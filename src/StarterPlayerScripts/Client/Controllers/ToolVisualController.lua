--[[
    ToolVisualController.lua
    Renders held items (tools AND blocks) on:
    - Local player (3rd person)
    - Remote players (multiplayer visibility)

    Uses HeldItemRenderer for unified rendering logic.
    Handles special bow animations for local player.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local HeldItemRenderer = require(ReplicatedStorage.Shared.HeldItemRenderer)

local controller = {}
local player = Players.LocalPlayer

----------------------------------------------------------------
-- Local Player State
----------------------------------------------------------------
local currentHandle = nil
local handleWeld = nil
local currentItemId = nil
local currentToolType = nil
local isBowCharging = false
local currentBowStage = nil

-- Bow meshes (multiple parts for charge stages)
local bowMeshParts = {} -- {idle, [0], [1], [2]}

-- Arm animation state
local shoulderMotor = nil
local originalShoulderC0 = nil
local armTween = nil

----------------------------------------------------------------
-- Remote Player State
----------------------------------------------------------------
local remotePlayerItems = {} -- {[userId] = {handle = Part, itemId = number}}

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local BOW_RAISE_ANGLE = 75
local TWEEN_UP = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_DOWN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local STUDS_PER_PIXEL = 3 / 16

local TOOL_ASSETS = {
    [BlockProperties.ToolType.SWORD] = "Sword",
    [BlockProperties.ToolType.AXE] = "Axe",
    [BlockProperties.ToolType.SHOVEL] = "Shovel",
    [BlockProperties.ToolType.PICKAXE] = "Pickaxe",
    [BlockProperties.ToolType.BOW] = "Bow",
    [BlockProperties.ToolType.ARROW] = "Arrow",
}

local TOOL_PX = {
    [BlockProperties.ToolType.SWORD] = {x = 14, y = 14},
    [BlockProperties.ToolType.AXE] = {x = 12, y = 14},
    [BlockProperties.ToolType.SHOVEL] = {x = 12, y = 12},
    [BlockProperties.ToolType.PICKAXE] = {x = 13, y = 13},
    [BlockProperties.ToolType.BOW] = {x = 14, y = 14},
    [BlockProperties.ToolType.ARROW] = {x = 14, y = 13},
}

local TOOL_GRIP = {
    [BlockProperties.ToolType.SWORD] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
    [BlockProperties.ToolType.AXE] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
    [BlockProperties.ToolType.SHOVEL] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
    [BlockProperties.ToolType.PICKAXE] = {pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0)},
    [BlockProperties.ToolType.BOW] = {pos = Vector3.new(0, 0.3, 0), rot = Vector3.new(225, 90, 0)},
    [BlockProperties.ToolType.ARROW] = {pos = Vector3.new(0, -0.1, -0.6), rot = Vector3.new(225, 90, 0)},
}

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function getToolsFolder()
    local folder = ReplicatedStorage:FindFirstChild("Tools")
    if folder then return folder end
    local assets = ReplicatedStorage:FindFirstChild("Assets")
    return assets and assets:FindFirstChild("Tools")
end

local function getMeshTemplate(name)
    local folder = getToolsFolder()
    if not folder then return nil end
    local template = folder:FindFirstChild(name)
    if not template then return nil end
    if template:IsA("MeshPart") then return template end
    return template:FindFirstChildWhichIsA("MeshPart", true)
end

local function getHand()
    local char = player.Character
    if not char then return nil end
    return char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
end

----------------------------------------------------------------
-- Bow Mesh Handling (Local Player Only)
----------------------------------------------------------------

local function destroyBowMeshParts()
    for key, part in pairs(bowMeshParts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
    bowMeshParts = {}
    currentBowStage = nil
end

local function createBowMeshPart(templateName, hand, gripCFrame, px, toolInfo)
    local mesh = getMeshTemplate(templateName)
    if not mesh then return nil end

    local part = mesh:Clone()
    part.Name = "BowHandle_" .. templateName
    part.Massless = true
    part.CanCollide = false
    part.CastShadow = false
    part.Anchored = false
    part.Transparency = 1 -- Start hidden

    if toolInfo and toolInfo.image and (not part.TextureID or part.TextureID == "") then
        part.TextureID = toolInfo.image
    end

    if px then
        local targetStuds = math.max(px.x, px.y) * STUDS_PER_PIXEL
        local maxDim = math.max(part.Size.X, part.Size.Y, part.Size.Z)
        if maxDim > 0 then
            part.Size = part.Size * (targetStuds / maxDim)
        end
    end

    part.Parent = hand

    local weld = Instance.new("Weld")
    weld.Name = "BowWeld"
    weld.Part0 = hand
    weld.Part1 = part
    weld.C0 = gripCFrame
    weld.Parent = part

    return part
end

local function createAllBowMeshParts(hand, toolItemId)
    destroyBowMeshParts()

    local grip = TOOL_GRIP[BlockProperties.ToolType.BOW]
    local gripCFrame = CFrame.new(grip.pos) * CFrame.Angles(math.rad(grip.rot.X), math.rad(grip.rot.Y), math.rad(grip.rot.Z))
    local px = TOOL_PX[BlockProperties.ToolType.BOW]
    local toolInfo = ToolConfig.GetToolInfo(toolItemId)

    bowMeshParts.idle = createBowMeshPart("Bow", hand, gripCFrame, px, toolInfo)
    bowMeshParts[0] = createBowMeshPart("Bow_pulling_0", hand, gripCFrame, px, toolInfo)
    bowMeshParts[1] = createBowMeshPart("Bow_pulling_1", hand, gripCFrame, px, toolInfo)
    bowMeshParts[2] = createBowMeshPart("Bow_pulling_2", hand, gripCFrame, px, toolInfo)

    if bowMeshParts.idle then
        bowMeshParts.idle.Transparency = 0
    end
    currentBowStage = "idle"
end

local function setBowMeshStage(stage)
    local targetKey = stage or "idle"
    if currentBowStage == targetKey then return end

    for key, part in pairs(bowMeshParts) do
        if part and part.Parent then
            part.Transparency = 1
        end
    end

    local targetPart = bowMeshParts[targetKey] or bowMeshParts.idle
    if targetPart and targetPart.Parent then
        targetPart.Transparency = 0
    end

    currentBowStage = targetKey
end

----------------------------------------------------------------
-- Arm Animation (Local Player Only)
----------------------------------------------------------------

local function getShoulderMotor()
    if shoulderMotor and shoulderMotor.Parent then return shoulderMotor end
    local char = player.Character
    if not char then return nil end

    local upperArm = char:FindFirstChild("RightUpperArm")
    if upperArm then
        local motor = upperArm:FindFirstChild("RightShoulder")
        if motor and motor:IsA("Motor6D") then
            shoulderMotor = motor
            originalShoulderC0 = motor.C0
            return motor
        end
    end

    local torso = char:FindFirstChild("Torso")
    if torso then
        local motor = torso:FindFirstChild("Right Shoulder")
        if motor and motor:IsA("Motor6D") then
            shoulderMotor = motor
            originalShoulderC0 = motor.C0
            return motor
        end
    end
    return nil
end

local function setArmRaised(raised)
    local motor = getShoulderMotor()
    if not motor or not originalShoulderC0 then return end

    if armTween then armTween:Cancel() end

    local angle = raised and BOW_RAISE_ANGLE or 0
    local tweenInfo = raised and TWEEN_UP or TWEEN_DOWN
    local target = originalShoulderC0 * CFrame.Angles(math.rad(angle), 0, 0)

    armTween = TweenService:Create(motor, tweenInfo, {C0 = target})
    armTween:Play()
end

local function resetArm()
    if armTween then armTween:Cancel(); armTween = nil end
    if shoulderMotor and originalShoulderC0 then
        shoulderMotor.C0 = originalShoulderC0
    end
    shoulderMotor = nil
    originalShoulderC0 = nil
end

----------------------------------------------------------------
-- Local Player Handle Management
----------------------------------------------------------------

local function destroyHandle()
	HeldItemRenderer.ClearItem(player.Character)
    resetArm()
    isBowCharging = false
    currentToolType = nil
    currentItemId = nil
    destroyBowMeshParts()
    if handleWeld then handleWeld:Destroy(); handleWeld = nil end
    if currentHandle then currentHandle:Destroy(); currentHandle = nil end
end

local function createToolHandle(toolItemId)
    local hand = getHand()
    if not hand then return end

    destroyHandle()

    local toolType = select(1, ToolConfig.GetBlockProps(toolItemId))
    if not toolType or not TOOL_ASSETS[toolType] then return end

    currentToolType = toolType
    currentItemId = toolItemId

    -- For bows, create all mesh variants for visibility toggling
    if toolType == BlockProperties.ToolType.BOW then
        createAllBowMeshParts(hand, toolItemId)
        currentHandle = bowMeshParts.idle
        return
    end

    -- For non-bow tools, use single mesh approach
    local assetName = TOOL_ASSETS[toolType]
    local mesh = getMeshTemplate(assetName)

    local part
    if mesh then
        part = mesh:Clone()
        part.Name = "ToolHandle"
        part.Massless = true
        part.CanCollide = false
        part.CastShadow = false
        part.Anchored = false

        local toolInfo = ToolConfig.GetToolInfo(toolItemId)
        if toolInfo and toolInfo.image and (not part.TextureID or part.TextureID == "") then
            part.TextureID = toolInfo.image
        end

        local px = TOOL_PX[toolType]
        if px then
            local targetStuds = math.max(px.x, px.y) * STUDS_PER_PIXEL
            local maxDim = math.max(part.Size.X, part.Size.Y, part.Size.Z)
            if maxDim > 0 then
                part.Size = part.Size * (targetStuds / maxDim)
            end
        end
    else
        part = Instance.new("Part")
        part.Name = "ToolHandle"
        part.Size = Vector3.new(0.2, 1.8, 0.2)
        part.Color = Color3.fromRGB(230, 230, 230)
        part.Material = Enum.Material.SmoothPlastic
        part.Massless = true
        part.CanCollide = false
        part.CastShadow = false
    end

    part.Parent = hand

    local weld = Instance.new("Weld")
    weld.Part0 = hand
    weld.Part1 = part
    local grip = TOOL_GRIP[toolType]
    if grip then
        weld.C0 = CFrame.new(grip.pos) * CFrame.Angles(math.rad(grip.rot.X), math.rad(grip.rot.Y), math.rad(grip.rot.Z))
    else
        weld.C0 = CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-90), 0, 0)
    end
    weld.Parent = part

    currentHandle = part
    handleWeld = weld
end

----------------------------------------------------------------
-- Local Player State Refresh
----------------------------------------------------------------

local function refresh()
    local isFirstPerson = GameState:Get("camera.isFirstPerson") == true

    -- Check for tool first
    local isHoldingTool = GameState:Get("voxelWorld.isHoldingTool") == true
    local toolItemId = GameState:Get("voxelWorld.selectedToolItemId")

    -- Check for block
    local isHoldingItem = GameState:Get("voxelWorld.isHoldingItem") == true
    local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
    local blockId = selectedBlock and selectedBlock.id

    -- Priority: Tool > Block
    if isHoldingTool and toolItemId and ToolConfig.IsTool(toolItemId) then
        local toolType = select(1, ToolConfig.GetBlockProps(toolItemId))

        -- Hide bow in first person (viewmodel handles it)
        if toolType == BlockProperties.ToolType.BOW and isFirstPerson then
            destroyHandle()
            return
        end

        -- Only recreate if item changed
        if toolItemId ~= currentItemId then
            createToolHandle(toolItemId)
        end
        return
    end

    -- Handle block
    if isHoldingItem and blockId and blockId > 0 then
        -- Only show in 3rd person (viewmodel handles 1st person)
        if isFirstPerson then
            destroyHandle()
            return
        end

		if blockId ~= currentItemId then
			destroyHandle()
			local char = player.Character
			if char then
				local handle = HeldItemRenderer.AttachItem(char, blockId)
				if handle then
					currentHandle = handle
					currentItemId = blockId
				end
			end
        end
        return
    end

    -- Nothing held
    destroyHandle()
end

local function onCharacterAdded(char)
    destroyHandle()
    task.spawn(function()
        local hand = char:WaitForChild("RightHand", 5) or char:WaitForChild("Right Arm", 5)
        if hand then
            task.wait(0.1)
            refresh()
        end
    end)
    char:GetPropertyChangedSignal("Parent"):Connect(function()
        if not char.Parent then destroyHandle() end
    end)
end

----------------------------------------------------------------
-- Remote Player Handling (Uses HeldItemRenderer)
----------------------------------------------------------------

local function getRemotePlayerCharacter(userId)
    local remotePlayer = Players:GetPlayerByUserId(userId)
    if not remotePlayer then return nil end
    return remotePlayer.Character
end

local function cleanupRemotePlayerItem(userId)
    local data = remotePlayerItems[userId]
    if not data then return end

    local char = getRemotePlayerCharacter(userId)
    if char then
        HeldItemRenderer.ClearItem(char)
    end

    remotePlayerItems[userId] = nil
end

local function createRemotePlayerItem(userId, itemId)
    -- Don't create for local player
    if userId == player.UserId then return end

    -- Validate item exists
    if not itemId or itemId == 0 then return end

    -- Clean up existing first
    cleanupRemotePlayerItem(userId)

    -- Get remote player's character
    local char = getRemotePlayerCharacter(userId)
    if not char then return end

    -- Use unified renderer
    local handle = HeldItemRenderer.AttachItem(char, itemId)

    if handle then
        remotePlayerItems[userId] = {
            handle = handle,
            itemId = itemId
        }
    end
end

-- Event handlers
local function onPlayerHeldItemChanged(data)
    if not data or not data.userId then return end
    if data.itemId and data.itemId > 0 then
        createRemotePlayerItem(data.userId, data.itemId)
    else
        cleanupRemotePlayerItem(data.userId)
    end
end

local function onPlayerToolEquipped(data)
    if not data or not data.userId or not data.itemId then return end
    createRemotePlayerItem(data.userId, data.itemId)
end

local function onPlayerToolUnequipped(data)
    if not data or not data.userId then return end
    cleanupRemotePlayerItem(data.userId)
end

local function onToolSync(data)
    if not data then return end
    for userIdStr, itemId in pairs(data) do
        local userId = tonumber(userIdStr)
        if userId and userId ~= player.UserId then
            createRemotePlayerItem(userId, itemId)
        end
    end
end

local function onPlayerRemoving(leavingPlayer)
    if leavingPlayer and leavingPlayer ~= player then
        cleanupRemotePlayerItem(leavingPlayer.UserId)
    end
end

local function onRemoteCharacterAdded(remotePlayer)
    if remotePlayer == player then return end

    local data = remotePlayerItems[remotePlayer.UserId]
    if data and data.itemId then
        local itemId = data.itemId
        task.spawn(function()
            local char = remotePlayer.Character
            if not char then return end
            local hand = char:WaitForChild("RightHand", 5) or char:WaitForChild("Right Arm", 5)
            if hand then
                task.wait(0.1)
                createRemotePlayerItem(remotePlayer.UserId, itemId)
            end
        end)
    end
end

local function setupRemotePlayerTracking(remotePlayer)
    if remotePlayer == player then return end
    remotePlayer.CharacterAdded:Connect(function()
        onRemoteCharacterAdded(remotePlayer)
    end)
end

local function initializeRemoteItems()
    -- Register event listeners (support both old tool events and new unified events)
    EventManager:RegisterEvent("PlayerToolEquipped", onPlayerToolEquipped)
    EventManager:RegisterEvent("PlayerToolUnequipped", onPlayerToolUnequipped)
    EventManager:RegisterEvent("ToolSync", onToolSync)

    -- Future unified events (can be added later)
    EventManager:RegisterEvent("PlayerHeldItemChanged", onPlayerHeldItemChanged)

    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, p in ipairs(Players:GetPlayers()) do
        setupRemotePlayerTracking(p)
    end
    Players.PlayerAdded:Connect(setupRemotePlayerTracking)

    -- Request sync for late joiners
    task.delay(0.5, function()
        EventManager:SendToServer("RequestToolSync")
    end)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function controller:Initialize()
    -- Local player state changes
    GameState:OnPropertyChanged("voxelWorld.isHoldingTool", refresh)
    GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", refresh)
    GameState:OnPropertyChanged("voxelWorld.isHoldingItem", refresh)
    GameState:OnPropertyChanged("voxelWorld.selectedBlock", refresh)
    GameState:OnPropertyChanged("camera.isFirstPerson", refresh)

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then onCharacterAdded(player.Character) end

    -- Remote player handling
    initializeRemoteItems()
end

function controller:SetBowPullStage(stage)
    local isFirstPerson = GameState:Get("camera.isFirstPerson") == true
    if isFirstPerson then return end

    local isCharging = stage ~= nil
    setBowMeshStage(stage)

    if isCharging ~= isBowCharging then
        isBowCharging = isCharging
        setArmRaised(isCharging)
    end
end

function controller:Cleanup()
    destroyHandle()
    for userId in pairs(remotePlayerItems) do
        cleanupRemotePlayerItem(userId)
    end
end

return controller
