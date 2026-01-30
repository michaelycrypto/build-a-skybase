--[[
	NPCConfig.lua
	Defines NPC types and their attributes.
	NPCs are static entities in the hub world that provide services to players.
]]

local NPCConfig = {}

-- NPC type definitions
NPCConfig.Types = {
	-- Old general shop keeper (deprecated, use FARM_SHOP or BUILDING_SHOP)
	SHOP_KEEPER = {
		id = "SHOP_KEEPER",
		displayName = "Shop Keeper",
		description = "Buy items and tools",
		interactionType = "SHOP",
		shopFilter = nil, -- Shows all items
		nameTagColor = Color3.fromRGB(50, 200, 50), -- Green
	},
	-- Farm shop - seeds, saplings, farming supplies
	FARM_SHOP = {
		id = "FARM_SHOP",
		displayName = "Farmer",
		description = "Seeds & Saplings",
		interactionType = "SHOP",
		shopFilter = "FARM", -- Only farm items
		nameTagColor = Color3.fromRGB(120, 200, 80), -- Light green
	},
	-- Building shop - blocks, decorations, building materials
	BUILDING_SHOP = {
		id = "BUILDING_SHOP",
		displayName = "Builder",
		description = "Blocks & Materials",
		interactionType = "SHOP",
		shopFilter = "BUILDING", -- Only building items
		nameTagColor = Color3.fromRGB(80, 160, 220), -- Sky blue
	},
	MERCHANT = {
		id = "MERCHANT",
		displayName = "Merchant",
		description = "Sell your items for coins",
		interactionType = "SELL",
		nameTagColor = Color3.fromRGB(255, 200, 50), -- Gold
	},
	WARP_MASTER = {
		id = "WARP_MASTER",
		displayName = "Warp Master",
		description = "Travel to different locations",
		interactionType = "WARP",
		nameTagColor = Color3.fromRGB(150, 100, 255), -- Purple
	}
}

-- Interaction radius in studs
NPCConfig.INTERACTION_RADIUS = 10

-- Get NPC type definition by type ID
function NPCConfig.GetNPCTypeDef(npcType)
	return NPCConfig.Types[npcType]
end

return NPCConfig
