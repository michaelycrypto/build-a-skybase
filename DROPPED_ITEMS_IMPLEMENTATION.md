# Dropped Items System - Implementation Summary

## Overview
A complete Minecraft-style dropped item system has been implemented for the voxel game. Items now pop out when blocks are broken, can be picked up by walking near them, and players can drop items manually using the Q key.

## Architecture

### Core Components

#### 1. **DroppedItem.lua** (Shared)
**Location:** `/src/ReplicatedStorage/Shared/DroppedItem.lua`

**Purpose:** Data structure representing a dropped item in the world

**Key Features:**
- Item ID and stack count tracking
- Position and velocity for physics simulation
- Lifetime tracking (5-minute despawn timer)
- Merging logic for same-type items within 2-stud radius
- Serialization/deserialization for network transmission
- Built-in physics simulation (gravity, collision, air resistance)

**Constants:**
- `LIFETIME = 300` seconds (5 minutes)
- `FLASH_WARNING_TIME = 285` seconds (flash starts at 4:45)
- `MERGE_RADIUS = 2` studs
- `PICKUP_RADIUS = 3` studs

---

#### 2. **DroppedItemService.lua** (Server)
**Location:** `/src/ServerScriptService/Server/Services/DroppedItemService.lua`

**Purpose:** Server-authoritative management of all dropped items

**Key Features:**
- **Item Spawning:** Spawns dropped items with pop-out physics
- **Physics Simulation:** 20Hz server-side physics loop (gravity, collision, velocity)
- **Auto-Merging:** Combines nearby items of the same type every 1 second
- **Despawn Management:** Removes items after 5 minutes
- **Pickup Validation:** Server validates distance and inventory space before allowing pickup
- **Network Synchronization:** Broadcasts item spawn/despawn/update events to all clients

**Dependencies:**
- VoxelWorldService (for block collision detection)
- PlayerInventoryService (for adding items to player inventory)

**Network Events Handled:**
- `RequestItemPickup` - Client requests to pick up an item (registered via `EventManager:CreateServerEventConfig`)
- `RequestDropItem` - Client requests to drop an item from inventory (registered via `EventManager:CreateServerEventConfig`)

**Network Events Fired:**
- `DroppedItemSpawned` - Item spawned in world
- `DroppedItemDespawned` - Item removed from world
- `DroppedItemUpdated` - Item count changed (merge)
- `ItemPickedUp` - Item successfully picked up

**Architecture Pattern:**
- Follows the existing EventManager pattern used by VoxelWorldService, ChestStorageService, etc.
- Event handlers are registered in `EventManager:CreateServerEventConfig` in Bootstrap
- Event definitions are in `EventManifest.lua` for proper type validation

---

#### 3. **DroppedItemController.lua** (Client)
**Location:** `/src/StarterPlayerScripts/Client/Controllers/DroppedItemController.lua`

**Purpose:** Client-side rendering and animation of dropped items

**Key Features:**
- **Visual Representation:** Creates 3D mini-blocks (1.5x1.5x1.5 studs)
- **Animations:**
  - Continuous Y-axis rotation (2 rad/sec)
  - Sine wave bobbing (0.3 stud amplitude)
  - Flash warning before despawn
  - Pop-in spawn animation
  - Shrink despawn animation
- **Automatic Pickup Detection:** Checks for nearby items twice per second
- **Particle Effects:**
  - Sparkle burst on spawn
  - Green sparkles on pickup
  - Smoke poof on timeout despawn
- **Sound Effects:** Pop sound on pickup (ID: `6895079853`)
- **Count Labels:** Billboard GUI showing stack count if > 1
- **Glow Effect:** Highlight outline for visibility

---

### Integration Points

#### 4. **VoxelWorldService.lua** (Modified)
**Changes:** Added dropped item spawning on block break

**Location:** Line ~428-437
```lua
-- Spawn dropped item if player can harvest the block
if canHarvest and self.Deps and self.Deps.DroppedItemService then
    self.Deps.DroppedItemService:SpawnDroppedItem(
        blockId,
        1, -- Drop 1 item
        Vector3.new(x, y, z),
        nil, -- Auto-generate pop-out velocity
        true -- Is block coordinates
    )
end
```

**Behavior:**
- Only spawns items if block is harvestable (correct tool tier)
- Converts block coordinates to world coordinates
- Generates random pop-out velocity

---

#### 5. **Bootstrap.server.lua** (Modified)
**Changes:** Added DroppedItemService to dependency injection

**Added Lines:**
- Service binding (line 83-87)
- Service resolution (line 103)
- Service injection into VoxelWorldService (line 108-109)
- Added to services table (line 121)
- Registered network events (lines 171-175)

**Network Events Registered:**
- `DroppedItemSpawned`
- `DroppedItemDespawned`
- `DroppedItemUpdated`
- `ItemPickedUp`

---

#### 6. **GameClient.client.lua** (Modified)
**Changes:** Added DroppedItemController initialization

**Location:** Line ~408-412
```lua
-- Initialize Dropped Item Controller (rendering dropped items)
local DroppedItemController = require(script.Parent.Controllers.DroppedItemController)
DroppedItemController:Initialize()
Client.droppedItemController = DroppedItemController
```

**Initialization:** Happens after BlockInteraction, during complete initialization phase

---

#### 7. **VoxelHotbar.lua** (Modified)
**Changes:** Added Q key to drop items from hotbar

**New Function:** `DropSelectedItem()` (line 355-381)
```lua
function VoxelHotbar:DropSelectedItem()
    -- Drops 1 item from selected slot
    -- Optimistically updates client UI
    -- Sends RequestDropItem event to server
end
```

**Input Binding:** Q key now drops the currently selected item

---

## System Flow

### Block Breaking → Item Drop
1. Player breaks block with correct tool
2. VoxelWorldService checks if block is harvestable
3. If harvestable, spawns dropped item at block position
4. DroppedItemService creates DroppedItem with random pop-out velocity
5. Server broadcasts `DroppedItemSpawned` to all clients
6. DroppedItemController creates visual model for each client
7. Item animates (rotation, bobbing) and falls via physics

### Item Pickup
1. DroppedItemController checks for nearby items (every 0.5 sec)
2. If player within 3 studs, sends `RequestItemPickup` to server
3. DroppedItemService validates:
   - Item still exists
   - Player is within 3 studs (anti-cheat)
   - Player has inventory space
4. If valid, adds to PlayerInventoryService
5. Removes item from world
6. Broadcasts `DroppedItemDespawned` with reason "picked_up"
7. DroppedItemController plays pickup effects and sound

### Manual Item Drop (Q Key)
1. Player presses Q key
2. VoxelHotbar removes 1 item from selected slot
3. Sends `RequestDropItem` to server with itemId and count
4. DroppedItemService spawns item in front of player
5. Item gets forward velocity based on player's look direction
6. Item spawns 3 studs in front of player's head

### Item Merging
1. Every 1 second, DroppedItemService checks all items
2. For each pair of items:
   - Same item type?
   - Within 2 studs?
   - Combined count ≤ 64?
3. If yes, merges B into A
4. Broadcasts `DroppedItemUpdated` with new count
5. Broadcasts `DroppedItemDespawned` for merged item

### Item Despawning
1. Every 2 seconds, checks item ages
2. If age ≥ 285 seconds (4:45), starts flashing
3. If age ≥ 300 seconds (5:00), despawns
4. Broadcasts `DroppedItemDespawned` with reason "timeout"
5. Client plays smoke poof particle effect

---

## Physics Simulation

### Server-Side (Authoritative)
- **Update Rate:** 20Hz (50ms intervals)
- **Gravity:** -50 studs/sec²
- **Air Resistance:** 0.95 multiplier per frame
- **Ground Collision:** Checks block at item position, stops at block top
- **Velocity Damping:** 50% velocity loss on ground impact

### Pop-Out Velocity (on spawn)
- **X:** Random(-5, 5) studs/sec
- **Y:** Random(8, 12) studs/sec (upward)
- **Z:** Random(-5, 5) studs/sec

### Drop Velocity (Q key)
- **Direction:** Player's look vector × 10
- **Upward:** +5 studs/sec (slight arc)

---

## Visual Effects

### Animations
- **Rotation:** Continuous spin around Y-axis (2 rad/sec)
- **Bobbing:** Sine wave vertical motion (0.3 stud amplitude, 2 Hz)
- **Flash Warning:** Alternates transparency at 4:45 remaining
- **Spawn:** Scale tween from 0.1 to 1.5 (0.2 sec, BackOut easing)
- **Despawn:** Scale tween from 1.5 to 0.1 (0.3 sec, BackIn easing)

### Particle Effects
1. **Spawn:** 10 yellow sparkles, radial burst
2. **Pickup:** 8 green sparkles, upward burst
3. **Timeout Despawn:** 15 gray smoke particles, poof effect

### Sound Effects
- **Pickup:** Pop sound (ID: 6895079853, volume: 0.3, pitch: 1.2)

### Visual Components
- **Size:** 1.5×1.5×1.5 studs (smaller than normal blocks)
- **Material:** Inherits from block type
- **Color:** Inherits from block type
- **Highlight:** Yellow glow outline
- **Billboard:** Stack count label (if count > 1)
- **Number Overlay:** Shows item type icon

---

## Configuration & Tuning

### DroppedItem Constants (Adjustable)
```lua
DroppedItem.LIFETIME = 300              -- 5 minutes
DroppedItem.FLASH_WARNING_TIME = 285    -- Flash at 4:45
DroppedItem.MERGE_RADIUS = 2            -- Studs
DroppedItem.PICKUP_RADIUS = 3           -- Studs
```

### Physics Constants (in DroppedItem:UpdatePhysics)
```lua
GRAVITY = -50                           -- Studs/sec²
AIR_RESISTANCE = 0.95                   -- Multiplier
```

### Animation Constants (in DroppedItemController)
```lua
ROTATION_SPEED = 2                      -- Radians/sec
BOB_SPEED = 2                           -- Hz
BOB_AMPLITUDE = 0.3                     -- Studs
PICKUP_ANIMATION_TIME = 0.3             -- Seconds
FLASH_INTERVAL = 0.2                    -- Seconds
```

### Update Intervals (in DroppedItemService)
```lua
UPDATE_INTERVAL = 0.05                  -- 20 Hz physics
MERGE_CHECK_INTERVAL = 1.0              -- 1 Hz merging
DESPAWN_CHECK_INTERVAL = 2.0            -- 0.5 Hz cleanup
```

---

## Performance Considerations

### Optimizations Implemented
1. **Client-Side Culling:** Only renders items in loaded chunks
2. **Server-Side Batching:** Physics updates at fixed 20Hz
3. **Merge System:** Reduces item count automatically
4. **Despawn Timer:** Prevents world clutter
5. **Pickup Check Rate:** Only checks twice per second
6. **Particle Bursts:** One-time emissions, not continuous

### Scalability
- **Max Items:** No hard limit, but merging prevents buildup
- **Network Traffic:** Events only sent when items spawn/despawn/pickup
- **Memory:** Each item ~1KB (data) + visual model
- **CPU:** 20Hz physics loop is lightweight (simple collision)

---

## Testing Checklist

### Block Breaking
- [x] Item pops out when breaking blocks
- [x] Item only drops with correct tool
- [x] Item has random pop-out velocity
- [x] Item lands on ground/blocks

### Pickup System
- [x] Walking near item picks it up
- [x] Item adds to inventory
- [x] Pickup sound plays
- [x] Pickup particles appear
- [x] Distance validation (3 studs)

### Manual Drop (Q Key)
- [x] Q key drops 1 item from selected slot
- [x] Item spawns in front of player
- [x] Item has forward velocity
- [x] Hotbar updates immediately

### Item Merging
- [x] Same items within 2 studs merge
- [x] Merge respects 64 stack limit
- [x] Merged items disappear
- [x] Count label updates

### Despawn System
- [x] Items despawn after 5 minutes
- [x] Items flash warning at 4:45
- [x] Despawn plays smoke effect
- [x] Despawn removes from client

### Visual Polish
- [x] Items rotate continuously
- [x] Items bob up and down
- [x] Spawn animation scales up
- [x] Despawn animation scales down
- [x] Particle effects on spawn/pickup/despawn
- [x] Glow highlight visible

### Network Sync
- [x] Items visible to all players
- [x] One player picking up removes for all
- [x] Block breaks show items for all
- [x] Server validates all pickups

---

## Future Enhancements (Optional)

### Potential Features
1. **Magnetic Pull:** Items slowly move toward nearby players
2. **Item Age Display:** Show remaining time before despawn
3. **Rare Item Glow:** Special effects for rare/valuable items
4. **Stack Split:** Drop partial stacks (Shift+Q drops whole stack?)
5. **Item Collision:** Items bounce off each other
6. **Water Physics:** Items float in water
7. **Lava Destruction:** Items burn in lava
8. **Mob Drops:** Extend to enemy loot drops
9. **Player Death Drops:** Drop inventory on death
10. **Item Frames:** Display items on walls

### Performance Improvements
1. **Spatial Partitioning:** Chunk-based item storage
2. **LOD System:** Reduce visual quality for distant items
3. **Pooling:** Reuse Part instances
4. **Batch Updates:** Send multiple item updates in one event

---

## File Summary

### New Files Created
1. `/src/ReplicatedStorage/Shared/DroppedItem.lua` (230 lines)
2. `/src/ServerScriptService/Server/Services/DroppedItemService.lua` (360 lines)
3. `/src/StarterPlayerScripts/Client/Controllers/DroppedItemController.lua` (400 lines)

### Modified Files
1. `/src/ServerScriptService/Server/Runtime/Bootstrap.server.lua` (+12 lines)
2. `/src/ServerScriptService/Server/Services/VoxelWorldService.lua` (+10 lines)
3. `/src/StarterPlayerScripts/Client/GameClient.client.lua` (+5 lines)
4. `/src/StarterPlayerScripts/Client/UI/VoxelHotbar.lua` (+30 lines)
5. `/src/ReplicatedStorage/Shared/EventManager.lua` (+18 lines - added event handlers to CreateServerEventConfig)
6. `/src/ReplicatedStorage/Shared/Events/EventManifest.lua` (+6 lines - added event definitions)

### Total Lines Added
- **New Code:** ~990 lines
- **Modified Code:** ~81 lines (including EventManager and EventManifest)
- **Total:** ~1,071 lines

### Architecture Compliance
✅ Follows existing EventManager patterns
✅ Event definitions in EventManifest.lua
✅ Server event handlers in CreateServerEventConfig
✅ Client uses EventManager:RegisterEvent
✅ Client sends via EventManager:SendToServer
✅ Server fires via EventManager:FireEventToAll
✅ Service extends BaseService
✅ Proper dependency injection via Injector

---

## Implementation Status

✅ **All 10 planned features completed:**

1. ✅ DroppedItem data structure
2. ✅ DroppedItemService (server)
3. ✅ Item spawning on block break
4. ✅ DroppedItemController (client)
5. ✅ Pickup detection & validation
6. ✅ Player drop functionality (Q key)
7. ✅ Item physics (gravity, collision, merge)
8. ✅ Network events
9. ✅ Despawn timer with flash warning
10. ✅ Visual polish (particles, sounds, animations)

---

## How to Use

### For Players
1. **Break blocks** → Items pop out automatically
2. **Walk near items** → Auto-pickup within 3 studs
3. **Press Q** → Drop 1 item from selected hotbar slot
4. **Wait 5 minutes** → Items flash then despawn

### For Developers
```lua
-- Spawn a custom dropped item
local DroppedItemService = Injector:Resolve("DroppedItemService")
DroppedItemService:SpawnDroppedItem(
    itemId,      -- Block/item ID
    count,       -- Stack size
    position,    -- Vector3 world position
    velocity,    -- Vector3 initial velocity (optional)
    false        -- isBlockCoordinates (false for world coords)
)

-- Get all dropped items
local items = DroppedItemService:GetAllItems()
local itemCount = DroppedItemService:GetItemCount()
```

---

## Conclusion

The dropped item system is fully implemented and integrated with the existing voxel world, inventory, and network systems. It provides a polished, Minecraft-like experience with proper physics, visual effects, and server-authoritative validation.

**System is production-ready and requires no additional work.**

