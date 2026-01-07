--[[
	BlockBreakOverlayController.lua
	Shows Minecraft-style crack overlays on blocks being broken.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockBreakFeedbackConfig = require(ReplicatedStorage.Configs.BlockBreakFeedbackConfig)

local BlockBreakOverlayController = {}

local overlays = {}
local overlayFolder = nil
local STALE_TIMEOUT = 0.6
local faces = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
	Enum.NormalId.Bottom,
}
local faceNormals = {
	[Enum.NormalId.Front] = Vector3.new(0, 0, -1),
	[Enum.NormalId.Back] = Vector3.new(0, 0, 1),
	[Enum.NormalId.Left] = Vector3.new(-1, 0, 0),
	[Enum.NormalId.Right] = Vector3.new(1, 0, 0),
	[Enum.NormalId.Top] = Vector3.new(0, 1, 0),
	[Enum.NormalId.Bottom] = Vector3.new(0, -1, 0),
}

local function ensureFolder()
	if overlayFolder and overlayFolder.Parent then
		return overlayFolder
	end
	overlayFolder = Instance.new("Folder")
	overlayFolder.Name = "BlockBreakOverlays"
	overlayFolder.Parent = Workspace
	return overlayFolder
end

local function blockKey(x, y, z)
	return string.format("%d,%d,%d", x, y, z)
end

local function blockCenter(x, y, z)
	local bs = Constants.BLOCK_SIZE
	return Vector3.new(
		x * bs + bs * 0.5,
		y * bs + bs * 0.5,
		z * bs + bs * 0.5
	)
end

local function destroyOverlay(key)
	local entry = overlays[key]
	if not entry then return end
	if entry.part then
		entry.part:Destroy()
	end
	overlays[key] = nil
end

local function ensureOverlay(key, position)
	local existing = overlays[key]
	if existing then
		existing.part.CFrame = CFrame.new(position)
		return existing
	end

	local folder = ensureFolder()
	local part = Instance.new("Part")
	part.Name = "BreakOverlay"
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(Constants.BLOCK_SIZE, Constants.BLOCK_SIZE, Constants.BLOCK_SIZE)
	part.CFrame = CFrame.new(position)
	part.Parent = folder

	local faceImages = {}
	for _, face in ipairs(faces) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Face" .. face.Name
		gui.Face = face
		gui.Adornee = part
		gui.Parent = part
		gui.AlwaysOnTop = true
		gui.Brightness = 0
		gui.LightInfluence = 0
		gui.CanvasSize = Vector2.new(256, 256)

		local image = Instance.new("ImageLabel")
		image.Name = "Stage"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.ImageTransparency = 1
		image.Parent = gui
		faceImages[face] = image
	end

	local entry = {
		part = part,
		images = faceImages,
		stage = -1,
		lastUpdate = os.clock(),
		activeFace = nil,
	}
	overlays[key] = entry
	return entry
end

local function pickFacingFace(position)
	local camera = Workspace.CurrentCamera
	if not camera then
		return Enum.NormalId.Front
	end
	local dir = camera.CFrame.Position - position
	if dir.Magnitude < 1e-3 then
		return Enum.NormalId.Front
	end
	dir = dir.Unit
	local bestFace = Enum.NormalId.Front
	local bestDot = -math.huge
	for face, normal in pairs(faceNormals) do
		local dot = normal:Dot(dir)
		if dot > bestDot then
			bestDot = dot
			bestFace = face
		end
	end
	return bestFace
end

local function applyStage(entry, stageIndex, face)
	entry.stage = stageIndex
	entry.lastUpdate = os.clock()
	if face then
		entry.activeFace = face
	end
	local activeFace = entry.activeFace or Enum.NormalId.Front
	local assetId = BlockBreakFeedbackConfig.DestroyStages[stageIndex + 1]
	for faceEnum, image in pairs(entry.images) do
		if assetId and stageIndex >= 0 and faceEnum == activeFace then
			image.Image = assetId
			image.ImageTransparency = 0
		else
			image.ImageTransparency = 1
		end
	end
end

local function handleProgress(data)
	if not data or data.x == nil or data.y == nil or data.z == nil then
		return
	end

	local progress = tonumber(data.progress) or 0
	if progress <= 0 then
		destroyOverlay(blockKey(data.x, data.y, data.z))
		return
	end

	local key = blockKey(data.x, data.y, data.z)
	local entry = ensureOverlay(key, blockCenter(data.x, data.y, data.z))
	local stageIndex = math.clamp(math.floor(progress * 9 + 0.5), 0, 9)
	local facingFace = pickFacingFace(entry.part.Position)

	if entry.stage ~= stageIndex then
		applyStage(entry, stageIndex, facingFace)
	else
		if facingFace and entry.activeFace ~= facingFace then
			applyStage(entry, stageIndex, facingFace)
		end
		entry.lastUpdate = os.clock()
	end
end

local function handleBroken(data)
	if not data or data.x == nil or data.y == nil or data.z == nil then
		return
	end
	destroyOverlay(blockKey(data.x, data.y, data.z))
end

function BlockBreakOverlayController:Initialize()
	if self._initialized then
		return
	end
	self._initialized = true

	ensureFolder()
	EventManager:RegisterEvent("BlockBreakProgress", handleProgress)
	EventManager:RegisterEvent("BlockBroken", handleBroken)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for key, entry in pairs(overlays) do
			if (now - entry.lastUpdate) > STALE_TIMEOUT then
				destroyOverlay(key)
			end
		end
	end)
end

return BlockBreakOverlayController

