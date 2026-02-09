--[[
	SmithingUI.lua
	Interactive smithing UI with temperature balance mini-game (Anvil workstation)
	Redesigned to match the voxel inventory/worlds panel aesthetic.

	Features:
	- Recipe selection grid showing available smithing recipes
	- Temperature gauge mini-game (hold to heat, release to cool)
	- Countdown-driven progress (auto smiths, interaction speeds it up)
	- Completion screen with stats
	
	Note: This was previously SmithingUI.lua, renamed for the Anvil system.
	Basic smelting is now handled by the simple SmithingUI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local InputService = require(script.Parent.Parent.Input.InputService)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local SoundManager = require(script.Parent.Parent.Managers.SoundManager)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local SmithingConfig = require(ReplicatedStorage.Configs.SmithingConfig)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local UpheavalFont = require(ReplicatedStorage.Fonts["Upheaval BRK"])
local _ = UpheavalFont -- Ensure font module loads

local SmithingUI = {}
SmithingUI.__index = SmithingUI

local player = Players.LocalPlayer
local CUSTOM_FONT_NAME = "Upheaval BRK"
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold

-- Consistent layout matching inventory/worlds panels
local SMITHING_LAYOUT = {
	-- Panel dimensions (single column design, narrower than inventory)
	TOTAL_WIDTH = 520,
	HEADER_HEIGHT = 54,
	BODY_HEIGHT = 420,
	SHADOW_HEIGHT = 18,

	-- Section sizing
	LABEL_HEIGHT = 22,
	LABEL_SPACING = 8,

	-- Recipe grid
	RECIPE_CELL_SIZE = 56,
	RECIPE_SPACING = 6,
	RECIPE_COLUMNS = 6,

	-- Temperature gauge
	GAUGE_WIDTH = 440,
	GAUGE_HEIGHT = 44,
	INDICATOR_WIDTH = 8,

	-- Progress bar
	PROGRESS_HEIGHT = 28,

	-- Colors (matching inventory/worlds)
	PANEL_BG_COLOR = Color3.fromRGB(58, 58, 58),
	SHADOW_COLOR = Color3.fromRGB(43, 43, 43),

	-- Border styling
	COLUMN_BORDER_COLOR = Color3.fromRGB(77, 77, 77),
	COLUMN_BORDER_THICKNESS = 3,

	-- Slot styling
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,
	SLOT_HOVER_COLOR = Color3.fromRGB(50, 50, 50),
	SLOT_BORDER_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_BORDER_THICKNESS = 2,
	SLOT_CORNER_RADIUS = 6,

	-- Button colors (matching CraftingPanel style)
	BTN_ACCENT = Color3.fromRGB(90, 180, 255),  -- Cool blue accent
	BTN_ACCENT_HOVER = Color3.fromRGB(120, 200, 255),
	BTN_DEFAULT = Color3.fromRGB(31, 31, 31),
	BTN_DEFAULT_HOVER = Color3.fromRGB(50, 50, 50),
	BTN_DISABLED = Color3.fromRGB(45, 45, 45),
	BTN_DISABLED_TEXT = Color3.fromRGB(100, 100, 100),

	-- Zone colors
	ZONE_COLOR = Color3.fromRGB(80, 200, 120),
	COLD_COLOR = Color3.fromRGB(80, 150, 255),
	HOT_COLOR = Color3.fromRGB(255, 100, 50),

	-- Countdown colors
	TIME_IDLE_COLOR = Color3.fromRGB(130, 180, 220),
	TIME_ACTIVE_COLOR = Color3.fromRGB(90, 210, 255),
	BAR_IDLE_COLOR = Color3.fromRGB(90, 130, 170),
	BAR_ACTIVE_COLOR = Color3.fromRGB(80, 200, 255),

	-- Text colors
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_SECONDARY = Color3.fromRGB(185, 185, 195),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),

	-- Background image (matching inventory)
	BACKGROUND_IMAGE = "rbxassetid://82824299358542",
	BACKGROUND_IMAGE_TRANSPARENCY = 0.6,
}

local HEADING_SIZE = 54
local LABEL_SIZE = 24

--[[
	Create a styled button with consistent appearance
	@param config: {
		name: string,
		text: string,
		size: UDim2,
		position: UDim2? (optional),
		anchorPoint: Vector2? (optional),
		style: "accent" | "default" | "danger" (default: "accent"),
		parent: Instance,
		onClick: function? (optional)
	}
	@return: TextButton
]]
local function CreateStyledButton(config)
	local style = config.style or "accent"

	-- Determine colors based on style
	local bgColor, hoverColor, textColor
	local bgTransparency = 0
	local useBackgroundImage = false

	if style == "accent" then
		bgColor = SMITHING_LAYOUT.BTN_ACCENT
		hoverColor = SMITHING_LAYOUT.BTN_ACCENT_HOVER
		textColor = SMITHING_LAYOUT.TEXT_PRIMARY
	elseif style == "danger" then
		bgColor = Color3.fromRGB(220, 100, 100)
		hoverColor = Color3.fromRGB(240, 120, 120)
		textColor = SMITHING_LAYOUT.TEXT_PRIMARY
	else -- "default"
		bgColor = SMITHING_LAYOUT.BTN_DEFAULT
		hoverColor = SMITHING_LAYOUT.BTN_DEFAULT_HOVER
		textColor = SMITHING_LAYOUT.TEXT_PRIMARY
		bgTransparency = SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY
		useBackgroundImage = true
	end

	-- Create button
	local button = Instance.new("TextButton")
	button.Name = config.name or "Button"
	button.Size = config.size or UDim2.fromOffset(160, 56)
	if config.position then
		button.Position = config.position
	end
	if config.anchorPoint then
		button.AnchorPoint = config.anchorPoint
	end
	button.BackgroundColor3 = bgColor
	button.BackgroundTransparency = bgTransparency
	button.BorderSizePixel = 0
	button.Font = BOLD_FONT
	button.TextSize = 18
	button.TextColor3 = textColor
	button.Text = config.text or "Button"
	button.AutoButtonColor = false
	button.Parent = config.parent
	button:SetAttribute("disabled", false)

	-- Corner radius
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, SMITHING_LAYOUT.SLOT_CORNER_RADIUS)
	corner.Parent = button

	-- Border stroke
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = SMITHING_LAYOUT.SLOT_BORDER_COLOR
	border.Thickness = SMITHING_LAYOUT.SLOT_BORDER_THICKNESS
	border.Transparency = 0
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = button

	-- Background image for default style buttons
	if useBackgroundImage then
		local bgImage = Instance.new("ImageLabel")
		bgImage.Name = "BackgroundImage"
		bgImage.Size = UDim2.fromScale(1, 1)
		bgImage.BackgroundTransparency = 1
		bgImage.Image = SMITHING_LAYOUT.BACKGROUND_IMAGE
		bgImage.ImageTransparency = SMITHING_LAYOUT.BACKGROUND_IMAGE_TRANSPARENCY
		bgImage.ScaleType = Enum.ScaleType.Tile
		bgImage.TileSize = UDim2.fromOffset(128, 128)
		bgImage.ZIndex = 0
		bgImage.Parent = button

		local bgCorner = Instance.new("UICorner")
		bgCorner.CornerRadius = UDim.new(0, SMITHING_LAYOUT.SLOT_CORNER_RADIUS)
		bgCorner.Parent = bgImage
	end

	-- Hover effects
	button.MouseEnter:Connect(function()
		if button:GetAttribute("disabled") then
			return
		end
		button.BackgroundColor3 = hoverColor
	end)
	button.MouseLeave:Connect(function()
		if button:GetAttribute("disabled") then
			return
		end
		button.BackgroundColor3 = bgColor
		button.BackgroundTransparency = bgTransparency
	end)

	-- Click handler
	if config.onClick then
		button.MouseButton1Click:Connect(config.onClick)
	end

	return button
end

--[[
	Update button to disabled state
	@param button: TextButton
	@param disabled: boolean
	@param disabledText: string? (optional text when disabled)
]]
local function SetButtonDisabled(button, disabled, disabledText)
	button:SetAttribute("disabled", disabled)
	if disabled then
		button.BackgroundColor3 = SMITHING_LAYOUT.BTN_DISABLED
		button.BackgroundTransparency = 0
		button.TextColor3 = SMITHING_LAYOUT.BTN_DISABLED_TEXT
		if disabledText then
			button.Text = disabledText
		end
	else
		button.BackgroundColor3 = SMITHING_LAYOUT.BTN_ACCENT
		button.BackgroundTransparency = 0
		button.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	end
end

function SmithingUI.new(inventoryManager)
	local self = setmetatable({}, SmithingUI)

	self.inventoryManager = inventoryManager
	self.isOpen = false
	self.gui = nil
	self.anvilPosition = nil
	self.recipes = {}
	self.selectedRecipe = nil

	-- Mini-game state
	self.isSmelting = false
	self.smeltConfig = nil
	self.indicator = SmithingConfig.Gauge.START_POSITION
	self.zoneCenter = 50
	self.driftDirection = 1
	self.progress = 0
	self.totalTime = 0
	self.fastDuration = 0
	self.autoDuration = 0
	self.timeRemaining = 0
	self.isHeating = false

	-- UI references
	self.recipeGrid = nil
	self.recipeCards = {}
	self.miniGamePanel = nil
	self.temperatureGauge = nil
	self.indicatorFrame = nil
	self.zoneFrame = nil
	self.progressBar = nil
	self.progressFill = nil

	-- Connections
	self.connections = {}
	self.updateConnection = nil

	-- Button state
	self.isWaitingForSmelt = false

	-- Auto-smelt state (completion panel)
	self.autoSmeltEnabled = false
	self.autoSmeltDelay = 3
	self.autoSmeltTask = nil
	self.autoSmeltCountdownConnection = nil
	self.autoSmeltEndTime = nil

	return self
end

function SmithingUI:Initialize()
	FontBinder.preload(CUSTOM_FONT_NAME)

	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "SmithingUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 150
	self.gui.IgnoreGuiInset = false
	self.gui.Enabled = false
	self.gui.Parent = player:WaitForChild("PlayerGui")

	-- Add responsive scaling (matching inventory/worlds)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale:SetAttribute("min_scale", 0.75)
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create main panel
	self:CreatePanel()

	-- Create mini-game panel (hidden by default)
	self:CreateMiniGamePanel()

	-- Create completion panel (hidden by default)
	self:CreateCompletionPanel()

	-- Bind input
	self:BindInput()

	-- Register network events
	local eventsSuccess, eventsError = pcall(function()
		self:RegisterEvents()
	end)
	if not eventsSuccess then
		warn("[SmithingUI] Failed to register events:", eventsError)
	end

	-- Register with UIVisibilityManager
	local registerSuccess, registerError = pcall(function()
		UIVisibilityManager:RegisterComponent("smithingUI", self, {
			showMethod = "Show",
			hideMethod = "Hide",
			isOpenMethod = "IsOpen",
			priority = 150
		})
	end)
	if not registerSuccess then
		warn("[SmithingUI] Failed to register with UIVisibilityManager:", registerError)
	end

	return self
end

function SmithingUI:CreatePanel()
	local totalWidth = SMITHING_LAYOUT.TOTAL_WIDTH
	local totalHeight = SMITHING_LAYOUT.HEADER_HEIGHT + SMITHING_LAYOUT.BODY_HEIGHT

	-- Main panel (transparent container)
	self.panel = Instance.new("Frame")
	self.panel.Name = "FurnacePanel"
	self.panel.Size = UDim2.fromOffset(totalWidth, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, -SMITHING_LAYOUT.HEADER_HEIGHT)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundTransparency = 1
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui

	-- Create header
	self:CreateHeader(self.panel)

	-- Create body
	self:CreateBody(self.panel)
end

function SmithingUI:CreateHeader(parent)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.fromOffset(SMITHING_LAYOUT.TOTAL_WIDTH, SMITHING_LAYOUT.HEADER_HEIGHT)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = parent

	-- Title text (left side, Upheaval font)
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.Text = "FURNACE"
	title.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	title.TextSize = HEADING_SIZE
	title.Font = Enum.Font.Code
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame
	FontBinder.apply(title, CUSTOM_FONT_NAME)
	self.titleLabel = title

	-- Close button using IconManager
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

	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 0}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)
end

function SmithingUI:CreateBody(parent)
	local bodyFrame = Instance.new("Frame")
	bodyFrame.Name = "Body"
	bodyFrame.Size = UDim2.fromOffset(SMITHING_LAYOUT.TOTAL_WIDTH, SMITHING_LAYOUT.BODY_HEIGHT)
	bodyFrame.Position = UDim2.fromOffset(0, SMITHING_LAYOUT.HEADER_HEIGHT)
	bodyFrame.BackgroundTransparency = 1
	bodyFrame.Parent = parent

	-- Create content column (single column for furnace)
	self:CreateContentColumn(bodyFrame)
end

function SmithingUI:CreateContentColumn(parent)
	local columnWidth = SMITHING_LAYOUT.TOTAL_WIDTH
	local columnHeight = SMITHING_LAYOUT.BODY_HEIGHT
	local shadowHeight = SMITHING_LAYOUT.SHADOW_HEIGHT

	-- Main content frame
	local column = Instance.new("Frame")
	column.Name = "ContentColumn"
	column.Size = UDim2.fromOffset(columnWidth, columnHeight)
	column.Position = UDim2.fromOffset(3, 3)
	column.BackgroundColor3 = SMITHING_LAYOUT.PANEL_BG_COLOR
	column.BackgroundTransparency = 0
	column.BorderSizePixel = 0
	column.ZIndex = 1
	column.Parent = parent
	self.contentColumn = column

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = column

	-- Shadow (decorative element at bottom)
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.Size = UDim2.fromOffset(columnWidth, shadowHeight)
	shadow.AnchorPoint = Vector2.new(0, 0.5)
	shadow.Position = UDim2.fromOffset(3, columnHeight + 3)
	shadow.BackgroundColor3 = SMITHING_LAYOUT.SHADOW_COLOR
	shadow.BackgroundTransparency = 0
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 0
	shadow.Parent = parent

	local shadowCorner = Instance.new("UICorner")
	shadowCorner.CornerRadius = UDim.new(0, 8)
	shadowCorner.Parent = shadow

	-- Border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = SMITHING_LAYOUT.COLUMN_BORDER_COLOR
	border.Thickness = SMITHING_LAYOUT.COLUMN_BORDER_THICKNESS
	border.Parent = column

	-- Padding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = column

	-- Create recipe section
	self:CreateRecipeSection(column)

	-- Create selected recipe info
	self:CreateRecipeInfo(column)
end

function SmithingUI:CreateRecipeSection(parent)
	-- Section label
	local label = Instance.new("TextLabel")
	label.Name = "RecipeLabel"
	label.Size = UDim2.new(1, 0, 0, SMITHING_LAYOUT.LABEL_HEIGHT)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = LABEL_SIZE
	label.TextColor3 = SMITHING_LAYOUT.TEXT_MUTED
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "RECIPES"
	label.Parent = parent
	FontBinder.apply(label, CUSTOM_FONT_NAME)

	-- Recipe grid container
	local gridContainer = Instance.new("Frame")
	gridContainer.Name = "RecipeGrid"
	gridContainer.Size = UDim2.new(1, 0, 0, 140)
	gridContainer.Position = UDim2.fromOffset(0, SMITHING_LAYOUT.LABEL_HEIGHT + SMITHING_LAYOUT.LABEL_SPACING)
	gridContainer.BackgroundTransparency = 1
	gridContainer.Parent = parent
	self.recipeGrid = gridContainer

	-- Grid layout
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(SMITHING_LAYOUT.RECIPE_CELL_SIZE, SMITHING_LAYOUT.RECIPE_CELL_SIZE)
	gridLayout.CellPadding = UDim2.fromOffset(SMITHING_LAYOUT.RECIPE_SPACING, SMITHING_LAYOUT.RECIPE_SPACING)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridContainer
end

function SmithingUI:CreateRecipeInfo(parent)
	-- Info container (positioned below recipe grid)
	local infoFrame = Instance.new("Frame")
	infoFrame.Name = "RecipeInfo"
	infoFrame.Size = UDim2.new(1, 0, 0, 200)
	infoFrame.Position = UDim2.fromOffset(0, SMITHING_LAYOUT.LABEL_HEIGHT + SMITHING_LAYOUT.LABEL_SPACING + 145)
	infoFrame.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	infoFrame.BackgroundTransparency = SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY
	infoFrame.BorderSizePixel = 0
	infoFrame.Parent = parent
	self.infoFrame = infoFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, SMITHING_LAYOUT.SLOT_CORNER_RADIUS)
	corner.Parent = infoFrame

	local border = Instance.new("UIStroke")
	border.Color = SMITHING_LAYOUT.SLOT_BORDER_COLOR
	border.Thickness = SMITHING_LAYOUT.SLOT_BORDER_THICKNESS
	border.Parent = infoFrame

	-- Info padding
	local infoPadding = Instance.new("UIPadding")
	infoPadding.PaddingTop = UDim.new(0, 12)
	infoPadding.PaddingBottom = UDim.new(0, 12)
	infoPadding.PaddingLeft = UDim.new(0, 12)
	infoPadding.PaddingRight = UDim.new(0, 12)
	infoPadding.Parent = infoFrame

	-- Selected recipe name
	local recipeName = Instance.new("TextLabel")
	recipeName.Name = "RecipeName"
	recipeName.Size = UDim2.new(1, 0, 0, 28)
	recipeName.BackgroundTransparency = 1
	recipeName.Font = Enum.Font.Code
	recipeName.TextSize = 28
	recipeName.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	recipeName.Text = "Pick a recipe"
	recipeName.TextXAlignment = Enum.TextXAlignment.Left
	recipeName.Parent = infoFrame
	FontBinder.apply(recipeName, CUSTOM_FONT_NAME)
	self.recipeNameLabel = recipeName

	-- Requirements label
	local reqLabel = Instance.new("TextLabel")
	reqLabel.Name = "RequirementsLabel"
	reqLabel.Size = UDim2.new(1, 0, 0, SMITHING_LAYOUT.LABEL_HEIGHT)
	reqLabel.Position = UDim2.fromOffset(0, 36)
	reqLabel.BackgroundTransparency = 1
	reqLabel.Font = Enum.Font.Code
	reqLabel.TextSize = 18
	reqLabel.TextColor3 = SMITHING_LAYOUT.TEXT_MUTED
	reqLabel.Text = "NEEDS"
	reqLabel.TextXAlignment = Enum.TextXAlignment.Left
	reqLabel.Parent = infoFrame
	FontBinder.apply(reqLabel, CUSTOM_FONT_NAME)

	-- Ingredients container
	local ingredientsFrame = Instance.new("Frame")
	ingredientsFrame.Name = "Ingredients"
	ingredientsFrame.Size = UDim2.new(1, 0, 0, 50)
	ingredientsFrame.Position = UDim2.fromOffset(0, 58)
	ingredientsFrame.BackgroundTransparency = 1
	ingredientsFrame.Parent = infoFrame
	self.ingredientsFrame = ingredientsFrame

	local ingredientLayout = Instance.new("UIListLayout")
	ingredientLayout.FillDirection = Enum.FillDirection.Horizontal
	ingredientLayout.Padding = UDim.new(0, 16)
	ingredientLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ingredientLayout.Parent = ingredientsFrame

	-- Start smelting button
	self.startButton = CreateStyledButton({
		name = "StartButton",
		text = "SMELT",
		size = UDim2.new(1, 0, 0, 56),
		position = UDim2.new(0, 0, 1, -56),
		style = "accent",
		parent = infoFrame,
		onClick = function()
			self:OnStartSmelt()
		end
	})
end

function SmithingUI:CreateMiniGamePanel()
	-- Full-screen immersive mini-game
	local miniGameRoot = Instance.new("Frame")
	miniGameRoot.Name = "MiniGameRoot"
	miniGameRoot.Size = UDim2.fromScale(1, 1)
	miniGameRoot.BackgroundTransparency = 1
	miniGameRoot.Visible = false
	miniGameRoot.Parent = self.gui
	self.miniGamePanel = miniGameRoot

	-- Compact centered container
	local centerWidth = 360
	local centerHeight = 200
	local centerContainer = Instance.new("Frame")
	centerContainer.Name = "CenterContainer"
	centerContainer.Size = UDim2.fromOffset(centerWidth, centerHeight)
	centerContainer.Position = UDim2.fromScale(0.5, 0.5)
	centerContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	centerContainer.BackgroundTransparency = 1
	centerContainer.Parent = miniGameRoot

	-- Header close button (matches other UI headers)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "MiniGameHeader"
	headerFrame.Size = UDim2.fromOffset(SMITHING_LAYOUT.TOTAL_WIDTH, SMITHING_LAYOUT.HEADER_HEIGHT)
	headerFrame.Position = UDim2.new(0.5, 0, 0.5, -centerHeight / 2)
	headerFrame.AnchorPoint = Vector2.new(0.5, 0)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = miniGameRoot

	-- === ITEM PREVIEW - Small, contextual ===
	local itemFrame = Instance.new("Frame")
	itemFrame.Name = "ItemFrame"
	itemFrame.Size = UDim2.fromOffset(64, 64)
	itemFrame.Position = UDim2.fromScale(0.5, 0)
	itemFrame.AnchorPoint = Vector2.new(0.5, 0)
	itemFrame.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	itemFrame.BackgroundTransparency = 0.3
	itemFrame.BorderSizePixel = 0
	itemFrame.Parent = centerContainer
	self.itemFrame = itemFrame

	-- Close button (matching completion UI)
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
	self.cancelButton = closeBtn
	closeIcon:Destroy()

	local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 90}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, rotationTweenInfo, {Rotation = 0}):Play()
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:OnCancelSmelt()
	end)

	local itemCorner = Instance.new("UICorner")
	itemCorner.CornerRadius = UDim.new(0, 8)
	itemCorner.Parent = itemFrame

	-- Item border (subtle temperature feedback)
	local itemGlow = Instance.new("UIStroke")
	itemGlow.Color = SMITHING_LAYOUT.COLD_COLOR
	itemGlow.Thickness = 3
	itemGlow.Transparency = 0.2
	itemGlow.Parent = itemFrame
	self.itemGlow = itemGlow

	-- Item viewport
	local itemViewport = Instance.new("Frame")
	itemViewport.Name = "ItemViewport"
	itemViewport.Size = UDim2.new(1, -12, 1, -12)
	itemViewport.Position = UDim2.fromScale(0.5, 0.5)
	itemViewport.AnchorPoint = Vector2.new(0.5, 0.5)
	itemViewport.BackgroundTransparency = 1
	itemViewport.Parent = itemFrame
	self.itemViewport = itemViewport

	-- Hidden compatibility elements removed (no visible usage)

	-- === HEAT BAR - THE MAIN INTERACTION ===
	local heatBar = Instance.new("Frame")
	heatBar.Name = "HeatBar"
	heatBar.Size = UDim2.new(1, 0, 0, 28)
	heatBar.Position = UDim2.new(0.5, 0, 0, 76)
	heatBar.AnchorPoint = Vector2.new(0.5, 0)
	heatBar.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	heatBar.BackgroundTransparency = 0.2
	heatBar.BorderSizePixel = 0
	heatBar.Parent = centerContainer
	self.temperatureGauge = heatBar

	local heatBarCorner = Instance.new("UICorner")
	heatBarCorner.CornerRadius = UDim.new(0, 6)
	heatBarCorner.Parent = heatBar

	-- Target zone
	local zoneFrame = Instance.new("Frame")
	zoneFrame.Name = "OptimalZone"
	zoneFrame.Size = UDim2.new(0.25, 0, 1, -4)
	zoneFrame.Position = UDim2.fromScale(0.375, 0.5)
	zoneFrame.AnchorPoint = Vector2.new(0, 0.5)
	zoneFrame.BackgroundColor3 = SMITHING_LAYOUT.ZONE_COLOR
	zoneFrame.BackgroundTransparency = 0.55
	zoneFrame.BorderSizePixel = 0
	zoneFrame.ZIndex = 2
	zoneFrame.Parent = heatBar
	self.zoneFrame = zoneFrame

	local zoneCorner = Instance.new("UICorner")
	zoneCorner.CornerRadius = UDim.new(0, 4)
	zoneCorner.Parent = zoneFrame
	-- No zone glow element in this simplified UI

	-- Indicator (taller, more visible)
	local indicatorFrame = Instance.new("Frame")
	indicatorFrame.Name = "Indicator"
	indicatorFrame.Size = UDim2.new(0, 4, 1, -4)
	indicatorFrame.Position = UDim2.fromScale(0.4, 0.5)
	indicatorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	indicatorFrame.BackgroundColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	indicatorFrame.BorderSizePixel = 0
	indicatorFrame.ZIndex = 3
	indicatorFrame.Parent = heatBar
	self.indicatorFrame = indicatorFrame

	local indicatorCorner = Instance.new("UICorner")
	indicatorCorner.CornerRadius = UDim.new(0, 3)
	indicatorCorner.Parent = indicatorFrame
	-- No indicator glow element in this simplified UI

	-- === PROGRESS BAR ===
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, 0, 0, 4)
	progressBar.Position = UDim2.new(0.5, 0, 0, 130)
	progressBar.AnchorPoint = Vector2.new(0.5, 0)
	progressBar.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	progressBar.BackgroundTransparency = 0.5
	progressBar.BorderSizePixel = 0
	progressBar.Parent = centerContainer
	self.progressBar = progressBar

	local progressCorner = Instance.new("UICorner")
	progressCorner.CornerRadius = UDim.new(0, 3)
	progressCorner.Parent = progressBar

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.fromScale(0, 1)
	progressFill.BackgroundColor3 = SMITHING_LAYOUT.ZONE_COLOR
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBar
	self.progressFill = progressFill

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = progressFill

	-- === COUNTDOWN STATUS ===
	local statsLine = Instance.new("TextLabel")
	statsLine.Name = "StatsLine"
	statsLine.Size = UDim2.new(1, 0, 0, 20)
	statsLine.Position = UDim2.new(0.5, 0, 0, 144)
	statsLine.AnchorPoint = Vector2.new(0.5, 0)
	statsLine.BackgroundTransparency = 1
	statsLine.Font = BOLD_FONT
	statsLine.TextSize = 14
	statsLine.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	statsLine.Text = "TIME: --"
	statsLine.Parent = centerContainer
	self.statsLine = statsLine
	self.efficiencyDisplay = nil
	self.efficiencyFill = progressFill

	-- === BOTTOM: Hint ===
	local bottomRow = Instance.new("Frame")
	bottomRow.Name = "BottomRow"
	bottomRow.Size = UDim2.new(1, 0, 0, 20)
	bottomRow.Position = UDim2.new(0.5, 0, 0, 165)
	bottomRow.AnchorPoint = Vector2.new(0.5, 0)
	bottomRow.BackgroundTransparency = 1
	bottomRow.Parent = centerContainer

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.Size = UDim2.fromScale(0.5, 1)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = BOLD_FONT
	hintLabel.TextSize = 11
	hintLabel.TextColor3 = SMITHING_LAYOUT.TEXT_MUTED
	hintLabel.TextTransparency = 0.5
	hintLabel.Text = "HOLD TO SPEED"
	hintLabel.TextXAlignment = Enum.TextXAlignment.Left
	hintLabel.Parent = bottomRow
	self.hintLabel = hintLabel
end

function SmithingUI:CreateCompletionPanel()
	-- Completion root (full screen container)
	local completionRoot = Instance.new("Frame")
	completionRoot.Name = "CompletionRoot"
	completionRoot.Size = UDim2.fromScale(1, 1)
	completionRoot.Position = UDim2.fromScale(0, 0)
	completionRoot.BackgroundTransparency = 1
	completionRoot.Visible = false
	completionRoot.Parent = self.gui
	self.completionPanel = completionRoot

	-- Central content container - matches mini-game width for visual continuity
	local completionLayout = {
		topPadding = 0,
		headerHeight = SMITHING_LAYOUT.HEADER_HEIGHT,
		headerToItem = 28,
		itemSize = 100,
		itemToLabel = 24,
		labelHeight = 28,
		labelToEff = 12,
		effHeight = 22,
		effToButtons = 28,
		buttonsHeight = 44
	}
	local contentHeight = completionLayout.topPadding
		+ completionLayout.headerHeight
		+ completionLayout.headerToItem
		+ completionLayout.itemSize
		+ completionLayout.itemToLabel
		+ completionLayout.labelHeight
		+ completionLayout.labelToEff
		+ completionLayout.effHeight
		+ completionLayout.effToButtons
		+ completionLayout.buttonsHeight

	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.fromOffset(SMITHING_LAYOUT.TOTAL_WIDTH, contentHeight)
	contentContainer.Position = UDim2.fromScale(0.5, 0.5)
	contentContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = completionRoot
	self.completionContent = contentContainer

	-- Header (matches inventory UI pattern)
	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "Header"
	headerFrame.Size = UDim2.new(1, 0, 0, completionLayout.headerHeight)
	headerFrame.Position = UDim2.fromOffset(0, completionLayout.topPadding)
	headerFrame.BackgroundTransparency = 1
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = contentContainer

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -50, 1, 0)
	title.Position = UDim2.fromScale(0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.Code
	title.TextSize = HEADING_SIZE
	title.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	title.Text = "SMELT COMPLETE"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.Parent = headerFrame
	FontBinder.apply(title, CUSTOM_FONT_NAME)
	self.completionTitle = title

	-- === HERO SECTION: Item Display ===
	-- Centered output item frame
	local outputFrame = Instance.new("Frame")
	outputFrame.Name = "OutputFrame"
	outputFrame.Size = UDim2.fromOffset(completionLayout.itemSize, completionLayout.itemSize)
	outputFrame.Position = UDim2.new(0.5, 0, 0, completionLayout.topPadding + completionLayout.headerHeight + completionLayout.headerToItem)
	outputFrame.AnchorPoint = Vector2.new(0.5, 0)
	outputFrame.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	outputFrame.BackgroundTransparency = 0.15
	outputFrame.BorderSizePixel = 0
	outputFrame.Parent = contentContainer
	self.outputFrame = outputFrame

	local outputCorner = Instance.new("UICorner")
	outputCorner.CornerRadius = UDim.new(0, 10)
	outputCorner.Parent = outputFrame

	local outputBorder = Instance.new("UIStroke")
	outputBorder.Color = SMITHING_LAYOUT.BTN_ACCENT
	outputBorder.Thickness = 3
	outputBorder.Parent = outputFrame
	self.outputBorder = outputBorder

	-- Output icon container
	local outputContainer = Instance.new("Frame")
	outputContainer.Name = "OutputContainer"
	outputContainer.Size = UDim2.new(1, -16, 1, -16)
	outputContainer.Position = UDim2.fromScale(0.5, 0.5)
	outputContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	outputContainer.BackgroundTransparency = 1
	outputContainer.Parent = outputFrame
	self.outputContainer = outputContainer

	-- Item count badge - positioned at bottom right
	local countBadge = Instance.new("Frame")
	countBadge.Name = "CountBadge"
	countBadge.Size = UDim2.fromOffset(32, 32)
	countBadge.Position = UDim2.new(1, 6, 1, 6)
	countBadge.AnchorPoint = Vector2.new(1, 1)
	countBadge.BackgroundColor3 = SMITHING_LAYOUT.BTN_ACCENT
	countBadge.BorderSizePixel = 0
	countBadge.ZIndex = 2
	countBadge.Parent = outputFrame
	self.countBadge = countBadge

	local countCorner = Instance.new("UICorner")
	countCorner.CornerRadius = UDim.new(0, 6)
	countCorner.Parent = countBadge

	local countText = Instance.new("TextLabel")
	countText.Name = "CountText"
	countText.Size = UDim2.fromScale(1, 1)
	countText.BackgroundTransparency = 1
	countText.Font = BOLD_FONT
	countText.TextSize = 18
	countText.TextColor3 = Color3.fromRGB(20, 20, 20)
	countText.Text = "+1"
	countText.ZIndex = 3
	countText.Parent = countBadge
	self.outputCountBadge = countText

	-- Item name - clean, centered below item
	local outputLabel = Instance.new("TextLabel")
	outputLabel.Name = "OutputLabel"
	outputLabel.Size = UDim2.new(1, 0, 0, completionLayout.labelHeight)
	outputLabel.Position = UDim2.new(0.5, 0, 0, completionLayout.topPadding + completionLayout.headerHeight + completionLayout.headerToItem + completionLayout.itemSize + completionLayout.itemToLabel)
	outputLabel.AnchorPoint = Vector2.new(0.5, 0)
	outputLabel.BackgroundTransparency = 1
	outputLabel.Font = Enum.Font.Code
	outputLabel.TextSize = 24
	outputLabel.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	outputLabel.Text = "COPPER INGOT"
	outputLabel.Parent = contentContainer
	FontBinder.apply(outputLabel, CUSTOM_FONT_NAME)
	self.outputLabel = outputLabel

	-- Efficiency rating (just the word, colored)
	local effLabel = Instance.new("TextLabel")
	effLabel.Name = "EfficiencyLabel"
	effLabel.Size = UDim2.new(1, 0, 0, completionLayout.effHeight)
	effLabel.Position = UDim2.new(0.5, 0, 0, completionLayout.topPadding + completionLayout.headerHeight + completionLayout.headerToItem + completionLayout.itemSize + completionLayout.itemToLabel + completionLayout.labelHeight + completionLayout.labelToEff)
	effLabel.AnchorPoint = Vector2.new(0.5, 0)
	effLabel.BackgroundTransparency = 1
	effLabel.Font = BOLD_FONT
	effLabel.TextSize = 14
	effLabel.TextColor3 = SMITHING_LAYOUT.ZONE_COLOR
	effLabel.Text = "GREAT"
	effLabel.Parent = contentContainer
	self.efficiencyLabel = effLabel

	-- === BOTTOM: Action Buttons ===
	local btnContainer = Instance.new("Frame")
	btnContainer.Name = "ButtonContainer"
	btnContainer.Size = UDim2.fromOffset(360, completionLayout.buttonsHeight)
	btnContainer.Position = UDim2.new(0.5, 0, 0, completionLayout.topPadding + completionLayout.headerHeight + completionLayout.headerToItem + completionLayout.itemSize + completionLayout.itemToLabel + completionLayout.labelHeight + completionLayout.labelToEff + completionLayout.effHeight + completionLayout.effToButtons)
	btnContainer.AnchorPoint = Vector2.new(0.5, 0)
	btnContainer.BackgroundTransparency = 1
	btnContainer.Parent = contentContainer
	self.completionBtnContainer = btnContainer

	-- Smelt Again button (primary action)
	self.smeltAgainBtn = CreateStyledButton({
		name = "SmeltAgain",
		text = "SMELT AGAIN",
		size = UDim2.fromOffset(150, 44),
		position = UDim2.fromScale(0, 0),
		style = "accent",
		parent = btnContainer,
		onClick = function()
			self:OnSmeltAgain()
		end
	})

	-- Auto-smelt toggle (secondary action)
	self.autoSmeltBtn = CreateStyledButton({
		name = "AutoSmelt",
		text = "AUTO: OFF",
		size = UDim2.fromOffset(90, 44),
		position = UDim2.fromOffset(160, 0),
		style = "default",
		parent = btnContainer,
		onClick = function()
			self:SetAutoSmeltEnabled(not self.autoSmeltEnabled)
		end
	})

	-- Recipes button (secondary action)
	self.recipesBtn = CreateStyledButton({
		name = "Recipes",
		text = "RECIPES",
		size = UDim2.fromOffset(110, 44),
		position = UDim2.fromOffset(250, 0),
		style = "default",
		parent = btnContainer,
		onClick = function()
			self:ShowRecipeSelection()
		end
	})

	-- Close button (matching inventory/worlds UI)
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
	self.completionCloseBtn = closeBtn
	closeIcon:Destroy()

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
end

-- === Recipe Card Creation ===

function SmithingUI:CreateRecipeCard(recipe, index)
	local card = Instance.new("TextButton")
	card.Name = "Recipe_" .. recipe.recipeId
	card.Size = UDim2.fromOffset(SMITHING_LAYOUT.RECIPE_CELL_SIZE, SMITHING_LAYOUT.RECIPE_CELL_SIZE)
	card.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
	card.BackgroundTransparency = recipe.canCraft and SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY or 0.6
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.LayoutOrder = index
	card.Parent = self.recipeGrid

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, SMITHING_LAYOUT.SLOT_CORNER_RADIUS)
	corner.Parent = card

	-- Selection/hover border
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = recipe.canCraft and SMITHING_LAYOUT.BTN_ACCENT or SMITHING_LAYOUT.SLOT_BORDER_COLOR
	border.Thickness = SMITHING_LAYOUT.SLOT_BORDER_THICKNESS
	border.Transparency = recipe.canCraft and 0.6 or 0
	border.Parent = card

	-- Icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, -8, 1, -8)
	iconContainer.Position = UDim2.fromScale(0.5, 0.5)
	iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = card

	-- Create block viewport for output item
	BlockViewportCreator.CreateBlockViewport(iconContainer, recipe.outputItemId, UDim2.fromScale(1, 1))

	-- Fuel cost indicator (small coal icon with number)
	local fuelBadge = Instance.new("Frame")
	fuelBadge.Name = "FuelBadge"
	fuelBadge.Size = UDim2.fromOffset(24, 14)
	fuelBadge.Position = UDim2.new(1, -4, 1, -4)
	fuelBadge.AnchorPoint = Vector2.new(1, 1)
	fuelBadge.BackgroundColor3 = recipe.hasEnoughFuel and SMITHING_LAYOUT.SLOT_BG_COLOR or Color3.fromRGB(100, 40, 40)
	fuelBadge.BackgroundTransparency = 0.2
	fuelBadge.BorderSizePixel = 0
	fuelBadge.ZIndex = 4
	fuelBadge.Parent = card

	local fuelCorner = Instance.new("UICorner")
	fuelCorner.CornerRadius = UDim.new(0, 3)
	fuelCorner.Parent = fuelBadge

	local fuelText = Instance.new("TextLabel")
	fuelText.Name = "FuelText"
	fuelText.Size = UDim2.fromScale(1, 1)
	fuelText.BackgroundTransparency = 1
	fuelText.Font = Enum.Font.GothamBold
	fuelText.TextSize = 10
	fuelText.Text = "×" .. (recipe.fuelCost or 1)
	fuelText.TextColor3 = recipe.hasEnoughFuel and SMITHING_LAYOUT.BTN_ACCENT or SMITHING_LAYOUT.HOT_COLOR
	fuelText.ZIndex = 5
	fuelText.Parent = fuelBadge

	-- Disabled overlay
	if not recipe.canCraft then
		local overlay = Instance.new("Frame")
		overlay.Name = "DisabledOverlay"
		overlay.Size = UDim2.fromScale(1, 1)
		overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		overlay.BackgroundTransparency = 0.5
		overlay.BorderSizePixel = 0
		overlay.ZIndex = 3
		overlay.Parent = card

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, SMITHING_LAYOUT.SLOT_CORNER_RADIUS)
		overlayCorner.Parent = overlay
	end

	-- Hover effects
	card.MouseEnter:Connect(function()
		if recipe.canCraft then
			border.Transparency = 0
			TweenService:Create(card, TweenInfo.new(0.1), {
				BackgroundColor3 = SMITHING_LAYOUT.SLOT_HOVER_COLOR
			}):Play()
		end
	end)

	card.MouseLeave:Connect(function()
		if self.selectedRecipe ~= recipe then
			border.Transparency = recipe.canCraft and 0.6 or 0
			TweenService:Create(card, TweenInfo.new(0.1), {
				BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
			}):Play()
		end
	end)

	-- Click to select
	card.MouseButton1Click:Connect(function()
		self:SelectRecipe(recipe, card)
	end)

	self.recipeCards[recipe.recipeId] = {card = card, border = border, recipe = recipe}
end

function SmithingUI:SelectRecipe(recipe, card)
	-- Deselect previous
	if self.selectedRecipeCard then
		local prevData = self.recipeCards[self.selectedRecipe.recipeId]
		if prevData then
			prevData.border.Transparency = self.selectedRecipe.canCraft and 0.6 or 0
			prevData.border.Color = self.selectedRecipe.canCraft and SMITHING_LAYOUT.BTN_ACCENT or SMITHING_LAYOUT.SLOT_BORDER_COLOR
			prevData.card.BackgroundColor3 = SMITHING_LAYOUT.SLOT_BG_COLOR
		end
	end

	-- Select new
	self.selectedRecipe = recipe
	self.selectedRecipeCard = card

	local cardData = self.recipeCards[recipe.recipeId]
	if cardData then
		cardData.border.Transparency = 0
		cardData.border.Color = SMITHING_LAYOUT.BTN_ACCENT
		cardData.card.BackgroundColor3 = SMITHING_LAYOUT.SLOT_HOVER_COLOR
	end

	-- Update info panel
	self:UpdateRecipeInfo(recipe)
end

function SmithingUI:UpdateRecipeInfo(recipe)
	-- Update name
	self.recipeNameLabel.Text = recipe.name

	-- Clear existing ingredients
	for _, child in pairs(self.ingredientsFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	-- Create ingredient displays (ore, dust, etc.)
	for i, ing in ipairs(recipe.ingredients) do
		local ingFrame = Instance.new("Frame")
		ingFrame.Name = "Ingredient" .. i
		ingFrame.Size = UDim2.fromOffset(80, 44)
		ingFrame.BackgroundTransparency = 1
		ingFrame.LayoutOrder = i
		ingFrame.Parent = self.ingredientsFrame

		-- Icon
		local iconFrame = Instance.new("Frame")
		iconFrame.Name = "Icon"
		iconFrame.Size = UDim2.fromOffset(36, 36)
		iconFrame.Position = UDim2.fromScale(0, 0.5)
		iconFrame.AnchorPoint = Vector2.new(0, 0.5)
		iconFrame.BackgroundTransparency = 1
		iconFrame.Parent = ingFrame

		BlockViewportCreator.CreateBlockViewport(iconFrame, ing.itemId, UDim2.fromScale(1, 1))

		-- Count label
		local countLabel = Instance.new("TextLabel")
		countLabel.Name = "Count"
		countLabel.Size = UDim2.new(0, 40, 1, 0)
		countLabel.Position = UDim2.fromOffset(40, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Font = BOLD_FONT
		countLabel.TextSize = 16
		countLabel.TextXAlignment = Enum.TextXAlignment.Left
		countLabel.Text = ing.owned .. "/" .. ing.required
		countLabel.TextColor3 = ing.owned >= ing.required and SMITHING_LAYOUT.ZONE_COLOR or Color3.fromRGB(255, 100, 100)
		countLabel.Parent = ingFrame
	end

	-- Add fuel display (Coal - shown separately as "Fuel")
	local fuelCost = recipe.fuelCost or 1
	local fuelOwned = recipe.fuelOwned or 0

	local fuelFrame = Instance.new("Frame")
	fuelFrame.Name = "FuelDisplay"
	fuelFrame.Size = UDim2.fromOffset(120, 44)
	fuelFrame.BackgroundTransparency = 1
	fuelFrame.LayoutOrder = 100 -- After ingredients
	fuelFrame.Parent = self.ingredientsFrame

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.fromOffset(1, 32)
	divider.Position = UDim2.fromScale(0, 0.5)
	divider.AnchorPoint = Vector2.new(0, 0.5)
	divider.BackgroundColor3 = SMITHING_LAYOUT.COLUMN_BORDER_COLOR
	divider.BorderSizePixel = 0
	divider.Parent = fuelFrame

	-- Fuel icon (coal)
	local fuelIcon = Instance.new("Frame")
	fuelIcon.Name = "FuelIcon"
	fuelIcon.Size = UDim2.fromOffset(28, 28)
	fuelIcon.Position = UDim2.new(0, 10, 0.5, 0)
	fuelIcon.AnchorPoint = Vector2.new(0, 0.5)
	fuelIcon.BackgroundTransparency = 1
	fuelIcon.Parent = fuelFrame
	BlockViewportCreator.CreateBlockViewport(fuelIcon, 32, UDim2.fromScale(1, 1)) -- 32 = COAL

	-- Fuel label with savings hint
	local fuelLabel = Instance.new("TextLabel")
	fuelLabel.Name = "FuelLabel"
	fuelLabel.Size = UDim2.new(0, 75, 1, 0)
	fuelLabel.Position = UDim2.fromOffset(42, 0)
	fuelLabel.BackgroundTransparency = 1
	fuelLabel.Font = BOLD_FONT
	fuelLabel.TextSize = 14
	fuelLabel.TextXAlignment = Enum.TextXAlignment.Left
	fuelLabel.RichText = true

	local hasEnoughFuel = fuelOwned >= fuelCost
	if hasEnoughFuel then
		fuelLabel.Text = string.format("<font color='#88FF88'>%d/%d</font>\n<font size='11' color='#AAAAAA'>FUEL</font>", fuelOwned, fuelCost)
	else
		fuelLabel.Text = string.format("<font color='#FF6666'>%d/%d</font>\n<font size='11' color='#AAAAAA'>FUEL</font>", fuelOwned, fuelCost)
	end
	fuelLabel.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
	fuelLabel.Parent = fuelFrame

	-- Update button state with clearer messaging
	if recipe.canCraft then
		SetButtonDisabled(self.startButton, false)
	self.startButton.Text = "SMELT"
	else
		local disabledText = "UNAVAILABLE"
		if not recipe.hasIngredients then
			disabledText = "NEED ITEMS"
		elseif not recipe.hasEnoughFuel then
			disabledText = "NEED FUEL"
		end
		SetButtonDisabled(self.startButton, true, disabledText)
	end
end

-- === Mini-Game Logic ===

function SmithingUI:StartMiniGame(smeltConfig)
	if not smeltConfig then
		warn("[SmithingUI] StartMiniGame: smeltConfig is nil!")
		return
	end

	self.isSmelting = true
	self.smeltConfig = smeltConfig

	-- Reset state
	self.indicator = SmithingConfig.Gauge.START_POSITION
	self.zoneCenter = 50
	self.driftDirection = 1
	self.progress = 0
	self.totalTime = 0
	self.fastDuration = smeltConfig.smeltTime or 4
	self.autoDuration = self.fastDuration * SmithingConfig.Countdown.IDLE_MULTIPLIER
	self.timeRemaining = self.autoDuration
	self.isHeating = false

	-- Switch to immersive smelting mode (darker backdrop)
	UIVisibilityManager:SetMode("smithing")

	-- Create item viewport
	if self.itemViewport then
		for _, child in pairs(self.itemViewport:GetChildren()) do
			child:Destroy()
		end
		if smeltConfig.outputItemId then
			BlockViewportCreator.CreateBlockViewport(self.itemViewport, smeltConfig.outputItemId, UDim2.fromScale(1, 1))
		end
	end

	-- Reset visuals and state
	self.wasInZone = false
	if self.itemGlow then
		self.itemGlow.Color = SMITHING_LAYOUT.COLD_COLOR
		self.itemGlow.Thickness = 3
		self.itemGlow.Transparency = 0.2
	end
	if self.itemFrame then
		self.itemFrame.Size = UDim2.fromOffset(64, 64)
	end
	if self.progressFill then
		self.progressFill.Size = UDim2.fromScale(0, 1)
		self.progressFill.BackgroundColor3 = SMITHING_LAYOUT.BAR_IDLE_COLOR
	end
	if self.progressBar then
		self.progressBar.Size = UDim2.new(1, 0, 0, 4)
	end
	if self.statsLine then
		self.statsLine.Text = string.format("TIME %.1fs", self.timeRemaining)
		self.statsLine.TextColor3 = SMITHING_LAYOUT.TIME_IDLE_COLOR
	end

	-- Reset indicator position
	if self.indicatorFrame then
		self.indicatorFrame.Position = UDim2.fromScale(SmithingConfig.Gauge.START_POSITION / 100, 0.5)
		self.indicatorFrame.BackgroundColor3 = SMITHING_LAYOUT.COLD_COLOR
	end

	-- Show mini-game panel, hide others
	if self.panel then
		self.panel.Visible = false
	end
	if self.miniGamePanel then
		self.miniGamePanel.Visible = true
	else
		warn("[SmithingUI] miniGamePanel is nil! Cannot show mini-game UI")
		return
	end
	if self.completionPanel then
		self.completionPanel.Visible = false
	end

	-- Ensure GUI is enabled
	if self.gui then
		self.gui.Enabled = true
	end

	-- Update zone width based on recipe difficulty
	if self.zoneFrame and smeltConfig.zoneWidth then
		local zoneWidth = smeltConfig.zoneWidth / 100
		self.zoneFrame.Size = UDim2.new(zoneWidth, 0, 1, -4)
	end

	-- Start update loop
	self.updateConnection = RunService.RenderStepped:Connect(function(dt)
		self:UpdateMiniGame(dt)
	end)
end

function SmithingUI:UpdateMiniGame(dt)
	if not self.isSmelting or not self.smeltConfig then
		return
	end

	local config = self.smeltConfig

	-- Update zone drift
	self.zoneCenter = self.zoneCenter + (self.driftDirection * config.driftSpeed * dt)
	if self.zoneCenter >= SmithingConfig.ZoneDrift.MAX then
		self.zoneCenter = SmithingConfig.ZoneDrift.MAX
		self.driftDirection = -1
	elseif self.zoneCenter <= SmithingConfig.ZoneDrift.MIN then
		self.zoneCenter = SmithingConfig.ZoneDrift.MIN
		self.driftDirection = 1
	end

	-- Update temperature indicator
	if self.isHeating then
		self.indicator = self.indicator + (SmithingConfig.Gauge.HEAT_RATE * dt)
	else
		self.indicator = self.indicator - (SmithingConfig.Gauge.COOL_RATE * dt)
	end
	self.indicator = math.clamp(self.indicator, SmithingConfig.Gauge.MIN, SmithingConfig.Gauge.MAX)

	-- Countdown progress: auto smelts, interaction speeds it up
	local countdownRate = self.isHeating and SmithingConfig.Countdown.IDLE_MULTIPLIER or 1
	self.timeRemaining = math.max(self.timeRemaining - (countdownRate * dt), 0)
	self.totalTime = self.totalTime + dt

	-- Update progress
	local progressPercent = 0
	if self.autoDuration and self.autoDuration > 0 then
		progressPercent = (1 - (self.timeRemaining / self.autoDuration)) * 100
	end
	self.progress = math.clamp(progressPercent, 0, 100)

	-- Update UI
	self:UpdateMiniGameUI()

	-- Check completion
	if self.timeRemaining <= 0 then
		self:CompleteMiniGame()
	end
end

function SmithingUI:UpdateMiniGameUI()
	-- Update zone position (smooth movement)
	local zoneWidth = self.smeltConfig.zoneWidth / 100
	local zonePos = (self.zoneCenter - (self.smeltConfig.zoneWidth / 2)) / 100
	self.zoneFrame.Size = UDim2.new(zoneWidth, 0, 1, -4)

	-- Smooth zone drift
	local targetZonePos = UDim2.fromScale(zonePos, 0.5)
	local currentZonePos = self.zoneFrame.Position
	self.zoneFrame.Position = UDim2.new(
		currentZonePos.X.Scale + (targetZonePos.X.Scale - currentZonePos.X.Scale) * 0.15,
		0, 0.5, 0
	)

	-- Smooth indicator position (adds weight/momentum feel)
	local indicatorPos = self.indicator / 100
	local currentPos = self.indicatorFrame.Position.X.Scale
	local smoothPos = currentPos + (indicatorPos - currentPos) * 0.25
	self.indicatorFrame.Position = UDim2.fromScale(smoothPos, 0.5)

	-- Zone check
	local zoneMin = self.zoneCenter - (self.smeltConfig.zoneWidth / 2)
	local zoneMax = self.zoneCenter + (self.smeltConfig.zoneWidth / 2)
	local inZone = self.indicator >= zoneMin and self.indicator <= zoneMax

	-- Detect zone entry/exit for animations
	local wasInZone = self.wasInZone or false
	if inZone and not wasInZone then
		self:OnEnterZone()
	elseif not inZone and wasInZone then
		self:OnExitZone()
	end
	self.wasInZone = inZone

	-- Temperature color (cold blue → orange → hot red)
	local t = self.indicator / 100
	local tempColor
	if t < 0.5 then
		tempColor = SMITHING_LAYOUT.COLD_COLOR:Lerp(Color3.fromRGB(255, 180, 80), t * 2)
	else
		tempColor = Color3.fromRGB(255, 180, 80):Lerp(SMITHING_LAYOUT.HOT_COLOR, (t - 0.5) * 2)
	end

	-- Item border: subtle temperature feedback
	if self.itemGlow then
		local targetColor = inZone and SMITHING_LAYOUT.ZONE_COLOR or tempColor
		self.itemGlow.Color = self.itemGlow.Color:Lerp(targetColor, 0.2)
		self.itemGlow.Transparency = inZone and 0 or 0.2
	end

	-- Indicator color (smooth)
	local targetIndicatorColor = inZone and SMITHING_LAYOUT.ZONE_COLOR or tempColor
	self.indicatorFrame.BackgroundColor3 = self.indicatorFrame.BackgroundColor3:Lerp(targetIndicatorColor, 0.3)

	-- Zone pulse when inside (subtle breathing)
	local baseTransparency = inZone and 0.35 or 0.6
	if inZone then
		local pulse = math.sin(tick() * 4) * 0.08
		self.zoneFrame.BackgroundTransparency = baseTransparency + pulse
	else
		self.zoneFrame.BackgroundTransparency = baseTransparency
	end

	-- Progress bar (color = speed, smooth)
	local speedColor = self.isHeating and SMITHING_LAYOUT.BAR_ACTIVE_COLOR or SMITHING_LAYOUT.BAR_IDLE_COLOR
	local targetSize = self.progress / 100
	local currentSize = self.progressFill.Size.X.Scale
	self.progressFill.Size = UDim2.fromScale(currentSize + (targetSize - currentSize) * 0.15, 1)
	self.progressFill.BackgroundColor3 = self.progressFill.BackgroundColor3:Lerp(speedColor, 0.1)

	-- Near completion excitement (progress > 90%)
	if self.progress > 90 then
		local pulse = 1 + math.sin(tick() * 8) * 0.03
		self.progressBar.Size = UDim2.new(1, 0, 0, 4 * pulse)
	else
		self.progressBar.Size = UDim2.new(1, 0, 0, 4)
	end

	-- Countdown text (bar shows progress)
	if self.statsLine then
		local timeLeft = math.max(self.timeRemaining or 0, 0)
		self.statsLine.Text = string.format("TIME %.1fs", timeLeft)
		self.statsLine.TextColor3 = self.isHeating and SMITHING_LAYOUT.TIME_ACTIVE_COLOR or SMITHING_LAYOUT.TIME_IDLE_COLOR
	end

	-- Hint feedback
	if self.hintLabel then
		if self.isHeating then
			self.hintLabel.Text = "BOOST"
			self.hintLabel.TextColor3 = SMITHING_LAYOUT.ZONE_COLOR
			self.hintLabel.TextTransparency = 0
		else
			self.hintLabel.Text = "AUTO - HOLD TO SPEED"
			self.hintLabel.TextColor3 = SMITHING_LAYOUT.TEXT_MUTED
			self.hintLabel.TextTransparency = 0.4
		end
	end

end

-- Called when indicator enters the optimal zone
function SmithingUI:OnEnterZone()
	-- Play subtle "in zone" sound
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("buttonClick", 1.3, 0.3)
	end

	-- Quick pulse on item frame (subtle)
	if self.itemFrame then
		TweenService:Create(self.itemFrame, TweenInfo.new(0.08, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(70, 70)
		}):Play()
		task.delay(0.08, function()
			if self.itemFrame then
				TweenService:Create(self.itemFrame, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(64, 64)
				}):Play()
			end
		end)
	end
	-- Also pulse the item glow
	if self.itemGlow then
		self.itemGlow.Thickness = 4
	end
end

-- Called when indicator exits the optimal zone
function SmithingUI:OnExitZone()
	-- Play subtle "exit zone" sound (lower pitch)
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("buttonClick", 0.8, 0.2)
	end

	if self.itemFrame then
		TweenService:Create(self.itemFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(64, 64)
		}):Play()
	end
	if self.itemGlow then
		self.itemGlow.Thickness = 3
	end
end

-- Helper to get efficiency rating and color
function SmithingUI:GetEfficiencyRating(percent)
	if percent >= 90 then
		return "PERFECT", SMITHING_LAYOUT.ZONE_COLOR
	elseif percent >= 75 then
		return "GREAT", Color3.fromRGB(180, 255, 100)
	elseif percent >= 60 then
		return "GOOD", Color3.fromRGB(255, 220, 100)
	elseif percent >= 40 then
		return "FAIR", Color3.fromRGB(255, 180, 100)
	else
		return "POOR", Color3.fromRGB(255, 100, 100)
	end
end

function SmithingUI:CompleteMiniGame()
	-- Stop update loop
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	self.isSmelting = false

	-- Play immediate completion feedback sound
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("inventoryPop", 1.2, 0.7)
	end

	-- Calculate efficiency percentage based on completion speed
	local efficiencyPercent = 0
	local autoDuration = self.autoDuration or 0
	local fastDuration = self.fastDuration or autoDuration
	if autoDuration > fastDuration and self.totalTime > 0 then
		local normalized = (autoDuration - self.totalTime) / (autoDuration - fastDuration)
		efficiencyPercent = math.clamp(normalized * 100, 0, 100)
	end

	-- Return to standard furnace mode (less dark backdrop)
	UIVisibilityManager:SetMode("smithing")

	-- Send completion to server
	EventManager:SendToServer("RequestCompleteSmith", {
		furnacePos = self.anvilPosition,
		efficiencyPercent = efficiencyPercent
	})
end

function SmithingUI:OnCancelSmelt()
	self:CancelAutoSmeltTimer()

	-- Stop update loop
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	self.isSmelting = false

	-- Return to standard furnace mode (less dark backdrop)
	UIVisibilityManager:SetMode("smithing")

	-- Send cancel to server
	EventManager:SendToServer("RequestCancelSmith", {
		furnacePos = self.anvilPosition
	})

	-- Return to recipe selection
	self:ShowRecipeSelection()
end

function SmithingUI:ShowCompletion(data)
	self.panel.Visible = false
	self.miniGamePanel.Visible = false
	self.completionPanel.Visible = true

	-- Store last smelted recipe for "Smelt Again" functionality
	if self.selectedRecipe then
		self.lastSmeltedRecipeId = self.selectedRecipe.recipeId
	end

	-- Get data
	local stats = data.stats
	local ratingColor = Color3.fromRGB(stats.color[1], stats.color[2], stats.color[3])
	local _efficiencyPercent = math.floor(stats.efficiencyPercent)
	local blockDef = BlockRegistry.Blocks[data.outputItemId]
	local itemName = blockDef and blockDef.name or "Item"

	-- Set border color based on efficiency
	self.outputBorder.Color = ratingColor

	-- Set values
	self.outputLabel.Text = string.upper(itemName)
	self.outputCountBadge.Text = "+" .. data.outputCount
	self.efficiencyLabel.Text = stats.rating
	self.efficiencyLabel.TextColor3 = ratingColor

	-- Clear and create item viewport
	for _, child in pairs(self.outputContainer:GetChildren()) do
		if not child:IsA("UICorner") and not child:IsA("UIStroke") then
			child:Destroy()
		end
	end
	BlockViewportCreator.CreateBlockViewport(self.outputContainer, data.outputItemId, UDim2.fromScale(1, 1))

	self:UpdateAutoSmeltButton()

	-- Play reveal animation
	self:PlayRevealAnimation()

	-- Update auto-smelt UI and kick off timer if enabled
	self:StartAutoSmeltTimer()
end

-- Play particle burst effect around an element (similar to crafting)
function SmithingUI:PlayParticleBurstEffect(parent, color, particleCount)
	particleCount = particleCount or 12
	color = color or SMITHING_LAYOUT.BTN_ACCENT

	for i = 1, particleCount do
		local particle = Instance.new("Frame")
		particle.Size = UDim2.fromOffset(8, 8)
		particle.Position = UDim2.fromScale(0.5, 0.5)
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundColor3 = color
		particle.BorderSizePixel = 0
		particle.ZIndex = 200
		particle.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle

		-- Random angle with slight variation
		local angle = (i / particleCount) * math.pi * 2 + math.random() * 0.3
		local distance = 90 + math.random() * 30
		local targetX = math.cos(angle) * distance
		local targetY = math.sin(angle) * distance

		-- Animate outward with fade and shrink
		local tween = TweenService:Create(particle, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, targetX, 0.5, targetY),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2)
		})
		tween:Play()

		-- Clean up
		task.delay(0.7, function()
			if particle and particle.Parent then
				particle:Destroy()
			end
		end)
	end
end

-- Play shimmer/sparkle effect on an element
function SmithingUI:PlayShimmerEffect(parent)
	-- Create multiple sparkles that appear and fade
	for i = 1, 6 do
		task.delay(i * 0.1, function()
			local sparkle = Instance.new("Frame")
			sparkle.Size = UDim2.fromOffset(4, 4)
			-- Random position within the parent
			sparkle.Position = UDim2.fromScale(math.random() * 0.8 + 0.1, math.random() * 0.8 + 0.1)
			sparkle.AnchorPoint = Vector2.new(0.5, 0.5)
			sparkle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			sparkle.BorderSizePixel = 0
			sparkle.ZIndex = 210
			sparkle.BackgroundTransparency = 0.3
			sparkle.Parent = parent

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = sparkle

			-- Animate: grow then shrink with fade
			local growTween = TweenService:Create(sparkle, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(10, 10),
				BackgroundTransparency = 0
			})
			growTween:Play()

			task.delay(0.15, function()
				if sparkle and sparkle.Parent then
					local fadeTween = TweenService:Create(sparkle, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						Size = UDim2.fromOffset(2, 2),
						BackgroundTransparency = 1
					})
					fadeTween:Play()
					task.delay(0.25, function()
						if sparkle and sparkle.Parent then
							sparkle:Destroy()
						end
					end)
				end
			end)
		end)
	end
end

-- Create glowing ring pulse effect
function SmithingUI:PlayGlowPulseEffect(frame, color)
	color = color or SMITHING_LAYOUT.BTN_ACCENT

	-- Create expanding ring
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromScale(1, 1)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.BackgroundTransparency = 1
	ring.BorderSizePixel = 0
	ring.ZIndex = 195
	ring.Parent = frame

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(0, 12)
	ringCorner.Parent = ring

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = color
	ringStroke.Thickness = 4
	ringStroke.Transparency = 0.3
	ringStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ringStroke.Parent = ring

	-- Animate ring expanding and fading
	local expandTween = TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(1.6, 1.6)
	})
	local fadeTween = TweenService:Create(ringStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1
	})

	expandTween:Play()
	fadeTween:Play()

	task.delay(0.5, function()
		if ring and ring.Parent then
			ring:Destroy()
		end
	end)
end

-- Enhanced animated reveal sequence with visual effects
function SmithingUI:PlayRevealAnimation()
	local _BOUNCE = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local BOUNCE_BIG = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0)
	local FADE = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	-- Reset states
	self.completionTitle.TextTransparency = 1
	self.outputFrame.Size = UDim2.fromScale(0, 0)
	self.outputFrame.Rotation = -10
	self.countBadge.Size = UDim2.fromScale(0, 0)
	self.outputLabel.TextTransparency = 1
	self.efficiencyLabel.TextTransparency = 1
	self.smeltAgainBtn.BackgroundTransparency = 1
	self.smeltAgainBtn.TextTransparency = 1
	if self.autoSmeltBtn then
		self.autoSmeltBtn.BackgroundTransparency = 1
		self.autoSmeltBtn.TextTransparency = 1
	end
	self.recipesBtn.BackgroundTransparency = 1
	self.recipesBtn.TextTransparency = 1
	self.completionCloseBtn.ImageTransparency = 1

	-- Reset border glow
	if self.outputBorder then
		self.outputBorder.Thickness = 0
	end

	-- Title fades in (0.0s)
	TweenService:Create(self.completionTitle, FADE, {
		TextTransparency = 0
	}):Play()

	-- Close button fades in with title (0.0s)
	TweenService:Create(self.completionCloseBtn, FADE, {
		ImageTransparency = 0
	}):Play()

	-- Item bounces in with rotation (0.1s) - bigger, more dramatic entrance
	task.delay(0.1, function()
		-- Play glow pulse as item appears
		self:PlayGlowPulseEffect(self.outputFrame, self.outputBorder.Color)

		TweenService:Create(self.outputFrame, BOUNCE_BIG, {
			Size = UDim2.fromOffset(100, 100),
			Rotation = 0
		}):Play()

		-- Animate border thickness
		TweenService:Create(self.outputBorder, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Thickness = 3
		}):Play()
	end)

	-- Particle burst effect (0.25s) - when item is mostly visible
	task.delay(0.25, function()
		self:PlayParticleBurstEffect(self.outputFrame, self.outputBorder.Color, 12)
	end)

	-- Shimmer/sparkle effect on item (0.35s)
	task.delay(0.35, function()
		-- Play sparkle/reveal sound
		if SoundManager and SoundManager.PlaySFX then
			SoundManager:PlaySFX("smeltReveal", 1.2, 0.5)
		end

		self:PlayShimmerEffect(self.outputFrame)
	end)

	-- Count badge pops in with overshoot (0.3s)
	task.delay(0.3, function()
		-- Initial overshoot
		TweenService:Create(self.countBadge, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(38, 38)
		}):Play()

		-- Settle to final size
		task.delay(0.2, function()
			TweenService:Create(self.countBadge, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(32, 32)
			}):Play()
		end)
	end)

	-- Item name fades in (0.4s)
	task.delay(0.4, function()
		TweenService:Create(self.outputLabel, FADE, {
			TextTransparency = 0
		}):Play()
	end)

	-- Efficiency label fades in (0.45s)
	task.delay(0.45, function()
		TweenService:Create(self.efficiencyLabel, FADE, {
			TextTransparency = 0
		}):Play()
	end)

	-- Action buttons fade in (0.55s)
	task.delay(0.55, function()
		local autoBgTransparency = self.autoSmeltEnabled and 0 or SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY
		TweenService:Create(self.smeltAgainBtn, FADE, {
			BackgroundTransparency = 0,
			TextTransparency = 0
		}):Play()
		if self.autoSmeltBtn then
			TweenService:Create(self.autoSmeltBtn, FADE, {
				BackgroundTransparency = autoBgTransparency,
				TextTransparency = 0
			}):Play()
		end
		TweenService:Create(self.recipesBtn, FADE, {
			BackgroundTransparency = SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY,
			TextTransparency = 0
		}):Play()
	end)

	-- Start subtle breathing glow on item border
	task.delay(0.6, function()
		self:StartCompletionGlowPulse()
	end)
end

-- Start a subtle pulsing glow on the completed item
function SmithingUI:StartCompletionGlowPulse()
	-- Stop any existing pulse
	self:StopCompletionGlowPulse()

	local border = self.outputBorder
	if not border then return end

	-- Create breathing animation loop
	self._glowPulseConnection = RunService.Heartbeat:Connect(function()
		if not border or not border.Parent then
			self:StopCompletionGlowPulse()
			return
		end

		-- Subtle breathing effect
		local pulse = 3 + math.sin(tick() * 2) * 0.8
		border.Thickness = pulse
	end)
end

-- Stop the completion glow pulse
function SmithingUI:StopCompletionGlowPulse()
	if self._glowPulseConnection then
		self._glowPulseConnection:Disconnect()
		self._glowPulseConnection = nil
	end
end

-- Auto-smelt control helpers
function SmithingUI:CancelAutoSmeltTimer()
	if self.autoSmeltTask then
		task.cancel(self.autoSmeltTask)
		self.autoSmeltTask = nil
	end
	if self.autoSmeltCountdownConnection then
		self.autoSmeltCountdownConnection:Disconnect()
		self.autoSmeltCountdownConnection = nil
	end
	self.autoSmeltEndTime = nil

	if self.smeltAgainBtn then
		self.smeltAgainBtn.Text = "SMELT AGAIN"
	end
end

function SmithingUI:UpdateAutoSmeltButton()
	if not self.autoSmeltBtn then
		return
	end

	local enabled = self.autoSmeltEnabled
	self.autoSmeltBtn.Text = enabled and "AUTO: ON" or "AUTO: OFF"
	if enabled then
		self.autoSmeltBtn.BackgroundColor3 = SMITHING_LAYOUT.BTN_ACCENT
		self.autoSmeltBtn.BackgroundTransparency = 0
	else
		self.autoSmeltBtn.BackgroundColor3 = SMITHING_LAYOUT.BTN_DEFAULT
		self.autoSmeltBtn.BackgroundTransparency = SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY
	end
	self.autoSmeltBtn.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY
end

function SmithingUI:SetAutoSmeltEnabled(enabled)
	self.autoSmeltEnabled = enabled and true or false
	self:UpdateAutoSmeltButton()

	if not self.autoSmeltEnabled then
		self:CancelAutoSmeltTimer()
	elseif self.completionPanel and self.completionPanel.Visible then
		self:StartAutoSmeltTimer()
	end
end

function SmithingUI:StartAutoSmeltTimer()
	self:CancelAutoSmeltTimer()

	if not self.autoSmeltEnabled then
		return
	end

	local delaySeconds = self.autoSmeltDelay or 3
	self.autoSmeltEndTime = tick() + delaySeconds

	-- Countdown text on smelt again button
	if self.smeltAgainBtn then
		self.smeltAgainBtn.Text = string.format("SMELT AGAIN %.1fs", delaySeconds)
	end
	self.autoSmeltCountdownConnection = RunService.Heartbeat:Connect(function()
		if not self.autoSmeltEnabled or not self.autoSmeltEndTime then
			self:CancelAutoSmeltTimer()
			return
		end
		if not self.isOpen or not self.completionPanel or not self.completionPanel.Visible then
			self:CancelAutoSmeltTimer()
			return
		end

		local remaining = math.max(0, self.autoSmeltEndTime - tick())
		if self.smeltAgainBtn then
			self.smeltAgainBtn.Text = string.format("SMELT AGAIN %.1fs", remaining)
		end
	end)

	self.autoSmeltTask = task.delay(delaySeconds, function()
		self.autoSmeltTask = nil
		if self.autoSmeltCountdownConnection then
			self.autoSmeltCountdownConnection:Disconnect()
			self.autoSmeltCountdownConnection = nil
		end

		if not self.autoSmeltEnabled then
			return
		end
		if not self.isOpen or not self.completionPanel or not self.completionPanel.Visible then
			return
		end
		if self.isSmelting or self.isWaitingForSmelt then
			return
		end

		self:OnSmeltAgain()
	end)
end

-- Smelt the same recipe again (if resources available)
function SmithingUI:OnSmeltAgain()
	self:CancelAutoSmeltTimer()

	if not self.lastSmeltedRecipeId then
		-- No previous recipe, go to recipe selection
		self:ShowRecipeSelection()
		return
	end

	-- Check if we can still smelt this recipe
	-- Re-request furnace data to get updated recipe availability
	self.pendingSmeltAgain = true
	EventManager:SendToServer("RequestOpenAnvil", self.anvilPosition)
end

-- Called after receiving updated recipes to check if we can smelt again
function SmithingUI:TrySmeltAgain()
	if not self.pendingSmeltAgain or not self.lastSmeltedRecipeId then
		return false
	end
	self.pendingSmeltAgain = false

	-- Find the recipe in current recipes
	local recipe = nil
	for _, r in ipairs(self.recipes or {}) do
		if r.recipeId == self.lastSmeltedRecipeId then
			recipe = r
			break
		end
	end

	if recipe and recipe.canCraft then
		-- We can smelt again - start immediately
		self.selectedRecipe = recipe
		self:OnStartSmelt()
		return true
	else
		-- Can't smelt again - show recipes with message
		self:ShowRecipeSelection()
		return false
	end
end

function SmithingUI:ShowRecipeSelection()
	-- Stop completion glow pulse
	self:StopCompletionGlowPulse()
	self:CancelAutoSmeltTimer()

	self.panel.Visible = true
	self.miniGamePanel.Visible = false
	self.completionPanel.Visible = false

	-- Reset completion animation states
	if self.completionTitle then
		self.completionTitle.TextTransparency = 0
	end
	if self.outputFrame then
		self.outputFrame.Size = UDim2.fromOffset(120, 120)
	end
	if self.countBadge then
		self.countBadge.Size = UDim2.fromOffset(36, 36)
	end
	if self.outputLabel then
		self.outputLabel.TextTransparency = 0
	end
	if self.efficiencyLabel then
		self.efficiencyLabel.TextTransparency = 0
	end
	if self.smeltAgainBtn then
		self.smeltAgainBtn.BackgroundTransparency = 0
		self.smeltAgainBtn.TextTransparency = 0
	end
	if self.autoSmeltBtn then
		self.autoSmeltBtn.TextTransparency = 0
	end
	if self.recipesBtn then
		self.recipesBtn.BackgroundTransparency = SMITHING_LAYOUT.SLOT_BG_TRANSPARENCY
		self.recipesBtn.TextTransparency = 0
	end
	if self.completionCloseBtn then
		self.completionCloseBtn.ImageTransparency = 0
	end

	self:UpdateAutoSmeltButton()

	-- Re-request recipes (inventory may have changed)
	EventManager:SendToServer("RequestOpenAnvil", self.anvilPosition)
end

-- === Input Handling ===

function SmithingUI:OnStartSmelt()
	self:CancelAutoSmeltTimer()

	if not self.selectedRecipe then
		return
	end

	if not self.selectedRecipe.canCraft then
		return
	end

	if not self.anvilPosition then
		return
	end

	-- Prevent double-clicks
	if self.isWaitingForSmelt then
		return
	end
	self.isWaitingForSmelt = true

	-- Show loading state on button
	if self.startButton then
		self.startButton.Text = "STARTING"
	end

	-- Send start request to server
	EventManager:SendToServer("RequestStartSmith", {
		recipeId = self.selectedRecipe.recipeId,
		furnacePos = self.anvilPosition
	})

	-- Add timeout to reset button if server doesn't respond
	task.delay(5, function()
		if self.isWaitingForSmelt then
			self.isWaitingForSmelt = false
			if self.startButton and self.selectedRecipe and self.selectedRecipe.canCraft then
				self.startButton.Text = "SMELT"
			end
			self:ShowSmeltError("NO RESPONSE")
		end
	end)
end

-- Show error feedback to user
function SmithingUI:ShowSmeltError(message)
	-- Flash the button red briefly with danger style
	if self.startButton then
		self.startButton.BackgroundColor3 = Color3.fromRGB(220, 100, 100)
		self.startButton.BackgroundTransparency = 0
		self.startButton.Text = message or "ERROR"
		self.startButton.TextColor3 = SMITHING_LAYOUT.TEXT_PRIMARY

		task.delay(2, function()
			if self.startButton and self.selectedRecipe then
				if self.selectedRecipe.canCraft then
					SetButtonDisabled(self.startButton, false)
					self.startButton.Text = "SMELT"
				else
					SetButtonDisabled(self.startButton, true, "NEED ITEMS")
				end
			end
		end)
	end
end

function SmithingUI:BindInput()
	-- ESC to close
	table.insert(self.connections, InputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape then
			if self.isOpen then
				if self.isSmelting then
					self:OnCancelSmelt()
				else
					self:Close()
				end
			end
		end
	end))

	-- Mouse/Touch for heating
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if not self.isSmelting then return end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			self.isHeating = true
		end
	end))

	table.insert(self.connections, UserInputService.InputEnded:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			self.isHeating = false
		end
	end))
end

-- === Network Events ===

function SmithingUI:RegisterEvents()
	-- Furnace opened
	EventManager:RegisterEvent("AnvilOpened", function(data)
		self:Open(data)
	end)

	-- Smelt started
	EventManager:RegisterEvent("SmithStarted", function(data)
		-- Reset button state
		self.isWaitingForSmelt = false
		if self.startButton then
			self.startButton.Text = "SMELT"
		end

		if type(data) == "table" then
			if data.error then
				self:ShowSmeltError(data.error)
				return
			end
			if data.smeltConfig then
				local success, err = pcall(function()
					self:StartMiniGame(data.smeltConfig)
				end)
				if not success then
					warn("[SmithingUI] StartMiniGame error:", err)
					self:ShowSmeltError("Failed to start mini-game")
				end
			else
				self:ShowSmeltError("Invalid server response")
			end
		else
			self:ShowSmeltError("Invalid server response")
		end
	end)

	-- Smelt completed
	EventManager:RegisterEvent("SmithCompleted", function(data)
		if data.success then
			self:ShowCompletion(data)
		else
			self:ShowRecipeSelection()
		end
	end)

	-- Smelt cancelled
	EventManager:RegisterEvent("SmithCancelled", function(_data)
		-- Cancelled - just reset state (already handled in OnCancelSmelt)
	end)
end

-- === Lifecycle ===

function SmithingUI:Open(data)
	if not data then
		warn("[SmithingUI] Open called with no data!")
		return
	end

	self.isOpen = true
	self.anvilPosition = {x = data.x, y = data.y, z = data.z}
	self.recipes = data.recipes or {}
	self.selectedRecipe = nil
	self.selectedRecipeCard = nil
	self.isWaitingForSmelt = false

	-- Use UIVisibilityManager to coordinate
	UIVisibilityManager:SetMode("smithing")

	-- Clear existing recipe cards
	for _, cardData in pairs(self.recipeCards) do
		cardData.card:Destroy()
	end
	self.recipeCards = {}

	-- Create recipe cards
	for i, recipe in ipairs(self.recipes) do
		self:CreateRecipeCard(recipe, i)
	end

	-- Auto-select first craftable recipe
	local selectedAny = false
	for _, recipe in ipairs(self.recipes) do
		if recipe.canCraft then
			local cardData = self.recipeCards[recipe.recipeId]
			if cardData then
				self:SelectRecipe(recipe, cardData.card)
				selectedAny = true
			end
			break
		end
	end

	-- If no craftable, select first
	if not selectedAny and #self.recipes > 0 then
		local first = self.recipes[1]
		local cardData = self.recipeCards[first.recipeId]
		if cardData then
			self:SelectRecipe(first, cardData.card)
		end
	end

	-- Check if this was a "Smelt Again" request
	if self:TrySmeltAgain() then
		-- Started smelting again, don't show recipe panel
		return
	end

	-- Show recipe selection panel
	self.panel.Visible = true
	self.miniGamePanel.Visible = false
	self.completionPanel.Visible = false

	-- Enable GUI
	self.gui.Enabled = true
end

function SmithingUI:Close(nextMode)
	local targetMode = nextMode or "gameplay"

	if not self.isOpen then return end

	self:CancelAutoSmeltTimer()

	-- Cancel active smelt if any
	if self.isSmelting then
		self:OnCancelSmelt()
	end

	self.isOpen = false
	self.anvilPosition = nil

	-- Stop update connection
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	-- Stop completion glow pulse
	self:StopCompletionGlowPulse()

	-- Hide GUI
	self.gui.Enabled = false

	-- Restore target mode (gameplay by default)
	UIVisibilityManager:SetMode(targetMode)
end

function SmithingUI:Toggle()
	if self.isOpen then
		self:Close()
	else
		-- Toggle requires furnace position, so we can't just open without data
		-- This is typically not used for SmithingUI since it requires interaction
		warn("[SmithingUI] Toggle called but SmithingUI requires furnace position to open")
	end
end

function SmithingUI:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function SmithingUI:Hide()
	if self.gui then
		self.gui.Enabled = false
	end
end

function SmithingUI:IsOpen()
	return self.isOpen
end

-- Helper for debugging
function SmithingUI:_getKeys(tbl)
	local keys = {}
	for k, _ in pairs(tbl) do
		table.insert(keys, tostring(k))
	end
	return keys
end

function SmithingUI:Cleanup()
	for _, conn in pairs(self.connections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	self.connections = {}

	self:CancelAutoSmeltTimer()

	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	-- Stop completion glow pulse
	self:StopCompletionGlowPulse()

	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return SmithingUI
