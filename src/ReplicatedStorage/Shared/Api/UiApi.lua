-- UiApi.lua - Simple UI-facing API wrappers

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local UiApi = {}

function UiApi.OnShowNotification(callback)
	return EventManager:ConnectToServer("ShowNotification", function(notificationData)
		callback(notificationData)
	end)
end

function UiApi.OnShowError(callback)
	return EventManager:ConnectToServer("ShowError", function(errorData)
		callback(errorData)
	end)
end

return UiApi


