--[[
	CombatController.lua
	Client-side PvP controller: repeats sword swings while LMB is held, detects targets, and requests hits.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ToolAnimationController = require(script.Parent.ToolAnimationController)

local player = Players.LocalPlayer
local CombatController = {}

local isHolding = false
local lastSwing = 0

local function hasSwordEquipped()
    local GameState = require(script.Parent.Parent.Managers.GameState)
    local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
    -- Prefer explicit equip state set by VoxelHotbar
    local equippedToolId = GameState:Get("voxelWorld.selectedToolItemId")
    if equippedToolId and ToolConfig.IsTool(equippedToolId) then
        local info = ToolConfig.GetToolInfo(equippedToolId)
        return info and info.toolType == BlockProperties.ToolType.SWORD
    end
    return false
end

local function findTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local origin = camera.CFrame.Position
    local dir = camera.CFrame.LookVector
    local reach = CombatConfig.REACH_STUDS or 10
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
    local char = player.Character
    if char then rayParams.FilterDescendantsInstances = {char} end
    local result = workspace:Raycast(origin, dir * reach, rayParams)
    if result and result.Instance then
        local model = result.Instance:FindFirstAncestorOfClass("Model")
        if model then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local plr = Players:GetPlayerFromCharacter(model)
            if hum and plr and plr ~= player and hum.Health > 0 then
                return plr
            end
        end
    end
    return nil
end

function CombatController:Initialize()
    -- Input handled by BlockInteraction for mining; we only send hits on swing cadence
    RunService.Heartbeat:Connect(function()
        if not isHolding then return end
        local now = os.clock()
        if (now - lastSwing) >= (CombatConfig.SWING_COOLDOWN or 0.35) then
            lastSwing = now
            -- Only try to hit if sword is equipped
            if hasSwordEquipped() then
                local target = findTarget()
                if target then
                    -- Play local swing animation when attempting a hit
                    ToolAnimationController:PlaySwing()
                    EventManager:SendToServer("PlayerMeleeHit", {
                        targetUserId = target.UserId,
                        swingTimeMs = math.floor(now * 1000)
                    })
                end
            end
        end
    end)
end

function CombatController:SetHolding(value: boolean)
    isHolding = value and true or false
end

return CombatController


