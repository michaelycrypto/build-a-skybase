--[[
	WaterMesher.lua
	Minecraft-style water rendering using corner height interpolation.

	============================================================================
	MINECRAFT WATER RENDERING MODEL
	============================================================================
	
	Water is simulated PER-BLOCK with a single scalar level (0-7).
	Corner heights are DERIVED from neighboring blocks, never simulated.
	
	Key formula (Minecraft's exact approach):
		cornerHeight = MAX(height(thisBlock), height(neighbor1), height(neighbor2), height(diagonal))
	
	This creates smooth slopes where water meets different levels.
	
	============================================================================
	CORNER HEIGHT CALCULATION
	============================================================================
	
	For each of the 4 corners (NE, NW, SE, SW), sample 4 blocks:
	- The current block
	- Two cardinal neighbors sharing that corner
	- The diagonal neighbor at that corner
	
	Example for NE corner (+X, -Z):
		cornerNE = max(current, north, east, northeast)
	
	============================================================================
	SHAPE DETERMINATION (Emergent from corners)
	============================================================================
	
	After computing 4 corner heights:
	- FLAT: All 4 corners same height
	- SLOPE (WedgePart): 2 adjacent corners high, 2 low
	- CONVEX (CornerWedgePart): 1 corner high, 3 low (peak)
	- CONCAVE (2 WedgeParts): 3 corners high, 1 low (valley)
	
	Convex/Concave are NOT simulated - they EMERGE from the corner math.
	
	============================================================================
	OPTIMIZATIONS (Performance-focused, core mechanics unchanged)
	============================================================================
	- Box-meshing falling water: Adjacent falling columns merge into XYZ boxes
	- Vertical column merging: Consecutive falling water → single tall Part
	- Horizontal greedy meshing: Interior source blocks → merged Parts
	- Flowing water greedy meshing: Same-level flowing blocks → merged Parts
	- Face culling: Only texture faces not adjacent to other water
	- Full occlusion skip: Fully-surrounded water blocks skip rendering entirely
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local WaterUtils = require(script.Parent.Parent.World.WaterUtils)
local PartPool = require(script.Parent.PartPool)
local TextureManager = require(script.Parent.TextureManager)

local WaterMesher = {}
WaterMesher.__index = WaterMesher

-- Water visual properties
local WATER_COLOR = Color3.fromRGB(32, 84, 164)
local WATER_TRANSPARENCY = 0.4  -- Semi-transparent
local WATER_REFLECTANCE = 0.2
local WATER_MATERIAL = Enum.Material.Glass

-- Height constants (in fractions of a block)
local WEDGE_HEIGHT = 1/8
local SOURCE_HEIGHT = 7/8

--============================================================================
-- DIRECTION SYSTEM
--============================================================================
-- Coordinate system (Minecraft-style): +Z = South, -Z = North, +X = East, -X = West

local DIRECTION = {
	NONE = 0,
	NORTH = 1,  -- -Z
	SOUTH = 2,  -- +Z
	EAST = 3,   -- +X
	WEST = 4,   -- -X
}

local DIRECTION_NAMES = {
	[0] = "NONE",
	[1] = "NORTH(-Z)",
	[2] = "SOUTH(+Z)",
	[3] = "EAST(+X)",
	[4] = "WEST(-X)",
}

local DIRECTION_VECTORS = {
	[DIRECTION.NORTH] = {dx = 0, dz = -1},
	[DIRECTION.SOUTH] = {dx = 0, dz = 1},
	[DIRECTION.EAST] = {dx = 1, dz = 0},
	[DIRECTION.WEST] = {dx = -1, dz = 0},
}

local OPPOSITE_DIRECTION = {
	[DIRECTION.NORTH] = DIRECTION.SOUTH,
	[DIRECTION.SOUTH] = DIRECTION.NORTH,
	[DIRECTION.EAST] = DIRECTION.WEST,
	[DIRECTION.WEST] = DIRECTION.EAST,
}

--============================================================================
-- CORNER SYSTEM
--============================================================================

local CORNER = {
	NONE = 0,
	-- Concave corners: Valley at the named corner, sources from opposite directions
	CONCAVE_NE = 1,  -- Valley at NE, sources from S and W
	CONCAVE_NW = 2,  -- Valley at NW, sources from S and E
	CONCAVE_SE = 3,  -- Valley at SE, sources from N and W
	CONCAVE_SW = 4,  -- Valley at SW, sources from N and E
	-- Convex corners: Peak at the named corner, targets toward the named directions
	CONVEX_NE = 5,   -- Peak at NE, targets toward N and E
	CONVEX_NW = 6,   -- Peak at NW, targets toward N and W
	CONVEX_SE = 7,   -- Peak at SE, targets toward S and E
	CONVEX_SW = 8,   -- Peak at SW, targets toward S and W
}

local CORNER_NAMES = {
	[0] = "NONE",
	[1] = "CONCAVE_NE",
	[2] = "CONCAVE_NW",
	[3] = "CONCAVE_SE",
	[4] = "CONCAVE_SW",
	[5] = "CONVEX_NE",
	[6] = "CONVEX_NW",
	[7] = "CONVEX_SE",
	[8] = "CONVEX_SW",
}

-- WedgePart rotation: LOW side faces the flow direction
-- Default WedgePart: HIGH at +Z, LOW at -Z
local WEDGE_ROTATIONS = {
	[DIRECTION.NORTH] = math.rad(0),     -- Low at -Z (North)
	[DIRECTION.SOUTH] = math.rad(180),   -- Low at +Z (South)
	[DIRECTION.EAST] = math.rad(-90),    -- Low at +X (East)
	[DIRECTION.WEST] = math.rad(90),     -- Low at -X (West)
}

-- CornerWedgePart rotation: Corner vertex points toward the peak
-- Default CornerWedgePart: vertex at +X, -Z (NE) after 180° base rotation
-- Includes both CONVEX and CONCAVE keys for flexibility
local CORNER_WEDGE_ROTATIONS = {
	[CORNER.CONVEX_NE] = math.rad(0),    -- Vertex at NE
	[CORNER.CONVEX_NW] = math.rad(90),   -- Vertex at NW
	[CORNER.CONVEX_SE] = math.rad(-90),  -- Vertex at SE
	[CORNER.CONVEX_SW] = math.rad(180),  -- Vertex at SW
	[CORNER.CONCAVE_NE] = math.rad(0),   -- Vertex at NE
	[CORNER.CONCAVE_NW] = math.rad(90),  -- Vertex at NW
	[CORNER.CONCAVE_SE] = math.rad(-90), -- Vertex at SE
	[CORNER.CONCAVE_SW] = math.rad(180), -- Vertex at SW
}

-- Two-wedge corner directions: both wedges slope TOWARD the corner
-- Includes both CONVEX and CONCAVE keys for flexibility
local TWO_WEDGE_DIRECTIONS = {
	[CORNER.CONCAVE_NE] = {DIRECTION.NORTH, DIRECTION.EAST},  -- Corner at NE
	[CORNER.CONCAVE_NW] = {DIRECTION.NORTH, DIRECTION.WEST},  -- Corner at NW
	[CORNER.CONCAVE_SE] = {DIRECTION.SOUTH, DIRECTION.EAST},  -- Corner at SE
	[CORNER.CONCAVE_SW] = {DIRECTION.SOUTH, DIRECTION.WEST},  -- Corner at SW
	[CORNER.CONVEX_NE] = {DIRECTION.NORTH, DIRECTION.EAST},   -- Corner at NE
	[CORNER.CONVEX_NW] = {DIRECTION.NORTH, DIRECTION.WEST},   -- Corner at NW
	[CORNER.CONVEX_SE] = {DIRECTION.SOUTH, DIRECTION.EAST},   -- Corner at SE
	[CORNER.CONVEX_SW] = {DIRECTION.SOUTH, DIRECTION.WEST},   -- Corner at SW
}

--============================================================================
-- UTILITY FUNCTIONS
--============================================================================

local function snap(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

local function posKey(x, y, z)
	return x * 65536 + y * 256 + z
end

function WaterMesher.new()
	return setmetatable({}, WaterMesher)
end

--============================================================================
-- HEIGHT CALCULATIONS
--============================================================================

--[[
	Get water height for corner calculations (Minecraft formula).
	
	height(level) = 1.0 - (level / 8.0)
	- Source (level 0) = 1.0
	- Level 1 = 0.875
	- Level 7 = 0.125
	
	This is used for corner interpolation, not visual mesh height.
	
	For falling water:
	- If hasWaterAbove is true: full height (1.0) - middle/bottom of column
	- If hasWaterAbove is false: use stored source depth - top of falling column
]]
local function getWaterHeight(blockId, metadata, hasWaterAbove)
	if blockId == Constants.BlockType.WATER_SOURCE then
		return 1.0  -- Source = level 0 = full height for corner calculations
	end
	if blockId ~= Constants.BlockType.FLOWING_WATER then
		return 0
	end
	-- Falling water handling
	if WaterUtils.IsFalling(metadata) then
		-- If water above, this is middle/bottom of column = full height
		if hasWaterAbove then
			return 1.0
		end
		-- Top of falling column: use stored source depth for proper height
		-- The source depth is stored in the level bits
		local sourceDepth = WaterUtils.GetDepth(metadata)
		if sourceDepth <= 0 then
			return 1.0  -- Source block (depth 0) = full height
		end
		-- Calculate height based on source depth
		sourceDepth = math.clamp(sourceDepth, 1, 7)
		return 1.0 - (sourceDepth / 8)
	end
	local level = WaterUtils.GetDepth(metadata)
	-- Clamp to valid range
	if level <= 0 then level = 1 end
	level = math.clamp(level, 1, 7)
	-- Minecraft formula: height = 1.0 - (level / 8)
	-- Level 1 = 0.875, Level 7 = 0.125
	return 1.0 - (level / 8)
end

local function getBaseHeight(blockId, metadata, hasWaterAbove)
	local totalHeight = getWaterHeight(blockId, metadata, hasWaterAbove)
	if blockId == Constants.BlockType.WATER_SOURCE or WaterUtils.IsFalling(metadata) then
		return totalHeight
	end
	return math.max(totalHeight - WEDGE_HEIGHT, 0)
end

--============================================================================
-- CORNER HEIGHT CALCULATION (Minecraft-style: MAX, not average)
--============================================================================

--[[
	Calculate the height at each of the 4 corners of a water block.
	
	MINECRAFT FORMULA: cornerHeight = MAX of the 4 blocks sharing that corner
	
	Corner layout:
	  NW ━━━ NE
	   |     |
	   |     |
	  SW ━━━ SE
	
	NE corner: max(current, north, east, northeast)
	NW corner: max(current, north, west, northwest)
	SE corner: max(current, south, east, southeast)
	SW corner: max(current, south, west, southwest)
]]
local function calculateCornerHeights(currentHeight, neighborHeights)
	local n  = neighborHeights.n  or 0
	local s  = neighborHeights.s  or 0
	local e  = neighborHeights.e  or 0
	local w  = neighborHeights.w  or 0
	local ne = neighborHeights.ne or 0
	local nw = neighborHeights.nw or 0
	local se = neighborHeights.se or 0
	local sw = neighborHeights.sw or 0
	
	-- Minecraft uses MAX of the 4 blocks sharing each corner
	return {
		ne = math.max(currentHeight, n, e, ne),
		nw = math.max(currentHeight, n, w, nw),
		se = math.max(currentHeight, s, e, se),
		sw = math.max(currentHeight, s, w, sw),
	}
end

--[[
	Determine shape from corner heights.
	
	Returns: flowDirection, cornerType
	
	Shape is EMERGENT from corner heights:
	- FLAT: all 4 corners same height
	- SLOPE: 2 adjacent high, 2 adjacent low → WedgePart
	- CONCAVE: 1 high, 3 low (single peak) → CornerWedgePart
	- CONVEX: 3 high, 1 low (single valley) → 2 WedgeParts
	- SADDLE: diagonal corners high → render flat (rare edge case)
]]
local function determineShapeFromCorners(corners)
	local hNE, hNW, hSE, hSW = corners.ne, corners.nw, corners.se, corners.sw
	local maxH = math.max(hNE, hNW, hSE, hSW)
	local minH = math.min(hNE, hNW, hSE, hSW)
	
	-- All same height: FLAT
	local EPSILON = 0.01
	if maxH - minH < EPSILON then
		return DIRECTION.NONE, CORNER.NONE
	end
	
	-- Classify each corner as high or low
	local threshold = (maxH + minH) / 2
	local neHigh = hNE >= threshold
	local nwHigh = hNW >= threshold
	local seHigh = hSE >= threshold
	local swHigh = hSW >= threshold
	
	local highCount = (neHigh and 1 or 0) + (nwHigh and 1 or 0) + (seHigh and 1 or 0) + (swHigh and 1 or 0)
	
	-- 1 high, 3 low: CONCAVE (single peak pointing up)
	if highCount == 1 then
		if neHigh then return DIRECTION.SOUTH, CORNER.CONCAVE_NE end
		if nwHigh then return DIRECTION.SOUTH, CORNER.CONCAVE_NW end
		if seHigh then return DIRECTION.NORTH, CORNER.CONCAVE_SE end
		if swHigh then return DIRECTION.NORTH, CORNER.CONCAVE_SW end
	end
	
	-- 3 high, 1 low: CONVEX (single valley/dip)
	if highCount == 3 then
		if not neHigh then return DIRECTION.SOUTH, CORNER.CONVEX_NE end
		if not nwHigh then return DIRECTION.SOUTH, CORNER.CONVEX_NW end
		if not seHigh then return DIRECTION.NORTH, CORNER.CONVEX_SE end
		if not swHigh then return DIRECTION.NORTH, CORNER.CONVEX_SW end
	end
	
	-- 2 high, 2 low: Check if adjacent (SLOPE) or diagonal (SADDLE)
	if highCount == 2 then
		-- North edge high (NE + NW) → slopes toward South
		if neHigh and nwHigh then return DIRECTION.SOUTH, CORNER.NONE end
		-- South edge high (SE + SW) → slopes toward North
		if seHigh and swHigh then return DIRECTION.NORTH, CORNER.NONE end
		-- East edge high (NE + SE) → slopes toward West
		if neHigh and seHigh then return DIRECTION.WEST, CORNER.NONE end
		-- West edge high (NW + SW) → slopes toward East
		if nwHigh and swHigh then return DIRECTION.EAST, CORNER.NONE end
		-- Diagonal (NE+SW or NW+SE): saddle point, render flat
		return DIRECTION.NONE, CORNER.NONE
	end
	
	return DIRECTION.NONE, CORNER.NONE
end

--============================================================================
-- NEIGHBOR HEIGHT SAMPLING
--============================================================================

--[[
	Get the visual height of a water block for corner calculations.
	Non-water blocks return 0 (don't contribute to MAX).
	Checks for water above neighbor to properly handle falling water top-of-column.
]]
local function getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, nx, y, nz)
	local blockId = sampler(worldManager, chunk, nx, y, nz)
	if not WaterUtils.IsWater(blockId) then
		return 0
	end
	local meta = metaSampler(worldManager, chunk, nx, y, nz) or 0
	-- Check if neighbor has water above (for falling water height calculation)
	local aboveId = sampler(worldManager, chunk, nx, y + 1, nz)
	local hasWaterAbove = WaterUtils.IsWater(aboveId)
	return getWaterHeight(blockId, meta, hasWaterAbove)
end

--[[
	Calculate shape for a water block using Minecraft's corner height system.
	
	Simple algorithm:
	1. Sample all 8 neighbors
	2. Compute 4 corner heights using MAX formula
	3. Determine shape from corner height pattern
	
	@return flowDirection, cornerType
]]
local function calculateWaterShape(chunk, worldManager, sampler, metaSampler, x, y, z, currentHeight, isFalling)
	-- Falling water: always flat (vertical column)
	if isFalling then
		return DIRECTION.NONE, CORNER.NONE
	end
	
	-- Sample all 8 neighbors
	local neighborHeights = {
		n  = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x, y, z - 1),
		s  = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x, y, z + 1),
		e  = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x + 1, y, z),
		w  = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x - 1, y, z),
		ne = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x + 1, y, z - 1),
		nw = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x - 1, y, z - 1),
		se = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x + 1, y, z + 1),
		sw = getNeighborWaterHeight(sampler, metaSampler, worldManager, chunk, x - 1, y, z + 1),
	}
	
	-- Compute corner heights using MAX formula
	local corners = calculateCornerHeights(currentHeight, neighborHeights)
	
	-- Determine shape from corners
	return determineShapeFromCorners(corners)
end

--============================================================================
-- FACE VISIBILITY
--============================================================================

local function getVisibleFaces(waterMap, x, y, z, height, yBlocks)
	local faces = {}
	yBlocks = yBlocks or 1

	-- Top: no water above
	if not waterMap[posKey(x, y + yBlocks, z)] then
		table.insert(faces, Enum.NormalId.Top)
	end

	-- Bottom: no water below
	if not waterMap[posKey(x, y - 1, z)] then
		table.insert(faces, Enum.NormalId.Bottom)
	end

	-- Sides: check all y levels for multi-block parts
	local hasN, hasS, hasE, hasW = true, true, true, true
	for checkY = y, y + yBlocks - 1 do
		if not waterMap[posKey(x, checkY, z - 1)] then hasN = false end
		if not waterMap[posKey(x, checkY, z + 1)] then hasS = false end
		if not waterMap[posKey(x + 1, checkY, z)] then hasE = false end
		if not waterMap[posKey(x - 1, checkY, z)] then hasW = false end
	end

	if not hasN then table.insert(faces, Enum.NormalId.Back) end   -- -Z
	if not hasS then table.insert(faces, Enum.NormalId.Front) end  -- +Z
	if not hasE then table.insert(faces, Enum.NormalId.Right) end  -- +X
	if not hasW then table.insert(faces, Enum.NormalId.Left) end   -- -X

	return faces
end

--============================================================================
-- TEXTURE APPLICATION
--============================================================================

local function applyTextures(part, textureId, bs, faces)
	if not textureId then return end
	for _, face in ipairs(faces) do
		local tex = PartPool.AcquireTexture()
		tex.Face = face
		tex.Texture = textureId
		tex.StudsPerTileU = bs
		tex.StudsPerTileV = bs
		tex.Transparency = 0
		tex.Parent = part
	end
end

--============================================================================
-- PART CREATION
--============================================================================

local function createBasePart(worldX, worldY, worldZ, height, bs, textureId, faces)
	local part = PartPool.AcquireFacePart()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = WATER_MATERIAL
	part.Color = WATER_COLOR
	part.Transparency = WATER_TRANSPARENCY
	part.Reflectance = WATER_REFLECTANCE
	part.Name = "WaterBase"

	local sizeY = height * bs
	part.Size = Vector3.new(snap(bs), snap(sizeY), snap(bs))
	part.Position = Vector3.new(snap(worldX), snap(worldY + sizeY * 0.5), snap(worldZ))

	applyTextures(part, textureId, bs, faces)
	return part
end

local function createMergedPart(worldX, worldZ, worldY, widthX, widthZ, height, bs, textureId, faces)
	local part = PartPool.AcquireFacePart()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = WATER_MATERIAL
	part.Color = WATER_COLOR
	part.Transparency = WATER_TRANSPARENCY
	part.Reflectance = WATER_REFLECTANCE
	part.Name = "WaterSurface"

	local sizeX = widthX * bs
	local sizeY = height * bs
	local sizeZ = widthZ * bs
	part.Size = Vector3.new(snap(sizeX), snap(sizeY), snap(sizeZ))
	part.Position = Vector3.new(
		snap(worldX + sizeX * 0.5),
		snap(worldY + sizeY * 0.5),
		snap(worldZ + sizeZ * 0.5)
	)

	if textureId then
		for _, face in ipairs(faces) do
			local tex = PartPool.AcquireTexture()
			tex.Face = face
			tex.Texture = textureId
			tex.StudsPerTileU = bs
			tex.StudsPerTileV = bs
			tex.Transparency = 0
			tex.Parent = part
		end
	end

	return part
end

local function createWedgePart(worldX, worldY, worldZ, baseHeight, bs, flowDir, textureId, faces)
	local wedge = PartPool.AcquireWedgePart()
	wedge.Anchored = true
	wedge.CanCollide = false
	wedge.CanQuery = false
	wedge.CanTouch = false
	wedge.CastShadow = false
	wedge.Material = WATER_MATERIAL
	wedge.Color = WATER_COLOR
	wedge.Transparency = WATER_TRANSPARENCY
	wedge.Reflectance = WATER_REFLECTANCE
	wedge.Name = "WaterWedge"

	local wedgeH = WEDGE_HEIGHT * bs
	wedge.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))

	local wedgeY = worldY + baseHeight * bs + wedgeH * 0.5
	local rotation = WEDGE_ROTATIONS[flowDir] or 0
	wedge.CFrame = CFrame.new(snap(worldX), snap(wedgeY), snap(worldZ)) * CFrame.Angles(0, rotation, 0)

	applyTextures(wedge, textureId, bs, faces)
	return wedge
end

--[[
	Create CONCAVE corner: Two wedges forming a valley at the corner.
	Both wedges slope TOWARD the corner location.
]]
local function createConcaveCorner(worldX, worldY, worldZ, baseHeight, bs, cornerType, textureId, faces)
	local parts = {}
	local wedgeH = WEDGE_HEIGHT * bs
	local wedgeY = worldY + baseHeight * bs + wedgeH * 0.5

	local dirs = TWO_WEDGE_DIRECTIONS[cornerType]
	if not dirs then return parts end

	-- First wedge
	local wedge1 = PartPool.AcquireWedgePart()
	wedge1.Anchored = true
	wedge1.CanCollide = false
	wedge1.CanQuery = false
	wedge1.CanTouch = false
	wedge1.CastShadow = false
	wedge1.Material = WATER_MATERIAL
	wedge1.Color = WATER_COLOR
	wedge1.Transparency = WATER_TRANSPARENCY
	wedge1.Reflectance = WATER_REFLECTANCE
	wedge1.Name = "WaterConcave1"

	wedge1.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))
	wedge1.CFrame = CFrame.new(snap(worldX), snap(wedgeY), snap(worldZ)) *
	                CFrame.Angles(0, WEDGE_ROTATIONS[dirs[1]] or 0, 0)
	applyTextures(wedge1, textureId, bs, faces)
	table.insert(parts, wedge1)

	-- Second wedge
	local wedge2 = PartPool.AcquireWedgePart()
	wedge2.Anchored = true
	wedge2.CanCollide = false
	wedge2.CanQuery = false
	wedge2.CanTouch = false
	wedge2.CastShadow = false
	wedge2.Material = WATER_MATERIAL
	wedge2.Color = WATER_COLOR
	wedge2.Transparency = WATER_TRANSPARENCY
	wedge2.Reflectance = WATER_REFLECTANCE
	wedge2.Name = "WaterConcave2"

	wedge2.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))
	wedge2.CFrame = CFrame.new(snap(worldX), snap(wedgeY), snap(worldZ)) *
	                CFrame.Angles(0, WEDGE_ROTATIONS[dirs[2]] or 0, 0)
	applyTextures(wedge2, textureId, bs, faces)
	table.insert(parts, wedge2)

	return parts
end

--[[
	Create CONVEX corner: Single CornerWedgePart with peak pointing at the corner.
]]
local function createConvexCorner(worldX, worldY, worldZ, baseHeight, bs, cornerType, textureId, faces)
	local corner = PartPool.AcquireCornerWedgePart()
	corner.Anchored = true
	corner.CanCollide = false
	corner.CanQuery = false
	corner.CanTouch = false
	corner.CastShadow = false
	corner.Material = WATER_MATERIAL
	corner.Color = WATER_COLOR
	corner.Transparency = WATER_TRANSPARENCY
	corner.Reflectance = WATER_REFLECTANCE
	corner.Name = "WaterConvex"

	local wedgeH = WEDGE_HEIGHT * bs
	corner.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))

	local cornerY = worldY + baseHeight * bs + wedgeH * 0.5
	local rotation = CORNER_WEDGE_ROTATIONS[cornerType] or 0
	corner.CFrame = CFrame.new(snap(worldX), snap(cornerY), snap(worldZ)) * CFrame.Angles(0, rotation, 0)

	applyTextures(corner, textureId, bs, faces)
	return corner
end

local function createFlatTop(worldX, worldY, worldZ, baseHeight, bs, textureId, faces)
	local part = PartPool.AcquireFacePart()
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = WATER_MATERIAL
	part.Color = WATER_COLOR
	part.Transparency = WATER_TRANSPARENCY
	part.Reflectance = WATER_REFLECTANCE
	part.Name = "WaterFlat"

	local topH = WEDGE_HEIGHT * bs
	part.Size = Vector3.new(snap(bs), snap(topH), snap(bs))
	part.Position = Vector3.new(snap(worldX), snap(worldY + baseHeight * bs + topH * 0.5), snap(worldZ))

	applyTextures(part, textureId, bs, faces)
	return part
end

--============================================================================
-- MAIN MESH GENERATION
--============================================================================

function WaterMesher:GenerateMesh(chunk, worldManager, options)
	options = options or {}
	local meshParts = {}
	local partsBudget = 0
	local MAX_PARTS = options.maxWaterParts or 500

	-- Block samplers
	local sampler = options.sampleBlock or function(wm, c, lx, ly, lz)
		if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
			return c:GetBlock(lx, ly, lz)
		end
		if not wm then return Constants.BlockType.AIR end
		local cx, cz = c.x, c.z
		if lx < 0 then cx = cx - 1; lx = lx + Constants.CHUNK_SIZE_X
		elseif lx >= Constants.CHUNK_SIZE_X then cx = cx + 1; lx = lx - Constants.CHUNK_SIZE_X end
		if lz < 0 then cz = cz - 1; lz = lz + Constants.CHUNK_SIZE_Z
		elseif lz >= Constants.CHUNK_SIZE_Z then cz = cz + 1; lz = lz - Constants.CHUNK_SIZE_Z end
		local key = Constants.ToChunkKey(cx, cz)
		local neighbor = wm.chunks and wm.chunks[key]
		return neighbor and neighbor:GetBlock(lx, ly, lz) or Constants.BlockType.AIR
	end

	local metaSampler = options.sampleMetadata or function(wm, c, lx, ly, lz)
		if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
			return c:GetMetadata(lx, ly, lz)
		end
		if not wm then return 0 end
		local cx, cz = c.x, c.z
		if lx < 0 then cx = cx - 1; lx = lx + Constants.CHUNK_SIZE_X
		elseif lx >= Constants.CHUNK_SIZE_X then cx = cx + 1; lx = lx - Constants.CHUNK_SIZE_X end
		if lz < 0 then cz = cz - 1; lz = lz + Constants.CHUNK_SIZE_Z
		elseif lz >= Constants.CHUNK_SIZE_Z then cz = cz + 1; lz = lz - Constants.CHUNK_SIZE_Z end
		local key = Constants.ToChunkKey(cx, cz)
		local neighbor = wm.chunks and wm.chunks[key]
		return neighbor and neighbor:GetMetadata(lx, ly, lz) or 0
	end

	-- Constants
	local CHUNK_SX = Constants.CHUNK_SIZE_X
	local CHUNK_SZ = Constants.CHUNK_SIZE_Z
	local CHUNK_SY = Constants.CHUNK_SIZE_Y
	local BLOCK_SIZE = Constants.BLOCK_SIZE

	-- Textures (fetch early to avoid lookup during iteration)
	local texStill = TextureManager:GetTextureId("water_still")
	local texFlow = TextureManager:GetTextureId("water_flow")

	--========================================================================
	-- PHASE 1: Collect water blocks (optimized single-pass)
	-- Water can fall into the void (below terrain), so we scan FULL world height
	-- This is necessary because heightMap only tracks solid blocks, not water
	--========================================================================
	local waterBlocks = {}
	local waterMap = {}
	local visited = {}
	local waterYMin, waterYMax = CHUNK_SY, 0
	
	-- Optimization: Use chunk's water bounds if tracked, otherwise scan full height
	-- Chunks can optionally track waterMinY/waterMaxY for faster scanning
	local scanYMin = 0
	local scanYMax = CHUNK_SY - 1
	
	-- Use cached water bounds if available and not dirty
	if chunk.waterMinY and chunk.waterMaxY and not chunk.waterBoundsDirty then
		scanYMin = chunk.waterMinY
		scanYMax = chunk.waterMaxY
	elseif chunk.heightMap then
		-- No water bounds cached, use heightMap to limit upper scan range
		-- Water can flow from heightMap level + 2 (water on top of blocks)
		-- And can fall down to Y=0 (void)
		local maxH = 0
		for z = 0, CHUNK_SZ - 1 do
			for x = 0, CHUNK_SX - 1 do
				local h = chunk.heightMap[x + z * CHUNK_SX] or 0
				if h > maxH then maxH = h end
			end
		end
		scanYMax = math.min(maxH + 2, CHUNK_SY - 1)
		scanYMin = 0  -- Always start from bottom to catch falling water
	end

	-- Single-pass scan: collect water blocks and determine Y bounds simultaneously
	for y = scanYMin, scanYMax do
		for z = 0, CHUNK_SZ - 1 do
			for x = 0, CHUNK_SX - 1 do
				local blockId = chunk:GetBlock(x, y, z)
				if WaterUtils.IsWater(blockId) then
					local meta = chunk:GetMetadata(x, y, z)
					-- Check for water above (needed for falling water top-of-column height)
					local aboveId = (y + 1 < CHUNK_SY) and chunk:GetBlock(x, y + 1, z) or Constants.BlockType.AIR
					local hasWaterAbove = WaterUtils.IsWater(aboveId)
					local height = getWaterHeight(blockId, meta, hasWaterAbove)
					if height > 0 then
						local key = posKey(x, y, z)
						waterMap[key] = true
						table.insert(waterBlocks, {
							x = x, y = y, z = z,
							blockId = blockId,
							metadata = meta,
							isFalling = WaterUtils.IsFalling(meta),
							isSource = (blockId == Constants.BlockType.WATER_SOURCE),
							depth = (blockId == Constants.BlockType.WATER_SOURCE) and 0 or WaterUtils.GetDepth(meta),
							height = height,
							key = key,
						})
						-- Track actual Y bounds (for neighbor scanning)
						if y < waterYMin then waterYMin = y end
						if y > waterYMax then waterYMax = y end
					end
				end
			end
		end
	end
	
	local hasWater = #waterBlocks > 0
	
	-- Update chunk's water bounds cache for faster future scans
	if hasWater then
		chunk.waterMinY = waterYMin
		chunk.waterMaxY = waterYMax
		chunk.waterBoundsDirty = false
	else
		chunk.waterMinY = nil
		chunk.waterMaxY = nil
		chunk.waterBoundsDirty = false
	end

	-- Add neighbor chunk water to map (for face culling)
	-- Scan the full water Y range to catch water in neighboring chunks at any height
	if hasWater then
		for y = waterYMin, waterYMax do
			for z = 0, CHUNK_SZ - 1 do
				if WaterUtils.IsWater(sampler(worldManager, chunk, -1, y, z)) then
					waterMap[posKey(-1, y, z)] = true
				end
				if WaterUtils.IsWater(sampler(worldManager, chunk, CHUNK_SX, y, z)) then
					waterMap[posKey(CHUNK_SX, y, z)] = true
				end
			end
			for x = 0, CHUNK_SX - 1 do
				if WaterUtils.IsWater(sampler(worldManager, chunk, x, y, -1)) then
					waterMap[posKey(x, y, -1)] = true
				end
				if WaterUtils.IsWater(sampler(worldManager, chunk, x, y, CHUNK_SZ)) then
					waterMap[posKey(x, y, CHUNK_SZ)] = true
				end
			end
		end
	end

	--========================================================================
	-- PHASE 2: Column-first box-meshing for falling water
	-- Instantly detects full vertical columns, then merges horizontally
	-- This creates optimal boxes for waterfalls (single part per waterfall)
	-- 
	-- NOTE: TOP of falling columns (no water above) are EXCLUDED from Phase 2
	-- because they need special height handling based on source depth.
	-- These are handled in Phase 4 with proper height calculation.
	--========================================================================
	
	-- Step 1: Build column map - for each XZ position, find full vertical extent
	-- columnMap[x][z] = {minY, maxY} representing the full falling water column
	-- Only include blocks that have water above (not the top of the column)
	-- Top-of-column blocks are NOT included here - they're processed in Phase 4
	-- with their correct height based on stored source depth.
	local columnMap = {} -- [x][z] = {minY, maxY}
	
	for _, wb in ipairs(waterBlocks) do
		if wb.isFalling then
			local x, y, z = wb.x, wb.y, wb.z
			local hasWaterAbove = waterMap[posKey(x, y + 1, z)]
			
			if hasWaterAbove then
				-- Middle/bottom of column: can be box-meshed at full height
				if not columnMap[x] then columnMap[x] = {} end
				
				if not columnMap[x][z] then
					columnMap[x][z] = {minY = y, maxY = y}
				else
					local col = columnMap[x][z]
					if y < col.minY then col.minY = y end
					if y > col.maxY then col.maxY = y end
				end
			end
			-- Top of column blocks (no water above) are skipped here
			-- They remain in waterBlocks and are processed in Phase 4
			-- with proper height based on stored source depth
		end
	end
	
	-- Step 2: Group columns by their Y extent (minY, maxY) for optimal merging
	-- Columns with same Y extent can be merged into a single box
	local columnGroups = {} -- [minY * 1000 + maxY] = {{x, z}, ...}
	
	for x, zMap in pairs(columnMap) do
		for z, col in pairs(zMap) do
			local groupKey = col.minY * 1000 + col.maxY
			if not columnGroups[groupKey] then
				columnGroups[groupKey] = {minY = col.minY, maxY = col.maxY, columns = {}}
			end
			table.insert(columnGroups[groupKey].columns, {x = x, z = z})
		end
	end
	
	-- Step 3: Greedy merge columns within each Y-extent group
	for _, group in pairs(columnGroups) do
		if partsBudget >= MAX_PARTS then break end
		
		local minY, maxY = group.minY, group.maxY
		local height = maxY - minY + 1
		
		-- Build 2D grid for this Y-extent group
		local grid = {} -- [x][z] = true
		for _, col in ipairs(group.columns) do
			if not grid[col.x] then grid[col.x] = {} end
			grid[col.x][col.z] = true
		end
		
		-- Track which columns have been processed
		local colVisited = {} -- [x * 1000 + z] = true
		
		-- Greedy merge into boxes
		for _, col in ipairs(group.columns) do
			local colKey = col.x * 1000 + col.z
			if colVisited[colKey] then continue end
			if partsBudget >= MAX_PARTS then break end
			
			local x0, z0 = col.x, col.z
			
			-- Expand along X axis
			local dx = 1
			while grid[x0 + dx] and grid[x0 + dx][z0] and not colVisited[(x0 + dx) * 1000 + z0] do
				dx = dx + 1
			end
			
			-- Expand along Z axis uniformly across X extent
			local dz = 1
			local canExpandZ = true
			while canExpandZ do
				for ix = 0, dx - 1 do
					local testX = x0 + ix
					local testZ = z0 + dz
					if not grid[testX] or not grid[testX][testZ] or colVisited[testX * 1000 + testZ] then
						canExpandZ = false
						break
					end
				end
				if canExpandZ then dz = dz + 1 end
			end
			
			-- Mark all columns in this box as visited and mark individual blocks
			for ix = 0, dx - 1 do
				for iz = 0, dz - 1 do
					local cx, cz = x0 + ix, z0 + iz
					colVisited[cx * 1000 + cz] = true
					-- Mark all Y levels in this column as visited
					for y = minY, maxY do
						visited[posKey(cx, y, cz)] = true
					end
				end
			end
			
			-- Calculate visible faces for the merged box
			local boxFaces = {}
			
			-- Top face: check if any column top has no water above
			local hasTop = false
			for ix = 0, dx - 1 do
				for iz = 0, dz - 1 do
					if not waterMap[posKey(x0 + ix, maxY + 1, z0 + iz)] then
						hasTop = true
						break
					end
				end
				if hasTop then break end
			end
			if hasTop then table.insert(boxFaces, Enum.NormalId.Top) end
			
			-- Bottom face: check if any column bottom has no water below
			local hasBottom = false
			for ix = 0, dx - 1 do
				for iz = 0, dz - 1 do
					if not waterMap[posKey(x0 + ix, minY - 1, z0 + iz)] then
						hasBottom = true
						break
					end
				end
				if hasBottom then break end
			end
			if hasBottom then table.insert(boxFaces, Enum.NormalId.Bottom) end
			
			-- Left face (-X): check entire YZ face
			local hasLeft = false
			for y = minY, maxY do
				for iz = 0, dz - 1 do
					if not waterMap[posKey(x0 - 1, y, z0 + iz)] then
						hasLeft = true
						break
					end
				end
				if hasLeft then break end
			end
			if hasLeft then table.insert(boxFaces, Enum.NormalId.Left) end
			
			-- Right face (+X): check entire YZ face
			local hasRight = false
			for y = minY, maxY do
				for iz = 0, dz - 1 do
					if not waterMap[posKey(x0 + dx, y, z0 + iz)] then
						hasRight = true
						break
					end
				end
				if hasRight then break end
			end
			if hasRight then table.insert(boxFaces, Enum.NormalId.Right) end
			
			-- Back face (-Z): check entire XY face
			local hasBack = false
			for y = minY, maxY do
				for ix = 0, dx - 1 do
					if not waterMap[posKey(x0 + ix, y, z0 - 1)] then
						hasBack = true
						break
					end
				end
				if hasBack then break end
			end
			if hasBack then table.insert(boxFaces, Enum.NormalId.Back) end
			
			-- Front face (+Z): check entire XY face
			local hasFront = false
			for y = minY, maxY do
				for ix = 0, dx - 1 do
					if not waterMap[posKey(x0 + ix, y, z0 + dz)] then
						hasFront = true
						break
					end
				end
				if hasFront then break end
			end
			if hasFront then table.insert(boxFaces, Enum.NormalId.Front) end
			
			-- Skip fully-occluded boxes
			if #boxFaces == 0 then
				continue
			end
			
			-- Create the merged box part
			local sizeX = dx * BLOCK_SIZE
			local sizeY = height * BLOCK_SIZE
			local sizeZ = dz * BLOCK_SIZE
			local worldX = (chunk.x * CHUNK_SX + x0) * BLOCK_SIZE + sizeX * 0.5
			local worldY = minY * BLOCK_SIZE + sizeY * 0.5
			local worldZ = (chunk.z * CHUNK_SZ + z0) * BLOCK_SIZE + sizeZ * 0.5
			
			local part = PartPool.AcquireFacePart()
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Material = WATER_MATERIAL
			part.Color = WATER_COLOR
			part.Transparency = WATER_TRANSPARENCY
			part.Reflectance = WATER_REFLECTANCE
			part.Name = "WaterFall"
			part.Size = Vector3.new(snap(sizeX), snap(sizeY), snap(sizeZ))
			part.Position = Vector3.new(snap(worldX), snap(worldY), snap(worldZ))
			
			applyTextures(part, texFlow, BLOCK_SIZE, boxFaces)
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
		end
	end

	--========================================================================
	-- PHASE 3: Horizontal greedy meshing (INTERIOR source water only)
	-- Edge sources (those with non-source neighbors) are left for Phase 4
	-- so they can render with proper slopes/corners
	--========================================================================
	local sourceByY = {}
	for _, wb in ipairs(waterBlocks) do
		if wb.isSource and not visited[wb.key] then
			-- Check if this is an interior source (all 4 cardinal neighbors are sources)
			local x, y, z = wb.x, wb.y, wb.z
			local nId = sampler(worldManager, chunk, x, y, z - 1)
			local sId = sampler(worldManager, chunk, x, y, z + 1)
			local eId = sampler(worldManager, chunk, x + 1, y, z)
			local wId = sampler(worldManager, chunk, x - 1, y, z)
			
			local isInterior = (nId == Constants.BlockType.WATER_SOURCE) and
			                   (sId == Constants.BlockType.WATER_SOURCE) and
			                   (eId == Constants.BlockType.WATER_SOURCE) and
			                   (wId == Constants.BlockType.WATER_SOURCE)
			
			if isInterior then
				-- Interior source: can be greedy meshed (flat top)
				if not sourceByY[wb.y] then sourceByY[wb.y] = {} end
				table.insert(sourceByY[wb.y], {x = wb.x, z = wb.z, key = wb.key})
			end
			-- Edge sources will be handled in Phase 4 with slopes/corners
		end
	end

	for y, blocks in pairs(sourceByY) do
		if partsBudget >= MAX_PARTS then return meshParts end

		local grid = {}
		for _, b in ipairs(blocks) do
			if not visited[b.key] then
				if not grid[b.x] then grid[b.x] = {} end
				grid[b.x][b.z] = true
			end
		end

		for _, b in ipairs(blocks) do
			if not visited[b.key] then
				if partsBudget >= MAX_PARTS then return meshParts end

				local startX, startZ = b.x, b.z

				-- Expand X
				local widthX = 1
				while grid[startX + widthX] and grid[startX + widthX][startZ] and
				      not visited[posKey(startX + widthX, y, startZ)] do
					widthX = widthX + 1
				end

				-- Expand Z
				local widthZ = 1
				local canExpandZ = true
				while canExpandZ do
					local testZ = startZ + widthZ
					for tx = startX, startX + widthX - 1 do
						if not grid[tx] or not grid[tx][testZ] or visited[posKey(tx, y, testZ)] then
							canExpandZ = false
							break
						end
					end
					if canExpandZ then widthZ = widthZ + 1 end
				end

				-- Mark visited
				for dx = 0, widthX - 1 do
					for dz = 0, widthZ - 1 do
						visited[posKey(startX + dx, y, startZ + dz)] = true
					end
				end

				-- Check water above
				local hasAbove = false
				for dx = 0, widthX - 1 do
					for dz = 0, widthZ - 1 do
						if waterMap[posKey(startX + dx, y + 1, startZ + dz)] then
							hasAbove = true
							break
						end
					end
					if hasAbove then break end
				end

				-- Determine visible faces
				local faces = {}
				if not hasAbove then table.insert(faces, Enum.NormalId.Top) end

				local hasBottom = false
				for dx = 0, widthX - 1 do
					for dz = 0, widthZ - 1 do
						if not waterMap[posKey(startX + dx, y - 1, startZ + dz)] then
							hasBottom = true break
						end
					end
					if hasBottom then break end
				end
				if hasBottom then table.insert(faces, Enum.NormalId.Bottom) end

				local hasLeft = false
				for dz = 0, widthZ - 1 do
					if not waterMap[posKey(startX - 1, y, startZ + dz)] then hasLeft = true break end
				end
				if hasLeft then table.insert(faces, Enum.NormalId.Left) end

				local hasRight = false
				for dz = 0, widthZ - 1 do
					if not waterMap[posKey(startX + widthX, y, startZ + dz)] then hasRight = true break end
				end
				if hasRight then table.insert(faces, Enum.NormalId.Right) end

				local hasBack = false
				for dx = 0, widthX - 1 do
					if not waterMap[posKey(startX + dx, y, startZ - 1)] then hasBack = true break end
				end
				if hasBack then table.insert(faces, Enum.NormalId.Back) end

				local hasFront = false
				for dx = 0, widthX - 1 do
					if not waterMap[posKey(startX + dx, y, startZ + widthZ)] then hasFront = true break end
				end
				if hasFront then table.insert(faces, Enum.NormalId.Front) end

				local worldX = (chunk.x * CHUNK_SX + startX) * BLOCK_SIZE
				local worldY = y * BLOCK_SIZE
				local worldZ = (chunk.z * CHUNK_SZ + startZ) * BLOCK_SIZE
				local tex = hasAbove and texFlow or texStill

				local part = createMergedPart(worldX, worldZ, worldY, widthX, widthZ, SOURCE_HEIGHT, BLOCK_SIZE, tex, faces)
				table.insert(meshParts, part)
				partsBudget = partsBudget + 1
			end
		end
	end
	
	--========================================================================
	-- PHASE 3.5: Greedy meshing for same-level flowing water (flat tops)
	-- Merges adjacent flowing water blocks with same depth into larger parts
	-- Only handles blocks that would render as flat (no slope/corner)
	--========================================================================
	
	-- Group flowing water by Y level and depth for greedy meshing
	local flowingByYDepth = {} -- [y][depth] = {{x, z, key}, ...}
	for _, wb in ipairs(waterBlocks) do
		if not visited[wb.key] and not wb.isSource and not wb.isFalling then
			-- Pre-calculate shape to check if it would be flat
			local flowDir, cornerType = calculateWaterShape(
				chunk, worldManager, sampler, metaSampler,
				wb.x, wb.y, wb.z, wb.height, wb.isFalling
			)
			
			-- Only include blocks that render as flat (no slope needed)
			if flowDir == DIRECTION.NONE and cornerType == CORNER.NONE then
				local hasAbove = waterMap[posKey(wb.x, wb.y + 1, wb.z)]
				
				-- Group by Y and depth (only merge same-level water)
				local groupKey = wb.y * 100 + wb.depth + (hasAbove and 50 or 0)
				if not flowingByYDepth[groupKey] then
					flowingByYDepth[groupKey] = {y = wb.y, depth = wb.depth, hasAbove = hasAbove, blocks = {}}
				end
				table.insert(flowingByYDepth[groupKey].blocks, {x = wb.x, z = wb.z, key = wb.key, height = wb.height})
			end
		end
	end
	
	-- Apply greedy meshing to each Y-depth group
	for _, group in pairs(flowingByYDepth) do
		if partsBudget >= MAX_PARTS then break end
		
		local y = group.y
		local hasAbove = group.hasAbove
		local blocks = group.blocks
		
		if #blocks == 0 then continue end
		
		-- Build grid for this group
		local grid = {}
		local heightMap = {} -- Track height at each position for proper sizing
		for _, b in ipairs(blocks) do
			if not visited[b.key] then
				if not grid[b.x] then 
					grid[b.x] = {} 
					heightMap[b.x] = {}
				end
				grid[b.x][b.z] = true
				heightMap[b.x][b.z] = b.height
			end
		end
		
		-- Greedy mesh this group
		for _, b in ipairs(blocks) do
			if visited[b.key] then continue end
			if partsBudget >= MAX_PARTS then break end
			
			local startX, startZ = b.x, b.z
			local baseHeight = heightMap[startX][startZ]
			
			-- Expand X (only merge blocks with same height)
			local widthX = 1
			while grid[startX + widthX] and grid[startX + widthX][startZ] 
				  and not visited[posKey(startX + widthX, y, startZ)]
				  and heightMap[startX + widthX][startZ] == baseHeight do
				widthX = widthX + 1
			end
			
			-- Expand Z uniformly across X extent (only merge blocks with same height)
			local widthZ = 1
			local canExpandZ = true
			while canExpandZ do
				local testZ = startZ + widthZ
				for tx = startX, startX + widthX - 1 do
					if not grid[tx] or not grid[tx][testZ] 
					   or visited[posKey(tx, y, testZ)]
					   or heightMap[tx][testZ] ~= baseHeight then
						canExpandZ = false
						break
					end
				end
				if canExpandZ then widthZ = widthZ + 1 end
			end
			
			-- Mark visited
			for dx = 0, widthX - 1 do
				for dz = 0, widthZ - 1 do
					visited[posKey(startX + dx, y, startZ + dz)] = true
				end
			end
			
			-- Calculate visible faces
			local faces = {}
			if not hasAbove then table.insert(faces, Enum.NormalId.Top) end
			
			-- Check bottom face
			local hasBottom = false
			for dx = 0, widthX - 1 do
				for dz = 0, widthZ - 1 do
					if not waterMap[posKey(startX + dx, y - 1, startZ + dz)] then
						hasBottom = true
						break
					end
				end
				if hasBottom then break end
			end
			if hasBottom then table.insert(faces, Enum.NormalId.Bottom) end
			
			-- Check side faces
			local hasLeft = false
			for dz = 0, widthZ - 1 do
				if not waterMap[posKey(startX - 1, y, startZ + dz)] then hasLeft = true break end
			end
			if hasLeft then table.insert(faces, Enum.NormalId.Left) end
			
			local hasRight = false
			for dz = 0, widthZ - 1 do
				if not waterMap[posKey(startX + widthX, y, startZ + dz)] then hasRight = true break end
			end
			if hasRight then table.insert(faces, Enum.NormalId.Right) end
			
			local hasBack = false
			for dx = 0, widthX - 1 do
				if not waterMap[posKey(startX + dx, y, startZ - 1)] then hasBack = true break end
			end
			if hasBack then table.insert(faces, Enum.NormalId.Back) end
			
			local hasFront = false
			for dx = 0, widthX - 1 do
				if not waterMap[posKey(startX + dx, y, startZ + widthZ)] then hasFront = true break end
			end
			if hasFront then table.insert(faces, Enum.NormalId.Front) end
			
			-- Skip if no visible faces
			if #faces == 0 then continue end
			
			-- Create merged part
			local worldX = (chunk.x * CHUNK_SX + startX) * BLOCK_SIZE
			local worldY = y * BLOCK_SIZE
			local worldZ = (chunk.z * CHUNK_SZ + startZ) * BLOCK_SIZE
			
			local part = createMergedPart(worldX, worldZ, worldY, widthX, widthZ, baseHeight, BLOCK_SIZE, texFlow, faces)
			part.Name = "WaterFlowingMerged"
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
		end
	end

	--========================================================================
	-- PHASE 4: Remaining blocks (flowing water AND source blocks with slopes)
	-- OPTIMIZATION: Full occlusion culling - skip blocks completely surrounded by water
	--========================================================================
	
	-- Helper: check if a block is fully occluded (surrounded by water on all 6 sides)
	local function isFullyOccluded(x, y, z)
		return waterMap[posKey(x, y + 1, z)]
			and waterMap[posKey(x, y - 1, z)]
			and waterMap[posKey(x + 1, y, z)]
			and waterMap[posKey(x - 1, y, z)]
			and waterMap[posKey(x, y, z + 1)]
			and waterMap[posKey(x, y, z - 1)]
	end
	
	for _, wb in ipairs(waterBlocks) do
		if visited[wb.key] then continue end
		if partsBudget >= MAX_PARTS then return meshParts end

		visited[wb.key] = true

		local x, y, z = wb.x, wb.y, wb.z
		
		-- OPTIMIZATION: Skip fully-occluded interior water blocks
		-- These are completely surrounded by water and contribute nothing visually
		if isFullyOccluded(x, y, z) then
			continue
		end
		
		local worldX = (chunk.x * CHUNK_SX + x + 0.5) * BLOCK_SIZE
		local worldY = y * BLOCK_SIZE
		local worldZ = (chunk.z * CHUNK_SZ + z + 0.5) * BLOCK_SIZE

		local hasAbove = waterMap[posKey(x, y + 1, z)] or false
		local faces = getVisibleFaces(waterMap, x, y, z, wb.height, 1)
		
		-- OPTIMIZATION: Skip if no visible faces at all
		if #faces == 0 and hasAbove then
			continue
		end

		-- Falling water: always flat (vertical column)
		-- Note: Most falling water should be handled in Phase 2 box-meshing
		if wb.isFalling then
			local part = createBasePart(worldX, worldY, worldZ, wb.height, BLOCK_SIZE, texFlow, faces)
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
			continue
		end

		-- Calculate shape using Minecraft corner height formula (MAX of neighbors)
		local flowDir, cornerType = calculateWaterShape(
			chunk, worldManager, sampler, metaSampler,
			x, y, z, wb.height, wb.isFalling
		)

		-- Determine base height and texture
		local baseHeight, tex
		if wb.isSource then
			-- Source blocks: full height base, but can have sloped top
			-- Base height is SOURCE_HEIGHT minus WEDGE_HEIGHT for the slope
			if hasAbove or (flowDir == DIRECTION.NONE and cornerType == CORNER.NONE) then
				-- Flat top: use full height
				baseHeight = SOURCE_HEIGHT
			else
				-- Sloped top: reserve space for wedge
				baseHeight = SOURCE_HEIGHT - WEDGE_HEIGHT
			end
			tex = hasAbove and texFlow or texStill
		else
			-- Flowing water: base + wedge
			baseHeight = getBaseHeight(wb.blockId, wb.metadata, hasAbove)
			tex = texFlow
		end

		-- Create base part only if we have visible side/bottom faces OR no water above
		-- This prevents creating invisible base parts under wedges when submerged
		local needsBasePart = baseHeight > 0 and (#faces > 0 or not hasAbove)
		if needsBasePart then
			local base = createBasePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, tex, faces)
			table.insert(meshParts, base)
			partsBudget = partsBudget + 1
		end

		-- Skip top if water above (no visible slope)
		if hasAbove then continue end

		-- Skip top for fully flat blocks (source with no flow direction)
		if wb.isSource and flowDir == DIRECTION.NONE and cornerType == CORNER.NONE then
			continue
		end

		-- Determine which top faces are visible (optimization: not all faces needed for wedges)
		local topFaces = {}
		-- Top face always visible for top pieces
		table.insert(topFaces, Enum.NormalId.Top)
		-- Side faces only if not occluded by water
		if not waterMap[posKey(x, y, z - 1)] then table.insert(topFaces, Enum.NormalId.Back) end
		if not waterMap[posKey(x, y, z + 1)] then table.insert(topFaces, Enum.NormalId.Front) end
		if not waterMap[posKey(x - 1, y, z)] then table.insert(topFaces, Enum.NormalId.Left) end
		if not waterMap[posKey(x + 1, y, z)] then table.insert(topFaces, Enum.NormalId.Right) end

		-- Use flow texture for slopes
		local slopeTex = texFlow

		-- Create top piece based on corner type
		-- CONCAVE (1 high, 3 low) → CornerWedgePart (single peak)
		-- CONVEX (3 high, 1 low) → 2 WedgeParts (valley)
		if cornerType >= CORNER.CONCAVE_NE and cornerType <= CORNER.CONCAVE_SW then
			local corner = createConvexCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, slopeTex, topFaces)
			table.insert(meshParts, corner)
			partsBudget = partsBudget + 1
		elseif cornerType >= CORNER.CONVEX_NE and cornerType <= CORNER.CONVEX_SW then
			local wedges = createConcaveCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, slopeTex, topFaces)
			for _, wedge in ipairs(wedges) do
				table.insert(meshParts, wedge)
				partsBudget = partsBudget + 1
				if partsBudget >= MAX_PARTS then return meshParts end
			end
		elseif flowDir ~= DIRECTION.NONE then
			local wedge = createWedgePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, flowDir, slopeTex, topFaces)
			table.insert(meshParts, wedge)
			partsBudget = partsBudget + 1
		else
			-- Flat top for flowing water with no clear direction
			local flat = createFlatTop(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, slopeTex, topFaces)
			table.insert(meshParts, flat)
			partsBudget = partsBudget + 1
		end
	end

	return meshParts
end

-- Export constants
WaterMesher.DIRECTION = DIRECTION
WaterMesher.CORNER = CORNER

return WaterMesher
