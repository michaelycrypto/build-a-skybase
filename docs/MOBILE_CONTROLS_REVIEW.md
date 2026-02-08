# Mobile Controls Review — Minecraft-Style Voxel Game

This document reviews the mobile control implementation against the design: **right thumb = camera**, **tap = interact/place**, **hold = mine**, with **crosshair-centered targeting** (not tap-on-model).

---

## Summary

| Area | Status | Notes |
|------|--------|--------|
| Crosshair & targeting | ⚠️ Partial | Center raycast and range OK; NPC/minion use `mouse.Target` (broken on mobile). |
| Interaction (tap/hold) | ✅ Good | Tap/hold/drag logic correct; consider restricting tap to right side. |
| Camera | ✅ Good | Right-thumb drag, clamp, smoothing; no mining on drag. |
| Performance & input | ✅ Good | No obvious conflicts; selection box at 10 Hz. |

---

## 1. Crosshair & Targeting

### 1.1 Crosshair always visible at screen center

- **Implementation:** `Crosshair.lua` creates a centered frame at `UDim2.fromScale(0.5, 0.5)` with horizontal/vertical bars.
- **Visibility:** Driven by `GameState:Get("camera.targetingMode")` — visible when `targetingMode == "crosshair"`.
- **Mobile:** Camera starts in `FIRST_PERSON` (`CameraController:Initialize()` → `TransitionTo("FIRST_PERSON")`), which sets `targetingMode = "crosshair"`. So on mobile the crosshair is shown.
- **Verdict:** ✅ Crosshair is centered and visible in crosshair mode (including mobile).

### 1.2 Raycast from camera center

- **Implementation:** `BlockInteraction.lua` → `_computeAimRay()`:
  - If `targetingMode == "crosshair"`: `camera:ViewportPointToRay(viewportSize.X / 2, viewportSize.Y / 2)`.
  - If `targetingMode == "direct"`: uses `lastInputPosition` (click/tap).
- **Verdict:** ✅ In crosshair mode the raycast origin is the viewport center.

### 1.3 Raycast aligns with crosshair visually

- Same math: crosshair at `(0.5, 0.5)` and ray from `(viewportSize.X/2, viewportSize.Y/2)`.
- **Verdict:** ✅ Aligned.

### 1.4 Player character ignored in raycast

- **Block targeting:** `BlockAPI:GetTargetedBlockFace()` uses a **voxel DDA** over the block grid only. The player is not represented as blocks, so the character is effectively ignored.
- **Workspace raycast:** There is no workspace raycast in `BlockInteraction` for block targeting; only voxel stepping is used. So no `RaycastParams`/`FilterDescendantsInstances` for block hit.
- **Verdict:** ✅ For blocks, the player does not block the ray. (If you add a workspace ray for interactables, you must filter the local character — see 1.8.)

### 1.5 Valid targets detected reliably

- Blocks: DDA in `BlockAPI:GetTargetedBlockFace()` steps through the voxel world; hit position and face are returned. Used by `getTargetedBlock()` with `maxDistance = 100` and then **range-checked** in `updateSelectionBox()` with `maxReach = 4.5 * bs + 2`.
- **Verdict:** ✅ Block targeting is consistent and gated by range.

### 1.6 Interaction range reasonable

- **Client:** `isBlockInRange()` uses `maxReach = 4.5 * bs + 2` (same as server placement/breaking).
- **Verdict:** ✅ Range is well-defined and matches server.

### 1.7 Interactables prioritized over blocks (NPC/minion > blocks)

- **Chest / block interactables:** Handled via `getTargetedBlock()` then `BlockRegistry:IsInteractable(blockId)`. So chests use **crosshair** and are correctly prioritized in the block path.
- **NPC / minion (workspace models):** In `interactOrPlace()` the **first** checks use `mouse.Target` to find a `Model` with `MobEntityId` or `NPCId`. On **mobile**, there is no cursor; `mouse.Target` is often nil or stale. So **NPC and minion interaction is not crosshair-based** and can fail on touch.
- **Verdict:** ⚠️ **Issue:** NPC and minion interaction should use a **crosshair-based workspace raycast** when `targetingMode == "crosshair"` (and filter character), instead of `mouse.Target`. Chests are fine (block path).

### 1.8 Transparent parts and raycast

- Block hit uses only voxel DDA; no workspace raycast for blocks. So transparent **parts** in workspace do not affect block targeting.
- If you add a workspace ray for NPC/minion, use `RaycastParams` with:
  - `FilterDescendantsInstances = { character }` (and optionally other UI/effects),
  - and `FilterType = Enum.RaycastFilterType.Exclude` so transparent/can-collide parts are handled as you intend.
- **Verdict:** ✅ Blocks are unaffected by transparent parts. When adding center-ray for interactables, configure `RaycastParams` so transparent parts don’t block incorrectly.

---

## 2. Interaction Logic

### 2.1 Tap: right side, crosshair-based

- **Current behavior:** **Any** touch (left or right) is tracked in `BlockInteraction`. On release, if `not touchData.moved` → treated as tap and `interactOrPlace()` is called. Aim for that call uses `_computeAimRay()`: in crosshair mode **center is used**, so block placement and chest interaction are crosshair-based.
- **Right-side only:** There is **no** check that the touch is on the right half. So a tap on the **left** (e.g. outside thumbstick) also triggers `interactOrPlace()`. Design said “tap anywhere on **right** side”; if that is strict, add a check (e.g. `touchData.startPos.X >= camera.ViewportSize.X * 0.4`) before treating as tap.
- **Verdict:** ✅ Tap is crosshair-based for blocks/chest. ⚠️ Optional: restrict tap-to-interact to the right side only.

### 2.2 Tap: NPC/minion and chest

- **Chest:** Uses `getTargetedBlock()` → crosshair. ✅
- **NPC/minion:** Uses `mouse.Target` → unreliable on mobile. ⚠️ (Same as 1.7 — use center raycast in crosshair mode.)

### 2.3 Tap: block place when holding block

- `interactOrPlace()` uses `getTargetedBlock()` and placement logic; in crosshair mode that’s center. ✅

### 2.4 Hold: mining on targeted block

- **Start:** On touch, a delayed task runs after `HOLD_TIME_THRESHOLD` (0.3 s). If the touch is still active and `not touchData.moved`, `holdTriggered = true` and `startBreaking()` is called.
- **Verdict:** ✅ Hold starts mining on the block under the crosshair (same ray as selection).

### 2.5 Mining progress indicator

- Server sends `BlockBreakProgress`; client shows it in `BlockBreakProgress.lua` (bar below crosshair). Only the local player’s progress is shown (`data.playerUserId == player.UserId`).
- **Verdict:** ✅ Progress appears while mining.

### 2.6 Mining cancels on release

- `InputEnded` for the same touch: if `touchData.holdTriggered` then `stopBreaking()`.
- **Verdict:** ✅ Release stops mining.

### 2.7 Mining cancels if aim leaves block

- In the breaking loop, `getTargetedBlock()` is polled. If the current target differs from `breakingBlock` or is nil, break is cancelled (e.g. `sendCancelForBlock`, `BlockBreakProgress:Reset()`, `breakingBlock = nil`).
- **Verdict:** ✅ Moving aim off the block cancels mining.

---

## 3. Camera

### 3.1 Right-thumb drag pans camera

- **MobileCameraController** subscribes to touch; `IsTouchInCameraZone(position)` in Classic mode returns true for `position.X >= screenSize.X * 0.4`. So the right 60% is camera zone; left 40% is thumbstick.
- **Verdict:** ✅ Right-side drag is used for camera.

### 3.2 No jitter / no snapping

- Rotation is applied to `targetRotation`; `UpdateCameraRotation(deltaTime)` lerps `cameraRotation` toward `targetRotation` with `alpha = 1 - math.pow(self.smoothing, deltaTime)`.
- **Verdict:** ✅ Smoothing should prevent visible jitter/snap.

### 3.3 Camera drag does not trigger mining

- If the user moves beyond `DRAG_MOVEMENT_THRESHOLD` (10 px), `touchData.moved = true`. The hold timer can still fire after 0.3 s, but if they then move, `holdTriggered` is set false and `stopBreaking()` is called (“Converted hold to drag - Stop breaking”). So mining can briefly start only if they hold still for 0.3 s then drag; normal “drag first” usage does not start mining.
- **Verdict:** ✅ Drag does not trigger mining in normal use; edge case (hold then drag) correctly stops mining.

### 3.4 Sensitivity consistent across devices

- `MobileCameraController` uses configurable `sensitivityX` / `sensitivityY` (from `MobileControlConfig.Camera` and device-recommended settings). No device-specific branching in the math.
- **Verdict:** ✅ Sensitivity is applied uniformly; tuning is per-config, not per-device in code.

### 3.5 Vertical angle clamped

- In `OnTouchMove`, vertical component is clamped: `math.clamp(self.targetRotation.Y, -maxPitch, maxPitch)` with `maxPitch = math.rad(self.maxVerticalAngle)` (default 80°).
- **Verdict:** ✅ Vertical look is clamped.

---

## 4. Performance & Input Quality

### 4.1 No noticeable tap delay

- Tap is recognized on `InputEnded` when `not touchData.moved`; no extra delay. Hold uses a 0.3 s delay only for the hold gesture.
- **Verdict:** ✅ Tap is immediate on release.

### 4.2 No lag from raycasting

- Block “raycast” is voxel DDA in `BlockAPI:GetTargetedBlockFace()` (no workspace ray). Selection box updates at **10 Hz** (`task.wait(0.1)` in the loop) with dirty checks (camera position/rotation, and in direct mode mouse position).
- **Verdict:** ✅ Ray work is cheap and throttled.

### 4.3 No FPS drops during repeated mining

- Breaking loop runs every 0.05 s, calls `getTargetedBlock()` and sends punch events. No heavy per-frame work in the inner loop.
- **Verdict:** ✅ No obvious cause for FPS drops from mining.

### 4.4 No input conflicts (camera vs tap/hold)

- Both `BlockInteraction` and `MobileCameraController` receive the same touch events (InputService forwards with `gameProcessed` from Roblox). Neither marks the touch as “consumed” for the other. Conflict is resolved by **gesture**: if the user moves >10 px, it’s treated as drag (camera) and any started break is cancelled; if they don’t move and release, it’s tap; if they don’t move for 0.3 s, it’s hold.
- **Verdict:** ✅ No structural conflict; behavior is gesture-based.

---

## 5. Recommendations

1. **Crosshair-based NPC/minion (high):** In `interactOrPlace()` (and first-person right-click path), when `targetingMode == "crosshair"`, replace `mouse.Target` with a **workspace raycast from camera center**. Use `RaycastParams` with the local character in `FilterDescendantsInstances` so the player doesn’t block the ray. Check the hit instance’s model for `MobEntityId` / `NPCId` and keep the same “interactables over blocks” order (NPC/minion first, then blocks).
2. **Right-side tap only (optional):** If design requires “tap on right side” only, in `InputEnded` for Touch, only call `interactOrPlace()` when `touchData.startPos.X >= workspace.CurrentCamera.ViewportSize.X * 0.4` (or use the same ratio as `IsTouchInCameraZone`).
3. **Transparent parts:** When adding the center workspace ray for NPC/minion, set `RaycastParams.FilterType` and filter list so transparent/can-collide behavior is correct and the character is always ignored.

---

## 6. File Reference

| Concern | Primary file(s) |
|--------|-------------------|
| Crosshair visibility/position | `StarterPlayerScripts/Client/UI/Crosshair.lua` |
| Aim ray (center vs direct) | `StarterPlayerScripts/Client/Controllers/BlockInteraction.lua` (`_computeAimRay`, `getTargetedBlock`) |
| Block hit (voxel) | `ReplicatedStorage/Shared/VoxelWorld/World/BlockAPI.lua` (`GetTargetedBlockFace`) |
| Touch tap/hold/drag | `BlockInteraction.lua` (InputBegan/InputChanged/InputEnded) |
| Mining start/cancel | `BlockInteraction.lua` (`startBreaking`, `stopBreaking`, breaking loop) |
| Mining progress UI | `StarterPlayerScripts/Client/UI/BlockBreakProgress.lua` |
| Mobile camera | `StarterPlayerScripts/Client/Modules/MobileControls/CameraController.lua` |
| Camera zone (right side) | `CameraController.lua` (`IsTouchInCameraZone`) |
| Camera state & targetingMode | `StarterPlayerScripts/Client/Controllers/CameraController.lua` |
| NPC/minion (mouse.Target) | `BlockInteraction.lua` (`interactOrPlace`, handleRightClick) |
