--[[
	TutorialConfig.lua - Tutorial/Onboarding Configuration

	Craft-First Tutorial:
	Players learn core Minecraft mechanics: gather → craft → build → mine → farm → automate

	Progression Loop (15 steps):
	Open Chest → Chop Tree → Craft Planks → Craft Workbench → Craft Pickaxe →
	Build Bridge → Open Stone Chest → Mine Cobblestone → Setup Furnace →
	Smelt Copper → Craft Shovel → Till Soil → Irrigate → Plant Seeds →
	Harvest Wheat → Complete!

	Tutorial Philosophy:
	- Non-intrusive guidance (tooltips, not forced cutscenes)
	- Progressive revelation (only show relevant info)
	- Earn everything through gameplay (no pre-provided tools)
	- Focus on the CRAFT → BUILD → AUTOMATE loop
]]

local TutorialConfig = {}

-- Tutorial step categories
TutorialConfig.Categories = {
	BASICS = "basics",           -- Movement, camera, UI
	GATHERING = "gathering",     -- Breaking blocks, collecting resources
	CRAFTING = "crafting",       -- Workbench, recipes
	BUILDING = "building",       -- Placing blocks, bridging
	MINING = "mining",           -- Mining ores, cobblestone
	FARMING = "farming",         -- Planting, harvesting
	ECONOMY = "economy",         -- Shop, merchant, trading
	AUTOMATION = "automation",   -- Golems, passive income
}

-- Waypoint configuration for guiding players
-- NOTE: offsetFromSpawn is in BLOCK coordinates matching SkyblockGenerator
-- X and Z are block offsets from island center (originX=48, originZ=48)
-- Y is offset from island surface (topY=65), e.g., Y=1 means surface+1
TutorialConfig.Waypoints = {
	-- Island waypoints (player world)
	starter_tree = {
		type = "block_area",
		-- Tree: offsetX=1, offsetZ=-1, baseOffset=1 (trunk base at surface+1)
		offsetFromSpawn = Vector3.new(1, 1, -1),
		radius = 3,
		color = Color3.fromRGB(139, 90, 43), -- Brown for tree
		label = "Starter Tree",
	},
	stone_island = {
		type = "block_area",
		-- Stone island: offsetZ=16, topY=65 (same height as starter)
		-- Point to near edge for bridge building
		offsetFromSpawn = Vector3.new(0, 0, 14),
		radius = 3,
		color = Color3.fromRGB(128, 128, 128), -- Gray for stone
		label = "Stone Island",
	},
	stone_chest = {
		type = "block_area",
		-- Chest on stone island: island offsetZ=16, chest at center (0,0), raise=1
		offsetFromSpawn = Vector3.new(0, 1, 16),
		radius = 2,
		color = Color3.fromRGB(139, 90, 43), -- Brown for chest
		label = "Stone Chest",
		blockId = 9, -- CHEST block ID for waypoint icon (shows chest_front texture)
	},
	starter_chest = {
		type = "block_area",
		-- Chest: offsetX=1, offsetZ=2, raise=1 (placed at surface+1)
		offsetFromSpawn = Vector3.new(1, 1, 2),
		radius = 2,
		color = Color3.fromRGB(139, 90, 43), -- Brown for chest
		label = "Starter Chest",
		blockId = 9, -- CHEST block ID for waypoint icon (shows chest_front texture)
	},
	portal = {
		type = "block_area",
		-- Portal base at surface+1
		offsetFromSpawn = Vector3.new(-3, 1, 0),
		radius = 2,
		color = Color3.fromRGB(128, 0, 128), -- Purple for portal
		label = "Hub Portal",
	},
	-- Hub waypoints (use NPC positions from NPCSpawnConfig)
	farm_shop = {
		type = "npc",
		npcId = "hub_farm_shop_1",
		color = Color3.fromRGB(34, 197, 94), -- Green
		label = "Farm Shop",
	},
}

-- Individual tutorial steps with triggers and objectives
TutorialConfig.Steps = {
	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 1: DISCOVERY - Open the nearby chest first (natural curiosity!)
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "welcome",
		category = "basics",
		title = "Welcome to Skyblox!",
		description = "Your island adventure begins! Check out the chest nearby for supplies.",
		hint = "Use WASD to move. Right-click the chest to open it!",
		trigger = {
			type = "immediate",
		},
		objective = {
			type = "move",
			distance = 5,
		},
		reward = nil,
		nextStep = "open_chest",
		uiType = "popup",
		canSkip = false,
	},

	{
		id = "open_chest",
		category = "gathering",
		title = "Open the Chest",
		description = "Open the chest to find supplies: copper ingots, sticks, seeds, and dirt!",
		hint = "Right-click the chest near the tree to open it.",
		trigger = {
			type = "step_complete",
			step = "welcome",
		},
		objective = {
			type = "collect_item",
			itemId = 105, -- COPPER_INGOT
			count = 3,
		},
		reward = {
			coins = 15,
			message = "Supplies acquired! Now chop the tree for wood.",
		},
		nextStep = "chop_tree",
		uiType = "objective",
		waypoint = "starter_chest",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 2: GATHERING - Chop the starter tree
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "chop_tree",
		category = "gathering",
		title = "Chop the Tree",
		description = "Break the tree trunk to collect Oak Logs!",
		hint = "Hold left-click on the tree trunk (brown wood) to break it.",
		trigger = {
			type = "step_complete",
			step = "open_chest",
		},
		objective = {
			type = "collect_item",
			itemId = 5, -- WOOD (Oak Log)
			count = 4,
		},
		reward = {
			coins = 10,
			message = "Great! Now craft those logs into planks.",
		},
		nextStep = "craft_planks",
		uiType = "objective",
		waypoint = "starter_tree",
		highlightBlockTypes = {5}, -- WOOD
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 3: CRAFTING - Make planks, workbench, and pickaxe
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "craft_planks",
		category = "crafting",
		title = "Craft Planks",
		description = "Open your inventory and craft Oak Logs into Planks!",
		hint = "Press E → Click on Oak Logs in the crafting grid → Take the planks.",
		trigger = {
			type = "step_complete",
			step = "chop_tree",
		},
		objective = {
			type = "craft_item",
			itemId = 12, -- OAK_PLANKS
			count = 8,
		},
		reward = {
			coins = 10,
			message = "Now craft a Workbench for advanced recipes!",
		},
		nextStep = "craft_workbench",
		uiType = "objective",
		highlightKey = "E",
		canSkip = true,
	},

	{
		id = "craft_workbench",
		category = "crafting",
		title = "Craft a Workbench",
		description = "Craft a Crafting Table using 4 planks in a 2x2 pattern.",
		hint = "Press E → Fill 2x2 grid with planks → Take the Crafting Table.",
		trigger = {
			type = "step_complete",
			step = "craft_planks",
		},
		objective = {
			type = "craft_item",
			itemId = 13, -- CRAFTING_TABLE
			count = 1,
		},
		reward = {
			coins = 15,
			message = "Workbench crafted! Now craft a Copper Pickaxe with your supplies.",
		},
		nextStep = "craft_pickaxe",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "craft_pickaxe",
		category = "crafting",
		title = "Craft a Copper Pickaxe",
		description = "Use your Copper Ingots and Sticks from the chest to craft a pickaxe!",
		hint = "Place the Crafting Table → Right-click it → 3 Copper Ingots on top + 2 Sticks below.",
		trigger = {
			type = "step_complete",
			step = "craft_workbench",
		},
		objective = {
			type = "craft_item",
			itemId = 1001, -- COPPER_PICKAXE
			count = 1,
		},
		reward = {
			coins = 25,
			message = "Pickaxe crafted! Now build a bridge to the Stone Island.",
		},
		nextStep = "build_bridge",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 4: EXPLORE STONE ISLAND - Bridge, loot chest, mine, smelt, craft tools
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "build_bridge",
		category = "building",
		title = "Build a Bridge",
		description = "Place planks to build a bridge to the Stone Island to the south!",
		hint = "Select planks in your hotbar → Right-click to place blocks → Bridge the gap.",
		trigger = {
			type = "step_complete",
			step = "craft_pickaxe",
		},
		objective = {
			type = "place_block",
			blockId = 12, -- OAK_PLANKS
			count = 10,
		},
		reward = {
			coins = 20,
			message = "Bridge built! Cross over and check out the chest.",
		},
		nextStep = "open_stone_chest",
		uiType = "objective",
		waypoint = "stone_island",
		canSkip = true,
	},

	{
		id = "open_stone_chest",
		category = "gathering",
		title = "Open the Stone Chest",
		description = "Open the chest on the Stone Island to find copper ore and coal!",
		hint = "Right-click the chest to open it. Take everything inside!",
		trigger = {
			type = "step_complete",
			step = "build_bridge",
		},
		objective = {
			type = "collect_item",
			itemId = 98, -- COPPER_ORE
			count = 3,
		},
		reward = {
			coins = 15,
			message = "Copper ore acquired! Now mine some cobblestone.",
		},
		nextStep = "mine_cobblestone",
		uiType = "objective",
		waypoint = "stone_chest",
		canSkip = true,
	},

	{
		id = "mine_cobblestone",
		category = "mining",
		title = "Mine Cobblestone",
		description = "Use your Copper Pickaxe to mine the stone blocks!",
		hint = "Equip your pickaxe and hold left-click on stone blocks.",
		trigger = {
			type = "step_complete",
			step = "open_stone_chest",
		},
		objective = {
			type = "collect_item",
			itemId = 14, -- COBBLESTONE
			count = 8,
		},
		reward = {
			coins = 20,
			message = "Cobblestone collected! Now craft a furnace to smelt your copper.",
		},
		nextStep = "setup_furnace",
		uiType = "objective",
		waypoint = "stone_island",
		highlightBlockTypes = {14, 3}, -- COBBLESTONE, STONE
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 5: SMELTING - Set up furnace and smelt copper
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "setup_furnace",
		category = "crafting",
		title = "Set Up Your Furnace",
		description = "Craft a Furnace and place it to start smelting!",
		hint = [[
Requirements:
• Craft a Furnace: 8 Cobblestone in a ring pattern at the Crafting Table
• Place the Furnace: Select it and right-click on a flat surface

Complete in any order!
		]],
		trigger = {
			type = "step_complete",
			step = "mine_cobblestone",
		},
		objective = {
			type = "multi_objective",
			objectives = {
				{ type = "craft_item", itemId = 35, count = 1, name = "Craft Furnace" },
				{ type = "place_block", blockId = 35, count = 1, name = "Place Furnace" },
			},
		},
		reward = {
			coins = 25,
			message = "Furnace ready! Now smelt your copper ore.",
		},
		nextStep = "smelt_copper",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "smelt_copper",
		category = "crafting",
		title = "Smelt Copper Ore",
		description = "Use your Furnace to smelt Copper Ore into Copper Ingots!",
		hint = "Right-click Furnace → Copper Ore in top → Coal in bottom → Wait.",
		trigger = {
			type = "step_complete",
			step = "setup_furnace",
		},
		objective = {
			type = "collect_item",
			itemId = 105, -- COPPER_INGOT
			count = 2,
		},
		reward = {
			coins = 25,
			message = "Copper smelted! Now craft a Copper Shovel.",
		},
		nextStep = "craft_copper_shovel",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 6: TOOLS - Craft copper shovel for farming
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "craft_copper_shovel",
		category = "crafting",
		title = "Craft a Copper Shovel",
		description = "Craft a Copper Shovel to till soil for farming!",
		hint = "Right-click Crafting Table → 1 Copper Ingot on top + 2 Sticks below.",
		trigger = {
			type = "step_complete",
			step = "smelt_copper",
		},
		objective = {
			type = "craft_item",
			itemId = 1021, -- COPPER_SHOVEL
			count = 1,
		},
		reward = {
			coins = 30,
			message = "Shovel crafted! Now let's set up a farm.",
		},
		nextStep = "till_soil",
		uiType = "objective",
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- PHASE 7: FARMING - Step by step farm setup
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "till_soil",
		category = "farming",
		title = "Till the Soil",
		description = "Use your Copper Shovel to turn dirt into farmland!",
		hint = [[
How to till:
1. Place Dirt blocks from your starter chest
2. Equip your Copper Shovel
3. Right-click on dirt to turn it into farmland

Farmland is required for planting crops!
		]],
		trigger = {
			type = "step_complete",
			step = "craft_copper_shovel",
		},
		objective = {
			type = "place_block",
			anyOf = {69, 385}, -- FARMLAND or FARMLAND_WET
			count = 4,
		},
		reward = {
			coins = 10,
			message = "Farmland ready! Now irrigate it for faster crop growth.",
		},
		nextStep = "irrigate_farm",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "irrigate_farm",
		category = "farming",
		title = "Irrigate Your Farm",
		description = "Place water near your farmland to make crops grow faster!",
		hint = [[
The Stone Island chest contains a Water Bucket!

How to irrigate:
1. Get the Water Bucket from the stone island chest
2. Place water next to your farmland (right-click)
3. Farmland within 4 blocks of water turns darker (wet)

Wet farmland = 2x faster crop growth!
		]],
		trigger = {
			type = "step_complete",
			step = "till_soil",
		},
		objective = {
			type = "place_block",
			blockId = 380, -- WATER_SOURCE - track placing water, not the resulting wet farmland
			count = 1,
		},
		reward = {
			coins = 10,
			message = "Farm irrigated! Wet farmland grows crops twice as fast.",
		},
		nextStep = "plant_seeds",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "plant_seeds",
		category = "farming",
		title = "Plant Seeds",
		description = "Plant Wheat Seeds on your farmland!",
		hint = [[
How to plant:
1. Select Wheat Seeds from your hotbar
2. Right-click on farmland to plant

Seeds are in your starter chest. Plant on wet farmland for faster growth!
		]],
		trigger = {
			type = "step_complete",
			step = "irrigate_farm",
		},
		objective = {
			type = "place_block",
			blockId = 76, -- WHEAT_CROP_0
			count = 4,
		},
		reward = {
			coins = 10,
			message = "Seeds planted! Wait for them to grow tall and golden.",
		},
		nextStep = "harvest_wheat",
		uiType = "objective",
		canSkip = true,
	},

	{
		id = "harvest_wheat",
		category = "farming",
		title = "Harvest Wheat",
		description = "Break fully grown wheat to harvest!",
		hint = [[
Fully grown wheat is tall and golden.

Break it to get:
• Wheat (for crafting bread or trading)
• Wheat Seeds (to replant)
		]],
		trigger = {
			type = "step_complete",
			step = "plant_seeds",
		},
		objective = {
			type = "collect_item",
			itemId = 71, -- WHEAT
			count = 4,
		},
		reward = {
			coins = 50,
			items = {{itemId = 384, count = 1, metadata = {level = 1, minionType = "COPPER"}}}, -- Copper Golem!
			message = "First harvest complete! You've earned a Copper Golem for your hard work!",
		},
		nextStep = "tutorial_complete",
		uiType = "objective",
		-- Tutorial accelerated growth
		tutorialBoost = {
			cropGrowthMultiplier = 10, -- Crops grow 10x faster during this step
		},
		canSkip = true,
	},

	-- ═══════════════════════════════════════════════════════════════════════════
	-- COMPLETION
	-- ═══════════════════════════════════════════════════════════════════════════
	{
		id = "tutorial_complete",
		category = "basics",
		title = "Tutorial Complete!",
		description = "You've mastered the basics of Skyblox! Gather, craft, build, mine, farm, trade, and automate!",
		hint = [[
Next goals:
• Expand your farm for steady crop income
• Mine deeper for better ores (Iron, Steel, Bluesteel)
• Craft better tools and armor
• Get more Golems to automate everything!
		]],
		trigger = {
			type = "step_complete",
			step = "harvest_wheat",
		},
		objective = nil,
		reward = {
			coins = 100,
			message = "Tutorial Complete! Here's a bonus to grow your island empire!",
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
	waypointMarkerSize = UDim2.fromOffset(40, 40),
	waypointUpdateInterval = 0.1,

	-- Behavior
	autoAdvance = true,
	showProgressBar = true,
	enableSkip = true,
	persistProgress = true,

	-- Tutorial special actions
	instantGrowCropsOnPlant = false, -- Disabled; using tutorialBoost multiplier instead
}

return TutorialConfig
