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

	-- Water textures
	["water_still"] = "rbxassetid://101973122634153",
	["water_overlay"] = "rbxassetid://139385214440445",
	["water_flow"] = "rbxassetid://92724971522269",

	-- Cross-shaped block textures (Minecraft naming convention)
	-- Two-block tall grass: lower block shows base, upper block shows tips
	["tall_grass_bottom"] = "rbxassetid://72372576895806",   -- Lower block texture (base/roots)
	["tall_grass_top"] = "rbxassetid://72700603792788",      -- Upper block texture (tips)
	["tall_grass"] = "rbxassetid://72372576895806",          -- Alias for single-block short grass
	["flower"] = "rbxassetid://87572508373911",       -- Flower texture (default: poppy)
	["flower_poppy"] = "rbxassetid://87572508373911", -- Poppy flower texture
	["flower_azure_bluet"] = "rbxassetid://87572508373911", -- Azure Bluet (using poppy for now, needs separate texture)
	["flower_rose_bush_top"] = "rbxassetid://80318970197042", -- Rose Bush top texture
	["flower_rose_bush_bottom"] = "rbxassetid://96465374166553", -- Rose Bush bottom texture
	["flower_lilac_top"] = "rbxassetid://109233564104296", -- Lilac top texture
	["flower_lilac_bottom"] = "rbxassetid://128080255483654", -- Lilac bottom texture
	["oak_sapling"] = "rbxassetid://87985508905533",  -- Oak sapling texture
	["stick"] = "rbxassetid://0",        -- Stick texture (crafting material)

	-- Sand texture
	["sand"] = "rbxassetid://135011741792825",  -- Sand texture (all faces)

	-- Stone Bricks texture
	["stone_bricks"] = "rbxassetid://80454802452229",  -- Stone bricks texture (all faces)

	-- Oak Planks texture
	["oak_planks"] = "rbxassetid://97906205267703",  -- Oak planks texture (all faces)

	-- Spruce textures
	["spruce_sapling"] = "rbxassetid://114598273516558",
	["spruce_planks"] = "rbxassetid://105755940066085",
	["spruce_log_top"] = "rbxassetid://72028606598650",
	["spruce_log_side"] = "rbxassetid://137442233699907",

	-- Jungle textures
	["jungle_sapling"] = "rbxassetid://74526907413316",
	["jungle_planks"] = "rbxassetid://129276345517813",
	["jungle_log_top"] = "rbxassetid://110736818391988",
	["jungle_log_side"] = "rbxassetid://134270574628736",

	-- Dark Oak textures
	["dark_oak_sapling"] = "rbxassetid://79970815232509",
	["dark_oak_planks"] = "rbxassetid://73932476747091",
	["dark_oak_log_top"] = "rbxassetid://136417573996102",
	["dark_oak_log_side"] = "rbxassetid://84761900511766",

	-- Birch textures
	["birch_sapling"] = "rbxassetid://92064362873503",
	["birch_planks"] = "rbxassetid://136512317998173",
	["birch_log_top"] = "rbxassetid://95413916416058",
	["birch_log_side"] = "rbxassetid://110526248592215",

	-- Acacia textures
	["acacia_sapling"] = "rbxassetid://71757022067162",
	["acacia_planks"] = "rbxassetid://85841942704300",
	["acacia_log_top"] = "rbxassetid://136532380257460",
	["acacia_log_side"] = "rbxassetid://101311361454505",

	-- Crafting Table textures
	["crafting_table_top"] = "rbxassetid://118160148189576",     -- Crafting table top/bottom texture
	["crafting_table_side"] = "rbxassetid://129009255077090",    -- Crafting table side texture
	["crafting_table_front"] = "rbxassetid://86645999004835",   -- Crafting table front texture

	-- Cobblestone texture
	["cobblestone"] = "rbxassetid://139692572506095",  -- Cobblestone texture (all faces)

	-- Bricks texture
	["bricks"] = "rbxassetid://131145686654663",  -- Bricks texture (all faces)

	-- ═══════════════════════════════════════════════════════════════════════
	-- MELON & PUMPKIN
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: MELON and PUMPKIN blocks use direct rbxassetid:// in BlockRegistry
	-- These textures are for stems (which map to TALL_GRASS block type)
	["melon_stem"] = "rbxassetid://131285032012914",  -- Melon stem (cross-shaped)
	["pumpkin_stem"] = "rbxassetid://103264904816321",  -- Pumpkin stem (cross-shaped)
	["carved_pumpkin"] = "rbxassetid://134873735074293",  -- Carved Pumpkin texture
	["jack_o_lantern"] = "rbxassetid://100828620621190",  -- Jack o'Lantern front texture

	-- ═══════════════════════════════════════════════════════════════════════
	-- CACTUS (regular block with multiple faces)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: CACTUS already uses direct rbxassetid:// in BlockRegistry
	-- These are provided for reference/consistency
	["cactus_top"] = "rbxassetid://94563015961260",  -- Cactus top texture
	["cactus_side"] = "rbxassetid://79094656952253",  -- Cactus side texture
	["cactus_bottom"] = "rbxassetid://97822724502105",  -- Cactus bottom texture

	-- ═══════════════════════════════════════════════════════════════════════
	-- PLANTS & VEGETATION (cross-shaped)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: SUGAR_CANE already uses direct rbxassetid:// in BlockRegistry
	["sugar_cane"] = "rbxassetid://128037896541445",  -- Sugar Cane (cross-shaped)

	-- ═══════════════════════════════════════════════════════════════════════
	-- HAY_BLOCK (regular block with multiple faces)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: HAY_BLOCK already uses direct rbxassetid:// in BlockRegistry
	["hay_block_top"] = "rbxassetid://114055682157370",  -- Hay Block top texture
	["hay_block_side"] = "rbxassetid://92792702867171",  -- Hay Block side texture

	-- ═══════════════════════════════════════════════════════════════════════
	-- DEAD_BUSH (cross-shaped)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: DEAD_BUSH already uses direct rbxassetid://116161927933610 in BlockRegistry
	-- Missing texture - user did not provide one

	-- ═══════════════════════════════════════════════════════════════════════
	-- MUSHROOMS (cross-shaped and blocks)
	-- ═══════════════════════════════════════════════════════════════════════
	-- Note: All mushrooms already use direct rbxassetid:// in BlockRegistry
	["brown_mushroom"] = "rbxassetid://78203109427997",  -- Brown Mushroom (cross-shaped)
	["red_mushroom"] = "rbxassetid://130349192960951",  -- Red Mushroom (cross-shaped)
	["brown_mushroom_block"] = "rbxassetid://125837820790379",  -- Brown Mushroom Block
	["red_mushroom_block"] = "rbxassetid://98579956986334",  -- Red Mushroom Block
	["mushroom_stem"] = "rbxassetid://110653819771271",  -- Mushroom Stem
}

-- Enable/disable texture system globally (useful for debugging)
local TEXTURES_ENABLED = true

--[[
	Get texture asset ID by texture name or pass through raw asset IDs
	@param textureName: Texture name (e.g., "grass_top", "dirt", "stone") OR raw asset ID ("rbxassetid://...")
	@return: Asset ID string or nil if texture not found
]]
function TextureManager:GetTextureId(textureName: string): string?
	if not TEXTURES_ENABLED then return nil end
	if not textureName then return nil end

	-- If it's already a raw asset ID, pass it through
	if string.match(textureName, "^rbxassetid://") then
		-- Don't return if it's the placeholder "rbxassetid://0"
		if textureName == "rbxassetid://0" then
			return nil
		end
		return textureName
	end

	-- Otherwise look it up in the texture assets table
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
	@param textureName: Texture name or raw asset ID to check
	@return: Boolean indicating if texture is configured
]]
function TextureManager:IsTextureConfigured(textureName: string): boolean
	-- If it's already a raw asset ID, check if it's valid
	if string.match(textureName, "^rbxassetid://") then
		return textureName ~= "rbxassetid://0"
	end

	-- Otherwise look it up in the texture assets table
	local assetId = TEXTURE_ASSETS[textureName]
	return assetId ~= nil and assetId ~= "rbxassetid://0"
end

--[[
	Collect all texture asset IDs referenced by BlockRegistry (including raw IDs)
	@return: Array of unique asset ID strings (rbxassetid://...)
]]
function TextureManager:GetAllBlockTextureAssetIds(): {string}
	local results = {}
	local seen = {}

	for _, def in pairs(BlockRegistry.Blocks or {}) do
		local tx = def and def.textures
		if tx then
			for _, textureName in pairs(tx) do
				local assetId = self:GetTextureId(textureName)
				if assetId and not seen[assetId] then
					seen[assetId] = true
					table.insert(results, assetId)
				end
			end
		end
	end

	return results
end

--[[
	Get texture asset IDs for specific block IDs (optimized for schematic palettes)
	@param blockIds: Array of block type IDs (from Constants.BlockType)
	@return: Array of unique asset ID strings (rbxassetid://...)
]]
function TextureManager:GetTextureAssetIdsForBlocks(blockIds: {number}): {string}
	local results = {}
	local seen = {}
	local blockIdSet = {}

	-- Create lookup set for faster checking
	for _, blockId in ipairs(blockIds) do
		blockIdSet[blockId] = true
	end

	-- Only get textures for blocks in the provided list
	for blockId, _ in pairs(blockIdSet) do
		local def = BlockRegistry:GetBlock(blockId)
		if def and def.textures then
			-- Handle all texture types: "all", face-specific, and half-specific (lower/upper)
			local textureNames = {}
			if def.textures.all then
				table.insert(textureNames, def.textures.all)
			end
			-- Face-specific textures (for regular blocks)
			if def.textures.top then
				table.insert(textureNames, def.textures.top)
			end
			if def.textures.bottom then
				table.insert(textureNames, def.textures.bottom)
			end
			if def.textures.side then
				table.insert(textureNames, def.textures.side)
			end
			-- Half-specific textures (for two-block tall plants like tall grass)
			if def.textures.lower then
				table.insert(textureNames, def.textures.lower)
			end
			if def.textures.upper then
				table.insert(textureNames, def.textures.upper)
			end

			for _, textureName in ipairs(textureNames) do
				local assetId = self:GetTextureId(textureName)
				if assetId and not seen[assetId] then
					seen[assetId] = true
					table.insert(results, assetId)
				end
			end
		end
	end

	return results
end

return TextureManager

