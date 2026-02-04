--[[
	FarmlandService
	Manages farmland hydration state based on nearby water blocks.

	Farmland becomes "wet" (FARMLAND_WET) when water is within 4 blocks horizontally.
	When water is removed, farmland becomes "dry" (FARMLAND).

	This service:
	1. Tracks all farmland blocks in the world
	2. Updates hydration state when water is placed/removed nearby
	3. Periodically verifies hydration state (in case of missed updates)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local WaterUtils = require(ReplicatedStorage.Shared.VoxelWorld.World.WaterUtils)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local BLOCK = Constants.BlockType

-- Configuration
local TICK_INTERVAL = 5           -- Seconds between hydration checks
local MAX_PER_TICK = 50           -- Max farmland blocks to process per tick
local WATER_RANGE = 4             -- Blocks (horizontal) to check for water

local FarmlandService = {}
FarmlandService.__index = FarmlandService
setmetatable(FarmlandService, BaseService)

function FarmlandService.new()
	local self = setmetatable(BaseService.new(), FarmlandService)
	self.Name = "FarmlandService"
	self._farmland = {}    -- key -> true (tracks all farmland blocks)
	self._iterKeys = {}    -- Array for iteration
	self._iterDirty = true -- Flag to rebuild iteration array
	return self
end

function FarmlandService:Init()
	if self._initialized then
		return
	end
	BaseService.Init(self)
end

function FarmlandService:Start()
	if self._started then
		return
	end
	BaseService.Start(self)

	-- Start the periodic hydration check loop
	local function ensureIter()
		if self._iterDirty then
			self._iterKeys = {}
			for k in pairs(self._farmland) do
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

			-- Check if still farmland
			if not self:_isFarmland(currentBlockId) then
				self._farmland[key] = nil
				self._iterDirty = true
				continue
			end

			-- Check hydration and update if needed
			local shouldBeWet = self:_checkWaterNearby(vm, x, y, z)
			local isCurrentlyWet = currentBlockId == BLOCK.FARMLAND_WET

			if shouldBeWet and not isCurrentlyWet then
				-- Convert to wet
				self:_setFarmlandState(vws, x, y, z, BLOCK.FARMLAND_WET, currentBlockId)
			elseif not shouldBeWet and isCurrentlyWet then
				-- Convert to dry
				self:_setFarmlandState(vws, x, y, z, BLOCK.FARMLAND, currentBlockId)
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

function FarmlandService:Destroy()
	if self._destroyed then
		return
	end
	self._farmland = {}
	self._iterKeys = {}
	BaseService.Destroy(self)
end

-- Helper: Create key from coordinates
local function keyOf(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

-- Helper: Check if block is farmland
function FarmlandService:_isFarmland(blockId)
	return blockId == BLOCK.FARMLAND or blockId == BLOCK.FARMLAND_WET
end

-- Helper: Check if water is within range
function FarmlandService:_checkWaterNearby(worldManager, x, y, z)
	for dx = -WATER_RANGE, WATER_RANGE do
		for dz = -WATER_RANGE, WATER_RANGE do
			-- Check same Y level
			local blockId = worldManager:GetBlock(x + dx, y, z + dz)
			if WaterUtils.IsWater(blockId) then
				return true
			end
			-- Check one level below (Y-1)
			blockId = worldManager:GetBlock(x + dx, y - 1, z + dz)
			if WaterUtils.IsWater(blockId) then
				return true
			end
		end
	end
	return false
end

-- Helper: Set farmland state and broadcast
function FarmlandService:_setFarmlandState(vws, x, y, z, newBlockId, oldBlockId)
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
	1. Farmland placement - track and check initial hydration
	2. Water placement - update nearby farmland to wet
	3. Water removal - update nearby farmland to dry
	4. Farmland removal - stop tracking
]]
function FarmlandService:OnBlockChanged(x, y, z, newBlockId, _newMetadata, oldBlockId)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local vm = vws and vws.worldManager
	if not vm then
		return
	end

	-- Track new farmland blocks
	if self:_isFarmland(newBlockId) then
		local key = keyOf(x, y, z)
		if not self._farmland[key] then
			self._farmland[key] = true
			self._iterDirty = true
		end
	end

	-- Untrack removed farmland
	if self:_isFarmland(oldBlockId) and not self:_isFarmland(newBlockId) then
		local key = keyOf(x, y, z)
		if self._farmland[key] then
			self._farmland[key] = nil
			self._iterDirty = true
		end
	end

	-- When water is placed, check nearby farmland and hydrate it
	if WaterUtils.IsWater(newBlockId) and not WaterUtils.IsWater(oldBlockId) then
		self:_updateNearbyFarmland(vm, vws, x, y, z, true)
	end

	-- When water is removed, check nearby farmland and potentially dry it
	if WaterUtils.IsWater(oldBlockId) and not WaterUtils.IsWater(newBlockId) then
		self:_updateNearbyFarmland(vm, vws, x, y, z, false)
	end
end

--[[
	Update farmland blocks near a water source change.
	@param worldManager - The world manager
	@param vws - VoxelWorldService
	@param wx, wy, wz - Water position
	@param waterAdded - true if water was added, false if removed
]]
function FarmlandService:_updateNearbyFarmland(worldManager, vws, wx, wy, wz, waterAdded)
	-- Check farmland within range of the water position
	-- Water can affect farmland at same Y level or one above
	for dx = -WATER_RANGE, WATER_RANGE do
		for dz = -WATER_RANGE, WATER_RANGE do
			for dy = 0, 1 do  -- Check same level and one above
				local fx, fy, fz = wx + dx, wy + dy, wz + dz
				local blockId = worldManager:GetBlock(fx, fy, fz)

				if self:_isFarmland(blockId) then
					if waterAdded then
						-- Water added - farmland should become wet
						if blockId == BLOCK.FARMLAND then
							self:_setFarmlandState(vws, fx, fy, fz, BLOCK.FARMLAND_WET, blockId)
						end
					else
						-- Water removed - check if still has water nearby
						local stillHydrated = self:_checkWaterNearby(worldManager, fx, fy, fz)
						if not stillHydrated and blockId == BLOCK.FARMLAND_WET then
							self:_setFarmlandState(vws, fx, fy, fz, BLOCK.FARMLAND, blockId)
						end
					end
				end
			end
		end
	end
end

--[[
	Check if farmland at given position should be hydrated.
	Used by VoxelWorldService when creating farmland.
	@param worldManager - The world manager
	@param x, y, z - Farmland position
	@return boolean - true if water is within range
]]
function FarmlandService:IsFarmlandHydrated(worldManager, x, y, z)
	return self:_checkWaterNearby(worldManager, x, y, z)
end

return FarmlandService
