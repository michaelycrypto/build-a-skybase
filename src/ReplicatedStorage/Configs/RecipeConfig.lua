--[[
	RecipeConfig.lua
	Defines all crafting recipes for the simplified crafting system

	4-tier progression: Copper → Iron → Steel → Bluesteel

	Smelting (Furnace):
	- Copper Ingot: Copper Ore + 1 Coal
	- Iron Ingot: Iron Ore + 1 Coal
	- Steel Ingot: Iron Ore + 2 Coal
	- Bluesteel Ingot: Iron Ore + 3 Coal + 1 Bluesteel Dust

	Recipe Format:
	{
		id = "recipe_id",
		name = "Display Name",
		category = RecipeConfig.Categories.XXX,
		inputs = {{itemId = X, count = Y}, ...},
		outputs = {{itemId = X, count = Y}, ...}
	}
]]

local RecipeConfig = {}

-- Recipe categories for UI organization
RecipeConfig.Categories = {
	MATERIALS = "Materials",
	SMELTING = "Smelting",
	TOOLS = "Tools",
	ARMOR = "Armor",
	BUILDING = "Building Blocks"
}

-- Recipe definitions
RecipeConfig.Recipes = {
	-- ═══════════════════════════════════════════════════════════════════════════
	-- BASIC MATERIAL CONVERSIONS
	-- ═══════════════════════════════════════════════════════════════════════════
	oak_planks = {
		id = "oak_planks",
		name = "Oak Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 5, count = 1}  -- 1x Oak Log (BlockType.WOOD)
		},
		outputs = {
			{itemId = 12, count = 4}  -- 4x Oak Planks (BlockType.OAK_PLANKS)
		}
	},

	sticks = {
		id = "sticks",
		name = "Sticks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 12, count = 2}  -- 2x Oak Planks
		},
		outputs = {
			{itemId = 28, count = 4}  -- 4x Sticks (BlockType.STICK = 28)
		}
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- SMELTING RECIPES (Furnace: Ore → Ingot, Coal is fuel not ingredient)
	-- Note: Coal cost is determined by SmeltingConfig based on ore tier
	--       Skilled play reduces coal consumption (up to 30% savings!)
	-- ═══════════════════════════════════════════════════════════════════════════

	smelt_copper = {
		id = "smelt_copper",
		name = "Copper Ingot",
		category = RecipeConfig.Categories.SMELTING,
		requiresFurnace = true,
		inputs = {
			{itemId = 98, count = 1}   -- 1x Copper Ore
		},
		outputs = { {itemId = 105, count = 1} }  -- 1x Copper Ingot
	},

	smelt_iron = {
		id = "smelt_iron",
		name = "Iron Ingot",
		category = RecipeConfig.Categories.SMELTING,
		requiresFurnace = true,
		inputs = {
			{itemId = 30, count = 1}   -- 1x Iron Ore
		},
		outputs = { {itemId = 33, count = 1} }  -- 1x Iron Ingot
	},

	smelt_steel = {
		id = "smelt_steel",
		name = "Steel Ingot",
		category = RecipeConfig.Categories.SMELTING,
		requiresFurnace = true,
		inputs = {
			{itemId = 30, count = 1}   -- 1x Iron Ore (more coal = higher temp steel)
		},
		outputs = { {itemId = 108, count = 1} }  -- 1x Steel Ingot
	},

	smelt_bluesteel = {
		id = "smelt_bluesteel",
		name = "Bluesteel Ingot",
		category = RecipeConfig.Categories.SMELTING,
		requiresFurnace = true,
		inputs = {
			{itemId = 30, count = 1},   -- 1x Iron Ore
			{itemId = 115, count = 1}   -- 1x Bluesteel Dust (catalyst)
		},
		outputs = { {itemId = 109, count = 1} }  -- 1x Bluesteel Ingot
	},


	-- ═══════════════════════════════════════════════════════════════════════════
	-- FULL BLOCKS (9x ingots/items → 1 block)
	-- ═══════════════════════════════════════════════════════════════════════════

	copper_block = {
		id = "copper_block",
		name = "Copper Block",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 105, count = 9} },  -- 9x Copper Ingot
		outputs = { {itemId = 116, count = 1} }  -- 1x Copper Block
	},

	coal_block = {
		id = "coal_block",
		name = "Coal Block",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 32, count = 9} },   -- 9x Coal
		outputs = { {itemId = 117, count = 1} }  -- 1x Coal Block
	},

	iron_block = {
		id = "iron_block",
		name = "Iron Block",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 33, count = 9} },   -- 9x Iron Ingot
		outputs = { {itemId = 118, count = 1} }  -- 1x Iron Block
	},

	steel_block = {
		id = "steel_block",
		name = "Steel Block",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 108, count = 9} },  -- 9x Steel Ingot
		outputs = { {itemId = 119, count = 1} }  -- 1x Steel Block
	},

	bluesteel_block = {
		id = "bluesteel_block",
		name = "Bluesteel Block",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 109, count = 9} },  -- 9x Bluesteel Ingot
		outputs = { {itemId = 120, count = 1} }  -- 1x Bluesteel Block
	},


	-- ═══════════════════════════════════════════════════════════════════════════
	-- COPPER TOOLS (Tier 1)
	-- ═══════════════════════════════════════════════════════════════════════════

	copper_pickaxe = {
		id = "copper_pickaxe",
		name = "Copper Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 105, count = 3},  -- 3x Copper Ingot
			{itemId = 28, count = 2}    -- 2x Sticks
		},
		outputs = { {itemId = 1001, count = 1} }
	},

	copper_axe = {
		id = "copper_axe",
		name = "Copper Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 105, count = 3},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1011, count = 1} }
	},

	copper_shovel = {
		id = "copper_shovel",
		name = "Copper Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 105, count = 1},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1021, count = 1} }
	},

	copper_sword = {
		id = "copper_sword",
		name = "Copper Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 105, count = 2},
			{itemId = 28, count = 1}
		},
		outputs = { {itemId = 1041, count = 1} }
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- IRON TOOLS (Tier 2)
	-- ═══════════════════════════════════════════════════════════════════════════

	iron_pickaxe = {
		id = "iron_pickaxe",
		name = "Iron Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 3},  -- 3x Iron Ingot
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1002, count = 1} }
	},

	iron_axe = {
		id = "iron_axe",
		name = "Iron Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 3},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1012, count = 1} }
	},

	iron_shovel = {
		id = "iron_shovel",
		name = "Iron Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 1},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1022, count = 1} }
	},

	iron_sword = {
		id = "iron_sword",
		name = "Iron Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 2},
			{itemId = 28, count = 1}
		},
		outputs = { {itemId = 1042, count = 1} }
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- STEEL TOOLS (Tier 3)
	-- ═══════════════════════════════════════════════════════════════════════════

	steel_pickaxe = {
		id = "steel_pickaxe",
		name = "Steel Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 108, count = 3},  -- 3x Steel Ingot
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1003, count = 1} }
	},

	steel_axe = {
		id = "steel_axe",
		name = "Steel Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 108, count = 3},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1013, count = 1} }
	},

	steel_shovel = {
		id = "steel_shovel",
		name = "Steel Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 108, count = 1},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1023, count = 1} }
	},

	steel_sword = {
		id = "steel_sword",
		name = "Steel Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 108, count = 2},
			{itemId = 28, count = 1}
		},
		outputs = { {itemId = 1043, count = 1} }
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- BLUESTEEL TOOLS (Tier 4)
	-- ═══════════════════════════════════════════════════════════════════════════

	bluesteel_pickaxe = {
		id = "bluesteel_pickaxe",
		name = "Bluesteel Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 109, count = 3},  -- 3x Bluesteel Ingot
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1004, count = 1} }
	},

	bluesteel_axe = {
		id = "bluesteel_axe",
		name = "Bluesteel Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 109, count = 3},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1014, count = 1} }
	},

	bluesteel_shovel = {
		id = "bluesteel_shovel",
		name = "Bluesteel Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 109, count = 1},
			{itemId = 28, count = 2}
		},
		outputs = { {itemId = 1024, count = 1} }
	},

	bluesteel_sword = {
		id = "bluesteel_sword",
		name = "Bluesteel Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 109, count = 2},
			{itemId = 28, count = 1}
		},
		outputs = { {itemId = 1044, count = 1} }
	},


	-- ═══════════════════════════════════════════════════════════════════════════
	-- ARMOR RECIPES
	-- Helmet: 5 ingots, Chestplate: 8 ingots, Leggings: 7 ingots, Boots: 4 ingots
	-- ═══════════════════════════════════════════════════════════════════════════

	-- COPPER ARMOR (Tier 1) - ID 105 = Copper Ingot
	copper_helmet = {
		id = "copper_helmet",
		name = "Copper Helmet",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 105, count = 5} },
		outputs = { {itemId = 3001, count = 1} }
	},
	copper_chestplate = {
		id = "copper_chestplate",
		name = "Copper Chestplate",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 105, count = 8} },
		outputs = { {itemId = 3002, count = 1} }
	},
	copper_leggings = {
		id = "copper_leggings",
		name = "Copper Leggings",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 105, count = 7} },
		outputs = { {itemId = 3003, count = 1} }
	},
	copper_boots = {
		id = "copper_boots",
		name = "Copper Boots",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 105, count = 4} },
		outputs = { {itemId = 3004, count = 1} }
	},

	-- IRON ARMOR (Tier 2) - ID 33 = Iron Ingot
	iron_helmet = {
		id = "iron_helmet",
		name = "Iron Helmet",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 33, count = 5} },
		outputs = { {itemId = 3005, count = 1} }
	},
	iron_chestplate = {
		id = "iron_chestplate",
		name = "Iron Chestplate",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 33, count = 8} },
		outputs = { {itemId = 3006, count = 1} }
	},
	iron_leggings = {
		id = "iron_leggings",
		name = "Iron Leggings",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 33, count = 7} },
		outputs = { {itemId = 3007, count = 1} }
	},
	iron_boots = {
		id = "iron_boots",
		name = "Iron Boots",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 33, count = 4} },
		outputs = { {itemId = 3008, count = 1} }
	},

	-- STEEL ARMOR (Tier 3) - ID 108 = Steel Ingot
	steel_helmet = {
		id = "steel_helmet",
		name = "Steel Helmet",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 108, count = 5} },
		outputs = { {itemId = 3009, count = 1} }
	},
	steel_chestplate = {
		id = "steel_chestplate",
		name = "Steel Chestplate",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 108, count = 8} },
		outputs = { {itemId = 3010, count = 1} }
	},
	steel_leggings = {
		id = "steel_leggings",
		name = "Steel Leggings",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 108, count = 7} },
		outputs = { {itemId = 3011, count = 1} }
	},
	steel_boots = {
		id = "steel_boots",
		name = "Steel Boots",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 108, count = 4} },
		outputs = { {itemId = 3012, count = 1} }
	},

	-- BLUESTEEL ARMOR (Tier 4) - ID 109 = Bluesteel Ingot
	bluesteel_helmet = {
		id = "bluesteel_helmet",
		name = "Bluesteel Helmet",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 109, count = 5} },
		outputs = { {itemId = 3013, count = 1} }
	},
	bluesteel_chestplate = {
		id = "bluesteel_chestplate",
		name = "Bluesteel Chestplate",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 109, count = 8} },
		outputs = { {itemId = 3014, count = 1} }
	},
	bluesteel_leggings = {
		id = "bluesteel_leggings",
		name = "Bluesteel Leggings",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 109, count = 7} },
		outputs = { {itemId = 3015, count = 1} }
	},
	bluesteel_boots = {
		id = "bluesteel_boots",
		name = "Bluesteel Boots",
		category = RecipeConfig.Categories.ARMOR,
		requiresWorkbench = true,
		inputs = { {itemId = 109, count = 4} },
		outputs = { {itemId = 3016, count = 1} }
	},


	-- ═══════════════════════════════════════════════════════════════════════════
	-- BUILDING BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════════

	crafting_table = {
		id = "crafting_table",
		name = "Crafting Table",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 12, count = 4}  -- 4x Oak Planks
		},
		outputs = {
			{itemId = 13, count = 1}  -- 1x Crafting Table (BlockType.CRAFTING_TABLE)
		}
	},

	chest = {
		id = "chest",
		name = "Chest",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 8}  -- 8x Oak Planks
		},
		outputs = {
			{itemId = 9, count = 1}  -- 1x Chest (BlockType.CHEST)
		}
	},

	oak_stairs = {
		id = "oak_stairs",
		name = "Oak Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 6}  -- 6x Oak Planks
		},
		outputs = {
			{itemId = 17, count = 4}  -- 4x Oak Stairs (BlockType.OAK_STAIRS)
		}
	},

	oak_slab = {
		id = "oak_slab",
		name = "Oak Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 3}  -- 3x Oak Planks
		},
		outputs = {
			{itemId = 22, count = 6}  -- 6x Oak Slab (BlockType.OAK_SLAB)
		}
	},

	oak_fence = {
		id = "oak_fence",
		name = "Oak Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 2},  -- 2x Oak Planks
			{itemId = 28, count = 4}   -- 4x Sticks
		},
		outputs = {
			{itemId = 27, count = 3}  -- 3x Oak Fence (BlockType.OAK_FENCE)
		}
	},

	furnace = {
		id = "furnace",
		name = "Furnace",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 14, count = 8}  -- 8x Cobblestone
		},
		outputs = {
			{itemId = 35, count = 1}  -- 1x Furnace (BlockType.FURNACE)
		}
	},

	bucket = {
		id = "bucket",
		name = "Bucket",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 3}  -- 3x Iron Ingot (V-shape pattern)
		},
		outputs = {
			{itemId = 382, count = 1}  -- 1x Bucket
		}
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- WOOD FAMILY RECIPES
	-- ═══════════════════════════════════════════════════════════════════════════

	-- Logs -> Planks (4)
	spruce_planks = {
		id = "spruce_planks",
		name = "Spruce Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 38, count = 1} },
		outputs = { {itemId = 39, count = 4} }
	},

	jungle_planks = {
		id = "jungle_planks",
		name = "Jungle Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 43, count = 1} },
		outputs = { {itemId = 44, count = 4} }
	},

	dark_oak_planks = {
		id = "dark_oak_planks",
		name = "Dark Oak Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 48, count = 1} },
		outputs = { {itemId = 49, count = 4} }
	},

	birch_planks = {
		id = "birch_planks",
		name = "Birch Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 53, count = 1} },
		outputs = { {itemId = 54, count = 4} }
	},

	acacia_planks = {
		id = "acacia_planks",
		name = "Acacia Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 58, count = 1} },
		outputs = { {itemId = 59, count = 4} }
	},

	-- Sticks from any planks (2 -> 4)
	sticks_spruce = {
		id = "sticks_spruce",
		name = "Sticks (Spruce)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 39, count = 2} },
		outputs = { {itemId = 28, count = 4} }
	},

	sticks_jungle = {
		id = "sticks_jungle",
		name = "Sticks (Jungle)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 44, count = 2} },
		outputs = { {itemId = 28, count = 4} }
	},

	sticks_dark_oak = {
		id = "sticks_dark_oak",
		name = "Sticks (Dark Oak)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 49, count = 2} },
		outputs = { {itemId = 28, count = 4} }
	},

	sticks_birch = {
		id = "sticks_birch",
		name = "Sticks (Birch)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 54, count = 2} },
		outputs = { {itemId = 28, count = 4} }
	},

	sticks_acacia = {
		id = "sticks_acacia",
		name = "Sticks (Acacia)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = { {itemId = 59, count = 2} },
		outputs = { {itemId = 28, count = 4} }
	},

	-- Crafting Table from any planks (4 -> 1)
	crafting_table_spruce = {
		id = "crafting_table_spruce",
		name = "Crafting Table (Spruce)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = { {itemId = 39, count = 4} },
		outputs = { {itemId = 13, count = 1} }
	},

	crafting_table_jungle = {
		id = "crafting_table_jungle",
		name = "Crafting Table (Jungle)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = { {itemId = 44, count = 4} },
		outputs = { {itemId = 13, count = 1} }
	},

	crafting_table_dark_oak = {
		id = "crafting_table_dark_oak",
		name = "Crafting Table (Dark Oak)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = { {itemId = 49, count = 4} },
		outputs = { {itemId = 13, count = 1} }
	},

	crafting_table_birch = {
		id = "crafting_table_birch",
		name = "Crafting Table (Birch)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = { {itemId = 54, count = 4} },
		outputs = { {itemId = 13, count = 1} }
	},

	crafting_table_acacia = {
		id = "crafting_table_acacia",
		name = "Crafting Table (Acacia)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = { {itemId = 59, count = 4} },
		outputs = { {itemId = 13, count = 1} }
	},

	-- Chest from any planks (8 -> 1)
	chest_spruce = {
		id = "chest_spruce",
		name = "Chest (Spruce)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 39, count = 8} },
		outputs = { {itemId = 9, count = 1} }
	},

	chest_jungle = {
		id = "chest_jungle",
		name = "Chest (Jungle)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 44, count = 8} },
		outputs = { {itemId = 9, count = 1} }
	},

	chest_dark_oak = {
		id = "chest_dark_oak",
		name = "Chest (Dark Oak)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 49, count = 8} },
		outputs = { {itemId = 9, count = 1} }
	},

	chest_birch = {
		id = "chest_birch",
		name = "Chest (Birch)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 54, count = 8} },
		outputs = { {itemId = 9, count = 1} }
	},

	chest_acacia = {
		id = "chest_acacia",
		name = "Chest (Acacia)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 59, count = 8} },
		outputs = { {itemId = 9, count = 1} }
	},

	-- Stairs (6 planks -> 4 stairs)
	spruce_stairs = {
		id = "spruce_stairs",
		name = "Spruce Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 39, count = 6} },
		outputs = { {itemId = 41, count = 4} }
	},

	jungle_stairs = {
		id = "jungle_stairs",
		name = "Jungle Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 44, count = 6} },
		outputs = { {itemId = 46, count = 4} }
	},

	dark_oak_stairs = {
		id = "dark_oak_stairs",
		name = "Dark Oak Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 49, count = 6} },
		outputs = { {itemId = 51, count = 4} }
	},

	birch_stairs = {
		id = "birch_stairs",
		name = "Birch Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 54, count = 6} },
		outputs = { {itemId = 56, count = 4} }
	},

	acacia_stairs = {
		id = "acacia_stairs",
		name = "Acacia Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 59, count = 6} },
		outputs = { {itemId = 61, count = 4} }
	},

	-- Slabs (3 planks -> 6 slabs)
	spruce_slab = {
		id = "spruce_slab",
		name = "Spruce Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 39, count = 3} },
		outputs = { {itemId = 42, count = 6} }
	},

	jungle_slab = {
		id = "jungle_slab",
		name = "Jungle Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 44, count = 3} },
		outputs = { {itemId = 47, count = 6} }
	},

	dark_oak_slab = {
		id = "dark_oak_slab",
		name = "Dark Oak Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 49, count = 3} },
		outputs = { {itemId = 52, count = 6} }
	},

	birch_slab = {
		id = "birch_slab",
		name = "Birch Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 54, count = 3} },
		outputs = { {itemId = 57, count = 6} }
	},

	acacia_slab = {
		id = "acacia_slab",
		name = "Acacia Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = { {itemId = 59, count = 3} },
		outputs = { {itemId = 62, count = 6} }
	},

	-- Fences from any wood planks (2 planks + 4 sticks -> 3 fences)
	spruce_fence = {
		id = "spruce_fence",
		name = "Spruce Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 39, count = 2},
			{itemId = 28, count = 4}
		},
		outputs = { {itemId = 27, count = 3} }
	},

	jungle_fence = {
		id = "jungle_fence",
		name = "Jungle Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 44, count = 2},
			{itemId = 28, count = 4}
		},
		outputs = { {itemId = 27, count = 3} }
	},

	dark_oak_fence = {
		id = "dark_oak_fence",
		name = "Dark Oak Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 49, count = 2},
			{itemId = 28, count = 4}
		},
		outputs = { {itemId = 27, count = 3} }
	},

	birch_fence = {
		id = "birch_fence",
		name = "Birch Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 54, count = 2},
			{itemId = 28, count = 4}
		},
		outputs = { {itemId = 27, count = 3} }
	},

	acacia_fence = {
		id = "acacia_fence",
		name = "Acacia Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 59, count = 2},
			{itemId = 28, count = 4}
		},
		outputs = { {itemId = 27, count = 3} }
	}
}

--[[
	Get all recipes as an array (for iteration)
	@return: array - Array of all recipe definitions
]]
function RecipeConfig:GetAllRecipes()
	local recipes = {}
	for _, recipe in pairs(self.Recipes) do
		table.insert(recipes, recipe)
	end
	return recipes
end

--[[
	Get recipe by ID
	@param recipeId: string - Recipe identifier
	@return: table | nil - Recipe definition or nil
]]
function RecipeConfig:GetRecipe(recipeId)
	return self.Recipes[recipeId]
end

--[[
	Get recipes by category
	@param category: string - Category name
	@return: array - Array of recipes in category
]]
function RecipeConfig:GetRecipesByCategory(category)
	local filtered = {}
	for _, recipe in pairs(self.Recipes) do
		if recipe.category == category then
			table.insert(filtered, recipe)
		end
	end
	return filtered
end

return RecipeConfig
