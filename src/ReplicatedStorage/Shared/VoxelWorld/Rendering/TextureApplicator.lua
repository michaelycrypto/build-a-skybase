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

local TextureApplicator = {}

--[[
	Apply textures to all 6 faces of a merged box Part

	This function creates 6 Texture objects (one for each face) and attaches them to the Part.
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
]]
--[[
	Get rotated face name based on metadata
	@param faceName: Original face name ("front", "back", "left", "right")
	@param rotation: Rotation value from metadata (0-3)
	@return: Rotated face name
]]
local function getRotatedFaceName(faceName, rotation)
	local Constants = require(script.Parent.Parent.Core.Constants)

	-- If no rotation or not a directional face, return as is
	if not rotation or rotation == 0 or (faceName ~= "front" and faceName ~= "back" and faceName ~= "left" and faceName ~= "right") then
		return faceName
	end

	-- Map faces to directions: North=+Z, East=+X, South=-Z, West=-X
	-- Front face default is South (-Z) in Minecraft convention
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
	metadata: number?
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
		local Constants = require(script.Parent.Parent.Core.Constants)
		rotation = Constants.GetRotation(metadata)
	end

	-- Apply texture to each face
	local texturesApplied = 0
	for _, faceInfo in ipairs(faces) do
		-- Apply rotation to get the correct texture for this face
		local rotatedFaceName = getRotatedFaceName(faceInfo.faceName, rotation)
		local textureId = TextureManager:GetTextureForBlockFace(blockId, rotatedFaceName)

		if textureId then
			local texture = Instance.new("Texture")
			texture.Name = "BlockTexture_" .. faceInfo.faceName
			texture.Face = faceInfo.normalId
			texture.Texture = textureId

			--[[
				UV TILING: 4 studs per texture tile (one texture per cell)

				BLOCK_SIZE = 4 studs per cell
				StudsPerTileU/V = 4 means texture repeats every 4 studs

				Examples:
				- 1 block (4 studs): texture shows 1 time
				- 3 blocks (12 studs): texture repeats 3 times
				- 5 blocks (20 studs): texture repeats 5 times

				This ensures sharp, non-stretched textures on merged boxes.
				DO NOT multiply by tilingU/V - that would stretch the texture!
			--]]
			texture.StudsPerTileU = bs  -- 4 studs = 1 texture tile
			texture.StudsPerTileV = bs  -- 4 studs = 1 texture tile

			-- Texture is opaque (Part.Transparency controls overall visibility)
			texture.Transparency = 0

			-- Optional: Set texture color to match part color for tinting
			-- texture.Color3 = part.Color

			texture.Parent = part
			texturesApplied = texturesApplied + 1
		end
	end

	-- Debug output (can be removed in production)
	if texturesApplied == 0 then
		-- No textures applied - this is normal if textures aren't configured yet
		-- or if the block type doesn't have texture definitions
	elseif texturesApplied < 6 then
		-- Some textures missing - might indicate incomplete texture configuration
		warn(string.format("[TextureApplicator] Only %d/6 textures applied to block %d", texturesApplied, blockId))
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

