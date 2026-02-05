# Guide: Adding New Food Items

This guide explains how to manually add new food items to the system.

---

## Step-by-Step Process

### Step 1: Add Item ID to Constants.lua

First, add the new food item ID to `src/ReplicatedStorage/Shared/VoxelWorld/Core/Constants.lua`:

```lua
BlockType = {
    -- ... existing items ...
    BREAD = 228,  -- Example: Add new food item ID
    -- ... rest of items ...
}
```

**Important**: Choose an ID that doesn't conflict with existing items. Check the Constants file for available IDs.

---

### Step 2: Add Item to BlockRegistry.lua

Add the item definition to `src/ReplicatedStorage/Shared/VoxelWorld/World/BlockRegistry.lua`:

```lua
[Constants.BlockType.BREAD] = {
    name = "Bread",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(200, 150, 100),  -- Example color
    textures = { all = "rbxassetid://YOUR_TEXTURE_ID" },
    crossShape = true,  -- For food items
    craftingMaterial = true  -- Optional
}
```

---

### Step 3: Add Food Configuration to FoodConfig.lua

Add the food configuration to `src/ReplicatedStorage/Shared/FoodConfig.lua`:

```lua
[Constants.BlockType.BREAD] = {
    hunger = 5,
    saturation = 6.0,
    stackSize = 64,
    effects = {}  -- Optional, for special effects
},
```

---

### Step 4: Add to InventoryValidator.lua

Add the item ID to the valid items list in `src/ReplicatedStorage/Shared/VoxelWorld/Inventory/InventoryValidator.lua`:

```lua
local VALID_ITEM_IDS = {
    -- ... existing items ...
    [Constants.BlockType.BREAD] = true,
    -- ... rest of items ...
}
```

---

### Step 5: Add Textures to BlockRegistry

Update the `textures` field in BlockRegistry.lua with the actual texture ID:

```lua
[Constants.BlockType.BREAD] = {
    name = "Bread",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(200, 150, 100),
    textures = { all = "rbxassetid://1234567890" },  -- Add your texture ID here
    crossShape = true
}
```

---

### Step 6: Add 3D Model to ReplicatedStorage.Assets.Tools (Optional)

Add a 3D model named after the food item (e.g., "Bread") to:
- `game.ReplicatedStorage.Assets.Tools["Bread"]` (primary location)

The model should be:
- A `MeshPart` directly, OR
- A `Model`/`Folder` containing a `MeshPart`

---

## Minecraft Food Values Reference

Use these exact values for Minecraft parity:

| Food Item | Hunger | Saturation | Stack Size |
|-----------|--------|------------|------------|
| Apple | 4 | 2.4 | 64 |
| Bread | 5 | 6.0 | 64 |
| Cooked Beef | 8 | 12.8 | 64 |
| Cooked Porkchop | 8 | 12.8 | 64 |
| Cooked Chicken | 6 | 7.2 | 64 |
| Cooked Mutton | 6 | 9.6 | 64 |
| Cooked Rabbit | 5 | 6.0 | 64 |
| Golden Apple | 4 | 9.6 | 64 |
| Enchanted Golden Apple | 4 | 9.6 | 64 |
| Carrot | 3 | 3.6 | 64 |
| Potato | 1 | 0.6 | 64 |
| Baked Potato | 5 | 6.0 | 64 |
| Beetroot | 1 | 1.2 | 64 |
| Beetroot Soup | 6 | 7.2 | 1 |
| Mushroom Stew | 6 | 7.2 | 1 |
| Rabbit Stew | 10 | 12.0 | 1 |
| Milk Bucket | 0 | 0 | 1 |

---

## Special Foods with Effects

### Golden Apple
```lua
[Constants.BlockType.GOLDEN_APPLE] = {
    hunger = 4,
    saturation = 9.6,
    stackSize = 64,
    effects = {
        {type = "regeneration", level = 2, duration = 5}  -- Regeneration II for 5 seconds
    }
}
```

### Enchanted Golden Apple
```lua
[Constants.BlockType.ENCHANTED_GOLDEN_APPLE] = {
    hunger = 4,
    saturation = 9.6,
    stackSize = 64,
    effects = {
        {type = "regeneration", level = 5, duration = 20},
        {type = "absorption", level = 4, duration = 120},
        {type = "fire_resistance", level = 1, duration = 300},
        {type = "resistance", level = 1, duration = 300}
    }
}
```

### Milk Bucket
```lua
[Constants.BlockType.MILK_BUCKET] = {
    hunger = 0,
    saturation = 0,
    stackSize = 1,
    effects = {
        {type = "clear_effects"}  -- Removes all status effects
    }
}
```

---

## Complete Example: Adding Bread

### 1. Add to Constants.lua
```lua
BREAD = 228,
```

### 2. Add to BlockRegistry.lua
```lua
[Constants.BlockType.BREAD] = {
    name = "Bread",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(200, 150, 100),
    textures = { all = "rbxassetid://YOUR_TEXTURE_ID" },
    crossShape = true,
    craftingMaterial = true
}
```

### 3. Add to FoodConfig.lua
```lua
[Constants.BlockType.BREAD] = {
    hunger = 5,
    saturation = 6.0,
    stackSize = 64,
    effects = {}
}
```

### 4. Add to InventoryValidator.lua
```lua
[Constants.BlockType.BREAD] = true,
```

### 5. Add texture to BlockRegistry
Update the `textures` field with the actual texture ID.

### 6. Add 3D model (Optional)
Create `ReplicatedStorage.Assets.Tools["Bread"]` with a 3D model.

---

*Last Updated: January 2026*
*Related: [PRD_FOOD_CONSUMABLES.md](./PRDs/PRD_FOOD_CONSUMABLES.md), [FoodConfig.lua](../src/ReplicatedStorage/Shared/FoodConfig.lua)*
