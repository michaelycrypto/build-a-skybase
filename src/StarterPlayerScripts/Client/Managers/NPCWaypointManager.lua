--[[
	NPCWaypointManager.lua - Client-side NPC Waypoint Markers

	Creates diamond-shaped waypoint markers above NPCs in the hub world
	to help players easily locate them. Markers use the NPC's nameTagColor
	and show the NPC type description.

	Features:
	- Diamond markers above each NPC in the hub
	- Color-coded by NPC type
	- Bobbing animation
	- Pulsing glow effect
	- Auto-hides when close to NPC
	- Only shows in hub world
]]

local NPCWaypointManager = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies
local NPCConfig = require(ReplicatedStorage.Configs.NPCConfig)
local ServerRoleDetector = require(ReplicatedStorage.Shared.ServerRoleDetector)

-- State
local isInitialized = false
local isInHub = false
local activeMarkers = {} -- {npcId = {billboard, anchor}}
local updateConnection = nil

-- Player reference
local player = Players.LocalPlayer

-- Constants
local MARKER_OFFSET = Vector3.new(0, 10, 0) -- Height above NPC root (above nametag)
local HIDE_DISTANCE = 15 -- Hide marker when this close to NPC
local SHOW_DISTANCE = 18 -- Show marker again when this far
local MAX_DISTANCE = 200 -- Max distance to show markers

-- Animation tweens
local BOB_TWEEN_INFO = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local PULSE_TWEEN_INFO = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

-- Colors
local COLORS = {
	background = Color3.fromRGB(15, 23, 42),
	white = Color3.fromRGB(255, 255, 255),
}

--[[
	Create a diamond waypoint marker for an NPC
	@param npcModel: Model - The NPC model
	@param npcTypeDef: table - The NPC type definition from NPCConfig
	@return billboard: BillboardGui, anchor: Part
]]
local function createMarker(npcModel, npcTypeDef)
	local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("Root") or npcModel:FindFirstChild("HumanoidRootPart")
	if not primaryPart then
		warn("[NPCWaypointManager] NPC has no primary part:", npcModel.Name)
		return nil, nil
	end

	local markerColor = npcTypeDef.nameTagColor or Color3.fromRGB(255, 215, 0)

	-- Create invisible anchor part that follows NPC
	local anchor = Instance.new("Part")
	anchor.Name = "NPCWaypointAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Position = primaryPart.Position + MARKER_OFFSET
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Parent = workspace

	-- Create billboard GUI
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NPCWaypointMarker"
	billboard.Size = UDim2.fromOffset(60, 60)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = MAX_DISTANCE
	billboard.Adornee = anchor
	billboard.Parent = workspace

	-- Container frame
	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	-- Diamond marker (rotated square)
	local diamondFrame = Instance.new("Frame")
	diamondFrame.Name = "Diamond"
	diamondFrame.Size = UDim2.fromOffset(20, 20)
	diamondFrame.Position = UDim2.fromScale(0.5, 0.3)
	diamondFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	diamondFrame.Rotation = 45
	diamondFrame.BackgroundColor3 = markerColor
	diamondFrame.BackgroundTransparency = 0.1
	diamondFrame.BorderSizePixel = 0
	diamondFrame.Parent = container

	-- Rounded corners for diamond
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = diamondFrame

	-- Glow stroke
	local glow = Instance.new("UIStroke")
	glow.Name = "Glow"
	glow.Color = markerColor
	glow.Thickness = 2
	glow.Transparency = 0.2
	glow.Parent = diamondFrame

	-- Inner diamond (creates layered effect)
	local innerDiamond = Instance.new("Frame")
	innerDiamond.Name = "InnerDiamond"
	innerDiamond.Size = UDim2.fromOffset(10, 10)
	innerDiamond.Position = UDim2.fromScale(0.5, 0.5)
	innerDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
	innerDiamond.BackgroundColor3 = COLORS.white
	innerDiamond.BackgroundTransparency = 0.3
	innerDiamond.BorderSizePixel = 0
	innerDiamond.Parent = diamondFrame

	local innerCorner = Instance.new("UICorner")
	innerCorner.CornerRadius = UDim.new(0, 2)
	innerCorner.Parent = innerDiamond

	-- Start bobbing animation
	local startPos = diamondFrame.Position
	local bobTween = TweenService:Create(diamondFrame, BOB_TWEEN_INFO, {
		Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset - 6)
	})
	bobTween:Play()

	-- Start pulsing glow animation
	local pulseTween = TweenService:Create(glow, PULSE_TWEEN_INFO, { Transparency = 0.6 })
	pulseTween:Play()

	return billboard, anchor
end

--[[
	Update marker positions and visibility based on player distance
]]
local function updateMarkers()
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local playerPos = hrp.Position

	for npcId, markerData in pairs(activeMarkers) do
		local billboard = markerData.billboard
		local anchor = markerData.anchor
		local npcModel = markerData.npcModel

		if billboard and anchor and npcModel and npcModel.Parent then
			local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("Root")
			if primaryPart then
				-- Update anchor position to follow NPC
				anchor.Position = primaryPart.Position + MARKER_OFFSET

				-- Calculate distance to NPC
				local distance = (playerPos - primaryPart.Position).Magnitude

				-- Hide when close, show when far (with hysteresis to prevent flickering)
				if distance < HIDE_DISTANCE then
					billboard.Enabled = false
				elseif distance > SHOW_DISTANCE then
					billboard.Enabled = true
				end
				-- Between HIDE_DISTANCE and SHOW_DISTANCE, keep current state
			end
		end
	end
end

--[[
	Create markers for all NPCs in the hub
]]
local function createAllMarkers()
	local npcFolder = workspace:FindFirstChild("NPCs")
	if not npcFolder then
		warn("[NPCWaypointManager] NPCs folder not found in workspace")
		return
	end

	for _, npcModel in ipairs(npcFolder:GetChildren()) do
		if npcModel:IsA("Model") then
			local npcType = npcModel:GetAttribute("NPCType")
			local npcId = npcModel:GetAttribute("NPCId")

			if npcType and npcId then
				local npcTypeDef = NPCConfig.GetNPCTypeDef(npcType)
				if npcTypeDef then
					local billboard, anchor = createMarker(npcModel, npcTypeDef)
					if billboard and anchor then
						activeMarkers[npcId] = {
							billboard = billboard,
							anchor = anchor,
							npcModel = npcModel,
						}
					end
				end
			end
		end
	end

	-- Listen for new NPCs being added
	npcFolder.ChildAdded:Connect(function(npcModel)
		if npcModel:IsA("Model") then
			-- Wait for attributes to be set
			task.wait(0.1)

			local npcType = npcModel:GetAttribute("NPCType")
			local npcId = npcModel:GetAttribute("NPCId")

			if npcType and npcId and not activeMarkers[npcId] then
				local npcTypeDef = NPCConfig.GetNPCTypeDef(npcType)
				if npcTypeDef then
					local billboard, anchor = createMarker(npcModel, npcTypeDef)
					if billboard and anchor then
						activeMarkers[npcId] = {
							billboard = billboard,
							anchor = anchor,
							npcModel = npcModel,
						}
					end
				end
			end
		end
	end)
end

--[[
	Remove all markers
]]
local function removeAllMarkers()
	for npcId, markerData in pairs(activeMarkers) do
		if markerData.billboard then
			markerData.billboard:Destroy()
		end
		if markerData.anchor then
			markerData.anchor:Destroy()
		end
	end
	activeMarkers = {}
end

--[[
	Enable markers (when entering hub)
]]
local function enableMarkers()
	if not isInHub then
		isInHub = true
		createAllMarkers()

		-- Start update loop
		if not updateConnection then
			updateConnection = RunService.Heartbeat:Connect(updateMarkers)
		end
	end
end

--[[
	Disable markers (when leaving hub)
]]
local function disableMarkers()
	if isInHub then
		isInHub = false
		removeAllMarkers()

		-- Stop update loop
		if updateConnection then
			updateConnection:Disconnect()
			updateConnection = nil
		end
	end
end

--[[
	Initialize the NPCWaypointManager
	@param deps: table - Dependencies (optional)
]]
function NPCWaypointManager:Initialize(deps)
	if isInitialized then return end

	-- Only enable in hub world
	if not ServerRoleDetector.IsHub() then
		isInitialized = true
		return
	end

	-- Wait for NPCs folder to exist and create markers
	task.spawn(function()
		local npcFolder = workspace:WaitForChild("NPCs", 10)
		if npcFolder then
			task.wait(0.5) -- Wait for NPCs to be created
			enableMarkers()
		end
	end)

	isInitialized = true
end

--[[
	Clean up the manager
]]
function NPCWaypointManager:Cleanup()
	disableMarkers()
	isInitialized = false
end

--[[
	Check if markers are currently active
	@return boolean
]]
function NPCWaypointManager:IsActive()
	return isInHub
end

--[[
	Get the number of active markers
	@return number
]]
function NPCWaypointManager:GetMarkerCount()
	local count = 0
	for _ in pairs(activeMarkers) do
		count = count + 1
	end
	return count
end

return NPCWaypointManager
