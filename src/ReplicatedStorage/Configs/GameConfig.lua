--[[
	GameConfig

	Main game configuration following framework minimalism.
	Easy for AI to understand and modify.
--]]

local SOUND_LIBRARY = {
	-- Background music tracks
	music = {
		[1] = {
			id = "rbxassetid://6324790483", -- Background music track 1
			volume = 0.3
		},
		[2] = {
			id = "rbxassetid://10066947742", -- Background music track 2
			volume = 0.3
		}
	},

	-- Named sound effects
		effects = {
		buttonClick = {id = "rbxassetid://6324790483", volume = 0.5}, -- Click sound
		buttonHover = {id = "rbxassetid://6324790483", volume = 0.3}, -- Hover sound
		purchase = {id = "rbxassetid://10066947742", volume = 0.7}, -- Purchase sound
		error = {id = "rbxassetid://8466981206", volume = 0.6}, -- Error sound
		coinCollect = {id = "rbxassetid://8646410774", volume = 0.4}, -- Coin collect
		levelUp = {id = "rbxassetid://17648982831", volume = 0.8}, -- Level up
		notification = {id = "rbxassetid://18595195017", volume = 0.4}, -- Notification
		achievement = {id = "rbxassetid://17648982831", volume = 0.8}, -- Achievement (same as level up)
		rewardClaim = {id = "rbxassetid://10066947742", volume = 0.6}, -- Reward claim (same as purchase)
		blockPlace = {id = "rbxassetid://6324790483", volume = 0.5}, -- Block placement sound
		blockBreak = {id = "rbxassetid://6324790483", volume = 0.5}, -- Block break sound
			inventoryPop = {id = "rbxassetid://116766040641694", volume = 0.65}, -- Inventory add/drop confirmation
			hitConfirm1 = {id = "rbxassetid://80622415030550", volume = 0.8}, -- Successful hit confirmation (variant 1)
			hitConfirm2 = {id = "rbxassetid://137305868942109", volume = 0.8}, -- Successful hit confirmation (variant 2)
			hitConfirm3 = {id = "rbxassetid://131614675021657", volume = 0.8}, -- Successful hit confirmation (variant 3)
			zombieDeath = {id = "rbxassetid://76518122006577", volume = 0.8}, -- Zombie death
			zombieSay1 = {id = "rbxassetid://123137984396272", volume = 0.7},
			zombieSay2 = {id = "rbxassetid://84419437806718", volume = 0.7},
			zombieSay3 = {id = "rbxassetid://135638254815605", volume = 0.7},
			zombieHurt1 = {id = "rbxassetid://96721285901178", volume = 0.75},
			zombieHurt2 = {id = "rbxassetid://70383423672318", volume = 0.75},
			-- Furnace/Smelting sounds
			smeltReveal = {id = "rbxassetid://9126073064", volume = 0.6} -- Sparkle/magic reveal
	},

	-- Block break specific audio (hit sounds + crack overlays)
	blockBreak = {
		defaultMaterial = "STONE",
		materials = {
			CLOTH = {
				"rbxassetid://81861806871886",
				"rbxassetid://123427473982725",
				"rbxassetid://73699577303099",
				"rbxassetid://97951769547033"
			},
			GRASS = {
				"rbxassetid://75505061544532",
				"rbxassetid://124882222888442",
				"rbxassetid://119971320422272",
				"rbxassetid://98041171530531"
			},
			GRAVEL = {
				"rbxassetid://137217647022562",
				"rbxassetid://133325038915077",
				"rbxassetid://85677719368412",
				"rbxassetid://85677719368412"
			},
			SAND = {
				"rbxassetid://117297811836351",
				"rbxassetid://112394400270897",
				"rbxassetid://133436973630142",
				"rbxassetid://113442257849670"
			},
			SNOW = {
				"rbxassetid://96086276839473",
				"rbxassetid://135139115397346",
				"rbxassetid://98591241368478",
				"rbxassetid://77291695981596"
			},
			STONE = {
				"rbxassetid://90449580070492",
				"rbxassetid://113945567384752",
				"rbxassetid://133928494021309",
				"rbxassetid://136166769778734"
			},
			WOOD = {
				"rbxassetid://104636919169799",
				"rbxassetid://80052678002221",
				"rbxassetid://100021273321115",
				"rbxassetid://74239169447328"
			}
		},
		destroyStages = {
			"rbxassetid://125479763188196", -- Stage 0
			"rbxassetid://122437960590463", -- Stage 1
			"rbxassetid://87494235425051", -- Stage 2
			"rbxassetid://86331071302668", -- Stage 3
			"rbxassetid://139320505726774", -- Stage 4
			"rbxassetid://124395945436399", -- Stage 5
			"rbxassetid://129303387455522", -- Stage 6
			"rbxassetid://140150860430907", -- Stage 7
			"rbxassetid://86006077340395",  -- Stage 8
			"rbxassetid://71974612582615"   -- Stage 9
		}
	}
}

local GameConfig = {
	-- Currency settings
	Currency = {
		StartingCoins = 100,
		StartingGems = 0,
		MaxCoins = 999999,
		MaxGems = 9999
	},

	-- Audio settings
	AUDIO_SETTINGS = {
		backgroundMusic = SOUND_LIBRARY.music,
		soundEffects = SOUND_LIBRARY.effects
	},

	-- Default player data
	DEFAULT_PLAYER_DATA = {
		userId = 0,
		displayName = "",
		coins = 100, -- Starting coins
		gems = 0, -- Starting gems
		manaCrystals = 0,
		experience = 0,
		level = 1,
		lastActive = 0
	},


	-- Data Store settings
	DataStore = {
		PlayerData = {
			DataStoreVersion = "PlayerData_v69", -- Keep in sync with PlayerDataStoreService (updated for 6-tier system)
			SchemaVersion = 5, -- Increment to force migrations/default resets
			AutoSaveInterval = 300 -- 5 minutes in seconds
		},
	},

	-- Inventory settings
	Inventory = {
		-- Starter loadouts (shared between hub + player-owned worlds)
		StarterHotbar = {
			{slot = 1, itemId = 1051, count = 1}, -- Bow
			{slot = 2, itemId = 2001, count = 64},
			{slot = 3, itemId = 2001, count = 64}, -- Arrows
		},
		StarterInventory = {
			-- ═══════════════════════════════════════════════════════════════
			-- FURNACE TESTING - Ores & Fuel
			-- ═══════════════════════════════════════════════════════════════
			{itemId = 98, count = 64},  -- Copper Ore (T1)
			{itemId = 30, count = 64},  -- Iron Ore (T2, also for Steel/Bluesteel)
			{itemId = 102, count = 64}, -- Tungsten Ore (T5)
			{itemId = 103, count = 64}, -- Titanium Ore (T6)
			{itemId = 32, count = 64},  -- Coal (fuel)
			{itemId = 32, count = 64},  -- Coal (more fuel)
			{itemId = 123, count = 1},  -- Coal Golem (minion)
			{itemId = 115, count = 64}, -- Bluesteel Dust (for Bluesteel smelting)

			-- ═══════════════════════════════════════════════════════════════
			-- FOOD ITEMS (Minecraft-style consumables)
			-- ═══════════════════════════════════════════════════════════════
			-- Basic Foods
			{itemId = 37, count = 32},  -- Apple
			{itemId = 73, count = 32},  -- Carrot
			{itemId = 72, count = 32},  -- Potato
			{itemId = 75, count = 32},  -- Beetroot

			-- Cooked Foods
			{itemId = 348, count = 16}, -- Bread
			{itemId = 349, count = 16}, -- Baked Potato
			{itemId = 350, count = 16}, -- Cooked Beef
			{itemId = 351, count = 16}, -- Cooked Porkchop
			{itemId = 352, count = 16}, -- Cooked Chicken
			{itemId = 353, count = 16}, -- Cooked Mutton
			{itemId = 354, count = 16}, -- Cooked Rabbit
			{itemId = 355, count = 16}, -- Cooked Cod
			{itemId = 356, count = 16}, -- Cooked Salmon

			-- Special Foods
			{itemId = 366, count = 8},  -- Golden Apple
			{itemId = 367, count = 4},  -- Enchanted Golden Apple
			{itemId = 368, count = 16}, -- Golden Carrot

			-- Soups & Stews
			{itemId = 369, count = 4},  -- Beetroot Soup
			{itemId = 370, count = 4},  -- Mushroom Stew
			{itemId = 371, count = 4},  -- Rabbit Stew

			-- Other Foods
			{itemId = 372, count = 32}, -- Cookie
			{itemId = 373, count = 32}, -- Melon Slice
			{itemId = 374, count = 32}, -- Dried Kelp
			{itemId = 375, count = 8},  -- Pumpkin Pie

			-- Raw Meats (for cooking)
			{itemId = 357, count = 16}, -- Beef
			{itemId = 358, count = 16}, -- Porkchop
			{itemId = 359, count = 16}, -- Chicken
			{itemId = 360, count = 16}, -- Mutton
			{itemId = 361, count = 16}, -- Rabbit

			-- Raw Fish (for cooking)
			{itemId = 362, count = 16}, -- Cod
			{itemId = 363, count = 16}, -- Salmon
			{itemId = 364, count = 16}, -- Tropical Fish
			{itemId = 365, count = 8},  -- Pufferfish (dangerous!)

			-- Hazardous Foods (for testing effects)
			{itemId = 376, count = 8},  -- Rotten Flesh
			{itemId = 377, count = 4},  -- Spider Eye
			{itemId = 378, count = 8},  -- Poisonous Potato
			{itemId = 379, count = 4},  -- Chorus Fruit

			-- ═══════════════════════════════════════════════════════════════
			-- CRAFTING MATERIALS
			-- ═══════════════════════════════════════════════════════════════
			{itemId = 28, count = 64},  -- Sticks (stack 1)
			{itemId = 28, count = 64},  -- Sticks (stack 2)
			{itemId = 12, count = 64},  -- Oak Planks (for more sticks)

			-- ═══════════════════════════════════════════════════════════════
			-- PRE-MADE INGOTS (for quick crafting)
			-- ═══════════════════════════════════════════════════════════════
			{itemId = 105, count = 64}, -- Copper Ingots
			{itemId = 33, count = 64},  -- Iron Ingots
			{itemId = 108, count = 64}, -- Steel Ingots
			{itemId = 109, count = 64}, -- Bluesteel Ingots
			{itemId = 110, count = 64}, -- Tungsten Ingots
			{itemId = 111, count = 64}, -- Titanium Ingots

			-- ═══════════════════════════════════════════════════════════════
			-- UTILITY BLOCKS
			-- ═══════════════════════════════════════════════════════════════
			{itemId = 13, count = 4},   -- Crafting Tables
			{itemId = 35, count = 4},   -- Furnaces
		}
	},

	-- Shop settings
	Shop = {
		-- Stock management
		stock = {
			replenishmentInterval = 120, -- Seconds between restocks
			maxStock = 10,
			minStock = 1
		},
		-- Featured items with restock configuration
		featuredItems = {
			{
				itemId = "goblin_head",
				restockLuck = 1.0, -- 100% chance to restock (always available)
				restockAmount = {min = 3, max = 3}, -- New stock amount when lucky (1-3)
				priority = 1 -- Higher priority items restock first
			},
			{
				itemId = "zombie_head",
				restockLuck = 1.0, -- 100% chance to restock (always available)
				restockAmount = {min = 1, max = 1}, -- New stock amount when lucky (1-2)
				priority = 2
			},
			{
				itemId = "rat_head",
				restockLuck = 0.25, -- 50% chance to restock
				restockAmount = {min = 0, max = 1}, -- New stock amount when lucky (0-1, can be 0)
				priority = 3
			}
		},
		-- Restock behavior
		restock = {
			-- Global restock settings
			guaranteedRestock = false, -- No guaranteed restock - let luck decide
			maxItemsPerRestock = 3, -- Maximum number of items that can restock per cycle
			-- Luck modifiers
			luckModifiers = {
				baseMultiplier = 1.0, -- Base luck multiplier
				timeOfDayBonus = 0.1, -- Bonus during peak hours (if implemented)
				playerCountBonus = 0.05 -- Bonus per 10 players online (if implemented)
			}
		},
		-- UI settings
		ui = {
			itemHeight = 110,
			spacing = 14,
			padding = 20,
			iconSize = 64
		},
		-- Toast notifications
		toast = {
			purchaseDuration = 2, -- Seconds
			restockDuration = 3   -- Seconds
		}
	},

	-- Combat/Animation settings
	Combat = {
		SWING_SPEED = 18, -- Animation playback speed (higher = faster)
		SWING_COOLDOWN = 0.22, -- Cooldown between swings (seconds)
	},

	-- Minecraft-style character proportions
	-- Applied to all player characters (Hub, Player World, Armor UI viewmodel)
	CharacterScale = {
		HEIGHT = 1.2,   -- Taller (Minecraft Steve is 2 blocks = 6 studs, Roblox is ~5 studs)
		WIDTH = 0.85,   -- Narrower limbs (Steve's arms/legs are 4 pixels wide vs 8 pixel body)
		DEPTH = 0.85,   -- Same as width for uniform limb thinning
		HEAD = 1.1,     -- Slightly larger head like Minecraft
	},

	-- Cooldown settings
	Cooldowns = {
		crate_opening = 1,          -- 1 second (prevent spam)
		bulk_sell = 60,             -- 1 minute
		teleport_cooldown = 5,      -- 5 seconds between teleports
	},

	-- World system settings
	World = {
		GridSize = {
			width = 52, -- 13 * 4
			height = 80  -- 20 * 4
		},
		BaseTileSize = 4, -- studs per grid unit
		TileTypes = {
			"Baseplate",
			"LargeBaseplate"
		},
		RegenerateOnStart = true,
		CleanupOnShutdown = true
	},

	-- Dropped items settings
	DroppedItems = {
		HitboxSize = Vector3.new(0.9, 0.9, 0.9)
	},

	-- Features (simple toggles)
	Features = {
		Currency = true,
		Shop = true,
		InventorySystem = true,
		ItemTracking = true,
		CrateSystem = true,
		ProgressionUnlocks = true,
		AutoSell = true,
		BulkSell = true,
		WorldSystem = true,
		DailyRewards = true,
		Statistics = true,
		SoundSystem = true,
		-- Enable/disable mouse lock (centering the cursor during gameplay)
		MouseLock = true
	},

	-- Server configuration
	SERVER = {
		SAVE_INTERVAL = 300, -- 5 minutes
		HEARTBEAT_INTERVAL = 60, -- 1 minute
		SHUTDOWN_GRACE_PERIOD = 10 -- 10 seconds
	},

	-- Toast notification icons
	TOAST_ICONS = {
		types = {
			success = {
				iconCategory = "UI",
				iconName = "CheckMark",
				context = "Toast_SuccessIcon"
			},
			warning = {
				iconCategory = "UI",
				iconName = "Warning",
				context = "Toast_WarningIcon"
			},
			error = {
				iconCategory = "UI",
				iconName = "X",
				context = "Toast_ErrorIcon"
			},
			info = {
				iconCategory = "UI",
				iconName = "Info",
				context = "Toast_InfoIcon"
			},
			currency = {
				iconCategory = "Currency",
				iconName = "Cash",
				context = "Toast_CurrencyIcon"
			},
			coins = {
				iconCategory = "Currency",
				iconName = "Cash",
				context = "Toast_CoinsIcon"
			},
			experience = {
				iconCategory = "General",
				iconName = "Star",
				context = "Toast_ExperienceIcon"
			},
			achievement = {
				iconCategory = "General",
				iconName = "Trophy",
				context = "Toast_AchievementIcon"
			},
			shop = {
				iconCategory = "General",
				iconName = "Shop",
				context = "Toast_ShopIcon"
			},
			social_join = {
				iconCategory = "Player",
				iconName = "AddFriend",
				context = "Toast_SocialJoinIcon"
			},
			social_leave = {
				iconCategory = "Player",
				iconName = "RemoveFriend",
				context = "Toast_SocialLeaveIcon"
			}
		},
		fallbacks = {
			default = {
				iconCategory = "General",
				iconName = "Star",
				context = "Toast_DefaultIcon"
			}
		}
	},

	-- Logging configuration
	LOGGING = {
		logLevel = "Info", -- Debug, Info, Warn, Error
		enableFileLogging = false,
		enableConsoleLogging = true
	},

	-- Performance debug toggles (server/client)
	PERF_DEBUG = {
		-- Set true to skip server dropped item merges (keeps despawn)
		DISABLE_DROPPED_ITEM_MERGE = true,
		-- Override interval (seconds) for dropped item loop; nil = default (1)
		DROPPED_ITEM_LOOP_INTERVAL = nil,

		-- Set true to skip sapling leaf-tick processing (decay/random ticks)
		DISABLE_SAPLING_LEAF_TICK = false,
		-- Override leaf tick interval (seconds); nil = SaplingConfig default
		LEAF_TICK_INTERVAL = nil,
		-- Optional cap per tick (if supported by service); nil = SaplingConfig default
		LEAF_PROCESS_PER_TICK = nil
	},

	-- UI Settings for UIComponents
	UI_SETTINGS = {
		-- Design system tokens
		designSystem = {
			borderRadius = {
				xs = 4,
				sm = 6,
				md = 8,
				lg = 12,
				xl = 16
			},
			spacing = {
				xs = 4,
				sm = 8,
				md = 12,
				lg = 16,
				xl = 24,
				xxl = 32
			},
			transparency = {
				backdrop = 0.3,
				heavy = 0.5,
				medium = 0.3,
				light = 0.1,
				subtle = 0.05,
				ghost = 0.8
			},
			borderWidth = {
				thin = 3, -- Increased from 1 to 3 for thicker panel borders
				medium = 4, -- Increased from 2 to 4
				thick = 5  -- Increased from 3 to 5
			},
			animation = {
				duration = {
					fast = 0.1,
					normal = 0.2,
					slow = 0.3
				},
				easing = {
					ease = Enum.EasingStyle.Quad,
					smooth = Enum.EasingStyle.Sine
				}
			}
		},

		-- Color palette
		colors = {
			-- Primary colors
			primary = Color3.fromRGB(88, 101, 242),
			accent = Color3.fromRGB(255, 215, 0),

			-- Background colors (Light theme with white backgrounds)
			background = Color3.fromRGB(255, 255, 255),
			backgroundSecondary = Color3.fromRGB(248, 249, 250),
			backgroundGlass = Color3.fromRGB(255, 255, 255),

			-- Text colors (Dark text for light backgrounds)
			text = Color3.fromRGB(33, 37, 41),
			textSecondary = Color3.fromRGB(73, 80, 87),
			textMuted = Color3.fromRGB(108, 117, 125),

			-- Semantic colors
			semantic = {
				backgrounds = {
					card = Color3.fromRGB(248, 249, 250),
					panel = Color3.fromRGB(255, 255, 255)
				},
				borders = {
					default = Color3.fromRGB(0, 0, 0), -- Black borders for panels
					subtle = Color3.fromRGB(233, 236, 239)
				},
				button = {
					primary = Color3.fromRGB(88, 101, 242),
					secondary = Color3.fromRGB(233, 236, 239),
					success = Color3.fromRGB(34, 197, 94),
					warning = Color3.fromRGB(251, 191, 36),
					danger = Color3.fromRGB(239, 68, 68)
				},
				game = {
					coins = Color3.fromRGB(255, 215, 0),
					gems = Color3.fromRGB(139, 69, 193),
					experience = Color3.fromRGB(34, 197, 94)
				},
				hud = {
					sidebar = {
						background = Color3.fromRGB(248, 249, 250),
						border = Color3.fromRGB(206, 212, 218)
					},
					bottomBar = {
						freeCoins = {
							background = Color3.fromRGB(34, 197, 94),
							border = Color3.fromRGB(40, 120, 80)
						},
						emote = {
							background = Color3.fromRGB(88, 101, 242),
							border = Color3.fromRGB(206, 212, 218)
						}
					}
				}
			}
		},

		-- Typography system
		typography = {
			fonts = {
				regular = Enum.Font.BuilderSansBold,
				bold = Enum.Font.BuilderSansBold,
				italicBold = Enum.Font.BuilderSansBold, -- Using BuilderSansBold as base for italic bold styling
				mono = Enum.Font.BuilderSansBold
			},
			sizes = {
				display = {
					hero = 54,
					large = 44,
					medium = 36,
					small = 32
				},
				headings = {
					h1 = 28,
					h2 = 24,
					h3 = 22,
					h4 = 20
				},
				body = {
					large = 22,
					base = 20,
					small = 18,
					xs = 17
				},
				ui = {
					button = 28,
					badge = 18,
					caption = 20,
					toast = 18
				}
			}
		},

		-- Title label styling
		titleLabel = {
			textColor = Color3.fromRGB(255, 255, 255), -- White text
			stroke = {
				color = Color3.fromRGB(0, 0, 0), -- Black stroke
				thickness = 2 -- 2px stroke
			}
		}
	},

	-- World system configuration
	Worlds = {
		MaxWorldsPerPlayer = 10, -- Maximum worlds a player can create
		DataStoreVersion = "PlayerOwnedWorlds_v61" -- Updated for multi-world support
	}
}

GameConfig.SOUND_LIBRARY = SOUND_LIBRARY

function GameConfig.IsFeatureEnabled(featureName)
	return GameConfig.Features[featureName] == true
end

return GameConfig