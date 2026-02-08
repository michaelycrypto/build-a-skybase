--[[
	ItemNotificationManager.lua - Item Acquisition Notification System
	Shows visual feedback when players acquire items through any means
	
	Features:
	- Left-side notification stack with item icons
	- Same-item coalescing (mining 10 stone → single notification)
	- 3D viewports for blocks, 2D images for items (via BlockViewportCreator)
	- Responsive scaling via UIScaler
	- Deduplication to prevent double-notifications
]]

local ItemNotificationManager = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local Config = require(ReplicatedStorage.Shared.Config)

-- Typography
local UI_SETTINGS = Config.UI_SETTINGS or {}
local Typography = UI_SETTINGS.typography or {}
local Fonts = Typography.fonts or {}
local BOLD_FONT = Fonts.bold or Enum.Font.GothamBold
local REGULAR_FONT = Fonts.regular or Enum.Font.Gotham

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Notification System Configuration
local NOTIFICATION_CONFIG = {
	maxVisible = 5,           -- Maximum notifications visible at once
	defaultDuration = 3,      -- Default duration in seconds
	spacing = 6,              -- Spacing between notifications
	queueLimit = 15,          -- Maximum queued notifications
	displayOrder = 4500,      -- ScreenGui display order (below ToastManager at 5000)
	
	-- Positioning
	container = {
		size = UDim2.fromOffset(280, 400),
		position = UDim2.new(0, 20, 0.5, 0),   -- Left side, vertically centered
		anchorPoint = Vector2.new(0, 0.5)
	},
	
	-- Notification dimensions (compact, inspired by RightSideInfoPanel)
	notification = {
		width = 240,
		height = 44,
		cornerRadius = 4,
		paddingH = 12,
		paddingV = 6
	},
	
	-- Colors (matching RightSideInfoPanel aesthetic)
	colors = {
		background = Color3.fromRGB(28, 32, 42),      -- Match panel row color
		edgeColor = Color3.fromRGB(22, 28, 48),       -- Match panel edge color
		nameText = Color3.fromRGB(255, 255, 255),
		countText = Color3.fromRGB(80, 200, 120),     -- Match panel done color (green)
		textStroke = Color3.fromRGB(0, 0, 0),
		textStrokeTransparency = 0.2
	},
	
	-- Typography (matching RightSideInfoPanel)
	text = {
		nameSize = 20,
		countSize = 20,
		strokeThickness = 1.2
	},
	
	-- Icon (compact)
	icon = {
		size = 28,
		padding = 8
	},
	
	-- Animation timings
	animations = {
		slideInDuration = 0.25,
		slideOutDuration = 0.3,
		popDuration = 0.2
	},
	
	-- Z-index layering
	zIndex = {
		screenGui = 4500,
		container = 4501,
		notification = 4502,
		icon = 4503,
		text = 4504
	}
}

-- Deduplication window for ItemPickedUp events
local DEDUP_WINDOW = 0.2  -- 200ms

-- State
local screenGui = nil
local container = nil
local activeNotifications = {}  -- {[itemId] -> notificationData}
local notificationQueue = {}
local nextNotificationId = 1
local isInitialized = false
local enabled = true

-- Deduplication table for preventing double-notifications
local recentPickups = {}  -- {[itemId] -> timestamp}

--[[
	Initialize the ItemNotificationManager
]]
function ItemNotificationManager:Initialize()
	if isInitialized then return end
	
	self:CreateNotificationContainer()
	self:SetupEventListeners()
	
	isInitialized = true
	print("[ItemNotificationManager] Initialized")
end

--[[
	Create the main notification container
]]
function ItemNotificationManager:CreateNotificationContainer()
	-- Create main ScreenGui
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ItemNotifications"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.DisplayOrder = NOTIFICATION_CONFIG.displayOrder
	screenGui.Parent = playerGui
	
	-- Add UIScale for responsive scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ItemNotificationUIScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = screenGui
	CollectionService:AddTag(uiScale, "scale_component")
	
	-- Create container frame
	container = Instance.new("Frame")
	container.Name = "NotificationContainer"
	container.Size = NOTIFICATION_CONFIG.container.size
	container.Position = NOTIFICATION_CONFIG.container.position
	container.AnchorPoint = NOTIFICATION_CONFIG.container.anchorPoint
	container.BackgroundTransparency = 1
	container.ZIndex = NOTIFICATION_CONFIG.zIndex.container
	container.Parent = screenGui
	
	-- Layout for notifications
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, NOTIFICATION_CONFIG.spacing)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = container
end

--[[
	Setup event listeners
]]
function ItemNotificationManager:SetupEventListeners()
	-- Process notification queue
	RunService.Heartbeat:Connect(function()
		self:ProcessQueue()
	end)
	
	-- Clean up old dedup entries periodically
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			for itemId, timestamp in pairs(recentPickups) do
				if now - timestamp > DEDUP_WINDOW * 2 then
					recentPickups[itemId] = nil
				end
			end
		end
	end)
end

--[[
	Main API: Show an item acquisition notification
	@param itemId: number - Item ID
	@param count: number - Quantity acquired
	@param fromPickup: boolean (optional) - True if from ItemPickedUp event (records in dedup)
]]
function ItemNotificationManager:ShowItemAcquired(itemId, count, fromPickup)
	if not enabled or not isInitialized then return end
	
	-- Record in dedup table if from pickup event
	if fromPickup then
		recentPickups[itemId] = os.clock()
	end
	
	-- Check if we already have an active notification for this item
	local existing = activeNotifications[itemId]
	if existing and existing.ui and existing.ui.Parent then
		-- Coalesce: update count and reset timer
		existing.count = existing.count + count
		existing.spawnTime = os.clock()
		self:UpdateNotificationCount(existing)
		self:PlayBumpAnimation(existing)
		
		-- Cancel old dismiss task and schedule new one
		if existing.dismissTask then
			task.cancel(existing.dismissTask)
		end
		existing.dismissTask = task.spawn(function()
			task.wait(NOTIFICATION_CONFIG.defaultDuration)
			self:DismissNotification(itemId)
		end)
		
		return
	end
	
	-- Create new notification data
	local notification = {
		id = "notification_" .. nextNotificationId,
		itemId = itemId,
		count = count,
		spawnTime = os.clock(),
		ui = nil
	}
	nextNotificationId = nextNotificationId + 1
	
	-- Add to queue or show immediately
	if self:GetActiveCount() >= NOTIFICATION_CONFIG.maxVisible then
		self:QueueNotification(notification)
	else
		self:ShowNotification(notification)
	end
end

--[[
	Check dedup table and notify if not recent pickup
	@param itemId: number - Item ID
	@param count: number - Quantity acquired
]]
function ItemNotificationManager:CheckAndNotify(itemId, count)
	local now = os.clock()
	local lastPickup = recentPickups[itemId]
	
	if lastPickup and (now - lastPickup) < DEDUP_WINDOW then
		-- Skip, already notified via ItemPickedUp
		recentPickups[itemId] = nil
		return
	end
	
	-- Not a recent pickup, show notification
	self:ShowItemAcquired(itemId, count, false)
end

--[[
	Show a notification immediately
]]
function ItemNotificationManager:ShowNotification(notification)
	if not container then
		warn("[ItemNotificationManager] Container not initialized")
		return
	end
	
	-- Create UI element
	notification.ui = self:CreateNotificationUI(notification)
	if not notification.ui then
		warn("[ItemNotificationManager] Failed to create notification UI")
		return
	end
	
	-- Add to active notifications
	activeNotifications[notification.itemId] = notification
	
	-- Update layout order
	self:UpdateLayoutOrder()
	
	-- Animate in
	self:AnimateNotificationIn(notification)
	
	-- Schedule auto-dismiss
	notification.dismissTask = task.spawn(function()
		task.wait(NOTIFICATION_CONFIG.defaultDuration)
		self:DismissNotification(notification.itemId)
	end)
end

--[[
	Create the UI element for a notification
]]
function ItemNotificationManager:CreateNotificationUI(notification)
	if not container then return nil end
	
	-- Get item info
	local itemName = ItemRegistry.GetItemName(notification.itemId)
	if itemName == "Unknown" then
		itemName = "Item " .. tostring(notification.itemId)
	end
	
	-- Main notification frame
	local notificationFrame = Instance.new("Frame")
	notificationFrame.Name = "Notification_" .. notification.id
	notificationFrame.Size = UDim2.fromOffset(
		NOTIFICATION_CONFIG.notification.width,
		NOTIFICATION_CONFIG.notification.height
	)
	notificationFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	notificationFrame.Position = UDim2.fromScale(0.5, 0.5)
	notificationFrame.BackgroundColor3 = NOTIFICATION_CONFIG.colors.background
	notificationFrame.BackgroundTransparency = 0
	notificationFrame.BorderSizePixel = 0
	notificationFrame.ZIndex = NOTIFICATION_CONFIG.zIndex.notification
	notificationFrame.Parent = container
	
	-- Rounded corners (small radius like RightSideInfoPanel)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, NOTIFICATION_CONFIG.notification.cornerRadius)
	corner.Parent = notificationFrame
	
	-- UIScale for pop animation (scales from center)
	local popScale = Instance.new("UIScale")
	popScale.Name = "PopScale"
	popScale.Parent = notificationFrame
	
	-- Radial gradient (more transparent)
	local gradient = Instance.new("UIGradient")
	local edgeColor = Color3.fromRGB(22, 28, 48)
	local mainColor = Color3.fromRGB(28, 32, 42)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edgeColor),
		ColorSequenceKeypoint.new(0.3, mainColor),
		ColorSequenceKeypoint.new(0.7, mainColor),
		ColorSequenceKeypoint.new(1, edgeColor),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(0.15, 0.4),
		NumberSequenceKeypoint.new(0.35, 0.25),
		NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.65, 0.25),
		NumberSequenceKeypoint.new(0.85, 0.4),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	gradient.Rotation = 0
	gradient.Parent = notificationFrame
	
	-- Icon container (left side, compact) - separate from gradient transparency
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromOffset(
		NOTIFICATION_CONFIG.icon.size,
		NOTIFICATION_CONFIG.icon.size
	)
	iconContainer.Position = UDim2.fromOffset(
		NOTIFICATION_CONFIG.notification.paddingH,
		(NOTIFICATION_CONFIG.notification.height - NOTIFICATION_CONFIG.icon.size) / 2
	)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = NOTIFICATION_CONFIG.zIndex.icon + 10  -- Higher z-index to be above gradient
	iconContainer.ClipsDescendants = false
	iconContainer.Parent = notificationFrame
	
	-- Render item icon using BlockViewportCreator with explicit size
	local success, iconElement = pcall(function()
		return BlockViewportCreator.CreateBlockViewport(
			iconContainer, 
			notification.itemId,
			UDim2.fromScale(1, 1),
			UDim2.fromScale(0, 0),
			Vector2.new(0, 0)
		)
	end)
	
	-- Ensure icon elements are fully opaque and have high z-index
	if success and iconElement then
		iconElement.ZIndex = NOTIFICATION_CONFIG.zIndex.icon + 10
		
		if iconElement:IsA("ViewportFrame") then
			iconElement.BackgroundTransparency = 1
			iconElement.ImageTransparency = 0
			-- Make all children opaque and set their z-index
			for _, child in ipairs(iconElement:GetDescendants()) do
				if child:IsA("BasePart") then
					child.Transparency = 0
				elseif child:IsA("GuiObject") then
					child.ZIndex = NOTIFICATION_CONFIG.zIndex.icon + 10
				end
			end
		elseif iconElement:IsA("ImageLabel") then
			iconElement.BackgroundTransparency = 1
			iconElement.ImageTransparency = 0
		end
	end
	
	-- Text starts after icon
	local textStartX = NOTIFICATION_CONFIG.notification.paddingH + NOTIFICATION_CONFIG.icon.size + 8
	local textWidth = NOTIFICATION_CONFIG.notification.width - textStartX - NOTIFICATION_CONFIG.notification.paddingH
	
	-- Item name (left-aligned, single line, compact)
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.fromOffset(textWidth - 45, NOTIFICATION_CONFIG.notification.height)
	nameLabel.Position = UDim2.fromOffset(textStartX, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemName
	nameLabel.TextColor3 = NOTIFICATION_CONFIG.colors.nameText
	nameLabel.TextSize = NOTIFICATION_CONFIG.text.nameSize
	nameLabel.Font = BOLD_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = NOTIFICATION_CONFIG.zIndex.text
	nameLabel.Parent = notificationFrame
	
	-- Text stroke for readability
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Color = NOTIFICATION_CONFIG.colors.textStroke
	nameStroke.Thickness = NOTIFICATION_CONFIG.text.strokeThickness
	nameStroke.Transparency = NOTIFICATION_CONFIG.colors.textStrokeTransparency
	nameStroke.Parent = nameLabel
	
	-- Count label (right-aligned, same line, compact)
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.fromOffset(45, NOTIFICATION_CONFIG.notification.height)
	countLabel.Position = UDim2.fromOffset(
		NOTIFICATION_CONFIG.notification.width - 45 - NOTIFICATION_CONFIG.notification.paddingH,
		0
	)
	countLabel.BackgroundTransparency = 1
	countLabel.Text = "×" .. tostring(notification.count)
	countLabel.TextColor3 = NOTIFICATION_CONFIG.colors.countText
	countLabel.TextSize = NOTIFICATION_CONFIG.text.countSize
	countLabel.Font = BOLD_FONT
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.TextYAlignment = Enum.TextYAlignment.Center
	countLabel.ZIndex = NOTIFICATION_CONFIG.zIndex.text
	countLabel.Parent = notificationFrame
	
	-- Text stroke for count
	local countStroke = Instance.new("UIStroke")
	countStroke.Color = NOTIFICATION_CONFIG.colors.textStroke
	countStroke.Thickness = NOTIFICATION_CONFIG.text.strokeThickness
	countStroke.Transparency = NOTIFICATION_CONFIG.colors.textStrokeTransparency
	countStroke.Parent = countLabel
	
	return notificationFrame
end

--[[
	Update notification count display
]]
function ItemNotificationManager:UpdateNotificationCount(notification)
	if not notification.ui then return end
	
	local countLabel = notification.ui:FindFirstChild("Count")
	if countLabel then
		countLabel.Text = "×" .. tostring(notification.count)
	end
end

--[[
	Play pop animation on the entire frame when count updates
]]
function ItemNotificationManager:PlayBumpAnimation(notification)
	if not notification.ui then return end
	
	local popScale = notification.ui:FindFirstChild("PopScale")
	if not popScale then return end
	
	-- Pop/scale effect using UIScale (scales from center with anchor point)
	local popTween = TweenService:Create(
		popScale,
		TweenInfo.new(
			NOTIFICATION_CONFIG.animations.popDuration / 2,
			Enum.EasingStyle.Back,
			Enum.EasingDirection.Out
		),
		{Scale = 1.08}
	)
	
	popTween.Completed:Connect(function()
		local returnTween = TweenService:Create(
			popScale,
			TweenInfo.new(
				NOTIFICATION_CONFIG.animations.popDuration / 2,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			),
			{Scale = 1}
		)
		returnTween:Play()
	end)
	
	popTween:Play()
end

--[[
	Animate notification in with slide from left
]]
function ItemNotificationManager:AnimateNotificationIn(notification)
	if not notification.ui then return end
	
	-- Initial state - off-screen to the left (anchor point is 0.5, 0.5)
	notification.ui.Position = UDim2.new(0.5, -280, 0.5, 0)
	
	-- Slide in from left to center
	local slideTween = TweenService:Create(
		notification.ui,
		TweenInfo.new(
			NOTIFICATION_CONFIG.animations.slideInDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out
		),
		{Position = UDim2.fromScale(0.5, 0.5)}
	)
	slideTween:Play()
end

--[[
	Dismiss a notification by itemId with slide-out to the right
]]
function ItemNotificationManager:DismissNotification(itemId)
	local notification = activeNotifications[itemId]
	if not notification or not notification.ui then return end
	
	local notificationFrame = notification.ui
	
	-- Prevent multiple dismissals
	if notificationFrame:GetAttribute("Dismissing") then return end
	notificationFrame:SetAttribute("Dismissing", true)
	
	-- Slide out to the right (anchor point is 0.5, 0.5)
	local slideOutTween = TweenService:Create(
		notificationFrame,
		TweenInfo.new(
			NOTIFICATION_CONFIG.animations.slideOutDuration,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{Position = UDim2.new(0.5, 320, 0.5, 0)}
	)
	
	slideOutTween:Play()
	
	-- Remove after animation completes
	slideOutTween.Completed:Connect(function()
		self:RemoveNotification(itemId)
	end)
end

--[[
	Remove notification from active list
]]
function ItemNotificationManager:RemoveNotification(itemId)
	local notification = activeNotifications[itemId]
	if not notification then return end
	
	-- Cancel any pending dismiss timer
	if notification.dismissTask then
		task.cancel(notification.dismissTask)
		notification.dismissTask = nil
	end
	
	-- Destroy UI element
	if notification.ui then
		notification.ui:Destroy()
		notification.ui = nil
	end
	
	-- Remove from active list
	activeNotifications[itemId] = nil
	
	-- Process queue
	self:ProcessQueue()
end

--[[
	Queue management
]]
function ItemNotificationManager:QueueNotification(notification)
	if #notificationQueue >= NOTIFICATION_CONFIG.queueLimit then
		-- Remove oldest from queue
		table.remove(notificationQueue, 1)
	end
	
	table.insert(notificationQueue, notification)
end

function ItemNotificationManager:ProcessQueue()
	while self:GetActiveCount() < NOTIFICATION_CONFIG.maxVisible and #notificationQueue > 0 do
		local notification = table.remove(notificationQueue, 1)
		self:ShowNotification(notification)
	end
end

--[[
	Get count of active notifications
]]
function ItemNotificationManager:GetActiveCount()
	local count = 0
	for _ in pairs(activeNotifications) do
		count = count + 1
	end
	return count
end

--[[
	Update layout order of notifications
]]
function ItemNotificationManager:UpdateLayoutOrder()
	local order = 0
	for _, notification in pairs(activeNotifications) do
		if notification.ui then
			notification.ui.LayoutOrder = order
			order = order + 1
		end
	end
end

--[[
	Configuration methods
]]
function ItemNotificationManager:SetEnabled(enabledState)
	enabled = enabledState
end

function ItemNotificationManager:IsEnabled()
	return enabled
end

--[[
	Clear all notifications
]]
function ItemNotificationManager:ClearAll()
	-- Cancel all pending dismiss timers
	for _, notification in pairs(activeNotifications) do
		if notification.dismissTask then
			task.cancel(notification.dismissTask)
		end
		if notification.ui then
			notification.ui:Destroy()
		end
	end
	
	-- Clear all state
	activeNotifications = {}
	notificationQueue = {}
	recentPickups = {}
end

--[[
	Cleanup
]]
function ItemNotificationManager:Destroy()
	self:ClearAll()
	if screenGui then
		screenGui:Destroy()
	end
	isInitialized = false
	print("[ItemNotificationManager] Destroyed")
end

return ItemNotificationManager
