--[[
	WorldOwnershipDisplay.lua
	Displays world ownership information in the UI
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local WorldOwnershipDisplay = {}

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
	screenGui.Parent = playerGui

	-- Create background frame
	local frame = Instance.new("Frame")
	frame.Name = "OwnershipFrame"
	frame.Size = UDim2.new(0, 300, 0, 80)
	frame.Position = UDim2.new(0.5, -150, 0, 10)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	frame.BackgroundTransparency = 0.3
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	-- Add corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	-- Add title label
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, -20, 0, 25)
	titleLabel.Position = UDim2.new(0, 10, 0, 5)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "🏠 World Owner"
	titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	titleLabel.TextSize = 16
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = frame

	-- Add owner name label
	ownerLabel = Instance.new("TextLabel")
	ownerLabel.Name = "OwnerLabel"
	ownerLabel.Size = UDim2.new(1, -20, 0, 30)
	ownerLabel.Position = UDim2.new(0, 10, 0, 30)
	ownerLabel.BackgroundTransparency = 1
	ownerLabel.Text = "Loading..."
	ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	ownerLabel.TextSize = 20
	ownerLabel.Font = Enum.Font.GothamBold
	ownerLabel.TextXAlignment = Enum.TextXAlignment.Left
	ownerLabel.Parent = frame

	-- Add world name label
	local worldLabel = Instance.new("TextLabel")
	worldLabel.Name = "WorldLabel"
	worldLabel.Size = UDim2.new(1, -20, 0, 20)
	worldLabel.Position = UDim2.new(0, 10, 0, 60)
	worldLabel.BackgroundTransparency = 1
	worldLabel.Text = ""
	worldLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	worldLabel.TextSize = 14
	worldLabel.Font = Enum.Font.Gotham
	worldLabel.TextXAlignment = Enum.TextXAlignment.Left
	worldLabel.Parent = frame

	self.worldLabel = worldLabel
end

function WorldOwnershipDisplay:UpdateDisplay(data)
	if not ownerLabel then return end

	local ownerName = data.ownerName or "Unknown"
	local worldName = data.worldName or "World"

	-- Update labels
	ownerLabel.Text = ownerName
	self.worldLabel.Text = worldName

	-- Check if local player is the owner
	local localPlayer = Players.LocalPlayer
	if localPlayer.UserId == data.ownerId then
		ownerLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		ownerLabel.Text = ownerName .. " (You)"
	else
		ownerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end

	print(string.format("WorldOwnershipDisplay: World owned by %s (%s)",
		ownerName, worldName))
end

function WorldOwnershipDisplay:Cleanup()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

return WorldOwnershipDisplay

