--[[
	PlayerBillboardManager.lua - Simple Player Billboard System
	Displays player names and avatars above their PlayerDungeon
--]]

local PlayerBillboardManager = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- State
local isInitialized = false
local billboards = {} -- [player] = billboardGui
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
local updateConnection = nil

-- Configuration
local BILLBOARD_OFFSET = Vector3.new(0, 50, 0)
local BILLBOARD_SIZE = UDim2.fromScale(24, 6)
local UPDATE_INTERVAL = 2

--[[
	Find a player's PlayerDungeon model
--]]
local function findPlayerDungeon(player)
	local dungeonWorld = Workspace:FindFirstChild("DungeonWorld")
	if not dungeonWorld then return nil end

	local playerDungeonFolder = dungeonWorld:FindFirstChild("PlayerDungeon")
	if not playerDungeonFolder then return nil end

	for _, model in pairs(playerDungeonFolder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Owner") == player.Name then
			return model
		end
	end
	return nil
end

--[[
	Create billboard for a player
--]]
local function createBillboard(player, centerPart)
	-- Create billboard GUI
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "PlayerBillboard_" .. player.Name
	billboardGui.Size = BILLBOARD_SIZE
	billboardGui.StudsOffsetWorldSpace = BILLBOARD_OFFSET
	billboardGui.AlwaysOnTop = true
	billboardGui.LightInfluence = 0
	billboardGui.MaxDistance = math.huge
	billboardGui.Adornee = centerPart
	billboardGui.Parent = centerPart

	-- Player image (square, left side)
	local playerImage = Instance.new("ImageLabel")
	playerImage.Name = "PlayerImage"
	playerImage.Size = UDim2.fromScale(0.25, 1)
	playerImage.Position = UDim2.fromScale(0, 0)
	playerImage.BackgroundTransparency = 1
	playerImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=420&h=420"
	playerImage.ScaleType = Enum.ScaleType.Crop
	playerImage.Parent = billboardGui

	local imageCorner = Instance.new("UICorner")
	imageCorner.CornerRadius = UDim.new(0.15, 0)
	imageCorner.Parent = playerImage

	-- Player name (right side)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(0.7, 1)
	nameLabel.Position = UDim2.fromScale(0.3, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = player.DisplayName
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextScaled = true
	nameLabel.Font = BOLD_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextWrapped = true
	nameLabel.Parent = billboardGui

	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MinTextSize = 24
	textSizeConstraint.MaxTextSize = 100
	textSizeConstraint.Parent = nameLabel

	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Color3.fromRGB(0, 0, 0)
	textStroke.Thickness = 3
	textStroke.Parent = nameLabel

	billboards[player] = billboardGui
end

--[[
	Remove billboard for a player
--]]
local function removeBillboard(player)
	local billboard = billboards[player]
	if billboard then
		billboard:Destroy()
		billboards[player] = nil
	end
end

--[[
	Update all billboards
--]]
local function updateBillboards()
	for _, player in pairs(Players:GetPlayers()) do
		if not billboards[player] then
			local playerDungeon = findPlayerDungeon(player)
			if playerDungeon then
				local centerPart = playerDungeon:FindFirstChild("CenterPart")
				if centerPart then
					createBillboard(player, centerPart)
				end
			end
		end
	end
end

--[[
	Initialize the PlayerBillboardManager
--]]
function PlayerBillboardManager:Initialize()
	if isInitialized then return end

	-- Handle player leaving
	Players.PlayerRemoving:Connect(removeBillboard)

	-- Start update loop
	local lastUpdate = 0
	updateConnection = RunService.Heartbeat:Connect(function()
		local currentTime = tick()
		if currentTime - lastUpdate >= UPDATE_INTERVAL then
			updateBillboards()
			lastUpdate = currentTime
		end
	end)

	-- Initial update
	updateBillboards()

	isInitialized = true
	print("PlayerBillboardManager: Initialized")
end

--[[
	Cleanup
--]]
function PlayerBillboardManager:Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	for _, billboard in pairs(billboards) do
		billboard:Destroy()
	end
	billboards = {}

	isInitialized = false
end

return PlayerBillboardManager
