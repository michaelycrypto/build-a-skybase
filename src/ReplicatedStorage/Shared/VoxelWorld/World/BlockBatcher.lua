--[[
	BlockBatcher.lua
	Batch block updates for 10-100x faster bulk edits

	Usage:
		local batcher = BlockBatcher.new(chunkManager)
		batcher:QueueBlockChange(100, 50, 200, BlockIds.STONE)
		batcher:QueueBlockChange(101, 50, 200, BlockIds.STONE)
		-- ... many more changes
		batcher:Flush() -- Apply all at once
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local BlockBatcher = {}
BlockBatcher.__index = BlockBatcher

--[[
	Create a new block batcher
	@param chunkManager ChunkManager
]]
function BlockBatcher.new(chunkManager)
	return setmetatable({
		chunkManager = chunkManager,
		pending = {}, -- {worldX, worldY, worldZ, blockId}
		dirtyChunks = {}, -- Set of chunk keys that need remeshing
		affectedChunks = {}, -- Chunks that were modified
	}, BlockBatcher)
end

--[[
	Queue a block change (doesn't apply immediately)
	@param worldX number (in studs)
	@param worldY number (in studs)
	@param worldZ number (in studs)
	@param blockId number
]]
function BlockBatcher:QueueBlockChange(worldX: number, worldY: number, worldZ: number, blockId: number)
	table.insert(self.pending, {worldX, worldY, worldZ, blockId})
end

--[[
	Queue multiple block changes at once
	@param changes {{worldX, worldY, worldZ, blockId}}
]]
function BlockBatcher:QueueMany(changes)
	for _, change in ipairs(changes) do
		table.insert(self.pending, change)
	end
end

--[[
	Apply all pending block changes and remesh affected chunks once
	@return number -- number of blocks changed
]]
function BlockBatcher:Flush(): number
	if #self.pending == 0 then
		return 0
	end

	local changedCount = 0

	-- Apply all changes without triggering individual remeshes
	for _, change in ipairs(self.pending) do
		local worldX, worldY, worldZ, blockId = table.unpack(change)

		-- Convert to chunk and local coordinates
		local cx, cz, lx, ly, lz = Constants.WorldStudsToChunkAndLocal(worldX, worldY, worldZ)

		-- Get or create chunk
		local chunk = self.chunkManager:getChunk(cx, cz)
		if chunk then
			-- Set block directly without triggering remesh
			if Constants.IsInsideChunk(lx, ly, lz) then
				local current = chunk.blocks[lx][ly][lz]
				if current ~= blockId then
					chunk.blocks[lx][ly][lz] = blockId
					chunk.lastAccessTime = os.clock()
					changedCount = changedCount + 1

					-- Track which chunk needs remeshing
					local chunkKey = Constants.ToChunkKey(cx, cz)
					self.dirtyChunks[chunkKey] = chunk
					self.affectedChunks[chunkKey] = chunk

					-- If on edge, mark neighbors too
					if chunk:IsEdge(lx, ly, lz) then
						local neighbors = {
							chunk.neighbors.north,
							chunk.neighbors.south,
							chunk.neighbors.east,
							chunk.neighbors.west,
						}
						for _, nb in ipairs(neighbors) do
							if nb then
								local nbKey = Constants.ToChunkKey(nb.chunkX, nb.chunkZ)
								self.dirtyChunks[nbKey] = nb
							end
						end
					end
				end
			end
		end
	end

	-- Now mark all affected chunks dirty and enqueue for meshing
	for _, chunk in pairs(self.dirtyChunks) do
		chunk.isDirty = true
		-- Update heightmap for affected columns
		self:UpdateHeightmapForChunk(chunk)
		-- Enqueue for meshing
		if self.chunkManager._enqueueForMeshing then
			self.chunkManager:_enqueueForMeshing(chunk)
		end
	end

	-- Clear batch
	self.pending = {}
	self.dirtyChunks = {}
	self.affectedChunks = {}

	return changedCount
end

--[[
	Update heightmap for chunks that were modified
	Only updates columns that had blocks changed
]]
function BlockBatcher:UpdateHeightmapForChunk(chunk)
	if not chunk.heightmap then
		return
	end

	-- For now, rebuild entire heightmap
	-- TODO: Optimize to only update affected columns
	local BlockRegistry = require(script.Parent.BlockRegistry)

	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		if not chunk.heightmap.surface[x] then
			chunk.heightmap.surface[x] = {}
		end
		if not chunk.heightmap.motionBlocking[x] then
			chunk.heightmap.motionBlocking[x] = {}
		end

		for z = 0, Constants.CHUNK_SIZE_Z - 1 do
			-- Find top solid block
			local surfaceY = 0
			for y = Constants.CHUNK_SIZE_Y - 1, 0, -1 do
				if BlockRegistry.IsSolid(chunk.blocks[x][y][z]) then
					surfaceY = y
					break
				end
			end
			chunk.heightmap.surface[x][z] = surfaceY

			-- Find top motion-blocking block
			local motionY = 0
			for y = Constants.CHUNK_SIZE_Y - 1, 0, -1 do
				local blockId = chunk.blocks[x][y][z]
				if BlockRegistry.IsSolid(blockId) and blockId ~= BlockRegistry.BlockIds.WATER then
					motionY = y
					break
				end
			end
			chunk.heightmap.motionBlocking[x][z] = motionY
		end
	end
end

--[[
	Clear all pending changes without applying
]]
function BlockBatcher:Clear()
	self.pending = {}
	self.dirtyChunks = {}
	self.affectedChunks = {}
end

--[[
	Get number of pending changes
]]
function BlockBatcher:GetPendingCount(): number
	return #self.pending
end

return BlockBatcher

