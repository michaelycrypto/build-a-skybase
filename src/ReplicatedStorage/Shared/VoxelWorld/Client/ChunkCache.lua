--[[
	ChunkCache.lua

	Client-side chunk caching and predictive loading.
	Uses LRU cache for recently unloaded chunks and
	predicts future chunk needs based on movement.

	Features:
	- LRU cache for recently unloaded chunks
	- Movement-based prediction
	- View direction prioritization
	- Memory-aware caching
	- Cache statistics tracking
]]

local RunService = game:GetService("RunService")
local Constants = require(script.Parent.Parent.Core.Constants)

local ChunkCache = {}
ChunkCache.__index = ChunkCache

-- Cache entry states
local CacheState = {
	CACHED = "CACHED",     -- In cache, ready for reuse
	PREDICTED = "PREDICTED" -- Predicted to be needed soon
}

--[=[
	Create a new chunk cache
	@param config table - Configuration options
	@return ChunkCache
]=]
function ChunkCache.new(config)
	local self = setmetatable({}, ChunkCache)

	-- Configuration
	self.config = {
		maxCacheSize = config.maxCacheSize or 64, -- Maximum chunks to cache
		predictionRadius = config.predictionRadius or 3, -- Chunks ahead to predict
		predictionAngle = config.predictionAngle or math.rad(60), -- View cone angle
		cacheTimeoutSeconds = config.cacheTimeoutSeconds or 30, -- Time before cache entry expires
		memoryThresholdMB = config.memoryThresholdMB or 512, -- Memory threshold for caching
	}

	-- Cache storage
	self.cache = {} -- [chunkKey] = {chunk, state, timestamp}
	self.lruList = {} -- Ordered list of chunk keys by last use

	-- Prediction state
	self.lastPosition = nil -- Vector3
	self.velocity = Vector3.new(0, 0, 0)
	self.viewDirection = Vector3.new(0, 0, 1)

	-- Statistics
	self.stats = {
		cacheHits = 0,
		cacheMisses = 0,
		predictedHits = 0,
		totalPredictions = 0,
		averageHitTime = 0,
		memoryUsageMB = 0
	}

	-- Start update loop
	self:StartUpdateLoop()

	return self
end

--[=[
	Add a chunk to the cache
	@param chunk table - The chunk to cache
	@param chunkX number
	@param chunkZ number
]=]
function ChunkCache:CacheChunk(chunk, chunkX, chunkZ)
	-- Check memory threshold
	local memory = gcinfo() / 1024 -- MB
	if memory > self.config.memoryThresholdMB then
		-- Memory pressure, don't cache
		return
	end

	local key = string.format("%d,%d", chunkX, chunkZ)

	-- Remove oldest entry if cache is full
	while #self.lruList >= self.config.maxCacheSize do
		local oldestKey = table.remove(self.lruList)
		self.cache[oldestKey] = nil
	end

	-- Add to cache
	self.cache[key] = {
		chunk = chunk,
		state = CacheState.CACHED,
		timestamp = os.clock()
	}
	table.insert(self.lruList, 1, key)

	-- Update memory usage stat
	self.stats.memoryUsageMB = memory
end

--[=[
	Try to get a chunk from cache
	@param chunkX number
	@param chunkZ number
	@return table - The chunk if found, nil otherwise
]=]
function ChunkCache:GetChunk(chunkX, chunkZ)
	local key = string.format("%d,%d", chunkX, chunkZ)
	local entry = self.cache[key]

	if entry then
		-- Update LRU order
		local index = table.find(self.lruList, key)
		if index then
			table.remove(self.lruList, index)
			table.insert(self.lruList, 1, key)
		end

		-- Update stats
		if entry.state == CacheState.PREDICTED then
			self.stats.predictedHits = self.stats.predictedHits + 1
		end
		self.stats.cacheHits = self.stats.cacheHits + 1

		-- Calculate average hit time
		local hitTime = os.clock() - entry.timestamp
		self.stats.averageHitTime = (self.stats.averageHitTime * (self.stats.cacheHits - 1) + hitTime) / self.stats.cacheHits

		return entry.chunk
	end

	self.stats.cacheMisses = self.stats.cacheMisses + 1
	return nil
end

--[=[
	Update movement prediction
	@param position Vector3
]=]
function ChunkCache:UpdatePosition(position)
	if self.lastPosition then
		-- Calculate velocity
		local delta = position - self.lastPosition
		local dt = RunService.Heartbeat:Wait()
		if dt > 0 then
			-- Smooth velocity using exponential moving average
			local alpha = 0.3
			self.velocity = self.velocity * (1 - alpha) + (delta / dt) * alpha
		end
	end
	self.lastPosition = position

	-- Update view direction from velocity
	if self.velocity.Magnitude > 0.1 then
		self.viewDirection = self.velocity.Unit
	end
end

--[=[
	Predict which chunks will be needed soon
]=]
function ChunkCache:UpdatePredictions()
	if not self.lastPosition then return end

	-- Convert position to chunk coordinates
	local chunkX = math.floor(self.lastPosition.X / Constants.CHUNK_WORLD_SIZE_X)
	local chunkZ = math.floor(self.lastPosition.Z / Constants.CHUNK_WORLD_SIZE_Z)

	-- Clear old predictions
	for _, entry in pairs(self.cache) do
		if entry.state == CacheState.PREDICTED then
			entry.state = CacheState.CACHED
		end
	end

	-- Predict chunks in view direction
	local predictions = {}
	for r = 1, self.config.predictionRadius do
		for dx = -r, r do
			for dz = -r, r do
				-- Skip if too far from prediction line
				local offset = Vector3.new(dx * Constants.CHUNK_WORLD_SIZE_X, 0, dz * Constants.CHUNK_WORLD_SIZE_Z)
				local angle = math.acos(offset.Unit:Dot(self.viewDirection))
				if angle <= self.config.predictionAngle then
					local key = string.format("%d,%d", chunkX + dx, chunkZ + dz)
					if self.cache[key] then
						self.cache[key].state = CacheState.PREDICTED
						table.insert(predictions, key)
					end
				end
			end
		end
	end

	self.stats.totalPredictions = #predictions
end

--[=[
	Clean up expired cache entries
]=]
function ChunkCache:CleanupCache()
	local now = os.clock()
	local memory = gcinfo() / 1024 -- MB

	-- More aggressive cleanup under memory pressure
	local timeout = memory > self.config.memoryThresholdMB
		and self.config.cacheTimeoutSeconds * 0.5
		or self.config.cacheTimeoutSeconds

	-- Remove expired entries
	for i = #self.lruList, 1, -1 do
		local key = self.lruList[i]
		local entry = self.cache[key]
		if entry and (now - entry.timestamp) > timeout then
			table.remove(self.lruList, i)
			self.cache[key] = nil
		end
	end

	-- Update memory usage stat
	self.stats.memoryUsageMB = memory
end

--[=[
	Start the update loop
]=]
function ChunkCache:StartUpdateLoop()
	RunService.Heartbeat:Connect(function()
		self:UpdatePredictions()
		self:CleanupCache()
	end)
end

--[=[
	Get cache statistics
	@return table
]=]
function ChunkCache:GetStats()
	local hitRate = self.stats.cacheHits / (self.stats.cacheHits + self.stats.cacheMisses + 0.001)
	local predictionAccuracy = self.stats.predictedHits / (self.stats.totalPredictions + 0.001)

	return {
		cacheSize = #self.lruList,
		maxSize = self.config.maxCacheSize,
		hitRate = hitRate,
		predictionAccuracy = predictionAccuracy,
		averageHitTime = self.stats.averageHitTime,
		memoryUsageMB = self.stats.memoryUsageMB
	}
end

--[=[
	Clean up
]=]
function ChunkCache:Destroy()
	self.cache = {}
	self.lruList = {}
	self.lastPosition = nil
	self.velocity = Vector3.new(0, 0, 0)
end

return ChunkCache
