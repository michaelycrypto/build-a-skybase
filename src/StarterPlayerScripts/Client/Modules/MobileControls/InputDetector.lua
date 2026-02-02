--[[
	InputDetector.lua
	Detects and tracks touch inputs, gestures, and multi-touch

	Features:
	- Track multiple simultaneous touches
	- Gesture recognition (tap, hold, drag, pinch, swipe)
	- Touch zone classification (left/right screen division)
	- Input priority system
]]

local GuiService = game:GetService("GuiService")

local InputDetector = {}
InputDetector.__index = InputDetector

-- Touch state tracking
local TouchState = {
	Began = "Began",
	Moved = "Moved",
	Ended = "Ended",
	Cancelled = "Cancelled",
}

-- Gesture types
local GestureType = {
	Tap = "Tap",
	LongPress = "LongPress",
	Drag = "Drag",
	Swipe = "Swipe",
	Pinch = "Pinch",
}

-- Constants
local TAP_MAX_DURATION = 0.3 -- Max time for a tap (seconds)
local TAP_MAX_MOVEMENT = 10 -- Max pixels moved for tap
local LONG_PRESS_DURATION = 0.5 -- Time to trigger long press
local SWIPE_MIN_VELOCITY = 500 -- Minimum velocity for swipe (pixels/sec)
local SWIPE_MIN_DISTANCE = 50 -- Minimum distance for swipe

function InputDetector.new(inputProvider)
	local self = setmetatable({}, InputDetector)

	-- Active touches: [inputObject] = touchData
	self.activeTouches = {}

	-- Touch history (for gesture recognition)
	self.touchHistory = {}

	-- Callbacks
	self.onTouchBegan = nil
	self.onTouchMoved = nil
	self.onTouchEnded = nil
	self.onGesture = nil

	-- Configuration
	self.enabled = false
	self.maxTouches = 5
	self.ignoreGuiTouches = true -- Ignore touches on GUI elements

	-- Screen zones for split-screen mode
	self.splitScreenEnabled = false
	self.splitRatio = 0.4 -- 40% left side

	-- Connections
	self.connections = {}
	self.inputProvider = inputProvider

	return self
end

--[[
	Initialize the input detector
]]
function InputDetector:Initialize()
	if self.enabled then
		warn("InputDetector already initialized")
		return
	end

	self.enabled = true

	if not self.inputProvider then
		warn("InputDetector: No input provider available")
		return
	end

	-- Connect to shared input provider events
	self.connections.inputBegan = self.inputProvider.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:DetectTouchBegin(input, gameProcessed)
		end
	end)

	self.connections.inputChanged = self.inputProvider.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:DetectTouchMove(input, gameProcessed)
		end
	end)

	self.connections.inputEnded = self.inputProvider.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			self:DetectTouchEnd(input, gameProcessed)
		end
	end)

	print("✅ InputDetector: Initialized")
end

--[[
	Get safe zone insets (handles notches, rounded corners)
]]
function InputDetector:GetSafeZoneInsets()
	local insets = GuiService:GetGuiInset()
	return {
		Top = insets.Y,
		Bottom = 0,
		Left = insets.X,
		Right = 0,
	}
end

--[[
	Get screen zone for a position (Left, Right, or Center)
]]
function InputDetector:GetScreenZone(position)
	local screenSize = workspace.CurrentCamera.ViewportSize

	if self.splitScreenEnabled then
		local splitX = screenSize.X * self.splitRatio
		if position.X < splitX then
			return "Left"
		else
			return "Right"
		end
	end

	-- Default: divide screen in half
	if position.X < screenSize.X / 2 then
		return "Left"
	else
		return "Right"
	end
end

--[[
	Detect touch begin
]]
function InputDetector:DetectTouchBegin(inputObject, gameProcessed)
	-- Ignore if we're at max touches
	if self:GetTouchCount() >= self.maxTouches then
		return
	end

	-- Ignore GUI touches if configured
	if self.ignoreGuiTouches and gameProcessed then
		return
	end

	local position = inputObject.Position
	local touchData = {
		inputObject = inputObject,
		startPosition = position,
		currentPosition = position,
		previousPosition = position,
		startTime = tick(),
		lastUpdateTime = tick(),
		state = TouchState.Began,
		zone = self:GetScreenZone(position),
		moved = false,
		totalDistance = 0,
		velocity = Vector2.new(0, 0),
		gameProcessed = gameProcessed,
	}

	self.activeTouches[inputObject] = touchData

	-- Fire callback
	if self.onTouchBegan then
		self.onTouchBegan(touchData)
	end
end

--[[
	Detect touch move
]]
function InputDetector:DetectTouchMove(inputObject, _gameProcessed)
	local touchData = self.activeTouches[inputObject]
	if not touchData then return end

	local position = inputObject.Position
	local previousPosition = touchData.currentPosition
	local deltaTime = tick() - touchData.lastUpdateTime

	-- Update touch data
	touchData.previousPosition = previousPosition
	touchData.currentPosition = position
	touchData.lastUpdateTime = tick()
	touchData.state = TouchState.Moved

	-- Calculate movement
	local delta = position - previousPosition
	local distance = delta.Magnitude
	touchData.totalDistance = touchData.totalDistance + distance

	-- Calculate velocity
	if deltaTime > 0 then
		touchData.velocity = delta / deltaTime
	end

	-- Mark as moved if significant movement
	if touchData.totalDistance > TAP_MAX_MOVEMENT then
		touchData.moved = true
	end

	-- Fire callback
	if self.onTouchMoved then
		self.onTouchMoved(touchData)
	end
end

--[[
	Detect touch end
]]
function InputDetector:DetectTouchEnd(inputObject, _gameProcessed)
	local touchData = self.activeTouches[inputObject]
	if not touchData then return end

	touchData.state = TouchState.Ended
	touchData.endTime = tick()
	touchData.duration = touchData.endTime - touchData.startTime

	-- Classify gesture
	local gesture = self:ClassifyGesture(touchData)
	touchData.gesture = gesture

	-- Fire callbacks
	if self.onTouchEnded then
		self.onTouchEnded(touchData)
	end

	if self.onGesture and gesture then
		self.onGesture(gesture, touchData)
	end

	-- Add to history and remove from active
	table.insert(self.touchHistory, touchData)
	self.activeTouches[inputObject] = nil

	-- Limit history size
	if #self.touchHistory > 20 then
		table.remove(self.touchHistory, 1)
	end
end

--[[
	Classify gesture from touch data
]]
function InputDetector:ClassifyGesture(touchData)
	local duration = touchData.duration or 0
	local distance = touchData.totalDistance or 0
	local velocity = touchData.velocity.Magnitude

	-- Long press: held still for duration
	if duration >= LONG_PRESS_DURATION and not touchData.moved then
		return GestureType.LongPress
	end

	-- Tap: quick touch with minimal movement
	if duration <= TAP_MAX_DURATION and distance <= TAP_MAX_MOVEMENT then
		return GestureType.Tap
	end

	-- Swipe: fast movement
	if velocity >= SWIPE_MIN_VELOCITY and distance >= SWIPE_MIN_DISTANCE then
		return GestureType.Swipe
	end

	-- Drag: slower movement
	if distance > TAP_MAX_MOVEMENT then
		return GestureType.Drag
	end

	return nil
end

--[[
	Get number of active touches
]]
function InputDetector:GetTouchCount()
	local count = 0
	for _ in pairs(self.activeTouches) do
		count = count + 1
	end
	return count
end

--[[
	Get all active touches
]]
function InputDetector:GetActiveTouches()
	local touches = {}
	for _, touchData in pairs(self.activeTouches) do
		table.insert(touches, touchData)
	end
	return touches
end

--[[
	Get touches in a specific zone
]]
function InputDetector:GetTouchesInZone(zone)
	local touches = {}
	for _, touchData in pairs(self.activeTouches) do
		if touchData.zone == zone then
			table.insert(touches, touchData)
		end
	end
	return touches
end

--[[
	Check if a position is being touched
]]
function InputDetector:IsPositionTouched(position, radius)
	radius = radius or 10

	for _, touchData in pairs(self.activeTouches) do
		local distance = (touchData.currentPosition - position).Magnitude
		if distance <= radius then
			return true, touchData
		end
	end

	return false, nil
end

--[[
	Set split screen mode
]]
function InputDetector:SetSplitScreen(enabled, ratio)
	self.splitScreenEnabled = enabled
	if ratio then
		self.splitRatio = ratio
	end
end

--[[
	Cleanup
]]
function InputDetector:Destroy()
	self.enabled = false

	-- Disconnect all connections
	for _, connection in pairs(self.connections) do
		if connection then
			connection:Disconnect()
		end
	end

	self.connections = {}
	self.activeTouches = {}
	self.touchHistory = {}

	print("🗑️ InputDetector: Destroyed")
end

return InputDetector

