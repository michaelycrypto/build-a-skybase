--[[
	LobbyManager.lua
	Manages the persistent lobby hub where all players spawn
	Lobby is 2-4 chunks, always loaded, blocks are protected
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local FlatTerrainGenerator = require(script.Parent.Parent.Generation.FlatTerrainGenerator)

local LobbyManager = {}
LobbyManager.__index = LobbyManager

-- Lobby configuration
local LOBBY_CONFIG = {
	SIZE_CHUNKS = 4, -- 4×4 chunks lobby
	CENTER_CHUNK_X = 0, -- Center at world origin
	CENTER_CHUNK_Z = 0,
	PROTECTED = true, -- Blocks cannot be broken/placed
	SPAWN_HEIGHT_OFFSET = 2 -- Spawn 2 blocks above grass
}

function LobbyManager.new()
	local self = setmetatable({
		chunks = {}, -- Map of chunkKey -> Chunk
		generator = FlatTerrainGenerator.new(12345), -- Fixed seed for lobby
		isLoaded = false,
		spawnPosition = Vector3.new(0, 0, 0),
		players = {} -- Set of players currently in lobby
	}, LobbyManager)

	return self
end

-- Load lobby (generate chunks)
function LobbyManager:Load()
	if self.isLoaded then
		return
	end

	local Chunk = require(script.Parent.Chunk)

	-- Generate lobby chunks centered around origin
	local halfSize = math.floor(LOBBY_CONFIG.SIZE_CHUNKS / 2)

	for x = -halfSize, halfSize - 1 do
		for z = -halfSize, halfSize - 1 do
			local chunk = Chunk.new(x + LOBBY_CONFIG.CENTER_CHUNK_X, z + LOBBY_CONFIG.CENTER_CHUNK_Z)
			self.generator:GenerateChunk(chunk)

			-- Mark as protected
			chunk.isProtected = LOBBY_CONFIG.PROTECTED

			local key = string.format("%d,%d", chunk.x, chunk.z)
			self.chunks[key] = chunk
		end
	end

	-- Calculate spawn position (center of lobby at grass level)
	local grassLevel = self.generator:GetGrassLevel()
	self.spawnPosition = Vector3.new(
		LOBBY_CONFIG.CENTER_CHUNK_X * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE,
		(grassLevel + LOBBY_CONFIG.SPAWN_HEIGHT_OFFSET) * Constants.BLOCK_SIZE,
		LOBBY_CONFIG.CENTER_CHUNK_Z * Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE
	)

	self.isLoaded = true
	print("LobbyManager: Loaded lobby with", LOBBY_CONFIG.SIZE_CHUNKS * LOBBY_CONFIG.SIZE_CHUNKS, "chunks")
end

-- Get chunk by coordinates
function LobbyManager:GetChunk(x: number, z: number)
	local key = string.format("%d,%d", math.floor(x), math.floor(z))
	return self.chunks[key]
end

-- Check if position is in lobby bounds
function LobbyManager:IsInLobby(x: number, z: number): boolean
	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)

	local halfSize = math.floor(LOBBY_CONFIG.SIZE_CHUNKS / 2)
	local minChunk = -halfSize + LOBBY_CONFIG.CENTER_CHUNK_X
	local maxChunk = halfSize - 1 + LOBBY_CONFIG.CENTER_CHUNK_X

	return chunkX >= minChunk and chunkX <= maxChunk and
	       chunkZ >= minChunk and chunkZ <= maxChunk
end

-- Check if block position is in lobby
function LobbyManager:IsBlockInLobby(blockX: number, blockZ: number): boolean
	return self:IsInLobby(blockX, blockZ)
end

-- Get block at world coordinates
function LobbyManager:GetBlock(x: number, y: number, z: number): number
	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return Constants.BlockType.AIR
	end

	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk then
		return Constants.BlockType.AIR
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	return chunk:getBlock(localX, y, localZ)
end

-- Set block (only if not protected)
function LobbyManager:SetBlock(x: number, y: number, z: number, blockId: number): boolean
	if LOBBY_CONFIG.PROTECTED then
		return false -- Lobby is protected
	end

	if y < 0 or y >= Constants.WORLD_HEIGHT then
		return false
	end

	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local chunk = self:GetChunk(chunkX, chunkZ)

	if not chunk or chunk.isProtected then
		return false
	end

	local localX = x - chunkX * Constants.CHUNK_SIZE_X
	local localZ = z - chunkZ * Constants.CHUNK_SIZE_Z

	chunk:setBlock(localX, y, localZ, blockId)
	return true
end

-- Get spawn position
function LobbyManager:GetSpawnPosition(): Vector3
	return self.spawnPosition
end

-- Add player to lobby
function LobbyManager:AddPlayer(player: Player)
	if not player then return end
	self.players[player] = true
end

-- Remove player from lobby
function LobbyManager:RemovePlayer(player: Player)
	if not player then return end
	self.players[player] = nil
end

-- Get player count in lobby
function LobbyManager:GetPlayerCount(): number
	local count = 0
	for _ in pairs(self.players) do
		count += 1
	end
	return count
end

-- Get all chunks (for rendering/streaming)
function LobbyManager:GetAllChunks(): table
	return self.chunks
end

-- Check if chunk is in lobby
function LobbyManager:IsLobbyChunk(chunkX: number, chunkZ: number): boolean
	local halfSize = math.floor(LOBBY_CONFIG.SIZE_CHUNKS / 2)
	local minChunk = -halfSize + LOBBY_CONFIG.CENTER_CHUNK_X
	local maxChunk = halfSize - 1 + LOBBY_CONFIG.CENTER_CHUNK_X

	return chunkX >= minChunk and chunkX <= maxChunk and
	       chunkZ >= minChunk and chunkZ <= maxChunk
end

-- Get lobby bounds (in world coordinates)
function LobbyManager:GetBounds(): (Vector3, Vector3)
	local halfSize = math.floor(LOBBY_CONFIG.SIZE_CHUNKS / 2)

	local minX = (-halfSize + LOBBY_CONFIG.CENTER_CHUNK_X) * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
	local minZ = (-halfSize + LOBBY_CONFIG.CENTER_CHUNK_Z) * Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE

	local maxX = (halfSize + LOBBY_CONFIG.CENTER_CHUNK_X) * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
	local maxZ = (halfSize + LOBBY_CONFIG.CENTER_CHUNK_Z) * Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE

	return Vector3.new(minX, 0, minZ), Vector3.new(maxX, Constants.WORLD_HEIGHT * Constants.BLOCK_SIZE, maxZ)
end

-- Clean up
function LobbyManager:Destroy()
	self.chunks = {}
	self.players = {}
end

return LobbyManager

