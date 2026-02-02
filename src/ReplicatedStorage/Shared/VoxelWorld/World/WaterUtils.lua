--[[
	WaterUtils.lua
	Helpers for water block metadata and identification.

	============================================================================
	MINECRAFT WATER LEVEL SYSTEM
	============================================================================

	Water uses a level-based system (0-7):
	- Source block: Full height (1.0), level 0
	- Flowing water: Level 1-7, height = (8 - level) / 9
	- Falling water: Level stores "source depth" (where water came from)

	Metadata format (single byte):
	- Bits 0-2: Water level (0-7)
	    - For flowing water: depth from source (1-7)
	    - For falling water: source depth (depth of water that started the fall)
	      This allows the TOP of falling columns to render at the correct height
	- Bit 3: Falling flag (water can flow down OR has water above)
	- Bits 4-7: Fall distance (0-15) - tracks vertical fall for spread reduction

	============================================================================
	FALLING WATER TOP-OF-COLUMN HEIGHT
	============================================================================

	When water flows off an edge:
	- The TOP block of the falling column stores the source's depth in its level bits
	- Blocks BELOW the top store level 0 (they render at full height)
	- This makes the top surface match the height of the water it came from

	Example: Water at depth 3 (height ~0.56) falls off an edge:
	- Top of falling column renders at height 0.56 (matches source)
	- Rest of column renders at full height (1.0)

	============================================================================
	WATER SPREAD (8 directions, max 7 blocks)
	============================================================================

	Water spreads to all 8 horizontal neighbors (cardinals + diagonals):
	- Creates square spread patterns
	- Max horizontal distance: 7 blocks from source (reduced by fall distance)
	- Depth resets to 0 when falling down
	- Fall distance increases when flowing down, reduces horizontal spread

	Level increases by 1 per horizontal step.
	Water prefers flowing toward nearest drop-off (BFS pathfinding).
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.BlockRegistry)

local WaterUtils = {}

-- Water level constants
WaterUtils.MAX_LEVEL = 7         -- Maximum water level (furthest from source)
WaterUtils.MAX_DEPTH = 7         -- Alias for MAX_LEVEL (backward compatibility)
WaterUtils.LEVEL_MASK = 0x07     -- Bits 0-2 for level
WaterUtils.FALLING_FLAG = 0x08   -- Bit 3 for falling
WaterUtils.FALL_DISTANCE_SHIFT = 4  -- Fall distance stored in bits 4-7
WaterUtils.FALL_DISTANCE_MASK = 0xF0 -- Bits 4-7 for fall distance (0-15)
WaterUtils.MAX_FALL_DISTANCE = 15   -- Maximum fall distance value

-- Direction constants (CARDINAL ONLY for spread)
WaterUtils.DIRECTION = {
	NONE = "none",
	N = "N",    -- -Z (North)
	S = "S",    -- +Z (South)
	E = "E",    -- +X (East)
	W = "W",    -- -X (West)
	UP = "Up",  -- +Y
	DOWN = "Dn", -- -Y
}

-- All 8 horizontal direction vectors (cardinals + diagonals)
WaterUtils.HORIZONTAL_DIRS = {
	{dx = 0, dz = -1, name = "N"},    -- North (-Z)
	{dx = 1, dz = 0, name = "E"},     -- East (+X)
	{dx = 0, dz = 1, name = "S"},     -- South (+Z)
	{dx = -1, dz = 0, name = "W"},    -- West (-X)
	{dx = 1, dz = -1, name = "NE"},   -- Northeast (+X, -Z)
	{dx = 1, dz = 1, name = "SE"},    -- Southeast (+X, +Z)
	{dx = -1, dz = 1, name = "SW"},   -- Southwest (-X, +Z)
	{dx = -1, dz = -1, name = "NW"},  -- Northwest (-X, -Z)
}

-- Alias for backward compatibility
WaterUtils.CARDINAL_DIRS = WaterUtils.HORIZONTAL_DIRS

--============================================================================
-- BLOCK TYPE CHECKS
--============================================================================

function WaterUtils.IsWater(blockId: number?): boolean
	if not blockId then
		return false
	end
	return blockId == Constants.BlockType.WATER_SOURCE
		or blockId == Constants.BlockType.FLOWING_WATER
end

function WaterUtils.IsSource(blockId: number?): boolean
	return blockId == Constants.BlockType.WATER_SOURCE
end

function WaterUtils.IsFlowing(blockId: number?): boolean
	return blockId == Constants.BlockType.FLOWING_WATER
end

--============================================================================
-- METADATA ACCESS
--============================================================================

--[[
	Get water level from metadata (0-7).
	Level 0 = closest to source (or source itself)
	Level 7 = furthest from source
]]
function WaterUtils.GetLevel(metadata: number?): number
	return bit32.band(metadata or 0, WaterUtils.LEVEL_MASK)
end

-- Alias for backward compatibility
WaterUtils.GetDepth = WaterUtils.GetLevel

--[[
	Check if water has falling flag set.
	Falling flag is set when:
	1. Water CAN flow down (air/replaceable below), OR
	2. Water HAS water directly above it
]]
function WaterUtils.IsFalling(metadata: number?): boolean
	return bit32.band(metadata or 0, WaterUtils.FALLING_FLAG) ~= 0
end

--[[
	Get fall distance from metadata (0-15).
	Tracks how far water has fallen vertically.
	Used to reduce horizontal spread after long falls.
]]
function WaterUtils.GetFallDistance(metadata: number?): number
	return bit32.rshift(bit32.band(metadata or 0, WaterUtils.FALL_DISTANCE_MASK), WaterUtils.FALL_DISTANCE_SHIFT)
end

--[[
	Create metadata byte from level, falling flag, and optional fall distance.

	@param level: Water level 0-7
	@param falling: Whether water is falling
	@param fallDistance: How far water has fallen (0-15), optional
]]
function WaterUtils.MakeMetadata(level: number, falling: boolean?, fallDistance: number?): number
	local lvl = math.clamp(level or 0, 0, WaterUtils.MAX_LEVEL)
	local meta = lvl
	if falling then
		meta = bit32.bor(meta, WaterUtils.FALLING_FLAG)
	end
	if fallDistance and fallDistance > 0 then
		local clampedFall = math.clamp(fallDistance, 0, WaterUtils.MAX_FALL_DISTANCE)
		meta = bit32.bor(meta, bit32.lshift(clampedFall, WaterUtils.FALL_DISTANCE_SHIFT))
	end
	return meta
end

--[[
	Set level in existing metadata.
]]
function WaterUtils.SetLevel(metadata: number?, level: number): number
	metadata = metadata or 0
	local clamped = math.clamp(level, 0, WaterUtils.MAX_LEVEL)
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(WaterUtils.LEVEL_MASK)),
		clamped
	)
end

--[[
	Get effective max depth based on fall distance.
	Water that has fallen far spreads less horizontally.

	Fall 0-3 blocks: full spread (7 blocks)
	Fall 4-7 blocks: reduced spread (5 blocks)
	Fall 8-11 blocks: minimal spread (3 blocks)
	Fall 12+ blocks: very minimal spread (1 block)
]]
function WaterUtils.GetEffectiveMaxDepth(fallDistance: number?): number
	local fd = fallDistance or 0
	if fd <= 3 then
		return WaterUtils.MAX_LEVEL  -- 7
	elseif fd <= 7 then
		return 5
	elseif fd <= 11 then
		return 3
	else
		return 1
	end
end

--[[
	Set falling flag in existing metadata.
]]
function WaterUtils.SetFalling(metadata: number?, falling: boolean): number
	metadata = metadata or 0
	if falling then
		return bit32.bor(metadata, WaterUtils.FALLING_FLAG)
	end
	return bit32.band(metadata, bit32.bnot(WaterUtils.FALLING_FLAG))
end

--[[
	Set fall distance in existing metadata.
]]
function WaterUtils.SetFallDistance(metadata: number?, fallDistance: number): number
	metadata = metadata or 0
	local clamped = math.clamp(fallDistance, 0, WaterUtils.MAX_FALL_DISTANCE)
	-- Clear existing fall distance bits, then set new value
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(WaterUtils.FALL_DISTANCE_MASK)),
		bit32.lshift(clamped, WaterUtils.FALL_DISTANCE_SHIFT)
	)
end

--============================================================================
-- WATER HEIGHT CALCULATION
--============================================================================

--[[
	Get visual height of water block as fraction of block height [0, 1].

	Water height system (Minecraft-style):
	- Source: 1.0 (full height for corner calculations)
	- Falling (with water above): 1.0 (middle/bottom of column)
	- Falling (no water above): Uses stored source depth (top of column)
	- Flowing Level 1: 0.875 (7/8)
	- Flowing Level 2: 0.75  (6/8)
	- Flowing Level 3: 0.625 (5/8)
	- Flowing Level 4: 0.5   (4/8)
	- Flowing Level 5: 0.375 (3/8)
	- Flowing Level 6: 0.25  (2/8)
	- Flowing Level 7: 0.125 (1/8, minimum visible)

	Formula: height = 1.0 - (level / 8) = (8 - level) / 8

	@param blockId: The water block type
	@param metadata: Block metadata containing level, falling flag, etc.
	@param hasWaterAbove: Optional. If true, falling water returns full height.
	                      If false (top of falling column), uses stored source depth.
	                      Defaults to true for backward compatibility.
]]
function WaterUtils.GetWaterHeight(blockId: number, metadata: number?, hasWaterAbove: boolean?): number
	-- Source blocks render at full height (for corner calculations)
	if blockId == Constants.BlockType.WATER_SOURCE then
		return 1.0
	end

	-- Non-water blocks have no height
	if blockId ~= Constants.BlockType.FLOWING_WATER then
		return 0
	end

	local meta = metadata or 0

	-- Falling water height depends on position in column
	if WaterUtils.IsFalling(meta) then
		-- Default hasWaterAbove to true for backward compatibility
		if hasWaterAbove == nil or hasWaterAbove then
			return 1.0  -- Middle/bottom of column: full height
		end
		-- Top of falling column: use stored source depth
		local sourceDepth = WaterUtils.GetLevel(meta)
		if sourceDepth <= 0 then
			-- Source block (depth 0) at top of fall = 7/8 height (matches SOURCE_HEIGHT)
			return 7/8
		end
		-- Calculate height based on source depth
		sourceDepth = math.clamp(sourceDepth, 1, 7)
		return 1.0 - (sourceDepth / 8)
	end

	local level = WaterUtils.GetLevel(meta)

	-- Clamp level to valid range (level 0 shouldn't happen for flowing water)
	if level <= 0 then
		level = 1
	end
	level = math.clamp(level, 1, 7)

	-- Height formula: 1.0 - (level / 8)
	-- Level 1 = 0.875, Level 7 = 0.125
	return 1.0 - (level / 8)
end

-- Alias for backward compatibility
WaterUtils.GetHeight = WaterUtils.GetWaterHeight

--============================================================================
-- BLOCK PROPERTY CHECKS
--============================================================================

--[[
	Check if a block can be replaced by water (air or non-solid).
]]
function WaterUtils.CanWaterReplace(blockId: number?): boolean
	if not blockId then
		return false
	end

	-- Air is always replaceable
	if blockId == Constants.BlockType.AIR then
		return true
	end

	-- Don't replace source blocks
	if blockId == Constants.BlockType.WATER_SOURCE then
		return false
	end

	-- Can replace flowing water with different level
	if blockId == Constants.BlockType.FLOWING_WATER then
		return true
	end

	-- Check block registry for non-solid blocks
	local def = BlockRegistry:GetBlock(blockId)
	if def and def.solid == false then
		return true
	end

	return false
end

--[[
	Check if a block is solid (blocks water flow).
]]
function WaterUtils.IsSolid(blockId: number?): boolean
	if not blockId then
		return false
	end
	if blockId == Constants.BlockType.AIR then
		return false
	end

	-- Water is not solid
	if WaterUtils.IsWater(blockId) then
		return false
	end

	local def = BlockRegistry:GetBlock(blockId)
	return def and def.solid ~= false
end

--============================================================================
-- FLOW ANALYSIS (For debug/rendering)
--============================================================================

--[[
	Analyze water flow at a position using CARDINAL directions only.
	Returns: sourceDirections (table), flowDirections (table)

	sourceDirections: Where water is coming FROM (lower level neighbors)
	flowDirections: Where water is flowing TO (higher level neighbors or air)
]]
function WaterUtils.AnalyzeFlow(worldManager, x: number, y: number, z: number)
	if not worldManager then
		return {}, {}
	end

	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then
		return {}, {}
	end

	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	local isSource = WaterUtils.IsSource(blockId)
	local isFalling = WaterUtils.IsFalling(metadata)
	local currentLevel = isSource and 0 or WaterUtils.GetLevel(metadata)

	local sourceDirections = {}
	local flowDirections = {}

	-- Check above for source (vertical)
	local aboveId = worldManager:GetBlock(x, y + 1, z)
	if WaterUtils.IsWater(aboveId) then
		table.insert(sourceDirections, WaterUtils.DIRECTION.UP)
	end

	-- Check below for flow target
	local belowId = worldManager:GetBlock(x, y - 1, z)
	if belowId and WaterUtils.CanWaterReplace(belowId) then
		table.insert(flowDirections, WaterUtils.DIRECTION.DOWN)
	end

	-- Falling water's horizontal source is above only
	if isFalling then
		return sourceDirections, flowDirections
	end

	-- Check all 8 horizontal neighbors
	for _, dir in ipairs(WaterUtils.HORIZONTAL_DIRS) do
		local nx, nz = x + dir.dx, z + dir.dz
		local neighborId = worldManager:GetBlock(nx, y, nz)

		if neighborId then
			if WaterUtils.IsWater(neighborId) then
				local neighborMeta = worldManager:GetBlockMetadata(nx, y, nz) or 0
				local neighborIsSource = WaterUtils.IsSource(neighborId)
				local neighborIsFalling = WaterUtils.IsFalling(neighborMeta)
				local neighborLevel = neighborIsSource and 0 or WaterUtils.GetLevel(neighborMeta)

				if isSource then
					-- SOURCE BLOCK: Water flows TO neighbors with higher levels (flowing water we feed)
					-- Adjacent sources are peers (no flow)
					if not neighborIsSource then
						if neighborIsFalling or neighborLevel > 0 then
							-- Water adjacent to source: we're feeding it horizontally
							table.insert(flowDirections, dir.name)
						end
					end
				else
					-- FLOWING WATER: Check for sources and targets
					-- Source or falling = always a source direction
					if neighborIsSource or neighborIsFalling or neighborLevel < currentLevel then
						table.insert(sourceDirections, dir.name)
					elseif neighborLevel > currentLevel then
						-- Higher level = flow direction (water goes there)
						table.insert(flowDirections, dir.name)
					end
				end
			else
				-- Non-water: check if replaceable (flow target)
				if WaterUtils.CanWaterReplace(neighborId) then
					table.insert(flowDirections, dir.name)
				end
			end
		end
	end

	return sourceDirections, flowDirections
end

--[[
	Get formatted flow direction strings for debug display.
]]
function WaterUtils.GetFlowStrings(worldManager, x: number, y: number, z: number)
	local sources, flows = WaterUtils.AnalyzeFlow(worldManager, x, y, z)

	local sourceStr = #sources > 0 and table.concat(sources, ",") or "none"
	local flowStr = #flows > 0 and table.concat(flows, ",") or "none"

	return sourceStr, flowStr
end

--[[
	Get the visual height of a water block (0-1 scale).
	Uses the same formula as WaterMesher for consistency.
]]
local function getWaterVisualHeight(worldManager, x, y, z)
	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then
		return 0
	end
	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	-- Check for water above (needed for falling water top-of-column)
	local hasWaterAbove = WaterUtils.IsWater(worldManager:GetBlock(x, y + 1, z))
	return WaterUtils.GetWaterHeight(blockId, metadata, hasWaterAbove)
end

--[[
	Get a simple string describing the water surface for debug display.
	Uses corner height calculation to match actual rendering.
]]
function WaterUtils.GetCornerString(worldManager, x: number, y: number, z: number)
	if not worldManager then
		return "?"
	end

	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then
		return "N/A"
	end

	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	local isSource = WaterUtils.IsSource(blockId)
	local isFalling = WaterUtils.IsFalling(metadata)
	local level = WaterUtils.GetLevel(metadata)

	-- Falling water always renders flat (full height column)
	if isFalling then
		return "FLAT (fall)"
	end

	-- Get current block height
	local currentHeight = getWaterVisualHeight(worldManager, x, y, z)

	-- Get all 8 neighbor heights
	local hN  = getWaterVisualHeight(worldManager, x, y, z - 1)
	local hS  = getWaterVisualHeight(worldManager, x, y, z + 1)
	local hE  = getWaterVisualHeight(worldManager, x + 1, y, z)
	local hW  = getWaterVisualHeight(worldManager, x - 1, y, z)
	local hNE = getWaterVisualHeight(worldManager, x + 1, y, z - 1)
	local hNW = getWaterVisualHeight(worldManager, x - 1, y, z - 1)
	local hSE = getWaterVisualHeight(worldManager, x + 1, y, z + 1)
	local hSW = getWaterVisualHeight(worldManager, x - 1, y, z + 1)

	-- Minecraft formula: corner height = MAX of the 4 blocks sharing that corner
	local cornerNE = math.max(currentHeight, hN, hE, hNE)
	local cornerNW = math.max(currentHeight, hN, hW, hNW)
	local cornerSE = math.max(currentHeight, hS, hE, hSE)
	local cornerSW = math.max(currentHeight, hS, hW, hSW)

	-- Analyze corner pattern
	local heights = {cornerNE, cornerNW, cornerSE, cornerSW}
	local maxH = math.max(unpack(heights))
	local minH = math.min(unpack(heights))

	-- All same height: FLAT
	if maxH - minH < 0.01 then
		if isSource then
			return "FLAT (src)"
		else
			return string.format("FLAT L%d", level)
		end
	end

	-- Count high and low corners
	local threshold = (maxH + minH) / 2
	local highCorners, lowCorners = {}, {}

	if cornerNE >= threshold then
		table.insert(highCorners, "NE")
	else
		table.insert(lowCorners, "NE")
	end
	if cornerNW >= threshold then
		table.insert(highCorners, "NW")
	else
		table.insert(lowCorners, "NW")
	end
	if cornerSE >= threshold then
		table.insert(highCorners, "SE")
	else
		table.insert(lowCorners, "SE")
	end
	if cornerSW >= threshold then
		table.insert(highCorners, "SW")
	else
		table.insert(lowCorners, "SW")
	end

	local suffix = isSource and " (src)" or string.format(" L%d", level)

	-- 1 high, 3 low: CONVEX (single peak at high corner)
	if #highCorners == 1 then
		return string.format("PEAK %s%s", highCorners[1], suffix)
	end

	-- 3 high, 1 low: CONCAVE (single valley at low corner)
	if #lowCorners == 1 then
		return string.format("VALLEY %s%s", lowCorners[1], suffix)
	end

	-- 2 high, 2 low: SLOPE
	if #highCorners == 2 then
		local h1, h2 = highCorners[1], highCorners[2]
		-- Determine slope direction
		if (h1 == "NE" and h2 == "NW") or (h1 == "NW" and h2 == "NE") then
			return string.format("SLOPE→S%s", suffix)
		elseif (h1 == "SE" and h2 == "SW") or (h1 == "SW" and h2 == "SE") then
			return string.format("SLOPE→N%s", suffix)
		elseif (h1 == "NE" and h2 == "SE") or (h1 == "SE" and h2 == "NE") then
			return string.format("SLOPE→W%s", suffix)
		elseif (h1 == "NW" and h2 == "SW") or (h1 == "SW" and h2 == "NW") then
			return string.format("SLOPE→E%s", suffix)
		else
			-- Diagonal (saddle)
			return string.format("SADDLE%s", suffix)
		end
	end

	return string.format("?%s", suffix)
end

--[[
	Calculate the dominant flow direction for a water block.
	Used for rendering flow direction indicators.
	Returns: Vector2 (normalized) or nil if no flow
]]
function WaterUtils.GetFlowVector(worldManager, x: number, y: number, z: number)
	if not worldManager then
		return nil
	end

	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then
		return nil
	end

	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	local isSource = WaterUtils.IsSource(blockId)
	local isFalling = WaterUtils.IsFalling(metadata)

	-- Source blocks and falling water have no horizontal flow vector
	if isSource or isFalling then
		return nil
	end

	local currentLevel = WaterUtils.GetLevel(metadata)
	local flowX, flowZ = 0, 0

	-- Check all 8 horizontal neighbors
	for _, dir in ipairs(WaterUtils.HORIZONTAL_DIRS) do
		local nx, nz = x + dir.dx, z + dir.dz
		local neighborId = worldManager:GetBlock(nx, y, nz)

		if neighborId then
			if WaterUtils.IsWater(neighborId) then
				local neighborMeta = worldManager:GetBlockMetadata(nx, y, nz) or 0
				local neighborIsSource = WaterUtils.IsSource(neighborId)
				local neighborIsFalling = WaterUtils.IsFalling(neighborMeta)
				local neighborLevel = neighborIsSource and 0 or WaterUtils.GetLevel(neighborMeta)

				-- Flow toward higher levels (away from source)
				if neighborLevel > currentLevel then
					flowX = flowX + dir.dx
					flowZ = flowZ + dir.dz
				elseif neighborIsSource or neighborIsFalling or neighborLevel < currentLevel then
					-- Flow away from lower levels (toward higher)
					flowX = flowX - dir.dx
					flowZ = flowZ - dir.dz
				end
			elseif WaterUtils.CanWaterReplace(neighborId) then
				-- Flow toward replaceable blocks
				flowX = flowX + dir.dx
				flowZ = flowZ + dir.dz
			end
		end
	end

	local mag = math.sqrt(flowX * flowX + flowZ * flowZ)
	if mag > 0.001 then
		return Vector2.new(flowX / mag, flowZ / mag)
	end

	return nil
end

return WaterUtils
