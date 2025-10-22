--[[
	Injector - Dependency Injection with Mixin Support

	Supports service dependencies and composable behavior mixins.
	Services can declare which mixins they want applied.

	Usage:
	Injector:Bind("DataService", script.Parent.Parent.Services.DataService, {
		dependencies = {"ConfigService"},
		mixins = {"Cacheable", "Trackable", "Auditable"}
	})
--]]

local Injector = {}
Injector.__index = Injector

-- Global state
local _bindings = {} -- name -> {moduleScript, dependencies, mixins}
local _instances = {} -- name -> constructed service
local _resolving = {} -- circular dependency detection

--[[
	Bind a service with dependencies and mixins
	@param name string - Service name
	@param moduleScript ModuleScript - ModuleScript object
	@param config table - Optional config: {dependencies = {...}, mixins = {...}}
--]]
function Injector:Bind(name, moduleScript, config)
	assert(type(name) == "string", "Service name must be a string")
	assert(typeof(moduleScript) == "Instance", "Module must be a ModuleScript")

	config = config or {}

	_bindings[name] = {
		moduleScript = moduleScript,
		dependencies = config.dependencies or {},
		mixins = config.mixins or {}
	}
end

--[[
	Simple bind for services without dependencies/mixins
--]]
function Injector:BindSimple(name, moduleScript)
	self:Bind(name, moduleScript, {})
end

--[[
	Bind a service with just dependencies
--]]
function Injector:BindWithDeps(name, moduleScript, dependencies)
	self:Bind(name, moduleScript, {dependencies = dependencies})
end

--[[
	Bind a service with just mixins
--]]
function Injector:BindWithMixins(name, moduleScript, mixins)
	self:Bind(name, moduleScript, {mixins = mixins})
end

--[[
	Resolve a single service by name
	@param name string - Service name to resolve
	@return table - The constructed service instance
--]]
function Injector:Resolve(name)
	assert(type(name) == "string", "Service name must be a string")

	-- Return cached instance if available
	if _instances[name] then
		return _instances[name]
	end

	-- Check for circular dependency
	if _resolving[name] then
		error("Circular dependency detected: " .. name)
	end

	-- Get binding info
	local binding = _bindings[name]
	if not binding then
		error("No binding found for service: " .. name)
	end

	_resolving[name] = true

	-- Load module directly
	local module = require(binding.moduleScript)
	local instance = self:_createInstance(module, name)

	-- Store instance before resolving dependencies
	_instances[name] = instance

	-- Apply mixins first (before dependencies)
	self:_applyMixins(instance, binding.mixins, name)

	-- Resolve and inject dependencies
	self:_injectDependencies(instance, binding.dependencies)

	_resolving[name] = nil
	return instance
end

--[[
	Create service instance from module
--]]
function Injector:_createInstance(module, name)
	local instance

	if type(module) == "function" then
		instance = module()
	elseif type(module) == "table" and module.new then
		instance = module.new()
	elseif type(module) == "table" then
		-- Plain table - ensure it has service methods
		if not module.Init then
			module.Init = function() end
		end
		if not module.Start then
			module.Start = function() end
		end
		if not module.Destroy then
			module.Destroy = function() end
		end
		instance = module
	else
		error("Invalid module type for service: " .. name)
	end

	-- Ensure instance has required tables
	if not instance.Deps then
		instance.Deps = {}
	end

	return instance
end

--[[
	Apply mixins to service instance
--]]
function Injector:_applyMixins(instance, mixins, serviceName)
	for _, mixinName in ipairs(mixins) do
			-- Get mixin ModuleScript from Mixins folder
	local mixinsFolder = script.Parent.Mixins
	local mixinScript = mixinsFolder:FindFirstChild(mixinName)

		if not mixinScript then
			error("Mixin not found: " .. mixinName .. " for service: " .. serviceName)
		end

		local mixin = require(mixinScript)

		-- Apply mixin based on its pattern
		if mixin.Apply then
			-- Pattern: mixin.Apply(service)
			mixin.Apply(instance)
		elseif mixin.Methods then
			-- Pattern: mixin has Methods table
			for methodName, method in pairs(mixin.Methods) do
				instance[methodName] = method
			end
		else
			-- Pattern: mixin is a table of methods
			for methodName, method in pairs(mixin) do
				if type(method) == "function" and not string.match(methodName, "^_") then
					instance[methodName] = method
				end
			end
		end

		-- Copy properties if they exist
		if mixin.Properties then
			for propName, propValue in pairs(mixin.Properties) do
				instance[propName] = propValue
			end
		end
	end
end

--[[
	Inject dependencies into service
--]]
function Injector:_injectDependencies(instance, dependencies)
	for _, depName in ipairs(dependencies) do
		instance.Deps[depName] = self:Resolve(depName)
	end
end

--[[
	Resolve all bound services and create a lifecycle manager
	@return table - Object with Init() and Start() methods
--]]
function Injector:ResolveAll()
	local services = {}

	-- Resolve all services
	for name, _ in pairs(_bindings) do
		table.insert(services, self:Resolve(name))
	end

	-- Return lifecycle manager
	return {
		Init = function()
			for _, service in ipairs(services) do
				if service.Init then
					service:Init()
				end
			end
		end,

		Start = function()
			for _, service in ipairs(services) do
				if service.Start then
					service:Start()
				end
			end
		end,

		Destroy = function()
			for _, service in ipairs(services) do
				if service.Destroy then
					service:Destroy()
				end
			end
		end
	}
end

--[[
	Legacy methods for backward compatibility
--]]
function Injector:InitAll()
	self:ResolveAll():Init()
end

function Injector:StartAll()
	self:ResolveAll():Start()
end

--[[
	Convert module path to ModuleScript instance
--]]
function Injector:_getModuleFromPath(path)
	local parts = string.split(path, ".")
	local current = game

	for _, part in ipairs(parts) do
		local child = current:FindFirstChild(part)
		if not child then
			return nil
		end
		current = child
	end

	return current
end

return Injector