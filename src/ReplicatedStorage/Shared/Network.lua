--[[
	Network - Simple Contract-Based Networking

	Simple but powerful networking utility for contract-first RemoteEvent/Function definitions.
	Provides type validation and clean API without over-engineering.

	Features:
	- Simple contract definitions
	- Type validation
	- Clean API for events and functions
	- No complex observability or metrics
	- Straightforward patterns
--]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = {}
Network.__index = Network

-- Global network instance
local _instance = nil

function Network.new()
	local self = setmetatable({}, Network)

	self._events = {} -- name -> enhanced event interface
	self._functions = {} -- name -> enhanced function interface
	self._remotesFolder = nil

	self:_initRemotesFolder()

	return self
end

function Network.GetInstance()
	if not _instance then
		_instance = Network.new()
	end
	return _instance
end

--[[
	Initialize the RemoteEvents folder (uses existing structure from project.json)
--]]
function Network:_initRemotesFolder()
	self._remotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not self._remotesFolder then
		if RunService:IsServer() then
			self._remotesFolder = Instance.new("Folder")
			self._remotesFolder.Name = "RemoteEvents"
			self._remotesFolder.Parent = ReplicatedStorage
		else
			self._remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents")
		end
	end
end

--[[
	Define a RemoteEvent with type validation
	@param name string - Event name
	@param paramTypes table - Array of type names for parameters
	@return table - Event interface
--]]
function Network:DefineEvent(name, paramTypes)
	assert(type(name) == "string", "Event name must be a string")
	assert(type(paramTypes) == "table", "Parameter types must be a table")

	if self._events[name] then
		return self._events[name]
	end

	local remote = self:_getOrCreateRemote(name, "RemoteEvent")

	local interface = {
		Fire = function(_, ...)
			if RunService:IsServer() then
				local player = select(1, ...)
				local params = {select(2, ...)}
				self:_validateParams(name, paramTypes, params)
				remote:FireClient(player, unpack(params))
			else
				self:_validateParams(name, paramTypes, {...})
				remote:FireServer(...)
			end
		end,

		FireAll = function(_, ...)
			if RunService:IsServer() then
				self:_validateParams(name, paramTypes, {...})
				remote:FireAllClients(...)
			else
				error("FireAll can only be called from server")
			end
		end,

		Connect = function(_, callback)
			if RunService:IsServer() then
				return remote.OnServerEvent:Connect(function(player, ...)
					self:_validateParams(name, paramTypes, {...})
					callback(player, ...)
				end)
			else
				return remote.OnClientEvent:Connect(function(...)
					self:_validateParams(name, paramTypes, {...})
					callback(...)
				end)
			end
		end
	}

	self._events[name] = interface
	return interface
end

--[[
	Define a RemoteFunction with type validation
	@param name string - Function name
	@param paramTypes table - Array of type names for parameters
	@return table - Function interface with Returns method
--]]
function Network:DefineFunction(name, paramTypes)
	assert(type(name) == "string", "Function name must be a string")
	assert(type(paramTypes) == "table", "Parameter types must be a table")

	if self._functions[name] then
		return self._functions[name]
	end

	local remote = self:_getOrCreateRemote(name, "RemoteFunction")
	local returnTypes = {}

	local interface = {
		Returns = function(self_interface, types)
			assert(type(types) == "table", "Return types must be a table")
			returnTypes = types
			return self_interface
		end,

		SetCallback = function(_, callback)
			if RunService:IsServer() then
				remote.OnServerInvoke = function(player, ...)
					Network.GetInstance():_validateParams(name, paramTypes, {...})
					local results = {callback(player, ...)}
					if #returnTypes > 0 then
						Network.GetInstance():_validateParams(name .. "_return", returnTypes, results)
					end
					return unpack(results)
				end
			else
				error("SetCallback can only be called from server")
			end
		end,

		Invoke = function(_, ...)
			if RunService:IsClient() then
				Network.GetInstance():_validateParams(name, paramTypes, {...})
				local results = {remote:InvokeServer(...)}
				if #returnTypes > 0 then
					Network.GetInstance():_validateParams(name .. "_return", returnTypes, results)
				end
				return unpack(results)
			else
				error("Invoke can only be called from client")
			end
		end
	}

	self._functions[name] = interface
	return interface
end

--[[
	Get or create a remote object
--]]
function Network:_getOrCreateRemote(name, remoteType)
	local remote = self._remotesFolder:FindFirstChild(name)

	if not remote then
		if RunService:IsServer() then
			-- Create individual remotes for each function in the RemoteEvents folder
			remote = Instance.new(remoteType)
			remote.Name = name
			remote.Parent = self._remotesFolder
			-- Remote created
		else
			-- Client waits for the remote to be created by server
			remote = self._remotesFolder:WaitForChild(name, 10)
			if not remote then
				error("Remote " .. name .. " not found in " .. self._remotesFolder.Name)
			end
		end
	end

	return remote
end

--[[
	Validate parameters against type definitions
--]]
function Network:_validateParams(name, paramTypes, params)
	if #paramTypes == 0 then
		return
	end

	-- For debugging
	if name == "PurchaseItem" then
		print("Network: Validating", name, "- expected:", #paramTypes, "got:", #params, "params:", params[1], params[2])
	end

	if #params ~= #paramTypes then
		error(string.format("Parameter count mismatch for %s: expected %d, got %d",
			name, #paramTypes, #params))
	end

	for i, paramType in ipairs(paramTypes) do
		if paramType == "any" then
			continue
		end

		local param = params[i]
		local actualType = type(param)

		-- Handle special type checks
		if paramType == "Player" then
			if actualType ~= "userdata" or not param:IsA("Player") then
				error(string.format("Parameter %d for %s: expected Player, got %s",
					i, name, actualType))
			end
		elseif paramType == "Instance" then
			if actualType ~= "userdata" or not param:IsA("Instance") then
				error(string.format("Parameter %d for %s: expected Instance, got %s",
					i, name, actualType))
			end
		elseif actualType ~= paramType then
			error(string.format("Parameter %d for %s: expected %s, got %s",
				i, name, paramType, actualType))
		end
	end
end

-- Export singleton instance
return Network.GetInstance()