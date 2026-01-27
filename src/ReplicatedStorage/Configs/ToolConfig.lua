--[[
	ToolConfig.lua
	Tool configuration - reads from ItemDefinitions.lua

	Handles: Tools, Weapons, Ranged, Arrows
	For mining speed calculations and combat.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local ToolConfig = {}

-- Tool type icons
local ICONS = {
	pickaxe = "⛏️",
	axe = "🪓",
	shovel = "🛠️",
	sword = "🗡️",
	bow = "🏹",
	arrow = "🏹",
}

-- ═══════════════════════════════════════════════════════════════════════════
-- BUILD ITEMS TABLE FROM ItemDefinitions
-- ═══════════════════════════════════════════════════════════════════════════

ToolConfig.Items = {}

-- Add Tools (mining)
for key, tool in pairs(ItemDefinitions.Tools) do
	ToolConfig.Items[tool.id] = {
		name = tool.name,
		icon = ICONS[tool.toolType] or "🔧",
		image = tool.texture,
		toolType = BlockProperties.ToolType[tool.toolType:upper()] or tool.toolType,
		category = tool.category,
		tier = tool.tier,
	}
end

-- Add Weapons (swords)
for key, weapon in pairs(ItemDefinitions.Weapons) do
	ToolConfig.Items[weapon.id] = {
		name = weapon.name,
		icon = ICONS[weapon.weaponType] or "🗡️",
		image = weapon.texture,
		toolType = weapon.weaponType,
		category = weapon.category,
		tier = weapon.tier,
	}
end

-- Add Ranged (bow)
for key, ranged in pairs(ItemDefinitions.Ranged) do
	ToolConfig.Items[ranged.id] = {
		name = ranged.name,
		icon = ICONS.bow,
		image = ranged.texture,
		toolType = "bow",
		category = ranged.category,
		tier = ranged.tier,
	}
end

-- Add Arrows
for key, arrow in pairs(ItemDefinitions.Arrows) do
	ToolConfig.Items[arrow.id] = {
		name = arrow.name,
		icon = ICONS.arrow,
		image = arrow.texture,
		toolType = "arrow",
		category = arrow.category,
		tier = arrow.tier,
	}
end

-- Add Utility Tools (shears, fishing rod, etc.)
if ItemDefinitions.UtilityTools then
	for key, tool in pairs(ItemDefinitions.UtilityTools) do
		ToolConfig.Items[tool.id] = {
			name = tool.name,
			icon = "🔧",
			image = tool.texture,
			toolType = tool.toolType,
			category = tool.category,
			tier = tool.tier or 0,
		}
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TIER CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

-- Tier colors from ItemDefinitions
ToolConfig.TierColors = {}
for tier, color in pairs(ItemDefinitions.TierColors) do
	local tierKey = ItemDefinitions.TierNames[tier]
	if tierKey and BlockProperties.ToolTier[tierKey:upper()] then
		ToolConfig.TierColors[BlockProperties.ToolTier[tierKey:upper()]] = color
	end
end

-- Tier names
ToolConfig.TierNames = {}
for tier, name in pairs(ItemDefinitions.TierNames) do
	local tierKey = name:upper()
	if BlockProperties.ToolTier[tierKey] then
		ToolConfig.TierNames[BlockProperties.ToolTier[tierKey]] = name
	end
end
ToolConfig.TierNames[BlockProperties.ToolTier.NONE] = "None"

-- ═══════════════════════════════════════════════════════════════════════════
-- API FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

function ToolConfig.IsTool(itemId)
	return ToolConfig.Items[itemId] ~= nil
end

function ToolConfig.GetToolInfo(itemId)
	return ToolConfig.Items[itemId]
end

function ToolConfig.GetBlockProps(itemId)
	local def = ToolConfig.Items[itemId]
	if not def then
		return BlockProperties.ToolType.NONE, BlockProperties.ToolTier.NONE
	end
	return def.toolType, def.tier
end

function ToolConfig.GetTierColor(tier)
	return ToolConfig.TierColors[tier] or Color3.fromRGB(150, 150, 150)
end

function ToolConfig.GetTierName(tier)
	return ToolConfig.TierNames[tier] or "Unknown"
end

function ToolConfig.GetToolsByType(toolType)
	local tools = {}
	for itemId, tool in pairs(ToolConfig.Items) do
		if tool.toolType == toolType then
			tools[itemId] = tool
		end
	end
	return tools
end

function ToolConfig.GetToolsByTier(tier)
	local tools = {}
	for itemId, tool in pairs(ToolConfig.Items) do
		if tool.tier == tier then
			tools[itemId] = tool
		end
	end
	return tools
end

function ToolConfig.GetToolsByCategory(category)
	local tools = {}
	for itemId, tool in pairs(ToolConfig.Items) do
		if tool.category == category then
			tools[itemId] = tool
		end
	end
	return tools
end

return ToolConfig
