# DataStore Quick Reference

## Quick Overview

This game uses **2 main DataStore systems**:

### 1. Player Data (`PlayerDataStoreService`)
- **Stores:** Player profiles, inventories, stats, settings
- **Key:** `Player_{UserId}`
- **Auto-saves:** Every 5 minutes
- **Service:** `PlayerDataStoreService.lua`

### 2. World Data (`WorldOwnershipService`)
- **Stores:** World chunks, chests, metadata
- **Key:** `World_{OwnerId}`
- **Auto-saves:** Every 5 minutes
- **Service:** `WorldOwnershipService.lua`

---

## Common Tasks

### Force Save Player Data
```lua
-- In server console or script
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
playerDataStoreService:SavePlayerData(player)
```

### Force Save World Data
```lua
local voxelWorldService = Injector:Resolve("VoxelWorldService")
voxelWorldService:SaveWorldData()
```

### Check Player Data
```lua
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
local data = playerDataStoreService:GetPlayerData(player)
print(data)
```

### Update Player Coins
```lua
local playerService = Injector:Resolve("PlayerService")
playerService:AddCurrency(player, "coins", 100)
-- Automatically marks data as dirty for next save
```

### Reset Player Data (Wipe)
```lua
-- Change version in PlayerDataStoreService.lua:
local DATA_STORE_NAME = "PlayerData_v2"  -- Was v1
-- Player will load with default data on next join
```

### Reset World Data (Wipe)
```lua
-- Change version in WorldOwnershipService.lua:
local WORLD_DATA_STORE_NAME = "PlayerOwnedWorlds_v2"  -- Was v1
-- World will generate fresh on next join
```

---

## Data Structure Cheat Sheet

### Player Data
```lua
{
    version = 1,
    profile = {
        level = number,
        experience = number,
        coins = number,
        gems = number,
    },
    inventory = {
        hotbar = {[1..9] = ItemStack},
        inventory = {[1..27] = ItemStack}
    },
    statistics = {...},
    dailyRewards = {...},
    settings = {...}
}
```

### World Data
```lua
{
    ownerId = UserId,
    seed = number,
    chunks = {
        {key, x, z, data},
        ...
    },
    chests = {
        {x, y, z, slots},
        ...
    },
    metadata = {...}
}
```

### ItemStack Format
```lua
{
    itemId = number,  -- 0 = empty
    count = number,
    maxStack = number,
    metadata = table (optional)
}
```

---

## Debugging Commands

### View All Active Sessions
```lua
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
for userId, session in pairs(playerDataStoreService._playerSessions) do
    print(userId, session.player.Name, "Dirty:", session.dirty)
end
```

### Check World Owner
```lua
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
print("Owner:", worldOwnershipService:GetOwnerName())
print("Seed:", worldOwnershipService:GetWorldSeed())
```

### View World Data
```lua
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
local data = worldOwnershipService:GetWorldData()
print("Chunks:", #data.chunks)
print("Chests:", #data.chests)
```

---

## Auto-Save Configuration

Located in `Bootstrap.server.lua`:

```lua
-- Auto-save loop (line ~336)
task.spawn(function()
    while true do
        task.wait(300)  -- 5 minutes = 300 seconds

        -- Save player data
        for _, player in pairs(Players:GetPlayers()) do
            playerService:SavePlayerData(player)
        end

        -- Save world data
        voxelWorldService:SaveWorldData()
    end
end)
```

**Change auto-save interval:** Modify `task.wait(300)` value

---

## Error Handling

All DataStore operations use:
- **Retry logic:** 3 attempts with 1-second delays
- **Fallback:** Returns default data if all retries fail
- **Logging:** Comprehensive error logs in output

### Check for DataStore Errors
Look for these in output:
- `"Failed to load player data"`
- `"Failed to save player data"`
- `"DataStore not available"`

---

## Testing Checklist

### New Player Test
- [ ] Join with new account
- [ ] Check default inventory (blocks in hotbar)
- [ ] Check default coins (100)
- [ ] Place/break blocks
- [ ] Open/close chests
- [ ] Leave server
- [ ] Rejoin server
- [ ] Verify all data persisted

### World Persistence Test
- [ ] Place blocks in world
- [ ] Break blocks
- [ ] Place chest with items
- [ ] Leave server
- [ ] Rejoin server (as owner)
- [ ] Verify blocks persist
- [ ] Verify chest inventory persists

### DataStore Limits Test
- [ ] Have 10+ players join
- [ ] Auto-save triggers
- [ ] Check output for rate limit errors
- [ ] Verify all players save successfully

---

## Common Issues & Solutions

### ❌ "DataStore not available"
**Cause:** Studio API access disabled
**Fix:** Enable in Game Settings > Security > "Enable Studio Access to API Services"

### ❌ Player data not saving
**Cause:** DataStore limits, errors, or disabled
**Fix:**
1. Check output for error logs
2. Verify API access enabled
3. Check auto-save interval hasn't been disabled

### ❌ Inventory disappears on rejoin
**Cause:** Inventory not serialized before save
**Fix:** Verify `PlayerInventoryService:SerializeInventory()` is called in save flow

### ❌ World resets on rejoin
**Cause:** Wrong owner or DataStore key mismatch
**Fix:**
1. Verify first player becomes owner
2. Check `WorldOwnershipService:GetOwnerId()` matches rejoining player
3. Check world data DataStore key format

---

## File Locations

### Services
```
src/ServerScriptService/Server/Services/
├── PlayerDataStoreService.lua      ← Player persistence
├── PlayerService.lua                ← Player management
├── PlayerInventoryService.lua       ← Inventory authority
├── WorldOwnershipService.lua        ← World ownership
├── VoxelWorldService.lua            ← Voxel world
└── ChestStorageService.lua          ← Chest inventories
```

### Bootstrap
```
src/ServerScriptService/Server/Runtime/
└── Bootstrap.server.lua             ← Service initialization
```

### Documentation
```
tds/
├── DATASTORE_ARCHITECTURE.md        ← Full documentation
└── DATASTORE_QUICK_REFERENCE.md     ← This file
```

---

## Performance Metrics

### Target Metrics
- Player load time: < 1 second
- Player save time: < 0.5 seconds
- World load time: < 2 seconds
- World save time: < 1 second

### Monitor These
- DataStore request count (stay under limits)
- Save success rate (should be 99%+)
- Data size per player (keep < 100KB)
- Data size per world (keep < 2MB)

---

## Quick Links

- [Full Documentation](./DATASTORE_ARCHITECTURE.md)
- [Player Service](./src/ServerScriptService/Server/Services/PlayerService.lua)
- [DataStore Service](./src/ServerScriptService/Server/Services/PlayerDataStoreService.lua)
- [World Ownership](./src/ServerScriptService/Server/Services/WorldOwnershipService.lua)

---

**TIP:** Use `warn()` statements temporarily to debug data flow:
```lua
warn("SAVE TRIGGERED:", player.Name, os.time())
warn("DATA:", game:GetService("HttpService"):JSONEncode(data))
```

**Last Updated:** October 20, 2025

