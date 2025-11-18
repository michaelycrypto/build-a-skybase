--[[
	LobbyWorldTeleportService.lua

	Lobby-only service that teleports players to their world instances.
	- Reuses existing active instances via MemoryStore registry
	- Creates new reserved servers when needed
	- Passes TeleportData to world servers for ownership/world loading
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

-- Configure with your place IDs
local LOBBY_PLACE_ID = 139848475014328
local WORLDS_PLACE_ID = 111115817294342

local REGISTRY_NAME = "ActiveWorlds_v1"
local REGISTRY_TTL = 90

local LobbyWorldTeleportService = setmetatable({}, BaseService)
LobbyWorldTeleportService.__index = LobbyWorldTeleportService

function LobbyWorldTeleportService.new()
	local self = setmetatable(BaseService.new(), LobbyWorldTeleportService)
	self._logger = Logger:CreateContext("LobbyWorldTeleport")
	self._map = nil
	return self
end

function LobbyWorldTeleportService:Init()
	if self._initialized then return end
	-- Use SortedMap for registry (simple key-value; TTL supported)
	self._map = MemoryStoreService:GetSortedMap(REGISTRY_NAME)
	BaseService.Init(self)
	self._logger.Info("LobbyWorldTeleportService initialized")
end

function LobbyWorldTeleportService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Info("LobbyWorldTeleportService started")
end

-- Resolve worldId from payload; default to ownerUserId string
local function resolveWorldId(player, payload)
	if payload and type(payload.worldId) == "string" and #payload.worldId > 0 then
		return payload.worldId
	end
	local ownerUserId = (payload and payload.ownerUserId) or player.UserId
	return tostring(ownerUserId)
end

function LobbyWorldTeleportService:_getActiveEntry(worldId)
	local ok, value = pcall(function()
		return self._map:GetAsync(worldId)
	end)
	if ok then
		return value
	end
	return nil
end

function LobbyWorldTeleportService:_setActiveEntry(worldId, entry)
	pcall(function()
		self._map:SetAsync(worldId, entry, REGISTRY_TTL)
	end)
end

-- Create or join world instance for player
function LobbyWorldTeleportService:RequestJoinWorld(player: Player, payload)
	self._logger.Info("RequestJoinWorld received", { player = player and player.Name, payload = payload })
	local worldId = resolveWorldId(player, payload)

	-- Extract ownerUserId from worldId (format: "userId:slot")
	local ownerUserId = tonumber(string.match(worldId, "^(%d+):")) or player.UserId
	local ownerName = player.Name  -- Will be updated from registry if available

	-- First try to re-use active instance
	local entry = self:_getActiveEntry(worldId)
	if entry and entry.accessCode then
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({
			worldId = worldId,
			ownerUserId = ownerUserId,
			ownerName = entry.ownerName or ownerName,
			accessCode = entry.accessCode,
			returnPlaceId = LOBBY_PLACE_ID,
			intent = "joinWorld"
		})
		self._logger.Info("Reusing active world instance", { worldId = worldId })
		local ok, err = pcall(function()
			TeleportService:TeleportToPrivateServer(WORLDS_PLACE_ID, entry.accessCode, { player }, options)
		end)
		if not ok then
			self._logger.Warn("Teleport failed, will reserve new server", { error = tostring(err) })
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("WorldJoinError", player, { message = "Teleport failed. Reserving a new server..." })
		else
			return
		end
	end

	-- Reserve new private server
	if RunService:IsStudio() then
		-- Teleporting between places is blocked in Studio; inform the client
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, { message = "Cross-place teleport is disabled in Studio. Publish and test in a live server." })
		return
	end

	local accessCode
	local ok, err = pcall(function()
		accessCode = TeleportService:ReserveServer(WORLDS_PLACE_ID)
	end)
	if not ok or not accessCode then
		self._logger.Error("Failed to reserve server", { error = tostring(err) })
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, { message = "Unable to start world. Please try again." })
		return
	end

	-- Write initial registry entry so friends can join
	local newEntry = {
		placeId = WORLDS_PLACE_ID,
		instanceId = nil, -- will be filled by world server heartbeat
		ownerUserId = ownerUserId,
		ownerName = ownerName,
		accessCode = accessCode,
		updatedAt = os.time(),
		playerCount = 0,
		version = 1
	}
	self:_setActiveEntry(worldId, newEntry)

	-- Teleport with data
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		worldId = worldId,
		ownerUserId = ownerUserId,
		ownerName = ownerName,
		accessCode = accessCode,
		returnPlaceId = LOBBY_PLACE_ID,
		intent = "joinWorld"
	})

	self._logger.Info("Teleporting to reserved world instance", { worldId = worldId })
	local ok2, err2 = pcall(function()
		TeleportService:TeleportToPrivateServer(WORLDS_PLACE_ID, accessCode, { player }, options)
	end)
	if not ok2 then
		self._logger.Error("TeleportToPrivateServer failed", { error = tostring(err2) })
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport failed. Please try again." })
	end
end

-- Simple create world entry point (defaults to userId world)
function LobbyWorldTeleportService:RequestCreateWorld(player: Player, payload)
	self._logger.Info("RequestCreateWorld received", { player = player and player.Name, payload = payload })

	-- Get WorldsListService to check slots and create world
	local Injector = require(script.Parent.Parent.Injector)
	local worldsListService = Injector:Resolve("WorldsListService")

	if not worldsListService then
		self._logger.Error("WorldsListService not available")
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, {
			message = "World service unavailable. Please try again."
		})
		return
	end

	-- Get slot number from payload or find next available
	local slotNumber = (payload and payload.slot) or worldsListService:GetNextAvailableSlot(player.UserId)

	if not slotNumber then
		-- All slots full
		self._logger.Warn("Player has no available world slots", { player = player.Name })
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, {
			message = "Maximum worlds reached (5/5). Delete a world to create a new one."
		})
		return
	end

	-- Create world in DataStore
	local success, result = worldsListService:CreateWorld(player, slotNumber)
	if not success then
		self._logger.Error("Failed to create world", { player = player.Name, error = result })
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("WorldJoinError", player, {
			message = result or "Failed to create world. Please try again."
		})
		return
	end

	-- World created successfully, now teleport to it
	local worldId = result
	self._logger.Info("World created, teleporting player", { player = player.Name, worldId = worldId })

	return self:RequestJoinWorld(player, {
		worldId = worldId,
		ownerUserId = player.UserId
	})
end

return LobbyWorldTeleportService


