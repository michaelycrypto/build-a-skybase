# Implementation Plan: Food & Consumables System

## Overview

This document outlines the implementation plan for the Food & Consumables system as specified in `PRD_FOOD_CONSUMABLES.md`. The system enables players to consume food items to restore hunger and saturation, with hunger affecting health regeneration and starvation damage.

## Key Requirements Summary

1. **Hunger & Saturation System**: Track hunger (0-20) and saturation (0-20) per player
2. **Consumption Mechanic**: Right-click with food in hand to eat (1.6s animation)
3. **Food Values**: Match Minecraft food values exactly
4. **Health Integration**: Hunger >= 18 enables health regen; Hunger < 6 causes starvation damage
5. **Visual Feedback**: Hunger bar UI, eating animation, sound effects
6. **3D Item Models**: Use items from `game.ReplicatedStorage.Assets.Tools` for wielding and rendering

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    FOOD CONSUMPTION SYSTEM                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CLIENT SIDE:                                               │
│  ├── FoodController.lua          (Input handling)          │
│  ├── HungerBar.lua              (UI component)             │
│  ├── EatingAnimation.lua         (Character animation)      │
│  └── HeldItemRenderer.lua       (Already exists - use)     │
│                                                             │
│  SERVER SIDE:                                               │
│  ├── HungerService.lua           (Hunger tracking)          │
│  ├── FoodService.lua             (Consumption logic)       │
│  └── PlayerService.lua           (Extend with hunger data)   │
│                                                             │
│  SHARED:                                                     │
│  ├── FoodConfig.lua              (Food values/config)      │
│  └── EventManager.lua            (Events - extend)          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Core Infrastructure (Days 1-2)

### 1.1 Create FoodConfig.lua

**File**: `src/ReplicatedStorage/Shared/FoodConfig.lua`

**Purpose**: Central configuration for all food items, hunger mechanics, and eating behavior.

**Key Components**:
- Food item definitions (hunger, saturation, stack size, effects)
- Hunger depletion rates (walking, sprinting, jumping, etc.)
- Health regeneration requirements
- Starvation damage configuration
- Eating mechanics (duration, cooldown, cancellation rules)

**Food Items to Define** (Initial):
- Apple (ID: 37) - Hunger: 4, Saturation: 2.4, Stack: 64
- Additional foods can be added as they're implemented

**Integration Points**:
- Constants.lua - Reference BlockType.APPLE
- BlockRegistry.lua - Food items are already defined as blocks
- ItemDefinitions.lua - Will need to mark items as food

### 1.2 Extend PlayerService with Hunger Data

**File**: `src/ServerScriptService/Server/Services/PlayerService.lua`

**Changes**:
- Add `hunger` and `saturation` fields to player data structure
- Initialize hunger to 20 and saturation to 20 for new players
- Add methods: `GetHunger()`, `SetHunger()`, `GetSaturation()`, `SetSaturation()`
- Persist hunger/saturation in player data saves

**Data Structure**:
```lua
playerData = {
    -- existing fields...
    hunger = 20,
    saturation = 20,
}
```

### 1.3 Create HungerService.lua

**File**: `src/ServerScriptService/Server/Services/HungerService.lua`

**Purpose**: Server-side service that manages hunger depletion, health regeneration, and starvation.

**Key Responsibilities**:
- Periodic hunger depletion based on player activity
- Health regeneration when hunger >= 18 and saturation > 0
- Starvation damage when hunger < 6
- Sync hunger/saturation to clients

**Activity Tracking**:
- Monitor player movement (walking, sprinting, jumping)
- Track mining, attacking, swimming activities
- Apply depletion rates from FoodConfig

**Health Integration**:
- Use DamageService for starvation damage
- Use DamageService:HealPlayer() for regeneration
- Rate limit: Health regen every 0.5s, starvation every 4s

**Events**:
- `HungerUpdate` - Broadcast to client when hunger/saturation changes

### 1.4 Create FoodService.lua

**File**: `src/ServerScriptService/Server/Services/FoodService.lua`

**Purpose**: Handles food consumption logic, validation, and item removal.

**Key Methods**:
- `HandleStartEating(player, foodId, slotIndex)` - Validate and start eating
- `HandleCompleteEating(player, foodId)` - Apply food effects, consume item
- `HandleCancelEating(player)` - Cancel eating if in progress

**Validation**:
- Check player has food item in inventory/hotbar
- Check hunger is not full (20/20)
- Check not already eating or on cooldown
- Check food item is valid (exists in FoodConfig)

**Item Consumption**:
- Use `PlayerInventoryService:RemoveItemFromHotbarSlot()` or `RemoveItem()`
- Remove 1 item from stack after successful consumption

**Events**:
- `RequestStartEating` (Client → Server)
- `EatingStarted` (Server → Client)
- `RequestCompleteEating` (Client → Server)
- `EatingCompleted` (Server → Client)
- `RequestCancelEating` (Client → Server)

---

## Phase 2: Client-Side Input & Animation (Days 2-3)

### 2.1 Create FoodController.lua

**File**: `src/StarterPlayerScripts/Client/Controllers/FoodController.lua`

**Purpose**: Handle right-click input for food consumption, manage eating state, coordinate with server.

**Key Responsibilities**:
- Detect right-click when holding food item
- Check if item is food (via FoodConfig)
- Request eating start from server
- Track eating progress (1.6s duration)
- Handle eating cancellation (movement, item switch, damage)
- Coordinate with EatingAnimation for visual feedback

**Integration Points**:
- `BlockInteraction.lua` - Right-click handling (modify to check for food)
- `VoxelHotbar.lua` - Get currently selected item
- `GameState` - Track eating state
- `EventManager` - Listen for eating events

**Eating State Machine**:
```lua
EatingState = {
    IDLE = "idle",
    EATING = "eating",      -- Animation in progress
    COOLDOWN = "cooldown"   -- 0.5s after completion
}
```

**Cancellation Conditions**:
- Player moves (check HumanoidRootPart velocity)
- Player switches items
- Player takes damage
- Player presses ESC or cancels manually

### 2.2 Modify BlockInteraction.lua

**File**: `src/StarterPlayerScripts/Client/Controllers/BlockInteraction.lua`

**Changes**:
- Before handling block placement/interaction, check if player is holding food
- If food item in hand and right-click, trigger food consumption instead
- Priority: Food consumption > Block interaction > Block placement

**Logic Flow**:
```lua
-- In right-click handler
local selectedItem = GameState:Get("voxelWorld.selectedBlock")
if selectedItem and FoodConfig.IsFood(selectedItem.id) then
    FoodController:StartEating(selectedItem.id)
    return -- Don't place blocks
end
-- Continue with normal block interaction...
```

### 2.3 Create EatingAnimation.lua

**File**: `src/StarterPlayerScripts/Client/Controllers/EatingAnimation.lua`

**Purpose**: Handle character animation for eating (arm brings food to mouth).

**Key Responsibilities**:
- Animate right arm bringing food item to mouth
- Use TweenService for smooth animation
- Sync with eating duration (1.6 seconds)
- Handle animation cancellation

**Animation Details**:
- Start: Arm at rest position
- Mid: Arm brings food to mouth (rotate shoulder/elbow)
- End: Return to rest position
- Use Humanoid:LoadAnimation() or TweenService on Right Arm joints

**Integration**:
- Called by FoodController when eating starts
- Cancelled if eating is interrupted

### 2.4 Integrate with HeldItemRenderer

**File**: `src/ReplicatedStorage/Shared/HeldItemRenderer.lua` (No changes needed)

**Usage**:
- Food items will automatically render in hand via existing system
- Food items are blocks (not tools), so they use `createBlockHandle()`
- 3D models from `ReplicatedStorage.Assets.Tools` will be used if available
- If no 3D model exists, fall back to block rendering (cross-shaped)

**Note**: 3D models exist in `game.ReplicatedStorage.Assets.Tools` in Studio. These should be referenced by item ID or name matching.

---

## Phase 3: UI Components (Days 3-4)

### 3.1 Create HungerBar.lua

**File**: `src/StarterPlayerScripts/Client/UI/HungerBar.lua`

**Purpose**: Display hunger bar UI with 10 drumstick icons (each = 2 hunger points).

**Key Features**:
- 10 drumstick icons arranged horizontally
- Each icon represents 2 hunger points
- Color coding:
  - Full (18-20): Green
  - Good (12-17): Yellow
  - Low (6-11): Orange
  - Critical (0-5): Red
- Position: Above health bar in StatusBarsHUD

**Integration**:
- Listen to `HungerUpdate` events from server
- Update icons based on current hunger value
- Animate changes smoothly

**UI Structure**:
```lua
HungerBarFrame
├── Icon1 (🍖)
├── Icon2 (🍖)
├── ...
└── Icon10 (🍖)
```

### 3.2 Integrate HungerBar into StatusBarsHUD

**File**: `src/StarterPlayerScripts/Client/UI/StatusBarsHUD.lua`

**Changes**:
- Add HungerBar component above health bar
- Position: Health bar below, Hunger bar above
- Sync with existing health bar styling

### 3.3 Eating Progress Indicator (Optional)

**File**: `src/StarterPlayerScripts/Client/UI/EatingProgressIndicator.lua` (Optional)

**Purpose**: Show eating progress during consumption (small progress bar above hotbar).

**Features**:
- Progress bar that fills over 1.6 seconds
- Appears when eating starts
- Disappears when eating completes or is cancelled
- Position: Above hotbar, centered

---

## Phase 4: Hunger Depletion & Health Integration (Days 4-5)

### 4.1 Implement Activity Tracking

**File**: `src/ServerScriptService/Server/Services/HungerService.lua`

**Tracking Methods**:
- Monitor Humanoid state (walking, running, jumping)
- Track mining events (from VoxelWorldService)
- Track combat events (from CombatController)
- Track swimming (check if player is in water)

**Depletion Rates** (from FoodConfig):
- Walking: 0.01 per second
- Sprinting: 0.1 per second
- Jumping: 0.05 per jump
- Swimming: 0.015 per second
- Mining: 0.005 per block
- Attacking: 0.1 per hit

**Implementation**:
- Run loop every 0.1 seconds
- Check player activity state
- Apply depletion based on activity
- Saturation depletes before hunger

### 4.2 Implement Health Regeneration

**File**: `src/ServerScriptService/Server/Services/HungerService.lua`

**Requirements**:
- Only regenerate when hunger >= 18 AND saturation > 0
- Regenerate 1 HP every 0.5 seconds (half heart)
- Use `DamageService:HealPlayer()`

**Implementation**:
- Check every 0.5 seconds
- If conditions met, heal 1 HP
- Stop if hunger < 18 or saturation <= 0

### 4.3 Implement Starvation Damage

**File**: `src/ServerScriptService/Server/Services/HungerService.lua`

**Requirements**:
- Apply damage when hunger < 6
- Damage: 1 HP every 4 seconds
- Use `DamageService:DamagePlayer()` with type `STARVATION`
- Starvation damage bypasses armor (already handled in DamageService)

**Implementation**:
- Check every 4 seconds
- If hunger < 6, apply 1 damage
- Stop if hunger >= 6

---

## Phase 5: Special Foods & Effects (Days 5-6)

### 5.1 Status Effect System (Foundation)

**File**: `src/ServerScriptService/Server/Services/StatusEffectService.lua` (New, or extend existing)

**Purpose**: Handle status effects from special foods (golden apple = regeneration, etc.).

**Key Features**:
- Track active effects per player
- Effect duration timers
- Effect application/removal
- Effect stacking rules

**Effects to Support** (Initial):
- Regeneration (from golden apple)
- Future: Absorption, Fire Resistance, Resistance (from enchanted golden apple)

**Integration**:
- Called by FoodService when special food is consumed
- Effects apply after eating completes

### 5.2 Status Effect Icons UI

**File**: `src/StarterPlayerScripts/Client/UI/StatusEffectIcons.lua` (New)

**Purpose**: Display status effect icons above hunger bar.

**Features**:
- Icon for each active effect
- Duration timer below icon
- Tooltip on hover (effect details)
- Position: Above hunger bar

### 5.3 Golden Apple Implementation

**File**: `src/ReplicatedStorage/Shared/FoodConfig.lua`

**Add**:
- Golden Apple definition (if item exists)
- Hunger: 4, Saturation: 9.6
- Effect: Regeneration II (5 seconds)

---

## Phase 6: Polish & Testing (Days 6-7)

### 6.1 Sound Effects

**Files**: Various

**Add**:
- Eating sound effect (plays during eating animation)
- Hunger bar update sound (subtle)
- Starvation warning sound (when hunger < 6)

**Integration**:
- SoundService or AudioService
- Play sounds at appropriate times

### 6.2 Visual Polish

**Files**: Various

**Add**:
- Eating particle effects (optional)
- Hunger bar animations (smooth transitions)
- Eating completion feedback (brief flash/glow)

### 6.3 Testing Checklist

**Core Functionality**:
- [ ] Right-click with food starts eating
- [ ] Eating animation plays correctly
- [ ] Food is consumed after 1.6 seconds
- [ ] Hunger and saturation restore correctly
- [ ] Cannot eat when hunger is full
- [ ] Eating cooldown works (0.5s)

**Cancellation**:
- [ ] Moving cancels eating
- [ ] Switching items cancels eating
- [ ] Taking damage cancels eating
- [ ] Manual cancel works

**Hunger System**:
- [ ] Hunger depletes over time
- [ ] Saturation depletes before hunger
- [ ] Health regenerates when hunger >= 18
- [ ] Starvation damage when hunger < 6
- [ ] Hunger bar UI updates correctly

**Multiplayer**:
- [ ] Hunger syncs across clients
- [ ] Eating state syncs correctly
- [ ] No duplication exploits

**Edge Cases**:
- [ ] Eating with full inventory (should still work)
- [ ] Eating last item in stack (stack should become empty)
- [ ] Eating while dead (should not work)
- [ ] Rapid clicking (cooldown prevents spam)

---

## File Structure Summary

### New Files

```
src/
├── ReplicatedStorage/
│   └── Shared/
│       └── FoodConfig.lua                    # Food values & config
│
├── ServerScriptService/Server/
│   └── Services/
│       ├── HungerService.lua                # Hunger tracking & depletion
│       ├── FoodService.lua                  # Food consumption logic
│       └── StatusEffectService.lua          # Status effects (optional)
│
└── StarterPlayerScripts/Client/
    ├── Controllers/
    │   ├── FoodController.lua               # Eating input handling
    │   └── EatingAnimation.lua              # Character animation
    └── UI/
        ├── HungerBar.lua                    # Hunger bar UI
        └── EatingProgressIndicator.lua      # Progress bar (optional)
```

### Modified Files

```
src/
├── ServerScriptService/Server/
│   └── Services/
│       └── PlayerService.lua                # Add hunger/saturation data
│
└── StarterPlayerScripts/Client/
    ├── Controllers/
    │   └── BlockInteraction.lua             # Add food right-click check
    └── UI/
        └── StatusBarsHUD.lua                # Integrate HungerBar
```

---

## Event Flow Diagram

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│   CLIENT    │      │   SERVER    │      │   CLIENT    │
│FoodController│      │ FoodService │      │ HungerBar   │
└──────┬──────┘      └──────┬──────┘      └──────┬──────┘
       │                     │                    │
       │ Right-click food    │                    │
       │────────────────────>│                    │
       │                     │                    │
       │                     │ Validate:          │
       │                     │ - Has food?        │
       │                     │ - Can eat?         │
       │                     │                    │
       │<────────────────────│ EatingStarted      │
       │                     │                    │
       │ [Play animation]     │                    │
       │                     │                    │
       │ [Track progress]    │                    │
       │                     │                    │
       │ [1.6s elapsed]      │                    │
       │────────────────────>│ CompleteEating     │
       │                     │                    │
       │                     │ Consume food       │
       │                     │ Update hunger      │
       │                     │ Apply effects      │
       │                     │                    │
       │<────────────────────│ EatingCompleted    │
       │                     │                    │
       │                     │───────────────────>│ UpdateHungerBar
       │                     │                    │
```

---

## Integration with Existing Systems

### HeldItemRenderer Integration

- Food items are blocks (not tools), so they render via `HeldItemRenderer.AttachItem()`
- 3D models from `ReplicatedStorage.Assets.Tools` should be referenced by item ID
- If model doesn't exist, fall back to block rendering (cross-shaped)
- Food items will appear in hand when selected in hotbar

### Inventory System Integration

- Use `PlayerInventoryService:RemoveItemFromHotbarSlot()` to consume food
- Food items use existing ItemStack system
- Stack sizes defined in FoodConfig (most foods: 64, stews: 1)

### Health System Integration

- Use `DamageService:HealPlayer()` for regeneration
- Use `DamageService:DamagePlayer()` with type `STARVATION` for starvation
- Starvation damage type already bypasses armor (defined in DamageService)

### Event System Integration

- Extend `EventManager` with new events:
  - `RequestStartEating`
  - `EatingStarted`
  - `RequestCompleteEating`
  - `EatingCompleted`
  - `RequestCancelEating`
  - `HungerUpdate`

---

## Testing Strategy

### Unit Tests

- FoodConfig: Verify food values match Minecraft
- HungerService: Test depletion rates, health regen, starvation
- FoodService: Test validation, consumption, item removal

### Integration Tests

- End-to-end eating flow
- Hunger depletion during gameplay
- Health regeneration with full hunger
- Starvation damage with low hunger

### Manual Testing

- Test all food items
- Test eating cancellation scenarios
- Test multiplayer synchronization
- Test edge cases (full inventory, last item, etc.)

---

## Future Enhancements (Post-MVP)

1. **Additional Foods**: Bread, cooked meats, stews, etc.
2. **Food Crafting**: Cooking recipes (raw → cooked)
3. **Advanced Effects**: Enchanted golden apple, suspicious stew
4. **Food Quality**: Freshness system, food poisoning
5. **Visual Polish**: Particle effects, better animations
6. **Audio**: More sound effects, ambient hunger sounds

---

## Notes

- **3D Models**: 3D models exist in `game.ReplicatedStorage.Assets.Tools` in Studio. These should be referenced by matching item ID or name. If a model doesn't exist for a food item, the system should fall back to block rendering.

- **Minecraft Parity**: All food values and mechanics should match Minecraft exactly as specified in the PRD.

- **Performance**: Hunger depletion checks should be rate-limited (every 0.1s) to avoid performance issues with many players.

- **Multiplayer**: All hunger/saturation state must be server-authoritative to prevent cheating.

---

*Implementation Plan Version: 1.0*
*Created: January 2026*
*Related: [PRD_FOOD_CONSUMABLES.md](./PRDs/PRD_FOOD_CONSUMABLES.md)*
