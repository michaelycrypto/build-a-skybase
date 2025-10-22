--[[
	ActionButton.lua - Action button implementation extending BaseButton
	Handles standard action buttons with border frames and hover effects
--]]

local BaseButton = require(script.Parent.BaseButton)
local ActionButton = {}
ActionButton.__index = ActionButton
setmetatable(ActionButton, BaseButton)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Config = require(ReplicatedStorage.Shared.Config)

--[[
	Create a new ActionButton instance
	@param config: table - Button configuration
	@return: ActionButton instance
--]]
function ActionButton.new(config)
	local self = setmetatable({}, ActionButton)
	self:Initialize(config)
	return self
end

--[[
	Create the action button UI elements
--]]
function ActionButton:CreateUI()
	local text = self.config.text or "Button"

	-- Get colors from variant configuration
	local colorConfig = self:GetColorVariant(self.variant)
	local buttonColor = colorConfig.button
	local borderColor = colorConfig.border

	-- Create border frame
	self.borderFrame = Instance.new("Frame")
	self.borderFrame.Name = self.name .. "Frame"
	self.borderFrame.Size = UDim2.new(0, self.width + (COMPONENT_CONFIGS.button.borderOffset * 2),
		0, self.height + (COMPONENT_CONFIGS.button.borderOffset * 2))
	self.borderFrame.Position = self.position or UDim2.new(0, 0, 0, 0)
	self.borderFrame.AnchorPoint = self.anchorPoint or Vector2.new(0, 0)
	self.borderFrame.BackgroundColor3 = borderColor
	self.borderFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy
	self.borderFrame.BorderSizePixel = 0
	self.borderFrame.Parent = self.parent

	-- Create border corner
	self:CreateCorner(self.borderFrame, COMPONENT_CONFIGS.button.borderRadius + 2)

	-- Create main button
	self.button = Instance.new("TextButton")
	self.button.Name = self.name
	self.button.Size = UDim2.new(0, self.width, 0, self.height)
	self.button.Position = UDim2.new(0, COMPONENT_CONFIGS.button.borderOffset,
		0, COMPONENT_CONFIGS.button.borderOffset)
	self.button.BackgroundColor3 = buttonColor
	self.button.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	self.button.Text = text
	self.button.TextColor3 = self.config.textColor or colorConfig.text
	self.button.TextSize = self.config.textSize or Config.UI_SETTINGS.typography.sizes.headings.h3
	self.button.Font = self.config.font or Config.UI_SETTINGS.typography.fonts.bold
	self.button.BorderSizePixel = 0
	self.button.Parent = self.borderFrame

	-- Create button corner
	self:CreateCorner(self.button, COMPONENT_CONFIGS.button.borderRadius)
end

--[[
	Override hover effects for action buttons
--]]
function ActionButton:OnMouseEnter()
	-- Animate border frame transparency for action buttons
	if self.borderFrame then
		self:AnimateProperty(self.borderFrame, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.light)
	end
end

--[[
	Override mouse leave for action buttons
--]]
function ActionButton:OnMouseLeave()
	-- Restore border frame transparency
	if self.borderFrame then
		self:AnimateProperty(self.borderFrame, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.heavy)
	end
end

--[[
	Set button text with proper formatting
	@param text: string - Button text
--]]
function ActionButton:SetText(text)
	if self.button then
		self.button.Text = text
	end
end

--[[
	Set button color and update original color for animations
	@param color: Color3 - Button color
--]]
function ActionButton:SetColor(color)
	if self.button then
		self.button.BackgroundColor3 = color
		self.originalColors.button = color
	end
end

--[[
	Set border color and update original color for animations
	@param color: Color3 - Border color
--]]
function ActionButton:SetBorderColor(color)
	if self.borderFrame then
		self.borderFrame.BackgroundColor3 = color
		self.originalColors.border = color
	end
end

--[[
	Override SetVariant to handle action button specific logic
	@param variant: string - Color variant
--]]
function ActionButton:SetVariant(variant)
	-- Call parent method
	BaseButton.SetVariant(self, variant)

	-- Action buttons don't have text strokes, so we don't need to handle that
end

return ActionButton
