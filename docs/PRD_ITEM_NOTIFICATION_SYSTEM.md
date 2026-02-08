# Product Requirements Document: Item Notification System
## Skyblox - Visual Item Acquisition Feedback

> **Status**: Ready for Implementation
> **Priority**: P1 (High - Quality-of-Life Polish)
> **Estimated Effort**: Small-Medium (2-3 days)
> **Last Updated**: February 2026

---

## Executive Summary

The Item Notification System provides visual feedback whenever a player acquires items through any means — pickup, crafting, mining, quest rewards, etc. A temporary notification slides in from the left side of the screen showing the item icon, name, and quantity received, creating a satisfying and informative gameplay loop.

### Why This Matters
- **Player Feedback Gap**: Players currently receive no on-screen visual confirmation when items enter their inventory — only a sound effect (`inventoryPop`) plays
- **Core Loop Reinforcement**: The GATHER → CRAFT → UPGRADE loop feels more rewarding when each acquisition is visually acknowledged
- **Discoverability**: New players learn what items they're collecting without needing to open inventory
- **Polish Benchmark**: Standard feature in Minecraft and all voxel-sandbox games that players expect

---

## Table of Contents

1. [Current State & Gap Analysis](#current-state--gap-analysis)
2. [Feature Overview](#feature-overview)
3. [Detailed Requirements](#detailed-requirements)
4. [UI/UX Specification](#uiux-specification)
5. [Grouping & Deduplication Logic](#grouping--deduplication-logic)
6. [Technical Architecture](#technical-architecture)
7. [Integration Points](#integration-points)
8. [Implementation Plan](#implementation-plan)
9. [Edge Cases & Constraints](#edge-cases--constraints)
10. [Future Enhancements](#future-enhancements)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| `ToastManager` | `Client/Managers/ToastManager.lua` | ✅ Text-only toasts (bottom-right, no item icons) |
| `SoundManager` pickup SFX | `GameConfig.lua` → `inventoryPop` | ✅ Audio feedback on item gain |
| `ItemPickedUp` event | `EventManifest.lua` (Server→Client) | ✅ Fires `{itemId, count}` on pickup |
| `HotbarSlotUpdate` event | `EventManifest.lua` (Server→Client) | ✅ Fires with old/new stack data |
| `InventorySlotUpdate` event | `EventManifest.lua` (Server→Client) | ✅ Fires with old/new stack data |
| `InventorySync` event | `EventManifest.lua` (Server→Client) | ✅ Full inventory resync |
| `didGainItems()` helper | `ClientInventoryManager.lua:30` | ✅ Detects when a slot gained items |
| `BlockViewportCreator` | `Shared/VoxelWorld/Rendering/BlockViewportCreator.lua` | ✅ Renders items as 3D viewports or 2D icons |
| `ItemRegistry` | `Configs/ItemRegistry.lua` | ✅ Unified item name/data lookup |
| `UIScaler` | `Client/Managers/UIScaler.lua` | ✅ Responsive scaling via CollectionService tags |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| `ItemNotificationManager.lua` | Core notification display & queue logic | P0 |
| Item icon rendering in notifications | Visual item identification | P0 |
| Slide-in/fade-out animations | Polished feel | P0 |
| Same-item grouping/coalescing | Bulk pickup handling (e.g., mining 10 stone) | P0 |
| Source context labels | Optional "Picked Up", "Crafted", etc. | P1 |
| Integration hooks in existing systems | Trigger notifications from all acquisition paths | P0 |
| New event: `ItemAcquired` (optional) | Unified acquisition signal across all sources | P2 |

---

## Feature Overview

### Notification Anatomy

```
┌──────────────────────────────────────────┐
│  ┌──────┐                                │
│  │ ICON │  Stone Block          ×12      │
│  │      │  ᴾⁱᶜᵏᵉᵈ ᵁᵖ                   │
│  └──────┘                                │
└──────────────────────────────────────────┘
```

Each notification contains:
- **Item Icon**: 3D viewport (blocks) or 2D image (items) — same rendering as inventory slots via `BlockViewportCreator`
- **Item Name**: From `ItemRegistry.GetItemName(itemId)` — bold, white text
- **Quantity**: `×N` count — slightly smaller, accent color
- **Source Context** (optional): "Picked Up", "Crafted", "Mined", "Quest Reward" — small, dimmed text

### Display Behavior

| Property | Value | Rationale |
|----------|-------|-----------|
| Position | Left side, vertically centered | Non-intrusive; away from hotbar (bottom), health bars (top-left), and toasts (bottom-right) |
| Anchor | `AnchorPoint(0, 0.5)`, `Position(0, 20, 0.5, 0)` | 20px inset from left edge, centered vertically |
| Stacking | Vertical, newest at bottom | Natural reading order; oldest scrolls up and out |
| Max Visible | 5 | Prevents screen clutter |
| Duration | 3 seconds per notification | Long enough to read, short enough to not annoy |
| Fade-out | 0.4s transparency tween | Smooth disappearance |
| Slide-in | 0.3s from left (Back easing Out) | Matches existing tween patterns |
| Queue | FIFO, max 15 queued | Handles burst acquisitions |

---

## Detailed Requirements

### FR-1: Core Notification Display (P0)

**FR-1.1** When a player gains an item, a notification appears on the left side of the screen within 1 frame of the inventory update.

**FR-1.2** The notification displays:
- Item icon rendered via `BlockViewportCreator.CreateBlockViewport()` for blocks (3D viewport) or `BlockViewportCreator.RenderItemSlot()` for items (2D image)
- Item name from `ItemRegistry.GetItemName(itemId)`
- Quantity in `×N` format (e.g., `×3`, `×1`)

**FR-1.3** Notifications auto-dismiss after 3 seconds with a fade-out animation.

**FR-1.4** Multiple notifications stack vertically with 6px spacing, newest at bottom.

**FR-1.5** When more than 5 notifications are active, the oldest is force-dismissed to make room.

### FR-2: Animations (P0)

**FR-2.1** Entry: Slide in from left (X offset -200 → 0), 0.3s, `EasingStyle.Back`, `EasingDirection.Out`. Simultaneously fade in (transparency 1 → 0).

**FR-2.2** Exit: Fade out (transparency 0 → 1) over 0.4s, `EasingStyle.Quad`, `EasingDirection.In`. Slide left slightly (-30px).

**FR-2.3** Stack reflow: When a notification is removed, remaining notifications smoothly slide to fill the gap (0.2s, `EasingStyle.Quad`, `EasingDirection.Out`).

### FR-3: Same-Item Grouping (P0)

**FR-3.1** When the same `itemId` is acquired while an existing notification for that item is still visible, the existing notification's count is updated (incremented) instead of creating a new notification.

**FR-3.2** On count update, play a brief "bump" animation (scale 1.0 → 1.05 → 1.0, 0.15s) on the count label to draw attention.

**FR-3.3** The coalescing window resets the notification's dismiss timer back to 3 seconds on each update.

**FR-3.4** Different `itemId`s always create separate notifications, even if acquired simultaneously.

### FR-4: Source Context Labels (P1)

**FR-4.1** Notifications may optionally include a source context string displayed below the item name in smaller, dimmed text.

**FR-4.2** Predefined source contexts:

| Source | Context String | Trigger |
|--------|----------------|---------|
| World pickup | `"Picked Up"` | `ItemPickedUp` event |
| Block mining | `"Mined"` | `BlockBroken` → slot gain |
| Crafting | `"Crafted"` | Crafting panel output taken |
| Smelting | `"Smelted"` | Furnace output taken |
| Quest reward | `"Quest Reward"` | Quest reward claimed |
| NPC trade | `"Purchased"` | NPC buy transaction |
| Chest loot | `"Looted"` | Chest → inventory transfer |

**FR-4.3** If no source context is provided, the notification shows only the item name and count (no empty space).

### FR-5: Responsive Scaling (P0)

**FR-5.1** The notification container uses `UIScale` with `base_resolution = Vector2.new(1920, 1080)` and the `"scale_component"` tag, managed by the existing `UIScaler` system.

**FR-5.2** On mobile (touch devices), notifications scale down via the existing `MOBILE_SCALE_MULTIPLIER` (0.72).

**FR-5.3** Notification width is fixed at 260px at base resolution. Height is 52px (or 64px with source context).

### FR-6: Visibility Control (P1)

**FR-6.1** Notifications are hidden during loading screens.

**FR-6.2** The system exposes `SetEnabled(bool)` to allow other systems to suppress notifications (cutscenes, tutorials, etc.).

**FR-6.3** Notifications do NOT show for internal inventory reorganization (slot swaps, drag-and-drop within inventory panel). Only server-initiated slot changes that result in item gain trigger notifications.

---

## UI/UX Specification

### Visual Design

```lua
-- Notification frame styling (matches inventory panel dark theme)
NOTIFICATION_CONFIG = {
    -- Container
    container = {
        position = UDim2.new(0, 20, 0.5, 0),   -- Left side, vertically centered
        anchorPoint = Vector2.new(0, 0.5),
        size = UDim2.fromOffset(280, 400),        -- Container bounds
    },

    -- Individual notification
    notification = {
        width = 260,
        height = 52,                               -- 64 with source context
        cornerRadius = 6,
        backgroundColor = Color3.fromRGB(24, 24, 24),
        backgroundTransparency = 0.15,             -- Slightly translucent
        borderColor = Color3.fromRGB(60, 60, 60),
        borderThickness = 1,
    },

    -- Item icon
    icon = {
        size = 36,                                  -- 36×36px icon area
        padding = 8,                                -- Left padding
    },

    -- Text
    text = {
        nameColor = Color3.fromRGB(255, 255, 255),  -- White
        nameSize = 14,                               -- Bold
        countColor = Color3.fromRGB(170, 220, 100),  -- Soft green accent
        countSize = 14,                              -- Bold
        contextColor = Color3.fromRGB(160, 160, 160),-- Dimmed gray
        contextSize = 11,                            -- Regular weight
    },

    -- Timing
    timing = {
        displayDuration = 3,                         -- Seconds before auto-dismiss
        slideInDuration = 0.3,
        fadeOutDuration = 0.4,
        reflowDuration = 0.2,
        bumpDuration = 0.15,
    },

    -- Limits
    maxVisible = 5,
    maxQueued = 15,
    spacing = 6,
}
```

### Layout (Left-to-Right)

```
8px | [36×36 icon] | 8px | [Item Name     ×Count] | 8px
                          | [Source Context]        |
```

- Icon occupies a fixed 36×36 area, vertically centered
- Name and count share the same line: name left-aligned, count right-aligned
- Source context (if present) sits below the name line, left-aligned
- All text uses `BOLD_FONT` from `Config.UI_SETTINGS.typography.fonts.bold` except source context which uses regular

### Z-Index Layering

```lua
zIndex = {
    screenGui = 4500,      -- Below ToastManager (5000) but above most panels
    container = 4501,
    notification = 4502,
    icon = 4503,
    text = 4504,
}
```

The `ScreenGui.DisplayOrder` is set to 4500 — below `ToastManager` (5000) so toasts always render on top, but above inventory panels and HUD elements.

---

## Grouping & Deduplication Logic

### Algorithm

```
On item acquired (itemId, count, sourceContext):
  1. Search activeNotifications for matching itemId
  2. If found AND still visible:
     a. Increment displayed count by `count`
     b. Reset dismiss timer to 3s
     c. Play bump animation on count label
     d. Return (no new notification created)
  3. If not found:
     a. Create new notification with itemId, count, sourceContext
     b. If activeNotifications >= maxVisible:
        - Force-dismiss oldest notification immediately
     c. Animate in the new notification
     d. Start 3s dismiss timer
```

### Bulk Acquisition Scenarios

| Scenario | Behavior |
|----------|----------|
| Mine 1 stone | Single notification: `Stone ×1` |
| Mine 10 stone rapidly | Single notification updates: `Stone ×1` → `×2` → ... → `×10` |
| Mine 3 stone + 2 coal | Two notifications: `Stone ×3`, `Coal ×2` |
| Craft 1 iron pickaxe | Single notification: `Iron Pickaxe ×1 — Crafted` |
| Pick up stack of 64 dirt | Single notification: `Dirt ×64` |
| Full inventory sync (join/respawn) | Suppressed — no notifications on `InventorySync` |

---

## Technical Architecture

### New File: `ItemNotificationManager.lua`

**Location**: `src/StarterPlayerScripts/Client/Managers/ItemNotificationManager.lua`

**Module Pattern**: Singleton module (same pattern as `ToastManager`)

```lua
-- Module structure
local ItemNotificationManager = {}

-- Dependencies
local BlockViewportCreator  -- For rendering item icons
local ItemRegistry          -- For item name lookup
local UIScaler integration  -- Via CollectionService tag
local TweenService          -- For animations
local Config                -- For typography/fonts

-- State
local activeNotifications = {}  -- {itemId → notificationData}
local notificationQueue = {}    -- FIFO overflow queue
local screenGui = nil           -- ScreenGui parent
local container = nil           -- Container frame

-- Public API
function ItemNotificationManager:Initialize()
function ItemNotificationManager:ShowItemAcquired(itemId, count, sourceContext)
function ItemNotificationManager:SetEnabled(enabled)
function ItemNotificationManager:Destroy()

return ItemNotificationManager
```

### Data Flow

```
Server                          Client
──────                          ──────
DroppedItemService              DroppedItemController
  └─ FireEvent("ItemPickedUp")    └─ OnItemPickedUp()
       {itemId, count}                └─ Plays sound
                                      └─ NEW: ItemNotificationManager:ShowItemAcquired(
                                              data.itemId, data.count, "Picked Up")

PlayerInventoryService          ClientInventoryManager
  └─ FireEvent("HotbarSlotUpdate")  └─ didGainItems() check
       {slotIndex, stack}              └─ Plays sound
                                       └─ NEW: ItemNotificationManager:ShowItemAcquired(
                                               newItemId, gainedCount)

  └─ FireEvent("InventorySlotUpdate") └─ didGainItems() check
       {slotIndex, stack}              └─ Plays sound
                                       └─ NEW: ItemNotificationManager:ShowItemAcquired(
                                               newItemId, gainedCount)
```

### Preventing Duplicate Notifications

A single item pickup can fire BOTH `ItemPickedUp` AND a slot update (`HotbarSlotUpdate`/`InventorySlotUpdate`). To avoid showing two notifications for the same acquisition:

**Strategy: Deduplication Window**
- When `ItemPickedUp` fires, record `{itemId, count, timestamp}` in a short-lived dedup table
- When a slot update detects a gain via `didGainItems()`, check if a matching `{itemId}` entry exists in the dedup table within the last 200ms
- If found: skip the notification (it was already shown via `ItemPickedUp`)
- If not found: show the notification (this was a non-pickup gain, e.g., crafting, server grant)

```lua
-- Dedup table
local recentPickups = {}  -- {itemId → timestamp}
local DEDUP_WINDOW = 0.2  -- 200ms

-- On ItemPickedUp:
recentPickups[data.itemId] = os.clock()
ItemNotificationManager:ShowItemAcquired(data.itemId, data.count, "Picked Up")

-- On slot gain detected in ClientInventoryManager:
local now = os.clock()
local lastPickup = recentPickups[newItemId]
if lastPickup and (now - lastPickup) < DEDUP_WINDOW then
    -- Skip, already notified via ItemPickedUp
    recentPickups[newItemId] = nil
else
    ItemNotificationManager:ShowItemAcquired(newItemId, gainedCount)
end
```

### Item Icon Rendering

Use `BlockViewportCreator` for consistency with inventory:

```lua
local function renderItemIcon(container, itemId)
    -- Clear previous icon
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("ViewportFrame") or child:IsA("ImageLabel") then
            child:Destroy()
        end
    end

    -- Render using the same system as inventory slots
    BlockViewportCreator.CreateBlockViewport(container, itemId)
end
```

This ensures blocks show as rotated 3D cubes and items show as 2D textures — identical to how they appear in the hotbar and inventory panel.

---

## Integration Points

### 1. DroppedItemController (World Pickup)

**File**: `Client/Controllers/DroppedItemController.lua`
**Function**: `OnItemPickedUp(data)`
**Current behavior**: Plays `inventoryPop` sound
**Change**: Add notification call after sound

```lua
function DroppedItemController:OnItemPickedUp(data)
    if not data then return end
    if SoundManager and SoundManager.PlaySFX then
        SoundManager:PlaySFX("inventoryPop")
    end
    -- NEW: Show item notification
    if ItemNotificationManager then
        ItemNotificationManager:ShowItemAcquired(data.itemId, data.count, "Picked Up")
    end
end
```

### 2. ClientInventoryManager (Server Slot Updates)

**File**: `Client/Managers/ClientInventoryManager.lua`
**Functions**: `HotbarSlotUpdate` handler (line 296), `InventorySlotUpdate` handler (line 312)
**Current behavior**: Calls `didGainItems()` → plays `inventoryPop`
**Change**: Also trigger notification for non-pickup gains (with dedup check)

### 3. CraftingPanel (Crafting Output)

**File**: `Client/UI/CraftingPanel.lua`
**When**: Player takes crafted item from output slot
**Source context**: `"Crafted"`

### 4. FurnaceUI (Smelting Output)

**When**: Player takes smelted item from furnace output
**Source context**: `"Smelted"`

### 5. ChestUI (Chest Looting)

**When**: Items transferred from chest to player inventory
**Source context**: `"Looted"`

### 6. NPC Shop (Purchases)

**When**: Player buys item from NPC shop
**Source context**: `"Purchased"`

### 7. InventorySync (Suppressed)

**File**: `Client/Managers/ClientInventoryManager.lua`
**Function**: `SyncFromServer()`
**Behavior**: Full syncs (on join/respawn) do NOT trigger notifications. The `_syncingFromServer` flag already exists and can be checked.

---

## Implementation Plan

### Phase 1: Core System (Day 1)

| Task | Description | Files |
|------|-------------|-------|
| 1.1 | Create `ItemNotificationManager.lua` with ScreenGui, container, UIScale | New file |
| 1.2 | Implement `ShowItemAcquired()` — create notification frame with icon, name, count | New file |
| 1.3 | Implement slide-in animation (TweenService) | New file |
| 1.4 | Implement auto-dismiss with fade-out animation | New file |
| 1.5 | Implement vertical stacking with UIListLayout | New file |
| 1.6 | Implement same-item coalescing (update count, bump animation, timer reset) | New file |

### Phase 2: Integration (Day 2)

| Task | Description | Files |
|------|-------------|-------|
| 2.1 | Initialize `ItemNotificationManager` in `GameClient.client.lua` (after UIScaler, before controllers) | `GameClient.client.lua` |
| 2.2 | Hook into `DroppedItemController:OnItemPickedUp()` | `DroppedItemController.lua` |
| 2.3 | Hook into `ClientInventoryManager` slot update handlers with dedup logic | `ClientInventoryManager.lua` |
| 2.4 | Suppress during `InventorySync` (full resync) | `ClientInventoryManager.lua` |
| 2.5 | Add source context for CraftingPanel output | `CraftingPanel.lua` |

### Phase 3: Polish (Day 2-3)

| Task | Description | Files |
|------|-------------|-------|
| 3.1 | Add source context for Furnace, Chest, NPC shop | Various UI files |
| 3.2 | Test edge cases: rapid mining, bulk pickup, inventory full | Manual testing |
| 3.3 | Verify responsive scaling on mobile (UIScaler integration) | `ItemNotificationManager.lua` |
| 3.4 | Verify z-index ordering doesn't conflict with existing panels | `ItemNotificationManager.lua` |
| 3.5 | Tune timing values (duration, animation speeds) based on playtesting | Config constants |

---

## Edge Cases & Constraints

### Don't Notify

| Scenario | Reason |
|----------|--------|
| Drag-and-drop within inventory panel | Internal reorganization, not acquisition |
| Full inventory sync on join/respawn | Would spam 36 notifications; use `_syncingFromServer` flag |
| Chest/Furnace action results (`ChestActionResult`, `FurnaceActionResult`) | These resync entire inventory; handled by slot update dedup |
| Moving items between armor slots | Equipment management, not acquisition |

### Handle Gracefully

| Scenario | Handling |
|----------|----------|
| 10+ rapid acquisitions (e.g., mining tunnel) | Same-item coalescing combines into single notification; max 5 visible |
| Unknown item ID | Show item ID as fallback text; log warning |
| ItemNotificationManager not yet initialized | Guard with nil check at all call sites |
| Player dying while notifications visible | Clear all active notifications on `PlayerDied` event |
| Screen resize during display | UIScaler handles automatically via `"scale_component"` tag |

### Performance Budget

- **Instance creation**: One `Frame` + one `ViewportFrame`/`ImageLabel` + 2-3 `TextLabel`s per notification (max 5 visible = ~25 instances)
- **Tweens**: Max 2 concurrent tweens per notification (slide + fade)
- **Memory**: Reuse notification frames from a small pool (optional optimization for Phase 2+)
- **No per-frame cost**: All animations use TweenService (not RenderStepped)

---

## Future Enhancements

| Enhancement | Priority | Notes |
|-------------|----------|-------|
| Rare item glow effect | P2 | Gold border / shimmer for rare+ tier items |
| Sound variation by item type | P2 | Different sounds for tools vs blocks vs food; via `SoundManager` |
| Click notification to highlight in inventory | P2 | Would require making notifications interactive (out of current scope) |
| XP/currency notifications in same system | P2 | Extend to show `+50 XP` or `+10 Coins` with appropriate icons |
| Configurable position (settings) | P3 | Let players choose left/right/center |
| Notification history log | P3 | Scrollable list of recent acquisitions |

---

## Success Criteria

- [ ] Players immediately see what item they received when picking up drops
- [ ] Mining 10+ blocks rapidly produces clean, grouped notifications (not 10 separate popups)
- [ ] Crafting, smelting, and looting all show contextual notifications
- [ ] Notifications never obscure the hotbar, health bars, or combat UI
- [ ] System handles edge cases gracefully (rapid pickup, full inventory, unknown items)
- [ ] Scales correctly on all screen sizes including mobile
- [ ] No measurable FPS impact (TweenService-based, no per-frame cost)
- [ ] Feels polished — smooth animations, readable at a glance, not spammy
