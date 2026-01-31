# PRD: Delayed Character Spawn & Server-Side Position Polling

**Status**: Draft  
**Author**: Assistant  
**Date**: 2026-01-31  
**Priority**: Critical (Blocking Hub Teleport)

---

## 1. Problem Statement

When players teleport from a World server to a Hub server, they experience:

1. **Falling into void**: Character spawns before voxel terrain is loaded
2. **Remote queue exhaustion**: Client spams `VoxelPlayerPositionUpdate` before server is ready
3. **Stuck loading screen**: Client waits for `WorldStateChanged` that never arrives or arrives with `isReady=false`

**Root Cause**: Roblox auto-spawns characters immediately on join. The voxel world initialization and chunk streaming cannot keep up with this timing.

---

## 2. Goals

| Goal | Success Criteria |
|------|------------------|
| **No void falling** | Character spawns only after terrain exists beneath spawn point |
| **No remote spam** | Zero "queue exhausted" errors in logs |
| **Reliable loading** | 100% success rate teleporting World → Hub |
| **Clean architecture** | Remove unnecessary client-to-server position sync |

---

## 3. Current State

### Current Flow (Broken)
```
1. Player teleports to Hub
2. PlayerAdded fires
3. Roblox auto-spawns character (CharacterAutoLoads = true by default)
4. Character falls (no terrain)
5. Client initializes, fires VoxelPlayerPositionUpdate repeatedly
6. Server still initializing services...
7. Remote queue fills (256 limit), events dropped
8. Server eventually ready, but client in broken state
9. Client stuck on "Waiting for world ready"
```

### Current Position Tracking
- Client fires `VoxelPlayerPositionUpdate` event with `{x, z}` coordinates
- Server stores in `VoxelWorldService.players[player].position`
- `StreamChunksToPlayers()` reads from this stored position

### Current Anchoring (Incomplete)
- `anchorHubCharacter()` exists but races with auto-spawn
- Character may move before anchor is applied

---

## 4. Proposed Solution

### New Flow
```
1. Player teleports to Hub
2. PlayerAdded fires
3. Server sets Players.CharacterAutoLoads = false (already set at startup)
4. Server checks: Is VoxelWorldService ready?
   - If NO: Player waits (no character yet)
   - If YES: Continue
5. Server determines spawn position from VoxelWorldService
6. Server calls player:LoadCharacter()
7. CharacterAdded fires
8. Server positions character at spawn (on solid ground)
9. Server starts streaming chunks around player
10. Client receives chunks, meshes them
11. Client sends ClientLoadingComplete
12. Loading screen fades
13. Player can move
```

### Key Changes

| Component | Current | Proposed |
|-----------|---------|----------|
| **CharacterAutoLoads** | `true` (default) | `false` |
| **Character spawn trigger** | Automatic on join | Manual via `LoadCharacter()` after world ready |
| **Position tracking** | Client sends remote | Server reads `HumanoidRootPart.Position` directly |
| **VoxelPlayerPositionUpdate** | Active, causes spam | Deprecated, handler is no-op |

---

## 5. Technical Implementation

### 5.1 Bootstrap.server.lua Changes

#### A. Disable Auto Character Loading (Early in file, before any player can join)

```lua
-- At top of file, immediately after services are obtained
Players.CharacterAutoLoads = false
```

#### B. Hub Player Handler (Replace current `addHubPlayer`)

```lua
local function addHubPlayer(player)
    -- Wait for world to be ready before spawning character
    if not voxelWorldService:IsWorldReady() then
        logger.Warn("World not ready for player", {player = player.Name})
        -- World should already be ready for Hub, but safety check
        local timeout = 10
        local waited = 0
        while not voxelWorldService:IsWorldReady() and waited < timeout do
            task.wait(0.5)
            waited += 0.5
        end
        if not voxelWorldService:IsWorldReady() then
            player:Kick("Hub failed to initialize. Please try again.")
            return
        end
    end
    
    -- Get spawn position from voxel world
    local spawnPos = voxelWorldService:GetSpawnPosition()
    
    -- Load the character
    player:LoadCharacter()
    
    -- Wait for character to exist
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    
    if hrp then
        -- Position at spawn
        hrp.CFrame = CFrame.new(spawnPos)
    end
    
    -- Register player with VoxelWorldService (starts chunk streaming)
    voxelWorldService:OnPlayerAdded(player)
    
    -- Send world ready signal to client
    dispatchWorldState("ready", "hub_player_spawned", player)
    
    -- Load player data
    if playerService then
        playerService:OnPlayerAdded(player)
    end
end
```

#### C. World Player Handler (Similar pattern)

```lua
-- In the IS_WORLD section, modify the player added handler
local function addWorldPlayer(player)
    -- ... existing teleport context parsing ...
    
    -- Wait for world initialization
    while not worldReady and waitTime < WORLD_READY_TIMEOUT do
        task.wait(0.1)
        waitTime += 0.1
    end
    
    if not worldReady then
        player:Kick("World failed to initialize. Please try again.")
        return
    end
    
    -- Get spawn position
    local spawnPos = voxelWorldService:GetSpawnPosition()
    
    -- Load character
    player:LoadCharacter()
    
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    
    if hrp then
        hrp.CFrame = CFrame.new(spawnPos)
    end
    
    -- Continue with existing initialization...
    voxelWorldService:OnPlayerAdded(player)
    dispatchWorldState("ready", "world_player_spawned", player)
    -- ...
end
```

### 5.2 VoxelWorldService.lua Changes

#### A. Change `StreamChunksToPlayers` to Read Position Directly

```lua
function VoxelWorldService:StreamChunksToPlayers()
    if not self:IsWorldReady() then return end
    
    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if not character then continue end
        
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        
        -- Read position directly from character (server-authoritative)
        local pos = hrp.Position
        local x, z = pos.X, pos.Z
        
        -- Update internal tracking (for chunk decisions)
        local state = self.players[player]
        if state then
            state.position = pos
        end
        
        -- Stream chunks based on this position
        self:_streamChunksForPlayer(player, x, z)
    end
end
```

#### B. Deprecate `UpdatePlayerPosition` (Make it a No-Op)

```lua
-- Keep for backwards compatibility but do nothing
function VoxelWorldService:UpdatePlayerPosition(player, positionOrX, maybeZ)
    -- DEPRECATED: Server now reads position directly from character
    -- This method is kept to prevent errors from old clients
    return
end
```

### 5.3 GameClient.client.lua Changes

#### A. Remove `VoxelPlayerPositionUpdate` Calls

Find and remove/comment these lines:

```lua
-- REMOVE: EventManager:SendToServer("VoxelPlayerPositionUpdate", { x = pos.X, z = pos.Z })
-- REMOVE: EventManager:SendToServer("VoxelPlayerPositionUpdate", { x = ..., z = ... })
```

There are 2 locations in GameClient.client.lua (lines ~1631 and ~1710).

#### B. Simplify `PlayerEntitySpawned` Handler

The handler no longer needs to send position updates. It should just:
1. Set up the camera
2. Request initial chunks (optional, server will auto-stream)
3. Wait for chunks to load
4. Signal completion

### 5.4 EventManager.lua Changes (Optional Cleanup)

The `VoxelPlayerPositionUpdate` handler can be simplified to a no-op:

```lua
{
    name = "VoxelPlayerPositionUpdate",
    handler = function(player, positionData)
        -- DEPRECATED: Server reads position directly from character
        -- Handler kept for backwards compatibility
    end
},
```

---

## 6. Edge Cases

| Edge Case | Handling |
|-----------|----------|
| **Player joins before world ready** | Wait loop with timeout, kick if exceeds |
| **Character dies** | `CharacterAdded` triggers, server repositions at spawn |
| **Player disconnects during load** | `PlayerRemoving` cleans up, no special handling needed |
| **Multiple rapid teleports** | Each server instance handles its own players independently |
| **Studio testing** | Works same as production (CharacterAutoLoads = false) |

---

## 7. Respawn Handling

When a character dies and respawns:

```lua
player.CharacterAdded:Connect(function(character)
    local hrp = character:WaitForChild("HumanoidRootPart", 5)
    if hrp and voxelWorldService:IsWorldReady() then
        local spawnPos = voxelWorldService:GetSpawnPosition()
        hrp.CFrame = CFrame.new(spawnPos)
    end
end)
```

This ensures respawns also land on solid ground.

---

## 8. Files to Modify

| File | Changes |
|------|---------|
| `Bootstrap.server.lua` | Add `CharacterAutoLoads = false`, refactor `addHubPlayer`/`addWorldPlayer` |
| `VoxelWorldService.lua` | Modify `StreamChunksToPlayers`, deprecate `UpdatePlayerPosition` |
| `GameClient.client.lua` | Remove `VoxelPlayerPositionUpdate` calls |
| `EventManager.lua` | (Optional) Simplify handler to no-op |

---

## 9. Testing Plan

### Test Cases

| # | Test | Expected Result |
|---|------|-----------------|
| 1 | Fresh join to Hub | Character spawns on solid ground, no falling |
| 2 | Teleport World → Hub | Character spawns on solid ground, no errors |
| 3 | Teleport Hub → World | Character spawns on solid ground, no errors |
| 4 | Die and respawn in Hub | Respawns on solid ground |
| 5 | Die and respawn in World | Respawns on solid ground |
| 6 | Check server logs | No "queue exhausted" errors |
| 7 | Check client logs | No remote spam warnings |
| 8 | Slow network test | Loading screen stays until chunks ready |

### Verification Commands

```lua
-- In server console, verify CharacterAutoLoads is false
print(game.Players.CharacterAutoLoads) -- Should print: false

-- Check for any VoxelPlayerPositionUpdate events being fired
-- (Should see none after fix)
```

---

## 10. Rollback Plan

If issues arise:

1. Revert `CharacterAutoLoads` to `true` (or remove the line)
2. Restore `VoxelPlayerPositionUpdate` client calls
3. Restore `UpdatePlayerPosition` implementation

The old code paths are being deprecated, not deleted, so rollback is straightforward.

---

## 11. Future Considerations

- **Predictive chunk loading**: If needed, server can calculate movement direction from position deltas between frames
- **Custom spawn points**: The `GetSpawnPosition()` method can be extended to support beds, waypoints, etc.
- **Anti-cheat**: Server-authoritative position makes it impossible for clients to spoof location for chunk loading

---

## 12. Summary

This PRD eliminates the root cause of Hub loading failures by:

1. **Taking control of character spawn timing** (`CharacterAutoLoads = false`)
2. **Removing unnecessary client→server position sync** (server reads directly)
3. **Ensuring terrain exists before character spawns** (sequential initialization)

The result is a deterministic, race-condition-free loading flow that works reliably for all teleport scenarios.
