--[[
	MobReplicationController.lua

	Client-side controller responsible for receiving replicated mob entity updates
	from the server and rendering them locally with lightweight procedural animation.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)
local MobModel = require(ReplicatedStorage.Shared.Mobs.MobModel)
local MobAnimator = require(ReplicatedStorage.Shared.Mobs.MobAnimator)

local MobReplicationController = {}
MobReplicationController.__index = MobReplicationController

local LOCAL_PLAYER = Players.LocalPlayer

-- Lightweight client-side budgets
local MAX_ANIM_DISTANCE = 200
local MAX_ANIMATED_PER_FRAME = 50
local INTERP_DELAY = 0.125 -- seconds of buffer for snapshot interpolation
local MAX_BUFFER_SECONDS = 1.0

-- Mob-specific interpolation tuning for more organic movement
local INTERP_SPEEDS = {
	SHEEP = 22,   -- Slightly more responsive than zombies for organic feel
	ZOMBIE = 18,  -- Standard interpolation
	DEFAULT = 18
}

local function ensureFolder()
	local folder = workspace:FindFirstChild("MobEntities")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MobEntities"
		folder.Parent = workspace
	end
	return folder
end

function MobReplicationController.new()
	local self = setmetatable({
		mobs = {},
		folder = ensureFolder(),
	}, MobReplicationController)

	self:_registerEvents()
	self:_startRenderLoop()

	return self
end

function MobReplicationController:_registerEvents()
	EventManager:RegisterEvent("MobSpawned", function(data)
		self:_onMobSpawned(data)
	end)

	EventManager:RegisterEvent("MobBatchUpdate", function(data)
		self:_onMobBatchUpdate(data)
	end)

	EventManager:RegisterEvent("MobDespawned", function(data)
		self:_onMobDespawned(data)
	end)

	EventManager:RegisterEvent("MobDamaged", function(data)
		self:_onMobDamaged(data)
	end)

	EventManager:RegisterEvent("MobDied", function(data)
		self:_onMobDied(data)
	end)
end

function MobReplicationController:_startRenderLoop()
	RunService.RenderStepped:Connect(function(dt)
		self:_onRenderStep(dt)
	end)
end

local function cframeFromPositionAndYaw(positionArray, yawDegrees)
	local position = Vector3.new(positionArray[1], positionArray[2], positionArray[3])
	local yaw = math.rad(yawDegrees or 0)
	local rotation = CFrame.Angles(0, yaw, 0)
	return CFrame.new(position) * rotation
end

local function shortestAngleDiffDeg(a, b)
	local d = (b - a) % 360
	if d > 180 then d -= 360 end
	return d
end

local function angleLerpDeg(a, b, t)
	return a + shortestAngleDiffDeg(a, b) * math.clamp(t, 0, 1)
end

-- Simple Minecraft-style death animation: tip over and sink, then cleanup
local function playDeathAnimation(model, onComplete)
	if not model or not model:IsA("Model") then
		if onComplete then onComplete() end
		return
	end
	-- Use a CFrameValue tween driving Model:PivotTo
	local cfVal = Instance.new("CFrameValue")
	local startCf = model:GetPivot()
	cfVal.Value = startCf
	local pivotConn = cfVal:GetPropertyChangedSignal("Value"):Connect(function()
		model:PivotTo(cfVal.Value)
	end)
	-- Disable collisions to avoid physics fighting the tween
	local fadeParts = {}
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.CanCollide = false
			table.insert(fadeParts, inst)
		end
	end
	-- Find ground Y under current position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local origin = startCf.Position + Vector3.new(0, 1, 0)
	local hit = workspace:Raycast(origin, Vector3.new(0, -512, 0), params)
	local groundY = (hit and hit.Position.Y) or (origin.Y - 2)
	-- Tip sideways (local roll ±90 deg) randomly left/right and move toward ground a bit
	local rollRad = math.rad((math.random(0, 1) == 0) and -90 or 90)
	local tipped = startCf * CFrame.Angles(0, 0, rollRad) * CFrame.new(0, -0.5, 0)
	local onGround = CFrame.new(tipped.Position.X, groundY + 0.2, tipped.Position.Z) * tipped.Rotation
	-- Phase 1: tip to ground
	local t1 = TweenService:Create(cfVal, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = onGround })
	-- Phase 2: sink and fade
	local sinkCf = onGround * CFrame.new(0, -0.8, 0)
	local alphaVal = Instance.new("NumberValue")
	alphaVal.Value = 0
	local alphaConn = alphaVal:GetPropertyChangedSignal("Value"):Connect(function()
		for _, p in ipairs(fadeParts) do
			if p.Parent then
				p.Transparency = math.clamp(alphaVal.Value, 0, 1)
			end
		end
	end)
	local t2 = TweenService:Create(cfVal, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = sinkCf })
	local t3 = TweenService:Create(alphaVal, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
	-- Run the sequence
	t1:Play()
	t1.Completed:Wait()
	t2:Play()
	t3:Play()
	-- Wait for either to complete (both have same duration)
	t2.Completed:Wait()
	-- Cleanup tween helpers
	pivotConn:Disconnect()
	alphaConn:Disconnect()
	cfVal:Destroy()
	alphaVal:Destroy()
	-- Finish
	if onComplete then onComplete() end
end

function MobReplicationController:_onMobSpawned(data)
	if not data or not data.entityId or not data.mobType or not data.position then
		return
	end

	self:_onMobDespawned({ entityId = data.entityId })

	local variant
	if data.variant then
		variant = { id = data.variant }
	end

	local build = MobModel.Build(data.mobType, variant)
	if not build or not build.model then
		return
	end

	build.model.Parent = self.folder
	-- Expose entity id on the client-side model for hit detection
	build.model:SetAttribute("MobEntityId", data.entityId)

	local rootOffset = (build.definition and build.definition.model and build.definition.model.rootOffset) or Vector3.new()
	local worldPos = cframeFromPositionAndYaw(data.position, data.rotation)

	-- Facing adjustment per mob type (sheep/cow/chicken models face -Z by default)
	local facingAdjust = 0
	if data.mobType == "SHEEP" or data.mobType == "COW" or data.mobType == "CHICKEN" then
		facingAdjust = math.rad(180)
	end
	local adjustedCFrame = worldPos * CFrame.Angles(0, facingAdjust, 0) * CFrame.new(rootOffset)

	local mobState = {
		id = data.entityId,
		mobType = data.mobType,
		build = build,
		animator = MobAnimator.new(build),
		state = data.state or "idle",
		velocity = Vector3.new(),
		health = data.health,
		maxHealth = data.maxHealth,
		lastUpdate = os.clock(),
		currentCFrame = adjustedCFrame,
		targetCFrame = nil,
		rootOffset = rootOffset,
		currentYawDeg = data.rotation or 0,
		snapshots = {},
		sounds = build.sounds or {},
		nextSoundTime = 0, -- For random sound timing
	}

	build.root.CFrame = mobState.currentCFrame
	build.model:PivotTo(mobState.currentCFrame)

	self.mobs[data.entityId] = mobState

	-- Seed snapshot buffer so interpolation has an initial value
	local now = os.clock()
	table.insert(mobState.snapshots, {
		time = now,
		pos = Vector3.new(data.position[1], data.position[2], data.position[3]),
		yaw = data.rotation or 0,
		vel = Vector3.new(0, 0, 0),
	})
end

function MobReplicationController:_onMobBatchUpdate(data)
	if not data or not data.mobs then
		return
	end

	for _, update in ipairs(data.mobs) do
		local mob = self.mobs[update.entityId]
		if mob then
			local now = os.clock()
			local worldPos = cframeFromPositionAndYaw(update.position, update.rotation)
			local facingAdjust = 0
			if mob.mobType == "SHEEP" or mob.mobType == "COW" or mob.mobType == "CHICKEN" then
				facingAdjust = math.rad(180)
			end
			mob.targetCFrame = worldPos * CFrame.Angles(0, facingAdjust, 0) * CFrame.new(mob.rootOffset or Vector3.new())
			mob.velocity = Vector3.new(update.velocity[1], update.velocity[2], update.velocity[3])
			mob.state = update.state or mob.state
			mob.health = update.health or mob.health
			mob.maxHealth = update.maxHealth or mob.maxHealth
			mob.lastUpdate = now

			-- Push snapshot for buffered interpolation
			local buf = mob.snapshots or {}
			mob.snapshots = buf
			table.insert(buf, {
				time = now,
				pos = Vector3.new(update.position[1], update.position[2], update.position[3]),
				yaw = update.rotation or 0,
				vel = Vector3.new(update.velocity[1], update.velocity[2], update.velocity[3]),
			})
			-- Trim old snapshots by time and cap length
			local cutoff = now - MAX_BUFFER_SECONDS
			while #buf > 0 and buf[1].time < cutoff do
				table.remove(buf, 1)
			end
			if #buf > 14 then
				while #buf > 14 do table.remove(buf, 1) end
			end
		end
	end
end

function MobReplicationController:_onMobDespawned(data)
	if not data or not data.entityId then
		return
	end

	local mob = self.mobs[data.entityId]
	if mob then
		if mob.build and mob.build.model then
			mob.build.model:Destroy()
		end
		self.mobs[data.entityId] = nil
	end
end

function MobReplicationController:_onMobDamaged(data)
	local mob = data and self.mobs[data.entityId]
	if not mob then
		return
	end
	-- Ignore damage visuals/combat tagging for static minions
	if mob.mobType == "COBBLE_MINION" then
		return
	end
	-- Simple damage flash by briefly changing root transparency
	local model = mob.build.model
	if model and model.PrimaryPart then
		local originalColor = {}
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				originalColor[part] = part.Color
				part.Color = Color3.new(1, 0.4, 0.4)
			end
		end
		task.delay(0.1, function()
			for part, color in pairs(originalColor) do
				if part and part.Parent then
					part.Color = color
				end
			end
		end)
		-- Apply combat tag attributes for unified highlight/flash visuals
		local ttl = (CombatConfig and CombatConfig.COMBAT_TTL_SECONDS) or 8
		local now = os.clock()
		pcall(function()
			model:SetAttribute("IsInCombat", true)
			model:SetAttribute("CombatExpiresAt", now + ttl)
			model:SetAttribute("LastHitAt", now)
		end)
		-- Schedule expiry check (refresh-safe)
		task.delay(ttl + 0.05, function()
			local ok, expiresAt = pcall(function()
				return model:GetAttribute("CombatExpiresAt")
			end)
			if ok and type(expiresAt) == "number" and os.clock() >= expiresAt then
				pcall(function()
					model:SetAttribute("IsInCombat", false)
				end)
			end
		end)
	end
end

function MobReplicationController:_onMobDied(data)
	if not data then
		return
	end
	-- Play a brief Minecraft-style death animation before removing the model
	local mob = self.mobs[data.entityId]
	if not mob or not mob.build or not mob.build.model then
		self:_onMobDespawned(data)
		return
	end
	local model = mob.build.model
	-- Stop tracking this mob so the render loop doesn't move it during the animation
	self.mobs[data.entityId] = nil
	-- Run animation, then destroy the model
	task.spawn(function()
		pcall(function()
			playDeathAnimation(model, function()
				if model and model.Parent then
					model:Destroy()
				end
			end)
		end)
	end)
end

function MobReplicationController:_onRenderStep(deltaTime)
	local now = os.clock()
	local lpRoot = LOCAL_PLAYER and LOCAL_PLAYER.Character and LOCAL_PLAYER.Character:FindFirstChild("HumanoidRootPart")
	local lpPos = lpRoot and lpRoot.Position
	local animatedCount = 0
	-- Dynamic animation budget based on frame time; prioritize nearby mobs first
	local scale = (1/60) / math.max(1e-3, deltaTime)
	local maxAnimate = math.floor(math.clamp(MAX_ANIMATED_PER_FRAME * math.clamp(scale, 0.6, 1.3), 12, 72))
	local PRIORITY_NEAR = 80
	local deferred = {}

	for _, mob in pairs(self.mobs) do
		-- Calculate time since last server update
		local timeSinceUpdate = now - mob.lastUpdate

		-- Distance gating
		local isNear = true
		if lpPos then
			local mobPos = mob.currentCFrame and mob.currentCFrame.Position or Vector3.new()
			isNear = (mobPos - lpPos).Magnitude <= MAX_ANIM_DISTANCE
		end

		if isNear then
			-- Static minions: snap to exact position, no interpolation or animation
			if mob.mobType == "COBBLE_MINION" then
				if mob.targetCFrame then
					mob.currentCFrame = mob.targetCFrame
					mob.build.model:PivotTo(mob.currentCFrame)
				end
				-- Don't process animation or interpolation for static minions
			elseif true then
			local newCFrame = nil
			local buf = mob.snapshots
            local usedTargetYaw = false
			if buf and #buf >= 2 then
				local renderTime = now - INTERP_DELAY
				local a, b = nil, nil
				-- Find bracket snapshots around renderTime
				for i = 1, #buf - 1 do
					local s0 = buf[i]
					local s1 = buf[i + 1]
					if s0.time <= renderTime and s1.time >= renderTime then
						a, b = s0, s1
						break
					end
				end
				if not a or not b then
					-- Fallback to last two snapshots
					a = buf[math.max(1, #buf - 1)]
					b = buf[#buf]
				end
				local span = math.max(1e-3, b.time - a.time)
				local t = math.clamp((renderTime - a.time) / span, 0, 1)
				local deltaPos = (b.pos - a.pos)
                -- Position interpolation only (no yaw interpolation)
                local pos
				if deltaPos.Magnitude > 30 then
                    pos = b.pos
				else
                    pos = a.pos:Lerp(b.pos, t)
                end
                -- Snap yaw to latest snapshot (b)
                local yawRad = math.rad(b.yaw or 0)
                -- Facing adjustment and root offset later
                newCFrame = CFrame.new(pos) * CFrame.Angles(0, yawRad, 0)
			else
                -- Fallback: use latest known yaw from last snapshot (no interpolation) and predict position
                local lastYawDeg
                if buf and #buf >= 1 then
                    lastYawDeg = buf[#buf].yaw
                end
				if mob.targetCFrame then
					-- Extract ground position from targetCFrame (remove rootOffset)
					local rootOffset = mob.rootOffset or Vector3.new()
					local targetPos = (mob.targetCFrame * CFrame.new(-rootOffset)).Position
					local leadTime = math.clamp(timeSinceUpdate, 0, 0.35)
					local predictedPos = targetPos + mob.velocity * leadTime
                    local yawRad
                    if lastYawDeg ~= nil then
                        yawRad = math.rad(lastYawDeg)
                    else
                        yawRad = select(2, mob.targetCFrame:ToOrientation()) or 0
                        usedTargetYaw = true
                    end
                    newCFrame = CFrame.new(predictedPos) * CFrame.Angles(0, yawRad, 0)
				end
			end
			if newCFrame then
                -- Facing adjustment
                local facingAdjust = 0
				if mob.mobType == "SHEEP" or mob.mobType == "COW" or mob.mobType == "CHICKEN" then
					facingAdjust = math.rad(180)
				end
                -- Extract pos and use exact yaw (no rotation smoothing); smooth position only
                local desiredPos = newCFrame.Position
                local _, yawRad = newCFrame:ToOrientation()
                if not usedTargetYaw then
                    yawRad = (yawRad or 0) + facingAdjust
                else
                    -- targetCFrame already had facing adjust baked in
                    yawRad = (yawRad or 0)
                end
                -- Use mob-specific interpolation speed for more organic movement
                local interpSpeed = INTERP_SPEEDS[mob.mobType] or INTERP_SPEEDS.DEFAULT
                local alpha = 1 - math.exp(-deltaTime * interpSpeed)
                local rootOffset = mob.rootOffset or Vector3.new()
                local currentPosNoOffset = desiredPos
                if mob.currentCFrame then
                    currentPosNoOffset = (mob.currentCFrame * CFrame.new(-rootOffset)).Position
                end
                local smoothedPos = currentPosNoOffset:Lerp(desiredPos, alpha)
                local finalCFrame = CFrame.new(smoothedPos) * CFrame.Angles(0, yawRad, 0) * CFrame.new(mob.rootOffset or Vector3.new())
                mob.currentCFrame = finalCFrame
				mob.build.model:PivotTo(mob.currentCFrame)
			end
			end -- end of elseif true block
		end

		if isNear and mob.animator and mob.mobType ~= "COBBLE_MINION" then
			local dist = 1e9
			if lpPos then
				local mobPos = mob.currentCFrame and mob.currentCFrame.Position or Vector3.new()
				dist = (mobPos - lpPos).Magnitude
			end
			if dist <= PRIORITY_NEAR then
				if animatedCount < maxAnimate then
			mob.animator:SetVelocity(mob.velocity)
			mob.animator:SetState(mob.state)
			mob.animator:Step(deltaTime)
			animatedCount += 1
		end
			else
				deferred[#deferred + 1] = mob
			end
		end

		-- Handle mob sounds (skip for minions)
		if mob.mobType ~= "COBBLE_MINION" and mob.sounds and mob.state == "graze" and now >= mob.nextSoundTime then
			local grazeSound = mob.sounds.GrazeSound
			if grazeSound and not grazeSound.IsPlaying then
				grazeSound:Play()
				-- Schedule next sound randomly between 2-5 seconds
				mob.nextSoundTime = now + math.random(200, 500) / 100
			end
		end
	end

	-- Second pass: animate remaining near-but-farther mobs until budget is met
	for i = 1, #deferred do
		if animatedCount >= maxAnimate then break end
		local mob = deferred[i]
		mob.animator:SetVelocity(mob.velocity)
		mob.animator:SetState(mob.state)
		mob.animator:Step(deltaTime)
		animatedCount += 1
	end
end

return MobReplicationController.new()


