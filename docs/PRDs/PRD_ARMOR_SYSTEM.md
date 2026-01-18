# Product Requirements Document: Armor System
## Skyblox - Defense, Durability & Protection

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Combat Survival)
> **Estimated Effort**: Medium (4-5 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Armor System provides damage reduction through equipped armor pieces (helmet, chestplate, leggings, boots). This PRD defines armor equipping, defense calculations, durability mechanics, visual representation, and integration with the combat system. Armor is essential for surviving combat and exploring dangerous areas.

### Why This Matters
- **Combat Survival**: Reduces damage from mobs and players
- **Progression**: Better armor enables harder content
- **Visual Identity**: Armor appearance shows player progression
- **Minecraft Parity**: Core survival mechanic

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Armor Definitions | `ItemDefinitions.lua` → Armor section | ✅ All armor defined |
| Armor Tiers | `ItemDefinitions.lua` → 6 tiers | ✅ Defined |
| Armor Defense Values | `ItemDefinitions.lua` → ArmorDefense table | ✅ Defined |
| Armor Textures | `ItemDefinitions.lua` | ✅ All textures available |
| Armor Slots | `ItemDefinitions.lua` | ✅ helmet, chestplate, leggings, boots |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Armor Equipping System | Wearing armor pieces | P0 |
| Defense Calculation | Damage reduction formula | P0 |
| Armor Durability | Armor wears with damage | P0 |
| Visual Armor Models | Show armor on player character | P0 |
| Armor UI | Equip/unequip interface | P0 |
| Armor Set Bonuses | Optional tier bonuses | P1 |

---

## Detailed Requirements

### FR-1: Armor Equipping

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Drag armor to armor slot to equip | P0 |
| FR-1.2 | Only one piece per slot (helmet, chestplate, etc.) | P0 |
| FR-1.3 | Equipped armor removed from inventory | P0 |
| FR-1.4 | Unequipping returns armor to inventory | P0 |
| FR-1.5 | Armor slots visible in inventory UI | P0 |

### FR-2: Defense Calculation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Defense = sum of all equipped armor pieces | P0 |
| FR-2.2 | Damage reduction = defense / (defense + 20) | P0 |
| FR-2.3 | Toughness reduces damage from high-damage attacks | P0 |
| FR-2.4 | Final damage = incoming * (1 - reduction) | P0 |

### FR-3: Armor Durability

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Armor durability decreases when taking damage | P0 |
| FR-3.2 | Durability loss = damage taken / 4 | P0 |
| FR-3.3 | Armor breaks when durability reaches 0 | P0 |
| FR-3.4 | Broken armor removed from slot | P0 |
| FR-3.5 | Durability displayed in armor tooltip | P0 |

### FR-4: Visual Representation

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Armor models attach to player character | P0 |
| FR-4.2 | Armor color matches tier color | P0 |
| FR-4.3 | Armor visible to all players | P0 |
| FR-4.4 | Armor updates when equipped/unequipped | P0 |

---

## Minecraft Behavior Reference

### Defense Values (Per Tier)

| Tier | Helmet | Chestplate | Leggings | Boots | Total | Toughness |
|------|--------|------------|----------|------|-------|-----------|
| Leather | 1 | 3 | 2 | 1 | 7 | 0 |
| Copper (T1) | 1 | 2 | 2 | 1 | 6 | 0 |
| Iron (T2) | 2 | 4 | 3 | 1 | 10 | 0 |
| Steel (T3) | 2 | 5 | 4 | 2 | 13 | 0 |
| Bluesteel (T4) | 3 | 6 | 5 | 2 | 16 | 1 |
| Tungsten (T5) | 4 | 7 | 6 | 3 | 20 | 2 |
| Titanium (T6) | 5 | 8 | 7 | 4 | 24 | 3 |

### Damage Reduction Formula

```
damageReduction = defense / (defense + 20)
finalDamage = incomingDamage * (1 - damageReduction)
```

**Example**: 10 defense = 10/(10+20) = 33% reduction

### Durability

- Durability decreases by 1 per point of damage taken (divided by 4)
- Each armor piece has different max durability
- Armor breaks at 0 durability

---

## Technical Specifications

### Armor Service

```lua
-- ArmorService.lua
local ArmorService = {}

function ArmorService:EquipArmor(player, armorId, slot)
    -- Validate
    local armorDef = ItemDefinitions.Armor[armorId]
    if not armorDef or armorDef.slot ~= slot then
        return false, "Invalid armor for slot"
    end

    -- Unequip existing armor in slot
    local existing = player:GetEquippedArmor(slot)
    if existing then
        self:UnequipArmor(player, slot)
    end

    -- Equip new armor
    player:SetEquippedArmor(slot, armorId)
    player:RemoveItem(armorId, 1)

    -- Update visuals
    self:UpdateArmorVisuals(player)

    -- Recalculate defense
    self:UpdateDefense(player)

    return true
end

function ArmorService:CalculateDefense(player)
    local totalDefense = 0
    local totalToughness = 0

    for _, slot in ipairs({"helmet", "chestplate", "leggings", "boots"}) do
        local armorId = player:GetEquippedArmor(slot)
        if armorId then
            local armorDef = ItemDefinitions.Armor[armorId]
            if armorDef then
                totalDefense = totalDefense + (armorDef.defense or 0)
                totalToughness = totalToughness + (armorDef.toughness or 0)
            end
        end
    end

    return totalDefense, totalToughness
end

function ArmorService:CalculateDamageReduction(defense, toughness, incomingDamage)
    -- Base reduction
    local reduction = defense / (defense + 20)

    -- Toughness reduces high-damage attacks
    if toughness > 0 and incomingDamage > 1 then
        local toughnessReduction = math.min(toughness / 4, 0.2)
        reduction = reduction + toughnessReduction
    end

    return math.min(reduction, 0.8)  -- Max 80% reduction
end

return ArmorService
```

---

## Implementation Plan

### Phase 1: Equipping System (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `ArmorService.lua` | Create armor service |
| 1.2 | `ArmorService.lua` | Implement equip/unequip logic |
| 1.3 | `PlayerInventoryService.lua` | Add armor slot storage |
| 1.4 | `InventoryUI.lua` | Add armor slot UI |

### Phase 2: Defense Calculation (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `ArmorService.lua` | Implement defense calculation |
| 2.2 | `DamageService.lua` | Integrate armor damage reduction |
| 2.3 | `CombatService.lua` | Apply armor in combat |

### Phase 3: Durability (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `ArmorService.lua` | Implement durability system |
| 3.2 | `ArmorService.lua` | Decrease durability on damage |
| 3.3 | `ArmorService.lua` | Handle armor breaking |

### Phase 4: Visuals (Day 4-5)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `ArmorService.lua` | Create armor model attachment |
| 4.2 | `ArmorService.lua` | Apply tier colors |
| 4.3 | `PlayerReplicationService.lua` | Sync armor visuals |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_TOOLS_SYSTEM.md](./PRD_TOOLS_SYSTEM.md)*
