--[[
	VoxelWorldService.lua
	Server-side voxel world management service
	Simplified for single player-owned world per server instance
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Core voxel modules
local VoxelWorld = require(ReplicatedStorage.Shared.VoxelWorld)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local Config = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)
local WorldTypes = require(ReplicatedStorage.Shared.VoxelWorld.Core.WorldTypes)
local ChunkCompressor = require(ReplicatedStorage.Shared.VoxelWorld.Memory.ChunkCompressor)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local BlockBreakTracker = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockBreakTracker)
local BlockPlacementRules = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockPlacementRules)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)
local SaplingConfig = require(ReplicatedStorage.Configs.SaplingConfig)

local VoxelWorldService = {
	Name = "VoxelWorldService"
}

local SPAWN_CHUNK_STREAM_WAIT = 0.15

-- Standardize and gate module-local prints through Logger at DEBUG level
local _logger = Logger:CreateContext("VoxelWorldService")
local function _toString(v)
    return tostring(v)
end
local function _concatArgs(...)
    local n = select("#", ...)
    local parts = table.create(n)
    for i = 1, n do
        parts[i] = _toString(select(i, ...))
    end
    return table.concat(parts, " ")
end
local print = function(...)
    _logger.Debug(_concatArgs(...))
end
local warn = function(...)
    _logger.Warn(_concatArgs(...))
end

local function _isMinionBlock(blockId)
	return blockId == Constants.BlockType.COBBLESTONE_MINION
		or blockId == Constants.BlockType.COAL_MINION
end

local function _defaultMinionTypeForBlock(blockId)
	if blockId == Constants.BlockType.COAL_MINION then
		return "COAL"
	end
	return "COBBLESTONE"
end

-- Internal: combat tagging helpers
function VoxelWorldService:_refreshCombatTagForCharacter(character, now)
    if not character then return end
    local ttl = CombatConfig.COMBAT_TTL_SECONDS or 8
    local expiresAt = now + ttl

    -- Mark as in combat and set expiry
    pcall(function()
        character:SetAttribute("IsInCombat", true)
        character:SetAttribute("CombatExpiresAt", expiresAt)
    end)

    -- Schedule a delayed check to clear the tag after TTL (if not refreshed)
    task.delay(ttl + 0.05, function()
        local ok, currentExpiry = pcall(function()
            return character:GetAttribute("CombatExpiresAt")
        end)
        if not ok then return end
        if type(currentExpiry) ~= "number" then return end
        if os.clock() >= currentExpiry then
            pcall(function()
                character:SetAttribute("IsInCombat", false)
            end)
        end
    end)
end

function VoxelWorldService:_tagCombat(attackerChar, victimChar)
    local now = os.clock()
    -- Attacker enters combat as well
    self:_refreshCombatTagForCharacter(attackerChar, now)
    -- Victim enters combat and records last hit time for client flash
    self:_refreshCombatTagForCharacter(victimChar, now)
    pcall(function()
        victimChar:SetAttribute("LastHitAt", now)
    end)
end

-- Initialize service
function VoxelWorldService:Init()
	-- Single world instance for this server
	self.world = nil
	self.worldManager = nil
	self.renderDistance = 6
	self.worldTypeId = "player_world"
	self.worldDescriptor = WorldTypes:Get("player_world")
	self.isHubWorld = false

	-- Player tracking
	self.players = {} -- Map of Player -> {position, chunks, tool}
	self.chunkViewers = {} -- Map of chunkKey -> set of players viewing it
	self.chunkLastAccess = {} -- Map of chunkKey -> last access os.clock()

	-- Block breaking tracker
	self.blockBreakTracker = BlockBreakTracker.new()

	-- Per-player rate limits
	self.rateLimits = {} -- Player -> {chunkWindowStart, chunksSent, modWindowStart, mods, lastPunch}

	-- Statistics
	self.stats = {
		chunksLoaded = 0,
		chunksStreamed = 0,
		chunksUnloaded = 0,
		blockChanges = 0,
		lastStreamTimeMs = 0
	}

	-- Chunk modifications tracking (for saving)
	self.modifiedChunks = {} -- Set of chunk keys that need saving

	-- Cobblestone Minion tracking
	self.minionByBlockKey = {} -- "x,y,z" -> entityId
	self.blockKeyByMinion = {} -- entityId -> "x,y,z"
	self.minionStateByBlockKey = {} -- "x,y,z" -> {level=1..4, slotsUnlocked=1..4}
	-- Minion UI viewer tracking
	self.minionViewers = {} -- "x,y,z" -> { [player] = true }
	self.playerMinionView = {} -- player -> "x,y,z"

	print("VoxelWorldService: Initialized (single player-owned world)")
end

-- Handle player melee hit request (PvP)
function VoxelWorldService:HandlePlayerMeleeHit(player: Player, data)
    if not data or not data.targetUserId then return end
    local now = os.clock()

    -- Rate limit by swing cooldown
    local rl = self.rateLimits[player]
    if not rl then
        rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0}
        self.rateLimits[player] = rl
    end
    rl.lastMelee = rl.lastMelee or 0
    if (now - rl.lastMelee) < (CombatConfig.SWING_COOLDOWN or 0.35) then
        return
    end
    rl.lastMelee = now

    -- Validate attacker character
    local attackerChar = player.Character
    if not attackerChar then return end
    local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart")
    if not attackerRoot then return end

    -- Validate victim
    local victim = nil
    for _, plr in ipairs(game.Players:GetPlayers()) do
        if plr.UserId == data.targetUserId then
            victim = plr
            break
        end
    end
    if not victim or victim == player then return end
    local victimChar = victim.Character
    if not victimChar then return end
    local victimRoot = victimChar:FindFirstChild("HumanoidRootPart")
    local victimHum = victimChar:FindFirstChildOfClass("Humanoid")
    if not victimRoot or not victimHum or victimHum.Health <= 0 then return end

    -- Determine attacker tool (sword or empty hand)
    local toolType, toolTier
    do
        local playerData = self.players[player]
        if playerData and playerData.tool and playerData.tool.slotIndex and self.Deps and self.Deps.PlayerInventoryService then
            local slotIndex = playerData.tool.slotIndex
            local stack = self.Deps.PlayerInventoryService:GetHotbarSlot(player, slotIndex)
            if stack and not stack:IsEmpty() then
                local itemId = stack:GetItemId()
                if ToolConfig.IsTool(itemId) then
                    local tType, tTier = ToolConfig.GetBlockProps(itemId)
                    toolType, toolTier = tType, tTier
                end
            end
        end
        -- If no tool or non-sword, treat as empty hand punch
    end

    -- Distance check
    local reach = CombatConfig.REACH_STUDS or 10
    if (attackerRoot.Position - victimRoot.Position).Magnitude > reach then
        return
    end

    -- FOV check
    local fov = (CombatConfig.FOV_DEGREES or 60)
    local forward = attackerRoot.CFrame.LookVector
    local dir = (victimRoot.Position - attackerRoot.Position).Unit
    local dot = forward:Dot(dir)
    local angle = math.deg(math.acos(math.clamp(dot, -1, 1)))
    if angle > fov then return end

    -- Optional: simple line-of-sight raycast
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    rayParams.FilterDescendantsInstances = {attackerChar}
    local result = workspace:Raycast(attackerRoot.Position, (victimRoot.Position - attackerRoot.Position), rayParams)
    if result and result.Instance and result.Instance:IsDescendantOf(victimChar) == false then
        -- Hit something else first
        -- allow slight occlusion tolerance; skip rejection for now to reduce false negatives
    end

    -- Compute damage using unified config (supports swords, axes, pickaxes, shovels, or hand)
    local rawDmg = CombatConfig.GetMeleeDamage(toolType, toolTier)

    -- Apply damage through DamageService (handles armor reduction)
    local DamageService = self.Deps and self.Deps.DamageService
    local finalDmg = rawDmg
    if DamageService then
        finalDmg = DamageService:DamagePlayer(victim, rawDmg, "melee", player)
    else
        -- Fallback if DamageService not available
        victimHum:TakeDamage(rawDmg)
    end

    -- Optional knockback
    local kb = CombatConfig.KNOCKBACK_STRENGTH or 0
    if kb > 0 then
        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        bodyVel.Velocity = dir * kb + Vector3.new(0, kb * 0.25, 0)
        bodyVel.Parent = victimRoot
        game:GetService("Debris"):AddItem(bodyVel, 0.2)
    end

    -- Broadcast damage event for feedback (legacy event for animations)
    pcall(function()
        require(ReplicatedStorage.Shared.EventManager):FireEventToAll("PlayerDamaged", {
            attackerUserId = player.UserId,
            victimUserId = victim.UserId,
            amount = finalDmg
        })
        require(ReplicatedStorage.Shared.EventManager):FireEventToAll("PlayerSwordSwing", {
            userId = player.UserId
        })
    end)

    -- Apply combat tags and victim flash
    self:_tagCombat(attackerChar, victimChar)
end

-- Handle client request to open minion UI
function VoxelWorldService:HandleOpenMinion(player, data)
	if not data or not data.x or not data.y or not data.z then
		return
	end
	-- No longer require a special block; use anchor position instead.
	local key = string.format("%d,%d,%d", data.x, data.y, data.z)
	local state = self.minionStateByBlockKey[key]
	if not state then
		state = { level = 1, slotsUnlocked = 1, type = "COBBLESTONE" }
		self.minionStateByBlockKey[key] = state
	end
	-- Compute timing/costs from MinionConfig
	local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
	state.type = state.type or "COBBLESTONE"
	local maxLevel = (MinionConfig.GetTypeDef(state.type).maxLevel or 4)
	local waitSec = MinionConfig.GetWaitSeconds(state.type, state.level)
	local costNext = (state.level < maxLevel) and MinionConfig.GetUpgradeCost(state.type, state.level) or 0

	-- Initialize slots if absent
	if not state.slots then
		state.slots = {}
		for i = 1, 12 do
			state.slots[i] = { itemId = 0, count = 0 }
		end
	end

	-- Serialize slots for client
	local slotsData = {}
	for i = 1, 12 do
		if state.slots[i] then
			slotsData[i] = {
				itemId = state.slots[i].itemId or 0,
				count = state.slots[i].count or 0
			}
		end
	end

	-- If player is already viewing this minion, avoid re-sending MinionOpened (prevents duplicate UI)
	if self.playerMinionView[player] == key then
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("MinionUpdated", player, {
			state = {
				type = state.type,
				level = state.level,
				slotsUnlocked = state.slotsUnlocked,
				waitSeconds = waitSec,
				nextUpgradeCost = costNext,
				slots = slotsData
			}
		})
		return
	end

	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	EventManager:FireEvent("MinionOpened", player, {
		anchorPos = { x = data.x, y = data.y, z = data.z },
		state = {
			type = state.type,
			level = state.level,
			slotsUnlocked = state.slotsUnlocked,
			waitSeconds = waitSec,
			nextUpgradeCost = costNext,
			slots = slotsData
		}
	})

	-- Track viewer subscription
	self.minionViewers[key] = self.minionViewers[key] or {}
	self.minionViewers[key][player] = true
	self.playerMinionView[player] = key
end

-- Handle open UI by entity id (clicking the mob model)
function VoxelWorldService:HandleOpenMinionByEntity(player, data)
	if not data or not data.entityId then return end
	local entityId = data.entityId
	-- Try both string and numeric keys
	local key = nil
	local isMinionEntity = false
	if self.blockKeyByMinion then
		key = self.blockKeyByMinion[entityId] or self.blockKeyByMinion[tonumber(entityId)] or self.blockKeyByMinion[tostring(entityId)]
		if key then
			isMinionEntity = true
		end
	end
	if not key then
		-- Fallback: try to locate mob and infer anchor from spawnPosition
		local mobService = self.Deps and self.Deps.MobEntityService
		if mobService and mobService._worlds then
			for _, ctx in pairs(mobService._worlds) do
				local mob = ctx.mobsById[tonumber(entityId)] or ctx.mobsById[tostring(entityId)]
				if mob then
					if mob.mobType ~= "COBBLE_MINION" then
						-- Not a minion entity; ignore request
						return
					end
					isMinionEntity = true
				end
				if mob and mob.spawnPosition then
					local bs = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants).BLOCK_SIZE
					local x = math.floor(mob.spawnPosition.X / bs)
					local y = math.floor(mob.spawnPosition.Y / bs) - 1
					local z = math.floor(mob.spawnPosition.Z / bs)
					key = string.format("%d,%d,%d", x, y, z)
					break
				end
			end
		end
	end
	-- If we still haven't confirmed it's a minion entity, reject
	if not isMinionEntity then
		return
	end
	if not key then return end
	local x, y, z = string.match(key, "(-?%d+),(-?%d+),(-?%d+)")
	x, y, z = tonumber(x), tonumber(y), tonumber(z)
	if not x then return end
	-- Reuse HandleOpenMinion state logic but with derived coordinates
	return self:HandleOpenMinion(player, { x = x, y = y, z = z })
end

-- Handle minion upgrade: spend cobblestone, level up, unlock slot, lower wait
function VoxelWorldService:HandleMinionUpgrade(player, data)
	if not data or not data.x or not data.y or not data.z then
		return
	end
	local key = string.format("%d,%d,%d", data.x, data.y, data.z)
	local state = self.minionStateByBlockKey[key]
	if not state then
		state = { level = 1, slotsUnlocked = 1, type = "COBBLESTONE" }
		self.minionStateByBlockKey[key] = state
	end
	local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
	state.type = state.type or "COBBLESTONE"
	local maxLevel = (MinionConfig.GetTypeDef(state.type).maxLevel or 4)
	if state.level >= maxLevel then
		return
	end
	local cost = MinionConfig.GetUpgradeCost(state.type, state.level)
	-- Charge appropriate item from inventory
	if self.Deps and self.Deps.PlayerInventoryService then
		local inv = self.Deps.PlayerInventoryService
		local itemId = MinionConfig.GetUpgradeItemId(state.type)
		local have = inv:GetItemCount(player, itemId)
		if have < cost then
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("ShowError", player, { message = "Not enough materials" })
			return
		end
		local ok = inv:RemoveItem(player, itemId, cost)
		if not ok then
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("ShowError", player, { message = "Failed to consume materials" })
			return
		end
	end
	-- Apply upgrade
	state.level = math.min(maxLevel, state.level + 1)
	state.slotsUnlocked = math.min(12, (state.slotsUnlocked or 1) + 1)
	local waitSec = MinionConfig.GetWaitSeconds(state.type, state.level)
	local nextCost = (state.level < maxLevel) and MinionConfig.GetUpgradeCost(state.type, state.level) or 0
	-- Broadcast to all viewers for this anchor
	self:_broadcastMinionState(key)
end

-- Handle collect all items from minion
function VoxelWorldService:HandleMinionCollectAll(player, data)
	if not data or not data.x or not data.y or not data.z then return end

	local key = string.format("%d,%d,%d", data.x, data.y, data.z)
	local state = self.minionStateByBlockKey[key]
	if not state or not state.slots then
		print(string.format("[Minion] CollectAll: no state for %s by %s", key, player and player.Name or "?"))
		local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
		EventManager:FireEvent("ShowError", player, { message = "Minion not found or empty" })
		return
	end

	local inv = self.Deps and self.Deps.PlayerInventoryService
	if not inv then
		print("[Minion] CollectAll: PlayerInventoryService not available")
		return
	end

	print(string.format("[Minion] CollectAll: %s requested at %s", player.Name, key))

	-- Collect all items from unlocked slots
	local collected = 0
	local attempted = 0
	for i = 1, math.min(12, state.slotsUnlocked or 1) do
		local slot = state.slots[i]
		if slot and slot.itemId and slot.itemId > 0 and slot.count and slot.count > 0 then
			attempted += slot.count
			-- Add as much as possible respecting stack limits; clear or reduce slot
			local toMove = slot.count
			local addedCount = inv.AddItemCount and inv:AddItemCount(player, slot.itemId, toMove) or (inv:AddItem(player, slot.itemId, toMove) and toMove or 0)
			if addedCount > 0 then
				collected = collected + addedCount
				local remaining = slot.count - addedCount
				if remaining <= 0 then
					slot.itemId = 0
					slot.count = 0
				else
					slot.count = remaining
				end
			end
		end
	end

	-- Always sync updated slots to client (even if nothing was collected) to reflect partial moves
	-- Broadcast to all viewers (reflect partial or full moves)
	self:_broadcastMinionState(key)

	-- Feedback to requester
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	if collected > 0 then
		print(string.format("[Minion] CollectAll: moved %d/%d items at %s for %s", collected, attempted, key, player.Name))
		EventManager:FireEvent("ShowNotification", player, {
			title = "Minion",
			message = string.format("Collected %d item(s)", collected)
		})
	end
	-- If nothing moved but there were items, show an error (likely inventory full)
	if collected == 0 and attempted > 0 then
		print(string.format("[Minion] CollectAll: inventory full for %s at %s (attempted %d)", player.Name, key, attempted))
		EventManager:FireEvent("ShowError", player, { message = "Inventory full" })
	end
end

-- Handle pickup minion: despawn, remove state, return item to player
function VoxelWorldService:HandleMinionPickup(player, data)
	if not data or not data.x or not data.y or not data.z then return end

	local key = string.format("%d,%d,%d", data.x, data.y, data.z)
	local state = self.minionStateByBlockKey[key]

	-- Check if minion has items and warn player
	if state and state.slots then
		local hasItems = false
		for i = 1, (state.slotsUnlocked or 1) do
			local slot = state.slots[i]
			if slot and slot.itemId and slot.itemId > 0 and slot.count and slot.count > 0 then
				hasItems = true
				break
			end
		end
		if hasItems then
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			EventManager:FireEvent("ShowError", player, {
				message = "Minion has items! Collect them first or they will be lost."
			})
			-- Still allow pickup, but warned
		end
	end

	local entityId = self.minionByBlockKey[key]
	-- Fallback: if mapping lost, locate the minion entity by anchorKey metadata
	if (not entityId) and self.Deps and self.Deps.MobEntityService then
		local mobService = self.Deps.MobEntityService
		if mobService._worlds then
			for _, ctx in pairs(mobService._worlds) do
				for id, mob in pairs(ctx.mobsById) do
					if mob and mob.mobType == "COBBLE_MINION" and mob.metadata and mob.metadata.anchorKey == key then
						entityId = id
						break
					end
				end
			end
		end
	end

	-- Despawn minion entity
	if entityId then
		local mobService = self.Deps and self.Deps.MobEntityService
		if mobService and mobService.DespawnMob then
			mobService:DespawnMob(entityId)
		end
		self.minionByBlockKey[key] = nil
		self.blockKeyByMinion[entityId] = nil
	end
	-- Also clear mapping if no entity found to avoid stale references
	self.minionByBlockKey[key] = nil

	-- Remove state
	self.minionStateByBlockKey[key] = nil

	-- Remove any leftover minion block at anchor
	do
		local wm = self.worldManager
		if wm then
			local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
			if _isMinionBlock(wm:GetBlock(data.x, data.y, data.z)) then
				wm:SetBlock(data.x, data.y, data.z, Constants.BlockType.AIR)
			end
		end
	end

	-- Close UI for all viewers and unsubscribe them
	do
		local viewers = self.minionViewers and self.minionViewers[key]
		if viewers then
			local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
			for viewer in pairs(viewers) do
				-- Clear reverse mapping
				if self.playerMinionView then
					self.playerMinionView[viewer] = nil
				end
				-- Notify viewer to close UI
				EventManager:FireEvent("MinionClosed", viewer)
			end
			self.minionViewers[key] = nil
		end
	end

	-- Return minion item to player
	local inv = self.Deps and self.Deps.PlayerInventoryService
	if inv then
		local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
		local t = (state and state.type) or "COBBLESTONE"
		local itemId = MinionConfig.GetPickupItemId(t)
			-- Include level/type in returned item's metadata (non-stackable item)
			local metadata = {
				level = (state and state.level) or 1,
				minionType = t,
				slotsUnlocked = (state and state.slotsUnlocked) or MinionConfig.GetSlotsUnlocked(t, (state and state.level) or 1)
			}
			if inv.AddItemWithMetadata then
				local ok = inv:AddItemWithMetadata(player, itemId, metadata)
				if not ok then
					-- Inventory full: drop on ground as a fallback (optional)
					local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
					EventManager:FireEvent("ShowError", player, { message = "Inventory full" })
				end
			else
				inv:AddItem(player, itemId, 1)
			end
	end

	-- Close UI
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	EventManager:FireEvent("MinionClosed", player)
end

-- Close minion UI for a player (unsubscribe)
function VoxelWorldService:HandleCloseMinion(player, data)
	-- Remove viewer subscription if present
	local key = self.playerMinionView[player]
	if key and self.minionViewers[key] then
		self.minionViewers[key][player] = nil
		if next(self.minionViewers[key]) == nil then
			self.minionViewers[key] = nil
		end
	end
	self.playerMinionView[player] = nil
	-- Acknowledge close back to client
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	EventManager:FireEvent("MinionClosed", player)
end

-- Add item to minion's internal storage (called when minion mines)
function VoxelWorldService:AddItemToMinion(anchorKey, itemId, count)
	if not anchorKey or not itemId or not count or count <= 0 then
		return false
	end

	local mapped = Constants.OreToMaterial[itemId]
	if mapped then
		itemId = mapped
	end

	local state = self.minionStateByBlockKey[anchorKey]
	if not state then
		return false
	end

	-- Initialize slots if absent
	if not state.slots then
		state.slots = {}
		for i = 1, 12 do
			state.slots[i] = { itemId = 0, count = 0 }
		end
	end

	local slotsUnlocked = state.slotsUnlocked or 1
	local remaining = count

	-- Try to stack with existing slots first
	for i = 1, slotsUnlocked do
		if remaining <= 0 then break end
		local slot = state.slots[i]
		if slot.itemId == itemId and slot.count < 64 then
			local canAdd = math.min(64 - slot.count, remaining)
			slot.count = slot.count + canAdd
			remaining = remaining - canAdd
		end
	end

	-- Fill empty slots
	for i = 1, slotsUnlocked do
		if remaining <= 0 then break end
		local slot = state.slots[i]
		if slot.itemId == 0 or slot.count == 0 then
			local canAdd = math.min(64, remaining)
			slot.itemId = itemId
			slot.count = canAdd
			remaining = remaining - canAdd
		end
	end

	-- Return true if all added, false if some remained (minion full)
	local allAdded = (remaining == 0)

	-- Broadcast updated state to any viewers of this minion
	self:_broadcastMinionState(anchorKey)

	return allAdded
end

-- Build state payload for a minion anchor
function VoxelWorldService:_buildMinionStatePayload(state)
	local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
	local t = (state and state.type) or "COBBLESTONE"
	local maxLevel = (MinionConfig.GetTypeDef(t).maxLevel or 4)
	local waitSec = MinionConfig.GetWaitSeconds(t, state.level or 1)
	local nextCost = ((state.level or 1) < maxLevel) and MinionConfig.GetUpgradeCost(t, state.level or 1) or 0
	-- Serialize slots
	local slotsData = {}
	if state and state.slots then
		for i = 1, 12 do
			if state.slots[i] then
				slotsData[i] = {
					itemId = state.slots[i].itemId or 0,
					count = state.slots[i].count or 0
				}
			end
		end
	end
	return {
		type = t,
		level = state.level or 1,
		slotsUnlocked = state.slotsUnlocked or 1,
		waitSeconds = waitSec,
		nextUpgradeCost = nextCost,
		slots = slotsData
	}
end

-- Broadcast current minion state to all viewers of the anchor
function VoxelWorldService:_broadcastMinionState(anchorKey)
	local state = self.minionStateByBlockKey[anchorKey]
	if not state then return end
	local viewers = self.minionViewers[anchorKey]
	if not viewers then return end
	local payload = self:_buildMinionStatePayload(state)
	local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
	for viewer, _ in pairs(viewers) do
		EventManager:FireEvent("MinionUpdated", viewer, { state = payload })
	end
end

-- Cancel block breaking immediately for a specific block
function VoxelWorldService:CancelBlockBreak(player, data)
    if not data or data.x == nil or data.y == nil or data.z == nil then return end
    if not self.blockBreakTracker then return end

    -- Optional: validate reach similar to punch to avoid remote abuse
    local character = player.Character
    if not character then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    local x, y, z = data.x, data.y, data.z
    local blockCenter = Vector3.new(
        x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
        y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
        z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
    )
    local distance3D = (blockCenter - head.Position).Magnitude
    local maxReach = 4.5 * Constants.BLOCK_SIZE + 2
    if distance3D > maxReach then return end

    self.blockBreakTracker:Cancel(x, y, z)
end

-- Check if world is ready for players to spawn
function VoxelWorldService:IsWorldReady()
	-- World must exist
	if not self.world then return false end

	-- WorldManager must exist
	if not self.worldManager then return false end

	-- Generator must exist (needed for spawn position)
	if not self.worldManager.generator then return false end

	-- Generator must have GetSpawnPosition method
	if not self.worldManager.generator.GetSpawnPosition then return false end

	return true
end

-- Initialize world with seed and render distance
function VoxelWorldService:InitializeWorld(seed, renderDistance, worldTypeId)
	local descriptor = WorldTypes:Get(worldTypeId or self.worldTypeId)
	self.worldTypeId = descriptor.id
	self.worldDescriptor = descriptor

	local desiredRenderDistance = renderDistance or descriptor.renderDistance or self.renderDistance
	self.renderDistance = desiredRenderDistance

	-- Create world instance
	local worldSeed = seed or 12345
	self.world = VoxelWorld.CreateWorld(worldSeed, desiredRenderDistance, descriptor.id)
	self.worldManager = self.world:GetWorldManager()
	self.isHubWorld = descriptor.isHub == true
	self:_applyWorldAttributes(descriptor)
	self._spawnChunkCoords = nil

	print(string.format("VoxelWorldService: World initialized (seed: %d, render distance: %d)",
		worldSeed, self.renderDistance))
end

-- Initialize starter chest for Skyblock (called after world generation)
function VoxelWorldService:InitializeStarterChest()
	-- Skyblock starter chest is at world coordinates (7, 66, 4)
	-- Center is (7, 65, 7), chest is 3 blocks north on the grass surface + 1
	local chestX = 7
	local chestY = 66  -- One block above grass surface (Y=65)
	local chestZ = 4   -- 3 blocks north of center

	-- Check if ChestStorageService is available
	if self.Deps and self.Deps.ChestStorageService then
		self.Deps.ChestStorageService:InitializeStarterChest(chestX, chestY, chestZ)
		print(string.format("VoxelWorldService: Initialized starter chest at (%d, %d, %d)", chestX, chestY, chestZ))
	else
		warn("VoxelWorldService: ChestStorageService not available, cannot initialize starter chest")
	end
end

function VoxelWorldService:_applyWorldAttributes(descriptor)
	local attrs = (descriptor and descriptor.workspaceAttributes) or {}
	local isHub = attrs.IsHubWorld == true
	Workspace:SetAttribute("IsHubWorld", isHub)
	if attrs.HubRenderDistance ~= nil then
		Workspace:SetAttribute("HubRenderDistance", attrs.HubRenderDistance)
	else
		Workspace:SetAttribute("HubRenderDistance", nil)
	end
end

function VoxelWorldService:IsHubWorld()
	return self.isHubWorld == true
end

function VoxelWorldService:_getCurrentSpawnPosition()
	if self.worldManager and self.worldManager.generator and self.worldManager.generator.GetSpawnPosition then
		local ok, result = pcall(function()
			return self.worldManager.generator:GetSpawnPosition()
		end)
		if ok and result then
			return result
		end
	end
	return Vector3.new(0, 300, 0)
end

function VoxelWorldService:_ensureSpawnChunkReady(spawnPosition: Vector3?)
	if not self.worldManager then
		return nil, nil
	end

	if self._spawnChunkCoords then
		return self._spawnChunkCoords.x, self._spawnChunkCoords.z
	end

	local spawnPos = spawnPosition or self:_getCurrentSpawnPosition()
	local blockX = math.floor(spawnPos.X / Constants.BLOCK_SIZE + 0.5)
	local blockZ = math.floor(spawnPos.Z / Constants.BLOCK_SIZE + 0.5)
	local chunkX = math.floor(blockX / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(blockZ / Constants.CHUNK_SIZE_Z)

	local chunk = self.worldManager:GetChunk(chunkX, chunkZ)
	local timeout = os.clock() + 2
	while chunk and chunk.state ~= Constants.ChunkState.READY and os.clock() < timeout do
		task.wait()
	end

	self._spawnChunkCoords = { x = chunkX, z = chunkZ }
	return chunkX, chunkZ
end

function VoxelWorldService:_streamSpawnChunksForPlayer(player, chunkX, chunkZ)
	if not chunkX or not chunkZ then
		warn("[VoxelWorldService] _streamSpawnChunksForPlayer: Invalid chunk coords", chunkX, chunkZ)
		return
	end

	print(string.format("[VoxelWorldService] Streaming spawn chunks around (%d,%d) for %s", chunkX, chunkZ, player.Name))
	local streamed = 0
	local chunkKeys = {}

	-- S3-FIX: Stream a 7x7 area (radius 3) to match client's loadingChunkRadius
	-- Build stream order prioritized by distance from center
	local SPAWN_CHUNK_RADIUS = 3
	local streamOrder = {}
	for dx = -SPAWN_CHUNK_RADIUS, SPAWN_CHUNK_RADIUS do
		for dz = -SPAWN_CHUNK_RADIUS, SPAWN_CHUNK_RADIUS do
			local dist = dx * dx + dz * dz
			table.insert(streamOrder, {dx, dz, dist})
		end
	end
	-- Sort by distance (center first, then expanding outward)
	table.sort(streamOrder, function(a, b) return a[3] < b[3] end)

	for _, entry in ipairs(streamOrder) do
		local dx, dz = entry[1], entry[2]
		local cx, cz = chunkX + dx, chunkZ + dz
		local ok = self:StreamChunkToPlayer(player, cx, cz)
		if ok then
			streamed = streamed + 1
			table.insert(chunkKeys, string.format("%d,%d", cx, cz))
		end
	end

	local totalAttempted = (SPAWN_CHUNK_RADIUS * 2 + 1) * (SPAWN_CHUNK_RADIUS * 2 + 1)
	print(string.format("[VoxelWorldService] Streamed %d/%d spawn chunks to %s (empty chunks skipped)",
		streamed, totalAttempted, player.Name))

	-- S3: Fire event to notify client that spawn chunks have been sent
	-- Client uses this to know which chunks to expect (only non-empty ones)
	EventManager:FireEvent("SpawnChunksStreamed", player, {
		spawnChunkX = chunkX,
		spawnChunkZ = chunkZ,
		chunkKeys = chunkKeys,
		totalStreamed = streamed
	})
end

-- Update world seed (called when owner joins)
function VoxelWorldService:UpdateWorldSeed(seed)
	if not seed then return end

	-- Destroy old world if it exists
	if self.world and self.world.Destroy then
		self.world:Destroy()
	end

	-- Recreate world with new seed
	self.world = VoxelWorld.CreateWorld(seed, self.renderDistance, self.worldTypeId)
	self.worldManager = self.world:GetWorldManager()
	self._spawnChunkCoords = nil

	print(string.format("VoxelWorldService: World recreated with owner's seed: %d", seed))
end

-- Stream chunk to player
function VoxelWorldService:StreamChunkToPlayer(player, chunkX, chunkZ)
	local playerData = self.players[player]
	if not playerData then
		warn(string.format("[VoxelWorldService] StreamChunkToPlayer: No player data for %s", player.Name))
		return false
	end

	local key = string.format("%d,%d", chunkX, chunkZ)

	-- Skip known-empty chunks (Skyblock/void worlds)
	if self.worldManager and self.worldManager.IsChunkEmpty and self.worldManager:IsChunkEmpty(chunkX, chunkZ) then
		-- Debug log for spawn chunks (around 0,0)
		if math.abs(chunkX) <= 2 and math.abs(chunkZ) <= 2 then
			print(string.format("[VoxelWorldService] Chunk (%d,%d) marked as EMPTY - skipping stream", chunkX, chunkZ))
		end
		return false
	end

	-- Get or create chunk
	local chunk = self.worldManager:GetChunk(chunkX, chunkZ)
	if not chunk then
		warn(string.format("[VoxelWorldService] StreamChunkToPlayer: Failed to get chunk (%d,%d)", chunkX, chunkZ))
		return false
	end

    -- Serialize and send via EventManager (with caching)
    local startTime = os.clock()

    -- Avoid duplicate work if another call is already compressing this chunk
    if chunk._compressing then
        return false
    end

    local compressed = chunk._netCache
    if not compressed or chunk.isDirty then
        chunk._compressing = true
        local linear = chunk:SerializeLinear()

        -- DEBUG: Log sample block IDs from the flat array
        if linear.flat and #linear.flat > 0 then
            local blockCounts = {}
            for i = 1, math.min(1000, #linear.flat) do
                local bid = linear.flat[i]
                if bid and bid ~= 0 then
                    blockCounts[bid] = (blockCounts[bid] or 0) + 1
                end
            end
            local sample = {}
            for bid, count in pairs(blockCounts) do
                table.insert(sample, string.format("%d:%d", bid, count))
            end
            if #sample > 0 then
                print(string.format("[VoxelWorldService] Chunk %d,%d linear sample: %s", chunkX, chunkZ, table.concat(sample, ", ")))
            end
        end

        compressed = ChunkCompressor.CompressForNetwork(linear)
        compressed.x = linear.x
        compressed.z = linear.z
        compressed.state = linear.state
        chunk._netCache = compressed
        -- Mark network cache clean; saving still uses WorldManager.modifiedChunks
        chunk.isDirty = false
        chunk._compressing = nil
    end

    local compressionTime = (os.clock() - startTime) * 1000

	EventManager:FireEvent("ChunkDataStreamed", player, {
		chunk = compressed,
		key = key
	})

	-- Update stats
	self.stats.chunksStreamed += 1
	self.stats.lastStreamTimeMs = compressionTime

	-- Track viewing reference
	self:_addViewer(player, key)
	self.chunkLastAccess[key] = os.clock()

	-- Notify SaplingService to scan this chunk once (for offline growth / registration)
	local saplingService = self.Deps and self.Deps.SaplingService
	if saplingService and saplingService.OnChunkStreamed then
		saplingService:OnChunkStreamed(chunkX, chunkZ)
	end

	-- Notify CropService to scan this chunk for crops
	local cropService = self.Deps and self.Deps.CropService
	if cropService and cropService.OnChunkStreamed then
		cropService:OnChunkStreamed(chunkX, chunkZ)
	end

	-- Enforce per-player chunk cap
	local perPlayerCap = (Config.PERFORMANCE and Config.PERFORMANCE.MAX_CHUNKS_PER_PLAYER) or 200
	if perPlayerCap > 0 then
		local state = self.players[player]
		if state and state.chunks then
			local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
			local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
			local safeRadius = (self.renderDistance or 6) + 1
			local candidates = {}

			for k in pairs(state.chunks) do
				local cx, cz = string.match(k, "(-?%d+),(-?%d+)")
				cx, cz = tonumber(cx) or 0, tonumber(cz) or 0
				local dx = cx - centerChunkX
				local dz = cz - centerChunkZ
				local dist2 = dx*dx + dz*dz

				if dist2 > (safeRadius * safeRadius) then
					candidates[#candidates + 1] = {
						key = k,
						last = self.chunkLastAccess[k] or 0,
						dist2 = dist2
					}
				end
			end

			table.sort(candidates, function(a, b)
				if a.dist2 == b.dist2 then
					return a.last < b.last
				end
				return a.dist2 > b.dist2
			end)

			local currentCount = 0
			for _ in pairs(state.chunks) do currentCount += 1 end
			local over = (currentCount + 1) - perPlayerCap
			local i = 1

			while over > 0 and i <= #candidates do
				local victim = candidates[i].key
				if victim ~= key then
					EventManager:FireEvent("ChunkUnload", player, { key = victim })
					state.chunks[victim] = nil
					self:_removeViewer(player, victim)
					over -= 1
				end
				i += 1
			end
		end
	end

	return true
end

-- Stream needed chunks for a player
function VoxelWorldService:StreamChunksToPlayer(player, playerState)
	local state = playerState or self.players[player]
	if not state then return end

	local now = os.clock()
	local rl = self.rateLimits[player]
	if not rl or (now - rl.chunkWindowStart) >= 1 then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0}
		self.rateLimits[player] = rl
	end

	local remaining = math.max(0, (Config.NETWORK.MAX_CHUNKS_PER_UPDATE or 5) - rl.chunksSent)
	if remaining <= 0 then return end

	local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
	local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
	local renderDistance = self.renderDistance or 6

	-- Build candidate list with forward bias
	local maxDist = renderDistance * renderDistance
	local candidates = {}
	local forward = state.moveDir or Vector3.new()
	local hasForward = (forward.Magnitude and forward.Magnitude > 0.5)
	local bias = renderDistance * 0.75

	for ox = -renderDistance, renderDistance do
		for oz = -renderDistance, renderDistance do
			local dist2 = ox*ox + oz*oz
			if dist2 <= maxDist then
				local cx = centerChunkX + ox
				local cz = centerChunkZ + oz
				local key = string.format("%d,%d", cx, cz)

				if not state.chunks[key] then
					-- Skip known-empty chunks in sparse worlds (e.g., Skyblock)
					if self.worldManager and self.worldManager.IsChunkEmpty and self.worldManager:IsChunkEmpty(cx, cz) then
						-- continue
					else
					local score = dist2
					if hasForward then
						local len = math.sqrt(ox*ox + oz*oz)
						if len > 1e-3 then
							local ndx, ndz = ox/len, oz/len
							local dot = ndx * forward.X + ndz * forward.Z
							if dot then
								dot = math.clamp(dot, -1, 1)
								score = score - (dot * bias)
							end
						end
					end
						table.insert(candidates, { cx = cx, cz = cz, key = key, score = score })
					end
				end
			end
		end
	end

	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)

	local sent = 0
	for i = 1, #candidates do
		local cand = candidates[i]
		local ok = self:StreamChunkToPlayer(player, cand.cx, cand.cz)
		if ok then
			state.chunks[cand.key] = true
			rl.chunksSent += 1
			sent += 1
			if sent >= remaining then
				break
			end
		end
	end
end

-- Stream chunks for all players
function VoxelWorldService:StreamChunksToPlayers()
	-- Safety check: Don't stream if world isn't initialized yet
	if not self.world or not self.worldManager then
		return
	end

	for player, state in pairs(self.players) do
		self:StreamChunksToPlayer(player, state)

		-- Unload far chunks
		local centerChunkX = math.floor(state.position.X / (Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE))
		local centerChunkZ = math.floor(state.position.Z / (Constants.CHUNK_SIZE_Z * Constants.BLOCK_SIZE))
		local extra = (Config.NETWORK and Config.NETWORK.UNLOAD_EXTRA_RADIUS) or 0
		local renderDist = self.renderDistance or 6
		local maxDist = (renderDist + 2 + extra)

		for key in pairs(state.chunks) do
			local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
			cx, cz = tonumber(cx) or 0, tonumber(cz) or 0
			local dx = cx - centerChunkX
			local dz = cz - centerChunkZ

			if (dx * dx + dz * dz) > (maxDist * maxDist) then
				EventManager:FireEvent("ChunkUnload", player, { key = key })
				state.chunks[key] = nil
				self.stats.chunksUnloaded += 1
				self:_removeViewer(player, key)
			end
		end
	end
end

-- Set block in world
function VoxelWorldService:SetBlock(x, y, z, blockId, player, metadata)
	if not self.worldManager then return false end

	-- Get current state
    local prevBlockId = self.worldManager:GetBlock(x, y, z)
    local prevMeta = self.worldManager:GetBlockMetadata(x, y, z) or 0
    
    -- Determine if anything is actually changing
    local blockTypeChanged = (prevBlockId ~= blockId)
    local metadataChanged = (metadata ~= nil and metadata ~= prevMeta)
    
    -- Early exit if nothing changed (prevents unnecessary network events, especially for water)
    if not blockTypeChanged and not metadataChanged then
    	return true -- Already set, no change needed
    end
    
    -- Set block type if changed
    if blockTypeChanged then
    	local success = self.worldManager:SetBlock(x, y, z, blockId)
		if not success then return false end
    end

	-- If block type changed and no explicit metadata provided, clear old metadata
	if blockTypeChanged and (metadata == nil) then
		self.worldManager:SetBlockMetadata(x, y, z, 0)
	end

	-- Leaves persistence: player-placed leaves (any variant) are persistent and should not decay
	local BLOCK = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants).BlockType
	local function _isLeaf(id)
		return id == BLOCK.LEAVES or id == BLOCK.OAK_LEAVES or id == BLOCK.SPRUCE_LEAVES or id == BLOCK.JUNGLE_LEAVES or id == BLOCK.DARK_OAK_LEAVES or id == BLOCK.BIRCH_LEAVES or id == BLOCK.ACACIA_LEAVES
	end
	if _isLeaf(blockId) then
		local metaToSet = metadata
		-- If placed by a player, set persistent bit (bit 3)
		if player then
			local existing = self.worldManager:GetBlockMetadata(x, y, z) or 0
			metaToSet = bit32.bor(metaToSet or existing, 0x8)
		end
		-- Apply metadata if non-nil (even if zero from explicit input)
		if metaToSet ~= nil then
			self.worldManager:SetBlockMetadata(x, y, z, metaToSet)
		end
	else
		-- Non-leaf blocks: set metadata if provided explicitly (e.g., slabs/stairs orientation, water depth)
		-- Note: metadata=0 is valid for water sources and other blocks, so we check for nil, not falsy
		if metadata ~= nil then
			self.worldManager:SetBlockMetadata(x, y, z, metadata)
		end
	end

	-- Notify SaplingService about block change (for sapling growth/leaf decay)
	local saplingService = self.Deps and self.Deps.SaplingService
	if saplingService and saplingService.OnBlockChanged then
		local metaNow = metadata or self.worldManager:GetBlockMetadata(x, y, z) or 0
        saplingService:OnBlockChanged(x, y, z, blockId, metaNow, prevBlockId)
	end

	-- Notify CropService about block change (for crop growth tracking)
	local cropService = self.Deps and self.Deps.CropService
	if cropService and cropService.OnBlockChanged then
		local metaNow = metadata or self.worldManager:GetBlockMetadata(x, y, z) or 0
		cropService:OnBlockChanged(x, y, z, blockId, metaNow, prevBlockId)
	end

	-- Notify WaterService about block change (for water flow updates)
	local waterService = self.Deps and self.Deps.WaterService
	if waterService and waterService.OnBlockChanged then
		local metaNow = metadata or self.worldManager:GetBlockMetadata(x, y, z) or 0
		waterService:OnBlockChanged(x, y, z, blockId, metaNow, prevBlockId)
	end

	-- Minion block: if removed/replaced, despawn linked minion
	do
		if _isMinionBlock(prevBlockId) and not _isMinionBlock(blockId) then
			local key = string.format("%d,%d,%d", x, y, z)
			local entityId = self.minionByBlockKey and self.minionByBlockKey[key]
			if entityId and self.Deps and self.Deps.MobEntityService and self.Deps.MobEntityService.DespawnMob then
				pcall(function()
					self.Deps.MobEntityService:DespawnMob(entityId)
				end)
			end
			if self.minionByBlockKey then
				self.minionByBlockKey[key] = nil
			end
			if self.blockKeyByMinion and entityId then
				self.blockKeyByMinion[entityId] = nil
			end
		end
	end

	-- After changing a block, update nearby stair shapes
	self:_updateNeighborStairShapes(x, y, z)

	-- Mark chunk as modified (and neighbor edge chunks to update fence connections across borders)
	local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
	local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
	local function mark(cx, cz)
		local k = string.format("%d,%d", cx, cz)
		self.modifiedChunks[k] = true
	end
	-- Always mark current chunk
	mark(chunkX, chunkZ)
	-- If on a chunk edge, also mark the neighbor so fence rails render across border
	local localX = x % Constants.CHUNK_SIZE_X
	local localZ = z % Constants.CHUNK_SIZE_Z
	if localX == 0 then mark(chunkX - 1, chunkZ) end
	if localX == Constants.CHUNK_SIZE_X - 1 then mark(chunkX + 1, chunkZ) end
	if localZ == 0 then mark(chunkX, chunkZ - 1) end
	if localZ == Constants.CHUNK_SIZE_Z - 1 then mark(chunkX, chunkZ + 1) end
	print(string.format("🔄 Marked chunk (%d,%d) (+edges if any) as modified (block %d at %d,%d,%d, meta:%d)", chunkX, chunkZ, blockId, x, y, z, metadata or 0))

	-- Notify all players
	for otherPlayer, otherData in pairs(self.players) do
		local distance = math.sqrt(
			(x * Constants.BLOCK_SIZE - otherData.position.X)^2 +
			(z * Constants.BLOCK_SIZE - otherData.position.Z)^2
		)

		if distance <= (Config.NETWORK.BLOCK_UPDATE_DISTANCE or 500) then
			EventManager:FireEvent("BlockChanged", otherPlayer, {
				x = x,
				y = y,
				z = z,
				blockId = blockId,
				metadata = metadata or 0,  -- NEW: Include metadata in network sync
				player = player and player.UserId or nil
			})
		end
	end

	self.stats.blockChanges += 1
	return true
end

-- Reject block change
function VoxelWorldService:RejectBlockChange(player, data, reason)
	EventManager:FireEvent("BlockChangeRejected", player, {
		x = data.x,
		y = data.y,
		z = data.z,
		reason = reason
	})
end


-- Handle player punch (block breaking)
function VoxelWorldService:HandlePlayerPunch(player, punchData)
	if not punchData or not punchData.x or not punchData.y or not punchData.z then
		warn("Invalid punch data from", player.Name)
		return
	end

	local x, y, z = punchData.x, punchData.y, punchData.z
	if self:IsHubWorld() then
		self:RejectBlockChange(player, { x = x, y = y, z = z }, "hub_read_only")
		return
	end
	local playerData = self.players[player]
	if not playerData then return end

	-- Rate limiting
	local now = os.clock()
	local rl = self.rateLimits[player]
	if rl and rl.lastPunch and (now - rl.lastPunch) < 0.1 then
		return
	end

	if not rl then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0, lastPunch = now}
		self.rateLimits[player] = rl
	end
	rl.lastPunch = now

	-- Validate distance
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	if not head then return end

	local blockCenter = Vector3.new(
		x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
		y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
		z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
	)

	local distance3D = (blockCenter - head.Position).Magnitude
	local maxReach = 4.5 * Constants.BLOCK_SIZE + 2

	if distance3D > maxReach then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "too_far")
		return
	end

	-- Get block
	local blockId = self.worldManager:GetBlock(x, y, z)
	if not blockId or blockId == Constants.BlockType.AIR then
		return
	end
	local blockMetadata = self.worldManager:GetBlockMetadata(x, y, z) or 0
	local dropService = self.Deps and self.Deps.DroppedItemService

	-- Check if breakable
	if not BlockProperties:IsBreakable(blockId) then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "unbreakable")
		return
	end

	-- Get tool info (validate equipped tool still in hotbar slot)
	local toolType = BlockProperties.ToolType.NONE
	local toolTier = BlockProperties.ToolTier.NONE
	if playerData.tool and playerData.tool.slotIndex and self.Deps and self.Deps.PlayerInventoryService then
		local slotIndex = playerData.tool.slotIndex
		local stack = self.Deps.PlayerInventoryService:GetHotbarSlot(player, slotIndex)
		if stack and not stack:IsEmpty() then
			local itemId = stack:GetItemId()
			local ToolConfig = require(game.ReplicatedStorage.Configs.ToolConfig)
			if ToolConfig.IsTool(itemId) then
				local tType, tTier = ToolConfig.GetBlockProps(itemId)
				toolType = tType
				toolTier = tTier
			else
				-- Slot no longer holds a tool; clear equipped state
				playerData.tool = nil
			end
		else
			-- Empty slot; clear equipped state
			playerData.tool = nil
		end
	else
		-- Fallback to any previously stored type/tier (legacy) if present
		toolType = (playerData.tool and playerData.tool.type) or BlockProperties.ToolType.NONE
		toolTier = (playerData.tool and playerData.tool.tier) or BlockProperties.ToolTier.NONE
	end

	-- Calculate break time
	local breakTime, canBreak = BlockProperties:GetBreakTime(blockId, toolType, toolTier)
	if not canBreak then
		self:RejectBlockChange(player, {x = x, y = y, z = z}, "wrong_tool")
		return
	end

	-- Track breaking progress
	local dt = punchData.dt or 0.25
	local progress, isBroken = self.blockBreakTracker:Hit(player, x, y, z, breakTime, dt)

	-- Broadcast punch animation
	pcall(function()
		EventManager:FireEventToAll("PlayerPunched", {
			userId = player.UserId,
			x = x, y = y, z = z,
			progress = progress,
			timeMs = math.floor(os.clock() * 1000)
		})
	end)

	if isBroken then
		print(string.format("Player %s broke block at (%d, %d, %d) - blockId: %d",
			player.Name, x, y, z, blockId))

		local canHarvest = BlockProperties:CanHarvest(blockId, toolType, toolTier)

		-- Handle special block types (e.g., chests)
		if blockId == Constants.BlockType.CHEST then
			-- Remove chest data and close for viewers
			if self.Deps and self.Deps.ChestStorageService then
				self.Deps.ChestStorageService:RemoveChest(x, y, z)
			end
		end

		-- Remove block FIRST so it disappears before item spawns
		self:SetBlock(x, y, z, Constants.BlockType.AIR, player)

		-- Fire break event after block is removed
		EventManager:FireEventToAll("BlockBroken", {
			x = x, y = y, z = z,
			blockId = blockId,
			playerUserId = player.UserId,
			canHarvest = canHarvest
		})

        -- Spawn dropped items
		if dropService then
            -- Special-case leaves (all variants): drop saplings/apples by chance, not the leaf block itself
            local isLeaf = (
                blockId == Constants.BlockType.LEAVES or
                blockId == Constants.BlockType.OAK_LEAVES or
                blockId == Constants.BlockType.SPRUCE_LEAVES or
                blockId == Constants.BlockType.JUNGLE_LEAVES or
                blockId == Constants.BlockType.DARK_OAK_LEAVES or
                blockId == Constants.BlockType.BIRCH_LEAVES or
                blockId == Constants.BlockType.ACACIA_LEAVES
            )

			if isLeaf then
				local saplingChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.SAPLING_DROP_CHANCE) or 0.05
				local appleChance = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.APPLE_DROP_CHANCE) or 0.005

				-- Map leaf → sapling
				local saplingId
				if blockId == Constants.BlockType.OAK_LEAVES then saplingId = Constants.BlockType.OAK_SAPLING end
				if blockId == Constants.BlockType.SPRUCE_LEAVES then saplingId = Constants.BlockType.SPRUCE_SAPLING end
				if blockId == Constants.BlockType.JUNGLE_LEAVES then saplingId = Constants.BlockType.JUNGLE_SAPLING end
				if blockId == Constants.BlockType.DARK_OAK_LEAVES then saplingId = Constants.BlockType.DARK_OAK_SAPLING end
				if blockId == Constants.BlockType.BIRCH_LEAVES then saplingId = Constants.BlockType.BIRCH_SAPLING end
				if blockId == Constants.BlockType.ACACIA_LEAVES then saplingId = Constants.BlockType.ACACIA_SAPLING end

				-- If leaf was the legacy generic kind, infer species from nearby variant leaves first, then nearest trunk
				if (not saplingId) and blockId == Constants.BlockType.LEAVES then
					local radius = (SaplingConfig.LEAF_DECAY and SaplingConfig.LEAF_DECAY.RADIUS) or 6
					-- Try species encoded in metadata (bits 4-6) first
					local meta = self.worldManager and self.worldManager:GetBlockMetadata(x, y, z) or 0
					local code = bit32.rshift(bit32.band(meta, 0x70), 4)
					local function codeToSapling(c)
						if c == 0 then return Constants.BlockType.OAK_SAPLING end
						if c == 1 then return Constants.BlockType.SPRUCE_SAPLING end
						if c == 2 then return Constants.BlockType.JUNGLE_SAPLING end
						if c == 3 then return Constants.BlockType.DARK_OAK_SAPLING end
						if c == 4 then return Constants.BlockType.BIRCH_SAPLING end
						if c == 5 then return Constants.BlockType.ACACIA_SAPLING end
						return nil
					end
					local fromCode = codeToSapling(code)
					if fromCode then saplingId = fromCode end

					-- Next, ask SaplingService for a chunk species hint
					if (not saplingId) and self.Deps and self.Deps.SaplingService and self.Deps.SaplingService.GetChunkSpecies then
						local cx = math.floor(x / Constants.CHUNK_SIZE_X)
						local cz = math.floor(z / Constants.CHUNK_SIZE_Z)
						local hint = self.Deps.SaplingService:GetChunkSpecies(cx, cz)
						if hint ~= nil then
							local hinted = codeToSapling(hint)
							if hinted then saplingId = hinted end
						end
					end

					-- Prefer nearby species leaves to infer correct sapling when logs are gone
					local inferred
					for dy = -radius, radius do
						for dx = -radius, radius do
							for dz = -radius, radius do
								local nid = self.worldManager and self.worldManager:GetBlock(x + dx, y + dy, z + dz)
								if nid == Constants.BlockType.OAK_LEAVES then inferred = Constants.BlockType.OAK_SAPLING break end
								if nid == Constants.BlockType.SPRUCE_LEAVES then inferred = Constants.BlockType.SPRUCE_SAPLING break end
								if nid == Constants.BlockType.JUNGLE_LEAVES then inferred = Constants.BlockType.JUNGLE_SAPLING break end
								if nid == Constants.BlockType.DARK_OAK_LEAVES then inferred = Constants.BlockType.DARK_OAK_SAPLING break end
								if nid == Constants.BlockType.BIRCH_LEAVES then inferred = Constants.BlockType.BIRCH_SAPLING break end
								if nid == Constants.BlockType.ACACIA_LEAVES then inferred = Constants.BlockType.ACACIA_SAPLING break end
							end
							if inferred then break end
						end
						if inferred then
							saplingId = inferred
						else
							local best
							for dy = -radius, radius do
								for dx = -radius, radius do
									for dz = -radius, radius do
										local bid = self.worldManager and self.worldManager:GetBlock(x + dx, y + dy, z + dz)
										if bid == Constants.BlockType.WOOD then best = Constants.BlockType.OAK_SAPLING break end
										if bid == Constants.BlockType.SPRUCE_LOG then best = Constants.BlockType.SPRUCE_SAPLING break end
										if bid == Constants.BlockType.JUNGLE_LOG then best = Constants.BlockType.JUNGLE_SAPLING break end
										if bid == Constants.BlockType.DARK_OAK_LOG then best = Constants.BlockType.DARK_OAK_SAPLING break end
										if bid == Constants.BlockType.BIRCH_LOG then best = Constants.BlockType.BIRCH_SAPLING break end
										if bid == Constants.BlockType.ACACIA_LOG then best = Constants.BlockType.ACACIA_SAPLING break end
									end
									if best then break end
								end
								if best then break end
							end
							saplingId = best
						end
					end
				end

				if dropService and saplingId and (math.random() < saplingChance) then
					dropService:SpawnItem(saplingId, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
				end
				-- Only oak leaves drop apples (no generic fallback)
				if dropService and (blockId == Constants.BlockType.OAK_LEAVES) and (math.random() < appleChance) then
					dropService:SpawnItem(Constants.BlockType.APPLE, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
				end
			-- Otherwise, default drop path (only if harvestable)
			elseif canHarvest then
			-- Crop drops override
			local dropItemId = blockId
			local dropCount = 1
			local BLOCK = Constants.BlockType
			local handled = false
			local function isWheatStage(id)
				return id == BLOCK.WHEAT_CROP_0 or id == BLOCK.WHEAT_CROP_1 or id == BLOCK.WHEAT_CROP_2 or id == BLOCK.WHEAT_CROP_3
					or id == BLOCK.WHEAT_CROP_4 or id == BLOCK.WHEAT_CROP_5 or id == BLOCK.WHEAT_CROP_6 or id == BLOCK.WHEAT_CROP_7
			end
			local function isPotatoStage(id)
				return id == BLOCK.POTATO_CROP_0 or id == BLOCK.POTATO_CROP_1 or id == BLOCK.POTATO_CROP_2 or id == BLOCK.POTATO_CROP_3
			end
			local function isCarrotStage(id)
				return id == BLOCK.CARROT_CROP_0 or id == BLOCK.CARROT_CROP_1 or id == BLOCK.CARROT_CROP_2 or id == BLOCK.CARROT_CROP_3
			end
			local function isBeetStage(id)
				return id == BLOCK.BEETROOT_CROP_0 or id == BLOCK.BEETROOT_CROP_1 or id == BLOCK.BEETROOT_CROP_2 or id == BLOCK.BEETROOT_CROP_3
			end

			if isWheatStage(blockId) then
				if blockId == BLOCK.WHEAT_CROP_7 then
					-- Mature: 1 wheat + 1 seeds
					if dropService then
						dropService:SpawnItem(BLOCK.WHEAT, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
						dropService:SpawnItem(BLOCK.WHEAT_SEEDS, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
					end
				else
					-- Immature: seeds only
					if dropService then
						dropService:SpawnItem(BLOCK.WHEAT_SEEDS, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
					end
				end
				handled = true
			elseif isPotatoStage(blockId) then
				local count = (blockId == BLOCK.POTATO_CROP_3) and math.random(1, 3) or 1
				if dropService then
					dropService:SpawnItem(BLOCK.POTATO, count, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
				end
				handled = true
			elseif isCarrotStage(blockId) then
				local count = (blockId == BLOCK.CARROT_CROP_3) and math.random(1, 3) or 1
				if dropService then
					dropService:SpawnItem(BLOCK.CARROT, count, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
				end
				handled = true
			elseif isBeetStage(blockId) then
				if blockId == BLOCK.BEETROOT_CROP_3 then
					if dropService then
						dropService:SpawnItem(BLOCK.BEETROOT, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
						dropService:SpawnItem(BLOCK.BEETROOT_SEEDS, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
					end
				else
					if dropService then
						dropService:SpawnItem(BLOCK.BEETROOT_SEEDS, 1, Vector3.new(x, y, z), Vector3.new(0,0,0), true)
					end
				end
				handled = true
			end

			if not handled and Constants.ShouldTransformBlockDrop(blockId) then
				-- Blocks that transform when broken (e.g., stone → cobblestone)
				dropItemId = Constants.GetBlockDrop(blockId)
				dropCount = 1
				print(string.format("🪨 Block %d drops as %d", blockId, dropItemId))
			elseif not handled and Constants.ShouldDropAsSlabs(blockId, blockMetadata) then
				-- This full block (e.g., Oak Planks) should drop as 2 slabs (e.g., Oak Slabs)
				dropItemId = Constants.GetSlabFromFullBlock(blockId)
				dropCount = 2
				print(string.format("📦 Block %d drops as 2x slab %d", blockId, dropItemId))
			elseif not handled and Constants.IsOreBlock(blockId) then
				-- Ore blocks drop their refined material instead of the ore block
				dropItemId = Constants.GetOreMaterialDrop(blockId)
				dropCount = 1
				print(string.format("⛏️ Ore block %d drops as material %d", blockId, dropItemId))
			end

			if not handled and dropService then
				-- Minimal velocity - just let it drop naturally
				local popVelocity = Vector3.new(
					math.random(-1, 1) * 0.5,
					0, -- No upward velocity - spawn and drop
					math.random(-1, 1) * 0.5
				)
				dropService:SpawnItem(
					dropItemId,
					dropCount,
					Vector3.new(x, y, z),
					popVelocity,
					true -- Is block coordinates
				)
			end
		end
		end
	else
		EventManager:FireEventToAll("BlockBreakProgress", {
			x = x, y = y, z = z,
			progress = progress,
			playerUserId = player.UserId
		})
	end
end

-- Handle block placement
function VoxelWorldService:RequestBlockPlace(player, placeData)
	if not placeData or not placeData.x or not placeData.y or not placeData.z or not placeData.blockId then
		warn("Invalid block place data from", player.Name)
		return
	end

	local x, y, z, blockId = placeData.x, placeData.y, placeData.z, placeData.blockId
	local playerData = self.players[player]
	if not playerData then return end

	if self:IsHubWorld() then
		self:RejectBlockChange(player, { x = x, y = y, z = z }, "hub_read_only")
		return
	end

	-- Debug: Log placement request
	print(string.format("[BlockPlace] %s requesting placement at (%d,%d,%d) with blockId: %d",
		player.Name, x, y, z, blockId))

	-- Rate limiting
	local now = os.clock()
	local rl = self.rateLimits[player]
	if not rl then
		rl = {chunkWindowStart = now, chunksSent = 0, modWindowStart = now, mods = 0, lastPlace = 0}
		self.rateLimits[player] = rl
	end

	if (now - (rl.lastPlace or 0)) < 0.15 then
		return
	end
	rl.lastPlace = now

	-- Validate distance and collision
	local character = player.Character
	if not character then return end

	local head = character:FindFirstChild("Head")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not head or not rootPart then return end

	-- Use head position for distance check (where player looks from)
	-- Use rootPart position for collision check (body center)
	local headPos = head.Position
	local bodyPos = rootPart.Position

	-- Check if this is a potential slab merge before validation
	-- If placing a slab where another slab exists, skip the space_occupied check
	local isPotentialSlabMerge = false
	if Constants.IsSlab(blockId) then
		local existingBlock = self.worldManager:GetBlock(x, y, z)
		if Constants.IsSlab(existingBlock) then
			isPotentialSlabMerge = true
			print(string.format("[BlockPlace] 🔍 Detected potential slab merge at (%d,%d,%d)", x, y, z))
		end
	end

	-- Standard placement validation (distance and collision)
	-- For potential slab merges, we'll validate after checking if they can actually merge
	local canPlace, reason
	if not isPotentialSlabMerge then
		-- Special rule: Cobblestone Minion must be placed by clicking a TOP face
		do
			local BLOCK = Constants.BlockType
			local fn = placeData.faceNormal
			if _isMinionBlock(placeData.blockId) then
				if not (fn and fn.Y and fn.Y == 1) then
					self:RejectBlockChange(player, {x = x, y = y, z = z}, "minion_top_face_only")
					return
				end
			end
		end
		canPlace, reason = BlockPlacementRules:CanPlace(
			self.worldManager,
			x, y, z,
			blockId,
			headPos,     -- Distance check uses head position
			bodyPos      -- Collision check uses body position
		)
	else
		-- For slab merges, only check distance, not space occupation
		local blockCenter = Vector3.new(
			x * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			y * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5,
			z * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
		)
		local distance = (blockCenter - headPos).Magnitude
		local maxReach = 4.5 * Constants.BLOCK_SIZE + 2
		canPlace = distance <= maxReach
		reason = canPlace and nil or "too_far"
	end

	if not canPlace then
		-- Debug logging for placement rejection
		local currentBlock = self.worldManager:GetBlock(x, y, z)
		local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
		local blockName = "unknown"
		if currentBlock == Constants.BlockType.AIR then blockName = "AIR"
		elseif currentBlock == Constants.BlockType.STONE then blockName = "STONE"
		elseif currentBlock == Constants.BlockType.DIRT then blockName = "DIRT"
		elseif currentBlock == Constants.BlockType.GRASS then blockName = "GRASS"
		elseif currentBlock == Constants.BlockType.LOG then blockName = "LOG"
		elseif currentBlock == Constants.BlockType.LEAVES then blockName = "LEAVES"
		end

		print(string.format("[BlockPlace] ❌ REJECTED for %s at (%d,%d,%d)", player.Name, x, y, z))
		print(string.format("  Current block: %d (%s)", currentBlock or -1, blockName))
		print(string.format("  Reason: %s", reason or "unknown"))
		print(string.format("  Trying to place: blockId %d", blockId))

		self:RejectBlockChange(player, {x = x, y = y, z = z}, reason or "cannot_place")
		return
	end

	-- Debug: Successful placement check
	print(string.format("[BlockPlace] ✅ Validation passed for %s at (%d,%d,%d)", player.Name, x, y, z))

	-- Custom placements: Farmland conversion and crop planting redirects
	local BLOCK = Constants.BlockType
	-- 1) Farmland item: convert targeted GRASS/DIRT into FARMLAND and consume farmland item
	if blockId == BLOCK.FARMLAND then
		local tpos = placeData.targetBlockPos
		local tgtId = self.worldManager:GetBlock(tpos.X, tpos.Y, tpos.Z)
		if tgtId == BLOCK.GRASS or tgtId == BLOCK.DIRT then
			-- Consume one farmland from hotbar
			if self.Deps and self.Deps.PlayerInventoryService then
				local inventoryService = self.Deps.PlayerInventoryService
				local hotbarSlot = placeData.hotbarSlot or 1
				if not inventoryService:ConsumeFromHotbar(player, hotbarSlot, blockId) then
					self:RejectBlockChange(player, {x = tpos.X, y = tpos.Y, z = tpos.Z}, "consume_failed")
					return
				end
			end
			-- Convert block to farmland at target location
			self:SetBlock(tpos.X, tpos.Y, tpos.Z, BLOCK.FARMLAND, player)
			return
		end
	end

	-- 2) Planting: redirect seed/produce items to stage-0 crop if above farmland
	local function seedToCrop(item)
		if item == BLOCK.WHEAT_SEEDS then return BLOCK.WHEAT_CROP_0 end
		if item == BLOCK.POTATO then return BLOCK.POTATO_CROP_0 end
		if item == BLOCK.CARROT then return BLOCK.CARROT_CROP_0 end
		if item == BLOCK.BEETROOT_SEEDS then return BLOCK.BEETROOT_CROP_0 end
		return nil
	end

	local redirectedCropId = seedToCrop(blockId)
	local plantingCrop = false
	if redirectedCropId then
		-- Must be placing into air with farmland below
		local belowId = self.worldManager:GetBlock(x, y - 1, z)
		local atId = self.worldManager:GetBlock(x, y, z)
		if atId ~= BLOCK.AIR then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "space_occupied")
			return
		end
		if belowId ~= BLOCK.FARMLAND then
			self:RejectBlockChange(player, {x = x, y = y - 1, z = z}, "no_support")
			return
		end
		plantingCrop = true
	end

	-- Debug: Log placement request details
	local targetBlock = self.worldManager:GetBlock(placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z)
	local targetMetadata = self.worldManager:GetBlockMetadata(placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z)
	local targetOrientation = Constants.IsSlab(targetBlock) and Constants.GetVerticalOrientation(targetMetadata) or -1

	print(string.format("[BlockPlace] 📍 Placement request: pos=(%d,%d,%d), blockId=%d", x, y, z, blockId))
	print(string.format("[BlockPlace] 📍 Target block: pos=(%d,%d,%d), id=%d, metadata=%d, orientation=%s",
		placeData.targetBlockPos.X, placeData.targetBlockPos.Y, placeData.targetBlockPos.Z,
		targetBlock, targetMetadata,
		targetOrientation == Constants.BlockMetadata.VERTICAL_TOP and "TOP" or
		targetOrientation == Constants.BlockMetadata.VERTICAL_BOTTOM and "BOTTOM" or "N/A"))
	print(string.format("[BlockPlace] 📍 Face clicked: normal=(%.1f,%.1f,%.1f), hitPos=(%.2f,%.2f,%.2f)",
		placeData.faceNormal.X, placeData.faceNormal.Y, placeData.faceNormal.Z,
		placeData.hitPosition.X, placeData.hitPosition.Y, placeData.hitPosition.Z))

	-- Calculate rotation and vertical orientation for rotatable blocks
	local metadata = 0
	local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local BlockRotation = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRotation)
	local blockInfo = BlockRegistry:GetBlock(blockId)

	if blockInfo and (blockInfo.hasRotation or blockInfo.stairShape or blockInfo.slabShape) then
		-- Get player's facing direction for horizontal rotation (Minecraft parity)
		local lookVector = rootPart.CFrame.LookVector
		local rotation = BlockRotation.GetRotationFromLookVector(lookVector)
		-- In Minecraft, stair yaw is derived from player facing, not clicked face
		metadata = Constants.SetRotation(metadata, rotation)

		-- Calculate vertical orientation (upside-down for stairs, top/bottom for slabs)
		-- Minecraft-style: determines based on which part of the block face was clicked
		local hitPosition = placeData.hitPosition
		local faceNormal = placeData.faceNormal
		local targetBlockPos = placeData.targetBlockPos

		if hitPosition and faceNormal and targetBlockPos then
			local verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM

			-- Calculate relative position within the targeted block face
			-- The hit position is in world coordinates
			local blockWorldPos = Vector3.new(
				targetBlockPos.X * Constants.BLOCK_SIZE,
				targetBlockPos.Y * Constants.BLOCK_SIZE,
				targetBlockPos.Z * Constants.BLOCK_SIZE
			)

			-- Calculate position within the block (0 to BLOCK_SIZE range)
			local relativePos = hitPosition - blockWorldPos

			-- Determine orientation based on face clicked and position (Minecraft logic)
			-- This determines the orientation of the NEW block being placed
			if faceNormal.Y == 1 then
				-- Clicked top face → place bottom slab/stair (sitting on top)
				verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
			elseif faceNormal.Y == -1 then
				-- Clicked bottom face → place top slab/stair (hanging from bottom)
				verticalOrientation = Constants.BlockMetadata.VERTICAL_TOP
			else
				-- Clicked side face → decide top/bottom by Y within FULL block space (Minecraft behavior)
				-- Normalize using full block height to avoid edge rounding on half blocks
				local normalizedY = math.clamp((relativePos.Y / Constants.BLOCK_SIZE), 0, 1)
				local EPS = 1e-3
				if normalizedY > (0.5 + EPS) then
					verticalOrientation = Constants.BlockMetadata.VERTICAL_TOP
				elseif normalizedY < (0.5 - EPS) then
					verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
				else
					-- Tie-break near midline: favor bottom (matches user expectation on boundary)
					verticalOrientation = Constants.BlockMetadata.VERTICAL_BOTTOM
				end
				print(string.format("[BlockPlace] 🔍 Side click: normalizedY=%.3f → %s",
					normalizedY,
					(verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP) and "TOP" or "BOTTOM"))
			end

			metadata = Constants.SetVerticalOrientation(metadata, verticalOrientation)

			-- Compute and persist stair shape (Minecraft parity) on placement
			if blockInfo and blockInfo.stairShape then
				local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
				local function rotLeft(r) return (r + 3) % 4 end
				local function rotRight(r) return (r + 1) % 4 end
				local function rotOpp(r) return (r + 2) % 4 end
				local function dirFromRot(r)
					if r == ROT_N then return 0, 0, 1 end
					if r == ROT_E then return 1, 0, 0 end
					if r == ROT_S then return 0, 0, -1 end
					return -1, 0, 0
				end
				local function isSameHalfStair(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
					local ndef = BlockRegistry:GetBlock(nid)
					if not (ndef and ndef.stairShape) then return false end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					if nvert ~= verticalOrientation then return false end
					return true, Constants.GetRotation(nmeta), Constants.GetStairShape(nmeta)
				end
				local fx, _, fz = dirFromRot(rotation)
				local bx, bz = -fx, -fz
				local rx, _, rz = dirFromRot(rotRight(rotation))
				local lx, _, lz = dirFromRot(rotLeft(rotation))
				local function isDifferentOrientation(checkRot)
					local dx, _, dz = dirFromRot(checkRot)
					local ok, nrot, nshape = isSameHalfStair(x + dx, y, z + dz)
					if not ok then return true end
					if nrot ~= rotation then return true end
					-- Same facing neighbor blocks corner unless neighbor is STRAIGHT (vanilla guard)
					return nshape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
				end
				local shape = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
				-- OUTER via front neighbor perpendicular to our facing
				local okF, frot = isSameHalfStair(x + fx, y, z + fz)
				if okF then
					if frot == rotLeft(rotation) and isDifferentOrientation(rotOpp(frot)) then
						shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT
					elseif frot == rotRight(rotation) and isDifferentOrientation(rotOpp(frot)) then
						shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT
					end
				end
				-- INNER via back neighbor perpendicular to our facing (no additional guard per vanilla behavior)
				if shape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT then
					local okB, brot = isSameHalfStair(x + bx, y, z + bz)
					if okB then
						if brot == rotLeft(rotation) then
							shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT
						elseif brot == rotRight(rotation) then
							shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT
						end
					end
				end
				metadata = Constants.SetStairShape(metadata, shape)
			end

			-- Neighbor snapping for stairs (disabled by default; rendering will honor shape)
			if blockInfo and blockInfo.stairShape and Config and Config.PLACEMENT and Config.PLACEMENT.STAIR_AUTO_ROTATE_ON_PLACE then
				local function rotLeft(r)
					return (r + 3) % 4
				end
				local function rotRight(r)
					return (r + 1) % 4
				end
				local function dirFromRot(r)
					if r == Constants.BlockMetadata.ROTATION_NORTH then return 0, 0, 1 end
					if r == Constants.BlockMetadata.ROTATION_EAST then return 1, 0, 0 end
					if r == Constants.BlockMetadata.ROTATION_SOUTH then return 0, 0, -1 end
					return -1, 0, 0 -- WEST
				end
				local function isSameStair(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					if nid ~= blockId then return false end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					return nvert == verticalOrientation, Constants.GetRotation(nmeta)
				end
				local function shapeForRotation(r)
					-- Returns preferred shape string if achievable with neighbors for rotation r, or nil
					local fx, _, fz = dirFromRot(r)
					local rx, _, rz = dirFromRot(rotRight(r))
					local lx, _, lz = dirFromRot(rotLeft(r))
					-- Inner corner check (highest priority)
					local okFront, frontRot = isSameStair(x + fx, y, z + fz)
					if okFront then
						if frontRot == rotLeft(r) then return "inner_left" end
						if frontRot == rotRight(r) then return "inner_right" end
					end
					-- Outer corner check
					local okLeft, leftRot = isSameStair(x + lx, y, z + lz)
					if okLeft and leftRot == rotLeft(r) then return "outer_left" end
					local okRight, rightRot = isSameStair(x + rx, y, z + rz)
					if okRight and rightRot == rotRight(r) then return "outer_right" end
					return nil
				end

				-- Try current rotation first, then left/right to find a corner snap
				local candidates = {
					rotation,
					rotLeft(rotation),
					rotRight(rotation)
				}
				local snappedRotation = rotation
				local snappedShape = shapeForRotation(rotation)
				if not snappedShape then
					for _, cand in ipairs(candidates) do
						local shape = shapeForRotation(cand)
						if shape then
							-- Prefer inner over outer implicitly because shapeForRotation checks inner first
							snappedRotation = cand
							snappedShape = shape
							break
						end
					end
				end
				if snappedRotation ~= rotation then
					metadata = Constants.SetRotation(metadata, snappedRotation)
					rotation = snappedRotation
					print(string.format("[BlockPlace] 🎯 Stair snapped to %s via neighbor (rotation=%s)", snappedShape or "straight", BlockRotation.GetRotationName(rotation)))
				end
			end

			-- Optional placement assist: choose rotation to yield a corner when possible (outer-first parity, but prefer corner over straight)
			if blockInfo and blockInfo.stairShape and Config and Config.PLACEMENT and Config.PLACEMENT.STAIR_CORNER_ON_PLACEMENT then
				local function rotLeft(r)
					return (r + 3) % 4
				end
				local function rotRight(r)
					return (r + 1) % 4
				end
				local function dirFromRot(r)
					if r == Constants.BlockMetadata.ROTATION_NORTH then return 0, 0, 1 end
					if r == Constants.BlockMetadata.ROTATION_EAST then return 1, 0, 0 end
					if r == Constants.BlockMetadata.ROTATION_SOUTH then return 0, 0, -1 end
					return -1, 0, 0
				end
				local function getStairRot(nx, ny, nz)
					local nid = self.worldManager:GetBlock(nx, ny, nz)
					local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
					local ndef = BlockRegistry:GetBlock(nid)
					if not (ndef and ndef.stairShape) then return nil end
					local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
					local nvert = Constants.GetVerticalOrientation(nmeta)
					if nvert ~= Constants.GetVerticalOrientation(metadata) then return nil end
					return Constants.GetRotation(nmeta)
				end
				local function shapeFor(r)
					local fx, _, fz = dirFromRot(r)
					local rx, _, rz = dirFromRot(rotRight(r))
					local lx, _, lz = dirFromRot(rotLeft(r))
					-- Outer first
					local lrot = getStairRot(x + lx, y, z + lz)
					if lrot and lrot == rotLeft(r) then return "outer_left" end
					local rrot = getStairRot(x + rx, y, z + rz)
					if rrot and rrot == rotRight(r) then return "outer_right" end
					-- Inner second (behind)
					local brot = getStairRot(x + fx, y, z + fz)
					if brot and brot == rotLeft(r) then return "inner_left" end
					if brot and brot == rotRight(r) then return "inner_right" end
					return nil
				end
				local candidates = {rotation, rotLeft(rotation), rotRight(rotation)}
				for _, cand in ipairs(candidates) do
					local s = shapeFor(cand)
					if s then
						rotation = cand
						metadata = Constants.SetRotation(metadata, rotation)
						break
					end
				end
			end

			local orientName = verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP and "TOP/UPSIDE_DOWN" or "BOTTOM/NORMAL"
			print(string.format("[BlockPlace] 🔄 Block orientation: %s rotation, %s vertical (metadata: %d)",
				BlockRotation.GetRotationName(rotation), orientName, metadata))
		else
			print(string.format("[BlockPlace] 🔄 Rotatable block, rotation: %s (%d)", BlockRotation.GetRotationName(rotation), rotation))
		end
	end

	-- Minecraft-style slab merging: Check if we're placing a slab where another slab exists
	-- Special case: When clicking TOP of a bottom slab or BOTTOM of a top slab, redirect placement
	local actualX, actualY, actualZ = x, y, z
	local actualBlockId = plantingCrop and redirectedCropId or blockId
	local actualMetadata = metadata

	print(string.format("[BlockPlace] 🔄 Checking slab merging logic for blockId=%d at (%d,%d,%d)", blockId, x, y, z))

	if Constants.IsSlab(blockId) then
		local faceNormal = placeData.faceNormal

		-- Check if we need to redirect placement for slab stacking
		if faceNormal and faceNormal.Y == 1 then
			-- Clicked top face - check if there's a slab BELOW
			local belowBlock = self.worldManager:GetBlock(x, y - 1, z)
			local belowMetadata = self.worldManager:GetBlockMetadata(x, y - 1, z)

			if Constants.IsSlab(belowBlock) then
				local belowOrientation = Constants.GetVerticalOrientation(belowMetadata)
				-- If clicking top of a bottom slab, place TOP slab at the slab's position
				if belowOrientation == Constants.BlockMetadata.VERTICAL_BOTTOM then
					actualY = y - 1
					-- Override orientation to fill the empty half (top half)
					actualMetadata = Constants.SetVerticalOrientation(metadata, Constants.BlockMetadata.VERTICAL_TOP)
					print(string.format("[BlockPlace] 📍 Redirecting to Y=%d, placing TOP slab to fill empty half", actualY))
				end
			end
		elseif faceNormal and faceNormal.Y == -1 then
			-- Clicked bottom face - check if there's a slab ABOVE
			local aboveBlock = self.worldManager:GetBlock(x, y + 1, z)
			local aboveMetadata = self.worldManager:GetBlockMetadata(x, y + 1, z)

			if Constants.IsSlab(aboveBlock) then
				local aboveOrientation = Constants.GetVerticalOrientation(aboveMetadata)
				-- If clicking bottom of a top slab, place BOTTOM slab at the slab's position
				if aboveOrientation == Constants.BlockMetadata.VERTICAL_TOP then
					actualY = y + 1
					-- Override orientation to fill the empty half (bottom half)
					actualMetadata = Constants.SetVerticalOrientation(metadata, Constants.BlockMetadata.VERTICAL_BOTTOM)
					print(string.format("[BlockPlace] 📍 Redirecting to Y=%d, placing BOTTOM slab to fill empty half", actualY))
				end
			end
		end

		-- Now check the actual target position for merging
		local existingBlock = self.worldManager:GetBlock(actualX, actualY, actualZ)
		local existingMetadata = self.worldManager:GetBlockMetadata(actualX, actualY, actualZ)

		if Constants.IsSlab(existingBlock) then
			-- Both are slabs - check if they can merge (use actualMetadata which may have been overridden)
			local canMerge, fullBlockId = Constants.CanSlabsCombine(
				existingBlock, existingMetadata,
				blockId, actualMetadata
			)

			if canMerge then
				-- Merge into full block
				actualBlockId = fullBlockId
				actualMetadata = Constants.SetDoubleSlabFlag(0, true)
				print(string.format("[BlockPlace] 🧱 Slab merging! Converting slabs at (%d,%d,%d) into full block %d",
					actualX, actualY, actualZ, fullBlockId))
			else
				-- Same type, same orientation - reject as occupied
				print(string.format("[BlockPlace] ❌ Cannot place slab - same orientation already exists at (%d,%d,%d)", actualX, actualY, actualZ))
				self:RejectBlockChange(player, {x = actualX, y = actualY, z = actualZ}, "space_occupied")
				return
			end
		end
	end

	-- Special-case: Minion placement behaves like a spawn (no block created)
	if _isMinionBlock(blockId) then
		-- Only allow placing into air with solid support below (top surface)
		local atId = self.worldManager:GetBlock(x, y, z)
		local belowId = self.worldManager:GetBlock(x, y - 1, z)
		if atId ~= Constants.BlockType.AIR then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "space_occupied")
			return
		end
		if belowId == Constants.BlockType.AIR then
			self:RejectBlockChange(player, {x = x, y = y - 1, z = z}, "no_support")
			return
		end

		-- Consume one item from hotbar
		if self.Deps and self.Deps.PlayerInventoryService then
			local inventoryService = self.Deps.PlayerInventoryService
			local hotbarSlot = placeData.hotbarSlot or 1
			-- Peek metadata before consuming
			local sourceStack = inventoryService.GetHotbarSlot and inventoryService:GetHotbarSlot(player, hotbarSlot)
			local itemMeta = (sourceStack and sourceStack.metadata) or {}
			if not inventoryService:HasItem(player, blockId) then
				self:RejectBlockChange(player, {x = x, y = y, z = z}, "no_item")
				return
			end
			if not inventoryService:ConsumeFromHotbar(player, hotbarSlot, blockId) then
				self:RejectBlockChange(player, {x = x, y = y, z = z}, "consume_failed")
				return
			end
			-- After consume, itemMeta still holds pre-consumption metadata

		-- No prefill platform; minion will place blocks over time

		-- Spawn the minion mob at block top center (feet on surface)
		do
			local mobService = self.Deps and self.Deps.MobEntityService
			if mobService and mobService.SpawnMob then
				local bs = Constants.BLOCK_SIZE
				local worldPos = Vector3.new(
					x * bs + bs * 0.5,
					(y) * bs,
					z * bs + bs * 0.5
				)
				-- Anchor key should reference the supporting platform block (one below target air)
				local key = string.format("%d,%d,%d", x, y - 1, z)
				-- Ensure minion state exists and has a type
				local state = self.minionStateByBlockKey[key]
				if not state then
					local initLevel = tonumber(itemMeta.level) or 1
					local initType = tostring(itemMeta.minionType or itemMeta.type or _defaultMinionTypeForBlock(blockId))
					local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
					local initSlots = tonumber(itemMeta.slotsUnlocked)
					if not initSlots or initSlots < 1 then
						initSlots = MinionConfig.GetSlotsUnlocked(initType, initLevel)
					end
					state = { level = initLevel, slotsUnlocked = initSlots, type = initType, slots = {}, lastActiveAt = os.clock() }
					for i = 1, 12 do
						state.slots[i] = { itemId = 0, count = 0 }
					end
					self.minionStateByBlockKey[key] = state
				else
					state.type = state.type or _defaultMinionTypeForBlock(blockId)
				end
				local mob = mobService:SpawnMob("COBBLE_MINION", worldPos, {
					metadata = {
						unattackable = true,
						stationary = true,
						anchorKey = key,
						minionType = state.type
					}
				})
				if mob and mob.entityId then
					self.minionByBlockKey[key] = mob.entityId
					self.blockKeyByMinion[mob.entityId] = key
					-- Initialize minion state at this anchor if absent
					if not self.minionStateByBlockKey[key] then
						self.minionStateByBlockKey[key] = {
							level = 1,
							slotsUnlocked = 1,
							slots = {}
						}
						for i = 1, 12 do
							self.minionStateByBlockKey[key].slots[i] = { itemId = 0, count = 0 }
						end
					end
				end
			end
		end

		-- Do not place a block; end request
		return
		end
	end

	-- Check inventory (consume the original slab item from player's hotbar)
	if self.Deps and self.Deps.PlayerInventoryService then
		local inventoryService = self.Deps.PlayerInventoryService
		local hotbarSlot = placeData.hotbarSlot or 1

		if not inventoryService:HasItem(player, blockId) then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "no_item")
			return
		end

		local consumed = inventoryService:ConsumeFromHotbar(player, hotbarSlot, blockId)
		if not consumed then
			self:RejectBlockChange(player, {x = x, y = y, z = z}, "consume_failed")
			return
		end
	end

	-- Place block with metadata (use actualX/Y/Z and actualBlockId/Metadata, which may be a full block if slabs merged)
    local success = self:SetBlock(actualX, actualY, actualZ, actualBlockId, player, actualMetadata)
    if success then
        -- Recompute shapes for placed stair and neighbors immediately, so player sees corner on placement
        local placedChanged = self:_recomputeStairShapeAt(actualX, actualY, actualZ)
        local neighborChanged = self:_updateNeighborStairShapes(actualX, actualY, actualZ)
		if actualBlockId ~= blockId then
			print(string.format("Player %s merged slabs into full block %d at (%d, %d, %d)",
				player.Name, actualBlockId, actualX, actualY, actualZ))
		else
			print(string.format("Player %s placed block %d at (%d, %d, %d) with metadata %d",
				player.Name, actualBlockId, actualX, actualY, actualZ, actualMetadata))
		end

		-- Special behavior: Minion (legacy block placement path)
		if _isMinionBlock(actualBlockId) then
			local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
			local minionType = _defaultMinionTypeForBlock(actualBlockId)
			local key = string.format("%d,%d,%d", actualX, actualY, actualZ)
			local state = self.minionStateByBlockKey[key]
			if state and state.type then
				minionType = state.type
			end
			local typeDef = MinionConfig.GetTypeDef(minionType)
			local placeBlockId = typeDef.placeBlockId
			local bonusPlaceId = typeDef.bonusPlaceBlockId
			local bonusPlaceChance = typeDef.bonusPlaceChance or 0
			-- Fill 5x5 layer beneath with resource blocks where air
			local BLOCK = Constants.BlockType
			for dx = -2, 2 do
				for dz = -2, 2 do
					local tx = actualX + dx
					local tz = actualZ + dz
					local ty = actualY - 1
					local existing = self.worldManager:GetBlock(tx, ty, tz)
					if existing == BLOCK.AIR then
						local finalPlaceId = placeBlockId
						if bonusPlaceId and bonusPlaceChance > 0 then
							if math.random() <= bonusPlaceChance then
								finalPlaceId = bonusPlaceId
							end
						end
						self.worldManager:SetBlock(tx, ty, tz, finalPlaceId)
						-- mark modified for save/stream
						local chunkX = math.floor(tx / Constants.CHUNK_SIZE_X)
						local chunkZ = math.floor(tz / Constants.CHUNK_SIZE_Z)
						local key = string.format("%d,%d", chunkX, chunkZ)
						self.modifiedChunks[key] = true
						-- Broadcast change
						for otherPlayer, _ in pairs(self.players) do
							pcall(function()
								EventManager:FireEvent("BlockChanged", otherPlayer, {
									x = tx, y = ty, z = tz,
									blockId = finalPlaceId,
									metadata = 0
								})
							end)
						end
					end
				end
			end

			-- Spawn the minion mob at block center
			local mobService = self.Deps and self.Deps.MobEntityService
			if mobService and mobService.SpawnMob then
				local BLOCK_SIZE = Constants.BLOCK_SIZE
				local pos = Vector3.new(
					actualX * BLOCK_SIZE + BLOCK_SIZE * 0.5,
					(actualY + 1) * BLOCK_SIZE, -- block top (feet on surface)
					actualZ * BLOCK_SIZE + BLOCK_SIZE * 0.5
				)
				-- Ensure minion state exists and has a type
				local state = self.minionStateByBlockKey[key]
				if not state then
					state = { level = 1, slotsUnlocked = 1, type = minionType, slots = {} }
					for i = 1, 12 do
						state.slots[i] = { itemId = 0, count = 0 }
					end
					self.minionStateByBlockKey[key] = state
				else
					state.type = state.type or minionType
				end
				local mob = mobService:SpawnMob("COBBLE_MINION", pos, {
					metadata = {
						unattackable = true,
						stationary = true,
						anchorKey = key,
						minionType = state.type
					}
				})
				if mob and mob.entityId then
					self.minionByBlockKey[key] = mob.entityId
					self.blockKeyByMinion[mob.entityId] = key
				end
			end
		end
	end
end

-- Recompute stair shape for a block and persist metadata (Minecraft parity)
function VoxelWorldService:_recomputeStairShapeAt(x, y, z)
	local blockId = self.worldManager:GetBlock(x, y, z)
	local BlockRegistry = require(game.ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local def = BlockRegistry:GetBlock(blockId)
	if not (def and def.stairShape) then return end
	local meta = self.worldManager:GetBlockMetadata(x, y, z)
	local rotation = Constants.GetRotation(meta)
	local verticalOrientation = Constants.GetVerticalOrientation(meta)
	local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
	local function rotLeft(r) return (r + 3) % 4 end
	local function rotRight(r) return (r + 1) % 4 end
	local function rotOpp(r) return (r + 2) % 4 end
	local function dirFromRot(r)
		if r == ROT_N then return 0, 0, 1 end
		if r == ROT_E then return 1, 0, 0 end
		if r == ROT_S then return 0, 0, -1 end
		return -1, 0, 0
	end
	local function isSameHalfStair(nx, ny, nz)
		local nid = self.worldManager:GetBlock(nx, ny, nz)
		local ndef = BlockRegistry:GetBlock(nid)
		if not (ndef and ndef.stairShape) then return false end
		local nmeta = self.worldManager:GetBlockMetadata(nx, ny, nz)
		local nvert = Constants.GetVerticalOrientation(nmeta)
		if nvert ~= verticalOrientation then return false end
		return true, Constants.GetRotation(nmeta)
	end
	local fx, _, fz = dirFromRot(rotation)
	local bx, bz = -fx, -fz
	local rx, _, rz = dirFromRot(rotRight(rotation))
	local lx, _, lz = dirFromRot(rotLeft(rotation))
	local function isDifferentOrientation(checkRot)
		local dx, _, dz = dirFromRot(checkRot)
		local ok, nrot = isSameHalfStair(x + dx, y, z + dz)
		if not ok then return true end
		return nrot ~= rotation
	end
	local shape = Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
	local okF, frot = isSameHalfStair(x + fx, y, z + fz)
	if okF then
		if frot == rotLeft(rotation) and isDifferentOrientation(rotOpp(frot)) then
			shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT
		elseif frot == rotRight(rotation) and isDifferentOrientation(rotOpp(frot)) then
			shape = Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT
		end
	end
	if shape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT then
		local okB, brot = isSameHalfStair(x + bx, y, z + bz)
		if okB then
			if brot == rotLeft(rotation) and isDifferentOrientation(brot) then
				shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT
			elseif brot == rotRight(rotation) and isDifferentOrientation(brot) then
				shape = Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT
			end
		end
	end
	local newMeta = Constants.SetStairShape(meta, shape)
    if newMeta ~= meta then
		self.worldManager:SetBlockMetadata(x, y, z, newMeta)
		local chunkX = math.floor(x / Constants.CHUNK_SIZE_X)
		local chunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)
		local key = string.format("%d,%d", chunkX, chunkZ)
		self.modifiedChunks[key] = true

		-- Broadcast metadata-only change so clients remesh with new shape
		local blockId = self.worldManager:GetBlock(x, y, z)
		for otherPlayer, _ in pairs(self.players) do
			pcall(function()
				EventManager:FireEvent("BlockChanged", otherPlayer, {
					x = x,
					y = y,
					z = z,
					blockId = blockId,
					metadata = newMeta
				})
			end)
		end
        return true
    end
    return false
end

-- Call after a block changes to update nearby stair shapes
function VoxelWorldService:_updateNeighborStairShapes(x, y, z)
    local changed = {}
    for _, d in ipairs({ {1,0,0}, {-1,0,0}, {0,0,1}, {0,0,-1} }) do
        local nx, ny, nz = x + d[1], y + d[2], z + d[3]
        if self:_recomputeStairShapeAt(nx, ny, nz) then
            changed[#changed + 1] = {nx, ny, nz}
        end
    end
    return changed
end

-- Update player position
function VoxelWorldService:UpdatePlayerPosition(player, positionOrX, maybeZ)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local characterPos = rootPart.Position
	local x, z = characterPos.X, characterPos.Z
	local now = os.clock()

	local state = self.players[player]
	if not state then
		self.players[player] = {
			position = Vector3.new(x, characterPos.Y, z),
			prevPosition = Vector3.new(x, characterPos.Y, z),
			moveDir = Vector3.new(),
			chunks = {},
			lastUpdate = now
		}
	else
		local prev = state.position
		state.prevPosition = prev
		state.position = Vector3.new(x, characterPos.Y, z)
		state.lastUpdate = now

		local dx = state.position.X - prev.X
		local dz = state.position.Z - prev.Z
		local mag = math.sqrt(dx*dx + dz*dz)
		if mag > 1e-3 then
			state.moveDir = Vector3.new(dx / mag, 0, dz / mag)
		end
	end
end

-- Handle player joining
function VoxelWorldService:OnPlayerAdded(player)
	-- DEFENSIVE CHECK: Ensure world is ready before spawning player
	if not self:IsWorldReady() then
		warn(string.format("[VoxelWorldService] ⚠️ World not ready when OnPlayerAdded called for %s - this should not happen!", player.Name))
		-- Don't add player if world isn't ready - they'll be kicked by Bootstrap
		return
	end

	print(string.format("[VoxelWorldService] Adding player %s to world", player.Name))

	local spawnPos = self:_getCurrentSpawnPosition()
	local spawnChunkX, spawnChunkZ = self:_ensureSpawnChunkReady(spawnPos)
	print(string.format("[VoxelWorldService] Spawn position for %s: (%.1f, %.1f, %.1f)",
		player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))

	self.players[player] = {
		position = Vector3.new(spawnPos.X, spawnPos.Y, spawnPos.Z),
		chunks = {},
		lastUpdate = os.clock(),
		tool = nil,
	}

	self:_streamSpawnChunksForPlayer(player, spawnChunkX, spawnChunkZ)

	-- Spawn player after character loads
	player.CharacterAdded:Connect(function(character)
		self:_streamSpawnChunksForPlayer(player, spawnChunkX, spawnChunkZ)
		task.wait(SPAWN_CHUNK_STREAM_WAIT)

		local rootPart = character:WaitForChild("HumanoidRootPart", 5)
		if rootPart then
			-- Spawn on the Skyblock island
			rootPart.CFrame = CFrame.new(spawnPos)
			print(string.format("[VoxelWorldService] Spawned character for %s at (%.1f, %.1f, %.1f)",
				player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			warn(string.format("[VoxelWorldService] Failed to get HumanoidRootPart for %s", player.Name))
		end

		-- Notify client
		EventManager:FireEvent("PlayerEntitySpawned", player, {
			character = character
		})
	end)

	if player.Character then
		self:_streamSpawnChunksForPlayer(player, spawnChunkX, spawnChunkZ)
		task.wait(SPAWN_CHUNK_STREAM_WAIT)
		local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			rootPart.CFrame = CFrame.new(spawnPos)
			print(string.format("[VoxelWorldService] Spawned existing character for %s at (%.1f, %.1f, %.1f)",
				player.Name, spawnPos.X, spawnPos.Y, spawnPos.Z))
		else
			warn(string.format("[VoxelWorldService] Failed to get HumanoidRootPart for existing character %s", player.Name))
		end

		EventManager:FireEvent("PlayerEntitySpawned", player, {
			character = player.Character
		})
	end
end

-- Equip a tool from hotbar slot (client sends slot index); server validates
function VoxelWorldService:OnEquipTool(player, data)
	if not data or type(data.slotIndex) ~= "number" then return end
	local slotIndex = data.slotIndex
	if slotIndex < 1 or slotIndex > 9 then return end

	if not self.Deps or not self.Deps.PlayerInventoryService then return end
	local invService = self.Deps.PlayerInventoryService
	local stack = invService:GetHotbarSlot(player, slotIndex)
	if not stack or stack:IsEmpty() then
		-- Empty slot -> treat as unequip
		local state = self.players[player]
		if state and state.tool then
			state.tool = nil
			-- Broadcast unequip to all clients
			EventManager:FireEventToAll("PlayerToolUnequipped", {
				userId = player.UserId
			})
		end
		return
	end

	local itemId = stack:GetItemId()
	if not ToolConfig.IsTool(itemId) then
		-- Not a tool -> unequip current tool if any
		local state = self.players[player]
		if state and state.tool then
			state.tool = nil
			EventManager:FireEventToAll("PlayerToolUnequipped", {
				userId = player.UserId
			})
		end
		return
	end

	local toolType, toolTier = ToolConfig.GetBlockProps(itemId)
	local state = self.players[player]
	if state then
		state.tool = {
			type = toolType,
			tier = toolTier,
			slotIndex = slotIndex,
			itemId = itemId
		}
		-- Broadcast to all clients so they can render the tool on this player
		EventManager:FireEventToAll("PlayerToolEquipped", {
			userId = player.UserId,
			itemId = itemId
		})
	end
end

-- Unequip current tool (fallback to hand)
function VoxelWorldService:OnUnequipTool(player)
	local state = self.players[player]
	if state and state.tool then
		state.tool = nil
		-- Broadcast unequip to all clients
		EventManager:FireEventToAll("PlayerToolUnequipped", {
			userId = player.UserId
		})
	end
end

-- Sync all players' equipped tools to a requesting client (for late joiners)
-- Also supports the new heldItem field (for blocks)
function VoxelWorldService:OnRequestToolSync(player)
	local toolStates = {}
	for otherPlayer, state in pairs(self.players) do
		-- Check new heldItem field first (unified: tools + blocks)
		if state.heldItem and state.heldItem > 0 then
			toolStates[tostring(otherPlayer.UserId)] = state.heldItem
		-- Fallback to legacy tool field
		elseif state.tool and state.tool.itemId then
			toolStates[tostring(otherPlayer.UserId)] = state.tool.itemId
		end
	end
	EventManager:FireEvent("ToolSync", player, toolStates)
end

-- Track client hotbar selection and broadcast held item to all clients
-- This handles BOTH tools AND blocks in a unified way
function VoxelWorldService:OnSelectHotbarSlot(player, data)
    if not data or type(data.slotIndex) ~= "number" then return end
    local slotIndex = data.slotIndex
    if slotIndex < 1 or slotIndex > 9 then return end

    local state = self.players[player]
    if not state then return end

    state.selectedSlot = slotIndex

    -- Get the item in the selected slot
    if not self.Deps or not self.Deps.PlayerInventoryService then return end
    local invService = self.Deps.PlayerInventoryService
    local stack = invService:GetHotbarSlot(player, slotIndex)

    local itemId = nil
    if stack and not stack:IsEmpty() then
        itemId = stack:GetItemId()
    end

    -- Store held item (can be tool, block, or nil)
    state.heldItem = itemId

    -- Broadcast to all clients so they can render the held item
    if itemId and itemId > 0 then
        EventManager:FireEventToAll("PlayerHeldItemChanged", {
            userId = player.UserId,
            itemId = itemId
        })
    else
        EventManager:FireEventToAll("PlayerHeldItemChanged", {
            userId = player.UserId,
            itemId = nil
        })
    end
end

function VoxelWorldService:GetSelectedHotbarSlot(player)
    local state = self.players[player]
    return state and state.selectedSlot or nil
end

-- Handle player leaving
function VoxelWorldService:OnPlayerRemoved(player)
	if self.players[player] then
		local state = self.players[player]

		-- Broadcast held item cleared (unified: supports both tools and blocks)
		if state and (state.heldItem or state.tool) then
			EventManager:FireEventToAll("PlayerHeldItemChanged", {
				userId = player.UserId,
				itemId = nil
			})
			-- Also fire legacy event for compatibility
			EventManager:FireEventToAll("PlayerToolUnequipped", {
				userId = player.UserId
			})
		end

		if state and state.chunks then
			for key in pairs(state.chunks) do
				self:_removeViewer(player, key)
			end
		end

		if self.blockBreakTracker then
			self.blockBreakTracker:CancelPlayer(player)
		end

		self.players[player] = nil
		self.rateLimits[player] = nil
	end
end

-- Save world data
function VoxelWorldService:SaveWorldData()
	print("===== SaveWorldData called =====")

	-- Throttle rapid duplicate saves (e.g., PlayerRemoving followed by BindToClose)
	self._lastWorldSaveAt = self._lastWorldSaveAt or 0
	local now = os.clock()
	if now - self._lastWorldSaveAt < 2 then
		print("Skipping world save - throttled")
		return
	end
	self._lastWorldSaveAt = now

	if not self.Deps or not self.Deps.WorldOwnershipService then
		warn("WorldOwnershipService not available for saving")
		return
	end

	local ownershipService = self.Deps.WorldOwnershipService
	local worldData = ownershipService:GetWorldData()

	if not worldData then
		warn("No world data to save")
		return
	end

	-- Collect modified chunks
	local modifiedCount = 0
	for key in pairs(self.modifiedChunks) do
		modifiedCount = modifiedCount + 1
	end
	print(string.format("Found %d modified chunks to save", modifiedCount))

	-- Start with existing saved chunks (if any)
	local chunksMap = {}
	if worldData.chunks then
		for _, chunkData in ipairs(worldData.chunks) do
			local key = string.format("%d,%d", chunkData.x, chunkData.z)
			chunksMap[key] = chunkData
			print(string.format("  Preserving existing chunk (%d,%d)", chunkData.x, chunkData.z))
		end
	end

	-- Update/add modified chunks
	for key in pairs(self.modifiedChunks) do
		local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
		cx, cz = tonumber(cx), tonumber(cz)

		local chunk = self.worldManager:GetChunk(cx, cz)
		if chunk then
			local serialized = chunk:SerializeLinear()
			chunksMap[key] = {
				key = key,
				x = cx,
				z = cz,
				data = serialized
			}
			print(string.format("  Updated chunk (%d,%d)", cx, cz))
		end
	end

	-- Convert map back to array
	local chunksToSave = {}
	for _, chunkData in pairs(chunksMap) do
		table.insert(chunksToSave, chunkData)
	end

	-- Update world data
	worldData.chunks = chunksToSave
	worldData.modifiedChunkCount = #chunksToSave
	print(string.format("Prepared %d total chunks for saving", #chunksToSave))

	if self.Deps.MobEntityService then
		self.Deps.MobEntityService:OnWorldDataSaving(worldData)
	end

	-- Save chest data (if ChestStorageService is available)
	if self.Deps.ChestStorageService then
		worldData.chests = self.Deps.ChestStorageService:SaveChestData()
		print(string.format("Saved %d chests", worldData.chests and #worldData.chests or 0))
	end

		-- Save minion states
	if self.minionStateByBlockKey then
		worldData.minions = {}
		for anchorKey, state in pairs(self.minionStateByBlockKey) do
			table.insert(worldData.minions, {
				anchorKey = anchorKey,
				type = state.type or "COBBLESTONE",
				level = state.level,
				slotsUnlocked = state.slotsUnlocked,
					slots = state.slots,
					lastActiveAt = state.lastActiveAt
			})
		end
		print(string.format("Saved %d minion states", #worldData.minions))
	end

	-- Save through ownership service
	print("Calling WorldOwnershipService:SaveWorldData...")
	local success = ownershipService:SaveWorldData(worldData)
	if success then
		print("✅ WorldOwnershipService saved successfully")
	else
		warn("❌ WorldOwnershipService save failed!")
	end

	-- DON'T clear modified chunks - keep them in case of multiple saves
	-- The worldData already contains all chunks (modified + saved)
	-- self.modifiedChunks = {}  -- REMOVED: Causes bug where second save overwrites with 0 chunks

	print(string.format("💾 SaveWorldData complete: Saved %d chunks", #chunksToSave))
	print("=====================================")
end

-- Load world data
function VoxelWorldService:LoadWorldData()
	print("===== LoadWorldData called =====")

	if not self.Deps or not self.Deps.WorldOwnershipService then
		warn("WorldOwnershipService not available for loading")
		return
	end

	local ownershipService = self.Deps.WorldOwnershipService
	local worldData = ownershipService:GetWorldData()

	if not worldData or not worldData.chunks then
		print("No saved chunks to load")
		if worldData and self.Deps.MobEntityService then
			self.Deps.MobEntityService:OnWorldDataLoaded(worldData)
		end
		return
	end

	print(string.format("Found %d chunks in saved data", #worldData.chunks))

	if self.Deps.MobEntityService then
		self.Deps.MobEntityService:OnWorldDataLoaded(worldData)
	end

	-- Load saved chunks
	local loadedCount = 0
	local loadedChunks = {} -- Track loaded chunks to re-stream to players
	for i, chunkData in ipairs(worldData.chunks) do
		if chunkData.x and chunkData.z and chunkData.data then
			print(string.format("  Loading chunk %d/%d at (%d,%d)", i, #worldData.chunks, chunkData.x, chunkData.z))
			local chunk = self.worldManager:GetChunk(chunkData.x, chunkData.z, true)
			if chunk then
				chunk:DeserializeLinear(chunkData.data)
				loadedCount += 1
				table.insert(loadedChunks, {x = chunkData.x, z = chunkData.z})
				print(string.format("  ✅ Chunk (%d,%d) loaded successfully", chunkData.x, chunkData.z))
			else
				warn(string.format("  ❌ Failed to get chunk (%d,%d)", chunkData.x, chunkData.z))
			end
		end
	end

	print(string.format("✅ Loaded %d/%d saved chunks from world data", loadedCount, #worldData.chunks))

	-- Mark loaded chunks as modified so they'll be properly streamed to players
	-- This ensures clients see the restored blocks when they join
	if loadedCount > 0 then
		for _, chunkPos in ipairs(loadedChunks) do
			local key = string.format("%d,%d", chunkPos.x, chunkPos.z)
			-- Note: We don't mark as modifiedChunks (for saving) since they're already saved
			-- But we do need to ensure they're streamed to players
			print(string.format("  📝 Chunk (%d,%d) ready for streaming", chunkPos.x, chunkPos.z))
		end

		-- If players are already online (e.g., Studio reload), re-stream immediately
		local playerCount = 0
		for _ in pairs(self.players) do playerCount = playerCount + 1 end

		if playerCount > 0 then
			print(string.format("🔄 Re-streaming %d loaded chunks to %d online players...", loadedCount, playerCount))
			for player, _ in pairs(self.players) do
				for _, chunkPos in ipairs(loadedChunks) do
					self:StreamChunkToPlayer(player, chunkPos.x, chunkPos.z)
					print(string.format("  📤 Streamed chunk (%d,%d) to %s", chunkPos.x, chunkPos.z, player.Name))
				end
			end
			print("✅ Finished re-streaming loaded chunks")
		else
			print("ℹ️  No players online yet - chunks will stream when players join")
		end
	end

	-- Load chest data (if ChestStorageService is available)
	if self.Deps.ChestStorageService and worldData.chests then
		print(string.format("Loading %d chests...", #worldData.chests))
		self.Deps.ChestStorageService:LoadChestData(worldData.chests)
	end

	-- Load minion states
	if worldData.minions then
		print(string.format("Loading %d minion states...", #worldData.minions))
		for _, minionData in ipairs(worldData.minions) do
			if minionData.anchorKey then
				self.minionStateByBlockKey[minionData.anchorKey] = {
					type = minionData.type or "COBBLESTONE",
					level = minionData.level or 1,
					slotsUnlocked = minionData.slotsUnlocked or 1,
					slots = minionData.slots or {},
					lastActiveAt = minionData.lastActiveAt or os.clock()
				}
				-- Ensure slots are initialized as proper array
				local slots = self.minionStateByBlockKey[minionData.anchorKey].slots
				if not slots or type(slots) ~= "table" then
					self.minionStateByBlockKey[minionData.anchorKey].slots = {}
					for i = 1, 12 do
						self.minionStateByBlockKey[minionData.anchorKey].slots[i] = { itemId = 0, count = 0 }
					end
				else
					-- Verify all 12 slots exist
					for i = 1, 12 do
						if not slots[i] then
							slots[i] = { itemId = 0, count = 0 }
						end
					end
				end
			end
		end
	end

	print("=====================================")
end

-- Get statistics
function VoxelWorldService:GetStats()
	local playerCount = 0
	for _ in pairs(self.players) do playerCount += 1 end

	return {
		players = playerCount,
		chunksStreamed = self.stats.chunksStreamed,
		chunksUnloaded = self.stats.chunksUnloaded,
		blockChanges = self.stats.blockChanges,
		modifiedChunks = self:_countModifiedChunks(),
		lastStreamTimeMs = self.stats.lastStreamTimeMs
	}
end

-- Internal: add viewer
function VoxelWorldService:_addViewer(player, key)
	if not key then return end
	local viewers = self.chunkViewers[key]
	local isNew = false
	if not viewers then
		viewers = {}
		self.chunkViewers[key] = viewers
		isNew = true
	end
	viewers[player] = true
	self.chunkLastAccess[key] = os.clock()

	if isNew and self.Deps and self.Deps.MobEntityService then
		local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
		if cx and cz then
			self.Deps.MobEntityService:OnChunkLoaded(tonumber(cx), tonumber(cz))
		end
	end

	-- Check for minions that need respawning in this chunk
	if isNew then
		self:RespawnMinionsInChunk(key)
	end
end

-- Respawn minions in a chunk if state exists but entity is missing
function VoxelWorldService:RespawnMinionsInChunk(chunkKey)
	if not self.minionStateByBlockKey then return end

	local cx, cz = string.match(chunkKey, "(-?%d+),(-?%d+)")
	if not cx or not cz then return end
	cx, cz = tonumber(cx), tonumber(cz)

	local Constants = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
	local bs = Constants.BLOCK_SIZE

	-- Helper: apply offline fast-forward for a single minion at anchor
	local function fastForwardMinion(anchorKey, state)
		if not state then return end
		-- Determine elapsed time since last activity
		local now = os.clock()
		local last = tonumber(state.lastActiveAt) or now
		local elapsed = math.max(0, now - last)
		if elapsed < 2 then return end -- ignore trivial gaps

		local MinionConfig = require(game.ReplicatedStorage.Configs.MinionConfig)
		local minionType = state.type or "COBBLESTONE"
		local waitSec = MinionConfig.GetWaitSeconds(minionType, state.level or 1)
		if waitSec <= 0 then waitSec = 15 end

		-- Cap offline simulation (e.g., 8 hours)
		local maxSeconds = 8 * 3600
		local simSeconds = math.min(elapsed, maxSeconds)
		local cycles = math.floor(simSeconds / waitSec)
		if cycles <= 0 then
			state.lastActiveAt = now
			return
		end

		-- Derive platform from anchor
		local ax, ay, az = string.match(anchorKey, "(-?%d+),(-?%d+),(-?%d+)")
		if not ax or not ay or not az then
			state.lastActiveAt = now
			return
		end
		ax, ay, az = tonumber(ax), tonumber(ay), tonumber(az)

		local BLOCK = Constants.BlockType
		local placeId = MinionConfig.GetPlaceBlockId(minionType)
		local mineId = MinionConfig.GetMineBlockId(minionType)

		local acted = 0
		for i = 1, cycles do
			-- Scan 5x5 footprint on platform Y
			local targetForPlace
			local targetForMine
			for dz = -2, 2 do
				for dx = -2, 2 do
					local bx = ax + dx
					local bz = az + dz
					local id = self.worldManager:GetBlock(bx, ay, bz)
					if id == BLOCK.AIR and not targetForPlace then
						targetForPlace = { x = bx, y = ay, z = bz }
					elseif id == mineId and not targetForMine then
						targetForMine = { x = bx, y = ay, z = bz }
					end
				end
			end
			local target = targetForPlace or targetForMine
			if not target then
				break
			end
			if targetForPlace and target == targetForPlace then
				-- Place
				if self.worldManager:GetBlock(target.x, target.y, target.z) == BLOCK.AIR then
					-- Use SetBlock to broadcast
					self:SetBlock(target.x, target.y, target.z, placeId, nil, 0)
					acted += 1
				end
			else
				-- Mine (if storage can accept)
				if self.worldManager:GetBlock(target.x, target.y, target.z) == mineId then
					local added = self.AddItemToMinion and self:AddItemToMinion(anchorKey, mineId, 1)
					if added then
						self:SetBlock(target.x, target.y, target.z, BLOCK.AIR, nil, 0)
						acted += 1
					else
						-- storage full; stop mining further
						break
					end
				end
			end
		end

		-- Update last active time
		state.lastActiveAt = now
	end

	-- Check all minion states to see if any are in this chunk
	for anchorKey, state in pairs(self.minionStateByBlockKey) do
		local x, y, z = string.match(anchorKey, "(-?%d+),(-?%d+),(-?%d+)")
		if x and y and z then
			x, y, z = tonumber(x), tonumber(y), tonumber(z)
			local minionChunkX = math.floor(x / Constants.CHUNK_SIZE_X)
			local minionChunkZ = math.floor(z / Constants.CHUNK_SIZE_Z)

			if minionChunkX == cx and minionChunkZ == cz then
				-- Apply offline catch-up upon chunk availability
				fastForwardMinion(anchorKey, state)
				-- This minion should be in this chunk
				-- Check if entity exists
				local entityId = self.minionByBlockKey[anchorKey]
				local entityExists = false
				if entityId and self.Deps.MobEntityService then
					local mobService = self.Deps.MobEntityService
					if mobService._worlds then
						for _, ctx in pairs(mobService._worlds) do
							if ctx.mobsById[entityId] then
								entityExists = true
								break
							end
						end
					end
				end

				if not entityExists then
					-- Respawn the minion
					print(string.format("[Minion] Respawning minion at anchor %s", anchorKey))
					local mobService = self.Deps.MobEntityService
					if mobService and mobService.SpawnMob then
						-- Derive minion type for this anchor
						local state = self.minionStateByBlockKey[anchorKey]
						local minionType = (state and state.type) or "COBBLESTONE"
						local worldPos = Vector3.new(
							x * bs + bs * 0.5,
							(y + 1) * bs,
							z * bs + bs * 0.5
						)
						local mob = mobService:SpawnMob("COBBLE_MINION", worldPos, {
							metadata = {
								unattackable = true,
								stationary = true,
								anchorKey = anchorKey,
								minionType = minionType
							}
						})
						if mob and mob.entityId then
							self.minionByBlockKey[anchorKey] = mob.entityId
							self.blockKeyByMinion[mob.entityId] = anchorKey
							print(string.format("[Minion] Successfully respawned minion entity %s", tostring(mob.entityId)))
						end
					end
				end
			end
		end
	end
end

-- Internal: remove viewer
function VoxelWorldService:_removeViewer(player, key)
	if not key then return end
	local viewers = self.chunkViewers[key]
	if viewers then
		viewers[player] = nil
		local empty = true
		for _ in pairs(viewers) do empty = false break end
		if empty then
			self.chunkViewers[key] = nil
			self.chunkLastAccess[key] = os.clock()
			if self.Deps and self.Deps.MobEntityService then
				local cx, cz = string.match(key, "(-?%d+),(-?%d+)")
				if cx and cz then
					self.Deps.MobEntityService:OnChunkUnloaded(tonumber(cx), tonumber(cz))
				end
			end
		end
	end
end

-- Internal: prune unused chunks
function VoxelWorldService:_pruneUnusedChunks()
	-- No-op for now - chunks are managed by viewer counts
end

-- Internal: count modified chunks
function VoxelWorldService:_countModifiedChunks()
	local count = 0
	for _ in pairs(self.modifiedChunks) do count += 1 end
	return count
end

-- Destroy service
function VoxelWorldService:Destroy()
	-- Save before shutdown
	self:SaveWorldData()
	print("VoxelWorldService: Cleanup complete")
end

return VoxelWorldService
