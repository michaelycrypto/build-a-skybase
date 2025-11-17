-- Legacy MinionUIController is disabled to avoid duplicate Minion UI panels.
-- New implementation lives in `src/StarterPlayerScripts/Client/UI/MinionUI.lua`.
local ENABLE_LEGACY_MINION_UI = false
if not ENABLE_LEGACY_MINION_UI then
	return {}
end

--[[
	MinionUIController.lua
	Client-side UI for Cobblestone Minion interaction
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local MinionUIController = {}

local gui -- ScreenGui
local frame -- main frame
local slots = {}
local lastPos = nil
local state = nil

local function ensureGui()
	if gui and gui.Parent then return end
	gui = Instance.new("ScreenGui")
	gui.Name = "MinionUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 80
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local function clearChildren(parent)
	for _, c in ipairs(parent:GetChildren()) do
		c:Destroy()
	end
end

local function renderUI()
	if not state then return end
	ensureGui()
	if not frame or not frame.Parent then
		frame = Instance.new("Frame")
		frame.Name = "Panel"
		frame.Size = UDim2.new(0, 420, 0, 360)
		frame.Position = UDim2.new(0.5, -210, 0.5, -180)
		frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
		frame.BackgroundTransparency = 0.1
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = frame
	end

	clearChildren(frame)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.new(0, 10, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local roman = ({[1]="I",[2]="II",[3]="III",[4]="IV"})[state.level or 1] or "I"
	title.Text = string.format("Cobblestone Minion  (Level %s)", roman)
	title.Parent = frame

	local waitLabel = Instance.new("TextLabel")
	waitLabel.Size = UDim2.new(1, -20, 0, 22)
	waitLabel.Position = UDim2.new(0, 10, 0, 40)
	waitLabel.BackgroundTransparency = 1
	waitLabel.Font = Enum.Font.Gotham
	waitLabel.TextSize = 16
	waitLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	waitLabel.TextXAlignment = Enum.TextXAlignment.Left
	waitLabel.Text = string.format("Action interval: %ds", state.waitSeconds or 15)
	waitLabel.Parent = frame

	-- Slots grid (12)
	local gridFrame = Instance.new("Frame")
	gridFrame.Size = UDim2.new(1, -20, 0, 210)
	gridFrame.Position = UDim2.new(0, 10, 0, 70)
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = frame

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 60, 0, 60)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.FillDirectionMaxCells = 6
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = gridFrame

	for i = 1, 12 do
		local slot = Instance.new("Frame")
		slot.Name = "Slot" .. i
		slot.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		slot.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = slot
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Text = (i <= (state.slotsUnlocked or 1)) and "" or "Locked"
		slot.Parent = gridFrame
		slots[i] = slot
	end

	local upgradeBtn = Instance.new("TextButton")
	upgradeBtn.Size = UDim2.new(0, 180, 0, 36)
	upgradeBtn.Position = UDim2.new(0, 10, 1, -46)
	upgradeBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	upgradeBtn.BorderSizePixel = 0
	upgradeBtn.AutoButtonColor = true
	upgradeBtn.Font = Enum.Font.GothamBold
	upgradeBtn.TextSize = 16
	upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	local maxLevel = state.maxLevel or 4
	if (state.level or 1) >= maxLevel then
		upgradeBtn.Text = "Max Level"
		upgradeBtn.Active = false
		upgradeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	else
		upgradeBtn.Text = string.format("Upgrade (Cost: %d Cobblestone)", state.costNext or 0)
		upgradeBtn.MouseButton1Click:Connect(function()
			EventManager:SendToServer("RequestMinionUpgrade", {
				x = lastPos.x, y = lastPos.y, z = lastPos.z
			})
		end)
	end
	upgradeBtn.Parent = frame

	local closeBtn = Instance.new("TextButton")
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -46, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(90, 90, 90)
	closeBtn.BorderSizePixel = 0
	closeBtn.AutoButtonColor = true
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "X"
	closeBtn.Parent = frame
	closeBtn.MouseButton1Click:Connect(function()
		if gui then gui:Destroy() gui = nil end
		frame = nil
		slots = {}
		state = nil
		lastPos = nil
	end)
end

-- Listen for server events
EventManager:ConnectToServer("MinionOpened", function(data)
	if not data then return end
	lastPos = { x = data.x, y = data.y, z = data.z }
	state = {
		level = data.level,
		slotsUnlocked = data.slotsUnlocked,
		waitSeconds = data.waitSeconds,
		maxLevel = data.maxLevel,
		maxSlots = data.maxSlots,
		costNext = data.costNext
	}
	renderUI()
end)

EventManager:ConnectToServer("MinionUpdated", function(data)
	if not data then return end
	if not lastPos or not (data.x == lastPos.x and data.y == lastPos.y and data.z == lastPos.z) then
		return
	end
	state.level = data.level
	state.slotsUnlocked = data.slotsUnlocked
	state.waitSeconds = data.waitSeconds
	state.costNext = data.costNext
	renderUI()
end)

return MinionUIController


