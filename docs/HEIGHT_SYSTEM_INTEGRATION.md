# Dynamic Height System Integration Guide

This document explains how to integrate and use the new dynamic height-based world generation system.

## Overview

The new system replaces the flat 2D grid with a dynamic height-based system where:
- Each tile has a base height value (ground elevation)
- Objects can be placed at various heights with collision detection
- Pathfinding considers height differences and walkability rules
- Players have individual grids with height variations

## System Architecture

### Core Components

1. **HeightTile** - Individual tile with base height and object storage
2. **HeightGrid** - Grid of HeightTiles with height management
3. **HeightTileService** - Service managing height grids and world state
4. **ObjectPlacementService** - Height-aware object placement
5. **HeightAwarePathfindingService** - A* pathfinding with height rules
6. **HeightUtils** - Utility functions for calculations

### Key Features

- **Base Height Concept**: Each tile (x, z) has a base height representing ground elevation
- **Object Placement**: Objects can be placed at arbitrary heights with collision detection
- **Walkability Rules**: Movement allowed for height differences ≤ 1 tile (5 studs)
- **Procedural Generation**: Height maps with ramps, hills, and cliffs
- **Player Grids**: Individual 21x21 grids for each player with terrain variations

## Integration Steps

### 1. Replace WorldService

Replace the existing `WorldService.lua` with `WorldService_New.lua`:

```lua
-- In your service initialization
local WorldService = require(script.Parent.WorldService_New)
```

### 2. Update Service Dependencies

Add the new services to your service manager:

```lua
-- In your service initialization
local HeightTileService = require(script.Parent.HeightTileService)
local ObjectPlacementService = require(script.Parent.ObjectPlacementService)
local HeightAwarePathfindingService = require(script.Parent.HeightAwarePathfindingService)

-- Set up dependencies
HeightTileService.Deps = {}
ObjectPlacementService.Deps.HeightTileService = HeightTileService
HeightAwarePathfindingService.Deps.HeightTileService = HeightTileService
```

### 3. Update Client Grid Manager

Replace `DungeonGridManager.lua` with `DungeonGridManager_New.lua`:

```lua
-- In your client initialization
local DungeonGridManager = require(script.Parent.DungeonGridManager_New)
```

## Usage Examples

### Basic World Initialization

```lua
-- Initialize the world with height variations
local worldService = WorldService.new()
worldService:Init()

-- Initialize with custom height map
local heightMap = {
    {0, 1, 2, 1, 0}, -- Example 5x5 height map
    {1, 2, 3, 2, 1},
    {2, 3, 4, 3, 2},
    {1, 2, 3, 2, 1},
    {0, 1, 2, 1, 0}
}

worldService:InitializeWorld(heightMap)
```

### Player Grid Creation

```lua
-- Create a player grid with hilly terrain
worldService:CreatePlayerGrid(player, "hilly")

-- Available terrain types:
-- "flat" - No height variation
-- "hilly" - Gentle slopes and hills
-- "mountainous" - Steep height variations
-- "valley" - Lower center with raised edges
```

### Object Placement

```lua
-- Place a spawner at a specific height
local objectId, success = objectPlacementService:PlaceObject(
    player,                    -- Player
    "spawner",                 -- Object type
    Vector3.new(10, 0, 10),   -- World position
    0,                         -- Rotation
    3                          -- Custom height (optional)
)

if success then
    print("Object placed successfully:", objectId)
else
    print("Failed to place object")
end
```

### Pathfinding

```lua
-- Find path between two points with height awareness
local path = pathfindingService:FindPath(
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

### Height Visualization

```lua
-- On the client side
local gridManager = DungeonGridManager.new()
gridManager:Initialize()

-- Toggle height visualization
gridManager:ToggleHeightVisualization(true)

-- Show object placement preview
gridManager:ShowPlacementPreview(5, 5, 2, "tower", 5, true)
```

## Configuration

### Height System Configuration

```lua
-- In HeightUtils.lua
local CONFIG = {
    TILE_SIZE = 5,        -- 5x5 studs per tile
    MAX_HEIGHT = 100,     -- Maximum height in studs
    MIN_HEIGHT = -10,     -- Minimum height in studs
    HEIGHT_STEP = 1,      -- Height increment in studs
    WALKABILITY_THRESHOLD = 1 -- Height difference threshold
}
```

### Pathfinding Configuration

```lua
-- In HeightAwarePathfindingService.lua
local PATHFINDING_CONFIG = {
    MAX_HEIGHT_DIFFERENCE = 5,  -- Max height diff for movement
    DIAGONAL_COST = 1.414,      -- Cost for diagonal movement
    STRAIGHT_COST = 1,          -- Cost for straight movement
    HEIGHT_COST_MULTIPLIER = 0.5 -- Cost multiplier for height changes
}
```

## Walkability Rules

The system implements the following walkability rules:

1. **Height Difference**: Movement allowed if height difference ≤ 1 tile (5 studs)
2. **Object Collisions**: Objects block movement at their height level
3. **Surface Types**: Some surfaces (water, lava) are not walkable
4. **Pathfinding**: A* algorithm considers height costs and walkability

## Object Types

Supported object types with their properties:

```lua
local OBJECT_TYPES = {
    SPAWNER = {
        height = 3, width = 1, depth = 1,
        canFloat = false, requiresGround = true
    },
    TOWER = {
        height = 10, width = 1, depth = 1,
        canFloat = false, requiresGround = true
    },
    WALL = {
        height = 5, width = 1, depth = 1,
        canFloat = false, requiresGround = true
    },
    DECORATION = {
        height = 2, width = 1, depth = 1,
        canFloat = true, requiresGround = false
    },
    PLATFORM = {
        height = 1, width = 3, depth = 3,
        canFloat = true, requiresGround = false
    }
}
```

## Migration from Old System

### Data Migration

If you have existing world data, you'll need to migrate it:

```lua
-- Convert old flat grid to height-based grid
function migrateOldGrid(oldGridData)
    local heightMap = {}
    for x = 1, GRID_WIDTH do
        heightMap[x] = {}
        for z = 1, GRID_HEIGHT do
            -- Set all heights to 0 initially
            heightMap[x][z] = 0
        end
    end
    return heightMap
end
```

### Service Updates

Update any services that interact with the world:

```lua
-- Old way
local tile = worldService:GetTile(x, z)

-- New way
local tile = heightTileService:GetWorldGrid():GetTile(x, z)
local height = WorldService:GetGridY(player, x, z)
```

## Performance Considerations

1. **Height Map Size**: Large height maps can impact performance
2. **Object Count**: Many objects require more collision checking
3. **Pathfinding**: Complex height variations increase pathfinding time
4. **Visualization**: Height visualization can impact client performance

## Troubleshooting

### Common Issues

1. **Height Not Applied**: Ensure HeightTileService is initialized before use
2. **Pathfinding Fails**: Check height differences and walkability rules
3. **Object Placement Fails**: Verify collision detection and height constraints
4. **Visualization Missing**: Check if height visualization is enabled

### Debug Commands

```lua
-- Check if world is initialized
print("World initialized:", heightTileService:IsWorldInitialized())

-- Get height at position
local height = heightTileService:GetHighestWalkableHeight(x, z)
print("Height at", x, z, ":", height)

-- Check walkability
local walkable = heightTileService:IsWalkable(x, z, height)
print("Walkable:", walkable)
```

## Future Enhancements

Potential improvements to the system:

1. **Multi-level Pathfinding**: Support for bridges and tunnels
2. **Dynamic Height Changes**: Real-time terrain modification
3. **Advanced Terrain Types**: Snow, sand, mud with different properties
4. **Height-based Spawning**: Spawn objects at appropriate heights
5. **Weather Effects**: Height-based weather and environmental effects

## Conclusion

The new dynamic height system provides a flexible foundation for complex world generation with height variations, object placement, and intelligent pathfinding. The modular design allows for easy extension and customization while maintaining compatibility with existing systems.
