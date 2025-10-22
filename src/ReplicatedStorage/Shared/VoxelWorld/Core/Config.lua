--[[
	Config.lua
	Configuration settings for the voxel world system
]]

local Config = {
	-- World generation settings (Minecraft-like)
	TERRAIN = {
		-- Base terrain
		NOISE_SCALE = 100, -- Scale of the Perlin noise
		NOISE_AMPLITUDE = 32, -- Maximum height variation (like Minecraft)
		BASE_HEIGHT = 64, -- Base terrain height

		-- Biome variation
		TEMPERATURE_SCALE = 200, -- Scale of temperature variation
		HUMIDITY_SCALE = 200, -- Scale of humidity variation

		-- Features
		TREE_DENSITY = 0.02, -- Trees per block (probability)
		MIN_TREE_HEIGHT = 4,
		MAX_TREE_HEIGHT = 8,

		-- Cave generation
		CAVE_DENSITY = 0.025, -- Cave density
		CAVE_SCALE = 50, -- Cave noise scale
		CAVE_THRESHOLD = 0.3, -- Cave formation threshold

		-- Ore generation
		ORE_CHANCES = {
			COAL = 0.01,
			IRON = 0.007,
			GOLD = 0.003,
			DIAMOND = 0.001
		}
	},

	-- Performance settings
	PERFORMANCE = {
		DEFAULT_RENDER_DISTANCE = 3, -- Chunks radius to render by default
		MAX_RENDER_DISTANCE = 8, -- Tighter cap for lower per-frame work
		MAX_WORLD_CHUNKS = 256, -- Hard cap on total loaded chunks on server
		MAX_CHUNKS_PER_PLAYER = 18, -- Per-player cap on visible chunks
		LOD_DISTANCE = 128, -- Studs distance for LOD change threshold
		MAX_CHUNKS_PER_FRAME = 2, -- Lower per-frame generation load
		MAX_MESH_UPDATES_PER_FRAME = 2, -- Fewer client mesh updates per frame
		MESH_UPDATE_BUDGET_MS = 4, -- Smaller time budget per frame
		GENERATION_BUDGET_MS = 3 -- Smaller generation time budget
	},

	-- Unload delay (seconds) used by ChunkManager
	CHUNK_UNLOAD_DELAY = 1,

	-- Network settings
	NETWORK = {
		CHUNK_STREAM_RATE = 24, -- Faster server streaming cadence
		POSITION_UPDATE_RATE = 10, -- Position updates per second
		MAX_BLOCK_UPDATES_PER_PACKET = 100, -- Maximum block updates per network packet
		MAX_CHUNK_REQUESTS_PER_FRAME = 3, -- Client requests per frame
		BLOCK_UPDATE_DISTANCE = 64, -- Studs radius to broadcast block changes
		MIN_VIEW_DISTANCE = 10,
		MAX_VIEW_DISTANCE = 12,
		MAX_CHUNKS_PER_UPDATE = 2, -- Server stream budget per player tick
		UNLOAD_EXTRA_RADIUS = 1, -- Keep chunks for +N rings beyond renderDistance before unloading
		ENTITY_TRACKING_RADIUS = 256 -- Studs radius for player entity replication (independent of chunk rendering)
	},

	-- Storage settings
	STORAGE = {
		AUTOSAVE_INTERVAL = 300, -- Seconds between auto-saves
		MAX_CHUNKS_PER_SAVE = 64, -- Maximum chunks to save per interval
		COMPRESSION_LEVEL = 2 -- 0-9, higher = better compression but slower
	},

	-- Placement settings
	PLACEMENT = {
		-- If true, server will rotate stairs during placement to snap corners with neighbors
		-- Minecraft keeps player-facing rotation and derives corner shapes from neighbors during rendering
		-- Set false for closer parity with Minecraft
		STAIR_AUTO_ROTATE_ON_PLACE = false,
		-- If true, on placement we choose a stair rotation that yields a corner (inner preferred) when possible
		-- Match Minecraft: do not force corners on placement; shape derives from neighbors at render time
		STAIR_CORNER_ON_PLACEMENT = false,
		-- If true, use within-face hit position to bias corner selection towards clicked quadrant (QoL, non-vanilla)
		STAIR_QUADRANT_ASSIST = false
	},

	-- Debug settings
	DEBUG = {
		SHOW_CHUNK_BORDERS = false,
		SHOW_PERFORMANCE_STATS = true,
		LOG_NETWORK_EVENTS = false,
		DISABLE_FRUSTUM_CULLING = false,
		MAX_PARTS_PER_CHUNK = nil
	}
}

return Config