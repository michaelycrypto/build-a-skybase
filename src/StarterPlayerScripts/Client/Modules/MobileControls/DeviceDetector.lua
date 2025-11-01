--[[
	DeviceDetector.lua
	Detects device type and capabilities for auto-configuration

	Features:
	- Detect device type (phone, tablet)
	- Screen size and aspect ratio detection
	- Safe zone detection (notches, rounded corners)
	- Capability detection (gyroscope, haptics)
	- Recommended settings based on device
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local DeviceDetector = {}
DeviceDetector.__index = DeviceDetector

-- Device types
local DeviceType = {
	SmallPhone = "SmallPhone",
	Phone = "Phone",
	Tablet = "Tablet",
	Unknown = "Unknown",
}

function DeviceDetector.new()
	local self = setmetatable({}, DeviceDetector)

	-- Device info
	self.deviceType = DeviceType.Unknown
	self.screenSize = Vector2.new(0, 0)
	self.aspectRatio = 0
	self.safeZones = {Top = 0, Bottom = 0, Left = 0, Right = 0}

	-- Capabilities
	self.hasTouchscreen = false
	self.hasGyroscope = false
	self.hasHaptics = false
	self.hasAccelerometer = false

	-- Recommended settings
	self.recommendedSettings = {}

	return self
end

--[[
	Detect device type and capabilities
]]
function DeviceDetector:Detect()
	-- Get screen size
	local camera = workspace.CurrentCamera
	if camera then
		self.screenSize = camera.ViewportSize
		self.aspectRatio = self.screenSize.X / self.screenSize.Y
	end

	-- Detect touch capability
	self.hasTouchscreen = UserInputService.TouchEnabled

	-- Detect gyroscope
	self.hasGyroscope = UserInputService.GyroscopeEnabled

	-- Detect accelerometer
	self.hasAccelerometer = UserInputService.AccelerometerEnabled

	-- Haptics are not directly detectable in Roblox, assume available if touch is present
	self.hasHaptics = self.hasTouchscreen

	-- Detect safe zones (for notches, rounded corners)
	self:DetectSafeZones()

	-- Classify device type based on screen size
	self:ClassifyDeviceType()

	-- Generate recommended settings
	self:GenerateRecommendedSettings()

	print("📱 DeviceDetector: Detected", self.deviceType)
	print("   Screen:", self.screenSize.X, "x", self.screenSize.Y)
	print("   Aspect Ratio:", string.format("%.2f", self.aspectRatio))
	print("   Touch:", self.hasTouchscreen)
	print("   Gyroscope:", self.hasGyroscope)
	print("   Accelerometer:", self.hasAccelerometer)

	return self
end

--[[
	Detect safe zones (screen insets)
]]
function DeviceDetector:DetectSafeZones()
	-- Get GUI insets (accounts for notches, system UI)
	local topInset, _ = GuiService:GetGuiInset()

	-- Roblox provides top inset for notches/status bar
	self.safeZones.Top = topInset.Y
	self.safeZones.Left = topInset.X

	-- Bottom and right insets are typically 0 but can be set manually
	-- for devices with bottom navigation bars
	local screenSize = self.screenSize

	-- Detect if device likely has a notch (tall aspect ratio)
	if self.aspectRatio > 2.0 then
		-- Modern phones with notches
		self.safeZones.Top = math.max(self.safeZones.Top, 40)
	end

	-- Detect if device likely has rounded corners
	if self.aspectRatio > 1.9 then
		-- Add padding for rounded corners
		self.safeZones.Left = math.max(self.safeZones.Left, 10)
		self.safeZones.Right = math.max(self.safeZones.Right, 10)
		self.safeZones.Bottom = math.max(self.safeZones.Bottom, 10)
	end
end

--[[
	Classify device type based on screen size
]]
function DeviceDetector:ClassifyDeviceType()
	local width = self.screenSize.X

	if width < 375 then
		-- Small phone (e.g., iPhone SE, old Android phones)
		self.deviceType = DeviceType.SmallPhone
	elseif width >= 375 and width < 768 then
		-- Standard phone (e.g., iPhone 12, most Android phones)
		self.deviceType = DeviceType.Phone
	elseif width >= 768 then
		-- Tablet (e.g., iPad, Android tablets)
		self.deviceType = DeviceType.Tablet
	else
		self.deviceType = DeviceType.Unknown
	end
end

--[[
	Generate recommended settings based on device
]]
function DeviceDetector:GenerateRecommendedSettings()
	local settings = {}

	if self.deviceType == DeviceType.SmallPhone then
		-- Small phone: compact UI, larger essential buttons
		settings.UIScale = 0.85
		settings.ButtonSize = 55
		settings.ThumbstickRadius = 50
		settings.ControlScheme = "Classic"
		settings.ButtonOpacity = 0.8
		settings.ShowLabels = false -- Less space

	elseif self.deviceType == DeviceType.Phone then
		-- Standard phone: default settings
		settings.UIScale = 1.0
		settings.ButtonSize = 65
		settings.ThumbstickRadius = 60
		settings.ControlScheme = "Classic"
		settings.ButtonOpacity = 0.7
		settings.ShowLabels = true

	elseif self.deviceType == DeviceType.Tablet then
		-- Tablet: larger UI, split-screen recommended
		settings.UIScale = 1.2
		settings.ButtonSize = 75
		settings.ThumbstickRadius = 70
		settings.ControlScheme = "Split" -- Suggest split mode for tablets
		settings.ButtonOpacity = 0.6
		settings.ShowLabels = true
		settings.SplitRatio = 0.4
	else
		-- Unknown: use conservative defaults
		settings.UIScale = 1.0
		settings.ButtonSize = 65
		settings.ThumbstickRadius = 60
		settings.ControlScheme = "Classic"
		settings.ButtonOpacity = 0.7
		settings.ShowLabels = true
	end

	-- Adjust for screen aspect ratio
	if self.aspectRatio > 2.0 then
		-- Tall screens: move buttons away from edges
		settings.EdgePadding = 60
	else
		settings.EdgePadding = 40
	end

	-- Enable gyroscope if available
	if self.hasGyroscope then
		settings.GyroscopeAvailable = true
	end

	self.recommendedSettings = settings
end

--[[
	Get device type
]]
function DeviceDetector:GetDeviceType()
	return self.deviceType
end

--[[
	Get screen size
]]
function DeviceDetector:GetScreenSize()
	return self.screenSize
end

--[[
	Get aspect ratio
]]
function DeviceDetector:GetAspectRatio()
	return self.aspectRatio
end

--[[
	Get safe zones
]]
function DeviceDetector:GetSafeZones()
	return self.safeZones
end

--[[
	Check if feature is supported
]]
function DeviceDetector:SupportsFeature(feature)
	local features = {
		Touch = self.hasTouchscreen,
		Gyroscope = self.hasGyroscope,
		Accelerometer = self.hasAccelerometer,
		Haptics = self.hasHaptics,
	}

	return features[feature] or false
end

--[[
	Get recommended settings
]]
function DeviceDetector:GetRecommendedSettings()
	return self.recommendedSettings
end

--[[
	Apply recommended settings to a config table
]]
function DeviceDetector:ApplyRecommendedSettings(config)
	for key, value in pairs(self.recommendedSettings) do
		-- Only apply if config doesn't already have a custom value
		if config[key] == nil then
			config[key] = value
		end
	end

	return config
end

--[[
	Check if device is mobile
]]
function DeviceDetector:IsMobile()
	return self.hasTouchscreen and (
		self.deviceType == DeviceType.SmallPhone or
		self.deviceType == DeviceType.Phone or
		self.deviceType == DeviceType.Tablet
	)
end

--[[
	Check if device is tablet
]]
function DeviceDetector:IsTablet()
	return self.deviceType == DeviceType.Tablet
end

--[[
	Check if device is phone
]]
function DeviceDetector:IsPhone()
	return self.deviceType == DeviceType.SmallPhone or self.deviceType == DeviceType.Phone
end

--[[
	Get UI safe area (accounting for notches and system UI)
]]
function DeviceDetector:GetSafeArea()
	return {
		Min = Vector2.new(self.safeZones.Left, self.safeZones.Top),
		Max = Vector2.new(
			self.screenSize.X - self.safeZones.Right,
			self.screenSize.Y - self.safeZones.Bottom
		),
	}
end

--[[
	Adjust position to be within safe area
]]
function DeviceDetector:AdjustPositionForSafeArea(position)
	local safeArea = self:GetSafeArea()

	return Vector2.new(
		math.clamp(position.X, safeArea.Min.X, safeArea.Max.X),
		math.clamp(position.Y, safeArea.Min.Y, safeArea.Max.Y)
	)
end

return DeviceDetector

