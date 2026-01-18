--[[
	SchematicImporter.lua

	Imports Minecraft schematics (converted to Lua RLE format) into the voxel world.

	Usage:
		local SchematicImporter = require(path.to.SchematicImporter)
		local blocksPlaced = SchematicImporter.import({
			schematic = ServerStorage.Medieval_Skyblock_Spawn,
			worldManager = worldManager,  -- WorldManager instance
			offset = Vector3.new(0, 0, 0),
			onProgress = function(placed, total) print(placed, "/", total) end,
		})
]]

local RunService = game:GetService("RunService")

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local logger = Logger:CreateContext("SchematicImporter")

local SchematicImporter = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- MINECRAFT → ROBLOX BLOCK MAPPING
-- Maps Minecraft block base names to our Constants.BlockType enum
-- ═══════════════════════════════════════════════════════════════════════════

local BLOCK = Constants.BlockType

-- Primary mappings: exact matches
local BLOCK_MAPPING = {
	-- Core blocks
	["stone"] = BLOCK.STONE,
	["dirt"] = BLOCK.DIRT,
	["grass_block"] = BLOCK.GRASS,
	["cobblestone"] = BLOCK.COBBLESTONE,
	["bedrock"] = BLOCK.BEDROCK,
	["sand"] = BLOCK.SAND,
	["gravel"] = BLOCK.GRAVEL,
	["clay"] = BLOCK.DIRT,
	["coarse_dirt"] = BLOCK.COARSE_DIRT,

	-- Stone variants (map to closest equivalents)
	["stone_bricks"] = BLOCK.STONE_BRICKS,
	["mossy_stone_bricks"] = BLOCK.STONE_BRICKS,
	["cracked_stone_bricks"] = BLOCK.STONE_BRICKS,
	["chiseled_stone_bricks"] = BLOCK.STONE_BRICKS,
	["mossy_cobblestone"] = BLOCK.COBBLESTONE,
	["andesite"] = BLOCK.ANDESITE,
	["polished_andesite"] = BLOCK.POLISHED_ANDESITE,
	["diorite"] = BLOCK.DIORITE,
	["polished_diorite"] = BLOCK.POLISHED_DIORITE,
	["granite"] = BLOCK.GRANITE,
	["polished_granite"] = BLOCK.POLISHED_GRANITE,

	-- Bricks
	["bricks"] = BLOCK.BRICKS,

	-- Glass
	["glass"] = BLOCK.GLASS,

	-- Stained Glass blocks (16 colors)
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

	-- Stained Glass Panes (→ corresponding solid blocks)
	["glass_pane"] = BLOCK.GLASS,
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

	-- Ores
	["coal_ore"] = BLOCK.COAL_ORE,
	["iron_ore"] = BLOCK.IRON_ORE,
	["diamond_ore"] = BLOCK.DIAMOND_ORE,
	["copper_ore"] = BLOCK.COPPER_ORE,

	-- Refined blocks
	["coal_block"] = BLOCK.COAL_BLOCK,
	["iron_block"] = BLOCK.IRON_BLOCK,
	["copper_block"] = BLOCK.COPPER_BLOCK,

	-- Wood logs (all variants → WOOD for now, or specific if available)
	["oak_log"] = BLOCK.WOOD,
	["oak_wood"] = BLOCK.WOOD,
	["spruce_log"] = BLOCK.SPRUCE_LOG,
	["spruce_wood"] = BLOCK.SPRUCE_LOG,
	["birch_log"] = BLOCK.BIRCH_LOG,
	["birch_wood"] = BLOCK.BIRCH_LOG,
	["jungle_log"] = BLOCK.JUNGLE_LOG,
	["jungle_wood"] = BLOCK.JUNGLE_LOG,
	["acacia_log"] = BLOCK.ACACIA_LOG,
	["acacia_wood"] = BLOCK.ACACIA_LOG,
	["dark_oak_log"] = BLOCK.DARK_OAK_LOG,
	["dark_oak_wood"] = BLOCK.DARK_OAK_LOG,

	-- Planks
	["oak_planks"] = BLOCK.OAK_PLANKS,
	["spruce_planks"] = BLOCK.SPRUCE_PLANKS,
	["birch_planks"] = BLOCK.BIRCH_PLANKS,
	["jungle_planks"] = BLOCK.JUNGLE_PLANKS,
	["acacia_planks"] = BLOCK.ACACIA_PLANKS,
	["dark_oak_planks"] = BLOCK.DARK_OAK_PLANKS,

	-- Leaves
	["oak_leaves"] = BLOCK.OAK_LEAVES,
	["spruce_leaves"] = BLOCK.SPRUCE_LEAVES,
	["birch_leaves"] = BLOCK.BIRCH_LEAVES,
	["jungle_leaves"] = BLOCK.JUNGLE_LEAVES,
	["acacia_leaves"] = BLOCK.ACACIA_LEAVES,
	["dark_oak_leaves"] = BLOCK.DARK_OAK_LEAVES,

	-- Stairs
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

	-- Slabs
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
	["andesite_slab"] = BLOCK.STONE_SLAB,
	["sandstone_slab"] = BLOCK.STONE_SLAB,
	["granite_slab"] = BLOCK.GRANITE_SLAB,
	
	-- Fences (all map to oak fence for now)
	["oak_fence"] = BLOCK.OAK_FENCE,
	["spruce_fence"] = BLOCK.OAK_FENCE,
	["birch_fence"] = BLOCK.OAK_FENCE,
	["jungle_fence"] = BLOCK.OAK_FENCE,
	["acacia_fence"] = BLOCK.OAK_FENCE,
	["dark_oak_fence"] = BLOCK.OAK_FENCE,
	["nether_brick_fence"] = BLOCK.OAK_FENCE,

	-- Saplings
	["oak_sapling"] = BLOCK.OAK_SAPLING,
	["spruce_sapling"] = BLOCK.SPRUCE_SAPLING,
	["birch_sapling"] = BLOCK.BIRCH_SAPLING,
	["jungle_sapling"] = BLOCK.JUNGLE_SAPLING,
	["acacia_sapling"] = BLOCK.ACACIA_SAPLING,
	["dark_oak_sapling"] = BLOCK.DARK_OAK_SAPLING,

	-- Farmland & crops
	["farmland"] = BLOCK.FARMLAND,
	["wheat"] = BLOCK.WHEAT_CROP_7,
	["potatoes"] = BLOCK.POTATO_CROP_3,
	["carrots"] = BLOCK.CARROT_CROP_3,
	["beetroots"] = BLOCK.BEETROOT_CROP_3,

	-- Utility blocks
	["crafting_table"] = BLOCK.CRAFTING_TABLE,
	["furnace"] = BLOCK.FURNACE,
	["chest"] = BLOCK.CHEST,

	-- Decorative plants (map to closest)
	["grass"] = BLOCK.TALL_GRASS,
	["tall_grass"] = BLOCK.TALL_GRASS,
	["short_grass"] = BLOCK.TALL_GRASS,
	["fern"] = BLOCK.TALL_GRASS,
	["large_fern"] = BLOCK.TALL_GRASS,
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

	-- Wool blocks (16 colors)
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

	-- Terracotta blocks (17 colors)
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

	-- Concrete blocks (16 colors)
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

	-- Concrete powder blocks (16 colors)
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

	-- Sandstone blocks
	["sandstone"] = BLOCK.SANDSTONE,
	["smooth_sandstone"] = BLOCK.SANDSTONE,
	["chiseled_sandstone"] = BLOCK.SANDSTONE,
	["cut_sandstone"] = BLOCK.SANDSTONE,
	["red_sandstone"] = BLOCK.SANDSTONE, -- Use same texture for now

	-- End blocks → Stone
	["end_stone"] = BLOCK.STONE,
	["end_stone_bricks"] = BLOCK.STONE_BRICKS,

	-- Nether Bricks
	["nether_bricks"] = BLOCK.NETHER_BRICKS,
	["nether_brick_stairs"] = BLOCK.NETHER_BRICK_STAIRS,
	["nether_brick_slab"] = BLOCK.STONE_SLAB,

	-- Blackstone (uses bedrock texture)
	["blackstone"] = BLOCK.BLACKSTONE,
	["blackstone_stairs"] = BLOCK.STONE_STAIRS, -- Map to stone stairs
	["blackstone_slab"] = BLOCK.BLACKSTONE_SLAB,

	-- Quartz blocks
	["quartz_block"] = BLOCK.QUARTZ_BLOCK,
	["smooth_quartz"] = BLOCK.QUARTZ_BLOCK, -- Use same texture as quartz_block
	["chiseled_quartz_block"] = BLOCK.CHISELED_QUARTZ_BLOCK,
	["quartz_pillar"] = BLOCK.QUARTZ_PILLAR,
	["quartz_bricks"] = BLOCK.QUARTZ_BLOCK, -- Use same texture as quartz_block
	["smooth_quartz_slab"] = BLOCK.SMOOTH_QUARTZ_SLAB,

	-- Prismarine → Stone
	["prismarine"] = BLOCK.STONE,
	["prismarine_bricks"] = BLOCK.STONE_BRICKS,
	["dark_prismarine"] = BLOCK.STONE,

	-- Additional terrain blocks
	["podzol"] = BLOCK.PODZOL,
	["sponge"] = BLOCK.STONE,

	-- Mushroom blocks (→ Wood as fallback)
	["brown_mushroom_block"] = BLOCK.WOOD,
	["red_mushroom_block"] = BLOCK.WOOD,
	["mushroom_stem"] = BLOCK.WOOD,

	-- Special blocks (skip or map to air)
	["air"] = BLOCK.AIR,
	["cave_air"] = BLOCK.AIR,
	["void_air"] = BLOCK.AIR,
	["water"] = BLOCK.AIR, -- Skip water for now
	["lava"] = BLOCK.AIR, -- Skip lava for now
}

-- ═══════════════════════════════════════════════════════════════════════════
-- METADATA PARSING
-- Converts Minecraft block state metadata to our Constants.BlockMetadata format
-- ═══════════════════════════════════════════════════════════════════════════

-- Direction mapping: Minecraft cardinal → our rotation constants
local FACING_TO_ROTATION = {
	["n"] = Constants.BlockMetadata.ROTATION_NORTH, -- North = +Z
	["e"] = Constants.BlockMetadata.ROTATION_EAST,  -- East = +X
	["s"] = Constants.BlockMetadata.ROTATION_SOUTH, -- South = -Z
	["w"] = Constants.BlockMetadata.ROTATION_WEST,  -- West = -X
	["north"] = Constants.BlockMetadata.ROTATION_NORTH,
	["east"] = Constants.BlockMetadata.ROTATION_EAST,
	["south"] = Constants.BlockMetadata.ROTATION_SOUTH,
	["west"] = Constants.BlockMetadata.ROTATION_WEST,
}

-- Half mapping: Minecraft half → our vertical constants
local HALF_TO_VERTICAL = {
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
}

-- Stair shape mapping
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

-- Slab type mapping
local SLAB_TYPE_TO_VERTICAL = {
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	["db"] = nil, -- Double slab handled separately
	["double"] = nil,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PARSING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

--- Parse block name and metadata from palette entry
--- @param paletteEntry string e.g. "cobblestone_stairs[f=n,h=b,s=st]"
--- @return string baseName, table|nil properties
local function parseBlockEntry(paletteEntry)
	-- Check for metadata in brackets
	local baseName, metadataStr = string.match(paletteEntry, "^([^%[]+)%[(.+)%]$")
	if not baseName then
		return paletteEntry, nil
	end

	-- Parse key=value pairs
	local properties = {}
	for key, value in string.gmatch(metadataStr, "([^,=]+)=([^,=]+)") do
		properties[key] = value
	end

	return baseName, properties
end

--- Convert Minecraft metadata to our BlockMetadata byte
--- @param properties table|nil Parsed properties from block name
--- @param baseName string The base block name (for context)
--- @return number metadata Our BlockMetadata format (0-255)
local function convertMetadata(baseName, properties)
	if not properties then
		return 0
	end

	local metadata = 0

	-- Handle facing (f)
	if properties.f and FACING_TO_ROTATION[properties.f] then
		metadata = Constants.SetRotation(metadata, FACING_TO_ROTATION[properties.f])
	end

	-- Handle half (h) for stairs/slabs
	if properties.h and HALF_TO_VERTICAL[properties.h] then
		metadata = Constants.SetVerticalOrientation(metadata, HALF_TO_VERTICAL[properties.h])
	end

	-- Handle stair shape (s)
	if properties.s and SHAPE_TO_STAIR[properties.s] then
		metadata = Constants.SetStairShape(metadata, SHAPE_TO_STAIR[properties.s])
	end

	-- Handle slab type (t) for slabs
	if properties.t then
		if properties.t == "db" or properties.t == "double" then
			-- Double slab: set the double flag
			metadata = Constants.SetDoubleSlabFlag(metadata, true)
		elseif SLAB_TYPE_TO_VERTICAL[properties.t] then
			metadata = Constants.SetVerticalOrientation(metadata, SLAB_TYPE_TO_VERTICAL[properties.t])
		end
	end

	return metadata
end

--- Get block ID from Minecraft block name
--- @param baseName string The base block name (without metadata)
--- @return number|nil blockId Our BlockType ID, or nil if unmapped
local function getBlockId(baseName)
	-- Direct lookup first
	local blockId = BLOCK_MAPPING[baseName]
	if blockId then
		return blockId
	end

	-- Skip certain decoration blocks that we don't support yet
	-- Note: "pane" removed since we now support stained glass panes
	local skipPatterns = {
		"trapdoor", "button", "sign", "wall", "fence_gate",
		"carpet", "banner", "head", "skull", "pot",
		"lantern", "lamp", "note_block", "piston",
		"cauldron", "hopper", "dragon_egg", "flower_pot",
		"potted_", "vine", -- Skip vines for now
	}

	for _, pattern in ipairs(skipPatterns) do
		if string.find(baseName, pattern) then
			return nil -- Skip these blocks
		end
	end

	-- Warn about unmapped blocks (only once per type)
	return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAIN IMPORT FUNCTION
-- ═══════════════════════════════════════════════════════════════════════════

--- Import a schematic into the voxel world
--- @param options table Import options
--- @return number blocksPlaced Number of blocks successfully placed
function SchematicImporter.import(options)
	assert(options.schematic, "SchematicImporter: schematic ModuleScript required")
	assert(options.worldManager, "SchematicImporter: worldManager required")

	local schematicModule = options.schematic
	local worldManager = options.worldManager
	local offset = options.offset or Vector3.new(0, 0, 0)
	local onProgress = options.onProgress
	local yieldInterval = options.yieldInterval or 1000 -- Yield every N blocks
	local blockMapping = options.blockMapping -- Optional custom mapping

	logger.Info("📦 Starting schematic import", {
		schematic = schematicModule.Name,
		offset = string.format("(%d, %d, %d)", offset.X, offset.Y, offset.Z)
	})

	-- Load schematic data
	local schematicData = require(schematicModule)

	local palette = schematicData.palette
	local chunks = schematicData.chunks
	local size = schematicData.size

	logger.Info("📊 Schematic info", {
		size = string.format("%dx%dx%d", size.width, size.height, size.length),
		paletteSize = #palette,
		encoding = schematicData.encoding
	})

	-- Pre-process palette: map each entry to our block type + metadata
	local processedPalette = {}
	local unmappedBlocks = {}

	for i, entry in ipairs(palette) do
		local baseName, properties = parseBlockEntry(entry)
		local blockId = (blockMapping and blockMapping[baseName]) or getBlockId(baseName)
		local metadata = convertMetadata(baseName, properties)

		if blockId then
			processedPalette[i] = {
				blockId = blockId,
				metadata = metadata,
				baseName = baseName
			}
		else
			-- Track unmapped for logging
			if not unmappedBlocks[baseName] then
				unmappedBlocks[baseName] = true
			end
			processedPalette[i] = nil
		end
	end

	-- Log unmapped blocks
	local unmappedList = {}
	for name, _ in pairs(unmappedBlocks) do
		table.insert(unmappedList, name)
	end
	if #unmappedList > 0 then
		logger.Warn("⚠️ Unmapped block types (skipping)", {
			count = #unmappedList,
			blocks = table.concat(unmappedList, ", ")
		})
	end

	-- Import chunks
	local blocksPlaced = 0
	local blocksSkipped = 0
	local totalBlocks = schematicData.size and (schematicData.size.width * schematicData.size.height * schematicData.size.length) or 0
	local operationCount = 0
	local chunkCount = 0
	local totalChunks = 0

	-- Count total chunks
	for _ in pairs(chunks) do
		totalChunks = totalChunks + 1
	end

	logger.Info("🔄 Processing chunks", { total = totalChunks })

	for chunkKey, chunkData in pairs(chunks) do
		chunkCount = chunkCount + 1

		-- Parse chunk coordinates
		local chunkX, chunkZ = string.match(chunkKey, "^(-?%d+),(-?%d+)$")
		chunkX = tonumber(chunkX)
		chunkZ = tonumber(chunkZ)

		if not chunkX or not chunkZ then
			logger.Warn("Invalid chunk key", { key = chunkKey })
			continue
		end

		-- Process each column in the chunk
		for columnKey, runs in pairs(chunkData) do
			-- Parse local coordinates
			local localX, localZ = string.match(columnKey, "^(-?%d+),(-?%d+)$")
			localX = tonumber(localX)
			localZ = tonumber(localZ)

			if not localX or not localZ then
				continue
			end

			-- Calculate world coordinates
			local worldX = chunkX * 16 + localX + math.floor(offset.X)
			local worldZ = chunkZ * 16 + localZ + math.floor(offset.Z)

			-- Process RLE runs for this column
			for _, run in ipairs(runs) do
				local startY = run[1]
				local length = run[2]
				local paletteIndex = run[3]

				local blockInfo = processedPalette[paletteIndex]

				if blockInfo then
					-- Place blocks in this run
					for dy = 0, length - 1 do
						local worldY = startY + dy + math.floor(offset.Y)

						-- Bounds check
						if worldY >= 0 and worldY < Constants.WORLD_HEIGHT then
							local success = worldManager:SetBlock(worldX, worldY, worldZ, blockInfo.blockId)
							if success then
								-- Set metadata if non-zero
								if blockInfo.metadata ~= 0 then
									worldManager:SetBlockMetadata(worldX, worldY, worldZ, blockInfo.metadata)
								end
								blocksPlaced = blocksPlaced + 1
							end
						end

						operationCount = operationCount + 1

						-- Yield periodically to prevent timeout
						if operationCount % yieldInterval == 0 then
							if onProgress then
								onProgress(blocksPlaced, totalBlocks)
							end
							task.wait()
						end
					end
				else
					blocksSkipped = blocksSkipped + length
				end
			end
		end

		-- Progress update per chunk
		if chunkCount % 10 == 0 then
			logger.Info("📦 Import progress", {
				chunks = string.format("%d/%d", chunkCount, totalChunks),
				blocksPlaced = blocksPlaced
			})
		end
	end

	logger.Info("✅ Schematic import complete", {
		blocksPlaced = blocksPlaced,
		blocksSkipped = blocksSkipped,
		chunks = chunkCount
	})

	return blocksPlaced
end

--- Get a preview of block mappings for a schematic
--- Useful for debugging which blocks will be mapped
--- @param schematicModule ModuleScript The schematic module
--- @return table mappingInfo { mapped = {}, unmapped = {} }
function SchematicImporter.previewMapping(schematicModule)
	local schematicData = require(schematicModule)
	local palette = schematicData.palette

	local mapped = {}
	local unmapped = {}

	for i, entry in ipairs(palette) do
		local baseName, properties = parseBlockEntry(entry)
		local blockId = getBlockId(baseName)

		if blockId then
			table.insert(mapped, {
				index = i,
				mcName = baseName,
				blockId = blockId,
				hasMetadata = properties ~= nil
			})
		else
			table.insert(unmapped, {
				index = i,
				mcName = baseName,
				fullEntry = entry
			})
		end
	end

	return {
		mapped = mapped,
		unmapped = unmapped,
		totalPalette = #palette,
		mappedCount = #mapped,
		unmappedCount = #unmapped
	}
end

return SchematicImporter
