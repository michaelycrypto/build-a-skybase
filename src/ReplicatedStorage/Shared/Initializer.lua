--[[
	Initializer - System Initialization Management

	Manages the initialization and startup sequence for both client and server.
	Provides utilities for ordered initialization and dependency management.
--]]

local RunService = game:GetService("RunService")

local Initializer = {}
Initializer.__index = Initializer

-- Global instance
local _instance = nil

function Initializer.new()
	local self = setmetatable({}, Initializer)

	self._systems = {}
	self._dependencies = {}
	self._initialized = {}
	self._isInitializing = false

	return self
end

function Initializer.GetInstance()
	if not _instance then
		_instance = Initializer.new()
	end
	return _instance
end

--[[
	Register a system for initialization
--]]
function Initializer:RegisterSystem(name, system, dependencies)
	assert(type(name) == "string", "System name must be a string")
	assert(type(system) == "table", "System must be a table")

	dependencies = dependencies or {}
	assert(type(dependencies) == "table", "Dependencies must be a table")

	self._systems[name] = system
	self._dependencies[name] = dependencies
	self._initialized[name] = false

	print("Initializer: Registered system '" .. name .. "' with dependencies:", table.concat(dependencies, ", "))
end

--[[
	Initialize all systems in dependency order
--]]
function Initializer:InitializeAll()
	if self._isInitializing then
		warn("Initializer: Already initializing")
		return false
	end

	self._isInitializing = true
	print("Initializer: Starting system initialization...")

	local initOrder = self:_calculateInitOrder()
	local totalSystems = #initOrder
	local successCount = 0

	for i, systemName in ipairs(initOrder) do
		local system = self._systems[systemName]
		local success = self:_initializeSystem(systemName, system)

		if success then
			successCount = successCount + 1
			print(string.format("Initializer: [%d/%d] %s initialized", i, totalSystems, systemName))
		else
			warn(string.format("Initializer: [%d/%d] %s failed to initialize", i, totalSystems, systemName))
		end
	end

	self._isInitializing = false
	local allSuccess = successCount == totalSystems

	if allSuccess then
		print("Initializer: All systems initialized successfully!")
	else
		warn(string.format("Initializer: %d/%d systems initialized", successCount, totalSystems))
	end

	return allSuccess
end

--[[
	Initialize a specific system
--]]
function Initializer:InitializeSystem(systemName)
	assert(type(systemName) == "string", "System name must be a string")

	if self._initialized[systemName] then
		print("Initializer: System '" .. systemName .. "' already initialized")
		return true
	end

	local system = self._systems[systemName]
	if not system then
		warn("Initializer: System '" .. systemName .. "' not found")
		return false
	end

	-- Check dependencies
	local dependencies = self._dependencies[systemName]
	for _, depName in ipairs(dependencies) do
		if not self._initialized[depName] then
			warn("Initializer: Cannot initialize '" .. systemName .. "' - dependency '" .. depName .. "' not initialized")
			return false
		end
	end

	return self:_initializeSystem(systemName, system)
end

--[[
	Check if a system is initialized
--]]
function Initializer:IsSystemInitialized(systemName)
	return self._initialized[systemName] == true
end

--[[
	Get initialization status
--]]
function Initializer:GetInitializationStatus()
	local status = {}
	for systemName, _ in pairs(self._systems) do
		status[systemName] = self._initialized[systemName]
	end
	return status
end

--[[
	Internal: Calculate initialization order based on dependencies
--]]
function Initializer:_calculateInitOrder()
	local order = {}
	local visited = {}
	local visiting = {}

	local function visit(systemName)
		if visiting[systemName] then
			error("Circular dependency detected involving: " .. systemName)
		end

		if visited[systemName] then
			return
		end

		visiting[systemName] = true

		local dependencies = self._dependencies[systemName]
		if dependencies then
			for _, depName in ipairs(dependencies) do
				if self._systems[depName] then
					visit(depName)
				else
					warn("Initializer: Dependency '" .. depName .. "' not found for system '" .. systemName .. "'")
				end
			end
		end

		visiting[systemName] = false
		visited[systemName] = true
		table.insert(order, systemName)
	end

	for systemName, _ in pairs(self._systems) do
		visit(systemName)
	end

	return order
end

--[[
	Internal: Initialize a single system
--]]
function Initializer:_initializeSystem(systemName, system)
	local success = false

	-- Try different initialization methods
	if system.Initialize then
		success = pcall(system.Initialize, system)
	elseif system.Init then
		success = pcall(system.Init, system)
	elseif system.Start then
		success = pcall(system.Start, system)
	else
		-- No initialization method found, assume success
		success = true
		print("Initializer: No initialization method found for '" .. systemName .. "', assuming success")
	end

	if success then
		self._initialized[systemName] = true
	else
		warn("Initializer: Failed to initialize system '" .. systemName .. "'")
	end

	return success
end

--[[
	Wait for a system to be initialized
--]]
function Initializer:WaitForSystem(systemName, timeout)
	timeout = timeout or 10
	local startTime = tick()

	while not self._initialized[systemName] do
		if tick() - startTime > timeout then
			warn("Initializer: Timeout waiting for system '" .. systemName .. "'")
			return false
		end
		task.wait(0.1)
	end

	return true
end

--[[
	Create a standard client initialization sequence
--]]
function Initializer:CreateClientSequence(config)
	config = config or {}

	-- Register core systems
	self:RegisterSystem("Network", config.Network or {}, {})
	self:RegisterSystem("Logger", config.Logger or {}, {})
	self:RegisterSystem("EventManager", config.EventManager or {}, {"Network"})

	-- Register managers
	if config.GameState then
		self:RegisterSystem("GameState", config.GameState, {"Network", "Logger"})
	end

	if config.SoundManager then
		self:RegisterSystem("SoundManager", config.SoundManager, {"Logger"})
	end

	if config.UIManager then
		self:RegisterSystem("UIManager", config.UIManager, {"Logger"})
	end

	if config.ToastManager then
		self:RegisterSystem("ToastManager", config.ToastManager, {"SoundManager", "UIManager"})
	end

	print("Initializer: Client initialization sequence created")
end

--[[
	Create a standard server initialization sequence
--]]
function Initializer:CreateServerSequence(config)
	config = config or {}

	-- Register core systems
	self:RegisterSystem("Network", config.Network or {}, {})
	self:RegisterSystem("Logger", config.Logger or {}, {})
	self:RegisterSystem("EventManager", config.EventManager or {}, {"Network"})

	-- Register services
	if config.PlayerService then
		self:RegisterSystem("PlayerService", config.PlayerService, {"Network", "Logger"})
	end

	if config.WorldService then
		self:RegisterSystem("WorldService", config.WorldService, {"Logger"})
	end

	if config.ShopService then
		self:RegisterSystem("ShopService", config.ShopService, {"PlayerService"})
	end

	if config.RewardService then
		self:RegisterSystem("RewardService", config.RewardService, {"PlayerService"})
	end

	print("Initializer: Server initialization sequence created")
end

--[[
	Cleanup all systems
--]]
function Initializer:Cleanup()
	print("Initializer: Cleaning up systems...")

	-- Cleanup in reverse order
	local systems = {}
	for name, system in pairs(self._systems) do
		if self._initialized[name] then
			table.insert(systems, {name = name, system = system})
		end
	end

	-- Sort by reverse dependency order (cleanup dependencies last)
	table.sort(systems, function(a, b)
		local aDeps = #(self._dependencies[a.name] or {})
		local bDeps = #(self._dependencies[b.name] or {})
		return aDeps > bDeps
	end)

	-- Cleanup each system
	for _, entry in ipairs(systems) do
		if entry.system.Cleanup then
			local success = pcall(entry.system.Cleanup, entry.system)
			if success then
				print("Initializer: Cleaned up system '" .. entry.name .. "'")
			else
				warn("Initializer: Failed to cleanup system '" .. entry.name .. "'")
			end
		end
	end

	-- Reset state
	self._systems = {}
	self._dependencies = {}
	self._initialized = {}
	self._isInitializing = false

	print("Initializer: Cleanup complete")
end

-- Export singleton
return Initializer.GetInstance()