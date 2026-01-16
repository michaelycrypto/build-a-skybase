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
	["gravel"] = BlockType.STONE,
	["clay"] = BlockType.DIRT,
	["coarse_dirt"] = BlockType.DIRT,
	
	-- Stone variants
	["stone_bricks"] = BlockType.STONE_BRICKS,
	["mossy_stone_bricks"] = BlockType.STONE_BRICKS,
	["cracked_stone_bricks"] = BlockType.STONE_BRICKS,
	["chiseled_stone_bricks"] = BlockType.STONE_BRICKS,
	["mossy_cobblestone"] = BlockType.COBBLESTONE,
	["andesite"] = BlockType.STONE,
	["polished_andesite"] = BlockType.STONE,
	["diorite"] = BlockType.STONE,
	["polished_diorite"] = BlockType.STONE,
	["granite"] = BlockType.STONE,
	["polished_granite"] = BlockType.STONE,
	
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
	["sandstone_stairs"] = BlockType.STONE_STAIRS,
	
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
	
	-- Wool → Stone (fallback)
	["white_wool"] = BlockType.STONE,
	["orange_wool"] = BlockType.STONE,
	["magenta_wool"] = BlockType.STONE,
	["light_blue_wool"] = BlockType.STONE,
	["yellow_wool"] = BlockType.STONE,
	["lime_wool"] = BlockType.STONE,
	["pink_wool"] = BlockType.STONE,
	["gray_wool"] = BlockType.STONE,
	["light_gray_wool"] = BlockType.STONE,
	["cyan_wool"] = BlockType.STONE,
	["purple_wool"] = BlockType.STONE,
	["blue_wool"] = BlockType.STONE,
	["brown_wool"] = BlockType.STONE,
	["green_wool"] = BlockType.STONE,
	["red_wool"] = BlockType.STONE,
	["black_wool"] = BlockType.STONE,
	
	-- Terracotta → Stone (fallback)
	["terracotta"] = BlockType.STONE,
	["white_terracotta"] = BlockType.STONE,
	["orange_terracotta"] = BlockType.STONE,
	["magenta_terracotta"] = BlockType.STONE,
	["light_blue_terracotta"] = BlockType.STONE,
	["yellow_terracotta"] = BlockType.STONE,
	["lime_terracotta"] = BlockType.STONE,
	["pink_terracotta"] = BlockType.STONE,
	["gray_terracotta"] = BlockType.STONE,
	["light_gray_terracotta"] = BlockType.STONE,
	["cyan_terracotta"] = BlockType.STONE,
	["purple_terracotta"] = BlockType.STONE,
	["blue_terracotta"] = BlockType.STONE,
	["brown_terracotta"] = BlockType.STONE,
	["green_terracotta"] = BlockType.STONE,
	["red_terracotta"] = BlockType.STONE,
	["black_terracotta"] = BlockType.STONE,
	
	-- Sandstone → Stone
	["sandstone"] = BlockType.STONE,
	["smooth_sandstone"] = BlockType.STONE,
	["chiseled_sandstone"] = BlockType.STONE,
	["cut_sandstone"] = BlockType.STONE,
	["red_sandstone"] = BlockType.STONE,
	
	-- End blocks → Stone
	["end_stone"] = BlockType.STONE,
	["end_stone_bricks"] = BlockType.STONE_BRICKS,
	
	-- Quartz → Stone
	["quartz_block"] = BlockType.STONE,
	["smooth_quartz"] = BlockType.STONE,
	["chiseled_quartz_block"] = BlockType.STONE,
	["quartz_pillar"] = BlockType.STONE,
	["quartz_bricks"] = BlockType.STONE,
	
	-- Prismarine → Stone
	["prismarine"] = BlockType.STONE,
	["prismarine_bricks"] = BlockType.STONE_BRICKS,
	["dark_prismarine"] = BlockType.STONE,
	
	-- Smooth stone variants
	["smooth_stone"] = BlockType.STONE,
	["smooth_stone_slab"] = BlockType.STONE_SLAB,
	
	-- Stained glass (→ Glass)
	["glass_pane"] = BlockType.GLASS,
	["white_stained_glass"] = BlockType.GLASS,
	["white_stained_glass_pane"] = BlockType.GLASS,
	["orange_stained_glass_pane"] = BlockType.GLASS,
	["magenta_stained_glass_pane"] = BlockType.GLASS,
	["light_blue_stained_glass_pane"] = BlockType.GLASS,
	["yellow_stained_glass_pane"] = BlockType.GLASS,
	["lime_stained_glass_pane"] = BlockType.GLASS,
	["pink_stained_glass_pane"] = BlockType.GLASS,
	["gray_stained_glass_pane"] = BlockType.GLASS,
	["light_gray_stained_glass_pane"] = BlockType.GLASS,
	["cyan_stained_glass_pane"] = BlockType.GLASS,
	["purple_stained_glass_pane"] = BlockType.GLASS,
	["blue_stained_glass_pane"] = BlockType.GLASS,
	["brown_stained_glass_pane"] = BlockType.GLASS,
	["green_stained_glass_pane"] = BlockType.GLASS,
	["red_stained_glass_pane"] = BlockType.GLASS,
	["black_stained_glass_pane"] = BlockType.GLASS,
	
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
	["podzol"] = BlockType.DIRT,
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
	["nether_brick_stairs"] = BlockType.STONE_STAIRS,
	["nether_brick_slab"] = BlockType.STONE_SLAB,
	["nether_bricks"] = BlockType.STONE_BRICKS,
	
	-- Quartz variants
	["quartz_stairs"] = BlockType.STONE_STAIRS,
	["quartz_slab"] = BlockType.STONE_SLAB,
	
	-- Sandstone variants
	["sandstone_stairs"] = BlockType.STONE_STAIRS,
	["cut_sandstone_slab"] = BlockType.STONE_SLAB,
	
	-- Solid stained glass (not panes)
	["yellow_stained_glass"] = BlockType.GLASS,
	["white_stained_glass"] = BlockType.GLASS,
	["orange_stained_glass"] = BlockType.GLASS,
	["light_blue_stained_glass"] = BlockType.GLASS,
	["lime_stained_glass"] = BlockType.GLASS,
	["green_stained_glass"] = BlockType.GLASS,
	["cyan_stained_glass"] = BlockType.GLASS,
	["blue_stained_glass"] = BlockType.GLASS,
	["purple_stained_glass"] = BlockType.GLASS,
	["magenta_stained_glass"] = BlockType.GLASS,
	["pink_stained_glass"] = BlockType.GLASS,
	["gray_stained_glass"] = BlockType.GLASS,
	["light_gray_stained_glass"] = BlockType.GLASS,
	["brown_stained_glass"] = BlockType.GLASS,
	["red_stained_glass"] = BlockType.GLASS,
	["black_stained_glass"] = BlockType.GLASS,
	
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
