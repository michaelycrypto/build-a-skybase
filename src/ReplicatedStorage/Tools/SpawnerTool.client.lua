--[[
	SpawnerTool.lua - Tool script for Spawner items

	This script handles the behavior of Spawner Tools that players can hold.
	When equipped, players can interact with dungeon slots to place spawners.
--]]

local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Logger = require(ReplicatedStorage.Shared.Logger)

-- Tool state
local player = nil
local character = nil
local humanoid = nil
local isEquipped = false

-- Tool configuration (set by server when creating the tool)
local spawnerType = Tool:GetAttribute("SpawnerType") or "goblin_spawner"
local spawnerId = Tool:GetAttribute("SpawnerId") or ""

--[[
	Handle tool equipped
--]]
function onEquipped()
	player = Players.LocalPlayer
	character = Tool.Parent
	humanoid = character:WaitForChild("Humanoid")
	isEquipped = true

	Logger:Info("SpawnerTool", "Spawner tool equipped", {
		spawnerType = spawnerType,
		spawnerId = spawnerId,
		playerName = player.Name
	})

	-- Notify the system that this tool is equipped
	local success, error = pcall(function()
		EventManager:SendToServer("SpawnerToolEquipped", {
			spawnerType = spawnerType,
			spawnerId = spawnerId
		})
	end)

	if not success then
		Logger:Warn("SpawnerTool", "Failed to send SpawnerToolEquipped event", {
			error = error,
			spawnerType = spawnerType,
			spawnerId = spawnerId
		})
	end
end

--[[
	Handle tool unequipped
--]]
function onUnequipped()
	isEquipped = false

	Logger:Info("SpawnerTool", "Spawner tool unequipped", {
		spawnerType = spawnerType,
		spawnerId = spawnerId,
		playerName = player and player.Name or "Unknown"
	})

	-- Notify the system that this tool is unequipped
	if player then
		local success, error = pcall(function()
			EventManager:SendToServer("SpawnerToolUnequipped", {
				spawnerType = spawnerType,
				spawnerId = spawnerId
			})
		end)

		if not success then
			Logger:Warn("SpawnerTool", "Failed to send SpawnerToolUnequipped event", {
				error = error,
				spawnerType = spawnerType,
				spawnerId = spawnerId
			})
		end
	end

	player = nil
	character = nil
	humanoid = nil
end

--[[
	Handle tool activation (clicking)
--]]
function onActivated()
	if not isEquipped or not player then return end

	Logger:Debug("SpawnerTool", "Spawner tool activated", {
		spawnerType = spawnerType,
		spawnerId = spawnerId
	})

	-- Tool activation doesn't directly place spawners
	-- Placement happens through proximity prompt interaction
	-- This could be used for other tool-specific actions if needed
end

-- Connect tool events
Tool.Equipped:Connect(onEquipped)
Tool.Unequipped:Connect(onUnequipped)
Tool.Activated:Connect(onActivated)

-- Update tool attributes when they change
Tool.AttributeChanged:Connect(function(attributeName)
	if attributeName == "SpawnerType" then
		spawnerType = Tool:GetAttribute("SpawnerType") or "goblin_spawner"
	elseif attributeName == "SpawnerId" then
		spawnerId = Tool:GetAttribute("SpawnerId") or ""
	end
end)
