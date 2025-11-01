# Crafting System - Minecraft Cursor Mechanic

## Overview
This document specifies the **Minecraft-style cursor crafting mechanic** where clicking a recipe attaches the result to the cursor, and crafting only finalizes when the player places it into an inventory slot.

This replaces the "one-click instant craft" approach with a more tactile, Minecraft-authentic experience.

---

## Minecraft Crafting Behavior

### How It Works in Minecraft

```
┌─────────────────────────────────────────────────────────────┐
│ Crafting Table                                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌───┬───┬───┐                                             │
│  │ X │ X │ X │  Pattern          ┌─────────┐              │
│  ├───┼───┼───┤        ──────→    │ Result  │              │
│  │   │ | │   │                    │  Slot   │              │
│  ├───┼───┼───┤                    └─────────┘              │
│  │   │ | │   │                         ↓                   │
│  └───┴───┴───┘                                             │
│                           Click: Pick up result            │
│                                  (attach to cursor)         │
│                                                             │
│                           Materials consumed when:          │
│                           - Result picked up                │
│                                                             │
│  [Inventory Slots Below]       Place in inventory          │
│  ┌───┬───┬───┬───┐             to finalize craft           │
│  │   │   │   │   │  ←───────────────┘                     │
│  └───┴───┴───┴───┘                                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Behaviors

1. **Left Click**: Pick up entire result stack
2. **Right Click**: Pick up half the result stack
3. **Shift + Click**: Craft and auto-transfer to inventory (skip cursor)
4. **Materials Consumed**: When picking up result (not when placing)
5. **Cursor Stack**: Can hold crafted items, place anywhere in inventory

---

## Our Simplified + Cursor System

### Recipe List with Cursor Crafting

```
┌────────────────────────────────────────────────────────────┐
│  Inventory                                              [×]│
├──────────────────────────┬─────────────────────────────────┤
│                          │                                 │
│  📦 INVENTORY            │  🔨 CRAFTING                    │
│                          │                                 │
│  ┌──┬──┬──┬──┬──┬──┐    │  ┌────────────────────────────┐│
│  │🪵│  │  │  │  │  │    │  │ Oak Planks           x4    ││
│  │64│  │  │  │  │  │    │  │ 🪵 Oak Log x1               ││
│  ├──┼──┼──┼──┼──┼──┤    │  │                             ││
│  │  │  │  │  │  │  │    │  │ [Click to pick up]     [►] ││
│  └──┴──┴──┴──┴──┴──┘    │  └────────────────────────────┘│
│                          │                                 │
│  [More slots...]         │  ┌────────────────────────────┐│
│                          │  │ Sticks               x4    ││
│                          │  │ 📏 Oak Planks x2            ││
│                          │  │ [Need 2 planks!]       [▪] ││
│                          │  └────────────────────────────┘│
│                          │                                 │
└──────────────────────────┴─────────────────────────────────┘
```

### Crafting Flow

```
Step 1: Player clicks recipe
┌────────────────────────────┐
│ Oak Planks           x4    │
│ 🪵 x1                  [►] │  ← Click!
└────────────────────────────┘
            ↓
Step 2: Result attaches to cursor (materials consumed)
         ┌────┐
         │📏4│  ← Follows mouse
         └────┘

Step 3: Player hovers over inventory slot (shows preview)
  ┌──┬──┬──┬──┐
  │  │██│  │  │  ← Highlighted slot
  └──┴──┴──┴──┘

Step 4: Player clicks to place (craft finalizes)
  ┌──┬──┬──┬──┐
  │  │📏│  │  │  ← Planks placed
  │  │4 │  │  │
  └──┴──┴──┴──┘
         ↓
Crafting complete! Oak log consumed, planks added.
```

---

## Interaction Modes

### 1. Left Click Recipe
**Behavior**: Pick up full result stack (craft once, attach to cursor)

```lua
function CraftingPanel:OnRecipeLeftClick(recipe)
    -- Check if can craft
    if not CraftingSystem:CanCraft(recipe, self.inventoryManager) then
        return
    end

    -- Check if cursor is empty
    if not self.cursorStack:IsEmpty() then
        -- Already holding something - can't pick up recipe
        return
    end

    -- Consume materials
    for _, input in ipairs(recipe.inputs) do
        self.inventoryManager:RemoveItem(input.itemId, input.count)
    end

    -- Create cursor stack with result
    local output = recipe.outputs[1]  -- Assume single output for now
    self.cursorStack = ItemStack.new(output.itemId, output.count)

    -- Update displays
    self:UpdateCursorDisplay()
    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end
```

### 2. Right Click Recipe
**Behavior**: Pick up half result stack (useful for even splitting)

```lua
function CraftingPanel:OnRecipeRightClick(recipe)
    -- Similar to left click but:
    local output = recipe.outputs[1]
    local halfAmount = math.ceil(output.count / 2)

    self.cursorStack = ItemStack.new(output.itemId, halfAmount)
    -- ...
end
```

### 3. Shift + Click Recipe
**Behavior**: Craft and auto-place into inventory (skip cursor)

```lua
function CraftingPanel:OnRecipeShiftClick(recipe)
    -- Craft directly into inventory
    if not CraftingSystem:CanCraft(recipe, self.inventoryManager) then
        return
    end

    -- Consume materials
    for _, input in ipairs(recipe.inputs) do
        self.inventoryManager:RemoveItem(input.itemId, input.count)
    end

    -- Add output directly to inventory
    for _, output in ipairs(recipe.outputs) do
        local success = self.inventoryManager:AddItem(output.itemId, output.count)
        if not success then
            -- Inventory full - drop or return materials?
            self:HandleInventoryFull(recipe)
        end
    end

    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end
```

### 4. Place Cursor Stack
**Behavior**: Click inventory slot to place crafted items

This already exists in `VoxelInventoryPanel.lua` - we just need to ensure crafted items on cursor work the same as picked-up items.

```lua
-- In VoxelInventoryPanel:OnInventorySlotLeftClick(index)
-- Already handles cursor stack placement!

-- When cursor has items and player clicks empty slot:
if self.cursorStack:IsEmpty() then
    -- Pick up from slot
else
    -- Place cursor stack into slot (existing logic)
    if slotStack:IsEmpty() then
        self.inventoryManager:SetInventorySlot(index, self.cursorStack:Clone())
        self.cursorStack = ItemStack.new(0, 0)
    end
end
```

---

## Rapid Crafting (Click Repeatedly)

### Behavior
Player can click recipe multiple times to craft repeatedly while holding shift.

```
Click recipe once: Craft x4 Oak Planks (materials: -1 log)
Click again:        Add +4 to cursor stack (materials: -1 log)
Click again:        Add +4 to cursor stack (materials: -1 log)
...
Continue until: Materials run out OR stack reaches max (64)
```

### Implementation

```lua
function CraftingPanel:OnRecipeLeftClick(recipe)
    if not CraftingSystem:CanCraft(recipe, self.inventoryManager) then
        return
    end

    local output = recipe.outputs[1]

    -- If cursor empty: Start new stack
    if self.cursorStack:IsEmpty() then
        -- Consume materials
        self:ConsumeMaterials(recipe)

        -- Create cursor stack
        self.cursorStack = ItemStack.new(output.itemId, output.count)

    -- If cursor has same item AND not full: Add to stack
    elseif self.cursorStack:GetItemId() == output.itemId and
           not self.cursorStack:IsFull() then

        -- Consume materials
        self:ConsumeMaterials(recipe)

        -- Add to cursor stack (respecting max stack size)
        local spaceLeft = self.cursorStack:GetRemainingSpace()
        local amountToAdd = math.min(output.count, spaceLeft)
        self.cursorStack:AddCount(amountToAdd)

        -- If we couldn't add full amount, we hit max stack
        if amountToAdd < output.count then
            -- Play "stack full" sound
            -- Could optionally refund materials for unused portion
        end
    else
        -- Cursor has different item or is full - can't craft
        -- Play error sound
        return
    end

    self:UpdateCursorDisplay()
    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end
```

---

## UI Design with Cursor

### Recipe Card States

#### 1. Craftable (Cursor Empty)
```
╔═══════════════════════════════╗
║ Oak Planks             x4    ║
║                              ║
║ ┌───┐                        ║
║ │🪵│x1                  [►] ║
║ └───┘                        ║
║                              ║
║ Click to craft               ║
╚═══════════════════════════════╝
  Background: RGB(45, 45, 45)
  Button: RGB(80, 180, 80) - Green
```

#### 2. Craftable (Cursor Has Same Item, Not Full)
```
╔═══════════════════════════════╗
║ Oak Planks             x4    ║
║                              ║
║ ┌───┐                        ║
║ │🪵│x1                  [►] ║
║ └───┘                        ║
║                              ║
║ Click to add to stack        ║
╚═══════════════════════════════╝
  Background: RGB(45, 45, 45)
  Button: RGB(80, 180, 80) - Green
  Cursor: 📏 12 (already holding 12)
```

#### 3. Cannot Craft (Cursor Has Different Item)
```
╔═══════════════════════════════╗
║ Oak Planks             x4    ║
║                              ║
║ ┌───┐                        ║
║ │🪵│x1                  [▪] ║
║ └───┘                        ║
║                              ║
║ Place cursor item first      ║
╚═══════════════════════════════╝
  Background: RGB(40, 40, 40) - Darker
  Button: RGB(60, 60, 60) - Gray
  Cursor: 🪓 1 (holding different item)
```

#### 4. Cannot Craft (Stack Full)
```
╔═══════════════════════════════╗
║ Oak Planks             x4    ║
║                              ║
║ ┌───┐                        ║
║ │🪵│x1                  [▪] ║
║ └───┘                        ║
║                              ║
║ Stack full (64/64)           ║
╚═══════════════════════════════╝
  Background: RGB(40, 40, 40)
  Button: RGB(60, 60, 60) - Gray
  Cursor: 📏 64 (max stack)
```

---

## Cursor Display

### Reuse Existing Cursor System
`VoxelInventoryPanel` already has a cursor system! We just integrate with it.

```lua
-- In CraftingPanel.new()
function CraftingPanel.new(inventoryManager, voxelInventoryPanel, parentFrame)
    local self = setmetatable({}, CraftingPanel)

    self.inventoryManager = inventoryManager
    self.voxelInventoryPanel = voxelInventoryPanel  -- Reference to main panel
    self.parentFrame = parentFrame

    -- Share cursor with VoxelInventoryPanel
    -- (Don't create separate cursor - use the existing one!)

    return self
end

-- When crafting, directly modify VoxelInventoryPanel's cursor
function CraftingPanel:OnRecipeLeftClick(recipe)
    -- ...craft logic...

    -- Set VoxelInventoryPanel's cursor stack
    self.voxelInventoryPanel.cursorStack = ItemStack.new(output.itemId, output.count)
    self.voxelInventoryPanel:UpdateCursorDisplay()
end
```

**Result**: Seamless cursor behavior across inventory and crafting!

---

## Material Consumption Timing

### Important Decision: When to Consume?

#### Option A: Consume When Picking Up (Minecraft Default)
```
Click recipe → Materials consumed → Cursor holds result
            ↓
    Can click repeatedly to craft more
            ↓
    Place in inventory to finalize
```

**Pros**:
- Authentic Minecraft behavior
- Natural for rapid crafting
- Clear visual feedback

**Cons**:
- If player disconnects with cursor item, might lose materials
- Materials gone before crafting "completes"

#### Option B: Consume When Placing (Alternative)
```
Click recipe → "Ghost" result on cursor → Materials NOT consumed yet
            ↓
    Place in inventory → Materials consumed now
```

**Pros**:
- More forgiving
- Can cancel by clicking outside inventory

**Cons**:
- Not authentic Minecraft
- Harder to implement rapid crafting
- Confusing UX (when did I use materials?)

### **Recommendation: Option A (Minecraft Default)**

Materials consume when picking up result. This matches player expectations and enables natural rapid crafting.

**Safety Net**: If player disconnects or closes inventory with cursor item, return it to inventory automatically (existing behavior in `VoxelInventoryPanel:Close()`).

---

## Integration with Existing Cursor System

### VoxelInventoryPanel Already Has:

```lua
-- Cursor state
self.cursorStack = ItemStack.new(0, 0)
self.cursorFrame = nil  -- UI element that follows mouse

-- Cursor methods
function VoxelInventoryPanel:UpdateCursorDisplay()
function VoxelInventoryPanel:IsCursorHoldingItem()
function VoxelInventoryPanel:UpdateCursorPosition()

-- Auto-cleanup on close
function VoxelInventoryPanel:Close()
    -- Returns cursor items to inventory
```

### CraftingPanel Integration:

```lua
function CraftingPanel.new(inventoryManager, voxelInventoryPanel, parentFrame)
    local self = setmetatable({}, CraftingPanel)

    self.inventoryManager = inventoryManager
    self.voxelInventoryPanel = voxelInventoryPanel  -- NEW: Reference to main panel
    self.parentFrame = parentFrame

    return self
end

function CraftingPanel:GetCursorStack()
    return self.voxelInventoryPanel.cursorStack
end

function CraftingPanel:SetCursorStack(stack)
    self.voxelInventoryPanel.cursorStack = stack
    self.voxelInventoryPanel:UpdateCursorDisplay()
end

function CraftingPanel:IsCursorEmpty()
    return self.voxelInventoryPanel.cursorStack:IsEmpty()
end
```

**Result**: No duplicate cursor system needed! Crafting uses the same cursor as inventory drag-and-drop.

---

## Updated Recipe Click Handling

### Complete Implementation

```lua
function CraftingPanel:CreateRecipeCard(recipe, canCraft, maxCount)
    local card = Instance.new("TextButton")
    -- ... setup card UI ...

    -- Left click: Pick up result (or add to cursor stack)
    card.MouseButton1Click:Connect(function()
        self:OnRecipeLeftClick(recipe, canCraft)
    end)

    -- Right click: Pick up half result
    card.MouseButton2Click:Connect(function()
        self:OnRecipeRightClick(recipe, canCraft)
    end)

    -- Shift+Click: Craft and auto-place
    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or
               UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
                self:OnRecipeShiftClick(recipe, canCraft)
            end
        end
    end)

    return card
end

function CraftingPanel:OnRecipeLeftClick(recipe, canCraft)
    if not canCraft then return end

    local cursorStack = self:GetCursorStack()
    local output = recipe.outputs[1]

    -- Case 1: Cursor empty - start new stack
    if cursorStack:IsEmpty() then
        self:CraftToNewStack(recipe, output)

    -- Case 2: Cursor has same item, not full - add to stack
    elseif cursorStack:GetItemId() == output.itemId and
           not cursorStack:IsFull() then
        self:CraftToExistingStack(recipe, output, cursorStack)

    -- Case 3: Cursor has different item or is full - can't craft
    else
        SoundManager:PlaySFX("error")  -- Play error sound
    end
end

function CraftingPanel:CraftToNewStack(recipe, output)
    -- Consume materials
    for _, input in ipairs(recipe.inputs) do
        self.inventoryManager:RemoveItem(input.itemId, input.count)
    end

    -- Set cursor stack
    local newStack = ItemStack.new(output.itemId, output.count)
    self:SetCursorStack(newStack)

    -- Update
    SoundManager:PlaySFX("craft")
    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end

function CraftingPanel:CraftToExistingStack(recipe, output, cursorStack)
    -- Check space
    local spaceLeft = cursorStack:GetRemainingSpace()
    local amountToAdd = math.min(output.count, spaceLeft)

    if amountToAdd <= 0 then
        SoundManager:PlaySFX("error")
        return
    end

    -- Consume materials
    for _, input in ipairs(recipe.inputs) do
        self.inventoryManager:RemoveItem(input.itemId, input.count)
    end

    -- Add to cursor stack
    cursorStack:AddCount(amountToAdd)
    self:SetCursorStack(cursorStack)

    -- Play appropriate sound
    if amountToAdd < output.count then
        SoundManager:PlaySFX("stack_full")  -- Hit max stack
    else
        SoundManager:PlaySFX("craft")
    end

    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end

function CraftingPanel:OnRecipeShiftClick(recipe, canCraft)
    if not canCraft then return end

    -- Consume materials
    for _, input in ipairs(recipe.inputs) do
        self.inventoryManager:RemoveItem(input.itemId, input.count)
    end

    -- Add directly to inventory
    for _, output in ipairs(recipe.outputs) do
        local success = self.inventoryManager:AddItem(output.itemId, output.count)

        if not success then
            -- Inventory full - could drop item or show message
            print("Inventory full! Item dropped.")
            -- TODO: Implement item drop to world
        end
    end

    SoundManager:PlaySFX("craft")
    self.inventoryManager:SendUpdateToServer()
    self:RefreshRecipes()
end
```

---

## Updated UI Flow

```
┌────────────────────────────────────────────────────────────┐
│  USER INTERACTION FLOW                                     │
└────────────────────────────────────────────────────────────┘

1. Player opens inventory (E key)
   └─> Crafting panel shows on right

2. Player sees available recipes
   ├─> Oak Planks (green, can craft)
   └─> Sticks (gray, need more planks)

3. Player LEFT CLICKS "Oak Planks" recipe
   ├─> Materials consumed (-1 Oak Log)
   ├─> Cursor now holds: 📏 x4 (Oak Planks)
   └─> Recipe refreshes (still green if more logs available)

4. Player CLICKS AGAIN on "Oak Planks"
   ├─> Materials consumed (-1 Oak Log)
   ├─> Cursor now holds: 📏 x8 (added to stack)
   └─> Recipe refreshes

5. Player CLICKS AGAIN... continues up to max stack (64)
   ├─> Each click: -1 log, +4 planks to cursor
   └─> When cursor reaches 64: Recipe grays out (stack full)

6. Player moves cursor over empty inventory slot
   └─> Slot highlights (preview)

7. Player LEFT CLICKS inventory slot
   ├─> Cursor stack placed in slot
   ├─> Cursor now empty
   └─> Recipe becomes green again (can craft more)

8. Alternatively: Player SHIFT+CLICKS recipe
   ├─> Materials consumed
   ├─> Items placed directly in inventory (skip cursor)
   └─> Fastest for bulk crafting
```

---

## Recipe Card Visual States (Updated)

### Dynamic Button Text

```lua
function CraftingPanel:GetRecipeButtonState(recipe, canCraft)
    local cursorStack = self:GetCursorStack()
    local output = recipe.outputs[1]

    if not canCraft then
        return {
            enabled = false,
            text = "▪",
            color = RGB(60, 60, 60),
            hint = "Not enough materials"
        }
    end

    if cursorStack:IsEmpty() then
        return {
            enabled = true,
            text = "►",
            color = RGB(80, 180, 80),
            hint = "Click to craft"
        }
    end

    if cursorStack:GetItemId() == output.itemId then
        if cursorStack:IsFull() then
            return {
                enabled = false,
                text = "▪",
                color = RGB(60, 60, 60),
                hint = "Stack full (64/64)"
            }
        else
            return {
                enabled = true,
                text = "+",
                color = RGB(80, 180, 80),
                hint = "Click to add (" .. cursorStack:GetCount() .. "/64)"
            }
        end
    else
        return {
            enabled = false,
            text = "▪",
            color = RGB(60, 60, 60),
            hint = "Place cursor item first"
        }
    end
end
```

### Example States

```
State 1: No cursor, can craft
╔═══════════════════════════╗
║ Oak Planks          x4 [►]║
║ 🪵 x1                     ║
╚═══════════════════════════╝

State 2: Cursor has same item (8/64)
╔═══════════════════════════╗
║ Oak Planks          x4 [+]║  ← Plus icon!
║ 🪵 x1      (8/64)         ║  ← Shows cursor count
╚═══════════════════════════╝

State 3: Cursor full (64/64)
╔═══════════════════════════╗
║ Oak Planks          x4 [▪]║  ← Disabled
║ 🪵 x1      FULL           ║
╚═══════════════════════════╝

State 4: Cursor has different item
╔═══════════════════════════╗
║ Oak Planks          x4 [▪]║  ← Disabled
║ 🪵 x1      (holding 🪓)   ║
╚═══════════════════════════╝
```

---

## Updated VoxelInventoryPanel Integration

### Modifications Needed

```lua
-- In VoxelInventoryPanel:CreatePanel()
function VoxelInventoryPanel:CreatePanel()
    -- ... existing inventory creation ...

    -- Create crafting section (NEW)
    local CraftingPanel = require(script.Parent.CraftingPanel)
    self.craftingPanel = CraftingPanel.new(
        self.inventoryManager,
        self,  -- Pass reference to VoxelInventoryPanel
        craftingSection
    )
    self.craftingPanel:Initialize()
end

-- Share cursor events (NEW)
function VoxelInventoryPanel:OnCursorChanged()
    -- Notify crafting panel when cursor changes
    if self.craftingPanel then
        self.craftingPanel:OnCursorChanged()
    end
end
```

---

## Server Validation

### Server-Side Crafting Event

```lua
-- Server: CraftingService.lua
EventManager:RegisterEvent("CraftRecipe", function(player, recipeId, count)
    local inventoryData = PlayerInventoryService:GetInventory(player)
    local recipe = RecipeConfig:GetRecipe(recipeId)

    if not recipe then
        warn("Invalid recipe:", recipeId)
        return
    end

    -- Validate materials (server-side check)
    for _, input in ipairs(recipe.inputs) do
        local totalNeeded = input.count * count
        if not HasEnoughMaterials(inventoryData, input.itemId, totalNeeded) then
            warn("Player", player.Name, "tried to craft without materials!")
            -- Resync inventory to prevent desync
            PlayerInventoryService:SyncToClient(player)
            return
        end
    end

    -- Execute craft server-side
    for _, input in ipairs(recipe.inputs) do
        RemoveMaterials(inventoryData, input.itemId, input.count * count)
    end

    for _, output in ipairs(recipe.outputs) do
        AddMaterials(inventoryData, output.itemId, output.count * count)
    end

    -- Sync back to client
    PlayerInventoryService:SyncToClient(player)
end)
```

---

## Summary of Changes

### What Changed from Original Spec

| Original Spec | Updated (Cursor Mechanic) |
|---------------|---------------------------|
| Click recipe → Instant craft | Click recipe → Cursor picks up result |
| Materials consumed on click | Materials consumed when picking up |
| Result added to inventory | Result held on cursor, placed manually |
| One click = one craft | Multiple clicks = stack on cursor |
| Simple and fast | More tactile, Minecraft-authentic |

### Benefits of Cursor Mechanic

✅ **More Minecraft-like** - Familiar to players
✅ **Rapid crafting** - Click repeatedly to build stack
✅ **Flexible placement** - Choose where to put crafted items
✅ **Visual feedback** - See what you're crafting on cursor
✅ **Reuses existing code** - VoxelInventoryPanel cursor system

### Implementation Complexity

- **Slightly More Complex**: Need to handle cursor states
- **Reuses Existing**: VoxelInventoryPanel already has cursor system
- **Net Change**: ~50 extra lines of code, mostly state checks

---

## Testing Checklist (Updated)

### Cursor Behavior
- [ ] Click recipe: Result attaches to cursor
- [ ] Click again: Adds to cursor stack (up to 64)
- [ ] Click when full: Disabled, plays error sound
- [ ] Click different recipe with cursor: Disabled
- [ ] Place cursor stack in inventory: Works correctly
- [ ] Cursor follows mouse smoothly

### Shift+Click
- [ ] Shift+click recipe: Crafts directly to inventory
- [ ] Works with full stacks
- [ ] Finds empty slots automatically
- [ ] Handles full inventory gracefully

### Materials
- [ ] Consumed when picking up result
- [ ] Not consumed if craft fails
- [ ] Correct amounts for repeated crafts
- [ ] Server validates materials

### Integration
- [ ] Cursor works same as inventory drag-drop
- [ ] Closing inventory returns cursor items
- [ ] Disconnecting doesn't lose cursor items
- [ ] Refreshes recipe availability correctly

---

## Final Recommendation

**Implement the cursor mechanic** as specified here. It provides:

1. ✅ **Authentic Minecraft feel** - Matches player expectations
2. ✅ **Rapid crafting** - Click repeatedly for bulk
3. ✅ **Reuses existing code** - VoxelInventoryPanel cursor
4. ✅ **Flexible UX** - Choose where to place items
5. ✅ **Minimal extra work** - Small changes to original spec

This is the **best of both worlds**: Simplified recipe list (no grid) + Minecraft cursor crafting (tactile feel).

---

See `CRAFTING_UI_SPEC.md` for full system details and `CRAFTING_IMPLEMENTATION_GUIDE.md` for step-by-step coding instructions.

