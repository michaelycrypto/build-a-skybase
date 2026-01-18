--[[
	SchematicWorldGenerator.lua

	World generator that loads terrain from a pre-built Minecraft schematic.
	Implements the same interface as HubWorldGenerator/SkyblockGenerator so it
	integrates seamlessly with the existing chunk streaming system.

	The schematic is loaded once on construction, then GetBlockAt queries
	return blocks from the schematic data (or AIR for empty space).
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BaseWorldGenerator = require(script.Parent.BaseWorldGenerator)

local SchematicWorldGenerator = BaseWorldGenerator.extend({})

local BlockType = Constants.BlockType

-- ═══════════════════════════════════════════════════════════════════════════
-- MINECRAFT → ROBLOX BLOCK MAPPING
-- ═══════════════════════════════════════════════════════════════════════════

local BLOCK_MAPPING = {
	-- Core blocks
	["stone"] = BlockType.STONE,
	["dirt"] = BlockType.DIRT,
	["grass_block"] = BlockType.GRASS,
	["cobblestone"] = BlockType.COBBLESTONE,
	["bedrock"] = BlockType.BEDROCK,
	["sand"] = BlockType.SAND,
	["gravel"] = BlockType.GRAVEL,
	["clay"] = BlockType.DIRT,
	["coarse_dirt"] = BlockType.COARSE_DIRT,

	-- Stone variants
	["stone_bricks"] = BlockType.STONE_BRICKS,
	["mossy_stone_bricks"] = BlockType.STONE_BRICKS,
	["cracked_stone_bricks"] = BlockType.STONE_BRICKS,
	["chiseled_stone_bricks"] = BlockType.STONE_BRICKS,
	["mossy_cobblestone"] = BlockType.COBBLESTONE,
	["andesite"] = BlockType.ANDESITE,
	["polished_andesite"] = BlockType.POLISHED_ANDESITE,
	["diorite"] = BlockType.DIORITE,
	["polished_diorite"] = BlockType.POLISHED_DIORITE,
	["granite"] = BlockType.GRANITE,
	["polished_granite"] = BlockType.POLISHED_GRANITE,

	-- Bricks
	["bricks"] = BlockType.BRICKS,

	-- Glass
	["glass"] = BlockType.GLASS,

	-- Ores
	["coal_ore"] = BlockType.COAL_ORE,
	["iron_ore"] = BlockType.IRON_ORE,
	["diamond_ore"] = BlockType.DIAMOND_ORE,
	["copper_ore"] = BlockType.COPPER_ORE,

	-- Refined blocks
	["coal_block"] = BlockType.COAL_BLOCK,
	["iron_block"] = BlockType.IRON_BLOCK,
	["copper_block"] = BlockType.COPPER_BLOCK,

	-- Wood logs
	["oak_log"] = BlockType.WOOD,
	["oak_wood"] = BlockType.WOOD,
	["spruce_log"] = BlockType.SPRUCE_LOG,
	["spruce_wood"] = BlockType.SPRUCE_LOG,
	["birch_log"] = BlockType.BIRCH_LOG,
	["birch_wood"] = BlockType.BIRCH_LOG,
	["jungle_log"] = BlockType.JUNGLE_LOG,
	["jungle_wood"] = BlockType.JUNGLE_LOG,
	["acacia_log"] = BlockType.ACACIA_LOG,
	["acacia_wood"] = BlockType.ACACIA_LOG,
	["dark_oak_log"] = BlockType.DARK_OAK_LOG,
	["dark_oak_wood"] = BlockType.DARK_OAK_LOG,

	-- Planks
	["oak_planks"] = BlockType.OAK_PLANKS,
	["spruce_planks"] = BlockType.SPRUCE_PLANKS,
	["birch_planks"] = BlockType.BIRCH_PLANKS,
	["jungle_planks"] = BlockType.JUNGLE_PLANKS,
	["acacia_planks"] = BlockType.ACACIA_PLANKS,
	["dark_oak_planks"] = BlockType.DARK_OAK_PLANKS,

	-- Leaves
	["oak_leaves"] = BlockType.OAK_LEAVES,
	["spruce_leaves"] = BlockType.SPRUCE_LEAVES,
	["birch_leaves"] = BlockType.BIRCH_LEAVES,
	["jungle_leaves"] = BlockType.JUNGLE_LEAVES,
	["acacia_leaves"] = BlockType.ACACIA_LEAVES,
	["dark_oak_leaves"] = BlockType.DARK_OAK_LEAVES,

	-- Stairs
	["oak_stairs"] = BlockType.OAK_STAIRS,
	["spruce_stairs"] = BlockType.SPRUCE_STAIRS,
	["birch_stairs"] = BlockType.BIRCH_STAIRS,
	["jungle_stairs"] = BlockType.JUNGLE_STAIRS,
	["acacia_stairs"] = BlockType.ACACIA_STAIRS,
	["dark_oak_stairs"] = BlockType.DARK_OAK_STAIRS,
	["stone_stairs"] = BlockType.STONE_STAIRS,
	["cobblestone_stairs"] = BlockType.COBBLESTONE_STAIRS,
	["stone_brick_stairs"] = BlockType.STONE_BRICK_STAIRS,
	["brick_stairs"] = BlockType.BRICK_STAIRS,
	["sandstone_stairs"] = BlockType.SANDSTONE_STAIRS,
	["andesite_stairs"] = BlockType.ANDESITE_STAIRS,
	["diorite_stairs"] = BlockType.DIORITE_STAIRS,
	["granite_stairs"] = BlockType.GRANITE_STAIRS,
	["nether_brick_stairs"] = BlockType.NETHER_BRICK_STAIRS,

	-- Slabs
	["oak_slab"] = BlockType.OAK_SLAB,
	["spruce_slab"] = BlockType.SPRUCE_SLAB,
	["birch_slab"] = BlockType.BIRCH_SLAB,
	["jungle_slab"] = BlockType.JUNGLE_SLAB,
	["acacia_slab"] = BlockType.ACACIA_SLAB,
	["dark_oak_slab"] = BlockType.DARK_OAK_SLAB,
	["stone_slab"] = BlockType.STONE_SLAB,
	["cobblestone_slab"] = BlockType.COBBLESTONE_SLAB,
	["stone_brick_slab"] = BlockType.STONE_BRICK_SLAB,
	["brick_slab"] = BlockType.BRICK_SLAB,
	["andesite_slab"] = BlockType.STONE_SLAB,
	["sandstone_slab"] = BlockType.STONE_SLAB,
	["granite_slab"] = BlockType.GRANITE_SLAB,

	-- Fences
	["oak_fence"] = BlockType.OAK_FENCE,
	["spruce_fence"] = BlockType.OAK_FENCE,
	["birch_fence"] = BlockType.OAK_FENCE,
	["jungle_fence"] = BlockType.OAK_FENCE,
	["acacia_fence"] = BlockType.OAK_FENCE,
	["dark_oak_fence"] = BlockType.OAK_FENCE,
	["nether_brick_fence"] = BlockType.OAK_FENCE,

	-- Saplings
	["oak_sapling"] = BlockType.OAK_SAPLING,
	["spruce_sapling"] = BlockType.SPRUCE_SAPLING,
	["birch_sapling"] = BlockType.BIRCH_SAPLING,
	["jungle_sapling"] = BlockType.JUNGLE_SAPLING,
	["acacia_sapling"] = BlockType.ACACIA_SAPLING,
	["dark_oak_sapling"] = BlockType.DARK_OAK_SAPLING,

	-- Farmland & crops
	["farmland"] = BlockType.FARMLAND,
	["wheat"] = BlockType.WHEAT_CROP_7,
	["potatoes"] = BlockType.POTATO_CROP_3,
	["carrots"] = BlockType.CARROT_CROP_3,
	["beetroots"] = BlockType.BEETROOT_CROP_3,

	-- Utility blocks
	["crafting_table"] = BlockType.CRAFTING_TABLE,
	["furnace"] = BlockType.FURNACE,
	["chest"] = BlockType.CHEST,

	-- Decorative plants
	["grass"] = BlockType.TALL_GRASS,
	["tall_grass"] = BlockType.TALL_GRASS,
	["fern"] = BlockType.TALL_GRASS,
	["large_fern"] = BlockType.TALL_GRASS,
	["allium"] = BlockType.FLOWER,
	["azure_bluet"] = BlockType.FLOWER,
	["blue_orchid"] = BlockType.FLOWER,
	["cornflower"] = BlockType.FLOWER,
	["dandelion"] = BlockType.FLOWER,
	["lily_of_the_valley"] = BlockType.FLOWER,
	["orange_tulip"] = BlockType.FLOWER,
	["oxeye_daisy"] = BlockType.FLOWER,
	["pink_tulip"] = BlockType.FLOWER,
	["poppy"] = BlockType.FLOWER,
	["red_tulip"] = BlockType.FLOWER,
	["white_tulip"] = BlockType.FLOWER,
	["wither_rose"] = BlockType.FLOWER,
	["peony"] = BlockType.FLOWER,
	["rose_bush"] = BlockType.FLOWER,
	["lilac"] = BlockType.FLOWER,
	["sunflower"] = BlockType.FLOWER,

	-- Wool blocks (now with proper block types)
	["white_wool"] = BlockType.WHITE_WOOL,
	["orange_wool"] = BlockType.ORANGE_WOOL,
	["magenta_wool"] = BlockType.MAGENTA_WOOL,
	["light_blue_wool"] = BlockType.LIGHT_BLUE_WOOL,
	["yellow_wool"] = BlockType.YELLOW_WOOL,
	["lime_wool"] = BlockType.LIME_WOOL,
	["pink_wool"] = BlockType.PINK_WOOL,
	["gray_wool"] = BlockType.GRAY_WOOL,
	["light_gray_wool"] = BlockType.LIGHT_GRAY_WOOL,
	["cyan_wool"] = BlockType.CYAN_WOOL,
	["purple_wool"] = BlockType.PURPLE_WOOL,
	["blue_wool"] = BlockType.BLUE_WOOL,
	["brown_wool"] = BlockType.BROWN_WOOL,
	["green_wool"] = BlockType.GREEN_WOOL,
	["red_wool"] = BlockType.RED_WOOL,
	["black_wool"] = BlockType.BLACK_WOOL,

	-- Terracotta blocks (now with proper block types)
	["terracotta"] = BlockType.TERRACOTTA,
	["white_terracotta"] = BlockType.WHITE_TERRACOTTA,
	["orange_terracotta"] = BlockType.ORANGE_TERRACOTTA,
	["magenta_terracotta"] = BlockType.MAGENTA_TERRACOTTA,
	["light_blue_terracotta"] = BlockType.LIGHT_BLUE_TERRACOTTA,
	["yellow_terracotta"] = BlockType.YELLOW_TERRACOTTA,
	["lime_terracotta"] = BlockType.LIME_TERRACOTTA,
	["pink_terracotta"] = BlockType.PINK_TERRACOTTA,
	["gray_terracotta"] = BlockType.GRAY_TERRACOTTA,
	["light_gray_terracotta"] = BlockType.LIGHT_GRAY_TERRACOTTA,
	["cyan_terracotta"] = BlockType.CYAN_TERRACOTTA,
	["purple_terracotta"] = BlockType.PURPLE_TERRACOTTA,
	["blue_terracotta"] = BlockType.BLUE_TERRACOTTA,
	["brown_terracotta"] = BlockType.BROWN_TERRACOTTA,
	["green_terracotta"] = BlockType.GREEN_TERRACOTTA,
	["red_terracotta"] = BlockType.RED_TERRACOTTA,
	["black_terracotta"] = BlockType.BLACK_TERRACOTTA,

	-- Sandstone blocks
	["sandstone"] = BlockType.SANDSTONE,
	["smooth_sandstone"] = BlockType.SANDSTONE, -- Use same texture for now
	["chiseled_sandstone"] = BlockType.SANDSTONE, -- Use same texture for now
	["cut_sandstone"] = BlockType.SANDSTONE, -- Use same texture for now
	["red_sandstone"] = BlockType.SANDSTONE, -- Use same texture for now (could add red variant later)

	-- End blocks → Stone
	["end_stone"] = BlockType.STONE,
	["end_stone_bricks"] = BlockType.STONE_BRICKS,

	-- Quartz blocks
	["quartz_block"] = BlockType.QUARTZ_BLOCK,
	["smooth_quartz"] = BlockType.QUARTZ_BLOCK, -- Use same texture as quartz_block
	["chiseled_quartz_block"] = BlockType.CHISELED_QUARTZ_BLOCK,
	["quartz_pillar"] = BlockType.QUARTZ_PILLAR,
	["quartz_bricks"] = BlockType.QUARTZ_BLOCK, -- Use same texture as quartz_block

	-- Prismarine → Stone
	["prismarine"] = BlockType.STONE,
	["prismarine_bricks"] = BlockType.STONE_BRICKS,
	["dark_prismarine"] = BlockType.STONE,

	-- Smooth stone variants
	["smooth_stone"] = BlockType.STONE,
	["smooth_stone_slab"] = BlockType.STONE_SLAB,

	-- Stained glass panes (→ corresponding solid stained glass blocks)
	["glass_pane"] = BlockType.GLASS,
	["white_stained_glass_pane"] = BlockType.WHITE_STAINED_GLASS,
	["orange_stained_glass_pane"] = BlockType.ORANGE_STAINED_GLASS,
	["magenta_stained_glass_pane"] = BlockType.MAGENTA_STAINED_GLASS,
	["light_blue_stained_glass_pane"] = BlockType.LIGHT_BLUE_STAINED_GLASS,
	["yellow_stained_glass_pane"] = BlockType.YELLOW_STAINED_GLASS,
	["lime_stained_glass_pane"] = BlockType.LIME_STAINED_GLASS,
	["pink_stained_glass_pane"] = BlockType.PINK_STAINED_GLASS,
	["gray_stained_glass_pane"] = BlockType.GRAY_STAINED_GLASS,
	["light_gray_stained_glass_pane"] = BlockType.LIGHT_GRAY_STAINED_GLASS,
	["cyan_stained_glass_pane"] = BlockType.CYAN_STAINED_GLASS,
	["purple_stained_glass_pane"] = BlockType.PURPLE_STAINED_GLASS,
	["blue_stained_glass_pane"] = BlockType.BLUE_STAINED_GLASS,
	["brown_stained_glass_pane"] = BlockType.BROWN_STAINED_GLASS,
	["green_stained_glass_pane"] = BlockType.GREEN_STAINED_GLASS,
	["red_stained_glass_pane"] = BlockType.RED_STAINED_GLASS,
	["black_stained_glass_pane"] = BlockType.BLACK_STAINED_GLASS,

	-- Mushroom blocks (→ Wood as fallback)
	["brown_mushroom_block"] = BlockType.WOOD,
	["red_mushroom_block"] = BlockType.WOOD,
	["mushroom_stem"] = BlockType.WOOD,

	-- Short grass variant
	["short_grass"] = BlockType.TALL_GRASS,

	-- Wood variants (bark on all sides)
	["oak_wood"] = BlockType.WOOD,
	["spruce_wood"] = BlockType.SPRUCE_LOG,
	["birch_wood"] = BlockType.BIRCH_LOG,
	["jungle_wood"] = BlockType.JUNGLE_LOG,
	["acacia_wood"] = BlockType.ACACIA_LOG,
	["dark_oak_wood"] = BlockType.DARK_OAK_LOG,

	-- Terrain variants
	["podzol"] = BlockType.PODZOL,
	["sponge"] = BlockType.STONE,

	-- Infested blocks (→ normal versions)
	["infested_stone_bricks"] = BlockType.STONE_BRICKS,
	["infested_cobblestone"] = BlockType.COBBLESTONE,
	["infested_stone"] = BlockType.STONE,

	-- Walls (→ base material)
	["cobblestone_wall"] = BlockType.COBBLESTONE,
	["mossy_cobblestone_wall"] = BlockType.COBBLESTONE,
	["stone_brick_wall"] = BlockType.STONE_BRICKS,
	["brick_wall"] = BlockType.BRICKS,

	-- Iron bars
	["iron_bars"] = BlockType.GLASS,

	-- Chests & containers
	["trapped_chest"] = BlockType.CHEST,
	["ender_chest"] = BlockType.CHEST,

	-- Nether brick variants
	["nether_brick_stairs"] = BlockType.NETHER_BRICK_STAIRS,
	["nether_brick_slab"] = BlockType.STONE_SLAB,
	["nether_bricks"] = BlockType.NETHER_BRICKS,

	-- Blackstone (uses bedrock texture)
	["blackstone"] = BlockType.BLACKSTONE,
	["blackstone_stairs"] = BlockType.STONE_STAIRS, -- Map to stone stairs
	["blackstone_slab"] = BlockType.STONE_SLAB, -- Map to stone slab

	-- Quartz variants
	["quartz_stairs"] = BlockType.QUARTZ_STAIRS,
	["quartz_slab"] = BlockType.STONE_SLAB,
	["smooth_quartz_slab"] = BlockType.SMOOTH_QUARTZ_SLAB,

	-- Sandstone variants (already mapped above, but keeping for reference)
	-- ["sandstone_stairs"] = BlockType.SANDSTONE_STAIRS, -- Mapped above
	["cut_sandstone_slab"] = BlockType.STONE_SLAB,

	-- Solid stained glass (not panes) - now with proper block types
	["white_stained_glass"] = BlockType.WHITE_STAINED_GLASS,
	["orange_stained_glass"] = BlockType.ORANGE_STAINED_GLASS,
	["magenta_stained_glass"] = BlockType.MAGENTA_STAINED_GLASS,
	["light_blue_stained_glass"] = BlockType.LIGHT_BLUE_STAINED_GLASS,
	["yellow_stained_glass"] = BlockType.YELLOW_STAINED_GLASS,
	["lime_stained_glass"] = BlockType.LIME_STAINED_GLASS,
	["pink_stained_glass"] = BlockType.PINK_STAINED_GLASS,
	["gray_stained_glass"] = BlockType.GRAY_STAINED_GLASS,
	["light_gray_stained_glass"] = BlockType.LIGHT_GRAY_STAINED_GLASS,
	["cyan_stained_glass"] = BlockType.CYAN_STAINED_GLASS,
	["purple_stained_glass"] = BlockType.PURPLE_STAINED_GLASS,
	["blue_stained_glass"] = BlockType.BLUE_STAINED_GLASS,
	["brown_stained_glass"] = BlockType.BROWN_STAINED_GLASS,
	["green_stained_glass"] = BlockType.GREEN_STAINED_GLASS,
	["red_stained_glass"] = BlockType.RED_STAINED_GLASS,
	["black_stained_glass"] = BlockType.BLACK_STAINED_GLASS,

	-- Light sources
	["sea_lantern"] = BlockType.GLASS,
	["glowstone"] = BlockType.STONE,
	["lantern"] = BlockType.GLASS,
	["soul_lantern"] = BlockType.GLASS,

	-- Unsupported utility blocks (→ AIR)
	["cauldron"] = BlockType.AIR,
	["hopper"] = BlockType.AIR,
	["ladder"] = BlockType.AIR,
	["oak_trapdoor"] = BlockType.AIR,
	["spruce_trapdoor"] = BlockType.AIR,
	["birch_trapdoor"] = BlockType.AIR,
	["jungle_trapdoor"] = BlockType.AIR,
	["acacia_trapdoor"] = BlockType.AIR,
	["dark_oak_trapdoor"] = BlockType.AIR,
	["iron_trapdoor"] = BlockType.AIR,
	["oak_wall_sign"] = BlockType.AIR,
	["spruce_wall_sign"] = BlockType.AIR,
	["birch_wall_sign"] = BlockType.AIR,
	["jungle_wall_sign"] = BlockType.AIR,
	["acacia_wall_sign"] = BlockType.AIR,
	["dark_oak_wall_sign"] = BlockType.AIR,
	["oak_sign"] = BlockType.AIR,
	["wither_skeleton_skull"] = BlockType.AIR,
	["skeleton_skull"] = BlockType.AIR,
	["zombie_head"] = BlockType.AIR,
	["creeper_head"] = BlockType.AIR,

	-- Carpets (→ AIR, too thin)
	["white_carpet"] = BlockType.AIR,
	["orange_carpet"] = BlockType.AIR,
	["magenta_carpet"] = BlockType.AIR,
	["light_blue_carpet"] = BlockType.AIR,
	["yellow_carpet"] = BlockType.AIR,
	["lime_carpet"] = BlockType.AIR,
	["pink_carpet"] = BlockType.AIR,
	["gray_carpet"] = BlockType.AIR,
	["light_gray_carpet"] = BlockType.AIR,
	["cyan_carpet"] = BlockType.AIR,
	["purple_carpet"] = BlockType.AIR,
	["blue_carpet"] = BlockType.AIR,
	["brown_carpet"] = BlockType.AIR,
	["green_carpet"] = BlockType.AIR,
	["red_carpet"] = BlockType.AIR,
	["black_carpet"] = BlockType.AIR,

	-- Concrete blocks (16 colors)
	["white_concrete"] = BlockType.WHITE_CONCRETE,
	["orange_concrete"] = BlockType.ORANGE_CONCRETE,
	["magenta_concrete"] = BlockType.MAGENTA_CONCRETE,
	["light_blue_concrete"] = BlockType.LIGHT_BLUE_CONCRETE,
	["yellow_concrete"] = BlockType.YELLOW_CONCRETE,
	["lime_concrete"] = BlockType.LIME_CONCRETE,
	["pink_concrete"] = BlockType.PINK_CONCRETE,
	["gray_concrete"] = BlockType.GRAY_CONCRETE,
	["light_gray_concrete"] = BlockType.LIGHT_GRAY_CONCRETE,
	["cyan_concrete"] = BlockType.CYAN_CONCRETE,
	["purple_concrete"] = BlockType.PURPLE_CONCRETE,
	["blue_concrete"] = BlockType.BLUE_CONCRETE,
	["brown_concrete"] = BlockType.BROWN_CONCRETE,
	["green_concrete"] = BlockType.GREEN_CONCRETE,
	["red_concrete"] = BlockType.RED_CONCRETE,
	["black_concrete"] = BlockType.BLACK_CONCRETE,

	-- Concrete powder blocks (16 colors)
	["white_concrete_powder"] = BlockType.WHITE_CONCRETE_POWDER,
	["orange_concrete_powder"] = BlockType.ORANGE_CONCRETE_POWDER,
	["magenta_concrete_powder"] = BlockType.MAGENTA_CONCRETE_POWDER,
	["light_blue_concrete_powder"] = BlockType.LIGHT_BLUE_CONCRETE_POWDER,
	["yellow_concrete_powder"] = BlockType.YELLOW_CONCRETE_POWDER,
	["lime_concrete_powder"] = BlockType.LIME_CONCRETE_POWDER,
	["pink_concrete_powder"] = BlockType.PINK_CONCRETE_POWDER,
	["gray_concrete_powder"] = BlockType.GRAY_CONCRETE_POWDER,
	["light_gray_concrete_powder"] = BlockType.LIGHT_GRAY_CONCRETE_POWDER,
	["cyan_concrete_powder"] = BlockType.CYAN_CONCRETE_POWDER,
	["purple_concrete_powder"] = BlockType.PURPLE_CONCRETE_POWDER,
	["blue_concrete_powder"] = BlockType.BLUE_CONCRETE_POWDER,
	["brown_concrete_powder"] = BlockType.BROWN_CONCRETE_POWDER,
	["green_concrete_powder"] = BlockType.GREEN_CONCRETE_POWDER,
	["red_concrete_powder"] = BlockType.RED_CONCRETE_POWDER,
	["black_concrete_powder"] = BlockType.BLACK_CONCRETE_POWDER,

	-- Air variants
	["air"] = BlockType.AIR,
	["cave_air"] = BlockType.AIR,
	["void_air"] = BlockType.AIR,
	["water"] = BlockType.AIR,
	["lava"] = BlockType.AIR,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- METADATA PARSING
-- ═══════════════════════════════════════════════════════════════════════════

local FACING_TO_ROTATION = {
	["n"] = Constants.BlockMetadata.ROTATION_NORTH,
	["e"] = Constants.BlockMetadata.ROTATION_EAST,
	["s"] = Constants.BlockMetadata.ROTATION_SOUTH,
	["w"] = Constants.BlockMetadata.ROTATION_WEST,
	["north"] = Constants.BlockMetadata.ROTATION_NORTH,
	["east"] = Constants.BlockMetadata.ROTATION_EAST,
	["south"] = Constants.BlockMetadata.ROTATION_SOUTH,
	["west"] = Constants.BlockMetadata.ROTATION_WEST,
}

local HALF_TO_VERTICAL = {
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
}

local SHAPE_TO_STAIR = {
	["st"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["straight"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["ol"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["outer_left"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["or"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
	["outer_right"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
	["il"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["inner_left"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["ir"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
	["inner_right"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
}

local function parseBlockEntry(paletteEntry)
	local baseName, metadataStr = string.match(paletteEntry, "^([^%[]+)%[(.+)%]$")
	if not baseName then
		return paletteEntry, nil
	end

	local properties = {}
	for key, value in string.gmatch(metadataStr, "([^,=]+)=([^,=]+)") do
		properties[key] = value
	end

	return baseName, properties
end

local function convertMetadata(baseName, properties)
	if not properties then
		return 0
	end

	local metadata = 0

	if properties.f and FACING_TO_ROTATION[properties.f] then
		metadata = Constants.SetRotation(metadata, FACING_TO_ROTATION[properties.f])
	end

	if properties.h and HALF_TO_VERTICAL[properties.h] then
		metadata = Constants.SetVerticalOrientation(metadata, HALF_TO_VERTICAL[properties.h])
	end

	if properties.s and SHAPE_TO_STAIR[properties.s] then
		metadata = Constants.SetStairShape(metadata, SHAPE_TO_STAIR[properties.s])
	end

	if properties.t then
		if properties.t == "db" or properties.t == "double" then
			metadata = Constants.SetDoubleSlabFlag(metadata, true)
		elseif properties.t == "t" or properties.t == "top" then
			metadata = Constants.SetVerticalOrientation(metadata, Constants.BlockMetadata.VERTICAL_TOP)
		end
	end

	return metadata
end

local function getBlockId(baseName)
	return BLOCK_MAPPING[baseName]
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GENERATOR IMPLEMENTATION
-- ═══════════════════════════════════════════════════════════════════════════

function SchematicWorldGenerator.new(seed: number, overrides)
	overrides = overrides or {}

	local self = setmetatable({}, SchematicWorldGenerator)
	BaseWorldGenerator._init(self, "SchematicWorldGenerator", seed, overrides)

	-- Configuration
	self._config = {
		offsetX = overrides.offsetX or 0,
		offsetY = overrides.offsetY or 0,
		offsetZ = overrides.offsetZ or 0,
		spawnX = overrides.spawnX,
		spawnY = overrides.spawnY,
		spawnZ = overrides.spawnZ,
	}

	-- Chunk bounds for early-out on empty chunks
	self._chunkBounds = overrides.chunkBounds

	-- Load schematic data
	self._schematicData = nil
	self._processedPalette = {}
	self._blockLookup = {} -- [chunkKey][columnKey] = array of {startY, length, blockId, metadata}
	self._occupiedChunks = {}
	self._minY = 256
	self._maxY = 0
	self._schematicSize = { width = 0, height = 0, length = 0 }

	-- Load schematic from ServerStorage if specified
	local schematicPath = overrides.schematicPath or "Schematics.Medieval_Skyblock_Spawn"
	self:_loadSchematic(schematicPath)

	-- Calculate spawn position
	self._spawnPosition = self:_computeSpawnPosition()

	return self
end

function SchematicWorldGenerator:_loadSchematic(path)
	local ServerStorage = game:GetService("ServerStorage")

	-- Parse path like "Schematics.Medieval_Skyblock_Spawn"
	local parts = string.split(path, ".")
	local current = ServerStorage
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then
			warn("[SchematicWorldGenerator] Could not find schematic at path:", path)
			return
		end
	end

	local ok, schematicData = pcall(require, current)
	if not ok then
		warn("[SchematicWorldGenerator] Failed to require schematic module:", schematicData)
		return
	end

	self._schematicData = schematicData
	self._schematicSize = schematicData.size or { width = 0, height = 0, length = 0 }

	-- Process palette
	local palette = schematicData.palette or {}
	for i, entry in ipairs(palette) do
		local baseName, properties = parseBlockEntry(entry)
		local blockId = getBlockId(baseName)
		local metadata = convertMetadata(baseName, properties)

		if blockId and blockId ~= BlockType.AIR then
			self._processedPalette[i] = {
				blockId = blockId,
				metadata = metadata,
			}
		end
	end

	-- Build lookup tables for fast GetBlockAt queries
	local chunks = schematicData.chunks or {}
	local offsetX = self._config.offsetX
	local offsetY = self._config.offsetY
	local offsetZ = self._config.offsetZ

	for chunkKey, chunkData in pairs(chunks) do
		local schematicChunkX, schematicChunkZ = string.match(chunkKey, "^(-?%d+),(-?%d+)$")
		schematicChunkX = tonumber(schematicChunkX)
		schematicChunkZ = tonumber(schematicChunkZ)

		if schematicChunkX and schematicChunkZ then
			for columnKey, runs in pairs(chunkData) do
				local localX, localZ = string.match(columnKey, "^(-?%d+),(-?%d+)$")
				localX = tonumber(localX)
				localZ = tonumber(localZ)

				if localX and localZ then
					-- Calculate world coordinates with offset
					local worldX = schematicChunkX * 16 + localX + offsetX
					local worldZ = schematicChunkZ * 16 + localZ + offsetZ

					-- Calculate destination chunk
					local destChunkX = math.floor(worldX / Constants.CHUNK_SIZE_X)
					local destChunkZ = math.floor(worldZ / Constants.CHUNK_SIZE_Z)
					local destChunkKey = string.format("%d,%d", destChunkX, destChunkZ)

					-- Mark chunk as occupied
					self._occupiedChunks[destChunkKey] = true

					-- Create column lookup
					if not self._blockLookup[destChunkKey] then
						self._blockLookup[destChunkKey] = {}
					end

					local destLocalX = worldX - destChunkX * Constants.CHUNK_SIZE_X
					local destLocalZ = worldZ - destChunkZ * Constants.CHUNK_SIZE_Z
					local destColumnKey = string.format("%d,%d", destLocalX, destLocalZ)

					-- Process RLE runs
					local processedRuns = {}
					for _, run in ipairs(runs) do
						local startY = run[1] + offsetY
						local length = run[2]
						local paletteIndex = run[3]

						local blockInfo = self._processedPalette[paletteIndex]
						if blockInfo then
							table.insert(processedRuns, {
								startY = startY,
								length = length,
								blockId = blockInfo.blockId,
								metadata = blockInfo.metadata,
							})

							-- Track Y bounds
							local endY = startY + length - 1
							if startY < self._minY then self._minY = startY end
							if endY > self._maxY then self._maxY = endY end
						end
					end

					if #processedRuns > 0 then
						self._blockLookup[destChunkKey][destColumnKey] = processedRuns
					end
				end
			end
		end
	end

	print(string.format("[SchematicWorldGenerator] Loaded schematic: %dx%dx%d, Y range: %d-%d, %d chunks",
		self._schematicSize.width, self._schematicSize.height, self._schematicSize.length,
		self._minY, self._maxY, self:_countOccupiedChunks()))
end

function SchematicWorldGenerator:_countOccupiedChunks()
	local count = 0
	for _ in pairs(self._occupiedChunks) do
		count = count + 1
	end
	return count
end

function SchematicWorldGenerator:_computeSpawnPosition()
	local config = self._config

	-- Use explicit spawn position if provided
	if config.spawnX and config.spawnY and config.spawnZ then
		return Vector3.new(
			config.spawnX * Constants.BLOCK_SIZE,
			config.spawnY * Constants.BLOCK_SIZE,
			config.spawnZ * Constants.BLOCK_SIZE
		)
	end

	-- Default: center of schematic at top Y + 2
	local centerX = config.offsetX + self._schematicSize.width / 2
	local centerZ = config.offsetZ + self._schematicSize.length / 2
	local spawnY = self._maxY + 2

	-- Try to find a solid block near center to spawn on
	local testY = self:_findSurfaceY(math.floor(centerX), math.floor(centerZ))
	if testY then
		spawnY = testY + 2
	end

	return Vector3.new(
		math.floor(centerX) * Constants.BLOCK_SIZE,
		spawnY * Constants.BLOCK_SIZE,
		math.floor(centerZ) * Constants.BLOCK_SIZE
	)
end

function SchematicWorldGenerator:_findSurfaceY(wx, wz)
	local chunkX = math.floor(wx / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(wz / Constants.CHUNK_SIZE_Z)
	local chunkKey = string.format("%d,%d", chunkX, chunkZ)

	local chunkData = self._blockLookup[chunkKey]
	if not chunkData then
		return nil
	end

	local localX = wx - chunkX * Constants.CHUNK_SIZE_X
	local localZ = wz - chunkZ * Constants.CHUNK_SIZE_Z
	local columnKey = string.format("%d,%d", localX, localZ)

	local runs = chunkData[columnKey]
	if not runs or #runs == 0 then
		return nil
	end

	-- Find highest block in column
	local highestY = 0
	for _, run in ipairs(runs) do
		local endY = run.startY + run.length - 1
		if endY > highestY then
			highestY = endY
		end
	end

	return highestY
end

function SchematicWorldGenerator:GetBlockAt(wx: number, wy: number, wz: number): number
	-- Fast bounds check
	if wy < self._minY or wy > self._maxY then
		return BlockType.AIR
	end

	local chunkX = math.floor(wx / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(wz / Constants.CHUNK_SIZE_Z)
	local chunkKey = string.format("%d,%d", chunkX, chunkZ)

	local chunkData = self._blockLookup[chunkKey]
	if not chunkData then
		return BlockType.AIR
	end

	local localX = wx - chunkX * Constants.CHUNK_SIZE_X
	local localZ = wz - chunkZ * Constants.CHUNK_SIZE_Z
	local columnKey = string.format("%d,%d", localX, localZ)

	local runs = chunkData[columnKey]
	if not runs then
		return BlockType.AIR
	end

	-- Binary search could be used here for very tall columns, but linear is fine for most cases
	for _, run in ipairs(runs) do
		if wy >= run.startY and wy < run.startY + run.length then
			return run.blockId
		end
	end

	return BlockType.AIR
end

function SchematicWorldGenerator:GetBlockMetadataAt(wx: number, wy: number, wz: number): number
	if wy < self._minY or wy > self._maxY then
		return 0
	end

	local chunkX = math.floor(wx / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(wz / Constants.CHUNK_SIZE_Z)
	local chunkKey = string.format("%d,%d", chunkX, chunkZ)

	local chunkData = self._blockLookup[chunkKey]
	if not chunkData then
		return 0
	end

	local localX = wx - chunkX * Constants.CHUNK_SIZE_X
	local localZ = wz - chunkZ * Constants.CHUNK_SIZE_Z
	local columnKey = string.format("%d,%d", localX, localZ)

	local runs = chunkData[columnKey]
	if not runs then
		return 0
	end

	for _, run in ipairs(runs) do
		if wy >= run.startY and wy < run.startY + run.length then
			return run.metadata or 0
		end
	end

	return 0
end

function SchematicWorldGenerator:IsChunkEmpty(chunkX: number, chunkZ: number): boolean
	local key = string.format("%d,%d", math.floor(chunkX), math.floor(chunkZ))
	return not self._occupiedChunks[key]
end

function SchematicWorldGenerator:GenerateChunk(chunk)
	local chunkWorldX = chunk.x * Constants.CHUNK_SIZE_X
	local chunkWorldZ = chunk.z * Constants.CHUNK_SIZE_Z
	local chunkKey = string.format("%d,%d", chunk.x, chunk.z)

	-- Fast early-out for empty chunks
	if not self._occupiedChunks[chunkKey] then
		chunk.state = Constants.ChunkState.READY
		return
	end

	local chunkData = self._blockLookup[chunkKey]
	if not chunkData then
		chunk.state = Constants.ChunkState.READY
		return
	end

	-- Generate blocks from lookup table
	for columnKey, runs in pairs(chunkData) do
		local localX, localZ = string.match(columnKey, "^(-?%d+),(-?%d+)$")
		localX = tonumber(localX)
		localZ = tonumber(localZ)

		if localX and localZ then
			local highestY = 0

			for _, run in ipairs(runs) do
				for dy = 0, run.length - 1 do
					local y = run.startY + dy
					if y >= 0 and y < Constants.WORLD_HEIGHT then
						chunk:SetBlock(localX, y, localZ, run.blockId)

						-- Set metadata if non-zero
						if run.metadata and run.metadata ~= 0 then
							chunk:SetMetadata(localX, y, localZ, run.metadata)
						end

						if y > highestY then
							highestY = y
						end
					end
				end
			end

			-- Update height map
			if chunk.heightMap then
				local idx = localX + localZ * Constants.CHUNK_SIZE_X
				chunk.heightMap[idx] = highestY
			end
		end
	end

	chunk.state = Constants.ChunkState.READY
end

function SchematicWorldGenerator:GetSpawnPosition(): Vector3
	return self._spawnPosition
end

function SchematicWorldGenerator:GetChunkBounds()
	return self._chunkBounds
end

return SchematicWorldGenerator
