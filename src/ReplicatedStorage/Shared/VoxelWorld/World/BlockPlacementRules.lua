--[[
	BlockPlacementRules.lua
	Validates block placement according to Minecraft-like rules
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.BlockRegistry)

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

	-- Block must be eligible for placement
	-- Exception: allow farm items (seeds, carrots, potatoes, beetroot seeds, compost) for redirect planting/soil tilling
	local isFarmItem = (
		blockId == 550 or  -- Wheat Seeds
		blockId == 504 or  -- Potato
		blockId == 503 or  -- Carrot
		blockId == 551     -- Beetroot Seeds
	)
	if not (BlockRegistry.IsPlaceable and BlockRegistry:IsPlaceable(blockId)) and not isFarmItem then
		return false, "not_placeable"
	end

	-- Check if target position is replaceable (air or water)
	local currentBlock = worldManager:GetBlock(x, y, z)
	if not BlockRegistry:IsReplaceable(currentBlock) then
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

	-- Check if player would collide with placed block (can't place inside player's body)
	-- Allow placement if player is standing ON TOP of the block (for bridge walking)
	local bodyPos = playerBodyPos or playerPos  -- Use body position if provided, otherwise fall back to playerPos
	if bodyPos then
		local bs = Constants.BLOCK_SIZE

		-- Block AABB (the block being placed)
		local blockMinY = y * bs
		local blockMaxY = (y + 1) * bs

		-- Player feet position
		local playerFeetOffset = 2.5  -- distance from rootPart to feet
		local playerFeetY = bodyPos.Y - playerFeetOffset

		-- If player's feet are at or above the block top, they're standing on it - allow placement
		-- Add small tolerance (0.1 studs) to account for slight position variations
		if playerFeetY >= blockMaxY - 0.1 then
			-- Player is on top of or above the block, placement is fine
			return true
		end

		-- Player is not above the block, check for horizontal collision
		local blockMinX = x * bs
		local blockMaxX = (x + 1) * bs
		local blockMinZ = z * bs
		local blockMaxZ = (z + 1) * bs

		-- Player body AABB (approximation for R15 character)
		local playerHalfWidth = 0.4  -- studs from center
		local playerHeadOffset = 2.0  -- distance from rootPart to top of head

		local playerMinX = bodyPos.X - playerHalfWidth
		local playerMaxX = bodyPos.X + playerHalfWidth
		local playerMinY = playerFeetY
		local playerMaxY = bodyPos.Y + playerHeadOffset
		local playerMinZ = bodyPos.Z - playerHalfWidth
		local playerMaxZ = bodyPos.Z + playerHalfWidth

		-- Check AABB overlap
		local overlapX = blockMinX < playerMaxX and blockMaxX > playerMinX
		local overlapY = blockMinY < playerMaxY and blockMaxY > playerMinY
		local overlapZ = blockMinZ < playerMaxZ and blockMaxZ > playerMinZ

		if overlapX and overlapY and overlapZ then
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
		or blockId == Constants.BlockType.WHEAT_CROP_0
		or blockId == Constants.BlockType.WHEAT_CROP_1
		or blockId == Constants.BlockType.WHEAT_CROP_2
		or blockId == Constants.BlockType.WHEAT_CROP_3
		or blockId == Constants.BlockType.WHEAT_CROP_4
		or blockId == Constants.BlockType.WHEAT_CROP_5
		or blockId == Constants.BlockType.WHEAT_CROP_6
		or blockId == Constants.BlockType.WHEAT_CROP_7
		or blockId == Constants.BlockType.POTATO_CROP_0
		or blockId == Constants.BlockType.POTATO_CROP_1
		or blockId == Constants.BlockType.POTATO_CROP_2
		or blockId == Constants.BlockType.POTATO_CROP_3
		or blockId == Constants.BlockType.CARROT_CROP_0
		or blockId == Constants.BlockType.CARROT_CROP_1
		or blockId == Constants.BlockType.CARROT_CROP_2
		or blockId == Constants.BlockType.CARROT_CROP_3
		or blockId == Constants.BlockType.BEETROOT_CROP_0
		or blockId == Constants.BlockType.BEETROOT_CROP_1
		or blockId == Constants.BlockType.BEETROOT_CROP_2
		or blockId == Constants.BlockType.BEETROOT_CROP_3
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
		or blockId == Constants.BlockType.FARMLAND
		or blockId == Constants.BlockType.FARMLAND_WET
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

