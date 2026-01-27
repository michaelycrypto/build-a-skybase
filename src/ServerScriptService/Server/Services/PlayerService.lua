--[[
	PlayerService

	Handles player data management, client communication, and player lifecycle.
	Integrates with EventManager for client-server communication.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local Config = require(game.ReplicatedStorage.Shared.Config)

local PlayerService = setmetatable({}, BaseService)
PlayerService.__index = PlayerService

-- Services
local Players = game:GetService("Players")

function PlayerService.new()
	local self = setmetatable(BaseService.new(), PlayerService)

	self._logger = Logger:CreateContext("PlayerService")
	self._playerData = {}
	self._connections = {}
	self._eventManager = nil

	return self
end

function PlayerService:Init()
	if self._initialized then
		return
	end

	-- Get EventManager instance
	self._eventManager = require(game.ReplicatedStorage.Shared.EventManager)

	-- NOTE: Player event connections are NOT set up here for single-place architecture.
	-- Bootstrap controls when players are initialized based on server role (Router/Hub/World).
	-- This prevents double-initialization and allows proper timing of data loading.

	BaseService.Init(self)
	self._logger.Debug("PlayerService initialized")
end

function PlayerService:Start()
	if self._started then
		return
	end

	self._logger.Debug("PlayerService started")
end

function PlayerService:Destroy()
	if self._destroyed then
		return
	end

	-- Cleanup all connections
	for _, connection in pairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}

	-- Save all player data
	for _, player in pairs(Players:GetPlayers()) do
		self:SavePlayerData(player)
	end

	self._playerData = {}

	BaseService.Destroy(self)
	self._logger.Info("PlayerService destroyed")
end

--[[
	Connect to player events
--]]
function PlayerService:_connectPlayerEvents()
	self._connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	self._connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)
end

--[[
	Handle player joining
--]]
function PlayerService:OnPlayerAdded(player)
	self._logger.Info("Player added", {playerName = player.Name, userId = player.UserId})

	-- Load player data from DataStore
	local playerData
	if self.Deps.PlayerDataStoreService then
		playerData = self.Deps.PlayerDataStoreService:LoadPlayerData(player)
		
		-- If nil, session is locked by another server (player will be kicked)
		if not playerData then
			self._logger.Warn("Failed to load player data (session locked)", {player = player.Name})
			return
		end
	else
		self._logger.Warn("PlayerDataStoreService not available, using local data")
		-- Fallback to local data
		playerData = {
			profile = {
				level = 1,
				experience = 0,
				coins = 100,
				gems = 10,
			},
			statistics = {
				gamesPlayed = 0,
				enemiesDefeated = 0,
				coinsEarned = 0,
				itemsCollected = 0,
				totalPlayTime = 0
			},
			inventory = {},
			equippedArmor = {
				helmet = nil,
				chestplate = nil,
				leggings = nil,
				boots = nil
			},
			dungeonData = {
				mobSpawnerSlots = {}
			},
			dailyRewards = {
				currentStreak = 0,
				lastClaimDate = nil,
				totalDaysClaimed = 0
			},
			settings = {
				musicVolume = 0.8,
				soundVolume = 1.0,
				enableNotifications = true
			},
			lastSave = os.time()
		}
	end

	-- Store local reference (for backward compatibility with existing code)
	-- Map new structure to old structure
	self._playerData[player.UserId] = {
		level = playerData.profile.level,
		experience = playerData.profile.experience,
		coins = playerData.profile.coins,
		gems = playerData.profile.gems,
		manaCrystals = playerData.profile.manaCrystals or 0,
		statistics = playerData.statistics,
		inventory = playerData.inventory,
		equippedArmor = playerData.equippedArmor or {helmet = nil, chestplate = nil, leggings = nil, boots = nil},
		dungeonData = playerData.dungeonData,
		dailyRewards = playerData.dailyRewards,
		settings = playerData.settings,
		lastSave = playerData.lastSave,
		-- Hunger/Saturation system (Minecraft-style)
		hunger = playerData.profile.hunger or 20,
		saturation = playerData.profile.saturation or 20
	}

	-- IMPORTANT: Create inventory structure FIRST (before loading data)
	self._logger.Debug("About to create inventory. Deps exists?", self.Deps ~= nil)
	self._logger.Debug("PlayerInventoryService exists?", self.Deps and self.Deps.PlayerInventoryService ~= nil)

	if self.Deps and self.Deps.PlayerInventoryService then
		self._logger.Debug("Creating inventory for", player.Name)
		-- This creates the empty inventory structure
		self.Deps.PlayerInventoryService:OnPlayerAdded(player)

		-- NOW load saved data into the inventory (if exists)
		if playerData.inventory and playerData.inventory.hotbar and #playerData.inventory.hotbar > 0 then
			self._logger.Debug("Loading saved inventory data for", player.Name)
			self.Deps.PlayerInventoryService:LoadInventory(player, playerData.inventory)
		else
			self._logger.Info("No saved inventory found, using starter items for", player.Name)
			-- Starter items were already given by OnPlayerAdded
		end
	else
		self._logger.Error("❌ PlayerInventoryService NOT AVAILABLE! Cannot create inventory!")
	end

	-- Load equipped armor data
	if self.Deps and self.Deps.ArmorEquipService then
		self._logger.Debug("Initializing armor for", player.Name)
		-- Initialize empty armor slots first
		self.Deps.ArmorEquipService:OnPlayerAdded(player)

		-- Load saved armor data if exists
		if playerData.equippedArmor then
			self._logger.Debug("Loading saved armor data for", player.Name)
			self.Deps.ArmorEquipService:LoadArmor(player, playerData.equippedArmor)
		else
			self._logger.Info("No saved armor found for", player.Name)
			-- Sync empty state to client
			task.defer(function()
				self.Deps.ArmorEquipService:SyncArmorToClient(player)
			end)
		end
	else
		self._logger.Warn("ArmorEquipService not available, cannot load armor")
	end

	-- Wait a moment for everything to load, then notify other services
	task.spawn(function()
		task.wait(1)

		-- Send initial data to client
		if self._eventManager then
			self:SendPlayerData(player)
		end
	end)
end

--[[
	Handle player leaving
--]]
function PlayerService:OnPlayerRemoving(player)
	self._logger.Debug("Player leaving", {playerName = player.Name})

	-- Save player data (including armor)
	self:SavePlayerData(player)

	-- Clean up ArmorEquipService data
	if self.Deps.ArmorEquipService then
		self.Deps.ArmorEquipService:OnPlayerRemoving(player)
	end

	-- Save to DataStore
	if self.Deps.PlayerDataStoreService then
		self.Deps.PlayerDataStoreService:OnPlayerRemoving(player)
	end

	-- Note: MobService cleanup removed - MobService is not implemented yet

	-- Cleanup player data
	self._playerData[player.UserId] = nil

	-- Cleanup player connections
	if self._connections[player.UserId] then
		for _, connection in pairs(self._connections[player.UserId]) do
			connection:Disconnect()
		end
		self._connections[player.UserId] = nil
	end
end

--[[
	Handle client ready event
--]]
function PlayerService:OnClientReady(player)
	self._logger.Debug("Client ready", {playerName = player.Name})

	-- Send complete player data
	self:SendPlayerData(player)

	-- Note: Dungeon initialization will happen automatically when grid is first requested
	-- This ensures all dependencies are properly loaded

	-- Send world/grid data if WorldService is available
	if self.Deps.WorldService then
		self.Deps.WorldService:SendGridData(player)
	end

	-- Send shop data
	self:SendShopData(player)

	-- Send daily rewards data
	self:SendDailyRewardsData(player)
end



--[[
	Send player data to client
--]]
function PlayerService:SendPlayerData(player)
	local data = self._playerData[player.UserId]
	if not data then
		self._logger.Warn("No data found for player", {playerName = player.Name})
		return
	end

	if not self._eventManager then
		self._logger.Error("EventManager not available")
		return
	end

	-- Send player data
	self._eventManager:FireEvent("PlayerDataUpdated", player, {
		level = data.level,
		experience = data.experience,
		statistics = data.statistics,
		dailyRewards = data.dailyRewards
	})

	-- Send currency data
	self._eventManager:FireEvent("CurrencyUpdated", player, {
		coins = data.coins,
		gems = data.gems
	})

	-- Send inventory data
	self._eventManager:FireEvent("InventoryUpdated", player, data.inventory)

	-- Send spawner inventory data if DungeonService is available
	if self.Deps.DungeonService then
		self.Deps.DungeonService:SendSpawnerInventory(player)
	end

	self._logger.Debug("Sent player data", {playerName = player.Name})
end

--[[
	Send shop data to client
--]]
function PlayerService:SendShopData(player)
	local shopData = {
		items = {
			{
				id = "basic_crate",
				name = "Basic Crate",
				price = 100,
				currency = "coins",
				description = "Contains basic spawners and resources",
				category = "crates"
			},
			{
				id = "enhanced_crate",
				name = "Enhanced Crate",
				price = 300,
				currency = "coins",
				description = "Contains enhanced spawners and resources",
				category = "crates"
			},
			{
				id = "premium_crate",
				name = "Premium Crate",
				price = 50,
				currency = "gems",
				description = "Contains rare spawners and resources",
				category = "crates"
			}
		},
		categories = {"crates", "upgrades", "resources"},
		featured = {"premium_crate"}
	}

	if self._eventManager then
		self._eventManager:FireEvent("ShopDataUpdated", player, shopData)
	end
end

--[[
	Send daily rewards data to client
--]]
function PlayerService:SendDailyRewardsData(player)
	-- Use RewardService to get proper daily rewards data
	if self.Deps.RewardService then
		self.Deps.RewardService:SendDailyRewardData(player)
	else
		self._logger.Warn("RewardService not available for daily rewards data")
	end
end

--[[
	Update player settings
--]]
function PlayerService:UpdateSettings(player, settings)
	local data = self._playerData[player.UserId]
	if not data then
		self._logger.Warn("No data found for settings update", {playerName = player.Name})
		return
	end

	-- Update settings
	for key, value in pairs(settings) do
		data.settings[key] = value
	end

	self._logger.Info("Updated player settings", {playerName = player.Name})
end

--[[
	Save player data
--]]
function PlayerService:SavePlayerData(player)
	local data = self._playerData[player.UserId]
	if not data then
		return
	end

	-- Update last save time
	data.lastSave = os.time()

	-- Save to PlayerDataStoreService
	if self.Deps.PlayerDataStoreService then
		-- Sync inventory data first
		if self.Deps.PlayerInventoryService then
			local inventoryData = self.Deps.PlayerInventoryService:SerializeInventory(player)
			if inventoryData then
				self.Deps.PlayerDataStoreService:SaveInventoryData(player, inventoryData)
			end
		end

		-- Sync armor data
		if self.Deps.ArmorEquipService then
			local armorData = self.Deps.ArmorEquipService:SerializeArmor(player)
			if armorData then
				self.Deps.PlayerDataStoreService:SaveArmorData(player, armorData)
				self._logger.Debug("Saved armor data", {
					playerName = player.Name,
					helmet = armorData.helmet,
					chestplate = armorData.chestplate,
					leggings = armorData.leggings,
					boots = armorData.boots
				})
			end
		end

		-- Update profile data in DataStore
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"profile", "level"}, data.level)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"profile", "experience"}, data.experience)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"profile", "coins"}, data.coins)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"profile", "gems"}, data.gems)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"statistics"}, data.statistics)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"dungeonData"}, data.dungeonData)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"dailyRewards"}, data.dailyRewards)
		self.Deps.PlayerDataStoreService:UpdatePlayerData(player, {"settings"}, data.settings)

		-- Actually save to DataStore
		self.Deps.PlayerDataStoreService:SavePlayerData(player)
	end

	self._logger.Debug("Saved player data", {playerName = player.Name})
end

--[[
	Get player data
--]]
function PlayerService:GetPlayerData(player)
	return self._playerData[player.UserId]
end



--[[
	Update player inventory
	@param player: Player - The player
	@param inventory: table - New inventory data
--]]
function PlayerService:UpdateInventory(player, inventory)
	local data = self._playerData[player.UserId]
	if not data then
		self._logger.Warn("No data found for inventory update", {
			playerName = player.Name
		})
		return false
	end

	data.inventory = inventory

	self._logger.Debug("Updated player inventory", {
		playerName = player.Name
	})

	return true
end

--[[
	Update player dungeon data
	@param player: Player - The player
	@param dungeonData: table - New dungeon data
--]]
function PlayerService:UpdateDungeonData(player, dungeonData)
	local data = self._playerData[player.UserId]
	if not data then
		self._logger.Warn("No data found for dungeon data update", {
			playerName = player.Name
		})
		return false
	end

	data.dungeonData = dungeonData

	self._logger.Debug("Updated player dungeon data", {
		playerName = player.Name
	})

	return true
end

--[[
	Add currency to player
--]]
function PlayerService:AddCurrency(player, currencyType, amount)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	if currencyType == "coins" then
		data.coins = data.coins + amount
		data.statistics.coinsEarned = data.statistics.coinsEarned + amount
	elseif currencyType == "gems" then
		data.gems = data.gems + amount
	else
		return false
	end

	-- Update client
	self:SendPlayerData(player)

	self._logger.Info("Added currency", {
		playerName = player.Name,
		currencyType = currencyType,
		amount = amount
	})

	return true
end

--[[
	Add experience to player
	@param player: Player - The target player
	@param amount: number - Amount of experience to add
	@return: boolean - Success
--]]
function PlayerService:AddExperience(player, amount)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	-- Add experience
	data.experience = data.experience + amount
	data.statistics.totalExperienceEarned = (data.statistics.totalExperienceEarned or 0) + amount

	-- Check for level up
	local oldLevel = data.level
	local newLevel = self:_calculateLevel(data.experience)

	if newLevel > oldLevel then
		data.level = newLevel
		data.statistics.highestLevel = math.max(data.statistics.highestLevel or 1, newLevel)

		-- Send level up event
		if self._eventManager then
			self._eventManager:FireEvent("PlayerLevelUp", player, {
				oldLevel = oldLevel,
				newLevel = newLevel,
				experienceGained = amount
			})
		end

		self._logger.Info("Player leveled up", {
			playerName = player.Name,
			oldLevel = oldLevel,
			newLevel = newLevel,
			experienceGained = amount
		})
	end

	-- Update client
	self:SendPlayerData(player)

	self._logger.Info("Added experience", {
		playerName = player.Name,
		amount = amount,
		newLevel = data.level
	})

	return true
end

--[[
	Calculate level based on total experience
	@param totalExperience: number - Total experience points
	@return: number - Calculated level
--]]
function PlayerService:_calculateLevel(totalExperience)
	-- Use Config level-up formula if available, otherwise use simple formula
	local baseXP = Config.STATS and Config.STATS.levelUp and Config.STATS.levelUp.baseXP or 100
	local multiplier = Config.STATS and Config.STATS.levelUp and Config.STATS.levelUp.multiplier or 1.5
	local maxLevel = Config.STATS and Config.STATS.levelUp and Config.STATS.levelUp.maxLevel or 100

	if totalExperience <= 0 then
		return 1
	end

	-- Calculate level using the same formula as GameState:GetLevelProgress()
	local level = 1
	local expUsed = 0
	local requiredXP = baseXP

	while level < maxLevel do
		if totalExperience < expUsed + requiredXP then
			break
		end
		expUsed = expUsed + requiredXP
		level = level + 1
		requiredXP = math.floor(requiredXP * multiplier)
	end

	return level
end

--[[
	Remove currency from player
--]]
function PlayerService:RemoveCurrency(player, currencyType, amount)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	local currentAmount = 0
	if currencyType == "coins" then
		currentAmount = data.coins
	elseif currencyType == "gems" then
		currentAmount = data.gems
	else
		return false
	end

	if currentAmount < amount then
		return false
	end

	if currencyType == "coins" then
		data.coins = data.coins - amount
	elseif currencyType == "gems" then
		data.gems = data.gems - amount
	end

	-- Update client
	self:SendPlayerData(player)

	self._logger.Info("Removed currency", {
		playerName = player.Name,
		currencyType = currencyType,
		amount = amount
	})

	return true
end

--[[
	Add item to player inventory
--]]
function PlayerService:AddItem(player, itemId, quantity)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	quantity = quantity or 1
	data.inventory[itemId] = (data.inventory[itemId] or 0) + quantity
	data.statistics.itemsCollected = data.statistics.itemsCollected + quantity

	-- Update client
	self:SendPlayerData(player)

	self._logger.Info("Added item to inventory", {
		playerName = player.Name,
		itemId = itemId,
		quantity = quantity
	})

	return true
end

--[[
	Remove item from player inventory
--]]
function PlayerService:RemoveItem(player, itemId, quantity)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	quantity = quantity or 1
	local currentQuantity = data.inventory[itemId] or 0

	if currentQuantity < quantity then
		return false -- Not enough items
	end

	data.inventory[itemId] = currentQuantity - quantity
	if data.inventory[itemId] <= 0 then
		data.inventory[itemId] = nil
	end

	-- Update client
	self:SendPlayerData(player)

	self._logger.Info("Removed item from inventory", {
		playerName = player.Name,
		itemId = itemId,
		quantity = quantity
	})

	return true
end

--[[
	Check if player has item in inventory
--]]
function PlayerService:HasItem(player, itemId, quantity)
	local data = self._playerData[player.UserId]
	if not data then
		return false
	end

	quantity = quantity or 1
	local currentQuantity = data.inventory[itemId] or 0
	return currentQuantity >= quantity
end

--[[
	Give starter items to new players
--]]
function PlayerService:GiveStarterItems(player)
	local gameConfig = require(game.ReplicatedStorage.Configs.GameConfig)
	local starterItems = gameConfig.Progression and gameConfig.Progression.StarterItems

	if not starterItems then
		return
	end

	for _, itemId in ipairs(starterItems) do
		self:AddItem(player, itemId, 1)
	end

	self._logger.Info("Gave starter items to player", {
		playerName = player.Name,
		items = starterItems
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HUNGER & SATURATION SYSTEM (Minecraft-style)
-- ═══════════════════════════════════════════════════════════════════════════

--[[
	Get player's current hunger level
	@param player: Player - The player
	@return: number - Hunger value (0-20)
]]
function PlayerService:GetHunger(player)
	local data = self._playerData[player.UserId]
	if not data then
		return 20 -- Default to full hunger
	end
	return data.hunger or 20
end

--[[
	Set player's hunger level
	@param player: Player - The player
	@param hunger: number - New hunger value (clamped to 0-20)
]]
function PlayerService:SetHunger(player, hunger)
	local data = self._playerData[player.UserId]
	if not data then
		return
	end
	data.hunger = math.clamp(hunger, 0, 20)
end

--[[
	Get player's current saturation level
	@param player: Player - The player
	@return: number - Saturation value (0-20)
]]
function PlayerService:GetSaturation(player)
	local data = self._playerData[player.UserId]
	if not data then
		return 20 -- Default to full saturation
	end
	return data.saturation or 20
end

--[[
	Set player's saturation level
	@param player: Player - The player
	@param saturation: number - New saturation value (clamped to 0-20)
]]
function PlayerService:SetSaturation(player, saturation)
	local data = self._playerData[player.UserId]
	if not data then
		return
	end
	data.saturation = math.clamp(saturation, 0, 20)
end

return PlayerService