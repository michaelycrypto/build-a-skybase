# Product Requirements Document: Furnace System Refactor
## Skyblox - Minecraft-Style Furnace & Smithing Separation

> **Status**: Ready for Implementation
> **Priority**: P0 (Critical - Simplifies Core Gameplay)
> **Last Updated**: February 2026

---

## Executive Summary

This PRD defines a major refactor of the furnace system to achieve two goals:

1. **Create a Minecraft-style Furnace** - Simple, intuitive smelting with fuel + input slots that automatically produces outputs
2. **Separate Smithing to Anvil** - Move the existing temperature mini-game to a new "Anvil" workstation for advanced crafting

### Why This Refactor

- **Player Expectation**: Minecraft players expect furnaces to work simply - add fuel, add ore, wait for output
- **Complexity Separation**: The temperature mini-game is engaging but overwhelming for basic smelting; it's better suited for advanced crafting (smithing)
- **Tutorial Simplification**: New players can learn smelting easily, then graduate to smithing later

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Part 1: Minecraft-Style Furnace](#part-1-minecraft-style-furnace)
3. [Part 2: Smithing System (Anvil)](#part-2-smithing-system-anvil)
4. [Migration Plan](#migration-plan)
5. [Technical Changes](#technical-changes)

---

## Architecture Overview

### Current State (Before Refactor)

```
┌─────────────────────────────────────────────────────┐
│                  FURNACE BLOCK                       │
│  - Complex temperature mini-game                     │
│  - Recipes with requiresFurnace = true              │
│  - SmeltingService.lua                              │
│  - FurnaceUI.lua (2,491 lines)                      │
└─────────────────────────────────────────────────────┘
```

### Target State (After Refactor)

```
┌─────────────────────────────────────────────────────┐
│                  FURNACE BLOCK                       │
│  - Simple: Fuel slot + Input slot → Output slot     │
│  - Auto-smelts over time (like Minecraft)           │
│  - FurnaceService.lua (NEW)                         │
│  - FurnaceUI.lua (SIMPLIFIED)                       │
└─────────────────────────────────────────────────────┘
                         +
┌─────────────────────────────────────────────────────┐
│                   ANVIL BLOCK                        │
│  - Temperature mini-game (skill-based)              │
│  - Advanced crafting/upgrades                       │
│  - SmithingService.lua (RENAMED from Smelting)      │
│  - SmithingUI.lua (RENAMED from FurnaceUI)          │
└─────────────────────────────────────────────────────┘
```

---

## Part 1: Minecraft-Style Furnace

### 1.1 Feature Overview

The new Furnace works exactly like Minecraft:

```
┌─────────────────────────────────────────────────────┐
│                    FURNACE UI                        │
│  ┌───────────────────────────────────────────────┐  │
│  │                                               │  │
│  │        ┌───────┐                              │  │
│  │        │ INPUT │  ← Place ore/raw items      │  │
│  │        │  SLOT │                              │  │
│  │        └───────┘                              │  │
│  │            ↓                                  │  │
│  │      [FIRE ICON]  ← Shows when smelting      │  │
│  │     ═══════════   ← Progress bar             │  │
│  │            ↓                                  │  │
│  │        ┌───────┐                              │  │
│  │        │OUTPUT │  → Collect finished items   │  │
│  │        │  SLOT │                              │  │
│  │        └───────┘                              │  │
│  │                                               │  │
│  │  ┌───────┐                                    │  │
│  │  │ FUEL  │  ← Place coal/wood/etc            │  │
│  │  │  SLOT │  [████████░░] Fuel remaining      │  │
│  │  └───────┘                                    │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### 1.2 Core Mechanics

#### Slot System

| Slot | Purpose | Behavior |
|------|---------|----------|
| **Input Slot** | Raw materials (ores, raw food, etc.) | Accepts smeltable items only |
| **Fuel Slot** | Fuel sources (coal, wood, planks) | Consumes fuel over time |
| **Output Slot** | Finished products | Output-only, player can take |

#### Fuel Types & Burn Times

| Fuel Type | Burn Time | Items Smelted Per Fuel |
|-----------|-----------|------------------------|
| Coal | 80 seconds | 8 items |
| Charcoal | 80 seconds | 8 items |
| Wood Plank | 15 seconds | 1.5 items |
| Log | 15 seconds | 1.5 items |
| Stick | 5 seconds | 0.5 items |

#### Smelt Times

| Item Type | Smelt Time | Notes |
|-----------|------------|-------|
| Ores (Copper, Iron, etc.) | 10 seconds | Standard time |
| Raw Food | 10 seconds | Cooks food items |
| Sand → Glass | 10 seconds | Material conversion |

#### Auto-Smelting Behavior

1. **Continuous Operation**: Furnace runs while UI is closed (server-side)
2. **Fuel Consumption**: Burns fuel only when actively smelting
3. **Output Stacking**: Results stack in output slot (max 64)
4. **Pause Conditions**:
   - No input items
   - No fuel remaining
   - Output slot full (64 items)

### 1.3 UI Design (Matching Existing Patterns)

The UI follows the established `ChestUI.lua` patterns:

```
┌─────────────────────────────────────────────────────────────┐
│  FURNACE                                           [X]      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    ┌─────────────┐                          │
│    INPUT           │             │                          │
│                    │    [ORE]    │                          │
│                    │             │                          │
│                    └─────────────┘                          │
│                          │                                  │
│                    ╔═══════════╗                            │
│                    ║  🔥 FIRE  ║  ← Animated when active   │
│                    ╚═══════════╝                            │
│                    ════════════   ← Progress (0-100%)      │
│                          │                                  │
│                    ┌─────────────┐                          │
│    OUTPUT          │             │                          │
│                    │  [INGOT]    │                          │
│                    │         x3  │                          │
│                    └─────────────┘                          │
│                                                             │
│  ──────────────────────────────────────────────────────    │
│                                                             │
│  FUEL              ┌─────────────┐                          │
│                    │             │  Fuel: ████████░░        │
│                    │   [COAL]    │  (6.4 items remaining)   │
│                    │         x12 │                          │
│                    └─────────────┘                          │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│  INVENTORY                                                  │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐    │
│  │    ││    ││    ││    ││    ││    ││    ││    ││    │    │
│  └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘    │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐    │
│  │    ││    ││    ││    ││    ││    ││    ││    ││    │    │
│  └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘    │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐    │
│  │    ││    ││    ││    ││    ││    ││    ││    ││    │    │
│  └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘    │
├─────────────────────────────────────────────────────────────┤
│  HOTBAR                                                     │
│  ┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐┌────┐    │
│  │ 1  ││ 2  ││ 3  ││ 4  ││ 5  ││ 6  ││ 7  ││ 8  ││ 9  │    │
│  └────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘└────┘    │
└─────────────────────────────────────────────────────────────┘
```

### 1.4 Functional Requirements

#### FR-1: Basic Interaction

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | Right-click furnace block opens FurnaceUI | P0 |
| FR-1.2 | Player must be within 6 studs to interact | P0 |
| FR-1.3 | ESC key closes furnace UI | P0 |
| FR-1.4 | Drag-and-drop items between slots | P0 |

#### FR-2: Input Slot

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Accepts only smeltable items | P0 |
| FR-2.2 | Shows item icon and count | P0 |
| FR-2.3 | Click to pick up, click to place | P0 |
| FR-2.4 | Shift-click quick-transfers to inventory | P1 |

#### FR-3: Fuel Slot

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-3.1 | Accepts only fuel items | P0 |
| FR-3.2 | Shows fuel bar (remaining burn time) | P0 |
| FR-3.3 | Auto-consumes fuel when smelting | P0 |
| FR-3.4 | Visual fire indicator when active | P1 |

#### FR-4: Output Slot

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-4.1 | Output-only (cannot place items) | P0 |
| FR-4.2 | Stacks up to 64 items | P0 |
| FR-4.3 | Shift-click transfers all to inventory | P0 |
| FR-4.4 | Stops smelting when full | P0 |

#### FR-5: Auto-Smelting

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-5.1 | Smelts while UI is closed (server-side) | P0 |
| FR-5.2 | Progress bar shows current smelt (0-100%) | P0 |
| FR-5.3 | Sound effect on smelt completion | P1 |
| FR-5.4 | Fire animation when actively smelting | P1 |

### 1.5 Furnace Recipe Configuration

Furnace recipes are simpler than the old smelting recipes (no coal cost built-in - coal is now fuel):

```lua
-- FurnaceRecipes.lua (NEW)
local FurnaceRecipes = {
    -- Ore smelting (10s each)
    { input = 98, output = 105, time = 10 },   -- Copper Ore → Copper Ingot
    { input = 30, output = 33, time = 10 },    -- Iron Ore → Iron Ingot
    { input = 106, output = 110, time = 10 },  -- Tungsten Ore → Tungsten Ingot
    { input = 107, output = 111, time = 10 },  -- Titanium Ore → Titanium Ingot
    
    -- Material processing
    { input = 12, output = 20, time = 10 },    -- Sand → Glass
    { input = 3, output = 116, time = 10 },    -- Cobblestone → Stone
    { input = 17, output = 117, time = 10 },   -- Clay → Brick
    
    -- Food cooking (future)
    -- { input = RAW_BEEF, output = COOKED_BEEF, time = 10 },
}

-- Fuel burn times (in seconds)
local FuelBurnTimes = {
    [ItemIds.COAL] = 80,        -- Smelts 8 items
    [ItemIds.CHARCOAL] = 80,    -- Smelts 8 items
    [ItemIds.WOOD_PLANK] = 15,  -- Smelts 1.5 items
    [ItemIds.LOG] = 15,         -- Smelts 1.5 items
    [ItemIds.STICK] = 5,        -- Smelts 0.5 items
}
```

---

## Part 2: Smithing System (Anvil)

### 2.1 Feature Overview

The existing temperature mini-game moves to a new **Anvil** block for skill-based crafting:

```
┌─────────────────────────────────────────────────────┐
│                   SMITHING (ANVIL)                   │
│                                                      │
│   - Temperature control mini-game                    │
│   - Skill-based efficiency (saves materials)        │
│   - Used for:                                        │
│     • Steel Ingot (Iron + skill = Steel)            │
│     • Bluesteel Ingot (Iron + Dust + skill)         │
│     • Tool upgrades/repairs (future)                │
│     • Weapon enchanting (future)                    │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 2.2 What Moves to Anvil

| Recipe | From (Old) | To (New) |
|--------|------------|----------|
| Copper Ingot | Furnace (mini-game) | **Furnace (auto)** |
| Iron Ingot | Furnace (mini-game) | **Furnace (auto)** |
| Steel Ingot | Furnace (mini-game) | **Anvil (mini-game)** |
| Bluesteel Ingot | Furnace (mini-game) | **Anvil (mini-game)** |

### 2.3 Anvil-Specific Recipes

Anvil recipes use the temperature mini-game for skill expression:

```lua
-- SmithingRecipes.lua (NEW)
local SmithingRecipes = {
    -- Advanced alloys (require skill)
    smith_steel = {
        id = "smith_steel",
        name = "Steel Ingot",
        tier = 3,  -- Difficulty tier
        inputs = {
            { itemId = 33, count = 1 },  -- 1x Iron Ingot
        },
        outputs = { { itemId = 108, count = 1 } },  -- 1x Steel Ingot
        baseCoal = 2,  -- Coal cost modified by efficiency
    },
    
    smith_bluesteel = {
        id = "smith_bluesteel",
        name = "Bluesteel Ingot",
        tier = 4,  -- Harder difficulty
        inputs = {
            { itemId = 33, count = 1 },    -- 1x Iron Ingot
            { itemId = 115, count = 1 },   -- 1x Bluesteel Dust
        },
        outputs = { { itemId = 109, count = 1 } },  -- 1x Bluesteel Ingot
        baseCoal = 3,
    },
    
    -- Future: Tool upgrades
    -- upgrade_iron_pickaxe = { ... },
}
```

### 2.4 Anvil Block Definition

```lua
-- Add to Constants.lua
BlockType.ANVIL = 36  -- New block type

-- Add to BlockRegistry.lua
{
    id = BlockType.ANVIL,
    name = "Anvil",
    category = "crafting",
    textures = {
        top = "rbxassetid://ANVIL_TOP",
        bottom = "rbxassetid://ANVIL_BOTTOM",
        sides = "rbxassetid://ANVIL_SIDE"
    },
    interactable = true,
    solid = true,
    hardness = 5.0,
    requiresTool = "pickaxe",
}

-- Add to RecipeConfig.lua
anvil = {
    id = "anvil",
    name = "Anvil",
    category = RecipeConfig.Categories.TOOLS,
    inputs = {
        { itemId = 33, count = 4 },   -- 4x Iron Ingot
        { itemId = 3, count = 3 },    -- 3x Cobblestone
    },
    outputs = { { itemId = BlockType.ANVIL, count = 1 } }
}
```

### 2.5 SmithingUI (Renamed from FurnaceUI)

The existing `FurnaceUI.lua` becomes `SmithingUI.lua` with minimal changes:

- Rename file: `FurnaceUI.lua` → `SmithingUI.lua`
- Update event names: `RequestOpenFurnace` → `RequestOpenAnvil`
- Update UI title: "FURNACE" → "ANVIL"
- Keep temperature mini-game logic intact

---

## Migration Plan

### Phase 1: Separation (No Breaking Changes)

| Task | Description |
|------|-------------|
| 1.1 | Create `FurnaceConfig.lua` with fuel/recipe data |
| 1.2 | Create `FurnaceService.lua` (new auto-smelt logic) |
| 1.3 | Create simplified `FurnaceUI.lua` (slot-based) |
| 1.4 | Add ANVIL block type to Constants |

### Phase 2: Rename Existing System

| Task | Description |
|------|-------------|
| 2.1 | Rename `SmeltingService.lua` → `SmithingService.lua` |
| 2.2 | Rename `SmeltingConfig.lua` → `SmithingConfig.lua` |
| 2.3 | Rename old `FurnaceUI.lua` → `SmithingUI.lua` |
| 2.4 | Update event names in EventManifest |

### Phase 3: Recipe Migration

| Task | Description |
|------|-------------|
| 3.1 | Move basic smelting (copper, iron) to FurnaceRecipes |
| 3.2 | Move advanced smithing (steel, bluesteel) to SmithingRecipes |
| 3.3 | Add `requiresAnvil = true` flag to smithing recipes |
| 3.4 | Remove `requiresFurnace` from basic ore recipes |

### Phase 4: Tutorial Update

| Task | Description |
|------|-------------|
| 4.1 | Update `smelt_copper` tutorial to use new Furnace |
| 4.2 | Add new tutorial step for Anvil (craft steel) |
| 4.3 | Update hint text for furnace interaction |

---

## Technical Changes

### New Files

```
src/
├── ReplicatedStorage/
│   └── Configs/
│       ├── FurnaceConfig.lua        # NEW: Fuel types, burn times, recipes
│       └── SmithingConfig.lua       # RENAMED: From SmeltingConfig
│
├── ServerScriptService/
│   └── Server/
│       └── Services/
│           ├── FurnaceService.lua   # NEW: Auto-smelt logic
│           └── SmithingService.lua  # RENAMED: From SmeltingService
│
└── StarterPlayerScripts/
    └── Client/
        └── UI/
            ├── FurnaceUI.lua        # NEW: Simple slot-based UI
            └── SmithingUI.lua       # RENAMED: From FurnaceUI
```

### Modified Files

| File | Changes |
|------|---------|
| `Constants.lua` | Add `BlockType.ANVIL = 36` |
| `BlockRegistry.lua` | Add Anvil block definition |
| `BlockProperties.lua` | Add Anvil properties |
| `RecipeConfig.lua` | Update recipe flags, add Anvil recipe |
| `EventManifest.lua` | Add Anvil events, keep Furnace events |
| `BlockInteraction.lua` | Add Anvil click handler |
| `GameClient.client.lua` | Initialize both FurnaceUI and SmithingUI |
| `TutorialConfig.lua` | Update smelting tutorial |

### Event Changes

#### Furnace Events (Simple System)

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestOpenFurnace` | Client → Server | `{x, y, z}` |
| `FurnaceOpened` | Server → Client | `{position, contents, fuel, progress}` |
| `FurnaceSlotClick` | Client → Server | `{position, slotType, clickType}` |
| `FurnaceUpdated` | Server → Client | `{position, contents, fuel, progress}` |
| `RequestCloseFurnace` | Client → Server | `{x, y, z}` |

#### Anvil Events (Mini-Game System)

| Event | Direction | Payload |
|-------|-----------|---------|
| `RequestOpenAnvil` | Client → Server | `{x, y, z}` |
| `AnvilOpened` | Server → Client | `{recipes, canCraft}` |
| `RequestStartSmith` | Client → Server | `{recipeId, anvilPos}` |
| `SmithStarted` | Server → Client | `{smithConfig}` |
| `RequestCompleteSmith` | Client → Server | `{efficiency%, anvilPos}` |
| `SmithCompleted` | Server → Client | `{success, output, coalUsed}` |

---

## UI Component Specifications

### FurnaceUI Slot Layout

Following `ChestUI.lua` patterns:

```lua
local FURNACE_CONFIG = {
    -- Slot sizes (matching ChestUI)
    SLOT_SIZE = 56,
    SLOT_SPACING = 5,
    PADDING = 12,
    
    -- Colors (matching existing UI)
    PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),
    SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),
    SLOT_BG_TRANSPARENCY = 0.4,
    SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),
    SLOT_BORDER_THICKNESS = 2,
    HOVER_COLOR = Color3.fromRGB(80, 80, 80),
    CORNER_RADIUS = 8,
    SLOT_CORNER_RADIUS = 4,
    
    -- Header
    HEADER_HEIGHT = 54,
    SHADOW_HEIGHT = 18,
    
    -- Grid dimensions
    COLUMNS = 9,
    INVENTORY_ROWS = 3,
    
    -- Furnace-specific
    FURNACE_SLOT_SIZE = 64,  -- Slightly larger for furnace slots
    PROGRESS_BAR_HEIGHT = 6,
    FIRE_ICON_SIZE = 32,
    
    -- Text colors
    TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
    TEXT_MUTED = Color3.fromRGB(140, 140, 140),
    
    -- Background image
    BACKGROUND_IMAGE = "rbxassetid://82824299358542",
    BACKGROUND_IMAGE_TRANSPARENCY = 0.6,
}
```

### Fire Animation

```lua
-- Fire indicator states
local FIRE_STATES = {
    INACTIVE = {
        color = Color3.fromRGB(60, 60, 60),
        transparency = 0.5,
    },
    ACTIVE = {
        color = Color3.fromRGB(255, 150, 50),
        transparency = 0,
        -- Animated glow pulse
    },
}
```

### Progress Bar

```lua
-- Progress bar shows current smelt progress (0-100%)
-- Fills from left to right
-- Color gradient: gray → orange → yellow at 100%
local function UpdateProgressBar(progress)
    progressFill.Size = UDim2.new(progress / 100, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.fromRGB(
        255,
        math.floor(150 + (progress * 1.05)),  -- Yellow at 100%
        50
    )
end
```

---

## Appendix: Item IDs Reference

| Item | ID | Used In |
|------|----|---------|
| Copper Ore | 98 | Furnace input |
| Copper Ingot | 105 | Furnace output |
| Iron Ore | 30 | Furnace input |
| Iron Ingot | 33 | Furnace output, Anvil input |
| Steel Ingot | 108 | Anvil output |
| Bluesteel Dust | 115 | Anvil input |
| Bluesteel Ingot | 109 | Anvil output |
| Coal | varies | Fuel |
| Cobblestone | 3 | Furnace input (→ Stone) |
| Sand | 12 | Furnace input (→ Glass) |
| Glass | 20 | Furnace output |

---

*Document Version: 1.0*
*Created: February 2026*
*Related: [PRD_FURNACE.md](./PRD_FURNACE.md) (Original, deprecated)*
