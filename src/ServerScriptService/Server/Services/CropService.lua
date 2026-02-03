--[[
	CropService
	Simple growth system for wheat, potatoes, carrots, and beetroots.
	Mirrors SaplingService style: tracks crop blocks and advances stages over time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local CropConfig = require(ReplicatedStorage.Configs.CropConfig)

local BLOCK = Constants.BlockType

local CropService = {}
CropService.__index = CropService
setmetatable(CropService, BaseService)

-- Mapping: stage block id -> next stage id (or nil if max)
local NEXT_STAGE = {
	[BLOCK.WHEAT_CROP_0] = BLOCK.WHEAT_CROP_1,
	[BLOCK.WHEAT_CROP_1] = BLOCK.WHEAT_CROP_2,
	[BLOCK.WHEAT_CROP_2] = BLOCK.WHEAT_CROP_3,
	[BLOCK.WHEAT_CROP_3] = BLOCK.WHEAT_CROP_4,
	[BLOCK.WHEAT_CROP_4] = BLOCK.WHEAT_CROP_5,
	[BLOCK.WHEAT_CROP_5] = BLOCK.WHEAT_CROP_6,
	[BLOCK.WHEAT_CROP_6] = BLOCK.WHEAT_CROP_7,

	[BLOCK.POTATO_CROP_0] = BLOCK.POTATO_CROP_1,
	[BLOCK.POTATO_CROP_1] = BLOCK.POTATO_CROP_2,
	[BLOCK.POTATO_CROP_2] = BLOCK.POTATO_CROP_3,

	[BLOCK.CARROT_CROP_0] = BLOCK.CARROT_CROP_1,
	[BLOCK.CARROT_CROP_1] = BLOCK.CARROT_CROP_2,
	[BLOCK.CARROT_CROP_2] = BLOCK.CARROT_CROP_3,

	[BLOCK.BEETROOT_CROP_0] = BLOCK.BEETROOT_CROP_1,
	[BLOCK.BEETROOT_CROP_1] = BLOCK.BEETROOT_CROP_2,
	[BLOCK.BEETROOT_CROP_2] = BLOCK.BEETROOT_CROP_3,
}

local function isCropBlock(id)
	return NEXT_STAGE[id] ~= nil or id == BLOCK.WHEAT_CROP_7 or id == BLOCK.POTATO_CROP_3 or id == BLOCK.CARROT_CROP_3 or id == BLOCK.BEETROOT_CROP_3
end

function CropService.new()
	local self = setmetatable(BaseService.new(), CropService)
	self.Name = "CropService"
	self._crops = {} -- key -> true
	self._iterKeys = {}
	self._iterDirty = true
	return self
end

function CropService:Init()
	if self._initialized then
		return
	end
	BaseService.Init(self)
end

function CropService:Start()
	if self._started then
		return
	end
	BaseService.Start(self)

	-- Periodic growth checks
	local interval = CropConfig.TICK_INTERVAL or 5
	local maxPerTick = CropConfig.MAX_PER_TICK or 64
	local chance = CropConfig.ATTEMPT_CHANCE or (1/20)

	local function ensureIter()
		if self._iterDirty then
			self._iterKeys = {}
			for k in pairs(self._crops) do table.insert(self._iterKeys, k) end
			self._iterDirty = false
		end
	end

	local cursor = 1
	local function tick()
		ensureIter()
		local processed = 0
		while processed < maxPerTick and cursor <= #self._iterKeys do
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
			local id = vm:GetBlock(x, y, z)
			if not isCropBlock(id) then
				-- Removed or changed
				self._crops[key] = nil
				self._iterDirty = true
				continue
			end
			local nextId = NEXT_STAGE[id]
			if nextId then
				-- Check if farmland below is wet for faster growth
				local farmlandBelow = vm:GetBlock(x, y - 1, z)
				local growthChance = chance
				if farmlandBelow == BLOCK.FARMLAND_WET then
					growthChance = chance * 2 -- Wet farmland = 2x growth speed
				end
				if math.random() < growthChance then
					vws:SetBlock(x, y, z, nextId)
				end
			end
		end
		if cursor > #self._iterKeys then
			cursor = 1
		end
	end

	-- Run loop
	task.spawn(function()
		while self._started do
			tick()
			task.wait(interval)
		end
	end)

end

function CropService:Destroy()
	if self._destroyed then
		return
	end
	self._crops = {}
	self._iterKeys = {}
	BaseService.Destroy(self)
end

local function keyOf(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

function CropService:OnBlockChanged(x, y, z, newBlockId, _newMetadata, oldBlockId)
	if isCropBlock(newBlockId) then
		local k = keyOf(x, y, z)
		if not self._crops[k] then
			self._crops[k] = true
			self._iterDirty = true
		end
	elseif isCropBlock(oldBlockId) and not isCropBlock(newBlockId) then
		local k = keyOf(x, y, z)
		if self._crops[k] then
			self._crops[k] = nil
			self._iterDirty = true
		end
	end
end

function CropService:OnChunkStreamed(cx, cz)
	local vws = self.Deps and self.Deps.VoxelWorldService
	local vm = vws and vws.worldManager
	if not vm then
		return
	end
	local minX = cx * Constants.CHUNK_SIZE_X
	local minZ = cz * Constants.CHUNK_SIZE_Z
	local maxX = minX + Constants.CHUNK_SIZE_X - 1
	local maxZ = minZ + Constants.CHUNK_SIZE_Z - 1
	for x = minX, maxX do
		for y = 0, Constants.WORLD_HEIGHT - 1 do
			for z = minZ, maxZ do
				local id = vm:GetBlock(x, y, z)
				if isCropBlock(id) then
					local k = keyOf(x, y, z)
					self._crops[k] = true
				end
			end
		end
	end
	self._iterDirty = true
end

--[[
	Instantly grow all tracked crops to their mature stage.
	Used by tutorial to skip waiting for crop growth.
]]
function CropService:InstantGrowAllCrops()
	local vws = self.Deps and self.Deps.VoxelWorldService
	local vm = vws and vws.worldManager
	if not vm then
		return 0
	end

	-- Mapping from any crop stage to its mature stage
	local MATURE_STAGE = {
		-- Wheat (stage 7 is mature)
		[BLOCK.WHEAT_CROP_0] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_1] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_2] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_3] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_4] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_5] = BLOCK.WHEAT_CROP_7,
		[BLOCK.WHEAT_CROP_6] = BLOCK.WHEAT_CROP_7,
		-- Potato (stage 3 is mature)
		[BLOCK.POTATO_CROP_0] = BLOCK.POTATO_CROP_3,
		[BLOCK.POTATO_CROP_1] = BLOCK.POTATO_CROP_3,
		[BLOCK.POTATO_CROP_2] = BLOCK.POTATO_CROP_3,
		-- Carrot (stage 3 is mature)
		[BLOCK.CARROT_CROP_0] = BLOCK.CARROT_CROP_3,
		[BLOCK.CARROT_CROP_1] = BLOCK.CARROT_CROP_3,
		[BLOCK.CARROT_CROP_2] = BLOCK.CARROT_CROP_3,
		-- Beetroot (stage 3 is mature)
		[BLOCK.BEETROOT_CROP_0] = BLOCK.BEETROOT_CROP_3,
		[BLOCK.BEETROOT_CROP_1] = BLOCK.BEETROOT_CROP_3,
		[BLOCK.BEETROOT_CROP_2] = BLOCK.BEETROOT_CROP_3,
	}

	local grownCount = 0
	for key in pairs(self._crops) do
		local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
		x = tonumber(x)
		y = tonumber(y)
		z = tonumber(z)
		if x and y and z then
			local id = vm:GetBlock(x, y, z)
			local matureId = MATURE_STAGE[id]
			if matureId then
				vws:SetBlock(x, y, z, matureId)
				grownCount = grownCount + 1
			end
		end
	end

	return grownCount
end

return CropService


