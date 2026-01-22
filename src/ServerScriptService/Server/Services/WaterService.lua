--[[
	WaterService.lua
	Minecraft-style water flow simulation for source/flowing water blocks.
	
	WATER SPREAD PATTERN:
	Water spreads to all 8 adjacent blocks (cardinals + diagonals), not just 4.
	
	  NW  N  NE
	   W [S] E     ← All 8 blocks at same Y-level receive flow
	  SW  S  SE
	
	This creates circular/diamond spread patterns matching Minecraft behavior.
	Diagonal flow has the same depth cost as cardinal flow (1 per block).
	
	DEPTH SYSTEM:
	- Source blocks have depth 0
	- Each horizontal step (cardinal OR diagonal) increases depth by 1
	- Max depth is 7 (water disappears beyond this)
	- Falling water resets depth to 0 but tracks fall distance
	
	FALLING FLAG (Minecraft 0x8 bit):
	The falling flag is set when EITHER condition is true:
	1. Water CAN flow down (air/replaceable below)
	2. Water HAS water directly above it
	
	This ensures waterfalls render at full height even when hitting surfaces:
	
	    [S] ← Source
	    [F] ← Falling (can flow down)
	    [F] ← Falling (water above, solid below) ← Key case!
	   ═════ ← Solid ground
	
	Without this, the bottom block would render at reduced height.
	
	DOWNHILL PATHFINDING:
	Water prefers flowing toward the nearest drop-off (edge).
	BFS searches all 8 directions to find shortest path to a hole.
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

local TICK_INTERVAL = 0.25 -- 5 ticks at 20 TPS
local MAX_UPDATES_PER_TICK = 200
local MAX_UPDATES_PER_CHUNK = 50
local MAX_QUEUE_SIZE = 50000
local SOURCE_DEPTH = WaterUtils.MAX_DEPTH + 1
local THROTTLE_THRESHOLD_FRAMES = 3
local REFLOW_RADIUS = 4
local MAX_FALL_DISTANCE = 15 -- Maximum fall distance tracked (metadata limit)
local MAX_TOTAL_FALL = 64 -- Water dissipates after falling this far without solid support

function WaterService.new()
	local self = setmetatable(BaseService.new(), WaterService)
	self.Name = "WaterService"
	self._queue = {} -- key -> true
	self._queueKeys = {}
	self._queueDirty = true
	self._cursor = 1
	self._queueSize = 0
	self._droppedUpdates = 0
	-- Adaptive throttling
	self._overBudgetFrames = 0
	self._currentBudget = MAX_UPDATES_PER_TICK
	self._throttled = false
	-- Pause control
	self._paused = false
	return self
end

function WaterService:Init()
	if self._initialized then return end
	BaseService.Init(self)
end

function WaterService:Start()
	if self._started then return end
	BaseService.Start(self)

	task.spawn(function()
		while self._started do
			self:_processQueue()
			task.wait(TICK_INTERVAL)
		end
	end)
end

function WaterService:Destroy()
	if self._destroyed then return end
	BaseService.Destroy(self)
	self._queue = {}
	self._queueKeys = {}
	self._queueDirty = true
	self._queueSize = 0
end

local function _key(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

function WaterService:_queueKey(x, y, z)
	local k = _key(x, y, z)
	if self._queue[k] then
		return
	end
	if self._queueSize >= MAX_QUEUE_SIZE then
		self._droppedUpdates += 1
		return
	end
	self._queue[k] = true
	self._queueDirty = true
	self._queueSize += 1
end

-- 8-direction horizontal spread + vertical (Minecraft-style)
-- Water spreads to all 8 neighbors at same Y level
local HORIZONTAL_NEIGHBORS = {
	-- Cardinals
	{dx = 1, dz = 0},   -- East (+X)
	{dx = -1, dz = 0},  -- West (-X)
	{dx = 0, dz = 1},   -- South (+Z)
	{dx = 0, dz = -1},  -- North (-Z)
	-- Diagonals
	{dx = 1, dz = 1},   -- SE (+X, +Z)
	{dx = 1, dz = -1},  -- NE (+X, -Z)
	{dx = -1, dz = 1},  -- SW (-X, +Z)
	{dx = -1, dz = -1}, -- NW (-X, -Z)
}

function WaterService:_queueNeighbors(x, y, z)
	-- Vertical
	self:_queueKey(x, y + 1, z)
	self:_queueKey(x, y - 1, z)
	-- All 8 horizontal directions
	for _, dir in ipairs(HORIZONTAL_NEIGHBORS) do
		self:_queueKey(x + dir.dx, y, z + dir.dz)
	end
end

function WaterService:_rebuildQueueKeys()
	self._queueKeys = {}
	for k in pairs(self._queue) do
		table.insert(self._queueKeys, k)
	end
	self._queueDirty = false
	if self._cursor > #self._queueKeys then
		self._cursor = 1
	end
end

local function _canFlowInto(blockId)
	if blockId == BLOCK.WATER_SOURCE then
		return false
	end
	if blockId == BLOCK.FLOWING_WATER then
		return true
	end
	return BlockRegistry:IsReplaceable(blockId)
end

local function _isChunkLoaded(wm, x, z)
	if not wm or not wm.chunks then
		return false
	end
	local cx = math.floor(x / Constants.CHUNK_SIZE_X)
	local cz = math.floor(z / Constants.CHUNK_SIZE_Z)
	local key = Constants.ToChunkKey(cx, cz)
	return wm.chunks[key] ~= nil
end

local function _isSolid(blockId)
	if blockId == BLOCK.AIR then
		return false
	end
	local def = BlockRegistry:GetBlock(blockId)
	return def and def.solid == true
end

local function _shouldReplaceWater(blockId, metadata, newDepth)
	if blockId ~= BLOCK.FLOWING_WATER then
		return true
	end
	local currentDepth = WaterUtils.GetDepth(metadata)
	return newDepth < currentDepth
end

local function _countCardinalSources(hNeighbors)
	local sources = 0
	if hNeighbors.east.id == BLOCK.WATER_SOURCE then
		sources += 1
	end
	if hNeighbors.west.id == BLOCK.WATER_SOURCE then
		sources += 1
	end
	if hNeighbors.south.id == BLOCK.WATER_SOURCE then
		sources += 1
	end
	if hNeighbors.north.id == BLOCK.WATER_SOURCE then
		sources += 1
	end
	return sources
end

function WaterService:_setFlowingWater(x, y, z, depth, falling, fallDistance)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws then return false end
	fallDistance = math.min(fallDistance or 0, MAX_FALL_DISTANCE)
	local meta = WaterUtils.MakeMetadata(depth, falling, fallDistance)
	vws:SetBlock(x, y, z, BLOCK.FLOWING_WATER, nil, meta)
	self:_queueKey(x, y, z)
	self:_queueNeighbors(x, y, z)
	return true
end

function WaterService:_findDownhillDistance(x, y, z, maxDistance): number
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return 1000
	end
	if not _isChunkLoaded(wm, x, z) then
		return 1000
	end

	local visited = {}
	local queue = { { x = x, z = z, d = 0 } }
	visited[_key(x, y, z)] = true

	while #queue > 0 do
		local node = table.remove(queue, 1)
		if node.d >= maxDistance then
			continue
		end

		if (y - 1) >= Constants.MIN_HEIGHT then
			local belowId = wm:GetBlock(node.x, y - 1, node.z)
			if _canFlowInto(belowId) then
				return node.d + 1
			end
		end

		-- Check all 8 horizontal directions
		for _, dir in ipairs(HORIZONTAL_NEIGHBORS) do
			local nx = node.x + dir.dx
			local nz = node.z + dir.dz
			local key = _key(nx, y, nz)
			if not visited[key] then
				if not _isChunkLoaded(wm, nx, nz) then
					visited[key] = true
					continue
				end
				local nid = wm:GetBlock(nx, y, nz)
				if _canFlowInto(nid) or WaterUtils.IsWater(nid) then
					visited[key] = true
					table.insert(queue, { x = nx, z = nz, d = node.d + 1 })
				end
			end
		end
	end

	return 1000
end

-- Optimized update: caches neighbor lookups to avoid redundant GetBlock calls
function WaterService:_updateWaterBlock(x, y, z): boolean
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then
		return false
	end

	local id = wm:GetBlock(x, y, z)
	if not WaterUtils.IsWater(id) then
		return false
	end

	if y < Constants.MIN_HEIGHT or y > Constants.WORLD_HEIGHT then
		return false
	end
	if not _isChunkLoaded(wm, x, z) then
		return false
	end

	local meta = wm:GetBlockMetadata(x, y, z) or 0
	local depth = (id == BLOCK.WATER_SOURCE) and 0 or WaterUtils.GetDepth(meta)
	local fallDistance = (id == BLOCK.WATER_SOURCE) and 0 or WaterUtils.GetFallDistance(meta)
	local isFalling = WaterUtils.IsFalling(meta)

	-- Cache neighbor lookups (avoid repeated GetBlock calls)
	local aboveId = (y + 1 <= Constants.WORLD_HEIGHT) and wm:GetBlock(x, y + 1, z) or BLOCK.AIR
	local belowId = (y - 1 >= Constants.MIN_HEIGHT) and wm:GetBlock(x, y - 1, z) or BLOCK.AIR
	local belowMeta = (y - 1 >= Constants.MIN_HEIGHT) and (wm:GetBlockMetadata(x, y - 1, z) or 0) or 0

	-- Cache all 8 horizontal neighbors: {id, meta, chunkLoaded}
	-- Coordinate system: +X = East, -X = West, +Z = South, -Z = North
	local hNeighbors = {
		-- Cardinals
		east  = {x = x + 1, z = z, dx = 1, dz = 0},
		west  = {x = x - 1, z = z, dx = -1, dz = 0},
		south = {x = x, z = z + 1, dx = 0, dz = 1},
		north = {x = x, z = z - 1, dx = 0, dz = -1},
		-- Diagonals
		ne = {x = x + 1, z = z - 1, dx = 1, dz = -1},
		nw = {x = x - 1, z = z - 1, dx = -1, dz = -1},
		se = {x = x + 1, z = z + 1, dx = 1, dz = 1},
		sw = {x = x - 1, z = z + 1, dx = -1, dz = 1},
	}
	for dir, nb in pairs(hNeighbors) do
		if _isChunkLoaded(wm, nb.x, nb.z) then
			nb.id = wm:GetBlock(nb.x, y, nb.z)
			nb.meta = wm:GetBlockMetadata(nb.x, y, nb.z) or 0
			nb.loaded = true
		else
			nb.id = BLOCK.AIR
			nb.meta = 0
			nb.loaded = false
		end
	end

	local changed = false

	-- Recompute flowing water depth or remove if unsupported
	if id == BLOCK.FLOWING_WATER then
		-- Compute desired depth and fall distance from cached neighbors
		local desiredDepth = nil
		local desiredFallDistance = nil
		local function considerSource(candidate, candidateFallDist)
			if candidate ~= nil and candidate >= 0 and candidate <= WaterUtils.MAX_DEPTH then
				if not desiredDepth or candidate < desiredDepth then
					desiredDepth = candidate
					desiredFallDistance = candidateFallDist or 0
				elseif candidate == desiredDepth and (candidateFallDist or 0) < (desiredFallDistance or 0) then
					-- Prefer lower fall distance at same depth
					desiredFallDistance = candidateFallDist or 0
				end
			end
		end

		-- Check above (vertical water source - inherits fall distance)
		if WaterUtils.IsWater(aboveId) then
			local aboveMeta = wm:GetBlockMetadata(x, y + 1, z) or 0
			local aboveDepth = (aboveId == BLOCK.WATER_SOURCE) and 0
				or WaterUtils.GetDepth(aboveMeta)
			local aboveFallDist = (aboveId == BLOCK.WATER_SOURCE) and 0
				or WaterUtils.GetFallDistance(aboveMeta)
			-- Water from above inherits its fall distance (we add 1 when flowing down)
			considerSource(aboveDepth, aboveFallDist)
		end

		-- Check horizontal neighbors
		for _, nb in pairs(hNeighbors) do
			if nb.loaded then
				if nb.id == BLOCK.WATER_SOURCE then
					considerSource(1, 0) -- Source resets fall distance
				elseif nb.id == BLOCK.FLOWING_WATER then
					local nbFallDist = WaterUtils.GetFallDistance(nb.meta)
					-- Horizontal spread inherits fall distance from neighbor
					considerSource(WaterUtils.GetDepth(nb.meta) + 1, nbFallDist)
				end
			end
		end

		if desiredDepth == nil then
			vws:SetBlock(x, y, z, BLOCK.AIR)
			self:_queueNeighbors(x, y, z)
			return true
		end

		-- Minecraft falling flag: set if CAN flow down OR HAS water above
		-- This ensures waterfalls render at full height even when hitting surfaces
		local canFlowDown = (y - 1 >= Constants.MIN_HEIGHT) and _canFlowInto(belowId)
		local hasWaterAbove = WaterUtils.IsWater(aboveId)
		local falling = canFlowDown or hasWaterAbove
		desiredFallDistance = math.min(desiredFallDistance or 0, MAX_FALL_DISTANCE)
		if desiredDepth ~= depth or WaterUtils.IsFalling(meta) ~= falling or fallDistance ~= desiredFallDistance then
			local newMeta = WaterUtils.MakeMetadata(desiredDepth, falling, desiredFallDistance)
			vws:SetBlock(x, y, z, BLOCK.FLOWING_WATER, nil, newMeta)
			changed = true
		end
	end

	-- Downward flow (highest priority)
	if (y - 1) >= Constants.MIN_HEIGHT and _canFlowInto(belowId) then
		-- Increment fall distance when flowing down
		local newFallDistance = (id == BLOCK.WATER_SOURCE) and 1 or math.min(fallDistance + 1, MAX_FALL_DISTANCE)
		
		-- Check if water has fallen too far and should dissipate (but not if falling into existing water)
		if newFallDistance >= MAX_TOTAL_FALL and belowId ~= BLOCK.FLOWING_WATER then
			-- Water dissipates - don't spread further down
			return changed
		end
		
		if _shouldReplaceWater(belowId, belowMeta, 0) then
			changed = self:_setFlowingWater(x, y - 1, z, 0, true, newFallDistance) or changed
		end
		return changed
	end

	-- When water lands (was falling, now blocked below), limit its spread based on fall distance
	local effectiveMaxDepth = WaterUtils.GetEffectiveMaxDepth(fallDistance)
	
	-- Prevent any horizontal spread for water that has fallen very far (dissipation)
	if fallDistance >= MAX_FALL_DISTANCE and isFalling then
		-- Water that was falling and has reached max fall distance cannot spread horizontally
		-- It effectively dissipates/splashes
		return changed
	end
	
	-- Horizontal flow (only when downward blocked)
	if depth >= effectiveMaxDepth then
		-- At max depth, check source conversion
		if id == BLOCK.FLOWING_WATER then
			-- Only convert after settling; falling water never converts
			if not isFalling then
				-- Count adjacent sources from cardinals only (no diagonals)
				local sources = _countCardinalSources(hNeighbors)
				if sources >= 2 and (_isSolid(belowId) or belowId == BLOCK.WATER_SOURCE) then
					vws:SetBlock(x, y, z, BLOCK.WATER_SOURCE, nil, 0)
					self:_queueNeighbors(x, y, z)
					changed = true
				end
			end
		end
		return changed
	end

	local newDepth = depth + 1
	
	-- Skip horizontal spread if already at effective max depth
	if newDepth > effectiveMaxDepth then
		return changed
	end

	-- Find downhill weights using cached neighbors
	local minWeight = 1000
	local weights = {}
	for dir, nb in pairs(hNeighbors) do
		if nb.loaded and _canFlowInto(nb.id) then
			local weight = self:_findDownhillDistance(nb.x, y, nb.z, 4)
			weights[#weights + 1] = { x = nb.x, z = nb.z, weight = weight, id = nb.id, meta = nb.meta }
			if weight < minWeight then
				minWeight = weight
			end
		end
	end

	for _, entry in ipairs(weights) do
		if entry.weight == minWeight then
			if _shouldReplaceWater(entry.id, entry.meta, newDepth) then
				-- Propagate fall distance for horizontal spread
				changed = self:_setFlowingWater(entry.x, y, entry.z, newDepth, false, fallDistance) or changed
			end
		end
	end

	return changed
end

function WaterService:_processQueue()
	if self._paused then
		return
	end
	if self._queueDirty then
		self:_rebuildQueueKeys()
	end
	if #self._queueKeys == 0 then
		-- Recover budget when idle
		if self._throttled then
			self._currentBudget = MAX_UPDATES_PER_TICK
			self._throttled = false
			self._overBudgetFrames = 0
		end
		return
	end

	local budget = self._currentBudget
	local processed = 0
	local chunkBudget = {}
	local visitedThisTick = {}
	while processed < budget and self._cursor <= #self._queueKeys do
		local key = self._queueKeys[self._cursor]
		self._cursor += 1
		if not self._queue[key] then
			continue
		end
		if visitedThisTick[key] then
			continue
		end
		visitedThisTick[key] = true
		local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
		x = tonumber(x) y = tonumber(y) z = tonumber(z)
		local cx = math.floor(x / Constants.CHUNK_SIZE_X)
		local cz = math.floor(z / Constants.CHUNK_SIZE_Z)
		local chunkKey = Constants.ToChunkKey(cx, cz)
		local remaining = chunkBudget[chunkKey]
		if remaining == nil then
			remaining = MAX_UPDATES_PER_CHUNK
		end
		if remaining > 0 then
			local changed = self:_updateWaterBlock(x, y, z)
			processed += 1
			chunkBudget[chunkKey] = remaining - 1
			if not changed then
				self._queue[key] = nil
				self._queueDirty = true
				self._queueSize = math.max(0, self._queueSize - 1)
			end
		end
	end

	if self._cursor > #self._queueKeys then
		self._cursor = 1
	end

	-- Adaptive throttling: if processed hit budget limit for 3+ frames, halve budget
	if processed >= budget then
		self._overBudgetFrames += 1
		if self._overBudgetFrames >= THROTTLE_THRESHOLD_FRAMES and not self._throttled then
			self._currentBudget = math.max(50, math.floor(budget / 2))
			self._throttled = true
			warn(string.format("WaterService: throttling (budget %d -> %d, queue %d)", budget, self._currentBudget, self._queueSize))
		end
	else
		-- Below budget, recover
		self._overBudgetFrames = 0
		if self._throttled and self._queueSize < MAX_QUEUE_SIZE * 0.5 then
			self._currentBudget = math.min(MAX_UPDATES_PER_TICK, self._currentBudget * 2)
			if self._currentBudget >= MAX_UPDATES_PER_TICK then
				self._throttled = false
			end
		end
	end

	if self._droppedUpdates > 0 then
		warn(string.format("WaterService: dropped %d queued updates (queue full)", self._droppedUpdates))
		self._droppedUpdates = 0
	end
end

function WaterService:OnBlockChanged(x, y, z, newBlockId, _newMeta, prevBlockId)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then return end

	if WaterUtils.IsWater(newBlockId) then
		if newBlockId == BLOCK.WATER_SOURCE then
			wm:SetBlockMetadata(x, y, z, 0)
		end
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					self:_queueKey(x + dx, y + dy, z + dz)
				end
			end
		end
		return
	end

	if WaterUtils.IsWater(prevBlockId) then
		-- If a source was removed, trigger BFS reflow in region
		if prevBlockId == BLOCK.WATER_SOURCE then
			task.defer(function()
				self:ReflowRegion(x, y, z, REFLOW_RADIUS)
			end)
		end
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					self:_queueKey(x + dx, y + dy, z + dz)
				end
			end
		end
		return
	end

	-- If a non-water block changed, only queue if adjacent to water
	for dx = -1, 1 do
		for dy = -1, 1 do
			for dz = -1, 1 do
				local nx = x + dx
				local ny = y + dy
				local nz = z + dz
				local nid = wm:GetBlock(nx, ny, nz)
				if WaterUtils.IsWater(nid) then
					self:_queueKey(nx, ny, nz)
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Admin / Debug Commands
--------------------------------------------------------------------------------

function WaterService:Pause()
	self._paused = true
end

function WaterService:Resume()
	self._paused = false
end

function WaterService:ClearQueue()
	self._queue = {}
	self._queueKeys = {}
	self._queueDirty = true
	self._queueSize = 0
	self._cursor = 1
	self._droppedUpdates = 0
	self._overBudgetFrames = 0
	self._currentBudget = MAX_UPDATES_PER_TICK
	self._throttled = false
end

function WaterService:GetStats()
	return {
		queueSize = self._queueSize,
		paused = self._paused,
		throttled = self._throttled,
		currentBudget = self._currentBudget,
		droppedUpdates = self._droppedUpdates,
	}
end

function WaterService:ClearWaterInRadius(centerX, centerY, centerZ, radius)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then return 0 end

	local cleared = 0
	for dy = -radius, radius do
		for dz = -radius, radius do
			for dx = -radius, radius do
				local x = centerX + dx
				local y = centerY + dy
				local z = centerZ + dz
				local id = wm:GetBlock(x, y, z)
				if WaterUtils.IsWater(id) then
					vws:SetBlock(x, y, z, BLOCK.AIR)
					cleared += 1
				end
			end
		end
	end
	return cleared
end

--------------------------------------------------------------------------------
-- BFS Reflow: recompute water depths in region when source removed
--------------------------------------------------------------------------------

function WaterService:ReflowRegion(centerX, centerY, centerZ, radius)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local wm = vws and vws.worldManager
	if not wm then return end

	radius = radius or REFLOW_RADIUS

	-- Collect all water blocks and sources in region
	local waterBlocks = {}
	local sources = {}
	for dy = -radius, radius do
		for dz = -radius, radius do
			for dx = -radius, radius do
				local x = centerX + dx
				local y = centerY + dy
				local z = centerZ + dz
				local id = wm:GetBlock(x, y, z)
				if id == BLOCK.WATER_SOURCE then
					table.insert(sources, {x = x, y = y, z = z})
				elseif id == BLOCK.FLOWING_WATER then
					table.insert(waterBlocks, {x = x, y = y, z = z})
				end
			end
		end
	end

	-- BFS from sources to assign depths and fall distances
	local depthMap = {} -- key -> {depth, fallDistance}
	local queue = {}
	for _, src in ipairs(sources) do
		local k = _key(src.x, src.y, src.z)
		depthMap[k] = {depth = 0, fallDistance = 0}
		table.insert(queue, {x = src.x, y = src.y, z = src.z, depth = 0, fallDistance = 0})
	end

	while #queue > 0 do
		local node = table.remove(queue, 1)
		local currentDepth = node.depth
		local currentFallDistance = node.fallDistance
		local effectiveMaxDepth = WaterUtils.GetEffectiveMaxDepth(currentFallDistance)
		
		if currentDepth >= effectiveMaxDepth then
			continue
		end

		-- All 8 horizontal directions + down
		local neighbors = {
			-- Cardinals
			{dx = 1, dy = 0, dz = 0},
			{dx = -1, dy = 0, dz = 0},
			{dx = 0, dy = 0, dz = 1},
			{dx = 0, dy = 0, dz = -1},
			-- Diagonals
			{dx = 1, dy = 0, dz = 1},
			{dx = 1, dy = 0, dz = -1},
			{dx = -1, dy = 0, dz = 1},
			{dx = -1, dy = 0, dz = -1},
			-- Down
			{dx = 0, dy = -1, dz = 0},
		}
		for _, dir in ipairs(neighbors) do
			local nx = node.x + dir.dx
			local ny = node.y + dir.dy
			local nz = node.z + dir.dz
			local nk = _key(nx, ny, nz)
			local nid = wm:GetBlock(nx, ny, nz)

			if WaterUtils.IsWater(nid) and nid ~= BLOCK.WATER_SOURCE then
				local newDepth, newFallDistance
				if dir.dy == -1 then
					-- Flowing down: reset depth to 0, increment fall distance
					newDepth = 0
					newFallDistance = math.min(currentFallDistance + 1, MAX_FALL_DISTANCE)
				else
					-- Horizontal (cardinal or diagonal): increment depth, maintain fall distance
					newDepth = currentDepth + 1
					newFallDistance = currentFallDistance
				end
				
				local existing = depthMap[nk]
				local shouldUpdate = false
				if existing == nil then
					shouldUpdate = true
				elseif newDepth < existing.depth then
					shouldUpdate = true
				elseif newDepth == existing.depth and newFallDistance < existing.fallDistance then
					shouldUpdate = true
				end
				
				if shouldUpdate then
					depthMap[nk] = {depth = newDepth, fallDistance = newFallDistance}
					table.insert(queue, {x = nx, y = ny, z = nz, depth = newDepth, fallDistance = newFallDistance})
				end
			end
		end
	end

	-- Update or remove flowing water based on BFS results
	for _, wb in ipairs(waterBlocks) do
		local k = _key(wb.x, wb.y, wb.z)
		local data = depthMap[k]
		if data == nil then
			-- No path to source, remove
			vws:SetBlock(wb.x, wb.y, wb.z, BLOCK.AIR)
		else
			local belowId = ((wb.y - 1) >= Constants.MIN_HEIGHT) and wm:GetBlock(wb.x, wb.y - 1, wb.z) or BLOCK.AIR
			local aboveId = ((wb.y + 1) <= Constants.WORLD_HEIGHT) and wm:GetBlock(wb.x, wb.y + 1, wb.z) or BLOCK.AIR
			-- Minecraft falling flag: set if CAN flow down OR HAS water above
			local canFlowDown = _canFlowInto(belowId)
			local hasWaterAbove = WaterUtils.IsWater(aboveId)
			local falling = canFlowDown or hasWaterAbove
			local newMeta = WaterUtils.MakeMetadata(data.depth, falling, data.fallDistance)
			local currentMeta = wm:GetBlockMetadata(wb.x, wb.y, wb.z) or 0
			if newMeta ~= currentMeta then
				vws:SetBlock(wb.x, wb.y, wb.z, BLOCK.FLOWING_WATER, nil, newMeta)
			end
		end
		self:_queueKey(wb.x, wb.y, wb.z)
	end
end

return WaterService
