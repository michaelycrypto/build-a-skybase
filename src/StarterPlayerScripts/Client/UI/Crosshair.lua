--[[
	Crosshair.lua - Minecraft-style crosshair (plus sign)
	Creates a simple, crisp crosshair centered on the screen using UI Frames.
	The crosshair is composed of a vertical and horizontal bar in light grey,
	flat, matching Minecraft's minimal aesthetic.

	NOTE: This crosshair is only shown in FIRST PERSON mode.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
	bar.Position = UDim2.new(0.5, 0, 0.5, 0)
	bar.ZIndex = 10

	if isHorizontal then
		bar.Size = UDim2.new(0, CROSSHAIR_LENGTH, 0, CROSSHAIR_THICKNESS)
	else
		bar.Size = UDim2.new(0, CROSSHAIR_THICKNESS, 0, CROSSHAIR_LENGTH)
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
	crosshairContainer.Size = UDim2.new(0, 0, 0, 0)
	crosshairContainer.Position = UDim2.new(0.5, 0, 0.5, 0)

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

	-- Update visibility based on camera mode
	task.spawn(function()
		while true do
			task.wait(0.1)

			if crosshairContainer then
				local isFirstPerson = GameState:Get("camera.isFirstPerson")
				local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

				-- Show crosshair:
				-- - Always in first person mode
				-- - On mobile devices (for tap targeting)
				local shouldShow = (isFirstPerson ~= false) or isMobile
				crosshairContainer.Visible = shouldShow
			end
		end
	end)
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


