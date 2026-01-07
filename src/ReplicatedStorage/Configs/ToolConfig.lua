--[[
	ToolConfig.lua
	Tool configuration - reads from ItemDefinitions.lua

	This file provides the API that other systems use.
	All tool data is defined in ItemDefinitions.lua
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local ToolConfig = {}

-- Tool type icons
local TOOL_ICONS = {
	pickaxe = "⛏️",
	axe = "🪓",
	shovel = "🛠️",
	sword = "🗡️",
	bow = "🏹",
	arrow = "🏹",
}

-- Build Items table from ItemDefinitions
ToolConfig.Items = {}

for key, tool in pairs(ItemDefinitions.Tools) do
	ToolConfig.Items[tool.id] = {
		name = tool.name,
		icon = TOOL_ICONS[tool.toolType] or "🔧",
		image = tool.texture,
		toolType = BlockProperties.ToolType[tool.toolType:upper()] or tool.toolType,
		tier = tool.tier,
	}
end

-- Tier colors from ItemDefinitions
ToolConfig.TierColors = {}
for tier, color in pairs(ItemDefinitions.TierColors) do
	-- Map tier number to BlockProperties.ToolTier
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

return ToolConfig
