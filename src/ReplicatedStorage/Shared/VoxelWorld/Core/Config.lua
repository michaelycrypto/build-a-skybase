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

		-- Ore generation (4-tier: Copper → Iron → Steel → Bluesteel)
		ORE_CHANCES = {
			COAL = 0.012,        -- Common fuel
			COPPER = 0.010,      -- Tier 1 - abundant
			IRON = 0.008,        -- Tier 2 - common
			BLUESTEEL = 0.004    -- Tier 4 - rare (drops dust)
		}
	},

	-- Performance settings
	PERFORMANCE = {
		DEFAULT_RENDER_DISTANCE = 3, -- Chunks radius to render by default
		MAX_RENDER_DISTANCE = 8, -- Tighter cap for lower per-frame work
		MAX_WORLD_CHUNKS = 256, -- Hard cap on total loaded chunks on server
		MAX_CHUNKS_PER_PLAYER = 100, -- Per-player cap on visible chunks (9x9+ area)
		LOD_DISTANCE = 128, -- Studs distance for LOD change threshold
		MAX_CHUNKS_PER_FRAME = 2, -- Lower per-frame generation load
		MAX_MESH_UPDATES_PER_FRAME = 3, -- Optimized: can handle more chunks per frame
		MESH_UPDATE_BUDGET_MS = 6, -- Increased budget after optimizations
		GENERATION_BUDGET_MS = 3, -- Smaller generation time budget
		MAX_PARTS_PER_CHUNK = 600, -- Default max mesh parts per chunk
		MAX_PARTS_PER_CHUNK_HUB = 10000 -- Higher limit for hub worlds with complex schematics (SimpleHub has ~6k blocks/chunk)
	},

	-- Unload delay (seconds) used by ChunkManager
	CHUNK_UNLOAD_DELAY = 1,

	-- Network settings
	NETWORK = {
		CHUNK_STREAM_RATE = 30, -- Faster server streaming cadence
		POSITION_UPDATE_RATE = 10, -- Position updates per second
		MAX_BLOCK_UPDATES_PER_PACKET = 100, -- Maximum block updates per network packet
		MAX_CHUNK_REQUESTS_PER_FRAME = 6, -- Client requests per frame
		BLOCK_UPDATE_DISTANCE = 64, -- Studs radius to broadcast block changes
		MIN_VIEW_DISTANCE = 10,
		MAX_VIEW_DISTANCE = 12,
		MAX_CHUNKS_PER_UPDATE = 6, -- Server stream budget per player tick (increased for faster initial load)
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
		STAIR_QUADRANT_ASSIST = false,
		-- QoL: allow placing into air when aiming down if an adjacent horizontal support exists
		BRIDGE_ASSIST_ENABLED = true,
		-- How many cells to step back along aim direction to find a supported air cell
		BRIDGE_ASSIST_MAX_STEPS = 3
	},

	-- Debug settings
	DEBUG = {
		SHOW_CHUNK_BORDERS = false,
		SHOW_PERFORMANCE_STATS = true,
		LOG_NETWORK_EVENTS = false,
		DISABLE_FRUSTUM_CULLING = false,
		MAX_PARTS_PER_CHUNK = nil,
		-- Enable to log cross-shaped block texture selection (tall grass, flowers)
		LOG_CROSSSHAPE_TEXTURES = false,
		-- Enable to log texture pool acquisition (detect contaminated textures)
		LOG_TEXTURE_POOL = false,
		-- DIAGNOSTIC: Skip texture pool for cross-shapes (creates fresh textures each time)
		-- Enable this to test if the UV issue is caused by texture pooling
		CROSSSHAPE_BYPASS_POOL = false
	}
}

return Config