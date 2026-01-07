--[[
	ItemRegistry.lua
	CENTRALIZED ITEM MANAGEMENT SYSTEM

	This module provides a unified way to look up item information across the codebase.
	It aggregates data from:
	- BlockRegistry (blocks, ores, ingots, materials)
	- ToolConfig (tools)
	- ArmorConfig (armor)
	- SpawnEggConfig (mob spawn eggs)

	USAGE:
		local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)

		-- Get any item's display info
		local info = ItemRegistry.GetItem(itemId)
		-- Returns: { name, icon, image, type, tier, ... }

		-- Get item image/texture for UI
		local image = ItemRegistry.GetItemImage(itemId)

		-- Check item type
		local isTool = ItemRegistry.IsType(itemId, "tool")
		local isArmor = ItemRegistry.IsType(itemId, "armor")

	ADDING NEW ITEMS:
		1. Add BlockType enum in Constants.lua
		2. Add block definition in BlockRegistry.lua (with textures)
		3. If tool/armor, add to ToolConfig.lua or ArmorConfig.lua
		4. Add crafting recipe in RecipeConfig.lua
		5. That's it! ItemRegistry will automatically find it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Lazy-load to avoid circular dependencies
local Constants, BlockRegistry, ToolConfig, ArmorConfig, SpawnEggConfig

local function ensureLoaded()
	if not Constants then
		Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
		BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
		ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
		ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
		SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
	end
end

local ItemRegistry = {}

-- Item type constants
ItemRegistry.ItemType = {
	BLOCK = "block",
	TOOL = "tool",
	ARMOR = "armor",
	MATERIAL = "material",
	SPAWN_EGG = "spawn_egg",
	UNKNOWN = "unknown"
}

--[[
	Get comprehensive item information
	@param itemId: number - The item ID
	@return table | nil - Item info or nil if not found
]]
function ItemRegistry.GetItem(itemId)
	ensureLoaded()

	if not itemId or itemId == 0 then
		return nil
	end

	-- Check if it's a tool
	local toolInfo = ToolConfig.GetToolInfo(itemId)
	if toolInfo then
		return {
			id = itemId,
			name = toolInfo.name,
			icon = toolInfo.icon,
			image = toolInfo.image,
			type = ItemRegistry.ItemType.TOOL,
			toolType = toolInfo.toolType,
			tier = toolInfo.tier,
			tierName = ToolConfig.GetTierName(toolInfo.tier),
			tierColor = ToolConfig.GetTierColor(toolInfo.tier)
		}
	end

	-- Check if it's armor
	local armorInfo = ArmorConfig.GetArmorInfo(itemId)
	if armorInfo then
		return {
			id = itemId,
			name = armorInfo.name,
			icon = armorInfo.icon,
			image = armorInfo.image,
			type = ItemRegistry.ItemType.ARMOR,
			slot = armorInfo.slot,
			tier = armorInfo.tier,
			tierName = ArmorConfig.GetTierName(armorInfo.tier),
			tierColor = ArmorConfig.GetTierColor(armorInfo.tier),
			defense = armorInfo.defense,
			toughness = armorInfo.toughness,
			setId = armorInfo.setId
		}
	end

	-- Check if it's a spawn egg
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local eggInfo = SpawnEggConfig.GetSpawnEgg(itemId)
		if eggInfo then
			return {
				id = itemId,
				name = eggInfo.name,
				icon = "🥚",
				image = eggInfo.image,
				type = ItemRegistry.ItemType.SPAWN_EGG,
				mobType = eggInfo.mobType
			}
		end
	end

	-- Check if it's a block/material
	local blockDef = BlockRegistry.Blocks[itemId]
	if blockDef then
		local itemType = ItemRegistry.ItemType.BLOCK
		if blockDef.craftingMaterial then
			itemType = ItemRegistry.ItemType.MATERIAL
		end

		-- Get texture as image
		local image = nil
		if blockDef.textures then
			image = blockDef.textures.all or blockDef.textures.side or blockDef.textures.top
		end

		return {
			id = itemId,
			name = blockDef.name,
			icon = "📦",
			image = image,
			type = itemType,
			color = blockDef.color,
			solid = blockDef.solid,
			transparent = blockDef.transparent,
			crossShape = blockDef.crossShape,
			craftingMaterial = blockDef.craftingMaterial
		}
	end

	return nil
end

--[[
	Get just the image/texture for an item (for UI display)
	@param itemId: number - The item ID
	@return string | nil - Image asset ID or nil
]]
function ItemRegistry.GetItemImage(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.image or nil
end

--[[
	Get item name
	@param itemId: number - The item ID
	@return string - Item name or "Unknown"
]]
function ItemRegistry.GetItemName(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.name or "Unknown"
end

--[[
	Check if an item is of a specific type
	@param itemId: number - The item ID
	@param itemType: string - Type to check (use ItemRegistry.ItemType constants)
	@return boolean
]]
function ItemRegistry.IsType(itemId, itemType)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.type == itemType
end

--[[
	Check if an item ID is valid
	@param itemId: number - The item ID
	@return boolean
]]
function ItemRegistry.IsValidItem(itemId)
	return ItemRegistry.GetItem(itemId) ~= nil
end

--[[
	Get the type of an item
	@param itemId: number - The item ID
	@return string - Item type constant
]]
function ItemRegistry.GetItemType(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.type or ItemRegistry.ItemType.UNKNOWN
end

--[[
	Check if item should stack
	@param itemId: number - The item ID
	@return boolean
]]
function ItemRegistry.IsStackable(itemId)
	ensureLoaded()

	-- Tools and armor don't stack (except arrows)
	if ToolConfig.IsTool(itemId) then
		local toolInfo = ToolConfig.GetToolInfo(itemId)
		-- Arrows are stackable
		return toolInfo and toolInfo.toolType == "arrow"
	end

	if ArmorConfig.IsArmor(itemId) then
		return false
	end

	-- Everything else stacks
	return true
end

--[[
	Get max stack size for an item
	@param itemId: number - The item ID
	@return number - Max stack size (1 for tools/armor, 64 for blocks)
]]
function ItemRegistry.GetMaxStackSize(itemId)
	if not ItemRegistry.IsStackable(itemId) then
		return 1
	end
	return 64
end

--[[
	Get tier color for tiered items (tools, armor)
	@param itemId: number - The item ID
	@return Color3 | nil
]]
function ItemRegistry.GetTierColor(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.tierColor or nil
end

--[[
	Debug: Print all registered items
]]
function ItemRegistry.DebugPrintAll()
	ensureLoaded()

	print("=== ItemRegistry Debug ===")

	-- Print tools
	print("\n-- TOOLS --")
	for id, tool in pairs(ToolConfig.Items) do
		print(string.format("  [%d] %s (%s)", id, tool.name, tool.toolType))
	end

	-- Print armor
	print("\n-- ARMOR --")
	for id, armor in pairs(ArmorConfig.Items) do
		print(string.format("  [%d] %s (%s)", id, armor.name, armor.slot))
	end

	-- Print blocks with textures
	print("\n-- BLOCKS/MATERIALS --")
	for id, block in pairs(BlockRegistry.Blocks) do
		if block.textures then
			local texture = block.textures.all or "none"
			print(string.format("  [%d] %s (texture: %s)", id, block.name, tostring(texture):sub(1, 30)))
		end
	end

	print("=== End Debug ===")
end

return ItemRegistry

