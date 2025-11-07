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
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)

local controller = {}

local player = Players.LocalPlayer
local currentHandle -- BasePart
local handleWeld -- Weld
local characterConn -- RBXScriptConnection
local propertyConns = {}

-- No presets needed; fixed orientation for Diamond Sword

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

-- Tool visual config
local STUDS_PER_PIXEL = 3 / 16
local TOOL_ASSET_NAME_BY_TYPE = {
    [BlockProperties.ToolType.SWORD] = "Sword",
    [BlockProperties.ToolType.AXE] = "Axe",
    [BlockProperties.ToolType.SHOVEL] = "Shovel",
    [BlockProperties.ToolType.PICKAXE] = "Pickaxe",
}

local TOOL_PX_BY_TYPE = {
    [BlockProperties.ToolType.SWORD] = {x = 14, y = 14},
    [BlockProperties.ToolType.AXE] = {x = 12, y = 14},
    [BlockProperties.ToolType.SHOVEL] = {x = 12, y = 12},
    [BlockProperties.ToolType.PICKAXE] = {x = 13, y = 13},
}

-- Default per-type offsets (tuned sword carried over; others share baseline and can be tweaked later)
local TOOL_C0_BY_TYPE = {
    [BlockProperties.ToolType.SWORD] = { pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0) },
    [BlockProperties.ToolType.AXE] = { pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0) },
    [BlockProperties.ToolType.SHOVEL] = { pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0) },
    [BlockProperties.ToolType.PICKAXE] = { pos = Vector3.new(0, -0.15, -1.5), rot = Vector3.new(225, 90, 0) },
}

local function cframeFromPosRotDeg(pos: Vector3, rotDeg: Vector3)
    return CFrame.new(pos) * CFrame.Angles(math.rad(rotDeg.X), math.rad(rotDeg.Y), math.rad(rotDeg.Z))
end

local function scaleMeshToPixels(part: BasePart, pxX: number, pxY: number)
    local longestPx = math.max(pxX or 0, pxY or 0)
    if longestPx <= 0 then return end
    local targetStuds = longestPx * STUDS_PER_PIXEL
    local size = part.Size
    local maxDim = math.max(size.X, size.Y, size.Z)
    if maxDim > 0 then
        local scale = targetStuds / maxDim
        part.Size = Vector3.new(size.X * scale, size.Y * scale, size.Z * scale)
    end
end

local function createPlaceholder(toolItemId)
    local hand = findHand(player.Character)
    if not hand then return end

    destroyHandle()

    local part

    -- Determine tool type from itemId
    local toolType
    do
        local tType, _tier = ToolConfig.GetBlockProps(toolItemId)
        toolType = tType
    end

    -- Clone appropriate MeshPart from Assets when a known tool is equipped
    if toolType and TOOL_ASSET_NAME_BY_TYPE[toolType] then
        local assetName = TOOL_ASSET_NAME_BY_TYPE[toolType]
        local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
        local template = assetsFolder and assetsFolder:FindFirstChild(assetName)
        if template and template:IsA("BasePart") then
            part = template:Clone()
            part.Name = "ToolHandle_" .. tostring(toolType)
            part.Massless = true
            part.CanCollide = false
            part.CastShadow = false
            pcall(function()
                part.Anchored = false
            end)

            -- Set texture from ToolConfig image if available
            local toolInfo = ToolConfig.GetToolInfo(toolItemId)
            local textureId = toolInfo and toolInfo.image
            if textureId and part:IsA("MeshPart") then
                pcall(function()
                    part.TextureID = textureId
                end)
            end

            -- True-to-scale using declared pixel dimensions for this type
            local px = TOOL_PX_BY_TYPE[toolType]
            if px then
                scaleMeshToPixels(part, px.x, px.y)
            end
        end
    end

    if not part then
        part = Instance.new("Part")
        part.Name = "ToolPlaceholderHandle"
        part.Size = Vector3.new(0.2, 1.8, 0.2)
        part.Color = Color3.fromRGB(230, 230, 230)
        part.Material = Enum.Material.SmoothPlastic
        part.Massless = true
        part.CanCollide = false
        part.CastShadow = false
    end

    part.Parent = hand

    -- Position relative to hand via Weld offset (C0)
    local weld = Instance.new("Weld")
    weld.Part0 = hand
    weld.Part1 = part
    if toolType and TOOL_C0_BY_TYPE[toolType] then
        local cfg = TOOL_C0_BY_TYPE[toolType]
        weld.C0 = cframeFromPosRotDeg(cfg.pos, cfg.rot)
    else
        weld.C0 = CFrame.new(0, 0, -0.9) * CFrame.Angles(math.rad(-90), 0, 0)
    end
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

    -- No hotkeys; fixed orientation applied on equip

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


