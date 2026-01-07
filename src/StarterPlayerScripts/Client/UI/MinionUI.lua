--[[
	MinionUI.lua
	Minion management interface matching Chest/Inventory visual style
	Shows minion slots (12 max), level, upgrade, collect all, and pickup
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local Config = require(ReplicatedStorage.Shared.Config)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)

local MinionUI = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
MinionUI.__index = MinionUI

-- Configuration matching ChestUI/Inventory
local CONFIG = {
	COLUMNS = 4,
	ROWS = 3, -- 12 slots total (3 rows × 4 columns)
	SLOT_SIZE = 44,
	SLOT_SPACING = 3,
	PADDING = 6,
	SECTION_SPACING = 12,
	BUTTON_HEIGHT = 36,
	BUTTON_SPACING = 8,
	RIGHT_PANEL_WIDTH = 200, -- Width for action buttons section

	-- Colors
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
	LOCKED_COLOR = Color3.fromRGB(30, 30, 30),
}

-- Helper function to get display name for any item type
local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then
		return nil
	end

	-- Check if it's a tool
	if ToolConfig.IsTool(itemId) then
		local toolInfo = ToolConfig.GetToolInfo(itemId)
		return toolInfo and toolInfo.name or "Tool"
	end

	-- Check if it's armor
	if ArmorConfig.IsArmor(itemId) then
		local armorInfo = ArmorConfig.GetArmorInfo(itemId)
		return armorInfo and armorInfo.name or "Armor"
	end

	-- Check if it's a spawn egg
	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local eggInfo = SpawnEggConfig.GetEggInfo(itemId)
		return eggInfo and eggInfo.name or "Spawn Egg"
	end

	-- Otherwise, it's a block - use BlockRegistry
	local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local blockDef = BlockRegistry.Blocks[itemId]
	return blockDef and blockDef.name or "Item"
end

function MinionUI.new(inventoryManager, inventoryPanel, chestUI)
	local self = setmetatable({}, MinionUI)

	self.inventoryManager = inventoryManager
	self.inventoryPanel = inventoryPanel
	self.chestUI = chestUI
	self.isOpen = false
	self.gui = nil
	self.panel = nil
	self.anchorPos = nil -- {x, y, z}
	self.hoverItemLabel = nil  -- Label for displaying hovered item name

	-- Minion state
	self.level = 1
	self.slotsUnlocked = 1
	self.waitSeconds = 15
	self.nextUpgradeCost = 32

	-- Minion slots (12 max)
	self.slots = {}
	self.slotFrames = {}
	for i = 1, 12 do
		self.slots[i] = ItemStack.new(0, 0)
	end

	self.connections = {}
	self.tooltip = nil

	return self
end

function MinionUI:CreateTooltip()
	-- Create tooltip (hidden by default)
	self.tooltip = Instance.new("Frame")
	self.tooltip.Name = "Tooltip"
	self.tooltip.Size = UDim2.new(0, 150, 0, 50)
	self.tooltip.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	self.tooltip.BorderSizePixel = 0
	self.tooltip.Visible = false
	self.tooltip.ZIndex = 1000
	self.tooltip.Parent = self.gui

	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, 4)
	tooltipCorner.Parent = self.tooltip

	local tooltipStroke = Instance.new("UIStroke")
	tooltipStroke.Color = Color3.fromRGB(80, 80, 80)
	tooltipStroke.Thickness = 2
	tooltipStroke.Parent = self.tooltip

	local tooltipText = Instance.new("TextLabel")
	tooltipText.Name = "Text"
	tooltipText.Size = UDim2.new(1, -8, 1, -8)
	tooltipText.Position = UDim2.new(0, 4, 0, 4)
	tooltipText.BackgroundTransparency = 1
	tooltipText.Font = BOLD_FONT
	tooltipText.TextSize = 12
	tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
	tooltipText.TextWrapped = true
	tooltipText.TextXAlignment = Enum.TextXAlignment.Left
	tooltipText.TextYAlignment = Enum.TextYAlignment.Top
	tooltipText.Parent = self.tooltip
end

function MinionUI:ShowTooltip(slot, itemId, count)
	if not self.tooltip then return end

	local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
	local block = BlockRegistry:GetBlock(itemId)
	local name = block.name or "Unknown"

	local text = string.format("%s\nCount: %d", name, count)
	self.tooltip:FindFirstChild("Text").Text = text

	-- Position near mouse
	local mousePos = UserInputService:GetMouseLocation()
	self.tooltip.Position = UDim2.new(0, mousePos.X + 15, 0, mousePos.Y + 15)
	self.tooltip.Visible = true
end

function MinionUI:HideTooltip()
	if self.tooltip then
		self.tooltip.Visible = false
	end
end

function MinionUI:CreateHoverItemLabel()
	-- Create a label in the top left of the screen to display hovered item name
	local label = Instance.new("TextLabel")
	label.Name = "HoverItemLabel"
	label.Size = UDim2.new(0, 400, 0, 40)
	label.Position = UDim2.new(0, 20, 0, 20)
	label.AnchorPoint = Vector2.new(0, 0)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	label.BackgroundTransparency = 0.3
	label.BorderSizePixel = 0
	label.Font = BOLD_FONT
	label.TextSize = 24
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.5
	label.Text = ""
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Visible = false
	label.ZIndex = 10
	label.AutomaticSize = Enum.AutomaticSize.X
	label.Parent = self.gui

	-- Add padding for text
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label

	-- Add rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label

	-- Add subtle border
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(60, 60, 60)
	border.Thickness = 1
	border.Parent = label

	self.hoverItemLabel = label
end

function MinionUI:ShowHoverItemName(itemId)
	if not self.hoverItemLabel then return end

	local itemName = GetItemDisplayName(itemId)
	if itemName then
		self.hoverItemLabel.Text = itemName
		self.hoverItemLabel.Visible = true
	else
		self.hoverItemLabel.Visible = false
	end
end

function MinionUI:HideHoverItemName()
	if not self.hoverItemLabel then return end
	self.hoverItemLabel.Visible = false
end

function MinionUI:Initialize()
	if self._initialized then
		return self
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Reuse existing ScreenGui if present; remove extras
	local existing = nil
	for _, child in ipairs(playerGui:GetChildren()) do
		if child:IsA("ScreenGui") and child.Name == "MinionUI" then
			if not existing then
				existing = child
			else
				-- Remove duplicate legacy instances
				child:Destroy()
			end
		end
	end

	if existing then
		self.gui = existing
	else
		-- Create ScreenGui
		self.gui = Instance.new("ScreenGui")
		self.gui.Name = "MinionUI"
		self.gui.ResetOnSpawn = false
		self.gui.DisplayOrder = 150
		self.gui.IgnoreGuiInset = true
		self.gui.Enabled = false
		self.gui.Parent = playerGui
	end

	-- Add responsive scaling
	if not self.gui:FindFirstChild("ResponsiveScale") then
		local uiScale = Instance.new("UIScale")
		uiScale.Name = "ResponsiveScale"
		uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
		uiScale.Parent = self.gui
		CollectionService:AddTag(uiScale, "scale_component")
	end

	-- Create hover item name label (top left of screen)
	if not self.hoverItemLabel then
		self:CreateHoverItemLabel()
	end

	-- Create panel/tooltip once
	if not self.panel or not self.panel.Parent then
		self:CreatePanel()
	end
	if not self.tooltip then
		self:CreateTooltip()
	end

	-- Register events once
	if not self._eventsRegistered then
		self:RegisterEvents()
		self._eventsRegistered = true
	end

	self._initialized = true

	return self
end

function MinionUI:CreatePanel()
	local slotsWidth = CONFIG.SLOT_SIZE * CONFIG.COLUMNS + CONFIG.SLOT_SPACING * (CONFIG.COLUMNS - 1)
	local slotsHeight = CONFIG.SLOT_SIZE * CONFIG.ROWS + CONFIG.SLOT_SPACING * (CONFIG.ROWS - 1)

	-- Total width: padding + slots + spacing + right panel + padding
	local totalWidth = CONFIG.PADDING + slotsWidth + CONFIG.SECTION_SPACING + CONFIG.RIGHT_PANEL_WIDTH + CONFIG.PADDING

	-- Total height: padding + info section + slots + padding
	local totalHeight = 30 + 40 + CONFIG.SECTION_SPACING + slotsHeight + 10

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.ZIndex = 0
	overlay.Parent = self.gui

	-- Main panel
	self.panel = Instance.new("Frame")
	self.panel.Name = "MinionPanel"
	self.panel.Size = UDim2.new(0, totalWidth, 0, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundColor3 = CONFIG.BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.ZIndex = 1
	self.panel.Parent = self.gui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.panel

	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = CONFIG.BORDER_COLOR
	stroke.Thickness = 3
	stroke.Parent = self.panel

	-- Header frame
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, 1)
	headerFrame.BackgroundTransparency = 1
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = self.panel

	-- Title container
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -64 - 16, 1, 0)
	titleContainer.Position = UDim2.new(0, 0, -0.5, 0)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = headerFrame

	local titlePadding = Instance.new("UIPadding")
	titlePadding.PaddingLeft = UDim.new(0, 6)
	titlePadding.PaddingRight = UDim.new(0, 16)
	titlePadding.Parent = titleContainer

	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 12)
	titleLayout.Parent = titleContainer

	-- Title icon (pickaxe emoji as fallback)
	local titleIcon = Instance.new("TextLabel")
	titleIcon.Name = "TitleIcon"
	titleIcon.Size = UDim2.new(0, 36, 0, 36)
	titleIcon.BackgroundTransparency = 1
	titleIcon.Text = "⛏️"
	titleIcon.TextSize = 28
	titleIcon.LayoutOrder = 1
	titleIcon.Parent = titleContainer

	-- Title text
	self.titleLabel = Instance.new("TextLabel")
	self.titleLabel.Name = "Title"
	self.titleLabel.Size = UDim2.new(0, 300, 1, 0)
	self.titleLabel.BackgroundTransparency = 1
	self.titleLabel.RichText = true
	self.titleLabel.Text = "<b><i>Cobblestone Minion I</i></b>"
	self.titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.titleLabel.TextSize = 36
	self.titleLabel.Font = BOLD_FONT
	self.titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.titleLabel.LayoutOrder = 2
	self.titleLabel.Parent = titleContainer

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(0, 0, 0)
	titleStroke.Thickness = 2
	titleStroke.Parent = self.titleLabel

	-- Close button
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.new(0, 40, 0, 40),
		position = UDim2.new(1, 2, 0, -2),
		anchorPoint = Vector2.new(0.5, 0.5)
	})

	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = closeIcon.Size
	closeBtn.Position = closeIcon.Position
	closeBtn.AnchorPoint = closeIcon.AnchorPoint
	closeBtn.BackgroundTransparency = 1
	closeBtn.Image = closeIcon.Image
	closeBtn.ScaleType = closeIcon.ScaleType
	closeBtn.Parent = headerFrame

	local closeButtonCorner = Instance.new("UICorner")
	closeButtonCorner.CornerRadius = UDim.new(0, 4)
	closeButtonCorner.Parent = closeBtn

	-- Rotation animation
	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 0}):Play()
	end)
	closeBtn.Activated:Connect(function()
		self:Close()
	end)

	-- Info section (level, interval) - at top
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "InfoSection"
	infoFrame.Size = UDim2.new(1, -CONFIG.PADDING * 2, 0, 40)
	infoFrame.Position = UDim2.new(0, CONFIG.PADDING, 0, 30)
	infoFrame.BackgroundTransparency = 1
	infoFrame.Parent = self.panel

	self.levelLabel = Instance.new("TextLabel")
	self.levelLabel.Name = "LevelLabel"
	self.levelLabel.Size = UDim2.new(0.5, 0, 1, 0)
	self.levelLabel.Position = UDim2.new(0, 0, 0, 0)
	self.levelLabel.BackgroundTransparency = 1
	self.levelLabel.Text = "Level: I"
	self.levelLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.levelLabel.TextSize = 16
	self.levelLabel.Font = BOLD_FONT
	self.levelLabel.TextXAlignment = Enum.TextXAlignment.Left
	self.levelLabel.Parent = infoFrame

	self.intervalLabel = Instance.new("TextLabel")
	self.intervalLabel.Name = "IntervalLabel"
	self.intervalLabel.Size = UDim2.new(0.5, 0, 1, 0)
	self.intervalLabel.Position = UDim2.new(0.5, 0, 0, 0)
	self.intervalLabel.BackgroundTransparency = 1
	self.intervalLabel.Text = "Action: 15s"
	self.intervalLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	self.intervalLabel.TextSize = 14
	self.intervalLabel.Font = BOLD_FONT
	self.intervalLabel.TextXAlignment = Enum.TextXAlignment.Right
	self.intervalLabel.Parent = infoFrame

	-- LEFT SECTION: Slots (3 rows × 4 columns)
	local slotsYStart = 30 + 40 + CONFIG.SECTION_SPACING
	for i = 1, 12 do
		self:CreateSlotUI(i, slotsYStart)
	end

	-- RIGHT SECTION: Action buttons
	local rightPanelX = CONFIG.PADDING + slotsWidth + CONFIG.SECTION_SPACING
	local buttonsYStart = slotsYStart

	-- Upgrade button
	self.upgradeBtn = Instance.new("TextButton")
	self.upgradeBtn.Name = "UpgradeButton"
	self.upgradeBtn.Size = UDim2.new(0, CONFIG.RIGHT_PANEL_WIDTH, 0, CONFIG.BUTTON_HEIGHT)
	self.upgradeBtn.Position = UDim2.new(0, rightPanelX, 0, buttonsYStart)
	self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	self.upgradeBtn.BorderSizePixel = 0
	self.upgradeBtn.Text = "Upgrade to II"
	self.upgradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.upgradeBtn.TextSize = 14
	self.upgradeBtn.Font = BOLD_FONT
	self.upgradeBtn.AutoButtonColor = false
	self.upgradeBtn.Parent = self.panel

	local upgradeCorner = Instance.new("UICorner")
	upgradeCorner.CornerRadius = UDim.new(0, 4)
	upgradeCorner.Parent = self.upgradeBtn

	-- Hover effect for upgrade button
	self.upgradeBtn.MouseEnter:Connect(function()
		if self.upgradeBtn.Active then
			self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 60)
		end
	end)

	self.upgradeBtn.MouseLeave:Connect(function()
		if self.level >= 4 then
			self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		else
			self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		end
	end)

	self.upgradeBtn.Activated:Connect(function()
		self:OnUpgradeClicked()
	end)

	-- Upgrade cost label (below button)
	self.upgradeCostLabel = Instance.new("TextLabel")
	self.upgradeCostLabel.Name = "UpgradeCostLabel"
	self.upgradeCostLabel.Size = UDim2.new(0, CONFIG.RIGHT_PANEL_WIDTH, 0, 20)
	self.upgradeCostLabel.Position = UDim2.new(0, rightPanelX, 0, buttonsYStart + CONFIG.BUTTON_HEIGHT + 4)
	self.upgradeCostLabel.BackgroundTransparency = 1
	self.upgradeCostLabel.Text = "Cost: 32 Cobblestone"
	self.upgradeCostLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
	self.upgradeCostLabel.TextSize = 12
	self.upgradeCostLabel.Font = BOLD_FONT
	self.upgradeCostLabel.TextXAlignment = Enum.TextXAlignment.Center
	self.upgradeCostLabel.Parent = self.panel

	-- Collect All button
	self.collectBtn = Instance.new("TextButton")
	self.collectBtn.Name = "CollectButton"
	self.collectBtn.Size = UDim2.new(0, CONFIG.RIGHT_PANEL_WIDTH, 0, CONFIG.BUTTON_HEIGHT)
	self.collectBtn.Position = UDim2.new(0, rightPanelX, 0, buttonsYStart + CONFIG.BUTTON_HEIGHT + 24 + CONFIG.BUTTON_SPACING)
	self.collectBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
	self.collectBtn.BorderSizePixel = 0
	self.collectBtn.Text = "Collect All"
	self.collectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.collectBtn.TextSize = 14
	self.collectBtn.Font = BOLD_FONT
	self.collectBtn.AutoButtonColor = false
	self.collectBtn.Parent = self.panel

	local collectCorner = Instance.new("UICorner")
	collectCorner.CornerRadius = UDim.new(0, 4)
	collectCorner.Parent = self.collectBtn

	-- Hover effect for collect button
	self.collectBtn.MouseEnter:Connect(function()
		if self.collectBtn.Active then
			self.collectBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 240)
		end
	end)

	self.collectBtn.MouseLeave:Connect(function()
		-- Check if has items to determine color
		local hasItems = false
		for i = 1, self.slotsUnlocked do
			if not self.slots[i]:IsEmpty() then
				hasItems = true
				break
			end
		end
		if hasItems then
			self.collectBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
		else
			self.collectBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		end
	end)

	self.collectBtn.Activated:Connect(function()
		self:OnCollectAllClicked()
	end)

	-- Pickup Minion button
	self.pickupBtn = Instance.new("TextButton")
	self.pickupBtn.Name = "PickupButton"
	self.pickupBtn.Size = UDim2.new(0, CONFIG.RIGHT_PANEL_WIDTH, 0, CONFIG.BUTTON_HEIGHT)
	self.pickupBtn.Position = UDim2.new(0, rightPanelX, 0, buttonsYStart + (CONFIG.BUTTON_HEIGHT + 24 + CONFIG.BUTTON_SPACING) + CONFIG.BUTTON_HEIGHT + CONFIG.BUTTON_SPACING)
	self.pickupBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	self.pickupBtn.BorderSizePixel = 0
	self.pickupBtn.Text = "Pickup Minion"
	self.pickupBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.pickupBtn.TextSize = 14
	self.pickupBtn.Font = BOLD_FONT
	self.pickupBtn.AutoButtonColor = false
	self.pickupBtn.Parent = self.panel

	local pickupCorner = Instance.new("UICorner")
	pickupCorner.CornerRadius = UDim.new(0, 4)
	pickupCorner.Parent = self.pickupBtn

	-- Hover effect for pickup button
	self.pickupBtn.MouseEnter:Connect(function()
		self.pickupBtn.BackgroundColor3 = Color3.fromRGB(240, 60, 60)
	end)

	self.pickupBtn.MouseLeave:Connect(function()
		self.pickupBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	end)

	self.pickupBtn.Activated:Connect(function()
		self:OnPickupClicked()
	end)
end

function MinionUI:CreateSlotUI(index, yStart)
	local row = math.floor((index - 1) / CONFIG.COLUMNS)
	local col = (index - 1) % CONFIG.COLUMNS

	local xPos = CONFIG.PADDING + col * (CONFIG.SLOT_SIZE + CONFIG.SLOT_SPACING)
	local yPos = yStart + row * (CONFIG.SLOT_SIZE + CONFIG.SLOT_SPACING)

	-- Slot frame (TextButton for hover/click)
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, CONFIG.SLOT_SIZE, 0, CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, xPos, 0, yPos)
	slot.BackgroundColor3 = CONFIG.SLOT_COLOR
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Hover border
	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(255, 255, 255)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.Parent = slot

	-- Icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

	-- Count label
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
		countLabel.Font = BOLD_FONT
	countLabel.TextSize = 14
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 4
	countLabel.Parent = slot

	-- Lock overlay (for locked slots)
	local lockOverlay = Instance.new("Frame")
	lockOverlay.Name = "LockOverlay"
	lockOverlay.Size = UDim2.new(1, 0, 1, 0)
	lockOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	lockOverlay.BackgroundTransparency = 0.7
	lockOverlay.BorderSizePixel = 0
	lockOverlay.ZIndex = 3
	lockOverlay.Visible = false
	lockOverlay.Parent = slot

	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, 4)
	lockCorner.Parent = lockOverlay

	-- Lock icon
	local lockIcon = Instance.new("TextLabel")
	lockIcon.Name = "LockIcon"
	lockIcon.Size = UDim2.new(1, 0, 1, 0)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Text = "🔒"
	lockIcon.TextSize = 24
	lockIcon.TextColor3 = Color3.fromRGB(200, 200, 200)
	lockIcon.ZIndex = 4
	lockIcon.Parent = lockOverlay

	self.slotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		lockOverlay = lockOverlay,
		hoverBorder = hoverBorder
	}

	-- Hover effects (only for unlocked slots)
	slot.MouseEnter:Connect(function()
		if index <= self.slotsUnlocked then
			hoverBorder.Transparency = 0.5
			slot.BackgroundColor3 = CONFIG.HOVER_COLOR

			-- Show tooltip if slot has item
			local stack = self.slots[index]
			if stack and not stack:IsEmpty() then
				self:ShowTooltip(index, stack:GetItemId(), stack:GetCount())
				-- Show item name in top left
				self:ShowHoverItemName(stack:GetItemId())
			end
		end
	end)

	slot.MouseLeave:Connect(function()
		if index <= self.slotsUnlocked then
			hoverBorder.Transparency = 1
			slot.BackgroundColor3 = CONFIG.SLOT_COLOR
		end
		self:HideTooltip()
		-- Hide item name
		self:HideHoverItemName()
	end)

	-- Click handlers (for future: quick-collect on click)
	slot.MouseButton1Click:Connect(function()
		if index <= self.slotsUnlocked and not self.slots[index]:IsEmpty() then
			-- Could implement quick-collect single slot here
		end
	end)
end

function MinionUI:UpdateSlotDisplay(index)
	local slotFrame = self.slotFrames[index]
	if not slotFrame then return end

	-- Check if locked
	local isLocked = index > self.slotsUnlocked
	slotFrame.lockOverlay.Visible = isLocked

	if isLocked then
		-- Clear any item visuals
		for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		slotFrame.countLabel.Text = ""
		slotFrame.frame.BackgroundColor3 = CONFIG.LOCKED_COLOR
		return
	end

	-- Unlocked slot - show item
	slotFrame.frame.BackgroundColor3 = CONFIG.SLOT_COLOR

	local stack = self.slots[index]
	local currentItemId = slotFrame.currentItemId

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		if currentItemId ~= itemId then
			-- Clear old visuals
			for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") then
					child:Destroy()
				end
			end

			if isTool then
				local info = ToolConfig.GetToolInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -8, 1, -8)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
			elseif ArmorConfig.IsArmor(itemId) then
				local info = ArmorConfig.GetArmorInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ArmorImage"
				image.Size = UDim2.new(1, -8, 1, -8)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				-- Tint base image for leather armor
				if info and info.imageOverlay then
					image.ImageColor3 = ArmorConfig.GetTierColor(info.tier)
				end
				image.Parent = slotFrame.iconContainer
				-- Add overlay for leather armor (untinted details)
				if info and info.imageOverlay then
					local overlay = Instance.new("ImageLabel")
					overlay.Name = "ArmorOverlay"
					overlay.Size = UDim2.new(1, -8, 1, -8)
					overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
					overlay.AnchorPoint = Vector2.new(0.5, 0.5)
					overlay.BackgroundTransparency = 1
					overlay.Image = info.imageOverlay
					overlay.ScaleType = Enum.ScaleType.Fit
					overlay.ZIndex = 4
					overlay.Parent = slotFrame.iconContainer
				end
			elseif SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -8, 1, -8))
				icon.Position = UDim2.new(0.5, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = slotFrame.iconContainer
			else
				BlockViewportCreator.CreateBlockViewport(
					slotFrame.iconContainer,
					itemId,
					UDim2.new(1, 0, 1, 0)
				)
			end

			slotFrame.currentItemId = itemId
		end

		if stack:GetCount() > 1 then
			slotFrame.countLabel.Text = tostring(stack:GetCount())
		else
			slotFrame.countLabel.Text = ""
		end
	else
		-- Empty slot
		for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		slotFrame.currentItemId = nil
		slotFrame.countLabel.Text = ""
	end
end

function MinionUI:UpdateAllDisplays()
	-- Update title
	local romanNumerals = {"I", "II", "III", "IV"}
	local roman = romanNumerals[self.level] or "IV"
	self.titleLabel.Text = string.format("<b><i>Cobblestone Minion %s</i></b>", roman)

	-- Update info
	self.levelLabel.Text = string.format("Level: %s", roman)
	self.intervalLabel.Text = string.format("Action: %ds", self.waitSeconds)

	-- Update slots
	for i = 1, 12 do
		self:UpdateSlotDisplay(i)
	end

	-- Update upgrade button
	if self.level >= 4 then
		self.upgradeBtn.Text = "Max Level"
		self.upgradeCostLabel.Text = ""
		self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		self.upgradeBtn.Active = false
	else
		local nextRoman = romanNumerals[self.level + 1]
		self.upgradeBtn.Text = string.format("Upgrade to %s", nextRoman)
		self.upgradeCostLabel.Text = string.format("Cost: %d Cobblestone", self.nextUpgradeCost)
		self.upgradeBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		self.upgradeBtn.Active = true
	end

	-- Update collect button (disable if all slots empty)
	local hasItems = false
	for i = 1, self.slotsUnlocked do
		if not self.slots[i]:IsEmpty() then
			hasItems = true
			break
		end
	end
	if hasItems then
		self.collectBtn.BackgroundColor3 = Color3.fromRGB(50, 100, 200)
		self.collectBtn.Active = true
	else
		self.collectBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
		self.collectBtn.Active = false
	end
end

function MinionUI:Open(anchorPos, state)
	if not self.gui or not self.panel then
		warn("MinionUI:Open - UI not initialized!")
		return
	end

	-- Prevent duplicate opens of the same anchor while already open
	if self.isOpen and self.anchorPos and anchorPos then
		if self.anchorPos.x == anchorPos.x and self.anchorPos.y == anchorPos.y and self.anchorPos.z == anchorPos.z then
			-- Update state silently but do not re-open UI
			if state then
				self.level = state.level or self.level
				self.slotsUnlocked = state.slotsUnlocked or self.slotsUnlocked
				self.waitSeconds = state.waitSeconds or self.waitSeconds
				self.nextUpgradeCost = state.nextUpgradeCost or self.nextUpgradeCost
				if state.slots then
					for i = 1, 12 do
						if state.slots[i] then
							self.slots[i] = ItemStack.Deserialize(state.slots[i])
						end
					end
				end
				self:UpdateAllDisplays()
			end
			return
		end
	end

	self.isOpen = true
	self.anchorPos = anchorPos

	-- Close other UIs
	if self.inventoryPanel and self.inventoryPanel.isOpen then
		self.inventoryPanel:Close()
	end
	if self.chestUI and self.chestUI.isOpen then
		self.chestUI:Close()
	end

	-- Apply state
	self.level = state.level or 1
	self.slotsUnlocked = state.slotsUnlocked or 1
	self.waitSeconds = state.waitSeconds or 15
	self.nextUpgradeCost = state.nextUpgradeCost or 32

	-- Load slots
	if state.slots then
		for i = 1, 12 do
			if state.slots[i] then
				self.slots[i] = ItemStack.Deserialize(state.slots[i])
			else
				self.slots[i] = ItemStack.new(0, 0)
			end
		end
	else
		for i = 1, 12 do
			self.slots[i] = ItemStack.new(0, 0)
		end
	end

	self:UpdateAllDisplays()

	-- Show UI
	self.gui.Enabled = true
	GameState:Set("voxelWorld.minionUIOpen", true)
	GameState:Set("voxelWorld.inventoryOpen", true) -- Signal to CameraController to unlock mouse

	-- Unlock mouse
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	task.defer(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	-- Start render connection to keep mouse unlocked (like ChestUI)
	local RunService = game:GetService("RunService")
	self.renderConnection = RunService.RenderStepped:Connect(function()
		if self.isOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
	end)
end

function MinionUI:Close()
	if not self.isOpen then return end

	-- Hide hover item name when closing
	self:HideHoverItemName()

	-- Notify server to unsubscribe before clearing anchor
	if self.anchorPos then
		local EventManager = require(game:GetService("ReplicatedStorage").Shared.EventManager)
		EventManager:SendToServer("RequestCloseMinion", {
			x = self.anchorPos.x,
			y = self.anchorPos.y,
			z = self.anchorPos.z
		})
	end

	self.isOpen = false
	self.anchorPos = nil

	-- Stop render connection
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	if self.gui then
		self.gui.Enabled = false
	end

	GameState:Set("voxelWorld.minionUIOpen", false)
	GameState:Set("voxelWorld.inventoryOpen", false) -- Signal to CameraController to re-lock mouse
end

function MinionUI:OnUpgradeClicked()
	if not self.anchorPos or self.level >= 4 then return end

	EventManager:SendToServer("RequestMinionUpgrade", {
		x = self.anchorPos.x,
		y = self.anchorPos.y,
		z = self.anchorPos.z
	})
end

function MinionUI:OnCollectAllClicked()
	if not self.anchorPos then return end

	print(string.format("[MinionUI] Sending RequestMinionCollectAll at (%d,%d,%d)",
		self.anchorPos.x, self.anchorPos.y, self.anchorPos.z))
	EventManager:SendToServer("RequestMinionCollectAll", {
		x = self.anchorPos.x,
		y = self.anchorPos.y,
		z = self.anchorPos.z
	})
end

function MinionUI:OnPickupClicked()
	if not self.anchorPos then return end

	EventManager:SendToServer("RequestMinionPickup", {
		x = self.anchorPos.x,
		y = self.anchorPos.y,
		z = self.anchorPos.z
	})
end

function MinionUI:RegisterEvents()
	EventManager:RegisterEvent("MinionOpened", function(data)
		if data and data.anchorPos and data.state then
			self:Open(data.anchorPos, data.state)
		end
	end)

	EventManager:RegisterEvent("MinionUpdated", function(data)
		if not self.isOpen then return end
		if data and data.state then
			-- Update state
			self.level = data.state.level or self.level
			self.slotsUnlocked = data.state.slotsUnlocked or self.slotsUnlocked
			self.waitSeconds = data.state.waitSeconds or self.waitSeconds
			self.nextUpgradeCost = data.state.nextUpgradeCost or self.nextUpgradeCost

			-- Update slots if provided
			if data.state.slots then
				for i = 1, 12 do
					if data.state.slots[i] then
						self.slots[i] = ItemStack.Deserialize(data.state.slots[i])
					else
						self.slots[i] = ItemStack.new(0, 0)
					end
				end
			end

			self:UpdateAllDisplays()
		end
	end)

	EventManager:RegisterEvent("MinionClosed", function()
		self:Close()
	end)
end

return MinionUI
