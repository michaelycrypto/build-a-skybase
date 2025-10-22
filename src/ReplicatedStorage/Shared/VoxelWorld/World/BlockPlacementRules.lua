--[[
	BlockPlacementRules.lua
	Validates block placement according to Minecraft-like rules
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local BlockPlacementRules = {}

--[[
	Check if a block can be placed at given coordinates
	@param worldManager: WorldManager instance
	@param x, y, z: World coordinates
	@param blockId: Block type to place
	@param playerPos: Player position (Vector3) for distance check (usually head position)
	@param playerBodyPos: Optional player body position (Vector3) for collision check (usually rootPart position)
	@return: canPlace (boolean), reason (string or nil)
]]
function BlockPlacementRules:CanPlace(worldManager, x: number, y: number, z: number, blockId: number, playerPos: Vector3?, playerBodyPos: Vector3?): (boolean, string?)
	-- Check world bounds
	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return false, "out_of_bounds"
	end

	-- Check if block type is valid
	if blockId < 0 then
		return false, "invalid_block"
	end

	-- Can't place AIR (use block breaking instead)
	if blockId == Constants.BlockType.AIR then
		return false, "cannot_place_air"
	end

	-- Can't place bedrock (except in creative mode - future feature)
	if blockId == Constants.BlockType.BEDROCK then
		return false, "cannot_place_bedrock"
	end

	-- Check if target position is currently air
	local currentBlock = worldManager:GetBlock(x, y, z)
	if currentBlock ~= Constants.BlockType.AIR then
		return false, "space_occupied"
	end

	-- Distance check if player position provided
	if playerPos then
		local blockCenter = Vector3.new(
			x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
		)
		local distance = (blockCenter - playerPos).Magnitude
		local maxReach = 4.5 * Constants.BLOCK_SIZE + 2 -- Same as break distance

		if distance > maxReach then
			return false, "too_far"
		end
	end

	-- Check if block needs support (like flowers, tall grass)
	if self:NeedsGroundSupport(blockId) then
		local belowBlock = worldManager:GetBlock(x, y - 1, z)
		if not self:CanSupport(belowBlock) then
			return false, "no_support"
		end
	end

	-- Check if player would collide with placed block (can't place inside player's core)
	-- Use a smaller collision box to allow Minecraft-style placement around player
	-- Players can place blocks at their feet, above their head, and close to their body
	local bodyPos = playerBodyPos or playerPos  -- Use body position if provided, otherwise fall back to playerPos
	if bodyPos then
		local bs = Constants.BLOCK_SIZE
		local blockCenter = Vector3.new(
			x * bs + bs * 0.5,
			y * bs + bs * 0.5,
			z * bs + bs * 0.5
		)

		-- Only prevent placement if block center is very close to player center
		-- This allows placing blocks at feet, head level, and adjacent positions
		-- Use a smaller collision radius (0.4 blocks) to be more lenient
		local playerHalfWidth = 0.2 * bs  -- Reduced from 0.3 to 0.2
		local playerHalfHeight = 0.4 * bs  -- Reduced from 0.9 to 0.4 (only core body)

		local distanceXZ = math.sqrt(
			(blockCenter.X - bodyPos.X)^2 +
			(blockCenter.Z - bodyPos.Z)^2
		)
		local distanceY = math.abs(blockCenter.Y - bodyPos.Y)

		-- Only reject if block is VERY close to player's core (within core cylinder)
		if distanceXZ < playerHalfWidth and distanceY < playerHalfHeight then
			return false, "would_suffocate"
		end
	end

	return true
end

--[[
	Check if a block type needs ground support
]]
function BlockPlacementRules:NeedsGroundSupport(blockId: number): boolean
	return blockId == Constants.BlockType.TALL_GRASS
		or blockId == Constants.BlockType.FLOWER
		or blockId == Constants.BlockType.OAK_SAPLING
end

--[[
	Check if a block can support other blocks above it
]]
function BlockPlacementRules:CanSupport(blockId: number): boolean
	-- Air can't support anything
	if blockId == Constants.BlockType.AIR then
		return false
	end

	-- Grass and dirt can support flowers/plants
	return blockId == Constants.BlockType.GRASS
		or blockId == Constants.BlockType.DIRT
		or blockId == Constants.BlockType.STONE
		or blockId == Constants.BlockType.BEDROCK
end

--[[
	Check if two AABBs overlap
]]
function BlockPlacementRules:AABBOverlap(min1: Vector3, max1: Vector3, min2: Vector3, max2: Vector3): boolean
	return min1.X < max2.X and max1.X > min2.X
		and min1.Y < max2.Y and max1.Y > min2.Y
		and min1.Z < max2.Z and max1.Z > min2.Z
end

--[[
	Get adjacent block coordinates (for future use - updating neighbors)
]]
function BlockPlacementRules:GetAdjacentPositions(x: number, y: number, z: number)
	return {
		{x = x + 1, y = y, z = z},
		{x = x - 1, y = y, z = z},
		{x = x, y = y + 1, z = z},
		{x = x, y = y - 1, z = z},
		{x = x, y = y, z = z + 1},
		{x = x, y = y, z = z - 1},
	}
end

return BlockPlacementRules

