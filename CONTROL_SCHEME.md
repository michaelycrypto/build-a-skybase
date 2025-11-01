# 🎮 Control Scheme - Dual Mode System

**Last Updated:** October 29, 2025
**Status:** ✅ Implemented - Mobile & PC Friendly

---

## 📋 Overview

The game features **two distinct camera modes** that players can toggle between using the **V key**:
1. **First Person** - Minecraft-style building (mouse locked)
2. **Third Person** - Fortnite-style building (free camera)

Both modes support **full building capabilities** with mobile-friendly controls.

---

## 🎯 First Person Mode (Minecraft-Style)

### Camera Behavior
- ✅ **Mouse locked** at center of screen
- ✅ **Crosshair visible** (grey)
- ✅ **Wide FOV** (90 degrees)
- ✅ **Camera bobbing** when walking/sprinting
- ✅ Character rotates with camera automatically

### Controls (PC)
```
Left-Click:
  - On block: Break it
  - On interactable (chest): Open/interact
  - Default: Break blocks

Right-Click:
  - Place blocks from selected hotbar slot
```

### Controls (Mobile)
```
Tap:
  - On block: Break it
  - On interactable (chest): Open/interact
  - Default: Break blocks

Place Button (UI):
  - Place blocks from selected hotbar slot
```

### When to Use
- ✅ Precision building and mining
- ✅ Fast-paced block placement
- ✅ Tight spaces and detailed work
- ✅ Minecraft-familiar gameplay

---

## 🏗️ Third Person Mode (Fortnite-Style)

### Camera Behavior
- ✅ **Mouse free** with cursor visible
- ✅ **Crosshair visible** (grey/green based on mode)
- ✅ **Standard FOV** (70 degrees)
- ✅ **Zoom range** (0.5 to 128 studs)
- ✅ Character moves independently of camera

### Camera Controls (PC)
```
Right-Click + Drag: Rotate camera around character
Scroll Wheel: Zoom in/out
Standard Roblox camera: Full freedom
```

### Building Controls (PC)
```
F Key: Toggle Break ↔ Place Mode

Break Mode (Grey Crosshair):
  Left-Click: Break blocks / Interact with chests

Place Mode (Green Crosshair):
  Left-Click: Place blocks from hotbar
```

### Building Controls (Mobile)
```
Toggle Button (UI): Switch Break ↔ Place Mode

Break Mode:
  Tap: Break blocks / Interact

Place Mode:
  Tap: Place blocks
```

### When to Use
- ✅ Exploring and viewing builds
- ✅ Combat and using weapons
- ✅ Building with spatial awareness
- ✅ Seeing surroundings (PvP, enemies)
- ✅ Showcasing character/skins

---

## 🔄 Mode Switching

**Press V** to toggle between First and Third Person
- Available at any time (except when UI is open)
- Place Mode automatically resets when entering First Person
- Crosshair adapts to current mode
- Mouse lock toggles automatically

---

## 🎨 Visual Indicators

### Crosshair Colors
```
Grey (200, 200, 200):
  - First Person mode (always)
  - Third Person + Break Mode

Green (100, 255, 100):
  - Third Person + Place Mode (ready to build!)
```

### UI States
```
First Person:
  - No mouse cursor
  - Crosshair centered
  - Full screen view

Third Person:
  - Mouse cursor visible
  - Crosshair centered
  - Camera can orbit character
  - Mode indicator (Break/Place)
```

---

## 📱 Mobile Support

### First Person (Mobile)
- **Touch screen** = Camera rotation
- **Tap** = Break/interact
- **Place button** = Place blocks
- **Thumbstick** = Movement

### Third Person (Mobile)
- **Two-finger drag** = Camera rotation
- **Pinch** = Zoom
- **Tap** = Break or Place (mode-dependent)
- **Toggle button** = Switch Break/Place mode
- **Thumbstick** = Movement

---

## 🔧 Technical Details

### State Management
- Camera mode stored in: `GameState:Get("camera.isFirstPerson")`
- Place mode local to: `BlockInteraction` module
- Crosshair updates every 0.05 seconds
- Mode resets on character respawn

### Files Modified
1. `CameraController.lua` - Camera mode and mouse lock
2. `BlockInteraction.lua` - Input handling and mode toggle
3. `GameConfig.lua` - MouseLock feature enabled

### Public API (for UI/Mobile)
```lua
BlockInteraction:TogglePlaceMode() -- Toggle and return new state
BlockInteraction:IsPlaceMode() -- Get current state
BlockInteraction:SetPlaceMode(enabled) -- Set specific state
```

---

## ✨ Benefits

### Mobile-Friendly
- ✅ Single tap/click for primary action
- ✅ Clear mode indicators
- ✅ No complex gesture requirements
- ✅ Works on touch screens

### PC-Optimized
- ✅ Familiar Minecraft controls in first person
- ✅ Fortnite-style building in third person
- ✅ Right-click reserved for camera (third person)
- ✅ Quick F key toggle for modes

### Universal
- ✅ Both modes have full building capability
- ✅ Consistent interaction logic
- ✅ Visual feedback for all states
- ✅ Works across all platforms

---

## 🎯 Design Philosophy

**First Person** = Fast, precise, Minecraft-style
- For players who want locked cursor building
- Familiar to Minecraft veterans
- Optimal for detailed work

**Third Person** = Flexible, spatial, Fortnite-style
- For players who want free camera
- Better situational awareness
- Optimal for exploration and combat

**Both modes are equally capable** - it's player preference!

