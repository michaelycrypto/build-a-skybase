--[[
	ArmorConfig.lua
	Armor configuration - reads from ItemDefinitions.lua

	This file provides the API that other systems use.
	All armor data is defined in ItemDefinitions.lua
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)

local ArmorConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONSTANTS & ENUMS
-- ═══════════════════════════════════════════════════════════════════════════

ArmorConfig.ArmorSlot = {
	HELMET = "helmet",
	CHESTPLATE = "chestplate",
	LEGGINGS = "leggings",
	BOOTS = "boots"
}

-- Mirror tier system from ItemDefinitions
ArmorConfig.ArmorTier = ItemDefinitions.Tiers
ArmorConfig.TierNames = ItemDefinitions.TierNames
ArmorConfig.TierColors = ItemDefinitions.TierColors

-- Slot icons
local SLOT_ICONS = {
	helmet = "🪖",
	chestplate = "🦺",
	leggings = "👖",
	boots = "👢",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DEFENSE VALUES
-- ═══════════════════════════════════════════════════════════════════════════

ArmorConfig.TierDefense = {
	[1] = { helmet = 1, chestplate = 2, leggings = 2, boots = 1, total = 6 },
	[2] = { helmet = 2, chestplate = 4, leggings = 3, boots = 1, total = 10 },
	[3] = { helmet = 2, chestplate = 5, leggings = 4, boots = 2, total = 13 },
	[4] = { helmet = 3, chestplate = 6, leggings = 5, boots = 2, total = 16 },
}

ArmorConfig.TierToughness = {
	[1] = 0, [2] = 0, [3] = 0, [4] = 1,
}

ArmorConfig.TierKnockbackResist = {
	[1] = 0, [2] = 0, [3] = 0, [4] = 0.05,
}

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD ITEMS TABLE FROM ItemDefinitions
-- ═══════════════════════════════════════════════════════════════════════════

ArmorConfig.Items = {}

for _, armor in pairs(ItemDefinitions.Armor) do
	ArmorConfig.Items[armor.id] = {
		name = armor.name,
		icon = SLOT_ICONS[armor.slot] or "🛡️",
		image = armor.texture,
		slot = armor.slot,
		tier = armor.tier,
		defense = armor.defense,
		toughness = armor.toughness,
		setId = armor.setId,
	}
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SET BONUSES
-- ═══════════════════════════════════════════════════════════════════════════

ArmorConfig.SetBonuses = {
	copper = {
		name = "Copper Set",
		description = "Starter protection"
	},
	iron = {
		name = "Iron Set",
		description = "+5% mining speed",
		miningBonus = 0.05
	},
	steel = {
		name = "Steel Set",
		description = "+10% mining speed",
		miningBonus = 0.10
	},
	bluesteel = {
		name = "Bluesteel Set",
		description = "Lightweight: +5% movement speed, +10% melee damage",
		speedBonus = 0.05,
		meleeBonus = 0.10
	},
}

-- ═══════════════════════════════════════════════════════════════════════════
-- API FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorConfig.IsArmor(itemId)
	return ArmorConfig.Items[itemId] ~= nil
end

function ArmorConfig.GetArmorInfo(itemId)
	return ArmorConfig.Items[itemId]
end

function ArmorConfig.GetArmorBySlotAndTier(slot, tier)
	for itemId, armor in pairs(ArmorConfig.Items) do
		if armor.slot == slot and armor.tier == tier then
			return itemId, armor
		end
	end
	return nil, nil
end

function ArmorConfig.GetSetPieces(setId)
	local pieces = {}
	for itemId, armor in pairs(ArmorConfig.Items) do
		if armor.setId == setId then
			pieces[armor.slot] = {itemId = itemId, armor = armor}
		end
	end
	return pieces
end

function ArmorConfig.GetArmorByTier(tier)
	local items = {}
	for itemId, armor in pairs(ArmorConfig.Items) do
		if armor.tier == tier then
			table.insert(items, itemId)
		end
	end
	return items
end

function ArmorConfig.CalculateTotalDefense(equippedArmor)
	local totalDefense = 0
	local totalToughness = 0

	for _, itemId in pairs(equippedArmor) do
		local armor = ArmorConfig.Items[itemId]
		if armor then
			totalDefense = totalDefense + (armor.defense or 0)
			totalToughness = totalToughness + (armor.toughness or 0)
		end
	end

	return totalDefense, totalToughness
end

function ArmorConfig.HasFullSet(equippedArmor)
	if not equippedArmor then return false, nil end

	local slots = {
		ArmorConfig.ArmorSlot.HELMET,
		ArmorConfig.ArmorSlot.CHESTPLATE,
		ArmorConfig.ArmorSlot.LEGGINGS,
		ArmorConfig.ArmorSlot.BOOTS
	}

	local setId = nil
	for _, slot in ipairs(slots) do
		local itemId = equippedArmor[slot]
		if not itemId then return false, nil end

		local armor = ArmorConfig.Items[itemId]
		if not armor then return false, nil end

		if setId == nil then
			setId = armor.setId
		elseif armor.setId ~= setId then
			return false, nil
		end
	end

	return true, setId
end

function ArmorConfig.CalculateDamageReduction(damage, defense, toughness)
	toughness = toughness or 0
	local defensePoints = math.min(20,
		math.max(defense / 5, defense - (4 * damage / (toughness + 8)))
	)
	local reduction = defensePoints / 25
	local finalDamage = damage * (1 - reduction)
	return math.max(0, finalDamage)
end

function ArmorConfig.GetTierName(tier)
	return ArmorConfig.TierNames[tier] or "Unknown"
end

function ArmorConfig.GetTierColor(tier)
	return ArmorConfig.TierColors[tier] or Color3.fromRGB(150, 150, 150)
end

function ArmorConfig.GetAllArmorIds()
	local ids = {}
	for itemId, _ in pairs(ArmorConfig.Items) do
		table.insert(ids, itemId)
	end
	return ids
end

return ArmorConfig
