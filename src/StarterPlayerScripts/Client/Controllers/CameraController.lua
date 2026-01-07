--[[
	CameraController.lua
	Manages camera settings and mouse lock behavior
	- Uses Roblox's native camera system
	- Starts in First Person mode by default
	- F5 key cycles through 3 modes (like Minecraft):
	  1. First Person: Mouse locked, camera bobbing, dynamic FOV
	  2. Third Person Lock: Fixed zoom, mouse locked, character faces camera direction
	  3. Third Person Free: Fixed zoom, character rotates towards mouse, free camera pan
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)

-- Feature flags
local MOUSE_LOCK_ENABLED = GameConfig.IsFeatureEnabled and GameConfig.IsFeatureEnabled("MouseLock")

local CameraController = {}

-- References
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil

-- Settings
local FIRST_PERSON_DISTANCE = 0.5 -- Roblox's default first-person distance
local FIRST_PERSON_FOV = 85 -- Minecraft-style wide FOV
local THIRD_PERSON_FOV = 70 -- Standard Roblox FOV
local MOUSE_SENSITIVITY = 0.6 -- Lower = less sensitive (0.6 = 60% of normal speed)

-- Third person: Fixed zoom distance (no scrolling)
local THIRD_PERSON_DISTANCE = 12 -- Fixed zoom distance
local CAMERA_HEIGHT_OFFSET = 1 -- Studs above normal camera height
local THIRD_PERSON_LOCK_HORIZONTAL_OFFSET = 1.5 -- Studs to the right (character appears on left)

-- Third person character rotation settings
local THIRD_PERSON_ROTATION_SPEED = 12 -- How fast character rotates towards mouse
local THIRD_PERSON_MIN_DISTANCE = 5 -- Minimum distance for mouse target to affect rotation

-- Camera bobbing settings (Minecraft-style)
local WALK_BOB_FREQUENCY = 1.5 -- How fast the camera bobs (cycles per second) - matches Minecraft pace
local WALK_BOB_AMPLITUDE = 0.15 -- How much the camera moves up/down (studs)
local SPRINT_BOB_FREQUENCY = 3 -- Faster bobbing when sprinting
local SPRINT_BOB_AMPLITUDE = 0.15 -- More pronounced bobbing when sprinting
local BOB_HORIZONTAL_SCALE = 1.2 -- Side-to-side bobbing (slightly more than vertical for Minecraft feel)
local NORMAL_WALKSPEED = 14 -- Must match SprintController

-- Camera modes
local CAMERA_MODE = {
	FIRST_PERSON = 1,
	THIRD_PERSON_FREE = 2,
	THIRD_PERSON_LOCK = 3,
}

-- State
local currentCameraMode = CAMERA_MODE.FIRST_PERSON -- Players always start in first person
local bobbingTime = 0

-- Helper to check if in first person
local function isFirstPerson()
	return currentCameraMode == CAMERA_MODE.FIRST_PERSON
end

-- Helper to check if in any third person mode
local function isThirdPerson()
	return currentCameraMode == CAMERA_MODE.THIRD_PERSON_FREE or currentCameraMode == CAMERA_MODE.THIRD_PERSON_LOCK
end

-- Helper to check if mouse should be locked
local function shouldLockMouse()
	return currentCameraMode == CAMERA_MODE.FIRST_PERSON or currentCameraMode == CAMERA_MODE.THIRD_PERSON_LOCK
end

-- Dynamic FOV tunables
local BASE_FOV = 80
local MAX_FOV = 96
local FOV_LERP = 0.25
local WALKSPEED_BASE = NORMAL_WALKSPEED -- 14
local FOV_PER_SPEED = 1.8 -- degrees per stud/sec beyond base


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
		-- Custom camera behavior based on mode
		if isFirstPerson() then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
			player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
			hum.CameraOffset = Vector3.new(0, 0, 0)
			camera.FieldOfView = BASE_FOV
		else
			-- Third person (both free and lock): Fixed zoom distance
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



	-- Initialize camera mode state
	GameState:Set("camera.isFirstPerson", isFirstPerson())
	GameState:Set("camera.mode", currentCameraMode)

	-- Set initial mouse settings based on camera mode
	if MOUSE_LOCK_ENABLED then
		if shouldLockMouse() then
			UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		else
			-- Third person free: Free mouse and visible cursor
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
		currentCameraMode = CAMERA_MODE.FIRST_PERSON -- Reset to first person on respawn
		bobbingTime = 0
		humanoid = setupCamera(newCharacter)
		GameState:Set("camera.isFirstPerson", isFirstPerson())
		GameState:Set("camera.mode", currentCameraMode)
	end)

	-- Continuously enforce camera settings every frame (only when enabled)
	if MOUSE_LOCK_ENABLED then
		RunService.RenderStepped:Connect(function(deltaTime)
			if not character or not humanoid then return end

			-- FIRST PERSON MODE: Enforce all camera settings
			if isFirstPerson() then
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
				-- But override with bow zoom when fully charged (Minecraft-style)
				local bowPullStage = GameState:Get("voxelWorld.bowPullStage")
				local isBowFullyCharged = bowPullStage == 2

				local targetFov
				local lerpSpeed
				if isBowFullyCharged then
					-- Minecraft-style: fast zoom when bow is fully charged
					targetFov = BowConfig.ZOOM_FOV
					lerpSpeed = BowConfig.ZOOM_IN_SPEED or 20
				else
					-- Normal FOV based on WalkSpeed
					local ws = humanoid.WalkSpeed or NORMAL_WALKSPEED
					targetFov = BASE_FOV + math.max(0, ws - WALKSPEED_BASE) * FOV_PER_SPEED
					targetFov = math.clamp(targetFov, BASE_FOV, MAX_FOV)
					-- Use fast zoom out speed if coming from bow zoom, else normal lerp
					if camera.FieldOfView < BASE_FOV - 5 then
						lerpSpeed = BowConfig.ZOOM_OUT_SPEED or 15
					else
						lerpSpeed = FOV_LERP / deltaTime -- Convert to same scale
					end
				end
				camera.FieldOfView = camera.FieldOfView + (targetFov - camera.FieldOfView) * math.min(1, deltaTime * lerpSpeed)

				-- Enforce mouse sensitivity
				if UserInputService.MouseDeltaSensitivity ~= MOUSE_SENSITIVITY then
					UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
				end

			elseif isThirdPerson() then
				-- THIRD PERSON MODES: Fixed zoom, different mouse/rotation behavior

				-- Enforce fixed zoom distance (no scroll)
				if player.CameraMaxZoomDistance ~= THIRD_PERSON_DISTANCE then
					player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
					player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
				end

				local inventoryOpen = GameState:Get("voxelWorld.inventoryOpen")

				if currentCameraMode == CAMERA_MODE.THIRD_PERSON_FREE then
					-- THIRD PERSON FREE: Rotate character towards mouse cursor
					if not inventoryOpen then
						local rootPart = character:FindFirstChild("HumanoidRootPart")
						if rootPart then
							-- Get mouse position and create ray into world
							local mousePos = UserInputService:GetMouseLocation()
							local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)

							-- Raycast to find where mouse is pointing in world
							local raycastParams = RaycastParams.new()
							raycastParams.FilterType = Enum.RaycastFilterType.Exclude
							raycastParams.FilterDescendantsInstances = {character}

							local rayResult = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
							local targetPos = rayResult and rayResult.Position or (ray.Origin + ray.Direction * 100)

							-- Calculate horizontal direction from character to target
							local charPos = rootPart.Position
							local lookDir = Vector3.new(targetPos.X - charPos.X, 0, targetPos.Z - charPos.Z)

							-- Only rotate if target is far enough away (avoid jittering when mouse is near character)
							if lookDir.Magnitude > THIRD_PERSON_MIN_DISTANCE then
								lookDir = lookDir.Unit

								-- Create target CFrame facing the mouse direction
								local targetCFrame = CFrame.new(charPos, charPos + lookDir)

								-- Smoothly rotate towards target
								local alpha = math.min(1, deltaTime * THIRD_PERSON_ROTATION_SPEED)
								rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, alpha)
							end
						end
					end

				elseif currentCameraMode == CAMERA_MODE.THIRD_PERSON_LOCK then
					-- THIRD PERSON LOCK: Character faces camera direction (like first person but zoomed out)
					if not inventoryOpen then
						local rootPart = character:FindFirstChild("HumanoidRootPart")
						if rootPart then
							-- Get camera's forward direction (horizontal only)
							local camLookVector = camera.CFrame.LookVector
							local lookDir = Vector3.new(camLookVector.X, 0, camLookVector.Z)

							if lookDir.Magnitude > 0.1 then
								lookDir = lookDir.Unit
								local charPos = rootPart.Position
								local targetCFrame = CFrame.new(charPos, charPos + lookDir)

								-- Smoothly rotate towards camera direction
								local alpha = math.min(1, deltaTime * THIRD_PERSON_ROTATION_SPEED)
								rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, alpha)
							end
						end
					end

					-- Enforce mouse sensitivity for locked mode
					if UserInputService.MouseDeltaSensitivity ~= MOUSE_SENSITIVITY then
						UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
					end
				end
			end

			-- Mouse behavior based on camera mode
			local inventoryOpen = GameState:Get("voxelWorld.inventoryOpen")

			if shouldLockMouse() then
				-- First person and Third person lock: enforce mouse lock
				if not inventoryOpen then
					if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
						UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
					end
					if UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = false
					end
				else
					-- Free mouse for UI
					if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
						UserInputService.MouseBehavior = Enum.MouseBehavior.Default
					end
					if not UserInputService.MouseIconEnabled then
						UserInputService.MouseIconEnabled = true
					end
				end
			end
			-- Third person free: Don't enforce mouse - let Roblox native camera handle it
		end)
	else
		-- When disabled, ensure defaults every frame are not overridden elsewhere
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end

	-- Helper function to apply camera mode settings
	local function applyCameraMode(mode)
		if not humanoid then return end

		bobbingTime = 0 -- Reset bobbing when toggling camera

		if mode == CAMERA_MODE.FIRST_PERSON then
			-- First person: Lock camera, custom settings
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
			player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
			humanoid.CameraOffset = Vector3.new(0, 0, 0)
			camera.FieldOfView = FIRST_PERSON_FOV
			UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			print("📷 First Person Mode - FOV:", FIRST_PERSON_FOV)

		elseif mode == CAMERA_MODE.THIRD_PERSON_FREE then
			-- Third person free: Fixed zoom, character rotates towards mouse, free camera pan
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
			player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
			humanoid.CameraOffset = Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
			camera.FieldOfView = THIRD_PERSON_FOV
			-- Set mouse free, let Roblox handle camera pan
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			print("📷 Third Person Free - Fixed Zoom:", THIRD_PERSON_DISTANCE)

		elseif mode == CAMERA_MODE.THIRD_PERSON_LOCK then
			-- Third person lock: Fixed zoom, mouse locked, character faces camera direction
			-- Character offset to the left (over-the-shoulder style)
			player.CameraMode = Enum.CameraMode.Classic
			player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
			player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
			humanoid.CameraOffset = Vector3.new(THIRD_PERSON_LOCK_HORIZONTAL_OFFSET, CAMERA_HEIGHT_OFFSET, 0)
			camera.FieldOfView = THIRD_PERSON_FOV
			UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
			print("📷 Third Person Lock - Fixed Zoom:", THIRD_PERSON_DISTANCE, "Offset:", THIRD_PERSON_LOCK_HORIZONTAL_OFFSET)
		end
	end

	-- Cycle to next camera mode
	-- Order: First Person → Third Person Lock → Third Person Free → First Person
	-- (Groups locked-mouse modes together for better UX)
	local function cycleNextMode()
		if currentCameraMode == CAMERA_MODE.FIRST_PERSON then
			currentCameraMode = CAMERA_MODE.THIRD_PERSON_LOCK
		elseif currentCameraMode == CAMERA_MODE.THIRD_PERSON_LOCK then
			currentCameraMode = CAMERA_MODE.THIRD_PERSON_FREE
		else
			currentCameraMode = CAMERA_MODE.FIRST_PERSON
		end

		-- Update GameState so other modules can react
		GameState:Set("camera.isFirstPerson", isFirstPerson())
		GameState:Set("camera.mode", currentCameraMode)
		applyCameraMode(currentCameraMode)
	end

	-- F5 key: Cycle through camera modes (like Minecraft)
	if MOUSE_LOCK_ENABLED then
		UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end

			if input.KeyCode == Enum.KeyCode.F5 then
				cycleNextMode()
			end
		end)

		-- Listen for external GameState changes (e.g., from MainHUD button)
		-- This still toggles between first person and third person free
		GameState:OnPropertyChanged("camera.isFirstPerson", function(newValue, oldValue)
			local wantsFirstPerson = newValue and true or false
			local currentlyFirstPerson = isFirstPerson()

			if wantsFirstPerson ~= currentlyFirstPerson then
				if wantsFirstPerson then
					currentCameraMode = CAMERA_MODE.FIRST_PERSON
				else
					currentCameraMode = CAMERA_MODE.THIRD_PERSON_FREE
				end
				GameState:Set("camera.mode", currentCameraMode)
				applyCameraMode(currentCameraMode)
			end
		end)
	end

	if MOUSE_LOCK_ENABLED then
		print("✅ CameraController: Initialized (First Person enabled, Press F5 to cycle camera)")
	else
		print("✅ CameraController: Initialized (MouseLock disabled - native Roblox camera)")
	end
end

return CameraController

