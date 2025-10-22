# Spawner Slot System - Model-Based 10 Pre-defined Positions

## Overview

The spawner slot system has been completely redesigned to use 10 pre-defined slot positions that are read directly from the PlayerDungeon model structure. Each slot has three possible states that determine player interaction and visual appearance. The system no longer uses hardcoded positions or directions - all positioning is driven by the 3D model.

## Table of Contents
- [Overview](#overview)
- [Model structure](#model-structure)
- [Slot configuration](#slot-configuration)
- [Three slot states](#three-slot-states)
- [Data structure](#data-structure)
- [API methods](#api-methods)
- [Visual configuration](#visual-configuration)
- [Model requirements](#model-requirements)
- [Migration from old system](#migration-from-old-system)
- [Network events](#network-events)
- [Error handling](#error-handling)
- [Code cleanup](#code-cleanup)
- [Future enhancements](#future-enhancements)
- [Related docs](#related-docs)

## Model Structure

### PlayerDungeon Model Layout
```
PlayerDungeon/
├── SpawnerSlots/
│   ├── SpawnerSlot1/
│   │   ├── SpawnerSlot (Part) - Proximity prompt attachment point
│   │   └── SpawnerPropLocation (Part) - Spawner visual placement location
│   ├── SpawnerSlot2/
│   │   ├── SpawnerSlot (Part)
│   │   └── SpawnerPropLocation (Part)
│   └── ... (up to SpawnerSlot10)
└── PrimaryPart (Part) - Dungeon center reference
```

### Slot Components
- **SpawnerSlot Part**: The visual representation of the slot and attachment point for proximity prompts
- **SpawnerPropLocation Part**: The exact position where spawner visuals are placed

## Slot Configuration

### Dynamic Slot Reading
The system reads slot positions and configurations directly from the 3D model. No hardcoded positions are used:

```lua
-- Server-side slot configuration from model
{
    id = 1,
    name = "SpawnerSlot1",
    spawnerSlotPart = Part,           -- Reference to SpawnerSlot part
    spawnerPropLocation = Part,       -- Reference to SpawnerPropLocation part
    position = Vector3,               -- Position of SpawnerSlot part
    spawnerPosition = Vector3,        -- Position of SpawnerPropLocation part
    unlocked = true                   -- Default unlock state from config
}
```

### Default Unlock States
The default unlock states are defined in `GameConfig.lua` (no positions, just unlock states):
- **Slots 1-3**: Locked by default, cost 10 coins each to unlock
- **Slots 4-10**: Locked by default with increasing unlock prices

## Three Slot States

### 1. Locked Slot
- **Description**: Slot is locked and cannot be used
- **Visual**: Dark grey color with high transparency on SpawnerSlot part
- **Interaction**: Proximity prompt shows "Locked Slot" and is disabled
- **Behavior**: Players cannot place spawners until slot is unlocked

### 2. Unlocked Slot
- **Description**: Slot is available for spawner placement
- **Visual**: Gold color with medium transparency on SpawnerSlot part
- **Interaction**: Proximity prompt shows "Place Spawner" and is enabled
- **Behavior**: Players can place spawners from their inventory

### 3. Spawner Placed
- **Description**: A spawner has been placed in the slot
- **Visual**: Green color with high transparency on SpawnerSlot part
- **Interaction**: Proximity prompt shows "Remove Spawner" and is enabled
- **Behavior**: Players can remove the spawner to return it to inventory

## Data Structure

### Server-side Slot Data
```lua
{
    spawnerType = "goblin_spawner", -- Type of spawner or "None"
    slotName = "SpawnerSlot1",      -- Name of the slot
    isEmpty = false,                -- Whether slot has a spawner
    isUnlocked = true               -- Whether slot is unlocked
}
```

### Client-side Tile Data
```lua
{
    index = 1,                      -- Slot index (1-10)
    name = "SpawnerSlot1",          -- Slot name
    spawnerType = "goblin_spawner", -- Spawner type or "None"
    isEmpty = false,                -- Whether slot is empty
    isUnlocked = true,              -- Whether slot is unlocked
    state = "spawner_placed",       -- "locked", "unlocked", or "spawner_placed"
    position = Vector3,             -- Position of SpawnerSlot part
    spawnerPosition = Vector3       -- Position of SpawnerPropLocation part
}
```

## API Methods

### DungeonService Methods

#### Slot Management
- `GetSpawnerSlot(player, slotIndex)` - Get slot data
- `UpdateSpawnerSlot(player, slotIndex, spawnerType)` - Update slot
- `UnlockSpawnerSlot(player, slotIndex)` - Unlock a slot
- `GetAllSpawnerSlots(player)` - Get all slots with states

#### Model-based Slot Configuration
- `GetSlotConfigurationsFromModel(dungeonModel)` - Read slot configs from model
- `FindPlayerDungeonModel(player, worldSlotId)` - Find player's dungeon model
- `_calculateSpawnerPositionFromSlotConfig(slotConfig)` - Get spawner position

#### Slot Information
- `GetSlotConfig(slotIndex)` - Get slot configuration
- `GetAllSlotConfigs()` - Get all slot configurations
- `IsSlotUnlockedByDefault(slotIndex)` - Check if slot is unlocked by default
- `GetUnlockedSlotCount(player)` - Count unlocked slots
- `GetPlacedSpawnerCount(player)` - Count placed spawners

#### Spawner Operations
- `PlaceSpawner(player, slotIndex, spawnerType)` - Place spawner
- `RemoveSpawner(player, slotIndex)` - Remove spawner
- `CanPlaceSpawner(player, slotIndex, spawnerType)` - Check if can place

### Client-side Methods

#### DungeonGridManager Methods
- `FindSpawnerSlotPart(slotIndex)` - Find SpawnerSlot part in model
- `UpdateSpawnerSlotProximityPrompt(spawnerSlotPart, tileData)` - Update proximity prompt
- `OnSpawnerSlotUnlocked(unlockData)` - Handle slot unlock

## Visual Configuration

### Colors and Transparency
```lua
SPAWNER_TILE = {
    -- Locked slot
    colorLocked = Color3.fromRGB(64, 64, 64),    -- Dark grey
    transparencyLocked = 0.7,                    -- High transparency

    -- Unlocked slot
    colorUnlocked = Color3.fromRGB(255, 215, 0), -- Gold
    transparencyEmpty = 0.3,                     -- Medium transparency

    -- Occupied slot
    colorOccupied = Color3.fromRGB(0, 255, 0),   -- Green
    transparencyWithSpawner = 0.8                -- High transparency
}
```

## Model Requirements

### Required Model Structure
Each PlayerDungeon model must contain:
1. **SpawnerSlots folder** with 10 SpawnerSlot models
2. **Each SpawnerSlot model** must contain:
   - `SpawnerSlot` part (for proximity prompts and visual state)
   - `SpawnerPropLocation` part (for spawner visual placement)
3. **PrimaryPart** for dungeon center reference

### Model Naming Convention
- SpawnerSlot models must be named: `SpawnerSlot1`, `SpawnerSlot2`, etc.
- Parts within each slot must be named: `SpawnerSlot` and `SpawnerPropLocation`

## Migration from Old System

### Backward Compatibility
- Legacy `directions` configuration has been removed
- Existing player data is automatically migrated to new format
- Old slot data is preserved during migration

### Data Migration
The system automatically migrates existing player data:
1. Preserves existing spawner placements
2. Converts direction names to slot names
3. Sets appropriate unlock states based on configuration
4. Maintains spawner inventory and placement data

## Network Events

### Server Events
- `SpawnerSlotUnlocked` - Fired when a slot is unlocked
- `SpawnerPlaced` - Fired when spawner is placed
- `SpawnerRemoved` - Fired when spawner is removed

### Client Events
- `OnSpawnerSlotUnlocked` - Handle slot unlock
- `OnSpawnerPlaced` - Handle spawner placement
- `OnSpawnerRemoved` - Handle spawner removal

## Error Handling

### Common Error Messages
- "Slot is locked" - Attempted to place spawner in locked slot
- "Slot already occupied" - Attempted to place spawner in occupied slot
- "Not in inventory" - Player doesn't have spawner in inventory
- "Invalid spawner type" - Spawner type not recognized
- "No SpawnerSlots folder found" - Model structure is invalid

### Validation
- Slot index must be 1-10
- Spawner type must be valid
- Player must have spawner in inventory
- Slot must be unlocked and empty for placement
- Model must have proper SpawnerSlots structure

## Code Cleanup

### Removed Components
- **Hardcoded positions**: All position calculations now use model data
- **Direction system**: Replaced with model-based slot system
- **Grid container creation**: No longer needed with model-based approach
- **Dynamic tile creation**: Uses existing model parts instead
- **Legacy configuration**: Removed old directions and position configs

### Benefits of Cleanup
- **Simplified codebase**: Removed complex position calculations
- **Better maintainability**: No hardcoded values to maintain
- **Model-driven design**: All positioning controlled by 3D models
- **Reduced complexity**: Fewer moving parts and dependencies

## Future Enhancements

### Potential Features
- Slot unlocking through progression system
- Slot unlocking through purchases
- Slot-specific spawner restrictions
- Slot enhancement system
- Dynamic slot positioning based on dungeon level
- Custom slot models per dungeon type

### Configuration Options
- Custom slot positions per dungeon type
- Slot-specific spawner type restrictions
- Unlock requirements per slot
- Visual customization per slot state
- Model-based slot validation

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Mob Spawning Implementation](MOB_SPAWNING_IMPLEMENTATION.md)
- [Server-Side API Documentation](API_DOCUMENTATION.md)
