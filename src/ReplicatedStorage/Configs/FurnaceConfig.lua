--[[
	FurnaceConfig.lua
	Configuration for the Minecraft-style auto-smelting furnace
	
	Features:
	- Fuel types with burn times
	- Smeltable items with output mappings
	- Auto-smelting timing configuration
]]

local Constants = require(script.Parent.Parent.Shared.VoxelWorld.Core.Constants)
local BlockType = Constants.BlockType

local FurnaceConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- TIMING CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Time to smelt one item (in seconds)
FurnaceConfig.SMELT_TIME = 10

-- Maximum interaction distance (studs) - 6 blocks * 3 studs
FurnaceConfig.MAX_INTERACTION_DISTANCE = 18

-- Server tick rate for furnace processing (seconds)
FurnaceConfig.TICK_RATE = 0.5

-- ═══════════════════════════════════════════════════════════════════════════
-- FUEL TYPES
-- Each fuel has a burn duration (in seconds) that determines how many items
-- can be smelted before the fuel is consumed.
-- Items smelted = burnTime / SMELT_TIME
-- ═══════════════════════════════════════════════════════════════════════════

FurnaceConfig.FuelTypes = {
	-- Coal family (best efficiency)
	[BlockType.COAL] = {
		burnTime = 80,      -- Smelts 8 items
		name = "Coal",
	},
	[BlockType.COAL_BLOCK] = {
		burnTime = 800,     -- Smelts 80 items (9x coal + bonus)
		name = "Block of Coal",
	},
	
	-- Wood planks (decent efficiency)
	[BlockType.OAK_PLANKS] = {
		burnTime = 15,      -- Smelts 1.5 items
		name = "Oak Planks",
	},
	[BlockType.SPRUCE_PLANKS] = {
		burnTime = 15,
		name = "Spruce Planks",
	},
	[BlockType.BIRCH_PLANKS] = {
		burnTime = 15,
		name = "Birch Planks",
	},
	[BlockType.JUNGLE_PLANKS] = {
		burnTime = 15,
		name = "Jungle Planks",
	},
	[BlockType.DARK_OAK_PLANKS] = {
		burnTime = 15,
		name = "Dark Oak Planks",
	},
	[BlockType.ACACIA_PLANKS] = {
		burnTime = 15,
		name = "Acacia Planks",
	},
	[BlockType.MANGROVE_PLANKS] = {
		burnTime = 15,
		name = "Mangrove Planks",
	},
	[BlockType.CRIMSON_PLANKS] = {
		burnTime = 15,
		name = "Crimson Planks",
	},
	[BlockType.WARPED_PLANKS] = {
		burnTime = 15,
		name = "Warped Planks",
	},
	
	-- Logs (same as planks, slightly inefficient)
	[BlockType.WOOD] = {
		burnTime = 15,
		name = "Oak Log",
	},
	[BlockType.SPRUCE_LOG] = {
		burnTime = 15,
		name = "Spruce Log",
	},
	[BlockType.BIRCH_LOG] = {
		burnTime = 15,
		name = "Birch Log",
	},
	[BlockType.JUNGLE_LOG] = {
		burnTime = 15,
		name = "Jungle Log",
	},
	[BlockType.DARK_OAK_LOG] = {
		burnTime = 15,
		name = "Dark Oak Log",
	},
	[BlockType.ACACIA_LOG] = {
		burnTime = 15,
		name = "Acacia Log",
	},
	[BlockType.MANGROVE_LOG] = {
		burnTime = 15,
		name = "Mangrove Log",
	},
	
	-- Sticks (low efficiency)
	[BlockType.STICK] = {
		burnTime = 5,       -- Smelts 0.5 items
		name = "Stick",
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SMELTABLE ITEMS (RECIPES)
-- Maps input item ID to output item ID
-- All items take SMELT_TIME seconds to process
-- ═══════════════════════════════════════════════════════════════════════════

FurnaceConfig.Recipes = {
	-- Ore smelting (raw ore → ingot)
	[BlockType.COPPER_ORE] = {
		output = BlockType.COPPER_INGOT,
		name = "Copper Ingot",
	},
	[BlockType.IRON_ORE] = {
		output = BlockType.IRON_INGOT,
		name = "Iron Ingot",
	},
	
	-- Material processing
	[BlockType.SAND] = {
		output = BlockType.GLASS,
		name = "Glass",
	},
	[BlockType.COBBLESTONE] = {
		output = BlockType.STONE,
		name = "Stone",
	},
	[BlockType.CLAY_BLOCK] = {
		output = BlockType.TERRACOTTA,
		name = "Terracotta",
	},
	
	-- Wood to charcoal (logs only)
	[BlockType.WOOD] = {
		output = BlockType.COAL,  -- Using coal as charcoal placeholder
		name = "Charcoal",
	},
	[BlockType.SPRUCE_LOG] = {
		output = BlockType.COAL,
		name = "Charcoal",
	},
	[BlockType.BIRCH_LOG] = {
		output = BlockType.COAL,
		name = "Charcoal",
	},
	[BlockType.JUNGLE_LOG] = {
		output = BlockType.COAL,
		name = "Charcoal",
	},
	[BlockType.DARK_OAK_LOG] = {
		output = BlockType.COAL,
		name = "Charcoal",
	},
	[BlockType.ACACIA_LOG] = {
		output = BlockType.COAL,
		name = "Charcoal",
	},
	
	-- Food cooking
	[BlockType.BEEF] = {
		output = BlockType.COOKED_BEEF,
		name = "Steak",
	},
	[BlockType.PORKCHOP] = {
		output = BlockType.COOKED_PORKCHOP,
		name = "Cooked Porkchop",
	},
	[BlockType.CHICKEN] = {
		output = BlockType.COOKED_CHICKEN,
		name = "Cooked Chicken",
	},
	[BlockType.MUTTON] = {
		output = BlockType.COOKED_MUTTON,
		name = "Cooked Mutton",
	},
	[BlockType.RABBIT] = {
		output = BlockType.COOKED_RABBIT,
		name = "Cooked Rabbit",
	},
	[BlockType.COD] = {
		output = BlockType.COOKED_COD,
		name = "Cooked Cod",
	},
	[BlockType.SALMON] = {
		output = BlockType.COOKED_SALMON,
		name = "Cooked Salmon",
	},
	[BlockType.POTATO] = {
		output = BlockType.BAKED_POTATO,
		name = "Baked Potato",
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

--[[
	Check if an item can be used as fuel
	@param itemId: number - Item ID to check
	@return: boolean, number? - canBeFuel, burnTime
]]
function FurnaceConfig:IsFuel(itemId)
	local fuelData = self.FuelTypes[itemId]
	if fuelData then
		return true, fuelData.burnTime
	end
	return false, nil
end

--[[
	Get fuel burn time for an item
	@param itemId: number - Item ID
	@return: number? - Burn time in seconds, or nil if not fuel
]]
function FurnaceConfig:GetFuelBurnTime(itemId)
	local fuelData = self.FuelTypes[itemId]
	return fuelData and fuelData.burnTime or nil
end

--[[
	Check if an item can be smelted
	@param itemId: number - Item ID to check
	@return: boolean - True if item has a smelting recipe
]]
function FurnaceConfig:IsSmeltable(itemId)
	return self.Recipes[itemId] ~= nil
end

--[[
	Get the output item for a smeltable input
	@param inputItemId: number - Input item ID
	@return: number? - Output item ID, or nil if not smeltable
]]
function FurnaceConfig:GetSmeltOutput(inputItemId)
	local recipe = self.Recipes[inputItemId]
	return recipe and recipe.output or nil
end

--[[
	Get recipe info for a smeltable item
	@param inputItemId: number - Input item ID
	@return: table? - Recipe data {output, name}, or nil
]]
function FurnaceConfig:GetRecipe(inputItemId)
	return self.Recipes[inputItemId]
end

--[[
	Calculate how many items a fuel source can smelt
	@param itemId: number - Fuel item ID
	@return: number - Number of items that can be smelted (can be fractional)
]]
function FurnaceConfig:GetFuelEfficiency(itemId)
	local burnTime = self:GetFuelBurnTime(itemId)
	if burnTime then
		return burnTime / self.SMELT_TIME
	end
	return 0
end

--[[
	Get all smeltable recipes as a list
	@return: table[] - Array of {inputId, outputId, name}
]]
function FurnaceConfig:GetAllRecipes()
	local recipes = {}
	for inputId, data in pairs(self.Recipes) do
		table.insert(recipes, {
			inputId = inputId,
			outputId = data.output,
			name = data.name,
		})
	end
	return recipes
end

--[[
	Get all fuel types as a list
	@return: table[] - Array of {itemId, burnTime, name, efficiency}
]]
function FurnaceConfig:GetAllFuels()
	local fuels = {}
	for itemId, data in pairs(self.FuelTypes) do
		table.insert(fuels, {
			itemId = itemId,
			burnTime = data.burnTime,
			name = data.name,
			efficiency = data.burnTime / self.SMELT_TIME,
		})
	end
	-- Sort by efficiency (best first)
	table.sort(fuels, function(a, b)
		return a.efficiency > b.efficiency
	end)
	return fuels
end

return FurnaceConfig
