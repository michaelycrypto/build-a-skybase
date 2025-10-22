--[[
	Constants.lua
	Core constants for the voxel world system
]]

local Constants = {
	-- Chunk dimensions
	CHUNK_SIZE_X = 16,
    CHUNK_SIZE_Y = 128,
	CHUNK_SIZE_Z = 16,

	-- Section dimensions
	CHUNK_SECTION_SIZE = 16,

	-- World limits
    WORLD_HEIGHT = 128,
	MIN_HEIGHT = 0,

	-- Block size in studs
	BLOCK_SIZE = 3.5,

	-- Chunk states
	ChunkState = {
		EMPTY = "EMPTY",
		GENERATING = "GENERATING",
		READY = "READY",
		LOADED = "LOADED"
	},

	-- Block types
	BlockType = {
		AIR = 0,
		GRASS = 1,
		DIRT = 2,
		STONE = 3,
		BEDROCK = 4,
		WOOD = 5,
		LEAVES = 6,
		TALL_GRASS = 7,
		FLOWER = 8,
		CHEST = 9,
		SAND = 10,
		STONE_BRICKS = 11,
		OAK_PLANKS = 12,
		CRAFTING_TABLE = 13,
		COBBLESTONE = 14,
		BRICKS = 15,
		OAK_SAPLING = 16,
		-- Staircase blocks (rotation stored in metadata)
		OAK_STAIRS = 17,
		STONE_STAIRS = 18,
		COBBLESTONE_STAIRS = 19,
		STONE_BRICK_STAIRS = 20,
		BRICK_STAIRS = 21,
		-- Slab blocks (half-height blocks)
		OAK_SLAB = 22,
		STONE_SLAB = 23,
		COBBLESTONE_SLAB = 24,
		STONE_BRICK_SLAB = 25,
		BRICK_SLAB = 26
	},

	-- Mapping: Slab block ID → Full block ID (when two slabs combine)
	SlabToFullBlock = {
		[22] = 12,  -- OAK_SLAB → OAK_PLANKS
		[23] = 3,   -- STONE_SLAB → STONE
		[24] = 14,  -- COBBLESTONE_SLAB → COBBLESTONE
		[25] = 11,  -- STONE_BRICK_SLAB → STONE_BRICKS
		[26] = 15,  -- BRICK_SLAB → BRICKS
	},

	-- Reverse mapping: Full block ID → Slab ID (what to drop when broken)
	FullBlockToSlab = {
		[12] = 22,  -- OAK_PLANKS → OAK_SLAB
		[3] = 23,   -- STONE → STONE_SLAB
		[14] = 24,  -- COBBLESTONE → COBBLESTONE_SLAB
		[11] = 25,  -- STONE_BRICKS → STONE_BRICK_SLAB
		[15] = 26,  -- BRICKS → BRICK_SLAB
	},

	-- Block metadata format (single byte: 0-255)
	BlockMetadata = {
		-- Bits 0-1: Horizontal rotation (4 directions)
		ROTATION_MASK = 3,  -- 0b00000011
		ROTATION_NORTH = 0,  -- 0b00 (faces +Z)
		ROTATION_EAST = 1,   -- 0b01 (faces +X)
		ROTATION_SOUTH = 2,  -- 0b10 (faces -Z)
		ROTATION_WEST = 3,   -- 0b11 (faces -X)

		-- Bits 2-3: Vertical orientation (for stairs - upside down)
		VERTICAL_MASK = 12,  -- 0b00001100
		VERTICAL_BOTTOM = 0,
		VERTICAL_TOP = 4,

		-- Bits 4-6: Stair shape (Minecraft parity)
		SHAPE_MASK = 112, -- 0b01110000
		SHAPE_SHIFT = 4,
		STAIR_SHAPE_STRAIGHT = 0,
		STAIR_SHAPE_OUTER_LEFT = 1,
		STAIR_SHAPE_OUTER_RIGHT = 2,
		STAIR_SHAPE_INNER_LEFT = 3,
		STAIR_SHAPE_INNER_RIGHT = 4,

		-- Bit 7 reserved for future use
	},

	-- Network events
	NetworkEvent = {
		CHUNK_DATA = "ChunkDataStreamed",
		CHUNK_UNLOAD = "ChunkUnload",
		BLOCK_CHANGED = "BlockChanged",
		BLOCK_CHANGE_REJECTED = "BlockChangeRejected",
		REQUEST_CHUNKS = "VoxelRequestInitialChunks",
		PLAYER_POSITION = "VoxelPlayerPositionUpdate"
	}
}

-- Derived world sizes (studs) for a single chunk footprint
Constants.CHUNK_WORLD_SIZE_X = Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
Constants.CHUNK_WORLD_SIZE_Z = Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE

-- Metadata helper functions
function Constants.GetRotation(metadata)
	return bit32.band(metadata or 0, Constants.BlockMetadata.ROTATION_MASK)
end

function Constants.SetRotation(metadata, rotation)
	metadata = metadata or 0
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.ROTATION_MASK)),
		bit32.band(rotation, Constants.BlockMetadata.ROTATION_MASK)
	)
end

function Constants.GetVerticalOrientation(metadata)
	return bit32.band(metadata or 0, Constants.BlockMetadata.VERTICAL_MASK)
end

function Constants.SetVerticalOrientation(metadata, vertical)
	metadata = metadata or 0
	return bit32.bor(
		bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.VERTICAL_MASK)),
		bit32.band(vertical, Constants.BlockMetadata.VERTICAL_MASK)
	)
end

-- Stair shape helpers (bits 4-6)
function Constants.GetStairShape(metadata)
    local v = bit32.band(metadata or 0, Constants.BlockMetadata.SHAPE_MASK)
    return bit32.rshift(v, Constants.BlockMetadata.SHAPE_SHIFT)
end

function Constants.SetStairShape(metadata, shape)
    metadata = metadata or 0
    local shaped = bit32.lshift(bit32.band(shape or 0, 0x7), Constants.BlockMetadata.SHAPE_SHIFT)
    return bit32.bor(
        bit32.band(metadata, bit32.bnot(Constants.BlockMetadata.SHAPE_MASK)),
        bit32.band(shaped, Constants.BlockMetadata.SHAPE_MASK)
    )
end

-- Check if a block ID is a slab
function Constants.IsSlab(blockId)
	return Constants.SlabToFullBlock[blockId] ~= nil
end

-- Get the full block equivalent of a slab (returns nil if not a slab)
function Constants.GetFullBlockFromSlab(slabId)
	return Constants.SlabToFullBlock[slabId]
end

-- Get the slab equivalent of a full block (returns nil if block doesn't have slab form)
function Constants.GetSlabFromFullBlock(fullBlockId)
	return Constants.FullBlockToSlab[fullBlockId]
end

-- Check if a full block should drop as slabs when broken
function Constants.ShouldDropAsSlabs(blockId)
	return Constants.FullBlockToSlab[blockId] ~= nil
end

-- Check if two slabs can combine into a full block
-- Returns: canCombine (boolean), fullBlockId (number or nil)
function Constants.CanSlabsCombine(existingSlabId, existingMetadata, newSlabId, newMetadata)
	-- Must be the same slab type
	if existingSlabId ~= newSlabId then
		return false, nil
	end

	-- Must both be slabs
	if not Constants.IsSlab(existingSlabId) or not Constants.IsSlab(newSlabId) then
		return false, nil
	end

	-- Must have opposite vertical orientations
	local existingOrientation = Constants.GetVerticalOrientation(existingMetadata)
	local newOrientation = Constants.GetVerticalOrientation(newMetadata)

	if existingOrientation == newOrientation then
		return false, nil  -- Same orientation, can't stack
	end

	-- They can combine!
	local fullBlockId = Constants.GetFullBlockFromSlab(existingSlabId)
	return true, fullBlockId
end

return Constants