# Sheep Model Position Analysis

## Minecraft Coordinate System vs Roblox

### Minecraft Bedrock Geometry System
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

**How Minecraft renders this:**
1. Create cube with corner at origin `[-4, 13, -5]` and size `[8, 16, 6]`
2. Rotate 90° around X-axis at the pivot point `[0, 19, 2]`
3. The rotation transforms:
   - Y (16 units) → Z (length)
   - Z (6 units) → Y (height)
   - Final dimensions: 8 wide, 6 tall, 16 long

**Key insight:** The origin `[-4, 13, -5]` is in UNROTATED space. After 90° X rotation around pivot `[0, 19, 2]`:
- The cube's corner moves in 3D space
- But Minecraft's renderer handles all this automatically with bone matrices

### Roblox Part System

Roblox Parts are positioned by their **CENTER** point, not corners. We need to:

1. Calculate where the cube's center ends up after rotation
2. Position Roblox part at that center
3. Use Motor6D joints for limb articulation

## Current Implementation Issues

### Double RootOffset Application

**Problem:** rootOffset is applied twice:

1. In `MobModel.lua`: ~~`baseCFrame = CFrame.new(rootOffset)`~~ (REMOVED)
2. In `MobReplicationController.lua`: `adjustedCFrame = worldPos * CFrame.new(rootOffset)` ✓

**Result:** Model was lifted **2× rootOffset** = 2.25 studs instead of 1.125 studs

### Body Position Adjustment

**Vanilla JSON positions:**
- Legs: Y=0-12 px (top at Y=12)
- Body: Y=13-19 px (bottom at Y=13, **1px gap**)
- Body center: Y=16 px

**Current adjusted positions:**
- Legs: Y=0-12 px ✓
- Body: Y=10.5-16.5 px (center Y=13.5, **1.5px overlap**)
- Body wool: Y=8.75-18.25 px (overlaps legs by 3.25px)

## Why We Can't Use Exact Vanilla Positions

### The Inflate Problem

In Minecraft, `inflate` expands cubes symmetrically. For body wool:
- Base cube: Y=13-19 (height 6)
- Inflate: 1.75 px on all sides
- Result: Y=(13-1.75) to (19+1.75) = **Y=11.25 to 20.75**

Wool bottom at Y=11.25 is **only 0.75px below** the 1px gap, barely covering it!

In Minecraft's renderer, this works because:
1. Textures blend smoothly
2. Anti-aliasing softens edges
3. Shading makes the transition less visible

In Roblox with solid colored parts:
- The 1px gap is VERY visible
- No texture blending to hide it
- Need actual geometry overlap

## Solution: Visual Fidelity vs Technical Accuracy

**Option A: Exact Vanilla (current rejected):**
```lua
BODY_CENTER_Y = px(16)  -- Leaves 1px gap
```

**Option B: Visually Seamless (current implementation):**
```lua
BODY_CENTER_Y = px(13.5)  -- 1.5px overlap, wool at 3.25px overlap
```

## Recommendation

Keep Option B (current) because:
1. Maintains exact JSON **dimensions** (8×6×16 body, 4×12×4 legs, correct inflates)
2. Adjusts only **vertical position** to eliminate visual gap
3. Looks like Minecraft in-game (players don't see the 1px gap there either due to rendering)
4. When we add mesh legs with wool, they'll naturally fill this area

The **dimensions** are 100% accurate, we just shifted the Y-axis assembly by 2.5px for visual quality.

