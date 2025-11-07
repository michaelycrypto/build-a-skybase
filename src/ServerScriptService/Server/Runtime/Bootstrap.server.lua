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

-- Disable overhead name/health display to avoid CoreScript CharacterNameHandler lookups in Studio
pcall(function()
	game:GetService("Players").NameDisplayDistance = 0
	game:GetService("Players").HealthDisplayDistance = 0
end)

-- Initialize core systems
Logger:Initialize(Config.LOGGING, Network)
EventManager:Initialize(Network)

-- Bind all services with dependencies

-- PlayerDataStoreService - handles player data persistence
Injector:Bind("PlayerDataStoreService", script.Parent.Parent.Services.PlayerDataStoreService, {
	dependencies = {},
	mixins = {}
})

-- PlayerInventoryService - server-side inventory authority (must be bound before PlayerService)
Injector:Bind("PlayerInventoryService", script.Parent.Parent.Services.PlayerInventoryService, {
	dependencies = {"PlayerDataStoreService"},
	mixins = {}
})

-- CraftingService - server-authoritative crafting system
Injector:Bind("CraftingService", script.Parent.Parent.Services.CraftingService, {
	dependencies = {"PlayerInventoryService"},
	mixins = {}
})

-- PlayerService - core service for player management
Injector:Bind("PlayerService", script.Parent.Parent.Services.PlayerService, {
	dependencies = {"PlayerDataStoreService", "PlayerInventoryService"},
	mixins = {"RateLimited", "Cooldownable"}
})

-- ShopService - depends on PlayerService for currency management
Injector:Bind("ShopService", script.Parent.Parent.Services.ShopService, {
	dependencies = {"PlayerService"},
	mixins = {"RateLimited", "Cooldownable"}
})

-- QuestService - depends on PlayerService for data and rewards
Injector:Bind("QuestService", script.Parent.Parent.Services.QuestService, {
	dependencies = {"PlayerService"},
	mixins = {"RateLimited", "Cooldownable"}
})

-- World and grid services removed as part of architecture reduction

-- Bind WorldOwnershipService (manages server instance ownership)
Injector:Bind("WorldOwnershipService", script.Parent.Parent.Services.WorldOwnershipService, {
	dependencies = {},
	mixins = {}
})

-- Bind VoxelWorldService (depends on inventory for block placement validation)
Injector:Bind("VoxelWorldService", script.Parent.Parent.Services.VoxelWorldService, {
	dependencies = {"PlayerInventoryService", "WorldOwnershipService"},
	mixins = {}
})

-- Bind SaplingService (depends on voxel world to set/get blocks)
Injector:Bind("SaplingService", script.Parent.Parent.Services.SaplingService, {
	dependencies = {"VoxelWorldService", "WorldOwnershipService"},
	mixins = {}
})

-- Bind CropService (depends on voxel world)
Injector:Bind("CropService", script.Parent.Parent.Services.CropService, {
	dependencies = {"VoxelWorldService", "WorldOwnershipService"},
	mixins = {}
})

-- Bind ChestStorageService (manages chest inventories)
Injector:Bind("ChestStorageService", script.Parent.Parent.Services.ChestStorageService, {
	dependencies = {"VoxelWorldService", "PlayerInventoryService"},
	mixins = {}
})

-- Bind DroppedItemService (manages dropped items in world)
Injector:Bind("DroppedItemService", script.Parent.Parent.Services.DroppedItemService, {
	dependencies = {"VoxelWorldService", "PlayerInventoryService"},
	mixins = {}
})

-- Bind MobEntityService (new mob system)
Injector:Bind("MobEntityService", script.Parent.Parent.Services.MobEntityService, {
	dependencies = {"VoxelWorldService", "WorldOwnershipService", "DroppedItemService", "PlayerInventoryService"},
	mixins = {}
})

-- Initialize all services
logger.Info("Initializing all services...")
local services = Injector:ResolveAll()
services:Init()

-- Get individual service instances for EventManager
local playerDataStoreService = Injector:Resolve("PlayerDataStoreService")
local playerService = Injector:Resolve("PlayerService")
local shopService = Injector:Resolve("ShopService")
local questService = Injector:Resolve("QuestService")
local playerInventoryService = Injector:Resolve("PlayerInventoryService")
local craftingService = Injector:Resolve("CraftingService")
local voxelWorldService = Injector:Resolve("VoxelWorldService")
local saplingService = Injector:Resolve("SaplingService")
local cropService = Injector:Resolve("CropService")
local worldOwnershipService = Injector:Resolve("WorldOwnershipService")
local chestStorageService = Injector:Resolve("ChestStorageService")
local droppedItemService = Injector:Resolve("DroppedItemService")
local mobEntityService = Injector:Resolve("MobEntityService")

-- Manually inject ChestStorageService into VoxelWorldService (to avoid circular dependency during init)
voxelWorldService.Deps.ChestStorageService = chestStorageService

-- Manually inject DroppedItemService into VoxelWorldService
voxelWorldService.Deps.DroppedItemService = droppedItemService
voxelWorldService.Deps.MobEntityService = mobEntityService

-- Manually inject SaplingService into VoxelWorldService for block-change notifications
voxelWorldService.Deps.SaplingService = saplingService

-- Manually inject CropService into VoxelWorldService
voxelWorldService.Deps.CropService = cropService

-- Create services table for EventManager
local servicesTable = {
	PlayerDataStoreService = playerDataStoreService,
	PlayerService = playerService,
	ShopService = shopService,
    QuestService = questService,
	PlayerInventoryService = playerInventoryService,
	CraftingService = craftingService,
	VoxelWorldService = voxelWorldService,
	WorldOwnershipService = worldOwnershipService,
	ChestStorageService = chestStorageService,
	DroppedItemService = droppedItemService,
	MobEntityService = mobEntityService,
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
	"MobDied"
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

-- NOTE: Voxel world will be initialized when first player (owner) joins
-- This ensures the world is only generated ONCE with the correct seed
logger.Info("VoxelWorldService ready - waiting for owner to join...")

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

-- Assign character parts to Character group
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

-- Track first player flag and world ready state
local firstPlayerHasJoined = false
local worldReady = false

Players.PlayerAdded:Connect(function(player)
	logger.Info("Player joined:", player.Name)

	-- First player becomes the owner
	if not firstPlayerHasJoined then
		firstPlayerHasJoined = true

		-- Claim ownership (this loads or creates world data including seed)
		worldOwnershipService:ClaimOwnership(player)
		logger.Info("🏠 " .. player.Name .. " is now the owner of this world!")

		-- Get the owner's seed (from saved data or newly generated)
		local seed = worldOwnershipService:GetWorldSeed()
		local worldData = worldOwnershipService:GetWorldData()

		-- Initialize world ONCE with correct seed (smaller render distance for Skyblock/sparse worlds)
		voxelWorldService:InitializeWorld(seed, 3)
		logger.Info("🌍 World initialized with owner's seed:", seed)

		-- Load owner's saved world data (chunks and chests) if they have any
		-- IMPORTANT: Must complete BEFORE adding player so they see saved blocks
		if worldData and worldData.chunks and #worldData.chunks > 0 then
			-- Load data immediately - no wait needed, LoadWorldData is synchronous
			voxelWorldService:LoadWorldData()
			logger.Info("📦 Loaded owner's saved world data (" .. #worldData.chunks .. " chunks)")
		else
			logger.Info("📦 New world - no saved data to load")
			-- Initialize starter chest for new worlds (Skyblock mode)
			voxelWorldService:InitializeStarterChest()
		end

		-- Mark world as ready for players (owner and visitors)
		worldReady = true
		logger.Info("✅ World is ready for players!")
	end

	-- Wait for world to be fully initialized (with timeout)
	local WORLD_READY_TIMEOUT = 30 -- seconds
	local waitTime = 0
	local isOwner = not firstPlayerHasJoined or player.UserId == worldOwnershipService:GetOwnerId()

	logger.Info("⏳ Waiting for world to be ready for player:", player.Name, "(owner:", isOwner, ")")

	while not worldReady and waitTime < WORLD_READY_TIMEOUT do
		task.wait(0.1)
		waitTime = waitTime + 0.1

		-- Double-check using service method
		if voxelWorldService:IsWorldReady() then
			worldReady = true
			break
		end
	end

	if not worldReady then
		logger.Error("❌ World failed to initialize within timeout for player:", player.Name)
		player:Kick("World failed to load. Please try again.")
		return
	end

	-- Additional safety check before spawning
	if not voxelWorldService:IsWorldReady() then
		logger.Error("❌ World not ready despite flag - cannot spawn player:", player.Name)
		player:Kick("World not ready. Please try again.")
		return
	end

	logger.Info("✅ World ready! Spawning player:", player.Name, "(waited", waitTime, "seconds)")

	-- NOTE: PlayerInventoryService:OnPlayerAdded is now called by PlayerService
	-- to ensure proper load order (create inventory, then load data)

	-- Add player to voxel world (saved chunks are now applied!)
	voxelWorldService:OnPlayerAdded(player)
	logger.Info("✅ Player spawned successfully:", player.Name)
end)

Players.PlayerRemoving:Connect(function(player)
	logger.Info("Player leaving:", player.Name)

    -- PlayerService handles saving on PlayerRemoving; avoid duplicate save here

	-- IMPORTANT: Save world data if this player is the owner
	if worldOwnershipService:GetOwnerId() == player.UserId then
		logger.Info("💾 Saving world data (owner leaving)...")
		voxelWorldService:SaveWorldData()
		logger.Info("✅ World data saved")
	end

	-- Clean up chest viewing
	chestStorageService:OnPlayerRemoved(player)
	-- Remove player from voxel world
	voxelWorldService:OnPlayerRemoved(player)
	-- Clean up player inventory
	playerInventoryService:OnPlayerRemoved(player)
	-- Clean up crafting service
	craftingService:OnPlayerRemoving(player)
end)

-- Initialize existing players (important for Studio testing when server reloads)
logger.Info("Initializing existing players...")
local existingPlayers = Players:GetPlayers()
for i, player in ipairs(existingPlayers) do
	logger.Info("Initializing existing player:", player.Name)

	-- First player becomes the owner
	if i == 1 and not firstPlayerHasJoined then
		firstPlayerHasJoined = true

		-- Claim ownership (this loads or creates world data including seed)
		worldOwnershipService:ClaimOwnership(player)
		logger.Info("🏠 " .. player.Name .. " is now the owner of this world!")

		-- Get the owner's seed (from saved data or newly generated)
		local seed = worldOwnershipService:GetWorldSeed()
		local worldData = worldOwnershipService:GetWorldData()

		-- Initialize world ONCE with correct seed (smaller render distance for Skyblock/sparse worlds)
		voxelWorldService:InitializeWorld(seed, 3)
		logger.Info("🌍 World initialized with owner's seed:", seed)

		-- Load owner's saved world data (chunks and chests) if they have any
		-- IMPORTANT: Must complete BEFORE adding player so they see saved blocks
		if worldData and worldData.chunks and #worldData.chunks > 0 then
			-- Load data immediately - no wait needed, LoadWorldData is synchronous
			voxelWorldService:LoadWorldData()
			logger.Info("📦 Loaded owner's saved world data (" .. #worldData.chunks .. " chunks)")
		else
			logger.Info("📦 New world - no saved data to load")
			-- Initialize starter chest for new worlds (Skyblock mode)
			voxelWorldService:InitializeStarterChest()
		end

		-- Mark world as ready for players (owner and visitors)
		worldReady = true
		logger.Info("✅ World is ready for players!")
	end

	-- Wait for world to be fully initialized (with timeout)
	local WORLD_READY_TIMEOUT = 30 -- seconds
	local waitTime = 0

	logger.Info("⏳ Waiting for world to be ready for existing player:", player.Name)

	while not worldReady and waitTime < WORLD_READY_TIMEOUT do
		task.wait(0.1)
		waitTime = waitTime + 0.1

		-- Double-check using service method
		if voxelWorldService:IsWorldReady() then
			worldReady = true
			break
		end
	end

	if not worldReady then
		logger.Error("❌ World failed to initialize within timeout for existing player:", player.Name)
		player:Kick("World failed to load. Please try again.")
		return
	end

	-- Additional safety check before spawning
	if not voxelWorldService:IsWorldReady() then
		logger.Error("❌ World not ready despite flag - cannot spawn existing player:", player.Name)
		player:Kick("World not ready. Please try again.")
		return
	end

	logger.Info("✅ World ready! Spawning existing player:", player.Name, "(waited", waitTime, "seconds)")

	-- NOTE: PlayerInventoryService:OnPlayerAdded is now called by PlayerService
	-- to ensure proper load order (create inventory, then load data)

	-- Add player to voxel world (saved chunks are now applied!)
	voxelWorldService:OnPlayerAdded(player)
	logger.Info("✅ Existing player spawned successfully:", player.Name)
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

