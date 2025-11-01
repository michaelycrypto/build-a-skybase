--[[
	MobileControlController.lua
	Main controller for mobile input system (Minecraft-inspired)

	Integrates:
	- Virtual thumbstick for movement
	- Touch camera controls
	- Action buttons
	- Device detection
	- Accessibility features
	- Multiple control schemes
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import mobile control modules
local MobileControls = script.Parent.Parent.Modules.MobileControls
local InputDetector = require(MobileControls.InputDetector)
local VirtualThumbstick = require(MobileControls.VirtualThumbstick)
local MobileCameraController = require(MobileControls.CameraController)
local ActionButtons = require(MobileControls.ActionButtons)
local DeviceDetector = require(MobileControls.DeviceDetector)
local FeedbackSystem = require(MobileControls.FeedbackSystem)
local ControlSchemes = require(MobileControls.ControlSchemes)

-- Import config
local MobileControlConfig = require(ReplicatedStorage.Shared.MobileControls.MobileControlConfig)

local MobileControlController = {}
MobileControlController.__index = MobileControlController

function MobileControlController.new()
	local self = setmetatable({}, MobileControlController)

	-- Core modules
	self.inputDetector = InputDetector.new()
	self.thumbstick = VirtualThumbstick.new()
	self.cameraController = MobileCameraController.new()
	self.actionButtons = ActionButtons.new()
	self.deviceDetector = DeviceDetector.new()
	self.feedbackSystem = FeedbackSystem.new()
	self.controlSchemes = ControlSchemes.new()

	-- State
	self.enabled = false
	self.initialized = false
	self.isMobileDevice = false

	-- Player references
	self.player = Players.LocalPlayer
	self.character = nil
	self.humanoid = nil

	-- Configuration (can be customized)
	self.config = MobileControlConfig

	-- Connections
	self.connections = {}

	return self
end

--[[
	Initialize mobile controls
]]
function MobileControlController:Initialize()
	if self.initialized then
		warn("MobileControlController already initialized")
		return
	end

	-- Detect device
	self.deviceDetector:Detect()
	self.isMobileDevice = self.deviceDetector:IsMobile()

	-- Only initialize mobile controls on mobile devices
	if not self.isMobileDevice then
		print("📱 Not a mobile device - mobile controls disabled")
		return
	end

	print("📱 Initializing Mobile Controls...")

	-- Apply device-recommended settings
	local recommendedSettings = self.deviceDetector:GetRecommendedSettings()
	self:ApplySettings(recommendedSettings)

	-- Get SoundManager if available
	local GameState = require(script.Parent.Parent.Managers.GameState)
	local Client = require(script.Parent.Parent.GameClient) or {}
	local soundManager = Client.managers and Client.managers.SoundManager

	-- Initialize modules
	self.inputDetector:Initialize()
	self.thumbstick:Initialize()
	self.cameraController:Initialize()
	self.actionButtons:Initialize()
	self.feedbackSystem:Initialize(soundManager)

	-- Setup character handling
	self:SetupCharacter()

	-- Setup input connections
	self:SetupInputHandling()

	-- Setup update loop
	self:SetupUpdateLoop()

	-- Apply initial control scheme
	local initialScheme = recommendedSettings.ControlScheme or "Classic"
	self:SetControlScheme(initialScheme)

	self.initialized = true
	self.enabled = true

	print("✅ Mobile Controls: Initialized")
	print("   Device:", self.deviceDetector:GetDeviceType())
	print("   Scheme:", initialScheme)
	print("   UI Scale:", recommendedSettings.UIScale or 1.0)
end

--[[
	Setup character references
]]
function MobileControlController:SetupCharacter()
	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	self.humanoid = self.character:WaitForChild("Humanoid")

	-- Handle respawn
	self.player.CharacterAdded:Connect(function(newCharacter)
		self.character = newCharacter
		self.humanoid = newCharacter:WaitForChild("Humanoid")
	end)
end

--[[
	Setup input handling
]]
function MobileControlController:SetupInputHandling()
	-- Connect thumbstick to movement
	self.thumbstick.onDirectionChanged = function(direction)
		if self.enabled and self.humanoid then
			-- Apply movement
			self:ApplyMovement(direction, self.thumbstick:GetMagnitude())
		end
	end

	-- Connect action buttons
	self.actionButtons.onButtonPressed = function(buttonType)
		self:HandleButtonPress(buttonType, true)
		self.feedbackSystem:OnButtonPress(self.actionButtons.buttons[buttonType].frame)
	end

	self.actionButtons.onButtonReleased = function(buttonType)
		self:HandleButtonPress(buttonType, false)
	end
end

--[[
	Setup update loop
]]
function MobileControlController:SetupUpdateLoop()
	self.connections.heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		if not self.enabled then return end

		-- Update movement based on thumbstick
		local moveVector = self.thumbstick:GetMovementVector()
		if moveVector.Magnitude > 0 then
			self:ApplyMovement(moveVector, moveVector.Magnitude)
		end
	end)
end

--[[
	Apply movement from thumbstick
]]
function MobileControlController:ApplyMovement(direction, magnitude)
	if not self.humanoid or not self.character then return end

	-- Get camera direction for relative movement
	local camera = workspace.CurrentCamera
	if not camera then return end

	local cameraCFrame = camera.CFrame
	local cameraLookVector = cameraCFrame.LookVector
	local cameraRightVector = cameraCFrame.RightVector

	-- Project to horizontal plane
	local forward = Vector3.new(cameraLookVector.X, 0, cameraLookVector.Z).Unit
	local right = Vector3.new(cameraRightVector.X, 0, cameraRightVector.Z).Unit

	-- Calculate movement direction relative to camera
	-- Note: direction.Y is vertical thumbstick (forward/back)
	-- direction.X is horizontal thumbstick (left/right)
	local moveDirection = (forward * -direction.Y) + (right * direction.X)

	if moveDirection.Magnitude > 0 then
		moveDirection = moveDirection.Unit

		-- Set humanoid move direction
		self.humanoid:Move(moveDirection * magnitude, false)
	else
		-- Stop movement
		self.humanoid:Move(Vector3.new(0, 0, 0), false)
	end
end

--[[
	Handle button press
]]
function MobileControlController:HandleButtonPress(buttonType, pressed)
	if not self.humanoid then return end

	-- Map button types to actions
	if buttonType == "Jump" and pressed then
		-- Jump
		self.humanoid.Jump = true
	elseif buttonType == "Sprint" then
		-- Sprint (change walk speed)
		if pressed then
			self.humanoid.WalkSpeed = 20 -- Sprint speed
		else
			self.humanoid.WalkSpeed = 14 -- Normal speed
		end
	elseif buttonType == "Crouch" then
		-- Crouch (handled by game's crouch system if exists)
		-- For now, just emit an event or change walk speed
		if pressed then
			self.humanoid.WalkSpeed = 8 -- Crouch speed
		else
			-- Check if sprinting
			local sprintPressed = self.actionButtons:IsButtonPressed("Sprint")
			self.humanoid.WalkSpeed = sprintPressed and 20 or 14
		end
	end
end

--[[
	Set control scheme
]]
function MobileControlController:SetControlScheme(scheme)
	local controllers = {
		thumbstick = self.thumbstick,
		camera = self.cameraController,
		actionButtons = self.actionButtons,
	}

	return self.controlSchemes:ApplyScheme(scheme, controllers)
end

--[[
	Apply settings
]]
function MobileControlController:ApplySettings(settings)
	-- Apply to thumbstick
	if settings.ThumbstickRadius then
		self.thumbstick:SetSize(settings.ThumbstickRadius)
	end

	-- Apply to action buttons
	if settings.ButtonSize then
		self.actionButtons:SetButtonSize(settings.ButtonSize)
	end

	if settings.ButtonOpacity then
		self.actionButtons:SetButtonOpacity(settings.ButtonOpacity)
	end

	-- Apply to camera
	if settings.SensitivityX or settings.SensitivityY then
		self.cameraController:SetSensitivity(
			settings.SensitivityX or 0.5,
			settings.SensitivityY or 0.5
		)
	end

	-- Apply accessibility settings
	if settings.HighContrast then
		self:SetHighContrast(true)
	end

	if settings.HapticIntensity then
		self.feedbackSystem:SetHapticIntensity(settings.HapticIntensity)
	end
end

--[[
	Set high contrast mode
]]
function MobileControlController:SetHighContrast(enabled)
	self.thumbstick:SetHighContrast(enabled)
	self.actionButtons:SetHighContrast(enabled)
end

--[[
	Set sensitivity
]]
function MobileControlController:SetSensitivity(x, y)
	self.cameraController:SetSensitivity(x, y)
end

--[[
	Enable/disable mobile controls
]]
function MobileControlController:SetEnabled(enabled)
	self.enabled = enabled

	if self.thumbstick then
		self.thumbstick:SetVisibility(enabled)
	end

	if self.actionButtons and self.actionButtons.gui then
		self.actionButtons.gui.Enabled = enabled
	end
end

--[[
	Check if mobile controls are active
]]
function MobileControlController:IsActive()
	return self.enabled and self.initialized and self.isMobileDevice
end

--[[
	Get device info
]]
function MobileControlController:GetDeviceInfo()
	return {
		type = self.deviceDetector:GetDeviceType(),
		screenSize = self.deviceDetector:GetScreenSize(),
		aspectRatio = self.deviceDetector:GetAspectRatio(),
		safeZones = self.deviceDetector:GetSafeZones(),
		capabilities = {
			touch = self.deviceDetector:SupportsFeature("Touch"),
			gyroscope = self.deviceDetector:SupportsFeature("Gyroscope"),
			accelerometer = self.deviceDetector:SupportsFeature("Accelerometer"),
		},
	}
end

--[[
	Show context button (e.g., "Press to interact")
]]
function MobileControlController:ShowContextButton(buttonType, label, icon)
	if not self.enabled then return end

	local position = UDim2.new(0.5, 0, 1, -100) -- Center-bottom
	self.actionButtons:ShowContextButton(buttonType, position, icon, label)
end

--[[
	Hide context button
]]
function MobileControlController:HideContextButton(buttonType)
	if not self.enabled then return end

	self.actionButtons:HideContextButton(buttonType)
end

--[[
	Cleanup
]]
function MobileControlController:Destroy()
	self.enabled = false
	self.initialized = false

	-- Disconnect all connections
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end

	-- Destroy modules
	if self.inputDetector then self.inputDetector:Destroy() end
	if self.thumbstick then self.thumbstick:Destroy() end
	if self.cameraController then self.cameraController:Destroy() end
	if self.actionButtons then self.actionButtons:Destroy() end

	print("🗑️ MobileControlController: Destroyed")
end

return MobileControlController

