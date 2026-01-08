--[[
	UIManager.lua - Responsive UI and Viewport Management System
	Handles responsive design, viewport changes, and device-specific optimizations
	Note: Panel/screen management moved to PanelManager.lua for better separation of concerns
--]]

local UIManager = {}

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

-- Import dependencies
local GameState = require(script.Parent.GameState)
local InputService = require(script.Parent.Parent.Input.InputService)

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- State
local currentDeviceType = "Desktop"
local currentViewport = {size = Vector2.new(1920, 1080), aspectRatio = 1.777}
local worldStatusGui = nil
local worldStatusTitle = nil
local worldStatusSubtitle = nil
local worldStatusOverlayRelease = nil

local STATUS_COPY = {
	loading = {
		title = "Syncing island...",
		body = "Preparing your world data."
	},
	waiting_for_owner = {
		title = "Waiting for world owner",
		body = "Hang tight while the world boots up."
	},
	shutting_down = {
		title = "World paused",
		body = "Server is shutting down safely."
	},
	timeout = {
		title = "Unable to load world",
		body = "Please return to the hub and try again."
	}
}

local function ensureWorldStatusGui()
	if worldStatusGui then
		return
	end

	worldStatusGui = Instance.new("ScreenGui")
	worldStatusGui.Name = "WorldStatusOverlay"
	worldStatusGui.IgnoreGuiInset = true
	worldStatusGui.DisplayOrder = 9999
	worldStatusGui.ResetOnSpawn = false
	worldStatusGui.Enabled = false
	worldStatusGui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
	backdrop.BackgroundTransparency = 0.35
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.Parent = worldStatusGui

	local container = Instance.new("Frame")
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.new(0.5, 0, 0.5, 0)
	container.Size = UDim2.new(0, 380, 0, 160)
	container.BackgroundTransparency = 1
	container.Parent = backdrop

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Vertical
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 10)
	list.Parent = container

	worldStatusTitle = Instance.new("TextLabel")
	worldStatusTitle.Size = UDim2.new(1, -20, 0, 40)
	worldStatusTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	worldStatusTitle.BackgroundTransparency = 1
	worldStatusTitle.Font = Enum.Font.GothamBold
	worldStatusTitle.TextScaled = true
	worldStatusTitle.TextWrapped = true
	worldStatusTitle.Parent = container

	worldStatusSubtitle = Instance.new("TextLabel")
	worldStatusSubtitle.Size = UDim2.new(1, -40, 0, 60)
	worldStatusSubtitle.TextColor3 = Color3.fromRGB(220, 230, 255)
	worldStatusSubtitle.BackgroundTransparency = 1
	worldStatusSubtitle.Font = Enum.Font.Gotham
	worldStatusSubtitle.TextScaled = true
	worldStatusSubtitle.TextWrapped = true
	worldStatusSubtitle.Parent = container
end

--[[
	Initialize the UI Manager for responsive design
--]]
function UIManager:Initialize()
	print("UIManager: Initializing responsive UI system")

	-- Connect to mobile/console input changes
	InputService.LastInputTypeChanged:Connect(function(lastInputType)
		self:HandleInputTypeChange(lastInputType)
	end)

	-- Handle viewport changes for responsive design
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		self:HandleViewportChange()
	end)

	-- Initialize responsive settings
	self:HandleViewportChange()

	GameState:OnPropertyChanged("game.isPlaying", function(isPlaying)
		if isPlaying then
			self:HideWorldStatus()
		else
			self:_applyWorldStatus(GameState:GetWorldStatus())
		end
	end)

	GameState:OnPropertyChanged("game.status", function(newStatus)
		if GameState:IsPlaying() then
			return
		end
		self:_applyWorldStatus(newStatus)
	end)

	if not GameState:IsPlaying() then
		self:_applyWorldStatus(GameState:GetWorldStatus())
	end

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
	if InputService.TouchEnabled and not InputService.KeyboardEnabled then
		deviceType = "Mobile"
	elseif InputService.GamepadEnabled then
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

function UIManager:ShowWorldStatus(title, subtitle)
	ensureWorldStatusGui()

	worldStatusGui.Enabled = true
	worldStatusTitle.Text = title or STATUS_COPY.loading.title
	worldStatusSubtitle.Text = subtitle or STATUS_COPY.loading.body

	if not worldStatusOverlayRelease then
		worldStatusOverlayRelease = InputService:BeginOverlay("WorldStatus", {
			showIcon = true,
		})
	end
end

function UIManager:HideWorldStatus()
	if worldStatusGui then
		worldStatusGui.Enabled = false
		worldStatusTitle.Text = ""
		worldStatusSubtitle.Text = ""
	end
	if worldStatusOverlayRelease then
		worldStatusOverlayRelease()
		worldStatusOverlayRelease = nil
	end
end

function UIManager:_applyWorldStatus(statusKey, overrideMessage)
	statusKey = statusKey or "loading"
	local copy = STATUS_COPY[statusKey] or STATUS_COPY.loading
	self:ShowWorldStatus(copy.title, overrideMessage or copy.body)
end

--[[
	Cleanup function
--]]
function UIManager:Cleanup()
	print("UIManager: Cleanup complete")
end

return UIManager