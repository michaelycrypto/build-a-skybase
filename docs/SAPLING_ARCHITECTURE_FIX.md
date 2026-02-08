# Sapling Architecture

## Overview

Saplings have a **dual nature** - they exist as both **items** (inventory/held/dropped) and **blocks** (placed in world). This is intentional and follows Minecraft's design pattern.

## Architecture

### Single Source of Truth: `SaplingTypes.lua`

All sapling-related data is centralized in `/src/ReplicatedStorage/Configs/SaplingTypes.lua`.

```lua
local SaplingTypes = require(game.ReplicatedStorage.Configs.SaplingTypes)

-- Check if a block is a sapling
if SaplingTypes.IsSapling(blockId) then ... end

-- Get log type for a sapling
local logId = SaplingTypes.SAPLING_TO_LOG[saplingId]

-- Available lookup tables:
-- SaplingTypes.ALL_SAPLINGS      -- { [saplingId] = true }
-- SaplingTypes.SAPLING_TO_LOG    -- { [saplingId] = logId }
-- SaplingTypes.LOG_TO_SAPLING    -- { [logId] = saplingId }
-- SaplingTypes.LOG_TO_LEAVES     -- { [logId] = leavesId }
-- SaplingTypes.LEAVES_TO_SAPLING -- { [leavesId] = saplingId }
-- SaplingTypes.LOG_SET           -- { [logId] = true }
-- SaplingTypes.LEAF_SET          -- { [leavesId] = true }
-- SaplingTypes.LEAF_TO_SPECIES_CODE    -- { [leavesId] = speciesCode }
-- SaplingTypes.SPECIES_CODE_TO_SAPLING -- { [speciesCode] = saplingId }
```

### Adding a New Sapling Type

To add a new sapling type (e.g., Cherry Sapling):

1. **Add block IDs to `Constants.lua`:**
   ```lua
   CHERRY_LOG = xxx,
   CHERRY_SAPLING = xxx,
   CHERRY_LEAVES = xxx,
   ```

2. **Add to `SaplingTypes.lua` (single location!):**
   ```lua
   CHERRY = {
       saplingId = BLOCK.CHERRY_SAPLING,
       logId = BLOCK.CHERRY_LOG,
       leavesId = BLOCK.CHERRY_LEAVES,
       speciesCode = 6,  -- Next available code
       name = "Cherry Sapling",
       texture = "cherry_sapling",
   },
   ```

3. **Add block definitions to `BlockRegistry.lua`:**
   - Cherry Log block
   - Cherry Sapling block (with `entityName = "Cherry Sapling"`)
   - Cherry Leaves block

4. **Add item definition to `ItemDefinitions.lua`:**
   ```lua
   CHERRY_SAPLING = { id = xxx, name = "Cherry Sapling", category = "material", placesBlock = xxx },
   ```

5. **Add 3D model to `Assets.Tools`:**
   - Create `Cherry Sapling` MeshPart in `ReplicatedStorage.Assets.Tools`

That's it! All lookup tables are auto-generated from `SaplingTypes.lua`.

## File Responsibilities

| File | Purpose |
|------|---------|
| `SaplingTypes.lua` | Centralized sapling definitions and lookup tables |
| `ItemDefinitions.lua` | Sapling as inventory item (`category = "material"`) |
| `BlockRegistry.lua` | Sapling as world block (`crossShape`, `entityName`) |
| `SaplingService.lua` | Growth logic, leaf decay |
| `SaplingConfig.lua` | Growth timing, decay settings |
| `ItemModelLoader.lua` | Loads 3D models from `Assets.Tools` |
| `BlockEntityLoader.lua` | Loads 3D models for world placement (falls back to `Assets.Tools`) |

## Rendering Pipeline

### As Item (inventory/held/dropped)
1. `ItemRegistry.GetItem(id)` → Returns from `ItemDefinitions` (category = "material")
2. Rendering code checks `SaplingTypes.IsSapling(id)` to skip `BlockEntityLoader`
3. `ItemModelLoader.GetModelTemplate("Oak Sapling")` → Looks in `Assets.Tools`
4. Renders 3D model

### As Block (placed in world)
1. `BlockRegistry.Blocks[id]` → Returns block definition with `entityName`
2. `BlockEntityLoader.GetEntityTemplate("Oak Sapling")` → Looks in `Assets.BlockEntities`, falls back to `Assets.Tools`
3. Renders 3D model at world position

### Model Locations

Saplings need models in **two locations**:

| Location | Purpose |
|----------|---------|
| `Assets.Tools/{name}` | Held item, dropped item, viewmodel, inventory icon |
| `Assets.BlockEntities/{name}` | World placement (or falls back to `Assets.Tools`) |

If you only have one model, place it in `Assets.Tools` and `BlockEntityLoader` will find it as a fallback for world placement.

### Why Two Locations?

The rendering systems have different requirements:
- **Held/Dropped**: Uses `ItemModelLoader` which only looks in `Assets.Tools`
- **World Placement**: Uses `BlockEntityLoader` which looks in `Assets.BlockEntities` first, then `Assets.Tools`

Saplings are explicitly excluded from `BlockEntityLoader` in held/dropped/viewmodel code so they use `Assets.Tools` models instead of `BlockEntities`.

## Current Sapling Types

| Name | Sapling ID | Log ID | Leaves ID | Species Code |
|------|------------|--------|-----------|--------------|
| Oak | 16 | 5 (WOOD) | 63 | 0 |
| Spruce | 40 | 38 | 64 | 1 |
| Jungle | 45 | 43 | 65 | 2 |
| Dark Oak | 50 | 48 | 66 | 3 |
| Birch | 55 | 53 | 67 | 4 |
| Acacia | 60 | 58 | 68 | 5 |

## Metadata Encoding

Leaf blocks store species information in metadata bits 4-6 (values 0-7). This allows:
- Correct sapling drops when leaves decay
- Species persistence across server restarts
- Proper leaf-to-log association for decay checks

```lua
-- Get species code from leaf metadata
local speciesCode = SaplingTypes.GetSpeciesCodeForLeaf(leavesId)

-- Get sapling from species code (for drops)
local saplingId = SaplingTypes.GetSaplingFromSpeciesCode(speciesCode)
```

## Growth Mechanics

See `SaplingConfig.lua` for tuning:
- `TICK_INTERVAL`: 5 seconds between growth checks
- `ATTEMPT_CHANCE`: 1/30 chance per tick (~2.5 min expected growth)
- `REQUIRE_SKY_VISIBLE`: Must have clear sky above to grow
- `REPLACEABLE_BLOCKS`: Auto-generated from `SaplingTypes`

Tree structure (all saplings use same shape):
- 5-block trunk
- 5x5 leaf layer at y+3 and y+4 (minus corners)
- 3x3 leaf layer at y+5
