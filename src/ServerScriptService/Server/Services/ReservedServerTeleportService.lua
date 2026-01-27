--[[
	ReservedServerTeleportService.lua
	
	Single-place architecture: Teleports between reserved servers.
	
	From PRD - Teleport Events:
	- RequestTeleportToHub: World → Hub
	- RequestReturnHome: Hub → World
	
	All teleports use same PlaceId with reserved servers.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)

local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local PLACE_ID = GameConfig.Places.PLACE_ID
local ServerTypes = GameConfig.ServerTypes

local HUB_POOL = "HubPool_v1"
local WORLD_REGISTRY = "ActiveWorlds_v1"
local REGISTRY_TTL = 30

local ReservedServerTeleportService = setmetatable({}, BaseService)
ReservedServerTeleportService.__index = ReservedServerTeleportService

function ReservedServerTeleportService.new()
	local self = setmetatable(BaseService.new(), ReservedServerTeleportService)
	self._logger = Logger:CreateContext("Teleport")
	self._hubPool = nil
	self._worldRegistry = nil
	return self
end

function ReservedServerTeleportService:Init()
	if self._initialized then return end
	if not IS_STUDIO then
		self._hubPool = MemoryStoreService:GetSortedMap(HUB_POOL)
		self._worldRegistry = MemoryStoreService:GetSortedMap(WORLD_REGISTRY)
	end
	BaseService.Init(self)
end

function ReservedServerTeleportService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Info("ReservedServerTeleportService ready")
end

-- Get available hub
function ReservedServerTeleportService:_getAvailableHub()
	if not self._hubPool then return nil end
	local maxPlayers = GameConfig.HubPool.MaxPlayersPerHub or 25
	
	local ok, items = pcall(function()
		return self._hubPool:GetRangeAsync(Enum.SortDirection.Ascending, 10)
	end)
	
	if ok and items then
		for _, item in ipairs(items) do
			if item.value and item.value.accessCode and (item.value.playerCount or 0) < maxPlayers then
				return item.value
			end
		end
	end
	return nil
end

-- Get active world
function ReservedServerTeleportService:_getActiveWorld(worldId)
	if not self._worldRegistry then return nil end
	local ok, value = pcall(function()
		return self._worldRegistry:GetAsync(worldId)
	end)
	return ok and value or nil
end

-- Reserve new server
function ReservedServerTeleportService:_reserveServer()
	if IS_STUDIO then return nil end
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(PLACE_ID)
	end)
	return ok and code or nil
end

-- Teleport to Hub (from World)
function ReservedServerTeleportService:TeleportToHub(player)
	if not player then return end
	
	self._logger.Info("TeleportToHub", { player = player.Name })
	
	if IS_STUDIO then
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport disabled in Studio" })
		return
	end
	
	local hub = self:_getAvailableHub()
	local accessCode = hub and hub.accessCode or self:_reserveServer()
	
	if not accessCode then
		EventManager:FireEvent("WorldJoinError", player, { message = "Unable to connect to Hub" })
		return
	end
	
	-- CRITICAL: Mark player as teleporting BEFORE saving to prevent dupe exploits
	-- This blocks all inventory actions (drops, pickups, transfers) during teleport
	local Injector = require(script.Parent.Parent.Injector)
	local playerService = Injector:Resolve("PlayerService")
	if playerService then
		playerService:SetTeleporting(player)
		playerService:SavePlayerData(player)
	end
	
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ serverType = ServerTypes.HUB, isHub = true })
	options.ReservedServerAccessCode = accessCode
	
	local ok = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)
	
	if not ok then
		-- Clear teleporting status if teleport failed
		if playerService then
			playerService:ClearTeleporting(player)
		end
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport failed" })
	end
end

-- Return to main world (from Hub)
function ReservedServerTeleportService:ReturnHome(player)
	if not player then return end
	
	self._logger.Info("ReturnHome", { player = player.Name })
	
	if IS_STUDIO then
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport disabled in Studio" })
		return
	end
	
	local worldId = string.format("%d:1", player.UserId)
	local ownerName = player.DisplayName or player.Name
	
	-- Check for active world
	local world = self:_getActiveWorld(worldId)
	local accessCode = world and world.accessCode or self:_reserveServer()
	
	if not accessCode then
		EventManager:FireEvent("WorldJoinError", player, { message = "Unable to start world" })
		return
	end
	
	-- Register if new
	if not world and self._worldRegistry then
		pcall(function()
			self._worldRegistry:SetAsync(worldId, {
				placeId = PLACE_ID,
				ownerUserId = player.UserId,
				ownerName = ownerName,
				accessCode = accessCode,
				worldId = worldId,
				slotId = 1,
				updatedAt = os.time(),
			}, REGISTRY_TTL)
		end)
	end
	
	-- CRITICAL: Mark player as teleporting BEFORE saving to prevent dupe exploits
	-- This blocks all inventory actions (drops, pickups, transfers) during teleport
	local Injector = require(script.Parent.Parent.Injector)
	local playerService = Injector:Resolve("PlayerService")
	if playerService then
		playerService:SetTeleporting(player)
		playerService:SavePlayerData(player)
	end
	
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		serverType = ServerTypes.WORLD,
		worldId = worldId,
		ownerUserId = player.UserId,
		ownerName = ownerName,
		slotId = 1,
		accessCode = accessCode,
		visitingAsOwner = true,
	})
	options.ReservedServerAccessCode = accessCode
	
	local ok = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)
	
	if not ok then
		-- Clear teleporting status if teleport failed
		if playerService then
			playerService:ClearTeleporting(player)
		end
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport failed" })
	end
end

-- Event handlers
function ReservedServerTeleportService:RequestTeleportToHub(player)
	self:TeleportToHub(player)
end

function ReservedServerTeleportService:RequestReturnHome(player)
	self:ReturnHome(player)
end

return ReservedServerTeleportService
