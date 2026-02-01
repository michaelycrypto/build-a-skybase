--[[
	NPCTradeConfig.lua
	Scarce Economy Configuration

	=== DESIGN PRINCIPLES ===
	1. Currency is SCARCE - every coin matters
	2. LOW MARGINS on farming - barely profitable, requires volume
	3. Blocks are CHEAP - building should be accessible
	4. NO ARBITRAGE - sell price always < buy price
	5. WHITELIST ONLY - only items in SellPrices can be sold

	=== WHAT CAN BE SOLD ===
	- Crops, logs, planks (farming income)
	- Ores, ingots (mining income)
	- Basic blocks, decoratives (building byproducts)

	=== WHAT CANNOT BE SOLD ===
	- Tools, weapons, armor (keep what you craft)
	- Arrows, ammo (consumables)
	- Utility blocks (crafting table, furnace, chest, minions)
]]

local NPCTradeConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEM ID CONSTANTS (for readability)
-- ═══════════════════════════════════════════════════════════════════════════

local B = {
	-- Basic
	DIRT = 2, STONE = 3, WOOD = 5, LEAVES = 6, SAND = 10,
	STONE_BRICKS = 11, OAK_PLANKS = 12, COBBLESTONE = 14,
	BRICKS = 15, OAK_SAPLING = 16, OAK_STAIRS = 17, STONE_STAIRS = 18,
	OAK_SLAB = 22, STONE_SLAB = 23,
	-- Ores & Materials
	COAL_ORE = 29, IRON_ORE = 30, DIAMOND_ORE = 31, COAL = 32, IRON_INGOT = 33,
	DIAMOND = 34, GLASS = 36, APPLE = 37,
	-- Wood types
	SPRUCE_LOG = 38, SPRUCE_PLANKS = 39, SPRUCE_SAPLING = 40,
	JUNGLE_LOG = 43, JUNGLE_PLANKS = 44, JUNGLE_SAPLING = 45,
	DARK_OAK_LOG = 48, DARK_OAK_PLANKS = 49, DARK_OAK_SAPLING = 50,
	BIRCH_LOG = 53, BIRCH_PLANKS = 54, BIRCH_SAPLING = 55,
	ACACIA_LOG = 58, ACACIA_PLANKS = 59, ACACIA_SAPLING = 60,
	-- Leaves
	OAK_LEAVES = 63, SPRUCE_LEAVES = 64, JUNGLE_LEAVES = 65,
	DARK_OAK_LEAVES = 66, BIRCH_LEAVES = 67, ACACIA_LEAVES = 68,
	-- Farming
	FARMLAND = 69, WHEAT_SEEDS = 70, WHEAT = 71, POTATO = 72, CARROT = 73,
	BEETROOT_SEEDS = 74, BEETROOT = 75,
	-- Materials
	COPPER_ORE = 98, BLUESTEEL_ORE = 101,
	COPPER_INGOT = 105, STEEL_INGOT = 108, BLUESTEEL_INGOT = 109, BLUESTEEL_DUST = 115,
	COPPER_BLOCK = 116, COAL_BLOCK = 117, IRON_BLOCK = 118, STEEL_BLOCK = 119, BLUESTEEL_BLOCK = 120,
	-- Stained Glass
	WHITE_STAINED_GLASS = 123, ORANGE_STAINED_GLASS = 124, MAGENTA_STAINED_GLASS = 125,
	LIGHT_BLUE_STAINED_GLASS = 126, YELLOW_STAINED_GLASS = 127, LIME_STAINED_GLASS = 128,
	BLUE_STAINED_GLASS = 134, GREEN_STAINED_GLASS = 136, RED_STAINED_GLASS = 137, BLACK_STAINED_GLASS = 138,
	-- Terracotta
	TERRACOTTA = 139, WHITE_TERRACOTTA = 140, ORANGE_TERRACOTTA = 141,
	BLUE_TERRACOTTA = 151, RED_TERRACOTTA = 154, BLACK_TERRACOTTA = 155,
	-- Wool
	WHITE_WOOL = 156, ORANGE_WOOL = 157, MAGENTA_WOOL = 158, LIGHT_BLUE_WOOL = 159,
	YELLOW_WOOL = 160, LIME_WOOL = 161, PINK_WOOL = 162, GRAY_WOOL = 163,
	BLUE_WOOL = 167, GREEN_WOOL = 169, RED_WOOL = 170, BLACK_WOOL = 171,
	-- Stone variants
	GRAVEL = 173, SANDSTONE = 175,
	DIORITE = 176, POLISHED_DIORITE = 177, ANDESITE = 178, POLISHED_ANDESITE = 179,
	-- Concrete
	WHITE_CONCRETE = 180, ORANGE_CONCRETE = 181, MAGENTA_CONCRETE = 182,
	LIGHT_BLUE_CONCRETE = 183, YELLOW_CONCRETE = 184, LIME_CONCRETE = 185,
	BLUE_CONCRETE = 191, RED_CONCRETE = 194, BLACK_CONCRETE = 195,
	-- Premium
	QUARTZ_BLOCK = 216, QUARTZ_PILLAR = 217, GRANITE = 221, POLISHED_GRANITE = 222,
	OBSIDIAN = 271,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SHOP ITEMS (What players can BUY)
-- shopType: "FARM" = Farmer NPC, "BUILDING" = Builder NPC
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.ShopItems = {
	-- ═══════════════════════════════════════════════════════════════════════
	-- FARM SHOP - Seeds & Saplings (stack of 8)
	-- ═══════════════════════════════════════════════════════════════════════

	{ itemId = B.WHEAT_SEEDS,    price = 160,   stock = 32, stackSize = 8, category = "Seeds", shopType = "FARM" },     -- 20/ea
	{ itemId = B.BEETROOT_SEEDS, price = 800,   stock = 24, stackSize = 8, category = "Seeds", shopType = "FARM" },     -- 100/ea
	{ itemId = B.POTATO,         price = 4000,  stock = 16, stackSize = 8, category = "Seeds", shopType = "FARM" },     -- 500/ea
	{ itemId = B.CARROT,         price = 20000, stock = 12, stackSize = 8, category = "Seeds", shopType = "FARM" },     -- 2500/ea

	{ itemId = B.OAK_SAPLING,      price = 800,   stock = 4, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 100/ea
	{ itemId = B.SPRUCE_SAPLING,   price = 1600,  stock = 3, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 200/ea
	{ itemId = B.BIRCH_SAPLING,    price = 3200,  stock = 3, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 400/ea
	{ itemId = B.JUNGLE_SAPLING,   price = 6400,  stock = 2, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 800/ea
	{ itemId = B.DARK_OAK_SAPLING, price = 12000, stock = 2, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 1500/ea
	{ itemId = B.ACACIA_SAPLING,   price = 24000, stock = 2, stackSize = 8, category = "Saplings", shopType = "FARM" }, -- 3000/ea

	-- ═══════════════════════════════════════════════════════════════════════
	-- BUILDING SHOP - Blocks ONLY
	-- ═══════════════════════════════════════════════════════════════════════

	-- FARMLAND (first for tutorial - cheap!)
	{ itemId = B.FARMLAND,          price = 64,   stock = 16, stackSize = 16, category = "Farming", shopType = "BUILDING" },  -- 4/ea

	-- BASIC MATERIALS (stack of 64, 2/ea)
	{ itemId = B.DIRT,              price = 128,  stock = 10, stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.COBBLESTONE,       price = 128,  stock = 10, stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.SAND,              price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.GRAVEL,            price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.ANDESITE,          price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.POLISHED_ANDESITE, price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.DIORITE,           price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.POLISHED_DIORITE,  price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.GRANITE,           price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.POLISHED_GRANITE,  price = 128,  stock = 8,  stackSize = 64, category = "Building", shopType = "BUILDING" },

	-- STONE VARIANTS (stack of 64, 3-6/ea)
	{ itemId = B.STONE,        price = 192,  stock = 6, stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.STONE_BRICKS, price = 256,  stock = 6, stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.SANDSTONE,    price = 384,  stock = 4, stackSize = 64, category = "Building", shopType = "BUILDING" },
	{ itemId = B.BRICKS,       price = 384,  stock = 6, stackSize = 64, category = "Building", shopType = "BUILDING" },

	-- LOGS (stack of 16, priced above sell)
	{ itemId = B.WOOD,         price = 80,   stock = 6, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.SPRUCE_LOG,   price = 128,  stock = 6, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.BIRCH_LOG,    price = 240,  stock = 6, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.JUNGLE_LOG,   price = 480,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.DARK_OAK_LOG, price = 960,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.ACACIA_LOG,   price = 1920, stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },

	-- GLASS & STAIRS/SLABS (stack of 16)
	{ itemId = B.GLASS,        price = 320,  stock = 6, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.OAK_STAIRS,   price = 320,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.STONE_STAIRS, price = 320,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.OAK_SLAB,     price = 320,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },
	{ itemId = B.STONE_SLAB,   price = 320,  stock = 4, stackSize = 16, category = "Building", shopType = "BUILDING" },

	-- WOOL (stack of 16, 20/ea)
	{ itemId = B.WHITE_WOOL,      price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.ORANGE_WOOL,     price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.MAGENTA_WOOL,    price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIGHT_BLUE_WOOL, price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.YELLOW_WOOL,     price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIME_WOOL,       price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.PINK_WOOL,       price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.GRAY_WOOL,       price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.RED_WOOL,        price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLUE_WOOL,       price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.GREEN_WOOL,      price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLACK_WOOL,      price = 320,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },

	-- STAINED GLASS (stack of 16, 40/ea)
	{ itemId = B.WHITE_STAINED_GLASS,      price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.ORANGE_STAINED_GLASS,     price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.MAGENTA_STAINED_GLASS,    price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIGHT_BLUE_STAINED_GLASS, price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.YELLOW_STAINED_GLASS,     price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIME_STAINED_GLASS,       price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLUE_STAINED_GLASS,       price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.RED_STAINED_GLASS,        price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.GREEN_STAINED_GLASS,      price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLACK_STAINED_GLASS,      price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },

	-- TERRACOTTA (stack of 16, 40/ea)
	{ itemId = B.TERRACOTTA,        price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.WHITE_TERRACOTTA,  price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.ORANGE_TERRACOTTA, price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLUE_TERRACOTTA,   price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.RED_TERRACOTTA,    price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLACK_TERRACOTTA,  price = 640,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },

	-- CONCRETE (stack of 16, 50/ea)
	{ itemId = B.WHITE_CONCRETE,      price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.ORANGE_CONCRETE,     price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.MAGENTA_CONCRETE,    price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIGHT_BLUE_CONCRETE, price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.YELLOW_CONCRETE,     price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.LIME_CONCRETE,       price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLUE_CONCRETE,       price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.RED_CONCRETE,        price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },
	{ itemId = B.BLACK_CONCRETE,      price = 800,  stock = 4, stackSize = 16, category = "Decoration", shopType = "BUILDING" },

	-- PREMIUM (stack of 16)
	{ itemId = B.QUARTZ_BLOCK,  price = 2048,  stock = 4, stackSize = 16, category = "Premium", shopType = "BUILDING" },
	{ itemId = B.QUARTZ_PILLAR, price = 2048,  stock = 4, stackSize = 16, category = "Premium", shopType = "BUILDING" },
	{ itemId = B.OBSIDIAN,      price = 2048,  stock = 2, stackSize = 16, category = "Premium", shopType = "BUILDING" },
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SELL PRICES (WHITELIST - only these items can be sold to merchant)
-- Tools, arrows, armor, utility blocks CANNOT be sold
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.SellPrices = {
	-- CROPS (core farming income)
	[B.WHEAT]    = 4,
	[B.BEETROOT] = 8,
	[B.POTATO]   = 16,
	[B.CARROT]   = 24,
	[B.APPLE]    = 10,

	-- LOGS (tree farming income)
	[B.WOOD]         = 4,
	[B.SPRUCE_LOG]   = 7,
	[B.BIRCH_LOG]    = 14,
	[B.JUNGLE_LOG]   = 28,
	[B.DARK_OAK_LOG] = 55,
	[B.ACACIA_LOG]   = 110,

	-- PLANKS (crafting byproduct)
	[B.OAK_PLANKS]      = 1,
	[B.SPRUCE_PLANKS]   = 2,
	[B.BIRCH_PLANKS]    = 3,
	[B.JUNGLE_PLANKS]   = 7,
	[B.DARK_OAK_PLANKS] = 13,
	[B.ACACIA_PLANKS]   = 27,

	-- SAPLINGS (low value - prevent exploit)
	[B.OAK_SAPLING]      = 5,
	[B.SPRUCE_SAPLING]   = 10,
	[B.BIRCH_SAPLING]    = 20,
	[B.JUNGLE_SAPLING]   = 40,
	[B.DARK_OAK_SAPLING] = 75,
	[B.ACACIA_SAPLING]   = 150,

	-- LEAVES (minimal value)
	[B.LEAVES]          = 1,
	[B.OAK_LEAVES]      = 1,
	[B.SPRUCE_LEAVES]   = 1,
	[B.JUNGLE_LEAVES]   = 1,
	[B.DARK_OAK_LEAVES] = 1,
	[B.BIRCH_LEAVES]    = 1,
	[B.ACACIA_LEAVES]   = 1,

	-- BASIC BLOCKS (mining byproduct)
	[B.COBBLESTONE] = 1,
	[B.STONE]       = 1,
	[B.DIRT]        = 1,
	[B.SAND]        = 1,
	[B.GRAVEL]      = 1,

	-- ORES (mining income)
	[B.COAL_ORE]      = 3,
	[B.COPPER_ORE]    = 5,
	[B.IRON_ORE]      = 8,
	[B.BLUESTEEL_ORE] = 12,
	[B.DIAMOND_ORE]   = 50,

	-- PROCESSED MATERIALS
	[B.COAL]            = 2,
	[B.COPPER_INGOT]    = 6,
	[B.IRON_INGOT]      = 12,
	[B.STEEL_INGOT]     = 20,
	[B.DIAMOND]         = 100,
	[B.BLUESTEEL_INGOT] = 25,
	[B.BLUESTEEL_DUST]  = 8,

	-- STORAGE BLOCKS
	[B.COAL_BLOCK]      = 15,
	[B.COPPER_BLOCK]    = 45,
	[B.IRON_BLOCK]      = 90,
	[B.STEEL_BLOCK]     = 150,
	[B.BLUESTEEL_BLOCK] = 190,

	-- FOOD
	[348] = 3,  -- Bread
	[349] = 4,  -- Baked Potato
	[350] = 5,  -- Cooked Beef
	[351] = 5,  -- Cooked Porkchop
	[352] = 4,  -- Cooked Chicken
	[353] = 4,  -- Cooked Mutton
	[355] = 3,  -- Cooked Cod
	[356] = 4,  -- Cooked Salmon
	[357] = 2, [358] = 2, [359] = 1, [360] = 2, [362] = 1, [363] = 2,  -- Raw meat

	-- BUILDING BLOCKS
	[B.BRICKS]       = 1,
	[B.STONE_BRICKS] = 1,
	[B.GLASS]        = 1,
	[B.SANDSTONE]    = 1,
	[279] = 1,  -- Clay Block
	[B.OAK_STAIRS] = 1, [B.STONE_STAIRS] = 1, [B.OAK_SLAB] = 1, [B.STONE_SLAB] = 1,

	-- WOOL
	[B.WHITE_WOOL] = 1, [B.ORANGE_WOOL] = 1, [B.MAGENTA_WOOL] = 1, [B.LIGHT_BLUE_WOOL] = 1,
	[B.YELLOW_WOOL] = 1, [B.LIME_WOOL] = 1, [B.PINK_WOOL] = 1, [B.GRAY_WOOL] = 1,
	[B.RED_WOOL] = 1, [B.BLUE_WOOL] = 1, [B.GREEN_WOOL] = 1, [B.BLACK_WOOL] = 1,

	-- STAINED GLASS
	[B.WHITE_STAINED_GLASS] = 1, [B.ORANGE_STAINED_GLASS] = 1, [B.MAGENTA_STAINED_GLASS] = 1,
	[B.LIGHT_BLUE_STAINED_GLASS] = 1, [B.YELLOW_STAINED_GLASS] = 1, [B.LIME_STAINED_GLASS] = 1,
	[B.BLUE_STAINED_GLASS] = 1, [B.RED_STAINED_GLASS] = 1, [B.GREEN_STAINED_GLASS] = 1,
	[B.BLACK_STAINED_GLASS] = 1,

	-- TERRACOTTA
	[B.TERRACOTTA] = 1, [B.WHITE_TERRACOTTA] = 1, [B.ORANGE_TERRACOTTA] = 1,
	[B.BLUE_TERRACOTTA] = 1, [B.RED_TERRACOTTA] = 1, [B.BLACK_TERRACOTTA] = 1,

	-- CONCRETE
	[B.WHITE_CONCRETE] = 2, [B.ORANGE_CONCRETE] = 2, [B.MAGENTA_CONCRETE] = 2,
	[B.LIGHT_BLUE_CONCRETE] = 2, [B.YELLOW_CONCRETE] = 2, [B.LIME_CONCRETE] = 2,
	[B.BLUE_CONCRETE] = 2, [B.RED_CONCRETE] = 2, [B.BLACK_CONCRETE] = 2,

	-- PREMIUM BLOCKS
	[B.QUARTZ_BLOCK]  = 2,
	[B.QUARTZ_PILLAR] = 3,
	[B.OBSIDIAN]      = 5,

	-- MISC FARMING
	[28]  = 1,   -- Stick
	[254] = 8,   -- Hay Block
	[248] = 10,  -- Melon
	[249] = 8,   -- Pumpkin
	[252] = 5,   -- Cactus
}

-- ═══════════════════════════════════════════════════════════════════════════
-- STOCK REPLENISHMENT
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.Stock = {
	replenishInterval = 300,  -- 5 minutes
	replenishPercent = 0.25,  -- 25% of max stock per cycle
}

-- ═══════════════════════════════════════════════════════════════════════════
-- API FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function NPCTradeConfig.GetShopItems()
	return NPCTradeConfig.ShopItems
end

function NPCTradeConfig.GetShopItem(itemId)
	for _, item in ipairs(NPCTradeConfig.ShopItems) do
		if item.itemId == itemId then
			return item
		end
	end
	return nil
end

function NPCTradeConfig.GetStackSize(itemId)
	local item = NPCTradeConfig.GetShopItem(itemId)
	if item and item.stackSize then
		return item.stackSize
	end
	return 1
end

function NPCTradeConfig.IsStackItem(itemId)
	local item = NPCTradeConfig.GetShopItem(itemId)
	return item and item.stackSize and item.stackSize > 1
end

-- WHITELIST: Only items in SellPrices can be sold
function NPCTradeConfig.GetSellPrice(itemId)
	return NPCTradeConfig.SellPrices[itemId]
end

-- WHITELIST: Only returns true if item is explicitly in SellPrices
function NPCTradeConfig.CanSellItem(itemId)
	return NPCTradeConfig.SellPrices[itemId] ~= nil
end

function NPCTradeConfig.GetShopItemsByCategory(category)
	local items = {}
	for _, item in ipairs(NPCTradeConfig.ShopItems) do
		if item.category == category then
			table.insert(items, item)
		end
	end
	return items
end

function NPCTradeConfig.GetShopItemsByShopType(shopType)
	local items = {}
	for _, item in ipairs(NPCTradeConfig.ShopItems) do
		if item.shopType == shopType then
			table.insert(items, item)
		end
	end
	return items
end

function NPCTradeConfig.GetCategories()
	local categories = {}
	local seen = {}
	for _, item in ipairs(NPCTradeConfig.ShopItems) do
		if not seen[item.category] then
			seen[item.category] = true
			table.insert(categories, item.category)
		end
	end
	return categories
end

function NPCTradeConfig.ValidateNoArbitrage()
	local issues = {}
	for _, shopItem in ipairs(NPCTradeConfig.ShopItems) do
		if shopItem.shopType then
			local sellPrice = NPCTradeConfig.GetSellPrice(shopItem.itemId)
			if sellPrice then
				local stackSize = shopItem.stackSize or 1
				local totalSellValue = sellPrice * stackSize
				if totalSellValue >= shopItem.price then
					table.insert(issues, string.format(
						"ARBITRAGE: Item %d - Buy %d (stack %d), Sell %d each = %d total",
						shopItem.itemId, shopItem.price, stackSize, sellPrice, totalSellValue
					))
				end
			end
		end
	end
	return issues
end

return NPCTradeConfig
