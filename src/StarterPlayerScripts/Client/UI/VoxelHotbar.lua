--[[
	VoxelHotbar.lua
	Minecraft-style hotbar for block/item selection
	9-slot toolbar at bottom of screen with number key selection
	Supports stacking (64 max) and drag-and-drop
]]

local Players = game:GetService("Players")
local InputService = require(script.Parent.Parent.Input.InputService)
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)
local ItemRegistry = require(ReplicatedStorage.Configs.ItemRegistry)
local SpawnEggIcon = require(script.Parent.SpawnEggIcon)
local Config = require(ReplicatedStorage.Shared.Config)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)

local VoxelHotbar = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
VoxelHotbar.__index = VoxelHotbar

local function playInventoryPopSound()
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("inventoryPop")
	end
end

	-- Hotbar configuration
local HOTBAR_CONFIG = {
	SLOT_COUNT = 9,
	SLOT_SIZE = 56,  -- Frame size (visual size is 60px with 2px border on each side)
	SLOT_SPACING = 5,  -- Gap between slots (between borders)
	INVENTORY_BUTTON_GAP = 8,  -- Gap between hotbar and inventory button
	BOTTOM_OFFSET = 20,
	BORDER_WIDTH = 3,
	SCALE = 0.85,

	-- Colors (matching inventory UI)
	BG_COLOR = Color3.fromRGB(40, 40, 40),
	BG_TRANSPARENCY = 0.3,
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),  -- Matching inventory border color
	SELECTED_COLOR = Color3.fromRGB(220, 220, 220),
	HOVER_COLOR = Color3.fromRGB(100, 100, 100),
}

-- Block metadata (icon, name, etc)
local BLOCK_INFO = {
	[0] = {name = "Empty", icon = "", isItem = false},
	[1] = {name = "Grass Block", icon = "🟩", category = "Natural"},
	[2] = {name = "Dirt", icon = "🟫", category = "Natural"},
	[3] = {name = "Stone", icon = "⬜", category = "Natural"},
	[4] = {name = "Bedrock", icon = "⬛", category = "Special"},
	[5] = {name = "Wood Planks", icon = "🟫", category = "Building"},
	[6] = {name = "Leaves", icon = "🟢", category = "Natural"},
	[7] = {name = "Tall Grass", icon = "🌱", category = "Decoration"},
	[8] = {name = "Flower", icon = "🌸", category = "Decoration"},
	[9] = {name = "Chest", icon = "📦", category = "Storage"},
	[10] = {name = "Sand", icon = "🟨", category = "Natural"},
	[11] = {name = "Stone Bricks", icon = "⬜", category = "Building"},
	[12] = {name = "Oak Planks", icon = "🟫", category = "Building"},
	[13] = {name = "Crafting Table", icon = "🔨", category = "Utility"},
	[14] = {name = "Cobblestone", icon = "⬜", category = "Building"},
	[15] = {name = "Bricks", icon = "🧱", category = "Building"},
	[16] = {name = "Oak Sapling", icon = "🌱", category = "Decoration"},
	[17] = {name = "Oak Stairs", icon = "📐", category = "Building"},
	[18] = {name = "Stone Stairs", icon = "📐", category = "Building"},
	[19] = {name = "Cobblestone Stairs", icon = "📐", category = "Building"},
	[20] = {name = "Stone Brick Stairs", icon = "📐", category = "Building"},
	[21] = {name = "Brick Stairs", icon = "📐", category = "Building"},
	[22] = {name = "Oak Slab", icon = "▬", category = "Building"},
	[23] = {name = "Stone Slab", icon = "▬", category = "Building"},
	[24] = {name = "Cobblestone Slab", icon = "▬", category = "Building"},
	[25] = {name = "Stone Brick Slab", icon = "▬", category = "Building"},
	[26] = {name = "Brick Slab", icon = "▬", category = "Building"},
	[27] = {name = "Oak Fence", icon = "#", category = "Building"},
	[28] = {name = "Stick", icon = "|", category = "Materials"},
	[29] = {name = "Coal Ore", icon = "⚫", category = "Ores"},
	[30] = {name = "Iron Ore", icon = "🔵", category = "Ores"},
	[31] = {name = "Diamond Ore", icon = "💎", category = "Ores"},
	[32] = {name = "Coal", icon = "⚫", category = "Materials"},
	[33] = {name = "Iron Ingot", icon = "⚪", category = "Materials"},
	[34] = {name = "Diamond", icon = "💠", category = "Materials"},
	[35] = {name = "Furnace", icon = "🔥", category = "Utility"},
	[36] = {name = "Glass", icon = "🪟", category = "Building"},
	[97] = {name = "Stone Golem", icon = "🗿", category = "Utility"},
	[123] = {name = "Coal Golem", icon = "⚫", category = "Utility"}
}

function VoxelHotbar.new()
	local self = setmetatable({}, VoxelHotbar)

	self.selectedSlot = 1
	self.slots = {} -- Array of ItemStack objects
	self.slotFrames = {} -- UI frames for each slot
	self.gui = nil
	self.container = nil
	self.inventoryButton = nil
	self.worldButton = nil
	self.voxelInventory = nil -- Reference to inventory panel
	self.worldsPanel = nil -- Reference to worlds panel
	self.connections = {}
	self.uiToggleDebounce = 0.3
	self.lastUiToggleTime = 0

	-- Initialize empty slots
	for i = 1, HOTBAR_CONFIG.SLOT_COUNT do
		self.slots[i] = ItemStack.new(0, 0) -- Empty
	end

	return self
end

function VoxelHotbar:Initialize()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VoxelHotbar"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 50
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Add responsive scaling (100% = original size)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080)) -- 1920x1080 for 100% original size
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create main hotbar container
	self:CreateHotbar()

	-- Bind input
	self:BindInput()

	-- Set initial selection and populate with starter blocks
	self:SetupStarterBlocks()
	self:SelectSlot(1)

	-- Register with UIVisibilityManager
	UIVisibilityManager:RegisterComponent("voxelHotbar", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 5
	})

	return self
end

function VoxelHotbar:CanToggleUI()
	local now = tick()
	if now - self.lastUiToggleTime < self.uiToggleDebounce then
		return false
	end
	self.lastUiToggleTime = now
	return true
end

function VoxelHotbar:SetupStarterBlocks()
	-- Give player some starter blocks (like creative mode)
	self:SetSlot(1, ItemStack.new(1, 64)) -- Grass
	self:SetSlot(2, ItemStack.new(2, 64)) -- Dirt
	self:SetSlot(3, ItemStack.new(3, 64)) -- Stone
	self:SetSlot(4, ItemStack.new(5, 64)) -- Wood
	self:SetSlot(5, ItemStack.new(6, 64)) -- Leaves
	self:SetSlot(6, ItemStack.new(7, 64)) -- Tall Grass
	self:SetSlot(7, ItemStack.new(9, 1))  -- Chest
	self:SetSlot(8, ItemStack.new(97, 1)) -- Cobblestone Minion (for testing)
end

function VoxelHotbar:CreateHotbar()
	-- Account for borders: visual size = frame size + 2 borders = 56 + 4 = 60px
	local borderThickness = 2
	local visualSlotSize = HOTBAR_CONFIG.SLOT_SIZE + borderThickness * 2  -- 60px
	local totalWidth = (visualSlotSize * HOTBAR_CONFIG.SLOT_COUNT) +
	                   (HOTBAR_CONFIG.SLOT_SPACING * (HOTBAR_CONFIG.SLOT_COUNT - 1))

	-- Container frame
	self.container = Instance.new("Frame")
	self.container.Name = "HotbarContainer"
	self.container.Size = UDim2.new(0, totalWidth, 0, visualSlotSize)  -- Use visual size for height
	self.container.Position = UDim2.new(0.5, 0, 1, -math.floor(HOTBAR_CONFIG.BOTTOM_OFFSET / (HOTBAR_CONFIG.SCALE or 1) + 0.5))
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.BackgroundColor3 = HOTBAR_CONFIG.BG_COLOR
	self.container.BackgroundTransparency = 1  -- Fully transparent
	self.container.BorderSizePixel = 0
	self.container.Parent = self.gui

	-- Local scale only for hotbar (multiplies on top of global UIScaler)
	local localScale = Instance.new("UIScale")
	localScale.Name = "LocalScale"
	localScale.Scale = HOTBAR_CONFIG.SCALE
	localScale.Parent = self.container


	-- Create world button to the left of hotbar
	self:CreateWorldButton()

	-- Create slots
	for i = 1, HOTBAR_CONFIG.SLOT_COUNT do
		self:CreateSlotUI(i)
	end

	-- Create inventory button to the right of hotbar
	self:CreateInventoryButton()
end

function VoxelHotbar:CreateSlotUI(index)
	local borderThickness = 2  -- 2px border on each side
	-- Visual size = frame size + 2 borders = 56 + 4 = 60px
	-- Position calculation: frame position = (index - 1) * (visual size + gap between borders)
	local xPos = 8 + ((index - 1) * (HOTBAR_CONFIG.SLOT_SIZE + borderThickness * 2 + HOTBAR_CONFIG.SLOT_SPACING))

	-- Slot frame
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, 56, 0, 56)  -- Frame size (visual is 60px with 2px border)
	slot.Position = UDim2.new(0, xPos, 0, 8)
	slot.BackgroundColor3 = Color3.fromRGB(31, 31, 31)  -- Matching inventory
	slot.BackgroundTransparency = 0.5  -- Default state: 50% transparent
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.container

	-- Slot corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = slot

	-- Background image at opacity (matching inventory)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- Matching inventory
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border (matching inventory styling)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)  -- Matching inventory
	border.Thickness = 2
	border.Transparency = 0.25  -- Default state: 25% transparent
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot

	-- Selection border (bright and prominent like Minecraft)
	local selectionBorder = Instance.new("UIStroke")
	selectionBorder.Name = "SelectionBorder"
	selectionBorder.Color = Color3.fromRGB(255, 255, 255) -- Pure white
	selectionBorder.Thickness = 4 -- Thicker for better visibility
	selectionBorder.Transparency = 1
	selectionBorder.ZIndex = 2
	selectionBorder.Parent = slot

	-- Inner glow effect when selected
	local innerGlow = Instance.new("UIStroke")
	innerGlow.Name = "InnerGlow"
	innerGlow.Color = Color3.fromRGB(255, 255, 255)
	innerGlow.Thickness = 1
	innerGlow.Transparency = 1
	innerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerGlow.ZIndex = 2
	innerGlow.Parent = slot

	-- Create container for viewport - fills entire slot
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image (ZIndex 1)
	iconContainer.Parent = slot

	-- Stack count label overlays in bottom right
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
	countLabel.ZIndex = 5 -- Above viewport and background (matching inventory)
	countLabel.Parent = slot

	-- Number indicator overlays in top left
	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.Size = UDim2.new(0, 20, 0, 20)
	number.Position = UDim2.new(0, 4, 0, 4)
	number.BackgroundTransparency = 1
	number.Font = BOLD_FONT
	number.TextSize = 14
	number.TextColor3 = Color3.fromRGB(255, 255, 255)
	number.TextStrokeTransparency = 0.5
	number.Text = tostring(index)
	number.TextXAlignment = Enum.TextXAlignment.Left
	number.TextYAlignment = Enum.TextYAlignment.Top
	number.ZIndex = 4 -- Above viewport
	number.Parent = slot

	-- Store slot frame reference
	self.slotFrames[index] = {
		frame = slot,
		border = border,  -- Regular border
		selectionBorder = selectionBorder,  -- Selection border (not used anymore)
		innerGlow = innerGlow,  -- Not used anymore
		iconContainer = iconContainer,
		number = number,
		countLabel = countLabel
	}

	-- Add click/tap handler to select slot
	slot.Activated:Connect(function()
		self:SelectSlot(index)
	end)

	-- Update display
	self:UpdateSlotDisplay(index)
end

function VoxelHotbar:CreateWorldButton()
	local borderThickness = 2  -- 2px border on each side
	local visualSlotSize = HOTBAR_CONFIG.SLOT_SIZE + borderThickness * 2  -- 60px

	-- Button size: 25% smaller than hotbar slots (56px * 0.75 = 42px)
	local buttonSize = math.floor(HOTBAR_CONFIG.SLOT_SIZE * 0.75)  -- 42px

	-- Calculate position: left of hotbar with gap
	-- First slot starts at xPos = 8, so button should be positioned before that with gap
	-- Button X position = 8 - gap - buttonSize
	local xPos = 8 - HOTBAR_CONFIG.INVENTORY_BUTTON_GAP - buttonSize

	-- Vertical centering: hotbar slots are at Y = 8, visual height is 60px
	-- Center of hotbar is at 8 + 30 = 38px
	-- Button center should be at 38px, so button Y = 38 - (buttonSize / 2) = 38 - 21 = 17px
	local hotbarCenterY = 8 + (visualSlotSize / 2)  -- 8 + 30 = 38px
	local buttonY = hotbarCenterY - (buttonSize / 2)  -- 38 - 21 = 17px

	-- World button frame (matching hotbar slot styling)
	local button = Instance.new("TextButton")
	button.Name = "WorldButton"
	button.Size = UDim2.new(0, buttonSize, 0, buttonSize)  -- 42x42px (25% smaller)
	button.Position = UDim2.new(0, xPos, 0, buttonY)
	button.BackgroundColor3 = Color3.fromRGB(31, 31, 31)  -- Matching inventory
	button.BackgroundTransparency = 0.5  -- Default state: 50% transparent
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = self.container

	-- Button corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = button

	-- Background image (matching hotbar slots)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- Matching inventory
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = button

	-- Border (matching inventory styling)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)  -- Matching inventory
	border.Thickness = 2
	border.Transparency = 0.25  -- Default state: 25% transparent
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button

	-- Icon container for home/world icon
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -8, 1, -8)
	iconContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image
	iconContainer.Parent = button

	-- Create planet icon using IconManager
	local globeIcon = IconManager:CreateIcon(iconContainer, "Nature", "Globe", {
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
	})

	-- B text label at top left (matching hotbar number indicator style)
	local bLabel = Instance.new("TextLabel")
	bLabel.Name = "BLabel"
	bLabel.Size = UDim2.new(0, 20, 0, 20)
	bLabel.Position = UDim2.new(0, 4, 0, 4)
	bLabel.BackgroundTransparency = 1
	bLabel.Font = BOLD_FONT
	bLabel.TextSize = 14
	bLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	bLabel.TextStrokeTransparency = 0.5
	bLabel.Text = "B"
	bLabel.TextXAlignment = Enum.TextXAlignment.Left
	bLabel.TextYAlignment = Enum.TextYAlignment.Top
	bLabel.ZIndex = 4  -- Above viewport
	bLabel.Parent = button

	-- Store button reference
	self.worldButton = {
		frame = button,
		border = border,
		iconContainer = iconContainer,
		globeIcon = globeIcon,
		bLabel = bLabel
	}

	-- Add click handler to toggle worlds panel
	button.Activated:Connect(function()
		if not self:CanToggleUI() then
			return
		end
		if self.voxelInventory and self.voxelInventory.isOpen then
			self.voxelInventory:Close("worlds")
		elseif self.voxelInventory and self.voxelInventory.IsClosing and self.voxelInventory:IsClosing() then
			self.voxelInventory:SetPendingCloseMode("worlds")
		end
		if self.worldsPanel then
			self.worldsPanel:Toggle()
		end
		-- Silently skip if worldsPanel not yet set (during initialization)
	end)

	-- Hover effects (matching hotbar slot behavior)
	button.MouseEnter:Connect(function()
		border.Transparency = 0  -- Fully opaque on hover
		button.BackgroundTransparency = 0.25  -- Less transparent on hover
	end)

	button.MouseLeave:Connect(function()
		border.Transparency = 0.25  -- Back to default
		button.BackgroundTransparency = 0.5  -- Back to default
	end)
end

function VoxelHotbar:CreateInventoryButton()
	local borderThickness = 2  -- 2px border on each side
	local visualSlotSize = HOTBAR_CONFIG.SLOT_SIZE + borderThickness * 2  -- 60px
	local totalHotbarWidth = (visualSlotSize * HOTBAR_CONFIG.SLOT_COUNT) +
	                        (HOTBAR_CONFIG.SLOT_SPACING * (HOTBAR_CONFIG.SLOT_COUNT - 1))

	-- Calculate position: right of hotbar with gap
	-- Slots start at xPos = 8, so last slot ends at 8 + totalHotbarWidth
	-- Button should be positioned after that with gap
	local lastSlotEnd = 8 + totalHotbarWidth
	local xPos = lastSlotEnd + HOTBAR_CONFIG.INVENTORY_BUTTON_GAP

	-- Button size: 25% smaller than hotbar slots (56px * 0.75 = 42px)
	local buttonSize = math.floor(HOTBAR_CONFIG.SLOT_SIZE * 0.75)  -- 42px

	-- Vertical centering: hotbar slots are at Y = 8, visual height is 60px
	-- Center of hotbar is at 8 + 30 = 38px
	-- Button center should be at 38px, so button Y = 38 - (buttonSize / 2) = 38 - 21 = 17px
	local hotbarCenterY = 8 + (visualSlotSize / 2)  -- 8 + 30 = 38px
	local buttonY = hotbarCenterY - (buttonSize / 2)  -- 38 - 21 = 17px

	-- Inventory button frame (matching hotbar slot styling)
	local button = Instance.new("TextButton")
	button.Name = "InventoryButton"
	button.Size = UDim2.new(0, buttonSize, 0, buttonSize)  -- 42x42px (25% smaller)
	button.Position = UDim2.new(0, xPos, 0, buttonY)
	button.BackgroundColor3 = Color3.fromRGB(31, 31, 31)  -- Matching inventory
	button.BackgroundTransparency = 0.5  -- Default state: 50% transparent
	button.BorderSizePixel = 0
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = self.container

	-- Button corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 2)
	corner.Parent = button

	-- Background image (matching hotbar slots)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.new(1, 0, 1, 0)
	bgImage.Position = UDim2.new(0, 0, 0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- Matching inventory
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = button

	-- Border (matching inventory styling)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = Color3.fromRGB(35, 35, 35)  -- Matching inventory
	border.Thickness = 2
	border.Transparency = 0.25  -- Default state: 25% transparent
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button

	-- Icon container for backpack icon
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -8, 1, -8)
	iconContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image
	iconContainer.Parent = button

	-- Create backpack icon using IconManager
	local backpackIcon = IconManager:CreateIcon(iconContainer, "Clothing", "Backpack", {
		size = UDim2.new(1, 0, 1, 0),
		position = UDim2.new(0.5, 0, 0.5, 0),
		anchorPoint = Vector2.new(0.5, 0.5),
	})

	-- E text label at top left (matching hotbar number indicator style)
	local eLabel = Instance.new("TextLabel")
	eLabel.Name = "ELabel"
	eLabel.Size = UDim2.new(0, 20, 0, 20)
	eLabel.Position = UDim2.new(0, 4, 0, 4)
	eLabel.BackgroundTransparency = 1
	eLabel.Font = BOLD_FONT
	eLabel.TextSize = 14
	eLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	eLabel.TextStrokeTransparency = 0.5
	eLabel.Text = "E"
	eLabel.TextXAlignment = Enum.TextXAlignment.Left
	eLabel.TextYAlignment = Enum.TextYAlignment.Top
	eLabel.ZIndex = 4  -- Above viewport
	eLabel.Parent = button

	-- Store button reference
	self.inventoryButton = {
		frame = button,
		border = border,
		iconContainer = iconContainer,
		backpackIcon = backpackIcon,
		eLabel = eLabel
	}

	-- Add click handler to toggle inventory
	button.Activated:Connect(function()
		if self.voxelInventory then
			self.voxelInventory:Toggle()
		else
			warn("VoxelHotbar: Inventory reference not set - inventory may not be initialized yet")
		end
	end)

	-- Hover effects (matching hotbar slot behavior)
	button.MouseEnter:Connect(function()
		border.Transparency = 0  -- Fully opaque on hover
		button.BackgroundTransparency = 0.25  -- Less transparent on hover
	end)

	button.MouseLeave:Connect(function()
		border.Transparency = 0.25  -- Back to default
		button.BackgroundTransparency = 0.5  -- Back to default
	end)
end

function VoxelHotbar:UpdateSlotDisplay(index)
	local slotFrame = self.slotFrames[index]
	if not slotFrame then return end

	local stack = self.slots[index]
	local currentItemId = slotFrame.currentItemId  -- Store in table, not as attribute

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		-- Only recreate viewport/image if item type changed (huge performance win)
		if currentItemId ~= itemId then
			-- Clear ALL existing visuals (ViewportContainer, ToolImage, ImageLabel, etc.)
			for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
				if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
					child:Destroy()
				end
			end

			if isTool then
				-- Render tool image (unified via ItemRegistry)
				local itemDef = ItemRegistry.GetItem(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -8, 1, -8)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = itemDef and itemDef.image or ""
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
			elseif ArmorConfig.IsArmor(itemId) then
				-- Render armor image
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
				-- Render spawn egg (two-layer)
				local icon = SpawnEggIcon.Create(itemId, UDim2.new(1, -8, 1, -8))
				icon.Position = UDim2.new(0.5, 0, 0.5, 0)
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Parent = slotFrame.iconContainer
			elseif BlockRegistry:IsBucket(itemId) or BlockRegistry:IsPlaceable(itemId) == false then
				-- Render non-placeable items (buckets, etc.) as 2D images
				local blockDef = BlockRegistry:GetBlock(itemId)
				local textureId = blockDef and blockDef.textures and blockDef.textures.all or ""

				local image = Instance.new("ImageLabel")
				image.Name = "ItemImage"
				image.Size = UDim2.new(1, -8, 1, -8)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = textureId
				image.ScaleType = Enum.ScaleType.Fit
				image.Parent = slotFrame.iconContainer
			else
				-- Render block viewport
				BlockViewportCreator.CreateBlockViewport(
					slotFrame.iconContainer,
					itemId,
					UDim2.new(1, 0, 1, 0)
				)
			end

			slotFrame.currentItemId = itemId  -- Store in table
		end

		-- Always update count (cheap operation)
		if stack:GetCount() > 1 then
			slotFrame.countLabel.Text = tostring(stack:GetCount())
		else
			slotFrame.countLabel.Text = ""
		end
	else
		-- Slot is empty - clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(slotFrame.iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
		slotFrame.currentItemId = nil
		slotFrame.countLabel.Text = ""
	end
end

function VoxelHotbar:GetSlot(index)
	return self.slots[index]
end

function VoxelHotbar:SetSlot(index, itemStack)
	if index < 1 or index > HOTBAR_CONFIG.SLOT_COUNT then return end

	self.slots[index] = itemStack or ItemStack.new(0, 0)
	self:UpdateSlotDisplay(index)

	-- Update game state if this is the selected slot
	if index == self.selectedSlot then
		self:OnSlotSelected()
	end
end

function VoxelHotbar:SelectSlot(index)
	if index < 1 or index > HOTBAR_CONFIG.SLOT_COUNT then return end

	-- Deselect previous slot (reset to default state)
	if self.slotFrames[self.selectedSlot] then
		local prevSlot = self.slotFrames[self.selectedSlot]
		local prevBorder = prevSlot.frame:FindFirstChild("Border")
		if prevBorder then
			prevBorder.Transparency = 0.25  -- Default: 25% transparent
		end
		prevSlot.frame.BackgroundTransparency = 0.5  -- Default: 50% transparent
		-- Tween position back to original (Y = 8) with dynamic easing
		TweenService:Create(prevSlot.frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(prevSlot.frame.Position.X.Scale, prevSlot.frame.Position.X.Offset, 0, 8)
		}):Play()
	end

	-- Select new slot (apply selected styling)
	self.selectedSlot = index
	if self.slotFrames[index] then
		local slot = self.slotFrames[index]
		local border = slot.frame:FindFirstChild("Border")
		if border then
			border.Transparency = 0  -- Selected: fully opaque
		end
		slot.frame.BackgroundTransparency = 0.25  -- Selected: 25% transparent
		-- Tween position 5px up (Y = 3, original is 8) with dynamic easing
		TweenService:Create(slot.frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(slot.frame.Position.X.Scale, slot.frame.Position.X.Offset, 0, 3)
		}):Play()
	end

	self:OnSlotSelected()
end

function VoxelHotbar:OnSlotSelected()
	local stack = self.slots[self.selectedSlot]

	-- Store selected slot index for server requests
	GameState:Set("voxelWorld.selectedSlot", self.selectedSlot)
	-- Inform server of selected hotbar slot (used for held block / tempt logic)
	EventManager:SendToServer("SelectHotbarSlot", { slotIndex = self.selectedSlot })

    if stack and not stack:IsEmpty() then
        local itemId = stack:GetItemId()
        -- If this is a tool, equip it (no durability)
        if ToolConfig.IsTool(itemId) then
            -- Clear block selection and equip tool
            GameState:Set("voxelWorld.selectedBlock", nil)
            GameState:Set("voxelWorld.isHoldingItem", false)
            -- Set tool equip state for client-side visuals (R15 handle, etc.)
            GameState:Set("voxelWorld.selectedToolItemId", itemId)
            GameState:Set("voxelWorld.isHoldingTool", true)
            GameState:Set("voxelWorld.selectedToolSlotIndex", self.selectedSlot)
            EventManager:SendToServer("EquipTool", { slotIndex = self.selectedSlot })
        else
            -- Treat as block selection
            local blockInfo = BLOCK_INFO[itemId] or BLOCK_INFO[0]
            GameState:Set("voxelWorld.selectedBlock", {
                id = itemId,
                name = blockInfo.name,
                icon = blockInfo.icon,
                count = stack:GetCount()
            })
            GameState:Set("voxelWorld.isHoldingItem", true)
            -- Clear tool equip state
            GameState:Set("voxelWorld.selectedToolItemId", nil)
            GameState:Set("voxelWorld.isHoldingTool", false)
            GameState:Set("voxelWorld.selectedToolSlotIndex", nil)
            -- Ensure no tool is equipped
            EventManager:SendToServer("UnequipTool")
			-- Already sent SelectHotbarSlot above
        end
    else
		-- Empty hand
		GameState:Set("voxelWorld.selectedBlock", nil)
		GameState:Set("voxelWorld.isHoldingItem", false)
            -- Clear tool equip state
            GameState:Set("voxelWorld.selectedToolItemId", nil)
            GameState:Set("voxelWorld.isHoldingTool", false)
            GameState:Set("voxelWorld.selectedToolSlotIndex", nil)
        EventManager:SendToServer("UnequipTool")
		-- Already sent SelectHotbarSlot above
	end
end

function VoxelHotbar:GetSelectedBlock()
	local stack = self.slots[self.selectedSlot]
	if stack and not stack:IsEmpty() then
		local blockInfo = BLOCK_INFO[stack:GetItemId()] or BLOCK_INFO[0]
		return {
			id = stack:GetItemId(),
			name = blockInfo.name,
			icon = blockInfo.icon,
			count = stack:GetCount()
		}
	end
	return nil
end

function VoxelHotbar:GetBlockInfo(itemId)
	return BLOCK_INFO[itemId] or BLOCK_INFO[0]
end

function VoxelHotbar:DropSelectedItem()
	local stack = self.slots[self.selectedSlot]

	if not stack or stack:IsEmpty() then
		return -- Nothing to drop
	end

	local EventManager = require(ReplicatedStorage.Shared.EventManager)

	-- Drop 1 item from the selected slot
	local itemId = stack:GetItemId()
	local count = 1

	-- Optimistically remove from hotbar (server will sync back if it fails)
	stack:RemoveCount(count)
	self:UpdateSlotDisplay(self.selectedSlot)
	self:OnSlotSelected()

	-- Request server to spawn dropped item
	EventManager:SendToServer("RequestDropItem", {
		itemId = itemId,
		count = count,
		slotIndex = self.selectedSlot
	})

	playInventoryPopSound()

	print(string.format("Dropped %d x %s", count, self:GetBlockInfo(itemId).name))
end

function VoxelHotbar:ConsumeOne(slotIndex)
	local slot = slotIndex or self.selectedSlot
	local stack = self.slots[slot]

	if stack and not stack:IsEmpty() then
		stack:RemoveCount(1)
		self:UpdateSlotDisplay(slot)

		if slot == self.selectedSlot then
			self:OnSlotSelected()
		end

		return true
	end

	return false
end

function VoxelHotbar:BindInput()
	-- Number keys 1-9
	self.connections[#self.connections + 1] = InputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end

		-- Check for number keys
		if input.KeyCode.Value >= Enum.KeyCode.One.Value and input.KeyCode.Value <= Enum.KeyCode.Nine.Value then
			local slot = input.KeyCode.Value - Enum.KeyCode.One.Value + 1
			self:SelectSlot(slot)
		end

		-- Q key - Drop item
		if input.KeyCode == Enum.KeyCode.Q then
			self:DropSelectedItem()
		end

		-- B key - Worlds panel handling moved to GameClient.client.lua to avoid double-toggle
	end)

	-- Mouse wheel scrolling
	self.connections[#self.connections + 1] = InputService.InputChanged:Connect(function(input, gpe)
		if gpe then return end

		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local delta = input.Position.Z
			local newSlot = self.selectedSlot

			if delta > 0 then
				newSlot = newSlot - 1
				if newSlot < 1 then newSlot = HOTBAR_CONFIG.SLOT_COUNT end
			elseif delta < 0 then
				newSlot = newSlot + 1
				if newSlot > HOTBAR_CONFIG.SLOT_COUNT then newSlot = 1 end
			end

			self:SelectSlot(newSlot)
		end
	end)
end

function VoxelHotbar:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function VoxelHotbar:Hide()
	if self.gui then
		self.gui.Enabled = false
	end
end

function VoxelHotbar:SetInventoryReference(inventory)
	-- Set reference to inventory panel (called after inventory is created)
	self.voxelInventory = inventory
end

function VoxelHotbar:SetWorldsPanel(worldsPanel)
	self.worldsPanel = worldsPanel
end

function VoxelHotbar:Cleanup()
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	self.connections = {}

	if self.gui then
		self.gui:Destroy()
	end
end

return VoxelHotbar
