--[[
    ToolVisualController.lua
    Attaches a simple placeholder handle to the player's character when a tool is equipped.
    - R15: weld to RightHand
    - R6: weld to Right Arm
    Listens to GameState paths set by VoxelHotbar.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)

local controller = {}

local player = Players.LocalPlayer
local currentHandle -- BasePart
local handleWeld -- WeldConstraint
local characterConn -- RBXScriptConnection
local propertyConns = {}

local function findHand(character)
    if not character then return nil end
    local hand = character:FindFirstChild("RightHand")
    if hand and hand:IsA("BasePart") then return hand end
    local r6 = character:FindFirstChild("Right Arm")
    if r6 and r6:IsA("BasePart") then return r6 end
    return nil
end

local function destroyHandle()
    if handleWeld then
        handleWeld:Destroy()
        handleWeld = nil
    end
    if currentHandle then
        currentHandle:Destroy()
        currentHandle = nil
    end
end

local function createPlaceholder(toolItemId)
    local hand = findHand(player.Character)
    if not hand then return end

    destroyHandle()

    local part = Instance.new("Part")
    part.Name = "ToolPlaceholderHandle"
    part.Size = Vector3.new(0.2, 1.8, 0.2)
    part.Color = Color3.fromRGB(230, 230, 230)
    part.Material = Enum.Material.SmoothPlastic
    part.Massless = true
    part.CanCollide = false
    part.CastShadow = false
    part.Parent = hand

    -- Position relative to hand: snap in front of the palm and point forward
    part.CFrame = hand.CFrame * CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-90), 0, 0)

    local weld = Instance.new("WeldConstraint")
    weld.Part0 = hand
    weld.Part1 = part
    weld.Parent = part

    currentHandle = part
    handleWeld = weld
end

local function onToolStateChanged()
    local isHolding = GameState:Get("voxelWorld.isHoldingTool") == true
    local itemId = GameState:Get("voxelWorld.selectedToolItemId")
    if not isHolding or not itemId or not ToolConfig.IsTool(itemId) then
        destroyHandle()
        return
    end
    createPlaceholder(itemId)
end

local function onCharacterAdded(char)
    -- Reattach handle if tool was selected during respawn
    task.defer(onToolStateChanged)
end

function controller:Initialize()
    -- Listen to equip state
    table.insert(propertyConns, GameState:OnPropertyChanged("voxelWorld.isHoldingTool", function()
        onToolStateChanged()
    end))
    table.insert(propertyConns, GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", function()
        onToolStateChanged()
    end))

    -- Character lifecycle
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then onCharacterAdded(player.Character) end
end

function controller:Cleanup()
    destroyHandle()
    for _, conn in ipairs(propertyConns) do
        pcall(function() conn() end)
    end
    propertyConns = {}
end

return controller


