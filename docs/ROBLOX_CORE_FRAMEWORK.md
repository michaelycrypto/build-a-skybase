# 📐 Roblox Core Game Framework

## Table of Contents
- [High-Level Architecture — Three-Plane Model](#1-high-level-architecture--three-plane-model)
- [Module conventions](#2-module-conventions)
- [Dependency injection](#3-dependency-injection)
- [State management](#4-state-management)
- [Networking standard](#5-networking-standard)
- [Persistence](#6-persistence)
- [Extensibility rules](#7-extensibility-rules)
- [Sample feature map](#8-sample-feature-map-personal-dungeon)
- [Minimal base classes](#9-minimal-base-classes)
- [Engineering principles & declarative patterns](#10-engineering-principles--declarative-patterns)
- [Glossary](#11-glossary)
- [Related docs](#related-docs)

## 1. High-Level Architecture — Three-Plane Model

The framework is organised into three orthogonal planes plus an assets plane.  Each plane has a clear responsibility boundary and a predictable directory root.

| Plane | Responsibility | Directory Root | Examples |
|-------|----------------|----------------|----------|
| **Shared Foundation** | Pure Lua utilities that run on both server and client. No Roblox instances. | `ReplicatedStorage/Shared` | `BaseService`, `Network`, `State`, `Models`, `Util`, `Injector` |
| **Server Authority** | Authoritative game logic, data persistence, world simulation. Nothing here should assume a local player. | `ServerScriptService/Services` | `CurrencyService`, `DungeonService`, `DataService`, `AnalyticsService` |
| **Client Experience** | Presentation logic, client-side prediction, input handling.  Zero authority; may optimistically mirror Server Authority state. | `StarterPlayerScripts/Services` (logic) and `StarterPlayerScripts/Components` (UI) | `CameraService`, `TooltipService`, `InventoryPanel` |
| **Assets & Content** | Static resources consumed by all planes. | `ReplicatedStorage/Assets` | 3D models, sounds, animations, UI templates |

### 1.1 Shared Foundation Sub-Layers
1. **Core** – `BaseService`, `Injector`, `Logger`
2. **Data** – Schemas in `Models`, validators, serializers
3. **Messaging** – `Network` wrappers, `Signal` helpers
4. **State** – Deterministic data containers, reducers, immutable change events

These layers are free of Roblox Instance allocations for maximum portability and testability.

### 1.2 Server Authority Layer
* **Domain Services** – long-lived logic operating on state (e.g., `ShopService`).
* **Infrastructure Services** – wrappers for Roblox APIs such as DataStore, Teleport, Http.
* **Orchestrators** – thin modules that sequence multiple services for complex flows (e.g., onboarding pipeline).

### 1.3 Client Experience Layer
* **Client Services** – input, camera, audio, small caches of server state.
* **View Models** – derive render-ready props from shared state.
* **Components** – pure functions from props → Roblox instances (destroy & recreate, never mutate children).

### 1.4 Cross-Plane Contracts
1. **State Replication:** server mutates Shared State → `Network:Fire("StateChanged")` → client applies patch read-only.
2. **Command / Query:** client calls `Network:Invoke("FunctionName")`; server returns data; all types validated against `Models`.
3. **Events:** fire-and-forget notifications (e.g., `RewardGranted`).

### 1.5 Execution Order
```lua
-- Bootstrap order (server)
Injector:Resolve("DataService"):Init()
Injector:ResolveAll():Init()      -- domain services
Injector:ResolveAll():Start()     -- after Init finishes
```
```lua
-- Bootstrap order (client)
Injector:Resolve("Network"):Init()
Injector:ResolveAll():Init()
Injector:ResolveAll():Start()
```

> **Rule:** A plane may depend only on planes above it (Shared → Server/Client). No cyclic dependencies.

## 2. Module Conventions

```
ReplicatedStorage
├─ Shared
│  ├─ Models         -- plain Lua tables, no Roblox objects
│  ├─ State          -- state holders & reducers
│  └─ Network        -- RemoteEvent/Function wrappers
├─ Assets
└─ …
ServerScriptService
└─ Services          -- `ServiceName.lua` (extends BaseService)
StarterPlayerScripts
└─ Services          -- optional thin client mirrors
StarterPlayerScripts
└─ Components        -- declarative UI / 3D views
```

• **File name = public symbol** (e.g. `CurrencyService.lua` returns table `CurrencyService`).
• Each service returns `{Init, Start, Destroy}` or inherits `BaseService` implementing those methods.

## 3. Dependency Injection

```lua
-- Runtime/Bootstrap.server.lua
local Injector = require(ReplicatedStorage.Shared.Injector)
Injector:Bind("CurrencyService", "ServerScriptService.Services.CurrencyService")
Injector:Bind("InventoryService", "ServerScriptService.Services.InventoryService")
Injector:ResolveAll():Start()
```

`Injector` handles construction order and gives each service a private reference table `self.Deps` to other services.

## 4. State Management

*Single authoritative table per domain.*

```lua
-- Shared/StateSlices/CurrencyState.lua
return {
    DEFAULT = {coins = 0, gems = 0},
    Validate = function(t)
        return type(t.coins) == "number" and type(t.gems) == "number"
    end
}
```

Server mutates then fires `StateChanged(path, newValue)` via `Network`. Clients treat state as **read-only**.

## 5. Networking Standard

* One RemoteEvent folder `Remotes` in `ReplicatedStorage`.
* File `Network.lua` exposes `Signal(eventName)` and `Invoke(funcName)` with runtime type validation.

```lua
Network:DefineEvent("StateChanged", {string, any})
Network:DefineFunction("RequestPurchase", {string, number}):Returns({boolean, string})
```

## 6. Persistence

* `DataService` is the only module that touches `DataStoreService`.
* Every player record conforms to a **schema id** in `Shared/Models`.
* Services extend schema via `DataService:RegisterExtension(key, default, validator)`.

## 7. Extensibility Rules

1. New features add:
   * model → `Shared/Models`
   * service → `…/Services`
   * state slice (optional) → `Shared/State`
   * events/functions → `Shared/Network`
2. No cross-service `require`; always use `self.Deps.{Name}`.
3. UI components never call network; they receive props only.

## 8. Sample Feature Map (Personal Dungeon)

| Requirement | Framework Mapping |
|-------------|------------------|
| **Personal dungeon** | `SpaceService` allocates reserved server or template Model per player; tracked in `DungeonState`. |
| **8 spawner slots** | `SpawnerService` enforces `maxPerDungeon = 8`; placement via network `PlaceSpawner(slotId, spawnerId)` function. |
| **Passive coins** | `SpawnerService` increments `CurrencyState` every tick. |
| **Coins/Gems** | `CurrencyState` + `CurrencyService`. |
| **XP & Levels** | `ProgressionState`, `ProgressionService`. |
| **Shop** | `ShopService` validates purchases, debits `CurrencyState`, adds item via `InventoryService`. |
| **Inventory** | `InventoryState` (array of item ids). |
| **Boosts** | `EffectService` applies timed modifiers, writes to `EffectState`; client Component shows timer. |
| **Daily login** | `RewardService` hooks player join, checks `DataService` timestamps. |
| **Emotes** | `EmoteService` validates rate limit, plays animations client-side. |
| **Global lobby** | `SpaceService` allocates shared lobby instance, manages teleport to private dungeons. |
| **Stats tracking** | `AnalyticsService` listens to state changes/events. |
| **Admin utilities** | `AdminService` whitelisted by userId; exposes commands over `Network`. |

All listed features slot naturally into the framework without breaking isolation or conventions.

## 9. Minimal Base Classes

```lua
-- Shared/BaseService.lua
auto   = {{Init = function(self) end, Start = function(self) end, Destroy = function(self) end}}
```

```lua
-- Shared/Injector.lua
local Injector = {}
function Injector:Bind(name, path) … end
function Injector:ResolveAll() … end
```

These two files plus `Network.lua` and `DataService.lua` constitute the irreducible core.

## 10. Engineering Principles & Declarative Patterns

| Principle / Pattern | Purpose | Concrete Application in Framework |
|---------------------|---------|-----------------------------------|
| **Single-Responsibility (SRP)** | Each module does **one** thing so it can be reasoned about and swapped independently. | `CurrencyService` only manages balances; shop logic lives in `ShopService`. |
| **Open-Closed (OCP)** | Code is **open for extension, closed for modification**. | Add boosts through `EffectService:RegisterEffect` instead of editing core files. |
| **Dependency Inversion (DIP)** | High-level modules depend on abstractions, not concrete classes. | Services communicate via `Network` + `State` events, never by direct object references outside `self.Deps`. |
| **Composition Over Inheritance** | Favour small composable behaviours to avoid deep hierarchies. | A `Spawner` object = `PassiveGenerator` + `PlacementRule` tables instead of subclassing. |
| **Entity-Component System (ECS) Mindset** | Data = **components**, logic = **systems** → declarative object creation. | `ObjectService:Spawn("mob_spawner", {location = …})` attaches generator + health components read from `Models`. |
| **Functional Reactive Programming (FRP)** | Derive UI/game state from observable data streams. | UI components subscribe to `StateChanged` and recompute props; no imperative UI updates scattered across code. |
| **Configuration-Driven Design** | Behaviour defined in data (configs, JSON/Lua tables) not code branches. | Shop inventory, daily rewards, dungeon templates live under `ReplicatedStorage/Configs`. Services just parse & enforce. |
| **Convention over Configuration** | Predictable file layout & naming eliminates boilerplate configuration. | `Services/ThingService.lua` auto-registered by `Injector` based on naming. |
| **Stateless UI** | View logic is pure function of props/state. | Components re-render on prop change, never store gameplay state internally. |
| **Idempotent Systems** | Re-running initialization causes no side-effects → hot-reload safety. | `Service.Init` guards `if self.started then return end`. |
| **Contract-First Networking** | Explicit parameter & return type specs; auto-validation. | `Network:DefineFunction("RequestPurchase", {...}):Returns({success = "boolean"})`. |
| **Test-Driven Development (TDD)** | Ensure contracts stay intact during refactor. | Each service has `{ServiceName}.spec.lua` under `ServerScriptService/Tests`. |
| **Code Generation Friendly** | Repetitive boilerplate encapsulated in templates/macros. | CLI command `rbxgen service Currency` scaffolds `CurrencyService`, test, and state slice. |
| **Observability & Logging** | Structured logs/events for diagnostics. | `LoggingService:Info("ShopService", "Purchase", {playerId = …})` feeds DevConsole or remote ELK stack. |
| **Feature Flags** | Toggle functionality without redeploy. | `FeatureFlagService:IsEnabled("WinterEvent")` controls event activation via DataStore. |

### Declarative Extension Checklist
1. **Define data first:** Add new record under `Shared/Models` or `Configs`.
2. **Emit state shape:** Extend or create a state slice with default values & validator.
3. **Expose contract:** Add remote definition in `Network.lua` **or** events in existing service.
4. **Write thin service layer:** Manipulate state based on config, no UI/physics.
5. **Create pure components:** Derive visuals from state props; never call services directly.
6. **Add tests:** Cover validators, state mutations, and network contracts.

Apply this checklist and patterns to maintain a declarative, extensible codebase that scales with feature count while keeping cognitive load low.

---
**Outcome**: Clear boundaries, predictable data flow, strict typing, and small surface area for bugs—forming a solid foundation for any Roblox project.

## 11. Glossary

| Term | Definition |
|------|------------|
| **Plane** | A vertical slice of responsibility (Shared, Server, Client). |
| **Service** | Long-lived Lua module that owns a portion of game logic; instantiated by the `Injector`. |
| **State Slice** | A namespaced table under `Shared/State` holding authoritative data for a domain. |
| **Remote Contract** | Typed signature for an event or function exposed via `Network`. |
| **SRP, OCP, DIP** | SOLID principles: Single-Responsibility, Open-Closed, Dependency Inversion. |
| **ECS** | Entity-Component-System paradigm; data (components) separated from logic (systems). |
| **FRP** | Functional Reactive Programming; UI reacts to observable state streams. |
| **Idempotent** | Safe to execute multiple times without changing the result beyond the first application. |
| **Hot-Reload** | Re-loading modules while the game is running without requiring restart. |
| **Feature Flag** | Runtime toggle that enables or disables a capability without code deployment. |

## Related Docs
- [Documentation Index](DOCS_INDEX.md)
- [Server-Side API Documentation](API_DOCUMENTATION.md)
- [Client Architecture Guide](CLIENT_ARCHITECTURE_GUIDE.md)