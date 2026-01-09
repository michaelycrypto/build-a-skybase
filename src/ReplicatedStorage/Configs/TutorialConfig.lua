--[[
	TutorialConfig.lua - Tutorial/Onboarding Configuration

	Defines all tutorial steps, their triggers, objectives, and rewards.
	Follows the Skyblox progression: Punch trees → Craft workbench → Gather stone → Build furnace → Mine copper → Smelt → Craft tools

	Tutorial Philosophy:
	- Non-intrusive guidance (tooltips, not forced cutscenes)
	- Progressive revelation (only show relevant info)
	- Skippable but incentivized with small rewards
	- Contextual (appears when relevant action is possible)
]]

local TutorialConfig = {}

-- Tutorial step categories
TutorialConfig.Categories = {
	BASICS = "basics",           -- Movement, camera, UI
	GATHERING = "gathering",     -- Breaking blocks, collecting resources
	CRAFTING = "crafting",       -- Workbench, recipes
	SMELTING = "smelting",       -- Furnace, ingots
	TOOLS = "tools",             -- Using tools effectively
	BUILDING = "building",       -- Placing blocks
	AUTOMATION = "automation",   -- Golems introduction
	COMBAT = "combat",           -- Fighting mobs
}

-- Individual tutorial steps with triggers and objectives
-- Each step has: id, category, title, description, hint, trigger, objective, reward, next
TutorialConfig.Steps = {
	--[[
		=== BASICS CATEGORY ===
	]]
	{
		id = "welcome",
		category = "basics",
		title = "Welcome to Skyblox!",
		description = "Your adventure begins in your personal Realm. Let's learn the basics!",
		hint = "Use WASD to move around. Look around with your mouse.",
		trigger = {
			type = "immediate",  -- Shows immediately on first join
		},
		objective = {
			type = "move",       -- Player must move
			distance = 10,       -- Move 10 studs total
		},
		reward = nil,           -- No reward for movement
		nextStep = "look_around",
		uiType = "popup",       -- Full popup for welcome
		canSkip = false,        -- Can't skip welcome
	},

	{
		id = "look_around",
		category = "basics",
		title = "Look Around",
		description = "Cycle through each camera mode with F5. There are 3 modes to try!",
		hint = "Press F5 to cycle through camera modes. You need to visit all 3 modes: First Person, Third Person Lock, and Third Person Free.",
		trigger = {
			type = "step_complete",
			step = "welcome",
		},
		objective = {
			type = "camera_cycle",
			count = 3,           -- Must cycle through all 3 camera modes
		},
		reward = nil,
		nextStep = "open_inventory",
		uiType = "objective",   -- Show as objective tracker to display progress
		canSkip = true,
	},

	{
		id = "open_inventory",
		category = "basics",
		title = "Open Your Inventory",
		description = "Press E to open your inventory. This is where you'll manage items.",
		hint = "Press E to open inventory. Press E again or Escape to close.",
		trigger = {
			type = "step_complete",
			step = "look_around",
		},
		objective = {
			type = "ui_open",
			panel = "inventory",
		},
		reward = nil,
		nextStep = "punch_tree",
		uiType = "tooltip",
		highlightKey = "E",     -- Highlight the E key prompt
		canSkip = true,
	},

--[[
	=== GATHERING CATEGORY ===
]]
{
	id = "punch_tree",
	category = "gathering",
	title = "Gather Wood",
	description = "Trees are essential! Punch a tree to gather wood logs.",
	hint = "Hold left-click on a tree trunk to break it. Wood is your first resource!",
	trigger = {
		type = "step_complete",
		step = "open_inventory",
	},
	objective = {
		type = "collect_item",
		itemType = "log",    -- Any log type
		anyOf = {5, 38, 43, 48, 53, 58}, -- OAK_LOG, SPRUCE_LOG, JUNGLE_LOG, DARK_OAK_LOG, BIRCH_LOG, ACACIA_LOG
		count = 4,
	},
	reward = {
		coins = 5,
		message = "Good job! You got your first wood!",
	},
	nextStep = "gather_more_wood",
	uiType = "objective",   -- Shows as objective tracker
	highlightBlockTypes = {5, 38, 43, 48, 53, 58}, -- Highlight tree logs
	canSkip = true,
},

{
	id = "gather_more_wood",
	category = "gathering",
	title = "Gather More Wood",
	description = "You'll need more wood for crafting. Gather at least 16 logs total.",
	hint = "Keep punching trees! Wood is needed for planks, sticks, and tools.",
	trigger = {
		type = "step_complete",
		step = "punch_tree",
	},
	objective = {
		type = "collect_item",
		itemType = "log",
		anyOf = {5, 38, 43, 48, 53, 58}, -- OAK_LOG, SPRUCE_LOG, JUNGLE_LOG, DARK_OAK_LOG, BIRCH_LOG, ACACIA_LOG
		count = 16,
		cumulative = true,  -- Total gathered, not current inventory
	},
	reward = {
		coins = 10,
		message = "Great! You have enough wood to start crafting.",
	},
	nextStep = "craft_planks",
	uiType = "objective",
	canSkip = true,
},

--[[
	=== CRAFTING CATEGORY ===
]]
{
	id = "craft_planks",
	category = "crafting",
	title = "Craft Planks",
	description = "Open your inventory and craft planks from logs. You'll need planks for a workbench.",
	hint = "Press E to open inventory, then click the Crafting tab. Click on Planks to craft them.",
	trigger = {
		type = "step_complete",
		step = "gather_more_wood",
	},
	objective = {
		type = "craft_item",
		itemId = 12,         -- OAK_PLANKS (BlockType)
		count = 8,
	},
	reward = {
		coins = 5,
		message = "Planks crafted! Now you can make a workbench.",
	},
	nextStep = "craft_workbench",
	uiType = "objective",
	highlightUI = "crafting_tab",
	canSkip = true,
},

{
	id = "craft_workbench",
	category = "crafting",
	title = "Craft a Workbench",
	description = "Craft a Crafting Table (Workbench) using 4 planks. This unlocks advanced recipes!",
	hint = "In the Crafting tab, find and craft the Crafting Table.",
	trigger = {
		type = "step_complete",
		step = "craft_planks",
	},
	objective = {
		type = "craft_item",
		itemId = 13,         -- CRAFTING_TABLE (BlockType)
		count = 1,
	},
	reward = {
		coins = 15,
		message = "Excellent! Place your workbench to access more recipes.",
	},
	nextStep = "place_workbench",
	uiType = "objective",
	canSkip = true,
},

{
	id = "place_workbench",
	category = "crafting",
	title = "Place the Workbench",
	description = "Select the workbench from your hotbar and place it on the ground.",
	hint = "Select the workbench in your hotbar (1-9 keys), then right-click to place it.",
	trigger = {
		type = "step_complete",
		step = "craft_workbench",
	},
	objective = {
		type = "place_block",
		blockId = 13,        -- CRAFTING_TABLE block type
		count = 1,
	},
	reward = {
		coins = 5,
		message = "Perfect! Right-click the workbench to access advanced crafting.",
	},
	nextStep = "use_workbench",
	uiType = "objective",
	canSkip = true,
},

	{
		id = "use_workbench",
		category = "crafting",
		title = "Use the Workbench",
		description = "Right-click your placed workbench to open the crafting menu with more recipes.",
		hint = "Stand near your workbench and right-click it. Workbench recipes show a special icon.",
		trigger = {
			type = "step_complete",
			step = "place_workbench",
		},
		objective = {
			type = "interact_block",
			blockType = "crafting_table",
		},
		reward = nil,
		nextStep = "gather_stone",
		uiType = "tooltip",
		canSkip = true,
	},

{
	id = "gather_stone",
	category = "gathering",
	title = "Gather Stone",
	description = "Mine stone blocks to gather cobblestone. You'll need it for a furnace!",
	hint = "Find gray stone blocks and hold left-click to mine them. You need 8 for a furnace.",
	trigger = {
		type = "step_complete",
		step = "use_workbench",
	},
	objective = {
		type = "collect_item",
		itemId = 14,         -- COBBLESTONE (BlockType)
		count = 8,
	},
	reward = {
		coins = 10,
		message = "Nice! You have enough cobblestone for a furnace.",
	},
	nextStep = "craft_furnace",
	uiType = "objective",
	highlightBlockTypes = {3}, -- STONE block type
	canSkip = true,
},

--[[
	=== SMELTING CATEGORY ===
]]
{
	id = "craft_furnace",
	category = "smelting",
	title = "Craft a Furnace",
	description = "Use your workbench to craft a furnace. You'll need it to smelt ores into ingots!",
	hint = "Right-click workbench, find Furnace in recipes (8 cobblestone).",
	trigger = {
		type = "step_complete",
		step = "gather_stone",
	},
	objective = {
		type = "craft_item",
		itemId = 35,         -- FURNACE (BlockType)
		count = 1,
	},
	reward = {
		coins = 15,
		message = "Furnace crafted! Place it to start smelting.",
	},
	nextStep = "place_furnace",
	uiType = "objective",
	canSkip = true,
},

{
	id = "place_furnace",
	category = "smelting",
	title = "Place the Furnace",
	description = "Select and place your furnace on the ground.",
	hint = "Select furnace from hotbar and right-click to place.",
	trigger = {
		type = "step_complete",
		step = "craft_furnace",
	},
	objective = {
		type = "place_block",
		blockId = 35,        -- FURNACE block type
		count = 1,
	},
	reward = {
		coins = 5,
		message = "Furnace placed! Now find some ore and coal.",
	},
	nextStep = "find_coal",
	uiType = "objective",
	canSkip = true,
},

{
	id = "find_coal",
	category = "gathering",
	title = "Find Coal",
	description = "Mine coal ore (black specks in stone). Coal is fuel for your furnace!",
	hint = "Look for stone with black specks - that's coal ore! Mine it to get coal.",
	trigger = {
		type = "step_complete",
		step = "place_furnace",
	},
	objective = {
		type = "collect_item",
		itemId = 32,         -- COAL (BlockType/ItemID)
		count = 5,
	},
	reward = {
		coins = 10,
		message = "Coal found! Now let's find copper ore.",
	},
	nextStep = "find_copper",
	uiType = "objective",
	highlightBlockTypes = {29}, -- COAL_ORE
	canSkip = true,
},

{
	id = "find_copper",
	category = "gathering",
	title = "Find Copper Ore",
	description = "Mine copper ore (orange specks in stone). This is your first metal!",
	hint = "Look for stone with orange/brown specks. Copper ore is common near the surface.",
	trigger = {
		type = "step_complete",
		step = "find_coal",
	},
	objective = {
		type = "collect_item",
		itemId = 98,         -- COPPER_ORE (BlockType/ItemID)
		count = 3,
	},
	reward = {
		coins = 15,
		message = "Copper ore collected! Time to smelt it into ingots.",
	},
	nextStep = "smelt_copper",
	uiType = "objective",
	highlightBlockTypes = {98}, -- COPPER_ORE block type
	canSkip = true,
},

{
	id = "smelt_copper",
	category = "smelting",
	title = "Smelt Copper Ingots",
	description = "Use your furnace to smelt copper ore + coal into copper ingots.",
	hint = "Right-click furnace. Place copper ore and coal to get copper ingots.",
	trigger = {
		type = "step_complete",
		step = "find_copper",
	},
	objective = {
		type = "collect_item",
		itemId = 105,        -- COPPER_INGOT (ItemID)
		count = 3,
	},
	reward = {
		coins = 20,
		message = "Copper ingots! Now you can craft real tools.",
	},
	nextStep = "craft_copper_pickaxe",
	uiType = "objective",
	canSkip = true,
},

	--[[
		=== TOOLS CATEGORY ===
	]]
	{
		id = "craft_copper_pickaxe",
		category = "tools",
		title = "Craft a Copper Pickaxe",
		description = "Craft a copper pickaxe using copper ingots and sticks. Better tools = faster mining!",
		hint = "Use workbench: 3 copper ingots + 2 sticks = copper pickaxe.",
		trigger = {
			type = "step_complete",
			step = "smelt_copper",
		},
		objective = {
			type = "craft_item",
			itemId = 1001,       -- COPPER_PICKAXE
			count = 1,
		},
		reward = {
			coins = 25,
			gems = 1,
			message = "Your first metal tool! Mining is now much faster.",
		},
		nextStep = "equip_pickaxe",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "equip_pickaxe",
		category = "tools",
		title = "Equip Your Pickaxe",
		description = "Select your copper pickaxe from the hotbar to equip it.",
		hint = "Press 1-9 to select items in your hotbar. Mining with tools is faster!",
		trigger = {
			type = "step_complete",
			step = "craft_copper_pickaxe",
		},
		objective = {
			type = "equip_item",
			itemId = 1001,       -- COPPER_PICKAXE
		},
		reward = nil,
		nextStep = "mine_with_pickaxe",
		uiType = "tooltip",
		canSkip = true,
	},

{
	id = "mine_with_pickaxe",
	category = "tools",
	title = "Mine with Your Pickaxe",
	description = "Use your copper pickaxe to mine stone. Notice how much faster it is!",
	hint = "Hold left-click with pickaxe equipped to mine. Metal tools are essential!",
	trigger = {
		type = "step_complete",
		step = "equip_pickaxe",
	},
	objective = {
		type = "break_block",
		blockTypes = {3, 29, 98, 30}, -- STONE, COAL_ORE, COPPER_ORE, IRON_ORE
		count = 5,
		withTool = true,     -- Must use a tool
	},
	reward = {
		coins = 10,
		message = "Great mining! You've completed the basics.",
	},
	nextStep = "tutorial_complete",
	uiType = "objective",
	canSkip = true,
},

	--[[
		=== TUTORIAL COMPLETE ===
	]]
	{
		id = "tutorial_complete",
		category = "basics",
		title = "Tutorial Complete!",
		description = "You've learned the basics of Skyblox! Keep exploring and building your Realm.",
		hint = "Next goals: Craft iron tools, build armor, explore deeper for rare ores, and automate with Golems!",
		trigger = {
			type = "step_complete",
			step = "mine_with_pickaxe",
		},
		objective = nil,        -- No objective, just celebration
		reward = {
			coins = 50,
			gems = 5,
			message = "🎉 Tutorial Complete! Here's a bonus to get you started!",
		},
		nextStep = nil,         -- End of tutorial
		uiType = "popup",       -- Celebration popup
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

-- Settings for tutorial behavior
TutorialConfig.Settings = {
	-- Timing
	tooltipDelay = 0.5,           -- Seconds before tooltip appears
	tooltipDuration = 10,         -- Seconds tooltip stays visible
	popupDuration = 0,            -- 0 = manual dismiss required
	highlightPulseSpeed = 2,      -- Pulses per second for highlights

	-- Appearance
	tooltipMaxWidth = 300,        -- Max width in pixels
	highlightColor = Color3.fromRGB(255, 215, 0), -- Gold highlight
	highlightTransparency = 0.3,

	-- Behavior
	autoAdvance = true,           -- Auto-advance when objective complete
	showProgressBar = true,       -- Show progress for multi-count objectives
	enableSkip = true,            -- Allow skipping skippable steps
	persistProgress = true,       -- Save progress to DataStore
}

return TutorialConfig

