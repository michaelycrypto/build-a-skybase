--[[
	SprintController.lua
	Manages sprint functionality
	- Hold Left Shift to sprint (WalkSpeed 20)
	- Release to return to normal walk speed (16)
	- Disabled while swimming (SwimmingController integration)
]]

local Players = game:GetService("Players")
local InputService = require(script.Parent.Parent.Input.InputService)

local SprintController = {}

-- References
local player = Players.LocalPlayer
local character = nil
local humanoid = nil

-- Swimming controller reference (for checking if player is swimming)
local swimmingController = nil

-- Settings
local NORMAL_WALKSPEED = 14
local SPRINT_WALKSPEED = 20

-- State
local isSprinting = false
local sprintInputHeld = false -- Track if sprint key is held (separate from actual sprinting)

local function setupCharacter(char)
	-- Wait for humanoid
	local hum = char:WaitForChild("Humanoid")

	-- Set default walkspeed
	hum.WalkSpeed = NORMAL_WALKSPEED

	return hum
end

--[[
	Check if sprinting is allowed (not swimming).
]]
local function canSprint()
	-- Can't sprint while swimming
	if swimmingController and swimmingController:IsSwimming() then
		return false
	end
	return true
end

local function startSprint()
	if not humanoid or isSprinting then return end
	
	-- Don't start sprint if swimming
	if not canSprint() then return end

	isSprinting = true
	humanoid.WalkSpeed = SPRINT_WALKSPEED
end

local function stopSprint()
	if not humanoid or not isSprinting then return end

	isSprinting = false
	-- Only reset to normal speed if not swimming (swimming manages its own speed)
	if not swimmingController or not swimmingController:IsInWater() then
		humanoid.WalkSpeed = NORMAL_WALKSPEED
	end
end

--[[
	Set sprint state programmatically (for mobile toggle)
	@param enabled boolean - true to sprint, false to stop
]]
function SprintController:SetSprinting(enabled)
	if enabled then
		sprintInputHeld = true
		startSprint()
	else
		sprintInputHeld = false
		stopSprint()
	end
end

--[[
	Check if currently sprinting
	@return boolean
]]
function SprintController:IsSprinting()
	return isSprinting
end

--[[
	Set the swimming controller reference.
	Used to check if player is swimming (sprint disabled while swimming).
	@param controller SwimmingController
]]
function SprintController:SetSwimmingController(controller)
	swimmingController = controller
end

--[[
	Called by other systems when swimming state changes.
	If sprint key was held when entering water, resume sprinting on exit.
]]
function SprintController:OnWaterStateChanged(isInWater)
	if isInWater then
		-- Stop sprinting when entering water
		if isSprinting then
			stopSprint()
		end
	else
		-- Resume sprinting if key is still held
		if sprintInputHeld and canSprint() then
			startSprint()
		end
	end
end

function SprintController:Initialize()
	-- Handle character spawn/respawn (non-blocking - character may not exist yet)
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		humanoid = setupCharacter(newCharacter)
		isSprinting = false
		sprintInputHeld = false
	end)
	
	-- Setup existing character if present
	if player.Character then
		character = player.Character
		humanoid = setupCharacter(character)
	end

	-- Handle sprint input (Left Shift)
	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintInputHeld = true
			startSprint()
		end
	end)

	InputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			sprintInputHeld = false
			stopSprint()
		end
	end)
end

return SprintController

