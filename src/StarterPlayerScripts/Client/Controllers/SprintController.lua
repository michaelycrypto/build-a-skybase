--[[
	SprintController.lua
	Manages sprint functionality
	- Hold Left Shift to sprint (WalkSpeed 20)
	- Release to return to normal walk speed (16)
]]

local Players = game:GetService("Players")
local InputService = require(script.Parent.Parent.Input.InputService)

local SprintController = {}

-- References
local player = Players.LocalPlayer
local character = nil
local humanoid = nil

-- Settings
local NORMAL_WALKSPEED = 14
local SPRINT_WALKSPEED = 20

-- State
local isSprinting = false

local function setupCharacter(char)
	-- Wait for humanoid
	local hum = char:WaitForChild("Humanoid")

	-- Set default walkspeed
	hum.WalkSpeed = NORMAL_WALKSPEED

	return hum
end

local function startSprint()
	if not humanoid or isSprinting then return end

	isSprinting = true
	humanoid.WalkSpeed = SPRINT_WALKSPEED
end

local function stopSprint()
	if not humanoid or not isSprinting then return end

	isSprinting = false
	humanoid.WalkSpeed = NORMAL_WALKSPEED
end

--[[
	Set sprint state programmatically (for mobile toggle)
	@param enabled boolean - true to sprint, false to stop
]]
function SprintController:SetSprinting(enabled)
	if enabled then
		startSprint()
	else
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

function SprintController:Initialize()
	-- Setup character
	character = player.Character or player.CharacterAdded:Wait()
	humanoid = setupCharacter(character)

	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		character = newCharacter
		humanoid = setupCharacter(newCharacter)
		isSprinting = false
	end)

	-- Handle sprint input (Left Shift)
	InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.LeftShift then
			startSprint()
		end
	end)

	InputService.InputEnded:Connect(function(input, gameProcessed)
		if input.KeyCode == Enum.KeyCode.LeftShift then
			stopSprint()
		end
	end)
end

return SprintController

