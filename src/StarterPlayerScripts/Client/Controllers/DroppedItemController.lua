--[[
	DroppedItemController.lua
	Items use real Roblox physics and collide with the voxel world
	Server provides spawn position and velocity, client simulates physics
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)

local player = Players.LocalPlayer
local items = {}
local pickupRequests = {} -- Track pickup requests to prevent spam {[itemId] = requestTime}

local DroppedItemController = {}

-- Animation constants (Minecraft-style)
local ROTATION_SPEED = 1.5 -- Smooth, slower rotation like Minecraft
local BOB_AMPLITUDE = 0.15 -- More noticeable bobbing
local BOB_SPEED = 2 -- How fast items bob up and down
local PICKUP_REQUEST_COOLDOWN = 1.0 -- Prevent spam-requesting the same item

-- Minecraft's layering system for dropped items
local function GetLayerCount(itemCount)
	if itemCount <= 1 then return 1
	elseif itemCount <= 16 then return 2
	elseif itemCount <= 32 then return 3
	else return 4 -- 33-64+ items
	end
end

-- Subtle offsets for "scattered pile" effect (in studs)
local LAYER_OFFSET_Y = 0.08 -- Vertical offset per layer (very subtle)
local LAYER_OFFSET_XZ = 0.05 -- Horizontal scatter per layer

function DroppedItemController:Initialize()
	-- Listen for server events
	EventManager:RegisterEvent("ItemSpawned", function(data)
		self:OnItemSpawned(data)
	end)

	EventManager:RegisterEvent("ItemRemoved", function(data)
		self:OnItemRemoved(data)
	end)

	EventManager:RegisterEvent("ItemUpdated", function(data)
		self:OnItemUpdated(data)
	end)

	EventManager:RegisterEvent("ItemPickedUp", function(data)
		self:OnItemPickedUp(data)
	end)

	-- Start physics simulation loop
	self:StartUpdateLoop()
end

function DroppedItemController:StartUpdateLoop()
	local lastPickupCheck = 0

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()

		-- Animate all items
		for id, item in pairs(items) do
			self:UpdateVisuals(item, dt, now)
		end

		-- Check for pickup (5Hz)
		if now - lastPickupCheck >= 0.2 then
			self:CheckPickup()
			lastPickupCheck = now
		end
	end)
end

function DroppedItemController:UpdateVisuals(item, dt, now)
	if not item.model or not item.model.PrimaryPart then return end

	local part = item.model.PrimaryPart

	-- Handle merge animation
	if item.merging and item.mergeStartTime and now >= item.mergeStartTime then
		local targetItem = items[item.mergeTargetId]
		local targetPos = item.mergeTargetPos

		-- If target no longer exists, just clean up this item
		if not targetItem then
			item.model:Destroy()
			items[item.id] = nil
			pickupRequests[item.id] = nil
			return
		end

		-- Use target's current position for accurate tracking
		if targetItem.model and targetItem.model.PrimaryPart then
			targetPos = targetItem.finalPosition or targetItem.model.PrimaryPart.Position
		end

		-- Anchor the item and move it towards target
		part.Anchored = true
		part.CanCollide = false

		local currentPos = part.Position
		local direction = (targetPos - currentPos)
		local distance = direction.Magnitude

		-- Move towards target (fast acceleration)
		local speed = 15 -- Fast merge speed
		local moveDistance = math.min(speed * dt, distance)
		local newPos = currentPos + direction.Unit * moveDistance

		-- Rotate faster during merge
		item.rotation = item.rotation + dt * ROTATION_SPEED * 3
		item.model:SetPrimaryPartCFrame(CFrame.new(newPos) * CFrame.Angles(0, item.rotation, 0))

		-- When close enough, play merge effect and destroy
		if distance < 1 then
			-- Burst particles
			local particles = part:FindFirstChild("SpawnEffect")
			if particles then
				particles.Color = ColorSequence.new(Color3.new(0, 1, 0))
				particles:Emit(15)
			end

			-- Remove the merging item completely
			item.model:Destroy()
			items[item.id] = nil
			pickupRequests[item.id] = nil
		end

		return
	end

	-- Rotation
	item.rotation = item.rotation + dt * ROTATION_SPEED

	-- Check if item has settled (velocity near zero)
	if not item.settled and now - item.lastVelocityCheck >= 0.1 then
		item.lastVelocityCheck = now
		local velocity = part.AssemblyLinearVelocity
		if velocity.Magnitude < 0.5 then
			item.settled = true
			-- Float 0.25 studs above ground for floating effect
			item.finalPosition = part.Position + Vector3.new(0, 0.25, 0)
			-- Anchor and disable collision once settled
			part.Anchored = true
			part.CanCollide = false
		end
	end

	-- Apply rotation and optional bobbing (Minecraft-style)
	if item.settled then
		-- Bobbing (more noticeable like Minecraft)
		local bobOffset = math.sin(now * BOB_SPEED) * BOB_AMPLITUDE
		local visualPos = item.finalPosition + Vector3.new(0, bobOffset, 0)

		-- Apply rotation to entire model (all parts rotate together)
		item.model:SetPrimaryPartCFrame(CFrame.new(visualPos) * CFrame.Angles(0, item.rotation, 0))
	else
		-- While falling, rotate gently around current position (physics handles movement)
		local currentPos = part.Position
		part.CFrame = CFrame.new(currentPos) * CFrame.Angles(0, item.rotation, 0)
	end

	-- Despawn warning flash (last 15 seconds)
	local age = now - item.spawnTime
	if age > 285 then
		local flashRate = 4
		local alpha = math.sin(now * flashRate * math.pi)

		local highlight = part:FindFirstChildOfClass("Highlight")
		if highlight then
			highlight.Enabled = alpha > 0
		end

		part.Transparency = alpha > 0 and 0 or 0.3
	end
end

function DroppedItemController:CreateModel(itemId, count)
	local blockInfo = BlockRegistry:GetBlock(itemId)
	local model = Instance.new("Model")
	model.Name = "DroppedItem"

	local layerCount = GetLayerCount(count)
	local isCrossShape = blockInfo and blockInfo.crossShape == true

	-- Layer offsets for Minecraft-style scattered pile
	local layerOffsets = {
		{x = 0, y = 0, z = 0},
		{x = -LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y, z = LAYER_OFFSET_XZ},
		{x = LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y * 2, z = -LAYER_OFFSET_XZ},
		{x = 0, y = LAYER_OFFSET_Y * 3, z = LAYER_OFFSET_XZ},
	}

	-- Create layered parts - 2D sprites for plants, 3D cubes for blocks
	for i = 1, layerCount do
		local part = Instance.new("Part")
		part.Name = "ItemPart_" .. i

		-- Cross-shaped plants: larger 2D sprite, Regular blocks: 3D cube
		if isCrossShape then
			part.Size = Vector3.new(1.0, 1.0, 0.05) -- Larger flat sprite
			part.Transparency = 1 -- Fully transparent, only texture shows
			part.CastShadow = false
		else
			part.Size = Vector3.new(0.75, 0.75, 0.75) -- 3D cube
			part.Transparency = 0
			part.CastShadow = true
		end

		part.Material = blockInfo and blockInfo.material or Enum.Material.SmoothPlastic
		part.Color = blockInfo and blockInfo.color or Color3.new(0.8, 0.8, 0.8)

		local offset = layerOffsets[i]
		part.CFrame = CFrame.new(offset.x, offset.y, offset.z)

		if i == 1 then
			part.Anchored = false
			part.CanCollide = true
			part.CustomPhysicalProperties = PhysicalProperties.new(0.4, 0.3, 0.4, 1, 1)
			model.PrimaryPart = part
		else
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end

		part.Parent = model

		-- Apply textures based on block type
		if isCrossShape then
			-- 2D sprite: Apply texture to front and back faces only
			local textureId
			if blockInfo and blockInfo.textures then
				textureId = TextureManager:GetTextureId(blockInfo.textures.all)
			end

			if textureId then
				-- Front face
				local frontTexture = Instance.new("Texture")
				frontTexture.Face = Enum.NormalId.Front
				frontTexture.Texture = textureId
				frontTexture.StudsPerTileU = 1.0
				frontTexture.StudsPerTileV = 1.0
				frontTexture.Parent = part

				-- Back face (same texture)
				local backTexture = Instance.new("Texture")
				backTexture.Face = Enum.NormalId.Back
				backTexture.Texture = textureId
				backTexture.StudsPerTileU = 1.0
				backTexture.StudsPerTileV = 1.0
				backTexture.Parent = part
			end
		else
			-- 3D cube: Apply textures to all 6 faces
			local faces = {
				{normalId = Enum.NormalId.Top, faceName = "top"},
				{normalId = Enum.NormalId.Bottom, faceName = "bottom"},
				{normalId = Enum.NormalId.Right, faceName = "side"},
				{normalId = Enum.NormalId.Left, faceName = "side"},
				{normalId = Enum.NormalId.Front, faceName = "side"},
				{normalId = Enum.NormalId.Back, faceName = "side"},
			}

			for _, faceInfo in ipairs(faces) do
				local textureId = TextureManager:GetTextureForBlockFace(itemId, faceInfo.faceName)
				if textureId then
					local texture = Instance.new("Texture")
					texture.Face = faceInfo.normalId
					texture.Texture = textureId
					texture.StudsPerTileU = 0.75
					texture.StudsPerTileV = 0.75
					texture.Parent = part
				end
			end
		end
	end

	-- Weld all layers together
	for i = 2, layerCount do
		local part = model:FindFirstChild("ItemPart_" .. i)
		if part and model.PrimaryPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = model.PrimaryPart
			weld.Part1 = part
			weld.Parent = part
		end
	end

	-- Spawn particles
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "SpawnEffect"
	particles.Texture = "rbxasset://textures/particles/smoke_main.dds"
	particles.Color = ColorSequence.new(blockInfo and blockInfo.color or Color3.new(1, 1, 1))
	particles.Size = NumberSequence.new(0.4, 0.1)
	particles.Transparency = NumberSequence.new(0.3, 1)
	particles.Lifetime = NumberRange.new(0.4, 0.7)
	particles.Rate = 0
	particles.Speed = NumberRange.new(1, 3)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Parent = model.PrimaryPart
	particles:Emit(10)

	model.Parent = workspace

	-- Pop-in animation
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local isCrossShape = blockInfo and blockInfo.crossShape == true
	for _, stackPart in ipairs(model:GetChildren()) do
		if stackPart:IsA("BasePart") then
			if isCrossShape then
				-- 2D sprite animation (maintain thin depth)
				stackPart.Size = Vector3.new(0.1, 0.1, 0.05)
				TweenService:Create(stackPart, tweenInfo, {Size = Vector3.new(1.0, 1.0, 0.05)}):Play()
			else
				-- 3D cube animation
				stackPart.Size = Vector3.new(0.1, 0.1, 0.1)
				TweenService:Create(stackPart, tweenInfo, {Size = Vector3.new(0.75, 0.75, 0.75)}):Play()
			end
		end
	end

	return model
end

function DroppedItemController:OnItemSpawned(data)
	if not data or not data.id then return end
	if items[data.id] then return end

	local model = self:CreateModel(data.itemId, data.count)
	local startPos = Vector3.new(data.startPos[1], data.startPos[2], data.startPos[3])
	local velocity = Vector3.new(data.velocity[1], data.velocity[2], data.velocity[3])

	model:SetPrimaryPartCFrame(CFrame.new(startPos))
	model.PrimaryPart.AssemblyLinearVelocity = velocity

	local item = {
		id = data.id,
		model = model,
		itemId = data.itemId,
		count = data.count,
		finalPosition = startPos,
		rotation = 0,
		spawnTime = os.clock(),
		settled = false,
		lastVelocityCheck = os.clock()
	}

	-- Check if this item should merge into another
	if data.mergeIntoId and data.mergeIntoPos then
		item.merging = true
		item.mergeTargetId = data.mergeIntoId
		item.mergeTargetPos = Vector3.new(data.mergeIntoPos[1], data.mergeIntoPos[2], data.mergeIntoPos[3])
		item.mergeStartTime = os.clock() + 0.3 -- Start merging after 0.3 seconds
	end

	items[data.id] = item
end

function DroppedItemController:OnItemRemoved(data)
	if not data or not data.id then return end

	local item = items[data.id]
	if not item then return end

	-- Despawn animation
	if item.model and item.model.PrimaryPart then
		local part = item.model.PrimaryPart

		-- Poof particles
		local particles = part:FindFirstChild("SpawnEffect")
		if particles then
			particles.Color = ColorSequence.new(Color3.new(0.7, 0.7, 0.7))
			particles:Emit(10)
		end

		-- Shrink
		TweenService:Create(
			part,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.In, 0, false, 0),
			{Size = Vector3.new(0.1, 0.1, 0.1), Transparency = 1}
		):Play()

		task.delay(0.2, function()
			if item.model then
				item.model:Destroy()
			end
		end)
	end

	-- Clean up tracking data (prevent memory leaks)
	items[data.id] = nil
	pickupRequests[data.id] = nil

	-- Clean up any merging items targeting this removed item
	for id, otherItem in pairs(items) do
		if otherItem.merging and otherItem.mergeTargetId == data.id then
			-- Target was removed, clean up the merging item immediately
			if otherItem.model then
				otherItem.model:Destroy()
			end
			items[id] = nil
			pickupRequests[id] = nil
		end
	end
end

function DroppedItemController:OnItemUpdated(data)
	if not data or not data.id then return end

	local item = items[data.id]
	if not item then return end

	local oldCount = item.count
	local newCount = data.count
	item.count = newCount

	-- Calculate layer counts using Minecraft's logic
	local oldLayerCount = GetLayerCount(oldCount)
	local newLayerCount = GetLayerCount(newCount)

	-- Check if we need to rebuild the visual stack
	if oldLayerCount ~= newLayerCount and item.model and item.model.PrimaryPart then
		local oldPart = item.model.PrimaryPart
		local oldPosition = oldPart.Position
		local oldVelocity = oldPart.AssemblyLinearVelocity
		local wasAnchored = oldPart.Anchored
		local wasSettled = item.settled
		local oldFinalPosition = item.finalPosition

		-- Destroy old model
		item.model:Destroy()

		-- Create new model with updated visual stack
		local newModel = self:CreateModel(item.itemId, newCount)
		local newPart = newModel.PrimaryPart

		-- Restore position using SetPrimaryPartCFrame to maintain weld offsets
		newModel:SetPrimaryPartCFrame(CFrame.new(oldPosition))

		-- Restore physics state
		if not wasAnchored then
			newPart.AssemblyLinearVelocity = oldVelocity
		else
			newPart.Anchored = true
			newPart.CanCollide = false
		end

		-- Restore settled state if it was settled
		if wasSettled and oldFinalPosition then
			item.finalPosition = oldFinalPosition
		end

		-- Update item reference
		item.model = newModel
	end
end

function DroppedItemController:CheckPickup()
	local char = player.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local now = os.clock()

	-- Find nearest item (only pick up settled ones, ignore merging items)
	for id, item in pairs(items) do
		if item.settled and not item.merging and item.model and item.model.PrimaryPart then
			local itemPos = item.model.PrimaryPart.Position
			local dist = (itemPos - root.Position).Magnitude

			if dist <= 3 then
				-- Anti-duplication: Check if we've already requested this item recently
				local lastRequest = pickupRequests[id]
				if lastRequest and (now - lastRequest) < PICKUP_REQUEST_COOLDOWN then
					-- Still on cooldown, skip this item
					continue
				end

				-- Send pickup request and track it
				pickupRequests[id] = now
				EventManager:SendToServer("RequestItemPickup", {id = id})
				break
			end
		end
	end
end

function DroppedItemController:OnItemPickedUp(data)
	if not data then return end

	-- Play pickup sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/action_get_up.mp3"
	sound.Volume = 0.6
	sound.PlaybackSpeed = 1.2
	sound.Parent = player:WaitForChild("PlayerGui")
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
end

return DroppedItemController
