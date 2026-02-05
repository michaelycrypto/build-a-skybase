--[[
	ActionBar.lua
	Unified horizontal action bar positioned above status bars
	
	Consolidates:
	- Inventory button (was in VoxelHotbar)
	- Worlds button (was in VoxelHotbar)
	- Action buttons (Sprint, Camera)
	
	Features:
	- All buttons visible on all platforms (desktop and mobile)
	- Matches VoxelHotbar styling (42x42px buttons, dark bg, borders)
	- Uses IconManager for icons
	- Centered horizontally, positioned above StatusBarsHUD
	- Hover tooltips for button descriptions
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)

local ActionBar = {}
ActionBar.__index = ActionBar

local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

-- Configuration (matching VoxelHotbar styling)
local UI_CONFIG = {
	BUTTON_SIZE = 42,  -- 25% smaller than hotbar slots (56 * 0.75)
	BUTTON_SPACING = 8,
	SCALE = 0.85,  -- Match hotbar scale
	
	-- Positioning relative to StatusBarsHUD
	GAP_ABOVE_STATUS = 4,
	
	-- Hotbar constants (must match VoxelHotbar and StatusBarsHUD)
	HOTBAR_SLOT_SIZE = 56,
	HOTBAR_BOTTOM_OFFSET = 4,
	HOTBAR_BORDER = 2,
	
	-- Status bar constants (must match StatusBarsHUD)
	STATUS_ICON_SIZE = 22,
	STATUS_BAR_SPACING = 5,
	STATUS_GAP_ABOVE_HOTBAR = 4,
	
	-- Colors (matching VoxelHotbar buttons)
	BG_COLOR = Color3.fromRGB(31, 31, 31),
	BG_TRANSPARENCY = 0.5,
	BG_TRANSPARENCY_HOVER = 0.25,
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	BORDER_TRANSPARENCY = 0.25,
	BORDER_TRANSPARENCY_HOVER = 0,
	BG_IMAGE = "rbxassetid://82824299358542",
	BG_IMAGE_TRANSPARENCY = 0.6,
	CORNER_RADIUS = 2,
	
	-- Active state colors (for toggle buttons)
	ACTIVE_BORDER_COLOR = Color3.fromRGB(100, 200, 100),
	ACTIVE_ICON_COLOR = Color3.fromRGB(100, 200, 100),
}

-- Cached TweenInfo objects for performance
local TWEEN_INFO = {
	VISUAL_UPDATE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- Tooltip configuration
local TOOLTIP_CONFIG = {
	OFFSET_Y = -4,  -- Small gap above the button
	PADDING_H = 10,
	PADDING_V = 6,
	BG_COLOR = Color3.fromRGB(15, 15, 15),
	BG_TRANSPARENCY = 0.1,
	TEXT_SIZE = 16,
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	CORNER_RADIUS = 6,
}

-- Button definitions
local BUTTON_DEFINITIONS = {
	{
		id = "Worlds",
		iconCategory = "Nature",
		iconName = "Globe",
		keybind = "B",
		tooltip = "World Teleport",
		behavior = "tap",  -- tap to toggle panel
	},
	{
		id = "Inventory",
		iconCategory = "Clothing",
		iconName = "Backpack",
		keybind = "E",
		tooltip = "Open Inventory",
		behavior = "tap",  -- tap to toggle panel
	},
	{
		id = "Sprint",
		iconText = "⚡",
		keybind = "⇧",  -- Shift key indicator
		tooltip = "Sprint",
		behavior = "toggle",  -- tap to toggle state
	},
	{
		id = "Camera",
		iconText = "📷",
		keybind = "F5",  -- Camera toggle key
		tooltip = "Toggle Camera",
		behavior = "tap",  -- tap to cycle modes
	},
}

function ActionBar.new()
	local self = setmetatable({}, ActionBar)
	
	self.gui = nil
	self.container = nil
	self.buttons = {}  -- { [id] = { frame, border, icon, active, pressed, def, tooltip } }
	self.connections = {}
	
	-- Panel references (set by GameClient)
	self.voxelInventory = nil
	self.worldsPanel = nil
	
	-- Callbacks for controls
	self.onSprintToggle = nil  -- function(isActive: boolean)
	self.onCameraMode = nil    -- function()
	
	-- UI toggle debounce
	self.uiToggleDebounce = 0.3
	self.lastUiToggleTime = 0
	
	return self
end

function ActionBar:CanToggleUI()
	local now = tick()
	if now - self.lastUiToggleTime < self.uiToggleDebounce then
		return false
	end
	self.lastUiToggleTime = now
	return true
end

function ActionBar:Initialize()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "ActionBar"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 48  -- Below StatusBarsHUD (49) and VoxelHotbar (50)
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = playerGui
	
	-- Add responsive scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")
	
	-- Create UI
	self:CreateContainer()
	self:CreateButtons()
	
	-- Register with visibility manager
	UIVisibilityManager:RegisterComponent("actionBar", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 5
	})
	
	return self
end

function ActionBar:CreateContainer()
	local buttonCount = #BUTTON_DEFINITIONS
	
	-- Calculate container dimensions
	local totalWidth = (buttonCount * UI_CONFIG.BUTTON_SIZE) + 
	                   ((buttonCount - 1) * UI_CONFIG.BUTTON_SPACING)
	local containerHeight = UI_CONFIG.BUTTON_SIZE
	
	-- Calculate vertical position (above StatusBarsHUD)
	local visualSlotSize = UI_CONFIG.HOTBAR_SLOT_SIZE + (UI_CONFIG.HOTBAR_BORDER * 2)
	local hotbarScaledHeight = visualSlotSize * UI_CONFIG.SCALE
	local statusBarHeight = (UI_CONFIG.STATUS_ICON_SIZE * 2) + UI_CONFIG.STATUS_BAR_SPACING
	local statusBarScaledHeight = statusBarHeight * UI_CONFIG.SCALE
	
	-- Bottom offset calculation
	local statusBarBottom = UI_CONFIG.HOTBAR_BOTTOM_OFFSET + hotbarScaledHeight + UI_CONFIG.STATUS_GAP_ABOVE_HOTBAR
	local actionBarBottom = statusBarBottom + statusBarScaledHeight + UI_CONFIG.GAP_ABOVE_STATUS
	
	-- Create container
	self.container = Instance.new("Frame")
	self.container.Name = "ActionBarContainer"
	self.container.Size = UDim2.fromOffset(totalWidth, containerHeight)
	self.container.Position = UDim2.new(0.5, 0, 1, -math.floor(actionBarBottom / UI_CONFIG.SCALE + 0.5))
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.BackgroundTransparency = 1
	self.container.Parent = self.gui
	
	-- Local scale (matches VoxelHotbar)
	local localScale = Instance.new("UIScale")
	localScale.Name = "LocalScale"
	localScale.Scale = UI_CONFIG.SCALE
	localScale.Parent = self.container
	
	-- Horizontal layout
	local layout = Instance.new("UIListLayout")
	layout.Name = "ButtonLayout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, UI_CONFIG.BUTTON_SPACING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.container
end

function ActionBar:CreateButtons()
	for index, def in ipairs(BUTTON_DEFINITIONS) do
		self:CreateButton(def, index)
	end
end

function ActionBar:CreateButton(def, layoutOrder)
	-- Button frame
	local button = Instance.new("TextButton")
	button.Name = def.id .. "Button"
	button.Size = UDim2.fromOffset(UI_CONFIG.BUTTON_SIZE, UI_CONFIG.BUTTON_SIZE)
	button.BackgroundColor3 = UI_CONFIG.BG_COLOR
	button.BackgroundTransparency = UI_CONFIG.BG_TRANSPARENCY
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = layoutOrder
	button.Parent = self.container
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI_CONFIG.CORNER_RADIUS)
	corner.Parent = button
	
	-- Background image
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = UI_CONFIG.BG_IMAGE
	bgImage.ImageTransparency = UI_CONFIG.BG_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = button
	
	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = UI_CONFIG.BORDER_COLOR
	border.Thickness = 2
	border.Transparency = UI_CONFIG.BORDER_TRANSPARENCY
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button
	
	-- Icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -8, 1, -8)
	iconContainer.Position = UDim2.fromScale(0.5, 0.5)
	iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = button
	
	-- Create icon (either via IconManager or text)
	local icon
	if def.iconCategory and def.iconName then
		icon = IconManager:CreateIcon(iconContainer, def.iconCategory, def.iconName, {
			size = UDim2.fromScale(1, 1),
			position = UDim2.fromScale(0.5, 0.5),
			anchorPoint = Vector2.new(0.5, 0.5),
		})
	elseif def.iconText then
		icon = Instance.new("TextLabel")
		icon.Name = "IconText"
		icon.Size = UDim2.new(1, -4, 1, -4)
		icon.Position = UDim2.fromScale(0.5, 0.5)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.BackgroundTransparency = 1
		icon.Text = def.iconText
		icon.TextColor3 = Color3.fromRGB(255, 255, 255)
		icon.TextScaled = true
		icon.Font = BOLD_FONT
		icon.ZIndex = 3
		icon.Parent = iconContainer
	end
	
	-- Keybind label (if has keybind)
	local keybindLabel
	if def.keybind then
		keybindLabel = Instance.new("TextLabel")
		keybindLabel.Name = "KeybindLabel"
		keybindLabel.Size = UDim2.fromOffset(28, 18)
		keybindLabel.Position = UDim2.fromOffset(3, 3)
		keybindLabel.BackgroundTransparency = 1
		keybindLabel.Font = BOLD_FONT
		keybindLabel.TextSize = 13
		keybindLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		keybindLabel.TextStrokeTransparency = 0.3
		keybindLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		keybindLabel.Text = def.keybind
		keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
		keybindLabel.TextYAlignment = Enum.TextYAlignment.Top
		keybindLabel.ZIndex = 4
		keybindLabel.Parent = button
	end
	
	-- Create tooltip (if has tooltip text)
	local tooltip
	if def.tooltip then
		tooltip = self:CreateTooltip(def.tooltip, button)
	end
	
	-- Store button data
	local buttonData = {
		frame = button,
		border = border,
		iconContainer = iconContainer,
		icon = icon,
		keybindLabel = keybindLabel,
		tooltip = tooltip,
		def = def,
		active = false,
		pressed = false,
		isHovered = false,
	}
	self.buttons[def.id] = buttonData
	
	-- Setup input handling
	self:SetupButtonInput(buttonData)
	
	-- Hover effects
	local hoverEnterConn = button.MouseEnter:Connect(function()
		buttonData.isHovered = true
		if SoundManager and SoundManager.PlaySFX then
			SoundManager:PlaySFX("buttonHover")
		end
		self:UpdateButtonVisual(buttonData)
		self:ShowTooltip(buttonData)
	end)
	table.insert(self.connections, hoverEnterConn)
	
	local hoverLeaveConn = button.MouseLeave:Connect(function()
		buttonData.isHovered = false
		self:UpdateButtonVisual(buttonData)
		self:HideTooltip(buttonData)
	end)
	table.insert(self.connections, hoverLeaveConn)
end

function ActionBar:CreateTooltip(text, parentButton)
	-- Tooltip frame - parented to button for automatic positioning
	local tooltip = Instance.new("Frame")
	tooltip.Name = "Tooltip"
	tooltip.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	tooltip.BackgroundTransparency = 0
	tooltip.BorderSizePixel = 0
	tooltip.Size = UDim2.new(0, 0, 0, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Position = UDim2.new(0.5, 0, 0, -4)
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = parentButton
	
	-- Corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = tooltip
	
	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = tooltip
	
	-- Text label
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextTransparency = 0
	label.Text = text
	label.ZIndex = 11
	label.Parent = tooltip
	
	return { frame = tooltip }
end

function ActionBar:ShowTooltip(buttonData)
	if not buttonData.tooltip then return end
	buttonData.tooltip.frame.Visible = true
end

function ActionBar:HideTooltip(buttonData)
	if not buttonData.tooltip then return end
	buttonData.tooltip.frame.Visible = false
end

function ActionBar:SetupButtonInput(buttonData)
	local button = buttonData.frame
	local def = buttonData.def
	local behavior = def.behavior
	
	if behavior == "tap" then
		-- Tap behavior: fire action on click/tap
		local conn = button.Activated:Connect(function()
			self:HandleButtonAction(def.id)
		end)
		table.insert(self.connections, conn)
		
	elseif behavior == "toggle" then
		-- Toggle behavior: flip state on tap
		local conn = button.Activated:Connect(function()
			buttonData.active = not buttonData.active
			self:UpdateButtonVisual(buttonData)
			self:HandleButtonAction(def.id, buttonData.active)
		end)
		table.insert(self.connections, conn)
	end
end

function ActionBar:ResetHoverState()
	for _, buttonData in pairs(self.buttons) do
		buttonData.isHovered = false
		self:UpdateButtonVisual(buttonData)
		if buttonData.tooltip then
			buttonData.tooltip.frame.Visible = false
		end
	end
end

function ActionBar:HandleButtonAction(buttonId, state)
	if buttonId == "Worlds" then
		if not self:CanToggleUI() then
			return
		end
		self:ResetHoverState()
		-- Close inventory if open before opening worlds
		if self.voxelInventory and self.voxelInventory.isOpen then
			self.voxelInventory:Close("worlds")
		elseif self.voxelInventory and self.voxelInventory.IsClosing and self.voxelInventory:IsClosing() then
			self.voxelInventory:SetPendingCloseMode("worlds")
		end
		if self.worldsPanel then
			self.worldsPanel:Toggle()
		end
		
	elseif buttonId == "Inventory" then
		if not self:CanToggleUI() then
			return
		end
		self:ResetHoverState()
		if self.voxelInventory then
			self.voxelInventory:Toggle()
		else
			warn("ActionBar: Inventory reference not set")
		end
		
	elseif buttonId == "Sprint" then
		if self.onSprintToggle then
			self.onSprintToggle(state)
		end
		
	elseif buttonId == "Camera" then
		if self.onCameraMode then
			self.onCameraMode()
		end
	end
end

function ActionBar:UpdateButtonVisual(buttonData)
	local isActive = buttonData.active
	local isHovered = buttonData.isHovered
	
	-- Determine target colors based on state
	local targetBorderColor = isActive and UI_CONFIG.ACTIVE_BORDER_COLOR or UI_CONFIG.BORDER_COLOR
	local targetBorderTransparency = (isActive or isHovered) and UI_CONFIG.BORDER_TRANSPARENCY_HOVER or UI_CONFIG.BORDER_TRANSPARENCY
	local targetBgTransparency = (isActive or isHovered) and UI_CONFIG.BG_TRANSPARENCY_HOVER or UI_CONFIG.BG_TRANSPARENCY
	
	-- Animate border
	TweenService:Create(buttonData.border, TWEEN_INFO.VISUAL_UPDATE, {
		Color = targetBorderColor,
		Transparency = targetBorderTransparency
	}):Play()
	
	-- Animate background
	TweenService:Create(buttonData.frame, TWEEN_INFO.VISUAL_UPDATE, {
		BackgroundTransparency = targetBgTransparency
	}):Play()
	
	-- Tint icon based on active state
	local targetIconColor = isActive and UI_CONFIG.ACTIVE_ICON_COLOR or Color3.fromRGB(255, 255, 255)
	
	if buttonData.icon then
		if buttonData.icon:IsA("TextLabel") then
			TweenService:Create(buttonData.icon, TWEEN_INFO.VISUAL_UPDATE, {
				TextColor3 = targetIconColor
			}):Play()
		elseif buttonData.icon:IsA("ImageLabel") then
			TweenService:Create(buttonData.icon, TWEEN_INFO.VISUAL_UPDATE, {
				ImageColor3 = targetIconColor
			}):Play()
		end
	end
end

--[[
	External API for setting state from other systems
]]

function ActionBar:SetSprintActive(isActive)
	local buttonData = self.buttons["Sprint"]
	if buttonData and buttonData.active ~= isActive then
		buttonData.active = isActive
		self:UpdateButtonVisual(buttonData)
	end
end

function ActionBar:SetCameraMode(modeName)
	local buttonData = self.buttons["Camera"]
	if not buttonData or not buttonData.icon then
		return
	end
	
	-- Update icon based on mode
	local icons = {
		FIRST_PERSON = "👁",
		THIRD_PERSON_LOCK = "🎯",
		THIRD_PERSON_FREE = "📷",
	}
	
	if buttonData.icon:IsA("TextLabel") then
		buttonData.icon.Text = icons[modeName] or "📷"
	end
end

--[[
	Visibility methods (for UIVisibilityManager)
]]

function ActionBar:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function ActionBar:Hide()
	self:ResetHoverState()
	if self.gui then
		self.gui.Enabled = false
	end
end

--[[
	Cleanup
]]

function ActionBar:Destroy()
	-- Disconnect all connections
	for _, connection in ipairs(self.connections) do
		if connection and connection.Connected then
			connection:Disconnect()
		end
	end
	self.connections = {}
	
	-- Destroy GUI
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	
	-- Clear references
	self.buttons = {}
	self.voxelInventory = nil
	self.worldsPanel = nil
end

return ActionBar
