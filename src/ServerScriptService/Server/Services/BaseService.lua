--[[
	BaseService

	Base class for all services in the framework. Provides standard lifecycle
	methods and ensures idempotent initialization.

	Lifecycle:
	- Init: One-time construction and dependency wiring
	- Start: Begin loops, listeners, timers
	- Destroy: Graceful cleanup
--]]

local Network = require(game.ReplicatedStorage.Shared.Network)

local BaseService = {}
BaseService.__index = BaseService

function BaseService.new()
	local self = setmetatable({}, BaseService)

	-- Dependency injection container (populated by Injector)
	self.Deps = {}

	-- Lifecycle state tracking
	self._initialized = false
	self._started = false
	self._destroyed = false

	return self
end

--[[
	Get Network singleton instance (lazy initialization)
--]]
function BaseService:GetNetwork()
	return Network.GetInstance()
end

--[[
	Override this method in your service for one-time setup
--]]
function BaseService:Init()
	if self._initialized then
		return
	end

	self._initialized = true
	-- Override in subclass
end

--[[
	Override this method in your service to start operations
--]]
function BaseService:Start()
	if self._started then
		return
	end

	if not self._initialized then
		error("Cannot start service before initialization")
	end

	self._started = true
	-- Override in subclass
end

--[[
	Override this method in your service for cleanup
--]]
function BaseService:Destroy()
	if self._destroyed then
		return
	end

	self._destroyed = true
	self._started = false
	-- Override in subclass
end

function BaseService:IsInitialized()
	return self._initialized
end

function BaseService:IsStarted()
	return self._started
end

function BaseService:IsDestroyed()
	return self._destroyed
end



return BaseService