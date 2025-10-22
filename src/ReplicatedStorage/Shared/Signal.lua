--[[
	Signal

	Lightweight signal/event system for decoupled communication.
	Provides a clean alternative to BindableEvents for internal messaging.

	Features:
	- Type-safe signal creation
	- Connection management
	- Automatic cleanup
	- Performance optimized
--]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)

	self._connections = {} -- array of connection functions
	self._connectionCount = 0

	return self
end

--[[
	Connect a callback to this signal
	@param callback function - Function to call when signal is fired
	@return table - Connection object with Disconnect method
--]]
function Signal:Connect(callback)
	assert(type(callback) == "function", "Callback must be a function")

	self._connectionCount = self._connectionCount + 1
	local connectionId = self._connectionCount

	self._connections[connectionId] = callback

	-- Return connection object
	local connection = {
		Connected = true,

		Disconnect = function()
			if self._connections[connectionId] then
				self._connections[connectionId] = nil
				connection.Connected = false
			end
		end
	}

	return connection
end

--[[
	Fire the signal with arguments
	@param ... any - Arguments to pass to connected callbacks
--]]
function Signal:Fire(...)
	local args = {...}

	for _, callback in pairs(self._connections) do
		if callback then
			-- Use spawn to prevent one callback from blocking others
			spawn(function()
				callback(unpack(args))
			end)
		end
	end
end

--[[
	Wait for the signal to be fired
	@return ... - Arguments passed to Fire
--]]
function Signal:Wait()
	local thread = coroutine.running()
	local connection

	connection = self:Connect(function(...)
		connection:Disconnect()
		coroutine.resume(thread, ...)
	end)

	return coroutine.yield()
end

--[[
	Disconnect all connections
--]]
function Signal:DisconnectAll()
	for connectionId, _ in pairs(self._connections) do
		self._connections[connectionId] = nil
	end
end

--[[
	Destroy the signal and cleanup resources
--]]
function Signal:Destroy()
	self:DisconnectAll()
	setmetatable(self, nil)
end

--[[
	Get the number of active connections
--]]
function Signal:GetConnectionCount()
	local count = 0
	for _, _ in pairs(self._connections) do
		count = count + 1
	end
	return count
end

return Signal