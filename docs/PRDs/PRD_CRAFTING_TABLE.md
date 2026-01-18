# Product Requirements Document: Crafting Table System
## Skyblox - 3x3 Crafting Grid Expansion

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Advanced Crafting)
> **Estimated Effort**: Small (2-3 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Crafting Table enables players to access a 3x3 crafting grid (instead of the default 2x2 grid). This PRD defines crafting table interaction, 3x3 grid UI, recipe support, and integration with the existing crafting system. The crafting table is essential for advanced recipes requiring 3x3 patterns.

### Why This Matters
- **Recipe Access**: Many recipes require 3x3 grid (tools, armor, complex items)
- **Progression Gate**: Unlocks advanced crafting capabilities
- **Minecraft Parity**: Core feature expected in Minecraft-like games

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Crafting Table Block | `Constants.lua` → `BlockType.CRAFTING_TABLE = 13` | ✅ Defined |
| Crafting Table Textures | `BlockRegistry.lua` | ✅ Available |
| Interactable Flag | `BlockRegistry.lua` | ✅ `interactable = true` |
| Basic Crafting System | `CraftingService.lua` | ✅ 2x2 grid exists |
| Recipe System | `RecipeConfig.lua` | ✅ Recipes defined |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Crafting Table Click Handler | Opening 3x3 crafting UI | P0 |
| 3x3 Crafting Grid UI | Expanded crafting interface | P0 |
| Recipe Filtering | Show only 3x3 recipes at table | P0 |
| Crafting Table Integration | Use table for 3x3 recipes | P0 |

---

## Detailed Requirements

### FR-1: Crafting Table Interaction

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Right-clicking crafting table opens 3x3 grid | P0 |
| FR-1.2 | Player must be within 6 studs to interact | P0 |
| FR-1.3 | 3x3 grid replaces 2x2 grid when table is open | P0 |
| FR-1.4 | Crafting table closes when player moves away | P0 |

### FR-2: 3x3 Crafting Grid

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Display 3x3 crafting grid (9 slots) | P0 |
| FR-2.2 | Support all existing crafting recipes | P0 |
| FR-2.3 | Show recipe results in output slot | P0 |
| FR-2.4 | Click output to craft item | P0 |
| FR-2.5 | Shift-click to craft maximum possible | P0 |

### FR-3: Recipe Support

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | 2x2 recipes work in 3x3 grid (any position) | P0 |
| FR-3.2 | 3x3 recipes require exact pattern | P0 |
| FR-3.3 | Recipe matching checks all 9 slots | P0 |
| FR-3.4 | Recipes update as player places items | P0 |

---

## Technical Specifications

### Crafting Table Service

```lua
-- CraftingTableService.lua
local CraftingTableService = {}

function CraftingTableService:OpenCraftingTable(player, tablePosition)
    -- Validate access
    if not self:CanPlayerAccess(player, tablePosition) then
        return false, "Too far away"
    end

    -- Open 3x3 crafting UI
    EventManager:FireEventToPlayer(player, "CraftingTableOpened", {
        position = tablePosition,
        gridSize = 3  -- 3x3 grid
    })

    return true
end

function CraftingTableService:CraftAtTable(player, recipeId, count)
    -- Use existing CraftingService but with 3x3 grid
    local craftingService = require(path.to.CraftingService)
    return craftingService:Craft(player, recipeId, count, {gridSize = 3})
end

return CraftingTableService
```

### UI Integration

The existing `CraftingPanel.lua` should be modified to support both 2x2 and 3x3 grids:
- When crafting table is open: Show 3x3 grid
- When crafting table is closed: Show 2x2 grid (default)

---

## Implementation Plan

### Phase 1: Basic Integration (Day 1)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `BlockInteraction.lua` | Add crafting table click handler |
| 1.2 | `CraftingTableService.lua` | Create service skeleton |
| 1.3 | `CraftingPanel.lua` | Add 3x3 grid support |
| 1.4 | `CraftingService.lua` | Support 3x3 grid parameter |

### Phase 2: Recipe Matching (Day 2)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `CraftingService.lua` | Update recipe matching for 3x3 |
| 2.2 | `CraftingService.lua` | Support 2x2 recipes in 3x3 grid |
| 2.3 | Testing | Test all recipe types |

### Phase 3: Polish (Day 3)

| Task | File | Description |
|------|------|-------------|
| 3.1 | Testing | Test crafting table interaction |
| 3.2 | Testing | Test recipe crafting |
| 3.3 | UI Polish | Improve 3x3 grid appearance |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_CHEST_STORAGE.md](./PRD_CHEST_STORAGE.md)*
