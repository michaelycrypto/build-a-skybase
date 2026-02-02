--[[
	Randomizable Trait

	Simple composable trait for weighted random systems and procedural generation.
	Essential for loot systems, spawn systems, random events, and procedural content.

	Usage:
	- Include in your service: local Randomizable = require(ServerScriptService.Server.Mixins.Randomizable)
	- Apply to service: Randomizable.Apply(self)
	- Use random methods: self:DefineRandomPool("loot", {{item = "sword", weight = 10}})

	Features:
	- Weighted random selection
	- Multiple random pools/tables
	- Seed management for reproducible results
	- Luck modifiers and biases
	- Random range utilities
--]]

local Randomizable = {}

--[[
	Apply randomization functionality to a service
	@param service table - Service to apply randomization functionality to
--]]
function Randomizable.Apply(service)
	-- Initialize random data
	service._randomPools = {}
	service._luckModifiers = {}
	service._seedState = {}

	-- Initialize default random pool
	service._randomPools.default = {
		items = {},
		totalWeight = 0
	}

	-- Add random methods
	for methodName, method in pairs(Randomizable.Methods) do
		service[methodName] = method
	end
end

--[[
	Random methods that get added to services
--]]
Randomizable.Methods = {}

--[[
	Define a random pool with weighted items
	@param poolId string - Unique pool identifier
	@param items table - Array of {item, weight} pairs or {item = item, weight = weight}
--]]
function Randomizable.Methods:DefineRandomPool(poolId, items)
	assert(type(poolId) == "string", "PoolId must be a string")
	assert(type(items) == "table", "Items must be a table")

	local pool = {
		items = {},
		totalWeight = 0
	}

	-- Process items and calculate total weight
	for _, itemData in ipairs(items) do
		local item, weight

		if type(itemData) == "table" then
			item = itemData.item or itemData[1]
			weight = itemData.weight or itemData[2] or 1
		else
			item = itemData
			weight = 1
		end

		assert(weight > 0, "Item weight must be positive")

		table.insert(pool.items, {
			item = item,
			weight = weight,
			minRange = pool.totalWeight,
			maxRange = pool.totalWeight + weight - 1
		})

		pool.totalWeight = pool.totalWeight + weight
	end

	self._randomPools[poolId] = pool
end

--[[
	Select random item from a pool
	@param poolId string - Pool to select from (defaults to "default")
	@param player Player - Optional player for luck modifiers
	@return any - Selected item, or nil if pool is empty
--]]
function Randomizable.Methods:SelectRandom(poolId, player)
	poolId = poolId or "default"

	local pool = self._randomPools[poolId]
	if not pool or pool.totalWeight == 0 then
		return nil
	end

	-- Apply luck modifiers
	local modifiedWeight = self:_applyLuckModifiers(pool.totalWeight, player, poolId)

	-- Generate random number
	local randomValue = math.random(0, modifiedWeight - 1)

	-- Find selected item
	for _, itemData in ipairs(pool.items) do
		if randomValue >= itemData.minRange and randomValue <= itemData.maxRange then
			return itemData.item
		end
	end

	-- Fallback to first item if something went wrong
	return pool.items[1] and pool.items[1].item
end

--[[
	Select multiple random items from a pool
	@param poolId string - Pool to select from
	@param count number - Number of items to select
	@param allowDuplicates boolean - Whether to allow duplicate selections
	@param player Player - Optional player for luck modifiers
	@return table - Array of selected items
--]]
function Randomizable.Methods:SelectMultipleRandom(poolId, count, allowDuplicates, player)
	poolId = poolId or "default"
	assert(type(count) == "number" and count > 0, "Count must be a positive number")

	local pool = self._randomPools[poolId]
	if not pool or pool.totalWeight == 0 then
		return {}
	end

	local selected = {}
	local usedItems = {}

	for _ = 1, count do
		local item = self:SelectRandom(poolId, player)

		if item then
			if allowDuplicates or not usedItems[item] then
				table.insert(selected, item)
				usedItems[item] = true
			else
				-- Try to find a different item if duplicates not allowed
				local attempts = 0
				while attempts < 10 and usedItems[item] do
					item = self:SelectRandom(poolId, player)
					attempts = attempts + 1
				end

				if not usedItems[item] then
					table.insert(selected, item)
					usedItems[item] = true
				end
			end
		end
	end

	return selected
end

--[[
	Get random number in range
	@param min number - Minimum value (inclusive)
	@param max number - Maximum value (inclusive)
	@param player Player - Optional player for luck modifiers
	@return number - Random number in range
--]]
function Randomizable.Methods:RandomRange(min, max, player)
	assert(type(min) == "number", "Min must be a number")
	assert(type(max) == "number", "Max must be a number")
	assert(min <= max, "Min must be less than or equal to max")

	local range = max - min + 1
	local baseValue = math.random(0, range - 1) + min

	-- Apply luck modifiers to shift towards higher values
	if player then
		local luckModifier = self:_getLuckModifier(player, "range")
		if luckModifier > 1.0 then
			local shift = (max - baseValue) * (luckModifier - 1.0) * 0.5
			baseValue = math.min(max, baseValue + shift)
		end
	end

	return math.floor(baseValue)
end

--[[
	Get random float in range
	@param min number - Minimum value (inclusive)
	@param max number - Maximum value (inclusive)
	@param player Player - Optional player for luck modifiers
	@return number - Random float in range
--]]
function Randomizable.Methods:RandomFloat(min, max, player)
	assert(type(min) == "number", "Min must be a number")
	assert(type(max) == "number", "Max must be a number")
	assert(min <= max, "Min must be less than or equal to max")

	local baseValue = min + math.random() * (max - min)

	-- Apply luck modifiers to shift towards higher values
	if player then
		local luckModifier = self:_getLuckModifier(player, "range")
		if luckModifier > 1.0 then
			local shift = (max - baseValue) * (luckModifier - 1.0) * 0.5
			baseValue = math.min(max, baseValue + shift)
		end
	end

	return baseValue
end

--[[
	Roll dice (1-6 by default)
	@param sides number - Number of sides on the dice (default 6)
	@param count number - Number of dice to roll (default 1)
	@param player Player - Optional player for luck modifiers
	@return number - Sum of dice rolls
--]]
function Randomizable.Methods:RollDice(sides, count, player)
	sides = sides or 6
	count = count or 1

	assert(type(sides) == "number" and sides > 0, "Sides must be a positive number")
	assert(type(count) == "number" and count > 0, "Count must be a positive number")

	local total = 0
	for _ = 1, count do
		total = total + self:RandomRange(1, sides, player)
	end

	return total
end

--[[
	Check if random chance succeeds
	@param chance number - Chance between 0 and 1 (0.5 = 50%)
	@param player Player - Optional player for luck modifiers
	@return boolean - True if chance succeeds
--]]
function Randomizable.Methods:RandomChance(chance, player)
	assert(type(chance) == "number", "Chance must be a number")
	assert(chance >= 0 and chance <= 1, "Chance must be between 0 and 1")

	local modifiedChance = chance
	if player then
		local luckModifier = self:_getLuckModifier(player, "chance")
		modifiedChance = math.min(1.0, chance * luckModifier)
	end

	return math.random() < modifiedChance
end

--[[
	Set luck modifier for a player
	@param player Player - Player to modify
	@param modifier number - Luck multiplier (1.0 = normal, 1.5 = 50% better luck)
	@param category string - Optional category ("range", "chance", "loot", etc.)
--]]
function Randomizable.Methods:SetLuckModifier(player, modifier, category)
	assert(typeof(player) == "Instance", "Player must be a Roblox Player")
	assert(type(modifier) == "number", "Modifier must be a number")

	local playerId = tostring(player.UserId)
	category = category or "global"

	if not self._luckModifiers[playerId] then
		self._luckModifiers[playerId] = {}
	end

	self._luckModifiers[playerId][category] = modifier
end

--[[
	Get luck modifier for a player
	@param player Player - Player to check
	@param category string - Optional category
	@return number - Luck modifier (1.0 = normal)
--]]
function Randomizable.Methods:_getLuckModifier(player, category)
	if not player then
		return 1.0
	end

	local playerId = tostring(player.UserId)
	category = category or "global"

	if not self._luckModifiers[playerId] then
		return 1.0
	end

	return self._luckModifiers[playerId][category] or self._luckModifiers[playerId].global or 1.0
end

--[[
	Private: Apply luck modifiers to weight
--]]
function Randomizable.Methods:_applyLuckModifiers(totalWeight, player, poolId)
	if not player then
		return totalWeight
	end

	local luckModifier = self:_getLuckModifier(player, poolId)
	if luckModifier <= 1.0 then
		return totalWeight
	end

	-- Increase weight range to give better odds for higher-weighted items
	return math.floor(totalWeight * luckModifier)
end

return Randomizable