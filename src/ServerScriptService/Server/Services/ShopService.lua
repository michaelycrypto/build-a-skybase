--[[
	ShopService

	Handles shop transactions, item purchases, and shop data management.
	Integrates with PlayerService for currency management and ItemConfig for item data.
	Features stock replenishment every 1 minute similar to Grow a Garden.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Config = require(game.ReplicatedStorage.Shared.Config)
local ItemConfig = require(game.ReplicatedStorage.Configs.ItemConfig)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)

local ShopService = setmetatable({}, BaseService)
ShopService.__index = ShopService

function ShopService.new()
	local self = setmetatable(BaseService.new(), ShopService)

	self._logger = Logger:CreateContext("ShopService")
	self._eventManager = nil
	self._shopData = {
		items = {},
		categories = {"Mobs", "Spawners", "Upgrades", "Resources", "Crates"},
		featured = {}
	}

	-- Stock management system
	self._stockData = {
		-- Stock levels for each item
		stock = {},
		-- Last replenishment time
		lastReplenishment = 0,
		-- Replenishment interval from GameConfig
		replenishmentInterval = GameConfig.Shop.stock.replenishmentInterval,
		-- Maximum stock per item from GameConfig
		maxStock = GameConfig.Shop.stock.maxStock,
		-- Minimum stock per item from GameConfig
		minStock = GameConfig.Shop.stock.minStock
	}

	return self
end

function ShopService:Init()
	if self._initialized then
		return
	end

	self._logger.Info("Initializing ShopService...")

	-- Get EventManager instance
	self._eventManager = require(game.ReplicatedStorage.Shared.EventManager)

	-- Initialize shop data from ItemConfig
	self:InitializeShopData()

	-- Set up event handlers
	self:SetupEventHandlers()

	BaseService.Init(self)
	self._logger.Info("ShopService initialized")
end

function ShopService:Start()
	if self._started then
		return
	end

	-- Initialize stock system
	self:InitializeStock()

	-- Set started flag BEFORE starting replenishment loop
	self._started = true

	-- Start stock replenishment loop
	self:StartStockReplenishment()

	self._logger.Info("ShopService started with stock management")
end

function ShopService:Destroy()
	if self._destroyed then
		return
	end

	BaseService.Destroy(self)
	self._logger.Info("ShopService destroyed")
end

--[[
	Initialize shop data from ItemConfig
--]]
function ShopService:InitializeShopData()
	self._shopData.items = {}

	-- Get all purchasable items from ItemConfig
	local allItems = ItemConfig.Items

	for itemId, itemData in pairs(allItems) do
		-- Only add items that have a price and are purchasable
		if itemData.price and itemData.price > 0 then
			local rarityData = ItemConfig.GetItemRarity(itemData.rarity)

			-- Determine category based on item type
			local category = "Misc"
			if itemData.type == "MOB_SPAWNER" then
				category = "Spawners"
			elseif itemData.type == "DUNGEON_UPGRADE" or itemData.type == "SPAWNER_ENHANCEMENT" then
				category = "Upgrades"
			elseif itemData.type == "RESOURCE" then
				category = "Resources"
			elseif itemData.type == "CRATE" then
				category = "Crates"
			end

			table.insert(self._shopData.items, {
				id = itemId, -- Use the actual item ID from ItemConfig
				name = itemData.name,
				category = category,
				price = itemData.price,
				currency = "coins", -- All items use coins for now
				description = itemData.description,
				rarity = itemData.rarity,
				rarityColor = rarityData and rarityData.color or Color3.fromRGB(150, 150, 150),
				type = itemData.type,
				stats = itemData.stats,
				effects = itemData.effects,
				lootPool = itemData.lootPool
			})
		end
	end

	self._logger.Info("Initialized shop with " .. #self._shopData.items .. " items from ItemConfig")
end

--[[
	Set up event handlers for client requests
--]]
function ShopService:SetupEventHandlers()
	-- Event handlers are now set up in EventManager:CreateServerEventConfig
	-- This method is kept for compatibility but handlers are registered elsewhere
	self._logger.Info("Event handlers will be registered by EventManager")
end

--[[
	Process a purchase request
--]]
function ShopService:ProcessPurchase(player, itemId, quantity)
	self._logger.Info("Processing purchase", {
		playerName = player.Name,
		itemId = itemId,
		quantity = quantity or 1
	})

	-- Validate inputs
	if not player or not itemId then
		self._logger.Error("Invalid purchase parameters", {
			player = player,
			itemId = itemId,
			playerType = type(player)
		})
		return false
	end

	-- Validate player is a Player object
	if not player:IsA("Player") then
		self._logger.Error("Player parameter is not a Player object", {
			player = player,
			playerType = type(player)
		})
		return false
	end

	quantity = quantity or 1
	if quantity <= 0 then
		self._logger.Error("Invalid quantity", {quantity = quantity})
		return false
	end

	-- Find the item in ItemConfig first
	local itemConfig = ItemConfig.GetItemDefinition(itemId)
	if not itemConfig then
		self._logger.Error("Item not found in ItemConfig", {itemId = itemId})
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "Item not found: " .. itemId
			})
		end
		return false
	end

	-- Check if item is purchasable
	if not itemConfig.price or itemConfig.price <= 0 then
		self._logger.Error("Item is not purchasable", {itemId = itemId})
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "This item cannot be purchased"
			})
		end
		return false
	end

	-- Calculate total cost
	local totalCost = itemConfig.price * quantity

	-- Check if PlayerService is available
	if not self.Deps.PlayerService then
		self._logger.Error("PlayerService not available")
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "Service unavailable, please try again"
			})
		end
		return false
	end

	-- Get player data
	local playerData = self.Deps.PlayerService:GetPlayerData(player)
	if not playerData then
		self._logger.Error("Player data not found")
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "Player data not found"
			})
		end
		return false
	end

	-- Check if item is in stock
	if not self:IsItemInStock(itemId, quantity) then
		self._logger.Info("Item out of stock", {
			playerName = player.Name,
			itemId = itemId,
			requestedQuantity = quantity,
			availableStock = self:GetItemStock(itemId)
		})
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "This item is out of stock! Check back in a minute."
			})
		end
		return false
	end

	-- Check if player has enough currency (all items use coins for now)
	local currentCurrency = playerData.coins or 0
	if currentCurrency < totalCost then
		self._logger.Info("Insufficient currency", {
			playerName = player.Name,
			required = totalCost,
			current = currentCurrency,
			currency = "coins"
		})
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "You need " .. totalCost .. " coins to purchase this item"
			})
		end
		return false
	end

	-- Deduct currency
	local success = self.Deps.PlayerService:RemoveCurrency(player, "coins", totalCost)
	if not success then
		self._logger.Error("Failed to deduct currency")
		if self._eventManager then
			self._eventManager:FireEvent("ShowError", player, {
				message = "Failed to process payment"
			})
		end
		return false
	end

	-- Add item to inventory
	self.Deps.PlayerService:AddItem(player, itemId, quantity)

	-- Spawner tool sync removed

	-- Reduce stock
	self:ReduceStock(itemId, quantity)

	self._logger.Info("Purchase successful", {
		playerName = player.Name,
		itemId = itemId,
		quantity = quantity,
		totalCost = totalCost,
		currency = "coins"
	})

	return true
end

--[[
	Get item by ID from ItemConfig
--]]
function ShopService:GetItem(itemId)
	-- First check ItemConfig
	local itemConfig = ItemConfig.GetItemDefinition(itemId)
	if not itemConfig then
		return nil
	end

	-- Only return if item is purchasable
	if not itemConfig.price or itemConfig.price <= 0 then
		return nil
	end

	-- Return shop item format
	local rarityData = ItemConfig.GetItemRarity(itemConfig.rarity)
	local category = "Misc"
	if itemConfig.type == "MOB_SPAWNER" then
		category = "Spawners"
	elseif itemConfig.type == "DUNGEON_UPGRADE" or itemConfig.type == "SPAWNER_ENHANCEMENT" then
		category = "Upgrades"
	elseif itemConfig.type == "RESOURCE" then
		category = "Resources"
	elseif itemConfig.type == "CRATE" then
		category = "Crates"
	end

	return {
		id = itemId,
		name = itemConfig.name,
		category = category,
		price = itemConfig.price,
		currency = "coins",
		description = itemConfig.description,
		rarity = itemConfig.rarity,
		rarityColor = rarityData and rarityData.color or Color3.fromRGB(150, 150, 150),
		type = itemConfig.type,
		stats = itemConfig.stats,
		effects = itemConfig.effects,
		lootPool = itemConfig.lootPool
	}
end

--[[
	Get all shop items
--]]
function ShopService:GetAllItems()
	return self._shopData.items
end

--[[
	Get items by category
--]]
function ShopService:GetItemsByCategory(category)
	local items = {}
	for _, item in pairs(self._shopData.items) do
		if item.category == category then
			table.insert(items, item)
		end
	end
	return items
end

--[[
	Get shop data
--]]
function ShopService:GetShopData()
	return self._shopData
end

--[[
	Add new item to shop (deprecated - use ItemConfig instead)
--]]
function ShopService:AddItem(item)
	self._logger.Warn("AddItem is deprecated - add items to ItemConfig instead")
	return false
end

--[[
	Update item in shop (deprecated - update ItemConfig instead)
--]]
function ShopService:UpdateItem(itemId, updates)
	self._logger.Warn("UpdateItem is deprecated - update items in ItemConfig instead")
	return false
end

--[[
	Remove item from shop (deprecated - update ItemConfig instead)
--]]
function ShopService:RemoveItem(itemId)
	self._logger.Warn("RemoveItem is deprecated - update items in ItemConfig instead")
	return false
end

--[[
	Get featured items
--]]
function ShopService:GetFeaturedItems()
	return self._shopData.featured
end

--[[
	Set featured items
--]]
function ShopService:SetFeaturedItems(featuredItems)
	self._shopData.featured = featuredItems or {}
end

--[[
	Check if item is available for purchase
--]]
function ShopService:IsItemAvailable(itemId)
	local itemConfig = ItemConfig.GetItemDefinition(itemId)
	if not itemConfig then
		return false
	end

	return itemConfig.price and itemConfig.price > 0
end

--[[
	Get item price
--]]
function ShopService:GetItemPrice(itemId)
	local itemConfig = ItemConfig.GetItemDefinition(itemId)
	if not itemConfig then
		return 0
	end

	return itemConfig.price or 0
end

--[[
	Initialize stock system for all shop items using restock system
--]]
function ShopService:InitializeStock()
	self._stockData.stock = {}
	self._stockData.lastReplenishment = tick()

	-- Initialize stock structure for all purchasable items (start with 0 stock)
	for _, item in pairs(self._shopData.items) do
		if item.price and item.price > 0 then
			self._stockData.stock[item.id] = {
				current = 0, -- Start with 0 stock
				max = self._stockData.maxStock,
				min = self._stockData.minStock,
				lastRestocked = 0 -- Not restocked yet
			}
		end
	end

	self._logger.Debug("Initialized stock structure for " .. #self._shopData.items .. " items (all starting at 0)")

	-- Run initial restock to populate stock based on luck system
	self._logger.Debug("Running initial restock to populate shop...")
	self:ReplenishStock()

	-- Debug: Log total stock entries
	local stockCount = 0
	for _ in pairs(self._stockData.stock) do
		stockCount = stockCount + 1
	end
	self._logger.Debug("Total stock entries created: " .. stockCount)
end

--[[
	Get initial stock amount based on item rarity (DEPRECATED - now using restock system)
--]]
function ShopService:GetInitialStockForRarity(rarity)
	-- This function is deprecated - initial stock is now determined by the restock system
	self._logger.Warn("GetInitialStockForRarity is deprecated - using restock system instead")
	return 0
end

--[[
	Start the stock replenishment loop
--]]
function ShopService:StartStockReplenishment()
	self._logger.Debug("=== STARTING STOCK REPLENISHMENT LOOP ===")
	self._logger.Debug("Replenishment interval: " .. self._stockData.replenishmentInterval .. " seconds")
	self._logger.Debug("Service started: " .. tostring(self._started))
	self._logger.Debug("Service destroyed: " .. tostring(self._destroyed))

	task.spawn(function()
		self._logger.Debug("Replenishment loop spawned, starting wait cycle...")
		while self._started and not self._destroyed do
			self._logger.Debug("Waiting " .. self._stockData.replenishmentInterval .. " seconds before next replenishment...")
			task.wait(self._stockData.replenishmentInterval)

			if self._started and not self._destroyed then
				self._logger.Debug("Triggering replenishment cycle...")
				self:ReplenishStock()
			else
				self._logger.Debug("Service stopped or destroyed, ending replenishment loop")
				break
			end
		end
	self._logger.Debug("Replenishment loop ended")
	end)

	self._logger.Debug("Started stock replenishment loop (every " .. self._stockData.replenishmentInterval .. " seconds)")

	-- Debug: Log initial stock state
	self._logger.Debug("Initial stock state:")
	for itemId, stockInfo in pairs(self._stockData.stock) do
		self._logger.Debug("  " .. itemId .. ": " .. stockInfo.current .. "/" .. stockInfo.max)
	end
end

--[[
	Replenish stock for all items using luck-based system
--]]
function ShopService:ReplenishStock()
	local currentTime = tick()
	local replenishedCount = 0

	self._logger.Debug("=== STARTING STOCK REPLENISHMENT CYCLE ===")
	self._logger.Debug("Current time: " .. currentTime)
	self._logger.Debug("Total items to check: " .. (function()
		local count = 0
		for _ in pairs(self._stockData.stock) do count = count + 1 end
		return count
	end)())

	-- Get featured items sorted by priority (lower number = higher priority)
	local featuredItems = {}
	for _, featuredItem in ipairs(GameConfig.Shop.featuredItems) do
		table.insert(featuredItems, featuredItem)
	end
	table.sort(featuredItems, function(a, b) return a.priority < b.priority end)

	-- Apply luck-based restocking
	local itemsRestocked = 0
	local maxItemsPerRestock = GameConfig.Shop.restock.maxItemsPerRestock
	local guaranteedRestock = GameConfig.Shop.restock.guaranteedRestock

	for _, featuredItem in ipairs(featuredItems) do
		if itemsRestocked >= maxItemsPerRestock then
			break
		end

		local itemId = featuredItem.itemId
		local stockInfo = self._stockData.stock[itemId]

		if stockInfo and stockInfo.current < stockInfo.max then
			-- Calculate restock chance with modifiers
			local baseLuck = featuredItem.restockLuck
			local luckModifiers = GameConfig.Shop.restock.luckModifiers
			local finalLuck = baseLuck * luckModifiers.baseMultiplier

			-- Apply guaranteed restock for first item if enabled
			local shouldRestock = false
			if guaranteedRestock and itemsRestocked == 0 then
				shouldRestock = true
				self._logger.Debug("GUARANTEED RESTOCK for " .. itemId .. " (first item)")
			else
				shouldRestock = math.random() < finalLuck
			end

			if shouldRestock then
				-- Roll for new stock amount (can be 0 for rare items)
				local newStock = math.random(featuredItem.restockAmount.min, featuredItem.restockAmount.max)
				local oldStock = stockInfo.current

				-- Log the restock
				if newStock > oldStock then
					self._logger.Debug("REPLENISHING " .. itemId .. " from " .. oldStock .. " to " .. newStock .. " (luck: " .. string.format("%.1f%%", finalLuck * 100) .. ")")
					replenishedCount = replenishedCount + 1
					itemsRestocked = itemsRestocked + 1
				elseif newStock < oldStock then
					self._logger.Debug("STOCK DECREASED " .. itemId .. " from " .. oldStock .. " to " .. newStock .. " (rare item scarcity, luck: " .. string.format("%.1f%%", finalLuck * 100) .. ")")
				else
					self._logger.Debug("STOCK UNCHANGED " .. itemId .. " at " .. newStock .. " (rare item scarcity, luck: " .. string.format("%.1f%%", finalLuck * 100) .. ")")
				end

				-- Update stock to the rolled amount
				stockInfo.current = newStock
				stockInfo.lastRestocked = currentTime
			else
				self._logger.Debug("Item " .. itemId .. " failed restock roll (luck: " .. string.format("%.1f%%", finalLuck * 100) .. ")")
			end
		else
			self._logger.Debug("Item " .. itemId .. " already at max stock (" .. (stockInfo and stockInfo.current or 0) .. "/" .. (stockInfo and stockInfo.max or 0) .. ")")
		end
	end

	self._logger.Info("Replenishment cycle complete. Items replenished: " .. replenishedCount)

	self._stockData.lastReplenishment = currentTime

	-- Always notify clients about restock cycle (even if no items needed restocking)
	-- This keeps client timers synchronized
	if self._eventManager then
		self._logger.Debug("Broadcasting stock update to all clients after restock cycle")
		local success, error = pcall(function()
			self._eventManager:FireEventToAll("ShopStockUpdated", {
				stock = self._stockData.stock,
				lastReplenishment = currentTime,
				replenishmentInterval = self._stockData.replenishmentInterval
			})
		end)
		if not success then
			self._logger.Error("Failed to fire ShopStockUpdated event:", error)
		else
			self._logger.Debug("Successfully fired ShopStockUpdated event")
		end
	else
		self._logger.Error("EventManager not available for ShopStockUpdated")
	end

	-- Always show replenishment notification (even if no items needed restocking)
	self._logger.Debug("Shop replenishment cycle completed. Items replenished: " .. replenishedCount)

end

--[[
	Get replenish amount for a specific item based on its rarity
--]]
function ShopService:GetReplenishAmountForItem(itemId)
	local itemConfig = ItemConfig.GetItemDefinition(itemId)
	if not itemConfig then
		return 1
	end

	local rarity = itemConfig.rarity
	if rarity == "LEGENDARY" or rarity == "MYTHICAL" then
		return math.random(1, 1) -- Very rare, only 1 at a time
	elseif rarity == "ELITE" then
		return math.random(1, 2) -- Rare, 1-2 at a time
	elseif rarity == "SUPERIOR" then
		return math.random(1, 2) -- Uncommon, 1-2 at a time
	elseif rarity == "ENHANCED" then
		return math.random(2, 3) -- Common, 2-3 at a time
	else
		return math.random(3, 5) -- Basic, 3-5 at a time
	end
end

--[[
	Get current stock for an item
--]]
function ShopService:GetItemStock(itemId)
	local stockInfo = self._stockData.stock[itemId]
	if not stockInfo then
		return 0
	end

	return stockInfo.current
end

--[[
	Check if an item is in stock
--]]
function ShopService:IsItemInStock(itemId, quantity)
	quantity = quantity or 1
	local currentStock = self:GetItemStock(itemId)
	return currentStock >= quantity
end

--[[
	Reduce stock when an item is purchased
	This affects ALL players - stock is server-wide
--]]
function ShopService:ReduceStock(itemId, quantity)
	quantity = quantity or 1
	local stockInfo = self._stockData.stock[itemId]

	if stockInfo then
		stockInfo.current = math.max(stockInfo.current - quantity, 0)

		self._logger.Info("Reduced stock", {
			itemId = itemId,
			quantity = quantity,
			remainingStock = stockInfo.current
		})

		-- Notify all clients about stock update
		if self._eventManager then
			self._logger.Info("Broadcasting stock update to all clients after purchase")
			local success, error = pcall(function()
				self._eventManager:FireEventToAll("ShopStockUpdated", {
					stock = self._stockData.stock,
					lastReplenishment = self._stockData.lastReplenishment,
					replenishmentInterval = self._stockData.replenishmentInterval
				})
			end)
			if not success then
				self._logger.Error("Failed to fire ShopStockUpdated event:", error)
			else
				self._logger.Info("Successfully fired ShopStockUpdated event")
			end
		else
			self._logger.Error("EventManager not available for ShopStockUpdated")
		end
	end
end

--[[
	Get all stock information
--]]
function ShopService:GetStockData()
	return {
		stock = self._stockData.stock,
		lastReplenishment = self._stockData.lastReplenishment,
		replenishmentInterval = self._stockData.replenishmentInterval
	}
end

--[[
	Send stock data to a specific player
--]]
function ShopService:SendStockData(player)
	if not self._eventManager then
		self._logger.Error("EventManager not available")
		return
	end

	local stockData = self:GetStockData()

	-- Debug: Log what we're sending
	local stockCount = 0
	for _ in pairs(stockData.stock) do
		stockCount = stockCount + 1
	end

	self._logger.Info("Sending stock data to player " .. player.Name, {
		stockCount = stockCount,
		lastReplenishment = stockData.lastReplenishment,
		replenishmentInterval = stockData.replenishmentInterval
	})

	-- Debug: Log specific stock for featured items
	for _, featuredItem in ipairs(GameConfig.Shop.featuredItems) do
		local itemId = featuredItem.itemId
		local stockInfo = stockData.stock[itemId]
		if stockInfo then
			self._logger.Info("Stock for " .. itemId .. ": " .. stockInfo.current .. "/" .. stockInfo.max)
		else
			self._logger.Warn("No stock data found for " .. itemId)
		end
	end

	self._eventManager:FireEvent("ShopStockUpdated", player, stockData)
end

--[[
	Debug method to manually trigger restock (for testing)
--]]
function ShopService:DebugTriggerRestock()
	self._logger.Info("DEBUG: Manually triggering restock...")
	self:ReplenishStock()
end

--[[
	Debug method to check current stock state
--]]
function ShopService:DebugCheckStock()
	self._logger.Info("=== CURRENT STOCK STATE ===")
	for itemId, stockInfo in pairs(self._stockData.stock) do
		self._logger.Info(itemId .. ": " .. stockInfo.current .. "/" .. stockInfo.max)
	end
	self._logger.Info("Last replenishment: " .. self._stockData.lastReplenishment)
	self._logger.Info("Replenishment interval: " .. self._stockData.replenishmentInterval)
	self._logger.Info("Service started: " .. tostring(self._started))
	self._logger.Info("Service destroyed: " .. tostring(self._destroyed))
	self._logger.Info("EventManager available: " .. tostring(self._eventManager ~= nil))
end

--[[
	Debug method to force start replenishment loop
--]]
function ShopService:DebugStartReplenishment()
	self._logger.Info("DEBUG: Force starting replenishment loop...")
	self:StartStockReplenishment()
end

return ShopService