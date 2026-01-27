--[[
	BlockProperties.lua
	Defines Minecraft-style block hardness and tool behavior.
	Hardness values match Minecraft's hardness parameter (NOT seconds).
	Break time is computed from hardness and tool speed using the Minecraft formula.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Core.Constants)
local BlockBreakFeedbackConfig = require(ReplicatedStorage.Configs.BlockBreakFeedbackConfig)

local BlockProperties = {}

-- Tool tiers (affects mining speed multiplier)
-- 4-tier progression: Copper → Iron → Steel → Bluesteel
BlockProperties.ToolTier = {
	NONE = 0,       -- Hand/no tool
	COPPER = 1,     -- Tier 1 - Starter
	IRON = 2,       -- Tier 2 - Standard
	STEEL = 3,      -- Tier 3 - Iron + Coal alloy
	BLUESTEEL = 4,  -- Tier 4 - Strong blue steel (max tier)
	-- Legacy aliases for compatibility
	WOOD = 1,       -- Alias for COPPER
	STONE = 2,      -- Alias for IRON
	DIAMOND = 4     -- Alias for BLUESTEEL (was TITANIUM)
}

-- Tool types
BlockProperties.ToolType = {
	NONE = "none",
	PICKAXE = "pickaxe",
	AXE = "axe",
	SHOVEL = "shovel",
	HOE = "hoe",
	SWORD = "sword",
	BOW = "bow",
	ARROW = "arrow",
}

-- Block property definitions
-- Format: {
--   hardness: Minecraft hardness value (e.g., stone = 1.5, dirt = 0.5)
--   toolType: Tool TYPE that mines it fastest (recommended tool). Only REQUIRED when minToolTier is set
--   minToolTier: Minimum tool tier REQUIRED to harvest (nil = no requirement for drops)
--   resistance: Explosion resistance (for future use)
-- }
BlockProperties.Properties = {
	[Constants.BlockType.AIR] = {
		hardness = 0,
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.WATER_SOURCE] = {
		hardness = 0,
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
	[Constants.BlockType.FLOWING_WATER] = {
		hardness = 0,
		toolType = nil,
		minToolTier = nil,
		resistance = 0
	},
    [Constants.BlockType.GRASS] = {
        hardness = 0.6,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.SHOVEL, -- Recommended tool, not required
        minToolTier = nil,
        resistance = 0.6
    },
    [Constants.BlockType.DIRT] = {
        hardness = 0.5,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.SHOVEL, -- Recommended tool, not required
        minToolTier = nil,
        resistance = 0.5
    },
    [Constants.BlockType.STONE] = {
        hardness = 1.5,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.PICKAXE,
        minToolTier = BlockProperties.ToolTier.WOOD,  -- Requires at least wooden pickaxe to harvest
        resistance = 6.0
    },
	[Constants.BlockType.BEDROCK] = {
		hardness = -1,  -- Unbreakable
		toolType = nil,
		minToolTier = nil,
		resistance = 3600000
	},
    [Constants.BlockType.WOOD] = {
        hardness = 2.0,  -- Minecraft hardness (logs)
        toolType = BlockProperties.ToolType.AXE, -- Recommended
        minToolTier = nil, -- Harvestable by hand
        resistance = 2.0
    },
    [Constants.BlockType.LEAVES] = {
        hardness = 0.2,  -- Minecraft hardness
        toolType = nil,  -- Any tool or hand (shears not modeled here)
        minToolTier = nil,
        resistance = 0.2
    },
	[Constants.BlockType.OAK_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.SPRUCE_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.JUNGLE_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.DARK_OAK_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.BIRCH_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
		minToolTier = nil,
		resistance = 0.2
	},
	[Constants.BlockType.ACACIA_LEAVES] = {
		hardness = 0.2,
		toolType = nil,
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
	[Constants.BlockType.CHEST] = {
		hardness = 2.5,  -- Minecraft hardness (same as crafting table)
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,  -- Harvestable by hand
		resistance = 2.5
	},
    [Constants.BlockType.SAND] = {
        hardness = 0.5,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.SHOVEL,
        minToolTier = nil,
        resistance = 0.5
    },
	-- Staircase blocks
	[Constants.BlockType.OAK_STAIRS] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,
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
		minToolTier = nil,
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
	-- Fences
	[Constants.BlockType.OAK_FENCE] = {
		hardness = 2.0,
		toolType = BlockProperties.ToolType.AXE,
		minToolTier = nil,
		resistance = 2.0
	},
    [Constants.BlockType.STONE_BRICKS] = {
        hardness = 1.5,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.PICKAXE,
        minToolTier = BlockProperties.ToolTier.WOOD,
        resistance = 6.0
    },
    [Constants.BlockType.OAK_PLANKS] = {
        hardness = 2.0,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.AXE, -- Recommended
        minToolTier = nil, -- Harvestable by hand
        resistance = 3.0
    },
    -- Additional wood families
    [Constants.BlockType.SPRUCE_LOG] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 2.0
    },
    [Constants.BlockType.JUNGLE_LOG] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 2.0
    },
    [Constants.BlockType.DARK_OAK_LOG] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 2.0
    },
    [Constants.BlockType.BIRCH_LOG] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 2.0
    },
    [Constants.BlockType.ACACIA_LOG] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 2.0
    },

    [Constants.BlockType.SPRUCE_PLANKS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.JUNGLE_PLANKS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.DARK_OAK_PLANKS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.BIRCH_PLANKS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.ACACIA_PLANKS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },

    -- Stairs (wood families)
    [Constants.BlockType.SPRUCE_STAIRS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.JUNGLE_STAIRS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.DARK_OAK_STAIRS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.BIRCH_STAIRS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.ACACIA_STAIRS] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },

    -- Slabs (wood families)
    [Constants.BlockType.SPRUCE_SLAB] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.JUNGLE_SLAB] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.DARK_OAK_SLAB] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.BIRCH_SLAB] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },
    [Constants.BlockType.ACACIA_SLAB] = {
        hardness = 2.0,
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil,
        resistance = 3.0
    },

    -- Saplings (instant break)
    [Constants.BlockType.SPRUCE_SAPLING] = {
        hardness = 0,
        toolType = nil,
        minToolTier = nil,
        resistance = 0
    },
    [Constants.BlockType.JUNGLE_SAPLING] = {
        hardness = 0,
        toolType = nil,
        minToolTier = nil,
        resistance = 0
    },
    [Constants.BlockType.DARK_OAK_SAPLING] = {
        hardness = 0,
        toolType = nil,
        minToolTier = nil,
        resistance = 0
    },
    [Constants.BlockType.BIRCH_SAPLING] = {
        hardness = 0,
        toolType = nil,
        minToolTier = nil,
        resistance = 0
    },
    [Constants.BlockType.ACACIA_SAPLING] = {
        hardness = 0,
        toolType = nil,
        minToolTier = nil,
        resistance = 0
    },
    [Constants.BlockType.CRAFTING_TABLE] = {
        hardness = 2.5,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.AXE,
        minToolTier = nil, -- Harvestable by hand
        resistance = 2.5
    },
    [Constants.BlockType.COBBLESTONE] = {
        hardness = 2.0,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.PICKAXE,
        minToolTier = BlockProperties.ToolTier.WOOD,
        resistance = 6.0
    },
    [Constants.BlockType.BRICKS] = {
        hardness = 2.0,  -- Minecraft hardness
        toolType = BlockProperties.ToolType.PICKAXE,
        minToolTier = BlockProperties.ToolTier.WOOD,
        resistance = 6.0
    },
	-- Ores
	[Constants.BlockType.COAL_ORE] = {
		hardness = 3.0,  -- Minecraft hardness
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,  -- Requires wooden pickaxe
		resistance = 3.0
	},
	[Constants.BlockType.IRON_ORE] = {
		hardness = 3.0,  -- Minecraft hardness
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.STONE,  -- Requires stone pickaxe
		resistance = 3.0
	},
	-- Utility blocks
	[Constants.BlockType.FURNACE] = {
		hardness = 3.5,  -- Minecraft hardness
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.WOOD,  -- Requires wooden pickaxe
		resistance = 3.5
	},
	[Constants.BlockType.GLASS] = {
		hardness = 0.3,  -- Minecraft hardness - breaks quickly
		toolType = nil,  -- No specific tool required
		minToolTier = nil,  -- Harvestable by hand
		resistance = 0.3
	}
	,

	-- Farming
	[Constants.BlockType.FARMLAND] = {
		hardness = 0.6,
		toolType = BlockProperties.ToolType.SHOVEL,
		minToolTier = nil,
		resistance = 0.6
	},

	-- Inventory items (instant break if ever placed)
	[Constants.BlockType.WHEAT_SEEDS] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.POTATO] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.CARROT] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.BEETROOT_SEEDS] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.BEETROOT] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },

	-- Crop stages (instant break)
	[Constants.BlockType.WHEAT_CROP_0] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_1] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_2] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_3] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_4] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_5] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_6] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.WHEAT_CROP_7] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },

	[Constants.BlockType.POTATO_CROP_0] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.POTATO_CROP_1] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.POTATO_CROP_2] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.POTATO_CROP_3] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },

	[Constants.BlockType.CARROT_CROP_0] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.CARROT_CROP_1] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.CARROT_CROP_2] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.CARROT_CROP_3] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },

	[Constants.BlockType.BEETROOT_CROP_0] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.BEETROOT_CROP_1] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.BEETROOT_CROP_2] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },
	[Constants.BlockType.BEETROOT_CROP_3] = { hardness = 0, toolType = nil, minToolTier = nil, resistance = 0 },

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ORES (4-tier progression: Copper → Iron → Steel → Bluesteel)
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.COPPER_ORE] = {
		hardness = 2.5,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.COPPER,
		resistance = 3.0
	},
	[Constants.BlockType.BLUESTEEL_ORE] = {
		hardness = 4.0,
		toolType = BlockProperties.ToolType.PICKAXE,
		minToolTier = BlockProperties.ToolTier.STEEL,
		resistance = 4.0
	},
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
		[Constants.BlockType.COAL_ORE] = 1.5,
		[Constants.BlockType.IRON_ORE] = 1.5,
		[Constants.BlockType.FURNACE] = 1.5,
		-- Tiered ores (4-tier)
		[Constants.BlockType.COPPER_ORE] = 1.5,
		[Constants.BlockType.BLUESTEEL_ORE] = 1.5,
	},
	-- Axe effectiveness
	axe = {
		[Constants.BlockType.WOOD] = 1.5,
		[Constants.BlockType.SPRUCE_LOG] = 1.5,
		[Constants.BlockType.JUNGLE_LOG] = 1.5,
		[Constants.BlockType.DARK_OAK_LOG] = 1.5,
		[Constants.BlockType.BIRCH_LOG] = 1.5,
		[Constants.BlockType.ACACIA_LOG] = 1.5,

		[Constants.BlockType.LEAVES] = 1.5,
		[Constants.BlockType.OAK_LEAVES] = 1.5,
		[Constants.BlockType.SPRUCE_LEAVES] = 1.5,
		[Constants.BlockType.JUNGLE_LEAVES] = 1.5,
		[Constants.BlockType.DARK_OAK_LEAVES] = 1.5,
		[Constants.BlockType.BIRCH_LEAVES] = 1.5,
		[Constants.BlockType.ACACIA_LEAVES] = 1.5,

		[Constants.BlockType.OAK_PLANKS] = 1.5,
		[Constants.BlockType.SPRUCE_PLANKS] = 1.5,
		[Constants.BlockType.JUNGLE_PLANKS] = 1.5,
		[Constants.BlockType.DARK_OAK_PLANKS] = 1.5,
		[Constants.BlockType.BIRCH_PLANKS] = 1.5,
		[Constants.BlockType.ACACIA_PLANKS] = 1.5,

		[Constants.BlockType.OAK_STAIRS] = 1.5,
		[Constants.BlockType.SPRUCE_STAIRS] = 1.5,
		[Constants.BlockType.JUNGLE_STAIRS] = 1.5,
		[Constants.BlockType.DARK_OAK_STAIRS] = 1.5,
		[Constants.BlockType.BIRCH_STAIRS] = 1.5,
		[Constants.BlockType.ACACIA_STAIRS] = 1.5,

		[Constants.BlockType.OAK_SLAB] = 1.5,
		[Constants.BlockType.SPRUCE_SLAB] = 1.5,
		[Constants.BlockType.JUNGLE_SLAB] = 1.5,
		[Constants.BlockType.DARK_OAK_SLAB] = 1.5,
		[Constants.BlockType.BIRCH_SLAB] = 1.5,
		[Constants.BlockType.ACACIA_SLAB] = 1.5,

		[Constants.BlockType.CRAFTING_TABLE] = 1.5,
		[Constants.BlockType.OAK_FENCE] = 1.5,
	},
	-- Shovel effectiveness
	shovel = {
		[Constants.BlockType.DIRT] = 1.5,
		[Constants.BlockType.GRASS] = 1.5,
		[Constants.BlockType.SAND] = 1.5,
	}
}

-- Tool speed multipliers by tier (4-tier progression)
BlockProperties.ToolSpeedMultipliers = {
    [BlockProperties.ToolTier.COPPER] = 2.0,     -- Tier 1: Copper
    [BlockProperties.ToolTier.IRON] = 4.0,       -- Tier 2: Iron
    [BlockProperties.ToolTier.STEEL] = 6.0,      -- Tier 3: Steel
    [BlockProperties.ToolTier.BLUESTEEL] = 9.0,  -- Tier 4: Bluesteel (max tier)
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

    -- Instant break blocks
    if props.hardness == 0 then
        return 0, true
    end

    -- Determine if correct tool type is used for this block and tier meets requirement
    local currentTier = toolTier or BlockProperties.ToolTier.NONE
    local requiredTier = props.minToolTier or BlockProperties.ToolTier.NONE
    local requiredType = props.toolType

    local usingCorrectTool = false
    if requiredType and requiredType ~= BlockProperties.ToolType.NONE then
        if toolType == requiredType then
            usingCorrectTool = true
        end
    else
        -- No strict requiredType: treat matching effectiveness map as "correct tool"
        if toolType and toolType ~= BlockProperties.ToolType.NONE then
            local effMap = self.ToolEffectiveness[toolType]
            if effMap and effMap[blockId] and effMap[blockId] > 1.0 then
                usingCorrectTool = true
            end
        end
    end

    -- Compute tool speed per Minecraft tier multipliers
    local speedMultiplier = 1.0
    if usingCorrectTool and toolTier and toolTier ~= BlockProperties.ToolTier.NONE then
        speedMultiplier = self.ToolSpeedMultipliers[toolTier] or 1.0
    end

    -- Additional effectiveness vs specific blocks (axes vs wood, shovels vs dirt)
    local effectiveness = 1.0

    -- Minecraft breaking formula approximation in seconds:
    -- base time by hand ~ 1.5 * hardness; correct tool speeds up proportionally by (speedMultiplier * effectiveness).
    -- Wrong tool is much slower; approximate as 5 * hardness by hand.
    local baseByHand = 1.5 * props.hardness
    local time
    if usingCorrectTool then
        time = baseByHand / math.max(1.0, (speedMultiplier * effectiveness))
    else
        time = 5.0 * props.hardness -- wrong tool baseline
    end

    -- Enchantments/effects could modify here later

    -- Harvest gating: time is still finite; drops handled by CanHarvest
    return time, true
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
	-- toolType without minToolTier = recommended tool for speed, not required for drops
	if not props.minToolTier then
		return true
	end

	-- If minToolTier is set, we need to check tool requirements
	-- Require correct tool type if specified
	if props.toolType and props.toolType ~= BlockProperties.ToolType.NONE then
		if toolType ~= props.toolType then
			return false
		end
	end

	-- Check tool tier meets requirement
	local currentTier = toolTier or BlockProperties.ToolTier.NONE
	local requiredTier = props.minToolTier or BlockProperties.ToolTier.NONE
	return currentTier >= requiredTier
end

--[[
	Get the hit sound material for a block (used by client feedback)
]]
function BlockProperties:GetHitMaterial(blockId: number): string
	return BlockBreakFeedbackConfig.BlockMaterialMap[blockId] or BlockBreakFeedbackConfig.DEFAULT_MATERIAL
end

return BlockProperties

