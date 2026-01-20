--[[
	CameraController.lua

	Unified camera controller with declarative state machine.
	- Single source of truth for camera state
	- Communicates cursor intent to InputService (does NOT write UserInputService directly)
	- Handles state transitions and per-frame updates (bobbing, character rotation)
	- Listens to InputService.CursorModeChanged to freeze when UI is open

	States:
	  FIRST_PERSON      - Mouse locked, camera bobbing, dynamic FOV
	  THIRD_PERSON_LOCK - Fixed zoom, mouse locked, character faces camera direction
	  THIRD_PERSON_FREE - Fixed zoom, free cursor, character rotates towards mouse
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local GameState = require(script.Parent.Parent.Managers.GameState)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)

local CameraController = {}

-- Feature flag
local MOUSE_LOCK_ENABLED = GameConfig.IsFeatureEnabled and GameConfig.IsFeatureEnabled("MouseLock")

-- Constants
local MOUSE_SENSITIVITY = 0.6

-- State definitions (declarative configuration)
local STATES = {
	FIRST_PERSON = {
		name = "FIRST_PERSON",
		cursorMode = "gameplay-lock",
		cursorOptions = { showIcon = false, mouseDeltaSensitivity = MOUSE_SENSITIVITY },
		cameraMode = Enum.CameraMode.LockFirstPerson,
		zoomDistance = 0.5,
		baseFov = 80,
		maxFov = 96,
		dynamicFov = true,
		cameraOffset = Vector3.new(0, 0, 0),
		enableBobbing = true,
		characterRotation = "auto",
	},
	THIRD_PERSON_LOCK = {
		name = "THIRD_PERSON_LOCK",
		cursorMode = "gameplay-lock",
		cursorOptions = { showIcon = false, mouseDeltaSensitivity = MOUSE_SENSITIVITY },
		cameraMode = Enum.CameraMode.Classic,
		zoomDistance = 12,
		baseFov = 70,
		maxFov = 70,
		dynamicFov = false,
		cameraOffset = Vector3.new(1.5, 1, 0),
		enableBobbing = false,
		characterRotation = "camera-forward",
	},
	THIRD_PERSON_FREE = {
		name = "THIRD_PERSON_FREE",
		cursorMode = "gameplay-free",
		cursorOptions = { showIcon = true },
		cameraMode = Enum.CameraMode.Classic,
		zoomDistance = 12,
		baseFov = 70,
		maxFov = 70,
		dynamicFov = false,
		cameraOffset = Vector3.new(0, 1, 0),
		enableBobbing = false,
		characterRotation = "mouse-raycast",
	},
}

local MODE_CYCLE = { "FIRST_PERSON", "THIRD_PERSON_LOCK", "THIRD_PERSON_FREE" }

-- Camera bobbing settings
local WALK_BOB_FREQUENCY = 1.5
local WALK_BOB_AMPLITUDE = 0.15
local SPRINT_BOB_FREQUENCY = 3
local SPRINT_BOB_AMPLITUDE = 0.15
local BOB_HORIZONTAL_SCALE = 1.2
local NORMAL_WALKSPEED = 14

-- Character rotation settings
local ROTATION_SPEED = 12
local MIN_MOUSE_TARGET_DISTANCE = 5

-- FOV settings
local FOV_LERP = 0.25
local FOV_PER_SPEED = 1.8

-- Signals
CameraController.StateChanged = Signal.new()

-- Internal state
local _player = nil
local _camera = nil
local _humanoid = nil
local _character = nil
local _inputService = nil
local _currentStateName = nil
local _currentState = nil
local _frozen = false
local _bobbingTime = 0
local _initialized = false
local _pendingState = nil

-- Helper functions
local function setupCharacter(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local hrp = character:WaitForChild("HumanoidRootPart", 5)

	if not humanoid or not hrp then
		warn("[CameraController] Character missing required parts, aborting setup")
		return nil
	end

	task.wait(0.1)

	_humanoid = humanoid
	_camera.CameraType = Enum.CameraType.Custom
	_camera.CameraSubject = humanoid

	-- Apply AutoRotate setting based on current state (for respawn scenarios)
	if _currentState then
		if _currentState.characterRotation == "camera-forward" or _currentState.characterRotation == "mouse-raycast" then
			humanoid.AutoRotate = false
		else
			humanoid.AutoRotate = true
		end
	end

	return humanoid
end

local function applyState(state)
	if not MOUSE_LOCK_ENABLED then
		_player.CameraMode = Enum.CameraMode.Classic
		if _humanoid then
			_humanoid.CameraOffset = Vector3.new(0, 0, 0)
			_humanoid.AutoRotate = true
		end
		_inputService:SetGameplayCursorMode("gameplay-free", { showIcon = true })
		return
	end

	-- Set camera properties FIRST - Roblox's PlayerModule may adjust MouseBehavior
	-- in response to CameraMode changes, so we must set camera mode before cursor mode
	_player.CameraMode = state.cameraMode
	_player.CameraMaxZoomDistance = state.zoomDistance
	_player.CameraMinZoomDistance = state.zoomDistance

	if _humanoid then
		_humanoid.CameraOffset = state.cameraOffset

		-- Disable AutoRotate for camera-locked modes to prevent rotation conflict
		-- When characterRotation is "camera-forward" or "mouse-raycast", we manually control facing
		-- AutoRotate would fight our rotation by trying to face MoveDirection
		if state.characterRotation == "camera-forward" or state.characterRotation == "mouse-raycast" then
			_humanoid.AutoRotate = false
		else
			_humanoid.AutoRotate = true
		end
	end

	_camera.FieldOfView = state.baseFov

	-- Set cursor mode AFTER camera properties to ensure it's not overwritten
	-- by Roblox's response to CameraMode changes
	_inputService:SetGameplayCursorMode(state.cursorMode, state.cursorOptions)
end

local function enforceSettings(state)
	if _player.CameraMode ~= state.cameraMode then
		_player.CameraMode = state.cameraMode
	end
	if _player.CameraMaxZoomDistance ~= state.zoomDistance then
		_player.CameraMaxZoomDistance = state.zoomDistance
		_player.CameraMinZoomDistance = state.zoomDistance
	end
	-- Continuously enforce cursor mode to counteract Roblox's PlayerModule interference
	-- This mirrors UIBackdrop's approach of enforcing cursor state every frame
	_inputService:SetGameplayCursorMode(state.cursorMode, state.cursorOptions)
end

local function updateBobbing(deltaTime, state)
	local moveDirection = _humanoid.MoveDirection
	local isMoving = moveDirection.Magnitude > 0.1
	local baseOffset = state.cameraOffset

	if isMoving then
		local isSprinting = _humanoid.WalkSpeed > NORMAL_WALKSPEED
		local frequency = isSprinting and SPRINT_BOB_FREQUENCY or WALK_BOB_FREQUENCY
		local amplitude = isSprinting and SPRINT_BOB_AMPLITUDE or WALK_BOB_AMPLITUDE

		_bobbingTime = _bobbingTime + deltaTime * frequency

		local verticalBob = (math.sin(_bobbingTime * math.pi * 2) ^ 2) * amplitude
		local horizontalBob = math.sin(_bobbingTime * math.pi * 2) * amplitude * BOB_HORIZONTAL_SCALE

		_humanoid.CameraOffset = baseOffset + Vector3.new(horizontalBob, verticalBob, 0)
	else
		if _bobbingTime > 0 then
			_bobbingTime = math.max(0, _bobbingTime - deltaTime * 2)
		end
		_humanoid.CameraOffset = baseOffset
	end
end

local function updateDynamicFov(deltaTime, state)
	local bowPullStage = GameState:Get("voxelWorld.bowPullStage")
	local isBowFullyCharged = bowPullStage == 2

	local targetFov, lerpSpeed

	if isBowFullyCharged then
		targetFov = BowConfig.ZOOM_FOV
		lerpSpeed = BowConfig.ZOOM_IN_SPEED or 20
	else
		local walkSpeed = _humanoid.WalkSpeed or NORMAL_WALKSPEED
		targetFov = state.baseFov + math.max(0, walkSpeed - NORMAL_WALKSPEED) * FOV_PER_SPEED
		targetFov = math.clamp(targetFov, state.baseFov, state.maxFov)

		if _camera.FieldOfView < state.baseFov - 5 then
			lerpSpeed = BowConfig.ZOOM_OUT_SPEED or 15
		else
			lerpSpeed = FOV_LERP / deltaTime
		end
	end

	_camera.FieldOfView = _camera.FieldOfView + (targetFov - _camera.FieldOfView) * math.min(1, deltaTime * lerpSpeed)
end

local function updateCharacterRotation(deltaTime, state)
	local rootPart = _character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	local lookDir

	if state.characterRotation == "camera-forward" then
		local camLookVector = _camera.CFrame.LookVector
		lookDir = Vector3.new(camLookVector.X, 0, camLookVector.Z)

	elseif state.characterRotation == "mouse-raycast" then
		local mousePos = _inputService:GetMouseLocation()
		local ray = _camera:ViewportPointToRay(mousePos.X, mousePos.Y)

		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude
		raycastParams.FilterDescendantsInstances = {_character}

		local rayResult = workspace:Raycast(ray.Origin, ray.Direction * 500, raycastParams)
		local targetPos = rayResult and rayResult.Position or (ray.Origin + ray.Direction * 100)

		local charPos = rootPart.Position
		lookDir = Vector3.new(targetPos.X - charPos.X, 0, targetPos.Z - charPos.Z)

		if lookDir.Magnitude < MIN_MOUSE_TARGET_DISTANCE then
			return
		end
	else
		return
	end

	if lookDir.Magnitude < 0.1 then return end

	lookDir = lookDir.Unit
	local charPos = rootPart.Position
	local targetCFrame = CFrame.new(charPos, charPos + lookDir)

	local alpha = math.min(1, deltaTime * ROTATION_SPEED)
	rootPart.CFrame = rootPart.CFrame:Lerp(targetCFrame, alpha)
end

-- Public API

function CameraController:TransitionTo(stateName)
	local state = STATES[stateName]
	if not state then
		warn("CameraController: Unknown state:", stateName)
		return
	end

	if _frozen then
		_pendingState = stateName
		return
	end

	local previousStateName = _currentStateName
	_currentStateName = stateName
	_currentState = state
	_bobbingTime = 0

	applyState(state)

	-- Update GameState for external consumers (BlockInteraction, ViewmodelController, etc.)
	GameState:Set("camera.isFirstPerson", stateName == "FIRST_PERSON")

	if previousStateName ~= stateName then
		CameraController.StateChanged:Fire(stateName, previousStateName)
	end
end

function CameraController:CycleMode()
	if _frozen or not MOUSE_LOCK_ENABLED then return end

	local currentIndex = 1
	for i, name in ipairs(MODE_CYCLE) do
		if name == _currentStateName then
			currentIndex = i
			break
		end
	end

	local nextIndex = (currentIndex % #MODE_CYCLE) + 1
	self:TransitionTo(MODE_CYCLE[nextIndex])
end

function CameraController:SetFrozen(frozen)
	if _frozen == frozen then return end

	_frozen = frozen

	if frozen then
		_player.CameraMode = Enum.CameraMode.Classic
	else
		local targetState = _pendingState or _currentStateName
		_pendingState = nil
		if targetState then
			self:TransitionTo(targetState)
		end
	end
end

function CameraController:GetCurrentState()
	return _currentStateName
end

function CameraController:IsFirstPerson()
	return _currentStateName == "FIRST_PERSON"
end

function CameraController:Initialize()
	if _initialized then return end

	-- Lazy require to avoid circular dependency
	_inputService = require(script.Parent.Parent.Input.InputService)

	_player = Players.LocalPlayer
	_camera = workspace.CurrentCamera

	-- Setup character
	_character = _player.Character or _player.CharacterAdded:Wait()
	setupCharacter(_character)

	-- Handle respawn
	_player.CharacterAdded:Connect(function(newCharacter)
		_character = newCharacter
		setupCharacter(newCharacter)
		self:TransitionTo("FIRST_PERSON")
	end)

	-- Start in first person
	self:TransitionTo("FIRST_PERSON")

	-- Listen to backdrop active state to freeze/unfreeze camera
	-- UIBackdrop is the single source of truth for "UI is open"
	GameState:OnPropertyChanged("ui.backdropActive", function(isActive)
		self:SetFrozen(isActive == true)
	end)

	-- F5 key: Cycle through camera modes
	if MOUSE_LOCK_ENABLED then
		_inputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then return end
			if _frozen then return end

			if input.KeyCode == Enum.KeyCode.F5 then
				self:CycleMode()
			end
		end)

		-- Listen for external GameState changes (MainHUD toggle button)
		GameState:OnPropertyChanged("camera.isFirstPerson", function(newValue)
			local currentlyFirstPerson = self:IsFirstPerson()
			local wantsFirstPerson = newValue == true

			if wantsFirstPerson ~= currentlyFirstPerson then
				if wantsFirstPerson then
					self:TransitionTo("FIRST_PERSON")
				else
					self:TransitionTo("THIRD_PERSON_FREE")
				end
			end
		end)
	end

	-- RenderStepped for continuous updates
	if MOUSE_LOCK_ENABLED then
		RunService.RenderStepped:Connect(function(deltaTime)
			if not _character or not _humanoid then return end
			if _frozen then return end

			local state = _currentState
			if not state then return end

			enforceSettings(state)

			if state.enableBobbing then
				updateBobbing(deltaTime, state)
			end

			if state.dynamicFov then
				updateDynamicFov(deltaTime, state)
			end

			if state.characterRotation ~= "auto" then
				updateCharacterRotation(deltaTime, state)
			end
		end)
	end

	_initialized = true
end

return CameraController
