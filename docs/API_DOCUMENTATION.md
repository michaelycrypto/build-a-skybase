# 🔧 Server-Side API Documentation

## Overview

This document provides comprehensive API documentation for the server-side components of the minimal Roblox Core Framework. The server architecture follows simple, AI-friendly patterns with clear authority boundaries, dependency injection, and reactive state management.

**Current System Focus**: Dungeon management game with spawner deployment, inventory management, and progression systems.

## Directory Structure

```
src/
├── ServerScriptService/
│   ├── Server/
│   │   ├── Services/
│   │   │   ├── BaseService.lua         # Base class for all services
│   │   │   ├── PlayerService.lua       # Player data and lifecycle management
│   │   │   ├── DungeonService.lua      # Dungeon and spawner management
│   │   │   ├── WorldService.lua        # World generation and dungeon assignment
│   │   │   ├── ShopService.lua         # Shop transactions and items
│   │   │   ├── RewardService.lua       # Daily rewards and bonus systems
│   │   │   └── EmoteService.lua        # Player emote system
│   │   ├── Mixins/
│   │   │   ├── Cooldownable.lua        # Cooldown functionality
│   │   │   ├── RateLimited.lua         # Rate limiting
│   │   │   └── Randomizable.lua        # Weighted random systems
│   │   ├── Runtime/
│   │   │   ├── Bootstrap.server.lua    # Server initialization
│   │   │   └── ServiceTest.server.lua  # Service integration tests
│   │   └── Injector.lua               # Dependency injection with mixin support
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Network.lua                # Networking utilities
│   │   ├── State.lua                  # Server-side state management
│   │   ├── EventManager.lua           # Event handling system
│   │   ├── Logger.lua                 # Logging system
│   │   └── Config.lua                 # Framework configuration
│   └── Configs/
│       ├── GameConfig.lua             # Game configuration
│       └── ItemConfig.lua             # Item definitions and spawner system
└── StarterPlayerScripts/
    └── Client/
        └── Managers/
            └── GameState.lua          # Client-side reactive state management
```

## Table of Contents
- [Overview](#overview)
- [Directory structure](#directory-structure)
- [Core framework components](#core-framework-components)
- [State management system](#state-management-system)
- [Service documentation](#service-documentation)
- [Configuration system](#configuration-system)
- [Mixin system](#mixin-system)
- [Bootstrap pattern](#bootstrap-pattern)
- [Network integration](#network-integration)
- [Best practices](#best-practices)
- [Related docs](#related-docs)

---

## Core Framework Components

### BaseService

**Location**: `src/ServerScriptService/Server/Services/BaseService.lua`

Base class for all services providing standard lifecycle methods and Network access.

**Key Features:**
- **Network Singleton Access**: All services inherit `self:GetNetwork()` for consistent networking
- **Lifecycle Management**: Standard Init/Start/Destroy pattern with state tracking
- **Mixin Integration**: Seamless mixin application through the Injector

#### API Methods

```lua
-- Create new service (inherit from BaseService)
local MyService = setmetatable({}, BaseService)
MyService.__index = MyService

-- Constructor
function MyService.new()
    local self = setmetatable(BaseService.new(), MyService)
    return self
end

-- Required lifecycle methods
function MyService:Init()
    if self._initialized then return end
    -- One-time setup, dependencies available in self.Deps
    -- Network access available via self:GetNetwork()
    BaseService.Init(self)
end

function MyService:Start()
    if self._started then return end
    -- Start operations, called after all services are initialized
    BaseService.Start(self)
end

function MyService:Destroy()
    if self._destroyed then return end
    -- Cleanup resources
    BaseService.Destroy(self)
end
```

#### Network Access

```lua
-- Access Network singleton (lazy initialization)
local network = self:GetNetwork()

-- Define network functions in services
function MyService:_setupNetworkFunctions()
    local network = self:GetNetwork()

    -- Define a function with type validation
    local myFunction = network:DefineFunction("MyFunction", {"string"})
    myFunction:Returns({"boolean", "string"})
    myFunction:SetCallback(function(player, data)
        return self:ProcessData(player, data)
    end)

    -- Define events for client notifications
    self._myEvent = network:DefineEvent("MyEvent", {"table"})
end

-- Use events with clean colon syntax
function MyService:NotifyClient(player, data)
    local eventData = {
        message = "Hello",
        value = data.value
    }
    self._myEvent:Fire(player, eventData)
end
```

#### Lifecycle State Tracking

```lua
-- Check service state
service:IsInitialized() -- boolean
service:IsStarted()     -- boolean
service:IsDestroyed()   -- boolean
```

---

## State Management System

The framework uses a two-tier state management approach:

### Client-Side State (GameState.lua)

**Location**: `src/StarterPlayerScripts/Client/Managers/GameState.lua`

Enhanced reactive state management with dot-notation paths and batched updates.

#### Key Features

- **Dot-notation Access**: `GameState:Get("playerData.coins")`
- **Batched Updates**: Updates processed in batches for performance
- **Reactive Listeners**: Subscribe to property changes
- **Event Integration**: Works with EventManager for network updates

#### API Methods

```lua
-- Get values with dot-notation
local coins = GameState:Get("playerData.coins")
local inventory = GameState:Get("playerData.inventory")

-- Set values (batched by default)
GameState:Set("playerData.coins", 100)
GameState:Set("playerData.level", 5, true) -- immediate update

-- Listen for changes
local unsubscribe = GameState:OnPropertyChanged("playerData.coins", function(newValue, oldValue, path)
    print("Coins changed from", oldValue, "to", newValue)
end)

-- Player data helpers
GameState:SetPlayerData("coins", 100)
GameState:IncrementPlayerData("experience", 50)
local level = GameState:GetPlayerData("level", 1)

-- UI and game state
GameState:SetUIState("currentScreen", "inventory")
GameState:SetGameState("isPlaying", true)

-- Currency management
local coins = GameState:GetCoins()
GameState:UpdateCoins(150)
```

### Server-Side State (State.lua)

**Location**: `src/ReplicatedStorage/Shared/State.lua`

Simplified framework-compliant state management with state slices.

#### Key Features

- **State Slices**: Separate domains (currency, inventory, dungeon)
- **Server Authority**: Server mutates, clients receive
- **Network Sync**: Automatic synchronization via Network events
- **Validation**: Built-in state validation

#### API Methods

```lua
-- Get state (read-only copy)
local currencyState = State:GetState("currency")
local allState = State:GetState()

-- Update state slice (server only)
local success = State:UpdateSlice("currency", {coins = 100, gems = 10})

-- Subscribe to changes
local unsubscribe = State:Subscribe("currency", function(newValue, oldValue)
    print("Currency updated:", newValue)
end)

-- Create validated state
local newState, error = State:CreateValidatedState("inventory", {
    slots = {},
    capacity = 30
})
```

---

## Service Documentation

### PlayerService

**Location**: `src/ServerScriptService/Server/Services/PlayerService.lua`

Handles player data management, client communication, and player lifecycle.

#### Key Methods

```lua
-- Player lifecycle
function PlayerService:OnPlayerAdded(player)
function PlayerService:OnPlayerRemoving(player)
function PlayerService:OnClientReady(player)

-- Data management
local playerData = PlayerService:GetPlayerData(player)
PlayerService:UpdateSettings(player, settings)
PlayerService:SavePlayerData(player)

-- Specific data updates
PlayerService:UpdateInventory(player, inventory)
PlayerService:UpdateDungeonData(player, dungeonData)

-- Currency operations
local success = PlayerService:AddCurrency(player, "coins", 100)
local success = PlayerService:RemoveCurrency(player, "coins", 50)

-- Communication
PlayerService:SendPlayerData(player)
PlayerService:SendShopData(player)
PlayerService:SendDailyRewardsData(player)
```

#### Features

- **Player data creation and persistence** with DataStore2 integration
- **Currency management** with validation and transaction safety
- **Specific update methods** for inventory and dungeon data
- **Settings management** with client synchronization
- **Integration with EventManager** for client communication
- **Automatic data synchronization** on client ready
- **Service dependency management** for other services

---

### DungeonService

**Location**: `src/ServerScriptService/Server/Services/DungeonService.lua`

Comprehensive dungeon management service combining player dungeons, spawner inventory, and placement logic with individual spawner tracking.

#### Key Methods

```lua
-- Dungeon management
local dungeonData = DungeonService:GetPlayerDungeon(player)
DungeonService:InitializePlayerDungeon(player, dungeonData, worldSlotId)
DungeonService:ValidateDungeonData(player)

-- Spawner slot management
local slotData = DungeonService:GetSpawnerSlot(player, slotIndex)
local canPlace, message = DungeonService:CanPlaceSpawner(player, slotIndex, spawnerType)
local success = DungeonService:UpdateSpawnerSlot(player, slotIndex, spawnerType)

-- Spawner inventory management
local inventory = DungeonService:GetSpawnerInventory(player)
local inventoryWithStatus = DungeonService:GetSpawnerInventoryWithStatus(player)
local spawner = DungeonService:GetAvailableSpawner(player, spawnerType)
local hasSpawner = DungeonService:HasSpawner(player, spawnerType, quantity)

-- Spawner placement and removal
local success = DungeonService:PlaceSpawner(player, slotIndex, spawnerType)
local success = DungeonService:RemoveSpawner(player, slotIndex)

-- Spawner tracking
local success = DungeonService:AddSpawner(player, spawnerType, quantity)
local success = DungeonService:RemoveSpawner(player, spawnerId)
local success = DungeonService:MarkSpawnerAsPlaced(player, spawnerId, slotIndex)
local success = DungeonService:MarkSpawnerAsAvailable(player, spawnerId)

-- Grid and visualization
DungeonService:SendGridData(player)
DungeonService:SendSpawnerInventory(player)
local gridData = DungeonService:CreateGrid(dungeonCenter, dungeonModel, player)
```

#### Features

- **8-slot spawner management** per player with directional placement
- **Individual spawner tracking** with unique IDs and status management
- **Inventory system** with "inventory" and "placed" status tracking
- **Placement validation** with comprehensive error handling
- **Network events** for real-time client updates
- **Grid-based positioning** with 7x7 tile visualization
- **DataStore integration** for persistent spawner data
- **World slot assignment** integration with WorldService

---

### WorldService

**Location**: `src/ServerScriptService/Server/Services/WorldService.lua`

Manages world generation and dungeon assignment system with grid-based layout.

#### Key Methods

```lua
-- World management
WorldService:InitializeWorld()
WorldService:CleanupWorld()

-- Player assignment
local slotId = WorldService:AssignPlayerToDungeon(player)
local worldInfo = WorldService:GetWorldInfo(player)

-- Teleportation
local success, message = WorldService:TeleportPlayerToDungeon(player)

-- Coordinate conversion
local worldPos = WorldService:GridToWorldPosition(gridX, gridZ)
local gridX, gridZ = WorldService:WorldToGridPosition(worldPosition)
```

#### Features

- **Grid-Based World**: 95x81 padded grid with 6 dungeon slots, gaps, centered spawn lobby, and 10-tile map padding
- **Dynamic Assignment**: Automatic player-to-dungeon assignment
- **Tile System**: 5x5 studs per grid unit with precise positioning
- **Spawn Management**: Player respawn location management
- **Asset Loading**: Dynamic tile loading from ServerStorage

---

### ShopService

**Location**: `src/ServerScriptService/Server/Services/ShopService.lua`

Handles shop transactions, item purchases, and shop data management.

#### Key Methods

```lua
-- Purchase processing
local success = ShopService:ProcessPurchase(player, itemId, quantity)

-- Shop management
local item = ShopService:GetItem(itemId)
local shopData = ShopService:GetShopData()

-- Inventory operations
local success = ShopService:AddItem(item)
local success = ShopService:UpdateItem(itemId, updates)
local success = ShopService:RemoveItem(itemId)

-- Featured items
ShopService:SetFeaturedItems(itemIds)
local featured = ShopService:GetFeaturedItems()
```

#### Features

- Transaction processing with validation
- Currency checking and deduction
- Shop item management
- Integration with PlayerService for currency operations
- Error handling and client notifications

---

### RewardService

**Location**: `src/ServerScriptService/Server/Services/RewardService.lua`

Server-side daily rewards system with infinite login streaks and 7-day cycles.

#### Key Methods

```lua
-- Daily rewards
local success, rewardData = RewardService:ClaimDailyReward(player)
local status = RewardService:GetDailyRewardsStatus(player)
RewardService:SendDailyRewardData(player)

-- Bonus rewards
local success = RewardService:GrantBonusReward(player, type, amount, source)

-- Player lifecycle
RewardService:OnPlayerAdded(player)
RewardService:OnPlayerLeaving(player)
```

#### Features

- **7-Day Reward Cycle**: Repeating reward pattern
- **Streak Tracking**: Infinite streak progression
- **Multiple Reward Types**: Coins, gems, items
- **Bonus Rewards**: Additional reward mechanisms
- **Integration**: Works with PlayerService for currency

---

### EmoteService

**Location**: `src/ServerScriptService/Server/Services/EmoteService.lua`

Server-side emote handling and validation with rate limiting and broadcasting.

#### Key Methods

```lua
-- Emote processing
local success, message = EmoteService:ProcessEmote(player, emoteName)
EmoteService:BroadcastEmote(sourcePlayer, emoteName)

-- Emote management
EmoteService:ForceRemoveEmote(targetPlayer)
EmoteService:RemoveEmoteForPlayer(sourcePlayer)

-- Statistics and maintenance
local stats = EmoteService:GetEmoteStats()
EmoteService:CleanupCooldowns()
local validEmotes = EmoteService:GetValidEmotes()
```

#### Features

- **Rate Limiting**: Cooldown system to prevent spam
- **Validation**: Valid emote checking
- **Broadcasting**: Multi-client emote distribution
- **Maintenance**: Automatic cleanup of expired data

---

## Configuration System

### GameConfig.lua

**Location**: `src/ReplicatedStorage/Configs/GameConfig.lua`

Main game configuration with comprehensive settings for all systems.

#### Key Configuration Sections

```lua
-- Currency settings
Currency = {
    StartingCoins = 100,
    StartingGems = 0,
    MaxCoins = 999999,
    MaxGems = 9999
}

-- Dungeon settings
Dungeon = {
    MaxSpawnerSlots = 8,
    DefaultEnergyCapacity = 100,
    EnergyRegenRate = 1, -- per minute
    MaxDurability = 100
}

-- Rate limiting
RateLimits = {
    DungeonOperations = {
        deploy_spawner = {calls = 10, window = 30},
        remove_spawner = {calls = 10, window = 30}
    },
    ShopOperations = {
        buy_crate = {calls = 10, window = 60},
        sell_items = {calls = 50, window = 60}
    }
}

-- World system
World = {
    GridSize = {width = 95, height = 81},
    BaseTileSize = 5,
    MaxDungeonSlots = 6,
    DungeonSize = {width = 23, height = 23}
}

-- Feature toggles
Features = {
    Currency = true,
    Shop = true,
    DungeonSystem = true,
    WorldSystem = true
}
```

### ItemConfig.lua

**Location**: `src/ReplicatedStorage/Configs/ItemConfig.lua`

Comprehensive item definitions for the dungeon-focused item system.

#### Key Configuration Sections

```lua
-- Item types
ItemTypes = {
    MOB_SPAWNER = {
        category = "Spawner",
        stackable = false,
        canDeploy = true,
        durabilityEnabled = true
    }
}

-- Item rarities
ItemRarities = {
    BASIC = {
        name = "Basic",
        color = Color3.fromRGB(150, 150, 150),
        dropChance = 0.6,
        powerMultiplier = 1.0
    }
}

-- Item definitions
Items = {
    goblin_spawner = {
        name = "Goblin Spawner",
        type = "MOB_SPAWNER",
        rarity = "BASIC",
        stats = {
            mobType = "Goblin",
            spawnRate = 5,
            maxMobs = 3
        }
    }
}

-- Loot pools
LootPools = {
    basic_spawner_crate = {
        {itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
    }
}
```

---

## Mixin System

The framework includes a powerful mixin system for composable behavior. All mixins work together seamlessly.

### Available Mixins

#### Cooldownable

**Location**: `src/ServerScriptService/Server/Mixins/Cooldownable.lua`

```lua
-- Define cooldown types
self:DefineCooldown("daily_reward", 86400) -- 24 hours
self:DefineCooldown("spawner_action", 30, {playerSpecific = true})

-- Use cooldowns
self:StartCooldown("daily_reward", player)
local isOnCooldown = self:IsOnCooldown("daily_reward", player)
local remaining = self:GetRemainingCooldown("daily_reward", player)
```

#### RateLimited

**Location**: `src/ServerScriptService/Server/Mixins/RateLimited.lua`

```lua
-- Define rate limits
self:DefineRateLimit("buy_crate", 10, 60) -- 10 purchases per 60 seconds

-- Check and record actions
if self:IsRateLimited("buy_crate", playerId) then
    return false, "Rate limit exceeded"
end
self:RecordAction("buy_crate", playerId)
```

#### Randomizable

**Location**: `src/ServerScriptService/Server/Mixins/Randomizable.lua`

```lua
-- Define random pools
self:DefineRandomPool("crate_rewards", {
    {itemId = "goblin_spawner", weight = 100}
})

-- Select random items
local reward = self:SelectRandom("crate_rewards", player)
local rewards = self:SelectMultipleRandom("crate_rewards", 3, false, player)
```

---

## Bootstrap Pattern

### Server Bootstrap

**Location**: `src/ServerScriptService/Server/Runtime/Bootstrap.server.lua`

```lua
-- Initialize core systems
Logger:Initialize(Config.LOGGING, Network)
EventManager:Initialize(Network)

-- Bind services with dependencies
Injector:Bind("PlayerService", script.Parent.Parent.Services.PlayerService, {
    dependencies = {},
    mixins = {"RateLimited", "Cooldownable"}
})

Injector:Bind("DungeonService", script.Parent.Parent.Services.DungeonService, {
    dependencies = {"PlayerService"},
    mixins = {"RateLimited", "Cooldownable"}
})

-- Initialize and start all services
local services = Injector:ResolveAll()
services:Init()
services:Start()

-- Register events
EventManager:RegisterAllEvents()
local eventConfig = EventManager:CreateServerEventConfig(servicesTable)
EventManager:RegisterEvents(eventConfig)
```

### Service Dependencies

Current service dependency graph:
- **PlayerService**: No dependencies (core service)
- **ShopService**: Depends on PlayerService
- **RewardService**: Depends on PlayerService
- **WorldService**: Depends on PlayerService
- **DungeonService**: Depends on PlayerService
- **EmoteService**: No dependencies

---

## Network Integration

### Client-Server Communication

All services include comprehensive network functions with type safety:

```lua
-- Example network calls from client
local success, message = ShopService:ProcessPurchase(itemId, quantity)
local worldInfo = WorldService:GetWorldInfo()
local dungeonData = DungeonService:GetDungeonData()
```

#### Server-side Event Firing

```lua
-- Clean event firing with proper type validation
local eventData = {
    type = "player_data_update",
    level = playerData.level,
    coins = playerData.coins
}
EventManager:FireEvent("PlayerDataUpdated", player, eventData)
```

#### Real-time Updates

- Player data syncs automatically between server and client
- Dungeon changes notify clients immediately
- Shop transactions provide instant feedback
- World events update spawn locations
- Inventory changes trigger UI updates

---

## Best Practices

### Service Design

1. **Single Responsibility**: Each service handles one domain clearly
2. **Dependency Injection**: Use the Injector for clean dependencies
3. **Network Integration**: Always use `self:GetNetwork()` for consistency
4. **Error Handling**: Provide meaningful error messages to clients
5. **Rate Limiting**: Apply appropriate rate limits to prevent abuse

### State Management

1. **Client-Side**: Use GameState for reactive UI updates
2. **Server-Side**: Use State slices for domain separation
3. **Network Sync**: Let the framework handle state synchronization
4. **Dot-notation**: Use clear, nested property paths

### Configuration

1. **Centralized**: Keep all configuration in GameConfig and ItemConfig
2. **Feature Toggles**: Use Features table for enabling/disabling systems
3. **Easy Tuning**: Make values easily adjustable for balancing
4. **Validation**: Ensure configuration values are validated

### Testing and Debugging

1. **Service Test**: Use ServiceTest.server.lua to verify initialization
2. **Global Access**: Services available via `_G.ServerServices` for debugging
3. **Logging**: Use Logger with appropriate contexts
4. **State Inspection**: Use GameState:GetFullState() for debugging

---

This documentation covers the complete current implementation of the dungeon management game with spawner systems, world generation, and reactive state management.

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Roblox Core Framework](ROBLOX_CORE_FRAMEWORK.md)
- [Server Architecture Documentation](SERVER_ARCHITECTURE.md)