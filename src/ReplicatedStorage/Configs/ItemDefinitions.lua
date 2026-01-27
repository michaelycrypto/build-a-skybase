--[[
	ItemDefinitions.lua
	═══════════════════════════════════════════════════════════════════════════
	SINGLE SOURCE OF TRUTH FOR ALL ITEMS
	═══════════════════════════════════════════════════════════════════════════

	This file defines ALL items in the game. Other configs read from here.

	CATEGORIES determine item behavior:
	- TOOL: Mining tools (pickaxe, axe, shovel) - affect mining speed
	- WEAPON: Combat items (sword) - deal damage
	- RANGED: Bow - shoots projectiles
	- ARMOR: Protection gear - provides defense
	- ARROW: Ammunition - consumed by ranged weapons
	- FOOD: Consumables - restore hunger
	- MATERIAL: Crafting ingredients - no direct use
	- DYE: Coloring items - apply to blocks/items
	- MOB_EGG: Spawn eggs - spawn entities
	- BLOCK: Placeable items - world interaction

	ID RANGES:
	  1-99:     Core blocks (dirt, stone, wood, etc.)
	  100-199:  Ores, ingots, materials
	  200-299:  Food items
	  1001-1099: Tools (pickaxes, axes, shovels)
	  1101-1199: Weapons (swords)
	  1201-1299: Ranged (bow)
	  2001-2099: Arrows
	  3001-3099: Armor
	  4001-4099: Spawn eggs
	  5001-5099: Dyes
]]

local ItemDefinitions = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CATEGORY SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Category = {
	TOOL = "tool",        -- Pickaxe, Axe, Shovel (mining)
	WEAPON = "weapon",    -- Sword (melee combat)
	RANGED = "ranged",    -- Bow (projectile combat)
	ARMOR = "armor",      -- Helmet, Chestplate, Leggings, Boots
	ARROW = "arrow",      -- Ammunition for ranged
	FOOD = "food",        -- Consumables
	MATERIAL = "material",-- Crafting ingredients
	DYE = "dye",          -- Coloring items
	MOB_EGG = "mob_egg",  -- Spawn eggs
	BLOCK = "block",      -- Placeable blocks
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TIER SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Tiers = {
	NONE = 0,
	COPPER = 1,
	IRON = 2,
	STEEL = 3,
	BLUESTEEL = 4,
}

ItemDefinitions.TierColors = {
	[1] = Color3.fromRGB(188, 105, 47),   -- Copper
	[2] = Color3.fromRGB(122, 122, 122),  -- Iron
	[3] = Color3.fromRGB(173, 173, 173),  -- Steel
	[4] = Color3.fromRGB(149, 190, 246),  -- Bluesteel
}

ItemDefinitions.TierNames = {
	[0] = "None",
	[1] = "Copper",
	[2] = "Iron",
	[3] = "Steel",
	[4] = "Bluesteel",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOOLS (Mining: Pickaxe, Axe, Shovel)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Tools = {
	-- PICKAXES (1001-1004)
	COPPER_PICKAXE =    { id = 1001, name = "Copper Pickaxe",    category = "tool", toolType = "pickaxe", tier = 1, texture = "rbxassetid://128947615086427" },
	IRON_PICKAXE =      { id = 1002, name = "Iron Pickaxe",      category = "tool", toolType = "pickaxe", tier = 2, texture = "rbxassetid://90422189544555" },
	STEEL_PICKAXE =     { id = 1003, name = "Steel Pickaxe",     category = "tool", toolType = "pickaxe", tier = 3, texture = "rbxassetid://79239885085319" },
	BLUESTEEL_PICKAXE = { id = 1004, name = "Bluesteel Pickaxe", category = "tool", toolType = "pickaxe", tier = 4, texture = "rbxassetid://78773213138783" },

	-- AXES (1011-1014)
	COPPER_AXE =    { id = 1011, name = "Copper Axe",    category = "tool", toolType = "axe", tier = 1, texture = "rbxassetid://113405300734786" },
	IRON_AXE =      { id = 1012, name = "Iron Axe",      category = "tool", toolType = "axe", tier = 2, texture = "rbxassetid://83988909828608" },
	STEEL_AXE =     { id = 1013, name = "Steel Axe",     category = "tool", toolType = "axe", tier = 3, texture = "rbxassetid://114291626046105" },
	BLUESTEEL_AXE = { id = 1014, name = "Bluesteel Axe", category = "tool", toolType = "axe", tier = 4, texture = "rbxassetid://79374639327483" },

	-- SHOVELS (1021-1024)
	COPPER_SHOVEL =    { id = 1021, name = "Copper Shovel",    category = "tool", toolType = "shovel", tier = 1, texture = "rbxassetid://97111593512086" },
	IRON_SHOVEL =      { id = 1022, name = "Iron Shovel",      category = "tool", toolType = "shovel", tier = 2, texture = "rbxassetid://137269837100155" },
	STEEL_SHOVEL =     { id = 1023, name = "Steel Shovel",     category = "tool", toolType = "shovel", tier = 3, texture = "rbxassetid://114823510951232" },
	BLUESTEEL_SHOVEL = { id = 1024, name = "Bluesteel Shovel", category = "tool", toolType = "shovel", tier = 4, texture = "rbxassetid://130333676635510" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- WEAPONS (Melee Combat: Sword)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Weapons = {
	COPPER_SWORD =    { id = 1041, name = "Copper Sword",    category = "weapon", weaponType = "sword", tier = 1, texture = "rbxassetid://139473111443819" },
	IRON_SWORD =      { id = 1042, name = "Iron Sword",      category = "weapon", weaponType = "sword", tier = 2, texture = "rbxassetid://88350899156447" },
	STEEL_SWORD =     { id = 1043, name = "Steel Sword",     category = "weapon", weaponType = "sword", tier = 3, texture = "rbxassetid://72684086705746" },
	BLUESTEEL_SWORD = { id = 1044, name = "Bluesteel Sword", category = "weapon", weaponType = "sword", tier = 4, texture = "rbxassetid://114493455671228" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- RANGED (Projectile Combat: Bow)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Ranged = {
	BOW = { id = 1051, name = "Bow", category = "ranged", tier = 1, texture = "rbxassetid://99844472348258" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITY TOOLS (Non-combat tools)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.UtilityTools = {
	SHEARS =          { id = 1061, name = "Shears",          category = "tool", toolType = "shears",   tier = 0, texture = "rbxassetid://139096196695198" },
	FISHING_ROD =     { id = 1062, name = "Fishing Rod",     category = "tool", toolType = "fishing",  tier = 0, texture = "rbxassetid://139096196695198" },
	FLINT_AND_STEEL = { id = 1063, name = "Flint And Steel", category = "tool", toolType = "igniter",  tier = 0, texture = "rbxassetid://139096196695198" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- BOOKS
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Books = {
	WRITABLE_BOOK =   { id = 270, name = "Writable Book",   category = "material", texture = "rbxassetid://139096196695198" },
	ENCHANTED_BOOK =  { id = 271, name = "Enchanted Book",  category = "material", texture = "rbxassetid://139096196695198" },
	BLUE_BOOK =       { id = 272, name = "Blue Book",       category = "material", texture = "rbxassetid://139096196695198" },
	GREEN_BOOK =      { id = 273, name = "Green Book",      category = "material", texture = "rbxassetid://139096196695198" },
	RED_BOOK =        { id = 274, name = "Red Book",        category = "material", texture = "rbxassetid://139096196695198" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ARROWS (Ammunition)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Arrows = {
	COPPER_ARROW =    { id = 2001, name = "Copper Arrow",    category = "arrow", tier = 1, texture = "rbxassetid://78321595602062", stackable = true, maxStack = 64 },
	IRON_ARROW =      { id = 2002, name = "Iron Arrow",      category = "arrow", tier = 2, texture = "rbxassetid://78321595602062", stackable = true, maxStack = 64 },
	STEEL_ARROW =     { id = 2003, name = "Steel Arrow",     category = "arrow", tier = 3, texture = "rbxassetid://78321595602062", stackable = true, maxStack = 64 },
	BLUESTEEL_ARROW = { id = 2004, name = "Bluesteel Arrow", category = "arrow", tier = 4, texture = "rbxassetid://78321595602062", stackable = true, maxStack = 64 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ARMOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Defense values per tier: { helmet, chestplate, leggings, boots }
local ArmorDefense = {
	[1] = { helmet = 1, chestplate = 2, leggings = 2, boots = 1, toughness = 0 },
	[2] = { helmet = 2, chestplate = 4, leggings = 3, boots = 1, toughness = 0 },
	[3] = { helmet = 2, chestplate = 5, leggings = 4, boots = 2, toughness = 0 },
	[4] = { helmet = 3, chestplate = 6, leggings = 5, boots = 2, toughness = 1 },
}

ItemDefinitions.Armor = {
	-- COPPER ARMOR (3001-3004)
	COPPER_HELMET =     { id = 3001, name = "Copper Helmet",     category = "armor", slot = "helmet",     tier = 1, texture = "rbxassetid://126048124614409" },
	COPPER_CHESTPLATE = { id = 3002, name = "Copper Chestplate", category = "armor", slot = "chestplate", tier = 1, texture = "rbxassetid://89778243976291" },
	COPPER_LEGGINGS =   { id = 3003, name = "Copper Leggings",   category = "armor", slot = "leggings",   tier = 1, texture = "rbxassetid://114975984936435" },
	COPPER_BOOTS =      { id = 3004, name = "Copper Boots",      category = "armor", slot = "boots",      tier = 1, texture = "rbxassetid://72491546589107" },

	-- IRON ARMOR (3005-3008)
	IRON_HELMET =     { id = 3005, name = "Iron Helmet",     category = "armor", slot = "helmet",     tier = 2, texture = "rbxassetid://122225724433670" },
	IRON_CHESTPLATE = { id = 3006, name = "Iron Chestplate", category = "armor", slot = "chestplate", tier = 2, texture = "rbxassetid://131613353335099" },
	IRON_LEGGINGS =   { id = 3007, name = "Iron Leggings",   category = "armor", slot = "leggings",   tier = 2, texture = "rbxassetid://75809753542420" },
	IRON_BOOTS =      { id = 3008, name = "Iron Boots",      category = "armor", slot = "boots",      tier = 2, texture = "rbxassetid://108013738218975" },

	-- STEEL ARMOR (3009-3012)
	STEEL_HELMET =     { id = 3009, name = "Steel Helmet",     category = "armor", slot = "helmet",     tier = 3, texture = "rbxassetid://132418834328833" },
	STEEL_CHESTPLATE = { id = 3010, name = "Steel Chestplate", category = "armor", slot = "chestplate", tier = 3, texture = "rbxassetid://105921740804226" },
	STEEL_LEGGINGS =   { id = 3011, name = "Steel Leggings",   category = "armor", slot = "leggings",   tier = 3, texture = "rbxassetid://92040368920341" },
	STEEL_BOOTS =      { id = 3012, name = "Steel Boots",      category = "armor", slot = "boots",      tier = 3, texture = "rbxassetid://86491440244351" },

	-- BLUESTEEL ARMOR (3013-3016)
	BLUESTEEL_HELMET =     { id = 3013, name = "Bluesteel Helmet",     category = "armor", slot = "helmet",     tier = 4, texture = "rbxassetid://108327379558098" },
	BLUESTEEL_CHESTPLATE = { id = 3014, name = "Bluesteel Chestplate", category = "armor", slot = "chestplate", tier = 4, texture = "rbxassetid://121636188243090" },
	BLUESTEEL_LEGGINGS =   { id = 3015, name = "Bluesteel Leggings",   category = "armor", slot = "leggings",   tier = 4, texture = "rbxassetid://82601608552864" },
	BLUESTEEL_BOOTS =      { id = 3016, name = "Bluesteel Boots",      category = "armor", slot = "boots",      tier = 4, texture = "rbxassetid://112236445368875" },
}

-- Auto-populate defense/toughness from ArmorDefense table
for _, armor in pairs(ItemDefinitions.Armor) do
	local tierStats = ArmorDefense[armor.tier]
	if tierStats then
		armor.defense = tierStats[armor.slot]
		armor.toughness = tierStats.toughness
		armor.setId = ItemDefinitions.TierNames[armor.tier]:lower()
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FOOD (Consumables)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Food = {
	-- Raw foods
	APPLE =          { id = 201, name = "Apple",          category = "food", hunger = 4, saturation = 2.4, texture = "rbxassetid://119276065058564" },
	BREAD =          { id = 202, name = "Bread",          category = "food", hunger = 5, saturation = 6.0, texture = "rbxassetid://134668764178448" },
	CARROT =         { id = 203, name = "Carrot",         category = "food", hunger = 3, saturation = 3.6, texture = "rbxassetid://133207158082629" },
	POTATO =         { id = 204, name = "Potato",         category = "food", hunger = 1, saturation = 0.6, texture = "rbxassetid://133207158082629" },
	BAKED_POTATO =   { id = 205, name = "Baked Potato",   category = "food", hunger = 5, saturation = 6.0, texture = "rbxassetid://112458163268481" },
	BEETROOT =       { id = 206, name = "Beetroot",       category = "food", hunger = 1, saturation = 1.2, texture = "rbxassetid://133207158082629" },
	MELON_SLICE =    { id = 207, name = "Melon Slice",    category = "food", hunger = 2, saturation = 1.2, texture = "rbxassetid://133207158082629" },
	GOLDEN_APPLE =   { id = 208, name = "Golden Apple",   category = "food", hunger = 4, saturation = 9.6, texture = "rbxassetid://133207158082629" },
	COOKIE =         { id = 209, name = "Cookie",         category = "food", hunger = 2, saturation = 0.4, texture = "rbxassetid://133207158082629" },
	PUMPKIN_PIE =    { id = 210, name = "Pumpkin Pie",    category = "food", hunger = 8, saturation = 4.8, texture = "rbxassetid://133207158082629" },
	MUSHROOM_STEW =  { id = 211, name = "Mushroom Stew",  category = "food", hunger = 6, saturation = 7.2, texture = "rbxassetid://133207158082629", stackable = false },
	BEETROOT_SOUP =  { id = 212, name = "Beetroot Soup",  category = "food", hunger = 6, saturation = 7.2, texture = "rbxassetid://133207158082629", stackable = false },

	-- Raw meats
	BEEF =           { id = 220, name = "Beef",           category = "food", hunger = 3, saturation = 1.8, texture = "rbxassetid://133207158082629" },
	CHICKEN =        { id = 221, name = "Chicken",        category = "food", hunger = 2, saturation = 1.2, texture = "rbxassetid://133207158082629" },
	PORKCHOP =       { id = 222, name = "Porkchop",       category = "food", hunger = 3, saturation = 1.8, texture = "rbxassetid://133207158082629" },
	MUTTON =         { id = 223, name = "Mutton",         category = "food", hunger = 2, saturation = 1.2, texture = "rbxassetid://133207158082629" },

	-- Cooked meats
	COOKED_BEEF =    { id = 230, name = "Cooked Beef",    category = "food", hunger = 8, saturation = 12.8, texture = "rbxassetid://133207158082629" },
	COOKED_CHICKEN = { id = 231, name = "Cooked Chicken", category = "food", hunger = 6, saturation = 7.2, texture = "rbxassetid://133207158082629" },
	COOKED_PORKCHOP ={ id = 232, name = "Cooked Porkchop",category = "food", hunger = 8, saturation = 12.8, texture = "rbxassetid://133207158082629" },
	COOKED_MUTTON =  { id = 233, name = "Cooked Mutton",  category = "food", hunger = 6, saturation = 9.6, texture = "rbxassetid://133207158082629" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALS (Crafting Ingredients)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Materials = {
	-- Basic resources
	COAL =            { id = 32,  name = "Coal",            category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(40, 40, 40) },
	CHARCOAL =        { id = 41,  name = "Charcoal",        category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(50, 50, 50) },
	STICK =           { id = 34,  name = "Stick",           category = "material", texture = "rbxassetid://139096196695198" },
	STRING =          { id = 35,  name = "String",          category = "material", texture = "rbxassetid://139096196695198" },
	FEATHER =         { id = 36,  name = "Feather",         category = "material", texture = "rbxassetid://139096196695198" },
	LEATHER =         { id = 37,  name = "Leather",         category = "material", texture = "rbxassetid://139096196695198" },
	PAPER =           { id = 38,  name = "Paper",           category = "material", texture = "rbxassetid://139096196695198" },
	BONE =            { id = 39,  name = "Bone",            category = "material", texture = "rbxassetid://139096196695198" },
	BONE_DUST =       { id = 42,  name = "Bone Dust",       category = "material", texture = "rbxassetid://139096196695198" },
	FLINT =           { id = 40,  name = "Flint",           category = "material", texture = "rbxassetid://139096196695198" },
	BOWL =            { id = 43,  name = "Bowl",            category = "material", texture = "rbxassetid://139096196695198" },
	EGG =             { id = 44,  name = "Egg",             category = "material", texture = "rbxassetid://139096196695198", stackable = true, maxStack = 16 },
	SUGAR =           { id = 45,  name = "Sugar",           category = "material", texture = "rbxassetid://139096196695198" },
	GLASS_BOTTLE =    { id = 46,  name = "Glass Bottle",    category = "material", texture = "rbxassetid://139096196695198" },

	-- Gems & Precious
	EMERALD =         { id = 47,  name = "Emerald",         category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(80, 200, 120) },
	RUBY =            { id = 48,  name = "Ruby",            category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(224, 17, 95) },
	QUARTZ =          { id = 49,  name = "Quartz",          category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(230, 230, 230) },
	PEARL =           { id = 50,  name = "Pearl",           category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(20, 90, 90) },

	-- Ingots
	IRON_INGOT =      { id = 33,  name = "Iron Ingot",      category = "material", texture = "rbxassetid://116257653070196", color = Color3.fromRGB(122, 122, 122) },
	COPPER_INGOT =    { id = 105, name = "Copper Ingot",    category = "material", texture = "rbxassetid://117987670821375", color = Color3.fromRGB(188, 105, 47) },
	STEEL_INGOT =     { id = 108, name = "Steel Ingot",     category = "material", texture = "rbxassetid://103080988701146", color = Color3.fromRGB(173, 173, 173) },
	BLUESTEEL_INGOT = { id = 109, name = "Bluesteel Ingot", category = "material", texture = "rbxassetid://121436448752857", color = Color3.fromRGB(149, 190, 246) },
	BLUESTEEL_DUST =  { id = 115, name = "Bluesteel Dust",  category = "material", texture = "rbxassetid://122819289085836", color = Color3.fromRGB(149, 190, 246) },

	-- Bucket items
	BUCKET =          { id = 382, name = "Bucket",          category = "material", texture = "rbxassetid://116062981484263", stackable = true, maxStack = 16 },
	WATER_BUCKET =    { id = 383, name = "Water Bucket",    category = "material", texture = "rbxassetid://93357317651884", stackable = false },
	LAVA_BUCKET =     { id = 384, name = "Lava Bucket",     category = "material", texture = "rbxassetid://93357317651884", stackable = false },

	-- Seeds
	WHEAT_SEEDS =     { id = 250, name = "Wheat Seeds",     category = "material", texture = "rbxassetid://139096196695198" },
	BEETROOT_SEEDS =  { id = 251, name = "Beetroot Seeds",  category = "material", texture = "rbxassetid://139096196695198" },
	MELON_SEEDS =     { id = 252, name = "Melon Seeds",     category = "material", texture = "rbxassetid://139096196695198" },
	PUMPKIN_SEEDS =   { id = 253, name = "Pumpkin Seeds",   category = "material", texture = "rbxassetid://139096196695198" },

	-- Special
	FALLEN_STAR =     { id = 260, name = "Fallen Star",     category = "material", texture = "rbxassetid://139096196695198", color = Color3.fromRGB(255, 255, 100) },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DYES
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Dyes = {
	BLACK_DYE =      { id = 5001, name = "Black Dye",      category = "dye", color = Color3.fromRGB(30, 30, 30),    texture = "rbxassetid://139096196695198" },
	BLUE_DYE =       { id = 5002, name = "Blue Dye",       category = "dye", color = Color3.fromRGB(51, 76, 178),   texture = "rbxassetid://139096196695198" },
	CYAN_DYE =       { id = 5003, name = "Cyan Dye",       category = "dye", color = Color3.fromRGB(22, 156, 156), texture = "rbxassetid://139096196695198" },
	GRAY_DYE =       { id = 5004, name = "Gray Dye",       category = "dye", color = Color3.fromRGB(71, 79, 82),    texture = "rbxassetid://139096196695198" },
	GREEN_DYE =      { id = 5005, name = "Green Dye",      category = "dye", color = Color3.fromRGB(94, 124, 22),   texture = "rbxassetid://139096196695198" },
	LIGHT_BLUE_DYE = { id = 5006, name = "Light Blue Dye", category = "dye", color = Color3.fromRGB(58, 179, 218),  texture = "rbxassetid://139096196695198" },
	LIGHT_GRAY_DYE = { id = 5007, name = "Light Gray Dye", category = "dye", color = Color3.fromRGB(142, 142, 134),texture = "rbxassetid://139096196695198" },
	LIME_DYE =       { id = 5008, name = "Lime Dye",       category = "dye", color = Color3.fromRGB(128, 199, 31),  texture = "rbxassetid://139096196695198" },
	MAGENTA_DYE =    { id = 5009, name = "Magenta Dye",    category = "dye", color = Color3.fromRGB(199, 78, 189),  texture = "rbxassetid://139096196695198" },
	ORANGE_DYE =     { id = 5010, name = "Orange Dye",     category = "dye", color = Color3.fromRGB(249, 128, 29),  texture = "rbxassetid://139096196695198" },
	PINK_DYE =       { id = 5011, name = "Pink Dye",       category = "dye", color = Color3.fromRGB(243, 139, 170), texture = "rbxassetid://139096196695198" },
	PURPLE_DYE =     { id = 5012, name = "Purple Dye",     category = "dye", color = Color3.fromRGB(137, 50, 184),  texture = "rbxassetid://139096196695198" },
	RED_DYE =        { id = 5013, name = "Red Dye",        category = "dye", color = Color3.fromRGB(176, 46, 38),   texture = "rbxassetid://139096196695198" },
	ROSE_RED =       { id = 5015, name = "Rose Red",       category = "dye", color = Color3.fromRGB(176, 46, 38),   texture = "rbxassetid://139096196695198" }, -- Legacy name
	YELLOW_DYE =     { id = 5014, name = "Yellow Dye",     category = "dye", color = Color3.fromRGB(254, 216, 61),  texture = "rbxassetid://139096196695198" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ORES (Block category - defined in BlockRegistry)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Ores = {
	COAL_ORE =      { id = 29,  name = "Coal Ore",      category = "block", hardness = 3.0, minToolTier = 1, drops = 32, spawnRate = 0.012 },
	IRON_ORE =      { id = 30,  name = "Iron Ore",      category = "block", hardness = 3.0, minToolTier = 1, drops = 30, spawnRate = 0.008 },
	COPPER_ORE =    { id = 98,  name = "Copper Ore",    category = "block", hardness = 2.5, minToolTier = 1, drops = 98, spawnRate = 0.010 },
	BLUESTEEL_ORE = { id = 101, name = "Bluesteel Ore", category = "block", hardness = 4.0, minToolTier = 3, drops = 115, spawnRate = 0.004 },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FULL BLOCKS (9x ingots - Block category)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.FullBlocks = {
	COPPER_BLOCK =    { id = 116, name = "Copper Block",    category = "block", craftedFrom = 105, texture = "rbxassetid://115933247878677" },
	COAL_BLOCK =      { id = 117, name = "Coal Block",      category = "block", craftedFrom = 32,  texture = "rbxassetid://74344180768881" },
	IRON_BLOCK =      { id = 118, name = "Iron Block",      category = "block", craftedFrom = 33,  texture = "rbxassetid://105161132495681" },
	STEEL_BLOCK =     { id = 119, name = "Steel Block",     category = "block", craftedFrom = 108, texture = "rbxassetid://76501364497397" },
	BLUESTEEL_BLOCK = { id = 120, name = "Bluesteel Block", category = "block", craftedFrom = 109, texture = "rbxassetid://74339957046108" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ALL CATEGORIES (for iteration)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.AllCategories = {
	ItemDefinitions.Tools,
	ItemDefinitions.Weapons,
	ItemDefinitions.Ranged,
	ItemDefinitions.UtilityTools,
	ItemDefinitions.Arrows,
	ItemDefinitions.Armor,
	ItemDefinitions.Food,
	ItemDefinitions.Materials,
	ItemDefinitions.Dyes,
	ItemDefinitions.Books,
	ItemDefinitions.Ores,
	ItemDefinitions.FullBlocks,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Get item by ID (searches all categories)
function ItemDefinitions.GetById(id)
	for _, category in ipairs(ItemDefinitions.AllCategories) do
		for key, item in pairs(category) do
			if item.id == id then
				return item, key
			end
		end
	end
	return nil
end

-- Get item category by ID
function ItemDefinitions.GetCategory(id)
	local item = ItemDefinitions.GetById(id)
	return item and item.category or nil
end

-- Get item by key name
function ItemDefinitions.Get(key)
	for _, category in ipairs(ItemDefinitions.AllCategories) do
		if category[key] then
			return category[key]
		end
	end
	return nil
end

-- Get tier color
function ItemDefinitions.GetTierColor(tier)
	return ItemDefinitions.TierColors[tier] or Color3.fromRGB(150, 150, 150)
end

-- Get tier name
function ItemDefinitions.GetTierName(tier)
	return ItemDefinitions.TierNames[tier] or "Unknown"
end

-- Check if item is stackable
function ItemDefinitions.IsStackable(id)
	local item = ItemDefinitions.GetById(id)
	if not item then return true end -- Default stackable

	-- Explicit stackable field
	if item.stackable ~= nil then
		return item.stackable
	end

	-- Category defaults
	local cat = item.category
	if cat == "tool" or cat == "weapon" or cat == "ranged" or cat == "armor" then
		return false
	end
	return true
end

-- Get max stack size
function ItemDefinitions.GetMaxStack(id)
	local item = ItemDefinitions.GetById(id)
	if not item then return 64 end

	if item.maxStack then return item.maxStack end
	if not ItemDefinitions.IsStackable(id) then return 1 end
	return 64
end

-- Validate all items (call in Studio to check for errors)
function ItemDefinitions.Validate()
	local errors = {}
	local ids = {}

	local function checkCategory(categoryName, category)
		for key, item in pairs(category) do
			if not item.id then
				table.insert(errors, string.format("[%s.%s] Missing 'id'", categoryName, key))
			elseif ids[item.id] then
				table.insert(errors, string.format("[%s.%s] Duplicate ID %d (also used by %s)", categoryName, key, item.id, ids[item.id]))
			else
				ids[item.id] = categoryName .. "." .. key
			end

			if not item.name then
				table.insert(errors, string.format("[%s.%s] Missing 'name'", categoryName, key))
			end

			if not item.category then
				table.insert(errors, string.format("[%s.%s] Missing 'category'", categoryName, key))
			end
		end
	end

	checkCategory("Tools", ItemDefinitions.Tools)
	checkCategory("Weapons", ItemDefinitions.Weapons)
	checkCategory("Ranged", ItemDefinitions.Ranged)
	checkCategory("UtilityTools", ItemDefinitions.UtilityTools)
	checkCategory("Arrows", ItemDefinitions.Arrows)
	checkCategory("Armor", ItemDefinitions.Armor)
	checkCategory("Food", ItemDefinitions.Food)
	checkCategory("Materials", ItemDefinitions.Materials)
	checkCategory("Dyes", ItemDefinitions.Dyes)
	checkCategory("Books", ItemDefinitions.Books)
	checkCategory("Ores", ItemDefinitions.Ores)
	checkCategory("FullBlocks", ItemDefinitions.FullBlocks)

	if #errors > 0 then
		warn("═══ ItemDefinitions Validation Errors ═══")
		for _, err in ipairs(errors) do
			warn("  " .. err)
		end
		warn("═══ " .. #errors .. " errors found ═══")
		return false, errors
	else
		print("✅ ItemDefinitions: All " .. #ids .. " items validated successfully!")
		return true
	end
end

return ItemDefinitions
