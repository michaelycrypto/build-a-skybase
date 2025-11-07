# Minecraft-Inspired Passive Mob AI System

## Overview

This document describes the comprehensive passive mob AI system inspired by Minecraft's passive mob behaviors. The system implements realistic animal behaviors including wandering, fleeing, panicking when damaged, idle states, and edge avoidance.

---

## Key Features

### ✅ Implemented Behaviors

1. **Idle State** - Mobs stand still and slowly rotate to look around
2. **Wander State** - Random exploration within spawn area
3. **Flee State** - Run away from nearby players
4. **Panic State** - Frantic running after taking damage (Minecraft behavior)
5. **Tempt State** - Follow players holding food items (framework ready)
6. **Terrain Following** - Automatically adjust to ground height
7. **Edge Avoidance** - Prevent falling off cliffs
8. **Look Around** - Rotate head randomly while idle

---

## Behavior Priority System

The AI uses a priority-based state machine. Higher priority behaviors override lower ones:

```
1. PANIC     (when damaged - overrides everything)
2. TEMPT     (following player with food)
3. FLEE      (nearby player detection)
4. IDLE      (standing still, looking around)
5. WANDER    (default behavior)
```

---

## State Descriptions

### 1. Panic State (Priority 1)

**Trigger:** When mob takes damage
**Duration:** Configurable per mob type (default: 5 seconds)
**Behavior:**
- Run in random directions at full speed
- Picks new random targets continuously
- Cannot be interrupted by flee or tempt
- Overrides all other behaviors

**Minecraft Accuracy:** ✅ Matches Minecraft's panic behavior for sheep and other passive mobs

**Code Location:**
```lua
MobEntityService:_updatePanicBehavior(mob, brain, def, position, dt, now)
```

---

### 2. Tempt State (Priority 2)

**Trigger:** Player within range holding tempting item (e.g., wheat for sheep)
**Distance:** Configurable (default: 30 studs / 10 blocks)
**Behavior:**
- Follow player holding food
- Stop when within 2 studs of player
- Walk at normal speed
- Cancel wander/idle states

**Status:** Framework implemented, awaits inventory system integration

**Code Location:**
```lua
MobEntityService:_updateTemptBehavior(mob, brain, def, position, player, dt)
findPlayerWithTemptItem(self, position, players, temptItems, maxDistance)
```

---

### 3. Flee State (Priority 3)

**Trigger:** Player within flee distance
**Distance:** Configurable (default: 30 studs / 10 blocks)
**Behavior:**
- Run away from player at run speed
- Target position: 1.5x flee distance away
- Includes edge avoidance (won't run off cliffs)
- Turns 90° if edge detected ahead

**Improvements over previous version:**
- ✅ Fixed flee distance calculation
- ✅ Edge avoidance prevents cliff deaths
- ✅ Proper target distance (was broken before)

**Code Location:**
```lua
MobEntityService:_updateFleeBehavior(mob, brain, def, position, fleeDir, dt)
```

---

### 4. Idle State (Priority 4)

**Trigger:** After reaching wander point (40% chance) or timeout
**Duration:** Configurable (default: 5-12 seconds)
**Behavior:**
- Stand completely still (velocity = 0)
- Slowly rotate to look around
- Changes look direction every 2-5 seconds
- Smooth rotation interpolation

**New Features:**
- ✅ Random look directions
- ✅ Smooth rotation
- ✅ Configurable idle duration
- ✅ Properly uses `wanderInterval` config

**Code Location:**
```lua
MobEntityService:_updateIdleBehavior(mob, brain, position, dt, now)
```

---

### 5. Wander State (Priority 5 - Default)

**Trigger:** No higher priority behaviors active
**Behavior:**
- Pick random points within wander radius
- Walk at normal speed
- 40% chance to idle when reaching target
- 60% chance to pick new wander target immediately
- Edge avoidance (cancels target if cliff ahead)

**Wander Radius:** Configurable per mob (default: ~24 studs / 8 blocks)

**Code Location:**
```lua
MobEntityService:_updateWanderBehavior(mob, brain, def, position, dt, now)
```

---

## Helper Systems

### Terrain Following

**Function:** `updateGroundY(self, position)`

**Purpose:** Keep mobs on the ground regardless of terrain height changes

**How it works:**
1. Converts world position to block coordinates
2. Raycasts downward from current position
3. Finds first solid block with air above
4. Sets mob Y position to block surface + small offset

**Benefits:**
- ✅ Mobs walk up/down hills naturally
- ✅ No floating or sinking into terrain
- ✅ Smooth terrain following

---

### Edge Avoidance

**Function:** `isEdgeAhead(self, position, direction, checkDistance)`

**Purpose:** Prevent mobs from walking off cliffs

**How it works:**
1. Checks position ahead in movement direction
2. Raycasts down to find ground
3. Returns `true` if drop is > 3 blocks or no ground found

**Behavior when edge detected:**
- **Wander:** Cancels current target, picks new one
- **Flee:** Turns 90° and continues fleeing

**Benefits:**
- ✅ Prevents accidental deaths from falls
- ✅ Realistic animal behavior
- ✅ Matches Minecraft's edge detection

---

### Tempting System (Framework)

**Function:** `findPlayerWithTemptItem(self, position, players, temptItems, maxDistance)`

**Purpose:** Find players holding food items that attract mobs

**Status:** Framework ready, awaits inventory system

**When enabled:**
- Sheep will follow players holding wheat
- Cows will follow players holding wheat
- Chickens will follow players holding seeds
- etc.

---

## Configuration

### Sheep Configuration Example

```lua
SHEEP = {
    -- Basic stats
    maxHealth = 8,
    walkSpeed = 4,          -- studs/second
    runSpeed = 7,           -- studs/second when fleeing/panicking

    -- Wander behavior
    wanderRadius = studs(8),              -- 24 studs / 8 blocks
    wanderInterval = { min = 5, max = 12 },  -- Idle time in seconds

    -- Flee behavior
    fleeDistance = studs(10),  -- 30 studs / 10 blocks

    -- Panic behavior
    panicDuration = 5,  -- Seconds of panic after damage

    -- Tempt behavior (not yet active)
    temptItems = { "WHEAT" },
    temptDistance = blocks(10),  -- 30 studs
}
```

---

## Brain State Structure

Each mob has a `brain` table tracking AI state:

```lua
brain = {
    -- Wander state
    wanderTarget = Vector3 or nil,  -- Current wander destination

    -- Idle state
    idleUntil = number,  -- os.clock() timestamp when idle ends
    lookRotation = number,  -- Target rotation for looking around
    nextLookChange = number,  -- When to pick new look direction

    -- Panic state
    panicUntil = number,  -- os.clock() timestamp when panic ends
    panicTarget = Vector3 or nil,  -- Panic run destination

    -- Hostile mob state
    lastAttackTime = number,
    targetPlayer = Player or nil
}
```

---

## Performance Characteristics

### Update Rates
- **AI Updates:** 10 Hz (every 0.1 seconds)
- **Network Updates:** 4 Hz (every 0.25 seconds)
- **Terrain Following:** Every AI tick
- **Edge Detection:** Only when moving

### Spawn Caps
- **Passive Mobs:** 12 per world
- **Hostile Mobs:** 55 per world

### Network Efficiency
- ✅ Batched updates (`MobBatchUpdate` event)
- ✅ Position arrays instead of Vector3 objects
- ✅ Only sends changed mobs

---

## Comparison with Minecraft

| Feature | Minecraft | This Implementation | Status |
|---------|-----------|---------------------|--------|
| Random wandering | ✅ | ✅ | Complete |
| Idle periods | ✅ | ✅ | Complete |
| Panic when damaged | ✅ | ✅ | Complete |
| Flee from players | ✅ | ✅ | Complete |
| Edge avoidance | ✅ | ✅ | Complete |
| Terrain following | ✅ | ✅ | Complete |
| Look around while idle | ✅ | ✅ | Complete |
| Tempting with food | ✅ | ⏳ | Framework ready |
| Breeding | ✅ | ❌ | Future feature |
| Grazing (sheep-specific) | ✅ | ❌ | Future feature |
| Baby mobs follow parents | ✅ | ❌ | Future feature |

---

## Bug Fixes

### Fixed in This Version

1. **Flee Distance Bug** 🐛 → ✅
   - **Before:** `targetPos = position + fleeDir * def.runSpeed` (7 studs)
   - **After:** `targetPos = position + fleeDir * fleeTargetDistance` (45 studs)

2. **No Idle State** → ✅
   - **Before:** Mobs wandered continuously
   - **After:** Mobs pause and look around between wander points

3. **No Terrain Following** → ✅
   - **Before:** `groundY` set once at spawn
   - **After:** `groundY` updated every frame

4. **Unused Config** → ✅
   - **Before:** `wanderInterval` defined but not used
   - **After:** Used for idle duration

5. **No Edge Avoidance** → ✅
   - **Before:** Mobs could walk off cliffs
   - **After:** Edge detection prevents cliff falls

6. **No Panic State** → ✅
   - **Before:** No reaction to damage
   - **After:** Panic for 5 seconds after taking damage

---

## Future Enhancements

### High Priority
1. **Breeding System** - Mobs enter love mode with food
2. **Grazing** - Sheep eat grass to regrow wool
3. **Baby Mobs** - Smaller models, follow parents

### Medium Priority
4. **Advanced Pathfinding** - Navigate around obstacles
5. **Water Detection** - Swim behavior
6. **Jump Over Obstacles** - 1-block step-up

### Low Priority
7. **Group Behaviors** - Flocking, following leaders
8. **Day/Night Cycles** - Different behavior at night
9. **Mob Sounds** - Ambient sounds and damage sounds

---

## Testing Checklist

### Manual Testing

- [ ] **Idle Behavior**
  - Spawn sheep and observe pauses between movement
  - Verify smooth head rotation while idle
  - Check 40% idle chance works

- [ ] **Wander Behavior**
  - Verify sheep wander within spawn radius
  - Check they don't wander too far
  - Confirm edge avoidance works

- [ ] **Flee Behavior**
  - Approach sheep and verify they flee
  - Check flee distance is correct (~45 studs)
  - Verify edge avoidance during flee

- [ ] **Panic Behavior**
  - Damage sheep and observe panic
  - Verify panic lasts ~5 seconds
  - Check panic overrides other behaviors

- [ ] **Terrain Following**
  - Spawn sheep on hills
  - Verify they follow terrain height
  - Check they don't float or sink

- [ ] **Edge Avoidance**
  - Spawn sheep near cliffs
  - Verify they don't walk off edges
  - Check they turn away from cliffs

### Automated Testing (Future)

```lua
-- Test idle state transitions
-- Test panic duration
-- Test flee distance calculation
-- Test terrain following
-- Test edge detection
```

---

## Code Architecture

### Files Modified

1. **MobEntityService.lua** (Server)
   - Main AI update loop
   - 5 behavior update functions
   - 3 helper functions
   - Panic triggering in damage handler

2. **MobRegistry.lua** (Shared Config)
   - Added panic configuration
   - Added tempt configuration
   - Updated comments

### Functions Added

```lua
-- Helper functions
updateGroundY(self, position) -> number
isEdgeAhead(self, position, direction, checkDistance) -> boolean
findPlayerWithTemptItem(self, position, players, temptItems, maxDistance) -> Player, number

-- Behavior functions
MobEntityService:_updatePanicBehavior(mob, brain, def, position, dt, now)
MobEntityService:_updateTemptBehavior(mob, brain, def, position, player, dt)
MobEntityService:_updateFleeBehavior(mob, brain, def, position, fleeDir, dt)
MobEntityService:_updateIdleBehavior(mob, brain, position, dt, now)
MobEntityService:_updateWanderBehavior(mob, brain, def, position, dt, now)
```

---

## Summary

This passive mob AI system provides a **comprehensive, Minecraft-accurate implementation** of animal behaviors. The system is:

- ✅ **Realistic** - Mimics Minecraft passive mob behaviors
- ✅ **Performant** - Optimized for 12+ mobs per world
- ✅ **Maintainable** - Clean separation of behaviors
- ✅ **Extensible** - Easy to add new behaviors
- ✅ **Configurable** - All parameters data-driven

The implementation fixes all major bugs from the previous version and adds several new features including panic states, edge avoidance, and terrain following.

---

## Credits

Based on Minecraft's passive mob AI system by Mojang Studios
Implemented for TDS (Tower Defense Simulator) Roblox game

