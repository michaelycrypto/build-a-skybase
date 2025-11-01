--[[
	CraftingSystem.lua
	Core crafting logic for simplified recipe-based crafting

	Handles:
	- Recipe validation (can player craft?)
	- Material checking
	- Craft execution (consume inputs, add outputs)
	- Max craft count calculation
]]

local CraftingSystem = {}

--[[
	Check if player has enough materials for a recipe
	@param recipe: table - Recipe definition from RecipeConfig
	@param inventoryManager: table - ClientInventoryManager instance
	@return: boolean - True if player can craft
]]
function CraftingSystem:CanCraft(recipe, inventoryManager)
	if not recipe or not inventoryManager then
		return false
	end

	-- Check each input requirement
	for _, input in ipairs(recipe.inputs) do
		local totalCount = inventoryManager:CountItem(input.itemId)
		if totalCount < input.count then
			return false
		end
	end

	return true
end

--[[
	Get maximum number of times this recipe can be crafted
	@param recipe: table - Recipe definition
	@param inventoryManager: table - ClientInventoryManager instance
	@return: number - Max number of times can craft (0 if can't craft)
]]
function CraftingSystem:GetMaxCraftCount(recipe, inventoryManager)
	if not recipe or not inventoryManager then
		return 0
	end

	local maxCount = math.huge

	-- For each input, calculate how many times we can craft
	for _, input in ipairs(recipe.inputs) do
		local totalCount = inventoryManager:CountItem(input.itemId)
		local timesCanCraft = math.floor(totalCount / input.count)
		maxCount = math.min(maxCount, timesCanCraft)
	end

	return maxCount == math.huge and 0 or maxCount
end

--[[
	Execute crafting (consume inputs, add outputs)
	Note: With cursor mechanic, materials are consumed when picking up to cursor,
	not when placing. This method is used for Shift+Click instant crafting.

	@param recipe: table - Recipe definition
	@param inventoryManager: table - ClientInventoryManager instance
	@param count: number - Number of times to craft (default 1)
	@return: boolean - Success
	@return: string - Error message if failed
]]
function CraftingSystem:ExecuteCraft(recipe, inventoryManager, count)
	count = count or 1

	-- Validate can craft
	if not self:CanCraft(recipe, inventoryManager) then
		return false, "Not enough materials"
	end

	local maxCraft = self:GetMaxCraftCount(recipe, inventoryManager)
	if count > maxCraft then
		return false, "Not enough materials for that quantity"
	end

	-- Consume inputs
	for _, input in ipairs(recipe.inputs) do
		local totalToRemove = input.count * count
		local success = inventoryManager:RemoveItem(input.itemId, totalToRemove)
		if not success then
			-- This shouldn't happen if validation worked, but safety check
			warn("CraftingSystem: Failed to remove materials for recipe", recipe.id)
			return false, "Failed to consume materials"
		end
	end

	-- Add outputs
	for _, output in ipairs(recipe.outputs) do
		local totalToAdd = output.count * count
		inventoryManager:AddItem(output.itemId, totalToAdd)
		-- Note: AddItem will do its best to add items, dropping extras if inventory full
	end

	return true, "Crafted successfully"
end

--[[
	Consume materials for one craft (for cursor pickup)
	@param recipe: table - Recipe definition
	@param inventoryManager: table - ClientInventoryManager instance
	@return: boolean - Success
]]
function CraftingSystem:ConsumeMaterials(recipe, inventoryManager)
	if not self:CanCraft(recipe, inventoryManager) then
		return false
	end

	-- Consume inputs
	for _, input in ipairs(recipe.inputs) do
		inventoryManager:RemoveItem(input.itemId, input.count)
	end

	return true
end

--[[
	Get all craftable recipes (filters based on current inventory)
	@param inventoryManager: table - ClientInventoryManager instance
	@param allRecipes: array - Array of all recipes to check
	@return: array - Array of {recipe, maxCount} for craftable recipes
]]
function CraftingSystem:GetCraftableRecipes(inventoryManager, allRecipes)
	local craftable = {}

	for _, recipe in ipairs(allRecipes) do
		if self:CanCraft(recipe, inventoryManager) then
			table.insert(craftable, {
				recipe = recipe,
				maxCount = self:GetMaxCraftCount(recipe, inventoryManager)
			})
		end
	end

	return craftable
end

--[[
	Check if adding output to cursor would exceed max stack
	@param recipe: table - Recipe definition
	@param currentCursorStack: ItemStack - Current cursor stack
	@return: boolean - True if can add to cursor
	@return: number - Amount that can be added
]]
function CraftingSystem:CanAddToCursor(recipe, currentCursorStack)
	if not recipe or not currentCursorStack then
		return false, 0
	end

	local output = recipe.outputs[1]  -- Assume single output for now

	-- If cursor empty, can always add
	if currentCursorStack:IsEmpty() then
		return true, output.count
	end

	-- If cursor has different item, can't add
	if currentCursorStack:GetItemId() ~= output.itemId then
		return false, 0
	end

	-- If cursor is full, can't add
	if currentCursorStack:IsFull() then
		return false, 0
	end

	-- Calculate how much can be added
	local spaceLeft = currentCursorStack:GetRemainingSpace()
	local amountToAdd = math.min(output.count, spaceLeft)

	return amountToAdd > 0, amountToAdd
end

return CraftingSystem

