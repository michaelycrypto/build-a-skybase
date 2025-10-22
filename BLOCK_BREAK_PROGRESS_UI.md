# Block Break Progress Bar UI

## Overview
A minimal, high-UX progress bar that appears below the crosshair when breaking blocks, providing visual feedback on block breaking progress.

## Features

### Visual Design
- **Position**: Centered below crosshair (40px offset)
- **Size**: 120px × 6px
- **Colors**:
  - Fill: Vibrant cyan (`rgb(85, 255, 255)`) with subtle glow
  - Background: Dark blue-gray (`rgb(20, 20, 25)`)
  - Border: Subtle gray (`rgb(50, 50, 60)`)
- **Style**: Rounded corners (3px radius) for modern look
- **Effects**: Subtle border and glow for polished appearance

### UX Animations
- **Smooth fade-in**: 0.1s when breaking starts
- **Smooth fade-out**: 0.2s when breaking stops
- **Progress animation**: Smooth linear transition as progress updates
- **Auto-hide**: Fades away after 0.3s of no updates

### Smart Behavior
- Only shows for the local player's breaking actions
- Automatically appears when breaking starts
- Smoothly updates as progress changes (0% → 100%)
- Auto-hides when:
  - Player releases mouse button (stops breaking)
  - Block is fully broken
  - Target changes
  - After timeout period

## Files Modified/Created

### New File
- `src/StarterPlayerScripts/Client/UI/BlockBreakProgress.lua`
  - Self-contained UI module
  - Handles all animations and state management
  - Clean API: `Create()`, `UpdateProgress()`, `Reset()`, `Destroy()`

### Modified Files
1. `src/StarterPlayerScripts/Client/GameClient.client.lua`
   - Added initialization in `completeInitialization()` (line ~408)
   - Wired up `BlockBreakProgress` event handler (line ~622)
   - Added reset on `BlockBroken` event (line ~642)

2. `src/StarterPlayerScripts/Client/Controllers/BlockInteraction.lua`
   - Added comment in `stopBreaking()` explaining auto-hide behavior

## Integration Points

```lua
-- Server sends progress events (already implemented in VoxelWorldService)
EventManager:FireEventToAll("BlockBreakProgress", {
    x = x, y = y, z = z,
    progress = 0.5,  -- 0.0 to 1.0
    playerUserId = player.UserId
})

-- Client receives and displays (newly implemented)
EventManager:RegisterEvent("BlockBreakProgress", function(data)
    if data.playerUserId == player.UserId then
        Client.blockBreakProgress:UpdateProgress(data.progress)
    end
end)
```

## Visual Reference

```
┌─────────────────────────┐
│                         │
│           +             │  ← Crosshair
│                         │
│     ████████░░░░        │  ← Progress bar (66% filled)
│                         │
└─────────────────────────┘
```

## Configuration
All visual settings can be tweaked at the top of `BlockBreakProgress.lua`:
- `BAR_WIDTH`: Width in pixels (default: 120)
- `BAR_HEIGHT`: Height in pixels (default: 6)
- `BAR_OFFSET_Y`: Distance below crosshair (default: 40)
- `BAR_COLOR`: Fill color (default: vibrant cyan `rgb(85, 255, 255)`)
- `BAR_BG_COLOR`: Background color (default: dark blue-gray `rgb(20, 20, 25)`)
- `BAR_BORDER_COLOR`: Border color (default: subtle gray `rgb(50, 50, 60)`)
- `CORNER_RADIUS`: Rounded corners (default: 3)
- `FADE_IN_TIME`: Show animation speed (default: 0.1s)
- `FADE_OUT_TIME`: Hide animation speed (default: 0.2s)
- `AUTO_HIDE_DELAY`: Timeout before auto-hide (default: 0.3s)

## Testing
1. Join the game
2. Look at a block
3. Hold left mouse button to break
4. Progress bar should smoothly appear and fill
5. Release early or complete breaking - bar should fade away
6. Try breaking different blocks - bar should show for each

