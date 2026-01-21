--[[
	NPCSpawnConfig.lua
	Defines spawn locations for NPCs in the hub world.
	Positions are in BLOCK coordinates (voxel coordinates).
]]

local NPCSpawnConfig = {}

-- Hub world NPC spawn points (block coordinates)
NPCSpawnConfig.HubSpawns = {
	{
		id = "hub_merchant_1",
		npcType = "MERCHANT",
		blockPosition = Vector3.new(-10, 47, -21),
		rotation = 180,
	},
	{
		id = "hub_warp_master_1",
		npcType = "WARP_MASTER",
		blockPosition = Vector3.new(0, 47, -25),
		rotation = 180,
	},
	{
		id = "hub_shop_keeper_1",
		npcType = "SHOP_KEEPER",
		blockPosition = Vector3.new(10, 47, -21),
		rotation = 180,
	},
}

-- Get all hub spawn configurations
function NPCSpawnConfig.GetAllHubSpawns()
	return NPCSpawnConfig.HubSpawns
end

return NPCSpawnConfig
