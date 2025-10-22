--[[
	PlayerDataStoreService.lua

	Handles all player data persistence using Roblox DataStoreService
	Manages:
	- Player profiles (level, XP, coins, gems, stats)
	- Player inventory (hotbar + inventory slots)
	- Player settings
	- Daily rewards tracking

	Uses proper error handling, retry logic, and data versioning
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local PlayerDataStoreService = setmetatable({}, BaseService)
PlayerDataStoreService.__index = PlayerDataStoreService

-- DataStore configuration
local DATA_STORE_NAME = "PlayerData_v6"  -- Changed to v5 to reset all data
local DATA_VERSION = 5

-- Retry configuration for DataStore operations
local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- Auto-save configuration
local AUTO_SAVE_INTERVAL = 300 -- 5 minutes

-- Default player data structure
local DEFAULT_PLAYER_DATA = {
	version = DATA_VERSION,

	-- Profile data
	profile = {
		level = 1,
		experience = 0,
		coins = 100,
		gems = 10,
		manaCrystals = 0,
	},

	-- Statistics
	statistics = {
		gamesPlayed = 0,
		enemiesDefeated = 0,
		coinsEarned = 0,
		itemsCollected = 0,
		totalPlayTime = 0,
		blocksPlaced = 0,
		blocksBroken = 0,
	},

	-- Inventory (will be populated by PlayerInventoryService)
	inventory = {
		hotbar = {},
		inventory = {}
	},

	-- Daily rewards
	dailyRewards = {
		currentStreak = 0,
		lastClaimDate = nil,
		totalDaysClaimed = 0
	},

	-- Dungeon/spawner data
	dungeonData = {
		mobSpawnerSlots = {}
	},

	-- Player settings
	settings = {
		musicVolume = 0.8,
		soundVolume = 1.0,
		enableNotifications = true
	},

	-- Timestamps
	createdAt = 0,
	lastSave = 0,
	lastLogin = 0
}

function PlayerDataStoreService.new()
	local self = setmetatable(BaseService.new(), PlayerDataStoreService)

	self._logger = Logger:CreateContext("PlayerDataStoreService")
	self._dataStore = nil
	self._playerSessions = {} -- Track active player sessions
	self._saveQueue = {} -- Queue for pending saves
	self._autoSaveConnection = nil

	return self
end

function PlayerDataStoreService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing PlayerDataStoreService...")

	-- Initialize DataStore
	local success, err = pcall(function()
		self._dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)

	if not success then
		self._logger.Error("Failed to initialize DataStore", {error = tostring(err)})
		self._logger.Warn("Running in local mode - data will not persist!")
	else
		self._logger.Info("DataStore initialized successfully")
	end

	BaseService.Init(self)
	self._logger.Info("PlayerDataStoreService initialized")
end

function PlayerDataStoreService:Start()
	if self._started then
		return
	end

	self._logger.Info("Starting PlayerDataStoreService...")

	-- Start auto-save loop
	self:_startAutoSave()

	-- Handle server shutdown
	game:BindToClose(function()
		self:SaveAllPlayers()
	end)

	BaseService.Start(self)
	self._logger.Info("PlayerDataStoreService started")
end

--[[
	Load player data from DataStore
	@param player: Player instance
	@return data: Player data table or nil if failed
]]
function PlayerDataStoreService:LoadPlayerData(player: Player)
	if not self._dataStore then
		self._logger.Warn("DataStore not available - using default data", {player = player.Name})
		return self:_createDefaultData(player)
	end

	local key = self:_getPlayerKey(player)
	local attempts = 0

	while attempts < MAX_RETRIES do
		attempts = attempts + 1

		local success, data = pcall(function()
			return self._dataStore:GetAsync(key)
		end)

		if success then
			if data then
				-- Validate and migrate data if needed
				data = self:_validateAndMigrate(data, player)

				-- Update last login
				data.lastLogin = os.time()

				-- Track session
				self._playerSessions[player.UserId] = {
					player = player,
					data = data,
					lastSave = os.time(),
					dirty = false -- Track if data needs saving
				}

				self._logger.Info("Loaded player data", {
					player = player.Name,
					level = data.profile.level,
					coins = data.profile.coins
				})

				return data
			else
				-- New player - create default data
				self._logger.Info("New player detected, creating default data", {player = player.Name})
				local defaultData = self:_createDefaultData(player)

				-- Track session
				self._playerSessions[player.UserId] = {
					player = player,
					data = defaultData,
					lastSave = os.time(),
					dirty = true -- Needs initial save
				}

				return defaultData
			end
		else
			self._logger.Warn("Failed to load player data", {
				player = player.Name,
				attempt = attempts,
				error = tostring(data)
			})

			if attempts < MAX_RETRIES then
				task.wait(RETRY_DELAY)
			end
		end
	end

	-- Failed all retries - use default data
	self._logger.Error("Failed to load player data after retries, using default", {player = player.Name})
	return self:_createDefaultData(player)
end

--[[
	Save player data to DataStore
	@param player: Player instance
	@return success: boolean
]]
function PlayerDataStoreService:SavePlayerData(player: Player)
	if not self._dataStore then
		self._logger.Warn("DataStore not available - cannot save", {player = player.Name})
		return false
	end

	local session = self._playerSessions[player.UserId]
	if not session or not session.data then
		self._logger.Warn("No session data to save", {player = player.Name})
		return false
	end

	-- Update last save timestamp
	session.data.lastSave = os.time()

	local key = self:_getPlayerKey(player)
	local attempts = 0

	while attempts < MAX_RETRIES do
		attempts = attempts + 1

		local success, err = pcall(function()
			self._dataStore:SetAsync(key, session.data)
		end)

		if success then
			session.lastSave = os.time()
			session.dirty = false

			self._logger.Info("Saved player data", {
				player = player.Name,
				dataSize = #game:GetService("HttpService"):JSONEncode(session.data)
			})

			return true
		else
			self._logger.Warn("Failed to save player data", {
				player = player.Name,
				attempt = attempts,
				error = tostring(err)
			})

			if attempts < MAX_RETRIES then
				task.wait(RETRY_DELAY)
			end
		end
	end

	self._logger.Error("Failed to save player data after retries", {player = player.Name})
	return false
end

--[[
	Update player data in memory and mark as dirty
	@param player: Player instance
	@param path: Array of keys to navigate (e.g. {"profile", "coins"})
	@param value: New value to set
]]
function PlayerDataStoreService:UpdatePlayerData(player: Player, path: {string}, value: any)
	local session = self._playerSessions[player.UserId]
	if not session then
		self._logger.Warn("No session for player", {player = player.Name})
		return false
	end

	-- Navigate to the target location
	local current = session.data
	for i = 1, #path - 1 do
		if not current[path[i]] then
			current[path[i]] = {}
		end
		current = current[path[i]]
	end

	-- Set the value
	local key = path[#path]
	current[key] = value

	-- Mark as dirty
	session.dirty = true

	return true
end

--[[
	Get player data from memory
	@param player: Player instance
	@return data: Player data table or nil
]]
function PlayerDataStoreService:GetPlayerData(player: Player)
	local session = self._playerSessions[player.UserId]
	return session and session.data or nil
end

--[[
	Get player session info
	@param player: Player instance
	@return session: Session table or nil
]]
function PlayerDataStoreService:GetSession(player: Player)
	return self._playerSessions[player.UserId]
end

--[[
	Save inventory data for a player
	Called by PlayerInventoryService
]]
function PlayerDataStoreService:SaveInventoryData(player: Player, inventoryData: {hotbar: {}, inventory: {}})
	local session = self._playerSessions[player.UserId]
	if not session then
		return false
	end

	session.data.inventory = inventoryData
	session.dirty = true

	return true
end

--[[
	Get inventory data for a player
	Called by PlayerInventoryService
]]
function PlayerDataStoreService:GetInventoryData(player: Player)
	local session = self._playerSessions[player.UserId]
	if not session then
		return nil
	end

	return session.data.inventory
end

--[[
	Remove player session on disconnect
	@param player: Player instance
]]
function PlayerDataStoreService:OnPlayerRemoving(player: Player)
	-- Save before removing
	self:SavePlayerData(player)

	-- Remove session
	self._playerSessions[player.UserId] = nil

	self._logger.Info("Removed player session", {player = player.Name})
end

--[[
	Save all active players
	Used on server shutdown
]]
function PlayerDataStoreService:SaveAllPlayers()
	self._logger.Info("Saving all player data...")

	local savedCount = 0
	local failedCount = 0

	for userId, session in pairs(self._playerSessions) do
		if session.player and session.player:IsDescendantOf(Players) then
			if self:SavePlayerData(session.player) then
				savedCount = savedCount + 1
			else
				failedCount = failedCount + 1
			end
		end
	end

	self._logger.Info("Save all complete", {
		saved = savedCount,
		failed = failedCount
	})
end

-- Private methods

function PlayerDataStoreService:_getPlayerKey(player: Player)
	return "Player_" .. tostring(player.UserId)
end

function PlayerDataStoreService:_createDefaultData(player: Player)
	local data = {}

	-- Deep copy default data
	for key, value in pairs(DEFAULT_PLAYER_DATA) do
		if type(value) == "table" then
			data[key] = {}
			for k, v in pairs(value) do
				if type(v) == "table" then
					data[key][k] = {}
					for k2, v2 in pairs(v) do
						data[key][k][k2] = v2
					end
				else
					data[key][k] = v
				end
			end
		else
			data[key] = value
		end
	end

	-- Set timestamps
	local now = os.time()
	data.createdAt = now
	data.lastSave = now
	data.lastLogin = now

	return data
end

function PlayerDataStoreService:_validateAndMigrate(data: any, player: Player)
	-- Ensure data is a table
	if type(data) ~= "table" then
		self._logger.Warn("Invalid data type, using default", {player = player.Name})
		return self:_createDefaultData(player)
	end

	-- Check version and migrate if needed
	local version = data.version or 0

	if version < DATA_VERSION then
		self._logger.Info("Migrating player data", {
			player = player.Name,
			from = version,
			to = DATA_VERSION
		})

		data = self:_migrateData(data, version, DATA_VERSION)
		data.version = DATA_VERSION
	end

	-- Ensure all required fields exist
	for key, defaultValue in pairs(DEFAULT_PLAYER_DATA) do
		if data[key] == nil then
			if type(defaultValue) == "table" then
				data[key] = {}
				for k, v in pairs(defaultValue) do
					data[key][k] = v
				end
			else
				data[key] = defaultValue
			end
		end
	end

	return data
end

function PlayerDataStoreService:_migrateData(data: any, fromVersion: number, toVersion: number)
	-- Add migration logic here as the data structure evolves
	-- Example:
	-- if fromVersion < 1 then
	--     data.newField = defaultValue
	-- end

	return data
end

function PlayerDataStoreService:_startAutoSave()
	if self._autoSaveConnection then
		return
	end

	self._autoSaveConnection = task.spawn(function()
		while true do
			task.wait(AUTO_SAVE_INTERVAL)

			-- Save all dirty sessions
			local saveCount = 0
			for userId, session in pairs(self._playerSessions) do
				if session.dirty and session.player and session.player:IsDescendantOf(Players) then
					self:SavePlayerData(session.player)
					saveCount = saveCount + 1
				end
			end

			if saveCount > 0 then
				self._logger.Info("Auto-save completed", {playersSaved = saveCount})
			end
		end
	end)
end

function PlayerDataStoreService:Destroy()
	if self._destroyed then
		return
	end

	-- Stop auto-save
	if self._autoSaveConnection then
		task.cancel(self._autoSaveConnection)
		self._autoSaveConnection = nil
	end

	-- Save all players before destroying
	self:SaveAllPlayers()

	BaseService.Destroy(self)
	self._logger.Info("PlayerDataStoreService destroyed")
end

return PlayerDataStoreService

