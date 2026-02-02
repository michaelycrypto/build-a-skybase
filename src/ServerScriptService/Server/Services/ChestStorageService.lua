--[[
	ChestStorageService.lua
	Server-side management of chest inventories
	Each chest is identified by its world position (x,y,z)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local InventoryValidator = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.InventoryValidator)

local ChestStorageService = {
	Name = "ChestStorageService"
}

-- Standardize and gate module-local prints through Logger at DEBUG level
local _logger = Logger:CreateContext("ChestStorageService")
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

-- Chest data structure: { x, y, z -> { slots = {}, viewers = {} } }
local CHEST_SLOTS = 27 -- Standard single chest size

-- Helpers: robust numeric coercion for potentially stringly-typed saved fields
local function toNumber(value, default)
	local n = tonumber(value)
	if n ~= nil then return n end
	return default or 0
end

local function isValidItem(slotData)
	return slotData and toNumber(slotData.itemId, 0) > 0
end

function ChestStorageService:Init()
	self.chests = {} -- Map of "x,y,z" -> chest data
	self.playerViewers = {} -- Map of Player -> {x, y, z} they're viewing
	print("ChestStorageService: Initialized")
end

-- Get chest key from coordinates
function ChestStorageService:GetChestKey(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

-- Get or create chest at position
function ChestStorageService:GetChest(x, y, z)
	local key = self:GetChestKey(x, y, z)

	if not self.chests[key] then
		print(string.format("[GetChest] ⚠️ Creating NEW empty chest at (%d,%d,%d)", x, y, z))
		-- Create new chest with empty slots
		self.chests[key] = {
			x = x,
			y = y,
			z = z,
			slots = {},
			viewers = {},
			cursors = {}  -- Track each player's cursor while viewing chest
		}

		-- DON'T initialize slots to nil - this removes them from the table!
		-- Slots will be nil by default, and we can set them when needed
		print(string.format("[GetChest]   Created empty chest, slots table address: %s", tostring(self.chests[key].slots)))
	else
		-- Count items in existing chest and DEBUG what's in it
		local itemCount = 0
		local totalSlots = 0
		print(string.format("[GetChest] Checking existing chest at (%d,%d,%d)...", x, y, z))
		for i = 1, CHEST_SLOTS do
			local slot = self.chests[key].slots[i]
			if slot then
				totalSlots = totalSlots + 1
				print(string.format("[GetChest]   Slot %d: type=%s, itemId=%s, count=%s, full dump:",
					i, type(slot), tostring(slot.itemId), tostring(slot.count)))
				-- Debug: Print the entire slot structure
				for k, v in pairs(slot) do
					print(string.format("[GetChest]     %s = %s (type: %s)", tostring(k), tostring(v), type(v)))
				end
				if isValidItem(slot) then
					itemCount = itemCount + 1
				end
			end
		end
		print(string.format("[GetChest] ✅ Returning existing chest at (%d,%d,%d) with %d items (total non-nil slots: %d)",
			x, y, z, itemCount, totalSlots))
	end

	return self.chests[key]
end

-- Initialize starter chest with all available blocks (for Skyblock)
function ChestStorageService:InitializeStarterChest(x, y, z)
	local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
	local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

	local _key = self:GetChestKey(x, y, z)

	-- Get or create the chest
	local chest = self:GetChest(x, y, z)

	-- Only initialize if chest is empty (prevent overwriting existing data)
	local hasItems = false
	for i = 1, CHEST_SLOTS do
		if isValidItem(chest.slots[i]) then
			hasItems = true
			break
		end
	end

	if hasItems then
		print(string.format("[InitializeStarterChest] Chest at (%d,%d,%d) already has items, skipping initialization", x, y, z))
		return
	end

	-- Starter chest items tuned for testing new wood families and recipes
	-- Baseline essentials
	local blockTypes = {
		-- Requested essentials
		{id = Constants.BlockType.COBBLESTONE_MINION, count = 1, metadata = { level = 1, minionType = "COBBLESTONE" }}, -- Level 1 Cobblestone Minion
		{id = Constants.BlockType.BIRCH_SAPLING, count = 8},      -- Birch saplings (requested)
		{id = Constants.BlockType.COBBLESTONE, count = 64},       -- 1 stack cobblestone (requested)

		{id = Constants.BlockType.GRASS, count = 64},           -- 1 stack grass blocks
		{id = Constants.BlockType.OAK_SAPLING, count = 8},      -- Oak saplings
		{id = Constants.BlockType.WOOD, count = 64},            -- Oak logs
		{id = Constants.BlockType.OAK_PLANKS, count = 64},      -- Oak planks
		{id = Constants.BlockType.STONE_BRICKS, count = 64},    -- Building block: Stone Bricks
		{id = Constants.BlockType.BRICKS, count = 64},          -- Building block: Bricks

		-- Spruce samples
		{id = Constants.BlockType.SPRUCE_SAPLING, count = 8},
		{id = Constants.BlockType.SPRUCE_LOG, count = 32},
		{id = Constants.BlockType.SPRUCE_PLANKS, count = 32},

		-- Jungle samples
		{id = Constants.BlockType.JUNGLE_SAPLING, count = 8},
		{id = Constants.BlockType.JUNGLE_LOG, count = 32},
		{id = Constants.BlockType.JUNGLE_PLANKS, count = 32},

		-- Dark Oak samples
		{id = Constants.BlockType.DARK_OAK_SAPLING, count = 8},
		{id = Constants.BlockType.DARK_OAK_LOG, count = 32},
		{id = Constants.BlockType.DARK_OAK_PLANKS, count = 32},

		-- Birch samples
		{id = Constants.BlockType.BIRCH_LOG, count = 32},
		{id = Constants.BlockType.BIRCH_PLANKS, count = 32},

		-- Acacia samples
		{id = Constants.BlockType.ACACIA_SAPLING, count = 8},
		{id = Constants.BlockType.ACACIA_LOG, count = 32},
		{id = Constants.BlockType.ACACIA_PLANKS, count = 32},

		-- Pre-crafted stairs for quick placement tests (one per family)
		{id = Constants.BlockType.SPRUCE_STAIRS, count = 16},
		{id = Constants.BlockType.JUNGLE_STAIRS, count = 16},
		{id = Constants.BlockType.DARK_OAK_STAIRS, count = 16},
		{id = Constants.BlockType.BIRCH_STAIRS, count = 16},
		{id = Constants.BlockType.ACACIA_STAIRS, count = 16},
	}

	-- Fill chest slots
	for i, blockData in ipairs(blockTypes) do
		if i <= CHEST_SLOTS then
			local stack = ItemStack.new(blockData.id, blockData.count)
			if blockData.metadata then
				for k, v in pairs(blockData.metadata) do
					stack.metadata[k] = v
				end
			end
			chest.slots[i] = stack:Serialize()
			print(string.format("[InitializeStarterChest] Added block ID %d (x%d) to slot %d", blockData.id, blockData.count, i))
		end
	end

	print(string.format("[InitializeStarterChest] ✅ Initialized starter chest at (%d,%d,%d) with %d block types", x, y, z, #blockTypes))
end

-- Handle player requesting to open chest
function ChestStorageService:HandleOpenChest(player, data)
	if not data or not data.x or not data.y or not data.z then
		warn("Invalid chest open request from", player.Name)
		return
	end

    -- Normalize numeric inputs (defensive: some clients may send strings)
    local x = tonumber(data.x) or data.x
    local y = tonumber(data.y) or data.y
    local z = tonumber(data.z) or data.z
	local key = self:GetChestKey(x, y, z)
	print(string.format("[HandleOpenChest] Opening chest at (%d,%d,%d), key=%s", x, y, z, key))

	-- Verify block is actually a chest
	if self.Deps and self.Deps.VoxelWorldService then
		local worldManager = self.Deps.VoxelWorldService.worldManager
		if worldManager then
			local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
			local blockId = worldManager:GetBlock(x, y, z)
			if blockId ~= Constants.BlockType.CHEST then
				print("Player tried to open non-chest block at", x, y, z)
				return
			end
		end
	end

	-- Get or create chest
	local chest = self:GetChest(x, y, z)

	-- Add player as viewer
	chest.viewers[player] = true
	self.playerViewers[player] = {x = x, y = y, z = z}

	-- Initialize empty cursor for this player's chest session
	local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
	chest.cursors[tostring(player.UserId)] = ItemStack.new(0, 0)

	-- Get player inventory from PlayerInventoryService
	-- IMPORTANT: Send ALL 27 slots (even empty) to keep array dense
	local emptySlot = ItemStack.new(0, 0):Serialize()
	local playerInventory = {}
	local hotbar = {}
	if self.Deps and self.Deps.PlayerInventoryService then
		local invData = self.Deps.PlayerInventoryService.inventories[player]
		if invData then
			-- Get inventory slots (27 slots) - use Serialize() for proper format
			for i = 1, 27 do
				local stack = invData.inventory[i]
				if stack and stack:GetItemId() > 0 then
					playerInventory[i] = stack:Serialize()
				else
					playerInventory[i] = emptySlot
				end
			end

			-- Get hotbar slots (9 slots) - use Serialize() for proper format
			for i = 1, 9 do
				local stack = invData.hotbar[i]
				if stack and stack:GetItemId() > 0 then
					hotbar[i] = stack:Serialize()
				else
					hotbar[i] = emptySlot
				end
			end
		end
	end

	-- Build dense chest contents array (all 27 slots)
	local chestContents = {}
	local chestItemCount = 0
	for i = 1, 27 do
		chestContents[i] = chest.slots[i] or emptySlot
		if isValidItem(chest.slots[i]) then
			chestItemCount = chestItemCount + 1
			print(string.format("[ChestOpen] Chest slot %d: Item %d x%d",
				i, toNumber(chest.slots[i].itemId, 0), toNumber(chest.slots[i].count, 0)))
		end
	end
	print(string.format("[ChestOpen] Sending %d chest items to %s", chestItemCount, player.Name))

	-- Send chest contents, player inventory, and hotbar to player
	EventManager:FireEvent("ChestOpened", player, {
		x = x,
		y = y,
		z = z,
		contents = chestContents,
		playerInventory = playerInventory,
		hotbar = hotbar
	})

	print(string.format("Player %s opened chest at (%d, %d, %d)", player.Name, x, y, z))
end

-- Handle player closing chest
function ChestStorageService:HandleCloseChest(player, data)
	if not data or not data.x or not data.y or not data.z then
		return
	end

	local x, y, z = data.x, data.y, data.z
	local key = self:GetChestKey(x, y, z)
	local chest = self.chests[key]

	if chest then
		-- Return cursor items to player inventory before closing
		local cursorKey = tostring(player.UserId)
		if chest.cursors[cursorKey] and not chest.cursors[cursorKey]:IsEmpty() then
			self:ReturnCursorToInventory(player, chest.cursors[cursorKey])
		end

		-- Clean up cursor and viewer
		chest.cursors[cursorKey] = nil
		chest.viewers[player] = nil
	end

	self.playerViewers[player] = nil

	EventManager:FireEvent("ChestClosed", player, {
		x = x,
		y = y,
		z = z
	})

	print(string.format("Player %s closed chest at (%d, %d, %d)", player.Name, x, y, z))
end

-- Return cursor items to player inventory
function ChestStorageService:ReturnCursorToInventory(player, cursorStack)
	if not self.Deps or not self.Deps.PlayerInventoryService then return end

	local invData = self.Deps.PlayerInventoryService.inventories[player]
	if not invData then return end

	-- Find first empty slot or matching stack with space
	for i = 1, 27 do
		local slot = invData.inventory[i]
		if slot:IsEmpty() then
			-- Place in empty slot
			invData.inventory[i] = cursorStack:Clone()
			return
		elseif slot:GetItemId() == cursorStack:GetItemId() and slot:GetCount() < slot:GetMaxStack() then
			-- Merge with existing stack
			local spaceAvailable = slot:GetMaxStack() - slot:GetCount()
			local amountToAdd = math.min(spaceAvailable, cursorStack:GetCount())
			slot:AddCount(amountToAdd)
			cursorStack:RemoveCount(amountToAdd)

			if cursorStack:IsEmpty() then
				return
			end
		end
	end

	-- If we get here, inventory is full - items are lost (TODO: drop on ground)
	warn(string.format("Could not return %d x%d to %s's inventory - full!",
		cursorStack:GetItemId(), cursorStack:GetCount(), player.Name))
end

--[[ ===================================================================
	NEW SYSTEM: Server-Authoritative Click-Based Chest Interactions
	Client sends click events, server validates and executes actions
	=================================================================== ]]

-- Handle chest slot click (NEW SYSTEM)
function ChestStorageService:HandleChestSlotClick(player, data)
	if not data or not data.chestPosition or not data.slotIndex or not data.clickType then
		warn("Invalid chest slot click from", player.Name)
		return
	end

	-- Anti-duplication: Block chest interactions while teleporting
	local Injector = require(script.Parent.Parent.Injector)
	local playerService = Injector:Resolve("PlayerService")
	if playerService and playerService:IsTeleporting(player) then
		warn(string.format("BLOCKED: Player %s tried to interact with chest while teleporting", player.Name))
		return
	end

    -- Normalize numeric inputs
    local x = tonumber(data.chestPosition.x) or data.chestPosition.x
    local y = tonumber(data.chestPosition.y) or data.chestPosition.y
    local z = tonumber(data.chestPosition.z) or data.chestPosition.z
    local slotIndex = tonumber(data.slotIndex)
    if not slotIndex then
        warn("Invalid slotIndex for chest click from", player.Name)
        return
    end
    data.slotIndex = slotIndex
	local chest = self:GetChest(x, y, z)

	-- Verify player is viewing this chest
	if not chest.viewers[player] then
		warn(player.Name, "tried to interact with chest they're not viewing")
		return
	end

	-- Get player inventory
	if not self.Deps or not self.Deps.PlayerInventoryService then
		warn("PlayerInventoryService not available")
		return
	end

	local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
	local invData = self.Deps.PlayerInventoryService.inventories[player]
	if not invData then return end

	-- Get player's cursor for this chest session
	local cursorKey = tostring(player.UserId)
	local cursor = chest.cursors[cursorKey] or ItemStack.new(0, 0)

	-- Execute the click action
	local success, newSlotStack, newCursor, shouldUpdateInventory

	if data.isChestSlot then
		-- Click on chest slot
		local chestSlot = chest.slots[data.slotIndex]
		if not chestSlot then
			chestSlot = ItemStack.new(0, 0)
		else
			chestSlot = ItemStack.Deserialize(chestSlot)
		end

		success, newSlotStack, newCursor = self:ExecuteSlotClick(chestSlot, cursor, data.clickType)

		if success then
			local serialized = newSlotStack:IsEmpty() and nil or newSlotStack:Serialize()
			chest.slots[data.slotIndex] = serialized
			chest.cursors[cursorKey] = newCursor

			print(string.format("[ChestClick] Updated chest slot %d: %s",
				data.slotIndex,
				serialized and string.format("Item %d x%d (serialized)", serialized.itemId, serialized.count) or "nil (empty)"))
		end
	else
		-- Click on inventory or hotbar slot
		-- Negative slotIndex means hotbar, positive means inventory
		local isHotbarSlot = data.slotIndex < 0
		local actualIndex = isHotbarSlot and -data.slotIndex or data.slotIndex

		local invSlot
		if isHotbarSlot then
			-- Hotbar slot (indices 1-9)
			invSlot = invData.hotbar[actualIndex] or ItemStack.new(0, 0)
		else
			-- Inventory slot (indices 1-27)
			invSlot = invData.inventory[actualIndex] or ItemStack.new(0, 0)
		end

		success, newSlotStack, newCursor = self:ExecuteSlotClick(invSlot, cursor, data.clickType)

		if success then
			if isHotbarSlot then
				invData.hotbar[actualIndex] = newSlotStack
			else
				invData.inventory[actualIndex] = newSlotStack
			end
			chest.cursors[cursorKey] = newCursor
			shouldUpdateInventory = true
		end
	end

	if not success then
		warn("Invalid click action from", player.Name)
		return
	end

	print(string.format("[ChestClick] %s clicked slot %d (%s), success: %s",
		player.Name, data.slotIndex, data.isChestSlot and "chest" or "inventory", tostring(success)))
	print(string.format("[ChestClick] New cursor: %s", newCursor:IsEmpty() and "empty" or
		string.format("Item %d x%d", newCursor:GetItemId(), newCursor:GetCount())))

    -- Send authoritative state back to player (delta-based)
    local emptySlot = ItemStack.new(0, 0):Serialize()

    local chestDelta = {}
    if data.isChestSlot then
        local serialized = (chest.slots[data.slotIndex] or emptySlot)
        chestDelta[data.slotIndex] = serialized
        if serialized then
            print(string.format("[ChestClick] Chest slot %d now has: Item %d x%d",
                data.slotIndex, serialized.itemId or 0, serialized.count or 0))
        end
    end

    local inventoryDelta = {}
    local hotbarDelta = {}
    if shouldUpdateInventory then
        -- Negative slotIndex means hotbar, positive means inventory
        local isHotbarSlot = data.slotIndex < 0
        local actualIndex = isHotbarSlot and -data.slotIndex or data.slotIndex

		if isHotbarSlot then
            local stack = invData.hotbar[actualIndex] or ItemStack.new(0, 0)
			hotbarDelta[actualIndex] = stack:Serialize()
        else
            local stack = invData.inventory[actualIndex] or ItemStack.new(0, 0)
			inventoryDelta[actualIndex] = stack:Serialize()
        end
    end

    EventManager:FireEvent("ChestActionResult", player, {
        chestPosition = {x = x, y = y, z = z},
        chestDelta = chestDelta,
        inventoryDelta = inventoryDelta,
        hotbarDelta = hotbarDelta,
        cursorItem = newCursor:IsEmpty() and nil or newCursor:Serialize()
    })
end

-- Execute click logic (works for both chest and inventory slots)
function ChestStorageService:ExecuteSlotClick(slotStack, cursor, clickType)
	local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

	print(string.format("[ExecuteSlotClick] clickType=%s, cursor=%s, slot=%s",
		clickType,
		cursor:IsEmpty() and "empty" or string.format("Item %d x%d", cursor:GetItemId(), cursor:GetCount()),
		slotStack:IsEmpty() and "empty" or string.format("Item %d x%d", slotStack:GetItemId(), slotStack:GetCount())
	))

	if clickType == "left" then
		if cursor:IsEmpty() then
			-- Pick up entire stack
			if slotStack:IsEmpty() then
				return false -- Can't pick from empty
			end
			print("[ExecuteSlotClick] Picking up entire stack from slot")
			return true, ItemStack.new(0, 0), slotStack:Clone()
		else
			-- Place/merge cursor into slot
			if slotStack:IsEmpty() then
				-- Place entire cursor
				print(string.format("[ExecuteSlotClick] Placing cursor (Item %d x%d) into empty slot",
					cursor:GetItemId(), cursor:GetCount()))
				local newSlot = cursor:Clone()
				print(string.format("[ExecuteSlotClick] New slot will be: Item %d x%d",
					newSlot:GetItemId(), newSlot:GetCount()))
				return true, newSlot, ItemStack.new(0, 0)
			elseif slotStack:GetItemId() == cursor:GetItemId() then
				-- Merge stacks
				local spaceAvailable = slotStack:GetMaxStack() - slotStack:GetCount()
				if spaceAvailable <= 0 then
					return false -- Stack is full
				end

				local amountToAdd = math.min(spaceAvailable, cursor:GetCount())

				local newSlot = slotStack:Clone()
				newSlot:AddCount(amountToAdd)

				local newCursor = cursor:Clone()
				newCursor:RemoveCount(amountToAdd)

				return true, newSlot, newCursor
			else
				-- Swap different items
				return true, cursor:Clone(), slotStack:Clone()
			end
		end
	elseif clickType == "right" then
		if cursor:IsEmpty() then
			-- Pick up half
			if slotStack:IsEmpty() then
				return false -- Can't pick from empty
			end

			local count = slotStack:GetCount()
			local half = math.ceil(count / 2)

			local newSlot = slotStack:Clone()
			newSlot:RemoveCount(half)

			local newCursor = ItemStack.new(slotStack:GetItemId(), half)

			return true, newSlot, newCursor
		else
			-- Place one
			if slotStack:IsEmpty() then
				-- Place one in empty slot
				local newSlot = ItemStack.new(cursor:GetItemId(), 1)
				local newCursor = cursor:Clone()
				newCursor:RemoveCount(1)
				return true, newSlot, newCursor
			elseif slotStack:GetItemId() == cursor:GetItemId() and slotStack:GetCount() < slotStack:GetMaxStack() then
				-- Add one to existing stack
				local newSlot = slotStack:Clone()
				newSlot:AddCount(1)

				local newCursor = cursor:Clone()
				newCursor:RemoveCount(1)

				return true, newSlot, newCursor
			else
				return false -- Can't place (different item or full stack)
			end
		end
	end

	return false -- Unknown click type
end

--[[ ===================================================================
	LEGACY SYSTEM: State-Based Chest Updates (To Be Deprecated)
	=================================================================== ]]

-- Handle chest contents update from client (drag-and-drop)
-- DEPRECATED: Legacy system for compatibility, will be replaced by HandleChestSlotClick
function ChestStorageService:HandleChestContentsUpdate(player, data)
	if not data or not data.x or not data.y or not data.z or not data.contents then
		warn("Invalid chest contents update from", player.Name)
		return
	end

	local x, y, z = data.x, data.y, data.z
	local chest = self:GetChest(x, y, z)

	if not chest.viewers[player] then
		warn("Player", player.Name, "is not viewing chest at", x, y, z)
		return
	end

	local ItemStack = require(game.ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

	-- VALIDATION: Validate chest contents structure
	local valid, reason = InventoryValidator:ValidateInventoryArray(data.contents, 27)
	if not valid then
		warn(string.format("ChestStorageService: Invalid chest contents from %s: %s", player.Name, reason))
		-- Resync correct state to all viewers
		self:SyncChestToViewers(x, y, z)
		return
	end

	-- Get player's current inventory for validation
	local playerInvData = nil
	if self.Deps and self.Deps.PlayerInventoryService then
		playerInvData = self.Deps.PlayerInventoryService.inventories[player]
	end

	if not playerInvData then
		warn(string.format("ChestStorageService: No inventory data for %s", player.Name))
		return
	end

	-- VALIDATION: Check for item duplication between chest and player inventory
	-- Items can only move between containers, not be created
	-- NOTE: Client must send playerInventory in data for proper validation
	local clientInventory = data.playerInventory or {}

	local valid2, reason2 = InventoryValidator:ValidateChestTransaction(
		chest.slots,
		data.contents,
		playerInvData.inventory,
		clientInventory, -- Compare against client's claimed inventory state
		player.Name
	)

	if not valid2 then
		warn(string.format("ChestStorageService: Chest transaction validation failed: %s", reason2))
		warn(string.format("  Potential duplication exploit from %s - rejecting", player.Name))
		-- Resync correct state to all viewers
		self:SyncChestToViewers(x, y, z)
		return
	end

	-- Validation passed - apply changes to chest
	for i = 1, 27 do
		if data.contents[i] then
			local deserialized = ItemStack.Deserialize(data.contents[i])
			if not deserialized:IsEmpty() then
				-- Store full serialized format
				chest.slots[i] = deserialized:Serialize()
			else
				chest.slots[i] = nil
			end
		else
			chest.slots[i] = nil
		end
	end

	-- Apply inventory changes from transaction to player's actual inventory
	-- This ensures the transaction is atomic on the server side
	if playerInvData and clientInventory then
		for i = 1, 27 do
			if clientInventory[i] then
				local deserialized = ItemStack.Deserialize(clientInventory[i])
				playerInvData.inventory[i] = deserialized
			else
				playerInvData.inventory[i] = ItemStack.new(0, 0)
			end
		end
	end

	-- Apply hotbar changes from transaction to player's actual hotbar
	local clientHotbar = data.hotbar or {}
	if playerInvData and clientHotbar then
		for i = 1, 9 do
			if clientHotbar[i] then
				local deserialized = ItemStack.Deserialize(clientHotbar[i])
				playerInvData.hotbar[i] = deserialized
			else
				playerInvData.hotbar[i] = ItemStack.new(0, 0)
			end
		end
	end

	-- Get updated player inventory (now reflects the transaction)
	local playerInventory = {}
	if playerInvData then
		for i = 1, 27 do
			local stack = playerInvData.inventory[i]
			if stack and stack:GetItemId() > 0 then
				playerInventory[i] = stack:Serialize()
			end
		end
	end

	-- Get updated hotbar
	local hotbar = {}
	if playerInvData then
		for i = 1, 9 do
			local stack = playerInvData.hotbar[i]
			if stack and stack:GetItemId() > 0 then
				hotbar[i] = stack:Serialize()
			end
		end
	end

	-- Notify all viewers
	for viewer in pairs(chest.viewers) do
		EventManager:FireEvent("ChestUpdated", viewer, {
			x = x, y = y, z = z,
			contents = chest.slots,
			playerInventory = playerInventory,
			hotbar = hotbar
		})
	end

	print(string.format("Player %s updated chest at (%d,%d,%d) [VALIDATED]", player.Name, x, y, z))
end

-- Handle player inventory update from chest UI
function ChestStorageService:HandlePlayerInventoryUpdate(player, data)
	if not data or not data.inventory then
		warn("Invalid player inventory update from", player.Name)
		return
	end

	if not self.Deps or not self.Deps.PlayerInventoryService then
		warn("PlayerInventoryService not available")
		return
	end

	local inventoryService = self.Deps.PlayerInventoryService
	local invData = inventoryService.inventories[player]
	if not invData then
		warn("No inventory data for player", player.Name)
		return
	end

	local ItemStack = require(game.ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

	-- VALIDATION: Validate inventory structure
	local valid, reason = InventoryValidator:ValidateInventoryArray(data.inventory, 27)
	if not valid then
		warn(string.format("ChestStorageService: Invalid inventory update from %s: %s", player.Name, reason))
		-- Resync correct state
		inventoryService:SyncInventoryToClient(player)
		return
	end

	-- VALIDATION: Check for duplication between chest and inventory
	local viewingChest = self.playerViewers[player]
	if viewingChest then
		local chest = self:GetChest(viewingChest.x, viewingChest.y, viewingChest.z)
		if chest then
			local valid2, reason2 = InventoryValidator:ValidateChestTransaction(
				chest.slots,
				chest.slots, -- Chest unchanged in this operation
				invData.inventory,
				data.inventory,
				player.Name
			)

			if not valid2 then
				warn(string.format("ChestStorageService: Inventory transaction validation failed: %s", reason2))
				warn(string.format("  Potential exploit from %s - rejecting", player.Name))
				-- Resync correct state
				inventoryService:SyncInventoryToClient(player)
				self:SyncChestToViewers(viewingChest.x, viewingChest.y, viewingChest.z)
				return
			end
		end
	end

	-- Validation passed - update player inventory from client data
	for i = 1, 27 do
		if data.inventory[i] then
			invData.inventory[i] = ItemStack.Deserialize(data.inventory[i])
		else
			invData.inventory[i] = ItemStack.new(0, 0)
		end
	end

	-- Sync to client
	inventoryService:SyncInventoryToClient(player)

	-- If player is viewing a chest, notify all viewers of the chest
	if viewingChest then
		local chest = self:GetChest(viewingChest.x, viewingChest.y, viewingChest.z)
		if chest then
			local playerInventory = {}
			for i = 1, 27 do
				local stack = invData.inventory[i]
				if stack and stack:GetItemId() > 0 then
					playerInventory[i] = stack:Serialize()
				end
			end

			for viewer in pairs(chest.viewers) do
				EventManager:FireEvent("ChestUpdated", viewer, {
					x = viewingChest.x, y = viewingChest.y, z = viewingChest.z,
					contents = chest.slots,
					playerInventory = playerInventory
				})
			end
		end
	end

	print(string.format("Player %s updated inventory from chest UI [VALIDATED]", player.Name))
end

-- Handle item transfer (deposit/withdraw) - DEPRECATED in favor of drag-and-drop
function ChestStorageService:HandleItemTransfer(player, data)
	if not data or not data.chestPos then
		warn("Invalid chest transfer request from", player.Name)
		return
	end

    local x = tonumber(data.chestPos.x) or data.chestPos.x
    local y = tonumber(data.chestPos.y) or data.chestPos.y
    local z = tonumber(data.chestPos.z) or data.chestPos.z
    local fromSlot = tonumber(data.fromSlot)
    if not fromSlot then
        warn("Invalid fromSlot in chest transfer from", player.Name)
        return
    end
    local isDeposit = data.isDeposit -- true = player->chest, false = chest->player

	local chest = self:GetChest(x, y, z)

	if not self.Deps or not self.Deps.PlayerInventoryService then
		warn("PlayerInventoryService not available")
		return
	end

	local inventoryService = self.Deps.PlayerInventoryService
	local invData = inventoryService.inventories[player]
	if not invData then
		warn("No inventory data for player", player.Name)
		return
	end

	local ItemStack = require(game.ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

	if isDeposit then
		-- Transfer from player to chest
		local sourceSlots = fromSlot > 27 and invData.hotbar or invData.inventory
		local adjustedSlot = fromSlot > 27 and (fromSlot - 27) or fromSlot

		local itemStack = sourceSlots[adjustedSlot]
		if not itemStack or itemStack:GetItemId() == 0 then
			return -- Nothing to deposit
		end

		-- Find empty chest slot
		local targetSlot = nil
		for i = 1, 27 do
			local slotData = chest.slots[i]
			if not isValidItem(slotData) then
				targetSlot = i
				break
			end
		end

		if not targetSlot then
			print("Chest is full!")
			return
		end

		-- Transfer item (store in serialized format)
		chest.slots[targetSlot] = itemStack:Serialize()

		-- Remove from player inventory
		sourceSlots[adjustedSlot] = ItemStack.new(0, 0)

		print(string.format("Player %s deposited item %d (x%d) to chest slot %d",
			player.Name, itemStack:GetItemId(), itemStack:GetCount(), targetSlot))
	else
		-- Transfer from chest to player
		local itemData = chest.slots[fromSlot]
		if not isValidItem(itemData) then
			return -- Nothing to withdraw
		end

		-- Find empty player inventory slot
		local targetSlot = nil
		for i = 1, 27 do
			local stack = invData.inventory[i]
			if not stack or stack:GetItemId() == 0 then
				targetSlot = i
				break
			end
		end

		if not targetSlot then
			print("Player inventory is full!")
			return
		end

		-- Transfer item (deserialize from stored format)
		invData.inventory[targetSlot] = ItemStack.Deserialize(itemData)

		-- Remove from chest
		chest.slots[fromSlot] = nil

		print(string.format("Player %s withdrew item %d (x%d) from chest slot %d",
			player.Name, itemData.itemId, itemData.count, fromSlot))
	end

	-- Sync player inventory to client
	inventoryService:SyncInventoryToClient(player)

	-- Get updated player inventory
	local playerInventory = {}
	for i = 1, 27 do
		local stack = invData.inventory[i]
		if stack and stack:GetItemId() > 0 then
			playerInventory[i] = stack:Serialize()
		end
	end

	-- Notify all viewers of the chest update
	for viewer in pairs(chest.viewers) do
		EventManager:FireEvent("ChestUpdated", viewer, {
			x = x,
			y = y,
			z = z,
			contents = chest.slots,
			playerInventory = playerInventory
		})
	end
end

-- Remove chest when block is broken
function ChestStorageService:RemoveChest(x, y, z)
	local key = self:GetChestKey(x, y, z)
	local chest = self.chests[key]

	if chest then
		-- Close chest for all viewers
		for viewer in pairs(chest.viewers) do
			self:HandleCloseChest(viewer, {x = x, y = y, z = z})
		end

		-- Drop items on ground when chest is broken
		-- TODO: Implement item entity spawning when that system is ready
		-- For now, just log what would be dropped
		local itemsToLog = {}
		for i, slotData in pairs(chest.slots) do
			if isValidItem(slotData) then
				table.insert(itemsToLog, string.format("Slot %d: Item %d x%d", toNumber(i, 0), toNumber(slotData.itemId, 0), toNumber(slotData.count, 0)))
			end
		end

		if #itemsToLog > 0 then
			print(string.format("Chest at (%d, %d, %d) broken with items:", x, y, z))
			for _, itemStr in ipairs(itemsToLog) do
				print("  - " .. itemStr)
			end
			print("  (Items would be dropped when item entity system is implemented)")
		end

		-- Remove chest data
		self.chests[key] = nil
		print(string.format("Removed chest at (%d, %d, %d)", x, y, z))
	end
end

-- Sync chest state to all viewers (for rollback on validation failure)
function ChestStorageService:SyncChestToViewers(x, y, z)
	local chest = self:GetChest(x, y, z)
	if not chest then return end

	for viewer in pairs(chest.viewers) do
		-- Get viewer's inventory
		local playerInventory = {}
		if self.Deps and self.Deps.PlayerInventoryService then
			local invData = self.Deps.PlayerInventoryService.inventories[viewer]
			if invData then
				for i = 1, 27 do
					local stack = invData.inventory[i]
					if stack and stack:GetItemId() > 0 then
						playerInventory[i] = stack:Serialize()
					end
				end
			end
		end

		EventManager:FireEvent("ChestUpdated", viewer, {
			x = x,
			y = y,
			z = z,
			contents = chest.slots,
			playerInventory = playerInventory
		})
	end

	print(string.format("Synced chest at (%d,%d,%d) to %d viewer(s)", x, y, z, #chest.viewers))
end

-- Handle player disconnect
function ChestStorageService:OnPlayerRemoved(player)
	local viewingChest = self.playerViewers[player]
	if viewingChest then
		self:HandleCloseChest(player, viewingChest)
	end
end

-- Count chests in memory
function ChestStorageService:CountChests()
	local count = 0
	for _ in pairs(self.chests) do
		count = count + 1
	end
	return count
end

-- Save chest data (called by world save)
function ChestStorageService:SaveChestData()
	local chestData = {}

	print("[SaveChestData] Starting chest save...")
	print(string.format("[SaveChestData] Total chests in memory: %d", self:CountChests()))

	for _, chest in pairs(self.chests) do
		-- Only save chests that have items
		local hasItems = false
		local itemCount = 0
		for _, slot in pairs(chest.slots) do
			if isValidItem(slot) then
				hasItems = true
				itemCount = itemCount + 1
			end
		end

		print(string.format("[SaveChestData] Chest at (%d,%d,%d): %d items, hasItems=%s",
			chest.x, chest.y, chest.z, itemCount, tostring(hasItems)))

		if hasItems then
			local chestToSave = {
				x = chest.x,
				y = chest.y,
				z = chest.z,
				slots = chest.slots -- Already in serialized format
			}
			table.insert(chestData, chestToSave)
			print(string.format("[SaveChestData] ✅ Saving chest at (%d,%d,%d) with %d items",
				chest.x, chest.y, chest.z, itemCount))
		else
			print(string.format("[SaveChestData] ⏭️ Skipping empty chest at (%d,%d,%d)",
				chest.x, chest.y, chest.z))
		end
	end

	print(string.format("[SaveChestData] Final result: %d chests to save", #chestData))
	return chestData
end

-- Load chest data (called on world load)
function ChestStorageService:LoadChestData(chestData)
	if not chestData then return end

	print("[LoadChestData] Starting chest load...")
	print(string.format("[LoadChestData] Received %d chests to load", #chestData))

	local ItemStack = require(game.ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

	for _, data in ipairs(chestData) do
		local key = self:GetChestKey(data.x, data.y, data.z)
		print(string.format("[LoadChestData] Loading chest at (%d,%d,%d), key=%s", data.x, data.y, data.z, key))

		local chest = self:GetChest(data.x, data.y, data.z)
		local loadedSlots = 0

		print(string.format("[LoadChestData]   Chest.slots table address BEFORE load: %s", tostring(chest.slots)))

		-- Migrate old format {id, count} to new format {itemId, count, maxStack, metadata}
		if data.slots then
			print(string.format("[LoadChestData]   DEBUG: data.slots type=%s, #data.slots=%d", type(data.slots), #data.slots))
			for i, slotData in pairs(data.slots) do
				-- IMPORTANT: Convert slot index to number if it's a string
				local slotIndex = tonumber(i) or i
				print(string.format("[LoadChestData]   DEBUG: Processing slot %s (converted to %s), slotData type=%s", tostring(i), tostring(slotIndex), type(slotData)))
				if slotData then
					-- Check if old format (uses 'id' instead of 'itemId')
					if slotData.id and not slotData.itemId then
						-- Convert old format to new format
						local stack = ItemStack.new(slotData.id, slotData.count)
						local serialized = stack:Serialize()
						chest.slots[slotIndex] = serialized
						print(string.format("[LoadChestData]   Slot %d: Item %d x%d (migrated from old format)",
							slotIndex, slotData.id, slotData.count))
						print(string.format("[LoadChestData]   DEBUG: Serialized data - itemId=%s, count=%s",
							tostring(serialized.itemId), tostring(serialized.count)))
						loadedSlots = loadedSlots + 1
					else
						-- Already in new format or proper serialized format
						chest.slots[slotIndex] = slotData
						print(string.format("[LoadChestData]   Slot %d: Loading slotData with itemId=%s, count=%s",
							slotIndex, tostring(slotData.itemId), tostring(slotData.count)))
						if isValidItem(slotData) then
							print(string.format("[LoadChestData]   ✅ Slot %d: Item %d x%d",
								slotIndex, toNumber(slotData.itemId, 0), toNumber(slotData.count, 0)))
							loadedSlots = loadedSlots + 1
						else
							print(string.format("[LoadChestData]   ⚠️ Slot %d has no valid itemId (itemId=%s)",
								slotIndex, tostring(slotData.itemId)))
						end
					end
				else
					print(string.format("[LoadChestData]   DEBUG: Slot %s is nil", tostring(i)))
				end
			end
		else
			print("[LoadChestData]   ⚠️ No slots data found in saved chest!")
		end

		print(string.format("[LoadChestData]   Chest.slots table address AFTER load: %s", tostring(chest.slots)))
		print("[LoadChestData]   Verifying loaded data in chest.slots:")
		local verifiedCount = 0
		for i = 1, 27 do
			if chest.slots[i] then
				print(string.format("[LoadChestData]     ✅ Slot %d exists: itemId=%s, count=%s",
					i, tostring(chest.slots[i].itemId), tostring(chest.slots[i].count)))
				verifiedCount = verifiedCount + 1
			end
		end
		print(string.format("[LoadChestData]   Verification complete: Found %d slots with data", verifiedCount))

		print(string.format("[LoadChestData] ✅ Loaded chest at (%d,%d,%d) with %d items",
			data.x, data.y, data.z, loadedSlots))
	end

	print(string.format("[LoadChestData] Completed: Loaded %d chests", #chestData))
end

return ChestStorageService

