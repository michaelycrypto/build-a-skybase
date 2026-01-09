# Progression Design Document
## Skyblox - Player Progression & Gameplay Loop

> *See [GAME_IDENTITY.md](./GAME_IDENTITY.md) for complete terminology and world-building context.*

---

## Executive Summary

This document defines the **player progression system** that connects all existing game mechanics (mining, crafting, golems, tools, armor, mobs, farming, building) into a cohesive gameplay experience from spawn to endgame.

**Skyblox** is a fantasy medieval multiverse where players own personal **Realms**, automate resource gathering with magical **Golems**, and progress through six material tiers from humble Copper to legendary Titanium.

---

## Table of Contents

1. [Core Progression Philosophy](#core-progression-philosophy)
2. [Tier System Overview](#tier-system-overview)
3. [Phase 1: Early Game (0-30 minutes)](#phase-1-early-game-0-30-minutes)
4. [Phase 2: Establishing (30-90 minutes)](#phase-2-establishing-30-90-minutes)
5. [Phase 3: Mid Game (90 min - 4 hours)](#phase-3-mid-game-90-min---4-hours)
6. [Phase 4: Late Game (4-10 hours)](#phase-4-late-game-4-10-hours)
7. [Phase 5: Endgame (10+ hours)](#phase-5-endgame-10-hours)
8. [System Interconnections](#system-interconnections)
9. [Progression Gates & Unlocks](#progression-gates--unlocks)
10. [Economy & Rewards](#economy--rewards)
11. [Implementation Checklist](#implementation-checklist)

---

## Core Progression Philosophy

### Design Pillars

1. **Tiered Gating** - Each tier unlocks access to the next tier's resources
2. **Parallel Paths** - Players can pursue combat, building, automation, or exploration
3. **Active → Passive** - Manual gathering evolves into Golem-powered automation
4. **Risk vs Reward** - Higher-tier materials require deeper exploration or harder challenges
5. **Meaningful Milestones** - Clear goals with tangible rewards at each stage

### The Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   GATHER → CRAFT → UPGRADE → UNLOCK → AUTOMATE → EXPAND        │
│     ↑                                                   │       │
│     └───────────────────────────────────────────────────┘       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tier System Overview

| Tier | Material | Tool Tier Required | Ore Depth | Spawn Rate | Time to Reach |
|------|----------|-------------------|-----------|------------|---------------|
| 1 | **Copper** | Fist/Wood | Surface-40 | 1.0% | 0-15 min |
| 2 | **Iron** | Copper (T1) | Surface-60 | 0.8% | 15-45 min |
| 3 | **Steel** | Iron (T2) | N/A (Iron + 2 Coal) | N/A | 30-60 min |
| 4 | **Bluesteel** | Steel (T3) | 20-50 depth | 0.4% | 1-2 hours |
| 5 | **Tungsten** | Bluesteel (T4) | 10-35 depth | 0.3% | 3-5 hours |
| 6 | **Titanium** | Tungsten (T5) | 5-25 depth | 0.2% | 6-10 hours |

### Material Flow

```
Wood → Sticks ──────────────────────────────────────────┐
                                                        │
Copper Ore + Coal → Copper Ingot → Copper Tools (T1) ──┼──→ Mine Iron
                                                        │
Iron Ore + Coal → Iron Ingot → Iron Tools (T2) ────────┼──→ Mine Normally
                                                        │
Iron Ore + 2 Coal → Steel Ingot → Steel Tools (T3) ────┼──→ Mine Bluesteel
                                                        │
Iron + 3 Coal + Bluesteel Dust → Bluesteel (T4) ───────┼──→ Mine Tungsten
                                                        │
Tungsten Ore + 4 Coal → Tungsten Ingot (T5) ───────────┼──→ Mine Titanium
                                                        │
Titanium Ore + 5 Coal → Titanium Ingot (T6) ───────────┘──→ ENDGAME
```

---

## Phase 1: Early Game (0-30 minutes)

### Player State
- No tools, empty inventory
- Spawns on surface or skyblock platform

### Immediate Goals

| Priority | Task | Purpose |
|----------|------|---------|
| 1 | **Punch trees** | Get wood for crafting table |
| 2 | **Craft workbench** | 4 planks → crafting table |
| 3 | **Craft wooden tools** | Basic mining capability |
| 4 | **Find coal** | Fuel for smelting |
| 5 | **Find copper ore** | First metal tier |
| 6 | **Build furnace** | 8 cobblestone → furnace |
| 7 | **Smelt copper** | Copper ore + coal |
| 8 | **Craft copper tools** | T1 mining speed |

### First 10 Minutes Checklist

```
□ Gather 16+ wood logs
□ Craft planks and sticks
□ Make crafting table
□ Make wooden pickaxe (if implemented) OR punch stone
□ Gather 20+ cobblestone
□ Build furnace
□ Find 10+ coal
□ Find 5+ copper ore
□ Smelt copper ingots
□ Craft copper pickaxe
```

### Survival Pressure (Optional)
- Day/night cycle with hostile mob spawns at night
- Hunger system requiring food
- Fall damage from high places

### Key Unlocks
- **Crafting Table** → Access to full recipe list
- **Furnace** → Smelting recipes
- **Copper Tools** → Efficient mining of stone and iron

---

## Phase 2: Establishing (30-90 minutes)

### Player State
- Copper tools equipped
- Basic shelter or platform established
- Beginning to accumulate resources

### Goals

| Priority | Task | Purpose |
|----------|------|---------|
| 1 | **Mine iron ore** | Next tier materials |
| 2 | **Craft iron tools** | Faster mining, better combat |
| 3 | **Build secure base** | Storage, crafting area |
| 4 | **Craft chest storage** | Inventory expansion |
| 5 | **Explore for resources** | Find rare ores |
| 6 | **Craft copper armor** | Basic protection |

### Resource Targets

| Resource | Target Amount | Purpose |
|----------|---------------|---------|
| Iron Ingots | 30+ | Full iron tools + start on armor |
| Coal | 50+ | Smelting stockpile |
| Cobblestone | 200+ | Building, furnaces |
| Wood | 100+ | Sticks, building |
| Copper Ingots | 24+ | Full copper armor set |

### Building Milestones

```
□ 3x3 enclosed room with door
□ Crafting table placed inside
□ Furnace placed inside
□ 4+ chests for storage
□ Light sources (torches) to prevent mob spawns
□ Farm plot started (if farming implemented)
```

### Key Unlocks
- **Iron Tools** → Can mine all basic ores efficiently
- **Copper Armor** → 6 total defense, survivable combat
- **Chest Network** → Organization and stockpiling

---

## Phase 3: Mid Game (90 min - 4 hours)

### Player State
- Iron tools/armor equipped
- Established base with storage
- Ready to pursue specialization

### Branching Paths

Players should be able to choose their focus:

#### Path A: Combat Focus
```
Goals:
- Craft full iron armor (10 defense)
- Upgrade to steel sword
- Hunt hostile mobs for drops
- Complete kill quests for rewards
- Push toward steel/bluesteel gear
```

#### Path B: Automation Focus
```
Goals:
- Craft first Stone Golem
- Place and level up Golem
- Collect passive resources
- Expand Golem network
- Unlock additional Golem types
```

#### Path C: Building Focus
```
Goals:
- Gather building materials (all wood types)
- Craft decorative blocks
- Expand base significantly
- Create farms for renewable resources
- Build showcase structures
```

### Steel Transition

**Critical Milestone**: Steel is the first "compound" material requiring:
- Iron Ore + 2 Coal (instead of 1)

This teaches players that higher tiers require more investment.

### Golem Introduction

| Milestone | Reward/Unlock |
|-----------|---------------|
| First 32 cobblestone | Can craft Stone Golem |
| Level 1 Golem | 1 slot unlocked, 15s interval |
| Level 2 Golem (64 cobblestone) | 2 slots, 14s interval |
| Level 3 Golem (128 cobblestone) | 3 slots, 13s interval |
| Level 4 Golem (256 cobblestone) | 4 slots, 12s interval |

### Steel Tier Targets

| Item | Materials Needed | Total Ingots |
|------|------------------|--------------|
| Steel Pickaxe | 3 ingots + 2 sticks | 3 |
| Steel Sword | 2 ingots + 1 stick | 2 |
| Steel Helmet | 5 ingots | 5 |
| Steel Chestplate | 8 ingots | 8 |
| Steel Leggings | 7 ingots | 7 |
| Steel Boots | 4 ingots | 4 |
| **Full Steel Set** | **29 Steel Ingots** | (29 Iron Ore + 58 Coal) |

---

## Phase 4: Late Game (4-10 hours)

### Player State
- Steel gear equipped
- Golem network generating passive resources
- Multiple branching goals available

### Bluesteel Transition

**Key Mechanic**: Bluesteel Ore only spawns at depth 20-50 and requires Steel (T3) tools.

**Smelting Recipe**: Iron Ore + 3 Coal + 1 Bluesteel Dust

This creates a **scarcity loop**:
1. Mine bluesteel ore (drops Bluesteel Dust)
2. Combine with iron + coal to make ingots
3. Each bluesteel item requires iron AND bluesteel dust

### Tungsten Introduction

Once players have Bluesteel (T4) tools:
- Tungsten Ore spawns at depth 10-35
- Even rarer (0.3% spawn rate)
- Requires 4 coal per smelt

### Late Game Goals

| Category | Goal | Reward |
|----------|------|--------|
| Combat | Kill 100 zombies | 500 coins, 5 gems |
| Mining | Mine 500 ores | Ore Golem unlock |
| Building | Place 1000 blocks | Builder badge |
| Automation | Own 5 Golems | Golem efficiency +10% |
| Collection | Obtain all T4 armor | Set bonus active |

### Specialization Unlocks

#### Combat Tree
```
Iron Armor → Steel Armor → Bluesteel Armor
     ↓            ↓             ↓
  +5% mining   +10% mining   +5% speed
```

#### Automation Tree
```
Stone Golem → Ore Golem → Guardian Golem?
     ↓            ↓              ↓
Basic blocks  Auto-smelt ores  Auto-defense
```

---

## Phase 5: Endgame (10+ hours)

### Player State
- Tungsten or Titanium gear
- Multiple maxed Golems
- Extensive base with all features
- Economy of surplus resources

### Endgame Content

#### 1. Titanium Pursuit
- Rarest ore (0.2% spawn rate)
- Deepest depths only (5-25)
- Requires T5 (Tungsten) tools
- 5 coal per smelt

#### 2. Collection Completion
```
□ All 6 tiers of each tool type (24 tools)
□ All 6 tiers of armor (24 pieces)
□ All building block types
□ All Golem types maxed
```

#### 3. Realm Showcase
- Player Realms can be visited by friends
- Builds demonstrate mastery
- Potential leaderboards for builds

#### 4. Combat Mastery
```
Kill Milestones:
- 500 zombies → Zombie Slayer title
- 100 of each passive mob → Animal Whisperer
- Complete all quests → Quest Master
```

### Titanium Set Bonus
```lua
{
    name = "Titanium Set",
    description = "+15% all damage, +10% knockback resist",
    damageBonus = 0.15,
    knockbackResist = 0.10
}
```

This is the ultimate goal - full Titanium represents mastery.

---

## System Interconnections

### How Systems Feed Each Other

```
                    ┌──────────────────┐
                    │     MINING       │
                    │  (Ores, Stone)   │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │ SMELTING│    │ BUILDING│    │ CRAFTING│
        │(Ingots) │    │ (Base)  │    │ (Items) │
        └────┬────┘    └────┬────┘    └────┬────┘
             │              │              │
             ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │  TOOLS  │    │ STORAGE │    │  ARMOR  │
        │(Mining+)│    │(Chests) │    │(Defense)│
        └────┬────┘    └────┬────┘    └────┬────┘
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                    ┌──────────────────┐
                    │      GOLEMS      │
                    │  (Automation)    │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌─────────┐    ┌─────────┐    ┌─────────┐
        │ PASSIVE │    │  MORE   │    │  MORE   │
        │RESOURCES│    │ GOLEMS  │    │ STORAGE │
        └─────────┘    └─────────┘    └─────────┘
```

### Golem → Mining Loop

```lua
-- Golems are ELEMENTALS - tied to natural resources only
-- Current Golem types
STONE_GOLEM: Generates cobblestone
EARTH_GOLEM: Generates dirt

-- Proposed elemental Golem expansion
COAL_GOLEM: Generates coal (fuel for smelting)
SAND_GOLEM: Generates sand (glass production)
COPPER_GOLEM: Generates copper ore (T1 metal)
IRON_GOLEM: Generates iron ore (T2 metal, requires Steel to craft)
```

### Combat → Resources Loop

```lua
-- Mob drops feed back into progression
ZOMBIE:
  - Rotten Flesh (food/trade)
  - Iron Ingot (5% chance) -- shortcuts mining

SHEEP:
  - Wool (building material)
  - Raw Mutton (food)

COW:
  - Leather (potential armor component?)
  - Raw Beef (food)
```

---

## Progression Gates & Unlocks

### Hard Gates (Cannot Progress Without)

| Gate | Requirement | Unlocks |
|------|-------------|---------|
| **Crafting Table** | 4 planks | All recipes |
| **Furnace** | 8 cobblestone | Smelting |
| **Copper Tools** | 3 copper ingots | Efficient mining |
| **Steel Tools** | Steel ingots | Bluesteel ore mining |
| **Bluesteel Tools** | Bluesteel ingots | Tungsten ore mining |
| **Tungsten Tools** | Tungsten ingots | Titanium ore mining |

### Soft Gates (Highly Recommended)

| Gate | Requirement | Benefit |
|------|-------------|---------|
| Armor | 24 ingots per tier | Survival in combat |
| Chest Storage | 8 planks each | Inventory management |
| Multiple Furnaces | Cobblestone | Parallel smelting |
| Golems | Block materials | Passive generation |

### Time-Gated Content (Optional Design)

| Content | Time Gate | Purpose |
|---------|-----------|---------|
| Daily quests | 24 hour reset | Retention |
| Golem collection | Real-time intervals | Passive engagement |
| Crop growth | 5 second ticks | Patience reward |

---

## Economy & Rewards

### Currency System

| Currency | Source | Use |
|----------|--------|-----|
| **Coins** | Quest rewards, mob drops | Shop purchases |
| **Gems** | Milestone rewards, rare | Premium unlocks |

### Quest Reward Scaling

```lua
-- Example from QuestConfig
Goblin Quests:
  10 kills → 25 coins
  20 kills → 25 coins
  ...
  100 kills → 500 coins + 5 gems
  500 kills → 1000 coins + 25 gems
```

### Proposed Reward Expansion

| Milestone | Reward |
|-----------|--------|
| First copper tool | 10 coins |
| First iron tool | 25 coins |
| First steel tool | 50 coins |
| First bluesteel tool | 100 coins |
| First tungsten tool | 200 coins |
| First titanium tool | 500 coins + 10 gems |
| Full armor set (any tier) | 100 coins |
| Full titanium set | 2000 coins + 50 gems |

---

## Implementation Checklist

### Phase 1: Core Loop (Critical)
- [x] 6-tier material system (Copper → Iron → Steel → Bluesteel → Tungsten → Titanium)
- [x] Tools for all tiers (Pickaxe, Axe, Shovel, Sword)
- [x] Armor for all tiers (Helmet, Chestplate, Leggings, Boots)
- [x] Smelting recipes (ores → ingots)
- [x] Crafting recipes (workbench, furnace, tools, armor)
- [x] Inventory persistence (hotbar + 27 slots saved to DataStore)
- [x] Farming system (Farmland, Wheat, Potato, Carrot, Beetroot crops)
- [x] Tree growth (Saplings → Trees with all wood types)
- [ ] **Wooden tools** (starter tier before copper?)
- [ ] **Tutorial/onboarding** for new players
- [ ] **Ore depth distribution** verification
- [ ] **Food/hunger system** (optional survival pressure)

### Phase 2: Automation (Golems)

> *Golems are elementals — magical constructs tied to natural resources (stone, earth, ore). No organic materials.*

- [x] Stone Golem (generates cobblestone)
- [x] Earth Golem (generates dirt)
- [x] Golem leveling (upgrade with materials)
- [ ] **Coal Golem** (generates coal)
- [ ] **Copper Golem** (generates copper ore — slower, rarer)
- [ ] **Iron Golem** (generates iron ore — requires Steel to craft)
- [ ] **Sand Golem** (generates sand)
- [ ] **Golem UI polish** (better visuals, stats display)
- [ ] **Golem fuel system?** (optional: requires coal to run)

### Phase 3: Combat & Mobs
- [x] Zombie hostile mob
- [x] Passive mobs (Sheep, Cow, Chicken)
- [x] Damage/armor calculations
- [x] Mob sound effects (ambient, attack, hurt, death)
- [ ] **Skeleton** (ranged hostile mob)
- [ ] **Spider** (climbing hostile mob)
- [ ] **Creeper/Goblin** (melee rush mob)
- [ ] **Boss mobs** for endgame (Golem Boss? Dragon?)
- [ ] **Mob spawner blocks** for farming

### Phase 4: Quests & Achievements
- [x] Kill-count quests (Zombie milestones)
- [x] Milestone coin/gem rewards
- [ ] **Crafting quests** (craft your first X tool/armor)
- [ ] **Mining quests** (mine X ore, reach depth Y)
- [ ] **Building quests** (place X blocks)
- [ ] **Golem quests** (place your first Golem)
- [ ] **Achievement badges** (visual rewards)

### Phase 5: Economy
- [x] Coin rewards from quests
- [ ] **Shop NPC/UI** for purchasing items
- [ ] **Gem premium currency** uses (cosmetics? boosts?)
- [ ] **Player trading** (optional future feature)

### Phase 6: Multiverse & Portals
- [x] The Nexus (hub/lobby place)
- [x] Player Realms (personal worlds with persistence)
- [x] Friends' Realms tab (view online friends' worlds)
- [x] Cross-place teleportation (lobby ↔ realms)
- [ ] **Resource Worlds** (shared public dimensions)
- [ ] **Mining World** (ore-rich, competitive gathering)
- [ ] **Forest World** (wood-rich, passive mobs)
- [ ] **Danger World** (hostile mobs, rare loot)
- [ ] **Physical portal blocks** (craftable frames in-world)
- [ ] **Portal activation items** (keys for Resource Worlds)
- [ ] **Portal visual effects** (swirling magic when active)
- [ ] **Resource World resets** (periodic regeneration)

### Phase 7: Social Features
- [x] Friend list integration (Roblox friends API)
- [x] Join friends' online Realms
- [ ] **Realm permissions UI** (visitor/builder mode toggle)
- [ ] **Realm invite codes** (share with non-friends)
- [ ] **Visit notifications** ("X entered your Realm")
- [ ] **Co-building mode** (trusted friends can place blocks)

### Phase 8: Audio & Polish
- [x] Sound manager (SFX, music)
- [x] Basic background music
- [x] UI click/hover sounds
- [ ] **Mining sounds by material** (stone vs wood vs ore)
- [ ] **Combat hit/block sounds**
- [ ] **Golem ambient sounds** (footsteps, working)
- [ ] **Day/night audio shift**
- [ ] **Portal activation sounds**
- [ ] **Additional music tracks** (exploration, combat, building)

### Phase 9: UI/UX Polish
- [x] Main HUD (coins, gems, menu icons)
- [x] Inventory panel (Minecraft-style drag/drop)
- [x] Crafting panel (recipe browser)
- [x] Realms panel (my realms, friends, hub)
- [x] Quests panel
- [x] Responsive scaling (1920x1080 base)
- [ ] **Tutorial tooltips** (first-time guidance)
- [ ] **Settings panel** (audio, controls, graphics)
- [ ] **Keybind customization**
- [ ] **Mobile control polish** (virtual joystick improvements)

### Phase 10: Endgame Content
- [ ] **Armor set bonuses** (full Titanium = +15% damage)
- [ ] **Rare item variants** (glowing/enchanted tools?)
- [ ] **Leaderboards** (blocks placed, mobs killed, Golems owned)
- [ ] **Prestige system?** (reset for permanent bonuses)
- [ ] **Seasonal events** (limited-time content)

---

### Priority Summary

| Priority | Category | Key Items | Impact |
|----------|----------|-----------|--------|
| 🔴 **P0** | Multiverse | Resource Worlds, Portal blocks | Core differentiator |
| 🔴 **P0** | Onboarding | Tutorial/tooltips | Player retention |
| 🟠 **P1** | Automation | More Golem types (Coal, Copper, Iron) | Progression depth |
| 🟠 **P1** | Combat | Additional hostile mobs | Mid/late game content |
| 🟡 **P2** | Social | Realm permissions, visit notifications | Social engagement |
| 🟡 **P2** | Economy | Shop system, gem uses | Monetization path |
| 🟢 **P3** | Polish | Audio improvements, settings panel | Quality of life |
| 🟢 **P3** | Endgame | Set bonuses, leaderboards | Long-term retention |

### Quick Wins (Low Effort, High Impact)

1. **Wooden Pickaxe** — Simple recipe addition, smooths early game
2. **Tutorial tooltips** — Help text on first interactions
3. **Mining sounds by material** — Satisfying feedback loop
4. **Armor set bonuses** — Config change, adds depth
5. **Crafting/Mining quests** — Extend existing quest system

---

## Appendix A: Full Item Tier Reference

### Tools by Tier

| Tier | Pickaxe ID | Axe ID | Shovel ID | Sword ID |
|------|------------|--------|-----------|----------|
| Copper (1) | 1001 | 1011 | 1021 | 1041 |
| Iron (2) | 1002 | 1012 | 1022 | 1042 |
| Steel (3) | 1003 | 1013 | 1023 | 1043 |
| Bluesteel (4) | 1004 | 1014 | 1024 | 1044 |
| Tungsten (5) | 1005 | 1015 | 1025 | 1045 |
| Titanium (6) | 1006 | 1016 | 1026 | 1046 |

### Armor by Tier

| Tier | Helmet | Chest | Legs | Boots | Total Defense |
|------|--------|-------|------|-------|---------------|
| Copper | 3001 | 3002 | 3003 | 3004 | 6 |
| Iron | 3005 | 3006 | 3007 | 3008 | 10 |
| Steel | 3009 | 3010 | 3011 | 3012 | 13 |
| Bluesteel | 3013 | 3014 | 3015 | 3016 | 16 (+1 tough) |
| Tungsten | 3017 | 3018 | 3019 | 3020 | 20 (+2 tough) |
| Titanium | 3021 | 3022 | 3023 | 3024 | 24 (+3 tough) |

### Ingot Requirements per Tier

| Item | Ingots |
|------|--------|
| Pickaxe | 3 |
| Axe | 3 |
| Shovel | 1 |
| Sword | 2 |
| Helmet | 5 |
| Chestplate | 8 |
| Leggings | 7 |
| Boots | 4 |
| **Full Tool Set** | **9** |
| **Full Armor Set** | **24** |
| **Complete Tier** | **33** |

---

## Appendix B: Ore Spawn Configuration

```lua
-- Current spawn rates from ItemDefinitions.lua
COAL_ORE:      spawnRate = 0.012 (1.2%)
COPPER_ORE:    spawnRate = 0.010 (1.0%)
IRON_ORE:      spawnRate = 0.008 (0.8%)
BLUESTEEL_ORE: spawnRate = 0.004 (0.4%)
TUNGSTEN_ORE:  spawnRate = 0.003 (0.3%)
TITANIUM_ORE:  spawnRate = 0.002 (0.2%)

-- Mining tier requirements
COAL_ORE:      minToolTier = 1 (Copper+)
COPPER_ORE:    minToolTier = 1 (Copper+)
IRON_ORE:      minToolTier = 1 (Copper+)
BLUESTEEL_ORE: minToolTier = 3 (Steel+)
TUNGSTEN_ORE:  minToolTier = 4 (Bluesteel+)
TITANIUM_ORE:  minToolTier = 5 (Tungsten+)
```

---

## Appendix C: Time Estimates

### Casual Player (1-2 hours/day)

| Phase | Days to Complete |
|-------|------------------|
| Early Game | Day 1 |
| Establishing | Day 1-2 |
| Mid Game | Day 2-5 |
| Late Game | Day 5-14 |
| Endgame | Day 14+ (ongoing) |

### Hardcore Player (4+ hours/day)

| Phase | Time to Complete |
|-------|------------------|
| Early Game | 30 minutes |
| Establishing | 1-2 hours |
| Mid Game | 2-4 hours |
| Late Game | 4-10 hours |
| Endgame | 10+ hours |

---

*Document Version: 3.0*
*Last Updated: January 2026*
*Aligned with: [GAME_IDENTITY.md](./GAME_IDENTITY.md)*

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | Jan 2026 | Expanded implementation checklist to 10 phases with 70+ items; added priority summary and quick wins |
| 2.0 | Jan 2026 | Updated terminology to match Skyblox identity (Minions → Golems, Worlds → Realms) |
| 1.0 | Jan 2026 | Initial progression design document |

