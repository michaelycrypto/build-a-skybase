--[[
	CameraController.lua (Mobile)
	Touch-drag camera control system for mobile devices

	Features:
	- Touch-drag camera rotation (Minecraft-style)
	- Split-screen mode support
	- Adjustable sensitivity
	- Smoothing and acceleration
	- Y-axis inversion
	- Gyroscope support (optional)
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local MobileCameraController = {}
MobileCameraController.__index = MobileCameraController

function MobileCameraController.new()
	local self = setmetatable({}, MobileCameraController)

	-- Configuration
	self.sensitivityX = 0.5
	self.sensitivityY = 0.5
	self.invertY = false
	self.smoothing = 0.2
	self.gyroscopeEnabled = false
	self.gyroscopeSensitivity = 1.0
	self.maxVerticalAngle = 80 -- Degrees

	-- State
	self.enabled = false
	self.active = false
	self.touchInput = nil
	self.lastTouchPosition = nil
	self.cameraRotation = Vector2.new(0, 0) -- X = horizontal, Y = vertical
	self.targetRotation = Vector2.new(0, 0)

	-- Screen zones
	self.controlScheme = "Classic" -- Classic, Split, Gyro
	self.splitRatio = 0.4 -- 40% left for movement

	-- Connections
	self.connections = {}

	-- Camera reference
	self.camera = workspace.CurrentCamera
	self.player = game.Players.LocalPlayer
	self.character = nil
	self.humanoid = nil

	return self
end

--[[
	Initialize mobile camera controller
]]
function MobileCameraController:Initialize()
	if self.enabled then
		warn("MobileCameraController already initialized")
		return
	end

	self.enabled = true

	-- Setup character
	self.character = self.player.Character or self.player.CharacterAdded:Wait()
	self.humanoid = self.character:WaitForChild("Humanoid")

	-- Handle respawn
	self.player.CharacterAdded:Connect(function(newCharacter)
		self.character = newCharacter
		self.humanoid = newCharacter:WaitForChild("Humanoid")
		self.cameraRotation = Vector2.new(0, 0)
		self.targetRotation = Vector2.new(0, 0)
	end)

	-- Setup input handling
	self:SetupInputHandling()

	-- Setup camera update loop
	self:SetupCameraLoop()

	-- Enable gyroscope if available
	if UserInputService.GyroscopeEnabled then
		self.gyroscopeAvailable = true
	end

	print("✅ MobileCameraController: Initialized")
end

--[[
	Setup input handling
]]
function MobileCameraController:SetupInputHandling()
	-- Touch input for camera rotation
	self.connections.inputBegan = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and not gameProcessed then
			self:OnTouchBegin(input)
		end
	end)

	self.connections.inputChanged = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and self.active and input == self.touchInput then
			self:OnTouchMove(input)
		end

		-- Gyroscope input
		if self.gyroscopeEnabled and input.UserInputType == Enum.UserInputType.Gyroscope then
			self:OnGyroscopeInput(input)
		end
	end)

	self.connections.inputEnded = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and input == self.touchInput then
			self:OnTouchEnd(input)
		end
	end)
end

--[[
	Setup camera update loop
]]
function MobileCameraController:SetupCameraLoop()
	self.connections.renderStepped = RunService.RenderStepped:Connect(function(deltaTime)
		if not self.enabled or not self.character or not self.humanoid then
			return
		end

		-- Smooth camera rotation
		self:UpdateCameraRotation(deltaTime)
	end)
end

--[[
	Check if touch is in camera control zone
]]
function MobileCameraController:IsTouchInCameraZone(position)
	local screenSize = workspace.CurrentCamera.ViewportSize

	if self.controlScheme == "Split" then
		-- Split mode: only right side controls camera
		local splitX = screenSize.X * self.splitRatio
		return position.X >= splitX
	elseif self.controlScheme == "Classic" then
		-- Classic mode: anywhere except left thumbstick area
		-- Exclude left 40% of screen (thumbstick zone)
		return position.X >= screenSize.X * 0.4
	end

	return true
end

--[[
	Handle touch begin
]]
function MobileCameraController:OnTouchBegin(input)
	if not self.enabled then return end

	local touchPos = Vector2.new(input.Position.X, input.Position.Y)

	-- Check if touch is in camera control zone
	if self:IsTouchInCameraZone(touchPos) then
		self.active = true
		self.touchInput = input
		self.lastTouchPosition = touchPos
	end
end

--[[
	Handle touch move
]]
function MobileCameraController:OnTouchMove(input)
	if not self.active or not self.lastTouchPosition then return end

	local currentPosition = Vector2.new(input.Position.X, input.Position.Y)
	local delta = currentPosition - self.lastTouchPosition

	-- Apply sensitivity
	delta = Vector2.new(
		delta.X * self.sensitivityX,
		delta.Y * self.sensitivityY
	)

	-- Invert Y if enabled
	if self.invertY then
		delta = Vector2.new(delta.X, -delta.Y)
	end

	-- Update target rotation
	-- X = horizontal (yaw), Y = vertical (pitch)
	-- Note: Negative delta.X for natural right-drag = turn right
	self.targetRotation = Vector2.new(
		self.targetRotation.X - delta.X * 0.01, -- Horizontal
		self.targetRotation.Y - delta.Y * 0.01  -- Vertical
	)

	-- Clamp vertical rotation
	local maxPitch = math.rad(self.maxVerticalAngle)
	self.targetRotation = Vector2.new(
		self.targetRotation.X,
		math.clamp(self.targetRotation.Y, -maxPitch, maxPitch)
	)

	self.lastTouchPosition = currentPosition
end

--[[
	Handle touch end
]]
function MobileCameraController:OnTouchEnd(input)
	if not self.active then return end

	self.active = false
	self.touchInput = nil
	self.lastTouchPosition = nil
end

--[[
	Handle gyroscope input
]]
function MobileCameraController:OnGyroscopeInput(input)
	if not self.gyroscopeEnabled then return end

	-- Get device rotation
	local rotation = input.Delta

	-- Apply gyroscope sensitivity
	local gyroX = rotation.X * self.gyroscopeSensitivity * 0.1
	local gyroY = rotation.Y * self.gyroscopeSensitivity * 0.1

	-- Update target rotation
	self.targetRotation = Vector2.new(
		self.targetRotation.X + gyroX,
		self.targetRotation.Y + gyroY
	)

	-- Clamp vertical rotation
	local maxPitch = math.rad(self.maxVerticalAngle)
	self.targetRotation = Vector2.new(
		self.targetRotation.X,
		math.clamp(self.targetRotation.Y, -maxPitch, maxPitch)
	)
end

--[[
	Update camera rotation with smoothing
]]
function MobileCameraController:UpdateCameraRotation(deltaTime)
	-- Smoothly interpolate to target rotation
	local alpha = 1 - math.pow(self.smoothing, deltaTime)
	self.cameraRotation = self.cameraRotation:Lerp(self.targetRotation, alpha)

	-- Get character's root part
	local rootPart = self.character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Calculate camera CFrame
	local cameraCFrame = self.camera.CFrame
	local cameraPosition = cameraCFrame.Position

	-- Apply rotation
	-- Horizontal rotation (yaw)
	local yawCFrame = CFrame.Angles(0, self.cameraRotation.X, 0)

	-- Vertical rotation (pitch)
	local pitchCFrame = CFrame.Angles(self.cameraRotation.Y, 0, 0)

	-- Combine rotations
	-- Note: Roblox native camera handles positioning, we only influence rotation
	-- by rotating the character to face camera direction

	-- Get camera's horizontal direction
	local lookVector = cameraCFrame.LookVector
	local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z)

	if horizontalLook.Magnitude > 0.001 then
		horizontalLook = horizontalLook.Unit

		-- Create CFrame facing the camera direction
		local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + horizontalLook)

		-- Apply rotation smoothly (to avoid jarring movements)
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, 0.5)
	end
end

--[[
	Set sensitivity
]]
function MobileCameraController:SetSensitivity(x, y)
	self.sensitivityX = math.clamp(x, 0.1, 2.0)
	self.sensitivityY = math.clamp(y or x, 0.1, 2.0)
end

--[[
	Set Y-axis inversion
]]
function MobileCameraController:SetInvertY(inverted)
	self.invertY = inverted
end

--[[
	Set smoothing factor
]]
function MobileCameraController:SetSmoothingFactor(value)
	self.smoothing = math.clamp(value, 0, 0.9)
end

--[[
	Enable gyroscope controls
]]
function MobileCameraController:EnableGyroscope(enabled)
	if not self.gyroscopeAvailable then
		warn("Gyroscope not available on this device")
		return false
	end

	self.gyroscopeEnabled = enabled
	return true
end

--[[
	Set gyroscope sensitivity
]]
function MobileCameraController:SetGyroscopeSensitivity(sensitivity)
	self.gyroscopeSensitivity = math.clamp(sensitivity, 0.1, 3.0)
end

--[[
	Set control scheme
]]
function MobileCameraController:SetControlScheme(scheme)
	if scheme == "Classic" or scheme == "Split" or scheme == "Gyro" then
		self.controlScheme = scheme
		print("📷 Camera control scheme:", scheme)
	else
		warn("Invalid control scheme:", scheme)
	end
end

--[[
	Set split ratio for split-screen mode
]]
function MobileCameraController:SetSplitRatio(ratio)
	self.splitRatio = math.clamp(ratio, 0.2, 0.8)
end

--[[
	Reset camera rotation
]]
function MobileCameraController:Reset()
	self.cameraRotation = Vector2.new(0, 0)
	self.targetRotation = Vector2.new(0, 0)
end

--[[
	Cleanup
]]
function MobileCameraController:Destroy()
	self.enabled = false
	self.active = false

	-- Disconnect all connections
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end

	self.connections = {}

	print("🗑️ MobileCameraController: Destroyed")
end

return MobileCameraController

