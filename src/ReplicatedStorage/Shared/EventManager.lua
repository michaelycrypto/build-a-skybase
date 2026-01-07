--[[
	EventManager - Client-Server Event Management

	Manages registration and handling of client-server events.
	Provides a centralized system for event management with managers integration.
--]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Logger = require(game:GetService("ReplicatedStorage").Shared.Logger)

local HIT_CONFIRM_SOUNDS = {"hitConfirm1", "hitConfirm2", "hitConfirm3"}

local function playRandomHitSound(managers)
	if not (managers and managers.SoundManager and managers.SoundManager.PlaySFX) then
		return
	end
	if #HIT_CONFIRM_SOUNDS == 0 then
		return
	end
	local index = math.random(1, #HIT_CONFIRM_SOUNDS)
	managers.SoundManager:PlaySFX(HIT_CONFIRM_SOUNDS[index])
end

local EventManager = {}
EventManager.__index = EventManager

-- Global instance
local _instance = nil

function EventManager.new()
	local self = setmetatable({}, EventManager)

	self._network = nil
	self._events = {}
	self._handlers = {}
	self._isInitialized = false

	-- Logging
	self._logger = Logger:CreateContext("EventManager")

	return self
end

function EventManager.GetInstance()
	if not _instance then
		_instance = EventManager.new()
	end
	return _instance
end

--[[
	Initialize the EventManager with Network instance
--]]
function EventManager:Initialize(network)
	assert(network, "Network instance is required")
	self._network = network
	self._isInitialized = true
	-- EventManager initialized
end

--[[
	Create client event configuration with managers
--]]
function EventManager:CreateClientEventConfig(managers)
	assert(type(managers) == "table", "Managers must be a table")

	local config = {
		-- World join error feedback (server -> client)
		{
			name = "WorldJoinError",
			handler = function(errorData)
				if managers.ToastManager then
					managers.ToastManager:Error(
						(errorData and errorData.message) or "Teleport failed.",
						4
					)
				end
			end
		},

		-- Combat feedback events
			{
				name = "PlayerDamaged",
				handler = function(data)
					local localPlayer = Players.LocalPlayer
					if not (localPlayer and data and data.attackerUserId == localPlayer.UserId) then
						return
					end
					playRandomHitSound(managers)
				end
			},
			{
				name = "MobDamaged",
				handler = function(data)
					if not data then return end
					-- Play swing animation for the attacker (visible to all players)
					if data.attackerUserId and managers.ToolAnimationController and managers.ToolAnimationController.PlaySwingForUserId then
						managers.ToolAnimationController:PlaySwingForUserId(data.attackerUserId)
					end
					-- Play hit sound only for local player who attacked
					local localPlayer = Players.LocalPlayer
					if localPlayer and data.attackerUserId == localPlayer.UserId then
						playRandomHitSound(managers)
					end
				end
			},
		{
			name = "PlayerSwordSwing",
			handler = function(data)
				-- Play swing animation for remote players only (local player already plays via direct input)
				local localPlayer = Players.LocalPlayer
				if data and data.userId and localPlayer and data.userId ~= localPlayer.UserId then
					if managers.ToolAnimationController and managers.ToolAnimationController.PlaySwingForUserId then
						managers.ToolAnimationController:PlaySwingForUserId(data.userId)
					end
				end
			end
		},
		-- Player data events
		{
			name = "PlayerDataUpdated",
			handler = function(data)
				if managers.GameState and managers.GameState.UpdatePlayerData then
					managers.GameState:UpdatePlayerData(data)
				end
			end
		},

		-- Currency events
		{
			name = "CurrencyUpdated",
			handler = function(currencies)
				if managers.GameState and managers.GameState.UpdateCurrencies then
					managers.GameState:UpdateCurrencies(currencies)
				end
			end
		},

		-- Inventory events
		{
			name = "InventoryUpdated",
			handler = function(inventory)
				if managers.GameState then
					managers.GameState:Set("playerData.inventory", inventory)
				end
			end
		},

		-- Notification events
		{
			name = "ShowNotification",
			handler = function(notificationData)
				if managers.ToastManager then
					-- Call the appropriate ToastManager method based on notification type
					local message = notificationData.message
					local notificationType = notificationData.type or "info"
					local duration = notificationData.duration

					if notificationType == "success" then
						managers.ToastManager:Success(message, duration)
					elseif notificationType == "error" then
						managers.ToastManager:Error(message, duration)
					elseif notificationType == "warning" then
						managers.ToastManager:Warning(message, duration)
					elseif notificationType == "reward" then
						managers.ToastManager:Success(message, duration)
					elseif notificationType == "experience" then
						-- Extract amount from message for experience notifications
						local amount = tonumber(string.match(message, "+(%d+)") or "0")
						managers.ToastManager:ExperienceEarned(amount)
					else
						-- Default to info
						managers.ToastManager:Info(message, duration)
					end
				end
			end
		},

		-- Sound events
		{
			name = "PlaySound",
			handler = function(soundData)
				if managers.SoundManager and managers.SoundManager.PlaySound then
					managers.SoundManager:PlaySound(
						soundData.soundId,
						soundData.volume,
						soundData.pitch,
						soundData.category
					)
				end
			end
		},

		-- Daily rewards events
		{
			name = "DailyRewardUpdated",
			handler = function(rewardData)
				if managers.DailyRewardsPanel and managers.DailyRewardsPanel.UpdateRewards then
					managers.DailyRewardsPanel:UpdateRewards(rewardData)
				end
			end
		},
		{
			name = "DailyRewardClaimed",
			handler = function(rewardData)
				-- This is handled by individual panels via their own event registration
				-- Just acknowledge the event here to avoid warnings
			end
		},
		{
			name = "DailyRewardDataUpdated",
			handler = function(rewardData)
				-- This is handled by individual panels via their own event registration
				-- Just acknowledge the event here to avoid warnings
			end
		},
		{
			name = "DailyRewardError",
			handler = function(errorData)
				-- This is handled by individual panels via their own event registration
				-- Just acknowledge the event here to avoid warnings
			end
		},

		-- Shop events
		{
			name = "ShopDataUpdated",
			handler = function(shopData)
				if managers.ShopPanel and managers.ShopPanel.UpdateShopData then
					managers.ShopPanel:UpdateShopData(shopData)
				end
			end
		},

		-- Grid/Spawner events removed

		-- Emote events
		{
			name = "ShowEmote",
			handler = function(targetPlayer, emoteName)
				if managers.EmoteManager and managers.EmoteManager.ShowEmoteBillboard then
					managers.EmoteManager:ShowEmoteBillboard(targetPlayer, emoteName)
				end
			end
		},
		{
			name = "RemoveEmote",
			handler = function(targetPlayer)
				if managers.EmoteManager and managers.EmoteManager.RemoveEmoteBillboard then
					managers.EmoteManager:RemoveEmoteBillboard(targetPlayer)
				end
			end
		},

		-- Stats events
		{
			name = "StatsUpdated",
			handler = function(statsData)
				if managers.GameState and managers.GameState.UpdateStats then
					managers.GameState:UpdateStats(statsData)
				end
			end
		},

		-- Level up events
		{
			name = "PlayerLevelUp",
			handler = function(levelData)
				if managers.ToastManager then
					managers.ToastManager:Success(
						"Level Up! You are now level " .. levelData.newLevel,
						5
					)
				end
				if managers.SoundManager and managers.SoundManager.PlaySFX then
					managers.SoundManager:PlaySFX("levelUp", 1.0, 0.7)
				end
			end
		},

		-- Achievement events
		{
			name = "AchievementUnlocked",
			handler = function(achievementData)
				if managers.ToastManager then
					managers.ToastManager:Achievement(
						"Achievement Unlocked: " .. achievementData.name,
						nil,
						"Trophy"
					)
				end
			end
		},

		-- Error events
		{
			name = "ShowError",
			handler = function(errorData)
				if managers.ToastManager then
					managers.ToastManager:Error(
						errorData.message or "An error occurred",
						errorData.duration or 4
					)
				end
			end
		},

		-- Mob-related events removed

		-- Server shutdown events
		{
			name = "ServerShutdown",
			handler = function(shutdownData)
				if managers.ToastManager then
					managers.ToastManager:Warning(
						"Server shutting down in " .. shutdownData.seconds .. " seconds",
						10
					)
				end
			end
		},

		-- Combat/Animation events
		{
			name = "PlayerPunched",
			handler = function(data)
				-- Trigger punch animation for remote players only (local player already plays via direct input)
				local localPlayer = Players.LocalPlayer
				local userId = data and data.userId
				if userId and localPlayer and userId ~= localPlayer.UserId then
					if managers.ToolAnimationController and managers.ToolAnimationController.PlaySwingForUserId then
						managers.ToolAnimationController:PlaySwingForUserId(userId)
					end
				end
			end
		}
	}

	return config
end

--[[
	Event definitions with parameter signatures
--]]
local Manifest = require(game:GetService("ReplicatedStorage").Shared.Events.EventManifest)
local VoxelNetworkEvents = require(game:GetService("ReplicatedStorage").Shared.Events.VoxelNetworkEvents)

local EVENT_DEFINITIONS = {
    -- Client-to-server events (no parameters)
	ClientReady = {},
	RequestDataRefresh = {},
    -- Grid/spawner requests removed
	RequestDailyRewardData = {},
	ClaimDailyReward = {},
	GetShopStock = {},
	-- Quests (client to server)
	RequestQuestData = {},
	ClaimQuestReward = {"any"}, -- {mobType:string, milestone:number}

    -- Client-to-server events (with parameters)
	PurchaseItem = {"any", "any"}, -- itemId, quantity
	RequestBonusCoins = {"any", "any"}, -- source, amount
	UpdateSettings = {"any"}, -- settings
    -- Dungeon request removed
	PlayEmote = {"any"}, -- emoteName
	-- Crafting events
	CraftRecipe = {"any"}, -- {recipeId:string, toCursor:boolean}
	CraftRecipeBatch = {"any"}, -- {recipeId:string, count:number, toCursor:boolean}
	CraftRecipeBatchResult = {"any"}, -- server->client: {recipeId:string, acceptedCount:number, toCursor:boolean, outputItemId:number, outputPerCraft:number}
    -- Spawner/mob/tooling events removed
    AttackMob = {"any"}, -- {entityId:string, damage:number}
	-- Ranged combat
	BowShoot = {"any"}, -- {origin:Vector3, direction:Vector3, charge:number, slotIndex:number?}

	-- Server-to-client events (with parameters)
	PlayerDataUpdated = {"any"}, -- playerData
	CurrencyUpdated = {"any"}, -- currencies
	InventoryUpdated = {"any"}, -- inventory
	WorldStateChanged = {"any"}, -- world/session readiness payload
	CraftRecipeBatchResult = {"any"}, -- {recipeId:string, acceptedCount:number, toCursor:boolean, outputItemId:number, outputPerCraft:number}
	ShowNotification = {"any"}, -- notificationData
	ShowError = {"any"}, -- errorData
	PlaySound = {"any"}, -- soundData
	DailyRewardUpdated = {"any"}, -- rewardData
	DailyRewardClaimed = {"any"}, -- rewardData
	DailyRewardDataUpdated = {"any"}, -- rewardData
	DailyRewardError = {"any"}, -- errorData
	ShopDataUpdated = {"any"}, -- shopData
	ShopStockUpdated = {"any"}, -- stockData
    -- Grid/spawner/mob events removed
    MobSpawned = {"any"}, -- {entityId:string, mobType:string, ...}
    MobBatchUpdate = {"any"}, -- {mobs:table}
    MobDespawned = {"any"}, -- {entityId:string}
    MobDamaged = {"any"}, -- {entityId:string, health:number, maxHealth:number, attackerUserId:number?}
    MobDied = {"any"}, -- {entityId:string}
	ShowEmote = {"any", "any"}, -- targetPlayer, emoteName
	RemoveEmote = {"any"}, -- targetPlayer
	StatsUpdated = {"any"}, -- statsData
	PlayerLevelUp = {"any"}, -- levelData
	AchievementUnlocked = {"any"}, -- achievementData
	MobRewardReceived = {"any"}, -- rewardData
    -- Quest events (server to client)
    QuestDataUpdated = {"any"},
    QuestProgressUpdated = {"any"},
    QuestRewardClaimed = {"any"},
    QuestError = {"any"},
	ServerShutdown = {"any"} -- shutdownData
}

-- Merge Manifest into EVENT_DEFINITIONS to ensure single source of truth
for eventName, types in pairs(Manifest.ClientToServer) do
	EVENT_DEFINITIONS[eventName] = types
end
for eventName, types in pairs(Manifest.ServerToClient) do
	EVENT_DEFINITIONS[eventName] = types
end

-- Merge Voxel Network Events
for eventName, types in pairs(VoxelNetworkEvents.AllEvents) do
	EVENT_DEFINITIONS[eventName] = types
end

--[[
	Register all events (replaces separate client/server registration)
--]]
function EventManager:RegisterAllEvents()
	assert(self._isInitialized, "EventManager must be initialized before registering events")

	local eventCount = 0
	for eventName, paramTypes in pairs(EVENT_DEFINITIONS) do
		if not self._events[eventName] then
			-- Define the event with Network using correct parameter signature
			self._events[eventName] = self._network:DefineEvent(eventName, paramTypes)
			eventCount = eventCount + 1
		end
	end

	-- Events registered with parameter signatures
end

--[[
	Register events from configuration (for handlers)
--]]
function EventManager:RegisterEvents(eventConfig)
	assert(self._isInitialized, "EventManager must be initialized before registering events")
	assert(type(eventConfig) == "table", "Event configuration must be a table")

	for _, event in pairs(eventConfig) do
		if event.name and event.handler then
			self:RegisterEventHandler(event.name, event.handler)
		end
	end

	-- Event handlers registered
end

--[[
	Register a single event handler (doesn't redefine the event)

	IMPORTANT: This is the CORRECT method to use for event registration.
	DO NOT use RegisterServerEvent() or RegisterClientEvent() - they don't exist!

	Usage:
		EventManager:RegisterEventHandler("EventName", function(player, data)
			-- Handle event
		end)
--]]
function EventManager:RegisterEventHandler(eventName, handler)
	assert(type(eventName) == "string", "Event name must be a string")
	assert(type(handler) == "function", "Handler must be a function")

	-- Ensure the event is defined
	if not self._events[eventName] then
		local paramTypes = EVENT_DEFINITIONS[eventName]
		if paramTypes then
			self._events[eventName] = self._network:DefineEvent(eventName, paramTypes)
		else
			warn("EventManager: Unknown event", eventName, "- using fallback definition")
			self._events[eventName] = self._network:DefineEvent(eventName, {"any"})
		end
	end

	-- Store the handler
	self._handlers[eventName] = handler

	-- Connect the event
	if RunService:IsClient() then
		self._events[eventName]:Connect(function(...)
			local success, error = pcall(handler, ...)
			if not success then
				warn("EventManager: Error in handler for", eventName, ":", error)
			end
		end)
	else
		-- On server, we need to connect to handle incoming events from clients
		self._events[eventName]:Connect(function(player, ...)
			local success, error = pcall(handler, player, ...)
			if not success then
				warn("EventManager: Error in server handler for", eventName, ":", error)
			end
		end)
	end
end

--[[
	Register a single event (legacy compatibility)
--]]
function EventManager:RegisterEvent(eventName, handler)
	return self:RegisterEventHandler(eventName, handler)
end

--[[
	Fire an event (server-side)
--]]
function EventManager:FireEvent(eventName, player, ...)
	assert(RunService:IsServer(), "FireEvent can only be called from server")
	assert(type(eventName) == "string", "Event name must be a string")

	if self._events[eventName] then
		self._events[eventName]:Fire(player, ...)
	else
		warn("EventManager: Attempted to fire unregistered event:", eventName)
	end
end

--[[
	Fire an event to all clients (server-side)
--]]
function EventManager:FireEventToAll(eventName, ...)
	assert(RunService:IsServer(), "FireEventToAll can only be called from server")
	assert(type(eventName) == "string", "Event name must be a string")

	if self._events[eventName] then
		self._events[eventName]:FireAll(...)
	else
		warn("EventManager: Attempted to fire unregistered event:", eventName)
	end
end

--[[
	Send an event to server (client-side)
--]]
function EventManager:SendToServer(eventName, ...)
	assert(RunService:IsClient(), "SendToServer can only be called from client")
	assert(type(eventName) == "string", "Event name must be a string")

	if self._events[eventName] then
		self._events[eventName]:Fire(...)
	else
		warn("EventManager: Attempted to send unregistered event:", eventName)
	end
end

--[[
	Connect to a server event (client-side)
--]]
function EventManager:ConnectToServer(eventName, callback)
	assert(RunService:IsClient(), "ConnectToServer can only be called from client")
	assert(type(eventName) == "string", "Event name must be a string")
	assert(type(callback) == "function", "Callback must be a function")

	if self._events[eventName] then
		return self._events[eventName]:Connect(callback)
	else
		warn("EventManager: Attempted to connect to unregistered event:", eventName)
		return nil
	end
end

--[[
	Create server event configuration
--]]
function EventManager:CreateServerEventConfig(services)
	assert(type(services) == "table", "Services must be a table")

	-- Expose services to handlers that reference self._services
	self._services = services

	local config = {
		-- Cross-place lobby/world navigation
		{
			name = "RequestJoinWorld",
			handler = function(player, data)
				print("[EventManager] Server received RequestJoinWorld from", player and player.Name)
				if services.LobbyWorldTeleportService and services.LobbyWorldTeleportService.RequestJoinWorld then
					services.LobbyWorldTeleportService:RequestJoinWorld(player, data)
				end
			end
		},
		{
			name = "RequestCreateWorld",
			handler = function(player, data)
				print("[EventManager] Server received RequestCreateWorld from", player and player.Name)
				if services.LobbyWorldTeleportService and services.LobbyWorldTeleportService.RequestCreateWorld then
					services.LobbyWorldTeleportService:RequestCreateWorld(player, data)
				end
			end
		},
		{
			name = "ReturnToLobby",
			handler = function(player)
				if services.CrossPlaceTeleportService and services.CrossPlaceTeleportService.ReturnToLobby then
					services.CrossPlaceTeleportService:ReturnToLobby(player)
				end
			end
		},
		{
			name = "RequestTeleportToHub",
			handler = function(player)
				print("[EventManager] Server received RequestTeleportToHub from", player and player.Name)
				if services.CrossPlaceTeleportService and services.CrossPlaceTeleportService.TeleportToHub then
					services.CrossPlaceTeleportService:TeleportToHub(player)
				end
			end
		},
		-- World management (lobby)
		{
			name = "RequestWorldsList",
			handler = function(player, data)
				print("[EventManager] Server received RequestWorldsList from", player and player.Name)
				if services.WorldsListService and services.WorldsListService.SendWorldsList then
					services.WorldsListService:SendWorldsList(player, data)
				end
			end
		},
		{
			name = "DeleteWorld",
			handler = function(player, data)
				print("[EventManager] Server received DeleteWorld from", player and player.Name)
				if services.WorldsListService and services.WorldsListService.DeleteWorld then
					services.WorldsListService:DeleteWorld(player, data.worldId)
				end
			end
		},
		{
			name = "UpdateWorldMetadata",
			handler = function(player, data)
				print("[EventManager] Server received UpdateWorldMetadata from", player and player.Name)
				if services.WorldsListService and services.WorldsListService.UpdateWorldMetadata then
					services.WorldsListService:UpdateWorldMetadata(player, data.worldId, data.metadata)
				end
			end
		},
		-- Client ready event
		{
			name = "ClientReady",
			handler = function(player)
				self._logger.Debug("Client ready for player", player.Name)
				if services.PlayerService and services.PlayerService.OnClientReady then
					services.PlayerService:OnClientReady(player)
				end
				-- Spawn the player at land spawn once ready
				if services.SpawnService and services.SpawnService.OnClientReady then
					services.SpawnService:OnClientReady(player)
				end
			end
		},
		{
			name = "ClientLoadingComplete",
			handler = function(player)
				if services.VoxelWorldService and services.VoxelWorldService.OnClientLoadingComplete then
					services.VoxelWorldService:OnClientLoadingComplete(player)
				end
			end
		},

		-- Data refresh request
		{
			name = "RequestDataRefresh",
			handler = function(player)
				if services.PlayerService and services.PlayerService.SendPlayerData then
					services.PlayerService:SendPlayerData(player)
				end
			end
		},

		-- Quest data request
		{
			name = "RequestQuestData",
			handler = function(player)
				if services.QuestService and services.QuestService.SendQuestData then
					services.QuestService:SendQuestData(player)
				end
			end
		},

		-- Quest reward claim
		{
			name = "ClaimQuestReward",
			handler = function(player, claimData)
				if services.QuestService and services.QuestService.OnClaimQuestReward then
					services.QuestService:OnClaimQuestReward(player, claimData)
				end
			end
		},

		-- Grid data request
		-- RequestGridData removed with world system

		-- Dungeon grid data request (7x7 spawner grid)
		{
			name = "RequestDungeonGrid",
			handler = function(player)
				if services.DungeonService and services.DungeonService.SendGridData then
					services.DungeonService:SendGridData(player)
				end
			end
		},

		-- Spawner inventory request removed

		-- Shop purchase request
		{
			name = "PurchaseItem",
			handler = function(player, itemId, quantity)
				-- Validate player is a Player object
				if not player or not player:IsA("Player") then
					warn("EventManager: Invalid player in PurchaseItem handler", {
						player = player,
						playerType = type(player)
					})
					return
				end

				if services.ShopService and services.ShopService.ProcessPurchase then
					services.ShopService:ProcessPurchase(player, itemId, quantity)
				end
			end
		},

		-- Shop stock request
		{
			name = "GetShopStock",
			handler = function(player)
				-- Validate player is a Player object
				if not player or not player:IsA("Player") then
					warn("EventManager: Invalid player in GetShopStock handler", {
						player = player,
						playerType = type(player)
					})
					return
				end

				if services.ShopService and services.ShopService.SendStockData then
					services.ShopService:SendStockData(player)
				end
			end
		},

		-- Daily reward data request
		{
			name = "RequestDailyRewardData",
			handler = function(player)
				if services.RewardService and services.RewardService.SendDailyRewardData then
					services.RewardService:SendDailyRewardData(player)
				end
			end
		},

		-- Daily reward claim
		{
			name = "ClaimDailyReward",
			handler = function(player)
				if services.RewardService and services.RewardService.ClaimDailyReward then
					services.RewardService:ClaimDailyReward(player) -- Server calculates everything based on stored data
				end
			end
		},

		-- Bonus coins request (free coins button)
		{
			name = "RequestBonusCoins",
			handler = function(player, source, amount)
				if services.RewardService and services.RewardService.GrantBonusReward then
					services.RewardService:GrantBonusReward(player, "coins", amount or 100, source or "free_button")
				end
			end
		},

		-- Toolbar tool events
        -- Deprecated ToolActivated behaviors (Raise/Lower/DrawPath) removed

		-- TileClicked removed with world system

		-- Settings update
		{
			name = "UpdateSettings",
			handler = function(player, settings)
				if services.PlayerService and services.PlayerService.UpdateSettings then
					services.PlayerService:UpdateSettings(player, settings)
				end
			end
		},

		-- Dungeon events
		{
			name = "RequestSlotUnlock",
			handler = function(player, slotIndex)
				if services.DungeonService and services.DungeonService.PurchaseSlotUnlock then
					services.DungeonService:PurchaseSlotUnlock(player, slotIndex)
				end
			end
		},
		{
			name = "DepositMobHead",
			handler = function(player, slotIndex, mobHeadType)
				if services.DungeonService and services.DungeonService.DepositMobHead then
					services.DungeonService:DepositMobHead(player, slotIndex, mobHeadType)
				end
			end
		},
		{
			name = "RemoveMobHead",
			handler = function(player, slotIndex)
				if services.DungeonService and services.DungeonService.RemoveMobHead then
					services.DungeonService:RemoveMobHead(player, slotIndex)
				end
			end
		},
		-- Spawner tool events removed


		-- Emote events
		{
			name = "PlayEmote",
			handler = function(player, emoteName)
				if services.EmoteService and services.EmoteService.HandlePlayEmote then
					services.EmoteService:HandlePlayEmote(player, emoteName)
				end
			end
		},

		-- Toolbar events
		{
			name = "ToolbarModeChanged",
			handler = function(player, modeData)
				-- Log mode change for debugging
				print("Player", player.Name, "changed toolbar mode to:", modeData.mode)
			end
		},
		{
			name = "ToolActivated",
			handler = function(player, toolData)
				-- Log tool activation for debugging
				print("Player", player.Name, "activated tool:", toolData.tool, "in mode:", toolData.mode)

				-- Map client tool names to WorldService modes
				if services.WorldService then
					if toolData and (toolData.tool == "PlaceBlock" or toolData.tool == "Build") then
						-- If a blockType is provided, remember it server-side for this player
						if toolData.blockType and services.WorldService.SetSelectedBuildType then
							services.WorldService:SetSelectedBuildType(player, toolData.blockType)
						end
						if services.WorldService.StartTowerDeployment then
							services.WorldService:StartTowerDeployment(player)
						end
					elseif toolData and (toolData.tool == "RemoveBlock" or toolData.tool == "RemoveTower") then
						if services.WorldService.StartTowerRemoval then
							services.WorldService:StartTowerRemoval(player)
						end
					end
				end
			end
		},
		-- Voxel tool equip/unequip
		{
			name = "EquipTool",
			handler = function(player, data)
				if services.VoxelWorldService and services.VoxelWorldService.OnEquipTool then
					services.VoxelWorldService:OnEquipTool(player, data)
				end
			end
		},
		{
			name = "UnequipTool",
			handler = function(player)
				if services.VoxelWorldService and services.VoxelWorldService.OnUnequipTool then
					services.VoxelWorldService:OnUnequipTool(player)
				end
			end
		},
		{
			name = "RequestToolSync",
			handler = function(player)
				if services.VoxelWorldService and services.VoxelWorldService.OnRequestToolSync then
					services.VoxelWorldService:OnRequestToolSync(player)
				end
			end
		},
		{
			name = "SelectHotbarSlot",
			handler = function(player, data)
				if services.VoxelWorldService and services.VoxelWorldService.OnSelectHotbarSlot then
					services.VoxelWorldService:OnSelectHotbarSlot(player, data)
				end
			end
		},
        -- Deprecated height/path handlers removed
		-- Deploy/Remove tower handlers removed with world system

		-- Voxel World Events
		{
			name = "VoxelPlayerPositionUpdate",
			handler = function(player, positionData)
				if services.VoxelWorldService and services.VoxelWorldService.UpdatePlayerPosition then
					services.VoxelWorldService:UpdatePlayerPosition(player, positionData)
				end
			end
		},
		-- Player input snapshots (REMOVED - using Roblox native movement)
		{
			name = "VoxelRequestBlockPlace",
			handler = function(player, blockData)
				if services.VoxelWorldService and services.VoxelWorldService.RequestBlockPlace then
					services.VoxelWorldService:RequestBlockPlace(player, blockData)
				end
			end
		},
		{
			name = "RequestSpawnMobAt",
			handler = function(player, data)
				if services.MobEntityService and services.MobEntityService.HandleSpawnEggUse then
					services.MobEntityService:HandleSpawnEggUse(player, data)
				end
			end
		},
		{
			name = "PlayerPunch",
			handler = function(player, punchData)
				if services.VoxelWorldService and services.VoxelWorldService.HandlePlayerPunch then
					services.VoxelWorldService:HandlePlayerPunch(player, punchData)
				end
			end
		},
		{
			name = "CancelBlockBreak",
			handler = function(player, data)
				if services.VoxelWorldService and services.VoxelWorldService.CancelBlockBreak then
					services.VoxelWorldService:CancelBlockBreak(player, data)
				end
			end
		},
		-- PvP melee
		{
			name = "PlayerMeleeHit",
			handler = function(player, data)
				if services.VoxelWorldService and services.VoxelWorldService.HandlePlayerMeleeHit then
					services.VoxelWorldService:HandlePlayerMeleeHit(player, data)
				end
			end
		},
		-- PlayerSneak (REMOVED - using Roblox native movement)
		{
			name = "VoxelRequestRenderDistance",
			handler = function(player, distance)
				if services.VoxelWorldService and services.VoxelWorldService.RequestRenderDistance then
					services.VoxelWorldService:RequestRenderDistance(player, distance)
				end
			end
		},
		{
			name = "VoxelRequestInitialChunks",
			handler = function(player)
				-- Mark as ready and immediately stream an initial batch
				local vws = services.VoxelWorldService
				if vws and vws.players and vws.players[player] then
					vws.players[player].isReady = true
					vws:StreamChunksToPlayer(player, vws.players[player])
				end
			end
		},
		-- Chest events
		{
			name = "RequestOpenChest",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandleOpenChest then
					services.ChestStorageService:HandleOpenChest(player, data)
				end
			end
		},
		{
			name = "RequestCloseChest",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandleCloseChest then
					services.ChestStorageService:HandleCloseChest(player, data)
				end
			end
		},
		{
			name = "ChestItemTransfer",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandleItemTransfer then
					services.ChestStorageService:HandleItemTransfer(player, data)
				end
			end
		},
		{
			name = "ChestSlotClick",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandleChestSlotClick then
					services.ChestStorageService:HandleChestSlotClick(player, data)
				end
			end
		},
		-- Workbench open request (no server storage; just validate block type and open client UI)
		{
			name = "RequestOpenWorkbench",
			handler = function(player, data)
				if not data or not data.x or not data.y or not data.z then
					return
				end

				-- Verify targeted block is a crafting table
				local ok, _ = pcall(function()
					if services and services.VoxelWorldService and services.VoxelWorldService.worldManager then
						local ReplicatedStorage = game:GetService("ReplicatedStorage")
						local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
						local wm = services.VoxelWorldService.worldManager
						local blockId = wm:GetBlock(data.x, data.y, data.z)
						if blockId ~= Constants.BlockType.CRAFTING_TABLE then
							return
						end
						-- Send open event to this player
						local EventManager = require(ReplicatedStorage.Shared.EventManager)
						EventManager:FireEvent("WorkbenchOpened", player, { x = data.x, y = data.y, z = data.z })
					end
				end)
				if not ok then
					-- Swallow errors; no-op on invalid requests
				end
			end
		},
		-- Minion open request
		{
			name = "RequestOpenMinion",
			handler = function(player, data)
				if not data or not data.x or not data.y or not data.z then
					return
				end
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleOpenMinion then
					services.VoxelWorldService:HandleOpenMinion(player, data)
				end
			end
		},
		-- Minion open request by entity id
		{
			name = "RequestOpenMinionByEntity",
			handler = function(player, data)
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleOpenMinionByEntity then
					services.VoxelWorldService:HandleOpenMinionByEntity(player, data)
				end
			end
		},
		-- Minion upgrade request
		{
			name = "RequestMinionUpgrade",
			handler = function(player, data)
				local services = self._services
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleMinionUpgrade then
					services.VoxelWorldService:HandleMinionUpgrade(player, data)
				end
			end
		},
		{
			name = "RequestMinionCollectAll",
			handler = function(player, data)
				local services = self._services
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleMinionCollectAll then
					services.VoxelWorldService:HandleMinionCollectAll(player, data)
				end
			end
		},
		{
			name = "RequestMinionPickup",
			handler = function(player, data)
				local services = self._services
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleMinionPickup then
					services.VoxelWorldService:HandleMinionPickup(player, data)
				end
			end
		},
		{
			name = "RequestCloseMinion",
			handler = function(player, data)
				local services = self._services
				if services and services.VoxelWorldService and services.VoxelWorldService.HandleCloseMinion then
					services.VoxelWorldService:HandleCloseMinion(player, data)
				end
			end
		},
		{
			name = "ChestContentsUpdate",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandleChestContentsUpdate then
					services.ChestStorageService:HandleChestContentsUpdate(player, data)
				end
			end
		},
		{
			name = "PlayerInventoryUpdate",
			handler = function(player, data)
				if services.ChestStorageService and services.ChestStorageService.HandlePlayerInventoryUpdate then
					services.ChestStorageService:HandlePlayerInventoryUpdate(player, data)
				end
			end
		},
		{
			name = "InventoryUpdate",
			handler = function(player, data)
				if services.PlayerInventoryService and services.PlayerInventoryService.HandleInventoryUpdate then
					services.PlayerInventoryService:HandleInventoryUpdate(player, data)
				end
			end
		},
		-- Dropped Item events
		{
			name = "RequestItemPickup",
			handler = function(player, data)
				if services.DroppedItemService and services.DroppedItemService.HandlePickupRequest then
					services.DroppedItemService:HandlePickupRequest(player, data)
				end
			end
		},
		{
			name = "RequestDropItem",
			handler = function(player, data)
				if services.DroppedItemService and services.DroppedItemService.HandleDropRequest then
					services.DroppedItemService:HandleDropRequest(player, data)
				end
			end
		},
		{
			name = "AttackMob",
			handler = function(player, data)
				if services.MobEntityService and services.MobEntityService.HandleAttackMob then
					services.MobEntityService:HandleAttackMob(player, data)
				end
			end
		},
		{
			name = "BowShoot",
			handler = function(player, data)
				if services.BowService and services.BowService.OnBowShoot then
					services.BowService:OnBowShoot(player, data)
				end
			end
		},
		{
			name = "CraftRecipe",
			handler = function(player, data)
				if services.CraftingService and services.CraftingService.HandleCraftRequest then
					services.CraftingService:HandleCraftRequest(player, data)
				end
			end
		},
		{
			name = "CraftRecipeBatch",
			handler = function(player, data)
				if services.CraftingService and services.CraftingService.HandleCraftBatchRequest then
					services.CraftingService:HandleCraftBatchRequest(player, data)
				end
			end
		},
		-- Armor equip events
		{
			name = "ArmorSlotClick",
			handler = function(player, data)
				if services.ArmorEquipService and services.ArmorEquipService.HandleArmorSlotClick then
					services.ArmorEquipService:HandleArmorSlotClick(player, data)
				end
			end
		},
		{
			name = "RequestArmorSync",
			handler = function(player)
				if services.ArmorEquipService then
					if services.ArmorEquipService.SyncArmorToClient then
						services.ArmorEquipService:SyncArmorToClient(player)
					end
					-- Also sync armor stats for StatusBarsHUD
					if services.ArmorEquipService._syncArmorStats then
						services.ArmorEquipService:_syncArmorStats(player)
					end
				end
			end
		},
	}

	return config
end

--[[
	Get registered events (for debugging)
--]]
function EventManager:GetRegisteredEvents()
	local events = {}
	for name, _ in pairs(self._events) do
		table.insert(events, name)
	end
	return events
end

--[[
	Cleanup
--]]
function EventManager:Cleanup()
	self._events = {}
	self._handlers = {}
	self._network = nil
	self._isInitialized = false
	print("EventManager: Cleaned up")
end

-- Export singleton
return EventManager.GetInstance()