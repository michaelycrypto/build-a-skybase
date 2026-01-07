--[[
	CloudController.lua
	Roblox-native implementation of Minecraft-style clouds.
	- Uses Roblox Texture objects with tiled UVs (no SurfaceGuis)
	- Automatically scrolls the UV offset to create motion
	- Renders top and underside with independent tinting
	- Respects Workspace.CloudHeightBlock for designers to override the layer height
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local CloudController = {}

local BLOCK_SIZE = Constants.BLOCK_SIZE or 3
local DEFAULT_CLOUD_BLOCK_HEIGHT = 128
local GRID_RADIUS = 16
local GRID_SIZE = GRID_RADIUS * 2 + 1
local CLOUD_TILE_WORLD_SIZE = BLOCK_SIZE * 8
local CLOUD_SPEED = 1 / 8
local CLOUD_TEXTURE = "rbxasset://textures/sky/clouds_new.png"
local TOP_COLOR = Color3.fromRGB(245, 245, 245)
local BOTTOM_COLOR = Color3.fromRGB(230, 234, 246)
local CLOUD_TRANSPARENCY = 0.25
local CLOUD_THICKNESS = 0.2
local BIND_NAME = "CloudControllerRender"
local BIND_PRIORITY = Enum.RenderPriority.Camera.Value + 2

local cloudPlane
local faceTextures = {}

local cloudHeightBlocks = DEFAULT_CLOUD_BLOCK_HEIGHT
local cloudHeightStuds = DEFAULT_CLOUD_BLOCK_HEIGHT * BLOCK_SIZE

local baseOffset = 0
local driftOffset = 0
local offX = 0
local coffX = 0
local lastCX = math.huge
local lastCZ = math.huge

local serverTickConn
local heightAttrConn

local function readCloudHeightAttribute()
	local attr = Workspace:GetAttribute("CloudHeightBlock")
	if typeof(attr) == "number" then
		cloudHeightBlocks = attr
	else
		cloudHeightBlocks = DEFAULT_CLOUD_BLOCK_HEIGHT
	end
	cloudHeightStuds = cloudHeightBlocks * BLOCK_SIZE
end

local function createTexture(faceName, faceEnum)
	local texture = Instance.new("Texture")
	texture.Name = "VoxelCloudTexture_" .. faceName
	texture.Face = faceEnum
	texture.Texture = CLOUD_TEXTURE
	texture.Color3 = faceName == "Bottom" and BOTTOM_COLOR or TOP_COLOR
	texture.Transparency = CLOUD_TRANSPARENCY
	texture.StudsPerTileU = CLOUD_TILE_WORLD_SIZE
	texture.StudsPerTileV = CLOUD_TILE_WORLD_SIZE
	texture.OffsetStudsU = 0
	texture.OffsetStudsV = 0
	texture.Parent = cloudPlane
	faceTextures[faceName] = texture
end

local function ensureSurface()
	if cloudPlane then
		return
	end

	cloudPlane = Instance.new("Part")
	cloudPlane.Name = "VoxelCloudPlane"
	cloudPlane.Anchored = true
	cloudPlane.CanCollide = false
	cloudPlane.Transparency = 1
	cloudPlane.CastShadow = false
	cloudPlane.Size = Vector3.new(GRID_SIZE * CLOUD_TILE_WORLD_SIZE, CLOUD_THICKNESS, GRID_SIZE * CLOUD_TILE_WORLD_SIZE)
	cloudPlane.Parent = Workspace

	createTexture("Top", Enum.NormalId.Top)
	createTexture("Bottom", Enum.NormalId.Bottom)
end

local function updateCloudPlanePosition(cx, cz)
	if not cloudPlane then
		return
	end

	local offsetX = (cx - coffX + offX) * CLOUD_TILE_WORLD_SIZE
	local offsetZ = cz * CLOUD_TILE_WORLD_SIZE
	cloudPlane.CFrame = CFrame.new(offsetX, cloudHeightStuds, offsetZ)
end

local function stepClouds(dt)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end

	local cloudSpace = camera.CFrame.Position / CLOUD_TILE_WORLD_SIZE
	local cx = math.floor(cloudSpace.X)
	local cz = math.floor(cloudSpace.Z)

	driftOffset -= dt * CLOUD_SPEED
	offX = baseOffset + driftOffset
	coffX = math.ceil(offX)

	updateCloudPlanePosition(cx, cz)

	local offsetStudsU = (cloudSpace.X - coffX + offX) * CLOUD_TILE_WORLD_SIZE
	local offsetStudsVTop = cloudSpace.Z * CLOUD_TILE_WORLD_SIZE
	local offsetStudsVBottom = -offsetStudsVTop

	if faceTextures.Top then
		faceTextures.Top.OffsetStudsU = offsetStudsU
		faceTextures.Top.OffsetStudsV = offsetStudsVTop
	end
	if faceTextures.Bottom then
		faceTextures.Bottom.OffsetStudsU = offsetStudsU
		faceTextures.Bottom.OffsetStudsV = offsetStudsVBottom
	end

	lastCX = cx
	lastCZ = cz
end

function CloudController:Initialize()
	if cloudPlane then
		return
	end

	readCloudHeightAttribute()
	heightAttrConn = Workspace:GetAttributeChangedSignal("CloudHeightBlock"):Connect(readCloudHeightAttribute)

	local serverInfo = Workspace:FindFirstChild("ServerInfo")
	local totalTicks = serverInfo and serverInfo:FindFirstChild("TotalTicks")
	if totalTicks and totalTicks:IsA("NumberValue") then
		baseOffset = -(totalTicks.Value / 20 / 8)
		serverTickConn = totalTicks.Changed:Connect(function(value)
			baseOffset = -(value / 20 / 8)
		end)
	end

	ensureSurface()

	local camera = Workspace.CurrentCamera
	if camera then
		local cloudSpace = camera.CFrame.Position / CLOUD_TILE_WORLD_SIZE
		lastCX = math.floor(cloudSpace.X)
		lastCZ = math.floor(cloudSpace.Z)
		updateCloudPlanePosition(lastCX, lastCZ)
	end

	RunService:BindToRenderStep(BIND_NAME, BIND_PRIORITY, stepClouds)
end

function CloudController:Destroy()
	RunService:UnbindFromRenderStep(BIND_NAME)
	if serverTickConn then
		serverTickConn:Disconnect()
		serverTickConn = nil
	end
	if heightAttrConn then
		heightAttrConn:Disconnect()
		heightAttrConn = nil
	end
	if cloudPlane then
		cloudPlane:Destroy()
		cloudPlane = nil
	end
	faceTextures = {}
end

return CloudController

