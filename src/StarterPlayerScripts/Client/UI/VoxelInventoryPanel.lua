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
local InputService = require(script.Parent.Parent.Input.InputService)
local GuiService = game:GetService("GuiService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local BlockProperties = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockProperties)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local ViewportPreview = require(script.Parent.Parent.Managers.ViewportPreview)
local UIScaler = require(script.Parent.Parent.Managers.UIScaler)
local CharacterRigBuilder = require(script.Parent.CharacterRigBuilder)
local HeldItemRenderer = require(ReplicatedStorage.Shared.HeldItemRenderer)
local ItemModelLoader = require(ReplicatedStorage.Shared.ItemModelLoader)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local ItemPixelSizes = require(ReplicatedStorage.Shared.ItemPixelSizes)
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold
local MIN_TEXT_SIZE = 20

local CUSTOM_FONT_NAME = "Upheaval BRK"
local HEADING_SIZE = 54
local LABEL_SIZE = 24

local VoxelInventoryPanel = {}
VoxelInventoryPanel.__index = VoxelInventoryPanel

-- Inventory configuration (bare minimum, transparent)
local INVENTORY_CONFIG = {
	COLUMNS = 9,
	ROWS = 3, -- 3 rows of storage (27 slots) + 9 hotbar slots = 36 total

	-- Layout sizing
	SLOT_SIZE = 56,  -- Frame size (visual size is 60px with 2px border on each side)
	SLOT_SPACING = 5,  -- Gap between slots (between borders)
	HEADER_HEIGHT = 54,
	BODY_HEIGHT = 356,
	LABEL_HEIGHT = 22,
	LABEL_SPACING = 8,

	-- Column layout (precise dimensions)
	-- Border: 3px on each side (outer borders, so frames are smaller than visual size)
	MENU_WIDTH = 94,  -- 94px buttons + 6px margin
	MENU_BUTTON_SIZE = 94,  -- Visual size (frame will be 94px to account for 3px borders)
	MENU_MARGIN = 6,
	CONTENT_WIDTH = 402,  -- Frame width (visual width 408 with 3px borders on each side)
	CONTENT_MARGIN = 6,  -- 6px gap between visual edges (including borders)
	INVENTORY_WIDTH = 604,  -- Frame width (visual width 598 with 3px borders on each side)
	TOTAL_WIDTH = 1124,  -- Total visual width: 94 + 6 + 402 + 6 + 604 = 1118

	-- Equipment slots
	EQUIPMENT_SLOT_SIZE = 56,  -- Frame size (visual size is 60px with 2px border on each side)
	EQUIPMENT_SPACING = 6,

	-- Colors
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
	EQUIPMENT_COLOR = Color3.fromRGB(50, 50, 60),
	NAV_BG_COLOR = Color3.fromRGB(58, 58, 58),
	CONTENT_BG_COLOR = Color3.fromRGB(58, 58, 58),
	INVENTORY_BG_COLOR = Color3.fromRGB(58, 58, 58),
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),
	BORDER_COLOR = Color3.fromRGB(77,77,77),
	OVERLAY_COLOR = Color3.fromRGB(4, 4, 6),
	OVERLAY_TRANSPARENCY = 0.35,
}

-- Universal grip for character preview (same as HeldItemRenderer)
local PREVIEW_GRIP = { pos = Vector3.new(0, -0.3, -0.5), rot = Vector3.new(0, 45, 0) }
local STUDS_PER_PIXEL = 3 / 16

local function cframeFromPosRotDeg(pos, rot)
	return CFrame.new(pos) * CFrame.Angles(
		math.rad(rot.X),
		math.rad(rot.Y),
		math.rad(rot.Z)
	)
end

local function scaleMeshToPixels(part, itemName)
	local px = ItemPixelSizes.GetSize(itemName)
	if not px then return end
	local longestPx = math.max(px.x or 0, px.y or 0)
	if longestPx <= 0 then return end
	local targetStuds = longestPx * STUDS_PER_PIXEL
	local size = part.Size
	local maxDim = math.max(size.X, size.Y, size.Z)
	if maxDim > 0 then
		local scale = targetStuds / maxDim
		part.Size = Vector3.new(size.X * scale, size.Y * scale, size.Z * scale)
	end
end

local function playInventoryPopSound()
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("inventoryPop")
	end
end

local function createToolHandle(itemId)
	if not itemId then return nil end

	-- Get item name for model lookup
	local itemName = ItemRegistry.GetItemName(itemId)
	if not itemName or itemName == "Unknown" then return nil end

	-- Get model using unified loader
	local mesh = ItemModelLoader.GetModelTemplate(itemName, itemId)
	if not mesh then return nil end

	local handle = mesh:Clone()
	handle.Name = "ArmorToolHandle"
	handle.Massless = true
	handle.CanCollide = false
	handle.CastShadow = false
	pcall(function()
		handle.Anchored = false
	end)

	-- Apply texture from ItemRegistry if needed
	local hasExistingTexture = false
	pcall(function()
		local currentTexture = handle.TextureID
		hasExistingTexture = currentTexture ~= nil and tostring(currentTexture) ~= ""
	end)
	if not hasExistingTexture then
		local itemDef = ItemRegistry.GetItem(itemId)
		local textureId = itemDef and itemDef.image
		if textureId then
			pcall(function()
				handle.TextureID = textureId
			end)
		end
	end

	-- Scale using ItemPixelSizes
	scaleMeshToPixels(handle, itemName)

	-- Return handle and toolType for backward compatibility
	local toolType = nil
	if ToolConfig.IsTool(itemId) then
		toolType = select(1, ToolConfig.GetBlockProps(itemId))
	end

	return handle, toolType
end
-- Helper function to get display name for any item type
local function GetItemDisplayName(itemId)
	if not itemId or itemId == 0 then
		return nil
	end

	-- Check if it's a tool (use unified ItemRegistry)
	if ToolConfig.IsTool(itemId) then
		return ItemRegistry.GetItemName(itemId)
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
	self.hoverItemLabel = nil  -- Label for displaying hovered item name

	-- UI slot frames
	self.inventorySlotFrames = {}
	self.equipmentSlotFrames = {}  -- Head, Chest, Leggings, Boots
	self.hotbarSlotFrames = {}

	-- Section/menu state
	self.sectionButtons = {}
	self.activeSection = "craft"
	self.craftSection = nil
	self.armorSection = nil
	self.armorScaleListener = nil
	self.armorToolListener = nil
	self.armorHoldingToolListener = nil
	self.armorToolHandle = nil
	self.armorToolWeld = nil

	-- Cursor/drag state (Minecraft-style)
	self.cursorStack = ItemStack.new(0, 0) -- Item attached to cursor
	self.cursorFrame = nil

	-- Equipped armor state (synced from server)
	self.equippedArmor = {
		helmet = nil,
		chestplate = nil,
		leggings = nil,
		boots = nil
	}

	self.connections = {}
	self.renderConnection = nil
	self.pendingCloseMode = "gameplay"
	self.overlayRelease = nil

	-- Animation state tracking
	self.isAnimating = false
	self.currentTween = nil

	return self
end

-- Keep cursor unlocked while the inventory overlay is visible.
function VoxelInventoryPanel:_acquireOverlay()
	if self.overlayRelease then
		return
	end

	local release = InputService:BeginOverlay("VoxelInventoryPanel", {
		showIcon = true,
	})

	if release then
		self.overlayRelease = release
	end
end

function VoxelInventoryPanel:_releaseOverlay()
	if not self.overlayRelease then
		return
	end

	local release = self.overlayRelease
	self.overlayRelease = nil
	release()
end

function VoxelInventoryPanel:Initialize()
	FontBinder.preload(CUSTOM_FONT_NAME)

	-- Create ScreenGui for inventory panel
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VoxelInventory"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100  -- Above backdrop (99)
	self.gui.IgnoreGuiInset = false
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
	uiScale:SetAttribute("min_scale", 0.6) -- Allow additional shrink on phones/tablets
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create hover item name label (top left of screen)
	self:CreateHoverItemLabel()

	-- Create panels
	self:CreatePanel()
	self:CreateCursorItem()

	-- Bind input
	self:BindInput()

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("voxelInventory", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		isOpenMethod = "IsOpen",
		priority = 100
	})

	-- Listen for armor events from server
	self:SetupArmorEventListeners()

	return self
end

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
			self:UpdateAllEquipmentSlots()
		end
	end)
	if armorSyncConn then
		table.insert(self.connections, armorSyncConn)
	end

	-- Listen for armor slot click result (server-authoritative)
	local armorSlotResultConn = EventManager:RegisterEvent("ArmorSlotResult", function(data)
		if data then
			-- Update equipped armor from server
			if data.equippedArmor then
				self.equippedArmor = {
					helmet = data.equippedArmor.helmet,
					chestplate = data.equippedArmor.chestplate,
					leggings = data.equippedArmor.leggings,
					boots = data.equippedArmor.boots
				}
			end

			-- Update cursor from server response
			if data.newCursorItemId and data.newCursorItemId > 0 then
				self.cursorStack = ItemStack.new(data.newCursorItemId, data.newCursorCount or 1)
			else
				self.cursorStack = ItemStack.new(0, 0)
			end

			-- Refresh displays
			self:UpdateAllEquipmentSlots()
			self:UpdateCursorDisplay()
		end
	end)
	if armorSlotResultConn then
		table.insert(self.connections, armorSlotResultConn)
	end

	-- Listen for individual armor equip events
	local armorEquippedConn = EventManager:RegisterEvent("ArmorEquipped", function(data)
		if data and data.slot and data.itemId then
			self.equippedArmor[data.slot] = data.itemId
			self:UpdateAllEquipmentSlots()
		end
	end)
	if armorEquippedConn then
		table.insert(self.connections, armorEquippedConn)
	end

	-- Listen for armor unequip events
	local armorUnequippedConn = EventManager:RegisterEvent("ArmorUnequipped", function(data)
		if data and data.slot then
			self.equippedArmor[data.slot] = nil
			self:UpdateAllEquipmentSlots()
		end
	end)
	if armorUnequippedConn then
		table.insert(self.connections, armorUnequippedConn)
	end

	-- Request current armor state from server after a delay to ensure server has loaded player data
	-- The server's LoadArmor runs during OnPlayerAdded which may still be in progress
	task.delay(2, function()
		EventManager:SendToServer("RequestArmorSync")
	end)
end

function VoxelInventoryPanel:CreateHoverItemLabel()
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

function VoxelInventoryPanel:ShowHoverItemName(itemId)
	if not self.hoverItemLabel then return end

	local itemName = GetItemDisplayName(itemId)
	if itemName then
		self.hoverItemLabel.Text = itemName
		self.hoverItemLabel.Visible = true
	else
		self.hoverItemLabel.Visible = false
	end
end

function VoxelInventoryPanel:HideHoverItemName()
	if not self.hoverItemLabel then return end
	self.hoverItemLabel.Visible = false
end

function VoxelInventoryPanel:CreatePanel()
	local totalWidth = INVENTORY_CONFIG.TOTAL_WIDTH
	local totalHeight = INVENTORY_CONFIG.HEADER_HEIGHT + INVENTORY_CONFIG.BODY_HEIGHT

	-- Main panel (transparent container - backdrop handled by UIVisibilityManager)
	-- Positioned vertically centered, offset upward by header height
	-- Anchor point at center (0.5, 0.5) for consistent positioning
	self.panel = Instance.new("Frame")
	self.panel.Name = "InventoryPanel"
	self.panel.Size = UDim2.new(0, totalWidth, 0, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, -INVENTORY_CONFIG.HEADER_HEIGHT)  -- Centered, offset by header
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)  -- Center anchor
	self.panel.BackgroundTransparency = 1  -- Fully transparent
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui

	-- Header frame: 1124x54 with title on left, close button on right (vertically centered)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(0, totalWidth, 0, INVENTORY_CONFIG.HEADER_HEIGHT)
	headerFrame.Position = UDim2.new(0, 0, 0, 0)
	headerFrame.BackgroundTransparency = 1
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = self.panel

	-- Title text (left side, Upheaval font at 48px, vertically centered)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.new(0, 0, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "INVENTORY"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = HEADING_SIZE
	title.Font = Enum.Font.Code
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame

	FontBinder.apply(title, CUSTOM_FONT_NAME)
	self.titleLabel = title

	-- Close button (40x40, vertically centered on right)
	local closeIcon = IconManager:CreateIcon(headerFrame, "UI", "X", {
		size = UDim2.new(0, 44, 0, 44),
		position = UDim2.new(1, 0, 0, 0),
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

	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, { Rotation = 90 }):Play()
	end)

	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, { Rotation = 0 }):Play()
	end)

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	closeIcon:Destroy()

	-- Body frame: contains the three columns
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.new(0, totalWidth, 0, INVENTORY_CONFIG.BODY_HEIGHT)
	bodyFrame.Position = UDim2.new(0, 0, 0, INVENTORY_CONFIG.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.BorderSizePixel = 0
	bodyFrame.Parent = self.panel

	-- Create the three columns (menu, content, inventory)
	self:CreateMenuColumn(bodyFrame)
	self:CreateContentColumn(bodyFrame)
	self:CreateInventoryColumn(bodyFrame)

	self:SetActiveSection(self.activeSection or "craft")
end

function VoxelInventoryPanel:CreateMenuColumn(parent)
	-- Menu column: 100x356, transparent, 94px buttons with 6px margin
	local column = Instance.new("Frame")
	column.Name = "MenuColumn"
	column.Size = UDim2.new(0, INVENTORY_CONFIG.MENU_WIDTH, 0, INVENTORY_CONFIG.BODY_HEIGHT)
	column.Position = UDim2.new(0, 0, 0, 0)
	column.BackgroundTransparency = 1  -- Transparent
	column.BorderSizePixel = 0
	column.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, INVENTORY_CONFIG.MENU_MARGIN)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.Parent = column

	self.sectionButtons = {}

	self:CreateSectionButton(column, "craft", 1, "Tools", "Hammer")
	self:CreateSectionButton(column, "armor", 2, "Weapons", "Shield")
end

function VoxelInventoryPanel:CreateSectionButton(parent, section, layoutOrder, iconCategory, iconName)
	-- Button container (list item)
	local container = Instance.new("Frame")
	container.Name = string.format("%sContainer", section)
	container.LayoutOrder = layoutOrder or 0
	local visualSize = INVENTORY_CONFIG.MENU_BUTTON_SIZE  -- 100px visual size
	local buttonSize = visualSize - 6  -- Frame size: 94px (100 - 6 for 3px borders on each side)
	local shadowHeight = 18
	-- Container needs extra height for shadow (shadow extends 12px below button bottom)
	container.Size = UDim2.new(0, visualSize, 0, visualSize + shadowHeight / 2)  -- Container accommodates shadow
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Parent = parent

	-- Main button (frame size, borders are outer)
	local button = Instance.new("ImageButton")
	button.Name = string.format("%sButton", section)
	button.Size = UDim2.new(0, buttonSize, 0, buttonSize)  -- 94x94 (100 - 6)
	button.Position = UDim2.new(0, 3, 0, 3)  -- 3px offset for border
	button.BackgroundColor3 = INVENTORY_CONFIG.NAV_BG_COLOR
	button.BackgroundTransparency = 0
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.ZIndex = 1
	button.Parent = container

	-- Shadow: decorative element, part of the button (positioned at bottom)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, buttonSize, 0, shadowHeight)  -- 24px height
	shadow.AnchorPoint = Vector2.new(0, 0.5)  -- Left-center vertically
	-- Position: 3px border offset horizontally, at button bottom (centered vertically)
	-- Button bottom is at: 3 (top) + 94 (height) = 97px from container top
	shadow.Position = UDim2.new(0, 3, 0, buttonSize + 3)  -- 3px border, at bottom edge
	shadow.BackgroundColor3 = INVENTORY_CONFIG.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0  -- Behind button
	shadow.Parent = container

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 8)
	rounded.Parent = button

	-- Inner border: 3px white at 20% transparency
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = INVENTORY_CONFIG.BORDER_COLOR
	border.Thickness = 3
	border.Parent = button

	-- Create icon using IconManager
	local icon = IconManager:CreateIcon(button, iconCategory, iconName, {
		size = UDim2.new(0, 64, 0, 64),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5)
	})
	icon.ImageColor3 = Color3.fromRGB(185, 185, 195)  -- Default inactive color
	icon.Name = "Icon"

	button.MouseButton1Click:Connect(function()
		self:SetActiveSection(section)
	end)

	self.sectionButtons[section] = button
end

function VoxelInventoryPanel:CreateContentColumn(parent)
	-- Content column: frame size (borders are outer)
	local visualWidth = INVENTORY_CONFIG.CONTENT_WIDTH + 6  -- 408 visual (402 frame + 6px borders)
	local visualHeight = INVENTORY_CONFIG.BODY_HEIGHT + 6  -- 362 visual (356 frame + 6px borders)
	local columnWidth = INVENTORY_CONFIG.CONTENT_WIDTH  -- 402 frame width
	local columnHeight = INVENTORY_CONFIG.BODY_HEIGHT  -- 356 frame height
	local shadowHeight = 18

	-- Position: 6px gap from menu (100 + 6 = 106)
	local columnX = INVENTORY_CONFIG.MENU_WIDTH + INVENTORY_CONFIG.CONTENT_MARGIN

	-- Content column: 402x356 frame (408x362 visual with borders)
	local column = Instance.new("Frame")
	column.Name = "ContentColumn"
	column.Size = UDim2.new(0, columnWidth, 0, columnHeight)
	column.Position = UDim2.new(0, columnX + 3, 0, 3)  -- 3px offset for border
	column.BackgroundColor3 = INVENTORY_CONFIG.CONTENT_BG_COLOR
	column.BackgroundTransparency = 0
	column.BorderSizePixel = 0
	column.ZIndex = 1
	column.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = column

	-- Shadow: decorative border shadow (positioned at bottom)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, columnWidth, 0, shadowHeight)
	shadow.AnchorPoint = Vector2.new(0, 0.5)  -- Left-center vertically
	-- Position: 3px border offset horizontally, at column bottom (centered vertically)
	-- Column bottom is at: 3 (top) + 356 (height) = 359px from body top
	shadow.Position = UDim2.new(0, columnX + 3, 0, columnHeight + 3)  -- 3px border, at bottom edge
	shadow.BackgroundColor3 = INVENTORY_CONFIG.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0  -- Behind column
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	-- Inner border: 3px white at 20% transparency
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = INVENTORY_CONFIG.BORDER_COLOR
	border.Thickness = 3
	border.Parent = column

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = column

	local stack = Instance.new("Frame")
	stack.Name = "SectionStack"
	stack.Size = UDim2.new(1, 0, 1, 0)
	stack.BackgroundTransparency = 1
	stack.Parent = column

	self.craftSection = Instance.new("Frame")
	self.craftSection.Name = "CraftSection"
	self.craftSection.Size = UDim2.new(1, 0, 1, 0)
	self.craftSection.BackgroundTransparency = 1
	self.craftSection.Parent = stack

	local CraftingPanel = require(script.Parent.CraftingPanel)
	self.craftingPanel = CraftingPanel.new(self.inventoryManager, self, self.craftSection)
	self.craftingPanel:Initialize()

	self.armorSection = Instance.new("Frame")
	self.armorSection.Name = "ArmorSection"
	self.armorSection.Size = UDim2.new(1, 0, 1, 0)
	self.armorSection.BackgroundTransparency = 1
	self.armorSection.Visible = false
	self.armorSection.Parent = stack

	self:CreateArmorSkeleton(self.armorSection)
end

function VoxelInventoryPanel:ClearArmorHeldItem()
	-- Use unified renderer to clear held items
	if self.armorViewmodel and self.armorViewmodel._model then
		HeldItemRenderer.ClearItem(self.armorViewmodel._model)
	end
end

-- Legacy alias for compatibility
function VoxelInventoryPanel:ClearArmorTool()
	self:ClearArmorHeldItem()
end

function VoxelInventoryPanel:AttachHeldItemToRig(rig, itemId)
	if not rig or not itemId or itemId == 0 then return end

	-- Use unified renderer to attach the item (tool or block)
	HeldItemRenderer.AttachItem(rig, itemId)
end

-- Legacy alias for compatibility
function VoxelInventoryPanel:AttachToolToRig(rig, toolItemId)
	self:AttachHeldItemToRig(rig, toolItemId)
end

function VoxelInventoryPanel:RefreshArmorHeldItem()
	if not self.armorViewmodel then return end

	local rigModel = self.armorViewmodel._model
	if not rigModel then return end

	-- Clear any existing held items first
	self:ClearArmorHeldItem()

	-- Check for tool first (priority)
	local toolId = GameState:Get("voxelWorld.selectedToolItemId")
	if toolId and ToolConfig.IsTool(toolId) then
		self:AttachHeldItemToRig(rigModel, toolId)
		return
	end

	-- Check for block
	local selectedBlock = GameState:Get("voxelWorld.selectedBlock")
	local blockId = selectedBlock and selectedBlock.id
	if blockId and blockId > 0 then
		self:AttachHeldItemToRig(rigModel, blockId)
		return
	end
end

-- Legacy alias for compatibility
function VoxelInventoryPanel:RefreshArmorTool()
	self:RefreshArmorHeldItem()
end

function VoxelInventoryPanel:CreateArmorSkeleton(parent)
	for _, child in ipairs(parent:GetChildren()) do
		child:Destroy()
	end

	-- Section label (matching inventory label style)
	local armorLabel = Instance.new("TextLabel")
	armorLabel.Name = "ArmorLabel"
	armorLabel.Size = UDim2.new(1, 0, 0, INVENTORY_CONFIG.LABEL_HEIGHT)
	armorLabel.BackgroundTransparency = 1
	armorLabel.Font = Enum.Font.Code
	armorLabel.TextSize = LABEL_SIZE
	armorLabel.TextColor3 = Color3.fromRGB(140, 140, 140)  -- Matching inventory label color
	armorLabel.TextXAlignment = Enum.TextXAlignment.Left
	armorLabel.Text = "ARMOR"
	armorLabel.Parent = parent

	FontBinder.apply(armorLabel, CUSTOM_FONT_NAME)

	-- Content area: below heading
	local labelHeight = INVENTORY_CONFIG.LABEL_HEIGHT + INVENTORY_CONFIG.LABEL_SPACING
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -labelHeight)  -- Remaining height after label
	contentArea.Position = UDim2.new(0, 0, 0, labelHeight)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = parent

	-- Calculate content area dimensions
	-- Parent has padding: 12px on all sides
	-- Content area height = parent height - label height - label spacing
	local contentAreaHeight = INVENTORY_CONFIG.BODY_HEIGHT - 24 - labelHeight  -- 24px = 12px padding top + 12px padding bottom
	local contentAreaWidth = INVENTORY_CONFIG.CONTENT_WIDTH - 24  -- 24px = 12px padding left + 12px padding right

	-- Calculate slots container height
	-- Each slot: 56px frame + 4px borders (2px each side) = 60px visual
	-- Spacing between slots: 5px (EQUIPMENT_SPACING)
	-- 4 slots: 4 * 60px + 3 * 5px = 240px + 15px = 255px total height
	local slotVisualSize = INVENTORY_CONFIG.EQUIPMENT_SLOT_SIZE + 4  -- 56px + 4px borders = 60px
	local numSlots = 4
	local slotSpacing = INVENTORY_CONFIG.EQUIPMENT_SPACING + 2  -- Added 2px extra gap for armor column
	local baseSlotsHeight = 248

	-- Create vertical transparent frame for armor slots
	local slotsContainer = Instance.new("Frame")
	slotsContainer.Name = "ArmorSlots"
	slotsContainer.Size = UDim2.new(0, slotVisualSize, 0, baseSlotsHeight)  -- Fixed width and calculated height
	slotsContainer.BackgroundTransparency = 1
	slotsContainer.AnchorPoint = Vector2.new(0, 0.5)  -- Left-center anchor for vertical centering
	slotsContainer.Parent = contentArea

	local slotsLayout = Instance.new("UIListLayout")
	slotsLayout.FillDirection = Enum.FillDirection.Vertical
	-- Keep spacing in sync with inventory config so armor slots match inventory gaps
	slotsLayout.Padding = UDim.new(0, slotSpacing)
	slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	slotsLayout.Parent = slotsContainer

	-- Create character viewmodel frame with same height
	local gap = 8  -- Gap between slots and viewmodel
	local viewmodelWidth = math.min(200, contentAreaWidth - slotVisualSize - gap)  -- Reasonable max width, but don't exceed available space
	local VIEWMODEL_HEIGHT = 248

	local totalWidth = slotVisualSize + gap + viewmodelWidth
	local startX = (contentAreaWidth - totalWidth) / 2

	local armorColumn = Instance.new("Frame")
	armorColumn.Name = "ArmorColumn"
	armorColumn.Size = UDim2.new(0, totalWidth, 0, math.max(baseSlotsHeight, VIEWMODEL_HEIGHT))
	armorColumn.Position = UDim2.new(0, startX, 0.5, 0)
	armorColumn.AnchorPoint = Vector2.new(0, 0.5)
	armorColumn.BackgroundTransparency = 1
	armorColumn.Parent = contentArea

	local viewmodelContainer = Instance.new("Frame")
	viewmodelContainer.Name = "ViewmodelContainer"
	viewmodelContainer.Size = UDim2.new(0, viewmodelWidth, 0, VIEWMODEL_HEIGHT)
	viewmodelContainer.BackgroundTransparency = 1
	viewmodelContainer.AnchorPoint = Vector2.new(0, 0.5)
	viewmodelContainer.Parent = armorColumn
	viewmodelContainer.Position = UDim2.new(0, 0, 0.5, 0)

	slotsContainer.Parent = armorColumn
	slotsContainer.Position = UDim2.new(0, viewmodelWidth + gap, 0.5, 0)

	local function refreshArmorColumnHeight()
		local layoutHeight = math.max(baseSlotsHeight, slotsLayout.AbsoluteContentSize.Y)
		slotsContainer.Size = UDim2.new(0, slotVisualSize, 0, layoutHeight)
		local columnHeight = math.max(layoutHeight, VIEWMODEL_HEIGHT)
		armorColumn.Size = UDim2.new(0, totalWidth, 0, columnHeight)
		viewmodelContainer.Size = UDim2.new(0, viewmodelWidth, 0, VIEWMODEL_HEIGHT)
	end

	slotsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refreshArmorColumnHeight)
	refreshArmorColumnHeight()

	-- Create viewport preview for character model
	local player = Players.LocalPlayer

	-- Ensure container is visible
	viewmodelContainer.Visible = true

	self.armorViewmodel = ViewportPreview.new({
		parent = viewmodelContainer,
		name = "ArmorViewmodel",
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.new(0, 0, 0, 0),
		backgroundColor = Color3.fromRGB(31, 31, 31),  -- Matching inventory slot background
		backgroundTransparency = 0.4,  -- 60% opacity (matching inventory)
		borderRadius = 2,  -- Matching inventory corner radius
		rotationSpeed = 20,  -- Slow rotation
		paddingScale = 1.4, -- Slightly more padding (zoomed-out view)
		cameraPitch = math.rad(10), -- Slightly above camera angle
	})

	-- Add border to viewmodel container (matching inventory styling)
	local viewmodelBorder = Instance.new("UIStroke")
	viewmodelBorder.Name = "Border"
	viewmodelBorder.Color = Color3.fromRGB(35, 35, 35)  -- Matching inventory border
	viewmodelBorder.Thickness = 2
	viewmodelBorder.Transparency = 0
	viewmodelBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	viewmodelBorder.Parent = viewmodelContainer

	-- Add background image to viewmodel container (matching inventory)
	local viewmodelBgImage = Instance.new("ImageLabel")
	viewmodelBgImage.Name = "BackgroundImage"
	viewmodelBgImage.Size = UDim2.new(1, 0, 1, 0)
	viewmodelBgImage.Position = UDim2.new(0, 0, 0, 0)
	viewmodelBgImage.BackgroundTransparency = 1
	viewmodelBgImage.Image = "rbxassetid://82824299358542"
	viewmodelBgImage.ImageTransparency = 0.6  -- Matching inventory
	viewmodelBgImage.ScaleType = Enum.ScaleType.Fit
	viewmodelBgImage.ZIndex = 0  -- Behind viewport
	viewmodelBgImage.Parent = viewmodelContainer

	-- Ensure viewport is visible
	if self.armorViewmodel._viewport then
		self.armorViewmodel._viewport.Visible = true
	end

	-- Set the character model in the viewport
	-- Store as method so it can be called when inventory opens
	self.updateArmorViewmodel = function()
		if not self.armorViewmodel then return end

		-- Verify viewport is initialized
		if not self.armorViewmodel._world then
			warn("ArmorViewmodel: Viewport not initialized")
			return
		end

		-- Build character rig using robust method
		local rig = CharacterRigBuilder.BuildCharacterRig(player)
		if not rig then
			warn("ArmorViewmodel: Failed to build character rig")
			return
		end

		-- Verify viewport still exists
		if not self.armorViewmodel or not self.armorViewmodel._world then
			rig:Destroy()
			return
		end

		-- Set the rig in the viewport
		self:ClearArmorTool()
		self.armorViewmodel:SetModel(rig)

		-- Ensure PrimaryPart is set correctly
		local clonedModel = self.armorViewmodel._model
		if clonedModel then
			local clonedRootPart = clonedModel:FindFirstChild("HumanoidRootPart")
			if clonedRootPart then
				clonedModel.PrimaryPart = clonedRootPart

				-- Remove accessories/hats from viewmodel (matching in-game character behavior)
				for _, child in ipairs(clonedModel:GetChildren()) do
					if child:IsA("Accessory") then
						child:Destroy()
					end
				end

				-- Apply Minecraft-style character scaling (narrower limbs, slightly taller)
				CharacterRigBuilder.ApplyMinecraftScale(clonedModel)

				CharacterRigBuilder.ApplyIdlePose(clonedModel)

				-- Apply equipped armor visuals to the viewmodel
				CharacterRigBuilder.ApplyArmorVisuals(clonedModel, self.equippedArmor)

				self.armorViewmodel:_refit()
				self:RefreshArmorTool()
			end
		end

		-- Enable mouse tracking (Minecraft-style look at mouse)
		self.armorViewmodel:SetMouseTracking(true)
	end

	-- Try to set immediately (doesn't require character to exist)
	task.spawn(self.updateArmorViewmodel)

	-- Update viewmodel when character spawns/respawns (to refresh appearance)
	local characterAddedConnection = player.CharacterAdded:Connect(function()
		task.spawn(self.updateArmorViewmodel)
	end)
	table.insert(self.connections, characterAddedConnection)

	if not self.armorScaleListener then
		local scaleListenerDisconnect = UIScaler:RegisterScaleListener(function()
			if self.armorViewmodel and self.armorViewmodel._refit then
				self.armorViewmodel:_refit()
			end
		end)
		if scaleListenerDisconnect then
			self.armorScaleListener = {
				Disconnect = scaleListenerDisconnect
			}
			table.insert(self.connections, self.armorScaleListener)
		end
	end

	-- Unified held item listeners (tools AND blocks)
	if not self.armorHeldItemListeners then
		self.armorHeldItemListeners = {}

		-- Tool ID changes
		local toolListenerDisconnect = GameState:OnPropertyChanged("voxelWorld.selectedToolItemId", function()
			self:RefreshArmorHeldItem()
		end)
		if toolListenerDisconnect then
			table.insert(self.armorHeldItemListeners, { Disconnect = toolListenerDisconnect })
		end

		-- Tool hold state changes
		local holdingToolListenerDisconnect = GameState:OnPropertyChanged("voxelWorld.isHoldingTool", function()
			self:RefreshArmorHeldItem()
		end)
		if holdingToolListenerDisconnect then
			table.insert(self.armorHeldItemListeners, { Disconnect = holdingToolListenerDisconnect })
		end

		-- Block selection changes
		local blockListenerDisconnect = GameState:OnPropertyChanged("voxelWorld.selectedBlock", function()
			self:RefreshArmorHeldItem()
		end)
		if blockListenerDisconnect then
			table.insert(self.armorHeldItemListeners, { Disconnect = blockListenerDisconnect })
		end

		-- Block hold state changes
		local holdingItemListenerDisconnect = GameState:OnPropertyChanged("voxelWorld.isHoldingItem", function()
			self:RefreshArmorHeldItem()
		end)
		if holdingItemListenerDisconnect then
			table.insert(self.armorHeldItemListeners, { Disconnect = holdingItemListenerDisconnect })
		end

		-- Add all to connections for cleanup
		for _, listener in ipairs(self.armorHeldItemListeners) do
			table.insert(self.connections, listener)
		end
	end

	local equipmentTypes = {"Head", "Chest", "Leggings", "Boots"}
	for i, equipmentType in ipairs(equipmentTypes) do
		self:CreateEquipmentSlot(i, equipmentType, slotsContainer)
	end
end

function VoxelInventoryPanel:CreateInventoryColumn(parent)
	-- Inventory column: frame size (borders are outer)
	-- Visual size per slot = 56 (frame) + 4 (2px border on each side) = 60px
	-- Gap between slots = 9px
	local borderThickness = 2
	local visualSlotSize = INVENTORY_CONFIG.SLOT_SIZE + borderThickness * 2  -- 60px
	local slotWidth = visualSlotSize * INVENTORY_CONFIG.COLUMNS +
	                  INVENTORY_CONFIG.SLOT_SPACING * (INVENTORY_CONFIG.COLUMNS - 1)
	local storageHeight = visualSlotSize * INVENTORY_CONFIG.ROWS +
	                      INVENTORY_CONFIG.SLOT_SPACING * (INVENTORY_CONFIG.ROWS - 1)
	local hotbarHeight = visualSlotSize

	local columnWidth = INVENTORY_CONFIG.INVENTORY_WIDTH  -- 592 frame width
	local columnHeight = INVENTORY_CONFIG.BODY_HEIGHT  -- 356 frame height
	local shadowHeight = 18

	-- Calculate position: MENU_WIDTH + gap + CONTENT visual width + gap
	-- Content visual width = CONTENT_WIDTH + 6 (402 + 6 = 408)
	local contentVisualWidth = INVENTORY_CONFIG.CONTENT_WIDTH + 6
	local columnX = INVENTORY_CONFIG.MENU_WIDTH + INVENTORY_CONFIG.CONTENT_MARGIN + contentVisualWidth + INVENTORY_CONFIG.CONTENT_MARGIN

	-- Inventory column: 592x356 frame (598x362 visual with borders)
	local column = Instance.new("Frame")
	column.Name = "InventoryColumn"
	column.Size = UDim2.new(0, columnWidth, 0, columnHeight)
	column.Position = UDim2.new(0, columnX + 3, 0, 3)  -- 3px offset for border
	column.BackgroundColor3 = INVENTORY_CONFIG.INVENTORY_BG_COLOR
	column.BackgroundTransparency = 0
	column.BorderSizePixel = 0
	column.ZIndex = 1
	column.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = column

	-- Shadow: decorative border shadow (positioned at bottom)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.new(0, columnWidth, 0, shadowHeight)
	shadow.AnchorPoint = Vector2.new(0, 0.5)  -- Left-center vertically
	-- Position: 3px border offset horizontally, at column bottom (centered vertically)
	-- Column bottom is at: 3 (top) + 356 (height) = 359px from body top
	shadow.Position = UDim2.new(0, columnX + 3, 0, columnHeight + 3)  -- 3px border, at bottom edge
	shadow.BackgroundColor3 = INVENTORY_CONFIG.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0  -- Behind column
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	-- Inner border: 3px white at 20% transparency
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = INVENTORY_CONFIG.BORDER_COLOR
	border.Thickness = 3
	border.Parent = column

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = column

	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Padding = UDim.new(0, INVENTORY_CONFIG.LABEL_SPACING)
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Left
	stack.Parent = column

	local invLabel = Instance.new("TextLabel")
	invLabel.Name = "InventoryLabel"
	invLabel.Size = UDim2.new(1, 0, 0, INVENTORY_CONFIG.LABEL_HEIGHT)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = Enum.Font.Code
	invLabel.TextSize = LABEL_SIZE
	invLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	invLabel.TextXAlignment = Enum.TextXAlignment.Left
	invLabel.Text = "INVENTORY"
	invLabel.Parent = column

	FontBinder.apply(invLabel, CUSTOM_FONT_NAME)

	local inventorySlotsFrame = Instance.new("Frame")
	inventorySlotsFrame.Name = "InventorySlots"
	inventorySlotsFrame.Size = UDim2.new(1, 0, 0, storageHeight)
	inventorySlotsFrame.BackgroundTransparency = 1
	inventorySlotsFrame.Parent = column

	local slotSpacing = INVENTORY_CONFIG.SLOT_SPACING
	local borderThickness = 2  -- 2px border on each side
	-- Visual size = frame size + 2 borders = 56 + 4 = 60px
	-- Position calculation: frame position = col * (visual size + gap between borders)
	for row = 0, INVENTORY_CONFIG.ROWS - 1 do
		for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
			local index = row * INVENTORY_CONFIG.COLUMNS + col + 1
			-- Visual size (60px) + gap (5px) = 65px per slot
			local x = col * (INVENTORY_CONFIG.SLOT_SIZE + borderThickness * 2 + slotSpacing)
			local y = row * (INVENTORY_CONFIG.SLOT_SIZE + borderThickness * 2 + slotSpacing)
			self:CreateInventorySlot(index, inventorySlotsFrame, x, y)
		end
	end

	local hotbarLabel = Instance.new("TextLabel")
	hotbarLabel.Name = "HotbarLabel"
	hotbarLabel.Size = UDim2.new(1, 0, 0, INVENTORY_CONFIG.LABEL_HEIGHT)
	hotbarLabel.BackgroundTransparency = 1
	hotbarLabel.Font = Enum.Font.Code
	hotbarLabel.TextSize = LABEL_SIZE
	hotbarLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
	hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
	hotbarLabel.Text = "HOTBAR"
	hotbarLabel.Parent = column

	FontBinder.apply(hotbarLabel, CUSTOM_FONT_NAME)

	local hotbarFrame = Instance.new("Frame")
	hotbarFrame.Name = "HotbarSlots"
	hotbarFrame.Size = UDim2.new(1, 0, 0, hotbarHeight)
	hotbarFrame.BackgroundTransparency = 1
	hotbarFrame.Parent = column

	local borderThickness = 2  -- 2px border on each side
	-- Visual size = frame size + 2 borders = 56 + 4 = 60px
	-- Position calculation: frame position = col * (visual size + gap between borders)
	for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
		local x = col * (INVENTORY_CONFIG.SLOT_SIZE + borderThickness * 2 + slotSpacing)
		self:CreateHotbarSlot(col + 1, hotbarFrame, x, 0)
	end
end

function VoxelInventoryPanel:SetActiveSection(section)
	self.activeSection = section

	for name, button in pairs(self.sectionButtons or {}) do
		if button then
			local isActive = name == section
			-- Keep background fully opaque with 58,58,58 color
			button.BackgroundTransparency = 0
			button.BackgroundColor3 = INVENTORY_CONFIG.NAV_BG_COLOR
			local icon = button:FindFirstChild("Icon")
			if icon then
				icon.ImageColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(185, 185, 195)
			end
		end
	end

	if self.craftSection then
		self.craftSection.Visible = section == "craft"
	end

	if self.armorSection then
		self.armorSection.Visible = section == "armor"
	end
end

function VoxelInventoryPanel:CreateInventorySlot(index, parent, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "InventorySlot" .. index
	slot.Size = UDim2.new(0, 56, 0, 56)  -- Frame size (visual is 60px with 2px border)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	slot.BackgroundTransparency = 0.4  -- 60% opacity
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = parent or self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Background image at 50% opacity
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- 50% opacity
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)
	border.Thickness = 2
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

	-- Create container for viewport - fills entire slot
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image (ZIndex 1)
	iconContainer.Parent = slot

	-- Count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = MIN_TEXT_SIZE
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5 -- Above viewport and background
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
		-- Show item name in top left
		local stack = self.inventoryManager:GetInventorySlot(index)
		if stack and not stack:IsEmpty() then
			self:ShowHoverItemName(stack:GetItemId())
		end
	end)

	slot.MouseLeave:Connect(function()
		-- Hide border when not hovering
		hoverBorder.Transparency = 1
		-- Restore background
		slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
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

function VoxelInventoryPanel:CreateHotbarSlot(index, parent, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "HotbarSlot" .. index
	slot.Size = UDim2.new(0, 56, 0, 56)  -- Frame size (visual is 60px with 2px border)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	slot.BackgroundTransparency = 0.4  -- 60% opacity
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = parent or self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Background image at 50% opacity
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- 50% opacity
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)
	border.Thickness = 2
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

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
	iconContainer.ZIndex = 3  -- Above background image (ZIndex 1)
	iconContainer.Parent = slot

	-- Count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = MIN_TEXT_SIZE
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 5 -- Above viewport and background
	countLabel.Parent = slot

	local numberLabel = Instance.new("TextLabel")
	numberLabel.Name = "Number"
	numberLabel.Size = UDim2.new(0, 20, 0, 20)
	numberLabel.Position = UDim2.new(0, 4, 0, 4)
	numberLabel.BackgroundTransparency = 1
	numberLabel.Font = BOLD_FONT
	numberLabel.TextSize = MIN_TEXT_SIZE
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
		selectionBorder = selectionBorder
	}

	-- Hover effect - show border and highlight when dragging items
	slot.MouseEnter:Connect(function()
		-- Show hover border (unless selection border is active)
		if self.hotbar and self.hotbar.selectedSlot ~= index then
			hoverBorder.Transparency = 0.5
		end
		-- Lighten background
		slot.BackgroundColor3 = INVENTORY_CONFIG.HOVER_COLOR
		-- Show item name in top left
		if self.hotbar then
			local stack = self.hotbar.slots[index]
			if stack and not stack:IsEmpty() then
				self:ShowHoverItemName(stack:GetItemId())
			end
		end
	end)

	slot.MouseLeave:Connect(function()
		-- Hide hover border
		hoverBorder.Transparency = 1
		-- Restore background
		slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		-- Hide item name
		self:HideHoverItemName()
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

function VoxelInventoryPanel:CreateEquipmentSlot(index, equipmentType, parent)
	local slot = Instance.new("TextButton")
	slot.Name = "EquipmentSlot" .. equipmentType
	slot.Size = UDim2.new(0, 56, 0, 56)  -- Frame size (visual is 60px with 2px border)
	slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	slot.BackgroundTransparency = 0.4  -- 60% opacity
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = parent or self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Background image at 50% opacity
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- 50% opacity
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)
	border.Thickness = 2
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

	-- Create container for viewport - slightly inset for padding
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -6, 1, -6)  -- 3px padding on all sides
	iconContainer.Position = UDim2.new(0, 3, 0, 3)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image (ZIndex 1)
	iconContainer.Parent = slot

	-- Equipment type icon/label (when empty)
	local typeLabel = Instance.new("TextLabel")
	typeLabel.Name = "TypeLabel"
	typeLabel.Size = UDim2.new(1, 0, 1, 0)
	typeLabel.BackgroundTransparency = 1
	typeLabel.Font = Enum.Font.Code
	typeLabel.TextSize = LABEL_SIZE
	typeLabel.TextColor3 = Color3.fromRGB(100, 100, 120)  -- More subtle
	typeLabel.Text = string.upper(equipmentType)
	typeLabel.TextXAlignment = Enum.TextXAlignment.Center
	typeLabel.TextYAlignment = Enum.TextYAlignment.Center
	typeLabel.ZIndex = 2
	typeLabel.Parent = slot

	FontBinder.apply(typeLabel, CUSTOM_FONT_NAME)

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
		-- Show item name in top left for equipped armor
		local equippedItemId = self.equippedArmor[equipmentType]
		if equippedItemId then
			self:ShowHoverItemName(equippedItemId)
		end
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
		-- Hide item name
		self:HideHoverItemName()
	end)

	-- Click handlers for armor equipping
	slot.MouseButton1Click:Connect(function()
		self:OnEquipmentSlotLeftClick(index, equipmentType)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnEquipmentSlotRightClick(index, equipmentType)
	end)
end

function VoxelInventoryPanel:CreateCursorItem()
	-- Item that follows cursor when dragging
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.new(0, 56, 0, 56)  -- Frame size (visual is 60px with 2px border)
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

	-- Border (matching slot styling)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)
	border.Thickness = 2
	border.Transparency = 0.5
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = self.cursorFrame

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
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = MIN_TEXT_SIZE
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
				local itemDef = ItemRegistry.GetItem(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = itemDef and itemDef.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
			elseif ArmorConfig.IsArmor(itemId) then
				local info = ArmorConfig.GetArmorInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ArmorImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				-- Tint base image for leather armor (base is tintable)
				if info and info.imageOverlay then
					image.ImageColor3 = ArmorConfig.GetTierColor(info.tier)
				end
				image.Parent = slotFrame.iconContainer
				-- Add overlay for leather armor (overlay shows untinted details)
				if info and info.imageOverlay then
					local overlay = Instance.new("ImageLabel")
					overlay.Name = "ArmorOverlay"
					overlay.Size = UDim2.new(1, -6, 1, -6)
					overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
					overlay.AnchorPoint = Vector2.new(0.5, 0.5)
					overlay.BackgroundTransparency = 1
					overlay.Image = info.imageOverlay
					overlay.ScaleType = Enum.ScaleType.Fit
					overlay.ZIndex = 4
					overlay.Parent = slotFrame.iconContainer
				end
			elseif SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
				icon.Position = UDim2.new(0.5, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = slotFrame.iconContainer
			elseif BlockRegistry:IsBucket(itemId) or BlockRegistry:IsPlaceable(itemId) == false then
				-- Render non-placeable items (buckets, etc.) as 2D images
				local blockDef = BlockRegistry:GetBlock(itemId)
				local textureId = blockDef and blockDef.textures and blockDef.textures.all or ""
				
				local image = Instance.new("ImageLabel")
				image.Name = "ItemImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = textureId
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
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
				local itemDef = ItemRegistry.GetItem(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = itemDef and itemDef.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = iconContainer
			elseif ArmorConfig.IsArmor(itemId) then
				local info = ArmorConfig.GetArmorInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ArmorImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				-- Tint base image for leather armor
				if info and info.imageOverlay then
					image.ImageColor3 = ArmorConfig.GetTierColor(info.tier)
				end
				image.Parent = iconContainer
				-- Add overlay for leather armor (untinted details)
				if info and info.imageOverlay then
					local overlay = Instance.new("ImageLabel")
					overlay.Name = "ArmorOverlay"
					overlay.Size = UDim2.new(1, -6, 1, -6)
					overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
					overlay.AnchorPoint = Vector2.new(0.5, 0.5)
					overlay.BackgroundTransparency = 1
					overlay.Image = info.imageOverlay
					overlay.ScaleType = Enum.ScaleType.Fit
					overlay.ZIndex = 4
					overlay.Parent = iconContainer
				end
			elseif SpawnEggConfig.IsSpawnEgg(itemId) then
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
				icon.Position = UDim2.new(0.5, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = iconContainer
			elseif BlockRegistry:IsBucket(itemId) or BlockRegistry:IsPlaceable(itemId) == false then
				-- Render non-placeable items (buckets, etc.) as 2D images
				local blockDef = BlockRegistry:GetBlock(itemId)
				local textureId = blockDef and blockDef.textures and blockDef.textures.all or ""
				
				local image = Instance.new("ImageLabel")
				image.Name = "ItemImage"
				image.Size = UDim2.new(1, -6, 1, -6)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = textureId
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = iconContainer
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
		local slotFrame = self.hotbarSlotFrames[i]
		if slotFrame and slotFrame.frame then
			self:UpdateHotbarSlotDisplay(i, slotFrame.frame, slotFrame.iconContainer, slotFrame.countLabel, slotFrame.selectionBorder)
		end
	end

	-- Update equipment/armor slots
	for i = 1, 4 do
		self:UpdateEquipmentSlotDisplay(i)
	end

	-- Update cursor item
	self:UpdateCursorDisplay()
end

-- Map slot index to armor slot name
local SLOT_INDEX_TO_ARMOR = {
	[1] = "helmet",
	[2] = "chestplate",
	[3] = "leggings",
	[4] = "boots"
}

function VoxelInventoryPanel:UpdateEquipmentSlotDisplay(index)
	local slotData = self.equipmentSlotFrames[index]
	if not slotData then return end

	local armorSlot = SLOT_INDEX_TO_ARMOR[index]
	if not armorSlot then return end

	local equippedItemId = self.equippedArmor[armorSlot]
	local iconContainer = slotData.iconContainer
	local typeLabel = slotData.typeLabel

	-- Clear existing visuals (except layout elements)
	for _, child in ipairs(iconContainer:GetChildren()) do
		if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
			child:Destroy()
		end
	end

	if equippedItemId then
		-- Show equipped armor
		local armorInfo = ArmorConfig.GetArmorInfo(equippedItemId)
		if armorInfo and armorInfo.image then
			local image = Instance.new("ImageLabel")
			image.Name = "ArmorImage"
			image.Size = UDim2.new(1, 0, 1, 0)
			image.Position = UDim2.new(0.5, 0, 0.5, 0)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.Image = armorInfo.image
			image.ScaleType = Enum.ScaleType.Fit
			image.ZIndex = 4
			-- Tint base image for leather armor
			if armorInfo.imageOverlay then
				image.ImageColor3 = ArmorConfig.GetTierColor(armorInfo.tier)
			end
			image.Parent = iconContainer

			-- Add overlay for leather armor (untinted details)
			if armorInfo.imageOverlay then
				local overlay = Instance.new("ImageLabel")
				overlay.Name = "ArmorOverlay"
				overlay.Size = UDim2.new(1, 0, 1, 0)
				overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
				overlay.AnchorPoint = Vector2.new(0.5, 0.5)
				overlay.BackgroundTransparency = 1
				overlay.Image = armorInfo.imageOverlay
				overlay.ScaleType = Enum.ScaleType.Fit
				overlay.ZIndex = 5
				overlay.Parent = iconContainer
			end
		end

		-- Hide type label when armor is equipped
		if typeLabel then
			typeLabel.Visible = false
		end
	else
		-- Show type label when empty
		if typeLabel then
			typeLabel.Visible = true
		end
	end
end

function VoxelInventoryPanel:UpdateAllEquipmentSlots()
	for i = 1, 4 do
		self:UpdateEquipmentSlotDisplay(i)
	end
	-- Update the character viewmodel armor (incremental update, not full rebuild)
	self:RefreshViewmodelArmor()
end

-- Refresh only the armor visuals on the viewmodel (more efficient than full rebuild)
function VoxelInventoryPanel:RefreshViewmodelArmor()
	if not self.armorViewmodel or not self.armorViewmodel._model then return end

	local clonedModel = self.armorViewmodel._model
	if clonedModel then
		-- Clear existing armor and re-apply with current equipped armor
		CharacterRigBuilder.ClearArmorVisuals(clonedModel)
		CharacterRigBuilder.ApplyArmorVisuals(clonedModel, self.equippedArmor)
	end
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
			local slotFrame = self.hotbarSlotFrames[i]
			if slotFrame and slotFrame.frame then
				local stack = self.hotbar:GetSlot(i)
				local cachedItemId = slotFrame.frame:GetAttribute("CurrentItemId")
				local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

				-- Update if item ID changed
				if cachedItemId ~= actualItemId then
					-- Item changed (including nil -> item, item -> nil, or item A -> item B)
					self:UpdateHotbarSlotDisplay(i, slotFrame.frame, slotFrame.iconContainer, slotFrame.countLabel, slotFrame.selectionBorder)
				elseif actualItemId and stack then
					-- Same item, just update count (cheap operation)
					if slotFrame.countLabel then
						slotFrame.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
					end
					-- Also update selection border in case selection changed
					if slotFrame.selectionBorder then
						if self.hotbar.selectedSlot == i then
							slotFrame.selectionBorder.Transparency = 0
						else
							slotFrame.selectionBorder.Transparency = 1
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
					local itemDef = ItemRegistry.GetItem(itemId)
					local image = Instance.new("ImageLabel")
					image.Name = "ToolImage"
					image.Size = UDim2.new(1, -6, 1, -6)
					image.Position = UDim2.new(0.5, 0, 0.5, 0)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundTransparency = 1
					image.Image = itemDef and itemDef.image or ""
					image.ScaleType = Enum.ScaleType.Fit
					image.ZIndex = 1001
					image.Parent = iconContainer
				elseif ArmorConfig.IsArmor(itemId) then
					local info = ArmorConfig.GetArmorInfo(itemId)
					local image = Instance.new("ImageLabel")
					image.Name = "ArmorImage"
					image.Size = UDim2.new(1, -6, 1, -6)
					image.Position = UDim2.new(0.5, 0, 0.5, 0)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundTransparency = 1
					image.Image = info and info.image or ""
					image.ScaleType = Enum.ScaleType.Fit
					image.ZIndex = 1001
					-- Tint base image for leather armor
					if info and info.imageOverlay then
						image.ImageColor3 = ArmorConfig.GetTierColor(info.tier)
					end
					image.Parent = iconContainer
					-- Add overlay for leather armor (untinted details)
					if info and info.imageOverlay then
						local overlay = Instance.new("ImageLabel")
						overlay.Name = "ArmorOverlay"
						overlay.Size = UDim2.new(1, -6, 1, -6)
						overlay.Position = UDim2.new(0.5, 0, 0.5, 0)
						overlay.AnchorPoint = Vector2.new(0.5, 0.5)
						overlay.BackgroundTransparency = 1
						overlay.Image = info.imageOverlay
						overlay.ScaleType = Enum.ScaleType.Fit
						overlay.ZIndex = 1002
						overlay.Parent = iconContainer
					end
				elseif SpawnEggConfig.IsSpawnEgg(itemId) then
					local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -6, 1, -6))
					icon.Position = UDim2.new(0.5, 0, 0.5, 0)
					icon.AnchorPoint = Vector2.new(0.5, 0.5)
					icon.ZIndex = 1001
					icon.Parent = iconContainer
				elseif BlockRegistry:IsBucket(itemId) or BlockRegistry:IsPlaceable(itemId) == false then
					-- Render non-placeable items (buckets, etc.) as 2D images
					local blockDef = BlockRegistry:GetBlock(itemId)
					local textureId = blockDef and blockDef.textures and blockDef.textures.all or ""
					
					local image = Instance.new("ImageLabel")
					image.Name = "ItemImage"
					image.Size = UDim2.new(1, -6, 1, -6)
					image.Position = UDim2.new(0.5, 0, 0.5, 0)
					image.AnchorPoint = Vector2.new(0.5, 0.5)
					image.BackgroundTransparency = 1
					image.Image = textureId
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
	local slotFrame = self.hotbarSlotFrames[index]
	if slotFrame and slotFrame.frame then
		self:UpdateHotbarSlotDisplay(index, slotFrame.frame, slotFrame.iconContainer, slotFrame.countLabel, slotFrame.selectionBorder)
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
	local slotFrame = self.hotbarSlotFrames[index]
	if slotFrame and slotFrame.frame then
		self:UpdateHotbarSlotDisplay(index, slotFrame.frame, slotFrame.iconContainer, slotFrame.countLabel, slotFrame.selectionBorder)
	end
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end
end

-- Map equipment types to armor slot names
local EQUIPMENT_TO_ARMOR_SLOT = {
	["Head"] = "helmet",
	["Chest"] = "chestplate",
	["Leggings"] = "leggings",
	["Boots"] = "boots"
}

--- Equipment slot clicks - now handles armor equip/unequip
function VoxelInventoryPanel:OnEquipmentSlotLeftClick(index, equipmentType)
	local armorSlot = EQUIPMENT_TO_ARMOR_SLOT[equipmentType]
	if not armorSlot then
		warn("[ArmorClick] Invalid equipmentType:", equipmentType)
		return
	end

	-- NOTE: Can't use Lua ternary `a and nil or b` because nil is falsy!
	local cursorItemId = nil
	local cursorCount = 0
	if not self.cursorStack:IsEmpty() then
		cursorItemId = self.cursorStack:GetItemId()
		cursorCount = self.cursorStack:GetCount()
	end

	-- Debug: log the current state
	local currentEquippedDebug = self.equippedArmor[armorSlot]
	print(string.format("[ArmorClick] Slot=%s, CurrentEquipped=%s, CursorItem=%s",
		armorSlot,
		tostring(currentEquippedDebug),
		tostring(cursorItemId)))

	-- Validate: if cursor has item, must be compatible armor
	if cursorItemId and cursorItemId > 0 then
		local armorInfo = ArmorConfig.GetArmorInfo(cursorItemId)
		if not armorInfo then
			-- Not armor - can't equip
			print("[ArmorClick] Cursor item is not armor, returning")
			return
		end
		if armorInfo.slot ~= armorSlot then
			-- Wrong slot type
			print("[ArmorClick] Wrong slot type, returning")
			return
		end
	end

	-- Get currently equipped armor in this slot
	local currentEquipped = self.equippedArmor[armorSlot]

	-- Perform the swap locally for responsiveness
	if cursorItemId and cursorItemId > 0 then
		-- Cursor has compatible armor - equip it
		self.equippedArmor[armorSlot] = cursorItemId
		if currentEquipped then
			-- Swap: put old armor on cursor
			self.cursorStack = ItemStack.new(currentEquipped, 1)
		else
			-- Just equip: clear cursor
			self.cursorStack = ItemStack.new(0, 0)
		end
	else
		-- Cursor empty - unequip to cursor
		if currentEquipped then
			self.cursorStack = ItemStack.new(currentEquipped, 1)
			self.equippedArmor[armorSlot] = nil
		end
	end

	-- Update displays
	self:UpdateCursorDisplay()
	self:UpdateEquipmentSlotDisplay(index)

	-- Send to server for authoritative handling
	EventManager:SendToServer("ArmorSlotClick", {
		slot = equipmentType,
		cursorItemId = cursorItemId,
		cursorCount = cursorCount
	})

	-- CRITICAL: Sync inventory to server after armor equip
	-- The item was picked up from inventory (emptying a slot), but that change
	-- hasn't been synced yet. We must sync now that the transaction is complete.
	if self.cursorStack:IsEmpty() then
		self.inventoryManager:SendUpdateToServer()
	end

	playInventoryPopSound()
end

function VoxelInventoryPanel:OnEquipmentSlotRightClick(index, equipmentType)
	-- Right-click on equipment slot: same as left click for now (armor doesn't stack)
	self:OnEquipmentSlotLeftClick(index, equipmentType)
end

-- Send inventory update to server (deprecated - use inventoryManager)
function VoxelInventoryPanel:SendInventoryUpdateToServer()
	-- Delegate to inventory manager
	self.inventoryManager:SendUpdateToServer()
end

function VoxelInventoryPanel:UpdateCursorPosition()
	if not self.cursorFrame.Visible then return end

	local mousePos = InputService:GetMouseLocation()

	-- Cursor ScreenGui has IgnoreGuiInset=true, so use raw mouse position
	-- AnchorPoint of 0.5,0.5 centers the cursor frame on this position
	self.cursorFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y)
end

function VoxelInventoryPanel:BindInput()
	-- Only handle Escape here; E is handled centrally in GameClient to avoid conflicts
	self.connections[#self.connections + 1] = InputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
			self:Close()
		end
	end)

	-- Drop item when clicking outside inventory
	self.connections[#self.connections + 1] = InputService.InputBegan:Connect(function(input, gpe)
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
			playInventoryPopSound()
			-- Clear cursor locally
			self.cursorStack = ItemStack.new(0, 0)
			self:UpdateCursorDisplay()
		end
	end)
end

function VoxelInventoryPanel:Open()
	if self.isOpen then return end
	if self.isAnimating then return end

	-- Cancel any existing animation
	if self.currentTween then
		self.currentTween:Cancel()
		self.currentTween = nil
	end

	-- NOTE: Do NOT call _acquireOverlay() here - UIVisibilityManager handles cursor unlock
	-- Having both creates a double-push that causes toggle flip bugs

	-- Use UIVisibilityManager to coordinate all UI (this handles cursor unlock)
	UIVisibilityManager:SetMode("inventory")

	self.isOpen = true
	self.isAnimating = true
	self.gui.Enabled = true

	-- Reset crafting UI state on open so overview shows first
	if self.craftingPanel and self.craftingPanel.OnPanelOpen then
		pcall(function()
			self.craftingPanel:OnPanelOpen()
		end)
	end

	-- Update all displays
	self:UpdateAllDisplays()

	-- Update armor viewmodel when inventory opens
	if self.updateArmorViewmodel then
		task.spawn(self.updateArmorViewmodel)
	end

	-- Enable mouse tracking on viewmodel when inventory opens
	if self.armorViewmodel then
		self.armorViewmodel:SetMouseTracking(true)
	end

	-- Start updating cursor position
	self.renderConnection = RunService.RenderStepped:Connect(function()
		if self.isOpen then
			self:UpdateCursorPosition()
		end
	end)

	-- Animate in: Grow from top with smooth bounce effect
	local startHeight = INVENTORY_CONFIG.HEADER_HEIGHT
	local finalHeight = INVENTORY_CONFIG.HEADER_HEIGHT + INVENTORY_CONFIG.BODY_HEIGHT
	local finalWidth = INVENTORY_CONFIG.TOTAL_WIDTH

	-- Set initial state: small at top (just header visible)
	-- Use center anchor throughout for consistent positioning
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.Size = UDim2.new(0, finalWidth, 0, startHeight)
	-- Start position: top of screen (0 scale) with small offset, accounting for center anchor
	self.panel.Position = UDim2.new(0.5, 0, 0, 60 + startHeight * 0.5)
	self.panel.BackgroundTransparency = 1

	-- Animate: grow size and move to final position
	-- Final position: centered vertically (0.5 scale) offset upward by header height
	-- Very smooth and fast animation
	self.currentTween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0, finalWidth, 0, finalHeight),
			Position = UDim2.new(0.5, 0, 0.5, -INVENTORY_CONFIG.HEADER_HEIGHT)
		}
	)

	self.currentTween:Play()
	self.currentTween.Completed:Connect(function()
		self.isAnimating = false
		self.currentTween = nil
	end)
end

function VoxelInventoryPanel:IsClosing()
	return self.isAnimating and not self.isOpen
end

function VoxelInventoryPanel:SetPendingCloseMode(mode)
	if self:IsClosing() then
		self.pendingCloseMode = mode or "gameplay"
	end
end

function VoxelInventoryPanel:Close(nextMode)
	local targetMode = nextMode or "gameplay"
	self.pendingCloseMode = targetMode

	if self:IsClosing() then
		return
	end
	if not self.isOpen then return end

	-- Hide hover item name when closing
	self:HideHoverItemName()

	-- Cancel any existing animation
	if self.currentTween then
		self.currentTween:Cancel()
		self.currentTween = nil
	end

	self.isAnimating = true

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
			playInventoryPopSound()
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

	-- Disable mouse tracking on viewmodel
	if self.armorViewmodel then
		self.armorViewmodel:SetMouseTracking(false)
	end

	-- Stop updating cursor
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Note: CameraController now manages mouse lock dynamically based on camera mode
	-- (first person = locked, third person = free)

	-- Animate out: Shrink upward to top
	local startHeight = INVENTORY_CONFIG.HEADER_HEIGHT
	local finalWidth = INVENTORY_CONFIG.TOTAL_WIDTH
	-- Target position matches open animation start: top with offset accounting for center anchor
	local targetPositionY = 60 + startHeight * 0.5

	-- Animate: shrink size and move to top
	-- Very smooth and fast close animation
	self.currentTween = TweenService:Create(
		self.panel,
		TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.In),
		{
			Size = UDim2.new(0, finalWidth, 0, startHeight),
			Position = UDim2.new(0.5, 0, 0, targetPositionY)
		}
	)

	self.currentTween:Play()
	self.currentTween.Completed:Connect(function()
		self.isAnimating = false
		self.currentTween = nil
		self.gui.Enabled = false

		-- Reset workbench mode after UI is hidden to avoid visible title flicker
		if self.isWorkbenchMode then
			self:SetWorkbenchMode(false)
		end

		-- NOTE: Do NOT call _releaseOverlay() here - UIVisibilityManager handles cursor lock
		-- Having both creates a double-pop that causes toggle flip bugs
		UIVisibilityManager:SetMode(self.pendingCloseMode or "gameplay")
	end)
end

function VoxelInventoryPanel:Toggle()
	-- Prevent rapid toggling during animations
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

-- Show method (called by UIVisibilityManager)
function VoxelInventoryPanel:Show()
	if not self.gui then return end
	self.gui.Enabled = true
end

-- Hide method (called by UIVisibilityManager)
function VoxelInventoryPanel:Hide()
	if not self.gui then return end
	self.gui.Enabled = false
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
			self.titleLabel.Text = "WORKBENCH"
		else
			self.titleLabel.Text = "INVENTORY"
		end
	end

end

function VoxelInventoryPanel:Cleanup()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}
	self.armorScaleListener = nil
	self.armorToolListener = nil
	self.armorHoldingToolListener = nil
	self:ClearArmorTool()

	if self.renderConnection then
		self.renderConnection:Disconnect()
	end

	self:_releaseOverlay()

	if self.armorViewmodel then
		self.armorViewmodel:Destroy()
		self.armorViewmodel = nil
	end

	if self.gui then
		self.gui:Destroy()
	end
end

return VoxelInventoryPanel
