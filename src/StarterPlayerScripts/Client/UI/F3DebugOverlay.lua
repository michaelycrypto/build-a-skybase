--[[
	F3DebugOverlay.lua - Minecraft-style Debug Overlay (Simplified)
	Press F3 to toggle debug information display
--]]

local F3DebugOverlay = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local InputService = require(script.Parent.Parent.Input.InputService)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local BlockInteraction = require(script.Parent.Parent.Controllers.BlockInteraction)
local CustomFont = require(ReplicatedStorage.RBX_CustomFont)
local WaterUtils = require(ReplicatedStorage.Shared.VoxelWorld.World.WaterUtils)

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI State
local isVisible = false
local screenGui = nil
local leftPanel = nil
local rightPanel = nil
local updateConnection = nil

-- Update rate (10 Hz)
local UPDATE_INTERVAL = 0.1
local lastUpdate = 0

-- FPS tracking (smoothed)
local fpsHistory = {}
local FPS_HISTORY_SIZE = 10

-- Font settings
local CUSTOM_FONT = "Upheaval BRK"
local MONO_FONT = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Regular)
local TITLE_SIZE = 16
local TEXT_SIZE = 14
local LINE_HEIGHT = 18
local PADDING = 8
local BACKGROUND_COLOR = Color3.fromRGB(0, 0, 0)
local BACKGROUND_TRANSPARENCY = 0.5
local TEXT_COLOR = Color3.fromRGB(255, 255, 255)
local TITLE_COLOR = Color3.fromRGB(85, 255, 85)

-- Labels for dynamic updating
local labels = {}

--[[
	Get cardinal direction from yaw angle
	Minecraft coordinate system:
	- +Z = South, -Z = North
	- +X = East, -X = West
	Yaw calculated from atan2(X, Z):
	- 0° = looking at +Z (South)
	- 90° = looking at +X (East)
	- 180° = looking at -Z (North)
	- 270° = looking at -X (West)
]]
local function getCardinalDirection(yaw)
	if yaw >= 337.5 or yaw < 22.5 then return "S"
	elseif yaw >= 22.5 and yaw < 67.5 then return "SE"
	elseif yaw >= 67.5 and yaw < 112.5 then return "E"
	elseif yaw >= 112.5 and yaw < 157.5 then return "NE"
	elseif yaw >= 157.5 and yaw < 202.5 then return "N"
	elseif yaw >= 202.5 and yaw < 247.5 then return "NW"
	elseif yaw >= 247.5 and yaw < 292.5 then return "W"
	else return "SW"
	end
end

--[[
	Create a title label with custom font
]]
local function createTitle(parent, name, text, yOffset)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.TextSize = TITLE_SIZE
	label.TextColor3 = TITLE_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -PADDING * 2, 0, LINE_HEIGHT)
	label.Position = UDim2.fromOffset(PADDING, yOffset)
	label.Text = text
	label.Parent = parent

	-- Apply custom font
	pcall(function()
		CustomFont.Apply(label, CUSTOM_FONT)
	end)

	return label
end

--[[
	Create a data label
]]
local function createLabel(parent, name, text, yOffset)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.RobotoMono
	label.FontFace = MONO_FONT
	label.TextSize = TEXT_SIZE
	label.TextColor3 = TEXT_COLOR
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -PADDING * 2, 0, LINE_HEIGHT)
	label.Position = UDim2.fromOffset(PADDING, yOffset)
	label.Text = text
	label.Parent = parent
	return label
end

--[[
	Create the debug overlay UI
]]
local function createUI()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "F3DebugOverlay"
	screenGui.DisplayOrder = 100
	screenGui.IgnoreGuiInset = true
	screenGui.Enabled = false
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Left panel (player info, performance)
	leftPanel = Instance.new("Frame")
	leftPanel.Name = "LeftPanel"
	leftPanel.BackgroundColor3 = BACKGROUND_COLOR
	leftPanel.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	leftPanel.BorderSizePixel = 0
	leftPanel.Position = UDim2.fromOffset(4, 36)
	leftPanel.Parent = screenGui

	local leftCorner = Instance.new("UICorner")
	leftCorner.CornerRadius = UDim.new(0, 4)
	leftCorner.Parent = leftPanel

	-- Right panel (targeted block)
	rightPanel = Instance.new("Frame")
	rightPanel.Name = "RightPanel"
	rightPanel.BackgroundColor3 = BACKGROUND_COLOR
	rightPanel.BackgroundTransparency = BACKGROUND_TRANSPARENCY
	rightPanel.BorderSizePixel = 0
	rightPanel.AnchorPoint = Vector2.new(1, 0)
	rightPanel.Position = UDim2.new(1, -4, 0, 36)
	rightPanel.Parent = screenGui

	local rightCorner = Instance.new("UICorner")
	rightCorner.CornerRadius = UDim.new(0, 4)
	rightCorner.Parent = rightPanel

	-- Left panel content
	local y = PADDING

	createTitle(leftPanel, "Title", "Debug", y)
	y = y + LINE_HEIGHT + 4

	labels.coords = createLabel(leftPanel, "Coords", "Coordinates: 0, 0, 0", y)
	y = y + LINE_HEIGHT

	labels.facing = createLabel(leftPanel, "Facing", "Facing: N (0°)", y)
	y = y + LINE_HEIGHT

	labels.velocity = createLabel(leftPanel, "Velocity", "Velocity: 0.0", y)
	y = y + LINE_HEIGHT + 4

	labels.fps = createLabel(leftPanel, "FPS", "FPS: 0", y)
	y = y + LINE_HEIGHT

	labels.memory = createLabel(leftPanel, "Memory", "Memory: 0 MB", y)
	y = y + LINE_HEIGHT

	labels.ping = createLabel(leftPanel, "Ping", "Ping: 0 ms", y)

	leftPanel.Size = UDim2.fromOffset(220, y + PADDING + LINE_HEIGHT)

	-- Right panel content
	y = PADDING

	createTitle(rightPanel, "TargetTitle", "Target", y)
	y = y + LINE_HEIGHT + 4

	labels.targetBlock = createLabel(rightPanel, "TargetBlock", "Block: None", y)
	y = y + LINE_HEIGHT

	labels.targetPos = createLabel(rightPanel, "TargetPos", "At: -", y)
	y = y + LINE_HEIGHT

	labels.targetMeta = createLabel(rightPanel, "TargetMeta", "Meta: -", y)
	y = y + LINE_HEIGHT

	labels.targetSource = createLabel(rightPanel, "TargetSource", "From: -", y)
	y = y + LINE_HEIGHT

	labels.targetFlow = createLabel(rightPanel, "TargetFlow", "To: -", y)
	y = y + LINE_HEIGHT

	labels.targetCorner = createLabel(rightPanel, "TargetCorner", "Surface: -", y)
	y = y + LINE_HEIGHT

	labels.targetDist = createLabel(rightPanel, "TargetDist", "Distance: -", y)

	rightPanel.Size = UDim2.fromOffset(220, y + PADDING + LINE_HEIGHT)
end

--[[
	Get the block the player is looking at
]]
local function getTargetedBlock()
	if not BlockInteraction.isReady then
		return nil, nil
	end
	return BlockInteraction:GetTargetedBlock()
end

--[[
	Calculate smoothed FPS
]]
local function getSmoothedFPS()
	if #fpsHistory == 0 then
		return 0
	end
	local sum = 0
	for _, fps in ipairs(fpsHistory) do
		sum = sum + fps
	end
	return math.floor(sum / #fpsHistory + 0.5)
end

--[[
	Update FPS history
]]
local function updateFPSHistory(dt)
	local instantFPS = dt > 0 and (1 / dt) or 0
	table.insert(fpsHistory, instantFPS)
	if #fpsHistory > FPS_HISTORY_SIZE then
		table.remove(fpsHistory, 1)
	end
end

--[[
	Update all debug information
]]
local function updateDebugInfo()
	if not labels.coords then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera

	if rootPart then
		local pos = rootPart.Position
		local blockX = math.floor(pos.X / Constants.BLOCK_SIZE)
		local blockY = math.floor(pos.Y / Constants.BLOCK_SIZE)
		local blockZ = math.floor(pos.Z / Constants.BLOCK_SIZE)
		labels.coords.Text = string.format("Coordinates: %d, %d, %d", blockX, blockY, blockZ)

		local velocity = rootPart.AssemblyLinearVelocity
		labels.velocity.Text = string.format("Velocity: %.1f", velocity.Magnitude)
	end

	if camera then
		local lookVector = camera.CFrame.LookVector
		local yaw = math.deg(math.atan2(lookVector.X, lookVector.Z))
		if yaw < 0 then
			yaw = yaw + 360
		end
		labels.facing.Text = string.format("Facing: %s (%.0f°)", getCardinalDirection(yaw), yaw)
	end

	labels.fps.Text = string.format("FPS: %d", math.clamp(getSmoothedFPS(), 0, 999))
	labels.memory.Text = string.format("Memory: %.0f MB", Stats:GetTotalMemoryUsageMb())
	labels.ping.Text = string.format("Ping: %.0f ms", player:GetNetworkPing() * 1000)

	local targetPos, targetId, _, targetMeta = getTargetedBlock()
	if targetPos and targetId and targetId ~= 0 then
		local blockDef = BlockRegistry.Blocks[targetId]
		local blockName = blockDef and blockDef.name or "Unknown"
		labels.targetBlock.Text = string.format("Block: %s", blockName)
		labels.targetPos.Text = string.format("At: %d, %d, %d", targetPos.X, targetPos.Y, targetPos.Z)

		-- Display metadata with special decoding for water blocks
		local metaDisplay = tostring(targetMeta or 0)
		local sourceStr, flowStr, cornerStr = "-", "-", "-"
		
		if WaterUtils.IsWater(targetId) then
			local depth = WaterUtils.GetDepth(targetMeta or 0)
			local falling = WaterUtils.IsFalling(targetMeta or 0)
			if targetId == Constants.BlockType.WATER_SOURCE then
				metaDisplay = string.format("%d (source)", targetMeta or 0)
			else
				metaDisplay = string.format("%d (d:%d%s)", targetMeta or 0, depth, falling and ",fall" or "")
			end
			
			-- Get flow direction info
			local worldManager = BlockInteraction:GetWorldManager()
			if worldManager then
				sourceStr, flowStr = WaterUtils.GetFlowStrings(worldManager, targetPos.X, targetPos.Y, targetPos.Z)
				cornerStr = WaterUtils.GetCornerString(worldManager, targetPos.X, targetPos.Y, targetPos.Z)
			end
		end
		
		labels.targetMeta.Text = string.format("Meta: %s", metaDisplay)
		labels.targetSource.Text = string.format("From: %s", sourceStr)
		labels.targetFlow.Text = string.format("To: %s", flowStr)
		labels.targetCorner.Text = string.format("Surface: %s", cornerStr)

		-- Calculate distance from camera to block center (in blocks)
		local bs = Constants.BLOCK_SIZE
		local blockCenter = Vector3.new(
			targetPos.X * bs + bs * 0.5,
			targetPos.Y * bs + bs * 0.5,
			targetPos.Z * bs + bs * 0.5
		)
		local camPos = camera and camera.CFrame.Position or Vector3.zero
		local distanceInBlocks = (blockCenter - camPos).Magnitude / bs
		labels.targetDist.Text = string.format("Distance: %.1f", distanceInBlocks)
	else
		labels.targetBlock.Text = "Block: None"
		labels.targetPos.Text = "At: -"
		labels.targetMeta.Text = "Meta: -"
		labels.targetSource.Text = "From: -"
		labels.targetFlow.Text = "To: -"
		labels.targetCorner.Text = "Surface: -"
		labels.targetDist.Text = "Distance: -"
	end
end

--[[
	Toggle visibility
]]
function F3DebugOverlay:Toggle()
	isVisible = not isVisible

	if screenGui then
		screenGui.Enabled = isVisible
	end

	if isVisible then
		fpsHistory = {}
		if not updateConnection then
			updateConnection = RunService.Heartbeat:Connect(function(dt)
				updateFPSHistory(dt)
				local now = tick()
				if now - lastUpdate >= UPDATE_INTERVAL then
					lastUpdate = now
					pcall(updateDebugInfo)
				end
			end)
		end
	else
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
	end
end

function F3DebugOverlay:IsVisible()
	return isVisible
end

function F3DebugOverlay:Show()
	if not isVisible then
		self:Toggle()
	end
end

function F3DebugOverlay:Hide()
	if isVisible then
		self:Toggle()
	end
end

function F3DebugOverlay:Create()
	if screenGui then
		return
	end
	createUI()

	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F3 then
			self:Toggle()
		end
	end)
end

function F3DebugOverlay:Destroy()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
	labels = {}
	fpsHistory = {}
	isVisible = false
end

return F3DebugOverlay
