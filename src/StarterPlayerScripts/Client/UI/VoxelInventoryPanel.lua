--[[
	VoxelInventoryPanel.lua
	Minecraft-style inventory panel with tabbed navigation

	Layout: Single-column with horizontal tabs (Inventory, Crafting)
	- Inventory tab: Armor slots + viewmodel, 3x9 grid, 1x9 hotbar
	- Crafting tab: Recipe grid with detail panel

	Mechanics:
	- Left Click: Pick up/place entire stack, or swap stacks
	- Right Click: Pick up half stack / Place one item
	- Shift+Click: Quick transfer between inventory and hotbar
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local InputService = require(script.Parent.Parent.Input.InputService)
local GameState = require(script.Parent.Parent.Managers.GameState)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local ViewportPreview = require(script.Parent.Parent.Managers.ViewportPreview)
local UIScaler = require(script.Parent.Parent.Managers.UIScaler)
local CharacterRigBuilder = require(script.Parent.CharacterRigBuilder)
local HeldItemRenderer = require(ReplicatedStorage.Shared.HeldItemRenderer)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)

-- Load custom font
local _ = require(ReplicatedStorage.Fonts["Upheaval BRK"])

local VoxelInventoryPanel = {}
VoxelInventoryPanel.__index = VoxelInventoryPanel

-- Constants
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold
local CUSTOM_FONT_NAME = "Upheaval BRK"
local HEADING_SIZE = 54
local MIN_TEXT_SIZE = 16

-- Layout configuration (matching Furnace/Smithing UI patterns)
-- Calculations:
--   Slot size = 50px (border drawn inside)
--   Slot spacing = 6px
--   Grid width = 50*9 + 6*8 = 498px
--   Panel width = Grid width + CONTENT_PADDING*2 = 498 + 20 = 518px
local CONFIG = {
	-- Grid dimensions
	COLUMNS = 9,
	ROWS = 3,

	-- Panel dimensions
	PANEL_WIDTH = 564,
	HEADER_HEIGHT = 54,
	TAB_ROW_HEIGHT = 40,
	CONTENT_PADDING = 10,
	SECTION_SPACING = 6,
	SHADOW_HEIGHT = 10,

	-- Slot dimensions (border is drawn inside, so SLOT_SIZE is the full visual size)
	SLOT_SIZE = 56,
	SLOT_SPACING = 5,
	SLOT_CORNER_RADIUS = 4,
	SLOT_BORDER_THICKNESS = 2,

	-- Label dimensions
	LABEL_HEIGHT = 14,
	LABEL_SPACING = 4,

	-- Tab styling
	TAB_ICON_SIZE = 24,
	TAB_TEXT_SIZE = 16,
	TAB_PADDING = 12,
	TAB_SPACING = 6,

	-- Armor section
	ARMOR_VIEWMODEL_HEIGHT = 120,
	EQUIPMENT_SLOT_SIZE = 56,
	EQUIPMENT_SPACING = 5,

	-- Colors (consistent with other UIs)
	PANEL_BG = Color3.fromRGB(58, 58, 58),
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),
	BORDER_COLOR = Color3.fromRGB(77, 77, 77),
	SLOT_BG = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,
	SLOT_BORDER = Color3.fromRGB(35, 35, 35),
	SLOT_HOVER = Color3.fromRGB(80, 80, 80),
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),
	TAB_ACTIVE = Color3.fromRGB(255, 255, 255),
	TAB_INACTIVE = Color3.fromRGB(185, 185, 195),

	-- Background texture
	BG_IMAGE = "rbxassetid://82824299358542",
	BG_IMAGE_TRANSPARENCY = 0.6,
}

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

local function playInventoryPopSound()
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("inventoryPop")
	end
end

local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then return nil end

	local registryName = ItemRegistry.GetItemName(itemId)
	if registryName and registryName ~= "Unknown" then
		return registryName
	end

	if SpawnEggConfig.IsSpawnEgg(itemId) then
		local eggInfo = SpawnEggConfig.GetEggInfo(itemId)
		return eggInfo and eggInfo.name or "Spawn Egg"
	end

	local blockDef = BlockRegistry.Blocks[itemId]
	return blockDef and blockDef.name or "Item"
end

local function IsShiftHeld()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function VoxelInventoryPanel.new(inventoryManager)
	local self = setmetatable({}, VoxelInventoryPanel)

	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar
	self.isOpen = false
	self.isAnimating = false
	self.isWorkbenchMode = false
	self.overlayRelease = nil
	self.pendingCloseMode = "gameplay"
	self.hoverEnabled = false -- Controls whether hover effects are active

	-- UI references
	self.gui = nil
	self.panel = nil
	self.bodyFrame = nil
	self.titleLabel = nil
	self.hoverItemLabel = nil

	-- Tab state
	self.tabButtons = {}
	self.activeTab = "inventory"
	self.inventoryTabFrame = nil
	self.craftingTabFrame = nil

	-- Slot frames
	self.inventorySlotFrames = {}
	self.equipmentSlotFrames = {}
	self.hotbarSlotFrames = {}

	-- Armor viewmodel
	self.armorViewmodel = nil
	self.updateArmorViewmodel = nil

	-- Cursor state (Minecraft drag-and-drop)
	self.cursorStack = ItemStack.new(0, 0)
	self.cursorFrame = nil

	-- Equipped armor (synced from server)
	self.equippedArmor = {
		helmet = nil,
		chestplate = nil,
		leggings = nil,
		boots = nil
	}

	-- Event connections
	self.connections = {}
	self.renderConnection = nil

	return self
end

--------------------------------------------------------------------------------
-- Overlay Management
--------------------------------------------------------------------------------

function VoxelInventoryPanel:_acquireOverlay()
	if self.overlayRelease then return end

	local release = InputService:BeginOverlay("VoxelInventoryPanel", {
		showIcon = true,
	})

	if release then
		self.overlayRelease = release
	end
end

function VoxelInventoryPanel:_releaseOverlay()
	if not self.overlayRelease then return end

	local release = self.overlayRelease
	self.overlayRelease = nil
	release()
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function VoxelInventoryPanel:Initialize()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VoxelInventoryUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Add responsive scaling
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.75)
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create cursor GUI (always on top)
	-- NOTE: Cursor GUI does NOT have UIScale - mouse coordinates are absolute pixels
	self.cursorGui = Instance.new("ScreenGui")
	self.cursorGui.Name = "VoxelInventoryCursor"
	self.cursorGui.ResetOnSpawn = false
	self.cursorGui.DisplayOrder = 999
	self.cursorGui.IgnoreGuiInset = true  -- Cursor needs to ignore inset for proper positioning
	self.cursorGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Create hover item label
	self:CreateHoverItemLabel()

	-- Create main panel
	self:CreatePanel()

	-- Create cursor frame for dragging
	self:CreateCursorFrame()

	-- Setup input handling
	self:SetupInputHandling()

	-- Setup inventory sync
	self:SetupInventorySync()

	-- Setup armor event listeners
	self:SetupArmorEventListeners()

	-- Initial refresh
	self:RefreshAllSlots()

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("voxelInventory", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 100
	})
end

--------------------------------------------------------------------------------
-- Panel Creation
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreatePanel()
	-- Calculate dimensions (SLOT_SIZE is the full visual size, border drawn inside)
	local slotSize = CONFIG.SLOT_SIZE
	local inventoryGridHeight = slotSize * CONFIG.ROWS + CONFIG.SLOT_SPACING * (CONFIG.ROWS - 1)
	local hotbarHeight = slotSize

	-- Section heights (each section has label + spacing + content)
	local armorSectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + CONFIG.ARMOR_VIEWMODEL_HEIGHT
	local inventorySectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + inventoryGridHeight
	local hotbarSectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + hotbarHeight

	-- Body = padding + armor + spacing + inventory + spacing + hotbar + padding
	local bodyContentHeight = CONFIG.CONTENT_PADDING
		+ armorSectionHeight
		+ CONFIG.SECTION_SPACING
		+ inventorySectionHeight
		+ CONFIG.SECTION_SPACING
		+ hotbarSectionHeight
		+ CONFIG.CONTENT_PADDING

	local totalHeight = CONFIG.HEADER_HEIGHT + CONFIG.TAB_ROW_HEIGHT + bodyContentHeight + CONFIG.SHADOW_HEIGHT

	-- Store the original panel height for animations
	self.originalPanelHeight = totalHeight

	-- Main panel container
	self.panel = Instance.new("Frame")
	self.panel.Name = "InventoryPanel"
	self.panel.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundTransparency = 1
	self.panel.Parent = self.gui

	-- Header
	self:CreateHeader()

	-- Tab row
	self:CreateTabRow()

	-- Body (main content area)
	self:CreateBody(bodyContentHeight)

	-- Set default tab
	self:SetActiveTab("inventory")
end

function VoxelInventoryPanel:CreateHeader()
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, CONFIG.HEADER_HEIGHT)
	header.Position = UDim2.fromScale(0, 0)
	header.BackgroundTransparency = 1
	header.Parent = self.panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 1, 0)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.TextColor3 = CONFIG.TEXT_PRIMARY
	title.TextSize = HEADING_SIZE
	title.Font = Enum.Font.Code
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = header
	FontBinder.apply(title, CUSTOM_FONT_NAME)
	self.titleLabel = title

	-- Close button
	local closeIcon = IconManager:CreateIcon(header, "UI", "X", {
		size = UDim2.fromOffset(44, 44),
		position = UDim2.fromScale(1, 0.5),
		anchorPoint = Vector2.new(1, 0.5)
	})

	local closeBtn = Instance.new("ImageButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.fromOffset(44, 44)
	closeBtn.Position = UDim2.new(1, -2, 0.5, 0)
	closeBtn.AnchorPoint = Vector2.new(1, 0.5)
	closeBtn.BackgroundTransparency = 1
	if closeIcon then
		closeBtn.Image = closeIcon.Image
		closeBtn.ScaleType = closeIcon.ScaleType
		closeIcon:Destroy()
	end
	closeBtn.Parent = header

	local rotateInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, { Rotation = 90 }):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotateInfo, { Rotation = 0 }):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

function VoxelInventoryPanel:CreateTabRow()
	local tabRow = Instance.new("Frame")
	tabRow.Name = "TabRow"
	tabRow.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, CONFIG.TAB_ROW_HEIGHT)
	tabRow.Position = UDim2.fromOffset(0, CONFIG.HEADER_HEIGHT)
	tabRow.BackgroundTransparency = 1
	tabRow.Parent = self.panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, CONFIG.TAB_SPACING)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = tabRow

	-- Create tabs (Inventory first, Crafting second)
	self:CreateTab(tabRow, "inventory", 1, "Clothing", "Backpack", "Inventory")
	self:CreateTab(tabRow, "crafting", 2, "Tools", "Hammer", "Crafting")
end

function VoxelInventoryPanel:CreateTab(parent, tabId, order, iconCategory, iconName, labelText)
	local tab = Instance.new("TextButton")
	tab.Name = tabId .. "Tab"
	tab.LayoutOrder = order
	tab.Size = UDim2.fromOffset(110, CONFIG.TAB_ROW_HEIGHT - 4)
	tab.BackgroundTransparency = 1
	tab.Text = ""
	tab.AutoButtonColor = false
	tab.Parent = parent

	-- Content layout
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = tab

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.Padding = UDim.new(0, CONFIG.TAB_SPACING)
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.Parent = content

	-- Icon
	local icon = IconManager:CreateIcon(content, iconCategory, iconName, {
		size = UDim2.fromOffset(CONFIG.TAB_ICON_SIZE, CONFIG.TAB_ICON_SIZE)
	})
	local isImageIcon = icon and icon:IsA("ImageLabel")
	if icon then
		icon.Name = "Icon"
		icon.LayoutOrder = 1
		if isImageIcon then
			icon.ImageColor3 = CONFIG.TAB_INACTIVE
		end
	end

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.LayoutOrder = 2
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = CONFIG.TAB_INACTIVE
	label.TextSize = CONFIG.TAB_TEXT_SIZE
	label.Font = Enum.Font.GothamBold
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Parent = content

	-- Active indicator
	local indicator = Instance.new("Frame")
	indicator.Name = "Indicator"
	indicator.Size = UDim2.new(1, 0, 0, 4)
	indicator.Position = UDim2.new(0, 0, 1, -4)
	indicator.BackgroundColor3 = CONFIG.TEXT_PRIMARY
	indicator.BackgroundTransparency = 1
	indicator.BorderSizePixel = 0
	indicator.Parent = tab

	-- Store reference
	self.tabButtons[tabId] = {
		button = tab,
		icon = icon,
		label = label,
		indicator = indicator,
		isImageIcon = isImageIcon
	}

	-- Click handler
	tab.MouseButton1Click:Connect(function()
		self:SetActiveTab(tabId)
	end)

	-- Hover effects
	tab.MouseEnter:Connect(function()
		if self.activeTab ~= tabId then
			if isImageIcon and icon then icon.ImageColor3 = Color3.fromRGB(220, 220, 220) end
			label.TextColor3 = Color3.fromRGB(220, 220, 220)
		end
	end)

	tab.MouseLeave:Connect(function()
		if self.activeTab ~= tabId then
			if isImageIcon and icon then icon.ImageColor3 = CONFIG.TAB_INACTIVE end
			label.TextColor3 = CONFIG.TAB_INACTIVE
		end
	end)
end

function VoxelInventoryPanel:CreateBody(contentHeight)
	local bodyY = CONFIG.HEADER_HEIGHT + CONFIG.TAB_ROW_HEIGHT

	-- Body container (holds panel + shadow)
	local bodyContainer = Instance.new("Frame")
	bodyContainer.Name = "BodyContainer"
	bodyContainer.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, contentHeight + CONFIG.SHADOW_HEIGHT)
	bodyContainer.Position = UDim2.fromOffset(0, bodyY)
	bodyContainer.BackgroundTransparency = 1
	bodyContainer.Parent = self.panel

	-- Shadow (behind body, at bottom)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, CONFIG.SHADOW_HEIGHT + 4)
	shadow.Position = UDim2.fromOffset(0, contentHeight - 4)
	shadow.BackgroundColor3 = CONFIG.SHADOW_COLOR
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = bodyContainer

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	-- Body frame with background (on top of shadow)
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, contentHeight)
	body.Position = UDim2.fromOffset(0, 0)
	body.BackgroundColor3 = CONFIG.PANEL_BG
	body.BorderSizePixel = 0
	body.ZIndex = 1
	body.Parent = bodyContainer
	self.bodyFrame = body

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = body

	local border = Instance.new("UIStroke")
	border.Color = CONFIG.BORDER_COLOR
	border.Thickness = 3
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = body

	-- Content area (positioned with padding offset, sized to fit content)
	local contentWidth = CONFIG.PANEL_WIDTH - CONFIG.CONTENT_PADDING * 2
	local contentInnerHeight = contentHeight - CONFIG.CONTENT_PADDING * 2

	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.fromOffset(contentWidth, contentInnerHeight)
	contentArea.Position = UDim2.fromOffset(CONFIG.CONTENT_PADDING, CONFIG.CONTENT_PADDING)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = body

	-- Create tab content
	self:CreateInventoryTab(contentArea)
	self:CreateCraftingTab(contentArea)
end

--------------------------------------------------------------------------------
-- Inventory Tab
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreateInventoryTab(parent)
	local tab = Instance.new("Frame")
	tab.Name = "InventoryTab"
	tab.Size = UDim2.fromScale(1, 1)
	tab.BackgroundTransparency = 1
	tab.Parent = parent
	self.inventoryTabFrame = tab

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, CONFIG.SECTION_SPACING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = tab

	-- Armor section
	self:CreateArmorSection(tab)

	-- Inventory grid section
	self:CreateInventorySection(tab)

	-- Hotbar section
	self:CreateHotbarSection(tab)
end

function VoxelInventoryPanel:CreateArmorSection(parent)
	local slotSize = CONFIG.EQUIPMENT_SLOT_SIZE
	local sectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + CONFIG.ARMOR_VIEWMODEL_HEIGHT

	local section = Instance.new("Frame")
	section.Name = "ArmorSection"
	section.LayoutOrder = 1
	section.Size = UDim2.new(1, 0, 0, sectionHeight)
	section.BackgroundTransparency = 1
	section.Parent = parent

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, CONFIG.LABEL_HEIGHT)
	label.BackgroundTransparency = 1
	label.Text = "ARMOR"
	label.TextColor3 = CONFIG.TEXT_MUTED
	label.TextSize = 11
	label.Font = BOLD_FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section

	-- Content Y offset (after label)
	local contentY = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING

	-- Calculate layout (section width = PANEL_WIDTH - CONTENT_PADDING*2 = 450px)
	local armorSlotsWidth = slotSize * 4 + CONFIG.EQUIPMENT_SPACING * 3
	local viewmodelSize = CONFIG.ARMOR_VIEWMODEL_HEIGHT -- Square viewmodel
	local gap = 8
	local totalWidth = viewmodelSize + gap + armorSlotsWidth
	local sectionWidth = CONFIG.PANEL_WIDTH - CONFIG.CONTENT_PADDING * 2
	local startX = (sectionWidth - totalWidth) / 2

	-- Viewmodel container (square aspect ratio for better character display)
	local viewmodelContainer = Instance.new("Frame")
	viewmodelContainer.Name = "Viewmodel"
	viewmodelContainer.Size = UDim2.fromOffset(viewmodelSize, viewmodelSize)
	viewmodelContainer.Position = UDim2.fromOffset(startX, contentY)
	viewmodelContainer.BackgroundColor3 = CONFIG.SLOT_BG
	viewmodelContainer.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	viewmodelContainer.Parent = section

	local vmCorner = Instance.new("UICorner")
	vmCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	vmCorner.Parent = viewmodelContainer

	local vmBorder = Instance.new("UIStroke")
	vmBorder.Color = CONFIG.SLOT_BORDER
	vmBorder.Thickness = CONFIG.SLOT_BORDER_THICKNESS
	vmBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	vmBorder.Parent = viewmodelContainer

	-- Background image
	local bgImage = Instance.new("ImageLabel")
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CONFIG.BG_IMAGE
	bgImage.ImageTransparency = CONFIG.BG_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 0
	bgImage.Parent = viewmodelContainer

	-- Create viewport preview
	self:CreateArmorViewmodel(viewmodelContainer)

	-- Armor slots container
	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "ArmorSlots"
	slotsContainer.Size = UDim2.fromOffset(armorSlotsWidth, slotSize)
	slotsContainer.Position = UDim2.fromOffset(startX + viewmodelSize + gap, contentY + (CONFIG.ARMOR_VIEWMODEL_HEIGHT - slotSize) / 2)
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.Parent = section

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Horizontal
	slotsLayout.Padding = UDim.new(0, CONFIG.EQUIPMENT_SPACING)
	slotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	slotsLayout.Parent = slotsContainer

	-- Create armor slots
	local equipmentTypes = {"Head", "Chest", "Leggings", "Boots"}
	for i, equipType in ipairs(equipmentTypes) do
		self:CreateEquipmentSlot(i, equipType, slotsContainer)
	end
end

function VoxelInventoryPanel:CreateArmorViewmodel(container)
	local player = Players.LocalPlayer

	self.armorViewmodel = ViewportPreview.new({
		parent = container,
		name = "ArmorViewmodel",
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0, 0),
		backgroundColor = CONFIG.SLOT_BG,
		backgroundTransparency = 1,
		borderRadius = 2,
		rotationSpeed = 20,
		paddingScale = 1.4,
		cameraPitch = math.rad(10),
	})

	self.updateArmorViewmodel = function()
		if not self.armorViewmodel or not self.armorViewmodel._world then return end

		local rig = CharacterRigBuilder.BuildCharacterRig(player)
		if not rig then return end

		if not self.armorViewmodel or not self.armorViewmodel._world then
			rig:Destroy()
			return
		end

		self:ClearArmorHeldItem()
		self.armorViewmodel:SetModel(rig)

		local model = self.armorViewmodel._model
		if model then
			local rootPart = model:FindFirstChild("HumanoidRootPart")
			if rootPart then
				model.PrimaryPart = rootPart

				-- Remove accessories
				for _, child in ipairs(model:GetChildren()) do
					if child:IsA("Accessory") then child:Destroy() end
				end

				CharacterRigBuilder.ApplyMinecraftScale(model)
				CharacterRigBuilder.ApplyIdlePose(model)
				CharacterRigBuilder.ApplyArmorVisuals(model, self.equippedArmor)

				self.armorViewmodel:_refit()
				self:RefreshArmorHeldItem()
			end
		end

		self.armorViewmodel:SetMouseTracking(true)
	end

	task.spawn(self.updateArmorViewmodel)

	-- Refresh on character respawn
	local conn = player.CharacterAdded:Connect(function()
		task.spawn(self.updateArmorViewmodel)
	end)
	table.insert(self.connections, conn)

	-- Setup held item listeners
	self:SetupArmorViewmodelListeners()
end

function VoxelInventoryPanel:SetupArmorViewmodelListeners()
	local listeners = {
		GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", function() self:RefreshArmorHeldItem() end),
		GameState:OnPropertyChanged("voxelWorld.isHoldingTool", function() self:RefreshArmorHeldItem() end),
		GameState:OnPropertyChanged("voxelWorld.selectedBlock", function() self:RefreshArmorHeldItem() end),
		GameState:OnPropertyChanged("voxelWorld.isHoldingItem", function() self:RefreshArmorHeldItem() end),
	}

	for _, disconnect in ipairs(listeners) do
		if disconnect then
			table.insert(self.connections, { Disconnect = disconnect })
		end
	end

	-- Scale listener
	local scaleDisconnect = UIScaler:RegisterScaleListener(function()
		if self.armorViewmodel and self.armorViewmodel._refit then
			self.armorViewmodel:_refit()
		end
	end)
	if scaleDisconnect then
		table.insert(self.connections, { Disconnect = scaleDisconnect })
	end
end

function VoxelInventoryPanel:CreateInventorySection(parent)
	local slotSize = CONFIG.SLOT_SIZE
	local inventoryGridHeight = slotSize * CONFIG.ROWS + CONFIG.SLOT_SPACING * (CONFIG.ROWS - 1)
	local sectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + inventoryGridHeight

	local section = Instance.new("Frame")
	section.Name = "InventorySection"
	section.LayoutOrder = 2
	section.Size = UDim2.new(1, 0, 0, sectionHeight)
	section.BackgroundTransparency = 1
	section.Parent = parent

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, CONFIG.LABEL_HEIGHT)
	label.BackgroundTransparency = 1
	label.Text = "INVENTORY"
	label.TextColor3 = CONFIG.TEXT_MUTED
	label.TextSize = 11
	label.Font = BOLD_FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section

	-- Content Y offset (after label)
	local contentY = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING

	-- Grid container (centered)
	local gridWidth = slotSize * CONFIG.COLUMNS + CONFIG.SLOT_SPACING * (CONFIG.COLUMNS - 1)

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.fromOffset(gridWidth, inventoryGridHeight)
	grid.Position = UDim2.new(0.5, -gridWidth/2, 0, contentY)
	grid.BackgroundTransparency = 1
	grid.Parent = section

	-- Create inventory slots (3x9 grid)
	for row = 0, CONFIG.ROWS - 1 do
		for col = 0, CONFIG.COLUMNS - 1 do
			local index = row * CONFIG.COLUMNS + col + 1
			local x = col * (slotSize + CONFIG.SLOT_SPACING)
			local y = row * (slotSize + CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, grid, x, y)
		end
	end
end

function VoxelInventoryPanel:CreateHotbarSection(parent)
	local slotSize = CONFIG.SLOT_SIZE
	local hotbarHeight = slotSize
	local sectionHeight = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING + hotbarHeight

	local section = Instance.new("Frame")
	section.Name = "HotbarSection"
	section.LayoutOrder = 3
	section.Size = UDim2.new(1, 0, 0, sectionHeight)
	section.BackgroundTransparency = 1
	section.Parent = parent

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 0, CONFIG.LABEL_HEIGHT)
	label.BackgroundTransparency = 1
	label.Text = "HOTBAR"
	label.TextColor3 = CONFIG.TEXT_MUTED
	label.TextSize = 11
	label.Font = BOLD_FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = section

	-- Content Y offset (after label)
	local contentY = CONFIG.LABEL_HEIGHT + CONFIG.LABEL_SPACING

	-- Hotbar container (centered)
	local gridWidth = slotSize * CONFIG.COLUMNS + CONFIG.SLOT_SPACING * (CONFIG.COLUMNS - 1)

	local hotbar = Instance.new("Frame")
	hotbar.Name = "Hotbar"
	hotbar.Size = UDim2.fromOffset(gridWidth, hotbarHeight)
	hotbar.Position = UDim2.new(0.5, -gridWidth/2, 0, contentY)
	hotbar.BackgroundTransparency = 1
	hotbar.Parent = section

	-- Create hotbar slots (1x9)
	for col = 0, CONFIG.COLUMNS - 1 do
		local x = col * (slotSize + CONFIG.SLOT_SPACING)
		self:CreateHotbarSlot(col + 1, hotbar, x, 0)
	end
end

--------------------------------------------------------------------------------
-- Crafting Tab
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreateCraftingTab(parent)
	local tab = Instance.new("Frame")
	tab.Name = "CraftingTab"
	tab.Size = UDim2.fromScale(1, 1)
	tab.BackgroundTransparency = 1
	tab.Visible = false
	tab.Parent = parent
	self.craftingTabFrame = tab

	-- Initialize CraftingPanel
	local CraftingPanel = require(script.Parent.CraftingPanel)
	self.craftingPanel = CraftingPanel.new(self.inventoryManager, self, tab)
	self.craftingPanel:Initialize()
end

--------------------------------------------------------------------------------
-- Tab Switching
--------------------------------------------------------------------------------

function VoxelInventoryPanel:SetActiveTab(tabId)
	self.activeTab = tabId

	-- Update tab visuals
	for id, tabData in pairs(self.tabButtons) do
		local isActive = id == tabId
		local color = isActive and CONFIG.TAB_ACTIVE or CONFIG.TAB_INACTIVE

		if tabData.isImageIcon and tabData.icon then
			tabData.icon.ImageColor3 = color
		end
		tabData.label.TextColor3 = color
		tabData.indicator.BackgroundTransparency = isActive and 0 or 1
	end

	-- Show/hide content
	if self.inventoryTabFrame then
		self.inventoryTabFrame.Visible = tabId == "inventory"
	end
	if self.craftingTabFrame then
		self.craftingTabFrame.Visible = tabId == "crafting"
	end
end

-- Legacy compatibility
function VoxelInventoryPanel:SetActiveSection(section)
	local mapping = { craft = "crafting", armor = "inventory" }
	self:SetActiveTab(mapping[section] or section)
end

--------------------------------------------------------------------------------
-- Slot Creation
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreateSlotBase(name, parent, x, y)
	-- Use the full slot size (SLOT_SIZE already represents the clickable area)
	local slot = Instance.new("TextButton")
	slot.Name = name
	slot.Size = UDim2.fromOffset(CONFIG.SLOT_SIZE, CONFIG.SLOT_SIZE)
	slot.Position = UDim2.fromOffset(x, y)
	slot.BackgroundColor3 = CONFIG.SLOT_BG
	slot.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot

	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BgImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CONFIG.BG_IMAGE
	bgImage.ImageTransparency = CONFIG.BG_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border stroke (draws inside the element)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = CONFIG.SLOT_BORDER
	border.Thickness = CONFIG.SLOT_BORDER_THICKNESS
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = CONFIG.TEXT_PRIMARY
	hoverBorder.Thickness = CONFIG.SLOT_BORDER_THICKNESS
	hoverBorder.Transparency = 1
	hoverBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
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
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = MIN_TEXT_SIZE
	countLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5
	countLabel.Parent = slot

	return {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		border = border,
		hoverBorder = hoverBorder,
		viewport = nil
	}
end

function VoxelInventoryPanel:CreateInventorySlot(index, parent, x, y)
	local slotData = self:CreateSlotBase("InventorySlot" .. index, parent, x, y)
	self.inventorySlotFrames[index] = slotData

	-- Hover effects
	slotData.frame.MouseEnter:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 0
		local stack = self.inventoryManager:GetInventorySlot(index)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)

	slotData.frame.MouseLeave:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 1
		self:HideHoverItemName()
	end)

	-- Click handlers
	slotData.frame.MouseButton1Click:Connect(function()
		self:HandleInventorySlotClick(index, false)
	end)

	slotData.frame.MouseButton2Click:Connect(function()
		self:HandleInventorySlotClick(index, true)
	end)
end

function VoxelInventoryPanel:CreateHotbarSlot(index, parent, x, y)
	local slotData = self:CreateSlotBase("HotbarSlot" .. index, parent, x, y)
	self.hotbarSlotFrames[index] = slotData

	-- Selection indicator
	local selectIndicator = Instance.new("Frame")
	selectIndicator.Name = "SelectIndicator"
	selectIndicator.Size = UDim2.new(1, 4, 1, 4)
	selectIndicator.Position = UDim2.new(0.5, 0, 0.5, 0)
	selectIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
	selectIndicator.BackgroundTransparency = 1
	selectIndicator.BorderSizePixel = 0
	selectIndicator.ZIndex = 0
	selectIndicator.Parent = slotData.frame

	local selectBorder = Instance.new("UIStroke")
	selectBorder.Name = "SelectBorder"
	selectBorder.Color = CONFIG.TEXT_PRIMARY
	selectBorder.Thickness = 3
	selectBorder.Transparency = 1
	selectBorder.Parent = selectIndicator

	local selectCorner = Instance.new("UICorner")
	selectCorner.CornerRadius = UDim.new(0, 6)
	selectCorner.Parent = selectIndicator

	slotData.selectIndicator = selectIndicator
	slotData.selectBorder = selectBorder

	-- Hover effects
	slotData.frame.MouseEnter:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 0
		local stack = self.hotbar:GetSlot(index)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)

	slotData.frame.MouseLeave:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 1
		self:HideHoverItemName()
	end)

	-- Click handlers
	slotData.frame.MouseButton1Click:Connect(function()
		self:HandleHotbarSlotClick(index, false)
	end)

	slotData.frame.MouseButton2Click:Connect(function()
		self:HandleHotbarSlotClick(index, true)
	end)
end

function VoxelInventoryPanel:CreateEquipmentSlot(index, equipType, parent)
	local slotData = self:CreateSlotBase(equipType .. "Slot", parent, 0, 0)
	slotData.frame.LayoutOrder = index
	slotData.equipType = equipType
	self.equipmentSlotFrames[equipType] = slotData

	-- Placeholder icon
	local placeholderIcon = self:GetEquipmentPlaceholderIcon(equipType)
	if placeholderIcon then
		local placeholder = Instance.new("ImageLabel")
		placeholder.Name = "Placeholder"
		placeholder.Size = UDim2.fromScale(0.6, 0.6)
		placeholder.Position = UDim2.fromScale(0.5, 0.5)
		placeholder.AnchorPoint = Vector2.new(0.5, 0.5)
		placeholder.BackgroundTransparency = 1
		placeholder.Image = placeholderIcon
		placeholder.ImageColor3 = Color3.fromRGB(80, 80, 80)
		placeholder.ImageTransparency = 0.5
		placeholder.ZIndex = 2
		placeholder.Parent = slotData.frame
		slotData.placeholder = placeholder
	end

	-- Hover effects
	slotData.frame.MouseEnter:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 0
		local itemId = self.equippedArmor[string.lower(equipType == "Head" and "helmet" or equipType == "Chest" and "chestplate" or equipType == "Leggings" and "leggings" or "boots")]
		if itemId then
			self:ShowHoverItemName(itemId)
		end
	end)

	slotData.frame.MouseLeave:Connect(function()
		if not self.hoverEnabled then return end
		slotData.hoverBorder.Transparency = 1
		self:HideHoverItemName()
	end)

	-- Click handler
	slotData.frame.MouseButton1Click:Connect(function()
		self:HandleEquipmentSlotClick(equipType)
	end)
end

function VoxelInventoryPanel:GetEquipmentPlaceholderIcon(equipType)
	local iconMap = {
		Head = "Helmet",
		Chest = "Chestplate",
		Leggings = "Leggings",
		Boots = "Boots"
	}
	local iconName = iconMap[equipType]
	if iconName then
		local icon = IconManager:CreateIcon(nil, "Clothing", iconName, {})
		if icon then
			local imageId = icon.Image
			icon:Destroy()
			return imageId
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Slot Click Handlers
--------------------------------------------------------------------------------

function VoxelInventoryPanel:HandleInventorySlotClick(index, isRightClick)
	if IsShiftHeld() and not isRightClick then
		self:QuickTransferFromInventory(index)
		return
	end

	local slotStack = self.inventoryManager:GetInventorySlot(index)
	self:HandleSlotInteraction(slotStack, function(newStack)
		self.inventoryManager:SetInventorySlot(index, newStack)
		-- Also refresh the inventory panel's slot display
		self:UpdateInventorySlotDisplay(index)
	end, isRightClick)
end

function VoxelInventoryPanel:HandleHotbarSlotClick(index, isRightClick)
	if IsShiftHeld() and not isRightClick then
		self:QuickTransferFromHotbar(index)
		return
	end

	local slotStack = self.hotbar:GetSlot(index)
	self:HandleSlotInteraction(slotStack, function(newStack)
		-- Use inventoryManager to set hotbar slot so it tracks changes for server sync
		self.inventoryManager:SetHotbarSlot(index, newStack)
		-- Also refresh the inventory panel's hotbar slot display
		self:UpdateHotbarSlotDisplay(index)
	end, isRightClick)
end

function VoxelInventoryPanel:HandleEquipmentSlotClick(equipType)
	local cursorItemId = self.cursorStack:IsEmpty() and 0 or self.cursorStack:GetItemId()
	local cursorCount = self.cursorStack:IsEmpty() and 0 or self.cursorStack:GetCount()

	-- Send to server for authoritative handling
	EventManager:SendToServer("ArmorSlotClick", {
		slot = equipType,
		cursorItemId = cursorItemId,
		cursorCount = cursorCount
	})

	-- Sync inventory to server after armor equip
	if self.cursorStack:IsEmpty() then
		self:SendInventoryUpdateToServer()
	end

	playInventoryPopSound()
end

function VoxelInventoryPanel:HandleSlotInteraction(slotStack, setSlotFunc, isRightClick)
	local cursorEmpty = self.cursorStack:IsEmpty()
	local slotEmpty = slotStack:IsEmpty()

	if cursorEmpty and slotEmpty then
		return -- Nothing to do
	end

	if isRightClick then
		self:HandleRightClick(slotStack, setSlotFunc, cursorEmpty, slotEmpty)
	else
		self:HandleLeftClick(slotStack, setSlotFunc, cursorEmpty, slotEmpty)
	end

	self:UpdateCursorDisplay()
	playInventoryPopSound()

	-- Sync to server when action is complete (cursor not holding mid-transaction)
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

function VoxelInventoryPanel:HandleLeftClick(slotStack, setSlotFunc, cursorEmpty, slotEmpty)
	if cursorEmpty then
		-- Pick up entire stack
		self.cursorStack = slotStack:Clone()
		setSlotFunc(ItemStack.new(0, 0))
	elseif slotEmpty then
		-- Place entire stack
		setSlotFunc(self.cursorStack:Clone())
		self.cursorStack = ItemStack.new(0, 0)
	else
		-- Swap or merge
		if self.cursorStack:GetItemId() == slotStack:GetItemId() then
			-- Merge stacks
			local maxStack = 64
			local total = slotStack:GetCount() + self.cursorStack:GetCount()
			if total <= maxStack then
				setSlotFunc(ItemStack.new(slotStack:GetItemId(), total))
				self.cursorStack = ItemStack.new(0, 0)
			else
				setSlotFunc(ItemStack.new(slotStack:GetItemId(), maxStack))
				self.cursorStack = ItemStack.new(self.cursorStack:GetItemId(), total - maxStack)
			end
		else
			-- Swap
			local temp = slotStack:Clone()
			setSlotFunc(self.cursorStack:Clone())
			self.cursorStack = temp
		end
	end
end

function VoxelInventoryPanel:HandleRightClick(slotStack, setSlotFunc, cursorEmpty, slotEmpty)
	if cursorEmpty then
		-- Pick up half
		local count = slotStack:GetCount()
		local half = math.ceil(count / 2)
		self.cursorStack = ItemStack.new(slotStack:GetItemId(), half)
		if count - half > 0 then
			setSlotFunc(ItemStack.new(slotStack:GetItemId(), count - half))
		else
			setSlotFunc(ItemStack.new(0, 0))
		end
	elseif slotEmpty then
		-- Place one
		setSlotFunc(ItemStack.new(self.cursorStack:GetItemId(), 1))
		if self.cursorStack:GetCount() > 1 then
			self.cursorStack = ItemStack.new(self.cursorStack:GetItemId(), self.cursorStack:GetCount() - 1)
		else
			self.cursorStack = ItemStack.new(0, 0)
		end
	else
		-- Place one if same type
		if self.cursorStack:GetItemId() == slotStack:GetItemId() and slotStack:GetCount() < 64 then
			setSlotFunc(ItemStack.new(slotStack:GetItemId(), slotStack:GetCount() + 1))
			if self.cursorStack:GetCount() > 1 then
				self.cursorStack = ItemStack.new(self.cursorStack:GetItemId(), self.cursorStack:GetCount() - 1)
			else
				self.cursorStack = ItemStack.new(0, 0)
			end
		end
	end
end

function VoxelInventoryPanel:QuickTransferFromInventory(index)
	local stack = self.inventoryManager:GetInventorySlot(index)
	if stack:IsEmpty() then return end

	-- Try to merge with existing hotbar stacks first
	for i = 1, 9 do
		local hotbarStack = self.hotbar:GetSlot(i)
		if hotbarStack:GetItemId() == stack:GetItemId() and hotbarStack:GetCount() < 64 then
			local space = 64 - hotbarStack:GetCount()
			local transfer = math.min(space, stack:GetCount())
			-- Use inventoryManager to set hotbar slot so it tracks changes for server sync
			self.inventoryManager:SetHotbarSlot(i, ItemStack.new(stack:GetItemId(), hotbarStack:GetCount() + transfer))
			self:UpdateHotbarSlotDisplay(i)
			if stack:GetCount() - transfer > 0 then
				self.inventoryManager:SetInventorySlot(index, ItemStack.new(stack:GetItemId(), stack:GetCount() - transfer))
			else
				self.inventoryManager:SetInventorySlot(index, ItemStack.new(0, 0))
			end
			self:UpdateInventorySlotDisplay(index)
			playInventoryPopSound()
			self.inventoryManager:SendUpdateToServer()
			return
		end
	end

	-- Try empty slot
	for i = 1, 9 do
		if self.hotbar:GetSlot(i):IsEmpty() then
			-- Use inventoryManager to set hotbar slot so it tracks changes for server sync
			self.inventoryManager:SetHotbarSlot(i, stack:Clone())
			self:UpdateHotbarSlotDisplay(i)
			self.inventoryManager:SetInventorySlot(index, ItemStack.new(0, 0))
			self:UpdateInventorySlotDisplay(index)
			playInventoryPopSound()
			self.inventoryManager:SendUpdateToServer()
			return
		end
	end
end

function VoxelInventoryPanel:QuickTransferFromHotbar(index)
	local stack = self.hotbar:GetSlot(index)
	if stack:IsEmpty() then return end

	-- Try to merge with existing inventory stacks first
	for i = 1, 27 do
		local invStack = self.inventoryManager:GetInventorySlot(i)
		if invStack:GetItemId() == stack:GetItemId() and invStack:GetCount() < 64 then
			local space = 64 - invStack:GetCount()
			local transfer = math.min(space, stack:GetCount())
			self.inventoryManager:SetInventorySlot(i, ItemStack.new(stack:GetItemId(), invStack:GetCount() + transfer))
			self:UpdateInventorySlotDisplay(i)
			if stack:GetCount() - transfer > 0 then
				-- Use inventoryManager to set hotbar slot so it tracks changes for server sync
				self.inventoryManager:SetHotbarSlot(index, ItemStack.new(stack:GetItemId(), stack:GetCount() - transfer))
			else
				self.inventoryManager:SetHotbarSlot(index, ItemStack.new(0, 0))
			end
			self:UpdateHotbarSlotDisplay(index)
			playInventoryPopSound()
			self.inventoryManager:SendUpdateToServer()
			return
		end
	end

	-- Try empty slot
	for i = 1, 27 do
		if self.inventoryManager:GetInventorySlot(i):IsEmpty() then
			self.inventoryManager:SetInventorySlot(i, stack:Clone())
			self:UpdateInventorySlotDisplay(i)
			-- Use inventoryManager to set hotbar slot so it tracks changes for server sync
			self.inventoryManager:SetHotbarSlot(index, ItemStack.new(0, 0))
			self:UpdateHotbarSlotDisplay(index)
			playInventoryPopSound()
			self.inventoryManager:SendUpdateToServer()
			return
		end
	end
end

--------------------------------------------------------------------------------
-- Slot Display Updates
--------------------------------------------------------------------------------

function VoxelInventoryPanel:UpdateSlotDisplay(slotData, stack)
	-- Clear existing viewport reference
	slotData.viewport = nil

	-- Clear icon container (preserving UI layout components)
	for _, child in ipairs(slotData.iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	if stack:IsEmpty() then
		slotData.countLabel.Text = ""
		if slotData.placeholder then
			slotData.placeholder.Visible = true
		end
		return
	end

	if slotData.placeholder then
		slotData.placeholder.Visible = false
	end

	local itemId = stack:GetItemId()
	local count = stack:GetCount()

	-- Create item icon using the unified helper
	BlockViewportCreator.RenderItemSlot(slotData.iconContainer, itemId, SpawnEggConfig, SpawnEggIcon)

	-- Update count
	slotData.countLabel.Text = count > 1 and tostring(count) or ""
end

function VoxelInventoryPanel:RefreshAllSlots()
	-- Inventory slots
	for i = 1, 27 do
		local slotData = self.inventorySlotFrames[i]
		if slotData then
			local stack = self.inventoryManager:GetInventorySlot(i)
			self:UpdateSlotDisplay(slotData, stack)
		end
	end

	-- Hotbar slots
	for i = 1, 9 do
		local slotData = self.hotbarSlotFrames[i]
		if slotData then
			local stack = self.hotbar:GetSlot(i)
			self:UpdateSlotDisplay(slotData, stack)

			-- Update selection indicator
			local selectedIndex = self.hotbar.selectedSlot
			if slotData.selectBorder then
				slotData.selectBorder.Transparency = (i == selectedIndex) and 0 or 1
			end
		end
	end

	-- Equipment slots
	self:RefreshEquipmentSlots()
end

function VoxelInventoryPanel:RefreshEquipmentSlots()
	local slotMap = {
		Head = "helmet",
		Chest = "chestplate",
		Leggings = "leggings",
		Boots = "boots"
	}

	for equipType, armorKey in pairs(slotMap) do
		local slotData = self.equipmentSlotFrames[equipType]
		if slotData then
			local itemId = self.equippedArmor[armorKey]
			if itemId then
				self:UpdateSlotDisplay(slotData, ItemStack.new(itemId, 1))
			else
				self:UpdateSlotDisplay(slotData, ItemStack.new(0, 0))
			end
		end
	end

	-- Also refresh viewmodel armor visuals
	self:RefreshViewmodelArmor()
end

-- Refresh only the armor visuals on the viewmodel (more efficient than full rebuild)
function VoxelInventoryPanel:RefreshViewmodelArmor()
	if not self.armorViewmodel or not self.armorViewmodel._model then return end

	local clonedModel = self.armorViewmodel._model
	if clonedModel then
		CharacterRigBuilder.ClearArmorVisuals(clonedModel)
		CharacterRigBuilder.ApplyArmorVisuals(clonedModel, self.equippedArmor)
	end
end

-- Aliases for backward compatibility
function VoxelInventoryPanel:UpdateAllEquipmentSlots()
	self:RefreshEquipmentSlots()
end

function VoxelInventoryPanel:UpdateAllDisplays()
	self:RefreshAllSlots()
end

-- Single slot update methods (for external callbacks)
function VoxelInventoryPanel:UpdateInventorySlotDisplay(slotIndex)
	local slotData = self.inventorySlotFrames[slotIndex]
	if slotData then
		local stack = self.inventoryManager:GetInventorySlot(slotIndex)
		self:UpdateSlotDisplay(slotData, stack)
	end
end

function VoxelInventoryPanel:UpdateHotbarSlotDisplay(slotIndex)
	local slotData = self.hotbarSlotFrames[slotIndex]
	if slotData then
		local stack = self.hotbar:GetSlot(slotIndex)
		self:UpdateSlotDisplay(slotData, stack)

		local selectedIndex = self.hotbar.selectedSlot
		if slotData.selectBorder then
			slotData.selectBorder.Transparency = (slotIndex == selectedIndex) and 0 or 1
		end
	end
end

--------------------------------------------------------------------------------
-- Cursor Display
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreateCursorFrame()
	local cursor = Instance.new("Frame")
	cursor.Name = "CursorItem"
	cursor.Size = UDim2.fromOffset(CONFIG.SLOT_SIZE, CONFIG.SLOT_SIZE)
	cursor.AnchorPoint = Vector2.new(0.5, 0.5)
	cursor.BackgroundTransparency = 1
	cursor.ZIndex = 100
	cursor.Visible = false
	cursor.Parent = self.cursorGui

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = cursor

	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.fromOffset(40, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = MIN_TEXT_SIZE
	countLabel.TextColor3 = CONFIG.TEXT_PRIMARY
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 101
	countLabel.Parent = cursor

	self.cursorFrame = cursor
	self.cursorIconContainer = iconContainer
	self.cursorCountLabel = countLabel
end

function VoxelInventoryPanel:UpdateCursorDisplay()
	if not self.cursorFrame then return end

	-- Clear existing (preserving UI layout components)
	for _, child in ipairs(self.cursorIconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	if self.cursorStack:IsEmpty() then
		self.cursorFrame.Visible = false
		return
	end

	self.cursorFrame.Visible = true

	local itemId = self.cursorStack:GetItemId()
	local count = self.cursorStack:GetCount()

	-- Create icon using the unified helper
	BlockViewportCreator.RenderItemSlot(self.cursorIconContainer, itemId, SpawnEggConfig, SpawnEggIcon)

	self.cursorCountLabel.Text = count > 1 and tostring(count) or ""
end

function VoxelInventoryPanel:UpdateCursorPosition()
	if not self.cursorFrame or not self.cursorFrame.Visible then return end

	local mousePos = UserInputService:GetMouseLocation()
	-- GetMouseLocation returns absolute screen coordinates
	-- Our cursor GUI has IgnoreGuiInset=true so it covers the full screen
	self.cursorFrame.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
end

function VoxelInventoryPanel:SendInventoryUpdateToServer()
	-- Delegate to inventory manager
	if self.inventoryManager and self.inventoryManager.SendUpdateToServer then
		self.inventoryManager:SendUpdateToServer()
	end
end

--------------------------------------------------------------------------------
-- Hover Item Label
--------------------------------------------------------------------------------

function VoxelInventoryPanel:CreateHoverItemLabel()
	local label = Instance.new("TextLabel")
	label.Name = "HoverItemLabel"
	label.Size = UDim2.fromOffset(300, 30)
	label.Position = UDim2.fromOffset(10, 10)
	label.BackgroundTransparency = 1
	label.Font = BOLD_FONT
	label.TextSize = 24
	label.TextColor3 = CONFIG.TEXT_PRIMARY
	label.TextStrokeTransparency = 0.3
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Visible = false
	label.ZIndex = 50
	label.Parent = self.gui

	self.hoverItemLabel = label
end

function VoxelInventoryPanel:ShowHoverItemName(itemId)
	if not self.hoverItemLabel then return end

	local name = GetItemDisplayName(itemId)
	if name then
		self.hoverItemLabel.Text = name
		self.hoverItemLabel.Visible = true
	else
		self.hoverItemLabel.Visible = false
	end
end

function VoxelInventoryPanel:HideHoverItemName()
	if self.hoverItemLabel then
		self.hoverItemLabel.Visible = false
	end
end

function VoxelInventoryPanel:ResetAllHoverStates()
	-- Reset inventory slot hover states
	for _, slotData in pairs(self.inventorySlotFrames) do
		if slotData.hoverBorder then
			slotData.hoverBorder.Transparency = 1
		end
	end

	-- Reset hotbar slot hover states
	for _, slotData in pairs(self.hotbarSlotFrames) do
		if slotData.hoverBorder then
			slotData.hoverBorder.Transparency = 1
		end
	end

	-- Reset equipment slot hover states
	for _, slotData in pairs(self.equipmentSlotFrames) do
		if slotData.hoverBorder then
			slotData.hoverBorder.Transparency = 1
		end
	end

	-- Hide hover item label
	self:HideHoverItemName()
end

--------------------------------------------------------------------------------
-- Armor Viewmodel Helpers
--------------------------------------------------------------------------------

function VoxelInventoryPanel:ClearArmorHeldItem()
	if self.armorViewmodel and self.armorViewmodel._model then
		HeldItemRenderer.ClearItem(self.armorViewmodel._model)
	end
end

function VoxelInventoryPanel:RefreshArmorHeldItem()
	if not self.armorViewmodel then return end

	local rigModel = self.armorViewmodel._model
	if not rigModel then return end

	self:ClearArmorHeldItem()

	-- Check for tool
	local toolId = GameState:Get("voxelWorld.selectedToolItemId")
	if toolId and ToolConfig.IsTool(toolId) then
		HeldItemRenderer.AttachItem(rigModel, toolId)
		return
	end

	-- Check for block
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	local blockId = selectedBlock and selectedBlock.id
	if blockId and blockId > 0 then
		HeldItemRenderer.AttachItem(rigModel, blockId)
	end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function VoxelInventoryPanel:SetupInputHandling()
	-- Escape to close (using InputService signal)
	local escapeConn = InputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:Close()
		end
	end)
	table.insert(self.connections, escapeConn)

	-- Drop item when clicking outside inventory
	local dropConn = InputService.InputBegan:Connect(function(input, _processed)
		if not self.isOpen then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

		-- Check if clicked outside inventory panel
		local mouse = Players.LocalPlayer:GetMouse()
		local panelPos = self.panel.AbsolutePosition
		local panelSize = self.panel.AbsoluteSize

		local isOutside = mouse.X < panelPos.X or mouse.X > (panelPos.X + panelSize.X) or
		                  mouse.Y < panelPos.Y or mouse.Y > (panelPos.Y + panelSize.Y)

		if isOutside and not self.cursorStack:IsEmpty() then
			-- Drop cursor item
			pcall(function()
				EventManager:SendToServer("RequestDropItem", {
					itemId = self.cursorStack:GetItemId(),
					count = self.cursorStack:GetCount(),
					fromCursor = false
				})
			end)
			playInventoryPopSound()
			self.cursorStack = ItemStack.new(0, 0)
			self:UpdateCursorDisplay()
		end
	end)
	table.insert(self.connections, dropConn)
end

-- Alias for backward compatibility
function VoxelInventoryPanel:BindInput()
	self:SetupInputHandling()
end

--------------------------------------------------------------------------------
-- Inventory Sync
--------------------------------------------------------------------------------

function VoxelInventoryPanel:SetupInventorySync()
	self.inventoryManager:OnInventoryChanged(function(slotIndex)
		if self.isOpen and slotIndex then
			self:UpdateInventorySlotDisplay(slotIndex)
		end
	end)

	self.inventoryManager:OnHotbarChanged(function(slotIndex)
		if self.isOpen and slotIndex then
			self:UpdateHotbarSlotDisplay(slotIndex)
		end
	end)
end

--------------------------------------------------------------------------------
-- Armor Event Listeners
--------------------------------------------------------------------------------

function VoxelInventoryPanel:SetupArmorEventListeners()
	-- Listen for full armor sync (on join/reconnect)
	local armorSyncConn = EventManager:RegisterEvent("ArmorSync", function(data)
		if data and data.equippedArmor then
			self.equippedArmor = {
				helmet = data.equippedArmor.helmet,
				chestplate = data.equippedArmor.chestplate,
				leggings = data.equippedArmor.leggings,
				boots = data.equippedArmor.boots
			}
			self:RefreshEquipmentSlots()
			if self.updateArmorViewmodel then
				task.spawn(self.updateArmorViewmodel)
			end
		end
	end)
	if armorSyncConn then
		table.insert(self.connections, armorSyncConn)
	end

	-- Listen for armor slot click result (server-authoritative)
	local armorSlotResultConn = EventManager:RegisterEvent("ArmorSlotResult", function(data)
		if data then
			if data.equippedArmor then
				self.equippedArmor = {
					helmet = data.equippedArmor.helmet,
					chestplate = data.equippedArmor.chestplate,
					leggings = data.equippedArmor.leggings,
					boots = data.equippedArmor.boots
				}
			end

			if data.newCursorItemId and data.newCursorItemId > 0 then
				self.cursorStack = ItemStack.new(data.newCursorItemId, data.newCursorCount or 1)
			else
				self.cursorStack = ItemStack.new(0, 0)
			end

			self:RefreshEquipmentSlots()
			self:UpdateCursorDisplay()
			if self.updateArmorViewmodel then
				task.spawn(self.updateArmorViewmodel)
			end
		end
	end)
	if armorSlotResultConn then
		table.insert(self.connections, armorSlotResultConn)
	end

	-- Listen for individual armor equip events
	local armorEquippedConn = EventManager:RegisterEvent("ArmorEquipped", function(data)
		if data and data.slot and data.itemId then
			self.equippedArmor[data.slot] = data.itemId
			self:RefreshEquipmentSlots()
			if self.updateArmorViewmodel then
				task.spawn(self.updateArmorViewmodel)
			end
		end
	end)
	if armorEquippedConn then
		table.insert(self.connections, armorEquippedConn)
	end

	-- Listen for armor unequip events
	local armorUnequippedConn = EventManager:RegisterEvent("ArmorUnequipped", function(data)
		if data and data.slot then
			self.equippedArmor[data.slot] = nil
			self:RefreshEquipmentSlots()
			if self.updateArmorViewmodel then
				task.spawn(self.updateArmorViewmodel)
			end
		end
	end)
	if armorUnequippedConn then
		table.insert(self.connections, armorUnequippedConn)
	end

	-- Request current armor state from server after a delay
	task.delay(2, function()
		EventManager:SendToServer("RequestArmorSync")
	end)
end

--------------------------------------------------------------------------------
-- Open/Close
--------------------------------------------------------------------------------

function VoxelInventoryPanel:Open()
	if self.isOpen or self.isAnimating then
		return
	end

	self.isOpen = true
	self.isAnimating = true
	self.gui.Enabled = true

	-- Use UIVisibilityManager to coordinate all UI (handles backdrop, cursor, etc.)
	local success, err = pcall(function()
		UIVisibilityManager:SetMode("inventory")
	end)
	if not success then
		warn("[VoxelInventoryPanel] UIVisibilityManager:SetMode failed:", err)
	end

	-- Reset crafting panel state
	if self.craftingPanel and self.craftingPanel.OnPanelOpen then
		pcall(function()
			self.craftingPanel:OnPanelOpen()
		end)
	end

	-- Refresh slots
	local refreshSuccess, refreshErr = pcall(function()
		self:RefreshAllSlots()
	end)
	if not refreshSuccess then
		warn("[VoxelInventoryPanel] RefreshAllSlots failed:", refreshErr)
	end

	-- Enable viewmodel tracking
	if self.armorViewmodel then
		self.armorViewmodel:SetMouseTracking(true)
	end

	-- Start cursor tracking
	self.renderConnection = RunService.RenderStepped:Connect(function()
		if self.isOpen then
			self:UpdateCursorPosition()
		end
	end)

	-- Animate in
	local finalHeight = self.originalPanelHeight
	local startHeight = CONFIG.HEADER_HEIGHT

	self.panel.Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, startHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0, 60 + startHeight / 2)

	local tween = TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, finalHeight),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})

	tween:Play()
	tween.Completed:Connect(function()
		self.isAnimating = false
		-- Enable hover effects after animation completes
		self.hoverEnabled = true
	end)
end

function VoxelInventoryPanel:Close(nextMode)
	if not self.isOpen or self.isAnimating then return end

	self.isOpen = false
	self.isAnimating = true
	self.pendingCloseMode = nextMode or "gameplay"

	-- Disable hover effects immediately
	self.hoverEnabled = false

	-- Reset all hover effects and labels
	self:ResetAllHoverStates()

	-- Disable viewmodel tracking
	if self.armorViewmodel then
		self.armorViewmodel:SetMouseTracking(false)
	end

	-- Stop cursor tracking
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Return cursor items to inventory
	if not self.cursorStack:IsEmpty() then
		for i = 1, 27 do
			if self.inventoryManager:GetInventorySlot(i):IsEmpty() then
				self.inventoryManager:SetInventorySlot(i, self.cursorStack:Clone())
				self.cursorStack = ItemStack.new(0, 0)
				self:UpdateCursorDisplay()
				break
			end
		end

		-- Drop if no space
		if not self.cursorStack:IsEmpty() then
			EventManager:SendToServer("RequestDropItem", {
				itemId = self.cursorStack:GetItemId(),
				count = self.cursorStack:GetCount()
			})
			self.cursorStack = ItemStack.new(0, 0)
			self:UpdateCursorDisplay()
		end
	end

	-- Sync inventory changes to server
	if self.inventoryManager and self.inventoryManager.SendUpdateToServer then
		self.inventoryManager:SendUpdateToServer()
	end

	-- Animate out
	local startHeight = CONFIG.HEADER_HEIGHT

	local tween = TweenService:Create(self.panel, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In), {
		Size = UDim2.fromOffset(CONFIG.PANEL_WIDTH, startHeight),
		Position = UDim2.new(0.5, 0, 0, 60 + startHeight / 2)
	})

	tween:Play()
	tween.Completed:Connect(function()
		self.isAnimating = false
		self.gui.Enabled = false

		if self.isWorkbenchMode then
			self:SetWorkbenchMode(false)
		end

		UIVisibilityManager:SetMode(self.pendingCloseMode or "gameplay")
	end)
end

function VoxelInventoryPanel:Toggle()
	if self.isAnimating then
		return
	end

	if self.isOpen then
		self:Close()
	else
		self:Open()
	end
end

function VoxelInventoryPanel:IsOpen()
	return self.isOpen
end

function VoxelInventoryPanel:IsClosing()
	return self.isAnimating and not self.isOpen
end

function VoxelInventoryPanel:SetPendingCloseMode(mode)
	self.pendingCloseMode = mode or "gameplay"
end

function VoxelInventoryPanel:IsCursorHoldingItem()
	return not self.cursorStack:IsEmpty()
end

-- UIVisibilityManager compatibility (simple enable/disable, not full open/close)
function VoxelInventoryPanel:Show()
	if not self.gui then return end
	self.gui.Enabled = true
end

function VoxelInventoryPanel:Hide()
	if not self.gui then return end
	self.gui.Enabled = false
end

--------------------------------------------------------------------------------
-- Workbench Mode
--------------------------------------------------------------------------------

function VoxelInventoryPanel:SetWorkbenchMode(enabled)
	self.isWorkbenchMode = enabled and true or false

	if self.craftingPanel and self.craftingPanel.SetMode then
		self.craftingPanel:SetMode(self.isWorkbenchMode and "workbench" or "inventory")
	end

	if self.titleLabel then
		self.titleLabel.Text = self.isWorkbenchMode and "WORKBENCH" or "INVENTORY"
	end

	if self.isWorkbenchMode then
		self:SetActiveTab("crafting")
	end
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function VoxelInventoryPanel:Cleanup()
	for _, conn in ipairs(self.connections) do
		if typeof(conn) == "table" and conn.Disconnect then
			conn:Disconnect()
		elseif typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	self.connections = {}

	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	self:ClearArmorHeldItem()

	if self.armorViewmodel then
		self.armorViewmodel:Destroy()
		self.armorViewmodel = nil
	end

	if self.gui then
		self.gui:Destroy()
	end

	if self.cursorGui then
		self.cursorGui:Destroy()
	end
end

return VoxelInventoryPanel
