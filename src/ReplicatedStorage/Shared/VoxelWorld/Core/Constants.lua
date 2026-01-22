--[[
	Constants.lua
	Core constants for the voxel world system
]]

local Constants = {
	-- Chunk dimensions
	CHUNK_SIZE_X = 16,
    CHUNK_SIZE_Y = 256,  -- Increased for taller schematics
	CHUNK_SIZE_Z = 16,

	-- Section dimensions
	CHUNK_SECTION_SIZE = 16,

	-- World limits
    WORLD_HEIGHT = 256,  -- Increased for taller schematics
	MIN_HEIGHT = 0,

	-- Block size in studs
	BLOCK_SIZE = 3,

	-- Chunk states
	ChunkState = {
		EMPTY = "EMPTY",
		GENERATING = "GENERATING",
		READY = "READY",
		LOADED = "LOADED"
	},

	-- Block types
	BlockType = {
		AIR = 0,
		GRASS = 1,
		DIRT = 2,
		STONE = 3,
		BEDROCK = 4,
		WOOD = 5,
		LEAVES = 6,
		TALL_GRASS = 7,
		FLOWER = 8,
		CHEST = 9,
		SAND = 10,
		STONE_BRICKS = 11,
		OAK_PLANKS = 12,
		CRAFTING_TABLE = 13,
		COBBLESTONE = 14,
		BRICKS = 15,
		OAK_SAPLING = 16,
		-- Staircase blocks (rotation stored in metadata)
		OAK_STAIRS = 17,
		STONE_STAIRS = 18,
		COBBLESTONE_STAIRS = 19,
		STONE_BRICK_STAIRS = 20,
		BRICK_STAIRS = 21,
		-- Slab blocks (half-height blocks)
		OAK_SLAB = 22,
		STONE_SLAB = 23,
		COBBLESTONE_SLAB = 24,
		STONE_BRICK_SLAB = 25,
		BRICK_SLAB = 26,
		-- Fences
		OAK_FENCE = 27,
		-- Crafting materials
		STICK = 28,
		-- Ores
		COAL_ORE = 29,
		IRON_ORE = 30,
		DIAMOND_ORE = 31,
		-- Refined materials
		COAL = 32,
		IRON_INGOT = 33,
		DIAMOND = 34,
		-- Utility blocks
		FURNACE = 35,
		GLASS = 36,
		APPLE = 37,

		-- New wood families
		SPRUCE_LOG = 38,
		SPRUCE_PLANKS = 39,
		SPRUCE_SAPLING = 40,
		SPRUCE_STAIRS = 41,
		SPRUCE_SLAB = 42,

		JUNGLE_LOG = 43,
		JUNGLE_PLANKS = 44,
		JUNGLE_SAPLING = 45,
		JUNGLE_STAIRS = 46,
		JUNGLE_SLAB = 47,

		DARK_OAK_LOG = 48,
		DARK_OAK_PLANKS = 49,
		DARK_OAK_SAPLING = 50,
		DARK_OAK_STAIRS = 51,
		DARK_OAK_SLAB = 52,

		BIRCH_LOG = 53,
		BIRCH_PLANKS = 54,
		BIRCH_SAPLING = 55,
		BIRCH_STAIRS = 56,
		BIRCH_SLAB = 57,

		ACACIA_LOG = 58,
		ACACIA_PLANKS = 59,
		ACACIA_SAPLING = 60,
		ACACIA_STAIRS = 61,
		ACACIA_SLAB = 62
		,

		-- Leaf variants per wood family
		OAK_LEAVES = 63,
		SPRUCE_LEAVES = 64,
		JUNGLE_LEAVES = 65,
		DARK_OAK_LEAVES = 66,
		BIRCH_LEAVES = 67,
		ACACIA_LEAVES = 68
		,

		-- Farming blocks and items
		FARMLAND = 69,
		WHEAT_SEEDS = 70,
		WHEAT = 71,
		POTATO = 72,
		CARROT = 73,
		BEETROOT_SEEDS = 74,
		BEETROOT = 75,

		-- Crop stages (cross-shaped plants)
		WHEAT_CROP_0 = 76,
		WHEAT_CROP_1 = 77,
		WHEAT_CROP_2 = 78,
		WHEAT_CROP_3 = 79,
		WHEAT_CROP_4 = 80,
		WHEAT_CROP_5 = 81,
		WHEAT_CROP_6 = 82,
		WHEAT_CROP_7 = 83,

		POTATO_CROP_0 = 84,
		POTATO_CROP_1 = 85,
		POTATO_CROP_2 = 86,
		POTATO_CROP_3 = 87,

		CARROT_CROP_0 = 88,
		CARROT_CROP_1 = 89,
		CARROT_CROP_2 = 90,
		CARROT_CROP_3 = 91,

		BEETROOT_CROP_0 = 92,
		BEETROOT_CROP_1 = 93,
		BEETROOT_CROP_2 = 94,
		BEETROOT_CROP_3 = 95,

		-- Compost item (used to convert grass/dirt to farmland)
		COMPOST = 96,

		-- Utility: visual minion blocks (spawn a mini zombie)
		COBBLESTONE_MINION = 97,
		COAL_MINION = 123,

		-- Ores (6-tier progression: Copper → Iron → Steel → Bluesteel → Tungsten → Titanium)
		COPPER_ORE = 98,
		BLUESTEEL_ORE = 101,   -- Tier 4 ore (drops Bluesteel Dust)
		TUNGSTEN_ORE = 102,    -- Tier 5 ore
		TITANIUM_ORE = 103,    -- Tier 6 ore

		-- Ingots/materials
		COPPER_INGOT = 105,
		STEEL_INGOT = 108,     -- Alloy: Iron + 2 Coal
		BLUESTEEL_INGOT = 109, -- Tier 4 ingot (Iron + 3 Coal + Bluesteel Dust)
		TUNGSTEN_INGOT = 110,  -- Tier 5 ingot
		TITANIUM_INGOT = 111,  -- Tier 6 ingot
		BLUESTEEL_DUST = 115,  -- Drops from Bluesteel Ore

		-- Full Blocks (9x ingots/items)
		COPPER_BLOCK = 116,
		COAL_BLOCK = 117,
		IRON_BLOCK = 118,
		STEEL_BLOCK = 119,
		BLUESTEEL_BLOCK = 120,
		TUNGSTEN_BLOCK = 121,
		TITANIUM_BLOCK = 122,

		-- Stained Glass blocks (16 colors)
		WHITE_STAINED_GLASS = 123,
		ORANGE_STAINED_GLASS = 124,
		MAGENTA_STAINED_GLASS = 125,
		LIGHT_BLUE_STAINED_GLASS = 126,
		YELLOW_STAINED_GLASS = 127,
		LIME_STAINED_GLASS = 128,
		PINK_STAINED_GLASS = 129,
		GRAY_STAINED_GLASS = 130,
		LIGHT_GRAY_STAINED_GLASS = 131,
		CYAN_STAINED_GLASS = 132,
		PURPLE_STAINED_GLASS = 133,
		BLUE_STAINED_GLASS = 134,
		BROWN_STAINED_GLASS = 135,
		GREEN_STAINED_GLASS = 136,
		RED_STAINED_GLASS = 137,
		BLACK_STAINED_GLASS = 138,

		-- Terracotta blocks (17 colors)
		TERRACOTTA = 139,
		WHITE_TERRACOTTA = 140,
		ORANGE_TERRACOTTA = 141,
		MAGENTA_TERRACOTTA = 142,
		LIGHT_BLUE_TERRACOTTA = 143,
		YELLOW_TERRACOTTA = 144,
		LIME_TERRACOTTA = 145,
		PINK_TERRACOTTA = 146,
		GRAY_TERRACOTTA = 147,
		LIGHT_GRAY_TERRACOTTA = 148,
		CYAN_TERRACOTTA = 149,
		PURPLE_TERRACOTTA = 150,
		BLUE_TERRACOTTA = 151,
		BROWN_TERRACOTTA = 152,
		GREEN_TERRACOTTA = 153,
		RED_TERRACOTTA = 154,
		BLACK_TERRACOTTA = 155,

		-- Wool blocks (16 colors)
		WHITE_WOOL = 156,
		ORANGE_WOOL = 157,
		MAGENTA_WOOL = 158,
		LIGHT_BLUE_WOOL = 159,
		YELLOW_WOOL = 160,
		LIME_WOOL = 161,
		PINK_WOOL = 162,
		GRAY_WOOL = 163,
		LIGHT_GRAY_WOOL = 164,
		CYAN_WOOL = 165,
		PURPLE_WOOL = 166,
		BLUE_WOOL = 167,
		BROWN_WOOL = 168,
		GREEN_WOOL = 169,
		RED_WOOL = 170,
		BLACK_WOOL = 171,

		-- Additional blocks
		NETHER_BRICKS = 172,
		GRAVEL = 173,
		COARSE_DIRT = 174,

		-- Stone variants
		SANDSTONE = 175,
		DIORITE = 176,
		POLISHED_DIORITE = 177,
		ANDESITE = 178,
		POLISHED_ANDESITE = 179,

		-- Concrete blocks (16 colors)
		WHITE_CONCRETE = 180,
		ORANGE_CONCRETE = 181,
		MAGENTA_CONCRETE = 182,
		LIGHT_BLUE_CONCRETE = 183,
		YELLOW_CONCRETE = 184,
		LIME_CONCRETE = 185,
		PINK_CONCRETE = 186,
		GRAY_CONCRETE = 187,
		LIGHT_GRAY_CONCRETE = 188,
		CYAN_CONCRETE = 189,
		PURPLE_CONCRETE = 190,
		BLUE_CONCRETE = 191,
		BROWN_CONCRETE = 192,
		GREEN_CONCRETE = 193,
		RED_CONCRETE = 194,
		BLACK_CONCRETE = 195,

		-- Concrete powder blocks (16 colors)
		WHITE_CONCRETE_POWDER = 196,
		ORANGE_CONCRETE_POWDER = 197,
		MAGENTA_CONCRETE_POWDER = 198,
		LIGHT_BLUE_CONCRETE_POWDER = 199,
		YELLOW_CONCRETE_POWDER = 200,
		LIME_CONCRETE_POWDER = 201,
		PINK_CONCRETE_POWDER = 202,
		GRAY_CONCRETE_POWDER = 203,
		LIGHT_GRAY_CONCRETE_POWDER = 204,
		CYAN_CONCRETE_POWDER = 205,
		PURPLE_CONCRETE_POWDER = 206,
		BLUE_CONCRETE_POWDER = 207,
		BROWN_CONCRETE_POWDER = 208,
		GREEN_CONCRETE_POWDER = 209,
		RED_CONCRETE_POWDER = 210,
		BLACK_CONCRETE_POWDER = 211,

		-- Additional stair types (using textures from base blocks)
		ANDESITE_STAIRS = 212,
		DIORITE_STAIRS = 213,
		SANDSTONE_STAIRS = 214,
		NETHER_BRICK_STAIRS = 215,

		-- Quartz blocks
		QUARTZ_BLOCK = 216,
		QUARTZ_PILLAR = 217,
		CHISELED_QUARTZ_BLOCK = 218,
		QUARTZ_STAIRS = 219,

		-- Blackstone (uses bedrock texture)
		BLACKSTONE = 220,

		-- Granite blocks
		GRANITE = 221,
		POLISHED_GRANITE = 222,
		GRANITE_STAIRS = 224,

		-- Podzol
		PODZOL = 223,

		-- Additional slab types (using textures from base blocks)
		GRANITE_SLAB = 225,
		BLACKSTONE_SLAB = 226,
		SMOOTH_QUARTZ_SLAB = 227,

		-- ═══════════════════════════════════════════════════════════════════════
		-- ICE VARIANTS
		-- ═══════════════════════════════════════════════════════════════════════
		ICE = 228,
		PACKED_ICE = 229,
		BLUE_ICE = 230,

		-- ═══════════════════════════════════════════════════════════════════════
		-- SNOW & SPONGE
		-- ═══════════════════════════════════════════════════════════════════════
		SNOW_BLOCK = 231,
		SPONGE = 232,
		WET_SPONGE = 233,

		-- ═══════════════════════════════════════════════════════════════════════
		-- NETHER BLOCKS
		-- ═══════════════════════════════════════════════════════════════════════
		NETHERRACK = 234,
		SOUL_SAND = 235,
		MAGMA_BLOCK = 236,
		GLOWSTONE = 237,
		NETHER_WART_BLOCK = 238,
		RED_NETHER_BRICKS = 239,

		-- ═══════════════════════════════════════════════════════════════════════
		-- OCEAN & PRISMARINE
		-- ═══════════════════════════════════════════════════════════════════════
		SEA_LANTERN = 240,
		PRISMARINE = 241,
		PRISMARINE_BRICKS = 242,
		DARK_PRISMARINE = 243,

		-- ═══════════════════════════════════════════════════════════════════════
		-- END BLOCKS (Purpur)
		-- ═══════════════════════════════════════════════════════════════════════
		PURPUR_BLOCK = 244,
		PURPUR_PILLAR = 245,
		END_STONE = 246,
		END_STONE_BRICKS = 247,

		-- ═══════════════════════════════════════════════════════════════════════
		-- PLANTS & VEGETATION
		-- ═══════════════════════════════════════════════════════════════════════
		MELON = 248,
		PUMPKIN = 249,
		CARVED_PUMPKIN = 250,
		JACK_O_LANTERN = 251,
		CACTUS = 252,
		SUGAR_CANE = 253,
		HAY_BLOCK = 254,
		DEAD_BUSH = 255,
		LILY_PAD = 256,

		-- ═══════════════════════════════════════════════════════════════════════
		-- MUSHROOM BLOCKS
		-- ═══════════════════════════════════════════════════════════════════════
		BROWN_MUSHROOM = 257,
		RED_MUSHROOM = 258,
		BROWN_MUSHROOM_BLOCK = 259,
		RED_MUSHROOM_BLOCK = 260,
		MUSHROOM_STEM = 261,

		-- ═══════════════════════════════════════════════════════════════════════
		-- UTILITY & DECORATION
		-- ═══════════════════════════════════════════════════════════════════════
		SLIME_BLOCK = 262,
		HONEY_BLOCK = 263,
		BONE_BLOCK = 264,
		COBWEB = 265,
		BOOKSHELF = 266,
		JUKEBOX = 267,
		NOTE_BLOCK = 268,
		TNT = 269,
		SPAWNER = 270,
		OBSIDIAN = 271,
		DRIED_KELP_BLOCK = 272,

		-- ═══════════════════════════════════════════════════════════════════════
		-- STONE VARIANTS (additional)
		-- ═══════════════════════════════════════════════════════════════════════
		SMOOTH_STONE = 273,
		MOSSY_COBBLESTONE = 274,
		MOSSY_STONE_BRICKS = 275,
		CRACKED_STONE_BRICKS = 276,
		CHISELED_STONE_BRICKS = 277,
		MYCELIUM = 278,
		CLAY_BLOCK = 279,

		-- ═══════════════════════════════════════════════════════════════════════
		-- SANDSTONE VARIANTS
		-- ═══════════════════════════════════════════════════════════════════════
		RED_SANDSTONE = 280,
		RED_SAND = 281,
		CUT_SANDSTONE = 282,
		CHISELED_SANDSTONE = 283,
		SMOOTH_SANDSTONE = 284,
		CUT_RED_SANDSTONE = 285,
		CHISELED_RED_SANDSTONE = 286,
		SMOOTH_RED_SANDSTONE = 287,

		-- ═══════════════════════════════════════════════════════════════════════
		-- STRIPPED LOGS (6 wood types)
		-- ═══════════════════════════════════════════════════════════════════════
		STRIPPED_OAK_LOG = 288,
		STRIPPED_SPRUCE_LOG = 289,
		STRIPPED_BIRCH_LOG = 290,
		STRIPPED_JUNGLE_LOG = 291,
		STRIPPED_ACACIA_LOG = 292,
		STRIPPED_DARK_OAK_LOG = 293,

		-- ═══════════════════════════════════════════════════════════════════════
		-- COPPER VARIANTS
		-- ═══════════════════════════════════════════════════════════════════════
		CUT_COPPER = 294,
		EXPOSED_COPPER = 295,
		WEATHERED_COPPER = 296,
		OXIDIZED_COPPER = 297,

		-- ═══════════════════════════════════════════════════════════════════════
		-- DEEPSLATE & TUFF
		-- ═══════════════════════════════════════════════════════════════════════
		DEEPSLATE = 298,
		COBBLED_DEEPSLATE = 299,
		POLISHED_DEEPSLATE = 300,
		DEEPSLATE_BRICKS = 301,
		DEEPSLATE_TILES = 302,
		TUFF = 303,
		CALCITE = 304,

		-- ═══════════════════════════════════════════════════════════════════════
		-- AMETHYST
		-- ═══════════════════════════════════════════════════════════════════════
		AMETHYST_BLOCK = 305,
		BUDDING_AMETHYST = 306,

		-- ═══════════════════════════════════════════════════════════════════════
		-- BASALT
		-- ═══════════════════════════════════════════════════════════════════════
		BASALT = 307,
		POLISHED_BASALT = 308,
		SMOOTH_BASALT = 309,

		-- ═══════════════════════════════════════════════════════════════════════
		-- MISC BLOCKS
		-- ═══════════════════════════════════════════════════════════════════════
		CRYING_OBSIDIAN = 310,
		SHROOMLIGHT = 311,
		WARPED_WART_BLOCK = 312,
		SOUL_SOIL = 313,
		NETHER_GOLD_ORE = 314,
		ANCIENT_DEBRIS = 315,
		LODESTONE = 316,
		RESPAWN_ANCHOR = 317,
		CHAIN = 318,

		-- ═══════════════════════════════════════════════════════════════════════
		-- SCULK (Deep Dark)
		-- ═══════════════════════════════════════════════════════════════════════
		SCULK = 319,
		SCULK_CATALYST = 320,
		REINFORCED_DEEPSLATE = 321,

		-- ═══════════════════════════════════════════════════════════════════════
		-- MANGROVE & MUD
		-- ═══════════════════════════════════════════════════════════════════════
		MUD = 322,
		PACKED_MUD = 323,
		MUD_BRICKS = 324,
		MANGROVE_LOG = 325,
		MANGROVE_PLANKS = 326,
		STRIPPED_MANGROVE_LOG = 327,
		MANGROVE_LEAVES = 328,

		-- ═══════════════════════════════════════════════════════════════════════
		-- MOSS & DRIPSTONE
		-- ═══════════════════════════════════════════════════════════════════════
		MOSS_BLOCK = 329,
		MOSS_CARPET = 330,
		DRIPSTONE_BLOCK = 331,

		-- ═══════════════════════════════════════════════════════════════════════
		-- CRIMSON & WARPED (Nether Wood)
		-- ═══════════════════════════════════════════════════════════════════════
		CRIMSON_STEM = 332,
		WARPED_STEM = 333,
		CRIMSON_PLANKS = 334,
		WARPED_PLANKS = 335,
		STRIPPED_CRIMSON_STEM = 336,
		STRIPPED_WARPED_STEM = 337,
		CRIMSON_NYLIUM = 338,
		WARPED_NYLIUM = 339,

		-- ═══════════════════════════════════════════════════════════════════════
		-- ADDITIONAL UTILITY
		-- ═══════════════════════════════════════════════════════════════════════
		CAULDRON = 340,
		ANVIL = 341,
		BREWING_STAND = 342,
		ENCHANTING_TABLE = 343,
		BEACON = 344,
		REDSTONE_LAMP = 345,
		LANTERN = 346,
		SOUL_LANTERN = 347,

		-- ═══════════════════════════════════════════════════════════════════════
		-- FOOD ITEMS (Minecraft-style consumables)
		-- ═══════════════════════════════════════════════════════════════════════
		-- Cooked Foods
		BREAD = 348,
		BAKED_POTATO = 349,
		COOKED_BEEF = 350,
		COOKED_PORKCHOP = 351,
		COOKED_CHICKEN = 352,
		COOKED_MUTTON = 353,
		COOKED_RABBIT = 354,
		COOKED_COD = 355,
		COOKED_SALMON = 356,

		-- Raw Meats
		BEEF = 357,
		PORKCHOP = 358,
		CHICKEN = 359,
		MUTTON = 360,
		RABBIT = 361,

		-- Raw Fish
		COD = 362,
		SALMON = 363,
		TROPICAL_FISH = 364,
		PUFFERFISH = 365,

		-- Special Foods
		GOLDEN_APPLE = 366,
		ENCHANTED_GOLDEN_APPLE = 367,
		GOLDEN_CARROT = 368,

		-- Soups & Stews
		BEETROOT_SOUP = 369,
		MUSHROOM_STEW = 370,
		RABBIT_STEW = 371,

		-- Other Foods
		COOKIE = 372,
		MELON_SLICE = 373,
		DRIED_KELP = 374,
		PUMPKIN_PIE = 375,

		-- Hazardous Foods
		ROTTEN_FLESH = 376,
		SPIDER_EYE = 377,
		POISONOUS_POTATO = 378,
		CHORUS_FRUIT = 379,

		-- Liquids
		WATER_SOURCE = 380,
		FLOWING_WATER = 381

		-- Note: Block IDs continue from 382+
	},

	-- Mapping: Slab block ID → Full block ID (when two slabs combine)
	SlabToFullBlock = {
		[22] = 12,  -- OAK_SLAB → OAK_PLANKS
		[23] = 3,   -- STONE_SLAB → STONE
		[24] = 14,  -- COBBLESTONE_SLAB → COBBLESTONE
		[25] = 11,  -- STONE_BRICK_SLAB → STONE_BRICKS
		[26] = 15,  -- BRICK_SLAB → BRICKS
		[42] = 39,  -- SPRUCE_SLAB → SPRUCE_PLANKS
		[47] = 44,  -- JUNGLE_SLAB → JUNGLE_PLANKS
		[52] = 49,  -- DARK_OAK_SLAB → DARK_OAK_PLANKS
		[57] = 54,  -- BIRCH_SLAB → BIRCH_PLANKS
		[62] = 59,  -- ACACIA_SLAB → ACACIA_PLANKS
		[225] = 221,  -- GRANITE_SLAB → GRANITE
		[226] = 220,  -- BLACKSTONE_SLAB → BLACKSTONE
		[227] = 216,  -- SMOOTH_QUARTZ_SLAB → QUARTZ_BLOCK
	},

	-- Reverse mapping: Full block ID → Slab ID (what to drop when broken)
	FullBlockToSlab = {
		[12] = 22,  -- OAK_PLANKS → OAK_SLAB
		[3] = 23,   -- STONE → STONE_SLAB
		[14] = 24,  -- COBBLESTONE → COBBLESTONE_SLAB
		[11] = 25,  -- STONE_BRICKS → STONE_BRICK_SLAB
		[15] = 26,  -- BRICKS → BRICK_SLAB
		[39] = 42,  -- SPRUCE_PLANKS → SPRUCE_SLAB
		[44] = 47,  -- JUNGLE_PLANKS → JUNGLE_SLAB
		[49] = 52,  -- DARK_OAK_PLANKS → DARK_OAK_SLAB
		[54] = 57,  -- BIRCH_PLANKS → BIRCH_SLAB
		[59] = 62,  -- ACACIA_PLANKS → ACACIA_SLAB
		[221] = 225,  -- GRANITE → GRANITE_SLAB
		[220] = 226,  -- BLACKSTONE → BLACKSTONE_SLAB
		[216] = 227,  -- QUARTZ_BLOCK → SMOOTH_QUARTZ_SLAB
	},

	-- Mapping: Ore block ID → Material item ID (what to drop when mined)
	OreToMaterial = {
		[29] = 32,   -- COAL_ORE → COAL (drops coal item)
		[30] = 30,   -- IRON_ORE → IRON_ORE (needs smelting)
		[98] = 98,   -- COPPER_ORE → COPPER_ORE (needs smelting)
		[101] = 115, -- BLUESTEEL_ORE → BLUESTEEL_DUST (drops dust item)
		[102] = 102, -- TUNGSTEN_ORE → TUNGSTEN_ORE (needs smelting)
		[103] = 103, -- TITANIUM_ORE → TITANIUM_ORE (needs smelting)
	},

	-- Mapping: Block ID → Drop item ID (blocks that transform when broken)
	BlockToDrop = {
		[3] = 14,   -- STONE → COBBLESTONE
	},

	-- ═══════════════════════════════════════════════════════════════════════
	-- FLOWER VARIANTS
	-- ═══════════════════════════════════════════════════════════════════════
	-- All flowers map to BlockType.FLOWER (ID 8) but use different textures
	-- This table maps Minecraft flower names to variant identifiers
	FlowerVariants = {
		-- Single-block tall flowers (use top texture only)
		POPPY = "poppy",
		AZURE_BLUET = "azure_bluet",
		DANDELION = "poppy",  -- Uses poppy texture (needs separate texture)
		BLUE_ORCHID = "poppy",  -- Uses poppy texture (needs separate texture)
		CORNFLOWER = "poppy",  -- Uses poppy texture (needs separate texture)
		LILY_OF_THE_VALLEY = "poppy",  -- Uses poppy texture (needs separate texture)
		OXEYE_DAISY = "poppy",  -- Uses poppy texture (needs separate texture)
		ORANGE_TULIP = "poppy",  -- Uses poppy texture (needs separate texture)
		PINK_TULIP = "poppy",  -- Uses poppy texture (needs separate texture)
		RED_TULIP = "poppy",  -- Uses poppy texture (needs separate texture)
		WHITE_TULIP = "poppy",  -- Uses poppy texture (needs separate texture)
		WITHER_ROSE = "poppy",  -- Uses poppy texture (needs separate texture)
		-- Two-block tall flowers (use top texture for lower half, bottom texture for upper half)
		ROSE_BUSH = "rose_bush",
		LILAC = "lilac",
		PEONY = "lilac",  -- Uses lilac texture (needs separate texture)
		SUNFLOWER = "lilac",  -- Uses lilac texture (needs separate texture)
		AZALEA = "poppy",  -- Uses poppy texture (needs separate texture)
		FLOWERING_AZALEA = "poppy",  -- Uses poppy texture (needs separate texture)
	},
	-- Flowers that are two blocks tall (need bottom texture for upper half)
	TwoBlockTallFlowers = {
		["rose_bush"] = true,
		["lilac"] = true,
	},

	-- Block metadata format (single byte: 0-255)
	BlockMetadata = {
		-- Bits 0-1: Horizontal rotation (4 directions)
		ROTATION_MASK = 3,  -- 0b00000011
		ROTATION_NORTH = 0,  -- 0b00 (faces +Z)
		ROTATION_EAST = 1,   -- 0b01 (faces +X)
		ROTATION_SOUTH = 2,  -- 0b10 (faces -Z)
		ROTATION_WEST = 3,   -- 0b11 (faces -X)

		-- Bits 2-3: Vertical orientation (for stairs - upside down)
		VERTICAL_MASK = 12,  -- 0b00001100
		VERTICAL_BOTTOM = 0,
		VERTICAL_TOP = 4,

		-- Bits 4-6: Stair shape (Minecraft parity)
		SHAPE_MASK = 112, -- 0b01110000
		SHAPE_SHIFT = 4,
		STAIR_SHAPE_STRAIGHT = 0,
		STAIR_SHAPE_OUTER_LEFT = 1,
		STAIR_SHAPE_OUTER_RIGHT = 2,
		STAIR_SHAPE_INNER_LEFT = 3,
		STAIR_SHAPE_INNER_RIGHT = 4,

		-- Bit 7: merged slab flag (set when two slabs combine into a full block)
		DOUBLE_SLAB_MASK = 128
	},

	-- Network events
	NetworkEvent = {
		CHUNK_DATA = "ChunkDataStreamed",
		CHUNK_UNLOAD = "ChunkUnload",
		SPAWN_CHUNKS_STREAMED = "SpawnChunksStreamed",  -- S3: Server notifies client when spawn chunks are sent
		BLOCK_CHANGED = "BlockChanged",
		BLOCK_CHANGE_REJECTED = "BlockChangeRejected",
		REQUEST_CHUNKS = "VoxelRequestInitialChunks",
		PLAYER_POSITION = "VoxelPlayerPositionUpdate"
	}
}

-- Derived world sizes (studs) for a single chunk footprint
Constants.CHUNK_WORLD_SIZE_X = Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
Constants.CHUNK_WORLD_SIZE_Z = Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE

-- Metadata helper functions
function Constants.GetRotation(metadata)
	return bit32.band(metadata or 0, Constants.BlockMetadata.ROTATION_MASK)
end

function Constants.SetRotation(metadata, rotation)
	metadata = metadata or 0
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.ROTATION_MASK)),
		bit32.band(rotation, Constants.BlockMetadata.ROTATION_MASK)
	)
end

function Constants.GetVerticalOrientation(metadata)
	return bit32.band(metadata or 0, Constants.BlockMetadata.VERTICAL_MASK)
end

function Constants.SetVerticalOrientation(metadata, vertical)
	metadata = metadata or 0
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.VERTICAL_MASK)),
		bit32.band(vertical, Constants.BlockMetadata.VERTICAL_MASK)
	)
end

-- Stair shape helpers (bits 4-6)
function Constants.GetStairShape(metadata)
    local v = bit32.band(metadata or 0, Constants.BlockMetadata.SHAPE_MASK)
    return bit32.rshift(v, Constants.BlockMetadata.SHAPE_SHIFT)
end

function Constants.SetStairShape(metadata, shape)
    metadata = metadata or 0
    local shaped = bit32.lshift(bit32.band(shape or 0, 0x7), Constants.BlockMetadata.SHAPE_SHIFT)
    return bit32.bor(
        bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.SHAPE_MASK)),
        bit32.band(shaped, Constants.BlockMetadata.SHAPE_MASK)
    )
end

function Constants.HasDoubleSlabFlag(metadata)
	metadata = metadata or 0
	return bit32.band(metadata, Constants.BlockMetadata.DOUBLE_SLAB_MASK) ~= 0
end

function Constants.SetDoubleSlabFlag(metadata, enabled)
	metadata = metadata or 0
	if enabled then
		return bit32.bor(metadata, Constants.BlockMetadata.DOUBLE_SLAB_MASK)
	end
	return bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.DOUBLE_SLAB_MASK))
end

-- Check if a block ID is a slab
function Constants.IsSlab(blockId)
	return Constants.SlabToFullBlock[blockId] ~= nil
end

-- Get the full block equivalent of a slab (returns nil if not a slab)
function Constants.GetFullBlockFromSlab(slabId)
	return Constants.SlabToFullBlock[slabId]
end

-- Get the slab equivalent of a full block (returns nil if block doesn't have slab form)
function Constants.GetSlabFromFullBlock(fullBlockId)
	return Constants.FullBlockToSlab[fullBlockId]
end

-- Check if a full block should drop as slabs when broken
function Constants.ShouldDropAsSlabs(blockId, metadata)
	if not blockId then
		return false
	end
	if not Constants.HasDoubleSlabFlag(metadata) then
		return false
	end
	return Constants.FullBlockToSlab[blockId] ~= nil
end

-- Check if two slabs can combine into a full block
-- Returns: canCombine (boolean), fullBlockId (number or nil)
function Constants.CanSlabsCombine(existingSlabId, existingMetadata, newSlabId, newMetadata)
	-- Must be the same slab type
	if existingSlabId ~= newSlabId then
		return false, nil
	end

	-- Must both be slabs
	if not Constants.IsSlab(existingSlabId) or not Constants.IsSlab(newSlabId) then
		return false, nil
	end

	-- Must have opposite vertical orientations
	local existingOrientation = Constants.GetVerticalOrientation(existingMetadata)
	local newOrientation = Constants.GetVerticalOrientation(newMetadata)

	if existingOrientation == newOrientation then
		return false, nil  -- Same orientation, can't stack
	end

	-- They can combine!
	local fullBlockId = Constants.GetFullBlockFromSlab(existingSlabId)
	return true, fullBlockId
end

-- Check if a block ID is an ore that should drop material instead
function Constants.IsOreBlock(blockId)
	return Constants.OreToMaterial[blockId] ~= nil
end

-- Get the material item that an ore block should drop
function Constants.GetOreMaterialDrop(oreBlockId)
	return Constants.OreToMaterial[oreBlockId]
end

-- Check if a block should drop a different item when broken
function Constants.ShouldTransformBlockDrop(blockId)
	return Constants.BlockToDrop[blockId] ~= nil
end

-- Get the drop item ID for a block that transforms when broken
function Constants.GetBlockDrop(blockId)
	return Constants.BlockToDrop[blockId]
end

-- ============================================================================
-- Chunk Key Caching (reduces GC pressure from string concatenation)
-- ============================================================================
local chunkKeyCache = {}

-- Get cached chunk key string for coordinates
-- Avoids repeated string allocations in hot paths (meshing, neighbor lookups)
function Constants.ToChunkKey(cx: number, cz: number): string
	cx = math.floor(cx)
	cz = math.floor(cz)
	local row = chunkKeyCache[cx]
	if not row then
		row = {}
		chunkKeyCache[cx] = row
	end
	local key = row[cz]
	if not key then
		key = string.format("%d,%d", cx, cz)
		row[cz] = key
	end
	return key
end

-- Parse chunk key back to coordinates (for rare cases where needed)
function Constants.FromChunkKey(key: string): (number, number)
	local x, z = string.match(key, "^(-?%d+),(-?%d+)$")
	return tonumber(x) or 0, tonumber(z) or 0
end

-- Check if position is inside chunk bounds
function Constants.IsInsideChunk(lx: number, ly: number, lz: number): boolean
	return lx >= 0 and lx < Constants.CHUNK_SIZE_X
		and ly >= 0 and ly < Constants.CHUNK_SIZE_Y
		and lz >= 0 and lz < Constants.CHUNK_SIZE_Z
end

-- Convert world studs to chunk coordinates and local block position
function Constants.WorldStudsToChunkAndLocal(worldX: number, worldY: number, worldZ: number)
	local bs = Constants.BLOCK_SIZE
	local bx = math.floor(worldX / bs)
	local by = math.floor(worldY / bs)
	local bz = math.floor(worldZ / bs)

	local cx = math.floor(bx / Constants.CHUNK_SIZE_X)
	local cz = math.floor(bz / Constants.CHUNK_SIZE_Z)

	local lx = bx - cx * Constants.CHUNK_SIZE_X
	local ly = by
	local lz = bz - cz * Constants.CHUNK_SIZE_Z

	return cx, cz, lx, ly, lz
end

return Constants