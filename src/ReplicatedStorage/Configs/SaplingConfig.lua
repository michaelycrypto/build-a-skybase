--[[
	SaplingConfig.lua
	Basic configuration for sapling growth mechanics (Minecraft-like, simplified)
	
	Uses centralized SaplingTypes for leaf/sapling block lists.
]]

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local SaplingTypes = require(game.ReplicatedStorage.Configs.SaplingTypes)

-- Build REPLACEABLE_BLOCKS from SaplingTypes + static blocks
local REPLACEABLE_BLOCKS = {
	[Constants.BlockType.AIR] = true,
	[Constants.BlockType.TALL_GRASS] = true,
	[Constants.BlockType.FLOWER] = true,
	[Constants.BlockType.LEAVES] = true, -- Legacy leaves
}

-- Add all leaf types from SaplingTypes
for leavesId in pairs(SaplingTypes.LEAF_SET) do
	REPLACEABLE_BLOCKS[leavesId] = true
end

-- Add all sapling types from SaplingTypes
for saplingId in pairs(SaplingTypes.ALL_SAPLINGS) do
	REPLACEABLE_BLOCKS[saplingId] = true
end

local SaplingConfig = {
	-- How often the service attempts growth checks (seconds)
	TICK_INTERVAL = 5,

	-- Chance per check to advance stage or attempt growth
	-- Tuned for ~2.5 minutes expected growth time with 5s tick (5 * 30 = 150s)
	ATTEMPT_CHANCE = 1/30,

	-- Max saplings processed per tick (performance budget)
	MAX_PER_TICK = 24,

	-- Light requirement simplified to sky visibility (no blocks above up to world height)
	REQUIRE_SKY_VISIBLE = true,

	-- Blocks that can be replaced by tree generation (for space checks)
	-- Auto-generated from SaplingTypes
	REPLACEABLE_BLOCKS = REPLACEABLE_BLOCKS,

	-- Leaf decay settings (simplified)
	LEAF_DECAY = {
		RADIUS = 6, -- distance connectivity like MC
		PROCESS_PER_TICK = 24, -- moderate cadence for gradual feel
		TICK_INTERVAL = 0.75, -- slightly slower than before for fairness
		MAX_CHUNKS_PER_TICK = 8, -- fewer chunks per tick to smooth decay
		RANDOM_TICKS_PER_CHUNK = 4, -- moderate sampling per chunk
		-- Gradual decay scheduling window (seconds)
		SCHEDULE_DELAY_MIN = 1.5,
		SCHEDULE_DELAY_MAX = 5.0,
		BURST_DECAY_LIMIT = 12, -- cap immediate removals for smoother pacing
		SAPLING_DROP_CHANCE = 0.05, -- 5%
		APPLE_DROP_CHANCE = 0.005 -- 0.5%
	}
}

return SaplingConfig


