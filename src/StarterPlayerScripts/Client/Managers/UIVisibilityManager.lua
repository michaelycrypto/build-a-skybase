--[[
	UIVisibilityManager.lua - Central UI Visibility Coordinator
	Manages all UI component visibility through modes
	Handles backdrop effects and component coordination
]]

local UIVisibilityManager = {}

local _ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local GameState = require(script.Parent.GameState)
local UIBackdrop = require(script.Parent.Parent.UI.UIBackdrop)

-- State
local registeredComponents = {}
local currentMode = "gameplay"
local isTransitioning = false

-- Mode definitions
local UI_MODES = {
	gameplay = {
		visibleComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair"},
		hiddenComponents = {"worldsPanel"},
		backdrop = false,
		cursorMode = "gameplay"
	},
	inventory = {
		visibleComponents = {"voxelInventory"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(58, 58, 58),
			overlayTransparency = 0.35,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	},
	chest = {
		visibleComponents = {"chestUI"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(4, 4, 6),
			overlayTransparency = 0.35,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	},
	menu = {
		visibleComponents = {"settingsPanel"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(4, 4, 6),
			overlayTransparency = 0.4,
			displayOrder = 149,
			persist = true
		},
		cursorMode = "ui"
	},
	worlds = {
		visibleComponents = {"worldsPanel"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "voxelInventory"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(58, 58, 58),
			overlayTransparency = 0.35,
			displayOrder = 149,
			persist = true
		},
		cursorMode = "ui"
	},
	minion = {
		visibleComponents = {"minionUI"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "voxelInventory", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(35, 35, 35),
			overlayTransparency = 0.35,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	},
	furnace = {
		visibleComponents = {"furnaceUI"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "voxelInventory", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(58, 58, 58),
			overlayTransparency = 0.35,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	},
	-- Smelting mini-game mode (more immersive, darker)
	smelting = {
		visibleComponents = {"furnaceUI"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "voxelInventory", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(20, 12, 8),
			overlayTransparency = 0.15,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	},
	-- NPC Trade mode (shop/merchant)
	npcTrade = {
		visibleComponents = {"npcTradeUI"},
		hiddenComponents = {"mainHUD", "voxelHotbar", "statusBarsHUD", "crosshair", "voxelInventory", "worldsPanel"},
		backdrop = true,
		backdropConfig = {
			overlay = true,
			overlayColor = Color3.fromRGB(58, 58, 58),
			overlayTransparency = 0.35,
			displayOrder = 99,
			persist = true
		},
		cursorMode = "ui"
	}
}

--[[
	Cursor Control Architecture (Streamlined):

	UIBackdrop is the SINGLE source of truth for mouse state when UI is open:
	- UIBackdrop.Modal = true releases Roblox's mouse lock
	- UIBackdrop RenderStepped continuously enforces MouseBehavior.Default
	- GameState "ui.backdropActive" signals CameraController to freeze/unfreeze

	This eliminates toggle-flip bugs from multiple systems fighting over cursor state.
]]

--[[
	Initialize the UI Visibility Manager
]]
function UIVisibilityManager:Initialize()
	-- Initialize with gameplay mode
	currentMode = "gameplay"
	GameState:Set("ui.mode", currentMode)
	GameState:Set("ui.backdropActive", false)

	-- Listen to mode changes from GameState (for external control)
	GameState:OnPropertyChanged("ui.mode", function(newMode)
		if newMode and newMode ~= currentMode then
			self:SetMode(newMode)
		end
	end)
end

--[[
	Register a UI component
	@param componentId: string - Unique identifier
	@param componentInstance: table - Component instance with Show/Hide methods
	@param config: table - Component configuration
]]
function UIVisibilityManager:RegisterComponent(componentId, componentInstance, config)
	local componentConfig = config or {}

	registeredComponents[componentId] = {
		id = componentId,
		instance = componentInstance,
		showMethod = componentConfig.showMethod or "Show",
		hideMethod = componentConfig.hideMethod or "Hide",
		isOpenMethod = componentConfig.isOpenMethod or "IsOpen",
		priority = componentConfig.priority or 0,
		config = componentConfig
	}
end

--[[
	Unregister a UI component
	@param componentId: string - Component identifier
]]
function UIVisibilityManager:UnregisterComponent(componentId)
	if registeredComponents[componentId] then
		registeredComponents[componentId] = nil
	end
end

--[[
	Set the active UI mode
	@param mode: string - Mode name (gameplay, inventory, chest, menu, etc.)
]]
function UIVisibilityManager:SetMode(mode)
	if not UI_MODES[mode] then
		warn(string.format("UIVisibilityManager: Unknown mode '%s'", mode))
		return
	end

	if isTransitioning then
		warn("UIVisibilityManager: Mode transition already in progress")
		return
	end

	if mode == currentMode then
		-- Already in this mode
		return
	end

	isTransitioning = true
	currentMode = mode

	local modeConfig = UI_MODES[mode]

	-- NOTE: Cursor control removed - UIBackdrop handles it via RenderStepped enforcement

	-- Handle backdrop
	if modeConfig.backdrop then
		UIBackdrop:Show(modeConfig.backdropConfig)
		GameState:Set("ui.backdropActive", true)
	else
		UIBackdrop:Hide()
		GameState:Set("ui.backdropActive", false)
	end

	-- Hide components that should be hidden in this mode
	if modeConfig.hiddenComponents then
		for _, componentId in ipairs(modeConfig.hiddenComponents) do
			self:HideComponent(componentId)
		end
	end

	-- Show components that should be visible in this mode
	if modeConfig.visibleComponents then
		for _, componentId in ipairs(modeConfig.visibleComponents) do
			self:ShowComponent(componentId)
		end
	end

	-- Update GameState
	GameState:Set("ui.mode", mode)
	GameState:Set("ui.visibleComponents", modeConfig.visibleComponents or {})

	isTransitioning = false
end

--[[
	Get the current UI mode
	@return: string - Current mode name
]]
function UIVisibilityManager:GetMode()
	return currentMode
end

--[[
	Show a specific component
	@param componentId: string - Component identifier
]]
function UIVisibilityManager:ShowComponent(componentId)
	local component = registeredComponents[componentId]
	if not component then
		-- Component not registered yet (might not be initialized)
		return
	end

	local instance = component.instance
	local showMethod = component.showMethod

	-- Call the show method if it exists
	if instance and instance[showMethod] then
		pcall(function()
			instance[showMethod](instance)
		end)
	elseif instance and type(instance[showMethod]) == "function" then
		pcall(function()
			instance[showMethod]()
		end)
	end
end

--[[
	Hide a specific component
	@param componentId: string - Component identifier
]]
function UIVisibilityManager:HideComponent(componentId)
	local component = registeredComponents[componentId]
	if not component then
		-- Component not registered yet
		return
	end

	local instance = component.instance
	local hideMethod = component.hideMethod

	-- Call the hide method if it exists
	if instance and instance[hideMethod] then
		pcall(function()
			instance[hideMethod](instance)
		end)
	elseif instance and type(instance[hideMethod]) == "function" then
		pcall(function()
			instance[hideMethod]()
		end)
	end
end

--[[
	Check if a component is currently visible
	@param componentId: string - Component identifier
	@return: boolean
]]
function UIVisibilityManager:IsComponentVisible(componentId)
	local component = registeredComponents[componentId]
	if not component then return false end

	local instance = component.instance
	local isOpenMethod = component.isOpenMethod

	-- Try to call IsOpen method
	if instance and instance[isOpenMethod] then
		local success, result = pcall(function()
			return instance[isOpenMethod](instance)
		end)
		if success then
			return result
		end
	end

	-- Fallback: check if component is in current mode's visible list
	local modeConfig = UI_MODES[currentMode]
	if modeConfig and modeConfig.visibleComponents then
		for _, id in ipairs(modeConfig.visibleComponents) do
			if id == componentId then
				return true
			end
		end
	end

	return false
end

--[[
	Get all registered components
	@return: table
]]
function UIVisibilityManager:GetRegisteredComponents()
	local components = {}
	for id, component in pairs(registeredComponents) do
		components[id] = {
			id = component.id,
			priority = component.priority,
			config = component.config
		}
	end
	return components
end

--[[
	Get mode configuration
	@param mode: string - Mode name
	@return: table or nil
]]
function UIVisibilityManager:GetModeConfig(mode)
	return UI_MODES[mode]
end

--[[
	Check if currently transitioning between modes
	@return: boolean
]]
function UIVisibilityManager:IsTransitioning()
	return isTransitioning
end

--[[
	Force hide all components (emergency cleanup)
]]
function UIVisibilityManager:HideAll()
	print("UIVisibilityManager: Hiding all components")

	for componentId, _ in pairs(registeredComponents) do
		self:HideComponent(componentId)
	end

	UIBackdrop:Hide()
	GameState:Set("ui.backdropActive", false)
end

--[[
	Cleanup (for debugging/reloading)
]]
function UIVisibilityManager:Cleanup()
	self:HideAll()
	registeredComponents = {}
	currentMode = "gameplay"
	isTransitioning = false

	print("UIVisibilityManager: Cleaned up")
end

return UIVisibilityManager

