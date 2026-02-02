--[[
	ChunkManager.lua
	Manages chunk loading, unloading, and streaming
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local Config = require(script.Parent.Parent.Core.Config)

local ChunkManager = {}
ChunkManager.__index = ChunkManager

function ChunkManager.new(worldManager, renderDistance)
	local self = setmetatable({
		worldManager = worldManager,
		renderDistance = math.clamp(renderDistance or 1, 1, (Config and Config.PERFORMANCE and Config.PERFORMANCE.MAX_RENDER_DISTANCE) or 32),
		activeChunks = {}, -- Map of chunk key -> last access time
		loadQueue = {}, -- Priority queue for chunk loading
		unloadQueue = {}, -- Queue for chunk unloading
        meshUpdateQueue = {}, -- Compatibility: queue of chunkKey -> chunk to remesh
		stats = {
			loadedCount = 0,
			unloadedCount = 0,
			lastLoadTime = 0
		}
	}, ChunkManager)

	return self
end

-- Get chunks needed for position
function ChunkManager:GetNeededChunks(centerX: number, centerZ: number)
	local needed = {}
	local centerChunkX = math.floor(centerX / Constants.CHUNK_SIZE_X)
	local centerChunkZ = math.floor(centerZ / Constants.CHUNK_SIZE_Z)

	-- Spiral outward to get chunks in order of distance
	local x, z = 0, 0
	local dx, dz = 0, -1
	local maxDist = self.renderDistance * self.renderDistance

	for _ = 1, (self.renderDistance * 2 + 1) ^ 2 do
		if -self.renderDistance <= x and x <= self.renderDistance and
		   -self.renderDistance <= z and z <= self.renderDistance then
			local dist = x * x + z * z
			if dist <= maxDist then
				local chunkX = centerChunkX + x
				local chunkZ = centerChunkZ + z
				local key = self.worldManager:GetChunkKey(chunkX, chunkZ)

				if not self.activeChunks[key] then
					table.insert(needed, {
						x = chunkX,
						z = chunkZ,
						distance = math.sqrt(dist),
						key = key
					})
				end
			end
		end

		if x == z or (x < 0 and x == -z) or (x > 0 and x == 1-z) then
			dx, dz = -dz, dx
		end
		x, z = x + dx, z + dz
	end

	-- Sort by distance
	table.sort(needed, function(a, b)
		return a.distance < b.distance
	end)

	return needed
end

-- Get chunks to unload
function ChunkManager:GetUnloadableChunks(centerX: number, centerZ: number)
	local unloadable = {}
	local centerChunkX = math.floor(centerX / Constants.CHUNK_SIZE_X)
	local centerChunkZ = math.floor(centerZ / Constants.CHUNK_SIZE_Z)
	local maxDist = (self.renderDistance + 2) * Constants.CHUNK_SIZE_X -- Add buffer

	for key, lastAccess in pairs(self.activeChunks) do
		local chunkX, chunkZ = self.worldManager:GetChunkCoords(key)
		local dx = (chunkX - centerChunkX) * Constants.CHUNK_SIZE_X
		local dz = (chunkZ - centerChunkZ) * Constants.CHUNK_SIZE_Z
		local dist = math.sqrt(dx * dx + dz * dz)

		if dist > maxDist or os.clock() - lastAccess > Config.CHUNK_UNLOAD_DELAY then
			table.insert(unloadable, {
				key = key,
				distance = dist
			})
		end
	end

	return unloadable
end

-- Update chunk loading/unloading
function ChunkManager:Update(centerX: number, centerZ: number)
	-- Get chunks to load/unload
	local needed = self:GetNeededChunks(centerX, centerZ)
	local unloadable = self:GetUnloadableChunks(centerX, centerZ)

	-- Unload far chunks
	for _, chunk in ipairs(unloadable) do
		self:UnloadChunk(chunk.key)
	end

	-- Load nearest chunks first
	local maxLoadsPerUpdate = Config.PERFORMANCE.MAX_CHUNKS_PER_FRAME
	local loaded = 0

	for _, chunk in ipairs(needed) do
		if loaded >= maxLoadsPerUpdate then
			break
		end

		if self:LoadChunk(chunk.x, chunk.z) then
			loaded += 1
		end
	end

	-- Update stats
	self.stats.lastLoadTime = os.clock()
end

-- Load single chunk
function ChunkManager:LoadChunk(chunkX: number, chunkZ: number): boolean
	local key = self.worldManager:GetChunkKey(chunkX, chunkZ)

	if self.activeChunks[key] then
		return false -- Already loaded
	end

	-- Get or generate chunk
	local chunk = self.worldManager:GetChunk(chunkX, chunkZ)
	if not chunk then
		return false
	end

	-- Mark as active
	self.activeChunks[key] = os.clock()
	self.stats.loadedCount += 1

	return true
end

-- Unload single chunk
function ChunkManager:UnloadChunk(key: string)
	if not self.activeChunks[key] then
		return -- Not loaded
	end

	-- Save if modified
	if self.worldManager.modifiedChunks[key] then
		local x, z = self.worldManager:GetChunkCoords(key)
		self.worldManager:SaveChunk(x, z)
	end

	-- Remove from active chunks and world storage to free memory
	self.activeChunks[key] = nil
	if self.worldManager and self.worldManager.UnloadChunk then
		self.worldManager:UnloadChunk(key)
	end
	self.stats.unloadedCount += 1
end

-- Get statistics
function ChunkManager:GetStats()
	local activeCount = 0
	for _ in pairs(self.activeChunks) do
		activeCount += 1
	end

	return {
		loadedChunks = self.stats.loadedCount,
		unloadedChunks = self.stats.unloadedCount,
		activeChunks = activeCount,
		lastLoadTime = os.clock() - self.stats.lastLoadTime
	}
end

-- Clean up
function ChunkManager:Destroy()
	-- Unload all chunks
	for key in pairs(self.activeChunks) do
		self:UnloadChunk(key)
	end

	self.activeChunks = {}
	self.loadQueue = {}
	self.unloadQueue = {}
end

return ChunkManager