--[[
	CropConfig.lua
	Simplified crop growth configuration
]]

local CropConfig = {
	-- Growth tick interval (seconds)
	TICK_INTERVAL = 5,

	-- Chance per tick for a crop to advance a stage
	ATTEMPT_CHANCE = 1/20,

	-- Max crops processed per tick (budget)
	MAX_PER_TICK = 64
}

return CropConfig


