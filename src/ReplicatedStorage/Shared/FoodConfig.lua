--[[
	FoodConfig.lua
	Configuration for food items, hunger mechanics, and eating behavior.
	Matches Minecraft food values exactly.

	All food items are defined in ItemDefinitions.Food.
]]

local ItemDefinitions = require(script.Parent.Parent.Configs.ItemDefinitions)

local FoodConfig = {}

-- Helper function to add food by ItemDefinitions key name
local function addFood(foods, itemKey, config)
	local id = ItemDefinitions.Id[itemKey]
	if id then
		foods[id] = config
	end
end

-- Food item definitions
-- Format: [itemId] = {hunger, saturation, stackSize, effects}
-- All values match Minecraft exactly
FoodConfig.Foods = {}

-- Build the foods table using only items that exist in Constants
local function buildFoodsTable()
	local foods = {}

	-- Basic Foods (these exist in Constants)
	addFood(foods, "APPLE", {
		hunger = 4,
		saturation = 2.4,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "CARROT", {
		hunger = 3,
		saturation = 3.6,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "POTATO", {
		hunger = 1,
		saturation = 0.6,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "BEETROOT", {
		hunger = 1,
		saturation = 1.2,
		stackSize = 64,
		effects = {}
	})

	-- Cooked Foods (add when implemented in Constants)
	addFood(foods, "BREAD", {
		hunger = 5,
		saturation = 6.0,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "BAKED_POTATO", {
		hunger = 5,
		saturation = 6.0,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_BEEF", {
		hunger = 8,
		saturation = 12.8,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_PORKCHOP", {
		hunger = 8,
		saturation = 12.8,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_CHICKEN", {
		hunger = 6,
		saturation = 7.2,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_MUTTON", {
		hunger = 6,
		saturation = 9.6,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_RABBIT", {
		hunger = 5,
		saturation = 6.0,
		stackSize = 64,
		effects = {}
	})

	-- Special Foods
	addFood(foods, "GOLDEN_APPLE", {
		hunger = 4,
		saturation = 9.6,
		stackSize = 64,
		effects = {
			{type = "regeneration", level = 2, duration = 5}
		}
	})
	addFood(foods, "ENCHANTED_GOLDEN_APPLE", {
		hunger = 4,
		saturation = 9.6,
		stackSize = 64,
		effects = {
			{type = "regeneration", level = 5, duration = 20},
			{type = "absorption", level = 4, duration = 120},
			{type = "fire_resistance", level = 1, duration = 300},
			{type = "resistance", level = 1, duration = 300}
		}
	})
	addFood(foods, "GOLDEN_CARROT", {
		hunger = 6,
		saturation = 14.4,
		stackSize = 64,
		effects = {}
	})

	-- Stew/Soup Items (stack size: 1)
	addFood(foods, "BEETROOT_SOUP", {
		hunger = 6,
		saturation = 7.2,
		stackSize = 1,
		effects = {}
	})
	addFood(foods, "MUSHROOM_STEW", {
		hunger = 6,
		saturation = 7.2,
		stackSize = 1,
		effects = {}
	})
	addFood(foods, "RABBIT_STEW", {
		hunger = 10,
		saturation = 12.0,
		stackSize = 1,
		effects = {}
	})

	-- Raw Meats
	addFood(foods, "BEEF", {
		hunger = 3,
		saturation = 1.8,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "CHICKEN", {
		hunger = 2,
		saturation = 1.2,
		stackSize = 64,
		effects = {
			{type = "hunger", level = 1, duration = 30, chance = 0.3}
		}
	})
	addFood(foods, "MUTTON", {
		hunger = 2,
		saturation = 1.2,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "PORKCHOP", {
		hunger = 3,
		saturation = 1.8,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "RABBIT", {
		hunger = 3,
		saturation = 1.8,
		stackSize = 64,
		effects = {}
	})

	-- Raw Fish
	addFood(foods, "COD", {
		hunger = 2,
		saturation = 0.4,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "SALMON", {
		hunger = 2,
		saturation = 0.4,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "TROPICAL_FISH", {
		hunger = 1,
		saturation = 0.2,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "PUFFERFISH", {
		hunger = 1,
		saturation = 0.2,
		stackSize = 64,
		effects = {
			{type = "hunger", level = 3, duration = 15},
			{type = "nausea", level = 1, duration = 15},
			{type = "poison", level = 1, duration = 60}
		}
	})

	-- Cooked Fish
	addFood(foods, "COOKED_COD", {
		hunger = 5,
		saturation = 6.0,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "COOKED_SALMON", {
		hunger = 6,
		saturation = 9.6,
		stackSize = 64,
		effects = {}
	})

	-- Other Foods
	addFood(foods, "COOKIE", {
		hunger = 2,
		saturation = 0.4,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "MELON_SLICE", {
		hunger = 2,
		saturation = 1.2,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "DRIED_KELP", {
		hunger = 1,
		saturation = 0.6,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "PUMPKIN_PIE", {
		hunger = 8,
		saturation = 4.8,
		stackSize = 64,
		effects = {}
	})
	addFood(foods, "ROTTEN_FLESH", {
		hunger = 4,
		saturation = 0.8,
		stackSize = 64,
		effects = {
			{type = "hunger", level = 1, duration = 30, chance = 0.8}
		}
	})
	addFood(foods, "SPIDER_EYE", {
		hunger = 2,
		saturation = 3.2,
		stackSize = 64,
		effects = {
			{type = "poison", level = 1, duration = 4}
		}
	})
	addFood(foods, "POISONOUS_POTATO", {
		hunger = 2,
		saturation = 1.2,
		stackSize = 64,
		effects = {
			{type = "poison", level = 1, duration = 4, chance = 0.6}
		}
	})
	addFood(foods, "CHORUS_FRUIT", {
		hunger = 4,
		saturation = 2.4,
		stackSize = 64,
		effects = {
			{type = "teleport"}
		}
	})

	return foods
end

FoodConfig.Foods = buildFoodsTable()

-- Hunger depletion rates (per second, unless noted)
FoodConfig.HungerDepletion = {
	walking = 0.01,      -- Per second while walking
	sprinting = 0.1,     -- Per second while sprinting
	jumping = 0.05,      -- Per jump
	swimming = 0.015,    -- Per second while swimming
	mining = 0.005,      -- Per block mined
	attacking = 0.1      -- Per hit/attack
}

-- Health regeneration requirements
FoodConfig.HealthRegen = {
	minHunger = 18,      -- Minimum hunger required
	minSaturation = 0.1, -- Minimum saturation required (any > 0)
	healAmount = 1,      -- HP healed per tick
	healInterval = 0.5  -- Seconds between heals
}

-- Starvation damage configuration
FoodConfig.Starvation = {
	damageThreshold = 6,  -- Hunger below this causes damage
	damageAmount = 1,     -- HP damaged per tick
	damageInterval = 4   -- Seconds between damage ticks
}

-- Eating mechanics
FoodConfig.Eating = {
	duration = 1.6,        -- Seconds to complete eating
	cooldown = 0.5,        -- Seconds cooldown after eating
	cancelOnMove = true,   -- Cancel if player moves
	cancelOnDamage = true, -- Cancel if player takes damage
	cancelOnItemSwitch = true -- Cancel if player switches items
}

-- Check if an item ID is a food item
function FoodConfig.IsFood(itemId)
	return FoodConfig.Foods[itemId] ~= nil
end

-- Get food configuration for an item
function FoodConfig.GetFoodConfig(itemId)
	return FoodConfig.Foods[itemId]
end

-- Get hunger restoration value
function FoodConfig.GetHunger(itemId)
	local food = FoodConfig.Foods[itemId]
	return food and food.hunger or 0
end

-- Get saturation restoration value
function FoodConfig.GetSaturation(itemId)
	local food = FoodConfig.Foods[itemId]
	return food and food.saturation or 0
end

-- Get stack size for food item
function FoodConfig.GetStackSize(itemId)
	local food = FoodConfig.Foods[itemId]
	return food and food.stackSize or 64 -- Default stack size
end

-- Get special effects for food item
function FoodConfig.GetEffects(itemId)
	local food = FoodConfig.Foods[itemId]
	return food and food.effects or {}
end

return FoodConfig
