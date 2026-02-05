--[[
	TutorialWaypoint.lua - Tutorial Waypoint Rendering System

	Renders visual waypoints to guide players to objectives:
	- 3D marker above target location (floating icon/label)
	- On-screen indicator pointing to off-screen targets
	- Distance display

	Used for hub tutorial steps to guide players to NPCs.
]]

local TutorialWaypoint = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Constants
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local BLOCK_SIZE = Constants.BLOCK_SIZE

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- State
local waypointGui = nil
local activeWaypoint = nil
local updateConnection = nil

-- UI Colors
local COLORS = {
	gold = Color3.fromRGB(255, 215, 0),
	green = Color3.fromRGB(34, 197, 94),
	blue = Color3.fromRGB(88, 101, 242),
	purple = Color3.fromRGB(128, 0, 128),
	white = Color3.fromRGB(255, 255, 255),
	background = Color3.fromRGB(15, 23, 42),
}

-- Animation
local ANIMATION = {
	bob = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	pulse = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
}

--[[
	Initialize the waypoint GUI container
]]
function TutorialWaypoint:Initialize()
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
	Convert block coordinates to world coordinates
	@param blockPos: Vector3 - Position in block coordinates
	@return Vector3 - Position in world coordinates
]]
local function blockToWorld(blockPos)
	return Vector3.new(
		blockPos.X * BLOCK_SIZE + BLOCK_SIZE / 2,
		blockPos.Y * BLOCK_SIZE + BLOCK_SIZE / 2,
		blockPos.Z * BLOCK_SIZE + BLOCK_SIZE / 2
	)
end

--[[
	Create the 3D world marker (BillboardGui above target)
	@param config: table - Waypoint configuration
	@param worldPos: Vector3 - World position for the marker
	@return BillboardGui, Part (anchor)
]]
local function createWorldMarker(config, worldPos)
	-- Create invisible anchor part at target position
	-- BillboardGui requires an Adornee to position correctly
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

	-- Container frame
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	-- Marker icon - use block texture if blockId provided, otherwise diamond
	-- Note: ViewportFrame doesn't work in BillboardGui, so we use texture images
	local marker
	local glow
	
	if config.blockId then
		-- Get block definition and its front texture
		local blockDef = BlockRegistry.Blocks[config.blockId]
		local textureName = blockDef and blockDef.textures and (blockDef.textures.front or blockDef.textures.all)
		local textureId = textureName and TextureManager:GetTextureId(textureName)
		
		if textureId then
			-- Use block texture as image (works in BillboardGui)
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
			
			-- Block texture image
			local blockImage = Instance.new("ImageLabel")
			blockImage.Name = "BlockImage"
			blockImage.Size = UDim2.new(1, -8, 1, -8) -- Small padding
			blockImage.Position = UDim2.fromScale(0.5, 0.5)
			blockImage.AnchorPoint = Vector2.new(0.5, 0.5)
			blockImage.BackgroundTransparency = 1
			blockImage.Image = textureId
			blockImage.ScaleType = Enum.ScaleType.Fit
			blockImage.Parent = markerFrame
			
			marker = markerFrame
			
			-- Pulsing glow effect on frame
			glow = Instance.new("UIStroke")
			glow.Color = config.color or COLORS.gold
			glow.Thickness = 3
			glow.Transparency = 0.2
			glow.Parent = markerFrame
		else
			-- Fallback to diamond if no texture found
			marker = Instance.new("ImageLabel")
			marker.Name = "Marker"
			marker.Size = UDim2.fromOffset(40, 40)
			marker.Position = UDim2.fromScale(0.5, 0)
			marker.AnchorPoint = Vector2.new(0.5, 0)
			marker.BackgroundTransparency = 1
			marker.Image = "rbxassetid://6031094678" -- Diamond marker icon
			marker.ImageColor3 = config.color or COLORS.gold
			marker.Parent = container

			glow = Instance.new("UIStroke")
			glow.Color = config.color or COLORS.gold
			glow.Thickness = 2
			glow.Transparency = 0.3
			glow.Parent = marker
		end
	else
		-- Fallback: diamond icon
		marker = Instance.new("ImageLabel")
		marker.Name = "Marker"
		marker.Size = UDim2.fromOffset(40, 40)
		marker.Position = UDim2.fromScale(0.5, 0)
		marker.AnchorPoint = Vector2.new(0.5, 0)
		marker.BackgroundTransparency = 1
		marker.Image = "rbxassetid://6031094678" -- Diamond marker icon
		marker.ImageColor3 = config.color or COLORS.gold
		marker.Parent = container

		-- Pulsing glow effect
		glow = Instance.new("UIStroke")
		glow.Color = config.color or COLORS.gold
		glow.Thickness = 2
		glow.Transparency = 0.3
		glow.Parent = marker
	end

	-- Label background
	local labelBg = Instance.new("Frame")
	labelBg.Name = "LabelBg"
	labelBg.Size = UDim2.new(1, 0, 0, 24)
	labelBg.Position = UDim2.fromOffset(0, 45)
	labelBg.BackgroundColor3 = COLORS.background
	labelBg.BackgroundTransparency = 0.3
	labelBg.Parent = container

	local labelCorner = Instance.new("UICorner")
	labelCorner.CornerRadius = UDim.new(0, 6)
	labelCorner.Parent = labelBg

	-- Label text
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = config.label or "Objective"
	label.TextColor3 = COLORS.white
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
	distanceLabel.TextColor3 = config.color or COLORS.gold
	distanceLabel.TextSize = 12
	distanceLabel.Font = Enum.Font.Gotham
	distanceLabel.Parent = container

	-- Animate marker bobbing (with safety check)
	if marker then
		local startPos = marker.Position
		TweenService:Create(marker, ANIMATION.bob, {
			Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - 8)
		}):Play()
	end

	-- Animate glow pulsing (with safety check)
	if glow then
		TweenService:Create(glow, ANIMATION.pulse, {
			Transparency = 0.7
		}):Play()
	end

	return billboard, anchor
end

--[[
	Create the screen-space indicator (for off-screen targets)
	Simple diamond shape - minimal and non-intrusive
	@param config: table - Waypoint configuration
	@return Frame
]]
local function createScreenIndicator(config)
	local indicator = Instance.new("Frame")
	indicator.Name = "ScreenIndicator"
	indicator.Size = UDim2.fromOffset(24, 24)
	indicator.BackgroundTransparency = 1
	indicator.Visible = false
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.Parent = waypointGui

	-- Diamond shape (rotated square)
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.Size = UDim2.fromOffset(12, 12)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Rotation = 45 -- Tilt to make diamond shape
	diamond.BackgroundColor3 = config.color or COLORS.gold
	diamond.BackgroundTransparency = 0.1
	diamond.BorderSizePixel = 0
	diamond.Parent = indicator

	-- Slight corner rounding for softer look
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = diamond

	-- Subtle glow/border
	local glow = Instance.new("UIStroke")
	glow.Color = config.color or COLORS.gold
	glow.Thickness = 1
	glow.Transparency = 0.3
	glow.Parent = diamond

	return indicator
end

--[[
	Update waypoint position and visibility
]]
local function updateWaypoint()
	if not activeWaypoint then return end

	local targetPos = activeWaypoint.worldPosition
	local marker = activeWaypoint.worldMarker
	local indicator = activeWaypoint.screenIndicator

	-- Get player position
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local playerPos = hrp.Position

	-- Calculate distance
	local distance = (targetPos - playerPos).Magnitude
	local distanceText = string.format("%.0fm", distance / BLOCK_SIZE)

	-- Update world marker distance display
	if marker then
		local distLabel = marker:FindFirstChild("Container") and marker.Container:FindFirstChild("Distance")
		if distLabel then
			distLabel.Text = distanceText
		end
	end

	-- Check if target is on screen
	local camera = workspace.CurrentCamera
	if not camera then return end

	local screenPos, onScreen = camera:WorldToViewportPoint(targetPos)

	if onScreen and screenPos.Z > 0 then
		-- Target is on screen - hide edge indicator (3D marker is visible)
		if indicator then
			indicator.Visible = false
		end
	else
		-- Target is off screen - show diamond indicator at edge
		if indicator then
			indicator.Visible = true

			-- Calculate direction to target
			local viewportSize = camera.ViewportSize
			local centerX = viewportSize.X / 2
			local centerY = viewportSize.Y / 2

			-- Get direction from center to target screen position
			local dirX = screenPos.X - centerX
			local dirY = screenPos.Y - centerY

			-- Handle behind camera (flip direction)
			if screenPos.Z < 0 then
				dirX = -dirX
				dirY = -dirY
			end

			-- Normalize and calculate angle
			local angle = math.atan2(dirY, dirX)

			-- Position diamond at edge of screen with smaller padding
			local padding = 20
			local radius = math.min(centerX - padding, centerY - padding)
			local edgeX = centerX + math.cos(angle) * radius
			local edgeY = centerY + math.sin(angle) * radius

			indicator.Position = UDim2.fromOffset(edgeX, edgeY)
			-- Diamond shape doesn't need rotation - stays tilted at 45 degrees
		end
	end
end

--[[
	Show a waypoint at a world position
	@param config: table - Waypoint configuration
		- worldPosition: Vector3 - Target position in world coordinates
		- blockPosition: Vector3 - Target position in block coordinates (alternative)
		- label: string - Label to display
		- color: Color3 - Color for the waypoint
]]
function TutorialWaypoint:Show(config)
	self:Initialize()
	self:Hide()

	-- Calculate world position
	local worldPos
	if config.worldPosition then
		worldPos = config.worldPosition
	elseif config.blockPosition then
		worldPos = blockToWorld(config.blockPosition)
	else
		warn("TutorialWaypoint: No position provided")
		return
	end

	-- Create waypoint elements
	local worldMarker, anchor = createWorldMarker(config, worldPos)
	local screenIndicator = createScreenIndicator(config)

	activeWaypoint = {
		worldPosition = worldPos,
		worldMarker = worldMarker,
		anchor = anchor,
		screenIndicator = screenIndicator,
		config = config,
	}

	-- Start update loop
	if updateConnection then
		updateConnection:Disconnect()
	end
	updateConnection = RunService.Heartbeat:Connect(updateWaypoint)
end

--[[
	Show a waypoint for an NPC
	@param npcId: string - The NPC's spawn ID
	@param config: table - Additional configuration (label, color)
]]
function TutorialWaypoint:ShowForNPC(npcId, config)
	-- Find the NPC in workspace
	local npcsFolder = workspace:FindFirstChild("NPCs")
	if not npcsFolder then
		warn("TutorialWaypoint: NPCs folder not found")
		return
	end

	local npcModel = npcsFolder:FindFirstChild(npcId)
	if not npcModel then
		-- Try to find by pattern match
		for _, child in ipairs(npcsFolder:GetChildren()) do
			if child.Name:find(npcId) then
				npcModel = child
				break
			end
		end
	end

	if not npcModel then
		warn("TutorialWaypoint: NPC not found:", npcId)
		return
	end

	-- Get NPC position
	local hrp = npcModel:FindFirstChild("HumanoidRootPart")
	local primaryPart = npcModel.PrimaryPart or hrp

	if not primaryPart then
		warn("TutorialWaypoint: NPC has no position part:", npcId)
		return
	end

	self:Show({
		worldPosition = primaryPart.Position,
		label = config.label or npcModel.Name,
		color = config.color,
	})
end

--[[
	Hide the current waypoint
]]
function TutorialWaypoint:Hide()
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
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

--[[
	Check if a waypoint is currently active
	@return boolean
]]
function TutorialWaypoint:IsActive()
	return activeWaypoint ~= nil
end

--[[
	Cleanup
]]
function TutorialWaypoint:Cleanup()
	self:Hide()
	if waypointGui then
		waypointGui:Destroy()
		waypointGui = nil
	end
end

return TutorialWaypoint
