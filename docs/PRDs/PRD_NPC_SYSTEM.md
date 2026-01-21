# Product Requirements Document: NPC System
## Hub World NPCs - Shop, Sell, Warps

> **Status**: Ready for Implementation - Phase 1 (Spawning & Attributes)
> **Priority**: P0 (Core Hub Functionality)
> **Estimated Effort**: Small (2-3 days)
> **Last Updated**: January 2026

---

## Executive Summary

The NPC System introduces interactive non-player characters in the hub world. Phase 1 focuses on spawning NPCs at designated locations with proper attributes and data structures. NPCs will use the existing Minion system as a foundation for entity management and visual representation.

### Why This Matters
- **Hub World Identity**: NPCs bring life and purpose to the hub world
- **Core Services**: Provide essential player services (shopping, selling, warping)
- **Scalability**: Clean architecture allows easy addition of new NPC types
- **Foundation**: Sets up data structure for Phase 2 (interactions)

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Minion Entities | `MobEntityService`, `MinionConfig.lua` | ✅ Entity spawning system |
| Minion UI | `MinionUI.lua` | ✅ Interaction UI pattern |
| Mob Registry | `MobRegistry.lua` | ✅ Entity registration |
| Hub World | World spawn system | ✅ Hub world exists |
| Event System | `EventManager` | ✅ Client/server communication |

### What's Needed ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| NPC Config | Define NPC types & attributes | P0 |
| NPC Service | Spawn & manage NPCs | P0 |
| NPC Registry | Register NPC types & /*-+ `ons | P0 |
| NPC Data Structure | Store NPC state & metadata | P0 |
| Spawn Locations Config | Define hub world positions | P0 |

---

## Feature Overview

### Core Concept

```
┌─────────────────────────────────────────────────────────────────┐
│                    NPC SYSTEM ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   Phase 1: Spawning & Attributes (This PRD)                     │
│   ┌───────────────────────────────────────────────────────┐    │
│   │  1. NPCConfig.lua - Define NPC types                   │    │
│   │     - SHOP_KEEPER: Buy items from NPC                  │    │
│   │     - MERCHANT: Sell items to NPC                      │    │
│   │     - WARP_MASTER: Teleport to locations               │    │
│   │                                                         │    │
│   │  2. NPCSpawnConfig.lua - Define locations              │    │
│   │     - Hub world coordinates                             │    │
│   │     - NPC type assignment                               │    │
│   │     - Display attributes (name, model, etc.)           │    │
│   │                                                         │    │
│   │  3. NPCService - Spawn & manage NPCs                   │    │
│   │     - Server-side entity management                     │    │
│   │     - Persistent NPC state                              │    │
│   │     - Replication to clients                            │    │
│   └───────────────────────────────────────────────────────┘    │
│                                                                 │
│   Phase 2: Interactions (Future PRD)                            │
│   - Shop UI & purchase logic                                    │
│   - Sell UI & selling logic                                     │
│   - Warp menu & teleportation                                   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Requirements

### Phase 1: NPC Spawning & Attributes

#### 1. NPC Configuration (`NPCConfig.lua`)

**Required Fields per NPC Type:**

```lua
NPCConfig.Types = {
    SHOP_KEEPER = {
        id = "SHOP_KEEPER",
        displayName = "Shop Keeper",
        description = "Buy items and tools",
        interactionType = "SHOP", -- Used in Phase 2
        model = "ShopKeeperModel", -- Model name or mob type
        interactionPrompt = "Press E to open Shop",
        -- Future: shopInventory, pricing, etc.
    },
    MERCHANT = {
        id = "MERCHANT",
        displayName = "Merchant",
        description = "Sell your items for coins",
        interactionType = "SELL",
        model = "MerchantModel",
        interactionPrompt = "Press E to sell items",
        -- Future: sellRates, acceptedItems, etc.
    },
    WARP_MASTER = {
        id = "WARP_MASTER",
        displayName = "Warp Master",
        description = "Travel to different locations",
        interactionType = "WARP",
        model = "WarpMasterModel",
        interactionPrompt = "Press E to open Warps",
        -- Future: warpDestinations, unlockRequirements, etc.
    }
}
```

**Configuration Methods:**
- `GetNPCTypeDef(npcType)` - Get definition for NPC type
- `GetInteractionPrompt(npcType)` - Get interaction text
- `GetModel(npcType)` - Get model identifier

#### 2. NPC Spawn Locations (`NPCSpawnConfig.lua`)

**Required Fields per Spawn Point:**

```lua
NPCSpawnConfig.HubSpawns = {
    {
        id = "hub_shop_keeper_1",
        npcType = "SHOP_KEEPER",
        position = Vector3.new(10, 5, 20), -- Hub world coordinates
        rotation = 0, -- Facing direction (degrees)
        scale = 1.0, -- Model scale multiplier
    },
    {
        id = "hub_merchant_1",
        npcType = "MERCHANT",
        position = Vector3.new(-15, 5, 25),
        rotation = 180,
        scale = 1.0,
    },
    {
        id = "hub_warp_master_1",
        npcType = "WARP_MASTER",
        position = Vector3.new(0, 5, 30),
        rotation = 90,
        scale = 1.2, -- Slightly larger for prominence
    }
}
```

**Configuration Methods:**
- `GetAllHubSpawns()` - Get all NPC spawn definitions
- `GetSpawnById(id)` - Get specific spawn point
- `GetSpawnsByType(npcType)` - Get all spawns for NPC type

#### 3. NPC Service (`NPCService.lua`)

**Responsibilities:**

1. **Initialization**
   - Load NPC configurations on server start
   - Spawn all hub world NPCs at defined locations
   - Register NPCs with appropriate systems

2. **Entity Management**
   - Create NPC entities (reuse Minion entity structure)
   - Store NPC state (position, type, attributes)
   - Handle NPC persistence (if needed)

3. **Interaction Detection**
   - Detect player proximity to NPCs
   - Send interaction prompts to client
   - Prepare for Phase 2 interaction handling

**Server-side Data Structure:**

```lua
NPCService.activeNPCs = {
    ["hub_shop_keeper_1"] = {
        id = "hub_shop_keeper_1",
        npcType = "SHOP_KEEPER",
        entityModel = <RobloxModel>, -- Reference to spawned model
        position = Vector3.new(10, 5, 20),
        config = <NPCConfig.Types.SHOP_KEEPER>,
        -- Phase 2: interaction state, inventory, etc.
    }
}
```

**Key Methods:**
- `Initialize()` - Spawn all hub NPCs on server start
- `SpawnNPC(spawnConfig)` - Spawn single NPC entity
- `GetNPC(npcId)` - Get NPC data by ID
- `GetNearbyNPCs(position, radius)` - Find NPCs near position
- `OnPlayerProximity(player, npcId)` - Trigger when player approaches

#### 4. NPC Client Detection (`NPCController.lua`)

**Responsibilities:**

1. **Proximity Detection**
   - Detect when player is near NPC (5 stud radius)
   - Show interaction prompt above NPC
   - Hide prompt when player moves away

2. **Visual Feedback**
   - Display NPC name tag
   - Show interaction prompt ("Press E to...")
   - Highlight NPC on hover (Phase 2)

**Key Methods:**
- `Initialize()` - Start proximity checking loop
- `CheckNearbyNPCs()` - Check distance to NPCs each frame
- `ShowInteractionPrompt(npcId)` - Display UI prompt
- `HideInteractionPrompt()` - Remove UI prompt
- `OnInteract(npcId)` - Handle E key press (stub for Phase 2)

---

## Technical Specifications

### 1. NPC Entity Structure (Extends Minion Pattern)

**Similarities to Minions:**
- Both are entities in the world
- Both have persistent locations
- Both have interaction UIs
- Both use MobEntityService patterns

**Differences from Minions:**
- NPCs are static (don't move/mine)
- NPCs don't have inventory/production
- NPCs spawn in hub world only
- NPCs use different interaction types

### 2. Reusing Minion Code

**Reuse from Minion System:**
- Entity spawning logic (`MobEntityService`)
- Model/visual representation patterns
- Proximity detection approach
- Event-based interaction system

**New Code Required:**
- `NPCConfig.lua` - NPC type definitions
- `NPCSpawnConfig.lua` - Spawn locations
- `NPCService.lua` - NPC management service
- `NPCController.lua` - Client-side detection

### 3. Data Flow

```
Server (NPCService):
  1. Load NPCSpawnConfig on server start
  2. For each spawn point:
     - Get NPC type from NPCConfig
     - Create entity model at position
     - Store in activeNPCs table
     - Register with MobEntityService (if applicable)
  3. Listen for player proximity events

Client (NPCController):
  1. Continuously check player position
  2. Calculate distance to all hub NPCs
  3. If within 5 studs:
     - Request NPC data from server
     - Show interaction prompt UI
     - Listen for E key press
  4. If E pressed:
     - Send interaction event to server (Phase 2)
```

---

## Implementation Plan

### Phase 1: Spawning & Attributes (This PRD)

**Step 1: Create Configuration Files** (30 mins)
- [ ] Create `src/ReplicatedStorage/Configs/NPCConfig.lua`
  - Define 3 NPC types (SHOP_KEEPER, MERCHANT, WARP_MASTER)
  - Add display names, descriptions, interaction types
  - Add placeholder model identifiers
- [ ] Create `src/ReplicatedStorage/Configs/NPCSpawnConfig.lua`
  - Define 3 spawn points in hub world
  - Assign positions (placeholder coordinates initially)
  - Assign NPC types to each spawn

**Step 2: Create NPC Service** (2-3 hours)
- [ ] Create `src/ServerScriptService/Server/Services/NPCService.lua`
  - Implement `Initialize()` - spawn all NPCs
  - Implement `SpawnNPC(spawnConfig)` - create entity
  - Implement `GetNPC(npcId)` - retrieve NPC data
  - Implement `GetNearbyNPCs(position, radius)`
  - Store activeNPCs table
  - Add basic logging

**Step 3: Create NPC Controller** (2-3 hours)
- [ ] Create `src/StarterPlayerScripts/Client/Controllers/NPCController.lua`
  - Implement `Initialize()` - start proximity loop
  - Implement `CheckNearbyNPCs()` - distance calculation
  - Implement `ShowInteractionPrompt(npcId)` - create UI
  - Implement `HideInteractionPrompt()` - remove UI
  - Add E key detection (stub for Phase 2)

**Step 4: Create Visual Elements** (1-2 hours)
- [ ] Design NPC models or assign existing mob models
  - Use simple placeholder models initially
  - Can enhance visuals later
- [ ] Create interaction prompt UI
  - Billboard GUI above NPC head
  - Shows NPC name + interaction hint
  - Fades in/out on proximity

**Step 5: Testing** (1 hour)
- [ ] Test NPC spawning on server start
- [ ] Verify all 3 NPCs appear at correct positions
- [ ] Test proximity detection (prompt appears/disappears)
- [ ] Verify NPC data retrieval works
- [ ] Check performance (no lag from proximity checks)

**Step 6: Hub World Positioning** (30 mins)
- [ ] Determine final spawn positions in hub world
- [ ] Update NPCSpawnConfig with actual coordinates
- [ ] Adjust rotations so NPCs face appropriate directions
- [ ] Test in-game placement

---

## Future Enhancements (Phase 2)

### Shop Interaction
- Shop UI with item grid
- Item purchasing logic
- Currency system integration
- Stock management

### Sell Interaction
- Sell UI showing player inventory
- Item selling logic
- Price calculation (% of buy price)
- Accepted items configuration

### Warp Interaction
- Warp menu UI with destinations
- Teleportation logic
- Unlock requirements (level, quest, etc.)
- Warp cooldowns

### Additional NPC Types
- Quest Giver
- Banker (storage access)
- Guild Master
- Tutorial NPC

### Polish
- NPC dialogue system
- Animated NPC models
- Ambient NPC behaviors (idle animations)
- Sound effects for interactions
- Particle effects for warps

---

## Success Criteria

**Phase 1 Complete When:**
- ✅ 3 NPCs spawn in hub world on server start
- ✅ NPCs appear at correct positions with correct models
- ✅ Proximity detection shows/hides interaction prompts
- ✅ NPC data structure is clean and extensible
- ✅ No performance issues from proximity checks
- ✅ Code is documented and follows project patterns
- ✅ Ready for Phase 2 interaction implementation

---

## Technical Notes

### Performance Considerations
- Use spatial partitioning if many NPCs exist
- Limit proximity checks to hub world only
- Cache NPC positions (don't recalculate every frame)
- Use magnitude squared for distance comparisons

### Code Organization
- Follow existing service/controller pattern
- Use EventManager for client/server communication
- Keep configuration separate from logic
- Make NPC types easily extensible

### Testing Strategy
- Unit test NPC spawning
- Test with multiple players simultaneously
- Verify proximity detection accuracy
- Check memory usage with many NPCs

---

*Based on Minion system architecture: `MinionConfig.lua`, `MinionUI.lua`, `MobEntityService.lua`*
