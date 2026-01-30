--[[
	RouterService.lua
	
	Single-place architecture: Fast player routing at public entry point.
	
	From PRD:
	- Router lifetime per player: <2 seconds
	- No Workspace loading, no NPCs, no UI
	- Resolve destination → Reserve server → Teleport
	
	Default destination: Player's own world (slot 1)
	Fallback: Hub on failure
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)

local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()
local PLACE_ID = GameConfig.Places.PLACE_ID
local ServerTypes = GameConfig.ServerTypes
local MAX_RETRIES = GameConfig.Router.MaxTeleportRetries or 2

local WORLD_REGISTRY = "ActiveWorlds_v1"
local HUB_POOL = "HubPool_v1"
local REGISTRY_TTL = 30

local RouterService = setmetatable({}, BaseService)
RouterService.__index = RouterService

function RouterService.new()
	local self = setmetatable(BaseService.new(), RouterService)
	self._logger = Logger:CreateContext("Router")
	self._worldRegistry = nil
	self._hubPool = nil
	self._routing = {}
	return self
end

function RouterService:Init()
	if self._initialized then return end
	if not IS_STUDIO then
		self._worldRegistry = MemoryStoreService:GetSortedMap(WORLD_REGISTRY)
		self._hubPool = MemoryStoreService:GetSortedMap(HUB_POOL)
	end
	BaseService.Init(self)
end

function RouterService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Info("RouterService ready (routes to player world by default)")
end

-- Get player's world ID (slot 1)
local function getPlayerWorldId(player)
	return string.format("%d:1", player.UserId)
end

-- Check if player's world is online
function RouterService:_getActiveWorld(worldId)
	if not self._worldRegistry then return nil end
	local ok, value = pcall(function()
		return self._worldRegistry:GetAsync(worldId)
	end)
	return ok and value or nil
end

-- Register world in registry
function RouterService:_registerWorld(worldId, ownerUserId, ownerName, accessCode)
	if not self._worldRegistry then return end
	pcall(function()
		self._worldRegistry:SetAsync(worldId, {
			placeId = PLACE_ID,
			ownerUserId = ownerUserId,
			ownerName = ownerName,
			accessCode = accessCode,
			worldId = worldId,
			slotId = 1,
			updatedAt = os.time(),
		}, REGISTRY_TTL)
	end)
end

-- Reserve new server for player world
function RouterService:_reserveWorldServer()
	if IS_STUDIO then return nil end
	
	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServer(PLACE_ID)
	end)
	
	return ok and accessCode or nil
end

-- Teleport to player's world
function RouterService:_teleportToWorld(player, worldId, accessCode, ownerName)
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
	return ok
end

-- Get available hub from pool (fallback)
function RouterService:_getAvailableHub()
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

-- Reserve new hub server (fallback)
function RouterService:_reserveHub()
	if IS_STUDIO then return nil end
	
	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServer(PLACE_ID)
	end)
	
	return ok and accessCode or nil
end

-- Teleport to hub (fallback)
function RouterService:_teleportToHub(player, accessCode)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		serverType = ServerTypes.HUB,
		isHub = true,
	})
	options.ReservedServerAccessCode = accessCode
	
	local ok = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)
	return ok
end

-- Main routing function: Routes player to their world (slot 1)
function RouterService:RoutePlayer(player)
	if not player or not player:IsDescendantOf(game) then return end
	if self._routing[player.UserId] then return end
	
	self._routing[player.UserId] = true
	local startTime = os.clock()
	local worldId = getPlayerWorldId(player)
	
	self._logger.Info("Routing player to their world", { 
		player = player.Name, 
		worldId = worldId 
	})
	
	if IS_STUDIO then
		self._logger.Warn("Router cannot teleport in Studio")
		self._routing[player.UserId] = nil
		return
	end
	
	-- Try to route to player's world first
	local success = false
	local accessCode = nil
	
	-- Check if world is already online
	local activeWorld = self:_getActiveWorld(worldId)
	if activeWorld and activeWorld.accessCode then
		accessCode = activeWorld.accessCode
		self._logger.Debug("Found active world", { worldId = worldId })
	else
		-- Reserve new server for player's world
		accessCode = self:_reserveWorldServer()
		if accessCode then
			self:_registerWorld(worldId, player.UserId, player.Name, accessCode)
			self._logger.Debug("Reserved new world server", { worldId = worldId })
		end
	end
	
	-- Attempt teleport to world with retries
	for attempt = 1, MAX_RETRIES do
		if not player:IsDescendantOf(game) then break end
		
		if accessCode then
			success = self:_teleportToWorld(player, worldId, accessCode, player.Name)
			if success then break end
		end
		
		if attempt < MAX_RETRIES then
			task.wait(0.5)
			-- Try reserving a new server
			accessCode = self:_reserveWorldServer()
			if accessCode then
				self:_registerWorld(worldId, player.UserId, player.Name, accessCode)
			end
		end
	end
	
	-- Fallback to Hub if world routing failed
	if not success and player:IsDescendantOf(game) then
		self._logger.Warn("World routing failed, falling back to Hub", { player = player.Name })
		
		local hub = self:_getAvailableHub()
		local hubAccessCode = hub and hub.accessCode or self:_reserveHub()
		
		for attempt = 1, MAX_RETRIES do
			if not player:IsDescendantOf(game) then break end
			
			if hubAccessCode then
				success = self:_teleportToHub(player, hubAccessCode)
				if success then break end
			end
			
			if attempt < MAX_RETRIES then
				task.wait(0.5)
				hubAccessCode = self:_reserveHub()
			end
		end
	end
	
	local elapsed = (os.clock() - startTime) * 1000
	self._logger.Info("Routing complete", {
		player = player.Name,
		success = success,
		destination = success and "world" or "failed",
		elapsedMs = string.format("%.0f", elapsed)
	})
	
	self._routing[player.UserId] = nil
end

return RouterService
