--[[
	SmithingService.lua
	Server-authoritative smithing system for the Anvil

	Responsibilities:
	- Validate anvil interaction requests
	- Verify player has required materials for smithing
	- Consume materials when smithing starts
	- Calculate efficiency and coal consumption on completion
	- Grant output items to player inventory
	- Handle smithing cancellation with material refund
	
	Note: This handles the temperature mini-game for advanced crafting.
	Basic ore smelting is now handled by FurnaceService.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local SmithingConfig = require(ReplicatedStorage.Configs.SmithingConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)

local SmithingService = setmetatable({}, BaseService)
SmithingService.__index = SmithingService

function SmithingService.new()
	local self = setmetatable(BaseService.new(), SmithingService)

	self._logger = Logger:CreateContext("SmithingService")
	self.Deps = nil -- Will be injected by ServiceManager

	-- Track active smelting sessions per player
	-- {[player] = {recipeId, anvilPos, startTime, consumedItems}}
	self.activeSmiths = {}

	-- Rate limiting
	self.smithCooldowns = {} -- {[player] = lastSmeltTime}
	self.SMITH_COOLDOWN = 0.5 -- 500ms between smelt operations

	return self
end

function SmithingService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Debug("SmithingService initialized")
end

function SmithingService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)
	self._logger.Debug("SmithingService started")
end

--[[
	Handle request to open anvil
	@param player: Player
	@param data: table - {x, y, z}
]]
function SmithingService:HandleOpenAnvil(player, data)
	self._logger.Info("HandleOpenAnvil called", {player = player and player.Name})

	if not player or not data then
		self._logger.Warn("Invalid open anvil request", {player = player and player.Name})
		return
	end

	-- Validate position
	local x, y, z = data.x, data.y, data.z
	if not x or not y or not z then
		self._logger.Warn("Missing anvil position", {player = player.Name})
		return
	end

	-- Verify block is actually an anvil
	if not self:ValidateAnvilBlock(x, y, z) then
		self._logger.Warn("Invalid anvil block", {
			player = player.Name,
			pos = {x = x, y = y, z = z}
		})
		return
	end

	-- Verify player distance
	if not self:ValidatePlayerDistance(player, x, y, z) then
		self._logger.Warn("Player too far from anvil", {player = player.Name})
		return
	end

	-- Get all smithing recipes with craftability info
	local recipes = self:GetSmithingRecipes(player)
	self._logger.Info("Sending AnvilOpened with recipes", {
		player = player.Name,
		recipeCount = #recipes,
		pos = {x = x, y = y, z = z}
	})

	-- Send anvil opened event to client
	EventManager:FireEvent("AnvilOpened", player, {
		x = x,
		y = y,
		z = z,
		recipes = recipes
	})
end

--[[
	Handle request to start smelting
	@param player: Player
	@param data: table - {recipeId, anvilPos}
]]
function SmithingService:HandleStartSmith(player, data)
	self._logger.Info("HandleStartSmith called", {player = player and player.Name, data = data})

	if not player then
		self._logger.Warn("Invalid start smelt request: no player")
		return
	end

	if not data then
		self._logger.Warn("Invalid start smelt request: no data", {player = player.Name})
		EventManager:FireEvent("SmithStarted", player, {error = "Invalid request"})
		return
	end

	local recipeId = data.recipeId
	local anvilPos = data.anvilPos

	if not recipeId or not anvilPos then
		self._logger.Warn("Missing smelt data", {player = player.Name, recipeId = recipeId, anvilPos = anvilPos})
		EventManager:FireEvent("SmithStarted", player, {error = "Missing recipe or position"})
		return
	end

	self._logger.Info("Processing smelt request", {player = player.Name, recipeId = recipeId})

	-- Rate limiting
	self._logger.Info("Step 1: Checking cooldown...")
	if not self:CheckCooldown(player) then
		self._logger.Warn("Smelt request rate limited", {player = player.Name})
		EventManager:FireEvent("SmithStarted", player, {error = "Please wait before smelting again"})
		return
	end

	-- Check if player already has an active smelt
	self._logger.Info("Step 2: Checking active smelts...")
	if self.activeSmiths[player] then
		self._logger.Warn("Player already has active smelt", {player = player.Name})
		EventManager:FireEvent("SmithStarted", player, {error = "Already smelting"})
		return
	end

	-- Validate furnace
	self._logger.Info("Step 3: Validating furnace block...", {pos = anvilPos})
	if not self:ValidateAnvilBlock(anvilPos.x, anvilPos.y, anvilPos.z) then
		self._logger.Warn("Invalid furnace block")
		EventManager:FireEvent("SmithStarted", player, {error = "Invalid furnace"})
		return
	end

	-- Validate distance
	self._logger.Info("Step 4: Validating player distance...")
	if not self:ValidatePlayerDistance(player, anvilPos.x, anvilPos.y, anvilPos.z) then
		self._logger.Warn("Player too far from furnace")
		EventManager:FireEvent("SmithStarted", player, {error = "Too far from furnace"})
		return
	end

	-- Get recipe
	self._logger.Info("Step 5: Getting recipe...")
	local recipe = RecipeConfig:GetRecipe(recipeId)
	if not recipe then
		self._logger.Warn("Invalid recipe ID", {player = player.Name, recipeId = recipeId})
		EventManager:FireEvent("SmithStarted", player, {error = "Invalid recipe"})
		return
	end
	self._logger.Info("Recipe found", {recipeName = recipe.name})

	-- Verify recipe requires furnace
	self._logger.Info("Step 6: Verifying recipe requires furnace...")
	if not SmithingConfig:RequiresAnvil(recipe) then
		self._logger.Warn("Recipe does not require furnace", {player = player.Name, recipeId = recipeId})
		EventManager:FireEvent("SmithStarted", player, {error = "Recipe cannot be smelted"})
		return
	end

	-- Get difficulty settings
	self._logger.Info("Step 7: Getting difficulty settings...")
	local difficulty = SmithingConfig:GetDifficulty(recipeId)
	if not difficulty then
		self._logger.Error("No difficulty settings for recipe", {recipeId = recipeId})
		EventManager:FireEvent("SmithStarted", player, {error = "Configuration error"})
		return
	end
	self._logger.Info("Difficulty found", {zoneWidth = difficulty.zoneWidth, smeltTime = difficulty.smeltTime})

	-- Get player inventory
	self._logger.Info("Step 8: Getting player inventory...")
	local invService = self.Deps and self.Deps.PlayerInventoryService
	if not invService then
		self._logger.Error("PlayerInventoryService not available")
		EventManager:FireEvent("SmithStarted", player, {error = "Server error"})
		return
	end

	local playerInv = invService.inventories[player]
	if not playerInv then
		self._logger.Error("No inventory found for player")
		EventManager:FireEvent("SmithStarted", player, {error = "No inventory found"})
		return
	end
	self._logger.Info("Player inventory found")

	-- Check player has non-coal materials (we consume ore now, coal at end)
	self._logger.Info("Step 9: Validating ore materials...")
	local hasOre = self:ValidateOreMaterials(player, recipe)
	if not hasOre then
		self._logger.Warn("Missing ore materials")
		EventManager:FireEvent("SmithStarted", player, {error = "Missing ore materials"})
		return
	end

	-- Check player has coal fuel (validate but don't consume yet)
	self._logger.Info("Step 10: Validating coal fuel...")
	local hasCoal = self:ValidateCoalMaterials(player, recipeId)
	if not hasCoal then
		local requiredCoal = difficulty.baseCoal or 1
		self._logger.Warn("Not enough coal fuel", {required = requiredCoal})
		EventManager:FireEvent("SmithStarted", player, {error = "Need " .. requiredCoal .. " coal for fuel"})
		return
	end

	-- Consume ore materials (NOT coal - that's consumed at completion based on efficiency)
	self._logger.Info("Step 11: Consuming ore materials...")
	local consumedItems = self:ConsumeOreMaterials(player, recipe, playerInv)
	if not consumedItems then
		self._logger.Error("Failed to consume ore materials")
		EventManager:FireEvent("SmithStarted", player, {error = "Failed to consume materials"})
		return
	end

	-- Store active smelt session
	self._logger.Info("Step 12: Storing active smelt session...")
	self.activeSmiths[player] = {
		recipeId = recipeId,
		anvilPos = anvilPos,
		startTime = tick(),
		consumedItems = consumedItems,
		recipe = recipe,
		difficulty = difficulty
	}

	-- Sync inventory to client
	self._logger.Info("Step 13: Syncing inventory to client...")
	invService:SyncInventoryToClient(player)

	-- Send smelt config to client to start mini-game
	self._logger.Info("Step 14: Firing SmithStarted event to client...")
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
	self._logger.Info("SmithStarted config", smeltConfigData)
	EventManager:FireEvent("SmithStarted", player, smeltConfigData)

	self._logger.Info("✅ Smelt started successfully!", {
		player = player.Name,
		recipeId = recipeId,
		tier = SmithingConfig:GetTier(recipeId)
	})
end

--[[
	Handle smelt completion from client
	@param player: Player
	@param data: table - {anvilPos, efficiencyPercent}
]]
function SmithingService:HandleCompleteSmith(player, data)
	if not player or not data then
		self._logger.Warn("Invalid complete smelt request")
		return
	end

	-- Check player has active smelt
	local activeSmelt = self.activeSmiths[player]
	if not activeSmelt then
		self._logger.Warn("No active smelt to complete", {player = player.Name})
		EventManager:FireEvent("SmithCompleted", player, {success = false, error = "No active smelt"})
		return
	end

	-- Validate furnace position matches
	local anvilPos = data.anvilPos
	if not anvilPos or
	   anvilPos.x ~= activeSmelt.anvilPos.x or
	   anvilPos.y ~= activeSmelt.anvilPos.y or
	   anvilPos.z ~= activeSmelt.anvilPos.z then
		self._logger.Warn("Furnace position mismatch", {player = player.Name})
		EventManager:FireEvent("SmithCompleted", player, {success = false, error = "Invalid furnace"})
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
	local efficiency = SmithingConfig:CalculateEfficiency(efficiencyPercent / 100, 1)
	local coalCost = SmithingConfig:CalculateCoalCost(activeSmelt.difficulty.baseCoal, efficiency.multiplier)

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
		EventManager:FireEvent("SmithCompleted", player, {
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
	self.activeSmiths[player] = nil

	-- Sync inventory to client
	invService:SyncInventoryToClient(player)

	-- Send completion event
	EventManager:FireEvent("SmithCompleted", player, {
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
	@param data: table - {anvilPos}
]]
function SmithingService:HandleCancelSmith(player, _data)
	if not player then
		return
	end

	local activeSmelt = self.activeSmiths[player]
	if not activeSmelt then
		-- No active smelt to cancel
		EventManager:FireEvent("SmithCancelled", player, {refunded = false})
		return
	end

	-- Refund consumed ore materials
	self:RefundSmelt(player, activeSmelt)

	-- Clear active smelt
	self.activeSmiths[player] = nil

	-- Send cancellation event
	EventManager:FireEvent("SmithCancelled", player, {refunded = true})

	self._logger.Debug("Smelt cancelled", {player = player.Name})
end

--[[
	Get all smelting recipes with craftability info
	@param player: Player
	@return: array - Array of {recipeId, name, canCraft, ingredients, fuelCost}
]]
function SmithingService:GetSmithingRecipes(player)
	local recipes = {}
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]

	-- Get player's coal count once
	local coalOwned = 0
	if playerInv then
		coalOwned = self:CountItemInInventory(playerInv, 32)
	end

	for recipeId, recipe in pairs(RecipeConfig.Recipes) do
		if SmithingConfig:RequiresAnvil(recipe) then
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
			local difficulty = SmithingConfig:GetDifficulty(recipeId)
			local tier = SmithingConfig:GetTier(recipeId)
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
function SmithingService:ValidateAnvilBlock(x, y, z)
	local vws = self.Deps and self.Deps.VoxelWorldService
	if not vws or not vws.worldManager then
		return false
	end

	local blockId = vws.worldManager:GetBlock(x, y, z)
	return blockId == Constants.BlockType.ANVIL
end

--[[
	Validate player is close enough to furnace
]]
function SmithingService:ValidatePlayerDistance(player, x, y, z)
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
	return distance <= SmithingConfig.MAX_INTERACTION_DISTANCE
end

--[[
	Validate player has ore materials (excluding coal)
]]
function SmithingService:ValidateOreMaterials(player, recipe)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return false end

	for _, input in ipairs(recipe.inputs) do
		-- Skip coal check here (coal is validated separately)
		if input.itemId ~= 32 then
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
function SmithingService:ValidateCoalMaterials(player, recipeId)
	local invService = self.Deps and self.Deps.PlayerInventoryService
	local playerInv = invService and invService.inventories[player]
	if not playerInv then return false end

	-- Get base coal requirement from SmithingConfig (based on tier)
	local difficulty = SmithingConfig:GetDifficulty(recipeId)
	local requiredCoal = difficulty and difficulty.baseCoal or 1

	local owned = self:CountItemInInventory(playerInv, 32)
	return owned >= requiredCoal
end

--[[
	Consume ore materials (not coal)
	@return: table - List of consumed items for potential refund
]]
function SmithingService:ConsumeOreMaterials(_player, recipe, playerInv)
	local consumedItems = {}

	for _, input in ipairs(recipe.inputs) do
		-- Skip coal (consumed at completion based on efficiency)
		if input.itemId ~= 32 then
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
function SmithingService:ConsumeCoal(playerInv, amount)
	local owned = self:CountItemInInventory(playerInv, 32)
	if owned < amount then
		return false
	end
	return self:RemoveItemFromInventory(playerInv, 32, amount)
end

--[[
	Refund consumed materials from a cancelled smelt
]]
function SmithingService:RefundSmelt(player, activeSmelt)
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
function SmithingService:CountItemInInventory(playerInv, itemId)
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
function SmithingService:RemoveItemFromInventory(playerInv, itemId, amount)
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
function SmithingService:AddItemToInventory(playerInv, itemId, amount)
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
function SmithingService:CheckCooldown(player)
	local now = tick()
	local lastSmelt = self.smithCooldowns[player] or 0

	if now - lastSmelt < self.SMITH_COOLDOWN then
		return false
	end

	self.smithCooldowns[player] = now
	return true
end

--[[
	Clean up player data
]]
function SmithingService:OnPlayerRemoving(player)
	self.activeSmiths[player] = nil
	self.smithCooldowns[player] = nil
end

return SmithingService

