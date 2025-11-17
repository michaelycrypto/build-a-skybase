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
local Logger = require(game:GetService("ReplicatedStorage").Shared.Logger)

local SkyblockGenerator = {}
SkyblockGenerator.__index = SkyblockGenerator

-- Skyblock configuration
local SKYBLOCK_CONFIG = {
	ISLAND_Y = 65, -- Island top surface height
	-- Make the starter island deeper and larger for a rocky, imperfect formation
	ISLAND_DEPTH = 9, -- Fuller underside (1 grass + 2 dirt + 4 stone)
	-- Top radius (in blocks) for main island; tapers each layer below
	MAIN_TOP_RADIUS = 8.0,
	-- Secondary "portal" island configuration (Hypixel-style: ~32-40 blocks away)
	SECOND_ISLAND_DISTANCE_BLOCKS = 36, -- distance from main center in blocks
	SECOND_ISLAND_DIRECTION = Vector2.new(0, 1), -- along +X by default
	SECOND_TOP_RADIUS = 6, -- slightly smaller than main but still sizable
	SECOND_DEPTH = 9, -- slightly deeper rocky formation
	-- World placement
	ISLAND_CENTER_X = 7, -- Center of island (world coords) - centered in chunk (0,0)
	ISLAND_CENTER_Z = 7, -- Spans from (4,4) to (10,10) - fits in one 16x16 chunk (top is larger, spills into neighbors)
	VOID_WORLD = true, -- Everything else is air (no bedrock layer)
	-- Edge noise parameters for imperfect rocky outline
	NOISE_SCALE = 0.18, -- frequency for math.noise
	NOISE_AMPLITUDE = 0.25, -- radial variation fraction (+/-), slightly more random
}

function SkyblockGenerator.new(seed: number)
	local self = setmetatable({
		seed = seed or 0,
		rng = Random.new(seed or 0)
	}, SkyblockGenerator)

	-- Logger context
	self._logger = Logger:CreateContext("SkyblockGenerator")

	return self
end

-- Compute noisy radius at a given vertical depth
local function computeRadiusAtDepth(topRadius: number, depthFromTop: number)
	-- Even gentler taper: 0.3 blocks per depth level (fuller silhouette)
	return math.max(1.5, topRadius - 0.3 * depthFromTop)
end

-- Apply edge noise to a clean radius
local function applyEdgeNoise(cleanRadius: number, wx: number, wz: number, noiseScale: number, noiseAmplitude: number, seedZ: number?)
	local n = math.noise(wx * noiseScale, wz * noiseScale, (seedZ or 0))
	-- Clamp noise for stability
	n = math.clamp(n, -1, 1)
	local factor = 1.0 + noiseAmplitude * n
	-- Avoid shrinking too much
	factor = math.clamp(factor, 1.0 - (noiseAmplitude * 0.75), 1.0 + noiseAmplitude)
	return cleanRadius * factor
end

-- Determine quickly if a chunk at (chunkX, chunkZ) contains any non-air blocks
function SkyblockGenerator:IsChunkEmpty(chunkX: number, chunkZ: number): boolean
	-- Axis-aligned rectangle bounds for the chunk
    local cs = Constants.CHUNK_SIZE_X -- 16
    local minX = chunkX * cs
    local maxX = minX + cs - 1
    local minZ = chunkZ * cs
    local maxZ = minZ + cs - 1

	-- Helper: distance sq from a point to rectangle
	local function distSqToRect(px, pz)
		local dx = 0
		if px < minX then dx = minX - px elseif px > maxX then dx = px - maxX end
		local dz = 0
		if pz < minZ then dz = minZ - pz elseif pz > maxZ then dz = pz - maxZ end
		return dx * dx + dz * dz
	end

	-- Main island check with generous cushion for taper and noise
	local rMain = (SKYBLOCK_CONFIG.MAIN_TOP_RADIUS + SKYBLOCK_CONFIG.ISLAND_DEPTH + 3)
	local mainCenterX = SKYBLOCK_CONFIG.ISLAND_CENTER_X
	local mainCenterZ = SKYBLOCK_CONFIG.ISLAND_CENTER_Z
	local dMain = distSqToRect(mainCenterX, mainCenterZ)

	-- Secondary island center
	local offset = SKYBLOCK_CONFIG.SECOND_ISLAND_DISTANCE_BLOCKS
	local dir = SKYBLOCK_CONFIG.SECOND_ISLAND_DIRECTION
	local secondCenterX = mainCenterX + math.floor(dir.X * offset + 0.5)
	local secondCenterZ = mainCenterZ + math.floor(dir.Y * offset + 0.5)
	local rSecond = (SKYBLOCK_CONFIG.SECOND_TOP_RADIUS + SKYBLOCK_CONFIG.SECOND_DEPTH + 3)
	local dSecond = distSqToRect(secondCenterX, secondCenterZ)

	-- If either footprint intersects the chunk, it's not empty
	if dMain <= (rMain * rMain) then return false end
	if dSecond <= (rSecond * rSecond) then return false end
	return true
end

-- Check if a world position is part of the island
function SkyblockGenerator:IsInsideIsland(wx: number, wy: number, wz: number): boolean
	-- Legacy compatibility wrapper; use detailed function
	local inside, _isSecond = self:_isInsideAnyIsland(wx, wy, wz)
	return inside
end

-- Internal: check membership against main and secondary islands
function SkyblockGenerator:_isInsideAnyIsland(wx: number, wy: number, wz: number): (boolean, boolean)
	local islandY = SKYBLOCK_CONFIG.ISLAND_Y
	local islandBottom = islandY - math.max(SKYBLOCK_CONFIG.ISLAND_DEPTH, SKYBLOCK_CONFIG.SECOND_DEPTH) + 1
	if wy < islandBottom or wy > islandY then
		return false, false
	end

	local depthFromTop = islandY - wy

	-- Compute main island radius (noisy)
	local dx1 = wx - SKYBLOCK_CONFIG.ISLAND_CENTER_X
	local dz1 = wz - SKYBLOCK_CONFIG.ISLAND_CENTER_Z
	local dist1 = math.sqrt(dx1 * dx1 + dz1 * dz1)
	local cleanR1 = computeRadiusAtDepth(SKYBLOCK_CONFIG.MAIN_TOP_RADIUS, depthFromTop)
	local r1 = applyEdgeNoise(cleanR1, wx, wz, SKYBLOCK_CONFIG.NOISE_SCALE, SKYBLOCK_CONFIG.NOISE_AMPLITUDE, (self.seed or 0) + 11)

	-- Compute second island center and radius (noisy)
	local offset = SKYBLOCK_CONFIG.SECOND_ISLAND_DISTANCE_BLOCKS
	local dir = SKYBLOCK_CONFIG.SECOND_ISLAND_DIRECTION
	local c2x = SKYBLOCK_CONFIG.ISLAND_CENTER_X + math.floor(dir.X * offset + 0.5)
	local c2z = SKYBLOCK_CONFIG.ISLAND_CENTER_Z + math.floor(dir.Y * offset + 0.5)
	local dx2 = wx - c2x
	local dz2 = wz - c2z
	local dist2 = math.sqrt(dx2 * dx2 + dz2 * dz2)
	local cleanR2 = computeRadiusAtDepth(SKYBLOCK_CONFIG.SECOND_TOP_RADIUS, math.min(depthFromTop, SKYBLOCK_CONFIG.SECOND_DEPTH - 1))
	local r2 = applyEdgeNoise(cleanR2, wx + 97, wz - 37, SKYBLOCK_CONFIG.NOISE_SCALE, SKYBLOCK_CONFIG.NOISE_AMPLITUDE, (self.seed or 0) + 23)

	if dist1 <= r1 then
		return true, false
	end
	if dist2 <= r2 then
		return true, true
	end
	return false, false
end

-- Local curved top surface (only curves downward; never above ISLAND_Y)
function SkyblockGenerator:_getLocalTopY(wx: number, wz: number, isSecond: boolean): number
	local baseTop = SKYBLOCK_CONFIG.ISLAND_Y
	-- Max downward offset (blocks)
	local maxDown = isSecond and 3 or 2
	-- Use a different noise seed for second island to decorrelate
	local seedZ = (self.seed or 0) + (isSecond and 303 or 202)
	local n = math.noise(wx * 0.12, wz * 0.12, seedZ)
	-- Map noise [-1,1] -> [0, maxDown], bias small
	local t = math.clamp((n + 1) * 0.5, 0, 1)
	local offset = math.floor(t * maxDown + 0.25)
	return baseTop - offset
end

-- Get block type at a world position
function SkyblockGenerator:GetBlockAt(wx: number, wy: number, wz: number): number
	local inside, isSecond = self:_isInsideAnyIsland(wx, wy, wz)
	if not inside then
		return Constants.BlockType.AIR
	end

	local islandY = SKYBLOCK_CONFIG.ISLAND_Y

	-- Determine composition by depth for main vs second island
	local localTopY = self:_getLocalTopY(wx, wz, isSecond)
	local depthFromLocalTop = localTopY - wy
	if depthFromLocalTop < 0 then
		return Constants.BlockType.AIR
	end

	if not isSecond then
		-- Minimal overhang for soft materials (grass/dirt): enforce support below
		if depthFromLocalTop <= 2 then
			local belowInside, _ = self:_isInsideAnyIsland(wx, wy - 1, wz)
			if not belowInside then
				return Constants.BlockType.AIR
			end
		end

		-- Main starter island: grass top, then dirt, then stone (rocky underside)
		if depthFromLocalTop == 0 then
			return Constants.BlockType.GRASS
		elseif depthFromLocalTop <= 2 then
			return Constants.BlockType.DIRT
		else
			return Constants.BlockType.STONE
		end
	else
		-- Secondary island: "rocky island" - mostly stone, occasional cobblestone flecks on top
		if depthFromLocalTop == 0 then
			-- Simple flecking using noise
			local n = math.noise(wx * 0.35, wz * 0.35, (self.seed or 0) + 101)
			if n > 0.35 then
				return Constants.BlockType.COBBLESTONE
			else
				return Constants.BlockType.STONE
			end
		elseif depthFromLocalTop <= 3 then
			return Constants.BlockType.STONE
		else
			return Constants.BlockType.COBBLESTONE
		end
	end
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
		-- Place tree on local curved top height
		local worldCenterTop = self:_getLocalTopY(SKYBLOCK_CONFIG.ISLAND_CENTER_X, SKYBLOCK_CONFIG.ISLAND_CENTER_Z, false)
		self:PlaceTree(chunk, centerLocalX, worldCenterTop + 1, centerLocalZ)
	end

	-- Add starter chest on north edge facing south (if this chunk contains it)
	local chestWorldX = SKYBLOCK_CONFIG.ISLAND_CENTER_X
	local chestWorldZ = SKYBLOCK_CONFIG.ISLAND_CENTER_Z - 3 -- North edge (3 blocks north of center)
	local chestLocalX = chestWorldX - chunkWorldX
	local chestLocalZ = chestWorldZ - chunkWorldZ

	if chestLocalX >= 0 and chestLocalX < Constants.CHUNK_SIZE_X and
	   chestLocalZ >= 0 and chestLocalZ < Constants.CHUNK_SIZE_Z then
		local chestTopY = self:_getLocalTopY(chestWorldX, chestWorldZ, false)
		chunk:SetBlock(chestLocalX, chestTopY + 1, chestLocalZ, Constants.BlockType.CHEST)
		self._logger.Debug(string.format("Placed starter chest at world (%d, %d, %d)", chestWorldX, SKYBLOCK_CONFIG.ISLAND_Y + 1, chestWorldZ))
	end

	-- Place a portal frame on the secondary rocky island (if this chunk contains it)
	self:_placeSecondIslandPortalFrame(chunk, chunkWorldX, chunkWorldZ)

	chunk.state = Constants.ChunkState.READY
end

-- Place a simple portal frame on the second island:
-- A 3x4 inner opening framed by stone bricks, filled with glass as portal surface
function SkyblockGenerator:_placeSecondIslandPortalFrame(chunk, chunkWorldX: number, chunkWorldZ: number)
	-- Secondary island center in world coords
	local dir = SKYBLOCK_CONFIG.SECOND_ISLAND_DIRECTION
	local offset = SKYBLOCK_CONFIG.SECOND_ISLAND_DISTANCE_BLOCKS
	local c2x = SKYBLOCK_CONFIG.ISLAND_CENTER_X + math.floor(dir.X * offset + 0.5)
	local c2z = SKYBLOCK_CONFIG.ISLAND_CENTER_Z + math.floor(dir.Y * offset + 0.5)

	-- Anchor the frame on the curved local top
	local baseY = self:_getLocalTopY(c2x, c2z, true) + 1
	-- Frame dimensions: inner 2w x 3h, outer 4w x 5h
	local halfOuterW = 2 -- extends 2 blocks left/right from center (outer width = 5)
	local innerHalfW = 1 -- inner half width (2 wide opening)
	local innerHeight = 3
	local outerHeight = innerHeight + 2

	-- Try to place only if the chunk contains any portion of the frame footprint
	for dx = -halfOuterW, halfOuterW do
		for dy = 0, outerHeight - 1 do
			for dz = 0, 0 do
				local wx = c2x + dx
				local wy = baseY + dy
				local wz = c2z + dz
				local lx = wx - chunkWorldX
				local lz = wz - chunkWorldZ
				if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
					-- Determine if this position is frame or interior
					local isTopOrBottom = (dy == 0) or (dy == outerHeight - 1)
					local isSide = (dx == -halfOuterW) or (dx == halfOuterW)
					if isTopOrBottom or isSide then
						chunk:SetBlock(lx, wy, lz, Constants.BlockType.STONE_BRICKS)
					else
						-- Interior: glass as portal surface
						-- Only fill within inner opening region
						if math.abs(dx) <= innerHalfW and dy >= 1 and dy <= innerHeight then
							chunk:SetBlock(lx, wy, lz, Constants.BlockType.GLASS)
						end
					end
				end
			end
		end
	end
end

-- Place a Minecraft-style tree with 5x5 canopy; trunk block can be overridden
function SkyblockGenerator:PlaceTree(chunk, lx: number, ly: number, lz: number, logBlockId: number?)
	-- Validate position is within chunk bounds
	if lx < 0 or lx >= Constants.CHUNK_SIZE_X or lz < 0 or lz >= Constants.CHUNK_SIZE_Z then
		return
	end

	-- Tree trunk (5 blocks tall)
	local trunkId = logBlockId or Constants.BlockType.WOOD
	for y = 0, 4 do
		if ly + y < Constants.WORLD_HEIGHT then
			chunk:SetBlock(lx, ly + y, lz, trunkId)
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
			local leafId = Constants.BlockType.OAK_LEAVES
			if logBlockId == Constants.BlockType.SPRUCE_LOG then leafId = Constants.BlockType.SPRUCE_LEAVES end
			if logBlockId == Constants.BlockType.JUNGLE_LOG then leafId = Constants.BlockType.JUNGLE_LEAVES end
			if logBlockId == Constants.BlockType.DARK_OAK_LOG then leafId = Constants.BlockType.DARK_OAK_LEAVES end
			if logBlockId == Constants.BlockType.BIRCH_LOG then leafId = Constants.BlockType.BIRCH_LEAVES end
			if logBlockId == Constants.BlockType.ACACIA_LOG then leafId = Constants.BlockType.ACACIA_LEAVES end
			chunk:SetBlock(leafX, leafY, leafZ, leafId)
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
	-- Spawn aligned to curved top at world center
	local topY = self._getLocalTopY and self:_getLocalTopY(SKYBLOCK_CONFIG.ISLAND_CENTER_X, SKYBLOCK_CONFIG.ISLAND_CENTER_Z, false) or SKYBLOCK_CONFIG.ISLAND_Y
	return Vector3.new(
		SKYBLOCK_CONFIG.ISLAND_CENTER_X * bs,
		(topY + 2) * bs, -- Spawn 2 blocks above local surface
		SKYBLOCK_CONFIG.ISLAND_CENTER_Z * bs
	)
end

return SkyblockGenerator

