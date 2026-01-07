# Crafting UI - Quick Implementation Guide

This is a condensed guide for implementing the crafting system specified in `CRAFTING_UI_SPEC.md`.

## Quick Start

### Step 1: Create Recipe Configuration
**File**: `src/ReplicatedStorage/Configs/RecipeConfig.lua`

Define recipes with simple input → output structure:
```lua
oak_planks = {
    inputs = {{itemId = 5, count = 1}},   -- 1 Oak Log
    outputs = {{itemId = 12, count = 4}}  -- 4 Oak Planks
}
```

### Step 2: Add Stick Block Type
**Files to modify**:
- `src/ReplicatedStorage/Shared/VoxelWorld/Core/Constants.lua`
- `src/ReplicatedStorage/Shared/VoxelWorld/World/BlockRegistry.lua`

Add `STICK = 30` to BlockType enum.

### Step 3: Create Core Crafting Logic
**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Crafting/CraftingSystem.lua`

Key functions:
- `CanCraft(recipe, inventoryManager)` - Check materials
- `ExecuteCraft(recipe, inventoryManager, count)` - Do the craft
- `GetCraftableRecipes(inventoryManager, allRecipes)` - Filter recipes

### Step 4: Extend ClientInventoryManager
**File**: `src/StarterPlayerScripts/Client/Managers/ClientInventoryManager.lua`

Add helper methods:
- `CountItem(itemId)` - Count item across inventory + hotbar
- `RemoveItem(itemId, amount)` - Smart removal
- `AddItem(itemId, amount)` - Smart stacking

### Step 5: Create Crafting Panel UI
**File**: `src/StarterPlayerScripts/Client/UI/CraftingPanel.lua`

Create scrollable list of recipe cards showing:
- Recipe name and output quantity
- Ingredient icons with counts
- Craft button (enabled/disabled based on materials)

### Step 6: Integrate with VoxelInventoryPanel
**File**: `src/StarterPlayerScripts/Client/UI/VoxelInventoryPanel.lua`

Modifications:
1. Expand panel width to fit crafting section
2. Add crafting panel to right side
3. Wire up inventory change events to refresh crafting

### Step 7: Add Server Validation (Optional but Recommended)
**File**: `src/ServerScriptService/Server/Services/CraftingService.lua`

Validate crafting server-side to prevent exploits.

---

## Key Design Decisions

### Simplified Crafting
❌ **NOT like Minecraft**: No 2x2/3x3 grid pattern matching
✅ **Simplified**: Direct ingredient list → result

### Smart Filtering
Only show recipes the player **can currently craft** based on inventory.

### Layout
```
[Inventory Grid]  |  [Crafting Recipes]
     27 slots     |   Scrollable list
   + 9 hotbar     |   of recipe cards
```

---

## Example Recipe Card Layout

```
┌─────────────────────────────────────┐
│ Oak Planks                    [x 4] │  ← Name + Output count
│ 🪵 Oak Log x1                  [►] │  ← Ingredients + Craft btn
└─────────────────────────────────────┘
  └─ Icon created via BlockViewportCreator
```

**States**:
- **Craftable**: Green craft button, white text, interactive
- **Cannot Craft**: Gray button, dimmed text, disabled

---

## File Checklist

### New Files to Create
- [ ] `RecipeConfig.lua` - Recipe definitions
- [ ] `CraftingSystem.lua` - Core crafting logic
- [ ] `CraftingPanel.lua` - UI component
- [ ] `CraftingService.lua` - Server validation (optional)

### Files to Modify
- [ ] `Constants.lua` - Add STICK = 30
- [ ] `BlockRegistry.lua` - Add stick block definition
- [ ] `ClientInventoryManager.lua` - Add CountItem, AddItem, RemoveItem
- [ ] `VoxelInventoryPanel.lua` - Integrate crafting panel

---

## Testing Quick List

### Basic Functionality
1. Open inventory (E key) - crafting panel appears on right
2. Craft oak planks from logs - materials consumed, planks added
3. Craft sticks from planks - works correctly
4. Try crafting without materials - button disabled/grayed

### Edge Cases
1. Inventory full - craft still works (stacks properly)
2. Rapid clicking - no duplication
3. Close inventory while holding cursor item - item returned

---

## Integration Points

### With Existing Systems

**VoxelInventoryPanel**:
- Crafting panel embedded as right-side section
- Shares same styling (colors, fonts, corner radius)
- Updates when inventory changes

**ClientInventoryManager**:
- Crafting system uses manager for all inventory operations
- Manager triggers events on inventory change
- Crafting panel listens to events and refreshes

**ItemStack**:
- All crafting uses ItemStack for consistency
- Stack merging handled automatically
- Max stack sizes respected

---

## Visual Style Guide

### Colors (Match VoxelInventoryPanel)
```lua
BG_COLOR = Color3.fromRGB(35, 35, 35)           -- Panel background
CARD_BG_COLOR = Color3.fromRGB(45, 45, 45)      -- Recipe card
CARD_HOVER_COLOR = Color3.fromRGB(55, 55, 55)   -- Hover state
CRAFT_BTN_COLOR = Color3.fromRGB(80, 180, 80)   -- Green craft button
```

### Sizing
```lua
CRAFTING_PANEL_WIDTH = 240        -- Right-side panel
RECIPE_CARD_HEIGHT = 70           -- Each recipe
RECIPE_SPACING = 8                -- Gap between recipes
INGREDIENT_ICON_SIZE = 24         -- Mini block viewport
```

### Fonts
- **Recipe Name**: BuilderSansBold, Size 14
- **Ingredient Text**: Gotham, Size 11
- **Craft Button**: BuilderSansBold, Size 14 ("►")

---

## Common Recipes

```lua
-- Basic materials
Oak Log (x1) → Oak Planks (x4)
Oak Planks (x2) → Sticks (x4)

-- Tools
Oak Planks (x3) + Sticks (x2) → Wood Pickaxe (x1)
Oak Planks (x3) + Sticks (x2) → Wood Axe (x1)
Oak Planks (x1) + Sticks (x2) → Wood Shovel (x1)

-- Building (future)
Cobblestone (x4) → Stone Bricks (x4)
Oak Planks (x6) → Oak Stairs (x4)
```

---

## Performance Notes

- Recipe filtering: O(n) where n = number of recipes (~20-30)
- Item counting: O(36) for inventory + hotbar
- Viewport creation: One-time cost, reused on refresh
- Event debouncing: Prevents excessive refreshes

---

## Error Handling

### Client-Side
```lua
if not CraftingSystem:CanCraft(recipe, inventoryManager) then
    -- Show error message
    -- Play error sound
    return
end
```

### Server-Side
```lua
-- Validate recipe exists
-- Validate player has materials
-- Validate inventory space for outputs
-- Log suspicious activity (rapid crafting, impossible recipes)
```

---

## Future Extensions

Easy to add:
- New recipes (just add to RecipeConfig)
- Recipe categories/tabs
- Bulk crafting (shift+click)
- Recipe unlocking system
- Crafting achievements

---

## Debug Commands (for testing)

```lua
-- Give materials for testing
/give oak_log 64
/give oak_planks 64

-- Clear inventory
/clearinv

-- Unlock all recipes (if using unlock system)
/unlockrecipes
```

---

## Summary

This crafting system:
- ✅ Simple to use (no grid matching)
- ✅ Clean integration (fits existing UI perfectly)
- ✅ Extensible (easy to add recipes)
- ✅ Performant (efficient filtering)
- ✅ Validated (server-side checks)

Total estimated implementation time: **4-6 hours** for experienced developer.

See `CRAFTING_UI_SPEC.md` for full technical specification.

