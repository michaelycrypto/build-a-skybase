--[[
	ItemConfig

	Dungeon-focused item system configuration.
	Players manage dungeons with Mob Spawners deployed in 8 slots.
--]]

local ItemConfig = {
	-- Item type definitions for dungeon management
	ItemTypes = {
		MOB_SPAWNER = {
			category = "Spawner",
			stackable = false,
			maxStack = 1,
			canDeploy = true,
			durabilityEnabled = true,
			deploySlotType = "dungeon"
		},
		DUNGEON_UPGRADE = {
			category = "Upgrade",
			stackable = true,
			maxStack = 10,
			canDeploy = false,
			durabilityEnabled = false,
			consumable = true
		},
		SPAWNER_ENHANCEMENT = {
			category = "Enhancement",
			stackable = true,
			maxStack = 50,
			canDeploy = false,
			durabilityEnabled = false,
			consumable = true
		},
		RESOURCE = {
			category = "Resource",
			stackable = true,
			maxStack = 1000,
			canDeploy = false,
			durabilityEnabled = false,
			sellable = true
		},
		CRYSTAL = {
			category = "Crystal",
			stackable = true,
			maxStack = 100,
			canDeploy = false,
			durabilityEnabled = false,
			premium = true
		},
		BLUEPRINT = {
			category = "Blueprint",
			stackable = false,
			maxStack = 1,
			canDeploy = false,
			durabilityEnabled = false,
			unlocks = true
		},
		CRATE = {
			category = "Crate",
			stackable = true,
			maxStack = 10,
			canDeploy = false,
			durabilityEnabled = false,
			openable = true
		},
		MOB_HEAD = {
			category = "MobHead",
			stackable = true,
			maxStack = 10,
			canDeploy = true,
			durabilityEnabled = false,
			deploySlotType = "spawner",
			consumable = false
		},
	},

		-- Spawner and dungeon item rarity definitions
	ItemRarities = {
		BASIC = {
			name = "Basic",
			color = Color3.fromRGB(150, 150, 150),
			dropChance = 0.6,
			glowEffect = false,
			sortOrder = 1,
			powerMultiplier = 1.0
		},
		ENHANCED = {
			name = "Enhanced",
			color = Color3.fromRGB(0, 255, 100),
			dropChance = 0.25,
			glowEffect = false,
			sortOrder = 2,
			powerMultiplier = 1.5
		},
		SUPERIOR = {
			name = "Superior",
			color = Color3.fromRGB(0, 150, 255),
			dropChance = 0.1,
			glowEffect = true,
			sortOrder = 3,
			powerMultiplier = 2.0
		},
		ELITE = {
			name = "Elite",
			color = Color3.fromRGB(150, 0, 255),
			dropChance = 0.04,
			glowEffect = true,
			sortOrder = 4,
			powerMultiplier = 3.0
		},
		LEGENDARY = {
			name = "Legendary",
			color = Color3.fromRGB(255, 150, 0),
			dropChance = 0.008,
			glowEffect = true,
			sortOrder = 5,
			powerMultiplier = 5.0
		},
		MYTHICAL = {
			name = "Mythical",
			color = Color3.fromRGB(255, 50, 150),
			dropChance = 0.002,
			glowEffect = true,
			sortOrder = 6,
			powerMultiplier = 8.0
		}
	},

		-- Item definitions - All dungeon items are defined here
	Items = {
		-- MOB HEADS - Define mob types and their properties
		goblin_head = {
			name = "Goblin Head",
			type = "MOB_HEAD",
			rarity = "BASIC",
			description = "Equip to a spawner to spawn goblins",
			stats = {
				mobType = "Goblin",
				mobHealth = 50,
				mobDamage = 8,
				mobSpeed = 16,
				mobValue = 10 -- coins/XP value when defeated
			},
			price = 25,
			sellPrice = 10,
			tradeable = true,
			droppable = true
		},

		orc_head = {
			name = "Orc Head",
			type = "MOB_HEAD",
			rarity = "ENHANCED",
			description = "Equip to a spawner to spawn orcs - stronger than goblins",
			stats = {
				mobType = "Orc",
				mobHealth = 100,
				mobDamage = 15,
				mobSpeed = 14,
				mobValue = 25
			},
			price = 75,
			sellPrice = 30,
			tradeable = true,
			droppable = true
		},

		troll_head = {
			name = "Troll Head",
			type = "MOB_HEAD",
			rarity = "SUPERIOR",
			description = "Equip to a spawner to spawn trolls - slow but powerful",
			stats = {
				mobType = "Troll",
				mobHealth = 250,
				mobDamage = 30,
				mobSpeed = 10,
				mobValue = 75
			},
			price = 200,
			sellPrice = 80,
			tradeable = true,
			droppable = true
		},

		dragon_head = {
			name = "Dragon Head",
			type = "MOB_HEAD",
			rarity = "LEGENDARY",
			description = "Equip to a spawner to spawn dragons - the ultimate mob",
			stats = {
				mobType = "Dragon",
				mobHealth = 500,
				mobDamage = 50,
				mobSpeed = 20,
				mobValue = 200
			},
			price = 1000,
			sellPrice = 400,
			tradeable = true,
			droppable = true
		},

		skeleton_head = {
			name = "Skeleton Head",
			type = "MOB_HEAD",
			rarity = "ENHANCED",
			description = "Equip to a spawner to spawn undead skeletons",
			stats = {
				mobType = "Skeleton",
				mobHealth = 80,
				mobDamage = 12,
				mobSpeed = 15,
				mobValue = 20
			},
			price = 50,
			sellPrice = 20,
			tradeable = true,
			droppable = true
		},

		zombie_head = {
			name = "Zombie Head",
			type = "MOB_HEAD",
			rarity = "BASIC",
			description = "Equip to a spawner to spawn slow but durable zombies",
			stats = {
				mobType = "Zombie",
				mobHealth = 120,
				mobDamage = 6,
				mobSpeed = 8,
				mobValue = 15
			},
			price = 15,
			sellPrice = 6,
			tradeable = true,
			droppable = true
		},

		imp_head = {
			name = "Imp Head",
			type = "MOB_HEAD",
			rarity = "ENHANCED",
			description = "Equip to a spawner to spawn fast demonic imps",
			stats = {
				mobType = "Imp",
				mobHealth = 60,
				mobDamage = 18,
				mobSpeed = 25,
				mobValue = 30
			},
			price = 60,
			sellPrice = 24,
			tradeable = true,
			droppable = true
		},

		rat_head = {
			name = "Rat Head",
			type = "MOB_HEAD",
			rarity = "BASIC",
			description = "Equip to a spawner to spawn small but quick rats",
			stats = {
				mobType = "Rat",
				mobHealth = 30,
				mobDamage = 4,
				mobSpeed = 20,
				mobValue = 5
			},
			price = 10,
			sellPrice = 4,
			tradeable = true,
			droppable = true
		},

		chicken_head = {
			name = "Chicken Head",
			type = "MOB_HEAD",
			rarity = "BASIC",
			description = "Equip to a spawner to spawn farm chickens",
			stats = {
				mobType = "Chicken",
				mobHealth = 25,
				mobDamage = 2,
				mobSpeed = 12,
				mobValue = 3
			},
			price = 8,
			sellPrice = 3,
			tradeable = true,
			droppable = true
		},

		cow_head = {
			name = "Cow Head",
			type = "MOB_HEAD",
			rarity = "BASIC",
			description = "Equip to a spawner to spawn farm cows",
			stats = {
				mobType = "Cow",
				mobHealth = 150,
				mobDamage = 8,
				mobSpeed = 10,
				mobValue = 12
			},
			price = 20,
			sellPrice = 8,
			tradeable = true,
			droppable = true
		},

		fire_elemental_head = {
			name = "Fire Elemental Head",
			type = "MOB_HEAD",
			rarity = "SUPERIOR",
			description = "Equip to a spawner to spawn powerful fire elementals",
			stats = {
				mobType = "FireElemental",
				mobHealth = 200,
				mobDamage = 25,
				mobSpeed = 18,
				mobValue = 50
			},
			price = 300,
			sellPrice = 120,
			tradeable = true,
			droppable = true
		},

		ice_golem_head = {
			name = "Ice Golem Head",
			type = "MOB_HEAD",
			rarity = "ELITE",
			description = "Equip to a spawner to spawn massive ice golems",
			stats = {
				mobType = "IceGolem",
				mobHealth = 400,
				mobDamage = 35,
				mobSpeed = 12,
				mobValue = 100
			},
			price = 800,
			sellPrice = 320,
			tradeable = true,
			droppable = true
		},



		-- DUNGEON UPGRADES
		reinforced_walls = {
			name = "Reinforced Walls",
			type = "DUNGEON_UPGRADE",
			rarity = "ENHANCED",
			description = "Increases dungeon durability by 25%",
			effects = {
				dungeonDurability = 1.25
			},
			price = 500,
			sellPrice = 250,
			tradeable = true,
			droppable = true
		},

		mana_generator = {
			name = "Mana Generator",
			type = "DUNGEON_UPGRADE",
			rarity = "SUPERIOR",
			description = "Generates 1 mana crystal per minute",
			effects = {
				manaGeneration = 1, -- per minute
				energyCost = -10
			},
			price = 1500,
			sellPrice = 750,
			tradeable = true,
			droppable = true
		},

		treasure_vault = {
			name = "Treasure Vault",
			type = "DUNGEON_UPGRADE",
			rarity = "ELITE",
			description = "Increases coin generation from defeated heroes by 50%",
			effects = {
				coinMultiplier = 1.5,
				storageBonus = 1000
			},
			price = 3000,
			sellPrice = 1500,
			tradeable = true,
			droppable = false
		},

		-- SPAWNER ENHANCEMENTS
		speed_rune = {
			name = "Speed Rune",
			type = "SPAWNER_ENHANCEMENT",
			rarity = "ENHANCED",
			description = "Reduces spawner cooldown by 20%",
			effects = {
				spawnRateMultiplier = 0.8
			},
			price = 200,
			sellPrice = 100,
			tradeable = true,
			droppable = true
		},

		power_crystal = {
			name = "Power Crystal",
			type = "SPAWNER_ENHANCEMENT",
			rarity = "SUPERIOR",
			description = "Increases mob damage by 30%",
			effects = {
				mobDamageMultiplier = 1.3
			},
			price = 600,
			sellPrice = 300,
			tradeable = true,
			droppable = true
		},

		vitality_essence = {
			name = "Vitality Essence",
			type = "SPAWNER_ENHANCEMENT",
			rarity = "ELITE",
			description = "Increases mob health by 50%",
			effects = {
				mobHealthMultiplier = 1.5
			},
			price = 1200,
			sellPrice = 600,
			tradeable = true,
			droppable = true
		},

		-- MOB DROPS (Generated by spawners)
		zombie_flesh = {
			name = "Zombie Flesh",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Rotting flesh from defeated zombies",
			price = 0, -- Not purchasable
			sellPrice = 3,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		rotten_bone = {
			name = "Rotten Bone",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Decaying bone from zombie remains",
			price = 0,
			sellPrice = 2,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		dark_essence = {
			name = "Dark Essence",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Dark energy from undead creatures",
			price = 0,
			sellPrice = 15,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		chicken_feather = {
			name = "Chicken Feather",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Soft feather from farm chickens",
			price = 0,
			sellPrice = 1,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		chicken_egg = {
			name = "Chicken Egg",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Fresh egg from chickens",
			price = 0,
			sellPrice = 2,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		raw_chicken = {
			name = "Raw Chicken",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Raw chicken meat for cooking",
			price = 0,
			sellPrice = 4,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		goblin_tooth = {
			name = "Goblin Tooth",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "A sharp tooth dropped by goblins",
			price = 0,
			sellPrice = 2,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		dark_iron = {
			name = "Dark Iron",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Basic crafting material for spawner upgrades",
			price = 0,
			sellPrice = 8,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		imp_horn = {
			name = "Imp Horn",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Sharp horn from demonic imps",
			price = 0,
			sellPrice = 12,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		fire_essence = {
			name = "Fire Essence",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Burning essence from fire creatures",
			price = 0,
			sellPrice = 18,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		rat_tail = {
			name = "Rat Tail",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Long tail from defeated rats",
			price = 0,
			sellPrice = 1,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		small_fang = {
			name = "Small Fang",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Tiny fang from small creatures",
			price = 0,
			sellPrice = 1,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		cow_hide = {
			name = "Cow Hide",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Thick hide from farm cows",
			price = 0,
			sellPrice = 5,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		beef = {
			name = "Beef",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Fresh beef from cows",
			price = 0,
			sellPrice = 6,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		milk = {
			name = "Milk",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Fresh milk from cows",
			price = 0,
			sellPrice = 3,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		skeleton_bone = {
			name = "Skeleton Bone",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Cursed bone from undead skeletons",
			price = 0,
			sellPrice = 6,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		soul_crystal = {
			name = "Soul Crystal",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Mystical crystal containing trapped souls",
			price = 0,
			sellPrice = 30,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		void_essence = {
			name = "Void Essence",
			type = "RESOURCE",
			rarity = "SUPERIOR",
			description = "Rare essence from the void realm",
			price = 0,
			sellPrice = 125,
			tradeable = true,
			droppable = true,
			mobDrop = true
		},

		-- CRAFTING RESOURCES (Purchasable materials)
		wood = {
			name = "Wood",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Basic wood for crafting",
			price = 5,
			sellPrice = 2,
			tradeable = true,
			droppable = true
		},

		stone = {
			name = "Stone",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Basic stone for crafting",
			price = 8,
			sellPrice = 4,
			tradeable = true,
			droppable = true
		},

		iron_ore = {
			name = "Iron Ore",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Raw iron for smelting",
			price = 12,
			sellPrice = 6,
			tradeable = true,
			droppable = true
		},

		leather = {
			name = "Leather",
			type = "RESOURCE",
			rarity = "BASIC",
			description = "Tanned leather for crafting",
			price = 10,
			sellPrice = 5,
			tradeable = true,
			droppable = true
		},

		magic_dust = {
			name = "Magic Dust",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Mystical dust for enchantments",
			price = 50,
			sellPrice = 25,
			tradeable = true,
			droppable = true
		},

		essence_crystal = {
			name = "Essence Crystal",
			type = "RESOURCE",
			rarity = "ENHANCED",
			description = "Crystal infused with magical essence",
			price = 80,
			sellPrice = 40,
			tradeable = true,
			droppable = true
		},

		ancient_rune = {
			name = "Ancient Rune",
			type = "RESOURCE",
			rarity = "SUPERIOR",
			description = "Ancient rune with powerful magic",
			price = 200,
			sellPrice = 100,
			tradeable = true,
			droppable = true
		},

		-- SPAWNER CRATES (Purchasable loot boxes)
		basic_spawner_crate = {
			name = "Basic Spawner Crate",
			type = "CRATE",
			rarity = "BASIC",
			description = "Contains a random basic spawner",
			price = 100,
			sellPrice = 0, -- Cannot sell crates
			tradeable = false,
			droppable = false,
			lootPool = "basic_spawner_crate"
		},

		enhanced_spawner_crate = {
			name = "Enhanced Spawner Crate",
			type = "CRATE",
			rarity = "ENHANCED",
			description = "Contains a random enhanced spawner",
			price = 500,
			sellPrice = 0,
			tradeable = false,
			droppable = false,
			lootPool = "enhanced_spawner_crate"
		},

		superior_spawner_crate = {
			name = "Superior Spawner Crate",
			type = "CRATE",
			rarity = "SUPERIOR",
			description = "Contains a random superior spawner",
			price = 2000,
			sellPrice = 0,
			tradeable = false,
			droppable = false,
			lootPool = "superior_spawner_crate"
		},

		elite_spawner_crate = {
			name = "Elite Spawner Crate",
			type = "CRATE",
			rarity = "ELITE",
			description = "Contains a random elite spawner",
			price = 10000,
			sellPrice = 0,
			tradeable = false,
			droppable = false,
			lootPool = "elite_spawner_crate",
			requiresUnlock = true
		},

		-- CRYSTALS (Premium Currency)
		mana_crystal = {
			name = "Mana Crystal",
			type = "CRYSTAL",
			rarity = "BASIC",
			description = "Pure crystallized mana, used for premium upgrades",
			price = 100, -- In real currency or special rewards
			sellPrice = 0, -- Cannot sell premium currency
			tradeable = false,
			droppable = false
		},

		-- BLUEPRINTS
		advanced_spawner_blueprint = {
			name = "Advanced Spawner Blueprint",
			type = "BLUEPRINT",
			rarity = "ELITE",
			description = "Unlocks the ability to craft Elite-tier spawners",
			unlocks = "elite_spawners",
			price = 5000,
			sellPrice = 0, -- Blueprints cannot be sold
			tradeable = false,
			droppable = false
		},

		legendary_dungeon_blueprint = {
			name = "Legendary Dungeon Blueprint",
			type = "BLUEPRINT",
			rarity = "LEGENDARY",
			description = "Unlocks legendary dungeon upgrades and features",
			unlocks = "legendary_dungeons",
			price = 25000,
			sellPrice = 0,
			tradeable = false,
			droppable = false
		}
	},

	-- Loot pools for rewards and crates
	LootPools = {
		starter_rewards = {
			{itemId = "goblin_spawner", weight = 70, quantityRange = {1, 1}},
			{itemId = "basic_spawner_crate", weight = 20, quantityRange = {1, 1}},
			{itemId = "dark_iron", weight = 10, quantityRange = {5, 10}}
		},

		daily_reward = {
			{itemId = "goblin_tooth", weight = 40, quantityRange = {10, 20}},
			{itemId = "dark_iron", weight = 40, quantityRange = {5, 10}},
			{itemId = "basic_spawner_crate", weight = 20, quantityRange = {1, 1}}
		},

		-- Spawner crate loot pools - all simplified to Goblin spawners
		basic_spawner_crate = {
			{itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
		},

		enhanced_spawner_crate = {
			{itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
		},

		superior_spawner_crate = {
			{itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
		},

		elite_spawner_crate = {
			{itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
		},

		legendary_spawner_crate = {
			{itemId = "goblin_spawner", weight = 100, quantityRange = {1, 1}}
		}
	},

	-- Spawner drop rates - what each spawner type drops
	SpawnerDrops = {
		goblin_spawner = {
			{itemId = "goblin_tooth", weight = 80, quantityRange = {1, 3}},
			{itemId = "dark_iron", weight = 20, quantityRange = {1, 1}}
		}
	},



	-- Default player data template
	DefaultPlayerData = {
		coins = 0, -- Will be overridden by GameConfig.Currency.StartingCoins
		gems = 0,  -- Will be overridden by GameConfig.Currency.StartingGems
		manaCrystals = 0,
		level = 1,
		experience = 0,
		inventory = {},
		dungeon = {
			name = "Untitled Dungeon",
			level = 1,
			durability = 100,
			maxDurability = 100,
			energyCapacity = 100,
			currentEnergy = 100,
			spawnerSlots = {
				-- Slot 1 is unlocked by default with a spawner
				[1] = {spawner = "spawner", mobHead = nil, unlocked = true},
				-- Other slots are locked by default
				[2] = {spawner = nil, mobHead = nil, unlocked = false},
				[3] = {spawner = nil, mobHead = nil, unlocked = false},
				[4] = {spawner = nil, mobHead = nil, unlocked = false},
				[5] = {spawner = nil, mobHead = nil, unlocked = false},
				[6] = {spawner = nil, mobHead = nil, unlocked = false},
				[7] = {spawner = nil, mobHead = nil, unlocked = false},
				[8] = {spawner = nil, mobHead = nil, unlocked = false},
				[9] = {spawner = nil, mobHead = nil, unlocked = false},
				[10] = {spawner = nil, mobHead = nil, unlocked = false}
			},
			upgrades = {
				-- Applied upgrades will be stored here
			},
			defenseStats = {
				totalDamageDealt = 0,
				heroesDefeated = 0,
				invasionsRepelled = 0,
				coinsEarned = 0
			}
		},
		settings = {
			sound = true,
			music = true,
			graphics = "Medium",
			autoSort = false,
			dungeonNotifications = true
		},
		statistics = {
			playtime = 0,
			joinDate = 0,
			lastLogin = 0,
			itemsFound = 0,
			itemsCrafted = 0,
			spawnersDeployed = 0,
			spawnerUpgrades = 0,
			totalDropsCollected = 0,
			cratesOpened = 0,
			itemsSold = 0,
			coinsEarned = 0,
			manaCrystalsSpent = 0
		},
		achievements = {},
		collections = {},
		blueprints = {} -- Unlocked blueprints
	}
}

-- Helper functions
function ItemConfig.GetItemDefinition(itemId)
	return ItemConfig.Items[itemId]
end

function ItemConfig.GetItemType(typeName)
	return ItemConfig.ItemTypes[typeName]
end

function ItemConfig.GetItemRarity(rarityName)
	return ItemConfig.ItemRarities[rarityName]
end

function ItemConfig.GetLootPool(poolName)
	return ItemConfig.LootPools[poolName]
end

function ItemConfig.GetAllItemsByType(itemType)
	local items = {}
	for itemId, definition in pairs(ItemConfig.Items) do
		if definition.type == itemType then
			items[itemId] = definition
		end
	end
	return items
end

function ItemConfig.GetAllItemsByRarity(rarity)
	local items = {}
	for itemId, definition in pairs(ItemConfig.Items) do
		if definition.rarity == rarity then
			items[itemId] = definition
		end
	end
	return items
end

return ItemConfig