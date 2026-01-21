--[[
	NPCTradeUI.lua
	Unified NPC trading interface for buying (Shop Keeper) and selling (Merchant).
	Follows MinionUI/ChestUI pattern - consistent with existing UI architecture.
	
	Uses UIVisibilityManager for proper backdrop/cursor handling.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local NPCTradeConfig = require(ReplicatedStorage.Configs.NPCTradeConfig)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local ToastManager = require(script.Parent.Parent.Managers.ToastManager)
local GameState = require(script.Parent.Parent.Managers.GameState)
local TutorialManager = require(script.Parent.Parent.Managers.TutorialManager)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)

local NPCTradeUI = {}
NPCTradeUI.__index = NPCTradeUI

local player = Players.LocalPlayer
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold

-- Configuration matching existing UI styles (ChestUI/MinionUI)
local CONFIG = {
	-- Panel dimensions
	PANEL_WIDTH = 400,
	HEADER_HEIGHT = 54,
	CURRENCY_HEIGHT = 36,
	ITEM_HEIGHT = 60,
	ITEM_SPACING = 4,
	PADDING = 8,
	ICON_SIZE = 44,
	BUTTON_WIDTH = 72,
	BUTTON_HEIGHT = 28,
	
	-- Colors (matching existing panels)
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	SLOT_HOVER = Color3.fromRGB(60, 60, 60),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HEADER_BG = Color3.fromRGB(45, 45, 45),
	
	-- Button colors
	BTN_BUY = Color3.fromRGB(80, 180, 80),
	BTN_BUY_HOVER = Color3.fromRGB(100, 200, 100),
	BTN_SELL = Color3.fromRGB(255, 200, 50),
	BTN_SELL_HOVER = Color3.fromRGB(255, 220, 80),
	BTN_DISABLED = Color3.fromRGB(70, 70, 70),
	
	-- Text colors
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_SECONDARY = Color3.fromRGB(180, 180, 180),
	TEXT_COINS = Color3.fromRGB(255, 215, 0),
	TEXT_INSUFFICIENT = Color3.fromRGB(255, 100, 100),
}

-- Helper function to get display name for any item type
local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then
		return nil
	end
	
	if ToolConfig.IsTool(itemId) then
		local toolInfo = ToolConfig.GetToolInfo(itemId)
		return toolInfo and toolInfo.name or "Tool"
	end
	
	if ArmorConfig.IsArmor(itemId) then
		local armorInfo = ArmorConfig.GetArmorInfo(itemId)
		return armorInfo and armorInfo.name or "Armor"
	end
	
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local eggInfo = SpawnEggConfig.GetEggInfo(itemId)
		return eggInfo and eggInfo.name or "Spawn Egg"
	end
	
	local blockDef = BlockRegistry.Blocks[itemId]
	return blockDef and blockDef.name or "Item"
end

function NPCTradeUI.new(inventoryManager)
	local self = setmetatable({}, NPCTradeUI)
	
	self.inventoryManager = inventoryManager
	self.isOpen = false
	self.gui = nil
	self.panel = nil
	self.mode = nil -- "buy" or "sell"
	self.npcId = nil
	self.itemFrames = {}
	
	-- Data from server
	self.shopItems = {}
	self.sellableItems = {}
	self.playerCoins = 0
	
	self._initialized = false
	self._eventsRegistered = false
	
	return self
end

function NPCTradeUI:Initialize()
	if self._initialized then
		return self
	end
	
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Remove any existing NPCTradeUI
	local existing = playerGui:FindFirstChild("NPCTradeUI")
	if existing then
		existing:Destroy()
	end
	
	-- Create ScreenGui (NO overlay - UIBackdrop handles that via UIVisibilityManager)
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "NPCTradeUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150  -- Above inventory (100), same as ChestUI/MinionUI
	self.gui.IgnoreGuiInset = true
	self.gui.Enabled = false
	self.gui.Parent = playerGui
	
	-- Add responsive scaling (matching other UIs)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")
	
	-- Create panel
	self:CreatePanel()
	
	-- Register events
	if not self._eventsRegistered then
		self:RegisterEvents()
		self._eventsRegistered = true
	end
	
	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("npcTradeUI", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 150
	})
	
	self._initialized = true
	
	return self
end

function NPCTradeUI:CreatePanel()
	-- Main panel (centered)
	self.panel = Instance.new("Frame")
	self.panel.Name = "TradePanel"
	self.panel.Size = UDim2.new(0, CONFIG.PANEL_WIDTH, 0, 450)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundColor3 = CONFIG.BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui
	
	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.panel
	
	-- Border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.BORDER_COLOR
	stroke.Thickness = 3
	stroke.Parent = self.panel
	
	-- Header
	self:CreateHeader()
	
	-- Currency display
	self:CreateCurrencyDisplay()
	
	-- Scrollable content area
	self:CreateContentArea()
end

function NPCTradeUI:CreateHeader()
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, CONFIG.HEADER_HEIGHT)
	headerFrame.BackgroundColor3 = CONFIG.HEADER_BG
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = self.panel
	
	-- Header corner (top only)
	local headerCorner = Instance.new("UICorner")
	headerCorner.CornerRadius = UDim.new(0, 8)
	headerCorner.Parent = headerFrame
	
	-- Cover bottom corners
	local headerCover = Instance.new("Frame")
	headerCover.Name = "HeaderCover"
	headerCover.Size = UDim2.new(1, 0, 0, 10)
	headerCover.Position = UDim2.new(0, 0, 1, -10)
	headerCover.BackgroundColor3 = CONFIG.HEADER_BG
	headerCover.BorderSizePixel = 0
	headerCover.Parent = headerFrame
	
	-- Title
	self.titleLabel = Instance.new("TextLabel")
	self.titleLabel.Name = "Title"
	self.titleLabel.Size = UDim2.new(1, -60, 1, 0)
	self.titleLabel.Position = UDim2.new(0, CONFIG.PADDING + 4, 0, 0)
	self.titleLabel.BackgroundTransparency = 1
	self.titleLabel.Text = "SHOP"
	self.titleLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	self.titleLabel.TextSize = 24
	self.titleLabel.Font = BOLD_FONT
	self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.titleLabel.Parent = headerFrame
	
	-- Title stroke
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 2
	titleStroke.Parent = self.titleLabel
	
	-- Close button
	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -CONFIG.PADDING - 32, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(0, 0.5)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Parent = headerFrame
	
	IconManager:ApplyIcon(closeBtn, "UI", "X", {
		size = 32,
		imageColor3 = CONFIG.TEXT_PRIMARY
	})
	
	-- Close button animation
	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 0}):Play()
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)
end

function NPCTradeUI:CreateCurrencyDisplay()
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyDisplay"
	currencyFrame.Size = UDim2.new(1, -CONFIG.PADDING * 2, 0, CONFIG.CURRENCY_HEIGHT)
	currencyFrame.Position = UDim2.new(0, CONFIG.PADDING, 0, CONFIG.HEADER_HEIGHT + 4)
	currencyFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = self.panel
	
	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, 6)
	currencyCorner.Parent = currencyFrame
	
	-- Coin icon
	local coinIcon = Instance.new("TextLabel")
	coinIcon.Name = "CoinIcon"
	coinIcon.Size = UDim2.new(0, 24, 0, 24)
	coinIcon.Position = UDim2.new(0, 10, 0.5, 0)
	coinIcon.AnchorPoint = Vector2.new(0, 0.5)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Text = "💰"
	coinIcon.TextSize = 18
	coinIcon.Parent = currencyFrame
	
	-- Coin amount
	self.coinsLabel = Instance.new("TextLabel")
	self.coinsLabel.Name = "CoinsLabel"
	self.coinsLabel.Size = UDim2.new(1, -44, 1, 0)
	self.coinsLabel.Position = UDim2.new(0, 38, 0, 0)
	self.coinsLabel.BackgroundTransparency = 1
	self.coinsLabel.Text = "0 coins"
	self.coinsLabel.TextColor3 = CONFIG.TEXT_COINS
	self.coinsLabel.TextSize = 16
	self.coinsLabel.Font = BOLD_FONT
	self.coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.coinsLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.coinsLabel.Parent = currencyFrame
end

function NPCTradeUI:CreateContentArea()
	local contentY = CONFIG.HEADER_HEIGHT + CONFIG.CURRENCY_HEIGHT + 12
	
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -CONFIG.PADDING * 2, 1, -(contentY + CONFIG.PADDING))
	contentFrame.Position = UDim2.new(0, CONFIG.PADDING, 0, contentY)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = self.panel
	
	-- Scroll frame
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ItemsList"
	scrollFrame.Size = UDim2.new(1, 0, 1, 0)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = contentFrame
	
	self.itemsListFrame = scrollFrame
	
	-- List layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, CONFIG.ITEM_SPACING)
	listLayout.Parent = scrollFrame
	
	-- Padding
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 2)
	listPadding.PaddingBottom = UDim.new(0, 2)
	listPadding.Parent = scrollFrame
end

function NPCTradeUI:PopulateItems()
	-- Clear existing
	for _, frame in pairs(self.itemFrames) do
		frame:Destroy()
	end
	self.itemFrames = {}
	
	if self.mode == "buy" then
		self:PopulateBuyItems()
	else
		self:PopulateSellItems()
	end
end

function NPCTradeUI:PopulateBuyItems()
	for i, item in ipairs(self.shopItems) do
		local itemFrame = self:CreateItemFrame(item, i, "buy")
		table.insert(self.itemFrames, itemFrame)
	end
end

function NPCTradeUI:PopulateSellItems()
	for i, item in ipairs(self.sellableItems) do
		local itemFrame = self:CreateItemFrame(item, i, "sell")
		table.insert(self.itemFrames, itemFrame)
	end
	
	if #self.sellableItems == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyLabel"
		emptyLabel.Size = UDim2.new(1, -16, 0, 80)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No sellable items in your inventory"
		emptyLabel.TextColor3 = CONFIG.TEXT_SECONDARY
		emptyLabel.TextSize = 14
		emptyLabel.Font = BOLD_FONT
		emptyLabel.TextWrapped = true
		emptyLabel.Parent = self.itemsListFrame
		table.insert(self.itemFrames, emptyLabel)
	end
end

function NPCTradeUI:CreateItemFrame(item, index, tradeType)
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "Item_" .. item.itemId
	itemFrame.Size = UDim2.new(1, -4, 0, CONFIG.ITEM_HEIGHT)
	itemFrame.BackgroundColor3 = CONFIG.SLOT_COLOR
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = index
	itemFrame.Parent = self.itemsListFrame
	
	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, 6)
	frameCorner.Parent = itemFrame
	
	-- Icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, CONFIG.ICON_SIZE, 0, CONFIG.ICON_SIZE)
	iconContainer.Position = UDim2.new(0, 8, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	iconContainer.BorderSizePixel = 0
	iconContainer.Parent = itemFrame
	
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 4)
	iconCorner.Parent = iconContainer
	
	-- Create item icon
	self:CreateItemIcon(iconContainer, item.itemId)
	
	-- Item name
	local itemName = GetItemDisplayName(item.itemId) or "Unknown"
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(0, 140, 0, 20)
	nameLabel.Position = UDim2.new(0, 8 + CONFIG.ICON_SIZE + 8, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemName
	nameLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	nameLabel.TextSize = 14
	nameLabel.Font = BOLD_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = itemFrame
	
	-- Price display
	local price = tradeType == "buy" and item.price or item.sellPrice
	local pricePrefix = tradeType == "buy" and "" or "+"
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(0, 140, 0, 16)
	priceLabel.Position = UDim2.new(0, 8 + CONFIG.ICON_SIZE + 8, 0, 28)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = pricePrefix .. tostring(price) .. " coins"
	priceLabel.TextSize = 12
	priceLabel.Font = BOLD_FONT
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.Parent = itemFrame
	
	if tradeType == "buy" then
		local canAfford = self.playerCoins >= price
		priceLabel.TextColor3 = canAfford and CONFIG.TEXT_COINS or CONFIG.TEXT_INSUFFICIENT
	else
		priceLabel.TextColor3 = CONFIG.TEXT_COINS
	end
	
	-- Quantity for sell mode
	if tradeType == "sell" and item.count and item.count > 1 then
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		countLabel.Size = UDim2.new(0, 30, 0, 16)
		countLabel.Position = UDim2.new(0, CONFIG.ICON_SIZE - 2, 1, -2)
		countLabel.AnchorPoint = Vector2.new(1, 1)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "x" .. tostring(item.count)
		countLabel.TextColor3 = CONFIG.TEXT_PRIMARY
		countLabel.TextSize = 11
		countLabel.Font = BOLD_FONT
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.ZIndex = 5
		countLabel.Parent = iconContainer
	end
	
	-- Stock for buy mode
	if tradeType == "buy" and item.stock then
		local stockLabel = Instance.new("TextLabel")
		stockLabel.Name = "StockLabel"
		stockLabel.Size = UDim2.new(0, 80, 0, 14)
		stockLabel.Position = UDim2.new(0, 8 + CONFIG.ICON_SIZE + 8, 0, 44)
		stockLabel.BackgroundTransparency = 1
		stockLabel.Text = "Stock: " .. tostring(item.currentStock or item.stock)
		stockLabel.TextColor3 = CONFIG.TEXT_SECONDARY
		stockLabel.TextSize = 10
		stockLabel.Font = BOLD_FONT
		stockLabel.TextXAlignment = Enum.TextXAlignment.Left
		stockLabel.Parent = itemFrame
		item.stockLabel = stockLabel
	end
	
	-- Action button
	local buttonColor = tradeType == "buy" and CONFIG.BTN_BUY or CONFIG.BTN_SELL
	local buttonHoverColor = tradeType == "buy" and CONFIG.BTN_BUY_HOVER or CONFIG.BTN_SELL_HOVER
	local buttonText = tradeType == "buy" and "BUY" or "SELL"
	
	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, CONFIG.BUTTON_WIDTH, 0, CONFIG.BUTTON_HEIGHT)
	actionButton.Position = UDim2.new(1, -CONFIG.BUTTON_WIDTH - 8, 0.5, 0)
	actionButton.AnchorPoint = Vector2.new(0, 0.5)
	actionButton.BackgroundColor3 = buttonColor
	actionButton.BorderSizePixel = 0
	actionButton.Text = buttonText
	actionButton.TextColor3 = CONFIG.TEXT_PRIMARY
	actionButton.TextSize = 12
	actionButton.Font = BOLD_FONT
	actionButton.AutoButtonColor = false
	actionButton.Parent = itemFrame
	
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 4)
	buttonCorner.Parent = actionButton
	
	-- Button state
	local isEnabled = true
	if tradeType == "buy" then
		local canAfford = self.playerCoins >= price
		local inStock = (item.currentStock or item.stock or 0) > 0
		isEnabled = canAfford and inStock
	end
	
	if not isEnabled then
		actionButton.BackgroundColor3 = CONFIG.BTN_DISABLED
		actionButton.Active = false
	end
	
	item.actionButton = actionButton
	item.frame = itemFrame
	item.priceLabel = priceLabel
	
	-- Hover effects
	itemFrame.MouseEnter:Connect(function()
		itemFrame.BackgroundColor3 = CONFIG.SLOT_HOVER
	end)
	
	itemFrame.MouseLeave:Connect(function()
		itemFrame.BackgroundColor3 = CONFIG.SLOT_COLOR
	end)
	
	actionButton.MouseEnter:Connect(function()
		if actionButton.Active ~= false then
			actionButton.BackgroundColor3 = buttonHoverColor
		end
	end)
	
	actionButton.MouseLeave:Connect(function()
		if actionButton.Active ~= false then
			actionButton.BackgroundColor3 = buttonColor
		end
	end)
	
	actionButton.Activated:Connect(function()
		if actionButton.Active == false then return end
		SoundManager:PlaySFX("ui_click")
		
		if tradeType == "buy" then
			self:OnBuyItem(item)
		else
			self:OnSellItem(item)
		end
	end)
	
	return itemFrame
end

function NPCTradeUI:CreateItemIcon(container, itemId)
	if ToolConfig.IsTool(itemId) then
		local toolInfo = ToolConfig.GetToolInfo(itemId)
		if toolInfo and toolInfo.image then
			local image = Instance.new("ImageLabel")
			image.Name = "ToolImage"
			image.Size = UDim2.new(1, -6, 1, -6)
			image.Position = UDim2.new(0.5, 0, 0.5, 0)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.Image = toolInfo.image
			image.ScaleType = Enum.ScaleType.Fit
			image.Parent = container
		end
		return
	end
	
	if ArmorConfig.IsArmor(itemId) then
		local armorInfo = ArmorConfig.GetArmorInfo(itemId)
		if armorInfo and armorInfo.image then
			local image = Instance.new("ImageLabel")
			image.Name = "ArmorImage"
			image.Size = UDim2.new(1, -6, 1, -6)
			image.Position = UDim2.new(0.5, 0, 0.5, 0)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.Image = armorInfo.image
			image.ScaleType = Enum.ScaleType.Fit
			image.Parent = container
		end
		return
	end
	
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Parent = container
		return
	end
	
	BlockViewportCreator.CreateBlockViewport(
		container,
		itemId,
		UDim2.new(1, 0, 1, 0)
	)
end

function NPCTradeUI:OnBuyItem(item)
	if not self.npcId then return end
	
	EventManager:SendToServer("RequestNPCBuy", {
		npcId = self.npcId,
		itemId = item.itemId,
		quantity = 1
	})
end

function NPCTradeUI:OnSellItem(item)
	if not self.npcId then return end
	
	EventManager:SendToServer("RequestNPCSell", {
		npcId = self.npcId,
		itemId = item.itemId,
		quantity = 1
	})
end

function NPCTradeUI:UpdateCurrencyDisplay()
	if self.coinsLabel then
		self.coinsLabel.Text = string.format("%s coins", tostring(self.playerCoins))
	end
end

function NPCTradeUI:UpdateButtonStates()
	if self.mode == "buy" then
		for _, item in ipairs(self.shopItems) do
			if item.actionButton then
				local canAfford = self.playerCoins >= item.price
				local inStock = (item.currentStock or item.stock or 0) > 0
				local isEnabled = canAfford and inStock
				
				if isEnabled then
					item.actionButton.BackgroundColor3 = CONFIG.BTN_BUY
					item.actionButton.Active = true
				else
					item.actionButton.BackgroundColor3 = CONFIG.BTN_DISABLED
					item.actionButton.Active = false
				end
				
				if item.priceLabel then
					item.priceLabel.TextColor3 = canAfford and CONFIG.TEXT_COINS or CONFIG.TEXT_INSUFFICIENT
				end
				
				if item.stockLabel then
					item.stockLabel.Text = "Stock: " .. tostring(item.currentStock or item.stock)
				end
			end
		end
	end
end

function NPCTradeUI:Open(data)
	if not self.gui or not self.panel then
		warn("NPCTradeUI:Open - UI not initialized!")
		return
	end
	
	self.mode = data.mode or "buy"
	self.npcId = data.npcId
	self.playerCoins = data.playerCoins or 0
	
	-- Set title based on mode
	if self.mode == "buy" then
		self.titleLabel.Text = "SHOP KEEPER"
		self.shopItems = data.items or {}
	else
		self.titleLabel.Text = "MERCHANT"
		self.sellableItems = data.items or {}
	end
	
	self:UpdateCurrencyDisplay()
	self:PopulateItems()
	
	-- Use UIVisibilityManager for proper backdrop/cursor handling
	UIVisibilityManager:SetMode("npcTrade")
	
	-- Show UI
	self.gui.Enabled = true
	self.isOpen = true
	
	-- Notify tutorial system of NPC interaction
	local npcType = self.mode == "buy" and "shop" or "merchant"
	if TutorialManager and TutorialManager.OnNPCInteracted then
		TutorialManager:OnNPCInteracted(npcType)
	end
	
	SoundManager:PlaySFX("ui_open")
end

function NPCTradeUI:Close()
	if not self.isOpen then return end
	
	self.isOpen = false
	
	if self.gui then
		self.gui.Enabled = false
	end
	
	-- Notify server
	if self.npcId then
		EventManager:SendToServer("RequestNPCClose", {
			npcId = self.npcId
		})
	end
	
	self.npcId = nil
	
	-- Restore gameplay mode
	UIVisibilityManager:SetMode("gameplay")
	
	SoundManager:PlaySFX("ui_close")
end

function NPCTradeUI:Show()
	-- UIVisibilityManager callback - actual show is done in Open()
end

function NPCTradeUI:Hide()
	-- UIVisibilityManager callback - actual hide is done in Close()
end

function NPCTradeUI:IsOpen()
	return self.isOpen
end

function NPCTradeUI:RegisterEvents()
	-- Shop opened (buy mode)
	EventManager:RegisterEvent("NPCShopOpened", function(data)
		if data then
			self:Open({
				mode = "buy",
				npcId = data.npcId,
				items = data.items or {},
				playerCoins = data.playerCoins or 0
			})
		end
	end)
	
	-- Merchant opened (sell mode)
	EventManager:RegisterEvent("NPCMerchantOpened", function(data)
		if data then
			self:Open({
				mode = "sell",
				npcId = data.npcId,
				items = data.items or {},
				playerCoins = data.playerCoins or 0
			})
		end
	end)
	
	-- Trade result
	EventManager:RegisterEvent("NPCTradeResult", function(data)
		if not data then return end
		
		if data.success then
			self.playerCoins = data.newCoins or self.playerCoins
			self:UpdateCurrencyDisplay()
			
			local message = data.message or "Transaction successful!"
			ToastManager:Success(message, 2)
			
			if self.mode == "buy" and data.itemId then
				for _, item in ipairs(self.shopItems) do
					if item.itemId == data.itemId then
						item.currentStock = (item.currentStock or item.stock) - 1
						break
					end
				end
			end
			
			if self.mode == "sell" then
				-- Notify tutorial system of item sold
				if TutorialManager and TutorialManager.OnItemSold then
					TutorialManager:OnItemSold(data.itemId, 1)
				end
				self:RefreshSellableItems()
			end
			
			self:UpdateButtonStates()
			SoundManager:PlaySFX("purchase")
		else
			local message = data.message or "Transaction failed"
			ToastManager:Error(message, 3)
			SoundManager:PlaySFX("error")
		end
	end)
	
	-- Listen for coin updates
	GameState:OnPropertyChanged("playerData.coins", function(newValue)
		if self.isOpen then
			self.playerCoins = newValue or 0
			self:UpdateCurrencyDisplay()
			self:UpdateButtonStates()
		end
	end)
end

function NPCTradeUI:RefreshSellableItems()
	if self.npcId and self.mode == "sell" then
		EventManager:SendToServer("RequestNPCInteract", {
			npcId = self.npcId
		})
	end
end

return NPCTradeUI
