# PRD: UI Item Rendering Consolidation

## Status: Complete

## Problem

7 UI files contain duplicated item rendering logic with custom branching for tools, armor, spawn eggs, buckets, and blocks. Each file independently checks `ToolConfig.IsTool`, `ArmorConfig.GetArmorInfo`, `SpawnEggConfig.IsSpawnEgg`, `BlockRegistry:IsBucket`, etc. to decide how to render an item in a slot. This results in:

- ~80 lines of duplicated rendering code per file
- Inconsistent rendering (some files have leather armor overlay logic, some don't)
- Bug-prone (changes to rendering must be updated in 7 places)
- References to old APIs (ToolConfig, ArmorConfig for rendering instead of ItemRegistry)

## Solution

`BlockViewportCreator.RenderItemSlot()` has been created as the **single source of truth** for all item slot rendering. All UI files should use this instead of custom rendering logic.

### API

```lua
BlockViewportCreator.RenderItemSlot(iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)
```

- Clears existing children from `iconContainer`
- Renders spawn eggs as two-layer icons (if SpawnEggConfig/SpawnEggIcon provided)
- Renders all other items via `BlockViewportCreator.CreateBlockViewport()`:
  - Items NOT in BlockRegistry: flat 2D image using texture from 3D mesh in Assets.Tools (fallback to ItemDefinitions texture)
  - Blocks IN BlockRegistry: 3D viewport

### Files to migrate

Each file needs its custom tool/armor/spawn-egg/bucket/block branching replaced with a single `BlockViewportCreator.RenderItemSlot()` call. Also replace custom `GetItemDisplayName()` functions with `ItemRegistry.GetItemName()`.

| File | Old rendering refs | Status |
|------|-------------------|--------|
| `ChestUI.lua` | 12 ToolConfig/ArmorConfig refs, 4 rendering blocks | Partially done (1 of 4 blocks fixed) |
| `NPCTradeUI.lua` | 8 refs | Not started |
| `MinionUI.lua` | 8 refs | Not started |
| `FurnaceUI.lua` | 4 refs (+ GetItemDisplayName) | Not started |
| `CraftingPanel.lua` | 4 refs | Not started |
| `VoxelInventoryPanel.lua` | 2 refs (equip logic only - rendering already done) | Done |
| `VoxelHotbar.lua` | 1 ref (equip logic only - rendering already done) | Done |

### Migration pattern

Before (repeated in each file, ~50-80 lines per rendering block):
```lua
local isTool = ToolConfig.IsTool(itemId)
if isTool then
    local info = ToolConfig.GetToolInfo(itemId)
    -- create ImageLabel with info.image ...
elseif ArmorConfig.IsArmor(itemId) then
    local info = ArmorConfig.GetArmorInfo(itemId)
    -- create ImageLabel with info.image + leather overlay ...
elseif SpawnEggConfig.IsSpawnEgg(itemId) then
    -- create SpawnEggIcon ...
elseif BlockRegistry:IsBucket(itemId) or BlockRegistry:IsPlaceable(itemId) == false then
    -- create ImageLabel from block texture ...
else
    -- create 3D viewport or flat image ...
end
```

After (single line):
```lua
BlockViewportCreator.RenderItemSlot(iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)
```

### GetItemDisplayName migration

Each file has a local `GetItemDisplayName()` function with tool/armor/spawn-egg/block branching. Replace with:
```lua
local displayName = ItemRegistry.GetItemName(itemId)
```

### Cleanup after migration

Once all UIs use `RenderItemSlot`, remove unused imports from each file:
- `ToolConfig` (keep only if used for equip logic, not rendering)
- `ArmorConfig` (keep only if used for equip slot validation)
- `BlockRegistry` (keep only if used for block-specific logic like IsBucket)

### Estimated scope

- 5 files to migrate (ChestUI, NPCTradeUI, MinionUI, FurnaceUI, CraftingPanel)
- ~300 lines of duplicated code removed
- ~5 lines of replacement code per file
