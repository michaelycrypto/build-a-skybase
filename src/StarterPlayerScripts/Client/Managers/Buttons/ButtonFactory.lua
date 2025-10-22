--[[
	ButtonFactory.lua - Factory for creating different types of buttons
	Provides a clean interface for creating buttons with proper OOP structure
--]]

local ButtonFactory = {}

-- Import button classes
local ActionButton = require(script.Parent.ActionButton)
local BuyButton = require(script.Parent.BuyButton)
local PanelButton = require(script.Parent.PanelButton)

--[[
	Create a button of the specified type
	@param buttonType: string - Type of button to create ("action", "buy", "panel")
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateButton(buttonType, config)
	local buttonTypes = {
		action = ActionButton,
		buy = BuyButton,
		panel = PanelButton
	}

	local ButtonClass = buttonTypes[buttonType]
	if not ButtonClass then
		error("Unknown button type: " .. tostring(buttonType))
	end

	return ButtonClass.new(config)
end

--[[
	Create an action button
	@param config: table - Button configuration
	@return: ActionButton instance
--]]
function ButtonFactory:CreateActionButton(config)
	return self:CreateButton("action", config)
end

--[[
	Create a buy button
	@param config: table - Button configuration
	@return: BuyButton instance
--]]
function ButtonFactory:CreateBuyButton(config)
	return self:CreateButton("buy", config)
end

--[[
	Create a panel button
	@param config: table - Button configuration
	@return: PanelButton instance
--]]
function ButtonFactory:CreatePanelButton(config)
	return self:CreateButton("panel", config)
end

--[[
	Create a success button (green)
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateSuccessButton(config)
	config = config or {}
	config.variant = "success"
	return self:CreateActionButton(config)
end

--[[
	Create a warning button (yellow)
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateWarningButton(config)
	config = config or {}
	config.variant = "warning"
	return self:CreateActionButton(config)
end

--[[
	Create a danger button (red)
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateDangerButton(config)
	config = config or {}
	config.variant = "danger"
	return self:CreateActionButton(config)
end

--[[
	Create an info button (blue)
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateInfoButton(config)
	config = config or {}
	config.variant = "info"
	return self:CreateActionButton(config)
end

--[[
	Create a secondary button (gray)
	@param config: table - Button configuration
	@return: Button instance
--]]
function ButtonFactory:CreateSecondaryButton(config)
	config = config or {}
	config.variant = "secondary"
	return self:CreateActionButton(config)
end

--[[
	Create a buy button with success variant (green)
	@param config: table - Button configuration
	@return: BuyButton instance
--]]
function ButtonFactory:CreateSuccessBuyButton(config)
	config = config or {}
	config.variant = "success"
	return self:CreateBuyButton(config)
end

--[[
	Create a buy button with danger variant (red)
	@param config: table - Button configuration
	@return: BuyButton instance
--]]
function ButtonFactory:CreateDangerBuyButton(config)
	config = config or {}
	config.variant = "danger"
	return self:CreateBuyButton(config)
end

--[[
	Get available button types
	@return: table - Array of available button types
--]]
function ButtonFactory:GetAvailableTypes()
	return {"action", "buy", "panel"}
end

--[[
	Get available color variants
	@return: table - Array of available color variants
--]]
function ButtonFactory:GetAvailableVariants()
	return {"primary", "success", "warning", "danger", "info", "secondary"}
end

return ButtonFactory
