--[[
	HeldItemRenderer.lua
	Unified module for rendering held items (tools OR blocks) on any character.

	Used by:
	- ToolVisualController (local player 3rd person + remote players)
	- VoxelInventoryPanel (armor UI viewmodel)

	API:
	- HeldItemRenderer.AttachItem(character, itemId) → returns handle Part
	- HeldItemRenderer.ClearItem(character)
	- HeldItemRenderer.GetAttachedItemId(character) → returns itemId or nil
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local ItemModelLoader = require(ReplicatedStorage.Shared.ItemModelLoader)

local HeldItemRenderer = {}

-- Constants
local STUDS_PER_PIXEL = 3 / 16
local HELD_ITEM_TAG = "HeldItemHandle" -- Tag for identifying held items

-- Tool mesh asset names
local TOOL_ASSET_NAMES = {
	[BlockProperties.ToolType.SWORD] = "Sword",
	[BlockProperties.ToolType.AXE] = "Axe",
	[BlockProperties.ToolType.SHOVEL] = "Shovel",
	[BlockProperties.ToolType.PICKAXE] = "Pickaxe",
	[BlockProperties.ToolType.BOW] = "Bow",
}

-- Tool pixel sizes for scaling
local TOOL_PX_SIZES = {
	[BlockProperties.ToolType.SWORD] = {x = 14, y = 14},
	[BlockProperties.ToolType.AXE] = {x = 12, y = 14},
	[BlockProperties.ToolType.SHOVEL] = {x = 12, y = 12},
	[BlockProperties.ToolType.PICKAXE] = {x = 13, y = 13},
	[BlockProperties.ToolType.BOW] = {x = 14, y = 14},
}

-- Tool grip positions/rotations
local TOOL_GRIPS = {
	[BlockProperties.ToolType.SWORD] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
	[BlockProperties.ToolType.AXE] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
	[BlockProperties.ToolType.SHOVEL] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
	[BlockProperties.ToolType.PICKAXE] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
	[BlockProperties.ToolType.BOW] = {pos = Vector3.new(0, 0.3, 0), rot = Vector3.new(225, 90, 0)},
}

-- Block grip (smaller, held differently)
local BLOCK_GRIP = {pos = Vector3.new(0, -0.3, -0.5), rot = Vector3.new(0, 45, 0)}
local BLOCK_SIZE = 0.5 -- Studs

----------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------

local function getToolsFolder()
	local folder = ReplicatedStorage:FindFirstChild("Tools")
	if folder then return folder end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Tools")
end

local function getMeshTemplate(name)
	local folder = getToolsFolder()
	if not folder then return nil end
	local template = folder:FindFirstChild(name)
	if not template then return nil end
	if template:IsA("MeshPart") then return template end
	return template:FindFirstChildWhichIsA("MeshPart", true)
end

local function scaleMeshToPixels(part, pxX, pxY)
	local longestPx = math.max(pxX or 0, pxY or 0)
	if longestPx <= 0 then return end
	local targetStuds = longestPx * STUDS_PER_PIXEL
	local size = part.Size
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0 then
		local scale = targetStuds / maxDim
		part.Size = Vector3.new(size.X * scale, size.Y * scale, size.Z * scale)
	end
end

local function createGripCFrame(grip)
	return CFrame.new(grip.pos) * CFrame.Angles(
		math.rad(grip.rot.X),
		math.rad(grip.rot.Y),
		math.rad(grip.rot.Z)
	)
end

local function getHand(character)
	if not character then return nil end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

----------------------------------------------------------------
-- Clear any existing held items from a character
----------------------------------------------------------------

function HeldItemRenderer.ClearItem(character)
	if not character then return end

	-- Find and destroy all held item handles
	for _, child in ipairs(character:GetDescendants()) do
		if child:GetAttribute(HELD_ITEM_TAG) then
			pcall(function() child:Destroy() end)
		end
	end

	-- Also clear by common names (for legacy/cloned items)
	for _, child in ipairs(character:GetDescendants()) do
		local name = child.Name
		if name == "HeldItemHandle" or name == "ToolHandle" or name == "ArmorToolHandle"
		   or name == "RemoteToolHandle" or name == "BlockHandle"
		   or name:match("^BowHandle_") then
			pcall(function() child:Destroy() end)
		end
	end
end

----------------------------------------------------------------
-- Get currently attached item ID
----------------------------------------------------------------

function HeldItemRenderer.GetAttachedItemId(character)
	if not character then return nil end

	for _, child in ipairs(character:GetDescendants()) do
		if child:GetAttribute(HELD_ITEM_TAG) then
			return child:GetAttribute("ItemId")
		end
	end

	return nil
end

----------------------------------------------------------------
-- Create a tool handle
----------------------------------------------------------------

local function createToolHandle(itemId, toolType)
	local assetName = TOOL_ASSET_NAMES[toolType]
	local mesh = assetName and getMeshTemplate(assetName)

	local part
	if mesh then
		part = mesh:Clone()
	else
		-- Fallback: simple wooden stick
		part = Instance.new("Part")
		part.Size = Vector3.new(0.15, 1.2, 0.15)
		part.Color = Color3.fromRGB(139, 90, 43)
		part.Material = Enum.Material.Wood
	end

	part.Name = "HeldItemHandle"
	part.Massless = true
	part.CanCollide = false
	part.CastShadow = false
	part.Anchored = false

	-- Apply texture from ToolConfig
	local toolInfo = ToolConfig.GetToolInfo(itemId)
	if toolInfo and toolInfo.image then
		pcall(function()
			if part:IsA("MeshPart") and (not part.TextureID or part.TextureID == "") then
				part.TextureID = toolInfo.image
			end
		end)
	end

	-- Scale to proper size
	local px = TOOL_PX_SIZES[toolType]
	if px then
		scaleMeshToPixels(part, px.x, px.y)
	end

	return part, TOOL_GRIPS[toolType] or TOOL_GRIPS[BlockProperties.ToolType.SWORD]
end

----------------------------------------------------------------
-- Create a block handle (rendered like dropped item blocks)
----------------------------------------------------------------

local function createBlockHandle(blockId, blockInfo)
	blockInfo = blockInfo or BlockRegistry.Blocks[blockId]

	-- Try to use 3D model from Tools folder first (for food items, etc.)
	if blockInfo and blockInfo.name then
		local modelTemplate = ItemModelLoader.GetModelTemplate(blockInfo.name, blockId)
		if modelTemplate then
			local part = modelTemplate:Clone()
			part.Name = "HeldItemHandle"
			part.Massless = true
			part.CanCollide = false
			part.CastShadow = false
			part.Anchored = false

			-- Always apply texture from BlockRegistry to ensure consistency
			if part:IsA("MeshPart") and blockInfo.textures then
				local textureName = blockInfo.textures.all or blockInfo.textures.side or blockInfo.textures.top
				if textureName then
					local textureId = TextureManager:GetTextureId(textureName)
					if textureId then
						pcall(function()
							part.TextureID = textureId
						end)
					end
				end
			end

			return part, BLOCK_GRIP
		end
	end

	-- Check if it's a cross-shaped plant (flowers, grass, etc.)
	local isCrossShape = blockInfo and blockInfo.crossShape

	local part = Instance.new("Part")
	part.Name = "HeldItemHandle"
	part.Massless = true
	part.CanCollide = false
	part.Anchored = false

	if isCrossShape then
		-- 2D sprite for plants (like dropped items)
		part.Size = Vector3.new(BLOCK_SIZE * 2, BLOCK_SIZE * 2, 0.02)
		part.Transparency = 1 -- Only texture shows
		part.CastShadow = false

		-- Apply texture to front and back faces
		local textureId
		if blockInfo.textures and blockInfo.textures.all then
			textureId = TextureManager:GetTextureId(blockInfo.textures.all)
		end

		if textureId then
			local frontTexture = Instance.new("Texture")
			frontTexture.Face = Enum.NormalId.Front
			frontTexture.Texture = textureId
			frontTexture.StudsPerTileU = BLOCK_SIZE * 2
			frontTexture.StudsPerTileV = BLOCK_SIZE * 2
			if blockInfo.greyscaleTexture and blockInfo.color then
				frontTexture.Color3 = blockInfo.color
			end
			frontTexture.Parent = part

			local backTexture = Instance.new("Texture")
			backTexture.Face = Enum.NormalId.Back
			backTexture.Texture = textureId
			backTexture.StudsPerTileU = BLOCK_SIZE * 2
			backTexture.StudsPerTileV = BLOCK_SIZE * 2
			if blockInfo.greyscaleTexture and blockInfo.color then
				backTexture.Color3 = blockInfo.color
			end
			backTexture.Parent = part
		end
	else
		-- 3D cube for regular blocks (like dropped items)
		part.Size = Vector3.new(BLOCK_SIZE, BLOCK_SIZE, BLOCK_SIZE)
		part.Material = blockInfo and blockInfo.material or Enum.Material.Plastic
		part.Color = blockInfo and blockInfo.color or Color3.fromRGB(128, 128, 128)
		part.Transparency = (blockInfo and blockInfo.transparent) and 0.3 or 0
		part.CastShadow = true

		-- Apply textures to all 6 faces (like dropped item blocks)
		local faces = {
			{normalId = Enum.NormalId.Top, faceName = "top"},
			{normalId = Enum.NormalId.Bottom, faceName = "bottom"},
			{normalId = Enum.NormalId.Right, faceName = "side"},
			{normalId = Enum.NormalId.Left, faceName = "side"},
			{normalId = Enum.NormalId.Front, faceName = "side"},
			{normalId = Enum.NormalId.Back, faceName = "side"},
		}

		for _, faceInfo in ipairs(faces) do
			local textureId = TextureManager:GetTextureForBlockFace(blockId, faceInfo.faceName)
			if textureId then
				local texture = Instance.new("Texture")
				texture.Face = faceInfo.normalId
				texture.Texture = textureId
				texture.StudsPerTileU = BLOCK_SIZE
				texture.StudsPerTileV = BLOCK_SIZE
				if blockInfo and blockInfo.greyscaleTexture and blockInfo.color then
					texture.Color3 = blockInfo.color
				end
				texture.Parent = part
			end
		end
	end

	return part, BLOCK_GRIP
end

----------------------------------------------------------------
-- Attach an item to a character's hand
----------------------------------------------------------------

function HeldItemRenderer.AttachItem(character, itemId)
	if not character or not itemId or itemId == 0 then
		return nil
	end

	local hand = getHand(character)
	if not hand then
		return nil
	end

	-- Clear any existing held item first
	HeldItemRenderer.ClearItem(character)

	-- Determine if it's a tool or block
	local isTool = ToolConfig.IsTool(itemId)
	local part, grip

	if isTool then
		local toolType = select(1, ToolConfig.GetBlockProps(itemId))
		if not toolType then return nil end
		part, grip = createToolHandle(itemId, toolType)
	else
		-- It's a block
		local blockInfo = BlockRegistry.Blocks[itemId]
		if not blockInfo then
			warn(string.format("[HeldItemRenderer] Block id %s missing from BlockRegistry; skipping render", tostring(itemId)))
			return nil
		end
		part, grip = createBlockHandle(itemId, blockInfo)
	end

	if not part then return nil end

	-- Tag the part for identification
	part:SetAttribute(HELD_ITEM_TAG, true)
	part:SetAttribute("ItemId", itemId)

	-- Parent to character
	part.Parent = character

	-- Create weld to hand
	local weld = Instance.new("Weld")
	weld.Name = "HeldItemWeld"
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = createGripCFrame(grip)
	weld.Parent = part

	return part
end

----------------------------------------------------------------
-- Check if an item ID is a tool or block
----------------------------------------------------------------

function HeldItemRenderer.IsTool(itemId)
	return ToolConfig.IsTool(itemId)
end

function HeldItemRenderer.IsBlock(itemId)
	if not itemId or itemId == 0 then return false end
	if ToolConfig.IsTool(itemId) then return false end
	local def = BlockRegistry.Blocks[itemId]
	return def ~= nil
end

return HeldItemRenderer

