--[[
	NPCController.lua
	Client-side NPC interactions and custom font application.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)

local NPCController = {}
local worldsPanel = nil

-- Apply custom font to NPC billboards
local function applyFont(textLabel)
	local success, FontBinder = pcall(function()
		return require(ReplicatedStorage.Shared.UI.FontBinder)
	end)
	if success and FontBinder then
		pcall(function() FontBinder.apply(textLabel, "Upheaval BRK") end)
	end
end

-- Handle server interaction response
local function handleInteraction(data)
	if not data then return end

	if data.interactionType == "WARP" and worldsPanel then
		worldsPanel:Open()
	end
end

-- Setup font for NPC folder
local function setupNPCFolder(folder)
	for _, desc in ipairs(folder:GetDescendants()) do
		if desc:IsA("TextLabel") then
			applyFont(desc)
		end
	end

	folder.DescendantAdded:Connect(function(desc)
		if desc:IsA("TextLabel") then
			task.defer(applyFont, desc)
		end
	end)
end

function NPCController:SetWorldsPanel(panel)
	worldsPanel = panel
end

function NPCController:Initialize()
	-- Preload font
	pcall(function()
		local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
		FontBinder.preload("Upheaval BRK")
	end)

	EventManager:ConnectToServer("NPCInteraction", handleInteraction)

	-- Setup fonts for NPC name tags
	local npcFolder = workspace:FindFirstChild("NPCs")
	if npcFolder then
		setupNPCFolder(npcFolder)
	else
		local conn
		conn = workspace.ChildAdded:Connect(function(child)
			if child.Name == "NPCs" then
				conn:Disconnect()
				setupNPCFolder(child)
			end
		end)
	end
end

return NPCController
