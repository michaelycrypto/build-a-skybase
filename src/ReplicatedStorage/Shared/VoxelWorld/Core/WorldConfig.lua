--[[
	WorldConfig.lua
	World size and boundary configuration
]]

local WorldConfig = {
	-- World boundaries (in blocks)
	MAP_SIZE_X = 512,
	MAP_SIZE_Z = 512,

	-- Chunk settings
	CHUNKS_X = 32, -- 512/16 chunks
	CHUNKS_Z = 32, -- 512/16 chunks

	-- Render settings
	MAX_RENDER_DISTANCE = 8, -- Maximum chunks to render (Roblox optimized)
	MIN_RENDER_DISTANCE = 4, -- Minimum chunks to render
	FADE_DISTANCE = 6, -- Distance at which to start fading chunks

	-- Performance settings
	MAX_VISIBLE_CHUNKS = 64, -- Maximum chunks to have loaded at once
	CHUNK_LOAD_PER_FRAME = 2, -- Chunks to load per frame
	CHUNK_UNLOAD_DELAY = 2, -- Seconds to keep unused chunks in memory

	-- Visual settings
	CHUNK_BORDER_COLOR = Color3.fromRGB(255, 0, 0),
	SHOW_CHUNK_BORDERS = false,
	FADE_CHUNKS = true -- Enable distance-based transparency
}

-- Calculate derived values
WorldConfig.TOTAL_CHUNKS = WorldConfig.CHUNKS_X * WorldConfig.CHUNKS_Z
WorldConfig.WORLD_BOUNDS_MIN = Vector3.new(0, 0, 0)
WorldConfig.WORLD_BOUNDS_MAX = Vector3.new(
	WorldConfig.MAP_SIZE_X * 3, -- Using BLOCK_SIZE = 3
    128 * 3, -- Max height * BLOCK_SIZE
	WorldConfig.MAP_SIZE_Z * 3
)

return WorldConfig
