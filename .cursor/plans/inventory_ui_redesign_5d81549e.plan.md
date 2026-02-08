---
name: Inventory UI Redesign
overview: Redesign the inventory UI from a 3-column layout with left vertical navigation to a single-column Minecraft-style layout with horizontal tabs. Maintain consistency with existing Furnace/Smelting UIs while optimizing for both mobile and PC platforms.
todos:
  - id: update-inventory-config
    content: Update INVENTORY_CONFIG constants in VoxelInventoryPanel.lua for new dimensions (640px width, tab row, etc.)
    status: completed
  - id: create-tab-navigation
    content: Implement CreateTabRow() function with horizontal tabs (Inventory, Crafting) and tab switching logic
    status: completed
  - id: refactor-inventory-layout
    content: "Refactor inventory tab content into vertical layout: Armor (4 slots horizontal) → Inventory (3×9 grid) → Hotbar (1×9 row)"
    status: completed
  - id: update-crafting-panel
    content: Adjust CraftingPanel grid layout for 640px width (5-6 columns) and add recipe detail panel below grid
    status: completed
  - id: implement-recipe-detail
    content: Create recipe detail panel (inspired by SmithingUI) with ingredients display and craft button
    status: completed
  - id: remove-old-navigation
    content: Remove old 3-column layout code (CreateMenuColumn, separate content/inventory columns)
    status: completed
  - id: test-responsive-behavior
    content: Test layout on mobile landscape (800×600, 1024×768) and PC (1920×1080) resolutions
    status: completed
  - id: validate-interactions
    content: "Validate all interactions work: tab switching, drag-and-drop, recipe selection, crafting, armor equip"
    status: completed
isProject: false
---

# Inventory UI Redesign Plan

## Overview

Transform the current 3-column inventory layout into a single-column Minecraft-style design with horizontal tab navigation, optimized for mobile and PC platforms.

---

## 1. Layout Architecture

### Current Structure (3-column)

```
[Left Nav: 94px] [Content: 402px] [Inventory: 604px]
Total width: 1124px
```

### New Structure (Single-column)

```
┌─────────────────────────────────────┐
│  INVENTORY              [X Close]   │ ← Header (54px height)
├─────────────────────────────────────┤
│  [📦 Inventory] [🔨 Crafting]      │ ← Tab Row (60px height)
├─────────────────────────────────────┤
│                                     │
│  [Active Tab Content Area]          │ ← Content (variable height)
│                                     │
└─────────────────────────────────────┘
```

**Dimensions:**

- **Panel width**: 640px (optimized for mobile landscape ~800px screens)
- **Header height**: 54px (unchanged)
- **Tab row height**: 60px (comfortable touch targets)
- **Content area**: Auto-height based on active tab
- **Total centered panel**, vertically positioned similar to current

---

## 2. Tab Navigation Design

### Tab Row Specifications

**Layout:**

- Horizontal row below header
- 2 tabs: "Inventory" and "Crafting"
- Each tab: Icon (32×32) + Text label
- Equal width distribution or auto-width with padding

**Tab Styling:**

- **Inactive state**:
  - Background: `RGB(58, 58, 58)` with 0.6 transparency
  - Icon color: `RGB(185, 185, 195)` (muted gray)
  - Text color: `RGB(185, 185, 195)`
- **Active state**:
  - Background: `RGB(58, 58, 58)` fully opaque
  - Icon color: `RGB(255, 255, 255)` (white)
  - Text color: `RGB(255, 255, 255)`
  - Bottom border accent: 3px white stroke
- **Hover state** (PC):
  - Slight brightness increase
  - Smooth 0.15s transition

**Tab Icons:**

- Inventory: Package/Backpack icon
- Crafting: Hammer/Workbench icon
- Use existing IconManager system

**Implementation Notes:**

- Store active tab state: `self.activeTab = "inventory"` or `"crafting"`
- Tab switching updates content visibility instantly (no animations per requirements)
- Mobile: Full-width tap targets (minimum 44px height)

---

## 3. Inventory Page Layout

Minecraft-style vertical structure with all slots visible at once.

### Structure (Top to Bottom)

```
┌─────────────────────────────────────┐
│  ARMOR                              │ ← Section label (22px height)
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐       │
│  │Head│ │Chst│ │Legs│ │Boots│      │ ← 4 armor slots (60×60 each)
│  └────┘ └────┘ └────┘ └────┘       │
│                                     │
│  INVENTORY                          │ ← Section label (22px height)
│  ┌────┬────┬────┬────┬────┬────┐  │
│  │    │    │    │    │    │    │  │
│  ├────┼────┼────┼────┼────┼────┤  │ ← 27 slots (3 rows × 9 cols)
│  │    │    │    │    │    │    │  │   60×60 each, 5px spacing
│  ├────┼────┼────┼────┼────┼────┤  │
│  │    │    │    │    │    │    │  │
│  └────┴────┴────┴────┴────┴────┘  │
│                                     │
│  HOTBAR                             │ ← Section label (22px height)
│  ┌────┬────┬────┬────┬────┬────┐  │
│  │ 1  │ 2  │ 3  │ 4  │ 5  │ 6  │  │ ← 9 slots (1 row × 9 cols)
│  └────┴────┴────┴────┴────┴────┘  │   60×60 each, 5px spacing
│                                     │
└─────────────────────────────────────┘
```

### Spacing & Sizing

**Armor Section:**

- Horizontal layout: 4 slots side-by-side
- Slot size: 60×60px (56px frame + 2×2px border)
- Spacing: 8px between slots
- Labels: "HEAD", "CHEST", "LEGS", "BOOTS" when empty
- Centered or left-aligned in panel

**Inventory Grid:**

- 3 rows × 9 columns = 27 slots
- Slot size: 60×60px (consistent with current)
- Spacing: 5px between slots
- Width: (60×9) + (5×8) = 540 + 40 = 580px
- Centered in 640px panel (30px margin each side)

**Hotbar:**

- 1 row × 9 columns = 9 slots
- Slot size: 60×60px
- Number labels: 1-9 in top-left corner
- Selection border: 3px white stroke (follows current slot)
- Same width/centering as inventory grid

**Section Labels:**

- Font: Upheaval BRK (custom font)
- Size: 24px
- Color: `RGB(140, 140, 140)` (muted gray)
- Alignment: Left
- Height: 22px + 8px spacing below

### Total Content Height Calculation

- Padding top: 12px
- Armor label: 22px + 8px spacing
- Armor slots: 60px
- Gap: 16px
- Inventory label: 22px + 8px spacing
- Inventory grid: (60×3) + (5×2) = 180 + 10 = 190px
- Gap: 16px
- Hotbar label: 22px + 8px spacing
- Hotbar row: 60px
- Padding bottom: 12px
- **Total**: ~456px content height

### Panel Total Height

- Header: 54px
- Tabs: 60px
- Content: 456px
- **Total**: ~570px

---

## 4. Crafting Page Layout

Minecraft-style recipe browser with detail panel.

### Structure (Top to Bottom)

```
┌─────────────────────────────────────┐
│  RECIPES                            │ ← Section label
│  ┌────┬────┬────┬────┬────┬────┐  │
│  │    │    │    │    │    │    │  │
│  ├────┼────┼────┼────┼────┼────┤  │ ← Recipe grid (scrollable)
│  │    │    │    │    │    │    │  │   5-6 columns × N rows
│  └────┴────┴────┴────┴────┴────┘  │
│                                     │
│  ╔═══════════════════════════════╗ │
│  ║ Selected Recipe Details       ║ │
│  ║                               ║ │
│  ║ Recipe Name                   ║ │ ← Detail panel (inspired by
│  ║ INGREDIENTS NEEDED:           ║ │   Smelting UI)
│  ║ [icon] x4  [icon] x2          ║ │   Compact, bottom section
│  ║                               ║ │
│  ║ [     CRAFT BUTTON      ]     ║ │
│  ╚═══════════════════════════════╝ │
└─────────────────────────────────────┘
```

### Recipe Grid

**Layout:**

- Scrollable grid (if recipes > visible area)
- 5-6 columns × variable rows
- Slot size: 56×56px (slightly smaller than inventory for more recipes visible)
- Spacing: 6px between slots
- Recipe cards show output item icon
- Craftability indicator:
  - Green glow border: Can craft
  - Gray/disabled: Missing ingredients
  - Stack count badge if > 1 output

**Interaction:**

- Single tap/click: Select recipe (shows detail panel below)
- Detail panel slides in/appears below grid

### Recipe Detail Panel

**Inspired by Smelting UI** (`SmithingUI.CreateRecipeInfo`):

**Panel styling:**

- Background: `RGB(58, 58, 58)`
- Border: 3px `RGB(77, 77, 77)`
- Rounded corners: 8px
- Height: ~180-200px (fixed)
- Padding: 12px

**Content structure:**

```
Recipe Name (28px font, white)
─────────────────────────
INGREDIENTS (18px font, muted)
[icon] Oak Wood x4   [icon] Stick x2
           ↓
[    CRAFT (1x)    ] ← Button (56px height)
```

**Ingredient Display:**

- Horizontal row layout
- Each ingredient:
  - Item icon: 36×36px viewport
  - Text below: "Oak Wood x4"
  - Color: Green if have enough, red if insufficient
  - Padding: 16px between items

**Craft Button:**

- Full width
- Height: 56px
- Background: `RGB(80, 180, 80)` (green) when craftable
- Background: `RGB(60, 60, 60)` (gray) when disabled
- Text: "CRAFT" or "CRAFT (1x)" or "NEED ITEMS"
- Font: 24px, bold, white
- Hover state: Slight brightness increase
- Single tap/click crafts item directly to inventory

**Behavior:**

- No recipe selected: Panel shows placeholder "Select a recipe"
- Recipe selected: Shows ingredients and craft button
- After crafting: Update button state immediately
- If inventory full: Show error notification (existing system)

---

## 5. Consistency with Furnace/Smelting UI

### Visual Consistency

**Shared Elements:**

- Slot styling: Dark background `RGB(31, 31, 31)` with 0.4 transparency
- Border color: `RGB(35, 35, 35)`, 2px thickness
- Rounded corners: 4px for slots, 8px for panels
- Background texture: `rbxassetid://82824299358542` at 0.6 transparency
- Label font: Upheaval BRK, 24px, `RGB(140, 140, 140)`

**Color Palette:**

- Panel background: `RGB(58, 58, 58)`
- Slot background: `RGB(31, 31, 31)`
- Hover color: `RGB(80, 80, 80)`
- Border color: `RGB(77, 77, 77)`
- Text primary: `RGB(255, 255, 255)`
- Text muted: `RGB(140, 140, 140)`
- Success green: `RGB(80, 180, 80)`
- Error red: `RGB(220, 100, 100)`

### Layout Patterns

**From FurnaceUI:**

- Labeled sections (INVENTORY, HOTBAR, etc.)
- Consistent slot sizing (60×60 visual)
- Vertical stacking of sections
- Clear visual hierarchy

**From SmithingUI:**

- Recipe grid with scrolling
- Recipe detail panel below grid
- Ingredient display with icons + counts
- Color-coded availability (green/red)
- Single-action craft button

---

## 6. Responsive Design & Aspect Ratios

### Mobile Landscape (Primary Target)

**Screen sizes:** 800×600, 960×640, 1024×768

**Adaptations:**

- Panel width: 640px fits comfortably with margins
- Touch targets: All buttons ≥44px height
- Tab row: Full-width tappable areas
- Scrolling: Recipe grid scrolls if > 3 rows visible
- Spacing: Generous padding for finger taps

### PC/Desktop

**Screen sizes:** 1920×1080, 1440×900

**Adaptations:**

- Panel centered on screen (same as current)
- Hover states enabled for tabs/buttons/slots
- Mouse cursor for drag-and-drop (existing system)
- Keyboard shortcuts maintained (E to open/close, 1-9 for hotbar)

### Scaling System

**Current system:** `UIScaler` with base resolution 1920×1080

- Maintains proportions across devices
- Minimum scale: 0.6 for small screens
- Already handles scaling automatically

**New panel considerations:**

- 640px width × ~570px height base dimensions
- Scales proportionally with existing system
- Test on minimum supported resolution (phone landscape)

---

## 7. Implementation File Changes

### Primary Files to Modify

#### `VoxelInventoryPanel.lua` (Main refactor)

**Structural changes:**

1. **Remove** `CreateMenuColumn()` function
2. **Add** `CreateTabRow()` function
3. **Refactor** `CreateContentColumn()` → `CreateContentArea()`
4. **Refactor** `CreateInventoryColumn()` → Merge into inventory tab content
5. **Update** `INVENTORY_CONFIG` constants for new dimensions

**New functions:**

```lua
function VoxelInventoryPanel:CreateTabRow(parent)
  -- Create horizontal tab navigation
  -- Tabs: [Inventory] [Crafting]
  -- Handle tab switching logic
end

function VoxelInventoryPanel:SetActiveTab(tabName)
  -- Switch between "inventory" and "crafting"
  -- Update tab visual states
  -- Show/hide content frames
end

function VoxelInventoryPanel:CreateInventoryTabContent(parent)
  -- Vertical layout: Armor → Inventory → Hotbar
  -- Reuse existing slot creation functions
end

function VoxelInventoryPanel:CreateCraftingTabContent(parent)
  -- Container for CraftingPanel
end
```

**Configuration updates:**

```lua
local INVENTORY_CONFIG = {
  -- Panel dimensions
  PANEL_WIDTH = 640,
  TAB_ROW_HEIGHT = 60,
  HEADER_HEIGHT = 54,

  -- Tab styling
  TAB_ICON_SIZE = 32,
  TAB_TEXT_SIZE = 24,
  TAB_PADDING = 12,

  -- Content area
  CONTENT_PADDING = 12,
  SECTION_SPACING = 16,

  -- Slot configuration (unchanged)
  SLOT_SIZE = 56,
  SLOT_SPACING = 5,

  -- Armor slots
  ARMOR_SLOT_SIZE = 56,
  ARMOR_SPACING = 8,

  -- Grid dimensions
  INVENTORY_COLUMNS = 9,
  INVENTORY_ROWS = 3,
  HOTBAR_SLOTS = 9,

  -- Colors (unchanged from current)
  -- ...
}
```

#### `CraftingPanel.lua` (Minor refactor)

**Changes:**

1. **Update** grid layout to fit new 640px width
2. **Add** recipe detail panel (inspired by SmithingUI)
3. **Adjust** grid columns: 5-6 columns instead of current
4. **Implement** single-click recipe selection + detail view

**New/modified functions:**

```lua
function CraftingPanel:CreateRecipeGrid(parent)
  -- Adjust for new width (640px - padding)
  -- 5-6 columns, scrollable
end

function CraftingPanel:CreateRecipeDetailPanel(parent)
  -- Inspired by SmithingUI.CreateRecipeInfo()
  -- Shows selected recipe ingredients + craft button
end

function CraftingPanel:OnRecipeSelected(recipeId)
  -- Update detail panel
  -- Single-click interaction (no hover delay)
end

function CraftingPanel:UpdateRecipeDetail(recipeId)
  -- Populate detail panel with recipe info
  -- Update craft button state
end
```

#### Optional: New component file

Consider creating `TabNavigation.lua` as a reusable component:

```lua
-- Reusable horizontal tab navigation component
-- Can be used for future UIs (e.g., quest log, skills, etc.)
```

---

## 8. Animation & Transitions

Per requirements: **Keep transitions simple, no complex animations**

### Tab Switching

- **Instant** content swap (no slide/fade)
- Tab state update: 0.15s ease for color/border changes only
- Content visibility: Immediate show/hide

### Panel Open/Close

- Keep existing animation (0.2s grow from top)
- No changes to current behavior

### Button Interactions

- Hover states: 0.15s ease (PC only)
- Click feedback: Slight scale (0.95x) for 0.1s
- Craft button: Instant state change (craftable ↔ disabled)

---

## 9. Testing & Validation Checklist

### Functional Testing

- [ ] Tab switching works correctly (Inventory ↔ Crafting)
- [ ] Armor slots display and equip correctly
- [ ] Inventory slots maintain drag-and-drop functionality
- [ ] Hotbar slots show selection state and numbers
- [ ] Recipe grid shows all recipes (filtered correctly)
- [ ] Recipe selection updates detail panel
- [ ] Craft button works and adds items to inventory
- [ ] Inventory full error shows correctly
- [ ] Cursor item (drag) displays correctly
- [ ] Shift-click quick transfer works

### Visual Testing

- [ ] Layout matches Minecraft-style design
- [ ] Consistent with Furnace/Smelting UI styling
- [ ] All labels use correct font and sizing
- [ ] Colors match existing palette
- [ ] Borders and shadows render correctly
- [ ] Icons display at correct sizes
- [ ] Stack counts visible and readable

### Responsive Testing

- [ ] Mobile landscape (800×600): All elements visible, tappable
- [ ] Mobile landscape (1024×768): Proper scaling
- [ ] PC (1920×1080): Centered and scaled correctly
- [ ] PC (1440×900): No overflow or clipping
- [ ] UIScaler maintains proportions at min scale (0.6)
- [ ] Touch targets ≥44px on mobile

### Cross-platform Testing

- [ ] PC: Mouse hover states work
- [ ] PC: Keyboard shortcuts work (E, 1-9, Escape)
- [ ] Mobile: Touch interactions work (tap, drag)
- [ ] Mobile: No hover-dependent interactions
- [ ] Gamepad: Navigation works (if supported)

---

## 10. File Structure & Code Organization

### Modified Files

1. [`VoxelInventoryPanel.lua`](src/StarterPlayerScripts/Client/UI/VoxelInventoryPanel.lua) - Main refactor
2. [`CraftingPanel.lua`](src/StarterPlayerScripts/Client/UI/CraftingPanel.lua) - Layout adjustments
3. Optional: Create new `TabNavigation.lua` component

### Reused Components

- `BlockViewportCreator` - Item rendering (unchanged)
- `IconManager` - Tab icons (unchanged)
- `FontBinder` - Custom font application (unchanged)
- `UIScaler` - Responsive scaling (unchanged)
- `ItemStack` - Inventory data (unchanged)
- `ClientInventoryManager` - Inventory logic (unchanged)

### No Changes Required

- Drag-and-drop system (Minecraft mechanics)
- Slot interaction handlers
- Server communication (EventManager)
- Armor equip/unequip logic
- Hotbar selection system
- Cursor item display

---

## 11. Alignment & Spacing Guidelines

### Horizontal Centering

- Main panel: Centered on screen (anchor 0.5, 0.5)
- Inventory grid: Centered in 640px width
- Hotbar: Centered (same as inventory grid)
- Armor slots: Left-aligned or centered (decide during implementation)

### Vertical Spacing

- Section label to content: 8px
- Between sections: 16px
- Panel padding: 12px all sides
- Tab row: No padding (full width sections)

### Visual Hierarchy

1. **Level 1**: Header title (54px font, white)
2. **Level 2**: Tab labels (24px font, white when active)
3. **Level 3**: Section labels (24px font, muted gray)
4. **Level 4**: Item counts, numbers (20px font, white)

---

## 12. Future Scalability

### Additional Tab Support

Design allows for easy addition of new tabs:

- Update tab row layout to distribute N tabs
- Add new content frame for tab
- Example future tabs: "Skills", "Quests", "Stats"

### Tab Configuration

Store tab definitions in config:

```lua
local TABS = {
  { id = "inventory", label = "Inventory", icon = "Package" },
  { id = "crafting", label = "Crafting", icon = "Hammer" },
  -- { id = "skills", label = "Skills", icon = "Star" }, -- Future
}
```

### Maintainability

- Separate tab navigation logic from content
- Keep existing slot component patterns
- Reuse existing styling constants
- Document any new magic numbers

---

## Summary

This redesign transforms the inventory from a 3-column desktop-oriented layout to a modern, single-column Minecraft-style UI optimized for both mobile and PC. The horizontal tab navigation provides clear, accessible switching between Inventory and Crafting modes, while maintaining consistency with existing UI patterns from Furnace and Smelting interfaces.

**Key improvements:**

- ✅ Mobile-friendly single-column layout
- ✅ Intuitive horizontal tab navigation
- ✅ Minecraft-style vertical inventory structure
- ✅ Streamlined crafting with detail panel
- ✅ Consistent with existing UI design system
- ✅ Scalable for future tab additions
- ✅ No complex animations (simple, fast UX)

**Implementation priority:**

1. Update VoxelInventoryPanel layout structure (tabs + content)
2. Refactor inventory tab content (armor + inventory + hotbar vertical)
3. Update CraftingPanel for new width + add detail panel
4. Test responsive behavior on mobile/PC
5. Polish styling and spacing
6. Comprehensive testing across devices