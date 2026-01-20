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
			all = "rbxassetid://122997720050182"
		},
		crossShape = false
	},

	[Constants.BlockType.BEDROCK] = {
		name = "Bedrock",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 84, 84),
		textures = {
			all = "rbxassetid://72951007570270"
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
		transparent = true,
		color = Color3.fromRGB(108, 161, 63),
		textures = {
			all = "rbxassetid://109214997392631"
		},
		crossShape = false,
		greyscaleTexture = true
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
		hasRotation = true, -- NEW: Block can be rotated
		interactable = true -- Allow right-click interaction (Workbench)
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
	},

	-- Fences
	[Constants.BlockType.OAK_FENCE] = {
		name = "Oak Fence",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 114, 46),
		textures = {
			all = "oak_planks"
		},
		fenceShape = true,
		fenceGroup = "wood_fence"
	},

	-- Crafting materials
	[Constants.BlockType.STICK] = {
		name = "Stick",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 90, 43),
		textures = {
			all = "rbxassetid://99291598802145"
		},
		crossShape = true,  -- Render like flowers/tall grass
		craftingMaterial = true  -- Special flag for crafting-only items
	},

	-- Ores
	[Constants.BlockType.COAL_ORE] = {
		name = "Coal Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(67, 67, 67),
		textures = {
			all = "rbxassetid://79950940655441"
		},
		crossShape = false
	},

	[Constants.BlockType.IRON_ORE] = {
		name = "Iron Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(122, 122, 122),
		textures = {
			all = "rbxassetid://97259156198539"
		},
		crossShape = false
	},


	-- Refined materials
	[Constants.BlockType.COAL] = {
		name = "Coal",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(40, 40, 40),
		textures = {
			all = "rbxassetid://139096196695198"
		},
		crossShape = true,
		craftingMaterial = true
	},

	[Constants.BlockType.IRON_INGOT] = {
		name = "Iron Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(122, 122, 122), -- #7a7a7a
		textures = {
			all = "rbxassetid://116257653070196"
		},
		crossShape = true,
		craftingMaterial = true
	},


	-- Utility blocks
	[Constants.BlockType.FURNACE] = {
		name = "Furnace",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			top = "rbxassetid://128506415856113",
			side = "rbxassetid://86512770974162",
			front = "rbxassetid://103685363568790",
			back = "rbxassetid://86512770974162",
			bottom = "rbxassetid://128506415856113",
			all = "rbxassetid://86512770974162"
		},
		crossShape = false,
		hasRotation = true,
		interactable = true
	},

	[Constants.BlockType.GLASS] = {
		name = "Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(255, 255, 255),
		textures = {
			all = "rbxassetid://125273472115959"
		},
		crossShape = false
	},

	-- Stained Glass blocks (16 colors)
	[Constants.BlockType.WHITE_STAINED_GLASS] = {
		name = "White Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(255, 255, 255),
		textures = {
			all = "rbxassetid://101559724196735"
		},
		crossShape = false
	},

	[Constants.BlockType.ORANGE_STAINED_GLASS] = {
		name = "Orange Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(249, 128, 29),
		textures = {
			all = "rbxassetid://121766028214736"
		},
		crossShape = false
	},

	[Constants.BlockType.MAGENTA_STAINED_GLASS] = {
		name = "Magenta Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(189, 68, 179),
		textures = {
			all = "rbxassetid://127227482448978"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_BLUE_STAINED_GLASS] = {
		name = "Light Blue Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(58, 179, 218),
		textures = {
			all = "rbxassetid://79305777266996"
		},
		crossShape = false
	},

	[Constants.BlockType.YELLOW_STAINED_GLASS] = {
		name = "Yellow Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(254, 216, 61),
		textures = {
			all = "rbxassetid://129154023775403"
		},
		crossShape = false
	},

	[Constants.BlockType.LIME_STAINED_GLASS] = {
		name = "Lime Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(128, 199, 31),
		textures = {
			all = "rbxassetid://81265789094800"
		},
		crossShape = false
	},

	[Constants.BlockType.PINK_STAINED_GLASS] = {
		name = "Pink Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(243, 139, 170),
		textures = {
			all = "rbxassetid://92565059330167"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAY_STAINED_GLASS] = {
		name = "Gray Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(63, 63, 63),
		textures = {
			all = "rbxassetid://77116232897703"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_GRAY_STAINED_GLASS] = {
		name = "Light Gray Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(155, 155, 155),
		textures = {
			all = "rbxassetid://105560986972055"
		},
		crossShape = false
	},

	[Constants.BlockType.CYAN_STAINED_GLASS] = {
		name = "Cyan Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(22, 156, 156),
		textures = {
			all = "rbxassetid://111757732547609"
		},
		crossShape = false
	},

	[Constants.BlockType.PURPLE_STAINED_GLASS] = {
		name = "Purple Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(122, 42, 173),
		textures = {
			all = "rbxassetid://74096747910416"
		},
		crossShape = false
	},

	[Constants.BlockType.BLUE_STAINED_GLASS] = {
		name = "Blue Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(60, 68, 170),
		textures = {
			all = "rbxassetid://85136323316961"
		},
		crossShape = false
	},

	[Constants.BlockType.BROWN_STAINED_GLASS] = {
		name = "Brown Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(106, 57, 9),
		textures = {
			all = "rbxassetid://73610167807060"
		},
		crossShape = false
	},

	[Constants.BlockType.GREEN_STAINED_GLASS] = {
		name = "Green Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(84, 109, 27),
		textures = {
			all = "rbxassetid://110462844931723"
		},
		crossShape = false
	},

	[Constants.BlockType.RED_STAINED_GLASS] = {
		name = "Red Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(142, 33, 33),
		textures = {
			all = "rbxassetid://102994509797687"
		},
		crossShape = false
	},

	[Constants.BlockType.BLACK_STAINED_GLASS] = {
		name = "Black Stained Glass",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(20, 21, 25),
		textures = {
			all = "rbxassetid://107452960839875"
		},
		crossShape = false
	},

	-- Terracotta blocks (17 colors)
	[Constants.BlockType.TERRACOTTA] = {
		name = "Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(152, 94, 68),
		textures = {
			all = "rbxassetid://97059974560305"
		},
		crossShape = false
	},

	[Constants.BlockType.WHITE_TERRACOTTA] = {
		name = "White Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(209, 177, 161),
		textures = {
			all = "rbxassetid://89540083505437"
		},
		crossShape = false
	},

	[Constants.BlockType.ORANGE_TERRACOTTA] = {
		name = "Orange Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(159, 82, 36),
		textures = {
			all = "rbxassetid://90843590584261"
		},
		crossShape = false
	},

	[Constants.BlockType.MAGENTA_TERRACOTTA] = {
		name = "Magenta Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(149, 87, 108),
		textures = {
			all = "rbxassetid://135705054844099"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_BLUE_TERRACOTTA] = {
		name = "Light Blue Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(112, 108, 138),
		textures = {
			all = "rbxassetid://99778109908231"
		},
		crossShape = false
	},

	[Constants.BlockType.YELLOW_TERRACOTTA] = {
		name = "Yellow Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(186, 133, 36),
		textures = {
			all = "rbxassetid://89038002746670"
		},
		crossShape = false
	},

	[Constants.BlockType.LIME_TERRACOTTA] = {
		name = "Lime Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(103, 117, 53),
		textures = {
			all = "rbxassetid://128397464621655"
		},
		crossShape = false
	},

	[Constants.BlockType.PINK_TERRACOTTA] = {
		name = "Pink Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(160, 77, 78),
		textures = {
			all = "rbxassetid://124703932136783"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAY_TERRACOTTA] = {
		name = "Gray Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(57, 41, 35),
		textures = {
			all = "rbxassetid://92602201738916"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_GRAY_TERRACOTTA] = {
		name = "Light Gray Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(135, 107, 98),
		textures = {
			all = "rbxassetid://140641571434848"
		},
		crossShape = false
	},

	[Constants.BlockType.CYAN_TERRACOTTA] = {
		name = "Cyan Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(87, 91, 91),
		textures = {
			all = "rbxassetid://114368208575156"
		},
		crossShape = false
	},

	[Constants.BlockType.PURPLE_TERRACOTTA] = {
		name = "Purple Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(122, 73, 88),
		textures = {
			all = "rbxassetid://89309009255562"
		},
		crossShape = false
	},

	[Constants.BlockType.BLUE_TERRACOTTA] = {
		name = "Blue Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(74, 60, 91),
		textures = {
			all = "rbxassetid://94990685323008"
		},
		crossShape = false
	},

	[Constants.BlockType.BROWN_TERRACOTTA] = {
		name = "Brown Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(77, 51, 36),
		textures = {
			all = "rbxassetid://108346640958472"
		},
		crossShape = false
	},

	[Constants.BlockType.GREEN_TERRACOTTA] = {
		name = "Green Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(76, 83, 42),
		textures = {
			all = "rbxassetid://79867171164469"
		},
		crossShape = false
	},

	[Constants.BlockType.RED_TERRACOTTA] = {
		name = "Red Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 60, 46),
		textures = {
			all = "rbxassetid://85487817833931"
		},
		crossShape = false
	},

	[Constants.BlockType.BLACK_TERRACOTTA] = {
		name = "Black Terracotta",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(37, 22, 16),
		textures = {
			all = "rbxassetid://138500268109404"
		},
		crossShape = false
	},

	-- Wool blocks (16 colors)
	[Constants.BlockType.WHITE_WOOL] = {
		name = "White Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(233, 236, 236),
		textures = {
			all = "rbxassetid://89541443504786"
		},
		crossShape = false
	},

	[Constants.BlockType.ORANGE_WOOL] = {
		name = "Orange Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(249, 128, 29),
		textures = {
			all = "rbxassetid://128892676881010"
		},
		crossShape = false
	},

	[Constants.BlockType.MAGENTA_WOOL] = {
		name = "Magenta Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(189, 68, 179),
		textures = {
			all = "rbxassetid://131270645277697"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_BLUE_WOOL] = {
		name = "Light Blue Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(58, 179, 218),
		textures = {
			all = "rbxassetid://108882719531816"
		},
		crossShape = false
	},

	[Constants.BlockType.YELLOW_WOOL] = {
		name = "Yellow Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(254, 216, 61),
		textures = {
			all = "rbxassetid://114616257363493"
		},
		crossShape = false
	},

	[Constants.BlockType.LIME_WOOL] = {
		name = "Lime Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(128, 199, 31),
		textures = {
			all = "rbxassetid://116704379882608"
		},
		crossShape = false
	},

	[Constants.BlockType.PINK_WOOL] = {
		name = "Pink Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(243, 139, 170),
		textures = {
			all = "rbxassetid://131985514888841"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAY_WOOL] = {
		name = "Gray Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(63, 63, 63),
		textures = {
			all = "rbxassetid://83395797424120"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_GRAY_WOOL] = {
		name = "Light Gray Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(155, 155, 155),
		textures = {
			all = "rbxassetid://116426811683404"
		},
		crossShape = false
	},

	[Constants.BlockType.CYAN_WOOL] = {
		name = "Cyan Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(22, 156, 156),
		textures = {
			all = "rbxassetid://136581279855939"
		},
		crossShape = false
	},

	[Constants.BlockType.PURPLE_WOOL] = {
		name = "Purple Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(122, 42, 173),
		textures = {
			all = "rbxassetid://128367088551959"
		},
		crossShape = false
	},

	[Constants.BlockType.BLUE_WOOL] = {
		name = "Blue Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(60, 68, 170),
		textures = {
			all = "rbxassetid://84908082320166"
		},
		crossShape = false
	},

	[Constants.BlockType.BROWN_WOOL] = {
		name = "Brown Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(106, 57, 9),
		textures = {
			all = "rbxassetid://95346063217465"
		},
		crossShape = false
	},

	[Constants.BlockType.GREEN_WOOL] = {
		name = "Green Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 109, 27),
		textures = {
			all = "rbxassetid://109069031644742"
		},
		crossShape = false
	},

	[Constants.BlockType.RED_WOOL] = {
		name = "Red Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 33, 33),
		textures = {
			all = "rbxassetid://76065063448794"
		},
		crossShape = false
	},

	[Constants.BlockType.BLACK_WOOL] = {
		name = "Black Wool",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(20, 21, 25),
		textures = {
			all = "rbxassetid://99030790400384"
		},
		crossShape = false
	},

	-- Additional blocks
	[Constants.BlockType.NETHER_BRICKS] = {
		name = "Nether Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(48, 24, 28),
		textures = {
			all = "rbxassetid://128785967170527"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAVEL] = {
		name = "Gravel",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(127, 127, 127),
		textures = {
			all = "rbxassetid://120564951796528"
		},
		crossShape = false
	},

	[Constants.BlockType.COARSE_DIRT] = {
		name = "Coarse Dirt",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(135, 96, 66),
		textures = {
			all = "rbxassetid://99120189484076"
		},
		crossShape = false
	},

	-- Stone variants
	[Constants.BlockType.SANDSTONE] = {
		name = "Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 202, 160),
		textures = {
			top = "rbxassetid://137930792211357",
			bottom = "rbxassetid://136805892114309",
			side = "rbxassetid://137701739718359",
			all = "rbxassetid://137701739718359" -- Fallback
		},
		crossShape = false
	},

	[Constants.BlockType.DIORITE] = {
		name = "Diorite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 220, 220),
		textures = {
			all = "rbxassetid://109151622306052"
		},
		crossShape = false
	},

	[Constants.BlockType.POLISHED_DIORITE] = {
		name = "Polished Diorite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 220, 220),
		textures = {
			all = "rbxassetid://126833103762414"
		},
		crossShape = false
	},

	[Constants.BlockType.ANDESITE] = {
		name = "Andesite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(136, 136, 136),
		textures = {
			all = "rbxassetid://125993902053331"
		},
		crossShape = false
	},

	[Constants.BlockType.POLISHED_ANDESITE] = {
		name = "Polished Andesite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(136, 136, 136),
		textures = {
			all = "rbxassetid://103374196150633"
		},
		crossShape = false
	},

	-- Concrete blocks (16 colors)
	[Constants.BlockType.WHITE_CONCRETE] = {
		name = "White Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(207, 213, 214),
		textures = {
			all = "rbxassetid://134061445903358"
		},
		crossShape = false
	},

	[Constants.BlockType.ORANGE_CONCRETE] = {
		name = "Orange Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(224, 97, 1),
		textures = {
			all = "rbxassetid://132020713388236"
		},
		crossShape = false
	},

	[Constants.BlockType.MAGENTA_CONCRETE] = {
		name = "Magenta Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(169, 48, 159),
		textures = {
			all = "rbxassetid://108944072842970"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_BLUE_CONCRETE] = {
		name = "Light Blue Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(36, 137, 199),
		textures = {
			all = "rbxassetid://121912341948653"
		},
		crossShape = false
	},

	[Constants.BlockType.YELLOW_CONCRETE] = {
		name = "Yellow Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(241, 175, 21),
		textures = {
			all = "rbxassetid://122653472121870"
		},
		crossShape = false
	},

	[Constants.BlockType.LIME_CONCRETE] = {
		name = "Lime Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(94, 169, 24),
		textures = {
			all = "rbxassetid://126257202987136"
		},
		crossShape = false
	},

	[Constants.BlockType.PINK_CONCRETE] = {
		name = "Pink Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(214, 101, 143),
		textures = {
			all = "rbxassetid://87337779708956"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAY_CONCRETE] = {
		name = "Gray Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(55, 58, 62),
		textures = {
			all = "rbxassetid://92380672034294"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_GRAY_CONCRETE] = {
		name = "Light Gray Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(125, 125, 115),
		textures = {
			all = "rbxassetid://92556473453315"
		},
		crossShape = false
	},

	[Constants.BlockType.CYAN_CONCRETE] = {
		name = "Cyan Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(21, 119, 136),
		textures = {
			all = "rbxassetid://79009543043665"
		},
		crossShape = false
	},

	[Constants.BlockType.PURPLE_CONCRETE] = {
		name = "Purple Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(100, 32, 156),
		textures = {
			all = "rbxassetid://115975571453155"
		},
		crossShape = false
	},

	[Constants.BlockType.BLUE_CONCRETE] = {
		name = "Blue Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(45, 47, 143),
		textures = {
			all = "rbxassetid://115359561390718"
		},
		crossShape = false
	},

	[Constants.BlockType.BROWN_CONCRETE] = {
		name = "Brown Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(96, 60, 32),
		textures = {
			all = "rbxassetid://131769185067505"
		},
		crossShape = false
	},

	[Constants.BlockType.GREEN_CONCRETE] = {
		name = "Green Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(73, 91, 36),
		textures = {
			all = "rbxassetid://95624876732859"
		},
		crossShape = false
	},

	[Constants.BlockType.RED_CONCRETE] = {
		name = "Red Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 33, 33),
		textures = {
			all = "rbxassetid://116816202250681"
		},
		crossShape = false
	},

	[Constants.BlockType.BLACK_CONCRETE] = {
		name = "Black Concrete",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(8, 10, 15),
		textures = {
			all = "rbxassetid://77780395031462"
		},
		crossShape = false
	},

	-- Concrete powder blocks (16 colors)
	[Constants.BlockType.WHITE_CONCRETE_POWDER] = {
		name = "White Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(207, 213, 214),
		textures = {
			all = "rbxassetid://140409192582723"
		},
		crossShape = false
	},

	[Constants.BlockType.ORANGE_CONCRETE_POWDER] = {
		name = "Orange Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(224, 97, 1),
		textures = {
			all = "rbxassetid://116942281728029"
		},
		crossShape = false
	},

	[Constants.BlockType.MAGENTA_CONCRETE_POWDER] = {
		name = "Magenta Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(169, 48, 159),
		textures = {
			all = "rbxassetid://96648021299794"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_BLUE_CONCRETE_POWDER] = {
		name = "Light Blue Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(36, 137, 199),
		textures = {
			all = "rbxassetid://134088524735223"
		},
		crossShape = false
	},

	[Constants.BlockType.YELLOW_CONCRETE_POWDER] = {
		name = "Yellow Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(241, 175, 21),
		textures = {
			all = "rbxassetid://95372717832752"
		},
		crossShape = false
	},

	[Constants.BlockType.LIME_CONCRETE_POWDER] = {
		name = "Lime Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(94, 169, 24),
		textures = {
			all = "rbxassetid://124469408477863"
		},
		crossShape = false
	},

	[Constants.BlockType.PINK_CONCRETE_POWDER] = {
		name = "Pink Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(214, 101, 143),
		textures = {
			all = "rbxassetid://123360325811963"
		},
		crossShape = false
	},

	[Constants.BlockType.GRAY_CONCRETE_POWDER] = {
		name = "Gray Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(55, 58, 62),
		textures = {
			all = "rbxassetid://92018875964263"
		},
		crossShape = false
	},

	[Constants.BlockType.LIGHT_GRAY_CONCRETE_POWDER] = {
		name = "Light Gray Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(125, 125, 115),
		textures = {
			all = "rbxassetid://77743881447116"
		},
		crossShape = false
	},

	[Constants.BlockType.CYAN_CONCRETE_POWDER] = {
		name = "Cyan Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(21, 119, 136),
		textures = {
			all = "rbxassetid://125728638453972"
		},
		crossShape = false
	},

	[Constants.BlockType.PURPLE_CONCRETE_POWDER] = {
		name = "Purple Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(100, 32, 156),
		textures = {
			all = "rbxassetid://84621794876713"
		},
		crossShape = false
	},

	[Constants.BlockType.BLUE_CONCRETE_POWDER] = {
		name = "Blue Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(45, 47, 143),
		textures = {
			all = "rbxassetid://140116393996653"
		},
		crossShape = false
	},

	[Constants.BlockType.BROWN_CONCRETE_POWDER] = {
		name = "Brown Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(96, 60, 32),
		textures = {
			all = "rbxassetid://123132798731793"
		},
		crossShape = false
	},

	[Constants.BlockType.GREEN_CONCRETE_POWDER] = {
		name = "Green Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(73, 91, 36),
		textures = {
			all = "rbxassetid://98371532667643"
		},
		crossShape = false
	},

	[Constants.BlockType.RED_CONCRETE_POWDER] = {
		name = "Red Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 33, 33),
		textures = {
			all = "rbxassetid://113707793327671"
		},
		crossShape = false
	},

	[Constants.BlockType.BLACK_CONCRETE_POWDER] = {
		name = "Black Concrete Powder",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(8, 10, 15),
		textures = {
			all = "rbxassetid://104777196974200"
		},
		crossShape = false
	},

	-- Additional stair types (using textures from base blocks)
	[Constants.BlockType.ANDESITE_STAIRS] = {
		name = "Andesite Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(136, 136, 136),
		textures = {
			all = "rbxassetid://125993902053331"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.DIORITE_STAIRS] = {
		name = "Diorite Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 220, 220),
		textures = {
			all = "rbxassetid://109151622306052"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.SANDSTONE_STAIRS] = {
		name = "Sandstone Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 202, 160),
		textures = {
			top = "rbxassetid://137930792211357",
			bottom = "rbxassetid://136805892114309",
			side = "rbxassetid://137701739718359",
			all = "rbxassetid://137701739718359" -- Fallback
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.NETHER_BRICK_STAIRS] = {
		name = "Nether Brick Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(48, 24, 28),
		textures = {
			all = "rbxassetid://128785967170527"
		},
		stairShape = true,
		hasRotation = true
	},

	-- Quartz blocks
	[Constants.BlockType.QUARTZ_BLOCK] = {
		name = "Quartz Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(236, 233, 227),
		textures = {
			top = "rbxassetid://83975873493407",
			bottom = "rbxassetid://112797281792184",
			side = "rbxassetid://86606476374001",
			all = "rbxassetid://86606476374001" -- Fallback
		},
		crossShape = false
	},

	[Constants.BlockType.QUARTZ_PILLAR] = {
		name = "Quartz Pillar",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(236, 233, 227),
		textures = {
			top = "rbxassetid://108915086867923",
			bottom = "rbxassetid://108915086867923",
			side = "rbxassetid://99859045449711",
			all = "rbxassetid://99859045449711" -- Fallback
		},
		crossShape = false
	},

	[Constants.BlockType.CHISELED_QUARTZ_BLOCK] = {
		name = "Chiseled Quartz Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(236, 233, 227),
		textures = {
			top = "rbxassetid://75555939359221",
			bottom = "rbxassetid://75555939359221",
			side = "rbxassetid://129059241151222",
			all = "rbxassetid://129059241151222" -- Fallback
		},
		crossShape = false
	},

	[Constants.BlockType.QUARTZ_STAIRS] = {
		name = "Quartz Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(236, 233, 227),
		textures = {
			all = "rbxassetid://86606476374001" -- Use quartz block side texture
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.BLACKSTONE] = {
		name = "Blackstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 84, 84),
		textures = {
			all = "rbxassetid://72951007570270" -- Uses bedrock texture
		},
		crossShape = false
	},

	[Constants.BlockType.GRANITE] = {
		name = "Granite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(146, 100, 88),
		textures = {
			all = "rbxassetid://102350830817868"
		},
		crossShape = false
	},

	[Constants.BlockType.POLISHED_GRANITE] = {
		name = "Polished Granite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(146, 100, 88),
		textures = {
			all = "rbxassetid://103738974930285"
		},
		crossShape = false
	},

	[Constants.BlockType.GRANITE_STAIRS] = {
		name = "Granite Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(146, 100, 88),
		textures = {
			all = "rbxassetid://102350830817868" -- Use granite texture
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.PODZOL] = {
		name = "Podzol",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(123, 88, 60),
		textures = {
			top = "rbxassetid://83330783906624",
			bottom = "rbxassetid://73446970436738",
			side = "rbxassetid://73446970436738",
			all = "rbxassetid://73446970436738" -- Fallback
		},
		crossShape = false
	},

	-- Additional slab types (using textures from base blocks)
	[Constants.BlockType.GRANITE_SLAB] = {
		name = "Granite Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(146, 100, 88),
		textures = {
			all = "rbxassetid://102350830817868"
		},
		slabShape = true
	},

	[Constants.BlockType.BLACKSTONE_SLAB] = {
		name = "Blackstone Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 84, 84),
		textures = {
			all = "rbxassetid://72951007570270" -- Uses bedrock texture
		},
		slabShape = true
	},

	[Constants.BlockType.SMOOTH_QUARTZ_SLAB] = {
		name = "Smooth Quartz Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(236, 233, 227),
		textures = {
			all = "rbxassetid://86606476374001" -- Use quartz block side texture
		},
		slabShape = true
	},

	-- Utility: Stone Golem block (visual mob, block itself is invisible)
	[Constants.BlockType.COBBLESTONE_MINION] = {
		name = "Stone Golem",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 255, 255),
		textures = nil, -- invisible like AIR
		crossShape = false,
		interactable = true
	},
	-- Utility: Coal Golem block (visual mob, block itself is invisible)
	[Constants.BlockType.COAL_MINION] = {
		name = "Coal Golem",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 255, 255),
		textures = nil, -- invisible like AIR
		crossShape = false,
		interactable = true
	},

	[Constants.BlockType.APPLE] = {
		name = "Apple",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 0, 0),
		textures = {
			all = "rbxassetid://107743228743622" -- Note: 3D model may not have texture, this is fallback
		},
		crossShape = true,
		craftingMaterial = true,
		isFood = true
	},

	-- Spruce wood set
	[Constants.BlockType.SPRUCE_LOG] = {
		name = "Spruce Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(120, 91, 60),
		textures = {
			top = "spruce_log_top",
			side = "spruce_log_side",
			bottom = "spruce_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.SPRUCE_PLANKS] = {
		name = "Spruce Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(114, 84, 56),
		textures = {
			all = "spruce_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.SPRUCE_SAPLING] = {
		name = "Spruce Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(70, 120, 70),
		textures = {
			all = "spruce_sapling"
		},
		crossShape = true
	},

	[Constants.BlockType.SPRUCE_STAIRS] = {
		name = "Spruce Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(114, 84, 56),
		textures = {
			all = "spruce_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.SPRUCE_SLAB] = {
		name = "Spruce Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(114, 84, 56),
		textures = {
			all = "spruce_planks"
		},
		slabShape = true
	},

	-- Jungle wood set
	[Constants.BlockType.JUNGLE_LOG] = {
		name = "Jungle Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(151, 112, 80),
		textures = {
			top = "jungle_log_top",
			side = "jungle_log_side",
			bottom = "jungle_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.JUNGLE_PLANKS] = {
		name = "Jungle Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(170, 128, 95),
		textures = {
			all = "jungle_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.JUNGLE_SAPLING] = {
		name = "Jungle Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(70, 130, 70),
		textures = {
			all = "jungle_sapling"
		},
		crossShape = true
	},

	[Constants.BlockType.JUNGLE_STAIRS] = {
		name = "Jungle Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(170, 128, 95),
		textures = {
			all = "jungle_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.JUNGLE_SLAB] = {
		name = "Jungle Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(170, 128, 95),
		textures = {
			all = "jungle_planks"
		},
		slabShape = true
	},

	-- Dark Oak wood set
	[Constants.BlockType.DARK_OAK_LOG] = {
		name = "Dark Oak Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(85, 62, 42),
		textures = {
			top = "dark_oak_log_top",
			side = "dark_oak_log_side",
			bottom = "dark_oak_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.DARK_OAK_PLANKS] = {
		name = "Dark Oak Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(88, 66, 46),
		textures = {
			all = "dark_oak_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.DARK_OAK_SAPLING] = {
		name = "Dark Oak Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(60, 100, 60),
		textures = {
			all = "dark_oak_sapling"
		},
		crossShape = true
	},

	[Constants.BlockType.DARK_OAK_STAIRS] = {
		name = "Dark Oak Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(88, 66, 46),
		textures = {
			all = "dark_oak_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.DARK_OAK_SLAB] = {
		name = "Dark Oak Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(88, 66, 46),
		textures = {
			all = "dark_oak_planks"
		},
		slabShape = true
	},

	-- Birch wood set
	[Constants.BlockType.BIRCH_LOG] = {
		name = "Birch Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(200, 200, 180),
		textures = {
			top = "birch_log_top",
			side = "birch_log_side",
			bottom = "birch_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.BIRCH_PLANKS] = {
		name = "Birch Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(205, 190, 145),
		textures = {
			all = "birch_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.BIRCH_SAPLING] = {
		name = "Birch Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(80, 140, 80),
		textures = {
			all = "birch_sapling"
		},
		crossShape = true
	},

	[Constants.BlockType.BIRCH_STAIRS] = {
		name = "Birch Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(205, 190, 145),
		textures = {
			all = "birch_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.BIRCH_SLAB] = {
		name = "Birch Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(205, 190, 145),
		textures = {
			all = "birch_planks"
		},
		slabShape = true
	},

	-- Acacia wood set
	[Constants.BlockType.ACACIA_LOG] = {
		name = "Acacia Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(170, 92, 55),
		textures = {
			top = "acacia_log_top",
			side = "acacia_log_side",
			bottom = "acacia_log_top"
		},
		crossShape = false
	},

	[Constants.BlockType.ACACIA_PLANKS] = {
		name = "Acacia Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(184, 106, 72),
		textures = {
			all = "acacia_planks"
		},
		crossShape = false
	},

	[Constants.BlockType.ACACIA_SAPLING] = {
		name = "Acacia Sapling",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(85, 130, 85),
		textures = {
			all = "acacia_sapling"
		},
		crossShape = true
	},

	[Constants.BlockType.ACACIA_STAIRS] = {
		name = "Acacia Stairs",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(184, 106, 72),
		textures = {
			all = "acacia_planks"
		},
		stairShape = true,
		hasRotation = true
	},

	[Constants.BlockType.ACACIA_SLAB] = {
		name = "Acacia Slab",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(184, 106, 72),
		textures = {
			all = "acacia_planks"
		},
		slabShape = true
	},

	-- Leaf variants
	[Constants.BlockType.OAK_LEAVES] = {
		name = "Oak Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(108, 161, 63), -- tint over greyscale
		textures = {
			all = "rbxassetid://109214997392631"
		},
		crossShape = false,
		greyscaleTexture = true
	},

	[Constants.BlockType.SPRUCE_LEAVES] = {
		name = "Spruce Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(80, 120, 80),
		textures = {
			all = "rbxassetid://72044338024402"
		},
		crossShape = false
	},

	[Constants.BlockType.JUNGLE_LEAVES] = {
		name = "Jungle Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(100, 150, 90), -- tint over greyscale
		textures = {
			all = "rbxassetid://84783548880636"
		},
		crossShape = false,
		greyscaleTexture = true
	},

	[Constants.BlockType.DARK_OAK_LEAVES] = {
		name = "Dark Oak Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(70, 100, 70), -- tint over greyscale
		textures = {
			all = "rbxassetid://107093950967991"
		},
		crossShape = false,
		greyscaleTexture = true
	},

	[Constants.BlockType.BIRCH_LEAVES] = {
		name = "Birch Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(150, 190, 120),
		textures = {
			all = "rbxassetid://80285390003829"
		},
		crossShape = false
	},

	[Constants.BlockType.ACACIA_LEAVES] = {
		name = "Acacia Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(120, 150, 90),
		textures = {
			all = "rbxassetid://120614493977362"
		},
		crossShape = false
	}
,

	-- Farming blocks/items
	[Constants.BlockType.FARMLAND] = {
		name = "Farmland",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(150, 100, 70),
		textures = {
			top = "rbxassetid://94222438062668",
			side = "dirt",
			bottom = "dirt"
		},
		crossShape = false
	},

	-- Inventory items (cross-shaped for icon rendering)
	[Constants.BlockType.WHEAT_SEEDS] = {
		name = "Wheat Seeds",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 200, 200),
		textures = { all = "rbxassetid://117288971547153" },
		crossShape = true
	},
	[Constants.BlockType.WHEAT] = {
		name = "Wheat",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(230, 210, 140),
		textures = { all = "rbxassetid://121084143590632" },
		crossShape = true
	},
	[Constants.BlockType.POTATO] = {
		name = "Potato",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 170, 120),
		textures = { all = "rbxassetid://85531142626814" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.CARROT] = {
		name = "Carrot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(240, 150, 80),
		textures = { all = "rbxassetid://98545720533447" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.BEETROOT_SEEDS] = {
		name = "Beetroot Seeds",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 200, 200),
		textures = { all = "rbxassetid://110414583156032" },
		crossShape = true
	},
	[Constants.BlockType.BEETROOT] = {
		name = "Beetroot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 50, 80),
		textures = { all = "rbxassetid://94002656186960" },
		crossShape = true,
		isFood = true
	},

	-- Wheat crop stages (cross-shaped)
	[Constants.BlockType.WHEAT_CROP_0] = { name = "Wheat (Stage 0)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://114356013890110" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_1] = { name = "Wheat (Stage 1)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://101949350772745" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_2] = { name = "Wheat (Stage 2)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://133533519991116" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_3] = { name = "Wheat (Stage 3)", solid = false, transparent = true, color = Color3.fromRGB(190, 200, 120), textures = { all = "rbxassetid://102996391913529" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_4] = { name = "Wheat (Stage 4)", solid = false, transparent = true, color = Color3.fromRGB(200, 200, 120), textures = { all = "rbxassetid://77729218147670" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_5] = { name = "Wheat (Stage 5)", solid = false, transparent = true, color = Color3.fromRGB(210, 200, 120), textures = { all = "rbxassetid://105328080071552" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_6] = { name = "Wheat (Stage 6)", solid = false, transparent = true, color = Color3.fromRGB(220, 200, 120), textures = { all = "rbxassetid://83753723300014" }, crossShape = true },
	[Constants.BlockType.WHEAT_CROP_7] = { name = "Wheat (Stage 7)", solid = false, transparent = true, color = Color3.fromRGB(230, 200, 120), textures = { all = "rbxassetid://136030730993000" }, crossShape = true },

	-- Potato crop stages
	[Constants.BlockType.POTATO_CROP_0] = { name = "Potatoes (Stage 0)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://128460303336429" }, crossShape = true },
	[Constants.BlockType.POTATO_CROP_1] = { name = "Potatoes (Stage 1)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://92682259576493" }, crossShape = true },
	[Constants.BlockType.POTATO_CROP_2] = { name = "Potatoes (Stage 2)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://103623438750445" }, crossShape = true },
	[Constants.BlockType.POTATO_CROP_3] = { name = "Potatoes (Stage 3)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://104276053911593" }, crossShape = true },

	-- Carrot crop stages
	[Constants.BlockType.CARROT_CROP_0] = { name = "Carrots (Stage 0)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://128380408094802" }, crossShape = true },
	[Constants.BlockType.CARROT_CROP_1] = { name = "Carrots (Stage 1)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://107854444375662" }, crossShape = true },
	[Constants.BlockType.CARROT_CROP_2] = { name = "Carrots (Stage 2)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://71473488230615" }, crossShape = true },
	[Constants.BlockType.CARROT_CROP_3] = { name = "Carrots (Stage 3)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://81683662013698" }, crossShape = true },

	-- Beetroot crop stages
	[Constants.BlockType.BEETROOT_CROP_0] = { name = "Beetroots (Stage 0)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://79781523080066" }, crossShape = true },
	[Constants.BlockType.BEETROOT_CROP_1] = { name = "Beetroots (Stage 1)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://81286687752129" }, crossShape = true },
	[Constants.BlockType.BEETROOT_CROP_2] = { name = "Beetroots (Stage 2)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://119272458748743" }, crossShape = true },
	[Constants.BlockType.BEETROOT_CROP_3] = { name = "Beetroots (Stage 3)", solid = false, transparent = true, color = Color3.fromRGB(180, 200, 120), textures = { all = "rbxassetid://105511567346427" }, crossShape = true },

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ORES (6-tier progression: Copper → Iron → Steel → Bluesteel → Tungsten → Titanium)
	-- ═══════════════════════════════════════════════════════════════════════════

	[Constants.BlockType.COPPER_ORE] = {
		name = "Copper Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(188, 105, 47), -- #bc692f
		textures = { all = "rbxassetid://136807077587468" },
		crossShape = false
	},
	[Constants.BlockType.BLUESTEEL_ORE] = {
		name = "Bluesteel Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(149, 190, 246), -- #95bef6
		textures = { all = "rbxassetid://101828645932065" },
		crossShape = false
	},
	[Constants.BlockType.TUNGSTEN_ORE] = {
		name = "Tungsten Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(232, 244, 255), -- #e8f4ff
		textures = { all = "rbxassetid://133328089014739" },
		crossShape = false
	},
	[Constants.BlockType.TITANIUM_ORE] = {
		name = "Titanium Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(193, 242, 242), -- #c1f2f2
		textures = { all = "rbxassetid://70831716548382" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- INGOTS/MATERIALS (crafting materials - not placeable)
	-- ═══════════════════════════════════════════════════════════════════════════

	[Constants.BlockType.COPPER_INGOT] = {
		name = "Copper Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(188, 105, 47), -- #bc692f
		textures = { all = "rbxassetid://117987670821375" },
		crossShape = true,
		craftingMaterial = true
	},
	[Constants.BlockType.STEEL_INGOT] = {
		name = "Steel Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(173, 173, 173), -- #adadad
		textures = { all = "rbxassetid://103080988701146" },
		crossShape = true,
		craftingMaterial = true
	},
	[Constants.BlockType.BLUESTEEL_INGOT] = {
		name = "Bluesteel Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(149, 190, 246), -- #95bef6
		textures = { all = "rbxassetid://121436448752857" },
		crossShape = true,
		craftingMaterial = true
	},
	[Constants.BlockType.TUNGSTEN_INGOT] = {
		name = "Tungsten Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(232, 244, 255), -- #e8f4ff
		textures = { all = "rbxassetid://136722055090955" },
		crossShape = true,
		craftingMaterial = true
	},
	[Constants.BlockType.TITANIUM_INGOT] = {
		name = "Titanium Ingot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(193, 242, 242), -- #c1f2f2
		textures = { all = "rbxassetid://72533241452362" },
		crossShape = true,
		craftingMaterial = true
	},
	[Constants.BlockType.BLUESTEEL_DUST] = {
		name = "Bluesteel Dust",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(149, 190, 246), -- #95bef6
		textures = { all = "rbxassetid://122819289085836" },
		crossShape = true,
		craftingMaterial = true
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- FULL BLOCKS (9x ingots/items)
	-- ═══════════════════════════════════════════════════════════════════════════

	[Constants.BlockType.COPPER_BLOCK] = {
		name = "Copper Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(188, 105, 47), -- #bc692f
		textures = { all = "rbxassetid://115933247878677" },
		crossShape = false
	},
	[Constants.BlockType.COAL_BLOCK] = {
		name = "Coal Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(40, 40, 40),
		textures = { all = "rbxassetid://74344180768881" },
		crossShape = false
	},
	[Constants.BlockType.IRON_BLOCK] = {
		name = "Iron Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(122, 122, 122), -- #7a7a7a
		textures = { all = "rbxassetid://105161132495681" },
		crossShape = false
	},
	[Constants.BlockType.STEEL_BLOCK] = {
		name = "Steel Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(173, 173, 173), -- #adadad
		textures = { all = "rbxassetid://76501364497397" },
		crossShape = false
	},
	[Constants.BlockType.BLUESTEEL_BLOCK] = {
		name = "Bluesteel Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(149, 190, 246), -- #95bef6
		textures = { all = "rbxassetid://74339957046108" },
		crossShape = false
	},
	[Constants.BlockType.TUNGSTEN_BLOCK] = {
		name = "Tungsten Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(232, 244, 255), -- #e8f4ff
		textures = { all = "rbxassetid://91018177845956" },
		crossShape = false
	},
	[Constants.BlockType.TITANIUM_BLOCK] = {
		name = "Titanium Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(193, 242, 242), -- #c1f2f2
		textures = { all = "rbxassetid://120386947860707" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ICE VARIANTS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.ICE] = {
		name = "Ice",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(160, 200, 255),
		textures = { all = "rbxassetid://96743487700676" },
		crossShape = false
	},
	[Constants.BlockType.PACKED_ICE] = {
		name = "Packed Ice",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(140, 180, 220),
		textures = { all = "rbxassetid://75266323917626" },
		crossShape = false
	},
	[Constants.BlockType.BLUE_ICE] = {
		name = "Blue Ice",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(100, 150, 220),
		textures = { all = "rbxassetid://84379385514767" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SNOW & SPONGE
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.SNOW_BLOCK] = {
		name = "Snow Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(249, 255, 255),
		textures = { all = "rbxassetid://92415018888386" },
		crossShape = false
	},
	[Constants.BlockType.SPONGE] = {
		name = "Sponge",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(195, 192, 74),
		textures = { all = "rbxassetid://79375009831611" },
		crossShape = false
	},
	[Constants.BlockType.WET_SPONGE] = {
		name = "Wet Sponge",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(160, 160, 70),
		textures = { all = "rbxassetid://92174994791697" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- NETHER BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.NETHERRACK] = {
		name = "Netherrack",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(97, 38, 38),
		textures = { all = "rbxassetid://107740562127200" },
		crossShape = false
	},
	[Constants.BlockType.SOUL_SAND] = {
		name = "Soul Sand",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(81, 62, 50),
		textures = { all = "rbxassetid://94512551206593" },
		crossShape = false
	},
	[Constants.BlockType.MAGMA_BLOCK] = {
		name = "Magma Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 63, 31),
		textures = { all = "rbxassetid://104970673405330" },
		crossShape = false
	},
	[Constants.BlockType.GLOWSTONE] = {
		name = "Glowstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(171, 131, 84),
		textures = { all = "rbxassetid://106914203863166" },
		crossShape = false
	},
	[Constants.BlockType.NETHER_WART_BLOCK] = {
		name = "Nether Wart Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(114, 2, 2),
		textures = { all = "rbxassetid://83259084292401" },
		crossShape = false
	},
	[Constants.BlockType.RED_NETHER_BRICKS] = {
		name = "Red Nether Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(69, 7, 9),
		textures = { all = "rbxassetid://88910294399355" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- OCEAN BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.SEA_LANTERN] = {
		name = "Sea Lantern",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(172, 199, 190),
		textures = { all = "rbxassetid://117550873516062" },
		crossShape = false
	},
	[Constants.BlockType.PRISMARINE] = {
		name = "Prismarine",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(99, 156, 151),
		textures = { all = "rbxassetid://98862659002356" },
		crossShape = false
	},
	[Constants.BlockType.PRISMARINE_BRICKS] = {
		name = "Prismarine Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(99, 171, 158),
		textures = { all = "rbxassetid://131504940340385" },
		crossShape = false
	},
	[Constants.BlockType.DARK_PRISMARINE] = {
		name = "Dark Prismarine",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(51, 91, 75),
		textures = { all = "rbxassetid://103531221763856" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- END BLOCKS (Purpur)
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.PURPUR_BLOCK] = {
		name = "Purpur Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(169, 125, 169),
		textures = { all = "rbxassetid://92744126775031" },
		crossShape = false
	},
	[Constants.BlockType.PURPUR_PILLAR] = {
		name = "Purpur Pillar",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(169, 125, 169),
		textures = {
			top = "rbxassetid://94027067868528",
			bottom = "rbxassetid://94027067868528",
			side = "rbxassetid://85132853149472",
			all = "rbxassetid://85132853149472"
		},
		crossShape = false
	},
	[Constants.BlockType.END_STONE] = {
		name = "End Stone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(219, 222, 158),
		textures = { all = "rbxassetid://115183801525313" }, -- Using stone as fallback
		crossShape = false
	},
	[Constants.BlockType.END_STONE_BRICKS] = {
		name = "End Stone Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(219, 222, 158),
		textures = { all = "rbxassetid://101759303836378" }, -- Using stone bricks as fallback
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MELON & PUMPKIN
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.MELON] = {
		name = "Melon",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(111, 145, 31),
		textures = {
			top = "rbxassetid://102480458382931",
			bottom = "rbxassetid://102480458382931",
			side = "rbxassetid://124722007953987",
			all = "rbxassetid://124722007953987"
		},
		crossShape = false
	},
	[Constants.BlockType.PUMPKIN] = {
		name = "Pumpkin",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(198, 118, 24),
		textures = {
			top = "rbxassetid://80664775024999",
			bottom = "rbxassetid://80664775024999",
			side = "rbxassetid://97456610277877",
			all = "rbxassetid://97456610277877"
		},
		crossShape = false
	},
	[Constants.BlockType.CARVED_PUMPKIN] = {
		name = "Carved Pumpkin",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(198, 118, 24),
		textures = {
			top = "rbxassetid://80664775024999",
			bottom = "rbxassetid://80664775024999",
			front = "rbxassetid://134873735074293",
			side = "rbxassetid://97456610277877",
			all = "rbxassetid://97456610277877"
		},
		crossShape = false,
		hasRotation = true
	},
	[Constants.BlockType.JACK_O_LANTERN] = {
		name = "Jack o'Lantern",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(198, 118, 24),
		textures = {
			top = "rbxassetid://80664775024999",
			bottom = "rbxassetid://80664775024999",
			front = "rbxassetid://100828620621190",
			side = "rbxassetid://97456610277877",
			all = "rbxassetid://97456610277877"
		},
		crossShape = false,
		hasRotation = true
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PLANTS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.CACTUS] = {
		name = "Cactus",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(85, 127, 43),
		textures = {
			top = "rbxassetid://94563015961260",
			bottom = "rbxassetid://97822724502105",
			side = "rbxassetid://79094656952253",
			all = "rbxassetid://79094656952253"
		},
		crossShape = false
	},
	[Constants.BlockType.SUGAR_CANE] = {
		name = "Sugar Cane",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(148, 192, 101),
		textures = { all = "rbxassetid://128037896541445" },
		crossShape = true
	},
	[Constants.BlockType.HAY_BLOCK] = {
		name = "Hay Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(166, 139, 28),
		textures = {
			top = "rbxassetid://114055682157370",
			bottom = "rbxassetid://114055682157370",
			side = "rbxassetid://92792702867171",
			all = "rbxassetid://92792702867171"
		},
		crossShape = false
	},
	[Constants.BlockType.DEAD_BUSH] = {
		name = "Dead Bush",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(107, 78, 40),
		textures = { all = "rbxassetid://116161927933610" },
		crossShape = true
	},
	[Constants.BlockType.LILY_PAD] = {
		name = "Lily Pad",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(32, 128, 48),
		textures = { all = "rbxassetid://119985599542708" },
		crossShape = true
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MUSHROOMS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.BROWN_MUSHROOM] = {
		name = "Brown Mushroom",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(149, 111, 82),
		textures = { all = "rbxassetid://78203109427997" },
		crossShape = true
	},
	[Constants.BlockType.RED_MUSHROOM] = {
		name = "Red Mushroom",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(216, 75, 67),
		textures = { all = "rbxassetid://130349192960951" },
		crossShape = true
	},
	[Constants.BlockType.BROWN_MUSHROOM_BLOCK] = {
		name = "Brown Mushroom Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(149, 111, 82),
		textures = { all = "rbxassetid://125837820790379" },
		crossShape = false
	},
	[Constants.BlockType.RED_MUSHROOM_BLOCK] = {
		name = "Red Mushroom Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(200, 46, 45),
		textures = { all = "rbxassetid://98579956986334" },
		crossShape = false
	},
	[Constants.BlockType.MUSHROOM_STEM] = {
		name = "Mushroom Stem",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(203, 195, 185),
		textures = { all = "rbxassetid://110653819771271" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SPECIAL BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.SLIME_BLOCK] = {
		name = "Slime Block",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(112, 192, 91),
		textures = { all = "rbxassetid://106116802685553" },
		crossShape = false
	},
	[Constants.BlockType.HONEY_BLOCK] = {
		name = "Honey Block",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(250, 171, 62),
		textures = { all = "rbxassetid://106116802685553" }, -- Using slime texture as fallback
		crossShape = false
	},
	[Constants.BlockType.BONE_BLOCK] = {
		name = "Bone Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(229, 225, 207),
		textures = {
			top = "rbxassetid://87899701364563",
			bottom = "rbxassetid://87899701364563",
			side = "rbxassetid://123505514936937",
			all = "rbxassetid://123505514936937"
		},
		crossShape = false
	},
	[Constants.BlockType.COBWEB] = {
		name = "Cobweb",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(228, 233, 234),
		textures = { all = "rbxassetid://82949317923507" },
		crossShape = true
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- UTILITY BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.BOOKSHELF] = {
		name = "Bookshelf",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(162, 130, 78),
		textures = {
			top = "rbxassetid://133840556774740",
			bottom = "rbxassetid://133840556774740",
			side = "rbxassetid://96702038987751",
			all = "rbxassetid://96702038987751"
		},
		crossShape = false
	},
	[Constants.BlockType.JUKEBOX] = {
		name = "Jukebox",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(107, 71, 45),
		textures = {
			top = "rbxassetid://92669609784698",
			bottom = "rbxassetid://92669609784698",
			side = "rbxassetid://113071519822080",
			all = "rbxassetid://113071519822080"
		},
		crossShape = false
	},
	[Constants.BlockType.NOTE_BLOCK] = {
		name = "Note Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(107, 71, 45),
		textures = { all = "rbxassetid://136511262353941" },
		crossShape = false
	},
	[Constants.BlockType.TNT] = {
		name = "TNT",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(219, 68, 26),
		textures = {
			top = "rbxassetid://99397443420413",
			bottom = "rbxassetid://82999094870264",
			side = "rbxassetid://101000178767581",
			all = "rbxassetid://101000178767581"
		},
		crossShape = false
	},
	[Constants.BlockType.SPAWNER] = {
		name = "Spawner",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(37, 55, 62),
		textures = { all = "rbxassetid://112195000812184" },
		crossShape = false
	},
	[Constants.BlockType.OBSIDIAN] = {
		name = "Obsidian",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(15, 10, 24),
		textures = { all = "rbxassetid://136505434230911" },
		crossShape = false
	},
	[Constants.BlockType.DRIED_KELP_BLOCK] = {
		name = "Dried Kelp Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(50, 58, 35),
		textures = {
			top = "rbxassetid://102483596486958",
			bottom = "rbxassetid://129485023640765",
			side = "rbxassetid://140536801666725",
			all = "rbxassetid://140536801666725"
		},
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- STONE VARIANTS (additional)
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.SMOOTH_STONE] = {
		name = "Smooth Stone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(158, 158, 158),
		textures = { all = "rbxassetid://115183801525313" },
		crossShape = false
	},
	[Constants.BlockType.MOSSY_COBBLESTONE] = {
		name = "Mossy Cobblestone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(110, 118, 94),
		textures = { all = "rbxassetid://79369165726496" },
		crossShape = false
	},
	[Constants.BlockType.MOSSY_STONE_BRICKS] = {
		name = "Mossy Stone Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(115, 121, 105),
		textures = { all = "rbxassetid://117764250729527" },
		crossShape = false
	},
	[Constants.BlockType.CRACKED_STONE_BRICKS] = {
		name = "Cracked Stone Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(118, 118, 118),
		textures = { all = "rbxassetid://79352827156243" },
		crossShape = false
	},
	[Constants.BlockType.CHISELED_STONE_BRICKS] = {
		name = "Chiseled Stone Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(120, 120, 120),
		textures = { all = "rbxassetid://91362927949400" },
		crossShape = false
	},
	[Constants.BlockType.MYCELIUM] = {
		name = "Mycelium",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(111, 99, 106),
		textures = {
			top = "rbxassetid://134502316741177",
			bottom = "rbxassetid://119220930990167",
			side = "rbxassetid://139241008869261",
			all = "rbxassetid://139241008869261"
		},
		crossShape = false
	},
	[Constants.BlockType.CLAY_BLOCK] = {
		name = "Clay",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(160, 166, 179),
		textures = { all = "rbxassetid://110798275614273" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SANDSTONE VARIANTS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.RED_SANDSTONE] = {
		name = "Red Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(186, 99, 29),
		textures = {
			top = "rbxassetid://112358652150634",
			bottom = "rbxassetid://120934199558038",
			side = "rbxassetid://106028151834528",
			all = "rbxassetid://106028151834528"
		},
		crossShape = false
	},
	[Constants.BlockType.RED_SAND] = {
		name = "Red Sand",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(190, 102, 33),
		textures = { all = "rbxassetid://129949771602581" },
		crossShape = false
	},
	[Constants.BlockType.CUT_SANDSTONE] = {
		name = "Cut Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 202, 160),
		textures = { all = "rbxassetid://139354278952882" },
		crossShape = false
	},
	[Constants.BlockType.CHISELED_SANDSTONE] = {
		name = "Chiseled Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 202, 160),
		textures = { all = "rbxassetid://125661543214474" },
		crossShape = false
	},
	[Constants.BlockType.SMOOTH_SANDSTONE] = {
		name = "Smooth Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(220, 202, 160),
		textures = { all = "rbxassetid://92878917320673" },
		crossShape = false
	},
	[Constants.BlockType.CUT_RED_SANDSTONE] = {
		name = "Cut Red Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(186, 99, 29),
		textures = { all = "rbxassetid://138179782463303" },
		crossShape = false
	},
	[Constants.BlockType.CHISELED_RED_SANDSTONE] = {
		name = "Chiseled Red Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(186, 99, 29),
		textures = { all = "rbxassetid://94772791776170" },
		crossShape = false
	},
	[Constants.BlockType.SMOOTH_RED_SANDSTONE] = {
		name = "Smooth Red Sandstone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(186, 99, 29),
		textures = { all = "rbxassetid://112358652150634" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- STRIPPED LOGS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.STRIPPED_OAK_LOG] = {
		name = "Stripped Oak Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(177, 144, 86),
		textures = {
			top = "rbxassetid://86207536636319",
			bottom = "rbxassetid://86207536636319",
			side = "rbxassetid://116598275917241",
			all = "rbxassetid://116598275917241"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_SPRUCE_LOG] = {
		name = "Stripped Spruce Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(115, 89, 52),
		textures = {
			top = "rbxassetid://107050453215631",
			bottom = "rbxassetid://107050453215631",
			side = "rbxassetid://124010513442397",
			all = "rbxassetid://124010513442397"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_BIRCH_LOG] = {
		name = "Stripped Birch Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(196, 176, 118),
		textures = {
			top = "rbxassetid://81347121658265",
			bottom = "rbxassetid://81347121658265",
			side = "rbxassetid://109105316431438",
			all = "rbxassetid://109105316431438"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_JUNGLE_LOG] = {
		name = "Stripped Jungle Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(171, 132, 84),
		textures = {
			top = "rbxassetid://132310236236978",
			bottom = "rbxassetid://132310236236978",
			side = "rbxassetid://76554799409444",
			all = "rbxassetid://76554799409444"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_ACACIA_LOG] = {
		name = "Stripped Acacia Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(174, 92, 59),
		textures = {
			top = "rbxassetid://128133586280282",
			bottom = "rbxassetid://128133586280282",
			side = "rbxassetid://90228715307033",
			all = "rbxassetid://90228715307033"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_DARK_OAK_LOG] = {
		name = "Stripped Dark Oak Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(96, 76, 49),
		textures = {
			top = "rbxassetid://129194372797805",
			bottom = "rbxassetid://129194372797805",
			side = "rbxassetid://74759388892088",
			all = "rbxassetid://74759388892088"
		},
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COPPER VARIANTS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.CUT_COPPER] = {
		name = "Cut Copper",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(188, 105, 47),
		textures = { all = "rbxassetid://115933247878677" },
		crossShape = false
	},
	[Constants.BlockType.EXPOSED_COPPER] = {
		name = "Exposed Copper",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(161, 125, 103),
		textures = { all = "rbxassetid://115933247878677" },
		crossShape = false
	},
	[Constants.BlockType.WEATHERED_COPPER] = {
		name = "Weathered Copper",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(108, 153, 110),
		textures = { all = "rbxassetid://115933247878677" },
		crossShape = false
	},
	[Constants.BlockType.OXIDIZED_COPPER] = {
		name = "Oxidized Copper",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(82, 162, 132),
		textures = { all = "rbxassetid://115933247878677" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- DEEPSLATE & TUFF
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.DEEPSLATE] = {
		name = "Deepslate",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(80, 80, 82),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.COBBLED_DEEPSLATE] = {
		name = "Cobbled Deepslate",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(77, 77, 80),
		textures = { all = "rbxassetid://130912274010831" },
		crossShape = false
	},
	[Constants.BlockType.POLISHED_DEEPSLATE] = {
		name = "Polished Deepslate",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(72, 72, 73),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.DEEPSLATE_BRICKS] = {
		name = "Deepslate Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(70, 70, 71),
		textures = { all = "rbxassetid://101759303836378" },
		crossShape = false
	},
	[Constants.BlockType.DEEPSLATE_TILES] = {
		name = "Deepslate Tiles",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(54, 54, 55),
		textures = { all = "rbxassetid://101759303836378" },
		crossShape = false
	},
	[Constants.BlockType.TUFF] = {
		name = "Tuff",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(108, 109, 102),
		textures = { all = "rbxassetid://124393974492403" },
		crossShape = false
	},
	[Constants.BlockType.CALCITE] = {
		name = "Calcite",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(223, 224, 220),
		textures = { all = "rbxassetid://92415018888386" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- AMETHYST
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.AMETHYST_BLOCK] = {
		name = "Amethyst Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(133, 97, 191),
		textures = { all = "rbxassetid://92744126775031" },
		crossShape = false
	},
	[Constants.BlockType.BUDDING_AMETHYST] = {
		name = "Budding Amethyst",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(133, 97, 191),
		textures = { all = "rbxassetid://92744126775031" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- BASALT
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.BASALT] = {
		name = "Basalt",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(73, 72, 77),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.POLISHED_BASALT] = {
		name = "Polished Basalt",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(65, 65, 68),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.SMOOTH_BASALT] = {
		name = "Smooth Basalt",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(72, 72, 72),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MISC NETHER/END BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.CRYING_OBSIDIAN] = {
		name = "Crying Obsidian",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(32, 10, 60),
		textures = { all = "rbxassetid://136505434230911" },
		crossShape = false
	},
	[Constants.BlockType.SHROOMLIGHT] = {
		name = "Shroomlight",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(240, 146, 70),
		textures = { all = "rbxassetid://106914203863166" },
		crossShape = false
	},
	[Constants.BlockType.WARPED_WART_BLOCK] = {
		name = "Warped Wart Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(22, 119, 121),
		textures = { all = "rbxassetid://83259084292401" },
		crossShape = false
	},
	[Constants.BlockType.SOUL_SOIL] = {
		name = "Soul Soil",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(75, 56, 46),
		textures = { all = "rbxassetid://94512551206593" },
		crossShape = false
	},
	[Constants.BlockType.NETHER_GOLD_ORE] = {
		name = "Nether Gold Ore",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(115, 54, 42),
		textures = { all = "rbxassetid://107740562127200" },
		crossShape = false
	},
	[Constants.BlockType.ANCIENT_DEBRIS] = {
		name = "Ancient Debris",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(95, 74, 59),
		textures = { all = "rbxassetid://107740562127200" },
		crossShape = false
	},
	[Constants.BlockType.LODESTONE] = {
		name = "Lodestone",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(147, 147, 147),
		textures = { all = "rbxassetid://101759303836378" },
		crossShape = false
	},
	[Constants.BlockType.RESPAWN_ANCHOR] = {
		name = "Respawn Anchor",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(35, 13, 55),
		textures = { all = "rbxassetid://136505434230911" },
		crossShape = false
	},
	[Constants.BlockType.CHAIN] = {
		name = "Chain",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(54, 60, 74),
		textures = { all = "rbxassetid://140497075939141" },
		crossShape = true
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SCULK (Deep Dark)
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.SCULK] = {
		name = "Sculk",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(12, 28, 36),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.SCULK_CATALYST] = {
		name = "Sculk Catalyst",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(15, 30, 38),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},
	[Constants.BlockType.REINFORCED_DEEPSLATE] = {
		name = "Reinforced Deepslate",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(55, 55, 56),
		textures = { all = "rbxassetid://72951007570270" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MANGROVE & MUD
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.MUD] = {
		name = "Mud",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(60, 57, 61),
		textures = { all = "rbxassetid://119220930990167" },
		crossShape = false
	},
	[Constants.BlockType.PACKED_MUD] = {
		name = "Packed Mud",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(142, 106, 79),
		textures = { all = "rbxassetid://119220930990167" },
		crossShape = false
	},
	[Constants.BlockType.MUD_BRICKS] = {
		name = "Mud Bricks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(137, 104, 77),
		textures = { all = "rbxassetid://129539517338826" },
		crossShape = false
	},
	[Constants.BlockType.MANGROVE_LOG] = {
		name = "Mangrove Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(84, 67, 41),
		textures = {
			top = "rbxassetid://125270540000651",
			bottom = "rbxassetid://125270540000651",
			side = "rbxassetid://74397475943828",
			all = "rbxassetid://74397475943828"
		},
		crossShape = false
	},
	[Constants.BlockType.MANGROVE_PLANKS] = {
		name = "Mangrove Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(117, 54, 48),
		textures = { all = "rbxassetid://118059443047835" },
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_MANGROVE_LOG] = {
		name = "Stripped Mangrove Log",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(119, 54, 47),
		textures = {
			top = "rbxassetid://125270540000651",
			bottom = "rbxassetid://125270540000651",
			side = "rbxassetid://74397475943828",
			all = "rbxassetid://74397475943828"
		},
		crossShape = false
	},
	[Constants.BlockType.MANGROVE_LEAVES] = {
		name = "Mangrove Leaves",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(85, 119, 47),
		textures = { all = "rbxassetid://100299341230111" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MOSS & DRIPSTONE
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.MOSS_BLOCK] = {
		name = "Moss Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(89, 109, 45),
		textures = { all = "rbxassetid://72610229433669" },
		crossShape = false
	},
	[Constants.BlockType.MOSS_CARPET] = {
		name = "Moss Carpet",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(89, 109, 45),
		textures = { all = "rbxassetid://72610229433669" },
		crossShape = false
	},
	[Constants.BlockType.DRIPSTONE_BLOCK] = {
		name = "Dripstone Block",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(134, 107, 92),
		textures = { all = "rbxassetid://115183801525313" },
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- CRIMSON & WARPED (Nether Wood)
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.CRIMSON_STEM] = {
		name = "Crimson Stem",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(101, 48, 70),
		textures = {
			top = "rbxassetid://138232486242288",
			bottom = "rbxassetid://138232486242288",
			side = "rbxassetid://139268979301523",
			all = "rbxassetid://139268979301523"
		},
		crossShape = false
	},
	[Constants.BlockType.WARPED_STEM] = {
		name = "Warped Stem",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(58, 58, 77),
		textures = {
			top = "rbxassetid://125270540000651",
			bottom = "rbxassetid://125270540000651",
			side = "rbxassetid://74397475943828",
			all = "rbxassetid://74397475943828"
		},
		crossShape = false
	},
	[Constants.BlockType.CRIMSON_PLANKS] = {
		name = "Crimson Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(101, 48, 70),
		textures = { all = "rbxassetid://91916919581806" },
		crossShape = false
	},
	[Constants.BlockType.WARPED_PLANKS] = {
		name = "Warped Planks",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(43, 105, 99),
		textures = { all = "rbxassetid://118059443047835" },
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_CRIMSON_STEM] = {
		name = "Stripped Crimson Stem",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(137, 57, 90),
		textures = {
			top = "rbxassetid://129194372797805",
			bottom = "rbxassetid://129194372797805",
			side = "rbxassetid://74759388892088",
			all = "rbxassetid://74759388892088"
		},
		crossShape = false
	},
	[Constants.BlockType.STRIPPED_WARPED_STEM] = {
		name = "Stripped Warped Stem",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(57, 150, 147),
		textures = {
			top = "rbxassetid://132310236236978",
			bottom = "rbxassetid://132310236236978",
			side = "rbxassetid://76554799409444",
			all = "rbxassetid://76554799409444"
		},
		crossShape = false
	},
	[Constants.BlockType.CRIMSON_NYLIUM] = {
		name = "Crimson Nylium",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(130, 31, 31),
		textures = {
			top = "rbxassetid://83259084292401",
			bottom = "rbxassetid://107740562127200",
			side = "rbxassetid://107740562127200",
			all = "rbxassetid://107740562127200"
		},
		crossShape = false
	},
	[Constants.BlockType.WARPED_NYLIUM] = {
		name = "Warped Nylium",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(43, 114, 101),
		textures = {
			top = "rbxassetid://83259084292401",
			bottom = "rbxassetid://107740562127200",
			side = "rbxassetid://107740562127200",
			all = "rbxassetid://107740562127200"
		},
		crossShape = false
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ADDITIONAL UTILITY BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════
	[Constants.BlockType.CAULDRON] = {
		name = "Cauldron",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(73, 73, 73),
		textures = {
			top = "rbxassetid://133845825728368",
			bottom = "rbxassetid://75000267472243",
			side = "rbxassetid://75129759837324",
			all = "rbxassetid://75129759837324"
		},
		crossShape = false
	},
	[Constants.BlockType.ANVIL] = {
		name = "Anvil",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(73, 73, 73),
		textures = {
			top = "rbxassetid://93850827330617",
			bottom = "rbxassetid://93850827330617",
			side = "rbxassetid://113323068322069",
			all = "rbxassetid://113323068322069"
		},
		crossShape = false,
		hasRotation = true
	},
	[Constants.BlockType.BREWING_STAND] = {
		name = "Brewing Stand",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 139, 129),
		textures = {
			top = "rbxassetid://85702259653816",
			bottom = "rbxassetid://91881858143089",
			side = "rbxassetid://85702259653816",
			all = "rbxassetid://85702259653816"
		},
		crossShape = true,
		interactable = true
	},
	[Constants.BlockType.ENCHANTING_TABLE] = {
		name = "Enchanting Table",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(114, 20, 20),
		textures = {
			top = "rbxassetid://102192486725769",
			bottom = "rbxassetid://78755549354143",
			side = "rbxassetid://140224980615436",
			all = "rbxassetid://140224980615436"
		},
		crossShape = false,
		interactable = true
	},
	[Constants.BlockType.BEACON] = {
		name = "Beacon",
		solid = true,
		transparent = true,
		color = Color3.fromRGB(117, 225, 215),
		textures = { all = "rbxassetid://124890497501415" },
		crossShape = false
	},
	[Constants.BlockType.REDSTONE_LAMP] = {
		name = "Redstone Lamp",
		solid = true,
		transparent = false,
		color = Color3.fromRGB(100, 60, 30),
		textures = { all = "rbxassetid://106914203863166" },
		crossShape = false
	},
	[Constants.BlockType.LANTERN] = {
		name = "Lantern",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(198, 137, 68),
		textures = { all = "rbxassetid://91918732182012" },
		crossShape = true
	},
	[Constants.BlockType.SOUL_LANTERN] = {
		name = "Soul Lantern",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(70, 185, 186),
		textures = { all = "rbxassetid://91918732182012" },
		crossShape = true
	},

	-- ═══════════════════════════════════════════════════════════════════════
	-- FOOD ITEMS (Consumables)
	-- ═══════════════════════════════════════════════════════════════════════

	-- Cooked Foods
	[Constants.BlockType.BREAD] = {
		name = "Bread",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(184, 135, 70),
		textures = { all = "rbxassetid://131410059829657" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.BAKED_POTATO] = {
		name = "Baked Potato",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 170, 100),
		textures = { all = "rbxassetid://103980797376124" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_BEEF] = {
		name = "Cooked Beef",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 69, 19),
		textures = { all = "rbxassetid://79908571442121" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_PORKCHOP] = {
		name = "Cooked Porkchop",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(205, 133, 63),
		textures = { all = "rbxassetid://115315254549034" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_CHICKEN] = {
		name = "Cooked Chicken",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(210, 160, 120),
		textures = { all = "rbxassetid://77712459701601" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_MUTTON] = {
		name = "Cooked Mutton",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(160, 82, 45),
		textures = { all = "rbxassetid://81818298886774" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_RABBIT] = {
		name = "Cooked Rabbit",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 90, 43),
		textures = { all = "rbxassetid://79254327247389" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_COD] = {
		name = "Cooked Cod",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(210, 180, 140),
		textures = { all = "rbxassetid://87086493517889" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.COOKED_SALMON] = {
		name = "Cooked Salmon",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(233, 150, 122),
		textures = { all = "rbxassetid://91129262883588" },
		crossShape = true,
		isFood = true
	},

	-- Raw Meats
	[Constants.BlockType.BEEF] = {
		name = "Raw Beef",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(178, 34, 34),
		textures = { all = "rbxassetid://116785591355645" }, -- Note: 3D model may not have texture, this is fallback
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.PORKCHOP] = {
		name = "Raw Porkchop",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 182, 193),
		textures = { all = "rbxassetid://111259766103163" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.CHICKEN] = {
		name = "Raw Chicken",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 218, 185),
		textures = { all = "rbxassetid://81854557076270" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.MUTTON] = {
		name = "Raw Mutton",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(205, 92, 92),
		textures = { all = "rbxassetid://72210947514718" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.RABBIT] = {
		name = "Raw Rabbit",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(210, 105, 30),
		textures = { all = "rbxassetid://119792692352396" },
		crossShape = true,
		isFood = true
	},

	-- Raw Fish
	[Constants.BlockType.COD] = {
		name = "Raw Cod",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(159, 182, 205),
		textures = { all = "rbxassetid://107632079015450" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.SALMON] = {
		name = "Raw Salmon",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(250, 128, 114),
		textures = { all = "rbxassetid://123844273363430" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.TROPICAL_FISH] = {
		name = "Tropical Fish",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 215, 0),
		textures = { all = "rbxassetid://119955336595901" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.PUFFERFISH] = {
		name = "Pufferfish",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 223, 0),
		textures = { all = "rbxassetid://92689876748346" },
		crossShape = true,
		isFood = true
	},

	-- Special Foods
	[Constants.BlockType.GOLDEN_APPLE] = {
		name = "Golden Apple",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 215, 0),
		textures = { all = "rbxassetid://135539741184385" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.ENCHANTED_GOLDEN_APPLE] = {
		name = "Enchanted Golden Apple",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 215, 0),
		textures = { all = "rbxassetid://135539741184385" }, -- Same as Golden Apple
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.GOLDEN_CARROT] = {
		name = "Golden Carrot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 215, 0),
		textures = { all = "rbxassetid://75127823784496" },
		crossShape = true,
		isFood = true
	},

	-- Soups & Stews
	[Constants.BlockType.BEETROOT_SOUP] = {
		name = "Beetroot Soup",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 0, 0),
		textures = { all = "rbxassetid://113501364634330" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.MUSHROOM_STEW] = {
		name = "Mushroom Stew",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 90, 43),
		textures = { all = "rbxassetid://124557852315892" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.RABBIT_STEW] = {
		name = "Rabbit Stew",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(160, 82, 45),
		textures = { all = "rbxassetid://74588806705549" },
		crossShape = true,
		isFood = true
	},

	-- Other Foods
	[Constants.BlockType.COOKIE] = {
		name = "Cookie",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(210, 180, 140),
		textures = { all = "rbxassetid://91659608407481" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.MELON_SLICE] = {
		name = "Melon Slice",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(255, 99, 71),
		textures = { all = "rbxassetid://70849803699595" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.DRIED_KELP] = {
		name = "Dried Kelp",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(34, 139, 34),
		textures = { all = "rbxassetid://95948620428069" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.PUMPKIN_PIE] = {
		name = "Pumpkin Pie",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(210, 105, 30),
		textures = { all = "rbxassetid://71957804042480" },
		crossShape = true,
		isFood = true
	},

	-- Hazardous Foods
	[Constants.BlockType.ROTTEN_FLESH] = {
		name = "Rotten Flesh",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 69, 19),
		textures = { all = "rbxassetid://109761141356633" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.SPIDER_EYE] = {
		name = "Spider Eye",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(139, 0, 0),
		textures = { all = "rbxassetid://91726041904711" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.POISONOUS_POTATO] = {
		name = "Poisonous Potato",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(154, 205, 50),
		textures = { all = "rbxassetid://82437405960125" },
		crossShape = true,
		isFood = true
	},
	[Constants.BlockType.CHORUS_FRUIT] = {
		name = "Chorus Fruit",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(186, 85, 211),
		textures = { all = "rbxassetid://76192554744450" },
		crossShape = true,
		isFood = true
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

-- Check if block is a liquid
function BlockRegistry:IsLiquid(blockId: number): boolean
	local block = self:GetBlock(blockId)
	return block.liquid == true
end

-- Check if block is replaceable (air, etc)
function BlockRegistry:IsReplaceable(blockId: number): boolean
	if blockId == Constants.BlockType.AIR then
		return true
	end
	local block = self:GetBlock(blockId)
	return block.replaceable == true
end

-- Determine if a block/item is allowed to be placed in the world
function BlockRegistry:IsPlaceable(blockId: number): boolean
    if not blockId or blockId == Constants.BlockType.AIR then
        return false
    end

    local block = self:GetBlock(blockId)

    -- Unknown definitions are never placeable
    if block.name == "Unknown" then
        return false
    end

    -- Crafting-only materials are not placeable (e.g., sticks, ingots, gems, apples)
    if block.craftingMaterial == true then
        return false
    end

    -- Cross-shaped visuals are placeable only for actual plants/saplings (not items)
    if block.crossShape == true then
        local t = Constants.BlockType
        if blockId == t.TALL_GRASS
            or blockId == t.FLOWER
            or blockId == t.OAK_SAPLING
            or blockId == t.SPRUCE_SAPLING
            or blockId == t.JUNGLE_SAPLING
            or blockId == t.DARK_OAK_SAPLING
            or blockId == t.BIRCH_SAPLING
            or blockId == t.ACACIA_SAPLING
        then
            return true
        end

        -- Everything else that is cross-shaped (seeds, produce, loose items) is not placeable
        return false
    end

    -- All other block shapes (solid cubes, stairs, slabs, fences, interactables) are placeable
    return true
end

return BlockRegistry