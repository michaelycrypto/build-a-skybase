--[[
	LoadingScreen.lua - Minimal Asset Loading Screen
	Preloads block textures and registered icons with elegant progress indication
--]]

local LoadingScreen = {}

local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UI Elements
local loadingGui
local progressBar
local progressFill
local statusLabel
local logoLabel
local dotsAnimation

-- State
local isLoading = false
local loadingComplete = false

-- Animation constants
local FADE_DURATION = 0.8
local PROGRESS_DURATION = 0.3
local DOT_CYCLE_TIME = 1.2

--[[
	Create the loading screen
--]]
function LoadingScreen:Create()
	-- Create loading screen GUI
	loadingGui = Instance.new("ScreenGui")
	loadingGui.Name = "LoadingScreen"
	loadingGui.ResetOnSpawn = false
	loadingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	loadingGui.IgnoreGuiInset = true
	loadingGui.Parent = playerGui

	-- Elegant backdrop with subtle gradient effect
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(8, 8, 15)
	backdrop.Transparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Parent = loadingGui

	-- Subtle animated gradient overlay
	local gradientOverlay = Instance.new("Frame")
	gradientOverlay.Name = "GradientOverlay"
	gradientOverlay.Size = UDim2.new(1, 0, 1, 0)
	gradientOverlay.BackgroundTransparency = 0.7
	gradientOverlay.BorderSizePixel = 0
	gradientOverlay.Parent = backdrop

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(138, 43, 226)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(75, 0, 130)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(138, 43, 226))
	})
	gradient.Rotation = 45
	gradient.Parent = gradientOverlay

	-- Animate gradient rotation
	local gradientTween = TweenService:Create(gradient,
		TweenInfo.new(4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{Rotation = 405}
	)
	gradientTween:Play()

	-- Main content container
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(0, 400, 0, 200)
	contentFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = loadingGui

	-- Game logo/title
	logoLabel = Instance.new("TextLabel")
	logoLabel.Name = "LogoLabel"
	logoLabel.Size = UDim2.new(1, 0, 0, 60)
	logoLabel.Position = UDim2.new(0, 0, 0, 0)
	logoLabel.BackgroundTransparency = 1
	logoLabel.Text = "AuraSystem"
	logoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	logoLabel.TextSize = Config.UI_SETTINGS.typography.sizes.display.hero  -- 36px - hero branding
	logoLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	logoLabel.TextStrokeTransparency = 0.5
	logoLabel.TextStrokeColor3 = Color3.fromRGB(138, 43, 226)
	logoLabel.Parent = contentFrame

	-- Progress container
	local progressContainer = Instance.new("Frame")
	progressContainer.Name = "ProgressContainer"
	progressContainer.Size = UDim2.new(1, 0, 0, 8)
	progressContainer.Position = UDim2.new(0, 0, 0, 100)
	progressContainer.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	progressContainer.BackgroundTransparency = 0.3
	progressContainer.BorderSizePixel = 0
	progressContainer.Parent = contentFrame

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 4)
	progressCorner.Parent = progressContainer

	-- Progress fill bar
	progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Config.UI_SETTINGS.colors.primary
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressContainer

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = progressFill

	-- Subtle glow effect on progress bar
	local glowEffect = Instance.new("Frame")
	glowEffect.Name = "GlowEffect"
	glowEffect.Size = UDim2.new(1, 4, 1, 4)
	glowEffect.Position = UDim2.new(0, -2, 0, -2)
	glowEffect.BackgroundColor3 = Config.UI_SETTINGS.colors.primary
	glowEffect.BackgroundTransparency = 0.8
	glowEffect.BorderSizePixel = 0
	glowEffect.Parent = progressFill

	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 6)
	glowCorner.Parent = glowEffect

	-- Status label with animated dots
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 0, 30)
	statusLabel.Position = UDim2.new(0, 0, 0, 130)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = "Loading assets"
	statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	statusLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base  -- 14px - status text
	statusLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	statusLabel.Parent = contentFrame

	-- Start dots animation
	self:StartDotsAnimation()

		-- Initial fade in
	contentFrame.BackgroundTransparency = 1
	logoLabel.TextTransparency = 1
	statusLabel.TextTransparency = 1
	progressContainer.BackgroundTransparency = 1

	-- Start fade in animation sequence
	task.spawn(function()
		-- Fade in logo first
		local fadeInTween = TweenService:Create(logoLabel,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{TextTransparency = 0}
		)
		fadeInTween:Play()

		task.wait(0.2)

		-- Fade in status label
		TweenService:Create(statusLabel,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{TextTransparency = 0}
		):Play()

		task.wait(0.2)

		-- Fade in progress container
		TweenService:Create(progressContainer,
			TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
			{BackgroundTransparency = 0.3}
		):Play()
	end)

	-- Loading interface created
end

--[[
	Start animated dots for loading text
--]]
function LoadingScreen:StartDotsAnimation()
	if dotsAnimation then
		dotsAnimation:Disconnect()
	end

	local dotCount = 0
	local lastUpdate = 0

	dotsAnimation = RunService.Heartbeat:Connect(function()
		if not statusLabel or not statusLabel.Parent then
			if dotsAnimation then
				dotsAnimation:Disconnect()
				dotsAnimation = nil
			end
			return
		end

		local currentTime = tick()
		if currentTime - lastUpdate > DOT_CYCLE_TIME / 4 then
			dotCount = (dotCount + 1) % 4
			local baseText = isLoading and "Loading assets" or "Preparing"
			local dots = string.rep(".", dotCount)
			statusLabel.Text = baseText .. dots
			lastUpdate = currentTime
		end
	end)
end

--[[
	Load block texture assets with progress tracking
--]]
function LoadingScreen:LoadBlockTextures(onProgress, onComplete)
	local assetsToLoad = {}
	local totalAssets = 0

	-- Get all texture names from TextureManager
	local textureNames = TextureManager:GetAllTextureNames()

	-- Prepare asset URLs for configured textures only
	for _, textureName in ipairs(textureNames) do
		if TextureManager:IsTextureConfigured(textureName) then
			local assetUrl = TextureManager:GetTextureId(textureName)
			if assetUrl then
				table.insert(assetsToLoad, {name = textureName, url = assetUrl})
				totalAssets = totalAssets + 1
			end
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
			statusLabel.Text = "Loading " .. assetsToLoad[startIndex].name:gsub("_", " ")
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
	Load Vector Icons that are registered for use
--]]
function LoadingScreen:LoadVectorIcons(onProgress, onComplete)
	if isLoading then return end

	isLoading = true
	statusLabel.Text = "Loading icons"

	-- Initialize IconManager if not already done
	IconManager:Initialize()

	-- Load registered icons with progress tracking
	IconManager:PreloadRegisteredIcons(
		function(loadedCount, totalCount, progress)
			-- Update progress bar
			if progressFill and progressFill.Parent then
				TweenService:Create(progressFill,
					TweenInfo.new(PROGRESS_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
					{Size = UDim2.new(progress, 0, 1, 0)}
				):Play()
			end

			-- Update status
			statusLabel.Text = "Loading icons (" .. loadedCount .. "/" .. totalCount .. ")"

			-- Call progress callback
			if onProgress then
				pcall(onProgress, loadedCount, totalCount, progress)
			end
		end,
		function(loadedCount, failedCount)
			-- Icons loading complete
			self:OnIconLoadingComplete(loadedCount, failedCount, onComplete)
		end
	)
end

--[[
	Handle icon loading completion
--]]
function LoadingScreen:OnIconLoadingComplete(loadedCount, failedCount, onComplete)
	-- Icon loading complete

	loadingComplete = true
	isLoading = false

	-- Update final status
	if failedCount > 0 then
		statusLabel.Text = "Loaded " .. loadedCount .. " icons (" .. failedCount .. " failed)"
	else
		statusLabel.Text = "All icons loaded successfully!"
	end

	-- Brief pause to show completion
	task.wait(0.5)

	-- Fade out and call completion callback
	self:FadeOut(function()
		if onComplete then
			onComplete(loadedCount, failedCount)
		end
	end)
end

--[[
	Load both block textures and icons (sequential for reliability)
--]]
function LoadingScreen:LoadAllAssets(onProgress, onComplete)
	if isLoading then
		warn("LoadingScreen: Already loading")
		return
	end

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
		-- No assets to load
		isLoading = false
		loadingComplete = true
		if onComplete then
			task.defer(onComplete, 0, 0)
		end
		return
	end

	-- Sequential loading for better reliability
	task.spawn(function()
		-- Load block textures first
		if totalTextures > 0 then
			statusLabel.Text = "Loading block textures..."

			self:LoadBlockTextures(
				function(loaded, total, progress)
					-- Update status and overall progress
					statusLabel.Text = "Loading textures (" .. loaded .. "/" .. total .. ")"
					local overallProgress = loaded / totalAssets

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
					self:LoadIconsAfterTextures(totalIcons, loaded, failed, totalAssets, onProgress, onComplete)
				end
			)
		else
			-- No textures, go straight to icons
			-- No textures, loading icons directly
			self:LoadIconsAfterTextures(totalIcons, 0, 0, totalAssets, onProgress, onComplete)
		end
	end)
end

--[[
	Helper function to load icons after block textures are done
--]]
function LoadingScreen:LoadIconsAfterTextures(totalIcons, texturesLoaded, texturesFailed, totalAssets, onProgress, onComplete)
	if totalIcons > 0 then
		statusLabel.Text = "Loading icons..."

		IconManager:PreloadRegisteredIcons(
			function(loaded, total, progress)
				local totalLoaded = texturesLoaded + loaded
				statusLabel.Text = "Loading icons (" .. loaded .. "/" .. total .. ")"

				-- Update overall progress
				local overallProgress = totalLoaded / totalAssets
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
				self:CompleteAllAssetLoading(totalLoaded, totalFailed, onComplete)
			end
		)
	else
		-- No icons to load, complete immediately
		-- No icons to load
		self:CompleteAllAssetLoading(texturesLoaded, texturesFailed, onComplete)
	end
end

--[[
	Complete the asset loading process
--]]
function LoadingScreen:CompleteAllAssetLoading(totalLoaded, totalFailed, onComplete)
	loadingComplete = true
	isLoading = false

	-- Update final status
	if totalFailed > 0 then
		statusLabel.Text = "Loaded " .. totalLoaded .. " assets (" .. totalFailed .. " failed)"
	else
		statusLabel.Text = "All assets loaded successfully!"
	end

	-- Brief pause to show completion
	task.wait(0.5)

	-- Fade out and call completion callback
	self:FadeOut(function()
		if onComplete then
			onComplete(totalLoaded, totalFailed)
		end
	end)
end

--[[
	Handle loading completion (legacy method - kept for compatibility)
--]]
function LoadingScreen:OnLoadingComplete(loadedCount, failedCount, totalAssets, onComplete)
	-- Loading complete

	loadingComplete = true
	isLoading = false

	-- Update final status
	if failedCount > 0 then
		statusLabel.Text = "Loaded " .. loadedCount .. "/" .. totalAssets .. " assets"
	else
		statusLabel.Text = "All assets loaded successfully!"
	end

	-- Brief pause to show completion
	task.wait(0.5)

	-- Fade out and call completion callback
	self:FadeOut(function()
		if onComplete then
			onComplete(loadedCount, failedCount, totalAssets)
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

	-- Stop dots animation
	if dotsAnimation then
		dotsAnimation:Disconnect()
		dotsAnimation = nil
	end

	-- Fade out all elements
	local fadeOutInfo = TweenInfo.new(FADE_DURATION, Enum.EasingStyle.Quart, Enum.EasingDirection.In)

	local logoFade = TweenService:Create(logoLabel, fadeOutInfo, {TextTransparency = 1})
	local statusFade = TweenService:Create(statusLabel, fadeOutInfo, {TextTransparency = 1})
	local progressFade = TweenService:Create(progressBar or progressFill.Parent, fadeOutInfo, {BackgroundTransparency = 1})
	local backdropFade = TweenService:Create(loadingGui:FindFirstChild("Backdrop"), fadeOutInfo, {BackgroundTransparency = 1})

	logoFade:Play()
	statusFade:Play()
	progressFade:Play()
	backdropFade:Play()

	-- Wait for fade completion then destroy
	backdropFade.Completed:Connect(function()
		task.wait(0.1)
		if loadingGui then
			loadingGui:Destroy()
			loadingGui = nil
		end

		if onComplete then
			onComplete()
		end
	end)
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