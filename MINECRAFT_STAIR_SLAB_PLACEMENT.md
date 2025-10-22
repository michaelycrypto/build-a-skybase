# Minecraft-Style Stair & Slab Placement Implementation

## Overview
This implementation adds Minecraft-style placement logic for stairs and slabs, where the clicked position on a block face determines the block's vertical orientation (upside-down stairs, top/bottom slabs).

## How It Works

### Core Concept
When placing stairs or slabs, the system analyzes **which part of the target block face was clicked**:
- **Clicking upper half** → Places stairs upside-down or slabs at the top
- **Clicking lower half** → Places stairs normally or slabs at the bottom
- **Clicking top face** → Always places normally (bottom orientation)
- **Clicking bottom face** → Always places upside-down (top orientation)

### Implementation Details

#### 1. **Client-Side: Precise Hit Detection** (`BlockAPI.lua`)
Enhanced the raycast system to return the exact world position where the ray hit the block face:

```lua
function BlockAPI:GetTargetedBlockFace(origin, direction, maxDistance)
    -- Returns: blockPos, faceNormal, preciseHitPos
    -- preciseHitPos is the exact Vector3 position where the ray intersected the block face
end
```

The DDA (Digital Differential Analyzer) algorithm now tracks the distance parameter `hitT` to calculate the precise intersection point.

#### 2. **Client-Side: Sending Hit Data** (`BlockInteraction.lua`)
When placing a block, the client now sends:
- `hitPosition` - Precise world position of the ray intersection
- `targetBlockPos` - Which block was clicked
- `faceNormal` - Which face was clicked

```lua
EventManager:SendToServer("VoxelRequestBlockPlace", {
    x = placeX, y = placeY, z = placeZ,
    blockId = selectedBlock.id,
    hotbarSlot = selectedSlot,
    hitPosition = preciseHitPos,
    targetBlockPos = blockPos,
    faceNormal = faceNormal
})
```

#### 3. **Server-Side: Calculating Orientation** (`VoxelWorldService.lua`)
The server analyzes the hit data to determine vertical orientation:

```lua
-- Calculate relative position within the targeted block
local blockWorldPos = targetBlockPos * BLOCK_SIZE
local relativePos = hitPosition - blockWorldPos
local normalizedY = relativePos.Y / BLOCK_SIZE  -- 0.0 to 1.0

if faceNormal.Y == 1 then
    -- Top face → always bottom/normal orientation
    verticalOrientation = VERTICAL_BOTTOM
elseif faceNormal.Y == -1 then
    -- Bottom face → always top/upside-down orientation
    verticalOrientation = VERTICAL_TOP
else
    -- Side face → check upper or lower half
    if normalizedY > 0.5 then
        verticalOrientation = VERTICAL_TOP  -- Upper half
    else
        verticalOrientation = VERTICAL_BOTTOM  -- Lower half
    end
end
```

The orientation is stored in the block's metadata byte using bits 2-3:
- `VERTICAL_BOTTOM = 0` (bits `00`) - Normal stairs, bottom slabs
- `VERTICAL_TOP = 4` (bits `01`) - Upside-down stairs, top slabs

#### 4. **Rendering: Visual Representation** (`BoxMesher.lua`)

**Stairs:**
- Normal: Base slab at Y offset 0.25, step at Y offset 0.75
- Upside-down: Base slab at Y offset 0.75, step at Y offset 0.25

**Slabs:**
- Bottom: Y offset 0.25 (lower half of block)
- Top: Y offset 0.75 (upper half of block)

The renderer also only merges stairs/slabs with the same vertical orientation to prevent visual glitches.

## Metadata Format

Block metadata is stored as a single byte with the following bit layout:

```
Bits 0-1: Horizontal Rotation (4 directions)
  00 = NORTH (+Z)
  01 = EAST (+X)
  10 = SOUTH (-Z)
  11 = WEST (-X)

Bits 2-3: Vertical Orientation
  00 = BOTTOM (normal stairs, bottom slabs)
  01 = TOP (upside-down stairs, top slabs)

Bits 4-7: Reserved for future use
```

## Helper Functions

The `Constants` module provides utility functions:

```lua
-- Get/Set Rotation (bits 0-1)
Constants.GetRotation(metadata)
Constants.SetRotation(metadata, rotation)

-- Get/Set Vertical Orientation (bits 2-3)
Constants.GetVerticalOrientation(metadata)
Constants.SetVerticalOrientation(metadata, verticalOrientation)
```

## Usage Examples

### Placing Stairs
1. **Look at block and click lower half** → Normal stairs (steps going up)
2. **Look at block and click upper half** → Upside-down stairs (steps from ceiling)
3. **Click top face of block** → Always normal stairs
4. **Click bottom face of block** → Always upside-down stairs

### Placing Slabs
1. **Click lower half of side face** → Bottom slab (lower half of space)
2. **Click upper half of side face** → Top slab (upper half of space)
3. **Click top face** → Bottom slab
4. **Click bottom face** → Top slab

## Files Modified

1. **`BlockAPI.lua`** - Enhanced raycast to return precise hit position
2. **`BlockInteraction.lua`** - Sends hit position data to server
3. **`VoxelWorldService.lua`** - Calculates vertical orientation from hit data
4. **`BoxMesher.lua`** - Renders stairs/slabs with correct vertical position
5. **`Constants.lua`** - Already had metadata helpers (no changes needed)

## Benefits

✅ **Intuitive Building** - Matches Minecraft's familiar mechanics
✅ **Precise Control** - Players can create arches, overhangs, and complex structures
✅ **No New Blocks Needed** - Uses same block types with metadata
✅ **Efficient Networking** - Only 1 byte of metadata per block
✅ **Smart Merging** - Renderer only merges blocks with matching orientations

## Technical Notes

- The system uses **relative Y position** within the clicked block to determine upper/lower half
- **Threshold is 0.5** (50% of block height) - exactly like Minecraft
- **Face normals** provide additional context for top/bottom face clicks
- **Merging optimization** ensures stairs/slabs with different orientations don't combine incorrectly
- All calculations happen **server-side** to prevent cheating

## Slab Stacking Feature

### Overview
When you place a slab on top of another slab of the **same type** with **opposite vertical orientation**, they automatically combine into a full block!

### How It Works

**Example: Oak Slabs → Oak Planks**
1. Place a **bottom** oak slab
2. Place another oak slab on the **upper half** of it
3. **Result:** The two slabs combine into a full **oak planks** block!

### Slab-to-Block Mappings
- Oak Slab → Oak Planks
- Stone Slab → Stone
- Cobblestone Slab → Cobblestone
- Stone Brick Slab → Stone Bricks
- Brick Slab → Bricks

### Implementation Details

**Client-Side Detection** (`BlockInteraction.lua`):
- When placing a slab, checks if target position already has a slab
- If yes, places at **same position** instead of adjacent
- Server validates if orientations are opposite

**Server-Side Logic** (`VoxelWorldService.lua`):
1. Detects slab stacking attempt
2. Calculates what the new slab's orientation would be
3. Checks if orientations are opposite using `Constants.CanSlabsCombine()`
4. If valid, places the full block equivalent instead
5. Consumes one slab from inventory (as expected)

**Benefits:**
- ✅ **Saves inventory space** - One slab type instead of separate full blocks
- ✅ **Natural building** - Matches Minecraft's intuitive mechanic
- ✅ **Material efficiency** - Craft slabs, use as needed
- ✅ **Fully reversible** - Breaking full blocks returns 2 slabs!

### Breaking Full Blocks → 2 Slabs

When you **break** a full block that can be made from slabs, it drops **2 slabs** instead of 1 full block!

**Example:**
- Break **Oak Planks** → Get **2 Oak Slabs**
- Break **Stone** → Get **2 Stone Slabs**
- Break **Cobblestone** → Get **2 Cobblestone Slabs**
- Break **Stone Bricks** → Get **2 Stone Brick Slabs**
- Break **Bricks** → Get **2 Brick Slabs**

**Why this is great:**
1. 🔄 **Fully circular system** - Slabs ↔ Full blocks
2. 💰 **Better resource value** - 1 block becomes 2 slabs
3. 🎮 **Minecraft-accurate** - Matches expected behavior
4. 🔨 **Flexible building** - Always have the right form

## Testing Checklist

**Stair Placement:**
- [ ] Place stairs on side face (upper half) → upside-down
- [ ] Place stairs on side face (lower half) → normal
- [ ] Place stairs on top face → normal
- [ ] Place stairs on bottom face → upside-down
- [ ] Verify stairs rotate correctly with player facing direction
- [ ] Verify upside-down stairs merge properly with each other

**Slab Placement:**
- [ ] Place slabs on side face (upper half) → top slab
- [ ] Place slabs on side face (lower half) → bottom slab
- [ ] Verify top slabs merge with top slabs, not with bottom slabs

**Slab Stacking:**
- [ ] Place bottom oak slab, then top oak slab → oak planks
- [ ] Place top stone slab, then bottom stone slab → stone
- [ ] Try stacking different slab types → should NOT combine
- [ ] Try stacking same orientation → should NOT combine
- [ ] Verify only one slab consumed from inventory
- [ ] Verify full block has no metadata/rotation

**Breaking Full Blocks:**
- [ ] Break oak planks → drops 2 oak slabs
- [ ] Break stone → drops 2 stone slabs
- [ ] Break cobblestone → drops 2 cobblestone slabs
- [ ] Break stone bricks → drops 2 stone brick slabs
- [ ] Break bricks → drops 2 brick slabs
- [ ] Verify dropped items merge into single stack of 2
- [ ] Test the full cycle: place 2 slabs → stack → break → get 2 slabs back

