--[[
	ItemDefinitions.lua
	═══════════════════════════════════════════════════════════════════════════
	SINGLE SOURCE OF TRUTH FOR ALL ITEMS
	═══════════════════════════════════════════════════════════════════════════

	This file defines ALL items in the game. Other configs read from here.

	ADDING A NEW ITEM:
	1. Add the item definition below in the appropriate category
	2. Run ItemDefinitions.Validate() in Studio to check for errors
	3. Done! All configs auto-populate from this file.

	ITEM STRUCTURE:
	{
		id = number,           -- Unique item ID (required)
		name = string,         -- Display name (required)
		texture = string,      -- rbxassetid:// (required)
		color = Color3,        -- Fallback color (optional)

		-- Category-specific fields:
		-- Blocks: solid, transparent, crossShape, craftingMaterial
		-- Tools: toolType, tier
		-- Armor: slot, tier, defense, toughness, setId
		-- Ores: hardness, minToolTier, drops, spawnRate
	}

	ID RANGES:
	  1-99:     Core blocks (dirt, stone, wood, etc.)
	  100-199:  Ores, ingots, materials
	  1001-1099: Tools (pickaxes, axes, shovels, swords)
	  2001-2099: Ammo & consumables
	  3001-3099: Armor
	  4001-4099: Spawn eggs
]]

local ItemDefinitions = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- TIER SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Tiers = {
	NONE = 0,
	COPPER = 1,
	IRON = 2,
	STEEL = 3,
	BLUESTEEL = 4,
	TUNGSTEN = 5,
	TITANIUM = 6,
}

ItemDefinitions.TierColors = {
	[1] = Color3.fromRGB(188, 105, 47),   -- Copper: #bc692f
	[2] = Color3.fromRGB(122, 122, 122),  -- Iron: #7a7a7a
	[3] = Color3.fromRGB(173, 173, 173),  -- Steel: #adadad
	[4] = Color3.fromRGB(149, 190, 246),  -- Bluesteel: #95bef6
	[5] = Color3.fromRGB(232, 244, 255),  -- Tungsten: #e8f4ff
	[6] = Color3.fromRGB(193, 242, 242),  -- Titanium: #c1f2f2
}

ItemDefinitions.TierNames = {
	[0] = "None",
	[1] = "Copper",
	[2] = "Iron",
	[3] = "Steel",
	[4] = "Bluesteel",
	[5] = "Tungsten",
	[6] = "Titanium",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ORES
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Ores = {
	COAL_ORE = {
		id = 29,
		name = "Coal Ore",
		texture = "rbxassetid://79950940655441",
		color = Color3.fromRGB(67, 67, 67),
		hardness = 3.0,
		minToolTier = 1,
		drops = 32, -- Drops Coal item
		spawnRate = 0.012,
	},
	IRON_ORE = {
		id = 30,
		name = "Iron Ore",
		texture = "rbxassetid://97259156198539",
		color = Color3.fromRGB(122, 122, 122),
		hardness = 3.0,
		minToolTier = 1,
		drops = 30, -- Drops itself (needs smelting)
		spawnRate = 0.008,
	},
	COPPER_ORE = {
		id = 98,
		name = "Copper Ore",
		texture = "rbxassetid://136807077587468",
		color = Color3.fromRGB(188, 105, 47),
		hardness = 2.5,
		minToolTier = 1,
		drops = 98, -- Drops itself (needs smelting)
		spawnRate = 0.010,
	},
	BLUESTEEL_ORE = {
		id = 101,
		name = "Bluesteel Ore",
		texture = "rbxassetid://101828645932065",
		color = Color3.fromRGB(149, 190, 246),
		hardness = 4.0,
		minToolTier = 3, -- Steel required
		drops = 115, -- Drops Bluesteel Dust
		spawnRate = 0.004,
	},
	TUNGSTEN_ORE = {
		id = 102,
		name = "Tungsten Ore",
		texture = "rbxassetid://133328089014739",
		color = Color3.fromRGB(232, 244, 255),
		hardness = 5.0,
		minToolTier = 4, -- Bluesteel required
		drops = 102, -- Drops itself (needs smelting)
		spawnRate = 0.003,
	},
	TITANIUM_ORE = {
		id = 103,
		name = "Titanium Ore",
		texture = "rbxassetid://70831716548382",
		color = Color3.fromRGB(193, 242, 242),
		hardness = 6.0,
		minToolTier = 5, -- Tungsten required
		drops = 103, -- Drops itself (needs smelting)
		spawnRate = 0.002,
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MATERIALS (Ingots, Dusts, etc.)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Materials = {
	COAL = {
		id = 32,
		name = "Coal",
		texture = "rbxassetid://139096196695198",
		color = Color3.fromRGB(40, 40, 40),
		craftingMaterial = true,
	},
	IRON_INGOT = {
		id = 33,
		name = "Iron Ingot",
		texture = "rbxassetid://116257653070196",
		color = Color3.fromRGB(122, 122, 122),
		craftingMaterial = true,
	},
	COPPER_INGOT = {
		id = 105,
		name = "Copper Ingot",
		texture = "rbxassetid://117987670821375",
		color = Color3.fromRGB(188, 105, 47),
		craftingMaterial = true,
	},
	STEEL_INGOT = {
		id = 108,
		name = "Steel Ingot",
		texture = "rbxassetid://103080988701146",
		color = Color3.fromRGB(173, 173, 173),
		craftingMaterial = true,
	},
	BLUESTEEL_INGOT = {
		id = 109,
		name = "Bluesteel Ingot",
		texture = "rbxassetid://121436448752857",
		color = Color3.fromRGB(149, 190, 246),
		craftingMaterial = true,
	},
	TUNGSTEN_INGOT = {
		id = 110,
		name = "Tungsten Ingot",
		texture = "rbxassetid://136722055090955",
		color = Color3.fromRGB(232, 244, 255),
		craftingMaterial = true,
	},
	TITANIUM_INGOT = {
		id = 111,
		name = "Titanium Ingot",
		texture = "rbxassetid://72533241452362",
		color = Color3.fromRGB(193, 242, 242),
		craftingMaterial = true,
	},
	BLUESTEEL_DUST = {
		id = 115,
		name = "Bluesteel Dust",
		texture = "rbxassetid://122819289085836",
		color = Color3.fromRGB(149, 190, 246),
		craftingMaterial = true,
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FULL BLOCKS (9x ingots)
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.FullBlocks = {
	COPPER_BLOCK = {
		id = 116,
		name = "Copper Block",
		texture = "rbxassetid://115933247878677",
		color = Color3.fromRGB(188, 105, 47),
		craftedFrom = 105, -- Copper Ingot
	},
	COAL_BLOCK = {
		id = 117,
		name = "Coal Block",
		texture = "rbxassetid://74344180768881",
		color = Color3.fromRGB(40, 40, 40),
		craftedFrom = 32, -- Coal
	},
	IRON_BLOCK = {
		id = 118,
		name = "Iron Block",
		texture = "rbxassetid://105161132495681",
		color = Color3.fromRGB(122, 122, 122),
		craftedFrom = 33, -- Iron Ingot
	},
	STEEL_BLOCK = {
		id = 119,
		name = "Steel Block",
		texture = "rbxassetid://76501364497397",
		color = Color3.fromRGB(173, 173, 173),
		craftedFrom = 108, -- Steel Ingot
	},
	BLUESTEEL_BLOCK = {
		id = 120,
		name = "Bluesteel Block",
		texture = "rbxassetid://74339957046108",
		color = Color3.fromRGB(149, 190, 246),
		craftedFrom = 109, -- Bluesteel Ingot
	},
	TUNGSTEN_BLOCK = {
		id = 121,
		name = "Tungsten Block",
		texture = "rbxassetid://91018177845956",
		color = Color3.fromRGB(232, 244, 255),
		craftedFrom = 110, -- Tungsten Ingot
	},
	TITANIUM_BLOCK = {
		id = 122,
		name = "Titanium Block",
		texture = "rbxassetid://120386947860707",
		color = Color3.fromRGB(193, 242, 242),
		craftedFrom = 111, -- Titanium Ingot
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TOOLS
-- ═══════════════════════════════════════════════════════════════════════════

ItemDefinitions.Tools = {
	-- ═══════════════════════════════════════════════════════════════════
	-- PICKAXES (1001-1006)
	-- ═══════════════════════════════════════════════════════════════════
	COPPER_PICKAXE =    { id = 1001, name = "Copper Pickaxe",    toolType = "pickaxe", tier = 1, texture = "rbxassetid://128947615086427" },
	IRON_PICKAXE =      { id = 1002, name = "Iron Pickaxe",      toolType = "pickaxe", tier = 2, texture = "rbxassetid://90422189544555" },
	STEEL_PICKAXE =     { id = 1003, name = "Steel Pickaxe",     toolType = "pickaxe", tier = 3, texture = "rbxassetid://79239885085319" },
	BLUESTEEL_PICKAXE = { id = 1004, name = "Bluesteel Pickaxe", toolType = "pickaxe", tier = 4, texture = "rbxassetid://78773213138783" },
	TUNGSTEN_PICKAXE =  { id = 1005, name = "Tungsten Pickaxe",  toolType = "pickaxe", tier = 5, texture = "rbxassetid://133384275970840" },
	TITANIUM_PICKAXE =  { id = 1006, name = "Titanium Pickaxe",  toolType = "pickaxe", tier = 6, texture = "rbxassetid://131513043502936" },

	-- ═══════════════════════════════════════════════════════════════════
	-- AXES (1011-1016)
	-- ═══════════════════════════════════════════════════════════════════
	COPPER_AXE =    { id = 1011, name = "Copper Axe",    toolType = "axe", tier = 1, texture = "rbxassetid://113405300734786" },
	IRON_AXE =      { id = 1012, name = "Iron Axe",      toolType = "axe", tier = 2, texture = "rbxassetid://83988909828608" },
	STEEL_AXE =     { id = 1013, name = "Steel Axe",     toolType = "axe", tier = 3, texture = "rbxassetid://114291626046105" },
	BLUESTEEL_AXE = { id = 1014, name = "Bluesteel Axe", toolType = "axe", tier = 4, texture = "rbxassetid://79374639327483" },
	TUNGSTEN_AXE =  { id = 1015, name = "Tungsten Axe",  toolType = "axe", tier = 5, texture = "rbxassetid://89800400936964" },
	TITANIUM_AXE =  { id = 1016, name = "Titanium Axe",  toolType = "axe", tier = 6, texture = "rbxassetid://134219228892729" },

	-- ═══════════════════════════════════════════════════════════════════
	-- SHOVELS (1021-1026)
	-- ═══════════════════════════════════════════════════════════════════
	COPPER_SHOVEL =    { id = 1021, name = "Copper Shovel",    toolType = "shovel", tier = 1, texture = "rbxassetid://97111593512086" },
	IRON_SHOVEL =      { id = 1022, name = "Iron Shovel",      toolType = "shovel", tier = 2, texture = "rbxassetid://137269837100155" },
	STEEL_SHOVEL =     { id = 1023, name = "Steel Shovel",     toolType = "shovel", tier = 3, texture = "rbxassetid://114823510951232" },
	BLUESTEEL_SHOVEL = { id = 1024, name = "Bluesteel Shovel", toolType = "shovel", tier = 4, texture = "rbxassetid://130333676635510" },
	TUNGSTEN_SHOVEL =  { id = 1025, name = "Tungsten Shovel",  toolType = "shovel", tier = 5, texture = "rbxassetid://84698617225603" },
	TITANIUM_SHOVEL =  { id = 1026, name = "Titanium Shovel",  toolType = "shovel", tier = 6, texture = "rbxassetid://110329438924043" },

	-- ═══════════════════════════════════════════════════════════════════
	-- SWORDS (1041-1046)
	-- ═══════════════════════════════════════════════════════════════════
	COPPER_SWORD =    { id = 1041, name = "Copper Sword",    toolType = "sword", tier = 1, texture = "rbxassetid://139473111443819" },
	IRON_SWORD =      { id = 1042, name = "Iron Sword",      toolType = "sword", tier = 2, texture = "rbxassetid://88350899156447" },
	STEEL_SWORD =     { id = 1043, name = "Steel Sword",     toolType = "sword", tier = 3, texture = "rbxassetid://72684086705746" },
	BLUESTEEL_SWORD = { id = 1044, name = "Bluesteel Sword", toolType = "sword", tier = 4, texture = "rbxassetid://114493455671228" },
	TUNGSTEN_SWORD =  { id = 1045, name = "Tungsten Sword",  toolType = "sword", tier = 5, texture = "rbxassetid://81783573420244" },
	TITANIUM_SWORD =  { id = 1046, name = "Titanium Sword",  toolType = "sword", tier = 6, texture = "rbxassetid://103127777465249" },

	-- ═══════════════════════════════════════════════════════════════════
	-- RANGED
	-- ═══════════════════════════════════════════════════════════════════
	BOW = { id = 1051, name = "Bow", toolType = "bow", tier = 1, texture = "rbxassetid://99844472348258" },
	ARROW = { id = 2001, name = "Arrow", toolType = "arrow", tier = 0, texture = "rbxassetid://78321595602062", stackable = true },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ARMOR
-- ═══════════════════════════════════════════════════════════════════════════

-- Defense values per tier: { helmet, chestplate, leggings, boots }
local ArmorDefense = {
	[1] = { helmet = 1, chestplate = 2, leggings = 2, boots = 1, toughness = 0 }, -- Copper
	[2] = { helmet = 2, chestplate = 4, leggings = 3, boots = 1, toughness = 0 }, -- Iron
	[3] = { helmet = 2, chestplate = 5, leggings = 4, boots = 2, toughness = 0 }, -- Steel
	[4] = { helmet = 3, chestplate = 6, leggings = 5, boots = 2, toughness = 1 }, -- Bluesteel
	[5] = { helmet = 4, chestplate = 7, leggings = 6, boots = 3, toughness = 2 }, -- Tungsten
	[6] = { helmet = 5, chestplate = 8, leggings = 7, boots = 4, toughness = 3 }, -- Titanium
}

ItemDefinitions.Armor = {
	-- ═══════════════════════════════════════════════════════════════════
	-- COPPER ARMOR (3001-3004)
	-- ═══════════════════════════════════════════════════════════════════
	COPPER_HELMET =     { id = 3001, name = "Copper Helmet",     slot = "helmet",     tier = 1, texture = "rbxassetid://126048124614409" },
	COPPER_CHESTPLATE = { id = 3002, name = "Copper Chestplate", slot = "chestplate", tier = 1, texture = "rbxassetid://89778243976291" },
	COPPER_LEGGINGS =   { id = 3003, name = "Copper Leggings",   slot = "leggings",   tier = 1, texture = "rbxassetid://114975984936435" },
	COPPER_BOOTS =      { id = 3004, name = "Copper Boots",      slot = "boots",      tier = 1, texture = "rbxassetid://72491546589107" },

	-- ═══════════════════════════════════════════════════════════════════
	-- IRON ARMOR (3005-3008)
	-- ═══════════════════════════════════════════════════════════════════
	IRON_HELMET =     { id = 3005, name = "Iron Helmet",     slot = "helmet",     tier = 2, texture = "rbxassetid://122225724433670" },
	IRON_CHESTPLATE = { id = 3006, name = "Iron Chestplate", slot = "chestplate", tier = 2, texture = "rbxassetid://131613353335099" },
	IRON_LEGGINGS =   { id = 3007, name = "Iron Leggings",   slot = "leggings",   tier = 2, texture = "rbxassetid://75809753542420" },
	IRON_BOOTS =      { id = 3008, name = "Iron Boots",      slot = "boots",      tier = 2, texture = "rbxassetid://108013738218975" },

	-- ═══════════════════════════════════════════════════════════════════
	-- STEEL ARMOR (3009-3012)
	-- ═══════════════════════════════════════════════════════════════════
	STEEL_HELMET =     { id = 3009, name = "Steel Helmet",     slot = "helmet",     tier = 3, texture = "rbxassetid://132418834328833" },
	STEEL_CHESTPLATE = { id = 3010, name = "Steel Chestplate", slot = "chestplate", tier = 3, texture = "rbxassetid://105921740804226" },
	STEEL_LEGGINGS =   { id = 3011, name = "Steel Leggings",   slot = "leggings",   tier = 3, texture = "rbxassetid://92040368920341" },
	STEEL_BOOTS =      { id = 3012, name = "Steel Boots",      slot = "boots",      tier = 3, texture = "rbxassetid://86491440244351" },

	-- ═══════════════════════════════════════════════════════════════════
	-- BLUESTEEL ARMOR (3013-3016)
	-- ═══════════════════════════════════════════════════════════════════
	BLUESTEEL_HELMET =     { id = 3013, name = "Bluesteel Helmet",     slot = "helmet",     tier = 4, texture = "rbxassetid://108327379558098" },
	BLUESTEEL_CHESTPLATE = { id = 3014, name = "Bluesteel Chestplate", slot = "chestplate", tier = 4, texture = "rbxassetid://121636188243090" },
	BLUESTEEL_LEGGINGS =   { id = 3015, name = "Bluesteel Leggings",   slot = "leggings",   tier = 4, texture = "rbxassetid://82601608552864" },
	BLUESTEEL_BOOTS =      { id = 3016, name = "Bluesteel Boots",      slot = "boots",      tier = 4, texture = "rbxassetid://112236445368875" },

	-- ═══════════════════════════════════════════════════════════════════
	-- TUNGSTEN ARMOR (3017-3020)
	-- ═══════════════════════════════════════════════════════════════════
	TUNGSTEN_HELMET =     { id = 3017, name = "Tungsten Helmet",     slot = "helmet",     tier = 5, texture = "rbxassetid://130275916685971" },
	TUNGSTEN_CHESTPLATE = { id = 3018, name = "Tungsten Chestplate", slot = "chestplate", tier = 5, texture = "rbxassetid://100722652470814" },
	TUNGSTEN_LEGGINGS =   { id = 3019, name = "Tungsten Leggings",   slot = "leggings",   tier = 5, texture = "rbxassetid://86625576976655" },
	TUNGSTEN_BOOTS =      { id = 3020, name = "Tungsten Boots",      slot = "boots",      tier = 5, texture = "rbxassetid://129227490448021" },

	-- ═══════════════════════════════════════════════════════════════════
	-- TITANIUM ARMOR (3021-3024)
	-- ═══════════════════════════════════════════════════════════════════
	TITANIUM_HELMET =     { id = 3021, name = "Titanium Helmet",     slot = "helmet",     tier = 6, texture = "rbxassetid://73722259390329" },
	TITANIUM_CHESTPLATE = { id = 3022, name = "Titanium Chestplate", slot = "chestplate", tier = 6, texture = "rbxassetid://88240735581722" },
	TITANIUM_LEGGINGS =   { id = 3023, name = "Titanium Leggings",   slot = "leggings",   tier = 6, texture = "rbxassetid://77644713417778" },
	TITANIUM_BOOTS =      { id = 3024, name = "Titanium Boots",      slot = "boots",      tier = 6, texture = "rbxassetid://83259278007304" },
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
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Get item by ID (searches all categories)
function ItemDefinitions.GetById(id)
	for _, category in pairs({ItemDefinitions.Ores, ItemDefinitions.Materials, ItemDefinitions.FullBlocks, ItemDefinitions.Tools, ItemDefinitions.Armor}) do
		for key, item in pairs(category) do
			if item.id == id then
				return item, key
			end
		end
	end
	return nil
end

-- Get item by key name
function ItemDefinitions.Get(key)
	return ItemDefinitions.Ores[key]
		or ItemDefinitions.Materials[key]
		or ItemDefinitions.FullBlocks[key]
		or ItemDefinitions.Tools[key]
		or ItemDefinitions.Armor[key]
end

-- Get tier color
function ItemDefinitions.GetTierColor(tier)
	return ItemDefinitions.TierColors[tier] or Color3.fromRGB(150, 150, 150)
end

-- Get tier name
function ItemDefinitions.GetTierName(tier)
	return ItemDefinitions.TierNames[tier] or "Unknown"
end

-- Validate all items (call in Studio to check for errors)
function ItemDefinitions.Validate()
	local errors = {}
	local ids = {}

	local function checkCategory(categoryName, category)
		for key, item in pairs(category) do
			-- Check required fields
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

			if not item.texture then
				table.insert(errors, string.format("[%s.%s] Missing 'texture'", categoryName, key))
			end
		end
	end

	checkCategory("Ores", ItemDefinitions.Ores)
	checkCategory("Materials", ItemDefinitions.Materials)
	checkCategory("FullBlocks", ItemDefinitions.FullBlocks)
	checkCategory("Tools", ItemDefinitions.Tools)
	checkCategory("Armor", ItemDefinitions.Armor)

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

-- Print summary of all items
function ItemDefinitions.PrintSummary()
	local counts = {
		Ores = 0,
		Materials = 0,
		FullBlocks = 0,
		Tools = 0,
		Armor = 0,
	}

	for k, _ in pairs(ItemDefinitions.Ores) do counts.Ores = counts.Ores + 1 end
	for k, _ in pairs(ItemDefinitions.Materials) do counts.Materials = counts.Materials + 1 end
	for k, _ in pairs(ItemDefinitions.FullBlocks) do counts.FullBlocks = counts.FullBlocks + 1 end
	for k, _ in pairs(ItemDefinitions.Tools) do counts.Tools = counts.Tools + 1 end
	for k, _ in pairs(ItemDefinitions.Armor) do counts.Armor = counts.Armor + 1 end

	local total = counts.Ores + counts.Materials + counts.FullBlocks + counts.Tools + counts.Armor

	print("═══ ItemDefinitions Summary ═══")
	print(string.format("  Ores:       %d", counts.Ores))
	print(string.format("  Materials:  %d", counts.Materials))
	print(string.format("  FullBlocks: %d", counts.FullBlocks))
	print(string.format("  Tools:      %d", counts.Tools))
	print(string.format("  Armor:      %d", counts.Armor))
	print(string.format("  TOTAL:      %d items", total))
end

return ItemDefinitions

