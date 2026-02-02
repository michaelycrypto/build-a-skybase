--[[
	TerrainGenerator.lua
	Plains-focused terrain generation with gentle rolling hills
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local NoiseGenerator = require(script.Parent.NoiseGenerator)

local TerrainGenerator = {}
TerrainGenerator.__index = TerrainGenerator

-- Plains biome configuration
local PLAINS_CONFIG = {
	BASE_HEIGHT = 64, -- Base terrain height
	NOISE_SCALE = 0.02, -- Lower -> broader hills (smoother terrain)
	NOISE_OCTAVES = 2,
	NOISE_PERSISTENCE = 0.35,
	NOISE_AMPLITUDE = 8, -- Max +/- variation from base (gentle hills)
	DIRT_DEPTH = 3 -- Number of dirt layers under grass
}

function TerrainGenerator.new(seed: number)
	local self = setmetatable({
		seed = seed,
        rng = Random.new(seed),
        noise = NoiseGenerator.new(seed)
	}, TerrainGenerator)

	return self
end

-- Get deterministic RNG for a position
function TerrainGenerator:GetPositionRNG(wx: number, wz: number)
	local positionSeed = wx * 48271 + wz * 16807 + self.seed
	return Random.new(positionSeed)
end

-- Get height at world position
function TerrainGenerator:GetHeight(wx: number, wz: number): number
    -- Octaved Perlin noise for gentle plains undulation
    local n = self.noise:OctaveNoise2D(
        wx * PLAINS_CONFIG.NOISE_SCALE,
        wz * PLAINS_CONFIG.NOISE_SCALE,
        PLAINS_CONFIG.NOISE_OCTAVES,
        PLAINS_CONFIG.NOISE_PERSISTENCE
    ) -- in [-1, 1]

    local height = PLAINS_CONFIG.BASE_HEIGHT + math.floor(n * PLAINS_CONFIG.NOISE_AMPLITUDE)
    -- Keep within world bounds and leave headroom for decorations/trees
    height = math.clamp(height, 1, Constants.WORLD_HEIGHT - 4)
    return height
end

-- Generate a single chunk
function TerrainGenerator:GenerateChunk(chunk)
	-- Get world coordinates of chunk corner
	local worldX = chunk.x * Constants.CHUNK_SIZE_X
	local worldZ = chunk.z * Constants.CHUNK_SIZE_Z

	-- Generate terrain for each column
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		for z = 0, Constants.CHUNK_SIZE_Z - 1 do
			local wx = worldX + x
			local wz = worldZ + z

			-- Get height for this position
			local height = self:GetHeight(wx, wz)
			local dirtTop = math.max(1, height - 1)
			local dirtBottom = math.max(1, height - PLAINS_CONFIG.DIRT_DEPTH)

			-- Bedrock at y=0
			chunk:SetBlock(x, 0, z, Constants.BlockType.BEDROCK)

			-- Stone from y=1 up to just below dirtBottom
			for y = 1, math.max(1, dirtBottom - 1) do
				chunk:SetBlock(x, y, z, Constants.BlockType.STONE)
			end

			-- Dirt layer
			for y = dirtBottom, dirtTop do
				if y >= 1 and y < height then
					chunk:SetBlock(x, y, z, Constants.BlockType.DIRT)
				end
			end

			-- Grass surface
			if height >= 1 and height < Constants.CHUNK_SIZE_Y then
				chunk:SetBlock(x, height, z, Constants.BlockType.GRASS)
			end

			-- Update heightmap
			local idx = x + z * Constants.CHUNK_SIZE_X
			chunk.heightMap[idx] = height
		end
	end

	chunk.state = Constants.ChunkState.READY
end

return TerrainGenerator