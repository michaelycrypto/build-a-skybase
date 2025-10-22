# World Generation Testing Guide

## 🧪 How to Test the Fixed World Save/Load System

This guide will help you verify that the world generation and persistence is working correctly.

---

## Test 1: New Player Experience

### Setup
1. Enable Studio API access (Game Settings → Security)
2. Clear any existing DataStore data (optional - for clean test)
3. Start the game in Studio

### Steps
1. **Join the game** as Player 1
2. **Watch the Output** for these logs:
   ```
   🏠 YourUsername is now the owner of this world!
   🌍 World initialized with owner's seed: [number]
   📦 New world - no saved data to load
   ```
3. **Spawn into the world**
   - Should spawn at coordinates around (0, 350, 0)
   - Should see Skyblock-style floating island
4. **Place some blocks**
   - Place blocks at different locations
   - Break some blocks
   - Create a simple structure
5. **Open a chest and add items**
   - Place a chest (hotbar slot 6)
   - Open it and add some blocks
6. **Wait for auto-save** or **leave the game**
   - Auto-save happens every 5 minutes
   - Watch output for: `"💾 Auto-saved world data"`

### Expected Result
✅ World generates once with unique seed
✅ Blocks can be placed and broken
✅ Changes are tracked
✅ Data saves successfully

---

## Test 2: Returning Player Experience

### Setup
Continue from Test 1 (same player, same world)

### Steps
1. **Rejoin the game** with the same account
2. **Watch the Output** for these logs:
   ```
   🏠 YourUsername is now the owner of this world!
   🌍 World initialized with owner's seed: [same seed as before]
   📦 Loaded owner's saved world data (X chunks)
   ```
3. **Spawn into the world**
4. **Verify your changes persisted**
   - Go to where you placed blocks
   - Check if structure is still there
   - Open the chest you placed
   - Verify items are still in the chest

### Expected Result
✅ Same seed used as first join
✅ Saved chunks loaded
✅ Placed blocks still there
✅ Chest inventory restored
✅ No regeneration occurred

---

## Test 3: Performance Test

### Purpose
Verify that world only generates once (not twice)

### Steps
1. **Start game** and watch Output
2. **Before joining**, note the time
3. **Join the game**
4. **Watch Output for generation messages**
5. **Note time when world is ready**

### What to Look For

**❌ OLD BEHAVIOR (Bug):**
```
[Server] Initializing voxel world (Skyblock mode)...
[VoxelWorld] World initialized (seed: 12345)      ← First generation
[Player joined]
[World] World recreated with owner's seed: 456789  ← Second generation (BAD!)
```

**✅ NEW BEHAVIOR (Fixed):**
```
[Server] VoxelWorldService ready - waiting for owner to join...
[Player joined]
[World] World initialized (seed: 456789)          ← Only ONE generation (GOOD!)
[World] Loaded owner's saved world data
```

### Expected Result
✅ Only ONE world generation message
✅ No "recreated" message
✅ Faster startup time
✅ Smoother experience

---

## Test 4: Different Player (New World)

### Setup
Use a different Roblox account

### Steps
1. **Join with different account**
2. **Watch Output** for:
   ```
   🏠 DifferentPlayer is now the owner of this world!
   🌍 World initialized with owner's seed: [different seed]
   📦 New world - no saved data to load
   ```
3. **Verify it's a fresh world**
   - No blocks from previous player
   - Fresh terrain
   - New Skyblock island

### Expected Result
✅ Different seed generated
✅ Fresh world
✅ No data from other player

---

## Test 5: Edge Cases

### Test 5A: Server Restart
1. Join and place blocks
2. Wait for auto-save
3. Stop and restart server
4. Rejoin with same account
5. **Verify:** Blocks still there

### Test 5B: No Auto-Save (Quick Rejoin)
1. Join and place blocks
2. Leave immediately (no auto-save)
3. Rejoin
4. **Expected:** Blocks NOT there (didn't save)

### Test 5C: Multiple Chests
1. Place 5 chests in different locations
2. Fill each with different items
3. Save and rejoin
4. **Verify:** All chests have correct items

---

## 🐛 Common Issues & Solutions

### Issue: "DataStore not available"
**Cause:** Studio API access not enabled
**Fix:** Game Settings → Security → Enable API Access

### Issue: World regenerates on rejoin
**Cause:** Fix not applied correctly
**Fix:** Verify Bootstrap.server.lua changes

### Issue: Blocks don't persist
**Cause:** Auto-save not working or DataStore disabled
**Fix:** Check output for save logs, verify API access

### Issue: Wrong seed on rejoin
**Cause:** WorldOwnershipService not loading saved data
**Fix:** Check DataStore key format, verify save occurred

---

## 📊 Expected Log Output

### Server Start (No Player Yet)
```
🚀 Starting server...
Initializing all services...
PlayerDataStoreService initialized
WorldOwnershipService initialized
VoxelWorldService initialized
✅ Server ready
VoxelWorldService ready - waiting for owner to join...  ← NEW
```

### First Player Joins (New World)
```
Player joined: TestPlayer
🏠 TestPlayer is now the owner of this world!
VoxelWorldService: World initialized (seed: 123456)
🌍 World initialized with owner's seed: 123456
📦 New world - no saved data to load
```

### First Player Joins (Existing World)
```
Player joined: TestPlayer
✅ Loaded world data for owner: TestPlayer
🏠 TestPlayer is now the owner of this world!
VoxelWorldService: World initialized (seed: 123456)
🌍 World initialized with owner's seed: 123456
📦 Loaded owner's saved world data (15 chunks)
```

### Auto-Save
```
Saved player data: TestPlayer
Saved 8 modified chunks
Saved 3 chests
💾 Saved world data for owner: TestPlayer
💾 Auto-saved world data
```

---

## ✅ Success Criteria

### Functional Tests
- [ ] New player gets unique seed
- [ ] World generates only once
- [ ] Blocks persist across sessions
- [ ] Chests persist across sessions
- [ ] Auto-save works every 5 minutes
- [ ] Different players get different worlds

### Performance Tests
- [ ] No double generation
- [ ] World ready within 3 seconds
- [ ] No regeneration on rejoin
- [ ] Smooth player spawn

### Data Integrity Tests
- [ ] Correct seed used on rejoin
- [ ] All chunks load correctly
- [ ] Chest inventories restore
- [ ] No data corruption

---

## 🎯 Quick Validation Commands

### Check Current Owner
```lua
-- In server console
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
print("Owner:", worldOwnershipService:GetOwnerName())
print("Seed:", worldOwnershipService:GetWorldSeed())
```

### Check World State
```lua
local voxelWorldService = Injector:Resolve("VoxelWorldService")
print("World initialized:", voxelWorldService.world ~= nil)
print("World manager:", voxelWorldService.worldManager ~= nil)
```

### Check Saved Chunks
```lua
local worldData = worldOwnershipService:GetWorldData()
print("Saved chunks:", worldData.chunks and #worldData.chunks or 0)
print("Saved chests:", worldData.chests and #worldData.chests or 0)
```

### Force Save
```lua
voxelWorldService:SaveWorldData()
print("World data saved!")
```

---

## 📝 Testing Checklist

### Before Testing
- [ ] Studio API access enabled
- [ ] Latest code deployed
- [ ] Output window visible

### During Testing
- [ ] Watch output logs
- [ ] Note any errors
- [ ] Check performance
- [ ] Test all scenarios

### After Testing
- [ ] All tests passed
- [ ] No errors in output
- [ ] Data persisted correctly
- [ ] Performance acceptable

---

## 🎉 If All Tests Pass

You've successfully verified:
✅ World generates only once
✅ Correct seed used
✅ Data persists properly
✅ Performance improved
✅ System working as designed

**The fix is complete and working!**

---

**Test Guide Version:** 1.0
**Date:** October 20, 2025
**Status:** Ready for Testing

