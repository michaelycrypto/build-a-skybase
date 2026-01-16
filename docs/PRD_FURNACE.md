# Product Requirements Document: Furnace System
## Skyblox - Interactive Smelting Feature

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Blocks Tutorial Completion)
> **Estimated Effort**: Medium (3-5 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Furnace is a core progression mechanic that transforms raw ores into usable ingots. This PRD defines an **interactive skill-based smelting system** where players actively manage furnace temperature to smelt efficiently. Better temperature control = less coal consumed.

### Why This Matters
- **Tutorial Blocker**: The "Smelt Copper Ingots" tutorial step is currently impossible
- **Progression Gate**: Without smelting, players cannot craft any metal tools or armor
- **Core Loop**: Furnace bridges Mining → Crafting, essential for the GATHER → CRAFT → UPGRADE loop

---

## Table of Contents

1. [Current State & Gap Analysis](#current-state--gap-analysis)
2. [Feature Overview](#feature-overview)
3. [Detailed Requirements](#detailed-requirements)
4. [Mini-Game Specification](#mini-game-specification)
5. [Fuel Efficiency System](#fuel-efficiency-system)
6. [UI/UX Design](#uiux-design)
7. [Technical Architecture](#technical-architecture)
8. [Implementation Plan](#implementation-plan)
9. [Future Enhancements](#future-enhancements)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Furnace Block Type | `Constants.lua` → `BlockType.FURNACE = 35` | ✅ Defined |
| Furnace Textures | `BlockRegistry.lua` | ✅ Top, side, front, back textures |
| Furnace Properties | `BlockProperties.lua` | ✅ Hardness 3.5, pickaxe required |
| Furnace Recipe | `RecipeConfig.lua` | ✅ 8 Cobblestone → 1 Furnace |
| Smelting Recipes | `RecipeConfig.lua` | ✅ 6 recipes with `requiresFurnace = true` |
| Interactable Flag | `BlockRegistry.lua` | ✅ `interactable = true` |
| Tutorial Steps | `TutorialConfig.lua` | ✅ craft_furnace, place_furnace, smelt_copper |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Furnace Click Handler | Opening furnace UI | P0 |
| FurnaceUI.lua | Player interaction | P0 |
| Smelting Mini-Game | Core mechanic | P0 |
| SmeltingService.lua | Server-side validation | P0 |
| Recipe Filtering | Show smelting recipes in furnace | P0 |
| Fuel Efficiency Logic | Reward skilled play | P1 |
| Furnace State (optional) | Persistence | P2 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                     FURNACE SMELTING FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. Player right-clicks placed Furnace                         │
│                    ↓                                            │
│   2. FurnaceUI opens (recipe list + mini-game area)            │
│                    ↓                                            │
│   3. Player selects smelting recipe (e.g., Copper Ingot)       │
│                    ↓                                            │
│   4. Mini-game starts: Temperature Balance Challenge           │
│      - Hold to heat, release to cool                           │
│      - Keep indicator in optimal zone (zone slowly drifts)     │
│                    ↓                                            │
│   5. Progress bar fills based on time in zone                  │
│                    ↓                                            │
│   6. Smelt completes → Ingot added to inventory                │
│      - Coal consumed based on efficiency (skill reward)        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Skill Expression** - Better players smelt faster and use less coal
2. **Active Engagement** - Can't just click and wait; requires attention
3. **Fair Difficulty** - Forgiving for beginners, rewarding for experts
4. **Progression Friendly** - Difficulty scales with ore tier

---

## Detailed Requirements

### FR-1: Furnace Block Interaction

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Right-clicking a placed Furnace opens FurnaceUI | P0 |
| FR-1.2 | Player must be within 6 studs of furnace to interact | P0 |
| FR-1.3 | Only one player can use a furnace at a time (in multiplayer realms) | P1 |
| FR-1.4 | Furnace interaction blocked if player inventory is full | P0 |

### FR-2: Recipe Selection

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Display only recipes with `requiresFurnace = true` | P0 |
| FR-2.2 | Show recipe ingredients with current inventory counts | P0 |
| FR-2.3 | Gray out recipes player cannot craft (missing materials) | P0 |
| FR-2.4 | Highlight craftable recipes with ingredient availability | P0 |

### FR-3: Smelting Mini-Game

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Temperature gauge with moving indicator | P0 |
| FR-3.2 | Hold input (click/touch) to increase heat | P0 |
| FR-3.3 | Release input to decrease heat (cooling) | P0 |
| FR-3.4 | Optimal zone highlighted on gauge | P0 |
| FR-3.5 | Optimal zone drifts left/right over time | P0 |
| FR-3.6 | Progress bar fills while indicator is in zone | P0 |
| FR-3.7 | Progress slows (not stops) when outside zone | P0 |
| FR-3.8 | Smelt completes when progress reaches 100% | P0 |

### FR-4: Fuel Efficiency

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Track "time in zone" percentage during smelt | P0 |
| FR-4.2 | Calculate efficiency multiplier based on performance | P0 |
| FR-4.3 | Apply multiplier to base coal cost | P0 |
| FR-4.4 | Display efficiency rating at smelt completion | P1 |
| FR-4.5 | Fractional coal rounds up (always costs at least 1) | P0 |

### FR-5: Completion & Rewards

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Output item added directly to player inventory | P0 |
| FR-5.2 | Input materials consumed on smelt START | P0 |
| FR-5.3 | Coal consumed on smelt COMPLETION (based on efficiency) | P0 |
| FR-5.4 | If inventory full, drop item at player feet | P1 |
| FR-5.5 | Show success message with efficiency stats | P1 |

---

## Mini-Game Specification

### Temperature Gauge Layout

```
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│   TEMPERATURE                                                │
│   ┌────────────────────────────────────────────────────┐    │
│   │ ░░░░░░░░░░░░░████████████░░░░░░░░░░░░░░░░░░░░░░░░░ │    │
│   │              ↑ OPTIMAL ZONE ↑                      │    │
│   │                    ▲                               │    │
│   │              (Your Heat)                           │    │
│   └────────────────────────────────────────────────────┘    │
│     COLD ←──────────────────────────────────────→ HOT       │
│                                                              │
│   Zone is drifting: →                                       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Input Mechanics

| Input | Desktop | Mobile |
|-------|---------|--------|
| Heat Up | Hold Left Mouse Button | Hold Touch |
| Cool Down | Release | Release |
| Cancel | Press ESC or click X | Tap X button |

### Temperature Physics

```lua
-- Configuration constants
local HEAT_RATE = 0.8        -- Units per second when holding
local COOL_RATE = 0.5        -- Units per second when released
local GAUGE_MIN = 0          -- Left edge (cold)
local GAUGE_MAX = 100        -- Right edge (hot)
local INDICATOR_START = 30   -- Starting position (cool side)

-- Per-frame update
if isHolding then
    indicator = indicator + (HEAT_RATE * deltaTime)
else
    indicator = indicator - (COOL_RATE * deltaTime)
end
indicator = math.clamp(indicator, GAUGE_MIN, GAUGE_MAX)
```

### Optimal Zone Behavior

```lua
-- Zone configuration (varies by ore tier)
local ZONE_WIDTH = 20        -- Width of optimal zone (in gauge units)
local ZONE_DRIFT_SPEED = 3   -- Units per second
local ZONE_DRIFT_RANGE = {min = 25, max = 75}  -- Zone stays within this range

-- Zone drifts back and forth
zoneCenter = zoneCenter + (driftDirection * ZONE_DRIFT_SPEED * deltaTime)
if zoneCenter >= ZONE_DRIFT_RANGE.max or zoneCenter <= ZONE_DRIFT_RANGE.min then
    driftDirection = -driftDirection  -- Reverse direction
end
```

### Difficulty Scaling by Ore Tier

| Ore Tier | Zone Width | Drift Speed | Smelt Time | Notes |
|----------|------------|-------------|------------|-------|
| Copper (T1) | 25 | 2 | 4s | Very forgiving, tutorial-friendly |
| Iron (T2) | 22 | 2.5 | 5s | Slightly tighter |
| Steel (T3) | 20 | 3 | 6s | Noticeable drift |
| Bluesteel (T4) | 18 | 3.5 | 7s | Requires focus |
| Tungsten (T5) | 15 | 4 | 8s | Challenging |
| Titanium (T6) | 12 | 5 | 10s | Expert level |

### Progress Calculation

```lua
-- Progress rate based on zone position
local function getProgressRate(indicator, zoneCenter, zoneWidth)
    local zoneMin = zoneCenter - (zoneWidth / 2)
    local zoneMax = zoneCenter + (zoneWidth / 2)

    if indicator >= zoneMin and indicator <= zoneMax then
        -- In optimal zone: full speed
        return 1.0
    else
        -- Outside zone: reduced speed (not zero - prevents frustration)
        local distance = 0
        if indicator < zoneMin then
            distance = zoneMin - indicator
        else
            distance = indicator - zoneMax
        end
        -- Falloff: 50% speed at edge, down to 10% at extremes
        return math.max(0.1, 0.5 - (distance / 100))
    end
end

-- Per-frame progress update
local rate = getProgressRate(indicator, zoneCenter, zoneWidth)
progress = progress + (rate * (100 / smeltTime) * deltaTime)
timeInZone = timeInZone + (rate == 1.0 and deltaTime or 0)
totalTime = totalTime + deltaTime
```

---

## Fuel Efficiency System

### Efficiency Calculation

```lua
-- Calculate efficiency at smelt completion
local function calculateEfficiency(timeInZone, totalTime)
    local zonePercentage = (timeInZone / totalTime) * 100

    -- Efficiency tiers
    if zonePercentage >= 90 then
        return { multiplier = 0.7, rating = "Perfect", color = Color3.fromRGB(100, 255, 100) }
    elseif zonePercentage >= 75 then
        return { multiplier = 0.85, rating = "Great", color = Color3.fromRGB(180, 255, 100) }
    elseif zonePercentage >= 60 then
        return { multiplier = 1.0, rating = "Good", color = Color3.fromRGB(255, 255, 100) }
    elseif zonePercentage >= 40 then
        return { multiplier = 1.15, rating = "Fair", color = Color3.fromRGB(255, 180, 100) }
    else
        return { multiplier = 1.3, rating = "Poor", color = Color3.fromRGB(255, 100, 100) }
    end
end
```

### Efficiency Tiers

| Performance | Zone Time | Coal Multiplier | Example: Steel (2 coal base) |
|-------------|-----------|-----------------|------------------------------|
| 🌟 Perfect | 90%+ | 0.7x (30% savings) | 2 × 0.7 = 1.4 → **1 coal** |
| ✨ Great | 75-89% | 0.85x (15% savings) | 2 × 0.85 = 1.7 → **2 coal** |
| ✅ Good | 60-74% | 1.0x (normal) | 2 × 1.0 = 2 → **2 coal** |
| ⚠️ Fair | 40-59% | 1.15x (15% waste) | 2 × 1.15 = 2.3 → **3 coal** |
| ❌ Poor | <40% | 1.3x (30% waste) | 2 × 1.3 = 2.6 → **3 coal** |

### Coal Rounding Rules

```lua
-- Always round UP to prevent free smelting
local function calculateCoalCost(baseCoal, efficiencyMultiplier)
    local adjustedCost = baseCoal * efficiencyMultiplier
    return math.max(1, math.ceil(adjustedCost))  -- Minimum 1 coal
end
```

---

## UI/UX Design

### FurnaceUI Layout (Minimal Style)

```
┌─────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                      🔥 FURNACE                           ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║  SMELTING RECIPES                                         ║  │
│  ║  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐         ║  │
│  ║  │ Copper  │ │  Iron   │ │  Steel  │ │Bluesteel│         ║  │
│  ║  │  Ingot  │ │  Ingot  │ │  Ingot  │ │  Ingot  │         ║  │
│  ║  │  3/3 ✓  │ │  0/1 ✗  │ │  5/1 ✓  │ │  0/1 ✗  │         ║  │
│  ║  └─────────┘ └─────────┘ └─────────┘ └─────────┘         ║  │
│  ║                                                           ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║                                                           ║  │
│  ║  SELECTED: Copper Ingot                                   ║  │
│  ║  Requires: 1× Copper Ore + 1× Coal                        ║  │
│  ║                                                           ║  │
│  ║           [  START SMELTING  ]                            ║  │
│  ║                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                              [X]                                │
└─────────────────────────────────────────────────────────────────┘
```

### Mini-Game View (During Smelting)

```
┌─────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║              🔥 SMELTING: Copper Ingot                    ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║   TEMPERATURE                                             ║  │
│  ║   ┌─────────────────────────────────────────────────┐    ║  │
│  ║   │░░░░░░░░░░░░░░███████████░░░░░░░░░░░░░░░░░░░░░░░░│    ║  │
│  ║   │                  ▲                              │    ║  │
│  ║   └─────────────────────────────────────────────────┘    ║  │
│  ║   ❄️ COLD ←───────────────────────────────────→ HOT 🔥   ║  │
│  ║                                                           ║  │
│  ║   ══════════════════════════════════════════════════     ║  │
│  ║   PROGRESS: ████████████████████░░░░░░░░░░  67%          ║  │
│  ║   ══════════════════════════════════════════════════     ║  │
│  ║                                                           ║  │
│  ║   💡 Hold [CLICK] to heat • Release to cool              ║  │
│  ║                                                           ║  │
│  ║                     [ CANCEL ]                            ║  │
│  ║                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────┘
```

### Completion Screen

```
┌─────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                    ✨ SMELT COMPLETE!                     ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║                    [Copper Ingot Icon]                    ║  │
│  ║                      +1 Copper Ingot                      ║  │
│  ║                                                           ║  │
│  ║   ─────────────────────────────────────────────────────   ║  │
│  ║                                                           ║  │
│  ║   Efficiency: ✨ GREAT (82% in zone)                      ║  │
│  ║   Coal Used: 1 (saved 0 from skill!)                      ║  │
│  ║                                                           ║  │
│  ║   ─────────────────────────────────────────────────────   ║  │
│  ║                                                           ║  │
│  ║        [ SMELT ANOTHER ]     [ CLOSE ]                    ║  │
│  ║                                                           ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
└─────────────────────────────────────────────────────────────────┘
```

### UI States

| State | Display | User Actions |
|-------|---------|--------------|
| Recipe Selection | Grid of available recipes | Click recipe → select |
| Recipe Selected | Show ingredients, Start button | Click Start → begin mini-game |
| Smelting Active | Temperature gauge, progress bar | Hold to heat, release to cool |
| Smelt Complete | Success screen with stats | Smelt Another / Close |
| Cannot Craft | Grayed recipe card | None (tooltip shows missing items) |

---

## Technical Architecture

### New Files Required

```
src/
├── StarterPlayerScripts/Client/
│   └── UI/
│       └── FurnaceUI.lua              # NEW: Furnace interface
│
├── ServerScriptService/Server/
│   └── Services/
│       └── SmeltingService.lua        # NEW: Server-side smelting logic
│
└── ReplicatedStorage/
    └── Shared/
        └── SmeltingConfig.lua         # NEW: Mini-game configuration
```

### Modified Files

```
src/
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── BlockInteraction.lua       # ADD: Furnace click handler
│
├── StarterPlayerScripts/Client/
│   └── UI/
│       └── CraftingPanel.lua          # ADD: Filter for requiresFurnace
│
└── ReplicatedStorage/
    └── Shared/
        └── EventManager.lua           # ADD: Furnace events (if needed)
```

### Event Flow

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLIENT    │      │   SERVER    │      │   CLIENT    │
│BlockInteract│      │SmeltService │      │ FurnaceUI   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                    │                    │
       │ Right-click furnace                     │
       │────────────────────────────────────────>│
       │                    │                    │ Open FurnaceUI
       │                    │                    │
       │                    │<───────────────────│ RequestStartSmelt
       │                    │ (recipeId, pos)    │
       │                    │                    │
       │                    │ Validate:          │
       │                    │ - Player has items │
       │                    │ - Near furnace     │
       │                    │ - Recipe valid     │
       │                    │                    │
       │                    │───────────────────>│ SmeltStarted
       │                    │                    │ (smeltConfig)
       │                    │                    │
       │                    │                    │ [Mini-game runs
       │                    │                    │  client-side]
       │                    │                    │
       │                    │<───────────────────│ RequestCompleteSmelt
       │                    │ (efficiency%)      │
       │                    │                    │
       │                    │ Calculate coal     │
       │                    │ Give output item   │
       │                    │ Consume coal       │
       │                    │                    │
       │                    │───────────────────>│ SmeltCompleted
       │                    │ (result, stats)    │
       │                    │                    │
```

### Server Events

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestOpenFurnace` | Client → Server | `{x, y, z}` furnace position |
| `FurnaceOpened` | Server → Client | `{recipes: [...], canCraft: {...}}` |
| `RequestStartSmelt` | Client → Server | `{recipeId, furnacePos}` |
| `SmeltStarted` | Server → Client | `{smeltConfig}` or `{error}` |
| `RequestCompleteSmelt` | Client → Server | `{efficiencyPercent, furnacePos}` |
| `SmeltCompleted` | Server → Client | `{success, output, coalUsed, stats}` |
| `RequestCancelSmelt` | Client → Server | `{furnacePos}` |
| `SmeltCancelled` | Server → Client | `{refunded: boolean}` |

### SmeltingConfig.lua

```lua
--[[
    SmeltingConfig.lua
    Configuration for the smelting mini-game
]]

local SmeltingConfig = {}

-- Temperature gauge settings
SmeltingConfig.Gauge = {
    MIN = 0,
    MAX = 100,
    START_POSITION = 30,
    HEAT_RATE = 0.8,      -- Units per second when holding
    COOL_RATE = 0.5,      -- Units per second when released
}

-- Difficulty settings per ore tier
SmeltingConfig.Difficulty = {
    -- [oreTier] = {zoneWidth, driftSpeed, smeltTime}
    [1] = { zoneWidth = 25, driftSpeed = 2.0, smeltTime = 4 },   -- Copper
    [2] = { zoneWidth = 22, driftSpeed = 2.5, smeltTime = 5 },   -- Iron
    [3] = { zoneWidth = 20, driftSpeed = 3.0, smeltTime = 6 },   -- Steel
    [4] = { zoneWidth = 18, driftSpeed = 3.5, smeltTime = 7 },   -- Bluesteel
    [5] = { zoneWidth = 15, driftSpeed = 4.0, smeltTime = 8 },   -- Tungsten
    [6] = { zoneWidth = 12, driftSpeed = 5.0, smeltTime = 10 },  -- Titanium
}

-- Zone drift boundaries
SmeltingConfig.ZoneDrift = {
    MIN = 25,
    MAX = 75,
}

-- Efficiency tiers
SmeltingConfig.Efficiency = {
    { threshold = 90, multiplier = 0.70, rating = "Perfect", color = {100, 255, 100} },
    { threshold = 75, multiplier = 0.85, rating = "Great",   color = {180, 255, 100} },
    { threshold = 60, multiplier = 1.00, rating = "Good",    color = {255, 255, 100} },
    { threshold = 40, multiplier = 1.15, rating = "Fair",    color = {255, 180, 100} },
    { threshold = 0,  multiplier = 1.30, rating = "Poor",    color = {255, 100, 100} },
}

-- Progress rates
SmeltingConfig.Progress = {
    IN_ZONE_RATE = 1.0,       -- Full speed in optimal zone
    OUT_OF_ZONE_MIN = 0.1,    -- Minimum progress rate outside zone
    OUT_OF_ZONE_FALLOFF = 0.5 -- Starting rate at zone edge
}

-- Recipe to tier mapping
SmeltingConfig.RecipeTiers = {
    smelt_copper = 1,
    smelt_iron = 2,
    smelt_steel = 3,
    smelt_bluesteel = 4,
    smelt_tungsten = 5,
    smelt_titanium = 6,
}

return SmeltingConfig
```

---

## Implementation Plan

### Phase 1: Core Infrastructure (Day 1)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `SmeltingConfig.lua` | Create configuration module |
| 1.2 | `BlockInteraction.lua` | Add furnace click handler |
| 1.3 | `SmeltingService.lua` | Create server service skeleton |
| 1.4 | `EventManager` | Register furnace events |

### Phase 2: Server Logic (Day 2)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `SmeltingService.lua` | Implement `HandleOpenFurnace` |
| 2.2 | `SmeltingService.lua` | Implement `HandleStartSmelt` (validate, consume ore) |
| 2.3 | `SmeltingService.lua` | Implement `HandleCompleteSmelt` (efficiency calc, give output) |
| 2.4 | `SmeltingService.lua` | Implement `HandleCancelSmelt` (refund ore) |

### Phase 3: Client UI (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `FurnaceUI.lua` | Create base UI structure |
| 3.2 | `FurnaceUI.lua` | Recipe grid display |
| 3.3 | `FurnaceUI.lua` | Temperature gauge rendering |
| 3.4 | `FurnaceUI.lua` | Input handling (hold to heat) |

### Phase 4: Mini-Game Logic (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `FurnaceUI.lua` | Temperature indicator physics |
| 4.2 | `FurnaceUI.lua` | Optimal zone drift behavior |
| 4.3 | `FurnaceUI.lua` | Progress calculation |
| 4.4 | `FurnaceUI.lua` | Efficiency tracking |

### Phase 5: Polish & Integration (Day 4-5)

| Task | File | Description |
|------|------|-------------|
| 5.1 | `FurnaceUI.lua` | Completion screen |
| 5.2 | `FurnaceUI.lua` | Cancel handling |
| 5.3 | `TutorialConfig.lua` | Verify smelt_copper step works |
| 5.4 | Testing | End-to-end testing all tiers |

### Checklist

```
□ Phase 1: Core Infrastructure
  □ Create SmeltingConfig.lua
  □ Add furnace handler to BlockInteraction.lua
  □ Create SmeltingService.lua skeleton
  □ Register events in ServiceManager

□ Phase 2: Server Logic
  □ HandleOpenFurnace - validate position, return recipes
  □ HandleStartSmelt - validate materials, consume ore
  □ HandleCompleteSmelt - calculate efficiency, give output, consume coal
  □ HandleCancelSmelt - refund ore if cancelled mid-smelt

□ Phase 3: Client UI
  □ FurnaceUI base structure (panel, close button)
  □ Recipe grid with craftability indicators
  □ Selected recipe detail view
  □ Temperature gauge component
  □ Progress bar component

□ Phase 4: Mini-Game
  □ Temperature indicator movement (heat up / cool down)
  □ Optimal zone rendering and drift
  □ Progress rate calculation based on position
  □ Efficiency percentage tracking
  □ Timer and completion detection

□ Phase 5: Polish
  □ Success screen with stats
  □ "Smelt Another" flow
  □ Cancel mid-smelt with ore refund
  □ Tutorial step verification
  □ All 6 ore tiers tested
```

---

## Future Enhancements

### v1.1: Visual Polish
- [ ] Lit furnace texture when smelting
- [ ] Fire particle effects
- [ ] Crackling sound effects
- [ ] Sizzle sound on completion

### v1.2: Furnace Tiers
- [ ] Iron Furnace (faster, higher tier ores)
- [ ] Steel Furnace (even faster, all ores)
- [ ] Visual distinction between tiers

### v1.3: Advanced Features
- [ ] Batch smelting (smelt multiple at once)
- [ ] Furnace persistence (save contents between sessions)
- [ ] Auto-collect outputs after timer
- [ ] Mastery system (player gets better over time)

### v1.4: Multiplayer
- [ ] Lock furnace while in use
- [ ] Visual indicator when furnace is occupied
- [ ] Shared furnaces in friend realms

---

## Appendix A: Recipe Reference

| Recipe ID | Output | Inputs | Base Coal | Tier |
|-----------|--------|--------|-----------|------|
| smelt_copper | Copper Ingot (105) | 1× Copper Ore (98) + 1× Coal | 1 | 1 |
| smelt_iron | Iron Ingot (33) | 1× Iron Ore (30) + 1× Coal | 1 | 2 |
| smelt_steel | Steel Ingot (108) | 1× Iron Ore (30) + 2× Coal | 2 | 3 |
| smelt_bluesteel | Bluesteel Ingot (109) | 1× Iron Ore (30) + 3× Coal + 1× Bluesteel Dust (115) | 3 | 4 |
| smelt_tungsten | Tungsten Ingot (110) | 1× Tungsten Ore (102) + 4× Coal | 4 | 5 |
| smelt_titanium | Titanium Ingot (111) | 1× Titanium Ore (103) + 5× Coal | 5 | 6 |

---

## Appendix B: Efficiency Examples

### Example 1: Perfect Copper Smelt
```
Player stays in zone 95% of time
Efficiency: Perfect (0.7x multiplier)
Base coal: 1
Calculated: 1 × 0.7 = 0.7 → ceil(0.7) = 1 coal
Result: Still costs 1 (minimum), but satisfaction!
```

### Example 2: Poor Steel Smelt
```
Player stays in zone only 35% of time
Efficiency: Poor (1.3x multiplier)
Base coal: 2
Calculated: 2 × 1.3 = 2.6 → ceil(2.6) = 3 coal
Result: Costs 3 coal instead of 2 (50% waste!)
```

### Example 3: Great Tungsten Smelt
```
Player stays in zone 80% of time
Efficiency: Great (0.85x multiplier)
Base coal: 4
Calculated: 4 × 0.85 = 3.4 → ceil(3.4) = 4 coal
Result: Still costs 4 (no savings at this tier, but close!)
```

---

*Document Version: 1.0*
*Created: January 2026*
*Author: AI Assistant*
*Related: [PROGRESSION_DESIGN.md](./PROGRESSION_DESIGN.md), [GAME_IDENTITY.md](./GAME_IDENTITY.md)*


