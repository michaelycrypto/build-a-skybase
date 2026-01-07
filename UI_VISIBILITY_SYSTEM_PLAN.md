# UI Visibility System - Implementation Plan

## Problem Statement
Currently, UI components (MainHUD, VoxelHotbar, VoxelInventoryPanel) manage their own visibility independently, leading to:
- Manual reference passing between components
- No centralized UI state coordination
- Duplicated backdrop/overlay code
- No reusable backdrop blur system

## Proposed Solution

### 1. UI Visibility Manager (New Module)
**Location:** `src/StarterPlayerScripts/Client/Managers/UIVisibilityManager.lua`

**Purpose:** Central coordinator for all UI visibility states

**Features:**
- Register UI components (MainHUD, VoxelHotbar, panels, etc.)
- Define UI "layers" or "modes" (gameplay, inventory, menu, etc.)
- Automatically show/hide components based on active mode
- Coordinate with GameState for reactive updates

**API:**
```lua
-- Register a UI component
UIVisibilityManager:RegisterComponent(componentId, componentInstance, config)

-- Set UI mode (auto-manages visibility)
UIVisibilityManager:SetMode(mode) -- "gameplay", "inventory", "menu", "chat"

-- Query current mode
local currentMode = UIVisibilityManager:GetMode()

-- Manual show/hide override
UIVisibilityManager:ShowComponent(componentId)
UIVisibilityManager:HideComponent(componentId)
```

**Component Configuration:**
```lua
{
    id = "mainHUD",
    instance = mainHudInstance,
    visibleInModes = {"gameplay"}, -- Array of modes where this is visible
    showMethod = "Show",  -- Method name to call on instance
    hideMethod = "Hide",  -- Method name to call on instance
    priority = 10  -- Z-index/layer priority
}
```

**Mode Definitions:**
```lua
MODES = {
    gameplay = {
        components = {"mainHUD", "voxelHotbar", "crosshair"},
        backdrop = false
    },
    inventory = {
        components = {"voxelInventory"},
        hideComponents = {"mainHUD", "voxelHotbar"}, -- Explicitly hide these
        backdrop = true,
        backdropConfig = {
            blur = true,
            blurSize = 24,
            overlay = true,
            overlayColor = Color3.fromRGB(4, 4, 6),
            overlayTransparency = 0.35
        }
    },
    chest = {
        components = {"chestUI"},
        hideComponents = {"mainHUD", "voxelHotbar"},
        backdrop = true,
        backdropConfig = { blur = true, blurSize = 24, overlay = true }
    },
    menu = {
        components = {"settingsPanel"},
        hideComponents = {"mainHUD", "voxelHotbar", "crosshair"},
        backdrop = true,
        backdropConfig = { blur = true, blurSize = 32, overlay = true }
    }
}
```

---

### 2. Reusable Backdrop System (New Module)
**Location:** `src/StarterPlayerScripts/Client/UI/UIBackdrop.lua`

**Purpose:** Reusable backdrop blur + overlay system for any UI

**Features:**
- Blur effect using BlurEffect in Lighting
- Dark overlay frame with IgnoreGuiInset = true
- Configurable blur intensity and overlay transparency
- Singleton pattern (one backdrop at a time)
- Smooth fade in/out animations

**API:**
```lua
local UIBackdrop = require(...)

-- Show backdrop with configuration
UIBackdrop:Show({
    blur = true,
    blurSize = 24,        -- Blur intensity (default: 24)
    overlay = true,
    overlayColor = Color3.fromRGB(4, 4, 6),
    overlayTransparency = 0.35,
    displayOrder = 50,    -- ScreenGui display order
    onTap = function()    -- Optional: callback when backdrop is tapped
        print("Backdrop tapped")
    end
})

-- Hide backdrop
UIBackdrop:Hide()

-- Check if backdrop is visible
local isVisible = UIBackdrop:IsVisible()
```

**Implementation Details:**
```lua
-- Singleton state
local backdropGui = nil
local blurEffect = nil
local overlayFrame = nil
local isVisible = false

-- Create backdrop ScreenGui (IgnoreGuiInset = true)
-- Create overlay frame (fullscreen)
-- Create/manage BlurEffect in Lighting
-- Tween blur size and overlay transparency for smooth transitions
```

---

### 3. Modified VoxelInventoryPanel Integration

**Changes:**
```lua
-- Remove internal overlay creation
-- Use UIVisibilityManager and UIBackdrop

function VoxelInventoryPanel:Open()
    if self.isOpen then return end

    self.isOpen = true
    self.gui.Enabled = true

    -- Use centralized UI visibility system
    UIVisibilityManager:SetMode("inventory")

    -- Update displays
    self:UpdateAllDisplays()

    -- Animate in
    -- ... animation code
end

function VoxelInventoryPanel:Close()
    if not self.isOpen then return end

    -- Handle cursor item
    -- ...

    self.isOpen = false

    -- Restore gameplay mode
    UIVisibilityManager:SetMode("gameplay")

    -- Animate out
    -- ...
end
```

---

### 4. Modified MainHUD Integration

**Changes:**
```lua
function MainHUD:Create()
    -- ... create UI elements

    -- Register with UIVisibilityManager
    local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
    UIVisibilityManager:RegisterComponent("mainHUD", self, {
        visibleInModes = {"gameplay"},
        showMethod = "Show",
        hideMethod = "Hide",
        priority = 10
    })

    -- Set initial mode
    UIVisibilityManager:SetMode("gameplay")
end
```

---

### 5. Modified VoxelHotbar Integration

**Changes:**
```lua
function VoxelHotbar:Initialize()
    -- ... create UI elements

    -- Register with UIVisibilityManager
    local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
    UIVisibilityManager:RegisterComponent("voxelHotbar", self, {
        visibleInModes = {"gameplay"},
        showMethod = "Show",
        hideMethod = "Hide",
        priority = 5
    })
end
```

---

### 6. Integration with GameState

**Add to GameState:**
```lua
ui = {
    mode = "gameplay",  -- Current UI mode
    visibleComponents = {},  -- Currently visible components
    backdropActive = false
}
```

**Benefits:**
- Reactive UI updates via GameState listeners
- Other systems can query/respond to UI mode changes
- Debugging support (inspect current UI state)

---

## Implementation Steps

### Phase 1: Core Infrastructure
1. ✅ Create `UIBackdrop.lua` module
2. ✅ Create `UIVisibilityManager.lua` module
3. ✅ Add UI mode to GameState

### Phase 2: Component Registration
4. ✅ Update MainHUD to register with UIVisibilityManager
5. ✅ Update VoxelHotbar to register with UIVisibilityManager
6. ✅ Update VoxelInventoryPanel to use UIVisibilityManager

### Phase 3: Integration & Testing
7. ✅ Remove manual HUD reference passing
8. ✅ Test mode transitions (gameplay → inventory → gameplay)
9. ✅ Test backdrop blur effects
10. ✅ Verify no visual glitches during transitions

### Phase 4: Extend to Other Panels
11. ✅ Integrate ChestUI with UIVisibilityManager
12. ✅ Integrate SettingsPanel with UIVisibilityManager
13. ✅ Integrate other panels as needed

---

## Benefits of This Architecture

### 1. **Maintainability**
- Single source of truth for UI visibility
- Easy to add new UI components
- Clear separation of concerns

### 2. **Reusability**
- UIBackdrop can be used by any UI component
- Consistent backdrop behavior across all panels
- No code duplication

### 3. **Flexibility**
- Easy to define new UI modes
- Components can be visible in multiple modes
- Override visibility for special cases

### 4. **Performance**
- Centralized blur management (one BlurEffect instance)
- Efficient mode transitions
- No redundant show/hide calls

### 5. **Developer Experience**
- Simple API (`SetMode("inventory")`)
- No manual reference management
- Easy debugging (check current mode)

---

## File Structure

```
src/StarterPlayerScripts/Client/
├── Managers/
│   ├── UIVisibilityManager.lua      (NEW - Central UI coordinator)
│   ├── UIManager.lua                 (Existing - Viewport/responsive)
│   ├── PanelManager.lua              (Existing - Panel creation)
│   └── GameState.lua                 (Existing - Add UI mode state)
├── UI/
│   ├── UIBackdrop.lua                (NEW - Reusable backdrop)
│   ├── MainHUD.lua                   (Modified - Register with manager)
│   ├── VoxelHotbar.lua               (Modified - Register with manager)
│   ├── VoxelInventoryPanel.lua       (Modified - Use manager + backdrop)
│   └── ChestUI.lua                   (Modified - Use manager + backdrop)
```

---

## Example Usage

### Opening Inventory
```lua
-- Old way (manual)
inventoryPanel:Open()
mainHUD:Hide()
voxelHotbar:Hide()
backdrop:Show()

-- New way (automatic)
UIVisibilityManager:SetMode("inventory")
-- UIVisibilityManager automatically:
--   1. Hides mainHUD and voxelHotbar
--   2. Shows backdrop with blur
--   3. Shows inventory panel
--   4. Updates GameState
```

### Opening Settings
```lua
-- Automatically manages everything
UIVisibilityManager:SetMode("menu")
```

### Returning to Gameplay
```lua
-- Restore gameplay state
UIVisibilityManager:SetMode("gameplay")
-- Automatically:
--   1. Hides all panels
--   2. Removes backdrop
--   3. Shows mainHUD and voxelHotbar
--   4. Restores crosshair
```

---

## Testing Checklist

- [ ] Inventory opens: MainHUD + Hotbar hidden, backdrop visible
- [ ] Inventory closes: MainHUD + Hotbar shown, backdrop hidden
- [ ] Chest opens: Same hide/show behavior
- [ ] Settings opens: All game UI hidden
- [ ] Mode transitions are smooth (no flicker)
- [ ] Backdrop blur animates smoothly
- [ ] Multiple rapid mode changes handled correctly
- [ ] Mobile/desktop both work correctly

---

## Notes

- **Backward Compatibility:** Old manual Show/Hide methods still work, but using UIVisibilityManager is preferred
- **Performance:** Single BlurEffect instance managed by UIBackdrop (vs multiple instances)
- **Extensibility:** Easy to add new modes and components without modifying existing code
- **GameState Integration:** UI mode changes trigger GameState events for reactive updates

