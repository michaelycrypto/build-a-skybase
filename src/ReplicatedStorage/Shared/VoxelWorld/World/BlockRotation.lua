--[[
	BlockRotation.lua
	Utility functions for calculating block rotation based on player facing direction
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local BlockRotation = {}

--[[
	Calculate rotation based on player's look vector
	@param lookVector: Player's forward vector (from HumanoidRootPart.CFrame.LookVector)
	@return: Rotation value (NORTH, EAST, SOUTH, or WEST)
	
	Minecraft coordinate system:
	- +Z = South, -Z = North
	- +X = East, -X = West
]]
function BlockRotation.GetRotationFromLookVector(lookVector: Vector3): number
	-- Calculate angle in radians (atan2 gives angle from +X axis)
	local angle = math.atan2(lookVector.Z, lookVector.X)

	-- Convert to rotation (0-3) using Minecraft coordinate system
	-- Player looking in +X direction → EAST
	-- Player looking in +Z direction → SOUTH (Minecraft convention)
	-- Player looking in -X direction → WEST
	-- Player looking in -Z direction → NORTH (Minecraft convention)

	if angle >= -math.pi/4 and angle < math.pi/4 then
		return Constants.BlockMetadata.ROTATION_EAST
	elseif angle >= math.pi/4 and angle < 3*math.pi/4 then
		return Constants.BlockMetadata.ROTATION_SOUTH  -- +Z = South in Minecraft
	elseif angle >= -3*math.pi/4 and angle < -math.pi/4 then
		return Constants.BlockMetadata.ROTATION_NORTH  -- -Z = North in Minecraft
	else
		return Constants.BlockMetadata.ROTATION_WEST
	end
end

--[[
	Get the forward direction vector for a given rotation
	@param rotation: Rotation value (0-3)
	@return: Forward direction as Vector3
	
	Minecraft coordinate system:
	- North = -Z, South = +Z, East = +X, West = -X
]]
function BlockRotation.GetDirectionFromRotation(rotation: number): Vector3
	if rotation == Constants.BlockMetadata.ROTATION_NORTH then
		return Vector3.new(0, 0, -1)  -- -Z (Minecraft North)
	elseif rotation == Constants.BlockMetadata.ROTATION_EAST then
		return Vector3.new(1, 0, 0)   -- +X (Minecraft East)
	elseif rotation == Constants.BlockMetadata.ROTATION_SOUTH then
		return Vector3.new(0, 0, 1)   -- +Z (Minecraft South)
	else -- WEST
		return Vector3.new(-1, 0, 0)  -- -X (Minecraft West)
	end
end

--[[
	Get rotation name for debugging
	@param rotation: Rotation value (0-3)
	@return: String name
]]
function BlockRotation.GetRotationName(rotation: number): string
	if rotation == Constants.BlockMetadata.ROTATION_NORTH then
		return "NORTH"
	elseif rotation == Constants.BlockMetadata.ROTATION_EAST then
		return "EAST"
	elseif rotation == Constants.BlockMetadata.ROTATION_SOUTH then
		return "SOUTH"
	else
		return "WEST"
	end
end

return BlockRotation

