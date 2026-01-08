--[[
	WorldsPanel.lua

	Lobby worlds UI redesigned to match the voxel inventory aesthetic.
	Provides world list navigation, quick actions, and inline management controls.
]]

local WorldsPanel = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputService = require(script.Parent.Parent.Input.InputService)
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local _ = UpheavalFont -- Ensure font module loads

local CUSTOM_FONT_NAME = "Upheaval BRK"
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold
local REGULAR_FONT = GameConfig.UI_SETTINGS.typography.fonts.regular
local MIN_TEXT_SIZE = 20
local LABEL_SIZE = 24
local WORLD_REQUEST_COOLDOWN = 1.5
local FRIENDS_AUTO_REFRESH_INTERVAL = 60

local player = Players.LocalPlayer

local WORLDS_LAYOUT = {
	TOTAL_WIDTH = 784,
	HEADER_HEIGHT = 54,
	BODY_HEIGHT = 356,
	MENU_WIDTH = 94,
	MENU_BUTTON_SIZE = 94,
	MENU_MARGIN = 6,
	CONTENT_WIDTH = 402,
	CONTENT_MARGIN = 6,
	DETAIL_WIDTH = 604,
	SHADOW_HEIGHT = 18,
	LABEL_HEIGHT = 22,
	LABEL_SPACING = 8,
	PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),
	NAV_BG_COLOR = Color3.fromRGB(58, 58, 58),
	-- Slot styling (matching inventory)
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,  -- 60% opacity
	SLOT_HOVER_COLOR = Color3.fromRGB(80, 80, 80),
	SLOT_COLOR = Color3.fromRGB(31, 31, 31),  -- Legacy, use SLOT_BG_COLOR
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),
	-- Column border styling (for menu items, content column, etc.)
	COLUMN_BORDER_COLOR = Color3.fromRGB(77, 77, 77),  -- Matching inventory column border
	COLUMN_BORDER_THICKNESS = 3,  -- Matching inventory column border
	-- Slot border styling (for buttons, inputs, etc.)
	SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),  -- Matching inventory slot border
	SLOT_BORDER_THICKNESS = 2,  -- Matching inventory slot border
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),  -- Legacy, use SLOT_BORDER_COLOR for slots
	BORDER_THICKNESS = 2,  -- Legacy, use SLOT_BORDER_THICKNESS for slots
	SLOT_CORNER_RADIUS = 6,  -- Matching inventory
	BACKGROUND_IMAGE = "rbxassetid://82824299358542",
	BACKGROUND_IMAGE_TRANSPARENCY = 0.6,  -- Matching inventory
	-- Button colors (matching CraftingPanel style)
	BTN_GREEN = Color3.fromRGB(80, 180, 80),  -- Success actions (create, play)
	BTN_GREEN_HOVER = Color3.fromRGB(90, 200, 90),
	BTN_BLUE = Color3.fromRGB(100, 180, 255),  -- Info/neutral actions (manage)
	BTN_BLUE_HOVER = Color3.fromRGB(120, 200, 255),
	BTN_RED = Color3.fromRGB(220, 100, 100),  -- Danger actions (delete)
	BTN_RED_HOVER = Color3.fromRGB(240, 120, 120),
	BTN_DEFAULT = Color3.fromRGB(31, 31, 31),  -- Default/neutral (back, rename)
	BTN_DEFAULT_HOVER = Color3.fromRGB(80, 80, 80),
	BTN_DISABLED = Color3.fromRGB(60, 60, 60),
	BTN_DISABLED_TRANSPARENCY = 0.7
}

local COLOR = {
	text = Color3.fromRGB(255, 255, 255),
	textSecondary = Color3.fromRGB(185, 185, 195),
	textMuted = Color3.fromRGB(140, 140, 140),
	statusOnline = Color3.fromRGB(120, 230, 140),
	statusOffline = Color3.fromRGB(150, 150, 150),
	success = Color3.fromRGB(34, 197, 94),
	danger = Color3.fromRGB(205, 60, 60),
	neutral = Color3.fromRGB(70, 70, 70)
}

local function destroyNonLayoutChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function trim(text)
	return text and text:match("^%s*(.-)%s*$") or ""
end

local function copyWorldEntries(list)
	local copy = {}
	for i, entry in ipairs(list or {}) do
		copy[i] = entry
	end
	return copy
end

WorldsPanel.__index = WorldsPanel

function WorldsPanel:_createDatasetState()
	return {
		status = "idle",
		items = {},
		lastUpdated = 0,
		lastRequestTime = 0,
		requestVersion = 0,
		error = nil
	}
end

function WorldsPanel:_ensureTabData()
	if self.tabData then
		return
	end

	self.tabData = {
		myWorlds = self:_createDatasetState(),
		friendsWorlds = self:_createDatasetState()
	}
end

function WorldsPanel:_getDataset(tab)
	self:_ensureTabData()
	return self.tabData[tab]
end

function WorldsPanel:_tabHasItems(tab)
	local dataset = self:_getDataset(tab)
	if not dataset then
		return false
	end

	local items = dataset.items
	return type(items) == "table" and #items > 0
end

function WorldsPanel:_syncDatasetArrays()
	if not self.tabData then
		return
	end

	self.myWorlds = self.tabData.myWorlds.items
	self.friendsWorlds = self.tabData.friendsWorlds.items
end

function WorldsPanel:_setDatasetStatus(tab, status)
	local dataset = self:_getDataset(tab)
	if not dataset or dataset.status == status then
		return
	end

	dataset.status = status
	if status == "loading" then
		dataset.requestVersion = (dataset.requestVersion or 0) + 1
	end

	self:UpdateOverviewSpinnerVisibility()
	self:UpdateListVisibility()
	if tab == "friendsWorlds" then
		self:UpdateRefreshButtonState()
	end
end

function WorldsPanel:_updateDataset(tab, update)
	local dataset = self:_getDataset(tab)
	if not dataset then
		return
	end

	if update.items then
		dataset.items = copyWorldEntries(update.items)
		self:_syncDatasetArrays()
	end

	if update.status then
		dataset.status = update.status
	end

	if update.lastUpdated then
		dataset.lastUpdated = update.lastUpdated
	elseif update.items then
		dataset.lastUpdated = os.time()
	end

	if update.error ~= nil then
		dataset.error = update.error
	end

	self:UpdateOverviewSpinnerVisibility()
	self:UpdateListVisibility()
	self:UpdateTabLabels()
	if tab == "friendsWorlds" then
		self:UpdateRefreshButtonState()
	end
end

function WorldsPanel:IsTabLoading(tab)
	tab = tab or self.currentTab
	local dataset = self:_getDataset(tab)
	return dataset and dataset.status == "loading"
end

function WorldsPanel:HasDatasetData(tab)
	local dataset = self:_getDataset(tab)
	if not dataset then
		return false
	end
	return dataset.status == "ready"
end

function WorldsPanel.new()
	local self = setmetatable({}, WorldsPanel)

	self.myWorlds = {}
	self.friendsWorlds = {}
	self.maxWorlds = 5
	self.currentTab = "myWorlds"
	self.selectedWorldId = nil

	self.sectionButtons = {}
	self.worldCardMap = {}
	self.uiScale = nil
	self.scaleTarget = nil

	self.rootFrame = nil
	self.worldsScrollFrame = nil
	self.listLabel = nil
	self.createWorldButton = nil
	self.createWorldLabel = nil
	self.createWorldSpacer = nil
	self.createWorldRow = nil
	self.createWorldReasonLabel = nil
	self.createWorldPlusLabel = nil
	self.detailPlaceholder = nil
	self.detailCard = nil
	self.detailNameLabel = nil
	self.detailStatusLabel = nil
	self.detailSlotBadge = nil
	self.detailOwnerValue = nil
	self.detailPlayerValue = nil
	self.detailCreatedValue = nil
	self.detailLastPlayedValue = nil
	self.playButton = nil
	self.renameSection = nil
	self.renameInput = nil
	self.renameButton = nil
	self.deleteButton = nil
	self.deleteConfirmWorldId = nil
	self.pendingDeleteToken = 0

	self.isJoiningWorld = false
	self.isTeleportingToHub = false
	self.overviewSpinner = nil
	self.joinSpinner = nil
	self.hubSpinner = nil
	self.emptyStateLabel = nil
	self.friendsRefreshActive = false
	self.friendsRefreshTask = nil
	self.teleportToHubButton = nil
	self.hubContainer = nil

	self.gui = nil
	self.panel = nil
	self.isOpen = false
	self.isAnimating = false
	self.currentTween = nil
	self.connections = {}
	self.renderConnection = nil
	self.pendingCloseMode = "gameplay"
	self.tabData = {
		myWorlds = self:_createDatasetState(),
		friendsWorlds = self:_createDatasetState()
	}
	self:_syncDatasetArrays()
	self.refreshFriendsButton = nil
	self.refreshFriendsIcon = nil

	return self
end

function WorldsPanel:IsClosing()
	return self.isAnimating and not self.isOpen
end

function WorldsPanel:SetPendingCloseMode(mode)
	if self:IsClosing() then
		self.pendingCloseMode = mode or "gameplay"
	end
end

function WorldsPanel:RequestWorldsListUpdate(options)
	options = options or {}
	local targetTab = options.targetTab or self.currentTab

	if targetTab == "hubWorld" then
		return false
	end

	local dataset = self:_getDataset(targetTab)
	if not dataset then
		return false
	end

	local now = os.clock()
	local shouldRequest = true

	if targetTab == "myWorlds" then
		local hasFetchedOnce = (dataset.lastUpdated or 0) > 0
		if hasFetchedOnce and not options.force then
			shouldRequest = false
		end
	else
		local lastRequestTime = dataset.lastRequestTime or 0
		if not options.force and lastRequestTime > 0 and (now - lastRequestTime) < WORLD_REQUEST_COOLDOWN then
			shouldRequest = false
		end
	end

	if not shouldRequest then
		return false
	end

	dataset.lastRequestTime = now

	if options.setLoading ~= false then
		self:_setDatasetStatus(targetTab, "loading")
		self:RefreshWorldsList()
	end

	local payload = options.payload
	if typeof(payload) ~= "table" then
		payload = {}
	end

	EventManager:SendToServer("RequestWorldsList", payload)
	return true
end

function WorldsPanel:RequestFriendsRefresh()
	self:RequestWorldsListUpdate({
		force = true,
		setLoading = true,
		reason = "friendsManualRefresh",
		targetTab = "friendsWorlds",
		payload = {
			bypassFriendsCache = true
		}
	})
end

function WorldsPanel:EnsureResponsiveScale(contentFrame)
	if self.uiScale and self.uiScale.Parent then
		return self.uiScale
	end

	if not contentFrame then
		return nil
	end

	local target = contentFrame.Parent
	if not (target and target:IsA("GuiBase2d")) then
		target = contentFrame
	end

	self.scaleTarget = target

	local existing = target:FindFirstChild("ResponsiveScale")
	if existing and existing:IsA("UIScale") then
		self.uiScale = existing
		if not CollectionService:HasTag(existing, "scale_component") then
			CollectionService:AddTag(existing, "scale_component")
		end
		return existing
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.6)
	uiScale.Parent = target
	CollectionService:AddTag(uiScale, "scale_component")
	self.uiScale = uiScale
	print("📐 WorldsPanel: Added UIScale with base resolution 1920x1080 (100% original size)")

	return uiScale
end

function WorldsPanel:RegisterScrollingLayout(layout)
	if not layout or not layout:IsA("UIListLayout") then
		return
	end

	if not (self.uiScale and self.uiScale.Parent) then
		self:EnsureResponsiveScale(self.scaleTarget or self.gui or layout.Parent)
	end

	if not (self.uiScale and self.uiScale.Parent) then
		return
	end

	if not CollectionService:HasTag(layout, "scrolling_frame_layout_component") then
		CollectionService:AddTag(layout, "scrolling_frame_layout_component")
	end

	local referral = layout:FindFirstChild("scale_component_referral")
	if not referral then
		referral = Instance.new("ObjectValue")
		referral.Name = "scale_component_referral"
		referral.Parent = layout
	end
	referral.Value = self.uiScale
end

function WorldsPanel:EnableMouseControl()
end

function WorldsPanel:StopMouseTracking()
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
end

function WorldsPanel:DisableMouseControl()
	self:StopMouseTracking()
	-- Mouse visibility is handled by InputService + CameraController stack
end

function WorldsPanel:ShouldKeepMouseUnlocked(mode)
	return mode == "inventory" or mode == "chest" or mode == "menu" or mode == "worlds"
end

function WorldsPanel:UpdateFriendsAutoRefreshState()
	if self.isOpen and self.currentTab == "friendsWorlds" then
		self:StartFriendsAutoRefresh()
	else
		self:StopFriendsAutoRefresh()
	end
end

function WorldsPanel:StartFriendsAutoRefresh()
	if self.friendsRefreshActive then
		return
	end
	self.friendsRefreshActive = true
	self.friendsRefreshTask = task.spawn(function()
		while self.friendsRefreshActive do
			task.wait(FRIENDS_AUTO_REFRESH_INTERVAL)
			if not self.friendsRefreshActive then
				break
			end
			if self.isOpen and self.currentTab == "friendsWorlds" then
				self:RequestWorldsListUpdate({
					reason = "friendsAutoRefresh",
					targetTab = "friendsWorlds",
					payload = {
						bypassFriendsCache = true
					}
				})
			end
		end
		self.friendsRefreshTask = nil
	end)
end

function WorldsPanel:StopFriendsAutoRefresh()
	if not self.friendsRefreshActive then
		return
	end
	self.friendsRefreshActive = false
end

function WorldsPanel:CreateGui()
	if self.gui then
		self.gui:Destroy()
	end

	local playerGui = player:WaitForChild("PlayerGui")

	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "WorldsPanel"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = playerGui

	self.panel = Instance.new("Frame")
	self.panel.Name = "WorldsPanelRoot"
	self.panel.Size = UDim2.new(0, WORLDS_LAYOUT.TOTAL_WIDTH, 0, WORLDS_LAYOUT.HEADER_HEIGHT + WORLDS_LAYOUT.BODY_HEIGHT)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, -WORLDS_LAYOUT.HEADER_HEIGHT)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundTransparency = 1
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui

	self:EnsureResponsiveScale(self.gui)
	self:CreateContent(self.panel)
end

function WorldsPanel:BindInput()
	local connection = InputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Escape and self:IsOpen() then
			self:Close()
		end
	end)
	table.insert(self.connections, connection)
end

function WorldsPanel:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function WorldsPanel:Hide()
	if self.gui then
		self.gui.Enabled = false
	end
	self.isOpen = false
	self.isAnimating = false
	if self.currentTween then
		self.currentTween:Cancel()
		self.currentTween = nil
	end
	self:DisableMouseControl()
	self:ResetDeleteButton()
end

function WorldsPanel:IsOpen()
	return self.isOpen
end

function WorldsPanel:Open()
	if self.isOpen or self.isAnimating then
		return
	end

	-- FIRST: Enable mouse control to unlock mouse BEFORE showing UI
	self:EnableMouseControl()

	self.isOpen = true
	self.isAnimating = true

	local hasInitialData = self:HasDatasetData("myWorlds")
	if not hasInitialData then
		self:_setDatasetStatus("myWorlds", "loading")
	end

	self:RefreshAll()
	self:ShowOverview()
	self:Show()
	UIVisibilityManager:SetMode("worlds")
	self:UpdateFriendsAutoRefreshState()

	self:AnimateOpen()

	-- Request worlds list (always request to ensure fresh data)
	self:RequestWorldsListUpdate({
		force = not hasInitialData,
		setLoading = not hasInitialData,
		reason = "open",
		targetTab = "myWorlds"
	})
end

function WorldsPanel:Close(nextMode)
	local targetMode = nextMode or "gameplay"
	self.pendingCloseMode = targetMode

	if self:IsClosing() then
		return
	end

	if not self.isOpen or self.isAnimating then
		return
	end

	self.isOpen = false
	self.isAnimating = true
	self:StopFriendsAutoRefresh()

	-- Clean up any spinners when closing
	if self.overviewSpinner then
		self:DestroySpinner(self.overviewSpinner)
		self.overviewSpinner = nil
	end
	if self.joinSpinner then
		self:DestroySpinner(self.joinSpinner)
		self.joinSpinner = nil
	end
	if self.hubSpinner then
		self:DestroySpinner(self.hubSpinner)
		self.hubSpinner = nil
	end
	self.isJoiningWorld = false
	self.isTeleportingToHub = false
	self:UpdateHubTeleportButtonState()

	local keepMouse = self:ShouldKeepMouseUnlocked(targetMode)
	if keepMouse then
		self:StopMouseTracking()
	else
		self:DisableMouseControl()
	end

	self:AnimateClose(function()
		UIVisibilityManager:SetMode(self.pendingCloseMode)
	end)
end

function WorldsPanel:Toggle()
	if self.isAnimating then
		return
	end

	if self.isOpen then
		self:Close()
	else
		self:Open()
	end
end

function WorldsPanel:AnimateOpen()
	if not self.panel then
		self.isAnimating = false
		return
	end

	local finalWidth = WORLDS_LAYOUT.TOTAL_WIDTH
	local finalHeight = WORLDS_LAYOUT.HEADER_HEIGHT + WORLDS_LAYOUT.BODY_HEIGHT
	local startHeight = WORLDS_LAYOUT.HEADER_HEIGHT

	self.panel.Size = UDim2.new(0, finalWidth, 0, startHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0, 60 + startHeight * 0.5)

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	self.currentTween = TweenService:Create(self.panel, tweenInfo, {
		Size = UDim2.new(0, finalWidth, 0, finalHeight),
		Position = UDim2.new(0.5, 0, 0.5, -WORLDS_LAYOUT.HEADER_HEIGHT)
	})

	self.currentTween.Completed:Connect(function()
		self.isAnimating = false
		self.currentTween = nil
	end)

	self.currentTween:Play()
end

function WorldsPanel:AnimateClose(onComplete)
	if not self.panel then
		self.isAnimating = false
		if onComplete then onComplete() end
		return
	end

	local finalWidth = WORLDS_LAYOUT.TOTAL_WIDTH
	local startHeight = WORLDS_LAYOUT.HEADER_HEIGHT

	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In)
	self.currentTween = TweenService:Create(self.panel, tweenInfo, {
		Size = UDim2.new(0, finalWidth, 0, startHeight),
		Position = UDim2.new(0.5, 0, 0, 60 + startHeight * 0.5)
	})

	self.currentTween.Completed:Connect(function()
		self.isAnimating = false
		self.currentTween = nil
		if onComplete then
			onComplete()
		end
	end)

	self.currentTween:Play()
end

function WorldsPanel:CreateContent(contentFrame)
	FontBinder.preload(CUSTOM_FONT_NAME)
	self.rootFrame = contentFrame

	for _, child in ipairs(contentFrame:GetChildren()) do
		child:Destroy()
	end

	self.worldCardMap = {}

	self:CreateHeader(contentFrame)
	self:CreateBody(contentFrame)
	self:UpdateTabAppearance()
	self:RefreshAll()

	print("WorldsPanel: Created voxel-styled worlds UI")
end

function WorldsPanel:CreateHeader(parent)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(0, WORLDS_LAYOUT.TOTAL_WIDTH, 0, WORLDS_LAYOUT.HEADER_HEIGHT)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "WORLDS"
	title.TextColor3 = COLOR.text
	title.Font = Enum.Font.Code
	title.TextSize = 54
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame
	FontBinder.apply(title, CUSTOM_FONT_NAME)

	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.new(0, 44, 0, 44),
		position = UDim2.new(1, 0, 0, 0),
		anchorPoint = Vector2.new(1, 0)
	})

	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = closeIcon.Size
	closeBtn.Position = closeIcon.Position
	closeBtn.AnchorPoint = closeIcon.AnchorPoint
	closeBtn.BackgroundTransparency = 1
	closeBtn.Image = closeIcon.Image
	closeBtn.ScaleType = closeIcon.ScaleType
	closeBtn.Parent = headerFrame
	closeIcon:Destroy()

	local rotateInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 0}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

function WorldsPanel:CreateBody(parent)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.new(0, WORLDS_LAYOUT.TOTAL_WIDTH, 0, WORLDS_LAYOUT.BODY_HEIGHT)
	bodyFrame.Position = UDim2.new(0, 0, 0, WORLDS_LAYOUT.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = parent

	self:CreateMenuColumn(bodyFrame)
	self:CreateContentPanel(bodyFrame)
end

function WorldsPanel:CreateMenuColumn(parent)
	local column = Instance.new("Frame")
	column.Name = "MenuColumn"
	column.Size = UDim2.new(0, WORLDS_LAYOUT.MENU_WIDTH, 0, WORLDS_LAYOUT.BODY_HEIGHT)
	column.BackgroundTransparency = 1
	column.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, WORLDS_LAYOUT.MENU_MARGIN)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = column

	self.sectionButtons = {}
	self:CreateNavButton(column, "myWorlds", "Nature", "Globe")
	self:CreateNavButton(column, "friendsWorlds", "Player", "Friends")
	self:CreateNavButton(column, "hubWorld", "General", "Home")
end

function WorldsPanel:CreateNavButton(parent, key, iconCategory, iconName)
	local visualSize = WORLDS_LAYOUT.MENU_BUTTON_SIZE
	local buttonSize = visualSize - 6
	local shadowHeight = 18

	local container = Instance.new("Frame")
	container.Name = key .. "_Container"
	container.Size = UDim2.new(0, visualSize, 0, visualSize + shadowHeight / 2)
	container.BackgroundTransparency = 1
	container.Parent = parent

	local button = Instance.new("ImageButton")
	button.Name = key .. "_Button"
	button.Size = UDim2.new(0, buttonSize, 0, buttonSize)
	button.Position = UDim2.new(0, 3, 0, 3)
	button.BackgroundColor3 = WORLDS_LAYOUT.NAV_BG_COLOR  -- Matching inventory menu button
	button.BackgroundTransparency = 0  -- Fully opaque, matching inventory
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.ZIndex = 1
	button.Parent = container

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, buttonSize, 0, shadowHeight)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.new(0, 3, 0, buttonSize + 3)
	shadow.BackgroundColor3 = WORLDS_LAYOUT.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)  -- Matching inventory menu button corner radius
	corner.Parent = button

	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = WORLDS_LAYOUT.COLUMN_BORDER_COLOR  -- Column border matching inventory
	border.Thickness = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS  -- Column border thickness
	border.Parent = button

	-- Create icon using IconManager (matching inventory)
	local icon = IconManager:CreateIcon(button, iconCategory, iconName, {
		size = UDim2.new(0, 64, 0, 64),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	})
	if icon then
		icon.ImageColor3 = Color3.fromRGB(185, 185, 195)  -- Default inactive color (matching inventory)
		icon.Name = "Icon"
	end

	button.MouseButton1Click:Connect(function()
		-- SwitchTab will handle showing overview if needed
		self:SwitchTab(key)
	end)

	self.sectionButtons[key] = {
		button = button,
		icon = icon
	}
end

function WorldsPanel:CreateContentPanel(parent)
	local columnWidth = WORLDS_LAYOUT.TOTAL_WIDTH - WORLDS_LAYOUT.MENU_WIDTH - WORLDS_LAYOUT.CONTENT_MARGIN
	local columnHeight = WORLDS_LAYOUT.BODY_HEIGHT
	local columnX = WORLDS_LAYOUT.MENU_WIDTH + WORLDS_LAYOUT.CONTENT_MARGIN
	local shadowHeight = WORLDS_LAYOUT.SHADOW_HEIGHT

	local column = Instance.new("Frame")
	column.Name = "ContentPanel"
	column.Size = UDim2.new(0, columnWidth, 0, columnHeight)
	column.Position = UDim2.new(0, columnX + 3, 0, 3)
	column.BackgroundColor3 = WORLDS_LAYOUT.PANEL_BG_COLOR
	column.BorderSizePixel = 0
	column.ZIndex = 1
	column.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = column

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, columnWidth, 0, shadowHeight)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.new(0, columnX + 3, 0, columnHeight + 3)
	shadow.BackgroundColor3 = WORLDS_LAYOUT.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local border = Instance.new("UIStroke")
	border.Color = WORLDS_LAYOUT.COLUMN_BORDER_COLOR  -- Column border matching inventory
	border.Thickness = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS  -- Column border thickness
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = column

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = column

	local contentStack = Instance.new("Frame")
	contentStack.Name = "ContentStack"
	contentStack.Size = UDim2.new(1, 0, 1, 0)
	contentStack.BackgroundTransparency = 1
	contentStack.Parent = column

	self.overviewContainer = Instance.new("Frame")
	self.overviewContainer.Name = "OverviewContainer"
	self.overviewContainer.Size = UDim2.new(1, 0, 1, 0)
	self.overviewContainer.BackgroundTransparency = 1
	self.overviewContainer.Parent = contentStack

	self.detailContainer = Instance.new("Frame")
	self.detailContainer.Name = "DetailContainer"
	self.detailContainer.Size = UDim2.new(1, 0, 1, 0)
	self.detailContainer.BackgroundTransparency = 1
	self.detailContainer.Visible = false
	self.detailContainer.Parent = contentStack

	self.hubContainer = Instance.new("Frame")
	self.hubContainer.Name = "HubContainer"
	self.hubContainer.Size = UDim2.new(1, 0, 1, 0)
	self.hubContainer.BackgroundTransparency = 1
	self.hubContainer.Visible = false
	self.hubContainer.Parent = contentStack

	self:BuildOverviewContent(self.overviewContainer)
	self:BuildDetailContent(self.detailContainer)
	self:BuildHubContent(self.hubContainer)

	self:ShowOverview()
end

function WorldsPanel:BuildOverviewContent(container)
	local headerHeight = math.max(WORLDS_LAYOUT.LABEL_HEIGHT, 40)
	local headerRow = Instance.new("Frame")
	headerRow.Name = "WorldListHeader"
	headerRow.Size = UDim2.new(1, 0, 0, headerHeight)
	headerRow.BackgroundTransparency = 1
	headerRow.Parent = container

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 6)
	headerPadding.PaddingRight = UDim.new(0, 6)
	headerPadding.Parent = headerRow

	local label = Instance.new("TextLabel")
	label.Name = "WorldListLabel"
	label.Size = UDim2.new(1, -70, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "MY WORLDS"
	label.TextColor3 = COLOR.textMuted
	label.Font = Enum.Font.Code
	label.TextSize = 24
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = headerRow
	FontBinder.apply(label, CUSTOM_FONT_NAME)
	self.listLabel = label

	local refreshButton = Instance.new("TextButton")
	refreshButton.Name = "RefreshFriendsButton"
	refreshButton.Size = UDim2.new(0, 40, 0, 40)
	refreshButton.AnchorPoint = Vector2.new(1, 0.5)
	refreshButton.Position = UDim2.new(1, 0, 0.5, 0)
	refreshButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT
	refreshButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	refreshButton.BorderSizePixel = 0
	refreshButton.AutoButtonColor = false
	refreshButton.Text = ""
	refreshButton.Visible = false
	refreshButton.Parent = headerRow
	self.refreshFriendsButton = refreshButton

	local refreshCorner = Instance.new("UICorner")
	refreshCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)
	refreshCorner.Parent = refreshButton

	local refreshStroke = Instance.new("UIStroke")
	refreshStroke.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR
	refreshStroke.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS
	refreshStroke.Parent = refreshButton

	local refreshBgImage = Instance.new("ImageLabel")
	refreshBgImage.Name = "BackgroundImage"
	refreshBgImage.Size = UDim2.new(1, 0, 1, 0)
	refreshBgImage.Position = UDim2.new(0, 0, 0, 0)
	refreshBgImage.BackgroundTransparency = 1
	refreshBgImage.Image = WORLDS_LAYOUT.BACKGROUND_IMAGE
	refreshBgImage.ImageTransparency = WORLDS_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
	refreshBgImage.ScaleType = Enum.ScaleType.Fit
	refreshBgImage.ZIndex = refreshButton.ZIndex
	refreshBgImage.Parent = refreshButton

	local refreshIcon = IconManager:CreateIcon(refreshButton, "UI", "Refresh", {
		size = UDim2.new(0, 24, 0, 24),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	})
	if refreshIcon then
		refreshIcon.ZIndex = refreshButton.ZIndex + 1
		self.refreshFriendsIcon = refreshIcon
	end

	local rotateInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	refreshButton.MouseEnter:Connect(function()
		if not refreshButton.Active then
			return
		end
		refreshButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT_HOVER
		refreshButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
		if self.refreshFriendsIcon then
			self.refreshFriendsIcon.ImageColor3 = COLOR.text
			TweenService:Create(self.refreshFriendsIcon, rotateInfo, {Rotation = 90}):Play()
		end
	end)
	refreshButton.MouseLeave:Connect(function()
		self:UpdateRefreshButtonState()
		if self.refreshFriendsIcon then
			TweenService:Create(self.refreshFriendsIcon, rotateInfo, {Rotation = 0}):Play()
		end
	end)
	refreshButton.MouseButton1Click:Connect(function()
		if refreshButton.Active then
			self:RequestFriendsRefresh()
		end
	end)

	local buttonSpacing = WORLDS_LAYOUT.LABEL_SPACING + 4

	local scrollTopOffset = headerHeight + buttonSpacing
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "WorldsScroll"
	scrollFrame.Position = UDim2.new(0, 0, 0, scrollTopOffset)
	scrollFrame.Size = UDim2.new(1, 0, 1, -scrollTopOffset)  -- Full height below label
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0  -- Remove border
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.Parent = container
	self.worldsScrollFrame = scrollFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 0)  -- Reduced gap between world cards
	listLayout.Parent = scrollFrame
	self:RegisterScrollingLayout(listLayout)

	-- Create World row (button + helper label)
	local createRow = Instance.new("Frame")
	createRow.Name = "CreateWorldRow"
	createRow.Size = UDim2.new(1, -12, 0, 56)
	createRow.BackgroundTransparency = 1
	createRow.LayoutOrder = 0
	createRow.Parent = scrollFrame
	self.createWorldRow = createRow

	local createRowPadding = Instance.new("UIPadding")
	createRowPadding.PaddingLeft = UDim.new(0, 6)
	createRowPadding.PaddingRight = UDim.new(0, 6)
	createRowPadding.Parent = createRow

	local createButtonWidth = 208

	local createButton = Instance.new("TextButton")
	createButton.Name = "CreateWorldButton"
	createButton.Size = UDim2.new(0, createButtonWidth, 1, 0)
	createButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN
	createButton.BackgroundTransparency = 0
	createButton.BorderSizePixel = 0
	createButton.AutoButtonColor = false
	createButton.Text = ""
	createButton.Parent = createRow
	self.createWorldButton = createButton

	local createCorner = Instance.new("UICorner")
	createCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	createCorner.Parent = createButton

	-- Disabled by default: no stroke
	self.createWorldBorder = nil

	-- Hover effects for green button
	createButton.MouseEnter:Connect(function()
		if createButton.Active then
			createButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN_HOVER
			createButton.BackgroundTransparency = 0
		end
	end)
	createButton.MouseLeave:Connect(function()
		self:UpdateCreateWorldButtonState()
	end)

	local plusLabel = Instance.new("TextLabel")
	plusLabel.Size = UDim2.new(0, 32, 0, 32)
	plusLabel.Position = UDim2.new(0, 8, 0.5, 0)
	plusLabel.AnchorPoint = Vector2.new(0, 0.5)
	plusLabel.BackgroundTransparency = 1
	plusLabel.Text = "+"
	plusLabel.TextColor3 = COLOR.text
	plusLabel.Font = BOLD_FONT
	plusLabel.TextSize = 28
	plusLabel.Parent = createButton
	self.createWorldPlusLabel = plusLabel

	local createLabel = Instance.new("TextLabel")
	createLabel.Name = "Label"
	createLabel.Size = UDim2.new(1, -48, 1, 0)
	createLabel.Position = UDim2.new(0, 48, 0, 0)
	createLabel.BackgroundTransparency = 1
	createLabel.Text = "Create New World"
	createLabel.TextColor3 = COLOR.text
	createLabel.Font = BOLD_FONT
	createLabel.TextSize = 20
	createLabel.TextXAlignment = Enum.TextXAlignment.Left
	createLabel.Parent = createButton
	self.createWorldLabel = createLabel

	local reasonLabelOffset = createButtonWidth + 12

	local reasonLabel = Instance.new("TextLabel")
	reasonLabel.Name = "CreateReasonLabel"
	reasonLabel.Size = UDim2.new(1, -reasonLabelOffset, 1, 0)
	reasonLabel.Position = UDim2.new(0, reasonLabelOffset, 0, 0)
	reasonLabel.BackgroundTransparency = 1
	reasonLabel.Text = ""
	reasonLabel.TextColor3 = COLOR.textMuted
	reasonLabel.Font = REGULAR_FONT
	reasonLabel.TextSize = 18
	reasonLabel.TextXAlignment = Enum.TextXAlignment.Left
	reasonLabel.TextYAlignment = Enum.TextYAlignment.Center
	reasonLabel.TextWrapped = true
	reasonLabel.Visible = false
	reasonLabel.Parent = createRow
	self.createWorldReasonLabel = reasonLabel

	local createSpacer = Instance.new("Frame")
	createSpacer.Name = "CreateWorldSpacer"
	createSpacer.Size = UDim2.new(1, 0, 0, buttonSpacing)
	createSpacer.BackgroundTransparency = 1
	createSpacer.LayoutOrder = 1
	createSpacer.Parent = scrollFrame
	self.createWorldSpacer = createSpacer

	createButton.MouseButton1Click:Connect(function()
		if createButton.Active then
			EventManager:SendToServer("RequestCreateWorld", {})
		end
	end)

	-- Create loading spinner for overview
	self.overviewSpinner = self:CreateLoadingSpinner(container)
	self.overviewSpinner.Visible = false

	self:UpdateRefreshButtonState()
end

function WorldsPanel:BuildDetailContent(container)
	local header = Instance.new("Frame")
	header.Name = "DetailHeader"
	header.Size = UDim2.new(1, 0, 0, 44)
	header.BackgroundTransparency = 1
	header.Parent = container

	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0, 56, 0, 56)  -- Matching inventory slot size
	backButton.Position = UDim2.new(0, 0, 0, 0)
	backButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT  -- Default for neutral action
	backButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	backButton.BorderSizePixel = 0
	backButton.Text = "←"
	backButton.TextColor3 = COLOR.text
	backButton.Font = BOLD_FONT
	backButton.TextSize = 20  -- MIN_TEXT_SIZE equivalent
	backButton.AutoButtonColor = false
	backButton.Parent = header
	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	backCorner.Parent = backButton

	-- Background image matching inventory
	local backBgImage = Instance.new("ImageLabel")
	backBgImage.Name = "BackgroundImage"
	backBgImage.Size = UDim2.new(1, 0, 1, 0)
	backBgImage.Position = UDim2.new(0, 0, 0, 0)
	backBgImage.BackgroundTransparency = 1
	backBgImage.Image = WORLDS_LAYOUT.BACKGROUND_IMAGE
	backBgImage.ImageTransparency = WORLDS_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
	backBgImage.ScaleType = Enum.ScaleType.Fit
	backBgImage.ZIndex = 1
	backBgImage.Parent = backButton

	-- Border matching inventory
	local backBorder = Instance.new("UIStroke")
	backBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
	backBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	backBorder.Transparency = 0
	backBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	backBorder.Parent = backButton

	-- Hover effects for default button
	backButton.MouseEnter:Connect(function()
		backButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT_HOVER
	end)
	backButton.MouseLeave:Connect(function()
		backButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT
		backButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	end)
	backButton.MouseButton1Click:Connect(function()
		self:ShowOverview()
	end)

	local detailTitle = Instance.new("TextLabel")
	detailTitle.Name = "DetailTitle"
	detailTitle.Size = UDim2.new(1, -200, 1, 0)
	detailTitle.Position = UDim2.new(0, 200, 0, 0)
	detailTitle.BackgroundTransparency = 1
	detailTitle.Text = "MANAGE WORLD"
	detailTitle.TextColor3 = COLOR.textMuted
	detailTitle.Font = Enum.Font.Code
	detailTitle.TextSize = 22
	detailTitle.TextXAlignment = Enum.TextXAlignment.Left
	detailTitle.TextYAlignment = Enum.TextYAlignment.Center
	detailTitle.Parent = header
	FontBinder.apply(detailTitle, CUSTOM_FONT_NAME)

	local detailScroll = Instance.new("ScrollingFrame")
	detailScroll.Name = "DetailScroll"
	detailScroll.Size = UDim2.new(1, 0, 1, -56)
	detailScroll.Position = UDim2.new(0, 0, 0, 56)
	detailScroll.BackgroundTransparency = 1
	detailScroll.ScrollBarThickness = 6
	detailScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detailScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	detailScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	detailScroll.Parent = container
	self.detailScroll = detailScroll

	local detailPadding = Instance.new("UIPadding")
	detailPadding.PaddingTop = UDim.new(0, 4)
	detailPadding.PaddingBottom = UDim.new(0, 4)
	detailPadding.PaddingLeft = UDim.new(0, 0)
	detailPadding.PaddingRight = UDim.new(0, 4)
	detailPadding.Parent = detailScroll

	local areaLayout = Instance.new("UIListLayout")
	areaLayout.FillDirection = Enum.FillDirection.Vertical
	areaLayout.SortOrder = Enum.SortOrder.LayoutOrder
	areaLayout.Padding = UDim.new(0, WORLDS_LAYOUT.LABEL_SPACING)
	areaLayout.Parent = detailScroll

	local emptyLabel = Instance.new("TextLabel")
	emptyLabel.Name = "DetailPlaceholder"
	emptyLabel.Size = UDim2.new(1, 0, 0, 120)
	emptyLabel.BackgroundTransparency = 1
	emptyLabel.Text = "Select a world to see details"
	emptyLabel.TextColor3 = COLOR.textMuted
	emptyLabel.TextWrapped = true
	emptyLabel.Font = REGULAR_FONT
	emptyLabel.TextSize = 20
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
	emptyLabel.LayoutOrder = 1
	emptyLabel.Parent = detailScroll
	self.detailPlaceholder = emptyLabel

	local detailCard = Instance.new("Frame")
	detailCard.Name = "DetailCard"
	detailCard.Size = UDim2.new(1, 0, 0, 0)
	detailCard.BackgroundColor3 = WORLDS_LAYOUT.SLOT_COLOR
	detailCard.BorderSizePixel = 0
	detailCard.Visible = false
	detailCard.LayoutOrder = 2
	detailCard.AutomaticSize = Enum.AutomaticSize.Y
	detailCard.Parent = detailScroll
	self.detailCard = detailCard

	local detailCorner = Instance.new("UICorner")
	detailCorner.CornerRadius = UDim.new(0, 8)
	detailCorner.Parent = detailCard

	local detailPadding = Instance.new("UIPadding")
	detailPadding.PaddingTop = UDim.new(0, 16)
	detailPadding.PaddingBottom = UDim.new(0, 16)
	detailPadding.PaddingLeft = UDim.new(0, 16)
	detailPadding.PaddingRight = UDim.new(0, 16)
	detailPadding.Parent = detailCard

	local cardLayout = Instance.new("UIListLayout")
	cardLayout.FillDirection = Enum.FillDirection.Vertical
	cardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cardLayout.Padding = UDim.new(0, 12)
	cardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	cardLayout.Parent = detailCard

	local headerRow = Instance.new("Frame")
	headerRow.Name = "HeaderRow"
	headerRow.Size = UDim2.new(1, 0, 0, 40)
	headerRow.BackgroundTransparency = 1
	headerRow.LayoutOrder = 1
	headerRow.Parent = detailCard

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -90, 1, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Unnamed World"
	nameLabel.TextColor3 = COLOR.text
	nameLabel.Font = Enum.Font.Code
	nameLabel.TextSize = 32
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = headerRow
	FontBinder.apply(nameLabel, CUSTOM_FONT_NAME)
	self.detailNameLabel = nameLabel

	local slotBadge = Instance.new("TextLabel")
	slotBadge.Name = "SlotBadge"
	slotBadge.Size = UDim2.new(0, 72, 0, 28)
	slotBadge.Position = UDim2.new(1, -72, 0, 6)
	slotBadge.BackgroundColor3 = COLOR.textMuted
	slotBadge.BorderSizePixel = 0
	slotBadge.Text = "Slot 1"
	slotBadge.TextColor3 = COLOR.text
	slotBadge.Font = BOLD_FONT
	slotBadge.TextSize = 16
	slotBadge.TextXAlignment = Enum.TextXAlignment.Center
	slotBadge.TextYAlignment = Enum.TextYAlignment.Center
	slotBadge.Parent = headerRow
	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slotBadge
	self.detailSlotBadge = slotBadge

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Offline"
	statusLabel.TextColor3 = COLOR.statusOffline
	statusLabel.Font = REGULAR_FONT
	statusLabel.TextSize = 18
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.LayoutOrder = 2
	statusLabel.Parent = detailCard
	self.detailStatusLabel = statusLabel

	local infoList = Instance.new("Frame")
	infoList.Name = "InfoList"
	infoList.Size = UDim2.new(1, 0, 0, 120)
	infoList.BackgroundTransparency = 1
	infoList.LayoutOrder = 3
	infoList.Parent = detailCard

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoLayout.Padding = UDim.new(0, 6)
	infoLayout.Parent = infoList

	local function createInfoRow(name)
		local row = Instance.new("Frame")
		row.Name = name .. "Row"
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.Parent = infoList

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.35, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = string.upper(name)
		label.TextColor3 = COLOR.textMuted
		label.Font = REGULAR_FONT
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Parent = row

		local value = Instance.new("TextLabel")
		value.Size = UDim2.new(0.65, 0, 1, 0)
		value.Position = UDim2.new(0.35, 0, 0, 0)
		value.BackgroundTransparency = 1
		value.Text = "--"
		value.TextColor3 = COLOR.text
		value.Font = BOLD_FONT
		value.TextSize = 16
		value.TextXAlignment = Enum.TextXAlignment.Left
		value.Parent = row
		return value
	end

	self.detailOwnerValue = createInfoRow("Owner")
	self.detailPlayerValue = createInfoRow("Players")
	self.detailCreatedValue = createInfoRow("Created")
	self.detailLastPlayedValue = createInfoRow("Last Played")

	local playButton = Instance.new("TextButton")
	playButton.Name = "JoinButton"
	playButton.Size = UDim2.new(1, 0, 0, 56)  -- Matching inventory slot height
	playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN  -- Green for success action
	playButton.BackgroundTransparency = 0  -- Fully opaque for colored buttons
	playButton.BorderSizePixel = 0
	playButton.TextColor3 = COLOR.text
	playButton.Text = "Join World"
	playButton.Font = BOLD_FONT
	playButton.TextSize = 20
	playButton.AutoButtonColor = false
	playButton.LayoutOrder = 4
	playButton.Parent = detailCard
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	playCorner.Parent = playButton

	-- Border matching inventory
	local playBorder = Instance.new("UIStroke")
	playBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
	playBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	playBorder.Transparency = 0
	playBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playBorder.Parent = playButton

	-- Hover effects for green button
	playButton.MouseEnter:Connect(function()
		playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN_HOVER
	end)
	playButton.MouseLeave:Connect(function()
		playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN
		playButton.BackgroundTransparency = 0
	end)
	playButton.MouseButton1Click:Connect(function()
		local selected = self:FindWorldById(self.selectedWorldId)
		if selected then
			self:JoinWorld(selected)
		end
	end)
	self.playButton = playButton

	local actionsCard = Instance.new("Frame")
	actionsCard.Name = "ManageActions"
	actionsCard.Size = UDim2.new(1, 0, 0, 0)
	actionsCard.BackgroundColor3 = WORLDS_LAYOUT.SLOT_COLOR
	actionsCard.BorderSizePixel = 0
	actionsCard.Visible = false
	actionsCard.LayoutOrder = 5
	actionsCard.AutomaticSize = Enum.AutomaticSize.Y
	actionsCard.Parent = detailScroll

	local actionsCorner = Instance.new("UICorner")
	actionsCorner.CornerRadius = UDim.new(0, 8)
	actionsCorner.Parent = actionsCard

	local actionsStroke = Instance.new("UIStroke")
	actionsStroke.Color = WORLDS_LAYOUT.COLUMN_BORDER_COLOR  -- Column border for container
	actionsStroke.Thickness = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS  -- Column border thickness
	actionsStroke.Transparency = 0
	actionsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	actionsStroke.Parent = actionsCard

	local actionsPadding = Instance.new("UIPadding")
	actionsPadding.PaddingTop = UDim.new(0, 12)
	actionsPadding.PaddingBottom = UDim.new(0, 12)
	actionsPadding.PaddingLeft = UDim.new(0, 16)
	actionsPadding.PaddingRight = UDim.new(0, 16)
	actionsPadding.Parent = actionsCard

	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Vertical
	actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionsLayout.Padding = UDim.new(0, 12)
	actionsLayout.Parent = actionsCard

	local actionsHeader = Instance.new("TextLabel")
	actionsHeader.Name = "ActionsHeader"
	actionsHeader.Size = UDim2.new(1, 0, 0, 24)
	actionsHeader.BackgroundTransparency = 1
	actionsHeader.Text = "MANAGE"
	actionsHeader.TextColor3 = COLOR.textMuted
	actionsHeader.Font = Enum.Font.Code
	actionsHeader.TextSize = 20
	actionsHeader.TextXAlignment = Enum.TextXAlignment.Left
	actionsHeader.LayoutOrder = 0
	actionsHeader.Parent = actionsCard
	FontBinder.apply(actionsHeader, CUSTOM_FONT_NAME)

	local manageHint = Instance.new("TextLabel")
	manageHint.Name = "ManageHint"
	manageHint.Size = UDim2.new(1, 0, 0, 36)
	manageHint.BackgroundTransparency = 1
	manageHint.Text = "Only the owner can rename or delete this world."
	manageHint.TextWrapped = true
	manageHint.TextColor3 = COLOR.textMuted
	manageHint.Font = REGULAR_FONT
	manageHint.TextSize = 16
	manageHint.TextXAlignment = Enum.TextXAlignment.Left
	manageHint.TextYAlignment = Enum.TextYAlignment.Center
	manageHint.Visible = false
	manageHint.LayoutOrder = 1
	manageHint.Parent = actionsCard
	self.manageHintLabel = manageHint

	local renameSection = Instance.new("Frame")
	renameSection.Name = "RenameSection"
	renameSection.Size = UDim2.new(1, 0, 0, 44)
	renameSection.BackgroundTransparency = 1
	renameSection.Visible = false
	renameSection.LayoutOrder = 2
	renameSection.Parent = actionsCard
	self.renameSection = renameSection

	local renameLayout = Instance.new("UIListLayout")
	renameLayout.FillDirection = Enum.FillDirection.Horizontal
	renameLayout.SortOrder = Enum.SortOrder.LayoutOrder
	renameLayout.Padding = UDim.new(0, 8)
	renameLayout.Parent = renameSection

	local renameInput = Instance.new("TextBox")
	renameInput.Name = "RenameInput"
	renameInput.Size = UDim2.new(0.65, 0, 1, 0)
	renameInput.BackgroundColor3 = WORLDS_LAYOUT.SLOT_BG_COLOR
	renameInput.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	renameInput.BorderSizePixel = 0
	renameInput.Text = ""
	renameInput.TextColor3 = COLOR.text
	renameInput.Font = REGULAR_FONT
	renameInput.TextSize = 20  -- MIN_TEXT_SIZE equivalent
	renameInput.TextXAlignment = Enum.TextXAlignment.Left
	renameInput.PlaceholderText = "Rename world"
	renameInput.Parent = renameSection
	local renameInputCorner = Instance.new("UICorner")
	renameInputCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	renameInputCorner.Parent = renameInput

	-- Background image matching inventory
	local renameInputBgImage = Instance.new("ImageLabel")
	renameInputBgImage.Name = "BackgroundImage"
	renameInputBgImage.Size = UDim2.new(1, 0, 1, 0)
	renameInputBgImage.Position = UDim2.new(0, 0, 0, 0)
	renameInputBgImage.BackgroundTransparency = 1
	renameInputBgImage.Image = WORLDS_LAYOUT.BACKGROUND_IMAGE
	renameInputBgImage.ImageTransparency = WORLDS_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
	renameInputBgImage.ScaleType = Enum.ScaleType.Fit
	renameInputBgImage.ZIndex = 1
	renameInputBgImage.Parent = renameInput

	local renameStroke = Instance.new("UIStroke")
	renameStroke.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for inputs
	renameStroke.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	renameStroke.Transparency = 0
	renameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	renameStroke.Parent = renameInput
	self.renameInput = renameInput

	local renameButton = Instance.new("TextButton")
	renameButton.Name = "RenameButton"
	renameButton.Size = UDim2.new(0.35, 0, 1, 0)
	renameButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT  -- Default for neutral action
	renameButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	renameButton.BorderSizePixel = 0
	renameButton.Text = "Rename"
	renameButton.TextColor3 = COLOR.text
	renameButton.Font = BOLD_FONT
	renameButton.TextSize = 20  -- MIN_TEXT_SIZE equivalent
	renameButton.AutoButtonColor = false
	renameButton.Parent = renameSection
	local renameBtnCorner = Instance.new("UICorner")
	renameBtnCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	renameBtnCorner.Parent = renameButton

	-- Background image matching inventory
	local renameBtnBgImage = Instance.new("ImageLabel")
	renameBtnBgImage.Name = "BackgroundImage"
	renameBtnBgImage.Size = UDim2.new(1, 0, 1, 0)
	renameBtnBgImage.Position = UDim2.new(0, 0, 0, 0)
	renameBtnBgImage.BackgroundTransparency = 1
	renameBtnBgImage.Image = WORLDS_LAYOUT.BACKGROUND_IMAGE
	renameBtnBgImage.ImageTransparency = WORLDS_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
	renameBtnBgImage.ScaleType = Enum.ScaleType.Fit
	renameBtnBgImage.ZIndex = 1
	renameBtnBgImage.Parent = renameButton

	-- Border matching inventory
	local renameBtnBorder = Instance.new("UIStroke")
	renameBtnBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
	renameBtnBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	renameBtnBorder.Transparency = 0
	renameBtnBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	renameBtnBorder.Parent = renameButton

	-- Hover effects for default button
	renameButton.MouseEnter:Connect(function()
		if renameButton.Active then
			renameButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT_HOVER
		end
	end)
	renameButton.MouseLeave:Connect(function()
		-- Will be updated by UpdateRenameButtonState
	end)
	self.renameButton = renameButton

	renameButton.MouseButton1Click:Connect(function()
		self:HandleRename()
	end)
	renameInput:GetPropertyChangedSignal("Text"):Connect(function()
		self:UpdateRenameButtonState()
	end)

	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteButton"
	deleteButton.Size = UDim2.new(1, 0, 0, 56)  -- Matching inventory slot height
	deleteButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_RED  -- Red for danger action
	deleteButton.BackgroundTransparency = 0  -- Fully opaque for colored buttons
	deleteButton.BorderSizePixel = 0
	deleteButton.Text = "Delete World"
	deleteButton.TextColor3 = COLOR.text
	deleteButton.Font = BOLD_FONT
	deleteButton.TextSize = 20  -- MIN_TEXT_SIZE equivalent
	deleteButton.AutoButtonColor = false
	deleteButton.Visible = false
	deleteButton.LayoutOrder = 3
	deleteButton.Parent = actionsCard
	local deleteCorner = Instance.new("UICorner")
	deleteCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	deleteCorner.Parent = deleteButton

	-- Border matching inventory
	local deleteBorder = Instance.new("UIStroke")
	deleteBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
	deleteBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	deleteBorder.Transparency = 0
	deleteBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	deleteBorder.Parent = deleteButton

	-- Hover effects for red button
	deleteButton.MouseEnter:Connect(function()
		deleteButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_RED_HOVER
	end)
	deleteButton.MouseLeave:Connect(function()
		-- Will be updated by ResetDeleteButton
	end)
	deleteButton.MouseButton1Click:Connect(function()
		self:HandleDeleteClick()
	end)
	self.deleteButton = deleteButton

	self.actionsCard = actionsCard

end

function WorldsPanel:BuildHubContent(container)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = container

	local stack = Instance.new("Frame")
	stack.Name = "HubStack"
	stack.Size = UDim2.new(1, 0, 1, 0)
	stack.BackgroundTransparency = 1
	stack.Parent = container

	local stackLayout = Instance.new("UIListLayout")
	stackLayout.FillDirection = Enum.FillDirection.Vertical
	stackLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stackLayout.Padding = UDim.new(0, WORLDS_LAYOUT.LABEL_SPACING)
	stackLayout.Parent = stack

	local label = Instance.new("TextLabel")
	label.Name = "HubLabel"
	label.Size = UDim2.new(1, 0, 0, WORLDS_LAYOUT.LABEL_HEIGHT + 6)
	label.BackgroundTransparency = 1
	label.Text = "HUB WORLD"
	label.TextColor3 = COLOR.textMuted
	label.Font = Enum.Font.Code
	label.TextSize = LABEL_SIZE
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.LayoutOrder = 1
	label.Parent = stack
	FontBinder.apply(label, CUSTOM_FONT_NAME)

	local borderMargin = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS
	local cardHeight = 130

	local containerFrame = Instance.new("Frame")
	containerFrame.Name = "HubCardContainer"
	containerFrame.Size = UDim2.new(1, -12, 0, cardHeight + 18 + (borderMargin * 2))
	containerFrame.BackgroundTransparency = 1
	containerFrame.ClipsDescendants = false
	containerFrame.LayoutOrder = 2
	containerFrame.ZIndex = 1
	containerFrame.Parent = stack

	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingLeft = UDim.new(0, borderMargin)
	containerPadding.PaddingRight = UDim.new(0, borderMargin)
	containerPadding.PaddingTop = UDim.new(0, borderMargin)
	containerPadding.PaddingBottom = UDim.new(0, borderMargin)
	containerPadding.Parent = containerFrame

	local card = Instance.new("Frame")
	card.Name = "HubCard"
	card.Size = UDim2.new(1, 0, 0, cardHeight)
	card.BackgroundColor3 = WORLDS_LAYOUT.PANEL_BG_COLOR
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = containerFrame

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)
	cardCorner.Parent = card

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = WORLDS_LAYOUT.COLUMN_BORDER_COLOR
	cardStroke.Thickness = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS
	cardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardStroke.Parent = card

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 0, WORLDS_LAYOUT.SHADOW_HEIGHT)
	shadow.AnchorPoint = Vector2.new(0, 1)
	shadow.Position = UDim2.new(0, 0, 1, -9)
	shadow.BackgroundColor3 = WORLDS_LAYOUT.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = containerFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local textColumn = Instance.new("Frame")
	textColumn.Name = "HubTextColumn"
	textColumn.Size = UDim2.new(1, -180, 1, -24)
	textColumn.Position = UDim2.new(0, 12, 0, 12)
	textColumn.BackgroundTransparency = 1
	textColumn.Parent = card

	local textLayout = Instance.new("UIListLayout")
	textLayout.FillDirection = Enum.FillDirection.Vertical
	textLayout.SortOrder = Enum.SortOrder.LayoutOrder
	textLayout.Padding = UDim.new(0, 6)
	textColumn.ClipsDescendants = false
	textColumn.ZIndex = 2
	textLayout.Parent = textColumn

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "HubName"
	nameLabel.Size = UDim2.new(1, 0, 0, 32)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Global Hub"
	nameLabel.TextColor3 = COLOR.text
	nameLabel.Font = BOLD_FONT
	nameLabel.TextSize = MIN_TEXT_SIZE
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.LayoutOrder = 1
	nameLabel.Parent = textColumn

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "HubStatus"
	statusLabel.Size = UDim2.new(1, 0, 0, 22)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Live lobby · Social quests · Featured vendors"
	statusLabel.TextColor3 = COLOR.textMuted
	statusLabel.Font = REGULAR_FONT
	statusLabel.TextSize = MIN_TEXT_SIZE
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
	statusLabel.LayoutOrder = 2
	statusLabel.Parent = textColumn

	local descriptionLabel = Instance.new("TextLabel")
	descriptionLabel.Name = "HubDescription"
	descriptionLabel.Size = UDim2.new(1, 0, 0, 38)
	descriptionLabel.BackgroundTransparency = 1
	descriptionLabel.Text = "Link up with friends, grab hub-only rewards, or jump into your own world without respawning elsewhere."
	descriptionLabel.TextColor3 = COLOR.textMuted
	descriptionLabel.Font = REGULAR_FONT
	descriptionLabel.TextSize = MIN_TEXT_SIZE
	descriptionLabel.TextXAlignment = Enum.TextXAlignment.Left
	descriptionLabel.TextWrapped = true
	descriptionLabel.TextYAlignment = Enum.TextYAlignment.Top
	descriptionLabel.LayoutOrder = 3
	descriptionLabel.Parent = textColumn

	local actionFrame = Instance.new("Frame")
	actionFrame.Name = "HubActions"
	actionFrame.Size = UDim2.new(0, 160, 0, 56)
	actionFrame.AnchorPoint = Vector2.new(1, 1)
	actionFrame.Position = UDim2.new(1, -12, 1, -12)
	actionFrame.BackgroundTransparency = 1
	actionFrame.ZIndex = 3
	actionFrame.Parent = card

	local teleportButton = Instance.new("TextButton")
	teleportButton.Name = "TeleportToHubButton"
	teleportButton.Size = UDim2.new(1, 0, 1, 0)
	teleportButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_BLUE
	teleportButton.BackgroundTransparency = 0
	teleportButton.BorderSizePixel = 0
	teleportButton.Text = "Return to Hub"
	teleportButton.TextColor3 = COLOR.text
	teleportButton.Font = BOLD_FONT
	teleportButton.TextSize = MIN_TEXT_SIZE
	teleportButton.AutoButtonColor = false
	teleportButton.ZIndex = 4
	teleportButton.Parent = actionFrame
	self.teleportToHubButton = teleportButton

	local teleportCorner = Instance.new("UICorner")
	teleportCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)
	teleportCorner.Parent = teleportButton

	local teleportStroke = Instance.new("UIStroke")
	teleportStroke.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR
	teleportStroke.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS
	teleportStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	teleportStroke.Parent = teleportButton

	teleportButton.MouseEnter:Connect(function()
		if self.isTeleportingToHub then
			return
		end
		teleportButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_BLUE_HOVER
	end)
	teleportButton.MouseLeave:Connect(function()
		self:UpdateHubTeleportButtonState()
	end)
	teleportButton.MouseButton1Click:Connect(function()
		self:TeleportToHub()
	end)

	self:UpdateHubTeleportButtonState()

	self.hubSpinner = self:CreateLoadingSpinner(card)
	if self.hubSpinner then
		self.hubSpinner.Visible = false
	end
end

function WorldsPanel:CreateLoadingSpinner(parent)
	local spinnerContainer = Instance.new("Frame")
	spinnerContainer.Name = "LoadingSpinner"
	spinnerContainer.Size = UDim2.new(1, 0, 1, 0)
	spinnerContainer.BackgroundTransparency = 1
	spinnerContainer.ZIndex = 10
	spinnerContainer.Visible = false  -- Start hidden, will be set to visible when needed
	spinnerContainer.Parent = parent

	local spinner = Instance.new("Frame")
	spinner.Name = "Spinner"
	spinner.Size = UDim2.new(0, 48, 0, 48)
	spinner.AnchorPoint = Vector2.new(0.5, 0.5)
	spinner.Position = UDim2.new(0.5, 0, 0.5, 0)
	spinner.BackgroundTransparency = 1
	spinner.Parent = spinnerContainer

	-- Create base circle (subtle background)
	local circle = Instance.new("Frame")
	circle.Name = "Circle"
	circle.Size = UDim2.new(0, 40, 0, 40)
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.new(0.5, 0, 0.5, 0)
	circle.BackgroundTransparency = 1
	circle.Parent = spinner

	local circleCorner = Instance.new("UICorner")
	circleCorner.CornerRadius = UDim.new(0, 20)
	circleCorner.Parent = circle

	local circleStroke = Instance.new("UIStroke")
	circleStroke.Color = COLOR.textMuted
	circleStroke.Thickness = 3
	circleStroke.Transparency = 1  -- Fully transparent
	circleStroke.Parent = circle

	-- Create rotating arc container
	local arcContainer = Instance.new("Frame")
	arcContainer.Name = "ArcContainer"
	arcContainer.Size = UDim2.new(0, 40, 0, 40)
	arcContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	arcContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	arcContainer.BackgroundTransparency = 1
	arcContainer.Parent = spinner

	-- Create 4 visible dots positioned around the circle that will rotate
	local function createDot(angle)
		local dotSize = 6
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.Size = UDim2.new(0, dotSize, 0, dotSize)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)

		-- Position dots around the circle (radius of ~16px from center)
		local rad = math.rad(angle)
		local radius = 16
		dot.Position = UDim2.new(0.5, math.cos(rad) * radius, 0.5, math.sin(rad) * radius)

		dot.BackgroundColor3 = COLOR.text
		dot.BackgroundTransparency = 0
		dot.BorderSizePixel = 0
		dot.Parent = arcContainer

		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0, dotSize / 2)  -- Exactly half for perfect circle
		dotCorner.Parent = dot

		return dot
	end

	-- Create 4 dots at 0, 90, 180, 270 degrees
	createDot(0)
	createDot(90)
	createDot(180)
	createDot(270)

	-- Rotation animation
	local rotationConnection = nil
	local startTime = 0

	local function startRotation()
		if rotationConnection then
			rotationConnection:Disconnect()
			rotationConnection = nil
		end
		startTime = tick()
		rotationConnection = RunService.RenderStepped:Connect(function()
			if arcContainer.Parent and spinnerContainer.Visible and spinnerContainer.Parent then
				local elapsed = tick() - startTime
				arcContainer.Rotation = elapsed * 360 % 360
			else
				if rotationConnection then
					rotationConnection:Disconnect()
					rotationConnection = nil
				end
			end
		end)
	end

	local function stopRotation()
		if rotationConnection then
			rotationConnection:Disconnect()
			rotationConnection = nil
		end
	end

	local visibleConnection = spinnerContainer:GetPropertyChangedSignal("Visible"):Connect(function()
		if spinnerContainer.Visible then
			startRotation()
		else
			stopRotation()
		end
	end)

	-- Start rotation immediately if spinner is already visible
	if spinnerContainer.Visible then
		startRotation()
	end

	-- Clean up connections when spinner is destroyed
	spinnerContainer.AncestryChanged:Connect(function()
		if not spinnerContainer.Parent then
			stopRotation()
			if visibleConnection then
				visibleConnection:Disconnect()
			end
		end
	end)

	return spinnerContainer
end

function WorldsPanel:DestroySpinner(spinner)
	if not spinner then
		return
	end

	-- Set visible to false first to trigger connection cleanup
	pcall(function()
		spinner.Visible = false
	end)

	-- Destroy the spinner immediately (connections will be cleaned up by AncestryChanged)
	pcall(function()
		if spinner.Parent then
			spinner:Destroy()
		end
	end)
end

function WorldsPanel:ShowOverview()
	if not self.overviewContainer or not self.detailContainer then
		return
	end
	self.overviewContainer.Visible = true
	self.detailContainer.Visible = false
	if self.hubContainer then
		self.hubContainer.Visible = false
	end
	self.contentMode = "overview"
	self:UpdateSelectionHighlight()
	if self.detailScroll then
		self.detailScroll.CanvasPosition = Vector2.new(0, 0)
	end

	-- Clean up join spinner when switching views
	if self.joinSpinner then
		self:DestroySpinner(self.joinSpinner)
		self.joinSpinner = nil
	end
	if self.hubSpinner then
		self.hubSpinner.Visible = false
	end

	self:UpdateOverviewSpinnerVisibility()
	self:UpdateListVisibility()
end

function WorldsPanel:ShowDetail(worldId)
	if worldId then
		self.selectedWorldId = worldId
	end
	if not self.overviewContainer or not self.detailContainer then
		return
	end
	self.overviewContainer.Visible = false
	self.detailContainer.Visible = true
	if self.hubContainer then
		self.hubContainer.Visible = false
	end
	self.contentMode = "detail"

	-- Clean up overview spinner when switching to detail
	if self.overviewSpinner then
		self:DestroySpinner(self.overviewSpinner)
		self.overviewSpinner = nil
	end

	-- Clean up join spinner when switching views
	if self.joinSpinner then
		self:DestroySpinner(self.joinSpinner)
		self.joinSpinner = nil
	end
	if self.hubSpinner then
		self.hubSpinner.Visible = false
	end
	self:UpdateDetailPanel()

	if self.detailScroll then
		self.detailScroll.CanvasPosition = Vector2.new(0, 0)
	end
end

function WorldsPanel:ShowHub()
	if not self.hubContainer then
		return
	end
	if self.overviewContainer then
		self.overviewContainer.Visible = false
	end
	if self.detailContainer then
		self.detailContainer.Visible = false
	end
	self.hubContainer.Visible = true
	self.contentMode = "hub"

	-- Clean up any spinners when switching to hub
	if self.overviewSpinner then
		self:DestroySpinner(self.overviewSpinner)
		self.overviewSpinner = nil
	end
	if self.joinSpinner then
		self:DestroySpinner(self.joinSpinner)
		self.joinSpinner = nil
	end
	if self.hubSpinner then
		self.hubSpinner.Visible = self.isTeleportingToHub == true
	end

	self:UpdateHubTeleportButtonState()
end

function WorldsPanel:SwitchTab(tabName)
	if tabName ~= "myWorlds" and tabName ~= "friendsWorlds" and tabName ~= "hubWorld" then
		return
	end

	-- Clean up any existing spinner before switching
	if self.overviewSpinner then
		self:DestroySpinner(self.overviewSpinner)
		self.overviewSpinner = nil
	end

	local previousTab = self.currentTab
	self.currentTab = tabName

	-- Handle hub world tab specially
	if tabName == "hubWorld" then
		self:ShowHub()
		self:UpdateTabAppearance()
		self:UpdateListHeader()
		self:UpdateFriendsAutoRefreshState()
		return
	end

	-- Ensure we're on overview view before switching tabs
	if self.contentMode ~= "overview" then
		self:ShowOverview()
	end

	self:UpdateTabAppearance()
	self:UpdateFriendsAutoRefreshState()
	self:RefreshWorldsList()

	if previousTab ~= tabName then
		-- Request fresh data only when the tab actually changes
		self:RequestWorldsListUpdate({
			reason = "switchTab",
			targetTab = tabName
		})
	end
end

function WorldsPanel:UpdateTabAppearance()
	for name, info in pairs(self.sectionButtons) do
		local isActive = name == self.currentTab
		if info.button then
			-- Keep background fully opaque with NAV_BG_COLOR (matching inventory)
			info.button.BackgroundTransparency = 0
			info.button.BackgroundColor3 = WORLDS_LAYOUT.NAV_BG_COLOR
		end
		if info.icon then
			-- Only change icon color for active state (matching inventory)
			info.icon.ImageColor3 = isActive and COLOR.text or COLOR.textSecondary
		end
	end

	self:UpdateRefreshButtonState()
	self:UpdateOverviewSpinnerVisibility()
end

function WorldsPanel:UpdateRefreshButtonState()
	if not self.refreshFriendsButton then
		return
	end

	local button = self.refreshFriendsButton
	local isFriendsTab = self.currentTab == "friendsWorlds"
	local hideForSpinner = self:ShouldShowOverviewSpinner()
	button.Visible = isFriendsTab and not hideForSpinner

	if not button.Visible then
		if self.refreshFriendsIcon then
			self.refreshFriendsIcon.ImageColor3 = COLOR.textMuted
		end
		return
	end

	local refreshing = self:IsTabLoading("friendsWorlds")
	button.Active = not refreshing
	button.AutoButtonColor = false
	button.Text = ""

	if refreshing then
		button.BackgroundColor3 = WORLDS_LAYOUT.BTN_DISABLED
		button.BackgroundTransparency = WORLDS_LAYOUT.BTN_DISABLED_TRANSPARENCY
	else
		button.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT
		button.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	end

	if self.refreshFriendsIcon then
		self.refreshFriendsIcon.ImageColor3 = refreshing and COLOR.textMuted or COLOR.text
	end
end

function WorldsPanel:ShouldShowOverviewSpinner()
	if not (self.overviewContainer and self.overviewContainer.Visible) then
		return false
	end

	if not self:IsTabLoading(self.currentTab) then
		return false
	end

	return not self:_tabHasItems(self.currentTab)
end

function WorldsPanel:UpdateOverviewSpinnerVisibility()
	if not self.overviewContainer then
		return
	end

	local shouldShow = self:ShouldShowOverviewSpinner()
	if shouldShow then
		if not self.overviewSpinner or not self.overviewSpinner.Parent then
			self.overviewSpinner = self:CreateLoadingSpinner(self.overviewContainer)
		end
		self.overviewSpinner.Visible = true
	elseif self.overviewSpinner then
		self.overviewSpinner.Visible = false
	end

	self:UpdateEmptyStateVisibility()
	self:UpdateListVisibility()
end

function WorldsPanel:UpdateEmptyStateVisibility()
	if not self.emptyStateLabel then
		return
	end
	if not self.emptyStateLabel.Parent then
		self.emptyStateLabel = nil
		return
	end

	self.emptyStateLabel.Visible = not self:ShouldShowOverviewSpinner()
end

function WorldsPanel:UpdateListVisibility()
	if not self.worldsScrollFrame then
		return
	end

	local shouldShowSpinner = self:ShouldShowOverviewSpinner()
	self.worldsScrollFrame.Visible = not shouldShowSpinner
	if self.createWorldButton then
		if shouldShowSpinner then
			if self.createWorldRow then
				self.createWorldRow.Visible = false
			end
			if self.createWorldSpacer then
				self.createWorldSpacer.Visible = false
			end
			self.createWorldButton.Visible = false
			if self.createWorldReasonLabel then
				self.createWorldReasonLabel.Visible = false
				self.createWorldReasonLabel.Text = ""
			end
		else
			self:UpdateCreateWorldButtonState()
		end
	end
end

function WorldsPanel:ApplyWorldCardData(card, worldData)
	if not card or not worldData then
		return
	end

	local nameLabel = card:FindFirstChild("Name")
	if nameLabel then
		nameLabel.Text = worldData.name or "Unnamed World"
	end

	local statusLabel = card:FindFirstChild("Status")
	if statusLabel then
		statusLabel.Text = self:FormatStatus(worldData)
		statusLabel.TextColor3 = worldData.online and COLOR.statusOnline or COLOR.statusOffline
	end

	local lastPlayed = card:FindFirstChild("LastPlayed")
	if lastPlayed then
		lastPlayed.Text = "Last played " .. self:FormatTimestamp(worldData.lastPlayed)
	end
end

function WorldsPanel:ClearWorldCards()
	for _, info in pairs(self.worldCardMap) do
		if info.container then
			info.container:Destroy()
		end
	end
	self.worldCardMap = {}
end

function WorldsPanel:CreateWorldCard(worldData)
	local worldId = worldData.worldId
	-- Container to hold card and shadow
	local container = Instance.new("Frame")
	container.Name = "WorldCardContainer_" .. worldId
	local borderMargin = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS  -- Margin to account for border on all sides
	container.Size = UDim2.new(1, -12, 0, 110 + 18 + (borderMargin * 2))  -- Right margin for scrollbar, plus shadow height, plus border margins
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false  -- Allow shadow to be visible
	container.ZIndex = 1  -- Ensure proper layering
	container.Parent = self.worldsScrollFrame

	-- Padding to account for border on all sides
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, borderMargin)
	padding.PaddingRight = UDim.new(0, borderMargin)
	padding.PaddingTop = UDim.new(0, borderMargin)
	padding.PaddingBottom = UDim.new(0, borderMargin)
	padding.Parent = container

	local card = Instance.new("Frame")
	card.Name = "WorldCard_" .. worldId
	card.Size = UDim2.new(1, 0, 0, 110)
	card.BackgroundColor3 = WORLDS_LAYOUT.PANEL_BG_COLOR  -- Panel background color
	card.BorderSizePixel = 0
	card.ZIndex = 2  -- Above shadow
	card.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)
	corner.Parent = card

	local border = Instance.new("UIStroke")
	border.Color = WORLDS_LAYOUT.COLUMN_BORDER_COLOR  -- Panel border color
	border.Thickness = WORLDS_LAYOUT.COLUMN_BORDER_THICKNESS  -- Panel border thickness
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = card

	-- Shadow below card - positioned at bottom of container to ensure visibility
	-- Shadow is slightly wider than card (a few pixels on each side)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 0, 18)  -- Full width minus padding, plus 4px wider (2px on each side), 18px height
	shadow.AnchorPoint = Vector2.new(0, 1)  -- Bottom-left anchor
	shadow.Position = UDim2.new(0, 0, 1, -9)  -- 2px wider on left (extends beyond card), 3px from bottom
	shadow.BackgroundColor3 = WORLDS_LAYOUT.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1  -- Above container background, below card
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -180, 0, 32)
	nameLabel.Position = UDim2.new(0, 12, 0, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = COLOR.text
	nameLabel.Font = BOLD_FONT
	nameLabel.TextSize = MIN_TEXT_SIZE  -- Standard minimum text size
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3  -- Above card background
	nameLabel.Parent = card

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -180, 0, 22)
	statusLabel.Position = UDim2.new(0, 12, 0, 44)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = REGULAR_FONT
	statusLabel.TextSize = MIN_TEXT_SIZE  -- Standard minimum text size
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.ZIndex = 3  -- Above card background
	statusLabel.Parent = card

	local lastPlayed = Instance.new("TextLabel")
	lastPlayed.Name = "LastPlayed"
	lastPlayed.Size = UDim2.new(1, -180, 0, 20)
	lastPlayed.Position = UDim2.new(0, 12, 0, 68)
	lastPlayed.BackgroundTransparency = 1
	lastPlayed.TextColor3 = COLOR.textMuted
	lastPlayed.Font = REGULAR_FONT
	lastPlayed.TextSize = MIN_TEXT_SIZE  -- Standard minimum text size
	lastPlayed.TextXAlignment = Enum.TextXAlignment.Left
	lastPlayed.ZIndex = 3  -- Above card background
	lastPlayed.Parent = card

	local actionFrame = Instance.new("Frame")
	actionFrame.Name = "Actions"
	actionFrame.Size = UDim2.new(0, 224, 0, 56)  -- 160px play + 8px spacing + 56px manage = 224px width, 56px height
	actionFrame.AnchorPoint = Vector2.new(1, 0.5)  -- Right-aligned horizontally, centered vertically
	actionFrame.Position = UDim2.new(1, -12, 0.5, 0)  -- 12px from right edge, vertically centered
	actionFrame.BackgroundTransparency = 1
	actionFrame.ZIndex = 3  -- Above card background
	actionFrame.Parent = card

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Horizontal  -- Horizontal layout for side-by-side buttons
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Padding = UDim.new(0, 8)  -- 8px spacing between buttons
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Parent = actionFrame

	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0, 160, 0, 56)  -- Original width retained (160px)
	playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN  -- Green for success action
	playButton.BackgroundTransparency = 0  -- Fully opaque for colored buttons
	playButton.BorderSizePixel = 0
	playButton.Text = "Play"
	playButton.TextColor3 = COLOR.text
	playButton.Font = BOLD_FONT
	playButton.TextSize = MIN_TEXT_SIZE  -- Standard minimum text size
	playButton.AutoButtonColor = false
	playButton.LayoutOrder = 1
	playButton.ZIndex = 4  -- Above action frame
	playButton.Parent = actionFrame
	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
	playCorner.Parent = playButton

	-- Border matching inventory
	local playCardBorder = Instance.new("UIStroke")
	playCardBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
	playCardBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
	playCardBorder.Transparency = 0
	playCardBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	playCardBorder.Parent = playButton

	-- Hover effects for green button
	playButton.MouseEnter:Connect(function()
		playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN_HOVER
	end)
	playButton.MouseLeave:Connect(function()
		playButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN
		playButton.BackgroundTransparency = 0
	end)
	playButton.MouseButton1Click:Connect(function()
		self:SelectWorld(worldId, true)
		local latest = self:FindWorldById(worldId)
		if latest then
			self:JoinWorld(latest)
		end
	end)

	if worldData.ownerId == player.UserId then
		local manageButton = Instance.new("TextButton")
		manageButton.Name = "ManageButton"
		manageButton.Size = UDim2.new(0, 56, 0, 56)  -- Square button matching inventory slot size
		manageButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT  -- Default for neutral action
		manageButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
		manageButton.BorderSizePixel = 0
		manageButton.Text = ""  -- No text, icon only
		manageButton.AutoButtonColor = false
		manageButton.LayoutOrder = 2
		manageButton.ZIndex = 4  -- Above action frame
		manageButton.Parent = actionFrame
		local manageCorner = Instance.new("UICorner")
		manageCorner.CornerRadius = UDim.new(0, WORLDS_LAYOUT.SLOT_CORNER_RADIUS)  -- Matching inventory
		manageCorner.Parent = manageButton

		-- Background image matching inventory
		local manageBgImage = Instance.new("ImageLabel")
		manageBgImage.Name = "BackgroundImage"
		manageBgImage.Size = UDim2.new(1, 0, 1, 0)
		manageBgImage.Position = UDim2.new(0, 0, 0, 0)
		manageBgImage.BackgroundTransparency = 1
		manageBgImage.Image = WORLDS_LAYOUT.BACKGROUND_IMAGE
		manageBgImage.ImageTransparency = WORLDS_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
		manageBgImage.ScaleType = Enum.ScaleType.Fit
		manageBgImage.ZIndex = 1
		manageBgImage.Parent = manageButton

		-- Border matching inventory
		local manageCardBorder = Instance.new("UIStroke")
		manageCardBorder.Color = WORLDS_LAYOUT.SLOT_BORDER_COLOR  -- Slot border for buttons
		manageCardBorder.Thickness = WORLDS_LAYOUT.SLOT_BORDER_THICKNESS  -- Slot border thickness
		manageCardBorder.Transparency = 0
		manageCardBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		manageCardBorder.Parent = manageButton

		-- Settings icon (cog/wrench style)
		local settingsIcon = IconManager:CreateIcon(manageButton, "General", "Settings", {
			size = UDim2.new(0, 32, 0, 32),
			position = UDim2.new(0.5, 0, 0.5, 0),
			anchorPoint = Vector2.new(0.5, 0.5)
		})
		if settingsIcon then
			settingsIcon.ImageColor3 = COLOR.text
			settingsIcon.ZIndex = 2
		end

		-- Hover effects for default button
		manageButton.MouseEnter:Connect(function()
			manageButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT_HOVER
		end)
		manageButton.MouseLeave:Connect(function()
			manageButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT
			manageButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
		end)
		manageButton.MouseButton1Click:Connect(function()
			self:SelectWorld(worldId)
			if self.renameInput then
				self.renameInput:CaptureFocus()
			end
		end)
	end
	self:ApplyWorldCardData(card, worldData)
	return container, card
end

function WorldsPanel:RefreshWorldsList()
	if not self.worldsScrollFrame then
		return
	end

	self:UpdateListHeader()
	self:UpdateOverviewSpinnerVisibility()
	self:UpdateListVisibility()

	if self.createWorldButton then
		self:UpdateCreateWorldButtonState()
	end

	if self.emptyStateLabel then
		self.emptyStateLabel:Destroy()
		self.emptyStateLabel = nil
	end

	if self:IsTabLoading(self.currentTab) and not self:_tabHasItems(self.currentTab) then
		return
	end

	local worldsList = self:GetCurrentWorlds()
	if #worldsList == 0 then
		self:ClearWorldCards()
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyState"
		emptyLabel.Size = UDim2.new(1, 0, 0, 120)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = self.currentTab == "myWorlds" and "No worlds yet. Create one!" or "No friends' worlds available."
		emptyLabel.TextColor3 = COLOR.textMuted
		emptyLabel.Font = REGULAR_FONT
		emptyLabel.TextSize = 20
		emptyLabel.TextWrapped = true
		emptyLabel.LayoutOrder = 1  -- Appears below create button (LayoutOrder = 0)
		emptyLabel.Parent = self.worldsScrollFrame
		self.emptyStateLabel = emptyLabel
		self:UpdateEmptyStateVisibility()
		self.selectedWorldId = nil
		self:UpdateDetailPanel()
		return
	end

	local seenIds = {}
	for i, worldData in ipairs(worldsList) do
		local worldId = worldData.worldId
		seenIds[worldId] = true
		local cardInfo = self.worldCardMap[worldId]
		if cardInfo and cardInfo.frame and cardInfo.frame.Parent then
			self:ApplyWorldCardData(cardInfo.frame, worldData)
			if cardInfo.container then
				cardInfo.container.LayoutOrder = i + 1
			end
		else
			local container, cardFrame = self:CreateWorldCard(worldData)
			if container and cardFrame then
				container.LayoutOrder = i + 1  -- LayoutOrder >= 2 so it appears below button and spacer
				self.worldCardMap[worldId] = {
					frame = cardFrame,
					container = container
				}
			end
		end
	end

	for worldId, info in pairs(self.worldCardMap) do
		if not seenIds[worldId] then
			if info.container then
				info.container:Destroy()
			end
			self.worldCardMap[worldId] = nil
		end
	end

	self:EnsureSelection()
end

function WorldsPanel:UpdateListHeader()
	if not self.listLabel then
		return
	end
	if self.currentTab == "myWorlds" then
		self.listLabel.Text = "MY WORLDS"
	elseif self.currentTab == "hubWorld" then
		self.listLabel.Text = "HUB WORLD"
	else
		self.listLabel.Text = "FRIENDS' WORLDS"
	end
end

function WorldsPanel:EnsureSelection()
	local list = self:GetCurrentWorlds()
	if #list == 0 then
		self.selectedWorldId = nil
		self:UpdateSelectionHighlight()
		self:UpdateDetailPanel()
		return
	end

	local hasWorld = self:IsWorldVisible(self.selectedWorldId)
	if not hasWorld then
		self:SelectWorld(list[1].worldId, true)
	else
		self:UpdateSelectionHighlight()
		self:UpdateDetailPanel()
	end
end

function WorldsPanel:IsWorldVisible(worldId)
	if not worldId then
		return false
	end
	for _, worldData in ipairs(self:GetCurrentWorlds()) do
		if worldData.worldId == worldId then
			return true
		end
	end
	return false
end

function WorldsPanel:SelectWorld(worldId, stayOnOverview)
	if not worldId then
		return
	end
	self.selectedWorldId = worldId
	self:UpdateSelectionHighlight()
	if stayOnOverview then
		self:UpdateDetailPanel()
	else
		self:ShowDetail()
	end
end

function WorldsPanel:UpdateSelectionHighlight()
	-- No visual feedback on world cards - removed click, hover, and active states
end

function WorldsPanel:UpdateDetailPanel()
	if not self.detailCard then
		return
	end
	local selected = self:FindWorldById(self.selectedWorldId)
	if not selected then
		if self.detailPlaceholder then
			self.detailPlaceholder.Visible = true
		end
		self.detailCard.Visible = false
		if self.actionsCard then
			self.actionsCard.Visible = false
		end
		if self.renameSection then
			self.renameSection.Visible = false
			self.renameSection.Size = UDim2.new(1, 0, 0, 0)
		end
		if self.deleteButton then
			self.deleteButton.Visible = false
			self.deleteButton.Size = UDim2.new(1, 0, 0, 0)
		end
		if self.manageHintLabel then
			self.manageHintLabel.Visible = false
		end
		return
	end

	if self.detailPlaceholder then
		self.detailPlaceholder.Visible = false
	end
	self.detailCard.Visible = true
	if self.actionsCard then
		self.actionsCard.Visible = true
	end

	if self.detailNameLabel then
		self.detailNameLabel.Text = selected.name or "Unnamed World"
	end
	if self.detailSlotBadge then
		self.detailSlotBadge.Text = "Slot " .. tostring(selected.slot or 1)
	end
	if self.detailStatusLabel then
		self.detailStatusLabel.Text = self:FormatStatus(selected)
		self.detailStatusLabel.TextColor3 = selected.online and COLOR.statusOnline or COLOR.statusOffline
	end
	if self.detailOwnerValue then
		self.detailOwnerValue.Text = selected.ownerName or ("User " .. tostring(selected.ownerId or ""))
	end
	if self.detailPlayerValue then
		local count = selected.playerCount or 0
		self.detailPlayerValue.Text = selected.online and (tostring(count) .. " online") or "Offline"
	end
	if self.detailCreatedValue then
		self.detailCreatedValue.Text = self:FormatTimestamp(selected.created)
	end
	if self.detailLastPlayedValue then
		self.detailLastPlayedValue.Text = self:FormatTimestamp(selected.lastPlayed)
	end
	if self.renameInput then
		self.renameInput.Text = selected.name or ""
	end
	if self.renameSection then
		local canEdit = selected.ownerId == player.UserId
		self.renameSection.Visible = canEdit
		self.renameSection.Size = UDim2.new(1, 0, 0, canEdit and 44 or 0)
	end
	if self.deleteButton then
		local canEdit = selected.ownerId == player.UserId
		self.deleteButton.Visible = canEdit
		self.deleteButton.Size = UDim2.new(1, 0, 0, canEdit and 44 or 0)
	end
	if self.manageHintLabel then
		local canEdit = selected.ownerId == player.UserId
		self.manageHintLabel.Visible = not canEdit
	end
	self:ResetDeleteButton()
	self:UpdateRenameButtonState()
end

function WorldsPanel:UpdateRenameButtonState()
	if not self.renameButton or not self.renameInput then
		return
	end
	local selected = self:FindWorldById(self.selectedWorldId)
	local canRename = false
	if selected and selected.ownerId == player.UserId then
		local newName = trim(self.renameInput.Text)
		canRename = #newName > 0 and newName ~= (selected.name or "")
	end
	self.renameButton.Active = canRename
	if canRename then
		self.renameButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DEFAULT  -- Default for neutral action
		self.renameButton.BackgroundTransparency = WORLDS_LAYOUT.SLOT_BG_TRANSPARENCY
	else
		self.renameButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DISABLED
		self.renameButton.BackgroundTransparency = WORLDS_LAYOUT.BTN_DISABLED_TRANSPARENCY
	end
	self.renameButton.Text = "Rename"
end

function WorldsPanel:HandleRename()
	if not self.renameInput then
		return
	end
	local selected = self:FindWorldById(self.selectedWorldId)
	if not selected or selected.ownerId ~= player.UserId then
		return
	end
	local newName = trim(self.renameInput.Text)
	if #newName == 0 or newName == (selected.name or "") then
		return
	end
	self.renameButton.Text = "Renaming..."
	self.renameButton.Active = false
	EventManager:SendToServer("UpdateWorldMetadata", {
		worldId = selected.worldId,
		metadata = {name = newName}
	})
end

function WorldsPanel:HandleDeleteClick()
	if not self.deleteButton then
		return
	end
	local selected = self:FindWorldById(self.selectedWorldId)
	if not selected or selected.ownerId ~= player.UserId then
		return
	end

	if self.deleteConfirmWorldId == selected.worldId then
		EventManager:SendToServer("DeleteWorld", {worldId = selected.worldId})
		self.deleteConfirmWorldId = nil
		self:ResetDeleteButton()
		return
	end

	self.deleteConfirmWorldId = selected.worldId
	self.deleteButton.Text = "Confirm Delete"
	self.deleteButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_RED_HOVER  -- Brighter red when confirming
	self.deleteButton.BackgroundTransparency = 0
	self.pendingDeleteToken = self.pendingDeleteToken + 1
	local token = self.pendingDeleteToken
	task.delay(3, function()
		if self.pendingDeleteToken == token then
			self.deleteConfirmWorldId = nil
			self:ResetDeleteButton()
		end
	end)
end

function WorldsPanel:ResetDeleteButton()
	if not self.deleteButton then
		return
	end
	self.deleteConfirmWorldId = nil
	self.deleteButton.Text = "Delete World"
	self.deleteButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_RED  -- Red for danger action
	self.deleteButton.BackgroundTransparency = 0
end

function WorldsPanel:GetCurrentWorlds()
	if self.currentTab == "friendsWorlds" then
		return self.friendsWorlds
	end
	return self.myWorlds
end

function WorldsPanel:FindWorldById(worldId)
	if not worldId then
		return nil
	end
	for _, worldData in ipairs(self.myWorlds) do
		if worldData.worldId == worldId then
			return worldData
		end
	end
	for _, worldData in ipairs(self.friendsWorlds) do
		if worldData.worldId == worldId then
			return worldData
		end
	end
	return nil
end

function WorldsPanel:FormatTimestamp(timestamp)
	if not timestamp or timestamp == 0 then
		return "Never"
	end
	local diff = os.time() - timestamp
	if diff < 60 then
		return "Just now"
	elseif diff < 3600 then
		return string.format("%d min ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%d hr ago", math.floor(diff / 3600))
	else
		return string.format("%d days ago", math.floor(diff / 86400))
	end
end

function WorldsPanel:FormatStatus(worldData)
	if worldData.online then
		return string.format("Online (%d)", worldData.playerCount or 0)
	end
	return "Offline"
end

function WorldsPanel:JoinWorld(worldData)
	if not worldData then
		return
	end
	print("[WorldsPanel] Joining world:", worldData.worldId)

	-- Show loading spinner when joining world
	self.isJoiningWorld = true

	-- Create spinner in the appropriate container
	local parentContainer = nil
	if self.contentMode == "overview" and self.overviewContainer then
		parentContainer = self.overviewContainer
	elseif self.contentMode == "detail" and self.detailScroll then
		parentContainer = self.detailScroll
	end

	if parentContainer then
		-- Clean up any existing join spinner
		if self.joinSpinner then
			self:DestroySpinner(self.joinSpinner)
			self.joinSpinner = nil
		end

		-- Create and show spinner
		self.joinSpinner = self:CreateLoadingSpinner(parentContainer)
		if self.joinSpinner then
			self.joinSpinner.Visible = true
		end
	end

	EventManager:SendToServer("RequestJoinWorld", {
		worldId = worldData.worldId,
		ownerUserId = worldData.ownerId,
		slotId = worldData.slot,
		visitingAsOwner = worldData.ownerId == player.UserId
	})
end

function WorldsPanel:TeleportToHub()
	if self.isTeleportingToHub then
		return
	end

	print("[WorldsPanel] Teleporting to hub world")

	self.isTeleportingToHub = true
	self:UpdateHubTeleportButtonState()

	-- Show loading spinner when teleporting to hub
	if (not self.hubSpinner or not self.hubSpinner.Parent) and self.hubContainer then
		self.hubSpinner = self:CreateLoadingSpinner(self.hubContainer)
	end
	if self.hubSpinner then
		self.hubSpinner.Visible = true
	end

	-- Send teleport request to server
	EventManager:SendToServer("RequestTeleportToHub", {})
end

function WorldsPanel:UpdateCreateWorldButtonState()
	if not self.createWorldButton or not self.createWorldLabel then
		return
	end

	local spinnerActive = self:ShouldShowOverviewSpinner()
	if spinnerActive then
		if self.createWorldRow then
			self.createWorldRow.Visible = false
		end
		if self.createWorldSpacer then
			self.createWorldSpacer.Visible = false
		end
		self.createWorldButton.Visible = false
		if self.createWorldReasonLabel then
			self.createWorldReasonLabel.Visible = false
			self.createWorldReasonLabel.Text = ""
		end
		return
	end

	local reasonText = nil
	local disableButton = false
	local onMyWorldsTab = self.currentTab == "myWorlds"
	local myWorldsLoading = self:IsTabLoading("myWorlds")

	if not onMyWorldsTab then
		if self.createWorldRow then
			self.createWorldRow.Visible = false
		end
		if self.createWorldSpacer then
			self.createWorldSpacer.Visible = false
		end
		self.createWorldButton.Visible = false
		if self.createWorldReasonLabel then
			self.createWorldReasonLabel.Visible = false
			self.createWorldReasonLabel.Text = ""
		end
		return
	end

	if self.createWorldRow then
		self.createWorldRow.Visible = true
	end
	if self.createWorldSpacer then
		self.createWorldSpacer.Visible = true
	end
	self.createWorldButton.Visible = true

	if myWorldsLoading then
		disableButton = true
		reasonText = "Loading your worlds..."
	else
		local slotsLeft = math.max(self.maxWorlds - #self.myWorlds, 0)
		if slotsLeft <= 0 then
			disableButton = true
			reasonText = "World limit reached."
		else
			disableButton = false
			self.createWorldLabel.Text = string.format("Create New World (%d slot%s left)", slotsLeft, slotsLeft == 1 and "" or "s")
		end
	end

	if disableButton then
		self.createWorldButton.Active = false
		self.createWorldButton.AutoButtonColor = false
		self.createWorldButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN
		self.createWorldButton.BackgroundTransparency = 0.5
		self.createWorldLabel.Text = "Create New World"
		self.createWorldLabel.TextColor3 = COLOR.textMuted
		if self.createWorldPlusLabel then
			self.createWorldPlusLabel.TextColor3 = COLOR.textMuted
		end
	else
		self.createWorldButton.Active = true
		self.createWorldButton.AutoButtonColor = false
		self.createWorldButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_GREEN
		self.createWorldButton.BackgroundTransparency = 0
		self.createWorldLabel.TextColor3 = COLOR.text
		if self.createWorldPlusLabel then
			self.createWorldPlusLabel.TextColor3 = COLOR.text
		end
	end

	if self.createWorldReasonLabel then
		if reasonText and reasonText ~= "" then
			self.createWorldReasonLabel.Visible = true
			self.createWorldReasonLabel.Text = reasonText
			self.createWorldReasonLabel.TextColor3 = COLOR.textMuted
		else
			self.createWorldReasonLabel.Visible = false
			self.createWorldReasonLabel.Text = ""
		end
	end
end

function WorldsPanel:UpdateHubTeleportButtonState()
	if not self.teleportToHubButton then
		return
	end

	local busy = self.isTeleportingToHub == true
	self.teleportToHubButton.Active = not busy

	if busy then
		self.teleportToHubButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_DISABLED
		self.teleportToHubButton.BackgroundTransparency = WORLDS_LAYOUT.BTN_DISABLED_TRANSPARENCY
		self.teleportToHubButton.Text = "Teleporting..."
	else
		self.teleportToHubButton.BackgroundColor3 = WORLDS_LAYOUT.BTN_BLUE
		self.teleportToHubButton.BackgroundTransparency = 0
		self.teleportToHubButton.Text = "Teleport to Hub"
	end
end

function WorldsPanel:UpdateTabLabels()
end

function WorldsPanel:RefreshAll()
	self:UpdateTabLabels()
	self:UpdateCreateWorldButtonState()
	self:UpdateRefreshButtonState()
	self:UpdateListHeader()
	self:RefreshWorldsList()
end

function WorldsPanel:Initialize()
	FontBinder.preload(CUSTOM_FONT_NAME)

	self:CreateGui()
	self:BindInput()

	UIVisibilityManager:RegisterComponent("worldsPanel", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 120
	})

	EventManager:RegisterEvent("WorldsListUpdated", function(data)
		self.maxWorlds = data.maxWorlds or self.maxWorlds

		if data.myWorlds then
			self:_updateDataset("myWorlds", {
				items = data.myWorlds,
				status = "ready"
			})
		end

		if data.friendsWorlds then
			self:_updateDataset("friendsWorlds", {
				items = data.friendsWorlds,
				status = data.friendsRefreshing and "loading" or "ready",
				lastUpdated = data.friendsLastUpdated
			})
		elseif data.friendsRefreshing ~= nil then
			self:_updateDataset("friendsWorlds", {
				status = data.friendsRefreshing and "loading" or "ready",
				lastUpdated = data.friendsLastUpdated
			})
		end

		if self.createWorldButton then
			if self.currentTab == "friendsWorlds" then
				self.createWorldButton.Visible = false
			else
				self:UpdateCreateWorldButtonState()
			end
		end

		self:UpdateRefreshButtonState()
		self:UpdateListHeader()
		self:UpdateOverviewSpinnerVisibility()

		self:RefreshAll()
		print(string.format("[WorldsPanel] Worlds list updated (%d my / %d friends)", #self.myWorlds, #self.friendsWorlds))
	end)

	EventManager:RegisterEvent("WorldDeleted", function(data)
		if data.success then
			self:_setDatasetStatus("myWorlds", "loading")
			self:RequestWorldsListUpdate({
				force = true,
				setLoading = false,
				reason = "worldDeleted",
				targetTab = "myWorlds"
			})
		end
	end)

	EventManager:RegisterEvent("WorldMetadataUpdated", function()
		self:_setDatasetStatus("myWorlds", "loading")
		self:RequestWorldsListUpdate({
			force = true,
			setLoading = false,
			reason = "worldMetadataUpdated",
			targetTab = "myWorlds"
		})
	end)

	EventManager:RegisterEvent("WorldJoinError", function(data)
		-- Stop spinner when teleport fails
		self.isJoiningWorld = false
		if self.joinSpinner then
			self:DestroySpinner(self.joinSpinner)
			self.joinSpinner = nil
		end
		if self.hubSpinner then
			self.hubSpinner.Visible = false
		end
		print("[WorldsPanel] World join error:", data.message or "Unknown error")
	end)

	EventManager:RegisterEvent("HubTeleportError", function(data)
		-- Stop spinner when hub teleport fails
		self.isTeleportingToHub = false
		self:UpdateHubTeleportButtonState()
		if self.hubSpinner then
			self.hubSpinner.Visible = false
		end
		print("[WorldsPanel] Hub teleport error:", data.message or "Unknown error")
	end)

	print("WorldsPanel: Initialized (responsive voxel style)")
end

function WorldsPanel:Cleanup()
	self:StopFriendsAutoRefresh()
	self:DisableMouseControl()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return WorldsPanel
