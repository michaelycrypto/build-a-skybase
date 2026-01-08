--[[
    BowController.lua
    Client-side bow charge and fire. Sends BowShoot to server.
]]

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)
local ToolVisualController = require(script.Parent.ToolVisualController)
local InputService = require(script.Parent.Parent.Input.InputService)

local controller = {}
local player = Players.LocalPlayer

-- State
local isEquipped = false
local isDrawing = false
local drawStart = nil
local currentStage = nil
local stageThreads = {}
local lastShotTime = 0

-- Cached shoot sound for immediate playback
local shootSound = nil

-- Reference to inventory manager (set during initialization)
local inventoryManager = nil

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------

local function cancelStageThreads()
    for _, thread in ipairs(stageThreads) do
        task.cancel(thread)
    end
    stageThreads = {}
end

local function setStage(stage)
    if stage == currentStage then return end
    currentStage = stage
    ToolVisualController:SetBowPullStage(stage)
    GameState:Set("voxelWorld.bowPullStage", stage, true)
end

local function resetDraw()
    isDrawing = false
    drawStart = nil
    cancelStageThreads()
    setStage(nil)
end

local function getElapsed()
    if not drawStart then return 0 end
    return os.clock() - drawStart
end

local function hasArrows()
    if not inventoryManager then return false end
    local arrowCount = inventoryManager:CountItem(BowConfig.ARROW_ITEM_ID)
    return arrowCount > 0
end

local function playShootSound()
    if not BowConfig.SHOOT_SOUNDS or #BowConfig.SHOOT_SOUNDS == 0 then return end

    local soundId = BowConfig.SHOOT_SOUNDS[math.random(1, #BowConfig.SHOOT_SOUNDS)]

    -- Create or reuse sound instance
    if not shootSound or not shootSound.Parent then
        shootSound = Instance.new("Sound")
        shootSound.Name = "BowShootSound"
        shootSound.Parent = SoundService
    end

    shootSound.SoundId = soundId
    shootSound.Volume = BowConfig.SHOOT_SOUND_VOLUME or 0.7
    shootSound:Play()
end

local function computeAimDirection()
    local camera = Workspace.CurrentCamera
    if not camera then return nil end

    local character = player.Character

    -- Get upper torso position to compute accurate aim direction (like Minecraft)
    local shootPos
    local isFirstPerson = GameState:Get("camera.isFirstPerson")
    if isFirstPerson or not character then
        shootPos = camera.CFrame.Position
    else
        -- Use UpperTorso (R15) or Torso (R6)
        local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
        if upperTorso then
            shootPos = upperTorso.Position
        else
            local hrp = character:FindFirstChild("HumanoidRootPart")
            if hrp then
                shootPos = hrp.Position + Vector3.new(0, 0.5, 0)
            else
                shootPos = camera.CFrame.Position
            end
        end
    end

    local mouse = player:GetMouse()
    local target = mouse and mouse.Hit and mouse.Hit.Position
    if not target then
        target = shootPos + camera.CFrame.LookVector * 500
    end

    local direction = (target - shootPos)
    if direction.Magnitude < 0.01 then
        return camera.CFrame.LookVector.Unit
    end
    return direction.Unit
end

local function sendShot()
    local direction = computeAimDirection()
    if not direction then return end

    local slotIndex = GameState:Get("voxelWorld.selectedToolSlotIndex") or GameState:Get("voxelWorld.selectedSlot")
    if typeof(slotIndex) ~= "number" then return end
    if not isEquipped then return end

    -- Check for arrows before playing sound or shooting
    if not hasArrows() then
        return
    end

    -- Play shoot sound immediately for responsiveness
    playShootSound()

    EventManager:SendToServer("BowShoot", {
        direction = direction,
        charge = getElapsed(),
        slotIndex = slotIndex,
    })
end

----------------------------------------------------------------
-- Input
----------------------------------------------------------------

local function startDraw()
    if isDrawing then return end
    if not isEquipped then return end

    -- Block shooting when UI is open (inventory, chest, worlds, minion, etc.)
    if InputService:IsGameplayBlocked() then return end

    -- Don't allow drawing if player has no arrows
    if not hasArrows() then return end

    isDrawing = true
    drawStart = os.clock()
    cancelStageThreads()

    -- Get stage times from config
    local times = BowConfig.DRAW_STAGE_TIMES or {0, 0.2, 0.6}

    -- Schedule stage transitions
    setStage(0)

    table.insert(stageThreads, task.delay(times[2] or 0.2, function()
        if isDrawing then setStage(1) end
    end))

    table.insert(stageThreads, task.delay(times[3] or 0.6, function()
        if isDrawing then setStage(2) end
    end))
end

local function endDraw()
    if not isDrawing then return end

    local elapsed = getElapsed()
    local now = os.clock()
    local cooldown = BowConfig.FIRE_COOLDOWN or 0

    if elapsed >= BowConfig.MIN_CHARGE_TIME and (now - lastShotTime) >= cooldown then
        lastShotTime = now
        sendShot()
    end

    resetDraw()
end

local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    startDraw()
end

local function onInputEnded(input)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    endDraw()
end

----------------------------------------------------------------
-- Equip State
----------------------------------------------------------------

local function refreshEquipState()
    local holding = GameState:Get("voxelWorld.isHoldingTool") == true
    local itemId = GameState:Get("voxelWorld.selectedToolItemId")
    isEquipped = holding and itemId == BowConfig.BOW_ITEM_ID

    if not isEquipped then
        resetDraw()
    end
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function controller:Initialize(invManager)
    -- Store reference to inventory manager for arrow checking
    inventoryManager = invManager

    InputService.InputBegan:Connect(onInputBegan)
    InputService.InputEnded:Connect(onInputEnded)

    GameState:OnPropertyChanged("voxelWorld.isHoldingTool", refreshEquipState)
    GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", refreshEquipState)

    player.CharacterAdded:Connect(resetDraw)

    refreshEquipState()
end

function controller:Cleanup()
    resetDraw()
end

return controller
