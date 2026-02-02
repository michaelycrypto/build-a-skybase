--[[
	ToastManager.lua - Advanced Toast Notification System
	Handles all toast notifications with queuing, priorities, and advanced features

	UNIFORM DESIGN PRINCIPLES:
	- All toast categories use identical size, shape, and animations
	- Only colors, icons, and text content vary between toast types
	- Standardized animation timing, easing, and behavior across all toasts
	- Consistent typography, spacing, and visual styling
--]]

local ToastManager = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local _GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local _SoundService = game:GetService("SoundService")
local CollectionService = game:GetService("CollectionService")

-- Import dependencies
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local IconManager = require(script.Parent.IconManager)
local UI_SETTINGS = Config.UI_SETTINGS
local Typography = UI_SETTINGS and UI_SETTINGS.typography or {}
local Fonts = Typography.fonts or {}
local TextSizes = Typography.sizes or {}
local UISizes = TextSizes.ui or {}
local BodySizes = TextSizes.body or {}
local BOLD_FONT = Fonts.bold or Fonts.regular
local _TOAST_TEXT_SIZE = UISizes.toast or 14
local _BODY_BASE_TEXT_SIZE = BodySizes.base or 14

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Toast System Configuration
local TOAST_CONFIG = {
	maxVisible = 5,           -- Maximum toasts visible at once
	defaultDuration = 3,      -- Default duration in seconds
	spacing = 6,              -- Spacing between toasts
	animationSpeed = 0.25,    -- Animation duration
	queueLimit = 20,          -- Maximum queued toasts
	displayOrder = 5000,      -- ScreenGui display order to stay on top of other GUIs

	-- Positioning
	container = {
		size = UDim2.fromOffset(380, 400),
		position = UDim2.new(1, -400, 1, -420)
	},

	-- Standardized toast dimensions
	toast = {
		width = 360,        -- Wider for more text
		height = 38,        -- Compact height
		cornerRadius = 6,   -- Consistent rounded corners
		padding = 8         -- Reduced padding for more text space
	},

	-- Standardized animation parameters (uniform across all toast types)
	animations = {
		-- Entry animation
		slideIn = {
			duration = 0.4,
			easing = Enum.EasingStyle.Back,
			direction = Enum.EasingDirection.Out,
			startPosition = UDim2.new(1, 30, 0, 0),
			startTransparency = 1
		},
		-- Exit animation
		slideOut = {
			duration = 0.4,
			easing = Enum.EasingStyle.Back,
			direction = Enum.EasingDirection.In,
			endPosition = UDim2.new(1, 80, 0, -10),
			rotation = 5,
			scaleMultiplier = 0.8,
			endTransparency = 1
		},
		-- Hover effects
		hover = {
			duration = 0.2,
			easing = Enum.EasingStyle.Quad,
			direction = Enum.EasingDirection.Out,
			liftOffset = UDim2.fromOffset(-3, 0),
			sizeIncrease = UDim2.fromOffset(4, 2)
		},
		-- Close button
		closeButton = {
			duration = 0.15,
			easing = Enum.EasingStyle.Quad,
			direction = Enum.EasingDirection.Out
		}
	},

	-- Standardized styling parameters (uniform across all toast types)
	styling = {
		backgroundTransparency = 0,  -- Consistent transparency
		textColor = Color3.fromRGB(255, 255, 255),  -- Consistent text color
		iconColor = Color3.fromRGB(255, 255, 255),  -- Consistent icon color
		shadowColor = Color3.fromRGB(0, 0, 0),
		shadowThickness = 1,
		shadowTransparency = 0.8,
		-- Typography - compact for more text visibility
		iconSize = 18,            -- Smaller icon
		iconFont = BOLD_FONT,
		textSize = 14,            -- Smaller text for more content
		textFont = BOLD_FONT,     -- Bold for better visibility
		closeButtonSize = 14,     -- Smaller close button
		closeButtonFont = BOLD_FONT
	},

	-- Centralized z-index layering so toast UI always renders above other screens
	zIndex = {
		screenGui = 20000,
		container = 20001,
		toast = 20002,
		content = 20003,
		icon = 20004,
		textShadow = 20005,
		text = 20006,
		closeButton = 20007,
		hover = 20008
	}
}

-- No priority system - simple first-in-first-out queue

-- Toast Categories for better organization
local CATEGORIES = {
	GAME = "game",           -- Game events (coins, level up)
	SOCIAL = "social",       -- Player interactions
	SYSTEM = "system",       -- System messages
	ERROR = "error",         -- Error messages
	ACHIEVEMENT = "achievement", -- Achievements
	SHOP = "shop"            -- Shop/purchase related
}

-- State
local toastContainer = nil
local activeToasts = {}
local toastQueue = {}
local nextToastId = 1
local isInitialized = false

-- Settings (can be configured)
local settings = {
	enabled = true,
	soundEnabled = true,
	animationsEnabled = true,
	maxVisible = TOAST_CONFIG.maxVisible,
	autoCollapseAfter = 10 -- Auto-collapse old toasts after this many
}

--[[
	Helper function to get icon configuration for a toast type
	@param toastType: string - The toast type key
	@return: table - Icon configuration {iconName, iconCategory}
--]]
local function getToastIconConfig(toastType)
	-- Safety check for Config.TOAST_ICONS existence
	if not Config.TOAST_ICONS then
		warn("ToastManager: Config.TOAST_ICONS not found, using fallback")
		return {
			iconName = "Info",
			iconCategory = "General",
			context = "Toast_Fallback"
		}
	end

	-- Get icon config with fallback chain
	local iconConfig = nil
	if Config.TOAST_ICONS.types and Config.TOAST_ICONS.types[toastType] then
		iconConfig = Config.TOAST_ICONS.types[toastType]
	elseif Config.TOAST_ICONS.fallbacks and Config.TOAST_ICONS.fallbacks.default then
		iconConfig = Config.TOAST_ICONS.fallbacks.default
	end

	-- Final fallback if config is completely missing
	if not iconConfig then
		warn("ToastManager: No icon config found for type '" .. toastType .. "', using hardcoded fallback")
		iconConfig = {
			iconName = "Info",
			iconCategory = "General",
			context = "Toast_Fallback"
		}
	end

	return iconConfig
end

--[[
	Initialize the ToastManager
--]]
function ToastManager:Initialize()
	if isInitialized then return end

	self:CreateToastContainer()
	self:SetupEventListeners()

	isInitialized = true
end

--[[
	Create the main toast container
--]]
function ToastManager:CreateToastContainer()
	-- Create main toast GUI
	local toastGui = Instance.new("ScreenGui")
	toastGui.Name = "ToastNotifications"
	toastGui.ResetOnSpawn = false
	toastGui.ZIndexBehavior = Enum.ZIndexBehavior.Global -- Allow explicit z-index control
	toastGui.DisplayOrder = TOAST_CONFIG.displayOrder -- High priority display
	toastGui.Parent = playerGui

	-- Add UIScale for responsive scaling (managed by UIScaler)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ToastUIScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = toastGui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create container frame
	toastContainer = Instance.new("Frame")
	toastContainer.Name = "ToastContainer"
	toastContainer.Size = TOAST_CONFIG.container.size
	toastContainer.Position = TOAST_CONFIG.container.position
	toastContainer.BackgroundTransparency = 1
	toastContainer.ZIndex = TOAST_CONFIG.zIndex.container
	toastContainer.Parent = toastGui

	-- Layout for toasts
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, TOAST_CONFIG.spacing)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Parent = toastContainer
end

--[[
	Setup event listeners and responsive design
--]]
function ToastManager:SetupEventListeners()
	-- Handle viewport changes
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:UpdateResponsiveLayout()
	end)

	-- Process toast queue
	RunService.Heartbeat:Connect(function()
		self:ProcessQueue()
	end)
end

--[[
	Main API: Show a toast notification
	@param options: table - Toast configuration
		- message: string - The toast message
		- type: string - Toast type ("success", "info", "warning", "error", "default")
		- duration: number - How long to show (optional)
		- category: string - Toast category (optional)
		- persistent: boolean - If true, won't auto-dismiss (optional)
		- sound: string - Custom sound to play (optional)
		- icon: string - Custom icon (optional)
--]]
function ToastManager:Show(options)
	if not self:IsEnabled() then return nil end

	-- Validate options
	if type(options) == "string" then
		options = { message = options }
	end

	if not options or not options.message then
		warn("ToastManager: Invalid toast options")
		return nil
	end

	-- Create toast data
	local toast = self:CreateToastData(options)

	-- Add to queue or show immediately
	if #activeToasts >= settings.maxVisible then
		self:QueueToast(toast)
	else
		self:ShowToast(toast)
	end

	return toast.id
end

--[[
	Quick API methods for common toast types
--]]
function ToastManager:Success(message, duration)
	local iconConfig = getToastIconConfig("success")
	return self:Show({
		message = message,
		type = "success",
		duration = duration,
		category = CATEGORIES.GAME,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

function ToastManager:Error(message, duration)
	local iconConfig = getToastIconConfig("error")
	return self:Show({
		message = message,
		type = "error",
		duration = duration or 4,
		category = CATEGORIES.ERROR,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

function ToastManager:Info(message, duration)
	local iconConfig = getToastIconConfig("info")
	return self:Show({
		message = message,
		type = "info",
		duration = duration,
		category = CATEGORIES.SYSTEM,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

function ToastManager:Warning(message, duration)
	local iconConfig = getToastIconConfig("warning")
	return self:Show({
		message = message,
		type = "warning",
		duration = duration or 4,
		category = CATEGORIES.SYSTEM,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

--[[
	Show achievement toast with special styling
--]]
function ToastManager:Achievement(title, description, icon)
	local iconConfig = getToastIconConfig("achievement")
	return self:Show({
		message = title .. (description and "\n" .. description or ""),
		type = "achievement",
		duration = 5,
		category = CATEGORIES.ACHIEVEMENT,
		icon = icon or iconConfig.iconName,
		iconCategory = iconConfig.iconCategory,
		sound = "achievement"
	})
end

--[[
	Specialized methods for EventManager integration
--]]
function ToastManager:PlayerJoined(playerName, level)
	local message = playerName .. " joined" .. (level and " (Lv." .. level .. ")" or "")
	local iconConfig = Config.TOAST_ICONS.types.social_join
	return self:Show({
		message = message,
		type = "info",
		duration = 2,
		category = CATEGORIES.SOCIAL,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

function ToastManager:PlayerLeft(playerName)
	local iconConfig = Config.TOAST_ICONS.types.social_leave
	return self:Show({
		message = playerName .. " left the game",
		type = "info",
		duration = 1.5,
		category = CATEGORIES.SOCIAL,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory
	})
end

function ToastManager:PurchaseSuccess(itemName)
	local message = "Purchase successful!" .. (itemName and " (" .. itemName .. ")" or "")
	local iconConfig = getToastIconConfig("shop")
	return self:Show({
		message = message,
		type = "success",
		duration = 2,
		category = CATEGORIES.SHOP,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory,
		sound = "purchase"
	})
end

--[[
	Show coins earned toast
--]]
function ToastManager:CoinsEarned(amount)
	local iconConfig = getToastIconConfig("coins")
	return self:Show({
		message = "+" .. amount .. " coins earned!",
		type = "success",
		duration = 2,
		category = CATEGORIES.GAME,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory,
		sound = "coins"
	})
end

--[[
	Show experience earned toast
--]]
function ToastManager:ExperienceEarned(amount)
	local iconConfig = getToastIconConfig("experience")
	return self:Show({
		message = "+" .. amount .. " XP earned!",
		type = "success",
		duration = 2,
		category = CATEGORIES.GAME,
		icon = iconConfig.iconName,
		iconCategory = iconConfig.iconCategory,
		sound = "notification"
	})
end

function ToastManager:PurchaseError(errorMessage)
	local message = "Purchase failed: " .. (errorMessage or "Unknown error")
	return self:Show({
		message = message,
		type = "error",
		duration = 3,
		category = CATEGORIES.SHOP,
		icon = "Skull"
	})
end

--[[
	Create toast data structure
--]]
function ToastManager:CreateToastData(options)
	local toast = {
		id = "toast_" .. nextToastId,
		message = options.message,
		type = options.type or "default",
		duration = options.duration or TOAST_CONFIG.defaultDuration,
		category = options.category or CATEGORIES.SYSTEM,
		timestamp = tick(),
		persistent = options.persistent or false,
		sound = options.sound,
		icon = options.icon,
		iconCategory = options.iconCategory,
		ui = nil -- Will hold the UI element
	}

	nextToastId = nextToastId + 1
	return toast
end

--[[
	Show a toast immediately
--]]
function ToastManager:ShowToast(toast)
	-- Ensure container exists
	if not toastContainer then
		warn("ToastManager: Container not initialized")
		return
	end

	-- Create UI element
	toast.ui = self:CreateToastUI(toast)
	if not toast.ui then
		warn("ToastManager: Failed to create toast UI")
		return
	end

	-- Add to active toasts
	table.insert(activeToasts, toast)

	-- Update layout order
	self:UpdateLayoutOrder()

	-- Play sound
	if settings.soundEnabled and toast.sound then
		self:PlayToastSound(toast.sound, toast.type)
	end

	-- Schedule auto-dismiss with cleanup tracking
	if not toast.persistent then
		toast.dismissConnection = task.spawn(function()
			wait(toast.duration)
			self:DismissToast(toast.id)
		end)
	end
end

--[[
	Create the UI element for a toast
--]]
function ToastManager:CreateToastUI(toast)
	-- Safety check
	if not toastContainer then
		return nil
	end

	-- Main toast frame
	local toastFrame = Instance.new("Frame")
	toastFrame.Name = "Toast_" .. toast.id
	toastFrame.Size = UDim2.fromOffset(TOAST_CONFIG.toast.width, TOAST_CONFIG.toast.height)
	toastFrame.BorderSizePixel = 0
	toastFrame.ClipsDescendants = true -- Prevent content overflow during animations
	toastFrame.ZIndex = TOAST_CONFIG.zIndex.toast
	toastFrame.Parent = toastContainer

	-- Get styling
	local styleData = self:GetToastStyle(toast.type)
	if not styleData then
		warn("ToastManager: Failed to get style data for type:", toast.type)
		toastFrame:Destroy()
		return nil
	end

	toastFrame.BackgroundColor3 = styleData.background
	toastFrame.BackgroundTransparency = styleData.backgroundTransparency

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, TOAST_CONFIG.toast.cornerRadius)
	corner.Parent = toastFrame

	-- Subtle shadow
	local shadow = Instance.new("UIStroke")
	shadow.Color = styleData.shadowColor
	shadow.Thickness = TOAST_CONFIG.styling.shadowThickness
	shadow.Transparency = TOAST_CONFIG.styling.shadowTransparency
	shadow.Parent = toastFrame

	-- Standardized content container
	local contentFrame = Instance.new("Frame")
	contentFrame.Size = UDim2.new(1, -TOAST_CONFIG.toast.padding * 2, 1, -TOAST_CONFIG.toast.padding * 2)
	contentFrame.Position = UDim2.fromOffset(TOAST_CONFIG.toast.padding, TOAST_CONFIG.toast.padding)
	contentFrame.BackgroundTransparency = 1
	contentFrame.ZIndex = TOAST_CONFIG.zIndex.content
	contentFrame.Parent = toastFrame

	-- Standardized icon using IconManager
	local iconName = toast.icon or styleData.icon
	local iconCategory = toast.iconCategory or "General"

	local iconElement = IconManager:CreateIcon(contentFrame, iconCategory, iconName, {
		size = "toast", -- Use semantic toast size (21px)
		position = UDim2.new(0, TOAST_CONFIG.styling.iconSize / 2, 0.5, 0), -- Properly centered
		anchorPoint = Vector2.new(0.5, 0.5), -- Center anchor point for clean positioning
		imageColor3 = styleData.iconColor,
		zIndex = TOAST_CONFIG.zIndex.icon
	})

	-- Fallback to text if icon creation fails
	if not iconElement then
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.fromOffset(TOAST_CONFIG.styling.iconSize, TOAST_CONFIG.styling.iconSize)
		iconLabel.Position = UDim2.new(0, TOAST_CONFIG.styling.iconSize / 2, 0.5, 0) -- Properly centered
		iconLabel.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor point for clean positioning
		iconLabel.BackgroundTransparency = 1
		iconLabel.Text = iconName
		iconLabel.TextColor3 = styleData.iconColor
		iconLabel.TextSize = TOAST_CONFIG.styling.iconSize
		iconLabel.Font = TOAST_CONFIG.styling.iconFont
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.TextYAlignment = Enum.TextYAlignment.Center
		iconLabel.ZIndex = TOAST_CONFIG.zIndex.icon
		iconLabel.Parent = contentFrame
	end

	-- Text shadow (positioned bottom-right) - aligned with centered icon
	local textLeftMargin = TOAST_CONFIG.styling.iconSize + 6 -- Icon size + small gap
	local shadowLabel = Instance.new("TextLabel")
	shadowLabel.Size = UDim2.new(1, -textLeftMargin - 8, 1, 0) -- Account for icon and right margin
	shadowLabel.Position = UDim2.fromOffset(textLeftMargin + 1, 1) -- Offset 1px right, 1px down for shadow
	shadowLabel.BackgroundTransparency = 1
	shadowLabel.Text = toast.message
	shadowLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
	shadowLabel.TextTransparency = 0.85 -- More subtle
	shadowLabel.TextSize = TOAST_CONFIG.styling.textSize
	shadowLabel.Font = TOAST_CONFIG.styling.textFont
	shadowLabel.TextXAlignment = Enum.TextXAlignment.Left
	shadowLabel.TextYAlignment = Enum.TextYAlignment.Center
	shadowLabel.TextTruncate = Enum.TextTruncate.AtEnd
	shadowLabel.TextWrapped = false
	shadowLabel.ZIndex = TOAST_CONFIG.zIndex.textShadow -- Behind main text
	shadowLabel.Parent = contentFrame

	-- Standardized message - aligned with centered icon
	local messageLabel = Instance.new("TextLabel")
	messageLabel.Size = UDim2.new(1, -textLeftMargin - 8, 1, 0) -- Account for icon and right margin
	messageLabel.Position = UDim2.fromOffset(textLeftMargin, 0)
	messageLabel.BackgroundTransparency = 1
	messageLabel.Text = toast.message
	messageLabel.TextColor3 = styleData.textColor
	messageLabel.TextSize = TOAST_CONFIG.styling.textSize
	messageLabel.Font = TOAST_CONFIG.styling.textFont
	messageLabel.TextXAlignment = Enum.TextXAlignment.Left
	messageLabel.TextYAlignment = Enum.TextYAlignment.Center
	messageLabel.TextTruncate = Enum.TextTruncate.AtEnd
	messageLabel.TextWrapped = false
	messageLabel.ZIndex = TOAST_CONFIG.zIndex.text -- In front of shadow
	messageLabel.Parent = contentFrame

	-- Standardized close button (only for persistent toasts)
	if toast.persistent then
		local closeButton = Instance.new("TextButton")
		closeButton.Name = "closeButton"
		closeButton.Size = UDim2.fromOffset(TOAST_CONFIG.styling.closeButtonSize, TOAST_CONFIG.styling.closeButtonSize)
		closeButton.Position = UDim2.new(1, -TOAST_CONFIG.styling.closeButtonSize / 2, 0.5, 0) -- Properly centered
		closeButton.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor point for clean positioning
		closeButton.BackgroundTransparency = 1
		closeButton.Text = "×"
		closeButton.TextColor3 = styleData.textColor
		closeButton.TextSize = TOAST_CONFIG.styling.closeButtonSize
		closeButton.Font = TOAST_CONFIG.styling.closeButtonFont
		closeButton.TextTransparency = 0.5
		closeButton.TextXAlignment = Enum.TextXAlignment.Center
		closeButton.TextYAlignment = Enum.TextYAlignment.Center
		closeButton.AutoButtonColor = false -- Prevent default button highlighting
		closeButton.ZIndex = TOAST_CONFIG.zIndex.closeButton
		closeButton.Parent = contentFrame

		-- Standardized close button interactions
		closeButton.MouseEnter:Connect(function()
			if closeButton.Parent then -- Safety check
				TweenService:Create(closeButton, TweenInfo.new(TOAST_CONFIG.animations.closeButton.duration, TOAST_CONFIG.animations.closeButton.easing, TOAST_CONFIG.animations.closeButton.direction), {
					TextTransparency = 0.1
				}):Play()
			end
		end)

		closeButton.MouseLeave:Connect(function()
			if closeButton.Parent then -- Safety check
				TweenService:Create(closeButton, TweenInfo.new(TOAST_CONFIG.animations.closeButton.duration, TOAST_CONFIG.animations.closeButton.easing, TOAST_CONFIG.animations.closeButton.direction), {
					TextTransparency = 0.5
				}):Play()
			end
		end)

		closeButton.MouseButton1Click:Connect(function()
			self:DismissToast(toast.id)
		end)
	end

	-- Add interactive hover effects
	self:AddInteractiveEffects(toastFrame)

	-- Animate in
	self:AnimateToastIn(toastFrame, styleData)

	return toastFrame
end

--[[
	Get styling data for toast type
--]]
function ToastManager:GetToastStyle(toastType)
		-- Simplified color palette - 4 main types + achievement
	local standardColors = {
		positive = Color3.fromRGB(34, 197, 94),    -- Green - success/positive
		neutral = Color3.fromRGB(59, 130, 246),    -- Blue - info/neutral
		warning = Color3.fromRGB(245, 158, 11),    -- Amber - warnings
		negative = Color3.fromRGB(239, 68, 68),    -- Red - errors/negative
		special = Color3.fromRGB(168, 85, 247),    -- Purple - achievements/special
		default = Color3.fromRGB(107, 114, 128)    -- Gray - fallback
	}

	-- All toast types use the same standardized design
	local standardStyle = {
		backgroundTransparency = TOAST_CONFIG.styling.backgroundTransparency,
		textColor = TOAST_CONFIG.styling.textColor,
		iconColor = TOAST_CONFIG.styling.iconColor
	}

	local styles = {
		-- Positive feedback (success, completed actions)
		success = {
			background = standardColors.positive,
			backgroundTransparency = standardStyle.backgroundTransparency,
			textColor = standardStyle.textColor,
			iconColor = standardStyle.iconColor,
			shadowColor = TOAST_CONFIG.styling.shadowColor,
			icon = getToastIconConfig("success").iconName or "Info"
		},
		-- Neutral information (blue for info)
		info = {
			background = standardColors.neutral,  -- Blue for info
			backgroundTransparency = standardStyle.backgroundTransparency,
			textColor = standardStyle.textColor,
			iconColor = standardStyle.iconColor,
			shadowColor = TOAST_CONFIG.styling.shadowColor,
			icon = getToastIconConfig("info").iconName or "Info"
		},
		-- Attention needed
		warning = {
			background = standardColors.warning,
			backgroundTransparency = standardStyle.backgroundTransparency,
			textColor = standardStyle.textColor,
			iconColor = standardStyle.iconColor,
			shadowColor = TOAST_CONFIG.styling.shadowColor,
			icon = getToastIconConfig("warning").iconName or "Warning"
		},
		-- Problems/errors
		error = {
			background = standardColors.negative,
			backgroundTransparency = standardStyle.backgroundTransparency,
			textColor = standardStyle.textColor,
			iconColor = standardStyle.iconColor,
			shadowColor = TOAST_CONFIG.styling.shadowColor,
			icon = getToastIconConfig("error").iconName or "Error"
		},
		-- Special celebrations
		achievement = {
			background = standardColors.special,
			backgroundTransparency = standardStyle.backgroundTransparency,
			textColor = standardStyle.textColor,
			iconColor = standardStyle.iconColor,
			shadowColor = TOAST_CONFIG.styling.shadowColor,
			icon = getToastIconConfig("achievement").iconName or "Trophy"
		}
	}

	return styles[toastType] or {
		background = standardColors.default,
		backgroundTransparency = standardStyle.backgroundTransparency,
		textColor = standardStyle.textColor,
		iconColor = standardStyle.iconColor,
		shadowColor = TOAST_CONFIG.styling.shadowColor,
		icon = getToastIconConfig("default").iconName or "Info"
	}
end

--[[
	Animate toast in with smooth slide effect
--]]
function ToastManager:AnimateToastIn(toastFrame, styleData)
	if not settings.animationsEnabled then return end

	-- Initial state - start off-screen to the right
	toastFrame.Position = TOAST_CONFIG.animations.slideIn.startPosition
	toastFrame.BackgroundTransparency = TOAST_CONFIG.animations.slideIn.startTransparency

	-- Single smooth slide-in animation
	TweenService:Create(toastFrame,
		TweenInfo.new(TOAST_CONFIG.animations.slideIn.duration, TOAST_CONFIG.animations.slideIn.easing, TOAST_CONFIG.animations.slideIn.direction), {
		Position = UDim2.fromOffset(0, 0),
		BackgroundTransparency = styleData.backgroundTransparency
	}):Play()
end

--[[
	Add interactive hover effects to toast
--]]
function ToastManager:AddInteractiveEffects(toastFrame)
	if not settings.animationsEnabled then return end

	-- Hover detection frame (invisible, covers entire toast)
	local hoverFrame = Instance.new("Frame")
	hoverFrame.Size = UDim2.fromScale(1, 1)
	hoverFrame.BackgroundTransparency = 1
	hoverFrame.ZIndex = TOAST_CONFIG.zIndex.hover
	hoverFrame.Parent = toastFrame

	-- Hover effects
	hoverFrame.MouseEnter:Connect(function()
		if toastFrame:GetAttribute("Dismissing") then return end

		-- Subtle lift and glow effect
		TweenService:Create(toastFrame, TweenInfo.new(TOAST_CONFIG.animations.hover.duration, TOAST_CONFIG.animations.hover.easing, TOAST_CONFIG.animations.hover.direction), {
			Position = TOAST_CONFIG.animations.hover.liftOffset,
			Size = UDim2.fromOffset(TOAST_CONFIG.toast.width + TOAST_CONFIG.animations.hover.sizeIncrease.X.Offset, TOAST_CONFIG.toast.height + TOAST_CONFIG.animations.hover.sizeIncrease.Y.Offset)
		}):Play()
	end)

	hoverFrame.MouseLeave:Connect(function()
		if toastFrame:GetAttribute("Dismissing") then return end

		-- Return to normal
		TweenService:Create(toastFrame, TweenInfo.new(TOAST_CONFIG.animations.hover.duration, TOAST_CONFIG.animations.hover.easing, TOAST_CONFIG.animations.hover.direction), {
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(TOAST_CONFIG.toast.width, TOAST_CONFIG.toast.height)
		}):Play()
	end)

	-- Click to dismiss (optional interaction)
	hoverFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local toastId = toastFrame.Name:match("Toast_(.+)")
			if toastId then
				self:DismissToast(toastId)
			end
		end
	end)
end

--[[
	Dismiss a toast by ID with interactive slide-out animation
--]]
function ToastManager:DismissToast(toastId)
	local toast = self:FindToast(toastId)
	if not toast or not toast.ui then return end

	local toastFrame = toast.ui

	-- Prevent multiple dismissals
	if toastFrame:GetAttribute("Dismissing") then return end
	toastFrame:SetAttribute("Dismissing", true)

	-- Interactive slide-out with scaling and rotation
	local slideOutTween = TweenService:Create(toastFrame,
		TweenInfo.new(TOAST_CONFIG.animations.slideOut.duration, TOAST_CONFIG.animations.slideOut.easing, TOAST_CONFIG.animations.slideOut.direction), {
		Position = TOAST_CONFIG.animations.slideOut.endPosition,
		Rotation = TOAST_CONFIG.animations.slideOut.rotation,
		Size = UDim2.fromOffset(TOAST_CONFIG.toast.width * TOAST_CONFIG.animations.slideOut.scaleMultiplier, TOAST_CONFIG.toast.height * TOAST_CONFIG.animations.slideOut.scaleMultiplier),
		BackgroundTransparency = TOAST_CONFIG.animations.slideOut.endTransparency
	})

	slideOutTween:Play()

	-- Remove after animation completes
	slideOutTween.Completed:Connect(function()
		self:RemoveToast(toastId)
	end)
end

--[[
	Remove toast from active list
--]]
function ToastManager:RemoveToast(toastId)
	for i, toast in ipairs(activeToasts) do
		if toast.id == toastId then
			-- Cancel any pending dismiss timer
			if toast.dismissConnection then
				task.cancel(toast.dismissConnection)
				toast.dismissConnection = nil
			end

			-- Destroy UI element
			if toast.ui then
				toast.ui:Destroy()
				toast.ui = nil
			end

			-- Remove from active list
			table.remove(activeToasts, i)
			break
		end
	end

	-- Process queue
	self:ProcessQueue()
end

--[[
	Queue management
--]]
function ToastManager:QueueToast(toast)
	-- Safety check
	if not toast or not toast.id then
		warn("ToastManager: Invalid toast for queueing")
		return
	end

	-- Simple queue management - just remove oldest if full
	if #toastQueue >= TOAST_CONFIG.queueLimit then
		table.remove(toastQueue, 1) -- Remove oldest
	end

	-- Simple first-in-first-out queue
	table.insert(toastQueue, toast)
end

function ToastManager:ProcessQueue()
	while #activeToasts < settings.maxVisible and #toastQueue > 0 do
		local toast = table.remove(toastQueue, 1)
		self:ShowToast(toast)
	end
end

--[[
	Utility functions
--]]
function ToastManager:FindToast(toastId)
	for _, toast in ipairs(activeToasts) do
		if toast.id == toastId then
			return toast
		end
	end
	return nil
end

function ToastManager:UpdateLayoutOrder()
	for i, toast in ipairs(activeToasts) do
		if toast.ui then
			toast.ui.LayoutOrder = i
		end
	end
end

function ToastManager:UpdateResponsiveLayout()
	if not toastContainer then return end

	local viewportSize = workspace.CurrentCamera.ViewportSize

	-- Adjust for smaller screens
	if viewportSize.X < 800 then
		toastContainer.Size = UDim2.fromOffset(260, 350)
		toastContainer.Position = UDim2.new(1, -280, 1, -370)
	else
		toastContainer.Size = TOAST_CONFIG.container.size
		toastContainer.Position = TOAST_CONFIG.container.position
	end
end

function ToastManager:PlayToastSound(soundName, toastType)
	-- Get SoundManager reference
	local SoundManager = require(script.Parent.SoundManager)

	if soundName and SoundManager then
		-- Try to play the specific sound if it exists
		if SoundManager.PlaySFX then
			SoundManager:PlaySFX(soundName)
		end
	else
		-- Fallback: play a default sound based on toast type
		local defaultSound = "buttonClick" -- Default sound

		if toastType == "success" then
			defaultSound = "achievement"
		elseif toastType == "error" or toastType == "warning" then
			defaultSound = "buttonClick" -- Keep simple for errors/warnings
		end

		if SoundManager and SoundManager.PlaySFX then
			SoundManager:PlaySFX(defaultSound)
		end
	end
end

--[[
	Configuration methods
--]]
function ToastManager:SetEnabled(enabled)
	settings.enabled = enabled
end

function ToastManager:IsEnabled()
	return settings.enabled
end

function ToastManager:SetMaxVisible(max)
	settings.maxVisible = math.max(1, math.min(10, max))
end

function ToastManager:ClearAll()
	-- Cancel all pending dismiss timers and destroy UIs
	for _, toast in ipairs(activeToasts) do
		if toast.dismissConnection then
			task.cancel(toast.dismissConnection)
		end
		if toast.ui then
			toast.ui:Destroy()
		end
	end

	-- Clear all arrays
	activeToasts = {}
	toastQueue = {}
end

--[[
	Cleanup
--]]
function ToastManager:Destroy()
	self:ClearAll()
	if toastContainer then
		toastContainer.Parent:Destroy()
	end
	isInitialized = false
end

-- Export constants for external use
ToastManager.CATEGORIES = CATEGORIES

return ToastManager