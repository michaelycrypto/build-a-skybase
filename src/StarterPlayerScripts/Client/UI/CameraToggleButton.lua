--[[
	CameraToggleButton.lua
	Standalone camera mode toggle button styled to match Roblox core GUI topbar buttons.
	Positioned top-left, to the right of the core GUI buttons in the topbar.

	Features:
	- 44x44 round button with F5 keybind badge
	- Cycles through camera modes on click or F5
	- Updates icon based on current camera state
	- IgnoreGuiInset = true, positioned at left margin 172px
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)

local CameraToggleButton = {}
CameraToggleButton.__index = CameraToggleButton

local BUTTON_CONFIG = {
	-- Size and shape
	BUTTON_SIZE = 44,
	CORNER_RADIUS = 22,  -- Half of 44 = perfectly round

	-- Position (IgnoreGuiInset = true, absolute from top-left)
	LEFT_MARGIN = 172,
	TOP_MARGIN = 12,

	-- Visual style
	BG_COLOR = Color3.fromRGB(21, 24, 28),        -- #15181c
	BG_COLOR_HOVER = Color3.fromRGB(30, 35, 40),  -- #1e2328
	BG_TRANSPARENCY = 0,
	BG_TRANSPARENCY_HOVER = 0,

	-- Icon
	ICON_COLOR = Color3.fromRGB(255, 255, 255),
	ICON_SIZE = 24,

	-- F5 keybind badge
	BADGE_SIZE = 18,
	BADGE_BG = Color3.fromRGB(60, 60, 65),
	BADGE_BG_TRANSPARENCY = 0.15,
	BADGE_TEXT_SIZE = 10,
	BADGE_TEXT_COLOR = Color3.fromRGB(200, 200, 210),
	BADGE_CORNER = 5,

	-- Tooltip
	TOOLTIP_BG = Color3.fromRGB(30, 30, 30),
	TOOLTIP_TEXT_COLOR = Color3.fromRGB(220, 220, 220),
	TOOLTIP_TEXT_SIZE = 12,
	TOOLTIP_PADDING = 6,
	TOOLTIP_OFFSET_Y = 4,
	TOOLTIP_CORNER = 4,
}

-- Camera mode display info
local MODE_INFO = {
	FIRST_PERSON = {
		icon = "👁",
		tooltip = "First Person (F5)",
	},
	THIRD_PERSON_LOCK = {
		icon = "🎯",
		tooltip = "Third Person Lock (F5)",
	},
	THIRD_PERSON_FREE = {
		icon = "📷",
		tooltip = "Third Person Free (F5)",
	},
}

local TWEEN_HOVER = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

function CameraToggleButton.new()
	local self = setmetatable({}, CameraToggleButton)

	self.gui = nil
	self.button = nil
	self.iconLabel = nil
	self.badge = nil
	self.tooltip = nil
	self.isHovered = false
	self.connections = {}

	-- Callback set by GameClient
	self.onCameraMode = nil

	return self
end

function CameraToggleButton:Initialize()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "CameraToggleButton"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = playerGui

	self:CreateButton()

	-- Register with visibility manager
	UIVisibilityManager:RegisterComponent("cameraToggleButton", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 2,
	})

	return self
end

function CameraToggleButton:CreateButton()
	local size = BUTTON_CONFIG.BUTTON_SIZE

	-- Round button
	self.button = Instance.new("TextButton")
	self.button.Name = "CameraToggle"
	self.button.Size = UDim2.fromOffset(size, size)
	self.button.Position = UDim2.new(0, BUTTON_CONFIG.LEFT_MARGIN, 0, BUTTON_CONFIG.TOP_MARGIN)
	self.button.AnchorPoint = Vector2.new(0, 0)
	self.button.BackgroundColor3 = BUTTON_CONFIG.BG_COLOR
	self.button.BackgroundTransparency = BUTTON_CONFIG.BG_TRANSPARENCY
	self.button.BorderSizePixel = 0
	self.button.Text = ""
	self.button.AutoButtonColor = false
	self.button.ZIndex = 2
	self.button.Parent = self.gui

	-- Fully round corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, BUTTON_CONFIG.CORNER_RADIUS)
	corner.Parent = self.button

	-- Camera icon (centered)
	self.iconLabel = Instance.new("TextLabel")
	self.iconLabel.Name = "CameraIcon"
	self.iconLabel.Size = UDim2.fromOffset(BUTTON_CONFIG.ICON_SIZE, BUTTON_CONFIG.ICON_SIZE)
	self.iconLabel.Position = UDim2.fromScale(0.5, 0.5)
	self.iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.iconLabel.BackgroundTransparency = 1
	self.iconLabel.Text = "📷"
	self.iconLabel.TextColor3 = BUTTON_CONFIG.ICON_COLOR
	self.iconLabel.TextTransparency = 0
	self.iconLabel.TextScaled = true
	self.iconLabel.Font = Enum.Font.GothamBold
	self.iconLabel.ZIndex = 3
	self.iconLabel.Parent = self.button

	-- F5 keybind badge (bottom-right corner of button)
	self:CreateKeybindBadge()

	-- Tooltip (appears below button on hover)
	self:CreateTooltip()

	-- Click handler
	local clickConn = self.button.Activated:Connect(function()
		if self.onCameraMode then
			self.onCameraMode()
		end
	end)
	table.insert(self.connections, clickConn)

	-- Hover effects
	local enterConn = self.button.MouseEnter:Connect(function()
		self.isHovered = true
		self:UpdateVisual()
		if self.tooltip then
			self.tooltip.Visible = true
		end
	end)
	table.insert(self.connections, enterConn)

	local leaveConn = self.button.MouseLeave:Connect(function()
		self.isHovered = false
		self:UpdateVisual()
		if self.tooltip then
			self.tooltip.Visible = false
		end
	end)
	table.insert(self.connections, leaveConn)
end

function CameraToggleButton:CreateKeybindBadge()
	local badgeSize = BUTTON_CONFIG.BADGE_SIZE

	-- Badge container — anchored to bottom-right of button, slightly overhanging
	local badge = Instance.new("Frame")
	badge.Name = "KeybindBadge"
	badge.Size = UDim2.fromOffset(badgeSize, badgeSize)
	badge.Position = UDim2.new(1, -2, 1, -2)
	badge.AnchorPoint = Vector2.new(1, 1)
	badge.BackgroundColor3 = BUTTON_CONFIG.BADGE_BG
	badge.BackgroundTransparency = BUTTON_CONFIG.BADGE_BG_TRANSPARENCY
	badge.BorderSizePixel = 0
	badge.ZIndex = 5
	badge.Parent = self.button

	-- Round badge corners
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, BUTTON_CONFIG.BADGE_CORNER)
	badgeCorner.Parent = badge

	-- Subtle border on badge
	local badgeBorder = Instance.new("UIStroke")
	badgeBorder.Color = Color3.fromRGB(90, 90, 100)
	badgeBorder.Thickness = 1
	badgeBorder.Transparency = 0.5
	badgeBorder.Parent = badge

	-- F5 text
	local badgeLabel = Instance.new("TextLabel")
	badgeLabel.Name = "BadgeText"
	badgeLabel.Size = UDim2.fromScale(1, 1)
	badgeLabel.Position = UDim2.fromScale(0.5, 0.5)
	badgeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	badgeLabel.BackgroundTransparency = 1
	badgeLabel.Text = "F5"
	badgeLabel.TextColor3 = BUTTON_CONFIG.BADGE_TEXT_COLOR
	badgeLabel.TextSize = BUTTON_CONFIG.BADGE_TEXT_SIZE
	badgeLabel.Font = Enum.Font.GothamBold
	badgeLabel.ZIndex = 6
	badgeLabel.Parent = badge

	self.badge = badge
end

function CameraToggleButton:CreateTooltip()
	local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = BUTTON_CONFIG.TOOLTIP_BG
	tooltip.BackgroundTransparency = 0.05
	tooltip.BorderSizePixel = 0
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.AnchorPoint = Vector2.new(0, 0)
	tooltip.Position = UDim2.new(0, 0, 1, BUTTON_CONFIG.TOOLTIP_OFFSET_Y)
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = self.button

	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, BUTTON_CONFIG.TOOLTIP_CORNER)
	tooltipCorner.Parent = tooltip

	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(60, 60, 65)
	border.Thickness = 1
	border.Transparency = 0.5
	border.Parent = tooltip

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, BUTTON_CONFIG.TOOLTIP_PADDING)
	padding.PaddingRight = UDim.new(0, BUTTON_CONFIG.TOOLTIP_PADDING)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = tooltip

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.new(0, 0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.TextSize = BUTTON_CONFIG.TOOLTIP_TEXT_SIZE
	label.TextColor3 = BUTTON_CONFIG.TOOLTIP_TEXT_COLOR
	label.Text = "Toggle Camera (F5)"
	label.ZIndex = 11
	label.Parent = tooltip

	self.tooltip = tooltip
	self.tooltipLabel = label
end

function CameraToggleButton:UpdateVisual()
	local targetBgColor = self.isHovered
		and BUTTON_CONFIG.BG_COLOR_HOVER
		or BUTTON_CONFIG.BG_COLOR
	local targetBgTransparency = self.isHovered
		and BUTTON_CONFIG.BG_TRANSPARENCY_HOVER
		or BUTTON_CONFIG.BG_TRANSPARENCY

	TweenService:Create(self.button, TWEEN_HOVER, {
		BackgroundColor3 = targetBgColor,
		BackgroundTransparency = targetBgTransparency,
	}):Play()
end

function CameraToggleButton:SetCameraMode(modeName)
	local info = MODE_INFO[modeName]
	if not info then return end

	if self.iconLabel then
		self.iconLabel.Text = info.icon
	end
	if self.tooltipLabel then
		self.tooltipLabel.Text = info.tooltip
	end
end

--[[
	Visibility methods (for UIVisibilityManager)
]]

function CameraToggleButton:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function CameraToggleButton:Hide()
	self.isHovered = false
	if self.tooltip then
		self.tooltip.Visible = false
	end
	if self.gui then
		self.gui.Enabled = false
	end
end

--[[
	Cleanup
]]

function CameraToggleButton:Destroy()
	for _, conn in ipairs(self.connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	self.connections = {}

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return CameraToggleButton
