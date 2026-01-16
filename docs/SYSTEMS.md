# Game Systems Reference

Quick reference for the major game systems.

## Voxel World

### Server (VoxelWorldService)

```lua
-- Initialize world
voxelWorldService:InitializeWorld(seed, renderDistance, worldType)

-- Block operations
voxelWorldService:SetBlock(x, y, z, blockId)
voxelWorldService:GetBlock(x, y, z) -- returns blockId

-- Player management
voxelWorldService:OnPlayerAdded(player)
voxelWorldService:OnPlayerRemoved(player)

-- Chunk streaming (called in Heartbeat)
voxelWorldService:StreamChunksToPlayers()
```

### Client (GameClient + BoxMesher)

Chunks are received via `ChunkDataStreamed` event and meshed in `updateVoxelWorld()`:

1. Server sends compressed chunk data
2. Client decompresses and stores in WorldManager
3. RenderStepped loop processes mesh queue
4. BoxMesher generates optimized Part meshes with textures

### Block Registry

Blocks defined in `VoxelWorld/Core/Constants.lua` under `BlockType`:
- `AIR`, `STONE`, `DIRT`, `GRASS`, `SAND`, `WATER`
- Ores: `COAL_ORE`, `IRON_ORE`, `GOLD_ORE`, `DIAMOND_ORE`, etc.
- Wood: `OAK_LOG`, `OAK_PLANKS`, `OAK_LEAVES`
- And many more...

## Inventory System

### Server (PlayerInventoryService)

```lua
-- Get inventory
local inventory = playerInventoryService:GetInventory(player)

-- Modify inventory
playerInventoryService:AddItem(player, itemId, count)
playerInventoryService:RemoveItem(player, itemId, count)
playerInventoryService:SetSlot(player, slotIndex, itemId, count)

-- Hotbar
playerInventoryService:GetHotbarSlot(player, slotIndex)
playerInventoryService:SetHotbarSlot(player, slotIndex, itemId, count)
```

### Client (ClientInventoryManager)

```lua
-- Get local inventory state
local slot = inventoryManager:GetInventorySlot(index)
local hotbarSlot = inventoryManager:GetHotbarSlot(index)

-- Subscribe to changes
inventoryManager:OnInventoryChanged(function(slotIndex)
    -- Update UI
end)

inventoryManager:OnHotbarChanged(function(slotIndex)
    -- Update hotbar display
end)
```

### UI Components

- `VoxelHotbar` - Bottom hotbar (9 slots + scroll)
- `VoxelInventoryPanel` - Full inventory grid with crafting

## Crafting

### Recipe Config

Recipes in `Configs/RecipeConfig.lua`:

```lua
{
    id = "oak_planks",
    type = "shapeless",
    ingredients = { {item = "oak_log", count = 1} },
    result = {item = "oak_planks", count = 4}
}

{
    id = "crafting_table",
    type = "shaped",
    pattern = {"PP", "PP"},
    key = { P = "oak_planks" },
    result = {item = "crafting_table", count = 1}
}
```

### Server (CraftingService)

```lua
-- Validate and execute craft
local success, resultItem = craftingService:Craft(player, recipeId)
```

### Client UI

`VoxelInventoryPanel` includes 2x2 crafting grid (3x3 at workbench).

## Combat

### Melee (CombatController + DamageService)

1. Client detects LMB hold via `CombatController:SetHolding(true)`
2. Sends `PlayerAttack` event with target info
3. `DamageService` calculates damage (weapon + armor modifiers)
4. Fires `MobDamaged` / player damage events

### Ranged (BowController + BowService)

1. Client holds RMB to charge bow
2. On release, sends `ShootArrow` with charge level
3. Server calculates trajectory, spawns projectile
4. Hit detection and damage via `DamageService`

### Damage Calculation

```lua
-- Base damage from weapon
local baseDamage = weaponConfig.damage or 1

-- Armor reduction
local reduction = armorEquipService:GetArmorReduction(target)
local finalDamage = baseDamage * (1 - reduction)
```

## Mob System

### Server (MobEntityService)

```lua
-- Spawning
mobEntityService:SpawnMob(mobType, position, worldId)

-- Batch updates (sent to clients)
EventManager:FireEventToAll("MobBatchUpdate", updates)
```

### Client (MobReplicationController)

Receives `MobSpawned`, `MobBatchUpdate`, `MobDespawned` events and renders mobs using prefab models from `MobPackageConfig`.

### Mob Types

Defined in `Configs/MobRegistry.lua`:
- Passive: Sheep, Cow, Pig, Chicken
- Hostile: Zombie, Skeleton, Creeper

## Camera System

### Modes

| Mode | Cursor | Rotation | Use Case |
|------|--------|----------|----------|
| `FIRST_PERSON` | Locked | Auto | Immersive gameplay |
| `THIRD_PERSON_LOCK` | Locked | Camera-forward | Combat |
| `THIRD_PERSON_FREE` | Free | Mouse-raycast | Building |

### Controls

- `F5` - Cycle modes
- HUD button - Toggle first/third person

### FOV Effects

- Dynamic FOV when sprinting (80 → 96)
- Zoom effect when charging bow

See `docs/CAMERA_INPUT_SYSTEM.md` for full details.

## Chest Storage

### Server (ChestStorageService)

```lua
-- Open chest
chestStorageService:OpenChest(player, chestPosition)

-- Transfer items
chestStorageService:TransferItem(player, fromSlot, toSlot, count)
```

### Client (ChestUI)

Split-panel UI showing player inventory and chest contents with drag-and-drop.

## Mobile Controls

### MobileControlController

Provides touch controls:
- Left thumbstick for movement
- Right touch zone for camera
- Action buttons: Attack, UseItem, Jump, Sprint

### Detection

```lua
-- InputService auto-detects
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
    -- Use mobile controls
end
```

## World Ownership

### Lobby Flow

1. Player selects world slot in `WorldsPanel`
2. `WorldsListService` provides world list
3. `LobbyWorldTeleportService` teleports to Worlds place with TeleportData

### Worlds Place

1. `WorldOwnershipService` validates teleport data
2. First player (owner) initializes world
3. Visitors wait for world ready
4. World data saved on owner leave

### TeleportData Structure

```lua
{
    ownerUserId = 12345,
    ownerName = "PlayerName",
    slotId = 1,
    worldId = "12345:1",
    visitingAsOwner = true
}
```

## Data Persistence

### PlayerDataStoreService

Uses DataStore2 with combined stores:

```lua
DataStore2.Combine("MainData", "inventory", "hotbar", "coins", "settings")
```

### Auto-Save

- Player data saved on leave
- World data saved on owner leave
- Periodic auto-save every 5 minutes

### World Data

Stored chunks with palette compression:
```lua
{
    chunks = { ... },
    seed = 12345,
    version = 1
}
```



