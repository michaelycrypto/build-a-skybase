# Crafting UI Specification

## Overview
This document specifies the implementation of a simplified crafting system integrated into the VoxelInventoryPanel. Unlike Minecraft's 2x2/3x3 grid pattern matching, this system displays only available recipes based on the player's current inventory.

## Design Goals
- **Simplified Crafting**: No grid pattern matching - recipes shown as simple ingredient → result transformations
- **Smart Filtering**: Only show recipes that the player can currently craft
- **Seamless Integration**: Fit naturally into the existing VoxelInventoryPanel UI
- **Consistent Patterns**: Follow existing codebase patterns for panels, managers, and UI components

---

## Architecture

### File Structure
```
src/
├── ReplicatedStorage/
│   ├── Configs/
│   │   └── RecipeConfig.lua                    [NEW] - Recipe definitions
│   └── Shared/
│       └── VoxelWorld/
│           └── Crafting/
│               ├── CraftingSystem.lua          [NEW] - Core crafting logic
│               └── RecipeValidator.lua         [NEW] - Recipe validation
├── StarterPlayerScripts/
    └── Client/
        └── UI/
            └── CraftingPanel.lua               [NEW] - Crafting UI component
```

### Modified Files
- `VoxelInventoryPanel.lua` - Add crafting panel as right-side section
- `Constants.lua` - Add new item IDs for crafting materials (sticks)

---

## Component Specifications

### 1. RecipeConfig.lua

**Location**: `src/ReplicatedStorage/Configs/RecipeConfig.lua`

**Purpose**: Define all crafting recipes in a centralized configuration

**Structure**:
```lua
local RecipeConfig = {}

-- Recipe category for UI organization
RecipeConfig.Categories = {
    MATERIALS = "Materials",
    TOOLS = "Tools",
    BUILDING = "Building Blocks"
}

-- Recipe definitions
RecipeConfig.Recipes = {
    -- Recipe ID: unique identifier
    oak_planks = {
        id = "oak_planks",
        name = "Oak Planks",
        category = RecipeConfig.Categories.MATERIALS,

        -- Inputs (what player needs)
        inputs = {
            {itemId = 5, count = 1}  -- 1x Oak Log (BlockType.WOOD)
        },

        -- Outputs (what player gets)
        outputs = {
            {itemId = 12, count = 4}  -- 4x Oak Planks (BlockType.OAK_PLANKS)
        },

        -- Crafting requirements
        requirements = {
            -- Future: could add requirements like "crafting_table_nearby"
        }
    },

    sticks = {
        id = "sticks",
        name = "Sticks",
        category = RecipeConfig.Categories.MATERIALS,

        inputs = {
            {itemId = 12, count = 2}  -- 2x Oak Planks
        },

        outputs = {
            {itemId = 30, count = 4}  -- 4x Sticks (NEW ItemID)
        }
    },

    wood_pickaxe = {
        id = "wood_pickaxe",
        name = "Wood Pickaxe",
        category = RecipeConfig.Categories.TOOLS,

        inputs = {
            {itemId = 12, count = 3},  -- 3x Oak Planks
            {itemId = 30, count = 2}   -- 2x Sticks
        },

        outputs = {
            {itemId = 1001, count = 1}  -- 1x Wood Pickaxe (ToolConfig)
        }
    },

    wood_axe = {
        id = "wood_axe",
        name = "Wood Axe",
        category = RecipeConfig.Categories.TOOLS,

        inputs = {
            {itemId = 12, count = 3},  -- 3x Oak Planks
            {itemId = 30, count = 2}   -- 2x Sticks
        },

        outputs = {
            {itemId = 1011, count = 1}  -- 1x Wood Axe
        }
    },

    wood_shovel = {
        id = "wood_shovel",
        name = "Wood Shovel",
        category = RecipeConfig.Categories.TOOLS,

        inputs = {
            {itemId = 12, count = 1},  -- 1x Oak Planks
            {itemId = 30, count = 2}   -- 2x Sticks
        },

        outputs = {
            {itemId = 1021, count = 1}  -- 1x Wood Shovel
        }
    }
}

-- Get all recipes as array (for iteration)
function RecipeConfig:GetAllRecipes()
    local recipes = {}
    for _, recipe in pairs(self.Recipes) do
        table.insert(recipes, recipe)
    end
    return recipes
end

-- Get recipe by ID
function RecipeConfig:GetRecipe(recipeId)
    return self.Recipes[recipeId]
end

-- Get recipes by category
function RecipeConfig:GetRecipesByCategory(category)
    local filtered = {}
    for _, recipe in pairs(self.Recipes) do
        if recipe.category == category then
            table.insert(filtered, recipe)
        end
    end
    return filtered
end

return RecipeConfig
```

---

### 2. CraftingSystem.lua

**Location**: `src/ReplicatedStorage/Shared/VoxelWorld/Crafting/CraftingSystem.lua`

**Purpose**: Core crafting logic - recipe availability and execution

**Key Methods**:
```lua
local CraftingSystem = {}

-- Check if player has enough materials for a recipe
function CraftingSystem:CanCraft(recipe, inventoryManager)
    -- Check each input requirement
    for _, input in ipairs(recipe.inputs) do
        local totalCount = inventoryManager:CountItem(input.itemId)
        if totalCount < input.count then
            return false
        end
    end
    return true
end

-- Get maximum number of times this recipe can be crafted
function CraftingSystem:GetMaxCraftCount(recipe, inventoryManager)
    local maxCount = math.huge

    for _, input in ipairs(recipe.inputs) do
        local totalCount = inventoryManager:CountItem(input.itemId)
        local timesCanCraft = math.floor(totalCount / input.count)
        maxCount = math.min(maxCount, timesCanCraft)
    end

    return maxCount == math.huge and 0 or maxCount
end

-- Execute crafting (consume inputs, add outputs)
function CraftingSystem:ExecuteCraft(recipe, inventoryManager, count)
    count = count or 1

    -- Validate can craft
    if not self:CanCraft(recipe, inventoryManager) then
        return false, "Not enough materials"
    end

    local maxCraft = self:GetMaxCraftCount(recipe, inventoryManager)
    if count > maxCraft then
        return false, "Not enough materials for that quantity"
    end

    -- Consume inputs
    for _, input in ipairs(recipe.inputs) do
        local totalToRemove = input.count * count
        inventoryManager:RemoveItem(input.itemId, totalToRemove)
    end

    -- Add outputs
    for _, output in ipairs(recipe.outputs) do
        local totalToAdd = output.count * count
        inventoryManager:AddItem(output.itemId, totalToAdd)
    end

    return true, "Crafted successfully"
end

-- Get all craftable recipes (filters based on current inventory)
function CraftingSystem:GetCraftableRecipes(inventoryManager, allRecipes)
    local craftable = {}

    for _, recipe in ipairs(allRecipes) do
        if self:CanCraft(recipe, inventoryManager) then
            table.insert(craftable, {
                recipe = recipe,
                maxCount = self:GetMaxCraftCount(recipe, inventoryManager)
            })
        end
    end

    return craftable
end

return CraftingSystem
```

---

### 3. CraftingPanel.lua

**Location**: `src/StarterPlayerScripts/Client/UI/CraftingPanel.lua`

**Purpose**: UI component for displaying and interacting with recipes

**Design**:
```
┌─────────────────────────────────────┐
│ Crafting                            │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ [RECIPE SCROLL AREA]            │ │
│ │                                 │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │ Oak Planks            [x 4] │ │ │
│ │ │ 🪵 Oak Log x1          [►]  │ │ │
│ │ └─────────────────────────────┘ │ │
│ │                                 │ │
│ │ ┌─────────────────────────────┐ │ │
│ │ │ Sticks                [x 4] │ │ │
│ │ │ 🪵 Oak Planks x2       [►]  │ │ │
│ │ └─────────────────────────────┘ │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

**Visual Style**:
- Same color scheme as VoxelInventoryPanel (dark gray background)
- Recipe cards with rounded corners
- Ingredient icons using BlockViewportCreator
- Disabled/grayed out when materials insufficient
- Highlight on hover
- Click to craft

**Layout Constants**:
```lua
local CRAFTING_CONFIG = {
    PANEL_WIDTH = 240,
    RECIPE_CARD_HEIGHT = 70,
    RECIPE_SPACING = 8,
    PADDING = 12,

    -- Colors match VoxelInventoryPanel
    BG_COLOR = Color3.fromRGB(35, 35, 35),
    CARD_BG_COLOR = Color3.fromRGB(45, 45, 45),
    CARD_HOVER_COLOR = Color3.fromRGB(55, 55, 55),
    CARD_DISABLED_COLOR = Color3.fromRGB(40, 40, 40),
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),
    TEXT_DISABLED_COLOR = Color3.fromRGB(120, 120, 120)
}
```

**Recipe Card Structure**:
```lua
function CraftingPanel:CreateRecipeCard(recipe, canCraft, maxCount)
    local card = Instance.new("TextButton")
    card.Size = UDim2.new(1, -CRAFTING_CONFIG.PADDING*2, 0, CRAFTING_CONFIG.RECIPE_CARD_HEIGHT)
    card.BackgroundColor3 = canCraft and CRAFTING_CONFIG.CARD_BG_COLOR or CRAFTING_CONFIG.CARD_DISABLED_COLOR
    card.AutoButtonColor = false
    card.Text = ""

    -- Recipe name (top)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Text = recipe.name
    nameLabel.Size = UDim2.new(1, -60, 0, 20)
    nameLabel.Position = UDim2.new(0, 8, 0, 6)
    nameLabel.TextColor3 = canCraft and CRAFTING_CONFIG.TEXT_COLOR or CRAFTING_CONFIG.TEXT_DISABLED_COLOR
    nameLabel.Font = Enum.Font.BuilderSansBold
    nameLabel.TextSize = 14
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.BackgroundTransparency = 1
    nameLabel.Parent = card

    -- Output quantity badge (top right)
    local outputCount = recipe.outputs[1].count
    local badge = Instance.new("TextLabel")
    badge.Text = "x" .. outputCount
    badge.Size = UDim2.new(0, 40, 0, 20)
    badge.Position = UDim2.new(1, -48, 0, 6)
    badge.TextColor3 = Color3.fromRGB(100, 200, 100)
    badge.Font = Enum.Font.BuilderSansBold
    badge.TextSize = 12
    badge.BackgroundTransparency = 1
    badge.Parent = card

    -- Ingredients display (middle)
    local ingredientsFrame = Instance.new("Frame")
    ingredientsFrame.Size = UDim2.new(1, -16, 0, 35)
    ingredientsFrame.Position = UDim2.new(0, 8, 0, 28)
    ingredientsFrame.BackgroundTransparency = 1
    ingredientsFrame.Parent = card

    -- Display ingredients with icons
    local xOffset = 0
    for i, input in ipairs(recipe.inputs) do
        -- Ingredient icon (mini viewport)
        local iconFrame = Instance.new("Frame")
        iconFrame.Size = UDim2.new(0, 24, 0, 24)
        iconFrame.Position = UDim2.new(0, xOffset, 0, 0)
        iconFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        iconFrame.BorderSizePixel = 0
        iconFrame.Parent = ingredientsFrame

        local iconCorner = Instance.new("UICorner")
        iconCorner.CornerRadius = UDim.new(0, 4)
        iconCorner.Parent = iconFrame

        -- Create small block viewport
        local isTool = ToolConfig.IsTool(input.itemId)
        if isTool then
            -- Tool image
            local toolInfo = ToolConfig.GetToolInfo(input.itemId)
            local image = Instance.new("ImageLabel")
            image.Size = UDim2.new(1, -4, 1, -4)
            image.Position = UDim2.new(0.5, 0, 0.5, 0)
            image.AnchorPoint = Vector2.new(0.5, 0.5)
            image.BackgroundTransparency = 1
            image.Image = toolInfo.image
            image.ScaleType = Enum.ScaleType.Fit
            image.Parent = iconFrame
        else
            -- Block viewport
            BlockViewportCreator.CreateBlockViewport(
                iconFrame,
                input.itemId,
                UDim2.new(1, 0, 1, 0)
            )
        end

        -- Count label
        local countLabel = Instance.new("TextLabel")
        countLabel.Text = "x" .. input.count
        countLabel.Size = UDim2.new(0, 50, 0, 24)
        countLabel.Position = UDim2.new(0, xOffset + 28, 0, 0)
        countLabel.TextColor3 = canCraft and CRAFTING_CONFIG.TEXT_COLOR or CRAFTING_CONFIG.TEXT_DISABLED_COLOR
        countLabel.Font = Enum.Font.BuilderSansBold
        countLabel.TextSize = 11
        countLabel.TextXAlignment = Enum.TextXAlignment.Left
        countLabel.BackgroundTransparency = 1
        countLabel.Parent = ingredientsFrame

        xOffset = xOffset + 85
    end

    -- Craft button (right side)
    local craftBtn = Instance.new("TextButton")
    craftBtn.Size = UDim2.new(0, 30, 0, 30)
    craftBtn.Position = UDim2.new(1, -38, 0.5, -15)
    craftBtn.AnchorPoint = Vector2.new(0, 0)
    craftBtn.BackgroundColor3 = canCraft and Color3.fromRGB(80, 180, 80) or Color3.fromRGB(60, 60, 60)
    craftBtn.Text = "►"
    craftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    craftBtn.Font = Enum.Font.BuilderSansBold
    craftBtn.TextSize = 14
    craftBtn.AutoButtonColor = false
    craftBtn.Parent = card

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = craftBtn

    -- Hover effects
    if canCraft then
        card.MouseEnter:Connect(function()
            card.BackgroundColor3 = CRAFTING_CONFIG.CARD_HOVER_COLOR
        end)

        card.MouseLeave:Connect(function()
            card.BackgroundColor3 = CRAFTING_CONFIG.CARD_BG_COLOR
        end)

        craftBtn.MouseButton1Click:Connect(function()
            self:OnCraft(recipe)
        end)
    end

    return card
end
```

**Integration with VoxelInventoryPanel**:
```lua
-- In VoxelInventoryPanel:CreatePanel()

-- Calculate new panel dimensions
local inventoryWidth = INVENTORY_CONFIG.SLOT_SIZE * INVENTORY_CONFIG.COLUMNS +
                       INVENTORY_CONFIG.SLOT_SPACING * (INVENTORY_CONFIG.COLUMNS - 1)

local craftingWidth = 240  -- CRAFTING_CONFIG.PANEL_WIDTH

local totalWidth = inventoryWidth + 30 + craftingWidth  -- 30px gap between sections

-- Update main panel size
self.panel.Size = UDim2.new(0, totalWidth + INVENTORY_CONFIG.PADDING * 2, 0, totalHeight)

-- Create crafting section (right side)
local craftingSection = Instance.new("Frame")
craftingSection.Name = "CraftingSection"
craftingSection.Size = UDim2.new(0, craftingWidth, 1, -70)
craftingSection.Position = UDim2.new(0, inventoryWidth + 30 + INVENTORY_CONFIG.PADDING, 0, 60)
craftingSection.BackgroundTransparency = 1
craftingSection.Parent = self.panel

-- Crafting panel instance
local CraftingPanel = require(script.Parent.CraftingPanel)
self.craftingPanel = CraftingPanel.new(self.inventoryManager, craftingSection)
self.craftingPanel:Initialize()
```

---

### 4. ClientInventoryManager Extensions

**New Methods for Crafting Support**:
```lua
-- Count total amount of an item across inventory and hotbar
function ClientInventoryManager:CountItem(itemId)
    local count = 0

    -- Count in inventory (27 slots)
    for i = 1, 27 do
        local stack = self:GetInventorySlot(i)
        if stack:GetItemId() == itemId then
            count = count + stack:GetCount()
        end
    end

    -- Count in hotbar (9 slots)
    for i = 1, 9 do
        local stack = self:GetHotbarSlot(i)
        if stack:GetItemId() == itemId then
            count = count + stack:GetCount()
        end
    end

    return count
end

-- Remove item from inventory/hotbar (smart removal)
function ClientInventoryManager:RemoveItem(itemId, amount)
    local remaining = amount

    -- Remove from inventory first
    for i = 1, 27 do
        if remaining <= 0 then break end

        local stack = self:GetInventorySlot(i)
        if stack:GetItemId() == itemId then
            local toRemove = math.min(remaining, stack:GetCount())
            stack:RemoveCount(toRemove)
            self:SetInventorySlot(i, stack)
            remaining = remaining - toRemove
        end
    end

    -- Remove from hotbar if needed
    for i = 1, 9 do
        if remaining <= 0 then break end

        local stack = self:GetHotbarSlot(i)
        if stack:GetItemId() == itemId then
            local toRemove = math.min(remaining, stack:GetCount())
            stack:RemoveCount(toRemove)
            self:SetHotbarSlot(i, stack)
            remaining = remaining - toRemove
        end
    end

    return remaining == 0  -- Returns true if all removed successfully
end

-- Add item to inventory/hotbar (smart stacking)
function ClientInventoryManager:AddItem(itemId, amount)
    local remaining = amount

    -- Try to add to existing stacks first
    for i = 1, 27 do
        if remaining <= 0 then break end

        local stack = self:GetInventorySlot(i)
        if stack:GetItemId() == itemId and not stack:IsFull() then
            local spaceLeft = stack:GetRemainingSpace()
            local toAdd = math.min(remaining, spaceLeft)
            stack:AddCount(toAdd)
            self:SetInventorySlot(i, stack)
            remaining = remaining - toAdd
        end
    end

    -- Create new stacks in empty slots
    for i = 1, 27 do
        if remaining <= 0 then break end

        local stack = self:GetInventorySlot(i)
        if stack:IsEmpty() then
            local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
            local toAdd = math.min(remaining, maxStack)
            self:SetInventorySlot(i, ItemStack.new(itemId, toAdd))
            remaining = remaining - toAdd
        end
    end

    return remaining == 0  -- Returns true if all added successfully
end
```

---

### 5. Constants.lua Updates

**Add Stick Item ID**:
```lua
-- In Constants.lua BlockType enum:
BlockType = {
    -- ... existing blocks ...
    WATER_FLOWING = 29,
    STICK = 30,  -- NEW: Crafting material
}
```

**Add to BlockRegistry.lua**:
```lua
[Constants.BlockType.STICK] = {
    name = "Stick",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(139, 90, 43),
    textures = {
        all = "stick"  -- Will need texture asset
    },
    crossShape = true,  -- Render like flowers/tall grass
    craftingMaterial = true  -- Special flag for crafting-only items
}
```

---

## User Flow

### Opening Inventory
1. Player presses `E` to open VoxelInventoryPanel
2. Panel expands to show both inventory (left) and crafting (right)
3. Crafting panel automatically filters to show only craftable recipes

### Crafting Items
1. Player views available recipes in the crafting panel
2. Recipes display:
   - Recipe name and output quantity
   - Required ingredients with icons
   - Craft button (green if craftable, gray if not)
3. Player clicks craft button (or recipe card)
4. System validates materials
5. Materials consumed, outputs added to inventory
6. Crafting panel refreshes to update availability
7. Sound effect plays (success or error)

### Inventory Updates
1. Any inventory change triggers crafting panel refresh
2. Recipe cards enable/disable based on current materials
3. Visual feedback: disabled recipes are grayed out

---

## Technical Implementation Notes

### Event Flow
```
Player clicks Craft
    ↓
CraftingPanel:OnCraft(recipe)
    ↓
CraftingSystem:ExecuteCraft(recipe, inventoryManager, count)
    ↓
ClientInventoryManager:RemoveItem(...)  // Consume inputs
ClientInventoryManager:AddItem(...)     // Add outputs
    ↓
inventoryManager:SendUpdateToServer()   // Sync with server
    ↓
CraftingPanel:RefreshRecipes()          // Update UI
VoxelInventoryPanel:UpdateAllDisplays() // Update inventory display
```

### Server Validation
While client-side crafting provides immediate feedback, implement server-side validation:

**New File**: `src/ServerScriptService/Server/Services/CraftingService.lua`
```lua
-- Validate and execute crafting on server
EventManager:RegisterEvent("CraftItem", function(player, recipeId, count)
    -- Get player's server-side inventory
    -- Validate recipe and materials
    -- Execute craft
    -- Sync back to client
end)
```

### Performance Considerations
- Recipe filtering runs on inventory change (debounced)
- ViewportFrames created once, not recreated on refresh
- Max ~20-30 recipes displayed (scrollable)
- Efficient item counting using hash maps

---

## UI Mockup Details

### Panel Layout
```
┌────────────────────────────────────────────────────────────────────┐
│  Inventory                                                      × │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Inventory                        │  Crafting                      │
│  ┌─┬─┬─┬─┬─┬─┬─┬─┬─┐             │  ┌──────────────────────────┐ │
│  │ │ │ │ │ │ │ │ │ │             │  │ Oak Planks         [x 4] │ │
│  ├─┼─┼─┼─┼─┼─┼─┼─┼─┤             │  │ 🪵 x1              [►]  │ │
│  │ │ │ │ │ │ │ │ │ │             │  └──────────────────────────┘ │
│  ├─┼─┼─┼─┼─┼─┼─┼─┼─┤             │                                │
│  │ │ │ │ │ │ │ │ │ │             │  ┌──────────────────────────┐ │
│  └─┴─┴─┴─┴─┴─┴─┴─┴─┘             │  │ Sticks             [x 4] │ │
│                                    │  │ 📏 x2              [►]  │ │
│  Hotbar                            │  └──────────────────────────┘ │
│  ┌─┬─┬─┬─┬─┬─┬─┬─┬─┐             │                                │
│  │1│2│3│4│5│6│7│8│9│             │  ┌──────────────────────────┐ │
│  └─┴─┴─┴─┴─┴─┴─┴─┴─┘             │  │ Wood Pickaxe       [x 1] │ │
│                                    │  │ 📏 x3  🪵 x2       [►]  │ │
│                                    │  └──────────────────────────┘ │
│                                    │                                │
└────────────────────────────────────────────────────────────────────┘
```

### Recipe Card States

**Craftable** (green accent):
```
┌────────────────────────────────┐
│ Oak Planks            [x 4]    │
│ 🪵 Oak Log x1          [►]     │
└────────────────────────────────┘
  Background: RGB(45, 45, 45)
  Button: RGB(80, 180, 80)
  Text: RGB(255, 255, 255)
```

**Not Craftable** (grayed out):
```
┌────────────────────────────────┐
│ Wood Pickaxe          [x 1]    │
│ 📏 x3  🪵 x2           [▪]     │
└────────────────────────────────┘
  Background: RGB(40, 40, 40)
  Button: RGB(60, 60, 60)
  Text: RGB(120, 120, 120)
```

---

## Testing Checklist

### Functional Tests
- [ ] Crafting oak logs → oak planks works correctly
- [ ] Crafting oak planks → sticks works correctly
- [ ] Crafting tools (pickaxe, axe, shovel) works
- [ ] Recipe filtering shows only craftable recipes
- [ ] Recipe cards disable when materials insufficient
- [ ] Multiple crafts consume materials correctly
- [ ] Inventory updates reflect in crafting panel
- [ ] Server sync validates crafting

### UI Tests
- [ ] Crafting panel displays correctly next to inventory
- [ ] Recipe cards render with correct styling
- [ ] Ingredient icons display correctly (blocks and tools)
- [ ] Hover effects work on craftable recipes
- [ ] Disabled recipes cannot be clicked
- [ ] Scrolling works with many recipes
- [ ] Panel resizes correctly when opened

### Integration Tests
- [ ] Opening/closing inventory shows/hides crafting
- [ ] Crafting updates hotbar display
- [ ] Crafting with full inventory handles overflow
- [ ] Server-client sync works correctly
- [ ] Multiple clients don't desync

### Edge Cases
- [ ] Crafting with exactly enough materials
- [ ] Crafting when inventory is full
- [ ] Crafting tools when hotbar is full
- [ ] Rapid clicking craft button
- [ ] Disconnection during craft
- [ ] Invalid recipe IDs handled gracefully

---

## Future Enhancements

### Phase 2 Features
1. **Bulk Crafting**: Shift+Click to craft max amount
2. **Recipe Unlocking**: Discover recipes by collecting ingredients
3. **Crafting Stations**: Require crafting table for advanced recipes
4. **Favorites**: Pin frequently used recipes to top
5. **Search/Filter**: Search recipes by name or category tabs

### Phase 3 Features
1. **Recipe Book**: Separate panel showing all discovered recipes
2. **Crafting Queue**: Queue multiple crafts
3. **Custom Recipes**: Server/admin configurable recipes
4. **Achievements**: Track crafting milestones
5. **Sound Effects**: Different sounds for different crafts

---

## Assets Needed

### Textures
- `stick.png` - Texture for stick item (crossShape rendering)

### Icons
- Already available through BlockViewportCreator for blocks
- Already available through ToolConfig for tools
- Stick will use crossShape rendering like flowers

### Sounds
- `craft_success.mp3` - Success sound when crafting
- `craft_fail.mp3` - Error sound when can't craft

---

## Migration Path

### Implementation Order
1. **Phase 1**: Core System (RecipeConfig, CraftingSystem)
2. **Phase 2**: UI Component (CraftingPanel)
3. **Phase 3**: Integration (VoxelInventoryPanel modifications)
4. **Phase 4**: Server Validation (CraftingService)
5. **Phase 5**: Polish & Testing

### Backwards Compatibility
- Existing inventory system unchanged
- Crafting is additive feature
- Old save data compatible
- Can be feature-flagged for gradual rollout

---

## Summary

This specification provides a complete, simplified crafting system that:
- ✅ Integrates seamlessly with existing VoxelInventoryPanel
- ✅ Follows established codebase patterns (Managers, Configs, UI components)
- ✅ Provides clear user experience (no complex grid matching)
- ✅ Scales for future recipe additions
- ✅ Includes client-side with server validation
- ✅ Maintains performance with efficient filtering

The system is designed to be implemented incrementally and can be extended with additional features in future updates.

