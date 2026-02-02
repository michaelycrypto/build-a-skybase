--[[
	WaterDetector.lua
	Detects when players/entities are in water for swimming mechanics.
	
	This module provides position-based water detection using the voxel world.
	It handles:
	- Source blocks (2+ deep = swimming)
	- Flowing water (depth-based)
	- Falling water (waterfalls)
	- Head/feet submersion detection
	
	Usage:
		local WaterDetector = require(path.to.WaterDetector)
		local isInWater = WaterDetector.IsPositionInWater(worldManager, position)
		local state = WaterDetector.GetSwimmingState(worldManager, rootPartPosition)
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local WaterUtils = require(script.Parent.WaterUtils)

local WaterDetector = {}

-- Constants
local BLOCK_SIZE = Constants.BLOCK_SIZE
local WATER_SOURCE = Constants.BlockType.WATER_SOURCE
local _FLOWING_WATER = Constants.BlockType.FLOWING_WATER

-- Character dimensions (approximate R15)
local _CHARACTER_HEIGHT = 5.0 -- studs from feet to head
local FEET_OFFSET = 2.5 -- studs below HumanoidRootPart to feet
local HEAD_OFFSET = 1.5 -- studs above HumanoidRootPart to head (eye level)
local _TORSO_OFFSET = 0 -- HumanoidRootPart is at torso level

-- Swimming state enum
WaterDetector.SwimState = {
	DRY = "Dry",           -- Not in water
	WADING = "Wading",     -- Feet wet, shallow water
	SWIMMING = "Swimming", -- Deep enough to swim
	SUBMERGED = "Submerged" -- Fully underwater (head included)
}

--============================================================================
-- HELPER FUNCTIONS
--============================================================================

--[[
	Convert world position (studs) to block coordinates.
]]
local function worldToBlock(worldPos)
	return Vector3.new(
		math.floor(worldPos.X / BLOCK_SIZE),
		math.floor(worldPos.Y / BLOCK_SIZE),
		math.floor(worldPos.Z / BLOCK_SIZE)
	)
end

--[[
	Get the water surface height at a block position (in studs).
	Returns the Y position of the water surface, or nil if not water.
]]
local function getWaterSurfaceY(worldManager, blockX, blockY, blockZ)
	if not worldManager then return nil end
	
	local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
	if not WaterUtils.IsWater(blockId) then
		return nil
	end
	
	local metadata = worldManager:GetBlockMetadata(blockX, blockY, blockZ) or 0
	
	-- Check if there's water above (for height calculation)
	local aboveId = worldManager:GetBlock(blockX, blockY + 1, blockZ)
	local hasWaterAbove = WaterUtils.IsWater(aboveId)
	
	-- Get water height as fraction of block
	local waterHeight = WaterUtils.GetWaterHeight(blockId, metadata, hasWaterAbove)
	
	-- Convert to world studs
	local blockBaseY = blockY * BLOCK_SIZE
	return blockBaseY + (waterHeight * BLOCK_SIZE)
end

--============================================================================
-- POSITION-BASED DETECTION
--============================================================================

--[[
	Check if a world position is inside water.
	
	@param worldManager: The voxel world manager
	@param worldPos: Vector3 position in world studs
	@return boolean: True if position is inside water volume
]]
function WaterDetector.IsPositionInWater(worldManager, worldPos)
	if not worldManager or not worldPos then return false end
	
	local blockCoords = worldToBlock(worldPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
	if not WaterUtils.IsWater(blockId) then
		return false
	end
	
	-- Check if position is below water surface
	local surfaceY = getWaterSurfaceY(worldManager, blockX, blockY, blockZ)
	if not surfaceY then
		return false
	end
	
	return worldPos.Y < surfaceY
end

--[[
	Get the water level (0-7) at a position.
	
	@param worldManager: The voxel world manager
	@param worldPos: Vector3 position in world studs
	@return number: Water level (0=source/full, 7=shallowest), or -1 if not water
]]
function WaterDetector.GetWaterLevelAt(worldManager, worldPos)
	if not worldManager or not worldPos then return -1 end
	
	local blockCoords = worldToBlock(worldPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
	if not WaterUtils.IsWater(blockId) then
		return -1
	end
	
	-- Source blocks are level 0
	if blockId == WATER_SOURCE then
		return 0
	end
	
	local metadata = worldManager:GetBlockMetadata(blockX, blockY, blockZ) or 0
	return WaterUtils.GetLevel(metadata)
end

--[[
	Check if position is in falling water (waterfall).
	
	@param worldManager: The voxel world manager
	@param worldPos: Vector3 position in world studs
	@return boolean: True if position is in falling water
]]
function WaterDetector.IsInFallingWater(worldManager, worldPos)
	if not worldManager or not worldPos then return false end
	
	local blockCoords = worldToBlock(worldPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
	if not WaterUtils.IsWater(blockId) then
		return false
	end
	
	local metadata = worldManager:GetBlockMetadata(blockX, blockY, blockZ) or 0
	return WaterUtils.IsFalling(metadata)
end

--[[
	Get the water depth in blocks at a horizontal position.
	Scans down from the given Y to count water blocks.
	
	@param worldManager: The voxel world manager
	@param worldPos: Vector3 position in world studs
	@return number: Depth in blocks (0 if not in water)
]]
function WaterDetector.GetWaterDepthBlocks(worldManager, worldPos)
	if not worldManager or not worldPos then return 0 end
	
	local blockCoords = worldToBlock(worldPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	-- First check if we're even in water
	local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
	if not WaterUtils.IsWater(blockId) then
		return 0
	end
	
	-- Count water blocks above and below
	local depth = 1 -- Current block counts as 1
	
	-- Count up
	for y = blockY + 1, blockY + 50 do
		local id = worldManager:GetBlock(blockX, y, blockZ)
		if WaterUtils.IsWater(id) then
			depth = depth + 1
		else
			break
		end
	end
	
	-- Count down
	for y = blockY - 1, math.max(0, blockY - 50), -1 do
		local id = worldManager:GetBlock(blockX, y, blockZ)
		if WaterUtils.IsWater(id) then
			depth = depth + 1
		else
			break
		end
	end
	
	return depth
end

--[[
	Get the flow direction at a position as a Vector3.
	Used for water current effects pushing the player.
	
	@param worldManager: The voxel world manager
	@param worldPos: Vector3 position in world studs
	@return Vector3?: Normalized flow direction, or nil if no flow
]]
function WaterDetector.GetFlowDirection(worldManager, worldPos)
	if not worldManager or not worldPos then return nil end
	
	local blockCoords = worldToBlock(worldPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	local flowVec2 = WaterUtils.GetFlowVector(worldManager, blockX, blockY, blockZ)
	if not flowVec2 then
		return nil
	end
	
	-- Convert Vector2 (XZ) to Vector3
	return Vector3.new(flowVec2.X, 0, flowVec2.Y)
end

--============================================================================
-- CHARACTER-BASED DETECTION
--============================================================================

--[[
	Check if character's feet are in water.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return boolean: True if feet are in water
]]
function WaterDetector.AreFeetInWater(worldManager, rootPartPos)
	if not rootPartPos then return false end
	local feetPos = rootPartPos - Vector3.new(0, FEET_OFFSET, 0)
	return WaterDetector.IsPositionInWater(worldManager, feetPos)
end

--[[
	Check if character's head is underwater.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return boolean: True if head is underwater
]]
function WaterDetector.IsHeadUnderwater(worldManager, rootPartPos)
	if not rootPartPos then return false end
	local headPos = rootPartPos + Vector3.new(0, HEAD_OFFSET, 0)
	return WaterDetector.IsPositionInWater(worldManager, headPos)
end

--[[
	Check if character's torso is in water.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return boolean: True if torso is in water
]]
function WaterDetector.IsTorsoInWater(worldManager, rootPartPos)
	if not rootPartPos then return false end
	return WaterDetector.IsPositionInWater(worldManager, rootPartPos)
end

--[[
	Get the complete swimming state for a character.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return table: {
		state: SwimState enum value,
		feetInWater: boolean,
		torsoInWater: boolean,
		headUnderwater: boolean,
		waterDepth: number (blocks),
		inFallingWater: boolean,
		flowDirection: Vector3?
	}
]]
function WaterDetector.GetSwimmingState(worldManager, rootPartPos)
	local result = {
		state = WaterDetector.SwimState.DRY,
		feetInWater = false,
		torsoInWater = false,
		headUnderwater = false,
		waterDepth = 0,
		inFallingWater = false,
		flowDirection = nil
	}
	
	if not worldManager or not rootPartPos then
		return result
	end
	
	-- Check body parts
	local feetPos = rootPartPos - Vector3.new(0, FEET_OFFSET, 0)
	local headPos = rootPartPos + Vector3.new(0, HEAD_OFFSET, 0)
	
	result.feetInWater = WaterDetector.IsPositionInWater(worldManager, feetPos)
	result.torsoInWater = WaterDetector.IsPositionInWater(worldManager, rootPartPos)
	result.headUnderwater = WaterDetector.IsPositionInWater(worldManager, headPos)
	
	-- If feet aren't in water, we're dry
	if not result.feetInWater then
		result.state = WaterDetector.SwimState.DRY
		return result
	end
	
	-- Get water info at feet level
	result.waterDepth = WaterDetector.GetWaterDepthBlocks(worldManager, feetPos)
	result.inFallingWater = WaterDetector.IsInFallingWater(worldManager, feetPos)
	result.flowDirection = WaterDetector.GetFlowDirection(worldManager, feetPos)
	
	-- Determine swimming state
	if result.headUnderwater then
		result.state = WaterDetector.SwimState.SUBMERGED
	elseif result.torsoInWater or result.waterDepth >= 2 or result.inFallingWater then
		-- Swimming if:
		-- - Torso is submerged
		-- - Water is 2+ blocks deep
		-- - In falling water (waterfall)
		result.state = WaterDetector.SwimState.SWIMMING
	else
		result.state = WaterDetector.SwimState.WADING
	end
	
	return result
end

--[[
	Check if a character should be able to swim at their current position.
	Quick check for movement decisions.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return boolean: True if character should be swimming
]]
function WaterDetector.ShouldSwim(worldManager, rootPartPos)
	if not worldManager or not rootPartPos then return false end
	
	local state = WaterDetector.GetSwimmingState(worldManager, rootPartPos)
	return state.state == WaterDetector.SwimState.SWIMMING 
		or state.state == WaterDetector.SwimState.SUBMERGED
end

--[[
	Get water surface Y position above or at character position.
	Used for swimming to surface.
	
	@param worldManager: The voxel world manager
	@param rootPartPos: Vector3 position of HumanoidRootPart
	@return number?: Y position of water surface in studs, or nil if not in water
]]
function WaterDetector.GetWaterSurfaceY(worldManager, rootPartPos)
	if not worldManager or not rootPartPos then return nil end
	
	local blockCoords = worldToBlock(rootPartPos)
	local blockX, blockY, blockZ = blockCoords.X, blockCoords.Y, blockCoords.Z
	
	-- Scan up to find topmost water block
	local topWaterY = nil
	for y = blockY, blockY + 50 do
		local blockId = worldManager:GetBlock(blockX, y, blockZ)
		if WaterUtils.IsWater(blockId) then
			topWaterY = y
		else
			break
		end
	end
	
	if not topWaterY then
		-- Check if we're at least in water at current level
		local blockId = worldManager:GetBlock(blockX, blockY, blockZ)
		if not WaterUtils.IsWater(blockId) then
			return nil
		end
		topWaterY = blockY
	end
	
	-- Get surface height of topmost water block
	return getWaterSurfaceY(worldManager, blockX, topWaterY, blockZ)
end

return WaterDetector
