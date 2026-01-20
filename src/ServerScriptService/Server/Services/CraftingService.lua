--[[
	CraftingService.lua
	Server-authoritative crafting system

	Responsibilities:
	- Validate crafting requests from clients
	- Verify player has required materials
	- Execute crafts server-side
	- Prevent duplication exploits
	- Sync results back to client
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local CraftingSystem = require(ReplicatedStorage.Shared.VoxelWorld.Crafting.CraftingSystem)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

local CraftingService = setmetatable({}, BaseService)
CraftingService.__index = CraftingService

function CraftingService.new()
	local self = setmetatable(BaseService.new(), CraftingService)

	self._logger = Logger:CreateContext("CraftingService")
	self.Deps = nil  -- Will be injected by ServiceManager

	-- Rate limiting (prevent spam crafting)
	self.craftCooldowns = {}  -- {[player] = lastCraftTime}
	self.CRAFT_COOLDOWN = 0.1  -- 100ms between crafts (allows rapid clicking but prevents exploits)

	return self
end

function CraftingService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Info("CraftingService initialized")
end

function CraftingService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)
	self._logger.Info("CraftingService started")
end

--[[
	Handle batch craft request from client
	@param player: Player - Player making the request
	@param data: table - {recipeId: string, count: number, toCursor: boolean}
]]
function CraftingService:HandleCraftBatchRequest(player, data)
	if not player or not data then
		self._logger.Warn("Invalid craft batch request", {player = player and player.Name})
		return
	end

	local recipeId = data.recipeId
	local requestedCount = tonumber(data.count) or 0
	local toCursor = data.toCursor or false

	if requestedCount <= 0 then
		self._logger.Debug("Craft batch request with non-positive count", {
			player = player.Name,
			recipeId = recipeId,
			count = requestedCount
		})
		return
	end

	-- Validate inventory service
	if not self.Deps or not self.Deps.PlayerInventoryService then
		self._logger.Error("PlayerInventoryService dependency not available (batch)")
		return
	end

	local invService = self.Deps.PlayerInventoryService
	local playerInv = invService.inventories[player]

	if not playerInv then
		self._logger.Warn("No inventory found for player (batch)", {player = player.Name})
		return
	end

	-- Rate limiting check (single cooldown per batch)
	if not self:CheckCooldown(player) then
		self._logger.Debug("Craft batch request rate limited", {player = player.Name})
		-- Force resync to undo any optimistic client-side changes
		invService:SyncInventoryToClient(player)
		return
	end

	-- Validate recipe exists
	local recipe = RecipeConfig:GetRecipe(recipeId)
	if not recipe then
		self._logger.Warn("Invalid recipe ID (batch)", {
			player = player.Name,
			recipeId = recipeId
		})
		-- Resync to revert any optimistic changes
		invService:SyncInventoryToClient(player)
		return
	end

	-- Compute max craftable on server snapshot
	local tempInventoryManager = self:CreateTempInventoryManager(playerInv)
	local maxCraftCount = CraftingSystem:GetMaxCraftCount(recipe, tempInventoryManager)

	-- Optional stack cap for cursor crafts (assumes single output)
	local acceptedCount = math.min(requestedCount, maxCraftCount)
	if toCursor then
		local output = recipe.outputs and recipe.outputs[1]
		if not output then
			self._logger.Warn("Recipe missing outputs for cursor batch", {recipeId = recipeId})
			return
		end
		local maxStack = ItemStack.new(output.itemId, 1):GetMaxStack()
		local capByStack = math.floor(maxStack / (output.count or 1))
		acceptedCount = math.min(acceptedCount, capByStack)
	end

	if acceptedCount <= 0 then
		-- Nothing to do; resync to ensure client reflects server state
		invService:SyncInventoryToClient(player)
		-- Still send result for toCursor so client does not wait indefinitely
		if toCursor then
			EventManager:FireEvent("CraftRecipeBatchResult", player, {
				recipeId = recipeId,
				acceptedCount = 0,
				toCursor = true
			})
		end
		return
	end

	-- Check if inventory has space (only for non-cursor crafts)
	if not toCursor then
		local output = recipe.outputs and recipe.outputs[1]
		if output then
			local totalItems = acceptedCount * output.count
			if not self:CheckInventorySpace(playerInv, output.itemId, totalItems) then
				self._logger.Debug("Cannot batch craft - inventory full", {
					player = player.Name,
					recipeId = recipeId,
					requestedCount = acceptedCount
				})
				-- Resync to ensure client state is correct
				invService:SyncInventoryToClient(player)
				return
			end
		end
	end

	-- Execute batch craft server-side
	local success = self:ExecuteCraftBatch(player, recipe, playerInv, toCursor, acceptedCount)

	-- Sync inventory back to client
	invService:SyncInventoryToClient(player)

	if success then
		self._logger.Debug("Batch craft successful", {
			player = player.Name,
			recipe = recipe.name,
			count = acceptedCount,
			toCursor = toCursor
		})

		local output = recipe.outputs and recipe.outputs[1]

		-- Grant craft credits for toCursor crafts (acceptedCount × per-craft output)
		if toCursor then
			for _, out in ipairs(recipe.outputs or {}) do
				local amount = (out.count or 0) * acceptedCount
				if amount > 0 then
					invService:AddCraftCredit(player, out.itemId, amount)
				end
			end
		end

		-- Always fire CraftRecipeBatchResult so tutorial system can track crafts
		if output then
			EventManager:FireEvent("CraftRecipeBatchResult", player, {
				recipeId = recipeId,
				acceptedCount = acceptedCount,
				toCursor = toCursor,
				outputItemId = output.itemId,
				outputPerCraft = output.count
			})
		else
			EventManager:FireEvent("CraftRecipeBatchResult", player, {
				recipeId = recipeId,
				acceptedCount = acceptedCount,
				toCursor = toCursor
			})
		end
	else
		self._logger.Warn("Batch craft failed", {
			player = player.Name,
			recipeId = recipeId
		})
		if toCursor then
			EventManager:FireEvent("CraftRecipeBatchResult", player, {
				recipeId = recipeId,
				acceptedCount = 0,
				toCursor = true
			})
		end
	end
end

--[[
	Execute craft server-side for count times
	@param player: Player
	@param recipe: table
	@param playerInv: table
	@param toCursor: boolean
	@param count: number
	@return: boolean
]]
function CraftingService:ExecuteCraftBatch(player, recipe, playerInv, toCursor, count)
	-- Consume inputs (scaled by count)
	for _, input in ipairs(recipe.inputs) do
		local totalToRemove = (input.count or 0) * count
		if totalToRemove > 0 then
			local removed = self:RemoveItemFromInventory(playerInv, input.itemId, totalToRemove)
			if not removed then
				self._logger.Error("Failed to remove materials during batch craft", {
					player = player.Name,
					itemId = input.itemId,
					count = totalToRemove
				})
				return false
			end
		end
	end

	-- Add outputs if not to cursor (scaled by count)
	if not toCursor then
		for _, output in ipairs(recipe.outputs) do
			local totalToAdd = (output.count or 0) * count
			if totalToAdd > 0 then
				self:AddItemToInventory(playerInv, output.itemId, totalToAdd)
			end
		end
	end

	return true
end

--[[
	Handle craft request from client
	@param player: Player - Player making the request
	@param data: table - {recipeId: string, toCursor: boolean}
]]
function CraftingService:HandleCraftRequest(player, data)
    if not player or not data then
        self._logger.Warn("Invalid craft request", {player = player and player.Name})
        return
    end

    local recipeId = data.recipeId
    local toCursor = data.toCursor or false

    -- Get player's inventory service and snapshot first (used for resync on early exits)
    if not self.Deps or not self.Deps.PlayerInventoryService then
        self._logger.Error("PlayerInventoryService dependency not available")
        return
    end

    local invService = self.Deps.PlayerInventoryService
    local playerInv = invService.inventories[player]

    if not playerInv then
        self._logger.Warn("No inventory found for player", {player = player.Name})
        return
    end

    -- Rate limiting check
    if not self:CheckCooldown(player) then
        self._logger.Debug("Craft request rate limited", {player = player.Name})
        -- Force resync to undo any optimistic client-side changes
        invService:SyncInventoryToClient(player)
        return
    end

    -- Validate recipe exists
    local recipe = RecipeConfig:GetRecipe(recipeId)
    if not recipe then
        self._logger.Warn("Invalid recipe ID", {
            player = player.Name,
            recipeId = recipeId
        })
        -- Resync to revert any optimistic changes
        invService:SyncInventoryToClient(player)
        return
    end

    -- Create temporary inventory manager for validation
	local tempInventoryManager = self:CreateTempInventoryManager(playerInv)

	-- Validate player has materials
	if not CraftingSystem:CanCraft(recipe, tempInventoryManager) then
		self._logger.Debug("Player cannot craft - insufficient materials", {
			player = player.Name,
			recipeId = recipeId
		})

		-- Resync inventory to prevent desync
		invService:SyncInventoryToClient(player)
		return
	end

	-- Check if inventory has space (only for non-cursor crafts)
	if not toCursor then
		for _, output in ipairs(recipe.outputs or {}) do
			if not self:CheckInventorySpace(playerInv, output.itemId, output.count) then
				self._logger.Debug("Cannot craft - inventory full", {
					player = player.Name,
					recipeId = recipeId
				})
				-- Resync to ensure client state is correct
				invService:SyncInventoryToClient(player)
				return
			end
		end
	end

    -- Execute craft server-side
    local success = self:ExecuteCraft(player, recipe, playerInv, toCursor)

	if success then
		-- Sync updated inventory to client
		invService:SyncInventoryToClient(player)

		self._logger.Debug("Craft successful", {
			player = player.Name,
			recipe = recipe.name
		})

		local output = recipe.outputs and recipe.outputs[1]

		-- Grant craft credits for toCursor crafts so client placement is validated
		if toCursor then
			for _, out in ipairs(recipe.outputs or {}) do
				local amount = out.count or 0
				if amount > 0 then
					invService:AddCraftCredit(player, out.itemId, amount)
				end
			end
		end

		-- Fire result event so tutorial system can track crafts
		if output then
			EventManager:FireEvent("CraftRecipeBatchResult", player, {
				recipeId = recipeId,
				acceptedCount = 1,
				toCursor = toCursor,
				outputItemId = output.itemId,
				outputPerCraft = output.count
			})
		end
	else
		self._logger.Warn("Craft execution failed", {
			player = player.Name,
			recipeId = recipeId
		})

		-- Resync to fix any desync
		invService:SyncInventoryToClient(player)
	end
end

--[[
	Execute craft server-side (consume materials, add outputs)
	@param player: Player
	@param recipe: table - Recipe definition
	@param playerInv: table - Player's server inventory {hotbar, inventory}
	@return: boolean - Success
]]
function CraftingService:ExecuteCraft(player, recipe, playerInv, toCursor)
    -- Consume inputs
	for _, input in ipairs(recipe.inputs) do
		local removed = self:RemoveItemFromInventory(playerInv, input.itemId, input.count)
		if not removed then
			-- This shouldn't happen after validation, but safety check
			self._logger.Error("Failed to remove materials during craft", {
				player = player.Name,
				itemId = input.itemId,
				count = input.count
			})
			return false
		end
	end

    -- Add outputs unless this is a cursor pickup craft. For cursor crafts,
    -- we only consume materials server-side and let the client place the
    -- crafted stack into an inventory/hotbar slot, which will be synced via
    -- the normal InventoryUpdate flow. This prevents duplication (cursor + inventory).
    if not toCursor then
        for _, output in ipairs(recipe.outputs) do
            self:AddItemToInventory(playerInv, output.itemId, output.count)
        end
    end

	return true
end

--[[
	Remove item from player's inventory (server-side)
	@param playerInv: table - {hotbar, inventory}
	@param itemId: number
	@param amount: number
	@return: boolean - Success
]]
function CraftingService:RemoveItemFromInventory(playerInv, itemId, amount)
	local remaining = amount

	-- Remove from inventory first (27 slots)
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = playerInv.inventory[i]
		if stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	-- Remove from hotbar if needed (9 slots)
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = playerInv.hotbar[i]
		if stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	return remaining == 0
end

--[[
	Add item to player's inventory (server-side)
	@param playerInv: table - {hotbar, inventory}
	@param itemId: number
	@param amount: number
]]
function CraftingService:AddItemToInventory(playerInv, itemId, amount)
	local remaining = amount

	-- Try to add to existing stacks in inventory
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = playerInv.inventory[i]
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			local toAdd = math.min(remaining, spaceLeft)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
		end
	end

	-- Try to add to existing stacks in hotbar
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = playerInv.hotbar[i]
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			local toAdd = math.min(remaining, spaceLeft)
			stack:AddCount(toAdd)
			remaining = remaining - toAdd
		end
	end

	-- Create new stacks in empty inventory slots
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = playerInv.inventory[i]
		if stack:IsEmpty() then
			local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(remaining, maxStack)
			playerInv.inventory[i] = ItemStack.new(itemId, toAdd)
			remaining = remaining - toAdd
		end
	end

	-- Create new stacks in empty hotbar slots
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = playerInv.hotbar[i]
		if stack:IsEmpty() then
			local maxStack = ItemStack.new(itemId, 1):GetMaxStack()
			local toAdd = math.min(remaining, maxStack)
			playerInv.hotbar[i] = ItemStack.new(itemId, toAdd)
			remaining = remaining - toAdd
		end
	end

	if remaining > 0 then
		self._logger.Warn("Inventory full, couldn't add all items", {
			itemId = itemId,
			remaining = remaining
		})
		-- TODO: Could drop items to world here
	end
end

--[[
	Create temporary inventory manager for CraftingSystem validation
	@param playerInv: table - Server inventory {hotbar, inventory}
	@return: table - Temporary manager with CountItem and HasSpaceForItem methods
]]
function CraftingService:CreateTempInventoryManager(playerInv)
	return {
		CountItem = function(_, itemId)
			local count = 0

			-- Count in inventory
			for i = 1, 27 do
				local stack = playerInv.inventory[i]
				if stack:GetItemId() == itemId then
					count = count + stack:GetCount()
				end
			end

			-- Count in hotbar
			for i = 1, 9 do
				local stack = playerInv.hotbar[i]
				if stack:GetItemId() == itemId then
					count = count + stack:GetCount()
				end
			end

			return count
		end,

		HasSpaceForItem = function(_, itemId, amount)
			return CraftingService:CheckInventorySpace(playerInv, itemId, amount)
		end
	}
end

--[[
	Check if inventory has space for items
	@param playerInv: table - Server inventory {hotbar, inventory}
	@param itemId: number - Item ID
	@param amount: number - Amount to add
	@return: boolean - True if there's enough space
]]
function CraftingService:CheckInventorySpace(playerInv, itemId, amount)
	local remaining = amount

	local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
	local isTool = ToolConfig.IsTool(itemId)

	-- For tools, count empty slots only (tools don't stack)
	if isTool then
		local emptySlots = 0
		for i = 1, 27 do
			if playerInv.inventory[i]:IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		for i = 1, 9 do
			if playerInv.hotbar[i]:IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		return emptySlots >= amount
	end

	-- Check space in existing stacks (inventory)
	for i = 1, 27 do
		if remaining <= 0 then break end

		local stack = playerInv.inventory[i]
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			remaining = remaining - spaceLeft
		end
	end

	-- Check space in existing stacks (hotbar)
	for i = 1, 9 do
		if remaining <= 0 then break end

		local stack = playerInv.hotbar[i]
		if stack:GetItemId() == itemId and not stack:IsFull() then
			local spaceLeft = stack:GetRemainingSpace()
			remaining = remaining - spaceLeft
		end
	end

	-- Count empty slots that can be used
	if remaining > 0 then
		local emptySlots = 0
		for i = 1, 27 do
			if playerInv.inventory[i]:IsEmpty() then
				emptySlots = emptySlots + 1
			end
		end
		for i = 1, 9 do
			if playerInv.hotbar[i]:IsEmpty() then
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
	Check craft cooldown (rate limiting)
	@param player: Player
	@return: boolean - Can craft
]]
function CraftingService:CheckCooldown(player)
	local now = tick()
	local lastCraft = self.craftCooldowns[player] or 0

	if now - lastCraft < self.CRAFT_COOLDOWN then
		return false  -- Too soon
	end

	self.craftCooldowns[player] = now
	return true
end

--[[
	Clean up player data
]]
function CraftingService:OnPlayerRemoving(player)
	self.craftCooldowns[player] = nil
end

return CraftingService

