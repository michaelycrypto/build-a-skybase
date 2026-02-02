--[[
	SchematicImporter.lua

	Imports Minecraft schematics (converted to Lua RLE format) into the voxel world.

	SUPPORTED FORMATS:
	- Legacy format: Block names without namespace, abbreviated properties (f=n, h=b, t=t)
	  Example: "stone_brick_stairs[f=w,h=b]"
	- 1.20+ format: Full Minecraft namespace and property names
	  Example: "minecraft:stone_brick_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]"

	BLOCK MAPPING: Uses shared BlockMapping module as single source of truth.

	Usage:
		local SchematicImporter = require(path.to.SchematicImporter)
		local blocksPlaced = SchematicImporter.import({
			schematic = ServerStorage.Medieval_Skyblock_Spawn,
			worldManager = worldManager,  -- WorldManager instance
			offset = Vector3.new(0, 0, 0),
			onProgress = function(placed, total) print(placed, "/", total) end,
		})
]]

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockMapping = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.BlockMapping)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local logger = Logger:CreateContext("SchematicImporter")

local SchematicImporter = {}

-- Use the shared block mapping as the single source of truth
local BLOCK_MAPPING = BlockMapping.Map

-- ═══════════════════════════════════════════════════════════════════════════
-- METADATA PARSING
-- ═══════════════════════════════════════════════════════════════════════════

-- Direction mapping: Minecraft cardinal → our rotation constants
-- Supports both abbreviated (f=n) and full (facing=north) formats
local FACING_TO_ROTATION = {
	-- Abbreviated
	["n"] = Constants.BlockMetadata.ROTATION_NORTH,
	["e"] = Constants.BlockMetadata.ROTATION_EAST,
	["s"] = Constants.BlockMetadata.ROTATION_SOUTH,
	["w"] = Constants.BlockMetadata.ROTATION_WEST,
	-- Full
	["north"] = Constants.BlockMetadata.ROTATION_NORTH,
	["east"] = Constants.BlockMetadata.ROTATION_EAST,
	["south"] = Constants.BlockMetadata.ROTATION_SOUTH,
	["west"] = Constants.BlockMetadata.ROTATION_WEST,
}

-- Half mapping: Minecraft half → our vertical constants
-- Supports both abbreviated (h=t) and full (half=top) formats
-- Also supports "lower" and "upper" for two-block tall plants (tall_grass, flowers)
local HALF_TO_VERTICAL = {
	-- Abbreviated
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	-- Full
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	-- Two-block tall plants (tall_grass, large_fern, rose_bush, lilac, etc.)
	["lower"] = Constants.BlockMetadata.VERTICAL_BOTTOM,  -- Lower half (default, no flag needed but explicit for clarity)
	["upper"] = Constants.BlockMetadata.VERTICAL_TOP,     -- Upper half
}

-- Stair shape mapping
-- Supports both abbreviated (s=st) and full (shape=straight) formats
local SHAPE_TO_STAIR = {
	-- Abbreviated
	["st"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["ol"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["or"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
	["il"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["ir"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
	-- Full
	["straight"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["outer_left"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["outer_right"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
	["inner_left"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["inner_right"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
}

-- Slab type mapping
-- Supports both abbreviated (t=t) and full (type=top) formats
local SLAB_TYPE_TO_VERTICAL = {
	-- Abbreviated
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	-- Full
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CROP AGE MAPPING
-- ═══════════════════════════════════════════════════════════════════════════
-- Maps base crop name + age → specific block ID
local CROP_STAGES = {
	["wheat"] = {
		[0] = Constants.BlockType.WHEAT_CROP_0,
		[1] = Constants.BlockType.WHEAT_CROP_1,
		[2] = Constants.BlockType.WHEAT_CROP_2,
		[3] = Constants.BlockType.WHEAT_CROP_3,
		[4] = Constants.BlockType.WHEAT_CROP_4,
		[5] = Constants.BlockType.WHEAT_CROP_5,
		[6] = Constants.BlockType.WHEAT_CROP_6,
		[7] = Constants.BlockType.WHEAT_CROP_7,
	},
	["potatoes"] = {
		[0] = Constants.BlockType.POTATO_CROP_0,
		[1] = Constants.BlockType.POTATO_CROP_1,
		[2] = Constants.BlockType.POTATO_CROP_2,
		[3] = Constants.BlockType.POTATO_CROP_3,
	},
	["carrots"] = {
		[0] = Constants.BlockType.CARROT_CROP_0,
		[1] = Constants.BlockType.CARROT_CROP_1,
		[2] = Constants.BlockType.CARROT_CROP_2,
		[3] = Constants.BlockType.CARROT_CROP_3,
	},
	["beetroots"] = {
		[0] = Constants.BlockType.BEETROOT_CROP_0,
		[1] = Constants.BlockType.BEETROOT_CROP_1,
		[2] = Constants.BlockType.BEETROOT_CROP_2,
		[3] = Constants.BlockType.BEETROOT_CROP_3,
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- PARSING FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

--- Parse block name and metadata from palette entry
--- @param paletteEntry string e.g. "minecraft:cobblestone_stairs[f=n,h=b,s=st]"
--- @return string baseName, table|nil properties
local function parseBlockEntry(paletteEntry)
	-- First extract base name and metadata
	local baseName, metadataStr = string.match(paletteEntry, "^([^%[]+)%[(.+)%]$")
	if not baseName then
		baseName = paletteEntry
		metadataStr = nil
	end

	-- Strip "minecraft:" namespace prefix if present
	baseName = string.gsub(baseName, "^minecraft:", "")

	-- Parse properties if present
	local properties = nil
	if metadataStr then
		properties = {}
		for key, value in string.gmatch(metadataStr, "([^,=]+)=([^,=]+)") do
			properties[key] = value
		end
	end

	return baseName, properties
end

--- Convert Minecraft metadata to our BlockMetadata byte
--- Handles both abbreviated (f=n, h=b, s=st, t=t) and full (facing=north, half=bottom, shape=straight, type=top) property names
--- Note: axis property (a=y or axis=y) for logs/pillars is parsed but not stored in metadata (no rotation storage)
--- @param baseName string The base block name (for context)
--- @param properties table|nil Parsed properties from block name
--- @return number metadata Our BlockMetadata format (0-255)
local function convertMetadata(_baseName, properties)
	if not properties then
		return 0
	end

	local metadata = 0

	-- Handle facing (f or facing)
	local facing = properties.f or properties.facing
	if facing and FACING_TO_ROTATION[facing] then
		metadata = Constants.SetRotation(metadata, FACING_TO_ROTATION[facing])
	end

	-- Handle half (h or half) for stairs/slabs
	local half = properties.h or properties.half
	if half and HALF_TO_VERTICAL[half] then
		metadata = Constants.SetVerticalOrientation(metadata, HALF_TO_VERTICAL[half])
	end

	-- Handle stair shape (s or shape)
	local shape = properties.s or properties.shape
	if shape and SHAPE_TO_STAIR[shape] then
		metadata = Constants.SetStairShape(metadata, SHAPE_TO_STAIR[shape])
	end

	-- Handle slab type (t or type) for slabs
	local slabType = properties.t or properties.type
	if slabType then
		if slabType == "db" or slabType == "double" then
			-- Double slab: set the double flag
			metadata = Constants.SetDoubleSlabFlag(metadata, true)
		elseif SLAB_TYPE_TO_VERTICAL[slabType] then
			metadata = Constants.SetVerticalOrientation(metadata, SLAB_TYPE_TO_VERTICAL[slabType])
		end
	end

	-- Note: axis property (a or axis) for logs/pillars is acknowledged but not stored
	-- Logs/pillars will be placed in default (vertical) orientation
	-- This is a known limitation - axis rotation would need additional metadata bits

	return metadata
end

--- Get block ID from Minecraft block name, considering properties like crop age
--- Handles both abbreviated (ag=7) and full (age=7) property names
--- @param baseName string The base block name (without metadata)
--- @param properties table|nil Parsed properties from block name
--- @return number|nil blockId Our BlockType ID, or nil if unmapped
local function getBlockId(baseName, properties)
	-- Handle crop stages based on age property (ag or age)
	if properties then
		local ageValue = properties.ag or properties.age
		if ageValue then
			local cropStages = CROP_STAGES[baseName]
			if cropStages then
				local age = tonumber(ageValue) or 0
				-- Clamp age to valid range for this crop
				local maxAge = 0
				for ageKey, _ in pairs(cropStages) do
					if ageKey > maxAge then
						maxAge = ageKey
					end
				end
				age = math.min(age, maxAge)
				return cropStages[age]
			end
		end
	end

	return BLOCK_MAPPING[baseName]
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
	local yieldInterval = options.yieldInterval or 1000
	local blockMapping = options.blockMapping -- Optional custom mapping override

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
		local blockId = (blockMapping and blockMapping[baseName]) or getBlockId(baseName, properties)
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
--- @param schematicModule ModuleScript The schematic module
--- @return table mappingInfo { mapped = {}, unmapped = {} }
function SchematicImporter.previewMapping(schematicModule)
	local schematicData = require(schematicModule)
	local palette = schematicData.palette

	local mapped = {}
	local unmapped = {}

	for i, entry in ipairs(palette) do
		local baseName, properties = parseBlockEntry(entry)
		local blockId = getBlockId(baseName, properties)

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
