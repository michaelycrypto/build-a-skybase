--[[
	VoxelWorld.lua
	Main entry point for the voxel world system.

	API:
	- CreateWorld(seed: number, renderDistance: number): WorldHandle
	- CreateClientView(renderDistance: number): WorldHandle
]]

local VoxelWorld = {}

-- Import core modules
local WorldManager = require(script.World.WorldManager)
local ChunkManager = require(script.World.ChunkManager)
local _BlockRegistry = require(script.World.BlockRegistry)
local _Constants = require(script.Core.Constants)
local _Config = require(script.Core.Config)

export type WorldHandle = {
	GetWorldManager: () -> WorldManager.WorldManager,
	Update: (number, number) -> (),
	Destroy: () -> ()
}

--[[
	Creates a new world instance (server-side)
	@param seed number - World generation seed
	@param renderDistance number - Chunk render distance
	@return WorldHandle
]]
function VoxelWorld.CreateWorld(seed: number, renderDistance: number, worldTypeId: string?): WorldHandle
	local worldManager = WorldManager.new(seed, worldTypeId)
	local chunkManager = ChunkManager.new(worldManager, renderDistance)

	local handle = {
		worldManager = worldManager,
		chunkManager = chunkManager
	}

	function handle:GetWorldManager()
		return self.worldManager
	end

	function handle:Update(x: number, z: number)
		self.chunkManager:Update(x, z)
	end

	function handle:Destroy()
		self.chunkManager:Destroy()
		self.worldManager:Destroy()
	end

	return handle
end

--[[
	Creates a client-side view of the world
	@param renderDistance number - Chunk render distance
	@return WorldHandle
]]
function VoxelWorld.CreateClientView(renderDistance: number, worldTypeId: string?): WorldHandle
	local worldManager = WorldManager.new(0, worldTypeId) -- Seed not used on client
	local chunkManager = ChunkManager.new(worldManager, renderDistance)

    -- Client should never locally generate chunks; only deserialize server-streamed data
    worldManager.generator = nil

	local handle = {
		worldManager = worldManager,
		chunkManager = chunkManager
	}

	function handle:GetWorldManager()
		return self.worldManager
	end

	function handle:Update(x: number, z: number)
		self.chunkManager:Update(x, z)
	end

	function handle:Destroy()
		self.chunkManager:Destroy()
		self.worldManager:Destroy()
	end

	return handle
end

return VoxelWorld