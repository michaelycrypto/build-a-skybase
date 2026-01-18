# Product Requirements Document: Food & Consumables System
## Skyblox - Hunger & Saturation Restoration

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Survival Mechanics)
> **Estimated Effort**: Medium (4-6 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Food & Consumables system enables players to restore hunger and saturation by consuming food items. This PRD defines the consumption mechanics, hunger/saturation values, eating animations, and integration with the health system. Food items are essential for survival gameplay and provide a core progression loop.

### Why This Matters
- **Survival Mechanic**: Players need food to survive and regenerate health
- **Progression Gate**: Without food, players cannot sustain exploration and combat
- **Core Loop**: Food bridges Farming → Consumption → Survival
- **Minecraft Parity**: Essential for authentic Minecraft-like experience

---

## Table of Contents

1. [Current State & Gap Analysis](#current-state--gap-analysis)
2. [Feature Overview](#feature-overview)
3. [Detailed Requirements](#detailed-requirements)
4. [Minecraft Behavior Reference](#minecraft-behavior-reference)
5. [Technical Specifications](#technical-specifications)
6. [UI/UX Design](#uiux-design)
7. [Technical Architecture](#technical-architecture)
8. [Implementation Plan](#implementation-plan)
9. [Future Enhancements](#future-enhancements)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Apple Item | `Constants.lua` → `BlockType.APPLE = 37` | ✅ Defined |
| Apple Texture | `BlockRegistry.lua` | ✅ Available |
| Basic Item System | `ItemDefinitions.lua` | ✅ Structure exists |
| Inventory System | `PlayerInventoryService` | ✅ Can hold items |
| Health System | `DamageService`, `PlayerService` | ✅ Health exists |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Hunger System | Tracking player hunger/saturation | P0 |
| Consumption Mechanic | Right-click to eat food | P0 |
| Eating Animation | Visual feedback during consumption | P0 |
| Eating Cooldown | Prevent spam eating | P0 |
| Food Values Config | Hunger/saturation per food item | P0 |
| Food Effects System | Special effects (golden apple, etc.) | P1 |
| Eating Sound Effects | Audio feedback | P1 |
| Food Stack Sizes | Different stack limits per food type | P0 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                    FOOD CONSUMPTION FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. Player holds food item in hand/hotbar                      │
│                    ↓                                            │
│   2. Player right-clicks (or presses use key)                   │
│                    ↓                                            │
│   3. Eating animation starts (1.6 seconds)                     │
│      - Arm animation (brings food to mouth)                    │
│      - Progress indicator (optional)                            │
│                    ↓                                            │
│   4. After animation completes:                                 │
│      - Hunger restored (based on food type)                      │
│      - Saturation restored (based on food type)                 │
│      - Special effects applied (if applicable)                  │
│      - Item consumed (stack count -1)                           │
│                    ↓                                            │
│   5. Eating cooldown (0.5 seconds) prevents spam                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Minecraft Parity** - Food values and mechanics match Minecraft exactly
2. **Smooth Experience** - Eating should feel responsive and satisfying
3. **Visual Feedback** - Clear indication of eating progress and effects
4. **Balanced Progression** - Food availability scales with game progression

---

## Detailed Requirements

### FR-1: Hunger & Saturation System

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Track player hunger level (0-20, like Minecraft) | P0 |
| FR-1.2 | Track player saturation level (0-20, hidden from UI) | P0 |
| FR-1.3 | Hunger depletes over time (based on activity) | P0 |
| FR-1.4 | Saturation depletes before hunger when available | P0 |
| FR-1.5 | Health regeneration requires hunger >= 18 | P0 |
| FR-1.6 | Hunger < 6 causes health damage over time | P0 |
| FR-1.7 | Display hunger bar in UI (10 drumstick icons) | P0 |

### FR-2: Consumption Mechanic

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Right-click with food item in hand starts eating | P0 |
| FR-2.2 | Eating can be cancelled by moving or switching items | P0 |
| FR-2.3 | Eating animation duration: 1.6 seconds (32 ticks) | P0 |
| FR-2.4 | Eating cooldown: 0.5 seconds after completion | P0 |
| FR-2.5 | Cannot eat while cooldown is active | P0 |
| FR-2.6 | Cannot eat if hunger is full (20/20) | P0 |
| FR-2.7 | Cannot eat if inventory doesn't contain food item | P0 |

### FR-3: Food Values & Effects

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Each food item has hunger restoration value | P0 |
| FR-3.2 | Each food item has saturation restoration value | P0 |
| FR-3.3 | Food values match Minecraft exactly | P0 |
| FR-3.4 | Special foods apply status effects (golden apple = regeneration) | P1 |
| FR-3.5 | Suspicious stew provides random effects | P2 |
| FR-3.6 | Food consumption removes 1 from stack | P0 |

### FR-4: Visual & Audio Feedback

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Eating animation: arm brings food to mouth | P0 |
| FR-4.2 | Eating sound effect plays during consumption | P1 |
| FR-4.3 | Hunger bar updates immediately after eating | P0 |
| FR-4.4 | Visual effect for special foods (golden apple glow) | P1 |
| FR-4.5 | Status effect icons appear for special foods | P1 |

### FR-5: Stack Sizes

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Most foods stack to 64 (default) | P0 |
| FR-5.2 | Stew/soup items stack to 1 | P0 |
| FR-5.3 | Milk bucket stacks to 1 | P0 |
| FR-5.4 | Stack size defined in ItemDefinitions | P0 |

---

## Minecraft Behavior Reference

### Official Minecraft Food Values

| Food Item | Hunger | Saturation | Notes |
|-----------|--------|------------|-------|
| Apple | 4 | 2.4 | Basic food |
| Bread | 5 | 6.0 | Common food |
| Cooked Beef | 8 | 12.8 | High value |
| Cooked Porkchop | 8 | 12.8 | High value |
| Cooked Chicken | 6 | 7.2 | Medium value |
| Cooked Mutton | 6 | 9.6 | Medium-high value |
| Cooked Rabbit | 5 | 6.0 | Medium value |
| Golden Apple | 4 | 9.6 | + Regeneration II (5s) |
| Enchanted Golden Apple | 4 | 9.6 | + Regeneration V (20s), Absorption IV (2m), Fire Resistance (5m), Resistance (5m) |
| Carrot | 3 | 3.6 | Low value |
| Potato | 1 | 0.6 | Very low value |
| Baked Potato | 5 | 6.0 | Medium value |
| Beetroot | 1 | 1.2 | Very low value |
| Beetroot Soup | 6 | 7.2 | Stack size: 1 |
| Mushroom Stew | 6 | 7.2 | Stack size: 1 |
| Rabbit Stew | 10 | 12.0 | Stack size: 1 |
| Milk Bucket | 0 | 0 | Removes all status effects, stack size: 1 |

### Hunger & Saturation Mechanics

- **Hunger Range**: 0-20 (displayed as 10 drumstick icons, each = 2 hunger)
- **Saturation Range**: 0-20 (hidden, depletes before hunger)
- **Health Regen**: Only when hunger >= 18 and saturation > 0
- **Starvation Damage**: 1 HP every 4 seconds when hunger = 0
- **Hunger Depletion Rate**:
  - Walking: 0.01 per second
  - Sprinting: 0.1 per second
  - Jumping: 0.05 per jump
  - Swimming: 0.015 per second
  - Mining: 0.005 per block
  - Attacking: 0.1 per hit

### Eating Mechanics

- **Eating Duration**: 1.6 seconds (32 game ticks)
- **Eating Animation**: Arm animation bringing food to mouth
- **Eating Cooldown**: 0.5 seconds (10 ticks) after completion
- **Cancellation**: Moving, switching items, or taking damage cancels eating
- **Full Hunger**: Cannot eat if hunger is already 20/20

---

## Technical Specifications

### Hunger System Configuration

```lua
-- FoodConfig.lua
local FoodConfig = {}

-- Food item definitions
FoodConfig.Foods = {
    [Constants.BlockType.APPLE] = {
        hunger = 4,
        saturation = 2.4,
        stackSize = 64,
        effects = {} -- No special effects
    },
    -- Add more foods as they're implemented
}

-- Hunger depletion rates (per second)
FoodConfig.HungerDepletion = {
    walking = 0.01,
    sprinting = 0.1,
    jumping = 0.05, -- Per jump
    swimming = 0.015,
    mining = 0.005, -- Per block
    attacking = 0.1 -- Per hit
}

-- Health regeneration requirements
FoodConfig.HealthRegen = {
    minHunger = 18,
    minSaturation = 0.1 -- Any saturation needed
}

-- Starvation damage
FoodConfig.Starvation = {
    damagePerTick = 0.25, -- 1 HP every 4 seconds
    tickInterval = 4 -- seconds
}

-- Eating mechanics
FoodConfig.Eating = {
    duration = 1.6, -- seconds
    cooldown = 0.5, -- seconds
    cancelOnMove = true,
    cancelOnDamage = true
}

return FoodConfig
```

### Hunger Calculation

```lua
-- Calculate saturation from food
local function calculateSaturation(hungerValue, saturationModifier)
    -- Saturation = hunger * saturationModifier
    return hungerValue * saturationModifier
end

-- Apply food consumption
local function consumeFood(player, foodId, foodConfig)
    local currentHunger = player:GetHunger()
    local currentSaturation = player:GetSaturation()

    local newHunger = math.min(20, currentHunger + foodConfig.hunger)
    local newSaturation = math.min(20, currentSaturation + foodConfig.saturation)

    player:SetHunger(newHunger)
    player:SetSaturation(newSaturation)

    -- Apply special effects
    if foodConfig.effects then
        for _, effect in ipairs(foodConfig.effects) do
            player:ApplyStatusEffect(effect)
        end
    end
end
```

### Eating State Machine

```lua
-- Eating states
local EatingState = {
    IDLE = "idle",
    EATING = "eating",
    COOLDOWN = "cooldown"
}

-- Eating state management
local function startEating(player, foodId)
    if player.eatingState ~= EatingState.IDLE then
        return false -- Already eating or on cooldown
    end

    player.eatingState = EatingState.EATING
    player.eatingStartTime = os.clock()
    player.eatingFoodId = foodId

    -- Start animation
    player:PlayEatingAnimation()

    return true
end

local function updateEating(player)
    if player.eatingState == EatingState.EATING then
        local elapsed = os.clock() - player.eatingStartTime
        local foodConfig = FoodConfig.Foods[player.eatingFoodId]

        if elapsed >= foodConfig.eatingDuration then
            -- Complete eating
            consumeFood(player, player.eatingFoodId, foodConfig)
            player.eatingState = EatingState.COOLDOWN
            player.cooldownEndTime = os.clock() + FoodConfig.Eating.cooldown
        end
    elseif player.eatingState == EatingState.COOLDOWN then
        if os.clock() >= player.cooldownEndTime then
            player.eatingState = EatingState.IDLE
        end
    end
end
```

---

## UI/UX Design

### Hunger Bar Display

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   HEALTH: ████████████████████░░░░  20/20                   │
│   HUNGER: 🍖🍖🍖🍖🍖🍖🍖🍖🍖🍖  20/20                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- **10 Drumstick Icons**: Each icon = 2 hunger points
- **Color Coding**:
  - Full (18-20): Green
  - Good (12-17): Yellow
  - Low (6-11): Orange
  - Critical (0-5): Red
- **Position**: Above health bar, always visible

### Eating Animation

- **Arm Animation**: Right arm brings food item to mouth
- **Duration**: 1.6 seconds smooth animation
- **Progress Indicator** (optional): Small progress bar above hotbar
- **Sound**: Eating sound effect plays during animation

### Status Effect Icons

When special foods are consumed (golden apple, etc.):
- **Icon Display**: Status effect icon appears above hunger bar
- **Duration Timer**: Shows remaining time for effect
- **Tooltip**: Hover to see effect details

---

## Technical Architecture

### New Files Required

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── HungerService.lua              # NEW: Hunger/saturation tracking
│       └── FoodService.lua               # NEW: Food consumption logic
│
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── FoodController.lua            # NEW: Client-side eating input
│   └── UI/
│       └── HungerBar.lua                 # NEW: Hunger bar UI component
│
└── ReplicatedStorage/
    └── Shared/
        └── FoodConfig.lua                 # NEW: Food values configuration
```

### Modified Files

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── PlayerService.lua             # ADD: Hunger/saturation properties
│
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── PlayerController.lua          # ADD: Eating input handling
│
└── ReplicatedStorage/
    └── Configs/
        └── ItemDefinitions.lua            # ADD: Food item flags (isFood, stackSize)
```

### Event Flow

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLIENT    │      │   SERVER    │      │   CLIENT    │
│FoodController│      │ FoodService │      │ HungerBar   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                     │                    │
       │ Right-click food    │                    │
       │────────────────────>│                    │
       │                     │                    │
       │                     │ Validate:          │
       │                     │ - Has food?        │
       │                     │ - Can eat?         │
       │                     │                    │
       │<────────────────────│ StartEating        │
       │                     │                    │
       │ [Play animation]     │                    │
       │                     │                    │
       │                     │<───────────────────│ UpdateHungerBar
       │                     │                    │
       │ [Animation complete] │                    │
       │────────────────────>│ CompleteEating     │
       │                     │                    │
       │                     │ Consume food       │
       │                     │ Update hunger      │
       │                     │ Apply effects      │
       │                     │                    │
       │<────────────────────│ EatingComplete     │
       │                     │ (new hunger)      │
       │                     │                    │
       │                     │──────────────────>│ UpdateHungerBar
       │                     │                    │
```

### Server Events

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestStartEating` | Client → Server | `{foodId}` |
| `EatingStarted` | Server → Client | `{foodId, duration}` or `{error}` |
| `RequestCancelEating` | Client → Server | `{}` |
| `EatingCancelled` | Server → Client | `{}` |
| `RequestCompleteEating` | Client → Server | `{foodId}` |
| `EatingCompleted` | Server → Client | `{hunger, saturation, effects}` |
| `HungerUpdate` | Server → Client | `{hunger, saturation}` (periodic) |

---

## Implementation Plan

### Phase 1: Core Hunger System (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `FoodConfig.lua` | Create food configuration with values |
| 1.2 | `PlayerService.lua` | Add hunger/saturation properties to players |
| 1.3 | `HungerService.lua` | Create hunger tracking service |
| 1.4 | `HungerService.lua` | Implement hunger depletion logic |
| 1.5 | `HungerService.lua` | Implement health regen/starvation logic |

### Phase 2: Consumption Mechanic (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `FoodService.lua` | Create food consumption service |
| 2.2 | `FoodService.lua` | Implement eating validation |
| 2.3 | `FoodService.lua` | Implement food consumption logic |
| 2.4 | `FoodController.lua` | Create client-side eating input |
| 2.5 | `FoodController.lua` | Handle eating animation |

### Phase 3: UI & Visual Feedback (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `HungerBar.lua` | Create hunger bar UI component |
| 3.2 | `HungerBar.lua` | Display 10 drumstick icons |
| 3.3 | `HungerBar.lua` | Color coding based on hunger level |
| 3.4 | `PlayerController.lua` | Add eating animation to character |
| 3.5 | `FoodService.lua` | Add eating sound effects |

### Phase 4: Special Foods & Effects (Day 4-5)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `FoodConfig.lua` | Add special food definitions (golden apple) |
| 4.2 | `FoodService.lua` | Implement status effect application |
| 4.3 | `HungerBar.lua` | Display status effect icons |
| 4.4 | `ItemDefinitions.lua` | Add food item flags and stack sizes |

### Phase 5: Polish & Testing (Day 5-6)

| Task | File | Description |
|------|------|-------------|
| 5.1 | Testing | Test all food items |
| 5.2 | Testing | Test hunger depletion rates |
| 5.3 | Testing | Test eating cancellation |
| 5.4 | Testing | Test special food effects |
| 5.5 | Testing | Test multiplayer synchronization |

### Checklist

```
□ Phase 1: Core Hunger System
  □ Create FoodConfig.lua with food values
  □ Add hunger/saturation to PlayerService
  □ Create HungerService.lua
  □ Implement hunger depletion
  □ Implement health regen/starvation

□ Phase 2: Consumption Mechanic
  □ Create FoodService.lua
  □ Implement eating validation
  □ Implement food consumption
  □ Create FoodController.lua
  □ Handle eating animation

□ Phase 3: UI & Visual Feedback
  □ Create HungerBar.lua component
  □ Display hunger icons
  □ Color coding
  □ Eating animation
  □ Sound effects

□ Phase 4: Special Foods
  □ Add special food configs
  □ Implement status effects
  □ Display effect icons
  □ Update ItemDefinitions

□ Phase 5: Polish & Testing
  □ Test all foods
  □ Test hunger mechanics
  □ Test edge cases
  □ Multiplayer sync
```

---

## Future Enhancements

### v1.1: Advanced Foods
- [ ] Cooked foods (beef, pork, chicken, etc.)
- [ ] Stew/soup items (mushroom stew, rabbit stew, beetroot soup)
- [ ] Milk bucket (removes status effects)
- [ ] Honey bottle
- [ ] Dried kelp

### v1.2: Food Crafting
- [ ] Cooking recipes (raw → cooked)
- [ ] Stew crafting (mushroom stew, etc.)
- [ ] Cake (placeable food block)

### v1.3: Food Effects Expansion
- [ ] Suspicious stew (random effects)
- [ ] Enchanted golden apple (multiple effects)
- [ ] Potion effects from food

### v1.4: Food Quality System
- [ ] Food freshness (optional)
- [ ] Food poisoning (rare chance)
- [ ] Food preferences (player likes/dislikes)

---

## Appendix A: Food Values Reference

| Food Item | Hunger | Saturation | Stack | Special Effects |
|-----------|--------|-----------|-------|-----------------|
| Apple | 4 | 2.4 | 64 | None |
| Bread | 5 | 6.0 | 64 | None |
| Golden Apple | 4 | 9.6 | 64 | Regeneration II (5s) |
| Enchanted Golden Apple | 4 | 9.6 | 64 | Multiple effects (see above) |
| Carrot | 3 | 3.6 | 64 | None |
| Potato | 1 | 0.6 | 64 | None |
| Baked Potato | 5 | 6.0 | 64 | None |
| Beetroot | 1 | 1.2 | 64 | None |
| Beetroot Soup | 6 | 7.2 | 1 | None |
| Mushroom Stew | 6 | 7.2 | 1 | None |
| Rabbit Stew | 10 | 12.0 | 1 | None |
| Milk Bucket | 0 | 0 | 1 | Removes all effects |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_FURNACE.md](../PRD_FURNACE.md), [PRD_FARMING.md](./PRD_FARMING.md)*
