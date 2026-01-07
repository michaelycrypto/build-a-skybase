# Armor & Health System Integration Plan

## Research Summary

### Current State Analysis

#### 1. Combat System
| Location | Function | Armor Integration |
|----------|----------|-------------------|
| `VoxelWorldService.lua:134-242` | `HandlePlayerMeleeHit` (PvP) | ❌ None - calls `victimHum:TakeDamage(dmg)` directly |
| `MobEntityService.lua:2597-2657` | `DamageMob` (PvE) | ❌ None - `mob.health -= amount` directly |
| `BowService.lua:263-293` | Arrow hits | ❌ None - calls `humanoid:TakeDamage(damage)` directly |

**Key Finding**: All damage calculations completely bypass the existing armor system.

#### 2. Armor System (EXISTS but UNUSED)
```
ArmorEquipService.lua
├── equippedArmor[player] = {helmet, chestplate, leggings, boots}
├── GetPlayerDefense(player) → (defense, toughness)  ✅ EXISTS
└── CalculateTotalDefense(equipped) → (defense, toughness)  ✅ EXISTS

ArmorConfig.lua
├── TierDefense[tier][slot] = defense value  ✅ EXISTS
├── TierToughness[tier] = toughness value  ✅ EXISTS
└── CalculateDamageReduction(damage, defense, toughness)  ✅ EXISTS but NEVER CALLED
```

**Minecraft Formula (Already Implemented)**:
```lua
defensePoints = min(20, max(defense/5, defense - 4*damage/(toughness+8)))
reduction = defensePoints / 25
finalDamage = damage * (1 - reduction)
```

#### 3. Health System
- **Current**: Uses Roblox's built-in `Humanoid.Health` (default 100 HP)
- **Minecraft**: 20 HP (10 hearts, displayed as half-heart increments)
- **No custom health state** - just raw Humanoid property

#### 4. UI/HUD System
| Component | File | Status |
|-----------|------|--------|
| Crosshair | `Crosshair.lua` | ✅ Exists (Minecraft-style) |
| Hotbar | `VoxelHotbar.lua` | ✅ Exists (9-slot, bottom center) |
| Currency | `MainHUD.lua` | ✅ Exists (coins/gems) |
| **Health Bar** | - | ❌ **NOT IMPLEMENTED** |
| **Armor Bar** | - | ❌ **NOT IMPLEMENTED** |
| **Hunger Bar** | - | ❌ **NOT IMPLEMENTED** |

---

## Implementation Plan

### Phase 1: Server-Side Armor Integration (CRITICAL)

#### 1.1 Create Damage Pipeline Service
**New File**: `src/ServerScriptService/Server/Services/DamageService.lua`

```lua
-- Centralized damage calculation with armor reduction
DamageService:ApplyDamage(victim: Player|Model, amount: number, damageType: string, attacker: Player?)
    1. Get victim's armor defense (if player)
    2. Apply armor reduction using ArmorConfig.CalculateDamageReduction()
    3. Apply damage to Humanoid
    4. Fire events for UI updates
```

#### 1.2 Modify Existing Combat Code
**Files to modify**:
- `VoxelWorldService.lua` - Replace `victimHum:TakeDamage(dmg)` with `DamageService:ApplyDamage()`
- `BowService.lua` - Same replacement
- `MobEntityService.lua` - Add armor support for player-to-mob (mobs don't have armor)

#### 1.3 Events to Add
```lua
-- EventManifest.lua additions
"PlayerHealthChanged" = {health, maxHealth, playerId}
"PlayerArmorChanged" = {defense, toughness, playerId}
"PlayerDamageTaken" = {amount, reduced, finalDamage, damageType, attackerId?}
```

---

### Phase 2: Health & Armor UI

#### 2.1 Create StatusBarsHUD Component
**New File**: `src/StarterPlayerScripts/Client/UI/StatusBarsHUD.lua`

**Layout** (Minecraft-style, above hotbar):
```
┌─────────────────────────────────────────────┐
│  ♥♥♥♥♥♥♥♥♥♥  (Health - 10 hearts)          │
│  🛡🛡🛡🛡🛡🛡🛡🛡🛡🛡  (Armor - 10 icons)      │
│  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░      │
│  [1][2][3][4][5][6][7][8][9] (Hotbar)       │
└─────────────────────────────────────────────┘
```

**Components**:
- Health bar: 10 heart icons (full, half, empty states)
- Armor bar: 10 armor icons (shows protection level)
- Positioned directly above existing VoxelHotbar

#### 2.2 Health Display Options
| Style | Description | Recommendation |
|-------|-------------|----------------|
| Hearts | Minecraft-authentic, 10 hearts | ✅ Recommended |
| Bar + Number | Modern, shows exact HP | Alternative |
| Hybrid | Hearts with number tooltip | Best of both |

#### 2.3 Armor Display
- Calculate total defense from equipped items
- Display as filled armor icons (like Minecraft)
- Max 20 armor points = 10 full icons

---

### Phase 3: Integration & Polish

#### 3.1 Damage Feedback
- Red flash on character when hit (exists in combat code)
- Screen vignette effect at low health
- Damage numbers (optional floating text)

#### 3.2 Death & Respawn
- Death screen with respawn button
- Drop items on death (optional, Minecraft behavior)
- Respawn with full health

#### 3.3 Sound Effects
- Hurt sound on damage
- Low health heartbeat
- Armor equip/break sounds

---

## File Structure

### New Files
```
src/
├── ServerScriptService/Server/Services/
│   └── DamageService.lua          # Centralized damage with armor
├── StarterPlayerScripts/Client/UI/
│   └── StatusBarsHUD.lua          # Health & Armor bars
└── ReplicatedStorage/Configs/
    └── HealthConfig.lua           # Health/armor UI settings
```

### Modified Files
```
src/
├── ServerScriptService/Server/Services/
│   ├── VoxelWorldService.lua      # Use DamageService for PvP
│   └── BowService.lua             # Use DamageService for arrows
├── ReplicatedStorage/Shared/Events/
│   └── EventManifest.lua          # Add health/armor events
└── StarterPlayerScripts/Client/UI/
    └── VoxelHotbar.lua            # Adjust position for status bars
```

---

## Technical Details

### Health Scaling Decision
| Option | Player HP | Minecraft | Notes |
|--------|-----------|-----------|-------|
| A | 100 HP | 20 HP | Current Roblox default, multiply display |
| B | 20 HP | 20 HP | True Minecraft, change Humanoid.MaxHealth |

**Recommendation**: Option A - Keep 100 HP internally, display as 10 hearts (1 heart = 10 HP)

### Armor Points Calculation
```lua
-- From ArmorConfig.TierDefense
Leather:   Helmet=1, Chest=3, Legs=2, Boots=1  → Total = 7
Chainmail: Helmet=2, Chest=5, Legs=4, Boots=1  → Total = 12
Iron:      Helmet=2, Chest=6, Legs=5, Boots=2  → Total = 15
Golden:    Helmet=2, Chest=5, Legs=3, Boots=1  → Total = 11
Diamond:   Helmet=3, Chest=8, Legs=6, Boots=3  → Total = 20
```

### Damage Reduction Examples
| Incoming | Armor | Toughness | Reduction | Final |
|----------|-------|-----------|-----------|-------|
| 6 (sword) | 7 (leather) | 0 | 28% | 4.32 |
| 6 (sword) | 15 (iron) | 0 | 60% | 2.40 |
| 6 (sword) | 20 (diamond) | 2 | 80% | 1.20 |

---

## Implementation Order

### Priority 1 (Core)
1. ✅ Research complete
2. [ ] Create DamageService.lua
3. [ ] Integrate armor into PvP damage
4. [ ] Integrate armor into bow damage
5. [ ] Add health/armor events

### Priority 2 (UI)
6. [ ] Create StatusBarsHUD.lua (health bar)
7. [ ] Add armor bar to StatusBarsHUD
8. [ ] Position above hotbar
9. [ ] Connect to events

### Priority 3 (Polish)
10. [ ] Low health effects
11. [ ] Damage feedback improvements
12. [ ] Sound effects
13. [ ] Death screen (optional)

---

## Questions for User

1. **Health Display Style**: Hearts (Minecraft) or modern bar?
2. **Health Value**: Keep 100 HP or change to 20 HP?
3. **Hunger System**: Include hunger bar? (Affects regen)
4. **Death Behavior**: Drop items on death?
5. **Damage Numbers**: Show floating damage text?

---

## Existing Code References

### ArmorConfig.CalculateDamageReduction (Already Exists!)
```lua:464:481:src/ReplicatedStorage/Configs/ArmorConfig.lua
function ArmorConfig.CalculateDamageReduction(damage, defense, toughness)
    toughness = toughness or 0
    local defensePoints = math.min(20,
        math.max(defense / 5, defense - (4 * damage / (toughness + 8)))
    )
    local reduction = defensePoints / 25
    local finalDamage = damage * (1 - reduction)
    return math.max(0, finalDamage)
end
```

### ArmorEquipService.GetPlayerDefense (Already Exists!)
```lua:325:329:src/ServerScriptService/Server/Services/ArmorEquipService.lua
function ArmorEquipService:GetPlayerDefense(player: Player): (number, number)
    local equipped = self.equippedArmor[player] or {}
    return ArmorConfig.CalculateTotalDefense(equipped)
end
```

### Current PvP Damage (NO ARMOR - Needs Fix)
```lua:214:216:src/ServerScriptService/Server/Services/VoxelWorldService.lua
-- Compute damage using unified config
local dmg = CombatConfig.GetMeleeDamage(toolType, toolTier)
victimHum:TakeDamage(dmg)  -- ← BYPASSES ARMOR COMPLETELY
```

