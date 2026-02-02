--[[
	WorldInstanceManager.lua
	Manages multiple player-owned world instances
	Handles loading, unloading, and concurrent world limits
]]

local WorldInstance = require(script.Parent.WorldInstance)

local WorldInstanceManager = {}
WorldInstanceManager.__index = WorldInstanceManager

-- Configuration
local MAX_CONCURRENT_WORLDS = 50
local UNLOAD_DELAY_SECONDS = 30 -- Unload world 30s after last player leaves

function WorldInstanceManager.new()
	local self = setmetatable({
		activeWorlds = {}, -- Map of worldId -> WorldInstance
		loadQueue = {}, -- Queue of worlds to load
		unloadQueue = {}, -- Map of worldId -> unload timestamp
		worldDataStore = nil, -- Set externally
		stats = {
			worldsLoaded = 0,
			worldsUnloaded = 0,
			totalPlayers = 0
		}
	}, WorldInstanceManager)

	return self
end

-- Set DataStore interface
function WorldInstanceManager:SetDataStore(dataStore)
	self.worldDataStore = dataStore
end

-- Get or load world instance
function WorldInstanceManager:GetWorld(worldId: string, metadata: table)
	if not worldId then
		warn("WorldInstanceManager: Invalid worldId")
		return nil
	end

	-- Return if already loaded
	if self.activeWorlds[worldId] then
		local world = self.activeWorlds[worldId]
		world.lastAccessTime = os.clock()
		-- Remove from unload queue if present
		self.unloadQueue[worldId] = nil
		return world
	end

	-- Check concurrent world limit
	local activeCount = 0
	for _ in pairs(self.activeWorlds) do
		activeCount += 1
	end

	if activeCount >= MAX_CONCURRENT_WORLDS then
		warn("WorldInstanceManager: Max concurrent worlds reached")
		-- Try to unload empty worlds to make space
		self:UnloadEmptyWorlds(true) -- Force immediate unload

		-- Recheck count
		activeCount = 0
		for _ in pairs(self.activeWorlds) do
			activeCount += 1
		end

		if activeCount >= MAX_CONCURRENT_WORLDS then
			return nil, "max_worlds_reached"
		end
	end

	-- Create new world instance
	local world = WorldInstance.new(worldId, metadata)

	-- Try to load from DataStore
	local chunkData = nil
	if self.worldDataStore then
		local success, data = pcall(function()
			return self.worldDataStore:LoadWorld(worldId)
		end)

		if success and data then
			chunkData = data.chunks
			-- Update metadata from saved data
			if data.metadata then
				world.metadata = data.metadata
			end
		end
	end

	-- Load world (generate if no saved data)
	world:Load(chunkData)

	-- Add to active worlds
	self.activeWorlds[worldId] = world
	self.stats.worldsLoaded += 1

	print(string.format("WorldInstanceManager: Loaded world %s (%s)", worldId, world.metadata.name))

	return world
end

-- Unload world instance
function WorldInstanceManager:UnloadWorld(worldId: string, forceSave: boolean)
	local world = self.activeWorlds[worldId]
	if not world then
		return
	end

	-- Check if world has players
	if not world:IsEmpty() then
		warn("WorldInstanceManager: Cannot unload world with players:", worldId)
		return false
	end

	-- Save if modified
	if forceSave or next(world.modifiedChunks) then
		self:SaveWorld(worldId)
	end

	-- Unload and remove
	world:Unload()
	world:Destroy()
	self.activeWorlds[worldId] = nil
	self.unloadQueue[worldId] = nil
	self.stats.worldsUnloaded += 1

	print(string.format("WorldInstanceManager: Unloaded world %s", worldId))
	return true
end

-- Save world to DataStore
function WorldInstanceManager:SaveWorld(worldId: string)
	local world = self.activeWorlds[worldId]
	if not world or not self.worldDataStore then
		return false
	end

	local success, err = pcall(function()
		local data = {
			metadata = world.metadata,
			chunks = world:SerializeChunks()
		}
		self.worldDataStore:SaveWorld(worldId, data)
	end)

	if success then
		-- Clear modified flags
		for key in pairs(world.modifiedChunks) do
			world:ClearModified(key)
		end
		print(string.format("WorldInstanceManager: Saved world %s", worldId))
		return true
	else
		warn("WorldInstanceManager: Failed to save world", worldId, err)
		return false
	end
end

-- Add player to world
function WorldInstanceManager:AddPlayerToWorld(worldId: string, player: Player, metadata: table)
	local world = self:GetWorld(worldId, metadata)
	if not world then
		return false, "failed_to_load"
	end

	-- Remove from unload queue
	self.unloadQueue[worldId] = nil

	local success, reason = world:AddPlayer(player)
	if success then
		self:UpdatePlayerCount()
	end

	return success, reason
end

-- Remove player from world
function WorldInstanceManager:RemovePlayerFromWorld(worldId: string, player: Player)
	local world = self.activeWorlds[worldId]
	if not world then
		return
	end

	world:RemovePlayer(player)
	self:UpdatePlayerCount()

	-- Queue for unload if empty
	if world:IsEmpty() then
		self.unloadQueue[worldId] = os.clock()
		print(string.format("WorldInstanceManager: Queued empty world %s for unload", worldId))
	end
end

-- Update player count statistics
function WorldInstanceManager:UpdatePlayerCount()
	local total = 0
	for _, world in pairs(self.activeWorlds) do
		total += world:GetPlayerCount()
	end
	self.stats.totalPlayers = total
end

-- Process unload queue (call from heartbeat)
function WorldInstanceManager:ProcessUnloadQueue()
	local now = os.clock()

	for worldId, queueTime in pairs(self.unloadQueue) do
		if (now - queueTime) >= UNLOAD_DELAY_SECONDS then
			local world = self.activeWorlds[worldId]
			if world and world:IsEmpty() then
				self:UnloadWorld(worldId, true)
			else
				-- Remove from queue if no longer empty
				self.unloadQueue[worldId] = nil
			end
		end
	end
end

-- Unload all empty worlds (for capacity management)
function WorldInstanceManager:UnloadEmptyWorlds(immediate: boolean)
	local now = os.clock()
	local unloaded = 0

	for worldId, world in pairs(self.activeWorlds) do
		if world:IsEmpty() then
			local queueTime = self.unloadQueue[worldId]
			if immediate or (queueTime and (now - queueTime) >= UNLOAD_DELAY_SECONDS) then
				if self:UnloadWorld(worldId, true) then
					unloaded += 1
				end
			else
				-- Queue if not already queued
				if not queueTime then
					self.unloadQueue[worldId] = now
				end
			end
		end
	end

	return unloaded
end

-- Save all modified worlds
function WorldInstanceManager:SaveAllWorlds()
	local saved = 0
	for worldId, world in pairs(self.activeWorlds) do
		if next(world.modifiedChunks) then
			if self:SaveWorld(worldId) then
				saved += 1
			end
		end
	end
	return saved
end

-- Get world by ID
function WorldInstanceManager:GetWorldById(worldId: string)
	return self.activeWorlds[worldId]
end

-- Check if world is loaded
function WorldInstanceManager:IsWorldLoaded(worldId: string): boolean
	return self.activeWorlds[worldId] ~= nil
end

-- Get statistics
function WorldInstanceManager:GetStats()
	local activeCount = 0
	local emptyCount = 0
	local totalChunks = 0

	for _, world in pairs(self.activeWorlds) do
		activeCount += 1
		if world:IsEmpty() then
			emptyCount += 1
		end
		for _ in pairs(world.chunks) do
			totalChunks += 1
		end
	end

	return {
		activeWorlds = activeCount,
		emptyWorlds = emptyCount,
		totalPlayers = self.stats.totalPlayers,
		totalChunks = totalChunks,
		worldsLoaded = self.stats.worldsLoaded,
		worldsUnloaded = self.stats.worldsUnloaded,
		queuedForUnload = (function()
			local count = 0
			for _ in pairs(self.unloadQueue) do
				count += 1
			end
			return count
		end)()
	}
end

-- Clean up all worlds
function WorldInstanceManager:Destroy()
	-- Save all modified worlds
	self:SaveAllWorlds()

	-- Destroy all worlds
	for _, world in pairs(self.activeWorlds) do
		world:Destroy()
	end

	self.activeWorlds = {}
	self.unloadQueue = {}
end

return WorldInstanceManager

