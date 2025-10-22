-- QuestsApi.lua - Quest data/events wrapper

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventWrappers = require(ReplicatedStorage.Shared.Events.EventWrappers)

local QuestsApi = {}

function QuestsApi.RequestData()
	EventWrappers.Client.RequestQuestData()
end

function QuestsApi.OnDataUpdated(callback)
	return EventWrappers.Client.OnQuestDataUpdated(callback)
end

function QuestsApi.OnProgressUpdated(callback)
	return EventWrappers.Client.OnQuestProgressUpdated(callback)
end

function QuestsApi.OnRewardClaimed(callback)
	return EventWrappers.Client.OnQuestRewardClaimed(callback)
end

function QuestsApi.OnError(callback)
	return EventWrappers.Client.OnQuestError(callback)
end

function QuestsApi.ClaimReward(mobType, milestone)
	EventWrappers.Client.ClaimQuestReward({mobType = mobType, milestone = milestone})
end

return QuestsApi


