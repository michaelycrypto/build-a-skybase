--[[
	MobHeadPanel.lua - Mob Head Management UI Panel
	Displays player's mob heads and allows equipping them to spawner slots
--]]

local MobHeadPanel = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameState = require(script.Parent.Parent.Managers.GameState)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)

-- Services and instances
local player = Players.LocalPlayer

-- UI State
local gameStateListener = nil
local tooltipConnections = {}
local selectedSpawnerSlot = nil

-- Grid Constants
local GRID_CONFIG = {
	itemSize = {width = 80, height = 100},
	itemPadding = 8,
	containerPadding = 12
}

--[[
	Create the mob head panel content
	@param contentFrame: Frame - The content frame to populate
	@param data: table - Panel data with spawner slot info
--]]
function MobHeadPanel:CreateContent(contentFrame, data)
	-- Store the selected spawner slot
	selectedSpawnerSlot = data and data.spawnerSlot or nil

	-- Clear any existing content and connections
	self:Cleanup()

	for _, child in pairs(contentFrame:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Create header
	self:CreateHeader(contentFrame)

	-- Create mob head grid
	self:CreateMobHeadGrid(contentFrame)

	-- Set up GameState listener for reactive updates
	self:SetupGameStateListener()

	-- Set up event listeners
	self:SetupEventListeners()

	-- Initial load
	self:RefreshMobHeads()
	self:UpdateDisplay()

	Logger:Info("MobHeadPanel", "Mob head panel content created", {
		spawnerSlot = selectedSpawnerSlot
	})
end

--[[
	Create header with title and spawner slot info
	@param parent: Frame - Parent frame
--]]
function MobHeadPanel:CreateHeader(parent)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 60)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0, 24)
	titleLabel.Position = UDim2.new(0, 0, 0, 8)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = selectedSpawnerSlot and ("Equip Mob Head to Slot " .. selectedSpawnerSlot) or "Mob Heads"
	titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
	titleLabel.TextScaled = true
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = headerFrame

	-- Title stroke
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
	titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
	titleStroke.Parent = titleLabel

	-- Instructions
	local instructionLabel = Instance.new("TextLabel")
	instructionLabel.Name = "Instructions"
	instructionLabel.Size = UDim2.new(1, 0, 0, 20)
	instructionLabel.Position = UDim2.new(0, 0, 1, -28)
	instructionLabel.BackgroundTransparency = 1
	instructionLabel.Text = selectedSpawnerSlot and "Click a mob head to deposit it" or "Select a spawner location to deposit mob heads"
	instructionLabel.TextColor3 = Config.UI_SETTINGS.colors.text.secondary
	instructionLabel.TextScaled = true
	instructionLabel.Font = Enum.Font.Gotham
	instructionLabel.Parent = headerFrame
end

--[[
	Create mob head grid container
	@param parent: Frame - Parent frame
--]]
function MobHeadPanel:CreateMobHeadGrid(parent)
	-- Scroll container
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "MobHeadScroll"
	scrollFrame.Size = UDim2.new(1, -24, 1, -80)
	scrollFrame.Position = UDim2.new(0, 12, 0, 70)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Config.UI_SETTINGS.colors.accent.primary
	scrollFrame.Parent = parent

	-- Grid layout
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, GRID_CONFIG.itemSize.width, 0, GRID_CONFIG.itemSize.height)
	gridLayout.CellPadding = UDim2.new(0, GRID_CONFIG.itemPadding, 0, GRID_CONFIG.itemPadding)
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollFrame

	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingAll = UDim.new(0, GRID_CONFIG.containerPadding)
	padding.Parent = scrollFrame

	-- Store reference
	self.gridContainer = scrollFrame

	-- Update canvas size when layout changes
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + (GRID_CONFIG.containerPadding * 2))
	end)
end

--[[
	Set up GameState listener for reactive updates
--]]
function MobHeadPanel:SetupGameStateListener()
	if gameStateListener then
		gameStateListener:Disconnect()
	end

	gameStateListener = GameState:Connect("playerData.inventory", function()
		self:UpdateDisplay()
	end)
end

--[[
	Set up event listeners
--]]
function MobHeadPanel:SetupEventListeners()
	-- Listen for mob head deposited/removed events
	EventManager:ConnectToServer("MobHeadDeposited", function(data)
		Logger:Info("MobHeadPanel", "Mob head deposited", data)
		self:RefreshMobHeads()
	end)

	EventManager:ConnectToServer("MobHeadRemoved", function(data)
		Logger:Info("MobHeadPanel", "Mob head removed", data)
		self:RefreshMobHeads()
	end)
end

--[[
	Request mob head data from server
--]]
function MobHeadPanel:RefreshMobHeads()
	-- Request updated player data which includes inventory
	EventManager:SendToServer("RequestPlayerData")
end

--[[
	Update the display with current mob heads
--]]
function MobHeadPanel:UpdateDisplay()
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
	local playerData = GameState:Get("playerData") or {}
	local inventory = playerData.inventory or {}

	-- Filter for mob heads
	local mobHeads = {}
	local itemConfig = require(ReplicatedStorage.Configs.ItemConfig)

	for itemId, quantity in pairs(inventory) do
		local itemDef = itemConfig.Items[itemId]
		if itemDef and itemDef.type == "MOB_HEAD" and quantity > 0 then
			table.insert(mobHeads, {
				itemId = itemId,
				definition = itemDef,
				quantity = quantity
			})
		end
	end

	-- Sort mob heads by rarity and name
	table.sort(mobHeads, function(a, b)
		local rarityOrder = {BASIC = 1, ENHANCED = 2, SUPERIOR = 3, LEGENDARY = 4}
		local aRarity = rarityOrder[a.definition.rarity] or 0
		local bRarity = rarityOrder[b.definition.rarity] or 0

		if aRarity ~= bRarity then
			return aRarity < bRarity
		end
		return a.definition.name < b.definition.name
	end)

	-- Create mob head items
	for i, mobHeadData in ipairs(mobHeads) do
		self:CreateMobHeadItem(mobHeadData, i)
	end

	Logger:Debug("MobHeadPanel", "Display updated", {
		mobHeadCount = #mobHeads
	})
end

--[[
	Create a mob head item
	@param mobHeadData: table - Mob head data
	@param layoutOrder: number - Layout order
--]]
function MobHeadPanel:CreateMobHeadItem(mobHeadData, layoutOrder)
	-- Item container
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "MobHead_" .. mobHeadData.itemId
	itemFrame.Size = UDim2.new(0, GRID_CONFIG.itemSize.width, 0, GRID_CONFIG.itemSize.height)
	itemFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	itemFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = layoutOrder
	itemFrame.Parent = self.gridContainer

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	itemCorner.Parent = itemFrame

	-- Rarity border
	local rarityColors = {
		BASIC = Color3.fromRGB(120, 120, 120),
		ENHANCED = Color3.fromRGB(30, 144, 255),
		SUPERIOR = Color3.fromRGB(138, 43, 226),
		LEGENDARY = Color3.fromRGB(255, 215, 0)
	}

	local itemBorder = Instance.new("UIStroke")
	itemBorder.Color = rarityColors[mobHeadData.definition.rarity] or rarityColors.BASIC
	itemBorder.Thickness = 2
	itemBorder.Parent = itemFrame

	-- Icon (placeholder - would use actual mob head icons)
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.Size = UDim2.new(0, 32, 0, 32)
	icon.Position = UDim2.new(0.5, 0, 0, 8)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundTransparency = 1
	icon.Image = "rbxasset://textures/face.png" -- Placeholder
	icon.Parent = itemFrame

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, -8, 0, 16)
	nameLabel.Position = UDim2.new(0, 4, 0, 48)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = mobHeadData.definition.name
	nameLabel.TextColor3 = Config.UI_SETTINGS.colors.text.primary
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Parent = itemFrame

	-- Quantity
	if mobHeadData.quantity > 1 then
		local quantityLabel = Instance.new("TextLabel")
		quantityLabel.Name = "Quantity"
		quantityLabel.Size = UDim2.new(0, 20, 0, 16)
		quantityLabel.Position = UDim2.new(1, -24, 0, 4)
		quantityLabel.BackgroundColor3 = Config.UI_SETTINGS.colors.accent.primary
		quantityLabel.Text = tostring(mobHeadData.quantity)
		quantityLabel.TextColor3 = Color3.new(1, 1, 1)
		quantityLabel.TextScaled = true
		quantityLabel.Font = Enum.Font.GothamBold
		quantityLabel.Parent = itemFrame

		local quantityCorner = Instance.new("UICorner")
		quantityCorner.CornerRadius = UDim.new(0, 8)
		quantityCorner.Parent = quantityLabel
	end

	-- Stats preview
	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "Stats"
	statsLabel.Size = UDim2.new(1, -8, 0, 24)
	statsLabel.Position = UDim2.new(0, 4, 1, -28)
	statsLabel.BackgroundTransparency = 1
	statsLabel.Text = string.format("HP: %d | DMG: %d",
		mobHeadData.definition.stats.mobHealth,
		mobHeadData.definition.stats.mobDamage)
	statsLabel.TextColor3 = Config.UI_SETTINGS.colors.text.secondary
	statsLabel.TextScaled = true
	statsLabel.Font = Enum.Font.Gotham
	statsLabel.Parent = itemFrame

	-- Click handler
	if selectedSpawnerSlot then
		local button = Instance.new("TextButton")
		button.Name = "EquipButton"
		button.Size = UDim2.new(1, 0, 1, 0)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.Parent = itemFrame

		button.MouseButton1Click:Connect(function()
			self:DepositMobHead(mobHeadData.itemId)
		end)

		-- Hover effects
		button.MouseEnter:Connect(function()
			TweenService:Create(itemFrame, TweenInfo.new(0.2), {
				BackgroundTransparency = 0
			}):Play()
		end)

		button.MouseLeave:Connect(function()
			TweenService:Create(itemFrame, TweenInfo.new(0.2), {
				BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
			}):Play()
		end)
	end

	-- Tooltip
	self:CreateTooltip(itemFrame, mobHeadData)
end

--[[
	Deposit a mob head into the selected spawner location
	@param mobHeadType: string - The mob head type to deposit
--]]
function MobHeadPanel:DepositMobHead(mobHeadType)
	if not selectedSpawnerSlot then
		Logger:Warn("MobHeadPanel", "No spawner slot selected")
		return
	end

	Logger:Info("MobHeadPanel", "Depositing mob head", {
		mobHeadType = mobHeadType,
		spawnerSlot = selectedSpawnerSlot
	})

	-- Send deposit request to server
	EventManager:SendToServer("DepositMobHead", selectedSpawnerSlot, mobHeadType)
end

--[[
	Create tooltip for mob head item
	@param itemFrame: Frame - The item frame
	@param mobHeadData: table - Mob head data
--]]
function MobHeadPanel:CreateTooltip(itemFrame, mobHeadData)
	-- Store tooltip connection for cleanup
	local connection = itemFrame.MouseEnter:Connect(function()
		-- Create tooltip content
		local tooltipText = string.format(
			"%s\n%s\n\nStats:\nHealth: %d\nDamage: %d\nSpeed: %d\nValue: %d",
			mobHeadData.definition.name,
			mobHeadData.definition.description,
			mobHeadData.definition.stats.mobHealth,
			mobHeadData.definition.stats.mobDamage,
			mobHeadData.definition.stats.mobSpeed,
			mobHeadData.definition.stats.mobValue
		)

		-- Show tooltip (would use actual tooltip system)
		Logger:Debug("MobHeadPanel", "Tooltip", {text = tooltipText})
	end)

	table.insert(tooltipConnections, connection)
end

--[[
	Clean up tooltips and connections
--]]
function MobHeadPanel:CleanupTooltips()
	for _, connection in ipairs(tooltipConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	tooltipConnections = {}
end

--[[
	Clean up the panel
--]]
function MobHeadPanel:Cleanup()
	if gameStateListener then
		gameStateListener:Disconnect()
		gameStateListener = nil
	end

	self:CleanupTooltips()
	selectedSpawnerSlot = nil
end

return MobHeadPanel
