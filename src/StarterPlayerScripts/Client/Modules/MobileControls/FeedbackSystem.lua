--[[
	FeedbackSystem.lua
	Provides visual, haptic, and audio feedback for mobile controls

	Features:
	- Button press feedback
	- Haptic patterns
	- Audio cues
	- Visual effects
]]

local TweenService = game:GetService("TweenService")

local FeedbackSystem = {}
FeedbackSystem.__index = FeedbackSystem

-- Feedback types
local FeedbackType = {
	Light = "Light",
	Medium = "Medium",
	Strong = "Strong",
	Success = "Success",
	Error = "Error",
	Warning = "Warning",
}

function FeedbackSystem.new()
	local self = setmetatable({}, FeedbackSystem)

	-- Configuration
	self.hapticEnabled = true
	self.hapticIntensity = 1.0
	self.audioEnabled = true
	self.audioVolume = 0.5
	self.visualEnabled = true

	-- Sound effects (can be replaced with actual sound IDs)
	self.sounds = {
		ButtonPress = nil, -- Will be loaded from SoundManager
		Success = nil,
		Error = nil,
		Warning = nil,
	}

	-- Visual effect templates
	self.effectTemplates = {}

	return self
end

--[[
	Initialize feedback system
]]
function FeedbackSystem:Initialize(soundManager)
	self.soundManager = soundManager

	-- Load sounds if SoundManager is available
	-- selene: allow(empty_if)
	if soundManager then
		-- Implement sound loading if needed
	end

	print("✅ FeedbackSystem: Initialized")
end

--[[
	Set SoundManager (for deferred initialization to avoid circular dependencies)
]]
function FeedbackSystem:SetSoundManager(soundManager)
	self.soundManager = soundManager
end

--[[
	Play haptic feedback
]]
function FeedbackSystem:PlayHaptic(feedbackType, customIntensity)
	if not self.hapticEnabled then return end

	-- Calculate intensity
	local intensity = customIntensity or self.hapticIntensity

	-- Map feedback types to intensities
	local intensityMap = {
		[FeedbackType.Light] = 0.3,
		[FeedbackType.Medium] = 0.5,
		[FeedbackType.Strong] = 0.8,
		[FeedbackType.Success] = 0.5,
		[FeedbackType.Error] = 0.7,
		[FeedbackType.Warning] = 0.6,
	}

	local baseIntensity = intensityMap[feedbackType] or 0.5
	local _finalIntensity = baseIntensity * intensity

	-- Note: Roblox doesn't have native haptic feedback API yet
	-- This is prepared for when the feature becomes available
	-- Placeholder for future haptic motor hook (requires engine support)

	-- For now, we can use a placeholder or wait for Roblox to add the API
	-- Placeholder: print haptic feedback
	-- print("Haptic:", feedbackType, "Intensity:", finalIntensity)
end

--[[
	Play audio feedback
]]
function FeedbackSystem:PlayAudio(feedbackType, customVolume)
	if not self.audioEnabled then return end

	local _volume = customVolume or self.audioVolume

	-- Use SoundManager if available
	if self.soundManager and self.soundManager.PlaySFXSafely then
		local soundMap = {
			[FeedbackType.Light] = "uiClick",
			[FeedbackType.Medium] = "uiClick",
			[FeedbackType.Strong] = "uiClick",
			[FeedbackType.Success] = "success",
			[FeedbackType.Error] = "error",
			[FeedbackType.Warning] = "warning",
		}

		local soundName = soundMap[feedbackType]
		if soundName then
			self.soundManager:PlaySFXSafely(soundName)
		end
	end
end

--[[
	Play visual feedback
]]
function FeedbackSystem:PlayVisual(element, feedbackType)
	if not self.visualEnabled or not element then return end

	if feedbackType == FeedbackType.Light or feedbackType == FeedbackType.Medium then
		-- Simple highlight effect
		self:HighlightElement(element)
	elseif feedbackType == FeedbackType.Strong then
		-- More pronounced effect
		self:PulseElement(element)
	elseif feedbackType == FeedbackType.Success then
		-- Green flash
		self:FlashElement(element, Color3.fromRGB(100, 255, 100))
	elseif feedbackType == FeedbackType.Error then
		-- Red flash
		self:FlashElement(element, Color3.fromRGB(255, 100, 100))
	elseif feedbackType == FeedbackType.Warning then
		-- Yellow flash
		self:FlashElement(element, Color3.fromRGB(255, 255, 100))
	end
end

--[[
	Highlight element (brief brightness increase)
]]
function FeedbackSystem:HighlightElement(element)
	if not element:IsA("GuiObject") then return end

	local originalTransparency = element.BackgroundTransparency
	local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Brighten
	local brighten = TweenService:Create(element, tweenInfo, {
		BackgroundTransparency = math.max(0, originalTransparency - 0.2)
	})

	brighten.Completed:Connect(function()
		-- Dim back
		local dim = TweenService:Create(element, tweenInfo, {
			BackgroundTransparency = originalTransparency
		})
		dim:Play()
	end)

	brighten:Play()
end

--[[
	Pulse element (scale animation)
]]
function FeedbackSystem:PulseElement(element)
	if not element:IsA("GuiObject") then return end

	local originalSize = element.Size
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Scale up
	local scaleUp = TweenService:Create(element, tweenInfo, {
		Size = UDim2.new(
			originalSize.X.Scale * 1.1,
			originalSize.X.Offset * 1.1,
			originalSize.Y.Scale * 1.1,
			originalSize.Y.Offset * 1.1
		)
	})

	scaleUp.Completed:Connect(function()
		-- Scale back
		local scaleDown = TweenService:Create(element, tweenInfo, {
			Size = originalSize
		})
		scaleDown:Play()
	end)

	scaleUp:Play()
end

--[[
	Flash element with color
]]
function FeedbackSystem:FlashElement(element, color)
	if not element:IsA("GuiObject") then return end

	local originalColor = element.BackgroundColor3
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Flash color
	local flash = TweenService:Create(element, tweenInfo, {
		BackgroundColor3 = color
	})

	flash.Completed:Connect(function()
		-- Return to original
		local restore = TweenService:Create(element, tweenInfo, {
			BackgroundColor3 = originalColor
		})
		restore:Play()
	end)

	flash:Play()
end

--[[
	Create ripple effect at position
]]
function FeedbackSystem:CreateRipple(parent, position, color)
	if not self.visualEnabled or not parent then return end

	local ripple = Instance.new("Frame")
	ripple.Size = UDim2.fromOffset(10, 10)
	ripple.Position = UDim2.fromOffset(position.X - 5, position.Y - 5)
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.BackgroundColor3 = color or Color3.fromRGB(255, 255, 255)
	ripple.BackgroundTransparency = 0.5
	ripple.BorderSizePixel = 0
	ripple.ZIndex = 10
	ripple.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ripple

	-- Animate ripple
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local expand = TweenService:Create(ripple, tweenInfo, {
		Size = UDim2.fromOffset(100, 100),
		BackgroundTransparency = 1
	})

	expand.Completed:Connect(function()
		ripple:Destroy()
	end)

	expand:Play()
end

--[[
	Combined feedback (haptic + audio + visual)
]]
function FeedbackSystem:PlayFeedback(feedbackType, element, options)
	options = options or {}

	-- Play haptic
	if options.haptic ~= false then
		self:PlayHaptic(feedbackType, options.hapticIntensity)
	end

	-- Play audio
	if options.audio ~= false then
		self:PlayAudio(feedbackType, options.audioVolume)
	end

	-- Play visual
	if options.visual ~= false and element then
		self:PlayVisual(element, feedbackType)
	end
end

--[[
	Button press feedback (common pattern)
]]
function FeedbackSystem:OnButtonPress(button)
	self:PlayFeedback(FeedbackType.Light, button, {
		haptic = true,
		audio = true,
		visual = true,
	})
end

--[[
	Action success feedback
]]
function FeedbackSystem:OnActionSuccess(element)
	self:PlayFeedback(FeedbackType.Success, element, {
		haptic = true,
		audio = true,
		visual = true,
	})
end

--[[
	Action error feedback
]]
function FeedbackSystem:OnActionError(element)
	self:PlayFeedback(FeedbackType.Error, element, {
		haptic = true,
		audio = true,
		visual = true,
	})
end

--[[
	Set haptic enabled
]]
function FeedbackSystem:SetHapticEnabled(enabled)
	self.hapticEnabled = enabled
end

--[[
	Set haptic intensity
]]
function FeedbackSystem:SetHapticIntensity(intensity)
	self.hapticIntensity = math.clamp(intensity, 0, 2)
end

--[[
	Set audio enabled
]]
function FeedbackSystem:SetAudioEnabled(enabled)
	self.audioEnabled = enabled
end

--[[
	Set audio volume
]]
function FeedbackSystem:SetAudioVolume(volume)
	self.audioVolume = math.clamp(volume, 0, 1)
end

--[[
	Set visual enabled
]]
function FeedbackSystem:SetVisualEnabled(enabled)
	self.visualEnabled = enabled
end

return FeedbackSystem

