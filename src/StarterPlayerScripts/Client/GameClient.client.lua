--[[
	GameClient.client.lua - Main Client Entry Point
	Handles initialization of all client-side systems with Vector Icons integration
--]]

print("AuraSystem Game Client Starting...")

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Voxel world
local VoxelWorld = require(ReplicatedStorage.Shared.VoxelWorld)
local BoxMesher = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BoxMesher)
local PartPool = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.PartPool)
local ChunkCompressor = require(ReplicatedStorage.Shared.VoxelWorld.Memory.ChunkCompressor)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local CameraFrustum = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.Culling.Camera)

-- Texture system (verify it loads)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local BlockBreakOverlayController = require(script.Parent.Controllers.BlockBreakOverlayController)
local CloudController = require(script.Parent.Controllers.CloudController)
print("[VoxelTextures] Texture system loaded. Enabled:", TextureManager:IsEnabled())
local voxelWorldHandle = nil
local boxMesher = BoxMesher.new()
local voxelWorldContainer = nil
local chunkFolders = {}
local frustum = CameraFrustum.new()
local _lastFogEnd
local isHubWorld = Workspace:GetAttribute("IsHubWorld") == true
local hubRenderDistance = Workspace:GetAttribute("HubRenderDistance")
local hubInitialMeshPending = isHubWorld
Workspace:GetAttributeChangedSignal("IsHubWorld"):Connect(function()
	isHubWorld = Workspace:GetAttribute("IsHubWorld") == true
	if isHubWorld then
		hubInitialMeshPending = true
	end
end)
Workspace:GetAttributeChangedSignal("HubRenderDistance"):Connect(function()
	hubRenderDistance = Workspace:GetAttribute("HubRenderDistance")
end)

local function updateVoxelWorld()
	if not voxelWorldHandle then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- Update frustum from camera for culling
	frustum:UpdateFromCamera(camera)
	local pos = camera.CFrame.Position
	-- Convert studs to voxel block coordinates for chunk manager
    local bx = pos.X / Constants.BLOCK_SIZE
    local bz = pos.Z / Constants.BLOCK_SIZE

	-- Process any pending mesh updates from streamed chunks
	local cm = voxelWorldHandle and voxelWorldHandle.chunkManager
	local wm = voxelWorldHandle and voxelWorldHandle.GetWorldManager and voxelWorldHandle:GetWorldManager()
	if cm and cm.meshUpdateQueue then
		-- Ensure a container exists for voxel meshes
		if not voxelWorldContainer then
			voxelWorldContainer = Instance.new("Folder")
			voxelWorldContainer.Name = "VoxelWorld"
			voxelWorldContainer.Parent = workspace
		end

		-- Apply per-frame budgets (count and time), and prioritize by distance inside the camera frustum
		local updates = 0
		local vwConfig = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)
		local budget = (vwConfig.PERFORMANCE.MAX_MESH_UPDATES_PER_FRAME or 2)
		local timeBudgetSec = (vwConfig.PERFORMANCE.MESH_UPDATE_BUDGET_MS or 5) / 1000
		local hubFastMesh = isHubWorld and hubInitialMeshPending
		if hubFastMesh then
			budget = math.max(budget, 200)
			timeBudgetSec = math.max(timeBudgetSec, 0.3)
		end
		local frameStart = os.clock()

		-- Client-side visual radius gate (prevents meshing/keeping far-away chunks)
		local clientVisualRadius = math.min(
			(voxelWorldHandle and voxelWorldHandle.chunkManager and voxelWorldHandle.chunkManager.renderDistance) or 8,
			(vwConfig.PERFORMANCE.MAX_RENDER_DISTANCE or 8)
		)
		if isHubWorld and hubRenderDistance then
			clientVisualRadius = math.max(clientVisualRadius, hubRenderDistance)
		end

		-- Dynamic horizon fog to mask pop-in based on effective render distance
		local rd = (voxelWorldHandle and voxelWorldHandle.chunkManager and voxelWorldHandle.chunkManager.renderDistance) or clientVisualRadius
		local horizonStuds = rd * Constants.CHUNK_SIZE_X * Constants.BLOCK_SIZE
		local fogStart = math.max(0, horizonStuds * 0.6)
		local fogEnd = math.max(fogStart + 10, horizonStuds * 0.9)
		if not _lastFogEnd or math.abs((_lastFogEnd or 0) - fogEnd) > 4 then
			local atm = Lighting:FindFirstChildOfClass("Atmosphere")
			if not atm then
				atm = Instance.new("Atmosphere")
				atm.Parent = Lighting
			end
			-- Gentle haze to soften horizon; tuned for voxel scale
			atm.Density = 0.35
			atm.Haze = 1
			-- Classic fog for firm cutoff
			Lighting.FogColor = Color3.fromRGB(200, 220, 255)
			Lighting.FogStart = fogStart
			Lighting.FogEnd = fogEnd
			_lastFogEnd = fogEnd
		end
        -- Build prioritized candidate list (frustum culled, but always include 7x7 around player)
		local candidates = {}
        -- Compute player chunk once for must-include set
        local pcx = math.floor(bx / Constants.CHUNK_SIZE_X)
        local pcz = math.floor(bz / Constants.CHUNK_SIZE_Z)
		local vwDebug = vwConfig.DEBUG
		local bs = Constants.BLOCK_SIZE
		local sizeX = Constants.CHUNK_SIZE_X * bs
		local sizeZ = Constants.CHUNK_SIZE_Z * bs
		local pad = bs * 0.25
		local maxParts = (vwDebug and vwDebug.MAX_PARTS_PER_CHUNK) or 600

		for key, chunk in pairs(cm.meshUpdateQueue) do
			local chunkWorldX = (chunk.x * Constants.CHUNK_SIZE_X) * bs
			local chunkWorldZ = (chunk.z * Constants.CHUNK_SIZE_Z) * bs
            local min = Vector3.new(chunkWorldX, 0, chunkWorldZ)
            local max = Vector3.new(chunkWorldX + sizeX, Constants.WORLD_HEIGHT * bs, chunkWorldZ + sizeZ)
            -- Conservative expansion to avoid precision pop-in at edges
            local minExp = min - Vector3.new(pad, pad * 2, pad)
            local maxExp = max + Vector3.new(pad, pad * 2, pad)
			local mustInclude = (math.abs(chunk.x - pcx) <= 3 and math.abs(chunk.z - pcz) <= 3)
			local dxChunks = chunk.x - pcx
			local dzChunks = chunk.z - pcz
			local withinVisualRadius = (dxChunks * dxChunks + dzChunks * dzChunks) <= (clientVisualRadius * clientVisualRadius)
			if isHubWorld then
				withinVisualRadius = true
			end
			if withinVisualRadius and (mustInclude or vwDebug.DISABLE_FRUSTUM_CULLING or frustum:IsAABBVisible(minExp, maxExp)) then
				local center = Vector3.new(chunkWorldX + sizeX * 0.5, pos.Y, chunkWorldZ + sizeZ * 0.5)
				local dist = (center - pos).Magnitude
				table.insert(candidates, { key = key, chunk = chunk, dist = dist })
			end
		end
		table.sort(candidates, function(a, b)
			return a.dist < b.dist
		end)

        -- For small queues (block edits), process all chunks together to avoid border flicker
        -- For large queues (world loading), respect the budget
        local queueSize = #candidates
        local effectiveBudget = budget
        if queueSize <= 5 then
            -- Small batch (likely from a single block change) - process all together
            effectiveBudget = math.max(budget, queueSize)
        end

		-- Neighbor sampler function for cross-chunk block lookups (shared across all chunks this frame)
		local function neighborSampler(worldManagerRef, baseChunk, lx, ly, lz)
			-- Fast path: block is within the base chunk
			if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
				return baseChunk:GetBlock(lx, ly, lz)
			end
			-- Need to look up neighbor chunk
			if not worldManagerRef then return Constants.BlockType.AIR end
			local cx, cz = baseChunk.x, baseChunk.z
			local nx, nz = lx, lz
			if nx < 0 then cx -= 1; nx += Constants.CHUNK_SIZE_X
			elseif nx >= Constants.CHUNK_SIZE_X then cx += 1; nx -= Constants.CHUNK_SIZE_X end
			if nz < 0 then cz -= 1; nz += Constants.CHUNK_SIZE_Z
			elseif nz >= Constants.CHUNK_SIZE_Z then cz += 1; nz -= Constants.CHUNK_SIZE_Z end
			local neighborKey = tostring(cx) .. "," .. tostring(cz)
			local neighbor = worldManagerRef.chunks and worldManagerRef.chunks[neighborKey]
			if not neighbor then return Constants.BlockType.AIR end
			return neighbor:GetBlock(nx, ly, nz)
		end

		-- Phase 1: Build all meshes (without parenting yet)
		local builtMeshes = {}
        for i, item in ipairs(candidates) do
			if updates >= effectiveBudget then break end
			-- Only check time budget for large queues
			if queueSize > 5 and (os.clock() - frameStart) >= timeBudgetSec then break end

            local key = item.key
            local chunk = item.chunk

            -- Generate merged box mesh with textures
			local parts = boxMesher:GenerateMesh(chunk, wm, {
                maxParts = maxParts,
                sampleBlock = neighborSampler,
            })

            -- Assemble new model (not parented yet)
            local nextModel = Instance.new("Model")
            nextModel.Name = "Chunk_" .. tostring(key)
            for _, part in ipairs(parts) do
                part.Parent = nextModel
            end

            -- Set a fixed pivot at chunk origin
            local origin = Vector3.new((chunk.x * Constants.CHUNK_SIZE_X) * bs, 0, (chunk.z * Constants.CHUNK_SIZE_Z) * bs)
            pcall(function()
                nextModel.WorldPivot = CFrame.new(origin)
            end)

            table.insert(builtMeshes, {key = key, model = nextModel})
			updates += 1
		end

		-- Phase 2: Swap all built meshes atomically (minimizes visual gaps)
		for _, built in ipairs(builtMeshes) do
			local key = built.key
			local nextModel = built.model

            -- Parent new model
            nextModel.Parent = voxelWorldContainer

            -- Remove old model
            local prev = chunkFolders[key]
            if prev then
                PartPool.ReleaseAllFromModel(prev)
                prev:Destroy()
            end

            chunkFolders[key] = nextModel
			cm.meshUpdateQueue[key] = nil
		end

		-- Check if hub initial mesh build is complete
		if hubFastMesh then
			if not next(cm.meshUpdateQueue) then
				hubInitialMeshPending = false
				print("[VoxelWorld] Hub voxel mesh build complete")
			end
		end
	end
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
	local handled = false
	if LoadingScreen and LoadingScreen.IsActive and LoadingScreen:IsActive() and LoadingScreen.ReleaseWorldHold then
		LoadingScreen:ReleaseWorldHold()
		handled = true
	end

	if not handled and Client.managers.UIManager and Client.managers.UIManager.HideWorldStatus then
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
		showWorldStatus("Unable to load world", "Please return to the hub and try again.")
		if Client.managers.ToastManager then
			Client.managers.ToastManager:Error("World failed to load. Please rejoin from the hub.", 6)
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
	print(string.format("🌍 WorldStateChanged received (%s, ready=%s)", status, tostring(worldState.isReady)))

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
			print("ToastManager: Initialized after loading")
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

	print("🎮 Voxel Hotbar, Inventory Manager, and Inventory Panel initialized")

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
		print("📚 TutorialManager: Initialized for onboarding")
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
	print("📦 Inventory change listeners registered")

	-- Initialize World Ownership Display
	local WorldOwnershipDisplay = require(script.Parent.UI.WorldOwnershipDisplay)
	WorldOwnershipDisplay:Initialize()
	Client.worldOwnershipDisplay = WorldOwnershipDisplay
	print("🏠 World Ownership Display initialized")

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
	print("💥 Block Break Progress UI initialized")

	-- Initialize Status Bars HUD (Minecraft-style health/armor/hunger)
	local statusBarsSuccess, statusBarsError = pcall(function()
		local StatusBarsHUD = require(script.Parent.UI.StatusBarsHUD)
		local statusBars = StatusBarsHUD.new()
		statusBars:Initialize()
		Client.statusBarsHUD = statusBars
	end)
	if statusBarsSuccess then
		print("❤️ Status Bars HUD (health/armor/hunger) initialized")
	else
		warn("⚠️ Status Bars HUD failed to initialize:", statusBarsError)
	end

	-- Initialize Block Break Overlay (crack stages)
	BlockBreakOverlayController:Initialize()
	Client.blockBreakOverlayController = BlockBreakOverlayController
	print("🧱 Block Break Overlay controller initialized")

	-- Initialize Dropped Item Controller (rendering dropped items)
	local DroppedItemController = require(script.Parent.Controllers.DroppedItemController)
	DroppedItemController:Initialize(voxelWorldHandle)
	Client.droppedItemController = DroppedItemController
	print("💎 Dropped Item Controller initialized")

	-- Initialize Mob Replication Controller (renders passive/hostile mobs)
	local MobReplicationController = require(script.Parent.Controllers.MobReplicationController)
	Client.mobReplicationController = MobReplicationController
	print("👾 Mob Replication Controller initialized")

	-- Note: MinionUI is initialized after ChestUI due to dependency

	-- Initialize Tool Visual Controller (attach placeholder handle for equipped tools)
	local ToolVisualController = require(script.Parent.Controllers.ToolVisualController)
	ToolVisualController:Initialize()
	Client.toolVisualController = ToolVisualController
	print("🛠️ Tool Visual Controller initialized")

	-- Initialize Tool Animation Controller (play R15 swing when sword equipped)
	local ToolAnimationController = require(script.Parent.Controllers.ToolAnimationController)
	ToolAnimationController:Initialize()
	Client.toolAnimationController = ToolAnimationController
	Client.managers.ToolAnimationController = ToolAnimationController
	print("🎬 Tool Animation Controller initialized")

	-- Initialize Viewmodel Controller (first-person hand/held item)
	local ViewmodelController = require(script.Parent.Controllers.ViewmodelController)
	ViewmodelController:Initialize()
	Client.viewmodelController = ViewmodelController
	Client.managers.ViewmodelController = ViewmodelController
	print("🖐️ Viewmodel Controller initialized")

	-- Initialize Combat Controller (PvP)
	local CombatController = require(script.Parent.Controllers.CombatController)
	CombatController:Initialize()
	Client.combatController = CombatController
	print("⚔️ Combat Controller initialized")

	-- Initialize Bow Controller (ranged hold-to-draw)
	local BowController = require(script.Parent.Controllers.BowController)
	BowController:Initialize(inventoryManager)
	Client.bowController = BowController
	print("🏹 Bow Controller initialized")

	-- Initialize Armor Visual Controller (render armor on character)
	local ArmorVisualController = require(script.Parent.Controllers.ArmorVisualController)
	ArmorVisualController.Init()
	Client.armorVisualController = ArmorVisualController
	print("🛡️ Armor Visual Controller initialized")

	-- Initialize Camera Controller (3rd person camera locked 2 studs above head)
	local CameraController = require(script.Parent.Controllers.CameraController)
	CameraController:Initialize()
	Client.cameraController = CameraController

	-- Initialize Sprint Controller (hold Left Shift to sprint)
	local SprintController = require(script.Parent.Controllers.SprintController)
	SprintController:Initialize()
	Client.sprintController = SprintController

	-- Initialize Cloud Controller (Minecraft-style layered clouds)
	CloudController:Initialize()
	Client.cloudController = CloudController
	print("☁️ Cloud Controller initialized")

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

	print("📦 Chest UI initialized")

	-- Initialize Minion UI (after ChestUI due to dependency)
	local MinionUI = require(script.Parent.UI.MinionUI)
	local minionUI = MinionUI.new(inventoryManager, inventory, chestUI)
	minionUI:Initialize()
	Client.minionUI = minionUI
	print("🧱 Minion UI initialized")

	-- Centralize inventory/chest key handling to avoid duplicate listeners
	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.E then
			if not canProcessUiToggle() then
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
			if minionUI and minionUI.isOpen then
				minionUI:Close()
			elseif chestUI and chestUI.isOpen then
				chestUI:Close()
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
			if minionUI and minionUI.isOpen then
				minionUI:Close()
			end
			if chestUI and chestUI.isOpen then
				local targetMode = worldsPanel and "worlds" or nil
				chestUI:Close(targetMode)
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
			else
				warn("Worlds panel is not available in this place.")
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if minionUI and minionUI.isOpen then
				minionUI:Close()
			elseif chestUI and chestUI.isOpen then
				chestUI:Close()
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
	print("🔌 Complete event handlers registered (with ToastManager and ToolAnimationController)")

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

	-- Create main HUD (after panels are registered)
	local MainHUD = require(script.Parent.UI.MainHUD)
	if MainHUD.Create then
		MainHUD:Create()
	end

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
	print("🔄 Sending ClientReady event to server...")
	EventManager:SendToServer("ClientReady")
	print("🔄 Sending RequestDataRefresh event to server...")
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
		print("Client already initialized")
		return
	end

	print("🚀 Starting client initialization with loading screen...")

	-- Initialize core systems first
	Logger:Initialize(Config.LOGGING, Network)
	EventManager:Initialize(Network)

	-- Register all events first (defines RemoteEvents with proper parameter signatures)
	EventManager:RegisterAllEvents()

	-- Initialize unified input orchestration before gameplay controllers bind
	InputService:Initialize()

	-- Initialize voxel world in SERVER-AUTHORITATIVE mode
	print("🌍 Initializing voxel world (server-authoritative mode)...")
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
        if not voxelWorldHandle or not voxelWorldHandle.GetWorldManager then return end
        local wm = voxelWorldHandle:GetWorldManager()
        if not wm then return end
        local chunk = wm:GetChunk(data.chunk.x, data.chunk.z)
        if not chunk then return end
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
        local key = data.key or (tostring(data.chunk.x) .. "," .. tostring(data.chunk.z))
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
                local neighborKey = tostring(nx) .. "," .. tostring(nz)
                -- Only remesh if neighbor already has a rendered mesh
                if chunkFolders[neighborKey] then
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

	EventManager:RegisterEvent(WORLD_READY_EVENT, handleWorldStateChanged)

	-- Batched chunk remeshing system
	-- Collects all affected chunks and processes them together to avoid border flicker
	local pendingRemeshChunks = {} -- Set of "cx,cz" keys
	local remeshBatchTimer = nil
	local REMESH_BATCH_DELAY = 0.05 -- 50ms - short delay to batch rapid edits

	-- Queue a chunk for batched remesh
	local function queueChunkRemesh(cx, cz)
		local k = tostring(cx) .. "," .. tostring(cz)
		pendingRemeshChunks[k] = {cx = cx, cz = cz}
	end

	-- Flush all pending chunk remeshes at once
	local function flushPendingRemeshes()
		remeshBatchTimer = nil
		if not voxelWorldHandle then return end
		local wm = voxelWorldHandle:GetWorldManager()
		if not wm then return end
		local cm = voxelWorldHandle.chunkManager
		if not cm then return end

		-- Queue all pending chunks for mesh update
		for k, coords in pairs(pendingRemeshChunks) do
			local ch = wm:GetChunk(coords.cx, coords.cz)
			if ch then
				cm.meshUpdateQueue[k] = ch
			end
		end

		-- Clear the pending set
		pendingRemeshChunks = {}
	end

	-- Schedule a batched remesh (resets timer on each call to batch rapid edits)
	local function scheduleBatchedRemesh()
		if remeshBatchTimer then
			task.cancel(remeshBatchTimer)
		end
		remeshBatchTimer = task.delay(REMESH_BATCH_DELAY, flushPendingRemeshes)
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

		-- Play block placement sound (only if placing a block, not breaking)
		if data.blockId and data.blockId ~= 0 then
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

		-- Check if block is on a chunk edge and queue neighbor chunks
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

		-- Schedule batched flush (all chunks will be queued together)
		scheduleBatchedRemesh()

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
    print("🎯 Waiting for PlayerEntitySpawned event from server...")
    EventManager:RegisterEvent("PlayerEntitySpawned", function(data)
        print("🎉 Received PlayerEntitySpawned event!", data)
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
        print("📍 Character spawned at:", pos)

        -- Set replication focus to character
        pcall(function()
            localPlayer.ReplicationFocus = rootPart
        end)

        -- Send initial position to server
        EventManager:SendToServer("VoxelPlayerPositionUpdate", { x = pos.X, z = pos.Z })
        EventManager:SendToServer("VoxelRequestInitialChunks")
        print("📦 Requested initial chunks for voxel world (entity spawn)")
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

	print("✅ Voxel world client view initialized successfully!")

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
	print("🔌 Early event handlers registered (without ToastManager)")

	-- Start the asynchronous loading and initialization process
	task.spawn(function()
		-- Create and show loading screen
		local LoadingScreen = require(script.Parent.UI.LoadingScreen)
		LoadingScreen:Create()

				-- Initialize IconManager and UIComponents
		IconManager:Initialize()
		UIComponents:Initialize()
		print("📦 IconManager: Registering MainHUD icons...")

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

		print("📦 IconManager: Registered 21 icons for preloading (10 MainHUD + 11 ToastManager)")

		-- Initialize EmoteManager for later use (not for preloading)
		local success, EmoteManager = pcall(require, script.Parent.Managers.EmoteManager)
		if not success then
			warn("Failed to load EmoteManager:", EmoteManager)
			EmoteManager = nil
		end

		print("🔄 Starting LoadAllAssets (block textures & icons)...")

		-- Load block textures and Vector Icons
		LoadingScreen:LoadAllAssets(
			function(loaded, total, progress)
				-- Progress callback
				-- Loading progress update
			end,
			function(loadedCount, failedCount)
				-- Completion callback (called after fade-out)
				print("Asset loading complete:", loadedCount, "loaded,", failedCount, "failed")
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
	else
		print("✅ Client initialized successfully!")
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