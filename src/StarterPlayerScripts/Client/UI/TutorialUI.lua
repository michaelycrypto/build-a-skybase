--[[
	TutorialUI.lua - Tutorial UI Components

	Renders tutorial popups, tooltips, objective trackers, and highlights.
	Beautiful, non-intrusive UI that guides new players.

	Integration:
	- Uses UIBackdrop for modal popups (blur + overlay + mouse release)
	- Uses InputService for cursor management
	- Tooltips/Objectives are overlay-only (don't block gameplay)
]]

local TutorialUI = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Load dependencies
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local UIBackdrop = require(script.Parent.UIBackdrop)

-- Config
local Config = require(ReplicatedStorage.Shared.Config)
local UI_SETTINGS = Config.UI_SETTINGS
local Typography = UI_SETTINGS and UI_SETTINGS.typography or {}
local Fonts = Typography.fonts or {}
local BOLD_FONT = Fonts.bold or Enum.Font.GothamBold
local REGULAR_FONT = Fonts.regular or Enum.Font.Gotham

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Try to get InputService for cursor management
local InputService = nil
pcall(function()
	InputService = require(script.Parent.Parent.Input.InputService)
end)

-- UI State
local tutorialGui = nil
local activePopup = nil
local activeTooltip = nil
local activeObjective = nil
local activeHighlights = {}
local overlayReleaseFunc = nil  -- For InputService overlay management

-- Colors (matching game theme)
local COLORS = {
	primary = Color3.fromRGB(59, 130, 246),      -- Blue
	primaryDark = Color3.fromRGB(37, 99, 235),
	secondary = Color3.fromRGB(255, 215, 0),     -- Gold
	background = Color3.fromRGB(15, 23, 42),     -- Dark slate
	backgroundLight = Color3.fromRGB(30, 41, 59),
	text = Color3.fromRGB(255, 255, 255),
	textMuted = Color3.fromRGB(148, 163, 184),
	success = Color3.fromRGB(34, 197, 94),
	border = Color3.fromRGB(71, 85, 105),
}

-- Animation config
local ANIMATION = {
	fadeIn = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	fadeOut = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
	pulse = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	slideIn = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
}

--[[
	Initialize the tutorial UI container
]]
function TutorialUI:Initialize()
	if tutorialGui then return end

	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "TutorialUI"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialGui.DisplayOrder = 150  -- Above HUD but below modal panels
	tutorialGui.IgnoreGuiInset = false  -- Respect top bar
	tutorialGui.Parent = playerGui
end

--[[
	Create a styled frame with rounded corners and optional border
]]
local function createStyledFrame(props)
	local frame = Instance.new("Frame")
	frame.Name = props.name or "StyledFrame"
	frame.Size = props.size or UDim2.new(0, 300, 0, 150)
	frame.Position = props.position or UDim2.new(0.5, -150, 0.5, -75)
	frame.AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = props.backgroundColor or COLORS.background
	frame.BackgroundTransparency = props.backgroundTransparency or 0
	frame.BorderSizePixel = 0
	frame.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, props.cornerRadius or 12)
	corner.Parent = frame

	if props.border then
		local stroke = Instance.new("UIStroke")
		stroke.Color = props.borderColor or COLORS.border
		stroke.Thickness = props.borderThickness or 1
		stroke.Transparency = 0.5
		stroke.Parent = frame
	end

	if props.shadow then
		local shadow = Instance.new("Frame")
		shadow.Name = "Shadow"
		shadow.Size = UDim2.new(1, 10, 1, 10)
		shadow.Position = UDim2.new(0, -5, 0, 3)
		shadow.AnchorPoint = Vector2.new(0, 0)
		shadow.BackgroundColor3 = Color3.new(0, 0, 0)
		shadow.BackgroundTransparency = 0.7
		shadow.ZIndex = frame.ZIndex - 1
		shadow.Parent = frame

		local shadowCorner = Instance.new("UICorner")
		shadowCorner.CornerRadius = UDim.new(0, (props.cornerRadius or 12) + 2)
		shadowCorner.Parent = shadow
	end

	return frame
end

--[[
	Create a text label with consistent styling
]]
local function createLabel(props)
	local label = Instance.new("TextLabel")
	label.Name = props.name or "Label"
	label.Size = props.size or UDim2.new(1, -24, 0, 24)
	label.Position = props.position or UDim2.new(0, 12, 0, 12)
	label.BackgroundTransparency = 1
	label.Text = props.text or ""
	label.TextColor3 = props.color or COLORS.text
	label.TextSize = props.textSize or 16
	label.Font = props.font or REGULAR_FONT
	label.TextXAlignment = props.alignX or Enum.TextXAlignment.Left
	label.TextYAlignment = props.alignY or Enum.TextYAlignment.Top
	label.TextWrapped = props.wrapped ~= false
	label.RichText = props.richText or false
	label.Parent = props.parent
	return label
end

--[[
	Create a button with consistent styling
]]
local function createButton(props)
	local button = Instance.new("TextButton")
	button.Name = props.name or "Button"
	button.Size = props.size or UDim2.new(0, 120, 0, 36)
	button.Position = props.position or UDim2.new(0.5, -60, 1, -48)
	button.AnchorPoint = props.anchorPoint or Vector2.new(0.5, 0)
	button.BackgroundColor3 = props.backgroundColor or COLORS.primary
	button.BorderSizePixel = 0
	button.Text = props.text or "Continue"
	button.TextColor3 = props.textColor or COLORS.text
	button.TextSize = props.textSize or 14
	button.Font = props.font or BOLD_FONT
	button.AutoButtonColor = true
	button.Parent = props.parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button

	-- Hover effect
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundColor3 = props.hoverColor or COLORS.primaryDark
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {
			BackgroundColor3 = props.backgroundColor or COLORS.primary
		}):Play()
	end)

	return button
end

--[[
	Show a welcome/celebration popup (MODAL - blocks input)
	Uses UIBackdrop for proper camera freeze and cursor release
	@param step: table - The tutorial step data
]]
function TutorialUI:ShowPopup(step)
	self:Initialize()
	self:HidePopup()

	-- Use UIBackdrop for proper modal behavior (overlay, cursor release)
	UIBackdrop:Show({
		overlay = true,
		overlayColor = Color3.fromRGB(4, 4, 6),
		overlayTransparency = 0.5,
		displayOrder = 149,  -- Below the popup
		persist = true,
	})

	-- Use InputService overlay mode for proper cursor + gameplay lock
	if InputService and InputService.BeginOverlay then
		overlayReleaseFunc = InputService:BeginOverlay("TutorialPopup")
	end

	-- Popup container (on top of backdrop)
	local popup = createStyledFrame({
		name = "TutorialPopup",
		size = UDim2.new(0, 420, 0, 280),
		position = UDim2.new(0.5, 0, 0.5, 0),
		parent = tutorialGui,
		shadow = true,
		border = true,
	})
	popup.BackgroundTransparency = 1
	popup.ZIndex = 10

	-- Icon/emoji
	local iconLabel = createLabel({
		name = "Icon",
		text = step.id == "tutorial_complete" and "🎉" or "⭐",
		textSize = 48,
		size = UDim2.new(1, 0, 0, 60),
		position = UDim2.new(0, 0, 0, 20),
		alignX = Enum.TextXAlignment.Center,
		parent = popup,
	})

	-- Title
	local titleLabel = createLabel({
		name = "Title",
		text = step.title,
		textSize = 24,
		font = BOLD_FONT,
		size = UDim2.new(1, -40, 0, 36),
		position = UDim2.new(0, 20, 0, 85),
		alignX = Enum.TextXAlignment.Center,
		parent = popup,
	})

	-- Description
	local descLabel = createLabel({
		name = "Description",
		text = step.description,
		textSize = 16,
		color = COLORS.textMuted,
		size = UDim2.new(1, -40, 0, 60),
		position = UDim2.new(0, 20, 0, 125),
		alignX = Enum.TextXAlignment.Center,
		parent = popup,
	})

	-- Hint
	if step.hint then
		local hintLabel = createLabel({
			name = "Hint",
			text = "💡 " .. step.hint,
			textSize = 14,
			color = COLORS.secondary,
			size = UDim2.new(1, -40, 0, 40),
			position = UDim2.new(0, 20, 0, 185),
			alignX = Enum.TextXAlignment.Center,
			parent = popup,
		})
	end

	-- Continue button
	local continueButton = createButton({
		name = "ContinueButton",
		text = step.id == "tutorial_complete" and "Start Playing!" or "Got it!",
		size = UDim2.new(0, 140, 0, 40),
		position = UDim2.new(0.5, 0, 1, -20),
		anchorPoint = Vector2.new(0.5, 1),
		parent = popup,
	})

	continueButton.MouseButton1Click:Connect(function()
		self:HidePopup()
		EventManager:SendToServer("CompleteTutorialStep", {stepId = step.id})
	end)

	-- Skip button (if allowed)
	if step.canSkip then
		local skipButton = createButton({
			name = "SkipButton",
			text = "Skip Tutorial",
			size = UDim2.new(0, 100, 0, 30),
			position = UDim2.new(1, -10, 0, 10),
			anchorPoint = Vector2.new(1, 0),
			backgroundColor = Color3.fromRGB(71, 85, 105),
			textSize = 12,
			parent = popup,
		})

		skipButton.MouseButton1Click:Connect(function()
			self:HidePopup()
			EventManager:SendToServer("SkipTutorial")
		end)
	end

	-- Animate in
	popup.Position = UDim2.new(0.5, 0, 0.6, 0)
	popup.BackgroundTransparency = 1

	TweenService:Create(popup, ANIMATION.slideIn, {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		BackgroundTransparency = 0
	}):Play()

	activePopup = {popup = popup}
end

--[[
	Hide the popup and restore input/camera state
]]
function TutorialUI:HidePopup()
	-- Only clean up if there was actually an active popup
	-- This prevents interfering with UIBackdrop used by other systems (UIVisibilityManager, etc.)
	if not activePopup and not overlayReleaseFunc then
		return
	end

	if activePopup then
		TweenService:Create(activePopup.popup, ANIMATION.fadeOut, {BackgroundTransparency = 1}):Play()

		local popup = activePopup
		task.delay(0.2, function()
			if popup.popup then popup.popup:Destroy() end
		end)
		activePopup = nil

		-- Only hide backdrop if we showed one for this popup
		UIBackdrop:Hide()
	end

	-- Release input overlay (restores cursor and gameplay)
	if overlayReleaseFunc then
		overlayReleaseFunc()
		overlayReleaseFunc = nil
	end
end

--[[
	Show a tooltip for hints (NON-MODAL - doesn't block gameplay)
	@param step: table - The tutorial step data
]]
function TutorialUI:ShowTooltip(step)
	self:Initialize()
	self:HideTooltip()

	local tooltip = createStyledFrame({
		name = "TutorialTooltip",
		size = UDim2.new(0, 320, 0, 100),
		position = UDim2.new(0.5, 0, 0, 100),
		parent = tutorialGui,
		border = true,
		cornerRadius = 10,
	})
	tooltip.BackgroundTransparency = 1

	-- Glow effect
	local glow = Instance.new("UIStroke")
	glow.Color = COLORS.secondary
	glow.Thickness = 2
	glow.Transparency = 0.5
	glow.Parent = tooltip

	-- Title
	local titleLabel = createLabel({
		name = "Title",
		text = "💡 " .. step.title,
		textSize = 16,
		font = BOLD_FONT,
		color = COLORS.secondary,
		size = UDim2.new(1, -20, 0, 24),
		position = UDim2.new(0, 10, 0, 10),
		parent = tooltip,
	})

	-- Hint text
	local hintLabel = createLabel({
		name = "Hint",
		text = step.hint or step.description,
		textSize = 14,
		color = COLORS.textMuted,
		size = UDim2.new(1, -20, 0, 50),
		position = UDim2.new(0, 10, 0, 38),
		parent = tooltip,
	})

	-- Skip text (if allowed)
	if step.canSkip then
		local skipHint = createLabel({
			name = "SkipHint",
			text = "[Press Tab to skip]",
			textSize = 11,
			color = COLORS.border,
			size = UDim2.new(1, -20, 0, 16),
			position = UDim2.new(0, 10, 1, -22),
			alignX = Enum.TextXAlignment.Right,
			parent = tooltip,
		})
	end

	-- Resize to fit content
	tooltip.Size = UDim2.new(0, 320, 0, step.canSkip and 100 or 85)

	-- Animate in
	tooltip.Position = UDim2.new(0.5, 0, 0, -50)
	tooltip.BackgroundTransparency = 1

	TweenService:Create(tooltip, ANIMATION.slideIn, {
		Position = UDim2.new(0.5, 0, 0, 100),
		BackgroundTransparency = 0
	}):Play()

	-- Pulsing glow animation
	local pulseConn = RunService.Heartbeat:Connect(function(dt)
		local t = tick() * 2
		glow.Transparency = 0.3 + math.sin(t) * 0.2
	end)

	activeTooltip = {frame = tooltip, pulseConnection = pulseConn}
end

--[[
	Hide the tooltip
]]
function TutorialUI:HideTooltip()
	if activeTooltip then
		if activeTooltip.pulseConnection then
			activeTooltip.pulseConnection:Disconnect()
		end

		TweenService:Create(activeTooltip.frame, ANIMATION.fadeOut, {BackgroundTransparency = 1}):Play()

		local tooltip = activeTooltip
		task.delay(0.2, function()
			if tooltip.frame then tooltip.frame:Destroy() end
		end)
		activeTooltip = nil
	end
end

--[[
	Show an objective tracker (NON-MODAL - doesn't block gameplay)
	@param step: table - The tutorial step data
]]
function TutorialUI:ShowObjective(step)
	self:Initialize()
	self:HideObjective()

	local objective = createStyledFrame({
		name = "TutorialObjective",
		size = UDim2.new(0, 280, 0, 90),
		position = UDim2.new(1, -20, 0.3, 0),
		anchorPoint = Vector2.new(1, 0),
		parent = tutorialGui,
		border = true,
		cornerRadius = 8,
	})
	objective.BackgroundTransparency = 1

	-- Header with icon
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = COLORS.primaryDark
	header.BackgroundTransparency = 0.3
	header.BorderSizePixel = 0
	header.Parent = objective

	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = header

	-- Fix corner rounding (only top corners rounded)
	local headerFix = Instance.new("Frame")
	headerFix.Size = UDim2.new(1, 0, 0.5, 0)
	headerFix.Position = UDim2.new(0, 0, 0.5, 0)
	headerFix.BackgroundColor3 = COLORS.primaryDark
	headerFix.BackgroundTransparency = 0.3
	headerFix.BorderSizePixel = 0
	headerFix.Parent = header

	local headerLabel = createLabel({
		name = "HeaderText",
		text = "📋 OBJECTIVE",
		textSize = 11,
		font = BOLD_FONT,
		color = COLORS.textMuted,
		size = UDim2.new(1, -16, 1, 0),
		position = UDim2.new(0, 8, 0, 0),
		alignY = Enum.TextYAlignment.Center,
		parent = header,
	})

	-- Task title
	local titleLabel = createLabel({
		name = "Title",
		text = step.title,
		textSize = 15,
		font = BOLD_FONT,
		size = UDim2.new(1, -16, 0, 22),
		position = UDim2.new(0, 8, 0, 32),
		parent = objective,
	})

	-- Task description/hint
	local descLabel = createLabel({
		name = "Description",
		text = step.hint or step.description,
		textSize = 12,
		color = COLORS.textMuted,
		size = UDim2.new(1, -16, 0, 30),
		position = UDim2.new(0, 8, 0, 54),
		parent = objective,
	})

	-- Progress bar (if applicable)
	if step.objective and step.objective.count and step.objective.count > 1 then
		objective.Size = UDim2.new(0, 280, 0, 110)

		-- Progress text label (shows "0/4" format)
		local progressText = createLabel({
			name = "ProgressText",
			text = string.format("0/%d", step.objective.count),
			textSize = 11,
			font = BOLD_FONT,
			color = COLORS.textMuted,
			size = UDim2.new(1, -16, 0, 14),
			position = UDim2.new(0, 8, 1, -28),
			alignX = Enum.TextXAlignment.Right,
			parent = objective,
		})

		local progressBg = Instance.new("Frame")
		progressBg.Name = "ProgressBg"
		progressBg.Size = UDim2.new(1, -16, 0, 6)
		progressBg.Position = UDim2.new(0, 8, 1, -14)
		progressBg.AnchorPoint = Vector2.new(0, 1)
		progressBg.BackgroundColor3 = COLORS.backgroundLight
		progressBg.Parent = objective

		local progressBgCorner = Instance.new("UICorner")
		progressBgCorner.CornerRadius = UDim.new(0, 3)
		progressBgCorner.Parent = progressBg

		local progressFill = Instance.new("Frame")
		progressFill.Name = "ProgressFill"
		progressFill.Size = UDim2.new(0, 0, 1, 0)
		progressFill.BackgroundColor3 = COLORS.success
		progressFill.Parent = progressBg

		local progressFillCorner = Instance.new("UICorner")
		progressFillCorner.CornerRadius = UDim.new(0, 3)
		progressFillCorner.Parent = progressFill
	end

	-- Animate in
	objective.Position = UDim2.new(1, 50, 0.3, 0)
	objective.BackgroundTransparency = 1

	TweenService:Create(objective, ANIMATION.slideIn, {
		Position = UDim2.new(1, -20, 0.3, 0),
		BackgroundTransparency = 0
	}):Play()

	activeObjective = {frame = objective}
end

--[[
	Update progress bar in objective tracker
]]
function TutorialUI:UpdateProgress(step, progressData)
	if not activeObjective or not activeObjective.frame then
		warn("[TutorialUI] UpdateProgress: No active objective frame")
		return
	end

	local progressBg = activeObjective.frame:FindFirstChild("ProgressBg")
	if not progressBg then
		warn("[TutorialUI] UpdateProgress: No ProgressBg found")
		return
	end

	local progressFill = progressBg:FindFirstChild("ProgressFill")
	local progressText = activeObjective.frame:FindFirstChild("ProgressText")

	if progressFill and step.objective and step.objective.count then
		local current = progressData.count or 0
		local target = step.objective.count
		local percent = math.clamp(current / target, 0, 1)

		-- Update progress bar
		TweenService:Create(progressFill, TweenInfo.new(0.3), {
			Size = UDim2.new(percent, 0, 1, 0)
		}):Play()

		-- Update progress text label
		if progressText then
			progressText.Text = string.format("%d/%d", current, target)
		end
	else
		if not progressFill then
			warn("[TutorialUI] UpdateProgress: No ProgressFill found")
		end
		if not step.objective then
			warn("[TutorialUI] UpdateProgress: No step.objective")
		end
		if not step.objective or not step.objective.count then
			warn("[TutorialUI] UpdateProgress: No step.objective.count")
		end
	end
end

--[[
	Hide the objective tracker
]]
function TutorialUI:HideObjective()
	if activeObjective then
		TweenService:Create(activeObjective.frame, ANIMATION.fadeOut, {
			Position = UDim2.new(1, 50, 0.3, 0),
			BackgroundTransparency = 1
		}):Play()

		local obj = activeObjective
		task.delay(0.2, function()
			if obj.frame then obj.frame:Destroy() end
		end)
		activeObjective = nil
	end
end

--[[
	Highlight specific block types in the world (visual indicator)
]]
function TutorialUI:HighlightBlockTypes(blockTypes)
	-- This is a placeholder - actual world highlighting would require
	-- integration with the voxel rendering system
	-- For now, we just store the highlight request
	activeHighlights.blockTypes = blockTypes
end

--[[
	Highlight a keyboard key
]]
function TutorialUI:HighlightKey(keyName)
	self:Initialize()

	-- Remove existing key hint
	if activeHighlights.keyHint then
		activeHighlights.keyHint:Destroy()
		activeHighlights.keyHint = nil
	end

	-- Create a key hint overlay
	local keyHint = createStyledFrame({
		name = "KeyHint",
		size = UDim2.new(0, 60, 0, 60),
		position = UDim2.new(0.5, 0, 0.7, 0),
		parent = tutorialGui,
		backgroundColor = COLORS.backgroundLight,
		border = true,
		cornerRadius = 8,
	})

	local keyLabel = createLabel({
		name = "KeyLabel",
		text = keyName,
		textSize = 24,
		font = BOLD_FONT,
		size = UDim2.new(1, 0, 1, 0),
		alignX = Enum.TextXAlignment.Center,
		alignY = Enum.TextYAlignment.Center,
		parent = keyHint,
	})

	-- Pulsing animation
	local glow = Instance.new("UIStroke")
	glow.Color = COLORS.secondary
	glow.Thickness = 3
	glow.Parent = keyHint

	TweenService:Create(glow, ANIMATION.pulse, {
		Transparency = 0.7
	}):Play()

	activeHighlights.keyHint = keyHint
end

--[[
	Highlight a UI element by name
]]
function TutorialUI:HighlightUIElement(elementName)
	-- This would require finding the element in the UI hierarchy
	-- and adding a highlight overlay
	activeHighlights.uiElement = elementName
end

--[[
	Hide all highlights
]]
function TutorialUI:ClearHighlights()
	if activeHighlights.keyHint then
		activeHighlights.keyHint:Destroy()
	end
	activeHighlights = {}
end

--[[
	Hide all tutorial UI
]]
function TutorialUI:HideAll()
	self:HidePopup()
	self:HideTooltip()
	self:HideObjective()
	self:ClearHighlights()
end

--[[
	Cleanup
]]
function TutorialUI:Cleanup()
	self:HideAll()
	if tutorialGui then
		tutorialGui:Destroy()
		tutorialGui = nil
	end
end

return TutorialUI
