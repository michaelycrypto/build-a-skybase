-- RewardsApi.lua - Daily rewards wrapper

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventWrappers = require(ReplicatedStorage.Shared.Events.EventWrappers)

local RewardsApi = {}

function RewardsApi.RequestDaily()
	EventWrappers.Client.RequestDailyRewardData()
end

function RewardsApi.ClaimDaily()
	EventWrappers.Client.ClaimDailyReward()
end

function RewardsApi.OnDailyUpdated(callback)
	return EventWrappers.Client.OnDailyRewardDataUpdated(callback)
end

function RewardsApi.OnDailyClaimed(callback)
	return EventWrappers.Client.OnDailyRewardClaimed(callback)
end

function RewardsApi.OnDailyError(callback)
	return EventWrappers.Client.OnDailyRewardError(callback)
end

return RewardsApi


