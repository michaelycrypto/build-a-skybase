# Proximity Grid System

## Overview

The Proximity Grid System is a performance-optimized grid rendering solution that simulates grid data and only renders visual elements when the player enters the proximity area. This system significantly improves performance by avoiding unnecessary rendering of distant grids.

## Key Features

- **Proximity-based Rendering**: Only renders grids when player is within a specified distance
- **Grid Simulation**: Maintains grid data without visual rendering for distant grids
- **Efficient Memory Management**: Automatically manages rendered grid limits
- **Seamless Integration**: Works with existing grid managers (PlayerBaseManager, DungeonGridManager)
- **Real-time Updates**: Synchronizes grid data between server and clients
- **Configurable Performance**: Adjustable render distances and update intervals

## Architecture

### Client-Side Components

1. **ProximityGridManager** (`/src/StarterPlayerScripts/Client/Managers/ProximityGridManager.lua`)
   - Manages proximity detection and grid rendering
   - Handles grid simulation data
   - Controls visual object creation/destruction

2. **GridIntegrationManager** (`/src/StarterPlayerScripts/Client/Managers/GridIntegrationManager.lua`)
   - Integrates with existing grid managers
   - Provides backward compatibility
   - Manages integration modes (proximity, legacy, hybrid)

3. **ProximityGridBootstrap** (`/src/StarterPlayerScripts/Client/Bootstrap/ProximityGridBootstrap.lua`)
   - Initializes the client-side system
   - Handles auto-initialization and error recovery

### Server-Side Components

1. **ProximityGridService** (`/src/ServerScriptService/Server/Services/ProximityGridService.lua`)
   - Manages grid data on the server
   - Coordinates with client-side proximity rendering
   - Handles grid creation, updates, and synchronization

2. **ProximityGridServerBootstrap** (`/src/ServerScriptService/Server/Bootstrap/ProximityGridServerBootstrap.lua`)
   - Initializes the server-side system
   - Creates sample grids for testing

## Configuration

### Client-Side Configuration

```lua
local PROXIMITY_CONFIG = {
    -- Proximity detection settings
    RENDER_DISTANCE = 50, -- Distance in studs to start rendering
    UNRENDER_DISTANCE = 60, -- Distance in studs to stop rendering (hysteresis)
    UPDATE_INTERVAL = 0.5, -- How often to check proximity (seconds)

    -- Performance settings
    MAX_RENDERED_GRIDS = 5, -- Maximum number of grids to render simultaneously
    BATCH_SIZE = 10, -- Number of tiles to process per frame

    -- Visual settings
    FADE_DURATION = 0.3, -- Duration for fade in/out animations
    FADE_DISTANCE = 10, -- Distance over which to fade
}
```

### Server-Side Configuration

```lua
local SERVICE_CONFIG = {
    -- Grid management settings
    MAX_GRIDS_PER_PLAYER = 10,
    GRID_UPDATE_INTERVAL = 1.0, -- How often to send updates to clients
    DATA_SYNC_INTERVAL = 0.5, -- How often to sync data with clients

    -- Performance settings
    BATCH_UPDATE_SIZE = 5, -- Number of grids to update per batch
    MAX_CONCURRENT_UPDATES = 3, -- Maximum concurrent grid updates
}
```

## Usage

### Basic Setup

The system automatically initializes when the game starts. No manual setup is required for basic functionality.

### Creating Grids

#### Server-Side
```lua
local ProximityGridService = require(ReplicatedStorage.Server.Services.ProximityGridService)

-- Create a new grid
local success = ProximityGridService:CreateGrid(
    "my_grid_1",                    -- Grid ID
    Vector3.new(0, 0, 0),          -- Center position
    {width = 21, height = 21},      -- Grid size
    3                               -- Tile size
)
```

#### Client-Side
```lua
local ProximityGridManager = require(ReplicatedStorage.Client.Managers.ProximityGridManager)

-- Add a grid to the proximity system
ProximityGridManager:AddGrid(
    "my_grid_1",                    -- Grid ID
    Vector3.new(0, 0, 0),          -- Center position
    {width = 21, height = 21},      -- Grid size
    3                               -- Tile size
)
```

### Integration Modes

The system supports three integration modes:

1. **Proximity Mode**: Uses only the proximity system
2. **Legacy Mode**: Uses only existing grid managers
3. **Hybrid Mode**: Uses both systems with intelligent switching

```lua
local GridIntegrationManager = require(ReplicatedStorage.Client.Managers.GridIntegrationManager)

-- Set integration mode
GridIntegrationManager:SetIntegrationMode("proximity")
```

### Grid Interaction

```lua
-- Update grid data
ProximityGridManager:UpdateGridData(gridId, {
    tiles = updatedTileData,
    heightMap = updatedHeightMap,
    objects = updatedObjectData
})

-- Force render a specific grid (for debugging)
ProximityGridManager:ForceRenderGrid(gridId)

-- Force unrender a specific grid (for debugging)
ProximityGridManager:ForceUnrenderGrid(gridId)
```

## Performance Benefits

### Before (Traditional Rendering)
- All grids rendered simultaneously
- High memory usage
- Poor performance with many grids
- No distance-based optimization

### After (Proximity System)
- Only nearby grids rendered
- Reduced memory usage
- Better performance with many grids
- Distance-based rendering optimization
- Automatic grid limit management

## Event System

The system uses a comprehensive event system for communication:

### Client Events
- `GridRendered`: Fired when a grid starts rendering
- `GridUnrendered`: Fired when a grid stops rendering
- `GridDataUpdated`: Fired when grid data is updated

### Server Events
- `ServerGridCreated`: Sent when a new grid is created
- `ServerGridUpdated`: Sent when grid data is updated
- `ServerGridRemoved`: Sent when a grid is removed

## Debugging

### Enable Debug Logging
```lua
local ProximityGridBootstrap = require(ReplicatedStorage.Client.Bootstrap.ProximityGridBootstrap)

ProximityGridBootstrap:UpdateConfig({
    ENABLE_DEBUG_LOGGING = true
})
```

### Force Render/Unrender
```lua
-- Force render a specific grid
ProximityGridManager:ForceRenderGrid("my_grid_1")

-- Force unrender a specific grid
ProximityGridManager:ForceUnrenderGrid("my_grid_1")
```

### Get System Status
```lua
-- Get all rendered grids
local renderedGrids = ProximityGridManager:GetRenderedGrids()

-- Get grid simulation data
local simulation = ProximityGridManager:GetGridSimulation("my_grid_1")

-- Get integration mode
local mode = GridIntegrationManager:GetIntegrationMode()
```

## Best Practices

1. **Grid ID Naming**: Use descriptive, unique grid IDs
2. **Performance Tuning**: Adjust render distances based on your game's needs
3. **Memory Management**: Monitor the number of rendered grids
4. **Integration Mode**: Choose the appropriate mode for your use case
5. **Error Handling**: Always check return values from grid operations

## Troubleshooting

### Common Issues

1. **Grids Not Rendering**
   - Check if player is within render distance
   - Verify grid data is properly initialized
   - Check for errors in the console

2. **Performance Issues**
   - Reduce MAX_RENDERED_GRIDS
   - Increase UPDATE_INTERVAL
   - Check for memory leaks

3. **Integration Problems**
   - Verify all managers are properly initialized
   - Check integration mode settings
   - Ensure event handlers are registered

### Debug Commands

```lua
-- Get system configuration
local config = ProximityGridManager:GetConfig()

-- Get active managers
local managers = GridIntegrationManager:GetActiveManagers()

-- Get grid mappings
local mappings = GridIntegrationManager:GetGridMappings()
```

## Future Enhancements

- **LOD System**: Different levels of detail based on distance
- **Streaming**: Progressive loading of grid data
- **Caching**: Intelligent caching of grid data
- **Predictive Rendering**: Pre-render grids player is moving towards
- **Dynamic Optimization**: Automatic performance tuning based on system load

## API Reference

### ProximityGridManager

#### Methods
- `Initialize()`: Initialize the manager
- `AddGrid(gridId, centerPosition, size, tileSize)`: Add a grid
- `RemoveGrid(gridId)`: Remove a grid
- `UpdateGridData(gridId, gridData)`: Update grid data
- `ForceRenderGrid(gridId)`: Force render a grid
- `ForceUnrenderGrid(gridId)`: Force unrender a grid
- `GetRenderedGrids()`: Get all rendered grids
- `GetGridSimulation(gridId)`: Get grid simulation data
- `GetConfig()`: Get configuration
- `UpdateConfig(newConfig)`: Update configuration
- `Destroy()`: Cleanup and destroy

### ProximityGridService

#### Methods
- `Initialize()`: Initialize the service
- `CreateGrid(gridId, centerPosition, size, tileSize)`: Create a grid
- `RemoveGrid(gridId)`: Remove a grid
- `GetGridData(gridId)`: Get grid data
- `GetAllGridIds()`: Get all grid IDs
- `GetPlayerGridState(player)`: Get player grid state
- `GetConfig()`: Get configuration
- `UpdateConfig(newConfig)`: Update configuration
- `Destroy()`: Cleanup and destroy

### GridIntegrationManager

#### Methods
- `Initialize()`: Initialize the manager
- `SetIntegrationMode(mode)`: Set integration mode
- `CreateGrid(gridId, gridData)`: Create a grid
- `UpdateGrid(gridId, gridData)`: Update grid data
- `RemoveGrid(gridId)`: Remove a grid
- `GetIntegrationMode()`: Get current integration mode
- `GetActiveManagers()`: Get active managers
- `GetGridMappings()`: Get grid mappings
- `GetConfig()`: Get configuration
- `UpdateConfig(newConfig)`: Update configuration
- `Destroy()`: Cleanup and destroy
