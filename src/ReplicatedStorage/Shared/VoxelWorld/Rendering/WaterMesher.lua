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
-- local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
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

-- local DIRECTION_NAMES = {
-- 	[0] = "NONE",
-- 	[1] = "NORTH(-Z)",
-- 	[2] = "SOUTH(+Z)",
-- 	[3] = "EAST(+X)",
-- 	[4] = "WEST(-X)",
-- }

-- local DIRECTION_VECTORS = {
-- 	[DIRECTION.NORTH] = {dx = 0, dz = -1},
-- 	[DIRECTION.SOUTH] = {dx = 0, dz = 1},
-- 	[DIRECTION.EAST] = {dx = 1, dz = 0},
-- 	[DIRECTION.WEST] = {dx = -1, dz = 0},
-- }

-- local OPPOSITE_DIRECTION = {
-- 	[DIRECTION.NORTH] = DIRECTION.SOUTH,
-- 	[DIRECTION.SOUTH] = DIRECTION.NORTH,
-- 	[DIRECTION.EAST] = DIRECTION.WEST,
-- 	[DIRECTION.WEST] = DIRECTION.EAST,
-- }

--============================================================================
-- CORNER SYSTEM
--============================================================================
-- Naming follows geometric convention:
-- CONVEX = single high corner (peak sticking up, like a mountain top)
-- CONCAVE = single low corner (valley dipping down, like a bowl)

local CORNER = {
	NONE = 0,
	-- Convex corners: Peak at the named corner (1 high, 3 low)
	-- Rendered as CornerWedgePart pointing upward at that corner
	CONVEX_NE = 1,   -- Peak at NE corner
	CONVEX_NW = 2,   -- Peak at NW corner
	CONVEX_SE = 3,   -- Peak at SE corner
	CONVEX_SW = 4,   -- Peak at SW corner
	-- Concave corners: Valley at the named corner (3 high, 1 low)
	-- Rendered as two WedgeParts meeting at that corner
	CONCAVE_NE = 5,  -- Valley at NE corner
	CONCAVE_NW = 6,  -- Valley at NW corner
	CONCAVE_SE = 7,  -- Valley at SE corner
	CONCAVE_SW = 8,  -- Valley at SW corner
}

-- local CORNER_NAMES = {
-- 	[0] = "NONE",
-- 	[1] = "CONVEX_NE",
-- 	[2] = "CONVEX_NW",
-- 	[3] = "CONVEX_SE",
-- 	[4] = "CONVEX_SW",
-- 	[5] = "CONCAVE_NE",
-- 	[6] = "CONCAVE_NW",
-- 	[7] = "CONCAVE_SE",
-- 	[8] = "CONCAVE_SW",
-- }

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
-- Used for CONVEX corners (single peak)
local CORNER_WEDGE_ROTATIONS = {
	[CORNER.CONVEX_NE] = math.rad(0),    -- Vertex at NE
	[CORNER.CONVEX_NW] = math.rad(90),   -- Vertex at NW
	[CORNER.CONVEX_SE] = math.rad(-90),  -- Vertex at SE
	[CORNER.CONVEX_SW] = math.rad(180),  -- Vertex at SW
}

-- Two-wedge corner directions: both wedges slope TOWARD the corner
-- Used for CONCAVE corners (single valley formed by two wedges meeting)
local TWO_WEDGE_DIRECTIONS = {
	[CORNER.CONCAVE_NE] = {DIRECTION.NORTH, DIRECTION.EAST},  -- Valley at NE
	[CORNER.CONCAVE_NW] = {DIRECTION.NORTH, DIRECTION.WEST},  -- Valley at NW
	[CORNER.CONCAVE_SE] = {DIRECTION.SOUTH, DIRECTION.EAST},  -- Valley at SE
	[CORNER.CONCAVE_SW] = {DIRECTION.SOUTH, DIRECTION.WEST},  -- Valley at SW
}

--============================================================================
-- WORLD-TO-LOCAL FACE MAPPING FOR ROTATED PARTS
--============================================================================
-- When parts are rotated around Y, world-space face directions must be
-- transformed to local-space NormalIds for correct texture application.
-- Key: rotation in radians, Value: mapping from world direction to local NormalId

local WORLD_TO_LOCAL_FACE = {
	-- 0° rotation (NORTH): World faces = Local faces
	[0] = {
		north = Enum.NormalId.Back,   -- World -Z = Local Back
		south = Enum.NormalId.Front,  -- World +Z = Local Front
		east = Enum.NormalId.Right,   -- World +X = Local Right
		west = Enum.NormalId.Left,    -- World -X = Local Left
	},
	-- 90° rotation (WEST): Part's local -Z now points World +X
	[90] = {
		north = Enum.NormalId.Right,  -- World -Z = Local Right
		south = Enum.NormalId.Left,   -- World +Z = Local Left
		east = Enum.NormalId.Back,    -- World +X = Local Back
		west = Enum.NormalId.Front,   -- World -X = Local Front
	},
	-- -90° rotation (EAST): Part's local -Z now points World -X
	[-90] = {
		north = Enum.NormalId.Left,   -- World -Z = Local Left
		south = Enum.NormalId.Right,  -- World +Z = Local Right
		east = Enum.NormalId.Front,   -- World +X = Local Front
		west = Enum.NormalId.Back,    -- World -X = Local Back
	},
	-- 180° rotation (SOUTH): Part's local -Z now points World +Z
	[180] = {
		north = Enum.NormalId.Front,  -- World -Z = Local Front
		south = Enum.NormalId.Back,   -- World +Z = Local Back
		east = Enum.NormalId.Left,    -- World +X = Local Left
		west = Enum.NormalId.Right,   -- World -X = Local Right
	},
}

-- Helper to get the face mapping for a given rotation (in radians)
local function getFaceMapping(rotationRad)
	local deg = math.floor(math.deg(rotationRad) + 0.5) % 360
	if deg > 180 then deg = deg - 360 end  -- Normalize to -180 to 180
	return WORLD_TO_LOCAL_FACE[deg] or WORLD_TO_LOCAL_FACE[0]
end

-- Transform world-space visible faces to local-space NormalIds for a rotated part
local function transformFacesToLocal(worldFaces, rotationRad)
	local mapping = getFaceMapping(rotationRad)
	local localFaces = {}

	for _, face in ipairs(worldFaces) do
		if face == Enum.NormalId.Top then
			table.insert(localFaces, Enum.NormalId.Top)
		elseif face == Enum.NormalId.Bottom then
			table.insert(localFaces, Enum.NormalId.Bottom)
		elseif face == Enum.NormalId.Back then  -- World -Z (North)
			table.insert(localFaces, mapping.north)
		elseif face == Enum.NormalId.Front then -- World +Z (South)
			table.insert(localFaces, mapping.south)
		elseif face == Enum.NormalId.Right then -- World +X (East)
			table.insert(localFaces, mapping.east)
		elseif face == Enum.NormalId.Left then  -- World -X (West)
			table.insert(localFaces, mapping.west)
		end
	end

	return localFaces
end

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
			-- Source block (depth 0) = SOURCE_HEIGHT (7/8), not full height
			-- This matches how source blocks render at the surface
			return SOURCE_HEIGHT
		end
		-- Calculate height based on source depth
		sourceDepth = math.clamp(sourceDepth, 1, 7)
		return 1.0 - (sourceDepth / 8)
	end
	local level = WaterUtils.GetDepth(metadata)
	-- Clamp to valid range
	if level <= 0 then
		level = 1
	end
	level = math.clamp(level, 1, 7)
	-- Minecraft formula: height = 1.0 - (level / 8)
	-- Level 1 = 0.875, Level 7 = 0.125
	return 1.0 - (level / 8)
end

local function getBaseHeight(blockId, metadata, hasWaterAbove)
	-- Full height when water above (no visible top, connects seamlessly to water above)
	if hasWaterAbove then
		return 1.0
	end
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
	- CONVEX: 1 high, 3 low (single peak) → CornerWedgePart
	- CONCAVE: 3 high, 1 low (single valley) → 2 WedgeParts
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

	-- 1 high, 3 low: CONVEX (single peak pointing up at the high corner)
	if highCount == 1 then
		if neHigh then
			return DIRECTION.SOUTH, CORNER.CONVEX_NE
		end
		if nwHigh then
			return DIRECTION.SOUTH, CORNER.CONVEX_NW
		end
		if seHigh then
			return DIRECTION.NORTH, CORNER.CONVEX_SE
		end
		if swHigh then
			return DIRECTION.NORTH, CORNER.CONVEX_SW
		end
	end

	-- 3 high, 1 low: CONCAVE (single valley/dip at the low corner)
	if highCount == 3 then
		if not neHigh then
			return DIRECTION.SOUTH, CORNER.CONCAVE_NE
		end
		if not nwHigh then
			return DIRECTION.SOUTH, CORNER.CONCAVE_NW
		end
		if not seHigh then
			return DIRECTION.NORTH, CORNER.CONCAVE_SE
		end
		if not swHigh then
			return DIRECTION.NORTH, CORNER.CONCAVE_SW
		end
	end

	-- 2 high, 2 low: Check if adjacent (SLOPE) or diagonal (SADDLE)
	if highCount == 2 then
		-- North edge high (NE + NW) → slopes toward South
		if neHigh and nwHigh then
			return DIRECTION.SOUTH, CORNER.NONE
		end
		-- South edge high (SE + SW) → slopes toward North
		if seHigh and swHigh then
			return DIRECTION.NORTH, CORNER.NONE
		end
		-- East edge high (NE + SE) → slopes toward West
		if neHigh and seHigh then
			return DIRECTION.WEST, CORNER.NONE
		end
		-- West edge high (NW + SW) → slopes toward East
		if nwHigh and swHigh then
			return DIRECTION.EAST, CORNER.NONE
		end
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

-- Check if a side face is exposed (neighbor water is shorter or doesn't exist)
-- Returns true if the side face should be textured
-- fallingWaterMap - falling water neighbors don't occlude horizontal water
-- currentIsFalling - if true, current block is falling water (optional parameter)
local function isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, nx, ny, nz, currentHeight, currentIsFalling)
	local key = posKey(nx, ny, nz)
	-- No water at neighbor position = definitely exposed (adjacent to air/solid)
	if not waterMap[key] then
		return true
	end
	-- Falling water shouldn't occlude horizontal water sides
	-- Waterfalls are visually separate from horizontal flow
	if fallingWaterMap and fallingWaterMap[key] then
		return true
	end
	-- If current block is falling water and neighbor is NOT falling (horizontal water),
	-- always expose the side face - there's a visual discontinuity at the junction
	-- This handles the "spread joins waterfall" edge case
	if currentIsFalling and fallingWaterMap and not fallingWaterMap[key] then
		return true
	end
	-- For non-falling water neighbors, compare heights
	-- Only occlude if neighbor water fully covers the current block's side
	-- Use strict less-than to prevent z-fighting when blocks are same height
	local neighborHeight = waterHeightMap[key] or 0
	return neighborHeight < currentHeight
end

local function getVisibleFaces(waterMap, waterHeightMap, fallingWaterMap, x, y, z, currentHeight, yBlocks)
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

	-- Sides: check if exposed (no water OR neighbor water is shorter)
	-- For multi-block parts, check all y levels
	local hasN, hasS, hasE, hasW = true, true, true, true
	for checkY = y, y + yBlocks - 1 do
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, checkY, z - 1, currentHeight) then
			hasN = false
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, checkY, z + 1, currentHeight) then
			hasS = false
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x + 1, checkY, z, currentHeight) then
			hasE = false
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x - 1, checkY, z, currentHeight) then
			hasW = false
		end
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
	if not textureId or not faces or #faces == 0 then
		return
	end
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

	-- Transform world-space faces to local-space for the rotated wedge
	local localFaces = transformFacesToLocal(faces, rotation)
	applyTextures(wedge, textureId, bs, localFaces)
	return wedge
end

--[[
	Create CONCAVE corner: Two wedges forming a valley at the corner.
	Both wedges slope TOWARD the corner location.
	Used when 3 corners are high and 1 is low (valley dipping down).
]]
local function createConcaveCorner(worldX, worldY, worldZ, baseHeight, bs, cornerType, textureId, faces)
	local parts = {}
	local wedgeH = WEDGE_HEIGHT * bs
	local wedgeY = worldY + baseHeight * bs + wedgeH * 0.5

	local dirs = TWO_WEDGE_DIRECTIONS[cornerType]
	if not dirs then
		return parts
	end

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

	local rotation1 = WEDGE_ROTATIONS[dirs[1]] or 0
	wedge1.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))
	wedge1.CFrame = CFrame.new(snap(worldX), snap(wedgeY), snap(worldZ)) *
	                CFrame.Angles(0, rotation1, 0)
	-- Transform world-space faces to local-space for the rotated wedge
	local localFaces1 = transformFacesToLocal(faces, rotation1)
	applyTextures(wedge1, textureId, bs, localFaces1)
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

	local rotation2 = WEDGE_ROTATIONS[dirs[2]] or 0
	wedge2.Size = Vector3.new(snap(bs), snap(wedgeH), snap(bs))
	wedge2.CFrame = CFrame.new(snap(worldX), snap(wedgeY), snap(worldZ)) *
	                CFrame.Angles(0, rotation2, 0)
	-- Transform world-space faces to local-space for the rotated wedge
	local localFaces2 = transformFacesToLocal(faces, rotation2)
	applyTextures(wedge2, textureId, bs, localFaces2)
	table.insert(parts, wedge2)

	return parts
end

--[[
	Create CONVEX corner: Single CornerWedgePart with peak pointing at the corner.
	Used when 1 corner is high (peak sticking up).
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
	-- Look up rotation - CONVEX corners are 1-4
	local rotation = CORNER_WEDGE_ROTATIONS[cornerType] or 0
	corner.CFrame = CFrame.new(snap(worldX), snap(cornerY), snap(worldZ)) * CFrame.Angles(0, rotation, 0)

	-- Transform world-space faces to local-space for the rotated corner
	local localFaces = transformFacesToLocal(faces, rotation)
	applyTextures(corner, textureId, bs, localFaces)
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
		if not wm then
			return Constants.BlockType.AIR
		end
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
		if not wm then
			return 0
		end
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
	local waterMap = {}        -- [posKey] = true (water exists)
	local waterHeightMap = {}  -- [posKey] = height (water visual height for side face culling)
	local fallingWaterMap = {} -- [posKey] = true (falling water - shouldn't occlude horizontal flow)
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
				if h > maxH then
					maxH = h
				end
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
						waterHeightMap[key] = height  -- Store height for side face culling
						if WaterUtils.IsFalling(meta) then
							fallingWaterMap[key] = true  -- Mark falling water for special handling
						end
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
						if y < waterYMin then
							waterYMin = y
						end
						if y > waterYMax then
							waterYMax = y
						end
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
	-- Also store heights for proper side face occlusion checks
	if hasWater then
		for y = waterYMin, waterYMax do
			for z = 0, CHUNK_SZ - 1 do
				-- Left neighbor (-X edge)
				local leftId = sampler(worldManager, chunk, -1, y, z)
				if WaterUtils.IsWater(leftId) then
					local key = posKey(-1, y, z)
					waterMap[key] = true
					local meta = metaSampler(worldManager, chunk, -1, y, z) or 0
					local aboveId = sampler(worldManager, chunk, -1, y + 1, z)
					local hasAbove = WaterUtils.IsWater(aboveId)
					waterHeightMap[key] = getWaterHeight(leftId, meta, hasAbove)
					if WaterUtils.IsFalling(meta) then
						fallingWaterMap[key] = true
					end
				end
				-- Right neighbor (+X edge)
				local rightId = sampler(worldManager, chunk, CHUNK_SX, y, z)
				if WaterUtils.IsWater(rightId) then
					local key = posKey(CHUNK_SX, y, z)
					waterMap[key] = true
					local meta = metaSampler(worldManager, chunk, CHUNK_SX, y, z) or 0
					local aboveId = sampler(worldManager, chunk, CHUNK_SX, y + 1, z)
					local hasAbove = WaterUtils.IsWater(aboveId)
					waterHeightMap[key] = getWaterHeight(rightId, meta, hasAbove)
					if WaterUtils.IsFalling(meta) then
						fallingWaterMap[key] = true
					end
				end
			end
			for x = 0, CHUNK_SX - 1 do
				-- Back neighbor (-Z edge)
				local backId = sampler(worldManager, chunk, x, y, -1)
				if WaterUtils.IsWater(backId) then
					local key = posKey(x, y, -1)
					waterMap[key] = true
					local meta = metaSampler(worldManager, chunk, x, y, -1) or 0
					local aboveId = sampler(worldManager, chunk, x, y + 1, -1)
					local hasAbove = WaterUtils.IsWater(aboveId)
					waterHeightMap[key] = getWaterHeight(backId, meta, hasAbove)
					if WaterUtils.IsFalling(meta) then
						fallingWaterMap[key] = true
					end
				end
				-- Front neighbor (+Z edge)
				local frontId = sampler(worldManager, chunk, x, y, CHUNK_SZ)
				if WaterUtils.IsWater(frontId) then
					local key = posKey(x, y, CHUNK_SZ)
					waterMap[key] = true
					local meta = metaSampler(worldManager, chunk, x, y, CHUNK_SZ) or 0
					local aboveId = sampler(worldManager, chunk, x, y + 1, CHUNK_SZ)
					local hasAbove = WaterUtils.IsWater(aboveId)
					waterHeightMap[key] = getWaterHeight(frontId, meta, hasAbove)
					if WaterUtils.IsFalling(meta) then
						fallingWaterMap[key] = true
					end
				end
			end
		end
	end

	--========================================================================
	-- PHASE 2: Column-first box-meshing for falling water BODY
	-- Merges the body of falling columns (blocks WITH water above)
	-- The TOP block (without water above) is left for Phase 4 to render with slope
	-- This creates the base that the sloped top sits on
	--========================================================================

	-- Step 1: Build column map - for each XZ position, find vertical extent
	-- Only include blocks that have water above (the "body" of the waterfall)
	-- Top blocks (no water above) are excluded and handled in Phase 4 with slopes
	local columnMap = {} -- [x][z] = {minY, maxY} representing the falling water body

	for _, wb in ipairs(waterBlocks) do
		if wb.isFalling then
			local x, y, z = wb.x, wb.y, wb.z
			local hasWaterAbove = waterMap[posKey(x, y + 1, z)]

			-- Only include body blocks (those with water above)
			-- Top blocks are left for Phase 4 to render with slope
			if hasWaterAbove then
				if not columnMap[x] then
					columnMap[x] = {}
				end
				if not columnMap[x][z] then
					columnMap[x][z] = {minY = y, maxY = y}
				end
				local col = columnMap[x][z]
				if y < col.minY then
					col.minY = y
				end
				if y > col.maxY then
					col.maxY = y
				end
			end
		end
	end

	-- Step 2: Group columns by their Y extent for optimal merging
	local columnGroups = {} -- [groupKey] = {minY, maxY, columns}

	for x, zMap in pairs(columnMap) do
		for z, col in pairs(zMap) do
			-- Group key combines minY and maxY
			local groupKey = col.minY * 1000 + col.maxY
			if not columnGroups[groupKey] then
				columnGroups[groupKey] = {minY = col.minY, maxY = col.maxY, columns = {}}
			end
			table.insert(columnGroups[groupKey].columns, {x = x, z = z})
		end
	end

	-- Step 3: Greedy merge columns within each Y-extent group
	for _, group in pairs(columnGroups) do
		if partsBudget >= MAX_PARTS then
			break
		end

		local minY, maxY = group.minY, group.maxY
		-- Body height: full blocks from minY to maxY (all have water above, so full height)
		local heightInBlocks = (maxY - minY + 1)

		-- Build 2D grid for this Y-extent group
		local grid = {} -- [x][z] = true
		for _, col in ipairs(group.columns) do
			if not grid[col.x] then
				grid[col.x] = {}
			end
			grid[col.x][col.z] = true
		end

		-- Track which columns have been processed
		local colVisited = {} -- [x * 1000 + z] = true

		-- Greedy merge into boxes
		for _, col in ipairs(group.columns) do
			local colKey = col.x * 1000 + col.z
			if colVisited[colKey] then
				continue
			end
			if partsBudget >= MAX_PARTS then
				break
			end

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
				if canExpandZ then
					dz = dz + 1
				end
			end

			-- Mark all columns in this box as visited and mark individual blocks
			-- Note: We only mark body blocks (minY to maxY), NOT the top block above
			for ix = 0, dx - 1 do
				for iz = 0, dz - 1 do
					local cx, cz = x0 + ix, z0 + iz
					colVisited[cx * 1000 + cz] = true
					-- Mark body Y levels as visited (these all have water above)
					for y = minY, maxY do
						visited[posKey(cx, y, cz)] = true
					end
				end
			end

			-- Calculate visible faces for the merged box
			-- No Top face - the sloped top block will provide that
			local boxFaces = {}

			-- Helper: check if waterfall body face is exposed at a neighbor position
			-- Waterfall body has full height (1.0), so expose face if:
			-- 1. No water at neighbor
			-- 2. Neighbor is horizontal water (not falling) with height < 1.0
			-- 3. Neighbor is also falling water (we still texture for visual clarity)
			local function isBodyFaceExposed(nx, ny, nz)
				local neighborKey = posKey(nx, ny, nz)
				-- No water = exposed
				if not waterMap[neighborKey] then
					return true
				end
				-- Neighbor is falling water = texture for visual clarity at junctions
				if fallingWaterMap[neighborKey] then
					return true
				end
				-- Neighbor is horizontal water - check if it's shorter than full height
				local neighborHeight = waterHeightMap[neighborKey] or 0
				-- Waterfall body is full height (1.0), expose if neighbor is shorter
				return neighborHeight < 1.0
			end

			-- Bottom face: check if any column bottom has no water below
			local hasBottom = false
			for ix = 0, dx - 1 do
				for iz = 0, dz - 1 do
					if not waterMap[posKey(x0 + ix, minY - 1, z0 + iz)] then
						hasBottom = true
						break
					end
				end
				if hasBottom then
					break
				end
			end
			if hasBottom then
				table.insert(boxFaces, Enum.NormalId.Bottom)
			end

			-- Side faces: check if exposed to air or shorter water
			local hasLeft = false
			for y = minY, maxY do
				for iz = 0, dz - 1 do
					if isBodyFaceExposed(x0 - 1, y, z0 + iz) then
						hasLeft = true
						break
					end
				end
				if hasLeft then
					break
				end
			end
			if hasLeft then
				table.insert(boxFaces, Enum.NormalId.Left)
			end

			local hasRight = false
			for y = minY, maxY do
				for iz = 0, dz - 1 do
					if isBodyFaceExposed(x0 + dx, y, z0 + iz) then
						hasRight = true
						break
					end
				end
				if hasRight then
					break
				end
			end
			if hasRight then
				table.insert(boxFaces, Enum.NormalId.Right)
			end

			local hasBack = false
			for y = minY, maxY do
				for ix = 0, dx - 1 do
					if isBodyFaceExposed(x0 + ix, y, z0 - 1) then
						hasBack = true
						break
					end
				end
				if hasBack then
					break
				end
			end
			if hasBack then
				table.insert(boxFaces, Enum.NormalId.Back)
			end

			local hasFront = false
			for y = minY, maxY do
				for ix = 0, dx - 1 do
					if isBodyFaceExposed(x0 + ix, y, z0 + dz) then
						hasFront = true
						break
					end
				end
				if hasFront then
					break
				end
			end
			if hasFront then
				table.insert(boxFaces, Enum.NormalId.Front)
			end

			-- Skip if no visible faces (interior body, but still need part for volume)
			-- Actually create the part even with no faces for proper water volume
			-- Create the merged box part for the body
			local sizeX = dx * BLOCK_SIZE
			local sizeY = heightInBlocks * BLOCK_SIZE
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
			part.Name = "WaterFallBody"
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
	-- Groups by Y level AND hasAbove to ensure correct heights
	--========================================================================
	local sourceGroups = {} -- [y * 2 + (hasAbove ? 1 : 0)] = {y, hasAbove, blocks}
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
				-- Group by Y AND hasAbove to ensure only blocks with same state are merged
				local hasAbove = waterMap[posKey(x, y + 1, z)] or false
				local groupKey = y * 2 + (hasAbove and 1 or 0)
				if not sourceGroups[groupKey] then
					sourceGroups[groupKey] = {y = y, hasAbove = hasAbove, blocks = {}}
				end
				table.insert(sourceGroups[groupKey].blocks, {x = x, z = z, key = wb.key})
			end
			-- Edge sources will be handled in Phase 4 with slopes/corners
		end
	end

	for _, group in pairs(sourceGroups) do
		if partsBudget >= MAX_PARTS then
			return meshParts
		end

		local y = group.y
		local hasAbove = group.hasAbove
		local blocks = group.blocks

		local grid = {}
		for _, b in ipairs(blocks) do
			if not visited[b.key] then
				if not grid[b.x] then
					grid[b.x] = {}
				end
				grid[b.x][b.z] = true
			end
		end

		for _, b in ipairs(blocks) do
			if not visited[b.key] then
				if partsBudget >= MAX_PARTS then
					return meshParts
				end

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
					if canExpandZ then
						widthZ = widthZ + 1
					end
				end

				-- Mark visited
				for dx = 0, widthX - 1 do
					for dz = 0, widthZ - 1 do
						visited[posKey(startX + dx, y, startZ + dz)] = true
					end
				end

				-- Determine height first (needed for side face checks)
				local tex = hasAbove and texFlow or texStill
				-- Use full height when water above so stacked sources merge seamlessly
				local height = hasAbove and 1.0 or SOURCE_HEIGHT

				-- Determine visible faces (using height comparison for sides)
				local faces = {}
				if not hasAbove then
					table.insert(faces, Enum.NormalId.Top)
				end

				local hasBottom = false
				for dx = 0, widthX - 1 do
					for dz = 0, widthZ - 1 do
						if not waterMap[posKey(startX + dx, y - 1, startZ + dz)] then
							hasBottom = true
							break
						end
					end
					if hasBottom then
						break
					end
				end
				if hasBottom then
					table.insert(faces, Enum.NormalId.Bottom)
				end

				-- Check side faces (exposed if no water OR neighbor water is shorter)
				local hasLeft = false
				for dz = 0, widthZ - 1 do
					if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX - 1, y, startZ + dz, height) then
						hasLeft = true
						break
					end
				end
				if hasLeft then
					table.insert(faces, Enum.NormalId.Left)
				end

				local hasRight = false
				for dz = 0, widthZ - 1 do
					if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + widthX, y, startZ + dz, height) then
						hasRight = true
						break
					end
				end
				if hasRight then
					table.insert(faces, Enum.NormalId.Right)
				end

				local hasBack = false
				for dx = 0, widthX - 1 do
					if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + dx, y, startZ - 1, height) then
						hasBack = true
						break
					end
				end
				if hasBack then
					table.insert(faces, Enum.NormalId.Back)
				end

				local hasFront = false
				for dx = 0, widthX - 1 do
					if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + dx, y, startZ + widthZ, height) then
						hasFront = true
						break
					end
				end
				if hasFront then
					table.insert(faces, Enum.NormalId.Front)
				end

				local worldX = (chunk.x * CHUNK_SX + startX) * BLOCK_SIZE
				local worldY = y * BLOCK_SIZE
				local worldZ = (chunk.z * CHUNK_SZ + startZ) * BLOCK_SIZE

				local part = createMergedPart(worldX, worldZ, worldY, widthX, widthZ, height, BLOCK_SIZE, tex, faces)
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
		if partsBudget >= MAX_PARTS then
			break
		end

		local y = group.y
		local hasAbove = group.hasAbove
		local blocks = group.blocks

		if #blocks == 0 then
			continue
		end

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
			if visited[b.key] then
				continue
			end
			if partsBudget >= MAX_PARTS then
				break
			end

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
				if canExpandZ then
					widthZ = widthZ + 1
				end
			end

			-- Mark visited
			for dx = 0, widthX - 1 do
				for dz = 0, widthZ - 1 do
					visited[posKey(startX + dx, y, startZ + dz)] = true
				end
			end

			-- Calculate visible faces (using height comparison for sides)
			local faces = {}
			if not hasAbove then
				table.insert(faces, Enum.NormalId.Top)
			end

			-- Check bottom face
			local hasBottom = false
			for dx = 0, widthX - 1 do
				for dz = 0, widthZ - 1 do
					if not waterMap[posKey(startX + dx, y - 1, startZ + dz)] then
						hasBottom = true
						break
					end
				end
				if hasBottom then
					break
				end
			end
			if hasBottom then
				table.insert(faces, Enum.NormalId.Bottom)
			end

			-- Check side faces (exposed if no water OR neighbor water is shorter)
			local hasLeft = false
			for dz = 0, widthZ - 1 do
				if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX - 1, y, startZ + dz, baseHeight) then
					hasLeft = true
					break
				end
			end
			if hasLeft then
				table.insert(faces, Enum.NormalId.Left)
			end

			local hasRight = false
			for dz = 0, widthZ - 1 do
				if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + widthX, y, startZ + dz, baseHeight) then
					hasRight = true
					break
				end
			end
			if hasRight then
				table.insert(faces, Enum.NormalId.Right)
			end

			local hasBack = false
			for dx = 0, widthX - 1 do
				if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + dx, y, startZ - 1, baseHeight) then
					hasBack = true
					break
				end
			end
			if hasBack then
				table.insert(faces, Enum.NormalId.Back)
			end

			local hasFront = false
			for dx = 0, widthX - 1 do
				if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, startX + dx, y, startZ + widthZ, baseHeight) then
					hasFront = true
					break
				end
			end
			if hasFront then
				table.insert(faces, Enum.NormalId.Front)
			end

			-- Skip if no visible faces
			if #faces == 0 then
				continue
			end

			-- Create merged part
			local worldX = (chunk.x * CHUNK_SX + startX) * BLOCK_SIZE
			local worldY = y * BLOCK_SIZE
			local worldZ = (chunk.z * CHUNK_SZ + startZ) * BLOCK_SIZE
			-- Use full height when water above so stacked water merges seamlessly
			local mergeHeight = hasAbove and 1.0 or baseHeight

			local part = createMergedPart(worldX, worldZ, worldY, widthX, widthZ, mergeHeight, BLOCK_SIZE, texFlow, faces)
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
		if visited[wb.key] then
			continue
		end
		if partsBudget >= MAX_PARTS then
			return meshParts
		end

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
		local faces = getVisibleFaces(waterMap, waterHeightMap, fallingWaterMap, x, y, z, wb.height, 1)

		-- OPTIMIZATION: Skip if no visible faces at all
		if #faces == 0 and hasAbove then
			continue
		end

		-- Falling water handling
		-- Note: Most falling water should be handled in Phase 2 box-meshing
		-- But top of falling columns (no water above) get slopes/corners
		if wb.isFalling then
			if hasAbove then
				-- Middle/bottom of falling column: flat full-height block
				local part = createBasePart(worldX, worldY, worldZ, 1.0, BLOCK_SIZE, texFlow, faces)
				table.insert(meshParts, part)
				partsBudget = partsBudget + 1
				continue
			end
			-- Top of falling column: calculate shape for slope/corner
			-- Fall through to shape calculation below
		end

		-- Calculate shape using Minecraft corner height formula (MAX of neighbors)
		-- For falling water at top of column, pass isFalling=false to allow shape calculation
		local flowDir, cornerType = calculateWaterShape(
			chunk, worldManager, sampler, metaSampler,
			x, y, z, wb.height, wb.isFalling and hasAbove  -- Only skip shape calc if falling AND has water above
		)

		-- Determine base height and texture
		local baseHeight, tex
		if wb.isSource then
			-- Source blocks: full height base, but can have sloped top
			if hasAbove then
				-- Water above: use full block height so stacked sources merge seamlessly
				baseHeight = 1.0
			elseif flowDir == DIRECTION.NONE and cornerType == CORNER.NONE then
				-- Flat top (no slope needed): use SOURCE_HEIGHT (7/8)
				baseHeight = SOURCE_HEIGHT
			else
				-- Sloped top: reserve space for wedge
				baseHeight = SOURCE_HEIGHT - WEDGE_HEIGHT
			end
			tex = hasAbove and texFlow or texStill
		elseif wb.isFalling then
			-- Falling water at top of column (hasAbove=false, handled above)
			-- Base extends from Y=0 of the block up to below the wedge
			-- Wedge is positioned at the correct water level (based on depth)
			if flowDir == DIRECTION.NONE and cornerType == CORNER.NONE then
				-- Flat top: use the depth-based height
				baseHeight = wb.height
			else
				-- Sloped top: base fills space below wedge at water level
				-- wb.height is based on the source depth stored in metadata
				baseHeight = math.max(wb.height - WEDGE_HEIGHT, 0)
			end
			tex = texFlow
		else
			-- Flowing water: base + wedge
			baseHeight = getBaseHeight(wb.blockId, wb.metadata, hasAbove)
			tex = texFlow
		end

		-- Skip top if water above (no visible slope)
		if hasAbove then
			-- Base part with full height, no slope needed
			local needsBasePart = baseHeight > 0 and #faces > 0
			if needsBasePart then
				local base = createBasePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, tex, faces)
				table.insert(meshParts, base)
				partsBudget = partsBudget + 1
			end
			continue
		end

		-- Skip top for fully flat blocks (source, falling, or flowing water with no flow direction)
		-- This handles ALL water types that don't need a slope/wedge on top
		if flowDir == DIRECTION.NONE and cornerType == CORNER.NONE then
			-- Flat top - base part includes Top face and all exposed side faces
			-- Re-calculate faces to ensure all exposed sides are included (defensive)
			local flatFaces = {}
			if not hasAbove then
				table.insert(flatFaces, Enum.NormalId.Top)
			end
			if not waterMap[posKey(x, y - 1, z)] then
				table.insert(flatFaces, Enum.NormalId.Bottom)
			end
			-- Ensure side faces are always checked for flat blocks
			-- Pass wb.isFalling to handle falling water junction with horizontal spread
			if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z - 1, wb.height, wb.isFalling) then
				table.insert(flatFaces, Enum.NormalId.Back)
			end
			if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z + 1, wb.height, wb.isFalling) then
				table.insert(flatFaces, Enum.NormalId.Front)
			end
			if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x - 1, y, z, wb.height, wb.isFalling) then
				table.insert(flatFaces, Enum.NormalId.Left)
			end
			if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x + 1, y, z, wb.height, wb.isFalling) then
				table.insert(flatFaces, Enum.NormalId.Right)
			end

			local needsBasePart = baseHeight > 0 and #flatFaces > 0
			if needsBasePart then
				local base = createBasePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, tex, flatFaces)
				table.insert(meshParts, base)
				partsBudget = partsBudget + 1
			elseif #flatFaces > 0 then
				-- For very shallow water (baseHeight = 0), still create part with exposed faces
				-- This handles level 7 flowing water at edges
				local flat = createFlatTop(worldX, worldY, worldZ, 0, BLOCK_SIZE, tex, flatFaces)
				table.insert(meshParts, flat)
				partsBudget = partsBudget + 1
			end
			continue
		end

		-- We're creating a slope (wedge/corner) on top
		-- Base part should NOT have Top face texture (covered by wedge)
		-- Calculate base part's faces
		local baseFaces = {}
		-- Bottom face: exposed if no water below, OR if water below is horizontal (not falling)
		-- For falling water columns, falling water below connects seamlessly (no bottom face needed)
		-- But if there's horizontal water below, the bottom might be partially exposed
		local belowKey = posKey(x, y - 1, z)
		local hasWaterBelow = waterMap[belowKey]
		local hasFallingBelow = hasWaterBelow and fallingWaterMap[belowKey]
		if not hasWaterBelow or (not hasFallingBelow and wb.isFalling) then
			-- No water below or falling/horizontal junction = bottom exposed
			table.insert(baseFaces, Enum.NormalId.Bottom)
		end
		-- Side faces: use same logic as topFaces (check against wb.height, not baseHeight)
		-- This ensures base and wedge have consistent face texturing
		-- The base part extends from 0 to baseHeight, but for face visibility
		-- we should check if neighbor water fully occludes the visual column
		-- Pass wb.isFalling to handle falling water junction with horizontal spread
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z - 1, wb.height, wb.isFalling) then
			table.insert(baseFaces, Enum.NormalId.Back)  -- North, -Z
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z + 1, wb.height, wb.isFalling) then
			table.insert(baseFaces, Enum.NormalId.Front)  -- South, +Z
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x - 1, y, z, wb.height, wb.isFalling) then
			table.insert(baseFaces, Enum.NormalId.Left)  -- West, -X
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x + 1, y, z, wb.height, wb.isFalling) then
			table.insert(baseFaces, Enum.NormalId.Right)  -- East, +X
		end

		-- Create base part with side/bottom faces only
		local needsBasePart = baseHeight > 0 and #baseFaces > 0
		if needsBasePart then
			local base = createBasePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, tex, baseFaces)
			table.insert(meshParts, base)
			partsBudget = partsBudget + 1
		end

		-- Determine which faces are visible for the wedge/corner on top
		local topFaces = {}
		-- Top face always visible for top pieces (the sloped surface)
		table.insert(topFaces, Enum.NormalId.Top)
		-- Bottom face: if no base part below the wedge AND (no water below OR non-falling water below falling block)
		if not needsBasePart then
			if not hasWaterBelow or (not hasFallingBelow and wb.isFalling) then
				table.insert(topFaces, Enum.NormalId.Bottom)
			end
		end
		-- Side faces: exposed if no water OR neighbor water is shorter than this block
		-- Pass wb.isFalling to handle falling water junction with horizontal spread
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z - 1, wb.height, wb.isFalling) then
			table.insert(topFaces, Enum.NormalId.Back)
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x, y, z + 1, wb.height, wb.isFalling) then
			table.insert(topFaces, Enum.NormalId.Front)
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x - 1, y, z, wb.height, wb.isFalling) then
			table.insert(topFaces, Enum.NormalId.Left)
		end
		if isSideFaceExposed(waterMap, waterHeightMap, fallingWaterMap, x + 1, y, z, wb.height, wb.isFalling) then
			table.insert(topFaces, Enum.NormalId.Right)
		end

		-- Use flow texture for slopes
		local slopeTex = texFlow

		-- Create top piece based on corner type
		-- CONVEX (1 high, 3 low) → CornerWedgePart (single peak)
		-- CONCAVE (3 high, 1 low) → 2 WedgeParts (valley)
		if cornerType >= CORNER.CONVEX_NE and cornerType <= CORNER.CONVEX_SW then
			local corner = createConvexCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, slopeTex, topFaces)
			table.insert(meshParts, corner)
			partsBudget = partsBudget + 1
		elseif cornerType >= CORNER.CONCAVE_NE and cornerType <= CORNER.CONCAVE_SW then
			local wedges = createConcaveCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, slopeTex, topFaces)
			for _, wedge in ipairs(wedges) do
				table.insert(meshParts, wedge)
				partsBudget = partsBudget + 1
				if partsBudget >= MAX_PARTS then
					return meshParts
				end
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
