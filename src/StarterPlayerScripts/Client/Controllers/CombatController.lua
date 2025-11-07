--[[
	CombatController.lua
	Client-side PvP controller: repeats sword swings while LMB is held, detects targets, and requests hits.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ToolAnimationController = require(script.Parent.ToolAnimationController)

local player = Players.LocalPlayer
local CombatController = {}

local isHolding = false
local lastSwing = 0

-- No longer gating melee by sword; any item or empty hand can attack

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

local function findMobEntityId()
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
			local id = model:GetAttribute("MobEntityId")
			if id then
				return id
			end
		end
	end
	return nil
end

function CombatController:Initialize()
    -- Input: track LMB hold state for repeated swings
    UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isHolding = true
        end
    end)
    UserInputService.InputEnded:Connect(function(input, gpe)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            isHolding = false
        end
    end)

    -- We send hits on swing cadence while LMB is held; server validates reach/FOV
    RunService.Heartbeat:Connect(function()
        if not isHolding then return end
        local now = os.clock()
        if (now - lastSwing) >= (CombatConfig.SWING_COOLDOWN or 0.35) then
            lastSwing = now
            -- Attempt to hit player first, then mob; play swing either way
            local target = findTarget()
            if target then
                ToolAnimationController:PlaySwing()
                EventManager:SendToServer("PlayerMeleeHit", {
                    targetUserId = target.UserId,
                    swingTimeMs = math.floor(now * 1000)
                })
            else
                local mobId = findMobEntityId()
                if mobId then
                    ToolAnimationController:PlaySwing()
                    EventManager:SendToServer("AttackMob", {
                        entityId = mobId
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


