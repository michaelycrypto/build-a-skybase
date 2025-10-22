--[[
	BlockProperties.lua
	Defines properties for each block type (hardness, tools, break times)
	Minecraft-accurate block breaking mechanics
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local BlockProperties = {}

-- Tool tiers (affects mining speed multiplier)
BlockProperties.ToolTier = {
	NONE = 0,     -- Hand/no tool
	WOOD = 1,
	STONE = 2,
	IRON = 3,
	DIAMOND = 4
}

-- Tool types
BlockProperties.ToolType = {
	NONE = "none",
	PICKAXE = "pickaxe",
	AXE = "axe",
	SHOVEL = "shovel",
	HOE = "hoe",
	SWORD = "sword"
}

-- Block property definitions
-- Format: {
--   hardness: Base time in seconds to break by hand (Minecraft ticks * 0.05)
--   toolType: Required tool type (nil = any tool works)
--   minToolTier: Minimum tool tier needed (nil = hand works)
--   resistance: Explosion resistance (for future use)
-- }
BlockProperties.Properties = {
	[Constants.BlockType.AIR] = {
		hardness = 0,
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.GRASS] = {
		hardness = 0.6,  -- Minecraft: 0.6 seconds
		toolType = BlockProperties.ToolType.SHOVEL,
		minToolTier = nil,  -- Any tool works, shovel is faster
		resistance = 0.6
	},
	[Constants.BlockType.DIRT] = {
		hardness = 0.5,  -- Minecraft: 0.5 seconds
		toolType = BlockProperties.ToolType.SHOVEL,
		minToolTier = nil,
		resistance = 0.5
	},
	[Constants.BlockType.STONE] = {
		hardness = 1.5,  -- Minecraft: 1.5 seconds
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,  -- Requires at least wood pickaxe
		resistance = 6.0
	},
	[Constants.BlockType.BEDROCK] = {
		hardness = -1,  -- Unbreakable
		toolType = nil,
		minToolTier = nil,
		resistance = 3600000
	},
	[Constants.BlockType.WOOD] = {
		hardness = 2.0,  -- Minecraft: 2.0 seconds
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,
		resistance = 2.0
	},
	[Constants.BlockType.LEAVES] = {
		hardness = 0.2,  -- Minecraft: 0.2 seconds
		toolType = nil,  -- Any tool or hand
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.TALL_GRASS] = {
		hardness = 0,  -- Instant break
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.FLOWER] = {
		hardness = 0,  -- Instant break
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.OAK_SAPLING] = {
		hardness = 0,  -- Instant break
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.SAND] = {
		hardness = 0.5,  -- Minecraft: 0.5 seconds
		toolType = BlockProperties.ToolType.SHOVEL,
		minToolTier = nil,
		resistance = 0.5
	},
	-- Staircase blocks
	[Constants.BlockType.OAK_STAIRS] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = 1,
		resistance = 3.0
	},
	[Constants.BlockType.STONE_STAIRS] = {
		hardness = 1.5,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.COBBLESTONE_STAIRS] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.STONE_BRICK_STAIRS] = {
		hardness = 1.5,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.BRICK_STAIRS] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	-- Slab blocks
	[Constants.BlockType.OAK_SLAB] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = 1,
		resistance = 3.0
	},
	[Constants.BlockType.STONE_SLAB] = {
		hardness = 1.5,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.COBBLESTONE_SLAB] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.STONE_BRICK_SLAB] = {
		hardness = 1.5,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.BRICK_SLAB] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = 1,
		resistance = 6.0
	},
	[Constants.BlockType.STONE_BRICKS] = {
		hardness = 1.5,  -- Minecraft: 1.5 seconds
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,
		resistance = 6.0
	},
	[Constants.BlockType.OAK_PLANKS] = {
		hardness = 2.0,  -- Minecraft: 2.0 seconds
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,
		resistance = 3.0
	},
	[Constants.BlockType.CRAFTING_TABLE] = {
		hardness = 2.5,  -- Minecraft: 2.5 seconds
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,
		resistance = 2.5
	},
	[Constants.BlockType.COBBLESTONE] = {
		hardness = 2.0,  -- Minecraft: 2.0 seconds
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,
		resistance = 6.0
	},
	[Constants.BlockType.BRICKS] = {
		hardness = 2.0,  -- Minecraft: 2.0 seconds
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,
		resistance = 6.0
	}
}

-- Tool effectiveness multipliers (Minecraft-accurate)
BlockProperties.ToolEffectiveness = {
	-- Pickaxe effectiveness
	pickaxe = {
		[Constants.BlockType.STONE] = 1.5,
		[Constants.BlockType.BEDROCK] = 1.5,
		[Constants.BlockType.STONE_BRICKS] = 1.5,
		[Constants.BlockType.COBBLESTONE] = 1.5,
		[Constants.BlockType.BRICKS] = 1.5,
		-- Add ores here when implemented
	},
	-- Axe effectiveness
	axe = {
		[Constants.BlockType.WOOD] = 1.5,
		[Constants.BlockType.LEAVES] = 1.5,
		[Constants.BlockType.OAK_PLANKS] = 1.5,
		[Constants.BlockType.CRAFTING_TABLE] = 1.5,
	},
	-- Shovel effectiveness
	shovel = {
		[Constants.BlockType.DIRT] = 1.5,
		[Constants.BlockType.GRASS] = 1.5,
		[Constants.BlockType.SAND] = 1.5,
	}
}

-- Tool speed multipliers by tier (Minecraft values)
BlockProperties.ToolSpeedMultipliers = {
	[BlockProperties.ToolTier.WOOD] = 2.0,
	[BlockProperties.ToolTier.STONE] = 4.0,
	[BlockProperties.ToolTier.IRON] = 6.0,
	[BlockProperties.ToolTier.DIAMOND] = 8.0
}

--[[
	Get block properties
	@param blockId: Block type ID
	@return: Properties table or default
]]
function BlockProperties:GetProperties(blockId: number)
	return self.Properties[blockId] or {
		hardness = 1.0,
		toolType = nil,
		minToolTier = nil,
		resistance = 1.0
	}
end

--[[
	Check if block is breakable
	@param blockId: Block type ID
	@return: boolean
]]
function BlockProperties:IsBreakable(blockId: number): boolean
	local props = self:GetProperties(blockId)
	return props.hardness >= 0
end

--[[
	Calculate break time for a block with given tool
	@param blockId: Block type ID
	@param toolType: Tool type (from ToolType enum)
	@param toolTier: Tool tier (from ToolTier enum)
	@return: Break time in seconds, canBreak (boolean)
]]
function BlockProperties:GetBreakTime(blockId: number, toolType: string?, toolTier: number?): (number, boolean)
	local props = self:GetProperties(blockId)

	-- Unbreakable blocks
	if props.hardness < 0 then
		return math.huge, false
	end

	-- Instant break
	if props.hardness == 0 then
		return 0, true
	end

	-- Check if tool meets minimum requirement
	local currentTier = toolTier or BlockProperties.ToolTier.NONE
	local requiredTier = props.minToolTier or BlockProperties.ToolTier.NONE

	-- Wrong tool type or insufficient tier
	if props.minToolTier and currentTier < requiredTier then
		-- Can't break this block (or takes extremely long)
		return math.huge, false
	end

	-- Base break time
	local breakTime = props.hardness

	-- Apply tool speed multiplier
	if toolType and toolTier then
		local speedMultiplier = self.ToolSpeedMultipliers[toolTier] or 1.0

		-- Check if tool is effective for this block
		local effectiveness = 1.0
		if self.ToolEffectiveness[toolType] then
			effectiveness = self.ToolEffectiveness[toolType][blockId] or 1.0
		end

		-- Apply both multipliers
		breakTime = breakTime / (speedMultiplier * effectiveness)
	end

	-- Minecraft applies efficiency enchantment here (for future)
	-- breakTime = breakTime / (1 + efficiencyLevel)

	return breakTime, true
end

--[[
	Get mining speed multiplier (for UI/effects)
	@param blockId: Block type ID
	@param toolType: Tool type
	@param toolTier: Tool tier
	@return: Speed multiplier (1.0 = normal, 2.0 = 2x faster)
]]
function BlockProperties:GetMiningSpeed(blockId: number, toolType: string?, toolTier: number?): number
	local baseTime = self:GetProperties(blockId).hardness
	if baseTime <= 0 then return math.huge end

	local actualTime = self:GetBreakTime(blockId, toolType, toolTier)
	if actualTime == math.huge then return 0 end

	return baseTime / actualTime
end

--[[
	Check if player can harvest this block (gets drops)
	@param blockId: Block type ID
	@param toolType: Tool type
	@param toolTier: Tool tier
	@return: boolean
]]
function BlockProperties:CanHarvest(blockId: number, toolType: string?, toolTier: number?): boolean
	local props = self:GetProperties(blockId)

	-- No tool requirement = always harvestable
	if not props.minToolTier then
		return true
	end

	-- Check tool tier meets requirement
	local currentTier = toolTier or BlockProperties.ToolTier.NONE
	return currentTier >= props.minToolTier
end

return BlockProperties

