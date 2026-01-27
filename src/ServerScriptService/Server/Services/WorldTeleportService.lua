--[[
	WorldTeleportService.lua
	
	Single-place architecture: Join/create player worlds.
	
	From PRD - Events:
	- RequestJoinWorld: Join own or friend's world
	- RequestCreateWorld: Create and join new world slot
	
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

local WORLD_REGISTRY = "ActiveWorlds_v1"
local REGISTRY_TTL = 30

local WorldTeleportService = setmetatable({}, BaseService)
WorldTeleportService.__index = WorldTeleportService

function WorldTeleportService.new()
	local self = setmetatable(BaseService.new(), WorldTeleportService)
	self._logger = Logger:CreateContext("WorldTeleport")
	self._registry = nil
	return self
end

function WorldTeleportService:Init()
	if self._initialized then return end
	if not IS_STUDIO then
		self._registry = MemoryStoreService:GetSortedMap(WORLD_REGISTRY)
	end
	BaseService.Init(self)
end

function WorldTeleportService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Info("WorldTeleportService ready")
end

-- Parse world context from payload
local function resolveWorldContext(player, payload)
	payload = payload or {}
	local ownerUserId = payload.ownerUserId or player.UserId
	local slotId = payload.slotId
	local worldId = payload.worldId
	
	if worldId and type(worldId) == "string" then
		slotId = slotId or tonumber(string.match(worldId, "[:_](%d+)$"))
		local extracted = tonumber(string.match(worldId, "^(%d+)"))
		if extracted then ownerUserId = extracted end
	end
	
	if not worldId and ownerUserId and slotId then
		worldId = string.format("%d:%d", ownerUserId, slotId)
	end
	
	return worldId, ownerUserId, slotId
end

-- Get active world from registry
function WorldTeleportService:_getActiveWorld(worldId)
	if not self._registry then return nil end
	local ok, value = pcall(function()
		return self._registry:GetAsync(worldId)
	end)
	return ok and value or nil
end

-- Register world in registry
function WorldTeleportService:_registerWorld(worldId, ownerUserId, ownerName, accessCode, slotId)
	if not self._registry then return end
	pcall(function()
		self._registry:SetAsync(worldId, {
			placeId = PLACE_ID,
			ownerUserId = ownerUserId,
			ownerName = ownerName,
			accessCode = accessCode,
			worldId = worldId,
			slotId = slotId,
			updatedAt = os.time(),
		}, REGISTRY_TTL)
	end)
end

-- Join a world
function WorldTeleportService:RequestJoinWorld(player, payload)
	local worldId, ownerUserId, slotId = resolveWorldContext(player, payload)
	
	if not worldId or not ownerUserId or not slotId then
		EventManager:FireEvent("WorldJoinError", player, { message = "Invalid world selection" })
		return
	end
	
	local ownerName = player.Name
	local isOwner = player.UserId == ownerUserId
	
	self._logger.Info("RequestJoinWorld", { player = player.Name, worldId = worldId, isOwner = isOwner })
	
	-- Try active instance first
	local entry = self:_getActiveWorld(worldId)
	if entry and entry.accessCode then
		-- Save player data before teleport (new server will take lock seamlessly)
		local Injector = require(script.Parent.Parent.Injector)
		local playerService = Injector:Resolve("PlayerService")
		if playerService then
			playerService:SavePlayerData(player)
		end
		
		local options = Instance.new("TeleportOptions")
		options:SetTeleportData({
			serverType = ServerTypes.WORLD,
			worldId = worldId,
			ownerUserId = ownerUserId,
			ownerName = entry.ownerName or ownerName,
			slotId = entry.slotId or slotId,
			accessCode = entry.accessCode,
			visitingAsOwner = isOwner,
		})
		options.ReservedServerAccessCode = entry.accessCode
		
		local ok = pcall(function()
			TeleportService:TeleportAsync(PLACE_ID, { player }, options)
		end)
		if ok then return end
	end
	
	-- Only owners can start new instances
	if not isOwner then
		EventManager:FireEvent("WorldJoinError", player, { message = "World offline. Ask owner to start it." })
		return
	end
	
	if IS_STUDIO then
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport disabled in Studio" })
		return
	end
	
	-- Reserve new server
	local accessCode
	local ok = pcall(function()
		accessCode = TeleportService:ReserveServer(PLACE_ID)
	end)
	
	if not ok or not accessCode then
		EventManager:FireEvent("WorldJoinError", player, { message = "Unable to start world" })
		return
	end
	
	-- Register and teleport
	self:_registerWorld(worldId, ownerUserId, ownerName, accessCode, slotId)
	
	-- Save player data before teleport (new server will take lock seamlessly)
	local Injector = require(script.Parent.Parent.Injector)
	local playerService = Injector:Resolve("PlayerService")
	if playerService then
		playerService:SavePlayerData(player)
	end
	
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		serverType = ServerTypes.WORLD,
		worldId = worldId,
		ownerUserId = ownerUserId,
		ownerName = ownerName,
		slotId = slotId,
		accessCode = accessCode,
		visitingAsOwner = true,
	})
	options.ReservedServerAccessCode = accessCode
	
	local ok2 = pcall(function()
		TeleportService:TeleportAsync(PLACE_ID, { player }, options)
	end)
	
	if not ok2 then
		EventManager:FireEvent("WorldJoinError", player, { message = "Teleport failed" })
	end
end

-- Create and join new world
function WorldTeleportService:RequestCreateWorld(player, payload)
	local Injector = require(script.Parent.Parent.Injector)
	local worldsListService = Injector:Resolve("WorldsListService")
	
	if not worldsListService then
		EventManager:FireEvent("WorldJoinError", player, { message = "World service unavailable" })
		return
	end
	
	local slotNumber = (payload and payload.slot) or worldsListService:GetNextAvailableSlot(player.UserId)
	if not slotNumber then
		EventManager:FireEvent("WorldJoinError", player, { message = "Maximum worlds reached" })
		return
	end
	
	local success, result = worldsListService:CreateWorld(player, slotNumber)
	if not success then
		EventManager:FireEvent("WorldJoinError", player, { message = result or "Failed to create world" })
		return
	end
	
	return self:RequestJoinWorld(player, { worldId = result, ownerUserId = player.UserId, visitingAsOwner = true })
end

return WorldTeleportService
