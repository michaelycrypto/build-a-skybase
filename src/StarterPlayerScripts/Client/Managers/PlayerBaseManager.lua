--[[
	PlayerBaseManager.lua - Client-side Height-Aware Base Management

	Handles rendering the player's base with height visualization.
	Supports dynamic height variations, object placement visualization,
	and height-based pathfinding visualization.
--]]

local PlayerBaseManager = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Import dependencies
local Network = require(ReplicatedStorage.Shared.Network)
local Config = require(ReplicatedStorage.Shared.Config)
local Logger = require(ReplicatedStorage.Shared.Logger)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameState = require(script.Parent.GameState)
local ToastManager = require(script.Parent.ToastManager)
local GridUtils = require(ReplicatedStorage.Shared.GridSystem.GridUtils)

-- Services and instances
local player = Players.LocalPlayer

-- State
local isInitialized = false
local currentGrid = nil
local activeConnections = {} -- Store connections for cleanup
local placeholderModels = {} -- Store all placeholder models for centralized animation
local centralAnimationConnection = nil -- Single connection for all placeholder animations
local heightVisualization = {} -- Store height visualization elements
local objectVisualizations = {} -- Store object placement visualizations

-- Constants
local BASE_TILE_SIZE = 4

-- Visual configuration for height-aware grid rendering
local GRID_CONFIG = {
	-- Tile appearance settings with height support
	SPAWNER_TILE = {
		-- Locked slot appearance
		colorLocked = Color3.fromRGB(64, 64, 64), -- Dark grey
		transparencyLocked = 0.7, -- More transparent

		-- Unlocked slot appearance
		colorUnlocked = Color3.fromRGB(64, 64, 64), -- Dark grey
		transparencyEmpty = 0, -- Slightly transparent

		-- Occupied slot appearance
		colorOccupied = Color3.fromRGB(64, 64, 64), -- Green
		transparencyWithSpawner = 0, -- More transparent when spawner is placed

		-- Legacy support
		color = Color3.fromRGB(255, 215, 0), -- Gold (default)
		transparency = 0.3
	},
	DUNGEON_TILE = {
		transparency = 1,
		color = Color3.fromRGB(150, 150, 150) -- Grey
	},
	-- Height visualization settings
	HEIGHT_VISUALIZATION = {
		enabled = true,
		heightIndicator = {
			color = Color3.fromRGB(0, 255, 0), -- Green for height indicators
			transparency = 0.5,
			thickness = 0.1,
			height = 0.5 -- Height of the indicator in studs
		},
		heightGradient = {
			lowColor = Color3.fromRGB(0, 0, 255), -- Blue for low areas
			highColor = Color3.fromRGB(255, 0, 0), -- Red for high areas
			neutralColor = Color3.fromRGB(128, 128, 128) -- Grey for neutral
		}
	},
	-- Object visualization settings
	OBJECT_VISUALIZATION = {
		enabled = true,
		placementPreview = {
			color = Color3.fromRGB(0, 255, 255), -- Cyan for placement preview
			transparency = 0.3,
			canPlaceColor = Color3.fromRGB(0, 255, 0), -- Green for valid placement
			cannotPlaceColor = Color3.fromRGB(255, 0, 0) -- Red for invalid placement
		},
		objectHeight = {
			indicatorColor = Color3.fromRGB(255, 255, 0), -- Yellow for height indicators
			transparency = 0.4,
			thickness = 0.2
		}
	},
	-- Interaction settings
	PROXIMITY_PROMPT = {
		maxDistance = 8,
		holdDuration = 0,
		requiresLineOfSight = false,
		style = Enum.ProximityPromptStyle.Default
	},
	-- Spawner positioning with height support
	SPAWNER_HEIGHT_OFFSET = 2.5 -- Half a tile above the ground
}

--[[
	Initialize the Height-Aware PlayerBaseManager
--]]
function PlayerBaseManager:Initialize()
	if isInitialized then return end

	-- Register network event handlers
	self:RegisterNetworkEvents()

	isInitialized = true
	Logger:Info("PlayerBaseManager", "Initialized height-aware player base manager", {})
end

--[[
	Register network events for height-aware grid rendering
--]]
function PlayerBaseManager:RegisterNetworkEvents()
	-- Events are handled automatically by EventManager configuration
	-- No manual registration needed - EventManager will call the appropriate methods
	print("PlayerBaseManager: Height-aware event handlers will be registered by EventManager")
end

--[[
	Render the height-aware grid based on server data
	@param gridData: table - Grid data from server with height information
--]]
function PlayerBaseManager:RenderGrid(gridData)
	if not gridData then
		Logger:Warn("PlayerBaseManager", "Cannot render grid - invalid data", {
			hasGridData = gridData ~= nil
		})
		return
	end

	Logger:Info("PlayerBaseManager", "Rendering height-aware grid", {
		initialized = gridData.initialized,
		gridSize = gridData.gridSize,
		tileSize = gridData.tileSize,
		hasHeightData = gridData.heightMap ~= nil
	})

	-- Clear existing visualizations
	self:ClearHeightVisualizations()
	self:ClearObjectVisualizations()

	-- Store current grid data
	currentGrid = gridData

	-- Render height visualization if enabled
	if GRID_CONFIG.HEIGHT_VISUALIZATION.enabled and gridData.heightMap then
		self:RenderHeightVisualization(gridData.heightMap)
	end

	-- Render object visualizations if enabled
	if GRID_CONFIG.OBJECT_VISUALIZATION.enabled and gridData.objects then
		self:RenderObjectVisualizations(gridData.objects)
	end

	-- Render the base grid (spawner tiles, etc.)
	self:RenderBaseGrid(gridData)
end

--[[
	Render height visualization for the grid
	@param heightMap: table - 2D array of height values
--]]
function PlayerBaseManager:RenderHeightVisualization(heightMap)
	if not heightMap or not currentGrid then
		return
	end

	local gridSize = currentGrid.gridSize
	local tileSize = currentGrid.tileSize or BASE_TILE_SIZE

	-- Find min and max heights for gradient calculation
	local minHeight, maxHeight = math.huge, -math.huge
	for x = 1, gridSize.width do
		for z = 1, gridSize.height do
			if heightMap[x] and heightMap[x][z] then
				local height = heightMap[x][z]
				minHeight = math.min(minHeight, height)
				maxHeight = math.max(maxHeight, height)
			end
		end
	end

	-- Create height indicators for each tile
	for x = 1, gridSize.width do
		for z = 1, gridSize.height do
			if heightMap[x] and heightMap[x][z] then
				local height = heightMap[x][z]

				-- Skip if height is 0 (ground level)
				if height ~= 0 then
					self:CreateHeightIndicator(x, z, height, minHeight, maxHeight, tileSize)
				end
			end
		end
	end

	Logger:Info("PlayerBaseManager", "Rendered height visualization", {
		tilesWithHeight = self:CountHeightVariations(heightMap),
		minHeight = minHeight,
		maxHeight = maxHeight
	})
end

--[[
	Create a height indicator for a specific tile
	@param x: number - Grid X coordinate
	@param z: number - Grid Z coordinate
	@param height: number - Height value
	@param minHeight: number - Minimum height in the map
	@param maxHeight: number - Maximum height in the map
	@param tileSize: number - Size of each tile
--]]
function PlayerBaseManager:CreateHeightIndicator(x, z, height, minHeight, maxHeight, tileSize)
	-- Calculate world position
    local worldPos = GridUtils.GetTileCenter(x, z, 0, tileSize)

	-- Calculate color based on height (gradient from low to high)
	local normalizedHeight = (height - minHeight) / (maxHeight - minHeight)
	local color = self:InterpolateColor(
		GRID_CONFIG.HEIGHT_VISUALIZATION.heightGradient.lowColor,
		GRID_CONFIG.HEIGHT_VISUALIZATION.heightGradient.highColor,
		normalizedHeight
	)

	-- Create height indicator part
	local indicator = Instance.new("Part")
	indicator.Name = string.format("HeightIndicator_%d_%d", x, z)
	indicator.Size = Vector3.new(tileSize * 0.8, GRID_CONFIG.HEIGHT_VISUALIZATION.heightIndicator.height, tileSize * 0.8)
	indicator.Position = worldPos + Vector3.new(0, height + GRID_CONFIG.HEIGHT_VISUALIZATION.heightIndicator.height / 2, 0)
	indicator.Color = color
	indicator.Material = Enum.Material.Neon
	indicator.Transparency = GRID_CONFIG.HEIGHT_VISUALIZATION.heightIndicator.transparency
	indicator.Anchored = true
	indicator.CanCollide = false
	indicator.Parent = Workspace

	-- Store for cleanup
	table.insert(heightVisualization, indicator)

	-- Add height text label
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 100, 0, 50)
	billboardGui.StudsOffset = Vector3.new(0, 2, 0)
	billboardGui.Parent = indicator

	local heightLabel = Instance.new("TextLabel")
	heightLabel.Size = UDim2.new(1, 0, 1, 0)
	heightLabel.BackgroundTransparency = 1
	heightLabel.Text = string.format("%.1f", height)
	heightLabel.TextColor3 = Color3.new(1, 1, 1)
	heightLabel.TextScaled = true
	heightLabel.Font = Enum.Font.SourceSansBold
	heightLabel.Parent = billboardGui
end

--[[
	Render object visualizations for the grid
	@param objects: table - Array of object data
--]]
function PlayerBaseManager:RenderObjectVisualizations(objects)
	if not objects or not currentGrid then
		return
	end

	local tileSize = currentGrid.tileSize or BASE_TILE_SIZE

	for _, objectData in ipairs(objects) do
		self:CreateObjectVisualization(objectData, tileSize)
	end

	Logger:Info("PlayerBaseManager", "Rendered object visualizations", {
		objectCount = #objects
	})
end

--[[
	Create visualization for a specific object
	@param objectData: table - Object data
	@param tileSize: number - Size of each tile
--]]
function PlayerBaseManager:CreateObjectVisualization(objectData, tileSize)
	-- Calculate world position
    local worldPos = GridUtils.GetTileCenter(objectData.x, objectData.z, objectData.height, tileSize)

	-- Create object preview part
	local preview = Instance.new("Part")
	preview.Name = string.format("ObjectPreview_%s_%d_%d", objectData.type or "unknown", objectData.x, objectData.z)
	preview.Size = Vector3.new(
		(objectData.width or 1) * tileSize * 0.9,
		objectData.objectHeight or 2,
		(objectData.depth or 1) * tileSize * 0.9
	)
	preview.Position = worldPos + Vector3.new(0, (objectData.objectHeight or 2) / 2, 0)
	preview.Color = GRID_CONFIG.OBJECT_VISUALIZATION.placementPreview.color
	preview.Material = Enum.Material.Neon
	preview.Transparency = GRID_CONFIG.OBJECT_VISUALIZATION.placementPreview.transparency
	preview.Anchored = true
	preview.CanCollide = false
	preview.Parent = Workspace

	-- Store for cleanup
	table.insert(objectVisualizations, preview)

	-- Add object info label
	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Size = UDim2.new(0, 150, 0, 100)
	billboardGui.StudsOffset = Vector3.new(0, (objectData.objectHeight or 2) + 1, 0)
	billboardGui.Parent = preview

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, 0, 1, 0)
	infoLabel.BackgroundTransparency = 0.5
	infoLabel.BackgroundColor3 = Color3.new(0, 0, 0)
	infoLabel.Text = string.format("%s\nH: %.1f", objectData.type or "Object", objectData.objectHeight or 0)
	infoLabel.TextColor3 = Color3.new(1, 1, 1)
	infoLabel.TextScaled = true
	infoLabel.Font = Enum.Font.SourceSansBold
	infoLabel.Parent = billboardGui
end

--[[
	Render the base grid (spawner tiles, etc.)
	@param gridData: table - Grid data from server
--]]
function PlayerBaseManager:RenderBaseGrid(gridData)
	-- This would contain the existing grid rendering logic
	-- adapted to work with height information
	Logger:Info("PlayerBaseManager", "Rendering base grid with height support", {
		hasSpawnerData = gridData.spawnerSlots ~= nil
	})

	-- Render spawner tiles with height awareness
	if gridData.spawnerSlots then
		for slotId, slotData in pairs(gridData.spawnerSlots) do
			self:RenderSpawnerTile(slotData, gridData)
		end
	end
end

--[[
	Render a spawner tile with height awareness
	@param slotData: table - Spawner slot data
	@param gridData: table - Grid data
--]]
function PlayerBaseManager:RenderSpawnerTile(slotData, gridData)
	-- Calculate position with height
	local tileSize = gridData.tileSize or BASE_TILE_SIZE
    local worldPos = GridUtils.GetTileCenter(slotData.gridX, slotData.gridZ, 0, tileSize)

	-- Get height for this position
	local height = 0
	if gridData.heightMap and gridData.heightMap[slotData.gridX] and gridData.heightMap[slotData.gridX][slotData.gridZ] then
		height = gridData.heightMap[slotData.gridX][slotData.gridZ]
	end

	-- Create spawner tile with height
	local tile = Instance.new("Part")
	tile.Name = string.format("SpawnerTile_%d", slotData.slotId)
	tile.Size = Vector3.new(tileSize * 0.9, 0.2, tileSize * 0.9)
	tile.Position = worldPos + Vector3.new(0, height + 0.1, 0)
	tile.Color = GRID_CONFIG.SPAWNER_TILE.color
	tile.Material = Enum.Material.Neon
	tile.Transparency = GRID_CONFIG.SPAWNER_TILE.transparency
	tile.Anchored = true
	tile.CanCollide = false
	tile.Parent = Workspace

	-- Store for cleanup
	table.insert(placeholderModels, tile)

	-- Add height indicator if significant
	if height ~= 0 then
		local heightIndicator = Instance.new("Part")
		heightIndicator.Name = string.format("SpawnerHeight_%d", slotData.slotId)
		heightIndicator.Size = Vector3.new(tileSize * 0.1, height, tileSize * 0.1)
		heightIndicator.Position = worldPos + Vector3.new(0, height / 2, 0)
		heightIndicator.Color = Color3.fromRGB(255, 255, 0)
		heightIndicator.Material = Enum.Material.Neon
		heightIndicator.Transparency = 0.3
		heightIndicator.Anchored = true
		heightIndicator.CanCollide = false
		heightIndicator.Parent = Workspace

		table.insert(placeholderModels, heightIndicator)
	end
end

--[[
	Show object placement preview
	@param x: number - Grid X coordinate
	@param z: number - Grid Z coordinate
	@param height: number - Placement height
	@param objectType: string - Type of object
	@param objectHeight: number - Height of the object
	@param canPlace: boolean - Whether placement is valid
--]]
function PlayerBaseManager:ShowPlacementPreview(x, z, height, objectType, objectHeight, canPlace)
	if not currentGrid then
		return
	end

	-- Clear existing preview
	self:ClearPlacementPreview()

	local tileSize = currentGrid.tileSize or BASE_TILE_SIZE
    local worldPos = GridUtils.GetTileCenter(x, z, height, tileSize)

	-- Create preview part
	local preview = Instance.new("Part")
	preview.Name = "PlacementPreview"
	preview.Size = Vector3.new(tileSize * 0.8, objectHeight, tileSize * 0.8)
	preview.Position = worldPos + Vector3.new(0, objectHeight / 2, 0)
	preview.Material = Enum.Material.Neon
	preview.Transparency = 0.3
	preview.Anchored = true
	preview.CanCollide = false
	preview.Parent = Workspace

	-- Set color based on placement validity
	if canPlace then
		preview.Color = GRID_CONFIG.OBJECT_VISUALIZATION.placementPreview.canPlaceColor
	else
		preview.Color = GRID_CONFIG.OBJECT_VISUALIZATION.placementPreview.cannotPlaceColor
	end

	-- Store for cleanup
	table.insert(objectVisualizations, preview)
end

--[[
	Clear placement preview
--]]
function PlayerBaseManager:ClearPlacementPreview()
	for i = #objectVisualizations, 1, -1 do
		local obj = objectVisualizations[i]
		if obj.Name == "PlacementPreview" then
			obj:Destroy()
			table.remove(objectVisualizations, i)
		end
	end
end

--[[
	Clear all height visualizations
--]]
function PlayerBaseManager:ClearHeightVisualizations()
	for _, indicator in ipairs(heightVisualization) do
		if indicator and indicator.Parent then
			indicator:Destroy()
		end
	end
	heightVisualization = {}
end

--[[
	Clear all object visualizations
--]]
function PlayerBaseManager:ClearObjectVisualizations()
	for _, visualization in ipairs(objectVisualizations) do
		if visualization and visualization.Parent then
			visualization:Destroy()
		end
	end
	objectVisualizations = {}
end

--[[
	Clear all grid visualizations
--]]
function PlayerBaseManager:ClearGrid()
	-- Clear existing placeholder models
	for _, model in ipairs(placeholderModels) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	placeholderModels = {}

	-- Clear height and object visualizations
	self:ClearHeightVisualizations()
	self:ClearObjectVisualizations()

	-- Clear current grid data
	currentGrid = nil

	Logger:Info("PlayerBaseManager", "Cleared all grid visualizations", {})
end

--[[
	Count height variations in a height map
	@param heightMap: table - 2D array of heights
	@return: number - Number of height variations
--]]
function PlayerBaseManager:CountHeightVariations(heightMap)
	if not heightMap then
		return 0
	end

	local variations = 0
	local lastHeight = nil

	for x = 1, #heightMap do
		for z = 1, #heightMap[x] do
			local height = heightMap[x][z]
			if lastHeight and height ~= lastHeight then
				variations = variations + 1
			end
			lastHeight = height
		end
	end

	return variations
end

--[[
	Interpolate between two colors
	@param color1: Color3 - First color
	@param color2: Color3 - Second color
	@param t: number - Interpolation factor (0-1)
	@return: Color3 - Interpolated color
--]]
function PlayerBaseManager:InterpolateColor(color1, color2, t)
	t = math.max(0, math.min(1, t)) -- Clamp t to [0, 1]

	return Color3.new(
		color1.R + (color2.R - color1.R) * t,
		color1.G + (color2.G - color1.G) * t,
		color1.B + (color2.B - color1.B) * t
	)
end

--[[
	Toggle height visualization
	@param enabled: boolean - Whether to enable height visualization
--]]
function PlayerBaseManager:ToggleHeightVisualization(enabled)
	GRID_CONFIG.HEIGHT_VISUALIZATION.enabled = enabled

	if enabled and currentGrid and currentGrid.heightMap then
		self:RenderHeightVisualization(currentGrid.heightMap)
	else
		self:ClearHeightVisualizations()
	end

	Logger:Info("PlayerBaseManager", "Toggled height visualization", {enabled = enabled})
end

--[[
	Toggle object visualization
	@param enabled: boolean - Whether to enable object visualization
--]]
function PlayerBaseManager:ToggleObjectVisualization(enabled)
	GRID_CONFIG.OBJECT_VISUALIZATION.enabled = enabled

	if enabled and currentGrid and currentGrid.objects then
		self:RenderObjectVisualizations(currentGrid.objects)
	else
		self:ClearObjectVisualizations()
	end

	Logger:Info("PlayerBaseManager", "Toggled object visualization", {enabled = enabled})
end

--[[
	Get current grid data
	@return: table or nil - Current grid data
--]]
function PlayerBaseManager:GetCurrentGrid()
	return currentGrid
end

--[[
	Get grid configuration
	@return: table - Grid configuration
--]]
function PlayerBaseManager:GetConfig()
	return GRID_CONFIG
end

--[[
	Update grid configuration
	@param newConfig: table - New configuration values
--]]
function PlayerBaseManager:UpdateConfig(newConfig)
	for key, value in pairs(newConfig) do
		if GRID_CONFIG[key] ~= nil then
			GRID_CONFIG[key] = value
		end
	end
end

-- Cleanup function
function PlayerBaseManager:Cleanup()
	self:ClearGrid()

	-- Disconnect all connections
	for _, connection in pairs(activeConnections) do
		if connection then
			connection:Disconnect()
		end
	end
	activeConnections = {}

	-- Disconnect central animation connection
	if centralAnimationConnection then
		centralAnimationConnection:Disconnect()
		centralAnimationConnection = nil
	end

	isInitialized = false
	Logger:Info("PlayerBaseManager", "Cleaned up height-aware player base manager", {})
end

return PlayerBaseManager
