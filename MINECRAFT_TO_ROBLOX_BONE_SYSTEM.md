# Minecraft to Roblox Bone Translation System

## Problem Statement

Minecraft uses a **pivot-based bone system** where:
- Each bone has a pivot point
- Cubes are positioned relative to world origin
- Bones can be rotated around their pivot
- Child bones inherit parent transformations

Roblox uses **Motor6D joints** where:
- Parts are positioned by their CENTER
- Motor6D connects two parts with C0/C1 offsets
- No automatic transformation inheritance

## Translation Strategy

### Step 1: Understanding Minecraft Coordinates

From `sheep.geo.json`:
```json
{
  "name": "body",
  "pivot": [0.0, 19.0, 2.0],
  "bind_pose_rotation": [90.0, 0.0, 0.0],
  "cubes": [{
    "origin": [-4.0, 13.0, -5.0],
    "size": [8, 16, 6]
  }]
}
```

**Meaning:**
- Cube corner is at `origin` in world space
- Bone can rotate around `pivot` point
- `bind_pose_rotation` [90, 0, 0] means rotate 90° around X-axis BEFORE positioning

### Step 2: Calculate Cube Center After Rotation

For a 90° X rotation:
- Original size [8, 16, 6] → [width, length, height]
- After rotation: Y ↔ Z swap
- Final size [8, 6, 16] → [width, HEIGHT, length]

**Cube center calculation:**
1. Find center in unrotated space: `origin + size/2`
2. Offset from pivot: `center - pivot`
3. Rotate offset around pivot
4. New center: `pivot + rotated_offset`

### Step 3: RootOffset for Ground Alignment

Minecraft entities have Y=0 at feet level.
In our coordinate system, we spawn at the block surface.

**Solution:** Add `rootOffset = Vector3.new(0, px(6), 0)`
- This lifts the root (at Y=0 in model space) up by 6 pixels
- So leg bottoms (also at Y=0) rest exactly on the surface

### Step 4: Motor6D Joint Setup

For animated limbs (legs):
```lua
jointC1 = CFrame.new(0, px(6), 0)
```

This positions the rotation pivot at the TOP of the leg (Y=12 in Minecraft = leg center + 6px).

## Current Implementation

### MinecraftBoneTranslator.lua

Provides:
1. `CalculateCubeTransform()` - Handles rotation and positioning
2. `CalculateMotorOffsets()` - Creates proper C0/C1 for Motor6D
3. `BuildSheepGeometry()` - Raw Minecraft JSON data
4. `BuildSheepModel()` - Complete Roblox-compatible spec

### Sheep Model Spec

**Dimensions (100% accurate):**
- Legs: 4×12×4 px
- Body: 8×16×6 px (becomes 8×6×16 after rotation)
- Head: 6×6×8 px
- Inflates: body=1.75px, head wool=0.6px

**Positioning (adjusted for visual quality):**
- Legs: Y=0–12 px (exact JSON)
- Body: Y=10.5–16.5 px (lowered 2.5px from vanilla Y=13-19)
- Head: Y=16.5–22.5 px (adjusted to sit on body)
- Root offset: +6px (feet on ground)

**Why adjusted:**
Vanilla has 1px gap (legs end Y=12, body starts Y=13). With Roblox's solid parts, this is very visible. We overlap by 1.5px so the inflated wool (which extends down to Y=8.75) visually connects the legs seamlessly.

##Position Flow

**Server spawn:**
```
worldY = blockY * 3 + 3 + 0.01
// Example: Y=64 block → 195.01 studs
```

**Client render:**
```
rootPosition = worldY + rootOffset
             = 195.01 + 1.125
             = 196.135 studs

legBottom = rootPosition + 0 = 196.135 studs (on surface!)
legTop = rootPosition + 2.25 = 198.385 studs
bodyBottom = rootPosition + 1.96875 = 198.10 studs (overlaps legs)
```

## Future: Full Bone Hierarchy

For complex mobs with many bones, extend `MinecraftBoneTranslator` to:
1. Build complete bone tree from JSON
2. Calculate world transforms for each bone
3. Create Motor6D hierarchy (Part0 = parent bone, Part1 = child cube)
4. Handle nested rotations properly

This will allow direct JSON→Roblox conversion for ANY Minecraft entity.

