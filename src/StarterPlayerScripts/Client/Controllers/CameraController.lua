--[[
	CameraController.lua
	Manages camera settings and mouse lock behavior
	- Uses Roblox's native camera system
	- Starts in First Person mode by default
	- Forced mouse lock (unlocks for UI)
	- V key to toggle First/Third person
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

-- Feature flags
local MOUSE_LOCK_ENABLED = GameConfig.IsFeatureEnabled and GameConfig.IsFeatureEnabled("MouseLock")

local CameraController = {}

-- References
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil

-- Settings
local CAMERA_HEIGHT_OFFSET = 1 -- Studs above normal camera height
local THIRD_PERSON_DISTANCE = 9 -- Default zoom distance for third person
local THIRD_PERSON_MAX_ZOOM = 9 -- Maximum zoom out distance
local THIRD_PERSON_MIN_ZOOM = 9 -- Minimum zoom in distance (can zoom to first person)
local FIRST_PERSON_DISTANCE = 0.5 -- Roblox's default first-person distance
local FIRST_PERSON_FOV = 85 -- Minecraft-style wide FOV
local THIRD_PERSON_FOV = 85 -- Standard Roblox FOV
local MOUSE_SENSITIVITY = 0.6 -- Lower = less sensitive (0.6 = 60% of normal speed)

-- Camera bobbing settings (Minecraft-style)
local WALK_BOB_FREQUENCY = 1.5 -- How fast the camera bobs (cycles per second) - matches Minecraft pace
local WALK_BOB_AMPLITUDE = 0.15 -- How much the camera moves up/down (studs)
local SPRINT_BOB_FREQUENCY = 3 -- Faster bobbing when sprinting
local SPRINT_BOB_AMPLITUDE = 0.15 -- More pronounced bobbing when sprinting
local BOB_HORIZONTAL_SCALE = 1.2 -- Side-to-side bobbing (slightly more than vertical for Minecraft feel)
local NORMAL_WALKSPEED = 14 -- Must match SprintController

-- State
local isFirstPerson = true -- Players always start in first person
local bobbingTime = 0

-- Dynamic FOV + Hurt Roll tunables
local BASE_FOV = 80
local MAX_FOV = 96
local FOV_LERP = 0.25
local WALKSPEED_BASE = NORMAL_WALKSPEED -- 14
local FOV_PER_SPEED = 1.8 -- degrees per stud/sec beyond base

local HURT_ROLL_MAX_DEG = 2.0
local HURT_ROLL_DECAY = 7.0 -- per second
local HURT_ROLL_IMPULSE = 1.0 -- multiplied by damage fraction

-- Hurt roll state
local hurtRollAngle = 0
local hurtRollVel = 0
local lastHealth = nil

local function setupCamera(char)
	-- Wait for character to be fully loaded
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	task.wait(0.1) -- Small delay to ensure everything is ready

	-- Configure camera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = hum

	-- Set camera mode and settings based on feature flag
	if MOUSE_LOCK_ENABLED then
		-- Custom first/third person behavior
		if isFirstPerson then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
			player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
			hum.CameraOffset = Vector3.new(0, 0, 0)
			-- Initialize FOV toward base to avoid abrupt jumps
			camera.FieldOfView = BASE_FOV
		else
			-- Third person: Fixed zoom at 16 studs (no zooming)
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
			player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
			hum.CameraOffset = Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
			camera.FieldOfView = THIRD_PERSON_FOV
		end
	else
		-- Native Roblox camera behavior (do not lock first person or force zoom/FOV)
		player.CameraMode = Enum.CameraMode.Classic
		hum.CameraOffset = Vector3.new(0, 0, 0)
	end

	print("📷 Camera setup: Mode =", player.CameraMode, "Offset =", hum.CameraOffset, "Distance =", player.CameraMaxZoomDistance)

	return hum
end

function CameraController:Initialize()
	-- Setup character
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = setupCamera(character)

	-- Hook health change for hurt roll
	if humanoid then
		lastHealth = humanoid.Health
		humanoid.HealthChanged:Connect(function(newHealth)
			if lastHealth then
				local delta = lastHealth - newHealth
				if delta > 0 then
					local maxH = math.max(1, humanoid.MaxHealth or 100)
					-- Apply an impulse proportional to damage fraction
					hurtRollVel = hurtRollVel + (delta / maxH) * HURT_ROLL_IMPULSE
				end
			end
			lastHealth = newHealth
		end)
	end

	-- Initialize camera mode state
	GameState:Set("camera.isFirstPerson", isFirstPerson)

	-- Set initial mouse settings based on camera mode
	if MOUSE_LOCK_ENABLED then
		if isFirstPerson then
			UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		else
			-- Third person: Free mouse and visible cursor
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	else
		-- Ensure free cursor/camera initially
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		isFirstPerson = true -- Keep first person on respawn
		bobbingTime = 0
		humanoid = setupCamera(newCharacter)
		GameState:Set("camera.isFirstPerson", isFirstPerson)
	end)

	-- Continuously enforce camera settings every frame (only when enabled)
	if MOUSE_LOCK_ENABLED then
		RunService.RenderStepped:Connect(function(deltaTime)
			if not character or not humanoid then return end

			-- FIRST PERSON MODE: Enforce all camera settings
			if isFirstPerson then
				-- Enforce first person camera mode
				if player.CameraMode ~= Enum.CameraMode.LockFirstPerson then
					player.CameraMode = Enum.CameraMode.LockFirstPerson
				end

				-- Enforce first person zoom lock (prevents scroll)
				if player.CameraMaxZoomDistance ~= FIRST_PERSON_DISTANCE then
					player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
					player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
				end

				-- Camera bobbing when moving
				local baseOffset = Vector3.new(0, 0, 0)
				local moveDirection = humanoid.MoveDirection
				local isMoving = moveDirection.Magnitude > 0.1

				if isMoving then
					-- Detect if sprinting (check walkspeed)
					local isSprinting = humanoid.WalkSpeed > NORMAL_WALKSPEED

					-- Use different bobbing parameters based on sprint state
					local frequency = isSprinting and SPRINT_BOB_FREQUENCY or WALK_BOB_FREQUENCY
					local amplitude = isSprinting and SPRINT_BOB_AMPLITUDE or WALK_BOB_AMPLITUDE

					-- Update bobbing time
					bobbingTime = bobbingTime + deltaTime * frequency

					-- Minecraft-style bobbing:
					local verticalBob = (math.sin(bobbingTime * math.pi * 2) ^ 2) * amplitude
					local horizontalBob = math.sin(bobbingTime * math.pi * 2) * amplitude * BOB_HORIZONTAL_SCALE

					-- Apply bobbing to camera offset
					baseOffset = Vector3.new(horizontalBob, verticalBob, 0)
				else
					-- Smoothly decay bobbing time when not moving
					if bobbingTime > 0 then
						bobbingTime = math.max(0, bobbingTime - deltaTime * 2)
					end
				end

				-- Apply bobbing and settings
				humanoid.CameraOffset = baseOffset

				-- Dynamic FOV tied to WalkSpeed (clamped)
				local ws = humanoid.WalkSpeed or NORMAL_WALKSPEED
				local targetFov = BASE_FOV + math.max(0, ws - WALKSPEED_BASE) * FOV_PER_SPEED
				targetFov = math.clamp(targetFov, BASE_FOV, MAX_FOV)
				camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * FOV_LERP

				-- Enforce mouse sensitivity
				if UserInputService.MouseDeltaSensitivity ~= MOUSE_SENSITIVITY then
					UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
				end
				-- Head roll on hurt (decays over time)
				hurtRollVel = hurtRollVel - (hurtRollVel * HURT_ROLL_DECAY * deltaTime)
				hurtRollAngle = math.clamp(hurtRollAngle + (hurtRollVel * deltaTime * 60), -HURT_ROLL_MAX_DEG, HURT_ROLL_MAX_DEG)
				camera.CFrame = camera.CFrame * CFrame.Angles(0, 0, math.rad(hurtRollAngle))
			end
			-- THIRD PERSON MODE: No camera updates (let Roblox handle everything)
			-- We don't touch any camera properties to avoid interfering

			-- Mouse lock handling ONLY for first person mode
			-- Third person: Don't touch mouse at all (let Roblox camera have full control)
			if isFirstPerson then
				local inventoryOpen = GameState:Get("voxelWorld.inventoryOpen")

				if not inventoryOpen then
					-- Lock mouse during first person gameplay
					if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
						UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
					end
					if UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = false
					end
				else
					-- Free mouse for UI in first person
					if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
						UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					end
					if not UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = true
					end
				end
			end
			-- Third person: ZERO mouse behavior changes (Roblox handles it completely)
		end)
	else
		-- When disabled, ensure defaults every frame are not overridden elsewhere
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	-- V key: Toggle First/Third person (only when enabled)
	if MOUSE_LOCK_ENABLED then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.V then
				isFirstPerson = not isFirstPerson
				bobbingTime = 0 -- Reset bobbing when toggling camera

				-- Update GameState so other modules can react
				GameState:Set("camera.isFirstPerson", isFirstPerson)

			if isFirstPerson then
				-- First person: Zoom to 0.5 studs (Roblox standard), no offset, wide FOV
				player.CameraMode = Enum.CameraMode.LockFirstPerson
				player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
				player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
				humanoid.CameraOffset = Vector3.new(0, 0, 0)
				camera.FieldOfView = FIRST_PERSON_FOV
				UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
				print("📷 First Person Mode - FOV:", FIRST_PERSON_FOV)
			else
				-- Third person: Fixed zoom at 16 studs (no zooming)
				player.CameraMode = Enum.CameraMode.Classic
				player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
				player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
				humanoid.CameraOffset = Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
				camera.FieldOfView = THIRD_PERSON_FOV
				-- Free mouse and make cursor visible
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
				print("📷 Third Person Mode - FOV:", THIRD_PERSON_FOV, "Fixed Zoom:", THIRD_PERSON_DISTANCE)
			end
			end
		end)
	end

	if MOUSE_LOCK_ENABLED then
		print("✅ CameraController: Initialized (First Person enabled, Press V to toggle)")
	else
		print("✅ CameraController: Initialized (MouseLock disabled - native Roblox camera)")
	end
end

return CameraController

