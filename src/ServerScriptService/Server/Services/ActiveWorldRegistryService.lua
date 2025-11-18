--[[
	ActiveWorldRegistryService.lua

	Tracks active player-world server instances in MemoryStore for discovery from the lobby.
	- Worlds place only
	- Heartbeats keep entries fresh; TTL expiry removes stale entries
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")

local REGISTRY_NAME = "ActiveWorlds_v1"
local HEARTBEAT_INTERVAL = 30 -- seconds
local ENTRY_TTL = 90 -- seconds

local ActiveWorldRegistryService = setmetatable({}, BaseService)
ActiveWorldRegistryService.__index = ActiveWorldRegistryService

function ActiveWorldRegistryService.new()
	local self = setmetatable(BaseService.new(), ActiveWorldRegistryService)
	self._logger = Logger:CreateContext("ActiveWorldRegistry")
	self._map = nil

	self._worldId = nil
	self._ownerUserId = nil
	self._ownerName = nil
	self._accessCode = nil -- reserved server access code (from lobby teleport)
	self._placeId = game.PlaceId
	self._instanceId = game.JobId
	self._heartbeatTask = nil

	self._playerCount = 0

	return self
end

function ActiveWorldRegistryService:Init()
	if self._initialized then return end
	-- Use SortedMap for key-value registry (supports Get/Set/Update/Remove with TTL)
	self._map = MemoryStoreService:GetSortedMap(REGISTRY_NAME)

	-- Track player count automatically
	Players.PlayerAdded:Connect(function()
		self._playerCount += 1
		self:_writeHeartbeat(true)
	end)
	Players.PlayerRemoving:Connect(function()
		self._playerCount = math.max(0, self._playerCount - 1)
		self:_writeHeartbeat(true)
	end)

	BaseService.Init(self)
	self._logger.Info("ActiveWorldRegistryService initialized")
end

-- Configure world identity and reserved access (first-player join from teleport data)
function ActiveWorldRegistryService:Configure(worldId: string, ownerUserId: number, ownerName: string?, accessCode: string?)
	self._worldId = worldId
	self._ownerUserId = ownerUserId
	self._ownerName = ownerName
	self._accessCode = accessCode
	self._playerCount = #Players:GetPlayers()
	self:_writeHeartbeat(true)
end

function ActiveWorldRegistryService:Start()
	if self._started then return end
	BaseService.Start(self)

	-- Start heartbeat if configured
	self._heartbeatTask = task.spawn(function()
		while true do
			task.wait(HEARTBEAT_INTERVAL)
			self:_writeHeartbeat(false)
		end
	end)

	self._logger.Info("ActiveWorldRegistryService started")
end

function ActiveWorldRegistryService:_writeHeartbeat(force)
	if not self._map or not self._worldId then return end

	local ok, err = pcall(function()
		self._map:UpdateAsync(self._worldId, function(prev)
			local entry = prev or {}
			entry.placeId = self._placeId
			entry.instanceId = self._instanceId
			entry.ownerUserId = self._ownerUserId
			entry.ownerName = self._ownerName
			entry.updatedAt = os.time()
			entry.playerCount = self._playerCount
			entry.version = 1
			-- Preserve accessCode if already set by lobby; set if provided here
			if self._accessCode then
				entry.accessCode = self._accessCode
			end
			return entry
		end, ENTRY_TTL)
	end)
	if not ok then
		self._logger.Warn("Failed to write heartbeat", { error = tostring(err) })
	end
end

function ActiveWorldRegistryService:Remove()
	if not self._map or not self._worldId then return end
	local ok, err = pcall(function()
		self._map:RemoveAsync(self._worldId)
	end)
	if not ok then
		self._logger.Warn("Failed to remove registry entry", { error = tostring(err) })
	end
end

function ActiveWorldRegistryService:Destroy()
	if self._destroyed then return end
	if self._heartbeatTask then
		pcall(task.cancel, self._heartbeatTask)
	end
	self:Remove()
	BaseService.Destroy(self)
	self._logger.Info("ActiveWorldRegistryService destroyed")
end

return ActiveWorldRegistryService


