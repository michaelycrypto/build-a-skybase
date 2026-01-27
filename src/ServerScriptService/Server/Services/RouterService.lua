--[[
	RouterService.lua
	
	Single-place architecture: Fast player routing at public entry point.
	
	From PRD:
	- Router lifetime per player: <2 seconds
	- No Workspace loading, no NPCs, no UI
	- Resolve destination → Reserve server → Teleport
	- Fallback to Hub on failure
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
	self._logger.Info("RouterService ready")
end

-- Get available hub from pool
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

-- Reserve new hub server
function RouterService:_reserveHub()
	if IS_STUDIO then return nil end
	
	local ok, accessCode = pcall(function()
		return TeleportService:ReserveServer(PLACE_ID)
	end)
	
	return ok and accessCode or nil
end

-- Teleport to hub
function RouterService:_teleportToHub(player, accessCode)
	-- Router doesn't load player data, so no lock to release
	-- But if we did load data, we'd release here
	
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

-- Route player to Hub (default destination per PRD)
function RouterService:RoutePlayer(player)
	if not player or not player:IsDescendantOf(game) then return end
	if self._routing[player.UserId] then return end
	
	self._routing[player.UserId] = true
	local startTime = os.clock()
	
	self._logger.Info("Routing player to Hub", { player = player.Name })
	
	if IS_STUDIO then
		self._logger.Warn("Router cannot teleport in Studio")
		self._routing[player.UserId] = nil
		return
	end
	
	-- Get or reserve hub
	local hub = self:_getAvailableHub()
	local accessCode = hub and hub.accessCode or self:_reserveHub()
	
	-- Teleport with retries
	local success = false
	for attempt = 1, MAX_RETRIES do
		if not player:IsDescendantOf(game) then break end
		
		if accessCode then
			success = self:_teleportToHub(player, accessCode)
			if success then break end
		end
		
		if attempt < MAX_RETRIES then
			task.wait(0.5)
			accessCode = self:_reserveHub()
		end
	end
	
	local elapsed = (os.clock() - startTime) * 1000
	self._logger.Info("Routing complete", {
		player = player.Name,
		success = success,
		elapsedMs = string.format("%.0f", elapsed)
	})
	
	self._routing[player.UserId] = nil
end

return RouterService
