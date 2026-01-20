# PRD: F3 Debug Mode

## Overview
A simple debug overlay toggled with F3 (similar to Minecraft).

## Display Information

**Left Panel - Debug:**
- Coordinates (grid position X, Y, Z)
- Facing direction (cardinal + degrees)
- Velocity (studs/second)
- FPS, Memory (MB), Ping (ms)

**Right Panel - Target:**
- Block name at crosshair
- Block position

## User Experience

- Press **F3** to toggle overlay
- Default: Hidden
- Top corners, semi-transparent dark background
- BuilderSansBold for titles, RobotoMono for data

## Technical

- Client-side only
- 10 Hz update rate
- FPS smoothed over 10 frames
- No performance impact when hidden

## Terminology

| Term | Meaning |
|------|---------|
| **Coordinates** | Grid position = `floor(studs / 3)`. Each block is 3×3×3 studs |
| **Facing** | Compass direction camera is pointing (N/S/E/W + degrees) |
| **Target** | The block at crosshair |
