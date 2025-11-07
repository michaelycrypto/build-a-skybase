--[[
	RecipeConfig.lua
	Defines all crafting recipes for the simplified crafting system

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
	TOOLS = "Tools",
	BUILDING = "Building Blocks"
}

-- Recipe definitions
RecipeConfig.Recipes = {
	-- Basic material conversions
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

	-- Tools
	wood_pickaxe = {
		id = "wood_pickaxe",
		name = "Wood Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 3},  -- 3x Oak Planks
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1001, count = 1}  -- 1x Wood Pickaxe (ToolConfig)
		}
	},

	wood_axe = {
		id = "wood_axe",
		name = "Wood Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 3},  -- 3x Oak Planks
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1011, count = 1}  -- 1x Wood Axe (ToolConfig)
		}
	},

	wood_shovel = {
		id = "wood_shovel",
		name = "Wood Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 1},  -- 1x Oak Planks
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1021, count = 1}  -- 1x Wood Shovel (ToolConfig)
		}
	},

	wood_sword = {
		id = "wood_sword",
		name = "Wood Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 12, count = 2},  -- 2x Oak Planks
			{itemId = 28, count = 1}   -- 1x Stick
		},
		outputs = {
			{itemId = 1041, count = 1}  -- 1x Wood Sword (ToolConfig)
		}
	},

	-- Stone Tools
	stone_pickaxe = {
		id = "stone_pickaxe",
		name = "Stone Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 14, count = 3},  -- 3x Cobblestone
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1002, count = 1}  -- 1x Stone Pickaxe
		}
	},

	stone_axe = {
		id = "stone_axe",
		name = "Stone Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 14, count = 3},  -- 3x Cobblestone
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1012, count = 1}  -- 1x Stone Axe
		}
	},

	stone_shovel = {
		id = "stone_shovel",
		name = "Stone Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 14, count = 1},  -- 1x Cobblestone
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1022, count = 1}  -- 1x Stone Shovel
		}
	},

	stone_sword = {
		id = "stone_sword",
		name = "Stone Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 14, count = 2},  -- 2x Cobblestone
			{itemId = 28, count = 1}   -- 1x Stick
		},
		outputs = {
			{itemId = 1042, count = 1}  -- 1x Stone Sword
		}
	},

	-- Iron Tools
	iron_pickaxe = {
		id = "iron_pickaxe",
		name = "Iron Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 3},  -- 3x Iron Ingot
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1003, count = 1}  -- 1x Iron Pickaxe
		}
	},

	iron_axe = {
		id = "iron_axe",
		name = "Iron Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 3},  -- 3x Iron Ingot
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1013, count = 1}  -- 1x Iron Axe
		}
	},

	iron_shovel = {
		id = "iron_shovel",
		name = "Iron Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 1},  -- 1x Iron Ingot
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1023, count = 1}  -- 1x Iron Shovel
		}
	},

	iron_sword = {
		id = "iron_sword",
		name = "Iron Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 33, count = 2},  -- 2x Iron Ingot
			{itemId = 28, count = 1}   -- 1x Stick
		},
		outputs = {
			{itemId = 1043, count = 1}  -- 1x Iron Sword
		}
	},

	-- Diamond Tools
	diamond_pickaxe = {
		id = "diamond_pickaxe",
		name = "Diamond Pickaxe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 34, count = 3},  -- 3x Diamond
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1004, count = 1}  -- 1x Diamond Pickaxe
		}
	},

	diamond_axe = {
		id = "diamond_axe",
		name = "Diamond Axe",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 34, count = 3},  -- 3x Diamond
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1014, count = 1}  -- 1x Diamond Axe
		}
	},

	diamond_shovel = {
		id = "diamond_shovel",
		name = "Diamond Shovel",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 34, count = 1},  -- 1x Diamond
			{itemId = 28, count = 2}   -- 2x Sticks
		},
		outputs = {
			{itemId = 1024, count = 1}  -- 1x Diamond Shovel
		}
	},

	diamond_sword = {
		id = "diamond_sword",
		name = "Diamond Sword",
		category = RecipeConfig.Categories.TOOLS,
		requiresWorkbench = true,
		inputs = {
			{itemId = 34, count = 2},  -- 2x Diamond
			{itemId = 28, count = 1}   -- 1x Stick
		},
		outputs = {
			{itemId = 1044, count = 1}  -- 1x Diamond Sword
		}
	},

	-- Building blocks
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

	-- Fences from any wood planks (2 planks + 4 sticks -> 3 fences)
	spruce_fence = {
		id = "spruce_fence",
		name = "Spruce Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 39, count = 2},  -- 2x Spruce Planks
			{itemId = 28, count = 4}   -- 4x Sticks
		},
		outputs = {
			{itemId = 27, count = 3}  -- 3x Fence (currently Oak Fence)
		}
	},

	jungle_fence = {
		id = "jungle_fence",
		name = "Jungle Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 44, count = 2},  -- 2x Jungle Planks
			{itemId = 28, count = 4}
		},
		outputs = {
			{itemId = 27, count = 3}
		}
	},

	dark_oak_fence = {
		id = "dark_oak_fence",
		name = "Dark Oak Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 49, count = 2},  -- 2x Dark Oak Planks
			{itemId = 28, count = 4}
		},
		outputs = {
			{itemId = 27, count = 3}
		}
	},

	birch_fence = {
		id = "birch_fence",
		name = "Birch Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 54, count = 2},  -- 2x Birch Planks
			{itemId = 28, count = 4}
		},
		outputs = {
			{itemId = 27, count = 3}
		}
	},

	acacia_fence = {
		id = "acacia_fence",
		name = "Acacia Fence",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 59, count = 2},  -- 2x Acacia Planks
			{itemId = 28, count = 4}
		},
		outputs = {
			{itemId = 27, count = 3}
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

	-- New wood families: Logs -> Planks (4)
	spuce_planks = { -- typo-safe note: actual id below is 'spruce_planks'
		id = "spruce_planks",
		name = "Spruce Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 38, count = 1}  -- 1x Spruce Log
		},
		outputs = {
			{itemId = 39, count = 4}  -- 4x Spruce Planks
		}
	},

	jungle_planks = {
		id = "jungle_planks",
		name = "Jungle Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 43, count = 1}  -- 1x Jungle Log
		},
		outputs = {
			{itemId = 44, count = 4}  -- 4x Jungle Planks
		}
	},

	dark_oak_planks = {
		id = "dark_oak_planks",
		name = "Dark Oak Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 48, count = 1}  -- 1x Dark Oak Log
		},
		outputs = {
			{itemId = 49, count = 4}  -- 4x Dark Oak Planks
		}
	},

	birch_planks = {
		id = "birch_planks",
		name = "Birch Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 53, count = 1}  -- 1x Birch Log
		},
		outputs = {
			{itemId = 54, count = 4}  -- 4x Birch Planks
		}
	},

	acacia_planks = {
		id = "acacia_planks",
		name = "Acacia Planks",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 58, count = 1}  -- 1x Acacia Log
		},
		outputs = {
			{itemId = 59, count = 4}  -- 4x Acacia Planks
		}
	},

	-- Sticks from any planks (2 -> 4)
	sticks_spruce = {
		id = "sticks_spruce",
		name = "Sticks (Spruce)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 39, count = 2}  -- 2x Spruce Planks
		},
		outputs = {
			{itemId = 28, count = 4}  -- 4x Sticks
		}
	},

	sticks_jungle = {
		id = "sticks_jungle",
		name = "Sticks (Jungle)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 44, count = 2}  -- 2x Jungle Planks
		},
		outputs = {
			{itemId = 28, count = 4}
		}
	},

	sticks_dark_oak = {
		id = "sticks_dark_oak",
		name = "Sticks (Dark Oak)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 49, count = 2}  -- 2x Dark Oak Planks
		},
		outputs = {
			{itemId = 28, count = 4}
		}
	},

	sticks_birch = {
		id = "sticks_birch",
		name = "Sticks (Birch)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 54, count = 2}  -- 2x Birch Planks
		},
		outputs = {
			{itemId = 28, count = 4}
		}
	},

	sticks_acacia = {
		id = "sticks_acacia",
		name = "Sticks (Acacia)",
		category = RecipeConfig.Categories.MATERIALS,
		inputs = {
			{itemId = 59, count = 2}  -- 2x Acacia Planks
		},
		outputs = {
			{itemId = 28, count = 4}
		}
	},

	-- Crafting Table from any planks (4 -> 1)
	crafting_table_spruce = {
		id = "crafting_table_spruce",
		name = "Crafting Table (Spruce)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 39, count = 4}
		},
		outputs = {
			{itemId = 13, count = 1}
		}
	},

	crafting_table_jungle = {
		id = "crafting_table_jungle",
		name = "Crafting Table (Jungle)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 44, count = 4}
		},
		outputs = {
			{itemId = 13, count = 1}
		}
	},

	crafting_table_dark_oak = {
		id = "crafting_table_dark_oak",
		name = "Crafting Table (Dark Oak)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 49, count = 4}
		},
		outputs = {
			{itemId = 13, count = 1}
		}
	},

	crafting_table_birch = {
		id = "crafting_table_birch",
		name = "Crafting Table (Birch)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 54, count = 4}
		},
		outputs = {
			{itemId = 13, count = 1}
		}
	},

	crafting_table_acacia = {
		id = "crafting_table_acacia",
		name = "Crafting Table (Acacia)",
		category = RecipeConfig.Categories.BUILDING,
		inputs = {
			{itemId = 59, count = 4}
		},
		outputs = {
			{itemId = 13, count = 1}
		}
	},

	-- Chest from any planks (8 -> 1)
	chest_spruce = {
		id = "chest_spruce",
		name = "Chest (Spruce)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 39, count = 8}
		},
		outputs = {
			{itemId = 9, count = 1}
		}
	},

	chest_jungle = {
		id = "chest_jungle",
		name = "Chest (Jungle)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 44, count = 8}
		},
		outputs = {
			{itemId = 9, count = 1}
		}
	},

	chest_dark_oak = {
		id = "chest_dark_oak",
		name = "Chest (Dark Oak)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 49, count = 8}
		},
		outputs = {
			{itemId = 9, count = 1}
		}
	},

	chest_birch = {
		id = "chest_birch",
		name = "Chest (Birch)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 54, count = 8}
		},
		outputs = {
			{itemId = 9, count = 1}
		}
	},

	chest_acacia = {
		id = "chest_acacia",
		name = "Chest (Acacia)",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 59, count = 8}
		},
		outputs = {
			{itemId = 9, count = 1}
		}
	},

	-- Stairs (6 planks -> 4 stairs)
	spruce_stairs = {
		id = "spruce_stairs",
		name = "Spruce Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 39, count = 6}
		},
		outputs = {
			{itemId = 41, count = 4}
		}
	},

	jungle_stairs = {
		id = "jungle_stairs",
		name = "Jungle Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 44, count = 6}
		},
		outputs = {
			{itemId = 46, count = 4}
		}
	},

	dark_oak_stairs = {
		id = "dark_oak_stairs",
		name = "Dark Oak Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 49, count = 6}
		},
		outputs = {
			{itemId = 51, count = 4}
		}
	},

	birch_stairs = {
		id = "birch_stairs",
		name = "Birch Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 54, count = 6}
		},
		outputs = {
			{itemId = 56, count = 4}
		}
	},

	acacia_stairs = {
		id = "acacia_stairs",
		name = "Acacia Stairs",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 59, count = 6}
		},
		outputs = {
			{itemId = 61, count = 4}
		}
	},

	-- Slabs (3 planks -> 6 slabs)
	spruce_slab = {
		id = "spruce_slab",
		name = "Spruce Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 39, count = 3}
		},
		outputs = {
			{itemId = 42, count = 6}
		}
	},

	jungle_slab = {
		id = "jungle_slab",
		name = "Jungle Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 44, count = 3}
		},
		outputs = {
			{itemId = 47, count = 6}
		}
	},

	dark_oak_slab = {
		id = "dark_oak_slab",
		name = "Dark Oak Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 49, count = 3}
		},
		outputs = {
			{itemId = 52, count = 6}
		}
	},

	birch_slab = {
		id = "birch_slab",
		name = "Birch Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 54, count = 3}
		},
		outputs = {
			{itemId = 57, count = 6}
		}
	},

	acacia_slab = {
		id = "acacia_slab",
		name = "Acacia Slab",
		category = RecipeConfig.Categories.BUILDING,
		requiresWorkbench = true,
		inputs = {
			{itemId = 59, count = 3}
		},
		outputs = {
			{itemId = 62, count = 6}
		}
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

