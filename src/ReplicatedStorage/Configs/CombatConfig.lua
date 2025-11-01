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

CombatConfig.SWING_COOLDOWN = 0.35
CombatConfig.REACH_STUDS = 10
CombatConfig.FOV_DEGREES = 60
CombatConfig.KNOCKBACK_STRENGTH = 5 -- optional, server-applied
CombatConfig.HAND_DAMAGE = 2 -- 1 heart for empty hand / non-weapon

return CombatConfig


