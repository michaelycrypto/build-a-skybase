-- EmoteApi.lua - Emote triggers/events

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local EmoteApi = {}

function EmoteApi.Play(emoteName)
	EventManager:SendToServer("PlayEmote", emoteName)
end

function EmoteApi.OnShow(callback)
	return EventManager:ConnectToServer("ShowEmote", function(targetPlayer, emoteName)
		callback(targetPlayer, emoteName)
	end)
end

function EmoteApi.OnRemove(callback)
	return EventManager:ConnectToServer("RemoveEmote", function(targetPlayer)
		callback(targetPlayer)
	end)
end

return EmoteApi


