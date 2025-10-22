--[[
	MobAnimationConfig.lua - Configuration for the centralized mob animation system
	This config allows easy customization of animation IDs and behaviors
--]]

local MobAnimationConfig = {
	-- Performance settings
	Performance = {
		-- How often to update animations (seconds)
		UpdateInterval = 0.1,

		-- Max distance from any player to animate mobs
		MaxAnimationDistance = 200,

		-- Cleanup interval for destroyed mobs (seconds)
		CleanupInterval = 5,

		-- Whether to preload animations on start
		PreloadAnimations = true,

		-- Max number of mobs to animate simultaneously
		MaxSimultaneousMobs = 50
	},

	-- Default animation IDs (can be overridden per mob type)
	DefaultAnimations = {
		idle = {
			{ id = "rbxassetid://507766666", weight = 1 },
			{ id = "rbxassetid://507766951", weight = 1 },
			{ id = "rbxassetid://507766388", weight = 9 }
		},
		walk = {
			{ id = "rbxassetid://507777826", weight = 10 }
		},
		run = {
			{ id = "rbxassetid://507767714", weight = 10 }
		},
		swim = {
			{ id = "rbxassetid://507784897", weight = 10 }
		},
		swimidle = {
			{ id = "rbxassetid://507785072", weight = 10 }
		},
		jump = {
			{ id = "rbxassetid://507765000", weight = 10 }
		},
		fall = {
			{ id = "rbxassetid://507767968", weight = 10 }
		},
		climb = {
			{ id = "rbxassetid://507765644", weight = 10 }
		},
		sit = {
			{ id = "rbxassetid://507768133", weight = 10 }
		}
	},

	-- Mob-specific animation overrides
	MobTypeAnimations = {
		-- Example: Goblin could have different animations
		Goblin = {
			-- inherit all default animations, or override specific ones
			idle = {
				{ id = "rbxassetid://507766388", weight = 10 } -- More energetic idle
			}
			-- walk, run, etc. will use defaults if not specified
		}
		-- Add more mob types here as needed
	},

	-- Emote definitions (non-looping vs looping)
	EmoteSettings = {
		wave = false,     -- non-looping
		point = false,    -- non-looping
		dance = true,     -- looping
		dance2 = true,    -- looping
		dance3 = true,    -- looping
		laugh = false,    -- non-looping
		cheer = false     -- non-looping
	},

	-- Animation timing settings
	Timing = {
		-- Jump animation duration
		JumpAnimDuration = 0.31,

		-- Transition times for different states
		Transitions = {
			idle = 0.1,
			walk = 0.1,
			run = 0.1,
			jump = 0.1,
			fall = 0.2,
			swim = 0.4,
			swimidle = 0.4,
			sit = 0.5,
			climb = 0.1
		},

		-- Speed scales for different animations
		SpeedScales = {
			walk = 15.0,   -- speed / scale = animation speed
			run = 15.0,
			climb = 5.0,
			swim = 10.0
		}
	},

			-- Debug settings (for development only)
	Debug = {
		EnableDebugPrint = false,
		LogAnimationChanges = false,
		LogMobTracking = false
	}
}

return MobAnimationConfig
