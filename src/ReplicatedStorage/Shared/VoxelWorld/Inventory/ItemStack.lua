--[[
	ItemStack.lua
	Represents a stack of items in inventory (Minecraft-style)
	Max stack size: 64 for most blocks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local ItemStack = {}
ItemStack.__index = ItemStack

-- Default max stack sizes
local DEFAULT_MAX_STACK = 64
local MAX_STACK_SIZES = {
	-- Tools and special items don't stack
	-- Add custom stack sizes here if needed
}

-- Configure per-item max stacks (non-tools)
do
	-- Minion item is non-stackable
	MAX_STACK_SIZES[Constants.BlockType.COBBLESTONE_MINION] = 1
end

function ItemStack.new(itemId, count, maxStack)
    local self = setmetatable({}, ItemStack)

    self.itemId = tonumber(itemId) or 0
    self.count = tonumber(count) or 1

    -- Tools are non-stackable (max 1). Otherwise use configured/default max.
    local resolvedMax = maxStack
    if not resolvedMax then
        if ToolConfig.IsTool(self.itemId) then
            resolvedMax = 1
        else
            resolvedMax = MAX_STACK_SIZES[self.itemId] or DEFAULT_MAX_STACK
        end
    end
    self.maxStack = resolvedMax

    self.metadata = {} -- For future use (durability, enchantments, etc)

    -- Clamp count to maxStack and clear if zero
    self.count = math.clamp(self.count, 0, self.maxStack)
    if self.count <= 0 then
        self:Clear()
    end

    return self
end

function ItemStack:IsEmpty()
	return self.itemId == 0 or self.count <= 0
end

function ItemStack:GetItemId()
    return tonumber(self.itemId) or 0
end

function ItemStack:GetCount()
	return self.count
end

function ItemStack:GetMaxStack()
	return self.maxStack
end

function ItemStack:SetCount(count)
	self.count = math.clamp(count, 0, self.maxStack)
	if self.count <= 0 then
		self:Clear()
	end
end

function ItemStack:AddCount(amount)
	self:SetCount(self.count + amount)
end

function ItemStack:RemoveCount(amount)
	self:SetCount(self.count - amount)
end

function ItemStack:IsFull()
	return self.count >= self.maxStack
end

function ItemStack:CanStack(other)
	if not other or other:IsEmpty() then return false end
	if self.itemId ~= other.itemId then return false end

	-- Tools cannot stack (Minecraft parity)
	if ToolConfig.IsTool(self.itemId) then return false end

	return true
end

function ItemStack:GetRemainingSpace()
	return self.maxStack - self.count
end

-- Try to merge another stack into this one
-- Returns: amount successfully added
function ItemStack:Merge(other)
	if not self:CanStack(other) then return 0 end

	local spaceLeft = self:GetRemainingSpace()
	local amountToAdd = math.min(spaceLeft, other.count)

	self:AddCount(amountToAdd)
	other:RemoveCount(amountToAdd)

	return amountToAdd
end

-- Split stack in half (rounds up), returns new stack with half
function ItemStack:SplitHalf()
	if self:IsEmpty() then return ItemStack.new(0, 0) end

	local halfCount = math.ceil(self.count / 2)
	local remainingCount = self.count - halfCount

	local newStack = ItemStack.new(self.itemId, halfCount, self.maxStack)
	self:SetCount(remainingCount)

	return newStack
end

-- Take one item from this stack, returns new stack with 1 item
function ItemStack:TakeOne()
	if self:IsEmpty() then return ItemStack.new(0, 0) end

	local newStack = ItemStack.new(self.itemId, 1, self.maxStack)
	self:RemoveCount(1)

	return newStack
end

function ItemStack:Clear()
	self.itemId = 0
	self.count = 0
end

function ItemStack:Clone()
	local clone = ItemStack.new(self.itemId, self.count, self.maxStack)
	-- Deep copy metadata if needed
	for k, v in pairs(self.metadata) do
		clone.metadata[k] = v
	end
	return clone
end

function ItemStack:Serialize()
	return {
		itemId = self.itemId,
		count = self.count,
		maxStack = self.maxStack,
		metadata = self.metadata
	}
end

function ItemStack.Deserialize(data)
    if not data then return ItemStack.new(0, 0) end

    -- Coerce potentially string-typed fields from network/datastore
    local itemId = tonumber(data.itemId or data.id) or 0
    local count = tonumber(data.count) or 0

    -- Re-resolve maxStack based on current config to avoid persisting wrong max values
    local resolvedMax
    if ToolConfig.IsTool(itemId) then
        resolvedMax = 1
    else
        resolvedMax = MAX_STACK_SIZES[itemId] or DEFAULT_MAX_STACK
    end

    local stack = ItemStack.new(itemId, count, resolvedMax)
    stack.metadata = data.metadata or {}
    return stack
end

return ItemStack

