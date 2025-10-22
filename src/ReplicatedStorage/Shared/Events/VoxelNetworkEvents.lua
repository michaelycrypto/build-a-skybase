--[[
	VoxelNetworkEvents.lua
	Events and param signatures for voxel networking
]]

--[[
	NOTE: This file is LEGACY and not actively used.
	The actual event definitions are in EventManifest.lua
	This is kept for documentation/reference only.
]]

local VoxelNetworkEvents = {
	AllEvents = {
		-- Client -> Server (see EventManifest.lua for actual implementation)
		-- VoxelRequestBlockPlace = {x,y,z,blockId,hotbarSlot}
		-- PlayerPunch = {x,y,z,dt} - Progressive block breaking
		-- VoxelRequestRenderDistance = {distance}
		-- VoxelRequestInitialChunks = {}

		-- Server -> Client (see EventManifest.lua for actual implementation)
		-- ChunkDataStreamed = {chunk, key}
		-- ChunkUnload = {key}
		-- BlockChanged = {x,y,z,blockId}
		-- BlockChangeRejected = {x,y,z,reason}
		-- BlockBreakProgress = {x,y,z,progress,playerUserId}
		-- BlockBroken = {x,y,z,blockId,playerUserId,canHarvest}
		-- InventorySync = {hotbar, inventory}
		-- HotbarSlotUpdate = {slotIndex, stack}
	}
}

return VoxelNetworkEvents


