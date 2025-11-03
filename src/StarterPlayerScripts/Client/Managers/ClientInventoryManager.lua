--[[
	ClientInventoryManager.lua
	Single source of truth for player's client-side inventory data

	Manages:
	- 27 inventory slots
	- 9 hotbar slots (shared with VoxelHotbar)
	- Event-based synchronization with server
	- Update notifications for UIs

	All inventory UIs (ChestUI, VoxelInventoryPanel) reference this manager
	instead of maintaining their own copies of inventory data.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local ClientInventoryManager = {}
ClientInventoryManager.__index = ClientInventoryManager

function ClientInventoryManager.new(hotbar)
	local self = setmetatable({}, ClientInventoryManager)

	-- Reference to hotbar (which owns hotbar slots)
	self.hotbar = hotbar

	-- Inventory slots (27 slots - the main storage)
	self.inventory = {}
	for i = 1, 27 do
		self.inventory[i] = ItemStack.new(0, 0)
	end

	-- Callbacks for when inventory updates
	self.onInventoryChanged = {}
	self.onHotbarChanged = {}

	-- Server sync state
	self._syncingFromServer = false

	-- Event connections
	self.connections = {}

	return self
end

function ClientInventoryManager:Initialize()
	-- Register server events
	self:RegisterServerEvents()
	return self
end

-- === INVENTORY ACCESS ===

function ClientInventoryManager:GetInventorySlot(index)
	if index < 1 or index > 27 then
		return ItemStack.new(0, 0)
	end
	return self.inventory[index]
end

function ClientInventoryManager:SetInventorySlot(index, stack)
	if index < 1 or index > 27 then return end

    -- Normalize tools to be non-stackable and ensure correct max stack
    local normalized = stack or ItemStack.new(0, 0)
    if normalized and not normalized:IsEmpty() then
        local itemId = normalized:GetItemId()
        local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
        if ToolConfig.IsTool(itemId) then
            normalized = ItemStack.new(itemId, math.min(normalized:GetCount(), 1), 1)
        end
    end

    self.inventory[index] = normalized
	self:NotifyInventoryChanged(index)
end

function ClientInventoryManager:GetHotbarSlot(index)
	if not self.hotbar then
		return ItemStack.new(0, 0)
	end
	return self.hotbar:GetSlot(index)
end

function ClientInventoryManager:SetHotbarSlot(index, stack)
	if not self.hotbar then return end

    -- Normalize tools to be non-stackable and ensure correct max stack
    local normalized = stack or ItemStack.new(0, 0)
    if normalized and not normalized:IsEmpty() then
        local itemId = normalized:GetItemId()
        local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
        if ToolConfig.IsTool(itemId) then
            normalized = ItemStack.new(itemId, math.min(normalized:GetCount(), 1), 1)
        end
    end

    self.hotbar:SetSlot(index, normalized)
	self:NotifyHotbarChanged(index)
end

-- Get all inventory slots as array
function ClientInventoryManager:GetInventoryArray()
	local arr = {}
	for i = 1, 27 do
		arr[i] = self.inventory[i]
	end
	return arr
end

-- Get all hotbar slots as array
function ClientInventoryManager:GetHotbarArray()
	if not self.hotbar then return {} end

	local arr = {}
	for i = 1, 9 do
		arr[i] = self.hotbar:GetSlot(i)
	end
	return arr
end

-- === SERIALIZATION ===

function ClientInventoryManager:SerializeInventory()
	local serialized = {}
	for i = 1, 27 do
        local stack = self.inventory[i]
        local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
        if stack and not stack:IsEmpty() and ToolConfig.IsTool(stack:GetItemId()) then
            if stack:GetCount() > 1 then
                stack:SetCount(1)
                self.inventory[i] = stack
            end
        end
        serialized[i] = stack:Serialize()
	end
	return serialized
end

function ClientInventoryManager:SerializeHotbar()
	if not self.hotbar then return {} end

	local serialized = {}
	for i = 1, 9 do
		local stack = self.hotbar:GetSlot(i)
        local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
        if stack and not stack:IsEmpty() and ToolConfig.IsTool(stack:GetItemId()) then
            if stack:GetCount() > 1 then
                stack:SetCount(1)
                self.hotbar:SetSlot(i, stack)
            end
        end
		serialized[i] = stack:Serialize()
	end
	return serialized
end

-- === SYNC WITH SERVER ===

function ClientInventoryManager:SendUpdateToServer()
	-- Don't send updates while syncing from server
	if self._syncingFromServer then
		return
	end

	local hotbarData = self:SerializeHotbar()
	local inventoryData = self:SerializeInventory()

	EventManager:SendToServer("InventoryUpdate", {
		inventory = inventoryData,
		hotbar = hotbarData
	})
end

function ClientInventoryManager:SyncFromServer(inventoryData, hotbarData)
	self._syncingFromServer = true

	-- Update inventory
	if inventoryData then
		for i = 1, 27 do
			if inventoryData[i] then
				self.inventory[i] = ItemStack.Deserialize(inventoryData[i])
			else
				self.inventory[i] = ItemStack.new(0, 0)
			end
		end
	end

	-- Update hotbar
	if hotbarData and self.hotbar then
		for i = 1, 9 do
			if hotbarData[i] then
				local stack = ItemStack.Deserialize(hotbarData[i])
				self.hotbar:SetSlot(i, stack)
			else
				self.hotbar:SetSlot(i, ItemStack.new(0, 0))
			end
		end
	end

	-- Notify all listeners
	self:NotifyAllChanged()


	-- Clear sync flag after a short delay (non-blocking)
	task.delay(0.15, function()
		self._syncingFromServer = false
	end)
end

-- === EVENT CALLBACKS ===

function ClientInventoryManager:OnInventoryChanged(callback)
	table.insert(self.onInventoryChanged, callback)
end

function ClientInventoryManager:OnHotbarChanged(callback)
	table.insert(self.onHotbarChanged, callback)
end

function ClientInventoryManager:NotifyInventoryChanged(slotIndex)
	for _, callback in ipairs(self.onInventoryChanged) do
		callback(slotIndex)
	end
end

function ClientInventoryManager:NotifyHotbarChanged(slotIndex)
	for _, callback in ipairs(self.onHotbarChanged) do
		callback(slotIndex)
	end
end

function ClientInventoryManager:NotifyAllChanged()
	-- Notify all inventory slots changed
	for i = 1, 27 do
		self:NotifyInventoryChanged(i)
	end

	-- Notify all hotbar slots changed
	for i = 1, 9 do
		self:NotifyHotbarChanged(i)
	end
end

-- === SERVER EVENT HANDLERS ===

function ClientInventoryManager:RegisterServerEvents()
	-- Full inventory sync from server
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("InventorySync", function(data)
		self:SyncFromServer(data.inventory, data.hotbar)
	end)

	-- Single hotbar slot update from server (server won't echo our own changes)
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("HotbarSlotUpdate", function(data)
		if data.slotIndex and data.stack and self.hotbar then
			local stack = ItemStack.Deserialize(data.stack)
			self.hotbar:SetSlot(data.slotIndex, stack)
			self:NotifyHotbarChanged(data.slotIndex)
		end
	end)

	-- Single inventory slot update from server (server won't echo our own changes)
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("InventorySlotUpdate", function(data)
		if data.slotIndex and data.stack then
			if data.slotIndex >= 1 and data.slotIndex <= 27 then
				self.inventory[data.slotIndex] = ItemStack.Deserialize(data.stack)
				self:NotifyInventoryChanged(data.slotIndex)
			end
		end
	end)

	print("ClientInventoryManager: Registered server events")
end

-- === CRAFTING HELPER METHODS ===

--[[
	Count total amount of an item across inventory and hotbar
	@param itemId: number - Item ID to count
	@return: number - Total count
]]
function ClientInventoryManager:CountItem(itemId)
	local count = 0

	-- Count in inventory (27 slots)
	for i = 1, 27 do
		local stack = self:GetInventorySlot(i)
		if stack:GetItemId() == itemId then
			count = count + stack:GetCount()
		end
	end

	-- Count in hotbar (9 slots)
	for i = 1, 9 do
		local stack = self:GetHotbarSlot(i)
		if stack:GetItemId() == itemId then
			count = count + stack:GetCount()
		end
	end

	return count
end

--[[
	Check if there's enough space in inventory to add items
	@param itemId: number - Item ID to add
	@param amount: number - Amount to add
	@return: boolean - True if there's enough space
]]
function ClientInventoryManager:HasSpaceForItem(itemId, amount)
	local remaining = amount

	local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
	local isTool = ToolConfig.IsTool(itemId)

	-- For tools, count empty slots only (tools don't stack)
	if isTool then
		local emptySlots = 0
		for i = 1, 27 do
			if self:GetInventorySlot(i):IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		for i = 1, 9 do
			if self:GetHotbarSlot(i):IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		return emptySlots >= amount
	end

	-- Check space in existing stacks (inventory)
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = self:GetInventorySlot(i)
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			remaining = remaining - spaceLeft
		end
	end

	-- Check space in existing stacks (hotbar)
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = self:GetHotbarSlot(i)
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			remaining = remaining - spaceLeft
		end
	end

	-- Count empty slots that can be used
	if remaining > 0 then
		local emptySlots = 0
		for i = 1, 27 do
			if self:GetInventorySlot(i):IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		for i = 1, 9 do
			if self:GetHotbarSlot(i):IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end

		-- Each empty slot can hold up to max stack size
		local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
		local spaceInEmptySlots = emptySlots * maxStack
		remaining = remaining - spaceInEmptySlots
	end

	return remaining <= 0
end

--[[
	Remove item from inventory/hotbar (smart removal from any slot)
	@param itemId: number - Item ID to remove
	@param amount: number - Amount to remove
	@return: boolean - True if all removed successfully
]]
function ClientInventoryManager:RemoveItem(itemId, amount)
	local remaining = amount

	-- Remove from inventory first
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = self:GetInventorySlot(i)
		if stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			self:SetInventorySlot(i, stack)
			remaining = remaining - toRemove
		end
	end

	-- Remove from hotbar if needed
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = self:GetHotbarSlot(i)
		if stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			self:SetHotbarSlot(i, stack)
			remaining = remaining - toRemove
		end
	end

	return remaining == 0  -- Returns true if all removed successfully
end

--[[
	Add item to inventory/hotbar (smart stacking)
	@param itemId: number - Item ID to add
	@param amount: number - Amount to add
	@return: boolean - True if all added successfully
]]
function ClientInventoryManager:AddItem(itemId, amount)
	local remaining = amount

    local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
    local isTool = ToolConfig.IsTool(itemId)

    -- Try to add to existing stacks first (inventory) - skip for tools
    if not isTool then
        for i = 1, 27 do
            if remaining <= 0 then break end

            local stack = self:GetInventorySlot(i)
            if stack:GetItemId() == itemId and not stack:IsFull() then
                local spaceLeft = stack:GetRemainingSpace()
                local toAdd = math.min(remaining, spaceLeft)
                stack:AddCount(toAdd)
                self:SetInventorySlot(i, stack)
                remaining = remaining - toAdd
            end
        end
    end

    -- Try to add to existing stacks in hotbar - skip for tools
    if not isTool then
        for i = 1, 9 do
            if remaining <= 0 then break end

            local stack = self:GetHotbarSlot(i)
            if stack:GetItemId() == itemId and not stack:IsFull() then
                local spaceLeft = stack:GetRemainingSpace()
                local toAdd = math.min(remaining, spaceLeft)
                stack:AddCount(toAdd)
                self:SetHotbarSlot(i, stack)
                remaining = remaining - toAdd
            end
        end
    end

	-- Create new stacks in empty slots (inventory)
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = self:GetInventorySlot(i)
		if stack:IsEmpty() then
            local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(remaining, maxStack)
			self:SetInventorySlot(i, ItemStack.new(itemId, toAdd))
			remaining = remaining - toAdd
		end
	end

	-- Create new stacks in empty slots (hotbar)
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = self:GetHotbarSlot(i)
		if stack:IsEmpty() then
            local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(remaining, maxStack)
			self:SetHotbarSlot(i, ItemStack.new(itemId, toAdd))
			remaining = remaining - toAdd
		end
	end

	-- If we couldn't add everything, inventory is full
	if remaining > 0 then
		warn("ClientInventoryManager: Inventory full, couldn't add", remaining, "of item", itemId)
		-- TODO: Could drop items to world here
	end

	return remaining == 0  -- Returns true if all added successfully
end

-- === CLEANUP ===

function ClientInventoryManager:Cleanup()
	for _, conn in ipairs(self.connections) do
		conn:Disconnect()
	end
	self.connections = {}

	self.onInventoryChanged = {}
	self.onHotbarChanged = {}

	print("ClientInventoryManager: Cleaned up")
end

return ClientInventoryManager

