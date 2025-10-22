--[[
	WorldInstance.lua
	Represents a single player-owned world instance
	Each instance has 16×16 chunks, metadata, and player tracking
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local FlatTerrainGenerator = require(script.Parent.Parent.Generation.FlatTerrainGenerator)

local WorldInstance = {}
WorldInstance.__index = WorldInstance

function WorldInstance.new(worldId: string, metadata: table)
	local self = setmetatable({
		id = worldId,
		chunks = {}, -- Map of chunkKey -> Chunk
		players = {}, -- Set of players currently in this world
		metadata = metadata or {},
		generator = FlatTerrainGenerator.new(metadata.seed or 0),
		modifiedChunks = {}, -- Set of chunks that need saving
		isLoaded = false,
		createdAt = os.time(),
		lastAccessTime = os.clock()
	}, WorldInstance)

	-- Set default metadata
	self.metadata = {
		id = worldId,
		owner = metadata.owner or 0,
		name = metadata.name or "Untitled World",
		created = metadata.created or os.time(),
		seed = metadata.seed or math.random(1, 999999),
		isPublic = metadata.isPublic or false,
		maxPlayers = metadata.maxPlayers or 10,
		allowBuilding = metadata.allowBuilding ~= false -- Default true
	}

	return self
end

-- Load world (generate or deserialize chunks)
function WorldInstance:Load(chunkData)
	if self.isLoaded then
		return
	end

	if chunkData and next(chunkData) then
		-- Deserialize existing chunks
		self:DeserializeChunks(chunkData)
	else
		-- Generate new flat world
		self.chunks = self.generator:GenerateWorld()
	end

	self.isLoaded = true
	self.lastAccessTime = os.clock()
end

-- Unload world (keep metadata, clear chunks)
function WorldInstance:Unload()
	self.chunks = {}
	self.isLoaded = false
end

-- Add player to world
function WorldInstance:AddPlayer(player: Player)
	if not player then return false end

	-- Check max players
	local currentCount = 0
	for _ in pairs(self.players) do
		currentCount += 1
	end

	if currentCount >= self.metadata.maxPlayers then
		return false, "world_full"
	end

	self.players[player] = true
	self.lastAccessTime = os.clock()
	return true
end

-- Remove player from world
function WorldInstance:RemovePlayer(player: Player)
	if not player then return end
	self.players[player] = nil
	self.lastAccessTime = os.clock()
end

-- Check if world is empty
function WorldInstance:IsEmpty(): boolean
	for _ in pairs(self.players) do
		return false
	end
	return true
end

-- Get player count
function WorldInstance:GetPlayerCount(): number
	local count = 0
	for _ in pairs(self.players) do
		count += 1
	end
	return count
end

-- Get chunk by coordinates
function WorldInstance:GetChunk(x: number, z: number)
	local key = string.format("%d,%d", math.floor(x), math.floor(z))
	return self.chunks[key]
end

-- Set block at world coordinates
function WorldInstance:SetBlock(x: number, y: number, z: number, blockId: number): boolean
	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return false
	end

	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return false
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	chunk:setBlock(localX, y, localZ, blockId)

	-- Mark chunk as modified
	local key = string.format("%d,%d", chunkX, chunkZ)
	self.modifiedChunks[key] = true
	self.lastAccessTime = os.clock()

	return true
end

-- Get block at world coordinates
function WorldInstance:GetBlock(x: number, y: number, z: number): number
	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return Constants.BlockType.AIR
	end

	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return Constants.BlockType.AIR
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	return chunk:getBlock(localX, y, localZ)
end

-- Convert world coordinates to chunk coordinates
function WorldInstance:WorldToChunk(x: number, z: number): (number, number)
	return math.floor(x / Constants.CHUNK_SIZE_X), math.floor(z / Constants.CHUNK_SIZE_Z)
end

-- Get chunk key
function WorldInstance:GetChunkKey(x: number, z: number): string
	return string.format("%d,%d", math.floor(x), math.floor(z))
end

-- Serialize chunks for saving
function WorldInstance:SerializeChunks()
	local serialized = {}

	for key, chunk in pairs(self.chunks) do
		if chunk and chunk.serialize then
			serialized[key] = chunk:serialize()
		end
	end

	return serialized
end

-- Deserialize chunks from saved data
function WorldInstance:DeserializeChunks(chunkData)
	local Chunk = require(script.Parent.Chunk)

	for key, data in pairs(chunkData) do
		if data and data.x and data.z then
			local chunk = Chunk.new(data.x, data.z)
			if chunk.deserialize then
				chunk:deserialize(data)
			end
			self.chunks[key] = chunk
		end
	end
end

-- Get modified chunks
function WorldInstance:GetModifiedChunks(): {[string]: boolean}
	return self.modifiedChunks
end

-- Clear modified flag for chunk
function WorldInstance:ClearModified(chunkKey: string)
	self.modifiedChunks[chunkKey] = nil
end

-- Get world spawn position (center of world at grass level)
function WorldInstance:GetSpawnPosition(): Vector3
	local worldSize = self.generator:GetWorldSizeChunks()
	local grassLevel = self.generator:GetGrassLevel()

	-- Spawn at center of world
	local centerX = (worldSize * Constants.CHUNK_SIZE_X / 2) * Constants.BLOCK_SIZE
	local centerZ = (worldSize * Constants.CHUNK_SIZE_Z / 2) * Constants.BLOCK_SIZE
	local spawnY = (grassLevel + 2) * Constants.BLOCK_SIZE -- 2 blocks above grass

	return Vector3.new(centerX, spawnY, centerZ)
end

-- Update metadata
function WorldInstance:UpdateMetadata(updates: table)
	for key, value in pairs(updates) do
		if self.metadata[key] ~= nil then
			self.metadata[key] = value
		end
	end
	self.lastAccessTime = os.clock()
end

-- Clean up
function WorldInstance:Destroy()
	self.chunks = {}
	self.players = {}
	self.modifiedChunks = {}
	self.generator = nil
end

return WorldInstance

