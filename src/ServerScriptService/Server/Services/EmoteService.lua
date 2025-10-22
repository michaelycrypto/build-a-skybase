--[[
	EmoteService.lua - Server-side emote handling and validation
	Manages emote network events, rate limiting, and broadcasting
	Based on legacy EmoteService with framework integration
--]]

local EmoteService = {}
local BaseService = require(script.Parent.BaseService)
setmetatable(EmoteService, {__index = BaseService})

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Logger = require(ReplicatedStorage.Shared.Logger)

-- Constants
local EMOTE_COOLDOWN = 1 -- seconds between emotes per player

function EmoteService.new()
	local self = setmetatable(BaseService.new(), EmoteService)

	-- Logger for this service
	self._logger = Logger:CreateContext("EmoteService")

	-- State tracking
	self._playerEmoteCooldowns = {} -- Track last emote time per player
	self._validEmotes = {} -- Will be loaded from IconMapping

	-- Network events
	self._showEmoteEvent = nil
	self._removeEmoteEvent = nil

	return self
end

--[[
	Initialize the EmoteService
--]]
function EmoteService:Init()
	BaseService.Init(self)

	self._logger.Info("Initializing EmoteService")

	-- Load valid emotes from IconMapping
	self:_loadValidEmotes()

	-- Setup network events
	self:_setupNetworkEvents()

	-- Setup player connections
	self:_setupPlayerConnections()

	self._logger.Info("EmoteService initialized successfully")
end

--[[
	Start the EmoteService
--]]
function EmoteService:Start()

	self._logger.Info("Starting EmoteService")

	-- Start cleanup task
	self:_startCleanupTask()

	self._logger.Info("EmoteService started successfully")
end

--[[
	Cleanup when service is destroyed
--]]
function EmoteService:Destroy()
	BaseService.Destroy(self)

	self._logger.Info("Destroying EmoteService")

	-- Clear all data
	self._playerEmoteCooldowns = {}
end

-- ============================
-- PRIVATE SETUP METHODS
-- ============================

--[[
	Load valid emotes from IconMapping
--]]
function EmoteService:_loadValidEmotes()
	-- Try to load from IconMapping, fallback to default emotes
	local success, IconMapping = pcall(require, ReplicatedStorage.Shared.IconMapping)
	if success and IconMapping and IconMapping.Emotes then
		self._validEmotes = IconMapping.Emotes
		self._logger.Info("Loaded emotes from IconMapping", {
			emoteCount = self:_countTable(self._validEmotes)
		})
	else
		-- Fallback to default emotes
		self._validEmotes = {
			wave = true,
			laugh = true,
			dance = true,
			thumbsUp = true,
			point = true,
			cheer = true
		}
		self._logger.Warn("IconMapping not found, using default emotes", {
			emoteCount = self:_countTable(self._validEmotes)
		})
	end
end

--[[
	Setup network events
--]]
function EmoteService:_setupNetworkEvents()
	local network = self:GetNetwork()

	-- Events for client notifications
	self._showEmoteEvent = network:DefineEvent("ShowEmote", {"Instance", "string"})
	self._removeEmoteEvent = network:DefineEvent("RemoveEmote", {"Instance"})

	self._logger.Info("Network events configured")
end

--[[
	Setup player connection handlers
--]]
function EmoteService:_setupPlayerConnections()
	-- Clean up cooldowns when players leave
	Players.PlayerRemoving:Connect(function(player)
		self._playerEmoteCooldowns[player] = nil
		self._logger.Debug("Cleaned up emote cooldowns for leaving player", {
			playerName = player.Name
		})
	end)

	self._logger.Info("Player connection handlers setup")
end

--[[
	Start periodic cleanup task
--]]
function EmoteService:_startCleanupTask()
	task.spawn(function()
		while not self:IsDestroyed() do
			task.wait(60) -- Run every minute
			self:CleanupCooldowns()
		end
	end)

	self._logger.Info("Cleanup task started")
end

--[[
	Utility to count table entries
--]]
function EmoteService:_countTable(t)
	local count = 0
	for _ in pairs(t) do
		count = count + 1
	end
	return count
end

-- ============================
-- PUBLIC EMOTE HANDLING
-- ============================

--[[
	Handle emote play request from client
--]]
function EmoteService:HandlePlayEmote(player, emoteName)
	-- Validate input
	if not self:ValidateEmoteRequest(player, emoteName) then
		return false
	end

	-- Check rate limiting
	if not self:CheckRateLimit(player) then
		self._logger.Warn("Rate limit exceeded", {
			playerName = player.Name,
			playerId = player.UserId,
			emoteName = emoteName
		})
		return false
	end

	-- Update cooldown
	self._playerEmoteCooldowns[player] = tick()

	-- Broadcast emote to all other players
	self:BroadcastEmote(player, emoteName)

	-- Log emote usage
	self._logger.Info("Player used emote", {
		playerName = player.Name,
		playerId = player.UserId,
		emoteName = emoteName
	})

	return true
end

--[[
	Validate emote request
--]]
function EmoteService:ValidateEmoteRequest(player, emoteName)
	-- Check if player exists and is valid
	if not player or not player.Parent then
		self._logger.Warn("Invalid player in emote request")
		return false
	end

	-- Check if player has a character
	if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then
		self._logger.Warn("Player has no character", {
			playerName = player.Name,
			playerId = player.UserId
		})
		return false
	end

	-- Validate emote name
	if type(emoteName) ~= "string" or not self._validEmotes[emoteName] then
		self._logger.Warn("Invalid emote name", {
			playerName = player.Name,
			playerId = player.UserId,
			emoteName = tostring(emoteName)
		})
		return false
	end

	return true
end

--[[
	Check rate limiting for player
--]]
function EmoteService:CheckRateLimit(player)
	local lastEmoteTime = self._playerEmoteCooldowns[player]
	if not lastEmoteTime then
		return true -- First emote
	end

	local timeSinceLastEmote = tick() - lastEmoteTime
	return timeSinceLastEmote >= EMOTE_COOLDOWN
end

--[[
	Broadcast emote to all other players
--]]
function EmoteService:BroadcastEmote(sourcePlayer, emoteName)
	-- Send to all players except the source player
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= sourcePlayer then
			self._showEmoteEvent:Fire(player, sourcePlayer, emoteName)
		end
	end

	self._logger.Debug("Broadcasted emote", {
		sourcePlayer = sourcePlayer.Name,
		emoteName = emoteName,
		recipientCount = #Players:GetPlayers() - 1
	})
end

--[[
	Force remove emote from a player (admin function)
--]]
function EmoteService:ForceRemoveEmote(targetPlayer)
	if not targetPlayer or not targetPlayer.Parent then
		return false
	end

	-- Broadcast emote removal to all clients
	for _, player in pairs(Players:GetPlayers()) do
		self._removeEmoteEvent:Fire(player, targetPlayer)
	end

	self._logger.Info("Force removed emote", {
		playerName = targetPlayer.Name,
		playerId = targetPlayer.UserId
	})

	return true
end

--[[
	Remove emote for a specific player (called when they request removal)
--]]
function EmoteService:RemoveEmoteForPlayer(sourcePlayer)
	if not sourcePlayer or not sourcePlayer.Parent then
		return false
	end

	-- Broadcast emote removal to all other players
	for _, player in pairs(Players:GetPlayers()) do
		if player ~= sourcePlayer then
			self._removeEmoteEvent:Fire(player, sourcePlayer)
		end
	end

	self._logger.Debug("Removed emote for player", {
		playerName = sourcePlayer.Name
	})

	return true
end

-- ============================
-- STATISTICS AND MAINTENANCE
-- ============================

--[[
	Get emote statistics
--]]
function EmoteService:GetEmoteStats()
	local stats = {
		totalPlayersWithCooldowns = 0,
		averageCooldownRemaining = 0,
		validEmoteCount = self:_countTable(self._validEmotes)
	}

	local currentTime = tick()
	local totalCooldownTime = 0
	local activeCooldowns = 0

	for player, lastEmoteTime in pairs(self._playerEmoteCooldowns) do
		if player.Parent then -- Player still in game
			stats.totalPlayersWithCooldowns = stats.totalPlayersWithCooldowns + 1

			local timeSinceEmote = currentTime - lastEmoteTime
			if timeSinceEmote < EMOTE_COOLDOWN then
				activeCooldowns = activeCooldowns + 1
				totalCooldownTime = totalCooldownTime + (EMOTE_COOLDOWN - timeSinceEmote)
			end
		end
	end

	if activeCooldowns > 0 then
		stats.averageCooldownRemaining = totalCooldownTime / activeCooldowns
	end

	return stats
end

--[[
	Clean up expired cooldowns (maintenance function)
--]]
function EmoteService:CleanupCooldowns()
	local currentTime = tick()
	local cleanedUp = 0

	for player, lastEmoteTime in pairs(self._playerEmoteCooldowns) do
		-- Remove if player left or cooldown expired long ago
		if not player.Parent or (currentTime - lastEmoteTime) > (EMOTE_COOLDOWN * 10) then
			self._playerEmoteCooldowns[player] = nil
			cleanedUp = cleanedUp + 1
		end
	end

	if cleanedUp > 0 then
		self._logger.Info("Cleaned up expired cooldowns", {
			cleanedUpCount = cleanedUp
		})
	end
end

--[[
	Get valid emotes list
--]]
function EmoteService:GetValidEmotes()
	return self._validEmotes
end

--[[
	Add a new valid emote (admin function)
--]]
function EmoteService:AddValidEmote(emoteName)
	if type(emoteName) ~= "string" then
		return false
	end

	self._validEmotes[emoteName] = true
	self._logger.Info("Added valid emote", {
		emoteName = emoteName
	})

	return true
end

--[[
	Remove a valid emote (admin function)
--]]
function EmoteService:RemoveValidEmote(emoteName)
	if type(emoteName) ~= "string" or not self._validEmotes[emoteName] then
		return false
	end

	self._validEmotes[emoteName] = nil
	self._logger.Info("Removed valid emote", {
		emoteName = emoteName
	})

	return true
end

return EmoteService