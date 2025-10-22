--[[
	TeleportService.lua
	Handles teleportation between lobby and player-owned worlds
	Manages player state transitions and world loading/unloading
]]

local TeleportService = {}
TeleportService.__index = TeleportService

function TeleportService.new(lobbyManager, worldInstanceManager, worldPermissions)
	local self = setmetatable({
		lobbyManager = lobbyManager,
		worldInstanceManager = worldInstanceManager,
		worldPermissions = worldPermissions,
		playerLocations = {}, -- player -> {location, worldId}
		teleportCallbacks = {} -- Callbacks for teleport events
	}, TeleportService)

	return self
end

-- Get player's current location
function TeleportService:GetPlayerLocation(player: Player)
	return self.playerLocations[player] or {
		location = "lobby",
		worldId = nil
	}
end

-- Teleport player to lobby
function TeleportService:TeleportToLobby(player: Player, eventManager)
	if not player or not player.Character then
		return false, "invalid_player"
	end

	local currentLocation = self:GetPlayerLocation(player)

	-- Remove from current world if in one
	if currentLocation.worldId then
		local world = self.worldInstanceManager:GetWorldById(currentLocation.worldId)
		if world then
			world:RemovePlayer(player)
		end
		self.worldInstanceManager:RemovePlayerFromWorld(currentLocation.worldId, player)

		-- Fire event: player left world
		self:FireCallback("PlayerLeftWorld", {
			player = player,
			worldId = currentLocation.worldId
		})
	end

	-- Add to lobby
	self.lobbyManager:AddPlayer(player)

	-- Update location
	self.playerLocations[player] = {
		location = "lobby",
		worldId = nil
	}

	-- Move character
	local spawnPos = self.lobbyManager:GetSpawnPosition()
	if player.Character and player.Character.PrimaryPart then
		player.Character:MoveTo(spawnPos)
	elseif player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.CFrame = CFrame.new(spawnPos)
	end

	-- Fire event: player entered lobby
	self:FireCallback("PlayerEnteredLobby", {
		player = player
	})

	-- Notify client to update chunks (via EventManager if provided)
	if eventManager then
		eventManager:FireEvent("PlayerTeleported", player, {
			location = "lobby",
			position = spawnPos
		})
	end

	print(string.format("TeleportService: %s teleported to lobby", player.Name))
	return true
end

-- Teleport player to world
function TeleportService:TeleportToWorld(player: Player, worldId: string, eventManager, worldDataStore)
	if not player or not player.Character then
		return false, "invalid_player"
	end

	if not worldId then
		return false, "invalid_world_id"
	end

	-- Load world metadata to check permissions
	local worldMetadata = nil
	if worldDataStore then
		worldMetadata = worldDataStore:GetWorldMetadata(worldId)
		if not worldMetadata then
			-- Try to get from active world
			local world = self.worldInstanceManager:GetWorldById(worldId)
			if world then
				worldMetadata = world.metadata
			end
		end
	end

	-- Check permissions
	if self.worldPermissions and worldMetadata then
		local canJoin = self.worldPermissions:CanJoinWorld(worldId, player.UserId, worldMetadata)
		if not canJoin then
			return false, "no_permission"
		end
	end

	-- Remove from lobby if in lobby
	local currentLocation = self:GetPlayerLocation(player)
	if currentLocation.location == "lobby" then
		self.lobbyManager:RemovePlayer(player)
	elseif currentLocation.worldId and currentLocation.worldId ~= worldId then
		-- Remove from different world
		local oldWorld = self.worldInstanceManager:GetWorldById(currentLocation.worldId)
		if oldWorld then
			oldWorld:RemovePlayer(player)
		end
		self.worldInstanceManager:RemovePlayerFromWorld(currentLocation.worldId, player)
	end

	-- Load world if not already loaded
	local world, err = self.worldInstanceManager:GetWorld(worldId, worldMetadata)
	if not world then
		return false, err or "failed_to_load_world"
	end

	-- Add player to world
	local success, reason = self.worldInstanceManager:AddPlayerToWorld(worldId, player, worldMetadata)
	if not success then
		return false, reason
	end

	-- Update location
	self.playerLocations[player] = {
		location = "world",
		worldId = worldId
	}

	-- Move character to world spawn
	local spawnPos = world:GetSpawnPosition()
	if player.Character and player.Character.PrimaryPart then
		player.Character:MoveTo(spawnPos)
	elseif player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		player.Character.HumanoidRootPart.CFrame = CFrame.new(spawnPos)
	end

	-- Fire event: player entered world
	self:FireCallback("PlayerEnteredWorld", {
		player = player,
		worldId = worldId
	})

	-- Notify client to update chunks (via EventManager if provided)
	if eventManager then
		eventManager:FireEvent("PlayerTeleported", player, {
			location = "world",
			worldId = worldId,
			position = spawnPos
		})
	end

	print(string.format("TeleportService: %s teleported to world %s", player.Name, worldId))
	return true
end

-- Handle player join (spawn in lobby)
function TeleportService:OnPlayerJoin(player: Player, eventManager)
	-- Set initial location
	self.playerLocations[player] = {
		location = "lobby",
		worldId = nil
	}

	-- Add to lobby
	self.lobbyManager:AddPlayer(player)

	-- Teleport to lobby spawn
	task.wait(0.5) -- Wait for character to load
	self:TeleportToLobby(player, eventManager)
end

-- Handle player leave
function TeleportService:OnPlayerLeave(player: Player)
	local currentLocation = self:GetPlayerLocation(player)

	-- Remove from current location
	if currentLocation.location == "lobby" then
		self.lobbyManager:RemovePlayer(player)
	elseif currentLocation.worldId then
		local world = self.worldInstanceManager:GetWorldById(currentLocation.worldId)
		if world then
			world:RemovePlayer(player)
		end
		self.worldInstanceManager:RemovePlayerFromWorld(currentLocation.worldId, player)
	end

	-- Clear location data
	self.playerLocations[player] = nil
end

-- Register callback
function TeleportService:RegisterCallback(eventName: string, callback: (any) -> ())
	if not self.teleportCallbacks[eventName] then
		self.teleportCallbacks[eventName] = {}
	end
	table.insert(self.teleportCallbacks[eventName], callback)
end

-- Fire callback
function TeleportService:FireCallback(eventName: string, data: any)
	if self.teleportCallbacks[eventName] then
		for _, callback in ipairs(self.teleportCallbacks[eventName]) do
			task.spawn(callback, data)
		end
	end
end

-- Check if player is in lobby
function TeleportService:IsInLobby(player: Player): boolean
	local location = self:GetPlayerLocation(player)
	return location.location == "lobby"
end

-- Check if player is in world
function TeleportService:IsInWorld(player: Player, worldId: string?): boolean
	local location = self:GetPlayerLocation(player)
	if worldId then
		return location.location == "world" and location.worldId == worldId
	end
	return location.location == "world"
end

-- Get current world ID for player
function TeleportService:GetPlayerWorldId(player: Player): string?
	local location = self:GetPlayerLocation(player)
	return location.worldId
end

return TeleportService

