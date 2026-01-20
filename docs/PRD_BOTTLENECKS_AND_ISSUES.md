# Product Requirements Document
## Voxel World System: Loading, Rendering, Player Worlds & Hub Optimization

**Version:** 1.0
**Date:** January 2026
**Author:** Engineering Team
**Status:** Draft

---

## Table of Contents
1. [Executive Summary](#1-executive-summary)
2. [Background & Context](#2-background--context)
3. [Current Architecture Analysis](#3-current-architecture-analysis)
4. [Problem Statement](#4-problem-statement)
5. [Goals & Success Metrics](#5-goals--success-metrics)
6. [Detailed Technical Analysis](#6-detailed-technical-analysis)
7. [Proposed Solutions](#7-proposed-solutions)
8. [Implementation Plan](#8-implementation-plan)
9. [Risk Assessment](#9-risk-assessment)
10. [Testing Strategy](#10-testing-strategy)
11. [Rollout Plan](#11-rollout-plan)
12. [Appendix](#12-appendix)

---

## 1. Executive Summary

The voxel world system powers both the hub lobby and player-owned worlds. Analysis reveals significant bottlenecks in four key areas:

| Area | Primary Issue | Impact | Priority |
|------|---------------|--------|----------|
| **Loading** | Player worlds load 100+ textures (only ~10 needed) | 10-15s load times | P0 |
| **Rendering** | MeshWorker burst processing during transitions | Frame drops | P1 |
| **Player Worlds** | Deferred initialization until first player joins | 2-5s delay | P0 |
| **Hub** | No spawn chunk pre-streaming | Visual pop-in | P1 |

**Key Targets:**
- Reduce player world load time from ~10-15s to <4s
- Reduce time to first render from ~5-8s to <2s
- Eliminate frame drops during loading-to-gameplay transition
- Reduce failed world joins from stale entries from ~5% to <1%

---

## 2. Background & Context

### 2.1 System Overview

The game uses a Minecraft-style voxel engine with:
- **Hub World**: Pre-built schematic-based lobby (`LittleIsland1_20.lua` - 8,315 lines)
- **Player Worlds**: Procedurally generated skyblock islands via `SkyblockGenerator`
- **Cross-Place Teleportation**: Separate Roblox places for hub (139848475014328) and worlds (111115817294342)

### 2.2 Current User Journey

```
Hub Join Flow:
1. Player joins lobby place
2. Server loads 8,315-line schematic synchronously (blocking)
3. Client receives world state signal
4. LoadingScreen preloads textures for schematic palette (~40-60 textures)
5. Client waits for spawn chunk to be streamed
6. Loading screen fades, player spawns

Player World Join Flow:
1. Player clicks world in UI
2. LobbyWorldTeleportService checks MemoryStore for active instance
3. If not found, reserves new server (owner only)
4. TeleportAsync to worlds place with teleport data
5. Server initializes VoxelWorldService (waits for first player)
6. LoadingScreen preloads ALL textures (100+)
7. Server streams chunks to player
8. Loading screen fades when spawn chunk ready
```

### 2.3 Relevant Files

| Component | File Path | Lines |
|-----------|-----------|-------|
| LoadingScreen | `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua` | 1,336 |
| GameClient | `src/StarterPlayerScripts/Client/GameClient.client.lua` | 1,715 |
| VoxelWorldService | `src/ServerScriptService/Server/Services/VoxelWorldService.lua` | 3,134 |
| SkyblockGenerator | `src/ReplicatedStorage/Shared/VoxelWorld/Generation/SkyblockGenerator.lua` | 755 |
| Hub Schematic | `src/ServerStorage/LittleIsland1_20.lua` | 8,315 |
| WorldOwnershipService | `src/ServerScriptService/Server/Services/WorldOwnershipService.lua` | 127 |
| LobbyWorldTeleportService | `src/ServerScriptService/Server/Services/LobbyWorldTeleportService.lua` | 262 |
| Config | `src/ReplicatedStorage/Shared/VoxelWorld/Core/Config.lua` | 105 |

---

## 3. Current Architecture Analysis

### 3.1 Loading Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     LoadingScreen.lua                           │
├─────────────────────────────────────────────────────────────────┤
│  1. FontBinder.preload() ─────────────────► Blocks main thread  │
│  2. Determine world type (IsHubWorld attribute)                 │
│  3. If Hub: getBlockIdsFromSchematic() → palette textures only  │
│  4. If Player: Load ALL BlockRegistry textures ◄── BOTTLENECK   │
│  5. ContentProvider:PreloadAsync(batch) ─────► Synchronous      │
│  6. IconManager:PreloadRegisteredIcons()                        │
│  7. Background: meshes, sounds                                  │
│  8. Wait for WorldReady signal                                  │
│  9. Fade out                                                    │
└─────────────────────────────────────────────────────────────────┘
```

**Key Configuration Values:**
```lua
-- Config.lua
PERFORMANCE = {
    DEFAULT_RENDER_DISTANCE = 3,
    MAX_RENDER_DISTANCE = 8,
    MAX_CHUNKS_PER_FRAME = 2,
    MAX_MESH_UPDATES_PER_FRAME = 3,
    MESH_UPDATE_BUDGET_MS = 6,
    MAX_PARTS_PER_CHUNK = 600,
    MAX_PARTS_PER_CHUNK_HUB = 10000
}

NETWORK = {
    CHUNK_STREAM_RATE = 30,
    MAX_CHUNKS_PER_UPDATE = 6
}
```

### 3.2 Rendering Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   GameClient.client.lua                         │
├─────────────────────────────────────────────────────────────────┤
│  RenderStepped:                                                 │
│    └─► updateVoxelWorld()                                       │
│         ├─► startMeshWorker() (spawns background task)          │
│         ├─► frustum:UpdateFromCamera()                          │
│         └─► fog calculation (every frame) ◄── INEFFICIENT       │
│                                                                 │
│  MeshWorker (background task):                                  │
│    while meshWorkerRunning:                                     │
│      1. Build candidate list from meshUpdateQueue               │
│      2. Sort ALL candidates by distance ◄── BOTTLENECK          │
│      3. Process maxChunksPerCycle:                              │
│         - Loading: 32 chunks ◄── FRAME SPIKES                   │
│         - Gameplay: 2-6 chunks                                  │
│      4. Build mesh, parent to workspace                         │
│      5. task.wait(0.05) if no work                              │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Player World Ownership Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 Cross-Place Teleport Flow                       │
├─────────────────────────────────────────────────────────────────┤
│  Lobby Place:                                                   │
│    LobbyWorldTeleportService                                    │
│      ├─► MemoryStore:GetAsync(worldId)                          │
│      │     └─► If found: reuse existing server                  │
│      │     └─► If not: ReserveServer() (owner only)             │
│      └─► TeleportAsync with TeleportData                        │
│                                                                 │
│  Worlds Place:                                                  │
│    Bootstrap.server.lua                                         │
│      └─► Players.PlayerAdded:Connect() ◄── WAITS FOR PLAYER     │
│           └─► ProcessTeleportData()                             │
│                ├─► WorldOwnershipService:SetOwnerById()         │
│                └─► VoxelWorldService:InitializeWorld()          │
│                     └─► World created AFTER player arrives      │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Hub Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Hub World Loading                            │
├─────────────────────────────────────────────────────────────────┤
│  Bootstrap.server.lua (IS_LOBBY == true):                       │
│    1. require(ServerStorage.Schematics.LittleIsland1_20)        │
│       └─► 8,315 line module BLOCKS server startup ◄── SLOW      │
│    2. voxelWorldService:InitializeWorld("hub_world")            │
│       └─► SchematicWorldGenerator.new()                         │
│            └─► _loadSchematic() parses palette                  │
│    3. RunService.Heartbeat streaming loop (30Hz)                │
│       └─► StreamChunksToPlayers() per player                    │
│                                                                 │
│  Client Join:                                                   │
│    1. LoadingScreen starts                                      │
│    2. getBlockIdsFromSchematic() reads palette file             │
│    3. Loads ~40-60 textures (optimized)                         │
│    4. Waits for spawn chunk ◄── NO PRE-STREAMING                │
│    5. Player spawns, may see incomplete world                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Problem Statement

### 4.1 Loading Problems

| Issue | Current State | Root Cause | Impact |
|-------|---------------|------------|--------|
| **Texture over-loading (Player Worlds)** | Loads 100+ textures | No palette optimization for player worlds | +8-10s load time |
| **Synchronous preloading** | Blocks main thread | ContentProvider:PreloadAsync batching | UI stalls |
| **Sequential DataStore calls** | Serial world metadata loading | No parallel fetching | +1-2s delay |
| **Font pre-warming** | Happens before progress starts | Always runs first | Perceived slowness |

**Code Evidence (LoadingScreen.lua:671-702):**
```lua
-- Fallback: count all textures if no schematic or extraction failed
if totalTextures == 0 then
    local seenTextures = {}
    -- Loads EVERYTHING from BlockRegistry
    local registryAssets = TextureManager:GetAllBlockTextureAssetIds()
    for _, assetUrl in ipairs(registryAssets) do
        if assetUrl and not seenTextures[assetUrl] then
            seenTextures[assetUrl] = true
            totalTextures = totalTextures + 1
        end
    end
end
```

### 4.2 Rendering Problems

| Issue | Current State | Root Cause | Impact |
|-------|---------------|------------|--------|
| **MeshWorker burst** | 32 chunks/cycle during loading | Aggressive processing when LoadingScreen active | Frame drops on transition |
| **Full sort every cycle** | O(n log n) candidate sorting | No incremental updates | CPU spikes |
| **No frustum culling in worker** | Builds off-screen chunks | Worker doesn't check camera frustum | Wasted work |
| **Per-frame fog calc** | Recalculates fog every RenderStepped | No change detection | Minor CPU overhead |

**Code Evidence (GameClient.client.lua:234-236):**
```lua
local isLoadingActive = LoadingScreenRef and LoadingScreenRef.IsActive and LoadingScreenRef:IsActive()
local maxChunksPerCycle = isLoadingActive and 32 or (isHubWorld and 6 or 2)
-- 32 chunks processed during loading can spike when transitioning to gameplay
```

### 4.3 Player World Problems

| Issue | Current State | Root Cause | Impact |
|-------|---------------|------------|--------|
| **Deferred initialization** | World created on first player join | Bootstrap waits for PlayerAdded | 2-5s delay |
| **Stale MemoryStore entries** | 90s TTL | Servers may crash without cleanup | ~5% failed joins |
| **World recreation** | Destroys/recreates on seed update | UpdateWorldSeed() implementation | Unnecessary GC pressure |
| **No pre-warming** | Cold server generation | Reserved servers idle until teleport | Full gen time on join |

**Code Evidence (Bootstrap.server.lua pattern):**
```lua
-- Worlds place: World initialized when first player joins
Players.PlayerAdded:Connect(function(player)
    local teleportData = player:GetJoinData().TeleportData
    -- World initialization happens HERE, not before
    voxelWorldService:InitializeWorld(...)
end)
```

### 4.4 Hub Problems

| Issue | Current State | Root Cause | Impact |
|-------|---------------|------------|--------|
| **Synchronous schematic load** | 8,315-line require() blocks | Single monolithic module | Server startup delay |
| **No spawn chunk pre-streaming** | Chunks streamed after player added | Reactive streaming | Visual pop-in |
| **Hardcoded chunk bounds** | Manual configuration | Not derived from schematic | Maintenance burden |
| **Single spawn point** | All players at (0, 55, 0) | Fixed spawn in WorldTypes | Player crowding |

**Code Evidence (WorldTypes.lua:43-46):**
```lua
-- Explicit spawn position (block coordinates, center of island)
spawnX = 0,
spawnY = 55,  -- Approximate surface level + buffer
spawnZ = 0,
```

---

## 5. Goals & Success Metrics

### 5.1 Primary Goals

1. **Reduce player world load time by 70%** (from ~10-15s to <4s)
2. **Eliminate frame drops** during loading-to-gameplay transition
3. **Reduce time to first render by 60%** (from ~5-8s to <2s)
4. **Reduce failed world joins** from stale MemoryStore entries (from ~5% to <1%)

### 5.2 Success Metrics

| Metric | Current | Target | Measurement Method |
|--------|---------|--------|-------------------|
| Player world load time | 10-15s | <4s | Analytics event: LoadingComplete |
| Hub world load time | 8-12s | <5s | Analytics event: LoadingComplete |
| Time to first render | 5-8s | <2s | Analytics event: FirstChunkRendered |
| 95th percentile frame time during transition | >50ms | <20ms | FPS monitoring |
| Failed world joins (stale entries) | ~5% | <1% | Error event: WorldJoinFailed |
| Texture memory (player worlds) | ~200MB | <60MB | Memory profiler |

### 5.3 Non-Goals

- Complete rewrite of voxel engine
- New world generation algorithms
- UI/UX changes to loading screen visuals
- Cross-region server improvements

---

## 6. Detailed Technical Analysis

### 6.1 SkyblockGenerator Block Palette

Analysis of `SkyblockGenerator.lua` reveals the actual blocks used in player worlds:

**Terrain Blocks (always present):**
| Block Type | Usage |
|------------|-------|
| `GRASS` | Island surface layer |
| `DIRT` | Subsurface mantle |
| `STONE` | Island body/core |
| `COBBLESTONE` | Cliff strata variation |
| `STONE_BRICKS` | Cliff strata, portal frames |

**Decoration Blocks (conditional):**
| Block Type | Usage |
|------------|-------|
| `WOOD` / `OAK_LOG` | Tree trunks |
| `OAK_LEAVES` | Tree canopy |
| `SPRUCE_LOG/LEAVES` | Variant trees |
| `JUNGLE_LOG/LEAVES` | Variant trees |
| `DARK_OAK_LOG/LEAVES` | Variant trees |
| `BIRCH_LOG/LEAVES` | Variant trees |
| `ACACIA_LOG/LEAVES` | Variant trees |
| `CHEST` | Starter chest |
| `GLASS` | Portal inner blocks |

**Total: 15-20 block types** (vs 100+ in BlockRegistry)

### 6.2 Hub Schematic Analysis

`LittleIsland1_20.lua` structure:
```lua
return {
    size = { width = 219, height = 130, length = 197 },
    palette = { ... },  -- ~80-100 unique block entries
    blocks = { ... }    -- Massive 3D block data array
}
```

**Chunk Coverage:**
- X: -8 to 7 chunks (16 chunks)
- Z: -7 to 6 chunks (14 chunks)
- Total: ~224 chunks (not all populated)
- Active chunks: ~120-150 with actual block data

### 6.3 Network Bandwidth Analysis

**Current chunk streaming:**
```lua
-- Config.lua
MAX_CHUNKS_PER_UPDATE = 6  -- Per player per tick
CHUNK_STREAM_RATE = 30     -- Hz
```

- Theoretical max: 6 chunks × 30 Hz = 180 chunks/second per player
- Actual: Limited by compression time and rate limiting
- Typical: 30-60 chunks/second during initial load

**Chunk payload size:**
- Uncompressed: ~16KB per chunk (16×256×16 blocks)
- Compressed (RLE + palette): ~2-4KB typical
- Hub chunks (dense): ~8-12KB

### 6.4 Memory Analysis

**Current texture loading (player worlds):**
- Full BlockRegistry: ~100-120 unique textures
- Each texture: ~1-2MB (uncompressed in GPU memory)
- Total: ~150-200MB texture memory

**Optimized loading:**
- Player palette: ~20 textures
- Total: ~30-40MB texture memory
- **Savings: 75-80%**

---

## 7. Proposed Solutions

### 7.1 Solution S1: Player World Palette Optimization (P0)

**Objective:** Load only textures for blocks used in SkyblockGenerator

**Implementation:**

1. Create `PlayerWorldPalette.lua`:
```lua
-- src/ReplicatedStorage/Configs/Schematics/PlayerWorldPalette.lua
return {
    -- Terrain
    "grass_block", "dirt", "stone", "cobblestone", "stone_bricks",
    -- Trees (all variants for player-placed)
    "oak_log", "oak_leaves", "spruce_log", "spruce_leaves",
    "jungle_log", "jungle_leaves", "dark_oak_log", "dark_oak_leaves",
    "birch_log", "birch_leaves", "acacia_log", "acacia_leaves",
    -- Decorations
    "chest", "glass",
    -- Player-placeable essentials
    "crafting_table", "furnace", "torch"
}
```

2. Update `LoadingScreen.lua`:
```lua
-- In LoadAllAssets()
local isHubWorld = Workspace:GetAttribute("IsHubWorld") == true

if isHubWorld then
    -- Existing schematic palette logic
    blockIds = getBlockIdsFromSchematic(hubWorldType.generatorOptions.schematicPath)
else
    -- NEW: Load player world palette
    local PlayerWorldPalette = require(ReplicatedStorage.Configs.Schematics.PlayerWorldPalette)
    blockIds = getBlockIdsFromPalette(PlayerWorldPalette)
end
```

**Effort:** Low (1-2 days)
**Risk:** Low
**Impact:** High (60-80% texture load reduction)

---

### 7.2 Solution S2: World Pre-Initialization (P0)

**Objective:** Initialize world before first player arrives

**Implementation:**

1. Modify `Bootstrap.server.lua` for worlds place:
```lua
-- Initialize with placeholder immediately on server start
local PLACEHOLDER_SEED = 0
voxelWorldService:InitializeWorld(PLACEHOLDER_SEED, 6, "player_world")

-- When player arrives, update with actual data
Players.PlayerAdded:Connect(function(player)
    local teleportData = player:GetJoinData().TeleportData
    if teleportData and teleportData.worldId then
        -- Hot-swap world data without full recreation
        voxelWorldService:LoadWorldData(teleportData.worldId, teleportData.ownerUserId)
    end
end)
```

2. Add `LoadWorldData()` to VoxelWorldService:
```lua
function VoxelWorldService:LoadWorldData(worldId, ownerId)
    -- Load from DataStore
    local worldData = self:_fetchWorldFromDataStore(worldId)

    -- Apply to existing world without destroying
    if worldData and worldData.chunks then
        self.worldManager:ApplyChunkData(worldData.chunks)
    end

    -- Update seed if different
    if worldData and worldData.seed ~= self.world.seed then
        self.world:UpdateSeed(worldData.seed)
    end
end
```

**Effort:** Medium (3-5 days)
**Risk:** Medium (requires careful state management)
**Impact:** High (eliminates 2-5s initialization delay)

---

### 7.3 Solution S3: Spawn Chunk Pre-Streaming (P1)

**Objective:** Stream spawn chunks to client before removing loading screen

**Implementation:**

1. Add spawn chunk priority in server:
```lua
function VoxelWorldService:PreStreamSpawnChunks(player)
    local spawnPos = self:GetSpawnPosition()
    local spawnChunkX = math.floor(spawnPos.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
    local spawnChunkZ = math.floor(spawnPos.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))

    -- Stream 3x3 around spawn immediately
    for dx = -1, 1 do
        for dz = -1, 1 do
            self:StreamChunkToPlayer(player, spawnChunkX + dx, spawnChunkZ + dz)
        end
    end

    -- Signal client spawn chunks ready
    EventManager:FireEvent("SpawnChunksReady", player)
end
```

2. Update client loading flow:
```lua
-- LoadingScreen.lua
local spawnChunksReceived = false

EventManager:RegisterEvent("SpawnChunksReady", function()
    spawnChunksReceived = true
    checkReadyToFade()
end)

local function checkReadyToFade()
    if assetsLoaded and spawnChunksReceived then
        self:FadeOut()
    end
end
```

**Effort:** Medium (2-3 days)
**Risk:** Low
**Impact:** Medium (eliminates visual pop-in)

---

### 7.4 Solution S4: MeshWorker Frame Budget (P1)

**Objective:** Prevent frame drops during loading-to-gameplay transition

**Implementation:**

```lua
-- GameClient.client.lua
local MESH_FRAME_BUDGET_MS = 8  -- Target 60fps (16ms frame, leave headroom)
local meshStartTime = nil

local function shouldYieldMeshWork()
    if not meshStartTime then return false end
    return (os.clock() - meshStartTime) * 1000 > MESH_FRAME_BUDGET_MS
end

-- In mesh worker loop:
meshStartTime = os.clock()
local chunksBuiltThisCycle = 0

for _, item in ipairs(candidates) do
    if shouldYieldMeshWork() then
        break  -- Yield to next frame
    end

    -- Build mesh...
    chunksBuiltThisCycle += 1
end

-- Reset for next cycle
meshStartTime = nil
```

**Effort:** Low (1 day)
**Risk:** Low
**Impact:** Medium (smooth transition)

---

### 7.5 Solution S5: MemoryStore TTL & Heartbeat (P2)

**Objective:** Reduce stale world entries causing failed joins

**Implementation:**

1. Reduce TTL and add active heartbeat:
```lua
-- LobbyWorldTeleportService.lua
local REGISTRY_TTL = 30  -- Reduced from 90s

-- Worlds place: Bootstrap.server.lua
local function startWorldHeartbeat()
    task.spawn(function()
        while true do
            task.wait(15)  -- Heartbeat every 15s
            if worldOwnershipService:GetWorldId() then
                local entry = {
                    worldId = worldOwnershipService:GetWorldId(),
                    playerCount = #Players:GetPlayers(),
                    updatedAt = os.time()
                }
                pcall(function()
                    activeWorldsMap:SetAsync(entry.worldId, entry, REGISTRY_TTL)
                end)
            end
        end
    end)
end
```

2. Add cleanup on server shutdown:
```lua
game:BindToClose(function()
    local worldId = worldOwnershipService:GetWorldId()
    if worldId then
        pcall(function()
            activeWorldsMap:RemoveAsync(worldId)
        end)
    end
end)
```

**Effort:** Low (1 day)
**Risk:** Low
**Impact:** Medium (reduces failed joins)

---

### 7.6 Solution S6: Schematic Chunking (P2)

**Objective:** Load hub schematic incrementally instead of synchronously

**Implementation:**

1. Split schematic into chunk-based modules:
```
ServerStorage/
  Schematics/
    LittleIsland1_20/
      _metadata.lua      -- Size, palette, spawn
      chunk_n7_n7.lua    -- Chunk at (-7, -7)
      chunk_n7_n6.lua
      ...
```

2. Update SchematicWorldGenerator:
```lua
function SchematicWorldGenerator:_loadChunkData(chunkX, chunkZ)
    local chunkModule = self:_getChunkModule(chunkX, chunkZ)
    if not chunkModule then return nil end

    -- Lazy load chunk data
    if not self._loadedChunks[chunkModule] then
        self._loadedChunks[chunkModule] = require(chunkModule)
    end

    return self._loadedChunks[chunkModule]
end
```

**Effort:** High (1-2 weeks)
**Risk:** Medium (requires schematic conversion tool)
**Impact:** Medium (faster server startup)

---

### 7.7 Solution S7: Fog Calculation Caching (P3)

**Objective:** Reduce per-frame CPU overhead

**Implementation:**

```lua
-- GameClient.client.lua
local lastFogCameraPos = nil
local lastFogValues = nil
local FOG_UPDATE_THRESHOLD = 10  -- Studs

local function updateFogIfNeeded(camera)
    local camPos = camera.CFrame.Position

    if lastFogCameraPos and (camPos - lastFogCameraPos).Magnitude < FOG_UPDATE_THRESHOLD then
        return  -- Skip update, use cached values
    end

    -- Calculate new fog values
    local horizonStuds = clientVisualRadius * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
    local fogStart = math.max(0, horizonStuds * 0.58)
    local fogEnd = math.max(fogStart + 15, horizonStuds * 0.92)

    -- Apply if changed significantly
    if not lastFogValues or math.abs(lastFogValues.fogEnd - fogEnd) > 4 then
        Lighting.FogStart = fogStart
        Lighting.FogEnd = fogEnd
        lastFogValues = { fogStart = fogStart, fogEnd = fogEnd }
    end

    lastFogCameraPos = camPos
end
```

**Effort:** Low (0.5 days)
**Risk:** Low
**Impact:** Low (minor CPU savings)

---

## 8. Implementation Plan

### 8.1 Phase 1: Quick Wins (Week 1)

| Task | Solution | Owner | Est. Hours |
|------|----------|-------|------------|
| Create PlayerWorldPalette.lua | S1 | - | 4 |
| Update LoadingScreen for player world palette | S1 | - | 8 |
| Add fog calculation caching | S7 | - | 4 |
| Add MeshWorker frame budget | S4 | - | 8 |

**Deliverable:** Player world load time reduced by 60%+

### 8.2 Phase 2: Core Optimizations (Week 2-3)

| Task | Solution | Owner | Est. Hours |
|------|----------|-------|------------|
| Implement world pre-initialization | S2 | - | 24 |
| Add spawn chunk pre-streaming | S3 | - | 16 |
| Implement MemoryStore heartbeat | S5 | - | 8 |
| Testing and bug fixes | - | - | 16 |

**Deliverable:** Initialization delay eliminated, visual pop-in fixed

### 8.3 Phase 3: Advanced Optimizations (Week 4-6)

| Task | Solution | Owner | Est. Hours |
|------|----------|-------|------------|
| Create schematic chunking tool | S6 | - | 24 |
| Convert LittleIsland1_20 to chunks | S6 | - | 8 |
| Update SchematicWorldGenerator | S6 | - | 16 |
| Performance testing and tuning | - | - | 16 |

**Deliverable:** Hub server startup optimized

### 8.4 Gantt Chart

```
Week 1    Week 2    Week 3    Week 4    Week 5    Week 6
|---------|---------|---------|---------|---------|---------|
[===S1====]
    [==S4==]
    [==S7==]
          [========S2=========]
                [=====S3=====]
                    [==S5==]
                              [===========S6============]
                                                [Testing]
```

---

## 9. Risk Assessment

### 9.1 Risk Matrix

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| PlayerWorldPalette missing blocks players can place | Medium | High | Include all crafting-obtainable blocks; add fallback lazy loading |
| World pre-init state conflicts with teleport data | Medium | Medium | Careful state machine design; extensive testing |
| MemoryStore TTL too short causes legitimate failures | Low | Medium | Monitor failure rates; adjust TTL dynamically |
| Schematic chunking breaks existing hub | Low | High | Thorough testing in staging; rollback plan |
| MeshWorker budget too aggressive causes slow loading | Medium | Low | Make budget configurable; tune based on device |

### 9.2 Rollback Plan

1. **Feature flags** for each solution (enabled via ReplicatedStorage attribute)
2. **A/B testing** capability for gradual rollout
3. **Monitoring dashboards** for key metrics
4. **Quick revert** via server configuration update

---

## 10. Testing Strategy

### 10.1 Unit Tests

| Component | Test Cases |
|-----------|------------|
| PlayerWorldPalette | All SkyblockGenerator blocks included; no missing textures |
| MeshWorker budget | Frame time stays under budget; chunks still process |
| Fog caching | Cache invalidates on significant movement |

### 10.2 Integration Tests

| Scenario | Expected Result |
|----------|-----------------|
| Player world load (new) | <4s load time, all blocks render correctly |
| Player world load (existing) | DataStore data applied correctly |
| Hub world load | <5s load time, spawn chunks visible immediately |
| Failed teleport (stale entry) | Graceful retry with fresh server |

### 10.3 Performance Tests

| Test | Target | Method |
|------|--------|--------|
| Load time (P50) | <3s | Automated test runner, 100 runs |
| Load time (P95) | <5s | Automated test runner, 100 runs |
| Frame time during transition | <20ms (P95) | FPS monitoring tool |
| Texture memory | <60MB | Memory profiler |

### 10.4 Device Matrix

| Device Category | Representative | Priority |
|-----------------|----------------|----------|
| Low-end mobile | iPhone 8 / Android mid-range | High |
| High-end mobile | iPhone 14 / Android flagship | Medium |
| Low-end PC | Integrated graphics | High |
| High-end PC | Dedicated GPU | Low |

---

## 11. Rollout Plan

### 11.1 Staging Environment

1. Deploy all changes to staging place
2. Run full test suite
3. Manual QA pass on all device categories
4. Performance benchmarking

### 11.2 Gradual Rollout

| Phase | Audience | Duration | Success Criteria |
|-------|----------|----------|------------------|
| Alpha | Internal team | 3 days | No critical bugs |
| Beta | 5% of players | 7 days | Metrics improving, error rate <1% |
| General | 25% → 50% → 100% | 14 days | All targets met |

### 11.3 Monitoring

**Dashboards:**
- Load time distribution (histogram)
- Frame time during transitions
- Failed world join rate
- Texture memory usage

**Alerts:**
- Load time P95 > 8s
- Failed join rate > 3%
- Client error rate spike > 2x baseline

---

## 12. Appendix

### 12.1 Block Type Reference

```lua
-- From Constants.lua BlockType enum
AIR = 0
STONE = 1
GRASS = 2
DIRT = 3
COBBLESTONE = 4
WOOD = 5  -- OAK_LOG
OAK_LEAVES = 12
CHEST = 54
GLASS = 20
STONE_BRICKS = 98
-- ... (see full BlockRegistry for complete list)
```

### 12.2 Configuration Reference

```lua
-- Current Config.lua values
PERFORMANCE = {
    DEFAULT_RENDER_DISTANCE = 3,
    MAX_RENDER_DISTANCE = 8,
    MAX_WORLD_CHUNKS = 256,
    MAX_CHUNKS_PER_PLAYER = 100,
    LOD_DISTANCE = 128,
    MAX_CHUNKS_PER_FRAME = 2,
    MAX_MESH_UPDATES_PER_FRAME = 3,
    MESH_UPDATE_BUDGET_MS = 6,
    GENERATION_BUDGET_MS = 3,
    MAX_PARTS_PER_CHUNK = 600,
    MAX_PARTS_PER_CHUNK_HUB = 10000
}

NETWORK = {
    CHUNK_STREAM_RATE = 30,
    POSITION_UPDATE_RATE = 10,
    MAX_BLOCK_UPDATES_PER_PACKET = 100,
    MAX_CHUNK_REQUESTS_PER_FRAME = 6,
    BLOCK_UPDATE_DISTANCE = 64,
    MIN_VIEW_DISTANCE = 10,
    MAX_VIEW_DISTANCE = 12,
    MAX_CHUNKS_PER_UPDATE = 6,
    UNLOAD_EXTRA_RADIUS = 1,
    ENTITY_TRACKING_RADIUS = 256
}
```

### 12.3 Related Documentation

- `docs/OPTIMIZATION_PLAN_PLAYER_WORLDS.md` - Previous optimization planning
- `docs/ARCHITECTURE.md` - System architecture overview
- `docs/VOXEL_ENGINE.md` - Voxel engine technical details

### 12.4 Glossary

| Term | Definition |
|------|------------|
| **Chunk** | 16×256×16 block region, unit of streaming |
| **Palette** | Set of block types used in a schematic/world |
| **RLE** | Run-Length Encoding, compression for chunk data |
| **MeshWorker** | Background task that converts chunk data to renderable meshes |
| **Schematic** | Pre-built world data imported from external tools |
| **Skyblock** | Player world type with floating island generation |

---

*Document End*
