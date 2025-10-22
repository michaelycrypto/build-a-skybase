-- ShopApi.lua - Shop stock and purchases

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventWrappers = require(ReplicatedStorage.Shared.Events.EventWrappers)

local ShopApi = {}

function ShopApi.RequestStock()
	EventWrappers.Client.GetShopStock()
end

function ShopApi.OnStockUpdated(callback)
	return EventWrappers.Client.OnShopStockUpdated(callback)
end

function ShopApi.OnShopDataUpdated(callback)
	return EventWrappers.Client.OnShopDataUpdated(callback)
end

function ShopApi.Purchase(itemId, quantity)
	EventWrappers.Client.PurchaseItem(itemId, quantity or 1)
end

return ShopApi


