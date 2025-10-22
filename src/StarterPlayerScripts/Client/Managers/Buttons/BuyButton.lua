--[[
	BuyButton.lua - Buy button implementation extending BaseButton
	Handles purchase buttons with currency icons and amount display
--]]

local BaseButton = require(script.Parent.BaseButton)
local BuyButton = {}
BuyButton.__index = BuyButton
setmetatable(BuyButton, BaseButton)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local IconManager = require(script.Parent.Parent.IconManager)

--[[
	Create a new BuyButton instance
	@param config: table - Button configuration
	@return: BuyButton instance
--]]
function BuyButton.new(config)
	local self = setmetatable({}, BuyButton)
	self:Initialize(config)
	return self
end

--[[
	Create the buy button UI elements
--]]
function BuyButton:CreateUI()
	local currency = self.config.currency or "coins"
	local amount = self.config.amount or 0

	-- Get colors from variant configuration
	local colorConfig = self:GetColorVariant(self.variant)
	local buttonColor = colorConfig.button
	local borderColor = colorConfig.border

	-- Create border frame
	self.borderFrame = Instance.new("Frame")
	self.borderFrame.Name = self.name .. "Border"
	self.borderFrame.Size = UDim2.new(0, self.width + 4, 0, self.height + 4) -- 2px border on all sides
	self.borderFrame.Position = self.position and UDim2.new(self.position.X.Scale, self.position.X.Offset - 2,
		self.position.Y.Scale, self.position.Y.Offset - 2) or UDim2.new(0, -2, 0, -2)
	self.borderFrame.BackgroundColor3 = borderColor
	self.borderFrame.BorderSizePixel = 0
	self.borderFrame.Parent = self.parent

	-- Create border corner
	local borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md
	self:CreateCorner(self.borderFrame, borderRadius + 3)

	-- Create main button
	self.button = Instance.new("TextButton")
	self.button.Name = self.name
	self.button.Size = UDim2.new(0, self.width, 0, self.height)
	self.button.Position = UDim2.new(0, 2, 0, 2) -- Offset by border thickness
	self.button.BackgroundColor3 = buttonColor
	self.button.BackgroundTransparency = self.enabled and
		Config.UI_SETTINGS.designSystem.transparency.light or
		Config.UI_SETTINGS.designSystem.transparency.backdrop
	self.button.Text = "" -- No text, we'll use icons and labels
	self.button.BorderSizePixel = 0
	self.button.Active = self.enabled
	self.button.AutoButtonColor = false
	self.button.Parent = self.borderFrame

	-- Create button corner
	self:CreateCorner(self.button, borderRadius + 2)

	-- Create content container
	self.contentContainer = Instance.new("Frame")
	self.contentContainer.Name = "ContentContainer"
	self.contentContainer.Size = UDim2.new(1, 0, 1, 0)
	self.contentContainer.BackgroundTransparency = 1
	self.contentContainer.Parent = self.button

	-- Create horizontal layout
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.xs)
	contentLayout.Parent = self.contentContainer

	-- Create currency icon
	self.currencyIcon = IconManager:CreateIcon(self.contentContainer, "Currency",
		currency == "coins" and "Cash" or "Gem", {
			size = UDim2.new(0, 25, 0, 20),
			layoutOrder = 1
		})

	-- Create amount label
	self.amountLabel = Instance.new("TextLabel")
	self.amountLabel.Name = "AmountLabel"
	self.amountLabel.Size = UDim2.new(0, 0, 0, 1)
	self.amountLabel.AutomaticSize = Enum.AutomaticSize.X
	self.amountLabel.BackgroundTransparency = 1
	self.amountLabel.Text = tostring(amount)
	self.amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text
	self.amountLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.large
	self.amountLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	self.amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.amountLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.amountLabel.LayoutOrder = 2
	self.amountLabel.Parent = self.contentContainer

	-- Create text stroke
	self.textStroke = Instance.new("UIStroke")
	self.textStroke.Thickness = 2
	self.textStroke.Color = colorConfig.textStroke
	self.textStroke.Parent = self.amountLabel

	-- Store original values
	self.originalTransparency = self.enabled and
		Config.UI_SETTINGS.designSystem.transparency.light or
		Config.UI_SETTINGS.designSystem.transparency.backdrop
	self.originalColor = buttonColor
	self.isAvailable = true
	self.originalBorderColor = borderColor
end

--[[
	Override SetupEvents to handle BuyButton-specific availability logic
	This completely replaces BaseButton's SetupEvents to avoid duplicate event handlers
--]]
function BuyButton:SetupEvents()
	if not self.button then
		warn("BuyButton: No button element found for event setup")
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

	-- Setup BuyButton-specific hover effects with availability check
	self:SetupBuyButtonHoverEffects()

	-- NOTE: We don't call BaseButton:SetupEvents() to avoid duplicate event handlers
end

--[[
	Setup BuyButton-specific hover effects that respect availability
--]]
function BuyButton:SetupBuyButtonHoverEffects()
	if not self.button then return end

	-- Mouse enter - only apply hover effects if available
	self.button.MouseEnter:Connect(function()
		if self.enabled and self.isAvailable then
			self:PlayHoverSound()
			self:OnMouseEnter()
		end
	end)

	-- Mouse leave - only apply hover effects if available
	self.button.MouseLeave:Connect(function()
		if self.enabled and self.isAvailable then
			self:OnMouseLeave()
		end
	end)
end

--[[
	Override hover effects for buy buttons
--]]
function BuyButton:OnMouseEnter()
	if self.isAvailable then
		-- Get current variant colors to determine hover effect
		local colorConfig = self:GetColorVariant(self.variant)

		local hoverBackgroundColor, hoverBorderColor

		-- Determine hover colors based on variant
		if self.variant == "success" then
			-- Dark green hover effect for success buttons (5% lighter)
			hoverBackgroundColor = Color3.fromRGB(37, 168, 37)  -- 5% lighter than RGB(35, 160, 35)
			hoverBorderColor = Color3.fromRGB(0, 63, 0)         -- 5% lighter than RGB(0, 60, 0)
		elseif self.variant == "danger" then
			-- Dark red hover effect for danger buttons (30% lighter)
			hoverBackgroundColor = Color3.fromRGB(234, 46, 65)  -- 30% lighter than RGB(180, 35, 50)
			hoverBorderColor = Color3.fromRGB(130, 59, 13)      -- 30% lighter than RGB(100, 45, 10)
		elseif self.variant == "warning" then
			-- Dark yellow hover effect for warning buttons (15% lighter border)
			hoverBackgroundColor = Color3.fromRGB(200, 150, 0)  -- Darker version of RGB(255, 193, 7)
			hoverBorderColor = Color3.fromRGB(161, 115, 6)      -- 15% lighter than RGB(140, 100, 5)
		elseif self.variant == "info" then
			-- Dark blue hover effect for info buttons (15% lighter border)
			hoverBackgroundColor = Color3.fromRGB(0, 90, 200)   -- Darker version of RGB(0, 123, 255)
			hoverBorderColor = Color3.fromRGB(0, 69, 161)       -- 15% lighter than RGB(0, 60, 140)
		elseif self.variant == "secondary" then
			-- Dark gray hover effect for secondary buttons (15% lighter border)
			hoverBackgroundColor = Color3.fromRGB(85, 95, 105)  -- Darker version of RGB(108, 117, 125)
			hoverBorderColor = Color3.fromRGB(63, 75, 86)       -- 15% lighter than RGB(55, 65, 75)
		else
			-- Default hover effect for primary buttons (15% lighter border)
			hoverBackgroundColor = Color3.fromRGB(100, 100, 100)
			hoverBorderColor = Color3.fromRGB(69, 69, 69)       -- 15% lighter than RGB(60, 60, 60)
		end

		self:AnimateProperty(self.button, "BackgroundColor3", hoverBackgroundColor)
		self:AnimateProperty(self.borderFrame, "BackgroundColor3", hoverBorderColor)
	end
end

--[[
	Override mouse leave for buy buttons
--]]
function BuyButton:OnMouseLeave()
	if self.isAvailable then
		-- Get current variant colors instead of stored original colors
		local colorConfig = self:GetColorVariant(self.variant)
		self:AnimateProperty(self.button, "BackgroundColor3", colorConfig.button)
		self:AnimateProperty(self.borderFrame, "BackgroundColor3", colorConfig.border)
	end
end

--[[
	Set button state (available, cannot_afford, out_of_stock)
	@param state: string - Button state
--]]
function BuyButton:SetState(state)
	local stateConfig = self:GetStateConfig(state)
	if stateConfig then
		self:ApplyStateConfig(stateConfig)
	end
end

--[[
	Get state configuration
	@param state: string - Button state
	@return: table - State configuration
--]]
function BuyButton:GetStateConfig(state)
	local stateConfigs = {
		available = {
			color = Color3.fromRGB(53, 210, 53),  -- 5% lighter than RGB(50, 200, 50)
			borderColor = Color3.fromRGB(0, 84, 0),  -- 5% lighter than RGB(0, 80, 0)
			textStrokeColor = Color3.fromRGB(0, 84, 0),  -- 5% lighter than RGB(0, 80, 0)
			enabled = true,
			hoverEffects = true
		},
		cannot_afford = {
			color = Color3.fromRGB(255, 131, 131),  -- 30% lighter than RGB(214, 101, 101), capped at 255
			borderColor = Color3.fromRGB(161, 83, 83),  -- 30% lighter than RGB(124, 64, 64)
			textStrokeColor = Color3.fromRGB(161, 83, 83),  -- 30% lighter than RGB(124, 64, 64)
			enabled = false,
			hoverEffects = false
		},
		zero_stock = {
			color = Color3.fromRGB(150, 150, 150),  -- Grey color for zero stock
			borderColor = Color3.fromRGB(100, 100, 100),  -- Darker grey border
			textStrokeColor = Color3.fromRGB(100, 100, 100),  -- Darker grey text stroke
			enabled = false,
			hoverEffects = false
		},
		out_of_stock = {
			color = Color3.fromRGB(150, 150, 150),
			borderColor = Color3.fromRGB(100, 100, 100),
			textStrokeColor = Color3.fromRGB(100, 100, 100),
			enabled = false,
			hoverEffects = false
		}
	}

	return stateConfigs[state]
end

--[[
	Apply state configuration
	@param config: table - State configuration
--]]
function BuyButton:ApplyStateConfig(config)
	-- Update colors
	self:SetColor(config.color)
	self:SetBorderColor(config.borderColor)
	self:SetTextStrokeColor(config.textStrokeColor)

	-- Update enabled state
	self:SetEnabled(config.enabled)

	-- Update availability for hover effects
	self.isAvailable = config.hoverEffects
	self.originalColor = config.color
	self.originalBorderColor = config.borderColor
end

--[[
	Set amount display
	@param amount: number - Amount to display
--]]
function BuyButton:SetAmount(amount)
	if self.amountLabel then
		self.amountLabel.Text = tostring(amount)
	end
end

--[[
	Set currency type
	@param currency: string - Currency type
--]]
function BuyButton:SetCurrency(currency)
	if self.currencyIcon then
		IconManager:ApplyIcon(self.currencyIcon, "Currency",
			currency == "coins" and "Cash" or "Gem", {
				size = UDim2.new(0, 25, 0, 20)
			})
	end
end

--[[
	Set text stroke color
	@param color: Color3 - Text stroke color
--]]
function BuyButton:SetTextStrokeColor(color)
	if self.textStroke then
		self.textStroke.Color = color
	end
end

--[[
	Override SetVariant to handle buy button specific logic
	@param variant: string - Color variant
--]]
function BuyButton:SetVariant(variant)
	-- Cancel any active tweens to prevent interference
	self:CleanupTweens()

	-- Call parent method
	BaseButton.SetVariant(self, variant)

	-- Update text stroke color for buy buttons
	local colorConfig = self:GetColorVariant(variant)
	self:SetTextStrokeColor(colorConfig.textStroke)

	-- CRITICAL: Immediately set colors without animation to ensure instant state change
	-- This prevents any lingering animations from overriding the new variant colors
	if self.button then
		self.button.BackgroundColor3 = colorConfig.button
	end
	if self.borderFrame then
		self.borderFrame.BackgroundColor3 = colorConfig.border
	end
end

--[[
	Set availability for hover effects
	@param available: boolean - Whether button is available
--]]
function BuyButton:SetAvailable(available)
	self.isAvailable = available
end

--[[
	Override SetEnabled to handle buy button specific logic
	@param enabled: boolean - Whether button is enabled
--]]
function BuyButton:SetEnabled(enabled)
	self.enabled = enabled
	if self.button then
		self.button.Active = enabled
		local transparency = enabled and
			Config.UI_SETTINGS.designSystem.transparency.light or
			Config.UI_SETTINGS.designSystem.transparency.backdrop
		self.button.BackgroundTransparency = transparency
	end
end

return BuyButton
