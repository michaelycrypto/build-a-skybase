--[[
	ServerRoleDetector.lua
	
	Single-place architecture: Detects server role from TeleportData.
	
	Server Types (from PRD):
	- ROUTER: Public entry point → routes players immediately
	- WORLD: Reserved server for player-owned worlds
	- HUB: Reserved server for Nexus (shared social hub)
	
	Detection (PRD spec):
	- TeleportData.serverType is authoritative
	- Public server (PrivateServerId == "") = ROUTER
	- Server sets Workspace.ServerRole for client to read
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)

local ServerTypes = GameConfig.ServerTypes
local IS_STUDIO = RunService:IsStudio()
local IS_SERVER = RunService:IsServer()

local ServerRoleDetector = {}
ServerRoleDetector.ServerTypes = ServerTypes

local _cachedRole = nil
local _cachedTeleportData = nil

-- Get TeleportData from first player (server-side)
local function getServerTeleportData()
	local players = Players:GetPlayers()
	if #players > 0 then
		local joinData = players[1]:GetJoinData()
		if joinData and joinData.TeleportData then
			return joinData.TeleportData
		end
	end
	
	-- Wait for first player
	local player = Players:FindFirstChildOfClass("Player")
	if not player then
		local waitStart = os.clock()
		while os.clock() - waitStart < 5 do
			player = Players.PlayerAdded:Wait()
			if player then break end
		end
	end
	
	if player then
		local joinData = player:GetJoinData()
		return joinData and joinData.TeleportData
	end
	return nil
end

-- Server detection: TeleportData → PrivateServerId fallback
local function detectServer()
	-- Studio: default to WORLD for gameplay testing
	if IS_STUDIO then
		local td = getServerTeleportData()
		if td and td.serverType then
			Workspace:SetAttribute("ServerRole", td.serverType)
			return td.serverType, td
		end
		Workspace:SetAttribute("ServerRole", ServerTypes.WORLD)
		return ServerTypes.WORLD, { serverType = ServerTypes.WORLD, studioFallback = true }
	end
	
	-- Production: check TeleportData first
	local td = getServerTeleportData()
	if td and td.serverType then
		if td.serverType == ServerTypes.WORLD or td.serverType == ServerTypes.HUB then
			Workspace:SetAttribute("ServerRole", td.serverType)
			return td.serverType, td
		end
	end
	
	-- Fallback: public server = ROUTER
	if game.PrivateServerId == "" then
		Workspace:SetAttribute("ServerRole", ServerTypes.ROUTER)
		return ServerTypes.ROUTER, nil
	end
	
	-- Reserved server without TeleportData (error state)
	warn("[ServerRoleDetector] Reserved server without TeleportData")
	Workspace:SetAttribute("ServerRole", ServerTypes.HUB)
	return ServerTypes.HUB, td
end

-- Client detection: read Workspace attribute
local function detectClient()
	-- Wait for server to set attribute
	local role = Workspace:GetAttribute("ServerRole")
	if role then return role end
	
	local waitStart = os.clock()
	while os.clock() - waitStart < 3 do
		role = Workspace:GetAttribute("ServerRole")
		if role then return role end
		task.wait(0.05)
	end
	
	-- Fallback
	if game.PrivateServerId == "" then
		return ServerTypes.ROUTER
	end
	return ServerTypes.WORLD
end

function ServerRoleDetector.Detect()
	if _cachedRole then
		return _cachedRole, _cachedTeleportData
	end
	
	if IS_SERVER then
		_cachedRole, _cachedTeleportData = detectServer()
	else
		_cachedRole = detectClient()
	end
	
	return _cachedRole, _cachedTeleportData
end

function ServerRoleDetector.IsRouter()
	return ServerRoleDetector.Detect() == ServerTypes.ROUTER
end

function ServerRoleDetector.IsWorld()
	return ServerRoleDetector.Detect() == ServerTypes.WORLD
end

function ServerRoleDetector.IsHub()
	return ServerRoleDetector.Detect() == ServerTypes.HUB
end

function ServerRoleDetector.GetTeleportData()
	ServerRoleDetector.Detect()
	return _cachedTeleportData
end

return ServerRoleDetector
