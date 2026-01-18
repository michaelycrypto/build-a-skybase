# Product Requirements Document: Chest Storage System
## Skyblox - Item Storage & Inventory Management

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Core Feature)
> **Estimated Effort**: Medium (4-5 days)
> **Last Updated**: January 2026

---

## Executive Summary

The Chest Storage System enables players to store items in placed chest blocks. This PRD defines chest interaction, inventory management, chest UI, item persistence, and multiplayer synchronization. Chests are essential for inventory management and resource storage.

### Why This Matters
- **Inventory Management**: Players need storage for excess items
- **Resource Organization**: Chests allow sorting and organizing resources
- **Base Building**: Essential for building player bases and storage rooms
- **Minecraft Parity**: Core feature expected in Minecraft-like games

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
| Chest Block Type | `Constants.lua` → `BlockType.CHEST = 9` | ✅ Defined |
| Chest Textures | `BlockRegistry.lua` | ✅ Top, side, front, back textures |
| Chest Properties | `BlockProperties.lua` | ✅ Hardness, pickaxe required |
| Interactable Flag | `BlockRegistry.lua` | ✅ `interactable = true` |
| Storage Flag | `BlockRegistry.lua` | ✅ `storage = true` |
| Chest Rotation | `BlockRegistry.lua` | ✅ `hasRotation = true` |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Chest Click Handler | Opening chest UI | P0 |
| ChestUI.lua | Player interaction interface | P0 |
| Chest Storage Service | Server-side inventory management | P0 |
| Chest Inventory System | 27-slot storage per chest | P0 |
| Chest Persistence | Save/load chest contents | P0 |
| Chest Synchronization | Multiplayer access | P0 |
| Double Chest Support | Two chests combine into 54 slots | P1 |
| Chest Locking | Prevent other players from accessing | P2 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                    CHEST INTERACTION FLOW                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. Player places Chest block                                  │
│                    ↓                                            │
│   2. Player right-clicks Chest                                  │
│                    ↓                                            │
│   3. ChestUI opens (27-slot inventory grid)                    │
│      - Player inventory on bottom (27 slots)                   │
│      - Chest inventory on top (27 slots)                       │
│                    ↓                                            │
│   4. Player can drag items between inventories                 │
│      - Click to move single item                                │
│      - Shift-click to move stack                               │
│      - Drag to move items                                      │
│                    ↓                                            │
│   5. Chest contents saved to server                            │
│      - Persists across sessions                                 │
│      - Synchronized to all players                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Design Pillars

1. **Intuitive Interface** - Easy to understand and use
2. **Smooth Interaction** - Responsive drag-and-drop
3. **Multiplayer Safe** - Multiple players can access simultaneously
4. **Persistent Storage** - Chest contents saved permanently

---

## Detailed Requirements

### FR-1: Chest Interaction

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Right-clicking chest opens ChestUI | P0 |
| FR-1.2 | Player must be within 6 studs to interact | P0 |
| FR-1.3 | Chest can be opened by multiple players simultaneously | P0 |
| FR-1.4 | Chest closes when player moves >10 studs away | P0 |
| FR-1.5 | Chest closes when player disconnects | P0 |
| FR-1.6 | Chest cannot be opened if block is broken | P0 |

### FR-2: Chest Inventory

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Each chest has 27 inventory slots (3x9 grid) | P0 |
| FR-2.2 | Items can stack up to stack limit (64 for most items) | P0 |
| FR-2.3 | Items persist when chest is closed | P0 |
| FR-2.4 | Items persist when player disconnects | P0 |
| FR-2.5 | Items persist across server restarts | P0 |
| FR-2.6 | Empty slots display as empty | P0 |

### FR-3: Item Transfer

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Click item to move single item between inventories | P0 |
| FR-3.2 | Shift-click to move entire stack | P0 |
| FR-3.3 | Drag-and-drop items between slots | P0 |
| FR-3.4 | Right-click to split stack in half | P0 |
| FR-3.5 | Items stack automatically when possible | P0 |
| FR-3.6 | Cannot move items if target inventory is full | P0 |

### FR-4: Chest Persistence

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Chest contents saved to database/server | P0 |
| FR-4.2 | Chest contents loaded when chunk loads | P0 |
| FR-4.3 | Chest identified by world position (x, y, z) | P0 |
| FR-4.4 | Chest contents persist if chest block is broken and replaced | P1 |
| FR-4.5 | Chest contents cleared if chest block is destroyed | P0 |

### FR-5: Double Chest Support

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Two adjacent chests combine into double chest | P1 |
| FR-5.2 | Double chest has 54 slots (6x9 grid) | P1 |
| FR-5.3 | Opening either chest opens the combined inventory | P1 |
| FR-5.4 | Chests must be same rotation to combine | P1 |
| FR-5.5 | Breaking one chest splits double chest | P1 |

---

## Minecraft Behavior Reference

### Chest Inventory

- **Single Chest**: 27 slots (3 rows × 9 columns)
- **Double Chest**: 54 slots (6 rows × 9 columns)
- **Stack Limits**: Same as player inventory (64 for most items)
- **Item Persistence**: Chest contents saved permanently

### Chest Placement

- **Placement**: Chest can be placed on solid blocks
- **Rotation**: Chest faces player when placed
- **Double Chest**: Two chests placed adjacent combine automatically
- **Breaking**: Chest drops itself (with contents) when broken

### Chest Interaction

- **Opening**: Right-click to open
- **Range**: Must be within interaction range (~5 blocks)
- **Multiple Players**: Multiple players can access same chest
- **Closing**: Move away or press ESC to close

---

## Technical Specifications

### Chest Storage Structure

```lua
-- ChestStorage.lua
local ChestStorage = {}

-- Chest data structure
local ChestData = {
    position = Vector3.new(x, y, z),
    inventory = {
        [1] = {itemId = 32, count = 64},  -- Slot 1: 64 Coal
        [2] = {itemId = 33, count = 32},  -- Slot 2: 32 Iron Ingots
        -- ... 27 slots total
    },
    isDoubleChest = false,
    doubleChestPartner = nil  -- Position of partner chest if double
}

-- Load chest from storage
function ChestStorage:LoadChest(worldId, position)
    local chestKey = self:GetChestKey(worldId, position)
    return self.chestDatabase[chestKey]
end

-- Save chest to storage
function ChestStorage:SaveChest(worldId, position, chestData)
    local chestKey = self:GetChestKey(worldId, position)
    self.chestDatabase[chestKey] = chestData
    -- Persist to database
    self:PersistToDatabase(chestKey, chestData)
end

-- Get chest key from position
function ChestStorage:GetChestKey(worldId, position)
    return string.format("%s_%d_%d_%d", worldId, position.X, position.Y, position.Z)
end

return ChestStorage
```

### Chest Service

```lua
-- ChestService.lua
local ChestService = {}

function ChestService:OpenChest(player, chestPosition)
    -- Validate player can access
    if not self:CanPlayerAccess(player, chestPosition) then
        return false, "Too far away"
    end

    -- Load chest data
    local chestData = ChestStorage:LoadChest(player.worldId, chestPosition)
    if not chestData then
        -- Create new chest
        chestData = self:CreateNewChest(chestPosition)
    end

    -- Check for double chest
    local doubleChestData = self:CheckDoubleChest(chestPosition)
    if doubleChestData then
        chestData = self:CombineChests(chestData, doubleChestData)
    end

    -- Open UI for player
    EventManager:FireEventToPlayer(player, "ChestOpened", {
        position = chestPosition,
        inventory = chestData.inventory,
        isDoubleChest = chestData.isDoubleChest
    })

    return true
end

function ChestService:MoveItem(player, chestPosition, fromSlot, toSlot, fromInventory, toInventory, count)
    -- Validate move
    if not self:ValidateMove(player, chestPosition, fromSlot, toSlot, fromInventory, toInventory, count) then
        return false, "Invalid move"
    end

    -- Perform move
    if fromInventory == "chest" and toInventory == "player" then
        -- Move from chest to player
        self:MoveFromChestToPlayer(player, chestPosition, fromSlot, toSlot, count)
    elseif fromInventory == "player" and toInventory == "chest" then
        -- Move from player to chest
        self:MoveFromPlayerToChest(player, chestPosition, fromSlot, toSlot, count)
    end

    -- Save chest
    self:SaveChest(player.worldId, chestPosition)

    -- Notify all players viewing this chest
    self:NotifyChestUpdate(chestPosition)

    return true
end

return ChestService
```

---

## UI/UX Design

### Chest UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║                      📦 CHEST                              ║  │
│  ╠═══════════════════════════════════════════════════════════╣  │
│  ║                                                           ║  │
│  ║  CHEST INVENTORY (27 slots)                              ║  │
│  ║  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  ├───┼───┼───┼───┼───┼───┼───┼───┼───┤                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  ├───┼───┼───┼───┼───┼───┼───┼───┼───┤                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  └───┴───┴───┴───┴───┴───┴───┴───┴───┘                  ║  │
│  ║                                                           ║  │
│  ║  ─────────────────────────────────────────────────────    ║  │
│  ║                                                           ║  │
│  ║  PLAYER INVENTORY (27 slots)                             ║  │
│  ║  ┌───┬───┬───┬───┬───┬───┬───┬───┬───┐                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  ├───┼───┼───┼───┼───┼───┼───┼───┼───┤                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  ├───┼───┼───┼───┼───┼───┼───┼───┼───┤                  ║  │
│  ║  │   │   │   │   │   │   │   │   │   │                  ║  │
│  ║  └───┴───┴───┴───┴───┴───┴───┴───┴───┘                  ║  │
│  ║                                                           ║  │
│  ╚═══════════════════════════════════════════════════════╝  │
│                              [X]                                │
└─────────────────────────────────────────────────────────────────┘
```

### Interaction Methods

- **Click**: Move single item
- **Shift-Click**: Move entire stack
- **Drag**: Drag item between slots
- **Right-Click**: Split stack in half
- **ESC**: Close chest

---

## Technical Architecture

### New Files Required

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── ChestService.lua              # NEW: Chest interaction logic
│       └── ChestStorage.lua             # NEW: Chest data persistence
│
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── BlockInteraction.lua         # MODIFY: Add chest click handler
│   └── UI/
│       └── ChestUI.lua                   # NEW: Chest interface
│
└── ReplicatedStorage/
    └── Shared/
        └── ChestConfig.lua              # NEW: Chest configuration
```

### Modified Files

```
src/
├── StarterPlayerScripts/Client/
│   └── Controllers/
│       └── BlockInteraction.lua         # ADD: Chest right-click handler
│
└── ServerScriptService/Server/
    └── Services/
        └── VoxelWorldService.lua        # MODIFY: Handle chest breaking
```

### Event Flow

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLIENT    │      │   SERVER    │      │   CLIENT    │
│BlockInteract│      │ChestService │      │   ChestUI   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                     │                    │
       │ Right-click chest   │                    │
       │────────────────────>│                    │
       │                     │                    │
       │                     │ Load chest data    │
       │                     │ Check double chest │
       │                     │                    │
       │<────────────────────│ ChestOpened        │
       │                     │ (inventory data)   │
       │                     │                    │
       │                     │                    │
       │────────────────────────────────────────>│ Open ChestUI
       │                     │                    │
       │                     │<───────────────────│ MoveItem
       │                     │                    │
       │                     │ Validate & move    │
       │                     │ Save chest         │
       │                     │                    │
       │<────────────────────│ ChestUpdated       │
       │                     │                    │
       │                     │───────────────────>│ Update UI
       │                     │                    │
```

---

## Implementation Plan

### Phase 1: Core Chest System (Day 1-2)

| Task | File | Description |
|------|------|-------------|
| 1.1 | `ChestConfig.lua` | Create chest configuration |
| 1.2 | `ChestStorage.lua` | Create chest data storage system |
| 1.3 | `ChestService.lua` | Create chest service skeleton |
| 1.4 | `BlockInteraction.lua` | Add chest click handler |
| 1.5 | `ChestService.lua` | Implement chest opening logic |

### Phase 2: Inventory Management (Day 2-3)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `ChestService.lua` | Implement 27-slot inventory |
| 2.2 | `ChestService.lua` | Implement item movement logic |
| 2.3 | `ChestUI.lua` | Create chest UI component |
| 2.4 | `ChestUI.lua` | Implement drag-and-drop |
| 2.5 | `ChestUI.lua` | Implement click interactions |

### Phase 3: Persistence (Day 3-4)

| Task | File | Description |
|------|------|-------------|
| 3.1 | `ChestStorage.lua` | Implement save to database |
| 3.2 | `ChestStorage.lua` | Implement load from database |
| 3.3 | `ChestService.lua` | Save chest on item change |
| 3.4 | `ChestService.lua` | Load chest when chunk loads |
| 3.5 | `VoxelWorldService.lua` | Handle chest breaking |

### Phase 4: Multiplayer Sync (Day 4)

| Task | File | Description |
|------|------|-------------|
| 4.1 | `ChestService.lua` | Notify all viewers on update |
| 4.2 | `ChestUI.lua` | Handle remote updates |
| 4.3 | `ChestService.lua` | Track players viewing chest |
| 4.4 | Testing | Test multiplayer access |

### Phase 5: Double Chest (Day 5)

| Task | File | Description |
|------|------|-------------|
| 5.1 | `ChestService.lua` | Detect adjacent chests |
| 5.2 | `ChestService.lua` | Combine chests into 54 slots |
| 5.3 | `ChestUI.lua` | Display double chest UI |
| 5.4 | `ChestService.lua` | Handle double chest breaking |

---

## Future Enhancements

### v1.1: Advanced Chest Features
- [ ] Chest locking (prevent access)
- [ ] Chest sorting (auto-organize)
- [ ] Chest search (find items)
- [ ] Chest filters (item type filters)

### v1.2: Other Storage Blocks
- [ ] Barrel (chest alternative)
- [ ] Shulker Box (portable storage)
- [ ] Ender Chest (shared storage)

### v1.3: Chest Upgrades
- [ ] Larger chests (more slots)
- [ ] Auto-sorting chests
- [ ] Filtered chests

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
*Related: [PRD_FURNACE.md](../PRD_FURNACE.md)*
