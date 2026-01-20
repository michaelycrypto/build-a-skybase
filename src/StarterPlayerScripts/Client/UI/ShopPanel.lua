--[[
	ShopPanel.lua - Shop Interface with Stock Management
	Vertical layout showing all items with stock information
	Clean single-column design similar to "Grow a Garden"
	Features stock replenishment every 1 minute
--]]

local ShopPanel = {}

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local InputService = require(script.Parent.Parent.Input.InputService)

-- Dependencies
local GameConfig = require(game:GetService("ReplicatedStorage").Configs.GameConfig)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local EventManager = require(game:GetService("ReplicatedStorage").Shared.EventManager)
local ShopApi = require(game:GetService("ReplicatedStorage").Shared.Api.ShopApi)
local GameState = require(script.Parent.Parent.Managers.GameState)
local ButtonFactory = require(script.Parent.Parent.Managers.Buttons.ButtonFactory)
local ToastManager = require(script.Parent.Parent.Managers.ToastManager)

-- State
local panel = nil
local itemsList = nil
local searchBox = nil
local sortDropdown = nil
local shopData = {
	items = {},
	filteredItems = {},
	searchTerm = "",
	sortBy = "name",
	stock = {},
	lastReplenishment = 0,
	replenishmentInterval = GameConfig.Shop.stock.replenishmentInterval
}
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

-- Configuration for vertical layout (using GameConfig)
local SHOP_CONFIG = {
	-- Items list
	list = {
		itemHeight = GameConfig.Shop.ui.itemHeight,
		spacing = GameConfig.Shop.ui.spacing,
		padding = GameConfig.Shop.ui.padding
	},

	-- Item cards
	cards = {
		iconSize = GameConfig.Shop.ui.iconSize
	},

	-- Layout spacing
	spacing = {
		section = 20, -- Between major sections
		element = 12, -- Between elements
		content = 16 -- Content padding
	}
}

--[[
	Create content for PanelManager integration
--]]
function ShopPanel:CreateContent(contentFrame, data)
	if not contentFrame then
		return self:Create()
	end

	if not panel then
		panel = {contentFrame = contentFrame}
	else
		panel.contentFrame = contentFrame
	end

	self:CreateCustomLayout(contentFrame)
	print("ShopPanel: Created vertical shop content")
end

--[[
	Create the shop panel using UIComponents (legacy method)
--]]
function ShopPanel:Create()
	panel = UIComponents:CreatePanel({
		name = "Shop",
		title = "Shop",
		icon = {category = "General", name = "Shop"},
		size = "shop", -- Use wide size for better layout
		parent = playerGui
	})

	-- Create a custom layout container inside the content frame
	self:CreateCustomLayout(panel.contentFrame)

	print("ShopPanel: Created vertical shop panel")
end

--[[
	Create custom layout with simplified structure
--]]
function ShopPanel:CreateCustomLayout(contentFrame)
	if not contentFrame then
		warn("ShopPanel: No content frame available")
		return
	end

	-- Initialize shop data
	self:InitializeShopData()

	-- Create restock timer container (fixed at top of content frame, inside content area)
	local restockContainer = Instance.new("Frame")
	restockContainer.Name = "RestockContainer"
	restockContainer.Size = UDim2.new(1, -20, 0, 20) -- Very compact height, account for 10px padding on each side
	restockContainer.Position = UDim2.new(0, 10, 0, 0) -- 10px from sides, 0px from top
	restockContainer.BackgroundTransparency = 1
	restockContainer.Parent = contentFrame

	-- Create scrollable content container (below restock timer)
	local scrollContainer = Instance.new("Frame")
	scrollContainer.Name = "ScrollContainer"
	scrollContainer.Size = UDim2.new(1, -20, 1, -20) -- Account for 10px padding on sides, 20px for restock timer + 20px spacing
	scrollContainer.Position = UDim2.new(0, 10, 0, 20) -- 10px from sides, 20px from top (20px timer + 0px spacing)
	scrollContainer.BackgroundTransparency = 1
	scrollContainer.Parent = contentFrame

	-- Create the restock timer
	self:CreateRestockTimer(restockContainer)

	-- Create simplified items list directly in scroll container
	self:CreateItemsList(scrollContainer)

	-- Initial filter to show all mob heads
	self:FilterItems()

	-- Update button states based on current player balance
	self:UpdatePurchaseButtonStates()

	-- Set up GameState listener for balance changes
	self:SetupGameStateListener()

	-- Set up stock listener and request initial stock data
	self:SetupStockListener()
	self:RequestStockData()

	-- Don't initialize countdown timer here - wait for server response
end

--[[
	Create simplified items list directly in scroll container
--]]
function ShopPanel:CreateItemsList(parent)
	-- Create scroll frame for the content
	local scrollFrame = UIComponents:CreateScrollFrame({
		parent = parent,
		size = UDim2.new(1, 0, 1, 0)
	})

	-- Remove the default UIPadding from UIComponents
	local existingPadding = scrollFrame.content:FindFirstChild("UIPadding")
	if existingPadding then
		existingPadding:Destroy()
	end

	-- Items list container (direct child of scroll content)
	itemsList = Instance.new("Frame")
	itemsList.Name = "ItemsList"
	itemsList.Size = UDim2.new(1, 0, 0, 0)
	itemsList.AutomaticSize = Enum.AutomaticSize.Y
	itemsList.BackgroundTransparency = 1
	itemsList.Parent = scrollFrame.content

	-- Add UIPadding to the items list container to keep borders within bounds
	local itemsPadding = Instance.new("UIPadding")
	itemsPadding.PaddingTop = UDim.new(0, 10)
	itemsPadding.PaddingBottom = UDim.new(0, 10)
	itemsPadding.PaddingLeft = UDim.new(0, 4) -- 4px left padding
	itemsPadding.PaddingRight = UDim.new(0, 4) -- 4px right padding
	itemsPadding.Parent = itemsList

	-- Vertical list layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, SHOP_CONFIG.list.spacing)
	listLayout.Parent = itemsList

	-- Populate with all mob heads initially
	self:PopulateItemsList()
end

--[[
	Set up GameState listener for balance changes
--]]
function ShopPanel:SetupGameStateListener()
	-- Listen for player data changes (specifically coins)
	GameState:OnPropertyChanged("playerData.coins", function(newValue, oldValue, path)
		-- Update purchase button states when balance changes
		self:UpdatePurchaseButtonStates()
	end)
end



--[[
	Create top bar with balance display and restock timer (legacy function - now handled directly)
--]]
function ShopPanel:CreateTopBar(parent)
	-- This function is now deprecated - restock timer is created directly in CreateCustomLayout
	-- Keeping for compatibility but functionality moved to CreateRestockTimer
end

--[[
	Create restock timer display
--]]
function ShopPanel:CreateRestockTimer(parent)
	-- Create timer container (left-aligned, very compact)
	local timerContainer = Instance.new("Frame")
	timerContainer.Name = "RestockTimer"
	timerContainer.Size = UDim2.new(0, 0, 1, 0) -- Full height of parent, auto-width
	timerContainer.AutomaticSize = Enum.AutomaticSize.X -- Auto-size width to fit content
	timerContainer.Position = UDim2.new(0, 0, 0, 0) -- Left-aligned, no padding
	timerContainer.BackgroundTransparency = 1 -- Completely transparent background
	timerContainer.Parent = parent

	-- Create timer label (very compact, left-aligned, no padding)
	local timerLabel = Instance.new("TextLabel")
	timerLabel.Name = "TimerLabel"
	timerLabel.Size = UDim2.new(0, 0, 1, 0) -- Full height of container, auto-width
	timerLabel.AutomaticSize = Enum.AutomaticSize.X -- Auto-size width to fit text content
	timerLabel.BackgroundTransparency = 1
	timerLabel.Text = "Restock: --:--"
	timerLabel.TextColor3 = GameConfig.UI_SETTINGS.colors.textSecondary -- Grey text
	timerLabel.TextSize = GameConfig.UI_SETTINGS.typography.sizes.body.small -- Smaller text for compactness
	timerLabel.Font = GameConfig.UI_SETTINGS.typography.fonts.bold -- Bold font
	timerLabel.TextXAlignment = Enum.TextXAlignment.Left -- Left-aligned
	timerLabel.TextYAlignment = Enum.TextYAlignment.Center
	timerLabel.Parent = timerContainer

	-- No stroke for restock timer text

	-- Store reference for updates
	self.restockTimerLabel = timerLabel

	-- Start the timer update loop
	self:StartRestockTimer()
end

--[[
	Start the restock timer update loop

	FLOW:
	1. Server runs restock every 10 seconds
	2. Server sends ShopStockUpdated event with lastReplenishment timestamp
	3. Client calculates countdown using server's timestamp
	4. Client shows accurate countdown until next server restock

	The client timer is synchronized with server timing using lastReplenishment.
--]]
function ShopPanel:StartRestockTimer()
	if self.restockTimerConnection then
		self.restockTimerConnection:Disconnect()
	end

	self.restockTimerConnection = game:GetService("RunService").Heartbeat:Connect(function()
		self:UpdateRestockTimer()
	end)
end

--[[
	Update the restock timer display
	Uses server's lastReplenishment timestamp to calculate accurate countdown
--]]
function ShopPanel:UpdateRestockTimer()
	if not self.restockTimerLabel then
		return
	end

	-- If we haven't received server data yet, show loading
	if not shopData.lastReplenishment or shopData.lastReplenishment == 0 then
		self.restockTimerLabel.Text = "Restock: Loading..."
		self.restockTimerLabel.TextColor3 = GameConfig.UI_SETTINGS.colors.textSecondary
		return
	end

	-- Calculate time based on server's lastReplenishment timestamp
	local replenishmentInterval = shopData.replenishmentInterval or 10
	local currentTime = tick()
	local timeSinceLastRestock = currentTime - shopData.lastReplenishment
	local timeUntilNextRestock = replenishmentInterval - (timeSinceLastRestock % replenishmentInterval)

	-- Ensure we don't show negative time
	timeUntilNextRestock = math.max(0, timeUntilNextRestock)

	-- Format as MM:SS
	local minutes = math.floor(timeUntilNextRestock / 60)
	local seconds = math.floor(timeUntilNextRestock % 60)
	local timeString = string.format("%02d:%02d", minutes, seconds)

	self.restockTimerLabel.Text = "Restock: " .. timeString
	self.restockTimerLabel.TextColor3 = GameConfig.UI_SETTINGS.colors.textSecondary
end

--[[
	Initialize shop data (ItemConfig removed - shop is now empty)
	Items should be fetched from ShopService API instead
--]]
function ShopPanel:InitializeShopData()
	shopData.items = {}
	-- ItemConfig was removed - shop items should be fetched from ShopService API
	-- For now, shop is empty. Items can be loaded via ShopApi:GetShopData() if needed
	print("ShopPanel: Initialized with 0 items (ItemConfig removed)")
end

--[[
	Filter mob heads by search term
--]]
function ShopPanel:FilterItems()
	self:ApplyFilters()
	self:PopulateItemsList()
end

--[[
	Apply filters and sorting to mob heads
--]]
function ShopPanel:ApplyFilters()
	shopData.filteredItems = {}

	-- Filter by search term
	for _, item in ipairs(shopData.items) do
		local searchMatch = shopData.searchTerm == "" or
			string.find(string.lower(item.name), string.lower(shopData.searchTerm)) or
			string.find(string.lower(item.description), string.lower(shopData.searchTerm))

		if searchMatch then
			table.insert(shopData.filteredItems, item)
		end
	end

	-- Sort items
	table.sort(shopData.filteredItems, function(a, b)
		if shopData.sortBy == "name" then
			return a.name < b.name
		elseif shopData.sortBy == "price" then
			return a.price < b.price
		elseif shopData.sortBy == "rarity" then
			return a.rarity < b.rarity
		end
		return a.name < b.name
	end)
end

--[[
	Populate mob heads list
--]]
function ShopPanel:PopulateItemsList()
	if not itemsList then return end

	-- Clear existing items
	for _, child in pairs(itemsList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	-- Create mob head cards
	for i, itemData in ipairs(shopData.filteredItems) do
		self:CreateItemCard(itemData, i)
	end
end

--[[
	Create individual mob head card (flex layout: icon left, info center, button right)
--]]
function ShopPanel:CreateItemCard(itemData, index)
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = itemData.name:gsub(" ", "") .. "Item"
	itemFrame.Size = UDim2.new(1, -4, 0, SHOP_CONFIG.list.itemHeight) -- 4px smaller to fit border inside scroll frame
	itemFrame.BackgroundColor3 = GameConfig.UI_SETTINGS.colors.backgroundSecondary
	itemFrame.BackgroundTransparency = GameConfig.UI_SETTINGS.designSystem.transparency.light
	itemFrame.BorderSizePixel = 0
	itemFrame.LayoutOrder = index
	itemFrame.Parent = itemsList

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, GameConfig.UI_SETTINGS.designSystem.borderRadius.md)
	itemCorner.Parent = itemFrame

	-- Rarity border
	local rarityBorder = Instance.new("UIStroke")
	rarityBorder.Color = itemData.rarityColor
	rarityBorder.Thickness = 2
	rarityBorder.Parent = itemFrame

	-- Item content (flex layout: icon left, info center, button right)
	local itemContent = Instance.new("Frame")
	itemContent.Name = "ItemContent"
	itemContent.Size = UDim2.new(1, 0, 1, 0)
	itemContent.BackgroundTransparency = 1
	itemContent.Parent = itemFrame


	-- Use absolute positioning for proper layout control
	-- No layout needed - we'll position elements manually

	-- Item icon container (left side) - 90x90 frame with transparent black background
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, 90, 0, 90)
	iconContainer.Position = UDim2.new(0, 10, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Black background
	iconContainer.BackgroundTransparency = 0.95 -- 0.95 transparent
	iconContainer.BorderSizePixel = 0
	iconContainer.Parent = itemContent

	-- Add corner radius to icon container
	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = iconContainer

	-- Item icon (centered in container)
	local itemIcon = Instance.new("ImageLabel")
	itemIcon.Name = "ItemIcon"
	itemIcon.Size = UDim2.new(0, SHOP_CONFIG.cards.iconSize, 0, SHOP_CONFIG.cards.iconSize)
	itemIcon.Position = UDim2.new(0.5, 0, 0.5, 0)
	itemIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	itemIcon.BackgroundTransparency = 1 -- Make background fully transparent
	itemIcon.BorderSizePixel = 0
	itemIcon.ScaleType = Enum.ScaleType.Fit -- Ensure icon fits properly
	itemIcon.Parent = iconContainer

	-- Apply skull icon using IconManager
	IconManager:ApplyIcon(itemIcon, "General", "Skull", {
		size = SHOP_CONFIG.cards.iconSize, -- Use the exact icon size
		imageColor3 = itemData.rarityColor,
		scaleType = Enum.ScaleType.Fit
	})

	-- Item info container (vertical layout: name, stock, buy button stacked)
	local infoContainer = Instance.new("Frame")
	infoContainer.Name = "InfoContainer"
	infoContainer.Size = UDim2.new(1, -90 - 16 - 10, 1, 0) -- Full height, accounting for 90px icon container + 16px spacing + 10px offset
	infoContainer.Position = UDim2.new(0, 90 + 16 + 10, 0, 0) -- 90px icon container + 16px spacing + 10px offset
	infoContainer.BackgroundTransparency = 1
	infoContainer.Parent = itemContent

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Vertical
	infoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	infoLayout.SortOrder = Enum.SortOrder.LayoutOrder
	infoLayout.Padding = UDim.new(0, 4) -- Reduced padding for more compact layout
	infoLayout.Parent = infoContainer

	-- Item name (top of vertical stack)
	local itemName = Instance.new("TextLabel")
	itemName.Name = "ItemName"
	itemName.Size = UDim2.new(1, 0, 0, GameConfig.UI_SETTINGS.typography.sizes.body.large) -- Use large body size
	itemName.BackgroundTransparency = 1
	itemName.Text = itemData.name
	itemName.TextColor3 = GameConfig.UI_SETTINGS.titleLabel.textColor -- White text
	itemName.TextSize = GameConfig.UI_SETTINGS.typography.sizes.body.large -- Large body size
	itemName.Font = GameConfig.UI_SETTINGS.typography.fonts.bold
	itemName.TextXAlignment = Enum.TextXAlignment.Left
	itemName.TextScaled = true
	itemName.LayoutOrder = 1
	itemName.Parent = infoContainer

	-- Add black stroke to item name (consistent with header title)
	local itemNameStroke = Instance.new("UIStroke")
	itemNameStroke.Color = GameConfig.UI_SETTINGS.titleLabel.stroke.color -- Black stroke
	itemNameStroke.Thickness = GameConfig.UI_SETTINGS.titleLabel.stroke.thickness -- 2px stroke
	itemNameStroke.Parent = itemName

	-- Stock information (middle of vertical stack)
	local stockInfo = Instance.new("TextLabel")
	stockInfo.Name = "StockInfo"
	stockInfo.Size = UDim2.new(1, 0, 0, GameConfig.UI_SETTINGS.typography.sizes.body.small)
	stockInfo.BackgroundTransparency = 1
	stockInfo.Text = "Stock: Loading..."
	stockInfo.TextColor3 = GameConfig.UI_SETTINGS.colors.textSecondary -- Grey text
	stockInfo.TextSize = GameConfig.UI_SETTINGS.typography.sizes.body.small -- Small body size
	stockInfo.Font = GameConfig.UI_SETTINGS.typography.fonts.bold -- Bold font
	stockInfo.TextXAlignment = Enum.TextXAlignment.Left
	stockInfo.TextScaled = true
	stockInfo.LayoutOrder = 2
	stockInfo.Parent = infoContainer

	-- No stroke for stock info text

	-- Store reference for stock updates
	itemData.stockInfo = stockInfo

	-- Purchase button (bottom of vertical stack)
	local purchaseButton = ButtonFactory:CreateBuyButton({
		name = "PurchaseButton",
		parent = infoContainer,
		currency = itemData.currency or "coins",
		amount = itemData.price,
		variant = "secondary", -- Start with secondary variant (grey) until stock is loaded
		size = "compact", -- Use compact size for buy buttons
		position = UDim2.new(0, 0, 0, 0), -- Position will be handled by layout
		callback = function()
			self:PurchaseItem(itemData)
		end
	})

	-- Set layout order for the border frame (which is the actual parent element)
	if purchaseButton.borderFrame then
		purchaseButton.borderFrame.LayoutOrder = 3
	end

	-- Store references for later updates
	itemData.purchaseButton = purchaseButton
	itemData.frame = itemFrame

	-- Initially disable the button until stock data is loaded
	purchaseButton:SetEnabled(false)
	purchaseButton:SetAvailable(false)
end

--[[
	Purchase an item
--]]
function ShopPanel:PurchaseItem(itemData)
	-- Debug: Check what we're sending
    print("ShopPanel: Purchasing item", itemData.id, "quantity", 1)

	-- Validate item data
	if not itemData or not itemData.id then
		warn("ShopPanel: Invalid item data for purchase", itemData)
		return
	end

	-- Send purchase request to server
	local itemId = itemData.id
	local quantity = 1
    print("ShopPanel: Sending purchase via ShopApi with itemId:", itemId, "quantity:", quantity)

	-- Ensure both parameters are valid
    if itemId and quantity then
        ShopApi.Purchase(itemId, quantity)
	else
		warn("ShopPanel: Invalid parameters for PurchaseItem - itemId:", itemId, "quantity:", quantity)
	end

	SoundManager:PlaySFX("purchase")

	-- Don't show purchase toast here - wait for server confirmation
	-- The server will send a stock update that will trigger the appropriate toast
end


--[[
	Check if this stock update was a restock (vs just a purchase)
	We can detect this by checking if any items increased in stock
--]]
function ShopPanel:CheckIfRestockOccurred(stockData, previousStockState)
	if not stockData or not stockData.stock then
		return false
	end

	-- Check if any items increased in stock (indicating a restock)
	for itemId, stockInfo in pairs(stockData.stock) do
		if type(stockInfo) == "table" then
			local previousStock = previousStockState[itemId]
			if previousStock and stockInfo.current > previousStock.current then
				print("ShopPanel: Detected restock for", itemId, "from", previousStock.current, "to", stockInfo.current)
				return true -- This item was restocked (stock increased)
			end
		end
	end

	return false
end

--[[
	Play restock animation on the timer
--]]
function ShopPanel:PlayRestockAnimation()
	if not self.restockTimerLabel then
		return
	end

	-- Create a brief highlight animation
	local originalColor = self.restockTimerLabel.TextColor3
	local highlightColor = Color3.fromRGB(0, 255, 0) -- Green highlight

	-- Tween to highlight color
	local highlightTween = TweenService:Create(self.restockTimerLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextColor3 = highlightColor}
	)

	-- Tween back to original color
	local resetTween = TweenService:Create(self.restockTimerLabel,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{TextColor3 = originalColor}
	)

	-- Play the animation sequence
	highlightTween:Play()
	highlightTween.Completed:Connect(function()
		resetTween:Play()
	end)
end

--[[
	Play restock animations for all items that were restocked
--]]
function ShopPanel:PlayRestockAnimations()
	-- Play animation on timer
	self:PlayRestockAnimation()

	-- Play animations on items that were restocked
	for _, itemData in ipairs(shopData.filteredItems) do
		if itemData.frame then
			local stockInfo = shopData.stock[itemData.id]
			if stockInfo and type(stockInfo) == "table" and stockInfo.current == stockInfo.max then
				-- This item is at full stock, play restock animation
				self:PlayItemRestockAnimation(itemData.frame)
			end
		end
	end
end

--[[
	Play restock animation on an item card
--]]
function ShopPanel:PlayItemRestockAnimation(itemFrame)
	if not itemFrame then
		return
	end

	-- Create a brief glow effect
	local originalTransparency = itemFrame.BackgroundTransparency
	local glowTransparency = originalTransparency - 0.1 -- Make it slightly less transparent

	-- Tween to glow
	local glowTween = TweenService:Create(itemFrame,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = glowTransparency}
	)

	-- Tween back to original
	local resetTween = TweenService:Create(itemFrame,
		TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{BackgroundTransparency = originalTransparency}
	)

	-- Play the animation sequence
	glowTween:Play()
	glowTween.Completed:Connect(function()
		resetTween:Play()
	end)
end

--[[
	Play microanimations for purchase feedback (shake animation for supply text)
--]]
function ShopPanel:PlayPurchaseAnimations(itemData)
	-- Shake/buzz animation for the supply text label
	if itemData.stockInfo then
		local originalPosition = itemData.stockInfo.Position
		local shakeTweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 0, false, 0)

		-- Create a quick shake effect
		local shakeSequence = {
			{Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset + 2, originalPosition.Y.Scale, originalPosition.Y.Offset)},
			{Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset - 2, originalPosition.Y.Scale, originalPosition.Y.Offset)},
			{Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset + 1, originalPosition.Y.Scale, originalPosition.Y.Offset)},
			{Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset - 1, originalPosition.Y.Scale, originalPosition.Y.Offset)},
			{Position = originalPosition}
		}

		-- Play shake animation
		for i, target in ipairs(shakeSequence) do
			local tween = TweenService:Create(itemData.stockInfo, shakeTweenInfo, target)
			tween:Play()
			if i < #shakeSequence then
				tween.Completed:Wait()
			end
		end
	end
end

--[[
	Show the shop panel
--]]
function ShopPanel:Show()
	if panel and panel.contentFrame then
		panel.contentFrame.Visible = true
	elseif panel then
		panel.Visible = true
	end
end

--[[
	Hide the shop panel
--]]
function ShopPanel:Hide()
	if panel and panel.contentFrame then
		panel.contentFrame.Visible = false
	elseif panel then
		panel.Visible = false
	end
end

--[[
	Toggle the shop panel visibility
--]]
function ShopPanel:Toggle()
	if panel and panel.contentFrame then
		panel.contentFrame.Visible = not panel.contentFrame.Visible
	elseif panel then
		panel.Visible = not panel.Visible
	end
end

--[[
	Request stock data from server
--]]
function ShopPanel:RequestStockData()
	print("ShopPanel: Requesting stock data from server...")
    ShopApi.RequestStock()
end

--[[
	Debug method to manually request stock data (for testing)
--]]
function ShopPanel:DebugRequestStock()
	print("ShopPanel: DEBUG - Manually requesting stock data...")
	self:RequestStockData()
end

--[[
	Update stock information for all items
	Stock is server-wide: when one player buys an item, stock decreases for all players
--]]
function ShopPanel:UpdateStockDisplay(stockData)
	-- Validate stock data
	if not stockData then
		warn("ShopPanel: Received nil stock data")
		return
	end

	-- Store previous stock state BEFORE updating (for restock detection)
	local previousStockState = {}
	for itemId, stockInfo in pairs(shopData.stock) do
		if type(stockInfo) == "table" then
			previousStockState[itemId] = {
				current = stockInfo.current,
				max = stockInfo.max
			}
		end
	end

	-- Update stock data
	shopData.stock = stockData.stock or {}
	shopData.lastReplenishment = stockData.lastReplenishment or 0
	shopData.replenishmentInterval = stockData.replenishmentInterval or 10

	-- Server sent us fresh data with correct lastReplenishment timestamp

	print("ShopPanel: Stock updated, interval:", shopData.replenishmentInterval)

	-- Check if this was a restock (not just a purchase)
	local wasRestock = self:CheckIfRestockOccurred(stockData, previousStockState)
	if wasRestock then
		print("ShopPanel: Restock detected - playing animations")
		self:PlayRestockAnimations()

		-- Show toast notification with shop icon
		ToastManager:Show({
			message = "Shop has been restocked!",
			type = "info",
			duration = 3,
			icon = "Shop",
			iconCategory = "General"
		})
	else
		print("ShopPanel: Stock update received (not a restock)")
	end

	-- Debug: Log specific stock for featured items
	for _, featuredItem in ipairs(GameConfig.Shop.featuredItems) do
		local itemId = featuredItem.itemId
		local stockInfo = shopData.stock[itemId]
		if stockInfo then
			print("ShopPanel: Stock for " .. itemId .. ":", stockInfo.current, "/", stockInfo.max)
		else
			print("ShopPanel: No stock data found for " .. itemId)
		end
	end

	-- Play restock animation on the timer (only if this was a restock)
	if wasRestock then
		self:PlayRestockAnimation()
	end

	-- Update stock display for each item
	for _, itemData in ipairs(shopData.filteredItems) do
		if itemData.stockInfo then
			local stockInfo = shopData.stock[itemData.id]
			local currentStock = 0
			local previousStock = itemData.previousStock or 0

			-- Handle different stock data structures
			if type(stockInfo) == "number" then
				currentStock = stockInfo
			elseif type(stockInfo) == "table" and stockInfo.current then
				currentStock = stockInfo.current
			end

			local stockText = "Stock: " .. tostring(currentStock)

			-- Keep grey text with no stroke for stock information
			itemData.stockInfo.TextColor3 = GameConfig.UI_SETTINGS.colors.textSecondary -- Grey text
			itemData.stockInfo.Text = stockText

			-- Note: Restock animations are now handled in PlayRestockAnimations()

			-- Check if this was a successful purchase (stock decreased by 1)
			local previousStock = itemData.previousStock or 0
			if previousStock > currentStock and previousStock - currentStock == 1 then
				-- Successful purchase confirmed by server - show toast
				ToastManager:Success("Purchased " .. itemData.name, GameConfig.Shop.toast.purchaseDuration)
			end

			-- Store current stock for next comparison
			itemData.previousStock = currentStock

			-- Debug: Log stock update for each item
			print("ShopPanel: Updated stock for", itemData.id, "to", currentStock, "(server-wide stock)")
		end
	end

	-- Update purchase button states based on stock
	self:UpdatePurchaseButtonStates()
end

--[[
	Update purchase button states based on player balance and stock
--]]
function ShopPanel:UpdatePurchaseButtonStates()
	-- Get current player balance from GameState
	local playerData = GameState:Get("playerData")
	local playerBalance = playerData and playerData.coins or 0

	for _, itemData in ipairs(shopData.filteredItems) do
		if itemData.purchaseButton then
			local canAfford = playerBalance >= itemData.price

			-- Handle different stock data structures
			local stockInfo = shopData.stock[itemData.id]
			local currentStock = 0
			if type(stockInfo) == "number" then
				currentStock = stockInfo
			elseif type(stockInfo) == "table" and stockInfo.current then
				currentStock = stockInfo.current
			end

			local inStock = currentStock > 0
			local canPurchase = canAfford and inStock

			-- Debug: Log button state update
			print("ShopPanel: Updating button for", itemData.id, "- canAfford:", canAfford, "inStock:", inStock, "currentStock:", currentStock, "(server-wide stock)")

			-- Set button state using the new OOP system
			if not canAfford then
				-- Cannot afford - use danger variant (red)
				itemData.purchaseButton:SetVariant("danger")
				itemData.purchaseButton:SetEnabled(false)
				itemData.purchaseButton:SetAvailable(false)
				print("ShopPanel: Set button to danger variant (cannot afford)")
			elseif not inStock then
				-- Out of stock - use secondary variant (gray)
				itemData.purchaseButton:SetVariant("secondary")
				itemData.purchaseButton:SetEnabled(false)
				itemData.purchaseButton:SetAvailable(false)
				print("ShopPanel: Set button to secondary variant (out of stock)")
			else
				-- Can afford and in stock - use success variant (green)
				itemData.purchaseButton:SetVariant("success")
				itemData.purchaseButton:SetEnabled(true)
				itemData.purchaseButton:SetAvailable(true)
				print("ShopPanel: Set button to success variant (can purchase)")
			end

			-- Always show the same amount (price with icon)
			itemData.purchaseButton:SetAmount(itemData.price)
		end
	end
end

--[[
	Set up stock update listener
--]]
function ShopPanel:SetupStockListener()
	-- Prevent multiple listeners
	if self._stockListenerSetup then
		print("ShopPanel: Stock listener already set up, skipping...")
		return
	end

	-- Listen for stock updates from server
	print("ShopPanel: Setting up ShopStockUpdated listener...")
    local success, error = pcall(function()
        ShopApi.OnStockUpdated(function(stockData)
			local timestamp = os.date("%H:%M:%S")
			print("ShopPanel: [" .. timestamp .. "] Received ShopStockUpdated event from server")
			if stockData then
				-- Log the specific stock levels for featured items
				for _, featuredItem in ipairs(GameConfig.Shop.featuredItems) do
					local itemId = featuredItem.itemId
					local stockInfo = stockData.stock and stockData.stock[itemId]
					if stockInfo then
						print("ShopPanel: [" .. timestamp .. "] " .. itemId .. " stock:", stockInfo.current .. "/" .. stockInfo.max)
					end
				end
				self:UpdateStockDisplay(stockData)
			else
				warn("ShopPanel: [" .. timestamp .. "] Received nil stock data in ShopStockUpdated event")
			end
        end)
	end)

	if not success then
		warn("ShopPanel: Failed to set up ShopStockUpdated listener:", error)
	else
		print("ShopPanel: Successfully set up ShopStockUpdated listener")
		self._stockListenerSetup = true
	end
end

--[[
	Cleanup function
--]]
function ShopPanel:Cleanup()
	if panel then
		panel:Destroy()
		panel = nil
	end

	itemsList = nil
	searchBox = nil
	sortDropdown = nil
	shopData = {
		items = {},
		filteredItems = {},
		searchTerm = "",
		sortBy = "name",
		stock = {},
		lastReplenishment = 0,
		replenishmentInterval = 10
	}
end

--[[
	Clean up resources when panel is destroyed
--]]
function ShopPanel:Destroy()
	if self.restockTimerConnection then
		self.restockTimerConnection:Disconnect()
		self.restockTimerConnection = nil
	end
end

return ShopPanel