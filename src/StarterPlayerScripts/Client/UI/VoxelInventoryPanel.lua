--[[
	VoxelInventoryPanel.lua
	Minecraft-style inventory panel (press E to open)
	Full drag-and-drop system with stack management

	Minecraft Mechanics:
	- Left Click: Pick up/place entire stack, or swap stacks
	- Right Click: Pick up half stack / Place one item
	- Shift+Click: Quick transfer between inventory and hotbar
	- Stacks merge when compatible (up to 64)
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)

local CUSTOM_FONT_NAME = "Zephyrean BRK"

local VoxelInventoryPanel = {}
VoxelInventoryPanel.__index = VoxelInventoryPanel

-- Inventory configuration (optimized for compactness)
local INVENTORY_CONFIG = {
	COLUMNS = 9,
	ROWS = 3, -- 3 rows of storage (27 slots) + 9 hotbar slots = 36 total
	SLOT_SIZE = 44,        -- Reduced from 52 for compactness
	SLOT_SPACING = 3,      -- Reduced from 4
	PADDING = 6,           -- Ultra-minimal padding
	SECTION_SPACING = 8,   -- Minimal section spacing

	-- Equipment slots (left side)
	EQUIPMENT_SLOT_SIZE = 44,  -- Same as inventory slots
	EQUIPMENT_SPACING = 3,      -- Same as slot spacing
	EQUIPMENT_GAP = 12,         -- Minimal gap between equipment and inventory

	-- Colors
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
	EQUIPMENT_COLOR = Color3.fromRGB(50, 50, 60),  -- Slightly different tint for equipment
}

function VoxelInventoryPanel.new(inventoryManager)
	local self = setmetatable({}, VoxelInventoryPanel)

	-- Use centralized inventory manager
	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar

	self.isOpen = false

	-- Ensure crafting detail page is closed so next open shows overview
	if self.craftingPanel and self.craftingPanel.HideRecipeDetailPage then
		pcall(function()
			self.craftingPanel:HideRecipeDetailPage()
		end)
	end
	self.gui = nil
	self.panel = nil

	-- UI slot frames
	self.inventorySlotFrames = {}
	self.equipmentSlotFrames = {}  -- Head, Chest, Leggings, Boots

	-- Cursor/drag state (Minecraft-style)
	self.cursorStack = ItemStack.new(0, 0) -- Item attached to cursor
	self.cursorFrame = nil

	self.connections = {}
	self.renderConnection = nil

	return self
end

function VoxelInventoryPanel:Initialize()
	FontBinder.preload(CUSTOM_FONT_NAME)

	-- Create ScreenGui for inventory panel
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VoxelInventory"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100  -- Below tooltips
	self.gui.IgnoreGuiInset = true
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Create separate ScreenGui for cursor (must be on top of everything)
	self.cursorGui = Instance.new("ScreenGui")
	self.cursorGui.Name = "VoxelInventoryCursor"
	self.cursorGui.ResetOnSpawn = false
	self.cursorGui.DisplayOrder = 2000  -- Always on top
	self.cursorGui.IgnoreGuiInset = true
	self.cursorGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Add responsive scaling (100% = original size)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080)) -- 1920x1080 for 100% original size
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")
	print("📐 VoxelInventoryPanel: Added UIScale with base resolution 1920x1080 (100% original size)")

	-- Create panels
	self:CreatePanel()
	self:CreateCursorItem()

	-- Bind input
	self:BindInput()

	return self
end

function VoxelInventoryPanel:CreatePanel()
	local slotWidth = INVENTORY_CONFIG.SLOT_SIZE * INVENTORY_CONFIG.COLUMNS +
	                  INVENTORY_CONFIG.SLOT_SPACING * (INVENTORY_CONFIG.COLUMNS - 1)
	local storageHeight = INVENTORY_CONFIG.SLOT_SIZE * INVENTORY_CONFIG.ROWS +
	                      INVENTORY_CONFIG.SLOT_SPACING * (INVENTORY_CONFIG.ROWS - 1)
	local hotbarHeight = INVENTORY_CONFIG.SLOT_SIZE

	-- Equipment slots (4 slots vertical: Head, Chest, Leggings, Boots)
	local equipmentWidth = INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE
	local equipmentTotalHeight = (INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE * 4) +
	                             (INVENTORY_CONFIG.EQUIPMENT_SPACING * 3)

	local headerHeight = 44

	-- Calculate proper height accounting for all elements (ultra-compact layout):
	-- Header + Top Padding (10) + Inv Label (18) + Storage + Spacing + Hotbar Label (18) + Hotbar + Bottom Padding (10)
	local totalHeight = headerHeight + 10 + 18 + storageHeight + INVENTORY_CONFIG.SECTION_SPACING + 18 + hotbarHeight + 10

	-- Crafting section dimensions (ultra-compact)
	local CRAFTING_WIDTH = 230  -- Ultra-compact width (detail page overlays anyway)
	local CRAFTING_GAP = 12     -- Minimal gap

	-- Total width: Equipment + Gap + Divider + Gap + Inventory + Gap + Crafting + Padding
	local totalWidth = equipmentWidth + INVENTORY_CONFIG.EQUIPMENT_GAP + slotWidth + CRAFTING_GAP + CRAFTING_WIDTH + INVENTORY_CONFIG.PADDING * 2

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = self.gui

	-- Main panel (expanded for crafting)
	self.panel = Instance.new("Frame")
	self.panel.Name = "InventoryPanel"
	self.panel.Size = UDim2.new(0, totalWidth, 0, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundColor3 = INVENTORY_CONFIG.BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.panel

	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = INVENTORY_CONFIG.BORDER_COLOR
	stroke.Thickness = 3
	stroke.Parent = self.panel

	-- Header frame (transparent, for title positioning)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, headerHeight)
	headerFrame.BackgroundTransparency = 1
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = self.panel

	-- Title container (inside header for compact layout)
	local titleContainer = Instance.new("Frame")
	titleContainer.Name = "TitleContainer"
	titleContainer.Size = UDim2.new(1, -72, 1, 0)
	titleContainer.Position = UDim2.new(0, 12, 0, 0)
	titleContainer.BackgroundTransparency = 1
	titleContainer.Parent = headerFrame

	-- Title container padding
	local titlePadding = Instance.new("UIPadding")
	titlePadding.PaddingLeft = UDim.new(0, 0)
	titlePadding.PaddingRight = UDim.new(0, 0)
	titlePadding.Parent = titleContainer

	-- Horizontal layout for title
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Padding = UDim.new(0, 12)
	titleLayout.Parent = titleContainer

	-- Title text (styled like SettingsPanel)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 1, 0)
	title.BackgroundTransparency = 1
	title.RichText = false
	title.Text = "Inventory"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 36
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.LayoutOrder = 1
	title.Parent = titleContainer

	FontBinder.apply(title, CUSTOM_FONT_NAME)

	-- Keep reference for dynamic title updates (Inventory vs Workbench)
	self.titleLabel = title

	-- Close button (same style as SettingsPanel) - positioned to stick out of top right corner
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.new(0, 40, 0, 40),
		position = UDim2.new(1, 2, 0, -2),  -- Reduced offset to account for 3px border
		anchorPoint = Vector2.new(0.5, 0.5)
	})

	-- Convert to ImageButton for interaction
	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = closeIcon.Size
	closeBtn.Position = closeIcon.Position
	closeBtn.AnchorPoint = closeIcon.AnchorPoint
	closeBtn.BackgroundTransparency = 1
	closeBtn.Image = closeIcon.Image
	closeBtn.ScaleType = closeIcon.ScaleType
	closeBtn.Parent = headerFrame

	-- Add rounded corners
	local closeButtonCorner = Instance.new("UICorner")
	closeButtonCorner.CornerRadius = UDim.new(0, 4)
	closeButtonCorner.Parent = closeBtn

	-- Add rotation animation on mouse enter/leave
	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	closeBtn.MouseEnter:Connect(function()
		local rotationTween = TweenService:Create(closeBtn, rotationTweenInfo, {
			Rotation = 90
		})
		rotationTween:Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		local rotationTween = TweenService:Create(closeBtn, rotationTweenInfo, {
			Rotation = 0
		})
		rotationTween:Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-- Remove original icon
	closeIcon:Destroy()

	local contentStartY = headerHeight + 12
	local yOffset = contentStartY  -- Top padding below header

	-- Equipment base X position (left side)
	local equipmentX = INVENTORY_CONFIG.PADDING

	-- Inventory base X position (after equipment + gap + divider space)
	local inventoryBaseX = INVENTORY_CONFIG.PADDING + equipmentWidth + INVENTORY_CONFIG.EQUIPMENT_GAP

	-- Inventory label (grey, caps, no icon)
	local invLabel = Instance.new("TextLabel")
	invLabel.Name = "InvLabel"
	invLabel.Size = UDim2.new(0, storageWidth, 0, 14)
	invLabel.Position = UDim2.new(0, inventoryBaseX, 0, yOffset)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = Enum.Font.GothamMedium
	invLabel.TextSize = 11
	invLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	invLabel.Text = "INVENTORY"
	invLabel.TextXAlignment = Enum.TextXAlignment.Left
	invLabel.Parent = self.panel

	yOffset = yOffset + 16

	-- Create equipment slots (4 slots vertical: Head, Chest, Leggings, Boots)
	local equipmentTypes = {"Head", "Chest", "Leggings", "Boots"}
	local equipmentStartY = yOffset  -- Aligned with inventory slots
	for i = 1, 4 do
		local equipY = equipmentStartY + (i - 1) * (INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE + INVENTORY_CONFIG.EQUIPMENT_SPACING + 2)  -- +2 for extra spacing
		self:CreateEquipmentSlot(i, equipmentTypes[i], equipmentX, equipY)
	end

	-- Create inventory slots (3 rows of 9)
	for row = 0, INVENTORY_CONFIG.ROWS - 1 do
		for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
			local index = row * INVENTORY_CONFIG.COLUMNS + col + 1
			local x = inventoryBaseX + col * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, x, y)
		end
	end

	yOffset = yOffset + storageHeight + INVENTORY_CONFIG.SECTION_SPACING

	-- Hotbar label (grey, caps, no icon)
	local hotbarLabel = Instance.new("TextLabel")
	hotbarLabel.Name = "HotbarLabel"
	hotbarLabel.Size = UDim2.new(0, storageWidth, 0, 14)
	hotbarLabel.Position = UDim2.new(0, inventoryBaseX, 0, yOffset)
	hotbarLabel.BackgroundTransparency = 1
	hotbarLabel.Font = Enum.Font.GothamMedium
	hotbarLabel.TextSize = 11
	hotbarLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	hotbarLabel.Text = "HOTBAR"
	hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
	hotbarLabel.Parent = self.panel

	yOffset = yOffset + 16

	-- Hotbar slots (reference only, actual data in hotbar)
	for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
		local x = inventoryBaseX + col * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
		self:CreateHotbarSlot(col + 1, x, yOffset)
	end

	-- Equipment divider (between equipment and inventory)
	local equipmentDivider = Instance.new("Frame")
	equipmentDivider.Name = "EquipmentDivider"
	equipmentDivider.Size = UDim2.new(0, 2, 0, totalHeight - contentStartY - 18)
	equipmentDivider.Position = UDim2.new(0, equipmentX + equipmentWidth + INVENTORY_CONFIG.EQUIPMENT_GAP/2 - 1, 0, contentStartY - 4)
	equipmentDivider.BackgroundColor3 = INVENTORY_CONFIG.BORDER_COLOR
	equipmentDivider.BackgroundTransparency = 0.5
	equipmentDivider.BorderSizePixel = 0
	equipmentDivider.Parent = self.panel

	-- Crafting label (grey, caps, no icon)
	local craftingLabel = Instance.new("TextLabel")
	craftingLabel.Name = "CraftingLabel"
	craftingLabel.Size = UDim2.new(0, CRAFTING_WIDTH, 0, 14)
	craftingLabel.Position = UDim2.new(0, inventoryBaseX + slotWidth + CRAFTING_GAP, 0, contentStartY - 2)
	craftingLabel.BackgroundTransparency = 1
	craftingLabel.Font = Enum.Font.GothamMedium
	craftingLabel.TextSize = 11
	craftingLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	craftingLabel.Text = "CRAFTING"
	craftingLabel.TextXAlignment = Enum.TextXAlignment.Left
	craftingLabel.Parent = self.panel

	-- Crafting section (right side, expanded)
	local craftingSection = Instance.new("Frame")
	craftingSection.Name = "CraftingSection"
	craftingSection.Size = UDim2.new(0, CRAFTING_WIDTH, 0, totalHeight - contentStartY - 20)
	craftingSection.Position = UDim2.new(0, inventoryBaseX + slotWidth + CRAFTING_GAP, 0, contentStartY + 14)
	craftingSection.BackgroundTransparency = 1
	craftingSection.Parent = self.panel

	-- Crafting divider (between inventory and crafting)
	local craftingDivider = Instance.new("Frame")
	craftingDivider.Name = "CraftingDivider"
	craftingDivider.Size = UDim2.new(0, 2, 0, totalHeight - contentStartY - 18)
	craftingDivider.Position = UDim2.new(0, inventoryBaseX + slotWidth + CRAFTING_GAP/2 - 1, 0, contentStartY - 4)
	craftingDivider.BackgroundColor3 = INVENTORY_CONFIG.BORDER_COLOR
	craftingDivider.BackgroundTransparency = 0.5
	craftingDivider.BorderSizePixel = 0
	craftingDivider.Parent = self.panel

	-- Initialize crafting panel
	local CraftingPanel = require(script.Parent.CraftingPanel)
	self.craftingPanel = CraftingPanel.new(self.inventoryManager, self, craftingSection)
	self.craftingPanel:Initialize()

end

function VoxelInventoryPanel:CreateInventorySlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "InventorySlot" .. index
	slot.Size = UDim2.new(0, INVENTORY_CONFIG.SLOT_SIZE, 0, INVENTORY_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = INVENTORY_CONFIG.SLOT_COLOR
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

	-- Create container for viewport - fills entire slot
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

	-- Count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 4 -- Above viewport
	countLabel.Parent = slot

	self.inventorySlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder
	}

	-- Hover effect - highlight when cursor over, especially when dragging
	slot.MouseEnter:Connect(function()
		-- Show border when hovering
		hoverBorder.Transparency = 0.5
		-- Lighten background slightly
		slot.BackgroundColor3 = INVENTORY_CONFIG.HOVER_COLOR
	end)

	slot.MouseLeave:Connect(function()
		-- Hide border when not hovering
		hoverBorder.Transparency = 1
		-- Restore background
		slot.BackgroundColor3 = INVENTORY_CONFIG.SLOT_COLOR
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

function VoxelInventoryPanel:CreateHotbarSlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "HotbarSlot" .. index
	slot.Size = UDim2.new(0, INVENTORY_CONFIG.SLOT_SIZE, 0, INVENTORY_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = INVENTORY_CONFIG.SLOT_COLOR
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Selection indicator (if this is the active hotbar slot) - bright white, thick
	local selectionBorder = Instance.new("UIStroke")
	selectionBorder.Name = "Selection"
	selectionBorder.Color = Color3.fromRGB(220, 220, 220)
	selectionBorder.Thickness = 3
	selectionBorder.Transparency = 1
	selectionBorder.Parent = slot

	-- Hover border (for drag-and-drop feedback)
	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(180, 180, 180)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.Parent = slot

	-- Create container for viewport - fills entire slot
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

	-- Count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 4 -- Above viewport
	countLabel.Parent = slot

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Size = UDim2.new(0, 20, 0, 20)
	numberLabel.Position = UDim2.new(0, 4, 0, 4)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Font = Enum.Font.GothamBold
	numberLabel.TextSize = 12
	numberLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	numberLabel.TextStrokeTransparency = 0.5
	numberLabel.Text = tostring(index)
	numberLabel.TextXAlignment = Enum.TextXAlignment.Left
	numberLabel.TextYAlignment = Enum.TextYAlignment.Top
	numberLabel.ZIndex = 3
	numberLabel.Parent = slot

	-- Hover effect - show border and highlight when dragging items
	slot.MouseEnter:Connect(function()
		-- Show hover border (unless selection border is active)
		if self.hotbar and self.hotbar.selectedSlot ~= index then
			hoverBorder.Transparency = 0.5
		end
		-- Lighten background
		slot.BackgroundColor3 = INVENTORY_CONFIG.HOVER_COLOR
	end)

	slot.MouseLeave:Connect(function()
		-- Hide hover border
		hoverBorder.Transparency = 1
		-- Restore background
		slot.BackgroundColor3 = INVENTORY_CONFIG.SLOT_COLOR
	end)

	-- Click handlers
	slot.MouseButton1Click:Connect(function()
		self:OnHotbarSlotLeftClick(index)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnHotbarSlotRightClick(index)
	end)

	-- Update display from hotbar
	self:UpdateHotbarSlotDisplay(index, slot, iconContainer, countLabel, selectionBorder)
end

function VoxelInventoryPanel:CreateEquipmentSlot(index, equipmentType, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "EquipmentSlot" .. equipmentType
	slot.Size = UDim2.new(0, INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE, 0, INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = INVENTORY_CONFIG.EQUIPMENT_COLOR
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

	-- Create container for viewport - slightly inset for padding
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -6, 1, -6)  -- 3px padding on all sides
	iconContainer.Position = UDim2.new(0, 3, 0, 3)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

	-- Equipment type icon/label (when empty)
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "TypeLabel"
	typeLabel.Size = UDim2.new(1, 0, 1, 0)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Font = Enum.Font.Gotham
	typeLabel.TextSize = 8  -- Smaller text
	typeLabel.TextColor3 = Color3.fromRGB(100, 100, 120)  -- More subtle
	typeLabel.Text = equipmentType
	typeLabel.TextXAlignment = Enum.TextXAlignment.Center
	typeLabel.TextYAlignment = Enum.TextYAlignment.Center
	typeLabel.ZIndex = 2
	typeLabel.Parent = slot

	self.equipmentSlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		typeLabel = typeLabel,
		hoverBorder = hoverBorder,
		equipmentType = equipmentType
	}

	-- Hover effect
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = INVENTORY_CONFIG.HOVER_COLOR
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = INVENTORY_CONFIG.EQUIPMENT_COLOR
	end)

	-- Click handlers (for future equipment system)
	slot.MouseButton1Click:Connect(function()
		self:OnEquipmentSlotLeftClick(index, equipmentType)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnEquipmentSlotRightClick(index, equipmentType)
	end)

	-- TODO: Update display when equipment system is implemented
	-- For now, equipment slots are always empty
end

function VoxelInventoryPanel:CreateCursorItem()
	-- Item that follows cursor when dragging
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.new(0, INVENTORY_CONFIG.SLOT_SIZE, 0, INVENTORY_CONFIG.SLOT_SIZE)
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

	-- Create container for viewport - fills entire cursor frame
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 1001
	iconContainer.Parent = self.cursorFrame

	-- Count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 12
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 1002
	countLabel.Parent = self.cursorFrame
end

function VoxelInventoryPanel:UpdateInventorySlotDisplay(index)
	local slotFrame = self.inventorySlotFrames[index]
	if not slotFrame then return end

	local stack = self.inventoryManager:GetInventorySlot(index)
	local currentItemId = slotFrame.currentItemId  -- slotFrame is a table, use table property

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		-- Only recreate viewport/image if item type changed (performance optimization)
		if currentItemId ~= itemId then
			-- Clear cached ID FIRST to prevent race conditions
			slotFrame.currentItemId = nil

			-- Clear ALL existing visuals (ViewportContainer, ToolImage, ImageLabel, etc.)
			for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
					child:Destroy()
				end
			end

			if isTool then
				local info = ToolConfig.GetToolInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
			elseif SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
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

			-- Set new item ID AFTER creating visuals
			slotFrame.currentItemId = itemId  -- slotFrame is a table
		end

		-- Always update count (cheap operation)
		slotFrame.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear cached ID IMMEDIATELY to prevent race conditions
		slotFrame.currentItemId = nil
		slotFrame.countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
			-- Keep only UI layout objects, destroy everything else
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

function VoxelInventoryPanel:UpdateHotbarSlotDisplay(index, slot, iconContainer, countLabel, selectionBorder)
	if not self.hotbar then return end

	local stack = self.hotbar:GetSlot(index)
	local currentItemId = slot:GetAttribute("CurrentItemId")  -- slot is an Instance, use attributes

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		-- Only recreate viewport/image if item type changed (performance optimization)
		if currentItemId ~= itemId then
			-- Clear attribute FIRST to prevent race conditions
			slot:SetAttribute("CurrentItemId", nil)

			-- Clear ALL existing visuals (ViewportContainer, ToolImage, ImageLabel, etc.)
			for _, child in ipairs(iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
					child:Destroy()
				end
			end

			if isTool then
				local info = ToolConfig.GetToolInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = iconContainer
			elseif SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
				icon.Position = UDim2.new(0.5, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = iconContainer
			else
				BlockViewportCreator.CreateBlockViewport(
					iconContainer,
					itemId,
					UDim2.new(1, 0, 1, 0)
				)
			end

			-- Set new item ID AFTER creating visuals
			slot:SetAttribute("CurrentItemId", itemId)  -- slot is an Instance, use attributes
		end

		-- Always update count (cheap operation)
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		slot:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end

	-- Highlight if this is the selected hotbar slot
	if self.hotbar.selectedSlot == index then
		selectionBorder.Transparency = 0
	else
		selectionBorder.Transparency = 1
	end
end

function VoxelInventoryPanel:UpdateAllDisplays()
	-- Update inventory slots (27)
	for i = 1, 27 do
		self:UpdateInventorySlotDisplay(i)
	end

	-- Update hotbar slots from hotbar data
	for i = 1, 9 do
		local slotName = "HotbarSlot" .. i
		local slot = self.panel:FindFirstChild(slotName)
		if slot then
			local iconContainer = slot:FindFirstChild("IconContainer")
			local countLabel = slot:FindFirstChild("CountLabel")
			local selectionBorder = slot:FindFirstChild("Selection")
			self:UpdateHotbarSlotDisplay(i, slot, iconContainer, countLabel, selectionBorder)
		end
	end

	-- Update cursor item
	self:UpdateCursorDisplay()
end

-- Smart update - check what actually changed and only update those slots
function VoxelInventoryPanel:UpdateChangedSlots()
	-- Check inventory slots (compare cached vs actual)
	for i = 1, 27 do
		local slotFrame = self.inventorySlotFrames[i]
		if slotFrame then
			local stack = self.inventoryManager:GetInventorySlot(i)
			local cachedItemId = slotFrame.currentItemId
			local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

			-- Update if item ID changed
			if cachedItemId ~= actualItemId then
				-- Item changed (including nil -> item, item -> nil, or item A -> item B)
				self:UpdateInventorySlotDisplay(i)
			elseif actualItemId and stack then
				-- Same item, just update count (cheap operation)
				slotFrame.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
			end
		end
	end

	-- Check hotbar slots
	if self.hotbar then
		for i = 1, 9 do
			local slotName = "HotbarSlot" .. i
			local slot = self.panel:FindFirstChild(slotName)
			if slot then
				local iconContainer = slot:FindFirstChild("IconContainer")
				local countLabel = slot:FindFirstChild("CountLabel")
				local stack = self.hotbar:GetSlot(i)
				local cachedItemId = slot:GetAttribute("CurrentItemId")
				local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

				-- Update if item ID changed
				if cachedItemId ~= actualItemId then
					-- Item changed (including nil -> item, item -> nil, or item A -> item B)
					local selectionBorder = slot:FindFirstChild("Selection")
					self:UpdateHotbarSlotDisplay(i, slot, iconContainer, countLabel, selectionBorder)
				elseif actualItemId and stack then
					-- Same item, just update count (cheap operation)
					if countLabel then
						countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
					end
					-- Also update selection border in case selection changed
					local selectionBorder = slot:FindFirstChild("Selection")
					if selectionBorder then
						if self.hotbar.selectedSlot == i then
							selectionBorder.Transparency = 0
						else
							selectionBorder.Transparency = 1
						end
					end
				end
			end
		end
	end

	-- Always update cursor
	self:UpdateCursorDisplay()
end

function VoxelInventoryPanel:UpdateCursorDisplay()
	if self.cursorStack:IsEmpty() then
		-- Clear attribute IMMEDIATELY to prevent race conditions
		self.cursorFrame:SetAttribute("CurrentItemId", nil)
		self.cursorFrame.Visible = false

		-- Clear visuals
		local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
		if iconContainer then
			for _, child in ipairs(iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
					child:Destroy()
				end
			end
		end
	else
		self.cursorFrame.Visible = true
		local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
		local countLabel = self.cursorFrame:FindFirstChild("CountLabel")

		if iconContainer then
			local itemId = self.cursorStack:GetItemId()
			local isTool = ToolConfig.IsTool(itemId)
			local currentItemId = self.cursorFrame:GetAttribute("CurrentItemId")  -- cursorFrame is an Instance

			-- Only recreate viewport/image if item type changed (performance optimization)
			if currentItemId ~= itemId then
				-- Clear attribute FIRST to prevent race conditions
				self.cursorFrame:SetAttribute("CurrentItemId", nil)

				-- Clear ALL existing visuals
				for _, child in ipairs(iconContainer:GetChildren()) do
					if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
						child:Destroy()
					end
				end

				if isTool then
					local info = ToolConfig.GetToolInfo(itemId)
					local image = Instance.new("ImageLabel")
					image.Name = "ToolImage"
					image.Size = UDim2.new(1, -6, 1, -6)
					image.Position = UDim2.new(0.5, 0, 0.5, 0)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundTransparency = 1
					image.Image = info and info.image or ""
					image.ScaleType = Enum.ScaleType.Fit
					image.ZIndex = 1001
					image.Parent = iconContainer
				else
					BlockViewportCreator.CreateBlockViewport(
						iconContainer,
						itemId,
						UDim2.new(1, 0, 1, 0)
					)
				end

				-- Set new item ID AFTER creating visuals
				self.cursorFrame:SetAttribute("CurrentItemId", itemId)  -- cursorFrame is an Instance
			end
		end

		-- Always update count (cheap operation)
		if countLabel then
			countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		end
	end

	-- Notify crafting panel of cursor change
	if self.craftingPanel then
		self.craftingPanel:OnCursorChanged()
	end
end

function VoxelInventoryPanel:IsCursorHoldingItem()
	return not self.cursorStack:IsEmpty()
end

-- Minecraft mechanics: Left click on inventory slot
function VoxelInventoryPanel:OnInventorySlotLeftClick(index)
	local slotStack = self.inventoryManager:GetInventorySlot(index)

	if self.cursorStack:IsEmpty() then
		-- No item on cursor: Pick up entire stack
		if not slotStack:IsEmpty() then
			self.cursorStack = slotStack:Clone()
			self.inventoryManager:SetInventorySlot(index, ItemStack.new(0, 0))
		end
	else
		-- Have item on cursor
		if slotStack:IsEmpty() then
			-- Empty slot: Place entire stack
			self.inventoryManager:SetInventorySlot(index, self.cursorStack:Clone())
			self.cursorStack = ItemStack.new(0, 0)
		elseif self.cursorStack:CanStack(slotStack) then
			-- Same item: Merge stacks
			slotStack:Merge(self.cursorStack)
			self.inventoryManager:SetInventorySlot(index, slotStack)
			if self.cursorStack:IsEmpty() then
				self.cursorStack = ItemStack.new(0, 0)
			end
		else
			-- Different item: Swap
			local temp = slotStack:Clone()
			self.inventoryManager:SetInventorySlot(index, self.cursorStack:Clone())
			self.cursorStack = temp
		end
	end

	-- Update cursor immediately; slot visuals refresh via manager events
	self:UpdateCursorDisplay()

	-- Ensure clicked slot redraws immediately (avoid relying solely on async events)
	self:UpdateInventorySlotDisplay(index)
	-- Only send to server when action is complete (cursor not holding mid-transaction)
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

-- Minecraft mechanics: Right click on inventory slot
function VoxelInventoryPanel:OnInventorySlotRightClick(index)
	local slotStack = self.inventoryManager:GetInventorySlot(index)

	if self.cursorStack:IsEmpty() then
		-- No item on cursor: Pick up half the stack
		if not slotStack:IsEmpty() then
			self.cursorStack = slotStack:SplitHalf()
			self.inventoryManager:SetInventorySlot(index, slotStack)
		end
	else
		-- Have item on cursor
		if slotStack:IsEmpty() then
			-- Empty slot: Place one item
			local oneItem = self.cursorStack:TakeOne()
			self.inventoryManager:SetInventorySlot(index, oneItem)
		elseif self.cursorStack:CanStack(slotStack) and not slotStack:IsFull() then
			-- Same item with space: Add one
			slotStack:AddCount(1)
			self.cursorStack:RemoveCount(1)
			self.inventoryManager:SetInventorySlot(index, slotStack)
			if self.cursorStack:IsEmpty() then
				self.cursorStack = ItemStack.new(0, 0)
			end
		end
		-- Different item: Do nothing (Minecraft behavior)
	end

	-- Update cursor immediately; slot visuals refresh via manager events
	self:UpdateCursorDisplay()

	-- Ensure clicked slot redraws immediately
	self:UpdateInventorySlotDisplay(index)
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

-- Hotbar slot clicks (similar logic but updates hotbar)
function VoxelInventoryPanel:OnHotbarSlotLeftClick(index)
	if not self.hotbar then return end

	local slotStack = self.inventoryManager:GetHotbarSlot(index)

	if self.cursorStack:IsEmpty() then
		if not slotStack:IsEmpty() then
			self.cursorStack = slotStack:Clone()
			self.inventoryManager:SetHotbarSlot(index, ItemStack.new(0, 0))
		end
	else
		if slotStack:IsEmpty() then
			self.inventoryManager:SetHotbarSlot(index, self.cursorStack:Clone())
			self.cursorStack = ItemStack.new(0, 0)
		elseif self.cursorStack:CanStack(slotStack) then
			slotStack:Merge(self.cursorStack)
			self.inventoryManager:SetHotbarSlot(index, slotStack)
			if self.cursorStack:IsEmpty() then
				self.cursorStack = ItemStack.new(0, 0)
			end
		else
			local temp = slotStack:Clone()
			self.inventoryManager:SetHotbarSlot(index, self.cursorStack:Clone())
			self.cursorStack = temp
		end
	end

	-- Update cursor immediately; slot visuals refresh via manager events
	self:UpdateCursorDisplay()

	-- Ensure clicked hotbar slot redraws immediately
	local slotNameL = "HotbarSlot" .. index
	local slotL = self.panel and self.panel:FindFirstChild(slotNameL)
	if slotL then
		local iconContainer = slotL:FindFirstChild("IconContainer")
		local countLabel = slotL:FindFirstChild("CountLabel")
		local selectionBorder = slotL:FindFirstChild("Selection")
		self:UpdateHotbarSlotDisplay(index, slotL, iconContainer, countLabel, selectionBorder)
	end
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

function VoxelInventoryPanel:OnHotbarSlotRightClick(index)
	if not self.hotbar then return end

	local slotStack = self.inventoryManager:GetHotbarSlot(index)

	if self.cursorStack:IsEmpty() then
		if not slotStack:IsEmpty() then
			self.cursorStack = slotStack:SplitHalf()
			self.inventoryManager:SetHotbarSlot(index, slotStack)
		end
	else
		if slotStack:IsEmpty() then
			local oneItem = self.cursorStack:TakeOne()
			self.inventoryManager:SetHotbarSlot(index, oneItem)
		elseif self.cursorStack:CanStack(slotStack) and not slotStack:IsFull() then
			slotStack:AddCount(1)
			self.cursorStack:RemoveCount(1)
			self.inventoryManager:SetHotbarSlot(index, slotStack)
			if self.cursorStack:IsEmpty() then
				self.cursorStack = ItemStack.new(0, 0)
			end
		end
	end

	-- Update cursor immediately; slot visuals refresh via manager events
	self:UpdateCursorDisplay()

	-- Ensure clicked hotbar slot redraws immediately
	local slotNameR = "HotbarSlot" .. index
	local slotR = self.panel and self.panel:FindFirstChild(slotNameR)
	if slotR then
		local iconContainer = slotR:FindFirstChild("IconContainer")
		local countLabel = slotR:FindFirstChild("CountLabel")
		local selectionBorder = slotR:FindFirstChild("Selection")
		self:UpdateHotbarSlotDisplay(index, slotR, iconContainer, countLabel, selectionBorder)
	end
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

--- Equipment slot clicks (placeholder for future equipment system)
function VoxelInventoryPanel:OnEquipmentSlotLeftClick(index, equipmentType)
	-- TODO: Implement equipment system
	-- For now, equipment slots don't interact with items
	print(string.format("Equipment slot clicked: %s (index %d)", equipmentType, index))
end

function VoxelInventoryPanel:OnEquipmentSlotRightClick(index, equipmentType)
	-- TODO: Implement equipment system
	-- For now, equipment slots don't interact with items
	print(string.format("Equipment slot right-clicked: %s (index %d)", equipmentType, index))
end

-- Send inventory update to server (deprecated - use inventoryManager)
function VoxelInventoryPanel:SendInventoryUpdateToServer()
	-- Delegate to inventory manager
	self.inventoryManager:SendUpdateToServer()
end

function VoxelInventoryPanel:UpdateCursorPosition()
	if not self.cursorFrame.Visible then return end

	local mousePos = UserInputService:GetMouseLocation()

	-- Cursor ScreenGui has IgnoreGuiInset=true, so use raw mouse position
	-- AnchorPoint of 0.5,0.5 centers the cursor frame on this position
	self.cursorFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
end

function VoxelInventoryPanel:BindInput()
	-- Only handle Escape here; E is handled centrally in GameClient to avoid conflicts
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:Close()
		end
	end)

	-- Drop item when clicking outside inventory
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
		if not self.isOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		-- Check if clicked outside inventory panel
		local mouse = Players.LocalPlayer:GetMouse()
		local panelPos = self.panel.AbsolutePosition
		local panelSize = self.panel.AbsoluteSize

		local isOutside = mouse.X < panelPos.X or mouse.X > (panelPos.X + panelSize.X) or
		                  mouse.Y < panelPos.Y or mouse.Y > (panelPos.Y + panelSize.Y)

		if isOutside and not self.cursorStack:IsEmpty() then
			-- Spawn a world drop for the cursor item via server
			local itemId = self.cursorStack:GetItemId()
			local count = self.cursorStack:GetCount()
			pcall(function()
				EventManager:SendToServer("RequestDropItem", {
					itemId = itemId,
					count = count,
					fromCursor = false -- Server will remove from inventory authoritative
				})
			end)
			-- Clear cursor locally
			self.cursorStack = ItemStack.new(0, 0)
			self:UpdateCursorDisplay()
		end
	end)
end

function VoxelInventoryPanel:Open()
	if self.isOpen then return end

	self.isOpen = true
	self.gui.Enabled = true

	-- Reset crafting UI state on open so overview shows first
	if self.craftingPanel and self.craftingPanel.OnPanelOpen then
		pcall(function()
			self.craftingPanel:OnPanelOpen()
		end)
	end

	-- Close chest UI if open (mutual exclusion)
	if self.chestUI and self.chestUI.isOpen then
		self.chestUI:Close()
	end

	-- Update all displays
	self:UpdateAllDisplays()

	-- Signal to character controller to stop locking mouse
	GameState:Set("voxelWorld.inventoryOpen", true)

	-- Unlock mouse - force it!
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	-- Force mouse visible again on next frame (in case something overrides it)
	task.defer(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	-- Start updating cursor position and keep mouse unlocked
	self.renderConnection = RunService.RenderStepped:Connect(function()
		-- Keep forcing mouse to be visible and unlocked while inventory is open
		if self.isOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		self:UpdateCursorPosition()
	end)

	-- Animate in
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 50)
	self.panel.Size = UDim2.new(0, self.panel.Size.X.Offset * 0.9, 0, self.panel.Size.Y.Offset * 0.9)

	TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
		Size = UDim2.new(0, self.panel.Size.X.Offset / 0.9, 0, self.panel.Size.Y.Offset / 0.9)
	}):Play()
end

function VoxelInventoryPanel:Close()
	if not self.isOpen then return end

	-- If holding an item, put it back somewhere or drop it
	if not self.cursorStack:IsEmpty() then
		-- Try to find empty slot in inventory
		local placed = false
		for i = 1, 27 do
			if self.inventoryManager:GetInventorySlot(i):IsEmpty() then
				self.inventoryManager:SetInventorySlot(i, self.cursorStack:Clone())
				placed = true
				break
			end
		end

		if not placed then
			-- Inventory full: drop the cursor item into the world
			local itemId = self.cursorStack:GetItemId()
			local count = self.cursorStack:GetCount()
			pcall(function()
				EventManager:SendToServer("RequestDropItem", {
					itemId = itemId,
					count = count,
					fromCursor = false -- Server will remove authoritative
				})
			end)
		end

		self.cursorStack = ItemStack.new(0, 0)
		self:UpdateCursorDisplay()

		-- Sync to server only if we placed the item back into an empty slot.
		-- For drops, the server will remove and granularly sync changed slots.
		if placed then
			self.inventoryManager:SendUpdateToServer()
		end
	end

	self.isOpen = false


	-- Stop updating cursor
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Signal to character controller to resume mouse locking
	GameState:Set("voxelWorld.inventoryOpen", false)

	-- Note: CameraController now manages mouse lock dynamically based on camera mode
	-- (first person = locked, third person = free)

	-- Animate out
	local tween = TweenService:Create(self.panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 30)
	})
	tween:Play()
	tween.Completed:Connect(function()
		self.gui.Enabled = false

		-- Reset workbench mode after UI is hidden to avoid visible title flicker
		if self.isWorkbenchMode then
			self:SetWorkbenchMode(false)
		end
	end)
end

function VoxelInventoryPanel:Toggle()
	if self.isOpen then
		self:Close()
	else
		self:Open()
	end
end

function VoxelInventoryPanel:IsOpen()
	return self.isOpen
end

-- Enable or disable Workbench mode (filters crafting recipes)
function VoxelInventoryPanel:SetWorkbenchMode(enabled)
	self.isWorkbenchMode = enabled and true or false
	if self.craftingPanel and self.craftingPanel.SetMode then
		self.craftingPanel:SetMode(self.isWorkbenchMode and "workbench" or "inventory")
	end

	-- Update title text
	if self.titleLabel then
		if self.isWorkbenchMode then
			self.titleLabel.Text = "Workbench"
		else
			self.titleLabel.Text = "Inventory"
		end
	end

end

function VoxelInventoryPanel:Cleanup()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	if self.renderConnection then
		self.renderConnection:Disconnect()
	end

	if self.gui then
		self.gui:Destroy()
	end
end

return VoxelInventoryPanel
