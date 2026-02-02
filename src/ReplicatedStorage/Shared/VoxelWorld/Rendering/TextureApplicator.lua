--[[
	TextureApplicator.lua
	Applies textures to all 6 faces of merged block Parts (BOX_MERGE mode)

	Handles:
	- Uniform textures (stone, dirt) - same texture on all faces
	- Per-face textures (grass) - different textures per face
	- UV tiling for merged boxes (e.g., 5×3 merged blocks)

	Usage:
		local TextureApplicator = require(...)
		TextureApplicator:ApplyBoxTextures(part, blockId, widthBlocks, heightBlocks, depthBlocks)
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local TextureManager = require(script.Parent.TextureManager)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local PartPool = require(script.Parent.PartPool)

local TextureApplicator = {}

-- Cache for block texture lookups (blockId -> {faceName -> textureId})
-- local textureCache = {}

--[[
	Apply textures to all 6 faces of a merged box Part

This function creates Texture objects (one for each visible face) and attaches them to the Part.
	Each texture is properly tiled based on the merged box dimensions.

	Example: A 3×2×1 merged grass block box will have:
	  - Top face: grass_top texture tiled 3×1 times
	  - Bottom face: dirt texture tiled 3×1 times
	  - Side faces: grass_side texture tiled appropriately for each face

	@param part: The merged box Part to texture
	@param blockId: Block type ID (from Constants.BlockType)
	@param widthBlocks: Number of blocks along X axis (dx)
	@param heightBlocks: Number of blocks along Y axis (dy)
	@param depthBlocks: Number of blocks along Z axis (dz)
	@param metadata: Optional block metadata for rotation
	@param visibleFaces: Optional table mask of face visibility; keys may be Enum.NormalId or face name strings. If a key is explicitly false, that face will be skipped.
]]
--[[
	Get rotated face name based on metadata
	@param faceName: Original face name ("front", "back", "left", "right")
	@param rotation: Rotation value from metadata (0-3)
	@return: Rotated face name
]]
local function getRotatedFaceName(faceName, rotation)

	-- If no rotation or not a directional face, return as is
	if not rotation or rotation == 0 or (faceName ~= "front" and faceName ~= "back" and faceName ~= "left" and faceName ~= "right") then
		return faceName
	end

	-- Rotation indices: 0=North(-Z), 1=East(+X), 2=South(+Z), 3=West(-X)
	-- Roblox Front face is -Z, so rotation 0 (North) keeps "front" on Front
	local faceToDir = {front = 2, right = 1, back = 0, left = 3}  -- In rotation units
	local dirToFace = {"back", "right", "front", "left"}

	local currentDir = faceToDir[faceName]
	if not currentDir then return faceName end

	-- Apply rotation
	local newDir = (currentDir + rotation) % 4
	return dirToFace[newDir + 1]
end

function TextureApplicator:ApplyBoxTextures(
	part: BasePart,
	blockId: number,
	widthBlocks: number,
	heightBlocks: number,
	depthBlocks: number,
	metadata: number?,
	visibleFaces: table?
)
	if not part then
		warn("[TextureApplicator] ApplyBoxTextures called with nil part")
		return
	end

	local bs = Constants.BLOCK_SIZE

	-- Define all 6 faces with their correct tiling requirements
	-- Tiling is based on how many blocks span each dimension of the face
	local faces = {
		{
			normalId = Enum.NormalId.Top,
			faceName = "top",
			tilingU = widthBlocks,   -- X direction (width)
			tilingV = depthBlocks,   -- Z direction (depth)
		},
		{
			normalId = Enum.NormalId.Bottom,
			faceName = "bottom",
			tilingU = widthBlocks,   -- X direction (width)
			tilingV = depthBlocks,   -- Z direction (depth)
		},
		{
			normalId = Enum.NormalId.Right,
			faceName = "side",
			tilingU = depthBlocks,   -- Z direction (depth)
			tilingV = heightBlocks,  -- Y direction (height)
		},
		{
			normalId = Enum.NormalId.Left,
			faceName = "side",
			tilingU = depthBlocks,   -- Z direction (depth)
			tilingV = heightBlocks,  -- Y direction (height)
		},
		{
			normalId = Enum.NormalId.Front,
			faceName = "side",
			tilingU = widthBlocks,   -- X direction (width)
			tilingV = heightBlocks,  -- Y direction (height)
		},
		{
			normalId = Enum.NormalId.Back,
			faceName = "side",
			tilingU = widthBlocks,   -- X direction (width)
			tilingV = heightBlocks,  -- Y direction (height)
		},
	}

	-- Get rotation from metadata if provided
	local rotation = 0
	if metadata and metadata ~= 0 then
		rotation = Constants.GetRotation(metadata)
	end

	-- Cache block definition lookup (used for greyscale texture check)
	local def = BlockRegistry:GetBlock(blockId)
	local needsColorTint = def and def.greyscaleTexture
	local tintColor = needsColorTint and (def.color or part.Color) or nil

	-- Apply texture to each face using pooled textures
	for i = 1, 6 do
		local faceInfo = faces[i]

		-- Fast visibility check - only check NormalId key (most common case)
		local isVisible = true
		if visibleFaces then
			local v = visibleFaces[faceInfo.normalId]
			if v == false then
				isVisible = false
			end
		end

		if isVisible then
			-- Apply rotation to get the correct texture for this face
			local rotatedFaceName = getRotatedFaceName(faceInfo.faceName, rotation)
			local textureId = TextureManager:GetTextureForBlockFace(blockId, rotatedFaceName)

			if textureId then
				-- Use pooled texture (much faster than Instance.new)
				local texture = PartPool.AcquireTexture()
				texture.Name = "BlockTexture"
				texture.Face = faceInfo.normalId
				texture.Texture = textureId
				texture.StudsPerTileU = bs
				texture.StudsPerTileV = bs

				-- Apply tint if needed
				if tintColor then
					texture.Color3 = tintColor
				end

				texture.Parent = part
			end
		end
	end
end

--[[
	Apply textures to a single block Part (simplified version for viewports)

	@param part: The single block Part to texture
	@param textureConfig: Table with texture names for each face (from BlockRegistry)
	@param size: Vector3 size of the block (for StudsPerTile calculation)
]]
function TextureApplicator.ApplyTexturesToPart(part, textureConfig, size)
	if not part or not textureConfig then return end

	local bs = size.X -- Assume cubic for now

	-- Define all 6 faces
	local faces = {
		{normalId = Enum.NormalId.Top, faceName = "top"},
		{normalId = Enum.NormalId.Bottom, faceName = "bottom"},
		{normalId = Enum.NormalId.Right, faceName = "side"},
		{normalId = Enum.NormalId.Left, faceName = "side"},
		{normalId = Enum.NormalId.Front, faceName = "side"},
		{normalId = Enum.NormalId.Back, faceName = "side"},
	}

	-- Handle texture configuration formats
	local getTextureName = function(faceName)
		-- If textureConfig has "all", use that for all faces
		if textureConfig.all then
			return textureConfig.all
		end
		-- Otherwise, try specific face name
		return textureConfig[faceName]
	end

	-- Apply texture to each face
	for _, faceInfo in ipairs(faces) do
		local textureName = getTextureName(faceInfo.faceName)
		if textureName then
			local textureId = TextureManager:GetTextureId(textureName)
			if textureId then
				local texture = Instance.new("Texture")
				texture.Name = "BlockTexture_" .. faceInfo.faceName
				texture.Face = faceInfo.normalId
				texture.Texture = textureId
				texture.StudsPerTileU = bs
				texture.StudsPerTileV = bs
				texture.Transparency = 0
				texture.Parent = part
			end
		end
	end
end

--[[
	Remove all texture objects from a Part
	Useful for cleaning up or re-applying textures

	@param part: The Part to clean textures from
]]
function TextureApplicator:ClearTextures(part: BasePart)
	if not part then return end

	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") then
			child:Destroy()
		end
	end
end

--[[
	Debug function: Print texture information for a Part
	Useful for troubleshooting texture issues

	@param part: The Part to debug
]]
function TextureApplicator:DebugPrintTextures(part: BasePart)
	if not part then
		print("[TextureApplicator] Debug: Part is nil")
		return
	end

	print(string.format("[TextureApplicator] Debug for Part '%s':", part.Name))
	print(string.format("  Size: (%.2f, %.2f, %.2f)", part.Size.X, part.Size.Y, part.Size.Z))

	local textures = {}
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") then
			table.insert(textures, child)
		end
	end

	print(string.format("  Textures: %d found", #textures))

	for _, texture in ipairs(textures) do
		print(string.format("    - %s: Face=%s, Asset=%s, Tiling=(%.1f, %.1f)",
			texture.Name,
			texture.Face.Name,
			texture.Texture,
			texture.StudsPerTileU,
			texture.StudsPerTileV
		))
	end
end

return TextureApplicator

