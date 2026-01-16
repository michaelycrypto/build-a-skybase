--[[
	MobileActionBar.lua
	Vertical action bar for mobile controls (right side of screen)
	
	Buttons:
	- Sprint (toggle) - Hold to sprint, tap to toggle
	- Attack (hold) - Hold for combat/mining
	- Camera (tap) - Cycle through camera modes
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local MobileActionBar = {}
MobileActionBar.__index = MobileActionBar

-- UI Configuration (matching VoxelHotbar style)
local UI_CONFIG = {
	BUTTON_SIZE = 52,
	BUTTON_SPACING = 8,
	BORDER_WIDTH = 3,
	CORNER_RADIUS = 8,
	RIGHT_OFFSET = 20,
	BOTTOM_OFFSET = 180, -- Above native jump button area
	
	-- Colors (matching VoxelHotbar)
	BG_COLOR = Color3.fromRGB(40, 40, 40),
	BG_TRANSPARENCY = 0.3,
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	ICON_COLOR = Color3.fromRGB(255, 255, 255),
	ACTIVE_COLOR = Color3.fromRGB(100, 200, 100),
	PRESSED_COLOR = Color3.fromRGB(80, 80, 80),
}

-- Button definitions
local BUTTONS = {
	{
		id = "Sprint",
		icon = "bolt", -- Unicode lightning bolt
		iconText = "⚡",
		behavior = "toggle", -- toggle state on tap
	},
	{
		id = "Attack",
		icon = "sword",
		iconText = "⚔",
		behavior = "hold", -- active while held
	},
	{
		id = "Camera",
		icon = "camera",
		iconText = "📷",
		behavior = "tap", -- single action on tap
	},
}

-- Font from config
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

function MobileActionBar.new()
	local self = setmetatable({}, MobileActionBar)
	
	-- State
	self.enabled = false
	self.buttons = {} -- { [id] = { frame, active, pressed } }
	self.gui = nil
	self.container = nil
	
	-- Callbacks
	self.onSprintToggle = nil -- function(isActive: boolean)
	self.onAttackStart = nil -- function()
	self.onAttackEnd = nil -- function()
	self.onCameraMode = nil -- function()
	
	return self
end

--[[
	Create the main UI container
]]
function MobileActionBar:CreateUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "MobileActionBar"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 60
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = playerGui
	
	-- Add responsive scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")
	
	-- Container frame (vertical layout on right side)
	local totalHeight = (#BUTTONS * UI_CONFIG.BUTTON_SIZE) + ((#BUTTONS - 1) * UI_CONFIG.BUTTON_SPACING)
	
	self.container = Instance.new("Frame")
	self.container.Name = "ActionBarContainer"
	self.container.Size = UDim2.new(0, UI_CONFIG.BUTTON_SIZE, 0, totalHeight)
	self.container.Position = UDim2.new(1, -UI_CONFIG.RIGHT_OFFSET - UI_CONFIG.BUTTON_SIZE, 1, -UI_CONFIG.BOTTOM_OFFSET - totalHeight)
	self.container.BackgroundTransparency = 1
	self.container.Parent = self.gui
	
	-- Vertical layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, UI_CONFIG.BUTTON_SPACING)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = self.container
	
	-- Create buttons
	for index, buttonDef in ipairs(BUTTONS) do
		self:CreateButton(buttonDef, index)
	end
end

--[[
	Create a single button
]]
function MobileActionBar:CreateButton(buttonDef, layoutOrder)
	local button = Instance.new("TextButton")
	button.Name = buttonDef.id .. "Button"
	button.Size = UDim2.new(0, UI_CONFIG.BUTTON_SIZE, 0, UI_CONFIG.BUTTON_SIZE)
	button.BackgroundColor3 = UI_CONFIG.BG_COLOR
	button.BackgroundTransparency = UI_CONFIG.BG_TRANSPARENCY
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.LayoutOrder = layoutOrder
	button.Parent = self.container
	
	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI_CONFIG.CORNER_RADIUS)
	corner.Parent = button
	
	-- Border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Border"
	stroke.Color = UI_CONFIG.BORDER_COLOR
	stroke.Thickness = UI_CONFIG.BORDER_WIDTH
	stroke.Transparency = 0
	stroke.Parent = button
	
	-- Icon label
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(1, -8, 1, -8)
	iconLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = buttonDef.iconText
	iconLabel.TextColor3 = UI_CONFIG.ICON_COLOR
	iconLabel.TextScaled = true
	iconLabel.Font = BOLD_FONT
	iconLabel.Parent = button
	
	-- Store button data
	local buttonData = {
		frame = button,
		icon = iconLabel,
		stroke = stroke,
		def = buttonDef,
		active = false,
		pressed = false,
	}
	self.buttons[buttonDef.id] = buttonData
	
	-- Setup input handling based on behavior
	self:SetupButtonInput(buttonData)
end

--[[
	Setup input handling for a button
]]
function MobileActionBar:SetupButtonInput(buttonData)
	local button = buttonData.frame
	local behavior = buttonData.def.behavior
	
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not self.enabled then return end
		
		buttonData.pressed = true
		self:AnimatePress(buttonData)
		
		if behavior == "hold" then
			-- Hold behavior: activate on press
			buttonData.active = true
			self:UpdateButtonVisual(buttonData)
			self:FireCallback(buttonData.def.id, "start")
		end
	end)
	
	button.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not buttonData.pressed then return end
		
		buttonData.pressed = false
		self:AnimateRelease(buttonData)
		
		if behavior == "toggle" then
			-- Toggle behavior: flip state on release
			buttonData.active = not buttonData.active
			self:UpdateButtonVisual(buttonData)
			self:FireCallback(buttonData.def.id, buttonData.active and "on" or "off")
			
		elseif behavior == "hold" then
			-- Hold behavior: deactivate on release
			buttonData.active = false
			self:UpdateButtonVisual(buttonData)
			self:FireCallback(buttonData.def.id, "end")
			
		elseif behavior == "tap" then
			-- Tap behavior: fire action on release
			self:FireCallback(buttonData.def.id, "tap")
		end
	end)
end

--[[
	Fire the appropriate callback
]]
function MobileActionBar:FireCallback(buttonId, action)
	if buttonId == "Sprint" then
		if self.onSprintToggle then
			self.onSprintToggle(action == "on")
		end
	elseif buttonId == "Attack" then
		if action == "start" and self.onAttackStart then
			self.onAttackStart()
		elseif action == "end" and self.onAttackEnd then
			self.onAttackEnd()
		end
	elseif buttonId == "Camera" then
		if action == "tap" and self.onCameraMode then
			self.onCameraMode()
		end
	end
end

--[[
	Update button visual based on active state
]]
function MobileActionBar:UpdateButtonVisual(buttonData)
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	if buttonData.active then
		-- Active state: green tint
		TweenService:Create(buttonData.icon, tweenInfo, {
			TextColor3 = UI_CONFIG.ACTIVE_COLOR
		}):Play()
		TweenService:Create(buttonData.stroke, tweenInfo, {
			Color = UI_CONFIG.ACTIVE_COLOR
		}):Play()
	else
		-- Inactive state: white
		TweenService:Create(buttonData.icon, tweenInfo, {
			TextColor3 = UI_CONFIG.ICON_COLOR
		}):Play()
		TweenService:Create(buttonData.stroke, tweenInfo, {
			Color = UI_CONFIG.BORDER_COLOR
		}):Play()
	end
end

--[[
	Animate button press
]]
function MobileActionBar:AnimatePress(buttonData)
	local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	TweenService:Create(buttonData.frame, tweenInfo, {
		Size = UDim2.new(0, UI_CONFIG.BUTTON_SIZE * 0.92, 0, UI_CONFIG.BUTTON_SIZE * 0.92),
		BackgroundTransparency = UI_CONFIG.BG_TRANSPARENCY * 0.5
	}):Play()
end

--[[
	Animate button release
]]
function MobileActionBar:AnimateRelease(buttonData)
	local tweenInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	TweenService:Create(buttonData.frame, tweenInfo, {
		Size = UDim2.new(0, UI_CONFIG.BUTTON_SIZE, 0, UI_CONFIG.BUTTON_SIZE),
		BackgroundTransparency = UI_CONFIG.BG_TRANSPARENCY
	}):Play()
end

--[[
	Set sprint state externally (for syncing with SprintController)
]]
function MobileActionBar:SetSprintActive(isActive)
	local buttonData = self.buttons["Sprint"]
	if buttonData and buttonData.active ~= isActive then
		buttonData.active = isActive
		self:UpdateButtonVisual(buttonData)
	end
end

--[[
	Update camera button icon based on current mode
]]
function MobileActionBar:SetCameraMode(modeName)
	local buttonData = self.buttons["Camera"]
	if not buttonData then return end
	
	-- Update icon based on mode
	local icons = {
		FIRST_PERSON = "👁",
		THIRD_PERSON_LOCK = "🎯",
		THIRD_PERSON_FREE = "📷",
	}
	
	buttonData.icon.Text = icons[modeName] or "📷"
end

--[[
	Initialize the action bar
]]
function MobileActionBar:Initialize()
	self:CreateUI()
	self.enabled = true
	print("MobileActionBar: Initialized with", #BUTTONS, "buttons")
end

--[[
	Enable/disable the action bar
]]
function MobileActionBar:SetEnabled(enabled)
	self.enabled = enabled
	if self.gui then
		self.gui.Enabled = enabled
	end
end

--[[
	Set visibility
]]
function MobileActionBar:SetVisible(visible)
	if self.container then
		self.container.Visible = visible
	end
end

--[[
	Set high contrast mode for accessibility
]]
function MobileActionBar:SetHighContrast(enabled)
	for _, buttonData in pairs(self.buttons) do
		if enabled then
			buttonData.frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			buttonData.stroke.Color = Color3.fromRGB(255, 255, 0)
			buttonData.stroke.Thickness = 4
			buttonData.icon.TextColor3 = Color3.fromRGB(255, 255, 0)
		else
			buttonData.frame.BackgroundColor3 = UI_CONFIG.BG_COLOR
			buttonData.stroke.Color = UI_CONFIG.BORDER_COLOR
			buttonData.stroke.Thickness = UI_CONFIG.BORDER_WIDTH
			buttonData.icon.TextColor3 = UI_CONFIG.ICON_COLOR
		end
	end
end

--[[
	Cleanup
]]
function MobileActionBar:Destroy()
	self.enabled = false
	
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
	
	self.buttons = {}
	print("MobileActionBar: Destroyed")
end

return MobileActionBar
