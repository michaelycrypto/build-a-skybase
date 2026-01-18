# Product Requirements Document: Bow & Arrow System
## Skyblox - Ranged Combat Mechanics

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Ranged Combat)
> **Estimated Effort**: Medium (4-5 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Bow & Arrow System enables ranged combat through bow charging and arrow projectiles. This PRD defines bow mechanics, arrow physics, damage calculation, and integration with the combat system. Bows are essential for safe ranged combat and hunting.

### Why This Matters
- **Ranged Combat**: Safe way to fight mobs from distance
- **Hunting**: Essential for hunting passive mobs
- **Combat Variety**: Adds strategic depth to combat
- **Minecraft Parity**: Core combat feature

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Bow Item | `ItemDefinitions.lua` → BOW (id: 1051) | ✅ Defined |
| Arrow Item | `ItemDefinitions.lua` → ARROW (id: 2001) | ✅ Defined |
| Bow Texture | `ItemDefinitions.lua` | ✅ Available |
| Arrow Texture | `ItemDefinitions.lua` | ✅ Available |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Bow Charging | Hold to charge, release to shoot | P0 |
| Arrow Projectile | Physics-based arrow flight | P0 |
| Arrow Damage | Damage based on charge level | P0 |
| Arrow Pickup | Arrows can be retrieved | P0 |
| Bow Durability | Bow wears with use | P0 |
| Arrow Inventory | Consume arrows when shooting | P0 |

---

## Detailed Requirements

### FR-1: Bow Charging

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Hold right-click to charge bow | P0 |
| FR-1.2 | Charge time: 1 second to full charge | P0 |
| FR-1.3 | Charge level: 0-1 (0 to 1.0) | P0 |
| FR-1.4 | Visual charge indicator (bow animation) | P0 |
| FR-1.5 | Release to shoot arrow | P0 |
| FR-1.6 | Cannot charge without arrows | P0 |

### FR-2: Arrow Projectile

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Arrow spawns at player position | P0 |
| FR-2.2 | Arrow velocity based on charge level | P0 |
| FR-2.3 | Arrow follows physics (gravity, trajectory) | P0 |
| FR-2.4 | Arrow damages on hit (mob or player) | P0 |
| FR-2.5 | Arrow sticks in blocks | P0 |
| FR-2.6 | Arrow despawns after 60 seconds | P0 |

### FR-3: Arrow Damage

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Base damage: 2-5 (random) | P0 |
| FR-3.2 | Charge multiplier: 0.2x to 1.0x | P0 |
| FR-3.3 | Critical hit: 1.5x damage (random 25% chance) | P0 |
| FR-3.4 | Final damage = base * charge * (1.5 if crit) | P0 |

### FR-4: Arrow Management

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Consume 1 arrow per shot | P0 |
| FR-4.2 | Arrows stack to 64 | P0 |
| FR-4.3 | Arrows can be picked up from ground | P0 |
| FR-4.4 | Arrows in blocks can be retrieved | P1 |

---

## Technical Specifications

### Bow Service

```lua
-- BowService.lua
local BowService = {}

function BowService:StartCharging(player)
    -- Check has arrows
    if not player:HasItem(Constants.BlockType.ARROW, 1) then
        return false, "No arrows"
    end

    -- Start charge
    player.bowCharging = true
    player.bowChargeStart = os.clock()

    -- Play animation
    player:PlayBowChargeAnimation()

    return true
end

function BowService:UpdateCharge(player)
    if not player.bowCharging then
        return
    end

    local elapsed = os.clock() - player.bowChargeStart
    local chargeLevel = math.min(1.0, elapsed / 1.0)  -- 1 second to full

    player.bowChargeLevel = chargeLevel

    -- Update animation
    player:UpdateBowChargeAnimation(chargeLevel)
end

function BowService:ShootArrow(player)
    if not player.bowCharging then
        return false
    end

    local chargeLevel = player.bowChargeLevel or 0

    -- Consume arrow
    player:RemoveItem(Constants.BlockType.ARROW, 1)

    -- Calculate velocity
    local baseVelocity = 50  -- studs/second
    local velocity = baseVelocity * (0.2 + chargeLevel * 0.8)

    -- Spawn arrow
    local arrow = self:SpawnArrow(player, velocity, chargeLevel)

    -- Reset charge
    player.bowCharging = false
    player.bowChargeLevel = 0

    -- Decrease bow durability
    self:DecreaseBowDurability(player, 1)

    return true, arrow
end

function BowService:CalculateDamage(chargeLevel, isCritical)
    local baseDamage = math.random(2, 5)
    local chargeMultiplier = 0.2 + (chargeLevel * 0.8)
    local critMultiplier = isCritical and 1.5 or 1.0

    return baseDamage * chargeMultiplier * critMultiplier
end

return BowService
```

---

## Implementation Plan

### Phase 1: Bow Charging (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `BowService.lua` | Create bow service |
| 1.2 | `BowService.lua` | Implement charge system |
| 1.3 | `PlayerController.lua` | Handle right-click hold |
| 1.4 | `PlayerController.lua` | Handle right-click release |

### Phase 2: Arrow Projectile (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `ArrowService.lua` | Create arrow projectile |
| 2.2 | `ArrowService.lua` | Implement physics |
| 2.3 | `ArrowService.lua` | Implement hit detection |
| 2.4 | `ArrowService.lua` | Implement damage application |

### Phase 3: Integration (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `CombatService.lua` | Integrate arrow damage |
| 3.2 | `BowService.lua` | Implement arrow consumption |
| 3.3 | `BowService.lua` | Implement bow durability |

### Phase 4: Polish (Day 4-5)

| Task | File | Description |
|------|------|-------------|
| 4.1 | Testing | Test all charge levels |
| 4.2 | Testing | Test arrow physics |
| 4.3 | Testing | Test damage calculation |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_TOOLS_SYSTEM.md](./PRD_TOOLS_SYSTEM.md)*
