--[[
	FurnaceUINew.lua
	Minecraft-style furnace UI with 3 slots: Input, Fuel, Output
	Auto-smelts with progress bar and fuel indicator
	
	Note: This file will replace the old FurnaceUI.lua once the refactor is complete.
	The old FurnaceUI.lua will be renamed to SmithingUI.lua for the Anvil system.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local InputService = require(script.Parent.Parent.Input.InputService)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local FurnaceConfig = require(ReplicatedStorage.Configs.FurnaceConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

local FurnaceUI = {}
FurnaceUI.__index = FurnaceUI

local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold

-- Load Upheaval font
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local _ = UpheavalFont
local CUSTOM_FONT_NAME = "Upheaval BRK"

-- Configuration (matching ChestUI/WorldsPanel styling)
local FURNACE_CONFIG = {
	-- Grid dimensions
	COLUMNS = 9,
	INVENTORY_ROWS = 3,
	SLOT_SIZE = 50,
	SLOT_SPACING = 4,
	PADDING = 10,
	SECTION_SPACING = 6,
	LABEL_HEIGHT = 16,
	LABEL_SPACING = 4,
	
	-- Furnace slot sizing (slightly larger for emphasis)
	FURNACE_SLOT_SIZE = 52,
	FURNACE_SLOT_SPACING = 6,
	
	-- Panel structure
	HEADER_HEIGHT = 40,
	SHADOW_HEIGHT = 12,
	
	-- Colors (matching existing UI)
	PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),
	COLUMN_BORDER_COLOR = Color3.fromRGB(77, 77, 77),
	COLUMN_BORDER_THICKNESS = 3,
	SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_BORDER_THICKNESS = 2,
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
	CORNER_RADIUS = 8,
	SLOT_CORNER_RADIUS = 4,
	
	-- Progress/fire colors
	FIRE_ACTIVE_COLOR = Color3.fromRGB(255, 150, 50),
	FIRE_INACTIVE_COLOR = Color3.fromRGB(60, 60, 60),
	PROGRESS_COLOR = Color3.fromRGB(80, 200, 80),
	FUEL_COLOR = Color3.fromRGB(255, 180, 50),
	
	-- Text colors
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),
	
	-- Background image
	BACKGROUND_IMAGE = "rbxassetid://82824299358542",
	BACKGROUND_IMAGE_TRANSPARENCY = 0.6,
}

-- Helper function to get display name
local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then return nil end
	
	if ToolConfig.IsTool(itemId) then
		local toolInfo = ToolConfig.GetToolInfo(itemId)
		return toolInfo and toolInfo.name or "Tool"
	end
	
	if ArmorConfig.IsArmor(itemId) then
		local armorInfo = ArmorConfig.GetArmorInfo(itemId)
		return armorInfo and armorInfo.name or "Armor"
	end
	
	local blockDef = BlockRegistry.Blocks[itemId]
	return blockDef and blockDef.name or "Item"
end

function FurnaceUI.new(inventoryManager)
	local self = setmetatable({}, FurnaceUI)
	
	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar
	
	self.isOpen = false
	self.gui = nil
	self.panel = nil
	self.furnacePosition = nil
	self.hoverItemLabel = nil
	
	-- Furnace slots (3 slots)
	self.inputSlot = ItemStack.new(0, 0)
	self.fuelSlot = ItemStack.new(0, 0)
	self.outputSlot = ItemStack.new(0, 0)
	
	-- Furnace state
	self.fuelBurnTimeRemaining = 0
	self.fuelPercentage = 0
	self.smeltProgress = 0
	
	-- UI slot frames
	self.furnaceSlotFrames = {} -- {input, fuel, output}
	self.inventorySlotFrames = {}
	self.hotbarSlotFrames = {}
	
	-- Progress indicators
	self.fireIndicator = nil
	self.progressBar = nil
	self.fuelBar = nil
	
	-- Cursor state
	self.cursorStack = ItemStack.new(0, 0)
	self.cursorFrame = nil
	
	self.connections = {}
	self.renderConnection = nil
	
	return self
end

function FurnaceUI:Initialize()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "FurnaceUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Cursor ScreenGui (on top)
	self.cursorGui = Instance.new("ScreenGui")
	self.cursorGui.Name = "FurnaceUICursor"
	self.cursorGui.ResetOnSpawn = false
	self.cursorGui.DisplayOrder = 2000
	self.cursorGui.IgnoreGuiInset = true
	self.cursorGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	
	-- Apply responsive scaling
	self:EnsureResponsiveScale(self.gui)
	
	-- Create UI
	self:CreateHoverItemLabel()
	self:CreatePanel()
	self:CreateCursorItem()
	
	-- Bind input
	self:BindInput()
	
	-- Register events
	self:RegisterEvents()
	
	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("furnaceUI", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 150
	})
	
	return self
end

function FurnaceUI:EnsureResponsiveScale(contentFrame)
	if self.uiScale and self.uiScale.Parent then
		return self.uiScale
	end
	
	if not contentFrame then return nil end
	
	local target = contentFrame.Parent
	if not (target and target:IsA("GuiBase2d")) then
		target = contentFrame
	end
	
	self.scaleTarget = target
	
	local existing = target:FindFirstChild("ResponsiveScale")
	if existing and existing:IsA("UIScale") then
		self.uiScale = existing
		return existing
	end
	
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.6)
	uiScale.Parent = target
	CollectionService:AddTag(uiScale, "scale_component")
	self.uiScale = uiScale
	
	return uiScale
end

function FurnaceUI:CreateHoverItemLabel()
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
	
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = label
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	
	local border = Instance.new("UIStroke")
	border.Color = Color3.fromRGB(60, 60, 60)
	border.Thickness = 1
	border.Parent = label
	
	self.hoverItemLabel = label
end

function FurnaceUI:ShowHoverItemName(itemId)
	if not self.hoverItemLabel then return end
	local itemName = GetItemDisplayName(itemId)
	if itemName then
		self.hoverItemLabel.Text = itemName
		self.hoverItemLabel.Visible = true
	else
		self.hoverItemLabel.Visible = false
	end
end

function FurnaceUI:HideHoverItemName()
	if not self.hoverItemLabel then return end
	self.hoverItemLabel.Visible = false
end

function FurnaceUI:CreatePanel()
	-- Calculate dimensions
	local slotWidth = FURNACE_CONFIG.SLOT_SIZE * FURNACE_CONFIG.COLUMNS +
	                  FURNACE_CONFIG.SLOT_SPACING * (FURNACE_CONFIG.COLUMNS - 1)
	local invHeight = FURNACE_CONFIG.SLOT_SIZE * FURNACE_CONFIG.INVENTORY_ROWS +
	                  FURNACE_CONFIG.SLOT_SPACING * (FURNACE_CONFIG.INVENTORY_ROWS - 1)
	local hotbarHeight = FURNACE_CONFIG.SLOT_SIZE
	
	-- Furnace section height (input + progress + output arranged horizontally with fuel)
	local furnaceHeight = FURNACE_CONFIG.FURNACE_SLOT_SIZE + 24 + FURNACE_CONFIG.FURNACE_SLOT_SIZE + 20
	
	local labelHeight = FURNACE_CONFIG.LABEL_HEIGHT
	local labelSpacing = FURNACE_CONFIG.LABEL_SPACING
	
	-- Body height
	local bodyHeight = FURNACE_CONFIG.PADDING +
	                   furnaceHeight +
	                   FURNACE_CONFIG.SECTION_SPACING +
	                   labelHeight + labelSpacing + invHeight +
	                   FURNACE_CONFIG.SECTION_SPACING +
	                   labelHeight + labelSpacing + hotbarHeight +
	                   FURNACE_CONFIG.PADDING
	
	local panelWidth = slotWidth + FURNACE_CONFIG.PADDING * 2
	local totalHeight = FURNACE_CONFIG.HEADER_HEIGHT + bodyHeight
	
	-- Container
	local container = Instance.new("Frame")
	container.Name = "FurnaceContainer"
	container.Size = UDim2.fromOffset(panelWidth, totalHeight)
	container.Position = UDim2.new(0.5, 0, 0.5, -FURNACE_CONFIG.HEADER_HEIGHT)
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = self.gui
	self.container = container
	
	-- Header
	self:CreateHeader(container, panelWidth)
	
	-- Body frame
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.fromOffset(panelWidth, bodyHeight)
	bodyFrame.Position = UDim2.fromOffset(0, FURNACE_CONFIG.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = container
	
	-- Main panel
	self.panel = Instance.new("Frame")
	self.panel.Name = "FurnacePanel"
	self.panel.Size = UDim2.fromOffset(panelWidth, bodyHeight)
	self.panel.Position = UDim2.fromScale(0, 0)
	self.panel.BackgroundColor3 = FURNACE_CONFIG.PANEL_BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.ZIndex = 1
	self.panel.Parent = bodyFrame
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, FURNACE_CONFIG.CORNER_RADIUS)
	corner.Parent = self.panel
	
	-- Shadow
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromOffset(panelWidth, FURNACE_CONFIG.SHADOW_HEIGHT)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.fromOffset(0, bodyHeight)
	shadow.BackgroundColor3 = FURNACE_CONFIG.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = bodyFrame
	
	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, FURNACE_CONFIG.CORNER_RADIUS)
	shadowCorner.Parent = shadow
	
	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = FURNACE_CONFIG.COLUMN_BORDER_COLOR
	stroke.Thickness = FURNACE_CONFIG.COLUMN_BORDER_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = self.panel
	
	local yOffset = FURNACE_CONFIG.PADDING
	
	-- === FURNACE SECTION ===
	self:CreateFurnaceSection(yOffset, panelWidth)
	yOffset = yOffset + furnaceHeight + FURNACE_CONFIG.SECTION_SPACING
	
	-- === INVENTORY SECTION ===
	local invLabel = Instance.new("TextLabel")
	invLabel.Name = "InvLabel"
	invLabel.Size = UDim2.new(1, -FURNACE_CONFIG.PADDING * 2, 0, FURNACE_CONFIG.LABEL_HEIGHT)
	invLabel.Position = UDim2.fromOffset(FURNACE_CONFIG.PADDING, yOffset)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = BOLD_FONT
	invLabel.TextSize = 11
	invLabel.TextColor3 = FURNACE_CONFIG.TEXT_MUTED
	invLabel.Text = "INVENTORY"
	invLabel.TextXAlignment = Enum.TextXAlignment.Left
	invLabel.Parent = self.panel
	
	yOffset = yOffset + FURNACE_CONFIG.LABEL_HEIGHT + FURNACE_CONFIG.LABEL_SPACING
	
	for row = 0, FURNACE_CONFIG.INVENTORY_ROWS - 1 do
		for col = 0, FURNACE_CONFIG.COLUMNS - 1 do
			local index = row * FURNACE_CONFIG.COLUMNS + col + 1
			local x = FURNACE_CONFIG.PADDING + col * (FURNACE_CONFIG.SLOT_SIZE + FURNACE_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (FURNACE_CONFIG.SLOT_SIZE + FURNACE_CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, x, y)
		end
	end
	
	yOffset = yOffset + invHeight + FURNACE_CONFIG.SECTION_SPACING
	
	-- === HOTBAR SECTION ===
	local hotbarLabel = Instance.new("TextLabel")
	hotbarLabel.Name = "HotbarLabel"
	hotbarLabel.Size = UDim2.new(1, -FURNACE_CONFIG.PADDING * 2, 0, FURNACE_CONFIG.LABEL_HEIGHT)
	hotbarLabel.Position = UDim2.fromOffset(FURNACE_CONFIG.PADDING, yOffset)
	hotbarLabel.BackgroundTransparency = 1
	hotbarLabel.Font = BOLD_FONT
	hotbarLabel.TextSize = 11
	hotbarLabel.TextColor3 = FURNACE_CONFIG.TEXT_MUTED
	hotbarLabel.Text = "HOTBAR"
	hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
	hotbarLabel.Parent = self.panel
	
	yOffset = yOffset + FURNACE_CONFIG.LABEL_HEIGHT + FURNACE_CONFIG.LABEL_SPACING
	
	for col = 0, FURNACE_CONFIG.COLUMNS - 1 do
		local index = col + 1
		local x = FURNACE_CONFIG.PADDING + col * (FURNACE_CONFIG.SLOT_SIZE + FURNACE_CONFIG.SLOT_SPACING)
		self:CreateHotbarSlot(index, x, yOffset)
	end
end

function FurnaceUI:CreateHeader(parent, panelWidth)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.fromOffset(panelWidth, FURNACE_CONFIG.HEADER_HEIGHT)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent
	
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "FURNACE"
	title.TextColor3 = FURNACE_CONFIG.TEXT_PRIMARY
	title.Font = Enum.Font.Code
	title.TextSize = 36
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame
	FontBinder.apply(title, CUSTOM_FONT_NAME)
	
	-- Close button
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.fromOffset(32, 32),
		position = UDim2.fromScale(1, 0.5),
		anchorPoint = Vector2.new(1, 0.5)
	})
	
	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.fromOffset(32, 32)
	closeBtn.Position = UDim2.new(1, -4, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Image = closeIcon.Image
	closeBtn.ScaleType = closeIcon.ScaleType
	closeBtn.Parent = headerFrame
	closeIcon:Destroy()
	
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

function FurnaceUI:CreateFurnaceSection(yOffset, panelWidth)
	local slotSize = FURNACE_CONFIG.FURNACE_SLOT_SIZE
	local spacing = FURNACE_CONFIG.FURNACE_SLOT_SPACING
	
	-- Center the furnace slots - horizontal layout: [FUEL] [INPUT] -> [OUTPUT]
	local centerX = panelWidth / 2
	local sectionHeight = slotSize + 24 + slotSize + 16
	
	-- Create furnace section container
	local furnaceSection = Instance.new("Frame")
	furnaceSection.Name = "FurnaceSection"
	furnaceSection.Size = UDim2.new(1, 0, 0, sectionHeight)
	furnaceSection.Position = UDim2.fromOffset(0, yOffset)
	furnaceSection.BackgroundTransparency = 1
	furnaceSection.Parent = self.panel
	
	-- Row 1: INPUT (center-left) -> arrow/progress -> OUTPUT (center-right)
	local row1Y = 4
	local gapBetweenSlots = 70 -- Space for arrow/progress
	
	-- INPUT SLOT (left of center)
	local inputX = centerX - gapBetweenSlots/2 - slotSize
	local inputSlotFrame = self:CreateFurnaceSlot("input", inputX, row1Y, "INPUT")
	self.furnaceSlotFrames.input = inputSlotFrame
	
	-- OUTPUT SLOT (right of center)
	local outputX = centerX + gapBetweenSlots/2
	local outputSlotFrame = self:CreateFurnaceSlot("output", outputX, row1Y, "OUTPUT")
	self.furnaceSlotFrames.output = outputSlotFrame
	
	-- PROGRESS BAR (between input and output)
	self:CreateProgressBar(centerX, row1Y + slotSize/2)
	
	-- Row 2: FUEL SLOT (centered) with fire indicator
	local row2Y = row1Y + slotSize + 12
	local fuelX = centerX - slotSize/2
	local fuelSlotFrame = self:CreateFurnaceSlot("fuel", fuelX, row2Y, "FUEL")
	self.furnaceSlotFrames.fuel = fuelSlotFrame
	
	-- FIRE INDICATOR (left of fuel)
	self:CreateFireIndicator(fuelX - 20, row2Y + slotSize/2)
	
	-- FUEL BAR (right of fuel slot)
	self:CreateFuelBar(fuelX + slotSize + 6, row2Y, slotSize)
end

function FurnaceUI:CreateFurnaceSlot(slotType, x, y, label)
	local size = FURNACE_CONFIG.FURNACE_SLOT_SIZE
	
	local slot = Instance.new("TextButton")
	slot.Name = slotType .. "Slot"
	slot.Size = UDim2.fromOffset(size, size)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = FURNACE_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel:FindFirstChild("FurnaceSection") or self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, FURNACE_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot
	
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = FURNACE_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = FURNACE_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot
	
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = FURNACE_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = FURNACE_CONFIG.SLOT_BORDER_THICKNESS
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot
	
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
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = slot
	
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(36, 16)
	countLabel.Position = UDim2.new(1, -2, 1, -2)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot
	
	-- Label below slot
	local slotLabel = Instance.new("TextLabel")
	slotLabel.Name = "SlotLabel"
	slotLabel.Size = UDim2.fromOffset(size, 12)
	slotLabel.Position = UDim2.fromOffset(x, y + size + 1)
	slotLabel.BackgroundTransparency = 1
	slotLabel.Font = BOLD_FONT
	slotLabel.TextSize = 9
	slotLabel.TextColor3 = FURNACE_CONFIG.TEXT_MUTED
	slotLabel.Text = label or ""
	slotLabel.TextXAlignment = Enum.TextXAlignment.Center
	slotLabel.Parent = self.panel:FindFirstChild("FurnaceSection") or self.panel
	
	local slotData = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder,
		slotType = slotType
	}
	
	-- Hover effects
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = FURNACE_CONFIG.HOVER_COLOR
		local stack = self:GetFurnaceSlotStack(slotType)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)
	
	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
		self:HideHoverItemName()
	end)
	
	-- Click handlers
	slot.MouseButton1Click:Connect(function()
		self:OnFurnaceSlotLeftClick(slotType)
	end)
	
	slot.MouseButton2Click:Connect(function()
		self:OnFurnaceSlotRightClick(slotType)
	end)
	
	return slotData
end

function FurnaceUI:CreateFireIndicator(centerX, y)
	local fireFrame = Instance.new("Frame")
	fireFrame.Name = "FireIndicator"
	fireFrame.Size = UDim2.fromOffset(32, 32)
	fireFrame.Position = UDim2.fromOffset(centerX - 16, y - 16)
	fireFrame.BackgroundColor3 = FURNACE_CONFIG.FIRE_INACTIVE_COLOR
	fireFrame.BackgroundTransparency = 0.5
	fireFrame.BorderSizePixel = 0
	fireFrame.Parent = self.panel:FindFirstChild("FurnaceSection") or self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = fireFrame
	
	-- Fire icon (using text for now)
	local fireIcon = Instance.new("TextLabel")
	fireIcon.Name = "FireIcon"
	fireIcon.Size = UDim2.fromScale(1, 1)
	fireIcon.BackgroundTransparency = 1
	fireIcon.Font = Enum.Font.GothamBold
	fireIcon.TextSize = 20
	fireIcon.TextColor3 = FURNACE_CONFIG.TEXT_PRIMARY
	fireIcon.Text = "🔥"
	fireIcon.TextTransparency = 0.3
	fireIcon.Parent = fireFrame
	
	self.fireIndicator = fireFrame
end

function FurnaceUI:CreateProgressBar(centerX, y)
	local barWidth = 100
	local barHeight = 8
	
	local progressBg = Instance.new("Frame")
	progressBg.Name = "ProgressBackground"
	progressBg.Size = UDim2.fromOffset(barWidth, barHeight)
	progressBg.Position = UDim2.fromOffset(centerX - barWidth/2, y)
	progressBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	progressBg.BorderSizePixel = 0
	progressBg.Parent = self.panel:FindFirstChild("FurnaceSection") or self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = progressBg
	
	local progressFill = Instance.new("Frame")
	progressFill.Name = "ProgressFill"
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = FURNACE_CONFIG.PROGRESS_COLOR
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBg
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = progressFill
	
	self.progressBar = progressFill
end

function FurnaceUI:CreateFuelBar(x, y, height)
	local barWidth = 8
	
	local fuelBg = Instance.new("Frame")
	fuelBg.Name = "FuelBackground"
	fuelBg.Size = UDim2.fromOffset(barWidth, height)
	fuelBg.Position = UDim2.fromOffset(x, y)
	fuelBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	fuelBg.BorderSizePixel = 0
	fuelBg.Parent = self.panel:FindFirstChild("FurnaceSection") or self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = fuelBg
	
	local fuelFill = Instance.new("Frame")
	fuelFill.Name = "FuelFill"
	fuelFill.Size = UDim2.new(1, 0, 0, 0)
	fuelFill.Position = UDim2.fromScale(0, 1)
	fuelFill.AnchorPoint = Vector2.new(0, 1)
	fuelFill.BackgroundColor3 = FURNACE_CONFIG.FUEL_COLOR
	fuelFill.BorderSizePixel = 0
	fuelFill.Parent = fuelBg
	
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fuelFill
	
	self.fuelBar = fuelFill
end

-- Helper to get furnace slot stack
function FurnaceUI:GetFurnaceSlotStack(slotType)
	if slotType == "input" then
		return self.inputSlot
	elseif slotType == "fuel" then
		return self.fuelSlot
	elseif slotType == "output" then
		return self.outputSlot
	end
	return nil
end

function FurnaceUI:SetFurnaceSlotStack(slotType, stack)
	if slotType == "input" then
		self.inputSlot = stack
	elseif slotType == "fuel" then
		self.fuelSlot = stack
	elseif slotType == "output" then
		self.outputSlot = stack
	end
end

-- Create inventory slot (same as ChestUI)
function FurnaceUI:CreateInventorySlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "InventorySlot" .. index
	slot.Size = UDim2.fromOffset(FURNACE_CONFIG.SLOT_SIZE, FURNACE_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = FURNACE_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, FURNACE_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot
	
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = FURNACE_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = FURNACE_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot
	
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = FURNACE_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = FURNACE_CONFIG.SLOT_BORDER_THICKNESS
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot
	
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
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3
	iconContainer.Parent = slot
	
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(36, 16)
	countLabel.Position = UDim2.new(1, -2, 1, -2)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 12
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
	
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = FURNACE_CONFIG.HOVER_COLOR
		local stack = self.inventoryManager:GetInventorySlot(index)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)
	
	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
		self:HideHoverItemName()
	end)
	
	slot.MouseButton1Click:Connect(function()
		self:OnInventorySlotLeftClick(index)
	end)
	
	slot.MouseButton2Click:Connect(function()
		self:OnInventorySlotRightClick(index)
	end)
end

function FurnaceUI:CreateHotbarSlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "HotbarSlot" .. index
	slot.Size = UDim2.fromOffset(FURNACE_CONFIG.SLOT_SIZE, FURNACE_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = FURNACE_CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, FURNACE_CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot
	
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = FURNACE_CONFIG.BACKGROUND_IMAGE
	bgImage.ImageTransparency = FURNACE_CONFIG.BACKGROUND_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot
	
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = FURNACE_CONFIG.SLOT_BORDER_COLOR
	border.Thickness = FURNACE_CONFIG.SLOT_BORDER_THICKNESS
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot
	
	local selectionBorder = Instance.new("UIStroke")
	selectionBorder.Name = "Selection"
	selectionBorder.Color = Color3.fromRGB(220, 220, 220)
	selectionBorder.Thickness = 3
	selectionBorder.Transparency = 1
	selectionBorder.ZIndex = 2
	selectionBorder.Parent = slot
	
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
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 4
	iconContainer.Parent = slot
	
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(36, 16)
	countLabel.Position = UDim2.new(1, -2, 1, -2)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot
	
	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Size = UDim2.fromOffset(16, 16)
	numberLabel.Position = UDim2.fromOffset(2, 2)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Font = BOLD_FONT
	numberLabel.TextSize = 10
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
	
	slot.MouseEnter:Connect(function()
		if self.hotbar and self.hotbar.selectedSlot ~= index then
			hoverBorder.Transparency = 0.5
		end
		slot.BackgroundColor3 = FURNACE_CONFIG.HOVER_COLOR
		if self.hotbar then
			local stack = self.hotbar.slots[index]
			if stack and not stack:IsEmpty() then
				self:ShowHoverItemName(stack:GetItemId())
			end
		end
	end)
	
	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = FURNACE_CONFIG.SLOT_BG_COLOR
		self:HideHoverItemName()
	end)
	
	slot.MouseButton1Click:Connect(function()
		self:OnHotbarSlotLeftClick(index)
	end)
	
	slot.MouseButton2Click:Connect(function()
		self:OnHotbarSlotRightClick(index)
	end)
end

function FurnaceUI:CreateCursorItem()
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.fromOffset(FURNACE_CONFIG.SLOT_SIZE, FURNACE_CONFIG.SLOT_SIZE)
	self.cursorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	self.cursorFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	self.cursorFrame.BackgroundTransparency = 0.7
	self.cursorFrame.BorderSizePixel = 0
	self.cursorFrame.Visible = false
	self.cursorFrame.ZIndex = 1000
	self.cursorFrame.Parent = self.cursorGui
	
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

function FurnaceUI:UpdateFurnaceSlotDisplay(slotType)
	local slotData = self.furnaceSlotFrames[slotType]
	if not slotData then return end
	
	local stack = self:GetFurnaceSlotStack(slotType)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	
	-- Clear existing visuals
	for _, child in ipairs(iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	
	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.fromScale(1, 1))
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		countLabel.Text = ""
	end
end

function FurnaceUI:UpdateProgressIndicators()
	-- Update fire indicator
	if self.fireIndicator then
		local isBurning = self.fuelBurnTimeRemaining > 0
		self.fireIndicator.BackgroundColor3 = isBurning and FURNACE_CONFIG.FIRE_ACTIVE_COLOR or FURNACE_CONFIG.FIRE_INACTIVE_COLOR
		self.fireIndicator.BackgroundTransparency = isBurning and 0.2 or 0.5
		
		local icon = self.fireIndicator:FindFirstChild("FireIcon")
		if icon then
			icon.TextTransparency = isBurning and 0 or 0.5
		end
	end
	
	-- Update progress bar
	if self.progressBar then
		self.progressBar.Size = UDim2.new(math.clamp(self.smeltProgress, 0, 1), 0, 1, 0)
	end
	
	-- Update fuel bar
	if self.fuelBar then
		self.fuelBar.Size = UDim2.new(1, 0, math.clamp(self.fuelPercentage, 0, 1), 0)
	end
end

function FurnaceUI:UpdateInventorySlotDisplay(index)
	local slotData = self.inventorySlotFrames[index]
	if not slotData then return end
	
	local stack = self.inventoryManager:GetInventorySlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	
	for _, child in ipairs(iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	
	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.fromScale(1, 1))
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		countLabel.Text = ""
	end
end

function FurnaceUI:UpdateHotbarSlotDisplay(index)
	if not self.hotbar then return end
	
	local slotData = self.hotbarSlotFrames[index]
	if not slotData then return end
	
	local stack = self.inventoryManager:GetHotbarSlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	
	for _, child in ipairs(iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	
	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.fromScale(1, 1))
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		countLabel.Text = ""
	end
	
	if self.hotbar.selectedSlot == index then
		slotData.selectionBorder.Transparency = 0
	else
		slotData.selectionBorder.Transparency = 1
	end
end

function FurnaceUI:UpdateCursorDisplay()
	if not self.cursorFrame then return end
	
	local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
	local countLabel = self.cursorFrame:FindFirstChild("CountLabel")
	if not iconContainer or not countLabel then return end
	
	for _, child in ipairs(iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end
	
	if self.cursorStack and not self.cursorStack:IsEmpty() then
		local itemId = self.cursorStack:GetItemId()
		BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.fromScale(1, 1))
		countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		self.cursorFrame.Visible = true
	else
		countLabel.Text = ""
		self.cursorFrame.Visible = false
	end
end

function FurnaceUI:UpdateAllDisplays()
	self:UpdateFurnaceSlotDisplay("input")
	self:UpdateFurnaceSlotDisplay("fuel")
	self:UpdateFurnaceSlotDisplay("output")
	self:UpdateProgressIndicators()
	
	for i = 1, 27 do
		self:UpdateInventorySlotDisplay(i)
	end
	
	for i = 1, 9 do
		self:UpdateHotbarSlotDisplay(i)
	end
	
	self:UpdateCursorDisplay()
end

-- === CLICK HANDLERS ===

local function IsShiftHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

function FurnaceUI:OnFurnaceSlotLeftClick(slotType)
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local stack = self:GetFurnaceSlotStack(slotType)
		if stack and not stack:IsEmpty() then
			EventManager:SendToServer("FurnaceQuickTransfer", {
				furnacePos = self.furnacePosition,
				slotType = slotType
			})
			return
		end
	end
	
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = slotType,
		clickType = "left"
	})
end

function FurnaceUI:OnFurnaceSlotRightClick(slotType)
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = slotType,
		clickType = "right"
	})
end

function FurnaceUI:OnInventorySlotLeftClick(index)
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local stack = self.inventoryManager:GetInventorySlot(index)
		if stack and not stack:IsEmpty() then
			EventManager:SendToServer("FurnaceQuickTransfer", {
				furnacePos = self.furnacePosition,
				slotType = "inventory",
				slotIndex = index
			})
			return
		end
	end
	
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = "inventory",
		slotIndex = index,
		clickType = "left"
	})
end

function FurnaceUI:OnInventorySlotRightClick(index)
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = "inventory",
		slotIndex = index,
		clickType = "right"
	})
end

function FurnaceUI:OnHotbarSlotLeftClick(index)
	if not self.hotbar then return end
	
	if IsShiftHeld() and self.cursorStack:IsEmpty() then
		local stack = self.inventoryManager:GetHotbarSlot(index)
		if stack and not stack:IsEmpty() then
			EventManager:SendToServer("FurnaceQuickTransfer", {
				furnacePos = self.furnacePosition,
				slotType = "hotbar",
				slotIndex = index
			})
			return
		end
	end
	
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = "hotbar",
		slotIndex = index,
		clickType = "left"
	})
end

function FurnaceUI:OnHotbarSlotRightClick(index)
	if not self.hotbar then return end
	
	EventManager:SendToServer("FurnaceSlotClick", {
		furnacePos = self.furnacePosition,
		slotType = "hotbar",
		slotIndex = index,
		clickType = "right"
	})
end

-- === LIFECYCLE ===

function FurnaceUI:Open(furnacePos, data)
	if not self.gui then
		warn("FurnaceUI:Open - gui is nil!")
		return
	end
	
	self.isOpen = true
	self.furnacePosition = furnacePos
	
	UIVisibilityManager:SetMode("furnace")
	
	-- Load furnace state from data
	self.inputSlot = data.inputSlot and ItemStack.Deserialize(data.inputSlot) or ItemStack.new(0, 0)
	self.fuelSlot = data.fuelSlot and ItemStack.Deserialize(data.fuelSlot) or ItemStack.new(0, 0)
	self.outputSlot = data.outputSlot and ItemStack.Deserialize(data.outputSlot) or ItemStack.new(0, 0)
	self.fuelBurnTimeRemaining = data.fuelBurnTimeRemaining or 0
	self.fuelPercentage = data.fuelPercentage or 0
	self.smeltProgress = data.smeltProgress or 0
	
	-- Sync player inventory
	if data.playerInventory then
		self.inventoryManager._syncingFromServer = true
		for i = 1, 27 do
			if data.playerInventory[i] then
				local stack = ItemStack.Deserialize(data.playerInventory[i])
				self.inventoryManager:SetInventorySlot(i, stack or ItemStack.new(0, 0))
			else
				self.inventoryManager:SetInventorySlot(i, ItemStack.new(0, 0))
			end
		end
		self.inventoryManager._syncingFromServer = false
	end
	
	if data.hotbar then
		self.inventoryManager._syncingFromServer = true
		for i = 1, 9 do
			if data.hotbar[i] then
				local stack = ItemStack.Deserialize(data.hotbar[i])
				self.inventoryManager:SetHotbarSlot(i, stack or ItemStack.new(0, 0))
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
	
	-- Start cursor tracking
	self.renderConnection = RunService.RenderStepped:Connect(function()
		if self.isOpen then
			self:UpdateCursorPosition()
		end
	end)
end

function FurnaceUI:Close(nextMode)
	if not self.isOpen then return end
	
	self:HideHoverItemName()
	self.isOpen = false
	
	-- Return cursor items
	if not self.cursorStack:IsEmpty() then
		self.cursorStack = ItemStack.new(0, 0)
		self:UpdateCursorDisplay()
	end
	
	-- Notify server
	if self.furnacePosition then
		EventManager:SendToServer("RequestCloseFurnace", {
			x = self.furnacePosition.x,
			y = self.furnacePosition.y,
			z = self.furnacePosition.z
		})
		self.furnacePosition = nil
	end
	
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end
	
	self.gui.Enabled = false
	
	local targetMode = nextMode or "gameplay"
	UIVisibilityManager:SetMode(targetMode)
end

function FurnaceUI:UpdateCursorPosition()
	if not self.cursorFrame or not self.cursorFrame.Visible then return end
	local mousePos = InputService:GetMouseLocation()
	self.cursorFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
end

function FurnaceUI:BindInput()
	table.insert(self.connections, InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Escape then
			if self.isOpen then
				self:Close()
			end
		end
	end))
end

function FurnaceUI:RegisterEvents()
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("FurnaceOpened", function(data)
		if not data then return end
		self:Open(
			{x = data.x, y = data.y, z = data.z},
			data
		)
	end)
	
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("FurnaceUpdated", function(data)
		if not self.isOpen then return end
		if not self.furnacePosition then return end
		
		local pos = data.furnacePos
		if not pos or pos.x ~= self.furnacePosition.x or pos.y ~= self.furnacePosition.y or pos.z ~= self.furnacePosition.z then
			return
		end
		
		-- Update furnace state
		self.inputSlot = data.inputSlot and ItemStack.Deserialize(data.inputSlot) or ItemStack.new(0, 0)
		self.fuelSlot = data.fuelSlot and ItemStack.Deserialize(data.fuelSlot) or ItemStack.new(0, 0)
		self.outputSlot = data.outputSlot and ItemStack.Deserialize(data.outputSlot) or ItemStack.new(0, 0)
		self.fuelBurnTimeRemaining = data.fuelBurnTimeRemaining or 0
		self.fuelPercentage = data.fuelPercentage or 0
		self.smeltProgress = data.smeltProgress or 0
		
		self:UpdateFurnaceSlotDisplay("input")
		self:UpdateFurnaceSlotDisplay("fuel")
		self:UpdateFurnaceSlotDisplay("output")
		self:UpdateProgressIndicators()
	end)
	
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("FurnaceActionResult", function(data)
		if not self.isOpen then return end
		if not self.furnacePosition then return end
		
		local pos = data.furnacePos
		if not pos or pos.x ~= self.furnacePosition.x or pos.y ~= self.furnacePosition.y or pos.z ~= self.furnacePosition.z then
			return
		end
		
		-- Update furnace slots
		self.inputSlot = data.inputSlot and ItemStack.Deserialize(data.inputSlot) or ItemStack.new(0, 0)
		self.fuelSlot = data.fuelSlot and ItemStack.Deserialize(data.fuelSlot) or ItemStack.new(0, 0)
		self.outputSlot = data.outputSlot and ItemStack.Deserialize(data.outputSlot) or ItemStack.new(0, 0)
		self.fuelBurnTimeRemaining = data.fuelBurnTimeRemaining or 0
		self.fuelPercentage = data.fuelPercentage or 0
		self.smeltProgress = data.smeltProgress or 0
		
		-- Update player inventory
		if data.playerInventory then
			self.inventoryManager._syncingFromServer = true
			for i = 1, 27 do
				local stack = data.playerInventory[i] and ItemStack.Deserialize(data.playerInventory[i]) or ItemStack.new(0, 0)
				self.inventoryManager:SetInventorySlot(i, stack)
				self:UpdateInventorySlotDisplay(i)
			end
			self.inventoryManager._syncingFromServer = false
		end
		
		if data.hotbar then
			self.inventoryManager._syncingFromServer = true
			for i = 1, 9 do
				local stack = data.hotbar[i] and ItemStack.Deserialize(data.hotbar[i]) or ItemStack.new(0, 0)
				self.inventoryManager:SetHotbarSlot(i, stack)
				self:UpdateHotbarSlotDisplay(i)
			end
			self.inventoryManager._syncingFromServer = false
		end
		
		-- Update cursor
		if data.cursorItem then
			self.cursorStack = ItemStack.Deserialize(data.cursorItem)
		else
			self.cursorStack = ItemStack.new(0, 0)
		end
		
		self:UpdateFurnaceSlotDisplay("input")
		self:UpdateFurnaceSlotDisplay("fuel")
		self:UpdateFurnaceSlotDisplay("output")
		self:UpdateProgressIndicators()
		self:UpdateCursorDisplay()
	end)
end

function FurnaceUI:Cleanup()
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

function FurnaceUI:Show()
	if not self.gui then return end
	self.gui.Enabled = true
end

function FurnaceUI:Hide()
	if not self.gui then return end
	self.gui.Enabled = false
end

function FurnaceUI:IsOpen()
	return self.isOpen
end

return FurnaceUI
