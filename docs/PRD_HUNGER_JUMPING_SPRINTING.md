# Product Requirements Document: Hunger from Jumping and Sprinting
## Skyblox - Activity-Based Hunger Depletion

> **Status**: Ready for Implementation
> **Priority**: P1 (Enhancement - Improves Gameplay Balance)
> **Estimated Effort**: Small (1-2 days)
> **Last Updated**: January 2026

---

## Executive Summary

This PRD defines the implementation of hunger depletion from player activities: **jumping** and **sprinting**. These mechanics add strategic depth to food management, encouraging players to balance movement efficiency with hunger conservation. Sprinting already works via speed detection; jumping detection needs to be connected.

### Why This Matters
- **Gameplay Balance**: Prevents players from sprinting/jumping indefinitely without food cost
- **Strategic Depth**: Players must choose when to sprint vs walk, when to jump vs walk around
- **Minecraft Authenticity**: Matches Minecraft's hunger mechanics for familiar gameplay
- **Food System Integration**: Makes food items more valuable and strategic

---

## Table of Contents

1. [Current State & Gap Analysis](#current-state--gap-analysis)
2. [Feature Overview](#feature-overview)
3. [Detailed Requirements](#detailed-requirements)
4. [Technical Specification](#technical-specification)
5. [Implementation Plan](#implementation-plan)
6. [Testing Checklist](#testing-checklist)
7. [Future Enhancements](#future-enhancements)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Hunger System | `HungerService.lua` | ✅ Fully functional |
| Sprinting Detection | `HungerService.lua` (line 191) | ✅ Working (speed > 16) |
| Jump Depletion Config | `FoodConfig.lua` (line 400) | ✅ Defined (0.05 per jump) |
| Sprint Depletion Config | `FoodConfig.lua` (line 399) | ✅ Defined (0.1 per second) |
| RecordActivity Method | `HungerService.lua` (line 325) | ✅ Exists with jump handling |
| Jump Cooldown Tracking | `HungerService.lua` (line 95, 336) | ✅ Prevents double-counting |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Jump Detection | Triggering hunger depletion on jump | P0 |
| Humanoid.Jumping Monitor | Detecting when player jumps | P0 |
| Client Jump Event (optional) | Alternative detection method | P1 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│              HUNGER DEPLETION FROM ACTIVITIES                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   SPRINTING (Already Working)                                   │
│   ───────────────────────────────────────────────────────────  │
│   • Detected via speed > 16 studs/second                        │
│   • Depletes 0.1 hunger per second while sprinting            │
│   • Saturation depletes first, then hunger                     │
│                                                                 │
│   JUMPING (Needs Implementation)                                │
│   ───────────────────────────────────────────────────────────  │
│   • Detected via Humanoid.Jumping property                     │
│   • Depletes 0.05 hunger per jump                             │
│   • Cooldown: 0.1 seconds between jumps (prevents spam)        │
│   • Saturation depletes first, then hunger                     │
│                                                                 │
│   COMBINED ACTIVITIES                                           │
│   ───────────────────────────────────────────────────────────  │
│   • Sprinting + Jumping = Both deplete hunger                 │
│   • Example: Sprint-jumping depletes 0.1/sec + 0.05/jump        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Fair & Balanced** - Depletion rates match Minecraft values for familiar feel
2. **Non-Intrusive** - Works automatically, no UI changes needed
3. **Performance Friendly** - Efficient detection with cooldowns to prevent spam
4. **Saturation First** - Saturation depletes before hunger (Minecraft behavior)

---

## Detailed Requirements

### FR-1: Jump Detection

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Monitor `Humanoid.Jumping` property for all players | P0 |
| FR-1.2 | Call `HungerService:RecordActivity(player, "jump")` when jump detected | P0 |
| FR-1.3 | Only trigger once per jump (cooldown handled by RecordActivity) | P0 |
| FR-1.4 | Work for all players (existing and newly joined) | P0 |

### FR-2: Sprinting (Already Implemented)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Continue detecting sprinting via speed > 16 studs/second | P0 |
| FR-2.2 | Continue depleting 0.1 hunger per second while sprinting | P0 |
| FR-2.3 | Verify sprinting works correctly with jumping | P0 |

### FR-3: Hunger Depletion Logic

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Saturation depletes before hunger | P0 |
| FR-3.2 | Jumping depletes 0.05 hunger per jump (from FoodConfig) | P0 |
| FR-3.3 | Sprinting depletes 0.1 hunger per second (from FoodConfig) | P0 |
| FR-3.4 | Cooldown prevents double-counting jumps (0.1 second minimum) | P0 |
| FR-3.5 | Depletion stops when hunger and saturation both reach 0 | P0 |

### FR-4: Integration

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Jump detection works alongside existing sprinting | P0 |
| FR-4.2 | Both activities can deplete hunger simultaneously | P0 |
| FR-4.3 | No conflicts with other hunger depletion sources (mining, attacking) | P0 |
| FR-4.4 | Client sync continues to work (hunger UI updates) | P0 |

---

## Technical Specification

### Jump Detection Method

**Option 1: Server-Side Humanoid Monitoring (Recommended)**

```lua
-- In HungerService:OnPlayerAdded
local humanoid = character:WaitForChild("Humanoid")
local lastJumpState = false

-- Monitor Humanoid.Jumping property
RunService.Heartbeat:Connect(function()
    local isJumping = humanoid.Jumping
    if isJumping and not lastJumpState then
        -- Jump just started
        self:RecordActivity(player, "jump")
    end
    lastJumpState = isJumping
end)
```

**Option 2: Humanoid.StateChanged Event**

```lua
-- In HungerService:OnPlayerAdded
humanoid.StateChanged:Connect(function(oldState, newState)
    if newState == Enum.HumanoidStateType.Jumping then
        self:RecordActivity(player, "jump")
    end
end)
```

### Current Sprinting Implementation

```lua
-- Already in HungerService:_updateHungerDepletion (line 191)
if speed > 16 then -- Sprinting threshold
    depletion = depletion + (FoodConfig.HungerDepletion.sprinting * deltaTime)
else
    depletion = depletion + (FoodConfig.HungerDepletion.walking * deltaTime)
end
```

### RecordActivity Method (Already Exists)

```lua
-- In HungerService:RecordActivity (line 325)
if activityType == "jump" then
    -- Prevent double-counting jumps
    if (now - state.lastJumpTime) > 0.1 then
        depletion = FoodConfig.HungerDepletion.jumping
        state.lastJumpTime = now
    end
end
```

### FoodConfig Values (Already Defined)

```lua
FoodConfig.HungerDepletion = {
    walking = 0.01,      -- Per second while walking
    sprinting = 0.1,      -- Per second while sprinting
    jumping = 0.05,       -- Per jump
    swimming = 0.015,     -- Per second while swimming
    mining = 0.005,       -- Per block mined
    attacking = 0.1       -- Per hit/attack
}
```

### Depletion Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    HUNGER DEPLETION FLOW                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Activity Detected (Jump or Sprint)                      │
│                    ↓                                        │
│  2. Calculate Depletion Amount                             │
│     • Jump: 0.05 per jump                                   │
│     • Sprint: 0.1 per second                               │
│                    ↓                                        │
│  3. Deplete Saturation First                               │
│     • If saturation > 0: reduce saturation                 │
│     • Remaining depletion goes to hunger                   │
│                    ↓                                        │
│  4. Deplete Hunger                                          │
│     • Only if saturation depleted or already 0             │
│                    ↓                                        │
│  5. Sync to Client (UI Update)                              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Jump Detection (Day 1)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `HungerService.lua` | Add jump detection in `OnPlayerAdded` |
| 1.2 | `HungerService.lua` | Monitor `Humanoid.Jumping` or `StateChanged` |
| 1.3 | `HungerService.lua` | Call `RecordActivity(player, "jump")` on jump |
| 1.4 | `HungerService.lua` | Clean up jump detection on player removal |

### Phase 2: Testing & Verification (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 2.1 | Testing | Verify jump detection works |
| 2.2 | Testing | Verify cooldown prevents spam |
| 2.3 | Testing | Verify sprinting still works |
| 2.4 | Testing | Verify combined sprint+jump works |
| 2.5 | Testing | Verify saturation depletes first |

### Checklist

```
□ Phase 1: Jump Detection
  □ Add Humanoid.Jumping monitor in OnPlayerAdded
  □ Connect to RecordActivity("jump")
  □ Clean up connections in OnPlayerRemoving
  □ Test with single player

□ Phase 2: Integration Testing
  □ Verify jump depletes 0.05 hunger per jump
  □ Verify cooldown prevents double-counting
  □ Verify sprinting still works (0.1/sec)
  □ Verify sprint+jump both deplete simultaneously
  □ Verify saturation depletes before hunger
  □ Test with multiple players
  □ Verify no performance issues
```

---

## Testing Checklist

### Functional Tests

- [ ] **Jump Detection**
  - [ ] Single jump depletes 0.05 hunger
  - [ ] Multiple jumps deplete correctly (with cooldown)
  - [ ] Jump cooldown prevents spam (0.1 second minimum)
  - [ ] Jump works when hunger > 0
  - [ ] Jump works when saturation > 0
  - [ ] Jump does nothing when both hunger and saturation = 0

- [ ] **Sprinting (Regression)**
  - [ ] Sprinting still depletes 0.1/sec
  - [ ] Sprinting works with hunger > 0
  - [ ] Sprinting works with saturation > 0
  - [ ] Sprinting stops when both = 0

- [ ] **Combined Activities**
  - [ ] Sprinting + jumping both deplete simultaneously
  - [ ] Depletion rates are correct for both
  - [ ] Saturation depletes first, then hunger

- [ ] **Edge Cases**
  - [ ] Works when player joins mid-game
  - [ ] Works when player respawns
  - [ ] No memory leaks (connections cleaned up)
  - [ ] No performance impact with many players

### Performance Tests

- [ ] Jump detection doesn't cause lag spikes
- [ ] Multiple players jumping simultaneously works smoothly
- [ ] No excessive event connections

---

## Future Enhancements

### v1.1: Enhanced Jump Detection
- [ ] Detect jump height (higher jumps = more depletion?)
- [ ] Detect jump distance (long jumps = more depletion?)
- [ ] Different depletion for sprint-jumping vs normal jumping

### v1.2: Visual Feedback
- [ ] Optional: Show hunger depletion indicator when jumping/sprinting
- [ ] Optional: Sound effect when hunger depletes from activity

### v1.3: Configuration Options
- [ ] Allow server admins to adjust depletion rates
- [ ] Per-player difficulty settings (hardcore = more depletion)

### v1.4: Advanced Detection
- [ ] Detect elytra flying (if added)
- [ ] Detect swimming (already in config, needs implementation)
- [ ] Detect climbing (ladders, vines)

---

## Appendix A: FoodConfig Reference

### Current Depletion Rates

| Activity | Rate | Unit | Notes |
|----------|------|------|-------|
| Walking | 0.01 | per second | Already implemented |
| Sprinting | 0.1 | per second | Already implemented |
| Jumping | 0.05 | per jump | **Needs implementation** |
| Swimming | 0.015 | per second | Config exists, not implemented |
| Mining | 0.005 | per block | Already implemented |
| Attacking | 0.1 | per hit | Already implemented |

### Depletion Examples

**Example 1: Sprinting for 10 seconds**
```
Depletion: 10 seconds × 0.1 = 1.0 hunger
Result: 1 hunger point consumed
```

**Example 2: Jumping 20 times**
```
Depletion: 20 jumps × 0.05 = 1.0 hunger
Result: 1 hunger point consumed
```

**Example 3: Sprint-jumping for 5 seconds (10 jumps)**
```
Sprint: 5 seconds × 0.1 = 0.5 hunger
Jumps: 10 jumps × 0.05 = 0.5 hunger
Total: 1.0 hunger consumed
```

---

## Appendix B: Code Locations

### Files to Modify

```
src/
└── ServerScriptService/Server/Services/
    └── HungerService.lua          # ADD: Jump detection logic
```

### Files Already Configured

```
src/
└── ReplicatedStorage/Shared/
    └── FoodConfig.lua              # ✅ Jump depletion rate defined
```

### Related Files

```
src/
├── ServerScriptService/Server/Services/
│   └── PlayerService.lua           # Hunger/saturation getters/setters
└── ReplicatedStorage/Shared/
    └── EventManager.lua            # Client sync events
```

---

## Appendix C: Implementation Notes

### Why Humanoid.Jumping?

- **Reliable**: Roblox's built-in property, always accurate
- **Server-Side**: No client trust required
- **Simple**: No complex velocity calculations needed
- **Performance**: Efficient property check

### Alternative: Velocity-Based Detection

If `Humanoid.Jumping` doesn't work reliably, we can detect jumps via:
- Upward velocity spike (Y velocity > threshold)
- Position change (Y position increases rapidly)
- State machine (grounded → jumping → grounded)

### Cooldown Rationale

0.1 second cooldown prevents:
- Double-counting the same jump
- Rapid jump spam (space bar held)
- Network lag causing duplicate events

---

*Document Version: 1.0*
*Created: January 2026*
*Author: AI Assistant*
*Related: [PRD_FOOD_CONSUMABLES.md](./PRDs/PRD_FOOD_CONSUMABLES.md), [FoodConfig.lua](../src/ReplicatedStorage/Shared/FoodConfig.lua)*
