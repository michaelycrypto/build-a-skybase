# Dynamic Map & Object Height Logic - Clean Implementation

This document provides a comprehensive guide to the clean, engineered implementation of the dynamic map and object height logic system.

## Overview

The system implements all five core requirements:

1. **Base Height Concept** - Each tile (x, z) has a base height value representing ground elevation
2. **Tile & Object Interaction** - Objects can sit on tiles, float above, or overlap vertically
3. **Walkability Rules** - Movement allowed for height differences ≤ 1 tile (5 studs)
4. **Procedural Map Generation** - Height maps with ramps, hills, and cliffs
5. **Dynamic Object Placement** - Objects of any height can coexist on the map

## Architecture

### Core Components

```
HeightSystemManager (Central Manager)
├── DynamicHeightWorldService (World Management)
├── ObjectPlacementService (Object Placement)
├── HeightAwarePathfindingService (Pathfinding)
└── HeightGrid/HeightTile (Data Structures)
```

### Key Design Principles

1. **Separation of Concerns** - Each service has a single responsibility
2. **Dependency Injection** - Services are loosely coupled through dependencies
3. **Unified API** - Single entry point through HeightSystemManager
4. **Error Handling** - Comprehensive error handling and recovery
5. **Performance Monitoring** - Built-in performance tracking
6. **Extensibility** - Easy to add new features and terrain types

## Implementation Details

### 1. Base Height Concept

Each tile tracks its base height in studs:

```lua
-- Tile structure
{
    baseHeight = 0,        -- Ground elevation in studs
    surfaceType = "grass", -- Surface material type
    objects = {}           -- Objects placed at various heights
}
```

**Key Features:**
- Absolute elevation tracking (not relative layers)
- Support for negative heights (underground)
- Height variations up to ±8 studs by default
- Procedural generation with multiple algorithms

### 2. Tile & Object Interaction

Objects can be placed at arbitrary heights with collision detection:

```lua
-- Object placement with height awareness
local objectId, success = heightSystemManager:PlaceObject(
    player,           -- Player
    "tower",          -- Object type
    Vector3.new(10, 0, 10), -- World position
    0,                -- Rotation
    3                 -- Custom height (optional)
)
```

**Collision Detection:**
- Vertical overlap checking
- Multi-tile object support
- Height-based placement validation
- Object stacking capabilities

### 3. Walkability Rules

Movement is determined by height differences:

```lua
-- Check if movement is possible
local canMove = heightSystemManager:IsWalkable(player, fromX, fromZ, toX, toZ)

-- Get all walkable neighbors
local neighbors = heightSystemManager:GetWalkableNeighbors(player, x, z)
```

**Rules:**
- Height difference ≤ 5 studs (1 tile) = walkable
- Height difference > 5 studs = impassable
- Objects block movement at their height level
- Surface types affect walkability (water, lava = not walkable)

### 4. Procedural Map Generation

Multiple terrain generation algorithms:

```lua
-- Create player grid with terrain type
heightSystemManager:CreatePlayerGrid(player, "hilly")

-- Available terrain types:
-- "flat" - No height variation
-- "hilly" - Gentle slopes and hills
-- "mountainous" - Steep height variations
-- "valley" - Lower center with raised edges
-- "ridged" - Mountain ranges
-- "voronoi" - Interesting patterns
-- "eroded" - Realistic weathering
-- "layered" - Complex multi-feature terrain
```

**Generation Algorithms:**
- **Perlin Noise** - Multi-octave realistic terrain
- **Ridged Noise** - Sharp mountain ranges
- **Distance-based** - Multiple peaks creating valleys
- **Voronoi** - Cellular patterns
- **Erosion** - Weathering simulation
- **Layered** - Combined multiple features

### 5. Dynamic Object Placement

Objects of any size can coexist:

```lua
-- Object types with properties
local OBJECT_TYPES = {
    SPAWNER = {
        height = 3, width = 1, depth = 1,
        canFloat = false, requiresGround = true
    },
    TOWER = {
        height = 10, width = 1, depth = 1,
        canFloat = false, requiresGround = true
    },
    PLATFORM = {
        height = 1, width = 3, depth = 3,
        canFloat = true, requiresGround = false
    }
}
```

**Placement Features:**
- Height-aware collision detection
- Multi-tile object support
- Floating object capabilities
- Ground-required objects
- Automatic height calculation

## Usage Examples

### Basic Setup

```lua
-- Initialize the height system
local HeightSystemManager = require(script.Parent.HeightSystemManager)
local heightSystemManager = HeightSystemManager.new()
heightSystemManager:Init()

-- Create a player grid
heightSystemManager:CreatePlayerGrid(player, "hilly")
```

### Object Placement

```lua
-- Place a tower at a specific location
local objectId, success = heightSystemManager:PlaceObject(
    player,
    "tower",
    Vector3.new(25, 0, 25), -- World position
    0, -- Rotation
    nil -- Use automatic height calculation
)

if success then
    print("Tower placed successfully:", objectId)
else
    print("Failed to place tower")
end
```

### Pathfinding

```lua
-- Find path between two points
local path = heightSystemManager:FindPath(
    1, 1, 0,    -- Start: x, z, height
    10, 10, 2,  -- End: x, z, height
    player      -- Player (optional for world grid)
)

if path then
    print("Path found with", #path, "nodes")
    for i, node in ipairs(path) do
        print(string.format("Node %d: (%d, %d, %.1f)",
            i, node.x, node.z, node.height))
    end
else
    print("No path found")
end
```

### Movement Validation

```lua
-- Check if movement is possible
local canMove = heightSystemManager:IsWalkable(player, 5, 5, 6, 5)
if canMove then
    print("Movement allowed")
else
    print("Movement blocked by height difference")
end

-- Get walkable neighbors
local neighbors = heightSystemManager:GetWalkableNeighbors(player, 5, 5)
print("Walkable neighbors:", #neighbors)
```

## Integration with Existing Systems

### Service Initialization

```lua
-- In your main service initialization
local HeightSystemManager = require(script.Parent.HeightSystemManager)

-- Initialize the height system
local heightSystemManager = HeightSystemManager.new()
heightSystemManager:Init()

-- Make it available to other services
_G.HeightSystemManager = heightSystemManager
```

### Player Management

```lua
-- Handle player joining
game.Players.PlayerAdded:Connect(function(player)
    -- Create player grid with default terrain
    heightSystemManager:CreatePlayerGrid(player, "flat")
end)

-- Handle player leaving
game.Players.PlayerRemoving:Connect(function(player)
    -- Clean up player data
    heightSystemManager:CleanupPlayer(player)
end)
```

### Object Management

```lua
-- Place objects based on game logic
local function placeSpawner(player, position)
    local objectId, success = heightSystemManager:PlaceObject(
        player, "spawner", position, 0
    )

    if success then
        -- Object placed successfully
        return objectId
    else
        -- Handle placement failure
        return nil
    end
end

-- Remove objects
local function removeObject(player, objectId)
    local success = heightSystemManager:RemoveObject(player, objectId)
    return success
end
```

## Performance Considerations

### Optimization Features

1. **Performance Monitoring** - Built-in tracking of operations
2. **Pathfinding Cache** - Cached pathfinding results
3. **Object Limits** - Configurable limits per player
4. **Error Handling** - Retry mechanisms for failed operations

### Monitoring

```lua
-- Get performance statistics
local stats = heightSystemManager:GetPerformanceStats()
print("Object placements:", stats.objectPlacements)
print("Pathfinding requests:", stats.pathfindingRequests)
print("Errors:", stats.errors)
```

### Cache Management

```lua
-- Clear pathfinding cache if needed
heightSystemManager:ClearPathfindingCache()
```

## Configuration

### System Configuration

```lua
-- Grid settings
GRID_WIDTH = 13,
GRID_HEIGHT = 13,
TILE_SIZE = 5, -- 5x5 studs per tile

-- Height system settings
MAX_HEIGHT_DIFFERENCE = 5, -- Maximum height difference for walkability
DEFAULT_BASE_HEIGHT = 0,
MAX_HEIGHT_VARIATION = 8, -- Maximum height variation in studs
```

### Object Types

```lua
-- Add new object types
local newObjectType = {
    height = 5, width = 2, depth = 2,
    canFloat = false, requiresGround = true
}

-- Modify existing types in CONFIG.OBJECT_TYPES
```

### Terrain Types

```lua
-- Add new terrain generation algorithms
local newTerrainGenerator = function(width, height, scale, amplitude, seed)
    -- Custom terrain generation logic
    return heightMap
end

-- Add to HeightGenerators table
```

## Error Handling

### Built-in Error Handling

The system includes comprehensive error handling:

1. **Retry Mechanisms** - Failed operations are retried up to 3 times
2. **Error Logging** - All errors are logged with context
3. **Graceful Degradation** - System continues operating even with errors
4. **Performance Impact** - Error handling has minimal performance impact

### Custom Error Handling

```lua
-- Wrap operations with custom error handling
local success, result = pcall(function()
    return heightSystemManager:PlaceObject(player, "tower", position, 0)
end)

if not success then
    -- Handle error
    print("Placement failed:", result)
end
```

## Testing

### Unit Testing

```lua
-- Test basic functionality
local function testBasicFunctionality()
    local player = game.Players.LocalPlayer

    -- Test grid creation
    local success = heightSystemManager:CreatePlayerGrid(player, "flat")
    assert(success, "Grid creation failed")

    -- Test object placement
    local objectId, success = heightSystemManager:PlaceObject(
        player, "tower", Vector3.new(10, 0, 10), 0
    )
    assert(success, "Object placement failed")

    -- Test object removal
    local success = heightSystemManager:RemoveObject(player, objectId)
    assert(success, "Object removal failed")

    print("All tests passed!")
end
```

### Performance Testing

```lua
-- Test performance with many objects
local function testPerformance()
    local player = game.Players.LocalPlayer
    local startTime = tick()

    -- Place many objects
    for i = 1, 100 do
        heightSystemManager:PlaceObject(
            player, "decoration",
            Vector3.new(i % 21 * 5, 0, math.floor(i / 21) * 5), 0
        )
    end

    local endTime = tick()
    print("Placed 100 objects in", endTime - startTime, "seconds")
end
```

## Future Enhancements

### Planned Features

1. **Multi-level Pathfinding** - Support for bridges and tunnels
2. **Dynamic Height Changes** - Real-time terrain modification
3. **Advanced Terrain Types** - Snow, sand, mud with different properties
4. **Height-based Spawning** - Spawn objects at appropriate heights
5. **Weather Effects** - Height-based weather and environmental effects

### Extension Points

The system is designed for easy extension:

1. **New Terrain Types** - Add custom generation algorithms
2. **New Object Types** - Add custom object definitions
3. **New Surface Types** - Add custom surface materials
4. **Custom Pathfinding** - Override pathfinding behavior
5. **Performance Optimizations** - Add custom caching strategies

## Conclusion

This clean implementation provides a robust, extensible foundation for dynamic map and object height logic. The modular design ensures maintainability while the comprehensive API makes it easy to integrate with existing systems. The built-in performance monitoring and error handling ensure reliable operation in production environments.

The system successfully implements all five core requirements while providing additional features for enhanced gameplay and system reliability.
