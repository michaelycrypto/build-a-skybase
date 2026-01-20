--[[
	HungerService.lua
	Manages hunger and saturation tracking, depletion, health regeneration, and starvation.
	Optimized for performance and reliability.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local FoodConfig = require(ReplicatedStorage.Shared.FoodConfig)

local HungerService = setmetatable({}, BaseService)
HungerService.__index = HungerService

-- Constants
local MAX_DELTA_TIME = 1.0 -- Max delta time to prevent lag spike issues
local ACTIVITY_COOLDOWN = 0.1 -- Cooldown between activity recordings (prevents spam)
local SPRINT_WALKSPEED_THRESHOLD = 18 -- WalkSpeed >= 18 is sprinting (sprint is 20, walk is 14)
local NORMAL_WALKSPEED_THRESHOLD = 14 -- Normal walk speed
local MOVEMENT_CHECK_INTERVAL = 0.1 -- Check movement every 0.1 seconds (more responsive)
local MIN_MOVEMENT_DISTANCE = 0.05 -- Minimum distance moved to be considered moving (studs) - lowered for better detection
local DEPLETION_ACCUMULATION_THRESHOLD = 0.0005 -- Accumulate depletions until >= 0.0005 before applying (very responsive)

function HungerService.new()
	local self = setmetatable(BaseService.new(), HungerService)

	self._logger = Logger:CreateContext("HungerService")
	self._playerStates = {} -- {[player] = {lastJumpTime, lastMineTime, lastAttackTime, lastHealthRegen, lastStarvation, stateChangedConnection, characterAddedConnection, lastPosition, lastPositionTime, accumulatedDepletion, isMoving, isSprinting}}
	self._lastUpdate = 0

	-- Cache FoodConfig values for performance
	self._depletionRates = nil
	self._healthRegenConfig = nil
	self._starvationConfig = nil

	return self
end

function HungerService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)

	-- Cache FoodConfig values for performance
	if FoodConfig and FoodConfig.HungerDepletion then
		self._depletionRates = FoodConfig.HungerDepletion
	else
		self._logger.Error("FoodConfig.HungerDepletion is missing!")
		self._depletionRates = {
			walking = 0.01,
			sprinting = 0.1,
			jumping = 0.05,
			swimming = 0.015,
			mining = 0.005,
			attacking = 0.1
		}
	end

	if FoodConfig and FoodConfig.HealthRegen then
		self._healthRegenConfig = FoodConfig.HealthRegen
	else
		self._healthRegenConfig = {
			minHunger = 18,
			minSaturation = 0.1,
			healAmount = 1,
			healInterval = 0.5
		}
	end

	if FoodConfig and FoodConfig.Starvation then
		self._starvationConfig = FoodConfig.Starvation
	else
		self._starvationConfig = {
			damageThreshold = 6,
			damageAmount = 1,
			damageInterval = 4
		}
	end

	self._logger.Debug("HungerService initialized")
end

function HungerService:Start()
	if self._started then
		return
	end

	-- Connect to player events FIRST (before checking existing players)
	-- This ensures we catch players who join during initialization
	-- Store connections for cleanup
	self._playerAddedConnection = Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		self:OnPlayerRemoving(player)
	end)

	-- Initialize existing players (after connections are set up)
	for _, player in ipairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	-- Initialize last update time before starting loop
	self._lastUpdate = os.clock()

	-- Start update loop
	self._updateConnection = RunService.Heartbeat:Connect(function()
		self:_update()
	end)

	BaseService.Start(self)
	self._logger.Debug("HungerService started", {
		updateLoopConnected = self._updateConnection ~= nil,
		initialPlayers = #Players:GetPlayers(),
		walkingRate = FoodConfig.HungerDepletion.walking,
		sprintingRate = FoodConfig.HungerDepletion.sprinting,
		jumpingRate = FoodConfig.HungerDepletion.jumping
	})
end

function HungerService:Destroy()
	if self._destroyed then
		return
	end

	-- Clean up update loop
	if self._updateConnection then
		self._updateConnection:Disconnect()
		self._updateConnection = nil
	end

	-- Clean up player event connections
	if self._playerAddedConnection then
		self._playerAddedConnection:Disconnect()
		self._playerAddedConnection = nil
	end

	if self._playerRemovingConnection then
		self._playerRemovingConnection:Disconnect()
		self._playerRemovingConnection = nil
	end

	-- Clean up all player states and their connections
	for player, state in pairs(self._playerStates) do
		if state.stateChangedConnection then
			state.stateChangedConnection:Disconnect()
		end
		if state.characterAddedConnection then
			state.characterAddedConnection:Disconnect()
		end
	end

	self._playerStates = {}

	BaseService.Destroy(self)
	self._logger.Info("HungerService destroyed")
end

--[[
	Handle player joining
--]]
function HungerService:OnPlayerAdded(player)
	self._logger.Debug("OnPlayerAdded called for", player.Name)

	if not self.Deps.PlayerService then
		self._logger.Warn("PlayerService not available, cannot initialize hunger for", player.Name)
		return
	end

	-- Initialize player state
	local state = {
		-- Activity cooldowns
		lastJumpTime = 0,
		lastMineTime = 0,
		lastAttackTime = 0,
		-- Health/starvation timers
		lastHealthRegen = 0,
		lastStarvation = 0,
		-- Event connections
		stateChangedConnection = nil, -- For jump detection via StateChanged event
		characterAddedConnection = nil,
		-- Movement tracking for accurate depletion detection
		lastPosition = nil,
		lastPositionTime = 0,
		accumulatedDepletion = 0, -- Accumulate small depletions until threshold reached
		isMoving = false,
		isSprinting = false
	}
	self._playerStates[player] = state

	-- Initialize hunger/saturation if not set
	local hunger = self.Deps.PlayerService:GetHunger(player)
	local saturation = self.Deps.PlayerService:GetSaturation(player)

	-- Ensure hunger/saturation are initialized (default to 20 if not set)
	if hunger == nil or hunger < 0 then
		hunger = 20
		self.Deps.PlayerService:SetHunger(player, hunger)
	end
	if saturation == nil or saturation < 0 then
		saturation = 20
		self.Deps.PlayerService:SetSaturation(player, saturation)
	end

	-- Sync to client after a short delay to ensure client is ready (non-blocking)
	task.spawn(function()
		task.wait(0.5)
		self:_syncHungerToClient(player, hunger, saturation)
	end)

	-- Set up jump detection for initial character
	if player.Character then
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			-- Initialize position tracking
			local state = self._playerStates[player]
			if state then
				state.lastPosition = rootPart.Position
				state.lastPositionTime = os.clock()
			end
		end
		self:_setupJumpDetection(player, player.Character)
	end

	-- Set up jump detection for character respawns (store connection for cleanup)
	state.characterAddedConnection = player.CharacterAdded:Connect(function(character)
		-- Safety check: ensure player still exists and state is valid
		if not self._playerStates[player] or not player.Parent then
			return
		end

		-- Reset movement tracking on respawn
		local respawnState = self._playerStates[player]
		if respawnState then
			respawnState.lastPosition = nil
			respawnState.lastPositionTime = 0
			respawnState.accumulatedDepletion = 0
			respawnState.isMoving = false
			respawnState.isSprinting = false
		end

		self:_setupJumpDetection(player, character)

		-- Initialize position tracking after character loads
		task.spawn(function()
			-- Additional safety check after wait
			if not self._playerStates[player] or not player.Parent then
				return
			end
			task.wait(0.5) -- Wait for character to fully load
			-- Final safety check before syncing
			if not self._playerStates[player] or not player.Parent then
				return
			end

			-- Initialize position tracking
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart and self._playerStates[player] then
				local respawnState = self._playerStates[player]
				respawnState.lastPosition = rootPart.Position
				respawnState.lastPositionTime = os.clock()
			end

			local hunger = self.Deps.PlayerService:GetHunger(player)
			local saturation = self.Deps.PlayerService:GetSaturation(player)
			self:_syncHungerToClient(player, hunger, saturation)
		end)
	end)

	self._logger.Debug("Initialized hunger for player", {playerName = player.Name, hunger = hunger, saturation = saturation})
end

--[[
	Handle player leaving
--]]
function HungerService:OnPlayerRemoving(player)
	local state = self._playerStates[player]
	if state then
		-- Clean up jump detection connection
		if state.stateChangedConnection then
			state.stateChangedConnection:Disconnect()
			state.stateChangedConnection = nil
		end
		-- Clean up CharacterAdded connection
		if state.characterAddedConnection then
			state.characterAddedConnection:Disconnect()
			state.characterAddedConnection = nil
		end
	end
	self._playerStates[player] = nil
end

--[[
	Main update loop - handles hunger depletion, health regen, and starvation
--]]
function HungerService:_update()
	local now = os.clock()
	local deltaTime = now - self._lastUpdate
	self._lastUpdate = now

	-- Clamp deltaTime to prevent huge values on first frame or lag spikes
	deltaTime = math.min(deltaTime, MAX_DELTA_TIME)

	-- Update each player
	for player, state in pairs(self._playerStates) do
		-- Clean up if player left (properly disconnect connections)
		if not player.Parent then
			if state.stateChangedConnection then
				state.stateChangedConnection:Disconnect()
				state.stateChangedConnection = nil
			end
			if state.characterAddedConnection then
				state.characterAddedConnection:Disconnect()
				state.characterAddedConnection = nil
			end
			self._playerStates[player] = nil
			continue
		end

		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		-- Update hunger depletion
		self:_updateHungerDepletion(player, state, deltaTime)

		-- Update health regeneration
		self:_updateHealthRegeneration(player, state, now)

		-- Update starvation damage
		self:_updateStarvation(player, state, now)
	end
end

--[[
	Update hunger depletion based on player activity
	Uses velocity for immediate movement detection, position tracking for verification
--]]
function HungerService:_updateHungerDepletion(player, state, deltaTime)
	if not self.Deps.PlayerService then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return
	end

	local currentHunger = self.Deps.PlayerService:GetHunger(player)
	local currentSaturation = self.Deps.PlayerService:GetSaturation(player)

	-- If both are at 0, no need to deplete
	if currentHunger <= 0 and currentSaturation <= 0 then
		return
	end

	local now = os.clock()
	local currentPosition = rootPart.Position

	-- Initialize position if not set (first check)
	if not state.lastPosition then
		state.lastPosition = currentPosition
		state.lastPositionTime = now
		state.isMoving = false
		state.isSprinting = false
		-- Don't return - allow velocity-based detection to work immediately
	end

	-- Use velocity for immediate movement detection (primary method)
	local velocity = rootPart.AssemblyLinearVelocity
	local horizontalVelocity = math.sqrt(velocity.X * velocity.X + velocity.Z * velocity.Z)
	local isMovingByVelocity = horizontalVelocity > 0.5 -- Moving if velocity > 0.5 studs/sec

	-- Determine sprinting from WalkSpeed (most reliable)
	local walkSpeed = humanoid.WalkSpeed
	local isSprintingByWalkSpeed = walkSpeed >= SPRINT_WALKSPEED_THRESHOLD

	-- Check movement using position tracking (verification and fallback)
	local timeSinceLastCheck = state.lastPositionTime > 0 and (now - state.lastPositionTime) or MOVEMENT_CHECK_INTERVAL
	local isMoving = false
	local isSprinting = false

	if timeSinceLastCheck >= MOVEMENT_CHECK_INTERVAL and state.lastPosition then
		-- Calculate horizontal distance moved
		local deltaX = currentPosition.X - state.lastPosition.X
		local deltaZ = currentPosition.Z - state.lastPosition.Z
		local horizontalDistance = math.sqrt(deltaX * deltaX + deltaZ * deltaZ)

		-- Check if player actually moved (ignoring vertical movement)
		local isMovingByPosition = horizontalDistance >= MIN_MOVEMENT_DISTANCE

		-- Use position-based detection as primary, velocity as fallback
		if isMovingByPosition then
			isMoving = true
			isSprinting = isSprintingByWalkSpeed

			-- Calculate movement speed for verification (studs per second)
			local movementSpeed = horizontalDistance / timeSinceLastCheck

			-- Fallback: If WalkSpeed replication is delayed, use movement speed
			-- Sprint speed is ~20 studs/sec, walk speed is ~14 studs/sec
			if not isSprinting and walkSpeed > NORMAL_WALKSPEED_THRESHOLD and movementSpeed > 16 then
				isSprinting = true
			end
		elseif isMovingByVelocity then
			-- Position check says not moving, but velocity says moving - trust velocity
			-- This handles cases where player just started moving
			isMoving = true
			isSprinting = isSprintingByWalkSpeed or horizontalVelocity > 16
		else
			-- Player is not moving
			isMoving = false
			isSprinting = false
		end

		-- Update position tracking
		state.lastPosition = currentPosition
		state.lastPositionTime = now
		state.isMoving = isMoving
		state.isSprinting = isSprinting
	else
		-- Use cached movement state between checks, but verify with velocity
		-- If lastPosition is nil (first frame), use velocity-based detection
		if not state.lastPosition then
			-- First frame - use velocity to detect movement
			isMoving = isMovingByVelocity
			isSprinting = isSprintingByWalkSpeed or (isMoving and horizontalVelocity > 16)
			-- Initialize position for next check
			state.lastPosition = currentPosition
			state.lastPositionTime = now
		else
			-- Use cached state, but verify with velocity
			isMoving = state.isMoving
			isSprinting = state.isSprinting

			-- If velocity indicates movement but cached state says not moving, update immediately
			-- This handles cases where position check hasn't happened yet
			if isMovingByVelocity and not isMoving then
				isMoving = true
				isSprinting = isSprintingByWalkSpeed or horizontalVelocity > 16
			elseif not isMovingByVelocity and isMoving then
				-- Velocity says not moving - trust it (player stopped)
				isMoving = false
				isSprinting = false
			elseif isMoving then
				-- Update sprinting state from WalkSpeed even if already moving
				isSprinting = isSprintingByWalkSpeed
			end
		end
	end

	-- Calculate depletion based on movement state
	local depletion = 0
	if isMoving then
		if isSprinting then
			depletion = self._depletionRates.sprinting * deltaTime
		else
			depletion = self._depletionRates.walking * deltaTime
		end
	end

	-- Accumulate small depletions to avoid threshold issues
	if depletion > 0 then
		state.accumulatedDepletion = state.accumulatedDepletion + depletion
	end

	-- Only apply depletion when accumulated amount is significant enough
	if state.accumulatedDepletion >= DEPLETION_ACCUMULATION_THRESHOLD then
		local totalDepletion = state.accumulatedDepletion
		state.accumulatedDepletion = 0 -- Reset accumulator

		-- Apply depletion: saturation depletes first, then hunger
		-- This is the correct Minecraft behavior
		local saturationDepletion = math.min(totalDepletion, currentSaturation)
		local remainingDepletion = totalDepletion - saturationDepletion
		local hungerDepletion = math.min(remainingDepletion, currentHunger)

		local newSaturation = math.max(0, currentSaturation - saturationDepletion)
		local newHunger = math.max(0, currentHunger - hungerDepletion)

		-- Update values if they changed
		if newSaturation ~= currentSaturation then
			self.Deps.PlayerService:SetSaturation(player, newSaturation)
		end
		if newHunger ~= currentHunger then
			self.Deps.PlayerService:SetHunger(player, newHunger)
		end

		-- Sync to client when values change
		if newSaturation ~= currentSaturation or newHunger ~= currentHunger then
			self:_syncHungerToClient(player, newHunger, newSaturation)
		end
	end
end

--[[
	Update health regeneration (when hunger >= 18 and saturation > 0)
--]]
function HungerService:_updateHealthRegeneration(player, state, now)
	if not self.Deps.PlayerService or not self.Deps.DamageService then
		return
	end

	local hunger = self.Deps.PlayerService:GetHunger(player)
	local saturation = self.Deps.PlayerService:GetSaturation(player)

	-- Check if conditions are met
	if hunger < self._healthRegenConfig.minHunger or saturation < self._healthRegenConfig.minSaturation then
		return
	end

	-- Check cooldown
	if (now - state.lastHealthRegen) < self._healthRegenConfig.healInterval then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Heal player
	if humanoid.Health < humanoid.MaxHealth then
		self.Deps.DamageService:HealPlayer(player, self._healthRegenConfig.healAmount)
		state.lastHealthRegen = now
	end
end

--[[
	Update starvation damage (when hunger < 6)
--]]
function HungerService:_updateStarvation(player, state, now)
	if not self.Deps.PlayerService or not self.Deps.DamageService then
		return
	end

	local hunger = self.Deps.PlayerService:GetHunger(player)

	-- Check if starvation threshold is met
	if hunger >= self._starvationConfig.damageThreshold then
		return
	end

	-- Check cooldown
	if (now - state.lastStarvation) < self._starvationConfig.damageInterval then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Apply starvation damage
	self.Deps.DamageService:DamagePlayer(player, self._starvationConfig.damageAmount, self.Deps.DamageService.DamageType.STARVATION)
	state.lastStarvation = now
end

--[[
	Sync hunger and saturation to client
--]]
function HungerService:_syncHungerToClient(player, hunger, saturation)
	if not EventManager then
		self._logger.Warn("EventManager not available, cannot sync hunger to client")
		return
	end

	-- Ensure event is registered
	if not EventManager._events or not EventManager._events["PlayerHungerChanged"] then
		self._logger.Warn("PlayerHungerChanged event not registered, attempting to register...")
		EventManager:RegisterEvent("PlayerHungerChanged", function() end)
	end

	local success, err = pcall(function()
		EventManager:FireEvent("PlayerHungerChanged", player, {
			hunger = hunger,
			saturation = saturation
		})
	end)

	if not success then
		self._logger.Error("Failed to fire PlayerHungerChanged event", {
			error = tostring(err),
			player = player.Name,
			hunger = hunger,
			saturation = saturation
		})
	end
end

--[[
	Manually sync hunger to client (called externally)
--]]
function HungerService:SyncHungerToClient(player)
	if not self.Deps.PlayerService then
		return
	end

	local hunger = self.Deps.PlayerService:GetHunger(player)
	local saturation = self.Deps.PlayerService:GetSaturation(player)
	self:_syncHungerToClient(player, hunger, saturation)
end

--[[
	Set up jump detection for a character
	Uses StateChanged event for better performance than Heartbeat polling
--]]
function HungerService:_setupJumpDetection(player, character)
	local state = self._playerStates[player]
	if not state then
		return
	end

	-- Clean up existing connection if any
	if state.stateChangedConnection then
		state.stateChangedConnection:Disconnect()
		state.stateChangedConnection = nil
	end

	-- Wait for humanoid
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		self._logger.Warn("Failed to find Humanoid for jump detection", player.Name)
		return
	end

	-- Use StateChanged event for jump detection (more efficient than Heartbeat polling)
	local connection = humanoid.StateChanged:Connect(function(oldState, newState)
		-- Safety checks: ensure player, state, character, and humanoid still exist
		if not self._playerStates[player] or not player.Parent then
			connection:Disconnect()
			if state and state.stateChangedConnection == connection then
				state.stateChangedConnection = nil
			end
			return
		end

		-- Check if character or humanoid was removed
		if not character.Parent or not humanoid.Parent then
			connection:Disconnect()
			if state and state.stateChangedConnection == connection then
				state.stateChangedConnection = nil
			end
			return
		end

		-- Detect jump start (transition to Jumping state)
		if newState == Enum.HumanoidStateType.Jumping then
			-- Final safety check before recording activity
			if self._playerStates[player] and player.Parent then
				self:RecordActivity(player, "jump")
			end
		end
	end)
	state.stateChangedConnection = connection
end

--[[
	Record activity for hunger depletion (called by other services)
--]]
function HungerService:RecordActivity(player, activityType)
	local state = self._playerStates[player]
	if not state then
		return
	end

	local now = os.clock()
	local depletion = 0

	if activityType == "jump" then
		-- Prevent double-counting jumps
		if (now - state.lastJumpTime) > ACTIVITY_COOLDOWN then
			depletion = self._depletionRates.jumping
			state.lastJumpTime = now
		end
	elseif activityType == "mine" then
		-- Prevent double-counting mining
		if (now - state.lastMineTime) > ACTIVITY_COOLDOWN then
			depletion = self._depletionRates.mining
			state.lastMineTime = now
		end
	elseif activityType == "attack" then
		-- Prevent double-counting attacks
		if (now - state.lastAttackTime) > ACTIVITY_COOLDOWN then
			depletion = self._depletionRates.attacking
			state.lastAttackTime = now
		end
	end

	if depletion > 0 and self.Deps.PlayerService then
		local currentSaturation = self.Deps.PlayerService:GetSaturation(player)
		local currentHunger = self.Deps.PlayerService:GetHunger(player)

		-- If both are at 0, no need to deplete
		if currentHunger <= 0 and currentSaturation <= 0 then
			return
		end

		-- Apply depletion: saturation depletes first, then hunger
		-- This matches Minecraft behavior exactly
		local saturationDepletion = math.min(depletion, currentSaturation)
		local remainingDepletion = depletion - saturationDepletion
		local hungerDepletion = math.min(remainingDepletion, currentHunger)

		local newSaturation = math.max(0, currentSaturation - saturationDepletion)
		local newHunger = math.max(0, currentHunger - hungerDepletion)

		-- Update values if they changed
		if newSaturation ~= currentSaturation then
			self.Deps.PlayerService:SetSaturation(player, newSaturation)
		end
		if newHunger ~= currentHunger then
			self.Deps.PlayerService:SetHunger(player, newHunger)
		end

		-- Sync to client when values change
		if newSaturation ~= currentSaturation or newHunger ~= currentHunger then
			self:_syncHungerToClient(player, newHunger, newSaturation)
		end
	end
end

return HungerService
