--[[
	ButtonExamples.lua - Examples of how to use the new OOP button system
	This file demonstrates the usage of different button types and color variants
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ButtonFactory = require(script.Parent.ButtonFactory)
local Config = require(ReplicatedStorage.Shared.Config)

local ButtonExamples = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

--[[
	Create example buttons showing different types and variants
	@param parent: Instance - Parent container for buttons
--]]
function ButtonExamples:CreateExamples(parent)
	-- Create a container for examples
	local container = Instance.new("Frame")
	container.Name = "ButtonExamples"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Create layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = container

	-- Example 1: Action Buttons with different variants
	self:CreateActionButtonExamples(container)

	-- Example 2: Buy Buttons with different variants
	self:CreateBuyButtonExamples(container)

	-- Example 3: Panel Buttons with different variants
	self:CreatePanelButtonExamples(container)
end

--[[
	Create action button examples
--]]
function ButtonExamples:CreateActionButtonExamples(parent)
	-- Create section header
	local header = Instance.new("TextLabel")
	header.Name = "ActionButtonHeader"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Text = "Action Buttons"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 18
	header.Font = BOLD_FONT
	header.TextXAlignment = Enum.TextXAlignment.Center
	header.LayoutOrder = 1
	header.Parent = parent

	-- Create button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "ActionButtonContainer"
	buttonContainer.Size = UDim2.new(1, 0, 0, 50)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.LayoutOrder = 2
	buttonContainer.Parent = parent

	-- Create horizontal layout for buttons
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Padding = UDim.new(0, 10)
	buttonLayout.Parent = buttonContainer

	-- Create different variant buttons
	local variants = {"primary", "success", "warning", "danger", "info", "secondary"}

	for i, variant in ipairs(variants) do
		local button = ButtonFactory:CreateActionButton({
			text = variant:gsub("^%l", string.upper), -- Capitalize first letter
			variant = variant,
			parent = buttonContainer,
			callback = function()
				print("Clicked " .. variant .. " button!")
			end
		})
	end
end

--[[
	Create buy button examples
--]]
function ButtonExamples:CreateBuyButtonExamples(parent)
	-- Create section header
	local header = Instance.new("TextLabel")
	header.Name = "BuyButtonHeader"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Text = "Buy Buttons"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 18
	header.Font = BOLD_FONT
	header.TextXAlignment = Enum.TextXAlignment.Center
	header.LayoutOrder = 3
	header.Parent = parent

	-- Create button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "BuyButtonContainer"
	buttonContainer.Size = UDim2.new(1, 0, 0, 50)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.LayoutOrder = 4
	buttonContainer.Parent = parent

	-- Create horizontal layout for buttons
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Padding = UDim.new(0, 10)
	buttonLayout.Parent = buttonContainer

	-- Create different variant buy buttons
	local buyVariants = {
		{amount = 100, currency = "coins", variant = "success"},
		{amount = 50, currency = "gems", variant = "info"},
		{amount = 200, currency = "coins", variant = "warning"},
		{amount = 75, currency = "gems", variant = "danger"}
	}

	for i, config in ipairs(buyVariants) do
		local button = ButtonFactory:CreateBuyButton({
			amount = config.amount,
			currency = config.currency,
			variant = config.variant,
			parent = buttonContainer,
			callback = function()
				print("Purchasing " .. config.amount .. " " .. config.currency .. "!")
			end
		})
	end
end

--[[
	Create panel button examples
--]]
function ButtonExamples:CreatePanelButtonExamples(parent)
	-- Create section header
	local header = Instance.new("TextLabel")
	header.Name = "PanelButtonHeader"
	header.Size = UDim2.new(1, 0, 0, 30)
	header.BackgroundTransparency = 1
	header.Text = "Panel Buttons"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 18
	header.Font = BOLD_FONT
	header.TextXAlignment = Enum.TextXAlignment.Center
	header.LayoutOrder = 5
	header.Parent = parent

	-- Create button container
	local buttonContainer = Instance.new("Frame")
	buttonContainer.Name = "PanelButtonContainer"
	buttonContainer.Size = UDim2.new(1, 0, 0, 200)
	buttonContainer.BackgroundTransparency = 1
	buttonContainer.LayoutOrder = 6
	buttonContainer.Parent = parent

	-- Create vertical layout for panel buttons
	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.FillDirection = Enum.FillDirection.Vertical
	buttonLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	buttonLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonLayout.Padding = UDim.new(0, 5)
	buttonLayout.Parent = buttonContainer

	-- Create different variant panel buttons
	local panelVariants = {
		{text = "Save Changes", variant = "success"},
		{text = "Discard Changes", variant = "danger"},
		{text = "Show Info", variant = "info"},
		{text = "Warning Action", variant = "warning"}
	}

	for i, config in ipairs(panelVariants) do
		-- Create container for each button
		local buttonFrame = Instance.new("Frame")
		buttonFrame.Name = "ButtonFrame" .. i
		buttonFrame.Size = UDim2.new(0.8, 0, 0, 40)
		buttonFrame.BackgroundTransparency = 1
		buttonFrame.LayoutOrder = i
		buttonFrame.Parent = buttonContainer

		local button = ButtonFactory:CreatePanelButton({
			text = config.text,
			variant = config.variant,
			parent = buttonFrame,
			callback = function()
				print("Panel button clicked: " .. config.text)
			end
		})
	end
end

--[[
	Demonstrate dynamic button state changes
--]]
function ButtonExamples:CreateDynamicButtonExample(parent)
	-- Create a container
	local container = Instance.new("Frame")
	container.Name = "DynamicButtonExample"
	container.Size = UDim2.new(1, 0, 0, 100)
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Create a buy button that changes state
	local buyButton = ButtonFactory:CreateBuyButton({
		amount = 100,
		currency = "coins",
		variant = "success",
		parent = container,
		callback = function()
			print("Purchase successful!")
		end
	})

	-- Create control buttons to change the buy button state
	local controlContainer = Instance.new("Frame")
	controlContainer.Name = "ControlContainer"
	controlContainer.Size = UDim2.new(1, 0, 0, 50)
	controlContainer.BackgroundTransparency = 1
	controlContainer.Parent = container

	local controlLayout = Instance.new("UIListLayout")
	controlLayout.FillDirection = Enum.FillDirection.Horizontal
	controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlLayout.Padding = UDim.new(0, 5)
	controlLayout.Parent = controlContainer

	-- Create state control buttons
	local states = {"available", "cannot_afford", "out_of_stock"}

	for i, state in ipairs(states) do
		local controlButton = ButtonFactory:CreateActionButton({
			text = state:gsub("_", " "):gsub("^%l", string.upper),
			variant = "secondary",
			size = "small",
			parent = controlContainer,
			callback = function()
				buyButton:SetState(state)
				print("Buy button state changed to: " .. state)
			end
		})
	end
end

return ButtonExamples
