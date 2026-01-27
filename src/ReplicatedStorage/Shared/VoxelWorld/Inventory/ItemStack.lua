--[[
	ItemStack.lua
	Represents a stack of items in inventory (Minecraft-style)
	Max stack size: 64 for most blocks
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local ItemStack = {}
ItemStack.__index = ItemStack

-- Default max stack sizes
local DEFAULT_MAX_STACK = 64
local MAX_STACK_SIZES = {
	-- Stackable ammo (even though they're in ToolConfig for display)
	[BowConfig.ARROW_ITEM_ID] = 64,
}

-- Configure per-item max stacks
do
	-- Minion item is non-stackable
	MAX_STACK_SIZES[Constants.BlockType.COBBLESTONE_MINION] = 1
	MAX_STACK_SIZES[Constants.BlockType.COAL_MINION] = 1
	
	-- Bucket stack sizes (Minecraft-style)
	MAX_STACK_SIZES[Constants.BlockType.BUCKET] = 16  -- Empty buckets stack to 16
	MAX_STACK_SIZES[Constants.BlockType.WATER_BUCKET] = 1  -- Water buckets don't stack
end

function ItemStack.new(itemId, count, maxStack)
    local self = setmetatable({}, ItemStack)

    self.itemId = tonumber(itemId) or 0
    self.count = tonumber(count) or 1

    -- Check explicit max stack first, then tools/armor default to 1, else default stack
    local resolvedMax = maxStack
    if not resolvedMax then
        local explicit = MAX_STACK_SIZES[self.itemId]
        if explicit then
            resolvedMax = explicit
        elseif ToolConfig.IsTool(self.itemId) or ArmorConfig.IsArmor(self.itemId) then
            resolvedMax = 1
        else
            resolvedMax = DEFAULT_MAX_STACK
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

	-- Tools and armor cannot stack except items with explicit stack sizes (like arrows)
	if (ToolConfig.IsTool(self.itemId) or ArmorConfig.IsArmor(self.itemId)) and not MAX_STACK_SIZES[self.itemId] then
		return false
	end

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

-- Set a new item into this slot, resolving the correct maxStack
-- Use this instead of direct itemId assignment to avoid maxStack bugs
function ItemStack:SetItem(itemId, count)
	itemId = tonumber(itemId) or 0
	count = tonumber(count) or 1
	
	self.itemId = itemId
	
	-- Resolve maxStack for the new item type
	local explicit = MAX_STACK_SIZES[itemId]
	if explicit then
		self.maxStack = explicit
	elseif ToolConfig.IsTool(itemId) or ArmorConfig.IsArmor(itemId) then
		self.maxStack = 1
	else
		self.maxStack = DEFAULT_MAX_STACK
	end
	
	-- Set count (will clamp and clear if needed)
	self:SetCount(count)
end

-- Static helper to get max stack size for an item
function ItemStack.GetMaxStackForItem(itemId)
	itemId = tonumber(itemId) or 0
	local explicit = MAX_STACK_SIZES[itemId]
	if explicit then
		return explicit
	elseif ToolConfig.IsTool(itemId) or ArmorConfig.IsArmor(itemId) then
		return 1
	else
		return DEFAULT_MAX_STACK
	end
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
    local explicit = MAX_STACK_SIZES[itemId]
    if explicit then
        resolvedMax = explicit
    elseif ToolConfig.IsTool(itemId) or ArmorConfig.IsArmor(itemId) then
        resolvedMax = 1
    else
        resolvedMax = DEFAULT_MAX_STACK
    end

    local stack = ItemStack.new(itemId, count, resolvedMax)
    stack.metadata = data.metadata or {}
    return stack
end

return ItemStack

