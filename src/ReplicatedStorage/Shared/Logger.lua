--[[
	Logger

	Structured logging system for observability and diagnostics.
	Supports multiple log levels, contexts, and structured data.

	Features:
	- Structured logging with context
	- Multiple log levels (Debug, Info, Warn, Error)
	- Service-specific logging contexts
	- Performance metrics
	- Remote logging support
--]]

local RunService = game:GetService("RunService")

local Logger = {}
Logger.__index = Logger

-- Log levels (higher number = higher severity)
local LogLevel = {
	DEBUG = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
	FATAL = 5
}

-- Global logger instance
local _instance = nil

function Logger.new()
	local self = setmetatable({}, Logger)

	self._logLevel = LogLevel.INFO -- Default log level
	self._contexts = {} -- service -> context data
	self._remoteLogger = nil -- For remote logging
	self._buffer = {} -- Log buffer for batching
	self._metrics = {} -- Performance metrics

	-- Initialize remote logging if on server
	if RunService:IsServer() then
		self:_initRemoteLogging()
	end

	return self
end

function Logger.GetInstance()
	if not _instance then
		_instance = Logger.new()
	end
	return _instance
end

--[[
	Initialize the Logger with configuration
--]]
function Logger:Initialize(config, network)
	config = config or {}

	-- Set log level from config
	if config.LEVEL then
		local levelMap = {
			DEBUG = LogLevel.DEBUG,
			INFO = LogLevel.INFO,
			WARN = LogLevel.WARN,
			ERROR = LogLevel.ERROR,
			FATAL = LogLevel.FATAL
		}
		self._logLevel = levelMap[config.LEVEL] or LogLevel.INFO
	end

	-- Set remote logger
	self._remoteLogger = network

	-- Logger initialized
	return true
end

--[[
	Set the minimum log level
--]]
function Logger:SetLogLevel(level)
	assert(type(level) == "number", "Log level must be a number")
	self._logLevel = level
end

--[[
	Create a logger context for a service
	@param serviceName string - Name of the service
	@param context table - Additional context data
	@return table - Logger context
--]]
function Logger:CreateContext(serviceName, context)
	assert(type(serviceName) == "string", "Service name must be a string")
	context = context or {}

	local loggerContext = {
		service = serviceName,
		context = context,

		Debug = function(message, data)
			self:_log(LogLevel.DEBUG, serviceName, message, data)
		end,

		Info = function(message, data)
			self:_log(LogLevel.INFO, serviceName, message, data)
		end,

		Warn = function(message, data)
			self:_log(LogLevel.WARN, serviceName, message, data)
		end,

		Error = function(message, data)
			self:_log(LogLevel.ERROR, serviceName, message, data)
		end,

		Fatal = function(message, data)
			self:_log(LogLevel.FATAL, serviceName, message, data)
		end,

		-- Performance tracking
		StartTimer = function(name)
			local key = serviceName .. "." .. name
			self._metrics[key] = tick()
		end,

		EndTimer = function(name)
			local key = serviceName .. "." .. name
			if self._metrics[key] then
				local duration = tick() - self._metrics[key]
				self:_log(LogLevel.INFO, serviceName, "Timer", {
					name = name,
					duration = duration
				})
				self._metrics[key] = nil
			end
		end
	}

	self._contexts[serviceName] = loggerContext
	return loggerContext
end

--[[
	Get existing logger context for a service
--]]
function Logger:GetContext(serviceName)
	return self._contexts[serviceName]
end

--[[
	Global logging methods
--]]
function Logger:Debug(message, data)
	self:_log(LogLevel.DEBUG, "Global", message, data)
end

function Logger:Info(message, data)
	self:_log(LogLevel.INFO, "Global", message, data)
end

function Logger:Warn(message, data)
	self:_log(LogLevel.WARN, "Global", message, data)
end

function Logger:Error(message, data)
	self:_log(LogLevel.ERROR, "Global", message, data)
end

function Logger:Fatal(message, data)
	self:_log(LogLevel.FATAL, "Global", message, data)
end

--[[
	Internal logging implementation
--]]
function Logger:_log(level, service, message, data)
	if level < self._logLevel then
		return -- Skip if below minimum log level
	end

	local timestamp = os.date("%Y-%m-%d %H:%M:%S")
	local levelName = self:_getLevelName(level)

	local logEntry = {
		timestamp = timestamp,
		level = levelName,
		service = service,
		message = message,
		data = data,
		server = RunService:IsServer()
	}

	-- Format and output to console
	local formatted = self:_formatLogEntry(logEntry)

	if level >= LogLevel.ERROR then
		warn(formatted)
	else
		print(formatted)
	end

	-- Add to buffer for remote logging
	table.insert(self._buffer, logEntry)

	-- Flush buffer if it gets too large
	if #self._buffer >= 50 then
		self:_flushBuffer()
	end
end

--[[
	Format log entry for console output
--]]
function Logger:_formatLogEntry(entry)
	local parts = {
		"[" .. entry.timestamp .. "]",
		"[" .. entry.level .. "]",
		"[" .. entry.service .. "]",
		entry.message
	}

	local formatted = table.concat(parts, " ")

	if entry.data then
		local dataStr = self:_serializeData(entry.data)
		formatted = formatted .. " | " .. dataStr
	end

	return formatted
end

--[[
	Serialize data for logging
--]]
function Logger:_serializeData(data)
	if type(data) == "table" then
		local parts = {}
		for key, value in pairs(data) do
			table.insert(parts, tostring(key) .. "=" .. tostring(value))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	else
		return tostring(data)
	end
end

--[[
	Get human-readable level name
--]]
function Logger:_getLevelName(level)
	for name, value in pairs(LogLevel) do
		if value == level then
			return name
		end
	end
	return "UNKNOWN"
end

--[[
	Initialize remote logging (server only)
--]]
function Logger:_initRemoteLogging()
	-- This could be extended to send logs to external services
	-- For now, it's a placeholder for future implementation
end

--[[
	Flush log buffer
--]]
function Logger:_flushBuffer()
	-- In a real implementation, this would send logs to a remote service
	-- For now, we just clear the buffer
	self._buffer = {}
end

-- Export log levels for external use
Logger.LogLevel = LogLevel

-- Export singleton instance
return Logger.GetInstance()