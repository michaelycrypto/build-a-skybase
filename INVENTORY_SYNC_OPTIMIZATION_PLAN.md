# Inventory Sync Optimization Plan

## Problem Summary

Current inventory sync behavior is highly inefficient:
- **8 item drops in 2 seconds = 8 full inventory syncs**
- Each sync sends 36 slots (27 inventory + 9 hotbar)
- Estimated bandwidth: ~8 syncs × 36 slots × ~50 bytes = ~14KB in 2 seconds
- Client receives sync every ~250ms during rapid actions

## Root Cause Analysis

### Code Flow for Item Drop:
```
Client: VoxelHotbar:DropSelectedItem() [line 441]
  ↓ Optimistic update (good!)
  ↓ SendToServer("RequestDropItem")
  ↓
Server: DroppedItemService:HandleDropRequest() [line 312]
  ↓ inv:RemoveItem(player, itemId, count) [line 332]
  ↓
Server: PlayerInventoryService:RemoveItem() [line 317]
  ↓ Remove items from slots
  ↓ self:SyncInventoryToClient(player) [line 350] ⚠️ FULL SYNC!
```

### Other Inefficient Paths:
- **Pickup**: `AddItem()` → full sync (line 309)
- **Crafting**: `CraftingService:HandleCraftRequest()` → full sync (line 122)
- **Chest ops**: Multiple full syncs per operation
- **Validation failures**: Re-sync entire inventory

## Optimization Strategies

---

## ✅ Strategy 1: Sync Debouncing (IMPLEMENT FIRST)

### Goal
Batch multiple inventory changes within a time window and sync once.

### Implementation

```lua
-- In PlayerInventoryService.lua

function PlayerInventoryService.new()
    local self = setmetatable(BaseService.new(), PlayerInventoryService)

    self._logger = Logger:CreateContext("PlayerInventoryService")
    self.inventories = {}

    -- NEW: Debouncing system
    self.syncScheduled = {} -- {[player] = true/false}
    self.syncDebounceTime = 0.1 -- 100ms window
    self.lastSyncTime = {} -- {[player] = timestamp}
    self.modifiedSlots = {} -- {[player] = {hotbar = {}, inventory = {}}}

    return self
end

-- NEW: Schedule a debounced sync
function PlayerInventoryService:ScheduleSync(player, modifiedSlots)
    if not self.inventories[player] then return end

    -- Track which slots were modified
    if not self.modifiedSlots[player] then
        self.modifiedSlots[player] = {hotbar = {}, inventory = {}}
    end

    if modifiedSlots then
        -- Merge slot changes
        if modifiedSlots.hotbar then
            for slot, _ in pairs(modifiedSlots.hotbar) do
                self.modifiedSlots[player].hotbar[slot] = true
            end
        end
        if modifiedSlots.inventory then
            for slot, _ in pairs(modifiedSlots.inventory) do
                self.modifiedSlots[player].inventory[slot] = true
            end
        end
    end

    -- If sync already scheduled, just update the modified slots
    if self.syncScheduled[player] then
        return
    end

    -- Check if we're within debounce window
    local now = os.clock()
    local lastSync = self.lastSyncTime[player] or 0

    if now - lastSync < self.syncDebounceTime then
        -- Schedule for later
        self.syncScheduled[player] = true
        task.delay(self.syncDebounceTime - (now - lastSync), function()
            if self.syncScheduled[player] then
                self:ExecuteSync(player)
            end
        end)
    else
        -- Sync immediately
        self:ExecuteSync(player)
    end
end

-- NEW: Execute the actual sync
function PlayerInventoryService:ExecuteSync(player)
    if not self.inventories[player] then return end

    local modified = self.modifiedSlots[player]

    -- If many slots modified (>10), do full sync
    local totalModified = 0
    if modified then
        for _ in pairs(modified.hotbar or {}) do totalModified += 1 end
        for _ in pairs(modified.inventory or {}) do totalModified += 1 end
    end

    if not modified or totalModified > 10 then
        -- Full sync
        self:SyncInventoryToClient(player)
    else
        -- Partial sync (more efficient)
        self:SyncModifiedSlotsToClient(player, modified)
    end

    -- Reset tracking
    self.syncScheduled[player] = false
    self.lastSyncTime[player] = os.clock()
    self.modifiedSlots[player] = {hotbar = {}, inventory = {}}
end

-- NEW: Sync only modified slots
function PlayerInventoryService:SyncModifiedSlotsToClient(player, modified)
    local playerInv = self.inventories[player]
    if not playerInv then return end

    local hotbarUpdates = {}
    local inventoryUpdates = {}

    -- Collect hotbar changes
    for slot, _ in pairs(modified.hotbar or {}) do
        if playerInv.hotbar[slot] then
            hotbarUpdates[slot] = playerInv.hotbar[slot]:Serialize()
        end
    end

    -- Collect inventory changes
    for slot, _ in pairs(modified.inventory or {}) do
        if playerInv.inventory[slot] then
            inventoryUpdates[slot] = playerInv.inventory[slot]:Serialize()
        end
    end

    -- Send partial update event
    EventManager:FireEvent("InventoryPartialSync", player, {
        hotbar = hotbarUpdates,
        inventory = inventoryUpdates
    })
end
```

### Modify Existing Methods

```lua
-- CHANGE: RemoveItem now schedules sync instead of immediate
function PlayerInventoryService:RemoveItem(player, itemId, count)
    local playerInv = self.inventories[player]
    if not playerInv then return false end

    local totalCount = self:GetItemCount(player, itemId)
    if totalCount < count then return false end

    local remaining = count
    local modifiedSlots = {hotbar = {}, inventory = {}}

    -- Remove from hotbar first
    for i, stack in ipairs(playerInv.hotbar) do
        if remaining <= 0 then break end
        if stack:GetItemId() == itemId then
            local toRemove = math.min(stack:GetCount(), remaining)
            stack:RemoveCount(toRemove)
            remaining = remaining - toRemove
            modifiedSlots.hotbar[i] = true  -- Track change
        end
    end

    -- Remove from inventory if still needed
    for i, stack in ipairs(playerInv.inventory) do
        if remaining <= 0 then break end
        if stack:GetItemId() == itemId then
            local toRemove = math.min(stack:GetCount(), remaining)
            stack:RemoveCount(toRemove)
            remaining = remaining - toRemove
            modifiedSlots.inventory[i] = true  -- Track change
        end
    end

    -- CHANGED: Schedule debounced sync instead of immediate
    self:ScheduleSync(player, modifiedSlots)

    return remaining == 0
end

-- CHANGE: AddItem now schedules sync instead of immediate
function PlayerInventoryService:AddItem(player, itemId, count)
    -- ... existing logic ...

    local modifiedSlots = {hotbar = {}, inventory = {}}

    -- Track changes during add operations
    -- (add tracking to all the loops where stacks are modified)

    if remaining < count then
        self:ScheduleSync(player, modifiedSlots)  -- CHANGED
        return true
    end

    return false
end
```

### Client-Side Handler

```lua
-- In ClientInventoryManager.lua, add new event handler

function ClientInventoryManager:RegisterServerEvents()
    -- Existing full sync
    self.connections[#self.connections + 1] = EventManager:RegisterEvent("InventorySync", function(data)
        self:SyncFromServer(data.inventory, data.hotbar)
    end)

    -- NEW: Partial sync handler
    self.connections[#self.connections + 1] = EventManager:RegisterEvent("InventoryPartialSync", function(data)
        self:PartialSyncFromServer(data.inventory, data.hotbar)
    end)

    -- ... existing slot update handler ...
end

-- NEW: Handle partial sync (only update changed slots)
function ClientInventoryManager:PartialSyncFromServer(inventoryUpdates, hotbarUpdates)
    self._syncingFromServer = true

    -- Update only modified inventory slots
    if inventoryUpdates then
        for slotIndex, stackData in pairs(inventoryUpdates) do
            local slot = tonumber(slotIndex)
            if slot and slot >= 1 and slot <= 27 then
                self.inventory[slot] = ItemStack.Deserialize(stackData)
                self:NotifyInventoryChanged(slot)
            end
        end
    end

    -- Update only modified hotbar slots
    if hotbarUpdates and self.hotbar then
        for slotIndex, stackData in pairs(hotbarUpdates) do
            local slot = tonumber(slotIndex)
            if slot and slot >= 1 and slot <= 9 then
                local stack = ItemStack.Deserialize(stackData)
                self.hotbar:SetSlot(slot, stack)
                self:NotifyHotbarChanged(slot)
            end
        end
    end

    task.wait(0.05)  -- Shorter wait for partial syncs
    self._syncingFromServer = false

    print("ClientInventoryManager: Partial sync from server")
end
```

### Expected Impact
- **Before**: 8 drops in 2s → 8 full syncs → ~14KB
- **After**: 8 drops in 2s → 2-3 partial syncs → ~2KB
- **Improvement**: ~85% reduction in bandwidth

---

## ✅ Strategy 2: Rate Limiting (DEFENSIVE)

### Goal
Prevent sync spam and abuse scenarios.

### Implementation

```lua
-- In PlayerInventoryService.new()
self.syncRateLimit = 10  -- Max syncs per second per player
self.syncCount = {}       -- {[player] = {count = 0, resetTime = 0}}

function PlayerInventoryService:CheckSyncRateLimit(player)
    local now = os.clock()

    if not self.syncCount[player] then
        self.syncCount[player] = {count = 0, resetTime = now + 1}
        return true
    end

    local data = self.syncCount[player]

    -- Reset counter every second
    if now >= data.resetTime then
        data.count = 0
        data.resetTime = now + 1
    end

    if data.count >= self.syncRateLimit then
        self._logger.Warn("Sync rate limit exceeded", {player = player.Name})
        return false
    end

    data.count += 1
    return true
end

-- Use in ExecuteSync
function PlayerInventoryService:ExecuteSync(player)
    if not self:CheckSyncRateLimit(player) then
        -- Reschedule for next frame
        task.wait(0.1)
        self:ExecuteSync(player)
        return
    end

    -- ... rest of sync logic ...
end
```

---

## 🧪 Testing Strategy

### Test Case 1: Rapid Item Dropping
```
Action: Hold Q key to drop 20 items rapidly
Expected Before: 20 sync messages in ~3 seconds
Expected After: 3-5 sync messages in ~3 seconds
```

### Test Case 2: Inventory Drag & Drop
```
Action: Rapidly move items between slots
Expected: Minimal syncs, changes batched
```

### Test Case 3: Chest + Crafting + Dropping
```
Action: Complex multi-operation workflow
Expected: Operations grouped, efficient syncing
```

### Metrics to Track
- Sync frequency (syncs per second)
- Bandwidth usage (bytes per sync)
- Client desync incidents (should be zero)
- Server CPU usage (should decrease)

---

## 📊 Expected Results

| Scenario | Before | After | Improvement |
|----------|--------|-------|-------------|
| Drop 8 items in 2s | 8 syncs (14KB) | 2 syncs (2KB) | 85% reduction |
| Rapid crafting (10 crafts) | 10 syncs (25KB) | 3 syncs (4KB) | 84% reduction |
| Chest operations | 5-10 syncs | 2-3 syncs | 60% reduction |
| Server CPU (sync overhead) | High | Low | 70% reduction |

---

## 🚀 Implementation Priority

1. **HIGH**: Sync debouncing (Strategy 1) - Biggest impact
2. **MEDIUM**: Rate limiting (Strategy 2) - Safety/defensive
3. **LOW**: Advanced optimizations (compression, delta encoding)

---

## 🔄 Migration & Rollback

### Phase 1: Add new system alongside old
- Implement debouncing and partial syncs
- Keep full sync as fallback
- Add feature flag to toggle

### Phase 2: Monitor & tune
- Track sync frequency and bandwidth
- Adjust debounce window based on telemetry
- Monitor for desync issues

### Phase 3: Full migration
- Make partial sync default
- Keep full sync for validation failures only

### Rollback Plan
If issues occur:
- Feature flag disables debouncing
- Falls back to immediate full syncs
- No data loss or corruption risk

---

## 📝 Additional Optimizations (Future)

1. **Compression**: Use Roblox's buffer API for binary serialization
2. **Delta Encoding**: Send only item count changes, not full stack data
3. **Predictive Syncing**: Only sync when prediction fails
4. **Batched Events**: Group multiple event types into single remote call


