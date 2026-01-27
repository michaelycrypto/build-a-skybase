--[[
	CombatConfig.lua
	Shared PvP tuning constants with 4-tier weapon progression
	Progression: Copper → Iron → Steel → Bluesteel
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local CombatConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- WEAPON DAMAGE BY TIER (4-tier progression)
-- Damage scales from Copper (lowest) to Bluesteel (highest)
-- ═══════════════════════════════════════════════════════════════════════════

-- Swords: Primary melee weapons, highest burst damage
CombatConfig.SWORD_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.COPPER] = 4,      -- 2 hearts
	[BlockProperties.ToolTier.IRON] = 6,        -- 3 hearts
	[BlockProperties.ToolTier.STEEL] = 8,       -- 4 hearts
	[BlockProperties.ToolTier.BLUESTEEL] = 10,  -- 5 hearts
}

-- Axes: Strong melee, comparable to swords
CombatConfig.AXE_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.COPPER] = 4,
	[BlockProperties.ToolTier.IRON] = 6,
	[BlockProperties.ToolTier.STEEL] = 8,
	[BlockProperties.ToolTier.BLUESTEEL] = 10,
}

-- Pickaxes: Medium melee damage
CombatConfig.PICKAXE_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.COPPER] = 3,
	[BlockProperties.ToolTier.IRON] = 5,
	[BlockProperties.ToolTier.STEEL] = 7,
	[BlockProperties.ToolTier.BLUESTEEL] = 9,
}

-- Shovels: Lower melee damage
CombatConfig.SHOVEL_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.COPPER] = 2,
	[BlockProperties.ToolTier.IRON] = 4,
	[BlockProperties.ToolTier.STEEL] = 6,
	[BlockProperties.ToolTier.BLUESTEEL] = 8,
}

-- Arrows: Ranged damage (bow adds base damage)
CombatConfig.ARROW_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.COPPER] = 4,
	[BlockProperties.ToolTier.IRON] = 6,
	[BlockProperties.ToolTier.STEEL] = 8,
	[BlockProperties.ToolTier.BLUESTEEL] = 10,
}

CombatConfig.BOW_BASE_DAMAGE = 2  -- Added to arrow damage

-- ═══════════════════════════════════════════════════════════════════════════
-- COMBAT MECHANICS
-- ═══════════════════════════════════════════════════════════════════════════

CombatConfig.SWING_COOLDOWN = 0.35
CombatConfig.REACH_STUDS = 10
CombatConfig.FOV_DEGREES = 60
CombatConfig.KNOCKBACK_STRENGTH = 5 -- optional, server-applied
CombatConfig.HAND_DAMAGE = 2 -- 1 heart for empty hand / non-weapon

-- ═══════════════════════════════════════════════════════════════════════════
-- COMBAT TAG & VISUAL EFFECTS
-- ═══════════════════════════════════════════════════════════════════════════

CombatConfig.COMBAT_TTL_SECONDS = 8
CombatConfig.FLASH_DURATION_SEC = 0.06
CombatConfig.FLASH_FADE_BACK_SEC = 0.2

-- Default highlight appearance
-- Default: combat-tagged characters appear red
CombatConfig.HIGHLIGHT_DEFAULT_FILL_COLOR = Color3.fromRGB(255, 0, 0)
CombatConfig.HIGHLIGHT_DEFAULT_OUTLINE_COLOR = Color3.fromRGB(255, 0, 0)
-- Hit flash color
CombatConfig.HIGHLIGHT_FLASH_WHITE = Color3.fromRGB(255, 255, 255)
-- Very opaque red tint while in combat (lower = more opaque)
CombatConfig.HIGHLIGHT_DEFAULT_FILL_TRANSPARENCY = 0.8
CombatConfig.HIGHLIGHT_DEFAULT_OUTLINE_TRANSPARENCY = 0
-- Stronger fill during flash (even more opaque)
CombatConfig.HIGHLIGHT_FLASH_FILL_TRANSPARENCY = 0.4

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Compute melee damage from tool type/tier (server-authoritative)
function CombatConfig.GetMeleeDamage(toolType, toolTier)
    local tier = toolTier or BlockProperties.ToolTier.NONE
    if toolType == BlockProperties.ToolType.SWORD then
        return (CombatConfig.SWORD_DAMAGE_BY_TIER and CombatConfig.SWORD_DAMAGE_BY_TIER[tier]) or CombatConfig.HAND_DAMAGE
    elseif toolType == BlockProperties.ToolType.AXE then
        return (CombatConfig.AXE_DAMAGE_BY_TIER and CombatConfig.AXE_DAMAGE_BY_TIER[tier]) or CombatConfig.HAND_DAMAGE
    elseif toolType == BlockProperties.ToolType.PICKAXE then
        return (CombatConfig.PICKAXE_DAMAGE_BY_TIER and CombatConfig.PICKAXE_DAMAGE_BY_TIER[tier]) or CombatConfig.HAND_DAMAGE
    elseif toolType == BlockProperties.ToolType.SHOVEL then
        return (CombatConfig.SHOVEL_DAMAGE_BY_TIER and CombatConfig.SHOVEL_DAMAGE_BY_TIER[tier]) or CombatConfig.HAND_DAMAGE
    end
    return CombatConfig.HAND_DAMAGE
end

-- Get damage for a specific weapon type and tier
function CombatConfig.GetWeaponDamage(weaponType, tier)
    local damageTable = nil
    if weaponType == "sword" then
        damageTable = CombatConfig.SWORD_DAMAGE_BY_TIER
    elseif weaponType == "axe" then
        damageTable = CombatConfig.AXE_DAMAGE_BY_TIER
    elseif weaponType == "pickaxe" then
        damageTable = CombatConfig.PICKAXE_DAMAGE_BY_TIER
    elseif weaponType == "shovel" then
        damageTable = CombatConfig.SHOVEL_DAMAGE_BY_TIER
    end

    if damageTable and tier then
        return damageTable[tier] or CombatConfig.HAND_DAMAGE
    end
    return CombatConfig.HAND_DAMAGE
end

-- Get arrow damage by tier (bow adds BOW_BASE_DAMAGE)
function CombatConfig.GetArrowDamage(arrowTier)
    local baseDamage = CombatConfig.ARROW_DAMAGE_BY_TIER[arrowTier] or 4
    return baseDamage + CombatConfig.BOW_BASE_DAMAGE
end

return CombatConfig
