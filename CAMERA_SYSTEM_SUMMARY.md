# Camera & Targeting System - Final Clean Implementation

**Date:** October 21, 2025
**Status:** ✅ Clean, Consistent, Production-Ready

---

## 📹 Camera System

### **CameraController.lua**
Uses Roblox's native camera system with custom settings.

**Features:**
- ✅ Camera offset: 2 studs above normal height
- ✅ Forced mouse lock during gameplay
- ✅ Automatic unlock when UI opens
- ✅ V key toggles First/Third person
- ✅ Smooth Roblox camera controls

**Settings:**
```lua
Third Person:      15 studs distance
First Person:      0.5 studs distance
Camera Offset:     +2 studs vertical
Mouse Sensitivity: 0.6 (60% of normal - less sensitive)
```

**Mouse Lock Logic:**
- Continuously enforces `MouseBehavior.LockCenter` every frame
- Checks `GameState.voxelWorld.inventoryOpen` to free mouse for UI
- Automatically re-locks when UI closes

---

## 🎯 Block Targeting System

### **BlockInteraction.lua**
Raycast from 2 studs above player's head.

**How it Works:**
1. Raycast from `head.Position + Vector3.new(0, 2, 0)` (2 studs above head)
2. Direction: `camera.CFrame.LookVector` (center of screen)
3. Max distance: 100 studs
4. Returns block coordinates at center crosshair

**Why 2 studs above head?**
- Matches camera focus height
- Prevents raycast from hitting player's own head in third person
- Ensures targeted blocks are visible on screen

**No Validation:**
- ❌ No magnitude checks
- ❌ No player distance limits
- ✅ Server handles reach validation

---

## 🖱️ Mouse Lock Consistency

All three files work together consistently:

### **1. BlockInteraction.lua**
```lua
-- Sets initial mouse lock on initialization
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false
```

### **2. ChestUI.lua**
```lua
-- Re-locks mouse when closing chest
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false
```

### **3. VoxelInventoryPanel.lua**
```lua
-- Re-locks mouse when closing inventory
UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
UserInputService.MouseIconEnabled = false
```

### **4. CameraController.lua**
```lua
-- Continuously enforces mouse lock (every frame)
-- Respects GameState.voxelWorld.inventoryOpen
RunService.RenderStepped:Connect(...)
```

**Result:** Mouse lock is maintained through multiple layers of enforcement, ensuring it never gets stuck unlocked.

---

## 🎮 Player Controls

### Gameplay (Mouse Locked)
- **Mouse Movement** → Rotate camera
- **Left Click** → Break block
- **Right Click** → Place block / Interact
- **V Key** → Toggle First/Third person
- **E Key** → Open inventory (unlocks mouse)

### UI Open (Mouse Free)
- **Mouse Cursor** → Navigate inventory
- **Click & Drag** → Move items
- **ESC / E** → Close UI (re-locks mouse)

---

## ✅ System Architecture

```
┌─────────────────────────────────────────┐
│         CameraController                │
│  - Native Roblox camera                 │
│  - +2 studs offset                      │
│  - Continuous mouse lock enforcement    │
│  - Checks GameState for UI              │
└─────────────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────┐
│       BlockInteraction                  │
│  - Raycast from camera center           │
│  - 100 stud range                       │
│  - No distance validation               │
│  - Sets initial mouse lock              │
└─────────────────────────────────────────┘
                    │
                    ↓
┌─────────────────────────────────────────┐
│       UI Systems                        │
│  - ChestUI: Re-locks on close           │
│  - VoxelInventoryPanel: Re-locks on close│
│  - Sets GameState.inventoryOpen         │
└─────────────────────────────────────────┘
```

---

## 🔧 Configuration

Easy to adjust in one place:

### CameraController.lua
```lua
local CAMERA_HEIGHT_OFFSET = 2   -- Camera height above normal
local THIRD_PERSON_DISTANCE = 15 -- Third person zoom
local FIRST_PERSON_DISTANCE = 0.5 -- First person zoom
local MOUSE_SENSITIVITY = 0.6    -- Mouse sensitivity (0.6 = 60% speed)
```

### BlockInteraction.lua
```lua
local maxDistance = 100 -- Block targeting range
-- Raycast origin: head.Position + Vector3.new(0, 2, 0)
```

---

## 🎯 Design Goals Achieved

✅ **Simple** - Minimal code, easy to understand
✅ **Consistent** - All files follow same pattern
✅ **Robust** - Multiple layers of mouse lock enforcement
✅ **Clean** - No redundant checks or dead code
✅ **Native** - Uses Roblox's battle-tested camera

---

## 📝 Notes

- Server-side validation still enforces player reach limits
- Client targeting is permissive for smooth UX
- Mouse lock has redundant enforcement (intentional for reliability)
- Camera offset applies to both first and third person
- No scroll zoom (locked distances per mode)

---

**End of Documentation**

