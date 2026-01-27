--[[
	Bootstrap.server.lua

	Server initialization script for single-place architecture.
	Uses ServerRoleDetector to determine server type and initialize appropriate systems.

	Server Types:
	- ROUTER: Minimal bootstrap, routes players to their destination (public entry)
	- WORLD: Full gameplay server for player-owned worlds (reserved)
	- HUB: Social hub with NPCs, shops, schematic world (reserved, shared)
--]]

local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local Injector = require(script.Parent.Parent.Injector)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
local Network = require(game.ReplicatedStorage.Shared.Network)
local Config = require(game.ReplicatedStorage.Shared.Config)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)
local ServerRoleDetector = require(game.ReplicatedStorage.Shared.ServerRoleDetector)

local logger = Logger:CreateContext("Bootstrap")
local ServerTypes = GameConfig.ServerTypes

logger.Info("🚀 Starting server...")

-- Detect server role using explicit TeleportData
local SERVER_ROLE, TELEPORT_DATA = ServerRoleDetector.Detect()
local IS_ROUTER = SERVER_ROLE == ServerTypes.ROUTER
local IS_HUB = SERVER_ROLE == ServerTypes.HUB
local IS_WORLD = SERVER_ROLE == ServerTypes.WORLD

logger.Info("🎯 Server role detected", {
	role = SERVER_ROLE,
	isReserved = game.PrivateServerId ~= "",
	hasTeleportData = TELEPORT_DATA ~= nil
})

-- Disable overhead name/health display
pcall(function()
	Players.NameDisplayDistance = 0
	Players.HealthDisplayDistance = 0
end)

-- Initialize core systems
Logger:Initialize(Config.LOGGING, Network)
EventManager:Initialize(Network)

-- ═══════════════════════════════════════════════════════════════════════════
-- ROUTER SERVER BOOTSTRAP
-- Minimal initialization - routes players to their destination immediately
-- Target: <2 seconds per player
-- ═══════════════════════════════════════════════════════════════════════════
if IS_ROUTER then
	logger.Info("⚡ ROUTER mode - minimal bootstrap")

	-- Only bind RouterService and minimal dependencies
	Injector:Bind("PlayerDataStoreService", script.Parent.Parent.Services.PlayerDataStoreService, {
		dependencies = {},
		mixins = {}
	})
	Injector:Bind("RouterService", script.Parent.Parent.Services.RouterService, {
		dependencies = {"PlayerDataStoreService"},
		mixins = {}
	})

	-- Initialize and start router services
	local services = Injector:ResolveAll()
	services:Init()

	local routerService = Injector:Resolve("RouterService")

	-- Register minimal events
	EventManager:RegisterAllEvents()

	services:Start()

	-- Router handles all player routing automatically
	Players.PlayerAdded:Connect(function(player)
		logger.Info("🔀 Routing player", { player = player.Name })
		routerService:RoutePlayer(player)
	end)

	-- Route existing players (for Studio testing)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			routerService:RoutePlayer(player)
		end)
	end

	logger.Info("✅ Router server ready")

	game:BindToClose(function()
		logger.Info("Router shutting down")
		services:Destroy()
	end)

	return -- Exit early - router does nothing else
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FULL SERVER BOOTSTRAP (HUB and WORLD modes)
-- ═══════════════════════════════════════════════════════════════════════════

-- Bind common services (both HUB and WORLD)
Injector:Bind("PlayerDataStoreService", script.Parent.Parent.Services.PlayerDataStoreService, {
	dependencies = {},
	mixins = {}
})
Injector:Bind("PlayerInventoryService", script.Parent.Parent.Services.PlayerInventoryService, {
	dependencies = {"PlayerDataStoreService"},
	mixins = {}
})
Injector:Bind("CraftingService", script.Parent.Parent.Services.CraftingService, {
	dependencies = {"PlayerInventoryService"},
	mixins = {}
})
Injector:Bind("PlayerService", script.Parent.Parent.Services.PlayerService, {
	dependencies = {"PlayerDataStoreService", "PlayerInventoryService", "ArmorEquipService"},
	mixins = {"RateLimited", "Cooldownable"}
})
Injector:Bind("ShopService", script.Parent.Parent.Services.ShopService, {
	dependencies = {"PlayerService"},
	mixins = {"RateLimited", "Cooldownable"}
})
Injector:Bind("QuestService", script.Parent.Parent.Services.QuestService, {
	dependencies = {"PlayerService"},
	mixins = {"RateLimited", "Cooldownable"}
})
Injector:Bind("ArmorEquipService", script.Parent.Parent.Services.ArmorEquipService, {
	dependencies = {"PlayerInventoryService"},
	mixins = {}
})
Injector:Bind("DamageService", script.Parent.Parent.Services.DamageService, {
	dependencies = {"ArmorEquipService", "PlayerInventoryService", "DroppedItemService"},
	mixins = {}
})
Injector:Bind("HungerService", script.Parent.Parent.Services.HungerService, {
	dependencies = {"PlayerService", "DamageService"},
	mixins = {}
})
Injector:Bind("FoodService", script.Parent.Parent.Services.FoodService, {
	dependencies = {"PlayerInventoryService", "PlayerService", "HungerService"},
	mixins = {}
})
Injector:Bind("BowService", script.Parent.Parent.Services.BowService, {
	dependencies = {"PlayerInventoryService", "VoxelWorldService", "DamageService"},
	mixins = {}
})
Injector:Bind("LoadingProtectionService", script.Parent.Parent.Services.LoadingProtectionService, {
	dependencies = {},
	mixins = {}
})

-- Teleport service for reserved server teleports (HUB ↔ WORLD)
Injector:Bind("ReservedServerTeleportService", script.Parent.Parent.Services.ReservedServerTeleportService, {
	dependencies = {},
	mixins = {}
})

-- WorldsListService available in both HUB and WORLD
Injector:Bind("WorldsListService", script.Parent.Parent.Services.WorldsListService, {
	dependencies = {},
	mixins = {}
})

if IS_HUB then
	-- HUB-specific services
	Injector:Bind("VoxelWorldService", script.Parent.Parent.Services.VoxelWorldService, {
		dependencies = {"PlayerInventoryService", "DamageService"},
		mixins = {}
	})
	Injector:Bind("WaterService", script.Parent.Parent.Services.WaterService, {
		dependencies = {"VoxelWorldService"},
		mixins = {}
	})
	Injector:Bind("DroppedItemService", script.Parent.Parent.Services.DroppedItemService, {
		dependencies = {"VoxelWorldService", "PlayerInventoryService"},
		mixins = {}
	})
	Injector:Bind("NPCService", script.Parent.Parent.Services.NPCService, {
		dependencies = {"PlayerService", "PlayerInventoryService"},
		mixins = {}
	})
	-- Hub pooling service to manage hub instances
	Injector:Bind("HubPoolService", script.Parent.Parent.Services.HubPoolService, {
		dependencies = {},
		mixins = {}
	})
	-- World teleport service for joining worlds from hub
	Injector:Bind("WorldTeleportService", script.Parent.Parent.Services.WorldTeleportService, {
		dependencies = {"WorldsListService"},
		mixins = {}
	})
elseif IS_WORLD then
	-- WORLD-specific services
	Injector:Bind("WorldOwnershipService", script.Parent.Parent.Services.WorldOwnershipService, {
		dependencies = {},
		mixins = {}
	})
	Injector:Bind("TutorialService", script.Parent.Parent.Services.TutorialService, {
		dependencies = {"PlayerService", "WorldOwnershipService"},
		mixins = {}
	})
	Injector:Bind("VoxelWorldService", script.Parent.Parent.Services.VoxelWorldService, {
		dependencies = {"PlayerInventoryService", "WorldOwnershipService", "DamageService"},
		mixins = {}
	})
	Injector:Bind("WaterService", script.Parent.Parent.Services.WaterService, {
		dependencies = {"VoxelWorldService"},
		mixins = {}
	})
	Injector:Bind("SaplingService", script.Parent.Parent.Services.SaplingService, {
		dependencies = {"VoxelWorldService", "WorldOwnershipService"},
		mixins = {}
	})
	Injector:Bind("CropService", script.Parent.Parent.Services.CropService, {
		dependencies = {"VoxelWorldService", "WorldOwnershipService"},
		mixins = {}
	})
	Injector:Bind("ChestStorageService", script.Parent.Parent.Services.ChestStorageService, {
		dependencies = {"VoxelWorldService", "PlayerInventoryService"},
		mixins = {}
	})
	Injector:Bind("SmeltingService", script.Parent.Parent.Services.SmeltingService, {
		dependencies = {"VoxelWorldService", "PlayerInventoryService"},
		mixins = {}
	})
	Injector:Bind("DroppedItemService", script.Parent.Parent.Services.DroppedItemService, {
		dependencies = {"VoxelWorldService", "PlayerInventoryService"},
		mixins = {}
	})
	Injector:Bind("MobEntityService", script.Parent.Parent.Services.MobEntityService, {
		dependencies = {"VoxelWorldService", "WorldOwnershipService", "DroppedItemService", "PlayerInventoryService"},
		mixins = {}
	})
	Injector:Bind("ActiveWorldRegistryService", script.Parent.Parent.Services.ActiveWorldRegistryService, {
		dependencies = {},
		mixins = {}
	})
	-- World teleport service for joining other worlds from within a world
	Injector:Bind("WorldTeleportService", script.Parent.Parent.Services.WorldTeleportService, {
		dependencies = {"WorldsListService"},
		mixins = {}
	})
end

-- Initialize all services
logger.Info("Initializing all services...")
local services = Injector:ResolveAll()
services:Init()

-- Get individual service instances
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
local playerService = Injector:Resolve("PlayerService")
local shopService = Injector:Resolve("ShopService")
local questService = Injector:Resolve("QuestService")
local tutorialService = IS_WORLD and Injector:Resolve("TutorialService") or nil
local playerInventoryService = Injector:Resolve("PlayerInventoryService")
local craftingService = Injector:Resolve("CraftingService")
local bowService = Injector:Resolve("BowService")
local armorEquipService = Injector:Resolve("ArmorEquipService")
local voxelWorldService = Injector:Resolve("VoxelWorldService")
local waterService = Injector:Resolve("WaterService")
local saplingService = IS_WORLD and Injector:Resolve("SaplingService") or nil
local cropService = IS_WORLD and Injector:Resolve("CropService") or nil
local worldOwnershipService = IS_WORLD and Injector:Resolve("WorldOwnershipService") or nil
local chestStorageService = IS_WORLD and Injector:Resolve("ChestStorageService") or nil
local smeltingService = IS_WORLD and Injector:Resolve("SmeltingService") or nil
local droppedItemService = Injector:Resolve("DroppedItemService")
local mobEntityService = IS_WORLD and Injector:Resolve("MobEntityService") or nil
local activeWorldRegistryService = IS_WORLD and Injector:Resolve("ActiveWorldRegistryService") or nil
local worldTeleportService = Injector:Resolve("WorldTeleportService") or nil
local worldsListService = Injector:Resolve("WorldsListService") or nil
local reservedServerTeleportService = Injector:Resolve("ReservedServerTeleportService")
local loadingProtectionService = Injector:Resolve("LoadingProtectionService")
local hungerService = Injector:Resolve("HungerService")
local foodService = Injector:Resolve("FoodService")
local npcService = IS_HUB and Injector:Resolve("NPCService") or nil
local hubPoolService = IS_HUB and Injector:Resolve("HubPoolService") or nil

-- Manual service injections (circular dependency resolution)
if voxelWorldService and chestStorageService then
	voxelWorldService.Deps.ChestStorageService = chestStorageService
end
if voxelWorldService then
	voxelWorldService.Deps.DroppedItemService = droppedItemService
	voxelWorldService.Deps.MobEntityService = mobEntityService
end
if voxelWorldService and waterService then
	voxelWorldService.Deps.WaterService = waterService
end
if voxelWorldService then
	voxelWorldService.Deps.SaplingService = saplingService
	voxelWorldService.Deps.CropService = cropService
end

-- Create services table for EventManager
local servicesTable = {
	PlayerDataStoreService = playerDataStoreService,
	PlayerService = playerService,
	ShopService = shopService,
	QuestService = questService,
	TutorialService = tutorialService,
	PlayerInventoryService = playerInventoryService,
	CraftingService = craftingService,
	BowService = bowService,
	ArmorEquipService = armorEquipService,
	VoxelWorldService = voxelWorldService,
	WorldOwnershipService = worldOwnershipService,
	ChestStorageService = chestStorageService,
	SmeltingService = smeltingService,
	DroppedItemService = droppedItemService,
	MobEntityService = mobEntityService,
	ActiveWorldRegistryService = activeWorldRegistryService,
	WorldTeleportService = worldTeleportService,
	WorldsListService = worldsListService,
	ReservedServerTeleportService = reservedServerTeleportService,
	LoadingProtectionService = loadingProtectionService,
	HungerService = hungerService,
	FoodService = foodService,
	NPCService = npcService,
	HubPoolService = hubPoolService,
}

-- Register all events
logger.Info("Registering all events...")
EventManager:RegisterAllEvents()

logger.Info("Registering server event handlers...")
local eventConfig = EventManager:CreateServerEventConfig(servicesTable)
EventManager:RegisterEvents(eventConfig)

logger.Info("🔌 Server event handlers registered")

-- Define client-bound events
logger.Info("Defining client-bound events...")
local clientEvents = {
	"WorldListUpdated",
	"WorldJoinError",
	"ReturnToLobbyAcknowledged",
	"PlayerDataUpdated",
	"CurrencyUpdated",
	"InventoryUpdated",
	"ShowNotification",
	"ShowError",
	"PlaySound",
	"DailyRewardUpdated",
	"DailyRewardClaimed",
	"DailyRewardDataUpdated",
	"DailyRewardError",
	"ShopDataUpdated",
	"ShopStockUpdated",
	"ShowEmote",
	"RemoveEmote",
	"StatsUpdated",
	"PlayerLevelUp",
	"AchievementUnlocked",
	"ServerShutdown",
	"WorldStateChanged",
	"ChunkDataStreamed",
	"ChunkUnload",
	"SpawnChunksStreamed",
	"PlayerEntitySpawned",
	"BlockChanged",
	"BlockChangeRejected",
	"BlockBreakProgress",
	"BlockBroken",
	"InventorySync",
	"HotbarSlotUpdate",
	"ChestOpened",
	"ChestClosed",
	"ChestUpdated",
	"ChestActionResult",
	"WorkbenchOpened",
	"ItemSpawned",
	"ItemRemoved",
	"ItemUpdated",
	"ItemPickedUp",
	"MobSpawned",
	"MobBatchUpdate",
	"MobDespawned",
	"MobDamaged",
	"MobDied",
	"ArmorEquipped",
	"ArmorUnequipped",
	"ArmorSync",
	"ArmorSlotResult",
	"PlayerToolEquipped",
	"PlayerToolUnequipped",
	"ToolSync",
	"PlayerHeldItemChanged",
	"PlayerHungerChanged",
	"PlayerHealthChanged",
	"PlayerArmorChanged",
	"PlayerDamageTaken",
	"PlayerDealtDamage",
	"EatingStarted",
	"EatingCompleted",
	"EatingCancelled",
	"NPCInteraction",
}

for _, eventName in pairs(clientEvents) do
	EventManager:RegisterEvent(eventName, function() end)
end

-- Start all services
services:Start()

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARACTER SCALING (applies to both HUB and WORLD)
-- ═══════════════════════════════════════════════════════════════════════════

local function applyMinecraftScale(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local scale = GameConfig.CharacterScale
	local function setOrCreateScale(name, value)
		local scaleValue = humanoid:FindFirstChild(name)
		if scaleValue and scaleValue:IsA("NumberValue") then
			scaleValue.Value = value
		end
	end

	task.defer(function()
		setOrCreateScale("BodyHeightScale", scale.HEIGHT)
		setOrCreateScale("BodyWidthScale", scale.WIDTH)
		setOrCreateScale("BodyDepthScale", scale.DEPTH)
		setOrCreateScale("HeadScale", scale.HEAD)
	end)
end

local function setupPlayerCharacterScaling(plr)
	local function onCharacterAdded(char)
		if char then
			applyMinecraftScale(char)
		end
	end

	if plr.Character then
		onCharacterAdded(plr.Character)
	end
	plr.CharacterAdded:Connect(onCharacterAdded)
end

for _, plr in ipairs(Players:GetPlayers()) do
	setupPlayerCharacterScaling(plr)
end

Players.PlayerAdded:Connect(setupPlayerCharacterScaling)

-- ═══════════════════════════════════════════════════════════════════════════
-- WORLD STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

local firstPlayerHasJoined = false
local worldReady = false
local configuredFromTeleport = false
local configuredWorldId = nil
local WORLD_READY_TIMEOUT = 30

local function buildWorldStatePayload(status, message)
	local isReady = voxelWorldService and voxelWorldService:IsWorldReady() or false
	local resolvedStatus = status or (isReady and "ready" or "loading")

	local payload = {
		status = resolvedStatus,
		isReady = isReady,
		isPaused = resolvedStatus ~= "ready",
		jobId = tostring(game.JobId or ""),
		timestamp = os.time(),
		message = message,
		serverType = SERVER_ROLE,
	}

	if IS_HUB then
		payload.worldType = "hub_world"
		payload.worldId = "hub_world"
		payload.ownerUserId = nil
		payload.ownerName = "HubServer"
	elseif IS_WORLD then
		payload.worldType = "player_world"
		if worldOwnershipService then
			payload.ownerUserId = worldOwnershipService:GetOwnerId()
			payload.ownerName = worldOwnershipService:GetOwnerName()
			payload.worldId = worldOwnershipService:GetWorldId()
			payload.configuredWorldId = configuredWorldId
		end
	end

	return payload
end

local function dispatchWorldState(status, message, targetPlayer)
	local payload = buildWorldStatePayload(status, message)
	if not payload then return end

	if targetPlayer then
		EventManager:FireEvent("WorldStateChanged", targetPlayer, payload)
	else
		EventManager:FireEventToAll("WorldStateChanged", payload)
	end

	logger.Info("World state dispatched", {
		status = payload.status,
		target = targetPlayer and targetPlayer.Name or "all",
		serverType = SERVER_ROLE
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HUB SERVER INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════
if IS_HUB then
	local HUB_WORLD_SEED = 3984757983459578
	local HUB_RENDER_DISTANCE = 6
	voxelWorldService:InitializeWorld(HUB_WORLD_SEED, HUB_RENDER_DISTANCE, "hub_world")
	logger.Info("✅ Hub voxel world initialized (schematic-based)")

	dispatchWorldState("ready", "hub_initialized")

	-- Register this hub with the pool
	if hubPoolService then
		hubPoolService:RegisterHub()
	end

	-- Anchor character to prevent falling through unloaded chunks
	local function anchorHubCharacter(character)
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = true
		end
	end

	local function unanchorHubCharacter(character)
		if not character then return end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Anchored = false
		end
	end

	-- Track players waiting for loading complete
	local hubPlayersLoading = {}
	local hubPlayerCharConnections = {} -- CharacterAdded connections per player
	
	local function addHubPlayer(player)
		-- Mark player as loading
		hubPlayersLoading[player.UserId] = true
		
		-- Anchor character while loading
		if player.Character then
			anchorHubCharacter(player.Character)
		end
		
		-- Anchor on respawn during loading
		hubPlayerCharConnections[player.UserId] = player.CharacterAdded:Connect(function(char)
			if hubPlayersLoading[player.UserId] then
				anchorHubCharacter(char)
			end
		end)
		
		-- Load player data from DataStore
		if playerService then
			playerService:OnPlayerAdded(player)
		end
		
		-- Initialize armor slots
		if armorEquipService and armorEquipService.OnPlayerAdded then
			armorEquipService:OnPlayerAdded(player)
		end
		
		voxelWorldService:OnPlayerAdded(player)
		dispatchWorldState("ready", nil, player)

		if hubPoolService then
			hubPoolService:UpdatePlayerCount(#Players:GetPlayers())
		end
		
		-- Fallback timeout: unanchor after 10 seconds
		task.delay(10, function()
			if hubPlayersLoading[player.UserId] then
				logger.Warn("Hub player loading timeout", {player = player.Name})
				hubPlayersLoading[player.UserId] = nil
				if hubPlayerCharConnections[player.UserId] then
					hubPlayerCharConnections[player.UserId]:Disconnect()
					hubPlayerCharConnections[player.UserId] = nil
				end
				if player.Character then
					unanchorHubCharacter(player.Character)
				end
			end
		end)
	end
	
	-- Client signals loading complete
	EventManager:RegisterEvent("ClientLoadingComplete", function(eventPlayer)
		if hubPlayersLoading[eventPlayer.UserId] then
			hubPlayersLoading[eventPlayer.UserId] = nil
			if hubPlayerCharConnections[eventPlayer.UserId] then
				hubPlayerCharConnections[eventPlayer.UserId]:Disconnect()
				hubPlayerCharConnections[eventPlayer.UserId] = nil
			end
			if eventPlayer.Character then
				unanchorHubCharacter(eventPlayer.Character)
			end
			logger.Debug("Hub player loaded", {player = eventPlayer.Name})
		end
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		addHubPlayer(plr)
	end

	Players.PlayerAdded:Connect(addHubPlayer)

	Players.PlayerRemoving:Connect(function(plr)
		-- Clear loading state
		hubPlayersLoading[plr.UserId] = nil
		if hubPlayerCharConnections[plr.UserId] then
			hubPlayerCharConnections[plr.UserId]:Disconnect()
			hubPlayerCharConnections[plr.UserId] = nil
		end
		
		-- Save and cleanup player data
		if playerService then
			playerService:OnPlayerRemoving(plr)
		end
		if hungerService and hungerService.OnPlayerRemoving then
			hungerService:OnPlayerRemoving(plr)
		end
		craftingService:OnPlayerRemoving(plr)
		voxelWorldService:OnPlayerRemoved(plr)
		
		if hubPoolService then
			hubPoolService:UpdatePlayerCount(#Players:GetPlayers() - 1)
		end
	end)

	-- Chunk streaming loop
	local hubConfig = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Config)
	local HUB_STREAM_INTERVAL = 1/math.max(1, (hubConfig.NETWORK and hubConfig.NETWORK.CHUNK_STREAM_RATE) or 12)
	local lastHubStream = 0

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastHubStream >= HUB_STREAM_INTERVAL then
			lastHubStream = now
			voxelWorldService:StreamChunksToPlayers()
			if voxelWorldService._pruneUnusedChunks then
				voxelWorldService:_pruneUnusedChunks()
			end
		end
	end)

	logger.Info("✅ Hub server ready")

	game:BindToClose(function()
		dispatchWorldState("shutting_down", "hub_shutdown")
		
		-- Save all player data before shutdown
		logger.Info("Saving all player data...")
		for _, player in pairs(Players:GetPlayers()) do
			if playerService and playerService:GetPlayerData(player) then
				playerService:SavePlayerData(player)
			end
		end
		
		if hubPoolService then
			hubPoolService:UnregisterHub()
		end
		services:Destroy()
	end)

	return -- Exit - hub initialization complete
end

-- ═══════════════════════════════════════════════════════════════════════════
-- WORLD SERVER INITIALIZATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Pre-initialize world framework
local PREINIT_SEED = 12345
local PREINIT_RENDER_DISTANCE = 3

logger.Info("🌍 Pre-initializing voxel world framework...")
local preInitStart = os.clock()
voxelWorldService:InitializeWorld(PREINIT_SEED, PREINIT_RENDER_DISTANCE, "player_world")

-- Pre-generate spawn chunks
local spawnChunkX, spawnChunkZ = 3, 3
if voxelWorldService.worldManager then
	for dx = -1, 1 do
		for dz = -1, 1 do
			local cx, cz = spawnChunkX + dx, spawnChunkZ + dz
			voxelWorldService.worldManager:GetChunk(cx, cz)
		end
	end
end
local preInitTime = (os.clock() - preInitStart) * 1000
logger.Info(string.format("✅ World pre-initialized in %.1fms (spawn chunks ready)", preInitTime))

-- Chunk streaming loop
local vwCoreConfig = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Config)
local CHUNK_STREAM_INTERVAL = 1/math.max(1, (vwCoreConfig.NETWORK and vwCoreConfig.NETWORK.CHUNK_STREAM_RATE) or 12)
local lastStreamTime = 0

-- Collision groups setup
local function ensureGroup(name)
	local groups = {}
	pcall(function()
		if PhysicsService.GetRegisteredCollisionGroups then
			groups = PhysicsService:GetRegisteredCollisionGroups()
		else
			groups = PhysicsService:GetCollisionGroups()
		end
	end)
	for _, g in ipairs(groups) do
		if g.name == name then return end
	end
	pcall(function()
		if PhysicsService.RegisterCollisionGroup then
			PhysicsService:RegisterCollisionGroup(name)
		else
			PhysicsService:CreateCollisionGroup(name)
		end
	end)
end

ensureGroup("DroppedItem")
ensureGroup("Character")
pcall(function()
	PhysicsService:CollisionGroupSetCollidable("DroppedItem", "DroppedItem", false)
	PhysicsService:CollisionGroupSetCollidable("DroppedItem", "Character", false)
	PhysicsService:CollisionGroupSetCollidable("DroppedItem", "Default", true)
end)

local function setCharGroup(char)
	if not char then return end
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			pcall(function() d.CollisionGroup = "Character" end)
		end
	end
	char.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then
			pcall(function() desc.CollisionGroup = "Character" end)
		end
	end)
end

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastStreamTime >= CHUNK_STREAM_INTERVAL then
		lastStreamTime = now
		voxelWorldService:StreamChunksToPlayers()
		if voxelWorldService._pruneUnusedChunks then
			voxelWorldService:_pruneUnusedChunks()
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- WORLD SERVER PLAYER HANDLING
-- ═══════════════════════════════════════════════════════════════════════════

local IS_STUDIO = RunService:IsStudio()
local STUDIO_DEFAULT_SLOT = 1

local function parseTeleportContext(player)
	local joinData = player:GetJoinData()
	local td = joinData and joinData.TeleportData

	-- Case 1: Has TeleportData (from Router or Hub)
	if td and td.serverType == ServerTypes.WORLD then
		local ownerId = td.ownerUserId
		local slotId = td.slotId
		local worldId = td.worldId

		if worldId and not slotId then
			slotId = tonumber(string.match(worldId, "[:_](%d+)$"))
		end

		if not worldId and ownerId and slotId then
			worldId = string.format("%d:%d", ownerId, slotId)
		end

		if not ownerId or not slotId or not worldId then
			return nil, "invalid_payload"
		end

		return {
			ownerId = ownerId,
			ownerName = td.ownerName,
			slotId = slotId,
			worldId = worldId,
			visitingAsOwner = td.visitingAsOwner == true,
			accessCode = td.accessCode,
		}
	end

	-- Case 2: Studio fallback - load player's own main world
	if IS_STUDIO then
		local mainSlot = STUDIO_DEFAULT_SLOT
		local worldId = string.format("%d:%d", player.UserId, mainSlot)

		logger.Info("🔧 Studio mode - loading player's main world", {
			player = player.Name,
			userId = player.UserId,
			worldId = worldId
		})

		return {
			ownerId = player.UserId,
			ownerName = player.Name,
			slotId = mainSlot,
			worldId = worldId,
			visitingAsOwner = true,
			accessCode = nil,
			studioFallback = true
		}
	end

	-- Case 3: Reserved server without valid TeleportData - error
	return nil, "missing_teleport_data"
end

local function configureOwnerIfNeeded(ctx)
	if worldOwnershipService:GetOwnerId() then
		if worldOwnershipService:GetOwnerId() ~= ctx.ownerId or worldOwnershipService:GetWorldId() ~= ctx.worldId then
			return false, "world_already_active"
		end
		return true
	end

	if not worldOwnershipService:SetOwnerById(ctx.ownerId, ctx.ownerName, ctx.worldId) then
		return false, "ownership_claim_failed"
	end

	worldOwnershipService:LoadWorldData()
	configuredFromTeleport = true
	configuredWorldId = ctx.worldId

	if activeWorldRegistryService then
		local ok, err = activeWorldRegistryService:Configure(ctx.worldId, ctx.ownerId, ctx.ownerName, ctx.accessCode)
		if not ok then
			return false, err or "registry_claim_failed"
		end
	end

	logger.Info("👤 World ownership configured", {
		ownerUserId = worldOwnershipService:GetOwnerId(),
		ownerName = worldOwnershipService:GetOwnerName(),
		worldId = worldOwnershipService:GetWorldId(),
	})

	return true
end

local function initializeVoxelWorld()
	local seed = worldOwnershipService:GetWorldSeed()
	local worldData = worldOwnershipService:GetWorldData()

	local needsReinit = seed and seed ~= PREINIT_SEED

	if needsReinit then
		logger.Info("🔄 Reinitializing with owner's seed:", seed)
		voxelWorldService:UpdateWorldSeed(seed)
	else
		logger.Info("✅ Using pre-initialized world (seed matches or new world)")
	end

	if worldData and worldData.chunks and #worldData.chunks > 0 then
		voxelWorldService:LoadWorldData()
		logger.Info("📦 Loaded owner's saved world data (" .. #worldData.chunks .. " chunks)")
	else
		logger.Info("📦 New world - no saved data to load")
		voxelWorldService:InitializeStarterChest()
	end
	worldReady = true
	logger.Info("✅ World is ready for players!")
	dispatchWorldState("ready", "world_initialized")
end

-- Track players waiting for loading complete
local worldPlayersLoading = {}

-- Listen for client loading complete to unanchor (World server)
EventManager:RegisterEvent("ClientLoadingComplete", function(eventPlayer)
	if worldPlayersLoading[eventPlayer.UserId] then
		worldPlayersLoading[eventPlayer.UserId] = nil
		local character = eventPlayer.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = false
			end
			logger.Debug("World player loading complete, unanchored", {player = eventPlayer.Name})
		end
	end
end)

-- Anchor character to prevent falling through unloaded world
local function anchorCharacter(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = true
	end
end

local function unanchorCharacter(character)
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.Anchored = false
	end
end

local function handlePlayerJoin(player, isExisting)
	logger.Info(isExisting and "Initializing existing player:" or "Player joined:", player.Name)

	-- Anchor character immediately to prevent falling through world
	if player.Character then
		anchorCharacter(player.Character)
	end
	
	-- Also anchor on respawn during loading
	local anchorConnection
	anchorConnection = player.CharacterAdded:Connect(function(char)
		if not worldReady then
			anchorCharacter(char)
		end
	end)

	local ctx, err = parseTeleportContext(player)
	if not ctx then
		logger.Error("Context resolution failed", { player = player.Name, reason = err })
		if anchorConnection then anchorConnection:Disconnect() end
		unanchorCharacter(player.Character)
		player:Kick("Failed to load world. Please try again. (" .. tostring(err) .. ")")
		return
	end

	local isOwner = player.UserId == ctx.ownerId
	local bypassChecks = ctx.studioFallback

	if isOwner then
		if not ctx.visitingAsOwner and not bypassChecks then
			if anchorConnection then anchorConnection:Disconnect() end
			unanchorCharacter(player.Character)
			player:Kick("Invalid teleport data. Please rejoin the game.")
			return
		end
		local ok, reason = configureOwnerIfNeeded(ctx)
		if not ok then
			if anchorConnection then anchorConnection:Disconnect() end
			unanchorCharacter(player.Character)
			player:Kick("Unable to start this world right now. (" .. tostring(reason) .. ")")
			return
		end
	else
		if ctx.visitingAsOwner and not bypassChecks then
			if anchorConnection then anchorConnection:Disconnect() end
			unanchorCharacter(player.Character)
			player:Kick("Invalid visitor teleport data.")
			return
		end
		if not worldOwnershipService:GetOwnerId() or worldOwnershipService:GetWorldId() ~= ctx.worldId then
			if anchorConnection then anchorConnection:Disconnect() end
			unanchorCharacter(player.Character)
			player:Kick("The owner has not started this world yet.")
			return
		end
	end

	if not firstPlayerHasJoined and isOwner then
		firstPlayerHasJoined = true
		initializeVoxelWorld()
	end

	local waitTime = 0
	while not worldReady and waitTime < WORLD_READY_TIMEOUT do
		task.wait(0.1)
		waitTime += 0.1
		if voxelWorldService:IsWorldReady() then
			worldReady = true
			break
		end
	end

	-- Disconnect anchor connection - world is ready or failed
	if anchorConnection then
		anchorConnection:Disconnect()
	end

	if not worldReady or not voxelWorldService:IsWorldReady() then
		unanchorCharacter(player.Character)
		player:Kick("World failed to initialize. Please try again.")
		return
	end

	dispatchWorldState("ready", nil, player)
	
	-- Load player data from DataStore (includes inventory)
	if playerService then
		playerService:OnPlayerAdded(player)
	end
	
	-- Initialize armor slots for player
	if armorEquipService and armorEquipService.OnPlayerAdded then
		armorEquipService:OnPlayerAdded(player)
	end
	
	voxelWorldService:OnPlayerAdded(player)

	-- Mark player as loading - character stays anchored until client signals ready
	worldPlayersLoading[player.UserId] = true

	-- Fallback timeout: unanchor after 15 seconds if client doesn't signal ready
	task.delay(15, function()
		if worldPlayersLoading[player.UserId] and player.Character then
			logger.Warn("World player loading timeout, unanchoring", {player = player.Name})
			worldPlayersLoading[player.UserId] = nil
			unanchorCharacter(player.Character)
		end
	end)

	logger.Info("✅ Player spawned successfully (awaiting client loading):", player.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setCharGroup)
	handlePlayerJoin(player, false)
end)

Players.PlayerRemoving:Connect(function(player)
	logger.Info("Player leaving:", player.Name)

	-- Clear loading state
	worldPlayersLoading[player.UserId] = nil

	-- Save world data if owner leaving
	if worldOwnershipService:GetOwnerId() == player.UserId then
		voxelWorldService:SaveWorldData()
		logger.Info("✅ World data saved (owner left)")
	end

	-- Save player data (includes inventory, armor via PlayerService)
	if playerService then
		playerService:OnPlayerRemoving(player)
	end
	
	-- Service cleanup
	if chestStorageService then
		chestStorageService:OnPlayerRemoved(player)
	end
	if hungerService and hungerService.OnPlayerRemoving then
		hungerService:OnPlayerRemoving(player)
	end
	craftingService:OnPlayerRemoving(player)
	voxelWorldService:OnPlayerRemoved(player)
	if tutorialService and tutorialService.ClearPlayerCache then
		tutorialService:ClearPlayerCache(player)
	end
end)

-- Initialize existing players
logger.Info("Initializing existing players...")
for _, player in ipairs(Players:GetPlayers()) do
	if player.Character then
		setCharGroup(player.Character)
	end
	player.CharacterAdded:Connect(setCharGroup)
	handlePlayerJoin(player, true)
end
logger.Info("Existing players initialized")

-- Auto-save task
task.spawn(function()
	while true do
		task.wait(Config.SERVER.SAVE_INTERVAL or 300)
		if worldOwnershipService:GetOwnerId() then
			voxelWorldService:SaveWorldData()
			logger.Info("💾 Auto-saved world data")
		end
	end
end)

-- Server heartbeat task (track playtime)
task.spawn(function()
	while true do
		task.wait(60)
		for _, player in pairs(Players:GetPlayers()) do
			local playerData = playerService:GetPlayerData(player)
			if playerData and playerData.statistics then
				playerData.statistics.totalPlayTime = (playerData.statistics.totalPlayTime or 0) + 1
			end
		end
	end
end)

local SHUTDOWN_GRACE_PERIOD = 1

logger.Info("✅ World server ready")

game:BindToClose(function()
	logger.Info("Server shutting down, notifying players...")
	dispatchWorldState("shutting_down", "server_shutdown")

	for _, player in pairs(Players:GetPlayers()) do
		EventManager:FireEvent("ServerShutdown", player, { seconds = SHUTDOWN_GRACE_PERIOD })
	end

	task.wait(SHUTDOWN_GRACE_PERIOD)

	logger.Info("Saving all player data...")
	for _, player in pairs(Players:GetPlayers()) do
		if playerService:GetPlayerData(player) then
			playerService:SavePlayerData(player)
		end
	end

	logger.Info("Destroying all services...")
	services:Destroy()
	logger.Info("✅ Cleanup complete")
end)
