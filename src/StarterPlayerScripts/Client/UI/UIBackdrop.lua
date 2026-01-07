--[[
	UIBackdrop.lua - Reusable Backdrop System
	Provides blur effect + dark overlay for any UI component
	Singleton pattern - only one backdrop active at a time
]]

local UIBackdrop = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Singleton state
local backdropGui = nil
local overlayFrame = nil
local blurEffect = nil
local isVisible = false
local currentConfig = nil
local overlayTween = nil
local blurTween = nil

local function stopTween(tween)
	if tween then
		tween:Cancel()
	end
end

local function hasTapDetector()
	return overlayFrame and overlayFrame:FindFirstChild("TapDetector")
end

local function removeTapDetector()
	if overlayFrame then
		local tapDetector = overlayFrame:FindFirstChild("TapDetector")
		if tapDetector then
			tapDetector:Destroy()
		end
	end
end

-- Default configuration
local DEFAULT_CONFIG = {
	blur = true,
	blurSize = 24,
	overlay = true,
	overlayColor = Color3.fromRGB(4, 4, 6),
	overlayTransparency = 0.35,
	displayOrder = 50,
	onTap = nil,  -- Optional callback when backdrop is tapped
	animationDuration = 0.2
}

--[[
	Initialize the backdrop (create UI elements)
]]
local function initialize()
	if backdropGui then return end

	-- Create ScreenGui with IgnoreGuiInset for fullscreen coverage
	backdropGui = Instance.new("ScreenGui")
	backdropGui.Name = "UIBackdrop"
	backdropGui.ResetOnSpawn = false
	backdropGui.IgnoreGuiInset = true  -- Fullscreen
	backdropGui.DisplayOrder = DEFAULT_CONFIG.displayOrder
	backdropGui.Enabled = false
	backdropGui.Parent = playerGui

	-- Create overlay frame
	overlayFrame = Instance.new("Frame")
	overlayFrame.Name = "Overlay"
	overlayFrame.Size = UDim2.new(1, 0, 1, 0)
	overlayFrame.Position = UDim2.new(0, 0, 0, 0)
	overlayFrame.BackgroundColor3 = DEFAULT_CONFIG.overlayColor
	overlayFrame.BackgroundTransparency = 1  -- Start hidden
	overlayFrame.BorderSizePixel = 0
	overlayFrame.Parent = backdropGui

	-- Create blur effect in Lighting
	blurEffect = Instance.new("BlurEffect")
	blurEffect.Name = "UIBackdropBlur"
	blurEffect.Size = 0  -- Start at 0
	blurEffect.Enabled = false
	blurEffect.Parent = Lighting

	print("UIBackdrop: Initialized singleton backdrop system")
end

--[[
	Show the backdrop with optional configuration
	@param config: table - Optional configuration overrides
]]
function UIBackdrop:Show(config)
	initialize()

	-- Merge config with defaults
	currentConfig = {}
	for key, value in pairs(DEFAULT_CONFIG) do
		currentConfig[key] = (config and config[key] ~= nil) and config[key] or value
	end

	stopTween(overlayTween)
	stopTween(blurTween)
	overlayTween = nil
	blurTween = nil

	isVisible = true
	backdropGui.Enabled = true

	-- Update display order
	if config and config.displayOrder then
		backdropGui.DisplayOrder = config.displayOrder
	end

	if overlayFrame then
		overlayFrame.BackgroundColor3 = currentConfig.overlayColor
	end

	-- Show overlay with animation
	if currentConfig.overlay then
		overlayTween = TweenService:Create(
			overlayFrame,
			TweenInfo.new(currentConfig.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = currentConfig.overlayTransparency }
		)
		overlayTween.Completed:Connect(function()
			overlayTween = nil
		end)
		overlayTween:Play()
	else
		overlayFrame.BackgroundTransparency = 1
	end

	-- Show blur with animation
	if currentConfig.blur and blurEffect then
		blurEffect.Enabled = true
		blurTween = TweenService:Create(
			blurEffect,
			TweenInfo.new(currentConfig.animationDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = currentConfig.blurSize }
		)
		blurTween.Completed:Connect(function()
			blurTween = nil
		end)
		blurTween:Play()
	else
		if blurEffect then
			blurEffect.Enabled = false
		end
	end

	-- Setup tap callback if provided
	if currentConfig.onTap then
		if not hasTapDetector() then
			local tapDetector = Instance.new("TextButton")
			tapDetector.Name = "TapDetector"
			tapDetector.Size = UDim2.new(1, 0, 1, 0)
			tapDetector.BackgroundTransparency = 1
			tapDetector.Text = ""
			tapDetector.Parent = overlayFrame

			tapDetector.MouseButton1Click:Connect(function()
				if currentConfig.onTap then
					currentConfig.onTap()
				end
			end)
		end
	end

	print("UIBackdrop: Shown with blur=" .. tostring(currentConfig.blur) .. " overlay=" .. tostring(currentConfig.overlay))
end

--[[
	Hide the backdrop with animation
	@param callback: function - Optional callback when hide animation completes
]]
function UIBackdrop:Hide(callback)
	if not backdropGui then return end

	if not isVisible and (not overlayTween and not blurTween) then
		-- Already hidden
		return
	end

	isVisible = false

	stopTween(overlayTween)
	stopTween(blurTween)

	local duration = currentConfig and currentConfig.animationDuration or DEFAULT_CONFIG.animationDuration

	-- Hide overlay with animation
	overlayTween = TweenService:Create(
		overlayFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)

	-- Hide blur with animation
	if blurEffect then
		blurTween = TweenService:Create(
			blurEffect,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = 0 }
		)
	end

	local function finalizeHide()
		if isVisible then
			return
		end
		if overlayTween or blurTween then
			return
		end

		backdropGui.Enabled = false
		if blurEffect then
			blurEffect.Enabled = false
		end

		-- Remove tap detector
		removeTapDetector()

		if callback then
			callback()
		end

		print("UIBackdrop: Hidden")
	end

	overlayTween.Completed:Connect(function()
		overlayTween = nil
		finalizeHide()
	end)
	overlayTween:Play()

	if blurTween then
		blurTween.Completed:Connect(function()
			blurTween = nil
			finalizeHide()
		end)
		blurTween:Play()
	else
		blurTween = nil
	end
end

--[[
	Update backdrop configuration (while visible)
	@param config: table - Configuration changes
]]
function UIBackdrop:UpdateConfig(config)
	if not config then return end

	-- Update current config
	if currentConfig then
		for key, value in pairs(config) do
			if currentConfig[key] ~= nil then
				currentConfig[key] = value
			end
		end
	else
		currentConfig = config
	end

	-- Apply changes with animation
	local duration = currentConfig.animationDuration

	if config.overlayTransparency and overlayFrame then
		stopTween(overlayTween)
		overlayTween = TweenService:Create(
			overlayFrame,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = config.overlayTransparency }
		)
		overlayTween.Completed:Connect(function()
			overlayTween = nil
		end)
		overlayTween:Play()
	end

	if config.overlayColor and overlayFrame then
		overlayFrame.BackgroundColor3 = config.overlayColor
	end

	if config.blurSize and blurEffect then
		stopTween(blurTween)
		if not blurEffect.Enabled then
			blurEffect.Enabled = true
		end
		blurTween = TweenService:Create(
			blurEffect,
			TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = config.blurSize }
		)
		blurTween.Completed:Connect(function()
			blurTween = nil
		end)
		blurTween:Play()
	end

	if config.displayOrder and backdropGui then
		backdropGui.DisplayOrder = config.displayOrder
	end
end

--[[
	Check if backdrop is currently visible
	@return: boolean
]]
function UIBackdrop:IsVisible()
	return isVisible
end

--[[
	Get current configuration
	@return: table
]]
function UIBackdrop:GetConfig()
	return currentConfig
end

--[[
	Cleanup backdrop (removes all instances)
]]
function UIBackdrop:Cleanup()
	isVisible = false

	if backdropGui then
		backdropGui:Destroy()
		backdropGui = nil
	end

	if blurEffect then
		blurEffect:Destroy()
		blurEffect = nil
	end

	overlayFrame = nil
	currentConfig = nil

	print("UIBackdrop: Cleaned up")
end

return UIBackdrop

