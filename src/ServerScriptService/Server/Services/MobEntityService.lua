--[[
	MobEntityService.lua

	Primary server-side coordinator for the mob entity system. Tracks all live mobs,
	spawns/despawns them based on chunk activity, runs lightweight AI, and replicates
	state updates to clients. Persistence is handled by serialising mob state back
	into world data when chunks unload or when the world saves.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local MobRegistry = require(ReplicatedStorage.Configs.MobRegistry)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local MinionConfig = require(ReplicatedStorage.Configs.MinionConfig)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)
local _BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)  -- Preloaded for cache
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local _AdvancedPathfinding = require(ReplicatedStorage.Shared.Pathfinding.AdvancedPathfinding)  -- Preloaded for cache
local Navigator = require(ReplicatedStorage.Shared.Pathfinding.Navigator)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)

local MobEntityService = setmetatable({}, BaseService)
MobEntityService.__index = MobEntityService

local BLOCK_SIZE = Constants.BLOCK_SIZE
local CHUNK_STUD_SIZE_X = Constants.CHUNK_SIZE_X * BLOCK_SIZE
local CHUNK_STUD_SIZE_Z = Constants.CHUNK_SIZE_Z * BLOCK_SIZE

-- Forward declarations for helpers used across functions
local isPassableForMobs
local isSolidForMobs

local function chunkKey(cx, cz)
	return string.format("%d,%d", cx, cz)
end

local function worldPositionToChunk(pos)
	local cx = math.floor(pos.X / CHUNK_STUD_SIZE_X)
	local cz = math.floor(pos.Z / CHUNK_STUD_SIZE_Z)
	return cx, cz
end

local function shallowCopy(dict)
	return table.clone(dict)
end

local function vectorToArray(vec)
	return { vec.X, vec.Y, vec.Z }
end

local function arrayToVector(arr, fallback)
	if not arr then
		return fallback or Vector3.new()
	end
	return Vector3.new(arr[1] or 0, arr[2] or 0, arr[3] or 0)
end

-- Lightweight debug helper (disabled by default)
local function Debug(self, message, data)
	if self._debugEnabled then
		self._logger.Debug(message, data)
	end
end

function MobEntityService.new()
	local self = setmetatable(BaseService.new(), MobEntityService)

	self.Name = "MobEntityService"
	self._logger = Logger:CreateContext("MobEntityService")
	self._worlds = {}
	self._pendingBroadcast = {}
	self._broadcastTimer = 0
	self._updateAccumulator = 0
	self._updateInterval = 0.1
	self._broadcastInterval = 0.25
	self._heartbeatConn = nil
	self._rng = Random.new()
	self._maxTurnRateDegPerSec = 110

	-- AI activation + scheduling (reduces server CPU while preserving nearby behavior)
	self._aiActiveDistance = 220 -- studs; activate when within this range
	self._aiInactiveDistance = 260 -- studs; deactivate when beyond this range (hysteresis)
	self._thinkIntervalActive = { min = 0.12, max = 0.18 } -- ~5-8 Hz when near players
	self._thinkIntervalInactive = { min = 0.9, max = 1.5 } -- ~0.7-1.1 Hz when far from players

	-- Networking budgets
	self._keepaliveInterval = 2.0 -- seconds between keepalives
	self._positionThreshold = 0.4 -- studs before sending an update
	self._rotationThreshold = 5 -- degrees before sending an update
	self._safeDropBlocks = 1 -- treat drops larger than this as dangerous edges
	self._maxStepDownBlocks = 8 -- allow descending multiple blocks at once
	self._emergencyDropBlocks = 8 -- maximum drop allowed in emergency step-down

	-- Movement tuning
	self._arriveRadius = 1.5 -- studs where we start slowing down when approaching a target
	self._maxAccel = 28.0 -- studs/sec^2 horizontal acceleration limit
	self._debugEnabled = true

    -- Navigation
    self._useAdvancedPathfinding = true

	-- Simple entity crowd repulsion (Minecraft-style jostling)
	self._entityRepulsionEnabled = true
	self._entityRepulsionPassiveOnly = false
	self._entityRepulsionRadius = BLOCK_SIZE * 0.85 -- fallback only; per-entity radii preferred
	self._entityRepulsionMaxPushPerSecond = BLOCK_SIZE * 1.0 -- ~1 block/sec

	return self
end

-- getNavigator is placed after movement helpers are defined to avoid forward reference issues

local function ensureWorldContext(self)
	local worldId = "default"
	if self.Deps and self.Deps.WorldOwnershipService then
		local ownerId = self.Deps.WorldOwnershipService:GetOwnerId()
		if ownerId then
			worldId = tostring(ownerId)
		end
	end

	local ctx = self._worlds[worldId]
	if not ctx then
		ctx = {
			id = worldId,
			nextMobId = 1,
			mobsById = {},
			mobsByChunk = {},
			persistedByChunk = {},
			caps = {
				PASSIVE = 0,
				HOSTILE = 0,
			}
		}
		self._worlds[worldId] = ctx
	end
	return ctx
end

local function registerMobToChunk(ctx, mob, cx, cz)
	local key = chunkKey(cx, cz)
	mob.chunkX, mob.chunkZ = cx, cz
	ctx.mobsByChunk[key] = ctx.mobsByChunk[key] or {}
	ctx.mobsByChunk[key][mob.entityId] = true
end

local function removeMobFromChunk(ctx, mob)
	if not mob.chunkX or not mob.chunkZ then
		return
	end
	local key = chunkKey(mob.chunkX, mob.chunkZ)
	local bucket = ctx.mobsByChunk[key]
	if bucket then
		bucket[mob.entityId] = nil
		if next(bucket) == nil then
			ctx.mobsByChunk[key] = nil
		end
	end
	mob.chunkX, mob.chunkZ = nil, nil
end

function MobEntityService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Info("Initialized")
end

function MobEntityService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)

	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		self:_onHeartbeat(dt)
	end)

	self._logger.Info("Started")
end

function MobEntityService:Destroy()
	if self._destroyed then
		return
	end

	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end

	self._worlds = {}
	self._pendingBroadcast = {}

	BaseService.Destroy(self)
	self._logger.Info("Destroyed")
end

function MobEntityService:_nextEntityId(ctx)
	local id = string.format("mob_%04d", ctx.nextMobId)
	ctx.nextMobId += 1
	return id
end

function MobEntityService:_broadcastSpawn(mob)
    -- Derive display state: force idle when not moving for passive mobs
    local hspeed = Vector3.new(mob.velocity.X, 0, mob.velocity.Z).Magnitude
    local stateOut = mob.state
    if mob.definition and mob.definition.category == MobRegistry.Categories.PASSIVE and hspeed < 0.05 then
        stateOut = "idle"
    end
    EventManager:FireEventToAll("MobSpawned", {
		entityId = mob.entityId,
		mobType = mob.mobType,
		position = vectorToArray(mob.position),
		rotation = mob.rotation,
		velocity = vectorToArray(mob.velocity),
		health = mob.health,
		maxHealth = mob.maxHealth,
		variant = mob.variant and mob.variant.id or nil,
		state = stateOut,
		-- server timestamp to assist client-side interpolation (optional)
		t = os.clock()
	})

	-- Initialize network last-sent snapshot to avoid immediate redundant update
	mob._netLast = {
		pos = mob.position,
		rot = mob.rotation,
		state = stateOut,
		health = mob.health,
		nextKeepAlive = os.clock() + (self._keepaliveInterval or 1.2)
	}
end

function MobEntityService:_queueUpdate(mob)
    local hspeed = Vector3.new(mob.velocity.X, 0, mob.velocity.Z).Magnitude
    local stateOut = mob.state
    if mob.definition and mob.definition.category == MobRegistry.Categories.PASSIVE and hspeed < 0.05 then
        stateOut = "idle"
    end

    local now = os.clock()
    local last = mob._netLast
    if not last then
        last = {
            pos = mob.position,
            rot = mob.rotation,
            state = stateOut,
            health = mob.health,
	            nextKeepAlive = now + (self._keepaliveInterval or 1.2)
        }
        mob._netLast = last
    end

    -- Only send if deltas exceed thresholds or on keepalive/state/health changes
	    local posDelta = (mob.position - last.pos).Magnitude
	    local rotDelta = math.abs((mob.rotation or 0) - (last.rot or 0))
    if rotDelta > 180 then
    	rotDelta = 360 - rotDelta
    end
    local stateChanged = stateOut ~= last.state
    local healthChanged = mob.health ~= last.health
		-- Adaptive thresholds by speed and viewer distance
		local dist = 1e6
		for _, player in ipairs(self:_playersInWorld()) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local dx = root.Position.X - mob.position.X
				local dz = root.Position.Z - mob.position.Z
				local d = math.sqrt(dx * dx + dz * dz)
				if d < dist then
					dist = d
				end
			end
		end
		local basePos = self._positionThreshold or 0.25
		local baseRot = self._rotationThreshold or 5
		local speedTerm = math.clamp(hspeed * 0.015, 0, 0.6)
		local farFactor = math.clamp((dist - 60) / 200, 0, 1) -- start relaxing beyond ~60 studs
		local posThreshold = basePos + speedTerm + farFactor * 0.6
		local rotThreshold = baseRot + farFactor * 8
	    local shouldSend = stateChanged or healthChanged or posDelta >= posThreshold or rotDelta >= rotThreshold or now >= (last.nextKeepAlive or 0)

    if not shouldSend then
        return
    end

    last.pos = mob.position
    last.rot = mob.rotation
    last.state = stateOut
    last.health = mob.health
	    last.nextKeepAlive = now + (self._keepaliveInterval or 1.2)

	self._pendingBroadcast[mob.entityId] = {
		entityId = mob.entityId,
		position = vectorToArray(mob.position),
		velocity = vectorToArray(mob.velocity),
		rotation = mob.rotation,
        state = stateOut,
		health = mob.health,
		maxHealth = mob.maxHealth,
		-- server timestamp to assist client-side interpolation (optional)
		t = now
	}
end

function MobEntityService:_calculateUpdatePriority(update, players)
	-- Base priority score (higher = more important)
	local priority = 0

	-- Get mob position
	local mobPos = Vector3.new(update.position[1], update.position[2], update.position[3])
	local mobVelocity = Vector3.new(update.velocity[1], update.velocity[2], update.velocity[3])
	local speed = Vector3.new(mobVelocity.X, 0, mobVelocity.Z).Magnitude

	-- Find closest player
	local closestDist = math.huge
	for _, player in ipairs(players) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local dist = (root.Position - mobPos).Magnitude
			if dist < closestDist then
				closestDist = dist
			end
		end
	end

	-- Distance-based priority (closer = higher priority)
	-- Priority ranges from 100 (very close) to 0 (far away)
	local distancePriority = math.max(0, 100 - closestDist * 2)
	priority = priority + distancePriority

	-- Speed-based priority (faster moving = higher priority)
	local speedPriority = math.min(50, speed * 20) -- Cap at 50 points
	priority = priority + speedPriority

	-- State change bonus (important state changes get priority boost)
	local importantStates = { "panic", "damaged", "death" }
	local statePriority = 0
	for _, importantState in ipairs(importantStates) do
		if update.state == importantState then
			statePriority = 30
			break
		end
	end
	priority = priority + statePriority

	-- Health change bonus (damage/healing is important)
	if update.health ~= update.maxHealth then
		priority = priority + 20
	end

	return priority
end

function MobEntityService:_flushUpdates()
	if next(self._pendingBroadcast) == nil then
		return
	end

	-- Calculate priorities and sort updates
	local updatesWithPriority = {}
	local players = self:_playersInWorld()

	for entityId, update in pairs(self._pendingBroadcast) do
		local priority = self:_calculateUpdatePriority(update, players)
		table.insert(updatesWithPriority, {
			update = update,
			priority = priority,
			entityId = entityId
		})
	end

	-- Sort by priority (highest first)
	table.sort(updatesWithPriority, function(a, b)
		return a.priority > b.priority
	end)

	-- Limit batch size to prevent network spam (keep top 50 highest priority updates)
	local maxBatchSize = 50
	local selectedUpdates = {}
	for i = 1, math.min(maxBatchSize, #updatesWithPriority) do
		selectedUpdates[i] = updatesWithPriority[i].update
	end

	-- If we had to drop updates, log it for debugging
	if #updatesWithPriority > maxBatchSize then
		Debug(self, "Dropped low-priority mob updates", {
			totalUpdates = #updatesWithPriority,
			sentUpdates = #selectedUpdates,
			droppedCount = #updatesWithPriority - #selectedUpdates
		})
	end

	local payload = {
		mobs = selectedUpdates
	}

	self._pendingBroadcast = {}
	EventManager:FireEventToAll("MobBatchUpdate", payload)
end

function MobEntityService:_broadcastDespawn(entityId)
	self._pendingBroadcast[entityId] = nil
	EventManager:FireEventToAll("MobDespawned", {
		entityId = entityId
	})
end

function MobEntityService:SpawnMob(mobType, position, options)
	local ctx = ensureWorldContext(self)
	local def = MobRegistry:GetDefinition(mobType)
	if not def then
		self._logger.Warn("Attempted to spawn unknown mob", { mobType = mobType })
		return nil
	end

	local entityId = self:_nextEntityId(ctx)
	local variant = options and options.variant or MobRegistry:GetRandomVariant(mobType, self._rng)

	local mob = {
		entityId = entityId,
		mobType = mobType,
		variant = variant,
		definition = def,
		health = def.maxHealth,
		maxHealth = def.maxHealth,
		position = position,
		spawnPosition = position,
		groundY = position.Y,
		velocity = Vector3.new(),
		rotation = self._rng:NextNumber(0, 360),  -- Random starting rotation
		isActive = true,
		state = "wander",  -- Start in wander state
		brain = {
			wanderTarget = nil,  -- Will be set on first update
			idleUntil = 0,  -- Not idle initially
			panicUntil = 0,  -- Timestamp when panic ends (after taking damage)
			panicTarget = nil,  -- Direction to run when panicking
			lookRotation = nil,  -- Look direction when idle
			nextLookChange = 0,  -- Next time to change look direction
			grazeUntil = 0,
			isFleeing = false,
			path = nil,  -- current path waypoints
			pathIndex = nil,
			pathTarget = nil,
			repathAt = 0,
			lastAttackTime = 0,
			targetPlayer = nil,
			nextThinkAt = os.clock() + self._rng:NextNumber(0, 0.2)
		},
		metadata = options and options.metadata or {},
		spawnChunk = { worldPositionToChunk(position) }
	}

	ctx.mobsById[entityId] = mob
	local cx, cz = worldPositionToChunk(position)
	registerMobToChunk(ctx, mob, cx, cz)
	self:_broadcastSpawn(mob)
	return mob
end

-- Client -> Server: Handle spawn egg usage to spawn a mob at target location
function MobEntityService:HandleSpawnEggUse(player, data)
	if not data or type(data) ~= "table" then
		return
	end
	local x, y, z = data.x, data.y, data.z
	local eggItemId = tonumber(data.eggItemId)
	local hotbarSlot = tonumber(data.hotbarSlot) or 1
	if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" or not eggItemId then
		return
	end
	if not SpawnEggConfig.IsSpawnEgg(eggItemId) then
		return
	end

	if not player or not player:IsDescendantOf(Players) then
		return
	end

	local eggInfo = SpawnEggConfig.GetEggInfo(eggItemId)
	if not eggInfo or not eggInfo.mobType then
		return
	end
	local mobType = eggInfo.mobType

	-- Compute target world position from block coordinates (center of cell, slightly above)
	-- Note: Uses file-scoped BLOCK_SIZE
	local worldPos = Vector3.new(
		x * BLOCK_SIZE + BLOCK_SIZE * 0.5,
		y * BLOCK_SIZE + BLOCK_SIZE * 0.75,
		z * BLOCK_SIZE + BLOCK_SIZE * 0.5
	)

	-- Reach validation similar to placement
	local character = player.Character
	if not character then
		return
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local distance = (worldPos - head.Position).Magnitude
	local maxReach = 4.5 * BLOCK_SIZE + 2
	if distance > maxReach then
		return
	end

	-- Basic collision check: prefer air at target, else try one block higher
	local vws = self.Deps and self.Deps.VoxelWorldService
	if vws and vws.worldManager then
		local atId = vws.worldManager:GetBlock(x, y, z)
		if atId and atId ~= Constants.BlockType.AIR then
			local aboveId = vws.worldManager:GetBlock(x, y + 1, z)
			if aboveId and aboveId ~= Constants.BlockType.AIR then
				return
			end
			worldPos = Vector3.new(
				x * BLOCK_SIZE + BLOCK_SIZE * 0.5,
				(y + 1) * BLOCK_SIZE + BLOCK_SIZE * 0.75,
				z * BLOCK_SIZE + BLOCK_SIZE * 0.5
			)
		end
	end

	-- Consume the egg from the specified hotbar slot
	if self.Deps and self.Deps.PlayerInventoryService then
		local inv = self.Deps.PlayerInventoryService
		if not inv:ConsumeFromHotbar(player, hotbarSlot, eggItemId) then
			return
		end
	end

	-- Spawn mob
	self:SpawnMob(mobType, worldPos, { metadata = { spawnedBy = player.UserId } })
end

function MobEntityService:DespawnMob(entityId, opts)
	local ctx = ensureWorldContext(self)
	local mob = ctx.mobsById[entityId]
	if not mob then
		return
	end

	removeMobFromChunk(ctx, mob)
	ctx.mobsById[entityId] = nil
	self:_broadcastDespawn(entityId)

	if opts and opts.persist then
		local key = chunkKey(mob.chunkX or mob.spawnChunk[1], mob.chunkZ or mob.spawnChunk[2])
		ctx.persistedByChunk[key] = ctx.persistedByChunk[key] or {}
		table.insert(ctx.persistedByChunk[key], MobRegistry:SerializeMob(mob))
	end
end

function MobEntityService:OnChunkLoaded(chunkX, chunkZ)
	local ctx = ensureWorldContext(self)
	local key = chunkKey(chunkX, chunkZ)
	local persisted = ctx.persistedByChunk[key]
	local hadPersisted = false
	if persisted then
		ctx.persistedByChunk[key] = nil
		for _, data in ipairs(persisted) do
			local position = arrayToVector(data.position, Vector3.new())
			self:SpawnMob(data.mobType, position, {
				variant = data.variant and { id = data.variant } or nil,
				metadata = data.metadata
			})
		end
		hadPersisted = true
	end

	self:_maybeSpawnNatural(ctx, chunkX, chunkZ, hadPersisted)
end

function MobEntityService:OnChunkUnloaded(chunkX, chunkZ)
	local ctx = ensureWorldContext(self)
	local key = chunkKey(chunkX, chunkZ)
	local bucket = ctx.mobsByChunk[key]
	if not bucket then
		return
	end

	ctx.persistedByChunk[key] = ctx.persistedByChunk[key] or {}

	for entityId in pairs(bucket) do
		local mob = ctx.mobsById[entityId]
		if mob then
			-- Do not persist minions; they are managed by VoxelWorldService minion state
			if mob.mobType ~= "COBBLE_MINION" then
				table.insert(ctx.persistedByChunk[key], MobRegistry:SerializeMob(mob))
			end
			ctx.mobsById[entityId] = nil
			self:_broadcastDespawn(entityId)
		end
	end

	ctx.mobsByChunk[key] = nil
end

function MobEntityService:OnWorldDataLoaded(worldData)
	if not worldData or not worldData.mobs then
		return
	end
	local ctx = ensureWorldContext(self)
	ctx.persistedByChunk = {}
	for _, mob in ipairs(worldData.mobs) do
		-- Ignore persisted minions; VoxelWorldService will respawn them from minion state
		if mob.mobType == "COBBLE_MINION" then
			continue
		end
		local key = chunkKey(mob.chunkX or 0, mob.chunkZ or 0)
		ctx.persistedByChunk[key] = ctx.persistedByChunk[key] or {}
		table.insert(ctx.persistedByChunk[key], shallowCopy(mob))
	end
	self._logger.Info("Loaded persisted mobs", { count = #worldData.mobs })
end

function MobEntityService:OnWorldDataSaving(worldData)
	local ctx = ensureWorldContext(self)
	local all = {}
	for _, mob in pairs(ctx.mobsById) do
		-- Skip minions; they are persisted separately in worldData.minions
		if mob.mobType ~= "COBBLE_MINION" then
			local serialized = MobRegistry:SerializeMob(mob)
			serialized.chunkX, serialized.chunkZ = worldPositionToChunk(mob.position)
			table.insert(all, serialized)
		end
	end
	for _, list in pairs(ctx.persistedByChunk) do
		for _, data in ipairs(list) do
			-- Historical data may include minions; skip them
			if data.mobType ~= "COBBLE_MINION" then
				table.insert(all, shallowCopy(data))
			end
		end
	end
	worldData.mobs = all
	self._logger.Info("Persisting mobs", { count = #all })
end

function MobEntityService:_playersInWorld()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(list, player)
		end
	end
	return list
end

-- Forward declaration for local function used inside _updateMob
local updateGroundY
local probeFootprint

-- Return squared horizontal distance (XZ) to the nearest player; math.huge if none
local function nearestPlayerDistanceSq(self, position)
	local best = math.huge
	for _, player in ipairs(self:_playersInWorld()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local dx = root.Position.X - position.X
			local dz = root.Position.Z - position.Z
			local d2 = dx * dx + dz * dz
			if d2 < best then
				best = d2
			end
		end
	end
	return best
end

function MobEntityService:_updateMob(ctx, mob, dt)
	local def = mob.definition
	local brain = mob.brain

	-- Stationary/Minion: keep fixed at spawn, no AI, no movement
	if mob.mobType == "COBBLE_MINION" or (mob.metadata and mob.metadata.stationary == true) then
		-- Simple minion brain: every ~15s place or mine on 5x5 platform beneath
		local now = os.clock()
		-- Determine interval from minion type and level
		-- Initialize per-context cooldown map for recently acted cells (persists across minion ticks)
		ctx._minionCooldowns = ctx._minionCooldowns or {}
		local cooldowns = ctx._minionCooldowns
		local minionType = (mob.metadata and mob.metadata.minionType) or "COBBLESTONE"
		local anchorKeyForLevel
		do
			anchorKeyForLevel = mob.metadata and mob.metadata.anchorKey
			if not anchorKeyForLevel and mob.spawnPosition then
				local bs = BLOCK_SIZE
				local ax = math.floor(mob.spawnPosition.X / bs)
				local ay = math.floor(mob.spawnPosition.Y / bs) - 1
				local az = math.floor(mob.spawnPosition.Z / bs)
				anchorKeyForLevel = string.format("%d,%d,%d", ax, ay, az)
			end
		end
		local levelForTiming = 1
		do
			local vws = self.Deps and self.Deps.VoxelWorldService
			if vws and anchorKeyForLevel and vws.minionStateByBlockKey then
				local s = vws.minionStateByBlockKey[anchorKeyForLevel]
				if s and s.level then
					levelForTiming = s.level
				end
			end
		end
		local baseWait = MinionConfig.GetWaitSeconds(minionType, levelForTiming)
		-- Add slight jitter +/-2s
		local nextInterval = math.max(0.1, baseWait + self._rng:NextNumber(-2, 2))
		brain.nextMinionActAt = brain.nextMinionActAt or (now + nextInterval)
		-- Do not recompute ground for minions; keep fixed Y at spawn (prevents falling)
		if now >= brain.nextMinionActAt then
			-- Determine platform coordinates beneath minion
			local BLOCK = Constants.BlockType
			local bs = BLOCK_SIZE
			local spawn = mob.spawnPosition
			local cx = math.floor(spawn.X / bs)
			local cz = math.floor(spawn.Z / bs)
			-- Use fixed platform layer derived from spawn Y (prevents drifting with terrain changes)
			brain.basePlatformY = brain.basePlatformY or (math.floor(spawn.Y / bs) - 1)
			local platformY = brain.basePlatformY

			local vws = self.Deps and self.Deps.VoxelWorldService
			local wm = vws and vws.worldManager
			-- If world manager unavailable, skip acting this cycle to avoid phantom placements based on AIR defaults
			if not wm then
				brain.nextMinionActAt = now + math.max(0.1, MinionConfig.GetWaitSeconds(minionType, levelForTiming) + self._rng:NextNumber(-2, 2))
				mob.state = "idle"
				self:_queueUpdate(mob)
				return
			end

			local function getBlock(x, y, z)
				if wm then
					return wm:GetBlock(x, y, z)
				end
				return BLOCK.AIR
			end
			local function setBlock(x, y, z, id)
				if vws and vws.SetBlock then
					vws:SetBlock(x, y, z, id, nil, 0)
				elseif wm then
					wm:SetBlock(x, y, z, id)
				end
			end

			-- Scan 5x5 footprint for air and target resource; avoid cells claimed by other minions this tick
			local targetForPlace
			local targetForMine
			local typeDef = MinionConfig.GetTypeDef(minionType)
			local BLOCK_TO_PLACE = typeDef.placeBlockId
			local BLOCK_TO_MINE = typeDef.mineBlockId
			local BONUS_PLACE_ID = typeDef.bonusPlaceBlockId
			local BONUS_PLACE_CHANCE = typeDef.bonusPlaceChance or 0
			local BONUS_MINE_ID = typeDef.bonusMineBlockId
			-- Randomize scan order to reduce contention patterns across minions
			local startI = self._rng:NextInteger(0, 4)
			local dirI = (self._rng:NextNumber(0, 1) < 0.5) and 1 or -1
			local startJ = self._rng:NextInteger(0, 4)
			local dirJ = (self._rng:NextNumber(0, 1) < 0.5) and 1 or -1
			for oj = 0, 4 do
				local j = (startJ + oj * dirJ) % 5 -- 0..4
				local dz = (j - 2)
				for oi = 0, 4 do
					local i = (startI + oi * dirI) % 5 -- 0..4
					local dx = (i - 2)
					local bx = cx + dx
					local bz = cz + dz
					local k = string.format("%d,%d,%d", bx, platformY, bz)
					local claimed = ctx._minionClaims and ctx._minionClaims[k]
					-- Per-cell cooldown: skip cells recently acted upon by any minion
					local cdUntil = cooldowns and cooldowns[k]
					local isOnCooldown = (cdUntil ~= nil and cdUntil > now)
					if (not claimed) and (not isOnCooldown) then
						local id = getBlock(bx, platformY, bz)
						if id == BLOCK.AIR and not targetForPlace then
							targetForPlace = { x = bx, y = platformY, z = bz, key = k }
						elseif (id == BLOCK_TO_MINE or (BONUS_MINE_ID and id == BONUS_MINE_ID)) and not targetForMine then
							targetForMine = { x = bx, y = platformY, z = bz, key = k }
						end
					end
				end
			end

			-- Choose action: place if any air; otherwise mine if any cobblestone
			local target = targetForPlace or targetForMine
			if target then
				-- Claim the target so other minions skip it this tick
				if ctx._minionClaims then
					ctx._minionClaims[target.key] = true
				end
				-- Apply a short cooldown on this cell so it won't be selected again immediately in subsequent ticks
				if cooldowns then
					-- Small randomization to avoid lockstep (configurable per minion type)
					local cdMin, cdMax = MinionConfig.GetCellCooldownRangeSec(minionType)
					cooldowns[target.key] = now + self._rng:NextNumber(cdMin, cdMax)
				end
				-- Face the target block center
				local tx = target.x * bs + bs * 0.5
				local tz = target.z * bs + bs * 0.5
				local dx = tx - mob.position.X
				local dz = tz - mob.position.Z
				if math.abs(dx) > 1e-6 or math.abs(dz) > 1e-6 then
					mob.rotation = math.deg(math.atan2(dx, dz))
				end

				-- Perform action
				if targetForPlace and target == targetForPlace then
					-- Re-verify target cell is still AIR before placing (race safety)
					if getBlock(target.x, target.y, target.z) == BLOCK.AIR then
						local placeId = BLOCK_TO_PLACE
						if BONUS_PLACE_ID and BONUS_PLACE_CHANCE > 0 then
							if self._rng:NextNumber(0, 1) <= BONUS_PLACE_CHANCE then
								placeId = BONUS_PLACE_ID
							end
						end
						setBlock(target.x, target.y, target.z, placeId)
						-- Update last active timestamp for offline catch-up
						if vws then
							local anchorKey = brain.basePlatformY and string.format("%d,%d,%d",
								math.floor(mob.spawnPosition.X / bs),
								(brain.basePlatformY),
								math.floor(mob.spawnPosition.Z / bs))
								or (mob.metadata and mob.metadata.anchorKey)
							if anchorKey and vws.minionStateByBlockKey[anchorKey] then
								vws.minionStateByBlockKey[anchorKey].lastActiveAt = now
							end
						end
					end
				else
					-- Mine only if still matching target block
					local minedId = getBlock(target.x, target.y, target.z)
					if minedId == BLOCK_TO_MINE or (BONUS_MINE_ID and minedId == BONUS_MINE_ID) then
						-- Try to add to minion's storage
						local anchorKey = mob.metadata and mob.metadata.anchorKey
						-- Fallback: compute anchorKey from spawn position if missing (for persisted minions)
						if not anchorKey and mob.spawnPosition then
							local ax = math.floor(mob.spawnPosition.X / bs)
							local ay = math.floor(mob.spawnPosition.Y / bs) - 1 -- minion spawns at y+1
							local az = math.floor(mob.spawnPosition.Z / bs)
							anchorKey = string.format("%d,%d,%d", ax, ay, az)
							-- Cache it for future use
							if mob.metadata then
								mob.metadata.anchorKey = anchorKey
							end
						end
						if anchorKey and vws and vws.AddItemToMinion then
							local added = vws:AddItemToMinion(anchorKey, minedId, 1)
							if added then
								-- Successfully stored, mine the block
								setBlock(target.x, target.y, target.z, BLOCK.AIR)
								-- Update last active timestamp for offline catch-up
								if vws and anchorKey then
									local key = anchorKey
									if vws.minionStateByBlockKey[key] then
										vws.minionStateByBlockKey[key].lastActiveAt = now
									end
								end
							end
							-- If not added (full), skip mining this cycle
						else
							-- No storage system; just mine to air
							setBlock(target.x, target.y, target.z, BLOCK.AIR)
						end
					end
				end
			end

			-- Schedule next action with slight jitter
			brain.nextMinionActAt = now + math.max(0.1, MinionConfig.GetWaitSeconds(minionType, levelForTiming) + self._rng:NextNumber(-2, 2))
		end

		mob.velocity = Vector3.new()
		-- Keep position pinned (no falling/jostling), with adjusted Y so model sits on the platform correctly
		do
			local bs = BLOCK_SIZE
			local baseY = brain.basePlatformY or (math.floor(mob.spawnPosition.Y / bs) - 1)
			-- Place minion on top of the platform block (feet at surface)
			local pinnedY = math.max(0, (baseY + 1) * bs)
			mob.position = Vector3.new(mob.spawnPosition.X, pinnedY, mob.spawnPosition.Z)
		end
		mob.state = "idle"
		self:_queueUpdate(mob)
		return
	end

	-- Activation gating + per-mob think staggering
	local now = os.clock()
	local activeDist = self._aiActiveDistance or 220
	local inactiveDist = self._aiInactiveDistance or (activeDist + 40)
	local activeDistSq = activeDist * activeDist
	local inactiveDistSq = inactiveDist * inactiveDist

	local d2 = nearestPlayerDistanceSq(self, mob.position)
	if mob.isActive == nil then
		mob.isActive = (d2 <= inactiveDistSq)
	elseif mob.isActive then
		if d2 > inactiveDistSq then
			mob.isActive = false
		end
	else
		if d2 < activeDistSq then
			mob.isActive = true
		end
	end

	local runAI = false
	local nextAt = brain.nextThinkAt or 0
	if now >= nextAt then
		local interval
		if mob.isActive then
			local r = self._thinkIntervalActive or { min = 0.12, max = 0.18 }
			interval = self._rng:NextNumber(r.min, r.max)
		else
			local r = self._thinkIntervalInactive or { min = 0.9, max = 1.5 }
			interval = self._rng:NextNumber(r.min, r.max)
		end
		brain.nextThinkAt = now + interval
		runAI = true
	end

	if runAI then
		if mob.isActive then
			if def.category == MobRegistry.Categories.PASSIVE then
				self:_updatePassiveMob(ctx, mob, def, brain, dt)
			elseif def.category == MobRegistry.Categories.HOSTILE then
				self:_updateHostileMob(ctx, mob, def, brain, dt)
			end
		else
			-- Inactive maintenance: hold pose and keep grounded
			if brain.grazeUntil and now < brain.grazeUntil then
				mob.state = "graze"
			else
				mob.state = "idle"
			end
			mob.velocity = Vector3.new()
			local ok, gY, gBY = probeFootprint(self, mob.position.X, mob.position.Z, mob.position.Y)
			if ok and gY and gBY then
				local currentBY = math.floor((mob.groundY or mob.position.Y) / BLOCK_SIZE)
				if gBY <= currentBY then
					mob.groundY = gY
					mob.position = Vector3.new(mob.position.X, mob.groundY, mob.position.Z)
				end
			end
		end
	end

	local newCx, newCz = worldPositionToChunk(mob.position)
	if newCx ~= mob.chunkX or newCz ~= mob.chunkZ then
		removeMobFromChunk(ctx, mob)
		registerMobToChunk(ctx, mob, newCx, newCz)
	end

	self:_queueUpdate(mob)
end

local function pickRandomOffset(rng, radius)
	local angle = rng:NextNumber(0, math.pi * 2)
	local dist = rng:NextNumber(radius * 0.25, radius)
	return Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
end

function updateGroundY(self, position)
	-- Raycast downward to find ground level
	if not self.Deps or not self.Deps.VoxelWorldService or not self.Deps.VoxelWorldService.worldManager then
		return position.Y
	end

	local wm = self.Deps.VoxelWorldService.worldManager
	if not wm then
		return position.Y
	end

	-- Convert world position to block coordinates
	local blockX = math.floor(position.X / BLOCK_SIZE)
	local blockZ = math.floor(position.Z / BLOCK_SIZE)
	local startY = math.min(Constants.WORLD_HEIGHT - 1, math.floor(position.Y / BLOCK_SIZE) + 2)

	-- Raycast down to find solid ground
	for blockY = startY, 1, -1 do
		local block = wm:GetBlock(blockX, blockY, blockZ)
		local above = wm:GetBlock(blockX, blockY + 1, blockZ)
		if isSolidForMobs(block) and isPassableForMobs(above) then
			return blockY * BLOCK_SIZE + BLOCK_SIZE + 0.01
		end
	end

	return position.Y
end

-- Returns groundY (studs) and groundBlockY (block index) at XZ, or nil if no ground
local function findGround(self, x, z, startYStuds)
	if not self.Deps or not self.Deps.VoxelWorldService or not self.Deps.VoxelWorldService.worldManager then
		return nil, nil
	end

	local wm = self.Deps.VoxelWorldService.worldManager
	if not wm then
		return nil, nil
	end

	local blockX = math.floor(x / BLOCK_SIZE)
	local blockZ = math.floor(z / BLOCK_SIZE)
	local startBlockY = math.min(Constants.WORLD_HEIGHT - 1, math.floor((startYStuds or 0) / BLOCK_SIZE) + 2)

	for blockY = startBlockY, 1, -1 do
		local block = wm:GetBlock(blockX, blockY, blockZ)
		local above = wm:GetBlock(blockX, blockY + 1, blockZ)
		-- Ground must be a solid block; space above it must be passable (air/cross-shape/non-solid)
		if isSolidForMobs(block) and isPassableForMobs(above) then
			local groundY = blockY * BLOCK_SIZE + BLOCK_SIZE + 0.01
			return groundY, blockY
		end
	end

	return nil, nil
end

-- Reserved for potential future use in advanced collision detection
local function _isSolid(_self, blockX, blockY, blockZ)
	if not _self.Deps or not _self.Deps.VoxelWorldService or not _self.Deps.VoxelWorldService.worldManager then
		return false
	end
	local wm = _self.Deps.VoxelWorldService.worldManager
	if not wm then
		return false
	end
	local block = wm:GetBlock(blockX, blockY, blockZ)
	return block ~= Constants.BlockType.AIR
end

-- Treat AIR, cross-shaped, and other non-solid blocks as passable for mob movement/headroom
function isPassableForMobs(blockId)
	if blockId == Constants.BlockType.AIR then
		return true
	end
	local def = BlockRegistry and BlockRegistry.GetBlock and BlockRegistry:GetBlock(blockId)
	if not def then
		return false
	end
	if def.crossShape == true then
		return true
	end
	return def.solid == false
end

-- Treat only truly solid blocks as supporting ground for mobs
function isSolidForMobs(blockId)
	if blockId == Constants.BlockType.AIR then
		return false
	end
	local def = BlockRegistry and BlockRegistry.GetBlock and BlockRegistry:GetBlock(blockId)
	return def and def.solid == true or false
end

-- Probe the mob's footprint (center + 4 offsets) for support and headroom
-- Returns (ok, centerGroundY, centerGroundBlockY)
function probeFootprint(self, x, z, startYStuds)
	if not self.Deps or not self.Deps.VoxelWorldService or not self.Deps.VoxelWorldService.worldManager then
		return true, startYStuds or 0, math.floor((startYStuds or 0) / BLOCK_SIZE)
	end
	local wm = self.Deps.VoxelWorldService.worldManager
	if not wm then
		return true, startYStuds or 0, math.floor((startYStuds or 0) / BLOCK_SIZE)
	end

	-- Minecraft-style footprint checking: more permissive for edge-standing
	-- Use smaller sample area to allow standing on edges and narrow surfaces
	local halfX = BLOCK_SIZE * 0.3  -- Smaller footprint for edge tolerance
	local halfZ = BLOCK_SIZE * 0.3

	local samples = {
		{ x = x, z = z },  -- Center (always required)
		{ x = x + halfX, z = z },  -- Right edge
		{ x = x - halfX, z = z },  -- Left edge
		{ x = x, z = z + halfZ },  -- Forward edge
		{ x = x, z = z - halfZ },  -- Back edge
	}

	local centerGroundY, centerBlockY = findGround(self, samples[1].x, samples[1].z, startYStuds)
	if not centerGroundY then
		return false, nil, nil
	end

	-- For Minecraft-like behavior, we only need the center to be supported
	-- Mobs can stand on edges and narrow surfaces
	local _validSamples = { { y = centerBlockY, hasHeadroom = true } }  -- Reserved for future multi-sample logic

	-- Check headroom at center first
	local centerBlockX = math.floor(x / BLOCK_SIZE)
	local centerBlockZ = math.floor(z / BLOCK_SIZE)
	local knee = wm:GetBlock(centerBlockX, centerBlockY + 1, centerBlockZ)
	local head = wm:GetBlock(centerBlockX, centerBlockY + 2, centerBlockZ)
	-- Consider cross-shaped and other non-solid blocks as passable headroom
	local centerHasHeadroom = (isPassableForMobs(knee) and isPassableForMobs(head))

	if not centerHasHeadroom then
		return false, nil, nil  -- No headroom at center, can't stand here
	end

	-- Center-only acceptance for 1-block-wide, 2-block-tall tunnels
	-- If the center has valid support and 2 blocks of headroom, consider it walkable.
	-- Edge samples are optional and no longer required for narrow corridors.
	return true, centerGroundY, centerBlockY

	-- (Edge sampling removed for strict 1x2 tunnel compatibility)
end

-- Apply voxel-aware horizontal movement with 1-block step limit
local function moveRespectingVoxels(self, mob, direction, speed, dt)
    local position = mob.position
    local dir2 = Vector3.new(direction.X, 0, direction.Z)
    local dirMag = dir2.Magnitude
    if dirMag < 1e-5 then
        mob.velocity = Vector3.new()
        return false
    end

    -- Arrive: slow down near target if we were given a displacement vector
    local arriveRadius = self._arriveRadius or 3.0
    local distHint = dirMag -- if caller passed a displacement to a waypoint/target
    local desiredSpeed = speed
    if distHint > 0 and distHint < arriveRadius * 1.25 then
        local scale = math.clamp(distHint / arriveRadius, 0.25, 1)
        desiredSpeed = speed * scale
    end

    -- Acceleration: approach desired speed
    local velH = Vector3.new(mob.velocity.X, 0, mob.velocity.Z)
    local currentSpeed = velH.Magnitude
    local maxAccel = (self._maxAccel or 28.0) * dt
    local targetSpeed = math.clamp(desiredSpeed, 0, desiredSpeed)
    local newSpeed = currentSpeed
    if math.abs(targetSpeed - currentSpeed) > 1e-4 then
        local delta = math.clamp(targetSpeed - currentSpeed, -maxAccel, maxAccel)
        newSpeed = currentSpeed + delta
    end

    local moveDir = dir2.Unit
    local step = moveDir * newSpeed * dt
    local targetX = position.X + step.X
    local targetZ = position.Z + step.Z

    local ok, targetGroundY, targetGroundBlockY = probeFootprint(self, targetX, targetZ, position.Y)
    if not ok then
        -- Wall slide fallback: try axis-projected steps
        if math.abs(step.X) > 1e-4 then
            local tx = position.X + step.X
            local tz = position.Z
            local okx, gYx, gBx = probeFootprint(self, tx, tz, position.Y)
            if okx then
                local currentBlockY = math.floor(mob.groundY / BLOCK_SIZE)
                local stepUp = (gBx - currentBlockY)
                local stepDown = (currentBlockY - gBx)
                if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
                    mob.velocity = Vector3.new(math.sign(step.X), 0, 0) * newSpeed
                    local desiredYaw = math.deg(math.atan2(mob.velocity.X, mob.velocity.Z == 0 and 1e-6 or mob.velocity.Z))
                    local deltaYaw = desiredYaw - mob.rotation
                    if deltaYaw > 180 then
                    	deltaYaw = deltaYaw - 360
                    end
                    if deltaYaw < -180 then
                    	deltaYaw = deltaYaw + 360
                    end
                    local maxTurn = (mob.definition.turnRateDegPerSec or self._maxTurnRateDegPerSec or 160) * dt
                    mob.rotation = mob.rotation + math.clamp(deltaYaw, -maxTurn, maxTurn)
                    mob.groundY = gYx
                    mob.position = Vector3.new(tx, mob.groundY, tz)
                    return true
                end
            end
        end
        if math.abs(step.Z) > 1e-4 then
            local tx = position.X
            local tz = position.Z + step.Z
            local okz, gYz, gBz = probeFootprint(self, tx, tz, position.Y)
            if okz then
                local currentBlockY = math.floor(mob.groundY / BLOCK_SIZE)
                local stepUp = (gBz - currentBlockY)
                local stepDown = (currentBlockY - gBz)
                if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
                    mob.velocity = Vector3.new(0, 0, math.sign(step.Z)) * newSpeed
                    local desiredYaw = math.deg(math.atan2(mob.velocity.X, mob.velocity.Z == 0 and 1e-6 or mob.velocity.Z))
                    local deltaYaw = desiredYaw - mob.rotation
                    if deltaYaw > 180 then
                    	deltaYaw = deltaYaw - 360
                    end
                    if deltaYaw < -180 then
                    	deltaYaw = deltaYaw + 360
                    end
                    local maxTurn = (mob.definition.turnRateDegPerSec or self._maxTurnRateDegPerSec or 160) * dt
                    mob.rotation = mob.rotation + math.clamp(deltaYaw, -maxTurn, maxTurn)
                    mob.groundY = gYz
                    mob.position = Vector3.new(tx, mob.groundY, tz)
                    return true
                end
            end
        end
        return false
    end

    -- Step height/drop limits
    local currentBlockY = math.floor(mob.groundY / BLOCK_SIZE)
    local stepBlocks = (targetGroundBlockY - currentBlockY)
    if stepBlocks > 1 then
        return false
    end
    local dropBlocks = (currentBlockY - targetGroundBlockY)
    if dropBlocks > (self._maxStepDownBlocks or 3) then
        return false
    end

    -- Commit move
    mob.velocity = moveDir * newSpeed
    local desiredYaw = math.deg(math.atan2(moveDir.X, moveDir.Z))
    local deltaYaw = desiredYaw - mob.rotation
    if deltaYaw > 180 then
    	deltaYaw = deltaYaw - 360
    end
    if deltaYaw < -180 then
    	deltaYaw = deltaYaw + 360
    end
    local maxTurn = (mob.definition.turnRateDegPerSec or self._maxTurnRateDegPerSec or 160) * dt
    mob.rotation = mob.rotation + math.clamp(deltaYaw, -maxTurn, maxTurn)
    mob.groundY = targetGroundY
    mob.position = Vector3.new(targetX, mob.groundY, targetZ)
    return true
end

-- Attempt a tiny horizontal nudge while respecting step up/down limits
local function tryNudgeXZ(self, mob, dx, dz)
    if math.abs(dx) < 1e-6 and math.abs(dz) < 1e-6 then
        return false
    end
    local pos = mob.position
    local tx = pos.X + dx
    local tz = pos.Z + dz
    local ok, gY, gBY = probeFootprint(self, tx, tz, mob.groundY or pos.Y)
    if ok and gY and gBY then
        local currentBY = math.floor((mob.groundY or pos.Y) / BLOCK_SIZE)
        local stepUp = (gBY - currentBY)
        local stepDown = (currentBY - gBY)
        if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
            mob.position = Vector3.new(tx, gY, tz)
            mob.groundY = gY
            return true
        end
    end
    -- Axis-projected fallbacks
    if math.abs(dx) > 1e-6 then
        local tx2 = pos.X + dx
        local tz2 = pos.Z
        local okx, gYx, gBx = probeFootprint(self, tx2, tz2, mob.groundY or pos.Y)
        if okx and gYx and gBx then
            local currentBY = math.floor((mob.groundY or pos.Y) / BLOCK_SIZE)
            local stepUp = (gBx - currentBY)
            local stepDown = (currentBY - gBx)
            if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
                mob.position = Vector3.new(tx2, gYx, tz2)
                mob.groundY = gYx
                return true
            end
        end
    end
    if math.abs(dz) > 1e-6 then
        local tx3 = pos.X
        local tz3 = pos.Z + dz
        local okz, gYz, gBz = probeFootprint(self, tx3, tz3, mob.groundY or pos.Y)
        if okz and gYz and gBz then
            local currentBY = math.floor((mob.groundY or pos.Y) / BLOCK_SIZE)
            local stepUp = (gBz - currentBY)
            local stepDown = (currentBY - gBz)
            if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
                mob.position = Vector3.new(tx3, gYz, tz3)
                mob.groundY = gYz
                return true
            end
        end
    end
    return false
end

local function worldToBlockCoord(value)
	return math.floor(value / BLOCK_SIZE)
end

local function heuristic(ax, az, bx, bz)
	return math.abs(ax - bx) + math.abs(az - bz)
end

local function makeKey(bx, bz)
	return tostring(bx) .. "," .. tostring(bz)
end

local function reconstructPath(cameFrom, endKey, nodeToWorld)
	local path = {}
	local current = endKey
	while current do
		local wp = nodeToWorld[current]
		if not wp then
			break
		end
		table.insert(path, 1, wp)
		current = cameFrom[current]
	end
	return path
end

-- Check if straight-line walk from A to B is viable by sampling footprint along the segment
local function lineClearFooting(self, fromPos, toPos, startYStuds)
	local dx = toPos.X - fromPos.X
	local dz = toPos.Z - fromPos.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 0.1 then
		return true
	end
	local steps = math.max(2, math.ceil(dist / (BLOCK_SIZE * 0.5)))

	-- Disallow skipping across a total rise > 1 block between endpoints
	local _, _, fromBY = probeFootprint(self, fromPos.X, fromPos.Z, startYStuds)
	local okEnd, _, toBY = probeFootprint(self, toPos.X, toPos.Z, startYStuds)
	if not okEnd or not fromBY or not toBY then
		return false
	end
	if (toBY - fromBY) > 1 then
		return false
	end

	-- Track elevation to enforce step constraints along the segment
	local prevBY = math.floor((startYStuds or fromPos.Y or 0) / BLOCK_SIZE)

	for i = 1, steps do
		local t = i / steps
		local sx = fromPos.X + dx * t
		local sz = fromPos.Z + dz * t
		local ok, _, gBY = probeFootprint(self, sx, sz, startYStuds)
		if not ok or not gBY then
			return false
		end
		-- Enforce the same movement rules used by movement/path expansion
		local stepUp = gBY - prevBY
		local stepDown = prevBY - gBY
		if stepUp > 1 or stepDown > (self._maxStepDownBlocks or 3) then
			return false
		end
		prevBY = gBY
	end
	return true
end

-- Simple line-of-sight check using Roblox raycast against world geometry
local function hasLineOfSight(_self, fromPos, toPos, ignoreInstances)
	local dir = toPos - fromPos
	if dir.Magnitude < 1e-4 then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreInstances or {}
	local result = workspace:Raycast(fromPos, dir, params)
	if not result then
		return true
	end
	-- Consider it clear if the first hit is among ignored instances (e.g. target's character)
	if ignoreInstances then
		for _, inst in ipairs(ignoreInstances) do
			if result.Instance and (result.Instance == inst or result.Instance:IsDescendantOf(inst)) then
				return true
			end
		end
	end
	return false
end

local function getNavigator(self, mob)
	if not mob._navigator then
		mob._navigator = Navigator.new(
			self.Deps and self.Deps.VoxelWorldService,
			function(selfSvc, m, dir, speed, dt)
				return moveRespectingVoxels(selfSvc, m, dir, speed, dt)
			end,
			function(selfSvc, fromPos, toPos, startY)
				return lineClearFooting(selfSvc, fromPos, toPos, startY)
			end,
			{
				stuckSeconds = 1.2,
				repathCooldown = 1.0,
				blockSize = BLOCK_SIZE,
			}
		)
	end
	return mob._navigator
end

-- Try a one-time emergency step down off ledges up to 2 blocks to recover from stuck-on-pillar situations
local function attemptEmergencyStepDown(self, mob)
	local currentBlockY = math.floor((mob.groundY or mob.position.Y) / BLOCK_SIZE)
	local bestDir
	local bestTarget
	local bestDrop = -1
	local dirs = {
		Vector3.new(1, 0, 0),
		Vector3.new(-1, 0, 0),
		Vector3.new(0, 0, 1),
		Vector3.new(0, 0, -1),
		Vector3.new(1, 0, 1).Unit,
		Vector3.new(1, 0, -1).Unit,
		Vector3.new(-1, 0, 1).Unit,
		Vector3.new(-1, 0, -1).Unit,
	}
	for _, d in ipairs(dirs) do
		local wx = worldToBlockCoord(mob.position.X + d.X * BLOCK_SIZE) * BLOCK_SIZE + BLOCK_SIZE / 2
		local wz = worldToBlockCoord(mob.position.Z + d.Z * BLOCK_SIZE) * BLOCK_SIZE + BLOCK_SIZE / 2
		local ok, gY, gBY = probeFootprint(self, wx, wz, mob.groundY or mob.position.Y)
		if ok and gY and gBY then
			local drop = currentBlockY - gBY
			local rise = gBY - currentBlockY
            -- Allow a controlled drop when trying to recover
            local maxDrop = self._emergencyDropBlocks or 2
            if drop >= 1 and drop <= maxDrop and rise <= 0 then
				if drop > bestDrop then
					bestDrop = drop
					bestDir = Vector3.new(wx - mob.position.X, 0, wz - mob.position.Z)
					bestTarget = Vector3.new(wx, gY, wz)
				end
			end
		end
	end
	if bestTarget then
		local dir = bestDir.Unit
		local desiredYaw = math.deg(math.atan2(dir.X, dir.Z == 0 and 1e-6 or dir.Z))
		local deltaYaw = desiredYaw - (mob.rotation or 0)
		if deltaYaw > 180 then
			deltaYaw = deltaYaw - 360
		end
		if deltaYaw < -180 then
			deltaYaw = deltaYaw + 360
		end
		mob.rotation = (mob.rotation or 0) + deltaYaw
		mob.velocity = Vector3.new()
		mob.position = bestTarget
		mob.groundY = bestTarget.Y
		return true
	end
	return false
end

local function findNearestWalkableGoal(self, targetX, targetZ, startYStuds, maxRadiusBlocks)
    local goalBX, goalBZ = worldToBlockCoord(targetX), worldToBlockCoord(targetZ)
    local maxR = maxRadiusBlocks or 12
    -- check goal itself first
    local centerX = goalBX * BLOCK_SIZE + BLOCK_SIZE / 2
    local centerZ = goalBZ * BLOCK_SIZE + BLOCK_SIZE / 2
    local ok, gY, gBY = probeFootprint(self, centerX, centerZ, startYStuds)
    if ok and gY and gBY then
        return Vector3.new(centerX, gY, centerZ)
    end

    -- expand in rings
    for r = 1, maxR do
        for dx = -r, r do
            local dz1 = -r
            local dz2 = r
            local bx1, bz1 = goalBX + dx, goalBZ + dz1
            local bx2, bz2 = goalBX + dx, goalBZ + dz2
            local wx1 = bx1 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wz1 = bz1 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wx2 = bx2 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wz2 = bz2 * BLOCK_SIZE + BLOCK_SIZE / 2
            local ok1, y1 = probeFootprint(self, wx1, wz1, startYStuds)
            if ok1 and y1 then
                return Vector3.new(wx1, y1, wz1)
            end
            local ok2, y2 = probeFootprint(self, wx2, wz2, startYStuds)
            if ok2 and y2 then
                return Vector3.new(wx2, y2, wz2)
            end
        end
        for dz = -r + 1, r - 1 do
            local dx1 = -r
            local dx2 = r
            local bx1, bz1 = goalBX + dx1, goalBZ + dz
            local bx2, bz2 = goalBX + dx2, goalBZ + dz
            local wx1 = bx1 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wz1 = bz1 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wx2 = bx2 * BLOCK_SIZE + BLOCK_SIZE / 2
            local wz2 = bz2 * BLOCK_SIZE + BLOCK_SIZE / 2
            local ok1, y1 = probeFootprint(self, wx1, wz1, startYStuds)
            if ok1 and y1 then
                return Vector3.new(wx1, y1, wz1)
            end
            local ok2, y2 = probeFootprint(self, wx2, wz2, startYStuds)
            if ok2 and y2 then
                return Vector3.new(wx2, y2, wz2)
            end
        end
    end
    return nil
end

-- Utility: squared 2D distance (X,Z)
local function distanceSq2(aX, aZ, bX, bZ)
	local dx = aX - bX
	local dz = aZ - bZ
	return dx * dx + dz * dz
end

-- Extract an approximate horizontal collision radius (studs) from a mob definition
local function getCollisionRadiusStuds(def)
    if not def then
        return BLOCK_SIZE * 0.45
    end
    local c = def.collision
    if type(c) == "table" then
        -- Prefer explicit radius if present
        local r = c.radius or c.r
        if type(r) == "number" and r > 0 then
            return r
        end
        -- Width/depth or size vector
        local width = c.width or c.w
        local depth = c.depth or c.d or c.z
        if type(width) == "number" or type(depth) == "number" then
            local diam = math.max(width or 0, depth or 0)
            if diam > 0 then
                return diam * 0.5
            end
        end
        local size = c.size or c.dim or c.bounds
        if typeof(size) == "Vector3" then
            return math.max(size.X, size.Z) * 0.5
        elseif type(size) == "table" then
            local sx = size.X or size[1]
            local sz = size.Z or size[3]
            if type(sx) == "number" and type(sz) == "number" then
                return math.max(sx, sz) * 0.5
            end
        end
    elseif type(c) == "number" and c > 0 then
        -- If a single number is provided, assume it's diameter in studs
        return c * 0.5
    end
    -- Fallback: Minecraft sheep width ~0.9 blocks => ~0.45 block radius
    return BLOCK_SIZE * 0.45
end

-- Find a nearby single descent step (1-2 blocks down) around the start position
-- Returns a world position at the candidate step or nil
-- Reserved for potential future use in jump-down pathing
local function _findDescentStepNear(self, startPos, maxRadiusBlocks)
	local wm = self.Deps and self.Deps.VoxelWorldService and self.Deps.VoxelWorldService.worldManager
	if not wm then
		return nil
	end

	local startBX = worldToBlockCoord(startPos.X)
	local startBZ = worldToBlockCoord(startPos.Z)
	local startBY = math.floor((startPos.Y or 0) / BLOCK_SIZE)
	local maxR = math.max(1, math.floor(maxRadiusBlocks or 8))

	local best
	local bestDrop = 0
	local bestDist2 = math.huge

	for r = 1, maxR do
		-- top and bottom rows of the ring
		for dx = -r, r do
			local bx1, bz1 = startBX + dx, startBZ - r
			local bx2, bz2 = startBX + dx, startBZ + r
			local wx1 = bx1 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wz1 = bz1 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wx2 = bx2 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wz2 = bz2 * BLOCK_SIZE + BLOCK_SIZE / 2

			local ok1, gY1, gB1 = probeFootprint(self, wx1, wz1, startPos.Y)
			if ok1 and gY1 and gB1 then
				local drop1 = startBY - gB1
				if drop1 >= 1 and drop1 <= 2 then
					local d2 = distanceSq2(wx1, wz1, startPos.X, startPos.Z)
					if drop1 > bestDrop or (drop1 == bestDrop and d2 < bestDist2) then
						best = Vector3.new(wx1, gY1, wz1)
						bestDrop = drop1
						bestDist2 = d2
					end
				end
			end

			local ok2, gY2, gB2 = probeFootprint(self, wx2, wz2, startPos.Y)
			if ok2 and gY2 and gB2 then
				local drop2 = startBY - gB2
				if drop2 >= 1 and drop2 <= 2 then
					local d2 = distanceSq2(wx2, wz2, startPos.X, startPos.Z)
					if drop2 > bestDrop or (drop2 == bestDrop and d2 < bestDist2) then
						best = Vector3.new(wx2, gY2, wz2)
						bestDrop = drop2
						bestDist2 = d2
					end
				end
			end
		end

		-- left and right columns of the ring (excluding corners already checked)
		for dz = -r + 1, r - 1 do
			local bx1, bz1 = startBX - r, startBZ + dz
			local bx2, bz2 = startBX + r, startBZ + dz
			local wx1 = bx1 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wz1 = bz1 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wx2 = bx2 * BLOCK_SIZE + BLOCK_SIZE / 2
			local wz2 = bz2 * BLOCK_SIZE + BLOCK_SIZE / 2

			local ok1, gY1, gB1 = probeFootprint(self, wx1, wz1, startPos.Y)
			if ok1 and gY1 and gB1 then
				local drop1 = startBY - gB1
				if drop1 >= 1 and drop1 <= 2 then
					local d2 = distanceSq2(wx1, wz1, startPos.X, startPos.Z)
					if drop1 > bestDrop or (drop1 == bestDrop and d2 < bestDist2) then
						best = Vector3.new(wx1, gY1, wz1)
						bestDrop = drop1
						bestDist2 = d2
					end
				end
			end

			local ok2, gY2, gB2 = probeFootprint(self, wx2, wz2, startPos.Y)
			if ok2 and gY2 and gB2 then
				local drop2 = startBY - gB2
				if drop2 >= 1 and drop2 <= 2 then
					local d2 = distanceSq2(wx2, wz2, startPos.X, startPos.Z)
					if drop2 > bestDrop or (drop2 == bestDrop and d2 < bestDist2) then
						best = Vector3.new(wx2, gY2, wz2)
						bestDrop = drop2
						bestDist2 = d2
					end
				end
			end
		end

		-- Early exit if we found a good 2-block drop nearby
		if best and bestDrop == 2 then
			break
		end
	end

	return best
end

local function _findPath(self, startX, startZ, startYStuds, goalX, goalZ, maxRangeBlocks, maxNodes)
	local startBX, startBZ = worldToBlockCoord(startX), worldToBlockCoord(startZ)
	local goalBX, goalBZ = worldToBlockCoord(goalX), worldToBlockCoord(goalZ)

	if maxRangeBlocks and heuristic(startBX, startBZ, goalBX, goalBZ) > maxRangeBlocks then
		return nil
	end

	local startGroundY, startBY = findGround(self, startX, startZ, startYStuds)
	if not startGroundY then
		return nil
	end

	-- Early-out: direct line-of-sight with valid footing to goal
	local goalWorld = Vector3.new(goalX, startGroundY, goalZ)
	local okGoal, gY = probeFootprint(self, goalX, goalZ, startYStuds)
	if okGoal and gY then
		goalWorld = Vector3.new(goalX, gY, goalZ)
	end
	if lineClearFooting(self, Vector3.new(startX, startGroundY, startZ), goalWorld, startYStuds) then
		return { goalWorld }
	end

	local openKeys = {}
	local cameFrom = {}
	local gScore = {}
	local fScore = {}
	local nodeToWorld = {}

	local Heap = {}
	Heap.__index = Heap
	function Heap.new()
		return setmetatable({ data = {} }, Heap)
	end
	function Heap:push(node, f)
		node.f = f
		local d = self.data
		d[#d + 1] = node
		local i = #d
		while i > 1 do
			local p = math.floor(i / 2)
			if d[p].f <= d[i].f then
				break
			end
			d[p], d[i] = d[i], d[p]
			i = p
		end
	end
	function Heap:pop()
		local d = self.data
		local n = #d
		if n == 0 then
			return nil
		end
		local root = d[1]
		d[1] = d[n]
		d[n] = nil
		n = n - 1
		local i = 1
		while true do
			local l = i * 2
			local r = l + 1
			local smallest = i
			if l <= n and d[l].f < d[smallest].f then
				smallest = l
			end
			if r <= n and d[r].f < d[smallest].f then
				smallest = r
			end
			if smallest == i then
				break
			end
			d[i], d[smallest] = d[smallest], d[i]
			i = smallest
		end
		return root
	end

	local openSet = Heap.new()

	local function push(bx, bz, by, g, f)
		local key = makeKey(bx, bz)
		gScore[key] = g
		fScore[key] = f
		openKeys[key] = true
		openSet:push({ bx = bx, bz = bz, by = by, key = key }, f)
		nodeToWorld[key] = Vector3.new(bx * BLOCK_SIZE + BLOCK_SIZE / 2, by * BLOCK_SIZE + BLOCK_SIZE + 0.01, bz * BLOCK_SIZE + BLOCK_SIZE / 2)
	end

	local function popLowestF()
		local node = openSet:pop()
		if not node then
			return nil
		end
		openKeys[node.key] = nil
		-- Skip stale entries where f no longer matches best known fScore
		local bestF = fScore[node.key]
		if bestF and node.f and math.abs(bestF - node.f) > 1e-6 then
			return popLowestF()
		end
		return node
	end

	local _startKey = makeKey(startBX, startBZ)
	push(startBX, startBZ, startBY, 0, heuristic(startBX, startBZ, goalBX, goalBZ))

	local expanded = 0
	local maxVisit = maxNodes or 600

    while #openSet.data > 0 and expanded < maxVisit do
		expanded += 1
		local current = popLowestF()
		if not current then
			break
		end

		if current.bx == goalBX and current.bz == goalBZ then
			return reconstructPath(cameFrom, current.key, nodeToWorld)
		end

        local neighbors = {
            { x = 1, z = 0, w = 1.0 },
            { x = -1, z = 0, w = 1.0 },
            { x = 0, z = 1, w = 1.0 },
            { x = 0, z = -1, w = 1.0 },
            -- diagonals
            { x = 1, z = 1, w = 1.41421356237 },
            { x = 1, z = -1, w = 1.41421356237 },
            { x = -1, z = 1, w = 1.41421356237 },
            { x = -1, z = -1, w = 1.41421356237 },
        }

		for _, d in ipairs(neighbors) do
			local nbx = current.bx + d.x
			local nbz = current.bz + d.z
			local worldX = nbx * BLOCK_SIZE + BLOCK_SIZE / 2
			local worldZ = nbz * BLOCK_SIZE + BLOCK_SIZE / 2

			local skip = false
			-- Diagonal corner-cut prevention: for diagonals, both adjacent cardinals must be walkable
			if d.w > 1.0 then
				local side1bx, side1bz = current.bx + d.x, current.bz
				local side2bx, side2bz = current.bx, current.bz + d.z
				local s1X = side1bx * BLOCK_SIZE + BLOCK_SIZE / 2
				local s1Z = side1bz * BLOCK_SIZE + BLOCK_SIZE / 2
				local s2X = side2bx * BLOCK_SIZE + BLOCK_SIZE / 2
				local s2Z = side2bz * BLOCK_SIZE + BLOCK_SIZE / 2
				local s1ok, _, s1BY = probeFootprint(self, s1X, s1Z, current.by * BLOCK_SIZE + BLOCK_SIZE)
				local s2ok, _, s2BY = probeFootprint(self, s2X, s2Z, current.by * BLOCK_SIZE + BLOCK_SIZE)
                if not (s1ok and s2ok) then
					skip = true
				else
					-- Also enforce step constraints for the side steps
                    if (s1BY - current.by) > 1 or (current.by - s1BY) > (self._maxStepDownBlocks or 3) or
                       (s2BY - current.by) > 1 or (current.by - s2BY) > (self._maxStepDownBlocks or 3) then
						skip = true
					end
				end
			end

			if not skip then
				local ok, nGroundY, nBY = probeFootprint(self, worldX, worldZ, current.by * BLOCK_SIZE + BLOCK_SIZE)
				if ok and nGroundY and nBY then
					local stepUp = nBY - current.by
					local stepDown = current.by - nBY
                    if stepUp <= 1 and stepDown <= (self._maxStepDownBlocks or 3) then
						local key = makeKey(nbx, nbz)
						local tentativeG = (gScore[current.key] or math.huge)
						if tentativeG == math.huge then
							tentativeG = 0
						end
                tentativeG = tentativeG + d.w + math.max(0, stepUp) * 0.2 + math.max(0, stepDown) * 0.3
						if tentativeG < (gScore[key] or math.huge) then
							cameFrom[key] = current.key
							local h = heuristic(nbx, nbz, goalBX, goalBZ)
							local f = tentativeG + h
							if not openKeys[key] then
								push(nbx, nbz, nBY, tentativeG, f)
							else
								gScore[key] = tentativeG
								fScore[key] = f
								nodeToWorld[key] = Vector3.new(nbx * BLOCK_SIZE + BLOCK_SIZE / 2, nBY * BLOCK_SIZE + BLOCK_SIZE + 0.01, nbz * BLOCK_SIZE + BLOCK_SIZE / 2)
							end
						end
					end
				end
			end
		end
	end

	return nil
end

function MobEntityService:_clearPath(mob)
	mob.brain.path = nil
	mob.brain.pathIndex = nil
	mob.brain.pathTarget = nil
	mob.brain.repathAt = 0
end

local function _snapToBlockCenter(x)
	return worldToBlockCoord(x) * BLOCK_SIZE + BLOCK_SIZE / 2
end

-- Find nearest walkable block center near target within search radius (in blocks)
local function findNearestWalkableXZ(self, targetX, targetZ, startYStuds, searchBlocks)
	local best
	local bestDist = math.huge
	local r = searchBlocks or 4
	local tBX = worldToBlockCoord(targetX)
	local tBZ = worldToBlockCoord(targetZ)
	for dz = -r, r do
		for dx = -r, r do
			local bx = tBX + dx
			local bz = tBZ + dz
			local wx = bx * BLOCK_SIZE + BLOCK_SIZE / 2
			local wz = bz * BLOCK_SIZE + BLOCK_SIZE / 2
			local ok, _, _ = probeFootprint(self, wx, wz, startYStuds)
			if ok then
				local d2 = distanceSq2(wx, wz, targetX, targetZ)
				if d2 < bestDist then
					bestDist = d2
					best = Vector3.new(wx, startYStuds or 0, wz)
				end
			end
		end
	end
	return best
end

-- Sample a random walkable block within radius (in blocks) of a center XZ
local function getRandomWalkableWithinRadius(self, centerX, centerZ, startYStuds, radiusBlocks, rng, maxAttempts)
	local attempts = maxAttempts or 12
	local r = math.max(1, math.floor(radiusBlocks or 6))
	for _ = 1, attempts do
		local dx = (rng:NextInteger(-r, r))
		local dz = (rng:NextInteger(-r, r))
		local bx = worldToBlockCoord(centerX) + dx
		local bz = worldToBlockCoord(centerZ) + dz
		local wx = bx * BLOCK_SIZE + BLOCK_SIZE / 2
		local wz = bz * BLOCK_SIZE + BLOCK_SIZE / 2
		local ok, gY, _ = probeFootprint(self, wx, wz, startYStuds)
		if ok and gY then
			return Vector3.new(wx, gY, wz)
		end
	end
	return nil
end

function MobEntityService:_planPathTo(mob, targetPos, maxRangeBlocks)
	local startPos = mob.position

	-- For temptation, use the target position directly without adjustment
	-- The temptation system should handle finding reachable positions
	local goal = targetPos

	-- Ensure goal is a reachable walkable center near the target
	local ok, gY, _ = probeFootprint(self, goal.X, goal.Z, startPos.Y)
	if ok and gY then
		goal = Vector3.new(goal.X, gY, goal.Z)
	else
		-- Broader search to find a nearby reachable block (e.g., staircase entry)
		local adjusted = findNearestWalkableGoal(self, targetPos.X, targetPos.Z, startPos.Y, 12)
			or findNearestWalkableXZ(self, targetPos.X, targetPos.Z, startPos.Y, 4)
		goal = adjusted or goal
	end

    -- Delegate to Navigator (PathNavigate-style)
    local nav = getNavigator(self, mob)
    return nav:moveToPosition(mob, goal, (mob.definition and mob.definition.walkSpeed) or nil, maxRangeBlocks)
end

function MobEntityService:_followPath(mob, speed, dt)
    local nav = getNavigator(self, mob)
    nav.speed = speed or nav.speed
    return nav:tick(self, mob, dt)
end
local function isEdgeAhead(self, position, direction, checkDistance)
    -- Check if there's a dangerous drop ahead using a 3-ray wedge (left/center/right)
	if not self.Deps or not self.Deps.VoxelWorldService or not self.Deps.VoxelWorldService.worldManager then
		return false
	end

	local wm = self.Deps.VoxelWorldService.worldManager
	if not wm then
		return false
	end

    local function hasDropAtOffset(dir)
        local checkPos = position + dir * checkDistance
	local blockX = math.floor(checkPos.X / BLOCK_SIZE)
	local blockZ = math.floor(checkPos.Z / BLOCK_SIZE)
	local currentY = math.floor(position.Y / BLOCK_SIZE)
	for blockY = currentY, math.max(1, currentY - 2), -1 do
		local block = wm:GetBlock(blockX, blockY, blockZ)
		-- Only treat truly solid blocks as ground; ignore cross-shaped/non-solid
		if isSolidForMobs(block) then
			local dropDistance = currentY - blockY
				local limit = self._safeDropBlocks or 1
				return dropDistance > limit
			end
		end
        return true -- No ground found = cliff edge
    end

    -- Build left/right directions (~20 degrees) and center
    local dir2 = Vector3.new(direction.X, 0, direction.Z)
    if dir2.Magnitude < 1e-5 then
    	return false
    end
    dir2 = dir2.Unit
    local yaw = math.atan2(dir2.X, dir2.Z)
    local function fromYaw(a)
        return Vector3.new(math.sin(a), 0, math.cos(a))
    end
    local left = fromYaw(yaw + math.rad(20))
    local right = fromYaw(yaw - math.rad(20))

    return hasDropAtOffset(dir2) or hasDropAtOffset(left) or hasDropAtOffset(right)
end

local function findPlayerWithTemptItem(self, position, players, temptItems, maxDistance)
    -- Minecraft-style temptation detection: Find players holding tempting items

    -- Handle both single items and arrays for robustness
    local temptItemList = {}
    if temptItems then
        if type(temptItems) == "table" then
            temptItemList = temptItems
        else
            -- Single item passed as number/string
            temptItemList = {temptItems}
        end
    end

    if #temptItemList == 0 then
        return nil, nil
    end

    local inv = self.Deps and self.Deps.PlayerInventoryService
    local voxel = self.Deps and self.Deps.VoxelWorldService

	local nearestPlayer = nil
	local nearestDistance = maxDistance or 10

	for _, player in ipairs(players) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and character then
			local distance = (root.Position - position).Magnitude
			if distance < nearestDistance then
				-- Line of sight check (raycast) from mob eye to player head/root
				local head = character:FindFirstChild("Head")
				local fromEye = Vector3.new(position.X, position.Y + BLOCK_SIZE * 1.6, position.Z)
				local toEye = head and head.Position or (root.Position + Vector3.new(0, BLOCK_SIZE * 0.9, 0))
				if hasLineOfSight(self, fromEye, toEye, {character}) then
					-- Check if player is holding a tempting item
                local hasTemptInHand = false
                local heldItemId = nil

                -- Method 1: Check selected hotbar slot
                local slot = voxel and voxel.GetSelectedHotbarSlot and voxel:GetSelectedHotbarSlot(player)
                if slot and inv and inv.GetHotbarSlot then
                    local stack = inv:GetHotbarSlot(player, slot)
                    if stack and stack.GetItemId then
                        heldItemId = stack:GetItemId()
                    end
                end

                -- Method 2: Fallback - check if player has tempting item equipped (could be extended)
                -- This ensures temptation works even if inventory system has issues

                if heldItemId then
                    for _, itemId in ipairs(temptItemList) do
                        if heldItemId == itemId then
                            hasTemptInHand = true
                            break
                        end
                    end
                end

                -- Additional check: Ensure player is alive and not incapacitated
                local humanoid = character:FindFirstChild("Humanoid")
                if hasTemptInHand and humanoid and humanoid.Health > 0 then
                    nearestPlayer = player
                    nearestDistance = distance
                end
			end
		end
	end

	end

	return nearestPlayer, nearestDistance
end

-- Small symmetric repulsion to reduce crowd cramming (XZ only)
function MobEntityService:_applyMobRepulsion(ctx, dt)
    if not self._entityRepulsionEnabled then
        return
    end

    local pushPerSec = (self._entityRepulsionMaxPushPerSecond or BLOCK_SIZE)

    -- Use processed set to ensure each pair is handled once
    local processed = {}
    local function pairKey(a, b)
        if a < b then
        	return a .. "|" .. b else return b .. "|" .. a
        end
    end

    for _, mob in pairs(ctx.mobsById) do
        if mob.position and mob.entityId then
            local baseCX, baseCZ = mob.chunkX, mob.chunkZ
            if not baseCX or not baseCZ then
                baseCX, baseCZ = worldPositionToChunk(mob.position)
            end

            for dz = -1, 1 do
                for dx = -1, 1 do
                    local key = chunkKey((baseCX or 0) + dx, (baseCZ or 0) + dz)
                    local bucket = ctx.mobsByChunk[key]
                    if bucket then
                        for otherId in pairs(bucket) do
                            if otherId ~= mob.entityId then
                                local other = ctx.mobsById[otherId]
                                if other and other.position and other.entityId then
									-- Skip repulsion for minions or stationary entities
									local skip = (mob.mobType == "COBBLE_MINION") or (mob.metadata and mob.metadata.stationary == true)
										or (other.mobType == "COBBLE_MINION") or (other.metadata and other.metadata.stationary == true)
									if not skip then
										local pk = pairKey(mob.entityId, other.entityId)
										if not processed[pk] then
											processed[pk] = true

                                        -- Horizontal separation check using per-entity radii
                                        local dxv = mob.position.X - other.position.X
                                        local dzv = mob.position.Z - other.position.Z
                                        local d2 = dxv * dxv + dzv * dzv
                                        if d2 > 1e-10 then
                                            local rA = getCollisionRadiusStuds(mob.definition)
                                            local rB = getCollisionRadiusStuds(other.definition)

                                            local sumR = rA + rB
                                            if d2 < (sumR * sumR) then
                                                local dist = math.sqrt(d2)
                                                if dist > 1e-6 then
                                                    local nx = dxv / dist
                                                    local nz = dzv / dist
                                                    local overlap = sumR - dist

                                                    -- Scale push by overlap ratio, cap to ~1 block/sec
                                                    local weight = math.clamp(overlap / sumR, 0, 1)
                                                    local dv = pushPerSec * weight

                                                    -- Symmetric velocity pushes
                                                    local vax = (mob.velocity and mob.velocity.X or 0) + nx * dv
                                                    local vaz = (mob.velocity and mob.velocity.Z or 0) + nz * dv
                                                    local vbx = (other.velocity and other.velocity.X or 0) - nx * dv
                                                    local vbz = (other.velocity and other.velocity.Z or 0) - nz * dv
                                                    mob.velocity = Vector3.new(vax, 0, vaz)
                                                    other.velocity = Vector3.new(vbx, 0, vbz)

                                                    -- Small symmetric positional nudge based on dv * dt, voxel-aware
                                                    local dxp = nx * dv * dt
                                                    local dzp = nz * dv * dt
                                                    local movedA = tryNudgeXZ(self, mob, dxp, dzp)
                                                    local movedB = tryNudgeXZ(self, other, -dxp, -dzp)
                                                    if movedA then
                                                    	self:_queueUpdate(mob)
                                                    end
                                                    if movedB then
                                                    	self:_queueUpdate(other)
                                                    end
                                                end
                                            end
                                        end
										end
									end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function MobEntityService:_updatePassiveMob(_ctx, mob, def, brain, dt)
	local players = self:_playersInWorld()
	local position = mob.position
	local now = os.clock()

	-- === PRIORITY 1: PANIC STATE ===
	-- Panic overrides all other behaviors (when recently damaged)
	if brain.panicUntil and now < brain.panicUntil then
		self:_updatePanicBehavior(mob, brain, def, position, dt, now)
		return
	end

	-- === PRIORITY 2: TEMPT STATE ===
	-- Check if player is holding tempting item (e.g., birch sapling for sheep)
	local temptMaxStuds = (def.temptMaxDistance or def.temptDistance or (BLOCK_SIZE * 10))
	local temptingPlayer = findPlayerWithTemptItem(self, position, players, def.temptItems, temptMaxStuds)

	-- Continue temptation if already tempted (maintain continuity)
	local alreadyTempted = brain.temptingPlayer and findPlayerWithTemptItem(self, position, {brain.temptingPlayer}, def.temptItems, temptMaxStuds)

	if temptingPlayer or alreadyTempted then
		local targetPlayer = temptingPlayer or brain.temptingPlayer
		-- Verify the tempting player is still in range and valid
		local playerRoot = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot and (playerRoot.Position - position).Magnitude <= temptMaxStuds then
			self:_updateTemptBehavior(mob, brain, def, position, targetPlayer, dt)
			return
		else
			-- Player moved out of range, clear temptation
			brain.temptingPlayer = nil
			brain.lastPlayerPos = nil
			brain.lastTargetPos = nil
		end
	end

	-- === PRIORITY 3: FLEE STATE (with hysteresis) ===
	local enterDist = def.fleeEnterDistance or def.fleeDistance or 0
	local exitDist = def.fleeExitDistance or enterDist
	if enterDist > 0 then
		local nearest = math.huge
		local nearestDelta
		for _, player in ipairs(players) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local delta = root.Position - position
				local dist = delta.Magnitude
				if dist < nearest then
					nearest = dist
					nearestDelta = delta
				end
			end
		end
		if brain.isFleeing then
			if nearest >= exitDist then
				brain.isFleeing = false
			else
				if nearestDelta and nearestDelta.Magnitude > 0 then
					self:_updateFleeBehavior(mob, brain, def, position, -nearestDelta.Unit, dt)
					return
				end
			end
		else
			if nearest < enterDist and nearestDelta and nearestDelta.Magnitude > 0 then
				brain.isFleeing = true
				self:_updateFleeBehavior(mob, brain, def, position, -nearestDelta.Unit, dt)
				return
			end
		end
	end

	-- === PRIORITY 4: GRAZE/IDLE STATE ===
	-- Grazing takes precedence over idle and persists for grazeUntil
	if brain.grazeUntil and now < brain.grazeUntil then
		mob.state = "graze"
		mob.velocity = Vector3.new()
		mob.groundY = updateGroundY(self, position)
		mob.position = Vector3.new(position.X, mob.groundY, position.Z)
		return
	end

	-- Plain idle fallback
	-- Stand still and occasionally look around
	if brain.idleUntil and now < brain.idleUntil then
		self:_updateIdleBehavior(mob, brain, position, dt, now)
		return
	end

	-- === PRIORITY 5: WANDER STATE ===
	-- Random wandering is the default behavior
	self:_updateWanderBehavior(mob, brain, def, position, dt, now)
end

function MobEntityService:_updatePanicBehavior(mob, brain, def, position, dt, _now)
	-- Minecraft panic: Run in random direction when damaged
	mob.state = "panic"

	-- If no panic target, pick a random direction to run
	if not brain.panicTarget then
		local panicDir = pickRandomOffset(self._rng, 1).Unit
		brain.panicTarget = position + panicDir * (def.wanderRadius or 20)
	end

	local speed = def.runSpeed or def.walkSpeed
	local needRepath = (not brain.path) or (not brain.pathTarget) or ((brain.pathTarget - brain.panicTarget).Magnitude > 2) or (os.clock() >= (brain.repathAt or 0))
	if needRepath then
		self:_planPathTo(mob, brain.panicTarget, 48)
	end
	if not self:_followPath(mob, speed, dt) then
		local moved = moveRespectingVoxels(self, mob, brain.panicTarget - position, speed, dt)
		if not moved then
			local panicDir = pickRandomOffset(self._rng, 1).Unit
			brain.panicTarget = position + panicDir * (def.wanderRadius or 20)
			self:_clearPath(mob)
		end
	end
end

function MobEntityService:_updateTemptBehavior(mob, brain, def, position, player, dt)
	-- Concise temptation: follow player with item using internal pathfinder
	mob.state = "tempt"
	brain.idleUntil = 0
	brain.wanderTarget = nil
	brain.panicUntil = 0

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local delta = root.Position - position
	local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
	local distance = horizontalDelta.Magnitude

	-- Stop when within 1 block
	if distance < BLOCK_SIZE then
		mob.velocity = Vector3.new()
		mob.state = "idle"
		brain.temptingPlayer = nil
		return
	end

    brain.temptingPlayer = player
    local speed = (def.walkSpeed or 4) * 1.25
    local target = Vector3.new(root.Position.X, position.Y, root.Position.Z)

    -- Minecraft-like: frequent repath to moving target, no direct-move fallback
    local nav = getNavigator(self, mob)
    nav.repathCooldown = 0.35
    nav.stuckSeconds = 0.6
    nav.speed = speed

    local now = os.clock()
    local needRepath = (not brain.path)
        or (not brain.pathTarget)
        or ((brain.pathTarget - target).Magnitude > 1.4) -- tighter threshold to follow turns
        or (now >= (brain.repathAt or 0))
    if needRepath then
        local temptMaxStuds = (def.temptMaxDistance or def.temptDistance or (BLOCK_SIZE * 10))
        local maxRangeBlocks = math.max(1, math.floor(temptMaxStuds / BLOCK_SIZE))
        self:_planPathTo(mob, target, maxRangeBlocks)
        brain.repathAt = now + 0.35
    end

    -- Follow path only; avoid sliding into walls in narrow corridors
    self:_followPath(mob, speed, dt)

	-- End temptation if item no longer held or too far
	local temptMaxStuds = (def.temptMaxDistance or def.temptDistance or (BLOCK_SIZE * 10))
	local stillTempting = findPlayerWithTemptItem(self, position, {player}, def.temptItems, temptMaxStuds)
	if not stillTempting then
		brain.temptingPlayer = nil
	end
end

function MobEntityService:_updateFleeBehavior(mob, brain, def, position, fleeDir, dt)
	-- Flee from nearby player
	mob.state = "flee"
	brain.idleUntil = 0
	brain.wanderTarget = nil
	brain.grazeUntil = 0

	local speed = def.runSpeed or def.walkSpeed
	local fleeTargetDistance = math.min((def.fleeDistance or 10) * 1.5, def.wanderRadius or 20)
	local targetPos = position + fleeDir * fleeTargetDistance

    -- Edge avoidance: don't run off cliffs when fleeing
    local dirCheck = Vector3.new(targetPos.X - position.X, 0, targetPos.Z - position.Z)
    local direction = dirCheck.Magnitude > 0 and dirCheck.Unit or Vector3.new()
    if direction.Magnitude > 0 and isEdgeAhead(self, position, direction, 2) then
        -- Turn 90 degrees and continue fleeing
        direction = Vector3.new(-direction.Z, 0, direction.X)
        targetPos = position + direction * fleeTargetDistance
    end

	local needRepath = (not brain.path) or (not brain.pathTarget) or ((brain.pathTarget - targetPos).Magnitude > 2) or (os.clock() >= (brain.repathAt or 0))
	if needRepath then
		self:_planPathTo(mob, targetPos, 48)
	end
	if not self:_followPath(mob, speed, dt) then
		moveRespectingVoxels(self, mob, targetPos - position, speed, dt)
	end
end

function MobEntityService:_updateIdleBehavior(mob, brain, position, dt, now)
	-- Stand still and occasionally rotate to look around
	mob.state = "idle"
	mob.velocity = Vector3.new()

	-- Random look direction (rotate slowly while idle)
	if not brain.lookRotation then
		brain.lookRotation = mob.rotation
		brain.nextLookChange = now + self._rng:NextNumber(2, 5)
	end

	if now >= brain.nextLookChange then
		-- Pick new look direction
		brain.lookRotation = self._rng:NextNumber(0, 360)
		brain.nextLookChange = now + self._rng:NextNumber(2, 5)
	end

	-- Smoothly rotate toward look direction
	local rotDelta = brain.lookRotation - mob.rotation
	if rotDelta > 180 then
		rotDelta = rotDelta - 360
	end
	if rotDelta < -180 then
		rotDelta = rotDelta + 360
	end
	mob.rotation = mob.rotation + rotDelta * dt * 2  -- Slow rotation

	-- Update ground while idle: allow snap down, never snap up
	local ok, gY, gBY = probeFootprint(self, position.X, position.Z, position.Y)
	if ok and gY and gBY then
		local currentBY = math.floor((mob.groundY or position.Y) / BLOCK_SIZE)
		if gBY <= currentBY then
			mob.groundY = gY
			mob.position = Vector3.new(position.X, mob.groundY, position.Z)
		end
	end
end

function MobEntityService:_updateWanderBehavior(mob, brain, def, position, dt, now)
	-- Random wandering with occasional pauses
	mob.state = "wander"

	-- Check if we need a new wander target
	if not brain.wanderTarget then
		-- Pick new wander target
		local basePos = mob.spawnPosition or Vector3.new(
			mob.spawnChunk[1] * CHUNK_STUD_SIZE_X + CHUNK_STUD_SIZE_X / 2,
			mob.groundY,
			mob.spawnChunk[2] * CHUNK_STUD_SIZE_Z + CHUNK_STUD_SIZE_Z / 2
		)
		local wanderRadius = (def.wanderRadius or (CHUNK_STUD_SIZE_X / 2)) / BLOCK_SIZE
		local candidate = getRandomWalkableWithinRadius(self, basePos.X, basePos.Z, mob.groundY, wanderRadius, self._rng, 12)
		if candidate then
			brain.wanderTarget = candidate
		else
			-- Could not find a walkable target now; idle briefly
			brain.idleUntil = now + self._rng:NextNumber(1, 2)
			return
		end

		-- Debug log
		Debug(self, "New wander target", {
			entityId = mob.entityId,
			from = position,
			to = brain.wanderTarget,
			distance = (brain.wanderTarget - position).Magnitude
		})
	end

	local delta = brain.wanderTarget - position
	local horizontalDelta = Vector3.new(delta.X, 0, delta.Z)
	local distanceToTarget = horizontalDelta.Magnitude

	if distanceToTarget < 1 then
		-- Reached target
		brain.wanderTarget = nil

		-- Randomly decide to idle, graze, or continue wandering
		local idleChance = 0.15
		local grazeChance = 0.6

		local roll = self._rng:NextNumber()
		if roll < idleChance then
			-- Enter idle state
			local wanderInterval = def.wanderInterval or { min = 3, max = 8 }
			local idleDuration = self._rng:NextNumber(wanderInterval.min, wanderInterval.max)
			brain.idleUntil = now + idleDuration
			brain.lookRotation = nil
			mob.velocity = Vector3.new()
			Debug(self, "Mob entering idle", { entityId = mob.entityId, duration = idleDuration })
		elseif roll < idleChance + grazeChance then
			-- Enter graze state (more Minecraft-like)
			local grazeDuration = self._rng:NextNumber(4, 8)
			brain.grazeUntil = now + grazeDuration
			mob.state = "graze"
			mob.velocity = Vector3.new()
			Debug(self, "Mob grazing", { entityId = mob.entityId, duration = grazeDuration })
		end
		return
	end

	local direction = horizontalDelta.Unit

	-- Edge avoidance: prevent wandering off cliffs
	if isEdgeAhead(self, position, direction, 2) then
		-- Cancel current wander target and pick new one
		brain.wanderTarget = nil
		mob.velocity = Vector3.new()
		Debug(self, "Edge detected, canceling wander", { entityId = mob.entityId })
		return
	end

    local speed = def.walkSpeed
    local needRepath = (not brain.path) or (not brain.pathTarget) or ((brain.pathTarget - brain.wanderTarget).Magnitude > 2) or (os.clock() >= (brain.repathAt or 0))
    if needRepath then
        self:_planPathTo(mob, brain.wanderTarget, math.ceil((def.wanderRadius or 24) / BLOCK_SIZE) + 8)
    end
    if not self:_followPath(mob, speed, dt) then
        local moved = moveRespectingVoxels(self, mob, direction, speed, dt)
        if not moved then
            if not attemptEmergencyStepDown(self, mob) then
            brain.wanderTarget = nil
            mob.velocity = Vector3.new()
            end
        end
    end

	-- Debug movement
	if self._debugEnabled and self._updateAccumulator == 0 then
		Debug(self, "Mob moving", {
			entityId = mob.entityId,
			position = mob.position,
			velocity = mob.velocity,
			distanceToTarget = distanceToTarget
		})
	end
end

function MobEntityService:_updateHostileMob(_ctx, mob, def, brain, dt)
	local targetPlayer, targetRoot
	local position = mob.position
	local players = self:_playersInWorld()
	local bestDist = math.huge

	for _, player in ipairs(players) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local dist = (root.Position - position).Magnitude
			if dist < bestDist and dist <= (def.aggroRange or 0) then
				-- Require line of sight from zombie eye to player head/root
				local character = player.Character
				local head = character and character:FindFirstChild("Head")
				local fromEye = Vector3.new(position.X, (mob.groundY or position.Y) + BLOCK_SIZE * 1.6, position.Z)
				local toEye = (head and head.Position) or (root.Position + Vector3.new(0, BLOCK_SIZE * 0.9, 0))
				if hasLineOfSight(self, fromEye, toEye, {character}) then
					bestDist = dist
					targetPlayer = player
					targetRoot = root
				end
			end
		end
	end

	if targetPlayer and targetRoot then
		brain.targetPlayer = targetPlayer
		local targetPos = targetRoot.Position
		local delta = targetPos - position
		local _distance = delta.Magnitude
		local speed = def.runSpeed or def.walkSpeed
		mob.state = "chase"

		-- Hold position when within 1 block horizontally; just face the player
		local horizDelta = Vector3.new(delta.X, 0, delta.Z)
		local horizDist = horizDelta.Magnitude
		local faceYaw = (horizDist > 1e-4) and math.deg(math.atan2(horizDelta.X, horizDelta.Z)) or mob.rotation
		if horizDist <= BLOCK_SIZE then
			mob.velocity = Vector3.new()
			mob.rotation = faceYaw
			local nav = getNavigator(self, mob)
			nav:clearPath(mob)
		else
			if def.useAdvancedPathfinding then
			local needRepath = (not brain.path) or (not brain.pathTarget) or ((brain.pathTarget - targetPos).Magnitude > 2) or (os.clock() >= (brain.repathAt or 0))
			if needRepath then
				self:_planPathTo(mob, targetPos, 48)
				brain.repathAt = os.clock() + 0.35
			end
			if not self:_followPath(mob, speed, dt) then
				local direction = delta.Magnitude > 0 and delta.Unit or Vector3.new(0, 0, 0)
				moveRespectingVoxels(self, mob, direction, speed, dt)
			end
			if mob.velocity.Magnitude > 0 then
				mob.rotation = math.deg(math.atan2(mob.velocity.X, mob.velocity.Z))
			end
		else
			local direction = delta.Magnitude > 0 and delta.Unit or Vector3.new(0, 0, 0)
			mob.velocity = direction * speed
			mob.rotation = math.deg(math.atan2(direction.X, direction.Z))
			mob.position = Vector3.new(position.X + mob.velocity.X * dt, mob.groundY, position.Z + mob.velocity.Z * dt)
		end
		end

		if horizDist <= (def.attackRange or (BLOCK_SIZE * 2)) then
			local now = os.clock()
			if now - (brain.lastAttackTime or 0) >= (def.attackCooldown or 1.5) then
				brain.lastAttackTime = now
				self:_applyMeleeDamage(targetPlayer, def.baseDamage or 2)
				mob.state = "attack"
			end
		end
	else
		mob.velocity = Vector3.new()
		mob.state = "idle"
	end
end

function MobEntityService:_applyMeleeDamage(player, damage)
	if not player or damage <= 0 then
		return
	end
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:TakeDamage(damage)
	end
end

function MobEntityService:_maybeSpawnNatural(_ctx, _chunkX, _chunkZ, _skip)
	-- Natural mob spawning disabled (no zombies or passive mobs)
	return
end

function MobEntityService:_countMobsByCategory(ctx, category)
	local count = 0
	for _, mob in pairs(ctx.mobsById) do
		if mob.definition and mob.definition.category == category then
			count += 1
		end
	end
	return count
end

function MobEntityService:_findSpawnPosition(chunkX, chunkZ)
	if not self.Deps or not self.Deps.VoxelWorldService or not self.Deps.VoxelWorldService.worldManager then
		return nil
	end
	local wm = self.Deps.VoxelWorldService.worldManager
	if not wm then
		return nil
	end

	for _ = 1, 5 do
		local blockX = chunkX * Constants.CHUNK_SIZE_X + self._rng:NextInteger(0, Constants.CHUNK_SIZE_X - 1)
		local blockZ = chunkZ * Constants.CHUNK_SIZE_Z + self._rng:NextInteger(0, Constants.CHUNK_SIZE_Z - 1)
		for blockY = Constants.WORLD_HEIGHT - 1, 1, -1 do
			local block = wm:GetBlock(blockX, blockY, blockZ)
			local above = wm:GetBlock(blockX, blockY + 1, blockZ)
			if block ~= Constants.BlockType.AIR and above == Constants.BlockType.AIR then
				local worldX = blockX * BLOCK_SIZE + BLOCK_SIZE / 2
				local worldY = blockY * BLOCK_SIZE + BLOCK_SIZE + 0.01
				local worldZ = blockZ * BLOCK_SIZE + BLOCK_SIZE / 2
				return Vector3.new(worldX, worldY, worldZ)
			end
		end
	end
	return nil
end

function MobEntityService:_onHeartbeat(dt)
	self._updateAccumulator += dt
	self._broadcastTimer += dt
	-- Minion throttling accumulator (per service)
	self._minionUpdateInterval = self._minionUpdateInterval or 0.5
	self._minionUpdateAccumulator = (self._minionUpdateAccumulator or 0) + dt

	if self._updateAccumulator >= self._updateInterval then
		local step = self._updateAccumulator
		self._updateAccumulator = 0
		for _, ctx in pairs(self._worlds) do
			-- Determine if minions should be processed this cycle; reset per-ctx claim set
			local minionTick = false
			if self._minionUpdateAccumulator >= self._minionUpdateInterval then
				self._minionUpdateAccumulator -= self._minionUpdateInterval
				minionTick = true
				ctx._minionClaims = {}
			end
			for _, mob in pairs(ctx.mobsById) do
				-- Skip minion updates on most frames; only run when minionTick is true
				if mob.mobType == "COBBLE_MINION" or (mob.metadata and mob.metadata.stationary == true) then
					if minionTick then
						self:_updateMob(ctx, mob, step)
					end
				else
					self:_updateMob(ctx, mob, step)
				end
			end
			-- Apply small horizontal repulsion after movement to reduce crowd cramming
			self:_applyMobRepulsion(ctx, step)
		end
	end

	if self._broadcastTimer >= self._broadcastInterval then
		self._broadcastTimer = 0
		self:_flushUpdates()
	end
end

function MobEntityService:DamageMob(entityId, amount, player)
	local ctx = ensureWorldContext(self)
	local mob = ctx.mobsById[entityId]
	if not mob then
		return
	end

	-- Unattackable mobs (e.g., minions) ignore damage
	if mob.metadata and mob.metadata.unattackable == true then
		return
	end

	mob.health = math.max(0, mob.health - amount)

	-- Apply horizontal knockback away from attacker (voxel-aware)
	if mob.health > 0 then
		local kb = (CombatConfig and CombatConfig.KNOCKBACK_STRENGTH) or 0
		if kb > 0 and player then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local away = Vector3.new(mob.position.X - root.Position.X, 0, mob.position.Z - root.Position.Z)
				if away.Magnitude > 1e-3 then
					local dir = away.Unit
					local pushDist = kb * 0.15
					local dx = dir.X * pushDist
					local dz = dir.Z * pushDist
					-- Try a small nudge respecting step limits and ground
					pcall(function()
						tryNudgeXZ(self, mob, dx, dz)
					end)
					-- Brief velocity for visual feedback/interp
					mob.velocity = dir * (kb * 0.8)
				end
			end
		end
	end

	self:_queueUpdate(mob)

	-- Trigger panic state for passive mobs (Minecraft behavior)
	if mob.definition and mob.definition.category == MobRegistry.Categories.PASSIVE then
		local panicDuration = mob.definition.panicDuration or 5  -- Default 5 seconds of panic
		mob.brain.panicUntil = os.clock() + panicDuration
		mob.brain.panicTarget = nil  -- Will be set when panic behavior runs
		mob.brain.wanderTarget = nil  -- Clear wander target
		mob.brain.idleUntil = 0  -- Cancel idle
	end

	EventManager:FireEventToAll("MobDamaged", {
		entityId = entityId,
		health = mob.health,
		maxHealth = mob.maxHealth,
		mobType = mob.mobType,
		attackerUserId = player and player.UserId or nil
	})

	if mob.health <= 0 then
		self:_handleMobDeath(ctx, mob, player)
	end
end

function MobEntityService:_handleMobDeath(ctx, mob, _player)
	removeMobFromChunk(ctx, mob)
	ctx.mobsById[mob.entityId] = nil

	EventManager:FireEventToAll("MobDied", {
		entityId = mob.entityId,
		mobType = mob.mobType,
		position = vectorToArray(mob.position)
	})

	if self.Deps and self.Deps.DroppedItemService then
		local dropService = self.Deps.DroppedItemService
		for _, drop in ipairs(mob.definition.drops or {}) do
			if self._rng:NextNumber() <= (drop.chance or 1) then
				local count = self._rng:NextInteger(drop.min or 1, drop.max or drop.min or 1)
				dropService:SpawnItem(drop.itemId, count, mob.position, Vector3.new(0, 2, 0), false)
			end
		end
	end
end

function MobEntityService:HandleAttackMob(player, data)
	if not data or not data.entityId or not player then
		return
	end
	local ctx = ensureWorldContext(self)
	local mob = ctx.mobsById[data.entityId]
	if not mob then
		return
	end

	-- Ignore attacks on invincible/static minions
	if mob.mobType == "COBBLE_MINION" or (mob.metadata and mob.metadata.unattackable == true) then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local reach = (CombatConfig and CombatConfig.REACH_STUDS) or 10
	local distance = (root.Position - mob.position).Magnitude
	if distance > reach then
		return
	end

	-- Compute damage using unified config (supports swords, axes, pickaxes, shovels, or hand)
	local toolType, toolTier
	local voxel = self.Deps and self.Deps.VoxelWorldService
	if voxel and voxel.players and voxel.players[player] and voxel.players[player].tool then
		local t = voxel.players[player].tool
		toolType = t and t.type
		toolTier = t and t.tier
	end
	local dmg = (CombatConfig and CombatConfig.GetMeleeDamage) and CombatConfig.GetMeleeDamage(toolType, toolTier) or ((CombatConfig and CombatConfig.HAND_DAMAGE) or 2)
	self:DamageMob(mob.entityId, dmg, player)
end

return MobEntityService


