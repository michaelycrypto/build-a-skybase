--[[
	MobHeadTool.client.lua - Client script for Mob Head tools

	This script handles:
	- Mob head tool activation
	- Interaction with spawner locations
	- Visual feedback for valid targets
--]]

local tool = script.Parent
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Import dependencies
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Logger = require(ReplicatedStorage.Shared.Logger)

-- Tool state
local isEquipped = false
local currentTarget = nil
local highlightConnection = nil

-- Visual feedback
local function createHighlight(part)
	local highlight = Instance.new("SelectionBox")
	highlight.Adornee = part
	highlight.Color3 = Color3.fromRGB(0, 255, 0) -- Green for valid target
	highlight.LineThickness = 0.2
	highlight.Transparency = 0.5
	highlight.Parent = part
	return highlight
end

local function removeHighlight(part)
	local highlight = part:FindFirstChild("SelectionBox")
	if highlight then
		highlight:Destroy()
	end
end

-- Check if a part is a valid unlocked spawner location
local function isValidSpawnerLocation(part)
	if not part or not part.Parent then return false end

	-- Check if it's a SpawnerSlot part that can accept mob heads
	if part.Name == "SpawnerSlot" then
		local slotState = part:GetAttribute("SlotState")
		local hasMobHead = part:GetAttribute("HasMobHead")

		-- Valid if unlocked and doesn't have a mob head, or if it has a mob head (for removal)
		if slotState == "unlocked" and not hasMobHead then
			return true
		elseif slotState == "mob_head_placed" or hasMobHead then
			return true
		end
	end

	return false
end

-- Handle mouse movement for highlighting
local function onMouseMove()
	if not isEquipped then return end

	local target = mouse.Target
	local newTarget = nil

	if target and isValidSpawnerLocation(target) then
		newTarget = target
	end

	-- Update highlighting
	if currentTarget ~= newTarget then
		-- Remove old highlight
		if currentTarget then
			removeHighlight(currentTarget)
		end

		-- Add new highlight
		if newTarget then
			createHighlight(newTarget)
		end

		currentTarget = newTarget
	end
end

-- Handle tool activation (clicking)
local function onActivated()
	if not currentTarget then
		Logger:Info("MobHeadTool", "No valid target selected")
		return
	end

	-- Get mob head info
	local mobHeadType = tool:GetAttribute("MobHeadType")
	local mobHeadId = tool:GetAttribute("MobHeadId")

	if not mobHeadType then
		Logger:Error("MobHeadTool", "No mob head type found on tool")
		return
	end

	-- Get slot index from the spawner slot part
	local slotIndex = currentTarget:GetAttribute("SlotIndex")

	if not slotIndex then
		Logger:Error("MobHeadTool", "No slot index found on spawner slot part")
		return
	end

	-- Check current state to determine action
	local hasMobHead = currentTarget:GetAttribute("HasMobHead")
	local slotState = currentTarget:GetAttribute("SlotState")

	if hasMobHead or slotState == "mob_head_placed" then
		-- Remove mob head
		Logger:Info("MobHeadTool", "Attempting to remove mob head from spawner", {
			slotIndex = slotIndex
		})

		-- Send removal request to server
		EventManager:SendToServer("RemoveMobHead", slotIndex)
	else
		-- Deposit mob head
		Logger:Info("MobHeadTool", "Attempting to equip mob head to spawner", {
			mobHeadType = mobHeadType,
			mobHeadId = mobHeadId,
			slotIndex = slotIndex
		})

		-- Send deposit request to server
		EventManager:SendToServer("DepositMobHead", slotIndex, mobHeadType)
	end

	-- Create feedback UI
	local gui = player.PlayerGui:FindFirstChild("ScreenGui")
	if gui then
		-- Create temporary feedback message
		local feedback = Instance.new("TextLabel")
		feedback.Size = UDim2.new(0, 300, 0, 50)
		feedback.Position = UDim2.new(0.5, -150, 0.5, -25)
		feedback.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		feedback.BackgroundTransparency = 0.3
		feedback.TextColor3 = Color3.fromRGB(255, 255, 255)
		feedback.TextScaled = true
		feedback.Font = Enum.Font.GothamBold
		feedback.Parent = gui

		-- Set appropriate text based on action
		if hasMobHead or slotState == "mob_head_placed" then
			feedback.Text = "Removing mob head..."
		else
			feedback.Text = "Depositing " .. tool.Name .. "..."
		end

		-- Fade out after 2 seconds
		game:GetService("TweenService"):Create(feedback, TweenInfo.new(2, Enum.EasingStyle.Quad), {
			BackgroundTransparency = 1,
			TextTransparency = 1
		}):Play()

		game:GetService("Debris"):AddItem(feedback, 2.5)
	end
end

-- Handle tool equipped
local function onEquipped()
	isEquipped = true
	Logger:Info("MobHeadTool", "Mob head tool equipped", {
		toolName = tool.Name,
		mobHeadType = tool:GetAttribute("MobHeadType")
	})

	-- Start mouse movement tracking
	highlightConnection = mouse.Move:Connect(onMouseMove)

	-- Change mouse icon to indicate tool mode
	mouse.Icon = "rbxasset://textures/ArrowCursor.png"
end

-- Handle tool unequipped
local function onUnequipped()
	isEquipped = false
	Logger:Info("MobHeadTool", "Mob head tool unequipped")

	-- Stop mouse movement tracking
	if highlightConnection then
		highlightConnection:Disconnect()
		highlightConnection = nil
	end

	-- Remove any current highlighting
	if currentTarget then
		removeHighlight(currentTarget)
		currentTarget = nil
	end

	-- Reset mouse icon
	mouse.Icon = ""
end

-- Connect tool events
tool.Activated:Connect(onActivated)
tool.Equipped:Connect(onEquipped)
tool.Unequipped:Connect(onUnequipped)

Logger:Info("MobHeadTool", "Mob head tool script loaded", {
	toolName = tool.Name
})
