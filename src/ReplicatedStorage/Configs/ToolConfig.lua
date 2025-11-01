--[[
	ToolConfig.lua
	Basic Minecraft-style tool definitions without durability.
	Provides helpers to map itemIds to BlockProperties tool type/tier.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local ToolConfig = {}

-- Reserve itemId range ≥ 1001 for tools to avoid block ID collision (0-29 used by blocks)
ToolConfig.Items = {
	-- Pickaxes
	[1001] = {name = "Wood Pickaxe",     icon = "⛏️", image = "rbxassetid://121308304464747", toolType = BlockProperties.ToolType.PICKAXE, tier = BlockProperties.ToolTier.WOOD},
	[1002] = {name = "Stone Pickaxe",    icon = "⛏️", image = "rbxassetid://109725505547962", toolType = BlockProperties.ToolType.PICKAXE, tier = BlockProperties.ToolTier.STONE},
	[1003] = {name = "Iron Pickaxe",     icon = "⛏️", image = "rbxassetid://91977238449226", toolType = BlockProperties.ToolType.PICKAXE, tier = BlockProperties.ToolTier.IRON},
	[1004] = {name = "Diamond Pickaxe",  icon = "⛏️", image = "rbxassetid://126350747925266", toolType = BlockProperties.ToolType.PICKAXE, tier = BlockProperties.ToolTier.DIAMOND},

	-- Axes
	[1011] = {name = "Wood Axe",         icon = "🪓", image = "rbxassetid://105650152333670", toolType = BlockProperties.ToolType.AXE, tier = BlockProperties.ToolTier.WOOD},
	[1012] = {name = "Stone Axe",        icon = "🪓", image = "rbxassetid://82378756513596", toolType = BlockProperties.ToolType.AXE, tier = BlockProperties.ToolTier.STONE},
	[1013] = {name = "Iron Axe",         icon = "🪓", image = "rbxassetid://100343121836924", toolType = BlockProperties.ToolType.AXE, tier = BlockProperties.ToolTier.IRON},
	[1014] = {name = "Diamond Axe",      icon = "🪓", image = "rbxassetid://127284013511937", toolType = BlockProperties.ToolType.AXE, tier = BlockProperties.ToolTier.DIAMOND},

	-- Shovels
	[1021] = {name = "Wood Shovel",      icon = "🛠️", image = "rbxassetid://87371798799110", toolType = BlockProperties.ToolType.SHOVEL, tier = BlockProperties.ToolTier.WOOD},
	[1022] = {name = "Stone Shovel",     icon = "🛠️", image = "rbxassetid://97804687989430", toolType = BlockProperties.ToolType.SHOVEL, tier = BlockProperties.ToolTier.STONE},
	[1023] = {name = "Iron Shovel",      icon = "🛠️", image = "rbxassetid://98887488838388", toolType = BlockProperties.ToolType.SHOVEL, tier = BlockProperties.ToolTier.IRON},
	[1024] = {name = "Diamond Shovel",   icon = "🛠️", image = "rbxassetid://82030710320351", toolType = BlockProperties.ToolType.SHOVEL, tier = BlockProperties.ToolTier.DIAMOND},

	-- Swords
	[1041] = {name = "Wood Sword",       icon = "🗡️", image = "rbxassetid://74762524011845", toolType = BlockProperties.ToolType.SWORD, tier = BlockProperties.ToolTier.WOOD},
	[1042] = {name = "Stone Sword",      icon = "🗡️", image = "rbxassetid://80451498258502", toolType = BlockProperties.ToolType.SWORD, tier = BlockProperties.ToolTier.STONE},
	[1043] = {name = "Iron Sword",       icon = "🗡️", image = "rbxassetid://80622149476148", toolType = BlockProperties.ToolType.SWORD, tier = BlockProperties.ToolTier.IRON},
	[1044] = {name = "Diamond Sword",    icon = "🗡️", image = "rbxassetid://130094269547476", toolType = BlockProperties.ToolType.SWORD, tier = BlockProperties.ToolTier.DIAMOND},
}

function ToolConfig.IsTool(itemId)
	return ToolConfig.Items[itemId] ~= nil
end

function ToolConfig.GetToolInfo(itemId)
	return ToolConfig.Items[itemId]
end

-- Returns toolType (string) and toolTier (number) for BlockProperties
function ToolConfig.GetBlockProps(itemId)
	local def = ToolConfig.Items[itemId]
	if not def then
		return BlockProperties.ToolType.NONE, BlockProperties.ToolTier.NONE
	end
	return def.toolType, def.tier
end

return ToolConfig


