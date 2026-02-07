--[[
	TutorialManager.lua - Client-side Tutorial/Onboarding Manager

	Tracks local tutorial progress and communicates with TutorialService
	for server-authoritative progression. Tutorial UI is rendered by
	RightSideInfoPanel via events. Waypoint rendering (3D markers and
	screen-edge indicators) is handled inline.

	NOTE: Tutorial only applies in player's own realm, not in the hub or other players' realms.
]]

local TutorialManager = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies (injected during Initialize)
local EventManager = nil
local _GameState = nil
local ToastManager = nil
local SoundManager = nil
local TutorialConfig = nil
local InventoryManager = nil  -- For counting items across slots

-- State
local isInitialized = false
local tutorialData = nil
local currentStep = nil
local _localProgress = {} -- Track local progress for responsive UI
local liveMultiObjectiveProgress = {} -- Real-time multi_objective progress from server events
local isDisabled = false -- True when not in own realm (hub or friend's realm)
local isOwnRealm = false -- True when in player's own realm
local lastReportedCounts = {} -- Track last reported count per objective to avoid duplicate reports

-- Player reference
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Tracking state for objectives
local moveStartPosition = nil
local totalMoveDistance = 0
local cameraStartRotation = nil
local totalCameraRotation = 0
local visitedCameraModes = {} -- Track which camera modes have been visited

-- ═══════════════════════════════════════════════════════════════════════════
-- Waypoint rendering state
-- ═══════════════════════════════════════════════════════════════════════════
local waypointGui = nil          -- ScreenGui for screen-edge indicator
local activeWaypoint = nil       -- {worldPosition, worldMarker, anchor, screenIndicator}
local waypointUpdateConnection = nil

-- Lazy-loaded modules for waypoint block textures
local BlockRegistry = nil
local TextureManager = nil

local WAYPOINT_COLORS = {
	gold = Color3.fromRGB(255, 215, 0),
	white = Color3.fromRGB(255, 255, 255),
	background = Color3.fromRGB(15, 23, 42),
}

local WAYPOINT_BOB = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local WAYPOINT_PULSE = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

--[[
	Initialize the TutorialManager
	@param deps: table - Dependencies {EventManager, GameState, ToastManager, SoundManager}
]]
function TutorialManager:Initialize(deps)
	if isInitialized then return end

	-- Store dependencies
	EventManager = deps.EventManager or require(ReplicatedStorage.Shared.EventManager)
	_GameState = deps.GameState or require(script.Parent.GameState)
	ToastManager = deps.ToastManager
	SoundManager = deps.SoundManager
	InventoryManager = deps.InventoryManager

	-- Load config
	local success, result = pcall(function()
		TutorialConfig = require(ReplicatedStorage.Configs.TutorialConfig)
	end)
	if not success then
		warn("TutorialManager: Failed to load TutorialConfig:", result)
		return
	end
	-- Register event handlers
	self:_registerEventHandlers()

	-- Setup tracking hooks
	self:_setupTrackingHooks()

	-- Setup camera mode tracking
	self:_setupCameraModeTracking()

	isInitialized = true

	-- Request tutorial data from server
	task.delay(1, function()
		EventManager:SendToServer("RequestTutorialData")
	end)
end

--[[
	Register event handlers for server communication
]]
function TutorialManager:_registerEventHandlers()
	-- Tutorial data update (full sync)
	EventManager:RegisterEvent("TutorialDataUpdated", function(data)
		tutorialData = data.tutorial
		-- Check if tutorial is complete
		if tutorialData and tutorialData.completed then
			isDisabled = true
			currentStep = nil
			self:_hideWaypoint()
			return
		end

		-- Check if tutorial is disabled for current step on this server
		if tutorialData and tutorialData.disabled then
			isDisabled = true
			isOwnRealm = false
			currentStep = nil
			self:_hideWaypoint()
			return
		end

		-- Tutorial is active (either on own realm or hub with hub-specific step)
		isOwnRealm = data.isOwnRealm == true
		local _isHub = data.isHub == true
		isDisabled = false -- Tutorial is active for current step

		if tutorialData and not tutorialData.completed then
			currentStep = data.config and data.config.currentStep
			self:_showCurrentStep()
		end
	end)

	-- Step completed
	EventManager:RegisterEvent("TutorialStepCompleted", function(data)
		self:_onStepCompleted(data)
	end)

	-- Step skipped
	EventManager:RegisterEvent("TutorialStepSkipped", function(data)
		self:_onStepSkipped(data)
	end)

	-- Tutorial skipped entirely
	EventManager:RegisterEvent("TutorialSkipped", function(data)
		tutorialData = data.tutorial
		currentStep = nil
		self:_hideWaypoint()
		if ToastManager then
			ToastManager:Info("Tutorial skipped. Good luck on your adventure!", 3)
		end
	end)

	-- Progress update
	EventManager:RegisterEvent("TutorialProgressUpdated", function(data)
		self:_onProgressUpdated(data)
	end)

	-- Error
	EventManager:RegisterEvent("TutorialError", function(data)
		if ToastManager then
			ToastManager:Error(data.message or "Tutorial error", 3)
		end
	end)
end

--[[
	Setup hooks to track player actions for objectives
]]
function TutorialManager:_setupTrackingHooks()
	-- Tab key to skip current step (if skippable)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			if currentStep and currentStep.canSkip and not isDisabled then
				self:SkipCurrentStep()
			end
		end
	end)

	-- Track movement (non-blocking setup - character may not exist yet)
	local function setupMovementTracking(character)
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
		if humanoidRootPart then
			moveStartPosition = humanoidRootPart.Position
		end
	end

	-- Setup existing character if present
	if player.Character then
		setupMovementTracking(player.Character)
	end

	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		task.spawn(function()
			setupMovementTracking(newCharacter)
		end)
	end)

	-- Movement tracking heartbeat (safe if character doesn't exist yet)
	RunService.Heartbeat:Connect(function()
		-- Skip tracking if tutorial is disabled (not in own realm)
		if isDisabled or not currentStep or tutorialData and tutorialData.completed then
			return
		end

		local newChar = player.Character
		local newHRP = newChar and newChar:FindFirstChild("HumanoidRootPart")
		if newHRP then
			local currentPos = newHRP.Position
			local distance = (currentPos - (moveStartPosition or currentPos)).Magnitude
			if distance > 0.5 then -- Ignore tiny movements
				totalMoveDistance = totalMoveDistance + distance
				moveStartPosition = currentPos

				-- Check movement objective
				if currentStep and currentStep.objective and currentStep.objective.type == "move" then
					if totalMoveDistance >= (currentStep.objective.distance or 10) then
						self:_reportProgress("move", {distance = totalMoveDistance})
					end
				end
			end
		end
	end)

	-- Track camera rotation
	local camera = workspace.CurrentCamera
	if camera then
		cameraStartRotation = camera.CFrame.LookVector

		RunService.RenderStepped:Connect(function()
			-- Skip tracking if tutorial is disabled (not in own realm)
			if isDisabled or not currentStep or tutorialData and tutorialData.completed then
				return
			end

			local currentLook = camera.CFrame.LookVector
			if cameraStartRotation then
				local dot = currentLook:Dot(cameraStartRotation)
				dot = math.clamp(dot, -1, 1)
				local angleDiff = math.deg(math.acos(dot))

				if angleDiff > 5 then -- Ignore tiny rotations
					totalCameraRotation = totalCameraRotation + angleDiff
					cameraStartRotation = currentLook

					-- Check camera rotation objective
					if currentStep and currentStep.objective and currentStep.objective.type == "camera_rotate" then
						if totalCameraRotation >= (currentStep.objective.degrees or 180) then
							self:_reportProgress("camera_rotate", {degrees = totalCameraRotation})
						end
					end
				end
			end
		end)
	end

	-- Character respawn handling
	player.CharacterAdded:Connect(function(newCharacter)
		local newHRP = newCharacter:WaitForChild("HumanoidRootPart", 5)
		if newHRP then
			moveStartPosition = newHRP.Position
		end
	end)
end

--[[
	Setup camera mode tracking for camera_cycle objective
]]
function TutorialManager:_setupCameraModeTracking()
	-- Wait for CameraController to be available
	task.spawn(function()
		-- Give CameraController time to initialize
		task.wait(2)

		local success, CameraController = pcall(function()
			return require(script.Parent.Parent.Controllers.CameraController)
		end)

		if not success or not CameraController then
			warn("TutorialManager: Could not load CameraController for camera mode tracking")
			return
		end

		-- Listen to camera mode changes
		CameraController.StateChanged:Connect(function(newState, _previousState)
			-- Skip if tutorial not active
			if isDisabled or not currentStep or (tutorialData and tutorialData.completed) then
				return
			end

			local objective = currentStep.objective
			if not objective or objective.type ~= "camera_cycle" then
				return
			end

			-- Track that this mode has been visited
			if not visitedCameraModes[newState] then
				visitedCameraModes[newState] = true

				-- Count how many unique modes have been visited
				local visitedCount = 0
				for _ in pairs(visitedCameraModes) do
					visitedCount = visitedCount + 1
				end

				-- Report progress
				self:_reportProgress("camera_cycle", {
					mode = newState,
					count = visitedCount,
				})
			end
		end)
	end)
end

--[[
	Report progress to server
	@param progressType: string - Type of progress
	@param progressData: table - Progress data
]]
function TutorialManager:_reportProgress(progressType, progressData)
	if isDisabled or not currentStep then
		return
	end

	EventManager:SendToServer("TutorialProgress", {
		stepId = currentStep.id,
		progressType = progressType,
		progressData = progressData,
	})
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Waypoint rendering (inline – no separate module)
-- ═══════════════════════════════════════════════════════════════════════════

--[[
	Ensure the waypoint ScreenGui exists (created once, reused)
]]
local function ensureWaypointGui()
	if waypointGui then return end
	waypointGui = Instance.new("ScreenGui")
	waypointGui.Name = "TutorialWaypointUI"
	waypointGui.ResetOnSpawn = false
	waypointGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	waypointGui.DisplayOrder = 100
	waypointGui.IgnoreGuiInset = false
	waypointGui.Parent = playerGui
end

--[[
	Create the 3D world marker (BillboardGui above target)
	@param config: table - {label, color, blockId}
	@param worldPos: Vector3
	@return BillboardGui, Part (anchor)
]]
local function createWorldMarker(config, worldPos)
	-- Invisible anchor part
	local anchor = Instance.new("Part")
	anchor.Name = "WaypointAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = worldPos
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "WaypointMarker"
	billboard.Size = UDim2.fromOffset(80, 100)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 500
	billboard.Adornee = anchor
	billboard.Parent = workspace

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	-- Marker icon – use block texture if blockId provided, otherwise diamond
	local marker, glow

	if config.blockId then
		-- Lazy-load block texture modules
		if not BlockRegistry then
			BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
		end
		if not TextureManager then
			TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
		end

		local blockDef = BlockRegistry.Blocks[config.blockId]
		local textureName = blockDef and blockDef.textures and (blockDef.textures.front or blockDef.textures.all)
		local textureId = textureName and TextureManager:GetTextureId(textureName)

		if textureId then
			local markerFrame = Instance.new("Frame")
			markerFrame.Name = "Marker"
			markerFrame.Size = UDim2.fromOffset(48, 48)
			markerFrame.Position = UDim2.fromScale(0.5, 0)
			markerFrame.AnchorPoint = Vector2.new(0.5, 0)
			markerFrame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
			markerFrame.BackgroundTransparency = 0.3
			markerFrame.Parent = container

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 6)
			corner.Parent = markerFrame

			local blockImage = Instance.new("ImageLabel")
			blockImage.Name = "BlockImage"
			blockImage.Size = UDim2.new(1, -8, 1, -8)
			blockImage.Position = UDim2.fromScale(0.5, 0.5)
			blockImage.AnchorPoint = Vector2.new(0.5, 0.5)
			blockImage.BackgroundTransparency = 1
			blockImage.Image = textureId
			blockImage.ScaleType = Enum.ScaleType.Fit
			blockImage.Parent = markerFrame

			marker = markerFrame

			glow = Instance.new("UIStroke")
			glow.Color = config.color or WAYPOINT_COLORS.gold
			glow.Thickness = 3
			glow.Transparency = 0.2
			glow.Parent = markerFrame
		end
	end

	-- Fallback: diamond icon
	if not marker then
		marker = Instance.new("ImageLabel")
		marker.Name = "Marker"
		marker.Size = UDim2.fromOffset(40, 40)
		marker.Position = UDim2.fromScale(0.5, 0)
		marker.AnchorPoint = Vector2.new(0.5, 0)
		marker.BackgroundTransparency = 1
		marker.Image = "rbxassetid://6031094678"
		marker.ImageColor3 = config.color or WAYPOINT_COLORS.gold
		marker.Parent = container

		glow = Instance.new("UIStroke")
		glow.Color = config.color or WAYPOINT_COLORS.gold
		glow.Thickness = 2
		glow.Transparency = 0.3
		glow.Parent = marker
	end

	-- Label background
	local labelBg = Instance.new("Frame")
	labelBg.Name = "LabelBg"
	labelBg.Size = UDim2.new(1, 0, 0, 24)
	labelBg.Position = UDim2.fromOffset(0, 45)
	labelBg.BackgroundColor3 = WAYPOINT_COLORS.background
	labelBg.BackgroundTransparency = 0.3
	labelBg.Parent = container

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 6)
	labelCorner.Parent = labelBg

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = config.label or "Objective"
	label.TextColor3 = WAYPOINT_COLORS.white
	label.TextSize = 14
	label.Font = Enum.Font.GothamBold
	label.Parent = labelBg

	-- Distance label
	local distanceLabel = Instance.new("TextLabel")
	distanceLabel.Name = "Distance"
	distanceLabel.Size = UDim2.new(1, 0, 0, 18)
	distanceLabel.Position = UDim2.fromOffset(0, 72)
	distanceLabel.BackgroundTransparency = 1
	distanceLabel.Text = "0m"
	distanceLabel.TextColor3 = config.color or WAYPOINT_COLORS.gold
	distanceLabel.TextSize = 12
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Parent = container

	-- Bobbing animation
	if marker then
		local startPos = marker.Position
		TweenService:Create(marker, WAYPOINT_BOB, {
			Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - 8)
		}):Play()
	end

	-- Pulsing glow
	if glow then
		TweenService:Create(glow, WAYPOINT_PULSE, { Transparency = 0.7 }):Play()
	end

	return billboard, anchor
end

--[[
	Create the screen-space diamond indicator (for off-screen targets)
]]
local function createScreenIndicator(config)
	ensureWaypointGui()

	local indicator = Instance.new("Frame")
	indicator.Name = "ScreenIndicator"
	indicator.Size = UDim2.fromOffset(24, 24)
	indicator.BackgroundTransparency = 1
	indicator.Visible = false
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.Parent = waypointGui

	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.Size = UDim2.fromOffset(12, 12)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = config.color or WAYPOINT_COLORS.gold
	diamond.BackgroundTransparency = 0.1
	diamond.BorderSizePixel = 0
	diamond.Parent = indicator

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = diamond

	local diamondGlow = Instance.new("UIStroke")
	diamondGlow.Color = config.color or WAYPOINT_COLORS.gold
	diamondGlow.Thickness = 1
	diamondGlow.Transparency = 0.3
	diamondGlow.Parent = diamond

	return indicator
end

--[[
	Heartbeat callback – update distance text and screen-edge indicator
]]
local function updateWaypoint()
	if not activeWaypoint then return end

	local targetPos = activeWaypoint.worldPosition
	local billboard = activeWaypoint.worldMarker
	local indicator = activeWaypoint.screenIndicator

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	-- Distance (in blocks)
	local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
	local BLOCK_SIZE = Constants.BLOCK_SIZE
	local distance = (targetPos - hrp.Position).Magnitude
	local distText = string.format("%.0fm", distance / BLOCK_SIZE)

	if billboard then
		local cont = billboard:FindFirstChild("Container")
		local distLabel = cont and cont:FindFirstChild("Distance")
		if distLabel then
			distLabel.Text = distText
		end
	end

	-- Screen-space indicator for off-screen targets
	local camera = workspace.CurrentCamera
	if not camera then return end

	local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)

	if onScreen and screenPos.Z > 0 then
		if indicator then
			indicator.Visible = false
		end
	else
		if indicator then
			indicator.Visible = true

			local viewportSize = camera.ViewportSize
			local centerX = viewportSize.X / 2
			local centerY = viewportSize.Y / 2

			local dirX = screenPos.X - centerX
			local dirY = screenPos.Y - centerY

			if screenPos.Z < 0 then
				dirX = -dirX
				dirY = -dirY
			end

			local angle = math.atan2(dirY, dirX)
			local padding = 20
			local radius = math.min(centerX - padding, centerY - padding)
			local edgeX = centerX + math.cos(angle) * radius
			local edgeY = centerY + math.sin(angle) * radius

			indicator.Position = UDim2.fromOffset(edgeX, edgeY)
		end
	end
end

--[[
	Show a waypoint at a world position
	@param config: table - {worldPosition, label, color, blockId}
]]
function TutorialManager:_showWaypointAt(config)
	self:_hideWaypoint()

	local worldPos = config.worldPosition
	if not worldPos then
		warn("TutorialManager: No world position for waypoint")
		return
	end

	local worldMarker, anchor = createWorldMarker(config, worldPos)
	local screenIndicator = createScreenIndicator(config)

	activeWaypoint = {
		worldPosition = worldPos,
		worldMarker = worldMarker,
		anchor = anchor,
		screenIndicator = screenIndicator,
	}

	if waypointUpdateConnection then
		waypointUpdateConnection:Disconnect()
	end
	waypointUpdateConnection = RunService.Heartbeat:Connect(updateWaypoint)
end

--[[
	Resolve a waypoint name from TutorialConfig and show it
	@param waypointName: string - Key in TutorialConfig.Waypoints
]]
function TutorialManager:_showWaypoint(waypointName)
	if not TutorialConfig then return end

	local waypointConfig = TutorialConfig.GetWaypoint(waypointName)
	if not waypointConfig then
		warn("TutorialManager: Unknown waypoint:", waypointName)
		return
	end

	if waypointConfig.type == "npc" then
		-- Find NPC in workspace
		local npcsFolder = workspace:FindFirstChild("NPCs")
		if not npcsFolder then return end

		local npcModel = npcsFolder:FindFirstChild(waypointConfig.npcId)
		if not npcModel then
			for _, child in ipairs(npcsFolder:GetChildren()) do
				if child.Name:find(waypointConfig.npcId) then
					npcModel = child
					break
				end
			end
		end

		if not npcModel then
			warn("TutorialManager: NPC not found:", waypointConfig.npcId)
			return
		end

		local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("HumanoidRootPart")
		if not primaryPart then return end

		self:_showWaypointAt({
			worldPosition = primaryPart.Position,
			label = waypointConfig.label or npcModel.Name,
			color = waypointConfig.color,
		})

	elseif waypointConfig.type == "block_area" then
		local targetOffset = waypointConfig.offsetFromSpawn
		if not targetOffset then return end

		local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
		local BLOCK_SIZE = Constants.BLOCK_SIZE

		-- SkyblockGenerator config values
		local ISLAND_ORIGIN_X = 48
		local ISLAND_ORIGIN_Z = 48
		local ISLAND_SURFACE_Y = 65

		local blockX = ISLAND_ORIGIN_X + targetOffset.X
		local blockZ = ISLAND_ORIGIN_Z + targetOffset.Z
		local blockY = ISLAND_SURFACE_Y + targetOffset.Y

		local worldX = blockX * BLOCK_SIZE + BLOCK_SIZE / 2
		local worldY = blockY * BLOCK_SIZE + BLOCK_SIZE / 2
		local worldZ = blockZ * BLOCK_SIZE + BLOCK_SIZE / 2

		self:_showWaypointAt({
			worldPosition = Vector3.new(worldX, worldY, worldZ),
			label = waypointConfig.label,
			color = waypointConfig.color,
			blockId = waypointConfig.blockId,
		})

	elseif waypointConfig.type == "position" then
		self:_showWaypointAt({
			worldPosition = waypointConfig.position,
			label = waypointConfig.label,
			color = waypointConfig.color,
		})
	end
end

--[[
	Hide and destroy the active waypoint
]]
function TutorialManager:_hideWaypoint()
	if waypointUpdateConnection then
		waypointUpdateConnection:Disconnect()
		waypointUpdateConnection = nil
	end

	if activeWaypoint then
		if activeWaypoint.worldMarker then
			activeWaypoint.worldMarker:Destroy()
		end
		if activeWaypoint.anchor then
			activeWaypoint.anchor:Destroy()
		end
		if activeWaypoint.screenIndicator then
			activeWaypoint.screenIndicator:Destroy()
		end
		activeWaypoint = nil
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- Step lifecycle
-- ═══════════════════════════════════════════════════════════════════════════

--[[
	Set up the current tutorial step (reset trackers, show waypoint, play sound)
	Tutorial UI is handled by RightSideInfoPanel via events.
]]
function TutorialManager:_showCurrentStep()
	if not currentStep then
		return
	end

	-- Reset local progress trackers
	totalMoveDistance = 0
	totalCameraRotation = 0
	visitedCameraModes = {} -- Reset camera mode tracking
	-- Reset last reported counts when step changes
	lastReportedCounts = {}

	-- Track initial camera mode if this is a camera_cycle objective
	if currentStep.objective and currentStep.objective.type == "camera_cycle" then
		task.spawn(function()
			-- Wait a bit for CameraController to be ready
			task.wait(0.5)
			local success, CameraController = pcall(function()
				return require(script.Parent.Parent.Controllers.CameraController)
			end)

			if success and CameraController then
				local currentMode = CameraController:GetCurrentState()
				if currentMode then
					visitedCameraModes[currentMode] = true

					-- Count how many unique modes have been visited
					local visitedCount = 0
					for _ in pairs(visitedCameraModes) do
						visitedCount = visitedCount + 1
					end

					-- Report initial progress
					self:_reportProgress("camera_cycle", {
						mode = currentMode,
						count = visitedCount,
					})
				end
			end
		end)
	end

	-- Show waypoint if step has one configured
	if currentStep.waypoint then
		self:_showWaypoint(currentStep.waypoint)
	else
		self:_hideWaypoint()
	end

	-- Play notification sound
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("notification")
	end
end

--[[
	Handle step completed event
]]
function TutorialManager:_onStepCompleted(data)
	-- Hide waypoint from completed step
	self:_hideWaypoint()

	-- Show reward notification
	if data.reward then
		local rewardParts = {}
		if data.reward.coins then
			table.insert(rewardParts, "+" .. data.reward.coins .. " coins")
		end
		if data.reward.gems then
			table.insert(rewardParts, "+" .. data.reward.gems .. " gems")
		end
		if data.reward.experience then
			table.insert(rewardParts, "+" .. data.reward.experience .. " XP")
		end

		if ToastManager then
			local message = data.reward.message or "Step complete!"
			if #rewardParts > 0 then
				message = message .. " " .. table.concat(rewardParts, ", ")
			end
			ToastManager:Success(message, 3)
		end

		-- Play success sound
		if SoundManager and SoundManager.PlaySFX then
			SoundManager:PlaySFX("achievement")
		end
	end

	-- Reset multi_objective progress for next step
	liveMultiObjectiveProgress = {}

	-- Show next step after delay
	if data.nextStep then
		currentStep = data.nextStep
		task.delay(0.5, function()
			self:_showCurrentStep()
		end)
	elseif data.tutorialComplete then
		-- Tutorial complete!
		currentStep = nil
		if ToastManager then
			ToastManager:Achievement("Tutorial Complete!", "You've mastered the basics of Skyblox!")
		end
	end
end

--[[
	Handle step skipped event
]]
function TutorialManager:_onStepSkipped(data)
	self:_hideWaypoint()

	if ToastManager then
		ToastManager:Info("Step skipped", 2)
	end

	liveMultiObjectiveProgress = {}

	if data.nextStep then
		currentStep = data.nextStep
		task.delay(0.5, function()
			self:_showCurrentStep()
		end)
	elseif data.tutorialComplete then
		currentStep = nil
	end
end

--[[
	Handle progress update (for UI updates)
]]
function TutorialManager:_onProgressUpdated(data)
	-- Store multi_objective progress for panel access
	if data and data.multiObjectiveProgress then
		liveMultiObjectiveProgress = data.multiObjectiveProgress
	end
	-- Tutorial UI updates are handled by RightSideInfoPanel via events
end

--[[
	Called when player collects an item
	@param itemId: number - The item ID collected
	@param count: number - Count in the changed slot
]]
function TutorialManager:OnItemCollected(itemId, count)
	-- Skip if tutorial not active
	if isDisabled or not currentStep or (tutorialData and tutorialData.completed) then
		return
	end

	local objective = currentStep.objective
	if not objective or objective.type ~= "collect_item" then
		return
	end

	-- Check if item matches objective
	local matches = false
	if objective.itemId and itemId == objective.itemId then
		matches = true
	elseif objective.anyOf then
		for _, targetId in ipairs(objective.anyOf) do
			if itemId == targetId then
				matches = true
				break
			end
		end
	end

	if not matches then
		return
	end

	-- Calculate total count of matching items across inventory
	local totalCount = count
	if objective.anyOf then
		totalCount = self:_getTotalMatchingItemCount(objective.anyOf)
	elseif objective.itemId then
		totalCount = self:_getTotalMatchingItemCount({objective.itemId})
	end

	-- Only report progress if the count has increased (avoid duplicate reports)
	local stepKey = currentStep.id
	local lastCount = lastReportedCounts[stepKey] or 0
	if totalCount <= lastCount then
		-- Count didn't increase, don't report
		return
	end

	-- Update last reported count
	lastReportedCounts[stepKey] = totalCount

	self:_reportProgress("collect_item", {
		itemId = itemId,
		count = totalCount,
	})
end

--[[
	Get total count of all matching items across inventory and hotbar
	@param itemIds: table - Array of item IDs to match
	@return number - Total count
]]
function TutorialManager:_getTotalMatchingItemCount(itemIds)
	local total = 0

	if not InventoryManager then
		return 0
	end

	-- Build a set for fast lookup
	local itemIdSet = {}
	for _, id in ipairs(itemIds) do
		itemIdSet[id] = true
	end

	-- Check inventory slots (27 slots)
	if InventoryManager.GetInventorySlot then
		for i = 1, 27 do
			local stack = InventoryManager:GetInventorySlot(i)
			if stack and not stack:IsEmpty() and itemIdSet[stack:GetItemId()] then
				total = total + stack:GetCount()
			end
		end
	end

	-- Check hotbar slots (9 slots)
	if InventoryManager.GetHotbarSlot then
		for i = 1, 9 do
			local stack = InventoryManager:GetHotbarSlot(i)
			if stack and not stack:IsEmpty() and itemIdSet[stack:GetItemId()] then
				total = total + stack:GetCount()
			end
		end
	end

	return total
end

--[[
	Called when player crafts an item
	@param itemId: number - The item ID crafted
	@param count: number - Total items crafted (default 1)
]]
function TutorialManager:OnItemCrafted(itemId, count)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("craft_item", {itemId = itemId, count = count or 1})
end

--[[
	Called when player places a block
	@param blockId: number - The block type placed
]]
function TutorialManager:OnBlockPlaced(blockId)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("place_block", {blockId = blockId})
end

--[[
	Called when player breaks a block
	@param blockType: number - The block type broken
]]
function TutorialManager:OnBlockBroken(blockType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("break_block", {blockType = blockType})
end

--[[
	Called when player opens a UI panel
	@param panelName: string - Name of the panel opened
]]
function TutorialManager:OnPanelOpened(panelName)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("ui_open", {panel = panelName})
end

--[[
	Called when player interacts with a block
	@param blockType: string - Type of block interacted with (e.g., "crafting_table")
]]
function TutorialManager:OnBlockInteracted(blockType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("interact_block", {blockType = blockType})
end

--[[
	Called when player equips an item
	@param itemId: number - The item ID equipped
]]
function TutorialManager:OnItemEquipped(itemId)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("equip_item", {itemId = itemId})
end

--[[
	Called when player interacts with an NPC
	@param npcType: string - The NPC type ("shop", "merchant", "warp", etc.)
]]
function TutorialManager:OnNPCInteracted(npcType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("npc_interact", {npcType = npcType})
end

--[[
	Called when player sells an item to merchant
	@param itemId: number - The item ID sold
	@param count: number - Amount sold
]]
function TutorialManager:OnItemSold(itemId, count)
	-- Skip if tutorial disabled
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("sell_item", {itemId = itemId, count = count or 1})
end

--[[
	Called when player buys an item from shop
	@param itemId: number - The item ID bought
	@param count: number - Amount bought
]]
function TutorialManager:OnItemBought(itemId, count)
	-- Skip if tutorial disabled
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("buy_item", {itemId = itemId, count = count or 1})
end

--[[
	Skip the current step (if allowed)
]]
function TutorialManager:SkipCurrentStep()
	-- Can't skip if disabled (not in own realm)
	if isDisabled or not currentStep then return end

	if currentStep.canSkip then
		EventManager:SendToServer("SkipTutorialStep")
	else
		if ToastManager then
			ToastManager:Warning("This step cannot be skipped", 2)
		end
	end
end

--[[
	Skip the entire tutorial
]]
function TutorialManager:SkipTutorial()
	-- Can't skip if disabled (not in own realm)
	if isDisabled then return end

	EventManager:SendToServer("SkipTutorial")
end

--[[
	Check if tutorial is completed
]]
function TutorialManager:IsCompleted()
	return tutorialData and tutorialData.completed
end

--[[
	Check if tutorial is active
]]
function TutorialManager:IsActive()
	return not isDisabled and tutorialData and not tutorialData.completed and currentStep ~= nil
end

--[[
	Check if tutorial is disabled (not in own realm)
]]
function TutorialManager:IsDisabled()
	return isDisabled
end

--[[
	Check if currently in own realm
]]
function TutorialManager:IsInOwnRealm()
	return isOwnRealm
end

--[[
	Get current step info
]]
function TutorialManager:GetCurrentStep()
	return currentStep
end

--[[
	Get raw tutorial data (progress counts, multiObjectiveProgress, etc.)
]]
function TutorialManager:GetTutorialData()
	return tutorialData
end

--[[
	Get real-time multi_objective progress (updated on each TutorialProgressUpdated event)
]]
function TutorialManager:GetMultiObjectiveProgress()
	return liveMultiObjectiveProgress
end

--[[
	Cleanup
]]
function TutorialManager:Cleanup()
	self:_hideWaypoint()
	if waypointGui then
		waypointGui:Destroy()
		waypointGui = nil
	end
	isInitialized = false
	tutorialData = nil
	currentStep = nil
	liveMultiObjectiveProgress = {}
	isDisabled = false
	isOwnRealm = false
end

return TutorialManager

