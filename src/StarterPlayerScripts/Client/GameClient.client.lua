--[[
	GameClient.client.lua - Main Client Entry Point
	Handles initialization of all client-side systems with Vector Icons integration
--]]

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- ═══════════════════════════════════════════════════════════════════════════
-- ROUTER EARLY EXIT (Single-place architecture)
-- ROUTER: Skip all init, wait for teleport
-- WORLD/HUB: Full client initialization
-- ═══════════════════════════════════════════════════════════════════════════
local ServerRoleDetector = require(ReplicatedStorage.Shared.ServerRoleDetector)
local serverRole = ServerRoleDetector.Detect()

print("[GameClient] Server role:", serverRole)

if ServerRoleDetector.IsRouter() then
	-- Minimal UI while routing
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end)
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "RouterUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	
	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 50)
	label.Position = UDim2.new(0, 0, 0.5, -25)
	label.BackgroundTransparency = 1
	label.Text = "Connecting..."
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 24
	label.Font = Enum.Font.GothamBold
	label.Parent = bg
	
	return -- Exit - server will teleport us
end
-- ═══════════════════════════════════════════════════════════════════════════

-- Voxel world
local VoxelWorld = require(ReplicatedStorage.Shared.VoxelWorld)
local BoxMesher = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BoxMesher)
local PartPool = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.PartPool)
local ChunkCompressor = require(ReplicatedStorage.Shared.VoxelWorld.Memory.ChunkCompressor)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local CameraFrustum = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.Culling.Camera)

-- Texture system
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local BlockBreakOverlayController = require(script.Parent.Controllers.BlockBreakOverlayController)
local CloudController = require(script.Parent.Controllers.CloudController)
local voxelWorldHandle = nil
local boxMesher = BoxMesher.new()
local voxelWorldContainer = nil
local chunkFolders = {}
local frustum = CameraFrustum.new()

-- Staging container in ReplicatedStorage (not rendered, better for building meshes)
local meshStagingContainer = Instance.new("Folder")
meshStagingContainer.Name = "_ChunkMeshStaging"
meshStagingContainer.Parent = ReplicatedStorage
local _lastFogEnd
-- S7: Fog calculation caching - only recalculate when camera moves significantly
local _lastFogCameraPos = nil
local FOG_UPDATE_DISTANCE_THRESHOLD = 16  -- Studs - only recalc if camera moved this far

local isHubWorld = Workspace:GetAttribute("IsHubWorld") == true
local hubRenderDistance = Workspace:GetAttribute("HubRenderDistance")
local hubInitialMeshPending = isHubWorld
Workspace:GetAttributeChangedSignal("IsHubWorld"):Connect(function()
	isHubWorld = Workspace:GetAttribute("IsHubWorld") == true
	if isHubWorld then
		hubInitialMeshPending = true
	end
	-- Update minimum chunks required based on world type
	minimumChunksRequired = isHubWorld and HUB_WORLD_CHUNK_COUNT or PLAYER_WORLD_CHUNK_COUNT
end)
Workspace:GetAttributeChangedSignal("HubRenderDistance"):Connect(function()
	hubRenderDistance = Workspace:GetAttribute("HubRenderDistance")
end)

-- Background mesh generation system (avoids blocking RenderStepped)
local meshReadyQueue = {}  -- {key, model} pairs ready to be parented
local waterfallTextures = {}
local waterfallScrollSpeed = 0.6
local meshBuildingSet = {} -- Keys currently being built (prevent duplicates)
local meshWorkerRunning = false

-- Spawn chunk tracking for loading screen
local spawnChunkKey = nil  -- "cx,cz" key for the chunk player spawns in
local spawnChunkReady = false
local onSpawnChunkReadyCallbacks = {}  -- Callbacks to fire when spawn chunk loads

-- Multi-chunk loading tracking
local requiredChunkKeys = {}  -- All chunk keys we want loaded before completing
local loadingChunkRadius = 3  -- Radius around spawn chunk to require (1 = 3x3, 2 = 5x5, 3 = 7x7, 4 = 9x9)
-- Hub world: 44 chunks (based on schematic size). Player world: based on loading radius (7×7 = 49)
local HUB_WORLD_CHUNK_COUNT = 44
local PLAYER_WORLD_CHUNK_COUNT = (loadingChunkRadius * 2 + 1) * (loadingChunkRadius * 2 + 1)  -- 49 for radius 3
local minimumChunksRequired = isHubWorld and HUB_WORLD_CHUNK_COUNT or PLAYER_WORLD_CHUNK_COUNT
-- S3-FIX: Track if server already provided the required chunk list (don't overwrite)
local serverProvidedChunkList = false

-- Check if a specific chunk is ready (meshed and parented)
local function isChunkReady(chunkKey)
	return chunkFolders[chunkKey] ~= nil
end

-- Count how many required chunks are loaded
local function countLoadedRequiredChunks()
	local count = 0
	for _, key in ipairs(requiredChunkKeys) do
		if isChunkReady(key) then
			count = count + 1
		end
	end
	return count
end

-- Check if minimum chunks are loaded
local function areMinimumChunksLoaded()
	local loaded = countLoadedRequiredChunks()
	local required = math.min(minimumChunksRequired, #requiredChunkKeys)
	return loaded >= required
end

-- Register callback for when spawn chunk is ready
local function onSpawnChunkReady(callback)
	if spawnChunkReady then
		-- Already ready, call immediately
		task.defer(callback)
	else
		table.insert(onSpawnChunkReadyCallbacks, callback)
	end
end

-- Fire spawn chunk ready callbacks
local function fireSpawnChunkReady()
	if spawnChunkReady then return end
	spawnChunkReady = true
	for _, callback in ipairs(onSpawnChunkReadyCallbacks) do
		task.defer(callback)
	end
	onSpawnChunkReadyCallbacks = {}
end

-- Check spawn readiness when a chunk loads (called from mesh parenting)
local function checkSpawnChunksReady()
	if spawnChunkReady then return end
	if areMinimumChunksLoaded() then
		fireSpawnChunkReady()
	end
end

-- Set the spawn chunk key based on world position
local function setSpawnPosition(worldX, worldZ)
	local CHUNK_SX = Constants.CHUNK_SIZE_X
	local CHUNK_SZ = Constants.CHUNK_SIZE_Z
	local bs = Constants.BLOCK_SIZE
	local cx = math.floor(worldX / (CHUNK_SX * bs))
	local cz = math.floor(worldZ / (CHUNK_SZ * bs))
	spawnChunkKey = Constants.ToChunkKey(cx, cz)
	spawnChunkReady = false

	-- S3-FIX: If server already provided the chunk list via SpawnChunksStreamed,
	-- don't overwrite it. Server knows which chunks actually exist (non-empty).
	if serverProvidedChunkList and #requiredChunkKeys > 0 then
		-- Just check if already loaded
		if areMinimumChunksLoaded() then
			fireSpawnChunkReady()
		end
		return
	end

	-- Generate list of required chunk keys (square around spawn)
	-- Filter out empty chunks to avoid waiting for chunks that don't exist
	requiredChunkKeys = {}
	local wm = voxelWorldHandle and voxelWorldHandle.GetWorldManager and voxelWorldHandle:GetWorldManager()

	for dx = -loadingChunkRadius, loadingChunkRadius do
		for dz = -loadingChunkRadius, loadingChunkRadius do
			local chunkX = cx + dx
			local chunkZ = cz + dz
			local key = Constants.ToChunkKey(chunkX, chunkZ)

			-- Only include chunks that actually exist (not empty)
			-- If we can't check (world manager not ready), include it to be safe
			if not wm or not wm.IsChunkEmpty or not wm:IsChunkEmpty(chunkX, chunkZ) then
				table.insert(requiredChunkKeys, key)
			end
		end
	end

	local total = #requiredChunkKeys

	-- Update minimum chunks required to match actual available chunks
	-- Hub world: limited to schematic chunks (44). Player world: full radius (49)
	local baseMinimum = isHubWorld and HUB_WORLD_CHUNK_COUNT or PLAYER_WORLD_CHUNK_COUNT
	minimumChunksRequired = math.min(baseMinimum, total)

	-- Check if already loaded
	if areMinimumChunksLoaded() then
		fireSpawnChunkReady()
	end
end

-- Background mesh worker - runs in a separate task, doesn't block rendering
local function startMeshWorker()
	if meshWorkerRunning then return end
	meshWorkerRunning = true

	task.spawn(function()
		-- Cache config values outside the loop
		local vwConfig = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)
		local vwDebug = vwConfig.DEBUG
		local vwPerf = vwConfig.PERFORMANCE
		-- Higher limit for hub worlds with complex schematics (can have 5000+ blocks per chunk)
		local defaultMaxParts = isHubWorld and (vwPerf.MAX_PARTS_PER_CHUNK_HUB or 2000) or (vwPerf.MAX_PARTS_PER_CHUNK or 600)
		local maxParts = (vwDebug and vwDebug.MAX_PARTS_PER_CHUNK) or defaultMaxParts
		local bs = Constants.BLOCK_SIZE
		local CHUNK_SX = Constants.CHUNK_SIZE_X
		local CHUNK_SZ = Constants.CHUNK_SIZE_Z
		local AIR = Constants.BlockType.AIR

		-- Reference to LoadingScreen for burst mode during loading
		local LoadingScreenRef = require(script.Parent.UI.LoadingScreen)

		while meshWorkerRunning do
			local cm = voxelWorldHandle and voxelWorldHandle.chunkManager
			local wm = voxelWorldHandle and voxelWorldHandle.GetWorldManager and voxelWorldHandle:GetWorldManager()

			if not cm or not cm.meshUpdateQueue or not next(cm.meshUpdateQueue) then
				-- No work to do, wait a bit
				task.wait(0.05)
				continue
			end

			-- Get camera position for prioritization
			local camera = workspace.CurrentCamera
			local camPos = camera and camera.CFrame.Position or Vector3.new(0, 0, 0)
			local bx = camPos.X / bs
			local bz = camPos.Z / bs
			local pcx = math.floor(bx / CHUNK_SX)
			local pcz = math.floor(bz / CHUNK_SZ)

			-- Build prioritized list of chunks to mesh
			local candidates = table.create(64)  -- Pre-allocate for typical queue size

			for key, chunk in pairs(cm.meshUpdateQueue) do
				-- Skip if already being built
				if not meshBuildingSet[key] then
					local dxChunks = chunk.x - pcx
					local dzChunks = chunk.z - pcz
					local dist = dxChunks * dxChunks + dzChunks * dzChunks
					table.insert(candidates, { key = key, chunk = chunk, dist = dist })
				end
			end

			-- Sort by distance (closest first) - skip for small lists (minor optimization)
			if #candidates > 4 then
				table.sort(candidates, function(a, b) return a.dist < b.dist end)
			end

			-- FAST MODE: Process multiple chunks per cycle
			-- During loading screen, be very aggressive (visual stutters invisible)
			-- During gameplay, keep low to avoid frame spikes
			local isLoadingActive = LoadingScreenRef and LoadingScreenRef.IsActive and LoadingScreenRef:IsActive()
			local maxChunksPerCycle = isLoadingActive and 32 or (isHubWorld and 6 or 2)
			local chunksBuiltThisCycle = 0

			-- S4: Frame budget limiting to prevent frame drops during loading→gameplay transition
			-- Target 60fps = 16.67ms per frame, budget 8ms for mesh work to leave headroom
			local MESH_FRAME_BUDGET_MS = isLoadingActive and 50 or 8  -- More aggressive during loading
			local cycleStartTime = os.clock()

			local function shouldYieldForFrameBudget()
				if isLoadingActive then return false end  -- No budget limit during loading screen
				return (os.clock() - cycleStartTime) * 1000 > MESH_FRAME_BUDGET_MS
			end

			-- Cache camera look direction for frustum culling (updated each cycle)
			local camLook = camera and camera.CFrame.LookVector or Vector3.new(0, 0, -1)

			for _, item in ipairs(candidates) do
				-- Check both chunk limit AND frame budget
				if chunksBuiltThisCycle >= maxChunksPerCycle then break end
				if shouldYieldForFrameBudget() then break end

				local key = item.key
				local chunk = item.chunk

				-- Frustum culling: skip chunks clearly behind camera during gameplay
				-- (Don't cull during loading - build everything)
				if not isLoadingActive and item.dist > 4 then  -- Only cull distant chunks
					local chunkCenterX = (chunk.x + 0.5) * CHUNK_SX * bs
					local chunkCenterZ = (chunk.z + 0.5) * CHUNK_SZ * bs
					local toChunk = Vector3.new(chunkCenterX - camPos.X, 0, chunkCenterZ - camPos.Z)
					local dotProduct = toChunk.X * camLook.X + toChunk.Z * camLook.Z
					-- Skip if chunk is behind camera (negative dot) and far away
					if dotProduct < -CHUNK_SX * bs then
						continue  -- Skip this chunk, will be processed when player turns
					end
				end

				-- Mark as building
				meshBuildingSet[key] = true

				-- Pre-cache neighbor chunks for faster lookups
				local neighborCache = {}
				if wm and wm.chunks then
					for dx = -1, 1 do
						for dz = -1, 1 do
							local nkey = Constants.ToChunkKey(chunk.x + dx, chunk.z + dz)
							neighborCache[nkey] = wm.chunks[nkey]
						end
					end
				end

				-- Optimized neighbor sampler with cached lookups
				local function neighborSampler(_, baseChunk, lx, ly, lz)
					if lx >= 0 and lx < CHUNK_SX and lz >= 0 and lz < CHUNK_SZ then
						return baseChunk:GetBlock(lx, ly, lz)
					end
					local cx, cz = baseChunk.x, baseChunk.z
					local nx, nz = lx, lz
					if nx < 0 then cx -= 1; nx += CHUNK_SX
					elseif nx >= CHUNK_SX then cx += 1; nx -= CHUNK_SX end
					if nz < 0 then cz -= 1; nz += CHUNK_SZ
					elseif nz >= CHUNK_SZ then cz += 1; nz -= CHUNK_SZ end
					local nkey = Constants.ToChunkKey(cx, cz)
					local neighbor = neighborCache[nkey]
					if not neighbor then return AIR end
					return neighbor:GetBlock(nx, ly, nz)
				end

				-- Generate mesh (runs in background task)
				local parts = boxMesher:GenerateMesh(chunk, wm, {
					maxParts = maxParts,
					sampleBlock = neighborSampler,
				})

				-- Create model in staging container (ReplicatedStorage = not rendered)
				-- This allows all parts to be assembled without visual impact
				local nextModel = Instance.new("Model")
				nextModel.Name = "Chunk_" .. key

				-- Parent to staging first (Roblox skips render calculations here)
				nextModel.Parent = meshStagingContainer

				-- Now parent all parts - they're in a non-rendered container
				for i = 1, #parts do
					parts[i].Parent = nextModel
				end

				-- Set pivot while still in staging
				local origin = Vector3.new((chunk.x * CHUNK_SX) * bs, 0, (chunk.z * CHUNK_SZ) * bs)
				pcall(function()
					nextModel.WorldPivot = CFrame.new(origin)
				end)

				-- Small yield to let physics/rendering settle before moving to workspace
				-- Skip during loading screen for maximum throughput
				if not isLoadingActive then
					task.wait()
				end

				-- Queue for parenting on main thread (will move from staging to workspace)
				table.insert(meshReadyQueue, { key = key, model = nextModel })
				meshBuildingSet[key] = nil
				chunksBuiltThisCycle += 1
			end

			-- Minimal delay between cycles for fast loading
			-- Skip during loading screen for maximum throughput
			if isLoadingActive then
				task.wait()  -- Minimal yield to prevent script timeout
			else
				task.wait(0.016)  -- ~1 frame between cycles during gameplay
			end
		end
	end)
end

-- Lightweight RenderStepped handler - only parents ready meshes and updates fog
local function registerWaterfallTextures(model)
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("Texture") and inst.Name == "WaterfallScroll" then
			table.insert(waterfallTextures, inst)
		end
	end
end

local function updateWaterfallTextures()
	if #waterfallTextures == 0 then
		return
	end
	local now = os.clock()
	for i = #waterfallTextures, 1, -1 do
		local tex = waterfallTextures[i]
		if not tex.Parent then
			table.remove(waterfallTextures, i)
		else
			tex.OffsetStudsV = -(now * waterfallScrollSpeed)
		end
	end
end

local function updateVoxelWorld()
	if not voxelWorldHandle then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Start background worker if not running
	startMeshWorker()

	-- Ensure container exists
	if not voxelWorldContainer then
		voxelWorldContainer = Instance.new("Folder")
		voxelWorldContainer.Name = "VoxelWorld"
		voxelWorldContainer.Parent = workspace
	end

	local cm = voxelWorldHandle.chunkManager
	local vwConfig = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)

	-- Update frustum (lightweight)
	frustum:UpdateFromCamera(camera)

	-- S7: Dynamic fog with position-based caching (skip recalculation if camera hasn't moved much)
	local camPos = camera.CFrame.Position
	local shouldRecalcFog = not _lastFogCameraPos or
		(camPos - _lastFogCameraPos).Magnitude > FOG_UPDATE_DISTANCE_THRESHOLD

	if shouldRecalcFog then
		_lastFogCameraPos = camPos
	end

	local clientVisualRadius = math.min(
		(cm and cm.renderDistance) or 8,
		(vwConfig.PERFORMANCE.MAX_RENDER_DISTANCE or 8)
	)
	if isHubWorld and hubRenderDistance then
		clientVisualRadius = math.max(clientVisualRadius, hubRenderDistance)
	end
	local horizonStuds = clientVisualRadius * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
	local fogStart = math.max(0, horizonStuds * 0.58)
	local fogEnd = math.max(fogStart + 15, horizonStuds * 0.92)

	-- Only apply fog changes if camera moved significantly OR fog values changed
	if shouldRecalcFog and (not _lastFogEnd or math.abs((_lastFogEnd or 0) - fogEnd) > 4) then
		local atm = Lighting:FindFirstChildOfClass("Atmosphere")
		if not atm then
			atm = Instance.new("Atmosphere")
			atm.Parent = Lighting
		end
		-- Minecraft-style atmosphere - clear with light blue sky haze
		atm.Density = 0.4
		atm.Haze = 0.4
		atm.Offset = 0.0
		atm.Color = Color3.fromRGB(160, 190, 255)
		atm.Decay = Color3.fromRGB(120, 160, 255)

		-- Classic Minecraft blue-tinted fog
		Lighting.FogColor = Color3.fromRGB(170, 200, 255)
		Lighting.FogStart = fogStart
		Lighting.FogEnd = fogEnd

		-- Minecraft-style ambient - bright, clean, sky-influenced
		Lighting.Ambient = Color3.fromRGB(115, 130, 160)
		Lighting.OutdoorAmbient = Color3.fromRGB(170, 185, 210)

		-- Bright daylight feel
		Lighting.Brightness = 1.0
		Lighting.ExposureCompensation = 0.1

		-- Crisp shadows like Minecraft with shaders
		Lighting.GlobalShadows = true
		Lighting.ShadowSoftness = 0.2
		Lighting.ShadowColor = Color3.fromRGB(85, 90, 110)

		-- Color correction - clean and vibrant like Minecraft
		local colorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if not colorCorrection then
			colorCorrection = Instance.new("ColorCorrectionEffect")
			colorCorrection.Parent = Lighting
		end
		colorCorrection.Brightness = 0.0
		colorCorrection.Contrast = 0.05
		colorCorrection.Saturation = 0.08
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)

		_lastFogEnd = fogEnd
	end

	-- Parent ready meshes (very fast - just parenting pre-built models)
	-- During loading screen, parent aggressively (visual stutters invisible)
	-- During gameplay, keep very low to avoid frame spikes
	local LoadingScreenRef = require(script.Parent.UI.LoadingScreen)
	local isLoadingActive = LoadingScreenRef and LoadingScreenRef.IsActive and LoadingScreenRef:IsActive()
	local maxParentsPerFrame = isLoadingActive and 50 or 2
	local parented = 0
	local cleanupQueue = {}

	while #meshReadyQueue > 0 and parented < maxParentsPerFrame do
		local ready = table.remove(meshReadyQueue, 1)
		local key = ready.key
		local nextModel = ready.model

		-- Only parent if chunk is still in the update queue (wasn't unloaded)
		if cm and cm.meshUpdateQueue and cm.meshUpdateQueue[key] then
			-- Parent new model (very fast)
			nextModel.Parent = voxelWorldContainer
			registerWaterfallTextures(nextModel)

			-- Queue old model for cleanup
			local prev = chunkFolders[key]
			if prev then
				table.insert(cleanupQueue, prev)
			end

			chunkFolders[key] = nextModel
			cm.meshUpdateQueue[key] = nil

			-- Check if enough spawn area chunks are loaded
			if not spawnChunkReady and #requiredChunkKeys > 0 then
				checkSpawnChunksReady()
			end
		else
			-- Chunk was unloaded, defer destruction to avoid frame cost
			task.defer(function()
				nextModel:Destroy()
			end)
		end

		parented += 1
	end

	-- Deferred cleanup (batch process for speed)
	if #cleanupQueue > 0 then
		task.defer(function()
			for _, oldModel in ipairs(cleanupQueue) do
				PartPool.ReleaseAllFromModel(oldModel)
				oldModel:Destroy()
			end
		end)
	end

	-- Check if hub initial mesh build is complete
	if isHubWorld and hubInitialMeshPending then
		if cm and (not cm.meshUpdateQueue or not next(cm.meshUpdateQueue)) and #meshReadyQueue == 0 then
			hubInitialMeshPending = false
			print("[VoxelWorld] Hub voxel mesh build complete")
		end
	end

	updateWaterfallTextures()
end

-- Connect voxel world update to RenderStepped
-- This will start working once voxelWorldHandle is created in initialize()
RunService.RenderStepped:Connect(updateVoxelWorld)

-- Load shared modules
local Config = require(ReplicatedStorage.Shared.Config)
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
local Logger = require(ReplicatedStorage.Shared.Logger)
local Network = require(ReplicatedStorage.Shared.Network)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Initializer = require(ReplicatedStorage.Shared.Initializer)

	-- Controllers (DELETED - using pure Roblox native)
	-- local ClientPlayerController = require(script.Parent.Controllers.ClientPlayerController)
	-- local RemotePlayerReplicator = require(script.Parent.Controllers.RemotePlayerReplicator)

	-- local clientPlayerController = ClientPlayerController.new()
	-- local remoteReplicator = RemotePlayerReplicator.new()

	-- Import client managers
	local IconManager = require(script.Parent.Managers.IconManager)
	local UIComponents = require(script.Parent.Managers.UIComponents)
	local GameState = require(script.Parent.Managers.GameState)
	local UIManager = require(script.Parent.Managers.UIManager)
	local SoundManager = require(script.Parent.Managers.SoundManager)
	local ToastManager = require(script.Parent.Managers.ToastManager)
	local EmoteManager = require(script.Parent.Managers.EmoteManager)
	local PanelManager = require(script.Parent.Managers.PanelManager)
	local InputService = require(script.Parent.Input.InputService)

	-- Import UI components
	local LoadingScreen = require(script.Parent.UI.LoadingScreen)
	local MainHUD = require(script.Parent.UI.MainHUD)
	local DailyRewardsPanel = require(script.Parent.UI.DailyRewardsPanel)
	local SettingsPanel = require(script.Parent.UI.SettingsPanel)

-- Global client state
local Client = {
	isInitialized = false,
	managers = {},
	worldReady = false
}

local WORLD_READY_EVENT = "WorldStateChanged"
local WORLD_READY_TIMEOUT = 20
local WORLD_READY_RETRY_INTERVAL = 5
local WORLD_READY_MAX_RETRIES = 3

local bootstrapComplete = false
local worldReadyWatchdogToken = 0

local function showWorldStatus(title, subtitle)
	if LoadingScreen and LoadingScreen.IsActive and LoadingScreen:IsActive() and LoadingScreen.HoldForWorldStatus then
		LoadingScreen:HoldForWorldStatus(title, subtitle)
		return
	end

	if Client.managers.UIManager and Client.managers.UIManager.ShowWorldStatus then
		Client.managers.UIManager:ShowWorldStatus(title, subtitle)
	end
end

local function hideWorldStatus()
	-- NOTE: Do NOT call LoadingScreen:ReleaseWorldHold() here!
	-- The loading screen is released by the terrain loading system (onSpawnChunkReady)
	-- after spawn chunks are actually meshed on the client.
	-- WorldStateChanged just means the SERVER is ready, not that CLIENT terrain is loaded.
	
	-- Only hide UIManager status (for post-loading status messages)
	if Client.managers.UIManager and Client.managers.UIManager.HideWorldStatus then
		Client.managers.UIManager:HideWorldStatus()
	end
end

local function tryFinalizeInitialization(reason)
	if Client.isInitialized then
		return
	end

	if not bootstrapComplete or not Client.worldReady then
		return
	end

	hideWorldStatus()

	Client.isInitialized = true
	print(("✅ Client initialization complete (%s)"):format(reason or "world_ready"))
	EventManager:SendToServer("RequestDataRefresh")
end

local function scheduleWorldReadyRetry(token, attempt)
	if Client.worldReady or worldReadyWatchdogToken ~= token then
		return
	end

	if attempt > WORLD_READY_MAX_RETRIES then
		print("❌ World ready handshake timed out.")
		showWorldStatus("Unable to load world", "Please rejoin the game and try again.")
		if Client.managers.ToastManager then
			Client.managers.ToastManager:Error("World failed to load. Please rejoin the game.", 6)
		end
		return
	end

	print(string.format("⏳ Waiting for world ready event (retry %d/%d)...", attempt, WORLD_READY_MAX_RETRIES))

	EventManager:SendToServer("RequestDataRefresh")
	if Client.managers.ToastManager then
		Client.managers.ToastManager:Warning("Waiting for world owner...", 4)
	end

	task.delay(WORLD_READY_RETRY_INTERVAL, function()
		scheduleWorldReadyRetry(token, attempt + 1)
	end)
end

local function startWorldReadyWatchdog()
	worldReadyWatchdogToken += 1
	local token = worldReadyWatchdogToken

	task.delay(WORLD_READY_TIMEOUT, function()
		if Client.worldReady or worldReadyWatchdogToken ~= token then
			return
		end
		scheduleWorldReadyRetry(token, 1)
	end)
end

local function handleWorldStateChanged(worldState)
	worldState = worldState or {}
	GameState:ApplyWorldState(worldState)

	local status = worldState.status or (worldState.isReady and "ready" or "loading")

	if worldState.isReady then
		Client.worldReady = true
		worldReadyWatchdogToken += 1
		tryFinalizeInitialization("world_ready_event")
	else
		Client.worldReady = false
		if status == "shutting_down" then
			showWorldStatus("World shutting down", worldState.message or "Saving progress...")
		else
			showWorldStatus("Waiting for world owner", worldState.message or "Syncing island data...")
		end
	end
end

--[[
	Complete initialization after loading screen
--]]
local function completeInitialization(EmoteManager)
	-- Initialize UIScaler first (before any UI is created)
	local UIScaler = require(script.Parent.Managers.UIScaler)
	if UIScaler.Initialize then
		UIScaler:Initialize()
	end
	Client.managers.UIScaler = UIScaler

	-- Initialize ToastManager now that loading is complete
	local ToastManager = require(script.Parent.Managers.ToastManager)
	if ToastManager.Initialize then
		local success, error = pcall(function()
			ToastManager:Initialize({SoundManager = Client.managers.SoundManager})
		end)
		if not success then
			warn("ToastManager initialization failed:", error)
		else
			Client.managers.ToastManager = ToastManager
		end
	end

	-- Initialize remaining managers
	local UIManager = require(script.Parent.Managers.UIManager)
	if UIManager.Initialize then
		UIManager:Initialize()
	end
	Client.managers.UIManager = UIManager

	-- Initialize UIVisibilityManager (BEFORE other UI components)
	local UIVisibilityManager = require(script.Parent.Managers.UIVisibilityManager)
	if UIVisibilityManager.Initialize then
		UIVisibilityManager:Initialize()
	end
	Client.managers.UIVisibilityManager = UIVisibilityManager

	-- Initialize PanelManager
	local PanelManager = require(script.Parent.Managers.PanelManager)
	if PanelManager.Initialize then
		PanelManager:Initialize()
	end
	Client.managers.PanelManager = PanelManager

	-- Initialize EmoteManager with preloaded assets (if available)
	if EmoteManager and EmoteManager.Initialize then
		local initSuccess = EmoteManager:Initialize({
			Network = Network,
			SoundManager = Client.managers.SoundManager
		})
		if initSuccess then
			Client.managers.EmoteManager = EmoteManager
		end
	end

	-- Initialize Voxel Hotbar and Inventory
	local VoxelHotbar = require(script.Parent.UI.VoxelHotbar)
	local VoxelInventoryPanel = require(script.Parent.UI.VoxelInventoryPanel)
	local ClientInventoryManager = require(script.Parent.Managers.ClientInventoryManager)

	-- Create hotbar first
	local hotbar = VoxelHotbar.new()
	hotbar:Initialize()
	Client.voxelHotbar = hotbar

	-- Create centralized inventory manager
	local inventoryManager = ClientInventoryManager.new(hotbar)
	inventoryManager:Initialize()
	Client.inventoryManager = inventoryManager

	-- Create inventory panel using the manager
	local inventory = VoxelInventoryPanel.new(inventoryManager)
	inventory:Initialize()
	Client.voxelInventory = inventory

	-- Set inventory reference in hotbar for inventory button
	hotbar:SetInventoryReference(inventory)

	-- Initialize TutorialManager (after InventoryManager so we can count items)
	local TutorialManager = require(script.Parent.Managers.TutorialManager)
	local tutorialSuccess, tutorialError = pcall(function()
		TutorialManager:Initialize({
			EventManager = EventManager,
			GameState = GameState,
			ToastManager = Client.managers.ToastManager,
			SoundManager = Client.managers.SoundManager,
			InventoryManager = inventoryManager,  -- Now available!
		})
	end)
	if tutorialSuccess then
		Client.managers.TutorialManager = TutorialManager
	else
		warn("TutorialManager initialization failed:", tutorialError)
	end

	-- Register inventory change callbacks for UI updates and tutorial tracking
	inventoryManager:OnInventoryChanged(function(slotIndex)
		if Client.voxelInventory and Client.voxelInventory.isOpen then
			Client.voxelInventory:UpdateInventorySlotDisplay(slotIndex)
		end
		if Client.chestUI and Client.chestUI.isOpen then
			Client.chestUI:UpdateInventorySlotDisplay(slotIndex)
		end
		-- Tutorial: track item collection
		if Client.managers.TutorialManager then
			local stack = inventoryManager:GetInventorySlot(slotIndex)
			if stack and not stack:IsEmpty() then
				Client.managers.TutorialManager:OnItemCollected(stack:GetItemId(), stack:GetCount())
			end
		end
	end)

	inventoryManager:OnHotbarChanged(function(slotIndex)
		if Client.voxelInventory and Client.voxelInventory.isOpen then
			-- Update the specific hotbar slot display
			local slotFrame = Client.voxelInventory.hotbarSlotFrames[slotIndex]
			if slotFrame and slotFrame.frame then
				Client.voxelInventory:UpdateHotbarSlotDisplay(slotIndex, slotFrame.frame, slotFrame.iconContainer, slotFrame.countLabel, slotFrame.selectionBorder)
			end
		end
		-- Tutorial: track item collection from hotbar
		if Client.managers.TutorialManager then
			local stack = inventoryManager:GetHotbarSlot(slotIndex)
			if stack and not stack:IsEmpty() then
				Client.managers.TutorialManager:OnItemCollected(stack:GetItemId(), stack:GetCount())
				if Client.voxelHotbar and Client.voxelHotbar.selectedSlot == slotIndex then
					Client.managers.TutorialManager:OnItemEquipped(stack:GetItemId())
				end
			end
		end
	end)

	-- Initialize World Ownership Display
	local WorldOwnershipDisplay = require(script.Parent.UI.WorldOwnershipDisplay)
	WorldOwnershipDisplay:Initialize()
	Client.worldOwnershipDisplay = WorldOwnershipDisplay

	-- Initialize Block Interaction (breaking/placing blocks)
	local BlockInteraction = require(script.Parent.Controllers.BlockInteraction)
	if voxelWorldHandle then
		BlockInteraction:Initialize(voxelWorldHandle)
		Client.blockInteraction = BlockInteraction
	else
		warn("⚠️ Could not initialize BlockInteraction: voxel world not ready")
	end

	-- Initialize Block Break Progress Bar
	local BlockBreakProgress = require(script.Parent.UI.BlockBreakProgress)
	BlockBreakProgress:Create()
	Client.blockBreakProgress = BlockBreakProgress

	-- Initialize Status Bars HUD (Minecraft-style health/armor/hunger)
	local statusBarsSuccess, statusBarsError = pcall(function()
		local StatusBarsHUD = require(script.Parent.UI.StatusBarsHUD)
		local statusBars = StatusBarsHUD.new()
		statusBars:Initialize()
		Client.statusBarsHUD = statusBars
	end)
	if not statusBarsSuccess then
		warn("⚠️ Status Bars HUD failed to initialize:", statusBarsError)
	end

	-- Initialize Block Break Overlay (crack stages)
	BlockBreakOverlayController:Initialize()
	Client.blockBreakOverlayController = BlockBreakOverlayController

	-- Initialize Dropped Item Controller (rendering dropped items)
	local DroppedItemController = require(script.Parent.Controllers.DroppedItemController)
	DroppedItemController:Initialize(voxelWorldHandle)
	Client.droppedItemController = DroppedItemController

	-- Initialize Mob Replication Controller (renders passive/hostile mobs)
	local MobReplicationController = require(script.Parent.Controllers.MobReplicationController)
	Client.mobReplicationController = MobReplicationController

	-- Note: MinionUI is initialized after ChestUI due to dependency

	-- Initialize Tool Visual Controller (attach placeholder handle for equipped tools)
	local ToolVisualController = require(script.Parent.Controllers.ToolVisualController)
	ToolVisualController:Initialize()
	Client.toolVisualController = ToolVisualController

	-- Initialize Tool Animation Controller (play R15 swing when sword equipped)
	local ToolAnimationController = require(script.Parent.Controllers.ToolAnimationController)
	ToolAnimationController:Initialize()
	Client.toolAnimationController = ToolAnimationController
	Client.managers.ToolAnimationController = ToolAnimationController

	-- Initialize Viewmodel Controller (first-person hand/held item)
	local ViewmodelController = require(script.Parent.Controllers.ViewmodelController)
	ViewmodelController:Initialize()
	Client.viewmodelController = ViewmodelController
	Client.managers.ViewmodelController = ViewmodelController

	-- Initialize Combat Controller (PvP)
	local CombatController = require(script.Parent.Controllers.CombatController)
	CombatController:Initialize()
	Client.combatController = CombatController

	-- Initialize Bow Controller (ranged hold-to-draw)
	local BowController = require(script.Parent.Controllers.BowController)
	BowController:Initialize(inventoryManager)
	Client.bowController = BowController

	-- Initialize NPC Controller (hub world NPC interactions)
	local NPCController = require(script.Parent.Controllers.NPCController)
	NPCController:Initialize()
	Client.npcController = NPCController

	-- Initialize NPC Trade UI (shop/merchant interface)
	local NPCTradeUI = require(script.Parent.UI.NPCTradeUI)
	local npcTradeUI = NPCTradeUI.new(inventoryManager)
	npcTradeUI:Initialize()
	Client.npcTradeUI = npcTradeUI

	-- Initialize Armor Visual Controller (render armor on character)
	local ArmorVisualController = require(script.Parent.Controllers.ArmorVisualController)
	ArmorVisualController.Init()
	Client.armorVisualController = ArmorVisualController

	-- Initialize Camera Controller (3rd person camera locked 2 studs above head)
	local CameraController = require(script.Parent.Controllers.CameraController)
	CameraController:Initialize()
	Client.cameraController = CameraController

	-- Initialize Sprint Controller (hold Left Shift to sprint)
	local SprintController = require(script.Parent.Controllers.SprintController)
	SprintController:Initialize()
	Client.sprintController = SprintController

	-- Initialize Swimming Controller (water block swimming)
	local SwimmingController = require(script.Parent.Controllers.SwimmingController)
	SwimmingController:Initialize()
	-- Set world manager reference for water detection
	if voxelWorldHandle and voxelWorldHandle.GetWorldManager then
		SwimmingController:SetWorldManager(voxelWorldHandle:GetWorldManager())
	end
	Client.swimmingController = SwimmingController

	-- Connect SprintController and SwimmingController bidirectionally
	SprintController:SetSwimmingController(SwimmingController)
	SwimmingController:SetSprintController(SprintController)

	-- Initialize Cloud Controller (Minecraft-style layered clouds)
	CloudController:Initialize()
	Client.cloudController = CloudController

	-- Initialize Mobile UI (action bar, thumbstick) after loading screen
	-- This follows the same pattern as other UI components
	local mobileController = InputService._mobileController
	if mobileController and mobileController.InitializeUI then
		mobileController:InitializeUI()
	end

	local worldsPanel = nil
	local UI_TOGGLE_DEBOUNCE = 0.3
	local lastUiToggleTime = 0

	local function canProcessUiToggle()
		local now = tick()
		if now - lastUiToggleTime < UI_TOGGLE_DEBOUNCE then
			return false
		end
		lastUiToggleTime = now
		return true
	end

	-- Initialize Chest UI (pass inventory manager for integration)
	local ChestUI = require(script.Parent.UI.ChestUI)
	local chestUI = ChestUI.new(inventoryManager)
	chestUI:Initialize()
	Client.chestUI = chestUI

	-- Initialize Furnace UI (smelting mini-game)
	local FurnaceUI = require(script.Parent.UI.FurnaceUI)
	local furnaceUI = FurnaceUI.new(inventoryManager)
	furnaceUI:Initialize()
	Client.furnaceUI = furnaceUI

	-- Initialize Minion UI (after ChestUI due to dependency)
	local MinionUI = require(script.Parent.UI.MinionUI)
	local minionUI = MinionUI.new(inventoryManager, inventory, chestUI)
	minionUI:Initialize()
	Client.minionUI = minionUI

	-- Centralize inventory/chest key handling to avoid duplicate listeners
	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.E then
			if not canProcessUiToggle() then
				return
			end
			-- Block input during furnace smelting mini-game
			if furnaceUI and furnaceUI.isSmelting then
				return
			end
			if worldsPanel and worldsPanel:IsOpen() then
				worldsPanel:Close("inventory")
				if inventory and not inventory.isOpen then
					inventory:Open()
				end
				return
			end
			if worldsPanel and worldsPanel.IsClosing and worldsPanel:IsClosing() then
				worldsPanel:SetPendingCloseMode("inventory")
			end
			if npcTradeUI and npcTradeUI.isOpen then
				npcTradeUI:Close()
			elseif minionUI and minionUI.isOpen then
				minionUI:Close()
			elseif chestUI and chestUI.isOpen then
				chestUI:Close()
			elseif furnaceUI and furnaceUI.isOpen then
				-- Close furnace and open inventory
				furnaceUI:Close("inventory")
				if inventory and not inventory.isOpen then
					inventory:Open()
				end
			else
				if inventory then
					inventory:Toggle()
					-- Tutorial tracking: notify of inventory panel opened
					if inventory.isOpen and Client.managers.TutorialManager then
						Client.managers.TutorialManager:OnPanelOpened("inventory")
					end
				end
			end
		elseif input.KeyCode == Enum.KeyCode.B then
			if not canProcessUiToggle() then
				return
			end
			-- Block input during furnace smelting mini-game
			if furnaceUI and furnaceUI.isSmelting then
				return
			end
			if npcTradeUI and npcTradeUI.isOpen then
				npcTradeUI:Close()
			end
			if minionUI and minionUI.isOpen then
				minionUI:Close()
			end
			if chestUI and chestUI.isOpen then
				local targetMode = worldsPanel and "worlds" or nil
				chestUI:Close(targetMode)
			end
			if furnaceUI and furnaceUI.isOpen then
				-- Close furnace when opening worlds
				furnaceUI:Close("worlds")
			end
			if inventory then
				if inventory.isOpen then
					inventory:Close("worlds")
				elseif inventory.IsClosing and inventory:IsClosing() then
					inventory:SetPendingCloseMode("worlds")
				end
			end
			if worldsPanel then
				if worldsPanel:IsOpen() then
					worldsPanel:Close()
				else
					worldsPanel:Open()
				end
			end
			-- Silently skip if worldsPanel not yet initialized
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if npcTradeUI and npcTradeUI.isOpen then
				npcTradeUI:Close()
			elseif minionUI and minionUI.isOpen then
				minionUI:Close()
			elseif chestUI and chestUI.isOpen then
				chestUI:Close()
			elseif furnaceUI and furnaceUI.isOpen then
				-- ESC closes furnace (or cancels smelting if active)
				if furnaceUI.isSmelting then
					furnaceUI:OnCancelSmelt()
				else
					furnaceUI:Close()
				end
			elseif inventory and inventory.isOpen then
				inventory:Close()
			elseif worldsPanel and worldsPanel:IsOpen() then
				worldsPanel:Close()
			end
		end
	end)

	-- Open Workbench (crafting table interaction)
	EventManager:RegisterEvent("WorkbenchOpened", function(data)
		if inventory then
			-- Close chest if open
			if chestUI and chestUI.isOpen then
				chestUI:Close("inventory")
			end
			-- Enable workbench filter and open
			inventory:SetWorkbenchMode(true)
			inventory:Open()

			-- Tutorial tracking: notify of workbench interaction
			if Client.managers.TutorialManager then
				Client.managers.TutorialManager:OnBlockInteracted("crafting_table")
			end
		end
	end)

	-- Handle crafting result for tutorial tracking
	EventManager:RegisterEvent("CraftRecipeBatchResult", function(data)
		-- data = {recipeId:string, acceptedCount:number, outputItemId:number, outputPerCraft:number}
		if data and data.outputItemId and data.acceptedCount and data.acceptedCount > 0 then
			-- Tutorial tracking: notify of successful craft with total items crafted
			if Client.managers.TutorialManager then
				local totalCrafted = data.acceptedCount * (data.outputPerCraft or 1)
				Client.managers.TutorialManager:OnItemCrafted(data.outputItemId, totalCrafted)
			end
		end
	end)

	-- Re-register event handlers with complete managers (including ToastManager and ToolAnimationController)
	local completeEventConfig = EventManager:CreateClientEventConfig(Client.managers)
	EventManager:RegisterEvents(completeEventConfig)

	-- Initialize UI panels BEFORE MainHUD (so they're registered with PanelManager)
	local DailyRewardsPanel = require(script.Parent.UI.DailyRewardsPanel)
	if DailyRewardsPanel.Initialize then
		DailyRewardsPanel:Initialize()
	end
	Client.managers.DailyRewardsPanel = DailyRewardsPanel

	local SettingsPanel = require(script.Parent.UI.SettingsPanel)
	if SettingsPanel.Initialize then
		SettingsPanel:Initialize()
	end
	Client.managers.SettingsPanel = SettingsPanel

	local ShopPanel = require(script.Parent.UI.ShopPanel)
	if ShopPanel.Initialize then
		ShopPanel:Initialize()
	end
	Client.managers.ShopPanel = ShopPanel

	-- Initialize standalone Worlds panel (available in all places, not just lobby)
	local WorldsPanelModule = require(script.Parent.UI.WorldsPanel)
	local worldsPanelInstance = WorldsPanelModule.new()
	worldsPanelInstance:Initialize()
	Client.managers.WorldsPanel = worldsPanelInstance
	worldsPanel = worldsPanelInstance
	if hotbar then
		hotbar:SetWorldsPanel(worldsPanelInstance)
	end
	if Client.npcController then
		Client.npcController:SetWorldsPanel(worldsPanelInstance)
	end

	-- Create main HUD (after panels are registered)
	local MainHUD = require(script.Parent.UI.MainHUD)
	if MainHUD.Create then
		MainHUD:Create()
	end

	-- Create F3 Debug Overlay (Minecraft-style debug info)
	local F3DebugOverlay = require(script.Parent.UI.F3DebugOverlay)
	F3DebugOverlay:Create()
	Client.f3DebugOverlay = F3DebugOverlay

	-- Setup character handling
	player.CharacterAdded:Connect(function(character)
		task.wait(2) -- Wait for character to load
		if Client.isInitialized and EventManager then
            EventManager:SendToServer("RequestDataRefresh")
		end
	end)

	-- If character already exists
	if player.Character then
		task.spawn(function()
			task.wait(1)
			if Client.isInitialized and EventManager then
				EventManager:SendToServer("RequestDataRefresh")
			end
		end)
	end

	-- Signal server that client is ready (AFTER event handlers are registered)
	EventManager:SendToServer("ClientReady")
	EventManager:SendToServer("RequestDataRefresh")

	bootstrapComplete = true
	if Client.worldReady then
		tryFinalizeInitialization("bootstrap_complete")
	else
		print("⌛ Awaiting world ready handshake before enabling gameplay...")
		showWorldStatus("Waiting for world owner", "Syncing island data...")
		startWorldReadyWatchdog()
	end

end

--[[
	Initialize with loading screen for emote preloading
--]]
local function initialize()
	if Client.isInitialized then
		return
	end

	-- Initialize core systems first
	Logger:Initialize(Config.LOGGING, Network)
	EventManager:Initialize(Network)

	-- Register all events first (defines RemoteEvents with proper parameter signatures)
	EventManager:RegisterAllEvents()

	-- CRITICAL: Create loading screen and set world hold BEFORE event handlers are registered
	-- This ensures PlayerEntitySpawned and other events can properly interact with the loading screen
	local LoadingScreenEarly = require(script.Parent.UI.LoadingScreen)
	LoadingScreenEarly:Create()
	LoadingScreenEarly:HoldForWorldStatus("Loading", "Preparing world...")

	-- Initialize unified input orchestration before gameplay controllers bind
	InputService:Initialize()

	-- Initialize voxel world in SERVER-AUTHORITATIVE mode
	local clientRenderDistance = hubRenderDistance or 3
    voxelWorldHandle = VoxelWorld.CreateClientView(clientRenderDistance)
	if hubRenderDistance and voxelWorldHandle and voxelWorldHandle.chunkManager then
		voxelWorldHandle.chunkManager.renderDistance = hubRenderDistance
	end

	-- Initialize player systems (DISABLED - using pure Roblox)
	-- clientPlayerController:Initialize(voxelWorldHandle)

	-- Initialize remote player tracking (DISABLED - Roblox handles everything)
	-- print("👥 Initializing remote player replicator...")
	-- remoteReplicator:Initialize()
	-- remoteReplicator:Start()

	-- Register network event handlers
    EventManager:RegisterEvent("ChunkDataStreamed", function(data)
        if not voxelWorldHandle or not voxelWorldHandle.GetWorldManager then
            warn("[ChunkDataStreamed] No voxelWorldHandle yet, dropping chunk data")
            return
        end
        local wm = voxelWorldHandle:GetWorldManager()
        if not wm then
            warn("[ChunkDataStreamed] No world manager, dropping chunk data")
            return
        end
        local chunk = wm:GetChunk(data.chunk.x, data.chunk.z)
        if not chunk then
            warn(string.format("[ChunkDataStreamed] Failed to create chunk (%d,%d)", data.chunk.x, data.chunk.z))
            return
        end

        local key = data.key or Constants.ToChunkKey(data.chunk.x, data.chunk.z)
        -- Prefer compressed payloads (palette + RLE) when present
        if data.chunk.palette and data.chunk.runs and data.chunk.dims then
            local lin = ChunkCompressor.DecompressToLinear(data.chunk)
            chunk:DeserializeLinear({
                x = data.chunk.x,
                z = data.chunk.z,
                flat = lin.flat,
                flatMeta = lin.flatMeta,
                dims = data.chunk.dims,
                state = data.chunk.state
            })
        elseif data.chunk.flat and data.chunk.dims then
            -- Fallback to linear deserialization when provided
            chunk:DeserializeLinear(data.chunk)
        else
            -- Legacy nested blocks table
            chunk:Deserialize(data.chunk)
        end
        voxelWorldHandle.chunkManager.meshUpdateQueue = voxelWorldHandle.chunkManager.meshUpdateQueue or {}

        local isNewChunk = not chunkFolders[key]

        -- Queue this chunk for meshing
        if isNewChunk then
            voxelWorldHandle.chunkManager.meshUpdateQueue[key] = chunk
        end

        -- When a new chunk loads, remesh adjacent neighbors that may have rendered
        -- border faces assuming this chunk was empty (AIR). Now that we have real
        -- block data, neighbors need to update their border faces.
        if isNewChunk then
            local cx, cz = data.chunk.x, data.chunk.z
            local neighborOffsets = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}
            for _, offset in ipairs(neighborOffsets) do
                local nx, nz = cx + offset[1], cz + offset[2]
                local neighborKey = Constants.ToChunkKey(nx, nz)
                -- Only remesh if neighbor already has a rendered mesh
                -- AND is not currently being built (prevent duplicate builds)
                if chunkFolders[neighborKey] and not meshBuildingSet[neighborKey] then
                    local neighborChunk = wm and wm.chunks and wm.chunks[neighborKey]
                    if neighborChunk then
                        voxelWorldHandle.chunkManager.meshUpdateQueue[neighborKey] = neighborChunk
                    end
                end
            end
        end
    end)

	EventManager:RegisterEvent("ChunkUnload", function(data)
		-- Drop any pending mesh updates for this chunk first
		if voxelWorldHandle and voxelWorldHandle.chunkManager and voxelWorldHandle.chunkManager.meshUpdateQueue then
			voxelWorldHandle.chunkManager.meshUpdateQueue[data.key] = nil
		end

		-- Remove rendered mesh for this chunk if present
		local folder = chunkFolders[data.key]
		if folder then
			PartPool.ReleaseAllFromModel(folder)
			folder:Destroy()
			chunkFolders[data.key] = nil
		end

		-- Unload chunk data from world manager
		if voxelWorldHandle and voxelWorldHandle.chunkManager then
			voxelWorldHandle.chunkManager:UnloadChunk(data.key)
		end
	end)

	-- S3: Handle spawn chunks pre-streaming notification from server
	-- This tells us which chunks are needed before the loading screen should fade
	EventManager:RegisterEvent("SpawnChunksStreamed", function(data)
		if not data then return end

		-- Update required chunk keys to include the spawn chunks
		-- This ensures the loading screen waits for these specific chunks
		if data.chunkKeys and #data.chunkKeys > 0 then
			-- Clear and repopulate required keys with spawn chunks
			requiredChunkKeys = {}
			for _, key in ipairs(data.chunkKeys) do
				table.insert(requiredChunkKeys, key)
			end
			-- S3-FIX: Mark that server provided the chunk list - setSpawnPosition should not overwrite
			serverProvidedChunkList = true
			-- Update minimum required to match the actual chunks server will send
			minimumChunksRequired = #requiredChunkKeys
		end

		-- If spawn chunk is already meshed, trigger ready check
		if data.spawnChunkX and data.spawnChunkZ then
			local centerKey = string.format("%d,%d", data.spawnChunkX, data.spawnChunkZ)
			if chunkFolders[centerKey] and areMinimumChunksLoaded() then
				fireSpawnChunkReady()
			end
		end
	end)

	EventManager:RegisterEvent(WORLD_READY_EVENT, handleWorldStateChanged)

	-- Batched chunk remeshing system
	-- Collects all affected chunks and processes them together to avoid border flicker
	local pendingRemeshChunks = {} -- Set of "cx,cz" keys
	local remeshBatchTimer = nil
	local remeshBatchStartTime = nil
	local REMESH_BATCH_DELAY = 0.05 -- 50ms - short delay to batch rapid edits
	local REMESH_BATCH_DELAY_WATER = 0.15 -- 150ms - longer delay for water (many rapid updates)
	local REMESH_MAX_DELAY = 0.3 -- 300ms - maximum delay before forced flush (prevents indefinite batching)
	local pendingWaterChanges = false -- Track if batch contains water changes

	-- Queue a chunk for batched remesh
	local function queueChunkRemesh(cx, cz)
		local k = Constants.ToChunkKey(cx, cz)
		pendingRemeshChunks[k] = {cx = cx, cz = cz}
	end

	-- Flush all pending chunk remeshes at once
	local function flushPendingRemeshes()
		remeshBatchTimer = nil
		remeshBatchStartTime = nil
		pendingWaterChanges = false

		if not voxelWorldHandle then return end
		local wm = voxelWorldHandle:GetWorldManager()
		if not wm then return end
		local cm = voxelWorldHandle.chunkManager
		if not cm then return end

		-- Queue all pending chunks for mesh update
		-- Skip chunks currently being built to prevent duplicate work
		for k, coords in pairs(pendingRemeshChunks) do
			if not meshBuildingSet[k] then
				local ch = wm:GetChunk(coords.cx, coords.cz)
				if ch then
					cm.meshUpdateQueue[k] = ch
				end
			end
		end

		-- Clear the pending set
		pendingRemeshChunks = {}
	end

	-- Schedule a batched remesh (resets timer on each call to batch rapid edits)
	-- Uses longer delay for water and caps maximum delay
	local function scheduleBatchedRemesh(isWater)
		-- Track water changes for delay calculation
		if isWater then
			pendingWaterChanges = true
		end

		-- Record batch start time (for max delay cap)
		if not remeshBatchStartTime then
			remeshBatchStartTime = tick()
		end

		-- Check if we've hit max delay - force flush
		local elapsed = tick() - remeshBatchStartTime
		if elapsed >= REMESH_MAX_DELAY then
			if remeshBatchTimer then
				task.cancel(remeshBatchTimer)
				remeshBatchTimer = nil
			end
			flushPendingRemeshes()
			return
		end

		-- Calculate delay based on batch contents
		local delay = pendingWaterChanges and REMESH_BATCH_DELAY_WATER or REMESH_BATCH_DELAY

		-- Cap delay to not exceed max delay from start
		local remainingTime = REMESH_MAX_DELAY - elapsed
		delay = math.min(delay, remainingTime)

		if remeshBatchTimer then
			task.cancel(remeshBatchTimer)
		end
		remeshBatchTimer = task.delay(delay, flushPendingRemeshes)
	end

	EventManager:RegisterEvent("BlockChanged", function(data)
		if not voxelWorldHandle then return end
		local wm = voxelWorldHandle:GetWorldManager()
		if not wm then return end

		-- Update block data immediately
		wm:SetBlock(data.x, data.y, data.z, data.blockId)

		-- Set metadata if provided
		if data.metadata and data.metadata ~= 0 then
			wm:SetBlockMetadata(data.x, data.y, data.z, data.metadata)
		end

		-- Check if this is a water block (for batching optimization)
		local isWaterBlock = data.blockId == Constants.BlockType.WATER_SOURCE
			or data.blockId == Constants.BlockType.FLOWING_WATER

		-- Also check if previous block was water (water removal)
		local prevBlock = wm:GetBlock(data.x, data.y, data.z)
		local wasWaterBlock = prevBlock == Constants.BlockType.WATER_SOURCE
			or prevBlock == Constants.BlockType.FLOWING_WATER
		if data.blockId and data.blockId ~= 0 and not isWaterBlock then
			local SoundManager = Client.managers and Client.managers.SoundManager
			if SoundManager and SoundManager.PlaySFXSafely then
				SoundManager:PlaySFXSafely("blockPlace")
			end

			-- Tutorial tracking: notify of block placed
			if Client.managers.TutorialManager then
				Client.managers.TutorialManager:OnBlockPlaced(data.blockId)
			end
		end

		-- Collect affected chunks (block's chunk + edge neighbors)
		local chunkX = math.floor(data.x / Constants.CHUNK_SIZE_X)
		local chunkZ = math.floor(data.z / Constants.CHUNK_SIZE_Z)

		-- Always queue the block's own chunk
		queueChunkRemesh(chunkX, chunkZ)

		-- For water blocks, queue ALL 4 neighbor chunks
		-- Water mesh visibility depends on neighbor water heights, so any water change
		-- can affect adjacent chunk water meshes (not just edge blocks)
		if isWaterBlock or wasWaterBlock then
			queueChunkRemesh(chunkX - 1, chunkZ)
			queueChunkRemesh(chunkX + 1, chunkZ)
			queueChunkRemesh(chunkX, chunkZ - 1)
			queueChunkRemesh(chunkX, chunkZ + 1)
		else
			-- For non-water blocks, only queue neighbors if block is on chunk edge
			local localX = data.x - chunkX * Constants.CHUNK_SIZE_X
			local localZ = data.z - chunkZ * Constants.CHUNK_SIZE_Z

			if localX == 0 then
				queueChunkRemesh(chunkX - 1, chunkZ)
			elseif localX == (Constants.CHUNK_SIZE_X - 1) then
				queueChunkRemesh(chunkX + 1, chunkZ)
			end
			if localZ == 0 then
				queueChunkRemesh(chunkX, chunkZ - 1)
			elseif localZ == (Constants.CHUNK_SIZE_Z - 1) then
				queueChunkRemesh(chunkX, chunkZ + 1)
			end
		end

		-- Schedule batched flush (all chunks will be queued together)
		-- Pass water flag for longer batching delay (water causes many rapid updates)
		scheduleBatchedRemesh(isWaterBlock or wasWaterBlock)

		-- Update block targeting after block change
		if Client.blockInteraction and Client.blockInteraction.UpdateTargeting then
			Client.blockInteraction:UpdateTargeting()
		end
	end)

	EventManager:RegisterEvent("BlockChangeRejected", function(data)
		print("Block change rejected:", data.reason)
		-- TODO: Revert client-side prediction if implemented
	end)

	-- Handle block break progress updates (show progress bar)
	EventManager:RegisterEvent("BlockBreakProgress", function(data)
		-- data = {x, y, z, progress, playerUserId}
		-- Only show progress for the local player
		if data.playerUserId == player.UserId then
			if Client.blockBreakProgress then
				Client.blockBreakProgress:UpdateProgress(data.progress)
			end
		end
	end)

	-- Handle block broken event (play break sound)
	EventManager:RegisterEvent("BlockBroken", function(data)
		-- Play block break sound
		-- data = {x, y, z, blockId, playerUserId, canHarvest}
		local SoundManager = Client.managers and Client.managers.SoundManager
		if SoundManager and SoundManager.PlaySFXSafely then
			SoundManager:PlaySFXSafely("blockBreak")
		end

		-- Reset progress bar when block is fully broken (any player)
		if Client.blockBreakProgress and data.playerUserId == player.UserId then
			Client.blockBreakProgress:Reset()
		end

		-- Tutorial tracking: notify of block broken
		if data.playerUserId == player.UserId and Client.managers.TutorialManager then
			Client.managers.TutorialManager:OnBlockBroken(data.blockId)
		end

		-- Stop client breaking loop immediately if the broken block matches current
		local BI = Client.blockInteraction
		if BI and BI._getBreakingBlock and type(BI._getBreakingBlock) == "function" then
			local bb = BI:_getBreakingBlock()
			if bb and data.x == bb.X and data.y == bb.Y and data.z == bb.Z then
				BI:_forceStopBreaking()
			end
		end

		-- Update block targeting after block broken (even if camera hasn't moved)
		if Client.blockInteraction and Client.blockInteraction.UpdateTargeting then
			Client.blockInteraction:UpdateTargeting()
		end
	end)

    -- Request initial chunks after our custom entity spawns
    local initializedFromEntity = false
    local playerSpawnPosition = nil
    EventManager:RegisterEvent("PlayerEntitySpawned", function(data)
        if initializedFromEntity then return end
        initializedFromEntity = true

        -- Use Roblox default camera (no custom control)
        -- Camera will follow character automatically

        local Players = game:GetService("Players")
        local localPlayer = Players.LocalPlayer

        -- Use R15 character instead of custom rig
        local character = data.character or localPlayer.Character
        if not character then
            warn("❌ No R15 character available for player controller")
            return
        end

        -- Wait for HumanoidRootPart
        local rootPart = character:WaitForChild("HumanoidRootPart", 5)
        if not rootPart then
            warn("❌ R15 character missing HumanoidRootPart")
            return
        end

        -- Get current position from character (server already spawned it at correct location)
        local pos = rootPart.Position
        playerSpawnPosition = pos

        -- Set spawn chunk for loading tracking (all worlds)
        setSpawnPosition(pos.X, pos.Z)

        -- Set replication focus to character
        pcall(function()
            localPlayer.ReplicationFocus = rootPart
        end)

        -- Send initial position to server and request chunks
        EventManager:SendToServer("VoxelPlayerPositionUpdate", { x = pos.X, z = pos.Z })
        EventManager:SendToServer("VoxelRequestInitialChunks")

        -- Hold loading screen until minimum chunks are loaded
        local LoadingScreen = require(script.Parent.UI.LoadingScreen)
        if LoadingScreen.IsActive and LoadingScreen:IsActive() then
            local totalRequired = #requiredChunkKeys
            LoadingScreen:HoldForWorldStatus("Loading World", "Terrain 0%")

            -- Update progress periodically while waiting
            local progressUpdateConnection
            progressUpdateConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if spawnChunkReady then
                    if progressUpdateConnection then
                        progressUpdateConnection:Disconnect()
                        progressUpdateConnection = nil
                    end
                    return
                end
                local loaded = countLoadedRequiredChunks()
                local percent = math.floor((loaded / totalRequired) * 100)
                if LoadingScreen.HoldForWorldStatus then
                    LoadingScreen:HoldForWorldStatus("Loading World", string.format("Terrain %d%%", percent))
                end
            end)

            -- Wait for spawn chunks to be ready, then release
            onSpawnChunkReady(function()
                if progressUpdateConnection then
                    progressUpdateConnection:Disconnect()
                    progressUpdateConnection = nil
                end
                if LoadingScreen.ReleaseWorldHold then
                    LoadingScreen:ReleaseWorldHold()
                end
            end)

            -- Timeout fallback - don't hold forever
            task.delay(20, function()
                if not spawnChunkReady then
                    if progressUpdateConnection then
                        progressUpdateConnection:Disconnect()
                        progressUpdateConnection = nil
                    end
                    local loaded = countLoadedRequiredChunks()
                    local required = math.min(minimumChunksRequired, #requiredChunkKeys)
                    warn(string.format("⚠️ Spawn chunk load timeout (%d/%d loaded) - forcing loading screen release", loaded, required))
                    spawnChunkReady = true
                    if LoadingScreen.ReleaseWorldHold then
                        LoadingScreen:ReleaseWorldHold()
                    end
                end
            end)
        end
    end)

    -- Player snapshots (DISABLED - no custom controller)
    -- EventManager:RegisterEvent("PlayerEntitiesSnapshot", function(data)
    --     if clientPlayerController and clientPlayerController.OnEntitiesSnapshot then
    --         clientPlayerController:OnEntitiesSnapshot(data)
    --     end
    -- end)

    -- EventManager:RegisterEvent("PlayerCorrection", function(data)
    --     if clientPlayerController and clientPlayerController.OnCorrection then
    --         clientPlayerController:OnCorrection(data)
    --     end
    -- end)

    -- Set up regular position updates (use camera since we have custom entity)
    RunService.Heartbeat:Connect(function()
        local cam = workspace.CurrentCamera
        if not cam then return end

        local Config = require(game.ReplicatedStorage.Shared.VoxelWorld.Core.Config)
        -- Update server with player position (rate limited)
        if tick() - (lastPositionUpdate or 0) >= 1/Config.NETWORK.POSITION_UPDATE_RATE then
            lastPositionUpdate = tick()
            local p = cam.CFrame.Position
            EventManager:SendToServer("VoxelPlayerPositionUpdate", {
                x = p.X,
                z = p.Z
            })
        end
    end)

	-- Load and initialize managers (except UI)
	local GameState = require(script.Parent.Managers.GameState)
	Client.managers.GameState = GameState

	local SoundManager = require(script.Parent.Managers.SoundManager)
	if SoundManager.Initialize then
		SoundManager:Initialize()
	end
	Client.managers.SoundManager = SoundManager

	-- Note: ToastManager will be initialized after loading completes
	-- to avoid showing notifications during loading screen

	-- Register essential event handlers EARLY (before loading screen)
	-- Use a minimal managers table for now (ToastManager will be added later)
	local earlyManagers = {
		GameState = Client.managers.GameState,
		SoundManager = Client.managers.SoundManager
	}
	local eventConfig = EventManager:CreateClientEventConfig(earlyManagers)
	EventManager:RegisterEvents(eventConfig)

	-- Start the asynchronous loading and initialization process
	task.spawn(function()
		-- Loading screen was already created and world hold was set in initialize()
		-- Now we just need to load assets
		local LoadingScreen = require(script.Parent.UI.LoadingScreen)

		-- Initialize IconManager and UIComponents
		IconManager:Initialize()
		UIComponents:Initialize()

		-- Register icons that MainHUD will use
		IconManager:RegisterIcon("Currency", "Cash", {context = "MainHUD_CoinsDisplay"})
		IconManager:RegisterIcon("Items", "Ticket", {context = "MainHUD_GemsDisplay"})
		IconManager:RegisterIcon("General", "Upgrade", {context = "MainHUD_LevelDisplay"})
		IconManager:RegisterIcon("UI", "Calendar", {context = "MainHUD_DailyRewardsButton"})
		IconManager:RegisterIcon("General", "Shop", {context = "MainHUD_ShopButton"})
		IconManager:RegisterIcon("Clothing", "Backpack", {context = "MainHUD_InventoryButton"})
		IconManager:RegisterIcon("General", "Settings", {context = "MainHUD_SettingsButton"})
		IconManager:RegisterIcon("General", "Stats", {context = "MainHUD_StatsButton"})
		IconManager:RegisterIcon("General", "Trophy", {context = "MainHUD_AchievementsButton"})
		IconManager:RegisterIcon("UI", "X", {context = "Panel_CloseButton"})

		-- Register icons for bottom bar
		IconManager:RegisterIcon("General", "GiftBox", {context = "MainHUD_FreeCoinsButton"})
		IconManager:RegisterIcon("General", "Heart", {context = "MainHUD_EmoteButton"})

		-- Register icons for daily rewards panel
		IconManager:RegisterIcon("Chest", "Chest1", {context = "DailyRewards_ChestIcon"})

		-- Register icons for inventory system
		IconManager:RegisterIcon("Shapes", "Cube", {context = "Inventory_SpawnerIcon"})

		-- Register icons for shop system
		IconManager:RegisterIcon("General", "Paw", {context = "Shop_SpawnerIcon"})
		IconManager:RegisterIcon("General", "Upgrade", {context = "Shop_UpgradeIcon"})
		IconManager:RegisterIcon("Shapes", "Cube", {context = "Shop_ResourceIcon"})
		IconManager:RegisterIcon("General", "GiftBox", {context = "Shop_CrateIcon"})

		-- Register icons for quest rewards
		IconManager:RegisterIcon("Currency", "Cash", {context = "Quest_CoinsReward"})
		IconManager:RegisterIcon("Currency", "Gem", {context = "Quest_GemsReward"})
		IconManager:RegisterIcon("General", "Upgrade", {context = "Quest_ExperienceReward"})
		IconManager:RegisterIcon("Currency", "Cash", {context = "Shop_CurrencyIcon"})
		IconManager:RegisterIcon("Currency", "Gem", {context = "Shop_PremiumCurrencyIcon"})

		-- Register icons that ToastManager will use (from centralized config)
		local toastIconConfig = Config.TOAST_ICONS

		-- Register all toast type icons
		for toastType, iconConfig in pairs(toastIconConfig.types) do
			IconManager:RegisterIcon(iconConfig.iconCategory, iconConfig.iconName, {
				context = iconConfig.context
			})
		end

		-- Register fallback icons
		for fallbackType, iconConfig in pairs(toastIconConfig.fallbacks) do
			IconManager:RegisterIcon(iconConfig.iconCategory, iconConfig.iconName, {
				context = iconConfig.context
			})
		end

		-- Initialize EmoteManager for later use (not for preloading)
		local success, EmoteManager = pcall(require, script.Parent.Managers.EmoteManager)
		if not success then
			warn("Failed to load EmoteManager:", EmoteManager)
			EmoteManager = nil
		end

		-- Load block textures and Vector Icons
		LoadingScreen:LoadAllAssets(
			function(loaded, total, progress)
				-- Progress callback
				-- Loading progress update
			end,
			function(loadedCount, failedCount)
				-- Completion callback (called after fade-out)
				EventManager:SendToServer("ClientLoadingComplete")
			end,
			function()
				-- Run heavy UI initialization while loading screen is still visible
				completeInitialization(EmoteManager)
			end
		)
	end)
end

--[[
	Safe initialization with simple error handling
--]]
local function safeInitialize()
	if Client.isInitialized then
		return
	end

	local success, error = pcall(initialize)

	if not success then
		warn("❌ Client initialization failed:", error)

		-- Create simple error display
		local errorGui = Instance.new("ScreenGui")
		errorGui.Name = "ClientErrorGui"
		errorGui.Parent = player:WaitForChild("PlayerGui")

		local errorFrame = Instance.new("Frame")
		errorFrame.Size = UDim2.new(0, 400, 0, 200)
		errorFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
		errorFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
		errorFrame.BorderSizePixel = 0
		errorFrame.Parent = errorGui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = errorFrame

		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(1, -20, 0, 40)
		titleLabel.Position = UDim2.new(0, 10, 0, 10)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = "Initialization Failed"
		titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
		titleLabel.TextScaled = true
		titleLabel.Font = BOLD_FONT
		titleLabel.Parent = errorFrame

		local errorLabel = Instance.new("TextLabel")
		errorLabel.Size = UDim2.new(1, -20, 1, -60)
		errorLabel.Position = UDim2.new(0, 10, 0, 50)
		errorLabel.BackgroundTransparency = 1
		errorLabel.Text = "Please rejoin the game.\n\nError: " .. tostring(error)
		errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		errorLabel.TextScaled = true
		errorLabel.Font = BOLD_FONT
		errorLabel.TextWrapped = true
		errorLabel.Parent = errorFrame
	end
end

-- Cleanup on player leaving
Players.PlayerRemoving:Connect(function(leavingPlayer)
	if leavingPlayer == player then
		if Client.managers then
			for name, manager in pairs(Client.managers) do
				if manager and manager.Cleanup then
					pcall(manager.Cleanup, manager)
				end
			end
		end
	end
end)

-- Start initialization
safeInitialize()

-- Export for debugging
Client.IconManager = IconManager
-- Hook LMB hold/release for combat using ContextActionService
local ContextActionService = game:GetService("ContextActionService")
local function handleCombat(actionName, inputState, inputObject)
	if actionName ~= "CombatLMB" then return end
	if not Client or not Client.combatController then return end
	if inputState == Enum.UserInputState.Begin then
		Client.combatController:SetHolding(true)
	elseif inputState == Enum.UserInputState.End then
		Client.combatController:SetHolding(false)
	end
    return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("CombatLMB", handleCombat, false, Enum.UserInputType.MouseButton1)