--[[
	BaseButton.lua - Base class for all button types
	Provides common functionality and abstract methods for button implementations
--]]

local BaseButton = {}
BaseButton.__index = BaseButton

-- Services
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local SoundManager = require(script.Parent.Parent.SoundManager)

-- Color variant configurations
local COLOR_VARIANTS = {
	primary = {
		button = Config.UI_SETTINGS.colors.semantic.button.primary or Config.UI_SETTINGS.colors.accent,
		border = Config.UI_SETTINGS.colors.semantic.borders.default,
		text = Config.UI_SETTINGS.colors.text,
		textStroke = Config.UI_SETTINGS.colors.semantic.borders.default
	},
	success = {
		button = Color3.fromRGB(50, 200, 50),   -- Green
		border = Color3.fromRGB(0, 80, 0),      -- Dark green
		text = Color3.fromRGB(255, 255, 255),   -- White
		textStroke = Color3.fromRGB(0, 80, 0)   -- Dark green
	},
	warning = {
		button = Color3.fromRGB(255, 193, 7),   -- Yellow/Amber
		border = Color3.fromRGB(184, 134, 11),  -- Dark yellow
		text = Color3.fromRGB(0, 0, 0),         -- Black
		textStroke = Color3.fromRGB(184, 134, 11) -- Dark yellow
	},
	danger = {
		button = Color3.fromRGB(220, 53, 69),   -- Red
		border = Color3.fromRGB(139, 69, 19),   -- Dark red
		text = Color3.fromRGB(255, 255, 255),   -- White
		textStroke = Color3.fromRGB(139, 69, 19) -- Dark red
	},
	info = {
		button = Color3.fromRGB(0, 123, 255),   -- Blue
		border = Color3.fromRGB(0, 86, 179),    -- Dark blue
		text = Color3.fromRGB(255, 255, 255),   -- White
		textStroke = Color3.fromRGB(0, 86, 179) -- Dark blue
	},
	secondary = {
		button = Color3.fromRGB(108, 117, 125), -- Gray
		border = Color3.fromRGB(73, 80, 87),    -- Dark gray
		text = Color3.fromRGB(255, 255, 255),   -- White
		textStroke = Color3.fromRGB(73, 80, 87) -- Dark gray
	}
}

-- Component configurations (shared with UIComponents)
local COMPONENT_CONFIGS = {
	button = {
		sizes = {
			compact = {width = 100, height = 35},
			small = {width = 80, height = 36},
			medium = {width = 120, height = 48},
			large = {width = 140, height = 56}
		},
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md,
		borderOffset = 2
	}
}

--[[
	Create a new BaseButton instance
	@param config: table - Button configuration
	@return: BaseButton instance
--]]
function BaseButton.new(config)
	local self = setmetatable({}, BaseButton)
	self:Initialize(config)
	return self
end

--[[
	Initialize the button with configuration
	@param config: table - Button configuration
--]]
function BaseButton:Initialize(config)
	-- Store configuration
	self.config = config or {}
	self.size = self.config.size or "medium"
	self.parent = self.config.parent
	self.callback = self.config.callback
	self.enabled = self.config.enabled ~= false
	self.name = self.config.name or "Button"
	self.position = self.config.position
	self.anchorPoint = self.config.anchorPoint
	self.variant = self.config.variant or self.config.color or "primary"

	-- Get size configuration
	local sizeConfig = COMPONENT_CONFIGS.button.sizes[self.size] or COMPONENT_CONFIGS.button.sizes.medium
	self.width = sizeConfig.width
	self.height = sizeConfig.height

	-- Initialize UI elements
	self.borderFrame = nil
	self.button = nil
	self.corners = {}

	-- Animation state
	self.originalColors = {}
	self.currentTweens = {}

	-- Create the button UI
	self:CreateUI()

	-- Setup events and animations (virtual method - can be overridden by subclasses)
	self:SetupEvents()

	-- Apply initial styling
	self:ApplyStyling()
end

--[[
	Create the button UI elements (to be implemented by subclasses)
--]]
function BaseButton:CreateUI()
	-- Abstract method - must be implemented by subclasses
	error("CreateUI must be implemented by subclass")
end

--[[
	Setup common events and animations
--]]
function BaseButton:SetupEvents()
	if not self.button then
		warn("BaseButton: No button element found for event setup")
		return
	end

	-- Disable default button behavior
	self.button.AutoButtonColor = false

	-- Setup click callback
	if self.callback then
		self.button.MouseButton1Click:Connect(function()
			if self.enabled then
				self:PlayClickSound()
				self.callback()
			end
		end)
	end

	-- Setup hover effects
	self:SetupHoverEffects()
end

--[[
	Setup hover effects (can be overridden by subclasses)
--]]
function BaseButton:SetupHoverEffects()
	if not self.button then return end

	-- Mouse enter
	self.button.MouseEnter:Connect(function()
		if self.enabled then
			self:PlayHoverSound()
			self:OnMouseEnter()
		end
	end)

	-- Mouse leave
	self.button.MouseLeave:Connect(function()
		if self.enabled then
			self:OnMouseLeave()
		end
	end)
end

--[[
	Handle mouse enter (can be overridden by subclasses)
--]]
function BaseButton:OnMouseEnter()
	-- Default: subtle transparency change
	if self.button then
		self:AnimateProperty(self.button, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.subtle)
	end
end

--[[
	Handle mouse leave (can be overridden by subclasses)
--]]
function BaseButton:OnMouseLeave()
	-- Default: restore original transparency
	if self.button then
		self:AnimateProperty(self.button, "BackgroundTransparency",
			Config.UI_SETTINGS.designSystem.transparency.light)
	end
end

--[[
	Apply initial styling (can be overridden by subclasses)
--]]
function BaseButton:ApplyStyling()
	-- Store original colors for animations
	if self.button then
		self.originalColors.button = self.button.BackgroundColor3
		self.originalColors.buttonTransparency = self.button.BackgroundTransparency
	end

	if self.borderFrame then
		self.originalColors.border = self.borderFrame.BackgroundColor3
		self.originalColors.borderTransparency = self.borderFrame.BackgroundTransparency
	end
end

--[[
	Animate a property with consistent tween settings
	@param target: Instance - Target instance
	@param property: string - Property name
	@param value: any - Target value
--]]
function BaseButton:AnimateProperty(target, property, value)
	if not target then return end

	-- Cancel any existing tween for this property
	local tweenKey = tostring(target) .. "_" .. property
	if self.currentTweens[tweenKey] then
		self.currentTweens[tweenKey]:Cancel()
	end

	-- Create new tween
	local tweenInfo = TweenInfo.new(
		Config.UI_SETTINGS.designSystem.animation.duration.normal,
		Config.UI_SETTINGS.designSystem.animation.easing.ease,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(target, tweenInfo, {
		[property] = value
	})

	-- Store and play tween
	self.currentTweens[tweenKey] = tween
	tween:Play()

	-- Clean up when complete
	tween.Completed:Connect(function()
		self.currentTweens[tweenKey] = nil
	end)
end

--[[
	Play hover sound effect
--]]
function BaseButton:PlayHoverSound()
	if SoundManager then
		SoundManager:PlaySFX("buttonHover")
	end
end

--[[
	Play click sound effect
--]]
function BaseButton:PlayClickSound()
	if SoundManager then
		SoundManager:PlaySFX("buttonClick")
	end
end

--[[
	Set button enabled state
	@param enabled: boolean - Whether button is enabled
--]]
function BaseButton:SetEnabled(enabled)
	self.enabled = enabled
	if self.button then
		self.button.Active = enabled
		-- Update transparency based on state
		local transparency = enabled and
			Config.UI_SETTINGS.designSystem.transparency.light or
			Config.UI_SETTINGS.designSystem.transparency.backdrop
		self.button.BackgroundTransparency = transparency
	end
end


--[[
	Set button text
	@param text: string - Button text
--]]
function BaseButton:SetText(text)
	if self.button then
		self.button.Text = text
	end
end

--[[
	Get color variant configuration
	@param variant: string - Color variant name
	@return: table - Color configuration
--]]
function BaseButton:GetColorVariant(variant)
	return COLOR_VARIANTS[variant] or COLOR_VARIANTS.primary
end

--[[
	Set button variant (success, warning, danger, info, primary, secondary)
	@param variant: string - Color variant
--]]
function BaseButton:SetVariant(variant)
	self.variant = variant
	local colorConfig = self:GetColorVariant(variant)

	-- Apply colors
	self:SetColor(colorConfig.button)
	self:SetBorderColor(colorConfig.border)
	self:SetTextColor(colorConfig.text)
	self:SetTextStrokeColor(colorConfig.textStroke)
end

--[[
	Set button color
	@param color: Color3 - Button color
--]]
function BaseButton:SetColor(color)
	if self.button then
		self.button.BackgroundColor3 = color
		self.originalColors.button = color
	end
end

--[[
	Set border color
	@param color: Color3 - Border color
--]]
function BaseButton:SetBorderColor(color)
	if self.borderFrame then
		self.borderFrame.BackgroundColor3 = color
		self.originalColors.border = color
	end
end

--[[
	Set text color
	@param color: Color3 - Text color
--]]
function BaseButton:SetTextColor(color)
	if self.button then
		self.button.TextColor3 = color
	end
end

--[[
	Set text stroke color
	@param color: Color3 - Text stroke color
--]]
function BaseButton:SetTextStrokeColor(color)
	-- This will be implemented by subclasses that have text strokes
end

--[[
	Set button position
	@param position: UDim2 - Button position
--]]
function BaseButton:SetPosition(position)
	if self.borderFrame then
		self.borderFrame.Position = position
	elseif self.button then
		self.button.Position = position
	end
end

--[[
	Set button size
	@param size: UDim2 - Button size
--]]
function BaseButton:SetSize(size)
	if self.borderFrame then
		self.borderFrame.Size = size
	elseif self.button then
		self.button.Size = size
	end
end

--[[
	Get button size configuration
	@param size: string - Size name
	@return: table - Size configuration
--]]
function BaseButton:GetSizeConfig(size)
	return COMPONENT_CONFIGS.button.sizes[size] or COMPONENT_CONFIGS.button.sizes.medium
end

--[[
	Create a corner radius for an element
	@param element: Instance - Target element
	@param radius: number - Corner radius
--]]
function BaseButton:CreateCorner(element, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or COMPONENT_CONFIGS.button.borderRadius)
	corner.Parent = element
	table.insert(self.corners, corner)
	return corner
end

--[[
	Clean up all tweens
--]]
function BaseButton:CleanupTweens()
	for _, tween in pairs(self.currentTweens) do
		if tween then
			tween:Cancel()
		end
	end
	self.currentTweens = {}
end

--[[
	Destroy the button and clean up resources
--]]
function BaseButton:Destroy()
	-- Clean up tweens
	self:CleanupTweens()

	-- Destroy UI elements
	if self.borderFrame then
		self.borderFrame:Destroy()
	elseif self.button then
		self.button:Destroy()
	end

	-- Clear references
	self.borderFrame = nil
	self.button = nil
	self.corners = {}
	self.originalColors = {}
end

return BaseButton
