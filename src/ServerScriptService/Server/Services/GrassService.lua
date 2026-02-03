--[[
	GrassService
	Handles grass spreading to adjacent dirt blocks (Minecraft-style).
	
	Mechanics:
	1. Grass spreads to dirt blocks within 3 blocks horizontally
	2. Target dirt must have air or transparent block above (light required)
	3. Spreading has a random chance per tick
	4. Grass dies (converts to dirt) if a solid block is placed above it
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local BLOCK = Constants.BlockType

-- Configuration
local TICK_INTERVAL = 5           -- Seconds between spread checks
local MAX_PER_TICK = 50           -- Max dirt blocks to process per tick
local SPREAD_CHANCE = 0.1         -- 10% chance per tick to spread
local SPREAD_RANGE = 3            -- Horizontal range for grass spreading
local VERTICAL_RANGE = 1          -- Vertical range for grass spreading (up/down)

local GrassService = {}
GrassService.__index = GrassService
setmetatable(GrassService, BaseService)

function GrassService.new()
	local self = setmetatable(BaseService.new(), GrassService)
	self.Name = "GrassService"
	self._dirtBlocks = {}    -- key -> true (tracks dirt blocks near grass)
	self._iterKeys = {}      -- Array for iteration
	self._iterDirty = true   -- Flag to rebuild iteration array
	return self
end

function GrassService:Init()
	if self._initialized then
		return
	end
	BaseService.Init(self)
end

function GrassService:Start()
	if self._started then
		return
	end
	BaseService.Start(self)
	
	-- Start the periodic spreading check loop
	local function ensureIter()
		if self._iterDirty then
			self._iterKeys = {}
			for k in pairs(self._dirtBlocks) do
				table.insert(self._iterKeys, k)
			end
			self._iterDirty = false
		end
	end
	
	local cursor = 1
	local function tick()
		ensureIter()
		local processed = 0
		
		while processed < MAX_PER_TICK and cursor <= #self._iterKeys do
			local key = self._iterKeys[cursor]
			cursor += 1
			processed += 1
			
			local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
			x = tonumber(x)
			y = tonumber(y)
			z = tonumber(z)
			
			local vws = self.Deps and self.Deps.VoxelWorldService
			local vm = vws and vws.worldManager
			if not (vm and x and y and z) then
				continue
			end
			
			local currentBlockId = vm:GetBlock(x, y, z)
			
			-- Check if still dirt
			if currentBlockId ~= BLOCK.DIRT then
				self._dirtBlocks[key] = nil
				self._iterDirty = true
				continue
			end
			
			-- Check if conditions are met for grass spreading
			if math.random() < SPREAD_CHANCE then
				local canSpread = self:_canGrassSpreadTo(vm, x, y, z)
				if canSpread then
					-- Convert dirt to grass
					self:_setBlockState(vws, x, y, z, BLOCK.GRASS, currentBlockId)
					self._dirtBlocks[key] = nil
					self._iterDirty = true
					
					-- Queue nearby dirt blocks for future spreading
					self:_queueNearbyDirt(vm, x, y, z)
				end
			end
		end
		
		-- Reset cursor when we've processed all
		if cursor > #self._iterKeys then
			cursor = 1
		end
	end
	
	-- Run the tick loop
	task.spawn(function()
		while self._started do
			tick()
			task.wait(TICK_INTERVAL)
		end
	end)
end

function GrassService:Destroy()
	if self._destroyed then
		return
	end
	self._dirtBlocks = {}
	self._iterKeys = {}
	BaseService.Destroy(self)
end

-- Helper: Create key from coordinates
local function keyOf(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

-- Helper: Check if block above allows light (air or transparent)
function GrassService:_hasLightAbove(worldManager, x, y, z)
	local blockAbove = worldManager:GetBlock(x, y + 1, z)
	if blockAbove == BLOCK.AIR then
		return true
	end
	
	local blockDef = BlockRegistry:GetBlock(blockAbove)
	if blockDef and blockDef.transparent then
		return true
	end
	
	return false
end

-- Helper: Check if grass is nearby (within SPREAD_RANGE)
function GrassService:_hasGrassNearby(worldManager, x, y, z)
	for dx = -SPREAD_RANGE, SPREAD_RANGE do
		for dz = -SPREAD_RANGE, SPREAD_RANGE do
			for dy = -VERTICAL_RANGE, VERTICAL_RANGE do
				if dx == 0 and dy == 0 and dz == 0 then
					continue
				end
				
				local blockId = worldManager:GetBlock(x + dx, y + dy, z + dz)
				if blockId == BLOCK.GRASS then
					return true
				end
			end
		end
	end
	return false
end

-- Helper: Check if grass can spread to this dirt block
function GrassService:_canGrassSpreadTo(worldManager, x, y, z)
	-- Must have light above
	if not self:_hasLightAbove(worldManager, x, y, z) then
		return false
	end
	
	-- Must have grass nearby
	if not self:_hasGrassNearby(worldManager, x, y, z) then
		return false
	end
	
	return true
end

-- Helper: Queue nearby dirt blocks for potential spreading
function GrassService:_queueNearbyDirt(worldManager, x, y, z)
	for dx = -SPREAD_RANGE, SPREAD_RANGE do
		for dz = -SPREAD_RANGE, SPREAD_RANGE do
			for dy = -VERTICAL_RANGE, VERTICAL_RANGE do
				if dx == 0 and dy == 0 and dz == 0 then
					continue
				end
				
				local nx, ny, nz = x + dx, y + dy, z + dz
				local blockId = worldManager:GetBlock(nx, ny, nz)
				
				if blockId == BLOCK.DIRT then
					local key = keyOf(nx, ny, nz)
					if not self._dirtBlocks[key] then
						self._dirtBlocks[key] = true
						self._iterDirty = true
					end
				end
			end
		end
	end
end

-- Helper: Set block state and broadcast
function GrassService:_setBlockState(vws, x, y, z, newBlockId, oldBlockId)
	vws.worldManager:SetBlock(x, y, z, newBlockId, 0)
	vws.modifiedChunks[Constants.ToChunkKey(
		math.floor(x / Constants.CHUNK_SIZE_X),
		math.floor(z / Constants.CHUNK_SIZE_Z)
	)] = true
	
	-- Broadcast the block change
	EventManager:FireEventToAll("BlockChanged", {
		x = x, y = y, z = z,
		blockId = newBlockId,
		metadata = 0
	})
end

--[[
	Called when a block changes in the world.
	Handles:
	1. Grass placement - queue nearby dirt for spreading
	2. Dirt placement - add to tracking if grass nearby
	3. Solid block placed above grass - convert grass to dirt
]]
function GrassService:OnBlockChanged(x, y, z, newBlockId, _newMetadata, oldBlockId)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local vm = vws and vws.worldManager
	if not vm then
		return
	end
	
	-- When grass is placed, queue nearby dirt for potential spreading
	if newBlockId == BLOCK.GRASS and oldBlockId ~= BLOCK.GRASS then
		self:_queueNearbyDirt(vm, x, y, z)
	end
	
	-- When dirt is placed, check if it should be tracked (grass nearby)
	if newBlockId == BLOCK.DIRT then
		if self:_hasGrassNearby(vm, x, y, z) then
			local key = keyOf(x, y, z)
			if not self._dirtBlocks[key] then
				self._dirtBlocks[key] = true
				self._iterDirty = true
			end
		end
	end
	
	-- When dirt is removed or converted, untrack it
	if oldBlockId == BLOCK.DIRT and newBlockId ~= BLOCK.DIRT then
		local key = keyOf(x, y, z)
		if self._dirtBlocks[key] then
			self._dirtBlocks[key] = nil
			self._iterDirty = true
		end
	end
	
	-- When a solid block is placed above grass, convert grass to dirt
	if oldBlockId == BLOCK.AIR and newBlockId ~= BLOCK.AIR then
		local blockDef = BlockRegistry:GetBlock(newBlockId)
		if blockDef and blockDef.solid then
			-- Check block below
			local blockBelowId = vm:GetBlock(x, y - 1, z)
			if blockBelowId == BLOCK.GRASS then
				-- Convert grass to dirt
				self:_setBlockState(vws, x, y - 1, z, BLOCK.DIRT, blockBelowId)
				-- Queue the new dirt for potential future spreading
				local key = keyOf(x, y - 1, z)
				self._dirtBlocks[key] = true
				self._iterDirty = true
			end
		end
	end
	
	-- When a solid block is removed from above grass, the grass is now valid
	-- (no action needed - grass stays grass)
	
	-- When a solid block is removed, check if there's dirt below that could now spread
	if newBlockId == BLOCK.AIR and oldBlockId ~= BLOCK.AIR then
		local blockDef = BlockRegistry:GetBlock(oldBlockId)
		if blockDef and blockDef.solid then
			-- Check block below - if it's dirt, it might now be able to spread
			local blockBelowId = vm:GetBlock(x, y - 1, z)
			if blockBelowId == BLOCK.DIRT then
				local key = keyOf(x, y - 1, z)
				if not self._dirtBlocks[key] then
					self._dirtBlocks[key] = true
					self._iterDirty = true
				end
			end
		end
	end
end

return GrassService
