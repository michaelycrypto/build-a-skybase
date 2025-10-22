# DataStore Architecture Documentation

## Overview

This document describes the complete DataStore implementation for the Roblox game, covering player data persistence and world data persistence. The architecture follows Roblox best practices with proper error handling, retry logic, and data versioning.

## Table of Contents

1. [Player Data Persistence](#player-data-persistence)
2. [World Data Persistence](#world-data-persistence)
3. [Data Structure Specifications](#data-structure-specifications)
4. [Best Practices](#best-practices)
5. [Testing and Debugging](#testing-and-debugging)

---

## Player Data Persistence

### Service: `PlayerDataStoreService`

**Location:** `src/ServerScriptService/Server/Services/PlayerDataStoreService.lua`

**Purpose:** Manages all player-specific data including:
- Player profile (level, XP, coins, gems)
- Player inventory (hotbar + inventory slots)
- Player statistics
- Daily rewards tracking
- Player settings
- Dungeon/spawner data

### DataStore Configuration

```lua
DataStore Name: "PlayerData_v1"
DataStore Type: Standard DataStore
Key Format: "Player_{UserId}"
Version: 1
```

### Key Features

1. **Auto-Save System**
   - Automatically saves player data every 5 minutes (configurable)
   - Only saves "dirty" data (modified since last save)
   - Handles server shutdown gracefully

2. **Error Handling**
   - Retry logic (3 attempts with exponential backoff)
   - Fallback to default data if load fails
   - Comprehensive error logging

3. **Data Versioning**
   - Built-in migration system for future updates
   - Version tracking in saved data
   - Backward compatibility support

4. **Session Management**
   - Tracks active player sessions in memory
   - Efficient dirty flag system
   - Automatic cleanup on disconnect

### Data Flow

#### Player Join:
```
1. Player joins server
2. PlayerService calls PlayerDataStoreService:LoadPlayerData()
3. DataStore loads from "Player_{UserId}" key
4. If data exists: Load and migrate if needed
5. If no data: Create default data for new player
6. Cache data in memory session
7. Sync inventory to PlayerInventoryService
8. Send data to client
```

#### Player Leave:
```
1. Player leaves server
2. PlayerService calls SavePlayerData()
3. Sync inventory from PlayerInventoryService
4. Update all profile data in session
5. PlayerDataStoreService:SavePlayerData() writes to DataStore
6. PlayerDataStoreService:OnPlayerRemoving() cleans up session
7. Remove local cache
```

#### Auto-Save Loop:
```
Every 5 minutes:
1. Iterate through all active sessions
2. For each "dirty" session:
   - Sync latest inventory data
   - Update DataStore
   - Mark as clean
3. Log save count
```

### Integration Points

**With PlayerService:**
- PlayerService loads data on player join
- PlayerService saves data on player leave
- PlayerService updates profile data (level, coins, gems, stats)

**With PlayerInventoryService:**
- Inventory data saved as part of player data
- Serialized inventory format stored in DataStore
- Loaded and applied on player join

### Default Data Structure

```lua
{
    version = 1,

    profile = {
        level = 1,
        experience = 0,
        coins = 100,
        gems = 10,
        manaCrystals = 0,
    },

    statistics = {
        gamesPlayed = 0,
        enemiesDefeated = 0,
        coinsEarned = 0,
        itemsCollected = 0,
        totalPlayTime = 0,
        blocksPlaced = 0,
        blocksBroken = 0,
    },

    inventory = {
        hotbar = {...},      -- 9 slots
        inventory = {...}    -- 27 slots
    },

    dailyRewards = {
        currentStreak = 0,
        lastClaimDate = nil,
        totalDaysClaimed = 0
    },

    dungeonData = {
        mobSpawnerSlots = {}
    },

    settings = {
        musicVolume = 0.8,
        soundVolume = 1.0,
        enableNotifications = true
    },

    createdAt = timestamp,
    lastSave = timestamp,
    lastLogin = timestamp
}
```

---

## World Data Persistence

### Service: `WorldOwnershipService`

**Location:** `src/ServerScriptService/Server/Services/WorldOwnershipService.lua`

**Purpose:** Manages player-owned world persistence in a Skyblock-style system where each server is owned by one player.

### DataStore Configuration

```lua
DataStore Name: "PlayerOwnedWorlds_v1"
DataStore Type: Standard DataStore
Key Format: "World_{OwnerId}"
```

### How It Works

1. **Server Ownership Model**
   - First player to join becomes the owner
   - World data saved to owner's DataStore
   - All modifications persist to owner's world

2. **World Data Components**
   - World seed (for terrain generation)
   - Modified chunks (voxel data)
   - Chest inventories (entity data)
   - World metadata (name, description, creation date)

### Data Flow

#### Server Start + First Player Join:
```
1. Server starts empty
2. First player joins
3. WorldOwnershipService:ClaimOwnership(player)
4. LoadWorldData() from "World_{OwnerId}"
5. If exists: Load seed, chunks, and chest data
6. If new: Generate new seed, empty chunks
7. VoxelWorldService:UpdateWorldSeed() recreates terrain
8. VoxelWorldService:LoadWorldData() applies saved chunks
9. ChestStorageService:LoadChestData() restores chests
```

#### Auto-Save (Every 5 Minutes):
```
1. VoxelWorldService:SaveWorldData() called
2. Collect all modified chunks
3. ChestStorageService:SaveChestData() collects chest inventories
4. Bundle: {seed, chunks, chests, metadata}
5. WorldOwnershipService:SaveWorldData() writes to DataStore
```

#### Server Shutdown:
```
1. game:BindToClose() triggered
2. Save all player data via PlayerDataStoreService
3. Save world data via WorldOwnershipService
4. Destroy all services gracefully
```

### World Data Structure

```lua
{
    ownerId = UserId,
    ownerName = "PlayerName",
    created = timestamp,
    lastSaved = timestamp,
    seed = 123456,  -- Terrain generation seed

    chunks = {
        {
            key = "0,0",
            x = 0,
            z = 0,
            data = {...}  -- Serialized chunk data
        },
        ...
    },

    chests = {
        {
            x = 10,
            y = 5,
            z = -3,
            slots = {
                [1] = {itemId = 5, count = 64},
                [2] = {itemId = 3, count = 32},
                ...
            }
        },
        ...
    },

    metadata = {
        name = "PlayerName's World",
        description = "A player-owned world",
    }
}
```

### Related Services

**VoxelWorldService:**
- Manages voxel world state
- Tracks modified chunks
- Calls save/load through WorldOwnershipService

**ChestStorageService:**
- Manages all chest inventories
- Saves chest data as part of world data
- Restores chests on world load

**WorldDataStore (Legacy):**
- Located at `src/ReplicatedStorage/Shared/VoxelWorld/World/Persistence/WorldDataStore.lua`
- Separate DataStore system for multi-world support (not currently used)
- Kept for future multi-world features

---

## Data Structure Specifications

### Player Inventory Format

Inventories use the `ItemStack` serialization format:

```lua
-- Single slot format
{
    itemId = 5,      -- Block/item ID
    count = 64,      -- Stack count
    maxStack = 64,   -- Max stack size
    metadata = {}    -- Optional metadata
}

-- Empty slot
{
    itemId = 0,
    count = 0
}
```

### Chunk Data Format

Chunks use run-length encoding for efficient storage:

```lua
{
    x = chunkX,
    z = chunkZ,
    blocks = {
        {blockId, count},  -- RLE: [blockId, runLength]
        {blockId, count},
        ...
    },
    heightMap = {...}  -- Optional height optimization
}
```

---

## Best Practices

### 1. DataStore Request Limits

**Roblox Limits (per minute):**
- GetAsync: 60 + (numPlayers × 10)
- SetAsync: 60 + (numPlayers × 10)

**Our Implementation:**
- Auto-save interval: 5 minutes (reduces SetAsync calls)
- Retry with exponential backoff
- Only save dirty data (modified since last save)
- Batch operations where possible

### 2. Data Size Limits

**Roblox Limits:**
- Maximum data size per key: 4MB
- Recommended: < 1MB per key

**Our Implementation:**
- Player data typically < 100KB
- World data with chunks can be 500KB - 2MB
- Run-length encoding for chunk compression
- Only save non-empty chunks

### 3. Error Handling

```lua
-- Always use pcall
local success, result = pcall(function()
    return dataStore:GetAsync(key)
end)

if not success then
    warn("DataStore error:", result)
    -- Fallback behavior
end

-- Implement retries with delay
for attempt = 1, MAX_RETRIES do
    local success, result = pcall(...)
    if success then
        break
    else
        if attempt < MAX_RETRIES then
            task.wait(RETRY_DELAY * attempt)
        end
    end
end
```

### 4. Data Validation

```lua
-- Always validate loaded data
if type(data) ~= "table" then
    return defaultData
end

-- Check version and migrate
if data.version < CURRENT_VERSION then
    data = migrateData(data)
end

-- Ensure required fields exist
for key, defaultValue in pairs(DEFAULT_DATA) do
    if data[key] == nil then
        data[key] = defaultValue
    end
end
```

### 5. Testing DataStores

**In Studio:**
- Enable "Enable Studio Access to API Services" in Game Settings
- Use "HttpService.HttpEnabled = true" for testing
- DataStores work but are separate from live game

**Testing Strategy:**
1. Test with mock data (no DataStore)
2. Test DataStore in Studio
3. Test in private server
4. Monitor error logs in production

---

## Testing and Debugging

### Enable DataStore Logging

In `PlayerDataStoreService.lua`:
```lua
-- Logs all DataStore operations
self._logger.Info("Loading player data", {player = player.Name})
self._logger.Info("Saved player data", {dataSize = ...})
self._logger.Error("Failed to save", {error = err})
```

### Testing New Player Flow

1. Join with alt account (new UserId)
2. Check output logs for "New player detected"
3. Verify default inventory is created
4. Leave and rejoin
5. Verify data persists

### Testing Save/Load

```lua
-- Force save via server console
playerDataStoreService:SavePlayerData(player)

-- Check session data
local session = playerDataStoreService:GetSession(player)
print("Session:", session)

-- Force load
local data = playerDataStoreService:LoadPlayerData(player)
print("Loaded data:", data)
```

### Common Issues

**Issue: Data not saving**
- Check `DataStoreService` is enabled in Studio
- Check for error logs in output
- Verify player session exists
- Check auto-save interval

**Issue: Data not loading**
- Check DataStore key format
- Verify UserId is correct
- Check for DataStore API limits
- Verify data exists (may be new player)

**Issue: Inventory not persisting**
- Verify `PlayerInventoryService:SerializeInventory()` is called
- Check inventory data format
- Verify integration with `PlayerDataStoreService`

---

## Summary

### Player Data
- ✅ Fully implemented in `PlayerDataStoreService`
- ✅ Auto-save every 5 minutes
- ✅ Includes inventory, profile, stats, settings
- ✅ Error handling with retries
- ✅ Data versioning and migration

### World Data
- ✅ Fully implemented in `WorldOwnershipService`
- ✅ Player-owned world model (Skyblock-style)
- ✅ Includes chunks, chests, metadata
- ✅ Auto-save every 5 minutes
- ✅ Integrated with voxel world system

### Entities (Chests)
- ✅ Saved as part of world data
- ✅ Managed by `ChestStorageService`
- ✅ Position-based storage (x,y,z)
- ✅ Full inventory per chest

---

## Configuration

### Adjust Auto-Save Interval

In `PlayerDataStoreService.lua`:
```lua
local AUTO_SAVE_INTERVAL = 300  -- seconds (5 minutes)
```

In `Bootstrap.server.lua`:
```lua
task.wait(Config.SERVER.SAVE_INTERVAL or 300)
```

### Adjust Retry Configuration

In `PlayerDataStoreService.lua`:
```lua
local MAX_RETRIES = 3
local RETRY_DELAY = 1  -- seconds
```

### DataStore Naming

To reset all data (NEW VERSION):
```lua
-- PlayerDataStoreService.lua
local DATA_STORE_NAME = "PlayerData_v2"  -- Change version

-- WorldOwnershipService.lua
local WORLD_DATA_STORE_NAME = "PlayerOwnedWorlds_v2"  -- Change version
```

---

## Future Improvements

1. **Backup System**
   - Implement periodic backups to separate DataStore
   - Restore functionality for corrupted data

2. **Analytics**
   - Track save/load times
   - Monitor DataStore usage
   - Alert on failures

3. **Compression**
   - Better chunk compression algorithms
   - Reduce world data size

4. **Caching**
   - Redis-style cache for frequently accessed data
   - Reduce DataStore read operations

---

## Related Files

- `src/ServerScriptService/Server/Services/PlayerDataStoreService.lua` - Player data persistence
- `src/ServerScriptService/Server/Services/PlayerService.lua` - Player management
- `src/ServerScriptService/Server/Services/PlayerInventoryService.lua` - Inventory management
- `src/ServerScriptService/Server/Services/WorldOwnershipService.lua` - World ownership
- `src/ServerScriptService/Server/Services/VoxelWorldService.lua` - Voxel world management
- `src/ServerScriptService/Server/Services/ChestStorageService.lua` - Chest inventories
- `src/ServerScriptService/Server/Runtime/Bootstrap.server.lua` - Service initialization
- `src/ReplicatedStorage/Shared/VoxelWorld/World/Persistence/WorldDataStore.lua` - Legacy multi-world system

---

**Last Updated:** October 20, 2025
**Architecture Version:** 1.0

