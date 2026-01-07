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
local BowConfig = require(ReplicatedStorage.Configs.BowConfig)
local GameState = require(script.Parent.Parent.Managers.GameState)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)

local player = Players.LocalPlayer
local CombatController = {}

local isHolding = false
local lastSwing = 0

-- Check if bow is currently equipped (bow only shoots, no melee)
local function isBowEquipped()
    local itemId = GameState:Get("voxelWorld.selectedToolItemId")
    return itemId == BowConfig.BOW_ITEM_ID
end

-- No longer gating melee by sword; any item or empty hand can attack (except bow)

-- Compute aim ray based on camera mode (1st person vs 3rd person)
local function computeAimRay()
    local camera = workspace.CurrentCamera
    if not camera then return nil, nil end

    local isFirstPerson = GameState:Get("camera.isFirstPerson")
    local origin, dir

    if isFirstPerson then
        -- First person: raycast from camera center
        origin = camera.CFrame.Position
        dir = camera.CFrame.LookVector
    else
        -- Third person: raycast through mouse position
        local mousePos = UserInputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
        origin = ray.Origin
        dir = ray.Direction
    end

    return origin, dir
end

local function findTarget()
    local camera = workspace.CurrentCamera
    if not camera then return nil end

    local origin, dir = computeAimRay()
    if not origin or not dir then return nil end

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

	local origin, dir = computeAimRay()
	if not origin or not dir then return nil end

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
        -- Bow only shoots arrows, no melee (Minecraft-style)
        if isBowEquipped() then return end
        -- Block combat when UI is open (inventory, chest, worlds, minion)
        if UIVisibilityManager:GetMode() ~= "gameplay" then return end
        if GameState:Get("voxelWorld.inventoryOpen") then return end

        local now = os.clock()
        if (now - lastSwing) >= (CombatConfig.SWING_COOLDOWN or 0.35) then
            lastSwing = now

            -- ALWAYS play the swing/punch animation when attacking (empty hand or with weapon)
            ToolAnimationController:PlaySwing()

            -- Then check for targets and send hit events
            local target = findTarget()
            if target then
                EventManager:SendToServer("PlayerMeleeHit", {
                    targetUserId = target.UserId,
                    swingTimeMs = math.floor(now * 1000)
                })
            else
                local mobId = findMobEntityId()
                if mobId then
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


