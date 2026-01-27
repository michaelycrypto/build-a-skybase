--[[
	LoadingHandler.client.lua (ReplicatedFirst)
	
	Runs before anything else loads.
	- Removes Roblox's default loading screen
	- Sets custom teleport GUI for seamless server transitions
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")

-- Remove Roblox's default loading screen immediately
ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Create a simple black screen for teleport transitions
-- This shows during TeleportAsync instead of Roblox's default
local function createTeleportGui()
	local player = Players.LocalPlayer
	if not player then return nil end
	
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

-- Set the custom teleport GUI
local teleportGui = createTeleportGui()
if teleportGui then
	TeleportService:SetTeleportGui(teleportGui)
end
