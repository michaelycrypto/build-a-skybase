--[[
	LoadingProtectionService.lua

	Protects players during initial game loading by:
	- Making them invulnerable (ForceField)
	- Anchoring their HumanoidRootPart to prevent falling
	- Waiting for client to signal ready before allowing gameplay

	This prevents deaths during loading screen when chunks aren't rendered yet.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = require(script.Parent.BaseService)
local Logger = require(game.ReplicatedStorage.Shared.Logger)
local EventManager = require(game.ReplicatedStorage.Shared.EventManager)

local LoadingProtectionService = setmetatable({}, {__index = BaseService})
LoadingProtectionService.__index = LoadingProtectionService

-- Configuration
local LOADING_TIMEOUT = 60  -- Max seconds to wait for client ready
local TIMEOUT_CHECK_INTERVAL = 5  -- How often to check for timeouts (seconds)

function LoadingProtectionService.new()
	local self = setmetatable(BaseService.new(), LoadingProtectionService)

	self._logger = Logger:CreateContext("LoadingProtection")
	self._loadingPlayers = {}  -- [Player] = { protected = bool, startTime = number, connections = {} }
	self._connections = {}

	return self
end

function LoadingProtectionService:Init()
	if self._initialized then return end
	BaseService.Init(self)

	self._logger.Debug("LoadingProtectionService initialized")
end

function LoadingProtectionService:Start()
	if self._started then return end
	BaseService.Start(self)
	self._logger.Debug("LoadingProtectionService started")

	-- Handle existing players
	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayerAdded(player)
	end

	-- Handle new players
	self._connections.PlayerAdded = Players.PlayerAdded:Connect(function(player)
		self:_onPlayerAdded(player)
	end)

	-- Handle players leaving
	self._connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		self:_onPlayerRemoving(player)
	end)

	-- Register client loading complete event handler
	-- This fires AFTER loading screen completes and assets are loaded
	EventManager:RegisterEvent("ClientLoadingComplete", function(player)
		self:OnClientReady(player)
	end)

	-- Also listen for legacy ClientReady as fallback (in case ClientLoadingComplete fails)
	EventManager:RegisterEvent("ClientReady", function(player)
		-- Don't immediately remove protection - this fires too early
		-- Just log that we received it
		self._logger.Debug("ClientReady received (early signal)", { player = player.Name })
	end)

	-- Timeout checker (runs periodically to catch clients that never signal ready)
	self._lastTimeoutCheck = 0
	self._connections.TimeoutChecker = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self._lastTimeoutCheck >= TIMEOUT_CHECK_INTERVAL then
			self._lastTimeoutCheck = now
			self:_checkTimeouts()
		end
	end)

	self._logger.Info("LoadingProtectionService started")
end

--[[
	Called when a player joins - begin protection
--]]
function LoadingProtectionService:_onPlayerAdded(player)
	local state = {
		protected = false,
		startTime = os.clock(),
		connections = {},
		forceField = nil,
	}
	self._loadingPlayers[player] = state

	-- Protect character when it spawns
	local function onCharacterAdded(character)
		if not self._loadingPlayers[player] then return end
		self:_applyProtection(player, character)
	end

	state.connections.CharacterAdded = player.CharacterAdded:Connect(onCharacterAdded)

	-- Also handle existing character
	if player.Character then
		onCharacterAdded(player.Character)
	end

	self._logger.Debug("Loading protection started", { player = player.Name })
end

--[[
	Called when a player leaves - cleanup
--]]
function LoadingProtectionService:_onPlayerRemoving(player)
	local state = self._loadingPlayers[player]
	if not state then return end

	-- Cleanup connections
	for _, conn in pairs(state.connections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end

	-- Remove forcefield if exists
	if state.forceField then
		state.forceField:Destroy()
	end

	self._loadingPlayers[player] = nil
end

--[[
	Apply protection to a character
--]]
function LoadingProtectionService:_applyProtection(player, character)
	local state = self._loadingPlayers[player]
	if not state then return end

	-- IMMEDIATELY try to anchor the character to prevent falling (no yielding)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart then
		rootPart.Anchored = true
	end

	-- Create ForceField immediately (doesn't require waiting)
	local forceField = Instance.new("ForceField")
	forceField.Name = "LoadingProtection"
	forceField.Visible = false  -- Invisible protection
	forceField.Parent = character
	state.forceField = forceField

	-- Now wait for parts if we didn't find them immediately
	-- This runs in a separate thread to not block other initialization
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 5)
		rootPart = rootPart or character:WaitForChild("HumanoidRootPart", 5)

		if not humanoid or not rootPart then
			self._logger.Warn("Failed to apply full protection - missing parts", { player = player.Name })
			return
		end

		-- Re-verify state (player might have left during wait)
		if not self._loadingPlayers[player] then return end

		-- Ensure still anchored (in case it was briefly unanchored)
		rootPart.Anchored = true

		-- Make invulnerable by setting health to max when damaged
		state.connections.HealthChanged = humanoid.HealthChanged:Connect(function(newHealth)
			if self._loadingPlayers[player] and newHealth < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end)

		-- Also immediately restore health if damaged
		if humanoid.Health < humanoid.MaxHealth then
			humanoid.Health = humanoid.MaxHealth
		end

		-- Prevent death during loading
		state.connections.Died = humanoid.Died:Connect(function()
			-- If they somehow died during protection, they should respawn protected again
			if self._loadingPlayers[player] then
				self._logger.Debug("Player died during protection, will re-protect on respawn", { player = player.Name })
			end
		end)

		state.protected = true
		self._logger.Debug("Protection applied", { player = player.Name })
	end)
end

--[[
	Remove protection from a player (called when client signals ready)
--]]
function LoadingProtectionService:_removeProtection(player)
	local state = self._loadingPlayers[player]
	if not state then return end

	-- Disconnect health protection
	if state.connections.HealthChanged then
		state.connections.HealthChanged:Disconnect()
		state.connections.HealthChanged = nil
	end

	if state.connections.Died then
		state.connections.Died:Disconnect()
		state.connections.Died = nil
	end

	-- Remove forcefield
	if state.forceField then
		state.forceField:Destroy()
		state.forceField = nil
	end

	-- Unanchor the player
	local character = player.Character
	if character then
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.Anchored = false
		end
	end

	-- Keep CharacterAdded connection for future respawns during loading?
	-- No - once client is ready, they're ready for all respawns
	if state.connections.CharacterAdded then
		state.connections.CharacterAdded:Disconnect()
	end

	-- Remove from loading players
	self._loadingPlayers[player] = nil

	local loadTime = os.clock() - state.startTime
	self._logger.Debug("Protection removed - client ready", {
		player = player.Name,
		loadTime = string.format("%.2fs", loadTime)
	})
end

--[[
	Called when client signals it's ready to play
--]]
function LoadingProtectionService:OnClientReady(player)
	local state = self._loadingPlayers[player]
	if not state then
		-- Already removed or never tracked
		return
	end

	self:_removeProtection(player)
end

--[[
	Check for players who have been loading too long (timeout protection)
--]]
function LoadingProtectionService:_checkTimeouts()
	local now = os.clock()

	for player, state in pairs(self._loadingPlayers) do
		if now - state.startTime > LOADING_TIMEOUT then
			self._logger.Warn("Loading timeout - removing protection", {
				player = player.Name,
				elapsed = string.format("%.1fs", now - state.startTime)
			})
			self:_removeProtection(player)
		end
	end
end

--[[
	Check if a player is still in loading protection
--]]
function LoadingProtectionService:IsPlayerLoading(player)
	return self._loadingPlayers[player] ~= nil
end

--[[
	Get loading elapsed time for a player
--]]
function LoadingProtectionService:GetLoadingTime(player)
	local state = self._loadingPlayers[player]
	if not state then return 0 end
	return os.clock() - state.startTime
end

function LoadingProtectionService:Destroy()
	if self._destroyed then return end

	-- Cleanup all connections
	for _, conn in pairs(self._connections) do
		if conn and typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end

	-- Remove protection from all players
	for player in pairs(self._loadingPlayers) do
		self:_removeProtection(player)
	end

	BaseService.Destroy(self)
end

return LoadingProtectionService
