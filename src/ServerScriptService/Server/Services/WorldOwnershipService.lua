--[[
	WorldOwnershipService.lua

	Manages server instance ownership for player-owned worlds.
	The first player to join becomes the owner of this server instance.
	All world data is stored in the owner's datastore.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local WorldOwnershipService = setmetatable({}, BaseService)
WorldOwnershipService.__index = WorldOwnershipService

-- DataStore for world ownership
local Config = require(game.ReplicatedStorage.Shared.Config)
local WORLD_DATA_STORE_NAME = Config.Worlds.DataStoreVersion

function WorldOwnershipService.new()
	local self = setmetatable(BaseService.new(), WorldOwnershipService)

	self._logger = Logger:CreateContext("WorldOwnershipService")
	self._worldDataStore = nil
	self._ownerId = nil -- UserId of the owner
	self._ownerName = nil -- Display name of the owner
	self._worldId = nil -- Full worldId (e.g., "12345:1")
	self._worldData = nil -- Cached world data
	self._initialized = false

	return self
end

function WorldOwnershipService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing WorldOwnershipService...")

	-- Initialize DataStore
	pcall(function()
		self._worldDataStore = DataStoreService:GetDataStore(WORLD_DATA_STORE_NAME)
	end)

	if not self._worldDataStore then
		self._logger.Warn("Failed to get DataStore - running in local mode")
	end

	BaseService.Init(self)
	self._logger.Info("WorldOwnershipService initialized")
end

function WorldOwnershipService:Start()
	if self._started then
		return
	end

	self._logger.Info("WorldOwnershipService started")
	BaseService.Start(self)
end

--[[
	Claim ownership of this server instance for a player
	This should only be called for the FIRST player to join
--]]
function WorldOwnershipService:ClaimOwnership(player: Player)
	if self._ownerId then
		self._logger.Warn("Server already has an owner", {
			existingOwner = self._ownerName,
			attemptedClaimer = player.Name
		})
		return false
	end

	self._ownerId = player.UserId
	self._ownerName = player.Name
	-- Set default worldId to slot 1 if not already set (for fallback cases)
	if not self._worldId then
		self._worldId = tostring(player.UserId) .. ":1"
	end

	self._logger.Info("🏠 Server ownership claimed", {
		owner = player.Name,
		userId = player.UserId,
		worldId = self._worldId
	})

	-- Load world data for this owner
	self:LoadWorldData()

	-- Notify all players about the owner
	self:BroadcastOwnershipInfo()

	return true
end

--[[
	Get the owner's UserId
--]]
function WorldOwnershipService:GetOwnerId()
	return self._ownerId
end

--[[
	Get the owner's display name
--]]
function WorldOwnershipService:GetOwnerName()
	return self._ownerName
end

--[[
	Get the current worldId
--]]
function WorldOwnershipService:GetWorldId()
	return self._worldId
end

--[[
	Set owner by UserId (used when owner is defined by teleport data)
	@param ownerUserId: number - The owner's UserId
	@param ownerName: string? - The owner's display name (optional)
	@param worldId: string? - The full worldId (e.g., "12345:1"), defaults to userId:1
--]]
function WorldOwnershipService:SetOwnerById(ownerUserId: number, ownerName: string?, worldId: string?)
	if self._ownerId then
		-- Already set; do not overwrite
		return false
	end

	self._ownerId = ownerUserId

	-- Validate and set worldId - ensure it's in format "userId:slot"
	if worldId and type(worldId) == "string" and #worldId > 0 then
		-- Check if worldId has the correct format (userId:slot)
		local hasColon = string.find(worldId, ":")
		if hasColon then
			-- Verify worldId format matches ownerUserId (e.g., "12345:2")
			local extractedUserId = tonumber(string.match(worldId, "^(%d+):"))
			-- Ensure both are numbers for comparison
			local ownerUserIdNum = tonumber(ownerUserId) or ownerUserId
			if extractedUserId and extractedUserId == ownerUserIdNum then
				self._worldId = worldId
				self._logger.Info("✅ WorldId validated and set", {
					worldId = worldId,
					ownerUserId = ownerUserId,
					extractedUserId = extractedUserId
				})
			else
				-- WorldId format doesn't match owner, but still use it if it has correct format
				-- This allows for edge cases where ownerUserId might be different
				-- (e.g., admin accessing someone else's world)
				if extractedUserId then
					self._worldId = worldId
					self._logger.Warn("⚠️ WorldId userId doesn't match ownerUserId, but using worldId anyway", {
						worldId = worldId,
						ownerUserId = ownerUserId,
						extractedUserId = extractedUserId
					})
				else
					-- Invalid format, default to slot 1
					self._logger.Warn("⚠️ WorldId has invalid format - defaulting to slot 1", {
						worldId = worldId,
						ownerUserId = ownerUserId
					})
					self._worldId = tostring(ownerUserId) .. ":1"
				end
			end
		else
			-- WorldId doesn't have colon format, default to slot 1
			self._logger.Warn("⚠️ WorldId missing colon format - defaulting to slot 1", {
				worldId = worldId,
				ownerUserId = ownerUserId
			})
			self._worldId = tostring(ownerUserId) .. ":1"
		end
	else
		-- No worldId provided, default to slot 1
		self._logger.Warn("⚠️ No worldId provided - defaulting to slot 1", {
			worldId = worldId,
			worldIdType = type(worldId),
			ownerUserId = ownerUserId
		})
		self._worldId = tostring(ownerUserId) .. ":1"
	end

	-- Try to resolve name if not provided
	if ownerName and #ownerName > 0 then
		self._ownerName = ownerName
	else
		local Players = game:GetService("Players")
		local ok, resolved = pcall(function()
			if Players.GetNameFromUserIdAsync then
				return Players:GetNameFromUserIdAsync(ownerUserId)
			end
			return nil
		end)
		self._ownerName = (ok and resolved) or ("User_" .. tostring(ownerUserId))
	end

	self._logger.Info("🏷️ Owner set by id", {
		owner = self._ownerName,
		userId = self._ownerId,
		worldId = self._worldId
	})
	return true
end

--[[
	Check if a player is the owner
--]]
function WorldOwnershipService:IsOwner(player: Player)
	return player and player.UserId == self._ownerId
end

--[[
	Get the owner player instance (if they're still in the server)
--]]
function WorldOwnershipService:GetOwner()
	if not self._ownerId then
		return nil
	end

	return Players:GetPlayerByUserId(self._ownerId)
end

--[[
	Load world data from the owner's datastore
--]]
function WorldOwnershipService:LoadWorldData()
	if not self._worldId or not self._worldDataStore then
		self._logger.Warn("Cannot load world data - no worldId or datastore")
		return nil
	end

	local success, data = pcall(function()
		local key = "World_" .. self._worldId
		return self._worldDataStore:GetAsync(key)
	end)

	if success and data then
		self._worldData = data
		self._logger.Info("✅ Loaded world data", {
			worldId = self._worldId,
			owner = self._ownerName,
			chunkCount = (data.chunks and #data.chunks) or 0
		})
	else
		-- Extract slot number from worldId (e.g., "12345:2" -> slot 2)
		local slot = tonumber(string.match(self._worldId, ":(%d+)$")) or 1

		-- Create new world data
		self._worldData = {
			worldId = self._worldId,
			ownerId = self._ownerId,
			ownerName = self._ownerName,
			created = os.time(),
			lastSaved = os.time(),
			seed = math.random(1, 999999),
			chunks = {},
			mobs = {},
			metadata = {
				name = "World " .. slot,
				description = "A player-owned world",
			}
		}
		self._logger.Info("📝 Created new world data", {
			worldId = self._worldId,
			owner = self._ownerName,
			slot = slot,
			seed = self._worldData.seed
		})
	end

	return self._worldData
end

--[[
	Save world data to the owner's datastore
--]]
function WorldOwnershipService:SaveWorldData(worldData)
	if not self._worldId or not self._worldDataStore then
		self._logger.Warn("Cannot save world data - no worldId or datastore")
		return false
	end

	-- Update cache if provided, otherwise use cached data
	if worldData then
		self._worldData = worldData
	end

	if not self._worldData then
		self._logger.Warn("No world data to save")
		return false
	end

	-- Ensure worldId matches the current _worldId (in case it changed)
	self._worldData.worldId = self._worldId
	self._worldData.ownerId = self._ownerId
	self._worldData.ownerName = self._ownerName

	-- Update last saved timestamp
	self._worldData.lastSaved = os.time()

	local key = "World_" .. self._worldId
	self._logger.Info("💾 Saving world data", {
		worldId = self._worldId,
		datastoreKey = key,
		owner = self._ownerName,
		lastSaved = self._worldData.lastSaved,
		chunkCount = (self._worldData.chunks and #self._worldData.chunks) or 0
	})

	local success, err = pcall(function()
		self._worldDataStore:SetAsync(key, self._worldData)
	end)

	if success then
		self._logger.Info("✅ Saved world data successfully", {
			worldId = self._worldId,
			datastoreKey = key,
			owner = self._ownerName,
			chunkCount = (self._worldData.chunks and #self._worldData.chunks) or 0
		})
		return true
	else
		self._logger.Error("❌ Failed to save world data", {
			worldId = self._worldId,
			datastoreKey = key,
			owner = self._ownerName,
			error = tostring(err)
		})
		return false
	end
end

--[[
	Get cached world data
--]]
function WorldOwnershipService:GetWorldData()
	return self._worldData
end

--[[
	Update world metadata
--]]
function WorldOwnershipService:UpdateMetadata(metadata)
	if not self._worldData then
		return false
	end

	self._worldData.metadata = self._worldData.metadata or {}
	for key, value in pairs(metadata) do
		self._worldData.metadata[key] = value
	end

	self._logger.Info("Updated world metadata", {
		owner = self._ownerName
	})

	return true
end

--[[
	Broadcast ownership information to all players
--]]
function WorldOwnershipService:BroadcastOwnershipInfo()
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)

	local ownerInfo = {
		ownerId = self._ownerId,
		ownerName = self._ownerName,
		worldName = self._worldData and self._worldData.metadata and self._worldData.metadata.name or (self._ownerName .. "'s World"),
		created = self._worldData and self._worldData.created or os.time(),
		seed = self._worldData and self._worldData.seed or 0
	}

	for _, player in ipairs(Players:GetPlayers()) do
		EventManager:FireEvent("WorldOwnershipInfo", player, ownerInfo)
	end

	self._logger.Info("📢 Broadcasted ownership info to all players")
end

--[[
	Get world seed for terrain generation
--]]
function WorldOwnershipService:GetWorldSeed()
	if self._worldData and self._worldData.seed then
		return self._worldData.seed
	end
	return 12345 -- Default seed
end

function WorldOwnershipService:Destroy()
	if self._destroyed then
		return
	end

	-- NOTE: Save already happens in game:BindToClose() in Bootstrap
	-- Don't save again here to avoid overwriting with stale data
	-- if self._worldData then
	--     self:SaveWorldData()
	-- end

	BaseService.Destroy(self)
	self._logger.Info("WorldOwnershipService destroyed")
end

return WorldOwnershipService

