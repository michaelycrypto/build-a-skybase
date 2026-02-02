--[[
	WorldDataStore.lua
	Handles DataStore operations for player-owned worlds
	Stores world metadata, chunks, and permissions
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local _HttpService = game:GetService("HttpService")

local WorldDataStore = {}
WorldDataStore.__index = WorldDataStore

-- DataStore keys
local WORLDS_STORE_NAME = "PlayerWorlds_v1"
local PERMISSIONS_STORE_NAME = "WorldPermissions_v1"
local PLAYER_WORLDS_STORE_NAME = "PlayerWorldsList_v1"

function WorldDataStore.new()
	local self = setmetatable({
		worldsStore = nil,
		permissionsStore = nil,
		playerWorldsStore = nil,
		saveQueue = {},
		isServer = RunService:IsServer()
	}, WorldDataStore)

	-- Initialize DataStores (server only)
	if self.isServer then
		self.worldsStore = DataStoreService:GetDataStore(WORLDS_STORE_NAME)
		self.permissionsStore = DataStoreService:GetDataStore(PERMISSIONS_STORE_NAME)
		self.playerWorldsStore = DataStoreService:GetDataStore(PLAYER_WORLDS_STORE_NAME)
	end

	return self
end

-- Save world data
function WorldDataStore:SaveWorld(worldId: string, data: table): boolean
	if not self.isServer or not self.worldsStore then
		return false
	end

	if not worldId or not data then
		warn("WorldDataStore: Invalid world data")
		return false
	end

	-- Prepare data for saving
	local saveData = {
		metadata = data.metadata,
		chunks = {}, -- Compressed chunk data
		savedAt = os.time()
	}

	-- Compress chunks
	if data.chunks then
		for key, chunkData in pairs(data.chunks) do
			-- Store only non-empty chunks
			if chunkData and next(chunkData) then
				saveData.chunks[key] = chunkData
			end
		end
	end

	-- Save to DataStore
	local success, err = pcall(function()
		self.worldsStore:SetAsync(worldId, saveData)
	end)

	if not success then
		warn("WorldDataStore: Failed to save world", worldId, err)
		return false
	end

	-- Update player's world list
	if data.metadata and data.metadata.owner then
		self:AddWorldToPlayerList(data.metadata.owner, worldId)
	end

	return true
end

-- Load world data
function WorldDataStore:LoadWorld(worldId: string)
	if not self.isServer or not self.worldsStore then
		return nil
	end

	local success, data = pcall(function()
		return self.worldsStore:GetAsync(worldId)
	end)

	if success and data then
		return data
	end

	return nil
end

-- Delete world
function WorldDataStore:DeleteWorld(worldId: string, ownerId: number): boolean
	if not self.isServer then
		return false
	end

	-- Delete world data
	local success = pcall(function()
		self.worldsStore:RemoveAsync(worldId)
	end)

	if not success then
		return false
	end

	-- Remove from player's world list
	if ownerId then
		self:RemoveWorldFromPlayerList(ownerId, worldId)
	end

	-- Delete all permissions for this world
	self:ClearWorldPermissions(worldId)

	return true
end

-- Get permission for player in world
function WorldDataStore:GetPermission(worldId: string, userId: number): string?
	if not self.isServer or not self.permissionsStore then
		return nil
	end

	local key = string.format("%s_%d", worldId, userId)

	local success, level = pcall(function()
		return self.permissionsStore:GetAsync(key)
	end)

	if success and level then
		return level
	end

	return nil
end

-- Set permission for player in world
function WorldDataStore:SetPermission(worldId: string, userId: number, level: string): boolean
	if not self.isServer or not self.permissionsStore then
		return false
	end

	local key = string.format("%s_%d", worldId, userId)

	local success = pcall(function()
		self.permissionsStore:SetAsync(key, level)
	end)

	return success
end

-- Remove permission
function WorldDataStore:RemovePermission(worldId: string, userId: number): boolean
	if not self.isServer or not self.permissionsStore then
		return false
	end

	local key = string.format("%s_%d", worldId, userId)

	local success = pcall(function()
		self.permissionsStore:RemoveAsync(key)
	end)

	return success
end

-- Get all permissions for world (expensive operation)
function WorldDataStore:GetWorldPermissions(_worldId: string): table
	-- Note: This is a simplified version
	-- In production, you'd want to maintain a separate index
	warn("WorldDataStore: GetWorldPermissions is not fully implemented (requires permission indexing)")
	return {}
end

-- Clear all permissions for world
function WorldDataStore:ClearWorldPermissions(_worldId: string)
	-- Note: This is a simplified version
	-- In production, you'd iterate through a permission index
	warn("WorldDataStore: ClearWorldPermissions is not fully implemented (requires permission indexing)")
end

-- Add world to player's world list
function WorldDataStore:AddWorldToPlayerList(userId: number, worldId: string): boolean
	if not self.isServer or not self.playerWorldsStore then
		return false
	end

	local key = tostring(userId)

	local success = pcall(function()
		local worlds = self.playerWorldsStore:GetAsync(key) or {}

		-- Add world if not already in list
		local found = false
		for _, wid in ipairs(worlds) do
			if wid == worldId then
				found = true
				break
			end
		end

		if not found then
			table.insert(worlds, worldId)
			self.playerWorldsStore:SetAsync(key, worlds)
		end
	end)

	return success
end

-- Remove world from player's world list
function WorldDataStore:RemoveWorldFromPlayerList(userId: number, worldId: string): boolean
	if not self.isServer or not self.playerWorldsStore then
		return false
	end

	local key = tostring(userId)

	local success = pcall(function()
		local worlds = self.playerWorldsStore:GetAsync(key) or {}

		-- Remove world from list
		for i = #worlds, 1, -1 do
			if worlds[i] == worldId then
				table.remove(worlds, i)
			end
		end

		self.playerWorldsStore:SetAsync(key, worlds)
	end)

	return success
end

-- Get player's world list
function WorldDataStore:GetPlayerWorlds(userId: number): {string}
	if not self.isServer or not self.playerWorldsStore then
		return {}
	end

	local key = tostring(userId)

	local success, worlds = pcall(function()
		return self.playerWorldsStore:GetAsync(key)
	end)

	if success and worlds then
		return worlds
	end

	return {}
end

-- Get world metadata (without loading chunks)
function WorldDataStore:GetWorldMetadata(worldId: string): table?
	if not self.isServer or not self.worldsStore then
		return nil
	end

	local success, data = pcall(function()
		return self.worldsStore:GetAsync(worldId)
	end)

	if success and data and data.metadata then
		return data.metadata
	end

	return nil
end

-- List public worlds (simplified - in production use ordered data store)
function WorldDataStore:ListPublicWorlds(_limit: number): {table}
	warn("WorldDataStore: ListPublicWorlds requires indexed public worlds (not fully implemented)")
	-- In production, maintain a separate OrderedDataStore for public worlds
	return {}
end

-- Create new world ID
function WorldDataStore:GenerateWorldId(userId: number): string
	local timestamp = os.time()
	local random = math.random(1000, 9999)
	return string.format("world_%d_%d_%d", userId, timestamp, random)
end

return WorldDataStore

