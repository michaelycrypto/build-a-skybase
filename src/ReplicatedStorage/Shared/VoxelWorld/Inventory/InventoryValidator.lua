--[[
	InventoryValidator.lua
	Server-side validation for inventory operations (Minecraft-style)
	Prevents item duplication, invalid stack sizes, and other exploits
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)

local InventoryValidator = {}

-- Maximum stack size for most items
local MAX_STACK_SIZE = 64
local MIN_STACK_SIZE = 0

-- Valid block/item IDs (based on Constants.BlockType)
local VALID_ITEM_IDS = {
	[Constants.BlockType.AIR] = true,
	[Constants.BlockType.GRASS] = true,
	[Constants.BlockType.DIRT] = true,
	[Constants.BlockType.STONE] = true,
	[Constants.BlockType.BEDROCK] = true,
	[Constants.BlockType.WOOD] = true,
	[Constants.BlockType.LEAVES] = true,
	[Constants.BlockType.TALL_GRASS] = true,
	[Constants.BlockType.FLOWER] = true,
	[Constants.BlockType.CHEST] = true,
	[Constants.BlockType.SAND] = true,
	[Constants.BlockType.STONE_BRICKS] = true,
	[Constants.BlockType.OAK_PLANKS] = true,
	[Constants.BlockType.CRAFTING_TABLE] = true,
	[Constants.BlockType.COBBLESTONE] = true,
	[Constants.BlockType.BRICKS] = true,
	[Constants.BlockType.OAK_SAPLING] = true,
	[Constants.BlockType.OAK_STAIRS] = true,
	[Constants.BlockType.STONE_STAIRS] = true,
	[Constants.BlockType.COBBLESTONE_STAIRS] = true,
	[Constants.BlockType.STONE_BRICK_STAIRS] = true,
	[Constants.BlockType.BRICK_STAIRS] = true,
	[Constants.BlockType.OAK_SLAB] = true,
	[Constants.BlockType.STONE_SLAB] = true,
	[Constants.BlockType.COBBLESTONE_SLAB] = true,
	[Constants.BlockType.STONE_BRICK_SLAB] = true,
	[Constants.BlockType.BRICK_SLAB] = true,
	[Constants.BlockType.OAK_FENCE] = true,
	[Constants.BlockType.STICK] = true,
	[Constants.BlockType.COAL_ORE] = true,
	[Constants.BlockType.IRON_ORE] = true,
	[Constants.BlockType.DIAMOND_ORE] = true,
	[Constants.BlockType.COAL] = true,
	[Constants.BlockType.IRON_INGOT] = true,
	[Constants.BlockType.DIAMOND] = true,
	[Constants.BlockType.FURNACE] = true,
	[Constants.BlockType.GLASS] = true,
	-- New wood families
	[Constants.BlockType.SPRUCE_LOG] = true,
	[Constants.BlockType.SPRUCE_PLANKS] = true,
	[Constants.BlockType.SPRUCE_SAPLING] = true,
	[Constants.BlockType.SPRUCE_STAIRS] = true,
	[Constants.BlockType.SPRUCE_SLAB] = true,
	[Constants.BlockType.JUNGLE_LOG] = true,
	[Constants.BlockType.JUNGLE_PLANKS] = true,
	[Constants.BlockType.JUNGLE_SAPLING] = true,
	[Constants.BlockType.JUNGLE_STAIRS] = true,
	[Constants.BlockType.JUNGLE_SLAB] = true,
	[Constants.BlockType.DARK_OAK_LOG] = true,
	[Constants.BlockType.DARK_OAK_PLANKS] = true,
	[Constants.BlockType.DARK_OAK_SAPLING] = true,
	[Constants.BlockType.DARK_OAK_STAIRS] = true,
	[Constants.BlockType.DARK_OAK_SLAB] = true,
	[Constants.BlockType.BIRCH_LOG] = true,
	[Constants.BlockType.BIRCH_PLANKS] = true,
	[Constants.BlockType.BIRCH_SAPLING] = true,
	[Constants.BlockType.BIRCH_STAIRS] = true,
	[Constants.BlockType.BIRCH_SLAB] = true,
	[Constants.BlockType.ACACIA_LOG] = true,
	[Constants.BlockType.ACACIA_PLANKS] = true,
	[Constants.BlockType.ACACIA_SAPLING] = true,
	[Constants.BlockType.ACACIA_STAIRS] = true,
	[Constants.BlockType.ACACIA_SLAB] = true,

		-- Farming items
		[Constants.BlockType.FARMLAND] = true,
		[Constants.BlockType.WHEAT_SEEDS] = true,
		[Constants.BlockType.WHEAT] = true,
		[Constants.BlockType.POTATO] = true,
		[Constants.BlockType.CARROT] = true,
		[Constants.BlockType.BEETROOT_SEEDS] = true,
		[Constants.BlockType.BEETROOT] = true,
		-- Utility/minion
		[Constants.BlockType.COBBLESTONE_MINION] = true,
}

--[[
	Validate a single ItemStack
	Returns: isValid (boolean), reason (string)
]]
function InventoryValidator:ValidateItemStack(stackData)
	if not stackData then
		return false, "Stack data is nil"
	end

	-- Check if itemId is a valid item (block or tool)
    local itemId = tonumber(stackData.itemId or stackData.id) or 0
	local isTool = ToolConfig.IsTool(itemId)
	if not VALID_ITEM_IDS[itemId] and not isTool and not SpawnEggConfig.IsSpawnEgg(itemId) then
		return false, string.format("Invalid item ID: %d", itemId)
	end

	-- Air (0) must have count 0
	if itemId == 0 and stackData.count ~= 0 then
		return false, "Air must have count 0"
	end

	-- Check count is within valid range
    local count = tonumber(stackData.count) or 0
	if count < MIN_STACK_SIZE or count > MAX_STACK_SIZE then
		return false, string.format("Invalid count: %d (must be 0-64)", count)
	end

	-- Tools are non-stackable (Minecraft parity)
	if isTool and count > 1 then
		return false, string.format("Invalid count for tool %d: %d (tools do not stack)", itemId, count)
	end

	-- Non-air items must have count > 0
	if itemId > 0 and count <= 0 then
		return false, "Non-air items must have count > 0"
	end

	return true, nil
end

--[[
	Validate entire inventory/hotbar array
	Returns: isValid (boolean), reason (string), totalItems (number)
]]
function InventoryValidator:ValidateInventoryArray(slots, expectedSize)
	if not slots then
		return false, "Slots array is nil", 0
	end

	local totalItems = {}
	local slotCount = 0

	for i, stackData in pairs(slots) do
		slotCount = slotCount + 1

		-- Validate slot index
		if type(i) ~= "number" or i < 1 or i > expectedSize then
			return false, string.format("Invalid slot index: %s", tostring(i)), 0
		end

		-- Validate stack
		local valid, reason = self:ValidateItemStack(stackData)
		if not valid then
			return false, string.format("Slot %d invalid: %s", i, reason), 0
		end

		-- Count total items per type (for duplication checking)
        local itemId = tonumber(stackData.itemId or stackData.id) or 0
        if itemId > 0 then
            totalItems[itemId] = (totalItems[itemId] or 0) + (tonumber(stackData.count) or 0)
		end
	end

	-- Check we don't have more slots than expected
	if slotCount > expectedSize then
		return false, string.format("Too many slots: %d (expected %d)", slotCount, expectedSize), 0
	end

	return true, nil, totalItems
end

--[[
	Compare old and new inventory states to detect item creation/duplication
	Returns: isValid (boolean), reason (string)
]]
function InventoryValidator:ValidateInventoryTransaction(oldInventory, oldHotbar, newInventory, newHotbar)
	-- Count items in old state
	local oldTotals = {}

	-- Count old inventory
	if oldInventory then
		for _, stack in pairs(oldInventory) do
			local itemId = stack:GetItemId()
			if itemId > 0 then
				oldTotals[itemId] = (oldTotals[itemId] or 0) + stack:GetCount()
			end
		end
	end

	-- Count old hotbar
	if oldHotbar then
		for _, stack in pairs(oldHotbar) do
			local itemId = stack:GetItemId()
			if itemId > 0 then
				oldTotals[itemId] = (oldTotals[itemId] or 0) + stack:GetCount()
			end
		end
	end

	-- Count items in new state
	local newTotals = {}

	-- Count new inventory
	if newInventory then
		for i, stackData in pairs(newInventory) do
            local itemId = tonumber(stackData.itemId or stackData.id) or 0
            if itemId > 0 then
                newTotals[itemId] = (newTotals[itemId] or 0) + (tonumber(stackData.count) or 0)
			end
		end
	end

	-- Count new hotbar
	if newHotbar then
		for i, stackData in pairs(newHotbar) do
            local itemId = tonumber(stackData.itemId or stackData.id) or 0
            if itemId > 0 then
                newTotals[itemId] = (newTotals[itemId] or 0) + (tonumber(stackData.count) or 0)
			end
		end
	end

	-- Compare totals - client InventoryUpdate must not create items in survival.
	-- Any net increase is invalid; item gains come from server-side actions only.
	for itemId, newCount in pairs(newTotals) do
		local oldCount = oldTotals[itemId] or 0
		if newCount > oldCount then
			return false, string.format(
				"Invalid gain: Item %d increased from %d to %d via client update",
				itemId, oldCount, newCount
			)
		end
	end

	return true, nil
end

--[[
	Validate chest operation (moving items between chest and inventory)
	NOTE: Cursor items are NOT included in validation - transactions should only
	be sent when cursor is empty (action complete) to keep validation simple.
	Returns: isValid (boolean), reason (string)
]]
function InventoryValidator:ValidateChestTransaction(
	oldChest, newChest,
	oldInventory, newInventory,
	playerName
)
	-- Count total items before (chest + inventory only, cursor should be empty)
	local beforeTotals = {}

	for _, stack in pairs(oldChest or {}) do
		if stack and stack.itemId and stack.itemId > 0 then
			beforeTotals[stack.itemId] = (beforeTotals[stack.itemId] or 0) + (stack.count or 0)
		end
	end

	for _, stack in pairs(oldInventory or {}) do
		local itemId = stack:GetItemId()
		if itemId > 0 then
			beforeTotals[itemId] = (beforeTotals[itemId] or 0) + stack:GetCount()
		end
	end

	-- Count total items after (chest + inventory only, cursor should be empty)
	local afterTotals = {}

	for _, stackData in pairs(newChest or {}) do
		if stackData and stackData.itemId and stackData.itemId > 0 then
            afterTotals[stackData.itemId] = (afterTotals[stackData.itemId] or 0) + (tonumber(stackData.count) or 0)
		end
	end

	for _, stackData in pairs(newInventory or {}) do
        local itemId = tonumber(stackData.itemId or stackData.id) or 0
        if itemId > 0 then
            afterTotals[itemId] = (afterTotals[itemId] or 0) + (tonumber(stackData.count) or 0)
		end
	end

	-- In chest operations, total items should remain constant (just moving between containers)
	-- Allow tiny discrepancies due to floating point, but flag significant differences
	for itemId, afterCount in pairs(afterTotals) do
		local beforeCount = beforeTotals[itemId] or 0

		if afterCount > beforeCount then
			-- Items were created
			return false, string.format(
				"Item duplication detected: %s gained %d of item %d in chest operation",
				playerName, afterCount - beforeCount, itemId
			)
		end
	end

	-- Check for items that disappeared
	for itemId, beforeCount in pairs(beforeTotals) do
		local afterCount = afterTotals[itemId] or 0

		if afterCount < beforeCount then
			-- Items were lost - this is allowed (dropping, deletion)
			-- But log it for audit purposes
			print(string.format(
				"[Audit] %s lost %d of item %d in chest operation",
				playerName, beforeCount - afterCount, itemId
			))
		end
	end

	return true, nil
end

--[[
	Validate block placement (consuming from inventory)
	Returns: isValid (boolean), reason (string)
]]
function InventoryValidator:ValidateBlockPlacement(hotbarSlot, itemId, oldStack, newStack)
	-- Check slot index is valid
	if hotbarSlot < 1 or hotbarSlot > 9 then
		return false, string.format("Invalid hotbar slot: %d", hotbarSlot)
	end

	-- Check old stack has the item
	if not oldStack or oldStack:GetItemId() ~= itemId then
		return false, string.format("Hotbar slot %d doesn't contain item %d", hotbarSlot, itemId)
	end

	-- Check old stack has at least 1 item
	if oldStack:GetCount() < 1 then
		return false, string.format("Hotbar slot %d is empty", hotbarSlot)
	end

	-- Check new stack is exactly 1 less
	if newStack:GetCount() ~= oldStack:GetCount() - 1 then
		return false, string.format(
			"Invalid consumption: Expected %d->%d, got %d->%d",
			oldStack:GetCount(), oldStack:GetCount() - 1,
			oldStack:GetCount(), newStack:GetCount()
		)
	end

	return true, nil
end

--[[
	Sanitize inventory data from client
	Clamps values to valid ranges and removes invalid entries
	Returns: sanitized data, wasModified (boolean)
]]
function InventoryValidator:SanitizeInventoryData(slots, expectedSize)
	local sanitized = {}
	local wasModified = false

	for i, stackData in pairs(slots) do
		if type(i) == "number" and i >= 1 and i <= expectedSize then
            local itemId = tonumber(stackData.itemId or stackData.id) or 0
            local count = tonumber(stackData.count) or 0

			-- Clamp to valid ranges
			if itemId < 0 then itemId = 0; wasModified = true end
			if count < 0 then count = 0; wasModified = true end
			if count > MAX_STACK_SIZE then count = MAX_STACK_SIZE; wasModified = true end

			-- Validate item ID exists (allow tools and spawn eggs)
            local isTool = ToolConfig.IsTool(itemId)
			local isEgg = SpawnEggConfig.IsSpawnEgg(itemId)
			if not VALID_ITEM_IDS[itemId] and not isTool and not isEgg then
				itemId = 0
				count = 0
				wasModified = true
			end

			-- Air must have 0 count
			if itemId == 0 then
				count = 0
			end

			-- Tools are non-stackable: clamp to 1 if >1 (keep 0 if empty)
			if isTool and count > 1 then
				count = 1
				wasModified = true
			end

				sanitized[i] = {
					itemId = itemId,
					count = count,
					maxStack = (isTool and 1) or (stackData.maxStack or MAX_STACK_SIZE),
					metadata = stackData.metadata or {}
				}
		else
			wasModified = true
		end
	end

	return sanitized, wasModified
end

return InventoryValidator

