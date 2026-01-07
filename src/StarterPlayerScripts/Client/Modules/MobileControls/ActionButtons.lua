--[[
	ActionButtons.lua
	Action button framework for mobile controls

	Features:
	- Static buttons (jump, crouch, sprint)
	- Context-sensitive buttons (interact, use, place)
	- Visual feedback
	- Accessibility support
	- Customizable positions and sizes
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ActionButtons = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
ActionButtons.__index = ActionButtons

-- Button types
local ButtonType = {
	Jump = "Jump",
	Crouch = "Crouch",
	Sprint = "Sprint",
	Interact = "Interact",
	UseItem = "UseItem",
	PlaceBlock = "PlaceBlock",
	Attack = "Attack",
}

function ActionButtons.new()
	local self = setmetatable({}, ActionButtons)

	-- Configuration
	self.buttonSize = 65
	self.buttonOpacity = 0.7
	self.buttonSpacing = 15
	self.toggleMode = false -- false = hold, true = toggle
	self.showLabels = true

	-- State
	self.enabled = false
	self.buttons = {} -- [buttonType] = buttonData
	self.activeButtons = {} -- Currently pressed buttons

	-- UI Elements
	self.gui = nil
	self.container = nil

	-- Callbacks
	self.onButtonPressed = nil
	self.onButtonReleased = nil

	-- Accessibility
	self.highContrast = false
	self.largeButtons = false
	self.hapticFeedback = true

	return self
end

--[[
	Create main UI container
]]
function ActionButtons:CreateContainer(parent)
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "MobileActionButtons"
	self.gui.ResetOnSpawn = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.Parent = parent

	self.container = Instance.new("Frame")
	self.container.Name = "Container"
	self.container.Size = UDim2.new(1, 0, 1, 0)
	self.container.BackgroundTransparency = 1
	self.container.Parent = self.gui
end

--[[
	Create a button
]]
function ActionButtons:CreateButton(buttonType, position, icon, label)
	if self.buttons[buttonType] then
		warn("Button already exists:", buttonType)
		return self.buttons[buttonType]
	end

	-- Button frame
	local button = Instance.new("TextButton")
	button.Name = buttonType .. "Button"
	button.Size = UDim2.new(0, self.buttonSize, 0, self.buttonSize)
	button.Position = position
	button.AnchorPoint = Vector2.new(0.5, 0.5)
	button.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundTransparency = 1 - self.buttonOpacity
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = self.container

	-- Corner rounding
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.2, 0)
	corner.Parent = button

	-- Border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 3
	stroke.Transparency = 0.3
	stroke.Parent = button

	-- Icon (text-based for now, can be replaced with images)
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0.6, 0, 0.6, 0)
	iconLabel.Position = UDim2.new(0.5, 0, 0.35, 0)
	iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon or "●"
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.TextScaled = true
	iconLabel.Font = BOLD_FONT
	iconLabel.Parent = button

	-- Label (optional)
	local labelText = nil
	if self.showLabels and label then
		labelText = Instance.new("TextLabel")
		labelText.Name = "Label"
		labelText.Size = UDim2.new(1, 0, 0.25, 0)
		labelText.Position = UDim2.new(0.5, 0, 0.8, 0)
		labelText.AnchorPoint = Vector2.new(0.5, 0.5)
		labelText.BackgroundTransparency = 1
		labelText.Text = label
		labelText.TextColor3 = Color3.fromRGB(255, 255, 255)
		labelText.TextScaled = true
		labelText.Font = BOLD_FONT
		labelText.TextTransparency = 0.3
		labelText.Parent = button
	end

	-- Store button data
	local buttonData = {
		type = buttonType,
		frame = button,
		icon = iconLabel,
		label = labelText,
		position = position,
		pressed = false,
		visible = true,
		static = true, -- Static buttons are always visible
		touchInput = nil,
	}

	self.buttons[buttonType] = buttonData

	-- Setup input handling
	self:SetupButtonInput(buttonData)

	return buttonData
end

--[[
	Setup input handling for a button
]]
function ActionButtons:SetupButtonInput(buttonData)
	local button = buttonData.frame

	-- Touch began
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:OnButtonPressed(buttonData, input)
		end
	end)

	-- Touch ended
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:OnButtonReleased(buttonData, input)
		end
	end)
end

--[[
	Handle button pressed
]]
function ActionButtons:OnButtonPressed(buttonData, input)
	if not self.enabled then return end

	buttonData.pressed = true
	buttonData.touchInput = input
	self.activeButtons[buttonData.type] = buttonData

	-- Visual feedback
	self:AnimateButtonPress(buttonData)

	-- Haptic feedback
	if self.hapticFeedback then
		-- Roblox doesn't have native haptics yet, but prepare for it
		-- UserInputService:SetHapticMotor(Enum.HapticMotor.Touch, 0.3)
	end

	-- Fire callback
	if self.onButtonPressed then
		self.onButtonPressed(buttonData.type)
	end

	-- Simulate key press for Roblox character controller
	self:SimulateKeyPress(buttonData.type, true)
end

--[[
	Handle button released
]]
function ActionButtons:OnButtonReleased(buttonData, input)
	if not self.enabled then return end

	-- In toggle mode, don't release immediately
	if self.toggleMode then
		buttonData.pressed = not buttonData.pressed
		if buttonData.pressed then
			return
		end
	else
		buttonData.pressed = false
	end

	buttonData.touchInput = nil
	self.activeButtons[buttonData.type] = nil

	-- Visual feedback
	self:AnimateButtonRelease(buttonData)

	-- Fire callback
	if self.onButtonReleased then
		self.onButtonReleased(buttonData.type)
	end

	-- Simulate key release for Roblox character controller
	self:SimulateKeyPress(buttonData.type, false)
end

--[[
	Simulate key press for Roblox native controls
]]
function ActionButtons:SimulateKeyPress(buttonType, pressed)
	-- Map button types to Roblox key codes
	local keyMap = {
		[ButtonType.Jump] = Enum.KeyCode.Space,
		[ButtonType.Crouch] = Enum.KeyCode.LeftControl,
		[ButtonType.Sprint] = Enum.KeyCode.LeftShift,
	}

	local keyCode = keyMap[buttonType]
	if not keyCode then return end

	-- Note: Roblox doesn't allow direct key injection, so we need to
	-- communicate with the character controller through other means
	-- For now, we'll handle this in the main mobile controller

	-- Store state for main controller to read
	if pressed then
		self.activeButtons[buttonType] = true
	else
		self.activeButtons[buttonType] = nil
	end
end

--[[
	Animate button press
]]
function ActionButtons:AnimateButtonPress(buttonData)
	local button = buttonData.frame
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Scale down slightly
	TweenService:Create(button, tweenInfo, {
		Size = UDim2.new(0, self.buttonSize * 0.9, 0, self.buttonSize * 0.9)
	}):Play()

	-- Increase opacity
	TweenService:Create(button, tweenInfo, {
		BackgroundTransparency = 1 - (self.buttonOpacity * 1.3)
	}):Play()

	-- Highlight icon
	if buttonData.icon then
		TweenService:Create(buttonData.icon, tweenInfo, {
			TextTransparency = 0
		}):Play()
	end
end

--[[
	Animate button release
]]
function ActionButtons:AnimateButtonRelease(buttonData)
	local button = buttonData.frame
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Scale back to normal
	TweenService:Create(button, tweenInfo, {
		Size = UDim2.new(0, self.buttonSize, 0, self.buttonSize)
	}):Play()

	-- Reset opacity
	TweenService:Create(button, tweenInfo, {
		BackgroundTransparency = 1 - self.buttonOpacity
	}):Play()

	-- Reset icon
	if buttonData.icon then
		TweenService:Create(buttonData.icon, tweenInfo, {
			TextTransparency = 0.2
		}):Play()
	end
end

--[[
	Initialize action buttons
]]
function ActionButtons:Initialize(parent)
	if not parent then
		parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	self:CreateContainer(parent)

	-- Create default buttons
	self:CreateButton(
		ButtonType.Jump,
		UDim2.new(1, -90, 1, -150),
		"↑",
		"Jump"
	)

	self:CreateButton(
		ButtonType.Crouch,
		UDim2.new(1, -90, 1, -240),
		"↓",
		"Crouch"
	)

	self:CreateButton(
		ButtonType.Sprint,
		UDim2.new(1, -180, 1, -150),
		"⚡",
		"Sprint"
	)

	self.enabled = true

	print("✅ ActionButtons: Initialized with", self:GetButtonCount(), "buttons")
end

--[[
	Show context-sensitive button
]]
function ActionButtons:ShowContextButton(buttonType, position, icon, label)
	-- Check if button already exists
	if self.buttons[buttonType] then
		self:SetButtonVisible(buttonType, true)
		return
	end

	-- Create new context button
	local buttonData = self:CreateButton(buttonType, position, icon, label)
	buttonData.static = false -- Mark as context-sensitive

	-- Fade in animation
	buttonData.frame.BackgroundTransparency = 1
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(buttonData.frame, tweenInfo, {
		BackgroundTransparency = 1 - self.buttonOpacity
	}):Play()
end

--[[
	Hide context-sensitive button
]]
function ActionButtons:HideContextButton(buttonType)
	local buttonData = self.buttons[buttonType]
	if not buttonData or buttonData.static then
		return -- Don't hide static buttons
	end

	-- Fade out and destroy
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(buttonData.frame, tweenInfo, {
		BackgroundTransparency = 1
	})

	tween.Completed:Connect(function()
		if buttonData.frame then
			buttonData.frame:Destroy()
		end
		self.buttons[buttonType] = nil
	end)

	tween:Play()
end

--[[
	Set button visible/hidden
]]
function ActionButtons:SetButtonVisible(buttonType, visible)
	local buttonData = self.buttons[buttonType]
	if not buttonData then return end

	buttonData.visible = visible
	buttonData.frame.Visible = visible
end

--[[
	Set button enabled/disabled
]]
function ActionButtons:SetButtonEnabled(buttonType, enabled)
	local buttonData = self.buttons[buttonType]
	if not buttonData then return end

	buttonData.frame.Active = enabled

	-- Visual feedback for disabled state
	if enabled then
		buttonData.frame.BackgroundTransparency = 1 - self.buttonOpacity
	else
		buttonData.frame.BackgroundTransparency = 0.9
	end
end

--[[
	Check if button is pressed
]]
function ActionButtons:IsButtonPressed(buttonType)
	return self.activeButtons[buttonType] ~= nil
end

--[[
	Get button count
]]
function ActionButtons:GetButtonCount()
	local count = 0
	for _ in pairs(self.buttons) do
		count = count + 1
	end
	return count
end

--[[
	Set button size
]]
function ActionButtons:SetButtonSize(size)
	self.buttonSize = size

	-- Update existing buttons
	for _, buttonData in pairs(self.buttons) do
		buttonData.frame.Size = UDim2.new(0, size, 0, size)
	end
end

--[[
	Set button opacity
]]
function ActionButtons:SetButtonOpacity(opacity)
	self.buttonOpacity = opacity

	-- Update existing buttons
	for _, buttonData in pairs(self.buttons) do
		if not buttonData.pressed then
			buttonData.frame.BackgroundTransparency = 1 - opacity
		end
	end
end

--[[
	Set high contrast mode
]]
function ActionButtons:SetHighContrast(enabled)
	self.highContrast = enabled

	for _, buttonData in pairs(self.buttons) do
		if enabled then
			buttonData.frame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			local stroke = buttonData.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 0)
				stroke.Thickness = 5
			end
			if buttonData.icon then
				buttonData.icon.TextColor3 = Color3.fromRGB(255, 255, 0)
			end
		else
			buttonData.frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = buttonData.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Thickness = 3
			end
			if buttonData.icon then
				buttonData.icon.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end
	end
end

--[[
	Set button position
]]
function ActionButtons:SetButtonPosition(buttonType, position)
	local buttonData = self.buttons[buttonType]
	if not buttonData then return end

	buttonData.position = position
	buttonData.frame.Position = position
end

--[[
	Cleanup
]]
function ActionButtons:Destroy()
	self.enabled = false

	-- Destroy all buttons
	for _, buttonData in pairs(self.buttons) do
		if buttonData.frame then
			buttonData.frame:Destroy()
		end
	end

	self.buttons = {}
	self.activeButtons = {}

	-- Destroy GUI
	if self.gui then
		self.gui:Destroy()
	end

	print("🗑️ ActionButtons: Destroyed")
end

return ActionButtons

