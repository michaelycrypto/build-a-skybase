--[[
	FoodService.lua
	Handles food consumption logic, validation, and item removal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local FoodConfig = require(ReplicatedStorage.Shared.FoodConfig)

local FoodService = setmetatable({}, BaseService)
FoodService.__index = FoodService

function FoodService.new()
	local self = setmetatable(BaseService.new(), FoodService)

	self._logger = Logger:CreateContext("FoodService")
	self._eatingPlayers = {} -- {[player] = {foodId, startTime, slotIndex}}
	self._eatingCooldowns = {} -- {[player] = cooldownEndTime}

	return self
end

function FoodService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Info("FoodService initialized")
end

function FoodService:Start()
	if self._started then
		return
	end

	-- Register event handlers
	if EventManager then
		EventManager:RegisterEventHandler("RequestStartEating", function(player, data)
			self:HandleStartEating(player, data)
		end)

		EventManager:RegisterEventHandler("RequestCompleteEating", function(player, data)
			self:HandleCompleteEating(player, data)
		end)

		EventManager:RegisterEventHandler("RequestCancelEating", function(player, data)
			self:HandleCancelEating(player, data)
		end)
	end

	-- Clean up on player leave
	Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	BaseService.Start(self)
	self._logger.Info("FoodService started")
end

function FoodService:Destroy()
	if self._destroyed then
		return
	end

	self._eatingPlayers = {}
	self._eatingCooldowns = {}

	BaseService.Destroy(self)
	self._logger.Info("FoodService destroyed")
end

--[[
	Handle player leaving
--]]
function FoodService:OnPlayerRemoving(player)
	self._eatingPlayers[player] = nil
	self._eatingCooldowns[player] = nil
end

--[[
	Handle start eating request from client
	@param player: Player
	@param data: {foodId: number, slotIndex: number?}
--]]
function FoodService:HandleStartEating(player, data)
	if not data or not data.foodId then
		self._logger.Warn("Invalid start eating request", {player = player.Name})
		return
	end

	local foodId = data.foodId
	local slotIndex = data.slotIndex

	-- Check if food item is valid
	if not FoodConfig.IsFood(foodId) then
		self._logger.Warn("Invalid food item", {player = player.Name, foodId = foodId})
		EventManager:FireEvent("EatingStarted", player, {error = "Invalid food item"})
		return
	end

	-- Check if player is already eating
	if self._eatingPlayers[player] then
		self._logger.Debug("Player already eating", {player = player.Name})
		EventManager:FireEvent("EatingStarted", player, {error = "Already eating"})
		return
	end

	-- Check cooldown
	local cooldownEnd = self._eatingCooldowns[player]
	if cooldownEnd and os.clock() < cooldownEnd then
		self._logger.Debug("Player on eating cooldown", {player = player.Name})
		EventManager:FireEvent("EatingStarted", player, {error = "On cooldown"})
		return
	end

	-- Check if player has food item
	if not self.Deps.PlayerInventoryService then
		self._logger.Error("PlayerInventoryService not available")
		EventManager:FireEvent("EatingStarted", player, {error = "Service unavailable"})
		return
	end

	-- Check if player has the food item
	local hasItem = false
	if slotIndex and slotIndex >= 1 and slotIndex <= 9 then
		-- Check specific hotbar slot
		local playerInv = self.Deps.PlayerInventoryService.inventories[player]
		if playerInv and playerInv.hotbar[slotIndex] then
			local stack = playerInv.hotbar[slotIndex]
			if stack:GetItemId() == foodId and stack:GetCount() > 0 then
				hasItem = true
			end
		end
	else
		-- Check if player has item anywhere in inventory
		hasItem = self.Deps.PlayerInventoryService:HasItem(player, foodId, 1)
	end

	if not hasItem then
		self._logger.Debug("Player does not have food item", {player = player.Name, foodId = foodId})
		EventManager:FireEvent("EatingStarted", player, {error = "No food item"})
		return
	end

	-- Check if hunger is full
	if not self.Deps.PlayerService then
		self._logger.Error("PlayerService not available")
		EventManager:FireEvent("EatingStarted", player, {error = "Service unavailable"})
		return
	end

	local hunger = self.Deps.PlayerService:GetHunger(player)
	if hunger >= 20 then
		self._logger.Debug("Player hunger is full", {player = player.Name, hunger = hunger})
		EventManager:FireEvent("EatingStarted", player, {error = "Hunger is full"})
		return
	end

	-- Start eating
	self._eatingPlayers[player] = {
		foodId = foodId,
		startTime = os.clock(),
		slotIndex = slotIndex
	}

	-- Notify client
	EventManager:FireEvent("EatingStarted", player, {
		foodId = foodId,
		duration = FoodConfig.Eating.duration
	})

	self._logger.Debug("Started eating", {
		player = player.Name,
		foodId = foodId,
		slotIndex = slotIndex
	})
end

--[[
	Handle complete eating request from client
	@param player: Player
	@param data: {foodId: number}
--]]
function FoodService:HandleCompleteEating(player, data)
	if not data or not data.foodId then
		self._logger.Warn("Invalid complete eating request", {player = player.Name})
		return
	end

	local eatingData = self._eatingPlayers[player]
	if not eatingData then
		self._logger.Debug("Player not eating", {player = player.Name})
		return
	end

	local foodId = data.foodId
	if eatingData.foodId ~= foodId then
		self._logger.Warn("Food ID mismatch", {
			player = player.Name,
			expected = eatingData.foodId,
			received = foodId
		})
		return
	end

	-- Check if enough time has passed
	local elapsed = os.clock() - eatingData.startTime
	if elapsed < FoodConfig.Eating.duration then
		self._logger.Warn("Eating completed too early", {
			player = player.Name,
			elapsed = elapsed,
			required = FoodConfig.Eating.duration
		})
		-- Still allow it, but log warning
	end

	-- Get food config
	local foodConfig = FoodConfig.GetFoodConfig(foodId)
	if not foodConfig then
		self._logger.Error("Food config not found", {player = player.Name, foodId = foodId})
		self._eatingPlayers[player] = nil
		return
	end

	-- Consume food item
	local consumed = false
	if eatingData.slotIndex and eatingData.slotIndex >= 1 and eatingData.slotIndex <= 9 then
		-- Remove from specific hotbar slot
		consumed = self.Deps.PlayerInventoryService:RemoveItemFromHotbarSlot(player, eatingData.slotIndex, 1)
	else
		-- Remove from anywhere in inventory
		consumed = self.Deps.PlayerInventoryService:RemoveItem(player, foodId, 1)
	end

	if not consumed then
		self._logger.Warn("Failed to consume food item", {player = player.Name, foodId = foodId})
		EventManager:FireEvent("EatingCompleted", player, {error = "Failed to consume food"})
		self._eatingPlayers[player] = nil
		return
	end

	-- Apply hunger and saturation restoration
	local currentHunger = self.Deps.PlayerService:GetHunger(player)
	local currentSaturation = self.Deps.PlayerService:GetSaturation(player)

	local newHunger = math.min(20, currentHunger + foodConfig.hunger)
	local newSaturation = math.min(20, currentSaturation + foodConfig.saturation)

	self.Deps.PlayerService:SetHunger(player, newHunger)
	self.Deps.PlayerService:SetSaturation(player, newSaturation)

	-- Sync hunger to client
	if self.Deps.HungerService then
		self.Deps.HungerService:SyncHungerToClient(player)
	end

	-- Apply special effects (if any)
	local effects = {}
	if foodConfig.effects and #foodConfig.effects > 0 then
		-- TODO: Apply status effects when StatusEffectService is implemented
		effects = foodConfig.effects
	end

	-- Set cooldown
	self._eatingCooldowns[player] = os.clock() + FoodConfig.Eating.cooldown

	-- Clear eating state
	self._eatingPlayers[player] = nil

	-- Notify client
	EventManager:FireEvent("EatingCompleted", player, {
		hunger = newHunger,
		saturation = newSaturation,
		effects = effects
	})

	self._logger.Info("Completed eating", {
		player = player.Name,
		foodId = foodId,
		hunger = newHunger,
		saturation = newSaturation
	})
end

--[[
	Handle cancel eating request from client
	@param player: Player
	@param data: {}
--]]
function FoodService:HandleCancelEating(player, data)
	local eatingData = self._eatingPlayers[player]
	if not eatingData then
		return -- Not eating, nothing to cancel
	end

	-- Clear eating state
	self._eatingPlayers[player] = nil

	-- Notify client
	EventManager:FireEvent("EatingCancelled", player, {})

	self._logger.Debug("Cancelled eating", {player = player.Name})
end

--[[
	Check if player is currently eating
--]]
function FoodService:IsPlayerEating(player)
	return self._eatingPlayers[player] ~= nil
end

--[[
	Get eating data for player
--]]
function FoodService:GetEatingData(player)
	return self._eatingPlayers[player]
end

return FoodService
