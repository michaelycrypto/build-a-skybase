--[[
	WorldsPanel.lua

	Lobby UI panel for creating and joining worlds.
	Shows My Worlds and Friends' Worlds tabs with world tiles.
	Integrates with PanelManager.
]]

local WorldsPanel = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Config = require(ReplicatedStorage.Shared.Config)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local IconManager = require(script.Parent.Parent.Managers.IconManager)

-- Services and instances
local player = Players.LocalPlayer

-- UI Elements
local panel = nil
local myWorldsTab = nil
local friendsWorldsTab = nil
local worldsScrollFrame = nil
local currentTab = "myWorlds"

-- Data
local myWorlds = {}
local friendsWorlds = {}

--[[
	Create content for PanelManager integration
]]
function WorldsPanel:CreateContent(contentFrame, data)
	panel = {contentFrame = contentFrame}

	-- Create New World button at top
	self:CreateNewWorldButton(contentFrame)

	-- Tab navigation
	self:CreateTabNavigation(contentFrame)

	-- Worlds scroll frame
	self:CreateWorldsScrollFrame(contentFrame)

	print("WorldsPanel: Created content")
end

--[[
	Create New World button
]]
function WorldsPanel:CreateNewWorldButton(parent)
	local button = Instance.new("TextButton")
	button.Name = "CreateWorldButton"
	button.Size = UDim2.new(1, -40, 0, 56)
	button.Position = UDim2.new(0, 20, 0, 20)
	button.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
	button.BorderSizePixel = 0
	button.Text = ""
	button.Parent = parent

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	buttonCorner.Parent = button

	-- Button text
	local buttonLabel = Instance.new("TextLabel")
	buttonLabel.Name = "Label"
	buttonLabel.Size = UDim2.new(1, -60, 1, 0)
	buttonLabel.Position = UDim2.new(0, 50, 0, 0)
	buttonLabel.BackgroundTransparency = 1
	buttonLabel.Text = "Create New World"
	buttonLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	buttonLabel.TextSize = Config.UI_SETTINGS.typography.sizes.ui.button
	buttonLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	buttonLabel.TextXAlignment = Enum.TextXAlignment.Left
	buttonLabel.Parent = button

	-- Plus symbol (text-based)
	local plusLabel = Instance.new("TextLabel")
	plusLabel.Name = "PlusIcon"
	plusLabel.Size = UDim2.new(0, 32, 0, 32)
	plusLabel.Position = UDim2.new(0, 15, 0.5, 0)
	plusLabel.AnchorPoint = Vector2.new(0, 0.5)
	plusLabel.BackgroundTransparency = 1
	plusLabel.Text = "+"
	plusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	plusLabel.TextSize = 28
	plusLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	plusLabel.Parent = button

	button.MouseButton1Click:Connect(function()
		print("[WorldsPanel] Creating new world...")
		EventManager:SendToServer("RequestCreateWorld", {})
	end)

	-- Store references for updating
	panel.createWorldButton = button
	panel.createWorldLabel = buttonLabel
end

--[[
	Create tab navigation
]]
function WorldsPanel:CreateTabNavigation(parent)
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -40, 0, 50)
	tabContainer.Position = UDim2.new(0, 20, 0, 96)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = parent

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.Parent = tabContainer

	-- My Worlds tab
	myWorldsTab = self:CreateTab("My Worlds", 1, function()
		self:SwitchTab("myWorlds")
	end)
	myWorldsTab.Parent = tabContainer

	-- Friends' Worlds tab
	friendsWorldsTab = self:CreateTab("Friends' Worlds", 2, function()
		self:SwitchTab("friendsWorlds")
	end)
	friendsWorldsTab.Parent = tabContainer

	-- Set initial active tab
	self:UpdateTabAppearance()
end

--[[
	Create a tab button
]]
function WorldsPanel:CreateTab(text, layoutOrder, callback)
	local tab = Instance.new("TextButton")
	tab.Name = text
	tab.Size = UDim2.new(0, 200, 1, 0)
	tab.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	tab.BorderSizePixel = 0
	tab.Text = text
	tab.TextColor3 = Config.UI_SETTINGS.colors.text
	tab.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	tab.Font = Config.UI_SETTINGS.typography.fonts.bold
	tab.LayoutOrder = layoutOrder

	local tabCorner = Instance.new("UICorner")
	tabCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	tabCorner.Parent = tab

	tab.MouseButton1Click:Connect(callback)

	return tab
end

--[[
	Switch active tab
]]
function WorldsPanel:SwitchTab(tabName)
	currentTab = tabName
	self:UpdateTabAppearance()
	self:RefreshWorldsList()
end

--[[
	Update tab appearance based on active tab
]]
function WorldsPanel:UpdateTabAppearance()
	if not myWorldsTab or not friendsWorldsTab then return end

	if currentTab == "myWorlds" then
		myWorldsTab.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.primary
		myWorldsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
		friendsWorldsTab.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		friendsWorldsTab.TextColor3 = Config.UI_SETTINGS.colors.text
	else
		myWorldsTab.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		myWorldsTab.TextColor3 = Config.UI_SETTINGS.colors.text
		friendsWorldsTab.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.primary
		friendsWorldsTab.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
end

--[[
	Create worlds scroll frame
]]
function WorldsPanel:CreateWorldsScrollFrame(parent)
	worldsScrollFrame = Instance.new("ScrollingFrame")
	worldsScrollFrame.Name = "WorldsScrollFrame"
	worldsScrollFrame.Size = UDim2.new(1, -40, 1, -176)
	worldsScrollFrame.Position = UDim2.new(0, 20, 0, 156)
	worldsScrollFrame.BackgroundTransparency = 1
	worldsScrollFrame.BorderSizePixel = 0
	worldsScrollFrame.ScrollBarThickness = 8
	worldsScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	worldsScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	worldsScrollFrame.Parent = parent

	local worldsLayout = Instance.new("UIListLayout")
	worldsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	worldsLayout.Padding = UDim.new(0, 12)
	worldsLayout.Parent = worldsScrollFrame
end

--[[
	Create a world tile
]]
function WorldsPanel:CreateWorldTile(worldData, layoutOrder)
	local tile = Instance.new("Frame")
	tile.Name = "WorldTile_" .. worldData.worldId
	tile.Size = UDim2.new(1, 0, 0, 120)
	tile.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	tile.BorderSizePixel = 0
	tile.LayoutOrder = layoutOrder
	tile.Parent = worldsScrollFrame

	local tileCorner = Instance.new("UICorner")
	tileCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	tileCorner.Parent = tile

	local tileStroke = Instance.new("UIStroke")
	tileStroke.Color = Config.UI_SETTINGS.colors.semantic.borders.subtle
	tileStroke.Thickness = 2
	tileStroke.Parent = tile

	-- World icon (left)
	local iconFrame = Instance.new("Frame")
	iconFrame.Name = "Icon"
	iconFrame.Size = UDim2.new(0, 80, 0, 80)
	iconFrame.Position = UDim2.new(0, 20, 0.5, 0)
	iconFrame.AnchorPoint = Vector2.new(0, 0.5)
	iconFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.background
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = tile

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	iconCorner.Parent = iconFrame

	IconManager:CreateIcon(iconFrame, "General", "Home", {
		size = UDim2.new(0, 48, 0, 48),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	})

	-- Slot badge (top-left of tile)
	local slotBadge = Instance.new("TextLabel")
	slotBadge.Name = "SlotBadge"
	slotBadge.Size = UDim2.new(0, 32, 0, 32)
	slotBadge.Position = UDim2.new(0, 8, 0, 8)
	slotBadge.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.primary
	slotBadge.BorderSizePixel = 0
	slotBadge.Text = tostring(worldData.slot or 1)
	slotBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	slotBadge.TextSize = 16
	slotBadge.Font = Config.UI_SETTINGS.typography.fonts.bold
	slotBadge.Parent = tile

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0.5, 0)
	badgeCorner.Parent = slotBadge

	-- World info (center)
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "Info"
	infoFrame.Size = UDim2.new(1, -340, 1, 0)
	infoFrame.Position = UDim2.new(0, 120, 0, 0)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = tile

	-- World name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.Position = UDim2.new(0, 0, 0, 15)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = worldData.name or "Unnamed World"
	nameLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	nameLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.large
	nameLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = infoFrame

	-- Status indicator
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, 0, 0, 24)
	statusLabel.Position = UDim2.new(0, 0, 0, 50)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = worldData.online and ("🟢 Online (" .. worldData.playerCount .. ")") or "⚫ Offline"
	statusLabel.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
	statusLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.small
	statusLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Parent = infoFrame

	-- Last played
	local lastPlayedLabel = Instance.new("TextLabel")
	lastPlayedLabel.Name = "LastPlayed"
	lastPlayedLabel.Size = UDim2.new(1, 0, 0, 20)
	lastPlayedLabel.Position = UDim2.new(0, 0, 0, 78)
	lastPlayedLabel.BackgroundTransparency = 1
	lastPlayedLabel.Text = self:FormatTimestamp(worldData.lastPlayed)
	lastPlayedLabel.TextColor3 = Config.UI_SETTINGS.colors.textMuted
	lastPlayedLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.xs
	lastPlayedLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
	lastPlayedLabel.TextXAlignment = Enum.TextXAlignment.Left
	lastPlayedLabel.Parent = infoFrame

	-- Action buttons (right)
	local actionsFrame = Instance.new("Frame")
	actionsFrame.Name = "Actions"
	actionsFrame.Size = UDim2.new(0, 140, 1, 0)
	actionsFrame.Position = UDim2.new(1, -160, 0, 0)
	actionsFrame.BackgroundTransparency = 1
	actionsFrame.Parent = tile

	local actionsLayout = Instance.new("UIListLayout")
	actionsLayout.FillDirection = Enum.FillDirection.Vertical
	actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionsLayout.Padding = UDim.new(0, 8)
	actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionsLayout.Parent = actionsFrame

	-- Play button
	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0, 120, 0, 40)
	playButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.primary
	playButton.BorderSizePixel = 0
	playButton.Text = "Play"
	playButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	playButton.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	playButton.Font = Config.UI_SETTINGS.typography.fonts.bold
	playButton.LayoutOrder = 1
	playButton.Parent = actionsFrame

	local playCorner = Instance.new("UICorner")
	playCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	playCorner.Parent = playButton

	playButton.MouseButton1Click:Connect(function()
		print("[WorldsPanel] Joining world:", worldData.worldId)
		EventManager:SendToServer("RequestJoinWorld", {worldId = worldData.worldId})
	end)

	-- Manage button (owner only)
	if worldData.ownerId == player.UserId then
		local manageButton = Instance.new("TextButton")
		manageButton.Name = "ManageButton"
		manageButton.Size = UDim2.new(0, 120, 0, 40)
		manageButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.secondary
		manageButton.BorderSizePixel = 0
		manageButton.Text = "Manage"
		manageButton.TextColor3 = Config.UI_SETTINGS.colors.text
		manageButton.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		manageButton.Font = Config.UI_SETTINGS.typography.fonts.bold
		manageButton.LayoutOrder = 2
		manageButton.Parent = actionsFrame

		local manageCorner = Instance.new("UICorner")
		manageCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
		manageCorner.Parent = manageButton

		manageButton.MouseButton1Click:Connect(function()
			self:OpenManageDialog(worldData)
		end)
	end

	return tile
end

--[[
	Format timestamp to relative time
]]
function WorldsPanel:FormatTimestamp(timestamp)
	if not timestamp or timestamp == 0 then
		return "Never played"
	end

	local now = os.time()
	local diff = now - timestamp

	if diff < 60 then
		return "Just now"
	elseif diff < 3600 then
		local minutes = math.floor(diff / 60)
		return minutes .. " minute" .. (minutes ~= 1 and "s" or "") .. " ago"
	elseif diff < 86400 then
		local hours = math.floor(diff / 3600)
		return hours .. " hour" .. (hours ~= 1 and "s" or "") .. " ago"
	else
		local days = math.floor(diff / 86400)
		return days .. " day" .. (days ~= 1 and "s" or "") .. " ago"
	end
end

--[[
	Refresh worlds list display
]]
function WorldsPanel:RefreshWorldsList()
	if not worldsScrollFrame then return end

	-- Clear existing tiles
	for _, child in ipairs(worldsScrollFrame:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("^WorldTile_") then
			child:Destroy()
		end
	end

	-- Display worlds based on active tab
	local worldsList = currentTab == "myWorlds" and myWorlds or friendsWorlds

	if #worldsList == 0 then
		-- Show empty state
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Name = "EmptyState"
		emptyLabel.Size = UDim2.new(1, 0, 0, 100)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = currentTab == "myWorlds" and "No worlds yet. Create one!" or "No friends' worlds available."
		emptyLabel.TextColor3 = Config.UI_SETTINGS.colors.textMuted
		emptyLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		emptyLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
		emptyLabel.Parent = worldsScrollFrame
	else
		-- Create tiles for each world
		for i, worldData in ipairs(worldsList) do
			self:CreateWorldTile(worldData, i)
		end
	end
end

--[[
	Open manage dialog for a world
]]
function WorldsPanel:OpenManageDialog(worldData)
	if not panel or not panel.contentFrame then return end

	-- Create backdrop (TextButton so it can be clicked)
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "ManageDialogBackdrop"
	backdrop.Size = UDim2.new(1, 0, 1, 0)
	backdrop.Position = UDim2.new(0, 0, 0, 0)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.AutoButtonColor = false
	backdrop.ZIndex = 100
	backdrop.Parent = panel.contentFrame

	-- Create dialog (TextButton to intercept clicks and prevent backdrop from closing)
	local dialog = Instance.new("TextButton")
	dialog.Name = "ManageDialog"
	dialog.Size = UDim2.new(0, 500, 0, 400)
	dialog.Position = UDim2.new(0.5, 0, 0.5, 0)
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.BackgroundColor3 = Config.UI_SETTINGS.colors.background
	dialog.BorderSizePixel = 0
	dialog.Text = ""
	dialog.AutoButtonColor = false
	dialog.ZIndex = 101
	dialog.Parent = panel.contentFrame

	local dialogCorner = Instance.new("UICorner")
	dialogCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.lg)
	dialogCorner.Parent = dialog

	local dialogStroke = Instance.new("UIStroke")
	dialogStroke.Color = Config.UI_SETTINGS.colors.semantic.borders.default
	dialogStroke.Thickness = 2
	dialogStroke.Parent = dialog

	-- Title
	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, -40, 0, 50)
	titleLabel.Position = UDim2.new(0, 20, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = "Manage World"
	titleLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.large
	titleLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = dialog

	-- Close button
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "CloseButton"
	closeButton.Size = UDim2.new(0, 40, 0, 40)
	closeButton.Position = UDim2.new(1, -50, 0, 10)
	closeButton.BackgroundTransparency = 1
	closeButton.Text = "✕"
	closeButton.TextColor3 = Config.UI_SETTINGS.colors.text
	closeButton.TextSize = 24
	closeButton.Font = Config.UI_SETTINGS.typography.fonts.bold
	closeButton.Parent = dialog

	-- Content container
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -40, 1, -120)
	contentContainer.Position = UDim2.new(0, 20, 0, 80)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = dialog

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 20)
	contentLayout.Parent = contentContainer

	-- World name input
	local nameSection = Instance.new("Frame")
	nameSection.Name = "NameSection"
	nameSection.Size = UDim2.new(1, 0, 0, 80)
	nameSection.BackgroundTransparency = 1
	nameSection.LayoutOrder = 1
	nameSection.Parent = contentContainer

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Label"
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "World Name"
	nameLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	nameLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	nameLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = nameSection

	local nameInput = Instance.new("TextBox")
	nameInput.Name = "Input"
	nameInput.Size = UDim2.new(1, 0, 0, 48)
	nameInput.Position = UDim2.new(0, 0, 0, 32)
	nameInput.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	nameInput.BorderSizePixel = 0
	nameInput.Text = worldData.name or ("World " .. (worldData.slot or 1))
	nameInput.TextColor3 = Config.UI_SETTINGS.colors.text
	nameInput.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	nameInput.Font = Config.UI_SETTINGS.typography.fonts.regular
	nameInput.PlaceholderText = "Enter world name..."
	nameInput.PlaceholderColor3 = Config.UI_SETTINGS.colors.textMuted
	nameInput.ClearTextOnFocus = false
	nameInput.Parent = nameSection

	local nameInputCorner = Instance.new("UICorner")
	nameInputCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	nameInputCorner.Parent = nameInput

	local nameInputStroke = Instance.new("UIStroke")
	nameInputStroke.Color = Config.UI_SETTINGS.colors.semantic.borders.subtle
	nameInputStroke.Thickness = 1
	nameInputStroke.Parent = nameInput

	-- World info
	local infoSection = Instance.new("Frame")
	infoSection.Name = "InfoSection"
	infoSection.Size = UDim2.new(1, 0, 0, 100)
	infoSection.BackgroundTransparency = 1
	infoSection.LayoutOrder = 2
	infoSection.Parent = contentContainer

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "Label"
	infoLabel.Size = UDim2.new(1, 0, 0, 24)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Text = "World Info"
	infoLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	infoLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	infoLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	infoLabel.TextXAlignment = Enum.TextXAlignment.Left
	infoLabel.Parent = infoSection

	local infoText = Instance.new("TextLabel")
	infoText.Name = "Text"
	infoText.Size = UDim2.new(1, 0, 0, 60)
	infoText.Position = UDim2.new(0, 0, 0, 32)
	infoText.BackgroundTransparency = 1
	infoText.Text = string.format("Slot: %d\nCreated: %s\nLast Played: %s",
		worldData.slot or 1,
		self:FormatTimestamp(worldData.created or 0),
		self:FormatTimestamp(worldData.lastPlayed or 0)
	)
	infoText.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
	infoText.TextSize = Config.UI_SETTINGS.typography.sizes.body.small
	infoText.Font = Config.UI_SETTINGS.typography.fonts.regular
	infoText.TextXAlignment = Enum.TextXAlignment.Left
	infoText.TextYAlignment = Enum.TextYAlignment.Top
	infoText.TextWrapped = true
	infoText.Parent = infoSection

	-- Buttons container
	local buttonsContainer = Instance.new("Frame")
	buttonsContainer.Name = "Buttons"
	buttonsContainer.Size = UDim2.new(1, 0, 0, 50)
	buttonsContainer.BackgroundTransparency = 1
	buttonsContainer.LayoutOrder = 3
	buttonsContainer.Parent = contentContainer

	local buttonsLayout = Instance.new("UIListLayout")
	buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
	buttonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	buttonsLayout.Padding = UDim.new(0, 12)
	buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	buttonsLayout.Parent = buttonsContainer

	-- Rename button
	local renameButton = Instance.new("TextButton")
	renameButton.Name = "RenameButton"
	renameButton.Size = UDim2.new(0, 140, 1, 0)
	renameButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.primary
	renameButton.BorderSizePixel = 0
	renameButton.Text = "Rename"
	renameButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	renameButton.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	renameButton.Font = Config.UI_SETTINGS.typography.fonts.bold
	renameButton.LayoutOrder = 1
	renameButton.Parent = buttonsContainer

	local renameCorner = Instance.new("UICorner")
	renameCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	renameCorner.Parent = renameButton

	-- Delete button
	local deleteButton = Instance.new("TextButton")
	deleteButton.Name = "DeleteButton"
	deleteButton.Size = UDim2.new(0, 140, 1, 0)
	deleteButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.danger
	deleteButton.BorderSizePixel = 0
	deleteButton.Text = "Delete"
	deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	deleteButton.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	deleteButton.Font = Config.UI_SETTINGS.typography.fonts.bold
	deleteButton.LayoutOrder = 2
	deleteButton.Parent = buttonsContainer

	local deleteCorner = Instance.new("UICorner")
	deleteCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
	deleteCorner.Parent = deleteButton

	-- Close handlers
	local function closeDialog()
		backdrop:Destroy()
		dialog:Destroy()
	end

	-- Close on backdrop click (clicking inside dialog won't trigger this)
	backdrop.MouseButton1Click:Connect(closeDialog)
	closeButton.MouseButton1Click:Connect(closeDialog)

	-- Rename handler
	renameButton.MouseButton1Click:Connect(function()
		local newName = nameInput.Text
		if newName and #newName > 0 then
			if newName ~= worldData.name then
				print("[WorldsPanel] Renaming world:", worldData.worldId, "to", newName)
				EventManager:SendToServer("UpdateWorldMetadata", {
					worldId = worldData.worldId,
					metadata = { name = newName }
				})
				closeDialog()
			else
				print("[WorldsPanel] Name unchanged, skipping rename")
			end
		else
			print("[WorldsPanel] Invalid name, cannot rename")
		end
	end)

	-- Delete handler (with confirmation)
	deleteButton.MouseButton1Click:Connect(function()
		-- Show confirmation
		deleteButton.Text = "Confirm?"
		deleteButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)

		local confirmed = false
		local confirmConnection
		confirmConnection = deleteButton.MouseButton1Click:Connect(function()
			if not confirmed then
				confirmed = true
				print("[WorldsPanel] Deleting world:", worldData.worldId)
				EventManager:SendToServer("DeleteWorld", { worldId = worldData.worldId })
				closeDialog()
			end
		end)

		-- Reset after 3 seconds if not confirmed
		task.delay(3, function()
			if not confirmed then
				deleteButton.Text = "Delete"
				deleteButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.danger
				confirmConnection:Disconnect()
			end
		end)
	end)
end

--[[
	Initialize the panel
]]
function WorldsPanel:Initialize()
	-- Listen for worlds list updates from server
	EventManager:RegisterEvent("WorldsListUpdated", function(data)
		myWorlds = data.myWorlds or {}
		friendsWorlds = data.friendsWorlds or {}
		local maxWorlds = data.maxWorlds or 5

		-- Update tab labels with counts
		if myWorldsTab then
			myWorldsTab.Text = "My Worlds (" .. #myWorlds .. " / " .. maxWorlds .. ")"
		end
		if friendsWorldsTab then
			friendsWorldsTab.Text = "Friends' Worlds (" .. #friendsWorlds .. ")"
		end

		-- Update create button state
		if panel and panel.createWorldButton and panel.createWorldLabel then
			local slotsLeft = maxWorlds - #myWorlds
			if slotsLeft <= 0 then
				-- Max worlds reached
				panel.createWorldButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.disabled
				panel.createWorldLabel.Text = "Maximum Worlds Reached (" .. maxWorlds .. "/" .. maxWorlds .. ")"
				panel.createWorldButton.Active = false
			else
				-- Slots available
				panel.createWorldButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
				panel.createWorldLabel.Text = "Create New World (" .. slotsLeft .. " slot" .. (slotsLeft ~= 1 and "s" or "") .. " left)"
				panel.createWorldButton.Active = true
			end
		end

		self:RefreshWorldsList()
		print("[WorldsPanel] Worlds list updated:", #myWorlds, "my worlds,", #friendsWorlds, "friends' worlds,", maxWorlds, "max")
	end)

	-- Listen for world deletion
	EventManager:RegisterEvent("WorldDeleted", function(data)
		if data.success then
			print("[WorldsPanel] World deleted:", data.worldId)
			-- Request updated list
			EventManager:SendToServer("RequestWorldsList", {})
		end
	end)

	-- Listen for world metadata updates
	EventManager:RegisterEvent("WorldMetadataUpdated", function(data)
		print("[WorldsPanel] World metadata updated:", data.worldId)
		-- Request updated list
		EventManager:SendToServer("RequestWorldsList", {})
	end)

	print("WorldsPanel: Initialized")
end

return WorldsPanel
