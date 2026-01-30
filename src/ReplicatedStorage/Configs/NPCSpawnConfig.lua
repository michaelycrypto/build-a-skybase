--[[
	NPCSpawnConfig.lua
	Defines spawn locations for NPCs in the hub world.
	Positions are in BLOCK coordinates (voxel coordinates).
]]

local NPCSpawnConfig = {}

-- Hub world NPC spawn points (block coordinates)
NPCSpawnConfig.HubSpawns = {
	-- Merchant (sell items) - unchanged
	{
		id = "hub_merchant_1",
		npcType = "MERCHANT",
		blockPosition = Vector3.new(-10, 47, -21),
		rotation = 180,
	},
	-- Warp Master - moved to new location
	{
		id = "hub_warp_master_1",
		npcType = "WARP_MASTER",
		blockPosition = Vector3.new(0, 49, 40),
		rotation = 180,
	},
	-- Farm Shop (seeds, saplings) - at old shop keeper location
	{
		id = "hub_farm_shop_1",
		npcType = "FARM_SHOP",
		blockPosition = Vector3.new(10, 47, -21),
		rotation = 180,
	},
	-- Building Shop (blocks, decorations) - at old warp master location
	{
		id = "hub_building_shop_1",
		npcType = "BUILDING_SHOP",
		blockPosition = Vector3.new(0, 47, -25),
		rotation = 180,
	},
}

-- Get all hub spawn configurations
function NPCSpawnConfig.GetAllHubSpawns()
	return NPCSpawnConfig.HubSpawns
end

return NPCSpawnConfig
