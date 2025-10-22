-- InventoryApi.lua - Inventory updates/cache

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local InventoryApi = {
	_cache = nil
}

function InventoryApi.OnUpdated(callback)
	return EventManager:ConnectToServer("InventoryUpdated", function(inventory)
		InventoryApi._cache = inventory
		callback(inventory)
	end)
end

function InventoryApi.Get()
	return InventoryApi._cache
end

return InventoryApi


