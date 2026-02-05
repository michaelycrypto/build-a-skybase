# Quick Start: Adding New Foods

## Manual Addition Process

### Step 1: Add to Constants.lua

Add the item ID to `src/ReplicatedStorage/Shared/VoxelWorld/Core/Constants.lua`:

```lua
BlockType = {
    -- ... existing items ...
    BREAD = 228,  -- Your new food ID
}
```

### Step 2: Add to BlockRegistry.lua

Add the item definition:

```lua
[Constants.BlockType.BREAD] = {
    name = "Bread",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(200, 150, 100),
    textures = { all = "rbxassetid://YOUR_TEXTURE_ID" },
    crossShape = true
}
```

### Step 3: Add to FoodConfig.lua

Add the food configuration:

```lua
[Constants.BlockType.BREAD] = {
    hunger = 5,
    saturation = 6.0,
    stackSize = 64,
    effects = {}
}
```

### Step 4: Add to InventoryValidator.lua

Add to the valid items list:

```lua
local VALID_ITEM_IDS = {
    -- ... existing items ...
    [Constants.BlockType.BREAD] = true,
}
```

### Step 5: Add Texture

Update `BlockRegistry.lua` with the actual texture ID:

```lua
textures = { all = "rbxassetid://1234567890" }  -- Your texture ID
```

### Step 6: Add 3D Model (Optional)

Create `ReplicatedStorage.Assets.Tools["Bread"]` with a 3D MeshPart.

---

## Common Food Values (Minecraft Parity)

| Food | Hunger | Saturation | Stack |
|------|--------|-----------|-------|
| Apple | 4 | 2.4 | 64 |
| Bread | 5 | 6.0 | 64 |
| Cooked Beef | 8 | 12.8 | 64 |
| Cooked Porkchop | 8 | 12.8 | 64 |
| Cooked Chicken | 6 | 7.2 | 64 |
| Cooked Mutton | 6 | 9.6 | 64 |
| Cooked Rabbit | 5 | 6.0 | 64 |
| Golden Apple | 4 | 9.6 | 64 |
| Carrot | 3 | 3.6 | 64 |
| Potato | 1 | 0.6 | 64 |
| Baked Potato | 5 | 6.0 | 64 |
| Beetroot | 1 | 1.2 | 64 |
| Beetroot Soup | 6 | 7.2 | 1 |
| Mushroom Stew | 6 | 7.2 | 1 |
| Rabbit Stew | 10 | 12.0 | 1 |
| Milk Bucket | 0 | 0 | 1 |

---

*See [FOOD_ADDING_GUIDE.md](./FOOD_ADDING_GUIDE.md) for detailed documentation*
