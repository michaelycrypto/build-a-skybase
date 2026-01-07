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
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local BlockBreakFeedbackConfig = require(ReplicatedStorage.Configs.BlockBreakFeedbackConfig)

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
local worldHoldActive = false
local pendingFadeHandler = nil

local CUSTOM_FONT_NAME = "Upheaval BRK"

local CUSTOM_FONT_THEME = {
	logo = CUSTOM_FONT_NAME,
	status = CUSTOM_FONT_NAME
}

local WORLDS_PRELOAD_TIMEOUT = 0.75
local WORLDS_EVENT_NAME = "WorldsListUpdated"

local worldsPrimeStarted = false
local worldsPrimeComplete = false
local worldsPrimeConnection = nil

local function cleanupWorldsPrimeConnection()
	if worldsPrimeConnection then
		pcall(function()
			worldsPrimeConnection:Disconnect()
		end)
		worldsPrimeConnection = nil
	end
end

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

local function setStatusText(text)
	if not titleLabel then
		return
	end
	setTextContent(titleLabel, text or "loading")
end

-- Animation constants
local FADE_DURATION = 0.8
local PROGRESS_DURATION = 0.3

local function updateProgressBar(progress)
	if not progressFill or not progressFill.Parent then
		return
	end

	local clamped = math.clamp(progress or 0, 0, 1)
	TweenService:Create(
		progressFill,
		TweenInfo.new(PROGRESS_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		{Size = UDim2.new(clamped, 0, 1, 0)}
	):Play()
end

local function collectToolMeshAssets()
	local meshAssets = {}
	local seen = {}

	-- Check ReplicatedStorage.Tools directly
	local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
	if not toolsFolder then
		-- Fallback: ReplicatedStorage.Assets.Tools
		local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
		toolsFolder = assetsFolder and assetsFolder:FindFirstChild("Tools")
	end

	if not toolsFolder then
		return meshAssets
	end

	-- Collect all MeshParts from tools folder
	for _, child in ipairs(toolsFolder:GetDescendants()) do
		if child:IsA("MeshPart") then
			local meshId = child.MeshId
			if meshId and meshId ~= "" and not seen[meshId] then
				seen[meshId] = true
				table.insert(meshAssets, child)
			end
			local textureId = child.TextureID
			if textureId and textureId ~= "" and not seen[textureId] then
				seen[textureId] = true
				table.insert(meshAssets, textureId)
			end
		end
	end

	return meshAssets
end

local function collectSoundAssetIds()
	local soundIds = {}
	local seen = {}

	local function addId(id)
		if type(id) ~= "string" then
			return
		end
		if id == "" or seen[id] then
			return
		end
		seen[id] = true
		table.insert(soundIds, id)
	end

	local function addList(list)
		if type(list) ~= "table" then
			return
		end
		for _, value in ipairs(list) do
			if type(value) == "string" then
				addId(value)
			elseif type(value) == "table" then
				if value.id then
					addId(value.id)
				end
				if value.soundId then
					addId(value.soundId)
				end
				if type(value.ids) == "table" then
					addList(value.ids)
				end
				if type(value.variants) == "table" then
					addList(value.variants)
				end
			end
		end
	end

	local audioSettings = Config.AUDIO_SETTINGS or {}

	addList(audioSettings.backgroundMusic or {})

	if type(audioSettings.soundEffects) == "table" then
		for _, entry in pairs(audioSettings.soundEffects) do
			addList({entry})
		end
	end

	-- Include Block Break hit sounds
	for _, soundList in pairs(BlockBreakFeedbackConfig.HitSounds or {}) do
		addList(soundList)
	end

	return soundIds
end

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
	math.randomseed(tick() % 1 * 1e6)
	local uiTypography = Config.UI_SETTINGS and Config.UI_SETTINGS.typography
	local sizes = uiTypography and uiTypography.sizes
	local titleFontPx = (sizes and sizes.body and sizes.body.base) or 24

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
	setTextContent(titleLabel, "Preparing assets...")
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

	setStatusText("Preparing assets...")
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

	-- 3) Block break destroy stage overlays (not part of TextureManager)
	for index, assetUrl in ipairs(BlockBreakFeedbackConfig.DestroyStages or {}) do
		if assetUrl and not seen[assetUrl] then
			seen[assetUrl] = true
			table.insert(assetsToLoad, {name = "DestroyStage" .. tostring(index - 1), url = assetUrl})
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
			setStatusText("Loading textures...")
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

		-- Call progress callback and check if we should stop early
		local shouldStop = false
		if onProgress then
			shouldStop = pcall(onProgress, loadedCount, totalAssets, progress)
		end

		if shouldStop then
			-- Early termination requested
			if onComplete then
				onComplete(loadedCount, failedCount)
			end
			return
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

	setStatusText("Warming up fonts...")
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

	local soundAssetIds = collectSoundAssetIds()
	local totalSounds = #soundAssetIds

	local meshAssets = collectToolMeshAssets()
	local totalMeshes = #meshAssets

	local totalAssets = totalTextures + totalIcons + totalMeshes + totalSounds

	-- Loading assets

	if totalAssets == 0 then
		-- No assets to load; complete immediately via common path
		self:CompleteAllAssetLoading(0, 0, onComplete, onBeforeFadeOut)
		return
	end

	-- Sequential loading for better reliability
	task.spawn(function()
		-- Load essential textures only (reduced set for faster startup)
		if totalTextures > 0 then
			setStatusText("Loading essential textures...")

			-- Load only first 5 textures to avoid long delays
			local essentialTextureCount = math.min(totalTextures, 5)

			self:LoadBlockTextures(
				function(loaded, total, progress)
					-- Update status and overall progress
					setStatusText("Bringing in textures...")
					local overallProgress = math.clamp(loaded / totalAssets, 0, 1)

					-- Update progress bar
					updateProgressBar(overallProgress)

					-- Call progress callback
					if onProgress then
						pcall(onProgress, loaded, totalAssets, overallProgress)
					end

					-- Stop after loading essential textures
					if loaded >= essentialTextureCount then
						return true -- Signal to stop loading more
					end
				end,
				function(loaded, failed)
					-- Essential textures loaded, continue to icons
					self:LoadIconsAfterTextures(
						totalIcons,
						loaded,
						failed,
						totalAssets,
						meshAssets,
						soundAssetIds,
						onProgress,
						onComplete,
						onBeforeFadeOut
					)
				end
			)
		else
			-- No textures, go straight to icons
			self:LoadIconsAfterTextures(
				totalIcons,
				0,
				0,
				totalAssets,
				meshAssets,
				soundAssetIds,
				onProgress,
				onComplete,
				onBeforeFadeOut
			)
		end
	end)
end

--[[
	Helper function to load icons after block textures are done
--]]
function LoadingScreen:LoadIconsAfterTextures(totalIcons, texturesLoaded, texturesFailed, totalAssets, meshAssets, soundAssetIds, onProgress, onComplete, onBeforeFadeOut)
	meshAssets = meshAssets or {}
	soundAssetIds = soundAssetIds or {}

	if totalIcons > 0 then
		setStatusText("Polishing icons...")

		IconManager:PreloadRegisteredIcons(
			function(loaded, total, progress)
				local totalLoaded = texturesLoaded + loaded
				setStatusText("Painting icons...")

				-- Update overall progress
				local overallProgress = math.clamp(totalLoaded / totalAssets, 0, 1)
				updateProgressBar(overallProgress)

				-- Call overall progress callback
				if onProgress then
					pcall(onProgress, totalLoaded, totalAssets, overallProgress)
				end
			end,
			function(iconsLoaded, iconsFailed)
				local totalLoaded = texturesLoaded + iconsLoaded
				local totalFailed = texturesFailed + iconsFailed

				self:LoadMeshesAfterIcons(
					meshAssets,
					totalLoaded,
					totalFailed,
					totalAssets,
					soundAssetIds,
					onProgress,
					onComplete,
					onBeforeFadeOut
				)
			end
		)
	else
		-- No icons to load, continue to meshes
		self:LoadMeshesAfterIcons(
			meshAssets,
			texturesLoaded,
			texturesFailed,
			totalAssets,
			soundAssetIds,
			onProgress,
			onComplete,
			onBeforeFadeOut
		)
	end
end

--[[
	Helper function to load tool meshes after icons
--]]
function LoadingScreen:LoadMeshesAfterIcons(meshAssets, assetsLoadedSoFar, assetsFailedSoFar, totalAssets, soundAssetIds, onProgress, onComplete, onBeforeFadeOut)
	local totalMeshes = #meshAssets

	if totalMeshes == 0 then
		self:LoadSoundsAfterIcons(soundAssetIds, assetsLoadedSoFar, assetsFailedSoFar, totalAssets, onProgress, onComplete, onBeforeFadeOut)
		return
	end

	setStatusText("Forging tools...")

	local batchSize = 4
	local loaded = 0
	local failed = 0

	local function loadBatch(startIndex)
		local batch = {}
		local finalIndex = math.min(startIndex + batchSize - 1, totalMeshes)
		for i = startIndex, finalIndex do
			local asset = meshAssets[i]
			if asset then
				table.insert(batch, asset)
			end
		end

		if #batch == 0 then
			self:LoadSoundsAfterIcons(
				soundAssetIds,
				assetsLoadedSoFar + loaded,
				assetsFailedSoFar + failed,
				totalAssets,
				onProgress,
				onComplete,
				onBeforeFadeOut
			)
			return
		end

		local success, err = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		if success then
			loaded = loaded + #batch
		else
			failed = failed + #batch
			warn("LoadingScreen: Mesh batch failed:", err)
		end

		local totalLoaded = assetsLoadedSoFar + loaded
		local overallProgress = math.clamp(totalLoaded / totalAssets, 0, 1)
		setStatusText("Assembling meshes...")
		updateProgressBar(overallProgress)
		if onProgress then
			pcall(onProgress, totalLoaded, totalAssets, overallProgress)
		end

		task.wait(0.05)
		loadBatch(finalIndex + 1)
	end

	task.spawn(function()
		loadBatch(1)
	end)
end

function LoadingScreen:LoadSoundsAfterIcons(soundAssetIds, assetsLoadedSoFar, assetsFailedSoFar, totalAssets, onProgress, onComplete, onBeforeFadeOut)
	local totalSounds = #soundAssetIds

	if totalSounds == 0 then
		self:CompleteAllAssetLoading(assetsLoadedSoFar, assetsFailedSoFar, onComplete, onBeforeFadeOut)
		return
	end

	setStatusText("Tuning sounds...")

	local batchSize = 8
	local loaded = 0
	local failed = 0

	local function loadBatch(startIndex)
		local batch = {}
		local finalIndex = math.min(startIndex + batchSize - 1, totalSounds)
		for i = startIndex, finalIndex do
			local id = soundAssetIds[i]
			if id then
				table.insert(batch, id)
			end
		end

		if #batch == 0 then
			self:CompleteAllAssetLoading(
				assetsLoadedSoFar + loaded,
				assetsFailedSoFar + failed,
				onComplete,
				onBeforeFadeOut
			)
			return
		end

		local success, err = pcall(function()
			ContentProvider:PreloadAsync(batch)
		end)

		if success then
			loaded += #batch
		else
			failed += #batch
			warn("LoadingScreen: Sound batch failed:", err)
		end

		local totalLoaded = assetsLoadedSoFar + loaded
		local overallProgress = math.clamp(totalLoaded / totalAssets, 0, 1)
		updateProgressBar(overallProgress)
		if onProgress then
			pcall(onProgress, totalLoaded, totalAssets, overallProgress)
		end

		task.wait(0.05)
		loadBatch(finalIndex + 1)
	end

	task.spawn(function()
		loadBatch(1)
	end)
end

--[[
	Complete the asset loading process
--]]
function LoadingScreen:PrimeWorldsData(timeout)
	if worldsPrimeStarted or not EventManager or type(EventManager.SendToServer) ~= "function" then
		return
	end

	worldsPrimeStarted = true
	worldsPrimeComplete = false
	timeout = timeout or WORLDS_PRELOAD_TIMEOUT

	-- Listen once so we know when data arrives during loading
	local ok, connection = pcall(function()
		return EventManager:ConnectToServer(WORLDS_EVENT_NAME, function()
			worldsPrimeComplete = true
			cleanupWorldsPrimeConnection()
		end)
	end)
	if ok then
		worldsPrimeConnection = connection
	else
		warn("LoadingScreen: Failed to connect to WorldsListUpdated", connection)
	end

	task.spawn(function()
		local success, err = pcall(function()
			EventManager:SendToServer("RequestWorldsList", {
				source = "loadingScreen"
			})
		end)
		if not success then
			warn("LoadingScreen: Failed to request worlds list during preload:", err)
		end
	end)

	if timeout and timeout > 0 then
		task.delay(timeout, function()
			if not worldsPrimeComplete then
				cleanupWorldsPrimeConnection()
			end
		end)
	end
end

function LoadingScreen:CompleteAllAssetLoading(totalLoaded, totalFailed, onComplete, onBeforeFadeOut)
	loadingComplete = true
	isLoading = false

	-- Update final status
	if totalFailed > 0 then
		setStatusText("Assets loaded!")
	else
		setStatusText("Ready to roll!")
	end

	-- Brief pause to show completion
	task.wait(0.5)

	-- Allow heavy initialization to run while the loading screen is still visible
	if onBeforeFadeOut then
		pcall(onBeforeFadeOut)
	end

	-- Prime worlds data while the loading screen is still covering the UI.
	self:PrimeWorldsData()

	local function finalizeFade()
		self:FadeOut(function()
			if onComplete then
				onComplete(totalLoaded, totalFailed)
			end
		end)
	end

	if worldHoldActive then
		pendingFadeHandler = function()
			pendingFadeHandler = nil
			finalizeFade()
		end
	else
		finalizeFade()
	end
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
		progressFill = nil
		titleLabel = nil

		worldHoldActive = false
		pendingFadeHandler = nil

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

function LoadingScreen:IsActive()
	return loadingGui ~= nil
end

function LoadingScreen:HoldForWorldStatus(title, subtitle)
	if not loadingGui then
		return false
	end

	worldHoldActive = true

	if title and titleLabel then
		setTextContent(titleLabel, title)
	end

	setStatusText(subtitle or "Preparing your world data...")

	return true
end

function LoadingScreen:ReleaseWorldHold()
	if not worldHoldActive then
		return
	end

	worldHoldActive = false

	if loadingComplete and pendingFadeHandler then
		local handler = pendingFadeHandler
		pendingFadeHandler = nil
		handler()
	end
end

--[[
	Cleanup function
--]]
function LoadingScreen:Cleanup()
	if dotsAnimation then
		dotsAnimation:Disconnect()
		dotsAnimation = nil
	end

	cleanupWorldsPrimeConnection()
	worldsPrimeStarted = false
	worldsPrimeComplete = false
	worldHoldActive = false
	pendingFadeHandler = nil
	isLoading = false
	loadingComplete = false

	if loadingGui then
		loadingGui:Destroy()
		loadingGui = nil
	end

	progressFill = nil
	titleLabel = nil
end

return LoadingScreen