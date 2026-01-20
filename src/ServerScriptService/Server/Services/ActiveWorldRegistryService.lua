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
-- S5: Reduced TTL from 90s to 30s with more frequent heartbeats (every 15s)
-- This reduces stale entries from crashed servers, improving teleport reliability
-- Heartbeat frequency ensures entry is refreshed 2x before expiry for redundancy
local HEARTBEAT_INTERVAL = 15 -- seconds (was 30)
local ENTRY_TTL = 30 -- seconds (was 90)

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
	self._logger.Debug("ActiveWorldRegistryService initialized")
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
	-- Allow reclaim if existing entry is stale (no heartbeat for 2x heartbeat interval)
	local STALE_THRESHOLD = HEARTBEAT_INTERVAL * 2

	local ok, err = pcall(function()
		self._map:UpdateAsync(worldId, function(prev)
			prev = prev or {}

			-- Check if existing entry is from a different server
			if prev.claimToken and prev.claimToken ~= claimToken then
				-- Allow reclaim if the existing entry is stale (old server is likely dead)
				local lastUpdate = prev.updatedAt or 0
				local isStale = (now - lastUpdate) > STALE_THRESHOLD

				-- Also allow reclaim if same owner is joining (they're taking over their own world)
				local isSameOwner = prev.ownerUserId == ownerUserId

				if not isStale and not isSameOwner then
					self._logger.Warn("Registry entry claimed by another active server", {
						worldId = worldId,
						existingToken = prev.claimToken,
						newToken = claimToken,
						lastUpdate = lastUpdate,
						ageSeconds = now - lastUpdate
					})
					return prev
				end

				self._logger.Info("Reclaiming registry entry", {
					worldId = worldId,
					reason = isStale and "stale_entry" or "owner_reclaim",
					ageSeconds = now - lastUpdate
				})
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


