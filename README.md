# 🎮 Roblox Core Framework - Minimal & AI-Friendly

A **clean, minimal game framework** for Roblox that follows the [Roblox Core Framework](ROBLOX_CORE_FRAMEWORK.md) specification. Perfect for AI-assisted development with simple patterns, dependency injection, composable mixins, and DataStore2 integration.

## 🎯 **Why This Framework?**

- ✅ **AI-Friendly**: Simple patterns that AI can easily understand and extend
- ✅ **Framework Compliant**: Follows the core framework document exactly
- ✅ **Minimal**: Clean architecture with powerful composable mixins
- ✅ **Production Ready**: Solid foundation with DataStore2 integration
- ✅ **Clear Separation**: Perfect server/client authority boundaries

## 📁 **Project Structure**

```
src/
├── ReplicatedStorage/
│   ├── Shared/                    # Pure Lua utilities (both server & client)
│   │   ├── Network.lua            # Simple remotes wrapper
│   │   ├── State.lua              # Basic state management
│   │   ├── Logger.lua             # Logging utility
│   │   └── Signal.lua             # Event system
│   ├── Assets/                    # Static resources
│   └── Configs/
│       └── GameConfig.lua         # Simple game configuration
├── ServerScriptService/           # Server Authority
│   ├── Server/
│   │   ├── Services/
│   │   │   └── BaseService.lua    # Base class for all services
│   │   ├── Mixins/                # Composable behavior
│   │   │   ├── Cooldownable.lua   # Cooldown management
│   │   │   ├── RateLimited.lua    # Rate limiting
│   │   │   ├── Randomizable.lua   # Random systems
│   │   │   └── Progressable.lua   # Progress tracking
│   │   ├── Runtime/
│   │   │   └── Bootstrap.server.lua # Server startup
│   │   └── Injector.lua           # Dependency injection
│   └── DataStore2.rbxm            # DataStore2 for data persistence
└── StarterPlayerScripts/          # Client Experience
    ├── Services/
    │   └── UIService.lua           # UI management
    ├── Components/
    │   └── CurrencyDisplay.lua     # Pure UI components
    └── Runtime/
        └── Bootstrap.client.lua    # Client startup
```

## 🚀 **Quick Start**

### 1. **Clone & Install**
```bash
git clone <repo-url>
cd roblox-core-framework
```

### 2. **Build with Rojo**
```bash
rojo build default.project.json -o game.rbxl
```

### 3. **Ready to Extend**
The framework is ready for you to add your game services! DataStore2 is already integrated for robust data persistence.

## 🏗️ **Creating Services (AI-Friendly Pattern)**

### **Server Service with Mixins**
```lua
-- ServerScriptService/Server/Services/CurrencyService.lua
local BaseService = require(script.Parent.BaseService)
local Network = require(game.ReplicatedStorage.Shared.Network)

local CurrencyService = setmetatable({}, BaseService)
CurrencyService.__index = CurrencyService

function CurrencyService.new()
    local self = setmetatable({}, CurrencyService)
    self.Deps = {}
    return self
end

function CurrencyService:Init()
    -- Mixins are already applied - use their functionality!
    self:DefineRateLimit("add_coins", 5, 10) -- Rate limiting from mixin
    self:DefineCooldown("daily_reward", 86400) -- Cooldown from mixin

    -- Network functions
    local addCoins = Network:DefineFunction("AddCoins", {"number"})
    addCoins:Returns({"boolean", "number"})
    addCoins:SetCallback(function(player, amount)
        return self:AddCoins(player, amount)
    end)
end

function CurrencyService:AddCoins(player, amount)
    local playerId = tostring(player.UserId)

    -- Use mixin functionality
    if self:IsRateLimited("add_coins", playerId) then
        return false, 0
    end

    self:RecordAction("add_coins", playerId)

    -- Use DataService dependency for persistence
    local data = self.Deps.DataService:GetPlayerData(player)
    if not data then return false, 0 end

    local newBalance = data.coins + amount
    self.Deps.DataService:UpdatePlayerData(player, "coins", newBalance)

    return true, newBalance
end

return CurrencyService
```

### **Register Service with Mixins**
```lua
-- ServerScriptService/Server/Runtime/Bootstrap.server.lua
Injector:Bind("CurrencyService", script.Parent.Parent.Services.CurrencyService, {
    dependencies = {"DataService"},
    mixins = {"RateLimited", "Cooldownable"}
})
```

### **Data Service with DataStore2**
```lua
-- ServerScriptService/Server/Services/DataService.lua
local BaseService = require(script.Parent.BaseService)
local DataStore2 = require(script.Parent.Parent.DataStore2)

local DataService = setmetatable({}, BaseService)
DataService.__index = DataService

function DataService.new()
    local self = setmetatable({}, DataService)
    self.Deps = {}
    self._playerData = {}
    return self
end

function DataService:Init()
    -- DataStore2 setup
    DataStore2.Combine("MainData", "coins", "gems", "level", "experience")

    -- Handle player events
    game.Players.PlayerAdded:Connect(function(player)
        self:LoadPlayerData(player)
    end)

    game.Players.PlayerRemoving:Connect(function(player)
        self:SavePlayerData(player)
    end)
end

function DataService:LoadPlayerData(player)
    local userId = tostring(player.UserId)

    -- Create DataStore2 instances for each data type
    local coinStore = DataStore2("coins", player)
    local gemStore = DataStore2("gems", player)
    local levelStore = DataStore2("level", player)
    local expStore = DataStore2("experience", player)

    -- Load with defaults
    self._playerData[userId] = {
        coins = coinStore:Get(100), -- Starting coins
        gems = gemStore:Get(0),
        level = levelStore:Get(1),
        experience = expStore:Get(0),
        stores = {
            coins = coinStore,
            gems = gemStore,
            level = levelStore,
            experience = expStore
        }
    }

    return self._playerData[userId]
end

function DataService:UpdatePlayerData(player, key, value)
    local userId = tostring(player.UserId)
    local data = self._playerData[userId]

    if not data then return false end

    -- Update cached value
    data[key] = value

    -- Save to DataStore2
    if data.stores[key] then
        data.stores[key]:Set(value)
    end

    return true
end

return DataService
```

## 🎨 **Mixin System**

### **Available Mixins**

| Mixin | Purpose | Key Methods |
|-------|---------|-------------|
| **Cooldownable** | Manage cooldowns | `DefineCooldown`, `StartCooldown`, `IsOnCooldown` |
| **RateLimited** | Prevent spam | `DefineRateLimit`, `IsRateLimited`, `RecordAction` |
| **Randomizable** | Weighted random | `DefineRandomPool`, `SelectRandom`, `RandomChance` |
| **Progressable** | Track progress | `SetProgressTarget`, `UpdateProgress`, `GetProgress` |

### **Using Mixins**

```lua
-- In service registration
Injector:Bind("ShopService", script.Parent.Services.ShopService, {
    dependencies = {"CurrencyService", "DataService"},
    mixins = {"RateLimited", "Randomizable", "Progressable"}
})

-- In service Init method
function ShopService:Init()
    -- Rate limiting
    self:DefineRateLimit("purchase", 3, 30) -- 3 purchases per 30 seconds

    -- Random loot
    self:DefineRandomPool("common_loot", {
        {item = "health_potion", weight = 40},
        {item = "iron_sword", weight = 20}
    })

    -- Progress tracking
    self:SetProgressTarget("purchases", 10, function()
        -- Give achievement
    end)
end
```

## 🔄 **Data Flow Pattern**

The framework enforces **unidirectional data flow** with **server authority**:

```
DataStore2 → Server Service → Network Events → Client UI Updates
```

### **Example: Currency System**
1. **DataStore2**: Persistent storage with automatic backups
2. **Server Service**: `CurrencyService:AddCoins(player, 50)`
3. **Network**: `Network:Fire("CurrencyChanged", "coins", newAmount)`
4. **Client UI**: Updates automatically (read-only)

## 📚 **Framework Benefits**

### **For Developers**
- 🧠 **Easy to Learn**: Simple patterns with powerful mixins
- 🔄 **Easy to Test**: Isolated services with dependency injection
- 📈 **Easy to Scale**: Add features without breaking existing code
- 🐛 **Easy to Debug**: Clear data flow and error handling

### **For AI Assistants**
- 🎯 **Predictable Patterns**: Same structure for every service
- 📁 **Clear File Organization**: Know exactly where to put code
- 🔗 **Composable Behavior**: Mix and match functionality with mixins
- 📋 **Minimal Boilerplate**: Focus on business logic, not infrastructure

### **DataStore2 Integration**
- 💾 **Robust Persistence**: Automatic backups and session locking
- 🔄 **Cross-Server Sync**: Data changes sync across servers
- ⚡ **Automatic Caching**: Built-in caching for performance
- 🛡️ **Data Safety**: Prevents data loss and corruption

## 🎯 **Framework Compliance**

| Principle | Status | Implementation |
|-----------|--------|----------------|
| **Three-Plane Model** | ✅ | Clear Shared/Server/Client separation |
| **Server Authority** | ✅ | Services own all game state |
| **Client Experience** | ✅ | UI services handle presentation only |
| **Dependency Injection** | ✅ | Advanced injector with mixin support |
| **Composable Behavior** | ✅ | Powerful mixin system for cross-cutting concerns |
| **Data Persistence** | ✅ | DataStore2 integration for robust data handling |

## 📖 **Documentation**

**Complete and Organized** - 25 focused documents (cleaned from 70 files)

### Framework & Architecture
- 🧭 [**Documentation Index**](docs/DOCS_INDEX.md) - Complete documentation navigation
- 📐 [**Core Framework Specification**](docs/ROBLOX_CORE_FRAMEWORK.md) - Architecture principles
- 🔧 [**Server-Side API Documentation**](docs/API_DOCUMENTATION.md) - Complete server API reference
- 🖥️ [**Client Architecture Guide**](docs/CLIENT_ARCHITECTURE_GUIDE.md) - Client patterns and structure
- 🗂️ [**Server Architecture**](docs/SERVER_ARCHITECTURE.md) - Server services overview

### Voxel World System
- 🌍 [**START_HERE**](START_HERE.md) - Voxel world quick start guide
- 📋 [**Terrain Quick Reference**](TERRAIN_QUICK_REFERENCE.md) - Concise terrain API
- 🔍 [**Troubleshooting**](TROUBLESHOOTING.md) - Common issues and solutions

### Game Systems
- 🧱 [**Spawner Slot System**](docs/SPAWNER_SLOT_SYSTEM.md) - Spawner deployment
- 🧪 [**Mob Spawning Implementation**](docs/MOB_SPAWNING_IMPLEMENTATION.md) - Mob mechanics
- 🎞️ [**Mob Animation System**](docs/MOB_ANIMATION_SYSTEM.md) - Animation system
- 📦 [**Mob Package System Guide**](docs/MOB_PACKAGE_SYSTEM_GUIDE.md) - Package management
- 📈 [**Player Progression Guide**](docs/PROGRESSION_GUIDE.md) - Progression design

**See [Documentation Index](docs/DOCS_INDEX.md) for the complete list of all 25 documents.**

## 🤖 **AI Development Tips**

### **Adding New Features**
1. **Create Service**: Extend BaseService with your business logic
2. **Choose Mixins**: Select appropriate mixins for cross-cutting concerns
3. **Register Service**: Add to Bootstrap with dependencies and mixins
4. **Network Layer**: Define client-server communication contracts

### **Common Patterns**
```lua
-- Service with mixins pattern (copy this)
local MyService = setmetatable({}, BaseService)
MyService.__index = MyService

function MyService.new()
    local self = setmetatable({}, MyService)
    self.Deps = {}
    return self
end

function MyService:Init()
    -- Configure mixins
    self:DefineRateLimit("action", 5, 60)
    self:DefineCooldown("ability", 30)

    -- Setup network
    -- Setup event handlers
end

function MyService:Start()
    -- Start operations
end

return MyService
```

---

**Perfect foundation for building scalable Roblox games with AI assistance!** 🚀

The framework provides everything you need: dependency injection, composable mixins, robust data persistence with DataStore2, and clear architectural patterns that both humans and AI can easily understand and extend.