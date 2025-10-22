# 🎮 Client Architecture Guide

## Overview

This guide explains how to create a clean, maintainable client-side architecture that mirrors your excellent server-side patterns while being optimized for client-specific concerns like UI management, animations, and responsiveness.

## Table of Contents
- [Overview](#overview)
- [Architecture overview](#architecture-overview)
- [Core components](#core-components)
- [Key benefits](#key-benefits)
- [Example: Complete service](#example-complete-service)
- [Getting started](#getting-started)
- [Migration from procedural code](#migration-from-procedural-code)
- [Best practices](#best-practices)
- [Comparison: Server vs Client architecture](#comparison-server-vs-client-architecture)
- [Advanced features](#advanced-features)
- [Related docs](#related-docs)

<a id="architecture-overview"></a>
## 🏗️ Architecture Overview

The client architecture follows the same principles as your server-side code:
- **Dependency Injection** via `ClientInjector`
- **Service-Based Pattern** with `BaseClientService`
- **Composable Mixins** for cross-cutting concerns
- **Lifecycle Management** (Init/Start/Destroy)
- **Automatic Cleanup** and memory management

<a id="core-components"></a>
## 🔧 Core Components

### 1. BaseClientService

The foundation of all client services, providing:
- UI element management and automatic cleanup
- State subscription helpers
- Network integration
- Component lifecycle management

```lua
local BaseClientService = require(script.Parent.BaseClientService)

local MyUIService = setmetatable({}, BaseClientService)
MyUIService.__index = MyUIService

function MyUIService.new()
    local self = setmetatable({}, MyUIService)
    BaseClientService.new(self) -- Initialize base functionality

    self:CreateLogger("MyUIService") -- Create service-specific logger
    return self
end

function MyUIService:Init()
    -- Create UI
    local screenGui = self:CreateScreenGui("MyUI", 10)

    -- Subscribe to state changes with automatic cleanup
    self:SubscribeToState("currency", function(newState, oldState)
        self:UpdateCurrencyDisplay(newState)
    end)

    -- Connect to network events with automatic cleanup
    self:ConnectToNetworkEvent("PlayerJoined", function(playerData)
        self:ShowWelcomeMessage(playerData)
    end)
end

function MyUIService:Destroy()
    -- BaseClientService handles all cleanup automatically!
    BaseClientService.Destroy(self)
end
```

### 2. ClientInjector

Mirrors the server-side `Injector` but optimized for client services:

```lua
local ClientInjector = require(script.Parent.ClientInjector)

-- Bind services with dependencies and mixins
ClientInjector:Bind("CurrencyUIService", script.Services.CurrencyUIService, {
    dependencies = {"NotificationService"},
    mixins = {"Animatable", "Interactive", "Responsive"}
})

-- Initialize all services
local serviceManager = ClientInjector:ResolveAll()
serviceManager:Init()
serviceManager:Start()
```

### 3. Client Mixins

Composable behaviors for common client concerns:

#### Animatable Mixin
Provides UI animation capabilities:
```lua
-- Apply to service
mixins = {"Animatable"}

-- Use in service
self:FadeIn(myElement)
self:ScaleIn(myElement)
self:AnimateNumber(textLabel, 0, 100, 1.0)
self:Bounce(myButton)
```

#### Interactive Mixin
Handles UI interactions and states:
```lua
-- Make buttons interactive with hover/click effects
self:MakeButtonInteractive(myButton, function()
    print("Button clicked!")
end)

-- Enable/disable buttons
self:SetButtonEnabled(myButton, false)

-- Add loading states
self:SetButtonLoading(myButton, true, "Processing...")
```

#### Responsive Mixin
Manages responsive UI layouts:
```lua
-- Make elements responsive to screen size
self:MakeResponsive(myFrame, {
    mobile = { size = UDim2.new(0, 280, 0, 90) },
    tablet = { size = UDim2.new(0, 320, 0, 100) },
    desktop = { size = UDim2.new(0, 350, 0, 110) }
})

-- Create responsive containers
local container = self:CreateResponsiveContainer(parent, "Frame", config)
```

<a id="key-benefits"></a>
## 🎯 Key Benefits

### 1. **Same Patterns as Server**
```lua
-- Server Service Pattern
local MyServerService = setmetatable({}, BaseService)
function MyServerService:Init() ... end

-- Client Service Pattern (identical structure!)
local MyClientService = setmetatable({}, BaseClientService)
function MyClientService:Init() ... end
```

### 2. **Dependency Injection**
```lua
-- Server DI
Injector:Bind("DataService", moduleScript, {
    dependencies = {"ConfigService"},
    mixins = {"Cooldownable"}
})

-- Client DI (same pattern!)
ClientInjector:Bind("UIService", moduleScript, {
    dependencies = {"NotificationService"},
    mixins = {"Animatable"}
})
```

### 3. **Automatic Cleanup**
- UI elements are automatically destroyed
- State subscriptions are automatically disconnected
- Network connections are automatically cleaned up
- Animation tweens are automatically cancelled

### 4. **Type-Safe Reactive State**
```lua
-- State updates automatically trigger UI updates
self:SubscribeToState("currency", function(newState, oldState)
    if newState.coins > oldState.coins then
        self:ShowCoinGainAnimation(newState.coins - oldState.coins)
    end
end)
```

<a id="example-complete-service"></a>
## 📖 Example: Complete Service

Here's a complete example showing the architecture in action:

```lua
--[[
    InventoryUIService - Complete Example
--]]
local BaseClientService = require(script.Parent.BaseClientService)

local InventoryUIService = setmetatable({}, BaseClientService)
InventoryUIService.__index = InventoryUIService

function InventoryUIService.new()
    local self = setmetatable({}, InventoryUIService)
    BaseClientService.new(self)

    self._inventoryGrid = nil
    self._selectedItem = nil

    self:CreateLogger("InventoryUIService")
    return self
end

function InventoryUIService:Init()
    self._logger.Info("Initializing inventory UI")

    -- Create responsive inventory UI
    self:_createInventoryUI()

    -- React to inventory state changes
    self:SubscribeToState("inventory", function(newState, oldState)
        self:_updateInventoryDisplay(newState)
    end)

    -- Setup network functions
    self:_setupNetworkFunctions()
end

function InventoryUIService:Start()
    -- Animate UI in
    if self._inventoryGrid then
        self:SlideInLeft(self._inventoryGrid)
    end
end

function InventoryUIService:_createInventoryUI()
    local screenGui = self:CreateScreenGui("InventoryUI", 15)

    -- Create responsive grid
    local gridFrame, gridLayout = self:CreateResponsiveGrid(screenGui, {
        mobileCellSize = UDim2.new(0, 80, 0, 80),
        tabletCellSize = UDim2.new(0, 100, 0, 100),
        desktopCellSize = UDim2.new(0, 120, 0, 120)
    })

    self._inventoryGrid = gridFrame
    self:RegisterUI(gridFrame)
end

function InventoryUIService:_updateInventoryDisplay(inventoryState)
    -- Clear existing items
    for _, child in ipairs(self._inventoryGrid:GetChildren()) do
        if child:IsA("GuiObject") and child.Name ~= "UIGridLayout" then
            child:Destroy()
        end
    end

    -- Create item slots
    for i, item in ipairs(inventoryState.items) do
        local itemSlot = self:_createItemSlot(item, i)
        itemSlot.Parent = self._inventoryGrid

        -- Animate item in
        self:ScaleIn(itemSlot)
    end
end

function InventoryUIService:_createItemSlot(item, index)
    local slot = self:CreateStyledFrame(nil, "ItemSlot_" .. index,
        UDim2.new(0, 100, 0, 100), UDim2.new(0, 0, 0, 0))

    -- Make interactive
    self:MakeButtonInteractive(slot, function()
        self:_selectItem(item)
    end)

    return slot
end

function InventoryUIService:_selectItem(item)
    self._selectedItem = item
    self._logger.Info("Item selected", {itemId = item.id})

    -- Notify other services
    if self.Deps.NotificationService then
        self.Deps.NotificationService:ShowToast(
            "Selected: " .. item.name, "info", 2
        )
    end
end

return InventoryUIService
```

<a id="getting-started"></a>
## 🚀 Getting Started

### 1. **Create a New Service**
```lua
-- 1. Inherit from BaseClientService
local MyService = setmetatable({}, BaseClientService)

-- 2. Add constructor
function MyService.new()
    local self = setmetatable({}, MyService)
    BaseClientService.new(self)
    self:CreateLogger("MyService")
    return self
end

-- 3. Implement lifecycle
function MyService:Init() -- Setup
function MyService:Start() -- Begin operations
function MyService:Destroy() -- Cleanup (automatic!)
```

### 2. **Bind with Dependencies**
```lua
ClientInjector:Bind("MyService", script.MyService, {
    dependencies = {"NotificationService"},
    mixins = {"Animatable", "Interactive"}
})
```

### 3. **Initialize and Start**
```lua
local serviceManager = ClientInjector:ResolveAll()
serviceManager:Init()
serviceManager:Start()
```

<a id="migration-from-procedural-code"></a>
## 🔄 Migration from Procedural Code

### Before (Procedural)
```lua
-- Scattered UI creation
local screenGui = Instance.new("ScreenGui")
local frame = Instance.new("Frame")
-- ... manual setup

-- Manual event handling
local connection = someEvent:Connect(function() end)

-- Manual cleanup (often forgotten!)
game.Players.PlayerRemoving:Connect(function()
    connection:Disconnect() -- If you remember!
    screenGui:Destroy()
end)
```

### After (Service-Based)
```lua
-- Clean service structure
function MyService:Init()
    -- Automatic UI management
    local screenGui = self:CreateScreenGui("MyUI")

    -- Automatic state subscriptions
    self:SubscribeToState("gameData", function(newState)
        self:UpdateUI(newState)
    end)

    -- Automatic cleanup handled by BaseClientService!
end
```

<a id="best-practices"></a>
## 📋 Best Practices

### 1. **Service Responsibilities**
- **UI Services**: Handle specific UI concerns (inventory, shop, currency)
- **Manager Services**: Coordinate between UI services
- **Utility Services**: Provide common functionality (notifications, audio)

### 2. **State Management**
- Always use reactive state subscriptions
- Never directly manipulate UI from state changes
- Let services handle their own UI updates

### 3. **Mixin Usage**
- Use `Animatable` for services that need UI animations
- Use `Interactive` for services with buttons and inputs
- Use `Responsive` for services that need responsive layouts

### 4. **Cleanup**
- Trust BaseClientService to handle cleanup
- Add custom cleanup via `self:AddCleanupTask()`
- Never manually manage connections/UI lifecycle

<a id="comparison-server-vs-client-architecture"></a>
## 🎯 Comparison: Server vs Client Architecture

| Aspect | Server Pattern | Client Pattern |
|--------|---------------|----------------|
| **Base Class** | `BaseService` | `BaseClientService` |
| **Injector** | `Injector` | `ClientInjector` |
| **Mixins** | `Cooldownable`, `RateLimited` | `Animatable`, `Interactive`, `Responsive` |
| **State** | Server `State` | Client `ClientState` |
| **Concerns** | Data, Business Logic | UI, Animations, Interactions |
| **Lifecycle** | Init/Start/Destroy | Init/Start/Destroy |
| **Dependencies** | Service Dependencies | UI Service Dependencies |
| **Cleanup** | Manual/Automatic | Fully Automatic |

<a id="advanced-features"></a>
## ✨ Advanced Features

### Custom Mixins
```lua
-- Create your own mixins for specific behaviors
local AudioMixin = {
    Apply = function(service)
        service.PlaySound = function(self, soundId)
            -- Custom audio logic
        end
    end
}
```

### Service Communication
```lua
-- Services can depend on each other
ClientInjector:Bind("ShopUIService", script.ShopUIService, {
    dependencies = {"CurrencyUIService", "NotificationService"}
})

-- Use dependencies in service
function ShopUIService:PurchaseItem(item)
    if self.Deps.CurrencyUIService:CanAfford(item.price) then
        -- Purchase logic
        self.Deps.NotificationService:ShowToast("Item purchased!")
    end
end
```

---

**Result**: A client architecture that's as clean and maintainable as your server-side code, with automatic cleanup, composable behaviors, and reactive state management! 🎉

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Roblox Core Framework](ROBLOX_CORE_FRAMEWORK.md)
- [Server-Side API Documentation](API_DOCUMENTATION.md)