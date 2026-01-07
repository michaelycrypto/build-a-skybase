--[[
	BlockBreakFeedbackConfig.lua
	Defines per-material block hit sounds and crack overlay art.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

local BlockBreakFeedbackConfig = {}

BlockBreakFeedbackConfig.Material = {
	CLOTH = "CLOTH",
	GRASS = "GRASS",
	GRAVEL = "GRAVEL",
	SAND = "SAND",
	SNOW = "SNOW",
	STONE = "STONE",
	WOOD = "WOOD",
}

BlockBreakFeedbackConfig.DEFAULT_MATERIAL = BlockBreakFeedbackConfig.Material.STONE

local blockBreakLibrary = (GameConfig.SOUND_LIBRARY and GameConfig.SOUND_LIBRARY.blockBreak) or {}
local materialSoundLookup = {}
for materialName, soundList in pairs(blockBreakLibrary.materials or {}) do
	local materialKey = BlockBreakFeedbackConfig.Material[materialName]
	if materialKey then
		materialSoundLookup[materialKey] = soundList
	end
end

BlockBreakFeedbackConfig.HitSounds = materialSoundLookup
BlockBreakFeedbackConfig.DestroyStages = blockBreakLibrary.destroyStages or {}

local defaultMaterialName = blockBreakLibrary.defaultMaterial or "STONE"
BlockBreakFeedbackConfig.DEFAULT_MATERIAL = BlockBreakFeedbackConfig.Material[defaultMaterialName] or BlockBreakFeedbackConfig.Material.STONE

local blockMaterialMap = {}

local function assign(material, blockIds)
	for _, blockId in ipairs(blockIds) do
		blockMaterialMap[blockId] = material
	end
end

assign(BlockBreakFeedbackConfig.Material.GRASS, {
	Constants.BlockType.GRASS,
	Constants.BlockType.TALL_GRASS,
	Constants.BlockType.FLOWER,
	Constants.BlockType.FARMLAND,
	Constants.BlockType.OAK_SAPLING,
	Constants.BlockType.SPRUCE_SAPLING,
	Constants.BlockType.JUNGLE_SAPLING,
	Constants.BlockType.DARK_OAK_SAPLING,
	Constants.BlockType.BIRCH_SAPLING,
	Constants.BlockType.ACACIA_SAPLING,
})

assign(BlockBreakFeedbackConfig.Material.GRAVEL, {
	Constants.BlockType.DIRT,
	Constants.BlockType.COBBLESTONE,
	Constants.BlockType.COBBLESTONE_STAIRS,
	Constants.BlockType.COBBLESTONE_SLAB,
})

assign(BlockBreakFeedbackConfig.Material.SAND, {
	Constants.BlockType.SAND,
})

assign(BlockBreakFeedbackConfig.Material.CLOTH, {
	Constants.BlockType.LEAVES,
	Constants.BlockType.OAK_LEAVES,
	Constants.BlockType.SPRUCE_LEAVES,
	Constants.BlockType.JUNGLE_LEAVES,
	Constants.BlockType.DARK_OAK_LEAVES,
	Constants.BlockType.BIRCH_LEAVES,
	Constants.BlockType.ACACIA_LEAVES,
})

assign(BlockBreakFeedbackConfig.Material.WOOD, {
	Constants.BlockType.WOOD,
	Constants.BlockType.OAK_PLANKS,
	Constants.BlockType.OAK_STAIRS,
	Constants.BlockType.OAK_SLAB,
	Constants.BlockType.OAK_FENCE,
	Constants.BlockType.CHEST,
	Constants.BlockType.CRAFTING_TABLE,
	Constants.BlockType.SPRUCE_LOG,
	Constants.BlockType.SPRUCE_PLANKS,
	Constants.BlockType.SPRUCE_STAIRS,
	Constants.BlockType.SPRUCE_SLAB,
	Constants.BlockType.JUNGLE_LOG,
	Constants.BlockType.JUNGLE_PLANKS,
	Constants.BlockType.JUNGLE_STAIRS,
	Constants.BlockType.JUNGLE_SLAB,
	Constants.BlockType.DARK_OAK_LOG,
	Constants.BlockType.DARK_OAK_PLANKS,
	Constants.BlockType.DARK_OAK_STAIRS,
	Constants.BlockType.DARK_OAK_SLAB,
	Constants.BlockType.BIRCH_LOG,
	Constants.BlockType.BIRCH_PLANKS,
	Constants.BlockType.BIRCH_STAIRS,
	Constants.BlockType.BIRCH_SLAB,
	Constants.BlockType.ACACIA_LOG,
	Constants.BlockType.ACACIA_PLANKS,
	Constants.BlockType.ACACIA_STAIRS,
	Constants.BlockType.ACACIA_SLAB,
})

assign(BlockBreakFeedbackConfig.Material.STONE, {
	Constants.BlockType.STONE,
	Constants.BlockType.STONE_STAIRS,
	Constants.BlockType.STONE_SLAB,
	Constants.BlockType.STONE_BRICKS,
	Constants.BlockType.STONE_BRICK_STAIRS,
	Constants.BlockType.STONE_BRICK_SLAB,
	Constants.BlockType.BRICKS,
	Constants.BlockType.BRICK_STAIRS,
	Constants.BlockType.BRICK_SLAB,
	Constants.BlockType.COAL_ORE,
	Constants.BlockType.IRON_ORE,
	Constants.BlockType.COPPER_ORE,
	Constants.BlockType.BLUESTEEL_ORE,
	Constants.BlockType.TUNGSTEN_ORE,
	Constants.BlockType.TITANIUM_ORE,
	Constants.BlockType.FURNACE,
	Constants.BlockType.GLASS,
	Constants.BlockType.BEDROCK,
	-- Full blocks
	Constants.BlockType.COPPER_BLOCK,
	Constants.BlockType.COAL_BLOCK,
	Constants.BlockType.IRON_BLOCK,
	Constants.BlockType.STEEL_BLOCK,
	Constants.BlockType.BLUESTEEL_BLOCK,
	Constants.BlockType.TUNGSTEN_BLOCK,
	Constants.BlockType.TITANIUM_BLOCK,
})

BlockBreakFeedbackConfig.BlockMaterialMap = blockMaterialMap

return BlockBreakFeedbackConfig

