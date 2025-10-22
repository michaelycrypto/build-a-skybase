--[[
	CameraController.lua
	Manages camera settings and mouse lock behavior
	- Uses Roblox's native camera system
	- Camera offset: 2 studs above normal
	- Forced mouse lock (unlocks for UI)
	- V key to toggle First/Third person
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require(script.Parent.Parent.Managers.GameState)

local CameraController = {}

-- References
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local character = nil
local humanoid = nil

-- Settings
local CAMERA_HEIGHT_OFFSET = 1 -- Studs above normal camera height
local THIRD_PERSON_DISTANCE = 15
local FIRST_PERSON_DISTANCE = 0.5 -- Roblox's default first-person distance
local FIRST_PERSON_FOV = 90 -- Minecraft-style wide FOV
local THIRD_PERSON_FOV = 70 -- Standard Roblox FOV
local MOUSE_SENSITIVITY = 0.6 -- Lower = less sensitive (0.6 = 60% of normal speed)

-- Camera bobbing settings (Minecraft-style)
local WALK_BOB_FREQUENCY = 1.5 -- How fast the camera bobs (cycles per second) - matches Minecraft pace
local WALK_BOB_AMPLITUDE = 0.15 -- How much the camera moves up/down (studs)
local SPRINT_BOB_FREQUENCY = 3 -- Faster bobbing when sprinting
local SPRINT_BOB_AMPLITUDE = 0.15 -- More pronounced bobbing when sprinting
local BOB_HORIZONTAL_SCALE = 1.2 -- Side-to-side bobbing (slightly more than vertical for Minecraft feel)
local NORMAL_WALKSPEED = 14 -- Must match SprintController

-- State
local isFirstPerson = false
local bobbingTime = 0

local function setupCamera(char)
	-- Wait for character to be fully loaded
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	task.wait(0.1) -- Small delay to ensure everything is ready

	-- Configure camera
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = hum

	-- Set camera mode and settings based on current state
	if isFirstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
		player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
		hum.CameraOffset = Vector3.new(0, 0, 0)
		camera.FieldOfView = FIRST_PERSON_FOV -- Minecraft-style wide FOV
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
		player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
		hum.CameraOffset = Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
		camera.FieldOfView = THIRD_PERSON_FOV -- Standard FOV
	end

	print("📷 Camera setup: Mode =", player.CameraMode, "Offset =", hum.CameraOffset, "Distance =", player.CameraMaxZoomDistance)

	return hum
end

function CameraController:Initialize()
	-- Setup character
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = setupCamera(character)

	-- Set mouse sensitivity
	UserInputService.MouseDeltaSensitivity = MOUSE_SENSITIVITY

	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		isFirstPerson = false
		bobbingTime = 0
		humanoid = setupCamera(newCharacter)
	end)

	-- Continuously enforce camera settings every frame
	RunService.RenderStepped:Connect(function(deltaTime)
		if not character or not humanoid then return end

		-- Enforce camera mode
		local targetMode = isFirstPerson and Enum.CameraMode.LockFirstPerson or Enum.CameraMode.Classic
		if player.CameraMode ~= targetMode then
			player.CameraMode = targetMode
		end

		-- Enforce camera zoom distance (prevents scroll)
		local targetDistance = isFirstPerson and FIRST_PERSON_DISTANCE or THIRD_PERSON_DISTANCE
		if player.CameraMaxZoomDistance ~= targetDistance then
			player.CameraMaxZoomDistance = targetDistance
			player.CameraMinZoomDistance = targetDistance
		end

		-- Camera bobbing in first person mode when moving
		local baseOffset = Vector3.new(0, 0, 0)
		if isFirstPerson then
			-- Check if player is moving
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
				-- Vertical: smooth bounce using sin squared for natural up/down motion
				-- Horizontal: alternating sway at same frequency
				local verticalBob = (math.sin(bobbingTime * math.pi * 2) ^ 2) * amplitude
				local horizontalBob = math.sin(bobbingTime * math.pi * 2) * amplitude * BOB_HORIZONTAL_SCALE

				-- Apply bobbing to camera offset
				baseOffset = Vector3.new(horizontalBob, verticalBob, 0)
			else
				-- Smoothly decay bobbing time when not moving (prevents jarring stop)
				if bobbingTime > 0 then
					bobbingTime = math.max(0, bobbingTime - deltaTime * 2)
				end
			end
		end

		-- Enforce camera offset based on mode (with bobbing in first person)
		local targetOffset = isFirstPerson and baseOffset or Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
		humanoid.CameraOffset = targetOffset

		-- Enforce FOV based on mode
		local targetFOV = isFirstPerson and FIRST_PERSON_FOV or THIRD_PERSON_FOV
		if camera.FieldOfView ~= targetFOV then
			camera.FieldOfView = targetFOV
		end

		-- Rotate character to follow camera in third person mode
		-- (First person mode handles this automatically via LockFirstPerson)
		if not isFirstPerson then
			local rootPart = character:FindFirstChild("HumanoidRootPart")
			if rootPart then
				-- Get camera's horizontal direction
				local cameraCFrame = camera.CFrame
				local lookVector = cameraCFrame.LookVector
				-- Project to horizontal plane (ignore Y component)
				local horizontalLook = Vector3.new(lookVector.X, 0, lookVector.Z)
				if horizontalLook.Magnitude > 0.001 then
					horizontalLook = horizontalLook.Unit
					-- Create CFrame facing the camera direction
					local targetCFrame = CFrame.new(rootPart.Position, rootPart.Position + horizontalLook)
					-- Apply rotation (keep position the same)
					rootPart.CFrame = targetCFrame
				end
			end
		end

		-- Enforce mouse lock based on UI state
		local inventoryOpen = GameState:Get("voxelWorld.inventoryOpen")

		if not inventoryOpen then
			-- Lock mouse during gameplay
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
	end)

	-- V key: Toggle First/Third person
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.V then
			isFirstPerson = not isFirstPerson
			bobbingTime = 0 -- Reset bobbing when toggling camera

			if isFirstPerson then
				-- First person: Zoom to 0.5 studs (Roblox standard), no offset, wide FOV
				player.CameraMode = Enum.CameraMode.LockFirstPerson
				player.CameraMaxZoomDistance = FIRST_PERSON_DISTANCE
				player.CameraMinZoomDistance = FIRST_PERSON_DISTANCE
				humanoid.CameraOffset = Vector3.new(0, 0, 0)
				camera.FieldOfView = FIRST_PERSON_FOV
				print("📷 First Person Mode - FOV:", FIRST_PERSON_FOV)
			else
				-- Third person: Standard camera mode with offset
				player.CameraMode = Enum.CameraMode.Classic
				player.CameraMaxZoomDistance = THIRD_PERSON_DISTANCE
				player.CameraMinZoomDistance = THIRD_PERSON_DISTANCE
				humanoid.CameraOffset = Vector3.new(0, CAMERA_HEIGHT_OFFSET, 0)
				camera.FieldOfView = THIRD_PERSON_FOV
				print("📷 Third Person Mode - FOV:", THIRD_PERSON_FOV)
			end
		end
	end)

	print("✅ CameraController: Initialized (Camera 1 stud above character, Press V to toggle)")
end

return CameraController

