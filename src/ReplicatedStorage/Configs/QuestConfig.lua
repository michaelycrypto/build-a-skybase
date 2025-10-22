--[[
	QuestConfig

	Defines quest milestones and rewards per mob type.
	Mob types should match `mob:GetAttribute("MobType")` (e.g., "goblin_spawner").
--]]

local QuestConfig = {
	-- Whether to count lava deaths without an owner attribution
	CountUnattributed = true,

	-- Per-mob quest definitions
	Mobs = {
		Goblin = {
			displayName = "Goblin",
			-- Milestones are absolute kill counts for this mob type
			milestones = {10, 20, 30, 40, 50, 60, 100, 500},
			-- Rewards keyed by milestone value
			rewards = {
				[10] = {coins = 25},
				[20] = {coins = 25},
				[30] = {coins = 25},
				[40] = {coins = 25},
				[50] = {coins = 25},
				[60] = {coins = 25},
				[100] = {coins = 500, gems = 5},
				[500] = {coins = 1000, gems = 25}
			}
		}
	}
}

return QuestConfig


