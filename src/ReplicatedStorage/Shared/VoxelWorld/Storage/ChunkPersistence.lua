--[[
	ChunkPersistence.lua
	Handles saving and loading chunks using DataStore
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Constants = require(script.Parent.Parent.Core.Constants)


local ChunkPersistence = {}
ChunkPersistence.__index = ChunkPersistence

function ChunkPersistence.new(options)
	local self = setmetatable({
		maxSaveQueueSize = options.maxSaveQueueSize or 64,
		savesPerTick = options.savesPerTick or 3,
		compressionLevel = options.compressionLevel or 2,
		saveQueue = {}, -- Queue of chunks to save
		dataStore = nil
	}, ChunkPersistence)

	-- Only initialize DataStore on server
	if RunService:IsServer() then
		self.dataStore = DataStoreService:GetDataStore("VoxelWorld_Chunks")
	end

	return self
end

-- Compress chunk data for storage
function ChunkPersistence:CompressChunk(chunk)
	-- Convert sparse block array to run-length encoding
	local blocks = {}
	local currentBlock = nil
	local currentCount = 0

	for y = 0, Constants.CHUNK_SIZE_Y - 1 do
		for z = 0, Constants.CHUNK_SIZE_Z - 1 do
			for x = 0, Constants.CHUNK_SIZE_X - 1 do
				local blockId = chunk:GetBlock(x, y, z)

				if blockId == currentBlock then
					currentCount = currentCount + 1
				else
					if currentBlock then
						table.insert(blocks, {currentBlock, currentCount})
					end
					currentBlock = blockId
					currentCount = 1
				end
			end
		end
	end

	-- Add final run
	if currentBlock then
		table.insert(blocks, {currentBlock, currentCount})
	end

	-- Create compressed data
	local data = {
		x = chunk.x,
		z = chunk.z,
		blocks = blocks,
		heightMap = chunk.heightMap
	}

	return HttpService:JSONEncode(data)
end

-- Decompress chunk data from storage
function ChunkPersistence:DecompressChunk(chunk, compressedData)
	local data = HttpService:JSONDecode(compressedData)

	-- Verify chunk coordinates
	if data.x ~= chunk.x or data.z ~= chunk.z then
		warn("Chunk coordinate mismatch in stored data")
		return false
	end

	-- Clear existing blocks
	chunk.blocks = {}

	-- Expand run-length encoding
	local index = 0
	for _, run in ipairs(data.blocks) do
		local blockId, count = run[1], run[2]

		for _ = 1, count do
			local x = index % Constants.CHUNK_SIZE_X
			local y = math.floor(index / (Constants.CHUNK_SIZE_X * Constants.CHUNK_SIZE_Z))
			local z = math.floor((index % (Constants.CHUNK_SIZE_X * Constants.CHUNK_SIZE_Z)) / Constants.CHUNK_SIZE_X)

			if blockId ~= Constants.BlockType.AIR then
				chunk:SetBlock(x, y, z, blockId)
			end

			index = index + 1
		end
	end

	-- Restore height map
	chunk.heightMap = data.heightMap

	return true
end

-- Get chunk key for DataStore
function ChunkPersistence:GetChunkKey(x: number, z: number): string
	return string.format("chunk_%d_%d", x, z)
end

-- Queue chunk for saving
function ChunkPersistence:QueueChunkSave(chunk)
	if not RunService:IsServer() then
		return
	end

	-- Only queue if modified
	if not chunk.isDirty then
		return
	end

	local key = self:GetChunkKey(chunk.x, chunk.z)

	-- Add to save queue if not already queued
	if not self.saveQueue[key] then
		self.saveQueue[key] = chunk
	end

	-- Process queue if it's getting full (count keys)
	local qsize = 0
	for _ in pairs(self.saveQueue) do
		qsize += 1
	end
	if qsize >= self.maxSaveQueueSize then
		self:ProcessSaveQueue()
	end
end

-- Process save queue
function ChunkPersistence:ProcessSaveQueue()
	if not RunService:IsServer() then
		return
	end

	local processed = 0

	-- Process up to savesPerTick chunks
	for key, chunk in pairs(self.saveQueue) do
		if processed >= self.savesPerTick then
			break
		end

		-- Compress and save chunk
		local success, err = pcall(function()
			local compressed = self:CompressChunk(chunk)
			self.dataStore:SetAsync(key, compressed)
		end)

		if success then
			chunk.isDirty = false
			self.saveQueue[key] = nil
			processed = processed + 1
		else
			warn("Failed to save chunk:", key, err)
		end
	end
end

-- Load chunk from storage
function ChunkPersistence:LoadChunk(chunk): boolean
	if not RunService:IsServer() then
		return false
	end

	local key = self:GetChunkKey(chunk.x, chunk.z)

	-- Try to load from DataStore
	local success, result = pcall(function()
		return self.dataStore:GetAsync(key)
	end)

	if success and result then
		-- Decompress and apply data
		return self:DecompressChunk(chunk, result)
	end

	return false
end

return ChunkPersistence