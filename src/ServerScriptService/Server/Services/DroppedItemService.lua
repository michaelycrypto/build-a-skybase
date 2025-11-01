--[[
	DroppedItemService.lua
	Server provides spawn position and initial velocity, clients use real Roblox physics
	Items collide with voxel world geometry naturally!
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local ItemConfig = require(ReplicatedStorage.Configs.ItemConfig)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

local DroppedItemService = setmetatable({}, BaseService)
DroppedItemService.__index = DroppedItemService

local BLOCK_SIZE = Constants.BLOCK_SIZE -- 3.5 studs
local LIFETIME = 300 -- 5 minutes
local MERGE_DISTANCE = BLOCK_SIZE -- Merge items within one block distance
local PICKUP_DISTANCE = 2
local PICKUP_COOLDOWN = 0 -- No cooldown on pickup
local PICKUP_DELAY = 0.5 -- 0.5s pickup delay like Minecraft (10 ticks)

local nextItemId = 1
-- Helper: determine if an itemId is a placeable block (numeric and not craftingMaterial)
local function _isBlockItemId(itemId)
    if typeof(itemId) == "number" then
        local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
        local raw = BlockRegistry.Blocks and BlockRegistry.Blocks[itemId]
        if raw ~= nil then
            return raw.craftingMaterial ~= true
        end
        return false
    end
    return false
end


-- Standardize and gate module-local prints through Logger at DEBUG level
local _logger = Logger:CreateContext("DroppedItemService")
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

function DroppedItemService.new()
	local self = setmetatable(BaseService.new(), DroppedItemService)

	self.Name = "DroppedItemService"
	self.items = {} -- {[id] = {id, itemId, count, position, spawnTime, beingPickedUp}}
	self.playerPickupCooldowns = {} -- {[playerId] = {[itemId] = lastPickupTime}}

	return self
end

function DroppedItemService:Init()
	if self._initialized then return end
	BaseService.Init(self)
	print("DroppedItemService: Initialized")
end

function DroppedItemService:Start()
	if self._started then return end
	BaseService.Start(self)

	-- Setup player sync
	Players.PlayerAdded:Connect(function(player)
		task.wait(2)
		self:SyncToPlayer(player)
	end)

	-- Cleanup cooldowns when players leave (prevent memory leak)
	Players.PlayerRemoving:Connect(function(player)
		self.playerPickupCooldowns[player.UserId] = nil
	end)

	-- Cleanup loop (check despawns and merges every second)
	task.spawn(function()
		while true do
			local interval = (GameConfig.PERF_DEBUG and GameConfig.PERF_DEBUG.DROPPED_ITEM_LOOP_INTERVAL) or 1
			task.wait(interval)
			local t0 = os.clock()
			self:CheckDespawns()
			if not (GameConfig.PERF_DEBUG and GameConfig.PERF_DEBUG.DISABLE_DROPPED_ITEM_MERGE) then
				self:CheckMerges()
			end
			local dtMs = (os.clock() - t0) * 1000
			if dtMs > 10 then
				warn(string.format("DroppedItemService loop took %.1f ms", dtMs))
			end
		end
	end)

	print("DroppedItemService: Started")
end

--[[
	Spawn a dropped item
]]
function DroppedItemService:SpawnItem(itemId, count, position, velocity, isBlockCoords)
	if not itemId or itemId == 0 or count <= 0 then return end

	local BS = BLOCK_SIZE

	-- Convert block coords to world
	local startPos = position
    if isBlockCoords then
        -- Spawn in center of block, higher up to prevent floor clipping
        startPos = Vector3.new(
            position.X * BS + BS/2,
            position.Y * BS + BS/2, -- Center of block to prevent tunneling
            position.Z * BS + BS/2
        )
    end

	-- Calculate initial velocity if not provided
	-- Ensure minimum upward velocity to prevent immediate floor clipping
    local initialVel = velocity or Vector3.new(
        math.random(-2, 2),
        math.random(2, 4), -- Minimum 2 studs/sec upward to prevent tunneling
        math.random(-2, 2)
    )

	-- Check if we should merge with nearby items
	local mergeTargetId = nil
	local mergeTargetPos = nil
	for id, item in pairs(self.items) do
		if item.itemId == itemId then
			local dist = (item.position - startPos).Magnitude
			if dist <= MERGE_DISTANCE and item.count + count <= 64 then
				-- Found merge target - will spawn visual item that merges
				mergeTargetId = id
				mergeTargetPos = item.position
				item.count = item.count + count
				break
			end
		end
	end

	if mergeTargetId then
		-- Spawn temporary visual item that will merge
		local tempId = nextItemId
		nextItemId = nextItemId + 1

		-- Notify clients to spawn visual item that merges into target
		EventManager:FireEventToAll("ItemSpawned", {
			id = tempId,
			itemId = itemId,
			count = count,
			startPos = {startPos.X, startPos.Y, startPos.Z},
			velocity = {initialVel.X, initialVel.Y, initialVel.Z},
			mergeIntoId = mergeTargetId,
			mergeIntoPos = {mergeTargetPos.X, mergeTargetPos.Y, mergeTargetPos.Z}
		})

		-- Update the target stack count
		EventManager:FireEventToAll("ItemUpdated", {
			id = mergeTargetId,
			count = self.items[mergeTargetId].count
		})

		return mergeTargetId
	end

	-- Create new item
	local id = nextItemId
	nextItemId = nextItemId + 1

    local item = {
		id = id,
		itemId = itemId,
		count = count,
		position = startPos,
		spawnTime = os.clock(),
        pickupAvailableAt = os.clock() + PICKUP_DELAY,
        beingPickedUp = false -- Anti-duplication flag
	}

	self.items[id] = item

	-- Notify all clients to spawn and simulate physics
	EventManager:FireEventToAll("ItemSpawned", {
		id = id,
		itemId = itemId,
		count = count,
		startPos = {startPos.X, startPos.Y, startPos.Z},
		velocity = {initialVel.X, initialVel.Y, initialVel.Z}
	})

    local blockInfo = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry):GetBlock(typeof(itemId) == "number" and itemId or nil)
    local itemName
    if _isBlockItemId(itemId) then
        itemName = blockInfo and blockInfo.name or tostring(itemId)
    else
        local def = ItemConfig and ItemConfig.GetItemDefinition and ItemConfig.GetItemDefinition(itemId)
        itemName = (def and def.name) or tostring(itemId)
    end
	print(string.format("📦 Item #%d spawned: %s at (%.1f, %.1f, %.1f)",
		id, itemName, startPos.X, startPos.Y, startPos.Z))

	return id
end

--[[
	Remove item
]]
function DroppedItemService:RemoveItem(id)
	if not self.items[id] then return end

	self.items[id] = nil
	EventManager:FireEventToAll("ItemRemoved", {id = id})
end

--[[
	Merge nearby items
]]
function DroppedItemService:CheckMerges()
	local itemList = {}
	for _, item in pairs(self.items) do
		table.insert(itemList, item)
	end

	for i = 1, #itemList do
		local a = itemList[i]
		if self.items[a.id] then
			for j = i + 1, #itemList do
				local b = itemList[j]
				if self.items[b.id] and a.itemId == b.itemId then
					local dist = (a.position - b.position).Magnitude
					if dist <= MERGE_DISTANCE and a.count + b.count <= 64 then
						a.count = a.count + b.count
						self:RemoveItem(b.id)

						EventManager:FireEventToAll("ItemUpdated", {
							id = a.id,
							count = a.count
						})
					end
				end
			end
		end
	end
end

--[[
	Despawn old items
]]
function DroppedItemService:CheckDespawns()
	local now = os.clock()

	for id, item in pairs(self.items) do
		if now - item.spawnTime > LIFETIME then
			self:RemoveItem(id)
		end
	end
end

--[[
	Sync all items to a joining player
]]
function DroppedItemService:SyncToPlayer(player)
	for _, item in pairs(self.items) do
		EventManager:FireEvent("ItemSpawned", player, {
			id = item.id,
			itemId = item.itemId,
			count = item.count,
			startPos = {item.position.X, item.position.Y, item.position.Z},
			velocity = {0, 0, 0}
		})
	end
end

--[[
	Handle pickup request
]]
function DroppedItemService:HandlePickupRequest(player, data)
	if not player or not data or not data.id then return end

	local itemId = data.id
	local item = self.items[itemId]

	-- Anti-duplication check #1: Item must exist
	if not item then return end

	-- Anti-duplication check #2: Item must not already be in the process of being picked up
	if item.beingPickedUp then return end

	-- Anti-duplication check #3: Cooldown check to prevent spam
	local playerId = player.UserId
	if not self.playerPickupCooldowns[playerId] then
		self.playerPickupCooldowns[playerId] = {}
	end

    local lastPickup = self.playerPickupCooldowns[playerId][itemId]
    local now = os.clock()
    -- No cooldown: always allow request

    -- Enforce pickup delay (server-authoritative)
    if now < (item.pickupAvailableAt or 0) then
        return
    end

    -- Mark item as being picked up immediately (prevents race conditions)
	item.beingPickedUp = true
	self.playerPickupCooldowns[playerId][itemId] = now

	-- Validate distance (use reported client item position if provided; fallback to stored spawn position)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		item.beingPickedUp = false -- Unlock if validation fails
		return
	end

	local posForCheck = item.position
	local reportedPos = nil
	if data.pos and type(data.pos) == "table" and #data.pos >= 3 then
		reportedPos = Vector3.new(tonumber(data.pos[1]) or 0, tonumber(data.pos[2]) or 0, tonumber(data.pos[3]) or 0)
		-- Basic sanity: only accept if within 100 studs of stored position to avoid teleports
		if (reportedPos - item.position).Magnitude <= 100 then
			posForCheck = reportedPos
			-- Also update server's tracked position so merges use a fresher location
			item.position = reportedPos
		end
	end

	-- Generous radius since physics is client-simulated
	local dist = (posForCheck - root.Position).Magnitude
	if dist > 15 then
		item.beingPickedUp = false -- Unlock if too far
		return
	end

	-- Add to inventory
	local inv = self.Deps and self.Deps.PlayerInventoryService
	if not inv then
		item.beingPickedUp = false -- Unlock if inventory service unavailable
		return
	end

	-- Attempt to add item to inventory (this also prevents duplication at inventory level)
	if inv:AddItem(player, item.itemId, item.count) then
		-- Success! Remove item from world (this also prevents any other pickup attempts)
		self:RemoveItem(itemId)

		EventManager:FireEvent("ItemPickedUp", player, {
			itemId = item.itemId,
			count = item.count
		})
	else
		-- Failed to add to inventory (full?), unlock the item
		item.beingPickedUp = false
	end
end

--[[
	Handle drop request
]]
function DroppedItemService:HandleDropRequest(player, data)
	if not player or not data or not data.itemId or not data.count then return end

	-- Validate count is positive
	if data.count <= 0 then return end

	local char = player.Character
	if not char then return end

	local head = char:FindFirstChild("Head")
	if not head then return end

	local inv = self.Deps and self.Deps.PlayerInventoryService
	if not inv then return end

	-- If dropping from cursor, items were already removed server-side when moved to cursor
	-- In that case, skip inventory removal and just spawn the item
	local fromCursor = data.fromCursor == true
	if not fromCursor then
		local removed = false

		-- If dropping from a specific hotbar slot, remove from that slot
		-- This ensures the correct slot is cleared visually on the client
		if data.slotIndex and data.slotIndex >= 1 and data.slotIndex <= 9 then
			removed = inv:RemoveItemFromHotbarSlot(player, data.slotIndex, data.count)
		else
			-- Otherwise, remove from any slot (for inventory drops)
			removed = inv:RemoveItem(player, data.itemId, data.count)
		end

		if not removed then
			-- Failed to remove (player doesn't have enough), don't spawn anything
			warn(string.format("Player %s tried to drop %d x itemId %d but doesn't have enough",
				player.Name, data.count, data.itemId))
			return
		end
	end

	-- Drop in front of player
	local dropPos = head.Position + head.CFrame.LookVector * 3
	local dropVel = head.CFrame.LookVector * 8 + Vector3.new(0, 4, 0)

	self:SpawnItem(data.itemId, data.count, dropPos, dropVel, false)
end

function DroppedItemService:Destroy()
	if self._destroyed then return end

	self.items = {}

	BaseService.Destroy(self)
	print("DroppedItemService: Destroyed")
end

return DroppedItemService
