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

-- Debug: Enable to trace model lookups
local DEBUG_MODEL_LOADER = false

-- Cache for Tools folder reference
local toolsFolderCache = nil

----------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------

local function getToolsFolder()
	if toolsFolderCache then
		return toolsFolderCache
	end

	-- Primary: ReplicatedStorage.Assets.Tools
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if assets then
		local toolsFolder = assets:FindFirstChild("Tools")
		if toolsFolder then
			toolsFolderCache = toolsFolder
			return toolsFolder
		end
	end

	-- Fallback: ReplicatedStorage.Tools (legacy)
	local folder = ReplicatedStorage:FindFirstChild("Tools")
	if folder then
		toolsFolderCache = folder
		return folder
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
			if DEBUG_MODEL_LOADER then
				print(string.format("[ItemModelLoader] FOUND model for name='%s' (id=%s)", 
					tostring(itemName), tostring(itemId)))
			end
			return findMeshPartInInstance(model)
		end
	end

	-- Try by item ID as fallback
	if itemId then
		local modelById = folder:FindFirstChild(tostring(itemId))
		if modelById then
			if DEBUG_MODEL_LOADER then
				-- WARN for numeric matches - these could be accidental!
				warn(string.format("[ItemModelLoader] FOUND model by ID='%s' for name='%s' - CHECK IF INTENTIONAL", 
					tostring(itemId), tostring(itemName)))
			end
			return findMeshPartInInstance(modelById)
		end
	end

	-- Debug: Log wheat crop lookups specifically
	if DEBUG_MODEL_LOADER and itemId and type(itemId) == "number" and itemId >= 76 and itemId <= 83 then
		print(string.format("[ItemModelLoader] Wheat crop lookup (id=%d name='%s') - NO MODEL FOUND (correct behavior)", 
			itemId, tostring(itemName)))
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
