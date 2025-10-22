# Centralized Mob Animation System

## Overview

This system replaces the inefficient per-mob animation scripts with a single, centralized client-side animation handler. Instead of each mob having its own animation script (which was very resource-intensive), one script handles animations for all mobs in the game.

## Table of Contents
- [Overview](#overview)
- [Key benefits](#key-benefits)
- [Architecture](#architecture)
- [Configuration](#configuration)
- [Usage](#usage)
- [Adding new mob types](#adding-new-mob-types)
- [Troubleshooting](#troubleshooting)
- [Migration from old system](#migration-from-old-system)
- [Performance impact](#performance-impact)
- [Future enhancements](#future-enhancements)
- [Related docs](#related-docs)

## Key Benefits

### Performance Improvements
- **Single Script**: One client script handles all mob animations instead of hundreds of individual scripts
- **Efficient Tracking**: Mobs are tracked centrally with automatic cleanup
- **Smart Caching**: Animation assets are preloaded and cached for better performance
- **Connection Management**: Proper cleanup of connections prevents memory leaks

### Maintainability
- **Centralized Logic**: All animation logic is in one place, making it easy to update
- **Configuration-Driven**: Easy to customize animations without touching code
- **Debug Tools**: Built-in debugging and monitoring capabilities
- **Mob-Specific Overrides**: Different mob types can have unique animations

## Architecture

### Core Components

1. **MobAnimationHandler.client.lua** - Main animation handler
2. **MobAnimationConfig.lua** - Configuration for animations and performance
3. **Debug Commands** - F4 key shows animation debug info

### How It Works

1. **Detection**: The script monitors `Workspace` for models with `IsMob = true` attribute
2. **Registration**: When a mob spawns, it gets registered for animation handling
3. **Event Binding**: Humanoid events (Running, Jumping, etc.) are connected
4. **Animation Management**: Animations are played based on humanoid state changes
5. **Cleanup**: When mobs are destroyed, connections are properly cleaned up

## Configuration

### Performance Settings (`MobAnimationConfig.Performance`)

```lua
Performance = {
    UpdateInterval = 0.1,           -- Animation update frequency
    MaxAnimationDistance = 200,     -- Max distance to animate mobs
    CleanupInterval = 5,            -- How often to cleanup destroyed mobs
    PreloadAnimations = true,       -- Preload animations for better performance
    MaxSimultaneousMobs = 50        -- Max mobs to animate at once
}
```

### Animation Configuration

#### Default Animations
All mobs use default animations defined in `DefaultAnimations` table:

```lua
DefaultAnimations = {
    idle = { { id = "rbxassetid://507766388", weight = 9 } },
    walk = { { id = "rbxassetid://507777826", weight = 10 } },
    -- ... more animations
}
```

#### Mob-Specific Overrides
You can override animations for specific mob types:

```lua
MobTypeAnimations = {
    Goblin = {
        idle = { { id = "rbxassetid://YOUR_GOBLIN_IDLE", weight = 10 } },
        -- walk, run, etc. will use defaults if not specified
    },
    Dragon = {
        walk = { { id = "rbxassetid://YOUR_DRAGON_WALK", weight = 10 } },
        -- Different walking animation for dragons
    }
}
```

### Animation Timing

Transition times and speed scales are configurable:

```lua
Timing = {
    JumpAnimDuration = 0.31,
    Transitions = {
        idle = 0.1,
        walk = 0.1,
        jump = 0.1,
        -- ... more transitions
    },
    SpeedScales = {
        walk = 15.0,    -- speed / scale = animation speed
        climb = 5.0,
        swim = 10.0
    }
}
```

## Usage

### Automatic Operation
The system works automatically once the script is loaded. No additional setup is required.

### Debug Commands
Press **F4** to see debug information:
- Total tracked mobs
- Mobs by type
- Mobs by pose/state

### Programmatic Access
The animation handler is available globally for debugging:

```lua
-- Get debug info
local debugInfo = _G.MobAnimationHandler:GetDebugInfo()
print("Tracked mobs:", debugInfo.trackedMobCount)
```

## Adding New Mob Types

1. **Create Mob Model**: Ensure your mob has a `Humanoid` and set `IsMob = true` attribute
2. **Set Mob Type**: Set `MobType` attribute to identify the mob type
3. **Configure Animations** (optional): Add mob-specific animations in `MobAnimationConfig`

Example mob setup:
```lua
-- In your mob spawning code
mob:SetAttribute("IsMob", true)
mob:SetAttribute("MobType", "Goblin")
-- Animation handler will automatically detect and manage this mob
```

## Troubleshooting

### Common Issues

1. **Mobs not animating**:
   - Check that mob has `IsMob = true` attribute
   - Ensure mob has a valid `Humanoid`
   - Verify animation IDs are correct

2. **Performance issues**:
   - Reduce `MaxSimultaneousMobs` in config
   - Increase `CleanupInterval` if needed
   - Disable `PreloadAnimations` if memory is limited

3. **Animation not playing**:
   - Check animation ID format (should be `rbxassetid://ID`)
   - Verify animation exists and is accessible
   - Check debug output for error messages

### Debug Output

Enable debug logging by setting:
```lua
Debug = {
    EnableDebugPrint = true,
    LogAnimationChanges = true,
    LogMobTracking = true
}
```

## Migration from Old System

To migrate from the old per-mob animation system:

1. **Remove Old Scripts**: Delete animation scripts from mob models
2. **Add Attributes**: Ensure mobs have `IsMob = true` and `MobType` attributes
3. **Update Configurations**: Move any custom animations to `MobAnimationConfig`
4. **Test**: Use F4 debug command to verify mobs are being tracked

## Performance Impact

### Before (Old System)
- Each mob: 1 script with multiple connections
- 100 mobs = 100 scripts + hundreds of connections
- No connection cleanup = memory leaks
- No animation caching = repeated asset loads

### After (New System)
- All mobs: 1 script with centralized management
- 100 mobs = 1 script + managed connections per mob
- Automatic cleanup = no memory leaks
- Smart caching = faster animation loading

**Expected Performance Improvement**: 80-90% reduction in script overhead and memory usage.

## Future Enhancements

Possible future improvements:
- Distance-based animation LOD (less detailed animations for distant mobs)
- Animation state interpolation for smoother transitions
- Custom animation events and triggers
- Animation synchronization for group behaviors
- Performance profiling and automatic optimization

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Client Architecture Guide](CLIENT_ARCHITECTURE_GUIDE.md)
- [Mob Spawning Implementation](MOB_SPAWNING_IMPLEMENTATION.md)
