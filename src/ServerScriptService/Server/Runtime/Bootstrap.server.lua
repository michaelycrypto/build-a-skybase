--[[
	Bootstrap.server.lua

	Server initialization script for the data store system.
	Sets up dependency injection, EventManager, and starts all services.
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

local logger = Logger:CreateContext("Bootstrap")

logger.Info("🚀 Starting server...")

-- Place role config
local LOBBY_PLACE_ID = 139848475014328
local WORLDS_PLACE_ID = 111115817294342
local IS_LOBBY = (game.PlaceId == LOBBY_PLACE_ID)

-- Disable overhead name/health display to avoid CoreScript CharacterNameHandler lookups in Studio
pcall(function()
	game:GetService("Players").NameDisplayDistance = 0
	game:GetService("Players").HealthDisplayDistance = 0
end)

-- Initialize core systems
Logger:Initialize(Config.LOGGING, Network)
EventManager:Initialize(Network)

-- Bind all services with dependencies
-- Common services (both places)
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
-- TutorialService is bound in the worlds place only (not in lobby)
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

-- Loading protection (both places) - keeps players safe during loading screen
Injector:Bind("LoadingProtectionService", script.Parent.Parent.Services.LoadingProtectionService, {
	dependencies = {},
	mixins = {}
})

-- Cross-place helper (both places)
Injector:Bind("CrossPlaceTeleportService", script.Parent.Parent.Services.CrossPlaceTeleportService, {
	dependencies = {},
	mixins = {}
})

if IS_LOBBY then
	-- Lobby-only
	Injector:Bind("LobbyWorldTeleportService", script.Parent.Parent.Services.LobbyWorldTeleportService, {
		dependencies = {},
		mixins = {}
	})
	Injector:Bind("WorldsListService", script.Parent.Parent.Services.WorldsListService, {
		dependencies = {},
		mixins = {}
	})
	Injector:Bind("VoxelWorldService", script.Parent.Parent.Services.VoxelWorldService, {
		dependencies = {"PlayerInventoryService", "DamageService"},
		mixins = {}
	})
	Injector:Bind("DroppedItemService", script.Parent.Parent.Services.DroppedItemService, {
		dependencies = {"VoxelWorldService", "PlayerInventoryService"},
		mixins = {}
	})
else
	-- Worlds place services
	-- Also bind WorldsListService so players can view/manage worlds from within their worlds
	Injector:Bind("WorldsListService", script.Parent.Parent.Services.WorldsListService, {
		dependencies = {},
		mixins = {}
	})
	Injector:Bind("WorldOwnershipService", script.Parent.Parent.Services.WorldOwnershipService, {
		dependencies = {},
		mixins = {}
	})
	-- TutorialService: Only in worlds place (needs WorldOwnershipService to check realm ownership)
	Injector:Bind("TutorialService", script.Parent.Parent.Services.TutorialService, {
		dependencies = {"PlayerService", "WorldOwnershipService"},
		mixins = {}
	})
	Injector:Bind("VoxelWorldService", script.Parent.Parent.Services.VoxelWorldService, {
		dependencies = {"PlayerInventoryService", "WorldOwnershipService", "DamageService"},
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
end

-- Initialize all services
logger.Info("Initializing all services...")
local services = Injector:ResolveAll()
services:Init()

-- Get individual service instances for EventManager
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
local playerService = Injector:Resolve("PlayerService")
local shopService = Injector:Resolve("ShopService")
local questService = Injector:Resolve("QuestService")
local tutorialService = not IS_LOBBY and Injector:Resolve("TutorialService") or nil
local playerInventoryService = Injector:Resolve("PlayerInventoryService")
local craftingService = Injector:Resolve("CraftingService")
local bowService = Injector:Resolve("BowService")
local armorEquipService = Injector:Resolve("ArmorEquipService")
local voxelWorldService = Injector:Resolve("VoxelWorldService")
local saplingService = not IS_LOBBY and Injector:Resolve("SaplingService") or nil
local cropService = not IS_LOBBY and Injector:Resolve("CropService") or nil
local worldOwnershipService = not IS_LOBBY and Injector:Resolve("WorldOwnershipService") or nil
local chestStorageService = not IS_LOBBY and Injector:Resolve("ChestStorageService") or nil
local smeltingService = not IS_LOBBY and Injector:Resolve("SmeltingService") or nil
local droppedItemService = Injector:Resolve("DroppedItemService")
local mobEntityService = not IS_LOBBY and Injector:Resolve("MobEntityService") or nil
local activeWorldRegistryService = not IS_LOBBY and Injector:Resolve("ActiveWorldRegistryService") or nil
local lobbyWorldTeleportService = IS_LOBBY and Injector:Resolve("LobbyWorldTeleportService") or nil
local worldsListService = Injector:Resolve("WorldsListService") or nil  -- Available in both lobby and player-owned worlds
local crossPlaceTeleportService = Injector:Resolve("CrossPlaceTeleportService")
local loadingProtectionService = Injector:Resolve("LoadingProtectionService")
local hungerService = Injector:Resolve("HungerService")
local foodService = Injector:Resolve("FoodService")

-- Manually inject ChestStorageService into VoxelWorldService (to avoid circular dependency during init)
if voxelWorldService and chestStorageService then
	voxelWorldService.Deps.ChestStorageService = chestStorageService
end

-- Manually inject DroppedItemService into VoxelWorldService
if voxelWorldService then
	voxelWorldService.Deps.DroppedItemService = droppedItemService
	voxelWorldService.Deps.MobEntityService = mobEntityService
end

-- Manually inject SaplingService into VoxelWorldService for block-change notifications
if voxelWorldService then
	voxelWorldService.Deps.SaplingService = saplingService
end

-- Manually inject CropService into VoxelWorldService
if voxelWorldService then
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
	LobbyWorldTeleportService = lobbyWorldTeleportService,
	WorldsListService = worldsListService,
	CrossPlaceTeleportService = crossPlaceTeleportService,
	LoadingProtectionService = loadingProtectionService,
	HungerService = hungerService,
	FoodService = foodService,
}

-- Register all events first (defines RemoteEvents with proper parameter signatures)
logger.Info("Registering all events...")
EventManager:RegisterAllEvents()

-- Then register server event handlers
logger.Info("Registering server event handlers...")
local eventConfig = EventManager:CreateServerEventConfig(servicesTable)
EventManager:RegisterEvents(eventConfig)

logger.Info("🔌 Server event handlers registered")

-- Define client-bound events that the server will fire to clients
logger.Info("Defining client-bound events...")
local clientEvents = {
	-- Cross-place UI/support
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
	-- Voxel World Events
	"ChunkDataStreamed",
	"ChunkUnload",
	"BlockChanged",
	"BlockChangeRejected",
	"BlockBreakProgress",
	"BlockBroken",
	-- Inventory Events
	"InventorySync",
	"HotbarSlotUpdate",
	-- Chest Events
	"ChestOpened",
	"ChestClosed",
	"ChestUpdated",
	"ChestActionResult",  -- NEW: Server-authoritative click result
	-- Workbench Events
	"WorkbenchOpened",
	-- Dropped Item Events (server calculates, client simulates)
	"ItemSpawned",
	"ItemRemoved",
	"ItemUpdated",
	"ItemPickedUp",
	"MobSpawned",
	"MobBatchUpdate",
	"MobDespawned",
	"MobDamaged",
	"MobDied",
	-- Armor events
	"ArmorEquipped",
	"ArmorUnequipped",
	"ArmorSync",
	"ArmorSlotResult",
	-- Tool equip events (multiplayer tool visibility)
	"PlayerToolEquipped",
	"PlayerToolUnequipped",
	"ToolSync",
	-- Unified held item events (tools + blocks)
	"PlayerHeldItemChanged",
	-- Hunger/Food system events
	"PlayerHungerChanged",
	"PlayerHealthChanged",
	"PlayerArmorChanged",
	"PlayerDamageTaken",
	"PlayerDealtDamage",
	"EatingStarted",
	"EatingCompleted",
	"EatingCancelled"
}

-- Register each client-bound event (this will define them in the Network module)
for _, eventName in pairs(clientEvents) do
    EventManager:RegisterEvent(eventName, function()
        -- Empty handler - these events are fired TO clients, not handled BY server
    end)
end

-- Export services for debugging (before starting services)
-- Remove global exports in production; keep locals accessible via server console only

-- Start all services
services:Start()

-- ═══════════════════════════════════════════════════════════════════════════
-- MINECRAFT CHARACTER SCALING (applies to both Hub and Player World)
-- Uses values from GameConfig.CharacterScale
-- ═══════════════════════════════════════════════════════════════════════════

-- Apply Minecraft-accurate character scaling
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

-- Setup character scaling for all players
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

-- Shared world-readiness helpers (hub + player worlds)
local firstPlayerHasJoined = false
local worldReady = false
local configuredFromTeleport = false
local configuredWorldId = nil
local WORLD_READY_TIMEOUT = 30 -- seconds

local function buildWorldStatePayload(status, message)
	local isReady = voxelWorldService and voxelWorldService:IsWorldReady() or false
	local resolvedStatus = status or (isReady and "ready" or "loading")

	local payload = {
		status = resolvedStatus,
		isReady = isReady,
		isPaused = resolvedStatus ~= "ready",
		jobId = tostring(game.JobId or ""),
		timestamp = os.time(),
		message = message
	}

	if IS_LOBBY then
		payload.worldType = "hub_world"
		payload.worldId = "hub_world"
		payload.ownerUserId = nil
		payload.ownerName = "HubServer"
	else
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
	if not payload then
		return
	end

	if targetPlayer then
		EventManager:FireEvent("WorldStateChanged", targetPlayer, payload)
	else
		EventManager:FireEventToAll("WorldStateChanged", payload)
	end

	logger.Info("World state dispatched", {
		status = payload.status,
		target = targetPlayer and targetPlayer.Name or "all",
		placeType = IS_LOBBY and "Hub" or "PlayerWorld"
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Hub world bootstrap (always-on shared place). Emit WorldStateChanged so the
-- client-side readiness gate behaves the same as player-owned worlds.
if IS_LOBBY then
	local HUB_WORLD_SEED = 3984757983459578
	local HUB_RENDER_DISTANCE = 6 -- Larger render distance for schematic hub
	voxelWorldService:InitializeWorld(HUB_WORLD_SEED, HUB_RENDER_DISTANCE, "hub_world")
	logger.Info("✅ Hub voxel world initialized (schematic-based)")

	-- Schematic is now loaded via SchematicWorldGenerator in WorldTypes
	-- No manual import needed - chunks are generated on-demand from schematic data

	dispatchWorldState("ready", "hub_initialized")

	local function addHubPlayer(player)
		voxelWorldService:OnPlayerAdded(player)
		-- Initialize armor for hub player
		if armorEquipService and armorEquipService.OnPlayerAdded then
			armorEquipService:OnPlayerAdded(player)
		end
		dispatchWorldState("ready", nil, player)
	end

	for _, plr in ipairs(Players:GetPlayers()) do
		addHubPlayer(plr)
	end

	Players.PlayerAdded:Connect(function(plr)
		addHubPlayer(plr)
	end)

	Players.PlayerRemoving:Connect(function(plr)
		voxelWorldService:OnPlayerRemoved(plr)
		-- Note: Armor cleanup is handled by PlayerService:OnPlayerRemoving (which saves first)
	end)

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

	logger.Info("✅ Lobby hub streaming loop ready")

	game:BindToClose(function()
		dispatchWorldState("shutting_down", "hub_shutdown")
	end)

	return
end

-- Worlds place:
-- S2: Pre-initialize world with placeholder to eliminate first-player delay
-- The actual seed/data will be applied when owner arrives, but having the
-- VoxelWorld framework and spawn chunks ready reduces perceived load time
-- Using 12345 as it's the default seed for new worlds (see WorldOwnershipService:GetWorldSeed)
local PREINIT_SEED = 12345  -- Match default seed for new worlds
local PREINIT_RENDER_DISTANCE = 3

logger.Info("🌍 S2: Pre-initializing voxel world framework...")
local preInitStart = os.clock()
voxelWorldService:InitializeWorld(PREINIT_SEED, PREINIT_RENDER_DISTANCE, "player_world")

-- Pre-generate spawn chunks so they're ready when player arrives
-- SkyblockGenerator spawn is around chunk (3,3) based on originX=48, originZ=48
local spawnChunkX, spawnChunkZ = 3, 3
if voxelWorldService.worldManager then
	for dx = -1, 1 do
		for dz = -1, 1 do
			local cx, cz = spawnChunkX + dx, spawnChunkZ + dz
			local chunk = voxelWorldService.worldManager:GetChunk(cx, cz)
			if chunk then
				-- Chunk is now generated and cached
			end
		end
	end
end
local preInitTime = (os.clock() - preInitStart) * 1000
logger.Info(string.format("✅ S2: World pre-initialized in %.1fms (spawn chunks ready)", preInitTime))

-- Start chunk streaming loop with rate limiting
local vwCoreConfig = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Config)
local CHUNK_STREAM_INTERVAL = 1/math.max(1, (vwCoreConfig.NETWORK and vwCoreConfig.NETWORK.CHUNK_STREAM_RATE) or 12)
local lastStreamTime = 0

-- Collision groups setup (server-side; also configured on client)
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

-- Assign character parts to Character collision group (for Player World only)
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

for _, plr in ipairs(Players:GetPlayers()) do
	setCharGroup(plr.Character)
	plr.CharacterAdded:Connect(setCharGroup)
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(setCharGroup)
end)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastStreamTime >= CHUNK_STREAM_INTERVAL then
		lastStreamTime = now
		voxelWorldService:StreamChunksToPlayers()
        -- Opportunistic prune of unused chunks (backstop in case service loop missed)
        if voxelWorldService._pruneUnusedChunks then
            voxelWorldService:_pruneUnusedChunks()
        end
	end
end)

-- Set up player join/leave handling
local Players = game:GetService("Players")

local STUDIO_PLACEHOLDER_JOB_ID = "00000000-0000-0000-0000-000000000000"
local STUDIO_DEFAULT_SLOT = 1

local function detectStudioPlayTestMode()
	if RunService:IsStudio() then
		return true, "RunService:IsStudio"
	end

	local jobId = tostring(game.JobId or "")
	if jobId == "" or jobId == STUDIO_PLACEHOLDER_JOB_ID then
		return true, "EmptyJobId"
	end

	local testService = game:GetService("TestService")
	if testService then
		local okRun, isRunning = pcall(function()
			return testService.IsRunning
		end)
		if okRun and isRunning then
			return true, "TestService.IsRunning"
		end

		local okMode, isRunMode = pcall(function()
			if testService.IsRunMode then
				return testService:IsRunMode()
			end
			return false
		end)
		if okMode and isRunMode then
			return true, "TestService:IsRunMode"
		end
	end

	return false, nil
end

local IS_STUDIO_PLAYTEST, studioPlayTestReason = detectStudioPlayTestMode()
logger.Info("Studio playtest detection", {
	enabled = IS_STUDIO_PLAYTEST,
	reason = studioPlayTestReason or "LiveServer",
	jobId = tostring(game.JobId or "unknown")
})

local studioFallbackContext = {
	ownerId = nil,
	ownerName = nil,
	slotId = STUDIO_DEFAULT_SLOT,
	worldId = nil
}

local function resolveStudioFallbackContext(player)
	if not IS_STUDIO_PLAYTEST or not player then
		return nil
	end

	if not studioFallbackContext.ownerId then
		local fallbackWorldId = string.format("%d:%d", player.UserId, STUDIO_DEFAULT_SLOT)
		studioFallbackContext.ownerId = player.UserId
		studioFallbackContext.ownerName = player.DisplayName or player.Name
		studioFallbackContext.slotId = STUDIO_DEFAULT_SLOT
		studioFallbackContext.worldId = fallbackWorldId

		return {
			ownerId = studioFallbackContext.ownerId,
			ownerName = studioFallbackContext.ownerName,
			slotId = studioFallbackContext.slotId,
			worldId = studioFallbackContext.worldId,
			visitingAsOwner = true,
			accessCode = nil,
			studioBypass = true,
			studioRole = "owner"
		}
	end

	return {
		ownerId = studioFallbackContext.ownerId,
		ownerName = studioFallbackContext.ownerName,
		slotId = studioFallbackContext.slotId,
		worldId = studioFallbackContext.worldId,
		visitingAsOwner = false,
		accessCode = nil,
		studioBypass = true,
		studioRole = "visitor"
	}
end

local STUDIO_OWNER_WAIT_TIMEOUT = 10 -- seconds

local function waitForStudioOwner(worldId)
	if not IS_STUDIO_PLAYTEST then
		return false
	end

	if not worldOwnershipService then
		return false
	end

	local elapsed = 0
	while elapsed < STUDIO_OWNER_WAIT_TIMEOUT do
		if worldOwnershipService:GetOwnerId() and worldOwnershipService:GetWorldId() == worldId then
			return true
		end
		task.wait(0.2)
		elapsed += 0.2
	end

	return false
end

local function parseTeleportContext(player)
	local joinData = player:GetJoinData()
	if not joinData then
		return nil, "missing_join_data"
	end

	if not IS_STUDIO_PLAYTEST then
		local sourcePlaceId = joinData.SourcePlaceId
		if sourcePlaceId and sourcePlaceId ~= LOBBY_PLACE_ID then
			return nil, "invalid_source"
		end
	end

	local td = joinData.TeleportData
	if not td then
		local studioCtx = resolveStudioFallbackContext(player)
		if studioCtx then
			return studioCtx
		end
		return nil, "missing_teleport_data"
	end

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
		studioBypass = false
	}
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
		slot = tonumber(string.match(worldOwnershipService:GetWorldId() or "", ":(%d+)$")) or ctx.slotId
	})

	return true
end

local function initializeVoxelWorld()
	local seed = worldOwnershipService:GetWorldSeed()
	local worldData = worldOwnershipService:GetWorldData()

	-- S2: Check if we need to reinitialize or can use pre-initialized world
	-- Pre-init uses PREINIT_SEED (0), so if owner's seed differs, we need to update
	local needsReinit = seed and seed ~= PREINIT_SEED

	if needsReinit then
		-- Owner has a different seed (existing world with saved seed)
		logger.Info("🔄 S2: Reinitializing with owner's seed:", seed)
		voxelWorldService:UpdateWorldSeed(seed)
	else
		-- New world or seed matches pre-init - can use pre-generated chunks
		logger.Info("✅ S2: Using pre-initialized world (seed matches or new world)")
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

local function handlePlayerJoin(player, isExisting)
	logger.Info(isExisting and "Initializing existing player:" or "Player joined:", player.Name)

	local ctx, err = parseTeleportContext(player)
	if not ctx then
		logger.Error("Teleport validation failed", { player = player.Name, reason = err })
		if not IS_STUDIO_PLAYTEST then
			player:Kick("Failed to load world (missing teleport data). Please rejoin from the hub.")
			return
		end
		ctx = resolveStudioFallbackContext(player) or {
			ownerId = player.UserId,
			ownerName = player.Name,
			slotId = STUDIO_DEFAULT_SLOT,
			worldId = string.format("%d:%d", player.UserId, STUDIO_DEFAULT_SLOT),
			visitingAsOwner = true,
			accessCode = nil,
			studioBypass = true
		}
	end

	local isOwner = player.UserId == ctx.ownerId

	if isOwner then
		if not ctx.visitingAsOwner and not ctx.studioBypass then
			player:Kick("Invalid owner teleport data. Please rejoin from the hub.")
			return
		end
		local ok, reason = configureOwnerIfNeeded(ctx)
		if not ok then
			player:Kick("Unable to start this world right now. (" .. tostring(reason) .. ")")
			return
		end
	else
		if ctx.visitingAsOwner and not ctx.studioBypass then
			player:Kick("Invalid visitor teleport data.")
			return
		end
		if not worldOwnershipService:GetOwnerId() or worldOwnershipService:GetWorldId() ~= ctx.worldId then
			if ctx.studioBypass then
				logger.Warn("Studio visitor waiting for owner context", {
					player = player.Name,
					worldId = ctx.worldId
				})
				if not waitForStudioOwner(ctx.worldId) then
					player:Kick("Owner context unavailable in Studio Play Test. Restart the session.")
					return
				end
			else
				player:Kick("The owner has not started this world yet.")
				return
			end
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

	if not worldReady or not voxelWorldService:IsWorldReady() then
		player:Kick("World failed to initialize. Please try again.")
		return
	end

	dispatchWorldState("ready", nil, player)

	voxelWorldService:OnPlayerAdded(player)

	-- Initialize armor for player
	if armorEquipService and armorEquipService.OnPlayerAdded then
		armorEquipService:OnPlayerAdded(player)
	end

	logger.Info("✅ Player spawned successfully:", player.Name)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(setCharGroup)
	handlePlayerJoin(player, false)
end)

Players.PlayerRemoving:Connect(function(player)
	logger.Info("Player leaving:", player.Name)

    -- PlayerService handles saving on PlayerRemoving; avoid duplicate save here

	-- IMPORTANT: Save world data if this player is the owner
	if worldOwnershipService:GetOwnerId() == player.UserId then
		local currentWorldId = worldOwnershipService:GetWorldId() or "unknown"
		logger.Info("💾 Saving world data (owner leaving)", {
			player = player.Name,
			ownerId = worldOwnershipService:GetOwnerId(),
			worldId = currentWorldId,
			configuredWorldId = configuredWorldId
		})
		voxelWorldService:SaveWorldData()
		logger.Info("✅ World data saved", {
			worldId = currentWorldId
		})
	end

	-- Clean up chest viewing
	if chestStorageService then
		chestStorageService:OnPlayerRemoved(player)
	end
	-- Remove player from voxel world
	voxelWorldService:OnPlayerRemoved(player)
	-- Clean up player inventory
	playerInventoryService:OnPlayerRemoved(player)
	-- Note: Armor cleanup is handled by PlayerService:OnPlayerRemoving (which saves first)
	-- Clean up crafting service
	craftingService:OnPlayerRemoving(player)
	-- Clean up tutorial cache
	if tutorialService and tutorialService.ClearPlayerCache then
		tutorialService:ClearPlayerCache(player)
	end
end)

-- Initialize existing players (important for Studio testing when server reloads)
logger.Info("Initializing existing players...")
for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(setCharGroup)
	handlePlayerJoin(player, true)
end
logger.Info("Existing players initialized")

-- Set up periodic tasks

-- Auto-save task
task.spawn(function()
	while true do
		task.wait(Config.SERVER.SAVE_INTERVAL or 300) -- Default 5 minutes

		-- Auto-save world data (if owner exists)
		if worldOwnershipService:GetOwnerId() then
			voxelWorldService:SaveWorldData()
			logger.Info("💾 Auto-saved world data")
		end
	end
end)

-- Server heartbeat task
task.spawn(function()
	while true do
		task.wait(60) -- Every minute

		-- Update player statistics
		local Players = game:GetService("Players")
		for _, player in pairs(Players:GetPlayers()) do
			local playerData = playerService:GetPlayerData(player)
			if playerData then
				playerData.statistics.totalPlayTime = playerData.statistics.totalPlayTime + 1
			end
		end

		-- Memory cleanup
		if gc then
			gc()
		end
	end
end)


-- Server shutdown grace period
local SHUTDOWN_GRACE_PERIOD = 0.3-- seconds

logger.Info("✅ Server ready")

-- Cleanup on shutdown
game:BindToClose(function()
	logger.Info("Server shutting down, notifying players...")

	dispatchWorldState("shutting_down", "server_shutdown")

	-- Notify all players of shutdown
	local Players = game:GetService("Players")
	for _, player in pairs(Players:GetPlayers()) do
		EventManager:FireEvent("ServerShutdown", player, {
			seconds = SHUTDOWN_GRACE_PERIOD
		})
	end

	-- Wait for grace period
	task.wait(SHUTDOWN_GRACE_PERIOD)

	logger.Info("Saving all player data...")

	-- Save all player data
	for _, player in pairs(Players:GetPlayers()) do
		if playerService:GetPlayerData(player) then
			playerService:SavePlayerData(player)
		end
	end

	-- World data is saved on owner leave and via periodic auto-save to avoid duplicate queueing here

	logger.Info("Destroying all services...")
	services:Destroy()

	logger.Info("✅ Cleanup complete")
end)

