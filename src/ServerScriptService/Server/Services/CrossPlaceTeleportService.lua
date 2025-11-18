--[[
	CrossPlaceTeleportService.lua

	Small helper to handle common teleports like ReturnToLobby from any place.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)

local TeleportService = game:GetService("TeleportService")

local LOBBY_PLACE_ID = 139848475014328

local CrossPlaceTeleportService = setmetatable({}, BaseService)
CrossPlaceTeleportService.__index = CrossPlaceTeleportService

function CrossPlaceTeleportService.new()
	local self = setmetatable(BaseService.new(), CrossPlaceTeleportService)
	self._logger = Logger:CreateContext("CrossPlaceTeleport")
	return self
end

function CrossPlaceTeleportService:ReturnToLobby(player: Player)
	if not player then return end
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		intent = "returnToLobby"
	})
	pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }, options)
	end)
end

return CrossPlaceTeleportService


