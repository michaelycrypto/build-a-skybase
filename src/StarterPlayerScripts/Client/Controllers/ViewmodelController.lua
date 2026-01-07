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
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

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

-- Bow viewmodel state (multiple meshes for stage toggling)
local bowViewmodelParts = {} -- {idle, [0], [1], [2]}
local currentBowVMStage = nil
local isBowViewmodelActive = false

-- Animation state (from GameConfig for universal tuning)
local timeAcc = 0
local swingTimer = 0
local SWING_DURATION = GameConfig.Combat.SWING_COOLDOWN
local isSwingHeld = false -- Track if mouse is held for continuous swinging

local function destroyBowViewmodelParts()
	for key, part in pairs(bowViewmodelParts) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	bowViewmodelParts = {}
	currentBowVMStage = nil
	isBowViewmodelActive = false
end

local function destroyCurrent()
	destroyBowViewmodelParts()
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

-- === TOOL MESH (replace SurfaceGui for tools) ===
local STUDS_PER_PIXEL = 3/16
local VM_TOOL_SCALE = 0.5 -- shrink first-person tool meshes to 50% of true scale
local TOOL_ASSET_NAME_BY_TYPE = {
	[BlockProperties.ToolType.SWORD] = "Sword",
	[BlockProperties.ToolType.AXE] = "Axe",
	[BlockProperties.ToolType.SHOVEL] = "Shovel",
	[BlockProperties.ToolType.PICKAXE] = "Pickaxe",
	[BlockProperties.ToolType.BOW] = "Bow",
	[BlockProperties.ToolType.ARROW] = "Arrow",
}

local TOOL_PX_BY_TYPE = {
	[BlockProperties.ToolType.SWORD] = {x = 14, y = 14},
	[BlockProperties.ToolType.AXE] = {x = 12, y = 14},
	[BlockProperties.ToolType.SHOVEL] = {x = 12, y = 12},
	[BlockProperties.ToolType.PICKAXE] = {x = 13, y = 13},
	[BlockProperties.ToolType.BOW] = {x = 14, y = 14},
	[BlockProperties.ToolType.ARROW] = {x = 14, y = 13},
}

local function scaleMeshToPixels(part, pxX, pxY)
	local longestPx = math.max(pxX or 0, pxY or 0)
	if longestPx <= 0 then return end
	local targetStuds = longestPx * STUDS_PER_PIXEL
	local size = part.Size
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0 then
		local s = (targetStuds / maxDim) * VM_TOOL_SCALE
		part.Size = Vector3.new(size.X * s, size.Y * s, size.Z * s)
	end
end

-- Helpers for resolving tool assets (prefer ReplicatedStorage.Tools, fallback to Assets.Tools)
local function findToolsContainer()
	-- Prefer direct ReplicatedStorage.Tools
	local tools = ReplicatedStorage:FindFirstChild("Tools")
	if tools then return tools end
	-- Fallback: ReplicatedStorage.Assets.Tools or an auto-detected container under Assets
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then return nil end
	local direct = assets:FindFirstChild("Tools")
	if direct then return direct end
	-- Heuristic: find a folder/model that contains tool names
	local expected = {}
	for _, name in pairs(TOOL_ASSET_NAME_BY_TYPE) do
		expected[name] = true
	end
	for _, child in ipairs(assets:GetChildren()) do
		if child:IsA("Folder") or child:IsA("Model") then
			for name, _ in pairs(expected) do
				if child:FindFirstChild(name) then
					return child
				end
			end
		end
	end
	return nil
end

local function findMeshPartFromTemplate(template: Instance)
	if not template then return nil end
	if template:IsA("MeshPart") then
		return template
	end
	return template:FindFirstChildWhichIsA("MeshPart", true)
end

local function createBowViewmodelMesh(assetName, itemId)
	local toolsFolder = findToolsContainer()
	if not toolsFolder then return nil end
	local template = toolsFolder:FindFirstChild(assetName)
	if not template then return nil end

	local mesh = findMeshPartFromTemplate(template)
	if not mesh then return nil end

	local p = mesh:Clone()
	p.Name = "BowVM_" .. assetName
	p.Anchored = true
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false
	p.Transparency = 1 -- Start hidden

	-- Apply texture
	local hasExistingTexture = false
	pcall(function()
		local currentTex = p.TextureID
		hasExistingTexture = (currentTex ~= nil and tostring(currentTex) ~= "")
	end)
	if not hasExistingTexture then
		local info = ToolConfig.GetToolInfo(itemId)
		local texId = info and info.image
		if texId and p:IsA("MeshPart") then
			pcall(function()
				p.TextureID = texId
			end)
		end
	end

	-- Scale
	local px = TOOL_PX_BY_TYPE[BlockProperties.ToolType.BOW]
	if px then
		scaleMeshToPixels(p, px.x, px.y)
	end

	return p
end

local function createAllBowViewmodelParts(itemId)
	destroyBowViewmodelParts()

	local cam = workspace.CurrentCamera
	if not cam then return end

	-- Create all 4 bow states
	bowViewmodelParts.idle = createBowViewmodelMesh("Bow", itemId)
	bowViewmodelParts[0] = createBowViewmodelMesh("Bow_pulling_0", itemId)
	bowViewmodelParts[1] = createBowViewmodelMesh("Bow_pulling_1", itemId)
	bowViewmodelParts[2] = createBowViewmodelMesh("Bow_pulling_2", itemId)

	-- Parent all to camera
	for key, part in pairs(bowViewmodelParts) do
		if part then
			part.Parent = cam
		end
	end

	-- Show idle by default
	if bowViewmodelParts.idle then
		bowViewmodelParts.idle.Transparency = 0
		currentInstance = bowViewmodelParts.idle
	end
	currentBowVMStage = "idle"
	isBowViewmodelActive = true
end

local function updateBowViewmodelStage()
	if not isBowViewmodelActive then return end

	local stage = GameState:Get("voxelWorld.bowPullStage")
	local targetKey = stage
	if stage == nil then
		targetKey = "idle"
	end

	-- Skip if already showing this stage
	if currentBowVMStage == targetKey then return end

	-- Hide all
	for key, part in pairs(bowViewmodelParts) do
		if part and part.Parent then
			part.Transparency = 1
		end
	end

	-- Show target
	local targetPart = bowViewmodelParts[targetKey] or bowViewmodelParts.idle
	if targetPart and targetPart.Parent then
		targetPart.Transparency = 0
		currentInstance = targetPart
	end

	currentBowVMStage = targetKey
end

local function buildToolMesh(itemId)
	local toolType = select(1, ToolConfig.GetBlockProps(itemId))

	-- For bows, use the multi-mesh system instead
	if toolType == BlockProperties.ToolType.BOW then
		createAllBowViewmodelParts(itemId)
		return bowViewmodelParts.idle -- Return idle as the "current" instance
	end

	local assetName = toolType and TOOL_ASSET_NAME_BY_TYPE[toolType]
	if not assetName then return nil end

	local toolsFolder = findToolsContainer()
	if not toolsFolder then return nil end
	local template = toolsFolder:FindFirstChild(assetName)
	if not template then return nil end

	local mesh = findMeshPartFromTemplate(template)
	if not mesh then return nil end

	local p = mesh:Clone()
	p.Name = "ToolVM_" .. tostring(toolType)
	p.Anchored = true
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = false

	-- Apply tier texture from ToolConfig if template has none
	local hasExistingTexture = false
	pcall(function()
		local currentTex = p.TextureID
		hasExistingTexture = (currentTex ~= nil and tostring(currentTex) ~= "")
	end)
	if not hasExistingTexture then
		local info = ToolConfig.GetToolInfo(itemId)
		local texId = info and info.image
		if texId and p:IsA("MeshPart") then
			pcall(function()
				p.TextureID = texId
			end)
		end
	end

	-- Scale to pixel dimensions per tool type
	local px = TOOL_PX_BY_TYPE[toolType]
	if px then
		scaleMeshToPixels(p, px.x, px.y)
	end

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

local function isBowEquipped()
	local holding = GameState:Get("voxelWorld.isHoldingTool") == true
	local itemId = GameState:Get("voxelWorld.selectedToolItemId")
	if not holding or not itemId or not ToolConfig.IsTool(itemId) then
		return false
	end
	local toolType = select(1, ToolConfig.GetBlockProps(itemId))
	return toolType == BlockProperties.ToolType.BOW
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

	-- Check if this is a bow tool
	local toolType = nil
	if holdingTool and currentItemId then
		toolType = select(1, ToolConfig.GetBlockProps(currentItemId))
	end
	local isBow = toolType == BlockProperties.ToolType.BOW

	-- For bows, buildToolMesh creates multiple meshes, so we need to destroy first
	-- For non-bows, we create the new instance first then destroy
    local newInst
	if holdingTool then
		if isBow then
			-- Bow: destroy everything first, then create all bow meshes
			destroyCurrent()
			newInst = buildToolMesh(currentItemId)
			-- newInst is already parented by createAllBowViewmodelParts
			if newInst then
				currentInstance = newInst
			end
			return
		else
			-- Non-bow tool
			newInst = buildToolMesh(currentItemId)
		end
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

	-- Check if only the bow stage changed (not a full state change)
	local bowStageChanged = GameState:Get("voxelWorld.bowPullStage") ~= GameState:Get("voxelWorld._vm_lastBowStage")
	local structuralChanged = (fp ~= isFirstPerson)
		or (isTool ~= holdingTool)
		or (isItem ~= holdingItem)
		or (nextItemId ~= currentItemId)
		or (nextIsFlat ~= isFlatItem)

	isFirstPerson = fp
	holdingTool = isTool
	holdingItem = isItem
	currentItemId = nextItemId
    isFlatItem = nextIsFlat
	GameState:Set("voxelWorld._vm_lastBowStage", GameState:Get("voxelWorld.bowPullStage"), true)

	if structuralChanged then
		-- Full rebuild needed
		rebuild()
	elseif bowStageChanged and isBowViewmodelActive then
		-- Just update bow mesh visibility (no rebuild)
		updateBowViewmodelStage()
	end
end

local function pulseSwing()
	-- Block if swing is already in progress - must complete before next one
	if swingTimer > 0 then return false end
	swingTimer = SWING_DURATION
	return true
end

local function connectInputs()
	clearConns(inputConns)

	-- Track mouse down for continuous swinging
	inputConns[#inputConns+1] = UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		-- Skip swing pulse for bow (charging handled elsewhere)
		if isBowEquipped() then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isSwingHeld = true
			pulseSwing() -- Initial swing
		end
	end)

	-- Track mouse up to stop continuous swinging
	inputConns[#inputConns+1] = UserInputService.InputEnded:Connect(function(input, gp)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isSwingHeld = false
		end
	end)
end

local function update(dt)
	if not currentInstance or not workspace.CurrentCamera then return end
	timeAcc += dt
	if swingTimer > 0 then
		swingTimer = math.max(0, swingTimer - dt)
	end

	-- Continuous swinging while mouse is held (and not bow)
	if isSwingHeld and swingTimer <= 0 and not isBowEquipped() then
		pulseSwing()
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
        -- Lower base Y offset
        local pos = (Vector3.new(0.36 + (-0.28 * b2), -0.20 + (c * 0.16), -0.37 + (-0.23 * b)) * 3)
        local rot = CFrame.fromEulerAnglesYXZ(
            math.rad(0 + (-22 * d)),
            math.rad(90 + (25 * d)),
            math.rad(-23 + (-57 * b))
        )
        cf = cam.CFrame * pre * CFrame.new(pos) * rot
    end

	-- For bow viewmodel, move all mesh parts (so switching is instant)
	if isBowViewmodelActive then
		for key, part in pairs(bowViewmodelParts) do
			if part and part.Parent then
				part.CFrame = cf
			end
		end
	elseif currentInstance:IsA("Model") then
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
	camChangedConns[#camChangedConns+1] = GameState:OnPropertyChanged("voxelWorld.bowPullStage", onStateChanged)

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


