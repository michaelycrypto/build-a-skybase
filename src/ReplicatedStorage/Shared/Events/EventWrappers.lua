--[[
	EventWrappers.lua
	Thin client wrappers around EventManager for existing API modules
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local EventWrappers = {
	Client = {}
}

-- Client -> Server requests
function EventWrappers.Client.RequestDailyRewardData()
	EventManager:SendToServer("RequestDailyRewardData")
end

function EventWrappers.Client.ClaimDailyReward()
	EventManager:SendToServer("ClaimDailyReward")
end

-- Server -> Client listeners
function EventWrappers.Client.OnDailyRewardDataUpdated(callback)
	return EventManager:ConnectToServer("DailyRewardDataUpdated", callback)
end

function EventWrappers.Client.OnDailyRewardClaimed(callback)
	return EventManager:ConnectToServer("DailyRewardClaimed", callback)
end

function EventWrappers.Client.OnDailyRewardError(callback)
	return EventManager:ConnectToServer("DailyRewardError", callback)
end

-- Quests
function EventWrappers.Client.RequestQuestData()
	EventManager:SendToServer("RequestQuestData")
end

function EventWrappers.Client.ClaimQuestReward(payload)
	EventManager:SendToServer("ClaimQuestReward", payload)
end

function EventWrappers.Client.OnQuestDataUpdated(callback)
	return EventManager:ConnectToServer("QuestDataUpdated", callback)
end

function EventWrappers.Client.OnQuestProgressUpdated(callback)
	return EventManager:ConnectToServer("QuestProgressUpdated", callback)
end

function EventWrappers.Client.OnQuestRewardClaimed(callback)
	return EventManager:ConnectToServer("QuestRewardClaimed", callback)
end

function EventWrappers.Client.OnQuestError(callback)
	return EventManager:ConnectToServer("QuestError", callback)
end

-- Shop
function EventWrappers.Client.GetShopStock()
	EventManager:SendToServer("GetShopStock")
end

function EventWrappers.Client.PurchaseItem(itemId, quantity)
	EventManager:SendToServer("PurchaseItem", itemId, quantity)
end

function EventWrappers.Client.OnShopDataUpdated(callback)
	return EventManager:ConnectToServer("ShopDataUpdated", callback)
end

function EventWrappers.Client.OnShopStockUpdated(callback)
	return EventManager:ConnectToServer("ShopStockUpdated", callback)
end

return EventWrappers
