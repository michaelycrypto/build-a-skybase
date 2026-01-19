--[[
	BlocksEntityRegistry.lua

	Central definition table for all block entities (blocks with state/data).
	Similar to MobRegistry but for blocks that have persistent state like chests, furnaces, etc.

	Block entities are blocks that:
	- Have inventory/storage (chests, furnaces, hoppers)
	- Have state that persists (furnace fuel, crafting progress)
	- Can be interacted with (crafting tables, enchanting tables)
	- Have special behavior (spawners, beacons)
]]

local BlocksEntityRegistry = {}

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BLOCK = Constants.BlockType

-- Block Entity Categories
BlocksEntityRegistry.Categories = {
	STORAGE = "STORAGE",        -- Blocks with inventory (chests, furnaces, hoppers)
	INTERACTIVE = "INTERACTIVE", -- Blocks that can be right-clicked (crafting table, enchanting table)
	MECHANICAL = "MECHANICAL",  -- Blocks with moving parts (doors, trapdoors, pistons)
	SPECIAL = "SPECIAL"         -- Unique blocks (spawners, beacons, jukeboxes)
}

-- Block Entity Definitions
BlocksEntityRegistry.Definitions = {
	-- ═══════════════════════════════════════════════════════════════════════
	-- STORAGE BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	[BLOCK.CHEST] = {
		blockId = BLOCK.CHEST,
		name = "Chest",
		category = BlocksEntityRegistry.Categories.STORAGE,
		hasInventory = true,
		inventorySize = 27, -- 3x9 slots
		canBeDouble = true, -- Can combine with adjacent chest
		interactable = true,
		persistent = true -- State persists across chunk loads
	},

	[BLOCK.FURNACE] = {
		blockId = BLOCK.FURNACE,
		name = "Furnace",
		category = BlocksEntityRegistry.Categories.STORAGE,
		hasInventory = true,
		inventorySize = 3, -- Input, fuel, output
		hasFuel = true,
		hasProgress = true, -- Smelting progress
		interactable = true,
		persistent = true
	},

	-- ═══════════════════════════════════════════════════════════════════════
	-- INTERACTIVE BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	[BLOCK.CRAFTING_TABLE] = {
		blockId = BLOCK.CRAFTING_TABLE,
		name = "Crafting Table",
		category = BlocksEntityRegistry.Categories.INTERACTIVE,
		hasInventory = false,
		interactable = true,
		persistent = false -- No state to persist
	},

	[BLOCK.ENCHANTING_TABLE] = {
		blockId = BLOCK.ENCHANTING_TABLE,
		name = "Enchanting Table",
		category = BlocksEntityRegistry.Categories.INTERACTIVE,
		hasInventory = false,
		interactable = true,
		persistent = false
	},

	[BLOCK.BREWING_STAND] = {
		blockId = BLOCK.BREWING_STAND,
		name = "Brewing Stand",
		category = BlocksEntityRegistry.Categories.INTERACTIVE,
		hasInventory = true,
		inventorySize = 4, -- 3 potions + 1 ingredient
		hasProgress = true, -- Brewing progress
		interactable = true,
		persistent = true
	},

	[BLOCK.ANVIL] = {
		blockId = BLOCK.ANVIL,
		name = "Anvil",
		category = BlocksEntityRegistry.Categories.INTERACTIVE,
		hasInventory = false,
		interactable = true,
		persistent = false
	},

	-- ═══════════════════════════════════════════════════════════════════════
	-- SPECIAL BLOCKS
	-- ═══════════════════════════════════════════════════════════════════════
	[BLOCK.SPAWNER] = {
		blockId = BLOCK.SPAWNER,
		name = "Spawner",
		category = BlocksEntityRegistry.Categories.SPECIAL,
		hasInventory = false,
		interactable = false,
		persistent = true,
		spawnData = {
			mobType = nil, -- Set via NBT data
			spawnDelay = 20, -- seconds
			minSpawnDelay = 200, -- ticks
			maxSpawnDelay = 800 -- ticks
		}
	},

	[BLOCK.BEACON] = {
		blockId = BLOCK.BEACON,
		name = "Beacon",
		category = BlocksEntityRegistry.Categories.SPECIAL,
		hasInventory = false,
		interactable = true,
		persistent = true,
		beaconData = {
			level = 0, -- Pyramid level (0-4)
			primaryEffect = nil,
			secondaryEffect = nil
		}
	},

	[BLOCK.JUKEBOX] = {
		blockId = BLOCK.JUKEBOX,
		name = "Jukebox",
		category = BlocksEntityRegistry.Categories.SPECIAL,
		hasInventory = false,
		interactable = true,
		persistent = true,
		jukeboxData = {
			disc = nil, -- Currently playing disc
			playing = false
		}
	},

	[BLOCK.NOTE_BLOCK] = {
		blockId = BLOCK.NOTE_BLOCK,
		name = "Note Block",
		category = BlocksEntityRegistry.Categories.SPECIAL,
		hasInventory = false,
		interactable = true,
		persistent = true,
		noteData = {
			note = 0, -- 0-24 (semitone)
			instrument = "harp" -- Based on block below
		}
	},

	[BLOCK.CAULDRON] = {
		blockId = BLOCK.CAULDRON,
		name = "Cauldron",
		category = BlocksEntityRegistry.Categories.SPECIAL,
		hasInventory = false,
		interactable = true,
		persistent = true,
		cauldronData = {
			level = 0, -- 0-3 (water level)
			content = "water" -- water, lava, powder_snow, potion
		}
	}
}

-- Helper Functions
function BlocksEntityRegistry:GetDefinition(blockId)
	return self.Definitions[blockId]
end

function BlocksEntityRegistry:IsBlockEntity(blockId)
	return self.Definitions[blockId] ~= nil
end

function BlocksEntityRegistry:HasInventory(blockId)
	local def = self:GetDefinition(blockId)
	return def and def.hasInventory == true
end

function BlocksEntityRegistry:IsInteractable(blockId)
	local def = self:GetDefinition(blockId)
	return def and def.interactable == true
end

function BlocksEntityRegistry:IsPersistent(blockId)
	local def = self:GetDefinition(blockId)
	return def and def.persistent == true
end

function BlocksEntityRegistry:GetInventorySize(blockId)
	local def = self:GetDefinition(blockId)
	return def and def.inventorySize or 0
end

function BlocksEntityRegistry:GetCategory(blockId)
	local def = self:GetDefinition(blockId)
	return def and def.category or nil
end

-- Serialize block entity state for persistence
function BlocksEntityRegistry:SerializeEntity(blockId, entityData)
	local def = self:GetDefinition(blockId)
	if not def then
		return nil
	end

	local serialized = {
		blockId = blockId,
		category = def.category
	}

	-- Serialize based on category
	if def.hasInventory and entityData.inventory then
		serialized.inventory = entityData.inventory
	end

	if def.hasFuel and entityData.fuel then
		serialized.fuel = entityData.fuel
		serialized.fuelTime = entityData.fuelTime
	end

	if def.hasProgress and entityData.progress then
		serialized.progress = entityData.progress
		serialized.maxProgress = entityData.maxProgress
	end

	if def.spawnData and entityData.spawnData then
		serialized.spawnData = entityData.spawnData
	end

	if def.beaconData and entityData.beaconData then
		serialized.beaconData = entityData.beaconData
	end

	if def.jukeboxData and entityData.jukeboxData then
		serialized.jukeboxData = entityData.jukeboxData
	end

	if def.noteData and entityData.noteData then
		serialized.noteData = entityData.noteData
	end

	if def.cauldronData and entityData.cauldronData then
		serialized.cauldronData = entityData.cauldronData
	end

	return serialized
end

-- Deserialize block entity state from persistence
function BlocksEntityRegistry:DeserializeEntity(serialized)
	if not serialized or not serialized.blockId then
		return nil
	end

	local def = self:GetDefinition(serialized.blockId)
	if not def then
		return nil
	end

	local entityData = {
		blockId = serialized.blockId
	}

	-- Deserialize based on what's present
	if serialized.inventory then
		entityData.inventory = serialized.inventory
	end

	if serialized.fuel then
		entityData.fuel = serialized.fuel
		entityData.fuelTime = serialized.fuelTime
	end

	if serialized.progress then
		entityData.progress = serialized.progress
		entityData.maxProgress = serialized.maxProgress
	end

	if serialized.spawnData then
		entityData.spawnData = serialized.spawnData
	end

	if serialized.beaconData then
		entityData.beaconData = serialized.beaconData
	end

	if serialized.jukeboxData then
		entityData.jukeboxData = serialized.jukeboxData
	end

	if serialized.noteData then
		entityData.noteData = serialized.noteData
	end

	if serialized.cauldronData then
		entityData.cauldronData = serialized.cauldronData
	end

	return entityData
end

return BlocksEntityRegistry
