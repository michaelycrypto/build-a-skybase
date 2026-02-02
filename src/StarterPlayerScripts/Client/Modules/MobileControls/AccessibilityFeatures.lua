--[[
	AccessibilityFeatures.lua
	Accessibility features for mobile controls

	Features:
	- UI scaling
	- Colorblind modes
	- High contrast
	- Touch assistance
	- Audio cues
	- Auto-aim/auto-jump
]]

local AccessibilityFeatures = {}
AccessibilityFeatures.__index = AccessibilityFeatures

-- Colorblind modes
local ColorblindMode = {
	None = "None",
	Protanopia = "Protanopia",       -- Red-blind
	Deuteranopia = "Deuteranopia",   -- Green-blind
	Tritanopia = "Tritanopia",       -- Blue-blind
}

function AccessibilityFeatures.new()
	local self = setmetatable({}, AccessibilityFeatures)

	-- Settings
	self.uiScale = 1.0
	self.colorblindMode = ColorblindMode.None
	self.highContrast = false
	self.reduceMotion = false
	self.touchAssistanceLevel = 0 -- 0-3
	self.audioCues = true
	self.hapticIntensity = 1.0
	self.autoJump = false
	self.autoAim = false
	self.stickyButtons = false
	self.minimumTouchSize = 48

	-- Color themes
	self.colorThemes = {
		Default = {
			Primary = Color3.fromRGB(255, 255, 255),
			Secondary = Color3.fromRGB(200, 200, 200),
			Accent = Color3.fromRGB(100, 200, 255),
			Background = Color3.fromRGB(40, 40, 50),
		},
		HighContrast = {
			Primary = Color3.fromRGB(255, 255, 255),
			Secondary = Color3.fromRGB(255, 255, 0),
			Accent = Color3.fromRGB(0, 255, 255),
			Background = Color3.fromRGB(0, 0, 0),
		},
		Protanopia = {
			Primary = Color3.fromRGB(255, 255, 255),
			Secondary = Color3.fromRGB(150, 150, 255),
			Accent = Color3.fromRGB(100, 200, 255),
			Background = Color3.fromRGB(40, 40, 50),
		},
		Deuteranopia = {
			Primary = Color3.fromRGB(255, 255, 255),
			Secondary = Color3.fromRGB(255, 200, 100),
			Accent = Color3.fromRGB(100, 150, 255),
			Background = Color3.fromRGB(40, 40, 50),
		},
		Tritanopia = {
			Primary = Color3.fromRGB(255, 255, 255),
			Secondary = Color3.fromRGB(255, 100, 100),
			Accent = Color3.fromRGB(100, 255, 200),
			Background = Color3.fromRGB(40, 40, 50),
		},
	}

	return self
end

--[[
	Apply UI scale to a GUI element
]]
function AccessibilityFeatures:ApplyUIScale(guiElement)
	if not guiElement or not guiElement:IsA("GuiObject") then
		return
	end

	-- Apply scale through UIScale object
	local uiScale = guiElement:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = guiElement
	end

	uiScale.Scale = self.uiScale
end

--[[
	Set UI scale (0.75 - 1.5)
]]
function AccessibilityFeatures:SetUIScale(scale)
	self.uiScale = math.clamp(scale, 0.75, 1.5)
end

--[[
	Get current color theme
]]
function AccessibilityFeatures:GetColorTheme()
	if self.highContrast then
		return self.colorThemes.HighContrast
	elseif self.colorblindMode ~= ColorblindMode.None then
		return self.colorThemes[self.colorblindMode] or self.colorThemes.Default
	else
		return self.colorThemes.Default
	end
end

--[[
	Apply color theme to a GUI element
]]
function AccessibilityFeatures:ApplyColorTheme(guiElement, colorType)
	if not guiElement or not guiElement:IsA("GuiObject") then
		return
	end

	local theme = self:GetColorTheme()
	local color = theme[colorType] or theme.Primary

	if guiElement:IsA("TextLabel") or guiElement:IsA("TextButton") then
		guiElement.TextColor3 = color
	end

	if guiElement.BackgroundTransparency < 1 then
		guiElement.BackgroundColor3 = color
	end
end

--[[
	Set colorblind mode
]]
function AccessibilityFeatures:SetColorblindMode(mode)
	if self.colorThemes[mode] then
		self.colorblindMode = mode
		print("♿ Colorblind Mode:", mode)
	end
end

--[[
	Set high contrast mode
]]
function AccessibilityFeatures:SetHighContrast(enabled)
	self.highContrast = enabled
	print("♿ High Contrast:", enabled)
end

--[[
	Set reduce motion
]]
function AccessibilityFeatures:SetReduceMotion(enabled)
	self.reduceMotion = enabled
end

--[[
	Set touch assistance level (0-3)
]]
function AccessibilityFeatures:SetTouchAssistance(level)
	self.touchAssistanceLevel = math.clamp(level, 0, 3)

	-- Level 0: No assistance
	-- Level 1: Slight hit box expansion
	-- Level 2: Moderate hit box expansion
	-- Level 3: Large hit box expansion + sticky touches

	print("♿ Touch Assistance Level:", level)
end

--[[
	Get touch assistance radius
]]
function AccessibilityFeatures:GetTouchAssistanceRadius()
	local radiusMap = {
		[0] = 0,
		[1] = 10,
		[2] = 20,
		[3] = 30,
	}

	return radiusMap[self.touchAssistanceLevel] or 0
end

--[[
	Set audio cues enabled
]]
function AccessibilityFeatures:SetAudioCues(enabled)
	self.audioCues = enabled
end

--[[
	Set haptic intensity
]]
function AccessibilityFeatures:SetHapticIntensity(intensity)
	self.hapticIntensity = math.clamp(intensity, 0, 2)
end

--[[
	Set auto-jump
]]
function AccessibilityFeatures:SetAutoJump(enabled)
	self.autoJump = enabled
	print("♿ Auto-Jump:", enabled)
end

--[[
	Set auto-aim
]]
function AccessibilityFeatures:SetAutoAim(enabled)
	self.autoAim = enabled
	print("♿ Auto-Aim:", enabled)
end

--[[
	Set sticky buttons
]]
function AccessibilityFeatures:SetStickyButtons(enabled)
	self.stickyButtons = enabled
end

--[[
	Set minimum touch size
]]
function AccessibilityFeatures:SetMinimumTouchSize(size)
	self.minimumTouchSize = math.max(44, size) -- WCAG minimum is 44x44 points
end

--[[
	Check if element meets minimum touch size
]]
function AccessibilityFeatures:MeetsMinimumTouchSize(guiElement)
	if not guiElement or not guiElement:IsA("GuiObject") then
		return false
	end

	local size = guiElement.AbsoluteSize
	return size.X >= self.minimumTouchSize and size.Y >= self.minimumTouchSize
end

--[[
	Adjust element to meet minimum touch size
]]
function AccessibilityFeatures:EnsureMinimumTouchSize(guiElement)
	if not guiElement or not guiElement:IsA("GuiObject") then
		return
	end

	local currentSize = guiElement.Size
	local pixelSize = guiElement.AbsoluteSize

	local newPixelX = math.max(pixelSize.X, self.minimumTouchSize)
	local newPixelY = math.max(pixelSize.Y, self.minimumTouchSize)

	guiElement.Size = UDim2.new(
		currentSize.X.Scale,
		newPixelX - (currentSize.X.Scale * guiElement.Parent.AbsoluteSize.X),
		currentSize.Y.Scale,
		newPixelY - (currentSize.Y.Scale * guiElement.Parent.AbsoluteSize.Y)
	)
end

--[[
	Get all current accessibility settings
]]
function AccessibilityFeatures:GetSettings()
	return {
		uiScale = self.uiScale,
		colorblindMode = self.colorblindMode,
		highContrast = self.highContrast,
		reduceMotion = self.reduceMotion,
		touchAssistanceLevel = self.touchAssistanceLevel,
		audioCues = self.audioCues,
		hapticIntensity = self.hapticIntensity,
		autoJump = self.autoJump,
		autoAim = self.autoAim,
		stickyButtons = self.stickyButtons,
		minimumTouchSize = self.minimumTouchSize,
	}
end

--[[
	Apply settings from a table
]]
function AccessibilityFeatures:ApplySettings(settings)
	if settings.uiScale then
		self:SetUIScale(settings.uiScale)
	end
	if settings.colorblindMode then
		self:SetColorblindMode(settings.colorblindMode)
	end
	if settings.highContrast ~= nil then
		self:SetHighContrast(settings.highContrast)
	end
	if settings.reduceMotion ~= nil then
		self:SetReduceMotion(settings.reduceMotion)
	end
	if settings.touchAssistanceLevel then
		self:SetTouchAssistance(settings.touchAssistanceLevel)
	end
	if settings.audioCues ~= nil then
		self:SetAudioCues(settings.audioCues)
	end
	if settings.hapticIntensity then
		self:SetHapticIntensity(settings.hapticIntensity)
	end
	if settings.autoJump ~= nil then
		self:SetAutoJump(settings.autoJump)
	end
	if settings.autoAim ~= nil then
		self:SetAutoAim(settings.autoAim)
	end
	if settings.stickyButtons ~= nil then
		self:SetStickyButtons(settings.stickyButtons)
	end
	if settings.minimumTouchSize then
		self:SetMinimumTouchSize(settings.minimumTouchSize)
	end
end

return AccessibilityFeatures

