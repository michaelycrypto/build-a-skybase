--[[
	Config.lua - Central configuration loader
	Provides access to GameConfig with proper casing
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

-- Create Config module that provides both naming conventions
local Config = {}

-- Direct access to GameConfig
for key, value in pairs(GameConfig) do
	Config[key] = value
end

-- Provide UPPER_CASE aliases for compatibility
Config.SPAWNER_SYSTEM = GameConfig.SpawnerSystem
Config.Game = GameConfig

return Config