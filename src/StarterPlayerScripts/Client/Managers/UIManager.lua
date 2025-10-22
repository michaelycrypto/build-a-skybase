--[[
	UIManager.lua - Responsive UI and Viewport Management System
	Handles responsive design, viewport changes, and device-specific optimizations
	Note: Panel/screen management moved to PanelManager.lua for better separation of concerns
--]]

local UIManager = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

-- Import dependencies
local GameState = require(script.Parent.GameState)

-- Services
local player = Players.LocalPlayer

-- State
local currentDeviceType = "Desktop"
local currentViewport = {size = Vector2.new(1920, 1080), aspectRatio = 1.777}

--[[
	Initialize the UI Manager for responsive design
--]]
function UIManager:Initialize()
	print("UIManager: Initializing responsive UI system")

	-- Connect to mobile/console input changes
	UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		self:HandleInputTypeChange(lastInputType)
	end)

	-- Handle viewport changes for responsive design
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:HandleViewportChange()
	end)

	-- Initialize responsive settings
	self:HandleViewportChange()

	print("UIManager: Responsive system ready")
end

--[[
	Handle input type changes for responsive design
--]]
function UIManager:HandleInputTypeChange(inputType)
	-- Adjust UI for different input methods
	if inputType == Enum.UserInputType.Touch then
		-- Mobile optimizations
		currentDeviceType = "Mobile"
		print("UIManager: Switched to touch input mode")
	elseif inputType == Enum.UserInputType.MouseButton1 then
		-- Desktop optimizations
		currentDeviceType = "Desktop"
		print("UIManager: Switched to mouse input mode")
	elseif inputType == Enum.UserInputType.Gamepad1 then
		-- Console optimizations
		currentDeviceType = "Console"
		print("UIManager: Switched to gamepad input mode")
	end

	-- Update GameState with device type
	GameState:Set("ui.deviceType", currentDeviceType)
end

--[[
	Handle viewport size changes
--]]
function UIManager:HandleViewportChange()
	local viewportSize = workspace.CurrentCamera.ViewportSize
	local aspectRatio = viewportSize.X / viewportSize.Y

	-- Determine device type based on screen size and input capabilities
	local deviceType = "Desktop"
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		deviceType = "Mobile"
	elseif UserInputService.GamepadEnabled then
		deviceType = "Console"
	end

	-- Update current viewport
	currentViewport = {
		size = viewportSize,
		aspectRatio = aspectRatio
	}
	currentDeviceType = deviceType

	-- Update responsive settings in GameState
	GameState:Set("ui.viewport", {
		size = viewportSize,
		aspectRatio = aspectRatio,
		deviceType = deviceType
	})

	print("UIManager: Viewport updated -", deviceType, viewportSize.X .. "x" .. viewportSize.Y)
end

--[[
	Get current device type
--]]
function UIManager:GetDeviceType()
	return currentDeviceType
end

--[[
	Get current viewport information
--]]
function UIManager:GetViewport()
	return currentViewport
end

--[[
	Check if device is mobile
--]]
function UIManager:IsMobile()
	return currentDeviceType == "Mobile"
end

--[[
	Check if device is console
--]]
function UIManager:IsConsole()
	return currentDeviceType == "Console"
end

--[[
	Check if device is desktop
--]]
function UIManager:IsDesktop()
	return currentDeviceType == "Desktop"
end

--[[
	Get recommended UI scale based on device
--]]
function UIManager:GetRecommendedUIScale()
	if self:IsMobile() then
		return 1.2 -- Larger UI for touch
	elseif self:IsConsole() then
		return 1.1 -- Slightly larger for TV viewing distance
	else
		return 1.0 -- Standard desktop scale
	end
end

--[[
	Get safe area insets for mobile devices
--]]
function UIManager:GetSafeAreaInsets()
	local topInset = GuiService:GetGuiInset().Y
	return {
		top = topInset,
		bottom = 0, -- Can be expanded for devices with bottom notches
		left = 0,
		right = 0
	}
end

--[[
	Cleanup function
--]]
function UIManager:Cleanup()
	print("UIManager: Cleanup complete")
end

return UIManager