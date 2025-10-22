--[[
	WorldManagementController.lua
	Client-side controller for world management UI and requests
	Handles world creation, teleportation, browsing, and settings
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local WorldManagementController = {}
WorldManagementController.__index = WorldManagementController

function WorldManagementController.new()
	local self = setmetatable({
		player = Players.LocalPlayer,
		currentLocation = "lobby",
		currentWorldId = nil,
		myWorlds = {}, -- Cache of player's worlds
		publicWorlds = {}, -- Cache of public worlds
		isInUI = false
	}, WorldManagementController)

	self:Init()
	return self
end

function WorldManagementController:Init()
	-- Register event listeners
	self:RegisterEvents()

	print("WorldManagementController: Initialized")
end

function WorldManagementController:RegisterEvents()
	-- Listen for teleport events
	EventManager:RegisterEvent("PlayerTeleported", function(data)
		if data then
			self.currentLocation = data.location or "lobby"
			self.currentWorldId = data.worldId or nil

			print(string.format("WorldManagementController: Teleported to %s", self.currentLocation))

			-- Update UI if open
			self:RefreshUI()
		end
	end)

	-- Listen for world list updates
	EventManager:RegisterEvent("WorldListUpdated", function(data)
		if data and data.worlds then
			self.myWorlds = data.worlds
			self:RefreshUI()
		end
	end)
end

-- Request world creation
function WorldManagementController:CreateWorld(worldName: string, isPublic: boolean, maxPlayers: number)
	print(string.format("WorldManagementController: Requesting world creation: %s", worldName))

	EventManager:FireEvent("CreateWorld", {
		name = worldName,
		isPublic = isPublic or false,
		maxPlayers = maxPlayers or 10
	})
end

-- Request teleport to world
function WorldManagementController:TeleportToWorld(worldId: string)
	if not worldId then
		warn("WorldManagementController: Invalid world ID")
		return
	end

	print(string.format("WorldManagementController: Requesting teleport to world %s", worldId))

	EventManager:FireEvent("TeleportToWorld", {
		worldId = worldId
	})
end

-- Request teleport to lobby
function WorldManagementController:TeleportToLobby()
	print("WorldManagementController: Requesting teleport to lobby")

	EventManager:FireEvent("TeleportToLobby", {})
end

-- Request my worlds list
function WorldManagementController:RequestMyWorlds()
	print("WorldManagementController: Requesting my worlds list")

	EventManager:FireEvent("GetMyWorlds", {})
end

-- Request public worlds list
function WorldManagementController:RequestPublicWorlds()
	print("WorldManagementController: Requesting public worlds list")

	EventManager:FireEvent("GetPublicWorlds", {})
end

-- Request world deletion
function WorldManagementController:DeleteWorld(worldId: string)
	if not worldId then
		warn("WorldManagementController: Invalid world ID")
		return
	end

	print(string.format("WorldManagementController: Requesting world deletion: %s", worldId))

	EventManager:FireEvent("DeleteWorld", {
		worldId = worldId
	})
end

-- Update world settings
function WorldManagementController:UpdateWorldSettings(worldId: string, settings: table)
	if not worldId then
		warn("WorldManagementController: Invalid world ID")
		return
	end

	print(string.format("WorldManagementController: Updating world settings: %s", worldId))

	EventManager:FireEvent("UpdateWorldSettings", {
		worldId = worldId,
		settings = settings
	})
end

-- Invite player to world
function WorldManagementController:InvitePlayer(worldId: string, targetPlayer: Player)
	if not worldId or not targetPlayer then
		warn("WorldManagementController: Invalid parameters")
		return
	end

	print(string.format("WorldManagementController: Inviting %s to world %s", targetPlayer.Name, worldId))

	EventManager:FireEvent("InvitePlayer", {
		worldId = worldId,
		targetUserId = targetPlayer.UserId
	})
end

-- Set player permission level
function WorldManagementController:SetPermission(worldId: string, targetUserId: number, level: string)
	if not worldId or not targetUserId or not level then
		warn("WorldManagementController: Invalid parameters")
		return
	end

	print(string.format("WorldManagementController: Setting permission for user %d in world %s to %s",
		targetUserId, worldId, level))

	EventManager:FireEvent("SetWorldPermission", {
		worldId = worldId,
		targetUserId = targetUserId,
		level = level
	})
end

-- Get current location
function WorldManagementController:GetCurrentLocation(): (string, string?)
	return self.currentLocation, self.currentWorldId
end

-- Check if in lobby
function WorldManagementController:IsInLobby(): boolean
	return self.currentLocation == "lobby"
end

-- Check if in world
function WorldManagementController:IsInWorld(): boolean
	return self.currentLocation == "world"
end

-- Refresh UI (override this to update UI when needed)
function WorldManagementController:RefreshUI()
	-- To be implemented by UI modules
end

return WorldManagementController

