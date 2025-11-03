--[[
	BlockInteraction.lua
	Module for block placement and breaking using R15 character and mouse input
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local GameState = require(script.Parent.Parent.Managers.GameState)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local BlockAPI = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockAPI)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local ToolAnimationController = require(script.Parent.ToolAnimationController)
local BlockBreakProgress = require(script.Parent.Parent.UI.BlockBreakProgress)

local BlockInteraction = {}
BlockInteraction.isReady = false

-- Public function to toggle place mode (for UI/mobile buttons)
function BlockInteraction:TogglePlaceMode()
	local isFirstPerson = GameState:Get("camera.isFirstPerson")
	if not isFirstPerson then
		isPlaceMode = not isPlaceMode
		print("🔧 Place Mode:", isPlaceMode and "ON (Green = Place)" or "OFF (Grey = Break)")
		return isPlaceMode
	end
	return false -- Can't toggle in first person
end

-- Public function to get current place mode state
function BlockInteraction:IsPlaceMode()
	return isPlaceMode
end

-- Public function to set place mode (for UI)
function BlockInteraction:SetPlaceMode(enabled)
	local isFirstPerson = GameState:Get("camera.isFirstPerson")
	if not isFirstPerson then
		isPlaceMode = enabled
		print("🔧 Place Mode:", isPlaceMode and "ON (Green = Place)" or "OFF (Grey = Break)")
	end
end

-- Private state
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local blockAPI = nil
local isBreaking = false
local breakingBlock = nil
local lastBreakTime = 0
local lastPlaceTime = 0
local isPlacing = false
local selectionBox = nil -- Visual indicator for targeted block
local isPlaceMode = false -- Toggle between Break and Place mode (for third person)

-- Right-click detection for third person (distinguish click from camera pan)
local rightClickStartTime = 0
local rightClickStartPos = Vector2.new(0, 0)
local isRightClickHeld = false
local CLICK_TIME_THRESHOLD = 0.3 -- Max time for a "click" vs "hold" (seconds)
local CLICK_MOVEMENT_THRESHOLD = 5 -- Max mouse movement in pixels for a "click"

-- Mobile touch detection (distinguish tap, hold, drag)
local activeTouches = {} -- Track multiple touches
local lastTapPosition = nil -- Last tap position for targeting
local TAP_TIME_THRESHOLD = 0.2 -- Max time for a "tap" (seconds)
local HOLD_TIME_THRESHOLD = 0.3 -- Min time before "hold" action triggers (seconds)
local DRAG_MOVEMENT_THRESHOLD = 10 -- Min movement in pixels to be considered a "drag"

-- Constants
local BREAK_INTERVAL = 0.1 -- How often to send punch events (server allows >=0.1s)
local PLACE_COOLDOWN = 0.2 -- Prevent spam

-- Forward declarations
local getTargetedBlock

-- Create selection box for visual feedback
local function createSelectionBox()
	local box = Instance.new("SelectionBox")
	box.Name = "BlockSelectionBox"
	box.LineThickness = 0.03
	box.Color3 = Color3.fromRGB(255, 255, 255)
	box.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
	box.SurfaceTransparency = 0.95
	box.Transparency = 0.7
	box.Parent = workspace
	return box
end

-- Track last targeted block for dirty checking
local lastTargetedBlock = nil

-- Update selection box position
local function updateSelectionBox()
	if not BlockInteraction.isReady or not blockAPI then
		if selectionBox then
			selectionBox.Adornee = nil
		end
		lastTargetedBlock = nil
		return
	end

	-- Skip updates when player is in UI/menus (optimization)
	local GuiService = game:GetService("GuiService")
	if GuiService.SelectedObject ~= nil then
		if selectionBox then
			selectionBox.Adornee = nil
		end
		return
	end

	local blockPos, faceNormal, preciseHitPos = getTargetedBlock()

	-- Dirty check: Skip update if still targeting same block
	if lastTargetedBlock and blockPos then
		if lastTargetedBlock.X == blockPos.X and
		   lastTargetedBlock.Y == blockPos.Y and
		   lastTargetedBlock.Z == blockPos.Z then
			return -- No change, skip expensive update
		end
	end

	lastTargetedBlock = blockPos

	if blockPos then
		-- Distance check: Only show selection box if within interaction range
		local character = player.Character
		if character then
			local head = character:FindFirstChild("Head")
			if head then
				local bs = Constants.BLOCK_SIZE
				local blockCenter = Vector3.new(
					blockPos.X * bs + bs * 0.5,
					blockPos.Y * bs + bs * 0.5,
					blockPos.Z * bs + bs * 0.5
				)
				local distance = (blockCenter - head.Position).Magnitude
				local maxReach = 4.5 * bs + 2 -- Same as server placement/breaking distance

				if distance > maxReach then
					-- Block is too far, hide selection box
					if selectionBox then
						selectionBox.Adornee = nil
					end
					lastTargetedBlock = nil
					return
				end
			end
		end
		-- Create a temporary part to represent the block
		if not selectionBox then
			selectionBox = createSelectionBox()
		end

		-- Create or reuse an adornee part
		local adornee = selectionBox.Adornee
		if not adornee or not adornee.Parent then
			adornee = Instance.new("Part")
			adornee.Name = "SelectionAdornee"
			adornee.Anchored = true
			adornee.CanCollide = false
			adornee.Transparency = 1
			adornee.Parent = workspace
		end

		-- Position the adornee at the block position
		local bs = Constants.BLOCK_SIZE
		adornee.Size = Vector3.new(bs, bs, bs)
		adornee.CFrame = CFrame.new(
			blockPos.X * bs + bs/2,
			blockPos.Y * bs + bs/2,
			blockPos.Z * bs + bs/2
		)

		selectionBox.Adornee = adornee
	else
		-- No block targeted, hide selection box
		if selectionBox then
			selectionBox.Adornee = nil
		end
		lastTargetedBlock = nil
	end
end

-- Raycast to find targeted block
-- PC First person: Center of screen (camera)
-- PC Third person: Mouse cursor position
-- Mobile: Center of screen (like first person)
-- Returns: blockPos, faceNormal, preciseHitPos
getTargetedBlock = function()
	if not BlockInteraction.isReady or not blockAPI or not camera then
		return nil, nil, nil
	end

	-- Compute picking ray based on platform and camera mode
	local origin
	local direction
	local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local isFirstPerson = GameState:Get("camera.isFirstPerson")

	if isMobile then
		-- Mobile: Always use center of screen (Minecraft PE style)
		-- This ensures targeting stays aligned with camera view during rotation
		local viewportSize = camera.ViewportSize
		local ray = camera:ViewportPointToRay(viewportSize.X/2, viewportSize.Y/2)
		origin = ray.Origin
		direction = ray.Direction
	elseif isFirstPerson then
		-- PC First person: Center-of-screen ray (mouse is locked)
		origin = camera.CFrame.Position
		direction = camera.CFrame.LookVector
	else
		-- PC Third person: Ray through mouse cursor position
		local mousePos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
		origin = ray.Origin
		direction = ray.Direction
	end
	local maxDistance = 100

	-- Find block at center of screen
	local hitPos, faceNormal, preciseHitPos = blockAPI:GetTargetedBlockFace(origin, direction, maxDistance)
	if not hitPos then return nil, nil, nil end

	-- Convert to block coordinates
	local blockX = math.floor(hitPos.X / Constants.BLOCK_SIZE)
	local blockY = math.floor(hitPos.Y / Constants.BLOCK_SIZE)
	local blockZ = math.floor(hitPos.Z / Constants.BLOCK_SIZE)

	return Vector3.new(blockX, blockY, blockZ), faceNormal, preciseHitPos
end

-- Break block (left click)
local function startBreaking()
	-- Guard: Don't allow breaking until system is ready
	if not BlockInteraction.isReady then return end
	if isBreaking then return end

	-- Prevent breaking when a sword is equipped (PvP mode)
	local GameState = require(script.Parent.Parent.Managers.GameState)
	local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1
	local invMgr = require(script.Parent.Parent.Managers.ClientInventoryManager)
	-- Without direct instance, rely on tool equip server state; locally approximate via selectedBlock nil
	local toolType = nil
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
	local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
	-- If currently selected is a Tool (from hotbar), and type is SWORD, block mining
	-- We do not have the stack here; keep this lightweight client-side guard by checking GameState flag if set in hotbar
	-- Fallback: allow breaking; server still authoritative

	-- Verify character still exists
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then
		return
	end

	local blockPos, _, _ = getTargetedBlock()
	if not blockPos then return end

	isBreaking = true
	breakingBlock = blockPos
	lastBreakTime = os.clock()

	-- Send initial punch
	EventManager:SendToServer("PlayerPunch", {
		x = blockPos.X,
		y = blockPos.Y,
		z = blockPos.Z,
		dt = 0
	})

	-- Continue sending punches while mouse is held
	task.spawn(function()
		while isBreaking do
			local now = os.clock()
			local dt = now - lastBreakTime

			if dt >= BREAK_INTERVAL then
				local currentBlock, _, _ = getTargetedBlock()

				if currentBlock then
					if not breakingBlock or currentBlock ~= breakingBlock then
						-- Switched target: reset UI and start breaking new block immediately
						if BlockBreakProgress and BlockBreakProgress.Reset then
							BlockBreakProgress:Reset()
						end
						breakingBlock = currentBlock
						EventManager:SendToServer("PlayerPunch", {
							x = breakingBlock.X,
							y = breakingBlock.Y,
							z = breakingBlock.Z,
							dt = 0
						})
						ToolAnimationController:PlaySwing()
						lastBreakTime = now
					else
						EventManager:SendToServer("PlayerPunch", {
							x = breakingBlock.X,
							y = breakingBlock.Y,
							z = breakingBlock.Z,
							dt = dt
						})
						ToolAnimationController:PlaySwing()
						lastBreakTime = now
					end
				else
					-- Nothing targeted: reset progress but keep mining state while mouse is held
					if BlockBreakProgress and BlockBreakProgress.Reset then
						BlockBreakProgress:Reset()
					end
					breakingBlock = nil
				end
			end

			task.wait(0.05)
		end
	end)
end

local function stopBreaking()
	isBreaking = false
	breakingBlock = nil
	-- Note: Progress bar will auto-hide via its built-in timeout when server stops sending progress updates
end

-- Interact with block or place block (right click)
local function interactOrPlace()
	-- Guard: Don't allow actions until system is ready
	if not BlockInteraction.isReady or not blockAPI then return end

	-- Verify character still exists
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then
		return
	end

	local now = os.clock()
	if (now - lastPlaceTime) < PLACE_COOLDOWN then return end
	lastPlaceTime = now

	local blockPos, faceNormal, preciseHitPos = getTargetedBlock()
	if not blockPos then return false end

	-- Check if the targeted block is interactable (like a chest)
	local worldManager = blockAPI and blockAPI.worldManager
	if worldManager then
		local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)

		-- Handle other interactable blocks (like a chest)
		if blockId and BlockRegistry:IsInteractable(blockId) then
			-- Handle interaction (e.g., open chest, open workbench)
			if blockId == Constants.BlockType.CHEST then
				print("Opening chest at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenChest", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			elseif blockId == Constants.BlockType.CRAFTING_TABLE then
				print("Opening workbench at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenWorkbench", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			end
		end
	end

	-- Not interacting with anything, try to place a block
	if not faceNormal then return false end

	-- Get selected block from hotbar
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	if not selectedBlock or not selectedBlock.id then
		return false -- No block selected
	end

	-- Always place adjacent to clicked face (Minecraft logic)
	-- Server will handle slab merging if applicable
	local placeX = blockPos.X + faceNormal.X
	local placeY = blockPos.Y + faceNormal.Y
	local placeZ = blockPos.Z + faceNormal.Z

	local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1

	-- Send placement request with precise hit position for Minecraft-style placement
	EventManager:SendToServer("VoxelRequestBlockPlace", {
		x = placeX,
		y = placeY,
		z = placeZ,
		blockId = selectedBlock.id,
		hotbarSlot = selectedSlot,
		-- Include hit position info for determining stair/slab orientation
		hitPosition = preciseHitPos,
		targetBlockPos = blockPos,
		faceNormal = faceNormal
	})

	return true
end

-- Start continuous placement while right mouse is held
local function startPlacing()
    -- Guard
    if not BlockInteraction.isReady or not blockAPI then return end
    if isPlacing then return end

    -- Initial attempt (includes interactions like chest/water)
    interactOrPlace()

    isPlacing = true
    task.spawn(function()
        while isPlacing do
            local now = os.clock()
            if (now - lastPlaceTime) >= PLACE_COOLDOWN then
                local blockPos, faceNormal, preciseHitPos = getTargetedBlock()
                if blockPos and faceNormal then
                    local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
                    if selectedBlock and selectedBlock.id then
                        local placeX = blockPos.X + faceNormal.X
                        local placeY = blockPos.Y + faceNormal.Y
                        local placeZ = blockPos.Z + faceNormal.Z

                        -- Skip if already occupied (client check to reduce spam)
                        local worldManager = blockAPI and blockAPI.worldManager
                        local canTryPlace = true
                        if worldManager then
                            local existing = worldManager:GetBlock(placeX, placeY, placeZ)
                            if existing and existing ~= Constants.BlockType.AIR then
                                canTryPlace = false
                            end
                        end

                        if canTryPlace then
                            local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1
                            EventManager:SendToServer("VoxelRequestBlockPlace", {
                                x = placeX,
                                y = placeY,
                                z = placeZ,
                                blockId = selectedBlock.id,
                                hotbarSlot = selectedSlot,
                                hitPosition = preciseHitPos,
                                targetBlockPos = blockPos,
                                faceNormal = faceNormal
                            })
                            lastPlaceTime = now
                        else
                            -- Occupied; wait for aim change
                        end
                    end
                end
            end
            task.wait(0.05)
        end
    end)
end

local function stopPlacing()
    isPlacing = false
end

-- Update selection box and handle mode switching
task.spawn(function()
	local lastFirstPersonState = nil
	local lastCameraPos = Vector3.new(0, 0, 0)
	local lastCameraLook = Vector3.new(0, 0, 1)
	local lastMousePos = Vector2.new(0, 0)
	local CAMERA_MOVE_THRESHOLD = 1.0 -- studs (increased for mobile)
	local CAMERA_ANGLE_THRESHOLD = 0.05 -- radians
	local MOUSE_MOVE_THRESHOLD = 5 -- pixels (for third person)

	while true do
		-- Reduced from 0.05 to 0.1 for 50% less CPU usage (10Hz instead of 20Hz)
		task.wait(0.1)

		local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		local isFirstPerson = GameState:Get("camera.isFirstPerson")

		-- Check if camera moved/rotated significantly (dirty checking)
		local currentPos = camera.CFrame.Position
		local currentLook = camera.CFrame.LookVector

		local cameraMoved = (currentPos - lastCameraPos).Magnitude > CAMERA_MOVE_THRESHOLD
		local cameraRotated = math.acos(math.clamp(currentLook:Dot(lastCameraLook), -1, 1)) > CAMERA_ANGLE_THRESHOLD

		-- In third person on desktop, also check mouse movement (cursor can move independently)
		local mouseMoved = false
		if not isMobile and not isFirstPerson then
			local currentMousePos = UserInputService:GetMouseLocation()
			mouseMoved = (currentMousePos - lastMousePos).Magnitude > MOUSE_MOVE_THRESHOLD
			if mouseMoved then
				lastMousePos = currentMousePos
			end
		end

		-- Update if camera changed OR mouse moved (in third person)
		if cameraMoved or cameraRotated or mouseMoved then
			updateSelectionBox()
			lastCameraPos = currentPos
			lastCameraLook = currentLook
		end

		-- Reset place mode when switching to first person
		if isFirstPerson and lastFirstPersonState == false then
			isPlaceMode = false
			print("📷 Switched to First Person - Place Mode reset")
		end
		lastFirstPersonState = isFirstPerson
	end
end)

--[[
	Initialize block interaction system
	@param voxelWorldHandle - The voxel world handle from GameClient
]]
function BlockInteraction:Initialize(voxelWorldHandle)
	if not voxelWorldHandle or not voxelWorldHandle.GetWorldManager then
		warn("❌ BlockInteraction: Invalid voxel world handle")
		return false
	end

	-- Create BlockAPI instance
	local worldManager = voxelWorldHandle:GetWorldManager()
	blockAPI = BlockAPI.new(worldManager)
	print("✅ BlockInteraction: Created BlockAPI")

	-- Wait for character to load
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid", 5)

		if not humanoid then
			warn("❌ BlockInteraction: Character missing Humanoid")
			return
		end

		-- Mark as ready
		BlockInteraction.isReady = true
		print("✅ BlockInteraction: Ready (character loaded)")
		print("💡 Block interaction enabled - Left click: Break | Right click: Place")
	end)

	-- Handle character respawn
	player.CharacterAdded:Connect(function(character)
		-- Reset state on character respawn
		BlockInteraction.isReady = false
		isBreaking = false
		breakingBlock = nil

		-- Wait for new character to be ready
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid and blockAPI then
				BlockInteraction.isReady = true
				print("✅ BlockInteraction: Re-enabled after respawn")
			end
		end)
	end)

	-- Setup input handlers
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		-- CRITICAL: Check gameProcessed FIRST for all inputs
		-- This ensures we don't interfere with Roblox's native camera controls or UI
		if gameProcessed then return end

		-- F key: Toggle Place Mode (for third person building)
		if input.KeyCode == Enum.KeyCode.F then
			local isFirstPerson = GameState:Get("camera.isFirstPerson")
			if not isFirstPerson then
				-- Only allow toggling in third person
				isPlaceMode = not isPlaceMode
				print("🔧 Place Mode:", isPlaceMode and "ON (Green = Place)" or "OFF (Grey = Break)")
			end
		end

		-- MOBILE: Touch handling (tap vs hold vs drag)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Store tap position for targeting
			lastTapPosition = Vector2.new(input.Position.X, input.Position.Y)

			-- Track touch for gesture detection
			local touchData = {
				input = input,
				startTime = tick(),
				startPos = Vector2.new(input.Position.X, input.Position.Y),
				currentPos = Vector2.new(input.Position.X, input.Position.Y),
				moved = false,
				holdTriggered = false,
			}
			activeTouches[input] = touchData

			-- Start hold timer (triggers break action after threshold)
			task.delay(HOLD_TIME_THRESHOLD, function()
				if activeTouches[input] and not activeTouches[input].moved then
					-- Still holding and haven't moved = HOLD action (break blocks)
					activeTouches[input].holdTriggered = true
					print("📱 Hold detected at", lastTapPosition, "- Start breaking")
					startBreaking()
				end
			end)
		end

		-- Right-click in third person: Track for click vs hold detection
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local isFirstPerson = GameState:Get("camera.isFirstPerson")
			if not isFirstPerson then
				-- Track right-click for third person smart detection
				isRightClickHeld = true
				rightClickStartTime = tick()
				rightClickStartPos = UserInputService:GetMouseLocation()
			end
		end

		-- Left click behavior (PC)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Left-click ALWAYS breaks blocks in both modes (Classic Minecraft)
			startBreaking()
		end

	end)

	-- Track touch movement to detect drag vs tap/hold
	UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			local touchData = activeTouches[input]
			if touchData then
				-- Update current position
				touchData.currentPos = Vector2.new(input.Position.X, input.Position.Y)

				-- Check if moved beyond threshold
				local movement = (touchData.currentPos - touchData.startPos).Magnitude
				if movement > DRAG_MOVEMENT_THRESHOLD then
					touchData.moved = true
					-- If hold was triggered, stop breaking (switched to camera drag)
					if touchData.holdTriggered then
						stopBreaking()
						touchData.holdTriggered = false
						print("📱 Converted hold to drag - Stop breaking")
					end
				end
			end
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		-- CRITICAL: Check gameProcessed FIRST to avoid interfering with Roblox camera/UI
		if gameProcessed then return end

		-- MOBILE: Touch release - Determine gesture and action
		if input.UserInputType == Enum.UserInputType.Touch then
			local touchData = activeTouches[input]
			if touchData then
				local duration = tick() - touchData.startTime

				if touchData.holdTriggered then
					-- Was a hold action (breaking) - stop it
					print("📱 Hold ended - Stop breaking")
					stopBreaking()
				elseif touchData.moved then
					-- Was a drag (camera rotation) - do nothing
					-- print("📱 Drag gesture - Camera rotated")
				else
					-- Tap or short press without movement = interact/place (remove deadzone)
					if not touchData.holdTriggered then
						print("📱 Tap detected at", lastTapPosition, "- Place/Interact")
						interactOrPlace()
					end
				end

				-- Clean up touch data
				activeTouches[input] = nil
			end
		end

		-- PC: Stop breaking when left click released
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopBreaking()
		end

		-- PC: Right-click release in third person (detect click vs camera pan)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local isFirstPerson = GameState:Get("camera.isFirstPerson")
			if not isFirstPerson and isRightClickHeld then
				isRightClickHeld = false

				local holdDuration = tick() - rightClickStartTime
				local currentMousePos = UserInputService:GetMouseLocation()
				local mouseMovement = (currentMousePos - rightClickStartPos).Magnitude

				if holdDuration < CLICK_TIME_THRESHOLD and mouseMovement < CLICK_MOVEMENT_THRESHOLD then
					print("🖱️ Right-click detected (quick click)")
					interactOrPlace()
				end
			end
		end

		-- Note: First person right-click release is handled by ContextActionService below
	end)

	-- Setup right-click for placing/interacting using ContextActionService
	-- Dynamically bind/unbind based on camera mode
	local function handleRightClick(actionName, inputState, inputObject)
		-- First person: Handle block placement and interaction (Minecraft-style)
		if inputState == Enum.UserInputState.Begin then
			-- Check if clicking on an interactable block first
			local blockPos, faceNormal, preciseHitPos = getTargetedBlock()
			if blockPos then
				local worldManager = blockAPI and blockAPI.worldManager
				if worldManager then
					local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
					if blockId and BlockRegistry:IsInteractable(blockId) then
						-- Interact with chest, etc (one-time action, don't hold)
						interactOrPlace()
						return Enum.ContextActionResult.Sink
					end
				end
			end
			-- Not interactable: Start placing blocks
			startPlacing()
		elseif inputState == Enum.UserInputState.End then
			stopPlacing()
		end

		-- Sink the input (don't pass to other systems in first person)
		return Enum.ContextActionResult.Sink
	end

	-- Function to update right-click binding based on camera mode
	local function updateRightClickBinding()
		local isFirstPerson = GameState:Get("camera.isFirstPerson")

		if isFirstPerson then
			-- First person: Bind right-click for block placement
			ContextActionService:BindAction(
				"BlockPlacement",
				handleRightClick,
				false, -- Don't create touch button
				Enum.UserInputType.MouseButton2
			)
		else
			-- Third person: Unbind completely to allow Roblox camera
			ContextActionService:UnbindAction("BlockPlacement")
		end
	end

	-- Set initial binding
	updateRightClickBinding()

	-- Listen for camera mode changes
	GameState:OnPropertyChanged("camera.isFirstPerson", function(newValue, oldValue)
		updateRightClickBinding()
	end)

	-- Note: Mouse lock is now managed dynamically by CameraController
	-- based on camera mode (first person = locked, third person = free)

	-- Note: Crosshair is managed by Crosshair.lua (in MainHUD)
	-- It automatically shows only in first person mode

	print("✅ BlockInteraction: Initialized")
	return true
end

return BlockInteraction

