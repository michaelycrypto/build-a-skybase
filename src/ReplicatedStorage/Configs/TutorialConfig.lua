--[[
	TutorialConfig.lua - Tutorial/Onboarding Configuration

	Skyblock-Style Economy Tutorial:
	Players start with tools, learn to farm resources, sell to merchant, buy from shop.

	Progression Loop:
	Move → Look → Inventory → Chop Trees → Sell to Merchant → Visit Shop →
	Plant Sapling → Harvest Crops → Craft Storage → Mine Ores → Smelt → Complete!

	Tutorial Philosophy:
	- Non-intrusive guidance (tooltips, not forced cutscenes)
	- Progressive revelation (only show relevant info)
	- Skippable but incentivized with small rewards
	- Focus on the ECONOMY loop (farm → sell → buy → expand)
]]

local TutorialConfig = {}

-- Tutorial step categories
TutorialConfig.Categories = {
	BASICS = "basics",           -- Movement, camera, UI
	GATHERING = "gathering",     -- Breaking blocks, collecting resources
	ECONOMY = "economy",         -- Shop, merchant, selling
	FARMING = "farming",         -- Planting, harvesting
	CRAFTING = "crafting",       -- Workbench, recipes
	SMELTING = "smelting",       -- Furnace, ingots
}

-- Individual tutorial steps with triggers and objectives
TutorialConfig.Steps = {
	-- ═══════════════════════════════════════════════════════════════════════════
	-- BASICS - Movement & Interface
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "welcome",
		category = "basics",
		title = "Welcome to Skyblox!",
		description = "Your island adventure begins! You've been given starter tools and some coins. Let's learn the basics!",
		hint = "Use WASD to move around. Look around with your mouse.",
		trigger = {
			type = "immediate",
		},
		objective = {
			type = "move",
			distance = 10,
		},
		reward = nil,
		nextStep = "look_around",
		uiType = "popup",
		canSkip = false,
	},

	{
		id = "look_around",
		category = "basics",
		title = "Look Around",
		description = "Press F5 to cycle through camera modes. Try all 3!",
		hint = "F5 cycles: First Person → Third Person Lock → Third Person Free",
		trigger = {
			type = "step_complete",
			step = "welcome",
		},
		objective = {
			type = "camera_cycle",
			count = 3,
		},
		reward = nil,
		nextStep = "open_inventory",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "open_inventory",
		category = "basics",
		title = "Check Your Inventory",
		description = "Press E to open your inventory. You already have tools and seeds!",
		hint = "Press E to open/close inventory. Check out your starter kit!",
		trigger = {
			type = "step_complete",
			step = "look_around",
		},
		objective = {
			type = "ui_open",
			panel = "inventory",
		},
		reward = nil,
		nextStep = "gather_wood",
		uiType = "tooltip",
		highlightKey = "E",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- GATHERING - Your First Resources
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "gather_wood",
		category = "gathering",
		title = "Chop Some Trees",
		description = "Use your Copper Axe to chop trees! Wood is valuable - you can sell it.",
		hint = "Select your axe (slot 2) and hold left-click on tree trunks. Axes chop faster!",
		trigger = {
			type = "step_complete",
			step = "open_inventory",
		},
		objective = {
			type = "collect_item",
			itemType = "log",
			anyOf = {5, 38, 43, 48, 53, 58}, -- All log types
			count = 8,
		},
		reward = {
			coins = 10,
			message = "Nice haul! Logs sell for 4-7 coins each at the Merchant.",
		},
		nextStep = "visit_merchant",
		uiType = "objective",
		highlightBlockTypes = {5, 38, 43, 48, 53, 58},
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- ECONOMY - The Core Loop
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "visit_merchant",
		category = "economy",
		title = "Find the Merchant",
		description = "The Merchant buys your resources! Find an NPC with a 'SELL' sign in the hub.",
		hint = "Walk up to the Merchant NPC and press E or right-click to interact.",
		trigger = {
			type = "step_complete",
			step = "gather_wood",
		},
		objective = {
			type = "npc_interact",
			npcType = "merchant",
		},
		reward = {
			coins = 15,
			message = "You found the Merchant! Sell your resources here for coins.",
		},
		nextStep = "sell_items",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "sell_items",
		category = "economy",
		title = "Sell Your Resources",
		description = "Sell some of your logs to the Merchant. This is how you earn coins!",
		hint = "Click SELL on any item in the Merchant window. Logs sell for 4+ coins each!",
		trigger = {
			type = "step_complete",
			step = "visit_merchant",
		},
		objective = {
			type = "sell_item",
			count = 1, -- Sell at least 1 item
		},
		reward = {
			coins = 20,
			message = "Your first sale! Farming + Selling = Profit!",
		},
		nextStep = "visit_shop",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "visit_shop",
		category = "economy",
		title = "Visit the Shop Keeper",
		description = "The Shop Keeper sells useful items! Find the NPC with a 'BUY' sign.",
		hint = "Walk up to the Shop Keeper NPC and interact. Browse seeds, tools, and decorations!",
		trigger = {
			type = "step_complete",
			step = "sell_items",
		},
		objective = {
			type = "npc_interact",
			npcType = "shop",
		},
		reward = {
			coins = 10,
			message = "The Shop has seeds, utility blocks, and decorations. Spend wisely!",
		},
		nextStep = "plant_sapling",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- FARMING - Renewable Resources
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "plant_sapling",
		category = "farming",
		title = "Plant a Sapling",
		description = "Plant one of your Oak Saplings. Trees regrow - infinite wood!",
		hint = "Select a sapling from your inventory and right-click on dirt or grass to plant.",
		trigger = {
			type = "step_complete",
			step = "visit_shop",
		},
		objective = {
			type = "place_block",
			blockId = 16, -- OAK_SAPLING
			count = 1,
		},
		reward = {
			coins = 10,
			message = "Sapling planted! It will grow into a tree over time.",
		},
		nextStep = "plant_crops",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "plant_crops",
		category = "farming",
		title = "Start a Farm",
		description = "Use your shovel on dirt near water to make farmland, then plant seeds.",
		hint = "Right-click dirt with shovel → Farmland. Then place seeds on farmland.",
		trigger = {
			type = "step_complete",
			step = "plant_sapling",
		},
		objective = {
			type = "place_block",
			anyOf = {70, 72, 73, 74}, -- Wheat seeds, potato, carrot, beetroot seeds
			count = 4,
		},
		reward = {
			coins = 15,
			message = "Farm started! Crops grow over time and sell for coins.",
		},
		nextStep = "craft_chest",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- CRAFTING - Storage & Utilities
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "craft_chest",
		category = "crafting",
		title = "Craft a Chest",
		description = "Chests store your items! Open your inventory and craft one.",
		hint = "Press E → Crafting tab → Find Chest (8 planks). Use your Crafting Table for more recipes!",
		trigger = {
			type = "step_complete",
			step = "plant_crops",
		},
		objective = {
			type = "craft_item",
			itemId = 9, -- CHEST
			count = 1,
		},
		reward = {
			coins = 15,
			message = "Chest crafted! Place it to store your valuables.",
		},
		nextStep = "place_chest",
		uiType = "objective",
		highlightUI = "crafting_tab",
		canSkip = true,
	},

	{
		id = "place_chest",
		category = "crafting",
		title = "Place Your Chest",
		description = "Place your chest somewhere safe. Right-click to open it.",
		hint = "Select chest from hotbar, right-click to place. Right-click again to open.",
		trigger = {
			type = "step_complete",
			step = "craft_chest",
		},
		objective = {
			type = "place_block",
			blockId = 9, -- CHEST
			count = 1,
		},
		reward = {
			coins = 10,
			message = "Storage ready! Keep your valuable items safe.",
		},
		nextStep = "mine_ore",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- MINING & SMELTING - Advanced Resources
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "mine_ore",
		category = "gathering",
		title = "Mine Some Ore",
		description = "Use your Copper Pickaxe to mine ore. Look for colored specks in stone!",
		hint = "Coal = black specks, Copper = orange, Iron = tan. Ores sell for good coins!",
		trigger = {
			type = "step_complete",
			step = "place_chest",
		},
		objective = {
			type = "collect_item",
			anyOf = {29, 98, 30}, -- Coal ore, copper ore, iron ore
			count = 5,
		},
		reward = {
			coins = 20,
			message = "Ore collected! Smelt it into ingots for even more value.",
		},
		nextStep = "use_furnace",
		uiType = "objective",
		highlightBlockTypes = {29, 98, 30},
		canSkip = true,
	},

	{
		id = "use_furnace",
		category = "smelting",
		title = "Smelt Your Ore",
		description = "Use the Furnace to smelt ore into ingots. Ingots are worth more!",
		hint = "Right-click furnace → Select ore recipe → Play the smelting minigame!",
		trigger = {
			type = "step_complete",
			step = "mine_ore",
		},
		objective = {
			type = "collect_item",
			anyOf = {32, 105, 33}, -- Coal, copper ingot, iron ingot
			count = 3,
		},
		reward = {
			coins = 25,
			message = "Smelting mastered! Ingots sell for much more than raw ore.",
		},
		nextStep = "tutorial_complete",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMPLETION
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "tutorial_complete",
		category = "basics",
		title = "Tutorial Complete!",
		description = "You've learned the Skyblox economy! Farm resources, sell to the Merchant, buy upgrades from the Shop.",
		hint = [[
Next goals:
• Expand your farm for steady income
• Buy a Furnace (150 coins) if you haven't
• Save up for decorative blocks
• Work toward automation (Minions cost 2500+ coins!)
		]],
		trigger = {
			type = "step_complete",
			step = "use_furnace",
		},
		objective = nil,
		reward = {
			coins = 50,
			message = "🎉 Tutorial Complete! Here's a bonus to grow your island!",
		},
		nextStep = nil,
		uiType = "popup",
		canSkip = false,
	},
}

-- Create lookup table by step ID for fast access
TutorialConfig.StepsByID = {}
for _, step in ipairs(TutorialConfig.Steps) do
	TutorialConfig.StepsByID[step.id] = step
end

-- Get the first step of the tutorial
function TutorialConfig.GetFirstStep()
	return TutorialConfig.Steps[1]
end

-- Get a step by ID
function TutorialConfig.GetStep(stepId)
	return TutorialConfig.StepsByID[stepId]
end

-- Get the next step after a given step
function TutorialConfig.GetNextStep(stepId)
	local currentStep = TutorialConfig.StepsByID[stepId]
	if currentStep and currentStep.nextStep then
		return TutorialConfig.StepsByID[currentStep.nextStep]
	end
	return nil
end

-- Check if a step can be skipped
function TutorialConfig.CanSkipStep(stepId)
	local step = TutorialConfig.StepsByID[stepId]
	return step and step.canSkip
end

-- Get all steps in a category
function TutorialConfig.GetStepsByCategory(category)
	local steps = {}
	for _, step in ipairs(TutorialConfig.Steps) do
		if step.category == category then
			table.insert(steps, step)
		end
	end
	return steps
end

-- Calculate total tutorial rewards
function TutorialConfig.GetTotalRewards()
	local totalCoins = 0
	local totalGems = 0
	for _, step in ipairs(TutorialConfig.Steps) do
		if step.reward then
			totalCoins = totalCoins + (step.reward.coins or 0)
			totalGems = totalGems + (step.reward.gems or 0)
		end
	end
	return { coins = totalCoins, gems = totalGems }
end

-- Settings for tutorial behavior
TutorialConfig.Settings = {
	-- Timing
	tooltipDelay = 0.5,
	tooltipDuration = 10,
	popupDuration = 0, -- 0 = manual dismiss

	-- Appearance
	tooltipMaxWidth = 300,
	highlightColor = Color3.fromRGB(255, 215, 0), -- Gold
	highlightTransparency = 0.3,
	highlightPulseSpeed = 2,

	-- Behavior
	autoAdvance = true,
	showProgressBar = true,
	enableSkip = true,
	persistProgress = true,
}

return TutorialConfig
