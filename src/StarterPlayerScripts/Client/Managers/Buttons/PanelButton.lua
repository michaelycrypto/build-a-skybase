--[[
	PanelButton.lua - Panel button implementation extending BaseButton
	Handles full-width panel buttons without border frames
--]]

local BaseButton = require(script.Parent.BaseButton)
local PanelButton = {}
PanelButton.__index = PanelButton
setmetatable(PanelButton, BaseButton)

local COMPONENT_CONFIGS = BaseButton.COMPONENT_CONFIGS

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Config = require(ReplicatedStorage.Shared.Config)

--[[
	Create a new PanelButton instance
	@param config: table - Button configuration
	@return: PanelButton instance
--]]
function PanelButton.new(config)
	local self = setmetatable({}, PanelButton)
	self:Initialize(config)
	return self
end

--[[
	Create the panel button UI elements
--]]
function PanelButton:CreateUI()
	local text = self.config.text or "Button"

	-- Get colors from variant configuration
	local colorConfig = self:GetColorVariant(self.variant)
	local buttonColor = colorConfig.button

	-- Create main button (no border frame for panel buttons)
	self.button = Instance.new("TextButton")
	self.button.Name = self.name
	self.button.Size = UDim2.fromScale(1, 1) -- Fill parent container
	self.button.Position = UDim2.fromScale(0, 0)
	self.button.BackgroundColor3 = buttonColor
	self.button.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	self.button.Text = text
	self.button.TextColor3 = self.config.textColor or colorConfig.text
	self.button.TextSize = self.config.textSize or Config.UI_SETTINGS.typography.sizes.headings.h3
	self.button.Font = self.config.font or Config.UI_SETTINGS.typography.fonts.bold
	self.button.BorderSizePixel = 0
	self.button.Parent = self.parent

	-- Create button corner
	self:CreateCorner(self.button, COMPONENT_CONFIGS.button.borderRadius)

	-- For panel buttons, the button itself is the border frame equivalent
	self.borderFrame = self.button
end

--[[
	Override hover effects for panel buttons
--]]
function PanelButton:OnMouseEnter()
	-- Panel buttons use subtle transparency changes
	if self.button then
		self:AnimateProperty(self.button, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.subtle)
	end
end

--[[
	Override mouse leave for panel buttons
--]]
function PanelButton:OnMouseLeave()
	-- Restore original transparency
	if self.button then
		self:AnimateProperty(self.button, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.light)
	end
end

--[[
	Set button text with proper formatting
	@param text: string - Button text
--]]
function PanelButton:SetText(text)
	if self.button then
		self.button.Text = text
	end
end

--[[
	Set button color and update original color for animations
	@param color: Color3 - Button color
--]]
function PanelButton:SetColor(color)
	if self.button then
		self.button.BackgroundColor3 = color
		self.originalColors.button = color
	end
end

--[[
	Override SetBorderColor (panel buttons don't have separate borders)
	@param color: Color3 - Border color (ignored for panel buttons)
--]]
function PanelButton:SetBorderColor(_color)
	-- Panel buttons don't have separate border frames
	-- This method is kept for compatibility but does nothing
end

--[[
	Override SetVariant to handle panel button specific logic
	@param variant: string - Color variant
--]]
function PanelButton:SetVariant(variant)
	-- Call parent method
	BaseButton.SetVariant(self, variant)

	-- Panel buttons don't have text strokes, so we don't need to handle that
end

--[[
	Override SetEnabled to handle panel button specific logic
	@param enabled: boolean - Whether button is enabled
--]]
function PanelButton:SetEnabled(enabled)
	self.enabled = enabled
	if self.button then
		self.button.Active = enabled
		local transparency = enabled and
			Config.UI_SETTINGS.designSystem.transparency.light or
			Config.UI_SETTINGS.designSystem.transparency.backdrop
		self.button.BackgroundTransparency = transparency
	end
end

return PanelButton
