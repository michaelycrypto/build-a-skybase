--[[
	CrossPlaceTeleportService.lua

	Small helper to handle common teleports like ReturnToLobby from any place.
--]]

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local EventManager = require(game.ReplicatedStorage.Shared.EventManager)

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local LOBBY_PLACE_ID = 139848475014328

local CrossPlaceTeleportService = setmetatable({}, BaseService)
CrossPlaceTeleportService.__index = CrossPlaceTeleportService

function CrossPlaceTeleportService.new()
	local self = setmetatable(BaseService.new(), CrossPlaceTeleportService)
	self._logger = Logger:CreateContext("CrossPlaceTeleport")
	return self
end

function CrossPlaceTeleportService:_teleportToLobby(player: Player, intent: string, errorEvent: string?)
	if not player then
		return
	end

	if RunService:IsStudio() then
		self._logger.Warn("Cross-place teleport blocked in Studio", {
			player = player.Name,
			intent = intent
		})
		if errorEvent then
			EventManager:FireEvent(errorEvent, player, {
				message = "Cross-place teleport is disabled in Studio. Publish and test in a live server."
			})
		end
		return
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({
		intent = intent or "returnToLobby"
	})

	local ok, err = pcall(function()
		TeleportService:TeleportAsync(LOBBY_PLACE_ID, { player }, options)
	end)

	if not ok then
		self._logger.Warn("Teleport to lobby failed", {
			player = player.Name,
			intent = intent,
			error = tostring(err)
		})
		if errorEvent then
			EventManager:FireEvent(errorEvent, player, {
				message = "Unable to teleport right now. Please try again."
			})
		end
	end
end

function CrossPlaceTeleportService:ReturnToLobby(player: Player)
	self:_teleportToLobby(player, "returnToLobby")
end

function CrossPlaceTeleportService:TeleportToHub(player: Player)
	self:_teleportToLobby(player, "teleportToHub", "HubTeleportError")
end

return CrossPlaceTeleportService


