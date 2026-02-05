--[[
	FurnaceService.lua
	Server-side Minecraft-style auto-smelting furnace system
	
	Features:
	- 3 slots: Input, Fuel, Output
	- Auto-smelts while UI is closed (server tick)
	- Fuel consumption over time
	- Persistent furnace state per position
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local FurnaceConfig = require(ReplicatedStorage.Configs.FurnaceConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

local FurnaceService = setmetatable({}, BaseService)
FurnaceService.__index = FurnaceService

-- Slot indices for furnace
local SLOT_INPUT = 1
local SLOT_FUEL = 2
local SLOT_OUTPUT = 3

function FurnaceService.new()
	local self = setmetatable(BaseService.new(), FurnaceService)
	
	self._logger = Logger:CreateContext("FurnaceService")
	self.Deps = nil -- Injected by ServiceManager
	
	-- Furnace state storage: {[key] = FurnaceState}
	-- FurnaceState = {
	--   inputSlot: ItemStack,
	--   fuelSlot: ItemStack,
	--   outputSlot: ItemStack,
	--   fuelBurnTimeRemaining: number (seconds),
	--   currentSmeltProgress: number (0-1),
	--   viewers: {[Player] = true},
	--   cursors: {[UserId] = ItemStack},
	--   lastTick: number
	-- }
	self.furnaces = {}
	
	-- Track which furnace each player is viewing
	self.playerViewers = {} -- {[Player] = {x, y, z}}
	
	-- Tick connection
	self.tickConnection = nil
	self.lastTickTime = 0
	
	return self
end

function FurnaceService:Init()
	if self._initialized then return end
	BaseService.Init(self)
	self._logger.Debug("FurnaceService initialized")
end

function FurnaceService:Start()
	if self._started then return end
	BaseService.Start(self)
	
	-- Start furnace tick loop
	self:StartTickLoop()
	
	self._logger.Debug("FurnaceService started")
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TICK LOOP (Auto-smelting)
-- ═══════════════════════════════════════════════════════════════════════════

function FurnaceService:StartTickLoop()
	self.lastTickTime = tick()
	
	self.tickConnection = RunService.Heartbeat:Connect(function()
		local now = tick()
		local deltaTime = now - self.lastTickTime
		
		-- Only tick at configured rate
		if deltaTime >= FurnaceConfig.TICK_RATE then
			self:TickAllFurnaces(deltaTime)
			self.lastTickTime = now
		end
	end)
end

function FurnaceService:TickAllFurnaces(deltaTime)
	for key, furnace in pairs(self.furnaces) do
		self:TickFurnace(key, furnace, deltaTime)
	end
end

function FurnaceService:TickFurnace(key, furnace, deltaTime)
	local wasActive = furnace.fuelBurnTimeRemaining > 0 or furnace.currentSmeltProgress > 0
	local stateChanged = false
	
	-- Check if we can smelt
	local canSmelt = self:CanSmelt(furnace)
	
	-- If we have fuel burning and can smelt, continue smelting
	if furnace.fuelBurnTimeRemaining > 0 then
		-- Burn fuel
		furnace.fuelBurnTimeRemaining = math.max(0, furnace.fuelBurnTimeRemaining - deltaTime)
		stateChanged = true
		
		-- Progress smelting if we have input
		if canSmelt then
			local progressIncrement = deltaTime / FurnaceConfig.SMELT_TIME
			furnace.currentSmeltProgress = furnace.currentSmeltProgress + progressIncrement
			
			-- Check if smelt is complete
			if furnace.currentSmeltProgress >= 1 then
				self:CompleteSmelting(furnace)
				furnace.currentSmeltProgress = 0
			end
		end
	elseif canSmelt then
		-- No fuel burning, try to consume new fuel
		if self:ConsumeFuel(furnace) then
			stateChanged = true
		end
	else
		-- Can't smelt, reset progress
		if furnace.currentSmeltProgress > 0 then
			furnace.currentSmeltProgress = 0
			stateChanged = true
		end
	end
	
	-- Notify viewers if state changed
	if stateChanged then
		self:NotifyViewers(key, furnace)
	end
end

function FurnaceService:CanSmelt(furnace)
	-- Check if we have smeltable input
	local inputStack = furnace.inputSlot
	if not inputStack or inputStack:IsEmpty() then
		return false
	end
	
	local inputItemId = inputStack:GetItemId()
	if not FurnaceConfig:IsSmeltable(inputItemId) then
		return false
	end
	
	-- Check if output has room
	local outputItemId = FurnaceConfig:GetSmeltOutput(inputItemId)
	local outputStack = furnace.outputSlot
	
	if outputStack and not outputStack:IsEmpty() then
		-- Output must match and have room
		if outputStack:GetItemId() ~= outputItemId then
			return false
		end
		if outputStack:IsFull() then
			return false
		end
	end
	
	-- Check if we have fuel (burning or available)
	if furnace.fuelBurnTimeRemaining <= 0 then
		local fuelStack = furnace.fuelSlot
		if not fuelStack or fuelStack:IsEmpty() then
			return false
		end
		if not FurnaceConfig:IsFuel(fuelStack:GetItemId()) then
			return false
		end
	end
	
	return true
end

function FurnaceService:ConsumeFuel(furnace)
	local fuelStack = furnace.fuelSlot
	if not fuelStack or fuelStack:IsEmpty() then
		return false
	end
	
	local fuelItemId = fuelStack:GetItemId()
	local burnTime = FurnaceConfig:GetFuelBurnTime(fuelItemId)
	if not burnTime then
		return false
	end
	
	-- Consume one fuel item
	fuelStack:RemoveCount(1)
	furnace.fuelBurnTimeRemaining = burnTime
	
	self._logger.Debug("Consumed fuel", {itemId = fuelItemId, burnTime = burnTime})
	return true
end

function FurnaceService:CompleteSmelting(furnace)
	local inputStack = furnace.inputSlot
	if not inputStack or inputStack:IsEmpty() then
		return false
	end
	
	local inputItemId = inputStack:GetItemId()
	local outputItemId = FurnaceConfig:GetSmeltOutput(inputItemId)
	if not outputItemId then
		return false
	end
	
	-- Consume input
	inputStack:RemoveCount(1)
	
	-- Add to output
	local outputStack = furnace.outputSlot
	if outputStack and not outputStack:IsEmpty() then
		outputStack:AddCount(1)
	else
		furnace.outputSlot = ItemStack.new(outputItemId, 1)
	end
	
	self._logger.Debug("Smelting complete", {
		input = inputItemId,
		output = outputItemId
	})
	
	return true
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FURNACE STATE MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

function FurnaceService:GetFurnaceKey(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

function FurnaceService:GetFurnace(x, y, z)
	local key = self:GetFurnaceKey(x, y, z)
	
	if not self.furnaces[key] then
		-- Create new furnace state
		self.furnaces[key] = {
			x = x,
			y = y,
			z = z,
			inputSlot = ItemStack.new(0, 0),
			fuelSlot = ItemStack.new(0, 0),
			outputSlot = ItemStack.new(0, 0),
			fuelBurnTimeRemaining = 0,
			currentSmeltProgress = 0,
			viewers = {},
			cursors = {},
			lastTick = tick()
		}
		self._logger.Debug("Created new furnace state", {x = x, y = y, z = z})
	end
	
	return self.furnaces[key]
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════

--[[
	Handle request to open furnace
	@param player: Player
	@param data: {x, y, z}
]]
function FurnaceService:HandleOpenFurnace(player, data)
	if not player or not data then
		self._logger.Warn("Invalid open furnace request")
		return
	end
	
	local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
	if not x or not y or not z then
		self._logger.Warn("Missing furnace position")
		return
	end
	
	-- Verify block is a furnace
	if not self:ValidateFurnaceBlock(x, y, z) then
		self._logger.Warn("Invalid furnace block", {x = x, y = y, z = z})
		return
	end
	
	-- Verify player distance
	if not self:ValidatePlayerDistance(player, x, y, z) then
		self._logger.Warn("Player too far from furnace")
		return
	end
	
	-- Get furnace state
	local furnace = self:GetFurnace(x, y, z)
	local key = self:GetFurnaceKey(x, y, z)
	
	-- Add player as viewer
	furnace.viewers[player] = true
	self.playerViewers[player] = {x = x, y = y, z = z}
	
	-- Initialize cursor for this player
	furnace.cursors[tostring(player.UserId)] = ItemStack.new(0, 0)
	
	-- Get player inventory
	local playerInventory, hotbar = self:GetPlayerInventoryData(player)
	
	-- Calculate fuel bar percentage
	local maxFuelTime = self:GetMaxFuelTime(furnace)
	local fuelPercentage = maxFuelTime > 0 and (furnace.fuelBurnTimeRemaining / maxFuelTime) or 0
	
	-- Send furnace state to client
	EventManager:FireEvent("FurnaceOpened", player, {
		x = x,
		y = y,
		z = z,
		inputSlot = furnace.inputSlot:Serialize(),
		fuelSlot = furnace.fuelSlot:Serialize(),
		outputSlot = furnace.outputSlot:Serialize(),
		fuelBurnTimeRemaining = furnace.fuelBurnTimeRemaining,
		fuelPercentage = fuelPercentage,
		smeltProgress = furnace.currentSmeltProgress,
		playerInventory = playerInventory,
		hotbar = hotbar
	})
	
	self._logger.Debug("Furnace opened", {player = player.Name, pos = key})
end

--[[
	Handle furnace slot click (server-authoritative)
	@param player: Player
	@param data: {furnacePos, slotType, clickType}
]]
function FurnaceService:HandleFurnaceSlotClick(player, data)
	if not player or not data then return end
	
	local pos = data.furnacePos
	if not pos then return end
	
	local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
	local key = self:GetFurnaceKey(x, y, z)
	local furnace = self.furnaces[key]
	
	if not furnace then
		self._logger.Warn("Furnace not found for slot click")
		return
	end
	
	-- Verify player is viewing this furnace
	local viewing = self.playerViewers[player]
	if not viewing or viewing.x ~= x or viewing.y ~= y or viewing.z ~= z then
		self._logger.Warn("Player not viewing this furnace")
		return
	end
	
	local slotType = data.slotType -- "input", "fuel", "output", "inventory", "hotbar"
	local slotIndex = data.slotIndex -- For inventory/hotbar
	local clickType = data.clickType -- "left" or "right"
	
	-- Get cursor
	local cursorKey = tostring(player.UserId)
	local cursor = furnace.cursors[cursorKey] or ItemStack.new(0, 0)
	
	-- Get player inventory
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	
	if not playerInv then
		self._logger.Error("Player inventory not found")
		return
	end
	
	-- Handle click based on slot type
	if slotType == "input" then
		cursor = self:HandleSlotInteraction(furnace.inputSlot, cursor, clickType, "input")
		furnace.inputSlot = furnace.inputSlot -- Ensure reference updated
	elseif slotType == "fuel" then
		cursor = self:HandleSlotInteraction(furnace.fuelSlot, cursor, clickType, "fuel")
	elseif slotType == "output" then
		cursor = self:HandleOutputSlotClick(furnace.outputSlot, cursor, clickType)
	elseif slotType == "inventory" and slotIndex then
		local idx = tonumber(slotIndex)
		if idx and idx >= 1 and idx <= 27 then
			cursor = self:HandleSlotInteraction(playerInv.inventory[idx], cursor, clickType, nil)
		end
	elseif slotType == "hotbar" and slotIndex then
		local idx = tonumber(slotIndex)
		if idx and idx >= 1 and idx <= 9 then
			cursor = self:HandleSlotInteraction(playerInv.hotbar[idx], cursor, clickType, nil)
		end
	end
	
	-- Update cursor
	furnace.cursors[cursorKey] = cursor
	
	-- Send update to client
	self:SendFurnaceActionResult(player, furnace, playerInv, cursor)
end

--[[
	Handle slot interaction (Minecraft-style click logic)
	@param slot: ItemStack - The slot being clicked
	@param cursor: ItemStack - Item on cursor
	@param clickType: "left" | "right"
	@param slotRestriction: "input" | "fuel" | nil - Slot type restriction
	@return: ItemStack - Updated cursor
]]
function FurnaceService:HandleSlotInteraction(slot, cursor, clickType, slotRestriction)
	-- Validate slot restriction
	if slotRestriction and not cursor:IsEmpty() then
		local cursorItemId = cursor:GetItemId()
		if slotRestriction == "input" and not FurnaceConfig:IsSmeltable(cursorItemId) then
			-- Can't place non-smeltable item in input slot
			return cursor
		elseif slotRestriction == "fuel" and not FurnaceConfig:IsFuel(cursorItemId) then
			-- Can't place non-fuel item in fuel slot
			return cursor
		end
	end
	
	if clickType == "left" then
		if cursor:IsEmpty() then
			-- Pick up entire stack
			if not slot:IsEmpty() then
				local newCursor = slot:Clone()
				slot:Clear()
				return newCursor
			end
		else
			-- Place/merge/swap
			if slot:IsEmpty() then
				-- Place cursor into empty slot
				slot:SetItem(cursor:GetItemId(), cursor:GetCount())
				return ItemStack.new(0, 0)
			elseif cursor:CanStack(slot) then
				-- Merge stacks
				slot:Merge(cursor)
				return cursor
			else
				-- Swap
				local temp = slot:Clone()
				slot:SetItem(cursor:GetItemId(), cursor:GetCount())
				return temp
			end
		end
	elseif clickType == "right" then
		if cursor:IsEmpty() then
			-- Pick up half
			if not slot:IsEmpty() then
				return slot:SplitHalf()
			end
		else
			-- Place one
			if slot:IsEmpty() then
				slot:SetItem(cursor:GetItemId(), 1)
				cursor:RemoveCount(1)
			elseif cursor:CanStack(slot) and not slot:IsFull() then
				slot:AddCount(1)
				cursor:RemoveCount(1)
			end
		end
	end
	
	return cursor
end

--[[
	Handle output slot click (output only - can only take, not place)
]]
function FurnaceService:HandleOutputSlotClick(slot, cursor, clickType)
	if slot:IsEmpty() then
		return cursor
	end
	
	if cursor:IsEmpty() then
		if clickType == "left" then
			-- Take entire stack
			local newCursor = slot:Clone()
			slot:Clear()
			return newCursor
		else
			-- Take half
			return slot:SplitHalf()
		end
	elseif cursor:CanStack(slot) then
		-- Add to cursor stack
		local spaceLeft = cursor:GetRemainingSpace()
		if clickType == "left" then
			local toTake = math.min(spaceLeft, slot:GetCount())
			cursor:AddCount(toTake)
			slot:RemoveCount(toTake)
		else
			if spaceLeft > 0 then
				cursor:AddCount(1)
				slot:RemoveCount(1)
			end
		end
	end
	
	return cursor
end

--[[
	Handle quick transfer (shift-click)
]]
function FurnaceService:HandleFurnaceQuickTransfer(player, data)
	if not player or not data then return end
	
	local pos = data.furnacePos
	if not pos then return end
	
	local x, y, z = tonumber(pos.x), tonumber(pos.y), tonumber(pos.z)
	local key = self:GetFurnaceKey(x, y, z)
	local furnace = self.furnaces[key]
	
	if not furnace then return end
	
	local slotType = data.slotType
	local slotIndex = data.slotIndex
	
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return end
	
	local cursor = furnace.cursors[tostring(player.UserId)] or ItemStack.new(0, 0)
	
	if slotType == "input" then
		self:QuickTransferToInventory(furnace.inputSlot, playerInv)
	elseif slotType == "fuel" then
		self:QuickTransferToInventory(furnace.fuelSlot, playerInv)
	elseif slotType == "output" then
		self:QuickTransferToInventory(furnace.outputSlot, playerInv)
	elseif slotType == "inventory" and slotIndex then
		local idx = tonumber(slotIndex)
		if idx and idx >= 1 and idx <= 27 then
			local stack = playerInv.inventory[idx]
			if stack and not stack:IsEmpty() then
				self:QuickTransferToFurnace(stack, furnace)
			end
		end
	elseif slotType == "hotbar" and slotIndex then
		local idx = tonumber(slotIndex)
		if idx and idx >= 1 and idx <= 9 then
			local stack = playerInv.hotbar[idx]
			if stack and not stack:IsEmpty() then
				self:QuickTransferToFurnace(stack, furnace)
			end
		end
	end
	
	self:SendFurnaceActionResult(player, furnace, playerInv, cursor)
end

function FurnaceService:QuickTransferToInventory(fromSlot, playerInv)
	if fromSlot:IsEmpty() then return end
	
	local itemId = fromSlot:GetItemId()
	local count = fromSlot:GetCount()
	
	-- Try to merge with existing stacks in hotbar first
	for i = 1, 9 do
		if count <= 0 then break end
		local slot = playerInv.hotbar[i]
		if slot and slot:GetItemId() == itemId and not slot:IsFull() then
			local space = slot:GetRemainingSpace()
			local toAdd = math.min(space, count)
			slot:AddCount(toAdd)
			count = count - toAdd
		end
	end
	
	-- Then inventory
	for i = 1, 27 do
		if count <= 0 then break end
		local slot = playerInv.inventory[i]
		if slot and slot:GetItemId() == itemId and not slot:IsFull() then
			local space = slot:GetRemainingSpace()
			local toAdd = math.min(space, count)
			slot:AddCount(toAdd)
			count = count - toAdd
		end
	end
	
	-- Then empty slots in hotbar
	for i = 1, 9 do
		if count <= 0 then break end
		local slot = playerInv.hotbar[i]
		if slot and slot:IsEmpty() then
			local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(maxStack, count)
			playerInv.hotbar[i] = ItemStack.new(itemId, toAdd)
			count = count - toAdd
		end
	end
	
	-- Then empty slots in inventory
	for i = 1, 27 do
		if count <= 0 then break end
		local slot = playerInv.inventory[i]
		if slot and slot:IsEmpty() then
			local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(maxStack, count)
			playerInv.inventory[i] = ItemStack.new(itemId, toAdd)
			count = count - toAdd
		end
	end
	
	-- Update source slot
	local transferred = fromSlot:GetCount() - count
	fromSlot:RemoveCount(transferred)
end

function FurnaceService:QuickTransferToFurnace(fromSlot, furnace)
	if fromSlot:IsEmpty() then return end
	
	local itemId = fromSlot:GetItemId()
	
	-- Determine target slot based on item type
	local targetSlot = nil
	if FurnaceConfig:IsSmeltable(itemId) then
		targetSlot = furnace.inputSlot
	elseif FurnaceConfig:IsFuel(itemId) then
		targetSlot = furnace.fuelSlot
	else
		return -- Can't go in furnace
	end
	
	-- Transfer to target slot
	if targetSlot:IsEmpty() then
		targetSlot:SetItem(itemId, fromSlot:GetCount())
		fromSlot:Clear()
	elseif targetSlot:GetItemId() == itemId and not targetSlot:IsFull() then
		local space = targetSlot:GetRemainingSpace()
		local toAdd = math.min(space, fromSlot:GetCount())
		targetSlot:AddCount(toAdd)
		fromSlot:RemoveCount(toAdd)
	end
end

--[[
	Handle close furnace
]]
function FurnaceService:HandleCloseFurnace(player, data)
	if not player then return end
	
	local viewing = self.playerViewers[player]
	if not viewing then return end
	
	local key = self:GetFurnaceKey(viewing.x, viewing.y, viewing.z)
	local furnace = self.furnaces[key]
	
	if furnace then
		-- Return cursor items to player inventory
		local cursorKey = tostring(player.UserId)
		local cursor = furnace.cursors[cursorKey]
		
		if cursor and not cursor:IsEmpty() then
			local invService = self.Deps and self.Deps.PlayerInventoryService
			local playerInv = invService and invService.inventories[player]
			if playerInv then
				self:QuickTransferToInventory(cursor, playerInv)
				invService:SyncInventoryToClient(player)
			end
		end
		
		-- Remove viewer
		furnace.viewers[player] = nil
		furnace.cursors[cursorKey] = nil
	end
	
	self.playerViewers[player] = nil
	
	self._logger.Debug("Furnace closed", {player = player.Name})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function FurnaceService:ValidateFurnaceBlock(x, y, z)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws or not vws.worldManager then
		return false
	end
	
	local blockId = vws.worldManager:GetBlock(x, y, z)
	return blockId == Constants.BlockType.FURNACE
end

function FurnaceService:ValidatePlayerDistance(player, x, y, z)
	local character = player.Character
	if not character then return false end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return false end
	
	local bs = Constants.BLOCK_SIZE
	local furnaceCenter = Vector3.new(
		x * bs + bs / 2,
		y * bs + bs / 2,
		z * bs + bs / 2
	)
	
	local distance = (rootPart.Position - furnaceCenter).Magnitude
	return distance <= FurnaceConfig.MAX_INTERACTION_DISTANCE
end

function FurnaceService:GetMaxFuelTime(furnace)
	local fuelStack = furnace.fuelSlot
	if fuelStack and not fuelStack:IsEmpty() then
		local burnTime = FurnaceConfig:GetFuelBurnTime(fuelStack:GetItemId())
		return burnTime or 80 -- Default to coal burn time
	end
	return 80 -- Default
end

function FurnaceService:GetPlayerInventoryData(player)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	
	local emptySlot = ItemStack.new(0, 0):Serialize()
	local inventory = {}
	local hotbar = {}
	
	if playerInv then
		for i = 1, 27 do
			local stack = playerInv.inventory[i]
			inventory[i] = (stack and not stack:IsEmpty()) and stack:Serialize() or emptySlot
		end
		for i = 1, 9 do
			local stack = playerInv.hotbar[i]
			hotbar[i] = (stack and not stack:IsEmpty()) and stack:Serialize() or emptySlot
		end
	end
	
	return inventory, hotbar
end

function FurnaceService:SendFurnaceActionResult(player, furnace, playerInv, cursor)
	local emptySlot = ItemStack.new(0, 0):Serialize()
	
	-- Build inventory data
	local inventory = {}
	local hotbar = {}
	for i = 1, 27 do
		local stack = playerInv.inventory[i]
		inventory[i] = (stack and not stack:IsEmpty()) and stack:Serialize() or emptySlot
	end
	for i = 1, 9 do
		local stack = playerInv.hotbar[i]
		hotbar[i] = (stack and not stack:IsEmpty()) and stack:Serialize() or emptySlot
	end
	
	-- Calculate fuel percentage
	local maxFuelTime = self:GetMaxFuelTime(furnace)
	local fuelPercentage = maxFuelTime > 0 and (furnace.fuelBurnTimeRemaining / maxFuelTime) or 0
	
	EventManager:FireEvent("FurnaceActionResult", player, {
		furnacePos = {x = furnace.x, y = furnace.y, z = furnace.z},
		inputSlot = furnace.inputSlot:Serialize(),
		fuelSlot = furnace.fuelSlot:Serialize(),
		outputSlot = furnace.outputSlot:Serialize(),
		fuelBurnTimeRemaining = furnace.fuelBurnTimeRemaining,
		fuelPercentage = fuelPercentage,
		smeltProgress = furnace.currentSmeltProgress,
		playerInventory = inventory,
		hotbar = hotbar,
		cursorItem = cursor and not cursor:IsEmpty() and cursor:Serialize() or nil
	})
end

function FurnaceService:NotifyViewers(key, furnace)
	local maxFuelTime = self:GetMaxFuelTime(furnace)
	local fuelPercentage = maxFuelTime > 0 and (furnace.fuelBurnTimeRemaining / maxFuelTime) or 0
	
	for player, _ in pairs(furnace.viewers) do
		if player and player.Parent then -- Check player is still connected
			EventManager:FireEvent("FurnaceUpdated", player, {
				furnacePos = {x = furnace.x, y = furnace.y, z = furnace.z},
				inputSlot = furnace.inputSlot:Serialize(),
				fuelSlot = furnace.fuelSlot:Serialize(),
				outputSlot = furnace.outputSlot:Serialize(),
				fuelBurnTimeRemaining = furnace.fuelBurnTimeRemaining,
				fuelPercentage = fuelPercentage,
				smeltProgress = furnace.currentSmeltProgress
			})
		end
	end
end

--[[
	Save furnace state for persistence (single furnace)
]]
function FurnaceService:GetFurnaceStateForSave(x, y, z)
	local key = self:GetFurnaceKey(x, y, z)
	local furnace = self.furnaces[key]
	
	if not furnace then return nil end
	
	return {
		inputSlot = furnace.inputSlot:Serialize(),
		fuelSlot = furnace.fuelSlot:Serialize(),
		outputSlot = furnace.outputSlot:Serialize(),
		fuelBurnTimeRemaining = furnace.fuelBurnTimeRemaining,
		currentSmeltProgress = furnace.currentSmeltProgress
	}
end

--[[
	Load furnace state from persistence (single furnace)
]]
function FurnaceService:LoadFurnaceState(x, y, z, savedState)
	if not savedState then return end
	
	local furnace = self:GetFurnace(x, y, z)
	
	if savedState.inputSlot then
		furnace.inputSlot = ItemStack.Deserialize(savedState.inputSlot) or ItemStack.new(0, 0)
	end
	if savedState.fuelSlot then
		furnace.fuelSlot = ItemStack.Deserialize(savedState.fuelSlot) or ItemStack.new(0, 0)
	end
	if savedState.outputSlot then
		furnace.outputSlot = ItemStack.Deserialize(savedState.outputSlot) or ItemStack.new(0, 0)
	end
	furnace.fuelBurnTimeRemaining = savedState.fuelBurnTimeRemaining or 0
	furnace.currentSmeltProgress = savedState.currentSmeltProgress or 0
end

--[[
	Save all furnace data (called by world save)
	@return: table - Array of furnace data to save
]]
function FurnaceService:SaveFurnaceData()
	local furnaceData = {}
	
	self._logger.Debug("Starting furnace save...")
	
	for key, furnace in pairs(self.furnaces) do
		-- Only save furnaces that have items or active smelting
		local hasItems = not furnace.inputSlot:IsEmpty() 
			or not furnace.fuelSlot:IsEmpty() 
			or not furnace.outputSlot:IsEmpty()
		local hasProgress = furnace.fuelBurnTimeRemaining > 0 or furnace.currentSmeltProgress > 0
		
		if hasItems or hasProgress then
			local furnaceToSave = {
				x = furnace.x,
				y = furnace.y,
				z = furnace.z,
				inputSlot = furnace.inputSlot:Serialize(),
				fuelSlot = furnace.fuelSlot:Serialize(),
				outputSlot = furnace.outputSlot:Serialize(),
				fuelBurnTimeRemaining = furnace.fuelBurnTimeRemaining,
				currentSmeltProgress = furnace.currentSmeltProgress
			}
			table.insert(furnaceData, furnaceToSave)
			self._logger.Debug(string.format("Saving furnace at (%d,%d,%d)", furnace.x, furnace.y, furnace.z))
		end
	end
	
	self._logger.Debug(string.format("Furnace save complete: %d furnaces", #furnaceData))
	return furnaceData
end

--[[
	Load all furnace data (called on world load)
	@param furnaceData: table - Array of saved furnace data
]]
function FurnaceService:LoadFurnaceData(furnaceData)
	if not furnaceData then return end
	
	self._logger.Debug(string.format("Loading %d furnaces...", #furnaceData))
	
	for _, data in ipairs(furnaceData) do
		if data.x and data.y and data.z then
			local furnace = self:GetFurnace(data.x, data.y, data.z)
			
			if data.inputSlot then
				furnace.inputSlot = ItemStack.Deserialize(data.inputSlot) or ItemStack.new(0, 0)
			end
			if data.fuelSlot then
				furnace.fuelSlot = ItemStack.Deserialize(data.fuelSlot) or ItemStack.new(0, 0)
			end
			if data.outputSlot then
				furnace.outputSlot = ItemStack.Deserialize(data.outputSlot) or ItemStack.new(0, 0)
			end
			furnace.fuelBurnTimeRemaining = data.fuelBurnTimeRemaining or 0
			furnace.currentSmeltProgress = data.currentSmeltProgress or 0
			
			self._logger.Debug(string.format("Loaded furnace at (%d,%d,%d)", data.x, data.y, data.z))
		end
	end
	
	self._logger.Debug("Furnace load complete")
end

--[[
	Clean up on player leaving
]]
function FurnaceService:OnPlayerRemoving(player)
	self:HandleCloseFurnace(player, nil)
end

--[[
	Stop tick loop (for cleanup)
]]
function FurnaceService:Stop()
	if self.tickConnection then
		self.tickConnection:Disconnect()
		self.tickConnection = nil
	end
end

return FurnaceService
