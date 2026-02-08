--[[
	BlockEntityLoader.lua
	Helper module for loading 3D entity models from ReplicatedStorage.Assets.BlockEntities

	This module provides a unified way to look up 3D entity models for special blocks
	like beds, chests, doors, signs, etc. that cannot be represented as simple cubes.

	Entity models are looked up by:
	1. Entity name in Assets.BlockEntities (e.g., "Chest", "Anvil")
	2. Fallback to Assets.Tools for items that are also blocks (e.g., saplings)

	Models can be:
	- A MeshPart directly
	- A Model containing multiple parts (for complex entities)

	Returns the entity template if found, nil otherwise.
	
	NOTE: For saplings, world placement uses BlockEntities (via entityName),
	while held/dropped items use Assets.Tools (via ItemModelLoader).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BlockEntityLoader = {}

-- Cache for folder references
local entitiesFolderCache = nil
local toolsFolderCache = nil

----------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------

local DEBUG_ENTITY_LOADER = false -- Set to true to enable debug prints

local function getEntitiesFolder()
	if entitiesFolderCache then
		return entitiesFolderCache
	end

	-- Primary: ReplicatedStorage.Assets.BlockEntities
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if DEBUG_ENTITY_LOADER then
		print("[BlockEntityLoader] Looking for Assets folder:", assets and "FOUND" or "NOT FOUND")
	end
	
	if assets then
		local entitiesFolder = assets:FindFirstChild("BlockEntities")
		if DEBUG_ENTITY_LOADER then
			print("[BlockEntityLoader] Looking for BlockEntities folder:", entitiesFolder and "FOUND" or "NOT FOUND")
			if entitiesFolder then
				print("[BlockEntityLoader] BlockEntities contents:")
				for _, child in ipairs(entitiesFolder:GetChildren()) do
					print("  -", child.Name, "(" .. child.ClassName .. ")")
				end
			end
		end
		if entitiesFolder then
			entitiesFolderCache = entitiesFolder
			return entitiesFolder
		end
	end

	-- Fallback: ReplicatedStorage.BlockEntities (legacy)
	local folder = ReplicatedStorage:FindFirstChild("BlockEntities")
	if DEBUG_ENTITY_LOADER then
		print("[BlockEntityLoader] Fallback - Looking for ReplicatedStorage.BlockEntities:", folder and "FOUND" or "NOT FOUND")
	end
	if folder then
		entitiesFolderCache = folder
		return folder
	end

	if DEBUG_ENTITY_LOADER then
		warn("[BlockEntityLoader] No BlockEntities folder found!")
	end
	return nil
end

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

local function findPrimaryMeshPart(instance)
	if not instance then return nil end

	-- If it's a MeshPart directly, return it
	if instance:IsA("MeshPart") then
		return instance
	end

	-- For Models, find the PrimaryPart or first MeshPart
	if instance:IsA("Model") then
		if instance.PrimaryPart and instance.PrimaryPart:IsA("MeshPart") then
			return instance.PrimaryPart
		end
	end

	-- Otherwise, search recursively for a MeshPart
	return instance:FindFirstChildWhichIsA("MeshPart", true)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

--[[
	Get the raw entity template (Model, MeshPart, or Folder)
	@param entityName: string - The entity name (e.g., "Chest", "Anvil", "Oak Sapling")
	@return Instance | nil - The entity template if found, nil otherwise
	
	Lookup order:
	1. Assets.BlockEntities (primary - for world placement)
	2. Assets.Tools (fallback - for saplings that share models)
	
	This allows saplings to use the same model from Assets.Tools for world placement
	if no dedicated BlockEntities model exists.
]]
function BlockEntityLoader.GetEntityTemplate(entityName, _blockId)
	if not entityName then
		return nil
	end

	-- First, try BlockEntities folder (primary for world placement)
	local entitiesFolder = getEntitiesFolder()
	if entitiesFolder then
		local entity = entitiesFolder:FindFirstChild(entityName)
		if DEBUG_ENTITY_LOADER then
			print("[BlockEntityLoader] Looking for entity '" .. tostring(entityName) .. "' in BlockEntities:", entity and "FOUND" or "NOT FOUND")
		end
		if entity then
			return entity
		end
	end

	-- Fallback: try Tools folder (for saplings that share models between held/world)
	local toolsFolder = getToolsFolder()
	if toolsFolder then
		local entity = toolsFolder:FindFirstChild(entityName)
		if DEBUG_ENTITY_LOADER then
			print("[BlockEntityLoader] Looking for entity '" .. tostring(entityName) .. "' in Tools (fallback):", entity and "FOUND" or "NOT FOUND")
		end
		if entity then
			return entity
		end
	end

	if DEBUG_ENTITY_LOADER then
		warn("[BlockEntityLoader] GetEntityTemplate: No entity found for", entityName)
	end
	return nil
end

--[[
	Get the primary MeshPart from an entity template
	@param entityName: string - The entity name
	@return MeshPart | nil - The primary MeshPart if found, nil otherwise
]]
function BlockEntityLoader.GetMeshPart(entityName)
	local template = BlockEntityLoader.GetEntityTemplate(entityName)
	return findPrimaryMeshPart(template)
end

--[[
	Check if a block entity exists
	@param entityName: string - The entity name
	@return boolean - True if entity exists, false otherwise
]]
function BlockEntityLoader.HasEntity(entityName)
	return BlockEntityLoader.GetEntityTemplate(entityName) ~= nil
end

--[[
	Clone an entity template for use
	@param entityName: string - The entity name
	@return Instance | nil - Cloned entity if found, nil otherwise
]]
function BlockEntityLoader.CloneEntity(entityName)
	local template = BlockEntityLoader.GetEntityTemplate(entityName)
	if template then
		return template:Clone()
	end
	return nil
end

--[[
	Clone and prepare an entity for world placement
	@param entityName: string - The entity name
	@param position: Vector3 - World position to place the entity
	@param rotation: number (optional) - Y-axis rotation in degrees (0, 90, 180, 270)
	@return Instance | nil - Positioned entity if found, nil otherwise
]]
function BlockEntityLoader.CreateWorldEntity(entityName, position, rotation)
	local entity = BlockEntityLoader.CloneEntity(entityName)
	if not entity then return nil end

	rotation = rotation or 0
	local rotationCFrame = CFrame.Angles(0, math.rad(rotation), 0)
	local positionCFrame = CFrame.new(position)

	if entity:IsA("Model") then
		-- For Models, use PivotTo
		entity:PivotTo(positionCFrame * rotationCFrame)
	elseif entity:IsA("BasePart") then
		-- For single parts, set CFrame directly
		entity.CFrame = positionCFrame * rotationCFrame
	end

	return entity
end

--[[
	Clone and prepare an entity for dropped item display (scaled down)
	@param entityName: string - The entity name
	@param scale: number (optional) - Scale factor (default 0.5)
	@return Instance | nil - Scaled entity if found, nil otherwise
]]
function BlockEntityLoader.CreateDroppedEntity(entityName, scale)
	local entity = BlockEntityLoader.CloneEntity(entityName)
	if not entity then return nil end

	scale = scale or 0.5

	if entity:IsA("Model") then
		-- Scale the model
		entity:ScaleTo(scale)
	elseif entity:IsA("BasePart") then
		-- Scale the part
		entity.Size = entity.Size * scale
	end

	return entity
end

--[[
	Clone and prepare an entity for held item display
	@param entityName: string - The entity name
	@param scale: number (optional) - Scale factor (default 0.4)
	@return Instance | nil - Scaled entity if found, nil otherwise
]]
function BlockEntityLoader.CreateHeldEntity(entityName, scale)
	local entity = BlockEntityLoader.CloneEntity(entityName)
	if not entity then return nil end

	scale = scale or 0.4

	if entity:IsA("Model") then
		entity:ScaleTo(scale)
	elseif entity:IsA("BasePart") then
		entity.Size = entity.Size * scale
	end

	-- Disable collisions for held items
	if entity:IsA("BasePart") then
		entity.CanCollide = false
		entity.Anchored = false
	elseif entity:IsA("Model") then
		for _, part in ipairs(entity:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = false
				part.Anchored = false
			end
		end
	end

	return entity
end

--[[
	Get a list of all available entity names
	@return table - Array of entity names
]]
function BlockEntityLoader.GetAllEntityNames()
	local folder = getEntitiesFolder()
	if not folder then return {} end

	local names = {}
	for _, child in ipairs(folder:GetChildren()) do
		table.insert(names, child.Name)
	end
	return names
end

--[[
	Clear the folder cache (useful if entities are added at runtime)
]]
function BlockEntityLoader.ClearCache()
	entitiesFolderCache = nil
end

return BlockEntityLoader
