--[[
	TutorialService.lua - Server-side Tutorial/Onboarding Management

	Tracks player tutorial progress, validates step completion, and grants rewards.
	Server-authoritative: all progress changes go through this service.

	NOTE: Tutorial only applies in player's own realm, not in the hub or other players' realms.
]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local TutorialConfig = require(game.ReplicatedStorage.Configs.TutorialConfig)
local GameConfig = require(game.ReplicatedStorage.Configs.GameConfig)
local ServerRoleDetector = require(game.ReplicatedStorage.Shared.ServerRoleDetector)

-- Server role detection (single-place architecture)
local IS_HUB = ServerRoleDetector.IsHub()

local TutorialService = setmetatable({}, BaseService)
TutorialService.__index = TutorialService

function TutorialService.new()
	local self = setmetatable(BaseService.new(), TutorialService)

	self._logger = Logger:CreateContext("TutorialService")
	self._eventManager = nil
	self._config = TutorialConfig

	-- In-memory cache of player tutorial data: userId -> tutorialData
	self._playerTutorials = {}

	return self
end

function TutorialService:Init()
	if self._initialized then return end

	self._eventManager = require(game.ReplicatedStorage.Shared.EventManager)

	BaseService.Init(self)

	if IS_HUB then
		self._logger.Debug("TutorialService initialized (DISABLED - Hub server)")
	else
		self._logger.Debug("TutorialService initialized (World server)")
	end
end

function TutorialService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Debug("TutorialService started")
end

function TutorialService:Destroy()
	if self._destroyed then return end
	self._playerTutorials = {}
	BaseService.Destroy(self)
	self._logger.Info("TutorialService destroyed")
end

-- Steps that can progress on hub servers (hub-specific objectives)
local HUB_ALLOWED_STEPS = {
	use_portal = true,      -- Completes when entering hub
	find_merchant = true,   -- NPC interaction
	sell_crops = true,      -- Selling items
	visit_farm_shop = true, -- NPC interaction
	buy_seeds = true,       -- Buying items
	return_home = true,     -- Completes when returning to player world
}

-- Objective types that can be tracked on hub servers
local HUB_ALLOWED_OBJECTIVES = {
	enter_world = true,
	npc_interact = true,
	sell_item = true,
	buy_item = true,
}

--[[
	Check if tutorial should be active for a player
	Tutorial applies in player's OWN realm AND in hub for hub-specific steps
	@param player: Player - The player to check
	@param stepId: string? - Optional step ID for hub-specific checks
	@return boolean - True if tutorial should be active
]]
function TutorialService:_isTutorialActiveFor(player, stepId)
	-- In hub: only allow hub-specific steps
	if IS_HUB then
		if stepId then
			return HUB_ALLOWED_STEPS[stepId] == true
		end
		-- If no stepId provided, check current step
		local data = self._playerTutorials[player.UserId]
		if data and data.currentStep then
			return HUB_ALLOWED_STEPS[data.currentStep] == true
		end
		return false
	end

	-- Check if WorldOwnershipService is available and player is the owner
	if self.Deps.WorldOwnershipService then
		local isOwner = self.Deps.WorldOwnershipService:IsOwner(player)
		if not isOwner then
			self._logger.Debug("Tutorial disabled - player is not realm owner", {
				player = player.Name,
				ownerId = self.Deps.WorldOwnershipService:GetOwnerId()
			})
			return false
		end
	end

	return true
end

--[[
	Check if an objective type can be tracked on the current server
	@param objectiveType: string - The objective type
	@return boolean - True if tracking is allowed
]]
function TutorialService:_canTrackObjective(objectiveType)
	if IS_HUB then
		return HUB_ALLOWED_OBJECTIVES[objectiveType] == true
	end
	return true
end

--[[
	Ensure tutorial data structure exists for the player
]]
function TutorialService:_ensurePlayerData(player)
	local userId = player.UserId
	if not self._playerTutorials[userId] then
		-- Load saved tutorial data from player profile
		local savedData = nil
		if self.Deps.PlayerService and self.Deps.PlayerService.GetPlayerData then
			local playerData = self.Deps.PlayerService:GetPlayerData(player)
			savedData = playerData and playerData.tutorial
		end

		if savedData and savedData.currentStep then
			self._logger.Info("Loaded saved tutorial data for player", {
				player = player.Name,
				currentStep = savedData.currentStep,
				completed = savedData.completed
			})
			self._playerTutorials[userId] = savedData
		else
			self._logger.Info("No saved tutorial data found, creating new", {
				player = player.Name
			})
			self._playerTutorials[userId] = {
				completed = false,
				skipped = false,
				currentStep = "welcome",
				completedSteps = {},
				startedAt = os.time(),
				completedAt = 0,
			}
		end
	end
	return self._playerTutorials[userId]
end

--[[
	Get tutorial data for a player
]]
function TutorialService:GetTutorialData(player)
	return self:_ensurePlayerData(player)
end

--[[
	Send tutorial data to client
]]
function TutorialService:SendTutorialData(player)
	local data = self:_ensurePlayerData(player)
	
	-- Check if tutorial is already complete
	if data.completed then
		if self._eventManager then
			self._eventManager:FireEvent("TutorialDataUpdated", player, {
				tutorial = data,
				config = nil,
			})
		end
		return
	end

	-- Check if tutorial is active for this player (considering current step)
	local isActive = self:_isTutorialActiveFor(player, data.currentStep)

	if not isActive then
		-- Send disabled state to client (not in correct realm for current step)
		if self._eventManager then
			self._eventManager:FireEvent("TutorialDataUpdated", player, {
				tutorial = {
					completed = false,
					disabled = true,   -- Flag that tutorial is disabled for current step
					currentStep = data.currentStep,
				},
				config = nil,
				isHub = IS_HUB,
			})
		end
		return
	end

	if self._eventManager then
		self._eventManager:FireEvent("TutorialDataUpdated", player, {
			tutorial = data,
			config = {
				-- Send only necessary config data to client
				currentStep = self._config.GetStep(data.currentStep),
				settings = self._config.Settings,
			},
			isOwnRealm = not IS_HUB,  -- Only true on player's own world server
			isHub = IS_HUB,
		})
	end
end

--[[
	Client request handler: send latest tutorial data
]]
function TutorialService:OnRequestTutorialData(player)
	self._logger.Debug("Client requested tutorial data", {player = player.Name})
	self:SendTutorialData(player)
end

--[[
	Complete a tutorial step and advance to next
]]
function TutorialService:CompleteStep(player, stepId)
	-- Check if tutorial is active for this player
	if not self:_isTutorialActiveFor(player) then
		return false
	end

	local data = self:_ensurePlayerData(player)

	-- Validate step exists
	local step = self._config.GetStep(stepId)
	if not step then
		self._logger.Warn("Invalid step ID", {player = player.Name, stepId = stepId})
		return false
	end

	-- Check if already completed
	if data.completedSteps[stepId] then
		self._logger.Debug("Step already completed", {player = player.Name, stepId = stepId})
		return true
	end

	-- Check if this is the current step (or allow out-of-order completion)
	if data.currentStep ~= stepId then
		self._logger.Warn("Step not current - allowing anyway", {
			player = player.Name,
			stepId = stepId,
			currentStep = data.currentStep
		})
	end

	-- Mark step as completed
	data.completedSteps[stepId] = os.time()
	self._logger.Info("Tutorial step completed", {
		player = player.Name,
		stepId = stepId
	})

	-- Special action: Instantly grow crops when plant_seeds completes
	if stepId == "plant_seeds" and TutorialConfig.Settings.instantGrowCropsOnPlant then
		local cropService = self.Deps and self.Deps.CropService
		if cropService and cropService.InstantGrowAllCrops then
			local grownCount = cropService:InstantGrowAllCrops()
			self._logger.Info("Tutorial: Instantly grew crops", {
				player = player.Name,
				count = grownCount
			})
		end
	end

	-- Grant reward if any
	if step.reward then
		self:_grantReward(player, step.reward)
	end

	-- Advance to next step
	local nextStep = self._config.GetNextStep(stepId)
	if nextStep then
		data.currentStep = nextStep.id
		self._logger.Info("Advancing to next step", {
			player = player.Name,
			nextStep = nextStep.id
		})
	else
		-- Tutorial complete!
		data.completed = true
		data.completedAt = os.time()
		data.currentStep = nil
		self._logger.Info("Tutorial completed!", {player = player.Name})
	end

	-- Save progress
	self:_saveTutorialData(player, data)

	-- Notify client
	if self._eventManager then
		self._eventManager:FireEvent("TutorialStepCompleted", player, {
			completedStep = stepId,
			nextStep = nextStep,
			reward = step.reward,
			tutorialComplete = data.completed,
		})
	end

	return true
end

--[[
	Client request handler: complete a step
]]
function TutorialService:OnCompleteStep(player, requestData)
	local stepId = requestData and requestData.stepId
	if type(stepId) ~= "string" then
		self._logger.Warn("Invalid step completion request", {player = player.Name})
		return
	end

	self:CompleteStep(player, stepId)
end

--[[
	Skip the current tutorial step
]]
function TutorialService:SkipStep(player)
	-- Check if tutorial is active for this player
	if not self:_isTutorialActiveFor(player) then
		return false
	end

	local data = self:_ensurePlayerData(player)

	if data.completed then
		return false
	end

	local currentStep = self._config.GetStep(data.currentStep)
	if not currentStep then
		return false
	end

	-- Check if step can be skipped
	if not currentStep.canSkip then
		self._logger.Warn("Step cannot be skipped", {
			player = player.Name,
			stepId = data.currentStep
		})
		if self._eventManager then
			self._eventManager:FireEvent("TutorialError", player, {
				message = "This step cannot be skipped"
			})
		end
		return false
	end

	-- Mark as skipped (no reward)
	data.completedSteps[data.currentStep] = os.time()

	-- Advance to next step
	local nextStep = self._config.GetNextStep(data.currentStep)
	if nextStep then
		data.currentStep = nextStep.id
	else
		data.completed = true
		data.completedAt = os.time()
		data.currentStep = nil
	end

	-- Save progress
	self:_saveTutorialData(player, data)

	-- Notify client
	if self._eventManager then
		self._eventManager:FireEvent("TutorialStepSkipped", player, {
			skippedStep = currentStep.id,
			nextStep = nextStep,
			tutorialComplete = data.completed,
		})
	end

	return true
end

--[[
	Client request handler: skip current step
]]
function TutorialService:OnSkipStep(player)
	self:SkipStep(player)
end

--[[
	Skip the entire tutorial
]]
function TutorialService:SkipTutorial(player)
	-- Check if tutorial is active for this player
	if not self:_isTutorialActiveFor(player) then
		return false
	end

	local data = self:_ensurePlayerData(player)

	if data.completed then
		return false
	end

	data.completed = true
	data.skipped = true
	data.completedAt = os.time()
	data.currentStep = nil

	-- Save progress
	self:_saveTutorialData(player, data)

	-- Notify client
	if self._eventManager then
		self._eventManager:FireEvent("TutorialSkipped", player, {
			tutorial = data,
		})
	end

	self._logger.Info("Tutorial skipped", {player = player.Name})
	return true
end

--[[
	Client request handler: skip entire tutorial
]]
function TutorialService:OnSkipTutorial(player)
	self:SkipTutorial(player)
end

--[[
	Track progress toward a step objective (called by other services)
	@param player: Player
	@param progressType: string - Type of progress ("collect_item", "craft_item", "place_block", etc.)
	@param progressData: table - Data about the progress
]]
function TutorialService:TrackProgress(player, progressType, progressData)
	local data = self:_ensurePlayerData(player)
	
	-- Check if this objective type can be tracked on this server
	if not self:_canTrackObjective(progressType) then
		self._logger.Debug("Objective type not trackable on this server", {
			player = player.Name,
			progressType = progressType,
			isHub = IS_HUB,
		})
		return
	end

	-- Check if tutorial is active for this player's current step
	if not self:_isTutorialActiveFor(player, data.currentStep) then
		return
	end

	-- Skip if tutorial completed
	if data.completed then
		return
	end

	local currentStep = self._config.GetStep(data.currentStep)
	if not currentStep or not currentStep.objective then
		return
	end

	local objective = currentStep.objective

	-- Check if progress type matches objective type
	if objective.type ~= progressType then
		return
	end

	-- Validate progress based on objective type
	local isComplete = false

	if progressType == "collect_item" then
		local itemId = progressData.itemId
		local count = progressData.count or 1

		self._logger.Debug("Tutorial collect_item progress", {
			player = player.Name,
			stepId = data.currentStep,
			itemId = itemId,
			count = count,
			requiredCount = objective.count,
			hasItemId = objective.itemId ~= nil,
			hasAnyOf = objective.anyOf ~= nil
		})

		if objective.itemId and itemId == objective.itemId then
			isComplete = count >= (objective.count or 1)
			self._logger.Debug("Tutorial collect_item: itemId match", {
				player = player.Name,
				isComplete = isComplete,
				count = count,
				required = objective.count
			})
		elseif objective.anyOf then
			local itemMatches = false
			for _, targetId in ipairs(objective.anyOf) do
				if itemId == targetId then
					itemMatches = true
					break
				end
			end

			if itemMatches then
				isComplete = count >= (objective.count or 1)
				self._logger.Debug("Tutorial collect_item: anyOf match", {
					player = player.Name,
					isComplete = isComplete,
					count = count,
					required = objective.count,
					itemId = itemId
				})
			else
				self._logger.Debug("Tutorial collect_item: itemId not in anyOf", {
					player = player.Name,
					itemId = itemId,
					anyOf = objective.anyOf
				})
			end
		end

	elseif progressType == "craft_item" then
		local itemId = progressData.itemId
		local craftedCount = progressData.count or 1
		if objective.itemId and itemId == objective.itemId then
			-- Track cumulative craft progress
			data.craftProgressCount = (data.craftProgressCount or 0) + craftedCount
			isComplete = data.craftProgressCount >= (objective.count or 1)

			self._logger.Debug("Tutorial craft_item progress", {
				player = player.Name,
				stepId = data.currentStep,
				itemId = itemId,
				craftedCount = craftedCount,
				totalProgress = data.craftProgressCount,
				requiredCount = objective.count or 1,
				isComplete = isComplete
			})

			-- Update progressData for UI display
			progressData.count = data.craftProgressCount
		end

	elseif progressType == "place_block" then
		local blockId = progressData.blockId
		if objective.blockId and blockId == objective.blockId then
			-- Track cumulative progress
			data.placeProgressCount = (data.placeProgressCount or 0) + 1
			isComplete = data.placeProgressCount >= (objective.count or 1)
			progressData.count = data.placeProgressCount
		elseif objective.anyOf then
			for _, targetId in ipairs(objective.anyOf) do
				if blockId == targetId then
					data.placeProgressCount = (data.placeProgressCount or 0) + 1
					isComplete = data.placeProgressCount >= (objective.count or 1)
					progressData.count = data.placeProgressCount
					break
				end
			end
		end

	elseif progressType == "break_block" then
		local blockType = progressData.blockType
		local count = progressData.count or 1
		if objective.blockTypes then
			for _, targetType in ipairs(objective.blockTypes) do
				if blockType == targetType then
					-- Track cumulative progress
					data.progressCount = (data.progressCount or 0) + 1
					isComplete = data.progressCount >= (objective.count or 1)
					break
				end
			end
		end

	elseif progressType == "ui_open" then
		local panel = progressData.panel
		if objective.panel and panel == objective.panel then
			isComplete = true
		end

	elseif progressType == "move" then
		local distance = progressData.distance or 0
		data.progressDistance = (data.progressDistance or 0) + distance
		isComplete = data.progressDistance >= (objective.distance or 10)

	elseif progressType == "camera_rotate" then
		local degrees = progressData.degrees or 0
		data.progressRotation = (data.progressRotation or 0) + math.abs(degrees)
		isComplete = data.progressRotation >= (objective.degrees or 180)

	elseif progressType == "camera_cycle" then
		local count = progressData.count or 0
		local mode = progressData.mode

		-- Initialize visited modes set if not exists
		if not data.visitedCameraModes then
			data.visitedCameraModes = {}
		end

		-- Track unique modes visited
		if mode and not data.visitedCameraModes[mode] then
			data.visitedCameraModes[mode] = true
		end

		-- Count unique modes visited
		local uniqueCount = 0
		for _ in pairs(data.visitedCameraModes) do
			uniqueCount = uniqueCount + 1
		end

		-- Complete when all required modes have been visited
		isComplete = uniqueCount >= (objective.count or 3)

		-- Update progressData with server-calculated count for UI display
		progressData.count = uniqueCount

		self._logger.Debug("Tutorial camera_cycle progress", {
			player = player.Name,
			stepId = data.currentStep,
			mode = mode,
			uniqueCount = uniqueCount,
			requiredCount = objective.count or 3,
			isComplete = isComplete
		})

	elseif progressType == "interact_block" then
		local blockType = progressData.blockType
		if objective.blockType and blockType == objective.blockType then
			isComplete = true
		end

	elseif progressType == "equip_item" then
		local itemId = progressData.itemId
		if objective.itemId and itemId == objective.itemId then
			isComplete = true
		end

	elseif progressType == "npc_interact" then
		local npcType = progressData.npcType
		if objective.npcType and npcType == objective.npcType then
			isComplete = true
		end

	elseif progressType == "sell_item" then
		local count = progressData.count or 1
		-- Track cumulative sell progress
		data.sellProgressCount = (data.sellProgressCount or 0) + count
		isComplete = data.sellProgressCount >= (objective.count or 1)
		progressData.count = data.sellProgressCount

	elseif progressType == "buy_item" then
		local count = progressData.count or 1
		-- Track cumulative buy progress
		data.buyProgressCount = (data.buyProgressCount or 0) + count
		isComplete = data.buyProgressCount >= (objective.count or 1)
		progressData.count = data.buyProgressCount

	elseif progressType == "enter_world" then
		local worldType = progressData.worldType
		if objective.worldType and worldType == objective.worldType then
			isComplete = true
			self._logger.Info("Tutorial enter_world objective met", {
				player = player.Name,
				stepId = data.currentStep,
				worldType = worldType,
			})
		end
	end

	-- Complete step if objective met
	if isComplete then
		self:CompleteStep(player, data.currentStep)
	else
		-- Send progress update to client
		if self._eventManager then
			self._logger.Info("Sending TutorialProgressUpdated to client", {
				player = player.Name,
				stepId = data.currentStep,
				progressType = progressType,
				count = progressData.count
			})
			self._eventManager:FireEvent("TutorialProgressUpdated", player, {
				stepId = data.currentStep,
				progressType = progressType,
				progressData = progressData,
			})
		end
	end
end

--[[
	Grant reward for completing a step
]]
function TutorialService:_grantReward(player, reward)
	if not reward then return end

	local granted = {}

	if reward.coins and self.Deps.PlayerService then
		local success = self.Deps.PlayerService:AddCurrency(player, "coins", reward.coins)
		if success then
			granted.coins = reward.coins
		end
	end

	if reward.gems and self.Deps.PlayerService then
		local success = self.Deps.PlayerService:AddCurrency(player, "gems", reward.gems)
		if success then
			granted.gems = reward.gems
		end
	end

	if reward.experience and self.Deps.PlayerService then
		self.Deps.PlayerService:AddExperience(player, reward.experience)
		granted.experience = reward.experience
	end

	self._logger.Info("Tutorial reward granted", {
		player = player.Name,
		reward = granted
	})

	return granted
end

--[[
	Save tutorial data to player profile
]]
function TutorialService:_saveTutorialData(player, data)
	if self.Deps.PlayerService and self.Deps.PlayerService.SavePlayerData then
		local playerData = self.Deps.PlayerService:GetPlayerData(player) or {}
		playerData.tutorial = data
		self.Deps.PlayerService:SavePlayerData(player, playerData)
	end
end

--[[
	Check if player has completed tutorial
]]
function TutorialService:HasCompletedTutorial(player)
	local data = self:_ensurePlayerData(player)
	return data.completed
end

--[[
	Reset tutorial for testing
]]
function TutorialService:ResetTutorial(player)
	local userId = player.UserId
	self._playerTutorials[userId] = {
		completed = false,
		skipped = false,
		currentStep = "welcome",
		completedSteps = {},
		startedAt = os.time(),
		completedAt = 0,
	}

	-- Save reset
	self:_saveTutorialData(player, self._playerTutorials[userId])

	-- Notify client
	if self._eventManager then
		self:SendTutorialData(player)
	end

	self._logger.Info("Tutorial reset", {player = player.Name})
end

--[[
	Clear cached data for a player (on disconnect)
]]
function TutorialService:ClearPlayerCache(player)
	local userId = player.UserId
	self._playerTutorials[userId] = nil
end

return TutorialService

