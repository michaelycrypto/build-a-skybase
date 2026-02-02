--[[
	DailyRewardsPanel.lua - Daily Login Rewards Panel
	Redesigned for infinite streak with 7-day cycle system
	Enhanced with diverse icon mappings for visual variety
--]]

local DailyRewardsPanel = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local _EventManager = require(ReplicatedStorage.Shared.EventManager)
local RewardsApi = require(ReplicatedStorage.Shared.Api.RewardsApi)
local Config = require(ReplicatedStorage.Shared.Config)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local GameState = require(script.Parent.Parent.Managers.GameState)

-- Services and instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local panel = nil
local streakDisplay = nil
local cycleDisplay = nil
local claimButton = nil

-- Daily rewards data
local dailyRewardsData = {
	currentStreak = 0,
	lastClaimDate = "",
	canClaim = false,
	cyclePosition = 1, -- Position in 7-day cycle (1-7)
	claimedToday = false, -- Track if already claimed today
	-- 7-day reward cycle that repeats infinitely with diverse icons
	rewardCycle = {
		{day = 1, type = "coins", amount = 100, icon = "Coin", name = "Coins", iconCategory = "Currency"},
		{day = 2, type = "coins", amount = 150, icon = "Cash", name = "Coins", iconCategory = "Currency"},
		{day = 3, type = "gems", amount = 5, icon = "Crystal", name = "Crystals", iconCategory = "Currency"},
		{day = 4, type = "coins", amount = 200, icon = "Ingots", name = "Gold Ingots", iconCategory = "Currency"},
		{day = 5, type = "gems", amount = 8, icon = "Gem", name = "Gems", iconCategory = "Currency"},
		{day = 6, type = "coins", amount = 300, icon = "StarGem", name = "Star Coins", iconCategory = "Currency"},
		{day = 7, type = "special", amount = 500, icon = "Trophy", name = "Bonus Reward", iconCategory = "General", special = true}
	}
}

--[[
	Create content for PanelManager integration
	@param contentFrame: Frame - The content frame provided by PanelManager
	@param data: table - Optional data for the panel
--]]
function DailyRewardsPanel:CreateContent(contentFrame, _data)
	-- If no contentFrame provided, use legacy method
	if not contentFrame then
		return self:Create()
	end

	-- Store content frame reference for PanelManager integration
	if not panel then
		panel = {contentFrame = contentFrame}
	else
		panel.contentFrame = contentFrame
	end

	-- Create the panel content using the provided contentFrame
	self:CreateDailyRewardsContent(contentFrame)

	print("DailyRewardsPanel: Created content for PanelManager integration")
end

--[[
	Create the daily rewards panel using UIComponents (legacy method)
--]]
function DailyRewardsPanel:Create()
	-- Create panel using UIComponents
	panel = UIComponents:CreatePanel({
		name = "DailyRewards",
		title = "Daily Rewards",
		icon = {category = "General", name = "DailyRewards", color = Config.UI_SETTINGS.colors.semantic.game.experience},
		size = "large",
		parent = playerGui
	})

	-- Create content within the panel
	self:CreateDailyRewardsContent(panel.contentFrame)

	print("DailyRewardsPanel: Created daily rewards panel using UIComponents")
end

--[[
	Create the panel content using the contentFrame from UIComponents or PanelManager
--]]
function DailyRewardsPanel:CreateDailyRewardsContent(contentFrame)
	if not contentFrame then
		warn("DailyRewardsPanel: No content frame available")
		return
	end

	-- Load data from GameState (don't call LoadDailyRewardsData to avoid recursion)
	local gameStateRewardData = GameState:Get("playerData.dailyRewards")
	if gameStateRewardData then
		self:UpdateDataFromGameState(gameStateRewardData)
	else
		-- Default values for first-time users
		self:UpdateDataFromGameState({
			currentStreak = 0,
			lastClaimDate = ""
		})
	end

	-- Main container with vertical layout - compact design with no margins
	local mainContainer = Instance.new("Frame")
	mainContainer.Name = "DailyRewardsContainer"
	mainContainer.Size = UDim2.fromScale(1, 1)
	mainContainer.BackgroundTransparency = 1 -- Transparent, let sections handle backgrounds
	mainContainer.BorderSizePixel = 0
	mainContainer.Parent = contentFrame

	local mainLayout = Instance.new("UIListLayout")
	mainLayout.FillDirection = Enum.FillDirection.Vertical
	mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	mainLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.Padding = UDim.new(0, 0) -- No gaps between sections
	mainLayout.Parent = mainContainer

	-- No padding on main container for tight design

	-- Create streak display at top
	self:CreateStreakDisplay(mainContainer)

	-- Create rewards cycle display
	self:CreateCycleDisplay(mainContainer)

	-- Create claim button at bottom
	self:CreateClaimButton(mainContainer)
end

--[[
	Create compact streak display topbar - full width, no margins
--]]
function DailyRewardsPanel:CreateStreakDisplay(parent)
	-- Create full-width streak container
	local streakContainer = Instance.new("Frame")
	streakContainer.Name = "StreakContainer"
	streakContainer.Size = UDim2.new(1, 0, 0, 40) -- Fixed height for compact design
	streakContainer.BackgroundTransparency = 1
	streakContainer.BorderSizePixel = 0
	streakContainer.LayoutOrder = 1
	streakContainer.Parent = parent

	-- Create topbar with streak information inside the container
	streakDisplay = UIComponents:CreateInfoTopbar({
		parent = streakContainer,
		layoutOrder = 1,
		backgroundTransparency = 1, -- Transparent background since container handles it
		transparency = 1, -- Fully transparent
		items = {
			{
				icon = {
					category = "General",
					name = "LightningBolt",
					color = Config.UI_SETTINGS.colors.semantic.game.experience
				},
				text = "Streak:",
				value = dailyRewardsData.currentStreak .. " Days",
				valueColor = Config.UI_SETTINGS.colors.text
			},
			{
				icon = {
					category = "UI",
					name = "Calendar",
					color = Config.UI_SETTINGS.colors.textMuted
				},
				text = "",
				value = self:GetStatusText(),
				valueColor = self:GetStatusColor()
			}
		}
	})
end

--[[
	Get status text based on current state
--]]
function DailyRewardsPanel:GetStatusText()
	if dailyRewardsData.claimedToday then
		return "Already claimed today!"
	elseif dailyRewardsData.canClaim then
		return "Ready to claim!"
	else
		return "Come back tomorrow"
	end
end

--[[
	Get status color based on current state
--]]
function DailyRewardsPanel:GetStatusColor()
	if dailyRewardsData.claimedToday then
		return Config.UI_SETTINGS.colors.textMuted
	elseif dailyRewardsData.canClaim then
		return Config.UI_SETTINGS.colors.semantic.button.success
	else
		return Config.UI_SETTINGS.colors.textMuted
	end
end

--[[
	Create 7-day cycle display showing current position - full width, no margins
--]]
function DailyRewardsPanel:CreateCycleDisplay(parent)
	-- Create full-width cycle container
	local cycleContainer = Instance.new("Frame")
	cycleContainer.Name = "CycleContainer"
	cycleContainer.Size = UDim2.new(1, 0, 0, 150) -- Fixed height for cycle display
	cycleContainer.BackgroundTransparency = 1
	cycleContainer.BorderSizePixel = 0
	cycleContainer.LayoutOrder = 2
	cycleContainer.Parent = parent

	-- Header section
	local headerContainer = Instance.new("Frame")
	headerContainer.Name = "Header"
	headerContainer.Size = UDim2.new(1, 0, 0, 40)
	headerContainer.BackgroundTransparency = 1
	headerContainer.Parent = cycleContainer

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
	headerPadding.PaddingRight = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
	headerPadding.PaddingTop = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.sm)
	headerPadding.Parent = headerContainer

	-- Title text
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.fromScale(1, 1)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Rewards Cycle - Day " .. dailyRewardsData.cyclePosition
	titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
	titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.headings.h3
	titleLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Parent = headerContainer

	-- Title stroke
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
	titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
	titleStroke.Parent = titleLabel

	-- Grid container for the 7-day cycle
	local cycleGrid = Instance.new("Frame")
	cycleGrid.Name = "CycleGrid"
	cycleGrid.Size = UDim2.new(1, 0, 1, -40) -- Account for header
	cycleGrid.Position = UDim2.fromOffset(0, 40)
	cycleGrid.BackgroundTransparency = 1
	cycleGrid.Parent = cycleContainer

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(72, 72) -- Compact card size
	gridLayout.CellPadding = UDim2.fromOffset(4, 4) -- Tight spacing
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.FillDirection = Enum.FillDirection.Horizontal -- Force horizontal layout
	gridLayout.Parent = cycleGrid

	-- Create reward cards for each day in cycle
	for i, reward in ipairs(dailyRewardsData.rewardCycle) do
		self:CreateCycleRewardCard(cycleGrid, reward, i)
	end

	-- Store reference for updates
	cycleDisplay = {
		container = cycleContainer,
		header = headerContainer,
		titleLabel = titleLabel,
		grid = cycleGrid
	}
end

--[[
	Create individual reward card in the cycle
--]]
function DailyRewardsPanel:CreateCycleRewardCard(parent, rewardData, dayIndex)
	local isCurrentDay = dayIndex == dailyRewardsData.cyclePosition
	local isNextReward = dailyRewardsData.canClaim and isCurrentDay and not dailyRewardsData.claimedToday

	-- A day is considered "completed" if:
	-- 1. It's before the current cycle position (we've passed this day in the current cycle), OR
	-- 2. It's the current day AND we've already claimed today's reward
	local isCompletedDay = dayIndex < dailyRewardsData.cyclePosition or (isCurrentDay and dailyRewardsData.claimedToday)

	-- For backward compatibility, keep isPastReward as alias
	local isPastReward = isCompletedDay

	-- Card frame
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = "CycleDay" .. dayIndex
	cardFrame.Size = UDim2.fromScale(1, 1)

	-- Set background color based on state
	if isPastReward then
		-- Already claimed - muted color
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy
	elseif isCurrentDay then
		-- Current day - highlight color
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	else
		-- Future reward - normal color
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.medium
	end

	cardFrame.BorderSizePixel = 0
	cardFrame.LayoutOrder = dayIndex
	cardFrame.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	cardCorner.Parent = cardFrame

		-- Simple styling for special rewards (Day 7)
	if rewardData.special and not isPastReward then
		cardFrame.BorderColor3 = Color3.fromRGB(255, 215, 0) -- Gold color
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	end

	-- Card layout - content should be above gradient
	local cardLayout = Instance.new("UIListLayout")
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	cardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 2) -- Much tighter spacing
	cardLayout.Parent = cardFrame

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 3) -- Tighter padding
	cardPadding.PaddingBottom = UDim.new(0, 3)
	cardPadding.PaddingLeft = UDim.new(0, 2)
	cardPadding.PaddingRight = UDim.new(0, 2)
	cardPadding.Parent = cardFrame

	-- Day label
	local dayLabel = Instance.new("TextLabel")
	dayLabel.Name = "DayLabel"
	dayLabel.Size = UDim2.new(1, 0, 0, 10) -- Smaller text
	dayLabel.BackgroundTransparency = 1
	dayLabel.Text = "Day " .. dayIndex
	dayLabel.TextColor3 = isPastReward and Config.UI_SETTINGS.colors.textMuted or Config.UI_SETTINGS.colors.text
	dayLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base - 1 -- Even smaller
	dayLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	dayLabel.TextXAlignment = Enum.TextXAlignment.Center
	dayLabel.LayoutOrder = 3
	dayLabel.Parent = cardFrame

	-- Reward icon with fallback to Currency category
	local iconCategory = rewardData.iconCategory or "Currency"
	local _rewardIcon = IconManager:CreateIcon(cardFrame, iconCategory, rewardData.icon, {
		size = UDim2.fromOffset(24, 24), -- Smaller icon
		layoutOrder = 2
	})

	-- Reward amount
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Size = UDim2.new(1, 0, 0, 12) -- Smaller text
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = tostring(rewardData.amount)
	amountLabel.TextColor3 = isPastReward and Config.UI_SETTINGS.colors.textMuted or Config.UI_SETTINGS.colors.text
	amountLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base - 1 -- Even smaller
	amountLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	amountLabel.TextXAlignment = Enum.TextXAlignment.Center
	amountLabel.LayoutOrder = 2
	amountLabel.Parent = cardFrame

	-- Current day indicator
	if isCurrentDay then
		local indicator = Instance.new("Frame")
		indicator.Name = "CurrentIndicator"
		indicator.Size = UDim2.fromOffset(4, 4)
		indicator.Position = UDim2.new(0.5, -2, 1, -8)
		indicator.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
		indicator.BorderSizePixel = 0
		indicator.Parent = cardFrame

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0, 2)
		indicatorCorner.Parent = indicator

		-- Pulsing animation for claimable reward
		if isNextReward then
			local pulseAnimation = TweenService:Create(cardFrame,
				TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.medium}
			)
			pulseAnimation:Play()
		end
	end

		-- Add checkmark for completed days in the current cycle
	if isCompletedDay then
		local _checkmark = IconManager:CreateIcon(cardFrame, "UI", "CheckMark", {
			size = UDim2.fromOffset(16, 16),
			position = UDim2.new(1, -18, 0, 2),
			anchorPoint = Vector2.new(1, 0)
		})
	end
end


--[[
	Create claim button that spans the bottom - full width, no margins
--]]
function DailyRewardsPanel:CreateClaimButton(parent)
	-- Create full-width button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ClaimButtonContainer"
	buttonContainer.Size = UDim2.new(1, 0, 0, 60) -- Increased height for proper spacing
	buttonContainer.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	buttonContainer.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.subtle
	buttonContainer.BorderSizePixel = 0
	buttonContainer.LayoutOrder = 3
	buttonContainer.Parent = parent

	-- Add rounded corners only on bottom
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	buttonCorner.Parent = buttonContainer

	-- Top section should be square - add a frame to cover top corners
	local cornerFix = Instance.new("Frame")
	cornerFix.Name = "CornerFix"
	cornerFix.Size = UDim2.new(1, 0, 0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	cornerFix.Position = UDim2.fromScale(0, 0)
	cornerFix.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	cornerFix.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.subtle
	cornerFix.BorderSizePixel = 0
	cornerFix.Parent = buttonContainer

	-- Content padding for button container
	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingLeft = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
	buttonPadding.PaddingRight = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
	buttonPadding.PaddingTop = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.sm)
	buttonPadding.PaddingBottom = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.sm)
	buttonPadding.Parent = buttonContainer

	-- Get current reward info
	local _currentReward = dailyRewardsData.rewardCycle[dailyRewardsData.cyclePosition]
	local buttonText = self:GetClaimButtonText()
	local canClaim = dailyRewardsData.canClaim and not dailyRewardsData.claimedToday

	claimButton = UIComponents:CreateButton({
		name = "ClaimDailyReward",
		parent = buttonContainer,
		style = "panel", -- Use panel style for full-width button
		text = buttonText,
		color = canClaim and "success" or "secondary",
		callback = canClaim and function()
			self:ClaimDailyReward()
		end or nil
	})

	-- Set initial enabled state
	claimButton:SetEnabled(canClaim)
end

--[[
	Get claim button text based on current state
--]]
function DailyRewardsPanel:GetClaimButtonText()
	if dailyRewardsData.claimedToday then
		return "Already Claimed Today"
	elseif dailyRewardsData.canClaim then
		local currentReward = dailyRewardsData.rewardCycle[dailyRewardsData.cyclePosition]
		return "Claim " .. currentReward.amount .. " " .. currentReward.name
	else
		return "Come Back Tomorrow"
	end
end

--[[
	Load daily rewards data
--]]
function DailyRewardsPanel:LoadDailyRewardsData()
    -- Request fresh data from server
    RewardsApi.RequestDaily()

	-- Load from GameState (server will update GameState which triggers our listener)
	local gameStateRewardData = GameState:Get("playerData.dailyRewards")
	if gameStateRewardData then
		self:UpdateFromGameState(gameStateRewardData)
	else
		-- Default values for first-time users
		self:UpdateFromGameState({
			currentStreak = 0,
			lastClaimDate = ""
		})
	end
end

--[[
	Claim daily reward
--]]
function DailyRewardsPanel:ClaimDailyReward()
	if not dailyRewardsData.canClaim or dailyRewardsData.claimedToday then
		return
	end

    -- Send claim request to server (server will update GameState)
    RewardsApi.ClaimDaily()

	-- Disable button immediately for UI responsiveness
	if claimButton then
		claimButton:SetEnabled(false)
	end
end



--[[
	Update existing UI elements without full recreation
--]]
function DailyRewardsPanel:UpdateExistingElements()
	if not panel or not panel.contentFrame then
		return false
	end

	local container = panel.contentFrame:FindFirstChild("DailyRewardsContainer")
	if not container then
		return false
	end

	-- Update streak display
	if streakDisplay then
		local success = self:UpdateStreakDisplay()
		if not success then
			return false
		end
	end

	-- Update cycle display
	if cycleDisplay then
		local success = self:UpdateCycleDisplay()
		if not success then
			return false
		end
	end

	-- Update claim button
	if claimButton then
		local success = self:UpdateClaimButton()
		if not success then
			return false
		end
	end

	return true
end

--[[
	Update streak display elements
--]]
function DailyRewardsPanel:UpdateStreakDisplay()
	if not streakDisplay then return false end

	-- Update streak value and status
	local _streakValue = dailyRewardsData.currentStreak .. " Days"
	local _statusText = self:GetStatusText()
	local _statusColor = self:GetStatusColor()

	-- Try to update the info topbar items
	local success, _err = pcall(function()
		-- This assumes the UIComponents:CreateInfoTopbar creates updatable elements
		-- We might need to access the specific text elements and update them
		-- For now, we'll return false to trigger a full refresh
		return false
	end)

	return success
end

--[[
	Update cycle display elements
--]]
function DailyRewardsPanel:UpdateCycleDisplay()
	if not cycleDisplay then return false end

	-- Update cycle title
	if cycleDisplay.titleLabel then
		cycleDisplay.titleLabel.Text = "Rewards Cycle - Day " .. dailyRewardsData.cyclePosition
	end

	-- Update each cycle card
	if cycleDisplay.grid then
		for i = 1, 7 do
			local cardFrame = cycleDisplay.grid:FindFirstChild("CycleDay" .. i)
			if cardFrame then
				local success = self:UpdateCycleCard(cardFrame, i)
				if not success then return false end
			end
		end
	end

	return true
end

--[[
	Update individual cycle card
--]]
function DailyRewardsPanel:UpdateCycleCard(cardFrame, dayIndex)
	local isCurrentDay = dayIndex == dailyRewardsData.cyclePosition
	local isCompletedDay = dayIndex < dailyRewardsData.cyclePosition or (isCurrentDay and dailyRewardsData.claimedToday)

	-- Update card appearance
	if isCompletedDay then
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy
	elseif isCurrentDay then
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	else
		cardFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		cardFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.medium
	end

	-- Update text colors
	local dayLabel = cardFrame:FindFirstChild("DayLabel")
	local amountLabel = cardFrame:FindFirstChild("AmountLabel")

	if dayLabel then
		dayLabel.TextColor3 = isCompletedDay and Config.UI_SETTINGS.colors.textMuted or Config.UI_SETTINGS.colors.text
	end

	if amountLabel then
		amountLabel.TextColor3 = isCompletedDay and Config.UI_SETTINGS.colors.textMuted or Config.UI_SETTINGS.colors.text
	end

	-- Add/remove checkmark for completed days
	local existingCheckmark = cardFrame:FindFirstChild("CheckMark")
	if isCompletedDay and not existingCheckmark then
		-- Add checkmark
		local checkmark = IconManager:CreateIcon(cardFrame, "UI", "CheckMark", {
			size = UDim2.fromOffset(16, 16),
			position = UDim2.new(1, -18, 0, 2),
			anchorPoint = Vector2.new(1, 0)
		})
		checkmark.Name = "CheckMark"
	elseif not isCompletedDay and existingCheckmark then
		-- Remove checkmark
		existingCheckmark:Destroy()
	end

	return true
end

--[[
	Update claim button
--]]
function DailyRewardsPanel:UpdateClaimButton()
	if not claimButton then return false end

	local canClaim = dailyRewardsData.canClaim and not dailyRewardsData.claimedToday
	local buttonText = self:GetClaimButtonText()

	-- Update button text and enabled state
	claimButton:SetText(buttonText)
	claimButton:SetEnabled(canClaim)

	-- Note: Button color and callback are set during creation and don't need to change
	-- The enabled/disabled state provides sufficient visual feedback

	return true
end

--[[
	Refresh the entire panel content (use sparingly)
--]]
function DailyRewardsPanel:RefreshPanel()
	if panel and panel.contentFrame then
		-- Clear existing content
		for _, child in ipairs(panel.contentFrame:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		-- Reset references
		streakDisplay = nil
		cycleDisplay = nil
		claimButton = nil

		-- Recreate content
		self:CreateDailyRewardsContent(panel.contentFrame)
	end
end

--[[
	Show the panel
--]]
function DailyRewardsPanel:Show()
	if not panel then
		self:Create()
	end

    -- Request fresh data from server when showing
    RewardsApi.RequestDaily()

	-- Load current data from GameState
	local gameStateRewardData = GameState:Get("playerData.dailyRewards")
	if gameStateRewardData then
		self:UpdateFromGameState(gameStateRewardData)
	end

	if panel.Show then
		panel:Show()
	end
end

--[[
	Hide the panel
--]]
function DailyRewardsPanel:Hide()
	if panel and panel.Hide then
		panel:Hide()
	end
end

--[[
	Initialize the daily rewards panel
--]]
function DailyRewardsPanel:Initialize()
	-- Network events update GameState, then GameState listener handles UI updates
    RewardsApi.OnDailyClaimed(function(rewardData)
		if rewardData.playerData then
			GameState:UpdatePlayerData(rewardData.playerData)
		end
		self:OnDailyRewardClaimed(rewardData)
    end)

    RewardsApi.OnDailyUpdated(function(rewardData)
		if rewardData then
			-- Update GameState with server data
			GameState:Set("playerData.dailyRewards", rewardData, true)
		end
    end)

    RewardsApi.OnDailyError(function(errorData)
        self:OnDailyRewardError(errorData)
    end)

	-- Single GameState listener for all data updates
	GameState:OnPropertyChanged("playerData.dailyRewards", function(newValue, _oldValue, _path)
		if newValue then
			self:UpdateFromGameState(newValue)
		end
	end)
end

--[[
	Handle daily reward claimed event from server (for feedback only)
--]]
function DailyRewardsPanel:OnDailyRewardClaimed(rewardData)
	-- Play success sound
	if SoundManager then
		SoundManager:PlaySFX("rewardClaim")
	end

	-- Show reward feedback
	local success, ToastManager = pcall(require, script.Parent.Parent.Managers.ToastManager)
	if success and ToastManager and rewardData.reward then
		-- Safely access reward data with fallbacks
		local rewardAmount = rewardData.reward.amount or 0
		local rewardType = rewardData.reward.type or "coins"
		local newStreak = rewardData.newStreak or 1

		local rewardText = "+" .. rewardAmount .. " " ..
			(rewardType == "gems" and "Gems" or "Coins")
		local streakText = "Day " .. newStreak .. " claimed!"
		local fullMessage = streakText .. " " .. rewardText
		ToastManager:Success(fullMessage, 4)
	end
end

--[[
	Handle daily reward error event from server
--]]
function DailyRewardsPanel:OnDailyRewardError(errorData)
	if not errorData then return end

	-- Show error message to user
	local success, ToastManager = pcall(require, script.Parent.Parent.Managers.ToastManager)
	if success and ToastManager then
		local errorMessage = errorData.error or "Unknown error occurred"
		if errorData.errorCode == "ALREADY_CLAIMED" then
			errorMessage = "You have already claimed your daily reward today!"
		elseif errorData.errorCode == "NO_DATA" then
			errorMessage = "Player data not found. Please try again."
		end
		ToastManager:Error(errorMessage, 3)
	end

	-- Re-enable claim button in case it was disabled
	if claimButton then
		claimButton:SetEnabled(dailyRewardsData.canClaim and not dailyRewardsData.claimedToday)
	end
end

--[[
	Update local data from GameState (without UI refresh)
--]]
function DailyRewardsPanel:UpdateDataFromGameState(gameStateRewardData)
	if not gameStateRewardData then return end

	-- Update local data from GameState
	dailyRewardsData.currentStreak = gameStateRewardData.currentStreak or 0
	dailyRewardsData.lastClaimDate = gameStateRewardData.lastClaimDate or ""

	-- Calculate cycle position from streak
	if dailyRewardsData.currentStreak == 0 then
		dailyRewardsData.cyclePosition = 1
	else
		dailyRewardsData.cyclePosition = ((dailyRewardsData.currentStreak - 1) % 7) + 1
	end

	-- Check claim status
	local today = os.date("%Y-%m-%d")
	dailyRewardsData.claimedToday = dailyRewardsData.lastClaimDate == today
	dailyRewardsData.canClaim = not dailyRewardsData.claimedToday
end

--[[
	Update panel from GameState data (single source of truth)
--]]
function DailyRewardsPanel:UpdateFromGameState(gameStateRewardData)
	if not gameStateRewardData then return end

	-- Update local data
	self:UpdateDataFromGameState(gameStateRewardData)

	-- Update UI elements if they exist
	if panel and panel.contentFrame then
		-- Try to update existing elements first before full refresh
		local success = self:UpdateExistingElements()

		-- If updating existing elements failed, do a full refresh
		if not success and panel.contentFrame:FindFirstChild("DailyRewardsContainer") then
			self:RefreshPanel()
		end
	end
end

return DailyRewardsPanel