--[[
	WorldOwnershipDisplay.lua
	Displays world ownership information in the UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Config = require(ReplicatedStorage.Shared.Config)

local WorldOwnershipDisplay = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

local screenGui = nil
local ownerLabel = nil

function WorldOwnershipDisplay:Initialize()
	print("WorldOwnershipDisplay: Initializing...")

	-- Create UI
	self:CreateUI()

	-- Listen for ownership info
	EventManager:RegisterEvent("WorldOwnershipInfo", function(data)
		self:UpdateDisplay(data)
	end)

	print("WorldOwnershipDisplay: Initialized")
end

function WorldOwnershipDisplay:CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	-- Create ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "WorldOwnershipDisplay"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.IgnoreGuiInset = false -- Respect Roblox top bar so we sit just below it
	screenGui.Parent = playerGui

	-- Add responsive scaling (100% = original size)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080)) -- 1920x1080 for 100% original size
	uiScale.Parent = screenGui
	CollectionService:AddTag(uiScale, "scale_component")
	print("📐 WorldOwnershipDisplay: Added UIScale with base resolution 1920x1080 (100% original size)")

	-- Minimal, unobtrusive owner label aligned with the top bar
	ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "OwnerLabel"
	ownerLabel.AutomaticSize = Enum.AutomaticSize.XY
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.Position = UDim2.new(0, 8, 0, 2)
	ownerLabel.Text = "🏠 Owner: Loading..."
	ownerLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	ownerLabel.TextSize = 14
	ownerLabel.Font = BOLD_FONT
	ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
	ownerLabel.Parent = screenGui
end

function WorldOwnershipDisplay:UpdateDisplay(data)
	if not ownerLabel then return end

	local ownerName = data.ownerName or "Unknown"
	local worldName = data.worldName or "Realm"

	-- Update label with format: World Name [World Owner]
	local displayText = worldName .. " [" .. ownerName .. "]"

	-- Check if local player is the owner
	local localPlayer = Players.LocalPlayer
	if localPlayer.UserId == data.ownerId then
		ownerLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		ownerLabel.Text = displayText .. " (You)"
	else
		ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		ownerLabel.Text = displayText
	end

	print(string.format("WorldOwnershipDisplay: %s owned by %s", worldName, ownerName))
end

function WorldOwnershipDisplay:Cleanup()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return WorldOwnershipDisplay

