--[[
	HubPoolService.lua
	
	Single-place architecture: Hub instance pooling for social density.
	
	From PRD - Hub Pooling Rules:
	- Max players per hub (e.g. 25)
	- Reuse hub if playerCount < max
	- Create new hub if none available
	- Expire hub after idle timeout
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)

local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IS_STUDIO = RunService:IsStudio()
local HUB_POOL = "HubPool_v1"

local Config = GameConfig.HubPool or {}
local MAX_PLAYERS = Config.MaxPlayersPerHub or 25
local HEARTBEAT_INTERVAL = Config.HeartbeatInterval or 15
local ENTRY_TTL = Config.EntryTTL or 30

local HubPoolService = setmetatable({}, BaseService)
HubPoolService.__index = HubPoolService

function HubPoolService.new()
	local self = setmetatable(BaseService.new(), HubPoolService)
	self._logger = Logger:CreateContext("HubPool")
	self._pool = nil
	self._hubId = nil
	self._accessCode = game.PrivateServerId ~= "" and game.PrivateServerId or nil
	self._playerCount = 0
	self._heartbeatTask = nil
	self._registered = false
	return self
end

function HubPoolService:Init()
	if self._initialized then return end
	if not IS_STUDIO then
		self._pool = MemoryStoreService:GetSortedMap(HUB_POOL)
	end
	BaseService.Init(self)
end

function HubPoolService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Info("HubPoolService ready")
end

-- Write heartbeat to keep entry fresh
function HubPoolService:_writeHeartbeat()
	if not self._pool or not self._hubId then return end
	
	pcall(function()
		self._pool:SetAsync(self._hubId, {
			hubId = self._hubId,
			accessCode = self._accessCode,
			playerCount = self._playerCount,
			maxPlayers = MAX_PLAYERS,
			lastActive = os.time(),
			jobId = tostring(game.JobId or ""),
		}, ENTRY_TTL)
	end)
end

-- Register this hub in the pool
function HubPoolService:RegisterHub()
	if self._registered then return end
	
	self._hubId = "hub_" .. tostring(game.JobId or os.time())
	self._playerCount = #Players:GetPlayers()
	
	if not self._pool then
		self._registered = true
		return
	end
	
	self:_writeHeartbeat()
	
	-- Start heartbeat loop
	self._heartbeatTask = task.spawn(function()
		while self._registered do
			task.wait(HEARTBEAT_INTERVAL)
			self:_writeHeartbeat()
		end
	end)
	
	self._registered = true
	self._logger.Info("Hub registered", { hubId = self._hubId, players = self._playerCount })
end

-- Update player count
function HubPoolService:UpdatePlayerCount(count)
	self._playerCount = math.max(0, count or 0)
	if self._registered then
		self:_writeHeartbeat()
	end
end

-- Unregister hub from pool
function HubPoolService:UnregisterHub()
	if not self._registered then return end
	self._registered = false
	
	if self._heartbeatTask then
		pcall(task.cancel, self._heartbeatTask)
		self._heartbeatTask = nil
	end
	
	if self._pool and self._hubId then
		pcall(function()
			self._pool:RemoveAsync(self._hubId)
		end)
	end
	
	self._logger.Info("Hub unregistered", { hubId = self._hubId })
end

function HubPoolService:Destroy()
	if self._destroyed then return end
	self:UnregisterHub()
	BaseService.Destroy(self)
end

return HubPoolService
