# Adding New Block Types - Complete Process

**Version**: 1.0
**Last Updated**: 2025-10-24
**Status**: Required Process

---

## Overview

This document outlines the **mandatory steps** for adding new block types to the voxel world system. Missing any step will result in validation failures, rendering issues, or broken gameplay mechanics.

---

## Prerequisites

Before adding a new block, determine:

1. **Block Properties**:
   - Solid or transparent?
   - Special shape? (stairs, slabs, fences, cross-shape, liquid)
   - Needs ground support? (flowers, saplings)
   - Replaceable? (air, water, tall grass)
   - Interactable? (chests, crafting tables)

2. **Textures**:
   - Uniform texture (all faces same)?
   - Multi-face texture (top/side/bottom different)?
   - Texture file names

3. **Gameplay Behavior**:
   - Stackable? Max stack size?
   - Special placement rules?
   - Special breaking behavior?
   - Metadata needed? (rotation, water level, etc.)

---

## Step-by-Step Process

### **Phase 1: Core Constants** (REQUIRED)

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Core/Constants.lua`

#### 1.1 Add Block Type ID

Add to `BlockType` table with unique ID:

```lua
BlockType = {
    -- ... existing blocks ...
    YOUR_NEW_BLOCK = 30,  -- Use next available ID
},
```

**Rules**:
- IDs must be unique positive integers
- Never reuse IDs (breaks saved worlds)
- Keep IDs sequential for maintainability
- Reserve ID 0 for AIR

#### 1.2 Add Metadata Constants (if needed)

If your block uses metadata (rotation, level, variant):

```lua
BlockMetadata = {
    -- ... existing metadata ...

    -- For your block (use available bits)
    YOUR_BLOCK_VARIANT_MASK = 0b00001111,  -- Bits 0-3
    YOUR_BLOCK_VARIANT_SHIFT = 0,
},
```

#### 1.3 Add Helper Functions (if needed)

```lua
-- Get variant from metadata
function Constants.GetYourBlockVariant(metadata)
    return bit32.band(metadata or 0, Constants.BlockMetadata.YOUR_BLOCK_VARIANT_MASK)
end

-- Set variant in metadata
function Constants.SetYourBlockVariant(metadata, variant)
    metadata = metadata or 0
    return bit32.bor(
        bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.YOUR_BLOCK_VARIANT_MASK)),
        bit32.band(variant, Constants.BlockMetadata.YOUR_BLOCK_VARIANT_MASK)
    )
end
```

#### 1.4 Add Special Mappings (if applicable)

For slabs:
```lua
SlabToFullBlock = {
    [YOUR_SLAB_ID] = YOUR_FULL_BLOCK_ID,
},

FullBlockToSlab = {
    [YOUR_FULL_BLOCK_ID] = YOUR_SLAB_ID,
},
```

---

### **Phase 2: Block Registry** (REQUIRED)

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/World/BlockRegistry.lua`

#### 2.1 Add Block Definition

```lua
[Constants.BlockType.YOUR_NEW_BLOCK] = {
    name = "Your Block Name",
    solid = true,              -- false for air, water, plants
    transparent = false,        -- true for glass, water, leaves
    color = Color3.fromRGB(R, G, B),  -- Fallback color
    textures = {
        -- OPTION A: Uniform texture (all faces same)
        all = "your_texture_name"

        -- OPTION B: Multi-face texture
        top = "your_texture_top",
        side = "your_texture_side",
        bottom = "your_texture_bottom"

        -- OPTION C: Fully custom (chests, etc.)
        top = "...",
        bottom = "...",
        front = "...",
        back = "...",
        left = "...",
        right = "..."
    },

    -- Special shape flags (set ONE maximum)
    crossShape = false,         -- X-shape (flowers, tall grass)
    stairShape = false,         -- Staircase blocks
    slabShape = false,          -- Half-height blocks
    fenceShape = false,         -- Fence connecting logic
    liquid = false,             -- Water, lava

    -- Behavior flags
    replaceable = false,        -- Can be replaced by block placement (water, air, tall grass)
    interactable = false,       -- Right-click opens UI (chests)
    hasRotation = false,        -- Can be rotated when placed
    waterSource = false,        -- Is a water source block
    waterFlowing = false,       -- Is flowing water

    -- Other properties
    needsSupport = false,       -- Requires solid block below
    storage = false,            -- Has inventory storage
    fenceGroup = nil,           -- "wood_fence", "stone_fence", etc.
},
```

#### 2.2 Add Helper Methods (if needed)

If your block needs special checks:

```lua
-- Check if block is your type
function BlockRegistry:IsYourBlockType(blockId: number): boolean
    local block = self:GetBlock(blockId)
    return block.yourSpecialProperty == true
end
```

---

### **Phase 3: Inventory Validation** (CRITICAL - REQUIRED)

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Inventory/InventoryValidator.lua`

#### 3.1 Add to Valid Item IDs

**⚠️ MOST COMMON MISTAKE: Forgetting this step causes silent inventory failures**

```lua
local VALID_ITEM_IDS = {
    -- ... existing IDs ...
    [Constants.BlockType.YOUR_NEW_BLOCK] = true,
}
```

**Why**: Server validates all inventory operations. Missing IDs are rejected silently.

---

### **Phase 4: Block Placement Rules** (REQUIRED if placeable)

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/World/BlockPlacementRules.lua`

#### 4.1 Add Support Requirements (if needed)

If block needs specific ground support:

```lua
function BlockPlacementRules:NeedsGroundSupport(blockId: number): boolean
    return blockId == Constants.BlockType.TALL_GRASS
        or blockId == Constants.BlockType.FLOWER
        or blockId == Constants.BlockType.YOUR_NEW_BLOCK  -- ADD HERE
end

function BlockPlacementRules:CanSupport(blockId: number): boolean
    -- Air can't support anything
    if blockId == Constants.BlockType.AIR then
        return false
    end

    -- Add blocks that can support your new block
    return blockId == Constants.BlockType.GRASS
        or blockId == Constants.BlockType.DIRT
        or blockId == Constants.BlockType.YOUR_SUPPORT_BLOCK  -- ADD HERE
end
```

#### 4.2 Add Special Placement Logic (if needed)

For complex placement rules (like stairs, slabs):

```lua
-- Add to CanPlace function or create custom validator
```

---

### **Phase 5: Rendering** (REQUIRED for visible blocks)

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/BoxMesher.lua`

#### 5.1 Standard Solid Blocks

No changes needed - handled automatically by box merging algorithm.

#### 5.2 Special Shape Blocks

**For Stairs/Slabs/Fences**: Add to appropriate rendering pass (already implemented)

**For Cross-Shape Plants**: Add `crossShape = true` in BlockRegistry (already implemented)

**For Liquids**: Add new rendering pass:

```lua
-- Fifth pass: Your special block type
for x = 0, Constants.CHUNK_SIZE_X - 1 do
    for y = 0, yLimit - 1 do
        for z = 0, Constants.CHUNK_SIZE_Z - 1 do
            local id = chunk:GetBlock(x, y, z)
            if id == Constants.BlockType.YOUR_SPECIAL_BLOCK then
                -- Custom rendering logic here
                local part = Instance.new("Part")
                -- ... configure part ...
                table.insert(meshParts, part)
            end
        end
    end
end
```

#### 5.3 Texture Application

Ensure `TextureManager` has your texture loaded:

**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/TextureManager.lua`

```lua
-- Add texture ID mapping if needed
```

---

### **Phase 6: Starter Items** (OPTIONAL)

**File**: `src/ServerScriptService/Server/Services/ChestStorageService.lua`

#### 6.1 Add to InitializeStarterChest

If players should start with this block:

```lua
local blockTypes = {
    -- ... existing blocks ...
    {id = Constants.BlockType.YOUR_NEW_BLOCK, count = 64},
}
```

---

### **Phase 7: Special Systems** (CONDITIONAL)

#### 7.1 Water/Liquid Behavior

If adding liquid block:

1. Create simulator service (like `WaterSimulator.lua`)
2. Integrate into `VoxelWorldService.lua`
3. Add network events to `EventManager.lua`
4. Add client interaction in `BlockInteraction.lua`

#### 7.2 Interactable Blocks

If block opens UI (chests, furnaces):

1. Add `interactable = true` in BlockRegistry
2. Create service for storage/logic
3. Add UI panel on client
4. Register network events

#### 7.3 Animated/Dynamic Blocks

If block changes appearance:

1. Add metadata for state
2. Update rendering to respect metadata
3. Add state change logic

---

## Validation Checklist

Before committing new block type, verify:

- [ ] Block ID added to `Constants.BlockType`
- [ ] Block definition added to `BlockRegistry.Blocks`
- [ ] Block ID added to `InventoryValidator.VALID_ITEM_IDS`
- [ ] Special placement rules added (if needed)
- [ ] Rendering logic updated (if special shape)
- [ ] Metadata helpers added (if uses metadata)
- [ ] Network events added (if interactable/special)
- [ ] Textures exist and are loaded
- [ ] Tested in-game:
  - [ ] Chest transfer works
  - [ ] Inventory stacking works
  - [ ] Block placement works
  - [ ] Block breaking works
  - [ ] Textures render correctly
  - [ ] Special behavior works (if applicable)

---

## Common Mistakes

### ❌ **Mistake #1: Forgetting InventoryValidator**
**Symptom**: Block appears in chest but doesn't transfer to inventory
**Fix**: Add to `VALID_ITEM_IDS` in `InventoryValidator.lua`

### ❌ **Mistake #2: Using Wrong Metadata Bits**
**Symptom**: Block rotation/variant conflicts with other blocks
**Fix**: Check which bits are available, don't overlap existing metadata

### ❌ **Mistake #3: Not Setting `replaceable` Flag**
**Symptom**: Can't place blocks in water/air properly
**Fix**: Set `replaceable = true` for water, air, tall grass

### ❌ **Mistake #4: Missing Texture Definitions**
**Symptom**: Block renders as pink/missing texture
**Fix**: Ensure texture names match loaded textures in TextureManager

### ❌ **Mistake #5: Wrong `solid` Flag**
**Symptom**: Can walk through solid blocks OR collision on transparent blocks
**Fix**: Set `solid = true` only for blocks that should have collision

### ❌ **Mistake #6: Reusing Block IDs**
**Symptom**: Saved worlds corrupted, wrong blocks appear
**Fix**: Never reuse IDs, always use next available ID

---

## File Reference Quick List

**Must Edit (Every Block)**:
1. `Constants.lua` - Add block ID
2. `BlockRegistry.lua` - Add block definition
3. `InventoryValidator.lua` - Add to VALID_ITEM_IDS

**Conditional Edit**:
4. `BlockPlacementRules.lua` - If special placement rules
5. `BoxMesher.lua` - If special rendering
6. `ChestStorageService.lua` - If starter item
7. `VoxelWorldService.lua` - If special behavior (liquid, interactable)
8. `EventManager.lua` - If network events needed
9. `BlockInteraction.lua` - If special player interaction

**Rarely Edit**:
10. `TextureManager.lua` - If dynamic texture loading needed
11. Custom simulator (e.g., `WaterSimulator.lua`) - If complex behavior

---

## Block Type Examples

### Example A: Simple Solid Block (Cobblestone)

```lua
-- 1. Constants.lua
COBBLESTONE = 14,

-- 2. BlockRegistry.lua
[Constants.BlockType.COBBLESTONE] = {
    name = "Cobblestone",
    solid = true,
    transparent = false,
    color = Color3.fromRGB(127, 127, 127),
    textures = {
        all = "cobblestone"
    },
},

-- 3. InventoryValidator.lua
[Constants.BlockType.COBBLESTONE] = true,

-- DONE - No other files needed
```

### Example B: Liquid Block (Water)

```lua
-- 1. Constants.lua
WATER_SOURCE = 28,
WATER_FLOWING = 29,
-- Add metadata for water level (bits 0-2)

-- 2. BlockRegistry.lua
[Constants.BlockType.WATER_SOURCE] = {
    name = "Water Source",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(55, 125, 255),
    textures = { all = "water_still" },
    liquid = true,
    waterSource = true,
    replaceable = true,
},

-- 3. InventoryValidator.lua
[Constants.BlockType.WATER_SOURCE] = true,
[Constants.BlockType.WATER_FLOWING] = true,

-- 4. BlockPlacementRules.lua
-- Update to allow placing in replaceable blocks

-- 5. BoxMesher.lua
-- Add water rendering pass

-- 6. WaterSimulator.lua (NEW FILE)
-- Create water flow simulation

-- 7. VoxelWorldService.lua
-- Integrate WaterSimulator

-- 8. EventManager.lua
-- Add PlaceWaterSource, CollectWaterSource events
```

### Example C: Plant Block (Flower)

```lua
-- 1. Constants.lua
FLOWER = 8,

-- 2. BlockRegistry.lua
[Constants.BlockType.FLOWER] = {
    name = "Flower",
    solid = false,
    transparent = true,
    color = Color3.fromRGB(255, 255, 100),
    textures = { all = "flower" },
    crossShape = true,  -- X-shaped rendering
    needsSupport = true,  -- Must be on grass/dirt
},

-- 3. InventoryValidator.lua
[Constants.BlockType.FLOWER] = true,

-- 4. BlockPlacementRules.lua
function BlockPlacementRules:NeedsGroundSupport(blockId)
    return blockId == Constants.BlockType.FLOWER
end

function BlockPlacementRules:CanSupport(blockId)
    return blockId == Constants.BlockType.GRASS
        or blockId == Constants.BlockType.DIRT
end

-- 5. BoxMesher.lua already handles crossShape blocks
```

---

## Testing Procedure

After adding a new block:

1. **Inventory Test**:
   ```
   - Add block to starter chest
   - Transfer to inventory → Should work
   - Transfer between slots → Should work
   - Stack with same block → Should work
   ```

2. **Placement Test**:
   ```
   - Place block in air → Should work
   - Place block on ground → Should work
   - Place block in invalid position → Should reject
   ```

3. **Breaking Test**:
   ```
   - Break block → Should remove and drop item
   - Break with tool → Should respect break speed
   ```

4. **Rendering Test**:
   ```
   - Texture visible → Check all faces
   - Multiple blocks merge → Check if expected
   - Transparency works → If applicable
   ```

5. **Special Behavior Test**:
   ```
   - Rotation works → If applicable
   - Interaction works → If applicable
   - Special mechanics work → If applicable
   ```

---

## Version History

| Version | Date       | Changes                                    |
|---------|------------|--------------------------------------------|
| 1.0     | 2025-10-24 | Initial document - water block experience  |

---

## Support

If validation errors occur:

1. Check server console for rejection messages
2. Verify block ID in InventoryValidator
3. Check BlockRegistry definition is complete
4. Test with simple solid block first
5. Review this document section by section

---

**Document Owner**: Engineering Team
**Review Frequency**: After each major voxel system update



