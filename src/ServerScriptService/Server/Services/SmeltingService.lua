--[[
	SmeltingService.lua
	Server-authoritative smelting system for the Furnace

	Responsibilities:
	- Validate furnace interaction requests
	- Verify player has required materials for smelting
	- Consume ore materials when smelt starts
	- Calculate efficiency and coal consumption on completion
	- Grant output items to player inventory
	- Handle smelt cancellation with material refund
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local SmeltingConfig = require(ReplicatedStorage.Configs.SmeltingConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

local SmeltingService = setmetatable({}, BaseService)
SmeltingService.__index = SmeltingService

function SmeltingService.new()
	local self = setmetatable(BaseService.new(), SmeltingService)

	self._logger = Logger:CreateContext("SmeltingService")
	self.Deps = nil -- Will be injected by ServiceManager

	-- Track active smelting sessions per player
	-- {[player] = {recipeId, furnacePos, startTime, consumedItems}}
	self.activeSmelts = {}

	-- Rate limiting
	self.smeltCooldowns = {} -- {[player] = lastSmeltTime}
	self.SMELT_COOLDOWN = 0.5 -- 500ms between smelt operations

	return self
end

function SmeltingService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Debug("SmeltingService initialized")
end

function SmeltingService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)
	self._logger.Debug("SmeltingService started")
end

--[[
	Handle request to open furnace
	@param player: Player
	@param data: table - {x, y, z}
]]
function SmeltingService:HandleOpenFurnace(player, data)
	self._logger.Info("HandleOpenFurnace called", {player = player and player.Name})

	if not player or not data then
		self._logger.Warn("Invalid open furnace request", {player = player and player.Name})
		return
	end

	-- Validate position
	local x, y, z = data.x, data.y, data.z
	if not x or not y or not z then
		self._logger.Warn("Missing furnace position", {player = player.Name})
		return
	end

	-- Verify block is actually a furnace
	if not self:ValidateFurnaceBlock(x, y, z) then
		self._logger.Warn("Invalid furnace block", {
			player = player.Name,
			pos = {x = x, y = y, z = z}
		})
		return
	end

	-- Verify player distance
	if not self:ValidatePlayerDistance(player, x, y, z) then
		self._logger.Warn("Player too far from furnace", {player = player.Name})
		return
	end

	-- Get all smelting recipes with craftability info
	local recipes = self:GetSmeltingRecipes(player)
	self._logger.Info("Sending FurnaceOpened with recipes", {
		player = player.Name,
		recipeCount = #recipes,
		pos = {x = x, y = y, z = z}
	})

	-- Send furnace opened event to client
	EventManager:FireEvent("FurnaceOpened", player, {
		x = x,
		y = y,
		z = z,
		recipes = recipes
	})
end

--[[
	Handle request to start smelting
	@param player: Player
	@param data: table - {recipeId, furnacePos}
]]
function SmeltingService:HandleStartSmelt(player, data)
	self._logger.Info("HandleStartSmelt called", {player = player and player.Name, data = data})

	if not player then
		self._logger.Warn("Invalid start smelt request: no player")
		return
	end

	if not data then
		self._logger.Warn("Invalid start smelt request: no data", {player = player.Name})
		EventManager:FireEvent("SmeltStarted", player, {error = "Invalid request"})
		return
	end

	local recipeId = data.recipeId
	local furnacePos = data.furnacePos

	if not recipeId or not furnacePos then
		self._logger.Warn("Missing smelt data", {player = player.Name, recipeId = recipeId, furnacePos = furnacePos})
		EventManager:FireEvent("SmeltStarted", player, {error = "Missing recipe or position"})
		return
	end

	self._logger.Info("Processing smelt request", {player = player.Name, recipeId = recipeId})

	-- Rate limiting
	self._logger.Info("Step 1: Checking cooldown...")
	if not self:CheckCooldown(player) then
		self._logger.Warn("Smelt request rate limited", {player = player.Name})
		EventManager:FireEvent("SmeltStarted", player, {error = "Please wait before smelting again"})
		return
	end

	-- Check if player already has an active smelt
	self._logger.Info("Step 2: Checking active smelts...")
	if self.activeSmelts[player] then
		self._logger.Warn("Player already has active smelt", {player = player.Name})
		EventManager:FireEvent("SmeltStarted", player, {error = "Already smelting"})
		return
	end

	-- Validate furnace
	self._logger.Info("Step 3: Validating furnace block...", {pos = furnacePos})
	if not self:ValidateFurnaceBlock(furnacePos.x, furnacePos.y, furnacePos.z) then
		self._logger.Warn("Invalid furnace block")
		EventManager:FireEvent("SmeltStarted", player, {error = "Invalid furnace"})
		return
	end

	-- Validate distance
	self._logger.Info("Step 4: Validating player distance...")
	if not self:ValidatePlayerDistance(player, furnacePos.x, furnacePos.y, furnacePos.z) then
		self._logger.Warn("Player too far from furnace")
		EventManager:FireEvent("SmeltStarted", player, {error = "Too far from furnace"})
		return
	end

	-- Get recipe
	self._logger.Info("Step 5: Getting recipe...")
	local recipe = RecipeConfig:GetRecipe(recipeId)
	if not recipe then
		self._logger.Warn("Invalid recipe ID", {player = player.Name, recipeId = recipeId})
		EventManager:FireEvent("SmeltStarted", player, {error = "Invalid recipe"})
		return
	end
	self._logger.Info("Recipe found", {recipeName = recipe.name})

	-- Verify recipe requires furnace
	self._logger.Info("Step 6: Verifying recipe requires furnace...")
	if not SmeltingConfig:RequiresFurnace(recipe) then
		self._logger.Warn("Recipe does not require furnace", {player = player.Name, recipeId = recipeId})
		EventManager:FireEvent("SmeltStarted", player, {error = "Recipe cannot be smelted"})
		return
	end

	-- Get difficulty settings
	self._logger.Info("Step 7: Getting difficulty settings...")
	local difficulty = SmeltingConfig:GetDifficulty(recipeId)
	if not difficulty then
		self._logger.Error("No difficulty settings for recipe", {recipeId = recipeId})
		EventManager:FireEvent("SmeltStarted", player, {error = "Configuration error"})
		return
	end
	self._logger.Info("Difficulty found", {zoneWidth = difficulty.zoneWidth, smeltTime = difficulty.smeltTime})

	-- Get player inventory
	self._logger.Info("Step 8: Getting player inventory...")
	local invService = self.Deps and self.Deps.PlayerInventoryService
	if not invService then
		self._logger.Error("PlayerInventoryService not available")
		EventManager:FireEvent("SmeltStarted", player, {error = "Server error"})
		return
	end

	local playerInv = invService.inventories[player]
	if not playerInv then
		self._logger.Error("No inventory found for player")
		EventManager:FireEvent("SmeltStarted", player, {error = "No inventory found"})
		return
	end
	self._logger.Info("Player inventory found")

	-- Check player has non-coal materials (we consume ore now, coal at end)
	self._logger.Info("Step 9: Validating ore materials...")
	local hasOre = self:ValidateOreMaterials(player, recipe)
	if not hasOre then
		self._logger.Warn("Missing ore materials")
		EventManager:FireEvent("SmeltStarted", player, {error = "Missing ore materials"})
		return
	end

	-- Check player has coal fuel (validate but don't consume yet)
	self._logger.Info("Step 10: Validating coal fuel...")
	local hasCoal = self:ValidateCoalMaterials(player, recipeId)
	if not hasCoal then
		local requiredCoal = difficulty.baseCoal or 1
		self._logger.Warn("Not enough coal fuel", {required = requiredCoal})
		EventManager:FireEvent("SmeltStarted", player, {error = "Need " .. requiredCoal .. " coal for fuel"})
		return
	end

	-- Consume ore materials (NOT coal - that's consumed at completion based on efficiency)
	self._logger.Info("Step 11: Consuming ore materials...")
	local consumedItems = self:ConsumeOreMaterials(player, recipe, playerInv)
	if not consumedItems then
		self._logger.Error("Failed to consume ore materials")
		EventManager:FireEvent("SmeltStarted", player, {error = "Failed to consume materials"})
		return
	end

	-- Store active smelt session
	self._logger.Info("Step 12: Storing active smelt session...")
	self.activeSmelts[player] = {
		recipeId = recipeId,
		furnacePos = furnacePos,
		startTime = tick(),
		consumedItems = consumedItems,
		recipe = recipe,
		difficulty = difficulty
	}

	-- Sync inventory to client
	self._logger.Info("Step 13: Syncing inventory to client...")
	invService:SyncInventoryToClient(player)

	-- Send smelt config to client to start mini-game
	self._logger.Info("Step 14: Firing SmeltStarted event to client...")
	local smeltConfigData = {
		smeltConfig = {
			recipeId = recipeId,
			recipeName = recipe.name,
			zoneWidth = difficulty.zoneWidth,
			driftSpeed = difficulty.driftSpeed,
			smeltTime = difficulty.smeltTime,
			baseCoal = difficulty.baseCoal,
			outputItemId = recipe.outputs[1].itemId,
			outputCount = recipe.outputs[1].count
		}
	}
	self._logger.Info("SmeltStarted config", smeltConfigData)
	EventManager:FireEvent("SmeltStarted", player, smeltConfigData)

	self._logger.Info("✅ Smelt started successfully!", {
		player = player.Name,
		recipeId = recipeId,
		tier = SmeltingConfig:GetTier(recipeId)
	})
end

--[[
	Handle smelt completion from client
	@param player: Player
	@param data: table - {furnacePos, efficiencyPercent}
]]
function SmeltingService:HandleCompleteSmelt(player, data)
	if not player or not data then
		self._logger.Warn("Invalid complete smelt request")
		return
	end

	-- Check player has active smelt
	local activeSmelt = self.activeSmelts[player]
	if not activeSmelt then
		self._logger.Warn("No active smelt to complete", {player = player.Name})
		EventManager:FireEvent("SmeltCompleted", player, {success = false, error = "No active smelt"})
		return
	end

	-- Validate furnace position matches
	local furnacePos = data.furnacePos
	if not furnacePos or
	   furnacePos.x ~= activeSmelt.furnacePos.x or
	   furnacePos.y ~= activeSmelt.furnacePos.y or
	   furnacePos.z ~= activeSmelt.furnacePos.z then
		self._logger.Warn("Furnace position mismatch", {player = player.Name})
		EventManager:FireEvent("SmeltCompleted", player, {success = false, error = "Invalid furnace"})
		return
	end

	-- Validate minimum time elapsed (prevent speed hacks)
	local elapsedTime = tick() - activeSmelt.startTime
	local minTime = activeSmelt.difficulty.smeltTime * 0.8 -- Allow 20% tolerance
	if elapsedTime < minTime then
		self._logger.Warn("Smelt completed too quickly (possible exploit)", {
			player = player.Name,
			elapsed = elapsedTime,
			minTime = minTime
		})
		-- Still complete but cap efficiency
		data.efficiencyPercent = math.min(data.efficiencyPercent or 0, 40)
	end

	-- Calculate efficiency and coal cost
	local efficiencyPercent = math.clamp(data.efficiencyPercent or 50, 0, 100)
	local efficiency = SmeltingConfig:CalculateEfficiency(efficiencyPercent / 100, 1)
	local coalCost = SmeltingConfig:CalculateCoalCost(activeSmelt.difficulty.baseCoal, efficiency.multiplier)

	-- Get player inventory
	local invService = self.Deps and self.Deps.PlayerInventoryService
	if not invService then
		self._logger.Error("PlayerInventoryService not available")
		self:RefundSmelt(player, activeSmelt)
		return
	end

	local playerInv = invService.inventories[player]
	if not playerInv then
		self:RefundSmelt(player, activeSmelt)
		return
	end

	-- Consume coal
	local coalConsumed = self:ConsumeCoal(playerInv, coalCost)
	if not coalConsumed then
		-- Not enough coal - refund ore and cancel
		self._logger.Warn("Not enough coal to complete smelt", {
			player = player.Name,
			required = coalCost
		})
		self:RefundSmelt(player, activeSmelt)
		EventManager:FireEvent("SmeltCompleted", player, {
			success = false,
			error = "Not enough coal"
		})
		return
	end

	-- Give output item
	local recipe = activeSmelt.recipe
	local output = recipe.outputs[1]
	self:AddItemToInventory(playerInv, output.itemId, output.count)

	-- Clear active smelt
	self.activeSmelts[player] = nil

	-- Sync inventory to client
	invService:SyncInventoryToClient(player)

	-- Send completion event
	EventManager:FireEvent("SmeltCompleted", player, {
		success = true,
		outputItemId = output.itemId,
		outputCount = output.count,
		coalUsed = coalCost,
		stats = {
			rating = efficiency.rating,
			efficiencyPercent = efficiencyPercent,
			color = {efficiency.color.R * 255, efficiency.color.G * 255, efficiency.color.B * 255}
		}
	})

	self._logger.Debug("Smelt completed", {
		player = player.Name,
		recipeId = activeSmelt.recipeId,
		efficiency = efficiency.rating,
		coalUsed = coalCost
	})
end

--[[
	Handle smelt cancellation
	@param player: Player
	@param data: table - {furnacePos}
]]
function SmeltingService:HandleCancelSmelt(player, _data)
	if not player then
		return
	end

	local activeSmelt = self.activeSmelts[player]
	if not activeSmelt then
		-- No active smelt to cancel
		EventManager:FireEvent("SmeltCancelled", player, {refunded = false})
		return
	end

	-- Refund consumed ore materials
	self:RefundSmelt(player, activeSmelt)

	-- Clear active smelt
	self.activeSmelts[player] = nil

	-- Send cancellation event
	EventManager:FireEvent("SmeltCancelled", player, {refunded = true})

	self._logger.Debug("Smelt cancelled", {player = player.Name})
end

--[[
	Get all smelting recipes with craftability info
	@param player: Player
	@return: array - Array of {recipeId, name, canCraft, ingredients, fuelCost}
]]
function SmeltingService:GetSmeltingRecipes(player)
	local recipes = {}
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]

	-- Get player's coal count once
	local coalOwned = 0
	if playerInv then
		coalOwned = self:CountItemInInventory(playerInv, Constants.BlockType.COAL)
	end

	for recipeId, recipe in pairs(RecipeConfig.Recipes) do
		if SmeltingConfig:RequiresFurnace(recipe) then
			local ingredients = {}
			local hasAllIngredients = true

			-- Check each ingredient (ore, dust, etc. - NOT coal)
			for _, input in ipairs(recipe.inputs) do
				local owned = 0
				if playerInv then
					owned = self:CountItemInInventory(playerInv, input.itemId)
				end
				table.insert(ingredients, {
					itemId = input.itemId,
					required = input.count,
					owned = owned
				})
				if owned < input.count then
					hasAllIngredients = false
				end
			end

			-- Get difficulty for tier and fuel info
			local difficulty = SmeltingConfig:GetDifficulty(recipeId)
			local tier = SmeltingConfig:GetTier(recipeId)
			local fuelCost = difficulty and difficulty.baseCoal or 1

			-- Check if player has enough coal for fuel
			local hasEnoughFuel = coalOwned >= fuelCost

			-- Can craft if all ingredients AND fuel met
			local canCraft = hasAllIngredients and hasEnoughFuel

			table.insert(recipes, {
				recipeId = recipeId,
				name = recipe.name,
				canCraft = canCraft,
				hasIngredients = hasAllIngredients,
				hasEnoughFuel = hasEnoughFuel,
				ingredients = ingredients,
				-- Fuel info (coal is fuel, not ingredient)
				fuelCost = fuelCost,
				fuelOwned = coalOwned,
				-- Output info
				outputItemId = recipe.outputs[1].itemId,
				outputCount = recipe.outputs[1].count,
				-- Difficulty info
				tier = tier,
				smeltTime = difficulty and difficulty.smeltTime or 5
			})
		end
	end

	-- Sort by tier
	table.sort(recipes, function(a, b)
		return (a.tier or 0) < (b.tier or 0)
	end)

	return recipes
end

--[[
	Validate that block at position is a furnace
]]
function SmeltingService:ValidateFurnaceBlock(x, y, z)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws or not vws.worldManager then
		return false
	end

	local blockId = vws.worldManager:GetBlock(x, y, z)
	return blockId == Constants.BlockType.FURNACE
end

--[[
	Validate player is close enough to furnace
]]
function SmeltingService:ValidatePlayerDistance(player, x, y, z)
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
	return distance <= SmeltingConfig.MAX_INTERACTION_DISTANCE
end

--[[
	Validate player has ore materials (excluding coal)
]]
function SmeltingService:ValidateOreMaterials(player, recipe)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return false end

	for _, input in ipairs(recipe.inputs) do
		-- Skip coal check here (coal is validated separately)
		if input.itemId ~= Constants.BlockType.COAL then
			local owned = self:CountItemInInventory(playerInv, input.itemId)
			if owned < input.count then
				return false
			end
		end
	end
	return true
end

--[[
	Validate player has enough coal for fuel
	Coal is fuel, not a recipe ingredient - amount determined by tier
]]
function SmeltingService:ValidateCoalMaterials(player, recipeId)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return false end

	-- Get base coal requirement from SmeltingConfig (based on tier)
	local difficulty = SmeltingConfig:GetDifficulty(recipeId)
	local requiredCoal = difficulty and difficulty.baseCoal or 1

	local owned = self:CountItemInInventory(playerInv, Constants.BlockType.COAL)
	return owned >= requiredCoal
end

--[[
	Consume ore materials (not coal)
	@return: table - List of consumed items for potential refund
]]
function SmeltingService:ConsumeOreMaterials(_player, recipe, playerInv)
	local consumedItems = {}

	for _, input in ipairs(recipe.inputs) do
		-- Skip coal (consumed at completion based on efficiency)
		if input.itemId ~= Constants.BlockType.COAL then
			local removed = self:RemoveItemFromInventory(playerInv, input.itemId, input.count)
			if not removed then
				-- Rollback previously consumed items
				for _, item in ipairs(consumedItems) do
					self:AddItemToInventory(playerInv, item.itemId, item.count)
				end
				return nil
			end
			table.insert(consumedItems, {itemId = input.itemId, count = input.count})
		end
	end

	return consumedItems
end

--[[
	Consume coal from inventory
]]
function SmeltingService:ConsumeCoal(playerInv, amount)
	local owned = self:CountItemInInventory(playerInv, Constants.BlockType.COAL)
	if owned < amount then
		return false
	end
	return self:RemoveItemFromInventory(playerInv, Constants.BlockType.COAL, amount)
end

--[[
	Refund consumed materials from a cancelled smelt
]]
function SmeltingService:RefundSmelt(player, activeSmelt)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return end

	for _, item in ipairs(activeSmelt.consumedItems or {}) do
		self:AddItemToInventory(playerInv, item.itemId, item.count)
	end

	-- Sync to client
	if invService then
		invService:SyncInventoryToClient(player)
	end
end

--[[
	Count items in player inventory
]]
function SmeltingService:CountItemInInventory(playerInv, itemId)
	local count = 0

	-- Count in inventory
	for i = 1, 27 do
		local stack = playerInv.inventory[i]
		if stack and stack:GetItemId() == itemId then
			count = count + stack:GetCount()
		end
	end

	-- Count in hotbar
	for i = 1, 9 do
		local stack = playerInv.hotbar[i]
		if stack and stack:GetItemId() == itemId then
			count = count + stack:GetCount()
		end
	end

	return count
end

--[[
	Remove item from inventory
]]
function SmeltingService:RemoveItemFromInventory(playerInv, itemId, amount)
	local remaining = amount

	-- Remove from inventory first
	for i = 1, 27 do
		if remaining <= 0 then break end
		local stack = playerInv.inventory[i]
		if stack and stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	-- Remove from hotbar if needed
	for i = 1, 9 do
		if remaining <= 0 then break end
		local stack = playerInv.hotbar[i]
		if stack and stack:GetItemId() == itemId then
			local toRemove = math.min(remaining, stack:GetCount())
			stack:RemoveCount(toRemove)
			remaining = remaining - toRemove
		end
	end

	return remaining == 0
end

--[[
	Add item to inventory
]]
function SmeltingService:AddItemToInventory(playerInv, itemId, amount)
	local remaining = amount

	-- Try to add to existing stacks in inventory
	for i = 1, 27 do
		if remaining <= 0 then break end
		local stack = playerInv.inventory[i]
		if stack and stack:GetItemId() == itemId and not stack:IsFull() then
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
		if stack and stack:GetItemId() == itemId and not stack:IsFull() then
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
		if stack and stack:IsEmpty() then
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
		if stack and stack:IsEmpty() then
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
	end
end

--[[
	Check smelt cooldown
]]
function SmeltingService:CheckCooldown(player)
	local now = tick()
	local lastSmelt = self.smeltCooldowns[player] or 0

	if now - lastSmelt < self.SMELT_COOLDOWN then
		return false
	end

	self.smeltCooldowns[player] = now
	return true
end

--[[
	Clean up player data
]]
function SmeltingService:OnPlayerRemoving(player)
	self.activeSmelts[player] = nil
	self.smeltCooldowns[player] = nil
end

return SmeltingService

