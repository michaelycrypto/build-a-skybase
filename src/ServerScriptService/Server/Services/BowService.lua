--[[
	BowService.lua
	Server-side bow shooting and arrow projectile management.
	Handles validation, arrow consumption, and physics simulation.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Logger = require(ReplicatedStorage.Shared.Logger)
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)

local BowService = {}
BowService.__index = BowService

function BowService.new()
	local self = setmetatable({}, BowService)
	self.Deps = {}
	self._logger = Logger:CreateContext("BowService")
	self._projectiles = {}
	self._lastShotAt = {}
	self._heartbeatConn = nil
	return self
end

function BowService:Init()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
	end
	self._heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		self:_stepProjectiles(dt)
	end)
end

function BowService:Start() end

function BowService:Destroy()
	if self._heartbeatConn then
		self._heartbeatConn:Disconnect()
		self._heartbeatConn = nil
	end
end

-- Convert remote event data to Vector3
local function coerceVector(vec)
	if typeof(vec) == "Vector3" then
		return vec
	end
	if type(vec) == "table" and vec.x and vec.y and vec.z then
		return Vector3.new(vec.x, vec.y, vec.z)
	end
	return nil
end

-- Create arrow projectile with proper appearance
local function createArrowProjectile()
	local arrow = Instance.new("Part")
	arrow.Name = "ArrowProjectile"
	arrow.Size = Vector3.new(0.2, 0.2, 1.2)
	arrow.Color = Color3.fromRGB(139, 90, 43) -- Wood brown
	arrow.Material = Enum.Material.Wood
	arrow.CanCollide = false
	arrow.Massless = true
	arrow.CastShadow = false

	-- Add arrow tip (darker point)
	local tip = Instance.new("Part")
	tip.Name = "Tip"
	tip.Size = Vector3.new(0.15, 0.15, 0.25)
	tip.Color = Color3.fromRGB(80, 80, 80) -- Iron gray
	tip.Material = Enum.Material.Metal
	tip.CanCollide = false
	tip.Massless = true
	tip.CastShadow = false

	local tipWeld = Instance.new("WeldConstraint")
	tipWeld.Part0 = arrow
	tipWeld.Part1 = tip
	tipWeld.Parent = arrow

	tip.CFrame = arrow.CFrame * CFrame.new(0, 0, -arrow.Size.Z / 2 - tip.Size.Z / 2)
	tip.Parent = arrow

	-- Trail for visibility
	local trailStart = Instance.new("Attachment")
	trailStart.Name = "TrailStart"
	trailStart.Position = Vector3.new(0, 0, arrow.Size.Z / 2)
	trailStart.Parent = arrow

	local trailEnd = Instance.new("Attachment")
	trailEnd.Name = "TrailEnd"
	trailEnd.Position = Vector3.new(0, 0, -arrow.Size.Z / 2)
	trailEnd.Parent = arrow

	local trail = Instance.new("Trail")
	trail.Name = "ArrowTrail"
	trail.Attachment0 = trailStart
	trail.Attachment1 = trailEnd
	trail.Lifetime = 0.15
	trail.LightInfluence = 1
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200))
	trail.Parent = arrow

	return arrow
end

local function buildRayParams(ignoreList)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList
	params.IgnoreWater = true
	return params
end

local function applyInaccuracy(direction, power)
	local spreadMin = BowConfig.INACCURACY_AT_MIN
	local spreadMax = BowConfig.INACCURACY_AT_MAX
	local spreadDeg = math.clamp(spreadMin - (spreadMin - spreadMax) * power, spreadMax, spreadMin)
	if spreadDeg <= 0 then
		return direction
	end
	local spreadRad = math.rad(spreadDeg)
	local randYaw = (math.random() * 2 - 1) * spreadRad
	local randPitch = (math.random() * 2 - 1) * spreadRad
	local cf = CFrame.lookAt(Vector3.zero, direction)
	return (cf * CFrame.Angles(randPitch, randYaw, 0)).LookVector.Unit
end

local function offsetOrigin(origin, direction)
	return origin + direction.Unit * 0.5 + Vector3.new(0, 0.1, 0)
end

-- Apply combat tag and hit flash to a character (same as melee combat)
local function tagCombatHit(attackerChar, victimChar)
	local now = os.clock()
	local ttl = CombatConfig.COMBAT_TTL_SECONDS or 8

	-- Tag attacker
	if attackerChar then
		pcall(function()
			attackerChar:SetAttribute("IsInCombat", true)
			attackerChar:SetAttribute("CombatExpiresAt", now + ttl)
		end)
	end

	-- Tag victim and trigger flash
	if victimChar then
		pcall(function()
			victimChar:SetAttribute("IsInCombat", true)
			victimChar:SetAttribute("CombatExpiresAt", now + ttl)
			victimChar:SetAttribute("LastHitAt", now) -- Triggers client-side flash effect
		end)
	end
end

-- Get the player's upper torso position for arrow origin (server-authoritative)
-- Arrow originates from chest/upper torso area like Minecraft
local function getPlayerShootPosition(player)
	local character = player and player.Character
	if not character then return nil end

	-- Try to get UpperTorso (R15) or Torso (R6)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if upperTorso then
		return upperTorso.Position
	end

	-- Fallback to HumanoidRootPart with slight upward offset
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position + Vector3.new(0, 0.5, 0)
	end

	return nil
end

function BowService:_spawnProjectile(player, origin, direction, chargeSeconds)
	local projectile = createArrowProjectile()
	projectile.CFrame = CFrame.lookAt(origin, origin + direction)
	projectile.Parent = Workspace

	local speed, power = BowConfig.GetSpeed(chargeSeconds)
	local dir = applyInaccuracy(direction, power)
	local velocity = dir * speed

	pcall(function()
		projectile.AssemblyLinearVelocity = velocity
		projectile:SetNetworkOwner(nil)
	end)

	-- Roll for critical hit (Minecraft-style: only at full charge + random chance)
	local isCrit = BowConfig.RollCrit(power)

	self._projectiles[projectile] = {
		player = player,
		velocity = velocity,
		power = power,
		lastPos = origin,
		spawnTime = os.clock(),
		crit = isCrit,
		ignoreUntil = os.clock() + BowConfig.IGNORE_SHOOTER_TIME,
	}
end

function BowService:_handleImpact(projectile, hit, hitPos, info)
	self._projectiles[projectile] = nil
	if not projectile then return end

	pcall(function()
		projectile.AssemblyLinearVelocity = Vector3.zero

		local dir = info.direction.Magnitude > 0 and info.direction.Unit or Vector3.new(0, 1, 0)
		projectile.CFrame = CFrame.lookAt(hitPos - dir * 0.1, hitPos)

		if hit and hit:IsA("BasePart") then
			projectile.Anchored = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hit
			weld.Part1 = projectile
			weld.Parent = projectile
		else
			projectile.Anchored = true
		end

		-- Fade out trail
		local trail = projectile:FindFirstChild("ArrowTrail")
		if trail then
			trail.Enabled = false
		end
	end)

	-- Play random hit sound
	if BowConfig.HIT_SOUNDS and #BowConfig.HIT_SOUNDS > 0 then
		local soundId = BowConfig.HIT_SOUNDS[math.random(1, #BowConfig.HIT_SOUNDS)]
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.Volume = BowConfig.HIT_SOUND_VOLUME or 0.8
		sound.RollOffMaxDistance = 100
		sound.RollOffMinDistance = 10
		sound.Parent = projectile
		sound:Play()
		-- Cleanup sound after it finishes
		task.delay(sound.TimeLength + 0.5, function()
			if sound and sound.Parent then
				sound:Destroy()
			end
		end)
	end

	-- Apply damage (Minecraft-style scaling based on charge)
	local model = hit and hit:FindFirstAncestorOfClass("Model")
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		local rawDamage = BowConfig.GetDamage(info.power, info.crit)

		-- Check if target is a player (for armor reduction)
		local targetPlayer = game.Players:GetPlayerFromCharacter(model)
		if targetPlayer and self.Deps and self.Deps.DamageService then
			-- Player target - apply armor reduction
			self.Deps.DamageService:DamagePlayer(targetPlayer, rawDamage, "projectile", info.player)
		else
			-- Mob or NPC - direct damage
			humanoid:TakeDamage(rawDamage)
		end

		-- Apply knockback (scales with charge power, like Minecraft)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local kb = BowConfig.KNOCKBACK_STRENGTH * info.power
			if kb > 0 then
				local bodyVel = Instance.new("BodyVelocity")
				bodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				-- Knockback in arrow direction + slight upward lift
				bodyVel.Velocity = info.direction * kb + Vector3.new(0, kb * 0.3, 0)
				bodyVel.Parent = root
				Debris:AddItem(bodyVel, 0.2)
			end
		end

		-- Apply combat tag and hit flash (same visual effect as melee)
		local attackerChar = info.player and info.player.Character
		tagCombatHit(attackerChar, model)
	end

	-- Cleanup after delay
	task.delay(BowConfig.STUCK_LIFETIME, function()
		if projectile and projectile.Parent then
			projectile:Destroy()
		end
	end)
end

function BowService:_stepProjectiles(dt)
	if not next(self._projectiles) then return end

	local gravity = Vector3.new(0, -Workspace.Gravity, 0)

	for projectile, data in pairs(self._projectiles) do
		if not projectile or not projectile.Parent then
			self._projectiles[projectile] = nil
			continue
		end

		local now = os.clock()
		if (now - data.spawnTime) > BowConfig.MAX_LIFETIME then
			local trail = projectile:FindFirstChild("ArrowTrail")
			if trail then trail.Enabled = false end
			projectile:Destroy()
			self._projectiles[projectile] = nil
			continue
		end

		local oldPos = data.lastPos
		local newPos = oldPos + data.velocity * dt + 0.5 * gravity * dt * dt
		data.velocity += gravity * dt

		local ignore = {projectile}
		if data.player and data.player.Character then
			table.insert(ignore, data.player.Character)
		end

		-- Also ignore all existing arrow projectiles (stuck arrows)
		for _, child in ipairs(Workspace:GetChildren()) do
			if child.Name == "ArrowProjectile" and child ~= projectile then
				table.insert(ignore, child)
			end
		end

		local result = Workspace:Raycast(oldPos, newPos - oldPos, buildRayParams(ignore))

		if result then
			-- Grace period for self-hits
			if data.player and data.player.Character and now < data.ignoreUntil then
				if result.Instance:IsDescendantOf(data.player.Character) then
					projectile.CFrame = CFrame.lookAt(newPos, newPos + data.velocity)
					data.lastPos = newPos
					pcall(function() projectile.AssemblyLinearVelocity = data.velocity end)
					continue
				end
			end

			self:_handleImpact(projectile, result.Instance, result.Position, {
				velocity = data.velocity,
				power = data.power,
				direction = data.velocity.Magnitude > 0 and data.velocity.Unit or Vector3.new(0, 1, 0),
				player = data.player,
				crit = data.crit,
			})
		else
			projectile.CFrame = CFrame.lookAt(newPos, newPos + data.velocity)
			data.lastPos = newPos
			pcall(function() projectile.AssemblyLinearVelocity = data.velocity end)
		end
	end
end

function BowService:_validateBowHeld(player, slotIndex)
	local inv = self.Deps and self.Deps.PlayerInventoryService
	if not inv then return false end
	if not slotIndex then return true end

	local stack = inv:GetHotbarSlot(player, slotIndex)
	if not stack or stack:IsEmpty() then return false end

	return stack:GetItemId() == BowConfig.BOW_ITEM_ID
end

function BowService:_resolveSlotIndex(player, slotIndex)
	if slotIndex and self:_validateBowHeld(player, slotIndex) then
		return slotIndex
	end

	local voxelWorld = self.Deps and self.Deps.VoxelWorldService
	if voxelWorld and voxelWorld.GetSelectedHotbarSlot then
		local selected = voxelWorld:GetSelectedHotbarSlot(player)
		if selected and self:_validateBowHeld(player, selected) then
			return selected
		end
	end

	return nil
end

function BowService:OnBowShoot(player, data)
	if not player or not data then return end

	local direction = coerceVector(data.direction)
	local charge = tonumber(data.charge) or 0

	if not direction or direction.Magnitude < 0.1 then return end
	direction = direction.Unit

	local slotIndex = self:_resolveSlotIndex(player, data.slotIndex)
	if not slotIndex then return end

	local inv = self.Deps and self.Deps.PlayerInventoryService
	if not inv then return end

	if inv:GetItemCount(player, BowConfig.ARROW_ITEM_ID) < 1 then return end

	local clampedCharge = math.clamp(charge, BowConfig.MIN_CHARGE_TIME, BowConfig.MAX_DRAW_TIME)
	if clampedCharge < BowConfig.MIN_CHARGE_TIME then return end

	local now = os.clock()
	local last = self._lastShotAt[player] or 0
	if (now - last) < BowConfig.FIRE_COOLDOWN then return end
	self._lastShotAt[player] = now

	-- Server-authoritative: always use the player's upper torso position
	local origin = getPlayerShootPosition(player)
	if not origin then return end

	inv:RemoveItem(player, BowConfig.ARROW_ITEM_ID, 1)

	self:_spawnProjectile(player, offsetOrigin(origin, direction), direction, clampedCharge)
end

return BowService
