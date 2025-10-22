--[[
	TextureManager.lua
	Manages block texture assets and provides texture lookup for block faces

	Usage:
		local TextureManager = require(...)
		local textureId = TextureManager:GetTextureForBlockFace(blockId, "top")
]]

local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)

local TextureManager = {}

-- Texture asset registry
-- TODO: Replace these placeholder IDs with actual Roblox asset IDs after uploading textures
-- To upload textures:
--   1. Open Roblox Studio
--   2. View → Asset Manager
--   3. Upload each texture image
--   4. Copy the asset ID (rbxassetid://XXXXXXXXXX)
--   5. Replace the values below
local TEXTURE_ASSETS = {
	-- Grass Block textures
	["grass_top"] = "rbxassetid://82335216994586",    -- Green grass texture (top face)
	["grass_side"] = "rbxassetid://79166604498682",   -- Grass with dirt blend (side faces)

	-- Dirt texture
	["dirt"] = "rbxassetid://116650521021237",         -- Brown dirt texture (all faces)

	-- Stone texture
	["stone"] = "rbxassetid://74732808917832",        -- Stone texture (all faces)

	-- Bedrock texture
	["bedrock"] = "rbxassetid://0",      -- Dark gray/black bedrock texture (all faces)

	-- Oak Log textures
	["oak_log_top"] = "rbxassetid://104794040131472",      -- Oak tree rings texture (top/bottom faces)
	["oak_log_side"] = "rbxassetid://86641407389937",     -- Oak bark texture (side faces)

	-- Leaves texture
	["leaves"] = "rbxassetid://0",       -- Leaf texture with transparency (all faces)

	-- Cross-shaped block textures
	["tall_grass"] = "rbxassetid://0",   -- Tall grass blade texture
	["flower"] = "rbxassetid://0",       -- Flower texture
	["oak_sapling"] = "rbxassetid://87985508905533",  -- Oak sapling texture

	-- Sand texture
	["sand"] = "rbxassetid://135011741792825",  -- Sand texture (all faces)

	-- Stone Bricks texture
	["stone_bricks"] = "rbxassetid://80454802452229",  -- Stone bricks texture (all faces)

	-- Oak Planks texture
	["oak_planks"] = "rbxassetid://97906205267703",  -- Oak planks texture (all faces)

	-- Crafting Table textures
	["crafting_table_top"] = "rbxassetid://118160148189576",     -- Crafting table top/bottom texture
	["crafting_table_side"] = "rbxassetid://129009255077090",    -- Crafting table side texture
	["crafting_table_front"] = "rbxassetid://86645999004835",   -- Crafting table front texture

	-- Cobblestone texture
	["cobblestone"] = "rbxassetid://139692572506095",  -- Cobblestone texture (all faces)

	-- Bricks texture
	["bricks"] = "rbxassetid://131145686654663",  -- Bricks texture (all faces)
}

-- Enable/disable texture system globally (useful for debugging)
local TEXTURES_ENABLED = true

--[[
	Get texture asset ID by texture name
	@param textureName: Texture name (e.g., "grass_top", "dirt", "stone")
	@return: Asset ID string or nil if texture not found
]]
function TextureManager:GetTextureId(textureName: string): string?
	if not TEXTURES_ENABLED then return nil end
	if not textureName then return nil end

	local assetId = TEXTURE_ASSETS[textureName]

	-- Return nil if texture not configured (ID is 0) or missing
	if not assetId or assetId == "rbxassetid://0" then
		return nil
	end

	return assetId
end

--[[
	Get texture asset ID for a specific block face
	@param blockId: Block type ID (from Constants.BlockType)
	@param faceName: Face name ("top", "bottom", "side")
	@return: Asset ID string or nil if texture not available
]]
function TextureManager:GetTextureForBlockFace(blockId: number, faceName: string): string?
	if not TEXTURES_ENABLED then return nil end

	-- Get texture name from BlockRegistry
	local textureName = BlockRegistry:GetTexture(blockId, faceName)
	if not textureName then return nil end

	-- Look up asset ID
	return self:GetTextureId(textureName)
end

--[[
	Enable or disable texture system
	@param enabled: Boolean to enable/disable textures
]]
function TextureManager:SetEnabled(enabled: boolean)
	TEXTURES_ENABLED = enabled
end

--[[
	Check if textures are enabled
	@return: Boolean indicating if textures are enabled
]]
function TextureManager:IsEnabled(): boolean
	return TEXTURES_ENABLED
end

--[[
	Get all configured texture names
	@return: Array of texture names
]]
function TextureManager:GetAllTextureNames(): {string}
	local names = {}
	for name, _ in pairs(TEXTURE_ASSETS) do
		table.insert(names, name)
	end
	return names
end

--[[
	Check if a texture is configured (has a valid asset ID)
	@param textureName: Texture name to check
	@return: Boolean indicating if texture is configured
]]
function TextureManager:IsTextureConfigured(textureName: string): boolean
	local assetId = TEXTURE_ASSETS[textureName]
	return assetId ~= nil and assetId ~= "rbxassetid://0"
end

return TextureManager

