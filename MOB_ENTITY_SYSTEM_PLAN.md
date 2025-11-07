# Mob Entity Service Plan

Straight-forward roadmap for replacing the deprecated mob system with a new chunk-aware, persistent mob service. Focused on sheep (passive) and zombies (hostile) for a first release.

---

## 1. Goals & Success Criteria
- Track mobs per player-owned world with save/load support
- Stream mobs in/out with chunks so we never keep unnecessary entities alive
- Deliver basic behaviors: sheep wander + flee, zombies chase + attack
- Provide clean server replication so clients see the mobs moving and animating
- Keep architecture simple enough to add more mob types later

---

## 2. Minimal Architecture

**Server (`MobEntityService.lua`)**
- Extends `BaseService`
- Holds registry of active mobs keyed by `worldId` → chunk key → mob list
- Listens to chunk load/unload to spawn/despawn
- Owns AI updates (simple timers, no over-engineered framework)
- Saves mobs into world data (new `mobs` table) and loads them back

**Client (`MobReplicationController.lua`)**
- Subscribes to server events (`MobSpawned`, `MobUpdated`, `MobDespawned`)
- Manages Roblox models per entity, pulling animation info from config
- Performs lightweight tweening/interpolation to keep motion smooth

**Shared Config (`MobRegistry.lua`)**
- Defines basic stats per mob: health, speed, drops, spawn rules
- Keeps spawn validation logic readable

---

## 3. Implementation Steps

### Step 1 – Scaffolding
1. Add `MobRegistry.lua` with entries for `SHEEP` and `ZOMBIE`
2. Create empty service/controller modules with lifecycle hooks wired into injector/bootstrap

### Step 2 – Core Spawn/Despawn
1. Implement `SpawnMob`/`DespawnMob` on the service (server only)
2. Fire replication events and have the client spawn simple placeholder models
3. Track mobs inside `worldId` + `chunkKey` buckets

### Step 3 – Chunk Hooks & Persistence
1. Hook into `VoxelWorldService` or `ChunkManager` load/unload callbacks
2. On load: spawn mobs from saved data, then try natural spawns if under cap
3. On unload or world save: serialize mobs in that chunk back into world data

### Step 4 – Behavior Loops
1. Passive behavior: random idle timer, random wander target, flee if player < X studs
2. Hostile behavior: acquire nearest player in range, move toward them, apply melee damage if close
3. Run ticks at ~10 Hz; clamp per-frame work to avoid spikes (e.g., rotate through entities)

### Step 5 – Movement & Collision
1. Keep movement simple: apply velocity, raycast down for ground, step up 1-block heights
2. Clamp fall speed and stop on ground hit; mark `onGround` flag
3. Handle chunk transfer by recalculating chunk key when position crosses boundary

### Step 6 – Networking Clean-Up
1. Batch position/state updates (`MobBatchUpdate`) instead of per-mob spam
2. Clients interpolate between updates; send state flags so sheep/zombies map to animation sets

### Step 7 – Drops & Combat Hooks
1. Add `DamageMob` endpoint; integrate with existing combat damage numbers
2. On death: remove entity, spawn items via `DroppedItemService`, update stats

### Step 8 – Tune & Test
1. Validate save/load cycles (leave server, rejoin → mobs persist)
2. Stress test with 100 mobs to ensure tick budget is stable
3. Adjust spawn caps/light checks until behavior feels Minecraft-like

---

## 4. Data & Storage Changes
- Extend world save schema with `mobs = { {entityId, mobType, position, health, persistenceData} }`
- Use existing autosave pipeline so mobs ride along without new datastore writes
- Migrate old mob data (if any) by dropping it; new system bootstraps fresh mobs per world

---

## 5. Testing Checklist
- Spawn/Despawn: manual tests + automated unit tests for registry bookkeeping
- Persistence: integration test that modifies mobs, saves, reloads
- AI: sandbox script verifying idle → wander and chase → attack transitions
- Performance: profile update loop under max mob cap, ensure <5 ms/tick
- Networking: simulate high ping to confirm interpolation stays stable

---

## 6. Timeline (1 Dev)
- Week 1: Steps 1–3 (scaffolding, spawn/despawn, persistence)
- Week 2: Steps 4–6 (behaviors, movement, networking polish)
- Week 3: Steps 7–8 plus playtesting & balance

This lean plan retires the old mob system and delivers a clear foundation for future mob types without drowning in detail.

---

## 7. Model Construction Specs (Minecraft Scale)

### 7.1 Scale & Orientation
- Keep `BLOCK_SIZE` = 3 studs (from existing voxel constants)
- 1 Minecraft pixel = `3 / 16 = 0.1875` studs
- Forward = +Z, Up = +Y, origin at the center of the mob’s footprint on the ground
- Use `Model.PrimaryPart` set to a custom `Root` cube (e.g. 0.5 × 0.5 × 0.5 studs) at `(0, 0.25, 0)` for easy welding to animations

### 7.2 Zombie (Biped)
| Part | Size (Studs) | Pixel Source (W×H×D) | Center Position (Studs) | Notes |
|------|---------------|----------------------|--------------------------|-------|
| Head | `1.5 × 1.5 × 1.5` | `8 × 8 × 8` | `(0, 5.25, 0)` | Bottom sits flush on torso top |
| Torso | `1.5 × 2.25 × 0.75` | `8 × 12 × 4` | `(0, 3.375, 0)` | Align top at Y = 4.5 |
| Left Arm | `0.75 × 2.25 × 0.75` | `4 × 12 × 4` | `(-1.125, 3.375, 0)` | Pivot at shoulder center |
| Right Arm | `0.75 × 2.25 × 0.75` | `4 × 12 × 4` | `(1.125, 3.375, 0)` | Mirror of left arm |
| Left Leg | `0.75 × 2.25 × 0.75` | `4 × 12 × 4` | `(-0.375, 1.125, 0)` | Feet touch ground at Y = 0 |
| Right Leg | `0.75 × 2.25 × 0.75` | `4 × 12 × 4` | `(0.375, 1.125, 0)` | Mirror of left leg |

Build Steps:
1. Create `Root` cube (0.5³ studs) at origin. All parts welded to it via `Motor6D` (for limbs) or `Weld` (torso/head).
2. Construct torso first; ensure bottom aligns with leg top (Y = 2.25).
3. Position legs so they share ground plane (Y = 0). Align pivots to inner top corners for natural swing.
4. Attach arms with shoulders aligned to torso upper edge (Y ≈ 4.5) and offset ±1.125 studs on X.
5. Place head so bottom plane meets torso top; set `Motor6D` pivot at head center for rotation.

### 7.3 Sheep (Quadruped)
| Part | Size (Studs) | Pixel Source (W×H×D) | Center Position (Studs) | Notes |
|------|---------------|----------------------|--------------------------|-------|
| Head (skin) | `1.125 × 1.125 × 1.5` | `6 × 6 × 8` | `(0, 3.375, -1.3125)` | Snout extends forward |
| Head (wool overlay) | `1.5 × 1.5 × 1.875` | `8 × 8 × 10` | `(0, 3.46875, -1.359375)` | Optional second part for fluff |
| Body (skin) | `1.5 × 1.875 × 1.125` | `8 × 10 × 6` | `(0, 2.625, 0.1875)` | Rotate 90° around X so length runs along Z |
| Body (wool overlay) | `1.875 × 2.25 × 1.5` | `10 × 12 × 8` | `(0, 2.71875, 0.1875)` | Optional thicker layer |
| Front Legs (x2) | `0.375 × 1.125 × 0.375` | `2 × 6 × 2` | `(±0.5625, 0.5625, -0.75)` | Feet on Y = 0 |
| Hind Legs (x2) | `0.375 × 1.125 × 0.375` | `2 × 6 × 2` | `(±0.5625, 0.5625, 1.125)` | Mirrors of front legs |

Build Steps:
1. Place legs first forming a 0.9 × 1.8 studs rectangle footprint (matching 0.9 × 1.8 m in Minecraft).
2. Set leg pivots at top inner corners for proper swing.
3. Position body so underside clears ground by 0.375 studs (sheep height ≈ 3.9 studs overall).
4. Add wool overlay parts (slightly larger) for layered look; weld to body.
5. Offset head forward by 1.3125 studs; ensure head pivot sits where neck meets body for grazing animation.
6. Optional: add small `Tail` part (0.375 × 0.375 × 0.1875) centered at `(0, 2.1, 1.5)`.

Tips:
- Use `Snap to Grid` at 0.0625 studs to make 0.1875 increments easy.
- Keep materials Plastic + SurfaceType Smooth; apply textures later via decals.

---

## 8. Procedural Leg Animation Math

### 8.1 Shared Parameters
- `t` = `os.clock()` (seconds)
- `speed` = horizontal velocity magnitude in studs/sec
- `stepFrequency = speed / strideLength` with `strideLength = 3.0` studs for biped, `2.4` for quadruped
- `cycle = t * stepFrequency * 2π`
- `amplitude` (degrees): `25` for zombie arms/legs, `30` for sheep legs; scale down when `speed < 0.5`

### 8.2 Zombie (Opposite Phase Limbs)
```lua
local function animateZombieLimbs(model, dt, velocity)
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if speed < 0.1 then
        return -- keep default idle pose
    end

    local strideLength = 3
    local frequency = speed / strideLength
    local cycle = os.clock() * frequency * math.pi * 2
    local amplitude = math.clamp(speed / 6, 0, 1) * 25

    local sinA = math.sin(cycle)
    local sinB = math.sin(cycle + math.pi)

    model.LeftLeg.Motor6D.Transform = CFrame.Angles(math.rad(sinA * amplitude), 0, 0)
    model.RightLeg.Motor6D.Transform = CFrame.Angles(math.rad(sinB * amplitude), 0, 0)
    model.LeftArm.Motor6D.Transform = CFrame.Angles(math.rad(sinB * amplitude * 0.8), 0, 0)
    model.RightArm.Motor6D.Transform = CFrame.Angles(math.rad(sinA * amplitude * 0.8), 0, 0)
end
```

### 8.3 Sheep (Quadruped Gait)
```lua
local function animateSheepLegs(model, dt, velocity)
    local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
    if speed < 0.05 then
        return
    end

    local strideLength = 2.4
    local frequency = speed / strideLength
    local cycle = os.clock() * frequency * math.pi * 2
    local amplitude = math.clamp(speed / 5, 0, 1) * 30

    local frontLeftPhase = math.sin(cycle)
    local frontRightPhase = math.sin(cycle + math.pi)
    local backLeftPhase = math.sin(cycle + math.pi)
    local backRightPhase = math.sin(cycle)

    model.FrontLeftLeg.Motor6D.Transform = CFrame.Angles(math.rad(frontLeftPhase * amplitude), 0, 0)
    model.FrontRightLeg.Motor6D.Transform = CFrame.Angles(math.rad(frontRightPhase * amplitude), 0, 0)
    model.BackLeftLeg.Motor6D.Transform = CFrame.Angles(math.rad(backLeftPhase * amplitude), 0, 0)
    model.BackRightLeg.Motor6D.Transform = CFrame.Angles(math.rad(backRightPhase * amplitude), 0, 0)

    -- Optional gentle head bob proportional to stride
    local headBob = math.sin(cycle * 2) * math.rad(amplitude * 0.1)
    model.Head.Motor6D.Transform = CFrame.Angles(headBob, 0, 0)
end
```

Guidelines:
- Reset `Motor6D.Transform` to `CFrame.new()` when mob stops to avoid pose drift.
- Blend procedural swing with Roblox animation keyframes by lerping transforms before applying them.

