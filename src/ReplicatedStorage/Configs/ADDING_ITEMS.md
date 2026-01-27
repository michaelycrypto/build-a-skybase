# Adding New Items - Quick Guide

## Single Source of Truth: `ItemDefinitions.lua`

All item data is defined in **one file**: `ItemDefinitions.lua`

Other config files (`ToolConfig.lua`, `ArmorConfig.lua`) automatically read from it.

---

## Adding a New Tool

```lua
-- In ItemDefinitions.lua → Tools section:
MYTHRIL_PICKAXE = {
    id = 1007,                    -- Unique ID (pickaxes: 1001-1010)
    name = "Mythril Pickaxe",
    toolType = "pickaxe",         -- pickaxe, axe, shovel, sword
    tier = 7,                     -- Add tier to Tiers table if new
    texture = "rbxassetid://xxx"
},
```

## Adding New Armor

```lua
-- In ItemDefinitions.lua → Armor section:
MYTHRIL_HELMET = {
    id = 3025,                    -- Unique ID (armor: 3001-3099)
    name = "Mythril Helmet",
    slot = "helmet",              -- helmet, chestplate, leggings, boots
    tier = 7,
    texture = "rbxassetid://xxx"
},
-- Defense auto-calculated from ArmorDefense table
```

## Adding a New Material/Ingot

```lua
-- In ItemDefinitions.lua → Materials section:
MYTHRIL_INGOT = {
    id = 112,                     -- Unique ID (materials: 100-199)
    name = "Mythril Ingot",
    texture = "rbxassetid://xxx",
    color = Color3.fromRGB(r, g, b),
    craftingMaterial = true,
},
```

## Adding a New Ore

```lua
-- In ItemDefinitions.lua → Ores section:
MYTHRIL_ORE = {
    id = 104,
    name = "Mythril Ore",
    texture = "rbxassetid://xxx",
    color = Color3.fromRGB(r, g, b),
    hardness = 5.0,
    minToolTier = 4,              -- Bluesteel required to mine
    drops = 104,                  -- Item ID it drops (itself or material)
    spawnRate = 0.001,
},
```

## Adding a New Tier

```lua
-- 1. Add to ItemDefinitions.Tiers:
MYTHRIL = 7,

-- 2. Add color:
[7] = Color3.fromRGB(200, 150, 255),

-- 3. Add name:
[7] = "Mythril",

-- 4. Add armor defense in ArmorDefense table
```

---

## Still Required (for now)

After adding to `ItemDefinitions.lua`, you also need to:

1. **Constants.lua** - Add BlockType enum ID
2. **BlockRegistry.lua** - Add block texture (for blocks/ores/materials)
3. **InventoryValidator.lua** - Add to VALID_ITEM_IDS
4. **RecipeConfig.lua** - Add crafting recipes
5. **BlockProperties.lua** - Add mining properties (for ores)

---

## Validation

Run in Studio command bar:
```lua
require(game.ReplicatedStorage.Configs.ItemDefinitions).Validate()
```

This checks for:
- Missing required fields
- Duplicate IDs
- Invalid references

---

## ID Ranges

| Category | Range | Example |
|----------|-------|---------|
| Core Blocks | 1-99 | Stone=4, Dirt=3 |
| Ores | 98-130 | Copper=98, Iron=30 |
| Materials | 100-199 | Coal=32, Ingots=105+ |
| Full Blocks | 116-150 | Copper Block=116 |
| Tools | 1001-1099 | Pickaxes=1001-1010 |
| Ammo | 2001-2099 | Arrow=2001 |
| Armor | 3001-3099 | Copper Set=3001-3004 |
| Spawn Eggs | 4001-4099 | |

