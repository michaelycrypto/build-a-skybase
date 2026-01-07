--[[
	CharacterRigBuilder.lua
	Builds a character rig for viewport previews using Roblox's built-in character creation
--]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorRenderer = require(ReplicatedStorage.Shared.ArmorRenderer)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local HeldItemRenderer = require(ReplicatedStorage.Shared.HeldItemRenderer)

local CharacterRigBuilder = {}

local DEFAULT_FALLBACK_USER_ID = 1 -- Roblox account; ensure rigs for Studio test players
local CHARACTER_WAIT_TIMEOUT = 5 -- seconds
local IDLE_ANIMATION_IDS = {
	"rbxassetid://507766666", -- Idle
	"rbxassetid://507766951"  -- Idle v2
}

local cachedStarterTemplate = nil
local idleTrackConnections = setmetatable({}, {__mode = "k"})

local ATTACHMENT_SEARCH_ORDER = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"LeftUpperArm",
	"RightUpperArm",
	"LeftArm",
	"RightArm",
	"LeftLowerArm",
	"RightLowerArm",
	"LeftHand",
	"RightHand",
	"LeftUpperLeg",
	"RightUpperLeg",
	"LeftLeg",
	"RightLeg",
	"LeftLowerLeg",
	"RightLowerLeg",
	"LeftFoot",
	"RightFoot"
}

local function setModelPhysicsState(model, anchored)
	if not model then
		return
	end

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Massless = true
			if anchored ~= nil then
				if anchored then
					part.AssemblyLinearVelocity = Vector3.zero
					part.AssemblyAngularVelocity = Vector3.zero
				end
				part.Anchored = anchored
			end
		end
	end
end

local function stripScriptsFromModel(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") then
			descendant:Destroy()
		end
	end

	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
end

local function findAttachmentOnRig(rig, attachmentName)
	if not rig or not attachmentName then
		return nil, nil
	end

	for _, partName in ipairs(ATTACHMENT_SEARCH_ORDER) do
		local part = rig:FindFirstChild(partName)
		if part then
			local attachment = part:FindFirstChild(attachmentName)
			if attachment then
				return part, attachment
			end
		end
	end

	return nil, nil
end

local function alignAccessoryToRig(accessory, rig)
	local handle = accessory and accessory:FindFirstChild("Handle")
	if not handle then
		return
	end

	-- Collect direct attachment children on the handle (ignore wrap/layer attachments deeper in the hierarchy)
	local handleAttachments = {}
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") then
			table.insert(handleAttachments, child)
		end
	end
	if #handleAttachments == 0 then
		local fallbackAttachment = handle:FindFirstChildOfClass("Attachment")
		if fallbackAttachment then
			table.insert(handleAttachments, fallbackAttachment)
		end
	end

	if #handleAttachments == 0 then
		return
	end

	-- Remove existing welds so the viewport weld fully controls the handle
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("WeldConstraint") or child:IsA("Weld") or (child:IsA("Motor6D") and child.Name == "AccessoryWeld") then
			child:Destroy()
		end
	end

	local selectedPart = nil
	local selectedRigAttachment = nil
	local selectedHandleAttachment = nil

	for _, handleAttachment in ipairs(handleAttachments) do
		local targetPart, targetAttachment = findAttachmentOnRig(rig, handleAttachment.Name)
		if targetPart and targetAttachment then
			selectedPart = targetPart
			selectedRigAttachment = targetAttachment
			selectedHandleAttachment = handleAttachment
			break
		end
	end

	if not selectedPart or not selectedRigAttachment or not selectedHandleAttachment then
		return
	end

	local targetWorldCFrame = selectedPart.CFrame * selectedRigAttachment.CFrame
	local handleWorldCFrame = targetWorldCFrame * selectedHandleAttachment.CFrame:Inverse()
	handle.CFrame = handleWorldCFrame

	local weld = Instance.new("WeldConstraint")
	weld.Name = "ViewportAccessoryWeld"
	weld.Part0 = selectedPart
	weld.Part1 = handle
	weld.Parent = handle
end

local DEFAULT_RIG_POSES = {
	R15 = {
		UpperTorso = {
			settings = {
				Neck = {
					C0 = CFrame.new(0, 1, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				RightShoulder = {
					C0 = CFrame.new(0.5, 0.5, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				LeftShoulder = {
					C0 = CFrame.new(-0.5, 0.5, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				RightHip = {
					C0 = CFrame.new(0.5, -0.5, 0),
					C1 = CFrame.new(0, 0.5, 0)
				},
				LeftHip = {
					C0 = CFrame.new(-0.5, -0.5, 0),
					C1 = CFrame.new(0, 0.5, 0)
				}
			}
		}
	},
	R6 = {
		Torso = {
			settings = {
				Neck = {
					C0 = CFrame.new(0, 1, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				RightShoulder = {
					C0 = CFrame.new(1, 0.5, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				LeftShoulder = {
					C0 = CFrame.new(-1, 0.5, 0),
					C1 = CFrame.new(0, -0.5, 0)
				},
				RightHip = {
					C0 = CFrame.new(1, -1, 0),
					C1 = CFrame.new(0, 1, 0)
				},
				LeftHip = {
					C0 = CFrame.new(-1, -1, 0),
					C1 = CFrame.new(0, 1, 0)
				}
			}
		}
	}
}

local function resetRigPose(model)
	if not model then return end

	local isR15 = model:FindFirstChild("UpperTorso") ~= nil
	local torso = model:FindFirstChild(isR15 and "UpperTorso" or "Torso")
	if not torso then return end

	local poseConfig = isR15 and DEFAULT_RIG_POSES.R15.UpperTorso or DEFAULT_RIG_POSES.R6.Torso
	if not poseConfig then return end

	for jointName, cfg in pairs(poseConfig.settings) do
		local motor = torso:FindFirstChild(jointName)
		if motor and motor:IsA("Motor6D") then
			motor.C0 = cfg.C0
			motor.C1 = cfg.C1
			motor.Transform = CFrame.new()
		end
	end

	local lowerTorso = model:FindFirstChild("LowerTorso")
	if lowerTorso then
		for _, motor in ipairs(lowerTorso:GetChildren()) do
			if motor:IsA("Motor6D") then
				motor.Transform = CFrame.new()
			end
		end
	end

	for _, partName in ipairs({"RightUpperArm", "LeftUpperArm", "RightLowerArm", "LeftLowerArm", "RightHand", "LeftHand",
		"RightUpperLeg", "LeftUpperLeg", "RightLowerLeg", "LeftLowerLeg", "RightFoot", "LeftFoot"}) do
		local part = model:FindFirstChild(partName)
		if part then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") then
					child.Transform = CFrame.new()
				end
			end
		end
	end

	-- Ensure R6 limb transforms are also reset
	for _, partName in ipairs({"RightArm", "LeftArm", "RightLeg", "LeftLeg"}) do
		local part = model:FindFirstChild(partName)
		if part then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("Motor6D") then
					child.Transform = CFrame.new()
				end
			end
		end
	end
end

local function ensureNeckAlignment(model)
	if not model then return end
	local head = model:FindFirstChild("Head")
	if not head then return end

	local torso = model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
	if not torso then return end

	local neckMotor
	for _, child in ipairs(torso:GetChildren()) do
		if child:IsA("Motor6D") and child.Part1 == head then
			neckMotor = child
			break
		end
	end

	if not neckMotor then
		return
	end

	neckMotor.Transform = CFrame.new()
	local isR15 = model:FindFirstChild("UpperTorso") ~= nil
	if isR15 then
		neckMotor.C0 = CFrame.new(0, 1, 0)
		neckMotor.C1 = CFrame.new(0, -0.5, 0)
	else
		neckMotor.C0 = CFrame.new(0, 1, 0)
		neckMotor.C1 = CFrame.new(0, -0.5, 0)
	end

	if neckMotor.Part0 and neckMotor.Part1 then
		local torsoCFrame = neckMotor.Part0.CFrame
		local headCFrame = torsoCFrame * neckMotor.C0 * neckMotor.C1:Inverse()
		neckMotor.Part1.CFrame = headCFrame
	end
end

local function waitForCharacter(player)
	if not player then
		return nil
	end

	local character = player.Character
	if character then
		return character
	end

	local elapsed = 0
	while elapsed < CHARACTER_WAIT_TIMEOUT do
		local ok, newCharacter = pcall(function()
			return player.CharacterAdded:Wait()
		end)
		if ok and newCharacter then
			return newCharacter
		end
		local dt = RunService.Heartbeat:Wait()
		elapsed += dt
		if player.Character then
			return player.Character
		end
	end

	return player.Character
end

local function createRigFromUserId(userId)
	if not userId or userId <= 0 then
		return nil, "invalid_user_id"
	end

	local success, result = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)

	if success and typeof(result) == "Instance" then
		return result
	end

	local reason = success and ("unexpected_type_" .. typeof(result)) or tostring(result)
	return nil, reason
end

local function cloneStarterTemplate()
	if cachedStarterTemplate == nil then
		local starterCharacter = StarterPlayer and StarterPlayer:FindFirstChild("StarterCharacter")
		if starterCharacter then
			local originalArchivable = starterCharacter.Archivable
			starterCharacter.Archivable = true
			local ok, clone = pcall(function()
				return starterCharacter:Clone()
			end)
			starterCharacter.Archivable = originalArchivable
			if ok and clone then
				clone.Archivable = true
				cachedStarterTemplate = clone
			else
				cachedStarterTemplate = false
			end
		else
			cachedStarterTemplate = false
		end
	end

	if cachedStarterTemplate and typeof(cachedStarterTemplate) == "Instance" then
		local ok, clone = pcall(function()
			return cachedStarterTemplate:Clone()
		end)
		if ok and clone then
			return clone
		end
		return nil, "starter_template_clone_failed"
	end

	return nil, "starter_template_unavailable"
end

local function cloneExistingCharacter(player)
	local character = waitForCharacter(player)
	if not character then
		return nil, "missing_character"
	end

	local originalArchivable = character.Archivable
	character.Archivable = true

	local success, clone = pcall(function()
		return character:Clone()
	end)

	character.Archivable = originalArchivable

	if success and clone then
		return clone
	end

	return nil, success and "clone_nil" or tostring(clone)
end

-- Build a character rig using Roblox's character creation API
-- Priority: Clone existing character (has server-side scaling) > CreateHumanoidModel > Fallbacks
function CharacterRigBuilder.BuildCharacterRig(player)
	if not player then return nil end

	local rig, failureReason

	-- PRIORITY 1: Clone existing character (already has Minecraft scaling from server)
	local clone, cloneReason = cloneExistingCharacter(player)
	if clone then
		rig = clone
	else
		failureReason = cloneReason
	end

	-- PRIORITY 2: Create from UserId (no scaling, will need to apply manually)
	if not rig then
		local userRig, userReason = createRigFromUserId(player.UserId)
		if userRig then
			rig = userRig
		else
			failureReason = failureReason or userReason
		end
	end

	-- PRIORITY 3: Starter template
	if not rig then
		local starterTemplate, starterReason = cloneStarterTemplate()
		if starterTemplate then
			rig = starterTemplate
		else
			failureReason = failureReason or starterReason
		end
	end

	-- PRIORITY 4: Fallback to default user
	if not rig then
		local fallbackRig, fallbackReason = createRigFromUserId(DEFAULT_FALLBACK_USER_ID)
		if fallbackRig then
			rig = fallbackRig
		else
			failureReason = failureReason or fallbackReason
		end
	end

	if not rig or typeof(rig) ~= "Instance" then
		warn("CharacterRigBuilder: Failed to create character rig for", player.Name, failureReason)
		return nil
	end

	-- Ensure HumanoidRootPart exists and is set as PrimaryPart
	if not rig:FindFirstChild("HumanoidRootPart") then
		-- Create a basic HumanoidRootPart if missing
		local rootPart = Instance.new("Part")
		rootPart.Name = "HumanoidRootPart"
		rootPart.Size = Vector3.new(2, 2, 1)
		rootPart.CFrame = CFrame.new(0, 5, 0)
		rootPart.Anchored = true
		rootPart.CanCollide = false
		rootPart.Parent = rig
		rig.PrimaryPart = rootPart
	else
		rig.PrimaryPart = rig.HumanoidRootPart
	end

	-- Disable animations and physics
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		-- Disable all animations
		for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
			track:Stop()
		end
	end

	setModelPhysicsState(rig, false)

	-- Fix head and Motor6D connections - copy from actual character if available
	local head = rig:FindFirstChild("Head")
	local character = waitForCharacter(player)

	if head then
		local torso = rig:FindFirstChild("Torso") or rig:FindFirstChild("UpperTorso")

		-- Try to copy Motor6D values from actual character if it exists
		local sourceMotor = nil
		if character then
			local sourceHead = character:FindFirstChild("Head")
			local sourceTorso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
			if sourceHead and sourceTorso then
				-- Find the neck Motor6D in the actual character
				for _, motor in ipairs(sourceTorso:GetChildren()) do
					if motor:IsA("Motor6D") and motor.Part1 == sourceHead then
						sourceMotor = motor
						break
					end
				end
			end
		end

		-- Find or create neck Motor6D in rig
		local neckMotor = nil
		if torso then
			for _, motor in ipairs(torso:GetChildren()) do
				if motor:IsA("Motor6D") and motor.Part1 == head then
					neckMotor = motor
					break
				end
			end

			-- Create Motor6D if it doesn't exist
			if not neckMotor then
				neckMotor = Instance.new("Motor6D")
				neckMotor.Name = "Neck"
				neckMotor.Part0 = torso
				neckMotor.Part1 = head
				neckMotor.Parent = torso
			end

			-- Copy CFrame values from source or use defaults
			if sourceMotor then
				neckMotor.C0 = sourceMotor.C0
				neckMotor.C1 = sourceMotor.C1
			else
				-- Use standard R15 values
				if rig:FindFirstChild("UpperTorso") then
					-- R15: Neck connects UpperTorso to Head
					neckMotor.C0 = CFrame.new(0, 1, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0)
					neckMotor.C1 = CFrame.new(0, -0.5, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0)
				else
					-- R6: Neck connects Torso to Head
					neckMotor.C0 = CFrame.new(0, 1, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0)
					neckMotor.C1 = CFrame.new(0, -0.5, 0, 1, 0, 0, 0, 0, -1, 0, 1, 0)
				end
			end

			-- Manually position head based on Motor6D CFrame values
			-- This ensures correct positioning even when parts are anchored
			if neckMotor.Part0 and neckMotor.Part1 then
				-- Calculate head position: torso.CFrame * C0 * C1:Inverse() gives head.CFrame
				local torsoCFrame = torso.CFrame
				local headCFrame = torsoCFrame * neckMotor.C0 * neckMotor.C1:Inverse()
				head.CFrame = headCFrame
				neckMotor.Enabled = true
			end
		end
	end

	-- Fix accessory attachments - copy from actual character if available
	for _, accessory in ipairs(rig:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			if handle then
				handle.CanCollide = false
				alignAccessoryToRig(accessory, rig)
			end
		end
	end

resetRigPose(rig)
ensureNeckAlignment(rig)

	-- Strip any held items that were cloned from the live character
	-- The caller (e.g., armor UI viewmodel) will attach the appropriate item via HeldItemRenderer
	HeldItemRenderer.ClearItem(rig)

stripScriptsFromModel(rig)
	setModelPhysicsState(rig, true)

	return rig
end

local function getIdleAnimationId()
	if #IDLE_ANIMATION_IDS == 0 then
		return nil
	end
	local index = math.random(1, #IDLE_ANIMATION_IDS)
	return IDLE_ANIMATION_IDS[index]
end

function CharacterRigBuilder.ApplyIdlePose(model)
	if not model then return end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local existingTrackValue = humanoid:FindFirstChild("ViewportIdleTrack")
	if existingTrackValue and existingTrackValue.Value then
		local existingTrack = existingTrackValue.Value
		pcall(function()
			existingTrack:Stop()
			existingTrack:Destroy()
		end)
		local existingConn = idleTrackConnections[existingTrack]
		if existingConn then
			existingConn:Disconnect()
			idleTrackConnections[existingTrack] = nil
		end
	end
	if existingTrackValue then
		existingTrackValue:Destroy()
	end

	setModelPhysicsState(model, false)

	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Name = "ViewportAnimator"
		animator.Parent = humanoid
	end

	for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
		pcall(function()
			track:Stop()
		end)
	end

	local animationId = getIdleAnimationId()
	if not animationId then
		setModelPhysicsState(model, true)
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = "ArmorIdlePose"
	animation.AnimationId = animationId
	animation.Parent = model

	local track = animator:LoadAnimation(animation)
	animation:Destroy()
	if not track then
		setModelPhysicsState(model, true)
		return
	end

	track.Priority = Enum.AnimationPriority.Core
	track.Looped = false
	track:Play(0.05)
	track.TimePosition = math.min(track.Length, 0.2)
	track:AdjustSpeed(0)

	local trackValue = Instance.new("ObjectValue")
	trackValue.Name = "ViewportIdleTrack"
	trackValue.Value = track
	trackValue.Parent = humanoid

	track.Stopped:Connect(function()
		local conn = idleTrackConnections[track]
		if conn then
			conn:Disconnect()
			idleTrackConnections[track] = nil
		end
		if trackValue.Parent then
			trackValue:Destroy()
		end
		if track then
			track:Destroy()
		end
	end)

	idleTrackConnections[track] = model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			local conn = idleTrackConnections[track]
			if conn then
				conn:Disconnect()
				idleTrackConnections[track] = nil
			end
			pcall(function()
				track:Stop()
				track:Destroy()
			end)
			if trackValue.Parent then
				trackValue:Destroy()
			end
		end
	end)

	setModelPhysicsState(model, true)
end

-- Check if a character already has Minecraft scaling applied
-- Uses values from GameConfig.CharacterScale
local function hasMinecraftScaling(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end

	local widthScale = humanoid:FindFirstChild("BodyWidthScale")
	if widthScale and widthScale:IsA("NumberValue") then
		-- If width is already scaled to the configured value, scaling was already applied
		return math.abs(widthScale.Value - GameConfig.CharacterScale.WIDTH) < 0.05
	end

	return false
end

-- Apply Minecraft-accurate character scaling to a viewport rig
-- Uses values from GameConfig.CharacterScale
-- Uses HumanoidDescription for most reliable scaling
function CharacterRigBuilder.ApplyMinecraftScale(model)
	if not model then return end

	-- Skip if already scaled (e.g., cloned from already-scaled character)
	if hasMinecraftScaling(model) then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local scale = GameConfig.CharacterScale

	-- Method 1: Try HumanoidDescription (most reliable)
	local descriptionApplied = false
	pcall(function()
		local description = humanoid:GetAppliedDescription()
		if description then
			description.HeightScale = scale.HEIGHT
			description.WidthScale = scale.WIDTH
			description.DepthScale = scale.DEPTH
			description.HeadScale = scale.HEAD
			humanoid:ApplyDescription(description)
			descriptionApplied = true
		end
	end)

	-- Method 2: Set NumberValue scales directly (fallback)
	if not descriptionApplied then
		local function setOrCreateScale(name, value)
			local scaleValue = humanoid:FindFirstChild(name)
			if not scaleValue then
				scaleValue = Instance.new("NumberValue")
				scaleValue.Name = name
				scaleValue.Parent = humanoid
			end
			if scaleValue:IsA("NumberValue") then
				scaleValue.Value = value
			end
		end

		setOrCreateScale("BodyHeightScale", scale.HEIGHT)
		setOrCreateScale("BodyWidthScale", scale.WIDTH)
		setOrCreateScale("BodyDepthScale", scale.DEPTH)
		setOrCreateScale("HeadScale", scale.HEAD)
	end
end

-- Apply armor visuals to a character model (for viewports)
-- Uses anchored parts since viewport models have anchored body parts
-- @param model: The character model to apply armor to
-- @param equippedArmor: Table with helmet, chestplate, leggings, boots item IDs
-- @returns: Table of all created armor part instances
function CharacterRigBuilder.ApplyArmorVisuals(model, equippedArmor)
	if not model or not equippedArmor then return {} end

	-- Clear any existing armor parts first
	ArmorRenderer.ClearArmorParts(model)

	-- Apply armor with anchored=true for viewport models
	return ArmorRenderer.ApplyAllArmor(model, equippedArmor, true, nil)
end

-- Clear armor visuals from a character model
function CharacterRigBuilder.ClearArmorVisuals(model)
	if not model then return end
	ArmorRenderer.ClearArmorParts(model)
end

return CharacterRigBuilder

