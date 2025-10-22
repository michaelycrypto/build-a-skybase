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
print("[VoxelTextures] Texture system loaded. Enabled:", TextureManager:IsEnabled())
local voxelWorldHandle = nil
local boxMesher = BoxMesher.new()
local voxelWorldContainer = nil
local voxelCollidersContainer = nil
local chunkFolders = {}
local colliderFolders = {}
local frustum = CameraFrustum.new()
local _lastFogEnd

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

	-- Removed legacy chunkReceiver/chunkCache path

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
		local frameStart = os.clock()

		-- Client-side visual radius gate (prevents meshing/keeping far-away chunks)
		local clientVisualRadius = math.min(
			(voxelWorldHandle and voxelWorldHandle.chunkManager and voxelWorldHandle.chunkManager.renderDistance) or 8,
			(vwConfig.PERFORMANCE.MAX_RENDER_DISTANCE or 8)
		)

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
		-- Player chunk for culling gate (computed once)
		local pcxGate = math.floor(bx / Constants.CHUNK_SIZE_X)
		local pczGate = math.floor(bz / Constants.CHUNK_SIZE_Z)
		-- Do not locally destroy models based on radius; rely on server ChunkUnload

		-- Ensure near-player chunks are remeshed with colliders when entering radius
		local cam = workspace.CurrentCamera
		if wm and cam then
			local ppos = cam.CFrame.Position
			local pbx = ppos.X / Constants.BLOCK_SIZE
			local pbz = ppos.Z / Constants.BLOCK_SIZE
			local pcx2 = math.floor(pbx / Constants.CHUNK_SIZE_X)
			local pcz2 = math.floor(pbz / Constants.CHUNK_SIZE_Z)
			for key, model in pairs(chunkFolders) do
				local cx, cz = wm:GetChunkCoords(key)
				local dx = math.abs(cx - pcx2)
				local dz = math.abs(cz - pcz2)
				local shouldHave = (dx <= 3 and dz <= 3)
				local has = (model:GetAttribute("HasColliders") == true)
				if shouldHave and not has then
					local chunk = wm.chunks and wm.chunks[key]
					if chunk then
						cm.meshUpdateQueue[key] = chunk
					end
				end
			end
		end

        -- Build prioritized candidate list (frustum culled, but always include 7x7 around player)
		local candidates = {}
        -- Compute player chunk once for must-include set
        local pcx = math.floor(bx / Constants.CHUNK_SIZE_X)
        local pcz = math.floor(bz / Constants.CHUNK_SIZE_Z)
		for key, chunk in pairs(cm.meshUpdateQueue) do
			local bs = Constants.BLOCK_SIZE
			local chunkWorldX = (chunk.x * Constants.CHUNK_SIZE_X) * bs
			local chunkWorldZ = (chunk.z * Constants.CHUNK_SIZE_Z) * bs
			local sizeX = Constants.CHUNK_SIZE_X * bs
			local sizeZ = Constants.CHUNK_SIZE_Z * bs
            local min = Vector3.new(chunkWorldX, 0, chunkWorldZ)
            local max = Vector3.new(chunkWorldX + sizeX, Constants.WORLD_HEIGHT * bs, chunkWorldZ + sizeZ)
            -- Conservative expansion to avoid precision pop-in at edges
            local pad = bs * 0.25
            local minExp = min - Vector3.new(pad, pad * 2, pad)
            local maxExp = max + Vector3.new(pad, pad * 2, pad)
			local vwDebug = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config).DEBUG
			local mustInclude = (math.abs(chunk.x - pcx) <= 3 and math.abs(chunk.z - pcz) <= 3)
			local dxChunks = chunk.x - pcx
			local dzChunks = chunk.z - pcz
			local withinVisualRadius = (dxChunks * dxChunks + dzChunks * dzChunks) <= (clientVisualRadius * clientVisualRadius)
			if withinVisualRadius and (mustInclude or vwDebug.DISABLE_FRUSTUM_CULLING or frustum:IsAABBVisible(minExp, maxExp)) then
				local center = Vector3.new(chunkWorldX + sizeX * 0.5, pos.Y, chunkWorldZ + sizeZ * 0.5)
				local dist = (center - pos).Magnitude
				table.insert(candidates, { key = key, chunk = chunk, dist = dist })
			end
		end
		table.sort(candidates, function(a, b)
			return a.dist < b.dist
		end)

        -- Background meshing budget (limit concurrent builds per frame)
        local concurrent = 0
        local maxConcurrent = math.max(1, math.floor(budget))

        for _, item in ipairs(candidates) do
			if updates >= budget then break end
			if (os.clock() - frameStart) >= timeBudgetSec then break end
            local key = item.key
            local chunk = item.chunk
            local bs = Constants.BLOCK_SIZE
            -- Build new mesh parts via greedy meshing with world-aware culling and colliders

			-- Determine if this chunk is the one the player is currently inside (only)
			local drawBorders = false
			if wm then
				local camera = workspace.CurrentCamera
				if camera then
					local pos = camera.CFrame.Position
					local bx = pos.X / Constants.BLOCK_SIZE
					local bz = pos.Z / Constants.BLOCK_SIZE
					local pcx = math.floor(bx / Constants.CHUNK_SIZE_X)
					local pcz = math.floor(bz / Constants.CHUNK_SIZE_Z)
					drawBorders = (chunk.x == pcx and chunk.z == pcz)
				end
			end
            local vwDebug2 = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config).DEBUG
			local maxParts = (vwDebug2 and vwDebug2.MAX_PARTS_PER_CHUNK) or 600
            -- Ensure colliders are generated for chunks around the camera/player position
            local needColliders = false
            do
                local camera = workspace.CurrentCamera
                if camera then
                    local pos = camera.CFrame.Position
                    local bx = pos.X / Constants.BLOCK_SIZE
                    local bz = pos.Z / Constants.BLOCK_SIZE
                    local pcx = math.floor(bx / Constants.CHUNK_SIZE_X)
                    local pcz = math.floor(bz / Constants.CHUNK_SIZE_Z)
                    local dx = math.abs(chunk.x - pcx)
                    local dz = math.abs(chunk.z - pcz)
                    -- 7x7 area centered around camera chunk gets colliders
                    needColliders = (dx <= 3 and dz <= 3)
                end
            end
            -- Build a voxel.js-like sampler: given (x,y,z) in local or neighbor space, fetch neighbor ids without creating chunks
			local neighborSampler = function(worldManagerRef, baseChunk, lx, ly, lz)
                -- Inline neighbor sampling based on local offsets relative to base chunk
                if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
                    return baseChunk:GetBlock(lx, ly, lz)
                end
				if not worldManagerRef then return Constants.BlockType.STONE end -- Treat unknown neighbor as occluder; avoid seam faces until neighbor loads
                local cx, cz = baseChunk.x, baseChunk.z
                local nx, nz = lx, lz
                if nx < 0 then cx -= 1 nx += Constants.CHUNK_SIZE_X elseif nx >= Constants.CHUNK_SIZE_X then cx += 1 nx -= Constants.CHUNK_SIZE_X end
                if nz < 0 then cz -= 1 nz += Constants.CHUNK_SIZE_Z elseif nz >= Constants.CHUNK_SIZE_Z then cz += 1 nz -= Constants.CHUNK_SIZE_Z end
                local key
                key = tostring(cx)..","..tostring(cz)
                local neighbor = (worldManagerRef and worldManagerRef.chunks) and worldManagerRef.chunks[key]
				if not neighbor then return Constants.BlockType.STONE end -- Defer border faces until real neighbor is present
                return neighbor:GetBlock(nx, ly, nz)
            end

            -- Generate merged box mesh with textures
			local parts = boxMesher:GenerateMesh(chunk, wm, {
                maxParts = maxParts,
                sampleBlock = neighborSampler,
            })

            -- Count textures applied (for verification)
            local textureCount = 0
            for _, part in ipairs(parts) do
                if part:IsA("BasePart") then
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("Texture") then
                            textureCount = textureCount + 1
                        end
                    end
                end
            end

            -- Log texture application (first few chunks only to avoid spam)
            if textureCount > 0 and updates < 3 then
                print(string.format("[VoxelTextures] Chunk %s: %d parts, %d textures applied",
                    key, #parts, textureCount))
            end

            -- Assemble new model offscreen, then swap to avoid flicker
            local nextModel = Instance.new("Model")
            nextModel.Name = "Chunk_" .. tostring(key)
            for _, part in ipairs(parts) do
                part.Parent = nextModel
            end
            -- Set a fixed pivot at chunk origin for clarity and fast transforms
            local origin = Vector3.new((chunk.x * Constants.CHUNK_SIZE_X) * bs, 0, (chunk.z * Constants.CHUNK_SIZE_Z) * bs)
            pcall(function()
                nextModel.WorldPivot = CFrame.new(origin)
            end)
            -- Track collider presence for future proximity remeshing
            pcall(function()
                nextModel:SetAttribute("HasColliders", needColliders and true or false)
            end)
            -- Swap models atomically: parent new, then remove old
            nextModel.Parent = voxelWorldContainer
            local prev = chunkFolders[key]
            if prev then
                PartPool.ReleaseAllFromModel(prev)
                prev:Destroy()
            end
            chunkFolders[key] = nextModel

			-- Mark processed
			cm.meshUpdateQueue[key] = nil
			updates += 1
            concurrent += 1
            if concurrent >= maxConcurrent then break end
		end

		-- Simplified: remove physics-only collider sweep. Colliders are generated with the visual mesh when needed.
	end
end

-- Connect voxel world update to RenderStepped
-- This will start working once voxelWorldHandle is created in initialize()
RunService.RenderStepped:Connect(updateVoxelWorld)

-- Load shared modules
local Config = require(ReplicatedStorage.Shared.Config)
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
    -- Removed grid/tool managers

	-- Import proximity grid system
    -- Removed proximity grid bootstrap

	-- Import UI components
	local LoadingScreen = require(script.Parent.UI.LoadingScreen)
	local MainHUD = require(script.Parent.UI.MainHUD)
	local DailyRewardsPanel = require(script.Parent.UI.DailyRewardsPanel)
	local SettingsPanel = require(script.Parent.UI.SettingsPanel)

-- Global client state
local Client = {
	isInitialized = false,
	managers = {}
}

--[[
	Complete initialization after loading screen
--]]
local function completeInitialization(EmoteManager)
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

	-- Initialize PanelManager
	local PanelManager = require(script.Parent.Managers.PanelManager)
	if PanelManager.Initialize then
		PanelManager:Initialize()
	end
	Client.managers.PanelManager = PanelManager

    -- Removed PlayerBase/PlayerBillboard/Toolbar/ProximityGrid initialization

    -- Removed GridIntegrationManager and GridBoundsManager

	-- ClientInventoryManager removed - inventory data now handled directly by InventoryPanel

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

	print("🎮 Voxel Hotbar, Inventory Manager, and Inventory Panel initialized")

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

	-- Initialize Dropped Item Controller (rendering dropped items)
	local DroppedItemController = require(script.Parent.Controllers.DroppedItemController)
	DroppedItemController:Initialize()
	Client.droppedItemController = DroppedItemController
	print("💎 Dropped Item Controller initialized")

	-- Initialize Camera Controller (3rd person camera locked 2 studs above head)
	local CameraController = require(script.Parent.Controllers.CameraController)
	CameraController:Initialize()
	Client.cameraController = CameraController

	-- Initialize Sprint Controller (hold Left Shift to sprint)
	local SprintController = require(script.Parent.Controllers.SprintController)
	SprintController:Initialize()
	Client.sprintController = SprintController

	-- Initialize Chest UI (pass inventory manager for integration)
	local ChestUI = require(script.Parent.UI.ChestUI)
	local chestUI = ChestUI.new(inventoryManager, inventory)
	chestUI:Initialize()
	Client.chestUI = chestUI

	-- Link inventory panel to chest UI for mutual exclusion
	inventory.chestUI = chestUI

	print("📦 Chest UI initialized")

	-- Re-register event handlers with complete managers (including ToastManager)
	local completeEventConfig = EventManager:CreateClientEventConfig(Client.managers)
	EventManager:RegisterEvents(completeEventConfig)
	print("🔌 Complete event handlers registered (with ToastManager)")

	-- Create main HUD
	local MainHUD = require(script.Parent.UI.MainHUD)
	if MainHUD.Create then
		MainHUD:Create()
	end

	-- Initialize UI panels
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

    -- World grid auto-send removed

		Client.isInitialized = true
	print("✅ Client initialization complete!")

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

	-- Initialize voxel world in SERVER-AUTHORITATIVE mode
	print("🌍 Initializing voxel world (server-authoritative mode)...")
    voxelWorldHandle = VoxelWorld.CreateClientView(3)

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
        -- Only queue if we don't already have a mesh
        if not chunkFolders[key] then
            voxelWorldHandle.chunkManager.meshUpdateQueue[key] = chunk
        end
    end)

	EventManager:RegisterEvent("ChunkUnload", function(data)
		-- Remove rendered mesh for this chunk if present
		local folder = chunkFolders[data.key]
		if folder then
			folder:Destroy()
			chunkFolders[data.key] = nil
		end
		voxelWorldHandle.chunkManager:UnloadChunk(data.key)

		-- Drop any pending mesh updates for this chunk
		if voxelWorldHandle and voxelWorldHandle.chunkManager and voxelWorldHandle.chunkManager.meshUpdateQueue then
			voxelWorldHandle.chunkManager.meshUpdateQueue[data.key] = nil
		end

        -- Do not trigger neighbor remesh here; neighbor faces are culled by occlusion policy
	end)

-- Debounce timers for chunk remeshing (avoid flash during rapid edits)
local pendingRemeshTimers = {}
local REMESH_DEBOUNCE_TIME = 0.15 -- Wait 150ms after last edit before remeshing

	EventManager:RegisterEvent("BlockChanged", function(data)
		voxelWorldHandle:GetWorldManager():SetBlock(data.x, data.y, data.z, data.blockId)

		-- Set metadata if provided
		if data.metadata and data.metadata ~= 0 then
			voxelWorldHandle:GetWorldManager():SetBlockMetadata(data.x, data.y, data.z, data.metadata)
		end

		-- Play block placement sound (only if placing a block, not breaking)
		if data.blockId and data.blockId ~= 0 then
			local SoundManager = Client.managers and Client.managers.SoundManager
			if SoundManager and SoundManager.PlaySFXSafely then
				SoundManager:PlaySFXSafely("blockPlace")
			end
		end


		-- Helper to schedule a remesh for a specific chunk key with debounce
		local function scheduleRemesh(cx, cz)
			local k = tostring(cx) .. "," .. tostring(cz)
			if pendingRemeshTimers[k] then
				task.cancel(pendingRemeshTimers[k])
			end
			pendingRemeshTimers[k] = task.delay(REMESH_DEBOUNCE_TIME, function()
				local ch = voxelWorldHandle:GetWorldManager():GetChunk(cx, cz)
				if ch then
					voxelWorldHandle.chunkManager.meshUpdateQueue[k] = ch
				end
				pendingRemeshTimers[k] = nil
			end)
		end

		-- Update mesh for affected chunk
		local chunkX = math.floor(data.x / Constants.CHUNK_SIZE_X)
		local chunkZ = math.floor(data.z / Constants.CHUNK_SIZE_Z)
		scheduleRemesh(chunkX, chunkZ)

		-- If the changed block is on a chunk edge, also schedule neighbor chunk remesh
		local localX = data.x - chunkX * Constants.CHUNK_SIZE_X
		local localZ = data.z - chunkZ * Constants.CHUNK_SIZE_Z
		if localX == 0 then
			scheduleRemesh(chunkX - 1, chunkZ)
		elseif localX == (Constants.CHUNK_SIZE_X - 1) then
			scheduleRemesh(chunkX + 1, chunkZ)
		end
		if localZ == 0 then
			scheduleRemesh(chunkX, chunkZ - 1)
		elseif localZ == (Constants.CHUNK_SIZE_Z - 1) then
			scheduleRemesh(chunkX, chunkZ + 1)
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
	end)

	-- Handle inventory synchronization from server
	-- NOTE: InventorySync and HotbarSlotUpdate are now handled by ClientInventoryManager
	-- We only need to refresh UI displays when inventory changes
	if Client.inventoryManager then
		Client.inventoryManager:OnInventoryChanged(function(slotIndex)
			if Client.voxelInventory and Client.voxelInventory.isOpen then
				Client.voxelInventory:UpdateInventorySlotDisplay(slotIndex)
			end
			if Client.chestUI and Client.chestUI.isOpen then
				Client.chestUI:UpdateInventorySlotDisplay(slotIndex)
			end
		end)

		Client.inventoryManager:OnHotbarChanged(function(slotIndex)
			if Client.voxelInventory and Client.voxelInventory.isOpen then
				-- Update hotbar display in inventory panel
				Client.voxelInventory:UpdateAllDisplays()
			end
		end)

		print("📦 Inventory change listeners registered")
	end

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
				-- Completion callback
				print("Asset loading complete:", loadedCount, "loaded,", failedCount, "failed")
				print("Calling completeInitialization...")

				-- Continue with rest of initialization
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
		titleLabel.Font = Enum.Font.GothamBold
		titleLabel.Parent = errorFrame

		local errorLabel = Instance.new("TextLabel")
		errorLabel.Size = UDim2.new(1, -20, 1, -60)
		errorLabel.Position = UDim2.new(0, 10, 0, 50)
		errorLabel.BackgroundTransparency = 1
		errorLabel.Text = "Please rejoin the game.\n\nError: " .. tostring(error)
		errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		errorLabel.TextScaled = true
		errorLabel.Font = Enum.Font.Gotham
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