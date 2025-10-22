--[[
	MobPackageConfig.lua - Simple Mob Package Configuration
	Defines mob models using Roblox's package system
--]]

local MobPackageConfig = {
	-- Mob model packages
	Packages = {
		Goblin = {
			packageId = "rbxassetid://100557151478355",
			appearance = {
				bodyColors = {
					HeadColor = Color3.fromRGB(0, 128, 0),
					LeftArmColor = Color3.fromRGB(0, 128, 0),
					RightArmColor = Color3.fromRGB(0, 128, 0),
					LeftLegColor = Color3.fromRGB(0, 128, 0),
					RightLegColor = Color3.fromRGB(0, 128, 0),
					TorsoColor = Color3.fromRGB(0, 128, 0)
				},
				material = Enum.Material.Plastic
			},
			stats = {
				walkSpeed = 8,
				jumpHeight = 16
			}
		}
	},

	-- Simple cache settings
	CacheTimeout = 300, -- Cache models for 5 minutes
	PreloadOnStart = {"Goblin"} -- Preload Goblin models
}

return MobPackageConfig
