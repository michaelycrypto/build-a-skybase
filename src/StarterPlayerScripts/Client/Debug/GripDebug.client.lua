--[[
	GripDebug.lua
	Real-time grip position adjustment using keyboard keys.

	Controls:
	- Y/H: Y axis (up/down)
	- U/J: Z axis (forward/back)
	- I/K: X axis (left/right)
	- P: Print current grip values

	Step size: 0.05 studs per press
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeldItemRenderer = require(ReplicatedStorage.Shared.HeldItemRenderer)

local player = Players.LocalPlayer
local STEP = 0.05

local function updateGrip()
	local character = player.Character
	if character then
		HeldItemRenderer.DebugUpdateGrip(character)
	end
end

local function printGrip()
	local g = HeldItemRenderer.DebugGrip
	print("=== CURRENT GRIP ===")
	print(string.format("pos = Vector3.new(%.2f, %.2f, %.2f), rot = Vector3.new(%d, %d, %d)",
		g.pos.X, g.pos.Y, g.pos.Z, g.rot.X, g.rot.Y, g.rot.Z))
	print("====================")
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	local grip = HeldItemRenderer.DebugGrip
	local changed = false

	if input.KeyCode == Enum.KeyCode.Y then
		grip.pos = grip.pos + Vector3.new(0, STEP, 0)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.H then
		grip.pos = grip.pos + Vector3.new(0, -STEP, 0)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.U then
		grip.pos = grip.pos + Vector3.new(0, 0, -STEP)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.J then
		grip.pos = grip.pos + Vector3.new(0, 0, STEP)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.I then
		grip.pos = grip.pos + Vector3.new(STEP, 0, 0)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.K then
		grip.pos = grip.pos + Vector3.new(-STEP, 0, 0)
		changed = true
	elseif input.KeyCode == Enum.KeyCode.P then
		printGrip()
	end

	if changed then
		updateGrip()
		print(string.format("Grip pos: (%.2f, %.2f, %.2f)", grip.pos.X, grip.pos.Y, grip.pos.Z))
	end
end)

print("[GripDebug] Loaded - Y/H=Y axis, U/J=Z axis, I/K=X axis, P=Print")
