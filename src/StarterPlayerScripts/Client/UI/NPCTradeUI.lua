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

-- Load Upheaval font (matching WorldsPanel)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local _ = UpheavalFont -- Ensure font module loads
local CUSTOM_FONT_NAME = "Upheaval BRK"

-- Configuration matching WorldsPanel styling exactly
local CONFIG = {
	-- Panel dimensions (matching WorldsPanel structure)
	TOTAL_WIDTH = 420,
	HEADER_HEIGHT = 54,
	BODY_HEIGHT = 420,
	SHADOW_HEIGHT = 18,

	-- Content dimensions
	CURRENCY_HEIGHT = 40,
	ITEM_HEIGHT = 80,  -- Taller cards like WorldsPanel
	PADDING = 12,
	ICON_SIZE = 56,
	BUTTON_WIDTH = 80,
	BUTTON_HEIGHT = 40,
	LABEL_HEIGHT = 22,
	LABEL_SPACING = 8,

	-- Colors (matching WorldsPanel exactly)
	PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),

	-- Border colors (matching WorldsPanel)
	COLUMN_BORDER_COLOR = Color3.fromRGB(77, 77, 77),
	COLUMN_BORDER_THICKNESS = 3,
	SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_BORDER_THICKNESS = 2,

	-- Corner radius
	CORNER_RADIUS = 8,
	SLOT_CORNER_RADIUS = 6,

	-- Background image (for icon slots only)
	BACKGROUND_IMAGE = "rbxassetid://82824299358542",
	BACKGROUND_IMAGE_TRANSPARENCY = 0.6,

	-- Button colors (matching WorldsPanel)
	BTN_BUY = Color3.fromRGB(80, 180, 80),
	BTN_BUY_HOVER = Color3.fromRGB(90, 200, 90),
	BTN_SELL = Color3.fromRGB(255, 200, 50),
	BTN_SELL_HOVER = Color3.fromRGB(255, 220, 80),
	BTN_DISABLED = Color3.fromRGB(60, 60, 60),
	BTN_DISABLED_TRANSPARENCY = 0.7,

	-- Text colors
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_SECONDARY = Color3.fromRGB(185, 185, 195),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),
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

	-- Create ScreenGui (matching WorldsPanel pattern)
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "NPCTradeUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150
	self.gui.IgnoreGuiInset = false  -- Matching WorldsPanel
	self.gui.Enabled = false
	self.gui.Parent = playerGui

	-- Apply responsive scaling (matching WorldsPanel pattern)
	self:EnsureResponsiveScale(self.gui)

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

function NPCTradeUI:EnsureResponsiveScale(contentFrame)
	if self.uiScale and self.uiScale.Parent then
		return self.uiScale
	end

	if not contentFrame then
		return nil
	end

	local target = contentFrame.Parent
	if not (target and target:IsA("GuiBase2d")) then
		target = contentFrame
	end

	self.scaleTarget = target

	local existing = target:FindFirstChild("ResponsiveScale")
	if existing and existing:IsA("UIScale") then
		self.uiScale = existing
		if not CollectionService:HasTag(existing, "scale_component") then
			CollectionService:AddTag(existing, "scale_component")
		end
		return existing
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.6)
	uiScale.Parent = target
	CollectionService:AddTag(uiScale, "scale_component")
	self.uiScale = uiScale

	return uiScale
end

function NPCTradeUI:RegisterScrollingLayout(layout)
	if not layout or not layout:IsA("UIListLayout") then
		return
	end

	if not (self.uiScale and self.uiScale.Parent) then
		self:EnsureResponsiveScale(self.scaleTarget or self.gui or layout.Parent)
	end

	if not (self.uiScale and self.uiScale.Parent) then
		return
	end

	if not CollectionService:HasTag(layout, "scrolling_frame_layout_component") then
		CollectionService:AddTag(layout, "scrolling_frame_layout_component")
	end

	local referral = layout:FindFirstChild("scale_component_referral")
	if not referral then
		referral = Instance.new("ObjectValue")
		referral.Name = "scale_component_referral"
		referral.Parent = layout
	end
	referral.Value = self.uiScale
end

function NPCTradeUI:CreatePanel()
	-- Container frame (centers everything, transparent - matching WorldsPanel)
	local totalHeight = CONFIG.HEADER_HEIGHT + CONFIG.BODY_HEIGHT

	local container = Instance.new("Frame")
	container.Name = "TradeContainer"
	container.Size = UDim2.new(0, CONFIG.TOTAL_WIDTH, 0, totalHeight)
	container.Position = UDim2.new(0.5, 0, 0.5, -CONFIG.HEADER_HEIGHT)  -- Vertical offset matching WorldsPanel
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = self.gui
	self.container = container

	-- Header (OUTSIDE panel, matching WorldsPanel)
	self:CreateHeader(container)

	-- Body panel (below header)
	self:CreateBody(container)
end

function NPCTradeUI:CreateHeader(parent)
	-- Header frame (transparent, floats above panel - matching WorldsPanel)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(0, CONFIG.TOTAL_WIDTH, 0, CONFIG.HEADER_HEIGHT)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent

	-- Title (Upheaval font, size 54 - matching WorldsPanel)
	self.titleLabel = Instance.new("TextLabel")
	self.titleLabel.Name = "Title"
	self.titleLabel.Size = UDim2.new(1, -50, 1, 0)
	self.titleLabel.BackgroundTransparency = 1
	self.titleLabel.Text = "SHOP"
	self.titleLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	self.titleLabel.Font = Enum.Font.Code
	self.titleLabel.TextSize = 54
	self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.titleLabel.Parent = headerFrame
	FontBinder.apply(self.titleLabel, CUSTOM_FONT_NAME)

	-- Close button (top-right corner - matching WorldsPanel)
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.new(0, 44, 0, 44),
		position = UDim2.new(1, 0, 0, 0),
		anchorPoint = Vector2.new(1, 0)
	})

	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = closeIcon.Size
	closeBtn.Position = closeIcon.Position
	closeBtn.AnchorPoint = closeIcon.AnchorPoint
	closeBtn.BackgroundTransparency = 1
	closeBtn.Image = closeIcon.Image
	closeBtn.ScaleType = closeIcon.ScaleType
	closeBtn.Parent = headerFrame
	closeIcon:Destroy()

	-- Close button animation (matching WorldsPanel)
	local rotateInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 0}):Play()
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)
end

function NPCTradeUI:CreateBody(parent)
	-- Body frame (transparent container for panel + shadow - matching WorldsPanel)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.new(0, CONFIG.TOTAL_WIDTH, 0, CONFIG.BODY_HEIGHT)
	bodyFrame.Position = UDim2.new(0, 0, 0, CONFIG.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = parent

	-- Main panel (with background color - matching WorldsPanel ContentPanel)
	self.panel = Instance.new("Frame")
	self.panel.Name = "TradePanel"
	self.panel.Size = UDim2.new(0, CONFIG.TOTAL_WIDTH, 0, CONFIG.BODY_HEIGHT)
	self.panel.Position = UDim2.new(0, 0, 0, 0)
	self.panel.BackgroundColor3 = CONFIG.PANEL_BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.ZIndex = 1
	self.panel.Parent = bodyFrame

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	corner.Parent = self.panel

	-- Shadow below panel (matching WorldsPanel)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, CONFIG.TOTAL_WIDTH, 0, CONFIG.SHADOW_HEIGHT)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.new(0, 0, 0, CONFIG.BODY_HEIGHT)
	shadow.BackgroundColor3 = CONFIG.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = bodyFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	shadowCorner.Parent = shadow

	-- Border (matching WorldsPanel column border)
	local border = Instance.new("UIStroke")
	border.Color = CONFIG.COLUMN_BORDER_COLOR
	border.Thickness = CONFIG.COLUMN_BORDER_THICKNESS
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = self.panel

	-- Padding inside panel
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, CONFIG.PADDING)
	padding.PaddingBottom = UDim.new(0, CONFIG.PADDING)
	padding.PaddingLeft = UDim.new(0, CONFIG.PADDING)
	padding.PaddingRight = UDim.new(0, CONFIG.PADDING)
	padding.Parent = self.panel

	-- Currency display
	self:CreateCurrencyDisplay()

	-- Scrollable content area
	self:CreateContentArea()
end

function NPCTradeUI:CreateCurrencyDisplay()
	-- Currency display (transparent frame)
	local currencyFrame = Instance.new("Frame")
	currencyFrame.Name = "CurrencyDisplay"
	currencyFrame.Size = UDim2.new(1, 0, 0, CONFIG.CURRENCY_HEIGHT)
	currencyFrame.Position = UDim2.new(0, 0, 0, 0)
	currencyFrame.BackgroundTransparency = 1
	currencyFrame.BorderSizePixel = 0
	currencyFrame.Parent = self.panel

	local currencyCorner = Instance.new("UICorner")
	currencyCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	currencyCorner.Parent = currencyFrame

	-- Cash icon (matching MainHUD)
	local cashIcon = IconManager:CreateIcon(currencyFrame, "Currency", "Cash", {
		size = UDim2.new(0,  28, 0, 28)
	})
	if cashIcon then
		cashIcon.Position = UDim2.new(0, 12, 0.5, 0)
		cashIcon.AnchorPoint = Vector2.new(0, 0.5)
		cashIcon.ZIndex = 2
	end

	-- Coin amount (matching MainHUD green color)
	self.coinsLabel = Instance.new("TextLabel")
	self.coinsLabel.Name = "CoinsLabel"
	self.coinsLabel.Size = UDim2.new(1, -56, 1, 0)
	self.coinsLabel.Position = UDim2.new(0, 44, 0, 0)
	self.coinsLabel.BackgroundTransparency = 1
	self.coinsLabel.Text = "0"
	self.coinsLabel.TextColor3 = Color3.fromRGB(34, 197, 94)  -- Green matching MainHUD
	self.coinsLabel.TextSize = 28
	self.coinsLabel.Font = BOLD_FONT
	self.coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.coinsLabel.TextYAlignment = Enum.TextYAlignment.Center
	self.coinsLabel.TextStrokeTransparency = 0
	self.coinsLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	self.coinsLabel.ZIndex = 2
	self.coinsLabel.Parent = currencyFrame

	-- Add stroke for better visibility
	local coinsStroke = Instance.new("UIStroke")
	coinsStroke.Color = Color3.fromRGB(0, 0, 0)
	coinsStroke.Thickness = 2
	coinsStroke.Parent = self.coinsLabel
end

function NPCTradeUI:CreateContentArea()
	-- Content starts after currency display
	local contentY = CONFIG.CURRENCY_HEIGHT + CONFIG.LABEL_SPACING

	-- Section label (matching WorldsPanel label style)
	local sectionLabel = Instance.new("TextLabel")
	sectionLabel.Name = "SectionLabel"
	sectionLabel.Size = UDim2.new(1, 0, 0, CONFIG.LABEL_HEIGHT)
	sectionLabel.Position = UDim2.new(0, 0, 0, contentY)
	sectionLabel.BackgroundTransparency = 1
	sectionLabel.Font = BOLD_FONT
	sectionLabel.TextSize = 14
	sectionLabel.TextColor3 = CONFIG.TEXT_MUTED
	sectionLabel.Text = "ITEMS"
	sectionLabel.TextXAlignment = Enum.TextXAlignment.Left
	sectionLabel.Parent = self.panel
	self.sectionLabel = sectionLabel

	contentY = contentY + CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING

	-- Content frame fills remaining space
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, 0, 1, -contentY)
	contentFrame.Position = UDim2.new(0, 0, 0, contentY)
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
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.Parent = contentFrame

	self.itemsListFrame = scrollFrame

	-- List layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)  -- Consistent spacing between cards
	listLayout.Parent = scrollFrame

	-- Padding for list view margins
	local listPadding = Instance.new("UIPadding")
	listPadding.PaddingTop = UDim.new(0, 6)
	listPadding.PaddingBottom = UDim.new(0, 12)
	listPadding.PaddingLeft = UDim.new(0, 6)
	listPadding.PaddingRight = UDim.new(0, 6)
	listPadding.Parent = scrollFrame

	-- Register scrolling layout for proper scaling (matching WorldsPanel)
	self:RegisterScrollingLayout(listLayout)
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
		emptyLabel.Size = UDim2.new(1, -16, 0, 100)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No sellable items in your inventory"
		emptyLabel.TextColor3 = CONFIG.TEXT_MUTED
		emptyLabel.TextSize = 16
		emptyLabel.Font = BOLD_FONT
		emptyLabel.TextWrapped = true
		emptyLabel.TextYAlignment = Enum.TextYAlignment.Center
		emptyLabel.Parent = self.itemsListFrame
		table.insert(self.itemFrames, emptyLabel)
	end
end

function NPCTradeUI:CreateItemFrame(item, index, tradeType)
	-- Outer container sits in list view (handles margins)
	local outerContainer = Instance.new("Frame")
	outerContainer.Name = "ItemOuter_" .. item.itemId
	outerContainer.Size = UDim2.new(1, 0, 0, CONFIG.ITEM_HEIGHT + CONFIG.SHADOW_HEIGHT / 2)
	outerContainer.BackgroundTransparency = 1
	outerContainer.ClipsDescendants = false
	outerContainer.LayoutOrder = index
	outerContainer.Parent = self.itemsListFrame

	-- Inner container holds card + shadow
	local container = Instance.new("Frame")
	container.Name = "ItemContainer_" .. item.itemId
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.Parent = outerContainer

	-- Card (solid background like WorldsPanel world cards)
	local card = Instance.new("Frame")
	card.Name = "ItemCard_" .. item.itemId
	card.Size = UDim2.new(1, 0, 0, CONFIG.ITEM_HEIGHT)
	card.Position = UDim2.new(0, 0, 0, 0)
	card.BackgroundColor3 = CONFIG.PANEL_BG_COLOR
	card.BorderSizePixel = 0
	card.ZIndex = 2
	card.Parent = container

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	cardCorner.Parent = card

	-- Card border (column border style like WorldsPanel)
	local cardBorder = Instance.new("UIStroke")
	cardBorder.Color = CONFIG.COLUMN_BORDER_COLOR
	cardBorder.Thickness = CONFIG.COLUMN_BORDER_THICKNESS
	cardBorder.Transparency = 0
	cardBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	cardBorder.Parent = card

	-- Shadow below card (positioned relative to card)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(1, 0, 0, CONFIG.SHADOW_HEIGHT)
	shadow.Position = UDim2.new(0, 0, 0, CONFIG.ITEM_HEIGHT - CONFIG.SHADOW_HEIGHT / 2)
	shadow.BackgroundColor3 = CONFIG.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	shadowCorner.Parent = shadow

	-- Icon container (with slot styling)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, CONFIG.ICON_SIZE, 0, CONFIG.ICON_SIZE)
	iconContainer.Position = UDim2.new(0, 12, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundColor3 = CONFIG.SLOT_BG_COLOR
	iconContainer.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	iconContainer.BorderSizePixel = 0
	iconContainer.ZIndex = 3
	iconContainer.Parent = card

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	iconCorner.Parent = iconContainer

	-- Icon background image
	local iconBgImage = Instance.new("ImageLabel")
	iconBgImage.Name = "BackgroundImage"
	iconBgImage.Size = UDim2.new(1, 0, 1, 0)
	iconBgImage.BackgroundTransparency = 1
	iconBgImage.Image = CONFIG.BACKGROUND_IMAGE
	iconBgImage.ImageTransparency = CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	iconBgImage.ScaleType = Enum.ScaleType.Fit
	iconBgImage.ZIndex = 1
	iconBgImage.Parent = iconContainer

	-- Icon border
	local iconBorder = Instance.new("UIStroke")
	iconBorder.Color = CONFIG.SLOT_BORDER_COLOR
	iconBorder.Thickness = CONFIG.SLOT_BORDER_THICKNESS
	iconBorder.Transparency = 0
	iconBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	iconBorder.Parent = iconContainer

	-- Create item icon
	self:CreateItemIcon(iconContainer, item.itemId)

	-- Text offset from icon
	local textX = 12 + CONFIG.ICON_SIZE + 12

	-- Check if this is a stack item (buy mode only)
	local isStackItem = tradeType == "buy" and item.stackSize and item.stackSize > 1
	local stackSize = item.stackSize or 1

	-- Item name (append stack count for stack items)
	local itemName = GetItemDisplayName(item.itemId) or "Unknown"
	if isStackItem then
		itemName = itemName .. " (×" .. stackSize .. ")"
	end
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	nameLabel.Size = UDim2.new(1, -textX - CONFIG.BUTTON_WIDTH - 24, 0, 24)
	nameLabel.Position = UDim2.new(0, textX, 0, 12)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = itemName
	nameLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	nameLabel.TextSize = 18
	nameLabel.Font = BOLD_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.ZIndex = 3
	nameLabel.Parent = card

	-- Price display (show per-item price for stack items)
	local price = tradeType == "buy" and item.price or item.sellPrice
	local pricePrefix = tradeType == "buy" and "" or "+"
	local priceText = pricePrefix .. tostring(price) .. " coins"
	if isStackItem then
		-- Show per-item price breakdown
		local perItem = math.floor(price / stackSize)
		priceText = priceText .. " (" .. perItem .. "/ea)"
	end
	local priceLabel = Instance.new("TextLabel")
	priceLabel.Name = "PriceLabel"
	priceLabel.Size = UDim2.new(1, -textX - CONFIG.BUTTON_WIDTH - 24, 0, 20)
	priceLabel.Position = UDim2.new(0, textX, 0, 36)
	priceLabel.BackgroundTransparency = 1
	priceLabel.Text = priceText
	priceLabel.TextSize = 14
	priceLabel.Font = BOLD_FONT
	priceLabel.TextXAlignment = Enum.TextXAlignment.Left
	priceLabel.ZIndex = 3
	priceLabel.Parent = card

	if tradeType == "buy" then
		local canAfford = self.playerCoins >= price
		priceLabel.TextColor3 = canAfford and CONFIG.TEXT_COINS or CONFIG.TEXT_INSUFFICIENT
	else
		priceLabel.TextColor3 = CONFIG.TEXT_COINS
	end

	-- Stack badge for stack items (shown on icon)
	if isStackItem then
		local stackBadge = Instance.new("TextLabel")
		stackBadge.Name = "StackBadge"
		stackBadge.Size = UDim2.new(0, 28, 0, 18)
		stackBadge.Position = UDim2.new(1, -2, 1, -2)
		stackBadge.AnchorPoint = Vector2.new(1, 1)
		stackBadge.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
		stackBadge.BackgroundTransparency = 0.1
		stackBadge.Text = tostring(stackSize)
		stackBadge.TextColor3 = CONFIG.TEXT_PRIMARY
		stackBadge.TextSize = 12
		stackBadge.Font = BOLD_FONT
		stackBadge.TextStrokeTransparency = 0
		stackBadge.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		stackBadge.ZIndex = 6
		stackBadge.Parent = iconContainer

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = stackBadge
	end

	-- Quantity for sell mode (on icon)
	if tradeType == "sell" and item.count and item.count > 1 then
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "CountLabel"
		countLabel.Size = UDim2.new(0, 40, 0, 20)
		countLabel.Position = UDim2.new(1, -4, 1, -4)
		countLabel.AnchorPoint = Vector2.new(1, 1)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = tostring(item.count)
		countLabel.TextColor3 = CONFIG.TEXT_PRIMARY
		countLabel.TextSize = 14
		countLabel.Font = BOLD_FONT
		countLabel.TextStrokeTransparency = 0.3
		countLabel.TextXAlignment = Enum.TextXAlignment.Right
		countLabel.ZIndex = 5
		countLabel.Parent = iconContainer
	end

	-- Stock for buy mode
	if tradeType == "buy" and item.stock then
		local stockLabel = Instance.new("TextLabel")
		stockLabel.Name = "StockLabel"
		stockLabel.Size = UDim2.new(1, -textX - CONFIG.BUTTON_WIDTH - 24, 0, 18)
		stockLabel.Position = UDim2.new(0, textX, 0, 54)
		stockLabel.BackgroundTransparency = 1
		stockLabel.Text = "Stock: " .. tostring(item.currentStock or item.stock)
		stockLabel.TextColor3 = CONFIG.TEXT_MUTED
		stockLabel.TextSize = 12
		stockLabel.Font = BOLD_FONT
		stockLabel.TextXAlignment = Enum.TextXAlignment.Left
		stockLabel.ZIndex = 3
		stockLabel.Parent = card
		item.stockLabel = stockLabel
	end

	-- Action button
	local buttonColor = tradeType == "buy" and CONFIG.BTN_BUY or CONFIG.BTN_SELL
	local buttonHoverColor = tradeType == "buy" and CONFIG.BTN_BUY_HOVER or CONFIG.BTN_SELL_HOVER
	local buttonText = tradeType == "buy" and "BUY" or "SELL"

	local actionButton = Instance.new("TextButton")
	actionButton.Name = "ActionButton"
	actionButton.Size = UDim2.new(0, CONFIG.BUTTON_WIDTH, 0, CONFIG.BUTTON_HEIGHT)
	actionButton.Position = UDim2.new(1, -12, 0.5, 0)
	actionButton.AnchorPoint = Vector2.new(1, 0.5)
	actionButton.BackgroundColor3 = buttonColor
	actionButton.BackgroundTransparency = 0
	actionButton.BorderSizePixel = 0
	actionButton.Text = buttonText
	actionButton.TextColor3 = CONFIG.TEXT_PRIMARY
	actionButton.TextSize = isStackItem and 12 or 14 -- Slightly smaller for stack items
	actionButton.Font = BOLD_FONT
	actionButton.AutoButtonColor = false
	actionButton.ZIndex = 4
	actionButton.Parent = card

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	buttonCorner.Parent = actionButton

	local buttonBorder = Instance.new("UIStroke")
	buttonBorder.Color = CONFIG.SLOT_BORDER_COLOR
	buttonBorder.Thickness = CONFIG.SLOT_BORDER_THICKNESS
	buttonBorder.Transparency = 0
	buttonBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	buttonBorder.Parent = actionButton

	-- Button state
	local isEnabled = true
	if tradeType == "buy" then
		local canAfford = self.playerCoins >= price
		local inStock = (item.currentStock or item.stock or 0) > 0
		isEnabled = canAfford and inStock
	end

	if not isEnabled then
		actionButton.BackgroundColor3 = CONFIG.BTN_DISABLED
		actionButton.BackgroundTransparency = CONFIG.BTN_DISABLED_TRANSPARENCY
		actionButton.Active = false
	end

	item.actionButton = actionButton
	item.frame = card
	item.container = outerContainer
	item.priceLabel = priceLabel
	item.isStackItem = isStackItem
	item.displayStackSize = stackSize

	-- Button hover effects only (no card hover)
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

	return outerContainer
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
			image.ZIndex = 4
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
			image.ZIndex = 4
			image.Parent = container
		end
		return
	end

	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
		icon.Position = UDim2.new(0.5, 0, 0.5, 0)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ZIndex = 4
		icon.Parent = container
		return
	end

	local viewport = BlockViewportCreator.CreateBlockViewport(
		container,
		itemId,
		UDim2.new(1, 0, 1, 0)
	)
	if viewport then
		viewport.ZIndex = 4
		-- Recursively set ZIndex on all children for proper visibility
		for _, child in ipairs(viewport:GetDescendants()) do
			if child:IsA("GuiObject") or child:IsA("ViewportFrame") then
				child.ZIndex = 4
			end
		end
	end
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
		self.coinsLabel.Text = tostring(self.playerCoins)
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
					item.actionButton.BackgroundTransparency = 0
					item.actionButton.Active = true
				else
					item.actionButton.BackgroundColor3 = CONFIG.BTN_DISABLED
					item.actionButton.BackgroundTransparency = CONFIG.BTN_DISABLED_TRANSPARENCY
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

	-- Set title and section label based on mode
	-- Title uses NPC's display name (e.g., "FARMER", "BUILDER", "MERCHANT")
	if self.mode == "buy" then
		self.titleLabel.Text = (data.shopTitle and data.shopTitle:upper()) or "SHOP"
		if self.sectionLabel then
			self.sectionLabel.Text = "ITEMS FOR SALE"
		end
		self.shopItems = data.items or {}
	else
		self.titleLabel.Text = (data.shopTitle and data.shopTitle:upper()) or "MERCHANT"
		if self.sectionLabel then
			self.sectionLabel.Text = "YOUR ITEMS"
		end
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
				playerCoins = data.playerCoins or 0,
				shopTitle = data.shopTitle,
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
				playerCoins = data.playerCoins or 0,
				shopTitle = data.shopTitle,
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
				-- Notify tutorial system of item bought
				if TutorialManager and TutorialManager.OnItemBought then
					TutorialManager:OnItemBought(data.itemId, 1)
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
