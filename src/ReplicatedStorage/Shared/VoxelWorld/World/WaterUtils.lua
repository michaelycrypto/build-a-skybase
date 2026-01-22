--[[
	WaterUtils.lua
	Helpers for water block metadata and identification.
	
	============================================================================
	MINECRAFT WATER LEVEL SYSTEM
	============================================================================
	
	Water uses a level-based system (0-7):
	- Source block: Full height (1.0), level 0
	- Falling water: Full height (1.0), level 0, falling flag set
	- Flowing water: Level 1-7, height = (8 - level) / 9
	
	Metadata format (single byte):
	- Bits 0-2: Water level (0-7)
	- Bit 3: Falling flag (water can flow down OR has water above)
	- Bits 4-7: Fall distance (0-15) - tracks vertical fall for spread reduction
	
	============================================================================
	WATER SPREAD (8 directions, max 7 blocks)
	============================================================================
	
	Water spreads to all 8 neighbors (N/NE/E/SE/S/SW/W/NW):
	- Cardinal spread: Direct from source/flowing water
	- Diagonal spread: Filled by orthogonal flows meeting
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

-- Cardinal direction vectors (used for water spread)
WaterUtils.CARDINAL_DIRS = {
	{dx = 0, dz = -1, name = "N"},   -- North (-Z)
	{dx = 1, dz = 0, name = "E"},    -- East (+X)
	{dx = 0, dz = 1, name = "S"},    -- South (+Z)
	{dx = -1, dz = 0, name = "W"},   -- West (-X)
}

--============================================================================
-- BLOCK TYPE CHECKS
--============================================================================

function WaterUtils.IsWater(blockId: number?): boolean
	if not blockId then return false end
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
	
	Water height system:
	- Source: 1.0 (full height)
	- Falling: 1.0 (full height column)
	- Flowing Level 0: ~0.89 (8/9)
	- Flowing Level 1: ~0.78 (7/9)
	- Flowing Level 2: ~0.67 (6/9)
	- Flowing Level 3: ~0.56 (5/9)
	- Flowing Level 4: ~0.44 (4/9)
	- Flowing Level 5: ~0.33 (3/9)
	- Flowing Level 6: ~0.22 (2/9)
	- Flowing Level 7: ~0.11 (1/9, minimum visible)
]]
function WaterUtils.GetWaterHeight(blockId: number, metadata: number?): number
	-- Source blocks render at full height
	if blockId == Constants.BlockType.WATER_SOURCE then
		return 1.0
	end
	
	-- Non-water blocks have no height
	if blockId ~= Constants.BlockType.FLOWING_WATER then
		return 0
	end
	
	local meta = metadata or 0
	
	-- Falling water always renders at full height
	if WaterUtils.IsFalling(meta) then
		return 1.0
	end
	
	local level = WaterUtils.GetLevel(meta)
	
	-- Height formula: (8 - level) / 9
	-- Level 0 = 8/9 ≈ 0.89, Level 7 = 1/9 ≈ 0.11
	return (8 - level) / 9
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
	if not blockId then return false end
	
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
	if not blockId then return false end
	if blockId == Constants.BlockType.AIR then return false end
	
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
	
	-- Source blocks have no horizontal sources
	if isSource then
		return sourceDirections, flowDirections
	end
	
	-- Falling water's source is above only
	if isFalling then
		return sourceDirections, flowDirections
	end
	
	-- Check CARDINAL neighbors only (no diagonals!)
	for _, dir in ipairs(WaterUtils.CARDINAL_DIRS) do
		local nx, nz = x + dir.dx, z + dir.dz
		local neighborId = worldManager:GetBlock(nx, y, nz)
		
		if neighborId then
			if WaterUtils.IsWater(neighborId) then
				local neighborMeta = worldManager:GetBlockMetadata(nx, y, nz) or 0
				local neighborIsSource = WaterUtils.IsSource(neighborId)
				local neighborIsFalling = WaterUtils.IsFalling(neighborMeta)
				local neighborLevel = neighborIsSource and 0 or WaterUtils.GetLevel(neighborMeta)
				
				-- Source or falling = always a source direction
				if neighborIsSource or neighborIsFalling then
					table.insert(sourceDirections, dir.name)
				elseif neighborLevel < currentLevel then
					-- Lower level = source direction
					table.insert(sourceDirections, dir.name)
				elseif neighborLevel > currentLevel then
					-- Higher level = flow direction
					table.insert(flowDirections, dir.name)
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
	Get a simple string describing the water surface for debug display.
]]
function WaterUtils.GetCornerString(worldManager, x: number, y: number, z: number)
	if not worldManager then return "?" end
	
	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then
		return "N/A"
	end
	
	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	local isSource = WaterUtils.IsSource(blockId)
	local isFalling = WaterUtils.IsFalling(metadata)
	local level = WaterUtils.GetLevel(metadata)
	
	if isSource then
		return "SOURCE"
	elseif isFalling then
		return "FALLING"
	else
		return string.format("L%d", level)
	end
end

--[[
	Calculate the dominant flow direction for a water block.
	Used for rendering flow direction indicators.
	Returns: Vector2 (normalized) or nil if no flow
]]
function WaterUtils.GetFlowVector(worldManager, x: number, y: number, z: number)
	if not worldManager then return nil end
	
	local blockId = worldManager:GetBlock(x, y, z)
	if not WaterUtils.IsWater(blockId) then return nil end
	
	local metadata = worldManager:GetBlockMetadata(x, y, z) or 0
	local isSource = WaterUtils.IsSource(blockId)
	local isFalling = WaterUtils.IsFalling(metadata)
	
	-- Source blocks and falling water have no horizontal flow vector
	if isSource or isFalling then
		return nil
	end
	
	local currentLevel = WaterUtils.GetLevel(metadata)
	local flowX, flowZ = 0, 0
	
	-- Check cardinal neighbors
	for _, dir in ipairs(WaterUtils.CARDINAL_DIRS) do
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
