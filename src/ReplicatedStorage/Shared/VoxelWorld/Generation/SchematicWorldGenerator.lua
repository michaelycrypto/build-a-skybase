--[[
	SchematicWorldGenerator.lua

	World generator that loads terrain from a pre-built Minecraft schematic.
	Implements the same interface as HubWorldGenerator/SkyblockGenerator so it
	integrates seamlessly with the existing chunk streaming system.

	The schematic is loaded once on construction, then GetBlockAt queries
	return blocks from the schematic data (or AIR for empty space).

	BLOCK MAPPING: Uses shared BlockMapping module as single source of truth.
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BaseWorldGenerator = require(script.Parent.BaseWorldGenerator)
local BlockMapping = require(script.Parent.Parent.Core.BlockMapping)

local SchematicWorldGenerator = BaseWorldGenerator.extend({})

local BlockType = Constants.BlockType

-- Use the shared block mapping as the single source of truth
local BLOCK_MAPPING = BlockMapping.Map

-- ═══════════════════════════════════════════════════════════════════════════
-- METADATA PARSING
-- ═══════════════════════════════════════════════════════════════════════════

-- Supports both abbreviated (f=n) and full (facing=north) property names
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

-- Supports both abbreviated (h=t) and full (half=top) property names
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

-- Supports both abbreviated (s=st) and full (shape=straight) property names
local SHAPE_TO_STAIR = {
	-- Abbreviated
	["st"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["il"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["ir"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
	["ol"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["or"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
	-- Full
	["straight"] = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT,
	["inner_left"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT,
	["inner_right"] = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT,
	["outer_left"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT,
	["outer_right"] = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT,
}

-- Supports both abbreviated (t=t) and full (type=top) property names for slabs
local SLAB_TYPE_TO_VERTICAL = {
	-- Abbreviated
	["t"] = Constants.BlockMetadata.VERTICAL_TOP,
	["b"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
	-- Full
	["top"] = Constants.BlockMetadata.VERTICAL_TOP,
	["bottom"] = Constants.BlockMetadata.VERTICAL_BOTTOM,
}

--- Parse a palette entry like "minecraft:oak_stairs[f=n,h=b,s=st]" into baseName and properties
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

--- Convert Minecraft block properties to our metadata byte format
--- Handles both abbreviated (f=n, h=b, s=st) and full (facing=north, half=bottom, shape=straight) property names
local function convertMetadata(_, properties)
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

	-- Handle slab type (t or type)
	local slabType = properties.t or properties.type
	if slabType then
		if slabType == "d" or slabType == "db" or slabType == "double" then
			-- Double slab: set the double flag
			metadata = Constants.SetDoubleSlabFlag(metadata, true)
		elseif SLAB_TYPE_TO_VERTICAL[slabType] then
			metadata = Constants.SetVerticalOrientation(metadata, SLAB_TYPE_TO_VERTICAL[slabType])
		end
	end

	return metadata
end

--- Get block ID for a Minecraft block name, fallback to STONE
local function getBlockId(baseName)
	local mapped = BLOCK_MAPPING[baseName]
	if mapped then
		return mapped
	end
	-- Fallback: map unknown blocks to STONE
	return BlockType.STONE
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

	print("[SchematicWorldGenerator] Loading schematic from path:", path)

	-- Parse path like "Schematics.Medieval_Skyblock_Spawn" or just "LittleIsland"
	local parts = string.split(path, ".")
	local current = ServerStorage
	for _, part in ipairs(parts) do
		current = current:FindFirstChild(part)
		if not current then
			warn("[SchematicWorldGenerator] Could not find schematic at path:", path, "- missing part:", part)
			warn("[SchematicWorldGenerator] Available children in ServerStorage:", table.concat(
				(function()
					local names = {}
					for _, child in ipairs(ServerStorage:GetChildren()) do
						table.insert(names, child.Name)
					end
					return names
				end)(), ", "))
			return
		end
	end

	print("[SchematicWorldGenerator] Found schematic module:", current:GetFullName())

	local ok, schematicData = pcall(require, current)
	if not ok then
		warn("[SchematicWorldGenerator] Failed to require schematic module:", schematicData)
		return
	end

	print("[SchematicWorldGenerator] Successfully loaded schematic data")

	self._schematicData = schematicData
	self._schematicSize = schematicData.size or { width = 0, height = 0, length = 0 }

	-- Process palette - map each entry to block ID and metadata
	local palette = schematicData.palette or {}
	local mappedCount = 0
	local airCount = 0
	local unmappedBlocks = {}

	for i, entry in ipairs(palette) do
		local baseName, properties = parseBlockEntry(entry)
		local blockId = getBlockId(baseName)
		local metadata = convertMetadata(baseName, properties)

		-- Store at Lua 1-based index
		self._processedPalette[i] = {
			blockId = blockId,
			metadata = metadata,
		}

		if blockId == BlockType.AIR then
			airCount = airCount + 1
		elseif blockId == BlockType.STONE and BLOCK_MAPPING[baseName] == nil then
			-- Unmapped block fell through to STONE fallback
			if #unmappedBlocks < 10 then
				table.insert(unmappedBlocks, baseName)
			end
		else
			mappedCount = mappedCount + 1
		end
	end

	-- Log palette processing results
	if #unmappedBlocks > 0 then
		warn(string.format("[SchematicWorldGenerator] Unmapped blocks: %s", table.concat(unmappedBlocks, ", ")))
	end
	print(string.format("[SchematicWorldGenerator] Palette: %d mapped, %d air, %d unmapped",
		mappedCount, airCount, #palette - mappedCount - airCount))

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

						if blockInfo and blockInfo.blockId ~= BlockType.AIR then
							table.insert(processedRuns, {
								startY = startY,
								length = length,
								blockId = blockInfo.blockId,
								metadata = blockInfo.metadata,
							})

							-- Track Y bounds
							local endY = startY + length - 1
							if startY < self._minY then
								self._minY = startY
							end
							if endY > self._maxY then
								self._maxY = endY
							end
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

	-- If schematic loaded successfully, use auto-detected spawn from schematic data
	if self._schematicData and self._schematicSize.width > 0 then
		-- Default: center of schematic at top Y + 2
		local centerX = config.offsetX + self._schematicSize.width / 2
		local centerZ = config.offsetZ + self._schematicSize.length / 2
		local spawnY = self._maxY + 2

		-- Try to find a solid block near center to spawn on
		local testY = self:_findSurfaceY(math.floor(centerX), math.floor(centerZ))
		if testY then
			spawnY = testY + 2
		end

		print(string.format("[SchematicWorldGenerator] Auto-detected spawn: (%d, %d, %d)",
			math.floor(centerX), spawnY, math.floor(centerZ)))

		return Vector3.new(
			math.floor(centerX) * Constants.BLOCK_SIZE,
			spawnY * Constants.BLOCK_SIZE,
			math.floor(centerZ) * Constants.BLOCK_SIZE
		)
	end

	-- Fallback: use explicit spawn position if schematic failed to load
	if config.spawnX and config.spawnY and config.spawnZ then
		warn("[SchematicWorldGenerator] Schematic not loaded, using fallback spawn position")
		return Vector3.new(
			config.spawnX * Constants.BLOCK_SIZE,
			config.spawnY * Constants.BLOCK_SIZE,
			config.spawnZ * Constants.BLOCK_SIZE
		)
	end

	-- Last resort fallback
	warn("[SchematicWorldGenerator] No spawn position available, using origin")
	return Vector3.new(0, 100 * Constants.BLOCK_SIZE, 0)
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
	-- If schematic failed to load, don't report all chunks as empty
	-- This allows fallback rendering of something rather than nothing
	if not self._schematicData then
		return false -- Force chunk generation attempt
	end

	local key = string.format("%d,%d", math.floor(chunkX), math.floor(chunkZ))
	return not self._occupiedChunks[key]
end

function SchematicWorldGenerator:GenerateChunk(chunk)
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

	-- Debug: log first chunk generation
	if not self._firstChunkLogged then
		self._firstChunkLogged = true
		local columnCount = 0
		for _ in pairs(chunkData) do
			columnCount = columnCount + 1
		end
		print(string.format("[SchematicWorldGenerator] Generating first chunk %s with %d columns", chunkKey, columnCount))
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
