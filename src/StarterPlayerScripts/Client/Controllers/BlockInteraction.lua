--[[
	BlockInteraction.lua
	Module for block placement and breaking using R15 character and mouse input
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local GameState = require(script.Parent.Parent.Managers.GameState)
local BlockAPI = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockAPI)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)

local BlockInteraction = {}
BlockInteraction.isReady = false

-- Private state
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local blockAPI = nil
local isBreaking = false
local breakingBlock = nil
local lastBreakTime = 0
local lastPlaceTime = 0
local selectionBox = nil -- Visual indicator for targeted block

-- Constants
local BREAK_INTERVAL = 0.25 -- How often to send punch events
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

-- Update selection box position
local function updateSelectionBox()
	if not BlockInteraction.isReady or not blockAPI then
		if selectionBox then
			selectionBox.Adornee = nil
		end
		return
	end

	local blockPos, faceNormal, preciseHitPos = getTargetedBlock()

	if blockPos then
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
	end
end

-- Raycast to find targeted block (center of screen)
-- Returns: blockPos, faceNormal, preciseHitPos
getTargetedBlock = function()
	if not BlockInteraction.isReady or not blockAPI or not camera then
		return nil, nil, nil
	end

	-- Raycast from camera position (automatically correct for first/third person)
	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector
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
		dt = BREAK_INTERVAL
	})

	-- Continue sending punches while mouse is held
	task.spawn(function()
		while isBreaking do
			local now = os.clock()
			local dt = now - lastBreakTime

			if dt >= BREAK_INTERVAL then
				local currentBlock, _, _ = getTargetedBlock()

				-- Check if still targeting same block
				if currentBlock and currentBlock == breakingBlock then
					EventManager:SendToServer("PlayerPunch", {
						x = breakingBlock.X,
						y = breakingBlock.Y,
						z = breakingBlock.Z,
						dt = dt
					})
					lastBreakTime = now
				else
					-- Target changed, stop breaking
					isBreaking = false
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
	if not blockPos then return end

	-- Check if the targeted block is interactable (like a chest)
	local worldManager = blockAPI and blockAPI.worldManager
	if worldManager then
		local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
		if blockId and BlockRegistry:IsInteractable(blockId) then
			-- Handle interaction (e.g., open chest)
			if blockId == Constants.BlockType.CHEST then
				print("Opening chest at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenChest", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return
			end
		end
	end

	-- Not interacting with anything, try to place a block
	if not faceNormal then return end

	-- Get selected block from hotbar
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	if not selectedBlock or not selectedBlock.id then
		return -- No block selected
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
end

-- Create crosshair UI
local function createCrosshair()
	local playerGui = player:WaitForChild("PlayerGui")
	local crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "BlockInteractionCrosshair"
	crosshairGui.ResetOnSpawn = false
	crosshairGui.IgnoreGuiInset = true
	crosshairGui.Parent = playerGui

	local crosshair = Instance.new("Frame")
	crosshair.Name = "Crosshair"
	crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
	crosshair.Position = UDim2.new(0.5, 0, 0.5, 0)
	crosshair.Size = UDim2.new(0, 4, 0, 4)
	crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	crosshair.BorderSizePixel = 0
	crosshair.BackgroundTransparency = 0.3
	crosshair.Parent = crosshairGui

	-- Add crosshair arms
	local function createCrosshairArm(name, size, position)
		local arm = Instance.new("Frame")
		arm.Name = name
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = position
		arm.Size = size
		arm.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		arm.BorderSizePixel = 0
		arm.BackgroundTransparency = 0.3
		arm.Parent = crosshairGui
		return arm
	end

	local armTop = createCrosshairArm("Top", UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 0.5, -12))
	local armBottom = createCrosshairArm("Bottom", UDim2.new(0, 2, 0, 8), UDim2.new(0.5, 0, 0.5, 12))
	local armLeft = createCrosshairArm("Left", UDim2.new(0, 8, 0, 2), UDim2.new(0.5, -12, 0.5, 0))
	local armRight = createCrosshairArm("Right", UDim2.new(0, 8, 0, 2), UDim2.new(0.5, 12, 0.5, 0))

	-- Update crosshair color and selection box based on targeting
	task.spawn(function()
		while true do
			task.wait(0.05) -- Update faster for smoother selection box

			-- Update selection box
			updateSelectionBox()

			if not BlockInteraction.isReady then
				-- Gray when not ready
				crosshair.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
				armTop.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
				armBottom.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
				armLeft.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
				armRight.BackgroundColor3 = Color3.fromRGB(128, 128, 128)
			else
				local blockPos = getTargetedBlock()
				if blockPos then
					-- Green when targeting a block
					crosshair.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					armTop.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					armBottom.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					armLeft.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
					armRight.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
				else
					-- White when not targeting
					crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					armTop.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					armBottom.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					armLeft.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
					armRight.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
				end
			end
		end
	end)
end

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
		-- Ignore if typing in chat or UI is focused
		if gameProcessed then return end

		-- Left click - break block
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			startBreaking()
		end

		-- Right click - interact or place block
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			interactOrPlace()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		-- Stop breaking when left click released
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopBreaking()
		end
	end)

	-- Lock mouse for 3rd person controls
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- Create crosshair
	createCrosshair()

	print("✅ BlockInteraction: Initialized")
	return true
end

return BlockInteraction

