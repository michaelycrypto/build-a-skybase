--[[
	LoadingHandler.client.lua (ReplicatedFirst)
	
	Runs before anything else loads.
	- Removes Roblox's default loading screen
	- Sets custom teleport GUI for seamless server transitions
	- Handles arriving teleport GUI for seamless handoff
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Remove Roblox's default loading screen immediately
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Check if we arrived via teleport (seamless transition)
local arrivingGui = TeleportService:GetArrivingTeleportGui()
if arrivingGui then
	-- Player arrived via teleport - show the arriving GUI until game loads
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	arrivingGui.Parent = playerGui
	arrivingGui.Enabled = true
end

-- Create a simple black screen for future teleports
local function createTeleportGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "TeleportLoadingScreen"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 9999
	
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui
	
	return gui
end

-- Set the custom teleport GUI for any future teleports from this server
local teleportGui = createTeleportGui()
TeleportService:SetTeleportGui(teleportGui)
