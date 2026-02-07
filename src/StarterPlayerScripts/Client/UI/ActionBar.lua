--[[
	ActionBar.lua
	Unified horizontal action bar positioned above status bars
	
	Features:
	- Action buttons (Inventory, Worlds, Sprint) — square, rounded, icon-over-label
	- Buttons: vertical layout (icon on top, label + keybind below), larger icons
	- Uses IconManager for icons; hover tooltips for descriptions
	- Centered horizontally, positioned above StatusBarsHUD
	- Camera toggle moved to standalone CameraToggleButton (top-left, CoreGui-style)
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
	-- Square buttons (icon above label)
	BUTTON_SIZE = 86,    -- ~20% larger
	BUTTON_SPACING = 10, -- Comfortable gap between buttons
	SCALE = 0.85,        -- Match hotbar scale
	
	-- Positioning relative to StatusBarsHUD
	GAP_ABOVE_STATUS = 1,  -- Minimal consistent gap
	
	-- Hotbar constants (must match VoxelHotbar and StatusBarsHUD)
	HOTBAR_SLOT_SIZE = 74,
	HOTBAR_BOTTOM_OFFSET = 4,
	HOTBAR_BORDER = 2,
	
	-- Status bar constants (must match StatusBarsHUD - single row, compact icons)
	STATUS_ICON_SIZE = 20,
	STATUS_GAP_ABOVE_HOTBAR = 1,  -- Minimal consistent gap
	
	-- Visuals (match VoxelHotbar slots: same bg image, border, corners)
	BG_COLOR = Color3.fromRGB(31, 31, 31),
	BG_TRANSPARENCY = 0.5,
	BG_TRANSPARENCY_HOVER = 0.25,
	BG_IMAGE_ASSET = "rbxassetid://82824299358542",
	BG_IMAGE_TRANSPARENCY = 0.6,
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	BORDER_COLOR_HOVER = Color3.fromRGB(95, 95, 105),
	BORDER_TRANSPARENCY = 0.25,
	BORDER_TRANSPARENCY_HOVER = 0,
	CORNER_RADIUS = 2,   -- Match hotbar slots
	BORDER_THICKNESS = 2,
	
	-- Active state colors (for toggle buttons)
	ACTIVE_BG_COLOR = Color3.fromRGB(38, 58, 38),
	ACTIVE_BORDER_COLOR = Color3.fromRGB(85, 185, 85),
	ACTIVE_TEXT_COLOR = Color3.fromRGB(115, 235, 115),
	
	-- Button content: vertical stack (icon on top, label+keybind below); fits in BUTTON_SIZE
	ICON_SIZE = 52,           -- Fits with text row in 86px height
	CONTENT_PADDING_V = 5,    -- Vertical padding (top/bottom)
	CONTENT_PADDING_H = 7,    -- Horizontal padding
	ICON_TO_TEXT_GAP = 2,     -- Gap between icon and text row
	TEXT_ROW_HEIGHT = 22,     -- Single line for label + keybind
	LABEL_TEXT_SIZE = 19,     -- Larger label
	KEYBIND_TEXT_SIZE = 15,   -- Larger keybind
	KEYBIND_COLOR = Color3.fromRGB(145, 145, 155),
}

-- Cached TweenInfo objects for performance
local TWEEN_INFO = {
	VISUAL_UPDATE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

-- Tooltip configuration
local TOOLTIP_CONFIG = {
	OFFSET_Y = -5,  -- Small gap above the button
	PADDING_H = 12,
	PADDING_V = 7,
	BG_COLOR = Color3.fromRGB(15, 15, 15),
	BG_TRANSPARENCY = 0.1,
	TEXT_SIZE = 16,
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	CORNER_RADIUS = 6,
}

-- Button definitions (reordered: Inventory first, then Worlds)
-- Shorter labels with inline keybinds
local BUTTON_DEFINITIONS = {
	{
		id = "Inventory",
		iconCategory = "Clothing",
		iconName = "Backpack",
		keybind = "E",
		tooltip = "Open Inventory",
		label = "Bag",
		behavior = "tap",
	},
	{
		id = "Worlds",
		iconCategory = "Nature",
		iconName = "Globe",
		keybind = "B",
		tooltip = "World Teleport",
		label = "World",
		behavior = "tap",
	},
	{
		id = "Sprint",
		iconText = "⚡",
		keybind = "⇧",
		tooltip = "Sprint",
		label = "Run",
		behavior = "toggle",
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
	-- Match hotbar width exactly
	local visualSlotSize = UI_CONFIG.HOTBAR_SLOT_SIZE + (UI_CONFIG.HOTBAR_BORDER * 2)  -- 66px
	local hotbarWidth = (visualSlotSize * 9) + (5 * 8)  -- 9 slots + 8 gaps
	local totalWidth = hotbarWidth
	local containerHeight = UI_CONFIG.BUTTON_SIZE
	
	-- Calculate vertical position (above StatusBarsHUD - single row)
	local visualSlotSize = UI_CONFIG.HOTBAR_SLOT_SIZE + (UI_CONFIG.HOTBAR_BORDER * 2)
	local hotbarScaledHeight = visualSlotSize * UI_CONFIG.SCALE
	local statusBarHeight = UI_CONFIG.STATUS_ICON_SIZE  -- Single row (no armor stacked above)
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
	layout.Name = "MainLayout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 0)  -- No padding, we'll handle spacing manually
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.container
end

function ActionBar:CreateButtons()
	-- Buttons container (square buttons in a row)
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "ButtonsContainer"
	local buttonCount = #BUTTON_DEFINITIONS
	local buttonsWidth = (buttonCount * UI_CONFIG.BUTTON_SIZE) + ((buttonCount - 1) * UI_CONFIG.BUTTON_SPACING)
	buttonsContainer.Size = UDim2.fromOffset(buttonsWidth, UI_CONFIG.BUTTON_SIZE)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.LayoutOrder = 1
	buttonsContainer.Parent = self.container
	
	-- Horizontal layout for buttons
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.Name = "ButtonLayout"
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.Padding = UDim.new(0, UI_CONFIG.BUTTON_SPACING)
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Parent = buttonsContainer
	
	self.buttonsContainer = buttonsContainer
	
	for index, def in ipairs(BUTTON_DEFINITIONS) do
		self:CreateButton(def, index)
	end
end

function ActionBar:CreateButton(def, layoutOrder)
	-- Square button frame (same base look as hotbar slots)
	local button = Instance.new("TextButton")
	button.Name = def.id .. "Button"
	button.Size = UDim2.fromOffset(UI_CONFIG.BUTTON_SIZE, UI_CONFIG.BUTTON_SIZE)
	button.BackgroundColor3 = UI_CONFIG.BG_COLOR
	button.BackgroundTransparency = UI_CONFIG.BG_TRANSPARENCY
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.LayoutOrder = layoutOrder
	button.Parent = self.buttonsContainer
	
	-- Corners (match hotbar slots)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI_CONFIG.CORNER_RADIUS)
	corner.Parent = button
	
	-- Background image (same as hotbar, stretched to fill)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = UI_CONFIG.BG_IMAGE_ASSET
	bgImage.ImageTransparency = UI_CONFIG.BG_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Stretch
	bgImage.ZIndex = 1
	bgImage.Parent = button
	
	-- Border (match hotbar slots)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = UI_CONFIG.BORDER_COLOR
	border.Thickness = UI_CONFIG.BORDER_THICKNESS
	border.Transparency = UI_CONFIG.BORDER_TRANSPARENCY
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button
	
	-- Content container: vertical stack (icon on top, label+keybind below)
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.new(1, 0, 1, 0)
	contentContainer.Position = UDim2.fromScale(0.5, 0.5)
	contentContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	contentContainer.BackgroundTransparency = 1
	contentContainer.ZIndex = 3
	contentContainer.Parent = button
	
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, UI_CONFIG.CONTENT_PADDING_V)
	contentPadding.PaddingBottom = UDim.new(0, UI_CONFIG.CONTENT_PADDING_V)
	contentPadding.PaddingLeft = UDim.new(0, UI_CONFIG.CONTENT_PADDING_H)
	contentPadding.PaddingRight = UDim.new(0, UI_CONFIG.CONTENT_PADDING_H)
	contentPadding.Parent = contentContainer
	
	local contentList = Instance.new("UIListLayout")
	contentList.FillDirection = Enum.FillDirection.Vertical
	contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentList.VerticalAlignment = Enum.VerticalAlignment.Top
	contentList.Padding = UDim.new(0, UI_CONFIG.ICON_TO_TEXT_GAP)
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Parent = contentContainer
	
	-- Icon: fixed size, centered by list layout
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromOffset(UI_CONFIG.ICON_SIZE, UI_CONFIG.ICON_SIZE)
	iconContainer.BackgroundTransparency = 1
	iconContainer.LayoutOrder = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = contentContainer
	
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
		icon.Size = UDim2.fromScale(1, 1)
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
	
	-- Text row: label + keybind, centered horizontally
	local textRowHeight = UI_CONFIG.TEXT_ROW_HEIGHT
	local textRow = Instance.new("Frame")
	textRow.Name = "TextRow"
	textRow.Size = UDim2.new(1, 0, 0, textRowHeight)
	textRow.BackgroundTransparency = 1
	textRow.LayoutOrder = 2
	textRow.ZIndex = 4
	textRow.Parent = contentContainer
	
	local textRowLayout = Instance.new("UIListLayout")
	textRowLayout.FillDirection = Enum.FillDirection.Horizontal
	textRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	textRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	textRowLayout.Padding = UDim.new(0, 4)  -- Small gap between label and keybind
	textRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	textRowLayout.Parent = textRow
	
	-- Label (title)
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "ButtonLabel"
	textLabel.Size = UDim2.fromOffset(0, textRowHeight)
	textLabel.AutomaticSize = Enum.AutomaticSize.X
	textLabel.BackgroundTransparency = 1
	textLabel.Text = def.label or def.id
	textLabel.TextColor3 = Color3.fromRGB(245, 245, 245)
	textLabel.TextSize = UI_CONFIG.LABEL_TEXT_SIZE
	textLabel.Font = BOLD_FONT
	textLabel.TextXAlignment = Enum.TextXAlignment.Right
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.LayoutOrder = 1
	textLabel.ZIndex = 4
	textLabel.Parent = textRow
	
	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = Color3.fromRGB(0, 0, 0)
	labelStroke.Thickness = 1
	labelStroke.Transparency = 0.2
	labelStroke.Parent = textLabel
	
	-- Keybind (next to label)
	local keybindLabel = nil
	if def.keybind then
		keybindLabel = Instance.new("TextLabel")
		keybindLabel.Name = "KeybindLabel"
		keybindLabel.Size = UDim2.fromOffset(0, textRowHeight)
		keybindLabel.AutomaticSize = Enum.AutomaticSize.X
		keybindLabel.BackgroundTransparency = 1
		keybindLabel.Text = def.keybind
		keybindLabel.TextColor3 = UI_CONFIG.KEYBIND_COLOR
		keybindLabel.TextSize = UI_CONFIG.KEYBIND_TEXT_SIZE
		keybindLabel.Font = BOLD_FONT
		keybindLabel.TextXAlignment = Enum.TextXAlignment.Left
		keybindLabel.TextYAlignment = Enum.TextYAlignment.Center
		keybindLabel.LayoutOrder = 2
		keybindLabel.ZIndex = 4
		keybindLabel.Parent = textRow
		
		local keybindStroke = Instance.new("UIStroke")
		keybindStroke.Color = Color3.fromRGB(0, 0, 0)
		keybindStroke.Thickness = 0.8
		keybindStroke.Transparency = 0.3
		keybindStroke.Parent = keybindLabel
	end
	
	-- Tooltip
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
		textLabel = textLabel,
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
	tooltip.BackgroundColor3 = Color3.fromRGB(20, 20, 22)
	tooltip.BackgroundTransparency = 0.05
	tooltip.BorderSizePixel = 0
	tooltip.Size = UDim2.new(0, 0, 0, 0)
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.AnchorPoint = Vector2.new(0.5, 1)
	tooltip.Position = UDim2.new(0.5, 0, 0, -6)
	tooltip.Visible = false
	tooltip.ZIndex = 10
	tooltip.Parent = parentButton
	
	-- Corner (rounded)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = tooltip
	
	-- Border
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(60, 60, 65)
	border.Thickness = 1
	border.Transparency = 0.5
	border.Parent = tooltip
	
	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = tooltip
	
	-- Text label
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0, 0, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Font = BOLD_FONT
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(230, 230, 230)
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
	end
end

function ActionBar:UpdateButtonVisual(buttonData)
	local isActive = buttonData.active
	local isHovered = buttonData.isHovered
	
	-- Determine target states
	local targetBgColor = isActive and UI_CONFIG.ACTIVE_BG_COLOR or UI_CONFIG.BG_COLOR
	local targetBorderColor
	if isActive then
		targetBorderColor = UI_CONFIG.ACTIVE_BORDER_COLOR
	elseif isHovered then
		targetBorderColor = UI_CONFIG.BORDER_COLOR_HOVER
	else
		targetBorderColor = UI_CONFIG.BORDER_COLOR
	end
	local targetBorderTransparency = (isActive or isHovered) and UI_CONFIG.BORDER_TRANSPARENCY_HOVER or UI_CONFIG.BORDER_TRANSPARENCY
	local targetBgTransparency = (isActive or isHovered) and UI_CONFIG.BG_TRANSPARENCY_HOVER or UI_CONFIG.BG_TRANSPARENCY
	
	-- Text colors
	local targetTextColor = isActive and UI_CONFIG.ACTIVE_TEXT_COLOR or Color3.fromRGB(245, 245, 245)
	local targetKeybindColor = isActive and UI_CONFIG.ACTIVE_TEXT_COLOR or UI_CONFIG.KEYBIND_COLOR
	
	-- Animate background
	TweenService:Create(buttonData.frame, TWEEN_INFO.VISUAL_UPDATE, {
		BackgroundColor3 = targetBgColor,
		BackgroundTransparency = targetBgTransparency
	}):Play()
	
	-- Animate border
	TweenService:Create(buttonData.border, TWEEN_INFO.VISUAL_UPDATE, {
		Color = targetBorderColor,
		Transparency = targetBorderTransparency
	}):Play()
	
	-- Animate icon color
	if buttonData.icon then
		if buttonData.icon:IsA("TextLabel") then
			TweenService:Create(buttonData.icon, TWEEN_INFO.VISUAL_UPDATE, {
				TextColor3 = targetTextColor
			}):Play()
		elseif buttonData.icon:IsA("ImageLabel") then
			TweenService:Create(buttonData.icon, TWEEN_INFO.VISUAL_UPDATE, {
				ImageColor3 = targetTextColor
			}):Play()
		end
	end
	
	-- Animate text color
	if buttonData.textLabel then
		TweenService:Create(buttonData.textLabel, TWEEN_INFO.VISUAL_UPDATE, {
			TextColor3 = targetTextColor
		}):Play()
	end
	
	-- Animate keybind color
	if buttonData.keybindLabel then
		TweenService:Create(buttonData.keybindLabel, TWEEN_INFO.VISUAL_UPDATE, {
			TextColor3 = targetKeybindColor
		}):Play()
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
