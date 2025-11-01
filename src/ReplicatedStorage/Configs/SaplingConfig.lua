--[[
	SaplingConfig.lua
	Basic configuration for sapling growth mechanics (Minecraft-like, simplified)
]]

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local SaplingConfig = {
	-- How often the service attempts growth checks (seconds)
	TICK_INTERVAL = 5,

	-- Chance per check to advance stage or attempt growth (approx 1/7 like MC random tick)
	ATTEMPT_CHANCE = 1/7,

	-- Max saplings processed per tick (performance budget)
	MAX_PER_TICK = 24,

	-- Light requirement simplified to sky visibility (no blocks above up to world height)
	REQUIRE_SKY_VISIBLE = true,

	-- Blocks that can be replaced by tree generation (for space checks)
	REPLACEABLE_BLOCKS = {
		[Constants.BlockType.AIR] = true,
		[Constants.BlockType.TALL_GRASS] = true,
		[Constants.BlockType.FLOWER] = true,
		[Constants.BlockType.LEAVES] = true,
		[Constants.BlockType.OAK_LEAVES] = true,
		[Constants.BlockType.SPRUCE_LEAVES] = true,
		[Constants.BlockType.JUNGLE_LEAVES] = true,
		[Constants.BlockType.DARK_OAK_LEAVES] = true,
		[Constants.BlockType.BIRCH_LEAVES] = true,
		[Constants.BlockType.ACACIA_LEAVES] = true,
		[Constants.BlockType.OAK_SAPLING] = true,
		[Constants.BlockType.SPRUCE_SAPLING] = true,
		[Constants.BlockType.JUNGLE_SAPLING] = true,
		[Constants.BlockType.DARK_OAK_SAPLING] = true,
		[Constants.BlockType.BIRCH_SAPLING] = true,
		[Constants.BlockType.ACACIA_SAPLING] = true,
	}

	,

	-- Leaf decay settings (simplified)
	LEAF_DECAY = {
		RADIUS = 6, -- distance connectivity like MC
		PROCESS_PER_TICK = 32, -- deterministic decays processed per tick (smaller for gradual feel)
		TICK_INTERVAL = 0.5, -- seconds between leaf decay ticks (separate from sapling growth)
		MAX_CHUNKS_PER_TICK = 16, -- random tick: how many active chunks to sample per tick
		RANDOM_TICKS_PER_CHUNK = 8, -- random tick: samples per chosen chunk
		-- Gradual decay scheduling window (seconds)
		SCHEDULE_DELAY_MIN = 1.0,
		SCHEDULE_DELAY_MAX = 6.0,
		BURST_DECAY_LIMIT = 64, -- max immediate decays after recompute
		SAPLING_DROP_CHANCE = 0.05, -- 5%
		APPLE_DROP_CHANCE = 0.005 -- 0.5%
	}
}

return SaplingConfig


