# Voxel Survival Game

A Minecraft-style voxel survival game built on Roblox, featuring terrain generation, building, crafting, combat, and multiplayer player-owned worlds.

## Quick Start

```bash
# Build and run
rojo build default.project.json -o game.rbxl
```

## Architecture Overview

```
src/
├── ServerScriptService/Server/     # Server authority
│   ├── Services/                   # Game services (VoxelWorldService, PlayerService, etc.)
│   ├── Mixins/                     # Composable behaviors (RateLimited, Cooldownable)
│   ├── Runtime/Bootstrap.server.lua
│   └── Injector.lua                # Dependency injection
├── StarterPlayerScripts/Client/    # Client experience
│   ├── Controllers/                # Game controllers (Camera, Combat, BlockInteraction)
│   ├── Managers/                   # State managers (GameState, UIVisibility, Sound)
│   ├── UI/                         # UI components (Hotbar, Inventory, Chest, MainHUD)
│   └── Input/                      # Input system (InputService, CursorService)
└── ReplicatedStorage/
    ├── Shared/                     # Shared utilities and systems
    │   ├── VoxelWorld/             # Voxel engine (Generation, Rendering, World)
    │   ├── Mobs/                   # Mob system
    │   └── Network.lua, EventManager.lua, etc.
    └── Configs/                    # Game configuration (Items, Mobs, Recipes, etc.)
```

## Core Systems

### Server Services
| Service | Purpose |
|---------|---------|
| `VoxelWorldService` | Voxel world management, chunk streaming, block changes |
| `PlayerDataStoreService` | Data persistence via DataStore2 |
| `PlayerInventoryService` | Inventory management |
| `CraftingService` | 3x3 crafting grid recipes |
| `ChestStorageService` | Chest block storage |
| `MobEntityService` | Mob spawning and AI |
| `DamageService` | Combat damage calculations |
| `ArmorEquipService` | Armor equipment |
| `WorldOwnershipService` | Player-owned world management |

### Client Controllers
| Controller | Purpose |
|------------|---------|
| `CameraController` | First/third person camera modes (F5 to cycle) |
| `BlockInteraction` | Block breaking/placing |
| `CombatController` | Melee combat |
| `BowController` | Ranged combat |
| `MobReplicationController` | Mob rendering |
| `DroppedItemController` | Dropped item rendering |

### Controls
| Key | Action |
|-----|--------|
| `WASD` | Movement |
| `Space` | Jump |
| `Left Shift` | Sprint |
| `E` | Inventory |
| `B` | Worlds panel |
| `F5` | Cycle camera mode |
| `1-9` | Hotbar slots |
| `LMB` | Break block / Attack |
| `RMB` | Place block / Use item |
| `Esc` | Close current panel |

## Multi-Place Structure

- **Lobby Place** (ID: 139848475014328): Hub world, world selection
- **Worlds Place** (ID: 111115817294342): Player-owned survival worlds

## Key Files

- `Bootstrap.server.lua` - Server initialization, service binding
- `GameClient.client.lua` - Client initialization, voxel rendering loop
- `InputService.lua` - Unified input handling (desktop/mobile/gamepad)
- `CameraController.lua` - Camera modes and behavior
- `VoxelWorldService.lua` - Server voxel world authority

## Documentation

See `docs/` folder:
- `ARCHITECTURE.md` - Detailed architecture guide
- `SYSTEMS.md` - Game systems reference
- `CAMERA_INPUT_SYSTEM.md` - Camera and input deep-dive
