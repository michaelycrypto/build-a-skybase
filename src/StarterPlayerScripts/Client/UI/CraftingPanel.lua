--[[
	CraftingPanel.lua
	Crafting UI component with recipe grid and detail panel
	
	Layout matches SmithingUI pattern:
	- Recipe grid at top (scrollable)
	- Recipe details below (ingredients, craft controls)
	
	Features:
	- Displays available recipes as scrollable grid
	- Click recipe to select and show details
	- Quantity controls with craft button
	- Direct-to-inventory crafting
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local CraftingSystem = require(ReplicatedStorage.Shared.VoxelWorld.Crafting.CraftingSystem)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)

local CraftingPanel = {}
CraftingPanel.__index = CraftingPanel

-- Constants
local BOLD_FONT = GameConfig.UI_SETTINGS.typography.fonts.bold
local CUSTOM_FONT_NAME = "Upheaval BRK"
local LABEL_SIZE = 24
local MIN_TEXT_SIZE = 20

-- Layout configuration (matching inventory panel)
local CONFIG = {
	-- Grid
	GRID_CELL_SIZE = 56,
	GRID_SPACING = 5,
	GRID_COLUMNS = 9,
	GRID_ROWS_VISIBLE = 2,
	
	-- Detail section
	DETAIL_HEIGHT = 200,
	INGREDIENT_SIZE = 48,
	INGREDIENT_SPACING = 8,
	BUTTON_HEIGHT = 44,
	
	-- Border/corner styling
	CORNER_RADIUS = 6,
	SLOT_CORNER_RADIUS = 4,
	BORDER_THICKNESS = 2,
	
	-- Colors (consistent with inventory)
	PANEL_BG = Color3.fromRGB(58, 58, 58),
	SLOT_BG = Color3.fromRGB(31, 31, 31),
	SLOT_BG_TRANSPARENCY = 0.4,
	SLOT_HOVER = Color3.fromRGB(80, 80, 80),
	SLOT_SELECTED = Color3.fromRGB(50, 50, 50),
	SLOT_BORDER = Color3.fromRGB(35, 35, 35),
	TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
	TEXT_MUTED = Color3.fromRGB(140, 140, 140),
	TEXT_SUCCESS = Color3.fromRGB(150, 220, 150),
	TEXT_ERROR = Color3.fromRGB(220, 150, 150),
	CRAFT_BTN = Color3.fromRGB(80, 180, 80),
	CRAFT_BTN_HOVER = Color3.fromRGB(90, 200, 90),
	CRAFT_BTN_DISABLED = Color3.fromRGB(60, 60, 60),
	
	-- Background
	BG_IMAGE = "rbxassetid://82824299358542",
	BG_IMAGE_TRANSPARENCY = 0.6,
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function CraftingPanel.new(inventoryManager, voxelInventoryPanel, parentFrame, options)
	local self = setmetatable({}, CraftingPanel)
	
	self.inventoryManager = inventoryManager
	self.voxelInventoryPanel = voxelInventoryPanel
	self.parentFrame = parentFrame
	
	self.allRecipes = RecipeConfig:GetAllRecipes()
	self.recipeSlots = {}
	self.selectedRecipe = nil
	self.selectedSlot = nil
	self.craftQuantity = 1
	
	-- Filter mode
	self.filterMode = "inventory"
	self.showWorkbenchRecipes = false
	
	return self
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function CraftingPanel:Initialize()
	self:CreateUI()
	self:RefreshRecipes()
	
	-- Listen for inventory changes
	self.inventoryManager:OnInventoryChanged(function()
		self:RefreshRecipes()
		self:RefreshDetailPanel()
	end)
	
	self.inventoryManager:OnHotbarChanged(function()
		self:RefreshRecipes()
		self:RefreshDetailPanel()
	end)
end

function CraftingPanel:OnPanelOpen()
	self.selectedRecipe = nil
	self.selectedSlot = nil
	self.craftQuantity = 1
	self:RefreshRecipes()
	self:RefreshDetailPanel()
end

function CraftingPanel:SetMode(mode)
	self.filterMode = mode
	self.showWorkbenchRecipes = (mode == "workbench")
	self:RefreshRecipes()
end

--------------------------------------------------------------------------------
-- UI Creation
--------------------------------------------------------------------------------

function CraftingPanel:CreateUI()
	-- Main container
	local container = Instance.new("Frame")
	container.Name = "CraftingContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = self.parentFrame
	self.container = container
	
	-- Calculate heights (border is drawn inside, so GRID_CELL_SIZE is the full visual size)
	local slotSize = CONFIG.GRID_CELL_SIZE
	local gridHeight = slotSize * CONFIG.GRID_ROWS_VISIBLE + CONFIG.GRID_SPACING * (CONFIG.GRID_ROWS_VISIBLE - 1)
	local labelHeight = 14 + 4 -- Label height + spacing
	
	-- Recipe section (top)
	self:CreateRecipeSection(container, labelHeight, gridHeight)
	
	-- Detail section (bottom)
	self:CreateDetailSection(container, labelHeight + gridHeight + 20)
end

function CraftingPanel:CreateRecipeSection(parent, yOffset, gridHeight)
	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "RecipesLabel"
	label.Size = UDim2.new(1, 0, 0, 14)
	label.Position = UDim2.fromOffset(0, 0)
	label.BackgroundTransparency = 1
	label.Text = "RECIPES"
	label.TextColor3 = CONFIG.TEXT_MUTED
	label.TextSize = 11
	label.Font = BOLD_FONT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	
	-- Scroll frame for recipe grid
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "RecipeScroll"
	scrollFrame.Size = UDim2.new(1, 0, 0, gridHeight + 8)
	scrollFrame.Position = UDim2.fromOffset(0, 14 + 4)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = CONFIG.TEXT_MUTED
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = parent
	self.scrollFrame = scrollFrame
	
	-- Grid container
	local grid = Instance.new("Frame")
	grid.Name = "RecipeGrid"
	grid.Size = UDim2.fromScale(1, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = scrollFrame
	self.recipeGrid = grid
	
	-- Grid layout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(CONFIG.GRID_CELL_SIZE, CONFIG.GRID_CELL_SIZE)
	layout.CellPadding = UDim2.fromOffset(CONFIG.GRID_SPACING, CONFIG.GRID_SPACING)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 2)
	padding.PaddingBottom = UDim.new(0, 2)
	padding.Parent = grid
end

function CraftingPanel:CreateDetailSection(parent, yOffset)
	-- Detail container
	local detail = Instance.new("Frame")
	detail.Name = "DetailSection"
	detail.Size = UDim2.new(1, 0, 1, -yOffset)
	detail.Position = UDim2.fromOffset(0, yOffset)
	detail.BackgroundColor3 = CONFIG.SLOT_BG
	detail.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	detail.Parent = parent
	self.detailFrame = detail
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	corner.Parent = detail
	
	local border = Instance.new("UIStroke")
	border.Color = CONFIG.SLOT_BORDER
	border.Thickness = CONFIG.BORDER_THICKNESS
	border.Parent = detail
	
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = detail
	
	-- Placeholder text
	local placeholder = Instance.new("TextLabel")
	placeholder.Name = "Placeholder"
	placeholder.Size = UDim2.fromScale(1, 1)
	placeholder.BackgroundTransparency = 1
	placeholder.Text = "Select a recipe"
	placeholder.TextColor3 = CONFIG.TEXT_MUTED
	placeholder.TextSize = 20
	placeholder.Font = BOLD_FONT
	placeholder.Parent = detail
	self.placeholderLabel = placeholder
	
	-- Recipe name
	local recipeName = Instance.new("TextLabel")
	recipeName.Name = "RecipeName"
	recipeName.Size = UDim2.new(1, 0, 0, 32)
	recipeName.BackgroundTransparency = 1
	recipeName.Text = ""
	recipeName.TextColor3 = CONFIG.TEXT_PRIMARY
	recipeName.TextSize = 32
	recipeName.Font = Enum.Font.Code
	recipeName.TextXAlignment = Enum.TextXAlignment.Left
	recipeName.Visible = false
	recipeName.Parent = detail
	FontBinder.apply(recipeName, CUSTOM_FONT_NAME)
	self.recipeNameLabel = recipeName
	
	-- Ingredients label
	local ingredientsLabel = Instance.new("TextLabel")
	ingredientsLabel.Name = "IngredientsLabel"
	ingredientsLabel.Size = UDim2.new(1, 0, 0, LABEL_SIZE)
	ingredientsLabel.Position = UDim2.fromOffset(0, 44)
	ingredientsLabel.BackgroundTransparency = 1
	ingredientsLabel.Text = "NEEDS"
	ingredientsLabel.TextColor3 = CONFIG.TEXT_MUTED
	ingredientsLabel.TextSize = 14
	ingredientsLabel.Font = BOLD_FONT
	ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
	ingredientsLabel.Visible = false
	ingredientsLabel.Parent = detail
	self.ingredientsLabel = ingredientsLabel
	
	-- Ingredients container
	local ingredients = Instance.new("Frame")
	ingredients.Name = "Ingredients"
	ingredients.Size = UDim2.new(1, 0, 0, CONFIG.INGREDIENT_SIZE)
	ingredients.Position = UDim2.fromOffset(0, 70)
	ingredients.BackgroundTransparency = 1
	ingredients.Visible = false
	ingredients.Parent = detail
	self.ingredientsFrame = ingredients
	
	local ingredientLayout = Instance.new("UIListLayout")
	ingredientLayout.FillDirection = Enum.FillDirection.Horizontal
	ingredientLayout.Padding = UDim.new(0, CONFIG.INGREDIENT_SPACING)
	ingredientLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ingredientLayout.Parent = ingredients
	
	-- Controls container (bottom)
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.Size = UDim2.new(1, 0, 0, CONFIG.BUTTON_HEIGHT)
	controls.Position = UDim2.new(0, 0, 1, -CONFIG.BUTTON_HEIGHT)
	controls.BackgroundTransparency = 1
	controls.Visible = false
	controls.Parent = detail
	self.controlsFrame = controls
	
	-- Create control buttons
	self:CreateControlButtons(controls)
end

function CraftingPanel:CreateControlButtons(parent)
	-- Layout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = parent
	
	-- Minus button
	local minusBtn = self:CreateControlButton(parent, "Minus", "−", 1)
	self.minusBtn = minusBtn
	
	-- Quantity display
	local qtyBox = Instance.new("TextBox")
	qtyBox.Name = "Quantity"
	qtyBox.LayoutOrder = 2
	qtyBox.Size = UDim2.fromOffset(70, CONFIG.BUTTON_HEIGHT)
	qtyBox.BackgroundColor3 = CONFIG.SLOT_BG
	qtyBox.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	qtyBox.BorderSizePixel = 0
	qtyBox.Text = "1"
	qtyBox.TextColor3 = CONFIG.TEXT_PRIMARY
	qtyBox.TextSize = 20
	qtyBox.Font = BOLD_FONT
	qtyBox.TextXAlignment = Enum.TextXAlignment.Center
	qtyBox.ClearTextOnFocus = false
	qtyBox.Parent = parent
	self.qtyBox = qtyBox
	
	local qtyCorner = Instance.new("UICorner")
	qtyCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	qtyCorner.Parent = qtyBox
	
	local qtyBorder = Instance.new("UIStroke")
	qtyBorder.Color = CONFIG.SLOT_BORDER
	qtyBorder.Thickness = CONFIG.BORDER_THICKNESS
	qtyBorder.Parent = qtyBox
	
	-- Plus button
	local plusBtn = self:CreateControlButton(parent, "Plus", "+", 3)
	self.plusBtn = plusBtn
	
	-- Max button
	local maxBtn = self:CreateControlButton(parent, "Max", "Max", 4)
	maxBtn.Size = UDim2.fromOffset(70, CONFIG.BUTTON_HEIGHT)
	self.maxBtn = maxBtn
	
	-- Craft button (takes remaining space)
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "Craft"
	craftBtn.LayoutOrder = 5
	craftBtn.Size = UDim2.new(1, -250, 0, CONFIG.BUTTON_HEIGHT) -- Remaining width
	craftBtn.BackgroundColor3 = CONFIG.CRAFT_BTN
	craftBtn.BorderSizePixel = 0
	craftBtn.Text = "Craft"
	craftBtn.TextColor3 = CONFIG.TEXT_PRIMARY
	craftBtn.TextSize = 20
	craftBtn.Font = BOLD_FONT
	craftBtn.AutoButtonColor = false
	craftBtn.Parent = parent
	self.craftBtn = craftBtn
	
	local craftCorner = Instance.new("UICorner")
	craftCorner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	craftCorner.Parent = craftBtn
	
	local craftBorder = Instance.new("UIStroke")
	craftBorder.Color = CONFIG.SLOT_BORDER
	craftBorder.Thickness = CONFIG.BORDER_THICKNESS
	craftBorder.Parent = craftBtn
	
	-- Connect button events
	self:SetupControlEvents()
end

function CraftingPanel:CreateControlButton(parent, name, text, order)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.LayoutOrder = order
	btn.Size = UDim2.fromOffset(CONFIG.BUTTON_HEIGHT, CONFIG.BUTTON_HEIGHT)
	btn.BackgroundColor3 = CONFIG.SLOT_BG
	btn.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	btn.BorderSizePixel = 0
	btn.Text = text
	btn.TextColor3 = CONFIG.TEXT_PRIMARY
	btn.TextSize = 24
	btn.Font = BOLD_FONT
	btn.AutoButtonColor = false
	btn.Parent = parent
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.CORNER_RADIUS)
	corner.Parent = btn
	
	local border = Instance.new("UIStroke")
	border.Color = CONFIG.SLOT_BORDER
	border.Thickness = CONFIG.BORDER_THICKNESS
	border.Parent = btn
	
	-- Hover effect
	btn.MouseEnter:Connect(function()
		if btn.Active ~= false then
			btn.BackgroundColor3 = CONFIG.SLOT_HOVER
		end
	end)
	
	btn.MouseLeave:Connect(function()
		btn.BackgroundColor3 = CONFIG.SLOT_BG
		btn.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	end)
	
	return btn
end

function CraftingPanel:SetupControlEvents()
	-- Minus
	self.minusBtn.MouseButton1Click:Connect(function()
		if self.craftQuantity > 1 then
			self.craftQuantity = self.craftQuantity - 1
			self:RefreshDetailPanel()
		end
	end)
	
	-- Plus
	self.plusBtn.MouseButton1Click:Connect(function()
		local maxCraft = self:GetMaxCraftable()
		if self.craftQuantity < maxCraft then
			self.craftQuantity = self.craftQuantity + 1
			self:RefreshDetailPanel()
		end
	end)
	
	-- Max
	self.maxBtn.MouseButton1Click:Connect(function()
		local maxCraft = self:GetMaxCraftable()
		if maxCraft > 0 then
			self.craftQuantity = maxCraft
			self:RefreshDetailPanel()
		end
	end)
	
	-- Quantity box
	self.qtyBox.FocusLost:Connect(function()
		local num = tonumber(self.qtyBox.Text) or 1
		local maxCraft = self:GetMaxCraftable()
		self.craftQuantity = math.clamp(math.floor(num), 1, math.max(1, maxCraft))
		self:RefreshDetailPanel()
	end)
	
	-- Craft
	self.craftBtn.MouseButton1Click:Connect(function()
		self:DoCraft()
	end)
	
	-- Craft button hover
	self.craftBtn.MouseEnter:Connect(function()
		if self:GetMaxCraftable() > 0 and self.craftQuantity > 0 then
			self.craftBtn.BackgroundColor3 = CONFIG.CRAFT_BTN_HOVER
		end
	end)
	
	self.craftBtn.MouseLeave:Connect(function()
		self:RefreshDetailPanel()
	end)
end

--------------------------------------------------------------------------------
-- Recipe Grid
--------------------------------------------------------------------------------

function CraftingPanel:RefreshRecipes()
	-- Clear existing
	for _, slot in ipairs(self.recipeSlots) do
		slot:Destroy()
	end
	self.recipeSlots = {}
	
	-- Group recipes by output
	local recipeGroups = {}
	for _, recipe in ipairs(self.allRecipes) do
		-- Filter based on mode
		local include = true
		if not self.showWorkbenchRecipes then
			include = not (recipe.requiresWorkbench == true)
		end
		
		if include then
			local output = recipe.outputs[1]
			local key = output.itemId .. "_" .. output.count
			
			if not recipeGroups[key] then
				recipeGroups[key] = {
					output = output,
					recipes = {},
					displayName = recipe.name:gsub(" %(.+%)$", ""),
					category = recipe.category
				}
			end
			table.insert(recipeGroups[key].recipes, recipe)
		end
	end
	
	-- Create slots for craftable recipes
	local order = 1
	for _, group in pairs(recipeGroups) do
		-- Check if any variant is craftable
		local canCraft = false
		local bestRecipe = nil
		local maxCount = 0
		
		for _, recipe in ipairs(group.recipes) do
			if CraftingSystem:CanCraft(recipe, self.inventoryManager) then
				canCraft = true
				local count = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)
				if count > maxCount then
					maxCount = count
					bestRecipe = recipe
				end
			end
		end
		
		if canCraft and bestRecipe then
			local slot = self:CreateRecipeSlot(group, bestRecipe, order)
			slot.Parent = self.recipeGrid
			table.insert(self.recipeSlots, slot)
			order = order + 1
		end
	end
	
	-- Update selection state
	if self.selectedSlot and not self.selectedSlot.Parent then
		self.selectedRecipe = nil
		self.selectedSlot = nil
		self:RefreshDetailPanel()
	end
end

function CraftingPanel:CreateRecipeSlot(group, recipe, order)
	local output = group.output
	
	local slot = Instance.new("TextButton")
	slot.Name = "Recipe_" .. output.itemId
	slot.LayoutOrder = order
	slot.Size = UDim2.fromOffset(CONFIG.GRID_CELL_SIZE, CONFIG.GRID_CELL_SIZE)
	slot.BackgroundColor3 = CONFIG.SLOT_BG
	slot.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
	corner.Parent = slot
	
	-- Background image
	local bgImage = Instance.new("ImageLabel")
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = CONFIG.BG_IMAGE
	bgImage.ImageTransparency = CONFIG.BG_IMAGE_TRANSPARENCY
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot
	
	-- Border (drawn inside the slot)
	local border = Instance.new("UIStroke")
	border.Name = "Border"
	border.Color = CONFIG.SLOT_BORDER
	border.Thickness = CONFIG.BORDER_THICKNESS
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	border.Parent = slot
	
	-- Icon
	local iconContainer = Instance.new("Frame")
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot
	
	BlockViewportCreator.CreateBlockViewport(iconContainer, output.itemId, UDim2.fromScale(0.85, 0.85))
	
	-- Store data
	slot:SetAttribute("RecipeGroup", group.displayName)
	
	-- Hover effect
	slot.MouseEnter:Connect(function()
		if self.selectedSlot ~= slot then
			slot.BackgroundColor3 = CONFIG.SLOT_HOVER
		end
	end)
	
	slot.MouseLeave:Connect(function()
		if self.selectedSlot ~= slot then
			slot.BackgroundColor3 = CONFIG.SLOT_BG
			slot.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
		end
	end)
	
	-- Click to select
	slot.MouseButton1Click:Connect(function()
		self:SelectRecipe(slot, group, recipe)
	end)
	
	return slot
end

function CraftingPanel:SelectRecipe(slot, group, recipe)
	-- Deselect previous
	if self.selectedSlot then
		self.selectedSlot.BackgroundColor3 = CONFIG.SLOT_BG
		self.selectedSlot.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
		local oldBorder = self.selectedSlot:FindFirstChild("Border")
		if oldBorder then oldBorder.Thickness = CONFIG.BORDER_THICKNESS end
	end
	
	-- Select new
	self.selectedSlot = slot
	self.selectedRecipe = recipe
	self.selectedGroup = group
	self.craftQuantity = 1
	
	slot.BackgroundColor3 = CONFIG.SLOT_SELECTED
	local border = slot:FindFirstChild("Border")
	if border then border.Thickness = CONFIG.BORDER_THICKNESS + 1 end
	
	self:RefreshDetailPanel()
end

--------------------------------------------------------------------------------
-- Detail Panel
--------------------------------------------------------------------------------

function CraftingPanel:RefreshDetailPanel()
	if not self.selectedRecipe then
		-- Show placeholder
		self.placeholderLabel.Visible = true
		self.recipeNameLabel.Visible = false
		self.ingredientsLabel.Visible = false
		self.ingredientsFrame.Visible = false
		self.controlsFrame.Visible = false
		return
	end
	
	-- Hide placeholder, show content
	self.placeholderLabel.Visible = false
	self.recipeNameLabel.Visible = true
	self.ingredientsLabel.Visible = true
	self.ingredientsFrame.Visible = true
	self.controlsFrame.Visible = true
	
	local recipe = self.selectedRecipe
	local output = recipe.outputs[1]
	
	-- Recipe name
	self.recipeNameLabel.Text = self.selectedGroup.displayName
	
	-- Refresh ingredients
	self:RefreshIngredients(recipe)
	
	-- Refresh controls
	self:RefreshControls()
end

function CraftingPanel:RefreshIngredients(recipe)
	-- Clear existing
	for _, child in ipairs(self.ingredientsFrame:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	-- Create ingredient displays
	for _, input in ipairs(recipe.inputs) do
		local ingredientFrame = Instance.new("Frame")
		ingredientFrame.Size = UDim2.fromOffset(CONFIG.INGREDIENT_SIZE + 60, CONFIG.INGREDIENT_SIZE)
		ingredientFrame.BackgroundTransparency = 1
		ingredientFrame.Parent = self.ingredientsFrame
		
		-- Icon
		local iconFrame = Instance.new("Frame")
		iconFrame.Size = UDim2.fromOffset(CONFIG.INGREDIENT_SIZE, CONFIG.INGREDIENT_SIZE)
		iconFrame.BackgroundColor3 = CONFIG.SLOT_BG
		iconFrame.BackgroundTransparency = CONFIG.SLOT_BG_TRANSPARENCY
		iconFrame.Parent = ingredientFrame
		
		-- Background image
		local bgImage = Instance.new("ImageLabel")
		bgImage.Size = UDim2.fromScale(1, 1)
		bgImage.BackgroundTransparency = 1
		bgImage.Image = CONFIG.BG_IMAGE
		bgImage.ImageTransparency = CONFIG.BG_IMAGE_TRANSPARENCY
		bgImage.ScaleType = Enum.ScaleType.Fit
		bgImage.ZIndex = 1
		bgImage.Parent = iconFrame
		
		local iconCorner = Instance.new("UICorner")
		iconCorner.CornerRadius = UDim.new(0, CONFIG.SLOT_CORNER_RADIUS)
		iconCorner.Parent = iconFrame
		
		local iconBorder = Instance.new("UIStroke")
		iconBorder.Color = CONFIG.SLOT_BORDER
		iconBorder.Thickness = CONFIG.BORDER_THICKNESS
		iconBorder.Parent = iconFrame
		
		BlockViewportCreator.CreateBlockViewport(iconFrame, input.itemId, UDim2.fromScale(0.8, 0.8))
		
		-- Count
		local countLabel = Instance.new("TextLabel")
		countLabel.Size = UDim2.fromOffset(50, CONFIG.INGREDIENT_SIZE)
		countLabel.Position = UDim2.fromOffset(CONFIG.INGREDIENT_SIZE + 6, 0)
		countLabel.BackgroundTransparency = 1
		countLabel.Text = "×" .. input.count
		countLabel.TextColor3 = CONFIG.TEXT_PRIMARY
		countLabel.TextSize = 20
		countLabel.Font = BOLD_FONT
		countLabel.TextXAlignment = Enum.TextXAlignment.Left
		countLabel.TextYAlignment = Enum.TextYAlignment.Center
		countLabel.Parent = ingredientFrame
	end
end

function CraftingPanel:RefreshControls()
	local maxCraft = self:GetMaxCraftable()
	local canCraft = maxCraft > 0 and self.craftQuantity > 0
	
	-- Clamp quantity
	if maxCraft > 0 then
		self.craftQuantity = math.clamp(self.craftQuantity, 1, maxCraft)
	else
		self.craftQuantity = 0
	end
	
	-- Update quantity display
	self.qtyBox.Text = tostring(self.craftQuantity)
	
	-- Update button states
	self.minusBtn.Active = self.craftQuantity > 1
	self.plusBtn.Active = self.craftQuantity < maxCraft
	self.maxBtn.Active = maxCraft > 1 and self.craftQuantity < maxCraft
	
	-- Update craft button
	self.craftBtn.Text = canCraft and string.format("Craft ×%d", self.craftQuantity) or "Craft"
	self.craftBtn.BackgroundColor3 = canCraft and CONFIG.CRAFT_BTN or CONFIG.CRAFT_BTN_DISABLED
end

function CraftingPanel:GetMaxCraftable()
	if not self.selectedRecipe then return 0 end
	
	local materialsMax = CraftingSystem:GetMaxCraftCount(self.selectedRecipe, self.inventoryManager)
	if materialsMax <= 0 then return 0 end
	
	-- Check inventory space
	local output = self.selectedRecipe.outputs[1]
	local spaceMax = self:GetMaxBySpace(output.itemId, output.count, materialsMax)
	
	return math.min(materialsMax, spaceMax)
end

function CraftingPanel:GetMaxBySpace(itemId, perCraft, upperBound)
	if upperBound <= 0 then return 0 end
	
	local lo, hi = 0, upperBound
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		if self.inventoryManager:HasSpaceForItem(itemId, mid * perCraft) then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

--------------------------------------------------------------------------------
-- Crafting
--------------------------------------------------------------------------------

function CraftingPanel:DoCraft()
	if not self.selectedRecipe then return end
	
	local maxCraft = self:GetMaxCraftable()
	if maxCraft <= 0 or self.craftQuantity <= 0 then return end
	
	local quantity = math.min(self.craftQuantity, maxCraft)
	local recipe = self.selectedRecipe
	
	-- Optimistic update: consume materials
	for _ = 1, quantity do
		CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)
	end
	
	-- Optimistic update: add outputs
	for _, output in ipairs(recipe.outputs) do
		local total = output.count * quantity
		self.inventoryManager:AddItem(output.itemId, total)
	end
	
	-- Update displays
	if self.voxelInventoryPanel.RefreshAllSlots then
		self.voxelInventoryPanel:RefreshAllSlots()
	end
	
	-- Send to server
	EventManager:SendToServer("CraftRecipeBatch", {
		recipeId = recipe.id,
		count = quantity,
		toCursor = false
	})
	
	-- Refresh
	self:RefreshRecipes()
	self:RefreshDetailPanel()
end

--------------------------------------------------------------------------------
-- Legacy Compatibility
--------------------------------------------------------------------------------

function CraftingPanel:SetRequiresWorkbenchOnly(enabled)
	self.showWorkbenchRecipes = enabled
	self:RefreshRecipes()
end

function CraftingPanel:HideRecipeDetailPage()
	-- No-op for compatibility
end

function CraftingPanel:OnCursorChanged()
	-- No-op for compatibility
end

return CraftingPanel
