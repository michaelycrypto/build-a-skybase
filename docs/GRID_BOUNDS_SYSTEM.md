# Grid Bounds System

## Overview

The Grid Bounds System provides precise control over when player grids are rendered based on strict geometric boundaries. Unlike the proximity-based system that uses distance thresholds, the bounds system uses exact grid boundaries to determine when a player enters or exits a grid area.

## Key Features

### **Precise Boundary Control**
- **Exact Grid Boundaries**: Uses precise geometric calculations based on grid size and tile dimensions
- **Tolerance System**: Configurable tolerance zone around boundaries for smoother transitions
- **Real-time Tracking**: Continuous monitoring of player position relative to grid bounds

### **Performance Optimization**
- **Conditional Rendering**: Only renders grids when player is inside bounds
- **Efficient Bounds Checking**: Optimized algorithms for boundary intersection testing
- **Throttled Updates**: Configurable update intervals to prevent excessive calculations

### **Integration with Existing Systems**
- **ProximityGridManager Integration**: Seamlessly works with existing proximity-based rendering
- **Event-Driven Architecture**: Uses EventManager for loose coupling between systems
- **Fallback Support**: Gracefully degrades when bounds system is unavailable

## Architecture

### **Client-Side Components**

#### **GridBoundsManager.lua**
- **Purpose**: Manages grid bounds tracking and player position monitoring
- **Key Features**:
  - Real-time bounds checking via `RunService.Heartbeat`
  - Configurable tolerance zones for smoother transitions
  - Debug visualization support for development
  - Event-driven communication with ProximityGridManager

#### **ProximityGridManager.lua (Enhanced)**
- **New Features**:
  - Bounds system integration with `USE_BOUNDS_SYSTEM` configuration
  - Event handlers for bounds enter/exit events
  - Toggle between proximity and bounds-based rendering
  - Automatic fallback to proximity system when bounds system is disabled

### **Server-Side Components**

#### **GridBoundsService.lua**
- **Purpose**: Server-side coordination of grid bounds data
- **Key Features**:
  - Grid bounds creation and management
  - Client synchronization of bounds data
  - Player bounds state tracking
  - Statistics and monitoring capabilities

#### **WorldService.lua (Enhanced)**
- **Integration**: Automatically creates grid bounds when creating player grids
- **Cleanup**: Properly removes bounds data when players leave
- **Coordination**: Works with both ProximityGridService and GridBoundsService

## Configuration

### **Client Configuration (GridBoundsManager)**

```lua
local BOUNDS_CONFIG = {
    -- Bounds checking settings
    CHECK_INTERVAL = 0.5, -- How often to check bounds (seconds)
    BOUNDS_TOLERANCE = 2, -- Extra distance beyond grid bounds (studs)

    -- Grid settings
    DEFAULT_TILE_SIZE = 3, -- 3x3 studs per tile
    DEFAULT_GRID_SIZE = {width = 21, height = 21},

    -- Performance settings
    MAX_BOUNDS_CHECKS_PER_FRAME = 5,
    BATCH_SIZE = 3,

    -- Visual feedback settings
    SHOW_BOUNDS_DEBUG = false, -- Show visual bounds indicators
    BOUNDS_DEBUG_COLOR = Color3.fromRGB(255, 255, 0),
    BOUNDS_DEBUG_TRANSPARENCY = 0.7,
}
```

### **ProximityGridManager Integration**

```lua
local PROXIMITY_CONFIG = {
    -- ... existing configuration ...

    -- Bounds system integration
    USE_BOUNDS_SYSTEM = true, -- Enable integration with GridBoundsManager
    BOUNDS_OVERRIDE_PROXIMITY = true, -- Bounds system overrides proximity-based rendering
}
```

## Usage Examples

### **Basic Setup**

The system is automatically initialized when the client starts. No additional setup is required for basic functionality.

### **Manual Grid Bounds Management**

```lua
-- Get GridBoundsManager instance
local GridBoundsManager = require(script.Parent.Managers.GridBoundsManager)

-- Add a grid with bounds
GridBoundsManager:AddGrid(
    "my_grid_1",
    Vector3.new(0, 0, 0), -- Center position
    {width = 21, height = 21}, -- Grid size
    3 -- Tile size
)

-- Check if player is inside a specific grid
local isInside = GridBoundsManager:IsPlayerInsideGrid("my_grid_1")

-- Get all grids player is currently inside
local insideGrids = GridBoundsManager:GetInsideGrids()
```

### **Debug Visualization**

```lua
-- Enable debug visualization to see grid bounds
GridBoundsManager:ToggleDebugVisuals()

-- Force check all bounds (for debugging)
GridBoundsManager:ForceCheckBounds()
```

### **Integration with ProximityGridManager**

```lua
-- Get ProximityGridManager instance
local ProximityGridManager = require(script.Parent.Managers.ProximityGridManager)

-- Check if bounds system is enabled
local boundsEnabled = ProximityGridManager:IsBoundsSystemEnabled()

-- Toggle bounds system on/off
ProximityGridManager:ToggleBoundsSystem()

-- Get GridBoundsManager instance
local boundsManager = ProximityGridManager:GetGridBoundsManager()
```

## Event System

### **Client Events**

#### **PlayerEnteredGridBounds**
- **Triggered**: When player enters grid bounds
- **Data**: `{gridId, gridBounds, playerPosition, timestamp}`
- **Usage**: ProximityGridManager starts rendering the grid

#### **PlayerExitedGridBounds**
- **Triggered**: When player exits grid bounds
- **Data**: `{gridId, gridBounds, playerPosition, timestamp}`
- **Usage**: ProximityGridManager stops rendering the grid

### **Server Events**

#### **PlayerBoundsUpdate**
- **Triggered**: Client sends bounds state to server
- **Data**: `{insideGrids, outsideGrids, playerPosition, timestamp}`
- **Usage**: Server tracks player bounds state

#### **GridBoundsAdded/Removed/Updated**
- **Triggered**: Server notifies clients of bounds changes
- **Data**: Grid bounds information
- **Usage**: Clients update their bounds tracking

## Performance Considerations

### **Optimization Features**

1. **Throttled Updates**: Bounds checking is limited to configurable intervals
2. **Batch Processing**: Multiple grids are checked in batches to prevent frame drops
3. **Efficient Algorithms**: Optimized geometric calculations for boundary testing
4. **Event-Driven**: Only processes changes when player state actually changes

### **Memory Management**

1. **Automatic Cleanup**: Grid bounds are automatically removed when players leave
2. **Debug Visual Cleanup**: Debug visuals are properly destroyed when disabled
3. **Connection Management**: All event connections are properly cleaned up

### **Performance Monitoring**

```lua
-- Get service statistics
local stats = GridBoundsService:GetStats()
print("Total grids:", stats.totalGrids)
print("Players with inside grids:", stats.playersWithInsideGrids)
```

## Comparison: Proximity vs Bounds

| Feature | Proximity System | Bounds System |
|---------|------------------|---------------|
| **Trigger Method** | Distance-based (50-60 studs) | Geometric boundary intersection |
| **Precision** | Approximate (distance thresholds) | Exact (boundary calculations) |
| **Performance** | Good (simple distance checks) | Excellent (optimized geometry) |
| **Flexibility** | Limited (circular areas) | High (any rectangular area) |
| **Use Case** | General proximity rendering | Precise area control |

## Migration Guide

### **From Proximity to Bounds**

1. **Enable Bounds System**: Set `USE_BOUNDS_SYSTEM = true` in ProximityGridManager
2. **Configure Override**: Set `BOUNDS_OVERRIDE_PROXIMITY = true` to use bounds instead of proximity
3. **Test Integration**: Verify that grids render/unrender based on bounds
4. **Adjust Tolerance**: Configure `BOUNDS_TOLERANCE` for smooth transitions

### **Hybrid Approach**

You can use both systems simultaneously:
- Set `USE_BOUNDS_SYSTEM = true` but `BOUNDS_OVERRIDE_PROXIMITY = false`
- Bounds system provides additional precision while proximity system handles general cases

## Troubleshooting

### **Common Issues**

1. **Grids Not Rendering**: Check if bounds system is enabled and properly initialized
2. **Performance Issues**: Reduce `CHECK_INTERVAL` or increase `BATCH_SIZE`
3. **Inconsistent Behavior**: Verify tolerance settings and grid size calculations

### **Debug Tools**

1. **Enable Debug Visualization**: `GridBoundsManager:ToggleDebugVisuals()`
2. **Force Bounds Check**: `GridBoundsManager:ForceCheckBounds()`
3. **Check System Status**: `ProximityGridManager:IsBoundsSystemEnabled()`

### **Logging**

The system provides comprehensive logging:
- Grid creation and removal
- Player bounds state changes
- System initialization and cleanup
- Performance statistics

## Future Enhancements

### **Planned Features**

1. **Dynamic Bounds**: Support for moving or resizing grids
2. **Complex Shapes**: Support for non-rectangular grid boundaries
3. **Multi-Layer Bounds**: Support for overlapping grid areas
4. **Advanced Visualization**: More sophisticated debug tools

### **Integration Opportunities**

1. **AI Systems**: Use bounds for AI behavior triggers
2. **Spawn Systems**: Control entity spawning based on player bounds
3. **Audio Systems**: Spatial audio based on grid boundaries
4. **UI Systems**: Context-sensitive UI based on player location

## Conclusion

The Grid Bounds System provides a robust, performant solution for precise grid rendering control. It seamlessly integrates with existing systems while offering superior precision and flexibility compared to distance-based approaches. The event-driven architecture ensures loose coupling and easy extensibility for future enhancements.
