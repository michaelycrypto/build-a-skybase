### Architecture Reduction Plan

- **Goal**: Keep the client HUD and core UX; remove world generation and grid systems; standardize interactions via simple shared APIs to enable future features.

### Features to Keep

- **HUD and UI**
  - Main HUD (`MainHUD`), Loading Screen, panel framework (`PanelManager`), Settings, Shop, Inventory, Quests, Toasts, Emotes UI.
- **Core client boot**
  - `GameClient.client.lua` minimal init, `Logger`, `EventManager`, `Network`, `IconManager`, `UIComponents`, `SoundManager`, `ToastManager`.
- **Player data and economy**
  - Basic player data refresh/update events, currencies, inventory, shop browse/purchase.
- **Emotes**
  - Show/Remove emote billboards.

### Shared APIs to Introduce (ReplicatedStorage/Shared/Api)

- **UiApi**
  - `OnShowNotification(callback)`
  - `OnShowError(callback)`
- **DataApi**
  - `RequestRefresh()`
  - `OnPlayerDataUpdated(callback)`
  - `OnCurrencyUpdated(callback)`
  - `OnInventoryUpdated(callback)`
  - `UpdateSettings(settings)`
- **ShopApi**
  - `RequestStock()`
  - `OnStockUpdated(callback)`
  - `Purchase(itemId, quantity)`
- **InventoryApi**
  - `OnUpdated(callback)`
  - `Get()` (returns last cached inventory on client)
- **EmoteApi**
  - `Play(emoteName)`
  - `OnShow(callback)`
  - `OnRemove(callback)`

Notes:
- APIs wrap `EventManager` remotes and local cache where needed.
- Lives under `src/ReplicatedStorage/Shared/Api/`.

### Things to Remove/Quarantine

- Server: `WorldService`, `GridBoundsService`, `ObjectPlacementService`, `ProximityGridService`, server proximity bootstrap.
- Client: `ProximityGridBootstrap`, `ProximityGridManager`, `GridIntegrationManager`, `GridBoundsManager`, `ToolHighlightManager`, `ToolbarManager`, `DungeonGridManager`.
- Events: All grid/proximity/placement/dungeon/spawner events.
- Docs: Move grid docs to `docs/legacy/` (kept in repo, not loaded).

### Server After Reduction

- `Bootstrap.server.lua` initializes `Logger`, `Network`, `EventManager`.
- Bind minimal services: `PlayerService`, `ShopService`, `QuestService` (if used), Reward service if daily rewards required.
- Register only data/shop/quests/daily rewards/emotes events.

### Client After Reduction

- `GameClient.client.lua` keeps HUD/UX init; removes grid and toolbar bootstraps/managers.
- Panels and HUD can consume new APIs; legacy direct `EventManager` usage continues until migrated.

### Event Contract (post-reduction)

- Client→Server: `ClientReady`, `RequestDataRefresh`, `UpdateSettings`, `GetShopStock`, `PurchaseItem`, `RequestDailyRewardData`, `ClaimDailyReward`, `PlayEmote`, `RequestQuestData`, `ClaimQuestReward`, `RequestBonusCoins`.
- Server→Client: `PlayerDataUpdated`, `CurrencyUpdated`, `InventoryUpdated`, `ShopDataUpdated`, `ShopStockUpdated`, `DailyRewardUpdated`, `DailyRewardClaimed`, `DailyRewardDataUpdated`, `DailyRewardError`, `ShowNotification`, `ShowError`, `PlaySound`, `ShowEmote`, `RemoveEmote`, `StatsUpdated`, `PlayerLevelUp`, `AchievementUnlocked`, `ServerShutdown`, `QuestDataUpdated`, `QuestProgressUpdated`, `QuestRewardClaimed`, `QuestError`.

### Migration Steps

1. Remove server bindings for world/grid services and their event handlers.
2. Remove client grid bootstraps/managers and toolbar; ensure no `require` left.
3. Add Shared APIs and begin refactoring HUD/panels to use them.
4. Optional: prune unused grid events from `EventManager` (safe-guarded today).
5. Smoke test client init and HUD.


