# Camera & Input System Documentation

> Complete reference for camera modes, input handling, cursor management, and UI interaction.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Camera Modes](#camera-modes)
3. [Input System](#input-system)
4. [Cursor Management](#cursor-management)
5. [UI Modes & Toggles](#ui-modes--toggles)
6. [Control Bindings](#control-bindings)
7. [GameState Integration](#gamestate-integration)
8. [Mobile Support](#mobile-support)

---

## Architecture Overview

The camera and input system follows a layered architecture where each component has a single responsibility:

```
┌─────────────────────────────────────────────────────────────┐
│                    User Input (KB/Mouse/Touch/Gamepad)      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       InputService                           │
│  • Wraps UserInputService                                   │
│  • Provides unified signals (PrimaryDown, SecondaryDown)    │
│  • Manages cursor mode stack via CursorService              │
│  • Coordinates gameplay locks via GameplayLockController    │
└─────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────────────┐
│ CameraController │ │  UIBackdrop  │ │  Game Controllers    │
│ • 3 camera modes │ │ • Blur/overlay│ │ • BlockInteraction   │
│ • FOV/bobbing    │ │ • Modal mouse │ │ • CombatController   │
│ • Char rotation  │ │   release     │ │ • BowController      │
└──────────────────┘ └──────────────┘ └──────────────────────┘
              │               │               │
              └───────────────┴───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                         GameState                            │
│  camera.isFirstPerson  │  ui.mode  │  ui.backdropActive     │
└─────────────────────────────────────────────────────────────┘
```

### Key Principles

1. **Single Source of Truth**: `CameraController` owns camera state, `InputService` owns cursor state
2. **Stack-Based Cursor**: UI components push/pop cursor modes; topmost entry wins
3. **Declarative States**: Camera modes are defined as configuration objects, not imperative code
4. **Frame Enforcement**: Both `CameraController` and `UIBackdrop` enforce their state every frame to counteract Roblox's PlayerModule interference

---

## Camera Modes

The camera system supports **three distinct modes**, cycled with `F5`:

### First Person (`FIRST_PERSON`)

```lua
{
    cursorMode = "gameplay-lock",      -- Mouse locked to center
    cameraMode = Enum.CameraMode.LockFirstPerson,
    zoomDistance = 0.5,
    baseFov = 80,
    maxFov = 96,                       -- Dynamic FOV when sprinting
    dynamicFov = true,
    cameraOffset = Vector3.new(0, 0, 0),
    enableBobbing = true,              -- Head bob when walking
    characterRotation = "auto"         -- Roblox handles rotation
}
```

**Behavior:**
- Mouse cursor hidden, locked to screen center
- Camera attached to character head
- Dynamic FOV increases with sprint speed (80 → 96)
- Immersive head bobbing when moving
- FOV zoom effect when bow is fully charged

### Third Person Lock (`THIRD_PERSON_LOCK`)

```lua
{
    cursorMode = "gameplay-lock",      -- Mouse locked to center
    cameraMode = Enum.CameraMode.Classic,
    zoomDistance = 12,
    baseFov = 70,
    cameraOffset = Vector3.new(1.5, 1, 0),  -- Over-shoulder offset
    enableBobbing = false,
    characterRotation = "camera-forward"    -- Character faces camera direction
}
```

**Behavior:**
- Mouse cursor hidden, locked to center
- Fixed camera distance (12 studs)
- Over-the-shoulder camera offset
- Character always faces where camera looks
- Good for combat/action gameplay

### Third Person Free (`THIRD_PERSON_FREE`)

```lua
{
    cursorMode = "gameplay-free",      -- Mouse visible, free movement
    cameraMode = Enum.CameraMode.Classic,
    zoomDistance = 12,
    baseFov = 70,
    cameraOffset = Vector3.new(0, 1, 0),
    enableBobbing = false,
    characterRotation = "mouse-raycast"    -- Character faces mouse target
}
```

**Behavior:**
- Mouse cursor visible and free
- Fixed camera distance (12 studs)
- Character rotates to face where mouse is pointing (raycast)
- Good for building/strategy gameplay
- Click targeting uses mouse position

### State Transitions

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│   FIRST_PERSON ──F5──► THIRD_PERSON_LOCK ──F5──► THIRD_PERSON_FREE
│        ▲                                              │    │
│        └──────────────────── F5 ──────────────────────┘    │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

### Camera Freezing

When UI panels open (inventory, settings, etc.), the camera **freezes**:

1. `UIBackdrop:Show()` sets `GameState["ui.backdropActive"] = true`
2. `CameraController` listens and calls `SetFrozen(true)`
3. Camera mode switches to `Classic` to release Roblox's mouse lock
4. Pending state changes queue until UI closes
5. On close, camera restores previous/pending state

---

## Input System

### InputService

Central hub for all input handling. Located at:
`src/StarterPlayerScripts/Client/Input/InputService.lua`

**Signals:**

| Signal | Description |
|--------|-------------|
| `InputBegan` | Raw input started (mirrors UserInputService) |
| `InputEnded` | Raw input ended |
| `InputChanged` | Input value changed (mouse move, etc.) |
| `PrimaryDown` | Primary action started (LMB / Touch / R2 / X) |
| `PrimaryUp` | Primary action released |
| `SecondaryDown` | Secondary action started (RMB / L2 / B) |
| `SecondaryUp` | Secondary action released |
| `InteractRequested` | Interact button pressed (mobile) |
| `InputModeChanged` | Switched between touch/gamepad/mouseKeyboard |
| `CursorModeChanged` | Cursor mode stack changed |
| `GameplayLockChanged` | Gameplay lock state changed |

**Input Mode Detection:**

```lua
local mode = GameState:Get("input.mode")
-- "mouseKeyboard" | "touch" | "gamepad"
```

### Primary/Secondary Actions

The system abstracts platform-specific inputs into unified actions:

| Action | Mouse | Gamepad | Touch |
|--------|-------|---------|-------|
| Primary | Left Click | R2 / X | Tap / Attack Button |
| Secondary | Right Click | L2 / B | UseItem Button |

### Gameplay Lock

When UI is open, gameplay inputs are blocked:

```lua
-- Check if gameplay should be blocked
if InputService:IsGameplayBlocked() then
    return -- Don't process gameplay input
end

-- Or inversely
if InputService:IsGameplayActive() then
    -- Process gameplay input
end
```

The lock suppresses movement keys (WASD, Space, Shift) and disables mobile controls.

---

## Cursor Management

### Cursor Service

Stack-based cursor state management. The topmost entry determines cursor behavior.

**Cursor Modes:**

| Mode | Mouse Behavior | Icon Visible | Use Case |
|------|---------------|--------------|----------|
| `gameplay-lock` | `LockCenter` | No | First person, combat |
| `gameplay-free` | `Default` | Yes | Third person free mode |
| `ui` | `Default` | Yes | Inventory, menus |
| `cinematic` | `Default` | No | Cutscenes |

### Stack Operations

**UI Opening a Panel:**

```lua
-- Push cursor mode when UI opens
local token = InputService:PushCursorMode("InventoryPanel", "ui", {
    showIcon = true
})

-- Pop when UI closes
InputService:PopCursorMode(token)
```

**Convenience Method:**

```lua
-- BeginOverlay handles both cursor and gameplay lock
local release = InputService:BeginOverlay("ChestUI")

-- Later, when closing
release()
```

### Stack Example

```
Initial State:
  [1] __gameplay__ (gameplay-lock) ← Base layer

Open Inventory:
  [1] __gameplay__ (gameplay-lock)
  [2] InventoryPanel_1 (ui) ← Active, cursor visible

Open Settings on top:
  [1] __gameplay__ (gameplay-lock)
  [2] InventoryPanel_1 (ui)
  [3] SettingsPanel_2 (ui) ← Active

Close Settings:
  [1] __gameplay__ (gameplay-lock)
  [2] InventoryPanel_1 (ui) ← Active again

Close Inventory:
  [1] __gameplay__ (gameplay-lock) ← Back to gameplay
```

---

## UI Modes & Toggles

### UIVisibilityManager

Central coordinator for UI panel visibility. Defines modes that control which components are shown.

**Available Modes:**

| Mode | Visible Components | Hidden Components | Backdrop |
|------|-------------------|-------------------|----------|
| `gameplay` | MainHUD, Hotbar, StatusBars, Crosshair | WorldsPanel | None |
| `inventory` | VoxelInventory | MainHUD, Hotbar, StatusBars, WorldsPanel | Blur 24px |
| `chest` | ChestUI | MainHUD, Hotbar, StatusBars, WorldsPanel | Blur 24px |
| `menu` | SettingsPanel | All game UI | Blur 32px |
| `worlds` | WorldsPanel | All game UI + inventory | Blur 24px |
| `minion` | MinionUI | All game UI | Blur 24px |

### Mode Transitions

```lua
-- Open inventory
UIVisibilityManager:SetMode("inventory")

-- Return to gameplay
UIVisibilityManager:SetMode("gameplay")
```

### Backdrop Effects

When a mode has `backdrop = true`, UIBackdrop applies:

1. **Blur Effect** - BlurEffect in Lighting (configurable size)
2. **Dark Overlay** - Semi-transparent overlay covering screen
3. **Modal Mouse Release** - `Modal = true` releases Roblox's mouse lock
4. **Frame Enforcement** - Continuously enforces `MouseBehavior.Default`

### Toggle Interactions

**Inventory Toggle (E key):**

```lua
-- In GameClient.lua
if input.KeyCode == Enum.KeyCode.E then
    local inventoryPanel = -- get reference
    inventoryPanel:Toggle()
end
```

**Camera Mode Toggle (F5 key):**

```lua
-- In CameraController
if input.KeyCode == Enum.KeyCode.F5 then
    self:CycleMode()
end
```

**Camera Mode Toggle (HUD Button):**

```lua
-- MainHUD has a button that toggles camera.isFirstPerson
local current = GameState:Get("camera.isFirstPerson")
GameState:Set("camera.isFirstPerson", not current)

-- CameraController listens and transitions:
-- true → FIRST_PERSON
-- false → THIRD_PERSON_FREE
```

---

## Control Bindings

### Keyboard

| Key | Action |
|-----|--------|
| `W/A/S/D` | Movement |
| `Space` | Jump |
| `Left Shift` | Sprint (hold) |
| `E` | Toggle Inventory |
| `B` | Toggle Crafting |
| `Escape` | Close current panel / Open settings |
| `F5` | Cycle camera mode |
| `Q` | Drop item |
| `1-9` | Select hotbar slot |

### Mouse

| Input | Action (First Person) | Action (Third Person Free) |
|-------|----------------------|---------------------------|
| Left Click | Break block / Attack | Break block / Attack |
| Right Click | Place block / Use item | Place block at cursor / Use item |
| Mouse Move | Look around | Orbit camera |
| Scroll | (disabled) | (disabled - fixed zoom) |

### Gamepad

| Button | Action |
|--------|--------|
| Left Stick | Movement |
| Right Stick | Camera |
| A | Jump |
| X / R2 | Primary action |
| B / L2 | Secondary action |

### Mobile

| Gesture | Action |
|---------|--------|
| Left Thumbstick | Movement |
| Right Touch Area | Camera rotation |
| Attack Button | Primary action |
| UseItem Button | Secondary action |
| Jump Button | Jump |

---

## GameState Integration

### Camera State

```lua
-- Check current camera mode
local isFirstPerson = GameState:Get("camera.isFirstPerson")

-- Listen for camera changes
GameState:OnPropertyChanged("camera.isFirstPerson", function(newValue)
    if newValue then
        -- First person mode active
    else
        -- Third person mode active
    end
end)
```

### UI State

```lua
-- Check current UI mode
local uiMode = GameState:Get("ui.mode")  -- "gameplay", "inventory", etc.

-- Check if backdrop is active (UI is blocking gameplay)
local isUIOpen = GameState:Get("ui.backdropActive")

-- Get visible components
local visible = GameState:Get("ui.visibleComponents")
```

### Input State

```lua
-- Get current input mode
local inputMode = GameState:Get("input.mode")  -- "mouseKeyboard", "touch", "gamepad"
```

---

## Mobile Support

### MobileControlController

Provides touch controls when on mobile devices:

- **Left Thumbstick**: Movement
- **Right Touch Zone**: Camera rotation (swipe)
- **Action Buttons**: Attack, UseItem, Jump, Sprint

### Automatic Detection

```lua
-- InputService automatically detects mobile
function InputService:_shouldUseMobileController()
    return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
```

### High Contrast Mode

For accessibility, mobile controls support high contrast:

```lua
InputService:SetHighContrast(true)
-- or via GameState
GameState:Set("settings.highContrast", true)
```

---

## Feature Flag

The mouse lock and multi-camera system can be disabled via feature flag:

```lua
-- In GameConfig
GameConfig.IsFeatureEnabled("MouseLock")  -- true/false
```

When disabled:
- Camera stays in Classic mode
- Cursor is always free (`gameplay-free`)
- F5 cycling is disabled
- Character rotation handled by Roblox default

---

## Debugging

### Print Cursor Stack

```lua
InputService:PrintCursorDebug()
-- Output:
-- [InputService] Cursor Diagnostics
-- Active Mode: ui (source: InventoryPanel)
-- Stack Depth: 2
--   [2] ui (InventoryPanel)
--   [1] gameplay-lock (gameplay)
```

### Verify Stack Integrity

```lua
local isValid = InputService:VerifyCursorStackIntegrity()
-- Returns false if gameplay base entry is missing
```

---

## Summary

| System | Responsibility | Key File |
|--------|---------------|----------|
| CameraController | Camera modes, FOV, bobbing, character rotation | `Controllers/CameraController.lua` |
| InputService | Input abstraction, cursor stack, gameplay locks | `Input/InputService.lua` |
| CursorService | Stack-based cursor state management | `Input/CursorService.lua` |
| GameplayLockController | Block inputs when UI open | `Input/GameplayLockController.lua` |
| UIVisibilityManager | UI mode coordination | `Managers/UIVisibilityManager.lua` |
| UIBackdrop | Blur, overlay, modal mouse release | `UI/UIBackdrop.lua` |

