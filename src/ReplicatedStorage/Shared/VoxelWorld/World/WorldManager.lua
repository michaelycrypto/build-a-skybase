--[[
	WorldManager.lua
	Manages the world state and chunk loading/unloading
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local Chunk = require(script.Parent.Chunk)
local WorldTypes = require(script.Parent.Parent.Core.WorldTypes)

local WorldManager = {}
WorldManager.__index = WorldManager

function WorldManager.new(seed: number, worldTypeId: string?)
	local descriptor = WorldTypes:Get(worldTypeId)
	local generatorModule = descriptor.generatorModule
	local generatorOptions = descriptor.generatorOptions

	local self = setmetatable({
		seed = seed or 0, -- Default seed if none provided
        chunks = {}, -- Map of chunk coordinates to chunk data
		generator = generatorModule.new(seed or 0, generatorOptions),
        modifiedChunks = {}, -- Set of chunks that need saving
        chunkDataCache = {}, -- In-memory cache of unloaded modified chunks
        network = nil, -- Optional network interface for streaming
		worldTypeId = descriptor.id,
		worldDescriptor = descriptor,
		chunkBounds = nil,
	}, WorldManager)

	if self.generator and self.generator.GetChunkBounds then
		self.chunkBounds = self.generator:GetChunkBounds()
	end

	return self
end

function WorldManager:_isChunkOutsideBounds(chunkX: number, chunkZ: number): boolean
	local bounds = self.chunkBounds
	if not bounds then
		return false
	end
	if bounds.minChunkX and chunkX < bounds.minChunkX then
		return true
	end
	if bounds.maxChunkX and chunkX > bounds.maxChunkX then
		return true
	end
	if bounds.minChunkZ and chunkZ < bounds.minChunkZ then
		return true
	end
	if bounds.maxChunkZ and chunkZ > bounds.maxChunkZ then
		return true
	end
	return false
end

-- Get chunk key from coordinates
function WorldManager:GetChunkKey(x: number, z: number): string
	-- Ensure we have valid numbers
	if not x or not z then
		warn("Invalid chunk coordinates:", x, z)
		return "0,0" -- Default to origin chunk
	end
	return string.format("%d,%d", math.floor(x), math.floor(z))
end

-- Get chunk coordinates from key
function WorldManager:GetChunkCoords(key: string): (number, number)
	local x, z = string.match(key, "(-?%d+),(-?%d+)")
	return tonumber(x) or 0, tonumber(z) or 0
end

-- Quick test: is this chunk known-empty according to the generator?
function WorldManager:IsChunkEmpty(x: number, z: number): boolean
	if self:_isChunkOutsideBounds(math.floor(x), math.floor(z)) then
		return true
	end
    local key = self:GetChunkKey(x, z)
    local loaded = self.chunks[key]
    if loaded and loaded.IsEmpty and (not loaded:IsEmpty()) then
        return false
    end
    -- If we have cached serialized data for this chunk, it contains blocks
    if self.chunkDataCache[key] ~= nil then
        return false
    end
    if self.generator and self.generator.IsChunkEmpty then
        return self.generator:IsChunkEmpty(x, z)
    end
    -- Unknown generator: assume not empty to be safe
    return false
end

-- Get or create chunk at coordinates
function WorldManager:GetChunk(x: number, z: number, skipGeneration: boolean?)
	if not x or not z then
		warn("Invalid chunk request coordinates:", x, z)
		return nil
	end

	local key = self:GetChunkKey(x, z)

	if not self.chunks[key] then
		local chunk = Chunk.new(x, z)
		self.chunks[key] = chunk

		-- Check if we have cached data for this chunk
		local cachedData = self.chunkDataCache[key]

		if cachedData then
			-- Restore chunk from cache
			chunk:deserialize(cachedData)
			-- Keep it marked as modified since it has edits
			self.modifiedChunks[key] = true
			-- Remove from cache as it's now loaded
			self.chunkDataCache[key] = nil
		elseif not skipGeneration and self.generator then
			-- Generate terrain for brand new chunk
			self:GenerateChunk(chunk)
		end
	end

	return self.chunks[key]
end

-- Convert world coordinates to chunk coordinates
function WorldManager:WorldToChunk(x: number, z: number): (number, number)
	if not x or not z then
		warn("Invalid world coordinates:", x, z)
		return 0, 0
	end
	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	return chunkX, chunkZ
end

-- Set block at world coordinates
function WorldManager:SetBlock(x: number, y: number, z: number, blockId: number): boolean
	if not x or not y or not z or not blockId then
		warn("Invalid block coordinates or ID:", x, y, z, blockId)
		return false
	end

	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return false
	end

	local chunkX, chunkZ = self:WorldToChunk(x, z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return false
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

    chunk:setBlock(localX, y, localZ, blockId)

	-- Mark chunk as modified
	self.modifiedChunks[self:GetChunkKey(chunkX, chunkZ)] = true

	return true
end

-- Set block metadata at world coordinates
function WorldManager:SetBlockMetadata(x: number, y: number, z: number, metadata: number): boolean
	if not x or not y or not z then
		return false
	end

	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return false
	end

	local chunkX, chunkZ = self:WorldToChunk(x, z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return false
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	chunk:setMetadata(localX, y, localZ, metadata or 0)

	-- Mark chunk as modified
	self.modifiedChunks[self:GetChunkKey(chunkX, chunkZ)] = true

	return true
end

-- Get block metadata at world coordinates
function WorldManager:GetBlockMetadata(x: number, y: number, z: number): number
	if not x or not y or not z then
		return 0
	end

	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return 0
	end

	local chunkX, chunkZ = self:WorldToChunk(x, z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return 0
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	return chunk:getMetadata(localX, y, localZ)
end

-- Get block at world coordinates
function WorldManager:GetBlock(x: number, y: number, z: number): number
	if not x or not y or not z then
		warn("Invalid block coordinates:", x, y, z)
		return Constants.BlockType.AIR
	end

	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return Constants.BlockType.AIR
	end

	local chunkX, chunkZ = self:WorldToChunk(x, z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return Constants.BlockType.AIR
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	return chunk:getBlock(localX, y, localZ)
end

-- Generate terrain for chunk
function WorldManager:GenerateChunk(chunk)
	if not chunk then return end

	if chunk.state ~= Constants.ChunkState.EMPTY then
		return
	end

	chunk.state = Constants.ChunkState.GENERATING
	self.generator:GenerateChunk(chunk)
	chunk.state = Constants.ChunkState.READY
end

-- Get all modified chunks
function WorldManager:GetModifiedChunks(): {[string]: boolean}
	return self.modifiedChunks
end

-- Clear modified chunk flag
function WorldManager:ClearModified(chunkKey: string)
	self.modifiedChunks[chunkKey] = nil
end

-- Clean up resources
function WorldManager:Destroy()
	self.chunks = {}
	self.modifiedChunks = {}
	self.chunkDataCache = {}
	self.generator = nil
end

-- Unload a chunk by key (server-side memory cleanup)
function WorldManager:UnloadChunk(key: string)
    if not key then return end

    -- If chunk was modified, cache its data before unloading
    if self.modifiedChunks[key] and self.chunks[key] then
        local chunk = self.chunks[key]
        -- Serialize the chunk data for later restoration
        local serialized = chunk:serialize()
        if serialized then
            self.chunkDataCache[key] = serialized
        end
    end

    -- Remove from loaded chunks and modified set
    self.chunks[key] = nil
    self.modifiedChunks[key] = nil
end

-- Get cache statistics
function WorldManager:GetCacheStats()
    local cacheCount = 0
    for _ in pairs(self.chunkDataCache) do
        cacheCount += 1
    end

    local loadedCount = 0
    for _ in pairs(self.chunks) do
        loadedCount += 1
    end

    local modifiedCount = 0
    for _ in pairs(self.modifiedChunks) do
        modifiedCount += 1
    end

    return {
        cachedChunks = cacheCount,
        loadedChunks = loadedCount,
        modifiedChunks = modifiedCount
    }
end

return WorldManager