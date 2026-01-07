--[[
	BaseWorldGenerator.lua
	Shared scaffolding for hub/player island generators.
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local Logger = require(game:GetService("ReplicatedStorage").Shared.Logger)
local IslandUtils = require(script.Parent.IslandUtils)

local BaseWorldGenerator = {}
BaseWorldGenerator.__index = BaseWorldGenerator

function BaseWorldGenerator.extend(classTable)
	classTable = classTable or {}
	classTable.__index = classTable
	return setmetatable(classTable, { __index = BaseWorldGenerator })
end

function BaseWorldGenerator._init(self, loggerLabel: string, seed: number?, overrides)
	overrides = overrides or {}

	self.seed = seed or 0
	self.rng = Random.new(self.seed)
	self._options = overrides
	self._chunkBounds = overrides.chunkBounds and IslandUtils.deepCopy(overrides.chunkBounds) or nil
	self._logger = Logger:CreateContext(loggerLabel)
	self._islands = {}
end

function BaseWorldGenerator:GetChunkBounds()
	return self._chunkBounds
end

function BaseWorldGenerator:IsChunkEmpty(chunkX: number, chunkZ: number): boolean
	local islands = self._islands
	if not islands or #islands == 0 then
		return true
	end

	local cs = Constants.CHUNK_SIZE_X
	local minX = chunkX * cs
	local maxX = minX + cs - 1
	local minZ = chunkZ * cs
	local maxZ = minZ + cs - 1

	local function distSqToRect(px, pz)
		local dx = 0
		if px < minX then
			dx = minX - px
		elseif px > maxX then
			dx = px - maxX
		end

		local dz = 0
		if pz < minZ then
			dz = minZ - pz
		elseif pz > maxZ then
			dz = pz - maxZ
		end

		return dx * dx + dz * dz
	end

	for _, island in ipairs(islands) do
		local buffer = island.topRadius + island.depth + 4
		if distSqToRect(island.centerX, island.centerZ) <= (buffer * buffer) then
			return false
		end
	end

	return true
end

function BaseWorldGenerator:_isInsideAnyIsland(wx: number, wy: number, wz: number)
	for _, island in ipairs(self._islands or {}) do
		local topY = island.topY
		local bottomY = topY - island.depth + 1
		if wy >= bottomY and wy <= topY then
			local dx = wx - island.centerX
			local dz = wz - island.centerZ
			local dist = math.sqrt(dx * dx + dz * dz)
			local depthFromTop = topY - wy
			local cleanRadius = IslandUtils.computeRadiusAtDepth(island.topRadius, depthFromTop, island.taper)
			local noisyRadius = IslandUtils.applyEdgeNoise(cleanRadius, wx, wz, island.noise)
			if dist <= noisyRadius then
				return true, island
			end
		end
	end

	return false, nil
end

function BaseWorldGenerator:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, wy, wz, blockId)
	if not blockId or blockId == Constants.BlockType.AIR then
		return
	end

	if wy < 0 or wy >= Constants.WORLD_HEIGHT then
		return
	end

	local lx = wx - chunkWorldX
	local lz = wz - chunkWorldZ
	if lx < 0 or lx >= Constants.CHUNK_SIZE_X or lz < 0 or lz >= Constants.CHUNK_SIZE_Z then
		return
	end

	chunk:SetBlock(lx, wy, lz, blockId)
	if chunk.heightMap then
		local idx = lx + lz * Constants.CHUNK_SIZE_X
		local current = chunk.heightMap[idx]
		if not current or wy > current then
			chunk.heightMap[idx] = wy
		end
	end
end

function BaseWorldGenerator:PostProcessChunk(_chunk, _chunkWorldX, _chunkWorldZ)
	-- Optional hook for derived generators.
end

function BaseWorldGenerator:GenerateChunk(chunk)
	local chunkWorldX = chunk.x * Constants.CHUNK_SIZE_X
	local chunkWorldZ = chunk.z * Constants.CHUNK_SIZE_Z

	for lx = 0, Constants.CHUNK_SIZE_X - 1 do
		for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
			local wx = chunkWorldX + lx
			local wz = chunkWorldZ + lz
			local highestY = 0

			for ly = 0, Constants.WORLD_HEIGHT - 1 do
				local wy = ly
				local blockType = self:GetBlockAt(wx, wy, wz)
				if blockType ~= Constants.BlockType.AIR then
					chunk:SetBlock(lx, ly, lz, blockType)
					highestY = ly
				end
			end

			local idx = lx + lz * Constants.CHUNK_SIZE_X
			chunk.heightMap[idx] = highestY
		end
	end

	self:PostProcessChunk(chunk, chunkWorldX, chunkWorldZ)
	chunk.state = Constants.ChunkState.READY
end

return BaseWorldGenerator

