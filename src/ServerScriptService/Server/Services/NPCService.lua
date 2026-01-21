--[[
	NPCService.lua
	Server-side service for spawning and managing hub world NPCs.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local NPCConfig = require(ReplicatedStorage.Configs.NPCConfig)
local NPCSpawnConfig = require(ReplicatedStorage.Configs.NPCSpawnConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local MinecraftBoneTranslator = require(ReplicatedStorage.Shared.Mobs.MinecraftBoneTranslator)

local BLOCK_SIZE = Constants.BLOCK_SIZE
local NPC_SCALE = 0.8
local LOOK_AT_RANGE = 24 -- studs (8 blocks)
local LOOK_AT_SPEED = 4 -- rotation speed

local NPCService = setmetatable({}, BaseService)
NPCService.__index = NPCService

function NPCService.new()
	local self = setmetatable(BaseService.new(), NPCService)
	self.Name = "NPCService"
	self._logger = Logger:CreateContext("NPCService")
	self._activeNPCs = {}
	self._npcFolder = nil
	self._heartbeat = nil
	return self
end

function NPCService:Init()
	if self._initialized then return end
	BaseService.Init(self)
end

function NPCService:Start()
	if self._started then return end

	self._npcFolder = Instance.new("Folder")
	self._npcFolder.Name = "NPCs"
	self._npcFolder.Parent = workspace

	for _, spawnConfig in ipairs(NPCSpawnConfig.GetAllHubSpawns()) do
		self:SpawnNPC(spawnConfig)
	end

	EventManager:RegisterEventHandler("RequestNPCInteract", function(player, data)
		self:HandleNPCInteract(player, data)
	end)

	-- Look-at player loop
	self._heartbeat = RunService.Heartbeat:Connect(function(dt)
		self:UpdateNPCLookAt(dt)
	end)

	BaseService.Start(self)
end

function NPCService:Destroy()
	if self._destroyed then return end

	if self._heartbeat then
		self._heartbeat:Disconnect()
		self._heartbeat = nil
	end

	for _, npcData in pairs(self._activeNPCs) do
		if npcData.model then npcData.model:Destroy() end
	end
	self._activeNPCs = {}

	if self._npcFolder then
		self._npcFolder:Destroy()
		self._npcFolder = nil
	end

	BaseService.Destroy(self)
end

function NPCService:UpdateNPCLookAt(dt)
	local players = Players:GetPlayers()
	if #players == 0 then return end

	for _, npcData in pairs(self._activeNPCs) do
		local root = npcData.model and npcData.model.PrimaryPart
		if not root then continue end

		-- Find nearest player
		local nearestDist = LOOK_AT_RANGE
		local nearestPos = nil

		for _, player in ipairs(players) do
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - npcData.position).Magnitude
				if dist < nearestDist then
					nearestDist = dist
					nearestPos = hrp.Position
				end
			end
		end

		-- Rotate toward player (or back to default)
		local targetAngle = npcData.defaultRotation
		if nearestPos then
			local dir = (nearestPos - npcData.position) * Vector3.new(1, 0, 1)
			if dir.Magnitude > 0.1 then
				targetAngle = math.atan2(-dir.X, -dir.Z)
			end
		end

		-- Smooth rotation
		local currentAngle = npcData.currentRotation or npcData.defaultRotation
		local diff = (targetAngle - currentAngle + math.pi) % (2 * math.pi) - math.pi
		local newAngle = currentAngle + math.clamp(diff, -LOOK_AT_SPEED * dt, LOOK_AT_SPEED * dt)
		npcData.currentRotation = newAngle

		root.CFrame = CFrame.new(npcData.position + npcData.rootOffset) * CFrame.Angles(0, newAngle, 0)
	end
end

function NPCService:SpawnNPC(spawnConfig)
	if self._activeNPCs[spawnConfig.id] then
		return self._activeNPCs[spawnConfig.id]
	end

	local npcTypeDef = NPCConfig.GetNPCTypeDef(spawnConfig.npcType)
	if not npcTypeDef then return nil end

	local blockPos = spawnConfig.blockPosition
	if not blockPos then return nil end

	local worldPosition = Vector3.new(
		(blockPos.X + 0.5) * BLOCK_SIZE,
		(blockPos.Y + 1) * BLOCK_SIZE,
		(blockPos.Z + 0.5) * BLOCK_SIZE
	)

	-- Get rootOffset from model spec
	local outfitColor = MinecraftBoneTranslator.NPCColors[spawnConfig.npcType] or Color3.fromRGB(100, 100, 100)
	local modelSpec = MinecraftBoneTranslator.BuildNPCModel(NPC_SCALE, outfitColor, spawnConfig.npcType)
	local rootOffset = modelSpec.rootOffset or Vector3.new(0, 0, 0)

	local model = self:CreateNPCModel(spawnConfig, npcTypeDef, worldPosition, modelSpec)
	if not model then return nil end

	local rotation = math.rad(spawnConfig.rotation or 0)
	self._activeNPCs[spawnConfig.id] = {
		model = model,
		position = worldPosition,
		rootOffset = rootOffset,
		config = npcTypeDef,
		npcType = spawnConfig.npcType,
		defaultRotation = rotation,
		currentRotation = rotation,
	}

	return self._activeNPCs[spawnConfig.id]
end

function NPCService:CreateMotor(part0, part1, name, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name = name or (part1.Name .. "Motor")
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0 or CFrame.new()
	motor.C1 = c1 or CFrame.new()
	motor.Parent = part0
	return motor
end

function NPCService:CreateNPCModel(spawnConfig, npcTypeDef, worldPosition, modelSpec)
	local model = Instance.new("Model")
	model.Name = "NPC_" .. spawnConfig.id

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.5, 0.5, 0.5)
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.Parent = model
	model.PrimaryPart = root

	local rotation = math.rad(spawnConfig.rotation or 0)
	local rootOffset = modelSpec.rootOffset or Vector3.new(0, 0, 0)
	root.CFrame = CFrame.new(worldPosition + rootOffset) * CFrame.Angles(0, rotation, 0)

	local parts = {}
	local baseCFrame = root.CFrame

	if modelSpec.parts then
		for name, partDef in pairs(modelSpec.parts) do
			local part = Instance.new("Part")
			part.Name = partDef.tag or name
			part.Size = partDef.size or Vector3.new(1, 1, 1)
			part.Color = partDef.color or Color3.new(1, 1, 1)
			part.Material = partDef.material or Enum.Material.SmoothPlastic
			part.Transparency = partDef.transparency or 0
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CFrame = baseCFrame * (partDef.cframe or CFrame.new())
			part.Parent = model
			parts[part.Name] = part
		end

		for name, partDef in pairs(modelSpec.parts) do
			local part = parts[partDef.tag or name]
			if not part then continue end

			local parentPart = root
			if partDef.parent and parts[partDef.parent] then
				parentPart = parts[partDef.parent]
			end

			self:CreateMotor(parentPart, part, partDef.motorName or (part.Name .. "Motor"),
				partDef.c0 or partDef.cframe or CFrame.new(), partDef.c1 or partDef.jointC1)
		end
	end

	-- Billboard name tag
	local headPart = parts["Head"] or root
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "NameTag"
	billboard.Size = UDim2.new(0, 300, 0, 70)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.Adornee = headPart
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 48
	billboard.Parent = headPart

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = billboard

	local nameColor = npcTypeDef.nameTagColor or Color3.new(1, 1, 1)
	local shadowColor = Color3.new(nameColor.R * 0.6, nameColor.G * 0.6, nameColor.B * 0.6)

	-- Shadow
	local shadow = Instance.new("TextLabel")
	shadow.Name = "NameShadow"
	shadow.Size = UDim2.new(1, 0, 0, 40)
	shadow.Position = UDim2.new(0, 0, 0, 2)
	shadow.BackgroundTransparency = 1
	shadow.Text = npcTypeDef.displayName
	shadow.TextColor3 = shadowColor
	shadow.TextStrokeTransparency = 1
	shadow.Font = Enum.Font.GothamBold
	shadow.TextSize = 32
	shadow.TextXAlignment = Enum.TextXAlignment.Center
	shadow.TextYAlignment = Enum.TextYAlignment.Center
	shadow.ZIndex = 1
	shadow.Parent = container

	-- Name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 40)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = npcTypeDef.displayName
	nameLabel.TextColor3 = nameColor
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 32
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.ZIndex = 2
	nameLabel.Parent = container

	-- Description
	local desc = Instance.new("TextLabel")
	desc.Name = "SubtitleLabel"
	desc.Size = UDim2.new(1, 0, 0, 26)
	desc.Position = UDim2.new(0, 0, 0, 42)
	desc.BackgroundTransparency = 1
	desc.Text = npcTypeDef.description
	desc.TextColor3 = Color3.new(1, 1, 1)
	desc.TextStrokeTransparency = 0.3
	desc.TextStrokeColor3 = Color3.new(0, 0, 0)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 20
	desc.TextXAlignment = Enum.TextXAlignment.Center
	desc.TextYAlignment = Enum.TextYAlignment.Center
	desc.Parent = container

	model:SetAttribute("NPCId", spawnConfig.id)
	model:SetAttribute("NPCType", spawnConfig.npcType)
	model.Parent = self._npcFolder

	return model
end

function NPCService:HandleNPCInteract(player, data)
	if not data or not data.npcId then return end

	local npcData = self._activeNPCs[data.npcId]
	if not npcData then return end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	if (rootPart.Position - npcData.position).Magnitude > NPCConfig.INTERACTION_RADIUS then
		return
	end

	-- Play interaction sound
	EventManager:FireEvent("PlaySound", player, { sound = "ui_click" })

	EventManager:FireEvent("NPCInteraction", player, {
		npcId = data.npcId,
		npcType = npcData.npcType,
		interactionType = npcData.config.interactionType,
	})
end

return NPCService
