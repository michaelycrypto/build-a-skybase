# Refactoring Summary: Minecraft Clone → Roblox Player-Owned Worlds + R15 Characters

## Overview
This document summarizes two major refactorings performed on the TDS codebase:

1. **World System Refactoring**: Conversion from single shared Minecraft-style world to Roblox-style player-owned worlds with lobby hub
2. **Character System Refactoring**: Conversion from Minecraft-style cubic rigs to Roblox R15 characters (IN PROGRESS)

---

## Part 1: Player-Owned Worlds System (COMPLETED)

### Architecture Changes

#### Before
- Single infinite procedural world shared by all players
- Perlin noise terrain generation with biomes
- Global world save system
- Chunk streaming based on player distance

#### After
- **Lobby Hub**: 4×4 chunks persistent flat area where all players spawn
- **Player Worlds**: Multiple isolated 16×16 chunk flat worlds, individually owned
- **Teleportation System**: Move between lobby ↔ worlds seamlessly
- **Permissions**: Owner/Builder/Visitor access control per world
- **DataStore**: Per-world saves using Roblox DataStore

### New Modules Created

#### Core World Management
1. **`FlatTerrainGenerator.lua`** - Generates flat 16×16 chunk worlds
   - Replaces Perlin noise generation
   - Bedrock (Y=0-2), Stone (Y=3-62), Dirt (Y=63), Grass (Y=64)
   - Simple, predictable terrain for player creativity

2. **`WorldInstance.lua`** - Represents individual player-owned worlds
   - 16×16 chunks (256 chunks total = 256×256 blocks)
   - Player tracking and metadata management
   - Block get/set with permission checking
   - Serialization for DataStore persistence

3. **`WorldInstanceManager.lua`** - Manages multiple concurrent worlds
   - Max 50 concurrent worlds
   - Load on-demand when player joins
   - Unload 30s after last player leaves
   - Auto-save every 5 minutes

4. **`LobbyManager.lua`** - Persistent lobby hub
   - 4×4 chunks (64×64 blocks)
   - Always loaded, never unloads
   - Protected blocks (cannot be broken/placed)
   - Central spawn point at (0, ground_level, 0)

5. **`TeleportService.lua`** - Player location and teleportation
   - Tracks player locations (lobby vs world)
   - Handles world loading on teleport
   - Manages player state transitions
   - Callbacks for teleport events

6. **`WorldPermissions.lua`** - Access control system
   - Permission levels: Owner, Builder, Visitor, None
   - Capability-based permissions (canJoin, canBuild, canDestroy, etc.)
   - Public worlds: anyone joins as Visitor
   - Private worlds: invitation required

7. **`WorldDataStore.lua`** - Per-world persistence
   - Separate DataStores: Worlds, Permissions, PlayerWorldsList
   - Per-world chunk serialization
   - World metadata (owner, name, settings)
   - Player world lists

#### Client-Side
8. **`WorldManagementController.lua`** - Client UI controller
   - World creation requests
   - Teleportation requests
   - World list management (my worlds, public worlds)
   - Permission management
   - Settings updates

### Major Service Updates

#### VoxelWorldService
- **Complete rewrite** for multi-world system
- Integrated WorldInstanceManager and LobbyManager
- Added TeleportService and WorldPermissions
- Permission checks on all block operations
- Chunk streaming now routes to lobby or active world
- Client event handlers for world management
- Auto-save processing (5-minute intervals)

#### SpawnService
- Updated to spawn all players in lobby
- Streams lobby chunks to player on spawn
- Uses LobbyManager for spawn position
- No more procedural terrain spawn lookups

### Key Features

#### Lobby System
- 4×4 chunks centered at world origin
- All players spawn here initially
- Blocks are protected (cannot be modified)
- Always loaded in memory
- Fixed seed for consistency

#### World Creation
```lua
-- Players can create worlds with settings:
{
	name = "My World",
	isPublic = false,
	maxPlayers = 10,
	allowBuilding = true
}
```

#### Permission System
```lua
-- Three permission levels:
Owner    → Full control (build, destroy, invite, settings, delete)
Builder  → Can build and destroy
Visitor  → View only (no modifications)
```

#### Teleportation
```lua
-- Server-side API:
VoxelWorldService:CreateWorld(player, "World Name", isPublic, maxPlayers)
VoxelWorldService:TeleportPlayerToWorld(player, worldId)
VoxelWorldService:TeleportPlayerToLobby(player)

-- Client-side API:
WorldManagementController:CreateWorld(worldName, isPublic, maxPlayers)
WorldManagementController:TeleportToWorld(worldId)
WorldManagementController:TeleportToLobby()
```

#### DataStore Structure
```lua
-- Worlds DataStore
Key: worldId → {
	metadata = { owner, name, created, isPublic, maxPlayers, allowBuilding },
	chunks = { [chunkKey] → serialized chunk data },
	savedAt = timestamp
}

-- Permissions DataStore
Key: "worldId_userId" → "owner" | "builder" | "visitor"

-- Player Worlds List
Key: userId → { worldIds[] }
```

### Systems Removed
- ✅ Perlin/Simplex noise generation
- ✅ Biome system
- ✅ Cave generation
- ✅ Infinite world streaming (replaced with lobby + 16×16 worlds)
- ✅ Height maps
- ✅ Global world save (replaced with per-world saves)

### Systems Kept
- ✅ Voxel rendering
- ✅ Block types (grass, stone, wood, etc.)
- ✅ Mining/placing mechanics
- ✅ Player physics (Minecraft-style)
- ✅ Inventory system

---

## Part 2: R15 Character System (IN PROGRESS)

### Architecture Changes

#### Before
- Custom Minecraft-style cubic rigs
- Server creates/destroys custom models
- Manual limb positioning and animation
- Custom physics capsule

#### After
- Native Roblox R15 characters
- Standard character loading
- Built-in animations
- Humanoid-based physics with custom controls

### Updated Modules

#### EntityService (IN PROGRESS)
- **Removed**: Custom rig creation (`_createRig`)
- **Added**: R15 character loading (`_loadCharacter`)
- **Added**: Character configuration (`ConfigureCharacter`)
- **Updated**: `SpawnPlayerAt` for R15 positioning
- **Changed**: Disabled default Roblox controls (we use custom physics)
- **Changed**: WalkSpeed = 0, JumpPower = 0 (controlled by our voxel physics)

#### Key Changes
```lua
-- Character Configuration
humanoid.WalkSpeed = 0 -- Custom movement via physics
humanoid.JumpPower = 0 -- Custom jumping via physics
humanoid.AutoRotate = false -- Manual rotation control
rootPart.CanCollide = false -- Voxel collision only
rootPart.Anchored = false -- Physics-based movement
```

### Remaining Tasks (TODO)

1. **ClientPlayerController Update**
   - Adapt input handling for R15
   - Update camera system for R15
   - Modify movement prediction for R15 physics
   - Keep similar control feel

2. **RemotePlayerReplicator Update**
   - Remove custom rig rendering
   - Use R15 characters for remote players
   - Update animation replication

3. **SpawnService Update**
   - Adjust spawn positioning for R15 height
   - Update character setup flow

4. **StarterPlayer Configuration**
   - Set character type to R15
   - Configure humanoid settings
   - Disable default scripts

5. **UI Modules** (Not Started)
   - MyWorldsScreen
   - BrowseWorldsScreen
   - CreateWorldDialog
   - WorldSettingsDialog
   - LobbyHubUI

---

## Configuration

### World Limits
```lua
MAX_CONCURRENT_WORLDS = 50
UNLOAD_DELAY_SECONDS = 30
AUTO_SAVE_INTERVAL = 300 -- 5 minutes
LOBBY_SIZE_CHUNKS = 4 -- 4×4
WORLD_SIZE_CHUNKS = 16 -- 16×16
```

### Spawn Points
```lua
-- Lobby spawn: (0, 66, 0) in studs
-- World spawn: Center of 16×16 world at grass level
```

---

## Testing Checklist

### Completed ✅
- [x] FlatTerrainGenerator creates flat 16×16 worlds
- [x] WorldInstance manages chunks and players
- [x] WorldInstanceManager handles multiple concurrent worlds
- [x] LobbyManager creates protected lobby
- [x] TeleportService moves players between locations
- [x] WorldPermissions enforces access control
- [x] WorldDataStore persists worlds separately
- [x] VoxelWorldService integrates all systems
- [x] SpawnService spawns in lobby
- [x] Block placement/breaking respects permissions
- [x] Lobby blocks are protected
- [x] Player state tracking (location, worldId)

### In Progress 🚧
- [ ] R15 character spawning
- [ ] R15 character movement controls
- [ ] R15 camera system
- [ ] Remote player R15 rendering

### Not Started ❌
- [ ] World creation UI
- [ ] World browser UI
- [ ] World settings UI
- [ ] Teleportation UI
- [ ] Full end-to-end testing with multiple players
- [ ] DataStore quota optimization
- [ ] World thumbnail generation
- [ ] World search/filtering
- [ ] Friend invitations

---

## Breaking Changes

### API Changes
1. `VoxelWorldService:InitializeWorld()` - No longer creates single world
2. Block operations now require permission checks
3. Chunk streaming routes through lobby/world instances
4. Player spawn always in lobby (not procedural world position)

### Data Migration
- Old global world saves incompatible with new per-world system
- No automatic migration provided
- Fresh start required for new system

### Client Expectations
- Clients must handle `PlayerTeleported` event
- Clients must request world lists
- Clients must handle lobby-specific UI
- Clients must adapt to R15 characters (in progress)

---

## Performance Considerations

### Memory
- Lobby: Always loaded (~16-64 chunks)
- Active worlds: Up to 50 × 256 chunks = 12,800 chunks max
- Empty world unload after 30s reduces memory

### DataStore
- Per-world saves reduce single-key size limits
- Separate permission keys prevent quota issues
- Player world lists enable quick lookups
- Auto-save every 5 minutes balances safety vs quota

### Network
- Lobby chunks streamed once on spawn
- World chunks loaded on teleport (256 chunks)
- Block updates only broadcast to same location
- Permission checks server-side only

---

## Future Enhancements

### Short Term
- Complete R15 character integration
- Implement world management UI
- Add world thumbnails
- Implement friend invitations

### Medium Term
- World templates/presets
- Copy/paste world tools
- World import/export
- Collaborative building mode

### Long Term
- World size tiers (small, medium, large)
- Custom world generators
- World marketplace
- Cross-world teleportation networks
- Persistent NPCs per world
- World-specific resource nodes

---

## Credits
Refactored by AI Assistant (Claude Sonnet 4.5)
Date: October 20, 2025

## Related Documentation
- See `FlatTerrainGenerator.lua` for terrain generation details
- See `WorldPermissions.lua` for permission system
- See `VoxelWorldService.lua` for integration examples
- See `WorldManagementController.lua` for client API

