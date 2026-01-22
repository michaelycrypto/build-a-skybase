--[[
	WaterMesher.lua
	Renders water blocks using optimized greedy meshing with Parts and WedgeParts/CornerWedgeParts.

	============================================================================
	OPTIMIZATIONS
	============================================================================
	- Vertical column merging: Consecutive falling water blocks merge into single tall Part
	- Horizontal greedy meshing: Adjacent same-height source water blocks merge into larger Parts
	- Selective face texturing: Only texture faces not adjacent to other water blocks

	============================================================================
	DEPTH SYSTEM
	============================================================================
	- Source (depth 0): Full 7/8 height Part, no slope
	- Depth 1-6: Base Part + WedgePart on top (total height decreases with depth)
	- Depth 7: WedgePart only (1/8 height)

	============================================================================
	CORNER SYSTEM
	============================================================================

	CONCAVE CORNERS (formerly "inner")
	---------------------------------
	- Water body shape: L-shaped pool, inside corner
	- Water surface: VALLEY/DIP at the corner (lowest point)
	- Flow pattern: Water CONVERGES from two perpendicular sources
	- Rendering: Two WedgeParts sloping DOWN toward the corner
	- Detection: 2 perpendicular sources with blocked/limited flow in corner directions

	Example: Corner of a swimming pool

	    S         Sources at S (south) and W (west)
	    |         Valley forms at NE corner
	  S-X         X = current block with CONCAVE_NE

	CONVEX CORNERS (formerly "outer")
	---------------------------------
	- Water body shape: Peninsula, outside corner
	- Water surface: PEAK/POINT at the corner (highest point)
	- Flow pattern: Water DIVERGES toward two perpendicular targets
	- Rendering: Single CornerWedgePart pointing OUT at the corner
	- Detection: 2 perpendicular targets (flow directions), water wrapping around obstacle

	Example: Water flowing around a pillar

	  1 1 1       Water wraps around obstacle
	  1 X .       Block at SW of obstacle has CONVEX_NE
	  1 . .       (peak points toward NE where obstacle is)

	CORNER NAMING CONVENTION
	------------------------
	The direction suffix (NE, NW, SE, SW) indicates the CORNER LOCATION:

	- CONCAVE_NE: Valley at NE corner (+X, -Z). Sources from S and W.
	- CONCAVE_NW: Valley at NW corner (-X, -Z). Sources from S and E.
	- CONCAVE_SE: Valley at SE corner (+X, +Z). Sources from N and W.
	- CONCAVE_SW: Valley at SW corner (-X, +Z). Sources from N and E.

	- CONVEX_NE: Peak at NE corner (+X, -Z). Targets toward N and E.
	- CONVEX_NW: Peak at NW corner (-X, -Z). Targets toward N and W.
	- CONVEX_SE: Peak at SE corner (+X, +Z). Targets toward S and E.
	- CONVEX_SW: Peak at SW corner (-X, +Z). Targets toward S and W.
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local WaterUtils = require(script.Parent.Parent.World.WaterUtils)
local PartPool = require(script.Parent.PartPool)
local TextureManager = require(script.Parent.TextureManager)

local WaterMesher = {}
WaterMesher.__index = WaterMesher

-- Debug flag
local DEBUG_WATER_FLOW = false
local DEBUG_MAX_LOGS = 20

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
-- Default CornerWedgePart: vertex at -X, +Z (SW)
local CONVEX_CORNER_ROTATIONS = {
	[CORNER.CONVEX_NE] = math.rad(180),  -- Vertex at NE: rotate 180° from SW
	[CORNER.CONVEX_NW] = math.rad(-90),  -- Vertex at NW: rotate -90° from SW
	[CORNER.CONVEX_SE] = math.rad(90),   -- Vertex at SE: rotate +90° from SW
	[CORNER.CONVEX_SW] = math.rad(0),    -- Vertex at SW: default
}

-- Concave corner wedge directions: both wedges slope TOWARD the corner (valley)
-- Key = corner type, Value = {dir1, dir2} where wedges slope toward these directions
local CONCAVE_WEDGE_DIRECTIONS = {
	[CORNER.CONCAVE_NE] = {DIRECTION.NORTH, DIRECTION.EAST},  -- Valley at NE
	[CORNER.CONCAVE_NW] = {DIRECTION.NORTH, DIRECTION.WEST},  -- Valley at NW
	[CORNER.CONCAVE_SE] = {DIRECTION.SOUTH, DIRECTION.EAST},  -- Valley at SE
	[CORNER.CONCAVE_SW] = {DIRECTION.SOUTH, DIRECTION.WEST},  -- Valley at SW
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

local function getWaterHeight(blockId, metadata)
	if blockId == Constants.BlockType.WATER_SOURCE then
		return SOURCE_HEIGHT
	end
	if blockId ~= Constants.BlockType.FLOWING_WATER then
		return 0
	end
	if WaterUtils.IsFalling(metadata) then
		return SOURCE_HEIGHT
	end
	local depth = WaterUtils.GetDepth(metadata)
	if depth <= 0 then
		return SOURCE_HEIGHT
	end
	-- Depth 1 = 7/8, depth 7 = 1/8
	return math.max((8 - math.clamp(depth, 1, WaterUtils.MAX_DEPTH)) / 8, WEDGE_HEIGHT)
end

local function getBaseHeight(blockId, metadata)
	local totalHeight = getWaterHeight(blockId, metadata)
	if blockId == Constants.BlockType.WATER_SOURCE or WaterUtils.IsFalling(metadata) then
		return totalHeight
	end
	return math.max(totalHeight - WEDGE_HEIGHT, 0)
end

--============================================================================
-- CORNER DETECTION
--============================================================================

--[[
	Analyze flow pattern to determine corner type.

	@param flowDirs - Array of directions water flows toward (targets)
	@param neighborInfo - Table of neighbor data keyed by direction
	@param isFromSources - True if flowDirs were derived from source directions
	@param currentDepth - Current block's water depth
	@return direction, cornerType
]]
local function analyzeCornerPattern(flowDirs, neighborInfo, isFromSources, currentDepth)
	if #flowDirs < 2 then
		return flowDirs[1] or DIRECTION.NONE, CORNER.NONE
	end

	-- Build direction set
	local hasDir = {}
	for _, dir in ipairs(flowDirs) do
		hasDir[dir] = true
	end

	local hasN = hasDir[DIRECTION.NORTH]
	local hasS = hasDir[DIRECTION.SOUTH]
	local hasE = hasDir[DIRECTION.EAST]
	local hasW = hasDir[DIRECTION.WEST]

	-- Count directions
	local count = (hasN and 1 or 0) + (hasS and 1 or 0) + (hasE and 1 or 0) + (hasW and 1 or 0)

	-- 3+ directions: radial spread, render flat
	if count >= 3 then
		return DIRECTION.NONE, CORNER.NONE
	end

	-- Opposite directions: pass-through flow, render flat
	if (hasN and hasS) or (hasE and hasW) then
		return DIRECTION.NONE, CORNER.NONE
	end

	-- Must be exactly 2 perpendicular directions at this point
	-- Determine which quadrant forms the corner
	local quadrant = nil
	if hasN and hasE then quadrant = "NE"
	elseif hasN and hasW then quadrant = "NW"
	elseif hasS and hasE then quadrant = "SE"
	elseif hasS and hasW then quadrant = "SW"
	end

	if not quadrant then
		return flowDirs[1], CORNER.NONE
	end

	-- Get the two directions forming this corner
	local dir1, dir2
	if quadrant == "NE" then dir1, dir2 = DIRECTION.NORTH, DIRECTION.EAST
	elseif quadrant == "NW" then dir1, dir2 = DIRECTION.NORTH, DIRECTION.WEST
	elseif quadrant == "SE" then dir1, dir2 = DIRECTION.SOUTH, DIRECTION.EAST
	elseif quadrant == "SW" then dir1, dir2 = DIRECTION.SOUTH, DIRECTION.WEST
	end

	-- Analyze neighbors to determine CONCAVE vs CONVEX
	local n1 = neighborInfo[dir1] or {}
	local n2 = neighborInfo[dir2] or {}
	local depthThreshold = currentDepth or 0

	-- Target = water can flow there (air or higher depth water)
	local n1IsTarget = n1.isAir or (n1.isWater and n1.depth > depthThreshold)
	local n2IsTarget = n2.isAir or (n2.isWater and n2.depth > depthThreshold)

	-- Source = water comes from there (lower depth or same-level source)
	local n1IsSource = n1.isWater and (n1.depth < depthThreshold or n1.depth == 0)
	local n2IsSource = n2.isWater and (n2.depth < depthThreshold or n2.depth == 0)

	-- Solid blocker
	local n1IsSolid = n1.isSolid
	local n2IsSolid = n2.isSolid

	--[[
		CONVEX (peak at corner): Both directions lead to targets
		- Water spreads OUT toward both directions
		- The corner is the highest point (peak)

		CONCAVE (valley at corner): At least one direction is source or solid
		- Water comes IN from sources
		- The corner is the lowest point (valley)
	]]
	local isConvex = n1IsTarget and n2IsTarget
	local isConcave = (n1IsSolid or n2IsSolid) or (n1IsSource or n2IsSource)

	-- Ambiguous case: use hint from how we derived the flow directions
	if not isConvex and not isConcave then
		isConvex = isFromSources
		isConcave = not isFromSources
	end

	-- Return appropriate corner type
	if isConvex and not isConcave then
		if quadrant == "NE" then return DIRECTION.NORTH, CORNER.CONVEX_NE
		elseif quadrant == "NW" then return DIRECTION.NORTH, CORNER.CONVEX_NW
		elseif quadrant == "SE" then return DIRECTION.SOUTH, CORNER.CONVEX_SE
		elseif quadrant == "SW" then return DIRECTION.SOUTH, CORNER.CONVEX_SW
		end
	else
		if quadrant == "NE" then return DIRECTION.NORTH, CORNER.CONCAVE_NE
		elseif quadrant == "NW" then return DIRECTION.NORTH, CORNER.CONCAVE_NW
		elseif quadrant == "SE" then return DIRECTION.SOUTH, CORNER.CONCAVE_SE
		elseif quadrant == "SW" then return DIRECTION.SOUTH, CORNER.CONCAVE_SW
		end
	end

	return flowDirs[1], CORNER.NONE
end

--[[
	Determine flow direction and corner type for a water block.

	@return flowDirection, cornerType
]]
local function calculateFlowDirection(chunk, worldManager, sampler, metaSampler, x, y, z, currentDepth, isFalling, hasWaterAbove)
	-- Falling water: no horizontal flow
	if isFalling then
		return DIRECTION.NONE, CORNER.NONE
	end

	-- Gather neighbor information
	local neighborInfo = {}
	for dir, vec in pairs(DIRECTION_VECTORS) do
		local nx, nz = x + vec.dx, z + vec.dz
		local neighborId = sampler(worldManager, chunk, nx, y, nz)

		local info = {
			isWater = WaterUtils.IsWater(neighborId),
			isSource = (neighborId == Constants.BlockType.WATER_SOURCE),
			isSolid = false,
			isAir = false,
			depth = 999,
			isFalling = false,
		}

		if info.isWater then
			local neighborMeta = metaSampler(worldManager, chunk, nx, y, nz)
			info.isFalling = WaterUtils.IsFalling(neighborMeta)
			info.depth = info.isSource and 0 or WaterUtils.GetDepth(neighborMeta)
		else
			local def = BlockRegistry:GetBlock(neighborId)
			if neighborId == Constants.BlockType.AIR or (def and def.solid == false) then
				info.isAir = true
			else
				info.isSolid = true
			end
		end

		neighborInfo[dir] = info
	end

	-- Find SOURCE directions (where water comes FROM)
	-- Immediate source = depth exactly 1 less than current
	local immediateSourceDepth = currentDepth - 1
	local sourceDirections = {}

	for dir, info in pairs(neighborInfo) do
		if info.isWater then
			if info.isFalling or (info.isSource and currentDepth == 1) or info.depth == immediateSourceDepth then
				table.insert(sourceDirections, dir)
			end
		end
	end

	-- Fallback: any lower-depth neighbor
	if #sourceDirections == 0 then
		for dir, info in pairs(neighborInfo) do
			if info.isWater and info.depth < currentDepth then
				table.insert(sourceDirections, dir)
			end
		end
	end

	-- Find TARGET directions (where water flows TO)
	local targetDirections = {}
	for dir, info in pairs(neighborInfo) do
		if info.isAir or (info.isWater and info.depth > currentDepth) then
			table.insert(targetDirections, dir)
		end
	end

	--========================================================================
	-- CASE 1: Water from above spreading horizontally
	--========================================================================
	if hasWaterAbove and #sourceDirections == 0 then
		if #targetDirections == 0 then
			return DIRECTION.NONE, CORNER.NONE
		elseif #targetDirections == 1 then
			return targetDirections[1], CORNER.NONE
		else
			return analyzeCornerPattern(targetDirections, neighborInfo, false, currentDepth)
		end
	end

	--========================================================================
	-- CASE 2: Single source direction
	--========================================================================
	if #sourceDirections == 1 then
		local sourceDir = sourceDirections[1]
		local straightDir = OPPOSITE_DIRECTION[sourceDir]

		-- Check what's in front (straight) and to the sides (perpendicular)
		local hasStraightTarget = false
		local perpTargets = {}

		for _, targetDir in ipairs(targetDirections) do
			if targetDir == straightDir then
				hasStraightTarget = true
			elseif targetDir ~= sourceDir then
				table.insert(perpTargets, targetDir)
			end
		end

		-- Straight flow continues
		if hasStraightTarget then
			return straightDir, CORNER.NONE
		end

		-- 90° turn: single perpendicular target
		if #perpTargets == 1 then
			return perpTargets[1], CORNER.NONE
		end

		-- T-junction: multiple perpendicular targets
		if #perpTargets >= 2 then
			return analyzeCornerPattern(perpTargets, neighborInfo, false, currentDepth)
		end

		-- Dead end: no targets
		return straightDir, CORNER.NONE
	end

	--========================================================================
	-- CASE 3: Multiple source directions
	--========================================================================
	if #sourceDirections >= 2 then
		-- Build source direction set
		local hasSourceDir = {}
		for _, dir in ipairs(sourceDirections) do
			hasSourceDir[dir] = true
		end

		local srcN = hasSourceDir[DIRECTION.NORTH]
		local srcS = hasSourceDir[DIRECTION.SOUTH]
		local srcE = hasSourceDir[DIRECTION.EAST]
		local srcW = hasSourceDir[DIRECTION.WEST]

		-- 3+ sources: water is "held up" from multiple sides, render flat
		if #sourceDirections >= 3 then
			return DIRECTION.NONE, CORNER.NONE
		end

		-- Opposite sources (N+S or E+W): pass-through, render flat
		if (srcN and srcS) or (srcE and srcW) then
			return DIRECTION.NONE, CORNER.NONE
		end

		-- Exactly 2 perpendicular sources: CONCAVE corner candidate
		-- Water converges from two perpendicular directions
		local concaveCorner = CORNER.NONE
		if srcN and srcE then concaveCorner = CORNER.CONCAVE_SW      -- Sources at NE → valley at SW
		elseif srcN and srcW then concaveCorner = CORNER.CONCAVE_SE  -- Sources at NW → valley at SE
		elseif srcS and srcE then concaveCorner = CORNER.CONCAVE_NW  -- Sources at SE → valley at NW
		elseif srcS and srcW then concaveCorner = CORNER.CONCAVE_NE  -- Sources at SW → valley at NE
		end

		if concaveCorner ~= CORNER.NONE then
			-- Get flow directions (opposite of sources)
			local flowDirs = {}
			for _, srcDir in ipairs(sourceDirections) do
				table.insert(flowDirs, OPPOSITE_DIRECTION[srcDir])
			end

			-- Build target set
			local targetSet = {}
			for _, dir in ipairs(targetDirections) do
				targetSet[dir] = true
			end

			-- Count how many flow directions are blocked vs open
			local blocked = 0
			local open = 0
			for _, flowDir in ipairs(flowDirs) do
				if targetSet[flowDir] then
					open = open + 1
				elseif neighborInfo[flowDir] and neighborInfo[flowDir].isSolid then
					blocked = blocked + 1
				end
			end

			-- Use CONCAVE if at least one direction is blocked or only one is open
			-- This creates the "valley filling" effect
			if blocked >= 1 or open <= 1 then
				local primaryDir = flowDirs[1] or DIRECTION.SOUTH
				return primaryDir, concaveCorner
			end
		end

		-- Default: check flow based on targets
		local targetSet = {}
		for _, dir in ipairs(targetDirections) do
			targetSet[dir] = true
		end

		local flowDirs = {}
		for _, srcDir in ipairs(sourceDirections) do
			local flowDir = OPPOSITE_DIRECTION[srcDir]
			if flowDir and targetSet[flowDir] then
				local found = false
				for _, fd in ipairs(flowDirs) do
					if fd == flowDir then found = true break end
				end
				if not found then
					table.insert(flowDirs, flowDir)
				end
			end
		end

		if #flowDirs == 0 then
			if #targetDirections == 1 then
				return targetDirections[1], CORNER.NONE
			elseif #targetDirections > 1 then
				return analyzeCornerPattern(targetDirections, neighborInfo, false, currentDepth)
			end
			return DIRECTION.NONE, CORNER.NONE
		elseif #flowDirs == 1 then
			return flowDirs[1], CORNER.NONE
		end

		return analyzeCornerPattern(flowDirs, neighborInfo, true, currentDepth)
	end

	--========================================================================
	-- CASE 4: No clear source
	--========================================================================
	if #targetDirections > 0 then
		if #targetDirections == 1 then
			return targetDirections[1], CORNER.NONE
		end
		return analyzeCornerPattern(targetDirections, neighborInfo, false, currentDepth)
	end

	-- No flow pattern detected
	return DIRECTION.NONE, CORNER.NONE
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

local function createColumnPart(worldX, worldY, worldZ, heightBlocks, bs, textureId, faces)
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
	part.Name = "WaterColumn"

	local sizeY = heightBlocks * bs
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

	local dirs = CONCAVE_WEDGE_DIRECTIONS[cornerType]
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
	local rotation = CONVEX_CORNER_ROTATIONS[cornerType] or 0
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

	-- Height limit
	local yLimit = CHUNK_SY
	if chunk.heightMap then
		local maxH = 0
		for z = 0, CHUNK_SZ - 1 do
			for x = 0, CHUNK_SX - 1 do
				local h = chunk.heightMap[x + z * CHUNK_SX] or 0
				if h > maxH then maxH = h end
			end
		end
		yLimit = math.clamp(maxH + 2, 1, CHUNK_SY)
	end

	-- Textures
	local texStill = TextureManager:GetTextureId("water_still")
	local texFlow = TextureManager:GetTextureId("water_flow")

	--========================================================================
	-- PHASE 1: Collect water blocks
	--========================================================================
	local waterBlocks = {}
	local waterMap = {}
	local visited = {}

	for y = 0, yLimit - 1 do
		for z = 0, CHUNK_SZ - 1 do
			for x = 0, CHUNK_SX - 1 do
				local blockId = chunk:GetBlock(x, y, z)
				if WaterUtils.IsWater(blockId) then
					local meta = chunk:GetMetadata(x, y, z)
					local height = getWaterHeight(blockId, meta)
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
					end
				end
			end
		end
	end

	-- Add neighbor chunk water to map (for face culling)
	for y = 0, yLimit - 1 do
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

	--========================================================================
	-- PHASE 2: Vertical column merging (falling water)
	--========================================================================
	local fallingCols = {}
	for _, wb in ipairs(waterBlocks) do
		if wb.isFalling and not visited[wb.key] then
			local colKey = wb.x * 256 + wb.z
			if not fallingCols[colKey] then
				fallingCols[colKey] = {x = wb.x, z = wb.z, ys = {}}
			end
			table.insert(fallingCols[colKey].ys, wb.y)
		end
	end

	for _, col in pairs(fallingCols) do
		table.sort(col.ys)
		local i = 1
		while i <= #col.ys do
			if partsBudget >= MAX_PARTS then return meshParts end

			local startY = col.ys[i]
			local endY = startY
			while i + 1 <= #col.ys and col.ys[i + 1] == endY + 1 do
				i = i + 1
				endY = col.ys[i]
			end

			for y = startY, endY do
				visited[posKey(col.x, y, col.z)] = true
			end

			local heightBlocks = endY - startY + 1
			local worldX = (chunk.x * CHUNK_SX + col.x + 0.5) * BLOCK_SIZE
			local worldY = startY * BLOCK_SIZE
			local worldZ = (chunk.z * CHUNK_SZ + col.z + 0.5) * BLOCK_SIZE
			local faces = getVisibleFaces(waterMap, col.x, startY, col.z, SOURCE_HEIGHT, heightBlocks)

			local part = createColumnPart(worldX, worldY, worldZ, heightBlocks, BLOCK_SIZE, texFlow, faces)
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
			i = i + 1
		end
	end

	--========================================================================
	-- PHASE 3: Horizontal greedy meshing (source water)
	--========================================================================
	local sourceByY = {}
	for _, wb in ipairs(waterBlocks) do
		if wb.isSource and not visited[wb.key] then
			if not sourceByY[wb.y] then sourceByY[wb.y] = {} end
			table.insert(sourceByY[wb.y], {x = wb.x, z = wb.z, key = wb.key})
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
	-- PHASE 4: Remaining blocks (flowing water with slopes)
	--========================================================================
	for _, wb in ipairs(waterBlocks) do
		if visited[wb.key] then continue end
		if partsBudget >= MAX_PARTS then return meshParts end

		visited[wb.key] = true

		local x, y, z = wb.x, wb.y, wb.z
		local worldX = (chunk.x * CHUNK_SX + x + 0.5) * BLOCK_SIZE
		local worldY = y * BLOCK_SIZE
		local worldZ = (chunk.z * CHUNK_SZ + z + 0.5) * BLOCK_SIZE

		local hasAbove = waterMap[posKey(x, y + 1, z)] or false
		local faces = getVisibleFaces(waterMap, x, y, z, wb.height, 1)

		-- Source (fallback)
		if wb.isSource then
			local tex = hasAbove and texFlow or texStill
			local part = createBasePart(worldX, worldY, worldZ, wb.height, BLOCK_SIZE, tex, faces)
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
			continue
		end

		-- Falling (fallback)
		if wb.isFalling then
			local part = createBasePart(worldX, worldY, worldZ, wb.height, BLOCK_SIZE, texFlow, faces)
			table.insert(meshParts, part)
			partsBudget = partsBudget + 1
			continue
		end

		-- Flowing water: base + slope
		local baseHeight = getBaseHeight(wb.blockId, wb.metadata)
		local flowDir, cornerType = calculateFlowDirection(
			chunk, worldManager, sampler, metaSampler,
			x, y, z, wb.depth, wb.isFalling, hasAbove
		)

		-- Create base part
		if baseHeight > 0 then
			local base = createBasePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, texFlow, faces)
			table.insert(meshParts, base)
			partsBudget = partsBudget + 1
		end

		-- Skip top if water above
		if hasAbove then continue end

		-- All faces visible for top piece
		local topFaces = {
			Enum.NormalId.Top, Enum.NormalId.Bottom,
			Enum.NormalId.Front, Enum.NormalId.Back,
			Enum.NormalId.Left, Enum.NormalId.Right
		}

		-- Create top piece based on corner type
		if cornerType >= CORNER.CONCAVE_NE and cornerType <= CORNER.CONCAVE_SW then
			local wedges = createConcaveCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, texFlow, topFaces)
			for _, wedge in ipairs(wedges) do
				table.insert(meshParts, wedge)
				partsBudget = partsBudget + 1
				if partsBudget >= MAX_PARTS then return meshParts end
			end
		elseif cornerType >= CORNER.CONVEX_NE and cornerType <= CORNER.CONVEX_SW then
			local corner = createConvexCorner(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, cornerType, texFlow, topFaces)
			table.insert(meshParts, corner)
			partsBudget = partsBudget + 1
		elseif flowDir ~= DIRECTION.NONE then
			local wedge = createWedgePart(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, flowDir, texFlow, topFaces)
			table.insert(meshParts, wedge)
			partsBudget = partsBudget + 1
		else
			local flat = createFlatTop(worldX, worldY, worldZ, baseHeight, BLOCK_SIZE, texFlow, topFaces)
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
