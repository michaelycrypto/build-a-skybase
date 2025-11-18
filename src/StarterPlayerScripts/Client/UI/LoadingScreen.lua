--[[
	LoadingScreen.lua - Minimal Asset Loading Screen
	Preloads block textures and registered icons with elegant progress indication
--]]

local LoadingScreen = {}

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local loadingGui
local progressFill
local titleLabel

-- State
local isLoading = false
local loadingComplete = false

local CUSTOM_FONT_NAME = "Zephyrean BRK"

local CUSTOM_FONT_THEME = {
	logo = CUSTOM_FONT_NAME,
	status = CUSTOM_FONT_NAME
}

local function applyFontMetadata(target, fontName, fontPx)
	if not target then return end

	if fontName then
		pcall(function()
			target.FontName = fontName
		end)
	end

	if fontPx then
		pcall(function()
			target.FontPx = fontPx
		end)
	end
end

local function setTextContent(target, text)
	if not target then return end

	pcall(function()
		target.Text = text
	end)

	pcall(function()
		target.FullText = text
	end)
end

local function setStatusText()
	-- Intentionally blank: new UI does not surface status copy
end

-- Animation constants
local FADE_DURATION = 0.8
local PROGRESS_DURATION = 0.3

--[[
	Create the loading screen
--]]
function LoadingScreen:Create()
	FontBinder.preload(CUSTOM_FONT_THEME)

	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "LoadingScreen"
	loadingGui.ResetOnSpawn = false
	loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	loadingGui.IgnoreGuiInset = true
	loadingGui.Parent = playerGui

	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BorderSizePixel = 0
	backdrop.Parent = loadingGui

	local centerContainer = Instance.new("Frame")
	centerContainer.Name = "CenterContainer"
	centerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	centerContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	centerContainer.Size = UDim2.new(0, 240, 0, 80)
	centerContainer.BackgroundTransparency = 1
	centerContainer.Parent = backdrop

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 20)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = centerContainer

	local heroFontName = CUSTOM_FONT_THEME.logo
	local titleFontPx = Config.UI_SETTINGS.typography.sizes.body.base

	titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "TitleLabel"
	titleLabel.Size = UDim2.new(1, 0, 0, 32)
	titleLabel.BackgroundTransparency = 1
	titleLabel.BorderSizePixel = 0
	titleLabel.TextXAlignment = Enum.TextXAlignment.Center
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.TextWrapped = false
	titleLabel.RichText = false
	titleLabel.AutoLocalize = false
	titleLabel.ClipsDescendants = true
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextSize = titleFontPx
	titleLabel.LayoutOrder = 1
	titleLabel.Parent = centerContainer

	FontBinder.apply(titleLabel, heroFontName)
	setTextContent(titleLabel, "Build a Sky Kingdom")
	applyFontMetadata(titleLabel, heroFontName, titleFontPx)

	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressContainer"
	progressContainer.Size = UDim2.new(0, 180, 0, 4)
	progressContainer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressContainer.BackgroundTransparency = 0.75
	progressContainer.BorderSizePixel = 0
	progressContainer.LayoutOrder = 2
	progressContainer.Parent = centerContainer

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 2)
	progressCorner.Parent = progressContainer

	progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 2)
	fillCorner.Parent = progressFill
end

--[[
	Start animated dots for loading text
--]]
--[[
	Load block texture assets with progress tracking
--]]
function LoadingScreen:LoadBlockTextures(onProgress, onComplete)
	local assetsToLoad = {}
	local totalAssets = 0
	local seen = {}

	-- 1) From TextureManager registry (named textures)
	local textureNames = TextureManager:GetAllTextureNames()
	for _, textureName in ipairs(textureNames) do
		if TextureManager:IsTextureConfigured(textureName) then
			local assetUrl = TextureManager:GetTextureId(textureName)
			if assetUrl and not seen[assetUrl] then
				seen[assetUrl] = true
				table.insert(assetsToLoad, {name = textureName, url = assetUrl})
				totalAssets = totalAssets + 1
			end
		end
	end

	-- 2) From BlockRegistry (raw IDs and names on each block's textures)
	local registryAssets = TextureManager:GetAllBlockTextureAssetIds()
	for _, assetUrl in ipairs(registryAssets) do
		if assetUrl and not seen[assetUrl] then
			seen[assetUrl] = true
			table.insert(assetsToLoad, {name = assetUrl, url = assetUrl})
			totalAssets = totalAssets + 1
		end
	end

	if totalAssets == 0 then
		-- No textures to load
		if onComplete then
			onComplete(0, 0) -- loaded, failed
		end
		return
	end

	-- Starting to load block texture assets

	-- Load assets in batches for better performance
	local batchSize = 5
	local loadedCount = 0
	local failedCount = 0

	local function loadBatch(startIndex)
		local batch = {}
		local endIndex = math.min(startIndex + batchSize - 1, totalAssets)

		-- Prepare batch
		for i = startIndex, endIndex do
			if assetsToLoad[i] then
				table.insert(batch, assetsToLoad[i].url)
			end
		end

		if #batch == 0 then
			-- All batches complete
			-- Block texture loading complete
			if onComplete then
				onComplete(loadedCount, failedCount)
			end
			return
		end

		-- Update status for current batch
		if assetsToLoad[startIndex] then
			setStatusText("Loading " .. assetsToLoad[startIndex].name:gsub("_", " "))
		end

		-- Load current batch with timeout protection
		local success, errorMessage = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		-- Update progress
		local batchLoadedCount = success and #batch or 0
		local batchFailedCount = success and 0 or #batch

		loadedCount = loadedCount + batchLoadedCount
		failedCount = failedCount + batchFailedCount

		local progress = math.min(loadedCount / totalAssets, 1) -- Cap at 100%

		-- Call progress callback
		if onProgress then
			pcall(onProgress, loadedCount, totalAssets, progress)
		end

		if not success then
			warn("LoadingScreen: Batch load failed:", errorMessage)
		end

		-- Load next batch after a brief pause
		task.wait(0.1)
		loadBatch(endIndex + 1)
	end

	-- Start loading batches
	task.spawn(function()
		loadBatch(1)
	end)
end

--[[
	Load both block textures and icons (sequential for reliability)
--]]
function LoadingScreen:LoadAllAssets(onProgress, onComplete, onBeforeFadeOut)
	if isLoading then
		warn("LoadingScreen: Already loading")
		return
	end

	setStatusText("Loading fonts...")
	FontBinder.preload(CUSTOM_FONT_THEME)
	isLoading = true

	-- Count total assets
	local totalTextures = 0
	local textureNames = TextureManager:GetAllTextureNames()
	for _, textureName in ipairs(textureNames) do
		if TextureManager:IsTextureConfigured(textureName) then
			totalTextures = totalTextures + 1
		end
	end

	local registeredIcons = IconManager:GetRegisteredIcons()
	local totalIcons = 0
	for _ in pairs(registeredIcons) do
		totalIcons = totalIcons + 1
	end

	local totalAssets = totalTextures + totalIcons

	-- Loading assets

	if totalAssets == 0 then
		-- No assets to load; complete immediately via common path
		self:CompleteAllAssetLoading(0, 0, onComplete, onBeforeFadeOut)
		return
	end

	-- Sequential loading for better reliability
	task.spawn(function()
		-- Load block textures first
		if totalTextures > 0 then
			setStatusText("Loading block textures...")

			self:LoadBlockTextures(
				function(loaded, total, progress)
					-- Update status and overall progress
					setStatusText("Loading textures (" .. loaded .. "/" .. total .. ")")
					local overallProgress = math.clamp(loaded / totalAssets, 0, 1)

					-- Update progress bar
					if progressFill and progressFill.Parent then
						TweenService:Create(progressFill,
							TweenInfo.new(PROGRESS_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
							{Size = UDim2.new(overallProgress, 0, 1, 0)}
						):Play()
					end

					-- Call progress callback
					if onProgress then
						pcall(onProgress, loaded, totalAssets, overallProgress)
					end
				end,
				function(loaded, failed)
					-- Block textures loaded

					-- Now load icons
					self:LoadIconsAfterTextures(totalIcons, loaded, failed, totalAssets, onProgress, onComplete, onBeforeFadeOut)
				end
			)
		else
			-- No textures, go straight to icons
			-- No textures, loading icons directly
			self:LoadIconsAfterTextures(totalIcons, 0, 0, totalAssets, onProgress, onComplete, onBeforeFadeOut)
		end
	end)
end

--[[
	Helper function to load icons after block textures are done
--]]
function LoadingScreen:LoadIconsAfterTextures(totalIcons, texturesLoaded, texturesFailed, totalAssets, onProgress, onComplete, onBeforeFadeOut)
	if totalIcons > 0 then
		setStatusText("Loading icons...")

		IconManager:PreloadRegisteredIcons(
			function(loaded, total, progress)
				local totalLoaded = texturesLoaded + loaded
				setStatusText("Loading icons (" .. loaded .. "/" .. total .. ")")

				-- Update overall progress
				local overallProgress = math.clamp(totalLoaded / totalAssets, 0, 1)
				if progressFill and progressFill.Parent then
					TweenService:Create(progressFill,
						TweenInfo.new(PROGRESS_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
						{Size = UDim2.new(overallProgress, 0, 1, 0)}
					):Play()
				end

				-- Call overall progress callback
				if onProgress then
					pcall(onProgress, totalLoaded, totalAssets, overallProgress)
				end
			end,
			function(iconsLoaded, iconsFailed)
				local totalLoaded = texturesLoaded + iconsLoaded
				local totalFailed = texturesFailed + iconsFailed

				-- Icons loaded, total assets loaded

				-- Complete loading
				self:CompleteAllAssetLoading(totalLoaded, totalFailed, onComplete, onBeforeFadeOut)
			end
		)
	else
		-- No icons to load, complete immediately
		-- No icons to load
		self:CompleteAllAssetLoading(texturesLoaded, texturesFailed, onComplete, onBeforeFadeOut)
	end
end

--[[
	Complete the asset loading process
--]]
function LoadingScreen:CompleteAllAssetLoading(totalLoaded, totalFailed, onComplete, onBeforeFadeOut)
	loadingComplete = true
	isLoading = false

	-- Update final status
	if totalFailed > 0 then
		setStatusText("Loaded " .. totalLoaded .. " assets (" .. totalFailed .. " failed)")
	else
		setStatusText("All assets loaded successfully!")
	end

	-- Brief pause to show completion
	task.wait(0.5)

	-- Allow heavy initialization to run while the loading screen is still visible
	if onBeforeFadeOut then
		pcall(onBeforeFadeOut)
	end

	-- Fade out and call completion callback
	self:FadeOut(function()
		if onComplete then
			onComplete(totalLoaded, totalFailed)
		end
	end)
end

--[[
	Fade out the loading screen
--]]
function LoadingScreen:FadeOut(onComplete)
	if not loadingGui then
		if onComplete then onComplete() end
		return
	end

	-- Fade out all elements
	local function finalize()
		if loadingGui then
			loadingGui:Destroy()
			loadingGui = nil
		end

		if onComplete then
			onComplete()
		end
	end

	finalize()
end

--[[
	Check if loading is complete
--]]
function LoadingScreen:IsLoadingComplete()
	return loadingComplete
end

--[[
	Check if currently loading
--]]
function LoadingScreen:IsLoading()
	return isLoading
end

--[[
	Cleanup function
--]]
function LoadingScreen:Cleanup()
	if dotsAnimation then
		dotsAnimation:Disconnect()
		dotsAnimation = nil
	end

	if loadingGui then
		loadingGui:Destroy()
		loadingGui = nil
	end

	isLoading = false
	loadingComplete = false
end

return LoadingScreen