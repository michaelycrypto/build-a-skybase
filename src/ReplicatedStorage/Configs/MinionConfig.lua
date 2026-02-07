--[[
	MinionConfig.lua
	Defines minion types, their production blocks, upgrade costs, and timing by level.
]]

local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local MinionConfig = {}

MinionConfig.Types = {
	COBBLESTONE = {
		id = "COBBLESTONE",
		displayName = "Stone Golem",
		placeBlockId = Constants.BlockType.COBBLESTONE,
		mineBlockId = Constants.BlockType.COBBLESTONE,
		-- Per-cell action cooldowns to prevent immediate re-selection
		cellCooldownMinSec = 1.1,
		cellCooldownMaxSec = 1.7,
		-- UI/item hooks
		upgradeItemId = Constants.BlockType.COBBLESTONE,
		pickupItemId = Constants.BlockType.COBBLESTONE_MINION,
		-- Timing
		baseIntervalSec = 15,
		perLevelDeltaSec = -1, -- each level reduces by 1s, min clamped separately
		maxLevel = 4,
		baseSlotsUnlocked = 1,
		getUpgradeCost = function(level)
			if level == 1 then return 32 end
			if level == 2 then return 64 end
			if level == 3 then return 128 end
			return 0
		end,
	},
	DIRT = {
		id = "DIRT",
		displayName = "Earth Golem",
		placeBlockId = Constants.BlockType.DIRT,
		mineBlockId = Constants.BlockType.DIRT,
		cellCooldownMinSec = 1.1,
		cellCooldownMaxSec = 1.7,
		upgradeItemId = Constants.BlockType.DIRT,
		-- Reuse same pickup item until a distinct item exists
		pickupItemId = Constants.BlockType.COBBLESTONE_MINION,
		baseIntervalSec = 15,
		perLevelDeltaSec = -1,
		maxLevel = 4,
		baseSlotsUnlocked = 1,
		getUpgradeCost = function(level)
			if level == 1 then return 32 end
			if level == 2 then return 64 end
			if level == 3 then return 128 end
			return 0
		end,
	},
	COAL = {
		id = "COAL",
		displayName = "Coal Golem",
		placeBlockId = Constants.BlockType.COBBLESTONE,
		mineBlockId = Constants.BlockType.COBBLESTONE,
		bonusPlaceBlockId = Constants.BlockType.COAL_ORE,
		bonusPlaceChance = 0.2, -- 20% chance to place coal ore instead of cobblestone
		bonusMineBlockId = Constants.BlockType.COAL_ORE,
		cellCooldownMinSec = 1.1,
		cellCooldownMaxSec = 1.7,
		upgradeItemId = 32, -- Coal
		pickupItemId = Constants.BlockType.COAL_MINION,
		baseIntervalSec = 15,
		perLevelDeltaSec = -1,
		maxLevel = 4,
		baseSlotsUnlocked = 1,
		getUpgradeCost = function(level)
			if level == 1 then return 32 end
			if level == 2 then return 64 end
			if level == 3 then return 128 end
			return 0
		end,
	},
	COPPER = {
		id = "COPPER",
		displayName = "Copper Golem",
		placeBlockId = Constants.BlockType.COBBLESTONE,
		mineBlockId = Constants.BlockType.COBBLESTONE,
		bonusPlaceBlockId = Constants.BlockType.COPPER_ORE,
		bonusPlaceChance = 0.25, -- 25% chance to place copper ore instead of cobblestone
		bonusMineBlockId = Constants.BlockType.COPPER_ORE,
		cellCooldownMinSec = 1.1,
		cellCooldownMaxSec = 1.7,
		upgradeItemId = Constants.BlockType.COPPER_ORE, -- Upgrade with copper ore
		pickupItemId = Constants.BlockType.COPPER_MINION,
		baseIntervalSec = 15,
		perLevelDeltaSec = -1,
		maxLevel = 4,
		baseSlotsUnlocked = 1,
		getUpgradeCost = function(level)
			if level == 1 then return 16 end  -- Cheaper upgrades for tutorial
			if level == 2 then return 32 end
			if level == 3 then return 64 end
			return 0
		end,
	},
}

function MinionConfig.GetTypeDef(minionType)
	if not minionType or MinionConfig.Types[minionType] == nil then
		return MinionConfig.Types.COBBLESTONE
	end
	return MinionConfig.Types[minionType]
end

function MinionConfig.GetWaitSeconds(minionType, level)
	local def = MinionConfig.GetTypeDef(minionType)
	local lvl = math.max(1, math.min(def.maxLevel or 4, level or 1))
	local base = def.baseIntervalSec or 15
	local delta = def.perLevelDeltaSec or 0
	local value = base + (lvl - 1) * delta
	-- Clamp to sensible floor
	return math.max(3, value)
end

function MinionConfig.GetUpgradeCost(minionType, level)
	local def = MinionConfig.GetTypeDef(minionType)
	if def.getUpgradeCost then
		return def.getUpgradeCost(level)
	end
	return 0
end

function MinionConfig.GetUpgradeItemId(minionType)
	return MinionConfig.GetTypeDef(minionType).upgradeItemId
end

function MinionConfig.GetPickupItemId(minionType)
	return MinionConfig.GetTypeDef(minionType).pickupItemId
end

function MinionConfig.GetPlaceBlockId(minionType)
	return MinionConfig.GetTypeDef(minionType).placeBlockId
end

function MinionConfig.GetMineBlockId(minionType)
	return MinionConfig.GetTypeDef(minionType).mineBlockId
end

-- Compute slots unlocked for a given level (base + 1 per level, clamped)
function MinionConfig.GetSlotsUnlocked(minionType, level)
	local def = MinionConfig.GetTypeDef(minionType)
	local base = def.baseSlotsUnlocked or 1
	local lvl = math.max(1, math.min(def.maxLevel or 4, level or 1))
	local slots = base + (lvl - 1)
	return math.max(1, math.min(12, slots))
end

-- Returns the per-cell cooldown range in seconds (min, max)
function MinionConfig.GetCellCooldownRangeSec(minionType)
	local def = MinionConfig.GetTypeDef(minionType)
	local minV = def.cellCooldownMinSec or 1.1
	local maxV = def.cellCooldownMaxSec or 1.7
	-- Ensure sane ordering and clamps
	if maxV < minV then
		minV, maxV = maxV, minV
	end
	-- Avoid zero/negative
	minV = math.max(0.05, minV)
	maxV = math.max(minV, maxV)
	return minV, maxV
end

return MinionConfig


