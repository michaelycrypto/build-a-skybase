# Development Checklist

## Before Writing Code

### ✅ API Usage
- [ ] Check `docs/API_REFERENCE.md` for correct method names
- [ ] Verify EventManager methods exist before using them
- [ ] Use `EventManager:RegisterEventHandler()` NOT `RegisterServerEvent()`
- [ ] Use `EventManager:RegisterEventHandler()` NOT `RegisterClientEvent()`

### ✅ Service Integration
- [ ] Check if service exists before calling methods
- [ ] Use proper error handling with `pcall()` for service calls
- [ ] Verify service initialization before using

### ✅ Event Registration
- [ ] Use correct EventManager methods
- [ ] Check event names match EVENT_DEFINITIONS
- [ ] Test event handlers work correctly

## Before Committing

### ✅ Code Review
- [ ] No hardcoded API method names without verification
- [ ] All service calls have proper error handling
- [ ] Event registration uses correct methods
- [ ] No copy-paste errors from other files

### ✅ Testing
- [ ] Test the code in Studio
- [ ] Check console for errors
- [ ] Verify services initialize properly
- [ ] Test event handling works

## Common Mistakes to Avoid

### ❌ EventManager Mistakes
```lua
-- WRONG - These methods don't exist
EventManager:RegisterServerEvent("EventName", handler)
EventManager:RegisterClientEvent("EventName", handler)

-- CORRECT - Use these instead
EventManager:RegisterEventHandler("EventName", handler)
```

### ❌ Service Integration Mistakes
```lua
-- WRONG - No error handling
ProximityGridService:Initialize()

-- CORRECT - With error handling
if ProximityGridService and ProximityGridService.Initialize then
    ProximityGridService:Initialize()
else
    Logger:Warn("ProximityGridService not available")
end
```

### ❌ Copy-Paste Mistakes
- Don't copy method names from other files without verifying they exist
- Always check the actual service/API for available methods
- Use IDE autocomplete when available

## Quick Reference

### EventManager Methods
- `RegisterEventHandler(eventName, handler)` - Register any event handler
- `FireEvent(eventName, player, ...)` - Fire to specific player (server)
- `FireEventToAll(eventName, ...)` - Fire to all clients (server)
- `SendToServer(eventName, ...)` - Send to server (client)

### Service Integration Pattern
```lua
-- Always check if service exists
if ServiceName and ServiceName.MethodName then
    local success, error = pcall(function()
        ServiceName:MethodName(params)
    end)
    if not success then
        Logger:Warn("Service method failed", {error = error})
    end
end
```

## Emergency Fixes

### If You Get "Missing Method" Errors
1. Check `docs/API_REFERENCE.md` for correct method name
2. Look at existing working code for examples
3. Use IDE autocomplete to see available methods
4. Check the service file directly for method definitions

### If Services Don't Initialize
1. Check if service file exists and is properly required
2. Verify service has Initialize method
3. Check for circular dependencies
4. Look at console errors for clues
