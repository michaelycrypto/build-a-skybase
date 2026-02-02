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

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Config = require(game.ReplicatedStorage.Shared.Config)

local PlayerDataStoreService = setmetatable({}, BaseService)
PlayerDataStoreService.__index = PlayerDataStoreService

-- DataStore configuration
local DATA_STORE_CONFIG = Config.DataStore or error("GameConfig.DataStore table is missing")
local PLAYER_DATA_CONFIG = DATA_STORE_CONFIG.PlayerData or error("GameConfig.DataStore.PlayerData is missing")

local function requireConfigValue(sourceTable, key: string, tableName: string)
	local value = sourceTable[key]
	if value == nil then
		error(string.format("%s.%s is missing", tableName, key))
	end
	return value
end

local DATA_STORE_NAME = requireConfigValue(PLAYER_DATA_CONFIG, "DataStoreVersion", "GameConfig.DataStore.PlayerData")
local DATA_VERSION = requireConfigValue(PLAYER_DATA_CONFIG, "SchemaVersion", "GameConfig.DataStore.PlayerData")

-- Retry configuration for DataStore operations
local MAX_RETRIES = 3
local RETRY_DELAY = 1

-- Auto-save configuration
local AUTO_SAVE_INTERVAL = requireConfigValue(PLAYER_DATA_CONFIG, "AutoSaveInterval", "GameConfig.DataStore.PlayerData")

-- Session locking to prevent duplication exploits
local SESSION_LOCK_TIMEOUT = 15 -- Seconds before a lock is considered stale for non-teleport joins
local SERVER_ID = game.JobId ~= "" and game.JobId or tostring(os.time()) .. "_" .. tostring(math.random(1000, 9999))
local PLACE_ID = game.PlaceId

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local clone = {}
	for key, child in pairs(value) do
		clone[key] = deepCopy(child)
	end

	return clone
end

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

	-- Equipped armor (helmet, chestplate, leggings, boots) - synced with ArmorEquipService
	equippedArmor = {
		helmet = nil,
		chestplate = nil,
		leggings = nil,
		boots = nil
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

	-- Tutorial/onboarding progress
	tutorial = {
		completed = false,           -- True when all steps done
		skipped = false,             -- True if player skipped
		currentStep = "welcome",     -- Current active step ID
		completedSteps = {},         -- {[stepId] = timestamp}
		startedAt = 0,               -- When tutorial started
		completedAt = 0,             -- When tutorial finished
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
	self._autoSaveConnection = nil

	return self
end

function PlayerDataStoreService:Init()
	if self._initialized then
		return
	end

	-- Initialize DataStore
	local success, err = pcall(function()
		self._dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)
	end)

	if not success then
		self._logger.Error("Failed to initialize DataStore", {error = tostring(err)})
		self._logger.Warn("Running in local mode - data will not persist!")
	end

	BaseService.Init(self)
	self._logger.Debug("PlayerDataStoreService initialized")
end

function PlayerDataStoreService:Start()
	if self._started then
		return
	end

	self._logger.Debug("Starting PlayerDataStoreService...")

	-- Start auto-save loop
	self:_startAutoSave()

	-- Server shutdown saving is centralized in Bootstrap; avoid duplicate saves here

	BaseService.Start(self)
	self._logger.Debug("PlayerDataStoreService started")
end

--[[
	Load player data from DataStore with session locking (prevents duplication)
	@param player: Player instance
	@return data: Player data table or nil if failed
]]
function PlayerDataStoreService:LoadPlayerData(player: Player)
	if not self._dataStore then
		self._logger.Warn("DataStore not available - using default data", {player = player.Name})
		return self:_createDefaultData(player)
	end

	-- Check if this is a teleport from the same game (seamless handoff)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	local sourcePlace = joinData and joinData.SourcePlaceId
	local isSameGameTeleport = teleportData ~= nil and (sourcePlace == PLACE_ID or sourcePlace == nil)

	local key = self:_getPlayerKey(player)
	local attempts = 0
	local loadedData = nil
	local sessionAcquired = false

	while attempts < MAX_RETRIES and not sessionAcquired do
		attempts = attempts + 1

		local success, result = pcall(function()
			return self._dataStore:UpdateAsync(key, function(oldData)
				local now = os.time()

				-- Check if session is locked by another server
				if oldData and oldData.sessionLock then
					local lock = oldData.sessionLock
					local lockAge = now - (lock.timestamp or 0)

					-- Same server = always ok
					if lock.serverId ~= SERVER_ID then
						-- Same-game teleport = always allow takeover (seamless)
						if isSameGameTeleport then
							self._logger.Info("Seamless teleport handoff", {
								player = player.Name,
								previousServer = lock.serverId,
								lockAge = lockAge
							})
							-- Allow immediate takeover for same-game teleports
						-- External join with recent lock = block
						elseif lockAge < SESSION_LOCK_TIMEOUT then
							self._logger.Warn("Session locked by another server", {
								player = player.Name,
								lockServer = lock.serverId,
								lockAge = lockAge
							})
							return nil -- Don't update, signal locked
						end
						-- Stale lock (> timeout) = allow takeover
					end
				end

				-- Create or use existing data
				local data = oldData
				if not data then
					data = self:_createDefaultData(player)
				else
					data = self:_validateAndMigrate(data, player)
				end

				-- Acquire session lock
				data.sessionLock = {
					serverId = SERVER_ID,
					timestamp = now,
					playerName = player.Name,
					placeId = PLACE_ID
				}
				data.lastLogin = now

				return data
			end)
		end)

		if success then
			if result then
				-- Session acquired successfully
				loadedData = result
				sessionAcquired = true

				self._playerSessions[player.UserId] = {
					player = player,
					data = result,
					lastSave = os.time(),
					dirty = false,
					sessionLockId = SERVER_ID
				}

				self._logger.Debug("Loaded player data", {
					player = player.Name,
					level = result.profile and result.profile.level or 1,
					wasTeleport = isSameGameTeleport
				})
			else
				-- Session locked, wait and retry
				self._logger.Warn("Session locked, retrying...", {
					player = player.Name,
					attempt = attempts
				})
				if attempts < MAX_RETRIES then
					task.wait(1)
				end
			end
		else
			self._logger.Warn("Failed to load player data", {
				player = player.Name,
				attempt = attempts,
				error = tostring(result)
			})
			if attempts < MAX_RETRIES then
				task.wait(RETRY_DELAY)
			end
		end
	end

	if not sessionAcquired then
		self._logger.Error("Failed to acquire session lock", {player = player.Name})
		task.defer(function()
			if player and player:IsDescendantOf(game) then
				player:Kick("Your data is being used on another server. Please wait a moment and rejoin.")
			end
		end)
		return nil
	end

	return loadedData
end

--[[
	Save player data to DataStore with session lock verification (prevents duplication)
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

	local key = self:_getPlayerKey(player)
	local attempts = 0
	local saveSucceeded = false

	while attempts < MAX_RETRIES and not saveSucceeded do
		attempts = attempts + 1

		local success, result = pcall(function()
			return self._dataStore:UpdateAsync(key, function(oldData)
				local now = os.time()

				-- Verify we still own the session lock
				if oldData and oldData.sessionLock then
					local lock = oldData.sessionLock
					if lock.serverId ~= SERVER_ID then
						-- Another server took the lock - don't save (prevents dupe)
						self._logger.Warn("Session lock lost to another server, aborting save", {
							player = player.Name,
							ourServer = SERVER_ID,
							lockServer = lock.serverId
						})
						return nil -- Abort save
					end
				end

				-- Update session data
				local dataToSave = session.data
				dataToSave.lastSave = now
				dataToSave.sessionLock = {
					serverId = SERVER_ID,
					timestamp = now,
					playerName = player.Name
				}

				return dataToSave
			end)
		end)

		if success then
			if result then
				session.lastSave = os.time()
				session.dirty = false
				saveSucceeded = true

				self._logger.Debug("Saved player data with lock", {
					player = player.Name,
					serverId = SERVER_ID
				})
			else
				-- Lock was taken by another server
				self._logger.Warn("Save aborted - session lock lost", {player = player.Name})
				break -- Don't retry, lock is gone
			end
		else
			self._logger.Warn("Failed to save player data", {
				player = player.Name,
				attempt = attempts,
				error = tostring(result)
			})
			if attempts < MAX_RETRIES then
				task.wait(RETRY_DELAY)
			end
		end
	end

	if not saveSucceeded then
		self._logger.Error("Failed to save player data", {player = player.Name})
	end

	return saveSucceeded
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
	Save equipped armor data for a player
	Called by PlayerService when saving player data
]]
function PlayerDataStoreService:SaveArmorData(player: Player, armorData: {helmet: number?, chestplate: number?, leggings: number?, boots: number?})
	local session = self._playerSessions[player.UserId]
	if not session then
		return false
	end

	session.data.equippedArmor = armorData
	session.dirty = true

	return true
end

--[[
	Get equipped armor data for a player
	Called by PlayerService when loading player data
]]
function PlayerDataStoreService:GetArmorData(player: Player)
	local session = self._playerSessions[player.UserId]
	if not session then
		return nil
	end

	return session.data.equippedArmor
end

--[[
	Save and release lock before teleport (ensures fast handoff)
	@param player: Player instance
	@return success: boolean
]]
function PlayerDataStoreService:SaveAndReleaseLock(player: Player)
	local session = self._playerSessions[player.UserId]
	if not session or not session.data then
		return false
	end

	if not self._dataStore then
		return false
	end

	local key = self:_getPlayerKey(player)
	local success = pcall(function()
		self._dataStore:UpdateAsync(key, function(oldData)
			if not oldData then return nil end

			-- Only save and release if we own the lock
			if oldData.sessionLock and oldData.sessionLock.serverId == SERVER_ID then
				-- Save current data
				local dataToSave = session.data
				dataToSave.lastSave = os.time()
				-- Clear lock for fast handoff
				dataToSave.sessionLock = nil
				self._logger.Info("Saved and released lock for teleport", {player = player.Name})
				return dataToSave
			end

			return oldData
		end)
	end)

	return success
end

--[[
	Remove player session on disconnect and release session lock
	@param player: Player instance
]]
function PlayerDataStoreService:OnPlayerRemoving(player: Player)
	local session = self._playerSessions[player.UserId]

	-- Release session lock in DataStore
	if self._dataStore and session then
		local key = self:_getPlayerKey(player)
		pcall(function()
			self._dataStore:UpdateAsync(key, function(oldData)
				if not oldData then return nil end

				-- Only release lock if we own it
				if oldData.sessionLock and oldData.sessionLock.serverId == SERVER_ID then
					oldData.sessionLock = nil
					self._logger.Debug("Released session lock", {player = player.Name})
				end

				return oldData
			end)
		end)
	end

	-- Remove local session
	self._playerSessions[player.UserId] = nil
	self._logger.Debug("Removed player session", {player = player.Name})
end

--[[
	Save all active players
	Used on server shutdown
]]
function PlayerDataStoreService:SaveAllPlayers()
	self._logger.Info("Saving all player data...")

	local savedCount = 0
	local failedCount = 0

	for _userId, session in pairs(self._playerSessions) do
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

function PlayerDataStoreService:_createDefaultData(_player: Player)
	local data = deepCopy(DEFAULT_PLAYER_DATA)

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

function PlayerDataStoreService:_migrateData(data: any, _fromVersion: number, _toVersion: number)
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
			for _userId, session in pairs(self._playerSessions) do
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

	-- Saving on shutdown is handled by Bootstrap; avoid duplicate saves here

	BaseService.Destroy(self)
	self._logger.Info("PlayerDataStoreService destroyed")
end

return PlayerDataStoreService

