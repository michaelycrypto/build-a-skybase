--[[
	BlockValidator.lua
	Server-side validation for block placement and destruction
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.BlockRegistry)

local BlockValidator = {}

-- Validation result type
export type ValidationResult = {
	valid: boolean,
	reason: string?
}

-- Check if coordinates are within world bounds
function BlockValidator.IsInBounds(x: number, y: number, z: number): ValidationResult
	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return {
			valid = false,
			reason = "Position is outside world height limits"
		}
	end

	-- Check world boundaries from config
	local WorldConfig = require(script.Parent.Parent.Core.WorldConfig)
	if x < 0 or x >= WorldConfig.MAP_SIZE_X or
	   z < 0 or z >= WorldConfig.MAP_SIZE_Z then
		return {
			valid = false,
			reason = "Position is outside world boundaries"
		}
	end

	return { valid = true }
end

-- Check if block can be placed at location
function BlockValidator.CanPlaceBlock(
	worldManager: any,
	x: number,
	y: number,
	z: number,
	blockId: number,
	player: Player?
): ValidationResult
	-- Check world bounds
	local boundsCheck = BlockValidator.IsInBounds(x, y, z)
	if not boundsCheck.valid then
		return boundsCheck
	end

	-- Get current block
	local currentBlock = worldManager:GetBlock(x, y, z)

	-- Check if block is different (avoid unnecessary updates)
	if currentBlock == blockId then
		return {
			valid = false,
			reason = "Block is already that type"
		}
	end

	-- Get block properties
	local blockProps = BlockRegistry:GetBlock(blockId)
	if not blockProps then
		return {
			valid = false,
			reason = "Invalid block type"
		}
	end

	-- Check bedrock (y=0)
	if y == 0 and currentBlock == Constants.BlockType.BEDROCK then
		return {
			valid = false,
			reason = "Cannot modify bedrock"
		}
	end

	-- Check block-specific placement rules
	if blockProps.placementRules then
		-- Example: Tall grass needs grass block below
		if blockId == Constants.BlockType.TALL_GRASS then
			local blockBelow = worldManager:GetBlock(x, y - 1, z)
			if blockBelow ~= Constants.BlockType.GRASS then
				return {
					valid = false,
					reason = "Tall grass can only be placed on grass blocks"
				}
			end
		end

		-- Example: Flowers need dirt or grass below
		if blockId == Constants.BlockType.FLOWER then
			local blockBelow = worldManager:GetBlock(x, y - 1, z)
			if blockBelow ~= Constants.BlockType.GRASS and
			   blockBelow ~= Constants.BlockType.DIRT then
				return {
					valid = false,
					reason = "Flowers can only be placed on grass or dirt"
				}
			end
		end
	end

	-- Check if block needs support
	if blockProps.needsSupport then
		local blockBelow = worldManager:GetBlock(x, y - 1, z)
		if blockBelow == Constants.BlockType.AIR then
			return {
				valid = false,
				reason = "Block needs support below"
			}
		end
	end

	-- Check player permissions if provided
	if player then
		-- Example: Check build permissions in area
		local canBuild = BlockValidator.PlayerCanBuildAt(player, x, y, z)
		if not canBuild.valid then
			return canBuild
		end
	end

	return { valid = true }
end

-- Check if block can be destroyed
function BlockValidator.CanDestroyBlock(
	worldManager: any,
	x: number,
	y: number,
	z: number,
	player: Player?
): ValidationResult
	-- Check world bounds
	local boundsCheck = BlockValidator.IsInBounds(x, y, z)
	if not boundsCheck.valid then
		return boundsCheck
	end

	-- Get current block
	local currentBlock = worldManager:GetBlock(x, y, z)

	-- Check if air (nothing to destroy)
	if currentBlock == Constants.BlockType.AIR then
		return {
			valid = false,
			reason = "No block to destroy"
		}
	end

	-- Check bedrock
	if currentBlock == Constants.BlockType.BEDROCK then
		return {
			valid = false,
			reason = "Cannot destroy bedrock"
		}
	end

	-- Check if destroying this block would cause problems
	local wouldCauseProblems = BlockValidator.WouldCauseProblems(worldManager, x, y, z)
	if not wouldCauseProblems.valid then
		return wouldCauseProblems
	end

	-- Check player permissions if provided
	if player then
		local canDestroy = BlockValidator.PlayerCanDestroyAt(player, x, y, z)
		if not canDestroy.valid then
			return canDestroy
		end
	end

	return { valid = true }
end

-- Check if player can build at location
function BlockValidator.PlayerCanBuildAt(player: Player, x: number, y: number, z: number): ValidationResult
	-- Example: Check distance from player
	local character = player.Character
	if not character then
		return {
			valid = false,
			reason = "Player character not found"
		}
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then
		return {
			valid = false,
			reason = "Player HumanoidRootPart not found"
		}
	end

	-- Convert block coordinates to world coordinates
	local blockPos = Vector3.new(
		x * Constants.BLOCK_SIZE,
		y * Constants.BLOCK_SIZE,
		z * Constants.BLOCK_SIZE
	)

	local distance = (humanoidRootPart.Position - blockPos).Magnitude
	if distance > 32 then -- Maximum build distance
		return {
			valid = false,
			reason = "Too far away to build"
		}
	end

	-- Example: Check if in protected region
	-- This would integrate with your protection system
	local isProtected = false -- Replace with actual check
	if isProtected then
		return {
			valid = false,
			reason = "Cannot build in protected area"
		}
	end

	return { valid = true }
end

-- Check if player can destroy at location
function BlockValidator.PlayerCanDestroyAt(player: Player, x: number, y: number, z: number): ValidationResult
	-- Similar to PlayerCanBuildAt but for destruction
	-- You might want different rules for destroying vs building
	return BlockValidator.PlayerCanBuildAt(player, x, y, z)
end

-- Check if block modification would cause problems
function BlockValidator.WouldCauseProblems(worldManager: any, x: number, y: number, z: number): ValidationResult
	-- Get current block
	local currentBlock = worldManager:GetBlock(x, y, z)

	-- Check if blocks above need support
	local blockAbove = worldManager:GetBlock(x, y + 1, z)
	local aboveProps = BlockRegistry:GetBlock(blockAbove)

	if aboveProps and aboveProps.needsSupport then
		return {
			valid = false,
			reason = "Would cause floating block above"
		}
	end

	-- Example: Check for floating trees
	if currentBlock == Constants.BlockType.WOOD then
		-- Simple check - are we removing the bottom of a tree?
		local hasWoodAbove = false
		local checkHeight = 1
		while checkHeight < 8 do -- Check up to 8 blocks up
			if worldManager:GetBlock(x, y + checkHeight, z) == Constants.BlockType.WOOD then
				hasWoodAbove = true
				break
			end
			checkHeight = checkHeight + 1
		end

		if hasWoodAbove then
			return {
				valid = false,
				reason = "Would create floating tree"
			}
		end
	end

	return { valid = true }
end

return BlockValidator
