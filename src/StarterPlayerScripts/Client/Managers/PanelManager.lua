--[[
	PanelManager.lua - Unified Panel Management System
	Handles opening, closing, and toggling various game panels with consistent animations
--]]

local PanelManager = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local UIComponents = require(script.Parent.UIComponents)
local SoundManager = require(script.Parent.SoundManager)

-- Services and instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Panel management state
local registeredPanels = {}
local activePanels = {}
local panelStack = {} -- For managing panel layering
local lastToggleTime = {} -- Simple debouncing per panel
local nextZIndex = 100

-- Animation settings
local ANIMATION_SETTINGS = {
	duration = {
		fast = 0.15,
		normal = 0.25,
		slow = 0.4
	},
	easing = {
		bounce = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		smooth = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		snap = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	}
}

-- Panel size configurations
local PANEL_SIZES = {
	small = {size = UDim2.new(0, 300, 0, 200)},
	medium = {size = UDim2.new(0, 400, 0, 300)},
	large = {size = UDim2.new(0, 500, 0, 600)},
	-- Custom sizes for specific use cases
	emote_wide = {
		size = UDim2.new(0, 630, 0, 180),
		position = UDim2.new(0.5, 0, 1, -290),
		anchorPoint = Vector2.new(0.5, 0)
	},
	daily_rewards_compact = {
		size = UDim2.new(0, 560, 0, 330), -- Increased height by 30px to prevent button overlap
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	},
	settings_compact = {
		size = UDim2.new(0, 450, 0, 280), -- Compact size for audio settings
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	},
	inventory_compact = {
		size = UDim2.new(0, 520, 0, 420), -- More compact size
		position = UDim2.new(0.5, 0, 0.5, 0), -- Left-aligned with 240px offset
		anchorPoint = Vector2.new(0.5, 0.5)
	},
	-- Left-docked compact panel for build selector to mirror shop styling but as a sidebar
	build_left = {
		size = UDim2.new(0, 380, 0, 420),
		position = UDim2.new(0, 20, 0.5, 0),
		anchorPoint = Vector2.new(0, 0.5)
	},
	shop = {
		size = UDim2.new(0, 440, 0, 360), -- Wide size for shop side-by-side layout
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	}
}

-- Panel types configuration
local PANEL_TYPES = {
	overlay = {
		hasBackdrop = true,
		backdropTransparency = Config.UI_SETTINGS.designSystem.transparency.backdrop,
		closeOnBackdrop = false, -- Disabled for straightforward panel behavior
		animation = "bounce",
		centerPosition = true
	},
	popup = {
		hasBackdrop = true,
		backdropTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy,
		closeOnBackdrop = false, -- Disabled for straightforward panel behavior
		animation = "smooth",
		centerPosition = true
	},
	sidebar = {
		hasBackdrop = false,
		closeOnBackdrop = false,
		animation = "smooth",
		centerPosition = false
	},
	toast = {
		hasBackdrop = false,
		closeOnBackdrop = false,
		animation = "snap",
		centerPosition = false,
		autoClose = true,
		autoCloseDelay = 3
	}
}

--[[
	Initialize the Panel Manager
--]]
function PanelManager:Initialize()
	print("PanelManager: Initializing unified panel system")

	-- Register built-in panels
	self:RegisterBuiltInPanels()

	print("PanelManager: System ready")
end

--[[
	Register a panel configuration
	@param panelId: string - Unique identifier for the panel
	@param config: table - Panel configuration
--]]
function PanelManager:RegisterPanel(panelId, config)
	local panelConfig = config or {}

	-- Validate required fields
	if not panelId or not panelConfig.create then
		warn("PanelManager: Invalid panel registration - missing panelId or create function")
		return false
	end

	-- Set defaults
	local finalConfig = {
		id = panelId,
		title = panelConfig.title or panelId,
		type = panelConfig.type or "overlay",
		size = panelConfig.size or "medium",
		icon = panelConfig.icon,
		create = panelConfig.create, -- Function that creates the panel content
		onShow = panelConfig.onShow, -- Optional callback when panel shows
		onHide = panelConfig.onHide, -- Optional callback when panel hides
		data = panelConfig.data or {}, -- Panel-specific data
		headerless = panelConfig.headerless or false,
		closable = panelConfig.closable,
		allowMultiple = panelConfig.allowMultiple or false, -- Allow multiple instances
		persistent = panelConfig.persistent or false -- Keep in memory when closed
	}

	registeredPanels[panelId] = finalConfig
	print("PanelManager: Registered panel -", panelId)
	return true
end

--[[
	Open a panel
	@param panelId: string - Panel identifier
	@param data: table - Optional data to pass to the panel
	@return: table - Panel instance or nil if failed
--]]
function PanelManager:OpenPanel(panelId, data)
	local config = registeredPanels[panelId]
	if not config then
		warn("PanelManager: Panel not registered -", panelId)
		return nil
	end

	-- Check if panel is already open and multiple instances aren't allowed
	if activePanels[panelId] and not config.allowMultiple then
		return activePanels[panelId]
	end

	-- Close all other panels first (ensures only one panel active at a time)
	for otherPanelId, _ in pairs(activePanels) do
		if otherPanelId ~= panelId then
			self:ClosePanel(otherPanelId)
		end
	end

	-- Create the panel
	local panelInstance = self:CreatePanelInstance(config, data)
	if not panelInstance then
		warn("PanelManager: Failed to create panel -", panelId)
		return nil
	end

	-- Register as active
	activePanels[panelId] = panelInstance
	table.insert(panelStack, panelInstance)

	-- Show the panel with animation
	self:ShowPanel(panelInstance)

	-- Play sound
	if SoundManager then
		SoundManager:PlaySFX("buttonClick")
	end

	return panelInstance
end

--[[
	Close a panel
	@param panelId: string - Panel identifier
--]]
function PanelManager:ClosePanel(panelId)
	local panelInstance = activePanels[panelId]
	if not panelInstance then
		return false
	end

	-- Remove from active panels immediately
	activePanels[panelId] = nil

	-- Remove from panel stack
	for i, panel in ipairs(panelStack) do
		if panel == panelInstance then
			table.remove(panelStack, i)
			break
		end
	end

	-- Hide the panel with animation
	self:HidePanel(panelInstance, function()
		-- Cleanup after animation
		self:CleanupPanel(panelInstance)
	end)

	return true
end

--[[
	Toggle a panel (open if closed, close if open)
	@param panelId: string - Panel identifier
	@param data: table - Optional data to pass when opening
	@return: boolean - True if opened, false if closed, nil if ignored
--]]
function PanelManager:TogglePanel(panelId, data)
	-- Simple debouncing: ignore rapid clicks within 300ms
	local currentTime = tick()
	local lastTime = lastToggleTime[panelId] or 0
	if currentTime - lastTime < 0.3 then
		return nil -- Ignored due to debouncing
	end
	lastToggleTime[panelId] = currentTime

	if self:IsPanelOpen(panelId) then
		self:ClosePanel(panelId)
		return false
	else
		self:OpenPanel(panelId, data)
		return true
	end
end

--[[
	Check if a panel is currently open
	@param panelId: string - Panel identifier
	@return: boolean
--]]
function PanelManager:IsPanelOpen(panelId)
	return activePanels[panelId] ~= nil
end



--[[
	Close all open panels
--]]
function PanelManager:CloseAllPanels()
	-- Create a copy of the active panels list to avoid modification during iteration
	local panelsToClose = {}
	for panelId, _ in pairs(activePanels) do
		table.insert(panelsToClose, panelId)
	end

	-- Close each panel
	for _, panelId in ipairs(panelsToClose) do
		self:ClosePanel(panelId)
	end
end

--[[
	Get active panel count
--]]
function PanelManager:GetActivePanelCount()
	local count = 0
	for _ in pairs(activePanels) do
		count = count + 1
	end
	return count
end

--[[
	Create a panel instance from configuration
	@param config: table - Panel configuration
	@param data: table - Optional panel data
	@return: table - Panel instance
--]]
function PanelManager:CreatePanelInstance(config, data)
	local typeConfig = PANEL_TYPES[config.type] or PANEL_TYPES.overlay
	local sizeConfig = PANEL_SIZES[config.size] or PANEL_SIZES.medium

	-- Create the panel using UIComponents
	local panel = UIComponents:CreatePanel({
		name = config.id,
		title = config.title,
		size = config.size,
		icon = config.icon,
		closable = config.closable ~= false,
		backdropClose = typeConfig.closeOnBackdrop,
		parent = playerGui,
		headerless = config.headerless
	})

	if not panel then
		return nil
	end

	-- Apply custom sizing if defined
	if sizeConfig.size and panel.mainFrame then
		panel.mainFrame.Size = sizeConfig.size
	end

	-- Set up panel properties
	panel.config = config
	panel.typeConfig = typeConfig
	panel.sizeConfig = sizeConfig
	panel.data = data or {}
	panel.zIndex = nextZIndex
	nextZIndex = nextZIndex + 10

	-- Set Z-index for proper layering
	if panel.gui then
		panel.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		panel.gui.DisplayOrder = panel.zIndex
	end

	-- Create panel content using the registered create function
	if config.create then
		-- Pass size config to the content creation function
		local panelData = data or {}
		if sizeConfig.size then
			panelData.customSize = sizeConfig.size
		end

		config.create(panel.contentFrame, panelData)
	end

	-- Apply custom positioning if defined
	if sizeConfig.position and sizeConfig.anchorPoint then
		panel.mainFrame.Position = sizeConfig.position
		panel.mainFrame.AnchorPoint = sizeConfig.anchorPoint
	elseif typeConfig.centerPosition then
		-- Panel is already centered by UIComponents for standard cases
	else
		-- Custom positioning for sidebars, etc.
		self:PositionPanel(panel, config)
	end

	-- Set up close callback
	if panel.closeButton then
		panel.closeButton.MouseButton1Click:Connect(function()
			-- Play sound effect
			if SoundManager then
				SoundManager:PlaySFX("buttonClick")
			end
			self:ClosePanel(config.id)
		end)
	end

	-- Backdrop close functionality
	if typeConfig.closeOnBackdrop and panel.backdrop then
		panel.backdrop.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self:ClosePanel(config.id)
			end
		end)
	end

	-- Auto-close functionality for toast panels
	if typeConfig.autoClose then
		local delay = typeConfig.autoCloseDelay or 3
		task.spawn(function()
			task.wait(delay)
			if self:IsPanelOpen(config.id) then
				self:ClosePanel(config.id)
			end
		end)
	end

	return panel
end

--[[
	Position panel based on type and configuration
--]]
function PanelManager:PositionPanel(panel, config)
	-- Custom positioning logic for different panel types
	if config.type == "sidebar" then
		-- Position on left side
		panel.mainFrame.Position = UDim2.new(0, 20, 0.5, 0)
		panel.mainFrame.AnchorPoint = Vector2.new(0, 0.5)
	elseif config.type == "toast" then
		-- Position at top-right
		panel.mainFrame.Position = UDim2.new(1, -20, 0, 80)
		panel.mainFrame.AnchorPoint = Vector2.new(1, 0)
	end
	-- Overlay and popup types remain centered (default)
	-- Custom positioning is now handled via PANEL_SIZES configuration
end

--[[
	Show panel with animation
--]]
function PanelManager:ShowPanel(panelInstance)
	local typeConfig = panelInstance.typeConfig
	local animationType = ANIMATION_SETTINGS.easing[typeConfig.animation] or ANIMATION_SETTINGS.easing.smooth

	-- Call onShow callback
	if panelInstance.config.onShow then
		panelInstance.config.onShow(panelInstance.data)
	end

	-- Show the panel using UIComponents animation
	panelInstance:Show(animationType.Time)
end

--[[
	Hide panel with animation
--]]
function PanelManager:HidePanel(panelInstance, callback)
	local typeConfig = panelInstance.typeConfig
	local animationType = ANIMATION_SETTINGS.easing[typeConfig.animation] or ANIMATION_SETTINGS.easing.smooth

	-- Call onHide callback
	if panelInstance.config.onHide then
		panelInstance.config.onHide(panelInstance.data)
	end

	-- Hide the panel using UIComponents animation
	panelInstance:Hide(animationType.Time)

	-- Schedule cleanup
	if callback then
		task.spawn(function()
			task.wait(animationType.Time)
			callback()
		end)
	end
end

--[[
	Clean up panel instance
--]]
function PanelManager:CleanupPanel(panelInstance)
	-- Destroy panel if not persistent
	if not panelInstance.config.persistent then
		panelInstance:Destroy()
	end
end

--[[
	Register built-in panels
--]]
function PanelManager:RegisterBuiltInPanels()
	-- Daily Rewards Panel
	self:RegisterPanel("daily_rewards", {
		title = "Daily Rewards",
		type = "popup",
		size = "daily_rewards_compact", -- Custom compact size for 7-day layout
		icon = {category = "UI", name = "Calendar"},
		create = function(contentFrame, data)
			local DailyRewardsPanel = require(script.Parent.Parent.UI.DailyRewardsPanel)
			DailyRewardsPanel:CreateContent(contentFrame, data)
		end
	})

	-- Settings Panel
	self:RegisterPanel("settings", {
		title = "Settings",
		type = "overlay",
		size = "settings_compact",
		icon = {category = "General", name = "Settings"},
		create = function(contentFrame, data)
			-- Load and use SettingsPanel directly
			local SettingsPanel = require(script.Parent.Parent.UI.SettingsPanel)
			SettingsPanel:CreateContent(contentFrame, data)
		end
	})

	-- Emotes Panel
	self:RegisterPanel("emotes", {
		title = "Emotes",
		type = "popup",
		size = "emote_wide",  -- Use the original wide design
		icon = {category = "General", name = "Heart"},
		create = function(contentFrame, data)
			local EmoteManager = require(script.Parent.EmoteManager)
			EmoteManager:CreatePanelContent(contentFrame, data)
		end,
		onShow = function(data)
			-- Notify EmoteManager that panel is shown
			local EmoteManager = require(script.Parent.EmoteManager)
			EmoteManager:OnPanelShown()
		end,
		onHide = function(data)
			-- Notify EmoteManager that panel is hidden
			local EmoteManager = require(script.Parent.EmoteManager)
			EmoteManager:OnPanelHidden()
		end
	})

	-- Shop Panel (integrates with existing UIManager shop)
	self:RegisterPanel("shop", {
		title = "Shop",
		type = "overlay",
		size = "shop",
		icon = {category = "General", name = "Shop"},
		create = function(contentFrame, data)
			local ShopPanel = require(script.Parent.Parent.UI.ShopPanel)
			ShopPanel:CreateContent(contentFrame, data)
		end
	})

	-- Inventory Panel
	self:RegisterPanel("inventory", {
		title = "Spawner Inventory",
		type = "overlay",
		size = "inventory_compact", -- Use the new compact size
		icon = {category = "Clothing", name = "Backpack"},
		create = function(contentFrame, data)
			-- Load and use InventoryPanel
			local InventoryPanel = require(script.Parent.Parent.UI.InventoryPanel)
			InventoryPanel:CreateContent(contentFrame, data)
		end,
		-- Inventory panel now handles its own data management
	})

	-- Quests Panel
	self:RegisterPanel("quests", {
		title = "Quests",
		type = "overlay",
		size = "inventory_compact",
		icon = {category = "General", name = "Trophy"},
		create = function(contentFrame, data)
			local QuestsPanel = require(script.Parent.Parent.UI.QuestsPanel)
			QuestsPanel:CreateContent(contentFrame, data)
		end,
		onShow = function()
			print("PanelManager: Quests panel opened - requesting fresh quest data")
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local EventManager = require(ReplicatedStorage.Shared.EventManager)
			EventManager:SendToServer("RequestQuestData")
		end
	})

end

--[[
	Utility function to create a simple notification panel
--]]
function PanelManager:ShowNotification(title, message, duration)
	local notificationId = "notification_" .. tick()

	self:RegisterPanel(notificationId, {
		title = title,
		type = "toast",
		size = "small",
		create = function(contentFrame, data)
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Text = message
			label.TextColor3 = Config.UI_SETTINGS.colors.text
			label.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
			label.Font = Config.UI_SETTINGS.typography.fonts.regular
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextYAlignment = Enum.TextYAlignment.Center
			label.TextWrapped = true
			label.Parent = contentFrame
		end
	})

	self:OpenPanel(notificationId)

	-- Auto-close after duration
	if duration then
		task.wait(duration)
		self:ClosePanel(notificationId)
		end
end

return PanelManager