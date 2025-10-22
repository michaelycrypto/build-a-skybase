--[[
	BlockRegistry.lua
	Defines block types and their properties
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local BlockRegistry = {}

-- Default block properties
local DEFAULT_BLOCK = {
	name = "Unknown",
	solid = true,
	transparent = false,
	color = Color3.new(1, 1, 1),
	textures = {
		all = "unknown"
	},
	crossShape = false
}

-- Block type definitions
BlockRegistry.Blocks = {
	[Constants.BlockType.AIR] = {
		name = "Air",
		solid = false,
		transparent = true,
		color = Color3.new(1, 1, 1),
		textures = nil,
		crossShape = false
	},

	[Constants.BlockType.GRASS] = {
		name = "Grass Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(126, 200, 80),
		textures = {
			top = "grass_top",
			side = "grass_side",
			bottom = "dirt"
		},
		crossShape = false
	},

	[Constants.BlockType.DIRT] = {
		name = "Dirt",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(155, 118, 83),
		textures = {
			all = "dirt"
		},
		crossShape = false
	},

	[Constants.BlockType.STONE] = {
		name = "Stone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			all = "stone"
		},
		crossShape = false
	},

	[Constants.BlockType.BEDROCK] = {
		name = "Bedrock",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 84, 84),
		textures = {
			all = "bedrock"
		},
		crossShape = false
	},

	[Constants.BlockType.WOOD] = {
		name = "Oak Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 84, 38),
		textures = {
			top = "oak_log_top",
			side = "oak_log_side",
			bottom = "oak_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.LEAVES] = {
		name = "Oak Leaves",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(108, 161, 63),
		textures = {
			all = "leaves"
		},
		crossShape = false
	},

	[Constants.BlockType.TALL_GRASS] = {
		name = "Tall Grass",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(146, 190, 100),
		textures = {
			all = "tall_grass"
		},
		crossShape = true
	},

	[Constants.BlockType.FLOWER] = {
		name = "Flower",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 255, 100),
		textures = {
			all = "flower"
		},
		crossShape = true
	},

	[Constants.BlockType.CHEST] = {
		name = "Chest",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(139, 90, 43),
		textures = {
			top = "chest_top",
			side = "chest_side",
			front = "chest_front",
			back = "chest_side",
			bottom = "chest_top",
			all = "chest_side" -- Fallback
		},
		crossShape = false,
		hasRotation = true, -- NEW: Block can be rotated
		interactable = true, -- Special property for chests
		storage = true -- Has inventory storage
	},

	[Constants.BlockType.SAND] = {
		name = "Sand",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(235, 213, 179),
		textures = {
			all = "sand"
		},
		crossShape = false
	},

	[Constants.BlockType.STONE_BRICKS] = {
		name = "Stone Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(120, 120, 120),
		textures = {
			all = "stone_bricks"
		},
		crossShape = false
	},

	[Constants.BlockType.OAK_PLANKS] = {
		name = "Oak Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 130, 78),
		textures = {
			all = "oak_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.CRAFTING_TABLE] = {
		name = "Crafting Table",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(139, 90, 43),
		textures = {
			top = "crafting_table_top",
			side = "crafting_table_side",
			bottom = "crafting_table_top",
			front = "crafting_table_front",
			back = "crafting_table_side"
		},
		crossShape = false,
		hasRotation = true -- NEW: Block can be rotated
	},

	[Constants.BlockType.COBBLESTONE] = {
		name = "Cobblestone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			all = "cobblestone"
		},
		crossShape = false
	},

	[Constants.BlockType.BRICKS] = {
		name = "Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(150, 97, 83),
		textures = {
			all = "bricks"
		},
		crossShape = false
	},

	[Constants.BlockType.OAK_SAPLING] = {
		name = "Oak Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(80, 150, 50),
		textures = {
			all = "oak_sapling"
		},
		crossShape = true
	},

	-- Staircase blocks
	[Constants.BlockType.OAK_STAIRS] = {
		name = "Oak Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 114, 46),
		textures = {
			all = "oak_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.STONE_STAIRS] = {
		name = "Stone Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(128, 128, 128),
		textures = {
			all = "stone"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.COBBLESTONE_STAIRS] = {
		name = "Cobblestone Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			all = "cobblestone"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.STONE_BRICK_STAIRS] = {
		name = "Stone Brick Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(120, 120, 120),
		textures = {
			all = "stone_bricks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.BRICK_STAIRS] = {
		name = "Brick Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(150, 97, 83),
		textures = {
			all = "bricks"
		},
		stairShape = true,
		hasRotation = true
	},

	-- Slab blocks (half-height blocks)
	[Constants.BlockType.OAK_SLAB] = {
		name = "Oak Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 114, 46),
		textures = {
			all = "oak_planks"
		},
		slabShape = true
	},

	[Constants.BlockType.STONE_SLAB] = {
		name = "Stone Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(128, 128, 128),
		textures = {
			all = "stone"
		},
		slabShape = true
	},

	[Constants.BlockType.COBBLESTONE_SLAB] = {
		name = "Cobblestone Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			all = "cobblestone"
		},
		slabShape = true
	},

	[Constants.BlockType.STONE_BRICK_SLAB] = {
		name = "Stone Brick Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(120, 120, 120),
		textures = {
			all = "stone_bricks"
		},
		slabShape = true
	},

	[Constants.BlockType.BRICK_SLAB] = {
		name = "Brick Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(150, 97, 83),
		textures = {
			all = "bricks"
		},
		slabShape = true
	}
}

-- Get block definition by ID
function BlockRegistry:GetBlock(blockId: number)
	if not blockId then
		return DEFAULT_BLOCK
	end
	return self.Blocks[blockId] or DEFAULT_BLOCK
end

-- Check if block is solid
function BlockRegistry:IsSolid(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.solid
end

-- Check if block is transparent
function BlockRegistry:IsTransparent(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.transparent
end

-- Get block color
function BlockRegistry:GetColor(blockId: number): Color3
	local block = self:GetBlock(blockId)
	return block.color
end

-- Check if block uses cross shape
function BlockRegistry:IsCrossShape(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.crossShape
end

-- Get block texture for face
function BlockRegistry:GetTexture(blockId: number, face: string): string
	local block = self:GetBlock(blockId)
	if not block.textures then
		return nil
	end
	return block.textures[face] or block.textures.all
end

-- Check if block is interactable (like chests)
function BlockRegistry:IsInteractable(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.interactable == true
end

-- Check if block has storage
function BlockRegistry:HasStorage(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.storage == true
end

return BlockRegistry