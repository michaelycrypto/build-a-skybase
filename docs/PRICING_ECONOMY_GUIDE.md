# TDS Voxel Economy - Complete Pricing Guide

## TABLE OF CONTENTS
1. [Core Economy Principles](#core-economy-principles)
2. [Starting Conditions](#starting-conditions)
3. [Crop Farming Economy](#crop-farming-economy)
4. [Tree Farming Economy](#tree-farming-economy)
5. [Mining & Ore Economy](#mining--ore-economy)
6. [Tools & Equipment](#tools--equipment)
7. [Utility Blocks](#utility-blocks)
8. [Building & Decoration](#building--decoration)
9. [Automation (Minions)](#automation-minions)
10. [Progression Timeline](#progression-timeline)
11. [Income Analysis](#income-analysis)
12. [Pricing Philosophy](#pricing-philosophy)

---

## CORE ECONOMY PRINCIPLES

### Design Goals
1. **Players EARN through farming** - Crops, trees, and mining are primary income
2. **Players SPEND on expansion** - Tools, seeds, saplings, utility blocks
3. **No arbitrage** - Sell price = 40-60% of buy price (encourages farming, not flipping)
4. **Building blocks sold in stacks** - Encourages bulk purchasing for construction
5. **Utility blocks are expensive** - Major money sinks (crafting table, furnace, chest)
6. **Farming resources cheap with low margins** - Accessible but requires volume

### Sell Price Multipliers
- **Raw farmable resources**: 50-60% (best margins - rewards active farming)
- **Processed materials**: 40-45% (convenience tax)
- **Tools**: 40% (prevent tool flipping)
- **Utility blocks**: 30-35% (strong money sink)
- **Decoratives**: 30-40% (money sink, low resale value)

---

## STARTING CONDITIONS

### Starting Inventory (From GameConfig.lua)
**Hotbar (8 slots):**
- Copper Pickaxe (ready to mine)
- Copper Axe (ready to chop)
- Copper Shovel (ready to dig)
- Copper Sword (ready to fight)
- Bow (ranged combat)
- 16x Bread (food)
- 32x Water Source Block (hydration)
- 4x Bucket (water collection)

**Inventory (starter kit):**
- 64x Copper Arrows (ammo)
- 4x Oak Sapling (tree farming)
- 8x Wheat Seeds (crop farming)
- 4x Potatoes (crop farming)
- 4x Carrots (crop farming)
- 64x Dirt (farmland creation)
- 64x Cobblestone (basic building)
- 64x Oak Planks (crafting)
- 8x Apples (food)
- 1x Crafting Table (utility)

**Starting Currency:**
- 100 coins

**Total Starting Value:**
- Tools: ~20,000 coins (4 copper tools + bow)
- Materials: ~8,000 coins (dirt, cobblestone, planks)
- Seeds/Saplings: ~40,000 coins (4 oak saplings)
- Food/Misc: ~2,000 coins
- **Total: ~70,000 coins worth of starting gear + 100 coins cash**

### Key Insight
Players start with copper tools and basic resources, allowing immediate farming and mining. The focus is on teaching the farming loop, not grinding for first tools.

---

## CROP FARMING ECONOMY

### Growth Mechanics (From CropConfig.lua)
- **Tick interval**: 5 seconds
- **Growth chance**: 1/20 per tick (5%)
- **Expected time per stage**: 100 seconds (~1.7 minutes)

### Crop Growth Times
| Crop | Stages | Total Growth Time | Harvests/Hour |
|------|--------|-------------------|---------------|
| Wheat | 8 stages | ~13 minutes | 4.6 harvests/hour |
| Potato | 4 stages | ~7 minutes | 8.6 harvests/hour |
| Carrot | 4 stages | ~7 minutes | 8.6 harvests/hour |
| Beetroot | 4 stages | ~7 minutes | 8.6 harvests/hour |

### Crop Economics (Prices in COINS per unit)

#### Seeds & Harvested Crops
| Item | Buy Price | Sell Price | Growth Time | Margin | ROI Analysis |
|------|-----------|------------|-------------|--------|--------------|
| **Wheat Seeds** | 10 | N/A (unsellable) | - | - | Must buy to expand |
| **Wheat** | - | 10 | 13 min | 100% of seed cost | Break-even per harvest |
| **Beetroot Seeds** | 50 | N/A | - | - | Must buy to expand |
| **Beetroot** | - | 30 | 7 min | 60% of seed cost | Profit after 2 harvests |
| **Potato** (seed) | 250 | 30 (sellable) | - | 12% | Low resale |
| **Potato** (harvest) | - | 150 | 7 min | 60% | 1-3 drops (avg 2), profit after 1 harvest |
| **Carrot** (seed) | 1,250 | 80 (sellable) | - | 6.4% | Low resale |
| **Carrot** (harvest) | - | 750 | 7 min | 60% | 1-3 drops (avg 2), profit after 1 harvest |

#### Crop Drop Rates (From VoxelWorldService)
- **Wheat**: 1 wheat + 1 seed (guaranteed when mature)
- **Potato**: 1-3 potatoes (average 2) when mature
- **Carrot**: 1-3 carrots (average 2) when mature
- **Beetroot**: 1 beetroot + 0-3 seeds when mature

### Income Per Hour (Active Farming)
**Assumptions**: 30-plant farm, continuous harvesting

| Crop | Harvests/Hour | Avg Yield | Income/Hour | Seed Cost | Net Income |
|------|---------------|-----------|-------------|-----------|------------|
| Wheat | 4.6 | 1 wheat | 46 × 10 = 460 | 300 (30 seeds) | 160/hour |
| Beetroot | 8.6 | 1 beetroot | 258 × 30 = 7,740 | 1,500 (30 seeds) | 6,240/hour |
| Potato | 8.6 | 2 potatoes | 258 × 300 = 77,400 | 7,500 (30 seeds) | 69,900/hour |
| Carrot | 8.6 | 2 carrots | 258 × 1,500 = 387,000 | 37,500 (30 seeds) | 349,500/hour |

**Note**: Income scales with farm size. Wheat provides minimal income (teaches mechanics), while carrots offer significant returns but require high initial investment.

### Farming Progression Strategy
1. **Hour 0-1**: Plant 8 wheat seeds (free starter) → ~80 coins, get seeds back
2. **Hour 1-3**: Expand to 30 wheat → ~160 coins/hour (slow grind)
3. **Hour 3-6**: Buy beetroot seeds → ~6,000 coins/hour (better margin)
4. **Hour 6-10**: Buy potato seeds → ~70,000 coins/hour (multiplication!)
5. **Hour 10+**: Buy carrot seeds → ~350,000 coins/hour (late-game farming)

---

## TREE FARMING ECONOMY

### Growth Mechanics (From SaplingConfig.lua)
- **Tick interval**: 5 seconds
- **Growth chance**: 1/30 per tick (3.33%)
- **Expected growth time**: ~150 seconds (~2.5 minutes)
- **All trees produce**: 6 logs when grown from sapling (no variation)

### Leaf Drop Rates
- **Sapling drop**: 5% per leaf block
- **Apple drop**: 0.5% per oak leaf block (oak only)
- **Average leaf count**: ~43 leaves per tree (17+17+9)
- **Expected sapling drops**: 2-3 saplings per tree
- **Expected apple drops**: 0.2-0.3 apples per oak tree

### Tree Economics (Prices in COINS per unit)

#### Saplings & Logs
| Tree Type | Sapling Buy | Sapling Sell | Log Sell | Growth Time | Value/Tree | ROI |
|-----------|-------------|--------------|----------|-------------|------------|-----|
| **Oak** | 10,000 | 1,200 | 5,000 | 2.5 min | 30,000 (6 logs) | Profit after 2 trees |
| **Spruce** | 20,000 | 1,800 | 10,000 | 2.5 min | 60,000 (6 logs) | Profit after 2 trees |
| **Birch** | 40,000 | 2,400 | 20,000 | 2.5 min | 120,000 (6 logs) | Profit after 2 trees |
| **Jungle** | 80,000 | 3,600 | 40,000 | 2.5 min | 240,000 (6 logs) | Profit after 2 trees |
| **Dark Oak** | 160,000 | 5,400 | 80,000 | 2.5 min | 480,000 (6 logs) | Profit after 2 trees |
| **Acacia** | 320,000 | 8,000 | 160,000 | 2.5 min | 960,000 (6 logs) | Profit after 2 trees |

**Critical Note**: All trees produce exactly 6 logs. Higher-tier trees have proportionally higher log values.

### Plank Processing (1 log = 4 planks via crafting)
| Wood Type | Log Value | Plank Value | Total (4 planks) | Processing Gain |
|-----------|-----------|-------------|------------------|-----------------|
| Oak | 5,000 | 1,250 | 5,000 | 0% (neutral) |
| Spruce | 10,000 | 2,500 | 10,000 | 0% (neutral) |
| Birch | 20,000 | 5,000 | 20,000 | 0% (neutral) |
| Jungle | 40,000 | 10,000 | 40,000 | 0% (neutral) |
| Dark Oak | 80,000 | 20,000 | 80,000 | 0% (neutral) |
| Acacia | 160,000 | 40,000 | 160,000 | 0% (neutral) |

**Processing Strategy**: No advantage to processing logs into planks for selling. Only process if you need planks for crafting.

### Income Per Hour (Active Tree Farming)
**Assumptions**: 10-tree farm, continuous planting/harvesting (2.5 min growth + 30s harvest/replant)

| Tree Type | Cycles/Hour | Logs/Cycle | Income/Hour | Sapling Cost | Net Income |
|-----------|-------------|------------|-------------|--------------|------------|
| Oak | 20 cycles | 60 logs | 300,000 | 100,000 | 200,000/hour |
| Spruce | 20 cycles | 60 logs | 600,000 | 200,000 | 400,000/hour |
| Birch | 20 cycles | 60 logs | 1,200,000 | 400,000 | 800,000/hour |
| Jungle | 20 cycles | 60 logs | 2,400,000 | 800,000 | 1,600,000/hour |
| Dark Oak | 20 cycles | 60 logs | 4,800,000 | 1,600,000 | 3,200,000/hour |
| Acacia | 20 cycles | 60 logs | 9,600,000 | 3,200,000 | 6,400,000/hour |

**Leaf Bonus Income**:
- Oak: ~2-3 saplings/tree = 24,000-36,000/hour bonus
- Oak: ~0.2-0.3 apples/tree = 4,000-6,000/hour bonus
- Other trees: ~2-3 saplings/tree = varying based on sapling sell price

### Tree Farming Progression
1. **Start**: Use 4 free oak saplings → 30,000 coins (20,000 net after 1 replant)
2. **Early (100 coins)**: Can't afford saplings yet, focus on crops
3. **Mid (10,000+ coins)**: Buy 1 oak sapling → break even after 2 trees
4. **Mid-Late (50,000+ coins)**: Expand oak farm → 200,000/hour income
5. **Late (100,000+ coins)**: Upgrade to spruce → 400,000/hour income
6. **End-game**: Acacia trees → 6,400,000/hour income

---

## MINING & ORE ECONOMY

### Ore Spawn Rates (From ItemDefinitions.lua)
| Ore | Spawn Rate | Drop Item | Sell Price |
|-----|------------|-----------|------------|
| Coal Ore | 1.2% | Coal | 500 |
| Copper Ore | 1.0% | Raw Copper | 800 |
| Iron Ore | 0.8% | Raw Iron | 1,200 |
| Bluesteel Ore | 0.4% | Bluesteel Dust | 1,500 |
| Diamond Ore | - | Diamond | 10,000 |

### Cobblestone Mining (Primary Income)
**Assumptions**: Using cobblestone generator (infinite mining), stone/iron pickaxe

| Material | Sell Price | Expected % | Expected Value/1000 Blocks |
|----------|------------|------------|---------------------------|
| Cobblestone | 200 | 96.6% | 193,200 |
| Coal Ore → Coal | 500 | 1.2% | 6,000 |
| Copper Ore → Raw Copper | 800 | 1.0% | 8,000 |
| Iron Ore → Raw Iron | 1,200 | 0.8% | 9,600 |
| Bluesteel Ore → Dust | 1,500 | 0.4% | 6,000 |
| **Total Expected Value** | - | 100% | **222,800/1000 blocks** |

### Mining Income Per Hour
**Assumptions**: 3-4 blocks/second mining speed with copper/iron tools

| Tool Tier | Blocks/Second | Blocks/Hour | Gross Income | Notes |
|-----------|---------------|-------------|--------------|-------|
| Copper Pickaxe | 2.5 | 9,000 | 2,005,200 | Starter tool (free) |
| Iron Pickaxe | 3.5 | 12,600 | 2,807,280 | Mid-game upgrade (25,000 cost) |
| Steel Pickaxe | 4.5 | 16,200 | 3,609,360 | Late-game (higher cost) |

**Net Income** (after tool durability costs is minimal - tools last 132-251 uses)

### Mining Progression
1. **Start**: Use free copper pickaxe → ~2,000,000/hour (incredible income!)
2. **Early (25,000 coins)**: Upgrade to iron pickaxe → ~2,800,000/hour
3. **Mid-game**: Mining is highest income activity until advanced tree farms

**Key Insight**: Mining is the dominant income source in early-mid game. Cobblestone generators are accessible early (just need water + lava sources).

---

## TOOLS & EQUIPMENT

### Tool Pricing Strategy
- **Copper tools (Tier 1)**: Affordable starter tier (5,000 coins)
- **Iron tools (Tier 2)**: Mid-game upgrade (25,000 coins)
- **Steel/Bluesteel**: Late-game luxury (expensive, gated by rare ores)
- **Swords**: Slightly more expensive than tools (+40% premium)

### Tool Buy/Sell Prices (From NPCTradeConfig.lua)

#### Copper Tools (Tier 1 - Starter)
| Tool | Buy Price | Sell Price (40%) | Durability | Cost/Use |
|------|-----------|------------------|------------|----------|
| Copper Pickaxe | 5,000 | 2,000 | - | Low |
| Copper Axe | 5,000 | 2,000 | - | Low |
| Copper Shovel | 5,000 | 2,000 | - | Low |
| Copper Sword | 7,500 | 3,000 | - | Low |

#### Iron Tools (Tier 2 - Mid-Game)
| Tool | Buy Price | Sell Price (40%) | Durability | Cost/Use |
|------|-----------|------------------|------------|----------|
| Iron Pickaxe | 25,000 | 10,000 | - | Medium |
| Iron Axe | 25,000 | 10,000 | - | Medium |
| Iron Shovel | 25,000 | 10,000 | - | Medium |
| Iron Sword | 35,000 | 14,000 | - | Medium |

**Note**: Diamond tools exist at 80,000+ coins (endgame luxury items)

### Arrows (Consumable Ammo)
| Arrow Type | Buy Price | Sell Price (40%) | Stock | Notes |
|------------|-----------|------------------|-------|-------|
| Copper Arrow | 500 | 200 | 64 | Starter ammo (64 free) |
| Iron Arrow | 1,000 | 400 | 32 | Mid-tier |
| Steel Arrow | 2,000 | 800 | 16 | Advanced |
| Bluesteel Arrow | 4,000 | 1,600 | 8 | Endgame |

**Ammo Economy**: Consumable sink (creates ongoing demand). Players get 64 free copper arrows, but need to buy more for sustained bow use.

---

## UTILITY BLOCKS

### Philosophy: Strong Money Sinks
Utility blocks are essential for progression but have terrible resale value (30-35% of buy price). This creates permanent money sinks in the economy.

### Core Utilities (From NPCTradeConfig.lua)
| Block | Buy Price | Sell Price (30%) | Stock | Purpose |
|-------|-----------|------------------|-------|---------|
| **Crafting Table** | 10,000 | 3,000 | 3 | Required for recipes |
| **Furnace** | 15,000 | 4,500 | 3 | Smelting ores |
| **Chest** | 20,000 | 6,000 | 5 | Storage expansion |
| **Composter** | 25,000 | 7,500 | 2 | Waste recycling |

**Starting Bonus**: Players get 1 free crafting table in starter inventory (worth 10,000 coins)

### Advanced Utilities (Late Game)
| Block | Buy Price | Sell Price | Notes |
|-------|-----------|------------|-------|
| Anvil | ~50,000 | ~15,000 | Tool repair/enchant |
| Enchanting Table | ~100,000 | ~30,000 | Tool upgrades |
| Brewing Stand | ~30,000 | ~9,000 | Potion crafting |
| Blast Furnace | ~10,000 | ~3,000 | Faster smelting |

### Economic Impact
Utility blocks create "commitment purchases" - players need them for progression but can't resell without massive loss. This prevents hoarding/flipping and creates demand for continuous farming income.

---

## BUILDING & DECORATION

### Pricing Strategy (STACK-BASED)
**All building blocks, stone variants, and decorations are priced per stack (64 blocks)**

This encourages bulk purchasing for construction projects and makes pricing intuitive for large builds.

### Basic Building Blocks (Per Stack of 64)
| Block | Buy/Stack | Sell/Stack (40%) | Individual Buy | Individual Sell |
|-------|-----------|------------------|----------------|-----------------|
| **Dirt** | 19,200 (300×64) | 5,760 | 300 | 90 |
| **Cobblestone** | 25,600 (400×64) | 12,800 | 400 | 200 |
| **Stone** | 38,400 (600×64) | 19,200 | 600 | 300 |
| **Sand** | 32,000 (500×64) | 12,800 | 500 | 200 |
| **Gravel** | 25,600 (400×64) | 12,800 | 400 | 200 |
| **Glass** | 76,800 (1,200×64) | 32,000 | 1,200 | 500 |

### Processed Building Blocks (Per Stack)
| Block | Buy/Stack | Sell/Stack (40%) | Individual Buy | Individual Sell |
|-------|-----------|------------------|----------------|-----------------|
| **Bricks** | 51,200 (800×64) | 19,200 | 800 | 300 |
| **Stone Bricks** | 64,000 (1,000×64) | 25,600 | 1,000 | 400 |
| **Sandstone** | 96,000 (1,500×64) | 38,400 | 1,500 | 600 |
| **Nether Bricks** | 128,000 (2,000×64) | 51,200 | 2,000 | 800 |

### Decorative Blocks (Per Stack - Money Sinks)

#### Tier 1: Wool (Cheapest Decoration)
- **Buy**: 96,000/stack (1,500×64)
- **Sell**: 9,600/stack (150×64) - **Only 10% resale!**
- **Purpose**: Discourage sheep farming, pure decoration sink

#### Tier 2: Stained Glass
- **Buy**: 160,000/stack (2,500×64)
- **Sell**: 51,200/stack (800×64) - 32% resale
- **Purpose**: Premium building material

#### Tier 3: Concrete (Modern Look)
- **Buy**: 224,000/stack (3,500×64)
- **Sell**: 76,800/stack (1,200×64) - 34% resale
- **Purpose**: End-game construction aesthetic

#### Tier 4: Premium Blocks (Individual Pricing)
| Block | Buy Price | Sell Price (30%) | Notes |
|-------|-----------|------------------|-------|
| Quartz Block | 10,000 | 3,000 | Late-game luxury |
| Prismarine | 15,000 | 4,500 | Ocean aesthetic |
| Glowstone | 35,000 | 10,000 | Light source |
| Obsidian | 50,000 | 15,000 | Ultra-premium |
| End Stone Bricks | 100,000 | 30,000 | Endgame |
| Beacon | 1,000,000 | 300,000 | Ultimate status symbol |

### Building Cost Examples
**Simple 10×10 House (floor + 4 walls + roof = ~600 blocks)**
- Cobblestone: 9-10 stacks = 240,000 coins
- Stone Bricks: 9-10 stacks = 600,000 coins
- With glass windows (+2 stacks): +153,600 coins

**Large Castle (5,000 blocks)**
- Stone Bricks: 78 stacks = 5,000,000 coins
- Premium accents: +1,000,000 coins
- **Total**: 6,000,000+ coins for ambitious build

**Economic Impact**: Large construction projects create sustained demand for farming income over many hours/days.

---

## AUTOMATION (MINIONS)

### Minion Mechanics (From MinionConfig.lua)
- **Base interval**: 15 seconds per action cycle
- **Level progression**: 1-4, each level reduces interval by 1 second
- **Slot capacity**: 1 base + 1 per level (max 4 slots at level 4)
- **Upgrade cost**: 32/64/128 blocks per level

### Minion Types

#### Cobblestone Minion (Basic Automation)
- **Buy Price**: 250,000
- **Sell Price**: 50,000 (20% - terrible resale)
- **Production**: Places/mines cobblestone
- **Output**: ~240 cobblestone/hour at level 1 (15s cycle)
- **Income**: 48,000/hour at level 1
- **ROI**: 5.2 hours of passive income to break even

#### Coal Minion (Premium Automation)
- **Buy Price**: 500,000
- **Sell Price**: N/A (not tracked in current config)
- **Production**: Places cobblestone with 20% coal ore bonus
- **Output**: ~192 cobblestone + ~48 coal ore/hour at level 1
- **Income**: ~38,400 + ~24,000 = 62,400/hour at level 1
- **ROI**: 8 hours of passive income to break even

### Minion Performance by Level
| Level | Interval | Actions/Hour | Cobblestone/Hour | Coal Ore/Hour (20%) | Total Income/Hour |
|-------|----------|--------------|------------------|---------------------|-------------------|
| 1 | 15s | 240 | 192 | 48 | 62,400 |
| 2 | 14s | 257 | 206 | 51 | 66,700 |
| 3 | 13s | 277 | 222 | 55 | 71,900 |
| 4 | 12s | 300 | 240 | 60 | 78,000 |

**Upgrade Investment**:
- Level 1→2: 32 items (varies by minion type)
- Level 2→3: 64 items
- Level 3→4: 128 items

### Passive Income Strategy
1. **No minions (hours 0-10)**: Active farming/mining only
2. **First minion (250,000)**: Cobblestone minion → 48,000/hour passive
3. **Upgrade to level 2-4**: Boost to ~70,000/hour passive
4. **Second minion (500,000)**: Coal minion → +62,000/hour passive
5. **End-game**: Multiple max-level minions → 300,000+/hour passive

**Key Insight**: Minions provide passive income but require massive upfront investment and long ROI periods (5-8 hours). Players should prioritize active income first.

---

## PROGRESSION TIMELINE

### Phase 1: Early Game (Hours 0-2) - Learning the Basics
**Starting Assets**: 70,000 coins worth of gear + 100 coins cash

**Hour 0-1: First Steps**
- Plant 8 wheat seeds (free starter) → First harvest in 13 min
- Plant 4 oak saplings (free starter) → 6 logs each in 2.5 min
- Explore cobblestone generator setup (need water/lava)
- **First income**: 80 coins from wheat, 24,000 from first tree
- **Net assets**: ~24,000 coins

**Hour 1-2: Expansion**
- Buy 16 more wheat seeds (160 coins) → 24-plant farm
- Harvest first 4 oak trees → 120,000 coins (24 logs)
- Buy 2 more oak saplings (20,000) → expand tree farm to 6 trees
- **Net assets**: ~100,000 coins

**Key Milestone**: First 100,000 coins (enables utility purchases)

### Phase 2: Mid-Early Game (Hours 2-5) - Building Infrastructure
**Hour 2-3: Tool Upgrades**
- Buy iron pickaxe (25,000) → faster mining
- Buy iron axe (25,000) → faster tree harvesting
- Set up cobblestone generator → infinite mining
- **Income**: 2,800,000/hour mining

**Hour 3-4: Farming Expansion**
- Buy beetroot seeds (800 for 16) → better crop income
- Buy 2-4 more oak saplings → 8-10 tree farm
- **Income**: ~6,000/hour from beetroots, ~200,000/hour from trees

**Hour 4-5: First Major Purchase**
- Option A: Save for cobblestone minion (250,000)
- Option B: Upgrade to potato farm (4,000 for seeds)
- **Net assets**: 300,000-500,000 coins

**Key Milestone**: First automation or high-tier farming

### Phase 3: Mid Game (Hours 5-15) - Scaling Operations
**Hour 5-10: Diversification**
- Expand potato farm → 70,000/hour farming income
- Maintain oak tree farm → 200,000/hour
- Mining sessions → 2,800,000/hour (when active)
- **Combined income**: 3,000,000+/hour active

**Hour 10-15: First Automation**
- Buy cobblestone minion (250,000) → 48,000/hour passive
- Upgrade minion to level 2-3 → ~65,000/hour passive
- Buy carrot seeds → 350,000/hour farming (if active)
- **Net assets**: 1,000,000-2,000,000 coins

**Key Milestone**: First passive income source established

### Phase 4: Late Game (Hours 15-30) - Optimization
**Hour 15-20: Multiple Income Streams**
- Carrot farming (active) → 350,000/hour
- Spruce tree farm → 400,000/hour (if upgraded saplings)
- Cobblestone minion (passive) → 65,000/hour
- Mining (when needed) → 2,800,000/hour
- **Net assets**: 5,000,000+ coins

**Hour 20-30: Premium Automation**
- Buy coal minion (500,000) → +62,000/hour passive
- Upgrade to birch/jungle trees → 800,000-1,600,000/hour
- Build base (construction projects create money sink)
- **Net assets**: 10,000,000-20,000,000 coins

**Key Milestone**: Multiple minions, premium tree farms, large construction projects

### Phase 5: End Game (Hours 30+) - Mastery
**Goals:**
- Acacia tree farms → 6,400,000/hour
- Multiple max-level minions → 300,000+/hour passive
- Premium decoration builds → Multi-million coin projects
- Beacon acquisition → 1,000,000 coin status symbol

**Net assets**: 50,000,000+ coins

---

## INCOME ANALYSIS

### Income Tiers by Activity (Active Play)

#### Tier 1: Early Farming (Hours 0-3)
| Activity | Income/Hour | Investment | Effort | Scalability |
|----------|-------------|------------|--------|-------------|
| Wheat Farming (30 plants) | 160 | 300 | Low | Limited |
| Oak Tree Farm (4 trees) | 80,000 | 0 (free) | Medium | Good |
| Mining (Copper Pick) | 2,000,000 | 0 (free) | High | Unlimited |

**Best Strategy**: Focus on mining with free copper pickaxe → fastest income

#### Tier 2: Mid-Game Farming (Hours 3-10)
| Activity | Income/Hour | Investment | Effort | Scalability |
|----------|-------------|------------|--------|-------------|
| Beetroot Farm (30 plants) | 6,240 | 1,500 | Low | Limited |
| Potato Farm (30 plants) | 69,900 | 7,500 | Low | Good |
| Oak Tree Farm (10 trees) | 200,000 | 100,000 | Medium | Good |
| Mining (Iron Pick) | 2,800,000 | 25,000 | High | Unlimited |

**Best Strategy**: Mix of potato farming (low effort, good income) + mining sessions (high income bursts)

#### Tier 3: Late-Game Farming (Hours 10-30)
| Activity | Income/Hour | Investment | Effort | Scalability |
|----------|-------------|------------|--------|-------------|
| Carrot Farm (30 plants) | 349,500 | 37,500 | Low | Good |
| Spruce Trees (10 trees) | 400,000 | 200,000 | Medium | Good |
| Birch Trees (10 trees) | 800,000 | 400,000 | Medium | Excellent |
| Jungle Trees (10 trees) | 1,600,000 | 800,000 | Medium | Excellent |
| Mining (Iron Pick) | 2,800,000 | 25,000 | High | Unlimited |

**Best Strategy**: Premium tree farms (best income/effort ratio) + mining (highest raw income)

#### Tier 4: End-Game Farming (Hours 30+)
| Activity | Income/Hour | Investment | Effort | Scalability |
|----------|-------------|------------|--------|-------------|
| Dark Oak Trees (10 trees) | 3,200,000 | 1,600,000 | Medium | Excellent |
| Acacia Trees (10 trees) | 6,400,000 | 3,200,000 | Medium | Excellent |
| Mining (Steel Pick) | 3,600,000 | High | High | Unlimited |

**Best Strategy**: Acacia tree farms (highest active income) + passive minion income

### Passive Income (Automation)
| Source | Cost | Income/Hour | ROI Period | Max Potential |
|--------|------|-------------|------------|---------------|
| Cobblestone Minion Lv1 | 250,000 | 48,000 | 5.2 hours | - |
| Cobblestone Minion Lv4 | +upgrades | 70,000 | 3.6 hours | - |
| Coal Minion Lv1 | 500,000 | 62,400 | 8.0 hours | - |
| Coal Minion Lv4 | +upgrades | 78,000 | 6.4 hours | - |
| Multiple Minions | Millions | 300,000+ | Variable | Sky's the limit |

**ROI Analysis**: Minions have 5-8 hour payback periods. Only invest after establishing strong active income.

### Income Comparison by Game Stage
| Hours Played | Primary Income | Income/Hour | Net Worth |
|--------------|----------------|-------------|-----------|
| 0-2 | Starter trees + mining | ~500,000 | 100,000 |
| 2-5 | Mining + oak trees | ~2,000,000 | 500,000 |
| 5-10 | Mining + potato farm | ~2,500,000 | 2,000,000 |
| 10-20 | Spruce trees + carrots | ~750,000 | 10,000,000 |
| 20-30 | Birch/Jungle trees + minions | ~1,500,000 | 30,000,000 |
| 30+ | Acacia trees + multiple minions | ~6,500,000 | 100,000,000+ |

**Key Insight**: Mining dominates early-mid game income (hours 0-10), then premium tree farming takes over in late game.

---

## PRICING PHILOSOPHY

### Design Principles Applied

#### 1. Building Blocks Sold in Stacks ✓
- All basic building blocks (cobblestone, dirt, stone, sand) priced per 64-stack
- Makes large construction projects easier to plan and purchase
- Example: 10×10 house = ~240,000 coins (clear, intuitive cost)

#### 2. Utility Blocks Are Expensive ✓
- Crafting Table: 10,000 (but 1 free in starter kit)
- Furnace: 15,000
- Chest: 20,000
- Resale value: 30% (strong money sink)
- Players commit to purchases, can't flip for profit

#### 3. Farming Resources Cheap, Low Margins ✓
- Wheat seeds: 10 coins (extremely affordable)
- Beetroot seeds: 50 coins (5x progression)
- Sell margins: 60% for crops (better than other categories)
- Volume-based income (need large farms or many harvests)

#### 4. Tools Expensive but Necessary ✓
- Copper tools: 5,000 (starter tier, included free)
- Iron tools: 25,000 (significant mid-game investment)
- Diamond tools: 80,000+ (luxury late-game)
- 40% resale prevents tool flipping

#### 5. No Arbitrage ✓
- All items sell for 30-60% of buy price
- Raw farmables: 50-60% (best margins, rewards farming)
- Processed/utilities: 30-45% (convenience tax)
- Prevents buy-low-sell-high exploits
- Encourages production over trading

### Economic Balance

#### Money Sources (Inflows)
1. **Farming crops** - Low but steady, scales with farm size
2. **Growing trees** - Medium income, 2.5 min cycles
3. **Mining cobblestone** - Highest active income (2-3M/hour)
4. **Ore drops** - Bonus income from mining (10% boost)
5. **Passive minions** - Late-game automation (requires investment)

#### Money Sinks (Outflows)
1. **Tools & equipment** - Necessary for efficiency (25,000-80,000)
2. **Seeds & saplings** - Required for farming expansion (10-320,000)
3. **Utility blocks** - Essential for progression (10,000-25,000 each)
4. **Building blocks** - Large construction (millions for big builds)
5. **Decorative blocks** - Aesthetic customization (pure sinks, 10% resale)
6. **Automation** - Minions (250,000-500,000 each)
7. **Premium items** - Beacons, end stone, etc. (100,000-1,000,000)

#### Inflation Controls
1. **Long ROI periods** - Minions take 5-8 hours to pay back
2. **Construction costs** - Large builds require sustained farming
3. **Tool upgrades** - Continuous small purchases
4. **Low resale values** - Money lost on all transactions
5. **Premium decoratives** - Million-coin status symbols

### Player Psychology

#### Progression Feel
- **Hour 1**: "I made my first 10 coins from wheat!"
- **Hour 5**: "I bought my first iron pickaxe!"
- **Hour 10**: "I'm making 100,000/hour from potatoes!"
- **Hour 20**: "I unlocked my first minion!"
- **Hour 40**: "I'm building a castle with premium blocks!"

#### Dopamine Loops
1. **Plant → Wait → Harvest** (crops: 7-13 min)
2. **Plant → Wait → Chop** (trees: 2.5 min)
3. **Mine → Sell → Upgrade** (immediate, high volume)
4. **Save → Buy → Unlock** (tools, minions, construction)

#### Long-Term Goals
- Build dream base (multi-million coin projects)
- Max-level minion army (passive income empire)
- Acacia tree farm (ultimate farming achievement)
- Beacon ownership (status symbol)
- Premium decoration collection (aesthetic mastery)

---

## CONCLUSION

### Economy Summary
This economy creates a **slow-burn progression** where players:
1. Start with basic tools and resources (70,000 coin value)
2. Learn farming mechanics with low-risk crops (wheat: 10 coins)
3. Progress through increasingly profitable crops (carrots: 750 coins)
4. Unlock tree farming for medium income (oak: 5,000/log)
5. Discover mining for highest active income (2-3M/hour)
6. Invest in automation for passive income (minions: 48-78k/hour)
7. Build elaborate bases as long-term projects (millions of coins)
8. Pursue premium aesthetics and status symbols (beacons: 1M coins)

### Key Differentiators from Minecraft
1. **All trees drop 6 logs** (no variation by type)
2. **Stack-based building block pricing** (64-unit purchases)
3. **Mining is king** (highest income activity by far)
4. **Utility blocks are money sinks** (poor resale value)
5. **No crafting advantage** (planks = same value as logs)
6. **Minions over generators** (active automation, not passive)
7. **Starting gear included** (tools provided, not earned)

### Recommended Playstyle
**Hours 0-5**: Mine cobblestone (2-3M/hour) → fastest early income
**Hours 5-15**: Mix mining + oak/spruce trees (200-400k/hour) → more engaging
**Hours 15-30**: Premium tree farms (800k-1.6M/hour) + first minions
**Hours 30+**: Acacia farms (6.4M/hour) + minion army + construction projects

This creates a **30-50 hour progression** to reach true end-game automation and wealth, with satisfying milestones every 5-10 hours.

---

**Document Version**: 1.0
**Based on Game Version**: Bootstrap v80 / NPCTradeConfig scaled 100x
**Last Updated**: January 29, 2026
