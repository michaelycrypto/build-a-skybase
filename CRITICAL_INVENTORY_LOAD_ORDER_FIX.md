# 🔧 CRITICAL FIX: Inventory Load Order Bug

## The Problem

**Saved inventory data was being completely ignored! Players always got starter items even after saving.**

### Root Cause
The inventory loading had a critical order-of-operations bug:

```lua
-- BEFORE (BROKEN):
-- In PlayerService:OnPlayerAdded()
if self.Deps.PlayerInventoryService and playerData.inventory then
    self.Deps.PlayerInventoryService:LoadInventory(player, playerData.inventory)
    -- ❌ This does NOTHING because inventory doesn't exist yet!
end

-- In PlayerInventoryService:LoadInventory()
local playerInv = self.inventories[player]
if not playerInv then return end  -- ❌ Returns early!
```

Then later in Bootstrap:
```lua
-- This creates a NEW empty inventory with starter items,
-- overwriting any attempt to load saved data
playerInventoryService:OnPlayerAdded(player)
```

### The Sequence That Was Broken

1. **Player joins** → `Players.PlayerAdded` event fires
2. **`PlayerService:OnPlayerAdded()`** executes (via event connection)
   - Loads player data from DataStore
   - Tries to call `PlayerInventoryService:LoadInventory()` with saved data
   - **BUT** the inventory structure doesn't exist yet
   - `LoadInventory` returns early without doing anything ❌
3. **Bootstrap** then calls `playerInventoryService:OnPlayerAdded()`
   - Creates a NEW empty inventory with starter items
   - **Overwrites/ignores** any saved data ❌
4. **Result:** Player always gets starter items, saved inventory is lost!

## The Fix

### 1. Fixed Load Order in PlayerService

```lua
-- AFTER (FIXED):
-- In PlayerService:OnPlayerAdded()

-- IMPORTANT: Create inventory structure FIRST (before loading data)
if self.Deps.PlayerInventoryService then
    -- This creates the empty inventory structure
    self.Deps.PlayerInventoryService:OnPlayerAdded(player)

    -- NOW load saved data into the inventory (if exists)
    if playerData.inventory and playerData.inventory.hotbar and #playerData.inventory.hotbar > 0 then
        self._logger.Info("Loading saved inventory data for", player.Name)
        self.Deps.PlayerInventoryService:LoadInventory(player, playerData.inventory)
    else
        self._logger.Info("No saved inventory found, using starter items for", player.Name)
        -- Starter items were already given by OnPlayerAdded
    end
end
```

### 2. Removed Duplicate Call from Bootstrap

```lua
-- BEFORE:
playerInventoryService:OnPlayerAdded(player)  -- ❌ Duplicate call
voxelWorldService:OnPlayerAdded(player)

-- AFTER:
-- NOTE: PlayerInventoryService:OnPlayerAdded is now called by PlayerService
-- to ensure proper load order (create inventory, then load data)
voxelWorldService:OnPlayerAdded(player)
```

### The Correct Sequence Now

1. **Player joins** → `Players.PlayerAdded` event fires
2. **`PlayerService:OnPlayerAdded()`** executes
   - Loads player data from DataStore ✅
   - **Creates** empty inventory structure via `PlayerInventoryService:OnPlayerAdded()` ✅
   - **Then loads** saved data into it via `PlayerInventoryService:LoadInventory()` ✅
   - If no saved data, keeps the starter items from `OnPlayerAdded()` ✅
3. **Bootstrap** just adds player to the voxel world ✅
4. **Result:** Saved inventory is properly restored! 🎉

## What This Fixes

✅ **Inventory now persists** across sessions
✅ **Hotbar items save and load** correctly
✅ **Inventory slots save and load** correctly
✅ **No more duplicate starter items** being given
✅ **Proper initialization order** (create → load → use)

## Testing The Fix

### Test Scenario
1. **Join game** → Get starter items (hotbar with grass, dirt, stone, etc.)
2. **Modify inventory:**
   - Use some blocks (place/break)
   - Move items around
   - Add new items to inventory slots
3. **Leave game** → Data saves
4. **Rejoin game** → Inventory should be **exactly as you left it**

### Expected Logs (NEW)
```
[INFO] [PlayerService] Player added | {playerName=YourName, userId=123}
[INFO] [PlayerDataStoreService] Loaded player data | {player=YourName, level=1, coins=100}
PlayerInventoryService: Inventory already exists for YourName, skipping  ← From OnPlayerAdded
[INFO] Loading saved inventory data for | YourName  ← From LoadInventory
```

### What You'll See
- **First join:** Get starter items (normal)
- **After using blocks:** Inventory changes
- **After rejoining:** **Inventory is exactly as you left it!** ✅

## Files Changed

1. **`src/ServerScriptService/Server/Services/PlayerService.lua`**
   - Modified `OnPlayerAdded()` (lines 155-168)
   - Now calls `PlayerInventoryService:OnPlayerAdded()` BEFORE `LoadInventory()`
   - Added proper logging for saved vs new inventories

2. **`src/ServerScriptService/Server/Runtime/Bootstrap.server.lua`**
   - Removed duplicate `playerInventoryService:OnPlayerAdded()` calls
   - Lines 300-301 (PlayerAdded event)
   - Lines 364-365 (Existing players loop)
   - Added explanatory comments

3. **`src/ServerScriptService/Server/Services/PlayerDataStoreService.lua`**
   - Changed `DATA_STORE_NAME` to `"PlayerData_v2"` (line 25)
   - Changed `DATA_VERSION` to `2` (line 26)
   - **Result:** All players get fresh data for testing

4. **`src/ServerScriptService/Server/Services/WorldOwnershipService.lua`**
   - Changed `WORLD_DATA_STORE_NAME` to `"PlayerOwnedWorlds_v2"` (line 18)
   - **Result:** All worlds reset for testing

## Related Bugs Fixed

This is part of a series of save/load bugs we've fixed:

1. ✅ **Double world generation bug** - World initialized twice with different seeds
2. ✅ **Asynchronous loading bug** - Player spawned before chunks loaded
3. ✅ **Double save overwrite bug** - Second save overwrote data with empty state
4. ✅ **Player leaving save bug** - No save calls in PlayerRemoving handler
5. ✅ **❌ THIS BUG: Inventory load order bug** - Inventory created after load attempt

## Date
October 20, 2025

---

## Technical Details

### Why The Guard Clause Didn't Help

`PlayerInventoryService:OnPlayerAdded()` has this guard:

```lua
if self.inventories[player] then
    print("Inventory already exists, skipping")
    return
end
```

But this didn't help because:
- First time `OnPlayerAdded` is called (from PlayerService), inventory doesn't exist yet
- So it creates a new one with starter items
- When Bootstrap tries to call it again, the guard prevents duplication
- **But the damage is already done** - saved data was never loaded!

The fix ensures we create the inventory AND load saved data in the same place, in the right order.

