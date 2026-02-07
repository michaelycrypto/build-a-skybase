# PRD: Right-Side Info Panel (v1)

**Status:** Draft
**Scope:** HUD / Client UI

---

## 1. Why we're building this

Players need one place to see **currencies**, **which world they’re in (and who owns it)**, and **current tutorial step**—without scanning the top bar or action bar. A right-side panel keeps this info visible and consistent.

**Success:** Player can answer “How much do I have?”, “Whose world is this?”, and “What am I supposed to do next?” at a glance.

---

## 2. What we're building (v1)

A single, compact panel on the **right edge of the screen** with three blocks, top to bottom:

| Block | Content | Data source |
|-------|---------|-------------|
| **Currencies** | Coins + Gems (icon + value, same formatting as today e.g. K/M/B) | `GameState` → `playerData.coins`, `playerData.gems` |
| **World** | World name + owner; “(You)” when local player is owner | `WorldOwnershipInfo` event (same as current `WorldOwnershipDisplay`) |
| **Tutorial** | Current step title (or short label); hidden when tutorial inactive or complete | `TutorialManager:GetCurrentStep()` + `TutorialConfig` steps |

Reuse existing systems; no new backend. Panel follows existing HUD styling (e.g. hotbar/action bar: background, border) and **UIVisibilityManager** (hides with rest of HUD when appropriate).

---

## 3. Requirements

| ID | Requirement |
|----|-------------|
| R1 | Panel anchored to **right edge** of viewport; vertical alignment: **top-right** with consistent offset from edge (e.g. below top bar). |
| R2 | **Currency block**: show coins and gems with icons + values; format as elsewhere (K/M/B). Bind to GameState. |
| R3 | **World block**: show world name and owner; indicate “(You)” when local player is owner. Consume `WorldOwnershipInfo` (can replace or integrate current `WorldOwnershipDisplay`). |
| R4 | **Tutorial block**: when tutorial is active, show current step title/label only. When inactive or complete: **hide block** (no “Tutorial complete” line in v1). |
| R5 | **Visual style**: match existing HUD (background, border, typography). Fits current “SkyBlock-style” look. |
| R6 | **Visibility**: respect UIVisibilityManager; responsive to scale/inset so panel doesn’t overlap core UI. |

---

## 4. Out of scope (v1)

- Moving or removing currency from the ActionBar (separate decision; can keep both).
- New tutorial step types or progression logic (use current TutorialConfig / TutorialManager).
- Quests, achievements, daily streak, or other stats (panel can be extended later).
- Collapse/expand or hover-to-expand (panel is always expanded in v1).

---

## 5. Acceptance criteria

- **Currencies**
  - Given the panel is visible, when GameState `coins` or `gems` change, then the displayed values update within one frame.
  - Given the panel is visible, then coins and gems use the same formatting (K/M/B) as the rest of the HUD.

- **World**
  - Given the player is in a world, when `WorldOwnershipInfo` fires, then the panel shows world name and owner; when local player is owner, then “(You)” is shown.
  - Given the player is not in a world or info is missing, then the world block shows a safe fallback (e.g. “—” or “Loading…”).

- **Tutorial**
  - Given tutorial is active and has a current step, when the step changes, then the tutorial block shows the new step title.
  - Given tutorial is inactive or complete, then the tutorial block is not visible.

- **Integration**
  - Given UIVisibilityManager hides the HUD, then the right-side panel is hidden.
  - Given the panel is shown, then it does not overlap hotbar, crosshair, or critical center UI at base resolution and with IgnoreGuiInset as used today.

---

## 6. Implementation notes

- **Currencies:** Same bindings as MainHUD (GameState `playerData.coins`, `playerData.gems`); consider shared formatting helper.
- **World:** Either (a) integrate `WorldOwnershipDisplay` into this panel and remove the standalone top-left label, or (b) have both consume the same event and keep panel as single source of “world + owner” for v1.
- **Tutorial:** Subscribe to tutorial step updates (e.g. events that TutorialManager already fires) and call `TutorialManager:GetCurrentStep()`; display `currentStep.title` or a short label from config. One line only in v1.

---

## 7. Open for later

- Exact pixel offset from right/top; optional collapse/expand in a future version.
- Adding more rows (quests, daily streak) without layout redesign—structure the panel so blocks can be appended.
