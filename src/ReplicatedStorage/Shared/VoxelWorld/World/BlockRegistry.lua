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
			all = "rbxassetid://107743228743622"
		},
		crossShape = true,
		craftingMaterial = true
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
		textures = { all = "rbxassetid://87026885464531" },
		crossShape = true
	},
	[Constants.BlockType.WHEAT] = {
		name = "Wheat",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(230, 210, 140),
		textures = { all = "rbxassetid://129655035000946" },
		crossShape = true
	},
	[Constants.BlockType.POTATO] = {
		name = "Potato",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 170, 120),
		textures = { all = "rbxassetid://102603334676051" },
		crossShape = true
	},
	[Constants.BlockType.CARROT] = {
		name = "Carrot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(240, 150, 80),
		textures = { all = "rbxassetid://111539451283086" },
		crossShape = true
	},
	[Constants.BlockType.BEETROOT_SEEDS] = {
		name = "Beetroot Seeds",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 200, 200),
		textures = { all = "rbxassetid://84894596040373" },
		crossShape = true
	},
	[Constants.BlockType.BEETROOT] = {
		name = "Beetroot",
		solid = false,
		transparent = true,
		color = Color3.fromRGB(200, 50, 80),
		textures = { all = "rbxassetid://98898799067872" },
		crossShape = true
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