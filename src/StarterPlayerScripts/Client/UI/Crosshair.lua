--[[
	Crosshair.lua - Minecraft-style crosshair (plus sign)
	Creates a simple, crisp crosshair centered on the screen using UI Frames.
	The crosshair is composed of a vertical and horizontal bar in light grey,
	flat, matching Minecraft's minimal aesthetic.

	Visibility is controlled by camera.targetingMode in GameState:
	  - "crosshair" mode: Crosshair VISIBLE (first person, third person lock)
	  - "direct" mode: Crosshair HIDDEN (third person free - click/tap targeting)
--]]

local Players = game:GetService("Players")

local GameState = require(script.Parent.Parent.Managers.GameState)

local Crosshair = {}

-- Internal state
local crosshairContainer

-- Tweakable appearance (pixel sizes)
local CROSSHAIR_LENGTH = 16		-- total length of each bar in pixels
local CROSSHAIR_THICKNESS = 2	-- thickness of the bars in pixels
local CROSSHAIR_COLOR = Color3.fromRGB(200, 200, 200)

-- Create one bar (horizontal or vertical)
local function createBar(parent, isHorizontal)
	local bar = Instance.new("Frame")
	bar.Name = isHorizontal and "HorizontalBar" or "VerticalBar"
	bar.BackgroundColor3 = CROSSHAIR_COLOR
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(0.5, 0.5)
	bar.ZIndex = 10

	if isHorizontal then
		bar.Size = UDim2.fromOffset(CROSSHAIR_LENGTH, CROSSHAIR_THICKNESS)
	else
		bar.Size = UDim2.fromOffset(CROSSHAIR_THICKNESS, CROSSHAIR_LENGTH)
	end

	bar.Parent = parent
	return bar
end

function Crosshair:Create(parentHudGui)
	if crosshairContainer and crosshairContainer.Parent then return end

	-- Create a centered, invisible container to hold the bars
	crosshairContainer = Instance.new("Frame")
	crosshairContainer.Name = "Crosshair"
	crosshairContainer.BackgroundTransparency = 1
	crosshairContainer.BorderSizePixel = 0
	crosshairContainer.ZIndex = 10
	crosshairContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshairContainer.Size = UDim2.fromScale(0, 0)
	crosshairContainer.Position = UDim2.fromScale(0.5, 0.5)

	-- Parent to the HUD if provided; otherwise attach to PlayerGui
	if parentHudGui then
		crosshairContainer.Parent = parentHudGui
	else
		local player = Players.LocalPlayer
		local playerGui = player and player:FindFirstChild("PlayerGui") or nil
		if not playerGui then
			playerGui = player and player:WaitForChild("PlayerGui")
		end
		crosshairContainer.Parent = playerGui
	end

	-- Create horizontal and vertical bars
	createBar(crosshairContainer, true)
	createBar(crosshairContainer, false)

	-- Update visibility based on targeting mode
	local function updateVisibility()
		if not crosshairContainer then return end

		-- Show crosshair only in "crosshair" targeting mode
		-- Hide in "direct" mode (user clicks/taps directly on targets)
		local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"
		crosshairContainer.Visible = (targetingMode == "crosshair")
	end

	-- Update on targeting mode change
	GameState:OnPropertyChanged("camera.targetingMode", updateVisibility)

	-- Initial update
	updateVisibility()
end

function Crosshair:SetVisible(isVisible)
	if crosshairContainer then
		crosshairContainer.Visible = isVisible and true or false
	end
end

function Crosshair:Destroy()
	if crosshairContainer then
		crosshairContainer:Destroy()
		crosshairContainer = nil
	end
end

return Crosshair


