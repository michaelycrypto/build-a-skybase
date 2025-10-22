--[[
	State - Simplified Framework-Compliant State Management

	Follows the framework specification:
	- Simple state slices with DEFAULT and Validate
	- Server authority with client read-only access
	- Network-based state synchronization
	- Minimal API surface
--]]

local Network = require(script.Parent.Network)
local CurrencyState = require(script.Parent.StateSlices.CurrencyState)
local InventoryState = require(script.Parent.StateSlices.InventoryState)
local DungeonState = require(script.Parent.StateSlices.DungeonState)

local State = {}
State.__index = State

-- State slice registry
local STATE_SLICES = {
	currency = CurrencyState,
	inventory = InventoryState,
	dungeon = DungeonState
}

function State.new()
	local self = setmetatable({}, State)

	-- Initialize state from slices
	self._state = {}
	for sliceName, slice in pairs(STATE_SLICES) do
		self._state[sliceName] = self:_deepCopy(slice.DEFAULT)
	end

	-- Subscribers for state changes
	self._subscribers = {}

	-- Network instance
	self._network = Network.GetInstance()

	-- Setup network events (following framework spec)
	self:_setupNetworkEvents()

	return self
end

--[[
	Get current state (read-only)
	Following framework pattern: clients treat state as read-only
--]]
function State:GetState(sliceName)
	if sliceName then
		return self:_deepCopy(self._state[sliceName])
	end
	return self:_deepCopy(self._state)
end

--[[
	Update state slice (server only)
	Following framework: server mutates then fires StateChanged via Network
--]]
function State:UpdateSlice(sliceName, newValue, path)
	local slice = STATE_SLICES[sliceName]
	if not slice then
		warn("Unknown state slice:", sliceName)
		return false
	end

	-- Validate new state
	if not slice.Validate(newValue) then
		warn("Invalid state for slice:", sliceName)
		return false
	end

	-- Update state
	local oldValue = self._state[sliceName]
	self._state[sliceName] = self:_deepCopy(newValue)

	-- Fire network event (following framework spec)
	self._network:DefineEvent("StateChanged", {"string", "any"}):Fire(sliceName, newValue)

	-- Notify local subscribers
	self:_notifySubscribers(sliceName, newValue, oldValue)

	return true
end

--[[
	Subscribe to state changes
	Reactive pattern for UI updates
--]]
function State:Subscribe(sliceName, callback)
	if not self._subscribers[sliceName] then
		self._subscribers[sliceName] = {}
	end

	local id = #self._subscribers[sliceName] + 1
	self._subscribers[sliceName][id] = callback

	-- Return unsubscribe function
	return function()
		self._subscribers[sliceName][id] = nil
	end
end

--[[
	Setup network events following framework specification
--]]
function State:_setupNetworkEvents()
	-- StateChanged event for client synchronization
	local stateChangedEvent = self._network:DefineEvent("StateChanged", {"string", "any"})
	stateChangedEvent:Connect(function(sliceName, newValue)
		-- Client receives server state updates (read-only)
		local oldValue = self._state[sliceName]
		self._state[sliceName] = newValue
		self:_notifySubscribers(sliceName, newValue, oldValue)
	end)
end

--[[
	Notify subscribers of state changes
--]]
function State:_notifySubscribers(sliceName, newValue, oldValue)
	local subscribers = self._subscribers[sliceName]
	if not subscribers then return end

	for _, callback in pairs(subscribers) do
		spawn(function()
			callback(newValue, oldValue)
		end)
	end
end

--[[
	Deep copy utility
--]]
function State:_deepCopy(original)
	if type(original) ~= "table" then
		return original
	end

	local copy = {}
	for key, value in pairs(original) do
		copy[key] = self:_deepCopy(value)
	end

	return copy
end

--[[
	Helper: Create state with validation
	Following framework pattern for new state creation
--]]
function State:CreateValidatedState(sliceName, data)
	local slice = STATE_SLICES[sliceName]
	if not slice then
		return nil, "Unknown slice: " .. sliceName
	end

	-- Merge with defaults
	local newState = self:_deepCopy(slice.DEFAULT)
	for key, value in pairs(data) do
		newState[key] = value
	end

	-- Validate
	if not slice.Validate(newState) then
		return nil, "Validation failed for slice: " .. sliceName
	end

	return newState
end

return State