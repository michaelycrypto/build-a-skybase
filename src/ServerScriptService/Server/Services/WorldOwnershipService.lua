--[[
	WorldOwnershipService.lua

	Manages server instance ownership for player-owned worlds.
	The first player to join becomes the owner of this server instance.
	All world data is stored in the owner's datastore.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local WorldOwnershipService = setmetatable({}, BaseService)
WorldOwnershipService.__index = WorldOwnershipService

-- DataStore for world ownership
local WORLD_DATA_STORE_NAME = "PlayerOwnedWorlds_v34"  -- Changed to v4 to reset all data

function WorldOwnershipService.new()
	local self = setmetatable(BaseService.new(), WorldOwnershipService)

	self._logger = Logger:CreateContext("WorldOwnershipService")
	self._worldDataStore = nil
	self._ownerId = nil -- UserId of the owner
	self._ownerName = nil -- Display name of the owner
	self._worldData = nil -- Cached world data
	self._initialized = false

	return self
end

function WorldOwnershipService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing WorldOwnershipService...")

	-- Initialize DataStore
	pcall(function()
		self._worldDataStore = DataStoreService:GetDataStore(WORLD_DATA_STORE_NAME)
	end)

	if not self._worldDataStore then
		self._logger.Warn("Failed to get DataStore - running in local mode")
	end

	BaseService.Init(self)
	self._logger.Info("WorldOwnershipService initialized")
end

function WorldOwnershipService:Start()
	if self._started then
		return
	end

	self._logger.Info("WorldOwnershipService started")
	BaseService.Start(self)
end

--[[
	Claim ownership of this server instance for a player
	This should only be called for the FIRST player to join
--]]
function WorldOwnershipService:ClaimOwnership(player: Player)
	if self._ownerId then
		self._logger.Warn("Server already has an owner", {
			existingOwner = self._ownerName,
			attemptedClaimer = player.Name
		})
		return false
	end

	self._ownerId = player.UserId
	self._ownerName = player.Name

	self._logger.Info("🏠 Server ownership claimed", {
		owner = player.Name,
		userId = player.UserId
	})

	-- Load world data for this owner
	self:LoadWorldData()

	-- Notify all players about the owner
	self:BroadcastOwnershipInfo()

	return true
end

--[[
	Get the owner's UserId
--]]
function WorldOwnershipService:GetOwnerId()
	return self._ownerId
end

--[[
	Get the owner's display name
--]]
function WorldOwnershipService:GetOwnerName()
	return self._ownerName
end

--[[
	Check if a player is the owner
--]]
function WorldOwnershipService:IsOwner(player: Player)
	return player and player.UserId == self._ownerId
end

--[[
	Get the owner player instance (if they're still in the server)
--]]
function WorldOwnershipService:GetOwner()
	if not self._ownerId then
		return nil
	end

	return Players:GetPlayerByUserId(self._ownerId)
end

--[[
	Load world data from the owner's datastore
--]]
function WorldOwnershipService:LoadWorldData()
	if not self._ownerId or not self._worldDataStore then
		self._logger.Warn("Cannot load world data - no owner or datastore")
		return nil
	end

	local success, data = pcall(function()
		local key = "World_" .. tostring(self._ownerId)
		return self._worldDataStore:GetAsync(key)
	end)

	if success and data then
		self._worldData = data
		self._logger.Info("✅ Loaded world data for owner", {
			owner = self._ownerName,
			chunkCount = (data.chunks and #data.chunks) or 0
		})
	else
		-- Create new world data
		self._worldData = {
			ownerId = self._ownerId,
			ownerName = self._ownerName,
			created = os.time(),
			lastSaved = os.time(),
			seed = math.random(1, 999999),
			chunks = {},
			metadata = {
				name = self._ownerName .. "'s World",
				description = "A player-owned world",
			}
		}
		self._logger.Info("📝 Created new world data for owner", {
			owner = self._ownerName,
			seed = self._worldData.seed
		})
	end

	return self._worldData
end

--[[
	Save world data to the owner's datastore
--]]
function WorldOwnershipService:SaveWorldData(worldData)
	if not self._ownerId or not self._worldDataStore then
		self._logger.Warn("Cannot save world data - no owner or datastore")
		return false
	end

	-- Update cache if provided, otherwise use cached data
	if worldData then
		self._worldData = worldData
	end

	if not self._worldData then
		self._logger.Warn("No world data to save")
		return false
	end

	-- Update last saved timestamp
	self._worldData.lastSaved = os.time()

	local success, err = pcall(function()
		local key = "World_" .. tostring(self._ownerId)
		self._worldDataStore:SetAsync(key, self._worldData)
	end)

	if success then
		self._logger.Info("💾 Saved world data for owner", {
			owner = self._ownerName,
			chunkCount = (self._worldData.chunks and #self._worldData.chunks) or 0
		})
		return true
	else
		self._logger.Error("Failed to save world data", {
			owner = self._ownerName,
			error = tostring(err)
		})
		return false
	end
end

--[[
	Get cached world data
--]]
function WorldOwnershipService:GetWorldData()
	return self._worldData
end

--[[
	Update world metadata
--]]
function WorldOwnershipService:UpdateMetadata(metadata)
	if not self._worldData then
		return false
	end

	self._worldData.metadata = self._worldData.metadata or {}
	for key, value in pairs(metadata) do
		self._worldData.metadata[key] = value
	end

	self._logger.Info("Updated world metadata", {
		owner = self._ownerName
	})

	return true
end

--[[
	Broadcast ownership information to all players
--]]
function WorldOwnershipService:BroadcastOwnershipInfo()
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)

	local ownerInfo = {
		ownerId = self._ownerId,
		ownerName = self._ownerName,
		worldName = self._worldData and self._worldData.metadata and self._worldData.metadata.name or (self._ownerName .. "'s World"),
		created = self._worldData and self._worldData.created or os.time(),
		seed = self._worldData and self._worldData.seed or 0
	}

	for _, player in ipairs(Players:GetPlayers()) do
		EventManager:FireEvent("WorldOwnershipInfo", player, ownerInfo)
	end

	self._logger.Info("📢 Broadcasted ownership info to all players")
end

--[[
	Get world seed for terrain generation
--]]
function WorldOwnershipService:GetWorldSeed()
	if self._worldData and self._worldData.seed then
		return self._worldData.seed
	end
	return 12345 -- Default seed
end

function WorldOwnershipService:Destroy()
	if self._destroyed then
		return
	end

	-- NOTE: Save already happens in game:BindToClose() in Bootstrap
	-- Don't save again here to avoid overwriting with stale data
	-- if self._worldData then
	--     self:SaveWorldData()
	-- end

	BaseService.Destroy(self)
	self._logger.Info("WorldOwnershipService destroyed")
end

return WorldOwnershipService

