--[[
	ToolAnimationController.lua
	Plays R15 swing/punch animations for local and remote players.
	Uses Animator:LoadAnimation for R15 compatibility.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local InputService = require(script.Parent.Parent.Input.InputService)

local controller = {}

local localPlayer = Players.LocalPlayer

-- Animation IDs (using tool swing for both - reliable and works at high speed)
local PUNCH_ANIMATION_ID = "rbxassetid://675025570" -- Use swing for punch (works reliably)
local SWING_ANIMATION_ID = "rbxassetid://675025570" -- Tool swing

-- Animation settings (from GameConfig for universal tuning)
local PUNCH_SPEED = GameConfig.Combat.SWING_SPEED
local SWING_SPEED = GameConfig.Combat.SWING_SPEED
local SWING_COOLDOWN = GameConfig.Combat.SWING_COOLDOWN

local animationCache = {} -- animId -> Animation instance
local playerTracks = {} -- userId -> {track, lastSwingTime}
local isSwingHeld = false -- Track if mouse is held for continuous swinging
local heartbeatConn = nil -- Heartbeat connection for continuous swing

local function isBowEquipped()
	local holding = GameState:Get("voxelWorld.isHoldingTool") == true
	local itemId = GameState:Get("voxelWorld.selectedToolItemId")
	if not holding or not itemId or not ToolConfig.IsTool(itemId) then
		return false
	end
	local toolType = select(1, ToolConfig.GetBlockProps(itemId))
	return toolType == BlockProperties.ToolType.BOW
end

local function getAnimatorForPlayer(targetPlayer)
	local character = targetPlayer and targetPlayer.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function getAnimation(animId)
	local anim = animationCache[animId]
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = animId
		animationCache[animId] = anim
	end
	return anim
end

local function playSwingForPlayer(targetPlayer, isRemote)
	if not targetPlayer then
		return
	end

	-- For local player, suppress if bow is equipped
	if targetPlayer == localPlayer and isBowEquipped() then
		return
	end

	local userId = targetPlayer.UserId
	local now = os.clock()

	-- Initialize player tracking if needed
	if not playerTracks[userId] then
		playerTracks[userId] = { track = nil, lastSwingTime = 0 }
	end

	local trackData = playerTracks[userId]

	-- Time-based cooldown for local player only (remote players trust server rate-limiting)
	if not isRemote and (now - trackData.lastSwingTime) < SWING_COOLDOWN then
		return
	end

	local animator = getAnimatorForPlayer(targetPlayer)
	if not animator then
		return
	end

	-- Determine animation: tool swing vs bare-hand punch
	local animId = PUNCH_ANIMATION_ID
	local speed = PUNCH_SPEED

	if targetPlayer == localPlayer then
		local holding = GameState:Get("voxelWorld.isHoldingTool") == true
		local itemId = GameState:Get("voxelWorld.selectedToolItemId")
		if holding and itemId and ToolConfig.IsTool(itemId) then
			animId = SWING_ANIMATION_ID
			speed = SWING_SPEED
		end
	end

	-- Stop previous animation if still playing (for clean transition)
	if trackData.track and trackData.track.IsPlaying then
		pcall(function() trackData.track:Stop(0) end)
	end

	-- Load and play animation
	local track = animator:LoadAnimation(getAnimation(animId))
	if not track then
		return
	end

	trackData.track = track
	trackData.lastSwingTime = now

	pcall(function()
		-- Use Action4 priority (highest action level) to prevent interruption
		track.Priority = Enum.AnimationPriority.Action4
		-- Play with no fade for instant snappy animation
		track:Play(0, 1, speed)
	end)
end

function controller:Initialize()
	local RunService = game:GetService("RunService")

	-- Input hook for local player - track hold state
	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isSwingHeld = true
			playSwingForPlayer(localPlayer) -- Initial swing
		end
	end)

	InputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isSwingHeld = false
		end
	end)

	-- Continuous swinging while mouse is held
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not isSwingHeld then
			return
		end
		if isBowEquipped() then
			return
		end

		-- Try to play swing - will only succeed if previous animation finished
		playSwingForPlayer(localPlayer)
	end)

	-- Character reset handling
	localPlayer.CharacterAdded:Connect(function()
		playerTracks[localPlayer.UserId] = nil
	end)

	-- Clean up tracks when players leave
	Players.PlayerRemoving:Connect(function(removingPlayer)
		playerTracks[removingPlayer.UserId] = nil
	end)
end

-- Public API: trigger a swing for local player
function controller:PlaySwing()
	playSwingForPlayer(localPlayer)
end

-- Public API: play swing animation for a specific player by userId (used for remote replication)
function controller:PlaySwingForUserId(userId)
	if not userId then
		return
	end
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if targetPlayer then
		-- Mark as remote so cooldown doesn't apply (server rate-limits)
		local isRemote = targetPlayer ~= localPlayer
		playSwingForPlayer(targetPlayer, isRemote)
	end
end

function controller:Cleanup()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
	isSwingHeld = false
	for _, trackData in pairs(playerTracks) do
		if trackData.track then
			pcall(function() trackData.track:Stop() end)
		end
	end
	playerTracks = {}
end

return controller
