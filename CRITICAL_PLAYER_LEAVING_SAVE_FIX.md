# 🔧 CRITICAL FIX: Player Leaving Save Bug

## The Problem

**World modifications were not being saved when players left the game normally.**

### Root Cause
The `Players.PlayerRemoving` event handler in `Bootstrap.server.lua` was only calling cleanup methods but **never actually saving the data**:

```lua
-- BEFORE (BROKEN):
Players.PlayerRemoving:Connect(function(player)
    logger.Info("Player leaving:", player.Name)
    -- Clean up chest viewing
    chestStorageService:OnPlayerRemoved(player)
    -- Remove player from voxel world
    voxelWorldService:OnPlayerRemoved(player)
    -- Clean up player inventory
    playerInventoryService:OnPlayerRemoved(player)
    -- ❌ NO SAVE CALLS!
end)
```

### Why This Was a Problem
- **Data only saved during server shutdown** via `game:BindToClose()`
- **Normal player leaving didn't trigger any saves**
- In Roblox Studio testing:
  - When you stop the play session, `BindToClose` triggers (saves work)
  - When you leave and rejoin without stopping, `PlayerRemoving` triggers (saves DON'T work)
- **All block placements, breaks, and chest modifications were lost** when the owner left normally

## The Fix

Added proper save calls to the `PlayerRemoving` event handler:

```lua
-- AFTER (FIXED):
Players.PlayerRemoving:Connect(function(player)
    logger.Info("Player leaving:", player.Name)

    -- IMPORTANT: Save player data before cleanup
    if playerService:GetPlayerData(player) then
        logger.Info("💾 Saving player data for:", player.Name)
        playerService:SavePlayerData(player)
    end

    -- IMPORTANT: Save world data if this player is the owner
    if worldOwnershipService:GetOwnerId() == player.UserId then
        logger.Info("💾 Saving world data (owner leaving)...")
        voxelWorldService:SaveWorldData()
        logger.Info("✅ World data saved")
    end

    -- Clean up chest viewing
    chestStorageService:OnPlayerRemoved(player)
    -- Remove player from voxel world
    voxelWorldService:OnPlayerRemoved(player)
    -- Clean up player inventory
    playerInventoryService:OnPlayerRemoved(player)
end)
```

### What This Fixes
✅ **Player data** now saves when they leave (inventory, stats, etc.)
✅ **World data** now saves when the owner leaves (blocks, chunks, chests)
✅ **Works in all scenarios:**
- Normal player leaving (clicking Leave Game)
- Player disconnecting
- Studio play session rejoin (without stopping server)
- Server shutdown (still has `BindToClose` as backup)

## Testing the Fix

### Test Scenario
1. **Join as new player** → Gets fresh skyblock island
2. **Place blocks, break blocks, put items in chest**
3. **Leave the game** (normal leave, not stopping server)
4. **Rejoin** → All modifications should persist

### Expected Logs When Owner Leaves
```
[INFO] [Bootstrap] Player leaving: | PlayerName
💾 Saving player data for: PlayerName
===== SaveWorldData called =====
Found X modified chunks to save
  Updated chunk (0,0)
  Updated chunk (1,0)
...
Prepared X total chunks for saving
Saved Y chests
✅ WorldOwnershipService saved successfully
💾 SaveWorldData complete: Saved X chunks
✅ World data saved
```

### Expected Logs When Owner Rejoins
```
[INFO] [WorldOwnershipService] ✅ Loaded world data for owner | {chunkCount=X, owner=PlayerName}
===== LoadWorldData called =====
Found X chunks in saved data
  Loading chunk 1/X at (0,0)
  ✅ Chunk (0,0) loaded successfully
✅ Loaded X/X saved chunks from world data
Loading Y chests...
Loaded Y chests
```

## Files Changed
- **`src/ServerScriptService/Server/Runtime/Bootstrap.server.lua`**
  - Modified `Players.PlayerRemoving` event handler (lines 306-328)
  - Added `playerService:SavePlayerData(player)` call
  - Added `voxelWorldService:SaveWorldData()` call for owner

## Why This Bug Was Hard to Find
1. **Studio testing confusion:** When you stop play mode, `BindToClose` fires and saves work fine
2. **The "rejoin" scenario** (leave and rejoin without stopping server) was not being tested
3. **Logs didn't show the issue** because no errors occurred - saves simply weren't happening
4. **The cleanup methods were being called** so it looked like everything was working

## Previous Related Fixes
This is the **third critical save/load bug** we've fixed:

1. **Double world generation bug** - World initialized twice with different seeds
2. **Asynchronous loading bug** - Player spawned before chunks finished loading
3. **Double save overwrite bug** - Second save call overwrote data with empty state
4. **❌ THIS BUG: Player leaving save bug** - No save calls in PlayerRemoving handler

All of these have now been resolved! 🎉

## Date
October 20, 2025

