--[[
	WorldsListService.lua

	Manages world listing and metadata for the lobby.
	Queries player's worlds and friends' worlds from DataStore.
	Checks active status from MemoryStore registry.
]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Config = require(game.ReplicatedStorage.Shared.Config)

local WorldsListService = setmetatable({}, BaseService)
WorldsListService.__index = WorldsListService

-- Configuration
local MAX_WORLDS_PER_PLAYER = Config.Worlds.MaxWorldsPerPlayer
local WORLD_DATA_STORE_NAME = Config.Worlds.DataStoreVersion

function WorldsListService.new()
	local self = setmetatable(BaseService.new(), WorldsListService)

	self._logger = Logger:CreateContext("WorldsList")
	self._worldDataStore = nil
	self._activeWorldsMap = nil
	self._initialized = false

	return self
end

function WorldsListService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing WorldsListService...")

	-- Initialize DataStores
	local success, err = pcall(function()
		self._worldDataStore = DataStoreService:GetDataStore(WORLD_DATA_STORE_NAME)
		self._activeWorldsMap = MemoryStoreService:GetSortedMap("ActiveWorlds_v1")
	end)

	if not success then
		self._logger.Warn("Failed to initialize DataStore/MemoryStore:", err)
	end

	self._initialized = true
	BaseService.Init(self)
	self._logger.Info("WorldsListService initialized")
end

function WorldsListService:Start()
	if self._started then
		return
	end

	self._logger.Info("WorldsListService started")
	BaseService.Start(self)
end

--[[
	Get list of player's worlds
	Returns: {worldId, name, created, lastPlayed, online, playerCount}[]
]]
function WorldsListService:GetPlayerWorlds(userId)
	if not self._worldDataStore then
		return {}
	end

	local worlds = {}

	-- Iterate through all possible slots
	for slot = 1, MAX_WORLDS_PER_PLAYER do
		local worldId = tostring(userId) .. ":" .. tostring(slot)
		local key = "World_" .. worldId

		local success, worldData = pcall(function()
			return self._worldDataStore:GetAsync(key)
		end)

		if success and worldData then
			-- Check if world is online
			local isOnline, playerCount = self:IsWorldOnline(worldId)

			table.insert(worlds, {
				worldId = worldId,
				slot = slot,
				name = (worldData.metadata and worldData.metadata.name) or ("World " .. slot),
				created = worldData.created or 0,
				lastPlayed = worldData.lastSaved or worldData.created or 0,
				online = isOnline,
				playerCount = playerCount or 0,
				ownerId = userId,
				ownerName = worldData.ownerName or "Unknown"
			})
		end
	end

	return worlds
end

--[[
	Check if a world is currently online
	Returns: isOnline (boolean), playerCount (number)
]]
function WorldsListService:IsWorldOnline(worldId)
	if not self._activeWorldsMap then
		return false, 0
	end

	local success, entry = pcall(function()
		return self._activeWorldsMap:GetAsync(worldId)
	end)

	if success and entry then
		-- Check if entry is fresh (within 90s TTL)
		local now = os.time()
		if entry.updatedAt and (now - entry.updatedAt) < 90 then
			return true, entry.playerCount or 0
		end
	end

	return false, 0
end

--[[
	Get list of friends' worlds
	For simplicity, returns empty for now
	TODO: Query FriendsService and fetch their worlds
]]
function WorldsListService:GetFriendsWorlds(userId)
	-- Placeholder: in production, query player's friends and their worlds
	return {}
end

--[[
	Get next available slot for a player
	Returns: slot number (1-5) or nil if all slots full
--]]
function WorldsListService:GetNextAvailableSlot(userId)
	if not self._worldDataStore then
		return 1 -- Default to slot 1 if DataStore unavailable
	end

	for slot = 1, MAX_WORLDS_PER_PLAYER do
		local worldId = tostring(userId) .. ":" .. tostring(slot)
		local key = "World_" .. worldId

		local success, worldData = pcall(function()
			return self._worldDataStore:GetAsync(key)
		end)

		if not success or not worldData then
			return slot -- Found empty slot
		end
	end

	return nil -- All slots full
end

--[[
	Create a new world in a specific slot
	Returns: success (boolean), worldId or error message
--]]
function WorldsListService:CreateWorld(player, slotNumber)
	if not self._worldDataStore then
		return false, "DataStore unavailable"
	end

	local userId = player.UserId
	local worldId = tostring(userId) .. ":" .. tostring(slotNumber)
	local key = "World_" .. worldId

	-- Verify slot is empty
	local success, existingData = pcall(function()
		return self._worldDataStore:GetAsync(key)
	end)

	if success and existingData then
		return false, "Slot already occupied"
	end

	-- Create initial world data
	local worldData = {
		worldId = worldId,
		ownerId = userId,
		ownerName = player.Name,
		created = os.time(),
		lastSaved = os.time(),
		seed = math.random(1, 999999),
		chunks = {},
		mobs = {},
		metadata = {
			name = "World " .. slotNumber,
			description = "A player-owned world",
		}
	}

	-- Save to DataStore
	local saveSuccess = pcall(function()
		self._worldDataStore:SetAsync(key, worldData)
	end)

	if saveSuccess then
		self._logger.Info("Created new world", {
			player = player.Name,
			worldId = worldId,
			slot = slotNumber
		})
		return true, worldId
	else
		return false, "Failed to save world"
	end
end

--[[
	Send worlds list to player
]]
function WorldsListService:SendWorldsList(player)
	local myWorlds = self:GetPlayerWorlds(player.UserId)
	local friendsWorlds = self:GetFriendsWorlds(player.UserId)

	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	EventManager:FireEvent("WorldsListUpdated", player, {
		myWorlds = myWorlds,
		friendsWorlds = friendsWorlds,
		maxWorlds = MAX_WORLDS_PER_PLAYER
	})

	self._logger.Info("Sent worlds list to player", {
		player = player.Name,
		myWorldsCount = #myWorlds,
		friendsWorldsCount = #friendsWorlds,
		maxWorlds = MAX_WORLDS_PER_PLAYER
	})
end

--[[
	Delete a world (owner only)
]]
function WorldsListService:DeleteWorld(player, worldId)
	-- Validate ownership
	local ownerId = tonumber(string.match(worldId, "^(%d+):"))
	if not ownerId or ownerId ~= player.UserId then
		self._logger.Warn("Player attempted to delete world they don't own", {
			player = player.Name,
			worldId = worldId
		})
		return false
	end

	-- Delete from DataStore
	if self._worldDataStore then
		local success, err = pcall(function()
			local key = "World_" .. worldId
			self._worldDataStore:RemoveAsync(key)
		end)

		if success then
			self._logger.Info("Deleted world", {
				player = player.Name,
				worldId = worldId
			})

			-- Notify client
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("WorldDeleted", player, {
				worldId = worldId,
				success = true
			})

			return true
		else
			self._logger.Error("Failed to delete world", {
				player = player.Name,
				worldId = worldId,
				error = tostring(err)
			})
		end
	end

	return false
end

--[[
	Update world metadata (owner only)
]]
function WorldsListService:UpdateWorldMetadata(player, worldId, metadata)
	-- Validate ownership
	local ownerId = tonumber(string.match(worldId, "^(%d+):"))
	if not ownerId or ownerId ~= player.UserId then
		self._logger.Warn("Player attempted to update world they don't own", {
			player = player.Name,
			worldId = worldId
		})
		return false
	end

	-- Update metadata in DataStore
	if self._worldDataStore then
		local success, err = pcall(function()
			local key = "World_" .. worldId
			local worldData = self._worldDataStore:GetAsync(key)
			if worldData then
				worldData.metadata = worldData.metadata or {}
				for k, v in pairs(metadata) do
					worldData.metadata[k] = v
				end
				self._worldDataStore:SetAsync(key, worldData)
			end
		end)

		if success then
			self._logger.Info("Updated world metadata", {
				player = player.Name,
				worldId = worldId,
				metadata = metadata
			})

			-- Notify client
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("WorldMetadataUpdated", player, {
				worldId = worldId,
				metadata = metadata
			})

			return true
		else
			self._logger.Error("Failed to update world metadata", {
				player = player.Name,
				worldId = worldId,
				error = tostring(err)
			})
		end
	end

	return false
end

function WorldsListService:Destroy()
	if self._destroyed then
		return
	end

	BaseService.Destroy(self)
	self._logger.Info("WorldsListService destroyed")
end

return WorldsListService

