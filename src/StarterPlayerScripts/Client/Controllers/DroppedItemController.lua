--[[
	DroppedItemController.lua
	Items use real Roblox physics and collide with the voxel world
	Server provides spawn position and velocity, client simulates physics
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local _TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ItemModelLoader = require(ReplicatedStorage.Shared.ItemModelLoader)
local BlockEntityLoader = require(ReplicatedStorage.Shared.BlockEntityLoader)
local ItemPixelSizes = require(ReplicatedStorage.Shared.ItemPixelSizes)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)

-- Scaling constants for dropped items
local STUDS_PER_PIXEL = 3 / 16
local DROPPED_ITEM_SCALE = 0.6 -- Dropped items are smaller than held items

local player = Players.LocalPlayer
local items = {}
local pickupRequests = {} -- Track last pickup request time per itemId

local DroppedItemController = {}
DroppedItemController.worldManager = nil
DroppedItemController.supportMap = {} -- key "x,y,z" -> { [id]=true }

-- Reusable pickup sound (prevents lag from creating new instances)
local pickupSound = nil

-- Compute the supporting block cell directly beneath a world position
local function computeSupportKeyFromPos(pos, blockSize)
    if not pos or not blockSize or blockSize <= 0 then
    	return nil
    end
    local bx = math.floor(pos.X / blockSize)
    local by = math.floor(pos.Y / blockSize) - 1 -- legacy fallback (unused when part available)
    local bz = math.floor(pos.Z / blockSize)
    return string.format("%d,%d,%d", bx, by, bz)
end

local function computeSupportKeyFromPart(part: BasePart, blockSize)
    if not part or not blockSize or blockSize <= 0 then
    	return nil
    end
    local pos = part.Position
    local halfY = (part.Size and part.Size.Y or 0) * 0.5
    local bx = math.floor(pos.X / blockSize)
    local bz = math.floor(pos.Z / blockSize)
    local by = math.floor(((pos.Y - halfY - 0.01) / blockSize)) -- block directly under the bottom face
    return string.format("%d,%d,%d", bx, by, bz)
end

-- Raycast down from the item's primary part to find actual ground under it
local function raycastGroundBelow(part: BasePart, maxDistance: number?)
    if not part then
    	return nil
    end
    local distance = maxDistance or 6
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {part.Parent} -- ignore the item model itself
    return workspace:Raycast(part.Position, Vector3.new(0, -distance, 0), params)
end

-- Animation constants (Minecraft-style)
local ROTATION_SPEED = 1.5 -- Smooth, slower rotation like Minecraft
local BOB_AMPLITUDE = 0.15 -- More noticeable bobbing
-- Magnetism constants (helps pickup feel like Minecraft)
local MAGNET_RADIUS = 2 -- start pulling when within this distance (studs)
local MAGNET_SPEED = 18 -- pull speed (studs/sec)

local BOB_SPEED = 2 -- How fast items bob up and down
local _PICKUP_REQUEST_COOLDOWN = 0 -- No client-side cooldown

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

-- Determine if an itemId represents a placeable voxel block (not a non-block item)
local function IsBlockItemId(itemId)
	if typeof(itemId) == "number" then
		-- Only treat as block if it's a known block entry and NOT marked craftingMaterial
		local raw = BlockRegistry.Blocks and BlockRegistry.Blocks[itemId]
		if raw ~= nil then
			return raw.craftingMaterial ~= true
		end
		return false
	end
	-- Strings come from ItemConfig and are non-block
	return false
end

-- One-time client collision group setup
function DroppedItemController:SetupCollisionGroups()
	local function ensureGroup(name)
		local found = false
		local groups = {}
		pcall(function()
			if PhysicsService.GetRegisteredCollisionGroups then
				groups = PhysicsService:GetRegisteredCollisionGroups()
			else
				groups = PhysicsService:GetCollisionGroups()
			end
		end)
		for _, g in ipairs(groups) do
			if g.name == name then
				found = true
				break
			end
		end
		if not found then
			pcall(function()
				PhysicsService:CreateCollisionGroup(name)
			end)
		end
	end

	ensureGroup("DroppedItem")
	ensureGroup("Character")

	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("DroppedItem", "DroppedItem", false)
		PhysicsService:CollisionGroupSetCollidable("DroppedItem", "Character", false)
		PhysicsService:CollisionGroupSetCollidable("DroppedItem", "Default", true)
	end)

	local function setCharGroup(char)
		if not char then
			return
		end
		for _, desc in ipairs(char:GetDescendants()) do
			if desc:IsA("BasePart") then
				pcall(function()
					desc.CollisionGroup = "Character"
				end)
			end
		end
		char.DescendantAdded:Connect(function(desc)
			if desc:IsA("BasePart") then
				pcall(function()
					desc.CollisionGroup = "Character"
				end)
			end
		end)
	end

	-- Existing players
	for _, plr in ipairs(Players:GetPlayers()) do
		setCharGroup(plr.Character)
		plr.CharacterAdded:Connect(setCharGroup)
	end

	-- Future players
	Players.PlayerAdded:Connect(function(plr)
		plr.CharacterAdded:Connect(setCharGroup)
	end)
end

function DroppedItemController:Initialize(voxelWorldHandle)
	-- Ensure collision groups exist and are configured
	self:SetupCollisionGroups()
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

	-- React to world edits to drop anchored items whose support disappeared
	EventManager:RegisterEvent("BlockChanged", function(data)
		if not data then
			return
		end
		self:OnBlockChanged(data.x, data.y, data.z, data.blockId)
	end)

	EventManager:RegisterEvent("BlockBroken", function(data)
		if not data then
			return
		end
		self:OnBlockChanged(data.x, data.y, data.z, 0)
	end)

	-- Capture world manager if provided (for block queries beneath items)
	if voxelWorldHandle and voxelWorldHandle.GetWorldManager then
		self.worldManager = voxelWorldHandle:GetWorldManager()
	end

	-- Start physics simulation loop
	self:StartUpdateLoop()
end

function DroppedItemController:StartUpdateLoop()
	local lastPickupCheck = 0
	local PICKUP_CHECK_INTERVAL = 0.05 -- Check every 0.05s instead of every frame (reduces CPU usage)

	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()

		-- Animate all items
		for _, item in pairs(items) do
			self:UpdateVisuals(item, dt, now)
		end

		-- Check for pickup with cooldown (optimization)
		if now - lastPickupCheck >= PICKUP_CHECK_INTERVAL then
			lastPickupCheck = now
			self:CheckPickup()
		end
	end)
end

function DroppedItemController:UpdateVisuals(item, dt, now)
	if not item.model or not item.model.PrimaryPart then
		return
	end

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

		-- When close enough, destroy
		if distance < 1 then
			-- Remove the merging item completely
			item.model:Destroy()
			items[item.id] = nil
			pickupRequests[item.id] = nil
		end

		return
	end

	-- Rotation
	item.rotation = item.rotation + dt * ROTATION_SPEED

	-- Clamp velocity to prevent tunneling through floor (max 50 studs/sec downward)
	if not item.settled and not part.Anchored then
		local velocity = part.AssemblyLinearVelocity
		local maxFallSpeed = 50 -- Maximum downward velocity to prevent tunneling
		if velocity.Y < -maxFallSpeed then
			part.AssemblyLinearVelocity = Vector3.new(velocity.X, -maxFallSpeed, velocity.Z)
		end
	end

	-- Check if item has settled (velocity near zero)
	if not item.settled and now - item.lastVelocityCheck >= 0.1 then
		item.lastVelocityCheck = now
		local velocity = part.AssemblyLinearVelocity
		local canSettle = true
        if item.noSettleUntil and now < item.noSettleUntil then
            canSettle = false
        end
		-- Loosen settle threshold and add time-based fallback to avoid perpetual jitter
		local ageNow = now - (item.spawnTime or now)
		local settleOk = (velocity.Magnitude < 1.0) or ((ageNow > 1.0) and (math.abs(velocity.Y) < 0.7))
		if canSettle and settleOk then
			-- Require a solid ground hit directly below to avoid anchoring mid-air
			local groundHit = raycastGroundBelow(part, 6)
			if groundHit and groundHit.Position then
				item.settled = true
				-- Place slightly above the ground for floating effect
				local groundY = groundHit.Position.Y
				item.finalPosition = Vector3.new(part.Position.X, groundY + 0.5, part.Position.Z)
				-- Anchor and disable collision once settled
				part.Anchored = true
				part.CanCollide = false

				-- Track the supporting block so we can unanchor on removal
				if self.worldManager then
					local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
					local bs = Constants.BLOCK_SIZE
					local key = computeSupportKeyFromPart(part, bs) or computeSupportKeyFromPos(item.finalPosition, bs)
					-- remove old mapping if any
					if item.supportKey and self.supportMap[item.supportKey] then
						self.supportMap[item.supportKey][item.id] = nil
					end
					item.supportKey = key
					if key then
						self.supportMap[key] = self.supportMap[key] or {}
						self.supportMap[key][item.id] = true
					end
				end
			end
		end
	end

	-- Apply rotation and optional bobbing (Minecraft-style)
	    if item.settled then
		-- Gentle magnetism towards player for easier pickup
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local toRoot = Vector3.new(root.Position.X - item.finalPosition.X, 0, root.Position.Z - item.finalPosition.Z)
			local dist = toRoot.Magnitude
			if dist > 0 and dist <= MAGNET_RADIUS then
				local step = math.min(MAGNET_SPEED * dt, dist)
				local dir = toRoot.Unit
				item.finalPosition = item.finalPosition + dir * step
			end
		end

		-- Bobbing (more noticeable like Minecraft)
		local bobOffset = math.sin(now * BOB_SPEED) * BOB_AMPLITUDE
		local visualPos = item.finalPosition + Vector3.new(0, bobOffset, 0)

		-- Apply rotation to entire model (all parts rotate together)
		item.model:SetPrimaryPartCFrame(CFrame.new(visualPos) * CFrame.Angles(0, item.rotation, 0))
	    else
        -- Falling: let physics drive both position and orientation; do not set CFrame
        -- Prevent immediate re-anchor after we intentionally dropped it; wait until it truly comes to rest
        if item.forceFallUntilContact then
            if item.noSettleUntil and now < item.noSettleUntil then
                item.lastVelocityCheck = now
            end
        end
		-- Gentle pre-settle magnetism in XZ to help pickup feel responsive
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local toRoot = Vector3.new(root.Position.X - part.Position.X, 0, root.Position.Z - part.Position.Z)
			local dist = toRoot.Magnitude
			if dist > 0 and dist <= MAGNET_RADIUS then
				local dir = toRoot.Unit
				local v = part.AssemblyLinearVelocity
				local pull = math.min(MAGNET_SPEED * dt, 3)
				part.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, v.Z) + dir * pull
			end
		end
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

		-- For flat visual-only items, do not reveal the invisible hitbox
		local flatOnly = item.model and item.model:GetAttribute("FlatVisualOnly") == true
		if not flatOnly then
			part.Transparency = alpha > 0 and 0 or 0.3
		end
	end
end

function DroppedItemController:CreateModel(itemId, count)
	local blockInfo = BlockRegistry:GetBlock(typeof(itemId) == "number" and itemId or nil)
	local model = Instance.new("Model")
	model.Name = "DroppedItem"

	local layerCount = GetLayerCount(count)
	local isCrossShape = blockInfo and blockInfo.crossShape == true
	local isBlockItem = IsBlockItemId(itemId)

	-- Use a standardized invisible hitbox for non-block (flat) items
	local hitboxSize = (GameConfig and GameConfig.DroppedItems and GameConfig.DroppedItems.HitboxSize) or Vector3.new(0.9, 0.9, 0.9)
	if not isBlockItem then
		-- Wrapper with invisible Hitbox and purely visual plate
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = hitboxSize
		hitbox.Transparency = 1
		hitbox.Anchored = false
		hitbox.CanCollide = true
		hitbox.CanQuery = true
		hitbox.CanTouch = true
		pcall(function() hitbox.CollisionGroup = "DroppedItem" end)
		hitbox.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1)
		hitbox.Parent = model

		local visualFolder = Instance.new("Folder")
		visualFolder.Name = "Visual"
		visualFolder.Parent = model

		-- Build visuals for non-block items: prefer BlockRegistry textures when numeric id; fallback to a Billboard for string ids
		local visualParts = {}

		local function makeSprite(textureId)
			local sprite = Instance.new("Part")
			sprite.Name = "VisualSprite"
			sprite.Size = Vector3.new(1.0, 1.0, 0.05)
			sprite.Transparency = 1
			sprite.CastShadow = false
			sprite.Anchored = false
			sprite.CanCollide = false
			sprite.CanQuery = false
			sprite.CanTouch = false
			sprite.Massless = true
			sprite.Parent = visualFolder
			if textureId then
				local frontTexture = Instance.new("Texture")
				frontTexture.Face = Enum.NormalId.Front
				frontTexture.Texture = textureId
				frontTexture.StudsPerTileU = 1.0
				frontTexture.StudsPerTileV = 1.0
				if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
					frontTexture.Color3 = blockInfo.color
				end
				frontTexture.Parent = sprite
				local backTexture = Instance.new("Texture")
				backTexture.Face = Enum.NormalId.Back
				backTexture.Texture = textureId
				backTexture.StudsPerTileU = 1.0
				backTexture.StudsPerTileV = 1.0
				if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
					backTexture.Color3 = blockInfo.color
				end
				backTexture.Parent = sprite
			end
			return sprite
		end

		local function _makeCube()
			local cube = Instance.new("Part")
			cube.Name = "VisualCube"
			cube.Size = Vector3.new(0.9, 0.9, 0.9)
			cube.Material = blockInfo and blockInfo.material or Enum.Material.Plastic
			cube.Color = blockInfo and blockInfo.color or Color3.new(0.8, 0.8, 0.8)
			cube.Anchored = false
			cube.CanCollide = false
			cube.CanQuery = false
			cube.CanTouch = false
			cube.CastShadow = true
			cube.Massless = true
			cube.Parent = visualFolder
			-- Apply textures to all faces when available
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
					texture.StudsPerTileU = 0.9
					texture.StudsPerTileV = 0.9
					if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
						texture.Color3 = blockInfo.color
					end
					texture.Parent = cube
				end
			end
			return cube
		end

		local layerOffsets = {
			{x = 0, y = 0, z = 0},
			{x = -LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y, z = LAYER_OFFSET_XZ},
			{x = LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y * 2, z = -LAYER_OFFSET_XZ},
			{x = 0, y = LAYER_OFFSET_Y * 3, z = LAYER_OFFSET_XZ},
		}

		-- Try to use 3D model from Tools folder (unified lookup via ItemRegistry)
		local itemName = ItemRegistry.GetItemName(itemId)
		local modelTemplate = nil
		if itemName and itemName ~= "Unknown" then
			modelTemplate = ItemModelLoader.GetModelTemplate(itemName, itemId)
		end

		if modelTemplate then
			-- Use 3D model for any item type
			local base = modelTemplate:Clone()
			base.Name = "Visual3DModel"
			base.Anchored = false
			base.CanCollide = false
			base.CanQuery = false
			base.CanTouch = false
			base.Massless = true
			base.CastShadow = true
			base.Parent = visualFolder

			-- Apply texture from ItemRegistry if needed
			if base:IsA("MeshPart") then
				local hasTexture = false
				pcall(function()
					hasTexture = base.TextureID ~= nil and tostring(base.TextureID) ~= ""
				end)
				if not hasTexture then
					local itemDef = ItemRegistry.GetItem(itemId)
					local textureId = itemDef and itemDef.image
					if textureId then
						pcall(function()
							base.TextureID = textureId
						end)
					end
				end
			end

			-- Scale using ItemPixelSizes (smaller for dropped items)
			local px = ItemPixelSizes.GetSize(itemName)
			if px then
				local longestPx = math.max(px.x or 0, px.y or 0)
				if longestPx > 0 then
					local targetStuds = longestPx * STUDS_PER_PIXEL * DROPPED_ITEM_SCALE
					local maxDim = math.max(base.Size.X, base.Size.Y, base.Size.Z)
					if maxDim > 0 then
						local scale = targetStuds / maxDim
						base.Size = base.Size * scale
					end
				end
			end

			base.CFrame = hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5, 0)
			table.insert(visualParts, base)
			if layerCount > 1 then
				for i = 2, layerCount do
					local off = layerOffsets[i]
					local clone = base:Clone()
					clone.CFrame = base.CFrame * CFrame.new(off.x, off.y, off.z)
					clone.Parent = visualFolder
					table.insert(visualParts, clone)
				end
			end
		elseif typeof(itemId) == "number" and ToolConfig and ToolConfig.IsTool and ToolConfig.IsTool(itemId) then
			-- Fallback: Tool without 3D model - render as cross-shaped sprite using item texture
			local itemDef = ItemRegistry.GetItem(itemId)
			local base = makeSprite(itemDef and itemDef.image or nil)
			base.CFrame = hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5 + 0.025, 0)
			table.insert(visualParts, base)
			if layerCount > 1 then
				for i = 2, layerCount do
					local off = layerOffsets[i]
					local clone = base:Clone()
					clone.CFrame = base.CFrame * CFrame.new(off.x, off.y, off.z)
					clone.Parent = visualFolder
					table.insert(visualParts, clone)
				end
			end
		elseif typeof(itemId) == "number" and blockInfo then
			-- FALLBACK: Block item without 3D model - render as a flat sprite using BlockRegistry texture
			local textureId
			if blockInfo.textures and blockInfo.textures.all then
				textureId = TextureManager:GetTextureId(blockInfo.textures.all)
			else
				textureId = TextureManager:GetTextureForBlockFace(itemId, "side")
			end
			local base = makeSprite(textureId)
			base.CFrame = hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5 + 0.025, 0)
			table.insert(visualParts, base)
			if layerCount > 1 then
				for i = 2, layerCount do
					local off = layerOffsets[i]
					local clone = base:Clone()
					clone.CFrame = base.CFrame * CFrame.new(off.x, off.y, off.z)
					clone.Parent = visualFolder
					table.insert(visualParts, clone)
				end
			end
		else
			-- Fallback for ItemConfig string ids: billboard with item name
			local bb = Instance.new("BillboardGui")
			bb.Name = "VisualBillboard"
			bb.Size = UDim2.fromOffset(64, 64)
			bb.StudsOffset = Vector3.new(0, hitbox.Size.Y * 0.5 + 0.25, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = hitbox
			bb.Parent = visualFolder
			local label = Instance.new("TextLabel")
			label.Name = "ItemName"
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.TextScaled = true
			local itemName = ItemRegistry.GetItemName(itemId)
			label.Text = (itemName ~= "Unknown") and itemName or tostring(itemId)
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.5
			label.Parent = bb
		end

		-- Weld visual Parts (not GUI) to hitbox
		for _, p in ipairs(visualParts) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hitbox
			weld.Part1 = p
			weld.Parent = p
		end

		-- Add highlight for late-despawn flashing (do not toggle hitbox transparency)
		local highlight = Instance.new("Highlight")
		highlight.Enabled = false
		highlight.Parent = hitbox

		model.PrimaryPart = hitbox
		model:SetAttribute("FlatVisualOnly", true)

		model.Parent = workspace
		return model
	end

	-- Layer offsets for Minecraft-style scattered pile
	local layerOffsets = {
		{x = 0, y = 0, z = 0},
		{x = -LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y, z = LAYER_OFFSET_XZ},
		{x = LAYER_OFFSET_XZ, y = LAYER_OFFSET_Y * 2, z = -LAYER_OFFSET_XZ},
		{x = 0, y = LAYER_OFFSET_Y * 3, z = LAYER_OFFSET_XZ},
	}

	-- Try to use BlockEntity model first (for special blocks like chests, lanterns, etc.)
	local entityName = blockInfo and blockInfo.entityName
	if entityName and BlockEntityLoader.HasEntity(entityName) then
		local hitbox = Instance.new("Part")
		hitbox.Name = "Hitbox"
		hitbox.Size = hitboxSize
		hitbox.Transparency = 1
		hitbox.Anchored = false
		hitbox.CanCollide = true
		hitbox.CanQuery = true
		hitbox.CanTouch = true
		pcall(function() hitbox.CollisionGroup = "DroppedItem" end)
		hitbox.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1)
		hitbox.Parent = model

		local visualFolder = Instance.new("Folder")
		visualFolder.Name = "Visual"
		visualFolder.Parent = model

		local visualParts = {}
		local entity = BlockEntityLoader.CreateDroppedEntity(entityName, DROPPED_ITEM_SCALE)
		if entity then
			entity.Name = "VisualBlockEntity"
			entity.Parent = visualFolder

			-- Handle both Model and BasePart entities
			if entity:IsA("Model") then
				-- Disable collisions on all parts
				for _, part in ipairs(entity:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = false
						part.CanCollide = false
						part.CanQuery = false
						part.CanTouch = false
						part.Massless = true
						part.CastShadow = true
					end
				end
				-- Position the model
				entity:PivotTo(hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5, 0))
				-- Weld all parts to hitbox
				for _, part in ipairs(entity:GetDescendants()) do
					if part:IsA("BasePart") then
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = hitbox
						weld.Part1 = part
						weld.Parent = part
						table.insert(visualParts, part)
					end
				end
			elseif entity:IsA("BasePart") then
				entity.Anchored = false
				entity.CanCollide = false
				entity.CanQuery = false
				entity.CanTouch = false
				entity.Massless = true
				entity.CastShadow = true
				entity.CFrame = hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5, 0)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hitbox
				weld.Part1 = entity
				weld.Parent = entity
				table.insert(visualParts, entity)
			end

			-- Add additional layers for stack sizes
			if layerCount > 1 then
				for i = 2, layerCount do
					local off = layerOffsets[i]
					local clone = entity:Clone()
					clone.Parent = visualFolder
					if clone:IsA("Model") then
						clone:PivotTo(hitbox.CFrame * CFrame.new(off.x, hitbox.Size.Y * 0.5 + off.y, off.z))
						for _, part in ipairs(clone:GetDescendants()) do
							if part:IsA("BasePart") then
								local weld = Instance.new("WeldConstraint")
								weld.Part0 = hitbox
								weld.Part1 = part
								weld.Parent = part
								table.insert(visualParts, part)
							end
						end
					elseif clone:IsA("BasePart") then
						clone.CFrame = hitbox.CFrame * CFrame.new(off.x, hitbox.Size.Y * 0.5 + off.y, off.z)
						local weld = Instance.new("WeldConstraint")
						weld.Part0 = hitbox
						weld.Part1 = clone
						weld.Parent = clone
						table.insert(visualParts, clone)
					end
				end
			end

			-- Add highlight for late-despawn flashing
			local highlight = Instance.new("Highlight")
			highlight.Enabled = false
			highlight.Parent = hitbox

			model.PrimaryPart = hitbox
			model:SetAttribute("FlatVisualOnly", true)
			model.Parent = workspace
			return model
		end
	end

	-- Try to use 3D model from Tools folder (unified lookup via ItemRegistry)
	-- SKIP for cross-shape blocks (wheat, saplings, flowers, etc.) - they render as flat sprites below
	local blockItemName = ItemRegistry.GetItemName(itemId)
	if blockItemName and blockItemName ~= "Unknown" and not isCrossShape then
		local modelTemplate = ItemModelLoader.GetModelTemplate(blockItemName, itemId)
		if modelTemplate then
			-- Use 3D model for block item
			local hitbox = Instance.new("Part")
			hitbox.Name = "Hitbox"
			hitbox.Size = hitboxSize
			hitbox.Transparency = 1
			hitbox.Anchored = false
			hitbox.CanCollide = true
			hitbox.CanQuery = true
			hitbox.CanTouch = true
			pcall(function() hitbox.CollisionGroup = "DroppedItem" end)
			hitbox.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1)
			hitbox.Parent = model

			local visualFolder = Instance.new("Folder")
			visualFolder.Name = "Visual"
			visualFolder.Parent = model

			local visualParts = {}
			local base = modelTemplate:Clone()
			base.Name = "Visual3DModel"
			base.Anchored = false
			base.CanCollide = false
			base.CanQuery = false
			base.CanTouch = false
			base.Massless = true
			base.CastShadow = true
			base.Parent = visualFolder

			-- Apply texture from ItemRegistry if needed
			if base:IsA("MeshPart") then
				local hasTexture = false
				pcall(function()
					hasTexture = base.TextureID ~= nil and tostring(base.TextureID) ~= ""
				end)
				if not hasTexture then
					local itemDef = ItemRegistry.GetItem(itemId)
					local textureId = itemDef and itemDef.image
					if textureId then
						pcall(function()
							base.TextureID = textureId
						end)
					end
				end
			end

			-- Scale using ItemPixelSizes (smaller for dropped items)
			local px = ItemPixelSizes.GetSize(blockItemName)
			if px then
				local longestPx = math.max(px.x or 0, px.y or 0)
				if longestPx > 0 then
					local targetStuds = longestPx * STUDS_PER_PIXEL * DROPPED_ITEM_SCALE
					local maxDim = math.max(base.Size.X, base.Size.Y, base.Size.Z)
					if maxDim > 0 then
						local scale = targetStuds / maxDim
						base.Size = base.Size * scale
					end
				end
			end

			base.CFrame = hitbox.CFrame * CFrame.new(0, hitbox.Size.Y * 0.5, 0)
			table.insert(visualParts, base)

			-- Add additional layers for stack sizes
			if layerCount > 1 then
				for i = 2, layerCount do
					local off = layerOffsets[i]
					local clone = base:Clone()
					clone.CFrame = base.CFrame * CFrame.new(off.x, off.y, off.z)
					clone.Parent = visualFolder
					table.insert(visualParts, clone)
				end
			end

			-- Weld visual parts to hitbox
			for _, p in ipairs(visualParts) do
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = hitbox
				weld.Part1 = p
				weld.Parent = p
			end

			-- Add highlight for late-despawn flashing
			local highlight = Instance.new("Highlight")
			highlight.Enabled = false
			highlight.Parent = hitbox

			model.PrimaryPart = hitbox
			model:SetAttribute("FlatVisualOnly", true)
			model.Parent = workspace
			return model
		end
	end

	-- Special model for fence-type items: two posts with connecting rails
	if blockInfo and blockInfo.fenceShape then
		-- Build a compact fence section centered at origin
		local size = 0.9 -- compact scale for dropped item
		local postWidth = 0.25 * size
		local postHeight = 1.0 * size
		local railThickness = 0.16 * size
		local sep = 0.35 * size

		local function makePost(x)
			local post = Instance.new("Part")
			post.Name = "FencePost"
			post.Size = Vector3.new(postWidth, postHeight, postWidth)
			post.Material = blockInfo.material or Enum.Material.Plastic
			post.Color = blockInfo.color or Color3.new(0.8, 0.8, 0.8)
			post.Anchored = false
			post.CanCollide = false
			post.Massless = true
			post.CFrame = CFrame.new(x, (postHeight - size) * 0.5, 0)
			post.Parent = model
			-- Apply wood planks texture to post
			if blockInfo and blockInfo.textures and blockInfo.textures.all then
				local textureId = TextureManager:GetTextureId(blockInfo.textures.all)
				if textureId then
					for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
						local tex = Instance.new("Texture")
						tex.Face = face
						tex.Texture = textureId
						tex.StudsPerTileU = size
						tex.StudsPerTileV = size
						tex.Parent = post
					end
				end
			end
			return post
		end

		local postL = makePost(-sep)
		local postR = makePost(sep)

		local span = (sep * 2) - postWidth
		local function makeRail(y)
			local rail = Instance.new("Part")
			rail.Name = "FenceRail"
			rail.Size = Vector3.new(span, railThickness, railThickness)
			rail.Material = blockInfo.material or Enum.Material.Plastic
			rail.Color = blockInfo.color or Color3.new(0.8, 0.8, 0.8)
			rail.Anchored = false
			rail.CanCollide = false
			rail.Massless = true
			rail.CFrame = CFrame.new(0, -0.5 * size + y, 0)
			rail.Parent = model
			-- Apply wood planks texture to rail
			if blockInfo and blockInfo.textures and blockInfo.textures.all then
				local textureId = TextureManager:GetTextureId(blockInfo.textures.all)
				if textureId then
					for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
						local tex = Instance.new("Texture")
						tex.Face = face
						tex.Texture = textureId
						tex.StudsPerTileU = size
						tex.StudsPerTileV = size
						tex.Parent = rail
					end
				end
			end
			return rail
		end

		-- Symmetric rail positions for perfect vertical stacking
		local rail1 = makeRail(0.25 * size)
		local rail2 = makeRail(0.75 * size)

		-- Collect all visual parts (base layer)
        local visualParts = {postL, postR, rail1, rail2}

		-- Additional layers for stack sizes (2-16, 17-32, 33-64)
		if layerCount > 1 then
			for i = 2, layerCount do
				local off = layerOffsets[i]
				local pL = makePost(-sep)
				pL.CFrame = pL.CFrame * CFrame.new(off.x, off.y, off.z)
				local pR = makePost(sep)
				pR.CFrame = pR.CFrame * CFrame.new(off.x, off.y, off.z)
				local r1 = makeRail(0.25 * size)
				r1.CFrame = r1.CFrame * CFrame.new(off.x, off.y, off.z)
				local r2 = makeRail(0.75 * size)
				r2.CFrame = r2.CFrame * CFrame.new(off.x, off.y, off.z)

				table.insert(visualParts, pL)
				table.insert(visualParts, pR)
				table.insert(visualParts, r1)
				table.insert(visualParts, r2)
			end
		end

		-- Use an invisible physical root as PrimaryPart for physics
		local root = Instance.new("Part")
		root.Name = "ItemPart_1"
		root.Size = hitboxSize -- Standardized hitbox size
		root.Transparency = 1
		root.Anchored = false
		root.CanCollide = true
		pcall(function() root.CollisionGroup = "DroppedItem" end)
		root.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1) -- More friction
		root.Parent = model
		model.PrimaryPart = root

		-- Weld all fence parts to root
		for _, p in ipairs(visualParts) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end

		model.Parent = workspace

		return model
	end

	-- Special model for slab-type items: compact half-height block
	if blockInfo and blockInfo.slabShape then
		local size = 0.9

		-- Visual slab
		local slab = Instance.new("Part")
		slab.Name = "SlabVisual"
		slab.Size = Vector3.new(size, size * 0.5, size)
		slab.Material = blockInfo.material or Enum.Material.Plastic
		slab.Color = blockInfo.color or Color3.new(0.8, 0.8, 0.8)
		slab.Anchored = false
		slab.CanCollide = false
		slab.Massless = true
		slab.CFrame = CFrame.new(0, -size * 0.25, 0)
		slab.Parent = model

		-- Apply textures to all faces if available
		if blockInfo.textures and blockInfo.textures.all then
			local textureId = TextureManager:GetTextureId(blockInfo.textures.all)
			if textureId then
				for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
					local tex = Instance.new("Texture")
					tex.Face = face
					tex.Texture = textureId
					tex.StudsPerTileU = 1.0
					tex.StudsPerTileV = 1.0
					if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
						tex.Color3 = blockInfo.color
					end
					tex.Parent = slab
				end
			end
		end

		-- Collect visual parts for layering
		local visualParts = {slab}

		-- Additional layers for stack sizes (2-16, 17-32, 33-64)
		if layerCount > 1 then
			for i = 2, layerCount do
				local off = layerOffsets[i]
				local s = slab:Clone()
				s.CFrame = slab.CFrame * CFrame.new(off.x, off.y, off.z)
				s.Parent = model
				table.insert(visualParts, s)
			end
		end

		-- Invisible physical root
		local root = Instance.new("Part")
		root.Name = "ItemPart_1"
		root.Size = hitboxSize -- Standardized hitbox size
		root.Transparency = 1
		root.Anchored = false
		root.CanCollide = true
		pcall(function() root.CollisionGroup = "DroppedItem" end)
		root.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1) -- More friction
		root.Parent = model
		model.PrimaryPart = root

		-- Weld all slab visuals to root
		for _, p in ipairs(visualParts) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end

		model.Parent = workspace

		return model
	end

	-- Special model for staircase-type items: bottom slab + top step
	if blockInfo and blockInfo.stairShape then
		local size = 0.9

		-- Visual parts
		local bottom = Instance.new("Part")
		bottom.Name = "StairBottom"
		bottom.Size = Vector3.new(size, size * 0.5, size)
		bottom.Material = blockInfo.material or Enum.Material.Plastic
		bottom.Color = blockInfo.color or Color3.new(0.8, 0.8, 0.8)
		bottom.Anchored = false
		bottom.CanCollide = false
		bottom.Massless = true
		bottom.CFrame = CFrame.new(0, -size * 0.25, 0)
		bottom.Parent = model

		local top = Instance.new("Part")
		top.Name = "StairTop"
		top.Size = Vector3.new(size, size * 0.5, size * 0.5)
		top.Material = blockInfo.material or Enum.Material.Plastic
		top.Color = blockInfo.color or Color3.new(0.8, 0.8, 0.8)
		top.Anchored = false
		top.CanCollide = false
		top.Massless = true
		top.CFrame = CFrame.new(0, size * 0.25, -size * 0.25)
		top.Parent = model

		-- Apply textures if available
		if blockInfo.textures and blockInfo.textures.all then
			local textureId = TextureManager:GetTextureId(blockInfo.textures.all)
			if textureId then
				for _, part in ipairs({bottom, top}) do
					for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
						local tex = Instance.new("Texture")
						tex.Face = face
						tex.Texture = textureId
						tex.StudsPerTileU = 1.0
						tex.StudsPerTileV = 1.0
						if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
							tex.Color3 = blockInfo.color
						end
						tex.Parent = part
					end
				end
			end
		end


		-- Collect visual parts for layering
		local visualParts = {bottom, top}

		-- Additional layers for stack sizes (2-16, 17-32, 33-64)
		if layerCount > 1 then
			for i = 2, layerCount do
				local off = layerOffsets[i]
				local b = bottom:Clone()
				b.CFrame = bottom.CFrame * CFrame.new(off.x, off.y, off.z)
				b.Parent = model
				local t = top:Clone()
				t.CFrame = top.CFrame * CFrame.new(off.x, off.y, off.z)
				t.Parent = model
				table.insert(visualParts, b)
				table.insert(visualParts, t)
			end
		end

		-- Invisible physical root
		local root = Instance.new("Part")
		root.Name = "ItemPart_1"
		root.Size = hitboxSize -- Standardized hitbox size
		root.Transparency = 1
		root.Anchored = false
		root.CanCollide = true
		pcall(function() root.CollisionGroup = "DroppedItem" end)
		root.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1) -- More friction
		root.Parent = model
		model.PrimaryPart = root

		-- Weld all stair visuals to root
		for _, p in ipairs(visualParts) do
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = p
			weld.Parent = p
		end

		model.Parent = workspace

		return model
	end

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
			part.Size = Vector3.new(0.9, 0.9, 0.9) -- 3D cube (increased from 0.75 to prevent tunneling)
			part.Transparency = (blockInfo and blockInfo.transparent) and 0.8 or 0
			part.CastShadow = true
		end

	part.Material = blockInfo and blockInfo.material or Enum.Material.Plastic
		part.Color = blockInfo and blockInfo.color or Color3.new(0.8, 0.8, 0.8)

		local offset = layerOffsets[i]
		part.CFrame = CFrame.new(offset.x, offset.y, offset.z)

		if i == 1 then
			part.Anchored = false
			part.CanCollide = true
			-- Slightly heavier and more friction to prevent high-speed tunneling
			part.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.5, 0.3, 1, 1)
			pcall(function() part.CollisionGroup = "DroppedItem" end)
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
					texture.StudsPerTileU = 0.9 -- Updated to match new part size
					texture.StudsPerTileV = 0.9 -- Updated to match new part size
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

	model.Parent = workspace

	return model
end

function DroppedItemController:OnItemSpawned(data)
	if not data or not data.id then
		return
	end
	if items[data.id] then
		return
	end

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

	-- Prevent mid-air anchoring at the apex by deferring settling briefly
	item.noSettleUntil = item.spawnTime + 0.1

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
	if not data or not data.id then
		return
	end

	local item = items[data.id]
	if not item then
		return
	end

	-- Instant cleanup (no animation for performance)
	if item.model then
		item.model:Destroy()
	end

	-- Clean up tracking data (prevent memory leaks)
	pickupRequests[data.id] = nil

	-- Optimized: Remove from support map using stored key (O(1) instead of O(n))
	if item.supportKey and self.supportMap[item.supportKey] then
		self.supportMap[item.supportKey][data.id] = nil
		-- Clean up empty sets
		if next(self.supportMap[item.supportKey]) == nil then
			self.supportMap[item.supportKey] = nil
		end
	end

	items[data.id] = nil

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
	if not data or not data.id then
		return
	end

	local item = items[data.id]
	if not item then
		return
	end

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

		-- Recompute support mapping if settled
		if item.settled and self.worldManager then
			local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
			local bs = Constants.BLOCK_SIZE
			local finalPos = item.finalPosition or newModel.PrimaryPart.Position
			local below = finalPos + Vector3.new(0, -0.6, 0)
			local sx = math.floor(below.X / bs)
			local sy = math.floor(below.Y / bs)
			local sz = math.floor(below.Z / bs)
			local key = string.format("%d,%d,%d", sx, sy, sz)
			if item.supportKey and self.supportMap[item.supportKey] then
				self.supportMap[item.supportKey][item.id] = nil
			end
			item.supportKey = key
			self.supportMap[key] = self.supportMap[key] or {}
			self.supportMap[key][item.id] = true
		end
	end
end

function DroppedItemController:CheckPickup()
	local char = player.Character
	if not char then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()

	-- Find nearest in-range item (allow pickup while moving; ignore merging)
	local nearestId = nil
	local nearestDist = math.huge
	local nearestPos = nil

	for id, item in pairs(items) do
		if not item.merging and item.model and item.model.PrimaryPart then
			local itemPos = item.model.PrimaryPart.Position
			-- Use horizontal (XZ) distance for Minecraft-like pickup feel
			local dx = itemPos.X - root.Position.X
			local dz = itemPos.Z - root.Position.Z
			local distXZ = math.sqrt(dx*dx + dz*dz)

			if distXZ <= 3 then
				if distXZ < nearestDist then
					nearestDist = distXZ
					nearestId = id
					if item.settled and item.finalPosition then
						nearestPos = item.finalPosition
					else
						nearestPos = itemPos
					end
				end
			else
				-- Out of range: allow immediate retry next time
				pickupRequests[id] = nil
			end
		end
	end

	if nearestId and nearestPos then
		local lastReq = pickupRequests[nearestId] or 0
		if (now - lastReq) >= 0.4 then
			pickupRequests[nearestId] = now
			EventManager:SendToServer("RequestItemPickup", {
				id = nearestId,
				pos = {nearestPos.X, nearestPos.Y, nearestPos.Z}
			})
		end
	end
end

-- Called when a block changed or was broken; if it was supporting any anchored item, drop them
function DroppedItemController:OnBlockChanged(x, y, z, newBlockId)
    if not self.worldManager then
    	return
    end
    local key = string.format("%d,%d,%d", x, y, z)
    local set = self.supportMap[key]
    if not set then
    	return
    end
    local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
    if newBlockId == nil then
        newBlockId = self.worldManager:GetBlock(x, y, z)
    end
    if newBlockId == Constants.BlockType.AIR then
        for id, _ in pairs(set) do
            local item = items[id]
            if item and item.model and item.model.PrimaryPart then
                local part = item.model.PrimaryPart
                part.Anchored = false
                part.CanCollide = true
                item.settled = false
                -- Ensure it actually starts falling, and defer re-settle briefly
                part.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
                item.forceFallUntilContact = true
                item.noSettleUntil = os.clock() + 0.125
                -- Clear mapping for this item
                set[id] = nil
                item.supportKey = nil
            end
        end
        if next(set) == nil then
            self.supportMap[key] = nil
        end
    end
end

function DroppedItemController:OnItemPickedUp(data)
	if not data then
		return
	end
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("inventoryPop")
		return
	end

	-- Fallback: reuse Roblox sound instance to prevent lag from creating new ones
	if not pickupSound or not pickupSound.Parent then
		pickupSound = Instance.new("Sound")
		pickupSound.SoundId = "rbxassetid://116766040641694"
		pickupSound.Volume = 0.65
		pickupSound.PlaybackSpeed = 1
		pickupSound.Parent = game:GetService("SoundService")
	end
	pickupSound:Play()
end

return DroppedItemController
