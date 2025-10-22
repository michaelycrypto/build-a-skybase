--[[
	IconManager.lua - Vector Icons Pack Manager
	Handles preloading, caching, and applying icons to UI elements
	Only loads icons that are actually used in the game
--]]

local IconManager = {}

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import dependencies
local IconMapping = require(ReplicatedStorage.Shared.IconMapping)
local Logger = require(ReplicatedStorage.Shared.Logger)

-- State
local preloadedIcons = {}
local iconsInUse = {}
local isPreloading = false
local preloadProgress = 0

-- Constants
local ICON_SIZE_CACHE = {}
local DEFAULT_ICON_SIZE = UDim2.new(0, 32, 0, 32)
local ICON_COLOR_CACHE = {}
local DEFAULT_ICON_COLOR = Color3.new(1, 1, 1)

-- Icon Size System - Supporting 64x64 source icons with flexible sizing
local ICON_SIZES = {
	-- Pixel-based sizes
	[12] = UDim2.new(0, 12, 0, 12),
	[18] = UDim2.new(0, 18, 0, 18),
	[24] = UDim2.new(0, 24, 0, 24),
	[36] = UDim2.new(0, 36, 0, 36),
	[48] = UDim2.new(0, 48, 0, 48),
	[64] = UDim2.new(0, 64, 0, 64),

	-- Semantic size names
	xs = UDim2.new(0, 12, 0, 12),   -- Extra Small
	sm = UDim2.new(0, 18, 0, 18),   -- Small
	md = UDim2.new(0, 24, 0, 24),   -- Medium (default)
	lg = UDim2.new(0, 36, 0, 36),   -- Large
	xl = UDim2.new(0, 48, 0, 48),   -- Extra Large
	xxl = UDim2.new(0, 64, 0, 64),  -- Extra Extra Large (full resolution)

	-- Common UI component sizes
	button = UDim2.new(0, 24, 0, 24),      -- Standard button icons
	navbar = UDim2.new(0, 20, 0, 20),      -- Navigation bar icons
	sidebar = UDim2.new(0, 28, 0, 28),     -- Sidebar icons
	toast = UDim2.new(0, 21, 0, 21),       -- Toast notification icons
	hud = UDim2.new(0, 16, 0, 16),         -- HUD element icons
	avatar = UDim2.new(0, 48, 0, 48),      -- Avatar/profile icons
	hero = UDim2.new(0, 64, 0, 64),        -- Hero/feature icons
}

-- Events
local IconPreloadedEvent = Instance.new("BindableEvent")
local AllIconsPreloadedEvent = Instance.new("BindableEvent")

--[[
	Initialize the IconManager
--]]
function IconManager:Initialize()
	-- Initializing Vector Icons system

	-- Clear any existing state
	preloadedIcons = {}
	iconsInUse = {}
	isPreloading = false
	preloadProgress = 0

	-- Vector Icons system ready
end

--[[
	Get UDim2 size from size parameter
	@param size: number|string|UDim2 - Size specification
	@return: UDim2 - Resolved size
--]]
function IconManager:GetSizeFromSpec(size)
	if not size then
		return ICON_SIZES.md -- Default to medium
	end

	-- If it's already a UDim2, return it
	if typeof(size) == "UDim2" then
		return size
	end

	-- If it's a number or string key in our sizes table
	if ICON_SIZES[size] then
		return ICON_SIZES[size]
	end

	-- If it's a number, create UDim2 from it
	if typeof(size) == "number" then
		return UDim2.new(0, size, 0, size)
	end

	-- Fallback to medium
	warn("IconManager: Invalid size specification:", size, "- using medium")
	return ICON_SIZES.md
end

--[[
	Get all available size options
	@return: table - Table of size options with descriptions
--]]
function IconManager:GetAvailableSizes()
	return {
		-- Pixel sizes
		{name = "12", pixels = 12, description = "12x12 pixels"},
		{name = "18", pixels = 18, description = "18x18 pixels"},
		{name = "24", pixels = 24, description = "24x24 pixels"},
		{name = "36", pixels = 36, description = "36x36 pixels"},
		{name = "48", pixels = 48, description = "48x48 pixels"},
		{name = "64", pixels = 64, description = "64x64 pixels (full resolution)"},

		-- Semantic sizes
		{name = "xs", pixels = 12, description = "Extra Small (12px)"},
		{name = "sm", pixels = 18, description = "Small (18px)"},
		{name = "md", pixels = 24, description = "Medium (24px) - Default"},
		{name = "lg", pixels = 36, description = "Large (36px)"},
		{name = "xl", pixels = 48, description = "Extra Large (48px)"},
		{name = "xxl", pixels = 64, description = "Extra Extra Large (64px)"},

		-- Component sizes
		{name = "button", pixels = 24, description = "Standard button icons (24px)"},
		{name = "navbar", pixels = 20, description = "Navigation bar icons (20px)"},
		{name = "sidebar", pixels = 28, description = "Sidebar icons (28px)"},
		{name = "toast", pixels = 21, description = "Toast notification icons (21px)"},
		{name = "hud", pixels = 16, description = "HUD element icons (16px)"},
		{name = "avatar", pixels = 48, description = "Avatar/profile icons (48px)"},
		{name = "hero", pixels = 64, description = "Hero/feature icons (64px)"},
	}
end

--[[
	Register an icon as "in use" so it gets preloaded
	@param category: string - Icon category (e.g., "Currency", "General")
	@param iconName: string - Icon name (e.g., "Coin", "Home")
	@param metadata: table - Optional metadata like size, color, etc.
--]]
function IconManager:RegisterIcon(category, iconName, metadata)
	local iconId = self:GetIconId(category, iconName)
	if not iconId then
		warn("IconManager: Invalid icon:", category, iconName)
		return false
	end

	local iconKey = category .. "_" .. iconName
	iconsInUse[iconKey] = {
		category = category,
		iconName = iconName,
		iconId = iconId,
		metadata = metadata or {}
	}

	-- Icon registered for preloading
	return true
end

--[[
	Get the asset ID for an icon
	@param category: string - Icon category
	@param iconName: string - Icon name
	@return: number or nil - Asset ID
--]]
function IconManager:GetIconId(category, iconName)
	if not IconMapping[category] then
		return nil
	end
	return IconMapping[category][iconName]
end

--[[
	Get the rbxassetid URL for an icon
	@param category: string - Icon category
	@param iconName: string - Icon name
	@return: string or nil - Asset URL
--]]
function IconManager:GetIconUrl(category, iconName)
	local iconId = self:GetIconId(category, iconName)
	if iconId then
		return "rbxassetid://" .. tostring(iconId)
	end
	return nil
end

--[[
	Preload all registered icons
	@param onProgress: function - Callback for progress updates (loadedCount, totalCount, progress)
	@param onComplete: function - Callback for completion
	@return: boolean - Success status
--]]
function IconManager:PreloadRegisteredIcons(onProgress, onComplete)
	if isPreloading then
		warn("IconManager: Already preloading icons")
		return false
	end

	isPreloading = true
	preloadProgress = 0

	local iconsToLoad = {}
	local totalIcons = 0

	-- Prepare list of icons to preload
	for iconKey, iconData in pairs(iconsInUse) do
		local assetUrl = "rbxassetid://" .. tostring(iconData.iconId)
		table.insert(iconsToLoad, {
			key = iconKey,
			url = assetUrl,
			data = iconData
		})
		totalIcons = totalIcons + 1
	end

	if totalIcons == 0 then
		-- No icons to preload
		isPreloading = false
		if onComplete then onComplete(0, 0) end
		AllIconsPreloadedEvent:Fire()
		return true
	end

	-- Starting icon preload

	-- Load icons in batches for better performance
	local batchSize = 8
	local loadedCount = 0
	local failedCount = 0

	local function loadBatch(startIndex)
		local batch = {}
		local endIndex = math.min(startIndex + batchSize - 1, totalIcons)

		-- Prepare batch URLs
		for i = startIndex, endIndex do
			if iconsToLoad[i] then
				table.insert(batch, iconsToLoad[i].url)
			end
		end

		if #batch == 0 then
			-- All batches complete
			isPreloading = false
			preloadProgress = 1

			-- Icon preloading complete

			if onComplete then
				onComplete(loadedCount, failedCount)
			end
			AllIconsPreloadedEvent:Fire()
			return
		end

		-- Load current batch
		local success, errorMessage = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		-- Update progress
		local batchLoadedCount = success and #batch or 0
		local batchFailedCount = success and 0 or #batch

		loadedCount = loadedCount + batchLoadedCount
		failedCount = failedCount + batchFailedCount

		-- Cache successfully loaded icons
		if success then
			for i = startIndex, endIndex do
				if iconsToLoad[i] then
					local iconData = iconsToLoad[i]
					preloadedIcons[iconData.key] = iconData
					IconPreloadedEvent:Fire(iconData.key, iconData.data)
				end
			end
		end

		-- Update progress
		preloadProgress = loadedCount / totalIcons

		if onProgress then
			pcall(onProgress, loadedCount, totalIcons, preloadProgress)
		end

		if not success then
			warn("IconManager: Failed to load batch starting at", startIndex, ":", errorMessage)
		end

		-- Load next batch after a brief pause
		task.wait(0.05)
		loadBatch(endIndex + 1)
	end

	-- Start loading batches
	task.spawn(function()
		loadBatch(1)
	end)

	return true
end

--[[
	Apply an icon to a UI element
	@param element: ImageLabel|ImageButton - UI element to apply icon to
	@param category: string - Icon category
	@param iconName: string - Icon name
	@param options: table - Optional styling options
		- size: number|string|UDim2 - Icon size (supports: 12,18,24,36,48,64, "xs","sm","md","lg","xl","xxl", "button","toast","hud", etc.)
		- imageColor3: Color3 - Icon color
		- imageTransparency: number - Icon transparency
		- scaleType: Enum.ScaleType - How to scale the icon
		- slice: Rect - Slice center for 9-slice scaling
--]]
function IconManager:ApplyIcon(element, category, iconName, options)
	if not element or not element:IsA("ImageLabel") and not element:IsA("ImageButton") then
		warn("IconManager: Invalid element for icon application")
		return false
	end

	local iconUrl = self:GetIconUrl(category, iconName)
	if not iconUrl then
		warn("IconManager: Icon not found:", category, iconName)
		return false
	end

	-- Apply the icon
	element.Image = iconUrl

	-- Apply options if provided
	if options then
		if options.size then
			local resolvedSize = self:GetSizeFromSpec(options.size)
			element.Size = resolvedSize
		end

		if options.imageTransparency then
			element.ImageTransparency = options.imageTransparency
		end

		if options.scaleType then
			element.ScaleType = options.scaleType
		end

		if options.slice then
			element.SliceCenter = options.slice
		end
	end

	return true
end

--[[
	Create a new ImageLabel with an icon
	@param parent: Instance - Parent for the new ImageLabel
	@param category: string - Icon category
	@param iconName: string - Icon name
	@param options: table - Optional styling options
		- size: number|string|UDim2 - Icon size (supports: 12,18,24,36,48,64, "xs","sm","md","lg","xl","xxl", "button","toast","hud", etc.)
		- position: UDim2 - Position
		- anchorPoint: Vector2 - Anchor point
		- imageColor3: Color3 - Icon color
		- imageTransparency: number - Icon transparency
		- scaleType: Enum.ScaleType - How to scale the icon
		- zIndex: number - Z-index
	@return: ImageLabel or nil - Created ImageLabel
--]]
function IconManager:CreateIcon(parent, category, iconName, options)
	local iconUrl = self:GetIconUrl(category, iconName)
	if not iconUrl then
		warn("IconManager: Icon not found:", category, iconName)
		return nil
	end

	-- Resolve size using the new sizing system
	local resolvedSize = DEFAULT_ICON_SIZE
	if options and options.size then
		resolvedSize = self:GetSizeFromSpec(options.size)
	end

	-- Create ImageLabel
	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = category .. "_" .. iconName
	iconLabel.Size = resolvedSize
	iconLabel.BackgroundTransparency = 1
	iconLabel.Image = iconUrl
	iconLabel.ImageColor3 = (options and options.imageColor3) or DEFAULT_ICON_COLOR
	iconLabel.ScaleType = (options and options.scaleType) or Enum.ScaleType.Fit

	-- Apply additional options
	if options then
		if options.position then
			iconLabel.Position = options.position
		end

		if options.anchorPoint then
			iconLabel.AnchorPoint = options.anchorPoint
		elseif options.position and not options.anchorPoint then
			-- Auto-center if position is given without explicit anchor point
			iconLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		end

		if options.imageTransparency then
			iconLabel.ImageTransparency = options.imageTransparency
		end

		if options.zIndex then
			iconLabel.ZIndex = options.zIndex
		end
	end

	iconLabel.Parent = parent
	return iconLabel
end

--[[
	Create a new ImageButton with an icon
	@param parent: Instance - Parent for the new ImageButton
	@param category: string - Icon category
	@param iconName: string - Icon name
	@param options: table - Optional styling options
		- size: number|string|UDim2 - Icon size (supports: 12,18,24,36,48,64, "xs","sm","md","lg","xl","xxl", "button","toast","hud", etc.)
		- position: UDim2 - Position
		- anchorPoint: Vector2 - Anchor point
		- imageColor3: Color3 - Icon color
		- imageTransparency: number - Icon transparency
		- scaleType: Enum.ScaleType - How to scale the icon
		- zIndex: number - Z-index
		- onClick: function - Click handler
	@return: ImageButton or nil - Created ImageButton
--]]
function IconManager:CreateIconButton(parent, category, iconName, options)
	local iconUrl = self:GetIconUrl(category, iconName)
	if not iconUrl then
		warn("IconManager: Icon not found:", category, iconName)
		return nil
	end

	-- Resolve size using the new sizing system
	local resolvedSize = DEFAULT_ICON_SIZE
	if options and options.size then
		resolvedSize = self:GetSizeFromSpec(options.size)
	end

	-- Create ImageButton
	local iconButton = Instance.new("ImageButton")
	iconButton.Name = category .. "_" .. iconName .. "_Button"
	iconButton.Size = resolvedSize
	iconButton.BackgroundTransparency = 1
	iconButton.Image = iconUrl
	iconButton.ImageColor3 = (options and options.imageColor3) or DEFAULT_ICON_COLOR
	iconButton.ScaleType = (options and options.scaleType) or Enum.ScaleType.Fit

	-- Apply additional options
	if options then
		if options.position then
			iconButton.Position = options.position
		end

		if options.anchorPoint then
			iconButton.AnchorPoint = options.anchorPoint
		end

		if options.imageTransparency then
			iconButton.ImageTransparency = options.imageTransparency
		end

		if options.zIndex then
			iconButton.ZIndex = options.zIndex
		end

		if options.onClick then
			iconButton.MouseButton1Click:Connect(options.onClick)
		end
	end

	iconButton.Parent = parent
	return iconButton
end

--[[
	Check if an icon is preloaded
	@param category: string - Icon category
	@param iconName: string - Icon name
	@return: boolean - Is preloaded
--]]
function IconManager:IsIconPreloaded(category, iconName)
	local iconKey = category .. "_" .. iconName
	return preloadedIcons[iconKey] ~= nil
end

--[[
	Get preload progress
	@return: number - Progress (0-1)
--]]
function IconManager:GetPreloadProgress()
	return preloadProgress
end

--[[
	Check if currently preloading
	@return: boolean - Is preloading
--]]
function IconManager:IsPreloading()
	return isPreloading
end

--[[
	Get list of all registered icons
	@return: table - List of registered icons
--]]
function IconManager:GetRegisteredIcons()
	return iconsInUse
end

--[[
	Get list of all preloaded icons
	@return: table - List of preloaded icons
--]]
function IconManager:GetPreloadedIcons()
	return preloadedIcons
end

--[[
	Get events for listening to preload progress
	@return: BindableEvent, BindableEvent - IconPreloaded, AllIconsPreloaded
--]]
function IconManager:GetEvents()
	return IconPreloadedEvent, AllIconsPreloadedEvent
end

--[[
	Helper function to get all icons in a category
	@param category: string - Icon category
	@return: table - List of icon names in category
--]]
function IconManager:GetIconsInCategory(category)
	if not IconMapping[category] then
		return {}
	end

	local icons = {}
	for iconName, _ in pairs(IconMapping[category]) do
		table.insert(icons, iconName)
	end

	return icons
end

--[[
	Helper function to get all categories
	@return: table - List of category names
--]]
function IconManager:GetCategories()
	local categories = {}
	for category, _ in pairs(IconMapping) do
		table.insert(categories, category)
	end

	return categories
end

--[[
	Cleanup function
--]]
function IconManager:Cleanup()
	preloadedIcons = {}
	iconsInUse = {}
	isPreloading = false
	preloadProgress = 0

	-- IconManager cleaned up
end

--[[
	Example usage of the sizing system:

	-- Pixel sizes
	IconManager:CreateIcon(parent, "General", "Star", {size = 24})
	IconManager:CreateIcon(parent, "General", "Star", {size = 48})

	-- Semantic sizes
	IconManager:CreateIcon(parent, "General", "Star", {size = "xs"})    -- 12px
	IconManager:CreateIcon(parent, "General", "Star", {size = "sm"})    -- 18px
	IconManager:CreateIcon(parent, "General", "Star", {size = "md"})    -- 24px (default)
	IconManager:CreateIcon(parent, "General", "Star", {size = "lg"})    -- 36px
	IconManager:CreateIcon(parent, "General", "Star", {size = "xl"})    -- 48px
	IconManager:CreateIcon(parent, "General", "Star", {size = "xxl"})   -- 64px (full resolution)

	-- Component-specific sizes
	IconManager:CreateIcon(parent, "General", "Star", {size = "button"})  -- 24px for buttons
	IconManager:CreateIcon(parent, "General", "Star", {size = "toast"})   -- 21px for toast notifications
	IconManager:CreateIcon(parent, "General", "Star", {size = "hud"})     -- 16px for HUD elements
	IconManager:CreateIcon(parent, "General", "Star", {size = "navbar"})  -- 20px for navigation
	IconManager:CreateIcon(parent, "General", "Star", {size = "sidebar"}) -- 28px for sidebars
	IconManager:CreateIcon(parent, "General", "Star", {size = "avatar"})  -- 48px for avatars
	IconManager:CreateIcon(parent, "General", "Star", {size = "hero"})    -- 64px for hero elements

	-- UDim2 (for custom sizing)
	IconManager:CreateIcon(parent, "General", "Star", {size = UDim2.new(0, 32, 0, 32)})
--]]

return IconManager