# Sheep Position Debug

## Current Implementation

### Spawn Position
```lua
worldY = blockY * BLOCK_SIZE + BLOCK_SIZE + 0.01
// blockY=64: worldY = 192 + 3 + 0.01 = 195.01 studs
```

### Root Offset Applied
```lua
rootOffset = Vector3.new(0, px(6), 0) = (0, 1.125, 0)
adjustedCFrame = worldPos * CFrame.new(rootOffset)
// Root at: 195.01 + 1.125 = 196.135 studs
```

### Part Positions (in model space + root offset)

**LEGS:**
```lua
size = Vector3.new(px(4), px(12), px(4)) = (0.75, 2.25, 0.75) studs
cframe = CFrame.new(px(-3), px(6), px(7))
// Center at: 196.135 + 1.125 = 197.26 studs
// Bottom at: 197.26 - 1.125 = 196.135 studs
// Top at: 197.26 + 1.125 = 198.385 studs
```

**BODY SKIN:** (Current Y=15)
```lua
size = Vector3.new(px(8), px(6), px(16)) = (1.5, 1.125, 3) studs
cframe = CFrame.new(0, px(15), px(2))
// Center at: 196.135 + 2.8125 = 198.9475 studs
// Bottom at: 198.9475 - 0.5625 = 198.385 studs
// Top at: 198.9475 + 0.5625 = 199.51 studs
```

**Result:**
- Leg top: 198.385 studs
- Body bottom: 198.385 studs
- **PERFECT! No gap, they touch exactly!**

**BODY WOOL:** (Y=15, inflate 1.75)
```lua
size = Vector3.new(px(11.5), px(9.5), px(19.5)) = (2.15625, 1.78125, 3.65625) studs
cframe = CFrame.new(0, px(15), px(2))
// Center at: 196.135 + 2.8125 = 198.9475 studs
// Bottom at: 198.9475 - 0.890625 = 198.057 studs
// Top at: 198.9475 + 0.890625 = 199.838 studs
```

**Wool coverage:**
- Wool bottom: 198.057 studs
- Leg top: 198.385 studs
- **GAP: 0.328 studs (1.75 pixels)**

## THE PROBLEM

The wool bottom (198.057) is **BELOW** the leg top (198.385), so there should be NO gap!

**If you're seeing a gap, it's because:**
1. The body SKIN is in the way (same color as legs, makes it look like a gap)
2. Z-fighting between wool and body skin
3. Or the positioning is being overridden somewhere

## Solutions to Test

### Option 1: Make body skin transparent
```lua
BodySkin = {
    ...
    transparency = 1  // Hide body skin, only show wool
}
```

### Option 2: Remove body skin entirely
```lua
-- Just use the wool layer
```

### Option 3: Lower body even more
```lua
BODY_CENTER_Y = px(12)  // Body bottom at Y=9, 3px overlap
```

## Debug Command

Run this in Studio command bar after spawning a sheep:
```lua
local mob = workspace.MobEntities:FindFirstChildWhichIsA("Model")
if mob then
    for _, part in ipairs(mob:GetDescendants()) do
        if part:IsA("BasePart") then
            local bounds = part.CFrame * CFrame.new(0, -part.Size.Y/2, 0)
            print(part.Name, "bottom Y:", bounds.Position.Y, "top Y:", (part.CFrame * CFrame.new(0, part.Size.Y/2, 0)).Position.Y)
        end
    end
end
```

This will show the exact world positions of each part's top and bottom edges.

