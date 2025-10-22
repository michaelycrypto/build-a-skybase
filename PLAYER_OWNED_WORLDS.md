# Player-Owned Worlds Implementation

## Overview

This Roblox place has been restructured to support player-owned worlds. Each server instance is owned by a single player, and all world data is stored in that player's datastore - similar to games like Skyblock.

## How It Works

### Server Ownership

1. **First Player = Owner**: When a server starts, the first player to join automatically becomes the owner of that server instance.
2. **Owner's World**: The world is generated using a seed unique to the owner's datastore.
3. **Persistent Data**: All world modifications (block placements, terrain changes) are saved to the owner's datastore.

### Architecture

The system has been significantly simplified compared to the previous multi-world lobby system:

#### New Services

1. **WorldOwnershipService** (`Services/WorldOwnershipService.lua`)
   - Manages server instance ownership
   - Handles world data loading/saving from owner's datastore
   - Broadcasts ownership info to all players
   - Key methods:
     - `ClaimOwnership(player)` - Makes a player the owner
     - `GetOwnerId()` - Returns the owner's UserId
     - `IsOwner(player)` - Check if player is the owner
     - `SaveWorldData()` - Save world to owner's datastore
     - `LoadWorldData()` - Load world from owner's datastore

2. **VoxelWorldService (Simplified)** (`Services/VoxelWorldService.lua`)
   - Now manages a single world instance per server
   - Removed all lobby/teleportation/multi-world complexity
   - Handles chunk streaming and block editing
   - Automatically saves modified chunks
   - Key methods:
     - `InitializeWorld(seed, renderDistance)` - Create world
     - `UpdateWorldSeed(seed)` - Recreate world with new seed
     - `SaveWorldData()` - Save modified chunks
     - `LoadWorldData()` - Load saved chunks from owner

#### Bootstrap Integration

The server bootstrap (`Bootstrap.server.lua`) now:

1. Initializes `WorldOwnershipService` as a dependency
2. Detects the first player to join
3. Assigns ownership to that player
4. Updates the world seed to the owner's seed
5. Loads the owner's saved world data
6. Auto-saves world data every 5 minutes
7. Saves world data on server shutdown

### Data Storage

World data is stored in DataStore under key: `World_<OwnerUserId>`

Structure:
```lua
{
    ownerId = 123456789,
    ownerName = "PlayerName",
    created = 1234567890,
    lastSaved = 1234567890,
    seed = 42069,
    chunks = {
        {
            key = "0,0",
            x = 0,
            z = 0,
            data = <serialized chunk data>
        },
        -- ... more chunks
    },
    metadata = {
        name = "PlayerName's World",
        description = "A player-owned world"
    }
}
```

### Client Display

A new UI component (`UI/WorldOwnershipDisplay.lua`) shows:
- The world owner's name
- The world name
- Special indicator if you're the owner

The display appears at the top of the screen and updates when the client receives ownership information.

## Testing

For testing purposes, the system works as follows:

1. Start a server in Studio
2. The first player to join becomes the owner
3. They can build/modify the world
4. Changes are saved to their datastore
5. When they rejoin, their world state is restored

### Studio Testing

When testing in Studio with "Server" mode:
- The test player becomes the owner automatically
- World data saves to DataStore (or mock DataStore in Studio)
- You can test by placing blocks, stopping the server, and restarting

## Key Features

✅ **Single Owner Per Server**: First player to join owns the server
✅ **Persistent World**: All changes saved to owner's datastore
✅ **Unique World Seed**: Each owner gets their own unique world generation
✅ **Auto-Save**: World saves every 5 minutes and on shutdown
✅ **Ownership Display**: Players can see whose world they're in
✅ **Full Voxel Support**: Block placement, breaking, and streaming work normally

## Removed Features

The following multi-world features were removed in this simplification:

- ❌ Lobby system
- ❌ Multiple world instances per server
- ❌ World teleportation
- ❌ Public world listings
- ❌ World permissions system (all players can build in owner's world for now)
- ❌ World instance manager

## Future Enhancements

Potential additions to the system:

1. **Permissions**: Add ability for owner to restrict who can build
2. **World Settings**: Let owner configure world parameters
3. **Visitor List**: Track who has visited the world
4. **World Statistics**: Show world age, block count, etc.
5. **World Sharing**: Allow owners to share their world code
6. **Multiple Worlds**: Let owners create multiple worlds (requires lobby)

## File Changes

### New Files
- `Services/WorldOwnershipService.lua` - Ownership management
- `UI/WorldOwnershipDisplay.lua` - Client ownership UI

### Modified Files
- `Services/VoxelWorldService.lua` - Simplified to single-world
- `Bootstrap.server.lua` - Integrated ownership system
- `GameClient.client.lua` - Added ownership display
- `EventManifest.lua` - Added WorldOwnershipInfo event

### Removed Dependencies
- `World/WorldInstanceManager.lua` - No longer used
- `World/LobbyManager.lua` - No longer used
- `World/TeleportService.lua` - No longer used
- All lobby/multi-world related modules

## API Reference

### Server Events

**WorldOwnershipInfo** (Server → Client)
```lua
{
    ownerId = 123456789,
    ownerName = "PlayerName",
    worldName = "PlayerName's World",
    created = 1234567890,
    seed = 42069
}
```

Fired to all players when:
- Server ownership is claimed
- New player joins after owner is established

## Notes

- DataStore limits apply (saves limited by Roblox throttling)
- World data size is limited by DataStore maximum (4MB per key)
- Only modified chunks are saved (optimized storage)
- Chunk compression is used for efficient network transfer
- Server shuts down properly to ensure data is saved

