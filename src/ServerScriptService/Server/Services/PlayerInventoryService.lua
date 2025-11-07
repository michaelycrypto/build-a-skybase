--[[
	PlayerInventoryService.lua
	Server-side inventory management with authority
	Tracks all player inventories, validates operations, prevents cheating
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local InventoryValidator = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.InventoryValidator)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local PlayerInventoryService = setmetatable({}, BaseService)
PlayerInventoryService.__index = PlayerInventoryService

function PlayerInventoryService.new()
	local self = setmetatable(BaseService.new(), PlayerInventoryService)

	self._logger = Logger:CreateContext("PlayerInventoryService")
	self.inventories = {} -- {[player] = {hotbar = {}, inventory = {}}}
	self.craftCredits = {} -- {[player] = {[itemId] = creditCount}}

	-- Granular sync optimization: track modified slots
	self.pendingSyncs = {} -- {[player] = {hotbar = {[slot] = true}, inventory = {[slot] = true}}}
	self.syncScheduled = {} -- {[player] = true/false}

	return self
end

function PlayerInventoryService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing PlayerInventoryService...")

	BaseService.Init(self)
	self._logger.Info("PlayerInventoryService initialized")
end

function PlayerInventoryService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)
	self._logger.Debug("PlayerInventoryService started")
end

-- Add craft credit for a player and item (used for toCursor crafts)
function PlayerInventoryService:AddCraftCredit(player: Player, itemId: number, amount: number)
	if amount <= 0 then return end
	self.craftCredits[player] = self.craftCredits[player] or {}
	self.craftCredits[player][itemId] = (self.craftCredits[player][itemId] or 0) + amount
	self._logger.Debug("Added craft credit", {player = player.Name, itemId = itemId, amount = amount, total = self.craftCredits[player][itemId]})
end

function PlayerInventoryService:OnPlayerAdded(player: Player)
	-- Don't initialize if already exists (prevent duplicate initialization)
	if self.inventories[player] then
		self._logger.Warn("Inventory already exists, skipping", {player = player.Name})
		return
	end

	self._logger.Debug("Initializing new inventory", {player = player.Name})

	-- Initialize player inventory - starting with empty inventory
	local hotbar = {}
	local inventory = {}

	-- Empty hotbar (9 slots)
	for i = 1, 9 do
		hotbar[i] = ItemStack.new(0, 0)
	end

	-- Empty inventory (27 slots)
	for i = 1, 27 do
		inventory[i] = ItemStack.new(0, 0)
	end

	-- Starter building resources: fill hotbar with common blocks and wood families
	local B = Constants.BlockType
	local function setHot(slot, id, count)
		if slot >= 1 and slot <= 9 then
			hotbar[slot] = ItemStack.new(id, count)
		end
	end
	setHot(1, B.OAK_PLANKS, 64)
	setHot(2, B.SPRUCE_PLANKS, 64)
	setHot(3, B.JUNGLE_PLANKS, 64)
	setHot(4, B.DARK_OAK_PLANKS, 64)
	setHot(5, B.BIRCH_PLANKS, 64)
	setHot(6, B.ACACIA_PLANKS, 64)
	setHot(7, B.COBBLESTONE, 64)
	setHot(8, B.STONE_BRICKS, 64)
	setHot(9, B.BRICKS, 64)

	-- Fill inventory with additional resource stacks (27 slots)
	local invIndex = 1
	local function pushInv(id, count)
		if invIndex <= 27 then
			inventory[invIndex] = ItemStack.new(id, count)
			invIndex += 1
		end
	end
	-- Core resources
	pushInv(B.STONE, 64)
	pushInv(B.DIRT, 64)
	pushInv(B.GRASS, 64)
	pushInv(B.SAND, 64)
	pushInv(B.GLASS, 64)
	-- Logs for each family
	pushInv(B.WOOD, 64) -- Oak logs
	pushInv(B.SPRUCE_LOG, 64)
	pushInv(B.JUNGLE_LOG, 64)
	pushInv(B.DARK_OAK_LOG, 64)
	pushInv(B.BIRCH_LOG, 64)
	pushInv(B.ACACIA_LOG, 64)
	-- Extra planks
	pushInv(B.OAK_PLANKS, 64)
	pushInv(B.SPRUCE_PLANKS, 64)
	pushInv(B.JUNGLE_PLANKS, 64)
	pushInv(B.DARK_OAK_PLANKS, 64)
	pushInv(B.BIRCH_PLANKS, 64)
	pushInv(B.ACACIA_PLANKS, 64)
	-- Stone variants
	pushInv(B.COBBLESTONE, 64)
	pushInv(B.STONE_BRICKS, 64)
	pushInv(B.BRICKS, 64)

	-- Diamond tools (non-stackable)
	pushInv(1004, 1) -- Diamond Pickaxe
	pushInv(1014, 1) -- Diamond Axe
	pushInv(1024, 1) -- Diamond Shovel
	pushInv(1044, 1) -- Diamond Sword

	self.inventories[player] = {
		hotbar = hotbar,
		inventory = inventory
	}

	-- Debug: Log what we created
	self._logger.Debug("Created empty starter inventory", {player = player.Name})

	-- Send initial inventory to client
	self:SyncInventoryToClient(player)

	self._logger.Debug("Initialized empty inventory", {player = player.Name})
end

function PlayerInventoryService:OnPlayerRemoved(player: Player)
	-- Save inventory to DataStore before removing
	if self.Deps and self.Deps.PlayerDataStoreService then
		local inventoryData = self:SerializeInventory(player)
		if inventoryData then
			self.Deps.PlayerDataStoreService:SaveInventoryData(player, inventoryData)
		end
	end

	self.inventories[player] = nil
	self.pendingSyncs[player] = nil
	self.syncScheduled[player] = nil
	self.craftCredits[player] = nil
	self._logger.Debug("Removed inventory", {player = player.Name})
end

-- Check if player has at least one of an item in hotbar
function PlayerInventoryService:HasItem(player: Player, itemId: number): boolean
	local playerInv = self.inventories[player]
	if not playerInv then
		self._logger.Warn("No inventory found", {player = player.Name, itemId = itemId})
		return false
	end

	-- Check hotbar
	for i, stack in ipairs(playerInv.hotbar) do
		if stack:GetItemId() == itemId and stack:GetCount() > 0 then
			self._logger.Debug("Found item in hotbar", {
				player = player.Name,
				itemId = itemId,
				slot = i,
				count = stack:GetCount()
			})
			return true
		end
	end

	-- Check inventory
	for i, stack in ipairs(playerInv.inventory) do
		if stack:GetItemId() == itemId and stack:GetCount() > 0 then
			self._logger.Debug("Found item in inventory", {
				player = player.Name,
				itemId = itemId,
				slot = i,
				count = stack:GetCount()
			})
			return true
		end
	end

	self._logger.Warn("Player does not have item", {
		player = player.Name,
		itemId = itemId,
		hotbarSlots = #playerInv.hotbar,
		inventorySlots = #playerInv.inventory
	})
	return false
end

-- Get total count of an item across all slots
function PlayerInventoryService:GetItemCount(player: Player, itemId: number): number
	local playerInv = self.inventories[player]
	if not playerInv then return 0 end

	local total = 0

	for _, stack in ipairs(playerInv.hotbar) do
		if stack:GetItemId() == itemId then
			total = total + stack:GetCount()
		end
	end

	for _, stack in ipairs(playerInv.inventory) do
		if stack:GetItemId() == itemId then
			total = total + stack:GetCount()
		end
	end

	return total
end

-- Consume one item from hotbar slot (used for block placement)
function PlayerInventoryService:ConsumeFromHotbar(player: Player, slotIndex: number, itemId: number): boolean
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return false end

	local stack = playerInv.hotbar[slotIndex]

	-- Validate item matches
	if stack:GetItemId() ~= itemId then
		self._logger.Warn("Item mismatch in hotbar slot", {
			player = player.Name,
			expected = itemId,
			actual = stack:GetItemId(),
			slot = slotIndex
		})
		return false
	end

	-- Check has enough
	if stack:GetCount() < 1 then
		self._logger.Warn("Tried to consume from empty slot", {
			player = player.Name,
			slot = slotIndex
		})
		return false
	end

	-- Consume one
	stack:RemoveCount(1)

	-- Sync to client
	self:SyncHotbarSlotToClient(player, slotIndex)

	return true
end

-- Add item to inventory (finds best slot)
function PlayerInventoryService:AddItem(player: Player, itemId: number, count: number): boolean
	local playerInv = self.inventories[player]
	if not playerInv then return false end

	local remaining = count

	-- Tools are non-stackable: place one per empty slot; never merge counts > 1
	if ToolConfig.IsTool(itemId) then
		for i, stack in ipairs(playerInv.hotbar) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				stack.itemId = itemId
				stack:SetCount(1)
				remaining -= 1
				self:TrackSlotChange(player, "hotbar", i)
			end
		end
		for i, stack in ipairs(playerInv.inventory) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				stack.itemId = itemId
				stack:SetCount(1)
				remaining -= 1
				self:TrackSlotChange(player, "inventory", i)
			end
		end

		return remaining < count
	end

	-- Try to stack with existing items first
	for i, stack in ipairs(playerInv.hotbar) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local space = stack:GetRemainingSpace()
			local toAdd = math.min(space, remaining)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
			self:TrackSlotChange(player, "hotbar", i)
		end
	end

	for i, stack in ipairs(playerInv.inventory) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local space = stack:GetRemainingSpace()
			local toAdd = math.min(space, remaining)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
			self:TrackSlotChange(player, "inventory", i)
		end
	end

	-- Put in empty slots if any remaining
	if remaining > 0 then
		for i, stack in ipairs(playerInv.hotbar) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				local toAdd = math.min(64, remaining)
				stack.itemId = itemId
				stack:SetCount(toAdd)
				remaining = remaining - toAdd
				self:TrackSlotChange(player, "hotbar", i)
			end
		end

		for i, stack in ipairs(playerInv.inventory) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				local toAdd = math.min(64, remaining)
				stack.itemId = itemId
				stack:SetCount(toAdd)
				remaining = remaining - toAdd
				self:TrackSlotChange(player, "inventory", i)
			end
		end
	end

	-- Granular sync will be triggered automatically by TrackSlotChange
	return remaining < count
end

-- Remove item from inventory (removes from any slot)
function PlayerInventoryService:RemoveItem(player: Player, itemId: number, count: number): boolean
	local playerInv = self.inventories[player]
	if not playerInv then return false end

	-- First, check if player has enough of the item
	local totalCount = self:GetItemCount(player, itemId)
	if totalCount < count then
		return false -- Not enough items
	end

	local remaining = count

	-- Remove from hotbar first (track which slots changed)
	for i, stack in ipairs(playerInv.hotbar) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId then
			local toRemove = math.min(stack:GetCount(), remaining)
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
			-- Track this slot for granular sync
			self:TrackSlotChange(player, "hotbar", i)
		end
	end

	-- Remove from inventory if still needed (track which slots changed)
	for i, stack in ipairs(playerInv.inventory) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId then
			local toRemove = math.min(stack:GetCount(), remaining)
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
			-- Track this slot for granular sync
			self:TrackSlotChange(player, "inventory", i)
		end
	end

	-- Granular sync will be triggered automatically by TrackSlotChange
	-- (syncs only the modified slots, not the entire inventory)

	return remaining == 0
end

-- Remove item from a specific hotbar slot
function PlayerInventoryService:RemoveItemFromHotbarSlot(player: Player, slotIndex: number, count: number): boolean
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return false end

	local stack = playerInv.hotbar[slotIndex]
	if stack:IsEmpty() or stack:GetCount() < count then
		return false -- Not enough items in this slot
	end

	stack:RemoveCount(count)
	-- Track this slot for granular sync
	self:TrackSlotChange(player, "hotbar", slotIndex)

	return true
end

-- Update hotbar slot from client request (with validation)
function PlayerInventoryService:UpdateHotbarSlot(player: Player, slotIndex: number, itemStack: any)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return end

	-- TODO: Add anti-cheat validation here
	-- For now, trust client (creative mode style)

	local oldStack = playerInv.hotbar[slotIndex]
	local newStack = ItemStack.Deserialize(itemStack)

	-- Only track and sync if the slot actually changed
	if oldStack:GetItemId() ~= newStack:GetItemId() or oldStack:GetCount() ~= newStack:GetCount() then
		self._logger.Debug("Hotbar slot changed", {
			player = player.Name,
			slot = slotIndex,
			oldItem = oldStack:GetItemId(),
			oldCount = oldStack:GetCount(),
			newItem = newStack:GetItemId(),
			newCount = newStack:GetCount()
		})
		playerInv.hotbar[slotIndex] = newStack
		self:TrackSlotChange(player, "hotbar", slotIndex)
	end

	-- Broadcast to other players? (for now, no - inventory is private)
end

-- Update inventory slot from client request (with validation)
function PlayerInventoryService:UpdateInventorySlot(player: Player, slotIndex: number, itemStack: any)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 27 then return end

	-- TODO: Add anti-cheat validation

	local oldStack = playerInv.inventory[slotIndex]
	local newStack = ItemStack.Deserialize(itemStack)

	-- Only track and sync if the slot actually changed
	if oldStack:GetItemId() ~= newStack:GetItemId() or oldStack:GetCount() ~= newStack:GetCount() then
		self._logger.Debug("Inventory slot changed", {
			player = player.Name,
			slot = slotIndex,
			oldItem = oldStack:GetItemId(),
			oldCount = oldStack:GetCount(),
			newItem = newStack:GetItemId(),
			newCount = newStack:GetCount()
		})
		playerInv.inventory[slotIndex] = newStack
		self:TrackSlotChange(player, "inventory", slotIndex)
	end
end

-- Sync entire inventory to client
function PlayerInventoryService:SyncInventoryToClient(player: Player)
	local playerInv = self.inventories[player]
	if not playerInv then return end

	local hotbarData = {}
	for i, stack in ipairs(playerInv.hotbar) do
		hotbarData[i] = stack:Serialize()
	end

	local inventoryData = {}
	for i, stack in ipairs(playerInv.inventory) do
		inventoryData[i] = stack:Serialize()
	end

	EventManager:FireEvent("InventorySync", player, {
		hotbar = hotbarData,
		inventory = inventoryData
	})
end

-- Sync single hotbar slot to client
function PlayerInventoryService:SyncHotbarSlotToClient(player: Player, slotIndex: number)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return end

	EventManager:FireEvent("HotbarSlotUpdate", player, {
		slotIndex = slotIndex,
		stack = playerInv.hotbar[slotIndex]:Serialize()
	})
end

-- Sync single inventory slot to client (granular sync)
function PlayerInventoryService:SyncInventorySlotToClient(player: Player, slotIndex: number)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 27 then return end

	EventManager:FireEvent("InventorySlotUpdate", player, {
		slotIndex = slotIndex,
		stack = playerInv.inventory[slotIndex]:Serialize()
	})
end

-- Track slot change for batched sync
function PlayerInventoryService:TrackSlotChange(player: Player, slotType: string, slotIndex: number)
	if not self.pendingSyncs[player] then
		self.pendingSyncs[player] = {hotbar = {}, inventory = {}}
	end

	if slotType == "hotbar" and slotIndex >= 1 and slotIndex <= 9 then
		self.pendingSyncs[player].hotbar[slotIndex] = true
		self._logger.Debug("Tracked hotbar slot change", {
			player = player.Name,
			slot = slotIndex
		})
	elseif slotType == "inventory" and slotIndex >= 1 and slotIndex <= 27 then
		self.pendingSyncs[player].inventory[slotIndex] = true
		self._logger.Debug("Tracked inventory slot change", {
			player = player.Name,
			slot = slotIndex
		})
	end

	-- Schedule sync if not already scheduled
	if not self.syncScheduled[player] then
		self:ScheduleGranularSync(player)
	end
end

-- Schedule a batched sync of modified slots
function PlayerInventoryService:ScheduleGranularSync(player: Player)
	self.syncScheduled[player] = true

	-- Use RunService.Heartbeat for next-frame sync (batches changes within same frame)
	task.defer(function()
		if not self.syncScheduled[player] then return end

		self:ExecuteGranularSync(player)
		self.syncScheduled[player] = false
	end)
end

-- Execute sync of only modified slots
function PlayerInventoryService:ExecuteGranularSync(player: Player)
	local pending = self.pendingSyncs[player]
	if not pending then return end

	local playerInv = self.inventories[player]
	if not playerInv then return end

	local hotbarCount = 0
	local inventoryCount = 0

	-- Count modified slots
	for _ in pairs(pending.hotbar) do hotbarCount += 1 end
	for _ in pairs(pending.inventory) do inventoryCount += 1 end

	local totalModified = hotbarCount + inventoryCount

	-- If too many slots changed (>50% of inventory), do full sync instead
	if totalModified > 18 then
		self._logger.Debug("Many slots modified, using full sync", {
			player = player.Name,
			count = totalModified
		})
		self:SyncInventoryToClient(player)
	else
		-- Send individual slot updates (more efficient)
		for slot, _ in pairs(pending.hotbar) do
			self:SyncHotbarSlotToClient(player, slot)
		end

		for slot, _ in pairs(pending.inventory) do
			self:SyncInventorySlotToClient(player, slot)
		end

		self._logger.Debug("Granular sync completed", {
			player = player.Name,
			hotbarSlots = hotbarCount,
			inventorySlots = inventoryCount
		})
	end

	-- Clear pending syncs
	self.pendingSyncs[player] = {hotbar = {}, inventory = {}}
end

-- Handle inventory update from client (for drag-and-drop sync)
function PlayerInventoryService:HandleInventoryUpdate(player: Player, updateData: any)
	if not updateData then
		self._logger.Warn("Received nil updateData", {player = player.Name})
		return
	end

	local playerInv = self.inventories[player]
	if not playerInv then
		self._logger.Warn("No inventory found for update", {player = player.Name})
		return
	end

    -- SANITIZE: Clamp and correct minor issues (tools non-stackable, counts, ids)
    local newInventory = updateData.inventory
    local newHotbar = updateData.hotbar

    if newInventory then
        local sanitizedInv, modifiedInv = InventoryValidator:SanitizeInventoryData(newInventory, 27)
        if modifiedInv then
            self._logger.Debug("Sanitized incoming inventory array", {player = player.Name})
        end
        newInventory = sanitizedInv
    end

    if newHotbar then
        local sanitizedHot, modifiedHot = InventoryValidator:SanitizeInventoryData(newHotbar, 9)
        if modifiedHot then
            self._logger.Debug("Sanitized incoming hotbar array", {player = player.Name})
        end
        newHotbar = sanitizedHot
    end

	-- VALIDATION: Validate inventory array structure (post-sanitize)
    if newInventory then
        local valid, reason = InventoryValidator:ValidateInventoryArray(newInventory, 27)
        if not valid then
            self._logger.Warn("Invalid inventory array", {player = player.Name, reason = reason})
            -- Resync correct state to client
            self:SyncInventoryToClient(player)
            return
        end
    end

	-- VALIDATION: Validate hotbar array structure (post-sanitize)
    if newHotbar then
        local valid, reason = InventoryValidator:ValidateInventoryArray(newHotbar, 9)
        if not valid then
            self._logger.Warn("Invalid hotbar array", {player = player.Name, reason = reason})
            -- Resync correct state to client
            self:SyncInventoryToClient(player)
            return
        end
    end

	-- VALIDATION: Compare totals and allow increases only if covered by craft credits
	local function computeTotalsFromStacks(stacks)
		local totals = {}
		for _, stack in ipairs(stacks) do
			local itemId = stack:GetItemId()
			if itemId > 0 then
				totals[itemId] = (totals[itemId] or 0) + stack:GetCount()
			end
		end
		return totals
	end

	local oldTotals = {}
	oldTotals = computeTotalsFromStacks(playerInv.inventory)
	local oldHotTotals = computeTotalsFromStacks(playerInv.hotbar)
	for itemId, count in pairs(oldHotTotals) do
		oldTotals[itemId] = (oldTotals[itemId] or 0) + count
	end

    local newTotals = {}
    if newInventory then
        for i, stackData in pairs(newInventory) do
            local itemId = tonumber(stackData.itemId or stackData.id) or 0
            if itemId > 0 then
                newTotals[itemId] = (newTotals[itemId] or 0) + (tonumber(stackData.count) or 0)
            end
        end
    end
    if newHotbar then
        for i, stackData in pairs(newHotbar) do
            local itemId = tonumber(stackData.itemId or stackData.id) or 0
            if itemId > 0 then
                newTotals[itemId] = (newTotals[itemId] or 0) + (tonumber(stackData.count) or 0)
            end
        end
    end

	-- Ensure no net gains beyond credits
	self.craftCredits[player] = self.craftCredits[player] or {}
	for itemId, newCount in pairs(newTotals) do
		local oldCount = oldTotals[itemId] or 0
		if newCount > oldCount then
			local increase = newCount - oldCount
			local credit = self.craftCredits[player][itemId] or 0
			if increase > credit then
				self._logger.Warn("Transaction validation failed - uncredited item gain", {
					player = player.Name,
					itemId = itemId,
					increase = increase,
					credit = credit
				})
				self:SyncInventoryToClient(player)
				return
			end
		end
	end

	-- Validation passed - apply changes
    if newHotbar then
        for i, stackData in pairs(newHotbar) do
            -- Convert to number if needed
            local slotIndex = tonumber(i) or i
            -- Ensure numeric fields
            if type(stackData) == "table" then
                stackData.itemId = tonumber(stackData.itemId or stackData.id) or 0
                stackData.count = tonumber(stackData.count) or 0
            end
            self:UpdateHotbarSlot(player, slotIndex, stackData)
		end
	end

    if newInventory then
        for i, stackData in pairs(newInventory) do
            -- Convert to number if needed
            local slotIndex = tonumber(i) or i
            -- Ensure numeric fields
            if type(stackData) == "table" then
                stackData.itemId = tonumber(stackData.itemId or stackData.id) or 0
                stackData.count = tonumber(stackData.count) or 0
            end
            self:UpdateInventorySlot(player, slotIndex, stackData)
		end
	end

	-- Consume credits equal to any net increases that were accepted
	for itemId, newCount in pairs(newTotals) do
		local oldCount = oldTotals[itemId] or 0
		if newCount > oldCount then
			local increase = newCount - oldCount
			local credit = self.craftCredits[player][itemId] or 0
			local remaining = math.max(0, credit - increase)
			self.craftCredits[player][itemId] = remaining
		end
	end

	-- Clear pending syncs for this player - don't echo back changes they just sent
	if self.pendingSyncs[player] then
		self.pendingSyncs[player] = nil
	end
	if self.syncScheduled[player] then
		self.syncScheduled[player] = nil
	end

	self._logger.Debug("Validated and applied inventory update (no echo)", {player = player.Name})
end

-- Get hotbar slot for validation
function PlayerInventoryService:GetHotbarSlot(player: Player, slotIndex: number)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return nil end
	return playerInv.hotbar[slotIndex]
end

-- Serialize for DataStore saving
function PlayerInventoryService:SerializeInventory(player: Player)
	local playerInv = self.inventories[player]
	if not playerInv then return nil end

	local data = {
		hotbar = {},
		inventory = {}
	}

	for i, stack in ipairs(playerInv.hotbar) do
		data.hotbar[i] = stack:Serialize()
	end

	for i, stack in ipairs(playerInv.inventory) do
		data.inventory[i] = stack:Serialize()
	end

	return data
end

-- Deserialize from DataStore
function PlayerInventoryService:LoadInventory(player: Player, data: any)
	if not data then return end

	local playerInv = self.inventories[player]
	if not playerInv then return end

	if data.hotbar then
		for i, stackData in pairs(data.hotbar) do
			-- IMPORTANT: Convert slot index to number if it's a string (DataStore may serialize as strings)
			local slotIndex = tonumber(i) or i
			if type(slotIndex) == "number" and slotIndex >= 1 and slotIndex <= 9 then
				playerInv.hotbar[slotIndex] = ItemStack.Deserialize(stackData)
			else
				self._logger.Warn("Invalid hotbar slot index during load", {
					player = player.Name,
					index = tostring(i),
					converted = tostring(slotIndex)
				})
			end
		end
	end

	if data.inventory then
		for i, stackData in pairs(data.inventory) do
			-- IMPORTANT: Convert slot index to number if it's a string (DataStore may serialize as strings)
			local slotIndex = tonumber(i) or i
			if type(slotIndex) == "number" and slotIndex >= 1 and slotIndex <= 27 then
				playerInv.inventory[slotIndex] = ItemStack.Deserialize(stackData)
			else
				self._logger.Warn("Invalid inventory slot index during load", {
					player = player.Name,
					index = tostring(i),
					converted = tostring(slotIndex)
				})
			end
		end
	end

	self:SyncInventoryToClient(player)
	self._logger.Debug("Loaded inventory from DataStore", {player = player.Name})
end

function PlayerInventoryService:Destroy()
	if self._destroyed then
		return
	end

	-- Save all inventories before destroying
	for player, _ in pairs(self.inventories) do
		if player and player:IsDescendantOf(game:GetService("Players")) then
			self:OnPlayerRemoved(player)
		end
	end

	self.inventories = {}

	BaseService.Destroy(self)
	self._logger.Info("PlayerInventoryService destroyed")
end

return PlayerInventoryService

