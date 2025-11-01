--[[
	ToolAnimationController.lua
	Plays R15 swing animation when a sword tool is equipped and player left-clicks.
	Uses Animator:LoadAnimation for R15 compatibility.
]]

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- No state gating; animation plays universally on left-click

local controller = {}

local player = Players.LocalPlayer
-- Default animation for punch/tools: Rotate Slash
local SWING_ANIMATION_IDS = {
	"rbxassetid://675025570", -- Rotate Slash (default)
}
local FALLBACK_ANIM_ID = "rbxassetid://675025570"

local animationCache = {} -- animId -> Animation
local swingTrack -- AnimationTrack
local lastSwingTime = 0
local SWING_COOLDOWN = 0.2 -- seconds (allow frequent repeats while mining)
local currentAnimIndex = 0

local function getAnimator()
	local character = player.Character
	if not character then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function ensureSwingTrack(animId)
	local animator = getAnimator()
	if not animator then return nil end
	local anim = animationCache[animId]
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = animId
		animationCache[animId] = anim
	end
	pcall(function()
		if swingTrack then swingTrack:Stop() end
	end)
	swingTrack = animator:LoadAnimation(anim)
	return swingTrack
end

-- No equip-gating: always play on left-click

local function playSwing()
	local now = os.clock()
	if (now - lastSwingTime) < SWING_COOLDOWN then return end
	-- Choose next animation id in cycle
	local animId = nil
	if #SWING_ANIMATION_IDS > 0 then
		currentAnimIndex = (currentAnimIndex % #SWING_ANIMATION_IDS) + 1
		animId = SWING_ANIMATION_IDS[currentAnimIndex]
	else
		animId = FALLBACK_ANIM_ID
	end
	local track = ensureSwingTrack(animId)
	if not track then return end
	lastSwingTime = now
    pcall(function()
        local speed = 10 -- Rotate Slash at 10x speed
        track:Play(0.05, 1, speed)
    end)
end

function controller:Initialize()
	-- Input hook
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            playSwing()
        end
    end)

	-- Character reset handling
	player.CharacterAdded:Connect(function()
		swingTrack = nil -- force reload on new character
	end)
end

-- Public API: allow other systems to trigger a swing (e.g., on PlayerPunched)
function controller:PlaySwing()
    playSwing()
end

function controller:Cleanup()
	pcall(function()
		if swingTrack then swingTrack:Stop() end
	end)
	swingTrack = nil
end

return controller


