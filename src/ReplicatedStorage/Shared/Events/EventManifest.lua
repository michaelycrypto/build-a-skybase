--[[
	EventManifest.lua
	Global event type manifest merged by EventManager
]]

local Manifest = {
	-- Client -> Server events and their parameter type signatures
	ClientToServer = {
		ClientReady = {},
		RequestDataRefresh = {},
		RequestDailyRewardData = {},
		ClaimDailyReward = {},
		GetShopStock = {},
		RequestQuestData = {},
		ClaimQuestReward = {"any"},
		PurchaseItem = {"any", "any"},
		RequestBonusCoins = {"any", "any"},
		UpdateSettings = {"any"},
		PlayEmote = {"any"},
		-- Voxel legacy compat
		VoxelPlayerPositionUpdate = {"any"},
		VoxelRequestInitialChunks = {},

		-- Dungeon/Spawner/Toolbar compatibility
		RequestDungeonGrid = {},
		RequestSlotUnlock = {"any"},
		DepositMobHead = {"any", "any"},
		RemoveMobHead = {"any"},
		SpawnerToolEquipped = {"any"},
		SpawnerToolUnequipped = {"any"},
		DebugSyncTools = {},
		DebugRemoveTools = {},
		ToolbarModeChanged = {"any"},
		ToolActivated = {"any"},

		-- Voxel tool equip (Minecraft-style)
		EquipTool = {"any"}, -- {slotIndex}
		UnequipTool = {},
		-- Hotbar selection (for blocks held in hand)
		SelectHotbarSlot = {"any"}, -- {slotIndex}

		-- Voxel server-authoritative edit requests
		VoxelRequestBlockPlace = {"any"},
		VoxelRequestRenderDistance = {"any"},
		PlayerPunch = {"any"},  -- Block breaking via punch system
		CancelBlockBreak = {"any"}, -- Immediate cancel of break progress for a block
		-- PvP melee
		PlayerMeleeHit = {"any"}, -- {targetUserId, swingTimeMs}

		-- Chest interactions
		RequestOpenChest = {"any"}, -- {x, y, z} - Request to open chest at position
		RequestCloseChest = {"any"}, -- {x, y, z} - Close chest
		ChestItemTransfer = {"any"}, -- {chestPos, fromSlot, toSlot, isDeposit} - Transfer item
		ChestSlotClick = {"any"}, -- NEW: {chestPosition, slotIndex, isChestSlot, clickType} - Server-authoritative click
		ChestContentsUpdate = {"any"}, -- {x, y, z, contents} - Client updated chest contents (LEGACY)
		PlayerInventoryUpdate = {"any"}, -- {inventory} - Client updated player inventory (from chest UI) (LEGACY)
		InventoryUpdate = {"any"}, -- {inventory, hotbar} - Client updated inventory (from inventory panel)

		-- Workbench interaction
		RequestOpenWorkbench = {"any"}, -- {x, y, z} - Request to open workbench at position

		-- Dropped item interactions
		RequestItemPickup = {"any"}, -- {id} - Request to pick up item by ID
		RequestDropItem = {"any"}, -- {itemId, count, slotIndex} - Request to drop item

		-- Player movement replication (custom entity)
		PlayerInputSnapshot = {"any"}
	},

	-- Server -> Client events and their parameter type signatures
	ServerToClient = {
		PlayerDataUpdated = {"any"},
		CurrencyUpdated = {"any"},
		InventoryUpdated = {"any"},
		ShowNotification = {"any"},
		ShowError = {"any"},
		PlaySound = {"any"},
		DailyRewardUpdated = {"any"},
		DailyRewardClaimed = {"any"},
		DailyRewardDataUpdated = {"any"},
		DailyRewardError = {"any"},
		ShopDataUpdated = {"any"},
		ShopStockUpdated = {"any"},
		ShowEmote = {"any", "any"},
		RemoveEmote = {"any"},
		StatsUpdated = {"any"},
		PlayerLevelUp = {"any"},
		AchievementUnlocked = {"any"},
		MobRewardReceived = {"any"},
		QuestDataUpdated = {"any"},
		QuestProgressUpdated = {"any"},
		QuestRewardClaimed = {"any"},
		QuestError = {"any"},
		ServerShutdown = {"any"},
		-- Voxel events used by client HUD/EventManager layer
		ChunkDataStreamed = {"any"},
		ChunkUnload = {"any"},
		BlockChanged = {"any"},
		BlockChangeRejected = {"any"},
		BlockBroken = {"any"},
		BlockBreakProgress = {"any"},
		-- Inventory events
		InventorySync = {"any"},
		HotbarSlotUpdate = {"any"},
		InventorySlotUpdate = {"any"},  -- Granular inventory slot sync
		-- Chest events
		ChestOpened = {"any"}, -- {x, y, z, contents} - Chest opened successfully
		ChestClosed = {"any"}, -- {x, y, z} - Chest closed
		ChestUpdated = {"any"}, -- {x, y, z, contents} - Chest contents changed (LEGACY)
		ChestActionResult = {"any"}, -- NEW: {chestPosition, chestContents, playerInventory, cursorItem} - Server-authoritative result
		-- Workbench open
		WorkbenchOpened = {"any"}, -- {x, y, z}
		-- Dropped item events (server calculates, client simulates)
		ItemSpawned = {"any"}, -- {id, itemId, count, startPos, finalPos, velocity}
		ItemRemoved = {"any"}, -- {id}
		ItemUpdated = {"any"}, -- {id, count} - For merging
		ItemPickedUp = {"any"}, -- {itemId, count} - Pickup feedback
		-- Custom entity lifecycle
		PlayerEntitySpawned = {"any"},
		PlayerEntityAdded = {"any"},
		PlayerEntityRemoved = {"any"},
		PlayerEntitiesSnapshot = {"any"},
		PlayerCorrection = {"any"},
		-- Broadcast when a player punches so others can play punch anim
		PlayerPunched = {"any"},
		-- PvP feedback
		PlayerDamaged = {"any"}, -- {attackerUserId, victimUserId, amount}
		PlayerSwordSwing = {"any"}, -- {userId}
		-- Broadcast when a player toggles sneak
		PlayerSneak = {"any"},
		-- World ownership info
		WorldOwnershipInfo = {"any"}
	}
}

return Manifest


