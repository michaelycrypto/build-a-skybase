--[[
	BlockMapping.lua
	
	SINGLE SOURCE OF TRUTH for Minecraft → Roblox block type mappings.
	
	Used by:
	- SchematicWorldGenerator (hub world generation)
	- SchematicImporter (direct schematic imports)
	
	Maps Minecraft block names (1.13+ naming convention) to Constants.BlockType IDs.
	Only maps to BlockTypes that exist in Constants.lua!
]]

local Constants = require(script.Parent.Constants)
local BLOCK = Constants.BlockType

local BlockMapping = {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- MINECRAFT → ROBLOX BLOCK MAPPING TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

BlockMapping.Map = {
	-- ═══════════════════════════════════════════════════════════════════════
	-- AIR & SKIP
	-- ═══════════════════════════════════════════════════════════════════════
	["air"] = BLOCK.AIR,
	["cave_air"] = BLOCK.AIR,
	["void_air"] = BLOCK.AIR,
	["water"] = BLOCK.AIR,
	["lava"] = BLOCK.AIR,
	["fire"] = BLOCK.AIR,
	["soul_fire"] = BLOCK.AIR,
	["barrier"] = BLOCK.AIR,
	["structure_void"] = BLOCK.AIR,
	["light"] = BLOCK.AIR,

	-- ═══════════════════════════════════════════════════════════════════════
	-- CORE TERRAIN
	-- ═══════════════════════════════════════════════════════════════════════
	["stone"] = BLOCK.STONE,
	["dirt"] = BLOCK.DIRT,
	["grass_block"] = BLOCK.GRASS,
	["cobblestone"] = BLOCK.COBBLESTONE,
	["bedrock"] = BLOCK.BEDROCK,
	["sand"] = BLOCK.SAND,
	["red_sand"] = BLOCK.RED_SAND,
	["gravel"] = BLOCK.GRAVEL,
	["clay"] = BLOCK.CLAY_BLOCK,
	["coarse_dirt"] = BLOCK.COARSE_DIRT,
	["podzol"] = BLOCK.PODZOL,
	["mycelium"] = BLOCK.MYCELIUM,
	["rooted_dirt"] = BLOCK.DIRT,

	-- Snow & Ice
	["snow"] = BLOCK.SNOW_BLOCK,
	["snow_block"] = BLOCK.SNOW_BLOCK,
	["ice"] = BLOCK.ICE,
	["packed_ice"] = BLOCK.PACKED_ICE,
	["blue_ice"] = BLOCK.BLUE_ICE,

	-- Mud
	["mud"] = BLOCK.MUD,
	["packed_mud"] = BLOCK.PACKED_MUD,
	["mud_bricks"] = BLOCK.MUD_BRICKS,

	-- Moss & Dripstone
	["moss_block"] = BLOCK.MOSS_BLOCK,
	["moss_carpet"] = BLOCK.MOSS_CARPET,
	["dripstone_block"] = BLOCK.DRIPSTONE_BLOCK,

	-- ═══════════════════════════════════════════════════════════════════════
	-- STONE VARIANTS
	-- ═══════════════════════════════════════════════════════════════════════
	["stone_bricks"] = BLOCK.STONE_BRICKS,
	["mossy_stone_bricks"] = BLOCK.MOSSY_STONE_BRICKS,
	["cracked_stone_bricks"] = BLOCK.CRACKED_STONE_BRICKS,
	["chiseled_stone_bricks"] = BLOCK.CHISELED_STONE_BRICKS,
	["mossy_cobblestone"] = BLOCK.MOSSY_COBBLESTONE,
	["smooth_stone"] = BLOCK.SMOOTH_STONE,
	["andesite"] = BLOCK.ANDESITE,
	["polished_andesite"] = BLOCK.POLISHED_ANDESITE,
	["diorite"] = BLOCK.DIORITE,
	["polished_diorite"] = BLOCK.POLISHED_DIORITE,
	["granite"] = BLOCK.GRANITE,
	["polished_granite"] = BLOCK.POLISHED_GRANITE,
	["tuff"] = BLOCK.TUFF,
	["calcite"] = BLOCK.CALCITE,

	-- Deepslate
	["deepslate"] = BLOCK.DEEPSLATE,
	["cobbled_deepslate"] = BLOCK.COBBLED_DEEPSLATE,
	["polished_deepslate"] = BLOCK.POLISHED_DEEPSLATE,
	["deepslate_bricks"] = BLOCK.DEEPSLATE_BRICKS,
	["deepslate_tiles"] = BLOCK.DEEPSLATE_TILES,
	["cracked_deepslate_bricks"] = BLOCK.DEEPSLATE_BRICKS,
	["cracked_deepslate_tiles"] = BLOCK.DEEPSLATE_TILES,
	["chiseled_deepslate"] = BLOCK.POLISHED_DEEPSLATE,
	["reinforced_deepslate"] = BLOCK.REINFORCED_DEEPSLATE,

	-- Infested variants → normal
	["infested_stone"] = BLOCK.STONE,
	["infested_cobblestone"] = BLOCK.COBBLESTONE,
	["infested_stone_bricks"] = BLOCK.STONE_BRICKS,
	["infested_mossy_stone_bricks"] = BLOCK.MOSSY_STONE_BRICKS,
	["infested_cracked_stone_bricks"] = BLOCK.CRACKED_STONE_BRICKS,
	["infested_chiseled_stone_bricks"] = BLOCK.CHISELED_STONE_BRICKS,
	["infested_deepslate"] = BLOCK.DEEPSLATE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- SANDSTONE
	-- ═══════════════════════════════════════════════════════════════════════
	["sandstone"] = BLOCK.SANDSTONE,
	["smooth_sandstone"] = BLOCK.SMOOTH_SANDSTONE,
	["chiseled_sandstone"] = BLOCK.CHISELED_SANDSTONE,
	["cut_sandstone"] = BLOCK.CUT_SANDSTONE,
	["red_sandstone"] = BLOCK.RED_SANDSTONE,
	["smooth_red_sandstone"] = BLOCK.SMOOTH_RED_SANDSTONE,
	["chiseled_red_sandstone"] = BLOCK.CHISELED_RED_SANDSTONE,
	["cut_red_sandstone"] = BLOCK.CUT_RED_SANDSTONE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- NETHER BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["netherrack"] = BLOCK.NETHERRACK,
	["soul_sand"] = BLOCK.SOUL_SAND,
	["soul_soil"] = BLOCK.SOUL_SOIL,
	["magma_block"] = BLOCK.MAGMA_BLOCK,
	["glowstone"] = BLOCK.GLOWSTONE,
	["nether_wart_block"] = BLOCK.NETHER_WART_BLOCK,
	["warped_wart_block"] = BLOCK.WARPED_WART_BLOCK,
	["shroomlight"] = BLOCK.SHROOMLIGHT,
	["crying_obsidian"] = BLOCK.CRYING_OBSIDIAN,
	["obsidian"] = BLOCK.OBSIDIAN,
	["basalt"] = BLOCK.BASALT,
	["polished_basalt"] = BLOCK.POLISHED_BASALT,
	["smooth_basalt"] = BLOCK.SMOOTH_BASALT,
	["nether_gold_ore"] = BLOCK.NETHER_GOLD_ORE,
	["ancient_debris"] = BLOCK.ANCIENT_DEBRIS,
	["lodestone"] = BLOCK.LODESTONE,
	["respawn_anchor"] = BLOCK.RESPAWN_ANCHOR,
	["crimson_nylium"] = BLOCK.CRIMSON_NYLIUM,
	["warped_nylium"] = BLOCK.WARPED_NYLIUM,

	-- Nether bricks
	["nether_bricks"] = BLOCK.NETHER_BRICKS,
	["red_nether_bricks"] = BLOCK.RED_NETHER_BRICKS,
	["cracked_nether_bricks"] = BLOCK.NETHER_BRICKS,
	["chiseled_nether_bricks"] = BLOCK.NETHER_BRICKS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- BRICKS
	-- ═══════════════════════════════════════════════════════════════════════
	["bricks"] = BLOCK.BRICKS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- PRISMARINE
	-- ═══════════════════════════════════════════════════════════════════════
	["prismarine"] = BLOCK.PRISMARINE,
	["prismarine_bricks"] = BLOCK.PRISMARINE_BRICKS,
	["dark_prismarine"] = BLOCK.DARK_PRISMARINE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- PURPUR & END BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["purpur_block"] = BLOCK.PURPUR_BLOCK,
	["purpur_pillar"] = BLOCK.PURPUR_PILLAR,
	["end_stone"] = BLOCK.END_STONE,
	["end_stone_bricks"] = BLOCK.END_STONE_BRICKS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- AMETHYST
	-- ═══════════════════════════════════════════════════════════════════════
	["amethyst_block"] = BLOCK.AMETHYST_BLOCK,
	["budding_amethyst"] = BLOCK.BUDDING_AMETHYST,
	["amethyst_cluster"] = BLOCK.AMETHYST_BLOCK,
	["large_amethyst_bud"] = BLOCK.AMETHYST_BLOCK,
	["medium_amethyst_bud"] = BLOCK.AMETHYST_BLOCK,
	["small_amethyst_bud"] = BLOCK.AMETHYST_BLOCK,

	-- ═══════════════════════════════════════════════════════════════════════
	-- SCULK
	-- ═══════════════════════════════════════════════════════════════════════
	["sculk"] = BLOCK.SCULK,
	["sculk_catalyst"] = BLOCK.SCULK_CATALYST,
	["sculk_sensor"] = BLOCK.SCULK,
	["sculk_shrieker"] = BLOCK.SCULK,
	["sculk_vein"] = BLOCK.AIR,

	-- ═══════════════════════════════════════════════════════════════════════
	-- BLACKSTONE
	-- ═══════════════════════════════════════════════════════════════════════
	["blackstone"] = BLOCK.BLACKSTONE,
	["polished_blackstone"] = BLOCK.BLACKSTONE,
	["polished_blackstone_bricks"] = BLOCK.BLACKSTONE,
	["cracked_polished_blackstone_bricks"] = BLOCK.BLACKSTONE,
	["chiseled_polished_blackstone"] = BLOCK.BLACKSTONE,
	["gilded_blackstone"] = BLOCK.BLACKSTONE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- QUARTZ
	-- ═══════════════════════════════════════════════════════════════════════
	["quartz_block"] = BLOCK.QUARTZ_BLOCK,
	["smooth_quartz"] = BLOCK.QUARTZ_BLOCK,
	["chiseled_quartz_block"] = BLOCK.CHISELED_QUARTZ_BLOCK,
	["quartz_pillar"] = BLOCK.QUARTZ_PILLAR,
	["quartz_bricks"] = BLOCK.QUARTZ_BLOCK,
	["nether_quartz_ore"] = BLOCK.QUARTZ_BLOCK,

	-- ═══════════════════════════════════════════════════════════════════════
	-- GLASS
	-- ═══════════════════════════════════════════════════════════════════════
	["glass"] = BLOCK.GLASS,
	["glass_pane"] = BLOCK.GLASS,
	["tinted_glass"] = BLOCK.GRAY_STAINED_GLASS,

	-- Stained Glass (16 colors)
	["white_stained_glass"] = BLOCK.WHITE_STAINED_GLASS,
	["orange_stained_glass"] = BLOCK.ORANGE_STAINED_GLASS,
	["magenta_stained_glass"] = BLOCK.MAGENTA_STAINED_GLASS,
	["light_blue_stained_glass"] = BLOCK.LIGHT_BLUE_STAINED_GLASS,
	["yellow_stained_glass"] = BLOCK.YELLOW_STAINED_GLASS,
	["lime_stained_glass"] = BLOCK.LIME_STAINED_GLASS,
	["pink_stained_glass"] = BLOCK.PINK_STAINED_GLASS,
	["gray_stained_glass"] = BLOCK.GRAY_STAINED_GLASS,
	["light_gray_stained_glass"] = BLOCK.LIGHT_GRAY_STAINED_GLASS,
	["cyan_stained_glass"] = BLOCK.CYAN_STAINED_GLASS,
	["purple_stained_glass"] = BLOCK.PURPLE_STAINED_GLASS,
	["blue_stained_glass"] = BLOCK.BLUE_STAINED_GLASS,
	["brown_stained_glass"] = BLOCK.BROWN_STAINED_GLASS,
	["green_stained_glass"] = BLOCK.GREEN_STAINED_GLASS,
	["red_stained_glass"] = BLOCK.RED_STAINED_GLASS,
	["black_stained_glass"] = BLOCK.BLACK_STAINED_GLASS,

	-- Stained Glass Panes → solid glass
	["white_stained_glass_pane"] = BLOCK.WHITE_STAINED_GLASS,
	["orange_stained_glass_pane"] = BLOCK.ORANGE_STAINED_GLASS,
	["magenta_stained_glass_pane"] = BLOCK.MAGENTA_STAINED_GLASS,
	["light_blue_stained_glass_pane"] = BLOCK.LIGHT_BLUE_STAINED_GLASS,
	["yellow_stained_glass_pane"] = BLOCK.YELLOW_STAINED_GLASS,
	["lime_stained_glass_pane"] = BLOCK.LIME_STAINED_GLASS,
	["pink_stained_glass_pane"] = BLOCK.PINK_STAINED_GLASS,
	["gray_stained_glass_pane"] = BLOCK.GRAY_STAINED_GLASS,
	["light_gray_stained_glass_pane"] = BLOCK.LIGHT_GRAY_STAINED_GLASS,
	["cyan_stained_glass_pane"] = BLOCK.CYAN_STAINED_GLASS,
	["purple_stained_glass_pane"] = BLOCK.PURPLE_STAINED_GLASS,
	["blue_stained_glass_pane"] = BLOCK.BLUE_STAINED_GLASS,
	["brown_stained_glass_pane"] = BLOCK.BROWN_STAINED_GLASS,
	["green_stained_glass_pane"] = BLOCK.GREEN_STAINED_GLASS,
	["red_stained_glass_pane"] = BLOCK.RED_STAINED_GLASS,
	["black_stained_glass_pane"] = BLOCK.BLACK_STAINED_GLASS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- WOOL (16 colors)
	-- ═══════════════════════════════════════════════════════════════════════
	["white_wool"] = BLOCK.WHITE_WOOL,
	["orange_wool"] = BLOCK.ORANGE_WOOL,
	["magenta_wool"] = BLOCK.MAGENTA_WOOL,
	["light_blue_wool"] = BLOCK.LIGHT_BLUE_WOOL,
	["yellow_wool"] = BLOCK.YELLOW_WOOL,
	["lime_wool"] = BLOCK.LIME_WOOL,
	["pink_wool"] = BLOCK.PINK_WOOL,
	["gray_wool"] = BLOCK.GRAY_WOOL,
	["light_gray_wool"] = BLOCK.LIGHT_GRAY_WOOL,
	["cyan_wool"] = BLOCK.CYAN_WOOL,
	["purple_wool"] = BLOCK.PURPLE_WOOL,
	["blue_wool"] = BLOCK.BLUE_WOOL,
	["brown_wool"] = BLOCK.BROWN_WOOL,
	["green_wool"] = BLOCK.GREEN_WOOL,
	["red_wool"] = BLOCK.RED_WOOL,
	["black_wool"] = BLOCK.BLACK_WOOL,

	-- Carpet → wool
	["white_carpet"] = BLOCK.WHITE_WOOL,
	["orange_carpet"] = BLOCK.ORANGE_WOOL,
	["magenta_carpet"] = BLOCK.MAGENTA_WOOL,
	["light_blue_carpet"] = BLOCK.LIGHT_BLUE_WOOL,
	["yellow_carpet"] = BLOCK.YELLOW_WOOL,
	["lime_carpet"] = BLOCK.LIME_WOOL,
	["pink_carpet"] = BLOCK.PINK_WOOL,
	["gray_carpet"] = BLOCK.GRAY_WOOL,
	["light_gray_carpet"] = BLOCK.LIGHT_GRAY_WOOL,
	["cyan_carpet"] = BLOCK.CYAN_WOOL,
	["purple_carpet"] = BLOCK.PURPLE_WOOL,
	["blue_carpet"] = BLOCK.BLUE_WOOL,
	["brown_carpet"] = BLOCK.BROWN_WOOL,
	["green_carpet"] = BLOCK.GREEN_WOOL,
	["red_carpet"] = BLOCK.RED_WOOL,
	["black_carpet"] = BLOCK.BLACK_WOOL,

	-- ═══════════════════════════════════════════════════════════════════════
	-- TERRACOTTA (17 colors)
	-- ═══════════════════════════════════════════════════════════════════════
	["terracotta"] = BLOCK.TERRACOTTA,
	["white_terracotta"] = BLOCK.WHITE_TERRACOTTA,
	["orange_terracotta"] = BLOCK.ORANGE_TERRACOTTA,
	["magenta_terracotta"] = BLOCK.MAGENTA_TERRACOTTA,
	["light_blue_terracotta"] = BLOCK.LIGHT_BLUE_TERRACOTTA,
	["yellow_terracotta"] = BLOCK.YELLOW_TERRACOTTA,
	["lime_terracotta"] = BLOCK.LIME_TERRACOTTA,
	["pink_terracotta"] = BLOCK.PINK_TERRACOTTA,
	["gray_terracotta"] = BLOCK.GRAY_TERRACOTTA,
	["light_gray_terracotta"] = BLOCK.LIGHT_GRAY_TERRACOTTA,
	["cyan_terracotta"] = BLOCK.CYAN_TERRACOTTA,
	["purple_terracotta"] = BLOCK.PURPLE_TERRACOTTA,
	["blue_terracotta"] = BLOCK.BLUE_TERRACOTTA,
	["brown_terracotta"] = BLOCK.BROWN_TERRACOTTA,
	["green_terracotta"] = BLOCK.GREEN_TERRACOTTA,
	["red_terracotta"] = BLOCK.RED_TERRACOTTA,
	["black_terracotta"] = BLOCK.BLACK_TERRACOTTA,

	-- Glazed Terracotta → regular terracotta
	["white_glazed_terracotta"] = BLOCK.WHITE_TERRACOTTA,
	["orange_glazed_terracotta"] = BLOCK.ORANGE_TERRACOTTA,
	["magenta_glazed_terracotta"] = BLOCK.MAGENTA_TERRACOTTA,
	["light_blue_glazed_terracotta"] = BLOCK.LIGHT_BLUE_TERRACOTTA,
	["yellow_glazed_terracotta"] = BLOCK.YELLOW_TERRACOTTA,
	["lime_glazed_terracotta"] = BLOCK.LIME_TERRACOTTA,
	["pink_glazed_terracotta"] = BLOCK.PINK_TERRACOTTA,
	["gray_glazed_terracotta"] = BLOCK.GRAY_TERRACOTTA,
	["light_gray_glazed_terracotta"] = BLOCK.LIGHT_GRAY_TERRACOTTA,
	["cyan_glazed_terracotta"] = BLOCK.CYAN_TERRACOTTA,
	["purple_glazed_terracotta"] = BLOCK.PURPLE_TERRACOTTA,
	["blue_glazed_terracotta"] = BLOCK.BLUE_TERRACOTTA,
	["brown_glazed_terracotta"] = BLOCK.BROWN_TERRACOTTA,
	["green_glazed_terracotta"] = BLOCK.GREEN_TERRACOTTA,
	["red_glazed_terracotta"] = BLOCK.RED_TERRACOTTA,
	["black_glazed_terracotta"] = BLOCK.BLACK_TERRACOTTA,

	-- ═══════════════════════════════════════════════════════════════════════
	-- CONCRETE (16 colors)
	-- ═══════════════════════════════════════════════════════════════════════
	["white_concrete"] = BLOCK.WHITE_CONCRETE,
	["orange_concrete"] = BLOCK.ORANGE_CONCRETE,
	["magenta_concrete"] = BLOCK.MAGENTA_CONCRETE,
	["light_blue_concrete"] = BLOCK.LIGHT_BLUE_CONCRETE,
	["yellow_concrete"] = BLOCK.YELLOW_CONCRETE,
	["lime_concrete"] = BLOCK.LIME_CONCRETE,
	["pink_concrete"] = BLOCK.PINK_CONCRETE,
	["gray_concrete"] = BLOCK.GRAY_CONCRETE,
	["light_gray_concrete"] = BLOCK.LIGHT_GRAY_CONCRETE,
	["cyan_concrete"] = BLOCK.CYAN_CONCRETE,
	["purple_concrete"] = BLOCK.PURPLE_CONCRETE,
	["blue_concrete"] = BLOCK.BLUE_CONCRETE,
	["brown_concrete"] = BLOCK.BROWN_CONCRETE,
	["green_concrete"] = BLOCK.GREEN_CONCRETE,
	["red_concrete"] = BLOCK.RED_CONCRETE,
	["black_concrete"] = BLOCK.BLACK_CONCRETE,

	-- Concrete Powder
	["white_concrete_powder"] = BLOCK.WHITE_CONCRETE_POWDER,
	["orange_concrete_powder"] = BLOCK.ORANGE_CONCRETE_POWDER,
	["magenta_concrete_powder"] = BLOCK.MAGENTA_CONCRETE_POWDER,
	["light_blue_concrete_powder"] = BLOCK.LIGHT_BLUE_CONCRETE_POWDER,
	["yellow_concrete_powder"] = BLOCK.YELLOW_CONCRETE_POWDER,
	["lime_concrete_powder"] = BLOCK.LIME_CONCRETE_POWDER,
	["pink_concrete_powder"] = BLOCK.PINK_CONCRETE_POWDER,
	["gray_concrete_powder"] = BLOCK.GRAY_CONCRETE_POWDER,
	["light_gray_concrete_powder"] = BLOCK.LIGHT_GRAY_CONCRETE_POWDER,
	["cyan_concrete_powder"] = BLOCK.CYAN_CONCRETE_POWDER,
	["purple_concrete_powder"] = BLOCK.PURPLE_CONCRETE_POWDER,
	["blue_concrete_powder"] = BLOCK.BLUE_CONCRETE_POWDER,
	["brown_concrete_powder"] = BLOCK.BROWN_CONCRETE_POWDER,
	["green_concrete_powder"] = BLOCK.GREEN_CONCRETE_POWDER,
	["red_concrete_powder"] = BLOCK.RED_CONCRETE_POWDER,
	["black_concrete_powder"] = BLOCK.BLACK_CONCRETE_POWDER,

	-- ═══════════════════════════════════════════════════════════════════════
	-- WOOD - LOGS
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_log"] = BLOCK.WOOD,
	["oak_wood"] = BLOCK.WOOD,
	["stripped_oak_log"] = BLOCK.STRIPPED_OAK_LOG,
	["stripped_oak_wood"] = BLOCK.STRIPPED_OAK_LOG,

	["spruce_log"] = BLOCK.SPRUCE_LOG,
	["spruce_wood"] = BLOCK.SPRUCE_LOG,
	["stripped_spruce_log"] = BLOCK.STRIPPED_SPRUCE_LOG,
	["stripped_spruce_wood"] = BLOCK.STRIPPED_SPRUCE_LOG,

	["birch_log"] = BLOCK.BIRCH_LOG,
	["birch_wood"] = BLOCK.BIRCH_LOG,
	["stripped_birch_log"] = BLOCK.STRIPPED_BIRCH_LOG,
	["stripped_birch_wood"] = BLOCK.STRIPPED_BIRCH_LOG,

	["jungle_log"] = BLOCK.JUNGLE_LOG,
	["jungle_wood"] = BLOCK.JUNGLE_LOG,
	["stripped_jungle_log"] = BLOCK.STRIPPED_JUNGLE_LOG,
	["stripped_jungle_wood"] = BLOCK.STRIPPED_JUNGLE_LOG,

	["acacia_log"] = BLOCK.ACACIA_LOG,
	["acacia_wood"] = BLOCK.ACACIA_LOG,
	["stripped_acacia_log"] = BLOCK.STRIPPED_ACACIA_LOG,
	["stripped_acacia_wood"] = BLOCK.STRIPPED_ACACIA_LOG,

	["dark_oak_log"] = BLOCK.DARK_OAK_LOG,
	["dark_oak_wood"] = BLOCK.DARK_OAK_LOG,
	["stripped_dark_oak_log"] = BLOCK.STRIPPED_DARK_OAK_LOG,
	["stripped_dark_oak_wood"] = BLOCK.STRIPPED_DARK_OAK_LOG,

	["mangrove_log"] = BLOCK.MANGROVE_LOG,
	["mangrove_wood"] = BLOCK.MANGROVE_LOG,
	["stripped_mangrove_log"] = BLOCK.STRIPPED_MANGROVE_LOG,
	["stripped_mangrove_wood"] = BLOCK.STRIPPED_MANGROVE_LOG,
	["mangrove_roots"] = BLOCK.MANGROVE_LOG,

	-- Nether wood
	["crimson_stem"] = BLOCK.CRIMSON_STEM,
	["crimson_hyphae"] = BLOCK.CRIMSON_STEM,
	["stripped_crimson_stem"] = BLOCK.STRIPPED_CRIMSON_STEM,
	["stripped_crimson_hyphae"] = BLOCK.STRIPPED_CRIMSON_STEM,

	["warped_stem"] = BLOCK.WARPED_STEM,
	["warped_hyphae"] = BLOCK.WARPED_STEM,
	["stripped_warped_stem"] = BLOCK.STRIPPED_WARPED_STEM,
	["stripped_warped_hyphae"] = BLOCK.STRIPPED_WARPED_STEM,

	-- ═══════════════════════════════════════════════════════════════════════
	-- WOOD - PLANKS
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_planks"] = BLOCK.OAK_PLANKS,
	["spruce_planks"] = BLOCK.SPRUCE_PLANKS,
	["birch_planks"] = BLOCK.BIRCH_PLANKS,
	["jungle_planks"] = BLOCK.JUNGLE_PLANKS,
	["acacia_planks"] = BLOCK.ACACIA_PLANKS,
	["dark_oak_planks"] = BLOCK.DARK_OAK_PLANKS,
	["mangrove_planks"] = BLOCK.MANGROVE_PLANKS,
	["crimson_planks"] = BLOCK.CRIMSON_PLANKS,
	["warped_planks"] = BLOCK.WARPED_PLANKS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- LEAVES
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_leaves"] = BLOCK.OAK_LEAVES,
	["spruce_leaves"] = BLOCK.SPRUCE_LEAVES,
	["birch_leaves"] = BLOCK.BIRCH_LEAVES,
	["jungle_leaves"] = BLOCK.JUNGLE_LEAVES,
	["acacia_leaves"] = BLOCK.ACACIA_LEAVES,
	["dark_oak_leaves"] = BLOCK.DARK_OAK_LEAVES,
	["mangrove_leaves"] = BLOCK.MANGROVE_LEAVES,
	["azalea_leaves"] = BLOCK.OAK_LEAVES,
	["flowering_azalea_leaves"] = BLOCK.OAK_LEAVES,
	["leaves"] = BLOCK.LEAVES, -- Legacy

	-- ═══════════════════════════════════════════════════════════════════════
	-- STAIRS
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_stairs"] = BLOCK.OAK_STAIRS,
	["spruce_stairs"] = BLOCK.SPRUCE_STAIRS,
	["birch_stairs"] = BLOCK.BIRCH_STAIRS,
	["jungle_stairs"] = BLOCK.JUNGLE_STAIRS,
	["acacia_stairs"] = BLOCK.ACACIA_STAIRS,
	["dark_oak_stairs"] = BLOCK.DARK_OAK_STAIRS,
	["stone_stairs"] = BLOCK.STONE_STAIRS,
	["cobblestone_stairs"] = BLOCK.COBBLESTONE_STAIRS,
	["stone_brick_stairs"] = BLOCK.STONE_BRICK_STAIRS,
	["brick_stairs"] = BLOCK.BRICK_STAIRS,
	["sandstone_stairs"] = BLOCK.SANDSTONE_STAIRS,
	["andesite_stairs"] = BLOCK.ANDESITE_STAIRS,
	["diorite_stairs"] = BLOCK.DIORITE_STAIRS,
	["granite_stairs"] = BLOCK.GRANITE_STAIRS,
	["nether_brick_stairs"] = BLOCK.NETHER_BRICK_STAIRS,
	["quartz_stairs"] = BLOCK.QUARTZ_STAIRS,
	["purpur_stairs"] = BLOCK.STONE_STAIRS,
	["blackstone_stairs"] = BLOCK.STONE_STAIRS,
	["red_sandstone_stairs"] = BLOCK.SANDSTONE_STAIRS,
	["mossy_cobblestone_stairs"] = BLOCK.COBBLESTONE_STAIRS,
	["mossy_stone_brick_stairs"] = BLOCK.STONE_BRICK_STAIRS,
	["smooth_sandstone_stairs"] = BLOCK.SANDSTONE_STAIRS,
	["smooth_quartz_stairs"] = BLOCK.QUARTZ_STAIRS,
	["polished_andesite_stairs"] = BLOCK.ANDESITE_STAIRS,
	["polished_diorite_stairs"] = BLOCK.DIORITE_STAIRS,
	["polished_granite_stairs"] = BLOCK.GRANITE_STAIRS,
	["prismarine_stairs"] = BLOCK.STONE_STAIRS,
	["prismarine_brick_stairs"] = BLOCK.STONE_STAIRS,
	["dark_prismarine_stairs"] = BLOCK.STONE_STAIRS,
	["end_stone_brick_stairs"] = BLOCK.STONE_STAIRS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- SLABS
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_slab"] = BLOCK.OAK_SLAB,
	["spruce_slab"] = BLOCK.SPRUCE_SLAB,
	["birch_slab"] = BLOCK.BIRCH_SLAB,
	["jungle_slab"] = BLOCK.JUNGLE_SLAB,
	["acacia_slab"] = BLOCK.ACACIA_SLAB,
	["dark_oak_slab"] = BLOCK.DARK_OAK_SLAB,
	["stone_slab"] = BLOCK.STONE_SLAB,
	["cobblestone_slab"] = BLOCK.COBBLESTONE_SLAB,
	["stone_brick_slab"] = BLOCK.STONE_BRICK_SLAB,
	["brick_slab"] = BLOCK.BRICK_SLAB,
	["sandstone_slab"] = BLOCK.STONE_SLAB,
	["andesite_slab"] = BLOCK.STONE_SLAB,
	["granite_slab"] = BLOCK.GRANITE_SLAB,
	["smooth_stone_slab"] = BLOCK.STONE_SLAB,
	["smooth_quartz_slab"] = BLOCK.SMOOTH_QUARTZ_SLAB,
	["quartz_slab"] = BLOCK.SMOOTH_QUARTZ_SLAB,
	["nether_brick_slab"] = BLOCK.STONE_SLAB,
	["blackstone_slab"] = BLOCK.BLACKSTONE_SLAB,
	["purpur_slab"] = BLOCK.STONE_SLAB,
	["cut_sandstone_slab"] = BLOCK.STONE_SLAB,

	-- ═══════════════════════════════════════════════════════════════════════
	-- FENCES → OAK_FENCE
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_fence"] = BLOCK.OAK_FENCE,
	["spruce_fence"] = BLOCK.OAK_FENCE,
	["birch_fence"] = BLOCK.OAK_FENCE,
	["jungle_fence"] = BLOCK.OAK_FENCE,
	["acacia_fence"] = BLOCK.OAK_FENCE,
	["dark_oak_fence"] = BLOCK.OAK_FENCE,
	["nether_brick_fence"] = BLOCK.OAK_FENCE,
	["crimson_fence"] = BLOCK.OAK_FENCE,
	["warped_fence"] = BLOCK.OAK_FENCE,
	["mangrove_fence"] = BLOCK.OAK_FENCE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- WALLS → base material
	-- ═══════════════════════════════════════════════════════════════════════
	["cobblestone_wall"] = BLOCK.COBBLESTONE,
	["mossy_cobblestone_wall"] = BLOCK.MOSSY_COBBLESTONE,
	["stone_brick_wall"] = BLOCK.STONE_BRICKS,
	["mossy_stone_brick_wall"] = BLOCK.MOSSY_STONE_BRICKS,
	["brick_wall"] = BLOCK.BRICKS,
	["sandstone_wall"] = BLOCK.SANDSTONE,
	["red_sandstone_wall"] = BLOCK.RED_SANDSTONE,
	["nether_brick_wall"] = BLOCK.NETHER_BRICKS,
	["red_nether_brick_wall"] = BLOCK.RED_NETHER_BRICKS,
	["prismarine_wall"] = BLOCK.PRISMARINE,
	["blackstone_wall"] = BLOCK.BLACKSTONE,
	["polished_blackstone_wall"] = BLOCK.BLACKSTONE,
	["polished_blackstone_brick_wall"] = BLOCK.BLACKSTONE,
	["granite_wall"] = BLOCK.GRANITE,
	["diorite_wall"] = BLOCK.DIORITE,
	["andesite_wall"] = BLOCK.ANDESITE,
	["deepslate_wall"] = BLOCK.DEEPSLATE,
	["cobbled_deepslate_wall"] = BLOCK.COBBLED_DEEPSLATE,
	["polished_deepslate_wall"] = BLOCK.POLISHED_DEEPSLATE,
	["deepslate_brick_wall"] = BLOCK.DEEPSLATE_BRICKS,
	["deepslate_tile_wall"] = BLOCK.DEEPSLATE_TILES,
	["end_stone_brick_wall"] = BLOCK.END_STONE_BRICKS,

	-- ═══════════════════════════════════════════════════════════════════════
	-- SAPLINGS
	-- ═══════════════════════════════════════════════════════════════════════
	["oak_sapling"] = BLOCK.OAK_SAPLING,
	["spruce_sapling"] = BLOCK.SPRUCE_SAPLING,
	["birch_sapling"] = BLOCK.BIRCH_SAPLING,
	["jungle_sapling"] = BLOCK.JUNGLE_SAPLING,
	["acacia_sapling"] = BLOCK.ACACIA_SAPLING,
	["dark_oak_sapling"] = BLOCK.DARK_OAK_SAPLING,

	-- ═══════════════════════════════════════════════════════════════════════
	-- PLANTS & VEGETATION
	-- ═══════════════════════════════════════════════════════════════════════
	["grass"] = BLOCK.TALL_GRASS,
	["short_grass"] = BLOCK.TALL_GRASS,
	["tall_grass"] = BLOCK.TALL_GRASS,
	["fern"] = BLOCK.TALL_GRASS,
	["large_fern"] = BLOCK.TALL_GRASS,
	["seagrass"] = BLOCK.TALL_GRASS,
	["tall_seagrass"] = BLOCK.TALL_GRASS,
	["kelp"] = BLOCK.TALL_GRASS,
	["kelp_plant"] = BLOCK.TALL_GRASS,
	["vine"] = BLOCK.TALL_GRASS,
	["cave_vines"] = BLOCK.TALL_GRASS,
	["cave_vines_plant"] = BLOCK.TALL_GRASS,
	["weeping_vines"] = BLOCK.TALL_GRASS,
	["weeping_vines_plant"] = BLOCK.TALL_GRASS,
	["twisting_vines"] = BLOCK.TALL_GRASS,
	["twisting_vines_plant"] = BLOCK.TALL_GRASS,
	["dead_bush"] = BLOCK.DEAD_BUSH,

	-- Flowers
	["allium"] = BLOCK.FLOWER,
	["azure_bluet"] = BLOCK.FLOWER,
	["blue_orchid"] = BLOCK.FLOWER,
	["cornflower"] = BLOCK.FLOWER,
	["dandelion"] = BLOCK.FLOWER,
	["lily_of_the_valley"] = BLOCK.FLOWER,
	["orange_tulip"] = BLOCK.FLOWER,
	["oxeye_daisy"] = BLOCK.FLOWER,
	["pink_tulip"] = BLOCK.FLOWER,
	["poppy"] = BLOCK.FLOWER,
	["red_tulip"] = BLOCK.FLOWER,
	["white_tulip"] = BLOCK.FLOWER,
	["wither_rose"] = BLOCK.FLOWER,
	["peony"] = BLOCK.FLOWER,
	["rose_bush"] = BLOCK.FLOWER,
	["lilac"] = BLOCK.FLOWER,
	["sunflower"] = BLOCK.FLOWER,
	["azalea"] = BLOCK.FLOWER,
	["flowering_azalea"] = BLOCK.FLOWER,

	-- Lily pad & mushrooms
	["lily_pad"] = BLOCK.LILY_PAD,
	["brown_mushroom"] = BLOCK.BROWN_MUSHROOM,
	["red_mushroom"] = BLOCK.RED_MUSHROOM,

	-- Cactus & sugar cane
	["cactus"] = BLOCK.CACTUS,
	["sugar_cane"] = BLOCK.SUGAR_CANE,
	["bamboo"] = BLOCK.SUGAR_CANE,
	["bamboo_sapling"] = BLOCK.SUGAR_CANE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- MUSHROOM BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["brown_mushroom_block"] = BLOCK.BROWN_MUSHROOM_BLOCK,
	["red_mushroom_block"] = BLOCK.RED_MUSHROOM_BLOCK,
	["mushroom_stem"] = BLOCK.MUSHROOM_STEM,

	-- ═══════════════════════════════════════════════════════════════════════
	-- CROPS
	-- ═══════════════════════════════════════════════════════════════════════
	["farmland"] = BLOCK.FARMLAND,
	["wheat"] = BLOCK.WHEAT_CROP_7,
	["potatoes"] = BLOCK.POTATO_CROP_3,
	["carrots"] = BLOCK.CARROT_CROP_3,
	["beetroots"] = BLOCK.BEETROOT_CROP_3,

	-- ═══════════════════════════════════════════════════════════════════════
	-- MELON & PUMPKIN
	-- ═══════════════════════════════════════════════════════════════════════
	["melon"] = BLOCK.MELON,
	["pumpkin"] = BLOCK.PUMPKIN,
	["carved_pumpkin"] = BLOCK.CARVED_PUMPKIN,
	["jack_o_lantern"] = BLOCK.JACK_O_LANTERN,

	-- ═══════════════════════════════════════════════════════════════════════
	-- SPECIAL BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["slime_block"] = BLOCK.SLIME_BLOCK,
	["honey_block"] = BLOCK.HONEY_BLOCK,
	["hay_block"] = BLOCK.HAY_BLOCK,
	["cobweb"] = BLOCK.COBWEB,
	["iron_bars"] = BLOCK.GRAY_STAINED_GLASS,
	["chain"] = BLOCK.CHAIN,
	["sponge"] = BLOCK.SPONGE,
	["wet_sponge"] = BLOCK.WET_SPONGE,
	["tnt"] = BLOCK.TNT,
	["bone_block"] = BLOCK.BONE_BLOCK,
	["dried_kelp_block"] = BLOCK.DRIED_KELP_BLOCK,

	-- ═══════════════════════════════════════════════════════════════════════
	-- LIGHT SOURCES
	-- ═══════════════════════════════════════════════════════════════════════
	["sea_lantern"] = BLOCK.SEA_LANTERN,
	["lantern"] = BLOCK.LANTERN,
	["soul_lantern"] = BLOCK.SOUL_LANTERN,
	["redstone_lamp"] = BLOCK.REDSTONE_LAMP,
	["beacon"] = BLOCK.BEACON,

	-- ═══════════════════════════════════════════════════════════════════════
	-- ORES
	-- ═══════════════════════════════════════════════════════════════════════
	["coal_ore"] = BLOCK.COAL_ORE,
	["iron_ore"] = BLOCK.IRON_ORE,
	["copper_ore"] = BLOCK.COPPER_ORE,
	["deepslate_coal_ore"] = BLOCK.COAL_ORE,
	["deepslate_iron_ore"] = BLOCK.IRON_ORE,
	["deepslate_copper_ore"] = BLOCK.COPPER_ORE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- METAL BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["coal_block"] = BLOCK.COAL_BLOCK,
	["iron_block"] = BLOCK.IRON_BLOCK,
	["copper_block"] = BLOCK.COPPER_BLOCK,

	-- ═══════════════════════════════════════════════════════════════════════
	-- UTILITY BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	["crafting_table"] = BLOCK.CRAFTING_TABLE,
	["furnace"] = BLOCK.FURNACE,
	["chest"] = BLOCK.CHEST,
	["trapped_chest"] = BLOCK.CHEST,
	["bookshelf"] = BLOCK.BOOKSHELF,
	["jukebox"] = BLOCK.JUKEBOX,
	["note_block"] = BLOCK.NOTE_BLOCK,
	["spawner"] = BLOCK.SPAWNER,
	["cauldron"] = BLOCK.CAULDRON,
	["water_cauldron"] = BLOCK.CAULDRON,
	["lava_cauldron"] = BLOCK.CAULDRON,
	["powder_snow_cauldron"] = BLOCK.CAULDRON,
	["anvil"] = BLOCK.ANVIL,
	["chipped_anvil"] = BLOCK.ANVIL,
	["damaged_anvil"] = BLOCK.ANVIL,
	["brewing_stand"] = BLOCK.BREWING_STAND,
	["enchanting_table"] = BLOCK.ENCHANTING_TABLE,

	-- ═══════════════════════════════════════════════════════════════════════
	-- LEGACY MINECRAFT NAMES (pre-1.13)
	-- ═══════════════════════════════════════════════════════════════════════
	["slime"] = BLOCK.SLIME_BLOCK,
	["melon_block"] = BLOCK.MELON,
	["red_flower"] = BLOCK.FLOWER,
	["tallgrass"] = BLOCK.TALL_GRASS,
	["double_plant"] = BLOCK.TALL_GRASS,
	["brick_block"] = BLOCK.BRICKS,
	["stonebrick"] = BLOCK.STONE_BRICKS,
	["hardened_clay"] = BLOCK.TERRACOTTA,
	["stained_hardened_clay"] = BLOCK.TERRACOTTA,
	["web"] = BLOCK.COBWEB,
	["snow_layer"] = BLOCK.SNOW_BLOCK,
	["lit_redstone_lamp"] = BLOCK.REDSTONE_LAMP,
	["fence"] = BLOCK.OAK_FENCE,
	["log"] = BLOCK.WOOD,
	["log2"] = BLOCK.DARK_OAK_LOG,
	["planks"] = BLOCK.OAK_PLANKS,
	["wooden_slab"] = BLOCK.OAK_SLAB,

	-- ═══════════════════════════════════════════════════════════════════════
	-- UNSUPPORTED → AIR (decoration/redstone/interactive)
	-- ═══════════════════════════════════════════════════════════════════════
	["torch"] = BLOCK.AIR,
	["wall_torch"] = BLOCK.AIR,
	["soul_torch"] = BLOCK.AIR,
	["soul_wall_torch"] = BLOCK.AIR,
	["redstone_torch"] = BLOCK.AIR,
	["redstone_wall_torch"] = BLOCK.AIR,
	["ladder"] = BLOCK.AIR,
	["hopper"] = BLOCK.AIR,
	["end_portal_frame"] = BLOCK.STONE_BRICKS,
	["ender_chest"] = BLOCK.CHEST,
	["redstone_block"] = BLOCK.RED_CONCRETE,
	["redstone_wire"] = BLOCK.AIR,

	-- Doors, trapdoors, buttons, pressure plates
	["oak_door"] = BLOCK.AIR,
	["spruce_door"] = BLOCK.AIR,
	["birch_door"] = BLOCK.AIR,
	["jungle_door"] = BLOCK.AIR,
	["acacia_door"] = BLOCK.AIR,
	["dark_oak_door"] = BLOCK.AIR,
	["iron_door"] = BLOCK.AIR,
	["trapdoor"] = BLOCK.AIR,
	["oak_trapdoor"] = BLOCK.AIR,
	["spruce_trapdoor"] = BLOCK.AIR,
	["birch_trapdoor"] = BLOCK.AIR,
	["jungle_trapdoor"] = BLOCK.AIR,
	["acacia_trapdoor"] = BLOCK.AIR,
	["dark_oak_trapdoor"] = BLOCK.AIR,
	["iron_trapdoor"] = BLOCK.AIR,
	["oak_button"] = BLOCK.AIR,
	["stone_button"] = BLOCK.AIR,
	["oak_pressure_plate"] = BLOCK.AIR,
	["stone_pressure_plate"] = BLOCK.AIR,
	["light_weighted_pressure_plate"] = BLOCK.AIR,
	["heavy_weighted_pressure_plate"] = BLOCK.AIR,
	["wooden_button"] = BLOCK.AIR,
	["wooden_pressure_plate"] = BLOCK.AIR,

	-- Fence gates
	["fence_gate"] = BLOCK.AIR,
	["oak_fence_gate"] = BLOCK.AIR,
	["spruce_fence_gate"] = BLOCK.AIR,
	["birch_fence_gate"] = BLOCK.AIR,
	["jungle_fence_gate"] = BLOCK.AIR,
	["acacia_fence_gate"] = BLOCK.AIR,
	["dark_oak_fence_gate"] = BLOCK.AIR,

	-- Signs
	["oak_sign"] = BLOCK.AIR,
	["oak_wall_sign"] = BLOCK.AIR,
	["spruce_wall_sign"] = BLOCK.AIR,
	["birch_wall_sign"] = BLOCK.AIR,
	["jungle_wall_sign"] = BLOCK.AIR,
	["acacia_wall_sign"] = BLOCK.AIR,
	["dark_oak_wall_sign"] = BLOCK.AIR,
	["wall_sign"] = BLOCK.AIR,

	-- Redstone components
	["piston"] = BLOCK.AIR,
	["piston_head"] = BLOCK.AIR,
	["sticky_piston"] = BLOCK.AIR,
	["moving_piston"] = BLOCK.AIR,
	["tripwire"] = BLOCK.AIR,
	["tripwire_hook"] = BLOCK.AIR,
	["lever"] = BLOCK.AIR,
	["repeater"] = BLOCK.AIR,
	["comparator"] = BLOCK.AIR,
	["observer"] = BLOCK.AIR,
	["daylight_detector"] = BLOCK.AIR,

	-- Rails
	["rail"] = BLOCK.AIR,
	["powered_rail"] = BLOCK.AIR,
	["detector_rail"] = BLOCK.AIR,
	["activator_rail"] = BLOCK.AIR,

	-- Misc
	["flower_pot"] = BLOCK.AIR,
	["skeleton_skull"] = BLOCK.AIR,
	["wither_skeleton_skull"] = BLOCK.AIR,
	["zombie_head"] = BLOCK.AIR,
	["creeper_head"] = BLOCK.AIR,
	["dragon_head"] = BLOCK.AIR,
	["player_head"] = BLOCK.AIR,
	["standing_banner"] = BLOCK.AIR,
	["wall_banner"] = BLOCK.AIR,
	["cake"] = BLOCK.AIR,
	["bed"] = BLOCK.AIR,
	["item_frame"] = BLOCK.AIR,
	["glow_item_frame"] = BLOCK.AIR,
	["painting"] = BLOCK.AIR,
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════════

--- Get block ID for a Minecraft block name
--- @param baseName string The Minecraft block name (without metadata)
--- @return number|nil The block ID, or nil if not mapped
function BlockMapping.GetBlockId(baseName: string): number?
	return BlockMapping.Map[baseName]
end

--- Get block ID with fallback to STONE for unmapped blocks
--- @param baseName string The Minecraft block name
--- @return number The block ID (STONE if not mapped)
function BlockMapping.GetBlockIdWithFallback(baseName: string): number
	return BlockMapping.Map[baseName] or BLOCK.STONE
end

--- Check if a block name is mapped
--- @param baseName string The Minecraft block name
--- @return boolean True if the block is mapped
function BlockMapping.IsMapped(baseName: string): boolean
	return BlockMapping.Map[baseName] ~= nil
end

return BlockMapping
