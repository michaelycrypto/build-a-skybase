-- DataApi.lua - Player data, currencies, inventory

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local DataApi = {
	_cache = {
		playerData = nil,
		currencies = nil,
		inventory = nil
	}
}

function DataApi.RequestRefresh()
	EventManager:SendToServer("RequestDataRefresh")
end

function DataApi.OnPlayerDataUpdated(callback)
	return EventManager:ConnectToServer("PlayerDataUpdated", function(playerData)
		DataApi._cache.playerData = playerData
		callback(playerData)
	end)
end

function DataApi.OnCurrencyUpdated(callback)
	return EventManager:ConnectToServer("CurrencyUpdated", function(currencies)
		DataApi._cache.currencies = currencies
		callback(currencies)
	end)
end

function DataApi.OnInventoryUpdated(callback)
	return EventManager:ConnectToServer("InventoryUpdated", function(inventory)
		DataApi._cache.inventory = inventory
		callback(inventory)
	end)
end

function DataApi.GetPlayerData()
	return DataApi._cache.playerData
end

function DataApi.UpdateSettings(settings)
	EventManager:SendToServer("UpdateSettings", settings)
end

return DataApi


