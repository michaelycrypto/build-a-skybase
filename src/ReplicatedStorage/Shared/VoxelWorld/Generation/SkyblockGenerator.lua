--[[
	SkyblockGenerator.lua
	Generates a naturally-shaped floating island for Skyblock-style gameplay
	Creates a starting platform with a Minecraft-style oak tree in the center

	Island structure:
	- Shape: Natural floating island with rounded corners and tapered bottom
	- Top surface: ~49 grass blocks (radius 3.5, roughly circular)
	- Height: 4 blocks total (1 grass layer on top, 3 dirt layers below)
	- Position: Y=62 to Y=65 (top surface at Y=65)
	- Tapering: Island gets smaller toward the bottom (creates natural overhang)
	- Features: Minecraft-style oak tree (5-block trunk, 5x5 canopy, 6 blocks tall)
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local SkyblockGenerator = {}
SkyblockGenerator.__index = SkyblockGenerator

-- Skyblock configuration
local SKYBLOCK_CONFIG = {
	ISLAND_Y = 65, -- Island top surface height
	ISLAND_DEPTH = 4, -- Island depth (4 blocks total: 1 grass + 3 dirt)
	ISLAND_SIZE = 7, -- Island size (7x7 square)
	ISLAND_CENTER_X = 7, -- Center of island (world coords) - centered in chunk (0,0)
	ISLAND_CENTER_Z = 7, -- Spans from (4,4) to (10,10) - fits in one 16x16 chunk
	VOID_WORLD = true, -- Everything else is air (no bedrock layer)
}

function SkyblockGenerator.new(seed: number)
	local self = setmetatable({
		seed = seed or 0,
		rng = Random.new(seed or 0)
	}, SkyblockGenerator)

	return self
end

-- Check if a world position is part of the island
function SkyblockGenerator:IsInsideIsland(wx: number, wy: number, wz: number): boolean
	-- Calculate distance from island center
	local dx = wx - SKYBLOCK_CONFIG.ISLAND_CENTER_X
	local dz = wz - SKYBLOCK_CONFIG.ISLAND_CENTER_Z
	local distanceFromCenter = math.sqrt(dx * dx + dz * dz)

	local islandY = SKYBLOCK_CONFIG.ISLAND_Y
	local islandBottom = islandY - SKYBLOCK_CONFIG.ISLAND_DEPTH + 1

	-- Not in vertical range at all
	if wy < islandBottom or wy > islandY then
		return false
	end

	-- Calculate depth from top (0 = top surface, 3 = bottom)
	local depthFromTop = islandY - wy

	-- Island tapers as it goes down (natural floating island shape)
	-- Top layer (grass): full size with rounded corners (radius ~3.5)
	-- Bottom layer: smaller (radius ~2.5)
	local radiusAtThisHeight
	if depthFromTop == 0 then
		-- Top surface (grass) - largest, slightly rounded
		radiusAtThisHeight = 3.5
	elseif depthFromTop == 1 then
		-- First dirt layer - full size
		radiusAtThisHeight = 3.3
	elseif depthFromTop == 2 then
		-- Second dirt layer - tapered
		radiusAtThisHeight = 3.0
	else
		-- Bottom dirt layer (depth 3) - most tapered
		radiusAtThisHeight = 2.5
	end

	-- Check if within radius for this height
	return distanceFromCenter <= radiusAtThisHeight
end

-- Get block type at a world position
function SkyblockGenerator:GetBlockAt(wx: number, wy: number, wz: number): number
	if not self:IsInsideIsland(wx, wy, wz) then
		return Constants.BlockType.AIR
	end

	local islandY = SKYBLOCK_CONFIG.ISLAND_Y

	-- Top layer: Grass
	if wy == islandY then
		return Constants.BlockType.GRASS
	end

	-- All other layers (4 blocks below): Dirt
	-- Y = 64, 63, 62, 61 (if ISLAND_Y = 65 and DEPTH = 5)
	return Constants.BlockType.DIRT
end

-- Generate a chunk
function SkyblockGenerator:GenerateChunk(chunk)
	local chunkWorldX = chunk.x * Constants.CHUNK_SIZE_X
	local chunkWorldZ = chunk.z * Constants.CHUNK_SIZE_Z

	-- Generate each block in the chunk
	for lx = 0, Constants.CHUNK_SIZE_X - 1 do
		for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
			local wx = chunkWorldX + lx
			local wz = chunkWorldZ + lz

			-- Track highest non-air block for this column
			local highestY = 0

			for ly = 0, Constants.WORLD_HEIGHT - 1 do
				local wy = ly
				local blockType = self:GetBlockAt(wx, wy, wz)

				if blockType ~= Constants.BlockType.AIR then
					chunk:SetBlock(lx, ly, lz, blockType)
					highestY = ly
				end
			end

			-- Update heightmap
			local idx = lx + lz * Constants.CHUNK_SIZE_X
			chunk.heightMap[idx] = highestY
		end
	end

	-- Add a small oak tree at the center (if this chunk contains the center)
	local centerLocalX = SKYBLOCK_CONFIG.ISLAND_CENTER_X - chunkWorldX
	local centerLocalZ = SKYBLOCK_CONFIG.ISLAND_CENTER_Z - chunkWorldZ

	if centerLocalX >= 0 and centerLocalX < Constants.CHUNK_SIZE_X and
	   centerLocalZ >= 0 and centerLocalZ < Constants.CHUNK_SIZE_Z then
		self:PlaceTree(chunk, centerLocalX, SKYBLOCK_CONFIG.ISLAND_Y + 1, centerLocalZ)
	end

	-- Add starter chest on north edge facing south (if this chunk contains it)
	local chestWorldX = SKYBLOCK_CONFIG.ISLAND_CENTER_X
	local chestWorldZ = SKYBLOCK_CONFIG.ISLAND_CENTER_Z - 3 -- North edge (3 blocks north of center)
	local chestLocalX = chestWorldX - chunkWorldX
	local chestLocalZ = chestWorldZ - chunkWorldZ

	if chestLocalX >= 0 and chestLocalX < Constants.CHUNK_SIZE_X and
	   chestLocalZ >= 0 and chestLocalZ < Constants.CHUNK_SIZE_Z then
		chunk:SetBlock(chestLocalX, SKYBLOCK_CONFIG.ISLAND_Y + 1, chestLocalZ, Constants.BlockType.CHEST)
		print(string.format("Placed starter chest at world (%d, %d, %d)", chestWorldX, SKYBLOCK_CONFIG.ISLAND_Y + 1, chestWorldZ))
	end

	chunk.state = Constants.ChunkState.READY
end

-- Place a Minecraft-style oak tree with 5x5 canopy
function SkyblockGenerator:PlaceTree(chunk, lx: number, ly: number, lz: number)
	-- Validate position is within chunk bounds
	if lx < 0 or lx >= Constants.CHUNK_SIZE_X or lz < 0 or lz >= Constants.CHUNK_SIZE_Z then
		return
	end

	-- Tree trunk (5 blocks tall)
	for y = 0, 4 do
		if ly + y < Constants.WORLD_HEIGHT then
			chunk:SetBlock(lx, ly + y, lz, Constants.BlockType.WOOD)
		end
	end

	-- Helper function to place leaf if in bounds
	local function placeLeaf(dx, dy, dz)
		local leafX = lx + dx
		local leafY = ly + dy
		local leafZ = lz + dz

		if leafX >= 0 and leafX < Constants.CHUNK_SIZE_X and
		   leafZ >= 0 and leafZ < Constants.CHUNK_SIZE_Z and
		   leafY < Constants.WORLD_HEIGHT then
			chunk:SetBlock(leafX, leafY, leafZ, Constants.BlockType.LEAVES)
		end
	end

	-- Layer 1 (y+3): 5x5 with corners cut (bottom canopy layer)
	for dx = -2, 2 do
		for dz = -2, 2 do
			-- Skip corners
			if not ((math.abs(dx) == 2 and math.abs(dz) == 2)) then
				-- Skip center where trunk is
				if not (dx == 0 and dz == 0) then
					placeLeaf(dx, 3, dz)
				end
			end
		end
	end

	-- Layer 2 (y+4): 5x5 with corners cut
	for dx = -2, 2 do
		for dz = -2, 2 do
			-- Skip corners
			if not ((math.abs(dx) == 2 and math.abs(dz) == 2)) then
				-- Skip center where trunk is
				if not (dx == 0 and dz == 0) then
					placeLeaf(dx, 4, dz)
				end
			end
		end
	end

	-- Layer 3 (y+5): 3x3 layer (top)
	for dx = -1, 1 do
		for dz = -1, 1 do
			placeLeaf(dx, 5, dz)
		end
	end
end

-- Get spawn position (on top of island)
function SkyblockGenerator:GetSpawnPosition(): Vector3
	local bs = Constants.BLOCK_SIZE
	return Vector3.new(
		SKYBLOCK_CONFIG.ISLAND_CENTER_X * bs,
		(SKYBLOCK_CONFIG.ISLAND_Y + 2) * bs, -- Spawn 2 blocks above grass
		SKYBLOCK_CONFIG.ISLAND_CENTER_Z * bs
	)
end

return SkyblockGenerator

