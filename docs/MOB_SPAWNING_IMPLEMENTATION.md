# Mob Spawning Implementation

## Overview

This implementation adds periodic mob spawning functionality to the dungeon system. Mobs spawn in the tiles around spawners based on the spawner's configuration and spawn rate.

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Implementation details](#implementation-details)
- [Integration points](#integration-points)
- [Configuration](#configuration)
- [Usage](#usage)
- [Testing](#testing)
- [Future enhancements](#future-enhancements)
- [Technical notes](#technical-notes)
- [Related docs](#related-docs)

## Architecture

### Core Components

1. **MobService** - Main service responsible for mob spawning logic
2. **DungeonService Integration** - Automatically registers/unregisters spawners with MobService
3. **PlayerService Integration** - Cleans up mob data when players leave

### Key Features

- **Periodic Spawning**: Mobs spawn at configurable intervals (e.g., every 5-30 seconds)
- **Max Mob Limits**: Each spawner has a maximum number of mobs it can spawn
- **Mob Variety**: Different spawner types create different mob types with unique properties
- **Automatic Cleanup**: Mobs are automatically tracked and cleaned up when destroyed
- **Player Cleanup**: All mob data is cleaned up when players leave the game

## Implementation Details

### MobService (`src/ServerScriptService/Server/Services/MobService.lua`)

The MobService handles all mob spawning logic and follows the BaseService pattern:

#### Service Lifecycle:
- `new()` - Creates a new MobService instance with proper BaseService inheritance
- `Init()` - Initializes tracking tables and logger
- `Start()` - Starts the main spawning loop
- `Destroy()` - Cleans up all data and connections

#### Key Methods:
- `RegisterSpawner(player, slotIndex, spawnerType)` - Registers a spawner for mob spawning
- `UnregisterSpawner(player, slotIndex)` - Unregisters a spawner and cleans up mobs
- `GetActiveSpawners(player)` - Returns active spawner data for a player
- `GetSpawnedMobs(player)` - Returns spawned mob data for a player
- `CleanupPlayer(player)` - Cleans up all mob data for a leaving player

#### Spawning Logic:
- Runs a continuous loop that checks all active spawners every second
- Spawns 1-3 random mobs when the spawn rate timer expires and max mob count hasn't been reached
- Creates mob Parts with different properties based on mob type
- Positions mobs in random tiles around spawners (3x3 grid excluding spawner tile)
- Supports multiple spawners per player with intersecting spawn areas

#### Mob Creation:
- Creates basic Part objects with humanoids for movement
- Different mob types have different:
  - Colors (Goblin=Green, Orc=Red, Skeleton=White, etc.)
  - Sizes (Trolls and Dragons are larger)
  - Materials (Plastic, Concrete, Rock, Metal, etc.)
  - Health and damage values from spawner configuration

#### Spawn Positioning:
- Mobs spawn in tiles around spawners, not directly on spawner tiles
- Uses a 3x3 grid centered on the spawner (excluding the spawner tile itself)
- Randomly selects from available adjacent tiles for each spawn
- Spawns at a height of 2 studs above the tile surface
- **Tile Occupancy System**: Only one mob can occupy a tile at a time
- Multiple spawners can share spawn tiles, but tiles are exclusive to one mob

#### Spawn Quantity:
- Each spawner spawns 1-3 random mobs per spawn cycle
- Respects the maximum mob limit per spawner
- Stops spawning if max mobs reached
- Logs the number of mobs spawned per cycle

#### Tile Occupancy System:
- Each tile can only be occupied by one mob at a time
- Uses position-to-tile-key conversion for efficient tracking
- Automatically marks tiles as occupied when mobs spawn
- Automatically marks tiles as unoccupied when mobs are destroyed
- Prevents overlapping mobs in intersecting spawn areas
- Gracefully handles cases where no spawn positions are available

#### Enhanced Debugging:
- Comprehensive logging for spawner registration and position calculation
- Debug information for spawn timing, mob counts, and tile occupancy
- Error handling for missing dependencies and invalid configurations
- Detailed logging for mob creation and positioning
- Spawn attempt tracking with success/failure reasons

```
Spawn Pattern (3x3 grid around spawner):
┌─────────┬─────────┬─────────┐
│   TL    │    T    │   TR    │
│ (spawn) │ (spawn) │ (spawn) │
├─────────┼─────────┼─────────┤
│    L    │   SPAWNER   │   R    │
│ (spawn) │   (tile)    │ (spawn) │
├─────────┼─────────┼─────────┤
│   BL    │    B    │   BR    │
│ (spawn) │ (spawn) │ (spawn) │
└─────────┴─────────┴─────────┘

Legend: T=Top, B=Bottom, L=Left, R=Right, TL=Top-Left, etc.
```

### Integration Points

#### DungeonService Integration:
- **PlaceSpawner**: Automatically calls `MobService:RegisterSpawner()` when a spawner is placed
- **RemoveSpawner**: Automatically calls `MobService:UnregisterSpawner()` when a spawner is removed

#### PlayerService Integration:
- **OnPlayerRemoving**: Calls `MobService:CleanupPlayer()` to clean up all mob data when a player leaves

#### Bootstrap Integration:
- MobService is registered with dependency injection
- Depends on DungeonService for spawner position data
- Automatically initialized when the server starts

## Configuration

### Spawner Types (from ItemConfig.lua)

```lua
goblin_spawner = {
    stats = {
        mobType = "Goblin",
        spawnRate = 5, -- seconds between spawns
        maxMobs = 3,
        mobHealth = 50,
        mobDamage = 8
    }
}
-- Only goblin_spawner is supported - system simplified to single mob type
```

### Mob Properties

Only one mob type is currently supported:

| Mob Type | Color | Size | Material | Special Properties |
|----------|-------|------|----------|-------------------|
| Goblin | Green | 1.8x3.5x1.8 | Plastic | Basic mob |

## Usage

### Automatic Usage
The system works automatically once spawners are placed:

1. Player places spawners in their dungeon (multiple spawners supported)
2. DungeonService automatically registers each spawner with MobService
3. MobService begins spawning 1-3 mobs per spawner at the configured rate
4. Mobs appear as Parts in the workspace in tiles around spawners
5. **Tile occupancy system prevents multiple mobs in the same tile**
6. Spawn tiles can intersect, but each tile can only hold one mob
7. When spawner is removed, all associated mobs are cleaned up

### Manual Testing
The MobService is designed to work automatically with the DungeonService. To test manually:

```lua
-- Get MobService instance
local mobService = _G.Injector:Resolve("MobService")

-- Check active spawners for a player
local activeSpawners = mobService:GetActiveSpawners(player)

-- Check spawned mobs for a player
local spawnedMobs = mobService:GetSpawnedMobs(player)
```

### Mob Spawning Monitor
The Bootstrap script includes built-in mob spawning monitoring:
- Waits for a player to join
- Continuously monitors active spawners and spawned mobs
- Provides real-time feedback on spawning activity
- Runs continuously to track spawning patterns
- Uses proper dependency injection instead of global variables

## Testing

### ServiceTest Integration
The existing ServiceTest now includes MobService validation:
- Checks that MobService is properly initialized
- Validates key methods are available
- Ensures dependency injection is working

### Integration Testing
The MobService integrates automatically with:
- **DungeonService**: Automatically registers/unregisters spawners when placed/removed
- **PlayerService**: Automatically cleans up mob data when players leave
- **WorldService**: Uses dungeon positioning for spawn calculations

## Future Enhancements

### Potential Improvements:
1. **Mob AI**: Add pathfinding and behavior systems
2. **Combat System**: Implement mob combat with players
3. **Mob Drops**: Add loot drops when mobs are defeated
4. **Mob Models**: Replace basic Parts with detailed 3D models
5. **Spawner Upgrades**: Allow players to upgrade spawner efficiency
6. **Mob Evolution**: Mobs that grow stronger over time
7. **Spawner Networks**: Multiple spawners working together

### Configuration Extensions:
- Mob movement patterns
- Spawner efficiency modifiers
- Environmental effects on spawning
- Time-based spawning variations

## Technical Notes

### Performance Considerations:
- Spawning loop runs every second but only processes active spawners
- Mob tracking uses efficient table lookups
- Automatic cleanup prevents memory leaks
- Limited max mobs per spawner prevents overcrowding

### Scalability:
- Each player's mobs are tracked independently
- Spawner registration is per-player, not global
- Cleanup happens automatically when players leave
- System can handle multiple players with multiple spawners

### Error Handling:
- Graceful handling of missing dependencies
- Validation of spawner types and configurations
- Fallback values for missing spawner stats
- Logging for debugging and monitoring

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Spawner Slot System](SPAWNER_SLOT_SYSTEM.md)
- [Mob Package System Guide](MOB_PACKAGE_SYSTEM_GUIDE.md)
- [Server-Side API Documentation](API_DOCUMENTATION.md)
