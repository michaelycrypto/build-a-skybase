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

	self.inventory[index] = stack or ItemStack.new(0, 0)
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

	self.hotbar:SetSlot(index, stack)
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
		serialized[i] = self.inventory[i]:Serialize()
	end
	return serialized
end

function ClientInventoryManager:SerializeHotbar()
	if not self.hotbar then return {} end

	local serialized = {}
	for i = 1, 9 do
		local stack = self.hotbar:GetSlot(i)
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

	EventManager:SendToServer("InventoryUpdate", {
		inventory = self:SerializeInventory(),
		hotbar = self:SerializeHotbar()
	})

	print("ClientInventoryManager: Sent inventory update to server")
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

	-- Clear sync flag after a short delay
	task.wait(0.1)
	self._syncingFromServer = false

	print("ClientInventoryManager: Synced from server")
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

	-- Single hotbar slot update from server
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("HotbarSlotUpdate", function(data)
		if data.slotIndex and data.stack and self.hotbar then
			local stack = ItemStack.Deserialize(data.stack)
			self.hotbar:SetSlot(data.slotIndex, stack)
			self:NotifyHotbarChanged(data.slotIndex)
			print("ClientInventoryManager: Hotbar slot", data.slotIndex, "updated from server")
		end
	end)

	print("ClientInventoryManager: Registered server events")
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

