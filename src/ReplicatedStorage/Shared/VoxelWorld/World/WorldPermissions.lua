--[[
	WorldPermissions.lua
	Manages world permissions and access control
	Roles: owner, builder, visitor
]]

local WorldPermissions = {}
WorldPermissions.__index = WorldPermissions

-- Permission levels
WorldPermissions.Level = {
	OWNER = "owner",
	BUILDER = "builder",
	VISITOR = "visitor",
	NONE = "none"
}

-- Permission capabilities
local CAPABILITIES = {
	owner = {
		canJoin = true,
		canBuild = true,
		canDestroy = true,
		canInvite = true,
		canKick = true,
		canModifySettings = true,
		canDelete = true
	},
	builder = {
		canJoin = true,
		canBuild = true,
		canDestroy = true,
		canInvite = false,
		canKick = false,
		canModifySettings = false,
		canDelete = false
	},
	visitor = {
		canJoin = true,
		canBuild = false,
		canDestroy = false,
		canInvite = false,
		canKick = false,
		canModifySettings = false,
		canDelete = false
	},
	none = {
		canJoin = false,
		canBuild = false,
		canDestroy = false,
		canInvite = false,
		canKick = false,
		canModifySettings = false,
		canDelete = false
	}
}

function WorldPermissions.new(dataStore)
	local self = setmetatable({
		dataStore = dataStore, -- WorldPermissionsDataStore
		cache = {} -- worldId -> userId -> level
	}, WorldPermissions)

	return self
end

-- Get player permission level for world
function WorldPermissions:GetPermissionLevel(worldId: string, userId: number, worldMetadata: table): string
	if not worldId or not userId then
		return WorldPermissions.Level.NONE
	end

	-- Owner always has owner permissions
	if worldMetadata and worldMetadata.owner == userId then
		return WorldPermissions.Level.OWNER
	end

	-- Public worlds: anyone can join as visitor (unless explicitly granted higher access)
	local isPublic = worldMetadata and worldMetadata.isPublic

	-- Check cache first
	if self.cache[worldId] and self.cache[worldId][userId] then
		return self.cache[worldId][userId]
	end

	-- Query DataStore for explicit permissions
	if self.dataStore then
		local success, level = pcall(function()
			return self.dataStore:GetPermission(worldId, userId)
		end)

		if success and level then
			-- Cache the result
			if not self.cache[worldId] then
				self.cache[worldId] = {}
			end
			self.cache[worldId][userId] = level
			return level
		end
	end

	-- Default: visitor for public worlds, none for private
	if isPublic then
		return WorldPermissions.Level.VISITOR
	end

	return WorldPermissions.Level.NONE
end

-- Set player permission level
function WorldPermissions:SetPermissionLevel(worldId: string, userId: number, level: string): boolean
	if not worldId or not userId or not level then
		return false
	end

	-- Validate level
	if not CAPABILITIES[level] then
		warn("WorldPermissions: Invalid permission level:", level)
		return false
	end

	-- Update DataStore
	if self.dataStore then
		local success = pcall(function()
			self.dataStore:SetPermission(worldId, userId, level)
		end)

		if success then
			-- Update cache
			if not self.cache[worldId] then
				self.cache[worldId] = {}
			end
			self.cache[worldId][userId] = level
			return true
		end
	end

	return false
end

-- Remove player permissions
function WorldPermissions:RemovePermission(worldId: string, userId: number): boolean
	if not worldId or not userId then
		return false
	end

	-- Remove from DataStore
	if self.dataStore then
		local success = pcall(function()
			self.dataStore:RemovePermission(worldId, userId)
		end)

		if success then
			-- Clear cache
			if self.cache[worldId] then
				self.cache[worldId][userId] = nil
			end
			return true
		end
	end

	return false
end

-- Check if player can perform action
function WorldPermissions:CanPerformAction(worldId: string, userId: number, action: string, worldMetadata: table): boolean
	local level = self:GetPermissionLevel(worldId, userId, worldMetadata)
	local capabilities = CAPABILITIES[level]

	if not capabilities then
		return false
	end

	-- Special case: check if building is disabled in world settings
	if action == "canBuild" or action == "canDestroy" then
		if worldMetadata and worldMetadata.allowBuilding == false then
			-- Only owner can build if building is disabled
			return level == WorldPermissions.Level.OWNER
		end
	end

	return capabilities[action] == true
end

-- Check if player can join world
function WorldPermissions:CanJoinWorld(worldId: string, userId: number, worldMetadata: table): boolean
	return self:CanPerformAction(worldId, userId, "canJoin", worldMetadata)
end

-- Check if player can build in world
function WorldPermissions:CanBuild(worldId: string, userId: number, worldMetadata: table): boolean
	return self:CanPerformAction(worldId, userId, "canBuild", worldMetadata)
end

-- Check if player can destroy blocks in world
function WorldPermissions:CanDestroy(worldId: string, userId: number, worldMetadata: table): boolean
	return self:CanPerformAction(worldId, userId, "canDestroy", worldMetadata)
end

-- Check if player can invite others
function WorldPermissions:CanInvite(worldId: string, userId: number, worldMetadata: table): boolean
	return self:CanPerformAction(worldId, userId, "canInvite", worldMetadata)
end

-- Check if player can modify world settings
function WorldPermissions:CanModifySettings(worldId: string, userId: number, worldMetadata: table): boolean
	return self:CanPerformAction(worldId, userId, "canModifySettings", worldMetadata)
end

-- Get all players with permissions for world
function WorldPermissions:GetWorldPermissions(worldId: string): table
	if not self.dataStore then
		return {}
	end

	local success, permissions = pcall(function()
		return self.dataStore:GetWorldPermissions(worldId)
	end)

	if success and permissions then
		return permissions
	end

	return {}
end

-- Clear cache for world
function WorldPermissions:ClearCache(worldId: string)
	if worldId then
		self.cache[worldId] = nil
	else
		self.cache = {}
	end
end

return WorldPermissions

