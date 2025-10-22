--[[
	RateLimited Mixin

	Adds rate limiting functionality to services - prevents excessive calls
	and implements throttling. Perfect for API endpoints and resource management.

	Usage:
	- Include in your service: local RateLimited = require(ServerScriptService.Server.Mixins.RateLimited)
	- Apply to service: RateLimited.Apply(self)
	- Use rate limiting: self:DefineRateLimit("purchase", 5, 60) -- 5 calls per 60 seconds
--]]

local RateLimited = {}

--[[
	Apply rate limiting capabilities to a service
--]]
function RateLimited.Apply(service)
	-- Initialize rate limiting state
	service._rateLimits = {}
	service._rateLimitData = {}

	-- Define a rate limit
	service.DefineRateLimit = function(self, actionName, maxCalls, windowSeconds)
		self._rateLimits[actionName] = {
			maxCalls = maxCalls,
			windowSeconds = windowSeconds
		}
		self._rateLimitData[actionName] = {}
	end

	-- Check if an action is rate limited
	service.IsRateLimited = function(self, actionName, playerId)
		local rateLimit = self._rateLimits[actionName]
		if not rateLimit then
			return false -- No rate limit defined
		end

		local playerData = self._rateLimitData[actionName][playerId]
		if not playerData then
			return false -- Player has no history
		end

		local currentTime = tick()
		local windowStart = currentTime - rateLimit.windowSeconds

		-- Clean up old entries
		local validCalls = {}
		for _, callTime in ipairs(playerData) do
			if callTime >= windowStart then
				table.insert(validCalls, callTime)
			end
		end

		self._rateLimitData[actionName][playerId] = validCalls

		-- Check if rate limit exceeded
		return #validCalls >= rateLimit.maxCalls
	end

	-- Record an action call
	service.RecordAction = function(self, actionName, playerId)
		if not self._rateLimitData[actionName] then
			self._rateLimitData[actionName] = {}
		end

		if not self._rateLimitData[actionName][playerId] then
			self._rateLimitData[actionName][playerId] = {}
		end

		table.insert(self._rateLimitData[actionName][playerId], tick())
	end

	-- Get remaining calls for a player
	service.GetRemainingCalls = function(self, actionName, playerId)
		local rateLimit = self._rateLimits[actionName]
		if not rateLimit then
			return math.huge -- No rate limit
		end

		local playerData = self._rateLimitData[actionName][playerId]
		if not playerData then
			return rateLimit.maxCalls -- No history
		end

		local currentTime = tick()
		local windowStart = currentTime - rateLimit.windowSeconds

		-- Count valid calls
		local validCalls = 0
		for _, callTime in ipairs(playerData) do
			if callTime >= windowStart then
				validCalls = validCalls + 1
			end
		end

		return math.max(0, rateLimit.maxCalls - validCalls)
	end

	-- Get time until rate limit resets
	service.GetResetTime = function(self, actionName, playerId)
		local rateLimit = self._rateLimits[actionName]
		if not rateLimit then
			return 0 -- No rate limit
		end

		local playerData = self._rateLimitData[actionName][playerId]
		if not playerData or #playerData == 0 then
			return 0 -- No history
		end

		local oldestCall = playerData[1]
		local resetTime = oldestCall + rateLimit.windowSeconds
		return math.max(0, resetTime - tick())
	end
end

return RateLimited