--[[
	VirtualThumbstick.lua
	Virtual thumbstick for movement control (Minecraft-style)

	Features:
	- Fixed or dynamic positioning
	- Visual feedback
	- Configurable dead zones
	- Snap to cardinal directions (optional)
	- Accessibility support
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local VirtualThumbstick = {}
VirtualThumbstick.__index = VirtualThumbstick

function VirtualThumbstick.new()
	local self = setmetatable({}, VirtualThumbstick)

	-- Configuration
	self.radius = 60
	self.deadZone = 0.15
	self.opacity = 0.6
	self.dynamicPosition = false
	self.snapToDirections = false
	self.enabled = false

	-- State
	self.active = false
	self.touchInput = nil
	self.direction = Vector2.new(0, 0)
	self.magnitude = 0
	self.startPosition = nil
	self.currentPosition = nil

	-- UI Elements
	self.gui = nil
	self.outerRing = nil
	self.innerKnob = nil
	self.directionalIndicators = {}

	-- Callbacks
	self.onDirectionChanged = nil
	self.onMagnitudeChanged = nil

	-- Accessibility
	self.highContrast = false
	self.largeSize = false
	self.hapticFeedback = true

	return self
end

--[[
	Create UI elements
]]
function VirtualThumbstick:Create(parent, position)
	-- Main container
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VirtualThumbstick"
	self.gui.ResetOnSpawn = false
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.Parent = parent

	-- Container frame
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, self.radius * 2.5, 0, self.radius * 2.5)
	container.Position = position or UDim2.new(0, 100, 1, -150)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.Parent = self.gui
	self.container = container

	-- Outer ring (boundary)
	self.outerRing = Instance.new("ImageLabel")
	self.outerRing.Name = "OuterRing"
	self.outerRing.Size = UDim2.new(0, self.radius * 2, 0, self.radius * 2)
	self.outerRing.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
	self.outerRing.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	self.outerRing.BackgroundTransparency = 0.7
	self.outerRing.BorderSizePixel = 0
	self.outerRing.Image = ""
	self.outerRing.Parent = container

	local outerCorner = Instance.new("UICorner")
	outerCorner.CornerRadius = UDim.new(1, 0)
	outerCorner.Parent = self.outerRing

	-- Outer ring border
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Color = Color3.fromRGB(255, 255, 255)
	outerStroke.Thickness = 2
	outerStroke.Transparency = 0.5
	outerStroke.Parent = self.outerRing

	-- Inner knob (draggable)
	self.innerKnob = Instance.new("ImageLabel")
	self.innerKnob.Name = "InnerKnob"
	self.innerKnob.Size = UDim2.new(0, self.radius * 0.8, 0, self.radius * 0.8)
	self.innerKnob.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.innerKnob.AnchorPoint = Vector2.new(0.5, 0.5)
	self.innerKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	self.innerKnob.BackgroundTransparency = 0.4
	self.innerKnob.BorderSizePixel = 0
	self.innerKnob.Image = ""
	self.innerKnob.Parent = container

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(1, 0)
	innerCorner.Parent = self.innerKnob

	-- Inner knob border
	local innerStroke = Instance.new("UIStroke")
	innerStroke.Color = Color3.fromRGB(255, 255, 255)
	innerStroke.Thickness = 3
	innerStroke.Transparency = 0.3
	innerStroke.Parent = self.innerKnob

	-- Directional indicators (subtle arrows)
	self:CreateDirectionalIndicators(container)

	-- Start hidden
	self.gui.Enabled = false

	print("✅ VirtualThumbstick: UI created")
end

--[[
	Create directional indicators
]]
function VirtualThumbstick:CreateDirectionalIndicators(parent)
	local directions = {
		{name = "Up", position = UDim2.new(0.5, 0, 0.2, 0), rotation = 0},
		{name = "Down", position = UDim2.new(0.5, 0, 0.8, 0), rotation = 180},
		{name = "Left", position = UDim2.new(0.2, 0, 0.5, 0), rotation = 270},
		{name = "Right", position = UDim2.new(0.8, 0, 0.5, 0), rotation = 90},
	}

	for _, dir in ipairs(directions) do
		local arrow = Instance.new("TextLabel")
		arrow.Name = dir.name .. "Arrow"
		arrow.Size = UDim2.new(0, 15, 0, 15)
		arrow.Position = dir.position
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.Text = "▲"
		arrow.TextColor3 = Color3.fromRGB(255, 255, 255)
		arrow.TextTransparency = 0.7
		arrow.TextSize = 12
		arrow.Font = Enum.Font.GothamBold
		arrow.Rotation = dir.rotation
		arrow.Parent = parent

		self.directionalIndicators[dir.name] = arrow
	end
end

--[[
	Initialize thumbstick
]]
function VirtualThumbstick:Initialize(parent, position)
	if not parent then
		parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	self:Create(parent, position)
	self:SetupInputHandling()
	self.enabled = true

	print("✅ VirtualThumbstick: Initialized")
end

--[[
	Setup input handling
]]
function VirtualThumbstick:SetupInputHandling()
	-- Touch input handling
	self.inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and not self.active then
			-- Check if touch is in the thumbstick zone (left side of screen)
			local screenSize = workspace.CurrentCamera.ViewportSize
			local touchPos = input.Position

			-- Only activate if touch is on left 40% of screen
			if touchPos.X < screenSize.X * 0.4 then
				self:OnTouchBegin(input)
			end
		end
	end)

	self.inputChangedConnection = UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and self.active and input == self.touchInput then
			self:OnTouchMove(input)
		end
	end)

	self.inputEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch and input == self.touchInput then
			self:OnTouchEnd(input)
		end
	end)
end

--[[
	Handle touch begin
]]
function VirtualThumbstick:OnTouchBegin(input)
	if not self.enabled then return end

	self.active = true
	self.touchInput = input
	self.startPosition = Vector2.new(input.Position.X, input.Position.Y)
	self.currentPosition = self.startPosition

	-- Position thumbstick at touch location (dynamic mode)
	if self.dynamicPosition then
		self.container.Position = UDim2.new(0, self.startPosition.X, 0, self.startPosition.Y)
	end

	-- Show thumbstick
	self.gui.Enabled = true

	-- Fade in animation
	self:AnimateFadeIn()
end

--[[
	Handle touch move
]]
function VirtualThumbstick:OnTouchMove(input)
	if not self.active then return end

	self.currentPosition = Vector2.new(input.Position.X, input.Position.Y)
	local delta = self.currentPosition - self.startPosition

	-- Calculate direction and magnitude
	local distance = delta.Magnitude
	local maxDistance = self.radius

	-- Clamp to radius
	if distance > maxDistance then
		delta = delta.Unit * maxDistance
		distance = maxDistance
	end

	-- Calculate normalized magnitude (0-1)
	self.magnitude = distance / maxDistance

	-- Apply dead zone
	if self.magnitude < self.deadZone then
		self.magnitude = 0
		self.direction = Vector2.new(0, 0)
	else
		-- Remap magnitude to remove dead zone
		self.magnitude = (self.magnitude - self.deadZone) / (1 - self.deadZone)
		self.direction = delta.Unit

		-- Snap to directions if enabled
		if self.snapToDirections then
			self.direction = self:SnapToCardinal(self.direction)
		end
	end

	-- Update knob position
	local knobOffset = self.direction * (self.magnitude * maxDistance)
	self.innerKnob.Position = UDim2.new(0.5, knobOffset.X, 0.5, knobOffset.Y)

	-- Fire callbacks
	if self.onDirectionChanged then
		self.onDirectionChanged(self.direction)
	end

	if self.onMagnitudeChanged then
		self.onMagnitudeChanged(self.magnitude)
	end

	-- Haptic feedback on direction change (if enabled)
	if self.hapticFeedback and self.magnitude > 0.5 then
		-- Simple vibration (Roblox doesn't have native haptics, but we can prepare for it)
		-- UserInputService:SetHapticMotor(Enum.HapticMotor.Touch, 0.1)
	end
end

--[[
	Handle touch end
]]
function VirtualThumbstick:OnTouchEnd(input)
	if not self.active then return end

	self.active = false
	self.touchInput = nil
	self.direction = Vector2.new(0, 0)
	self.magnitude = 0

	-- Reset knob position
	self.innerKnob.Position = UDim2.new(0.5, 0, 0.5, 0)

	-- Fade out animation
	self:AnimateFadeOut()

	-- Fire callbacks
	if self.onDirectionChanged then
		self.onDirectionChanged(self.direction)
	end

	if self.onMagnitudeChanged then
		self.onMagnitudeChanged(self.magnitude)
	end
end

--[[
	Snap direction to 8 cardinal directions
]]
function VirtualThumbstick:SnapToCardinal(direction)
	local angle = math.atan2(direction.Y, direction.X)
	local snapAngle = math.pi / 4 -- 45 degrees

	-- Round to nearest 45 degrees
	local snappedAngle = math.floor((angle + snapAngle / 2) / snapAngle) * snapAngle

	return Vector2.new(math.cos(snappedAngle), math.sin(snappedAngle))
end

--[[
	Fade in animation
]]
function VirtualThumbstick:AnimateFadeIn()
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(self.outerRing, tweenInfo, {BackgroundTransparency = 0.7}):Play()
	TweenService:Create(self.innerKnob, tweenInfo, {BackgroundTransparency = 0.4}):Play()
end

--[[
	Fade out animation
]]
function VirtualThumbstick:AnimateFadeOut()
	local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local outerTween = TweenService:Create(self.outerRing, tweenInfo, {BackgroundTransparency = 1})
	outerTween.Completed:Connect(function()
		if not self.active then
			self.gui.Enabled = false
		end
	end)
	outerTween:Play()

	TweenService:Create(self.innerKnob, tweenInfo, {BackgroundTransparency = 1}):Play()
end

--[[
	Get current direction (normalized)
]]
function VirtualThumbstick:GetDirection()
	return self.direction
end

--[[
	Get current magnitude (0-1)
]]
function VirtualThumbstick:GetMagnitude()
	return self.magnitude
end

--[[
	Get movement vector (direction * magnitude)
]]
function VirtualThumbstick:GetMovementVector()
	return self.direction * self.magnitude
end

--[[
	Set dead zone
]]
function VirtualThumbstick:SetDeadZone(value)
	self.deadZone = math.clamp(value, 0, 0.5)
end

--[[
	Set visibility
]]
function VirtualThumbstick:SetVisibility(visible)
	if self.gui then
		self.gui.Enabled = visible
	end
end

--[[
	Set position
]]
function VirtualThumbstick:SetPosition(position)
	if self.container then
		self.container.Position = position
	end
end

--[[
	Set size
]]
function VirtualThumbstick:SetSize(radius)
	self.radius = radius

	if self.outerRing then
		self.outerRing.Size = UDim2.new(0, radius * 2, 0, radius * 2)
	end

	if self.innerKnob then
		self.innerKnob.Size = UDim2.new(0, radius * 0.8, 0, radius * 0.8)
	end
end

--[[
	Set opacity
]]
function VirtualThumbstick:SetOpacity(opacity)
	self.opacity = opacity

	if self.outerRing then
		self.outerRing.BackgroundTransparency = 1 - opacity
	end

	if self.innerKnob then
		self.innerKnob.BackgroundTransparency = 1 - (opacity * 0.6)
	end
end

--[[
	Set high contrast mode
]]
function VirtualThumbstick:SetHighContrast(enabled)
	self.highContrast = enabled

	if enabled then
		if self.outerRing then
			self.outerRing.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
			local stroke = self.outerRing:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 0)
				stroke.Thickness = 4
			end
		end

		if self.innerKnob then
			self.innerKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			local stroke = self.innerKnob:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Thickness = 4
			end
		end
	else
		if self.outerRing then
			self.outerRing.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = self.outerRing:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Thickness = 2
			end
		end

		if self.innerKnob then
			self.innerKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			local stroke = self.innerKnob:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(255, 255, 255)
				stroke.Thickness = 3
			end
		end
	end
end

--[[
	Cleanup
]]
function VirtualThumbstick:Destroy()
	self.enabled = false
	self.active = false

	-- Disconnect input connections
	if self.inputConnection then
		self.inputConnection:Disconnect()
	end
	if self.inputChangedConnection then
		self.inputChangedConnection:Disconnect()
	end
	if self.inputEndedConnection then
		self.inputEndedConnection:Disconnect()
	end

	-- Destroy GUI
	if self.gui then
		self.gui:Destroy()
	end

	print("🗑️ VirtualThumbstick: Destroyed")
end

return VirtualThumbstick

