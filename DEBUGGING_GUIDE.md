# World Persistence Debugging Guide

## 🔍 How to Debug World Save/Load Issues

Follow these steps to diagnose why your world isn't persisting:

---

## Step 1: Enable API Access (CRITICAL!)

**Go to Game Settings → Security → Enable "Studio Access to API Services"**

⚠️ **Without this, DataStore will not work at all!**

---

## Step 2: Watch the Output Window

The code now has comprehensive debug logging. Watch for these messages:

### When You Place a Block:
```
[BlockPlace] YourName requesting placement at (x,y,z) with blockId: X
[BlockPlace] ✅ Validation passed for YourName at (x,y,z)
Player YourName placed block X at (x, y, z)
🔄 Marked chunk (cx,cz) as modified (block X at x,y,z)
```

**If you DON'T see "🔄 Marked chunk"**, blocks aren't being tracked!

### When Auto-Save Triggers (every 5 min):
```
===== SaveWorldData called =====
Found X modified chunks to save
  Serialized chunk (0,0)
  Serialized chunk (1,0)
...
Prepared X chunks for saving
Saved X chests
Calling WorldOwnershipService:SaveWorldData...
💾 Saved world data for owner: YourName
✅ WorldOwnershipService saved successfully
💾 SaveWorldData complete: Saved X chunks
=====================================
💾 Auto-saved world data
```

**If you see "Found 0 modified chunks"**, no blocks were placed or chunks weren't marked!

### When You Leave and Rejoin:
```
🏠 YourName is now the owner of this world!
🌍 World initialized with owner's seed: XXXXX
===== LoadWorldData called =====
Found X chunks in saved data
  Loading chunk 1/X at (0,0)
  ✅ Chunk (0,0) loaded successfully
...
✅ Loaded X/X saved chunks from world data
Loading X chests...
=====================================
📦 Loaded owner's saved world data (X chunks)
```

**If you see "Found 0 chunks in saved data"**, nothing was saved!

---

## Step 3: Force a Manual Save

Don't wait 5 minutes. Test immediately:

1. **Place some blocks**
2. **Open server console** (View → Output → type in bottom bar)
3. **Type this command:**
   ```lua
   local Injector = require(game.ServerScriptService.Server.Injector)
   local voxelWorldService = Injector:Resolve("VoxelWorldService")
   voxelWorldService:SaveWorldData()
   ```
4. **Check Output** for save messages

---

## Step 4: Check What Was Saved

After saving, check the data:

```lua
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
local data = worldOwnershipService:GetWorldData()
print("Chunks saved:", data.chunks and #data.chunks or 0)
print("Chests saved:", data.chests and #data.chests or 0)
```

---

## Common Issues & Solutions

### ❌ Issue: "Found 0 modified chunks to save"

**Cause:** Blocks aren't being marked as modified

**Solutions:**
1. Make sure you're actually placing blocks (check block placement logs)
2. Verify `SetBlock` is being called
3. Check if `modifiedChunks` table is being populated

**Debug:**
```lua
local voxelWorldService = Injector:Resolve("VoxelWorldService")
for key in pairs(voxelWorldService.modifiedChunks) do
    print("Modified chunk:", key)
end
```

---

### ❌ Issue: "DataStore not available"

**Cause:** Studio API access not enabled

**Solution:**
1. Game Settings → Security
2. Enable "Studio Access to API Services"
3. Restart Studio
4. Try again

---

### ❌ Issue: "Failed to save player data"

**Cause:** DataStore request limits or errors

**Solutions:**
1. Check if you're hitting rate limits (60 + players×10 per minute)
2. Check Output for specific error messages
3. Try in a private server instead of Studio

---

### ❌ Issue: Saves but doesn't load

**Cause:** Load happening before save completes or timing issue

**Check:**
1. Did you wait for auto-save (5 min) before leaving?
2. Check Output on rejoin for "Found X chunks in saved data"
3. If X = 0, data wasn't saved properly

**Force save before leaving:**
```lua
voxelWorldService:SaveWorldData()
-- Wait 2 seconds
task.wait(2)
-- Now leave
```

---

### ❌ Issue: "Loaded 0/X saved chunks"

**Cause:** Chunks loading but not applying

**Check:**
1. Look for "✅ Chunk loaded successfully" messages
2. Look for "❌ Failed to get chunk" errors
3. Chunks might be loading but world manager isn't initialized

---

## Step 5: Complete Test Flow

### Test 1: First Visit
```
1. Join game
2. Check Output: "📦 New world - no saved data to load"
3. Place 10-20 blocks
4. Check Output: "🔄 Marked chunk..." for each block
5. Force save or wait 5 min
6. Check Output: "💾 SaveWorldData complete: Saved X chunks"
7. Leave game
```

### Test 2: Second Visit
```
1. Rejoin game
2. Check Output: "📦 Loaded owner's saved world data (X chunks)"
3. Check Output: "✅ Loaded X/X saved chunks"
4. Look for your blocks - they should ALL be there!
```

---

## Diagnostic Commands

### Check Modified Chunks
```lua
local count = 0
for _ in pairs(voxelWorldService.modifiedChunks) do count = count + 1 end
print("Modified chunks:", count)
```

### Check World Data
```lua
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
local data = worldOwnershipService:GetWorldData()
print("Seed:", data.seed)
print("Chunks:", data.chunks and #data.chunks or 0)
print("Owner:", data.ownerName)
```

### Force Save
```lua
voxelWorldService:SaveWorldData()
-- Check Output for save logs
```

### Force Load
```lua
voxelWorldService:LoadWorldData()
-- Check Output for load logs
```

---

## What Success Looks Like

### Output on First Visit:
```
Player joined: YourName
🏠 YourName is now the owner of this world!
🌍 World initialized with owner's seed: 123456
📦 New world - no saved data to load
[BlockPlace] YourName requesting placement at (5,350,3)
🔄 Marked chunk (0,0) as modified
[After 5 min or manual save]
===== SaveWorldData called =====
Found 1 modified chunks to save
  Serialized chunk (0,0)
Prepared 1 chunks for saving
💾 Saved world data for owner: YourName
✅ WorldOwnershipService saved successfully
💾 SaveWorldData complete: Saved 1 chunks
```

### Output on Second Visit:
```
Player joined: YourName
🏠 YourName is now the owner of this world!
🌍 World initialized with owner's seed: 123456
===== LoadWorldData called =====
Found 1 chunks in saved data
  Loading chunk 1/1 at (0,0)
  ✅ Chunk (0,0) loaded successfully
✅ Loaded 1/1 saved chunks from world data
📦 Loaded owner's saved world data (1 chunks)
[Your blocks are now visible!]
```

---

## If ALL Else Fails

1. **Check you enabled Studio API access**
2. **Check Output for ANY error messages**
3. **Try in a private server (not Studio)**
4. **Share the Output logs** so I can help diagnose

---

## Quick Checklist

- [ ] Studio API access enabled
- [ ] Placed blocks (saw "🔄 Marked chunk" logs)
- [ ] Waited 5 min or forced save
- [ ] Saw "💾 SaveWorldData complete: Saved X chunks" (X > 0)
- [ ] Left and rejoined
- [ ] Saw "📦 Loaded owner's saved world data (X chunks)"
- [ ] Saw "✅ Loaded X/X saved chunks"
- [ ] Blocks are visible

If all checkboxes are ✅ and blocks still aren't there, share your Output logs!

---

**Debug logging added on:** October 20, 2025

