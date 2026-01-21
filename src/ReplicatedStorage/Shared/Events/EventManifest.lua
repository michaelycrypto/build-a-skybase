--[[
	EventManifest.lua
	Global event type manifest merged by EventManager
]]

local Manifest = {
	-- Client -> Server events and their parameter type signatures
	ClientToServer = {
		-- Cross-place/lobby-world navigation
		RequestJoinWorld = {"any"},   -- {worldId?, ownerUserId?}
		RequestCreateWorld = {"any"}, -- {slot?}
		ReturnToLobby = {},           -- no args
		RequestTeleportToHub = {},    -- Return to hub world from any place
		-- World management (lobby)
		RequestWorldsList = {},       -- Request list of player's worlds and friends' worlds
		DeleteWorld = {"any"},        -- {worldId}
		UpdateWorldMetadata = {"any"}, -- {worldId, metadata}

		ClientReady = {},
		ClientLoadingComplete = {},
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
		-- Spawner tool events removed
		ToolbarModeChanged = {"any"},
		ToolActivated = {"any"},

		-- Voxel tool equip (Minecraft-style)
		EquipTool = {"any"}, -- {slotIndex}
		UnequipTool = {},
		RequestToolSync = {}, -- Request all players' equipped tools (for late joiners)
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

		-- Spawn egg usage
		RequestSpawnMobAt = {"any"}, -- {x, y, z, eggItemId, hotbarSlot, targetBlockPos?, faceNormal?, hitPosition?}

		-- Workbench interaction
		RequestOpenWorkbench = {"any"}, -- {x, y, z} - Request to open workbench at position
		-- Minion interaction
		RequestOpenMinion = {"any"}, -- {x, y, z}
		RequestOpenMinionByEntity = {"any"}, -- {entityId}
		RequestMinionUpgrade = {"any"}, -- {x, y, z}
		RequestMinionCollectAll = {"any"}, -- {x, y, z}
		RequestMinionPickup = {"any"}, -- {x, y, z}
		RequestCloseMinion = {"any"}, -- {x, y, z} optional; server unsubscribes regardless

		-- Furnace interaction (smelting mini-game)
		RequestOpenFurnace = {"any"}, -- {x, y, z} - Request to open furnace at position
		RequestStartSmelt = {"any"}, -- {recipeId, furnacePos} - Start smelting a recipe
		RequestCompleteSmelt = {"any"}, -- {furnacePos, efficiencyPercent} - Complete smelt with efficiency
		RequestCancelSmelt = {"any"}, -- {furnacePos} - Cancel current smelt

		-- Dropped item interactions
		RequestItemPickup = {"any"}, -- {id} - Request to pick up item by ID
		RequestDropItem = {"any"}, -- {itemId, count, slotIndex} - Request to drop item

		-- Player movement replication (custom entity)
		PlayerInputSnapshot = {"any"},

		-- Ranged combat
		BowShoot = {"any"}, -- {origin:Vector3, direction:Vector3, charge:number, slotIndex:number?}

		-- Armor equip system
		EquipArmor = {"any"}, -- {slot: string, itemId: number} - Equip armor to slot
		UnequipArmor = {"any"}, -- {slot: string} - Unequip armor from slot
		ArmorSlotClick = {"any"}, -- {slot: string, cursorItemId: number?} - Click on armor slot with optional cursor item
		RequestArmorSync = {}, -- Request server to resend current armor state

		-- Food/Eating system
		RequestStartEating = {"any"}, -- {foodId: number, slotIndex: number?} - Request to start eating food
		RequestCompleteEating = {"any"}, -- {foodId: number} - Request to complete eating
		RequestCancelEating = {}, -- Cancel eating
		RequestHungerSync = {}, -- Request server to resend current hunger/saturation state

		-- NPC system
		RequestNPCInteract = {"any"}, -- {npcId: string} - Request to interact with NPC
		RequestNPCBuy = {"any"}, -- {npcId: string, itemId: number, quantity: number} - Buy from shop
		RequestNPCSell = {"any"}, -- {npcId: string, itemId: number, quantity: number} - Sell to merchant
		RequestNPCClose = {"any"}, -- {npcId: string} - Close NPC UI
	},

	-- Server -> Client events and their parameter type signatures
	ServerToClient = {
		-- Cross-place/lobby-world navigation
		WorldListUpdated = {"any"}, -- optional UI support: {worlds=[{worldId, name, online, playerCount}]}
		WorldJoinError = {"any"},   -- {message}
		HubTeleportError = {"any"}, -- {message}
		-- Return flow can reuse ShowNotification/ShowError; explicit here for clarity
		ReturnToLobbyAcknowledged = {"any"},
		WorldStateChanged = {"any"},
		-- World management responses
		WorldsListUpdated = {"any"}, -- {myWorlds = [...], friendsWorlds = [...]}
		WorldDeleted = {"any"},      -- {worldId, success}
		WorldMetadataUpdated = {"any"}, -- {worldId, metadata}

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
		SpawnChunksStreamed = {"any"},  -- S3: Server notifies client when spawn chunks are sent
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
		-- Minion UI
		MinionOpened = {"any"}, -- {anchorPos, state}
		MinionUpdated = {"any"}, -- {state}
		MinionClosed = {}, -- Close minion UI
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
		-- Tool equip broadcast (for multiplayer tool visibility)
		PlayerToolEquipped = {"any"}, -- {userId, itemId} - Player equipped a tool
		PlayerToolUnequipped = {"any"}, -- {userId} - Player unequipped tool
		ToolSync = {"any"}, -- {[userId]: itemId, ...} - All players' equipped tools (for late joiners)
		-- Unified held item broadcast (tools AND blocks for 3rd person / multiplayer)
		PlayerHeldItemChanged = {"any"}, -- {userId, itemId} - Player's held item changed (tool or block or nil)
		-- PvP feedback
		PlayerDamaged = {"any"}, -- {attackerUserId, victimUserId, amount}
		PlayerSwordSwing = {"any"}, -- {userId}
		-- Health/Armor system (Minecraft-style)
		PlayerHealthChanged = {"any"}, -- {health, maxHealth}
		PlayerArmorChanged = {"any"}, -- {defense, toughness}
		PlayerDamageTaken = {"any"}, -- {rawDamage, finalDamage, reduced, damageType, attackerId?}
		PlayerDealtDamage = {"any"}, -- {victimId, damage, damageType}
		PlayerDied = {"any"}, -- {playerId}
		PlayerHungerChanged = {"any"}, -- {hunger, saturation}
		-- Broadcast when a player toggles sneak
		PlayerSneak = {"any"},
		-- World ownership info
		WorldOwnershipInfo = {"any"},
		-- Armor equip events
		ArmorEquipped = {"any"}, -- {slot: string, itemId: number} - Armor was equipped
		ArmorUnequipped = {"any"}, -- {slot: string} - Armor was unequipped
		ArmorSync = {"any"}, -- {equippedArmor: {helmet?, chestplate?, leggings?, boots?}} - Full armor state sync
		ArmorSlotResult = {"any"}, -- {equippedArmor, inventory, cursorItem} - Result of armor slot interaction

		-- Furnace events (smelting mini-game)
		FurnaceOpened = {"any"}, -- {x, y, z, recipes} - Furnace opened with available smelting recipes
		SmeltStarted = {"any"}, -- {smeltConfig} or {error} - Smelting started with config
		SmeltCompleted = {"any"}, -- {success, output, coalUsed, stats} - Smelting completed
		SmeltCancelled = {"any"}, -- {refunded} - Smelting cancelled, materials refunded

		-- Food/Eating events
		EatingStarted = {"any"}, -- {foodId: number, duration: number} or {error: string} - Eating started
		EatingCompleted = {"any"}, -- {hunger: number, saturation: number, effects: table} or {error: string} - Eating completed
		EatingCancelled = {"any"}, -- {} - Eating was cancelled

		-- NPC events
		NPCInteraction = {"any"}, -- {npcId: string, npcType: string, interactionType: string} - NPC interaction triggered
		NPCShopOpened = {"any"}, -- {npcId: string, items: table, playerCoins: number} - Shop opened for buying
		NPCMerchantOpened = {"any"}, -- {npcId: string, items: table, playerCoins: number} - Merchant opened for selling
		NPCTradeResult = {"any"}, -- {success: boolean, message: string, newCoins: number, itemId: number} - Trade result
	}
}

return Manifest


