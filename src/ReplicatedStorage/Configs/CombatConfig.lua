--[[
	CombatConfig.lua
	Shared PvP tuning constants
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local CombatConfig = {}

CombatConfig.SWORD_DAMAGE_BY_TIER = {
	[BlockProperties.ToolTier.WOOD] = 4,   -- 2 hearts
	[BlockProperties.ToolTier.STONE] = 5,  -- 2.5 hearts
	[BlockProperties.ToolTier.IRON] = 6,   -- 3 hearts
	[BlockProperties.ToolTier.DIAMOND] = 7 -- 3.5 hearts
}

-- Additional tool damage (Minecraft-like ordering; swords best burst, axes comparable)
CombatConfig.AXE_DAMAGE_BY_TIER = {
    [BlockProperties.ToolTier.WOOD] = 4,
    [BlockProperties.ToolTier.STONE] = 5,
    [BlockProperties.ToolTier.IRON] = 6,
    [BlockProperties.ToolTier.DIAMOND] = 7
}

CombatConfig.PICKAXE_DAMAGE_BY_TIER = {
    [BlockProperties.ToolTier.WOOD] = 3,
    [BlockProperties.ToolTier.STONE] = 4,
    [BlockProperties.ToolTier.IRON] = 5,
    [BlockProperties.ToolTier.DIAMOND] = 6
}

CombatConfig.SHOVEL_DAMAGE_BY_TIER = {
    [BlockProperties.ToolTier.WOOD] = 2,
    [BlockProperties.ToolTier.STONE] = 3,
    [BlockProperties.ToolTier.IRON] = 4,
    [BlockProperties.ToolTier.DIAMOND] = 5
}

CombatConfig.SWING_COOLDOWN = 0.35
CombatConfig.REACH_STUDS = 10
CombatConfig.FOV_DEGREES = 60
CombatConfig.KNOCKBACK_STRENGTH = 5 -- optional, server-applied
CombatConfig.HAND_DAMAGE = 2 -- 1 heart for empty hand / non-weapon

-- Combat tag + visual highlight settings
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

return CombatConfig


