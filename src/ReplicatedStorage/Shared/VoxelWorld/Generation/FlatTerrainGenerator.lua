--[[
	FlatTerrainGenerator.lua
	Generates flat 16×16 chunk worlds for player-owned instances
	No Perlin noise - simple flat terrain with bedrock, stone, dirt, and grass layers
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local FlatTerrainGenerator = {}
FlatTerrainGenerator.__index = FlatTerrainGenerator

-- Flat terrain configuration
local FLAT_CONFIG = {
	BEDROCK_LAYERS = 3, -- Y=0-2: Bedrock
	STONE_TOP = 62, -- Y=3-62: Stone
	DIRT_TOP = 63, -- Y=63: Dirt
	GRASS_LEVEL = 64, -- Y=64: Grass surface
	WORLD_SIZE_CHUNKS = 16 -- 16×16 chunks per world
}

function FlatTerrainGenerator.new(seed: number)
	local self = setmetatable({
		seed = seed or 0,
		rng = Random.new(seed or 0)
	}, FlatTerrainGenerator)

	return self
end

-- Generate a single flat chunk
function FlatTerrainGenerator:GenerateChunk(chunk)
	-- Generate flat terrain for each column
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		for z = 0, Constants.CHUNK_SIZE_Z - 1 do
			-- Bedrock layers at bottom (Y=0-2)
			for y = 0, FLAT_CONFIG.BEDROCK_LAYERS - 1 do
				chunk:SetBlock(x, y, z, Constants.BlockType.BEDROCK)
			end

			-- Stone from Y=3 up to Y=62
			for y = FLAT_CONFIG.BEDROCK_LAYERS, FLAT_CONFIG.STONE_TOP do
				chunk:SetBlock(x, y, z, Constants.BlockType.STONE)
			end

			-- Dirt layer at Y=63
			chunk:SetBlock(x, FLAT_CONFIG.DIRT_TOP, z, Constants.BlockType.DIRT)

			-- Grass surface at Y=64
			chunk:SetBlock(x, FLAT_CONFIG.GRASS_LEVEL, z, Constants.BlockType.GRASS)

			-- Update heightmap
			local idx = x + z * Constants.CHUNK_SIZE_X
			chunk.heightMap[idx] = FLAT_CONFIG.GRASS_LEVEL
		end
	end

	chunk.state = Constants.ChunkState.READY
end

-- Generate all chunks for a 16×16 world
-- Returns array of 256 chunks
function FlatTerrainGenerator:GenerateWorld()
	local Chunk = require(script.Parent.Parent.World.Chunk)
	local chunks = {}

	for chunkX = 0, FLAT_CONFIG.WORLD_SIZE_CHUNKS - 1 do
		for chunkZ = 0, FLAT_CONFIG.WORLD_SIZE_CHUNKS - 1 do
			local chunk = Chunk.new(chunkX, chunkZ)
			self:GenerateChunk(chunk)
			local key = string.format("%d,%d", chunkX, chunkZ)
			chunks[key] = chunk
		end
	end

	return chunks
end

-- Get world size in chunks
function FlatTerrainGenerator:GetWorldSizeChunks(): number
	return FLAT_CONFIG.WORLD_SIZE_CHUNKS
end

-- Get grass level (spawn height)
function FlatTerrainGenerator:GetGrassLevel(): number
	return FLAT_CONFIG.GRASS_LEVEL
end

return FlatTerrainGenerator

