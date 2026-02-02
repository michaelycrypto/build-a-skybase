--[[
	WaterService.lua
	Optimized water flow simulation.

	KEY OPTIMIZATIONS:
	- Instant fall/cleanup: Entire columns handled in one operation
	- Minimal queuing: Only queue blocks that actually need updates
	- Skip column interiors: Middle blocks of falling columns don't need processing
	- Direct removal: Water cleanup bypasses queue flooding
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local WaterUtils = require(ReplicatedStorage.Shared.VoxelWorld.World.WaterUtils)

local BLOCK = Constants.BlockType

local WaterService = {}
WaterService.__index = WaterService
setmetatable(WaterService, BaseService)

-- Configuration
local TICK_INTERVAL = 0.25
local MAX_UPDATES_PER_TICK = 200
local MAX_UPDATES_PER_CHUNK = 50
local MAX_QUEUE_SIZE = 50000
local MAX_FALL_DISTANCE = 15
local SOURCE_CONVERSION_SETTLE_TICKS = 4
local MAX_CONVERSIONS_PER_TICK = 3

-- Cardinal directions only (water spreads in 4 directions)
local CARDINALS = {
	{dx = 1, dz = 0},   -- East
	{dx = -1, dz = 0},  -- West
	{dx = 0, dz = 1},   -- South
	{dx = 0, dz = -1},  -- North
}

-- 8 horizontal directions (for neighbor checks)
local HORIZONTAL_8 = {
	{dx = 1, dz = 0},   -- E
	{dx = -1, dz = 0},  -- W
	{dx = 0, dz = 1},   -- S
	{dx = 0, dz = -1},  -- N
	{dx = 1, dz = 1},   -- SE
	{dx = 1, dz = -1},  -- NE
	{dx = -1, dz = 1},  -- SW
	{dx = -1, dz = -1}, -- NW
}

function WaterService.new()
	local self = setmetatable(BaseService.new(), WaterService)
	self.Name = "WaterService"
	self._queue = {}
	self._queueList = {}
	self._queueSize = 0
	self._cursor = 1
	self._dirty = false
	self._paused = false
	self._conversionCandidates = {}
	self._conversionsThisTick = 0
	self._inCleanup = false -- Prevent recursive cleanup calls
	return self
end

function WaterService:Init()
	if self._initialized then
		return
	end
	BaseService.Init(self)
end

function WaterService:Start()
	if self._started then
		return
	end
	BaseService.Start(self)
	task.spawn(function()
		while self._started do
			self:_processQueue()
			task.wait(TICK_INTERVAL)
		end
	end)
end

function WaterService:Destroy()
	if self._destroyed then
		return
	end
	BaseService.Destroy(self)
	self._queue = {}
	self._queueList = {}
	self._queueSize = 0
	self._conversionCandidates = {}
end

--============================================================================
-- QUEUE MANAGEMENT (Simplified)
--============================================================================

local function posKey(x, y, z)
	return x * 16777216 + y * 65536 + z -- Numeric key for speed
end

local function strKey(x, y, z)
	return x .. "," .. y .. "," .. z
end

function WaterService:_enqueue(x, y, z)
	local k = posKey(x, y, z)
	if self._queue[k] then
		return
	end
	if self._queueSize >= MAX_QUEUE_SIZE then
		return
	end
	self._queue[k] = {x = x, y = y, z = z}
	self._queueSize += 1
	self._dirty = true
end

function WaterService:_dequeue(k)
	if self._queue[k] then
		self._queue[k] = nil
		self._queueSize = math.max(0, self._queueSize - 1)
		self._dirty = true
	end
end

function WaterService:_rebuildList()
	self._queueList = {}
	for k, v in pairs(self._queue) do
		table.insert(self._queueList, {k = k, x = v.x, y = v.y, z = v.z})
	end
	self._dirty = false
	self._cursor = 1
end

--============================================================================
-- HELPERS
--============================================================================

local function canFlowInto(blockId)
	if blockId == BLOCK.WATER_SOURCE then
		return false
	end
	if blockId == BLOCK.FLOWING_WATER then
		return true
	end
	return BlockRegistry:IsReplaceable(blockId)
end

local function isChunkLoaded(wm, x, z)
	if not wm or not wm.chunks then
		return false
	end
	local cx = math.floor(x / Constants.CHUNK_SIZE_X)
	local cz = math.floor(z / Constants.CHUNK_SIZE_Z)
	return wm.chunks[Constants.ToChunkKey(cx, cz)] ~= nil
end

local function isSolid(blockId)
	if blockId == BLOCK.AIR then
		return false
	end
	local def = BlockRegistry:GetBlock(blockId)
	return def and def.solid == true
end

--============================================================================
-- INSTANT FALL COLUMN
--============================================================================

function WaterService:_instantFallColumn(x, startY, z, initialFallDist, sourceDepth)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return startY, 0
	end

	sourceDepth = sourceDepth or 0
	local bottomY = startY

	-- Scan down to find where column ends
	for checkY = startY - 1, Constants.MIN_HEIGHT, -1 do
		if not isChunkLoaded(wm, x, z) then
			break
		end
		local belowId = wm:GetBlock(x, checkY, z)
		-- Stop at solid blocks or sources
		if belowId ~= BLOCK.AIR and belowId ~= BLOCK.FLOWING_WATER then
			if not BlockRegistry:IsReplaceable(belowId) then
				break
			end
		end
		if belowId == BLOCK.WATER_SOURCE then
			break
		end
		bottomY = checkY
	end

	if bottomY == startY then
		return startY, 0
	end

	-- Place column (only if different from current state)
	local blocksPlaced = 0
	local fallDist = initialFallDist or 0
	local isTop = true

	for y = startY - 1, bottomY, -1 do
		fallDist = math.min(fallDist + 1, MAX_FALL_DISTANCE)
		local level = isTop and sourceDepth or 0
		local meta = WaterUtils.MakeMetadata(level, true, fallDist)

		-- Only set if different (prevents redundant OnBlockChanged triggers)
		local currentId = wm:GetBlock(x, y, z)
		local currentMeta = wm:GetBlockMetadata(x, y, z) or 0
		if currentId ~= BLOCK.FLOWING_WATER or currentMeta ~= meta then
			vws:SetBlock(x, y, z, BLOCK.FLOWING_WATER, nil, meta)
			blocksPlaced += 1
		end
		isTop = false
	end

	-- Only queue if we actually placed new blocks
	if blocksPlaced > 0 then
		self:_enqueue(x, bottomY, z)
		for _, d in ipairs(CARDINALS) do
			self:_enqueue(x + d.dx, bottomY, z + d.dz)
		end
	end

	return bottomY, blocksPlaced
end

--============================================================================
-- EFFICIENT CASCADE CLEANUP
--============================================================================

-- Batch remove falling column and return edge neighbors to queue
function WaterService:_cleanupFallingColumn(x, startY, z)
	if self._inCleanup then
		return 0
	end

	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return 0
	end

	-- Collect falling blocks in one pass
	local toRemove = {}
	for checkY = startY, Constants.MIN_HEIGHT, -1 do
		if not isChunkLoaded(wm, x, z) then
			break
		end
		local blockId = wm:GetBlock(x, checkY, z)
		if blockId == BLOCK.FLOWING_WATER then
			local meta = wm:GetBlockMetadata(x, checkY, z) or 0
			if WaterUtils.IsFalling(meta) then
				toRemove[#toRemove + 1] = checkY
			else
				break
			end
		elseif blockId ~= BLOCK.AIR then
			break
		end
	end

	if #toRemove == 0 then
		return 0
	end

	-- Batch remove
	self._inCleanup = true
	for i = 1, #toRemove do
		vws:SetBlock(x, toRemove[i], z, BLOCK.AIR, nil, 0)
	end
	self._inCleanup = false

	-- Collect unique edge neighbors
	local edgeSet = {}
	for i = 1, #toRemove do
		local y = toRemove[i]
		for _, d in ipairs(CARDINALS) do
			local nx, nz = x + d.dx, z + d.dz
			local k = posKey(nx, y, nz)
			if not edgeSet[k] and isChunkLoaded(wm, nx, nz) then
				if wm:GetBlock(nx, y, nz) == BLOCK.FLOWING_WATER then
					edgeSet[k] = true
					self:_enqueue(nx, y, nz)
				end
			end
		end
	end

	return #toRemove
end

-- Check if flowing water has valid source, excluding certain positions
local function hasSourceExcluding(wm, x, y, z, depth, excluded)
	-- Check above
	if y + 1 <= Constants.WORLD_HEIGHT then
		local aboveK = posKey(x, y + 1, z)
		if not excluded[aboveK] then
			local aboveId = wm:GetBlock(x, y + 1, z)
			if aboveId == BLOCK.WATER_SOURCE then
				return true
			end
			if aboveId == BLOCK.FLOWING_WATER then
				return true
			end
		end
	end

	-- Check cardinal neighbors
	for _, d in ipairs(CARDINALS) do
		local nx, nz = x + d.dx, z + d.dz
		local nk = posKey(nx, y, nz)
		if excluded[nk] then
			continue
		end
		if not isChunkLoaded(wm, nx, nz) then
			continue
		end

		local nBlockId = wm:GetBlock(nx, y, nz)
		if nBlockId == BLOCK.WATER_SOURCE then
			return true
		end
		if nBlockId == BLOCK.FLOWING_WATER then
			local nMeta = wm:GetBlockMetadata(nx, y, nz) or 0
			if WaterUtils.GetDepth(nMeta) < depth then
				return true
			end
		end
	end

	return false
end

-- Direct cascade: immediately remove dependent orphaned water
-- More efficient than queuing each block for later processing
function WaterService:_cascadeRemove(x, y, z)
	if self._inCleanup then
		return 0
	end

	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return 0
	end

	-- Phase 1: Collect all orphaned blocks using BFS
	local orphaned = {}
	local toProcess = {{x = x, y = y, z = z}}
	local head = 1

	while head <= #toProcess do
		local node = toProcess[head]
		head += 1

		local nx, ny, nz = node.x, node.y, node.z
		local k = posKey(nx, ny, nz)

		if orphaned[k] then
			continue
		end
		if not isChunkLoaded(wm, nx, nz) then
			continue
		end

		local blockId = wm:GetBlock(nx, ny, nz)
		if blockId ~= BLOCK.FLOWING_WATER then
			continue
		end

		local meta = wm:GetBlockMetadata(nx, ny, nz) or 0
		local depth = WaterUtils.GetDepth(meta)

		-- Check if this block has a valid source (excluding already-orphaned blocks)
		if hasSourceExcluding(wm, nx, ny, nz, depth, orphaned) then
			continue -- Has source, not orphaned
		end

		-- Mark as orphaned
		orphaned[k] = {x = nx, y = ny, z = nz, depth = depth}

		-- Add neighbors to check (they might depend on this block)
		for _, d in ipairs(CARDINALS) do
			local nnx, nnz = nx + d.dx, nz + d.dz
			local nk = posKey(nnx, ny, nnz)
			if not orphaned[nk] then
				toProcess[#toProcess + 1] = {x = nnx, y = ny, z = nnz}
			end
		end

		-- Check below for dependent falling water
		if ny - 1 >= Constants.MIN_HEIGHT then
			local belowK = posKey(nx, ny - 1, nz)
			if not orphaned[belowK] then
				toProcess[#toProcess + 1] = {x = nx, y = ny - 1, z = nz}
			end
		end
	end

	-- Phase 2: Batch remove all orphaned blocks
	local count = 0
	for _, _ in pairs(orphaned) do count += 1 end
	if count == 0 then
		return 0
	end

	self._inCleanup = true
	for _, pos in pairs(orphaned) do
		vws:SetBlock(pos.x, pos.y, pos.z, BLOCK.AIR, nil, 0)
	end
	self._inCleanup = false

	-- Phase 3: Queue edge neighbors (non-orphaned water adjacent to removed blocks)
	local queued = {}
	for _, pos in pairs(orphaned) do
		for _, d in ipairs(CARDINALS) do
			local nx, nz = pos.x + d.dx, pos.z + d.dz
			local nk = posKey(nx, pos.y, nz)
			if not orphaned[nk] and not queued[nk] and isChunkLoaded(wm, nx, nz) then
				local nBlockId = wm:GetBlock(nx, pos.y, nz)
				if nBlockId == BLOCK.FLOWING_WATER then
					queued[nk] = true
					self:_enqueue(nx, pos.y, nz)
				end
			end
		end
	end

	return count
end

-- Legacy wrapper
function WaterService:_instantCleanupColumn(x, startY, z)
	return self:_cleanupFallingColumn(x, startY, z)
end

--============================================================================
-- DOWNHILL PATHFINDING (Simplified BFS)
--============================================================================

function WaterService:_findDropDistance(wm, x, y, z, maxDist)
	if not isChunkLoaded(wm, x, z) then
		return 1000
	end

	local visited = {[posKey(x, y, z)] = true}
	local queue = {{x = x, z = z, d = 0}}
	local head = 1

	while head <= #queue do
		local node = queue[head]
		head += 1

		if node.d >= maxDist then
			continue
		end

		-- Check if can drop here
		local belowId = (y - 1 >= Constants.MIN_HEIGHT) and wm:GetBlock(node.x, y - 1, node.z)
		if belowId and canFlowInto(belowId) then
			return node.d + 1
		end

		-- Expand cardinals only
		for _, d in ipairs(CARDINALS) do
			local nx, nz = node.x + d.dx, node.z + d.dz
			local k = posKey(nx, y, nz)
			if not visited[k] then
				visited[k] = true
				if isChunkLoaded(wm, nx, nz) then
					local nid = wm:GetBlock(nx, y, nz)
					if canFlowInto(nid) or WaterUtils.IsWater(nid) then
						queue[#queue + 1] = {x = nx, z = nz, d = node.d + 1}
					end
				end
			end
		end
	end

	return 1000
end

--============================================================================
-- WATER BLOCK UPDATE
--============================================================================

function WaterService:_updateWaterBlock(x, y, z)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return false
	end
	if not isChunkLoaded(wm, x, z) then
		return false
	end

	local id = wm:GetBlock(x, y, z)
	if not WaterUtils.IsWater(id) then
		return false
	end

	local meta = wm:GetBlockMetadata(x, y, z) or 0
	local isSource = (id == BLOCK.WATER_SOURCE)
	local depth = isSource and 0 or WaterUtils.GetDepth(meta)
	local fallDist = isSource and 0 or WaterUtils.GetFallDistance(meta)
	local isFalling = WaterUtils.IsFalling(meta)

	-- Get vertical neighbors
	local aboveId = (y + 1 <= Constants.WORLD_HEIGHT) and wm:GetBlock(x, y + 1, z) or BLOCK.AIR
	local belowId = (y - 1 >= Constants.MIN_HEIGHT) and wm:GetBlock(x, y - 1, z) or BLOCK.AIR

	-- Skip interior falling column blocks (handled by column top)
	-- But DON'T skip bottom of column - it needs to process horizontal spread
	if not isSource and isFalling and canFlowInto(belowId) then
		local aboveMeta = (y + 1 <= Constants.WORLD_HEIGHT) and (wm:GetBlockMetadata(x, y + 1, z) or 0) or 0
		if WaterUtils.IsWater(aboveId) and WaterUtils.IsFalling(aboveMeta) then
			return false -- Interior of column, skip
		end
	end

	-- Cache horizontal neighbors
	local neighbors = {}
	for _, d in ipairs(HORIZONTAL_8) do
		local nx, nz = x + d.dx, z + d.dz
		if isChunkLoaded(wm, nx, nz) then
			neighbors[#neighbors + 1] = {
				x = nx, z = nz,
				dx = d.dx, dz = d.dz,
				id = wm:GetBlock(nx, y, nz),
				meta = wm:GetBlockMetadata(nx, y, nz) or 0,
			}
		end
	end

	local changed = false

	-- FLOWING WATER: Validate depth or remove
	if not isSource then
		local bestDepth, bestFallDist = nil, nil

		-- Check above (water from above = depth 0)
		if WaterUtils.IsWater(aboveId) then
			local aboveMeta = wm:GetBlockMetadata(x, y + 1, z) or 0
			local aDepth = (aboveId == BLOCK.WATER_SOURCE) and 0 or WaterUtils.GetDepth(aboveMeta)
			local aFall = (aboveId == BLOCK.WATER_SOURCE) and 0 or WaterUtils.GetFallDistance(aboveMeta)
			bestDepth, bestFallDist = aDepth, aFall
		end

		-- Check horizontal neighbors
		for _, nb in ipairs(neighbors) do
			if nb.id == BLOCK.WATER_SOURCE then
				if not bestDepth or 1 < bestDepth then
					bestDepth, bestFallDist = 1, 0
				end
			elseif nb.id == BLOCK.FLOWING_WATER then
				local nDepth = WaterUtils.GetDepth(nb.meta) + 1
				local nFall = WaterUtils.GetFallDistance(nb.meta)
				if not bestDepth or nDepth < bestDepth or (nDepth == bestDepth and nFall < bestFallDist) then
					bestDepth, bestFallDist = nDepth, nFall
				end
			end
		end

		-- No source path OR lost shorter path: remove
		-- Water at depth D requires a neighbor at depth D-1 (or source adjacent)
		-- If bestDepth > depth, the short path is gone and water should decay
		-- Note: vws:SetBlock triggers OnBlockChanged which handles:
		-- 1. Cleanup of falling water below
		-- 2. Queuing of cardinal neighbors
		if not bestDepth or bestDepth > depth then
			vws:SetBlock(x, y, z, BLOCK.AIR, nil, 0)
			return true
		end

		-- Update metadata if needed
		local canDrop = canFlowInto(belowId)
		local hasAbove = WaterUtils.IsWater(aboveId)
		local shouldFall = canDrop or hasAbove
		bestFallDist = math.min(bestFallDist or 0, MAX_FALL_DISTANCE)

		if bestDepth ~= depth or shouldFall ~= isFalling or bestFallDist ~= fallDist then
			local newMeta = WaterUtils.MakeMetadata(bestDepth, shouldFall, bestFallDist)
			vws:SetBlock(x, y, z, BLOCK.FLOWING_WATER, nil, newMeta)
			depth, isFalling, fallDist = bestDepth, shouldFall, bestFallDist
			changed = true
		end
	end

	-- DOWNWARD FLOW (priority)
	if canFlowInto(belowId) then
		-- Skip if falling column already exists (prevents repeated recreation)
		if belowId == BLOCK.FLOWING_WATER then
			local belowMeta = wm:GetBlockMetadata(x, y - 1, z) or 0
			if WaterUtils.IsFalling(belowMeta) then
				return changed -- Column already exists
			end
		end
		local sourceDepth = isSource and 0 or depth
		local _, placed = self:_instantFallColumn(x, y, z, fallDist, sourceDepth)
		return placed > 0 or changed
	end

	-- Check max spread based on fall distance
	local maxDepth = WaterUtils.GetEffectiveMaxDepth(fallDist)
	if depth >= maxDepth then
		-- At max depth: check source conversion
		if not isSource and not isFalling then
			local sources = 0
			for _, nb in ipairs(neighbors) do
				if nb.id == BLOCK.WATER_SOURCE then
					sources += 1
				end
			end
			if sources >= 2 and (isSolid(belowId) or belowId == BLOCK.WATER_SOURCE) then
				local pk = strKey(x, y, z)
				local settle = (self._conversionCandidates[pk] or 0) + 1
				self._conversionCandidates[pk] = settle
				if settle >= SOURCE_CONVERSION_SETTLE_TICKS and self._conversionsThisTick < MAX_CONVERSIONS_PER_TICK then
					vws:SetBlock(x, y, z, BLOCK.WATER_SOURCE, nil, 0)
					self._conversionCandidates[pk] = nil
					self._conversionsThisTick += 1
					return true
				end
			else
				self._conversionCandidates[strKey(x, y, z)] = nil
			end
		end
		return changed
	else
		self._conversionCandidates[strKey(x, y, z)] = nil
	end

	-- HORIZONTAL SPREAD (cardinals only)
	local newDepth = depth + 1
	if newDepth > maxDepth then
		return changed
	end

	-- Find best flow direction (toward nearest drop)
	local minWeight = 1000
	local targets = {}

	for _, nb in ipairs(neighbors) do
		-- Cardinals only (dx == 0 or dz == 0, not both non-zero)
		if nb.dx == 0 or nb.dz == 0 then
			if canFlowInto(nb.id) then
				local w = self:_findDropDistance(wm, nb.x, y, nb.z, 4)
				targets[#targets + 1] = {x = nb.x, z = nb.z, w = w, id = nb.id, meta = nb.meta}
				if w < minWeight then
					minWeight = w
				end
			end
		end
	end

	-- Spread to best directions
	-- Note: vws:SetBlock triggers OnBlockChanged which queues the new block
	for _, t in ipairs(targets) do
		if t.w == minWeight then
			local shouldReplace = (t.id ~= BLOCK.FLOWING_WATER) or (newDepth < WaterUtils.GetDepth(t.meta))
			if shouldReplace then
				local newMeta = WaterUtils.MakeMetadata(newDepth, false, fallDist)
				vws:SetBlock(t.x, y, t.z, BLOCK.FLOWING_WATER, nil, newMeta)
				changed = true
			end
		end
	end

	return changed
end

--============================================================================
-- QUEUE PROCESSING
--============================================================================

function WaterService:_processQueue()
	if self._paused then
		return
	end

	self._conversionsThisTick = 0

	if self._dirty then
		self:_rebuildList()
	end
	if #self._queueList == 0 then
		self._conversionCandidates = {}
		return
	end

	local budget = MAX_UPDATES_PER_TICK
	local processed = 0
	local chunkBudget = {}

	while processed < budget and self._cursor <= #self._queueList do
		local item = self._queueList[self._cursor]
		self._cursor += 1

		if not self._queue[item.k] then
			continue
		end

		local cx = math.floor(item.x / Constants.CHUNK_SIZE_X)
		local cz = math.floor(item.z / Constants.CHUNK_SIZE_Z)
		local ck = cx * 65536 + cz
		local remaining = chunkBudget[ck] or MAX_UPDATES_PER_CHUNK

		if remaining > 0 then
			local changed = self:_updateWaterBlock(item.x, item.y, item.z)
			processed += 1
			chunkBudget[ck] = remaining - 1

			if not changed then
				self:_dequeue(item.k)
			end
		end
	end

	if self._cursor > #self._queueList then
		self._cursor = 1
	end
end

--============================================================================
-- BLOCK CHANGE HANDLER
--============================================================================

function WaterService:OnBlockChanged(x, y, z, newBlockId, newMeta, prevBlockId)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return
	end

	-- Water placed
	if WaterUtils.IsWater(newBlockId) then
		if newBlockId == BLOCK.WATER_SOURCE then
			wm:SetBlockMetadata(x, y, z, 0)
			local belowId = (y - 1 >= Constants.MIN_HEIGHT) and wm:GetBlock(x, y - 1, z)
			-- Only create falling column if air below (not into existing water)
			if belowId == BLOCK.AIR or (belowId and belowId ~= BLOCK.FLOWING_WATER and BlockRegistry:IsReplaceable(belowId)) then
				self:_instantFallColumn(x, y, z, 0, 0)
			end
			self:_enqueue(x, y, z)
			for _, d in ipairs(CARDINALS) do
				self:_enqueue(x + d.dx, y, z + d.dz)
			end
		elseif newBlockId == BLOCK.FLOWING_WATER then
			local meta = newMeta or (wm:GetBlockMetadata(x, y, z) or 0)
			local isFalling = WaterUtils.IsFalling(meta)
			-- Skip if part of existing falling column
			if isFalling then
				local aboveId = (y + 1 <= Constants.WORLD_HEIGHT) and wm:GetBlock(x, y + 1, z) or BLOCK.AIR
				if WaterUtils.IsWater(aboveId) then
					local aboveMeta = wm:GetBlockMetadata(x, y + 1, z) or 0
					if WaterUtils.IsFalling(aboveMeta) then
						return
					end
				end
			end
			self:_enqueue(x, y, z)
		end
		return
	end

	-- Water removed
	if WaterUtils.IsWater(prevBlockId) then
		-- Skip all processing if already in cleanup (cleanup handles queuing afterward)
		if self._inCleanup then
			return
		end

		-- Cascade remove: clean up falling water below and any dependent orphaned water
		local belowId = (y - 1 >= Constants.MIN_HEIGHT) and wm:GetBlock(x, y - 1, z)
		if belowId == BLOCK.FLOWING_WATER then
			local belowMeta = wm:GetBlockMetadata(x, y - 1, z) or 0
			if WaterUtils.IsFalling(belowMeta) then
				-- Falling water below - clean up the column
				self:_cleanupFallingColumn(x, y - 1, z)
			else
				-- Non-falling water below - cascade remove orphaned water
				self:_cascadeRemove(x, y - 1, z)
			end
		end

		-- Cascade remove adjacent orphaned water (more efficient than queuing)
		for _, d in ipairs(CARDINALS) do
			local nx, nz = x + d.dx, z + d.dz
			if isChunkLoaded(wm, nx, nz) then
				local nBlockId = wm:GetBlock(nx, y, nz)
				if nBlockId == BLOCK.FLOWING_WATER then
					self:_cascadeRemove(nx, y, nz)
				end
			end
		end

		-- Check above for falling water
		if y + 1 <= Constants.WORLD_HEIGHT then
			local aboveId = wm:GetBlock(x, y + 1, z)
			if aboveId == BLOCK.FLOWING_WATER then
				local aboveMeta = wm:GetBlockMetadata(x, y + 1, z) or 0
				if WaterUtils.IsFalling(aboveMeta) then
					-- This shouldn't happen (water above falling into removed block)
					-- but handle it anyway
					self:_enqueue(x, y + 1, z)
				else
					self:_cascadeRemove(x, y + 1, z)
				end
			end
		end
		return
	end

	-- Non-water block changed to air: check if water above can fall
	if newBlockId == BLOCK.AIR then
		local aboveId = (y + 1 <= Constants.WORLD_HEIGHT) and wm:GetBlock(x, y + 1, z)
		if WaterUtils.IsWater(aboveId) then
			local aboveMeta = wm:GetBlockMetadata(x, y + 1, z) or 0
			self:_instantFallColumn(x, y + 1, z, WaterUtils.GetFallDistance(aboveMeta), 0)
		end
		-- Queue adjacent water at this level
		for _, d in ipairs(CARDINALS) do
			local nx, nz = x + d.dx, z + d.dz
			if isChunkLoaded(wm, nx, nz) and WaterUtils.IsWater(wm:GetBlock(nx, y, nz)) then
				self:_enqueue(nx, y, nz)
			end
		end
	end
end

--============================================================================
-- PUBLIC API
--============================================================================

function WaterService:Pause() self._paused = true end
function WaterService:Resume() self._paused = false end

function WaterService:ClearQueue()
	self._queue = {}
	self._queueList = {}
	self._queueSize = 0
	self._cursor = 1
	self._dirty = false
	self._conversionCandidates = {}
	self._conversionsThisTick = 0
end

function WaterService:GetStats()
	local candidates = 0
	for _ in pairs(self._conversionCandidates) do candidates += 1 end
	return {
		queueSize = self._queueSize,
		paused = self._paused,
		conversionCandidates = candidates,
	}
end

function WaterService:ClearWaterInRadius(cx, cy, cz, radius)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return 0
	end

	local cleared = 0
	for dy = -radius, radius do
		for dz = -radius, radius do
			for dx = -radius, radius do
				local x, y, z = cx + dx, cy + dy, cz + dz
				if WaterUtils.IsWater(wm:GetBlock(x, y, z)) then
					vws:SetBlock(x, y, z, BLOCK.AIR)
					cleared += 1
				end
			end
		end
	end
	return cleared
end

return WaterService
