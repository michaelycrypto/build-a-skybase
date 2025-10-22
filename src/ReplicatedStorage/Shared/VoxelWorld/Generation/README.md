# Terrain Generation System

This directory contains the terrain generation system for the voxel engine.

## Generators

### PlainsTerrainGenerator.lua ⭐ NEW
**Simplified, focused plains terrain generator**

A clean, easy-to-understand terrain generator that creates beautiful Minecraft-style plains biomes.

**Features:**
- Gentle rolling hills (±6 block variation)
- Natural cave systems with 3D noise
- Proper ore distribution (8 ore types)
- Oak trees with leaf canopy
- Beach generation near water
- 100% seed-based deterministic

**Best for:**
- Simple worlds and prototypes
- Learning terrain generation
- Performance-critical applications
- Plains-only environments

**Usage:**
```lua
local PlainsTerrainGenerator = require(script.PlainsTerrainGenerator)
PlainsTerrainGenerator.GenerateChunk(chunk, { seed = 12345 })
```

**See:** `/PLAINS_TERRAIN_GUIDE.md` for full documentation

---

### TerrainGenerator.lua
**Advanced multi-biome terrain generator**

Full-featured terrain generation system matching Minecraft 1.18+ algorithms.

**Features:**
- Multiple biomes (plains, desert, forest, mountains, tundra, etc.)
- 3D density functions for realistic terrain
- Continentalness, erosion, peaks/valleys noise
- Multiple cave types (cheese, spaghetti, noodle)
- Aquifer system for underground water
- Complex ore distribution
- Biome-specific structures

**Best for:**
- Full-featured game worlds
- Varied terrain requirements
- Maximum realism and complexity

**Usage:**
```lua
local TerrainGenerator = require(script.TerrainGenerator)
TerrainGenerator.GenerateChunk(chunk, { seed = 12345 })
```

---

## Support Modules

### NoiseGenerator.lua
Multi-octave Perlin noise functions for terrain generation:
- Height noise (2D)
- 3D density functions
- Cave systems (cheese, spaghetti, noodle)
- Biome selection (temperature, humidity, weirdness)
- Continentalness, erosion, peaks/valleys

### BiomeManager.lua
Biome selection and properties system:
- Temperature and humidity-based biome selection
- Biome-specific blocks (grass, sand, snow, etc.)
- Height variations per biome
- Structure placement rules

### OreGenerator.lua
Ore vein placement system:
- Depth-aware ore distribution
- Minecraft-style ore veins
- Multiple ore types with different rarities

### StructureGenerator.lua
Natural structure placement:
- Trees (oak, birch, spruce, jungle, acacia)
- Boulders and rock formations
- Biome-specific decorations

### DensityFunction.lua
Advanced 3D density calculations for Minecraft 1.18+ terrain:
- Terrain squashing and stretching
- Overhang generation
- Cliff formation

### SpawnLocationManager.lua
Find safe spawn locations:
- Height-based spawn finding
- Avoid water and caves
- Deterministic spawn selection

## Quick Comparison

| Feature | PlainsTerrainGenerator | TerrainGenerator |
|---------|----------------------|------------------|
| **Lines of Code** | ~450 | ~1100+ |
| **Biomes** | 1 (Plains) | 15+ biomes |
| **Generation Speed** | Fast (~5-10ms) | Slower (~15-30ms) |
| **Complexity** | Simple | Complex |
| **Memory Usage** | Low | Higher |
| **Ore Types** | 8 types | 8 types |
| **Cave Systems** | 1 type | 3 types |
| **Best Use Case** | Simple worlds | Full games |

## Which Generator Should I Use?

### Use PlainsTerrainGenerator if:
- ✅ You want simple, readable code
- ✅ You only need plains-style terrain
- ✅ Performance is critical
- ✅ You're prototyping or learning
- ✅ You want easy customization

### Use TerrainGenerator if:
- ✅ You need multiple biomes
- ✅ You want maximum realism
- ✅ You're building a full game
- ✅ You need varied terrain (mountains, oceans, deserts)
- ✅ You want Minecraft 1.18+ accuracy

## Configuration

Both generators use seed-based configuration:

```lua
local config = {
    seed = 12345  -- Any number, same seed = same world
}
```

For advanced configuration, see:
- **PlainsTerrainGenerator**: Edit `PLAINS_CONFIG` table in source
- **TerrainGenerator**: Edit `Config.TERRAIN` in `/Core/Config.lua`

## Examples

See `/examples/PlainsTerrainExample.lua` for comprehensive usage examples including:
- Basic generation
- Seed comparison
- Spawn location finding
- Block distribution analysis

## Testing

Both generators are tested via:
- `/Testing/TerrainGeneratorSpec.lua`
- `/Testing/WorldGenerationSpec.lua`

Run tests to verify terrain generation is working correctly.

## Performance Tips

1. **Generate chunks in batches** - Use task.defer between chunks
2. **Cache height values** - Both generators cache height internally
3. **Use spatial prioritization** - Generate closest chunks first
4. **Consider using PlainsTerrainGenerator** - 2-3x faster than full system

## Future Work

Potential enhancements:
- **Rivers and lakes** - Flowing water systems
- **Villages** - Procedural structure generation
- **Biome transitions** - Smooth blending between biomes (TerrainGenerator)
- **More tree types** - Variety in vegetation
- **Ravines** - Large surface cracks
- **Dungeons** - Underground structures

## Contributing

When adding new generators or features:
1. Follow existing code style
2. Add comprehensive comments
3. Include usage examples
4. Update this README
5. Add tests for new features

---

**Last Updated:** October 2025
**Maintainer:** Voxel Engine Team

