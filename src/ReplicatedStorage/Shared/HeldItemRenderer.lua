--[[
	HeldItemRenderer.lua
	Renders held items on characters.

	- Block entity → 3D model from ReplicatedStorage.Assets.BlockEntities
	- Placeable solid block → textured cube
	- Everything else → 3D model from ReplicatedStorage.Assets.Tools
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local ItemModelLoader = require(ReplicatedStorage.Shared.ItemModelLoader)
local BlockEntityLoader = require(ReplicatedStorage.Shared.BlockEntityLoader)
local ItemPixelSizes = require(ReplicatedStorage.Shared.ItemPixelSizes)

local HeldItemRenderer = {}

local STUDS_PER_PIXEL = 3 / 16
local BLOCK_SIZE = 1
local ITEM_SCALE = 0.6 -- Scale for non-tool/weapon/bow items
local TOOL_GRIP = {pos = Vector3.new(0, 0.4, -1.4), rot = Vector3.new(-20, -270, -90)}
local BOW_GRIP = {pos = Vector3.new(0, 0.5, 0.05), rot = Vector3.new(-20, -270, -90)}
local ITEM_GRIP = {pos = Vector3.new(0, 0.2, -0.5), rot = Vector3.new(-20, -90, 0)}
local BLOCK_GRIP = {pos = Vector3.new(0, -0.3, -0.5), rot = Vector3.new(0, 45, 0)}

local function isTool(itemName)
	local lower = itemName:lower()
	return lower:find("pickaxe") or lower:find("axe") or lower:find("sword") or lower:find("shovel")
end

local function getHand(character)
	return character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
end

local function createGripCFrame(grip)
	return CFrame.new(grip.pos) * CFrame.Angles(math.rad(grip.rot.X), math.rad(grip.rot.Y), math.rad(grip.rot.Z))
end

local function scaleMeshToPixels(part, pxX, pxY)
	local longest = math.max(pxX or 0, pxY or 0)
	if longest <= 0 then
		return
	end
	local target = longest * STUDS_PER_PIXEL
	local maxDim = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	if maxDim > 0 then
		part.Size = part.Size * (target / maxDim)
	end
end

local function isPlaceableBlock(itemId)
	local def = BlockRegistry.Blocks[itemId]
	if not def or not def.solid or def.craftingMaterial or def.isFood then
		return false
	end
	return def.textures ~= nil
end

local function hasBlockEntity(itemId)
	local def = BlockRegistry.Blocks[itemId]
	if not def or not def.entityName then
		return false
	end
	return BlockEntityLoader.HasEntity(def.entityName)
end

local function createBlockEntityPart(itemId)
	local def = BlockRegistry.Blocks[itemId]
	local entityName = def and def.entityName
	if not entityName then return nil end

	local entity = BlockEntityLoader.CreateHeldEntity(entityName, 0.5)
	if not entity then return nil end

	-- Handle both Model and BasePart entities
	if entity:IsA("Model") then
		-- For Models, we need to create a wrapper or use the primary part
		local primaryPart = entity.PrimaryPart or entity:FindFirstChildWhichIsA("BasePart", true)
		if primaryPart then
			-- Create a wrapper to attach to hand
			local wrapper = Instance.new("Part")
			wrapper.Name = "HeldItemHandle"
			wrapper.Size = Vector3.new(0.1, 0.1, 0.1)
			wrapper.Transparency = 1
			wrapper.Massless = true
			wrapper.CanCollide = false
			wrapper.Anchored = false
			wrapper.CastShadow = false

			-- Parent the entity to the wrapper
			entity.Parent = wrapper

			-- Position entity relative to wrapper center
			entity:PivotTo(CFrame.new(0, 0, 0))

			-- Weld all parts in the entity to the wrapper
			for _, part in ipairs(entity:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = false
					part.CanCollide = false
					part.Massless = true
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = wrapper
					weld.Part1 = part
					weld.Parent = part
				end
			end

			return wrapper
		end
		return nil
	elseif entity:IsA("BasePart") then
		entity.Name = "HeldItemHandle"
		entity.Massless = true
		entity.CanCollide = false
		entity.Anchored = false
		entity.CastShadow = true
		return entity
	end

	return nil
end

local function createBlockPart(itemId)
	local def = BlockRegistry.Blocks[itemId]
	local part = Instance.new("Part")
	part.Name = "HeldItemHandle"
	part.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
	part.Massless = true
	part.CanCollide = false
	part.Anchored = false
	part.Material = def.material or Enum.Material.Plastic
	part.Color = def.color or Color3.fromRGB(128, 128, 128)

	for _, face in ipairs({
		{Enum.NormalId.Top, "top"}, {Enum.NormalId.Bottom, "bottom"},
		{Enum.NormalId.Right, "side"}, {Enum.NormalId.Left, "side"},
		{Enum.NormalId.Front, "side"}, {Enum.NormalId.Back, "side"}
	}) do
		local textureId = TextureManager:GetTextureForBlockFace(itemId, face[2])
		if textureId then
			local tex = Instance.new("Texture")
			tex.Face = face[1]
			tex.Texture = textureId
			tex.StudsPerTileU = BLOCK_SIZE
			tex.StudsPerTileV = BLOCK_SIZE
			tex.Parent = part
		end
	end
	return part
end

local function createItemPart(itemId, itemName)
	local template = ItemModelLoader.GetModelTemplate(itemName, itemId)
	if not template then
		return nil
	end

	local part = template:Clone()
	part.Name = "HeldItemHandle"
	part.Massless = true
	part.CanCollide = false
	part.CastShadow = false
	part.Anchored = false

	local px = ItemPixelSizes.GetSize(itemName)
	if px then
		scaleMeshToPixels(part, px.x, px.y)
	end

	return part
end

function HeldItemRenderer.ClearItem(character)
	if not character then return end
	for _, child in ipairs(character:GetDescendants()) do
		if child.Name == "HeldItemHandle" then
			pcall(function()
				child:Destroy()
			end)
		end
	end
end

function HeldItemRenderer.AttachItem(character, itemId)
	if not character or not itemId or itemId == 0 then return nil end

	local hand = getHand(character)
	if not hand then return nil end

	HeldItemRenderer.ClearItem(character)

	local part, grip

	-- Check for block entity first (chests, lanterns, etc.)
	if hasBlockEntity(itemId) then
		part = createBlockEntityPart(itemId)
		grip = BLOCK_GRIP
	elseif isPlaceableBlock(itemId) then
		part = createBlockPart(itemId)
		grip = BLOCK_GRIP
	else
		-- Try 3D model from Assets.Tools (covers tools, armor, food, materials, etc.)
		local itemName = ItemRegistry.GetItemName(itemId)
		if itemName and itemName ~= "Unknown" then
			part = createItemPart(itemId, itemName)
		end

		-- Select grip based on item type
		if part then
			if itemName and itemName:lower():find("bow") then
				grip = BOW_GRIP
			elseif itemName and isTool(itemName) then
				grip = TOOL_GRIP
			else
				grip = ITEM_GRIP
				part.Size = part.Size * ITEM_SCALE
			end
		else
			-- Fallback: textured cube ONLY for actual solid blocks without 3D models
			-- Non-solid items (food, materials, saplings) should not render as cubes
			local blockDef = BlockRegistry.Blocks[itemId]
			if blockDef and blockDef.solid and blockDef.textures then
				part = createBlockPart(itemId)
				grip = BLOCK_GRIP
			end
			-- Items without 3D models and without solid block rendering simply won't show
		end
	end

	if not part then return nil end

	part:SetAttribute("ItemId", itemId)
	part.Parent = character

	local weld = Instance.new("Weld")
	weld.Name = "HeldItemWeld"
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = createGripCFrame(grip)
	weld.Parent = part

	return part
end

function HeldItemRenderer.GetAttachedItemId(character)
	if not character then return nil end
	for _, child in ipairs(character:GetDescendants()) do
		if child.Name == "HeldItemHandle" and child:GetAttribute("ItemId") then
			return child:GetAttribute("ItemId")
		end
	end
	return nil
end

return HeldItemRenderer
