--[[
	ChestUI.lua
	Minecraft-style chest interface with drag-and-drop
	Shows chest inventory (27 slots) + player inventory (27 slots)
	Note: Hotbar remains visible at bottom of screen (not included in chest UI)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InputService = require(script.Parent.Parent.Input.InputService)
local _GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local _TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)

local ChestUI = {}
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold
ChestUI.__index = ChestUI

-- Load Upheaval font (matching WorldsPanel)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local _ = UpheavalFont -- Ensure font module loads
local CUSTOM_FONT_NAME = "Upheaval BRK"

-- Configuration (matching WorldsPanel styling exactly)
local CHEST_CONFIG = {
	-- Grid dimensions
	COLUMNS = 9,
	CHEST_ROWS = 3, -- 27 chest slots
	INVENTORY_ROWS = 3, -- 27 inventory slots
	SLOT_SIZE = 56,        -- Matching inventory slot size
	SLOT_SPACING = 5,      -- Matching inventory slot spacing
	PADDING = 12,          -- Matching inventory padding
	SECTION_SPACING = 8,   -- Section spacing
	LABEL_HEIGHT = 22,
	LABEL_SPACING = 8,

	-- Panel structure (matching WorldsPanel)
	HEADER_HEIGHT = 54,
	SHADOW_HEIGHT = 18,

	-- Colors (matching WorldsPanel exactly)
	PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),  -- Panel background
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),   -- Slot background
	SLOT_BG_TRANSPARENCY = 0.4,  -- 60% opacity
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),

	-- Border colors (matching WorldsPanel)
	COLUMN_BORDER_COLOR = Color3.fromRGB(77, 77, 77),  -- Column/panel border
	COLUMN_BORDER_THICKNESS = 3,
	SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),   -- Slot border
	SLOT_BORDER_THICKNESS = 2,

	-- Hover state
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),

	-- Corner radius
	CORNER_RADIUS = 8,
	SLOT_CORNER_RADIUS = 4,

	-- Background image (matching inventory slots)
	BACKGROUND_IMAGE = "rbxassetid://82824299358542",
	BACKGROUND_IMAGE_TRANSPARENCY = 0.6,

	-- Text colors
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),
}

-- Helper function to get display name for any item type
local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then return nil end
	return ItemRegistry.GetItemName(itemId)
end

function ChestUI.new(inventoryManager)
	local self = setmetatable({}, ChestUI)

	-- Use centralized inventory manager
	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar

	self.isOpen = false
	self.gui = nil
	self.panel = nil
	self.chestPosition = nil -- {x, y, z} of current chest
	self.hoverItemLabel = nil  -- Label for displaying hovered item name

	-- Chest slots (27 slots) - local to this UI
	self.chestSlots = {}
	self.chestSlotFrames = {}

	-- UI slot frames for inventory display
	self.inventorySlotFrames = {}

	-- Hotbar slot frames (for visual reference only)
	self.hotbarSlotFrames = {}

	-- Cursor/drag state
	self.cursorStack = ItemStack.new(0, 0)
	self.cursorFrame = nil

	self.connections = {}
	self.renderConnection = nil

	-- Initialize empty chest slots
	for i = 1, 27 do
		self.chestSlots[i] = ItemStack.new(0, 0)
	end

	return self
end

function ChestUI:Initialize()
	-- Create ScreenGui for chest UI (matching WorldsPanel pattern)
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "ChestUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150
	self.gui.IgnoreGuiInset = false  -- Matching WorldsPanel
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Create separate ScreenGui for cursor (must be on top of everything)
	self.cursorGui = Instance.new("ScreenGui")
	self.cursorGui.Name = "ChestUICursor"
	self.cursorGui.ResetOnSpawn = false
	self.cursorGui.DisplayOrder = 2000  -- Always on top (shared with inventory cursor)
	self.cursorGui.IgnoreGuiInset = true  -- Cursor needs to ignore inset for proper positioning
	self.cursorGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Apply responsive scaling (matching WorldsPanel pattern)
	self:EnsureResponsiveScale(self.gui)

	-- Create hover item name label (top left of screen)
	self:CreateHoverItemLabel()

	-- Create panels
	self:CreatePanel()
	self:CreateCursorItem()

	-- Bind input
	self:BindInput()

	-- Register network events
	self:RegisterEvents()

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("chestUI", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 150
	})

	return self
end

function ChestUI:EnsureResponsiveScale(contentFrame)
	if self.uiScale and self.uiScale.Parent then
		return self.uiScale
	end

	if not contentFrame then
		return nil
	end

	local target = contentFrame.Parent
	if not (target and target:IsA("GuiBase2d")) then
		target = contentFrame
	end

	self.scaleTarget = target

	local existing = target:FindFirstChild("ResponsiveScale")
	if existing and existing:IsA("UIScale") then
		self.uiScale = existing
		if not CollectionService:HasTag(existing, "scale_component") then
			CollectionService:AddTag(existing, "scale_component")
		end
		return existing
	end

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.75)
	uiScale.Parent = target
	CollectionService:AddTag(uiScale, "scale_component")
	self.uiScale = uiScale

	return uiScale
end

function ChestUI:RegisterScrollingLayout(layout)
	if not layout or not layout:IsA("UIListLayout") then
		return
	end

	if not (self.uiScale and self.uiScale.Parent) then
		self:EnsureResponsiveScale(self.scaleTarget or self.gui or layout.Parent)
	end

	if not (self.uiScale and self.uiScale.Parent) then
		return
	end

	if not CollectionService:HasTag(layout, "scrolling_frame_layout_component") then
		CollectionService:AddTag(layout, "scrolling_frame_layout_component")
	end

	local referral = layout:FindFirstChild("scale_component_referral")
	if not referral then
		referral = Instance.new("ObjectValue")
		referral.Name = "scale_component_referral"
		referral.Parent = layout
	end
	referral.Value = self.uiScale
end

function ChestUI:CreateHoverItemLabel()
	-- Create a label in the top left of the screen to display hovered item name
	local label = Instance.new("TextLabel")
	label.Name = "HoverItemLabel"
	label.Size = UDim2.fromOffset(400, 40)
	label.Position = UDim2.fromOffset(20, 20)
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

function ChestUI:ShowHoverItemName(itemId)
	if not self.hoverItemLabel then return end

	local itemName = GetItemDisplayName(itemId)
	if itemName then
		self.hoverItemLabel.Text = itemName
		self.hoverItemLabel.Visible = true
	else
		self.hoverItemLabel.Visible = false
	end
end

function ChestUI:HideHoverItemName()
	if not self.hoverItemLabel then return end
	self.hoverItemLabel.Visible = false
end

function ChestUI:CreatePanel()
	-- Calculate dimensions based on slot size
	local _borderThickness = CHEST_CONFIG.SLOT_BORDER_THICKNESS
	local slotWidth = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.COLUMNS +
	                  CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.COLUMNS - 1)
	local chestHeight = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.CHEST_ROWS +
	                    CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.CHEST_ROWS - 1)
	local invHeight = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.INVENTORY_ROWS +
	                  CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.INVENTORY_ROWS - 1)
	local hotbarHeight = CHEST_CONFIG.SLOT_SIZE

	-- Calculate body height (panel content area)
	local labelHeight = CHEST_CONFIG.LABEL_HEIGHT
	local labelSpacing = CHEST_CONFIG.LABEL_SPACING
	local bodyHeight = CHEST_CONFIG.PADDING + labelHeight + labelSpacing + chestHeight + CHEST_CONFIG.SECTION_SPACING + labelHeight + labelSpacing + invHeight + CHEST_CONFIG.SECTION_SPACING + labelHeight + labelSpacing + hotbarHeight + CHEST_CONFIG.PADDING
	local panelWidth = slotWidth + CHEST_CONFIG.PADDING * 2

	-- Total container height (header + body - matching WorldsPanel)
	local totalHeight = CHEST_CONFIG.HEADER_HEIGHT + bodyHeight

	-- Container frame (centers everything, transparent - matching WorldsPanel)
	local container = Instance.new("Frame")
	container.Name = "ChestContainer"
	container.Size = UDim2.fromOffset(panelWidth, totalHeight)
	container.Position = UDim2.new(0.5, 0, 0.5, -CHEST_CONFIG.HEADER_HEIGHT)  -- Vertical offset matching WorldsPanel
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = self.gui
	self.container = container

	-- Header (OUTSIDE panel, matching WorldsPanel)
	self:CreateHeader(container, panelWidth)

	-- Body frame (transparent container for panel + shadow - matching WorldsPanel)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.fromOffset(panelWidth, bodyHeight)
	bodyFrame.Position = UDim2.fromOffset(0, CHEST_CONFIG.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = container

	-- Main panel (with background color - matching WorldsPanel ContentPanel)
	self.panel = Instance.new("Frame")
	self.panel.Name = "ChestPanel"
	self.panel.Size = UDim2.fromOffset(panelWidth, bodyHeight)
	self.panel.Position = UDim2.fromScale(0, 0)
	self.panel.BackgroundColor3 = CHEST_CONFIG.PANEL_BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.ZIndex = 1
	self.panel.Parent = bodyFrame

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CHEST_CONFIG.CORNER_RADIUS)
	corner.Parent = self.panel

	-- Shadow below panel (matching WorldsPanel)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromOffset(panelWidth, CHEST_CONFIG.SHADOW_HEIGHT)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.fromOffset(0, bodyHeight)
	shadow.BackgroundColor3 = CHEST_CONFIG.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = bodyFrame

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, CHEST_CONFIG.CORNER_RADIUS)
	shadowCorner.Parent = shadow

	-- Border (matching WorldsPanel column border)
	local stroke = Instance.new("UIStroke")
	stroke.Color = CHEST_CONFIG.COLUMN_BORDER_COLOR
	stroke.Thickness = CHEST_CONFIG.COLUMN_BORDER_THICKNESS
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = self.panel

	-- Content starts inside panel
	local yOffset = CHEST_CONFIG.PADDING

	-- === CHEST SECTION ===
	-- Chest label (matching WorldsPanel label style)
	local chestLabel = Instance.new("TextLabel")
	chestLabel.Name = "ChestLabel"
	chestLabel.Size = UDim2.new(1, -CHEST_CONFIG.PADDING * 2, 0, CHEST_CONFIG.LABEL_HEIGHT)
	chestLabel.Position = UDim2.fromOffset(CHEST_CONFIG.PADDING, yOffset)
	chestLabel.BackgroundTransparency = 1
	chestLabel.Font = BOLD_FONT
	chestLabel.TextSize = 14
	chestLabel.TextColor3 = CHEST_CONFIG.TEXT_MUTED
	chestLabel.Text = "CHEST"
	chestLabel.TextXAlignment = Enum.TextXAlignment.Left
	chestLabel.Parent = self.panel

	yOffset = yOffset + CHEST_CONFIG.LABEL_HEIGHT + CHEST_CONFIG.LABEL_SPACING

	-- Create chest slots (3 rows of 9)
	for row = 0, CHEST_CONFIG.CHEST_ROWS - 1 do
		for col = 0, CHEST_CONFIG.COLUMNS - 1 do
			local index = row * CHEST_CONFIG.COLUMNS + col + 1
			local x = CHEST_CONFIG.PADDING + col * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			self:CreateChestSlot(index, x, y)
		end
	end

	yOffset = yOffset + chestHeight + CHEST_CONFIG.SECTION_SPACING

	-- === INVENTORY SECTION ===
	-- Inventory label (matching WorldsPanel label style)
	local invLabel = Instance.new("TextLabel")
	invLabel.Name = "InvLabel"
	invLabel.Size = UDim2.new(1, -CHEST_CONFIG.PADDING * 2, 0, CHEST_CONFIG.LABEL_HEIGHT)
	invLabel.Position = UDim2.fromOffset(CHEST_CONFIG.PADDING, yOffset)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = BOLD_FONT
	invLabel.TextSize = 14
	invLabel.TextColor3 = CHEST_CONFIG.TEXT_MUTED
	invLabel.Text = "INVENTORY"
	invLabel.TextXAlignment = Enum.TextXAlignment.Left
	invLabel.Parent = self.panel

	yOffset = yOffset + CHEST_CONFIG.LABEL_HEIGHT + CHEST_CONFIG.LABEL_SPACING

	-- Create inventory slots (3 rows of 9)
	for row = 0, CHEST_CONFIG.INVENTORY_ROWS - 1 do
		for col = 0, CHEST_CONFIG.COLUMNS - 1 do
			local index = row * CHEST_CONFIG.COLUMNS + col + 1
			local x = CHEST_CONFIG.PADDING + col * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, x, y)
		end
	end

	yOffset = yOffset + invHeight + CHEST_CONFIG.SECTION_SPACING

	-- === HOTBAR SECTION ===
	-- Hotbar label (matching WorldsPanel label style)
	local hotbarLabel = Instance.new("TextLabel")
	hotbarLabel.Name = "HotbarLabel"
	hotbarLabel.Size = UDim2.new(1, -CHEST_CONFIG.PADDING * 2, 0, CHEST_CONFIG.LABEL_HEIGHT)
	hotbarLabel.Position = UDim2.fromOffset(CHEST_CONFIG.PADDING, yOffset)
	hotbarLabel.BackgroundTransparency = 1
	hotbarLabel.Font = BOLD_FONT
	hotbarLabel.TextSize = 14
	hotbarLabel.TextColor3 = CHEST_CONFIG.TEXT_MUTED
	hotbarLabel.Text = "HOTBAR"
	hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
	hotbarLabel.Parent = self.panel

	yOffset = yOffset + CHEST_CONFIG.LABEL_HEIGHT + CHEST_CONFIG.LABEL_SPACING

	-- Create hotbar slots (1 row of 9) - visual reference only, data managed by inventoryManager
	for col = 0, CHEST_CONFIG.COLUMNS - 1 do
		local index = col + 1
		local x = CHEST_CONFIG.PADDING + col * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
		self:CreateHotbarSlot(index, x, yOffset)
	end
end

function ChestUI:CreateHeader(parent, panelWidth)
	-- Header frame (transparent, floats above panel - matching WorldsPanel)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.fromOffset(panelWidth, CHEST_CONFIG.HEADER_HEIGHT)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent

	-- Title (Upheaval font, size 54 - matching WorldsPanel)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "CHEST"
	title.TextColor3 = CHEST_CONFIG.TEXT_PRIMARY
	title.Font = Enum.Font.Code
	title.TextSize = 54
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame
	FontBinder.apply(title, CUSTOM_FONT_NAME)

	-- Close button (top-right corner - matching WorldsPanel)
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.fromOffset(44, 44),
		position = UDim2.fromScale(1, 0),
		anchorPoint = Vector2.new(1, 0)
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
	closeIcon:Destroy()

	-- Close button animation (matching WorldsPanel)
	local rotateInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, {Rotation = 0}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

function ChestUI:CreateChestSlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "ChestSlot" .. index
	slot.Size = UDim2.fromOffset(CHEST_CONFIG.SLOT_SIZE, CHEST_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = CHEST_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CHEST_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot

	-- Background image (matching inventory slots)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CHEST_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = CHEST_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border (matching inventory slot border)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = CHEST_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = CHEST_CONFIG.SLOT_BORDER_THICKNESS
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

	-- Hover border
	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(255, 255, 255)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.ZIndex = 2
	hoverBorder.Parent = slot

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.Position = UDim2.fromScale(0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 14
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot

	self.chestSlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder
	}

	-- Hover effects
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = CHEST_CONFIG.HOVER_COLOR
		-- Show item name in top left
		local stack = self.chestSlots[index]
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
		-- Hide item name
		self:HideHoverItemName()
	end)

	-- Click handlers
	slot.MouseButton1Click:Connect(function()
		self:OnChestSlotLeftClick(index)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnChestSlotRightClick(index)
	end)

	self:UpdateChestSlotDisplay(index)
end

function ChestUI:CreateInventorySlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "InventorySlot" .. index
	slot.Size = UDim2.fromOffset(CHEST_CONFIG.SLOT_SIZE, CHEST_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = CHEST_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CHEST_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot

	-- Background image (matching inventory slots)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CHEST_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = CHEST_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border (matching inventory slot border)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = CHEST_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = CHEST_CONFIG.SLOT_BORDER_THICKNESS
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

	-- Hover border
	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(255, 255, 255)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.ZIndex = 2
	hoverBorder.Parent = slot

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.Position = UDim2.fromScale(0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 14
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot

	self.inventorySlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder
	}

	-- Hover effects
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = CHEST_CONFIG.HOVER_COLOR
		-- Show item name in top left
		local stack = self.inventoryManager:GetInventorySlot(index)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
		-- Hide item name
		self:HideHoverItemName()
	end)

	-- Click handlers
	slot.MouseButton1Click:Connect(function()
		self:OnInventorySlotLeftClick(index)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnInventorySlotRightClick(index)
	end)

	self:UpdateInventorySlotDisplay(index)
end

function ChestUI:CreateHotbarSlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "HotbarSlot" .. index
	slot.Size = UDim2.fromOffset(CHEST_CONFIG.SLOT_SIZE, CHEST_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = CHEST_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CHEST_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot

	-- Background image (matching inventory slots)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CHEST_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = CHEST_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border (matching inventory slot border)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = CHEST_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = CHEST_CONFIG.SLOT_BORDER_THICKNESS
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

	-- Selection indicator (if this is the active hotbar slot) - bright white, thick
	local selectionBorder = Instance.new("UIStroke")
	selectionBorder.Name = "Selection"
	selectionBorder.Color = Color3.fromRGB(220, 220, 220)
	selectionBorder.Thickness = 3
	selectionBorder.Transparency = 1
	selectionBorder.ZIndex = 2
	selectionBorder.Parent = slot

	-- Hover border (for drag-and-drop feedback)
	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(180, 180, 180)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.ZIndex = 3
	hoverBorder.Parent = slot

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.Position = UDim2.fromScale(0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 4
	iconContainer.Parent = slot

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 14
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot

	-- Number label in top-left corner
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Size = UDim2.fromOffset(20, 20)
	numberLabel.Position = UDim2.fromOffset(4, 4)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Font = BOLD_FONT
	numberLabel.TextSize = 12
	numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	numberLabel.TextStrokeTransparency = 0.5
	numberLabel.Text = tostring(index)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberLabel.TextYAlignment = Enum.TextYAlignment.Top
	numberLabel.ZIndex = 3
	numberLabel.Parent = slot

	self.hotbarSlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder,
		selectionBorder = selectionBorder
	}

	-- Hover effects
	slot.MouseEnter:Connect(function()
		-- Show hover border (unless selection border is active)
		if self.hotbar and self.hotbar.selectedSlot ~= index then
			hoverBorder.Transparency = 0.5
		end
		slot.BackgroundColor3 = CHEST_CONFIG.HOVER_COLOR
		-- Show item name in top left
		if self.hotbar then
			local stack = self.hotbar.slots[index]
			if stack and not stack:IsEmpty() then
				self:ShowHoverItemName(stack:GetItemId())
			end
		end
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = CHEST_CONFIG.SLOT_BG_COLOR
		-- Hide item name
		self:HideHoverItemName()
	end)

	-- Click handlers (hotbar slots interact with hotbar data through inventoryManager)
	slot.MouseButton1Click:Connect(function()
		self:OnHotbarSlotLeftClick(index)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnHotbarSlotRightClick(index)
	end)

	self:UpdateHotbarSlotDisplay(index)
end

function ChestUI:CreateCursorItem()
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.fromOffset(CHEST_CONFIG.SLOT_SIZE, CHEST_CONFIG.SLOT_SIZE)
	self.cursorFrame.AnchorPoint = Vector2.new(0.5, 0.5)  -- Center on cursor
	self.cursorFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	self.cursorFrame.BackgroundTransparency = 0.7  -- Semi-transparent background, item stays fully visible
	self.cursorFrame.BorderSizePixel = 0
	self.cursorFrame.Visible = false
	self.cursorFrame.ZIndex = 1000
	self.cursorFrame.Parent = self.cursorGui  -- Separate ScreenGui for proper layering

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = self.cursorFrame

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = self.cursorFrame

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 1001
	countLabel.Parent = self.cursorFrame
end

-- === UPDATE DISPLAYS ===

function ChestUI:UpdateChestSlotDisplay(index)
	local slotData = self.chestSlotFrames[index]
	if not slotData then return end

	local stack = self.chestSlots[index]
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	local currentItemId = iconContainer:GetAttribute("CurrentItemId")

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		-- Only update visuals if item type changed
		if currentItemId ~= itemId then
			for _, child in ipairs(iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
					child:Destroy()
				end
			end
			if SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
				icon.Position = UDim2.fromScale(0.5, 0.5)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = iconContainer
			else
				BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.fromScale(1, 1))
			end
			iconContainer:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count (cheap operation)
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		iconContainer:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

function ChestUI:UpdateInventorySlotDisplay(index)
	local slotData = self.inventorySlotFrames[index]
	if not slotData then return end

	local stack = self.inventoryManager:GetInventorySlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	local currentItemId = iconContainer:GetAttribute("CurrentItemId")

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		-- Only update visuals if item type changed
		if currentItemId ~= itemId then
			BlockViewportCreator.RenderItemSlot(iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)
			iconContainer:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		iconContainer:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

function ChestUI:UpdateHotbarSlotDisplay(index)
	if not self.hotbar then return end

	local slotData = self.hotbarSlotFrames[index]
	if not slotData then return end

	local stack = self.inventoryManager:GetHotbarSlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	local currentItemId = iconContainer:GetAttribute("CurrentItemId")

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		-- Only update visuals if item type changed
		if currentItemId ~= itemId then
			BlockViewportCreator.RenderItemSlot(iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)
			iconContainer:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		iconContainer:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end

	-- Update selection border
	if self.hotbar.selectedSlot == index then
		slotData.selectionBorder.Transparency = 0
	else
		slotData.selectionBorder.Transparency = 1
	end
end

-- Smart update - check what actually changed and only update those slots
-- Works for both local actions and remote player updates
function ChestUI:UpdateChangedSlots()
	-- Check chest slots (compare cached vs actual)
	for i = 1, 27 do
		local slotData = self.chestSlotFrames[i]
		if slotData then
			local stack = self.chestSlots[i]
			local cachedItemId = slotData.iconContainer:GetAttribute("CurrentItemId")
			local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

			-- Update if item ID changed OR if visuals/labels are out of sync
			if cachedItemId ~= actualItemId then
				-- Item changed (including nil -> item, item -> nil, or item A -> item B)
				self:UpdateChestSlotDisplay(i)
			elseif actualItemId and stack then
				-- Same item, just update count (cheap operation)
				slotData.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
			end
		end
	end

	-- Check inventory slots (compare cached vs actual)
	for i = 1, 27 do
		local slotData = self.inventorySlotFrames[i]
		if slotData then
			local stack = self.inventoryManager:GetInventorySlot(i)
			local cachedItemId = slotData.iconContainer:GetAttribute("CurrentItemId")
			local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

			-- Update if item ID changed OR if visuals/labels are out of sync
			if cachedItemId ~= actualItemId then
				-- Item changed (including nil -> item, item -> nil, or item A -> item B)
				self:UpdateInventorySlotDisplay(i)
			elseif actualItemId and stack then
				-- Same item, just update count (cheap operation)
				slotData.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
			end
		end
	end

	-- Check hotbar slots
	if self.hotbar then
		for i = 1, 9 do
			local slotData = self.hotbarSlotFrames[i]
			if slotData then
				local stack = self.inventoryManager:GetHotbarSlot(i)
				local cachedItemId = slotData.iconContainer:GetAttribute("CurrentItemId")
				local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

				-- Update if item ID changed
				if cachedItemId ~= actualItemId then
					self:UpdateHotbarSlotDisplay(i)
				elseif actualItemId and stack then
					-- Same item, just update count (cheap operation)
					slotData.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
					-- Also update selection border in case selection changed
					if self.hotbar.selectedSlot == i then
						slotData.selectionBorder.Transparency = 0
					else
						slotData.selectionBorder.Transparency = 1
					end
				end
			end
		end
	end

	-- Always update cursor
	self:UpdateCursorDisplay()
end

-- Legacy function for full refresh (used on open)
function ChestUI:UpdateAllDisplays()
	-- Update chest slots
	for i = 1, 27 do
		self:UpdateChestSlotDisplay(i)
	end

	-- Update inventory slots
	for i = 1, 27 do
		self:UpdateInventorySlotDisplay(i)
	end

	-- Update hotbar slots
	for i = 1, 9 do
		self:UpdateHotbarSlotDisplay(i)
	end

	-- Update cursor
	self:UpdateCursorDisplay()
end

function ChestUI:UpdateCursorDisplay()
	if not self.cursorFrame then return end

	local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
	local countLabel = self.cursorFrame:FindFirstChild("CountLabel")
	if not iconContainer or not countLabel then return end

	local currentItemId = self.cursorFrame:GetAttribute("CurrentItemId")

	if self.cursorStack and not self.cursorStack:IsEmpty() then
		local itemId = self.cursorStack:GetItemId()
		-- Only recreate viewport/image if item type changed
		if currentItemId ~= itemId then
			BlockViewportCreator.RenderItemSlot(iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)
			self.cursorFrame:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count (cheap operation)
		countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		self.cursorFrame.Visible = true
	else
		-- Clear attribute IMMEDIATELY to prevent race conditions
		self.cursorFrame:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""
		self.cursorFrame.Visible = false

		-- Clear ALL visuals
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

-- === CLICK HANDLERS ===

-- Helper: Check if shift key is held
local function IsShiftHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Quick transfer item (shift-click) from one container to another
-- sourceType: "chest", "inventory", "hotbar"
function ChestUI:QuickTransfer(slotIndex, sourceType)
	-- Send to server for authoritative handling
	EventManager:SendToServer("ChestQuickTransfer", {
		chestPosition = self.chestPosition,
		slotIndex = slotIndex,
		sourceType = sourceType, -- "chest", "inventory", "hotbar"
	})
end

-- Local helper: simulate Minecraft-style click on a slot
function ChestUI:_simulateSlotClick(slotStack, cursorStack, clickType)
	-- Work on clones to avoid mutating originals before applying
	local slot = (slotStack and slotStack:Clone()) or ItemStack.new(0, 0)
	local cursor = (cursorStack and cursorStack:Clone()) or ItemStack.new(0, 0)

	if clickType == "left" then
		if cursor:IsEmpty() then
			-- Pick up entire stack
			if not slot:IsEmpty() then
				cursor = slot:Clone()
				slot = ItemStack.new(0, 0)
			end
		else
			-- Place entire stack / merge / swap
			if slot:IsEmpty() then
				slot = cursor:Clone()
				cursor = ItemStack.new(0, 0)
			elseif cursor:CanStack(slot) then
				-- Merge as much as possible
				slot:Merge(cursor)
				if cursor:IsEmpty() then
					cursor = ItemStack.new(0, 0)
				end
			else
				-- Swap stacks
				local temp = slot:Clone()
				slot = cursor:Clone()
				cursor = temp
			end
		end
	elseif clickType == "right" then
		if cursor:IsEmpty() then
			-- Pick up half (round up)
			if not slot:IsEmpty() then
				cursor = slot:SplitHalf()
			end
		else
			-- Place one / add one to stack
			if slot:IsEmpty() then
				local oneItem = cursor:TakeOne()
				slot = oneItem
			elseif cursor:CanStack(slot) and not slot:IsFull() then
				slot:AddCount(1)
				cursor:RemoveCount(1)
			end
		end
	end

	return slot, cursor
end

function ChestUI:OnChestSlotLeftClick(index)
	-- Shift-click: Quick transfer from chest to player (hotbar first, then inventory)
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local slotStack = self.chestSlots[index]
		if slotStack and not slotStack:IsEmpty() then
			self:QuickTransfer(index, "chest")
			return
		end
	end

	-- Predictive visual update for instant feedback
	local currentSlot = self.chestSlots[index]
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "left")

	-- Apply visuals immediately
	self.chestSlots[index] = newSlot
	self:UpdateChestSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "left"
	})
end

function ChestUI:OnChestSlotRightClick(index)
	-- Predictive visual update for instant feedback
	local currentSlot = self.chestSlots[index]
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "right")

	-- Apply visuals immediately
	self.chestSlots[index] = newSlot
	self:UpdateChestSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "right"
	})
end

function ChestUI:OnInventorySlotLeftClick(index)
	-- Shift-click: Quick transfer from inventory to chest
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local slotStack = self.inventoryManager:GetInventorySlot(index)
		if slotStack and not slotStack:IsEmpty() then
			self:QuickTransfer(index, "inventory")
			return
		end
	end

	-- Predictive visual update for instant feedback (player inventory slot)
	local currentSlot = self.inventoryManager:GetInventorySlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "left")

	-- Apply visuals immediately to player's inventory
	self.inventoryManager:SetInventorySlot(index, newSlot)
	self:UpdateInventorySlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = false,
		clickType = "left"
	})
end

function ChestUI:OnInventorySlotRightClick(index)
	-- Predictive visual update for instant feedback (player inventory slot)
	local currentSlot = self.inventoryManager:GetInventorySlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "right")

	-- Apply visuals immediately to player's inventory
	self.inventoryManager:SetInventorySlot(index, newSlot)
	self:UpdateInventorySlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = false,
		clickType = "right"
	})
end

function ChestUI:OnHotbarSlotLeftClick(index)
	if not self.hotbar then return end

	-- Shift-click: Quick transfer from hotbar to chest
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local slotStack = self.inventoryManager:GetHotbarSlot(index)
		if slotStack and not slotStack:IsEmpty() then
			self:QuickTransfer(index, "hotbar")
			return
		end
	end

	-- Predictive visual update for instant feedback (hotbar slot)
	local currentSlot = self.inventoryManager:GetHotbarSlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "left")

	-- Apply visuals immediately to hotbar
	self.inventoryManager:SetHotbarSlot(index, newSlot)
	self:UpdateHotbarSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server (using negative indices to indicate hotbar)
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = -index, -- Negative to indicate hotbar slot
		isChestSlot = false,
		clickType = "left"
	})
end

function ChestUI:OnHotbarSlotRightClick(index)
	if not self.hotbar then return end

	-- Predictive visual update for instant feedback (hotbar slot)
	local currentSlot = self.inventoryManager:GetHotbarSlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "right")

	-- Apply visuals immediately to hotbar
	self.inventoryManager:SetHotbarSlot(index, newSlot)
	self:UpdateHotbarSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server (using negative indices to indicate hotbar)
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = -index, -- Negative to indicate hotbar slot
		isChestSlot = false,
		clickType = "right"
	})
end

-- === NETWORK SYNC ===

-- Send atomic transaction (chest + inventory + cursor together)
function ChestUI:SendTransaction()
	if not self.chestPosition then return end

	-- Serialize chest contents
	local chestContents = {}
	for i = 1, 27 do
		chestContents[i] = self.chestSlots[i]:Serialize()
	end

	-- Serialize player inventory
	local playerInventory = {}
	for i = 1, 27 do
		local stack = self.inventoryManager:GetInventorySlot(i)
		if stack and not stack:IsEmpty() then
			playerInventory[i] = stack:Serialize()
		end
	end

	-- Serialize hotbar
	local hotbar = {}
	for i = 1, 9 do
		local stack = self.inventoryManager:GetHotbarSlot(i)
		if stack and not stack:IsEmpty() then
			hotbar[i] = stack:Serialize()
		end
	end

	-- Include cursor items in transaction (important for validation!)
	local cursorItem = nil
	if not self.cursorStack:IsEmpty() then
		cursorItem = self.cursorStack:Serialize()
	end

	-- Send SINGLE atomic transaction with all states
	EventManager:SendToServer("ChestContentsUpdate", {
		x = self.chestPosition.x,
		y = self.chestPosition.y,
		z = self.chestPosition.z,
		contents = chestContents,
		playerInventory = playerInventory,
		hotbar = hotbar,  -- Include hotbar
		cursorItem = cursorItem  -- Include cursor for proper validation
	})
end

-- Deprecated - kept for compatibility
function ChestUI:SendChestUpdate()
	self:SendTransaction()
end

function ChestUI:SendInventoryUpdate()
	self:SendTransaction()
end

-- === LIFECYCLE ===

function ChestUI:Open(chestPos, chestContents, _playerInventory, hotbar)
	if not self.gui then
		warn("ChestUI:Open - self.gui is nil! ChestUI not properly initialized!")
		return
	end

	if not self.panel then
		warn("ChestUI:Open - self.panel is nil! Panel not created!")
		return
	end

	self.isOpen = true
	self.chestPosition = chestPos

	-- Use UIVisibilityManager to coordinate all UI
	UIVisibilityManager:SetMode("chest")

	-- First, initialize all slots as empty
	for i = 1, 27 do
		self.chestSlots[i] = ItemStack.new(0, 0)
	end

	-- Then apply chest contents from server (now a dense array of all 27 slots)
	if chestContents then
		for i = 1, 27 do
			if chestContents[i] then
				local deserialized = ItemStack.Deserialize(chestContents[i])
				self.chestSlots[i] = deserialized or ItemStack.new(0, 0)
			else
				self.chestSlots[i] = ItemStack.new(0, 0)
			end
		end
	end

	-- Sync hotbar from server (if provided)
	if hotbar and self.hotbar then
		self.inventoryManager._syncingFromServer = true
		for i = 1, 9 do
			if hotbar[i] then
				local deserialized = ItemStack.Deserialize(hotbar[i])
				self.inventoryManager:SetHotbarSlot(i, deserialized or ItemStack.new(0, 0))
			else
				self.inventoryManager:SetHotbarSlot(i, ItemStack.new(0, 0))
			end
		end
		self.inventoryManager._syncingFromServer = false
	end

	-- Update all displays
	self:UpdateAllDisplays()

	-- Show UI
	self.gui.Enabled = true

	-- Start render connection for cursor tracking
	self.renderConnection = RunService.RenderStepped:Connect(function()
		if self.isOpen then
			self:UpdateCursorPosition()
		end
	end)
end

function ChestUI:Close(nextMode)
	if not self.isOpen then return end

	-- Hide hover item name when closing
	self:HideHoverItemName()

	self.isOpen = false

	-- Drop cursor item back to inventory/chest
	if not self.cursorStack:IsEmpty() then
		-- Try to return to first empty inventory slot
		local placed = false
		for i = 1, 27 do
			if self.inventoryManager:GetInventorySlot(i):IsEmpty() then
				self.inventoryManager:SetInventorySlot(i, self.cursorStack:Clone())
				placed = true
				break
			end
		end
		if not placed then
			-- Try chest
			for i = 1, 27 do
				if self.chestSlots[i]:IsEmpty() then
					self.chestSlots[i] = self.cursorStack:Clone()
					placed = true
					break
				end
			end
		end
		self.cursorStack = ItemStack.new(0, 0)
		self:UpdateCursorDisplay()

		-- Sync changes to server
		if placed then
			self.inventoryManager:SendUpdateToServer()
		end
	end

	-- Notify server of closure
	if self.chestPosition then
		EventManager:SendToServer("RequestCloseChest", {
			x = self.chestPosition.x,
			y = self.chestPosition.y,
			z = self.chestPosition.z
		})
		self.chestPosition = nil
	end

	-- Stop render connection first
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Hide UI
	self.gui.Enabled = false

	-- Restore target UI mode (defaults to gameplay)
	local targetMode = nextMode or "gameplay"
	if targetMode then
		UIVisibilityManager:SetMode(targetMode)
	end

	-- Note: CameraController now manages mouse lock dynamically based on camera mode
	-- (first person = locked, third person = free)
end

function ChestUI:UpdateCursorPosition()
	if not self.cursorFrame or not self.cursorFrame.Visible then return end

	local mousePos = InputService:GetMouseLocation()

	-- Cursor ScreenGui has IgnoreGuiInset=true, so use raw mouse position
	-- AnchorPoint of 0.5,0.5 centers the cursor frame on this position
	self.cursorFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
end

function ChestUI:BindInput()
	table.insert(self.connections, InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape then
			if self.isOpen then
				self:Close()
			end
		end
	end))
end

function ChestUI:RegisterEvents()
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestOpened", function(data)
		if not data then
			warn("ChestUI: ChestOpened event data is nil!")
			return
		end
		self:Open(
			{x = data.x, y = data.y, z = data.z},
			data.contents or {},
			data.playerInventory or {},
			data.hotbar or {}
		)
	end)

	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestClosed", function(data)
		if self.chestPosition and
		   self.chestPosition.x == data.x and
		   self.chestPosition.y == data.y and
		   self.chestPosition.z == data.z then
			self:Close()
		end
	end)

	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestUpdated", function(data)
		if not self.isOpen then return end
		if not self.chestPosition then return end
		if self.chestPosition.x ~= data.x or self.chestPosition.y ~= data.y or self.chestPosition.z ~= data.z then
			return
		end

		-- Targeted update: compute changes and only redraw changed indices
		if data.contents then
			for i = 1, 27 do
				local incoming = data.contents[i]
				local old = self.chestSlots[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				local oldId = old and not old:IsEmpty() and old:GetItemId() or 0
				local oldCount = old and old:GetCount() or 0
				local newId = not newStack:IsEmpty() and newStack:GetItemId() or 0
				local newCount = newStack:GetCount()
				if oldId ~= newId or oldCount ~= newCount then
					self.chestSlots[i] = newStack
					self:UpdateChestSlotDisplay(i)
				else
					self.chestSlots[i] = newStack
				end
			end
		end

		-- Player inventory is managed by inventoryManager (dense array from server)
		if data.playerInventory then
			self.inventoryManager._syncingFromServer = true
			for i = 1, 27 do
				local incoming = data.playerInventory[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				local old = self.inventoryManager:GetInventorySlot(i)
				local oldId = old and not old:IsEmpty() and old:GetItemId() or 0
				local oldCount = old and old:GetCount() or 0
				local newId = not newStack:IsEmpty() and newStack:GetItemId() or 0
				local newCount = newStack:GetCount()
				if oldId ~= newId or oldCount ~= newCount then
					self.inventoryManager:SetInventorySlot(i, newStack)
					self:UpdateInventorySlotDisplay(i)
				else
					self.inventoryManager:SetInventorySlot(i, newStack)
				end
			end
			self.inventoryManager._syncingFromServer = false
		end

		-- Hotbar is also managed by inventoryManager (dense array from server)
		if data.hotbar then
			self.inventoryManager._syncingFromServer = true
			for i = 1, 9 do
				local incoming = data.hotbar[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				local old = self.inventoryManager:GetHotbarSlot(i)
				local oldId = old and not old:IsEmpty() and old:GetItemId() or 0
				local oldCount = old and old:GetCount() or 0
				local newId = not newStack:IsEmpty() and newStack:GetItemId() or 0
				local newCount = newStack:GetCount()
				if oldId ~= newId or oldCount ~= newCount then
					self.inventoryManager:SetHotbarSlot(i, newStack)
					self:UpdateHotbarSlotDisplay(i)
				else
					self.inventoryManager:SetHotbarSlot(i, newStack)
				end
			end
			self.inventoryManager._syncingFromServer = false
		end
	end)

	-- NEW SYSTEM: Handle server-authoritative click results (now delta-based)
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestActionResult", function(data)
		if not self.isOpen then return end
		if not self.chestPosition then return end
		if not data.chestPosition or
		   self.chestPosition.x ~= data.chestPosition.x or
		   self.chestPosition.y ~= data.chestPosition.y or
		   self.chestPosition.z ~= data.chestPosition.z then
			return
		end

		-- Apply authoritative chest deltas (preferred)
		if data.chestDelta then
			for k, stackData in pairs(data.chestDelta) do
				local i = tonumber(k) or k
				if type(i) == "number" and i >= 1 and i <= 27 then
					local newStack = stackData and ItemStack.Deserialize(stackData) or ItemStack.new(0, 0)
					self.chestSlots[i] = newStack
					self:UpdateChestSlotDisplay(i)
				end
			end
		elseif data.chestContents then
			-- Backward compatibility: dense array
			for i = 1, 27 do
				local incoming = data.chestContents[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				self.chestSlots[i] = newStack
				self:UpdateChestSlotDisplay(i)
			end
		end

		-- Apply authoritative player inventory deltas (preferred)
		if data.inventoryDelta then
			self.inventoryManager._syncingFromServer = true
			for k, stackData in pairs(data.inventoryDelta) do
				local i = tonumber(k) or k
				if type(i) == "number" and i >= 1 and i <= 27 then
					local newStack = stackData and ItemStack.Deserialize(stackData) or ItemStack.new(0, 0)
					self.inventoryManager:SetInventorySlot(i, newStack)
					self:UpdateInventorySlotDisplay(i)
				end
			end
			self.inventoryManager._syncingFromServer = false
		elseif data.playerInventory then
			-- Backward compatibility: dense array
			self.inventoryManager._syncingFromServer = true
			for i = 1, 27 do
				local incoming = data.playerInventory[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				self.inventoryManager:SetInventorySlot(i, newStack)
				self:UpdateInventorySlotDisplay(i)
			end
			self.inventoryManager._syncingFromServer = false
		end

		-- Apply authoritative hotbar deltas (preferred)
		if data.hotbarDelta then
			self.inventoryManager._syncingFromServer = true
			for k, stackData in pairs(data.hotbarDelta) do
				local i = tonumber(k) or k
				if type(i) == "number" and i >= 1 and i <= 9 then
					local newStack = stackData and ItemStack.Deserialize(stackData) or ItemStack.new(0, 0)
					self.inventoryManager:SetHotbarSlot(i, newStack)
					self:UpdateHotbarSlotDisplay(i)
				end
			end
			self.inventoryManager._syncingFromServer = false
		end

		-- Apply authoritative cursor from server
		if data.cursorItem then
			self.cursorStack = ItemStack.Deserialize(data.cursorItem)
		else
			self.cursorStack = ItemStack.new(0, 0)
		end
		self:UpdateCursorDisplay()
	end)
end

function ChestUI:Cleanup()
	for _, conn in pairs(self.connections) do
		conn:Disconnect()
	end
	self.connections = {}

	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

-- Show method (called by UIVisibilityManager)
function ChestUI:Show()
	if not self.gui then return end
	self.gui.Enabled = true
end

-- Hide method (called by UIVisibilityManager)
function ChestUI:Hide()
	if not self.gui then return end
	self.gui.Enabled = false
end

-- IsOpen method (called by UIVisibilityManager)
function ChestUI:IsOpen()
	return self.isOpen
end

return ChestUI
