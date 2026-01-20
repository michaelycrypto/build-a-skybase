--[[
	QuestService.lua - Server-side Quests and Mob Incineration Tracking

	Tracks per-player mob kill counts (via lava incineration) and manages milestone rewards.
	Authoritative on the server; clients request/claim, server validates and grants.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local QuestService = setmetatable({}, BaseService)
QuestService.__index = QuestService

function QuestService.new()
	local self = setmetatable(BaseService.new(), QuestService)

	self._logger = Logger:CreateContext("QuestService")
	self._eventManager = nil
	self._questConfig = require(game.ReplicatedStorage.Configs.QuestConfig)

	-- In-memory cache of player quest data: userId -> questData
	self._playerQuests = {}

	return self
end

function QuestService:Init()
	if self._initialized then return end

	self._eventManager = require(game.ReplicatedStorage.Shared.EventManager)

	BaseService.Init(self)
	self._logger.Debug("QuestService initialized")
end

function QuestService:Start()
	if self._started then return end
	self._logger.Debug("QuestService started")
end

function QuestService:Destroy()
	if self._destroyed then return end
	self._playerQuests = {}
	BaseService.Destroy(self)
	self._logger.Info("QuestService destroyed")
end

-- Ensure quest data structure exists for the player
function QuestService:_ensurePlayerData(player)
	local userId = player.UserId
	if not self._playerQuests[userId] then
		-- Load saved quest data from player profile
		local savedData = nil
		if self.Deps.PlayerService and self.Deps.PlayerService.GetPlayerData then
			local playerData = self.Deps.PlayerService:GetPlayerData(player)
			savedData = playerData and playerData.quests
		end

		if savedData then
			self._logger.Info("Loaded saved quest data for player", {
				player = player.Name,
				savedData = savedData
			})
			self._playerQuests[userId] = savedData
		else
			self._logger.Info("No saved quest data found, creating new", {
				player = player.Name
			})
			self._playerQuests[userId] = {
				-- mobType -> {kills = number, claimed = {[milestone]=true}}
				mobs = {}
			}
		end
	end
	return self._playerQuests[userId]
end

-- Get or create record for a specific mob type
function QuestService:_getMobRecord(player, mobType)
	local pdata = self:_ensurePlayerData(player)
	local mobs = pdata.mobs
	if not mobs[mobType] then
		mobs[mobType] = {kills = 0, claimed = {}}
	end
	return mobs[mobType]
end

-- Clear cached quest data for a player (useful for testing)
function QuestService:ClearPlayerCache(player)
	local userId = player.UserId
	self._playerQuests[userId] = nil
	self._logger.Info("Cleared cached quest data for player", {player = player.Name})
end

-- Send full quest data to client
function QuestService:SendQuestData(player)
	local data = self:_ensurePlayerData(player)

	-- Detailed logging of what we're sending
	self._logger.Info("Sending quest data to player", {
		player = player.Name,
		questData = data
	})

	-- Log each mob's data in detail
	if data.mobs then
		for mobType, mobData in pairs(data.mobs) do
			self._logger.Info("Mob data being sent", {
				player = player.Name,
				mobType = mobType,
				kills = mobData.kills,
				claimed = mobData.claimed
			})
			-- Log specific milestone claims
			if mobData.claimed then
				for milestone, isClaimed in pairs(mobData.claimed) do
					self._logger.Info("Milestone claim status", {
						player = player.Name,
						mobType = mobType,
						milestone = milestone,
						claimed = isClaimed
					})
				end
			end
		end
	end

	if self._eventManager then
		-- Normalize claimed keys to strings to prevent RemoteEvent key conversion issues
		local normalizedData = {mobs = {}}
		if data.mobs then
			for mobType, mobData in pairs(data.mobs) do
				normalizedData.mobs[mobType] = {
					kills = mobData.kills,
					claimed = {}
				}
				if mobData.claimed then
					for milestone, isClaimed in pairs(mobData.claimed) do
						-- Convert all milestone keys to strings for consistent client access
						normalizedData.mobs[mobType].claimed[tostring(milestone)] = isClaimed
					end
				end
			end
		end

		-- Debug: Check data structure before sending
		local debugData = {}
		if normalizedData.mobs then
			for mobType, mobData in pairs(normalizedData.mobs) do
				debugData[mobType] = {
					kills = mobData.kills,
					claimedCount = 0
				}
				if mobData.claimed then
					for milestone, isClaimed in pairs(mobData.claimed) do
						if isClaimed then
							debugData[mobType].claimedCount = debugData[mobType].claimedCount + 1
						end
					end
				end
			end
		end
		self._logger.Info("About to send quest data", {
			player = player.Name,
			debugData = debugData
		})

		self._eventManager:FireEvent("QuestDataUpdated", player, {
			quests = normalizedData,
			config = self._questConfig
		})
	end
end

-- Public: Record a mob incineration attributed to a player
function QuestService:RecordMobIncinerated(player, mobType)
	if not player or not mobType then
		self._logger.Warn("RecordMobIncinerated called with invalid parameters", {
			player = player and player.Name or "nil",
			mobType = mobType
		})
		return
	end

	local config = self._questConfig.Mobs[mobType]
	if not config then
		-- Untracked mob type; silently ignore
		self._logger.Debug("Untracked mob type", {
			player = player.Name,
			mobType = mobType,
			availableMobTypes = table.concat(self:_getAvailableMobTypes(), ", ")
		})
		return
	end

	local record = self:_getMobRecord(player, mobType)
	record.kills += 1

	self._logger.Info("Recorded mob kill", {
		player = player.Name,
		mobType = mobType,
		newKillCount = record.kills
	})

	-- Check milestones reached
	local newlyAchieved = {}
	for _, milestone in ipairs(config.milestones) do
		if record.kills >= milestone and not record.claimed[milestone] then
			table.insert(newlyAchieved, milestone)
		end
	end

	if #newlyAchieved > 0 then
		self._logger.Info("New milestones achieved", {
			player = player.Name,
			mobType = mobType,
			milestones = newlyAchieved
		})
	end

	-- Notify client of progress
	if self._eventManager then
		local progressData = {
			mobType = mobType,
			kills = record.kills,
			newlyAchieved = newlyAchieved
		}
		self._logger.Info("Firing QuestProgressUpdated event", {
			player = player.Name,
			progressData = progressData
		})
		self._eventManager:FireEvent("QuestProgressUpdated", player, progressData)
	else
		self._logger.Error("EventManager not available for QuestProgressUpdated")
	end

	-- Persist to PlayerService data (best-effort)
	if self.Deps.PlayerService and self.Deps.PlayerService.SavePlayerData then
		local playerData = self.Deps.PlayerService:GetPlayerData(player) or {}
		playerData.quests = playerData.quests or {mobs = {}}
		playerData.quests.mobs[mobType] = {kills = record.kills, claimed = record.claimed}
		self.Deps.PlayerService:SavePlayerData(player, playerData)
	end
end

-- Client request handler: send latest quest data
function QuestService:OnRequestQuestData(player)
	self._logger.Info("Client requested quest data - clearing cache and reloading", {player = player.Name})
	-- Clear cache to force reload from saved data
	self:ClearPlayerCache(player)
	self:SendQuestData(player)
end

-- Client request handler: claim a specific milestone reward
-- claimData = {mobType = string, milestone = number}
function QuestService:OnClaimQuestReward(player, claimData)
	local mobType = claimData and claimData.mobType
	local milestone = claimData and claimData.milestone

	if type(mobType) ~= "string" or type(milestone) ~= "number" then
		if self._eventManager then
			self._eventManager:FireEvent("QuestError", player, {message = "Invalid claim parameters"})
		end
		return
	end

	local config = self._questConfig.Mobs[mobType]
	if not config then
		if self._eventManager then
			self._eventManager:FireEvent("QuestError", player, {message = "Unknown quest"})
		end
		return
	end

	local record = self:_getMobRecord(player, mobType)
	self._logger.Info("Checking claim eligibility", {
		player = player.Name,
		mobType = mobType,
		milestone = milestone,
		playerKills = record.kills,
		claimedMilestones = record.claimed
	})

	if record.kills < milestone then
		self._logger.Info("Milestone not reached", {player = player.Name, kills = record.kills, needed = milestone})
		if self._eventManager then
			self._eventManager:FireEvent("QuestError", player, {message = "Milestone not reached"})
		end
		return
	end
	if record.claimed[milestone] then
		self._logger.Info("Milestone already claimed", {player = player.Name, mobType = mobType, milestone = milestone})
		if self._eventManager then
			-- Don't send QuestError for already claimed - just sync the client state
			self._logger.Info("Syncing client state since milestone already claimed")
			self:SendQuestData(player)
		end
		return
	end

	local reward = (config.rewards and config.rewards[milestone]) or nil
	if not reward then
		if self._eventManager then
			self._eventManager:FireEvent("QuestError", player, {message = "No reward configured"})
		end
		return
	end

	-- Grant rewards using PlayerService
	local grantOk = true
	if reward.coins and self.Deps.PlayerService then
		grantOk = self.Deps.PlayerService:AddCurrency(player, "coins", reward.coins) and grantOk
	end
	if reward.gems and self.Deps.PlayerService then
		grantOk = self.Deps.PlayerService:AddCurrency(player, "gems", reward.gems) and grantOk
	end
	if reward.experience and self.Deps.PlayerService then
		grantOk = self.Deps.PlayerService:AddExperience(player, reward.experience) and grantOk
	end

	if not grantOk then
		if self._eventManager then
			self._eventManager:FireEvent("QuestError", player, {message = "Failed to grant reward"})
		end
		return
	end

	-- Mark claimed and persist
	record.claimed[milestone] = true
	self._logger.Info("Marked milestone as claimed", {
		player = player.Name,
		mobType = mobType,
		milestone = milestone,
		newClaimedState = record.claimed
	})

	if self.Deps.PlayerService and self.Deps.PlayerService.SavePlayerData then
		local playerData = self.Deps.PlayerService:GetPlayerData(player) or {}
		playerData.quests = playerData.quests or {mobs = {}}
		playerData.quests.mobs[mobType] = {kills = record.kills, claimed = record.claimed}
		self.Deps.PlayerService:SavePlayerData(player, playerData)
		self._logger.Info("Saved quest data to player profile", {
			player = player.Name,
			savedData = playerData.quests.mobs[mobType]
		})
	end

	-- Notify client of claim
	if self._eventManager then
		local claimData = {
			mobType = mobType,
			milestone = milestone,
			reward = reward
		}
		self._logger.Info("Firing QuestRewardClaimed event", {
			player = player.Name,
			claimData = claimData
		})
		self._eventManager:FireEvent("QuestRewardClaimed", player, claimData)

		-- Refresh the overall quest data
		self._logger.Info("About to send quest data after successful claim")
		self:SendQuestData(player)
		self._logger.Info("Successfully sent quest data after claim - client should receive QuestDataUpdated")
	else
		self._logger.Error("EventManager not available for QuestRewardClaimed")
	end
end

-- Helper function to get available mob types for debugging
function QuestService:_getAvailableMobTypes()
	local mobTypes = {}
	for mobType, _ in pairs(self._questConfig.Mobs) do
		table.insert(mobTypes, mobType)
	end
	return mobTypes
end

return QuestService


