--[[
	InventoryPanel.lua - Spawner Inventory UI Panel
	Displays player's spawner inventory showing individual spawners with their status
--]]

local InventoryPanel = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local InventoryApi = require(ReplicatedStorage.Shared.Api.InventoryApi)
local GameState = require(script.Parent.Parent.Managers.GameState)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)

-- Services and instances
local player = Players.LocalPlayer

-- UI State
local gameStateListener = nil
local tooltipConnections = {}
local lastRefreshTime = 0

-- Grid Constants - Compact design
local GRID_CONFIG = {
	itemSize = {width = 90, height = 110},
	itemPadding = 6,
	containerPadding = 10
}

--[[
	Create the inventory panel content
	@param contentFrame: Frame - The content frame to populate
	@param data: table - Panel data
--]]
function InventoryPanel:CreateContent(contentFrame, data)
	-- Clear any existing content and connections
	self:Cleanup()

	for _, child in pairs(contentFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Create header
	self:CreateHeader(contentFrame)

	-- Create inventory grid
	self:CreateInventoryGrid(contentFrame)

	-- Set up GameState listener for reactive updates
	self:SetupGameStateListener()

	-- Set up event listener
	self:SetupEventListener()

	-- Initial load
	self:RefreshInventory()
	self:UpdateDisplay()

	Logger:Info("InventoryPanel", "Inventory panel content created", {})
end

--[[
	Create compact header with inventory statistics
	@param parent: Frame - Parent frame
--]]
function InventoryPanel:CreateHeader(parent)
	local headerContainer = Instance.new("Frame")
	headerContainer.Name = "HeaderContainer"
	headerContainer.Size = UDim2.new(1, 0, 0, 35)
	headerContainer.Position = UDim2.new(0, 0, 0, 0)
	headerContainer.BackgroundTransparency = 1
	headerContainer.Parent = parent

	-- Stats info
	self.statsLabel = Instance.new("TextLabel")
	self.statsLabel.Name = "StatsLabel"
	self.statsLabel.Size = UDim2.new(1, 0, 0, 20)
	self.statsLabel.Position = UDim2.new(0, 0, 0, 0)
	self.statsLabel.BackgroundTransparency = 1
	self.statsLabel.Text = "Loading..."
	self.statsLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	self.statsLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	self.statsLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	self.statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.statsLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.statsLabel.Parent = headerContainer

	-- Subtitle row
	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Name = "SubtitleLabel"
	subtitleLabel.Size = UDim2.new(1, 0, 0, 15)
	subtitleLabel.Position = UDim2.new(0, 0, 0, 20)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Text = "Hover over items for details • Tap items on mobile"
	subtitleLabel.TextColor3 = Config.UI_SETTINGS.colors.textMuted
	subtitleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	subtitleLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	subtitleLabel.TextYAlignment = Enum.TextYAlignment.Center
	subtitleLabel.Parent = headerContainer
end

--[[
	Create inventory grid using UIGridLayout
	@param parent: Frame - Parent frame
--]]
function InventoryPanel:CreateInventoryGrid(parent)
	-- Scrolling frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "InventoryScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -45)
	scrollFrame.Position = UDim2.new(0, 0, 0, 45)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Config.UI_SETTINGS.colors.accent
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = parent

	-- Grid container
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "GridContainer"
	gridContainer.Size = UDim2.new(1, 0, 0, 0)
	gridContainer.BackgroundTransparency = 1
	gridContainer.AutomaticSize = Enum.AutomaticSize.Y
	gridContainer.Parent = scrollFrame

	-- UIGridLayout for automatic grid arrangement
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellSize = UDim2.new(0, GRID_CONFIG.itemSize.width, 0, GRID_CONFIG.itemSize.height)
	gridLayout.CellPadding = UDim2.new(0, GRID_CONFIG.itemPadding, 0, GRID_CONFIG.itemPadding)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.Parent = gridContainer

	-- Container padding
	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingTop = UDim.new(0, GRID_CONFIG.containerPadding)
	containerPadding.PaddingBottom = UDim.new(0, GRID_CONFIG.containerPadding)
	containerPadding.PaddingLeft = UDim.new(0, GRID_CONFIG.containerPadding)
	containerPadding.PaddingRight = UDim.new(0, GRID_CONFIG.containerPadding)
	containerPadding.Parent = gridContainer

	-- Store references
	self.scrollFrame = scrollFrame
	self.gridContainer = gridContainer
end

--[[
	Set up GameState listener for reactive updates
--]]
function InventoryPanel:SetupGameStateListener()
	-- Clean up existing listener
	if gameStateListener then
		gameStateListener() -- Call the unregister function
		gameStateListener = nil
	end

	-- Listen for inventory changes in GameState
	gameStateListener = GameState:OnPropertyChanged("playerData.spawnerInventory", function(newValue, oldValue, path)
		-- Update display when inventory changes
		self:UpdateDisplay()
	end)
end

--[[
	Set up event listener for inventory updates
--]]
function InventoryPanel:SetupEventListener()
	-- Listen for inventory updates from server
	EventManager:RegisterEvent("SpawnerInventoryUpdated", function(updateData)
		Logger:Debug("InventoryPanel", "Received inventory update", {
			action = updateData.action,
			spawnerId = updateData.spawnerId,
			spawnerType = updateData.spawnerType
		})

		-- Just update the display - don't request new data as it was already provided
		-- The inventory data is already updated in GameState by EventManager
		self:UpdateDisplay()
	end)
end

--[[
	Refresh inventory data from server
--]]
function InventoryPanel:RefreshInventory()
	-- Debounce rapid refresh requests
	local currentTime = tick()
	if currentTime - lastRefreshTime < 0.5 then
		return
	end
	lastRefreshTime = currentTime

Logger:Info("InventoryPanel", "Subscribing to inventory updates via InventoryApi", {})
InventoryApi.OnUpdated(function(inventory)
	-- Refresh UI when inventory updates
	-- (Assumes this module has a Refresh or Update method; adjust if needed)
	if InventoryPanel and InventoryPanel.Refresh then
		InventoryPanel:Refresh(inventory)
	end
end)
end

--[[
	Update the entire display based on current GameState
--]]
function InventoryPanel:UpdateDisplay()
	if not self.gridContainer then return end

	-- Clean up existing tooltips
	self:CleanupTooltips()

	-- Clear existing items
	for _, child in pairs(self.gridContainer:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Get current inventory data from GameState
	local inventoryData = GameState:Get("playerData.spawnerInventory") or {}

	-- Build flat list of all spawners
	local allSpawners = {}
	for spawnerType, typeData in pairs(inventoryData) do
		if typeData.spawners then
			for _, spawnerData in ipairs(typeData.spawners) do
				table.insert(allSpawners, spawnerData)
			end
		end
	end

	-- Sort spawners (available first, then by creation date)
	table.sort(allSpawners, function(a, b)
		if a.status == b.status then
			return (a.dateCreated or 0) < (b.dateCreated or 0)
		end
		return a.status == "inventory" and b.status == "placed"
	end)

	-- Create items
	for i, spawnerData in ipairs(allSpawners) do
		self:CreateInventoryItem(spawnerData, i)
	end

	-- Update stats
	self:UpdateStats(inventoryData)

	Logger:Debug("InventoryPanel", "Display updated", {
		spawnerCount = #allSpawners
	})
end

--[[
	Create an inventory item
	@param spawnerData: table - Individual spawner data
	@param layoutOrder: number - Layout order
--]]
function InventoryPanel:CreateInventoryItem(spawnerData, layoutOrder)
	-- Item container
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "Item_" .. spawnerData.id
	itemFrame.Size = UDim2.new(0, GRID_CONFIG.itemSize.width, 0, GRID_CONFIG.itemSize.height)
	itemFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	itemFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = layoutOrder
	itemFrame.Parent = self.gridContainer

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	itemCorner.Parent = itemFrame

	-- Border
	local itemBorder = Instance.new("UIStroke")
	itemBorder.Color = Config.UI_SETTINGS.colors.semantic.borders.default
	itemBorder.Thickness = 1
	itemBorder.Transparency = Config.UI_SETTINGS.designSystem.transparency.subtle
	itemBorder.Parent = itemFrame

	-- Gradient overlay
	UIComponents:CreateGradientOverlay(itemFrame, Config.UI_SETTINGS.designSystem.borderRadius.lg)

	-- Icon
	local iconInfo = self:GetSpawnerIcon(spawnerData.type)
	local icon = IconManager:CreateIcon(itemFrame, iconInfo.category, iconInfo.name, {
		size = UDim2.new(0, 36, 0, 36),
		position = UDim2.new(0.5, 0, 0, 12),
		anchorPoint = Vector2.new(0.5, 0)
	})

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, -8, 0, 0)
	nameLabel.Position = UDim2.new(0, 4, 0, 52)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = self:GetSpawnerDisplayName(spawnerData.type)
	nameLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	nameLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	nameLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Top
	nameLabel.TextWrapped = true
	nameLabel.AutomaticSize = Enum.AutomaticSize.Y
	nameLabel.Parent = itemFrame

	-- Status container
	local statusContainer = Instance.new("Frame")
	statusContainer.Name = "StatusContainer"
	statusContainer.Size = UDim2.new(1, -8, 0, 20)
	statusContainer.Position = UDim2.new(0, 4, 1, -24)
	statusContainer.BackgroundTransparency = 1
	statusContainer.Parent = itemFrame

	local statusLayout = Instance.new("UIListLayout")
	statusLayout.FillDirection = Enum.FillDirection.Horizontal
	statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
	statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	statusLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statusLayout.Padding = UDim.new(0, 4)
	statusLayout.Parent = statusContainer

	-- Status dot
	local statusDot = Instance.new("Frame")
	statusDot.Name = "StatusDot"
	statusDot.Size = UDim2.new(0, 6, 0, 6)
	statusDot.BorderSizePixel = 0
	statusDot.LayoutOrder = 1
	statusDot.Parent = statusContainer

	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(0.5, 0)
	dotCorner.Parent = statusDot

	-- Status text
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(0, 0, 0, 20)
	statusLabel.BackgroundTransparency = 1
	statusLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	statusLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Center
	statusLabel.AutomaticSize = Enum.AutomaticSize.X
	statusLabel.LayoutOrder = 2
	statusLabel.Parent = statusContainer

	-- Update status appearance
	self:UpdateItemStatus(itemFrame, spawnerData, statusDot, statusLabel, icon)

	-- Add hover effects
	self:AddHoverEffects(itemFrame, icon, itemBorder)

	-- Add tooltip
	self:AddSpawnerTooltip(itemFrame, spawnerData)
end

--[[
	Update item status appearance
--]]
function InventoryPanel:UpdateItemStatus(itemFrame, spawnerData, statusDot, statusLabel, icon)
	if spawnerData.status == "placed" then
		statusLabel.Text = "Placed"
		statusLabel.TextColor3 = Config.UI_SETTINGS.colors.semantic.game.experience
		statusDot.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.game.experience
		itemFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.medium
		if icon then
			icon.ImageTransparency = 0.2
		end
	else
		statusLabel.Text = "Available"
		statusLabel.TextColor3 = Config.UI_SETTINGS.colors.semantic.game.coins
		statusDot.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.game.coins
		itemFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
		if icon then
			icon.ImageTransparency = 0
		end
	end
end

--[[
	Add hover effects
--]]
function InventoryPanel:AddHoverEffects(itemFrame, icon, border)
	itemFrame.MouseEnter:Connect(function()
		TweenService:Create(itemFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.subtle
		}):Play()

		TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 0.2,
			Thickness = 2
		}):Play()

		if icon then
			TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 40, 0, 40)
			}):Play()
		end
	end)

	itemFrame.MouseLeave:Connect(function()
		local baseTransparency = Config.UI_SETTINGS.designSystem.transparency.light
		-- Check if this item is placed by looking at the status label
		local statusLabel = itemFrame:FindFirstChild("StatusContainer"):FindFirstChild("StatusLabel")
		if statusLabel and statusLabel.Text == "Placed" then
			baseTransparency = Config.UI_SETTINGS.designSystem.transparency.medium
		end

		TweenService:Create(itemFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = baseTransparency
		}):Play()

		TweenService:Create(border, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = Config.UI_SETTINGS.designSystem.transparency.subtle,
			Thickness = 1
		}):Play()

		if icon then
			TweenService:Create(icon, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Size = UDim2.new(0, 36, 0, 36)
			}):Play()
		end
	end)
end

--[[
	Add tooltip to spawner item
--]]
function InventoryPanel:AddSpawnerTooltip(itemFrame, spawnerData)
	if not itemFrame or not spawnerData then return end

	-- Build tooltip content
	local tooltipContent = {
		title = self:GetSpawnerDisplayName(spawnerData.type),
		description = self:GetSpawnerDescription(spawnerData.type),
		status = spawnerData.status == "placed" and "Placed in Dungeon" or "Available for Placement",
		properties = {
			{name = "Spawner ID", value = spawnerData.id},
			{name = "Type", value = spawnerData.type},
		}
	}

	-- Add placement info if placed
	if spawnerData.status == "placed" and spawnerData.placedSlot then
		table.insert(tooltipContent.properties, {
			name = "Slot",
			value = spawnerData.placedSlot,
			color = Config.UI_SETTINGS.colors.semantic.game.experience
		})
	end

	-- Add creation date if available
	if spawnerData.dateCreated then
		local timeAgo = self:FormatTimeAgo(spawnerData.dateCreated)
		table.insert(tooltipContent.properties, {
			name = "Acquired",
			value = timeAgo,
			color = Config.UI_SETTINGS.colors.textSecondary
		})
	end

	-- Add tooltip
	local success, tooltipConnection = pcall(function()
		return UIComponents:AddTooltip(itemFrame, tooltipContent)
	end)

	if success and tooltipConnection then
		table.insert(tooltipConnections, tooltipConnection)
	end
end

--[[
	Update stats display
--]]
function InventoryPanel:UpdateStats(inventoryData)
	if not self.statsLabel then return end

	local totalCount = 0
	local availableCount = 0
	local placedCount = 0

	for _, typeData in pairs(inventoryData) do
		totalCount = totalCount + (typeData.totalCount or 0)
		availableCount = availableCount + (typeData.availableCount or 0)
		placedCount = placedCount + (typeData.placedCount or 0)
	end

	self.statsLabel.Text = string.format("Total: %d • Available: %d • Placed: %d", totalCount, availableCount, placedCount)
end

--[[
	Get spawner display name
--]]
function InventoryPanel:GetSpawnerDisplayName(spawnerType)
	if not spawnerType then return "Unknown Spawner" end

	local spawnerConfig = Config.SPAWNER_SYSTEM.spawnerTypes[spawnerType]
	return spawnerConfig and spawnerConfig.name or spawnerType
end

--[[
	Get spawner description
--]]
function InventoryPanel:GetSpawnerDescription(spawnerType)
	local spawnerConfig = Config.SPAWNER_SYSTEM.spawnerTypes[spawnerType]
	return spawnerConfig and spawnerConfig.description or "A spawner"
end

--[[
	Get spawner icon information
--]]
function InventoryPanel:GetSpawnerIcon(spawnerType)
	if not spawnerType then
		return {
			category = "Shapes",
			name = "Cube",
			color = Color3.fromRGB(128, 128, 128)
		}
	end

	return {
		category = "Shapes",
		name = "Cube",
		color = Color3.fromRGB(255, 215, 0)
	}
end

--[[
	Count number of spawner types in inventory (helper for logging)
--]]
function InventoryPanel:CountSpawnerTypes(inventoryData)
	local count = 0
	for _ in pairs(inventoryData or {}) do
		count = count + 1
	end
	return count
end

--[[
	Format time ago string
--]]
function InventoryPanel:FormatTimeAgo(timestamp)
	local now = os.time()
	local diff = now - timestamp

	if diff < 60 then return "Just now"
	elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
	elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
	else return math.floor(diff / 86400) .. "d ago"
	end
end

--[[
	Clean up tooltip connections
--]]
function InventoryPanel:CleanupTooltips()
	-- Hide any active tooltip
	UIComponents:HideTooltip(true)

	-- Clean up connections
	for _, connection in ipairs(tooltipConnections) do
		if connection and connection.cleanup then
			pcall(connection.cleanup)
		end
	end
	tooltipConnections = {}
end

--[[
	Clean up the inventory panel
--]]
function InventoryPanel:Cleanup()
	-- Clean up GameState listener
	if gameStateListener then
		gameStateListener() -- Call the unregister function
		gameStateListener = nil
	end

	-- EventManager events are automatically cleaned up when the panel is destroyed

	-- Clean up tooltips
	self:CleanupTooltips()

	-- Clear UI references
	self.gridContainer = nil
	self.scrollFrame = nil
	self.statsLabel = nil

	Logger:Info("InventoryPanel", "Inventory panel cleaned up", {})
end

return InventoryPanel