--[[
    ToolVisualController.lua
    Renders held items on local and remote players using HeldItemRenderer.
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
local currentItemId = nil
local isBowCharging = false

-- Arm animation state
local shoulderMotor = nil
local originalShoulderC0 = nil
local armTween = nil

----------------------------------------------------------------
-- Remote Player State
----------------------------------------------------------------
local remotePlayerItems = {} -- {[userId] = itemId}

----------------------------------------------------------------
-- Config
----------------------------------------------------------------
local BOW_RAISE_ANGLE = 75
local TWEEN_UP = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_DOWN = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

----------------------------------------------------------------
-- Arm Animation (Local Player Only - for bow)
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

local function clearLocalItem()
    local char = player.Character
    if char then
        HeldItemRenderer.ClearItem(char)
    end
    resetArm()
    isBowCharging = false
    currentItemId = nil
end

local function attachLocalItem(itemId)
    local char = player.Character
    if not char then return end

    -- Check if same item already attached
    if itemId == currentItemId then return end

    clearLocalItem()

    if not itemId or itemId == 0 then return end

    local handle = HeldItemRenderer.AttachItem(char, itemId)
    if handle then
        currentItemId = itemId
    end
end

----------------------------------------------------------------
-- Local Player State Refresh
----------------------------------------------------------------

local function refresh()
    local isFirstPerson = GameState:Get("camera.isFirstPerson") == true

    -- Check for tool first
    local isHoldingTool = GameState:Get("voxelWorld.isHoldingTool") == true
    local toolItemId = GameState:Get("voxelWorld.selectedToolItemId")

    -- Check for block/item
    local isHoldingItem = GameState:Get("voxelWorld.isHoldingItem") == true
    local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
    local blockId = selectedBlock and selectedBlock.id

    -- In first person, viewmodel handles rendering
    if isFirstPerson then
        clearLocalItem()
        return
    end

    -- Priority: Tool > Block
    if isHoldingTool and toolItemId and toolItemId > 0 then
        attachLocalItem(toolItemId)
        return
    end

    if isHoldingItem and blockId and blockId > 0 then
        attachLocalItem(blockId)
        return
    end

    -- Nothing held
    clearLocalItem()
end

local function onCharacterAdded(char)
    clearLocalItem()
    task.spawn(function()
        local hand = char:WaitForChild("RightHand", 5) or char:WaitForChild("Right Arm", 5)
        if hand then
            task.wait(0.1)
            refresh()
        end
    end)
    char:GetPropertyChangedSignal("Parent"):Connect(function()
        if not char.Parent then clearLocalItem() end
    end)
end

----------------------------------------------------------------
-- Remote Player Handling
----------------------------------------------------------------

local function getRemotePlayerCharacter(userId)
    local remotePlayer = Players:GetPlayerByUserId(userId)
    if not remotePlayer then return nil end
    return remotePlayer.Character
end

local function cleanupRemotePlayerItem(userId)
    local char = getRemotePlayerCharacter(userId)
    if char then
        HeldItemRenderer.ClearItem(char)
    end
    remotePlayerItems[userId] = nil
end

local function createRemotePlayerItem(userId, itemId)
    if userId == player.UserId then return end
    if not itemId or itemId == 0 then
        cleanupRemotePlayerItem(userId)
        return
    end

    -- Check if same item
    if remotePlayerItems[userId] == itemId then return end

    cleanupRemotePlayerItem(userId)

    local char = getRemotePlayerCharacter(userId)
    if not char then return end

    local handle = HeldItemRenderer.AttachItem(char, itemId)
    if handle then
        remotePlayerItems[userId] = itemId
    end
end

local function onPlayerHeldItemChanged(data)
    if not data or not data.userId then return end
    createRemotePlayerItem(data.userId, data.itemId)
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
    local itemId = remotePlayerItems[remotePlayer.UserId]
    if itemId then
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
    EventManager:RegisterEvent("PlayerToolEquipped", onPlayerToolEquipped)
    EventManager:RegisterEvent("PlayerToolUnequipped", onPlayerToolUnequipped)
    EventManager:RegisterEvent("ToolSync", onToolSync)
    EventManager:RegisterEvent("PlayerHeldItemChanged", onPlayerHeldItemChanged)

    Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, p in ipairs(Players:GetPlayers()) do
        setupRemotePlayerTracking(p)
    end
    Players.PlayerAdded:Connect(setupRemotePlayerTracking)

    task.delay(0.5, function()
        EventManager:SendToServer("RequestToolSync")
    end)
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function controller:Initialize()
    GameState:OnPropertyChanged("voxelWorld.isHoldingTool", refresh)
    GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", refresh)
    GameState:OnPropertyChanged("voxelWorld.isHoldingItem", refresh)
    GameState:OnPropertyChanged("voxelWorld.selectedBlock", refresh)
    GameState:OnPropertyChanged("camera.isFirstPerson", refresh)

    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then onCharacterAdded(player.Character) end

    initializeRemoteItems()
end

function controller:SetBowPullStage(stage)
    local isFirstPerson = GameState:Get("camera.isFirstPerson") == true
    if isFirstPerson then return end

    local isCharging = stage ~= nil
    if isCharging ~= isBowCharging then
        isBowCharging = isCharging
        setArmRaised(isCharging)
    end
end

function controller:Cleanup()
    clearLocalItem()
    for userId in pairs(remotePlayerItems) do
        cleanupRemotePlayerItem(userId)
    end
end

return controller
