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
	["Apple"] = {x = 12, y = 13},
	["Baked Potato"] = {x = 11, y = 13},
	["Beef"] = {x = 14, y = 10},
	["Beetroot"] = {x = 11, y = 10},
	["Beetroot Seeds"] = {x = 13, y = 13},
	["Beetroot Soup"] = {x = 12, y = 8},
	["Black Dye"] = {x = 8, y = 15},
	["Blue Book"] = {x = 14, y = 10},
	["Blue Dye"] = {x = 8, y = 15},
	["Bluesteel Arrow"] = {x = 12, y = 12},
	["Bluesteel Axe"] = {x = 12, y = 14},
	["Bluesteel Boots"] = {x = 14, y = 7},
	["Bluesteel Chestplate"] = {x = 12, y = 10},
	["Bluesteel Dust"] = {x = 13, y = 8},
	["Bluesteel Helmet"] = {x = 10, y = 9},
	["Bluesteel Ingot"] = {x = 14, y = 9},
	["Bluesteel Leggings"] = {x = 8, y = 9},
	["Bluesteel Pickaxe"] = {x = 13, y = 13},
	["Bluesteel Shovel"] = {x = 13, y = 13},
	["Bluesteel Sword"] = {x = 13, y = 13},
	["Bone"] = {x = 15, y = 15},
	["Bone Dust"] = {x = 8, y = 15},
	["Bow"] = {x = 15, y = 15},
	["Bow Pulling 0"] = {x = 15, y = 15},
	["Bow Pulling 1"] = {x = 15, y = 15},
	["Bow Pulling 2"] = {x = 15, y = 15},
	["Bow_pulling_0"] = {x = 15, y = 15},
	["Bow_pulling_1"] = {x = 15, y = 15},
	["Bow_pulling_2"] = {x = 15, y = 15},
	["Bowl"] = {x = 12, y = 8},
	["Bread"] = {x = 13, y = 11},
	["Bucket"] = {x = 10, y = 11},
	["Carrot"] = {x = 16, y = 14},
	["Charcoal"] = {x = 10, y = 11},
	["Chicken"] = {x = 12, y = 15},
	["Coal"] = {x = 12, y = 15},
	["Cooked Beef"] = {x = 14, y = 10},
	["Cooked Chicken"] = {x = 12, y = 15},
	["Cooked Mutton"] = {x = 13, y = 10},
	["Cooked Porkchop"] = {x = 13, y = 14},
	["Cookie"] = {x = 14, y = 10},
	["Copper Arrow"] = {x = 12, y = 12},
	["Copper Axe"] = {x = 12, y = 14},
	["Copper Boots"] = {x = 14, y = 7},
	["Copper Chestplate"] = {x = 12, y = 10},
	["Copper Helmet"] = {x = 10, y = 9},
	["Copper Ingot"] = {x = 14, y = 9},
	["Copper Leggings"] = {x = 8, y = 9},
	["Copper Pickaxe"] = {x = 13, y = 13},
	["Copper Shovel"] = {x = 13, y = 13},
	["Copper Sword"] = {x = 13, y = 13},
	["Cyan Dye"] = {x = 8, y = 15},
	["Egg"] = {x = 8, y = 10},
	["Emerald"] = {x = 9, y = 11},
	["Enchanted Book"] = {x = 14, y = 10},
	["Fallen Star"] = {x = 12, y = 14},
	["Feather"] = {x = 13, y = 15},
	["Fishing Rod"] = {x = 16, y = 14},
	["Fishing Rod Cast"] = {x = 15, y = 14},
	["Flint"] = {x = 9, y = 12},
	["Flint And Steel"] = {x = 11, y = 16},
	["Glass Bottle"] = {x = 7, y = 10},
	["Golden Apple"] = {x = 12, y = 13},
	["Gray Dye"] = {x = 8, y = 15},
	["Green Book"] = {x = 14, y = 10},
	["Green Dye"] = {x = 8, y = 15},
	["Iron Arrow"] = {x = 12, y = 12},
	["Iron Axe"] = {x = 12, y = 14},
	["Iron Boots"] = {x = 14, y = 7},
	["Iron Chestplate"] = {x = 12, y = 10},
	["Iron Helmet"] = {x = 10, y = 9},
	["Iron Ingot"] = {x = 14, y = 9},
	["Iron Leggings"] = {x = 8, y = 9},
	["Iron Pickaxe"] = {x = 13, y = 13},
	["Iron Shovel"] = {x = 13, y = 13},
	["Iron Sword"] = {x = 13, y = 13},
	["Lava Bucket"] = {x = 10, y = 11},
	["Leather"] = {x = 12, y = 13},
	["Light Blue Dye"] = {x = 8, y = 15},
	["Light Gray Dye"] = {x = 8, y = 15},
	["Lime Dye"] = {x = 8, y = 15},
	["Magenta Dye"] = {x = 8, y = 15},
	["Melon Seeds"] = {x = 13, y = 13},
	["Melon Slice"] = {x = 14, y = 14},
	["Mushroom Stew"] = {x = 12, y = 9},
	["Mutton"] = {x = 13, y = 10},
	["Orange Dye"] = {x = 8, y = 15},
	["Paper"] = {x = 13, y = 14},
	["Pearl"] = {x = 11, y = 11},
	["Pink Dye"] = {x = 8, y = 15},
	["Porkchop"] = {x = 13, y = 14},
	["Potato"] = {x = 11, y = 13},
	["Pumpkin Pie"] = {x = 13, y = 10},
	["Pumpkin Seeds"] = {x = 13, y = 13},
	["Purple Dye"] = {x = 8, y = 15},
	["Quartz"] = {x = 13, y = 14},
	["Red Book"] = {x = 14, y = 10},
	["Rose Red"] = {x = 8, y = 15},
	["Rotten Flesh"] = {x = 14, y = 14},
	["Ruby"] = {x = 10, y = 10},
	["Shears"] = {x = 14, y = 14},
	["Spawn Egg"] = {x = 10, y = 12},
	["Spider Eye"] = {x = 10, y = 13},
	["Steel Arrow"] = {x = 12, y = 12},
	["Steel Axe"] = {x = 12, y = 14},
	["Steel Boots"] = {x = 14, y = 7},
	["Steel Chestplate"] = {x = 12, y = 10},
	["Steel Helmet"] = {x = 10, y = 9},
	["Steel Ingot"] = {x = 14, y = 9},
	["Steel Leggings"] = {x = 8, y = 9},
	["Steel Pickaxe"] = {x = 13, y = 13},
	["Steel Shovel"] = {x = 13, y = 13},
	["Steel Sword"] = {x = 13, y = 13},
	["Stick"] = {x = 13, y = 13},
	["String"] = {x = 12, y = 12},
	["Sugar"] = {x = 14, y = 14},
	["Sugar Cane"] = {x = 14, y = 16},
	["Water Bucket"] = {x = 10, y = 11},
	["Wheat"] = {x = 14, y = 15},
	["Wheat Seeds"] = {x = 13, y = 13},
	["Writable Book"] = {x = 14, y = 14},
	["Yellow Dye"] = {x = 8, y = 15}
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
