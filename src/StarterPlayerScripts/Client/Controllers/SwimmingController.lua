--[[
	SwimmingController.lua
	Handles swimming mechanics when player enters water blocks.

	Features:
	- Detects when player enters water
	- Modifies movement (reduced speed, gravity)
	- Vertical swimming (Space to ascend, Shift to descend)
	- Integrates with SprintController (disables sprint while swimming)
	- Visual effects (underwater tint, fog)

	Minecraft-style swimming:
	- Wading in shallow water (1 block) - slowed movement
	- Swimming in deep water (2+ blocks) - floaty, reduced gravity
	- Space = swim up, Shift = swim down
	- Water currents push the player
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import modules
local InputService = require(script.Parent.Parent.Input.InputService)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

-- Water detection will be required once we have the world manager
local WaterDetector = nil
local Constants = nil

local SwimmingController = {}

-- References
local player = Players.LocalPlayer
local character = nil
local humanoid = nil
local rootPart = nil

-- World manager reference (set from GameClient)
local worldManager = nil

-- Sprint controller reference (for notifying on water state change)
local sprintController = nil

-- Configuration (from GameConfig or defaults)
local config = {
	-- Movement speeds
	NormalWalkSpeed = 14,
	NormalJumpPower = 50,
	WadingSpeedMultiplier = 0.7,
	SwimmingSpeed = 8,
	AscendSpeed = 6,
	DescendSpeed = 8,

	-- Physics
	WaterGravityMultiplier = 0.3,
	WaterDrag = 0.85,
	SurfaceTension = 0.5,
	CurrentPushStrength = 3,

	-- Thresholds
	SwimDepthBlocks = 2,

	-- Visual effects
	UnderwaterFogColor = Color3.fromRGB(32, 84, 164),
	UnderwaterFogStart = 8,
	UnderwaterFogEnd = 48,
	UnderwaterTintColor = Color3.fromRGB(50, 100, 180),
	UnderwaterTintBrightness = -0.1,
}

-- State
local currentState = "Dry" -- "Dry", "Wading", "Swimming", "Submerged"
local previousState = "Dry"
local isSwimming = false
local isHeadUnderwater = false
local isAscending = false
local isDescending = false
local isInFallingWater = false -- Track if player is in a waterfall

-- Input state
local spaceHeld = false
local shiftHeld = false
local ctrlHeld = false

-- Visual effects
local underwaterColorCorrection = nil
local originalFogColor = nil
local originalFogStart = nil
local originalFogEnd = nil
local fogTransitionTween = nil

-- BodyMovers for swimming physics
local bodyVelocity = nil
local bodyGyro = nil

-- Update loop connection
local updateConnection = nil
local inputBeganConnection = nil
local inputEndedConnection = nil

--============================================================================
-- HELPER FUNCTIONS
--============================================================================

local function getSwimmingConfig()
	-- Try to get config from GameConfig.Swimming, fall back to defaults
	if GameConfig and GameConfig.Swimming then
		for key, value in pairs(GameConfig.Swimming) do
			if config[key] ~= nil then
				config[key] = value
			end
		end
	end
	return config
end

local function setState(newState)
	if currentState == newState then return end

	previousState = currentState
	currentState = newState

	-- Notify other systems of state change
	if currentState == "Dry" then
		SwimmingController:OnExitWater()
	elseif previousState == "Dry" then
		SwimmingController:OnEnterWater()
	end

	-- Update swimming flag
	isSwimming = (currentState == "Swimming" or currentState == "Submerged")
end

--============================================================================
-- MOVEMENT MODIFICATION
--============================================================================

local function applyWadingMovement()
	if not humanoid then return end

	local cfg = getSwimmingConfig()
	humanoid.WalkSpeed = cfg.NormalWalkSpeed * cfg.WadingSpeedMultiplier
	humanoid.JumpPower = cfg.NormalJumpPower * 0.8
end

local function applySwimmingMovement()
	if not humanoid then return end

	local cfg = getSwimmingConfig()

	-- Boost swimming speed when holding Space or Shift (swim sprint)
	if spaceHeld or shiftHeld then
		humanoid.WalkSpeed = cfg.SwimSprintSpeed or 14
	else
		humanoid.WalkSpeed = cfg.SwimmingSpeed
	end

	humanoid.JumpPower = 0 -- Disable jump while swimming (use Space for ascend)
end

local function applyNormalMovement()
	if not humanoid then return end

	local cfg = getSwimmingConfig()
	humanoid.WalkSpeed = cfg.NormalWalkSpeed
	humanoid.JumpPower = cfg.NormalJumpPower
end

local function createBodyMovers()
	if not rootPart then return end

	-- Clean up existing
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end

	-- Create BodyVelocity for vertical swimming
	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "SwimmingVelocity"
	bodyVelocity.MaxForce = Vector3.new(0, 0, 0) -- Start disabled
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.P = 5000
	bodyVelocity.Parent = rootPart
end

local function destroyBodyMovers()
	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end
	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end
end

local function updateSwimmingPhysics(dt)
	if not isSwimming or not rootPart or not bodyVelocity then return end

	local cfg = getSwimmingConfig()
	local verticalVelocity = 0
	local horizontalVelocityX = 0
	local horizontalVelocityZ = 0

	-- Check if in falling water (waterfall)
	local inFallingWater = false
	if WaterDetector and worldManager then
		inFallingWater = WaterDetector.IsInFallingWater(worldManager, rootPart.Position)
	end
	isInFallingWater = inFallingWater

	-- Vertical swimming input
	if isAscending then
		-- Ascending in falling water is harder (fighting the current)
		if inFallingWater then
			verticalVelocity = cfg.AscendSpeed * 0.5 -- 50% speed fighting waterfall
		else
			verticalVelocity = cfg.AscendSpeed
		end
	elseif isDescending then
		-- Descending in falling water is much faster
		if inFallingWater then
			verticalVelocity = -(cfg.FallingWaterDescentSpeed or 16)
		else
			verticalVelocity = -cfg.DescendSpeed
		end
	else
		-- Not pressing up/down
		if inFallingWater then
			-- Falling water pulls you down fast
			verticalVelocity = -(cfg.FallingWaterPullStrength or 12)
		else
			-- Apply water gravity (slow sink)
			verticalVelocity = -2 * cfg.WaterGravityMultiplier
		end
	end

	-- Apply vertical force
	bodyVelocity.MaxForce = Vector3.new(0, 10000, 0)
	bodyVelocity.Velocity = Vector3.new(0, verticalVelocity, 0)

	-- Apply water current push (horizontal flow)
	if WaterDetector and worldManager then
		local flowDir = WaterDetector.GetFlowDirection(worldManager, rootPart.Position)
		if flowDir then
			-- Add horizontal push from current
			local currentVel = flowDir * cfg.CurrentPushStrength
			horizontalVelocityX = currentVel.X
			horizontalVelocityZ = currentVel.Z
		end
	end

	-- Apply combined forces if there's horizontal movement from currents
	if horizontalVelocityX ~= 0 or horizontalVelocityZ ~= 0 then
		bodyVelocity.MaxForce = Vector3.new(5000, 10000, 5000)
		bodyVelocity.Velocity = Vector3.new(horizontalVelocityX, verticalVelocity, horizontalVelocityZ)
	end

	-- Surface tension - resist breaking the surface (not in falling water)
	if not inFallingWater and not isHeadUnderwater and WaterDetector and worldManager then
		local surfaceY = WaterDetector.GetWaterSurfaceY(worldManager, rootPart.Position)
		if surfaceY then
			local headY = rootPart.Position.Y + 1.5
			local distToSurface = surfaceY - headY

			-- Near surface, add resistance when trying to go up
			if distToSurface > -1 and distToSurface < 1 and isAscending then
				-- Reduce upward velocity near surface
				local surfaceResistance = 1 - math.abs(distToSurface)
				bodyVelocity.Velocity = bodyVelocity.Velocity * (1 - surfaceResistance * cfg.SurfaceTension)
			end
		end
	end

	-- Update horizontal swim speed based on input state
	applySwimmingMovement()
end

--============================================================================
-- VISUAL EFFECTS
--============================================================================

local function createUnderwaterEffects()
	-- Color correction for underwater tint
	if not underwaterColorCorrection then
		underwaterColorCorrection = Instance.new("ColorCorrectionEffect")
		underwaterColorCorrection.Name = "SwimmingUnderwaterTint"
		underwaterColorCorrection.Enabled = false
		underwaterColorCorrection.Parent = Lighting
	end
end

local function applyUnderwaterVisuals()
	local cfg = getSwimmingConfig()

	-- Store original fog settings
	if not originalFogColor then
		originalFogColor = Lighting.FogColor
		originalFogStart = Lighting.FogStart
		originalFogEnd = Lighting.FogEnd
	end

	-- Apply underwater fog
	Lighting.FogColor = cfg.UnderwaterFogColor
	Lighting.FogStart = cfg.UnderwaterFogStart
	Lighting.FogEnd = cfg.UnderwaterFogEnd

	-- Apply color tint
	if underwaterColorCorrection then
		underwaterColorCorrection.TintColor = cfg.UnderwaterTintColor
		underwaterColorCorrection.Brightness = cfg.UnderwaterTintBrightness
		underwaterColorCorrection.Saturation = -0.2
		underwaterColorCorrection.Contrast = -0.1
		underwaterColorCorrection.Enabled = true
	end
end

local function removeUnderwaterVisuals()
	-- Restore original fog settings
	if originalFogColor then
		Lighting.FogColor = originalFogColor
		Lighting.FogStart = originalFogStart
		Lighting.FogEnd = originalFogEnd
		originalFogColor = nil
		originalFogStart = nil
		originalFogEnd = nil
	end

	-- Disable color tint
	if underwaterColorCorrection then
		underwaterColorCorrection.Enabled = false
	end
end

--============================================================================
-- INPUT HANDLING
--============================================================================

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		spaceHeld = true
		if isSwimming then
			isAscending = true
			-- Update swim speed immediately
			applySwimmingMovement()
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		shiftHeld = true
		if isSwimming then
			isDescending = true
			-- Update swim speed immediately
			applySwimmingMovement()
		end
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		ctrlHeld = true
		-- Ctrl for slow descent (like Minecraft sneak)
		if isSwimming then
			isDescending = true
		end
	end
end

local function onInputEnded(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space then
		spaceHeld = false
		isAscending = false
		-- Update swim speed immediately
		if isSwimming then
			applySwimmingMovement()
		end
	elseif input.KeyCode == Enum.KeyCode.LeftShift then
		shiftHeld = false
		-- Only stop descending if Ctrl isn't held
		if not ctrlHeld then
			isDescending = false
		end
		-- Update swim speed immediately
		if isSwimming then
			applySwimmingMovement()
		end
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		ctrlHeld = false
		-- Only stop descending if Shift isn't held
		if not shiftHeld then
			isDescending = false
		end
	end
end

--============================================================================
-- UPDATE LOOP
--============================================================================

local function update(dt)
	if not character or not humanoid or not rootPart then return end
	if not worldManager then return end
	if not WaterDetector then return end

	-- Get swimming state from detector
	local swimState = WaterDetector.GetSwimmingState(worldManager, rootPart.Position)

	-- Update head underwater state (for visuals)
	local wasHeadUnderwater = isHeadUnderwater
	isHeadUnderwater = swimState.headUnderwater

	-- Track previous state to detect transitions
	local wasInWater = (currentState ~= "Dry")

	-- Update movement state based on water state
	if swimState.state == WaterDetector.SwimState.DRY then
		setState("Dry")

		-- Only apply normal movement when TRANSITIONING from water to dry
		-- AND only if the player isn't sprinting (sprint controller manages sprint speed)
		-- This prevents overwriting sprint speed every frame
		if wasInWater then
			-- Check if sprint controller has resumed sprinting (key was held)
			local isSprinting = sprintController and sprintController.IsSprinting and sprintController:IsSprinting()
			if not isSprinting then
				applyNormalMovement()
			end
		end

		-- Disable swimming physics
		if bodyVelocity then
			bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
		end

	elseif swimState.state == WaterDetector.SwimState.WADING then
		setState("Wading")
		applyWadingMovement()

		-- Disable swimming physics in shallow water
		if bodyVelocity then
			bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
		end

	elseif swimState.state == WaterDetector.SwimState.SWIMMING then
		setState("Swimming")
		applySwimmingMovement()
		updateSwimmingPhysics(dt)

	elseif swimState.state == WaterDetector.SwimState.SUBMERGED then
		setState("Submerged")
		applySwimmingMovement()
		updateSwimmingPhysics(dt)
	end

	-- Update visual effects for head underwater
	if isHeadUnderwater and not wasHeadUnderwater then
		applyUnderwaterVisuals()
	elseif not isHeadUnderwater and wasHeadUnderwater then
		removeUnderwaterVisuals()
	end
end

--============================================================================
-- PUBLIC API
--============================================================================

--[[
	Called when player enters water (from dry state).
]]
function SwimmingController:OnEnterWater()
	createBodyMovers()

	-- Notify sprint controller
	if sprintController and sprintController.OnWaterStateChanged then
		sprintController:OnWaterStateChanged(true)
	end

	-- Could play splash sound here
end

--[[
	Called when player exits water completely.
]]
function SwimmingController:OnExitWater()
	destroyBodyMovers()
	removeUnderwaterVisuals()
	isAscending = false
	isDescending = false
	isInFallingWater = false

	-- Notify sprint controller (can resume sprinting)
	if sprintController and sprintController.OnWaterStateChanged then
		sprintController:OnWaterStateChanged(false)
	end

	-- Could play drip/exit sound here
end

--[[
	Check if player is currently swimming.
	Used by SprintController to disable sprint.
]]
function SwimmingController:IsSwimming()
	return isSwimming
end

--[[
	Check if player is in falling water (waterfall).
	Falling water has faster descent.
]]
function SwimmingController:IsInFallingWater()
	return isInFallingWater
end

--[[
	Check if player is in water at all (wading or swimming).
]]
function SwimmingController:IsInWater()
	return currentState ~= "Dry"
end

--[[
	Check if player's head is underwater.
	Used for oxygen/drowning mechanics.
]]
function SwimmingController:IsHeadUnderwater()
	return isHeadUnderwater
end

--[[
	Get current swimming state.
	Returns: "Dry", "Wading", "Swimming", or "Submerged"
]]
function SwimmingController:GetState()
	return currentState
end

--[[
	Set the world manager reference.
	Called from GameClient after voxel world is initialized.
]]
function SwimmingController:SetWorldManager(wm)
	worldManager = wm
end

--[[
	Set the sprint controller reference.
	Used to notify sprint controller when water state changes.
]]
function SwimmingController:SetSprintController(controller)
	sprintController = controller
end

--[[
	Setup character references when character loads.
]]
local function setupCharacter(char)
	character = char
	humanoid = char:WaitForChild("Humanoid")
	rootPart = char:WaitForChild("HumanoidRootPart")

	-- Reset state
	currentState = "Dry"
	previousState = "Dry"
	isSwimming = false
	isHeadUnderwater = false
	isAscending = false
	isDescending = false
	isInFallingWater = false

	-- Reset input tracking
	spaceHeld = false
	shiftHeld = false
	ctrlHeld = false

	-- Apply normal movement
	applyNormalMovement()

	-- Clean up body movers
	destroyBodyMovers()
end

--[[
	Initialize the swimming controller.
]]
function SwimmingController:Initialize()
	-- Load modules
	local success, err = pcall(function()
		WaterDetector = require(ReplicatedStorage.Shared.VoxelWorld.World.WaterDetector)
		Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
	end)

	if not success then
		warn("[SwimmingController] Failed to load water detection modules:", err)
		return
	end

	-- Load config
	getSwimmingConfig()

	-- Create visual effects
	createUnderwaterEffects()

	-- Setup character
	character = player.Character or player.CharacterAdded:Wait()
	setupCharacter(character)

	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		setupCharacter(newCharacter)
	end)

	-- Connect input
	inputBeganConnection = InputService.InputBegan:Connect(onInputBegan)
	inputEndedConnection = InputService.InputEnded:Connect(onInputEnded)

	-- Connect update loop
	updateConnection = RunService.Heartbeat:Connect(update)

	print("[SwimmingController] Initialized")
end

--[[
	Cleanup the swimming controller.
]]
function SwimmingController:Cleanup()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end

	if inputBeganConnection then
		inputBeganConnection:Disconnect()
		inputBeganConnection = nil
	end

	if inputEndedConnection then
		inputEndedConnection:Disconnect()
		inputEndedConnection = nil
	end

	destroyBodyMovers()
	removeUnderwaterVisuals()

	if underwaterColorCorrection then
		underwaterColorCorrection:Destroy()
		underwaterColorCorrection = nil
	end
end

return SwimmingController
