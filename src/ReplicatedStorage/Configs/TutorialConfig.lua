--[[
	TutorialConfig.lua - Tutorial/Onboarding Configuration

	Farming-First Economy Tutorial:
	Players learn farming on their island, then travel to hub to sell and buy.

	Progression Loop:
	Move → Look → Inventory → Find Farm → Plant Seeds → Harvest →
	Use Portal → Find Merchant → Sell Crops → Visit Shop → Buy Seeds →
	Return Home → Expand Farm → Complete!

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
	FARMING = "farming",         -- Planting, harvesting (FIRST!)
	TRAVEL = "travel",           -- Portal, hub navigation
	ECONOMY = "economy",         -- Shop, merchant, selling
	CRAFTING = "crafting",       -- Workbench, recipes
	GATHERING = "gathering",     -- Breaking blocks, collecting resources
}

-- Waypoint configuration for guiding players
TutorialConfig.Waypoints = {
	-- Island waypoints (player world)
	portal = {
		type = "block_area",
		offsetFromSpawn = Vector3.new(-9, 0, 0), -- Portal at offset (-3, 0) * BLOCK_SIZE
		radius = 2,
		color = Color3.fromRGB(128, 0, 128), -- Purple for portal
		label = "Hub Portal",
	},
	-- Hub waypoints (use NPC positions from NPCSpawnConfig)
	merchant = {
		type = "npc",
		npcId = "hub_merchant_1",
		color = Color3.fromRGB(255, 215, 0), -- Gold
		label = "Merchant",
	},
	farm_shop = {
		type = "npc",
		npcId = "hub_farm_shop_1",
		color = Color3.fromRGB(34, 197, 94), -- Green
		label = "Farm Shop",
	},
	warp_master = {
		type = "npc",
		npcId = "hub_warp_master_1",
		color = Color3.fromRGB(88, 101, 242), -- Blue
		label = "Warp Master",
	},
}

-- Individual tutorial steps with triggers and objectives
TutorialConfig.Steps = {
	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 1: BASICS - Movement & Interface
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "welcome",
		category = "basics",
		title = "Welcome to Skyblox!",
		description = "Your island adventure begins! You have a portal to the hub, pre-built farmland, and starter seeds. Let's grow your fortune!",
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
		title = "Equip Your Seeds",
		description = "Press E to open your inventory. Find the Wheat Seeds and drag them to your hotbar!",
		hint = "Press E → Find Wheat Seeds in your inventory → Drag to an empty hotbar slot at the bottom.",
		trigger = {
			type = "step_complete",
			step = "look_around",
		},
		objective = {
			type = "equip_item",
			itemId = 70, -- Wheat Seeds
		},
		reward = {
			coins = 5,
			message = "Great! Now you can use the seeds from your hotbar.",
		},
		nextStep = "plant_seeds",
		uiType = "objective",
		highlightKey = "E",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 2: FARMING - Your First Harvest (on island)
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "plant_seeds",
		category = "farming",
		title = "Plant Your Seeds",
		description = "Select the Wheat Seeds from your hotbar and right-click on the brown farmland!",
		hint = "Look for the tilled brown soil near the water. Right-click farmland to plant seeds.",
		trigger = {
			type = "step_complete",
			step = "open_inventory",
		},
		objective = {
			type = "place_block",
			blockId = 76, -- WHEAT_CROP_0 (placed when wheat seeds are planted)
			count = 4,
		},
		reward = {
			coins = 15,
			message = "Seeds planted! Now wait for them to grow...",
		},
		nextStep = "harvest_crops",
		uiType = "objective",
		-- Highlight the farmland blocks so player knows where to plant
		highlightBlockTypes = {69}, -- FARMLAND block type
		canSkip = true,
	},

	{
		id = "harvest_crops",
		category = "farming",
		title = "Harvest Your Crops",
		description = "Break the fully-grown wheat to harvest! Tip: Crops grow faster near water.",
		hint = "Left-click on mature wheat to harvest. You'll get wheat AND seeds back!",
		trigger = {
			type = "step_complete",
			step = "plant_seeds",
		},
		objective = {
			type = "collect_item",
			itemId = 71, -- Wheat only
			count = 4,
		},
		reward = {
			coins = 20,
			message = "Great harvest! Now let's sell these for coins.",
		},
		nextStep = "use_portal",
		uiType = "objective",
		-- Tutorial accelerated growth hint
		tutorialBoost = {
			cropGrowthMultiplier = 5, -- Crops grow 5x faster during this step
		},
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 3: TRAVEL - Portal to Hub
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "use_portal",
		category = "travel",
		title = "Use the Hub Portal",
		description = "Walk into the purple portal to travel to the Hub! The Hub has shops and merchants.",
		hint = "The obsidian portal with purple glass teleports you to the Hub.",
		trigger = {
			type = "step_complete",
			step = "harvest_crops",
		},
		objective = {
			type = "enter_world",
			worldType = "hub",
		},
		reward = {
			coins = 10,
			message = "Welcome to the Hub! This is where you sell crops and buy supplies.",
		},
		nextStep = "find_merchant",
		uiType = "objective",
		waypoint = "portal",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 4: ECONOMY - Sell & Buy in Hub
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "find_merchant",
		category = "economy",
		title = "Find the Merchant",
		description = "The Merchant buys your crops! Look for the NPC with a gold coin icon.",
		hint = "Walk up to the Merchant NPC and press E to interact.",
		trigger = {
			type = "step_complete",
			step = "use_portal",
		},
		objective = {
			type = "npc_interact",
			npcType = "merchant",
		},
		reward = {
			coins = 10,
			message = "You found the Merchant! Now sell your harvest.",
		},
		nextStep = "sell_crops",
		uiType = "objective",
		waypoint = "merchant",
		canSkip = true,
	},

	{
		id = "sell_crops",
		category = "economy",
		title = "Sell Your Harvest",
		description = "Sell your wheat to the Merchant for coins!",
		hint = "Click SELL on your wheat. Each wheat sells for 3 coins!",
		trigger = {
			type = "step_complete",
			step = "find_merchant",
		},
		objective = {
			type = "sell_item",
			count = 4, -- Sell at least 4 items
		},
		reward = {
			coins = 20,
			message = "Profit! Now buy more seeds to expand your farm.",
		},
		nextStep = "visit_farm_shop",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "visit_farm_shop",
		category = "economy",
		title = "Visit the Farm Shop",
		description = "The Farm Shop sells seeds and saplings. Time to invest in more crops!",
		hint = "Look for the NPC with a green plant icon.",
		trigger = {
			type = "step_complete",
			step = "sell_crops",
		},
		objective = {
			type = "npc_interact",
			npcType = "shop",
		},
		reward = {
			coins = 10,
			message = "The Farm Shop has all the seeds you need!",
		},
		nextStep = "buy_seeds",
		uiType = "objective",
		waypoint = "farm_shop",
		canSkip = true,
	},

	{
		id = "buy_seeds",
		category = "economy",
		title = "Buy More Seeds",
		description = "Spend your coins on Wheat Seeds! More seeds = bigger farm = more profit!",
		hint = "Click BUY on Wheat Seeds. They're cheap at just 2 coins per stack!",
		trigger = {
			type = "step_complete",
			step = "visit_farm_shop",
		},
		objective = {
			type = "buy_item",
			count = 1,
		},
		reward = {
			coins = 15,
			message = "Smart investment! Now return home and plant them.",
		},
		nextStep = "return_home",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 5: RETURN & EXPAND
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "return_home",
		category = "travel",
		title = "Return to Your Island",
		description = "Use the Warp Master to return to your island!",
		hint = "Talk to the Warp Master NPC and select your island.",
		trigger = {
			type = "step_complete",
			step = "buy_seeds",
		},
		objective = {
			type = "enter_world",
			worldType = "player",
		},
		reward = {
			coins = 10,
			message = "Welcome home! Time to expand your farm.",
		},
		nextStep = "expand_farm",
		uiType = "objective",
		waypoint = "warp_master",
		canSkip = true,
	},

	{
		id = "expand_farm",
		category = "farming",
		title = "Expand Your Farm",
		description = "Create more farmland with your shovel and plant your new wheat seeds!",
		hint = "Right-click dirt with your shovel to make farmland. Then plant seeds!",
		trigger = {
			type = "step_complete",
			step = "return_home",
		},
		objective = {
			type = "multi_objective",
			objectives = {
				{ type = "place_block", blockId = 69, count = 4 }, -- Place 4 farmland
				{ type = "place_block", blockId = 76, count = 4 }, -- Plant 4 wheat (WHEAT_CROP_0)
			},
		},
		reward = {
			coins = 30,
			message = "Farm expanded! You've mastered the economy loop!",
		},
		nextStep = "gather_wood",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 6: ADDITIONAL SKILLS (Optional continuation)
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "gather_wood",
		category = "gathering",
		title = "Chop Some Trees",
		description = "Use your Copper Axe to chop trees! Wood is valuable - you can sell it.",
		hint = "Select your axe (slot 2) and hold left-click on tree trunks. Axes chop faster!",
		trigger = {
			type = "step_complete",
			step = "expand_farm",
		},
		objective = {
			type = "collect_item",
			itemType = "log",
			anyOf = {5, 38, 43, 48, 53, 58}, -- All log types
			count = 8,
		},
		reward = {
			coins = 15,
			message = "Nice haul! Logs sell for 4-7 coins each at the Merchant.",
		},
		nextStep = "plant_sapling",
		uiType = "objective",
		highlightBlockTypes = {5, 38, 43, 48, 53, 58},
		canSkip = true,
	},

	{
		id = "plant_sapling",
		category = "farming",
		title = "Plant a Sapling",
		description = "Plant one of your Oak Saplings. Trees regrow - infinite wood!",
		hint = "Select a sapling from your inventory and right-click on dirt or grass to plant.",
		trigger = {
			type = "step_complete",
			step = "gather_wood",
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
		nextStep = "craft_chest",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "craft_chest",
		category = "crafting",
		title = "Craft a Chest",
		description = "Chests store your items! Open your inventory and craft one.",
		hint = "Press E → Crafting tab → Find Chest (8 planks). Use your Crafting Table for more recipes!",
		trigger = {
			type = "step_complete",
			step = "plant_sapling",
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
		nextStep = "tutorial_complete",
		uiType = "objective",
		highlightUI = "crafting_tab",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMPLETION
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "tutorial_complete",
		category = "basics",
		title = "Tutorial Complete!",
		description = "You've mastered the Skyblox economy! Farm crops, sell to the Merchant, buy upgrades from the Shop, and expand!",
		hint = [[
Next goals:
• Grow more crops for steady income
• Mine ores and smelt them for big profits
• Buy a Furnace (150 coins) from the Building Shop
• Save up for automation (Minions cost 2500+ coins!)
		]],
		trigger = {
			type = "step_complete",
			step = "craft_chest",
		},
		objective = nil,
		reward = {
			coins = 50,
			message = "Tutorial Complete! Here's a bonus to grow your island!",
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

-- Get waypoint config by name
function TutorialConfig.GetWaypoint(waypointName)
	return TutorialConfig.Waypoints[waypointName]
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

	-- Waypoint settings
	waypointBeamWidth = 0.5,
	waypointBeamColor = Color3.fromRGB(255, 215, 0),
	waypointMarkerSize = UDim2.new(0, 40, 0, 40),
	waypointUpdateInterval = 0.1,

	-- Behavior
	autoAdvance = true,
	showProgressBar = true,
	enableSkip = true,
	persistProgress = true,

	-- Tutorial special actions
	instantGrowCropsOnPlant = true, -- Instantly grow crops when plant_seeds step completes
}

return TutorialConfig
