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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import mobile control modules
local MobileControls = script.Parent.Parent.Modules.MobileControls
local InputDetector = require(MobileControls.InputDetector)
local VirtualThumbstick = require(MobileControls.VirtualThumbstick)
local MobileCameraController = require(MobileControls.CameraController)
local MobileActionBar = require(MobileControls.MobileActionBar)
local DeviceDetector = require(MobileControls.DeviceDetector)
local FeedbackSystem = require(MobileControls.FeedbackSystem)
local ControlSchemes = require(MobileControls.ControlSchemes)

-- Import config
local MobileControlConfig = require(ReplicatedStorage.Shared.MobileControls.MobileControlConfig)

-- Controllers (lazy-loaded to avoid circular dependencies)
local SprintController = nil
local CameraController = nil

local MobileControlController = {}
MobileControlController.__index = MobileControlController

function MobileControlController.new(inputProvider)
	local self = setmetatable({}, MobileControlController)

	-- Core modules
	self.inputProvider = inputProvider
	self.inputDetector = InputDetector.new(inputProvider)
	self.thumbstick = VirtualThumbstick.new()
	self.mobileCameraController = MobileCameraController.new(inputProvider)
	self.actionBar = MobileActionBar.new()
	self.deviceDetector = DeviceDetector.new(inputProvider)
	self.feedbackSystem = FeedbackSystem.new()
	self.controlSchemes = ControlSchemes.new()
	self.inputCallbacks = nil

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
function MobileControlController:Initialize(inputCallbacks)
	if self.initialized then
		warn("MobileControlController already initialized")
		return
	end

	self.inputCallbacks = inputCallbacks or {}

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

	-- Get SoundManager if available (defer to avoid circular dependency with GameClient)
	-- GameClient requires InputService which requires MobileControlController
	-- MobileControlController cannot require GameClient during initialization
	local soundManager = nil
	task.defer(function()
		local success, Client = pcall(function()
			return require(script.Parent.Parent.GameClient)
		end)
		if success and Client and Client.managers then
			soundManager = Client.managers.SoundManager
			if self.feedbackSystem and soundManager then
				self.feedbackSystem:SetSoundManager(soundManager)
			end
		end
	end)

	-- Initialize core modules (no UI yet - that happens after loading screen)
	self.inputDetector:Initialize()
	self.mobileCameraController:Initialize()
	self.feedbackSystem:Initialize(soundManager)

	-- Setup character handling
	self:SetupCharacter()

	-- Setup update loop
	self:SetupUpdateLoop()

	-- Store settings for later UI creation
	self._recommendedSettings = recommendedSettings

	self.initialized = true
	self.enabled = true

	-- NOTE: UI (thumbstick, action bar) is NOT created here
	-- Call InitializeUI() after loading screen completes to match other UI components

	print("Mobile Controls: Core initialized (UI deferred)")
	print("   Device:", self.deviceDetector:GetDeviceType())
end

--[[
	Initialize mobile UI components (call after loading screen completes)
	This follows the same pattern as VoxelHotbar, ChestUI, etc.
]]
function MobileControlController:InitializeUI()
	if not self.initialized or not self.isMobileDevice then
		return
	end

	if self._uiInitialized then
		warn("MobileControlController UI already initialized")
		return
	end

	print("Mobile Controls: Initializing UI...")

	-- Initialize thumbstick
	self.thumbstick:Initialize(nil, nil, self.inputProvider)

	-- Initialize action bar with callbacks
	self.actionBar:Initialize()
	self:SetupActionBarCallbacks()

	-- Setup input connections (thumbstick direction changes)
	self:SetupInputHandling()

	-- Apply control scheme
	local initialScheme = (self._recommendedSettings and self._recommendedSettings.ControlScheme) or "Classic"
	self:SetControlScheme(initialScheme)

	self._uiInitialized = true

	print("Mobile Controls: UI initialized")
	print("   Scheme:", initialScheme)
	print("   UI Scale:", (self._recommendedSettings and self._recommendedSettings.UIScale) or 1.0)
end

--[[
	Setup action bar button callbacks
]]
function MobileControlController:SetupActionBarCallbacks()
	-- Lazy load controllers to avoid circular dependencies
	if not SprintController then
		SprintController = require(script.Parent.SprintController)
	end
	if not CameraController then
		CameraController = require(script.Parent.CameraController)
	end

	-- Helper to get Client controllers (accessed at callback time, not setup time)
	local function getClient()
		local success, result = pcall(function()
			return require(script.Parent.Parent.GameClient)
		end)
		return success and result or nil
	end

	-- Sprint toggle callback
	self.actionBar.onSprintToggle = function(isActive)
		if SprintController and SprintController.SetSprinting then
			SprintController:SetSprinting(isActive)
		end
	end

	-- Attack callbacks - triggers both combat (PvP) and block breaking
	self.actionBar.onAttackStart = function()
		local Client = getClient()
		if not Client then return end

		-- Combat system (PvP sword swings)
		if Client.combatController and Client.combatController.SetHolding then
			Client.combatController:SetHolding(true)
		end
		-- Block breaking system
		if Client.blockInteraction and Client.blockInteraction.StartBreaking then
			Client.blockInteraction:StartBreaking()
		end
	end

	self.actionBar.onAttackEnd = function()
		local Client = getClient()
		if not Client then return end

		-- Combat system
		if Client.combatController and Client.combatController.SetHolding then
			Client.combatController:SetHolding(false)
		end
		-- Block breaking system
		if Client.blockInteraction and Client.blockInteraction.StopBreaking then
			Client.blockInteraction:StopBreaking()
		end
	end

	-- Camera mode cycle callback
	self.actionBar.onCameraMode = function()
		if CameraController and CameraController.CycleMode then
			CameraController:CycleMode()
			-- Update button icon to reflect new mode
			local currentMode = CameraController:GetCurrentState()
			if currentMode then
				self.actionBar:SetCameraMode(currentMode)
			end
		end
	end

	-- Listen for camera state changes to update button icon
	if CameraController and CameraController.StateChanged then
		CameraController.StateChanged:Connect(function(newState)
			self.actionBar:SetCameraMode(newState)
		end)
	end

	-- Sync initial sprint state
	if SprintController and SprintController.IsSprinting then
		self.actionBar:SetSprintActive(SprintController:IsSprinting())
	end

	-- Sync initial camera mode
	if CameraController and CameraController.GetCurrentState then
		local currentMode = CameraController:GetCurrentState()
		if currentMode then
			self.actionBar:SetCameraMode(currentMode)
		end
	end
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
		if self.inputCallbacks.onMovement then
			self.inputCallbacks.onMovement(direction, self.thumbstick:GetMagnitude())
		end
	end

	-- Action bar callbacks are set up in SetupActionBarCallbacks()
end

--[[
	Setup update loop
]]
function MobileControlController:SetupUpdateLoop()
	self.connections.heartbeat = RunService.Heartbeat:Connect(function(deltaTime)
		if not self.enabled then return end

		-- Update movement based on thumbstick
		local moveVector = self.thumbstick:GetMovementVector()
		if self.inputCallbacks.onMovement then
			self.inputCallbacks.onMovement(moveVector, moveVector.Magnitude)
		end
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
	Get action bar reference (for external access)
]]
function MobileControlController:GetActionBar()
	return self.actionBar
end

function MobileControlController:SetHighContrast(enabled)
	if self.thumbstick and self.thumbstick.SetHighContrast then
		self.thumbstick:SetHighContrast(enabled)
	end

	if self.actionBar and self.actionBar.SetHighContrast then
		self.actionBar:SetHighContrast(enabled)
	end
end

--[[
	Set control scheme
]]
function MobileControlController:SetControlScheme(scheme)
	local controllers = {
		thumbstick = self.thumbstick,
		camera = self.mobileCameraController,
		actionBar = self.actionBar,
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

	-- Apply to camera
	if settings.SensitivityX or settings.SensitivityY then
		self.mobileCameraController:SetSensitivity(
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
--[[
	Set sensitivity
]]
function MobileControlController:SetSensitivity(x, y)
	self.mobileCameraController:SetSensitivity(x, y)
end

--[[
	Check if UI has been initialized
]]
function MobileControlController:IsUIInitialized()
	return self._uiInitialized == true
end

--[[
	Enable/disable mobile controls
]]
function MobileControlController:SetEnabled(enabled)
	self.enabled = enabled

	if self._uiInitialized then
		if self.thumbstick then
			self.thumbstick:SetVisibility(enabled)
		end

		if self.actionBar then
			self.actionBar:SetEnabled(enabled)
		end
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
	if self.mobileCameraController then self.mobileCameraController:Destroy() end
	if self.actionBar then self.actionBar:Destroy() end

	print("MobileControlController: Destroyed")
end

return MobileControlController

