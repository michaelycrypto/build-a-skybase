--[[
	NPCTradeConfig.lua
	Skyblock-Style Economy Configuration
	
	=== DESIGN PRINCIPLES ===
	1. Players EARN by selling farmed resources (crops, logs, raw blocks)
	2. Players SPEND on expansion, utility, and decoratives (money sinks)
	3. Sell price = 40-60% of buy price (NO ARBITRAGE)
	4. Early game: Manual farming rewards
	5. Mid game: Automation with diminishing returns
	6. Late game: High-cost decoratives as inflation sinks
	
	=== ECONOMY TIERS ===
	Tier 1 (Early): Basic farming - sell 1-5 coins
	Tier 2 (Early-Mid): Better crops, ores - sell 5-15 coins
	Tier 3 (Mid): Processed materials - sell 15-40 coins
	Tier 4 (Late): Rare materials - sell 40-100+ coins
	Tier 5 (End-game): Premium decoratives - money sink only
]]

local NPCTradeConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- ECONOMY CONSTANTS
-- ═══════════════════════════════════════════════════════════════════════════

local SELL_MULTIPLIER = {
	RAW_RESOURCE = 0.50,    -- Raw blocks sell at 50% of buy (best for farmers)
	PROCESSED = 0.45,       -- Processed materials at 45%
	TOOL = 0.40,            -- Tools at 40% (prevent tool flipping)
	DECORATION = 0.40,      -- Decoratives at 40% (money sinks)
	UTILITY = 0.35,         -- Utility blocks at 35% (strong money sink)
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SHOP ITEMS (What players can BUY from Shop Keeper)
-- Categories: Tools, Seeds, Utility, Materials, Building, Decoration
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.ShopItems = {
	-- ═══════════════════════════════════════════════════════════════════════
	-- STARTER TOOLS (affordable, low stock to prevent hoarding)
	-- ═══════════════════════════════════════════════════════════════════════
	{ itemId = 1001, price = 50,   stock = 5,  category = "Tools" },   -- Copper Pickaxe
	{ itemId = 1011, price = 50,   stock = 5,  category = "Tools" },   -- Copper Axe
	{ itemId = 1021, price = 50,   stock = 5,  category = "Tools" },   -- Copper Shovel
	{ itemId = 1041, price = 75,   stock = 3,  category = "Tools" },   -- Copper Sword
	
	-- MID-TIER TOOLS (unlock after some farming)
	{ itemId = 1002, price = 250,  stock = 3,  category = "Tools" },   -- Iron Pickaxe
	{ itemId = 1012, price = 250,  stock = 3,  category = "Tools" },   -- Iron Axe
	{ itemId = 1022, price = 250,  stock = 3,  category = "Tools" },   -- Iron Shovel
	{ itemId = 1042, price = 350,  stock = 2,  category = "Tools" },   -- Iron Sword
	
	-- ARROWS (ammo sink - tiered)
	{ itemId = 2001, price = 5,    stock = 64, category = "Ammo" },    -- Copper Arrow
	{ itemId = 2002, price = 10,   stock = 32, category = "Ammo" },    -- Iron Arrow
	{ itemId = 2003, price = 20,   stock = 16, category = "Ammo" },    -- Steel Arrow
	{ itemId = 2004, price = 40,   stock = 8,  category = "Ammo" },    -- Bluesteel Arrow
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- SEEDS & FARMING (kickstart farming loop)
	-- ═══════════════════════════════════════════════════════════════════════
	{ itemId = 70,  price = 10,  stock = 16, category = "Seeds" },     -- Wheat Seeds
	{ itemId = 74,  price = 15,  stock = 16, category = "Seeds" },     -- Beetroot Seeds
	{ itemId = 72,  price = 20,  stock = 8,  category = "Seeds" },     -- Potato (plantable)
	{ itemId = 73,  price = 20,  stock = 8,  category = "Seeds" },     -- Carrot (plantable)
	
	-- SAPLINGS (tree farming)
	{ itemId = 16,  price = 25,  stock = 8,  category = "Seeds" },     -- Oak Sapling
	{ itemId = 40,  price = 30,  stock = 6,  category = "Seeds" },     -- Spruce Sapling
	{ itemId = 55,  price = 30,  stock = 6,  category = "Seeds" },     -- Birch Sapling
	{ itemId = 45,  price = 40,  stock = 4,  category = "Seeds" },     -- Jungle Sapling
	{ itemId = 50,  price = 40,  stock = 4,  category = "Seeds" },     -- Dark Oak Sapling
	{ itemId = 60,  price = 50,  stock = 4,  category = "Seeds" },     -- Acacia Sapling
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- UTILITY BLOCKS (money sinks - essential for progression)
	-- ═══════════════════════════════════════════════════════════════════════
	{ itemId = 13,  price = 100,  stock = 3,  category = "Utility" },  -- Crafting Table
	{ itemId = 35,  price = 150,  stock = 3,  category = "Utility" },  -- Furnace
	{ itemId = 9,   price = 200,  stock = 5,  category = "Utility" },  -- Chest
	{ itemId = 96,  price = 250,  stock = 2,  category = "Utility" },  -- Composter
	
	-- AUTOMATION (expensive - late game money sink)
	{ itemId = 97,  price = 2500, stock = 1,  category = "Utility" },  -- Cobblestone Minion
	{ itemId = 123, price = 5000, stock = 1,  category = "Utility" },  -- Coal Minion
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- RAW MATERIALS (buy price > sell price, for convenience)
	-- ═══════════════════════════════════════════════════════════════════════
	{ itemId = 14,  price = 4,    stock = 128, category = "Materials" }, -- Cobblestone
	{ itemId = 3,   price = 6,    stock = 64,  category = "Materials" }, -- Stone
	{ itemId = 2,   price = 3,    stock = 64,  category = "Materials" }, -- Dirt
	{ itemId = 10,  price = 5,    stock = 64,  category = "Materials" }, -- Sand
	{ itemId = 173, price = 4,    stock = 32,  category = "Materials" }, -- Gravel
	{ itemId = 279, price = 8,    stock = 32,  category = "Materials" }, -- Clay Block
	
	-- PROCESSED MATERIALS (convenience buy, sell at loss)
	{ itemId = 32,  price = 10,   stock = 32,  category = "Materials" }, -- Coal
	{ itemId = 105, price = 30,   stock = 16,  category = "Materials" }, -- Copper Ingot
	{ itemId = 33,  price = 50,   stock = 16,  category = "Materials" }, -- Iron Ingot
	{ itemId = 108, price = 80,   stock = 8,   category = "Materials" }, -- Steel Ingot
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- BUILDING BLOCKS (island expansion - major money sink)
	-- ═══════════════════════════════════════════════════════════════════════
	{ itemId = 15,  price = 8,    stock = 64,  category = "Building" },  -- Bricks
	{ itemId = 11,  price = 10,   stock = 64,  category = "Building" },  -- Stone Bricks
	{ itemId = 36,  price = 12,   stock = 64,  category = "Building" },  -- Glass
	{ itemId = 175, price = 15,   stock = 32,  category = "Building" },  -- Sandstone
	{ itemId = 172, price = 20,   stock = 32,  category = "Building" },  -- Nether Bricks
	
	-- STAIRS & SLABS (building details)
	{ itemId = 17,  price = 6,    stock = 32,  category = "Building" },  -- Oak Stairs
	{ itemId = 18,  price = 8,    stock = 32,  category = "Building" },  -- Stone Stairs
	{ itemId = 22,  price = 4,    stock = 32,  category = "Building" },  -- Oak Slab
	{ itemId = 23,  price = 5,    stock = 32,  category = "Building" },  -- Stone Slab
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- DECORATIVE BLOCKS (pure money sinks - late game inflation control)
	-- ═══════════════════════════════════════════════════════════════════════
	
	-- COLORED WOOL (Tier 1 decoration)
	{ itemId = 156, price = 15,   stock = 16, category = "Decoration" }, -- White Wool
	{ itemId = 157, price = 15,   stock = 16, category = "Decoration" }, -- Orange Wool
	{ itemId = 158, price = 15,   stock = 16, category = "Decoration" }, -- Magenta Wool
	{ itemId = 159, price = 15,   stock = 16, category = "Decoration" }, -- Light Blue Wool
	{ itemId = 160, price = 15,   stock = 16, category = "Decoration" }, -- Yellow Wool
	{ itemId = 161, price = 15,   stock = 16, category = "Decoration" }, -- Lime Wool
	{ itemId = 162, price = 15,   stock = 16, category = "Decoration" }, -- Pink Wool
	{ itemId = 163, price = 15,   stock = 16, category = "Decoration" }, -- Gray Wool
	{ itemId = 170, price = 15,   stock = 16, category = "Decoration" }, -- Red Wool
	{ itemId = 167, price = 15,   stock = 16, category = "Decoration" }, -- Blue Wool
	{ itemId = 169, price = 15,   stock = 16, category = "Decoration" }, -- Green Wool
	{ itemId = 171, price = 15,   stock = 16, category = "Decoration" }, -- Black Wool
	
	-- STAINED GLASS (Tier 2 decoration)
	{ itemId = 123, price = 25,   stock = 16, category = "Decoration" }, -- White Stained Glass
	{ itemId = 124, price = 25,   stock = 16, category = "Decoration" }, -- Orange Stained Glass
	{ itemId = 125, price = 25,   stock = 16, category = "Decoration" }, -- Magenta Stained Glass
	{ itemId = 126, price = 25,   stock = 16, category = "Decoration" }, -- Light Blue Stained Glass
	{ itemId = 127, price = 25,   stock = 16, category = "Decoration" }, -- Yellow Stained Glass
	{ itemId = 128, price = 25,   stock = 16, category = "Decoration" }, -- Lime Stained Glass
	{ itemId = 134, price = 25,   stock = 16, category = "Decoration" }, -- Blue Stained Glass
	{ itemId = 137, price = 25,   stock = 16, category = "Decoration" }, -- Red Stained Glass
	{ itemId = 136, price = 25,   stock = 16, category = "Decoration" }, -- Green Stained Glass
	{ itemId = 138, price = 25,   stock = 16, category = "Decoration" }, -- Black Stained Glass
	
	-- TERRACOTTA (Tier 2 decoration)
	{ itemId = 139, price = 20,   stock = 16, category = "Decoration" }, -- Terracotta
	{ itemId = 140, price = 25,   stock = 16, category = "Decoration" }, -- White Terracotta
	{ itemId = 141, price = 25,   stock = 16, category = "Decoration" }, -- Orange Terracotta
	{ itemId = 151, price = 25,   stock = 16, category = "Decoration" }, -- Blue Terracotta
	{ itemId = 154, price = 25,   stock = 16, category = "Decoration" }, -- Red Terracotta
	{ itemId = 155, price = 25,   stock = 16, category = "Decoration" }, -- Black Terracotta
	
	-- CONCRETE (Tier 3 decoration - clean modern look)
	{ itemId = 180, price = 35,   stock = 16, category = "Decoration" }, -- White Concrete
	{ itemId = 181, price = 35,   stock = 16, category = "Decoration" }, -- Orange Concrete
	{ itemId = 182, price = 35,   stock = 16, category = "Decoration" }, -- Magenta Concrete
	{ itemId = 183, price = 35,   stock = 16, category = "Decoration" }, -- Light Blue Concrete
	{ itemId = 184, price = 35,   stock = 16, category = "Decoration" }, -- Yellow Concrete
	{ itemId = 185, price = 35,   stock = 16, category = "Decoration" }, -- Lime Concrete
	{ itemId = 191, price = 35,   stock = 16, category = "Decoration" }, -- Blue Concrete
	{ itemId = 194, price = 35,   stock = 16, category = "Decoration" }, -- Red Concrete
	{ itemId = 195, price = 35,   stock = 16, category = "Decoration" }, -- Black Concrete
	
	-- PREMIUM DECORATIVES (Tier 4 - expensive money sinks)
	{ itemId = 216, price = 100,  stock = 8,  category = "Premium" },    -- Quartz Block
	{ itemId = 217, price = 120,  stock = 8,  category = "Premium" },    -- Quartz Pillar
	{ itemId = 241, price = 150,  stock = 8,  category = "Premium" },    -- Prismarine
	{ itemId = 242, price = 180,  stock = 8,  category = "Premium" },    -- Prismarine Bricks
	{ itemId = 243, price = 200,  stock = 8,  category = "Premium" },    -- Dark Prismarine
	{ itemId = 244, price = 250,  stock = 8,  category = "Premium" },    -- Purpur Block
	{ itemId = 240, price = 300,  stock = 4,  category = "Premium" },    -- Sea Lantern
	{ itemId = 237, price = 350,  stock = 4,  category = "Premium" },    -- Glowstone
	
	-- ULTRA PREMIUM (Tier 5 - end-game wealth sinks)
	{ itemId = 271, price = 500,  stock = 4,  category = "Premium" },    -- Obsidian
	{ itemId = 246, price = 750,  stock = 4,  category = "Premium" },    -- End Stone
	{ itemId = 247, price = 1000, stock = 2,  category = "Premium" },    -- End Stone Bricks
	{ itemId = 310, price = 1500, stock = 2,  category = "Premium" },    -- Crying Obsidian
	{ itemId = 305, price = 2000, stock = 2,  category = "Premium" },    -- Amethyst Block
	{ itemId = 344, price = 10000,stock = 1,  category = "Premium" },    -- Beacon
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SELL PRICES (What Merchant buys FROM players)
-- Prices set at 40-60% of buy price to prevent arbitrage
-- Higher margin for farmable resources (encourages farming)
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.SellPrices = {
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 1: BASIC FARMABLES (best margins - core income source)
	-- ═══════════════════════════════════════════════════════════════════════
	
	-- Basic Blocks (always available, consistent income)
	[14] = 2,    -- Cobblestone (buy 4, sell 2 = 50%)
	[3]  = 3,    -- Stone (buy 6, sell 3 = 50%)
	[2]  = 1,    -- Dirt (buy 3, sell 1 = 33%)
	[10] = 2,    -- Sand (buy 5, sell 2 = 40%)
	[173] = 2,   -- Gravel (buy 4, sell 2 = 50%)
	
	-- Logs (renewable via saplings - good income)
	[5]   = 4,   -- Oak Log
	[38]  = 5,   -- Spruce Log
	[53]  = 5,   -- Birch Log
	[43]  = 6,   -- Jungle Log
	[48]  = 6,   -- Dark Oak Log
	[58]  = 7,   -- Acacia Log
	
	-- Planks (processed from logs - lower margin)
	[12]  = 1,   -- Oak Planks
	[39]  = 1,   -- Spruce Planks
	[54]  = 1,   -- Birch Planks
	[44]  = 2,   -- Jungle Planks
	[49]  = 2,   -- Dark Oak Planks
	[59]  = 2,   -- Acacia Planks
	
	-- Leaves (byproduct - minimal value)
	[6]   = 1,   -- Oak Leaves
	[63]  = 1,   -- Oak Leaves (alternate ID)
	[64]  = 1,   -- Spruce Leaves
	[65]  = 1,   -- Jungle Leaves
	[66]  = 1,   -- Dark Oak Leaves
	[67]  = 1,   -- Birch Leaves
	[68]  = 1,   -- Acacia Leaves
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 1: CROPS (core farming income)
	-- ═══════════════════════════════════════════════════════════════════════
	[71]  = 3,   -- Wheat (main early crop)
	[72]  = 4,   -- Potato
	[73]  = 4,   -- Carrot
	[75]  = 5,   -- Beetroot
	[37]  = 5,   -- Apple (tree drop)
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 2: ORES (mining income - scales with tools)
	-- ═══════════════════════════════════════════════════════════════════════
	[29]  = 5,   -- Coal Ore
	[98]  = 8,   -- Copper Ore
	[30]  = 12,  -- Iron Ore
	[101] = 20,  -- Bluesteel Ore
	[31]  = 100, -- Diamond Ore
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 3: PROCESSED MATERIALS (lower margin - convenience tax)
	-- ═══════════════════════════════════════════════════════════════════════
	[32]  = 4,   -- Coal (buy 10, sell 4 = 40%)
	[105] = 12,  -- Copper Ingot (buy 30, sell 12 = 40%)
	[33]  = 20,  -- Iron Ingot (buy 50, sell 20 = 40%)
	[108] = 32,  -- Steel Ingot (buy 80, sell 32 = 40%)
	[34]  = 200, -- Diamond
	[109] = 50,  -- Bluesteel Ingot
	[115] = 15,  -- Bluesteel Dust
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 3: STORAGE BLOCKS (bulk selling - slight discount)
	-- 9 ingots = block, but sell at 8x ingot price (incentive to sell ingots)
	-- ═══════════════════════════════════════════════════════════════════════
	[117] = 30,   -- Coal Block (8x4 = 32, sell 30)
	[116] = 90,   -- Copper Block (8x12 = 96, sell 90)
	[118] = 150,  -- Iron Block (8x20 = 160, sell 150)
	[119] = 240,  -- Steel Block (8x32 = 256, sell 240)
	[120] = 375,  -- Bluesteel Block
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- TIER 2: FOOD (farming byproducts)
	-- ═══════════════════════════════════════════════════════════════════════
	[348] = 5,   -- Bread (3 wheat = 1 bread worth 5)
	[349] = 6,   -- Baked Potato
	[350] = 8,   -- Cooked Beef
	[351] = 8,   -- Cooked Porkchop
	[352] = 6,   -- Cooked Chicken
	[353] = 7,   -- Cooked Mutton
	[355] = 5,   -- Cooked Cod
	[356] = 6,   -- Cooked Salmon
	
	-- Raw Meat (less value than cooked - incentive to smelt)
	[357] = 3,   -- Raw Beef
	[358] = 3,   -- Raw Porkchop
	[359] = 2,   -- Raw Chicken
	[360] = 3,   -- Raw Mutton
	[362] = 2,   -- Raw Cod
	[363] = 3,   -- Raw Salmon
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- BUILDING BLOCKS (sell at ~40% of buy - money sink)
	-- ═══════════════════════════════════════════════════════════════════════
	[15]  = 3,   -- Bricks (buy 8, sell 3 = 37.5%)
	[11]  = 4,   -- Stone Bricks (buy 10, sell 4 = 40%)
	[36]  = 5,   -- Glass (buy 12, sell 5 = 42%)
	[175] = 6,   -- Sandstone (buy 15, sell 6 = 40%)
	[172] = 8,   -- Nether Bricks (buy 20, sell 8 = 40%)
	[279] = 3,   -- Clay Block (buy 8, sell 3 = 37.5%)
	
	-- Stairs & Slabs
	[17]  = 2,   -- Oak Stairs
	[18]  = 3,   -- Stone Stairs
	[22]  = 1,   -- Oak Slab
	[23]  = 2,   -- Stone Slab
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- DECORATIVES (very low sell - pure money sink category)
	-- ═══════════════════════════════════════════════════════════════════════
	
	-- Wool (buy 15, sell 5 = 33%)
	[156] = 5, [157] = 5, [158] = 5, [159] = 5, [160] = 5,
	[161] = 5, [162] = 5, [163] = 5, [167] = 5, [169] = 5,
	[170] = 5, [171] = 5,
	
	-- Stained Glass (buy 25, sell 8 = 32%)
	[123] = 8, [124] = 8, [125] = 8, [126] = 8, [127] = 8,
	[128] = 8, [134] = 8, [136] = 8, [137] = 8, [138] = 8,
	
	-- Terracotta (buy 20-25, sell 7-8 = 32-35%)
	[139] = 7, [140] = 8, [141] = 8, [151] = 8, [154] = 8, [155] = 8,
	
	-- Concrete (buy 35, sell 12 = 34%)
	[180] = 12, [181] = 12, [182] = 12, [183] = 12, [184] = 12,
	[185] = 12, [191] = 12, [194] = 12, [195] = 12,
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- PREMIUM BLOCKS (very low sell % - end-game money sinks)
	-- ═══════════════════════════════════════════════════════════════════════
	[216] = 30,  -- Quartz Block (buy 100, sell 30 = 30%)
	[217] = 35,  -- Quartz Pillar
	[241] = 45,  -- Prismarine
	[242] = 55,  -- Prismarine Bricks
	[243] = 60,  -- Dark Prismarine
	[244] = 75,  -- Purpur Block
	[240] = 90,  -- Sea Lantern
	[237] = 100, -- Glowstone
	[271] = 150, -- Obsidian
	[246] = 225, -- End Stone
	[247] = 300, -- End Stone Bricks
	[310] = 450, -- Crying Obsidian
	[305] = 600, -- Amethyst Block
	[344] = 3000,-- Beacon (buy 10000, sell 3000 = 30%)
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- UTILITY BLOCKS (very low sell - discourage selling)
	-- ═══════════════════════════════════════════════════════════════════════
	[13]  = 30,  -- Crafting Table (buy 100, sell 30 = 30%)
	[35]  = 45,  -- Furnace (buy 150, sell 45 = 30%)
	[9]   = 60,  -- Chest (buy 200, sell 60 = 30%)
	[96]  = 75,  -- Composter
	
	-- Minions (automation - very low resale)
	[97]  = 500,  -- Cobblestone Minion (buy 2500, sell 500 = 20%)
	
	-- ═══════════════════════════════════════════════════════════════════════
	-- MISC DROPS & ITEMS
	-- ═══════════════════════════════════════════════════════════════════════
	[28]  = 1,   -- Stick
	[266] = 20,  -- Bookshelf
	[254] = 15,  -- Hay Block
	[248] = 20,  -- Melon
	[249] = 15,  -- Pumpkin
	[252] = 10,  -- Cactus
	
	-- Arrows (tiered)
	[2001] = 2,   -- Copper Arrow (buy 5, sell 2 = 40%)
	[2002] = 4,   -- Iron Arrow (buy 10, sell 4 = 40%)
	[2003] = 8,   -- Steel Arrow (buy 20, sell 8 = 40%)
	[2004] = 16,  -- Bluesteel Arrow (buy 40, sell 16 = 40%)
}

-- Tool sell multiplier (% of shop price)
NPCTradeConfig.ToolSellMultiplier = 0.40

-- Armor sell multiplier (% of crafting value)
NPCTradeConfig.ArmorSellMultiplier = 0.30

-- ═══════════════════════════════════════════════════════════════════════════
-- STOCK REPLENISHMENT
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.Stock = {
	replenishInterval = 300,     -- 5 minutes
	replenishPercent = 0.25,     -- 25% of max stock per cycle
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS THAT CANNOT BE SOLD (prevent exploits)
-- ═══════════════════════════════════════════════════════════════════════════

NPCTradeConfig.UnsellableItems = {
	[0]   = true, -- Air
	[4]   = true, -- Bedrock
	[1]   = true, -- Grass Block (unobtainable)
	[7]   = true, -- Tall Grass
	[8]   = true, -- Flower
	[69]  = true, -- Farmland
	[70]  = true, -- Wheat Seeds (too easy to farm)
	[74]  = true, -- Beetroot Seeds
	[270] = true, -- Spawner
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

function NPCTradeConfig.GetSellPrice(itemId)
	-- Check explicit sell prices
	local basePrice = NPCTradeConfig.SellPrices[itemId]
	if basePrice then
		return basePrice
	end
	
	-- Check if it's a tool (sell at 40% of shop price)
	local shopItem = NPCTradeConfig.GetShopItem(itemId)
	if shopItem then
		return math.floor(shopItem.price * NPCTradeConfig.ToolSellMultiplier)
	end
	
	-- Default: 1 coin (for unlisted items)
	return 1
end

function NPCTradeConfig.CanSellItem(itemId)
	-- Check unsellable list
	if NPCTradeConfig.UnsellableItems[itemId] then
		return false
	end
	
	-- Items with explicit sell prices can be sold
	if NPCTradeConfig.SellPrices[itemId] then
		return true
	end
	
	-- Tools from shop can be sold
	if NPCTradeConfig.GetShopItem(itemId) then
		return true
	end
	
	-- Exclude spawn eggs and special items
	if itemId >= 4000 then
		return false
	end
	
	-- Allow most items to be sold for 1 coin
	return true
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

-- Debug: Check for arbitrage opportunities
function NPCTradeConfig.ValidateNoArbitrage()
	local issues = {}
	for _, shopItem in ipairs(NPCTradeConfig.ShopItems) do
		local sellPrice = NPCTradeConfig.GetSellPrice(shopItem.itemId)
		if sellPrice >= shopItem.price then
			table.insert(issues, string.format(
				"ARBITRAGE: Item %d - Buy %d, Sell %d",
				shopItem.itemId, shopItem.price, sellPrice
			))
		end
	end
	return issues
end

return NPCTradeConfig
