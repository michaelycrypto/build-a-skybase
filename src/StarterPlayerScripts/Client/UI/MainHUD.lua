--[[
	MainHUD.lua - Simplified Main HUD with Clean Design
	Features essential stats display and menu functionality
--]]

local MainHUD = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local _GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _InputService = require(script.Parent.Parent.Input.InputService)

-- Import dependencies
local _EventManager = require(ReplicatedStorage.Shared.EventManager)
local _RewardsApi = require(ReplicatedStorage.Shared.Api.RewardsApi)
local _QuestsApi = require(ReplicatedStorage.Shared.Api.QuestsApi)
local Config = require(ReplicatedStorage.Shared.Config)
local GameState = require(script.Parent.Parent.Managers.GameState)
local _UIManager = require(script.Parent.Parent.Managers.UIManager)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local PanelManager = require(script.Parent.Parent.Managers.PanelManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local _UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local Crosshair = require(script.Parent.Crosshair)
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

-- Services and instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local hudGui
local moneyLabel
local gemsLabel

-- UI State
local menuButtons = {}
local activeWiggleTweens = {}
local buttonCooldowns = {}
local currentValues = {coins = 0, gems = 0}

-- Quests badge state
local questBadge
local questConfigState = nil
local playerQuestsState = nil
local dailyBadge
local BADGE_SIZE = 16
local DAILY_BADGE_SIZE = 12
local DEFAULT_ICON_SIZE = 56
local ACTIVE_ICON_SIZE = 64
local HOVER_ICON_SIZE = 68

local function hasActiveBadgeForButton(buttonObj)
	if not buttonObj or not buttonObj.button then
		return false
	end
	local label = buttonObj.button:FindFirstChild("ButtonText")
	local candidates = {
		label and label:FindFirstChild("QuestsBadge"),
		label and label:FindFirstChild("DailyBadge"),
		buttonObj.button:FindFirstChild("QuestsBadge"),
		buttonObj.button:FindFirstChild("DailyBadge")
	}
	for _, badge in ipairs(candidates) do
		if badge and badge:IsA("GuiObject") and badge.Visible then
			return true
		end
	end
	return false
end

local function getBaseIconSizeForButton(buttonObj)
	return hasActiveBadgeForButton(buttonObj) and ACTIVE_ICON_SIZE or DEFAULT_ICON_SIZE
end

local function _tweenIconSize(icon, sizePx)
	if not icon then
		return
	end
	TweenService:Create(icon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(sizePx, sizePx)
	}):Play()
end

local function popIcon(icon, baseSize)
	if not icon then
		return
	end
	local overshoot = baseSize + 6
	local tweenUp = TweenService:Create(icon, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(overshoot, overshoot)
	})
	local tweenDown = TweenService:Create(icon, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(baseSize, baseSize)
	})
	tweenUp:Play()
	tweenUp.Completed:Connect(function()
		tweenDown:Play()
	end)
end

local function setIconActiveForButton(buttonObj, active)
	if not buttonObj or not buttonObj.icon then
		return
	end
	local target = active and ACTIVE_ICON_SIZE or DEFAULT_ICON_SIZE
	TweenService:Create(buttonObj.icon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(target, target)
	}):Play()

	-- Replace pulse with constant wiggle rotation
	if activeWiggleTweens[buttonObj.icon] then
		activeWiggleTweens[buttonObj.icon]:Cancel()
		activeWiggleTweens[buttonObj.icon] = nil
	end

	if active then
		popIcon(buttonObj.icon, target)
		buttonObj.icon.Rotation = -4
		local wiggleTween = TweenService:Create(
			buttonObj.icon,
			TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0),
			{ Rotation = 4 }
		)
		activeWiggleTweens[buttonObj.icon] = wiggleTween
		wiggleTween:Play()
	else
		buttonObj.icon.Rotation = 0
	end
end
local function findQuestsButton()
	for _, data in ipairs(menuButtons) do
		if data.text == "Quests" and data.buttonObj then
			return data.buttonObj
		end
	end
	return nil
end

local function ensureQuestBadge()
	if questBadge and questBadge.Parent and questBadge.Parent.Parent then
		return questBadge
	end
	local questsButtonObj = findQuestsButton()
	if not questsButtonObj or not questsButtonObj.button then
		return nil
	end

	local parent = questsButtonObj.button:FindFirstChild("ButtonText") or questsButtonObj.button
	local badge = Instance.new("Frame")
	badge.Name = "QuestsBadge"
	badge.Size = UDim2.fromOffset(BADGE_SIZE, BADGE_SIZE)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(1, 6, 0.5, -4)
	badge.BackgroundColor3 = Color3.fromRGB(220, 38, 38) -- Attention red
	badge.BackgroundTransparency = 0
	badge.BorderSizePixel = 0
	badge.ZIndex = ((parent and parent:IsA("GuiObject") and parent.ZIndex) or 2) + 1
	badge.Visible = false
	badge.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	-- Add 1px black stroke for clarity
	local qStroke = Instance.new("UIStroke")
	qStroke.Color = Color3.fromRGB(0, 0, 0)
	qStroke.Thickness = 1
	qStroke.Parent = badge

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "0"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.Font = BOLD_FONT
	label.ZIndex = badge.ZIndex + 1
	label.Parent = badge

	questBadge = badge
	return questBadge
end

local function _setQuestsBadgeCount(count)
	local badge = ensureQuestBadge()
	if not badge then
		return
	end
	local label = badge:FindFirstChild("Label")
	if count and count > 0 then
		badge.Visible = true
		if label and label:IsA("TextLabel") then
			label.Text = (count > 99) and "99" or tostring(count)
		end
		local btn = findQuestsButton()
		setIconActiveForButton(btn, true)
	else
		badge.Visible = false
		local btn = findQuestsButton()
		setIconActiveForButton(btn, false)
	end
end

local function findDailyButton()
	for _, data in ipairs(menuButtons) do
		if data.text == "Daily Rewards" and data.buttonObj then
			return data.buttonObj
		end
	end
	return nil
end

local function ensureDailyBadge()
	if dailyBadge and dailyBadge.Parent and dailyBadge.Parent.Parent then
		return dailyBadge
	end
	local dailyButtonObj = findDailyButton()
	if not dailyButtonObj or not dailyButtonObj.button then
		return nil
	end

	local parent = dailyButtonObj.button:FindFirstChild("ButtonText") or dailyButtonObj.button
	local badge = Instance.new("Frame")
	badge.Name = "DailyBadge"
	badge.Size = UDim2.fromOffset(DAILY_BADGE_SIZE, DAILY_BADGE_SIZE)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(1, -3, 0.5, -3)
	badge.BackgroundColor3 = Color3.fromRGB(34, 197, 94) -- Green dot for available
	badge.BackgroundTransparency = 0
	badge.BorderSizePixel = 0
	badge.ZIndex = ((parent and parent:IsA("GuiObject") and parent.ZIndex) or 2) + 1
	badge.Visible = false
	badge.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = badge

	-- Add 1px black stroke for clarity
	local dStroke = Instance.new("UIStroke")
	dStroke.Color = Color3.fromRGB(0, 0, 0)
	dStroke.Thickness = 1
	dStroke.Parent = badge

	dailyBadge = badge
	return dailyBadge
end

local function _setDailyBadgeAvailable(isAvailable)
	local badge = ensureDailyBadge()
	if not badge then
		return
	end
	badge.Visible = isAvailable and true or false
	local btn = findDailyButton()
	-- Daily: do not wiggle on availability; only show size change
	if btn and btn.icon then
		local target = isAvailable and ACTIVE_ICON_SIZE or DEFAULT_ICON_SIZE
		TweenService:Create(btn.icon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(target, target)
		}):Play()
		-- Manage wiggle: start when available, stop when not
		if activeWiggleTweens[btn.icon] then
			activeWiggleTweens[btn.icon]:Cancel()
			activeWiggleTweens[btn.icon] = nil
		end
		if isAvailable then
			btn.icon.Rotation = -4
			local wiggleTween = TweenService:Create(
				btn.icon,
				TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0),
				{ Rotation = 4 }
			)
			activeWiggleTweens[btn.icon] = wiggleTween
			wiggleTween:Play()
		else
			btn.icon.Rotation = 0
		end
	end
	-- No daily badge pulse on availability per spec
end

local function _getClaimableQuestCount()
	if not questConfigState or not questConfigState.Mobs then
		return 0
	end
	local quests = playerQuestsState or {mobs = {}}
	local total = 0
	for mobType, mobConfig in pairs(questConfigState.Mobs) do
		local mobData = (quests.mobs and quests.mobs[mobType]) or {kills = 0, claimed = {}}
		-- Determine next unclaimed milestone
		local sortedMilestones = {}
		for _, milestone in ipairs(mobConfig.milestones or {}) do
			table.insert(sortedMilestones, milestone)
		end
		table.sort(sortedMilestones, function(a, b) return a < b end)
		local nextMilestone = nil
		for _, milestone in ipairs(sortedMilestones) do
			local claimed = mobData.claimed and mobData.claimed[tostring(milestone)]
			if not claimed then
				nextMilestone = milestone
				break
			end
		end
		if nextMilestone then
			local kills = mobData.kills or 0
			if kills >= nextMilestone then
				total = total + 1
			end
		end
	end
	return total
end

-- Constants
local _SIDEBAR_WIDTH = 76  -- 68px button + 4px padding each side (fixed width)
local _STATS_WIDTH = 280
local _STATS_HEIGHT = 100
local BUTTON_SIZE = 68 -- Button size including frame (back to original)
local _CONTENT_PADDING = 4 -- Padding inside containers

-- Simple animations for where still needed
local _RunService = game:GetService("RunService")
local _subtleTween = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)



--[[
	Create the main HUD
--]]
function MainHUD:Create()
	-- Create main HUD ScreenGui
	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "MainHUD"
	hudGui.ResetOnSpawn = false
	hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hudGui.IgnoreGuiInset = true
	hudGui.Parent = playerGui

	-- Add responsive scaling (100% = original size)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080)) -- 1920x1080 for 100% original size
	uiScale.Parent = hudGui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create components
	-- NOTE: Currency display moved to ActionBar for better UX
	-- self:CreateBottomLeftCurrency()

	-- Center crosshair (Minecraft-style)
	Crosshair:Create(hudGui)

	-- Initialize PanelManager
	PanelManager:Initialize()

	-- Connect to game state
	self:ConnectToGameState()

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("mainHUD", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 10
	})

	-- Badge and quest/daily tracking removed for simplified mobile UI
end


--[[
	Create bottom left currency display (money and gems)
--]]
function MainHUD:CreateBottomLeftCurrency()
	-- Container for currency displays in bottom left
	local currencyContainer = Instance.new("Frame")
	currencyContainer.Name = "BottomLeftCurrency"
	currencyContainer.Size = UDim2.fromOffset(340, 140) -- Larger to accommodate 64px text
	currencyContainer.AnchorPoint = Vector2.new(0, 1) -- Anchor to bottom-left
	currencyContainer.Position = UDim2.new(0, 4, 1, -4) -- 4px from bottom and left edges
	currencyContainer.BackgroundTransparency = 1
	currencyContainer.Parent = hudGui

	-- Add UIScale for independent scaling of currency display
	local currencyScale = Instance.new("UIScale")
	currencyScale.Name = "CurrencyScale"
	currencyScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	currencyScale:SetAttribute("min_scale", 0.6)  -- Allow smaller scaling on mobile
	currencyScale:SetAttribute("max_scale", 1.2)  -- Cap max size
	currencyScale.Parent = currencyContainer
	CollectionService:AddTag(currencyScale, "scale_component")

	-- Ultra-minimal padding with no bottom padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 1)
	padding.PaddingBottom = UDim.new(0, 0) -- No bottom padding
	padding.PaddingLeft = UDim.new(0, 2)
	padding.PaddingRight = UDim.new(0, 2)
	padding.Parent = currencyContainer

	-- Vertical layout for stacking gems above money
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, -5) -- Negative spacing to bring items closer
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = currencyContainer

	-- Gems display (positioned above money)
	local gemsContainer = Instance.new("Frame")
	gemsContainer.Name = "GemsContainer"
	gemsContainer.Size = UDim2.new(1, 0, 0, 70) -- Height for 64px text and icons
	gemsContainer.BackgroundTransparency = 1
	gemsContainer.LayoutOrder = 1
	gemsContainer.Parent = currencyContainer

	-- Horizontal layout for gem icon and value
	local gemsLayout = Instance.new("UIListLayout")
	gemsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gemsLayout.Padding = UDim.new(0, 5) -- 5px spacing between icon and text
	gemsLayout.FillDirection = Enum.FillDirection.Horizontal
	gemsLayout.VerticalAlignment = Enum.VerticalAlignment.Center -- Center icons with text
	gemsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gemsLayout.Parent = gemsContainer

	-- Create gem icon
	local gemIcon = IconManager:CreateIcon(gemsContainer, "Currency", "Gem", {
		size = UDim2.fromOffset(48, 48) -- 48px icon size
	})
	if gemIcon then
		gemIcon.LayoutOrder = 1
	end

	gemsLabel = Instance.new("TextLabel")
	gemsLabel.Name = "GemsLabel"
	gemsLabel.Size = UDim2.new(0, 100, 1, 0) -- Fixed width for text
	gemsLabel.BackgroundTransparency = 1
	gemsLabel.Text = "<b><i>0</i></b>"
	gemsLabel.RichText = true -- Enable RichText for bold+italic
	gemsLabel.TextColor3 = Config.UI_SETTINGS.colors.semantic.game.gems -- Purple gems color
	gemsLabel.TextSize = 64 -- Massive text size
	gemsLabel.Font = BOLD_FONT -- Base font for RichText
	gemsLabel.TextXAlignment = Enum.TextXAlignment.Left
	gemsLabel.TextYAlignment = Enum.TextYAlignment.Center
	gemsLabel.TextStrokeTransparency = 0 -- Maximum opacity for thickest stroke
	gemsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	gemsLabel.LayoutOrder = 2
	gemsLabel.Parent = gemsContainer

	-- Add extra thick UIStroke for gems
	local gemsStroke = Instance.new("UIStroke")
	gemsStroke.Color = Color3.fromRGB(0, 0, 0)
	gemsStroke.Thickness = 2 -- Medium stroke thickness
	gemsStroke.Parent = gemsLabel

	-- Money display (positioned at bottom)
	local moneyContainer = Instance.new("Frame")
	moneyContainer.Name = "MoneyContainer"
	moneyContainer.Size = UDim2.new(1, 0, 0, 70) -- Height for 64px text and icons
	moneyContainer.BackgroundTransparency = 1
	moneyContainer.LayoutOrder = 2
	moneyContainer.Parent = currencyContainer

	-- Horizontal layout for money icon and value
	local moneyLayout = Instance.new("UIListLayout")
	moneyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	moneyLayout.Padding = UDim.new(0, 5) -- 5px spacing between icon and text
	moneyLayout.FillDirection = Enum.FillDirection.Horizontal
	moneyLayout.VerticalAlignment = Enum.VerticalAlignment.Center -- Center icons with text
	moneyLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	moneyLayout.Parent = moneyContainer

	-- Create money icon
	local moneyIcon = IconManager:CreateIcon(moneyContainer, "Currency", "Cash", {
		size = UDim2.fromOffset(48, 48) -- 48px icon size
	})
	if moneyIcon then
		moneyIcon.LayoutOrder = 1
	end

	moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "MoneyLabel"
	moneyLabel.Size = UDim2.new(0, 100, 1, 0) -- Fixed width for text
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Text = "<b><i>0</i></b>"
	moneyLabel.RichText = true -- Enable RichText for bold+italic
	moneyLabel.TextColor3 = Color3.fromRGB(34, 197, 94) -- Green color for money
	moneyLabel.TextSize = 64 -- Massive text size
	moneyLabel.Font = BOLD_FONT -- Base font for RichText
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.TextYAlignment = Enum.TextYAlignment.Center
	moneyLabel.TextStrokeTransparency = 0 -- Maximum opacity for thickest stroke
	moneyLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	moneyLabel.LayoutOrder = 2
	moneyLabel.Parent = moneyContainer

	-- Add extra thick UIStroke for money
	local moneyStroke = Instance.new("UIStroke")
	moneyStroke.Color = Color3.fromRGB(0, 0, 0)
	moneyStroke.Thickness = 2 -- Medium stroke thickness
	moneyStroke.Parent = moneyLabel
end--[[
	Create a menu button with individual background frame
--]]
function MainHUD:CreateMenuButton(buttonData)
	-- Create background frame for the button
	local buttonBackgroundFrame = Instance.new("Frame")
	buttonBackgroundFrame.Name = "MenuButtonFrame"
	buttonBackgroundFrame.Size = UDim2.fromOffset(BUTTON_SIZE, BUTTON_SIZE)
	buttonBackgroundFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.hud.sidebar.border
	buttonBackgroundFrame.BackgroundTransparency = 1 -- Fully transparent
	buttonBackgroundFrame.BorderSizePixel = 0

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	frameCorner.Parent = buttonBackgroundFrame

	-- Create the actual button
	local button = Instance.new("TextButton")
	button.Name = "MenuButton"
	button.Size = UDim2.fromOffset(60, 60) -- 4px padding inside frame (back to original)
	button.Position = UDim2.fromOffset(4, 4)
	button.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.hud.sidebar.background
	button.BackgroundTransparency = 1 -- Fully transparent
	button.Text = ""
	button.BorderSizePixel = 0
	button.Parent = buttonBackgroundFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	buttonCorner.Parent = button

	-- No gradient overlay needed for transparent buttons

	-- Create icon (positioned for text overlay)
	local icon = IconManager:CreateIcon(button, buttonData.iconCategory, buttonData.iconName, {
		size = UDim2.fromOffset(DEFAULT_ICON_SIZE, DEFAULT_ICON_SIZE), -- Smaller by default
		position = UDim2.fromScale(0.5, 0.5), -- Centered in button
		anchorPoint = Vector2.new(0.5, 0.5),
	})

	-- Create button text label overlaying the icon (using titleLabel styling)
	local buttonTextLabel = nil
	if buttonData.buttonText then
		buttonTextLabel = Instance.new("TextLabel")
		buttonTextLabel.Name = "ButtonText"
		buttonTextLabel.Size = UDim2.new(1, -4, 0, 32) -- Full width minus padding, larger height for bigger text
		buttonTextLabel.Position = UDim2.new(0, 2, 1, -18) -- Nudge label back up slightly per feedback
		buttonTextLabel.BackgroundTransparency = 1
		buttonTextLabel.Text = "<b><i>" .. buttonData.buttonText .. "</i></b>" -- Bold+italic like money/gems
		buttonTextLabel.RichText = true -- Enable RichText for bold+italic styling
		buttonTextLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
		buttonTextLabel.TextSize = 22 -- Scaled up font for bigger buttons
		buttonTextLabel.Font = BOLD_FONT -- Same font as money/gems
		buttonTextLabel.TextXAlignment = Enum.TextXAlignment.Center
		buttonTextLabel.TextYAlignment = Enum.TextYAlignment.Center
		buttonTextLabel.TextScaled = false -- Disable scaling to use exact font size
		buttonTextLabel.ZIndex = 2 -- Ensure text appears above icon
		buttonTextLabel.Parent = button

		-- Add UIStroke using titleLabel configuration
		local textStroke = Instance.new("UIStroke")
		textStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
		textStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
		textStroke.Parent = buttonTextLabel
	end

		-- Remove expanded text label functionality for cleaner design
	local _textLabel = nil -- No expanded text needed

	-- Button functionality
	button.MouseButton1Click:Connect(function()
		if buttonData.callback then
			buttonData.callback()
		end

		-- Micro UX: single short pulse on tap
		local baseSize = getBaseIconSizeForButton({button = button, icon = icon})
		popIcon(icon, baseSize)
	end)

	-- Hover effects (transparent buttons with icon scaling)
	button.MouseEnter:Connect(function()
		if SoundManager then
			SoundManager:PlaySFX("buttonHover")
		end
		-- Scale up the icon for hover feedback
		if icon then
			local base = getBaseIconSizeForButton({button = button, icon = icon})
			local target = math.max(base, HOVER_ICON_SIZE)
			TweenService:Create(icon, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal), {
				Size = UDim2.fromOffset(target, target)
			}):Play()
		end
	end)

	button.MouseLeave:Connect(function()
		-- Scale down the icon
		if icon then
			local base = getBaseIconSizeForButton({button = button, icon = icon})
			TweenService:Create(icon, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal), {
				Size = UDim2.fromOffset(base, base)
			}):Play()
		end
	end)

	-- Return button object
	return {
		borderFrame = buttonBackgroundFrame,
		button = button,
		icon = icon,
		textLabel = nil, -- No expanded text
		buttonTextLabel = buttonTextLabel -- For button label
	}
end

--[[
	Removed menu toggle functionality for simpler design
	Buttons now work independently without expand/collapse behavior
--]]



--[[
	Start button cooldown with simple countdown
--]]
function MainHUD:StartButtonCooldown(buttonId, buttonObj, duration)
	buttonCooldowns[buttonId] = true

	-- Create cooldown overlay
	local cooldownOverlay = Instance.new("Frame")
	cooldownOverlay.Name = "CooldownOverlay"
	cooldownOverlay.Size = UDim2.fromScale(1, 1)
	cooldownOverlay.BackgroundTransparency = 1
	cooldownOverlay.BorderSizePixel = 0
	cooldownOverlay.Parent = buttonObj.button

	-- Countdown text
	local countdownText = Instance.new("TextLabel")
	countdownText.Name = "CountdownText"
	countdownText.Size = UDim2.fromScale(1, 1)
	countdownText.Position = UDim2.fromScale(0, 0)
	countdownText.BackgroundTransparency = 1
	countdownText.Text = tostring(duration)
	countdownText.TextColor3 = Config.UI_SETTINGS.colors.text
	countdownText.TextSize = Config.UI_SETTINGS.typography.sizes.body.large
	countdownText.Font = Config.UI_SETTINGS.typography.fonts.bold
	countdownText.TextStrokeTransparency = 0.3
	countdownText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	countdownText.Parent = cooldownOverlay

	-- Disable button and make icon semi-transparent
	buttonObj:SetEnabled(false)
	if buttonObj.icon then
		buttonObj.icon.ImageTransparency = Config.UI_SETTINGS.designSystem.transparency.overlay
	end

	local startTime = tick()
	local connection

	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local remaining = duration - elapsed

		if remaining > 0 then
			countdownText.Text = string.format("%.0f", remaining)
		else
			-- Cooldown complete
			buttonCooldowns[buttonId] = false
			cooldownOverlay:Destroy()
			buttonObj:SetEnabled(true)
			-- Restore icon transparency
			if buttonObj.icon then
				buttonObj.icon.ImageTransparency = 0
			end
			connection:Disconnect()
		end
	end)
end



--[[
	Connect to game state changes
--]]
function MainHUD:ConnectToGameState()
	-- Update stats when player data changes
	GameState:OnPropertyChanged("playerData", function(newData)
		if newData then
			self:UpdateStats(newData)
		end
	end)
end

--[[
	Update player stats with count-up animations and gain/loss effects
--]]
function MainHUD:UpdateStats(playerData)
	if not playerData then
		return
	end

	-- Update stats with count-up animations and gain/loss effects
	if playerData.coins then
		local oldValue = currentValues.coins
		local newValue = playerData.coins
		if oldValue ~= newValue then
			self:AnimateValueChange(moneyLabel, oldValue, newValue, "coins")
			currentValues.coins = newValue
		end
	end

	if playerData.gems then
		local oldValue = currentValues.gems
		local newValue = playerData.gems
		if oldValue ~= newValue then
			self:AnimateValueChange(gemsLabel, oldValue, newValue, "gems")
			currentValues.gems = newValue
		end
	end
end

--[[
	Animate value change with count-up effect
--]]
function MainHUD:AnimateValueChange(label, oldValue, newValue, valueType)
	if not label then
		return
	end

	local duration = 0.8 -- Animation duration
	local startTime = tick()
	local connection

	-- No scale effects to keep size consistent

	connection = game:GetService("RunService").Heartbeat:Connect(function()
		local elapsed = tick() - startTime
		local progress = math.min(elapsed / duration, 1)

		-- Ease out animation
		local easedProgress = 1 - math.pow(1 - progress, 3)
		local currentValue = math.floor(oldValue + (newValue - oldValue) * easedProgress)

		-- Update text based on value type with RichText formatting
		if valueType == "coins" or valueType == "gems" then
			label.Text = "<b><i>" .. self:FormatNumber(currentValue) .. "</i></b>"
		end

		if progress >= 1 then
			connection:Disconnect()
		end
	end)
end



--[[
	Format numbers with K/M/B suffixes
--]]
function MainHUD:FormatNumber(number)
	if number >= 1000000000 then
		return string.format("%.1fB", number / 1000000000)
	elseif number >= 1000000 then
		return string.format("%.1fM", number / 1000000)
	elseif number >= 1000 then
		return string.format("%.1fK", number / 1000)
	else
		return tostring(number)
	end
end

--[[
	Show/Hide HUD
--]]
function MainHUD:Show()
	if hudGui then
		hudGui.Enabled = true
	end
end

function MainHUD:Hide()
	if hudGui then
		hudGui.Enabled = false
	end
end

function MainHUD:Destroy()
	if hudGui then
		hudGui:Destroy()
		hudGui = nil
	end
end

return MainHUD