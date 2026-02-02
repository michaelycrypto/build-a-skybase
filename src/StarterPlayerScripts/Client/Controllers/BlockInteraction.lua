--[[
	BlockInteraction.lua
	Module for block placement and breaking using R15 character and mouse input
]]

local InputService = require(script.Parent.Parent.Input.InputService)
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local VoxelConfig = require(ReplicatedStorage.Shared.VoxelWorld.Core.Config)
local GameState = require(script.Parent.Parent.Managers.GameState)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local _GameConfig = require(ReplicatedStorage.Configs.GameConfig)  -- Preload for cache
local BlockBreakFeedbackConfig = require(ReplicatedStorage.Configs.BlockBreakFeedbackConfig)
local BlockAPI = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockAPI)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local ToolAnimationController = require(script.Parent.ToolAnimationController)
local BlockBreakProgress = require(script.Parent.Parent.UI.BlockBreakProgress)

local BlockInteraction = {}
BlockInteraction.isReady = false


-- Private state
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera
local blockAPI = nil
local isBreaking = false
local breakingBlock = nil
local lastBreakTime = 0
local lastPlaceTime = 0
local isPlacing = false
local selectionBox = nil -- Visual indicator for targeted block
local lastMinionOpenRequestAt = 0
local MINION_OPEN_DEBOUNCE = 0.25

-- Right-click detection for third person (distinguish click from camera pan)
local rightClickStartTime = 0
local rightClickStartPos = Vector2.new(0, 0)
local isRightClickHeld = false
local CLICK_TIME_THRESHOLD = 0.3 -- Max time for a "click" vs "hold" (seconds)
local CLICK_MOVEMENT_THRESHOLD = 5 -- Max mouse movement in pixels for a "click"

-- Mobile touch detection (distinguish tap, hold, drag)
local activeTouches = {} -- Track multiple touches
local _TAP_TIME_THRESHOLD = 0.2 -- Max time for a "tap" (seconds) (reserved for future use)
local HOLD_TIME_THRESHOLD = 0.3 -- Min time before "hold" action triggers (seconds)
local DRAG_MOVEMENT_THRESHOLD = 10 -- Min movement in pixels to be considered a "drag"

-- Input position for direct targeting mode (click/tap position)
local lastInputPosition = nil -- Stores mouse click or tap position for direct targeting

-- Constants
local BREAK_INTERVAL = 0.1 -- How often to send punch events (server allows >=0.1s)
local PLACE_COOLDOWN = 0.15 -- Placement cooldown (~7 per second)
local HIT_SOUND_COOLDOWN = 0.2 -- Match Minecraft cadence (~5 hits per second)

-- Bridge mode state - once we start bridge building, stay in bridge mode until mouse released
local bridgeModeActive = false
local bridgeLockedY = nil        -- Locked Y-level for bridge building
local bridgeLockedDX = nil       -- Locked X direction (-1, 0, or 1)
local bridgeLockedDZ = nil       -- Locked Z direction (-1, 0, or 1)
local _bridgeLastBlockX = nil     -- Last block X player was on (reserved for future use)
local _bridgeLastBlockZ = nil     -- Last block Z player was on (reserved for future use)

local function _blockKey(vec3)
	if not vec3 then
		return nil
	end
	return string.format("%d,%d,%d", vec3.X, vec3.Y, vec3.Z)
end

local function _blockWorldCenter(blockPos)
	local bs = Constants.BLOCK_SIZE
	return Vector3.new(
		blockPos.X * bs + bs * 0.5,
		blockPos.Y * bs + bs * 0.5,
		blockPos.Z * bs + bs * 0.5
	)
end

local function _isMinionBlock(blockId)
	return blockId == Constants.BlockType.COBBLESTONE_MINION
		or blockId == Constants.BlockType.COAL_MINION
end

local lastCancelKey = nil
local lastCancelAt = 0
local hitSoundTimestamps = {}

local function isBowEquipped()
	local holding = GameState:Get("voxelWorld.isHoldingTool") == true
	if not holding then
		return false
	end
	local itemId = GameState:Get("voxelWorld.selectedToolItemId")
	if not itemId or not ToolConfig.IsTool(itemId) then
		return false
	end
	local toolType = select(1, ToolConfig.GetBlockProps(itemId))
	return toolType == BlockProperties.ToolType.BOW
end

-- Check if player is holding an empty bucket
local function isEmptyBucketEquipped()
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	if not selectedBlock or not selectedBlock.id then
		return false
	end
	return selectedBlock.id == Constants.BlockType.BUCKET
end

-- Check if player is holding a water bucket
local function isWaterBucketEquipped()
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	if not selectedBlock or not selectedBlock.id then
		return false
	end
	return selectedBlock.id == Constants.BlockType.WATER_BUCKET
end

-- Check if player is holding any bucket (empty or filled)
-- Note: Function defined but reserved for future use (currently relies on specific bucket checks)
local function _isBucketEquipped()
	return isEmptyBucketEquipped() or isWaterBucketEquipped()
end

local function sendCancelForBlock(blockPos)
	if not blockPos then
		return
	end
	local key = _blockKey(blockPos)
	if not key then
		return
	end
	local now = os.clock()
	if lastCancelKey == key and (now - lastCancelAt) < 0.05 then
		return
	end
	lastCancelKey = key
	lastCancelAt = now
	EventManager:SendToServer("CancelBlockBreak", {
		x = blockPos.X,
		y = blockPos.Y,
		z = blockPos.Z,
	})
end

local function playBlockHitSound(blockPos)
	if not blockPos or not blockAPI or not blockAPI.worldManager then
		return
	end

	local wm = blockAPI.worldManager
	local blockId = wm:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
	if not blockId or blockId == Constants.BlockType.AIR then
		return
	end

	local key = _blockKey(blockPos)
	local now = os.clock()
	if key and hitSoundTimestamps[key] and (now - hitSoundTimestamps[key]) < HIT_SOUND_COOLDOWN then
		return
	end

	local material = BlockProperties:GetHitMaterial(blockId)
	local soundPool = BlockBreakFeedbackConfig.HitSounds[material]
	if not soundPool or #soundPool == 0 then
		soundPool = BlockBreakFeedbackConfig.HitSounds[BlockBreakFeedbackConfig.DEFAULT_MATERIAL]
	end
	if not soundPool or #soundPool == 0 then
		return
	end

	local soundId = soundPool[math.random(1, #soundPool)]
	if not soundId then
		return
	end

	if key then
		hitSoundTimestamps[key] = now
	end

	local anchor = Instance.new("Part")
	anchor.Name = "BlockHitSound"
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.CFrame = CFrame.new(_blockWorldCenter(blockPos))
	anchor.Parent = workspace

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 5
	sound.RollOffMaxDistance = 60
	sound.Volume = 0.65
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 2)
end

-- Forward declarations
local getTargetedBlock
local getBridgePlacementCandidate

-- Compute an aim ray (origin, direction) based on targeting mode
-- targetingMode: "crosshair" = center screen, "direct" = input position (click/tap)
local function _computeAimRay()
    if not camera then
    	return nil, nil
    end

    local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"

    if targetingMode == "direct" and lastInputPosition then
        -- Direct mode: Ray through click/tap position
        local ray = camera:ViewportPointToRay(lastInputPosition.X, lastInputPosition.Y)
        return ray.Origin, ray.Direction
    else
        -- Crosshair mode: Ray through center of screen
        local viewportSize = camera.ViewportSize
        local ray = camera:ViewportPointToRay(viewportSize.X / 2, viewportSize.Y / 2)
        return ray.Origin, ray.Direction
    end
end

-- Create selection box for visual feedback
local function createSelectionBox()
	local box = Instance.new("SelectionBox")
	box.Name = "BlockSelectionBox"
	box.LineThickness = 0.03
	box.Color3 = Color3.fromRGB(255, 255, 255)
	box.SurfaceColor3 = Color3.fromRGB(255, 255, 255)
	box.SurfaceTransparency = 0.95
	box.Transparency = 0.7
	box.Parent = workspace
	return box
end

-- Track last targeted block for dirty checking
local lastTargetedBlock = nil

-- Update selection box position
local function updateSelectionBox()
	if not BlockInteraction.isReady or not blockAPI then
		if selectionBox then
			selectionBox.Adornee = nil
		end
		lastTargetedBlock = nil
		return
	end

	-- Skip updates when player is in UI/menus (optimization)
	local GuiService = game:GetService("GuiService")
	if GuiService.SelectedObject ~= nil then
		if selectionBox then
			selectionBox.Adornee = nil
		end
		return
	end

	local blockPos, _faceNormal, _preciseHitPos = getTargetedBlock()

	-- Helper to check if a block position is within interaction range
	local function isBlockInRange(pos)
		local character = player.Character
		if not character then
			return false
		end
		local head = character:FindFirstChild("Head")
		if not head then
			return false
		end
		local bs = Constants.BLOCK_SIZE
		local blockCenter = Vector3.new(
			pos.X * bs + bs * 0.5,
			pos.Y * bs + bs * 0.5,
			pos.Z * bs + bs * 0.5
		)
		local distance = (blockCenter - head.Position).Magnitude
		local maxReach = 4.5 * bs + 2 -- Same as server placement/breaking distance
		return distance <= maxReach
	end

	-- Use bridge assist if no block targeted OR target is out of range
	local useBridgeAssist = (not blockPos) or (blockPos and not isBlockInRange(blockPos))
	if useBridgeAssist and VoxelConfig and VoxelConfig.PLACEMENT and VoxelConfig.PLACEMENT.BRIDGE_ASSIST_ENABLED then
		local placePos, _supportPos = getBridgePlacementCandidate()
		if placePos then
			-- Highlight the target placement cell (air block)
			blockPos = placePos
		end
	end

	-- Dirty check: Skip update if still targeting same block
	if lastTargetedBlock and blockPos then
		if lastTargetedBlock.X == blockPos.X and
		   lastTargetedBlock.Y == blockPos.Y and
		   lastTargetedBlock.Z == blockPos.Z then
			return -- No change, skip expensive update
		end
	end

	lastTargetedBlock = blockPos

	if blockPos then
		-- Distance check: Only show selection box if within interaction range
		if not isBlockInRange(blockPos) then
			-- Block is too far, hide selection box
			if selectionBox then
				selectionBox.Adornee = nil
			end
			lastTargetedBlock = nil
			return
		end
		-- Create a temporary part to represent the block
		if not selectionBox then
			selectionBox = createSelectionBox()
		end

		-- Create or reuse an adornee part
		local adornee = selectionBox.Adornee
		if not adornee or not adornee.Parent then
			adornee = Instance.new("Part")
			adornee.Name = "SelectionAdornee"
			adornee.Anchored = true
			adornee.CanCollide = false
			adornee.Transparency = 1
			adornee.Parent = workspace
		end

		-- Position the adornee at the block position
		local bs = Constants.BLOCK_SIZE
		adornee.Size = Vector3.new(bs, bs, bs)
		adornee.CFrame = CFrame.new(
			blockPos.X * bs + bs/2,
			blockPos.Y * bs + bs/2,
			blockPos.Z * bs + bs/2
		)

		selectionBox.Adornee = adornee
	else
		-- No block targeted, hide selection box
		if selectionBox then
			selectionBox.Adornee = nil
		end
		lastTargetedBlock = nil
	end
end

-- Raycast to find targeted block
-- Uses camera.targetingMode from GameState:
--   "crosshair" = center of screen (for FIRST_PERSON, THIRD_PERSON_LOCK)
--   "direct" = input position (for THIRD_PERSON_FREE - click/tap where you want)
-- Returns: blockPos, faceNormal, preciseHitPos
getTargetedBlock = function()
	if not BlockInteraction.isReady or not blockAPI or not camera then
		return nil, nil, nil
	end

	-- Compute picking ray based on targeting mode
	local origin, direction = _computeAimRay()
	if not origin or not direction then
		return nil, nil, nil
	end

	local maxDistance = 100

	-- Find block along ray
	local hitPos, faceNormal, preciseHitPos = blockAPI:GetTargetedBlockFace(origin, direction, maxDistance)
	if not hitPos then
		return nil, nil, nil
	end

	-- Convert to block coordinates
	local blockX = math.floor(hitPos.X / Constants.BLOCK_SIZE)
	local blockY = math.floor(hitPos.Y / Constants.BLOCK_SIZE)
	local blockZ = math.floor(hitPos.Z / Constants.BLOCK_SIZE)

	return Vector3.new(blockX, blockY, blockZ), faceNormal, preciseHitPos
end

-- Bridge-assist: when aiming into the void, propose a placement on the player's ground level
-- Returns: placePos (Vector3) to place into AIR, supportBlockPos (Vector3), faceNormal (Vector3), hitPosition (Vector3)
-- Optional parameters for locked bridge mode: lockedY, lockedDX, lockedDZ
getBridgePlacementCandidate = function(lockedY, lockedDX, lockedDZ)
    if not VoxelConfig or not VoxelConfig.PLACEMENT or not VoxelConfig.PLACEMENT.BRIDGE_ASSIST_ENABLED then
        return nil, nil, nil, nil
    end
    if not BlockInteraction.isReady or not blockAPI or not camera then
        return nil, nil, nil, nil
    end

    local character = player.Character
    if not character then
    	return nil, nil, nil, nil
    end
    local head = character:FindFirstChild("Head")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not head or not rootPart then
    	return nil, nil, nil, nil
    end

    local bs = Constants.BLOCK_SIZE
    local worldHeight = Constants.WORLD_HEIGHT or 128

    -- Determine Y level
    local yBlock
    if lockedY then
        -- Use locked Y level (bridge mode)
        yBlock = lockedY
    else
        -- Calculate from player position
        local origin, direction = _computeAimRay()
        if not origin or not direction then
        	return nil, nil, nil, nil
        end

        -- Only check look direction if NOT in locked bridge mode
        if direction.Y > 0.2 then
            return nil, nil, nil, nil
        end

        local footY = rootPart.Position.Y - 2.5
        yBlock = math.floor(footY / bs) - 1
        if yBlock < 0 then
        	yBlock = 0
        end
        if yBlock >= worldHeight then
        	yBlock = worldHeight - 1
        end
    end

    local wm = blockAPI and blockAPI.worldManager
    if not wm then
    	return nil, nil, nil, nil
    end

    -- Check if chunk at position is loaded (to avoid false AIR at chunk borders)
    local function _isChunkLoaded(x, z)
        local chunkX = math.floor(x / (Constants.CHUNK_SIZE_X or 16))
        local chunkZ = math.floor(z / (Constants.CHUNK_SIZE_Z or 16))
        local chunk = wm:GetChunk(chunkX, chunkZ)
        return chunk ~= nil
    end

    local function _isAirAt(x, y, z)
        -- If chunk isn't loaded, treat as NOT air (be conservative)
        if not _isChunkLoaded(x, z) then
            return false
        end
        local id = wm:GetBlock(x, y, z)
        -- Also treat flowing water as "air" for placement purposes (it's replaceable)
        return (id == nil) or (id == Constants.BlockType.AIR) or (id == Constants.BlockType.FLOWING_WATER)
    end
    local function _nonAirAt(x, y, z)
        -- If chunk isn't loaded, treat as NOT solid (be conservative)
        if not _isChunkLoaded(x, z) then
            return false
        end
        local id = wm:GetBlock(x, y, z)
        return id and id ~= Constants.BlockType.AIR
    end

    local maxSteps = (VoxelConfig.PLACEMENT.BRIDGE_ASSIST_MAX_STEPS or 3)
    if maxSteps < 0 then
    	maxSteps = 0
    end

    -- Determine direction
    local dx, dz
    if lockedDX and lockedDZ then
        -- Use locked direction (bridge mode)
        dx = lockedDX
        dz = lockedDZ
    else
        -- Calculate from camera look direction
        local origin, direction = _computeAimRay()
        if not origin or not direction then
        	return nil, nil, nil, nil
        end

        local dir2 = Vector3.new(direction.X, 0, direction.Z)
        local mag2 = dir2.Magnitude
        if mag2 < 1e-3 then
            return nil, nil, nil, nil
        end
        local absX, absZ = math.abs(dir2.X), math.abs(dir2.Z)
        if absX >= absZ then
            dx = (dir2.X >= 0) and 1 or -1
            dz = 0
        else
            dx = 0
            dz = (dir2.Z >= 0) and 1 or -1
        end
    end

    -- Get player's current block position as the starting point
    local playerBlockX = math.floor(rootPart.Position.X / bs)
    local playerBlockZ = math.floor(rootPart.Position.Z / bs)

    -- Calculate how far into the current block the player is (0.0 to 1.0)
    local posInBlockX = (rootPart.Position.X / bs) - playerBlockX
    local posInBlockZ = (rootPart.Position.Z / bs) - playerBlockZ

    -- Predictive placement: if player is >60% across current block in bridge direction, look ahead
    local predictiveOffset = 0
    if dx ~= 0 then
        local progress = dx > 0 and posInBlockX or (1 - posInBlockX)
        if progress > 0.6 then
            predictiveOffset = 1
        end
    elseif dz ~= 0 then
        local progress = dz > 0 and posInBlockZ or (1 - posInBlockZ)
        if progress > 0.6 then
            predictiveOffset = 1
        end
    end

    -- Search along the cardinal direction only (no diagonal placement)
    -- Stop immediately if out of range (don't keep searching further)
    local maxReach = 4.5 * bs + 2

    for s = 1, maxSteps do
        local cx = playerBlockX + (s + predictiveOffset) * dx
        local cz = playerBlockZ + (s + predictiveOffset) * dz

        -- Check distance first - if this position is out of range, stop searching
        local blockCenter = Vector3.new(
            cx * bs + bs * 0.5,
            yBlock * bs + bs * 0.5,
            cz * bs + bs * 0.5
        )
        if (blockCenter - head.Position).Magnitude > maxReach then
            -- Out of range - stop searching, don't try further blocks
            return nil, nil, nil, nil
        end

        if _isAirAt(cx, yBlock, cz) then
            -- Check for a support block adjacent to this air block (in the direction back toward player)
            local supportX = cx - dx
            local supportZ = cz - dz
            local faceNormal = Vector3.new(dx, 0, dz)

            if _nonAirAt(supportX, yBlock, supportZ) then
                local placePos = Vector3.new(cx, yBlock, cz)
                local supportPos = Vector3.new(supportX, yBlock, supportZ)
                local hitPosition = Vector3.new(
                    supportX * bs + bs * 0.5,
                    yBlock * bs + bs * 0.25,
                    supportZ * bs + bs * 0.5
                )
                return placePos, supportPos, faceNormal, hitPosition
            end
        end
    end

    return nil, nil, nil, nil
end

-- Break block (left click)
local function startBreaking()
	-- Guard: Don't allow breaking until system is ready
	if not BlockInteraction.isReady then
		return
	end
	if isBreaking then
		return
	end
	if isBowEquipped() then
		return
	end

	-- Block interactions when UI is open (inventory, chest, worlds, minion, etc.)
	if InputService:IsGameplayBlocked() then
		return
	end

	-- Prevent breaking when a sword is equipped (PvP mode)
	-- Note: Uses the file-scoped GameState, ToolConfig, BlockProperties rather than re-requiring
	-- The following variables are reserved for future sword block logic
	local _selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1
	local _invMgr = require(script.Parent.Parent.Managers.ClientInventoryManager)
	-- Without direct instance, rely on tool equip server state; locally approximate via selectedBlock nil
	local _toolType = nil
	-- Note: BlockProperties already required at file scope
	-- If currently selected is a Tool (from hotbar), and type is SWORD, block mining
	-- We do not have the stack here; keep this lightweight client-side guard by checking GameState flag if set in hotbar
	-- Fallback: allow breaking; server still authoritative

	-- Verify character still exists
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then
		return
	end

	local blockPos, _, _ = getTargetedBlock()
	if not blockPos then
		return
	end

	-- Water source blocks cannot be broken - they must be picked up with a bucket
	local worldManager = blockAPI and blockAPI.worldManager
	if worldManager then
		local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
		if blockId == Constants.BlockType.WATER_SOURCE or blockId == Constants.BlockType.FLOWING_WATER then
			-- Water cannot be broken, only picked up with bucket (via right-click)
			return
		end
	end

	isBreaking = true
	breakingBlock = blockPos
	lastBreakTime = os.clock()

	-- Send initial punch
	EventManager:SendToServer("PlayerPunch", {
		x = blockPos.X,
		y = blockPos.Y,
		z = blockPos.Z,
		dt = 0
	})
	ToolAnimationController:PlaySwing()
	playBlockHitSound(blockPos)

	-- Continue sending punches while mouse is held
	task.spawn(function()
		while isBreaking do
			local now = os.clock()
			local dt = now - lastBreakTime

			if dt >= BREAK_INTERVAL then
				local currentBlock, _, _ = getTargetedBlock()

				if currentBlock then
					if not breakingBlock or currentBlock ~= breakingBlock then
						-- Switched target: reset UI and start breaking new block immediately
						if BlockBreakProgress and BlockBreakProgress.Reset then
							BlockBreakProgress:Reset()
						end
						if breakingBlock then
							sendCancelForBlock(breakingBlock)
						end
						breakingBlock = currentBlock
						EventManager:SendToServer("PlayerPunch", {
							x = breakingBlock.X,
							y = breakingBlock.Y,
							z = breakingBlock.Z,
							dt = 0
						})
						ToolAnimationController:PlaySwing()
						playBlockHitSound(breakingBlock)
						lastBreakTime = now
					else
						EventManager:SendToServer("PlayerPunch", {
							x = breakingBlock.X,
							y = breakingBlock.Y,
							z = breakingBlock.Z,
							dt = dt
						})
						ToolAnimationController:PlaySwing()
						playBlockHitSound(breakingBlock)
						lastBreakTime = now
					end
				else
					-- Nothing targeted: reset progress but keep mining state while mouse is held
					if BlockBreakProgress and BlockBreakProgress.Reset then
						BlockBreakProgress:Reset()
					end
					if breakingBlock then
						sendCancelForBlock(breakingBlock)
					end
					breakingBlock = nil
				end
			end

			task.wait(0.05)
		end
	end)
end

local function stopBreaking()
	if breakingBlock then
		sendCancelForBlock(breakingBlock)
	end
	isBreaking = false
	breakingBlock = nil
	-- Note: Progress bar will auto-hide via its built-in timeout when server stops sending progress updates
end

-- Interact with block or place block (right click)
local function interactOrPlace()
	-- Guard: Don't allow actions until system is ready
	if not BlockInteraction.isReady or not blockAPI then
		return
	end
	if isBowEquipped() then
		return
	end

	-- Block interactions when UI is open (inventory, chest, worlds, minion, etc.)
	if InputService:IsGameplayBlocked() then
		return
	end

	-- Try interacting with a minion mob model under mouse
	do
		local target = mouse and mouse.Target
		if target then
			local model = target:FindFirstAncestorOfClass("Model")
			if model then
				local entityId = model:GetAttribute("MobEntityId")
				if entityId then
					local now = os.clock()
					if (now - lastMinionOpenRequestAt) < MINION_OPEN_DEBOUNCE then
						print("[BlockInteraction] Minion open request debounced (entity path)")
						return true
					end
					lastMinionOpenRequestAt = now
					print("[BlockInteraction] RequestOpenMinionByEntity entityId=", tostring(entityId))
					EventManager:SendToServer("RequestOpenMinionByEntity", { entityId = tostring(entityId) })
					return true
				end
			end
		end
	end

	-- Try interacting with an NPC model under mouse
	do
		local target = mouse and mouse.Target
		if target then
			local model = target:FindFirstAncestorOfClass("Model")
			if model then
				local npcId = model:GetAttribute("NPCId")
				if npcId then
					local now = os.clock()
					if (now - lastMinionOpenRequestAt) < MINION_OPEN_DEBOUNCE then
						print("[BlockInteraction] NPC interact request debounced")
						return true
					end
					lastMinionOpenRequestAt = now
					print("[BlockInteraction] RequestNPCInteract npcId=", tostring(npcId))
					EventManager:SendToServer("RequestNPCInteract", { npcId = tostring(npcId) })
					return true
				end
			end
		end
	end

	-- Verify character still exists
	local character = player.Character
	if not character or not character:FindFirstChild("Humanoid") then
		return
	end

	local now = os.clock()
	if (now - lastPlaceTime) < PLACE_COOLDOWN then
		return
	end
	lastPlaceTime = now

	local blockPos, faceNormal, preciseHitPos = getTargetedBlock()

	-- ═══════════════════════════════════════════════════════════════════════════
	-- BUCKET HANDLING (Minecraft-style water pickup/placement)
	-- ═══════════════════════════════════════════════════════════════════════════
	local _selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1

	-- Empty bucket + targeting water source = pick up water
	if isEmptyBucketEquipped() and blockPos then
		local worldManager = blockAPI and blockAPI.worldManager
		if worldManager then
			local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
			if blockId == Constants.BlockType.WATER_SOURCE then
				-- Send bucket pickup request to server
				EventManager:SendToServer("RequestBucketPickup", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z,
					hotbarSlot = selectedSlot
				})
				return true
			end
		end
	end

	-- Water bucket + right-click = place water source
	if isWaterBucketEquipped() then
		-- Need a valid surface to place water on
		if blockPos and faceNormal then
			local placeX = blockPos.X + faceNormal.X
			local placeY = blockPos.Y + faceNormal.Y
			local placeZ = blockPos.Z + faceNormal.Z

			-- Send bucket place request to server
			EventManager:SendToServer("RequestBucketPlace", {
				x = placeX,
				y = placeY,
				z = placeZ,
				hotbarSlot = selectedSlot,
				targetBlockPos = blockPos,
				faceNormal = faceNormal
			})
			return true
		end
		return false  -- Can't place water without a target
	end
	-- ═══════════════════════════════════════════════════════════════════════════

	-- Helper to check if a block position is within interaction range
	local function isBlockInRange(pos)
		local char = player.Character
		if not char then
			return false
		end
		local head = char:FindFirstChild("Head")
		if not head then
			return false
		end
		local bs = Constants.BLOCK_SIZE
		local blockCenter = Vector3.new(
			pos.X * bs + bs * 0.5,
			pos.Y * bs + bs * 0.5,
			pos.Z * bs + bs * 0.5
		)
		local distance = (blockCenter - head.Position).Magnitude
		local maxReach = 4.5 * bs + 2
		return distance <= maxReach
	end

	-- Use bridge assist if no block targeted OR target is out of range
	local useBridgeAssist = (not blockPos) or (blockPos and not isBlockInRange(blockPos))
	if useBridgeAssist then
		-- Bridge assist fallback: synthesize support face when aiming into void or out of range
		if VoxelConfig and VoxelConfig.PLACEMENT and VoxelConfig.PLACEMENT.BRIDGE_ASSIST_ENABLED then
			local placePos, supportPos, bFace, bHit = getBridgePlacementCandidate()
			if placePos and supportPos and bFace then
				blockPos = supportPos
				faceNormal = bFace
				preciseHitPos = bHit
			else
				return false
			end
		else
			return false
		end
	end

	-- Check if the targeted block is interactable (like a chest)
	local worldManager = blockAPI and blockAPI.worldManager
	if worldManager then
		local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)

		-- Handle other interactable blocks (like a chest, minion)
		if blockId and BlockRegistry:IsInteractable(blockId) then
			-- Handle interaction (e.g., open chest, open workbench)
			if blockId == Constants.BlockType.CHEST then
				print("Opening chest at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenChest", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			elseif blockId == Constants.BlockType.CRAFTING_TABLE then
				print("Opening workbench at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenWorkbench", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			elseif blockId == Constants.BlockType.FURNACE then
				print("Opening furnace at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenFurnace", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			elseif _isMinionBlock(blockId) then
				local now = os.clock()
				if (now - lastMinionOpenRequestAt) < MINION_OPEN_DEBOUNCE then
					print("[BlockInteraction] Minion open request debounced (block path)")
					return true
				end
				lastMinionOpenRequestAt = now
				print("Opening minion at", blockPos.X, blockPos.Y, blockPos.Z)
				EventManager:SendToServer("RequestOpenMinion", {
					x = blockPos.X,
					y = blockPos.Y,
					z = blockPos.Z
				})
				return true
			end
		end
	end

	-- Not interacting with anything, try to open minion UI (if a minion is anchored here), else place a block or use spawn egg
	if not faceNormal then
		return false
	end

	-- Only entity right-click opens minion UI; do not fallback-open by block position

	-- Get selected block from hotbar
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	if not selectedBlock or not selectedBlock.id then
		return false -- No block selected
	end

	-- If a spawn egg is selected, request mob spawn instead of block placement
	if selectedBlock and selectedBlock.id and SpawnEggConfig.IsSpawnEgg(selectedBlock.id) then
		local placeX = blockPos.X + faceNormal.X
		local placeY = blockPos.Y + faceNormal.Y
		local placeZ = blockPos.Z + faceNormal.Z
		local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1
		EventManager:SendToServer("RequestSpawnMobAt", {
			x = placeX,
			y = placeY,
			z = placeZ,
			eggItemId = selectedBlock.id,
			hotbarSlot = selectedSlot,
			targetBlockPos = blockPos,
			faceNormal = faceNormal,
			hitPosition = preciseHitPos
		})
		return true
	end

	-- Client-side guard: allow farm items (seeds/carrots/potatoes/beetroot seeds/compost) even if not normally placeable
	local BLOCK = Constants.BlockType
	local isFarmItem = (
		selectedBlock.id == BLOCK.WHEAT_SEEDS or
		selectedBlock.id == BLOCK.POTATO or
		selectedBlock.id == BLOCK.CARROT or
		selectedBlock.id == BLOCK.BEETROOT_SEEDS
	)
	if not BlockRegistry:IsPlaceable(selectedBlock.id) and not isFarmItem then
		return false
	end

	-- Determine placement position
	-- If targeted block is replaceable (water, flowing water), place INTO that position
	-- Otherwise, place adjacent to clicked face (Minecraft logic)
	local placeX, placeY, placeZ
	local worldManager = blockAPI and blockAPI.worldManager
	local targetBlockId = worldManager and worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)

	if targetBlockId and BlockRegistry:IsReplaceable(targetBlockId) and targetBlockId ~= BLOCK.AIR then
		-- Target is replaceable (water/flowing water) - place INTO the water position
		placeX = blockPos.X
		placeY = blockPos.Y
		placeZ = blockPos.Z
	else
		-- Normal placement - place adjacent to clicked face
		placeX = blockPos.X + faceNormal.X
		placeY = blockPos.Y + faceNormal.Y
		placeZ = blockPos.Z + faceNormal.Z
	end

	local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1

	-- Send placement request with precise hit position for Minecraft-style placement
	EventManager:SendToServer("VoxelRequestBlockPlace", {
		x = placeX,
		y = placeY,
		z = placeZ,
		blockId = selectedBlock.id,
		hotbarSlot = selectedSlot,
		-- Include hit position info for determining stair/slab orientation
		hitPosition = preciseHitPos,
		targetBlockPos = blockPos,
		faceNormal = faceNormal
	})

	return true
end

-- Start continuous placement while right mouse is held
local function startPlacing()
    -- Guard
    if not BlockInteraction.isReady or not blockAPI then
    	return
    end
    if isPlacing then
    	return
    end

    -- Initial attempt (includes interactions like chest/water)
    interactOrPlace()

    isPlacing = true
    -- Reset bridge mode state at start
    bridgeModeActive = false
    bridgeLockedY = nil
    bridgeLockedDX = nil
    bridgeLockedDZ = nil
    _bridgeLastBlockX = nil
    _bridgeLastBlockZ = nil

    -- Track last placed position to avoid duplicate requests
    local lastPlacedKey = nil

    task.spawn(function()
        while isPlacing do
            local now = os.clock()
            if (now - lastPlaceTime) >= PLACE_COOLDOWN then
				local blockPos, faceNormal, preciseHitPos = getTargetedBlock()
				local usedBridgeAssist = false

				-- Helper to check if a block position is within interaction range
				local function isBlockInRange(pos)
					local char = player.Character
					if not char then
						return false
					end
					local head = char:FindFirstChild("Head")
					if not head then
						return false
					end
					local bs = Constants.BLOCK_SIZE
					local blockCenter = Vector3.new(
						pos.X * bs + bs * 0.5,
						pos.Y * bs + bs * 0.5,
						pos.Z * bs + bs * 0.5
					)
					local distance = (blockCenter - head.Position).Magnitude
					local maxReach = 4.5 * bs + 2
					return distance <= maxReach
				end

				-- Determine if we should use bridge assist
				local shouldUseBridgeAssist = false

				-- If already in bridge mode, ALWAYS use bridge assist with locked values
				if bridgeModeActive then
					shouldUseBridgeAssist = true
				else
					-- Check conditions to ENTER bridge mode
					-- Case 1: No block targeted or out of range
					if not (blockPos and faceNormal) or (blockPos and not isBlockInRange(blockPos)) then
						shouldUseBridgeAssist = true
					end

					-- Case 2: Targeting TOP of a block at feet level (would stack on bridge)
					if not shouldUseBridgeAssist and blockPos and faceNormal and faceNormal.Y == 1 then
						local character = player.Character
						local rootPart = character and character:FindFirstChild("HumanoidRootPart")
						if rootPart then
							local bs = Constants.BLOCK_SIZE
							local footY = rootPart.Position.Y - 2.5
							local standingBlockY = math.floor(footY / bs) - 1
							if blockPos.Y <= standingBlockY then
								shouldUseBridgeAssist = true
							end
						end
					end
				end

				-- Apply bridge assist if needed
				local bridgeAssistFailed = false
				if shouldUseBridgeAssist and VoxelConfig and VoxelConfig.PLACEMENT and VoxelConfig.PLACEMENT.BRIDGE_ASSIST_ENABLED then
					-- Use locked values if in bridge mode, otherwise calculate fresh
					local placePos, supportPos, bFace, bHit
					if bridgeModeActive and bridgeLockedY and bridgeLockedDX and bridgeLockedDZ then
						placePos, supportPos, bFace, bHit = getBridgePlacementCandidate(bridgeLockedY, bridgeLockedDX, bridgeLockedDZ)
					else
						placePos, supportPos, bFace, bHit = getBridgePlacementCandidate()
					end

					if placePos and supportPos and bFace then
						blockPos = supportPos
						faceNormal = bFace
						preciseHitPos = bHit
						usedBridgeAssist = true

						-- If this is the first bridge assist placement, lock the values
						if not bridgeModeActive then
							local character = player.Character
							local rootPart = character and character:FindFirstChild("HumanoidRootPart")
							if rootPart then
								local bs = Constants.BLOCK_SIZE
								local footY = rootPart.Position.Y - 2.5
								bridgeLockedY = math.floor(footY / bs) - 1
								if bridgeLockedY < 0 then
									bridgeLockedY = 0
								end
								-- Lock direction from face normal
								bridgeLockedDX = math.floor(bFace.X + 0.5)
								bridgeLockedDZ = math.floor(bFace.Z + 0.5)
								_bridgeLastBlockX = math.floor(rootPart.Position.X / bs)
								_bridgeLastBlockZ = math.floor(rootPart.Position.Z / bs)
							end
						end
					else
						-- Bridge assist failed (out of range or no valid placement)
						bridgeAssistFailed = true
					end
				end

				-- If we're in bridge mode and bridge assist failed, DON'T fall back to normal targeting
				-- User must release mouse and click again to start a new placement
				if bridgeModeActive and bridgeAssistFailed then
					-- Skip this iteration - don't place anything
					task.wait(0.05)
					continue
				end

				-- Place block if we have valid target
				if blockPos and faceNormal then
					-- Determine placement position
					-- If targeted block is replaceable (water), place INTO that position
					local worldManager = blockAPI and blockAPI.worldManager
					local targetBlockId = worldManager and worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
					local placeX, placeY, placeZ

					if targetBlockId and BlockRegistry:IsReplaceable(targetBlockId) and targetBlockId ~= Constants.BlockType.AIR then
						-- Target is replaceable (water/flowing water) - place INTO the water position
						placeX = blockPos.X
						placeY = blockPos.Y
						placeZ = blockPos.Z
					else
						-- Normal placement - place adjacent to clicked face
						placeX = blockPos.X + faceNormal.X
						placeY = blockPos.Y + faceNormal.Y
						placeZ = blockPos.Z + faceNormal.Z
					end

					local placeKey = string.format("%d,%d,%d", placeX, placeY, placeZ)

					-- Skip if we already sent a request for this exact position
					if placeKey ~= lastPlacedKey then
						local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
						if selectedBlock and selectedBlock.id then
							-- Skip if already occupied (client check)
							-- Allow placing through air and replaceable blocks (water)
							local canTryPlace = true
							if worldManager then
								local existing = worldManager:GetBlock(placeX, placeY, placeZ)
								if existing and existing ~= Constants.BlockType.AIR and not BlockRegistry:IsReplaceable(existing) then
									canTryPlace = false
									lastPlacedKey = nil -- Reset so we can try new positions
								end
							end

							if canTryPlace then
								local selectedSlot = GameState:Get("voxelWorld.selectedSlot") or 1
								local BLOCK = Constants.BlockType
								local isFarmItem = (
									selectedBlock.id == BLOCK.WHEAT_SEEDS or
									selectedBlock.id == BLOCK.POTATO or
									selectedBlock.id == BLOCK.CARROT or
									selectedBlock.id == BLOCK.BEETROOT_SEEDS
								)
								if BlockRegistry:IsPlaceable(selectedBlock.id) or isFarmItem then
									EventManager:SendToServer("VoxelRequestBlockPlace", {
										x = placeX,
										y = placeY,
										z = placeZ,
										blockId = selectedBlock.id,
										hotbarSlot = selectedSlot,
										hitPosition = preciseHitPos,
										targetBlockPos = blockPos,
										faceNormal = faceNormal
									})
									lastPlacedKey = placeKey
									lastPlaceTime = now

									-- If we used bridge assist for this placement, activate bridge mode
									if usedBridgeAssist then
										bridgeModeActive = true
									end
								end
							end
						end
					else
						-- Same position - check if block was placed and reset
						local worldManager = blockAPI and blockAPI.worldManager
						if worldManager then
							local existing = worldManager:GetBlock(placeX, placeY, placeZ)
							if existing and existing ~= Constants.BlockType.AIR then
								lastPlacedKey = nil -- Block placed, allow new placements
							end
						end
					end
				end
			end
            task.wait(0.05)
        end
    end)
end

local function stopPlacing()
    isPlacing = false
    -- Reset all bridge mode state when mouse released
    bridgeModeActive = false
    bridgeLockedY = nil
    bridgeLockedDX = nil
    bridgeLockedDZ = nil
    _bridgeLastBlockX = nil
    _bridgeLastBlockZ = nil
end

-- Update selection box and handle mode switching
task.spawn(function()
	local lastCameraPos = Vector3.new(0, 0, 0)
	local lastCameraLook = Vector3.new(0, 0, 1)
	local lastMousePos = Vector2.new(0, 0)
	local CAMERA_MOVE_THRESHOLD = 1.0 -- studs
	local CAMERA_ANGLE_THRESHOLD = 0.05 -- radians
	local MOUSE_MOVE_THRESHOLD = 5 -- pixels (for direct targeting mode)

	while true do
		-- 10Hz update rate for performance
		task.wait(0.1)

		local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"

		-- Check if camera moved/rotated significantly (dirty checking)
		local currentPos = camera.CFrame.Position
		local currentLook = camera.CFrame.LookVector

		local cameraMoved = (currentPos - lastCameraPos).Magnitude > CAMERA_MOVE_THRESHOLD
		local cameraRotated = math.acos(math.clamp(currentLook:Dot(lastCameraLook), -1, 1)) > CAMERA_ANGLE_THRESHOLD

		-- In direct targeting mode, also check mouse movement (cursor can move independently)
		local mouseMoved = false
		if targetingMode == "direct" then
			local currentMousePos = InputService:GetMouseLocation()
			mouseMoved = (currentMousePos - lastMousePos).Magnitude > MOUSE_MOVE_THRESHOLD
			if mouseMoved then
				lastMousePos = currentMousePos
				-- Update lastInputPosition so selection box follows cursor
				lastInputPosition = currentMousePos
			end
		end

		-- Update if camera changed OR mouse moved (in direct mode)
		if cameraMoved or cameraRotated or mouseMoved then
			updateSelectionBox()
			lastCameraPos = currentPos
			lastCameraLook = currentLook
		end
	end
end)

--[[
	Initialize block interaction system
	@param voxelWorldHandle - The voxel world handle from GameClient
]]
function BlockInteraction:Initialize(voxelWorldHandle)
	if not voxelWorldHandle or not voxelWorldHandle.GetWorldManager then
		warn("❌ BlockInteraction: Invalid voxel world handle")
		return false
	end

	-- Create BlockAPI instance
	local worldManager = voxelWorldHandle:GetWorldManager()
	blockAPI = BlockAPI.new(worldManager)

	-- Wait for character to load
	task.spawn(function()
		local character = player.Character or player.CharacterAdded:Wait()
		local humanoid = character:WaitForChild("Humanoid", 5)

		if not humanoid then
			warn("❌ BlockInteraction: Character missing Humanoid")
			return
		end

		-- Mark as ready
		BlockInteraction.isReady = true
	end)

	-- Handle character respawn
	player.CharacterAdded:Connect(function(character)
		-- Reset state on character respawn
		BlockInteraction.isReady = false
		isBreaking = false
		breakingBlock = nil

		-- Wait for new character to be ready
		task.spawn(function()
			local humanoid = character:WaitForChild("Humanoid", 5)
			if humanoid and blockAPI then
				BlockInteraction.isReady = true
				print("✅ BlockInteraction: Re-enabled after respawn")
			end
		end)
	end)

	-- Setup input handlers
	InputService.InputBegan:Connect(function(input, gameProcessed)
		-- CRITICAL: Check gameProcessed FIRST for all inputs
		-- This ensures we don't interfere with Roblox's native camera controls or UI
		if gameProcessed then
			return
		end

		-- F key: (unused)

		-- MOBILE: Touch handling (tap vs hold vs drag)
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Store input position for direct targeting mode
			lastInputPosition = Vector2.new(input.Position.X, input.Position.Y)

			-- Track touch for gesture detection
			local touchData = {
				input = input,
				startTime = tick(),
				startPos = Vector2.new(input.Position.X, input.Position.Y),
				currentPos = Vector2.new(input.Position.X, input.Position.Y),
				moved = false,
				holdTriggered = false,
			}
			activeTouches[input] = touchData

			-- Start hold timer (triggers break action after threshold)
			task.delay(HOLD_TIME_THRESHOLD, function()
				if activeTouches[input] and not activeTouches[input].moved then
					-- Still holding and haven't moved = HOLD action (break blocks)
					activeTouches[input].holdTriggered = true
					startBreaking()
				end
			end)
		end

		-- Store input position for direct targeting mode (mouse clicks)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			lastInputPosition = InputService:GetMouseLocation()
		end

		-- Right-click in third person: Track for click vs hold detection
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"
			if targetingMode == "direct" then
				-- Direct mode: Track right-click for click vs camera pan detection
				isRightClickHeld = true
				rightClickStartTime = tick()
				rightClickStartPos = InputService:GetMouseLocation()
			end
		end

		-- Left click behavior (PC)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- Left-click ALWAYS breaks blocks in both modes (Classic Minecraft)
			startBreaking()
		end

	end)

	-- Track touch movement to detect drag vs tap/hold
	InputService.InputChanged:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			local touchData = activeTouches[input]
			if touchData then
				-- Update current position
				touchData.currentPos = Vector2.new(input.Position.X, input.Position.Y)

				-- Check if moved beyond threshold
				local movement = (touchData.currentPos - touchData.startPos).Magnitude
				if movement > DRAG_MOVEMENT_THRESHOLD then
					touchData.moved = true
					-- If hold was triggered, stop breaking (switched to camera drag)
					if touchData.holdTriggered then
						stopBreaking()
						touchData.holdTriggered = false
						print("📱 Converted hold to drag - Stop breaking")
					end
				end
			end
		end
	end)

	InputService.InputEnded:Connect(function(input, gameProcessed)
		-- CRITICAL: Check gameProcessed FIRST to avoid interfering with Roblox camera/UI
		if gameProcessed then
			return
		end

		-- MOBILE: Touch release - Determine gesture and action
		if input.UserInputType == Enum.UserInputType.Touch then
			local touchData = activeTouches[input]
			if touchData then
				if touchData.holdTriggered then
					-- Was a hold action (breaking) - stop it
					stopBreaking()
				elseif not touchData.moved then
					-- Tap = interact/place
					-- Update input position to final tap position for accurate targeting
					lastInputPosition = touchData.startPos
					interactOrPlace()
				end

				-- Clean up touch data
				activeTouches[input] = nil
			end
		end

		-- PC: Stop breaking when left click released
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopBreaking()
		end

		-- PC: Right-click release in direct mode (detect click vs camera pan)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"
			if targetingMode == "direct" and isRightClickHeld then
				isRightClickHeld = false

				local holdDuration = tick() - rightClickStartTime
				local currentMousePos = InputService:GetMouseLocation()
				local mouseMovement = (currentMousePos - rightClickStartPos).Magnitude

				if holdDuration < CLICK_TIME_THRESHOLD and mouseMovement < CLICK_MOVEMENT_THRESHOLD then
					-- Update input position for accurate targeting
					lastInputPosition = currentMousePos
					interactOrPlace()
				end
			end
		end

		-- Note: First person right-click release is handled by ContextActionService below
	end)

	-- Setup right-click for placing/interacting using ContextActionService
	-- Dynamically bind/unbind based on camera mode
	local function handleRightClick(_actionName, inputState, _inputObject)
		-- Block interactions when UI is open (inventory, chest, worlds, minion, etc.)
		if InputService:IsGameplayBlocked() then
			return Enum.ContextActionResult.Pass
		end

		-- First person: Handle block placement and interaction (Minecraft-style)
		if inputState == Enum.UserInputState.Begin then
		-- Try minion mob model interaction in first-person
		do
			local target = mouse and mouse.Target
			if target then
				local model = target:FindFirstAncestorOfClass("Model")
				if model then
					local entityId = model:GetAttribute("MobEntityId")
					if entityId then
						local now = os.clock()
						if (now - lastMinionOpenRequestAt) < MINION_OPEN_DEBOUNCE then
							print("[BlockInteraction] Minion open request debounced (entity path FP)")
							return Enum.ContextActionResult.Sink
						end
						lastMinionOpenRequestAt = now
						print("[BlockInteraction] RequestOpenMinionByEntity (FP) entityId=", tostring(entityId))
						EventManager:SendToServer("RequestOpenMinionByEntity", { entityId = tostring(entityId) })
						return Enum.ContextActionResult.Sink
					end
				end
			end
		end
		-- Try NPC model interaction in first-person
		do
			local target = mouse and mouse.Target
			if target then
				local model = target:FindFirstAncestorOfClass("Model")
				if model then
					local npcId = model:GetAttribute("NPCId")
					if npcId then
						local now = os.clock()
						if (now - lastMinionOpenRequestAt) < MINION_OPEN_DEBOUNCE then
							print("[BlockInteraction] NPC interact request debounced (FP)")
							return Enum.ContextActionResult.Sink
						end
						lastMinionOpenRequestAt = now
						print("[BlockInteraction] RequestNPCInteract (FP) npcId=", tostring(npcId))
						EventManager:SendToServer("RequestNPCInteract", { npcId = tostring(npcId) })
						return Enum.ContextActionResult.Sink
					end
				end
			end
		end
		-- Check if clicking on an interactable block first
			local blockPos, _faceNormal, _preciseHitPos = getTargetedBlock()
			if blockPos then
				local worldManager = blockAPI and blockAPI.worldManager
				if worldManager then
					local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
					if blockId and BlockRegistry:IsInteractable(blockId) then
						-- Interact with chest, etc (one-time action, don't hold)
						interactOrPlace()
						return Enum.ContextActionResult.Sink
					end
				end
			end
			-- Not interactable: Start placing blocks
			startPlacing()
		elseif inputState == Enum.UserInputState.End then
			stopPlacing()
		end

		-- Sink the input (don't pass to other systems in first person)
		return Enum.ContextActionResult.Sink
	end

	-- Function to update right-click binding based on targeting mode
	local function updateRightClickBinding()
		local targetingMode = GameState:Get("camera.targetingMode") or "crosshair"

		if targetingMode == "crosshair" then
			-- Crosshair mode (first person, third person lock): Bind right-click for block placement
			ContextActionService:BindAction(
				"BlockPlacement",
				handleRightClick,
				false, -- Don't create touch button
				Enum.UserInputType.MouseButton2
			)
		else
			-- Direct mode (third person free): Unbind to allow right-click detection via InputEnded
			ContextActionService:UnbindAction("BlockPlacement")
		end
	end

	-- Set initial binding
	updateRightClickBinding()

	-- Listen for targeting mode changes
	GameState:OnPropertyChanged("camera.targetingMode", function(_newValue, _oldValue)
		updateRightClickBinding()
	end)

	-- Note: Mouse lock is managed by CameraController based on camera mode
	-- Note: Crosshair visibility is managed by Crosshair.lua based on targetingMode

	return true
end

--[[
	Force update the block targeting selection box
	Useful when blocks are placed/broken and camera hasn't moved
]]
function BlockInteraction:UpdateTargeting()
	-- Clear last targeted block to force a fresh update
	lastTargetedBlock = nil
	updateSelectionBox()
end

--[[
	Start breaking the targeted block (for mobile action bar)
	This allows external callers to trigger breaking without touch events
]]
function BlockInteraction:StartBreaking()
	startBreaking()
end

--[[
	Stop breaking the current block (for mobile action bar)
]]
function BlockInteraction:StopBreaking()
	stopBreaking()
end

--[[
	Try to place a block at the targeted position (for mobile action bar)
]]
function BlockInteraction:TryPlace()
	interactOrPlace()
end

--[[
	Get the currently targeted block (for F3 debug overlay)
	Returns: blockPos (Vector3), blockId (number), faceNormal (Vector3), metadata (number)
]]
function BlockInteraction:GetTargetedBlock()
	if not BlockInteraction.isReady or not blockAPI then
		return nil, nil, nil, nil
	end

	local blockPos, faceNormal = getTargetedBlock()
	if not blockPos then
		return nil, nil, nil, nil
	end

	local worldManager = blockAPI.worldManager
	if not worldManager then
		return nil, nil, nil, nil
	end

	local blockId = worldManager:GetBlock(blockPos.X, blockPos.Y, blockPos.Z)
	local metadata = worldManager:GetBlockMetadata(blockPos.X, blockPos.Y, blockPos.Z) or 0
	return blockPos, blockId, faceNormal, metadata
end

--[[
	Get loaded chunk count (for F3 debug overlay)
	Returns: number of loaded chunks
]]
function BlockInteraction:GetLoadedChunkCount()
	if not BlockInteraction.isReady or not blockAPI then
		return 0
	end

	local worldManager = blockAPI.worldManager
	if not worldManager or not worldManager.chunks then
		return 0
	end

	local count = 0
	for _ in pairs(worldManager.chunks) do
		count = count + 1
	end
	return count
end

--[[
	Get the world manager (for F3 debug overlay water flow analysis)
	Returns: worldManager or nil
]]
function BlockInteraction:GetWorldManager()
	if not BlockInteraction.isReady or not blockAPI then
		return nil
	end
	return blockAPI.worldManager
end

return BlockInteraction

