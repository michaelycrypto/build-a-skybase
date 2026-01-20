--[[
	ItemPixelSizes.lua
	Item pixel sizes calculated from texture files.
	Generated automatically by calculateItemPixelSizes.js
	Used for proper scaling of items in viewmodels, dropped items, and held item rendering.
]]

local ItemPixelSizes = {}

-- Item pixel sizes calculated from texture files
-- Keys match display names from BlockRegistry/ToolConfig (as returned by ItemRegistry.GetItemName)
local ITEM_PX_SIZES = {
	-- Tools (special sizes)
	["Sword"] = {x = 14, y = 14},
	["Axe"] = {x = 12, y = 14},
	["Shovel"] = {x = 12, y = 12},
	["Pickaxe"] = {x = 13, y = 13},
	["Bow"] = {x = 14, y = 14},
	["Arrow"] = {x = 14, y = 13},

	-- Food items (using display names from BlockRegistry)
	["Apple"] = {x = 12, y = 13},
	["Baked Potato"] = {x = 11, y = 13},
	["Raw Beef"] = {x = 14, y = 10},
	["Beetroot"] = {x = 11, y = 10},
	["Beetroot Seeds"] = {x = 13, y = 13},
	["Beetroot Soup"] = {x = 12, y = 8},
	["Bone Meal"] = {x = 8, y = 15},
	["Bread"] = {x = 13, y = 11},
	["Bucket"] = {x = 10, y = 11},
	["Cake"] = {x = 14, y = 12},
	["Carrot"] = {x = 16, y = 14},
	["Raw Chicken"] = {x = 12, y = 15},
	["Chorus Fruit"] = {x = 12, y = 13},
	["Cocoa Beans"] = {x = 8, y = 15},
	["Raw Cod"] = {x = 13, y = 14},
	["Cod Bucket"] = {x = 10, y = 11},
	["Cooked Beef"] = {x = 14, y = 10},
	["Cooked Chicken"] = {x = 12, y = 15},
	["Cooked Cod"] = {x = 11, y = 7},
	["Cooked Mutton"] = {x = 13, y = 10},
	["Cooked Porkchop"] = {x = 13, y = 14},
	["Cooked Rabbit"] = {x = 14, y = 14},
	["Cooked Salmon"] = {x = 11, y = 7},
	["Cookie"] = {x = 14, y = 10},
	["Dried Kelp"] = {x = 14, y = 14},
	["Egg"] = {x = 8, y = 10},
	["Glistering Melon Slice"] = {x = 14, y = 14},
	["Golden Apple"] = {x = 12, y = 13},
	["Enchanted Golden Apple"] = {x = 12, y = 13},
	["Golden Carrot"] = {x = 9, y = 15},
	["Kelp"] = {x = 14, y = 14},
	["Melon Seeds"] = {x = 13, y = 13},
	["Melon Slice"] = {x = 14, y = 14},
	["Milk Bucket"] = {x = 10, y = 11},
	["Mushroom Stew"] = {x = 12, y = 9},
	["Raw Mutton"] = {x = 13, y = 10},
	["Nether Wart"] = {x = 8, y = 12},
	["Poisonous Potato"] = {x = 11, y = 11},
	["Popped Chorus Fruit"] = {x = 12, y = 11},
	["Raw Porkchop"] = {x = 13, y = 14},
	["Potato"] = {x = 11, y = 13},
	["Pufferfish"] = {x = 15, y = 14},
	["Pufferfish Bucket"] = {x = 12, y = 15},
	["Pumpkin Pie"] = {x = 13, y = 10},
	["Pumpkin Seeds"] = {x = 13, y = 13},
	["Raw Rabbit"] = {x = 14, y = 14},
	["Rabbit Stew"] = {x = 12, y = 8},
	["Rotten Flesh"] = {x = 14, y = 14},
	["Raw Salmon"] = {x = 13, y = 14},
	["Salmon Bucket"] = {x = 10, y = 12},
	["Spider Eye"] = {x = 10, y = 13},
	["Sugar"] = {x = 14, y = 14},
	["Sugar Cane"] = {x = 14, y = 16},
	["Tropical Fish"] = {x = 11, y = 12},
	["Tropical Fish Bucket"] = {x = 10, y = 12},
	["Turtle Egg"] = {x = 10, y = 11},
	["Water Bucket"] = {x = 10, y = 11},
	["Wheat"] = {x = 14, y = 15},
	["Wheat Seeds"] = {x = 13, y = 13},
}

--[[
	Get pixel size for an item by name
	@param itemName: string - Item name (e.g., "apple", "Sword")
	@return: table | nil - {x = number, y = number} or nil if not found
]]
function ItemPixelSizes.GetSize(itemName)
	return ITEM_PX_SIZES[itemName]
end

--[[
	Get all pixel sizes
	@return: table - Copy of ITEM_PX_SIZES
]]
function ItemPixelSizes.GetAllSizes()
	local copy = {}
	for key, value in pairs(ITEM_PX_SIZES) do
		copy[key] = value
	end
	return copy
end

-- Export the table directly for backward compatibility
ItemPixelSizes.ITEM_PX_SIZES = ITEM_PX_SIZES

return ItemPixelSizes
