# Product Requirements Document: Tools System
## Skyblox - Mining, Durability & Tool Mechanics

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Core Gameplay)
> **Estimated Effort**: Large (6-8 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Tools System enables players to efficiently mine blocks, chop wood, dig dirt, and fight mobs using tiered tools (pickaxes, axes, shovels, swords). This PRD defines durability mechanics, mining speed calculations, tool effectiveness by block type, and integration with the block breaking system. Tools are essential for progression and resource gathering.

### Why This Matters
- **Core Gameplay**: Tools are the primary way players interact with the world
- **Progression Gate**: Better tools unlock access to better resources
- **Resource Gathering**: Mining speed and efficiency depend on tool quality
- **Combat**: Swords are primary melee weapons
- **Minecraft Parity**: Tool mechanics must match Minecraft for authentic experience

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
| Tool Definitions | `ItemDefinitions.lua` → Tools section | ✅ All tools defined |
| Tool IDs | `Constants.lua` | ✅ Tool IDs assigned (1001-1099) |
| Tool Textures | `ItemDefinitions.lua` | ✅ All textures available |
| Tool Tiers | `ItemDefinitions.lua` → Tiers | ✅ 6 tiers defined |
| Tool Types | `ItemDefinitions.lua` | ✅ pickaxe, axe, shovel, sword, bow |
| Block Breaking | `VoxelWorldService` | ✅ Basic breaking exists |
| Block Hardness | `BlockProperties.lua` | ✅ Hardness values defined |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Durability System | Tool wear and breaking | P0 |
| Mining Speed Calculation | Tool effectiveness | P0 |
| Tool Effectiveness by Block | Correct tool for correct block | P0 |
| Durability UI | Show tool condition | P0 |
| Tool Breaking Animation | Visual feedback when tool breaks | P0 |
| Mining Speed Multipliers | Faster mining with better tools | P0 |
| Tool Requirements | Tier requirements for blocks | P0 |
| Tool Damage Values | Sword damage, tool attack damage | P0 |
| Tool Enchantments | Future: efficiency, unbreaking, etc. | P2 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                      TOOL USAGE FLOW                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. Player equips tool (pickaxe, axe, shovel, sword)          │
│                    ↓                                            │
│   2. Player interacts with block/mob                            │
│      - Mining: Left-click block                                │
│      - Combat: Left-click mob                                 │
│                    ↓                                            │
│   3. Tool effectiveness calculated:                            │
│      - Is tool correct type? (pickaxe for stone)                │
│      - Is tool tier sufficient? (iron for iron ore)            │
│      - Mining speed = base / toolMultiplier                     │
│                    ↓                                            │
│   4. Block breaks / Mob takes damage                            │
│                    ↓                                            │
│   5. Tool durability decreases (1 point per use)               │
│                    ↓                                            │
│   6. If durability reaches 0: Tool breaks (removed)            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Minecraft Parity** - Durability, mining speed, and effectiveness match Minecraft exactly
2. **Clear Progression** - Each tier significantly improves efficiency
3. **Tool Specialization** - Right tool for the right job matters
4. **Visual Feedback** - Clear indication of tool condition and effectiveness

---

## Detailed Requirements

### FR-1: Durability System

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Each tool has maximum durability based on tier | P0 |
| FR-1.2 | Durability decreases by 1 per block broken | P0 |
| FR-1.3 | Durability decreases by 2 per mob hit (swords) | P0 |
| FR-1.4 | Tool breaks when durability reaches 0 | P0 |
| FR-1.5 | Broken tool is removed from inventory | P0 |
| FR-1.6 | Durability persists across sessions | P0 |
| FR-1.7 | Durability displayed in tooltip/UI | P0 |

### FR-2: Mining Speed & Effectiveness

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Mining speed calculated based on tool tier | P0 |
| FR-2.2 | Correct tool type provides speed multiplier | P0 |
| FR-2.3 | Wrong tool type provides no speed bonus | P0 |
| FR-2.4 | Tool tier must meet block's minToolTier requirement | P0 |
| FR-2.5 | Insufficient tier: block takes 5x longer to break | P0 |
| FR-2.6 | Hand mining (no tool) uses base speed | P0 |

### FR-3: Tool Types & Specialization

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Pickaxe: Effective on stone, ores, mineral blocks | P0 |
| FR-3.2 | Axe: Effective on wood, logs, planks, leaves | P0 |
| FR-3.3 | Shovel: Effective on dirt, sand, gravel, grass | P0 |
| FR-3.4 | Sword: Effective on mobs, webs, bamboo | P0 |
| FR-3.5 | Wrong tool type: No speed bonus, still works | P0 |
| FR-3.6 | Hand: Works on all blocks, slow speed | P0 |

### FR-4: Tool Damage (Combat)

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Sword damage based on tier | P0 |
| FR-4.2 | Tool attack speed: 1.6 attacks/second | P0 |
| FR-4.3 | Critical hits: 1.5x damage when falling | P0 |
| FR-4.4 | Tool durability decreases on hit (2 points) | P0 |
| FR-4.5 | Tool can break during combat | P0 |

### FR-5: Tool Breaking & Feedback

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Tool breaking sound effect plays | P0 |
| FR-5.2 | Tool breaking animation/particle effect | P1 |
| FR-5.3 | Warning when durability < 10% | P1 |
| FR-5.4 | Tool removed from hotbar if equipped | P0 |
| FR-5.5 | Message to player when tool breaks | P1 |

---

## Minecraft Behavior Reference

### Tool Durability (Maximum)

| Tool Type | Wood | Stone | Iron | Diamond | Netherite |
|-----------|------|-------|------|---------|-----------|
| Pickaxe | 59 | 131 | 250 | 1561 | 2031 |
| Axe | 59 | 131 | 250 | 1561 | 2031 |
| Shovel | 59 | 131 | 250 | 1561 | 2031 |
| Sword | 59 | 131 | 250 | 1561 | 2031 |

**Note**: Our game uses custom tiers (Copper, Iron, Steel, Bluesteel, Tungsten, Titanium). Map these to approximate Minecraft tiers:
- Copper ≈ Wood/Stone
- Iron = Iron
- Steel ≈ Diamond
- Bluesteel ≈ Diamond+
- Tungsten ≈ Netherite
- Titanium ≈ Netherite+

### Mining Speed Multipliers

| Tool Tier | Speed Multiplier | Equivalent Minecraft |
|-----------|------------------|---------------------|
| Hand | 1.0x | Hand |
| Copper | 2.0x | Wood/Stone |
| Iron | 4.0x | Iron |
| Steel | 6.0x | Diamond |
| Bluesteel | 7.0x | Diamond+ |
| Tungsten | 8.0x | Netherite |
| Titanium | 10.0x | Netherite+ |

### Tool Effectiveness by Block Type

**Pickaxe Effective:**
- Stone, Cobblestone, Stone Bricks
- All ores (Coal, Iron, Copper, etc.)
- Mineral blocks (Iron Block, Gold Block, etc.)
- Furnace, Anvil

**Axe Effective:**
- All wood types (Oak, Spruce, etc.)
- Logs, Planks
- Fences, Gates
- Crafting Table

**Shovel Effective:**
- Dirt, Grass, Coarse Dirt
- Sand, Gravel
- Clay, Podzol
- Farmland

**Sword Effective:**
- Mobs (all types)
- Cobwebs
- Bamboo
- Hay Bales

### Mining Speed Formula

```
baseBreakTime = blockHardness * 1.5

if toolType == correctType:
    breakTime = baseBreakTime / toolSpeedMultiplier
else:
    breakTime = baseBreakTime * 1.0  // No bonus

if toolTier < block.minToolTier:
    breakTime = breakTime * 5.0  // 5x slower
```

### Tool Damage Values

| Tool Type | Base Damage | Tier Multiplier |
|-----------|-------------|-----------------|
| Hand | 1 | - |
| Sword | 4 | +1 per tier |
| Pickaxe | 2 | +0.5 per tier (when used as weapon) |
| Axe | 3 | +1 per tier (when used as weapon) |
| Shovel | 1.5 | +0.5 per tier (when used as weapon) |

**Example**: Iron Sword (Tier 2) = 4 + 2 = 6 damage

---

## Technical Specifications

### Tool Configuration

```lua
-- ToolConfig.lua (extend existing)
local ToolConfig = {}

-- Durability by tier
ToolConfig.Durability = {
    [1] = 59,   -- Copper (Wood/Stone equivalent)
    [2] = 250,  -- Iron
    [3] = 1561, -- Steel (Diamond equivalent)
    [4] = 1800, -- Bluesteel
    [5] = 2031, -- Tungsten (Netherite equivalent)
    [6] = 2500, -- Titanium
}

-- Mining speed multipliers
ToolConfig.MiningSpeed = {
    [0] = 1.0,  -- Hand
    [1] = 2.0,  -- Copper
    [2] = 4.0,  -- Iron
    [3] = 6.0,  -- Steel
    [4] = 7.0,  -- Bluesteel
    [5] = 8.0,  -- Tungsten
    [6] = 10.0, -- Titanium
}

-- Tool effectiveness by block type
ToolConfig.BlockEffectiveness = {
    pickaxe = {
        [Constants.BlockType.STONE] = true,
        [Constants.BlockType.COBBLESTONE] = true,
        [Constants.BlockType.COAL_ORE] = true,
        [Constants.BlockType.IRON_ORE] = true,
        -- ... all stone/ore blocks
    },
    axe = {
        [Constants.BlockType.WOOD] = true,
        [Constants.BlockType.OAK_PLANKS] = true,
        -- ... all wood blocks
    },
    shovel = {
        [Constants.BlockType.DIRT] = true,
        [Constants.BlockType.GRASS] = true,
        [Constants.BlockType.SAND] = true,
        -- ... all dirt/sand blocks
    },
    sword = {
        -- Mobs (handled separately)
        [Constants.BlockType.COBWEB] = true,
    }
}

-- Tool damage values
ToolConfig.Damage = {
    sword = {
        base = 4,
        perTier = 1
    },
    axe = {
        base = 3,
        perTier = 1
    },
    pickaxe = {
        base = 2,
        perTier = 0.5
    },
    shovel = {
        base = 1.5,
        perTier = 0.5
    }
}

return ToolConfig
```

### Durability Management

```lua
-- ToolService.lua
local ToolService = {}

function ToolService:GetToolDurability(player, toolId)
    local toolData = player:GetToolData(toolId)
    return toolData and toolData.durability or nil
end

function ToolService:SetToolDurability(player, toolId, durability)
    local toolData = player:GetToolData(toolId)
    if toolData then
        toolData.durability = math.max(0, durability)

        if toolData.durability == 0 then
            self:BreakTool(player, toolId)
        end
    end
end

function ToolService:DecreaseDurability(player, toolId, amount)
    amount = amount or 1
    local current = self:GetToolDurability(player, toolId)
    if current then
        self:SetToolDurability(player, toolId, current - amount)
    end
end

function ToolService:BreakTool(player, toolId)
    -- Remove tool from inventory
    player:RemoveItem(toolId, 1)

    -- If tool was equipped, unequip it
    if player:GetEquippedTool() == toolId then
        player:UnequipTool()
    end

    -- Notify client
    EventManager:FireEventToPlayer(player, "ToolBroke", {toolId = toolId})
end
```

### Mining Speed Calculation

```lua
function ToolService:CalculateMiningSpeed(player, blockId, toolId)
    local blockProperties = BlockProperties:Get(blockId)
    local baseBreakTime = blockProperties.hardness * 1.5

    if not toolId then
        -- Hand mining
        return baseBreakTime
    end

    local toolDef = ItemDefinitions.Tools[toolId] or ItemDefinitions.GetById(toolId)
    if not toolDef then
        return baseBreakTime
    end

    local toolType = toolDef.toolType
    local toolTier = toolDef.tier or 0
    local speedMultiplier = ToolConfig.MiningSpeed[toolTier] or 1.0

    -- Check if tool is effective for this block
    local isEffective = ToolConfig.BlockEffectiveness[toolType] and
                        ToolConfig.BlockEffectiveness[toolType][blockId]

    if isEffective then
        baseBreakTime = baseBreakTime / speedMultiplier
    end

    -- Check tier requirement
    if blockProperties.minToolTier and toolTier < blockProperties.minToolTier then
        baseBreakTime = baseBreakTime * 5.0  -- 5x slower
    end

    return baseBreakTime
end
```

---

## UI/UX Design

### Tool Durability Display

**In Tooltip:**
```
┌─────────────────────────────┐
│  Iron Pickaxe               │
│  Durability: ████████░░ 80% │
│  (200/250)                  │
└─────────────────────────────┘
```

**In Hotbar:**
- Durability bar below tool icon
- Color coding:
  - Green: 100-50%
  - Yellow: 50-25%
  - Orange: 25-10%
  - Red: <10%

### Tool Breaking Warning

When durability < 10%:
- Tool icon flashes red
- Warning message: "Your [Tool Name] is about to break!"
- Sound effect: Low durability warning

### Mining Speed Indicator

Optional: Show mining progress bar when breaking blocks
- Progress bar fills as block is being broken
- Faster with better tools
- Visual feedback for tool effectiveness

---

## Technical Architecture

### New Files Required

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── ToolService.lua              # NEW: Tool durability & effectiveness
│
├── StarterPlayerScripts/Client/
│   └── UI/
│       └── ToolDurabilityBar.lua       # NEW: Durability display
│
└── ReplicatedStorage/
    └── Configs/
        └── ToolConfig.lua              # MODIFY: Add durability, speed configs
```

### Modified Files

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── VoxelWorldService.lua       # MODIFY: Use ToolService for mining speed
│       └── CombatService.lua           # MODIFY: Use ToolService for tool damage
│       └── PlayerInventoryService.lua  # MODIFY: Store tool durability
│
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── BlockBreakingController.lua # MODIFY: Show mining progress
│
└── ReplicatedStorage/
    └── Configs/
        └── ItemDefinitions.lua         # MODIFY: Add durability to tool definitions
```

### Event Flow

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLIENT    │      │   SERVER    │      │   CLIENT    │
│BlockBreaking│      │ ToolService │      │DurabilityBar │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                     │                    │
       │ Start breaking block│                    │
       │────────────────────>│                    │
       │                     │                    │
       │                     │ Calculate speed    │
       │                     │ Check durability   │
       │                     │                    │
       │<────────────────────│ MiningSpeed        │
       │                     │                    │
       │ [Show progress bar] │                    │
       │                     │                    │
       │ Block broken        │                    │
       │────────────────────>│                    │
       │                     │                    │
       │                     │ Decrease durability│
       │                     │ Check if broken    │
       │                     │                    │
       │<────────────────────│ DurabilityUpdate   │
       │                     │                    │
       │                     │───────────────────>│ UpdateDurabilityBar
       │                     │                    │
```

---

## Implementation Plan

### Phase 1: Durability System (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `ToolConfig.lua` | Add durability values by tier |
| 1.2 | `ItemDefinitions.lua` | Add maxDurability to tool definitions |
| 1.3 | `PlayerInventoryService.lua` | Store tool durability in item data |
| 1.4 | `ToolService.lua` | Create durability management service |
| 1.5 | `ToolService.lua` | Implement durability decrease logic |
| 1.6 | `ToolService.lua` | Implement tool breaking logic |

### Phase 2: Mining Speed (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `ToolConfig.lua` | Add mining speed multipliers |
| 2.2 | `ToolConfig.lua` | Add block effectiveness mappings |
| 2.3 | `ToolService.lua` | Implement mining speed calculation |
| 2.4 | `VoxelWorldService.lua` | Integrate ToolService for block breaking |
| 2.5 | `BlockBreakingController.lua` | Show mining progress with speed |

### Phase 3: Tool Effectiveness (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `ToolConfig.lua` | Complete block effectiveness mappings |
| 3.2 | `ToolService.lua` | Check tool type vs block type |
| 3.3 | `ToolService.lua` | Check tool tier requirements |
| 3.4 | `VoxelWorldService.lua` | Apply 5x penalty for insufficient tier |

### Phase 4: Tool Damage (Day 4-5)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `ToolConfig.lua` | Add tool damage values |
| 4.2 | `CombatService.lua` | Use ToolService for weapon damage |
| 4.3 | `CombatService.lua` | Apply tier-based damage multipliers |
| 4.4 | `ToolService.lua` | Decrease durability on combat hit (2 points) |

### Phase 5: UI & Feedback (Day 5-6)

| Task | File | Description |
|------|------|-------------|
| 5.1 | `ToolDurabilityBar.lua` | Create durability bar component |
| 5.2 | `ToolDurabilityBar.lua` | Display in tooltip and hotbar |
| 5.3 | `ToolService.lua` | Add breaking sound effects |
| 5.4 | `ToolService.lua` | Add low durability warnings |
| 5.5 | `ToolService.lua` | Add tool breaking animation |

### Phase 6: Testing & Polish (Day 6-8)

| Task | File | Description |
|------|------|-------------|
| 6.1 | Testing | Test all tool types |
| 6.2 | Testing | Test durability across all tiers |
| 6.3 | Testing | Test mining speed calculations |
| 6.4 | Testing | Test tool breaking |
| 6.5 | Testing | Test combat damage |

---

## Future Enhancements

### v1.1: Tool Repair
- [ ] Anvil repair system
- [ ] Repair with materials
- [ ] Repair cost calculation

### v1.2: Tool Enchantments
- [ ] Efficiency (mining speed)
- [ ] Unbreaking (durability)
- [ ] Fortune (more drops)
- [ ] Silk Touch (block drops itself)

### v1.3: Tool Crafting
- [ ] Tool crafting recipes
- [ ] Tool upgrade paths
- [ ] Tool combination (repair with same tool)

### v1.4: Advanced Tools
- [ ] Fishing rod
- [ ] Shears
- [ ] Hoe (for farming)
- [ ] Trident (ranged weapon)

---

## Appendix A: Tool Durability Reference

| Tool | Copper | Iron | Steel | Bluesteel | Tungsten | Titanium |
|------|--------|------|-------|-----------|----------|----------|
| Pickaxe | 59 | 250 | 1561 | 1800 | 2031 | 2500 |
| Axe | 59 | 250 | 1561 | 1800 | 2031 | 2500 |
| Shovel | 59 | 250 | 1561 | 1800 | 2031 | 2500 |
| Sword | 59 | 250 | 1561 | 1800 | 2031 | 2500 |

---

## Appendix B: Mining Speed Reference

| Block Type | Hand | Copper | Iron | Steel | Bluesteel | Tungsten | Titanium |
|------------|------|--------|------|-------|-----------|----------|----------|
| Dirt (Shovel) | 0.75s | 0.38s | 0.19s | 0.13s | 0.11s | 0.09s | 0.08s |
| Stone (Pickaxe) | 7.5s | 3.75s | 1.88s | 1.25s | 1.07s | 0.94s | 0.75s |
| Wood (Axe) | 3.0s | 1.5s | 0.75s | 0.5s | 0.43s | 0.38s | 0.3s |
| Iron Ore (Pickaxe) | 15s | 7.5s | 3.75s | 2.5s | 2.14s | 1.88s | 1.5s |

*Note: Times assume correct tool type. Wrong tool = no speed bonus.*

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_ARMOR_SYSTEM.md](./PRD_ARMOR_SYSTEM.md), [PRD_FURNACE.md](../PRD_FURNACE.md)*
