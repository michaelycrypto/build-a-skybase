--[[
	ViewmodelController.lua
	Client-side first-person viewmodel (hand/held item) rendered under the camera.
	- Builds a local-only held object based on hotbar selection
	- Shows only in first-person; hides in third-person
	- Sway while walking and brief swing pulse on interactions
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureApplicator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureApplicator)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)

local player = Players.LocalPlayer

local Controller = {}

-- Runtime
local currentInstance -- BasePart | Model (held viewmodel)
local currentItemId -- number | nil
local isFirstPerson = false
local holdingTool = false
local holdingItem = false
local isFlatItem = false
local rsConn -- RenderStepped
local camChangedConns = {}
local inputConns = {}
local respawnConn

-- Animation state
local timeAcc = 0
local swingTimer = 0
local SWING_DURATION = 0.22

local function destroyCurrent()
	if currentInstance then
		currentInstance:Destroy()
		currentInstance = nil
	end
end

local function clearConns(list)
	for _, c in ipairs(list) do
		pcall(function()
			c:Disconnect()
		end)
	end
	while #list > 0 do table.remove(list) end
end

local function shouldShow()
    -- In first person we always show a viewmodel (tool/block/arm)
    return isFirstPerson
end

local function buildBlockModel(itemId)
	local def = BlockRegistry.Blocks[itemId]
	if not def then return nil end
    -- Specialized shapes for more accurate preview
    if def.stairShape then
        -- Create simple two-piece stair (bottom slab + top step)
        local model = Instance.new("Model")
        model.Name = "StairVM"
        local base = Instance.new("Part")
        base.Name = "BottomSlab"
        base.Size = Vector3.new(0.9, 0.45, 0.9)
        base.Anchored = true
        base.CanCollide = false
        base.Massless = true
        base.CastShadow = false
        base.Material = Enum.Material.SmoothPlastic
        base.Color = def.color or Color3.fromRGB(200, 200, 200)
        base.CFrame = CFrame.new(0, -0.225, 0)
        TextureApplicator.ApplyTexturesToPart(base, def.textures, base.Size)
        base.Parent = model

        local step = Instance.new("Part")
        step.Name = "TopStep"
        step.Size = Vector3.new(0.9, 0.45, 0.45)
        step.Anchored = true
        step.CanCollide = false
        step.Massless = true
        step.CastShadow = false
        step.Material = Enum.Material.SmoothPlastic
        step.Color = def.color or Color3.fromRGB(200, 200, 200)
        step.CFrame = CFrame.new(0, 0.225, -0.225)
        TextureApplicator.ApplyTexturesToPart(step, def.textures, step.Size)
        step.Parent = model

        return model
    elseif def.fenceShape then
        -- Create fence: two posts + two rails (simple)
        local model = Instance.new("Model")
        model.Name = "FenceVM"
        local postWidth = 0.25
        local railThick = 0.18
        local function makePost(x)
            local p = Instance.new("Part")
            p.Name = "Post"
            p.Size = Vector3.new(postWidth, 1.0, postWidth)
            p.CFrame = CFrame.new(x, 0, 0)
            p.Anchored = true
            p.CanCollide = false
            p.Massless = true
            p.CastShadow = false
            p.Material = Enum.Material.SmoothPlastic
            p.Color = def.color or Color3.fromRGB(200, 200, 200)
            TextureApplicator.ApplyTexturesToPart(p, def.textures, p.Size)
            p.Parent = model
            return p
        end
        local sep = 0.35
        makePost(-sep)
        makePost(sep)

        local span = (sep * 2) - postWidth
        local function makeRail(y)
            local r = Instance.new("Part")
            r.Name = "Rail"
            r.Size = Vector3.new(span, railThick, railThick)
            r.CFrame = CFrame.new(0, y - 0.5, 0)
            r.Anchored = true
            r.CanCollide = false
            r.Massless = true
            r.CastShadow = false
            r.Material = Enum.Material.SmoothPlastic
            r.Color = def.color or Color3.fromRGB(200, 200, 200)
            TextureApplicator.ApplyTexturesToPart(r, def.textures, r.Size)
            r.Parent = model
            return r
        end
        makeRail(0.25)
        makeRail(0.75)
        return model
    else
        local part = Instance.new("Part")
        part.Size = Vector3.new(0.7, 0.7, 0.7)
        part.Anchored = true
        part.CanCollide = false
        part.Massless = true
        part.CastShadow = false
        part.Material = Enum.Material.SmoothPlastic
        part.Color = def.color or Color3.fromRGB(200, 200, 200)
        TextureApplicator.ApplyTexturesToPart(part, def.textures, part.Size)
        return part
    end
end

local function buildFlatItem(itemId)
	local info = ToolConfig.GetToolInfo(itemId)
	local image = info and info.image
	if not image then return nil end
    local p = Instance.new("Part")
	p.Name = "ItemCard"
	p.Size = Vector3.new(1.2, 1.2, 0.05)
	p.Anchored = true
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
    p.Transparency = 1
	-- Front
	local s1 = Instance.new("SurfaceGui")
	s1.Face = Enum.NormalId.Front
	s1.LightInfluence = 1
	s1.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	s1.PixelsPerStud = 64
    s1.AlwaysOnTop = true
	local il1 = Instance.new("ImageLabel")
	il1.BackgroundTransparency = 1
	il1.Size = UDim2.fromScale(1, 1)
	il1.Image = image
	il1.Parent = s1
	s1.Parent = p
	-- Back
	local s2 = Instance.new("SurfaceGui")
	s2.Face = Enum.NormalId.Back
	s2.LightInfluence = 1
	s2.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	s2.PixelsPerStud = 64
    s2.AlwaysOnTop = true
	local il2 = Instance.new("ImageLabel")
	il2.BackgroundTransparency = 1
	il2.Size = UDim2.fromScale(1, 1)
	il2.Image = image
	il2.Parent = s2
	s2.Parent = p
	return p
end

local function buildFlatBlockItem(itemId)
    local def = BlockRegistry.Blocks[itemId]
    if not def or not def.textures then return nil end
    local textureName = def.textures.all or def.textures.side or def.textures.top
    if not textureName then return nil end
    local textureId = TextureManager:GetTextureId(textureName)
    if not textureId then return nil end
    local p = Instance.new("Part")
    p.Name = "ItemCard"
    p.Size = Vector3.new(1.2, 1.2, 0.05)
    p.Anchored = true
    p.CanCollide = false
    p.Massless = true
    p.CastShadow = false
    p.Transparency = 1
    local s1 = Instance.new("SurfaceGui")
    s1.Face = Enum.NormalId.Front
    s1.LightInfluence = 1
    s1.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    s1.PixelsPerStud = 64
    s1.AlwaysOnTop = true
    local il1 = Instance.new("ImageLabel")
    il1.BackgroundTransparency = 1
    il1.Size = UDim2.fromScale(1, 1)
    il1.Image = textureId
    il1.Parent = s1
    s1.Parent = p
    local s2 = Instance.new("SurfaceGui")
    s2.Face = Enum.NormalId.Back
    s2.LightInfluence = 1
    s2.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    s2.PixelsPerStud = 64
    s2.AlwaysOnTop = true
    local il2 = Instance.new("ImageLabel")
    il2.BackgroundTransparency = 1
    il2.Size = UDim2.fromScale(1, 1)
    il2.Image = textureId
    il2.Parent = s2
    s2.Parent = p
    return p
end

local function getArmColor()
    local char = player.Character
    if char then
        local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
        if hand and hand:IsA("BasePart") then
            return hand.Color
        end
    end
    return Color3.fromRGB(235, 205, 180)
end

local function buildArmModel()
    local arm = Instance.new("Part")
    arm.Name = "ViewArm"
    arm.Size = Vector3.new(0.26, 0.9, 0.26)
    arm.Anchored = true
    arm.CanCollide = false
    arm.Massless = true
    arm.CastShadow = false
    arm.Material = Enum.Material.SmoothPlastic
    arm.Color = getArmColor()
    return arm
end

local function rebuild()
	if not shouldShow() then
		destroyCurrent()
		return
	end

    local newInst
    if holdingTool then
		newInst = buildFlatItem(currentItemId)
    elseif holdingItem then
        if isFlatItem then
            newInst = buildFlatBlockItem(currentItemId)
        else
            newInst = buildBlockModel(currentItemId)
            if not newInst then
                newInst = buildFlatBlockItem(currentItemId) or buildFlatItem(currentItemId)
            end
        end
    else
        -- Empty hand -> show arm
        newInst = buildArmModel()
	end

	destroyCurrent()
	if newInst then
		newInst.Parent = workspace.CurrentCamera
		currentInstance = newInst
	end
end

local function onStateChanged()
	local fp = GameState:Get("camera.isFirstPerson") and true or false
    local isTool = GameState:Get("voxelWorld.isHoldingTool") and true or false
    local isItem = GameState:Get("voxelWorld.isHoldingItem") and true or false
	local toolId = GameState:Get("voxelWorld.selectedToolItemId")
	local blockSel = GameState:Get("voxelWorld.selectedBlock")
	local blockId = blockSel and blockSel.id or nil

	local nextItemId = isTool and toolId or blockId

    local nextIsFlat = false
    if isItem and blockId then
        local def = BlockRegistry.Blocks[blockId]
        nextIsFlat = def and (def.crossShape or def.craftingMaterial) and true or false
    end

    local changed = (fp ~= isFirstPerson) or (isTool ~= holdingTool) or (isItem ~= holdingItem) or (nextItemId ~= currentItemId) or (nextIsFlat ~= isFlatItem)
	isFirstPerson = fp
	holdingTool = isTool
	holdingItem = isItem
	currentItemId = nextItemId
    isFlatItem = nextIsFlat

	if changed then
		rebuild()
	end
end

local function pulseSwing()
	swingTimer = SWING_DURATION
end

local function connectInputs()
	clearConns(inputConns)
	inputConns[#inputConns+1] = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			pulseSwing()
		end
	end)
end

local function update(dt)
	if not currentInstance or not workspace.CurrentCamera then return end
	timeAcc += dt
	if swingTimer > 0 then
		swingTimer = math.max(0, swingTimer - dt)
	end

	local cam = workspace.CurrentCamera
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local isMoving = false
	if hum then
		isMoving = hum.MoveDirection.Magnitude > 0.1
	end

    -- Normalize swing progress a ∈ [0,1]
    local a = 0
    if swingTimer > 0 then
        a = 1 - (swingTimer / SWING_DURATION)
    end

    local humCamOff = Vector3.new()
    if hum and hum.CameraOffset then humCamOff = hum.CameraOffset end

    local cf
    if not holdingTool and not holdingItem then
        -- Arm (hand_type == 0)
        local b = math.sin(a * 2.2)
        local c = math.sin(-a * 4)
        local d = math.sin((a^(1/3)) * 1.6)
        local pre = CFrame.new(-humCamOff/2.3)
        local pos = Vector3.new(0.5 + (b * -0.21), -0.51 + (c * 0.45), -0.6 + (b * -0.12))
        local rot = CFrame.fromEulerAnglesYXZ(
            math.rad(-23 + (-2 * d)),
            math.rad(-90 + (65 * d)),
            math.rad(-135 + (5 * d))
        )
        cf = cam.CFrame * pre * CFrame.new(pos) * rot
    elseif holdingItem and not isFlatItem then
        -- Block (hand_type == 1)
        local b = math.sin(a * 2.618) * 2
        local c = math.sin(-a * 4)
        local d = math.sin((a^(1/3)) * 1.6)
        local pre = CFrame.new(-humCamOff/2.3 * 2)
        local pos = (Vector3.new(0.48 + (b * -0.21), -0.335 + (c * 0.2), -0.6 + (b * -0.025)) * 2)
        local rot = CFrame.fromEulerAnglesYXZ(
            math.rad(0 + (61 * d)),
            math.rad(-135 + (12 * d)),
            math.rad(0 + (19 * d))
        )
        cf = cam.CFrame * pre * CFrame.new(pos) * rot
    else
        -- Flat tool/material (hand_type == 2)
        local b = math.sin(a * 2.718) * 2
        local b2 = math.sin(a * 2.8) * 1.24
        local c = math.sin(-a * 4.7)
        if c < 0 then c = c * 1.5 end
        local d = math.sin((a^(1/3)) * 1.6)
        local pre = CFrame.new(-humCamOff/2.9 * 3)
        local pos = (Vector3.new(0.36 + (-0.28 * b2), -0.1 + (c * 0.16), -0.37 + (-0.23 * b)) * 3)
        local rot = CFrame.fromEulerAnglesYXZ(
            math.rad(0 + (-22 * d)),
            math.rad(90 + (25 * d)),
            math.rad(-23 + (-57 * b))
        )
        cf = cam.CFrame * pre * CFrame.new(pos) * rot
    end

	if currentInstance:IsA("Model") then
		currentInstance:PivotTo(cf)
	else
		currentInstance.CFrame = cf
	end
end

function Controller:Initialize()
	-- Initial state
	onStateChanged()

	-- Listen to state changes
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("camera.isFirstPerson", onStateChanged)
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("voxelWorld.isHoldingTool", onStateChanged)
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("voxelWorld.isHoldingItem", onStateChanged)
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", onStateChanged)
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("voxelWorld.selectedBlock", onStateChanged)

	-- Character respawn cleanup
	respawnConn = player.CharacterAdded:Connect(function()
		rebuild()
	end)

	-- Frame update
	rsConn = RunService.RenderStepped:Connect(update)

	-- Swing pulse triggers
	connectInputs()
end

function Controller:Cleanup()
	if rsConn then pcall(function() rsConn:Disconnect() end) rsConn = nil end
	if respawnConn then pcall(function() respawnConn:Disconnect() end) respawnConn = nil end
	clearConns(camChangedConns)
	clearConns(inputConns)
	destroyCurrent()
end

return Controller


