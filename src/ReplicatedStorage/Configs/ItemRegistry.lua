--[[
	ItemRegistry.lua
	CENTRALIZED ITEM MANAGEMENT SYSTEM

	This module provides a unified way to look up item information.
	It aggregates data from ItemDefinitions (single source of truth) and BlockRegistry.

	USAGE:
		local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)

		-- Get item info
		local info = ItemRegistry.GetItem(itemId)
		local name = ItemRegistry.GetItemName(itemId)
		local category = ItemRegistry.GetCategory(itemId)

		-- Check category
		if ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.FOOD then
			-- eat it
		end
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Lazy-load to avoid circular dependencies
local ItemDefinitions, BlockRegistry, SpawnEggConfig, FoodConfig

local function ensureLoaded()
	if not ItemDefinitions then
		ItemDefinitions = require(ReplicatedStorage.Configs.ItemDefinitions)
		BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
		SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
		FoodConfig = require(ReplicatedStorage.Shared.FoodConfig)
	end
end

local ItemRegistry = {}

-- Re-export Category from ItemDefinitions
ItemRegistry.Category = {
	TOOL = "tool",
	WEAPON = "weapon",
	RANGED = "ranged",
	ARMOR = "armor",
	ARROW = "arrow",
	FOOD = "food",
	MATERIAL = "material",
	DYE = "dye",
	MOB_EGG = "mob_egg",
	BLOCK = "block",
	UNKNOWN = "unknown",
}

-- Legacy type mapping (for backward compatibility)
ItemRegistry.ItemType = {
	BLOCK = "block",
	TOOL = "tool",
	ARMOR = "armor",
	MATERIAL = "material",
	SPAWN_EGG = "mob_egg",
	UNKNOWN = "unknown"
}

--[[
	Get item category
	@param itemId: number
	@return string - Category constant
]]
function ItemRegistry.GetCategory(itemId)
	ensureLoaded()
	if not itemId or itemId == 0 then return ItemRegistry.Category.UNKNOWN end

	-- Check ItemDefinitions first (tools, weapons, armor, etc.)
	local item = ItemDefinitions.GetById(itemId)
	if item and item.category then
		return item.category
	end

	-- Check spawn eggs
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		return ItemRegistry.Category.MOB_EGG
	end

	-- Check BlockRegistry for blocks
	local blockDef = BlockRegistry.Blocks[itemId]
	if blockDef then
		if blockDef.craftingMaterial then
			return ItemRegistry.Category.MATERIAL
		end
		return ItemRegistry.Category.BLOCK
	end

	return ItemRegistry.Category.UNKNOWN
end

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

	-- Check ItemDefinitions first
	local item = ItemDefinitions.GetById(itemId)
	if item then
		return {
			id = itemId,
			name = item.name,
			image = item.texture,
			category = item.category,
			type = item.category, -- Legacy compatibility
			tier = item.tier,
			tierName = item.tier and ItemDefinitions.GetTierName(item.tier),
			tierColor = item.tier and ItemDefinitions.GetTierColor(item.tier),
			-- Category-specific fields
			toolType = item.toolType,
			weaponType = item.weaponType,
			slot = item.slot,
			defense = item.defense,
			toughness = item.toughness,
			hunger = item.hunger,
			saturation = item.saturation,
			color = item.color,
		}
	end

	-- Check spawn eggs
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local eggInfo = SpawnEggConfig.GetSpawnEgg(itemId)
		if eggInfo then
			return {
				id = itemId,
				name = eggInfo.name,
				image = eggInfo.image,
				category = ItemRegistry.Category.MOB_EGG,
				type = ItemRegistry.ItemType.SPAWN_EGG,
				mobType = eggInfo.mobType
			}
		end
	end

	-- Check BlockRegistry
	local blockDef = BlockRegistry.Blocks[itemId]
	if blockDef then
		local category = blockDef.craftingMaterial and ItemRegistry.Category.MATERIAL or ItemRegistry.Category.BLOCK

		local image = nil
		if blockDef.textures then
			image = blockDef.textures.all or blockDef.textures.side or blockDef.textures.top
		end

		return {
			id = itemId,
			name = blockDef.name,
			image = image,
			category = category,
			type = category,
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
	Get item name
	@param itemId: number
	@return string - Item name or "Unknown"
]]
function ItemRegistry.GetItemName(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.name or "Unknown"
end

--[[
	Get item image/texture for UI
	@param itemId: number
	@return string | nil
]]
function ItemRegistry.GetItemImage(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.image or nil
end

--[[
	Check if item is of a specific category
	@param itemId: number
	@param category: string
	@return boolean
]]
function ItemRegistry.IsCategory(itemId, category)
	return ItemRegistry.GetCategory(itemId) == category
end

-- Legacy: Check if item is of a specific type
function ItemRegistry.IsType(itemId, itemType)
	local info = ItemRegistry.GetItem(itemId)
	return info and (info.type == itemType or info.category == itemType)
end

--[[
	Check if item ID is valid
	@param itemId: number
	@return boolean
]]
function ItemRegistry.IsValidItem(itemId)
	return ItemRegistry.GetItem(itemId) ~= nil
end

--[[
	Get item type (legacy)
	@param itemId: number
	@return string
]]
function ItemRegistry.GetItemType(itemId)
	return ItemRegistry.GetCategory(itemId)
end

--[[
	Check if item should stack
	@param itemId: number
	@return boolean
]]
function ItemRegistry.IsStackable(itemId)
	ensureLoaded()
	return ItemDefinitions.IsStackable(itemId)
end

--[[
	Get max stack size
	@param itemId: number
	@return number
]]
function ItemRegistry.GetMaxStackSize(itemId)
	ensureLoaded()
	return ItemDefinitions.GetMaxStack(itemId)
end

--[[
	Get tier color
	@param itemId: number
	@return Color3 | nil
]]
function ItemRegistry.GetTierColor(itemId)
	local info = ItemRegistry.GetItem(itemId)
	return info and info.tierColor or nil
end

--[[
	Category check shortcuts
]]
function ItemRegistry.IsTool(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.TOOL end
function ItemRegistry.IsWeapon(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.WEAPON end
function ItemRegistry.IsRanged(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.RANGED end
function ItemRegistry.IsArmor(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.ARMOR end
function ItemRegistry.IsArrow(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.ARROW end
function ItemRegistry.IsMaterial(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.MATERIAL end
function ItemRegistry.IsDye(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.DYE end
function ItemRegistry.IsMobEgg(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.MOB_EGG end
function ItemRegistry.IsBlock(itemId) return ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.BLOCK end

-- Food check includes both ItemDefinitions and FoodConfig
function ItemRegistry.IsFood(itemId)
	ensureLoaded()
	if ItemRegistry.GetCategory(itemId) == ItemRegistry.Category.FOOD then return true end
	return FoodConfig.IsFood(itemId)
end

--[[
	Check if item is combat-related (deals damage)
]]
function ItemRegistry.IsCombatItem(itemId)
	local cat = ItemRegistry.GetCategory(itemId)
	return cat == ItemRegistry.Category.WEAPON or cat == ItemRegistry.Category.RANGED or cat == ItemRegistry.Category.TOOL
end

--[[
	Check if item is held in hand (not placed in world)
]]
function ItemRegistry.IsHeldItem(itemId)
	local cat = ItemRegistry.GetCategory(itemId)
	return cat ~= ItemRegistry.Category.BLOCK
end

--[[
	Debug: Print all registered items
]]
function ItemRegistry.DebugPrintAll()
	ensureLoaded()

	print("=== ItemRegistry Debug ===")

	local counts = {}
	for _, cat in pairs(ItemRegistry.Category) do
		counts[cat] = 0
	end

	-- Count by category
	for _, categoryTable in ipairs(ItemDefinitions.AllCategories) do
		for _, item in pairs(categoryTable) do
			local cat = item.category or "unknown"
			counts[cat] = (counts[cat] or 0) + 1
		end
	end

	print("\n-- ITEM COUNTS BY CATEGORY --")
	for cat, count in pairs(counts) do
		if count > 0 then
			print(string.format("  %s: %d", cat, count))
		end
	end

	print("=== End Debug ===")
end

return ItemRegistry
