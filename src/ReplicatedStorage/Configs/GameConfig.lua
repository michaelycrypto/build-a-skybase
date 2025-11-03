--[[
	GameConfig

	Main game configuration following framework minimalism.
	Easy for AI to understand and modify.
--]]

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
		backgroundMusic = {
			[1] = {
				id = "rbxassetid://6324790483", -- Background music track 1
				volume = 0.3
			},
			[2] = {
				id = "rbxassetid://10066947742", -- Background music track 2
				volume = 0.3
			}
		},
		soundEffects = {
			buttonClick = {id = "rbxassetid://6324790483", volume = 0.5}, -- Click sound
			buttonHover = {id = "rbxassetid://6324790483", volume = 0.3}, -- Hover sound
			purchase = {id = "rbxassetid://10066947742", volume = 0.7}, -- Purchase sound
			error = {id = "rbxassetid://8466981206", volume = 0.6}, -- Error sound
			coinCollect = {id = "rbxassetid://8646410774", volume = 0.4}, -- Coin collect
			levelUp = {id = "rbxassetid://17648982831", volume = 0.8}, -- Level up
			notification = {id = "rbxassetid://18595195017", volume = 0.4}, -- Notification
			achievement = {id = "rbxassetid://17648982831", volume = 0.8}, -- Achievement (same as level up)
			rewardClaim = {id = "rbxassetid://10066947742", volume = 0.6}, -- Reward claim (same as purchase)
				-- Voxel World Sounds
				blockPlace = {id = "rbxassetid://6324790483", volume = 0.5}, -- Block placement sound
				blockBreak = {id = "rbxassetid://6324790483", volume = 0.5} -- Block break sound
		}
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
		AutoSaveInterval = 300, -- 5 minutes in seconds
		DataStoreKey = "1DATA", -- DataStore2 combine key
		PlayerDataKeys = {"PlayerData", "Inventory", "Statistics"}
	},

	-- Inventory settings
	Inventory = {
		DefaultCapacity = 30,
		MaxCapacity = 100,
		StackSizeLimits = {
			RESOURCE = 1000,
			CRYSTAL = 100,
			BLUEPRINT = 1,
			CRATE = 10
		}
	},






	-- Rate limiting settings
	RateLimits = {
		InventoryOperations = {
			add_item = {calls = 20, window = 10},
			remove_item = {calls = 20, window = 10},
			move_item = {calls = 30, window = 10}
		},
		ShopOperations = {
			buy_crate = {calls = 10, window = 60},
			sell_items = {calls = 50, window = 60},
			bulk_sell = {calls = 5, window = 60}
		},
		WorldOperations = {
			teleport_player = {calls = 10, window = 60},
			world_regeneration = {calls = 1, window = 3600} -- Once per hour
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
				regular = Enum.Font.Gotham,
				bold = Enum.Font.GothamBold,
				italicBold = Enum.Font.GothamBold, -- Using GothamBold as base for italic bold styling
				mono = Enum.Font.RobotoMono
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
	}
}

function GameConfig.IsFeatureEnabled(featureName)
	return GameConfig.Features[featureName] == true
end

return GameConfig