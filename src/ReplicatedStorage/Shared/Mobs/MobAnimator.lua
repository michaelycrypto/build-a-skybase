--[[
	MobAnimator.lua

	Client-side procedural animation driver for simple Minecraft-style mobs.
	Consumes motor joints produced by MobModel.Build and drives them based on movement state.
--]]

local MobAnimator = {}
MobAnimator.__index = MobAnimator

local function safeMotor(motors, name)
	local motor = motors[name]
	if not motor then
		for key, value in pairs(motors) do
			if string.lower(key) == string.lower(name) then
				return value
			end
		end
	end
	return motor
end

function MobAnimator.new(build)
	local self = setmetatable({
		build = build,
		motors = build.motors or {},
		definition = build.definition,
		velocity = Vector3.zero,
		state = "idle",
		lastCycle = 0,
        phaseOffset = math.random(),
        lastAttackAt = 0,
	}, MobAnimator)
	return self
end

function MobAnimator:SetState(state)
    local prev = self.state
    self.state = state or "idle"
    if self.state == "attack" and prev ~= "attack" then
        self.lastAttackAt = os.clock()
    end
end

function MobAnimator:SetVelocity(velocity)
	self.velocity = velocity or Vector3.zero
end

local function getHorizontalSpeed(vector)
	return Vector3.new(vector.X, 0, vector.Z).Magnitude
end

local function animateZombie(self, t)
	local motors = self.motors
	local speed = getHorizontalSpeed(self.velocity)

	local leftLeg = safeMotor(motors, "LeftLegMotor")
	local rightLeg = safeMotor(motors, "RightLegMotor")
	local leftArm = safeMotor(motors, "LeftArmMotor")
	local rightArm = safeMotor(motors, "RightArmMotor")

    -- Minecraft zombie arms forward (ModelZombie: rotateAngleX = -PI/2)
    local armBasePitch = math.rad(-90)

	-- Attack overlay: brief, more engaging eased swing with slight recoil
	local attackOverlay = 0
	local attackDuration = 0.35
	if self.lastAttackAt and (t - self.lastAttackAt) <= attackDuration then
		local p = math.clamp((t - self.lastAttackAt) / attackDuration, 0, 1)
		local function easeOutCubic(u)
			return 1 - (1 - u) ^ 3
		end
		local function easeOutBack(u)
			local c1 = 1.70158
			local c3 = c1 + 1
			local a = (u - 1)
			return 1 + c3 * a * a * a + c1 * a * a
		end
		local Adeg = 60 -- max downward degrees
		local downFrac = 0.45 -- portion of the window dedicated to the down swing
		if p <= downFrac then
			local d = p / downFrac
			local down = easeOutBack(d) -- 0->1(+overshoot)
			attackOverlay = -math.rad(Adeg) * down
		else
			local u = (p - downFrac) / (1 - downFrac)
			local up = easeOutCubic(u) -- 0->1
			-- Return toward forward with a slight damped recoil
			local base = -math.rad(Adeg) * (1 - up)
			local recoil = math.rad(8) * (1 - u) * math.sin(u * math.pi)
			attackOverlay = base + recoil
		end
	end

    if speed < 0.05 then
		if leftLeg then leftLeg.Transform = CFrame.new() end
		if rightLeg then rightLeg.Transform = CFrame.new() end
        if leftArm then leftArm.Transform = CFrame.Angles(armBasePitch + attackOverlay, 0, 0) end
        if rightArm then rightArm.Transform = CFrame.Angles(armBasePitch + attackOverlay, 0, 0) end
		return
	end

	-- Minecraft uses limbSwing (distance walked) instead of time-based cycle
	-- limbSwing increases continuously, frequency constant is 0.6662
	local limbSwing = (t + self.phaseOffset) * speed * 0.6662

	-- limbSwingAmount is movement speed multiplier (0-1)
	local limbSwingAmount = math.clamp(speed / 16, 0, 1)

	-- Minecraft formula: cos(limbSwing * 0.6662) * 1.4 * limbSwingAmount
	-- Legs swing with amplitude factor of 1.4
	local legSwingA = math.cos(limbSwing) * 1.4 * limbSwingAmount
	local legSwingB = math.cos(limbSwing + math.pi) * 1.4 * limbSwingAmount

	if leftLeg then
		leftLeg.Transform = CFrame.Angles(legSwingA, 0, 0)
	end
	if rightLeg then
		rightLeg.Transform = CFrame.Angles(legSwingB, 0, 0)
	end

	-- Arms: cos(limbSwing * 0.6662 + PI) * 2.0 * limbSwingAmount * 0.5
	-- Arms swing opposite to legs with amplitude factor of 1.0 (2.0 * 0.5)
	-- Reduced swing while attacking to emphasize the hit
	local armSwingFactor = (self.lastAttackAt and (t - self.lastAttackAt) <= attackDuration) and 0.15 or 1.0
	local armSwingA = math.cos(limbSwing) * 2.0 * limbSwingAmount * 0.5 * armSwingFactor
	local armSwingB = math.cos(limbSwing + math.pi) * 2.0 * limbSwingAmount * 0.5 * armSwingFactor

    if leftArm then
		-- Left arm swings opposite to left leg (uses limbSwing without offset)
        leftArm.Transform = CFrame.Angles(armBasePitch + armSwingA + attackOverlay, 0, 0)
    end
    if rightArm then
		-- Right arm swings opposite to right leg (uses limbSwing + PI offset)
        rightArm.Transform = CFrame.Angles(armBasePitch + armSwingB + attackOverlay, 0, 0)
    end
end

local function animateSheep(self, t)
	local motors = self.motors
	local speed = getHorizontalSpeed(self.velocity)

	local frontLeft = safeMotor(motors, "FrontLeftLegMotor") or safeMotor(motors, "LeftFrontLegMotor")
	local frontRight = safeMotor(motors, "FrontRightLegMotor") or safeMotor(motors, "RightFrontLegMotor")
	local backLeft = safeMotor(motors, "BackLeftLegMotor") or safeMotor(motors, "LeftBackLegMotor")
	local backRight = safeMotor(motors, "BackRightLegMotor") or safeMotor(motors, "RightBackLegMotor")
	local headMotor = safeMotor(motors, "HeadSkinMotor") or safeMotor(motors, "HeadWoolMotor")

	if speed < 0.05 then
		if frontLeft then frontLeft.Transform = CFrame.new() end
		if frontRight then frontRight.Transform = CFrame.new() end
		if backLeft then backLeft.Transform = CFrame.new() end
		if backRight then backRight.Transform = CFrame.new() end
		-- Head motion while stopped is handled by idle animation path
		return
	end

	local strideLength = 2.4
	local frequency = speed / strideLength
	local cycle = (t + self.phaseOffset) * frequency * math.pi * 2
	local amplitude = math.clamp(speed / 5, 0, 1) * 30

	local frontLeftPhase = math.sin(cycle)
	local frontRightPhase = math.sin(cycle + math.pi)
	local backLeftPhase = math.sin(cycle + math.pi)
	local backRightPhase = math.sin(cycle)

	if frontLeft then
		frontLeft.Transform = CFrame.Angles(math.rad(frontLeftPhase * amplitude), 0, 0)
	end
	if frontRight then
		frontRight.Transform = CFrame.Angles(math.rad(frontRightPhase * amplitude), 0, 0)
	end
	if backLeft then
		backLeft.Transform = CFrame.Angles(math.rad(backLeftPhase * amplitude), 0, 0)
	end
	if backRight then
		backRight.Transform = CFrame.Angles(math.rad(backRightPhase * amplitude), 0, 0)
	end

	if headMotor then
		local bob = math.sin(cycle * 2) * math.rad(amplitude * 0.06)
		headMotor.Transform = CFrame.Angles(bob, 0, 0)
	end
end

local function animateSheepIdle(self, t)
	local motors = self.motors
	-- Reset legs
	local frontLeft = safeMotor(motors, "FrontLeftLegMotor") or safeMotor(motors, "LeftFrontLegMotor")
	local frontRight = safeMotor(motors, "FrontRightLegMotor") or safeMotor(motors, "RightFrontLegMotor")
	local backLeft = safeMotor(motors, "BackLeftLegMotor") or safeMotor(motors, "LeftBackLegMotor")
	local backRight = safeMotor(motors, "BackRightLegMotor") or safeMotor(motors, "RightBackLegMotor")
	if frontLeft then frontLeft.Transform = CFrame.new() end
	if frontRight then frontRight.Transform = CFrame.new() end
	if backLeft then backLeft.Transform = CFrame.new() end
	if backRight then backRight.Transform = CFrame.new() end

	-- Subtle head look-around (Minecraft-style idle)
	local headMotor = safeMotor(motors, "HeadSkinMotor") or safeMotor(motors, "HeadWoolMotor")
	if headMotor then
		local yaw = math.sin(t * 0.8 + self.phaseOffset * 2.0) * math.rad(8)
		local pitch = math.sin(t * 0.6 + self.phaseOffset * 3.1) * math.rad(3)
		headMotor.Transform = CFrame.Angles(pitch, yaw, 0)
	end
end

local function animateSheepGraze(self, t)
    local motors = self.motors
    -- Reset leg swing
    local frontLeft = safeMotor(motors, "FrontLeftLegMotor") or safeMotor(motors, "LeftFrontLegMotor")
    local frontRight = safeMotor(motors, "FrontRightLegMotor") or safeMotor(motors, "RightFrontLegMotor")
    local backLeft = safeMotor(motors, "BackLeftLegMotor") or safeMotor(motors, "LeftBackLegMotor")
    local backRight = safeMotor(motors, "BackRightLegMotor") or safeMotor(motors, "RightBackLegMotor")
    if frontLeft then frontLeft.Transform = CFrame.new() end
    if frontRight then frontRight.Transform = CFrame.new() end
    if backLeft then backLeft.Transform = CFrame.new() end
    if backRight then backRight.Transform = CFrame.new() end

    -- Head down with subtle nibble motion
    local headMotor = safeMotor(motors, "HeadSkinMotor") or safeMotor(motors, "HeadWoolMotor")
    if headMotor then
        local baseDown = math.rad(25)
        local nibble = math.sin(t * 6) * math.rad(2)
        headMotor.Transform = CFrame.Angles(baseDown + nibble, 0, 0)
    end
end

local function animateCow(self, t)
	local motors = self.motors
	local speed = getHorizontalSpeed(self.velocity)

	-- Cow has 4 legs like sheep
	local frontLeft = safeMotor(motors, "FrontLeftLegMotor")
	local frontRight = safeMotor(motors, "FrontRightLegMotor")
	local backLeft = safeMotor(motors, "BackLeftLegMotor")
	local backRight = safeMotor(motors, "BackRightLegMotor")
	local headMotor = safeMotor(motors, "HeadMotor")

	if speed < 0.05 then
		-- Idle animation
		if frontLeft then frontLeft.Transform = CFrame.new() end
		if frontRight then frontRight.Transform = CFrame.new() end
		if backLeft then backLeft.Transform = CFrame.new() end
		if backRight then backRight.Transform = CFrame.new() end

		-- Subtle head movement when idle
		if headMotor then
			local yaw = math.sin(t * 0.7 + self.phaseOffset * 2.0) * math.rad(10)
			local pitch = math.sin(t * 0.5 + self.phaseOffset * 3.1) * math.rad(4)
			headMotor.Transform = CFrame.Angles(pitch, yaw, 0)
		end
		return
	end

	-- Walking animation (same as sheep but slightly slower/heavier feel)
	local strideLength = 2.6
	local frequency = speed / strideLength
	local cycle = (t + self.phaseOffset) * frequency * math.pi * 2
	local amplitude = math.clamp(speed / 5.5, 0, 1) * 28

	local frontLeftPhase = math.sin(cycle)
	local frontRightPhase = math.sin(cycle + math.pi)
	local backLeftPhase = math.sin(cycle + math.pi)
	local backRightPhase = math.sin(cycle)

	if frontLeft then
		frontLeft.Transform = CFrame.Angles(math.rad(frontLeftPhase * amplitude), 0, 0)
	end
	if frontRight then
		frontRight.Transform = CFrame.Angles(math.rad(frontRightPhase * amplitude), 0, 0)
	end
	if backLeft then
		backLeft.Transform = CFrame.Angles(math.rad(backLeftPhase * amplitude), 0, 0)
	end
	if backRight then
		backRight.Transform = CFrame.Angles(math.rad(backRightPhase * amplitude), 0, 0)
	end

	-- Subtle head bob when walking
	if headMotor then
		local bob = math.sin(cycle * 2) * math.rad(amplitude * 0.08)
		headMotor.Transform = CFrame.Angles(bob, 0, 0)
	end
end

local function animateCowIdle(self, t)
	local motors = self.motors
	-- Reset legs
	local frontLeft = safeMotor(motors, "FrontLeftLegMotor")
	local frontRight = safeMotor(motors, "FrontRightLegMotor")
	local backLeft = safeMotor(motors, "BackLeftLegMotor")
	local backRight = safeMotor(motors, "BackRightLegMotor")
	if frontLeft then frontLeft.Transform = CFrame.new() end
	if frontRight then frontRight.Transform = CFrame.new() end
	if backLeft then backLeft.Transform = CFrame.new() end
	if backRight then backRight.Transform = CFrame.new() end

	-- Subtle head look-around
	local headMotor = safeMotor(motors, "HeadMotor")
	if headMotor then
		local yaw = math.sin(t * 0.7 + self.phaseOffset * 2.0) * math.rad(10)
		local pitch = math.sin(t * 0.5 + self.phaseOffset * 3.1) * math.rad(4)
		headMotor.Transform = CFrame.Angles(pitch, yaw, 0)
	end
end

local function animateChicken(self, t)
	local motors = self.motors
	local speed = getHorizontalSpeed(self.velocity)

	local leftLeg = safeMotor(motors, "LeftLegMotor")
	local rightLeg = safeMotor(motors, "RightLegMotor")
	local leftWing = safeMotor(motors, "LeftWingMotor")
	local rightWing = safeMotor(motors, "RightWingMotor")
	local headMotor = safeMotor(motors, "HeadMotor")

	if speed < 0.05 then
		-- Idle animation
		if leftLeg then leftLeg.Transform = CFrame.new() end
		if rightLeg then rightLeg.Transform = CFrame.new() end

		-- Idle head bob (chickens constantly move their head)
		if headMotor then
			local bob = math.sin(t * 3.5 + self.phaseOffset * 2.0) * math.rad(5)
			local tilt = math.sin(t * 2.2 + self.phaseOffset * 3.1) * math.rad(8)
			headMotor.Transform = CFrame.Angles(bob, tilt, 0)
		end

		-- Wings slightly spread outward when idle
		if leftWing then
			leftWing.Transform = CFrame.Angles(0, 0, math.rad(-5))
		end
		if rightWing then
			rightWing.Transform = CFrame.Angles(0, 0, math.rad(5))
		end
		return
	end

	-- Walking animation (chicken has unique short-legged waddle)
	local strideLength = 1.8
	local frequency = speed / strideLength
	local cycle = (t + self.phaseOffset) * frequency * math.pi * 2
	local amplitude = math.clamp(speed / 4.5, 0, 1) * 35

	local sinA = math.sin(cycle)
	local sinB = math.sin(cycle + math.pi)

	if leftLeg then
		-- Chicken legs pivot at Z=1 (back of body), positive rotation swings forward
		leftLeg.Transform = CFrame.Angles(math.rad(sinA * amplitude), 0, 0)
	end
	if rightLeg then
		rightLeg.Transform = CFrame.Angles(math.rad(sinB * amplitude), 0, 0)
	end

	-- Wings flap when walking (rotate around Z axis to flap outward)
	local flapSpeed = 8
	local flapCycle = math.sin(t * flapSpeed + self.phaseOffset)
	local flapAngle = math.rad(15 + flapCycle * 20)

	if leftWing then
		-- Left wing: negative Z rotation flaps outward
		leftWing.Transform = CFrame.Angles(0, 0, -flapAngle)
	end
	if rightWing then
		-- Right wing: positive Z rotation flaps outward
		rightWing.Transform = CFrame.Angles(0, 0, flapAngle)
	end

	-- Head bob when walking (more pronounced than idle)
	if headMotor then
		local bob = math.sin(cycle * 2) * math.rad(amplitude * 0.15)
		local tilt = math.sin(cycle) * math.rad(3)
		headMotor.Transform = CFrame.Angles(bob, tilt, 0)
	end
end

local function animateChickenIdle(self, t)
	local motors = self.motors
	-- Reset legs
	local leftLeg = safeMotor(motors, "LeftLegMotor")
	local rightLeg = safeMotor(motors, "RightLegMotor")
	if leftLeg then leftLeg.Transform = CFrame.new() end
	if rightLeg then rightLeg.Transform = CFrame.new() end

	-- Constant head bobbing (chickens are always moving their head)
	local headMotor = safeMotor(motors, "HeadMotor")
	if headMotor then
		local bob = math.sin(t * 3.5 + self.phaseOffset * 2.0) * math.rad(5)
		local tilt = math.sin(t * 2.2 + self.phaseOffset * 3.1) * math.rad(8)
		headMotor.Transform = CFrame.Angles(bob, tilt, 0)
	end

	-- Wings slightly spread outward
	local leftWing = safeMotor(motors, "LeftWingMotor")
	local rightWing = safeMotor(motors, "RightWingMotor")
	if leftWing then
		leftWing.Transform = CFrame.Angles(0, 0, math.rad(-5))
	end
	if rightWing then
		rightWing.Transform = CFrame.Angles(0, 0, math.rad(5))
	end
end

function MobAnimator:Step(deltaTime)
	local now = os.clock()
	if not self.definition then
		return
	end

	if self.definition.id == "ZOMBIE" then
		animateZombie(self, now)
	elseif self.definition.id == "SHEEP" then
		if self.state == "graze" then
            animateSheepGraze(self, now)
		elseif self.state == "idle" then
			animateSheepIdle(self, now)
		else
            animateSheep(self, now)
        end
	elseif self.definition.id == "COW" then
		if self.state == "idle" then
			animateCowIdle(self, now)
		else
			animateCow(self, now)
		end
	elseif self.definition.id == "CHICKEN" then
		if self.state == "idle" then
			animateChickenIdle(self, now)
		else
			animateChicken(self, now)
		end
	else
		-- Reset transforms for unsupported mobs
		for _, motor in pairs(self.motors) do
			motor.Transform = CFrame.new()
		end
	end
end

return MobAnimator


