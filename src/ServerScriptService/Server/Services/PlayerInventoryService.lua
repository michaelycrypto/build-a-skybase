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
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local InventoryValidator = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.InventoryValidator)

local PlayerInventoryService = setmetatable({}, BaseService)
PlayerInventoryService.__index = PlayerInventoryService

function PlayerInventoryService.new()
	local self = setmetatable(BaseService.new(), PlayerInventoryService)

	self._logger = Logger:CreateContext("PlayerInventoryService")
	self.inventories = {} -- {[player] = {hotbar = {}, inventory = {}}}

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
	self._logger.Info("PlayerInventoryService started")
end

function PlayerInventoryService:OnPlayerAdded(player: Player)
	-- Don't initialize if already exists (prevent duplicate initialization)
	if self.inventories[player] then
		self._logger.Warn("Inventory already exists, skipping", {player = player.Name})
		return
	end

	self._logger.Info("Initializing new inventory", {player = player.Name})

	-- Initialize player inventory with starter blocks
	local hotbar = {}
	local inventory = {}

	-- Hotbar starter blocks (same as client defaults)
	hotbar[1] = ItemStack.new(1, 64)  -- Grass
	hotbar[2] = ItemStack.new(2, 64)  -- Dirt
	hotbar[3] = ItemStack.new(3, 64)  -- Stone
	hotbar[4] = ItemStack.new(5, 64)  -- Oak Log
	hotbar[5] = ItemStack.new(6, 64)  -- Leaves
	hotbar[6] = ItemStack.new(7, 64)  -- Tall Grass
	hotbar[7] = ItemStack.new(9, 1)   -- Chest
	hotbar[8] = ItemStack.new(10, 64) -- Sand
	hotbar[9] = ItemStack.new(12, 64) -- Oak Planks

	-- Initialize inventory with starter items
	inventory[1] = ItemStack.new(13, 1)  -- Crafting Table
	inventory[2] = ItemStack.new(15, 64) -- Bricks

	-- Fill remaining inventory slots
	for i = 3, 27 do
		inventory[i] = ItemStack.new(0, 0)
	end

	self.inventories[player] = {
		hotbar = hotbar,
		inventory = inventory
	}

	-- Debug: Log what we created
	self._logger.Info("Created inventory with starter items", {player = player.Name})
	for i = 1, 5 do
		local stack = hotbar[i]
		self._logger.Debug(string.format("  Hotbar[%d]: ItemID=%d, Count=%d", i, stack:GetItemId(), stack:GetCount()))
	end

	-- Send initial inventory to client
	self:SyncInventoryToClient(player)

	self._logger.Info("Initialized inventory", {player = player.Name})
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
	self._logger.Info("Removed inventory", {player = player.Name})
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

	-- Try to stack with existing items first
	for _, stack in ipairs(playerInv.hotbar) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local space = stack:GetRemainingSpace()
			local toAdd = math.min(space, remaining)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
		end
	end

	for _, stack in ipairs(playerInv.inventory) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local space = stack:GetRemainingSpace()
			local toAdd = math.min(space, remaining)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
		end
	end

	-- Put in empty slots if any remaining
	if remaining > 0 then
		for _, stack in ipairs(playerInv.hotbar) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				local toAdd = math.min(64, remaining)
				stack.itemId = itemId
				stack:SetCount(toAdd)
				remaining = remaining - toAdd
			end
		end

		for _, stack in ipairs(playerInv.inventory) do
			if remaining <= 0 then break end
			if stack:IsEmpty() then
				local toAdd = math.min(64, remaining)
				stack.itemId = itemId
				stack:SetCount(toAdd)
				remaining = remaining - toAdd
			end
		end
	end

	-- Sync entire inventory if anything was added
	if remaining < count then
		self:SyncInventoryToClient(player)
		return true
	end

	return false
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

	-- Remove from hotbar first
	for _, stack in ipairs(playerInv.hotbar) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId then
			local toRemove = math.min(stack:GetCount(), remaining)
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	-- Remove from inventory if still needed
	for _, stack in ipairs(playerInv.inventory) do
		if remaining <= 0 then break end
		if stack:GetItemId() == itemId then
			local toRemove = math.min(stack:GetCount(), remaining)
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	-- Sync entire inventory
	self:SyncInventoryToClient(player)

	return remaining == 0
end

-- Update hotbar slot from client request (with validation)
function PlayerInventoryService:UpdateHotbarSlot(player: Player, slotIndex: number, itemStack: any)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 9 then return end

	-- TODO: Add anti-cheat validation here
	-- For now, trust client (creative mode style)

	local stack = ItemStack.Deserialize(itemStack)
	playerInv.hotbar[slotIndex] = stack

	-- Broadcast to other players? (for now, no - inventory is private)
end

-- Update inventory slot from client request (with validation)
function PlayerInventoryService:UpdateInventorySlot(player: Player, slotIndex: number, itemStack: any)
	local playerInv = self.inventories[player]
	if not playerInv or slotIndex < 1 or slotIndex > 27 then return end

	-- TODO: Add anti-cheat validation

	local stack = ItemStack.Deserialize(itemStack)
	playerInv.inventory[slotIndex] = stack
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

	-- VALIDATION: Validate inventory array structure
	if updateData.inventory then
		local valid, reason = InventoryValidator:ValidateInventoryArray(updateData.inventory, 27)
		if not valid then
			self._logger.Warn("Invalid inventory array", {player = player.Name, reason = reason})
			-- Resync correct state to client
			self:SyncInventoryToClient(player)
			return
		end
	end

	-- VALIDATION: Validate hotbar array structure
	if updateData.hotbar then
		local valid, reason = InventoryValidator:ValidateInventoryArray(updateData.hotbar, 9)
		if not valid then
			self._logger.Warn("Invalid hotbar array", {player = player.Name, reason = reason})
			-- Resync correct state to client
			self:SyncInventoryToClient(player)
			return
		end
	end

	-- VALIDATION: Check for item duplication (compare old vs new totals)
	local valid, reason = InventoryValidator:ValidateInventoryTransaction(
		playerInv.inventory,
		playerInv.hotbar,
		updateData.inventory,
		updateData.hotbar
	)

	if not valid then
		self._logger.Warn("Transaction validation failed - potential exploit attempt", {
			player = player.Name,
			reason = reason
		})
		-- Resync correct state to client
		self:SyncInventoryToClient(player)
		return
	end

	-- Validation passed - apply changes
	if updateData.hotbar then
		for i, stackData in pairs(updateData.hotbar) do
			-- Convert to number if needed
			local slotIndex = tonumber(i) or i
			self:UpdateHotbarSlot(player, slotIndex, stackData)
		end
	end

	if updateData.inventory then
		for i, stackData in pairs(updateData.inventory) do
			-- Convert to number if needed
			local slotIndex = tonumber(i) or i
			self:UpdateInventorySlot(player, slotIndex, stackData)
		end
	end

	self._logger.Debug("Validated and applied inventory update", {player = player.Name})
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
	self._logger.Info("Loaded inventory from DataStore", {player = player.Name})
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

