# Block Entities - 3D Mesh Rendering for Complex Blocks

## Overview

The game supports two types of block rendering:

1. **Regular Textured Blocks** - Rendered as cubes with textures on faces (Stone, Dirt, Planks, etc.)
2. **Block Entities** - Rendered as 3D models from `ReplicatedStorage.Assets.BlockEntities` (Chest, Anvil, etc.)

## Implementation Status: COMPLETE

The BlockEntity system is fully integrated across all rendering systems:

| System | File | Purpose |
|--------|------|---------|
| **BlockEntityLoader** | `Shared/BlockEntityLoader.lua` | Unified loader module for block entities |
| **BlockRegistry** | `VoxelWorld/World/BlockRegistry.lua` | Block definitions with `entityName` property |
| **BoxMesher** | `VoxelWorld/Rendering/BoxMesher.lua` | World chunk rendering |
| **DroppedItemController** | `Controllers/DroppedItemController.lua` | Items dropped on ground |
| **HeldItemRenderer** | `Shared/HeldItemRenderer.lua` | Items held in hand (3rd person) |
| **ViewmodelController** | `Controllers/ViewmodelController.lua` | Items held in hand (1st person) |
| **BlockViewportCreator** | `VoxelWorld/Rendering/BlockViewportCreator.lua` | Inventory UI previews |

## How It Works

### BlockRegistry Configuration

To make a block render as a 3D entity, add `entityName` to its definition:

```lua
[Constants.BlockType.CHEST] = {
    name = "Chest",
    solid = true,
    textures = { ... },  -- Fallback textures (not used if entity exists)
    entityName = "Chest" -- Must match model name in Assets.BlockEntities
},
```

### Rendering Flow

Each rendering system follows this pattern:

```lua
-- 1. Check if block has entity
local def = BlockRegistry.Blocks[blockId]
if def.entityName and BlockEntityLoader.HasEntity(def.entityName, blockId) then
    -- 2. Clone and use entity model
    local entity = BlockEntityLoader.CloneEntity(def.entityName, blockId)
    -- ... position, scale, configure entity
else
    -- 3. Fallback to textured cube rendering
    -- ... create cube with textures
end
```

## Configured Block Entities

| Block Type | Entity Name | Notes |
|------------|-------------|-------|
| CHEST | "Chest" | Storage block |
| ANVIL | "Anvil" | Smithing block |
| BREWING_STAND | "Brewing Stand" | Potion brewing |
| CAULDRON | "Cauldron" | Water container |
| ENCHANTING_TABLE | "Enchanting Table" | Enchantment block |
| LANTERN | "Torch" | Light source |
| SOUL_LANTERN | "Torch" | Blue light source |

## Available Entity Models (Not Yet Configured)

These models exist in BlockEntities but need block type definitions:

- Dragon Egg
- End Portal Frame
- Ender Chest
- Flower Pot
- Grindstone
- Hopper
- Ladder
- Lectern
- Sign

## Adding New Block Entities

1. **Add the model** to `ReplicatedStorage.Assets.BlockEntities` in Studio
2. **Add block type** to `Constants.lua` (if not exists)
3. **Add block definition** to `BlockRegistry.lua` with `entityName = "ModelName"`

Example:
```lua
-- In Constants.lua
ENDER_CHEST = 500,

-- In BlockRegistry.lua
[Constants.BlockType.ENDER_CHEST] = {
    name = "Ender Chest",
    solid = true,
    transparent = false,
    color = Color3.fromRGB(20, 20, 30),
    textures = { all = "ender_chest" },
    entityName = "Ender Chest",  -- <-- This enables 3D entity rendering
    hasRotation = true,
    interactable = true
},
```

## Model Requirements

Entity models in `ReplicatedStorage.Assets.BlockEntities` should be:

- **MeshPart** - Single mesh with TextureID
- **Model** - Container with MeshParts (for complex entities)

The system automatically:
- Scales models to fit block size
- Applies rotation based on block metadata
- Anchors parts for world placement
- Disables collision for held/dropped items

## File Structure

```
ReplicatedStorage/
└── Assets/
    ├── BlockEntities/
    │   ├── Anvil
    │   ├── Brewing Stand
    │   ├── Cauldron
    │   ├── Chest
    │   ├── Dragon Egg
    │   ├── Enchanting Table
    │   ├── End Portal Frame
    │   ├── Ender Chest
    │   ├── Flower Pot
    │   ├── Grindstone
    │   ├── Hopper
    │   ├── Ladder
    │   ├── Lectern
    │   ├── Sign
    │   └── Torch
    └── Tools/
        └── ... (item models)
```
