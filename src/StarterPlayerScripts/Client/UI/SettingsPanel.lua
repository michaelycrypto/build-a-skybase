--[[
	SettingsPanel.lua - Game Settings Panel
	Handles audio settings with UIComponents form controls
--]]

local SettingsPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local GameState = require(script.Parent.Parent.Managers.GameState)

-- Services and instances
local player = Players.LocalPlayer

-- UI Elements
local panel = nil

--[[
	Create content for PanelManager integration
--]]
function SettingsPanel:CreateContent(contentFrame, data)
	panel = {contentFrame = contentFrame}

	local mainContainer = Instance.new("Frame")
	mainContainer.Size = UDim2.new(1, -40, 1, -40) -- Add 20px margin on all sides
	mainContainer.Position = UDim2.new(0, 20, 0, 20)
	mainContainer.BackgroundTransparency = 1
	mainContainer.Parent = contentFrame

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = Enum.VerticalAlignment.Top
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 15) -- Increased padding between elements
	layout.Parent = mainContainer

	-- Header
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 35) -- Slightly taller header
	header.BackgroundTransparency = 1
	header.Text = "🔊 Audio Settings"
	header.TextColor3 = Color3.fromRGB(255, 255, 255)
	header.TextSize = 20 -- Slightly larger text
	header.Font = Enum.Font.GothamBold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = 1
	header.Parent = mainContainer

	-- Load settings from GameState (with fallbacks)
	local gameStateSettings = GameState:Get("settings") or {}
	local soundEnabled = gameStateSettings.soundEnabled
	local musicVolume = gameStateSettings.musicVolume
	local sfxVolume = gameStateSettings.sfxVolume

	-- If no GameState settings, get from SoundManager as fallback
	if soundEnabled == nil or musicVolume == nil or sfxVolume == nil then
		local volumeSettings = SoundManager:GetVolumeSettings()
		soundEnabled = soundEnabled ~= nil and soundEnabled or volumeSettings.soundEnabled
		musicVolume = musicVolume or volumeSettings.musicVolume
		sfxVolume = sfxVolume or volumeSettings.sfxVolume

		-- Store initial values in GameState
		GameState:Set("settings.soundEnabled", soundEnabled)
		GameState:Set("settings.musicVolume", musicVolume)
		GameState:Set("settings.sfxVolume", sfxVolume)
	end

	-- Master toggle using UIComponents
	self.masterToggle = UIComponents:CreateToggleSwitch({
		parent = mainContainer,
		label = "Master Audio",
		enabled = soundEnabled,
		layoutOrder = 2,
		callback = function(enabled)
			-- Only update GameState - SoundManager will react to GameState changes
			GameState:Set("settings.soundEnabled", enabled)
		end
	})

	-- Music slider using UIComponents
	self.musicSlider = UIComponents:CreateSlider({
		parent = mainContainer,
		label = "Music Volume",
		value = musicVolume,
		layoutOrder = 3,
		callback = function(value)
			-- Only update GameState - SoundManager will react to GameState changes
			GameState:Set("settings.musicVolume", value)
		end
	})
	self.musicSlider.container.Visible = soundEnabled

	-- SFX slider using UIComponents
	self.sfxSlider = UIComponents:CreateSlider({
		parent = mainContainer,
		label = "SFX Volume",
		value = sfxVolume,
		layoutOrder = 4,
		callback = function(value)
			-- Only update GameState - SoundManager will react to GameState changes
			GameState:Set("settings.sfxVolume", value)
		end
	})
	self.sfxSlider.container.Visible = soundEnabled

	print("SettingsPanel: Created with UIComponents form controls")
end

function SettingsPanel:Initialize()
	-- Listen for GameState changes to update UI
	GameState:OnPropertyChanged("settings.soundEnabled", function(newValue, oldValue, path)
		if self.masterToggle and newValue ~= nil then
			self.masterToggle.setEnabled(newValue, true) -- Silent update to prevent callback loop

			-- Show/hide volume sliders based on master toggle
			if self.musicSlider then
				self.musicSlider.container.Visible = newValue
			end
			if self.sfxSlider then
				self.sfxSlider.container.Visible = newValue
			end
		end
	end)

	GameState:OnPropertyChanged("settings.musicVolume", function(newValue, oldValue, path)
		if self.musicSlider and newValue ~= nil then
			self.musicSlider.setValue(newValue, true) -- Silent update to prevent callback loop
		end
	end)

	GameState:OnPropertyChanged("settings.sfxVolume", function(newValue, oldValue, path)
		if self.sfxSlider and newValue ~= nil then
			self.sfxSlider.setValue(newValue, true) -- Silent update to prevent callback loop
		end
	end)

	print("SettingsPanel: Initialized with GameState listeners")
end

return SettingsPanel