--[[
	BlockBreakProgress.lua
	Minimal, modern block break progress bar displayed below the crosshair.
	Shows progress when breaking blocks with smooth animations.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BlockBreakProgress = {}

-- Internal state
local progressContainer
local progressBar
local progressBarBackground
local lastUpdateTime = 0
local hideTimer = nil
local currentProgress = 0

-- Configuration
local BAR_WIDTH = 120				-- Width of progress bar in pixels
local BAR_HEIGHT = 6				-- Height of progress bar in pixels
local BAR_OFFSET_Y = 40				-- Distance below crosshair
local BAR_COLOR = Color3.fromRGB(85, 255, 255)		-- Vibrant cyan progress fill
local BAR_BG_COLOR = Color3.fromRGB(20, 20, 25)		-- Dark blue-gray background
local BAR_BORDER_COLOR = Color3.fromRGB(50, 50, 60)	-- Subtle border color
local CORNER_RADIUS = 3				-- Rounded corners
local FADE_IN_TIME = 0.1			-- How fast bar appears
local FADE_OUT_TIME = 0.2			-- How fast bar fades
local AUTO_HIDE_DELAY = 0.3			-- Hide after this many seconds of no updates

-- Tween info for smooth animations
local TWEEN_INFO_SHOW = TweenInfo.new(FADE_IN_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_INFO_HIDE = TweenInfo.new(FADE_OUT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_INFO_PROGRESS = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

-- Create rounded corner UI element
local function createCorner(parent)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CORNER_RADIUS)
	corner.Parent = parent
	return corner
end

-- Show the progress bar with smooth fade-in
local function showBar()
	if not progressContainer then return end

	-- Cancel any pending hide timer (use pcall to avoid errors if already completed)
	if hideTimer then
		pcall(function()
			task.cancel(hideTimer)
		end)
		hideTimer = nil
	end

	-- If already visible, don't animate again
	if progressContainer.Visible and progressContainer.GroupTransparency < 0.1 then
		return
	end

	progressContainer.Visible = true

	-- Smooth fade in
	local tween = TweenService:Create(progressContainer, TWEEN_INFO_SHOW, {
		GroupTransparency = 0
	})
	tween:Play()
end

-- Hide the progress bar with smooth fade-out
local function hideBar()
	if not progressContainer then return end
	if not progressContainer.Visible then return end

	-- Cancel any pending hide timer (use pcall to avoid errors if already completed)
	if hideTimer then
		pcall(function()
			task.cancel(hideTimer)
		end)
		hideTimer = nil
	end

	-- Smooth fade out
	local tween = TweenService:Create(progressContainer, TWEEN_INFO_HIDE, {
		GroupTransparency = 1
	})
	tween:Play()

	-- Hide after fade completes
	task.delay(FADE_OUT_TIME, function()
		if progressContainer then
			progressContainer.Visible = false
		end
	end)
end

-- Schedule auto-hide after delay
local function scheduleAutoHide()
	-- Cancel previous timer (use pcall to avoid errors if already completed)
	if hideTimer then
		pcall(function()
			task.cancel(hideTimer)
		end)
		hideTimer = nil
	end

	-- Schedule new hide
	hideTimer = task.delay(AUTO_HIDE_DELAY, function()
		hideBar()
		hideTimer = nil
	end)
end

-- Update progress bar fill
local function updateProgress(progress)
	if not progressBar then return end

	-- Clamp progress between 0 and 1
	progress = math.clamp(progress, 0, 1)
	currentProgress = progress

	-- Smooth transition to new width
	local targetSize = UDim2.new(progress, 0, 1, 0)
	local tween = TweenService:Create(progressBar, TWEEN_INFO_PROGRESS, {
		Size = targetSize
	})
	tween:Play()
end

-- Create the UI elements
function BlockBreakProgress:Create(parentHudGui)
	if progressContainer and progressContainer.Parent then return end

	-- Main container (CanvasGroup for GroupTransparency support)
	progressContainer = Instance.new("CanvasGroup")
	progressContainer.Name = "BlockBreakProgress"
	progressContainer.BackgroundTransparency = 1
	progressContainer.BorderSizePixel = 0
	progressContainer.AnchorPoint = Vector2.new(0.5, 0)
	progressContainer.Position = UDim2.new(0.5, 0, 0.5, BAR_OFFSET_Y)
	progressContainer.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
	progressContainer.ZIndex = 15
	progressContainer.Visible = false
	progressContainer.GroupTransparency = 1 -- Start invisible

	-- Parent to the HUD if provided; otherwise attach to PlayerGui
	if parentHudGui then
		progressContainer.Parent = parentHudGui
	else
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChild("PlayerGui") or nil
		if not playerGui then
			playerGui = player and player:WaitForChild("PlayerGui")
		end

		-- Create a dedicated ScreenGui for the progress bar
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "BlockBreakProgressGui"
		screenGui.ResetOnSpawn = false
		screenGui.IgnoreGuiInset = true
		screenGui.DisplayOrder = 10
		screenGui.Parent = playerGui

		progressContainer.Parent = screenGui
	end

	-- Background bar (dark, full width)
	progressBarBackground = Instance.new("Frame")
	progressBarBackground.Name = "Background"
	progressBarBackground.BackgroundColor3 = BAR_BG_COLOR
	progressBarBackground.BorderSizePixel = 0
	progressBarBackground.Size = UDim2.new(1, 0, 1, 0)
	progressBarBackground.Position = UDim2.new(0, 0, 0, 0)
	progressBarBackground.ZIndex = 15
	progressBarBackground.Parent = progressContainer
	createCorner(progressBarBackground)

	-- Subtle border for depth
	local border = Instance.new("UIStroke")
	border.Color = BAR_BORDER_COLOR
	border.Thickness = 1
	border.Transparency = 0.3
	border.Parent = progressBarBackground

	-- Progress fill bar (cyan, grows left to right)
	progressBar = Instance.new("Frame")
	progressBar.Name = "Fill"
	progressBar.BackgroundColor3 = BAR_COLOR
	progressBar.BorderSizePixel = 0
	progressBar.Size = UDim2.new(0, 0, 1, 0) -- Start at 0 width
	progressBar.Position = UDim2.new(0, 0, 0, 0)
	progressBar.ZIndex = 16
	progressBar.Parent = progressContainer
	createCorner(progressBar)

	-- Add subtle glow effect to the fill
	local fillGlow = Instance.new("UIStroke")
	fillGlow.Color = BAR_COLOR
	fillGlow.Thickness = 1
	fillGlow.Transparency = 0.5
	fillGlow.Parent = progressBar
end

-- Update the progress bar (called from BlockBreakProgress event)
function BlockBreakProgress:UpdateProgress(progress)
	if not progressContainer then return end

	lastUpdateTime = tick()

	-- Show bar if hidden
	showBar()

	-- Update the fill
	updateProgress(progress)

	-- If progress reaches 1, hide immediately after a brief moment
	if progress >= 1 then
		task.delay(0.15, function()
			hideBar()
			-- Reset progress after hiding
			task.delay(FADE_OUT_TIME, function()
				updateProgress(0)
			end)
		end)
	else
		-- Schedule auto-hide if no more updates
		scheduleAutoHide()
	end
end

-- Reset progress (useful when breaking is cancelled)
function BlockBreakProgress:Reset()
	updateProgress(0)
	hideBar()
end

-- Destroy the UI
function BlockBreakProgress:Destroy()
	if progressContainer then
		progressContainer:Destroy()
		progressContainer = nil
		progressBar = nil
		progressBarBackground = nil
	end

	if hideTimer then
		pcall(function()
			task.cancel(hideTimer)
		end)
		hideTimer = nil
	end
end

return BlockBreakProgress

