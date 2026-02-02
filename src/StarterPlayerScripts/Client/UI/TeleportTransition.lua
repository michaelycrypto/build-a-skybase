--[[
	TeleportTransition.lua - Simple teleport screen
	Matches LoadingScreen design exactly - black screen, Upheaval text, progress bar
]]

local TeleportTransition = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CUSTOM_FONT_NAME = "Upheaval BRK"

-- State
local transitionGui = nil
local statusLabel = nil
local progressFill = nil
local isActive = false

local function createUI()
	if transitionGui then
		return
	end
	
	FontBinder.preload({ status = CUSTOM_FONT_NAME })
	
	transitionGui = Instance.new("ScreenGui")
	transitionGui.Name = "TeleportTransition"
	transitionGui.ResetOnSpawn = false
	transitionGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	transitionGui.DisplayOrder = 999
	transitionGui.IgnoreGuiInset = true
	transitionGui.Enabled = false
	transitionGui.Parent = playerGui
	
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 1
	backdrop.BorderSizePixel = 0
	backdrop.Parent = transitionGui
	
	local centerContainer = Instance.new("Frame")
	centerContainer.Name = "CenterContainer"
	centerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	centerContainer.Position = UDim2.fromScale(0.5, 0.5)
	centerContainer.Size = UDim2.fromOffset(240, 80)
	centerContainer.BackgroundTransparency = 1
	centerContainer.Parent = backdrop
	
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 20)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = centerContainer
	
	local uiTypography = Config.UI_SETTINGS and Config.UI_SETTINGS.typography
	local sizes = uiTypography and uiTypography.sizes
	local titleFontPx = (sizes and sizes.body and sizes.body.base) or 24
	
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 32)
	statusLabel.BackgroundTransparency = 1
	statusLabel.BorderSizePixel = 0
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextSize = titleFontPx
	statusLabel.Text = "Teleporting..."
	statusLabel.LayoutOrder = 1
	statusLabel.Parent = centerContainer
	
	FontBinder.apply(statusLabel, CUSTOM_FONT_NAME)
	
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressContainer"
	progressContainer.Size = UDim2.fromOffset(180, 4)
	progressContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressContainer.BackgroundTransparency = 0.75
	progressContainer.BorderSizePixel = 0
	progressContainer.LayoutOrder = 2
	progressContainer.Parent = centerContainer
	
	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressContainer
	
	progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.fromScale(0.3, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressContainer
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = progressFill
end

local function animateProgress()
	if not isActive or not progressFill then
		return
	end
	
	local slideRight = TweenService:Create(
		progressFill,
		TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Position = UDim2.fromScale(0.7, 0) }
	)
	
	slideRight.Completed:Connect(function()
		if not isActive or not progressFill then
			return
		end
		
		local slideLeft = TweenService:Create(
			progressFill,
			TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(0, 0) }
		)
		
		slideLeft.Completed:Connect(function()
			animateProgress()
		end)
		
		slideLeft:Play()
	end)
	
	slideRight:Play()
end

function TeleportTransition:Show(message)
	if isActive then
		return
	end
	
	createUI()
	isActive = true
	
	transitionGui.Enabled = true
	statusLabel.Text = message or "Teleporting..."
	progressFill.Position = UDim2.fromScale(0, 0)
	
	local backdrop = transitionGui:FindFirstChild("Backdrop")
	backdrop.BackgroundTransparency = 1
	
	TweenService:Create(backdrop, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	
	animateProgress()
end

function TeleportTransition:Hide(callback)
	if not isActive then
		if callback then
			callback()
		end
		return
	end
	
	isActive = false
	
	if not transitionGui then
		if callback then
			callback()
		end
		return
	end
	
	local backdrop = transitionGui:FindFirstChild("Backdrop")
	local tween = TweenService:Create(backdrop, TweenInfo.new(0.3), { BackgroundTransparency = 1 })
	
	tween.Completed:Connect(function()
		transitionGui.Enabled = false
		if callback then
			callback()
		end
	end)
	
	tween:Play()
end

function TeleportTransition:IsActive()
	return isActive
end

return TeleportTransition
