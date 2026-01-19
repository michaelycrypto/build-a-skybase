--[[
	SchematicImporter.lua

	Imports Minecraft schematics (converted to Lua RLE format) into the voxel world.

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

local RunService = game:GetService("RunService")

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
--- @param baseName string The base block name (for context)
--- @param properties table|nil Parsed properties from block name
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
