# Product Requirements Document: Farming System
## Skyblox - Crop Growth & Farming Mechanics

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Food Production)
> **Estimated Effort**: Large (6-7 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Farming System enables players to grow crops (wheat, potatoes, carrots, beetroot) on farmland. This PRD defines farmland creation, seed planting, crop growth stages, harvesting mechanics, and integration with the food system. Farming is essential for sustainable food production and progression.

### Why This Matters
- **Food Production**: Primary source of renewable food
- **Progression**: Unlocks sustainable survival gameplay
- **Base Building**: Farms are core to player bases
- **Minecraft Parity**: Essential farming mechanics expected

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
| Farmland Block | `Constants.lua` → `BlockType.FARMLAND = 69` | ✅ Defined |
| Crop Blocks | `Constants.lua` → WHEAT_CROP_0-7, etc. | ✅ All stages defined |
| Seed Items | `Constants.lua` → WHEAT_SEEDS, BEETROOT_SEEDS | ✅ Defined |
| Crop Items | `Constants.lua` → WHEAT, POTATO, CARROT, BEETROOT | ✅ Defined |
| Compost Item | `Constants.lua` → `BlockType.COMPOST = 96` | ✅ Defined |
| Crop Textures | `BlockRegistry.lua` | ✅ Available (assumed) |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Farmland Creation | Converting dirt/grass to farmland | P0 |
| Seed Planting | Right-click farmland with seeds | P0 |
| Crop Growth System | Crops grow through stages over time | P0 |
| Growth Conditions | Light, water, farmland moisture | P0 |
| Crop Harvesting | Breaking crops drops items | P0 |
| Bone Meal | Speed up growth (optional) | P1 |
| Farmland Moisture | Water nearby keeps farmland hydrated | P0 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                      FARMING FLOW                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. Player uses Compost on Dirt/Grass → Farmland              │
│                    ↓                                            │
│   2. Player right-clicks Farmland with Seeds                    │
│      - Seeds consumed from inventory                            │
│      - Crop stage 0 planted                                     │
│                    ↓                                            │
│   3. Crop grows through stages over time                       │
│      - Growth requires: light, water nearby, farmland           │
│      - Each stage takes random time (Minecraft formula)         │
│                    ↓                                            │
│   4. Crop reaches final stage (fully grown)                     │
│                    ↓                                            │
│   5. Player breaks crop → Drops items                           │
│      - Wheat: 1-4 Wheat + 0-3 Seeds                             │
│      - Potato: 1-4 Potatoes                                     │
│      - Carrot: 1-4 Carrots                                     │
│      - Beetroot: 1-4 Beetroot + 0-3 Seeds                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Minecraft Parity** - Growth times and mechanics match Minecraft exactly
2. **Visual Feedback** - Clear crop stages and growth progress
3. **Sustainable Loop** - Crops drop seeds for replanting
4. **Environmental Factors** - Light and water affect growth

---

## Detailed Requirements

### FR-1: Farmland Creation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Right-click Dirt/Grass with Compost → Farmland | P0 |
| FR-1.2 | Compost consumed on use | P0 |
| FR-1.3 | Farmland has moisture level (0-7) | P0 |
| FR-1.4 | Water within 4 blocks hydrates farmland | P0 |
| FR-1.5 | Hydrated farmland has darker texture | P0 |
| FR-1.6 | Farmland reverts to Dirt if block above is solid | P0 |

### FR-2: Seed Planting

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Right-click Farmland with Seeds → Plant crop | P0 |
| FR-2.2 | Seeds consumed from inventory | P0 |
| FR-2.3 | Crop starts at stage 0 | P0 |
| FR-2.4 | Can only plant on Farmland | P0 |
| FR-2.5 | Cannot plant if block above is solid | P0 |
| FR-2.6 | Different seeds plant different crops | P0 |

### FR-3: Crop Growth

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Crops grow through defined stages | P0 |
| FR-3.2 | Growth requires light level >= 9 | P0 |
| FR-3.3 | Growth requires farmland (not dirt) | P0 |
| FR-3.4 | Growth time is random per stage | P0 |
| FR-3.5 | Hydrated farmland grows faster | P0 |
| FR-3.6 | Crops break if farmland reverts to dirt | P0 |

### FR-4: Crop Harvesting

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Breaking crop drops items | P0 |
| FR-4.2 | Fully grown crops drop more items | P0 |
| FR-4.3 | Crops drop seeds (for replanting) | P0 |
| FR-4.4 | Breaking crop stage 0-6 drops 0-1 seeds | P0 |
| FR-4.5 | Breaking fully grown crop drops 1-4 items + seeds | P0 |

### FR-5: Growth Conditions

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Light level check: block above must allow light | P0 |
| FR-5.2 | Water check: water within 4 blocks horizontally | P0 |
| FR-5.3 | Farmland check: must be on farmland block | P0 |
| FR-5.4 | Growth stops if conditions not met | P0 |
| FR-5.5 | Growth resumes when conditions met | P0 |

---

## Minecraft Behavior Reference

### Crop Growth Stages

**Wheat:**
- 8 stages (0-7), stage 7 is fully grown
- Growth time: 1-3 minutes per stage (random)
- Total time: ~8-24 minutes

**Potato:**
- 4 stages (0-3), stage 3 is fully grown
- Growth time: 1-3 minutes per stage
- Total time: ~4-12 minutes

**Carrot:**
- 4 stages (0-3), stage 3 is fully grown
- Growth time: 1-3 minutes per stage
- Total time: ~4-12 minutes

**Beetroot:**
- 4 stages (0-3), stage 3 is fully grown
- Growth time: 1-3 minutes per stage
- Total time: ~4-12 minutes

### Growth Conditions

- **Light**: Block above must allow light (light level >= 9 at crop)
- **Water**: Water within 4 blocks horizontally hydrates farmland
- **Farmland**: Crop must be on farmland (not dirt)
- **Space**: Block above must be air (crops are cross-shaped)

### Drop Rates

**Wheat (fully grown):**
- 1-4 Wheat (average 2.67)
- 0-3 Seeds (average 1.24)
- Fortune increases drops

**Potato (fully grown):**
- 1-4 Potatoes (average 2.67)
- Small chance for Poisonous Potato

**Carrot (fully grown):**
- 1-4 Carrots (average 2.67)

**Beetroot (fully grown):**
- 1-4 Beetroot (average 2.67)
- 0-3 Seeds (average 1.24)

### Farmland Mechanics

- **Creation**: Hoe on dirt/grass (we use Compost)
- **Moisture**: 0-7 levels, water within 4 blocks = 7
- **Hydration**: Hydrated farmland grows crops 2x faster
- **Breaking**: Farmland reverts to dirt if block above is solid

---

## Technical Specifications

### Crop Growth Configuration

```lua
-- FarmingConfig.lua
local FarmingConfig = {}

FarmingConfig.Crops = {
    [Constants.BlockType.WHEAT_CROP_0] = {
        cropType = "wheat",
        stage = 0,
        nextStage = Constants.BlockType.WHEAT_CROP_1,
        finalStage = Constants.BlockType.WHEAT_CROP_7,
        stages = 8,
        seedItem = Constants.BlockType.WHEAT_SEEDS,
        dropItem = Constants.BlockType.WHEAT,
        growthTimeMin = 60,  -- seconds
        growthTimeMax = 180, -- seconds
        drops = {
            minItems = 1,
            maxItems = 4,
            minSeeds = 0,
            maxSeeds = 3
        }
    },
    -- Add potato, carrot, beetroot...
}

FarmingConfig.Farmland = {
    moistureLevels = 8,  -- 0-7
    waterRange = 4,      -- blocks
    hydrationBonus = 2.0 -- 2x faster growth
}

FarmingConfig.GrowthConditions = {
    minLightLevel = 9,
    requiresFarmland = true,
    requiresAirAbove = true
}

return FarmingConfig
```

### Growth System

```lua
-- FarmingService.lua
local FarmingService = {}

function FarmingService:PlantCrop(player, farmlandPos, seedId)
    -- Validate
    if not self:CanPlantCrop(farmlandPos, seedId) then
        return false, "Cannot plant here"
    end

    -- Get crop config
    local cropConfig = FarmingConfig:GetCropBySeed(seedId)
    if not cropConfig then
        return false, "Invalid seed"
    end

    -- Consume seed
    player:RemoveItem(seedId, 1)

    -- Place crop stage 0
    local worldManager = self:GetWorldManager(player)
    worldManager:SetBlock(
        farmlandPos.X,
        farmlandPos.Y + 1,
        farmlandPos.Z,
        cropConfig.initialStage
    )

    -- Start growth timer
    self:StartCropGrowth(farmlandPos + Vector3.new(0, 1, 0), cropConfig)

    return true
end

function FarmingService:StartCropGrowth(cropPos, cropConfig)
    -- Calculate growth time
    local growthTime = math.random(cropConfig.growthTimeMin, cropConfig.growthTimeMax)

    -- Check if farmland is hydrated (2x faster)
    if self:IsFarmlandHydrated(cropPos - Vector3.new(0, 1, 0)) then
        growthTime = growthTime / FarmingConfig.Farmland.hydrationBonus
    end

    -- Schedule growth
    task.delay(growthTime, function()
        self:GrowCrop(cropPos, cropConfig)
    end)
end

function FarmingService:GrowCrop(cropPos, cropConfig)
    -- Check conditions
    if not self:CanGrow(cropPos, cropConfig) then
        -- Retry later
        self:StartCropGrowth(cropPos, cropConfig)
        return
    end

    -- Get current stage
    local currentBlock = self:GetBlockAt(cropPos)
    local currentStage = cropConfig:GetStage(currentBlock)

    -- Grow to next stage
    if currentStage < cropConfig.stages - 1 then
        local nextStage = cropConfig:GetStageBlock(currentStage + 1)
        self:SetBlockAt(cropPos, nextStage)

        -- Schedule next growth
        self:StartCropGrowth(cropPos, cropConfig)
    end
end
```

---

## UI/UX Design

### Farmland Visual States

- **Dry Farmland**: Light brown texture
- **Hydrated Farmland**: Dark brown texture (water nearby)
- **Crop Stages**: Visual progression through stages

### Crop Growth Indicator

Optional: Show growth progress bar above crop
- Progress bar fills as crop grows
- Color: Green when conditions met, Red when blocked

---

## Technical Architecture

### New Files Required

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── FarmingService.lua          # NEW: Farming logic
│
└── ReplicatedStorage/
    └── Shared/
        └── FarmingConfig.lua            # NEW: Crop configurations
```

### Modified Files

```
src/
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── BlockInteraction.lua        # ADD: Compost use, seed planting
│
└── ServerScriptService/Server/
    └── Services/
        └── VoxelWorldService.lua       # MODIFY: Handle crop breaking
```

---

## Implementation Plan

### Phase 1: Farmland System (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `FarmingConfig.lua` | Create farming configuration |
| 1.2 | `BlockInteraction.lua` | Add compost use handler |
| 1.3 | `FarmingService.lua` | Implement farmland creation |
| 1.4 | `FarmingService.lua` | Implement farmland moisture system |
| 1.5 | `FarmingService.lua` | Implement farmland hydration check |

### Phase 2: Seed Planting (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `FarmingConfig.lua` | Define all crop types and stages |
| 2.2 | `BlockInteraction.lua` | Add seed planting handler |
| 2.3 | `FarmingService.lua` | Implement seed planting logic |
| 2.4 | `FarmingService.lua` | Validate planting conditions |

### Phase 3: Crop Growth (Day 3-5)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `FarmingService.lua` | Implement growth timer system |
| 3.2 | `FarmingService.lua` | Implement growth stage progression |
| 3.3 | `FarmingService.lua` | Check growth conditions (light, water) |
| 3.4 | `FarmingService.lua` | Handle growth interruptions |
| 3.5 | `FarmingService.lua` | Optimize growth updates (batch processing) |

### Phase 4: Harvesting (Day 5-6)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `FarmingService.lua` | Implement crop breaking logic |
| 4.2 | `FarmingService.lua` | Calculate drop amounts |
| 4.3 | `FarmingService.lua` | Drop items to player inventory |
| 4.4 | `VoxelWorldService.lua` | Integrate crop breaking |

### Phase 5: Polish & Testing (Day 6-7)

| Task | File | Description |
|------|------|-------------|
| 5.1 | Testing | Test all crop types |
| 5.2 | Testing | Test growth conditions |
| 5.3 | Testing | Test harvesting drops |
| 5.4 | Testing | Test farmland hydration |

---

## Future Enhancements

### v1.1: Advanced Farming
- [ ] Bone meal (speed up growth)
- [ ] Crop trampling (mobs break crops)
- [ ] Crop bonemeal interaction
- [ ] More crops (pumpkin, melon, etc.)

### v1.2: Farming Tools
- [ ] Hoe (for creating farmland)
- [ ] Watering can (hydrate farmland)
- [ ] Fertilizer system

### v1.3: Advanced Crops
- [ ] Nether crops
- [ ] Tree farming
- [ ] Animal farming integration

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_FOOD_CONSUMABLES.md](./PRD_FOOD_CONSUMABLES.md)*
