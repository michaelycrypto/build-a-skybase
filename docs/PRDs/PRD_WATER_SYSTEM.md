# Product Requirements Document: Water System
## Skyblox - Minecraft Water Dynamics & EditableMesh Rendering

> **Status**: Ready for Implementation  
> **Priority**: P0 (Critical - Core Gameplay)  
> **Estimated Effort**: Large (8-10 days)  
> **Last Updated**: January 2026

---

## Executive Summary

This PRD defines the complete water system for Skyblox, implementing Minecraft-accurate water flow dynamics and rendering using Roblox's EditableMesh API. The existing system requires significant cleanup and redesign to properly match Minecraft behavior for water spreading, source block mechanics, and visual rendering.

### Why This Matters
- **Core World Interaction**: Water is essential for farming, decoration, and world-building
- **Minecraft Parity**: Players expect water to behave exactly like Minecraft
- **Visual Quality**: EditableMesh enables smooth, flowing water surfaces
- **Performance**: Proper implementation avoids excessive updates and rendering overhead

### Current State Issues
1. **8-directional spread is wrong** - Minecraft uses 4-directional cardinal spread, not 8
2. **Downhill pathfinding is incorrect** - Should use BFS to find shortest path to drop-off
3. **Water level calculation is incorrect** - Uses min() rule incorrectly
4. **Falling water behavior has bugs** - Fall distance tracking is inconsistent
5. **Chunk boundary handling is unreliable** - Cross-chunk water flow fails
6. **No entity interaction** - Players/mobs should be pushed by water currents

---

## Table of Contents

1. [Current State & Gap Analysis](#current-state--gap-analysis)
2. [Minecraft Water Mechanics Reference](#minecraft-water-mechanics-reference)
3. [Detailed Requirements](#detailed-requirements)
4. [Technical Specifications](#technical-specifications)
5. [EditableMesh Rendering](#editablemesh-rendering)
6. [Technical Architecture](#technical-architecture)
7. [Implementation Plan](#implementation-plan)
8. [Future Enhancements](#future-enhancements)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Block Types | `Constants.lua` | ✅ WATER_SOURCE (380), FLOWING_WATER (381) |
| Water Service | `WaterService.lua` | ⚠️ Exists but has bugs |
| Water Mesher | `WaterMesher.lua` | ⚠️ Exists but rendering is incorrect |
| Water Utils | `WaterUtils.lua` | ⚠️ Exists but formulas are wrong |
| Water Config | `GameConfig.lua` | ✅ InfiniteWaterSource toggle |
| Metadata System | `Constants.lua` | ✅ Depth + falling flag encoding |

### What's Wrong ❌

| Issue | Current Behavior | Correct Behavior | Priority |
|-------|------------------|------------------|----------|
| Spread Direction | 8-directional (cardinal + diagonal) | 4-directional (cardinal only) | P0 |
| Depth Calculation | Increments per any step | Increments per horizontal step only | P0 |
| Downhill Flow | BFS includes diagonals | BFS uses cardinals only | P0 |
| Water Level Height | Complex corner interpolation | Simple level-based height (8 levels) | P0 |
| Falling Reset | Depth resets to 0 | Depth stays 0 for entire fall column | P0 |
| Source Conversion | 2 adjacent sources | 2 adjacent sources + solid below | P0 |
| Entity Currents | Not implemented | Push entities in flow direction | P1 |
| Swimming | Not implemented | Player swims when inside water | P1 |
| Underwater Vision | Not implemented | Blue tint, reduced visibility | P2 |

### Files to Modify/Replace

```
src/
├── ServerScriptService/Server/Services/
│   └── WaterService.lua              # REWRITE: Fix spread algorithm
│
├── ReplicatedStorage/Shared/VoxelWorld/
│   ├── Rendering/
│   │   └── WaterMesher.lua           # REWRITE: Fix height calculation
│   │
│   └── World/
│       └── WaterUtils.lua            # MODIFY: Fix metadata helpers
│
└── ReplicatedStorage/Configs/
    └── GameConfig.lua                # MODIFY: Add water config options
```

---

## Minecraft Water Mechanics Reference

### Water Block Types

```
┌─────────────────────────────────────────────────────────────────┐
│                     MINECRAFT WATER TYPES                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SOURCE BLOCK (Level 0)                                         │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 8/8 height                                    │
│  - Placed by player or generated                                │
│  - Never decays                                                 │
│  - Can create infinite water with 2+ adjacent sources           │
│                                                                 │
│  FLOWING WATER (Level 1-7)                                      │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓   7/8 height (level 1)                          │
│  ▓▓▓▓▓▓▓▓▓▓▓▓     6/8 height (level 2)                          │
│  ▓▓▓▓▓▓▓▓▓▓       5/8 height (level 3)                          │
│  ▓▓▓▓▓▓▓▓         4/8 height (level 4)                          │
│  ▓▓▓▓▓▓           3/8 height (level 5)                          │
│  ▓▓▓▓             2/8 height (level 6)                          │
│  ▓▓               1/8 height (level 7)                          │
│  - Created by spreading from sources                            │
│  - Decays when source is removed                                │
│                                                                 │
│  FALLING WATER (Level 8 / Flag)                                 │
│  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ 8/8 height (full column)                      │
│  - Created when water flows down                                │
│  - Always renders at full height                                │
│  - Has falling flag set in metadata                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Water Level Metadata

```
Metadata byte: 0bFDDDLLLL
  - LLLL (bits 0-3): Water level (0-15, but 0-7 used for water)
  - DDD (bits 4-6): Reserved (fall distance tracking, optional)
  - F (bit 7): Falling flag (1 = falling/has water above)

Level values:
  - 0: Source block (full)
  - 1-7: Flowing water (decreasing height)
  - 8+: Falling water (full height, level doesn't matter)

Falling flag:
  - Set when: block can flow down OR has water directly above
  - Purpose: Ensures waterfalls render at full height
```

### Water Spread Rules (CARDINAL ONLY)

```
┌─────────────────────────────────────────────────────────────────┐
│              MINECRAFT WATER SPREAD ALGORITHM                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: Check if can flow DOWN                                 │
│  ┌───┐                                                          │
│  │ S │  Source/Flowing water                                    │
│  └─┬─┘                                                          │
│    ↓   If air/replaceable below, flow down (priority 1)        │
│  ┌───┐                                                          │
│  │ F │  Falling water (level 8, full height)                    │
│  └───┘                                                          │
│                                                                 │
│  STEP 2: If cannot flow down, spread HORIZONTALLY               │
│  ┌───────────────┐                                              │
│  │     [2]       │  North (-Z)                                  │
│  │      ↑        │                                              │
│  │ [2]←[S]→[2]   │  West (-X) ← Source → East (+X)              │
│  │      ↓        │                                              │
│  │     [2]       │  South (+Z)                                  │
│  └───────────────┘                                              │
│                                                                 │
│  STEP 3: Downhill pathfinding (BFS)                            │
│  - Search CARDINAL directions only (not diagonal!)              │
│  - Find shortest path to nearest drop-off (hole)                │
│  - Water prefers flowing toward edges                           │
│  - If multiple paths equal length, flow all directions         │
│                                                                 │
│  STEP 4: Increment level per horizontal step                    │
│  ┌───────────────────────────────┐                              │
│  │ [S] → [1] → [2] → [3] → ...   │  Level increases each step  │
│  │ L0    L1    L2    L3          │  Until level 7 (then stops) │
│  └───────────────────────────────┘                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### IMPORTANT: NO Diagonal Spread

```
┌─────────────────────────────────────────────────────────────────┐
│                    ❌ WRONG (Current)                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│     [2]   [2]   [2]                                             │
│       ↖   ↑   ↗                                                 │
│     [2] ← S → [2]      8-directional spread                    │
│       ↙   ↓   ↘                                                 │
│     [2]   [2]   [2]                                             │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                    ✅ CORRECT (Minecraft)                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│           [1]                                                   │
│            ↑                                                    │
│     [1] ← [S] → [1]    4-directional spread (cardinal only)    │
│            ↓                                                    │
│           [1]                                                   │
│                                                                 │
│  Diagonal corners fill from two perpendicular flows:            │
│                                                                 │
│           [1]                                                   │
│          ↓   ↓                                                  │
│     [1] → [2] ←        Diagonal position gets water from       │
│                        orthogonal neighbors, NOT from source    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Infinite Water Source

```
┌─────────────────────────────────────────────────────────────────┐
│                  INFINITE WATER SOURCE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Requirements:                                                  │
│  1. Flowing water block (level 1-7)                             │
│  2. At least 2 adjacent source blocks (horizontal)              │
│  3. Solid block or source block below                           │
│                                                                 │
│  Example:                                                       │
│  ┌───┬───┬───┐                                                  │
│  │ S │ 1 │ S │  ← Flowing water [1] has 2 adjacent sources     │
│  └───┴───┴───┘                                                  │
│  ████████████   ← Solid block below                             │
│                                                                 │
│  Result: [1] converts to [S] (new source block)                 │
│                                                                 │
│  Counter-example (NO conversion):                               │
│  ┌───┬───┬───┐                                                  │
│  │ S │ 1 │ S │  ← Has 2 adjacent sources                        │
│  └───┴───┴───┘                                                  │
│      [AIR]      ← Air below = NO conversion!                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Falling Water Column

```
┌─────────────────────────────────────────────────────────────────┐
│                   FALLING WATER BEHAVIOR                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  When water flows down, it creates a column of falling water:   │
│                                                                 │
│  ┌───┐                                                          │
│  │ S │  Source block                                            │
│  ├───┤                                                          │
│  │ F │  Falling (level 0, flag set, full height)                │
│  ├───┤                                                          │
│  │ F │  Falling (level 0, flag set, full height)                │
│  ├───┤                                                          │
│  │ F │  Falling (level 0, flag set, full height)                │
│  └───┘                                                          │
│  █████  Solid ground                                            │
│                                                                 │
│  The BOTTOM block of falling water:                             │
│  - Has solid below, so can't flow down                          │
│  - Has water above, so falling flag is STILL SET                │
│  - Renders at full height (looks correct)                       │
│  - CAN spread horizontally from this point                      │
│                                                                 │
│  After hitting ground:                                          │
│  ┌───┐                                                          │
│  │ F │  Falling water hits ground                               │
│  └─┬─┘                                                          │
│  ┌─┴─┬───┬───┬───┐                                              │
│  │ 1 │ 2 │ 3 │...│  Spreads horizontally from impact point     │
│  └───┴───┴───┴───┘                                              │
│  ████████████████   Solid ground                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Requirements

### FR-1: Water Spread Mechanics

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Water spreads in 4 cardinal directions only (N, E, S, W) | P0 |
| FR-1.2 | Water level increases by 1 per horizontal step | P0 |
| FR-1.3 | Water stops spreading at level 7 | P0 |
| FR-1.4 | Water flows down if air/replaceable below (priority 1) | P0 |
| FR-1.5 | Falling water has level 0 and falling flag set | P0 |
| FR-1.6 | Falling water renders at full block height | P0 |
| FR-1.7 | Water uses BFS to find shortest path to drop-off | P0 |
| FR-1.8 | BFS searches cardinal directions only | P0 |
| FR-1.9 | Water prefers flowing toward nearest edge/hole | P0 |
| FR-1.10 | If multiple equal paths, water flows all directions | P0 |

### FR-2: Source Block Mechanics

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Source blocks have level 0 (full height) | P0 |
| FR-2.2 | Source blocks never decay | P0 |
| FR-2.3 | Source blocks can be placed by players | P0 |
| FR-2.4 | Infinite water: 2+ adjacent sources + solid below | P0 |
| FR-2.5 | Infinite water is toggleable via GameConfig | P0 |
| FR-2.6 | Source conversion happens on tick update | P0 |

### FR-3: Flowing Water Mechanics

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Flowing water decays when disconnected from source | P0 |
| FR-3.2 | Decay uses BFS to verify path to source exists | P0 |
| FR-3.3 | Decay removes water if no valid source path | P0 |
| FR-3.4 | Flowing water updates on adjacent block changes | P0 |
| FR-3.5 | Flowing water respects block replacement rules | P0 |

### FR-4: Water Rendering

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Water uses EditableMesh for smooth surfaces | P0 |
| FR-4.2 | Water height: (8 - level) / 8 blocks | P0 |
| FR-4.3 | Source/Falling water renders at 7/8 height (Minecraft) | P0 |
| FR-4.4 | Water surface is semi-transparent (0.4 transparency) | P0 |
| FR-4.5 | Water surface has blue tint (32, 84, 164) | P0 |
| FR-4.6 | Water mesh is double-sided (visible from below) | P0 |
| FR-4.7 | Adjacent water blocks share vertex heights at edges | P1 |
| FR-4.8 | Water surface animates (UV scrolling) | P2 |

### FR-5: Entity Interaction

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Entities inside water are pushed in flow direction | P1 |
| FR-5.2 | Current strength based on water level | P1 |
| FR-5.3 | Players can swim (reduced gravity in water) | P1 |
| FR-5.4 | Underwater: blue tint overlay, bubble particles | P2 |
| FR-5.5 | Drowning: oxygen meter, damage when depleted | P2 |

---

## Technical Specifications

### Water Metadata Format

```lua
-- WaterUtils.lua (corrected)
local WaterUtils = {}

-- Level mask: bits 0-2 (values 0-7)
WaterUtils.LEVEL_MASK = 0x07
WaterUtils.MAX_LEVEL = 7

-- Falling flag: bit 3
WaterUtils.FALLING_FLAG = 0x08

-- Reserved: bits 4-7 (for future use: fall distance, biome tint, etc.)

function WaterUtils.GetLevel(metadata: number?): number
    return bit32.band(metadata or 0, WaterUtils.LEVEL_MASK)
end

function WaterUtils.SetLevel(metadata: number?, level: number): number
    metadata = metadata or 0
    local clamped = math.clamp(level, 0, WaterUtils.MAX_LEVEL)
    return bit32.bor(
        bit32.band(metadata, bit32.bnot(WaterUtils.LEVEL_MASK)),
        clamped
    )
end

function WaterUtils.IsFalling(metadata: number?): boolean
    return bit32.band(metadata or 0, WaterUtils.FALLING_FLAG) ~= 0
end

function WaterUtils.SetFalling(metadata: number?, falling: boolean): number
    metadata = metadata or 0
    if falling then
        return bit32.bor(metadata, WaterUtils.FALLING_FLAG)
    end
    return bit32.band(metadata, bit32.bnot(WaterUtils.FALLING_FLAG))
end

function WaterUtils.MakeMetadata(level: number, falling: boolean?): number
    local meta = math.clamp(level, 0, WaterUtils.MAX_LEVEL)
    if falling then
        meta = bit32.bor(meta, WaterUtils.FALLING_FLAG)
    end
    return meta
end
```

### Water Height Calculation

```lua
--[[
    Get visual height of water block as fraction of block height [0, 1]
    
    Minecraft water heights:
    - Source (level 0): 14/16 = 0.875 (renders slightly below full)
    - Level 1: 12.5/16 = 0.78125
    - Level 2: 10/16 = 0.625
    - Level 3: 7.5/16 = 0.46875
    - Level 4: 5/16 = 0.3125
    - Level 5: 3.5/16 = 0.21875
    - Level 6: 2/16 = 0.125
    - Level 7: 0.5/16 = 0.03125 (barely visible)
    - Falling: 14/16 = 0.875 (full height)
]]
function WaterUtils.GetHeight(blockId: number, metadata: number?): number
    if blockId == Constants.BlockType.WATER_SOURCE then
        return 14/16  -- Source blocks at 7/8 visual height
    end
    
    if blockId ~= Constants.BlockType.FLOWING_WATER then
        return 0
    end
    
    local meta = metadata or 0
    
    -- Falling water always renders at full height
    if WaterUtils.IsFalling(meta) then
        return 14/16
    end
    
    local level = WaterUtils.GetLevel(meta)
    
    -- Minecraft formula: height = (8 - level) / 9 * 8/9
    -- Simplified: we use linear interpolation for visual clarity
    -- Level 0 (source) = 7/8, Level 7 = 1/8
    return math.max((8 - level) / 8 * (14/16), 1/16)
end
```

### Water Spread Algorithm (Corrected)

```lua
-- WaterService.lua (corrected spread algorithm)

-- CARDINAL DIRECTIONS ONLY (no diagonals!)
local CARDINAL_NEIGHBORS = {
    {dx = 0, dz = -1, name = "N"},  -- North (-Z)
    {dx = 1, dz = 0, name = "E"},   -- East (+X)
    {dx = 0, dz = 1, name = "S"},   -- South (+Z)
    {dx = -1, dz = 0, name = "W"},  -- West (-X)
}

--[[
    Find shortest distance to a drop-off using BFS.
    Returns: distance (1000 if no drop found within maxDistance)
]]
function WaterService:_findDropDistance(x: number, y: number, z: number, maxDistance: number): number
    local wm = self:_getWorldManager()
    if not wm then return 1000 end
    
    local visited = {}
    local queue = {{x = x, z = z, dist = 0}}
    visited[x .. "," .. z] = true
    
    while #queue > 0 do
        local node = table.remove(queue, 1)
        
        if node.dist >= maxDistance then
            continue
        end
        
        -- Check if this position has a drop below
        local belowId = wm:GetBlock(node.x, y - 1, node.z)
        if self:_canFlowInto(belowId) then
            return node.dist
        end
        
        -- Expand to CARDINAL neighbors only
        for _, dir in ipairs(CARDINAL_NEIGHBORS) do
            local nx, nz = node.x + dir.dx, node.z + dir.dz
            local key = nx .. "," .. nz
            
            if not visited[key] then
                visited[key] = true
                
                local neighborId = wm:GetBlock(nx, y, nz)
                if self:_canFlowInto(neighborId) or WaterUtils.IsWater(neighborId) then
                    table.insert(queue, {x = nx, z = nz, dist = node.dist + 1})
                end
            end
        end
    end
    
    return 1000  -- No drop found
end

--[[
    Update a single water block.
    Returns: true if block changed
]]
function WaterService:_updateWaterBlock(x: number, y: number, z: number): boolean
    local wm = self:_getWorldManager()
    if not wm then return false end
    
    local blockId = wm:GetBlock(x, y, z)
    if not WaterUtils.IsWater(blockId) then
        return false
    end
    
    local metadata = wm:GetBlockMetadata(x, y, z) or 0
    local isSource = (blockId == Constants.BlockType.WATER_SOURCE)
    local level = isSource and 0 or WaterUtils.GetLevel(metadata)
    
    local changed = false
    
    -- Step 1: Check vertical neighbors
    local aboveId = wm:GetBlock(x, y + 1, z)
    local belowId = wm:GetBlock(x, y - 1, z)
    local hasWaterAbove = WaterUtils.IsWater(aboveId)
    local canFlowDown = self:_canFlowInto(belowId)
    
    -- Step 2: Update falling flag
    -- Set if: can flow down OR has water above
    local shouldBeFalling = canFlowDown or hasWaterAbove
    local isFalling = WaterUtils.IsFalling(metadata)
    
    if shouldBeFalling ~= isFalling then
        metadata = WaterUtils.SetFalling(metadata, shouldBeFalling)
        wm:SetBlockMetadata(x, y, z, metadata)
        changed = true
    end
    
    -- Step 3: Flow down (highest priority)
    if canFlowDown then
        local newMeta = WaterUtils.MakeMetadata(0, true)  -- Level 0, falling
        if self:_setWater(x, y - 1, z, Constants.BlockType.FLOWING_WATER, newMeta) then
            changed = true
        end
        return changed  -- Don't spread horizontally if flowing down
    end
    
    -- Step 4: Recompute level for flowing water
    if not isSource then
        local desiredLevel = self:_computeDesiredLevel(x, y, z)
        
        if desiredLevel == nil then
            -- No source path, remove this water
            self:_removeWater(x, y, z)
            return true
        end
        
        if desiredLevel ~= level then
            metadata = WaterUtils.SetLevel(metadata, desiredLevel)
            wm:SetBlockMetadata(x, y, z, metadata)
            level = desiredLevel
            changed = true
        end
    end
    
    -- Step 5: Check infinite water source conversion
    if not isSource and GameConfig.Water.InfiniteWaterSource then
        local adjacentSources = 0
        for _, dir in ipairs(CARDINAL_NEIGHBORS) do
            local nx, nz = x + dir.dx, z + dir.dz
            local nId = wm:GetBlock(nx, y, nz)
            if nId == Constants.BlockType.WATER_SOURCE then
                adjacentSources = adjacentSources + 1
            end
        end
        
        -- Need 2+ adjacent sources AND solid below
        local belowSolid = self:_isSolid(belowId) or belowId == Constants.BlockType.WATER_SOURCE
        if adjacentSources >= 2 and belowSolid then
            self:_setWater(x, y, z, Constants.BlockType.WATER_SOURCE, 0)
            return true
        end
    end
    
    -- Step 6: Spread horizontally (only if at surface, not falling)
    if level >= WaterUtils.MAX_LEVEL then
        return changed  -- At max level, can't spread further
    end
    
    -- Find drop distances for all cardinal neighbors
    local dropDistances = {}
    local minDrop = 1000
    
    for _, dir in ipairs(CARDINAL_NEIGHBORS) do
        local nx, nz = x + dir.dx, z + dir.dz
        local nId = wm:GetBlock(nx, y, nz)
        
        if self:_canFlowInto(nId) then
            local dist = self:_findDropDistance(nx, y, nz, 4)
            dropDistances[dir.name] = {x = nx, z = nz, dist = dist}
            if dist < minDrop then
                minDrop = dist
            end
        end
    end
    
    -- Spread to neighbors with minimum drop distance (or all if no drop found)
    local newLevel = level + 1
    local newMeta = WaterUtils.MakeMetadata(newLevel, false)
    
    for name, data in pairs(dropDistances) do
        if minDrop < 1000 then
            -- Only spread toward drops
            if data.dist == minDrop then
                if self:_setWater(data.x, y, data.z, Constants.BlockType.FLOWING_WATER, newMeta) then
                    changed = true
                end
            end
        else
            -- No drops found, spread all directions
            if self:_setWater(data.x, y, data.z, Constants.BlockType.FLOWING_WATER, newMeta) then
                changed = true
            end
        end
    end
    
    return changed
end

--[[
    Compute desired level for flowing water based on neighbors.
    Returns: level (0-7) or nil if disconnected from source
]]
function WaterService:_computeDesiredLevel(x: number, y: number, z: number): number?
    local wm = self:_getWorldManager()
    if not wm then return nil end
    
    local minSourceLevel = nil
    
    -- Check above first (falling from above)
    local aboveId = wm:GetBlock(x, y + 1, z)
    if WaterUtils.IsWater(aboveId) then
        return 0  -- Water from above = level 0
    end
    
    -- Check cardinal neighbors
    for _, dir in ipairs(CARDINAL_NEIGHBORS) do
        local nx, nz = x + dir.dx, z + dir.dz
        local nId = wm:GetBlock(nx, y, nz)
        
        if nId == Constants.BlockType.WATER_SOURCE then
            minSourceLevel = math.min(minSourceLevel or 999, 1)
        elseif nId == Constants.BlockType.FLOWING_WATER then
            local nMeta = wm:GetBlockMetadata(nx, y, nz) or 0
            local nLevel = WaterUtils.GetLevel(nMeta)
            local nFalling = WaterUtils.IsFalling(nMeta)
            
            if nFalling then
                -- Falling water acts like source
                minSourceLevel = math.min(minSourceLevel or 999, 1)
            else
                minSourceLevel = math.min(minSourceLevel or 999, nLevel + 1)
            end
        end
    end
    
    if minSourceLevel and minSourceLevel <= WaterUtils.MAX_LEVEL then
        return minSourceLevel
    end
    
    return nil  -- No valid source
end
```

---

## EditableMesh Rendering

### Water Surface Geometry

```lua
--[[
    WaterMesher.lua - EditableMesh water rendering
    
    Key principles:
    1. Each water block generates a top face quad
    2. Side faces only where water meets air/solid
    3. Bottom faces only where no water below
    4. All faces are double-sided for underwater visibility
    5. Vertex colors provide blue tint (no textures needed)
]]

local WaterMesher = {}
WaterMesher.__index = WaterMesher

-- Visual constants
local WATER_COLOR = Color3.fromRGB(32, 84, 164)
local WATER_ALPHA = 0.6  -- 1 - transparency
local WATER_REFLECTANCE = 0.2

function WaterMesher.new()
    return setmetatable({}, WaterMesher)
end

--[[
    Generate water mesh for a chunk.
    Returns: Array of MeshParts (usually 1, could be 0 if no water)
]]
function WaterMesher:GenerateMesh(chunk, worldManager, options)
    options = options or {}
    
    local waterBlocks = self:_collectWaterBlocks(chunk)
    if #waterBlocks == 0 then
        return {}
    end
    
    local editableMesh = AssetService:CreateEditableMesh()
    local builder = MeshBuilder.new(editableMesh, WATER_COLOR, WATER_ALPHA)
    
    for _, wb in ipairs(waterBlocks) do
        self:_generateBlockGeometry(builder, chunk, worldManager, wb)
    end
    
    if builder.faceCount == 0 then
        editableMesh:Destroy()
        return {}
    end
    
    local meshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh))
    editableMesh:Destroy()  -- Free memory
    
    meshPart.Name = "WaterSurface"
    meshPart.Anchored = true
    meshPart.CanCollide = false
    meshPart.CanQuery = false
    meshPart.CanTouch = false
    meshPart.CastShadow = false
    meshPart.Color = WATER_COLOR
    meshPart.Transparency = 1 - WATER_ALPHA
    meshPart.Reflectance = WATER_REFLECTANCE
    meshPart.Material = Enum.Material.Glass
    
    return {meshPart}
end

--[[
    Generate geometry for a single water block.
    
    Top face: Always generated if no water above
    Side faces: Only where adjacent to air/solid
    Bottom face: Only if no water below
]]
function WaterMesher:_generateBlockGeometry(builder, chunk, worldManager, wb)
    local x, y, z = wb.x, wb.y, wb.z
    local height = wb.height
    local BLOCK_SIZE = Constants.BLOCK_SIZE
    
    -- World position (corner of block)
    local worldX = (chunk.x * Constants.CHUNK_SIZE_X + x) * BLOCK_SIZE
    local worldY = y * BLOCK_SIZE
    local worldZ = (chunk.z * Constants.CHUNK_SIZE_Z + z) * BLOCK_SIZE
    
    local hasWaterAbove = wb.hasAbove
    local hasWaterBelow = wb.hasBelow
    
    -- Top face (if no water above)
    if not hasWaterAbove then
        local topY = worldY + height * BLOCK_SIZE
        
        -- Simple flat top (no corner interpolation needed for Minecraft accuracy)
        local p0 = Vector3.new(worldX, topY, worldZ)
        local p1 = Vector3.new(worldX + BLOCK_SIZE, topY, worldZ)
        local p2 = Vector3.new(worldX, topY, worldZ + BLOCK_SIZE)
        local p3 = Vector3.new(worldX + BLOCK_SIZE, topY, worldZ + BLOCK_SIZE)
        
        builder:addQuad(p0, p1, p2, p3, Vector3.new(0, 1, 0))
    end
    
    -- Side faces
    local neighbors = {
        {dx = -1, dz = 0, normal = Vector3.new(-1, 0, 0)},  -- West
        {dx = 1, dz = 0, normal = Vector3.new(1, 0, 0)},    -- East
        {dx = 0, dz = -1, normal = Vector3.new(0, 0, -1)},  -- North
        {dx = 0, dz = 1, normal = Vector3.new(0, 0, 1)},    -- South
    }
    
    for _, dir in ipairs(neighbors) do
        if not wb.neighborWater[dir.dx .. "," .. dir.dz] then
            local topY = hasWaterAbove and (worldY + BLOCK_SIZE) or (worldY + height * BLOCK_SIZE)
            local botY = worldY
            
            -- Generate side quad based on direction
            self:_addSideFace(builder, worldX, topY, botY, worldZ, BLOCK_SIZE, dir)
        end
    end
    
    -- Bottom face (if no water below)
    if not hasWaterBelow then
        local p0 = Vector3.new(worldX, worldY, worldZ)
        local p1 = Vector3.new(worldX + BLOCK_SIZE, worldY, worldZ)
        local p2 = Vector3.new(worldX, worldY, worldZ + BLOCK_SIZE)
        local p3 = Vector3.new(worldX + BLOCK_SIZE, worldY, worldZ + BLOCK_SIZE)
        
        builder:addQuad(p0, p2, p1, p3, Vector3.new(0, -1, 0))  -- Reversed winding
    end
end
```

### MeshBuilder Helper

```lua
local MeshBuilder = {}
MeshBuilder.__index = MeshBuilder

function MeshBuilder.new(editableMesh, color, alpha)
    local self = setmetatable({
        mesh = editableMesh,
        faceCount = 0,
        color = color,
        alpha = alpha,
    }, MeshBuilder)
    
    self.colorId = editableMesh:AddColor(color, alpha)
    return self
end

--[[
    Add a quad (2 triangles, double-sided = 4 triangles total)
    p0--p1
    |    |
    p2--p3
]]
function MeshBuilder:addQuad(p0, p1, p2, p3, normal)
    local mesh = self.mesh
    
    -- Front face vertices
    local v0 = mesh:AddVertex(p0)
    local v1 = mesh:AddVertex(p1)
    local v2 = mesh:AddVertex(p2)
    local v3 = mesh:AddVertex(p3)
    
    -- Back face vertices (same positions)
    local v0b = mesh:AddVertex(p0)
    local v1b = mesh:AddVertex(p1)
    local v2b = mesh:AddVertex(p2)
    local v3b = mesh:AddVertex(p3)
    
    -- Normals
    local normalId = mesh:AddNormal(normal)
    local backNormalId = mesh:AddNormal(-normal)
    
    -- UVs
    local uv0 = mesh:AddUV(Vector2.new(0, 0))
    local uv1 = mesh:AddUV(Vector2.new(1, 0))
    local uv2 = mesh:AddUV(Vector2.new(0, 1))
    local uv3 = mesh:AddUV(Vector2.new(1, 1))
    
    -- Front triangles (CCW)
    local f1 = mesh:AddTriangle(v0, v1, v2)
    mesh:SetFaceNormals(f1, {normalId, normalId, normalId})
    mesh:SetFaceUVs(f1, {uv0, uv1, uv2})
    mesh:SetFaceColors(f1, {self.colorId, self.colorId, self.colorId})
    
    local f2 = mesh:AddTriangle(v1, v3, v2)
    mesh:SetFaceNormals(f2, {normalId, normalId, normalId})
    mesh:SetFaceUVs(f2, {uv1, uv3, uv2})
    mesh:SetFaceColors(f2, {self.colorId, self.colorId, self.colorId})
    
    -- Back triangles (CW = reversed)
    local f3 = mesh:AddTriangle(v0b, v2b, v1b)
    mesh:SetFaceNormals(f3, {backNormalId, backNormalId, backNormalId})
    mesh:SetFaceUVs(f3, {uv0, uv2, uv1})
    mesh:SetFaceColors(f3, {self.colorId, self.colorId, self.colorId})
    
    local f4 = mesh:AddTriangle(v1b, v2b, v3b)
    mesh:SetFaceNormals(f4, {backNormalId, backNormalId, backNormalId})
    mesh:SetFaceUVs(f4, {uv1, uv2, uv3})
    mesh:SetFaceColors(f4, {self.colorId, self.colorId, self.colorId})
    
    self.faceCount = self.faceCount + 4
end
```

---

## Technical Architecture

### File Structure

```
src/
├── ServerScriptService/Server/Services/
│   └── WaterService.lua              # REWRITE
│       - 4-directional spread
│       - Correct BFS pathfinding
│       - Proper falling water
│       - Source conversion
│       - Queue-based tick updates
│
├── StarterPlayerScripts/Client/Controllers/
│   └── WaterEffectsController.lua    # NEW (P1)
│       - Underwater camera effects
│       - Current push on player
│       - Swimming controls
│
├── ReplicatedStorage/Shared/VoxelWorld/
│   ├── Rendering/
│   │   └── WaterMesher.lua           # REWRITE
│   │       - Correct height calculation
│   │       - Proper face culling
│   │       - Double-sided geometry
│   │       - Vertex colors for tint
│   │
│   └── World/
│       └── WaterUtils.lua            # MODIFY
│           - Simplified metadata
│           - Correct height formula
│           - Cardinal-only helpers
│
└── ReplicatedStorage/Configs/
    └── GameConfig.lua                # MODIFY
        - Water.InfiniteWaterSource
        - Water.SpreadTickRate
        - Water.MaxUpdatesPerTick
        - Water.FlowSearchDistance
```

### Service Dependencies

```
┌─────────────────────────────────────────────────────────────────┐
│                    WATER SYSTEM ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SERVER                           CLIENT                        │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │  WaterService   │              │   ChunkRenderer │           │
│  │  ─────────────  │              │   ─────────────  │          │
│  │  - Tick updates │              │  - Calls WaterMesher        │
│  │  - Spread logic │              │  - Manages MeshParts        │
│  │  - Source conv. │              │  - Updates on block change  │
│  └────────┬────────┘              └────────┬────────┘           │
│           │                                │                    │
│           ▼                                ▼                    │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │VoxelWorldService│◄────────────►│   WaterMesher   │           │
│  │   (Authority)   │  Block data  │  ─────────────  │           │
│  │  ─────────────  │              │  - EditableMesh │           │
│  │  - Block storage│              │  - Height calc  │           │
│  │  - Chunk mgmt   │              │  - Face culling │           │
│  └─────────────────┘              └─────────────────┘           │
│           │                                │                    │
│           ▼                                ▼                    │
│  ┌─────────────────┐              ┌─────────────────┐           │
│  │   WaterUtils    │              │  WaterUtils     │           │
│  │   (Shared)      │              │  (Shared)       │           │
│  │  ─────────────  │              │  ─────────────  │           │
│  │  - Metadata     │              │  - Metadata     │           │
│  │  - Height calc  │              │  - Height calc  │           │
│  │  - Block checks │              │  - Block checks │           │
│  └─────────────────┘              └─────────────────┘           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Event Flow

```
Block Change (Water Placed/Removed)
         │
         ▼
┌─────────────────────┐
│ VoxelWorldService   │
│ OnBlockChanged()    │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ WaterService        │
│ OnBlockChanged()    │
│ - Queue neighbors   │
│ - Queue self        │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ WaterService        │
│ _processQueue()     │ (runs on tick interval)
│ - Update each block │
│ - Spread/decay      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ VoxelWorldService   │
│ SetBlock()          │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐      ┌─────────────────────┐
│ Network: BlockChanged│─────►│ Client: ChunkRenderer│
│ Event to clients     │      │ - Re-mesh chunk      │
└─────────────────────┘      │ - Update WaterMesher │
                              └─────────────────────┘
```

---

## Implementation Plan

### Phase 1: Core Water Spread (Day 1-3)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `WaterUtils.lua` | Simplify metadata (level 0-7 + falling flag) |
| 1.2 | `WaterUtils.lua` | Fix GetHeight() to use correct Minecraft formula |
| 1.3 | `WaterService.lua` | Remove 8-direction spread, use 4-direction only |
| 1.4 | `WaterService.lua` | Fix BFS to search cardinal directions only |
| 1.5 | `WaterService.lua` | Implement correct level computation |
| 1.6 | `WaterService.lua` | Fix falling water flag logic |
| 1.7 | `WaterService.lua` | Fix source conversion (2 sources + solid below) |

### Phase 2: Water Rendering (Day 3-5)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `WaterMesher.lua` | Remove corner height interpolation |
| 2.2 | `WaterMesher.lua` | Use flat top faces with correct height |
| 2.3 | `WaterMesher.lua` | Fix face culling (water-to-water, water-to-air) |
| 2.4 | `WaterMesher.lua` | Ensure double-sided geometry |
| 2.5 | `WaterMesher.lua` | Proper vertex colors for water tint |
| 2.6 | `WaterMesher.lua` | Fix side face generation |

### Phase 3: Integration & Testing (Day 5-7)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `GameConfig.lua` | Add water configuration options |
| 3.2 | `VoxelWorldService.lua` | Ensure WaterService integration |
| 3.3 | Testing | Test 4-direction spread patterns |
| 3.4 | Testing | Test downhill pathfinding |
| 3.5 | Testing | Test falling water columns |
| 3.6 | Testing | Test infinite water source |
| 3.7 | Testing | Test cross-chunk water flow |
| 3.8 | Testing | Test water decay when source removed |

### Phase 4: Entity Interaction (Day 7-9) [P1]

| Task | File | Description |
|------|------|-------------|
| 4.1 | `WaterEffectsController.lua` | Create new controller |
| 4.2 | `WaterEffectsController.lua` | Detect player inside water |
| 4.3 | `WaterEffectsController.lua` | Calculate flow direction at position |
| 4.4 | `WaterEffectsController.lua` | Apply current push to player |
| 4.5 | `WaterEffectsController.lua` | Implement swimming controls |
| 4.6 | `GameClient.client.lua` | Initialize WaterEffectsController |

### Phase 5: Visual Effects (Day 9-10) [P2]

| Task | File | Description |
|------|------|-------------|
| 5.1 | `WaterEffectsController.lua` | Underwater blue tint overlay |
| 5.2 | `WaterEffectsController.lua` | Bubble particles when underwater |
| 5.3 | `WaterEffectsController.lua` | Underwater fog/visibility reduction |
| 5.4 | `WaterMesher.lua` | UV animation for surface flow |

---

## Configuration Options

### GameConfig.Water

```lua
-- GameConfig.lua
Water = {
    -- Infinite water source generation
    -- When true, 2+ adjacent sources + solid below creates new source
    InfiniteWaterSource = true,
    
    -- Water tick rate (seconds between spread updates)
    TickInterval = 0.25,
    
    -- Maximum blocks to update per tick (performance limit)
    MaxUpdatesPerTick = 200,
    
    -- Maximum blocks to update per chunk per tick
    MaxUpdatesPerChunk = 50,
    
    -- BFS search distance for downhill pathfinding
    FlowSearchDistance = 4,
    
    -- Maximum queue size (prevents runaway water)
    MaxQueueSize = 50000,
    
    -- Entity current push strength (studs/second)
    CurrentStrength = 5.0,
    
    -- Swimming gravity multiplier (< 1 = slower fall)
    SwimmingGravity = 0.25,
    
    -- Underwater oxygen time (seconds before drowning)
    OxygenTime = 30,
    
    -- Drowning damage per second
    DrowningDamage = 2,
},
```

---

## Testing Checklist

### Spread Pattern Tests

- [ ] Source block spreads to 4 cardinal neighbors (not 8)
- [ ] Water level increases by 1 per horizontal step
- [ ] Water stops at level 7
- [ ] Water flows down before spreading horizontally
- [ ] Water prefers flowing toward nearest drop-off
- [ ] Multiple equal-distance drops: water spreads to all

### Falling Water Tests

- [ ] Falling water has level 0, falling flag set
- [ ] Falling water renders at full height
- [ ] Entire falling column renders correctly
- [ ] Bottom of waterfall can spread horizontally
- [ ] Waterfall top has water above (flag still set)

### Source Conversion Tests

- [ ] 2 adjacent sources + solid below = new source
- [ ] 2 adjacent sources + air below = no conversion
- [ ] 1 adjacent source = no conversion
- [ ] Conversion can be disabled via config

### Decay Tests

- [ ] Flowing water decays when source removed
- [ ] Decay propagates through connected water
- [ ] Falling column decays from top down
- [ ] Decay doesn't affect other source branches

### Rendering Tests

- [ ] Water surface renders at correct height per level
- [ ] No gaps between adjacent water blocks
- [ ] Side faces only where water meets air/solid
- [ ] Bottom faces only where no water below
- [ ] Water visible from underwater (double-sided)
- [ ] Cross-chunk water renders correctly

---

## Future Enhancements

### v1.1: Advanced Water Physics
- [ ] Water displacement by entities
- [ ] Waterlogged blocks (slabs, stairs)
- [ ] Kelp and seagrass in water
- [ ] Bubble columns (soul sand, magma)

### v1.2: Water Interactions
- [ ] Water extinguishes fire
- [ ] Water washes away crops
- [ ] Water pushes dropped items
- [ ] Concrete powder + water = concrete

### v1.3: Lava System
- [ ] Lava source and flowing blocks
- [ ] Lava spread (slower than water, 4 blocks max)
- [ ] Water + Lava interactions (cobblestone, obsidian, stone)
- [ ] Lava damage to entities

### v1.4: Weather Effects
- [ ] Rain fills cauldrons
- [ ] Rain creates puddles (temporary water)
- [ ] Snow accumulation on water (ice)

---

## Appendix A: Minecraft Water Level Reference

| Level | Height (Blocks) | Height (Fraction) | Description |
|-------|-----------------|-------------------|-------------|
| 0 (Source) | 14/16 | 0.875 | Full source block |
| 1 | 12.5/16 | 0.78125 | First spread |
| 2 | 10/16 | 0.625 | Second spread |
| 3 | 7.5/16 | 0.46875 | Third spread |
| 4 | 5/16 | 0.3125 | Fourth spread |
| 5 | 3.5/16 | 0.21875 | Fifth spread |
| 6 | 2/16 | 0.125 | Sixth spread |
| 7 | 0.5/16 | 0.03125 | Maximum spread |
| 8+ (Falling) | 14/16 | 0.875 | Full height column |

---

## Appendix B: Direction Constants Reference

```lua
-- CARDINAL ONLY - Used for water spread
local CARDINAL = {
    N = {dx = 0, dz = -1},   -- North (-Z)
    E = {dx = 1, dz = 0},    -- East (+X)
    S = {dx = 0, dz = 1},    -- South (+Z)
    W = {dx = -1, dz = 0},   -- West (-X)
}

-- DO NOT USE for water spread (only for special cases)
local DIAGONAL = {
    NE = {dx = 1, dz = -1},
    NW = {dx = -1, dz = -1},
    SE = {dx = 1, dz = 1},
    SW = {dx = -1, dz = 1},
}
```

---

*Document Version: 1.0*  
*Created: January 2026*  
*Author: PRD Generation Agent*  
*Related: [ARCHITECTURE.md](../ARCHITECTURE.md), [SYSTEMS.md](../SYSTEMS.md)*
