--[[
	ItemModelLoader.lua
	Helper module for loading 3D models from ReplicatedStorage.Tools folder

	This module provides a unified way to look up 3D models for items by:
	1. Item name (e.g., "Apple", "Bread")
	2. Item ID (e.g., "37" for Apple)

	Models can be:
	- A MeshPart directly
	- A Model/Folder containing a MeshPart (searches recursively)

	Returns the MeshPart if found, nil otherwise.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemModelLoader = {}

-- Cache for Tools folder reference
local toolsFolderCache = nil

----------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------

local function getToolsFolder()
	if toolsFolderCache then
		return toolsFolderCache
	end

	-- Prefer direct ReplicatedStorage.Tools
	local folder = ReplicatedStorage:FindFirstChild("Tools")
	if folder then
		toolsFolderCache = folder
		return folder
	end

	-- Fallback: ReplicatedStorage.Assets.Tools
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local direct = assets:FindFirstChild("Tools")
		if direct then
			toolsFolderCache = direct
			return direct
		end
	end

	return nil
end

local function findMeshPartInInstance(instance)
	if not instance then return nil end

	-- If it's a MeshPart directly, return it
	if instance:IsA("MeshPart") then
		return instance
	end

	-- Otherwise, search recursively for a MeshPart
	return instance:FindFirstChildWhichIsA("MeshPart", true)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

--[[
	Get a 3D model template for an item
	@param itemName: string | nil - The item name (e.g., "Apple", "Bread"). If nil, only searches by ID.
	@param itemId: number (optional) - The item ID as fallback (e.g., 37 for Apple)
	@return MeshPart | nil - The MeshPart template if found, nil otherwise
]]
function ItemModelLoader.GetModelTemplate(itemName, itemId)
	local folder = getToolsFolder()
	if not folder then return nil end

	-- Try by item name first (most common)
	if itemName then
		local model = folder:FindFirstChild(itemName)
		if model then
			return findMeshPartInInstance(model)
		end
	end

	-- Try by item ID as fallback
	if itemId then
		local modelById = folder:FindFirstChild(tostring(itemId))
		if modelById then
			return findMeshPartInInstance(modelById)
		end
	end

	return nil
end

--[[
	Check if a 3D model exists for an item
	@param itemName: string - The item name
	@param itemId: number (optional) - The item ID as fallback
	@return boolean - True if model exists, false otherwise
]]
function ItemModelLoader.HasModel(itemName, itemId)
	return ItemModelLoader.GetModelTemplate(itemName, itemId) ~= nil
end

--[[
	Clone a model template for use
	@param itemName: string - The item name
	@param itemId: number (optional) - The item ID as fallback
	@return MeshPart | nil - Cloned MeshPart if found, nil otherwise
]]
function ItemModelLoader.CloneModel(itemName, itemId)
	local template = ItemModelLoader.GetModelTemplate(itemName, itemId)
	if template then
		return template:Clone()
	end
	return nil
end

return ItemModelLoader
