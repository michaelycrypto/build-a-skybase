# Skyblock Mode

## Overview

The game has been converted to **Skyblock mode** - players spawn on a small floating island in the sky with limited resources. Each player's world is their own personal Skyblock island that persists in their datastore.

## What Changed

### World Generation

**Before:** Infinite procedurally generated terrain with rolling hills, caves, and ores.

**After:** A single floating island in the void:
- **Island Size:** Circular platform with 5-block radius
- **Island Height:** Y=65 (floating in the sky)
- **Island Structure:**
  - Bottom layer (Y=63): Stone
  - Middle layer (Y=64): Dirt
  - Top layer (Y=65): Grass
- **Starting Resources:** One oak tree at the center
- **Everything else:** Void (air)

### Key Features

✅ **Floating Island** - Players spawn on a small circular platform
✅ **Starting Tree** - Oak tree with leaves for wood/saplings
✅ **Void World** - No ground below, infinite sky
✅ **Fall Damage** - Be careful at the edges!
✅ **Expandable** - Players can build outward from the island
✅ **Player-Owned** - Each server is one player's personal Skyblock

## File Changes

### New Files
- `Generation/SkyblockGenerator.lua` - Generates the floating island

### Modified Files
- `World/WorldManager.lua` - Uses SkyblockGenerator instead of TerrainGenerator
- `Services/VoxelWorldService.lua` - Spawns players on the island
- `Bootstrap.server.lua` - Updated for Skyblock mode

## World Structure

```
Y=70: Tree leaves & Air
Y=69: Tree trunk & Air
Y=68: Tree trunk & Air
Y=67: Tree trunk & Air
Y=66: Tree trunk & Air
Y=65: [====GRASS====] (Surface)
Y=64: [====DIRT====]
Y=63: [====STONE====] (Bottom)
Y=62: Air (void below)
...
Y=0:  Air (no bedrock)
```

## Island Dimensions

- **Radius:** 5 blocks from center (0, 0)
- **Total diameter:** ~10 blocks
- **Surface area:** ~78 grass blocks
- **Center coordinates:** (0, 65, 0)
- **Spawn position:** (0, 67, 0) - 2 blocks above grass

## Spawn System

Players spawn at:
- **X:** 0 (island center)
- **Y:** 67 (2 blocks above grass)
- **Z:** 0 (island center)

This prevents them from spawning inside the tree or too close to the edge.

## Gameplay Implications

### Starting Resources
- **Wood:** 1 oak tree (4 logs + leaves)
- **Dirt:** ~30 blocks (middle layer)
- **Stone:** ~50 blocks (bottom layer)
- **Grass:** ~78 blocks (surface)

### Challenge Mechanics
- **Limited Space:** Players must expand carefully
- **Void Danger:** Falling off = death
- **Resource Management:** Must use starting resources wisely
- **No Caves:** All resources come from the surface
- **No Ores:** Currently no underground resources (can be added later)

## Future Enhancements

Potential additions to enhance Skyblock gameplay:

1. **Resource Generation**
   - Cobblestone generator (lava + water)
   - Tree farms (saplings)
   - Mob spawning platforms

2. **Challenges/Quests**
   - Build to certain size
   - Create farms
   - Collect specific items
   - Reach milestones

3. **Ore Blocks**
   - Add ore blocks to starting island
   - Or make them obtainable through other means

4. **Multiple Islands**
   - Generate additional small islands at distance
   - Encourage bridging between islands

5. **Weather/Events**
   - Rain (fills water sources)
   - Lightning (fire hazard)
   - Meteor showers (resource drops)

6. **Visiting**
   - Allow players to visit each other's islands
   - Trading between players

## Configuration

You can modify the island in `SkyblockGenerator.lua`:

```lua
local SKYBLOCK_CONFIG = {
	ISLAND_Y = 65, -- Island height
	ISLAND_RADIUS = 5, -- Island radius in blocks
	ISLAND_CENTER_X = 0, -- Center X coordinate
	ISLAND_CENTER_Z = 0, -- Center Z coordinate
	VOID_WORLD = true, -- Everything else is air
}
```

### Make the Island Bigger

Change `ISLAND_RADIUS` from `5` to a larger number:
- `ISLAND_RADIUS = 10` → ~314 surface blocks
- `ISLAND_RADIUS = 15` → ~707 surface blocks
- `ISLAND_RADIUS = 20` → ~1257 surface blocks

### Change Island Height

Change `ISLAND_Y` from `65` to a different height:
- Higher = more dramatic void below
- Lower = easier to build down
- Recommended: 50-100 range

### Add More Resources

In the `GenerateChunk` function, you can:
- Place additional trees
- Add ore blocks
- Create ponds or lava pools
- Add animals/mobs

## Technical Details

### Generator Type
`SkyblockGenerator` uses **positional generation** rather than noise:
- Calculates distance from island center
- Determines if each block is part of the island
- Creates circular shape with layered depth
- No Perlin noise needed (deterministic by position)

### Chunk Streaming
- Only chunks near the island contain blocks
- All other chunks are empty (air)
- Efficient memory usage (empty chunks are cheap)
- Fast generation (no noise calculations)

### Collision Detection
The island shape tapers as it goes down:
- Top layer (Y=65): Full radius (5 blocks)
- Middle layer (Y=64): Slightly smaller
- Bottom layer (Y=63): Even smaller

This creates a natural "rounded" island bottom.

## Testing

To test Skyblock mode:

1. Start the server
2. Join as first player (you become owner)
3. You'll spawn on a small floating island
4. One tree in the center
5. Void all around
6. Build outward carefully!

## Notes

- **Fall death:** Players who fall off respawn on the island
- **No ground:** There's no bedrock or ground layer below
- **Void color:** The sky extends infinitely down
- **Build limit:** Players can build up to Y=255
- **Expansion:** Players can place blocks outward to expand the island

