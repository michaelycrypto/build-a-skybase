--[[
	SaplingTypes.lua
	Centralized sapling type definitions - SINGLE SOURCE OF TRUTH
	
	All sapling-related mappings (sapling↔log, log↔leaves, species codes, etc.)
	are derived from this single table. Add new sapling types here only.
	
	Usage:
		local SaplingTypes = require(...)
		
		-- Check if a block is a sapling
		if SaplingTypes.IsSapling(blockId) then ... end
		
		-- Get log type for a sapling
		local logId = SaplingTypes.SAPLING_TO_LOG[saplingId]
		
		-- Get sapling type for a log
		local saplingId = SaplingTypes.LOG_TO_SAPLING[logId]
]]

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BLOCK = Constants.BlockType

--[[
	Master sapling definitions
	Each entry defines a complete wood family relationship
]]
local SAPLING_DEFINITIONS = {
	OAK = {
		saplingId = BLOCK.OAK_SAPLING,      -- 16
		logId = BLOCK.WOOD,                  -- 5 (Oak log)
		leavesId = BLOCK.OAK_LEAVES,         -- 63
		speciesCode = 0,                     -- Metadata bits 4-6 for leaf species
		name = "Oak Sapling",
		texture = "oak_sapling",
	},
	SPRUCE = {
		saplingId = BLOCK.SPRUCE_SAPLING,    -- 40
		logId = BLOCK.SPRUCE_LOG,            -- 38
		leavesId = BLOCK.SPRUCE_LEAVES,      -- 64
		speciesCode = 1,
		name = "Spruce Sapling",
		texture = "spruce_sapling",
	},
	JUNGLE = {
		saplingId = BLOCK.JUNGLE_SAPLING,    -- 45
		logId = BLOCK.JUNGLE_LOG,            -- 43
		leavesId = BLOCK.JUNGLE_LEAVES,      -- 65
		speciesCode = 2,
		name = "Jungle Sapling",
		texture = "jungle_sapling",
	},
	DARK_OAK = {
		saplingId = BLOCK.DARK_OAK_SAPLING,  -- 50
		logId = BLOCK.DARK_OAK_LOG,          -- 48
		leavesId = BLOCK.DARK_OAK_LEAVES,    -- 66
		speciesCode = 3,
		name = "Dark Oak Sapling",
		texture = "dark_oak_sapling",
	},
	BIRCH = {
		saplingId = BLOCK.BIRCH_SAPLING,     -- 55
		logId = BLOCK.BIRCH_LOG,             -- 53
		leavesId = BLOCK.BIRCH_LEAVES,       -- 67
		speciesCode = 4,
		name = "Birch Sapling",
		texture = "birch_sapling",
	},
	ACACIA = {
		saplingId = BLOCK.ACACIA_SAPLING,    -- 60
		logId = BLOCK.ACACIA_LOG,            -- 58
		leavesId = BLOCK.ACACIA_LEAVES,      -- 68
		speciesCode = 5,
		name = "Acacia Sapling",
		texture = "acacia_sapling",
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- AUTO-GENERATED LOOKUP TABLES (derived from SAPLING_DEFINITIONS)
-- ═══════════════════════════════════════════════════════════════════════════

-- Set of all sapling block IDs: { [saplingId] = true }
local ALL_SAPLINGS = {}

-- Sapling → Log mapping: { [saplingId] = logId }
local SAPLING_TO_LOG = {}

-- Log → Sapling mapping: { [logId] = saplingId }
local LOG_TO_SAPLING = {}

-- Log → Leaves mapping: { [logId] = leavesId }
local LOG_TO_LEAVES = {}

-- Leaves → Sapling mapping: { [leavesId] = saplingId }
local LEAVES_TO_SAPLING = {}

-- Set of all log block IDs: { [logId] = true }
local LOG_SET = {}

-- Set of all leaf block IDs: { [leavesId] = true }
local LEAF_SET = {}

-- Leaf type → Species code: { [leavesId] = speciesCode }
local LEAF_TO_SPECIES_CODE = {}

-- Species code → Sapling: { [speciesCode] = saplingId }
local SPECIES_CODE_TO_SAPLING = {}

-- Generate all lookup tables from definitions
for _, def in pairs(SAPLING_DEFINITIONS) do
	ALL_SAPLINGS[def.saplingId] = true
	SAPLING_TO_LOG[def.saplingId] = def.logId
	LOG_TO_SAPLING[def.logId] = def.saplingId
	LOG_TO_LEAVES[def.logId] = def.leavesId
	LEAVES_TO_SAPLING[def.leavesId] = def.saplingId
	LOG_SET[def.logId] = true
	LEAF_SET[def.leavesId] = true
	LEAF_TO_SPECIES_CODE[def.leavesId] = def.speciesCode
	SPECIES_CODE_TO_SAPLING[def.speciesCode] = def.saplingId
end

-- Also include legacy LEAVES block type (maps to Oak)
LEAF_SET[BLOCK.LEAVES] = true
LEAVES_TO_SAPLING[BLOCK.LEAVES] = BLOCK.OAK_SAPLING
LEAF_TO_SPECIES_CODE[BLOCK.LEAVES] = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════

local SaplingTypes = {
	-- Raw definitions (for iteration)
	Definitions = SAPLING_DEFINITIONS,
	
	-- Lookup tables
	ALL_SAPLINGS = ALL_SAPLINGS,
	SAPLING_TO_LOG = SAPLING_TO_LOG,
	LOG_TO_SAPLING = LOG_TO_SAPLING,
	LOG_TO_LEAVES = LOG_TO_LEAVES,
	LEAVES_TO_SAPLING = LEAVES_TO_SAPLING,
	LOG_SET = LOG_SET,
	LEAF_SET = LEAF_SET,
	LEAF_TO_SPECIES_CODE = LEAF_TO_SPECIES_CODE,
	SPECIES_CODE_TO_SAPLING = SPECIES_CODE_TO_SAPLING,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

--- Check if a block ID is a sapling
---@param blockId number
---@return boolean
function SaplingTypes.IsSapling(blockId)
	return ALL_SAPLINGS[blockId] == true
end

--- Check if a block ID is a log
---@param blockId number
---@return boolean
function SaplingTypes.IsLog(blockId)
	return LOG_SET[blockId] == true
end

--- Check if a block ID is a leaf
---@param blockId number
---@return boolean
function SaplingTypes.IsLeaf(blockId)
	return LEAF_SET[blockId] == true
end

--- Get the log type for a sapling
---@param saplingId number
---@return number|nil
function SaplingTypes.GetLogForSapling(saplingId)
	return SAPLING_TO_LOG[saplingId]
end

--- Get the sapling type for a log
---@param logId number
---@return number|nil
function SaplingTypes.GetSaplingForLog(logId)
	return LOG_TO_SAPLING[logId]
end

--- Get the leaves type for a log
---@param logId number
---@return number|nil
function SaplingTypes.GetLeavesForLog(logId)
	return LOG_TO_LEAVES[logId]
end

--- Get the sapling type for a leaf
---@param leavesId number
---@return number|nil
function SaplingTypes.GetSaplingForLeaves(leavesId)
	return LEAVES_TO_SAPLING[leavesId]
end

--- Get species code for a leaf type (for metadata encoding)
---@param leavesId number
---@return number|nil
function SaplingTypes.GetSpeciesCodeForLeaf(leavesId)
	return LEAF_TO_SPECIES_CODE[leavesId]
end

--- Get sapling type from species code (for metadata decoding)
---@param speciesCode number
---@return number|nil
function SaplingTypes.GetSaplingFromSpeciesCode(speciesCode)
	return SPECIES_CODE_TO_SAPLING[speciesCode]
end

--- Get all sapling IDs as an array
---@return table
function SaplingTypes.GetAllSaplingIds()
	local ids = {}
	for saplingId in pairs(ALL_SAPLINGS) do
		table.insert(ids, saplingId)
	end
	return ids
end

--- Get all log IDs as an array
---@return table
function SaplingTypes.GetAllLogIds()
	local ids = {}
	for logId in pairs(LOG_SET) do
		table.insert(ids, logId)
	end
	return ids
end

--- Get all leaf IDs as an array
---@return table
function SaplingTypes.GetAllLeafIds()
	local ids = {}
	for leavesId in pairs(LEAF_SET) do
		table.insert(ids, leavesId)
	end
	return ids
end

return SaplingTypes
