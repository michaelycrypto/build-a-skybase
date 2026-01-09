# Architecture Guide

## Overview

This game follows a server-authoritative architecture with dependency injection on the server and a manager/controller pattern on the client.

## Server Architecture

### Dependency Injection

Services are bound in `Bootstrap.server.lua` using the `Injector`:

```lua
Injector:Bind("PlayerInventoryService", script.Parent.Parent.Services.PlayerInventoryService, {
    dependencies = {"PlayerDataStoreService"},
    mixins = {}
})
```

Services receive their dependencies via `self.Deps`:

```lua
function MyService:DoSomething()
    local data = self.Deps.PlayerDataStoreService:GetPlayerData(player)
end
```

### Service Lifecycle

1. `Injector:Bind()` - Register service with dependencies
2. `Injector:ResolveAll()` - Create all service instances
3. `services:Init()` - Initialize all services
4. `services:Start()` - Start all services

### Available Mixins

| Mixin | Purpose | Methods |
|-------|---------|---------|
| `RateLimited` | Prevent spam | `DefineRateLimit`, `IsRateLimited`, `RecordAction` |
| `Cooldownable` | Cooldown management | `DefineCooldown`, `StartCooldown`, `IsOnCooldown` |

### Server Services

**Core Services:**
- `PlayerDataStoreService` - DataStore2 persistence
- `PlayerService` - Player lifecycle, data management
- `PlayerInventoryService` - Inventory operations

**World Services:**
- `VoxelWorldService` - Voxel world authority, chunk streaming
- `WorldOwnershipService` - Player world ownership (worlds place only)
- `WorldsListService` - World listing and management

**Gameplay Services:**
- `CraftingService` - Recipe validation, crafting
- `ChestStorageService` - Chest block storage
- `DroppedItemService` - Dropped item spawning/pickup
- `MobEntityService` - Mob spawning and behavior
- `DamageService` - Combat damage calculations
- `ArmorEquipService` - Armor management
- `BowService` - Ranged combat
- `CropService` / `SaplingService` - Farming

**Economy:**
- `ShopService` - Shop purchases
- `QuestService` - Quest tracking

### Event System

Server-client communication uses `EventManager`:

```lua
-- Server: Register handler
EventManager:RegisterEvent("PurchaseItem", function(player, itemId)
    return shopService:ProcessPurchase(player, itemId)
end)

-- Server: Fire to client
EventManager:FireEvent("InventorySync", player, inventoryData)

-- Client: Send to server
EventManager:SendToServer("PurchaseItem", itemId)

-- Client: Register handler
EventManager:RegisterEvent("InventorySync", function(data)
    -- Handle inventory update
end)
```

## Client Architecture

The client uses **Controllers** for game logic, **Managers** for state/coordination, and **UI** modules for interface.

### Controllers

Controllers handle specific game mechanics:

```lua
-- Controllers/CameraController.lua
local CameraController = {}

function CameraController:Initialize()
    -- Setup camera system
end

function CameraController:CycleMode()
    -- F5 camera mode cycling
end

return CameraController
```

**Key Controllers:**
- `CameraController` - Camera modes, FOV, bobbing
- `BlockInteraction` - Block breaking/placing
- `CombatController` - Melee combat
- `BowController` - Ranged combat
- `MobReplicationController` - Mob rendering
- `DroppedItemController` - Dropped item rendering
- `ToolVisualController` / `ToolAnimationController` - Tool rendering
- `ArmorVisualController` - Armor rendering
- `SprintController` - Sprint handling
- `MobileControlController` - Mobile touch controls

### Managers

Managers coordinate state and systems:

- `GameState` - Reactive state container
- `UIVisibilityManager` - UI mode coordination
- `ClientInventoryManager` - Inventory state
- `SoundManager` - Audio playback
- `ToastManager` - Notifications
- `PanelManager` - Panel registration

### Input System

`InputService` provides unified input handling:

```lua
-- Signals
InputService.PrimaryDown:Connect(function()
    -- LMB / Touch / R2
end)

InputService.SecondaryDown:Connect(function()
    -- RMB / L2
end)

-- Cursor management (stack-based)
local token = InputService:PushCursorMode("MyUI", "ui")
-- Later...
InputService:PopCursorMode(token)

-- Convenience for UI panels
local release = InputService:BeginOverlay("ChestUI")
-- On close:
release()
```

### GameState

Reactive state with subscriptions:

```lua
-- Set state
GameState:Set("ui.mode", "inventory")

-- Get state
local mode = GameState:Get("ui.mode")

-- Subscribe to changes
GameState:OnPropertyChanged("camera.isFirstPerson", function(newValue)
    -- Handle change
end)
```

## Shared Systems

### VoxelWorld

Located at `ReplicatedStorage/Shared/VoxelWorld/`:

- `Core/` - Constants, Config
- `World/` - Chunk, WorldManager
- `Generation/` - Terrain generation
- `Rendering/` - BoxMesher, TextureManager, PartPool
- `Inventory/` - Item stack operations
- `Crafting/` - Recipe matching

### Network Flow

```
Client Action → EventManager:SendToServer() → Server Service →
EventManager:FireEvent() → Client Handler → Update UI
```

### Configuration

Game config in `ReplicatedStorage/Configs/`:
- `GameConfig.lua` - Core game settings
- `ItemConfig.lua` / `ItemDefinitions.lua` - Item data
- `RecipeConfig.lua` - Crafting recipes
- `MobRegistry.lua` - Mob definitions
- `ArmorConfig.lua` - Armor stats
- `BlockBreakFeedbackConfig.lua` - Break effects

## Patterns

### Adding a New Service

1. Create `Services/MyService.lua`:
```lua
local BaseService = require(script.Parent.BaseService)
local MyService = setmetatable({}, BaseService)
MyService.__index = MyService

function MyService.new()
    local self = setmetatable({}, MyService)
    self.Deps = {}
    return self
end

function MyService:Init()
    -- Setup
end

function MyService:Start()
    -- Begin operations
end

return MyService
```

2. Bind in `Bootstrap.server.lua`:
```lua
Injector:Bind("MyService", script.Parent.Parent.Services.MyService, {
    dependencies = {"PlayerService"},
    mixins = {"RateLimited"}
})
```

### Adding a New Controller

1. Create `Controllers/MyController.lua`:
```lua
local MyController = {}

function MyController:Initialize()
    -- Setup
end

return MyController
```

2. Initialize in `GameClient.client.lua`:
```lua
local MyController = require(script.Parent.Controllers.MyController)
MyController:Initialize()
Client.myController = MyController
```

### Adding a New UI Panel

1. Create `UI/MyPanel.lua` with `new()`, `Initialize()`, `Open()`, `Close()`, `Toggle()`
2. Register with `UIVisibilityManager` if needed
3. Initialize in `GameClient.client.lua`


