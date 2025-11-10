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

-- Try to locate the Tools container even if it's a Model or differently named parent
local function findToolsContainer(assetsFolder: Instance)
	if not assetsFolder then return nil end
	-- First, prefer a direct child named "Tools"
	local direct = assetsFolder:FindFirstChild("Tools")
	if direct then return direct end
	-- Otherwise, scan for a child that contains tool-named children
	local expectedNames = {
		[TOOL_ASSET_NAME_BY_TYPE[BlockProperties.ToolType.SWORD]] = true,
		[TOOL_ASSET_NAME_BY_TYPE[BlockProperties.ToolType.AXE]] = true,
		[TOOL_ASSET_NAME_BY_TYPE[BlockProperties.ToolType.SHOVEL]] = true,
		[TOOL_ASSET_NAME_BY_TYPE[BlockProperties.ToolType.PICKAXE]] = true,
	}
	for _, child in ipairs(assetsFolder:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			for name, _ in pairs(expectedNames) do
				if child:FindFirstChild(name) then
					return child
				end
			end
		end
	end
	return nil
end

-- Given a template which may be a MeshPart, Model, or Folder, find a MeshPart to clone
local function findMeshPartFromTemplate(template: Instance)
	if not template then return nil end
	if template:IsA("MeshPart") then
		return template
	end
	-- Search descendants for the first MeshPart (common when template is a Model)
	local mesh = template:FindFirstChildWhichIsA("MeshPart", true)
	return mesh
end

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

	-- Clone appropriate MeshPart from ReplicatedStorage.Tools (fallback to Assets.Tools) when a known tool is equipped
    if toolType and TOOL_ASSET_NAME_BY_TYPE[toolType] then
        local assetName = TOOL_ASSET_NAME_BY_TYPE[toolType]
		-- Prefer ReplicatedStorage.Tools directly
		local toolsFolder = ReplicatedStorage:FindFirstChild("Tools")
		-- Fallback: ReplicatedStorage.Assets.Tools or auto-detected tools container under Assets
		if not toolsFolder then
			local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
			toolsFolder = assetsFolder and (assetsFolder:FindFirstChild("Tools") or findToolsContainer(assetsFolder)) or nil
		end
		local template = toolsFolder and toolsFolder:FindFirstChild(assetName)

        -- Specifically check for MeshPart (the expected asset type)
		if template then
			local mesh = findMeshPartFromTemplate(template)
			if mesh then
				part = mesh:Clone()
			end
		end

		if part and part:IsA("MeshPart") then
            part.Name = "ToolHandle_" .. tostring(toolType)

            -- Configure MeshPart properties
            part.Massless = true
            part.CanCollide = false
            part.CastShadow = false
            pcall(function()
                part.Anchored = false
            end)

            -- Set texture from ToolConfig image if available
            local toolInfo = ToolConfig.GetToolInfo(toolItemId)
            local textureId = toolInfo and toolInfo.image
			-- Do not override existing TextureID on the template if already present
			local hasExistingTexture = false
			pcall(function()
				local currentTex = part.TextureID
				hasExistingTexture = (currentTex ~= nil and tostring(currentTex) ~= "")
			end)
			if textureId and (not hasExistingTexture) then
                pcall(function()
                    part.TextureID = textureId
                end)
            end

            -- True-to-scale using declared pixel dimensions for this type
            local px = TOOL_PX_BY_TYPE[toolType]
            if px then
                scaleMeshToPixels(part, px.x, px.y)
            end
		else
			if template then
				warn("ToolVisualController: Could not find MeshPart inside asset '" .. assetName .. "' (found type: " .. template.ClassName .. ")")
			elseif toolsFolder then
				warn("ToolVisualController: Tool asset '" .. assetName .. "' not found in ReplicatedStorage.Tools (or fallback Assets.Tools)")
			else
				warn("ToolVisualController: 'Tools' folder not found in ReplicatedStorage (or fallback under ReplicatedStorage.Assets)")
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
    -- Clean up old handle when character respawns
    destroyHandle()

    -- Wait for character to fully load before trying to attach tool
    task.spawn(function()
        -- Wait for RightHand or Right Arm to exist
        local hand = char:WaitForChild("RightHand", 5) or char:WaitForChild("Right Arm", 5)
        if hand then
            -- Small delay to ensure character is fully loaded
            task.wait(0.1)
            onToolStateChanged()
        end
    end)

    -- Clean up when character is removed
    char:GetPropertyChangedSignal("Parent"):Connect(function()
        if not char.Parent then
            destroyHandle()
        end
    end)
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


