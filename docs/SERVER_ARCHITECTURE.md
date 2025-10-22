# Server Architecture Documentation

## Overview

This server architecture provides a scalable, modular system for handling client-server communication and game logic. It consists of four main services that integrate with your existing EventManager system.

## Table of Contents
- [Overview](#overview)
- [Services](#services)
- [EventManager integration](#eventmanager-integration)
- [Architecture benefits](#architecture-benefits)
- [Usage example](#usage-example)
- [Configuration](#configuration)
- [Testing](#testing)
- [Migration from old system](#migration-from-old-system)
- [Extending the system](#extending-the-system)
- [Related docs](#related-docs)

## Services

### 1. PlayerService (`Services/PlayerService.lua`)
Handles all player-related functionality:
- **Player lifecycle management** (join/leave events)
- **Player data management** (currency, inventory, statistics)
- **Client communication** (sending data updates)
- **Settings management**

**Key Methods:**
- `OnClientReady(player)` - Called when client is ready
- `SendPlayerData(player)` - Sends player data to client
- `AddCurrency(player, type, amount)` - Adds coins/gems
- `RemoveCurrency(player, type, amount)` - Removes coins/gems
- `AddItem(player, itemId, quantity)` - Adds items to inventory
- `UpdateSettings(player, settings)` - Updates player settings

### 2. ShopService (`Services/ShopService.lua`)
Handles shop transactions and item management:
- **Purchase processing** with validation
- **Currency checking** and deduction
- **Item management** (add/remove/update shop items)
- **Featured items** management

**Key Methods:**
- `ProcessPurchase(player, itemId, quantity)` - Processes item purchases
- `GetItem(itemId)` - Gets item by ID
- `GetShopData()` - Gets complete shop data
- `AddItem(item)` - Adds new item to shop

### 3. RewardService (`Services/RewardService.lua`)
Handles daily rewards and achievements:
- **Daily rewards system** with streak tracking
- **Achievement rewards**
- **Bonus rewards** for special events
- **Reward validation** and cooldowns

**Key Methods:**
- `ClaimDailyReward(player, dayIndex)` - Claims daily reward
- `GetDailyRewardsStatus(player)` - Gets reward status
- `GrantBonusReward(player, type, amount, message)` - Grants bonus rewards
- `GrantAchievementReward(player, achievementId, rewardData)` - Grants achievement rewards

### 4. WorldService (`Services/WorldService.lua`)
Handles world generation and player assignment:
- **Grid-based world generation**
- **Player dungeon assignment**
- **Spawn location management**
- **Grid data synchronization**

**Key Methods:**
- `SendGridData(player)` - Sends world data to client
- `GetWorldInfo(player)` - Gets world information
- `AssignPlayerToDungeon(player)` - Assigns player to dungeon slot

## EventManager Integration

### Server Events
The services automatically register these events with EventManager:

- `ClientReady` → `PlayerService:OnClientReady(player)`
- `RequestDataRefresh` → `PlayerService:SendPlayerData(player)`
- `RequestGridData` → `WorldService:SendGridData(player)`
- `PurchaseItem` → `ShopService:ProcessPurchase(player, itemId, quantity)`
- `ClaimDailyReward` → `RewardService:ClaimDailyReward(player, dayIndex)`
- `UpdateSettings` → `PlayerService:UpdateSettings(player, settings)`

### Client Events
The services can fire these events to clients:

- `PlayerDataUpdated` - Player stats/data changed
- `CurrencyUpdated` - Coins/gems changed
- `InventoryUpdated` - Inventory changed
- `ShowNotification` - Show notification toast
- `ShowError` - Show error message
- `ShopDataUpdated` - Shop data changed
- `DailyRewardUpdated` - Daily rewards changed
- `GridDataUpdated` - World grid data changed

## Architecture Benefits

### 1. **Modular Design**
- Each service has a single responsibility
- Easy to add new services or modify existing ones
- Clean separation of concerns

### 2. **Dependency Injection**
- Services can depend on other services
- Automatic dependency resolution
- Easy testing and mocking

### 3. **Mixins Support**
- **RateLimited**: Automatic rate limiting for service methods
- **Cooldownable**: Cooldown management for actions
- **Trackable**: Action tracking and analytics

### 4. **Event-Driven Communication**
- Centralized event management
- Type-safe event handling
- Automatic client-server synchronization

### 5. **Lifecycle Management**
- Proper initialization order
- Graceful shutdown with data saving
- Resource cleanup

## Usage Example

```lua
-- The services are automatically initialized by Bootstrap.server.lua
-- You can access them via the global table for debugging:

local playerService = _G.ServerServices.PlayerService
local shopService = _G.ServerServices.ShopService

-- Example: Give a player bonus coins
playerService:AddCurrency(player, "coins", 500)

-- Example: Process a purchase
shopService:ProcessPurchase(player, "basic_crate", 1)

-- Example: Grant daily reward
local rewardService = _G.ServerServices.RewardService
rewardService:ClaimDailyReward(player, 1)
```

## Configuration

Services use the shared Config module for configuration:

```lua
-- In ReplicatedStorage.Shared.Config
Config.Game.Currency = {
    StartingCoins = 1000,
    StartingGems = 50
}

Config.SERVER = {
    SAVE_INTERVAL = 300 -- Auto-save every 5 minutes
}
```

## Testing

Use the `ServiceTest.server.lua` script to verify that all services are working correctly. It will:
- Check service initialization
- Verify EventManager integration
- Test dependency injection
- Validate service methods

## Migration from Old System

If you're migrating from the old `GameServer.server.lua` system:

1. **Keep the old system** as a fallback during transition
2. **Update client code** to use the new event names if needed
3. **Test thoroughly** with the ServiceTest script
4. **Remove old system** once confident in the new architecture

## Extending the System

To add a new service:

1. **Create service class** extending `BaseService`
2. **Add to Bootstrap.server.lua** with proper dependencies
3. **Register events** in EventManager if needed
4. **Update client** to handle new events
5. **Add tests** to verify functionality

Example:
```lua
-- In Bootstrap.server.lua
Injector:Bind("MyNewService", script.Parent.Parent.Services.MyNewService, {
    dependencies = {"PlayerService"},
    mixins = {"RateLimited"}
})
```

## Related Docs
- [Documentation Index](../../../DOCS_INDEX.md)
- [Server-Side API Documentation](../../../API_DOCUMENTATION.md)
- [Roblox Core Framework](../../../ROBLOX_CORE_FRAMEWORK.md)