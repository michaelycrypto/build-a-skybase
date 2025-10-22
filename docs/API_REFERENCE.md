# API Reference Guide

## EventManager API

### ✅ CORRECT Methods (Use These)

#### Server-Side Methods
- `EventManager:RegisterEventHandler(eventName, handler)` - Register event handlers
- `EventManager:RegisterEvent(eventName, handler)` - Alias for RegisterEventHandler
- `EventManager:FireEvent(eventName, player, ...)` - Fire event to specific player
- `EventManager:FireEventToAll(eventName, ...)` - Fire event to all clients

#### Client-Side Methods
- `EventManager:RegisterEventHandler(eventName, handler)` - Register event handlers
- `EventManager:SendToServer(eventName, ...)` - Send event to server
- `EventManager:ConnectToServer(eventName, callback)` - Connect to server events

### ❌ WRONG Methods (Don't Use These)
- `EventManager:RegisterServerEvent()` - **DOES NOT EXIST**
- `EventManager:RegisterClientEvent()` - **DOES NOT EXIST**
- `EventManager:FireToServer()` - **DOES NOT EXIST**
- `EventManager:FireToClient()` - **DOES NOT EXIST**

### Common Patterns
```lua
-- Server-side event registration
EventManager:RegisterEventHandler("EventName", function(player, data)
    -- Handle event
end)

-- Client-side event registration
EventManager:RegisterEventHandler("EventName", function(data)
    -- Handle event
end)

-- Fire event from server to client
EventManager:FireEvent("EventName", player, data)

-- Send event from client to server
EventManager:SendToServer("EventName", data)
```

## Service Integration Patterns

### WorldService Integration
```lua
-- Initialize with proximity system
if ProximityGridService and ProximityGridService.Initialize then
    ProximityGridService:Initialize()
end

-- Create grid in proximity system
local success = ProximityGridService:CreateGrid(gridId, centerPosition, size, tileSize)
```

### Error Handling Patterns
```lua
-- Always check if service exists before using
if ServiceName and ServiceName.MethodName then
    local success, error = pcall(function()
        ServiceName:MethodName(params)
    end)
    if not success then
        Logger:Warn("Service method failed", {error = error})
    end
end
```
