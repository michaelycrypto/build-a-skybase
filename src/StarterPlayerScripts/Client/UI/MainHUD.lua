--[[
	MainHUD.lua - Main HUD Container
	Creates the root ScreenGui, crosshair, and registers with UIVisibilityManager.
	Currency is displayed by RightSideInfoPanel; action buttons by ActionBar;
	health/hunger/armor by StatusBarsHUD; items by VoxelHotbar.
]]

local MainHUD = {}

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local PanelManager = require(script.Parent.Parent.Managers.PanelManager)
local Crosshair = require(script.Parent.Crosshair)

-- Services and instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local hudGui

--[[
	Create the main HUD
]]
function MainHUD:Create()
	hudGui = Instance.new("ScreenGui")
	hudGui.Name = "MainHUD"
	hudGui.ResetOnSpawn = false
	hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	hudGui.IgnoreGuiInset = true
	hudGui.Parent = playerGui

	-- Responsive scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = hudGui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Center crosshair (Minecraft-style)
	Crosshair:Create(hudGui)

	-- Initialize PanelManager
	PanelManager:Initialize()

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("mainHUD", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 10,
	})
end

--[[
	Show/Hide HUD
]]
function MainHUD:Show()
	if hudGui then
		hudGui.Enabled = true
	end
end

function MainHUD:Hide()
	if hudGui then
		hudGui.Enabled = false
	end
end

function MainHUD:Destroy()
	if hudGui then
		hudGui:Destroy()
		hudGui = nil
	end
end

return MainHUD
