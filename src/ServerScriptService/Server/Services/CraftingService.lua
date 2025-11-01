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

	self._logger.Info("Initializing CraftingService...")

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
	Handle craft request from client
	@param player: Player - Player making the request
	@param data: table - {recipeId: string, toCursor: boolean}
]]
function CraftingService:HandleCraftRequest(player, data)
	if not player or not data then
		self._logger.Warn("Invalid craft request", {player = player and player.Name})
		return
	end

	-- Rate limiting check
	if not self:CheckCooldown(player) then
		self._logger.Debug("Craft request rate limited", {player = player.Name})
		return
	end

	local recipeId = data.recipeId
	local toCursor = data.toCursor or false

	-- Validate recipe exists
	local recipe = RecipeConfig:GetRecipe(recipeId)
	if not recipe then
		self._logger.Warn("Invalid recipe ID", {
			player = player.Name,
			recipeId = recipeId
		})
		return
	end

	-- Get player's inventory from PlayerInventoryService
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

	-- Execute craft server-side
	local success = self:ExecuteCraft(player, recipe, playerInv)

	if success then
		-- Sync updated inventory to client
		invService:SyncInventoryToClient(player)

		self._logger.Debug("Craft successful", {
			player = player.Name,
			recipe = recipe.name
		})
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
function CraftingService:ExecuteCraft(player, recipe, playerInv)
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

	-- Add outputs
	for _, output in ipairs(recipe.outputs) do
		self:AddItemToInventory(playerInv, output.itemId, output.count)
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
	@return: table - Temporary manager with CountItem method
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
		end
	}
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

