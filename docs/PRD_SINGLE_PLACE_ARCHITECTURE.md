
# PRD v2: Single-Place Router Architecture

## Overview

Migrate from a multi-place architecture to a **single-place, multi-server model** using a **Router → Reserved Server** pattern.
All navigation is handled via the existing **Worlds Panel UI**, preserving UX while significantly improving load speed, reliability, and maintainability.

---

## Goals

1. **Fast Entry**
   - Router → World in **<3s**
   - World ↔ Nexus in **<2s** (asset-cached)

2. **Single Codebase**
   - One PlaceId
   - Shared assets, services, and UI

3. **Persistent Social Hub**
   - Nexus remains a shared, social space
   - Multiple hub instances for scale

4. **Operational Safety**
   - Explicit server roles
   - Teleport failure recovery
   - Scalable hub pooling

---

## Non-Goals

- No cross-place teleporting
- No public gameplay servers (all gameplay occurs in reserved servers)
- No new navigation UI (reuse Worlds Panel)

---

## Architecture

```

SINGLE PLACE
├── ROUTER (public)
│   └── Identity → Resolve destination → Teleport
│
├── PLAYER WORLD (reserved)
│   └── Full gameplay (owner-specific)
│
└── NEXUS / HUB (reserved, shared)
└── Social, NPCs, shops

````

---

## Server Role Detection (Explicit)

Server intent is **explicitly defined via TeleportData**, never inferred.

```lua
-- TeleportData.serverType = "ROUTER" | "WORLD" | "HUB"

if TeleportData and TeleportData.serverType then
    return TeleportData.serverType
end

-- Fallback: true entry point only
if game.PrivateServerId == "" then
    return "ROUTER"
end

error("Unknown server type")
````

---

## TeleportData Contract

```lua
TeleportData = {
    serverType = "WORLD" | "HUB",
    worldId = "string",         -- required for WORLD
    ownerUserId = number,       -- required for WORLD
    isHub = boolean             -- convenience flag
}
```

---

## Player Flow (via Worlds Panel)

```
Click Play
   ↓
ROUTER (public, minimal)
   ↓
PLAYER WORLD (reserved)
   │
   ├─ [E] Worlds Panel
   │     ├─ My Realms → Play
   │     ├─ Nexus → Return to Nexus
   │     └─ Friends' Realms
   │
   ↓
NEXUS (reserved, shared)
   │
   └─ Worlds Panel → My Realms → Play
```

---

## Server Responsibilities

### Router Server (Public)

**Purpose:** Resolve destination and teleport immediately.

**Requirements**

* Detect router server
* Load player profile (read-only)
* Get or create player’s main world access code
* Reserve server if needed
* Teleport immediately (no UI, no world load)
* Retry teleport up to 2 times
* Fallback to Nexus on failure

**Constraints**

* No Workspace loading
* No NPCs, terrain, or UI
* No DataStore writes

**Target**

* Router lifetime per player: **<2 seconds**

---

### Player World Server (Reserved)

**Purpose:** Full gameplay experience.

**Requirements**

* Detect WORLD via TeleportData
* Validate `worldId` + ownership
* Load full gameplay systems:

  * Mobs
  * Crops
  * Chests
  * Persistence
* Enable Worlds Panel ([E] key)
* Handle:

  * `RequestTeleportToHub`
  * `RequestJoinWorld`

**Failure Handling**

* Missing or invalid `worldId` → teleport to Router

---

### Nexus / Hub Server (Reserved, Shared)

**Purpose:** Social + economy space.

**Requirements**

* Detect HUB via TeleportData
* Load:

  * NPCs
  * Shops
  * Static schematic world
* Worlds Panel shows:

  * “My Realms” → return home
* Support multiple concurrent hub instances

---

## Hub Pooling (MemoryStore)

**Goal:** Maintain social density without overcrowding.

### Rules

* Max players per hub (e.g. 25)
* Reuse hub if:

  * `playerCount < max`
* Create new hub if none available
* Expire hub after X minutes idle

### Stored Data (Example)

```lua
HubPools = {
    region = {
        accessCode,
        playerCount,
        lastActive
    }
}
```

---

## UI: Worlds Panel (Existing)

No UI changes required.

**Tabs**

* **My Realms** → Play
* **The Nexus** → Return to Nexus
* **Friends' Realms** → Visit

**Events**

* `RequestJoinWorld`
* `RequestTeleportToHub`
* `RequestReturnHome`

---

## Teleport Events

| Event                  | From  | To     | Action                   |
| ---------------------- | ----- | ------ | ------------------------ |
| `RequestJoinWorld`     | Any   | Router | Teleport to target world |
| `RequestTeleportToHub` | World | Hub    | Teleport to Nexus        |
| `RequestReturnHome`    | Hub   | World  | Teleport to main realm   |

---

## Technical Changes

| File                        | Change                            |
| --------------------------- | --------------------------------- |
| `GameConfig.lua`            | Single `PLACE_ID`                 |
| `Bootstrap.server.lua`      | Explicit server role routing      |
| `LobbyWorldTeleportService` | → `RouterService`                 |
| `CrossPlaceTeleportService` | → `ReservedServerTeleportService` |
| `WorldsPanel.lua`           | No change                         |

---

## Migration Plan

1. Merge bootstrap logic (Router / World / Hub)
2. Implement RouterService
3. Add hub pooling (MemoryStore)
4. Update teleport services (same-place)
5. Add teleport failure recovery
6. End-to-end test:

   * Router → World
   * World → Nexus
   * Nexus → World
7. Deploy single place

---

## Success Metrics

* Router → World: **<3s**
* World ↔ Nexus: **<2s**
* Teleport failure rate: **<0.5%**
* Zero cross-place teleports

---

**Status:** Implemented ✅

## Implementation Files

| File | Purpose |
|------|---------|
| `ServerRoleDetector.lua` | Detects ROUTER/WORLD/HUB from TeleportData |
| `RouterService.lua` | Fast routing at public entry → Hub |
| `ReservedServerTeleportService.lua` | World ↔ Hub teleports |
| `WorldTeleportService.lua` | Join/create player worlds |
| `HubPoolService.lua` | Hub instance pooling |
| `Bootstrap.server.lua` | Role-based server initialization |
| `GameClient.client.lua` | Client early exit for ROUTER |

```

