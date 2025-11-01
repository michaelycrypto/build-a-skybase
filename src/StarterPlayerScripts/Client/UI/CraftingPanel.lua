--[[
	CraftingPanel.lua
	UI component for displaying and interacting with crafting recipes

	Features:
	- Displays available recipes as scrollable list
	- Shows recipe ingredients with 3D icons
	- Cursor-based crafting (Minecraft-style)
	- Left click: Pick up to cursor
	- Right click: Pick up half to cursor
	- Shift+Click: Craft directly to inventory
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local CraftingSystem = require(ReplicatedStorage.Shared.VoxelWorld.Crafting.CraftingSystem)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local CraftingPanel = {}
CraftingPanel.__index = CraftingPanel

-- UI Configuration
local CRAFTING_CONFIG = {
	PANEL_WIDTH = 260,  -- Match VoxelInventoryPanel CRAFTING_WIDTH
	RECIPE_CARD_HEIGHT = 72,  -- Slightly taller for better spacing
	RECIPE_SPACING = 6,
	PADDING = 10,
	ICON_SIZE = 26,  -- Slightly larger icons

	-- Colors (match VoxelInventoryPanel)
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	CARD_BG_COLOR = Color3.fromRGB(45, 45, 45),
	CARD_HOVER_COLOR = Color3.fromRGB(55, 55, 55),
	CARD_DISABLED_COLOR = Color3.fromRGB(40, 40, 40),
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	TEXT_DISABLED_COLOR = Color3.fromRGB(120, 120, 120),
	CRAFT_BTN_COLOR = Color3.fromRGB(80, 180, 80),
	CRAFT_BTN_DISABLED_COLOR = Color3.fromRGB(60, 60, 60)
}

--[[
	Create new crafting panel
	@param inventoryManager: table - ClientInventoryManager instance
	@param voxelInventoryPanel: table - Reference to VoxelInventoryPanel (for cursor)
	@param parentFrame: Frame - Parent UI element
	@return: table - CraftingPanel instance
]]
function CraftingPanel.new(inventoryManager, voxelInventoryPanel, parentFrame)
	local self = setmetatable({}, CraftingPanel)

	self.inventoryManager = inventoryManager
	self.voxelInventoryPanel = voxelInventoryPanel
	self.parentFrame = parentFrame

	self.recipeCards = {}  -- Store references to recipe card UI elements
	self.allRecipes = RecipeConfig:GetAllRecipes()

	return self
end

--[[
	Initialize the crafting panel UI
]]
function CraftingPanel:Initialize()
	self:CreatePanelUI()
	self:RefreshRecipes()

	-- Listen for inventory changes
	self.inventoryManager:OnInventoryChanged(function()
		self:RefreshRecipes()
	end)

	self.inventoryManager:OnHotbarChanged(function()
		self:RefreshRecipes()
	end)
end

--[[
	Create the main panel UI structure
]]
function CraftingPanel:CreatePanelUI()
	-- Main container
	local container = Instance.new("Frame")
	container.Name = "CraftingContainer"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = self.parentFrame

	-- Title with subtle background
	local titleBg = Instance.new("Frame")
	titleBg.Name = "TitleBg"
	titleBg.Size = UDim2.new(1, 0, 0, 32)
	titleBg.Position = UDim2.new(0, 0, 0, 0)
	titleBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	titleBg.BackgroundTransparency = 0.5
	titleBg.BorderSizePixel = 0
	titleBg.Parent = container

	local titleCorner = Instance.new("UICorner")
	titleCorner.CornerRadius = UDim.new(0, 4)
	titleCorner.Parent = titleBg

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 1, 0)
	title.Position = UDim2.new(0, 8, 0, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	title.Text = "Crafting"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = titleBg

	-- Scrolling frame for recipes
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "RecipeScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -40)
	scrollFrame.Position = UDim2.new(0, 0, 0, 38)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 180, 80)
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = container

	-- Recipe container
	local recipeContainer = Instance.new("Frame")
	recipeContainer.Name = "RecipeContainer"
	recipeContainer.Size = UDim2.new(1, 0, 0, 0)
	recipeContainer.BackgroundTransparency = 1
	recipeContainer.AutomaticSize = Enum.AutomaticSize.Y
	recipeContainer.Parent = scrollFrame

	-- Layout
	local listLayout = Instance.new("UIListLayout")
	listLayout.Name = "ListLayout"
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, CRAFTING_CONFIG.RECIPE_SPACING)
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	listLayout.Parent = recipeContainer

	-- Padding around recipes
	local containerPadding = Instance.new("UIPadding")
	containerPadding.PaddingTop = UDim.new(0, 4)
	containerPadding.PaddingBottom = UDim.new(0, 4)
	containerPadding.PaddingLeft = UDim.new(0, 0)
	containerPadding.PaddingRight = UDim.new(0, 0)
	containerPadding.Parent = recipeContainer

	-- Store references
	self.container = container
	self.scrollFrame = scrollFrame
	self.recipeContainer = recipeContainer
end

--[[
	Refresh all recipe displays based on current inventory
]]
function CraftingPanel:RefreshRecipes()
	-- Clear existing cards
	for _, card in pairs(self.recipeCards) do
		card:Destroy()
	end
	self.recipeCards = {}

	-- Create new cards for each recipe
	for _, recipe in ipairs(self.allRecipes) do
		local canCraft = CraftingSystem:CanCraft(recipe, self.inventoryManager)
		local maxCount = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)

		local card = self:CreateRecipeCard(recipe, canCraft, maxCount)
		card.Parent = self.recipeContainer

		table.insert(self.recipeCards, card)
	end
end

--[[
	Create a recipe card UI element
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft this
	@param maxCount: number - Max times can craft
	@return: Frame - Recipe card UI
]]
function CraftingPanel:CreateRecipeCard(recipe, canCraft, maxCount)
	local cursorStack = self:GetCursorStack()
	local buttonState = self:GetRecipeButtonState(recipe, canCraft, cursorStack)

	-- Main card frame
	local card = Instance.new("TextButton")
	card.Name = "RecipeCard_" .. recipe.id
	card.Size = UDim2.new(1, -CRAFTING_CONFIG.PADDING*2, 0, CRAFTING_CONFIG.RECIPE_CARD_HEIGHT)
	card.BackgroundColor3 = buttonState.enabled and CRAFTING_CONFIG.CARD_BG_COLOR or CRAFTING_CONFIG.CARD_DISABLED_COLOR
	card.BorderSizePixel = 0
	card.AutoButtonColor = false
	card.Text = ""
	card.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card

	-- Subtle border for depth
	local cardBorder = Instance.new("UIStroke")
	cardBorder.Color = buttonState.enabled and Color3.fromRGB(70, 70, 70) or Color3.fromRGB(50, 50, 50)
	cardBorder.Thickness = 1
	cardBorder.Transparency = 0.5
	cardBorder.Parent = card

	-- Recipe name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "RecipeName"
	nameLabel.Size = UDim2.new(1, -110, 0, 22)
	nameLabel.Position = UDim2.new(0, 10, 0, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 14
	nameLabel.TextColor3 = buttonState.enabled and CRAFTING_CONFIG.TEXT_COLOR or CRAFTING_CONFIG.TEXT_DISABLED_COLOR
	nameLabel.Text = recipe.name
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = card

	-- Output quantity badge
	local output = recipe.outputs[1]
	local badge = Instance.new("TextLabel")
	badge.Name = "OutputBadge"
	badge.Size = UDim2.new(0, 50, 0, 22)
	badge.Position = UDim2.new(1, -108, 0, 8)
	badge.BackgroundTransparency = 1
	badge.Font = Enum.Font.GothamBold
	badge.TextSize = 13
	badge.TextColor3 = Color3.fromRGB(100, 220, 100)
	badge.Text = "x" .. output.count
	badge.TextXAlignment = Enum.TextXAlignment.Right
	badge.Parent = card

	-- Ingredients display frame
	local ingredientsFrame = Instance.new("Frame")
	ingredientsFrame.Name = "Ingredients"
	ingredientsFrame.Size = UDim2.new(1, -65, 0, 36)
	ingredientsFrame.Position = UDim2.new(0, 10, 0, 32)
	ingredientsFrame.BackgroundTransparency = 1
	ingredientsFrame.Parent = card

	-- Display each ingredient
	local xOffset = 0
	for _, input in ipairs(recipe.inputs) do
		xOffset = self:CreateIngredientIcon(input, ingredientsFrame, xOffset, buttonState.enabled)
	end

	-- Cursor count hint (if holding same item)
	if not cursorStack:IsEmpty() and cursorStack:GetItemId() == output.itemId then
		local cursorHint = Instance.new("TextLabel")
		cursorHint.Name = "CursorHint"
		cursorHint.Size = UDim2.new(0, 70, 0, 14)
		cursorHint.Position = UDim2.new(1, -125, 1, -18)
		cursorHint.BackgroundTransparency = 1
		cursorHint.Font = Enum.Font.Gotham
		cursorHint.TextSize = 10
		cursorHint.TextColor3 = Color3.fromRGB(200, 200, 200)
		cursorHint.Text = string.format("(%d/64)", cursorStack:GetCount())
		cursorHint.TextXAlignment = Enum.TextXAlignment.Right
		cursorHint.Parent = card
	end

	-- Craft button
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "CraftButton"
	craftBtn.Size = UDim2.new(0, 48, 0, 48)
	craftBtn.Position = UDim2.new(1, -56, 0.5, -24)
	craftBtn.BackgroundColor3 = buttonState.color
	craftBtn.BorderSizePixel = 0
	craftBtn.AutoButtonColor = false
	craftBtn.Font = Enum.Font.GothamBold
	craftBtn.TextSize = 20
	craftBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	craftBtn.Text = buttonState.text
	craftBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = craftBtn

	-- Subtle button shadow/depth
	if buttonState.enabled then
		local btnBorder = Instance.new("UIStroke")
		btnBorder.Color = Color3.fromRGB(60, 140, 60)
		btnBorder.Thickness = 2
		btnBorder.Transparency = 0.3
		btnBorder.Parent = craftBtn
	end

	-- Hover effects (only if enabled)
	if buttonState.enabled then
		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = CRAFTING_CONFIG.CARD_HOVER_COLOR
		end)

		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = CRAFTING_CONFIG.CARD_BG_COLOR
		end)

		-- Left click: Pick up to cursor
		craftBtn.MouseButton1Click:Connect(function()
			self:OnRecipeLeftClick(recipe, canCraft)
		end)

		-- Right click: Pick up half to cursor
		craftBtn.MouseButton2Click:Connect(function()
			self:OnRecipeRightClick(recipe, canCraft)
		end)

		-- Detect shift+click for instant crafting
		card.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or
				   UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
					self:OnRecipeShiftClick(recipe, canCraft)
				end
			end
		end)
	end

	return card
end

--[[
	Create ingredient icon display
	@param input: table - Input requirement {itemId, count}
	@param parent: Frame - Parent frame
	@param xOffset: number - X offset for positioning
	@param enabled: boolean - Whether to show enabled or disabled colors
	@return: number - New x offset
]]
function CraftingPanel:CreateIngredientIcon(input, parent, xOffset, enabled)
	-- Icon frame with subtle background
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, CRAFTING_CONFIG.ICON_SIZE, 0, CRAFTING_CONFIG.ICON_SIZE)
	iconFrame.Position = UDim2.new(0, xOffset, 0, 5)
	iconFrame.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = parent

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 5)
	iconCorner.Parent = iconFrame

	-- Icon border for depth
	local iconBorder = Instance.new("UIStroke")
	iconBorder.Color = Color3.fromRGB(70, 70, 70)
	iconBorder.Thickness = 1
	iconBorder.Transparency = 0.6
	iconBorder.Parent = iconFrame

	-- Create viewport or image for item
	local isTool = ToolConfig.IsTool(input.itemId)
	if isTool then
		local toolInfo = ToolConfig.GetToolInfo(input.itemId)
		if toolInfo then
			local image = Instance.new("ImageLabel")
			image.Name = "ToolImage"
			image.Size = UDim2.new(1, -4, 1, -4)
			image.Position = UDim2.new(0.5, 0, 0.5, 0)
			image.AnchorPoint = Vector2.new(0.5, 0.5)
			image.BackgroundTransparency = 1
			image.Image = toolInfo.image
			image.ScaleType = Enum.ScaleType.Fit
			image.Parent = iconFrame

			if not enabled then
				image.ImageColor3 = Color3.fromRGB(100, 100, 100)
			end
		end
	else
		-- Block viewport
		BlockViewportCreator.CreateBlockViewport(
			iconFrame,
			input.itemId,
			UDim2.new(1, 0, 1, 0)
		)
	end

	-- Count label
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0, 40, 0, CRAFTING_CONFIG.ICON_SIZE)
	countLabel.Position = UDim2.new(0, xOffset + CRAFTING_CONFIG.ICON_SIZE + 5, 0, 5)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 12
	countLabel.TextColor3 = enabled and CRAFTING_CONFIG.TEXT_COLOR or CRAFTING_CONFIG.TEXT_DISABLED_COLOR
	countLabel.Text = "×" .. input.count
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = parent

	return xOffset + CRAFTING_CONFIG.ICON_SIZE + 48
end

--[[
	Get the button state for a recipe based on cursor and materials
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player has materials
	@param cursorStack: ItemStack - Current cursor stack
	@return: table - {enabled, text, color, hint}
]]
function CraftingPanel:GetRecipeButtonState(recipe, canCraft, cursorStack)
	local output = recipe.outputs[1]

	-- Can't craft - no materials
	if not canCraft then
		return {
			enabled = false,
			text = "▪",
			color = CRAFTING_CONFIG.CRAFT_BTN_DISABLED_COLOR,
			hint = "Not enough materials"
		}
	end

	-- Cursor empty - can craft
	if cursorStack:IsEmpty() then
		return {
			enabled = true,
			text = "►",
			color = CRAFTING_CONFIG.CRAFT_BTN_COLOR,
			hint = "Click to craft"
		}
	end

	-- Cursor has same item
	if cursorStack:GetItemId() == output.itemId then
		-- Stack full - can't add more
		if cursorStack:IsFull() then
			return {
				enabled = false,
				text = "▪",
				color = CRAFTING_CONFIG.CRAFT_BTN_DISABLED_COLOR,
				hint = "Stack full (64/64)"
			}
		else
			-- Can add to stack
			return {
				enabled = true,
				text = "+",
				color = CRAFTING_CONFIG.CRAFT_BTN_COLOR,
				hint = "Click to add to stack"
			}
		end
	else
		-- Cursor has different item
		return {
			enabled = false,
			text = "▪",
			color = CRAFTING_CONFIG.CRAFT_BTN_DISABLED_COLOR,
			hint = "Place cursor item first"
		}
	end
end

--[[
	Handle left click on recipe (pick up to cursor)
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:OnRecipeLeftClick(recipe, canCraft)
	if not canCraft then return end

	local cursorStack = self:GetCursorStack()
	local output = recipe.outputs[1]

	-- Case 1: Cursor empty - start new stack
	if cursorStack:IsEmpty() then
		self:CraftToNewStack(recipe, output)

	-- Case 2: Cursor has same item, not full - add to stack
	elseif cursorStack:GetItemId() == output.itemId and not cursorStack:IsFull() then
		self:CraftToExistingStack(recipe, output, cursorStack)

	-- Case 3: Cursor has different item or is full - can't craft
	else
		-- Play error sound
		print("CraftingPanel: Cannot craft - cursor full or different item")
	end
end

--[[
	Handle right click on recipe (pick up half to cursor)
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:OnRecipeRightClick(recipe, canCraft)
	if not canCraft then return end

	local cursorStack = self:GetCursorStack()

	-- Only works when cursor is empty
	if not cursorStack:IsEmpty() then
		return
	end

	local output = recipe.outputs[1]
	local halfAmount = math.ceil(output.count / 2)

	-- OPTIMISTIC UPDATE: Update client immediately for instant feedback
	CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)

	-- Set cursor stack (half the output)
	local newStack = ItemStack.new(output.itemId, halfAmount)
	self:SetCursorStack(newStack)

	-- Update inventory display (visual feedback of consumed materials)
	self.voxelInventoryPanel:UpdateAllDisplays()

	-- REQUEST SERVER: Send craft request to server for validation
	EventManager:SendToServer("CraftRecipe", {
		recipeId = recipe.id,
		toCursor = true
	})

	-- Refresh recipes
	self:RefreshRecipes()
end

--[[
	Handle shift+click on recipe (craft directly to inventory)
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:OnRecipeShiftClick(recipe, canCraft)
	if not canCraft then return end

	-- OPTIMISTIC UPDATE: Update client immediately for instant feedback
	CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)

	-- Add output directly to inventory
	for _, output in ipairs(recipe.outputs) do
		self.inventoryManager:AddItem(output.itemId, output.count)
	end

	-- Update inventory display (visual feedback of materials consumed and items added)
	self.voxelInventoryPanel:UpdateAllDisplays()

	-- REQUEST SERVER: Send craft request to server for validation
	EventManager:SendToServer("CraftRecipe", {
		recipeId = recipe.id,
		toCursor = false  -- Goes directly to inventory
	})

	-- Refresh recipes
	self:RefreshRecipes()
end

--[[
	Craft to a new cursor stack (cursor empty)
	@param recipe: table - Recipe definition
	@param output: table - Output definition
]]
function CraftingPanel:CraftToNewStack(recipe, output)
	-- OPTIMISTIC UPDATE: Update client immediately for instant feedback
	-- Server will validate and sync back the correct state
	CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)

	-- Set cursor stack
	local newStack = ItemStack.new(output.itemId, output.count)
	self:SetCursorStack(newStack)

	-- Update inventory display (visual feedback of consumed materials)
	self.voxelInventoryPanel:UpdateAllDisplays()

	-- REQUEST SERVER: Send craft request to server for validation
	EventManager:SendToServer("CraftRecipe", {
		recipeId = recipe.id,
		toCursor = true
	})

	-- Refresh recipes
	self:RefreshRecipes()
end

--[[
	Craft and add to existing cursor stack
	@param recipe: table - Recipe definition
	@param output: table - Output definition
	@param cursorStack: ItemStack - Current cursor stack
]]
function CraftingPanel:CraftToExistingStack(recipe, output, cursorStack)
	-- Check space
	local spaceLeft = cursorStack:GetRemainingSpace()
	local amountToAdd = math.min(output.count, spaceLeft)

	if amountToAdd <= 0 then
		return
	end

	-- OPTIMISTIC UPDATE: Update client immediately for instant feedback
	CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)

	-- Add to cursor stack
	cursorStack:AddCount(amountToAdd)
	self:SetCursorStack(cursorStack)

	-- Update inventory display (visual feedback of consumed materials)
	self.voxelInventoryPanel:UpdateAllDisplays()

	-- REQUEST SERVER: Send craft request to server for validation
	EventManager:SendToServer("CraftRecipe", {
		recipeId = recipe.id,
		toCursor = true
	})

	-- Refresh recipes
	self:RefreshRecipes()
end

--[[
	Get cursor stack from VoxelInventoryPanel
	@return: ItemStack - Current cursor stack
]]
function CraftingPanel:GetCursorStack()
	return self.voxelInventoryPanel.cursorStack or ItemStack.new(0, 0)
end

--[[
	Set cursor stack in VoxelInventoryPanel
	@param stack: ItemStack - New cursor stack
]]
function CraftingPanel:SetCursorStack(stack)
	self.voxelInventoryPanel.cursorStack = stack
	self.voxelInventoryPanel:UpdateCursorDisplay()
end

--[[
	Called when cursor changes (from VoxelInventoryPanel)
]]
function CraftingPanel:OnCursorChanged()
	-- Refresh recipes to update button states
	self:RefreshRecipes()
end

--[[
	Cleanup
]]
function CraftingPanel:Destroy()
	if self.container then
		self.container:Destroy()
	end
	self.recipeCards = {}
end

return CraftingPanel

