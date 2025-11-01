# Mobile Controls Quick Start Guide

## 🚀 Getting Started (3 Easy Steps)

### Step 1: Add to GameClient

Open `/home/roblox/tds/src/StarterPlayerScripts/Client/GameClient.client.lua`

**Find this section (around line 428):**

```lua
-- Initialize Sprint Controller (hold Left Shift to sprint)
local SprintController = require(script.Parent.Controllers.SprintController)
SprintController:Initialize()
Client.sprintController = SprintController
```

**Add this code RIGHT AFTER the Sprint Controller:**

```lua
-- Initialize Mobile Controls (Minecraft-inspired)
local MobileControlController = require(script.Parent.Controllers.MobileControlController)
local mobileControls = MobileControlController.new()
mobileControls:Initialize()
Client.mobileControls = mobileControls
print("📱 Mobile Control Controller initialized")
```

### Step 2: Test on Mobile

1. Publish your game to Roblox
2. Open on a mobile device (phone or tablet)
3. You should see:
   - Virtual thumbstick on bottom-left
   - Jump, Crouch, Sprint buttons on bottom-right
   - Touch-drag camera rotation

### Step 3: Customize (Optional)

Edit settings in:
`/home/roblox/tds/src/ReplicatedStorage/Shared/MobileControls/MobileControlConfig.lua`

---

## 🎮 Default Controls

### Movement
- **Thumbstick** (bottom-left): Move character
- **Touch-drag** (anywhere else): Rotate camera

### Actions
- **Jump** (bottom-right): Make character jump
- **Crouch** (above jump): Crouch/sneak
- **Sprint** (left of jump): Run faster

### Camera
- Press **V** key to toggle first/third person (works on desktop too!)

---

## 🔧 Configuration Examples

### Change Button Sizes

```lua
-- In MobileControlConfig.lua
Actions = {
    ButtonSize = 75,  -- Larger buttons (default: 65)
    ButtonOpacity = 0.8,  -- More visible (default: 0.7)
}
```

### Change Camera Sensitivity

```lua
-- In MobileControlConfig.lua
Camera = {
    SensitivityX = 0.7,  -- Faster horizontal (default: 0.5)
    SensitivityY = 0.3,  -- Slower vertical (default: 0.5)
    InvertY = false,  -- Set to true to invert Y-axis
}
```

### Enable Auto-Accessibility Features

```lua
-- In MobileControlConfig.lua
Accessibility = {
    AutoJump = true,  -- Auto-jump near obstacles
    TouchAssistance = 2,  -- Level 2 assistance (0-3)
    UIScale = 1.2,  -- 120% larger UI
}
```

---

## 📱 Testing Tips

### On Desktop (Roblox Studio)
Mobile controls won't show up on desktop - this is intentional!
To test:
1. Enable mobile emulation in Studio
2. Or publish and test on actual mobile device

### Device Detection
The system automatically detects:
- **Small Phone** (<375px width): Compact layout, 85% UI scale
- **Phone** (375-768px): Default layout, 100% UI scale
- **Tablet** (>768px): Split-screen layout, 120% UI scale

---

## 🎯 Control Schemes

Change control scheme programmatically:

```lua
-- In your game code
local mobileControls = Client.mobileControls

-- Classic mode (default)
mobileControls:SetControlScheme("Classic")

-- Split-screen mode (Minecraft-style, best for tablets)
mobileControls:SetControlScheme("Split")

-- One-handed mode (all controls on one side)
mobileControls:SetControlScheme("OneHandedRight")
```

---

## ♿ Accessibility Options

Enable accessibility features:

```lua
-- In your game code
local mobileControls = Client.mobileControls

-- High contrast mode
mobileControls:SetHighContrast(true)

-- Increase UI size
mobileControls.accessibilityFeatures:SetUIScale(1.5)  -- 150%

-- Colorblind mode
mobileControls.accessibilityFeatures:SetColorblindMode("Protanopia")

-- Touch assistance
mobileControls.accessibilityFeatures:SetTouchAssistance(2)  -- Level 2

-- Auto-jump
mobileControls.accessibilityFeatures:SetAutoJump(true)
```

---

## 🔌 API Quick Reference

```lua
-- Get mobile controls instance
local mobileControls = Client.mobileControls

-- Check if mobile controls are active
if mobileControls:IsActive() then
    print("Playing on mobile!")
end

-- Get device info
local deviceInfo = mobileControls:GetDeviceInfo()
print("Device Type:", deviceInfo.type)  -- SmallPhone, Phone, or Tablet
print("Screen Size:", deviceInfo.screenSize)

-- Show context button (e.g., "Press to interact")
mobileControls:ShowContextButton("Interact", "Open Chest", "📦")

-- Hide context button
mobileControls:HideContextButton("Interact")

-- Change sensitivity
mobileControls:SetSensitivity(0.6, 0.4)  -- X, Y

-- Enable/disable mobile controls
mobileControls:SetEnabled(true)
```

---

## ❓ Troubleshooting

### Mobile controls not showing up?
- Check if you're on a mobile device (or mobile emulation is enabled)
- Ensure `UserInputService.TouchEnabled` returns `true`
- Check console for initialization messages

### Buttons too small/large?
- Adjust `ButtonSize` in `MobileControlConfig.lua`
- Or use `SetButtonSize()` programmatically

### Camera too sensitive/slow?
- Adjust `SensitivityX` and `SensitivityY` in config
- Or use `SetSensitivity()` method

### Thumbstick not responding?
- Check if your character has a Humanoid
- Verify thumbstick is in left 40% of screen
- Check console for errors

---

## 📚 More Info

- **Full Documentation**: `MOBILE_CONTROLS_IMPLEMENTATION_COMPLETE.md`
- **Design Plan**: `MOBILE_CONTROLS_IMPLEMENTATION_PLAN.md`
- **Code Comments**: Each module has detailed inline documentation

---

## 🎉 That's It!

Your game now has professional mobile controls inspired by Minecraft!

**Features you get:**
✅ Virtual thumbstick movement
✅ Touch-drag camera
✅ Action buttons (jump, crouch, sprint)
✅ Auto device detection
✅ Multiple control schemes
✅ Full accessibility support
✅ Tablet-optimized layouts
✅ High contrast mode
✅ Colorblind-friendly options

**Desktop players** won't see any mobile UI - it only activates on touch devices!

---

*Happy mobile gaming! 🎮📱*

