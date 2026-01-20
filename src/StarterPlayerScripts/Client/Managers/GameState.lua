--[[
	GameState.lua - Enhanced Reactive State Management System
	Handles game state with precision, events, and dot-notation path support
--]]

local GameState = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import shared modules
local Config = require(ReplicatedStorage.Shared.Config)

-- Internal state
local state = {}
local listeners = {}
local updateQueue = {}
local isProcessingUpdates = false

-- Constants
local MAX_QUEUE_SIZE = 100
local UPDATE_INTERVAL = 0.1 -- Process updates every 100ms for better performance

--[[
	Initialize the GameState with default values
--]]
local function initialize()
	state = {
		playerData = {
			coins = 0,
			gems = 0, -- Premium currency
			level = 1,
			experience = 0,
			inventory = {},
			effects = {},
			settings = {
				soundEnabled = true,
				musicEnabled = true,
				graphicsQuality = "Medium"
			},
			-- Player progression stats
			stats = {
				totalCoinsEarned = 0,
				totalGemsEarned = 0,
				totalExperienceEarned = 0,
				highestLevel = 1,
				playtimeSeconds = 0,
				sessionsPlayed = 0,
				lastLoginTime = 0
			}
		},
		ui = {
			currentScreen = nil,
			notifications = {},
			isLoading = false,
			viewport = {
				size = Vector2.new(1024, 768),
				aspectRatio = 1.33,
				deviceType = "Desktop"
			}
		},
		game = {
			isPlaying = false,
			isPaused = true,
			startTime = 0,
			sessionTime = 0,
			status = "loading",
			lastStateChange = 0,
			worldState = {}
		},
		network = {
			isConnected = false,
			latency = 0,
			lastPing = 0
		}
	}

	-- Start update processing
	RunService.Heartbeat:Connect(processUpdateQueue)
end

--[[
	Parse a dot-notation path into table keys
	@param path: string - Dot-notation path (e.g., "playerData.coins")
	@return: table - Array of keys
--]]
local function parsePath(path)
	local keys = {}
	for key in string.gmatch(path, "[^%.]+") do
		table.insert(keys, key)
	end
	return keys
end

--[[
	Get a value from state using dot-notation path
	@param path: string - Dot-notation path
	@return: any - The value at the path
--]]
function GameState:Get(path)
	local keys = parsePath(path)
	local current = state

	for _, key in ipairs(keys) do
		if type(current) ~= "table" or current[key] == nil then
			return nil
		end
		current = current[key]
	end

	return current
end

--[[
	Set a value in state using dot-notation path with batching
	@param path: string - Dot-notation path
	@param value: any - Value to set
	@param immediate: boolean - Whether to update immediately (default: false)
--]]
function GameState:Set(path, value, immediate)
	-- Add to update queue for batch processing
	table.insert(updateQueue, {
		path = path,
		value = value,
		timestamp = tick()
	})

	-- Limit queue size to prevent memory issues
	while #updateQueue > MAX_QUEUE_SIZE do
		table.remove(updateQueue, 1)
	end

	-- Process immediately if requested
	if immediate then
		self:FlushUpdates()
	end
end

--[[
	Process the update queue in batches for better performance
--]]
function processUpdateQueue()
	if isProcessingUpdates or #updateQueue == 0 then
		return
	end

	isProcessingUpdates = true

	-- Process all queued updates
	local processedPaths = {}

	while #updateQueue > 0 do
		local update = table.remove(updateQueue, 1)

		-- Apply the update
		local keys = parsePath(update.path)
		local current = state

		-- Navigate to parent object
		for i = 1, #keys - 1 do
			local key = keys[i]
			if type(current[key]) ~= "table" then
				current[key] = {}
			end
			current = current[key]
		end

		-- Set the final value
		local finalKey = keys[#keys]
		local oldValue = current[finalKey]
		current[finalKey] = update.value

		-- Track that this path was updated
		if not processedPaths[update.path] then
			processedPaths[update.path] = {
				oldValue = oldValue,
				newValue = update.value
			}
		else
			-- Update the new value if path was processed multiple times
			processedPaths[update.path].newValue = update.value
		end
	end

	-- Fire events for all processed paths
	for path, changes in pairs(processedPaths) do
		GameState:_fireListeners(path, changes.newValue, changes.oldValue)
	end

	isProcessingUpdates = false
end

--[[
	Immediately flush all pending updates
--]]
function GameState:FlushUpdates()
	if #updateQueue > 0 then
		processUpdateQueue()
	end
end

--[[
	=== WORLD SESSION HELPERS ===
--]]

function GameState:GetWorldState()
	return self:Get("game.worldState") or {}
end

function GameState:GetWorldStatus()
	return self:Get("game.status") or "loading"
end

function GameState:IsPlaying()
	return self:Get("game.isPlaying") == true
end

function GameState:IsPaused()
	return self:Get("game.isPaused") == true
end

function GameState:ApplyWorldState(worldState)
	worldState = worldState or {}

	local now = tick()
	local status = worldState.status or (worldState.isReady and "ready" or "loading")
	local isReady = worldState.isReady == true or status == "ready"
	local isPaused = worldState.isPaused == true or status ~= "ready"

	self:Set("game.worldState", worldState)
	self:Set("game.status", status)
	self:Set("game.isPlaying", isReady)
	self:Set("game.isPaused", isPaused)
	self:Set("game.lastStateChange", now)

	if isReady then
		local startTime = self:Get("game.startTime") or 0
		if startTime == 0 then
			self:Set("game.startTime", now)
			startTime = now
		end
		self:Set("game.sessionTime", math.max(0, now - startTime))
	else
		self:Set("game.lastPauseTime", now)
	end
end

--[[
	Register a listener for property changes
	@param path: string - Dot-notation path to listen to
	@param callback: function - Callback function (newValue, oldValue, path)
	@return: function - Disconnect function
--]]
function GameState:OnPropertyChanged(path, callback)
	assert(type(path) == "string", "Path must be a string")
	assert(type(callback) == "function", "Callback must be a function")

	-- Initialize listeners table for this path if it doesn't exist
	if not listeners[path] then
		listeners[path] = {}
	end

	-- Generate unique listener ID
	local listenerId = tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
	listeners[path][listenerId] = callback

	-- Return disconnect function
	return function()
		if listeners[path] then
			listeners[path][listenerId] = nil
		end
	end
end

--[[
	Fire listeners for a given path
	@param path: string - Path that changed
	@param newValue: any - New value
	@param oldValue: any - Previous value
--]]
function GameState:_fireListeners(path, newValue, oldValue)
	-- Fire exact path listeners
	if listeners[path] then
		for _, callback in pairs(listeners[path]) do
			local success, error = pcall(callback, newValue, oldValue, path)
			if not success then
				warn("GameState: Error in listener for", path, ":", error)
			end
		end
	end

	-- Fire parent path listeners (for nested changes)
	local keys = parsePath(path)
	for i = 1, #keys - 1 do
		local parentPath = table.concat(keys, ".", 1, i)
		if listeners[parentPath] then
			local parentValue = self:Get(parentPath)
			for _, callback in pairs(listeners[parentPath]) do
				local success, error = pcall(callback, parentValue, nil, parentPath)
				if not success then
					warn("GameState: Error in parent listener for", parentPath, ":", error)
				end
			end
		end
	end
end

-- Removed duplicate OnPropertyChanged method - using the one above

-- Removed duplicate UpdatePlayerData method - using the one below with field-by-field updates

--[[
	Get a player data value with default fallback
	@param key: string - Key to get
	@param default: any - Default value if key doesn't exist
	@return: any - The value or default
--]]
function GameState:GetPlayerData(key, default)
	local path = "playerData." .. key
	local value = self:Get(path)
	return value ~= nil and value or default
end

--[[
	Set a player data value
	@param key: string - Key to set
	@param value: any - Value to set
--]]
function GameState:SetPlayerData(key, value)
	local path = "playerData." .. key
	self:Set(path, value)
end

--[[
	Increment a numeric player data value
	@param key: string - Key to increment
	@param amount: number - Amount to increment by (default: 1)
--]]
function GameState:IncrementPlayerData(key, amount)
	amount = amount or 1
	local currentValue = self:GetPlayerData(key, 0)
	if type(currentValue) == "number" then
		self:SetPlayerData(key, currentValue + amount)
	else
		warn("GameState: Cannot increment non-numeric value:", key)
	end
end

--[[
	=== STAT MANAGEMENT FUNCTIONS ===
--]]

--[[
	Update complete player data from server
	@param newData: table - New player data from server
--]]
function GameState:UpdatePlayerData(newData)
	if not newData then return end

	-- Update each field individually to trigger proper events
	for key, value in pairs(newData) do
		if key == "stats" and type(value) == "table" then
			-- Update stats individually
			for statKey, statValue in pairs(value) do
				self:Set("playerData.stats." .. statKey, statValue)
			end
		else
			self:SetPlayerData(key, value)
		end
	end
end

--[[
	Update currencies from server
	@param currencies: table - Currency data from server
--]]
function GameState:UpdateCurrencies(currencies)
	if not currencies then return end

	-- Update coins
	if currencies.coins ~= nil then
		self:SetPlayerData("coins", currencies.coins)
	end

	-- Update gems
	if currencies.gems ~= nil then
		self:SetPlayerData("gems", currencies.gems)
	end
end

--[[
	Update comprehensive stats from server
	@param statsData: table - Stats data from server
--]]
function GameState:UpdateStats(statsData)
	if not statsData then return end

	-- Update core stats
	if statsData.coins ~= nil then
		self:SetPlayerData("coins", statsData.coins)
	end
	if statsData.gems ~= nil then
		self:SetPlayerData("gems", statsData.gems)
	end
	if statsData.level ~= nil then
		self:SetPlayerData("level", statsData.level)
	end
	if statsData.experience ~= nil then
		self:SetPlayerData("experience", statsData.experience)
	end

	-- Update progression stats
	local statFields = {
		"totalCoinsEarned", "totalGemsEarned", "totalExperienceEarned",
		"highestLevel", "playtimeSeconds", "sessionsPlayed", "lastLoginTime"
	}

	for _, field in ipairs(statFields) do
		if statsData[field] ~= nil then
			self:Set("playerData.stats." .. field, statsData[field])
		end
	end

	print("GameState: Comprehensive stats updated")
end

--[[
	Get current coins
	@return: number - Current coins
--]]
function GameState:GetCoins()
	return self:GetPlayerData("coins", 0)
end

--[[
	Update coins
	@param coins: number - New coin amount
--]]
function GameState:UpdateCoins(coins)
	self:SetPlayerData("coins", coins)
end

--[[
	Get current gems
	@return: number - Current gems
--]]
function GameState:GetGems()
	return self:GetPlayerData("gems", 0)
end

--[[
	Update gems
	@param gems: number - New gem amount
--]]
function GameState:UpdateGems(gems)
	self:SetPlayerData("gems", gems)
end

--[[
	Get current level
	@return: number - Current level
--]]
function GameState:GetLevel()
	return self:GetPlayerData("level", 1)
end

--[[
	Update level
	@param level: number - New level
--]]
function GameState:UpdateLevel(level)
	self:SetPlayerData("level", level)
end

--[[
	Get current experience
	@return: number - Current experience
--]]
function GameState:GetExperience()
	return self:GetPlayerData("experience", 0)
end

--[[
	Update experience
	@param experience: number - New experience amount
--]]
function GameState:UpdateExperience(experience)
	self:SetPlayerData("experience", experience)
end

--[[
	Get level progress information
	@return: table - Level progress data
--]]
function GameState:GetLevelProgress()
	local level = self:GetLevel()
	local experience = self:GetExperience()

	-- Calculate based on Config stat system
	local baseXP = Config.STATS and Config.STATS.levelUp.baseXP or 100
	local multiplier = Config.STATS and Config.STATS.levelUp.multiplier or 1.5
	local maxLevel = Config.STATS and Config.STATS.levelUp.maxLevel or 100

	if level >= maxLevel then
		return {current = 0, needed = 0, percent = 100}
	end

	-- Calculate experience used for current level
	local expUsed = 0
	local requiredXP = baseXP

	for i = 2, level do
		expUsed = expUsed + requiredXP
		requiredXP = math.floor(requiredXP * multiplier)
	end

	local currentLevelExp = experience - expUsed
	local neededForNext = requiredXP
	local percent = math.floor((currentLevelExp / neededForNext) * 100)

	return {
		current = currentLevelExp,
		needed = neededForNext,
		percent = math.min(percent, 100)
	}
end

--[[
	Get player progression stats
	@return: table - Progression stats
--]]
function GameState:GetProgressionStats()
	return self:Get("playerData.stats") or {}
end

--[[
	Get formatted playtime string
	@return: string - Formatted playtime
--]]
function GameState:GetFormattedPlaytime()
	local playtimeSeconds = self:Get("playerData.stats.playtimeSeconds") or 0
	local hours = math.floor(playtimeSeconds / 3600)
	local minutes = math.floor((playtimeSeconds % 3600) / 60)
	local seconds = playtimeSeconds % 60

	if hours > 0 then
		return string.format("%dh %dm %ds", hours, minutes, seconds)
	elseif minutes > 0 then
		return string.format("%dm %ds", minutes, seconds)
	else
		return string.format("%ds", seconds)
	end
end

--[[
	Get comprehensive player summary
	@return: table - Complete player summary
--]]
function GameState:GetPlayerSummary()
	local levelProgress = self:GetLevelProgress()
	local stats = self:GetProgressionStats()

	return {
		-- Core stats
		coins = self:GetCoins(),
		gems = self:GetGems(),
		level = self:GetLevel(),
		experience = self:GetExperience(),

		-- Progress
		levelProgress = levelProgress,

		-- Lifetime stats
		totalCoinsEarned = stats.totalCoinsEarned or 0,
		totalGemsEarned = stats.totalGemsEarned or 0,
		totalExperienceEarned = stats.totalExperienceEarned or 0,
		highestLevel = stats.highestLevel or 1,

		-- Session info
		playtime = self:GetFormattedPlaytime(),
		playtimeSeconds = stats.playtimeSeconds or 0,
		sessionsPlayed = stats.sessionsPlayed or 0,
		lastLoginTime = stats.lastLoginTime or 0
	}
end

--[[
	Get current UI state
	@return: table - Current UI state
--]]
function GameState:GetUIState()
	return self:Get("ui") or {}
end

--[[
	Set UI state property
	@param key: string - UI property key
	@param value: any - Value to set
--]]
function GameState:SetUIState(key, value)
	local path = "ui." .. key
	self:Set(path, value)
end

--[[
	Get current game state
	@return: table - Current game state
--]]
function GameState:GetGameState()
	return self:Get("game") or {}
end

--[[
	Set game state property
	@param key: string - Game property key
	@param value: any - Value to set
--]]
function GameState:SetGameState(key, value)
	local path = "game." .. key
	self:Set(path, value)
end

--[[
	Get network state
	@return: table - Current network state
--]]
function GameState:GetNetworkState()
	return self:Get("network") or {}
end

--[[
	Set network state property
	@param key: string - Network property key
	@param value: any - Value to set
--]]
function GameState:SetNetworkState(key, value)
	local path = "network." .. key
	self:Set(path, value)
end

--[[
	Get the entire state tree (for debugging)
	@return: table - Complete state tree
--]]
function GameState:GetFullState()
	return state
end

--[[
	Reset the entire state to defaults
--]]
function GameState:Reset()
	-- Clear all listeners
	listeners = {}

	-- Clear update queue
	updateQueue = {}

	-- Reinitialize state
	initialize()

	print("GameState: State reset to defaults")
end

--[[
	Get state statistics for debugging
	@return: table - Statistics about the state
--]]
function GameState:GetStats()
	local function countNodes(tbl, depth)
		depth = depth or 0
		local count = 0
		local maxDepth = depth

		for _, value in pairs(tbl) do
			count = count + 1
			if type(value) == "table" then
				local subCount, subDepth = countNodes(value, depth + 1)
				count = count + subCount
				maxDepth = math.max(maxDepth, subDepth)
			end
		end

		return count, maxDepth
	end

	local nodeCount, maxDepth = countNodes(state)
	local listenerCount = 0

	for _, pathListeners in pairs(listeners) do
		for _ in pairs(pathListeners) do
			listenerCount = listenerCount + 1
		end
	end

	return {
		totalNodes = nodeCount,
		maxDepth = maxDepth,
		totalListeners = listenerCount,
		queuedUpdates = #updateQueue,
		memoryUsage = gcinfo() -- Rough memory usage in KB
	}
end

--[[
	Validate state integrity (for debugging)
	@return: boolean, string - Success status and error message if any
--]]
function GameState:ValidateState()
	local function validateNode(node, path)
		if type(node) ~= "table" then
			return true, nil
		end

		for key, value in pairs(node) do
			local newPath = path == "" and key or (path .. "." .. key)

			-- Check for circular references
			local seen = {}
			local function checkCircular(obj, objPath)
				if type(obj) == "table" then
					if seen[obj] then
						return false, "Circular reference detected at " .. objPath
					end
					seen[obj] = true

					for k, v in pairs(obj) do
						local success, err = checkCircular(v, objPath .. "." .. k)
						if not success then
							return false, err
						end
					end
				end
				return true, nil
			end

			local success, err = checkCircular(value, newPath)
			if not success then
				return false, err
			end

			-- Recursively validate
			local subSuccess, subErr = validateNode(value, newPath)
			if not subSuccess then
				return false, subErr
			end
		end

		return true, nil
	end

	return validateNode(state, "")
end

-- Initialize the state system
initialize()

return GameState