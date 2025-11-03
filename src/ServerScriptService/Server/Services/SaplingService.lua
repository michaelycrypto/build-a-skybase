--[[
	SaplingService.lua
	Straightforward Minecraft-like sapling growth for voxel world (Oak only for now)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local SaplingConfig = require(game.ReplicatedStorage.Configs.SaplingConfig)
local Logger = require(ReplicatedStorage.Shared.Logger)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

local SaplingService = setmetatable({}, BaseService)
SaplingService.__index = SaplingService

local BLOCK = Constants.BlockType

-- Standardize and gate module-local prints through Logger at DEBUG level
local _logger = Logger:CreateContext("SaplingService")
local function _toString(v)
    return tostring(v)
end
local function _concatArgs(...)
    local n = select("#", ...)
    local parts = table.create(n)
    for i = 1, n do
        parts[i] = _toString(select(i, ...))
    end
    return table.concat(parts, " ")
end
local print = function(...)
    _logger.Debug(_concatArgs(...))
end
local warn = function(...)
    _logger.Warn(_concatArgs(...))
end

-- 6-neighbor offsets reused across BFS to avoid per-iteration allocations
local NEIGHBOR_OFFSETS_6 = {
	{1,0,0}, {-1,0,0}, {0,1,0}, {0,-1,0}, {0,0,1}, {0,0,-1}
}

local function keyFor(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

local function parseKey(k)
	local x, y, z = string.match(k, "(-?%d+),(-?%d+),(-?%d+)")
	return tonumber(x), tonumber(y), tonumber(z)
end

local function getStageFromMeta(meta)
	local m = meta or 0
	return bit32.band(m, 0x1)
end

local function setStageInMeta(meta, stage)
	local base = meta or 0
	base = bit32.band(base, 0xFE) -- clear bit0
	if stage and stage ~= 0 then
		base = bit32.bor(base, 0x1)
	end
	return base
end

-- For leaves: store distance (0-7) in low 3 bits of metadata
local function getLeafDistance(meta)
    return bit32.band(meta or 0, 0x7)
end

local function setLeafDistance(meta, dist)
    local base = meta or 0
    base = bit32.band(base, bit32.bnot(0x7))
    return bit32.bor(base, math.clamp(dist or 7, 0, 7))
end

-- Wood families support (logs/saplings)
local ALL_SAPLINGS = {
    [BLOCK.OAK_SAPLING] = true,
    [BLOCK.SPRUCE_SAPLING] = true,
    [BLOCK.JUNGLE_SAPLING] = true,
    [BLOCK.DARK_OAK_SAPLING] = true,
    [BLOCK.BIRCH_SAPLING] = true,
    [BLOCK.ACACIA_SAPLING] = true,
}

local SAPLING_TO_LOG = {
    [BLOCK.OAK_SAPLING] = BLOCK.WOOD,
    [BLOCK.SPRUCE_SAPLING] = BLOCK.SPRUCE_LOG,
    [BLOCK.JUNGLE_SAPLING] = BLOCK.JUNGLE_LOG,
    [BLOCK.DARK_OAK_SAPLING] = BLOCK.DARK_OAK_LOG,
    [BLOCK.BIRCH_SAPLING] = BLOCK.BIRCH_LOG,
    [BLOCK.ACACIA_SAPLING] = BLOCK.ACACIA_LOG,
}

local LOG_TO_SAPLING = {
    [BLOCK.WOOD] = BLOCK.OAK_SAPLING,
    [BLOCK.SPRUCE_LOG] = BLOCK.SPRUCE_SAPLING,
    [BLOCK.JUNGLE_LOG] = BLOCK.JUNGLE_SAPLING,
    [BLOCK.DARK_OAK_LOG] = BLOCK.DARK_OAK_SAPLING,
    [BLOCK.BIRCH_LOG] = BLOCK.BIRCH_SAPLING,
    [BLOCK.ACACIA_LOG] = BLOCK.ACACIA_SAPLING,
}

local LOG_ANCHORS = {
    [BLOCK.WOOD] = true,
    [BLOCK.SPRUCE_LOG] = true,
    [BLOCK.JUNGLE_LOG] = true,
    [BLOCK.DARK_OAK_LOG] = true,
    [BLOCK.BIRCH_LOG] = true,
    [BLOCK.ACACIA_LOG] = true,
}

local LEAF_SET = {
    [BLOCK.LEAVES] = true,
    [BLOCK.OAK_LEAVES] = true,
    [BLOCK.SPRUCE_LEAVES] = true,
    [BLOCK.JUNGLE_LEAVES] = true,
    [BLOCK.DARK_OAK_LEAVES] = true,
    [BLOCK.BIRCH_LEAVES] = true,
    [BLOCK.ACACIA_LEAVES] = true,
}

local LOG_TO_LEAVES = {
    [BLOCK.WOOD] = BLOCK.OAK_LEAVES,
    [BLOCK.SPRUCE_LOG] = BLOCK.SPRUCE_LEAVES,
    [BLOCK.JUNGLE_LOG] = BLOCK.JUNGLE_LEAVES,
    [BLOCK.DARK_OAK_LOG] = BLOCK.DARK_OAK_LEAVES,
    [BLOCK.BIRCH_LOG] = BLOCK.BIRCH_LEAVES,
    [BLOCK.ACACIA_LOG] = BLOCK.ACACIA_LEAVES,
}

local LEAVES_TO_SAPLING = {
    [BLOCK.LEAVES] = BLOCK.OAK_SAPLING,
    [BLOCK.OAK_LEAVES] = BLOCK.OAK_SAPLING,
    [BLOCK.SPRUCE_LEAVES] = BLOCK.SPRUCE_SAPLING,
    [BLOCK.JUNGLE_LEAVES] = BLOCK.JUNGLE_SAPLING,
    [BLOCK.DARK_OAK_LEAVES] = BLOCK.DARK_OAK_SAPLING,
    [BLOCK.BIRCH_LEAVES] = BLOCK.BIRCH_SAPLING,
    [BLOCK.ACACIA_LEAVES] = BLOCK.ACACIA_SAPLING,
}

-- Encode leaf species in metadata bits 4-6 (0..7) to survive log removal/server restarts
local function getLeafSpecies(meta)
    local v = bit32.band(meta or 0, 0x70) -- bits 4-6
    return bit32.rshift(v, 4)
end

local function setLeafSpecies(meta, speciesCode)
    local base = meta or 0
    local cleared = bit32.band(base, bit32.bnot(0x70))
    local coded = bit32.lshift(bit32.band(speciesCode or 0, 0x7), 4)
    return bit32.bor(cleared, coded)
end

local LEAF_TO_SPECIES_CODE = {
    [BLOCK.OAK_LEAVES] = 0,
    [BLOCK.SPRUCE_LEAVES] = 1,
    [BLOCK.JUNGLE_LEAVES] = 2,
    [BLOCK.DARK_OAK_LEAVES] = 3,
    [BLOCK.BIRCH_LEAVES] = 4,
    [BLOCK.ACACIA_LEAVES] = 5,
}

local SPECIES_CODE_TO_SAPLING = {
    [0] = BLOCK.OAK_SAPLING,
    [1] = BLOCK.SPRUCE_SAPLING,
    [2] = BLOCK.JUNGLE_SAPLING,
    [3] = BLOCK.DARK_OAK_SAPLING,
    [4] = BLOCK.BIRCH_SAPLING,
    [5] = BLOCK.ACACIA_SAPLING,
}

function SaplingService:_isLeaf(blockId)
    return LEAF_SET[blockId] == true
end

-- Schedule unsupported leaf for gradual decay (placed after helpers to use keyFor)
function SaplingService:_scheduleUnsupported(x, y, z)
	local k = keyFor(x, y, z)
	self._unsupportedSet[k] = true
	if not self._unsupportedSchedule[k] then
		local minD = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SCHEDULE_DELAY_MIN) or 1.0
		local maxD = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SCHEDULE_DELAY_MAX) or 6.0
		local rng = Random.new(self:_seedFor(x, y, z))
		local delay = rng:NextNumber(minD, math.max(minD, maxD))
		self._unsupportedSchedule[k] = os.clock() + delay
	end
end

function SaplingService.new()
	local self = setmetatable(BaseService.new(), SaplingService)
	self.Name = "SaplingService"
	self._saplings = {} -- key -> {x,y,z}
	self._iterKeys = {}
	self._iterCursor = 1
	self._iterDirty = true
	self._scannedChunks = {} -- "cx,cz" -> true
	self._unsupportedSet = {}
	self._unsupportedSchedule = {} -- key -> os.clock() time when eligible to decay
    self._chunkSpecies = {} -- "cx,cz" -> speciesCode (0..5)
	return self
end

function SaplingService:Init()
	if self._initialized then return end
	BaseService.Init(self)
	print("SaplingService: Initialized")
end

function SaplingService:Start()
	if self._started then return end
	BaseService.Start(self)

	-- Periodic growth checks
	task.spawn(function()
		while self._started do
			self:_tick()
			task.wait(SaplingConfig.TICK_INTERVAL or 5)
		end
	end)

	-- Leaf decay tick separate from sapling growth for smoother cadence
	task.spawn(function()
		while self._started do
			if not (GameConfig.PERF_DEBUG and GameConfig.PERF_DEBUG.DISABLE_SAPLING_LEAF_TICK) then
				local t0 = os.clock()
				self:_leafTick()
				local dtMs = (os.clock() - t0) * 1000
				if dtMs > 5 then
					warn(string.format("SaplingService leaf tick took %.1f ms", dtMs))
				end
			end
			local overrideInterval = GameConfig.PERF_DEBUG and GameConfig.PERF_DEBUG.LEAF_TICK_INTERVAL
			local interval = overrideInterval or ((SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.TICK_INTERVAL) or 0.5)
			task.wait(interval)
		end
	end)

	print("SaplingService: Started")
end

function SaplingService:Destroy()
	if self._destroyed then return end
	self._saplings = {}
	BaseService.Destroy(self)
	print("SaplingService: Destroyed")
end

-- Called by VoxelWorldService whenever a block changes
function SaplingService:OnBlockChanged(x, y, z, newBlockId, newMetadata, oldBlockId)
	local k = keyFor(x, y, z)
	if ALL_SAPLINGS[newBlockId] then
		self._saplings[k] = {x = x, y = y, z = z}
		self._iterDirty = true
	else
		self._saplings[k] = nil
		self._iterDirty = true
	end

	-- Recompute leaf distances around changes involving logs or leaf placements (not removals)
    local involvesLeafOrLog = LOG_ANCHORS[newBlockId] or LOG_ANCHORS[oldBlockId] or self:_isLeaf(newBlockId) or self:_isLeaf(oldBlockId)
	if involvesLeafOrLog then
		local vm = self.Deps and self.Deps.VoxelWorldService and self.Deps.VoxelWorldService.worldManager
		if vm then
			SaplingService._recomputeLeafDistances(self, vm, x, y, z, (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6)
		end
	end
end

function SaplingService:GetChunkSpecies(cx, cz)
    return self._chunkSpecies and self._chunkSpecies[string.format("%d,%d", cx, cz)]
end

function SaplingService:_tick()
	local budget = SaplingConfig.MAX_PER_TICK or 24
	local processed = 0

	-- Refresh iterator list if dirty
	if self._iterDirty then
		self._iterKeys = {}
		for k in pairs(self._saplings) do
			self._iterKeys[#self._iterKeys + 1] = k
		end
		-- Keep cursor within bounds
		if self._iterCursor > #self._iterKeys then
			self._iterCursor = 1
		end
		self._iterDirty = false
	end

	local keys = self._iterKeys

	local vm = self.Deps and self.Deps.VoxelWorldService and self.Deps.VoxelWorldService.worldManager
	if not vm then return end

	local total = #keys
	if total > 0 then
		local tries = 0
		while processed < budget and tries < total do
			local idx = self._iterCursor
			local k = keys[idx]
			local sx, sy, sz = parseKey(k)
			-- Validate still a sapling
				local id = vm:GetBlock(sx, sy, sz)
				if not ALL_SAPLINGS[id] then
				self._saplings[k] = nil
				self._iterDirty = true
			else
				-- Process only if chunk has any viewer (active)
				local cx = math.floor(sx / Constants.CHUNK_SIZE_X)
				local cz = math.floor(sz / Constants.CHUNK_SIZE_Z)
				local vw = self.Deps and self.Deps.VoxelWorldService
				local key = string.format("%d,%d", cx, cz)
				local hasViewer = vw and vw.chunkViewers and vw.chunkViewers[key] ~= nil
				if hasViewer then
					self:_processSapling(vm, sx, sy, sz)
					processed += 1
				end
			end

			-- advance cursor
			self._iterCursor = self._iterCursor + 1
			if self._iterCursor > #keys then
				self._iterCursor = 1
			end
			tries += 1
		end
	end

	-- Sapling tick only handles saplings; leaf decay handled by separate cadence
end

-- Random-tick leaves per active chunk
function SaplingService:_randomTickLeaves()
    local vws = self.Deps and self.Deps.VoxelWorldService
    local vm = vws and vws.worldManager
    if not vws or not vm then return end

    local viewers = vws.chunkViewers or {}
    local chunkKeys = {}
    for key in pairs(viewers) do
        chunkKeys[#chunkKeys + 1] = key
    end
    if #chunkKeys == 0 then return end

    local rng = Random.new()
    local maxChunks = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.MAX_CHUNKS_PER_TICK) or 16
    local samplesPer = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RANDOM_TICKS_PER_CHUNK) or 8
    local saplingChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SAPLING_DROP_CHANCE) or 0.05
    local appleChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.APPLE_DROP_CHANCE) or 0.005

    -- Shuffle a subset of chunk keys to spread work
    for i = #chunkKeys, 2, -1 do
        local j = rng:NextInteger(1, i)
        chunkKeys[i], chunkKeys[j] = chunkKeys[j], chunkKeys[i]
    end

    local processed = 0
    for idx = 1, math.min(maxChunks, #chunkKeys) do
        local key = chunkKeys[idx]
        local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
        cx, cz = tonumber(cx) or 0, tonumber(cz) or 0
        local baseX = cx * Constants.CHUNK_SIZE_X
        local baseZ = cz * Constants.CHUNK_SIZE_Z

        local chunk = vws.worldManager and vws.worldManager:GetChunk(cx, cz)
        for s = 1, samplesPer do
            local lx = rng:NextInteger(0, Constants.CHUNK_SIZE_X - 1)
            local lz = rng:NextInteger(0, Constants.CHUNK_SIZE_Z - 1)
            local x = baseX + lx
            local z = baseZ + lz
            local yTop = nil
            if chunk and chunk.heightMap then
                local idx = lx + lz * Constants.CHUNK_SIZE_X
                yTop = chunk.heightMap[idx]
            end
            local yMin = 0
            local yMax = Constants.WORLD_HEIGHT - 1
            if yTop and type(yTop) == "number" then
                yMin = math.max(0, yTop - 12)
                yMax = math.min(Constants.WORLD_HEIGHT - 1, yTop + 2)
            end
            local y = rng:NextInteger(yMin, yMax)
            local id = vm:GetBlock(x, y, z)
            if self:_isLeaf(id) then
                local meta = vm:GetBlockMetadata(x, y, z) or 0
                local distance = getLeafDistance(meta) or 7
                local persistent = bit32.band(meta, 0x8) ~= 0
				if not persistent and distance >= 7 then
					-- Recompute distances before decaying to account for newly loaded neighbor logs/chunks
					SaplingService._recomputeLeafDistances(self, vm, x, y, z, (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6)
					meta = vm:GetBlockMetadata(x, y, z) or 0
					distance = getLeafDistance(meta) or 7
                    if distance >= 7 then
                        -- Compute drop BEFORE removing the leaf (metadata and id will be cleared on SetBlock)
                        local dropId
                        local dropSvc = vws.Deps and vws.Deps.DroppedItemService
                        if dropSvc and (math.random() < saplingChance) then
                            dropId = self:_pickSaplingDropForLeaf(vm, x, y, z, id, meta)
                        end
                        vws:SetBlock(x, y, z, BLOCK.AIR)
                        if dropSvc and dropId then
                            dropSvc:SpawnItem(dropId, 1, Vector3.new(x, y, z), nil, true)
                        end
                        -- Only oak leaves drop apples (no generic fallback)
                        if dropSvc and (id == BLOCK.OAK_LEAVES) and (math.random() < appleChance) then
                            dropSvc:SpawnItem(BLOCK.APPLE, 1, Vector3.new(x, y, z), nil, true)
                        end
                    end
				end
            end
        end

        processed += 1
        if processed >= maxChunks then break end
    end

end

-- Leaf decay tick: process scheduled unsupported leaves and random ticks
function SaplingService:_leafTick()
	self:_processUnsupportedLeaves()
	self:_randomTickLeaves()
end

-- Proactively enqueue leaves within a radius cube around a position
-- (removed _scheduleLeafCluster; using random ticks instead)

-- Recompute leaf distances (BFS) within radius cube centered at (cx,cy,cz)

function SaplingService:_recomputeLeafDistances(vm, cx, cy, cz, radius)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local minX, maxX = cx - radius, cx + radius
	local minY, maxY = math.max(0, cy - radius), math.min(Constants.WORLD_HEIGHT - 1, cy + radius)
	local minZ, maxZ = cz - radius, cz + radius

	-- Initialize leaves in region to distance 7
	for x = minX, maxX do
		for y = minY, maxY do
			for z = minZ, maxZ do
				if self:_isLeaf(vm:GetBlock(x, y, z)) then
					local meta = vm:GetBlockMetadata(x, y, z) or 0
					vm:SetBlockMetadata(x, y, z, setLeafDistance(meta, 7))
				end
			end
		end
	end

	-- Seed queue with logs (distance 0), carrying species leaf target per seed
	local q = {}
	local qi = 1
	local function push(nx, ny, nz, d, leafTarget)
		q[#q + 1] = {nx, ny, nz, d, leafTarget}
	end
	for x = minX, maxX do
		for y = minY, maxY do
			for z = minZ, maxZ do
				local id = vm:GetBlock(x, y, z)
				if LOG_ANCHORS[id] then
					local leafTarget = LOG_TO_LEAVES[id] or BLOCK.OAK_LEAVES or BLOCK.LEAVES
					push(x, y, z, 0, leafTarget)
				end
			end
		end
	end

	-- 6-neighbor BFS up to distance 6 through leaves
	while qi <= #q do
		local node = q[qi]
		qi = qi + 1
		local x, y, z, d = node[1], node[2], node[3], node[4]
		local leafTarget = node[5]
		if d < 6 then
			local nextD = d + 1
			for i = 1, #NEIGHBOR_OFFSETS_6 do
				local off = NEIGHBOR_OFFSETS_6[i]
				local nx, ny, nz = x + off[1], y + off[2], z + off[3]
				if ny >= minY and ny <= maxY and nx >= minX and nx <= maxX and nz >= minZ and nz <= maxZ then
					local nid = vm:GetBlock(nx, ny, nz)
					if nid == leafTarget or nid == BLOCK.LEAVES then
						-- Upgrade legacy generic leaves to the species near this log
						if nid == BLOCK.LEAVES then
							local oldMeta = vm:GetBlockMetadata(nx, ny, nz) or 0
							local wasPersistent = bit32.band(oldMeta, 0x8) ~= 0
							if vws and vws.SetBlock then
								vws:SetBlock(nx, ny, nz, leafTarget)
							else
								if vm and vm.SetBlock then vm:SetBlock(nx, ny, nz, leafTarget) end
							end
							-- Preserve persistent bit if it was set
							if wasPersistent then
								local curMeta = vm:GetBlockMetadata(nx, ny, nz) or 0
								vm:SetBlockMetadata(nx, ny, nz, bit32.bor(curMeta, 0x8))
							end
							-- Also stamp species code in metadata for future inference
							local curMeta2 = vm:GetBlockMetadata(nx, ny, nz) or 0
							local speciesCode = LEAF_TO_SPECIES_CODE[leafTarget]
							if speciesCode then
								vm:SetBlockMetadata(nx, ny, nz, setLeafSpecies(curMeta2, speciesCode))
							end
						end
						local meta = vm:GetBlockMetadata(nx, ny, nz) or 0
						local cur = getLeafDistance(meta)
						if nextD < cur then
							vm:SetBlockMetadata(nx, ny, nz, setLeafDistance(meta, nextD))
							push(nx, ny, nz, nextD, leafTarget)
						end
					end
				end
			end
		end
	end

    -- Enqueue remaining unsupported leaves in region for deterministic processing
    local regionMinX, regionMaxX = minX, maxX
    local regionMinY, regionMaxY = minY, maxY
    local regionMinZ, regionMaxZ = minZ, maxZ
    for x = regionMinX, regionMaxX do
        for y = regionMinY, regionMaxY do
            for z = regionMinZ, regionMaxZ do
                if self:_isLeaf(vm:GetBlock(x, y, z)) then
                    local meta = vm:GetBlockMetadata(x, y, z) or 0
                    local persistent = bit32.band(meta, 0x8) ~= 0
                    local distance = getLeafDistance(meta) or 7
                    if (not persistent) and distance >= 7 then
                        self:_scheduleUnsupported(x, y, z)
                    end
                end
            end
        end
    end

end

-- (removed _hasWoodWithin; using leaf distance instead)

function SaplingService:_processSapling(vm, x, y, z)
	-- Random attempt chance
	if math.random() > (SaplingConfig.ATTEMPT_CHANCE or (1/7)) then
		return
	end

	-- Optional sky visibility requirement (cap to local canopy height for efficiency)
	if SaplingConfig.REQUIRE_SKY_VISIBLE then
		local topY = math.min(Constants.WORLD_HEIGHT - 1, y + 7)
		for ay = y + 1, topY do
			local above = vm:GetBlock(x, ay, z)
			-- Ignore all leaves when checking for obstruction
			if above ~= BLOCK.AIR and (not self:_isLeaf(above)) then
				return
			end
		end
	end

	-- Stage handling using metadata bit 0
	local meta = vm:GetBlockMetadata(x, y, z) or 0
	local stage = getStageFromMeta(meta)
	if stage == 0 then
		-- Advance to stage 1
		local newMeta = setStageInMeta(meta, 1)
		vm:SetBlockMetadata(x, y, z, newMeta)
		stage = 1 -- Continue to attempt growth in same tick for responsiveness
	end

	-- Stage 1: try to grow
	local saplingId = vm:GetBlock(x, y, z)
	local logId = SAPLING_TO_LOG[saplingId] or BLOCK.WOOD
	if not self:_canPlaceOakAt(vm, x, y + 1, z) then
		return
	end

	self:_placeTreeAt(vm, x, y + 1, z, logId)
end

-- Called when a chunk is streamed to any player; scans once and applies offline fast-forward
function SaplingService:OnChunkStreamed(cx, cz)
	local k = string.format("%d,%d", cx, cz)
	if self._scannedChunks[k] then return end
	self._scannedChunks[k] = true

	local vm = self.Deps and self.Deps.VoxelWorldService and self.Deps.VoxelWorldService.worldManager
	if not vm then return end

	local baseX = cx * Constants.CHUNK_SIZE_X
	local baseZ = cz * Constants.CHUNK_SIZE_Z
	for lx = 0, Constants.CHUNK_SIZE_X - 1 do
		for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
			for y = 0, Constants.WORLD_HEIGHT - 1 do
				local x = baseX + lx
				local z = baseZ + lz
				local id = vm:GetBlock(x, y, z)
				if ALL_SAPLINGS[id] then
					local meta = vm:GetBlockMetadata(x, y, z) or 0
					self._saplings[keyFor(x, y, z)] = {x = x, y = y, z = z}
					self._iterDirty = true
					self:_fastForwardIfOffline(vm, x, y, z, meta)
                elseif self:_isLeaf(id) then
					-- Initialize leaf distance to 7 (unknown/not supported yet); batch recompute below will lower it
					local m = vm:GetBlockMetadata(x, y, z) or 0
					vm:SetBlockMetadata(x, y, z, setLeafDistance(m, 7))
				end
			end
		end
	end

	-- Record a species hint for this chunk based on any logs present
	local hint
	for lx = 0, Constants.CHUNK_SIZE_X - 1 do
		for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
			for y = 0, Constants.WORLD_HEIGHT - 1 do
				local x = baseX + lx
				local z = baseZ + lz
				local id = vm:GetBlock(x, y, z)
				if LOG_ANCHORS[id] then
					local leafId = LOG_TO_LEAVES[id]
					local code = leafId and LEAF_TO_SPECIES_CODE[leafId]
					if code ~= nil then hint = code break end
				end
			end
			if hint ~= nil then break end
		end
		if hint ~= nil then break end
	end
	if hint ~= nil then
		self._chunkSpecies[string.format("%d,%d", cx, cz)] = hint
	end

    -- Batch recompute distances for entire chunk footprint (plus border), crossing into neighbors
    local chunkCenterX = baseX + math.floor(Constants.CHUNK_SIZE_X / 2)
    local chunkCenterZ = baseZ + math.floor(Constants.CHUNK_SIZE_Z / 2)
    local chunkRadius = math.max(Constants.CHUNK_SIZE_X, Constants.CHUNK_SIZE_Z) / 2 + ((SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6)
    -- Estimate canopy Y from heightmap (average + 2), fallback to mid-world
    local centerY = math.floor(Constants.WORLD_HEIGHT / 2)
    local chunk = self.Deps and self.Deps.VoxelWorldService and self.Deps.VoxelWorldService.worldManager and self.Deps.VoxelWorldService.worldManager:GetChunk(cx, cz)
    if chunk and chunk.heightMap then
        local sum = 0
        local count = 0
        for lx = 0, Constants.CHUNK_SIZE_X - 1 do
            for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
                local idx = lx + lz * Constants.CHUNK_SIZE_X
                local h = chunk.heightMap[idx]
                if type(h) == "number" then
                    sum = sum + h
                    count = count + 1
                end
            end
        end
        if count > 0 then
            centerY = math.clamp(math.floor(sum / count) + 2, 0, Constants.WORLD_HEIGHT - 1)
        end
    end
	SaplingService._recomputeLeafDistances(self, vm, chunkCenterX, centerY, chunkCenterZ, chunkRadius)

    -- After recompute, enqueue all unsupported leaves in chunk region for deterministic processing
    local minX, maxX = baseX - 6, baseX + Constants.CHUNK_SIZE_X + 6
    local minZ, maxZ = baseZ - 6, baseZ + Constants.CHUNK_SIZE_Z + 6
    local minY, maxY = 0, Constants.WORLD_HEIGHT - 1
    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                if self:_isLeaf(vm:GetBlock(x, y, z)) then
                    local meta = vm:GetBlockMetadata(x, y, z) or 0
                    local persistent = bit32.band(meta, 0x8) ~= 0
                    local distance = getLeafDistance(meta) or 7
                    if (not persistent) and distance >= 7 then
                        self:_scheduleUnsupported(x, y, z)
                    end
                end
            end
        end
    end
end

function SaplingService:_fastForwardIfOffline(vm, x, y, z, meta)
	local ownerSvc = self.Deps and self.Deps.WorldOwnershipService
	if not ownerSvc then return end
	local wd = ownerSvc:GetWorldData()
	if not wd then return end

	local lastSaved = wd.lastSaved or wd.created or os.time()
	local elapsed = math.max(0, os.time() - lastSaved)
	if elapsed <= 0 then return end

	local rate = (SaplingConfig.ATTEMPT_CHANCE or (1/7)) / (SaplingConfig.TICK_INTERVAL or 5)
	local lambda = rate * elapsed

	-- Compute P(K=0), P(K=1) for Poisson(lambda)
	local p0 = math.exp(-lambda)
	local p1 = lambda * p0
	local u = Random.new(self:_seedFor(x, y, z)):NextNumber()
	local k
	if u < p0 then k = 0 elseif u < (p0 + p1) then k = 1 else k = 2 end

	local stage = getStageFromMeta(meta or 0)
	if stage == 0 and k >= 1 then
		vm:SetBlockMetadata(x, y, z, setStageInMeta(meta, 1))
		stage = 1
	end
	if stage == 1 and k >= 2 then
		if self:_canPlaceOakAt(vm, x, y + 1, z) then
			local saplingId = vm:GetBlock(x, y, z)
			local logId = SAPLING_TO_LOG[saplingId] or BLOCK.WOOD
			self:_placeTreeAt(vm, x, y + 1, z, logId)
		end
	end

    -- Optional burst decay of unsupported leaves (distance 7) for immediate feedback
	local vws = self.Deps and self.Deps.VoxelWorldService
	local dropSvc = vws and vws.Deps and vws.Deps.DroppedItemService
	local burstLimit = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.BURST_DECAY_LIMIT) or 0
	local saplingChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SAPLING_DROP_CHANCE) or 0.05
	local appleChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.APPLE_DROP_CHANCE) or 0.005
	local removed = 0
	if vws and burstLimit > 0 then
		-- Define a local region around the sapling and recompute distances first
		local radius = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6
		local minX, maxX = x - radius, x + radius
		local minZ, maxZ = z - radius, z + radius
		local minY, maxY = math.max(0, y - radius), math.min(Constants.WORLD_HEIGHT - 1, y + radius)
		SaplingService._recomputeLeafDistances(self, vm, x, y, z, radius)

		for x = minX, maxX do
			for y = minY, maxY do
				for z = minZ, maxZ do
					local leafId = vm:GetBlock(x, y, z)
					if self:_isLeaf(leafId) then
						local meta = vm:GetBlockMetadata(x, y, z) or 0
						local distance = getLeafDistance(meta) or 7
                        if distance >= 7 then
                            -- Compute drop BEFORE removing the leaf (metadata/id are cleared on SetBlock)
                            local dropId
                            if dropSvc and (math.random() < saplingChance) then
                                local metaBefore = vm:GetBlockMetadata(x, y, z) or 0
                                dropId = self:_pickSaplingDropForLeaf(vm, x, y, z, leafId, metaBefore)
                            end
                            vws:SetBlock(x, y, z, BLOCK.AIR)
                            if dropSvc and dropId then
                                dropSvc:SpawnItem(dropId, 1, Vector3.new(x, y, z), nil, true)
                            end
                            -- Only oak leaves drop apples (no generic fallback)
                            if dropSvc and (leafId == BLOCK.OAK_LEAVES) and (math.random() < appleChance) then
                                dropSvc:SpawnItem(BLOCK.APPLE, 1, Vector3.new(x, y, z), nil, true)
                            end

							removed += 1
							-- Track for deterministic processing removal
							self._unsupportedSet[keyFor(x, y, z)] = nil
							if removed >= burstLimit then return end
						end
					end
				end
            end
        end
    end
end


-- Deterministic processing of unsupported leaves (distance 7)
function SaplingService:_processUnsupportedLeaves()
    local vws = self.Deps and self.Deps.VoxelWorldService
    local vm = vws and vws.worldManager
    if not vws or not vm then return end

    local limit = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.PROCESS_PER_TICK) or 128
    if limit <= 0 then return end

    local saplingChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SAPLING_DROP_CHANCE) or 0.05
    local appleChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.APPLE_DROP_CHANCE) or 0.005
    local processed = 0
    local now = os.clock()

    for k, _ in pairs(self._unsupportedSet) do
        local x, y, z = parseKey(k)
        local id = vm:GetBlock(x, y, z)
                if self:_isLeaf(id) then
            local meta = vm:GetBlockMetadata(x, y, z) or 0
            local persistent = bit32.band(meta, 0x8) ~= 0
            local distance = getLeafDistance(meta) or 7
                    if (not persistent) and distance >= 7 then
                if not self._unsupportedSchedule[k] then
                    self:_scheduleUnsupported(x, y, z)
                end
                local due = self._unsupportedSchedule[k] or 0
				if now >= due then
					-- Recompute distances just-in-time to avoid false decays when neighbor logs just loaded
					local radius = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6
					SaplingService._recomputeLeafDistances(self, vm, x, y, z, radius)
					meta = vm:GetBlockMetadata(x, y, z) or 0
					persistent = bit32.band(meta, 0x8) ~= 0
					distance = getLeafDistance(meta) or 7
					if (not persistent) and distance >= 7 then
						-- Compute drop BEFORE removing the leaf (metadata/id are cleared on SetBlock)
						local dropSvc = vws.Deps and vws.Deps.DroppedItemService
						local dropId
						if dropSvc and (math.random() < saplingChance) then
							local metaBefore = vm:GetBlockMetadata(x, y, z) or 0
							dropId = self:_pickSaplingDropForLeaf(vm, x, y, z, id, metaBefore)
						end
						vws:SetBlock(x, y, z, BLOCK.AIR)
						if dropSvc and dropId then
							dropSvc:SpawnItem(dropId, 1, Vector3.new(x, y, z), nil, true)
						end
						if dropSvc and (id == BLOCK.OAK_LEAVES) and (math.random() < appleChance) then
							dropSvc:SpawnItem(BLOCK.APPLE, 1, Vector3.new(x, y, z), nil, true)
						end
						self._unsupportedSet[k] = nil
						self._unsupportedSchedule[k] = nil
						processed += 1
						if processed >= limit then break end
					else
						-- Leaf became supported; clear from queues without decaying
						self._unsupportedSet[k] = nil
						self._unsupportedSchedule[k] = nil
					end
				end
            else
                -- No longer unsupported; cleanup
                self._unsupportedSet[k] = nil
                self._unsupportedSchedule[k] = nil
            end
        else
            -- Block changed (air or other); cleanup
            self._unsupportedSet[k] = nil
            self._unsupportedSchedule[k] = nil
        end
    end

end

function SaplingService:_seedFor(x, y, z)
	local seedBase = (self.Deps and self.Deps.WorldOwnershipService and self.Deps.WorldOwnershipService:GetWorldSeed()) or 1
	local s = bit32.bxor(seedBase * 73856093, x * 19349663)
	s = bit32.bxor(s, z * 83492791)
	s = bit32.bxor(s, y * 2654435761)
	if s < 0 then s = -s end
	return s % 2147483647
end

function SaplingService:_isReplaceable(blockId)
	return SaplingConfig.REPLACEABLE_BLOCKS[blockId] == true
end

-- Choose sapling drop type for a decaying leaf near the nearest log, default to oak
function SaplingService:_pickSaplingDropForLeaf(vm, x, y, z)
    local radius = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6
    -- Prefer strict mapping for species leaf variants; generic LEAVES infers from nearby logs
    local leafId = vm:GetBlock(x, y, z)
    if leafId ~= BLOCK.LEAVES then
        local mapped = LEAVES_TO_SAPLING[leafId]
        if mapped then return mapped end
    end
    -- If legacy generic LEAVES, first try to infer from metadata/chunk hint, then nearby species leaves, then logs
    if leafId == BLOCK.LEAVES then
        -- 1) Try species encoded in metadata
        local meta = vm:GetBlockMetadata(x, y, z) or 0
        local code = getLeafSpecies(meta)
        if code and SPECIES_CODE_TO_SAPLING[code] then
            return SPECIES_CODE_TO_SAPLING[code]
        end
        -- 2) Try last known species for this chunk
        local cx = math.floor(x / Constants.CHUNK_SIZE_X)
        local cz = math.floor(z / Constants.CHUNK_SIZE_Z)
        local hint = self._chunkSpecies and self._chunkSpecies[string.format("%d,%d", cx, cz)]
        if hint and SPECIES_CODE_TO_SAPLING[hint] then
            return SPECIES_CODE_TO_SAPLING[hint]
        end
        -- 3) Try nearby species leaves
        for dy = -radius, radius do
            for dx = -radius, radius do
                for dz = -radius, radius do
                    local nid = vm:GetBlock(x + dx, y + dy, z + dz)
                    local mapped = LEAVES_TO_SAPLING[nid]
                    if mapped and nid ~= BLOCK.LEAVES then
                        return mapped
                    end
                end
            end
        end
    end
    for dy = -radius, radius do
		for dx = -radius, radius do
			for dz = -radius, radius do
				local id = vm:GetBlock(x + dx, y + dy, z + dz)
				if LOG_ANCHORS[id] then
					return LOG_TO_SAPLING[id] or BLOCK.OAK_SAPLING
				end
			end
		end
	end
    -- If we couldn't infer species (no hints/leaves/logs), return nil to drop nothing
    return nil
end

-- Check space for a small oak tree (5-block trunk, 5x5 canopy, top 3x3)
function SaplingService:_canPlaceOakAt(vm, x, y, z)
	-- Trunk space
	for dy = 0, 4 do
		local id = vm:GetBlock(x, y + dy, z)
		if not self:_isReplaceable(id) then
			return false
		end
	end

	-- Canopy layers relative to y (matches SkyblockGenerator:PlaceTree)
	local function can(dx, dy, dz)
		local id = vm:GetBlock(x + dx, y + dy, z + dz)
		return self:_isReplaceable(id)
	end

	-- Layer y+3: 5x5 minus corners, skip center (trunk)
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				if not (dx == 0 and dz == 0) then
					if not can(dx, 3, dz) then return false end
				end
			end
		end
	end

	-- Layer y+4: 5x5 minus corners, skip center
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				if not (dx == 0 and dz == 0) then
					if not can(dx, 4, dz) then return false end
				end
			end
		end
	end

	-- Layer y+5: 3x3
	for dx = -1, 1 do
		for dz = -1, 1 do
			if not can(dx, 5, dz) then return false end
		end
	end

	return true
end

function SaplingService:_placeOakAt(vm, x, y, z)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws then return end

	-- Replace sapling block (at y-1) with trunk base
	vws:SetBlock(x, y - 1, z, BLOCK.WOOD)

	-- Trunk (5 blocks)
	for dy = 0, 4 do
		vws:SetBlock(x, y + dy, z, BLOCK.WOOD)
	end

	local function place(dx, dy, dz, skipTrunk)
		if skipTrunk and dx == 0 and dz == 0 then return end
		local leafId = LOG_TO_LEAVES[BLOCK.WOOD] or BLOCK.LEAVES
		vws:SetBlock(x + dx, y + dy, z + dz, leafId)
		-- Stamp species bits for persistence
		local meta = vm:GetBlockMetadata(x + dx, y + dy, z + dz) or 0
		local code = LEAF_TO_SPECIES_CODE[leafId]
		if code then vm:SetBlockMetadata(x + dx, y + dy, z + dz, setLeafSpecies(meta, code)) end
	end

	-- Layer y+3: 5x5 minus corners, skip center
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				place(dx, 3, dz, true)
			end
		end
	end

	-- Layer y+4: 5x5 minus corners, skip center
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				place(dx, 4, dz, true)
			end
		end
	end

	-- Layer y+5: 3x3 (includes center)
	for dx = -1, 1 do
		for dz = -1, 1 do
			place(dx, 5, dz, false)
		end
	end

	-- Initialize leaf distances around the new tree to ensure decay metadata is valid
	local vm2 = vws and vws.worldManager
	if vm2 then
		SaplingService._recomputeLeafDistances(self, vm2, x, y + 3, z, (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6)
	end
end

-- Generic placement for small trees, using specified logId for trunk
function SaplingService:_placeTreeAt(vm, x, y, z, logId)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws then return end

	local trunkId = logId or BLOCK.WOOD

	-- Replace sapling block (at y-1) with trunk base
	vws:SetBlock(x, y - 1, z, trunkId)

	-- Trunk (5 blocks)
	for dy = 0, 4 do
		vws:SetBlock(x, y + dy, z, trunkId)
	end

	local function place(dx, dy, dz, skipTrunk)
		if skipTrunk and dx == 0 and dz == 0 then return end
		local saplingLeafId = LOG_TO_LEAVES[trunkId] or LOG_TO_LEAVES[BLOCK.WOOD] or BLOCK.LEAVES
		vws:SetBlock(x + dx, y + dy, z + dz, saplingLeafId)
		-- Stamp species bits for persistence
		local meta = vm:GetBlockMetadata(x + dx, y + dy, z + dz) or 0
		local code = LEAF_TO_SPECIES_CODE[saplingLeafId]
		if code then vm:SetBlockMetadata(x + dx, y + dy, z + dz, setLeafSpecies(meta, code)) end
	end

	-- Layer y+3: 5x5 minus corners, skip center
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				place(dx, 3, dz, true)
			end
		end
	end

	-- Layer y+4: 5x5 minus corners, skip center
	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				place(dx, 4, dz, true)
			end
		end
	end

	-- Layer y+5: 3x3 (includes center)
	for dx = -1, 1 do
		for dz = -1, 1 do
			place(dx, 5, dz, false)
		end
	end

	-- Initialize leaf distances around the new tree to ensure decay metadata is valid
	local vm2 = vws and vws.worldManager
	if vm2 then
		SaplingService._recomputeLeafDistances(self, vm2, x, y + 3, z, (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6)
	end
end

return SaplingService


