--[[
	UIBackdrop.lua - Reusable Backdrop System
	Provides dark overlay for any UI component
	Singleton pattern - only one backdrop active at a time

	Mouse Lock Fix:
	- Uses TextButton.Modal = true to tell Roblox to release mouse lock
	- Continuously enforces MouseBehavior.Default while visible (fights PlayerModule)
]]

local UIBackdrop = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Singleton state
local backdropGui = nil
local overlayFrame = nil
local isVisible = false
local currentConfig = nil
local overlayTween = nil
local mouseEnforceConnection = nil

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

	-- Cleanup any existing UIBackdropBlur instances from Lighting
	local existingBlur = Lighting:FindFirstChild("UIBackdropBlur")
	if existingBlur then
		existingBlur:Destroy()
	end

	-- Create ScreenGui with IgnoreGuiInset for fullscreen coverage
	backdropGui = Instance.new("ScreenGui")
	backdropGui.Name = "UIBackdrop"
	backdropGui.ResetOnSpawn = false
	backdropGui.IgnoreGuiInset = true  -- Fullscreen
	backdropGui.DisplayOrder = DEFAULT_CONFIG.displayOrder
	backdropGui.Enabled = false
	backdropGui.Parent = playerGui

	-- Create overlay as TextButton (not Frame) because Modal property only exists on interactive elements
	-- TextButton with empty text acts like a Frame but supports Modal
	overlayFrame = Instance.new("TextButton")
	overlayFrame.Name = "Overlay"
	overlayFrame.Size = UDim2.new(1, 0, 1, 0)
	overlayFrame.Position = UDim2.new(0, 0, 0, 0)
	overlayFrame.BackgroundColor3 = DEFAULT_CONFIG.overlayColor
	overlayFrame.BackgroundTransparency = 1  -- Start hidden
	overlayFrame.BorderSizePixel = 0
	overlayFrame.Text = ""
	overlayFrame.AutoButtonColor = false
	overlayFrame.Active = true  -- Required for Modal to work
	overlayFrame.Modal = true   -- KEY: Tells Roblox to release mouse lock when mouse is over this element
	overlayFrame.Parent = backdropGui

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
	overlayTween = nil

	isVisible = true
	backdropGui.Enabled = true

	-- Update display order
	if config and config.displayOrder then
		backdropGui.DisplayOrder = config.displayOrder
	end

	-- Re-enable Modal (disabled in Hide() to allow cursor lock restoration) and set color
	if overlayFrame then
		overlayFrame.Modal = true
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

	-- Setup tap callback if provided
	-- The overlay is now a TextButton, so we connect directly to it
	if currentConfig.onTap then
		if not hasTapDetector() then
			-- Create a marker to track that we've connected
			local marker = Instance.new("BoolValue")
			marker.Name = "TapDetector"
			marker.Parent = overlayFrame

			overlayFrame.MouseButton1Click:Connect(function()
				if currentConfig and currentConfig.onTap then
					currentConfig.onTap()
				end
			end)
		end
	end

	-- Continuously enforce mouse unlock while UI is visible
	-- This fights Roblox's PlayerModule which tries to lock the mouse every frame
	if mouseEnforceConnection then
		mouseEnforceConnection:Disconnect()
	end

	mouseEnforceConnection = RunService.RenderStepped:Connect(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	print("UIBackdrop: Shown with overlay=" .. tostring(currentConfig.overlay))
end

--[[
	Hide the backdrop with animation
	@param callback: function - Optional callback when hide animation completes
]]
function UIBackdrop:Hide(callback)
	if not backdropGui then return end

	if not isVisible and not overlayTween then
		-- Already hidden
		return
	end

	isVisible = false

	-- Disable Modal immediately to stop fighting cursor lock restoration
	-- Modal=true tells Roblox to release mouse lock, which interferes with
	-- CameraController's attempt to re-lock the cursor during close animation
	if overlayFrame then
		overlayFrame.Modal = false
	end

	-- Stop enforcing mouse unlock
	if mouseEnforceConnection then
		mouseEnforceConnection:Disconnect()
		mouseEnforceConnection = nil
	end

	stopTween(overlayTween)

	local duration = currentConfig and currentConfig.animationDuration or DEFAULT_CONFIG.animationDuration

	-- Hide overlay with animation
	overlayTween = TweenService:Create(
		overlayFrame,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }
	)

	local function finalizeHide()
		if isVisible then
			return
		end
		if overlayTween then
			return
		end

		backdropGui.Enabled = false

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

	-- Stop enforcing mouse unlock
	if mouseEnforceConnection then
		mouseEnforceConnection:Disconnect()
		mouseEnforceConnection = nil
	end

	if backdropGui then
		backdropGui:Destroy()
		backdropGui = nil
	end

	overlayFrame = nil
	currentConfig = nil

	print("UIBackdrop: Cleaned up")
end

return UIBackdrop

