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
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.Config)

local WorldsListService = setmetatable({}, BaseService)
WorldsListService.__index = WorldsListService

-- Configuration
local MAX_WORLDS_PER_PLAYER = Config.Worlds.MaxWorldsPerPlayer
local WORLD_DATA_STORE_NAME = Config.Worlds.DataStoreVersion
local MAX_FRIENDS_TO_SCAN = 25
local MAX_FRIEND_WORLD_RESULTS = 30
local PLAYER_WORLD_CACHE_TTL = 30
local FRIENDS_WORLD_CACHE_TTL = 20

local function makeWorldId(userId, slot)
	return string.format("%d:%d", userId, slot)
end

function WorldsListService.new()
	local self = setmetatable(BaseService.new(), WorldsListService)

	self._logger = Logger:CreateContext("WorldsList")
	self._worldDataStore = nil
	self._activeWorldsMap = nil
	self._initialized = false
	self._playerWorldCache = {}
	self._friendsWorldCache = {}
	self._pendingFriendTasks = {}

	return self
end

local function cloneWorldsList(list)
	if not list then
		return {}
	end
	local copy = {}
	for i, entry in ipairs(list) do
		local entryCopy = {}
		for k, v in pairs(entry) do
			entryCopy[k] = v
		end
		copy[i] = entryCopy
	end
	return copy
end

function WorldsListService:_getCachedPlayerWorlds(userId)
	local cache = self._playerWorldCache[userId]
	if cache and cache.expiresAt > os.clock() then
		return cloneWorldsList(cache.data)
	end
	self._playerWorldCache[userId] = nil
	return nil
end

function WorldsListService:_setCachedPlayerWorlds(userId, worlds)
	self._playerWorldCache[userId] = {
		data = cloneWorldsList(worlds),
		expiresAt = os.clock() + PLAYER_WORLD_CACHE_TTL
	}
end

function WorldsListService:_invalidatePlayerWorldCache(userId)
	self._playerWorldCache[userId] = nil
end

function WorldsListService:_getCachedFriendsWorlds(userId)
	local worlds = select(1, self:_getCachedFriendsWorldsWithMeta(userId))
	return worlds
end

function WorldsListService:_getCachedFriendsWorldsWithMeta(userId)
	local cache = self._friendsWorldCache[userId]
	if cache and cache.expiresAt > os.clock() then
		return cloneWorldsList(cache.data), self:_copyFriendsCacheMeta(cache)
	end
	self._friendsWorldCache[userId] = nil
	return nil, nil
end

function WorldsListService:_copyFriendsCacheMeta(cache)
	if not cache then
		return nil
	end
	return {
		fetchedAt = cache.fetchedAt,
		expiresAt = cache.expiresAt
	}
end

function WorldsListService:_getFriendsCacheMeta(userId)
	local cache = self._friendsWorldCache[userId]
	if cache and cache.expiresAt > os.clock() then
		return self:_copyFriendsCacheMeta(cache)
	end
	return nil
end

function WorldsListService:_setCachedFriendsWorlds(userId, worlds)
	self._friendsWorldCache[userId] = {
		data = cloneWorldsList(worlds),
		expiresAt = os.clock() + FRIENDS_WORLD_CACHE_TTL,
		fetchedAt = os.time()
	}
end

function WorldsListService:_hasFreshFriendsCache(userId)
	local cache = self._friendsWorldCache[userId]
	return cache and cache.expiresAt > os.clock()
end

function WorldsListService:_readWorldData(userId, slot)
	if not self._worldDataStore then
		return nil
	end

	local worldId = makeWorldId(userId, slot)
	local key = "World_" .. worldId

	local success, result = pcall(function()
		return self._worldDataStore:GetAsync(key)
	end)

	if not success then
		self._logger.Warn("Failed to read world data", {
			userId = userId,
			slot = slot,
			error = result
		})
		return nil
	end

	return result
end

function WorldsListService:Init()
	if self._initialized then
		return
	end

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
function WorldsListService:GetPlayerWorlds(userId, options)
	options = options or {}
	local bypassCache = options.bypassCache == true

	if not bypassCache then
		local cached = self:_getCachedPlayerWorlds(userId)
		if cached then
			return cached
		end
	end

	local worlds = self:_buildPlayerWorlds(userId)
	self:_setCachedPlayerWorlds(userId, worlds)
	return cloneWorldsList(worlds)
end

function WorldsListService:_buildPlayerWorlds(userId)
	if not self._worldDataStore then
		return {}
	end

	local worlds = {}

	for slot = 1, MAX_WORLDS_PER_PLAYER do
		local worldId = makeWorldId(userId, slot)
		local worldData = self:_readWorldData(userId, slot)

		if worldData then
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

function WorldsListService:_collectFriendOnlineWorlds(friendUserId, friendName, limit)
	local results = {}

	for slot = 1, MAX_WORLDS_PER_PLAYER do
		if limit and limit <= 0 then
			break
		end

		local worldId = makeWorldId(friendUserId, slot)
		local isOnline, playerCount = self:IsWorldOnline(worldId)

		if isOnline then
			local worldData = self:_readWorldData(friendUserId, slot)
			local name = (worldData and worldData.metadata and worldData.metadata.name) or ("World " .. slot)
			local created = worldData and worldData.created or 0
			local lastPlayed = worldData and (worldData.lastSaved or worldData.created) or 0

			table.insert(results, {
				worldId = worldId,
				slot = slot,
				name = name,
				created = created,
				lastPlayed = lastPlayed,
				online = true,
				playerCount = playerCount or 0,
				ownerId = friendUserId,
				ownerName = friendName
			})

			if limit then
				limit -= 1
			end
		end
	end

	return results
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

	if success and entry and entry.claimToken then
		-- Check if entry is fresh (within 90s TTL)
		local now = os.time()
		if entry.updatedAt and (now - entry.updatedAt) < 90 then
			return true, entry.playerCount or 0
		end
	end

	return false, 0
end

--[[
	Build a readable display name from friend metadata
]]
local function resolveFriendName(friendInfo)
	if not friendInfo then
		return "Friend"
	end
	if typeof(friendInfo.DisplayName) == "string" and #friendInfo.DisplayName > 0 then
		return friendInfo.DisplayName
	end
	if typeof(friendInfo.Username) == "string" and #friendInfo.Username > 0 then
		return friendInfo.Username
	end
	return "Friend"
end

local function resolveFriendId(friendInfo)
	if not friendInfo then
		return nil
	end
	local friendId = friendInfo.Id or friendInfo.UserId or friendInfo.id or friendInfo.userId
	return tonumber(friendId)
end

--[[
	Get list of friends' worlds
	Returns only currently online worlds so players can jump in immediately.
]]
function WorldsListService:GetFriendsWorlds(userId, options)
	options = options or {}
	if not userId then
		return {}
	end

	if options.useCacheOnly then
		return self:_getCachedFriendsWorlds(userId)
	end

	if not options.bypassCache then
		local cached = self:_getCachedFriendsWorlds(userId)
		if cached then
			return cached
		end
	end

	local friendsWorlds = {}
	local processedFriends = 0
	local seenWorldIds = {}

	local success, friendPages = pcall(function()
		return Players:GetFriendsAsync(userId)
	end)

	if not success or not friendPages then
		self._logger.Warn("Failed to fetch friends list", {
			userId = userId,
			error = friendPages
		})
		return {}
	end

	local function addWorldEntry(worldData)
		if not worldData then
			return
		end
		if seenWorldIds[worldData.worldId] then
			return
		end

		seenWorldIds[worldData.worldId] = true
		table.insert(friendsWorlds, worldData)
	end

	local function processFriendsPage(friendsPage)
		for _, friendInfo in ipairs(friendsPage) do
			if processedFriends >= MAX_FRIENDS_TO_SCAN then
				return true
			end

			local friendUserId = resolveFriendId(friendInfo)
			if friendUserId then
				local friendName = resolveFriendName(friendInfo)
				local budget = MAX_FRIEND_WORLD_RESULTS - #friendsWorlds
				if budget <= 0 then
					return true
				end
				local friendWorlds = self:_collectFriendOnlineWorlds(friendUserId, friendName, budget)
				for _, worldData in ipairs(friendWorlds) do
					addWorldEntry(worldData)
					if #friendsWorlds >= MAX_FRIEND_WORLD_RESULTS then
						return true
					end
				end
			end

			processedFriends = processedFriends + 1
		end
		return false
	end

	local shouldStop = processFriendsPage(friendPages:GetCurrentPage())
	while not shouldStop and not friendPages.IsFinished do
		local ok, err = pcall(function()
			friendPages:AdvanceToNextPageAsync()
		end)
		if not ok then
			self._logger.Warn("Failed to advance friends page", {
				userId = userId,
				error = err
			})
			break
		end
		shouldStop = processFriendsPage(friendPages:GetCurrentPage())
	end

	table.sort(friendsWorlds, function(a, b)
		local aCount = a.playerCount or 0
		local bCount = b.playerCount or 0
		if aCount ~= bCount then
			return aCount > bCount
		end
		local aOwner = a.ownerName or ""
		local bOwner = b.ownerName or ""
		if aOwner ~= bOwner then
			return aOwner < bOwner
		end
		return (a.slot or 0) < (b.slot or 0)
	end)

	self._logger.Info("Compiled friends world list", {
		userId = userId,
		friendsProcessed = processedFriends,
		worldCount = #friendsWorlds
	})

	return friendsWorlds
end

function WorldsListService:_buildFriendsWorlds(userId)
	local worlds = self:GetFriendsWorlds(userId, { bypassCache = true })
	self:_setCachedFriendsWorlds(userId, worlds)
	return worlds
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
		self:_invalidatePlayerWorldCache(userId)
		return true, worldId
	else
		return false, "Failed to save world"
	end
end

--[[
	Send worlds list to player
]]
function WorldsListService:SendWorldsList(player, requestOptions)
	if not player then
		return
	end

	requestOptions = requestOptions or {}
	local userId = player.UserId
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	local myWorlds = self:GetPlayerWorlds(userId)
	local cachedFriends, friendsCacheMeta = self:_getCachedFriendsWorldsWithMeta(userId)
	local friendsWorlds = cachedFriends or {}
	local forceFriendsRefresh = requestOptions.bypassFriendsCache == true
	local hasFreshCache = friendsCacheMeta ~= nil
	local isPendingRefresh = self._pendingFriendTasks[userId] == true
	local friendsRefreshing = forceFriendsRefresh or isPendingRefresh or not hasFreshCache

	EventManager:FireEvent("WorldsListUpdated", player, {
		myWorlds = myWorlds,
		friendsWorlds = friendsWorlds,
		maxWorlds = MAX_WORLDS_PER_PLAYER,
		friendsRefreshing = friendsRefreshing,
		friendsLastUpdated = friendsCacheMeta and friendsCacheMeta.fetchedAt or nil
	})

	self._logger.Info("Sent initial worlds list to player", {
		player = player.Name,
		myWorldsCount = #myWorlds,
		friendsWorldsCount = #friendsWorlds,
		maxWorlds = MAX_WORLDS_PER_PLAYER,
		friendFetchPending = friendsRefreshing
	})

	self:_refreshFriendsWorldsAsync(player, EventManager, {
		force = forceFriendsRefresh
	})
end

function WorldsListService:_refreshFriendsWorldsAsync(player, eventManager, options)
	if not player then
		return
	end

	options = options or {}
	local forceRefresh = options.force == true
	local userId = player.UserId
	if self._pendingFriendTasks[userId] then
		return
	end
	if not forceRefresh and self:_hasFreshFriendsCache(userId) then
		return
	end

	self._pendingFriendTasks[userId] = true

	task.spawn(function()
		local ok, friendsWorlds = pcall(function()
			return self:_buildFriendsWorlds(userId)
		end)
		self._pendingFriendTasks[userId] = nil

		if not ok or not friendsWorlds then
			self._logger.Warn("Failed to refresh friends worlds", {
				userId = userId,
				error = friendsWorlds
			})
			return
		end

		local currentPlayer = Players:GetPlayerByUserId(userId)
		if not currentPlayer then
			return
		end

		local refreshedWorlds = self:GetPlayerWorlds(userId)
		eventManager = eventManager or require(game.ReplicatedStorage.Shared.EventManager)

		eventManager:FireEvent("WorldsListUpdated", currentPlayer, {
			myWorlds = refreshedWorlds,
			friendsWorlds = friendsWorlds,
			maxWorlds = MAX_WORLDS_PER_PLAYER,
			friendsRefreshing = false,
			friendsLastUpdated = (self:_getFriendsCacheMeta(userId) or {}).fetchedAt or os.time()
		})

		self._logger.Info("Sent friends worlds refresh", {
			player = currentPlayer.Name,
			myWorldsCount = #refreshedWorlds,
			friendsWorldsCount = #friendsWorlds,
			maxWorlds = MAX_WORLDS_PER_PLAYER,
			friendsRefreshing = false
		})
	end)
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
			self:_invalidatePlayerWorldCache(player.UserId)

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
			self:_invalidatePlayerWorldCache(player.UserId)

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

