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
	self._claimToken = nil
	self._configured = false

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
	if self._configured then
		return true
	end

	if not worldId or not ownerUserId then
		self._logger.Error("Cannot configure registry - missing identifiers", {
			worldId = worldId,
			ownerUserId = ownerUserId
		})
		return false, "invalid_parameters"
	end

	if not self._map then
		self._logger.Error("Cannot configure registry - MemoryStore unavailable")
		return false, "registry_unavailable"
	end

	local claimToken = self._instanceId
	local claimed = false
	local now = os.time()

	local ok, err = pcall(function()
		self._map:UpdateAsync(worldId, function(prev)
			prev = prev or {}

			if prev.claimToken and prev.claimToken ~= claimToken then
				return prev
			end

			claimed = true
			prev.placeId = self._placeId
			prev.instanceId = self._instanceId
			prev.ownerUserId = ownerUserId
			prev.ownerName = ownerName
			prev.accessCode = prev.accessCode or accessCode
			prev.updatedAt = now
			prev.playerCount = #Players:GetPlayers()
			prev.version = 1
			prev.claimToken = claimToken
			return prev
		end, ENTRY_TTL)
	end)

	if not ok or not claimed then
		self._logger.Error("Failed to claim registry entry", {
			worldId = worldId,
			error = err or "claim_failed"
		})
		return false, err or "claim_failed"
	end

	self._worldId = worldId
	self._ownerUserId = ownerUserId
	self._ownerName = ownerName
	self._accessCode = accessCode
	self._playerCount = #Players:GetPlayers()
	self._claimToken = claimToken
	self._configured = true
	self:_writeHeartbeat(true)
	return true
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
	if not self._configured or not self._map or not self._worldId then
		return
	end

	local ok, err = pcall(function()
		self._map:UpdateAsync(self._worldId, function(prev)
			local entry = prev or {}
			if entry.claimToken and entry.claimToken ~= self._claimToken then
				return entry
			end
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
			entry.claimToken = self._claimToken
			return entry
		end, ENTRY_TTL)
	end)
	if not ok then
		self._logger.Warn("Failed to write heartbeat", { error = tostring(err) })
	end
end

function ActiveWorldRegistryService:Remove()
	if not self._map or not self._worldId or not self._claimToken then
		return
	end

	local ok, err = pcall(function()
		self._map:UpdateAsync(self._worldId, function(prev)
			if prev and prev.claimToken == self._claimToken then
				return nil
			end
			return prev
		end)
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


