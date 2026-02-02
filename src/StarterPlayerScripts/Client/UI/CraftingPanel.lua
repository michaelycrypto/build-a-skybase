--[[
	CraftingPanel.lua
	UI component for displaying and interacting with crafting recipes

	Features:
	- Displays available recipes as scrollable grid
	- Shows recipe ingredients with 3D icons
	- Direct-to-inventory crafting (cross-device friendly)
	- Click recipe to view detail page with crafting options
	- Shows error notification if inventory is full
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputService = require(script.Parent.Parent.Input.InputService)
local TweenService = game:GetService("TweenService")
local _RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local CraftingSystem = require(ReplicatedStorage.Shared.VoxelWorld.Crafting.CraftingSystem)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local _ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local _IconManager = require(script.Parent.Parent.Managers.IconManager)
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CraftingPanel = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold
CraftingPanel.__index = CraftingPanel

-- Import font utilities for consistent styling
local FontBinder = require(ReplicatedStorage.Shared.UI.FontBinder)
local CUSTOM_FONT_NAME = "Upheaval BRK"
local LABEL_SIZE = 24  -- Matching inventory label size
local MIN_TEXT_SIZE = 20  -- Matching inventory minimum text size

-- UI Configuration (matching inventory slot styling and content section)
local CRAFTING_CONFIG = {
	-- Grid Layout (matching inventory slots: 56px frame, 60px visual with 2px border)
	GRID_CELL_SIZE = 56,  -- Frame size (visual is 60px with 2px border)
	GRID_SPACING = 5,     -- Gap between slots (between borders, matching inventory)
	GRID_COLUMNS = 5,     -- Fits content section: (60×5) + (5×4) = 320px + padding
	PADDING = 12,         -- Matching content section padding

	-- Icons
	INGREDIENT_ICON_SIZE = 32,  -- Icons in detail page

	-- Recipe Detail Page Configuration (full overlay, ultra-compact)
	DETAIL_PAGE_PADDING = 0,      -- No padding for maximum content space
	DETAIL_BACK_BUTTON_SIZE = 26, -- Slightly smaller
	HOVER_DELAY = 0,  -- Instant detail page

	-- Animation (disabled for straightforward UX)
	HOVER_SCALE = 1.0,  -- No scaling
	ANIMATION_SPEED = 0,  -- Instant transitions

	-- Colors (matching inventory slot styling and content section)
	BG_COLOR = Color3.fromRGB(58, 58, 58),  -- Matching content section
	SLOT_BG_COLOR = Color3.fromRGB(31, 31, 31),  -- Matching inventory
	SLOT_BG_TRANSPARENCY = 0.4,  -- 60% opacity (matching inventory)
	SLOT_HOVER_COLOR = Color3.fromRGB(80, 80, 80),  -- Matching inventory hover
	SLOT_DISABLED_COLOR = Color3.fromRGB(31, 31, 31),
	SLOT_DISABLED_TRANSPARENCY = 0.7,  -- More transparent when disabled
	SLOT_SELECTED_COLOR = Color3.fromRGB(65, 65, 65),  -- Mobile tap state
	SLOT_CRAFTABLE_GLOW = Color3.fromRGB(80, 180, 80),
	BORDER_COLOR = Color3.fromRGB(35, 35, 35),  -- Matching inventory border
	TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	TEXT_DISABLED_COLOR = Color3.fromRGB(120, 120, 120),
	TEXT_SUCCESS = Color3.fromRGB(100, 220, 100),
	TEXT_ERROR = Color3.fromRGB(220, 100, 100),
	CRAFT_BTN_COLOR = Color3.fromRGB(80, 180, 80),
	CRAFT_BTN_DISABLED_COLOR = Color3.fromRGB(60, 60, 60),
	CRAFT_BTN_HOVER = Color3.fromRGB(90, 200, 90),

	-- Category Colors
	CATEGORY_COLORS = {
		Materials = Color3.fromRGB(100, 180, 255),
		Tools = Color3.fromRGB(255, 180, 100),
		["Building Blocks"] = Color3.fromRGB(180, 140, 100)
	}
}

--[[
	Create new crafting panel
	@param inventoryManager: table - ClientInventoryManager instance
	@param voxelInventoryPanel: table - Reference to VoxelInventoryPanel (for cursor)
	@param parentFrame: Frame - Parent UI element
	@return: table - CraftingPanel instance
]]
function CraftingPanel.new(inventoryManager, voxelInventoryPanel, parentFrame, options)
	local self = setmetatable({}, CraftingPanel)

	self.inventoryManager = inventoryManager
	self.voxelInventoryPanel = voxelInventoryPanel
	self.parentFrame = parentFrame

	self.recipeCards = {}  -- Store references to recipe card UI elements
	self.allRecipes = RecipeConfig:GetAllRecipes()

	-- Options / filtering
	self.requiresWorkbenchOnly = (options and options.requiresWorkbenchOnly) or false -- legacy flag
	self.filterMode = "inventory" -- "inventory" or "workbench"
	self.showAllRecipes = false
	self.hideWorkbenchRecipes = true

	-- Tooltip state
	self.activeTooltip = nil
	self.activeTooltipCard = nil
	self.tooltipConnections = {}
	self.hoverDebounce = nil

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

	-- No longer using cursor-based crafting - all crafts go directly to inventory
	self._eventConnections = self._eventConnections or {}
end

-- Toggle filtering for workbench-only recipes
function CraftingPanel:SetRequiresWorkbenchOnly(enabled)
	self.requiresWorkbenchOnly = enabled and true or false
	self:RefreshRecipes()
end

-- Called when the parent panel opens; resets transient UI state
function CraftingPanel:OnPanelOpen()
	-- Close any open detail overlay
	self:HideRecipeDetailPage()
	self.activeTooltipCard = nil
	self.suppressHoverUntil = os.clock() + 0.2
end

-- Set filtering mode
-- mode: "inventory" (show only non-workbench) or "workbench" (show all)
function CraftingPanel:SetMode(mode)
	if mode == "workbench" then
		self.filterMode = "workbench"
		self.showAllRecipes = true
		self.hideWorkbenchRecipes = false
		self.requiresWorkbenchOnly = false
	else
		self.filterMode = "inventory"
		self.showAllRecipes = false
		self.hideWorkbenchRecipes = true
		self.requiresWorkbenchOnly = false
	end
	self:RefreshRecipes()
end

--[[
	Create the main panel UI structure
]]
function CraftingPanel:CreatePanelUI()
	-- Main container
	local container = Instance.new("Frame")
	container.Name = "CraftingContainer"
	container.Size = UDim2.fromScale(1, 1)
	container.BackgroundTransparency = 1
	container.Parent = self.parentFrame

	-- Section label (matching inventory label style)
	local craftingLabel = Instance.new("TextLabel")
	craftingLabel.Name = "CraftingLabel"
	craftingLabel.Size = UDim2.new(1, 0, 0, 22)  -- Matching INVENTORY_CONFIG.LABEL_HEIGHT
	craftingLabel.BackgroundTransparency = 1
	craftingLabel.Font = Enum.Font.Code
	craftingLabel.TextSize = LABEL_SIZE
	craftingLabel.TextColor3 = Color3.fromRGB(140, 140, 140)  -- Matching inventory label color
	craftingLabel.TextXAlignment = Enum.TextXAlignment.Left
	craftingLabel.Text = "CRAFTING"
	craftingLabel.Parent = container

	FontBinder.apply(craftingLabel, CUSTOM_FONT_NAME)

	-- Scrolling frame for recipes (below label, full width)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "RecipeScroll"
	local labelHeight = 22  -- INVENTORY_CONFIG.LABEL_HEIGHT
	local labelSpacing = 8  -- INVENTORY_CONFIG.LABEL_SPACING
	scrollFrame.Size = UDim2.new(1, 0, 1, -(labelHeight + labelSpacing))  -- Full width, below label
	scrollFrame.Position = UDim2.fromOffset(0, labelHeight + labelSpacing)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 180, 80)
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = container

	-- Recipe grid container
	local recipeGrid = Instance.new("Frame")
	recipeGrid.Name = "RecipeGrid"
	recipeGrid.Size = UDim2.fromScale(1, 0)
	recipeGrid.BackgroundTransparency = 1
	recipeGrid.AutomaticSize = Enum.AutomaticSize.Y
	recipeGrid.Parent = scrollFrame

	-- Optimized Grid Layout (left-aligned, matching inventory)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellSize = UDim2.fromOffset(CRAFTING_CONFIG.GRID_CELL_SIZE, CRAFTING_CONFIG.GRID_CELL_SIZE)
	gridLayout.CellPadding = UDim2.fromOffset(CRAFTING_CONFIG.GRID_SPACING, CRAFTING_CONFIG.GRID_SPACING)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left  -- Left-aligned like inventory
	gridLayout.Parent = recipeGrid

	-- Padding (matching content section spacing)
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 4)  -- Small top padding
	gridPadding.PaddingBottom = UDim.new(0, 4)
	gridPadding.PaddingLeft = UDim.new(0, 0)  -- No left padding for left alignment
	gridPadding.PaddingRight = UDim.new(0, 0)
	gridPadding.Parent = recipeGrid

	-- Store references
	self.container = container
	self.scrollFrame = scrollFrame
	self.recipeGrid = recipeGrid
end

--[[
	Refresh all recipe displays based on current inventory
]]
function CraftingPanel:RefreshRecipes()
	-- Clear existing grid items
	for _, item in pairs(self.recipeCards) do
		item:Destroy()
	end
	self.recipeCards = {}

	-- Group recipes by output (itemId + count)
	local recipeGroups = {}
	for _, recipe in ipairs(self.allRecipes) do
		-- Unified filter rules:
		-- 1) If requiresWorkbenchOnly is true (legacy): include only workbench-required
		-- 2) If showAllRecipes: include all
		-- 3) Default (inventory): include only if NOT workbench-required
		local include = true
		if self.requiresWorkbenchOnly then
			include = (recipe and recipe.requiresWorkbench == true)
		elseif self.showAllRecipes then
			include = true
		else
			include = not (recipe and recipe.requiresWorkbench == true)
		end

		if include then
		local output = recipe.outputs[1]
		local outputKey = output.itemId .. "_" .. output.count

		if not recipeGroups[outputKey] then
			recipeGroups[outputKey] = {
				output = output,
				recipes = {},
				displayName = recipe.name:gsub(" %(.+%)$", ""),  -- Remove variant suffix like "(Oak)"
				category = recipe.category
			}
		end

			table.insert(recipeGroups[outputKey].recipes, recipe)
		end
	end

	-- Create grid items for each unique output (only show if at least one variant is craftable)
	local layoutOrder = 1
	for _, group in pairs(recipeGroups) do
		-- Check if ANY variant can be crafted
		local anyCanCraft = false
		local maxCount = 0
		local primaryRecipe = nil

		for _, recipe in ipairs(group.recipes) do
			local canCraft = CraftingSystem:CanCraft(recipe, self.inventoryManager)
			if canCraft then
				anyCanCraft = true
				local recipeMaxCount = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)
				if recipeMaxCount > maxCount then
					maxCount = recipeMaxCount
					primaryRecipe = recipe
				end
			end
		end

		-- Only show if at least one variant is available
		if anyCanCraft and primaryRecipe then
			local gridItem = self:CreateRecipeGridItem(group, anyCanCraft, maxCount, layoutOrder)
			gridItem.Parent = self.recipeGrid

			table.insert(self.recipeCards, gridItem)
			layoutOrder = layoutOrder + 1
		end
	end
end

--[[
	Create a recipe grid item (compact, like inventory slot)
	@param group: table - Recipe group (contains output, recipes array, displayName, category)
	@param canCraft: boolean - Whether player can craft this
	@param maxCount: number - Max times can craft
	@param layoutOrder: number - Grid position
	@return: TextButton - Recipe grid item
]]
function CraftingPanel:CreateRecipeGridItem(group, canCraft, _maxCount, layoutOrder)
	local output = group.output

	-- Grid slot (matching inventory slot styling)
	local slot = Instance.new("TextButton")
	slot.Name = "Recipe_" .. output.itemId
	slot.Size = UDim2.fromOffset(56, 56)  -- Frame size (visual is 60px with 2px border)
	slot.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	slot.BackgroundTransparency = canCraft and CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY or CRAFTING_CONFIG.SLOT_DISABLED_TRANSPARENCY
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.LayoutOrder = layoutOrder

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius (was 2, should be 4)
	slotCorner.Parent = slot

	-- Background image (matching inventory)
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6  -- Matching inventory
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = slot

	-- Border (exactly matching inventory slots - no green border)
	local slotBorder = Instance.new("UIStroke")
	slotBorder.Name = "Border"
	slotBorder.Color = CRAFTING_CONFIG.BORDER_COLOR  -- Standard border, same as inventory
	slotBorder.Thickness = 2
	slotBorder.Transparency = 0  -- Fully opaque, matching inventory
	slotBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	slotBorder.Parent = slot

	-- Output icon container (fills entire slot)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "Icon"
	iconContainer.Size = UDim2.fromScale(1, 1)
	iconContainer.Position = UDim2.fromScale(0, 0)
	iconContainer.AnchorPoint = Vector2.new(0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 3  -- Above background image
	iconContainer.Parent = slot

	-- Create 3D viewmodel
	BlockViewportCreator.CreateBlockViewport(
		iconContainer,
		output.itemId,
		UDim2.fromScale(1, 1)
	)

	-- Store references for interaction
	slot:SetAttribute("CanCraft", canCraft)

	-- Add interactions (will show tooltip on hover/tap)
	self:SetupGridItemInteractions(slot, group, canCraft)

	-- Add press animation and glow pulse for craftable items
	if canCraft then
		self:AddButtonPressAnimation(slot)
		self:AddCraftableGlowPulse(slot)
	end

	return slot
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
	iconFrame.Size = UDim2.fromOffset(CRAFTING_CONFIG.ICON_SIZE, CRAFTING_CONFIG.ICON_SIZE)
	iconFrame.Position = UDim2.fromOffset(xOffset, 5)
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
			image.Position = UDim2.fromScale(0.5, 0.5)
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
			UDim2.fromScale(1, 1)
		)
	end

	-- Count label
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.fromOffset(40, CRAFTING_CONFIG.ICON_SIZE)
	countLabel.Position = UDim2.fromOffset(xOffset + CRAFTING_CONFIG.ICON_SIZE + 5, 5)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = BOLD_FONT
	countLabel.TextSize = 12
	countLabel.TextColor3 = enabled and CRAFTING_CONFIG.TEXT_COLOR or CRAFTING_CONFIG.TEXT_DISABLED_COLOR
	countLabel.Text = "×" .. input.count
	countLabel.TextXAlignment = Enum.TextXAlignment.Left
	countLabel.Parent = parent

	return xOffset + CRAFTING_CONFIG.ICON_SIZE + 48
end

--[[
	Detect if running on mobile device
	@return: boolean - True if mobile
]]
function CraftingPanel:IsMobile()
	return InputService.TouchEnabled and not InputService.KeyboardEnabled
end

--[[
	Setup grid item interactions with hover/tap tooltips and animations
	@param slot: TextButton - Recipe grid slot
	@param group: table - Recipe group definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:SetupGridItemInteractions(slot, group, canCraft)
	local originalColor = slot.BackgroundColor3
	local originalTransparency = slot.BackgroundTransparency
	local hoverBorder = slot:FindFirstChild("HoverBorder")

	-- Create hover border if it doesn't exist (matching inventory)
	if not hoverBorder then
		hoverBorder = Instance.new("UIStroke")
		hoverBorder.Name = "HoverBorder"
		hoverBorder.Color = Color3.fromRGB(255, 255, 255)
		hoverBorder.Thickness = 2
		hoverBorder.Transparency = 1
		hoverBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		hoverBorder.ZIndex = 2
		hoverBorder.Parent = slot
	end

	-- Hover highlight (exactly matching inventory - no active state)
	slot.MouseEnter:Connect(function()
		slot.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
		if hoverBorder then
			hoverBorder.Transparency = 0.5
		end
	end)

	slot.MouseLeave:Connect(function()
		slot.BackgroundColor3 = originalColor
		slot.BackgroundTransparency = originalTransparency
		if hoverBorder then
			hoverBorder.Transparency = 1
		end
	end)

	-- Click to show detail page (both desktop and mobile)
	slot.MouseButton1Click:Connect(function()
		if self.activeTooltipCard == slot then
			-- Clicked same slot, close detail page
			self:HideRecipeDetailPage()
		else
			-- Open detail page for this slot
			self:ShowRecipeDetailPage(slot, group, canCraft)
		end
	end)
end

--[[
	Setup card interactions with hover/tap tooltips and animations (LEGACY - for old card layout)
	@param card: TextButton - Recipe card
	@param craftBtn: TextButton - Craft button
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
	@param buttonState: table - Button state info
]]
function CraftingPanel:SetupCardInteractions(card, craftBtn, recipe, canCraft, buttonState)
	local isMobile = self:IsMobile()

	if not isMobile then
		-- Desktop: Hover effects with smooth animations
		local hoverTween = nil

		card.MouseEnter:Connect(function()
			-- Cancel hide debounce
			if self.hoverDebounce then
				task.cancel(self.hoverDebounce)
				self.hoverDebounce = nil
			end

			-- Smooth scale animation
			if hoverTween then
				hoverTween:Cancel()
			end
			hoverTween = TweenService:Create(card, TweenInfo.new(CRAFTING_CONFIG.ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -CRAFTING_CONFIG.PADDING*2 + 4, 0, CRAFTING_CONFIG.RECIPE_CARD_HEIGHT * CRAFTING_CONFIG.HOVER_SCALE)
			})
			hoverTween:Play()

			-- Show background highlight
			card.BackgroundColor3 = buttonState.enabled and CRAFTING_CONFIG.CARD_HOVER_COLOR or CRAFTING_CONFIG.CARD_DISABLED_COLOR

			-- Show detail page after delay (instant with HOVER_DELAY = 0)
			self.hoverDebounce = task.delay(CRAFTING_CONFIG.HOVER_DELAY, function()
				self:ShowRecipeDetailPage(card, recipe, canCraft)
			end)
		end)

		card.MouseLeave:Connect(function()
			-- Cancel show debounce
			if self.hoverDebounce then
				task.cancel(self.hoverDebounce)
				self.hoverDebounce = nil
			end

			-- Smooth scale back
			if hoverTween then
				hoverTween:Cancel()
			end
			hoverTween = TweenService:Create(card, TweenInfo.new(CRAFTING_CONFIG.ANIMATION_SPEED, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.new(1, -CRAFTING_CONFIG.PADDING*2, 0, CRAFTING_CONFIG.RECIPE_CARD_HEIGHT)
			})
			hoverTween:Play()

			card.BackgroundColor3 = buttonState.enabled and CRAFTING_CONFIG.CARD_BG_COLOR or CRAFTING_CONFIG.CARD_DISABLED_COLOR

			-- Hide detail page after delay
			self.hoverDebounce = task.delay(0.3, function()
				self:HideRecipeDetailPage()
			end)
		end)

		-- Button hover effects
		craftBtn.MouseEnter:Connect(function()
			if buttonState.enabled then
				TweenService:Create(craftBtn, TweenInfo.new(0.1), {
					BackgroundColor3 = CRAFTING_CONFIG.CRAFT_BTN_HOVER
				}):Play()
			end
		end)

		craftBtn.MouseLeave:Connect(function()
			if buttonState.enabled then
				TweenService:Create(craftBtn, TweenInfo.new(0.1), {
					BackgroundColor3 = CRAFTING_CONFIG.CRAFT_BTN_COLOR
				}):Play()
			end
		end)

		-- Click handlers (updated to use new crafting methods)
		if buttonState.enabled then
			craftBtn.MouseButton1Click:Connect(function()
				self:CraftToInventory(recipe, canCraft)
				self:HideRecipeDetailPage()
			end)

			-- Shift+click for instant craft
			card.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if InputService:IsKeyDown(Enum.KeyCode.LeftShift) or
					   InputService:IsKeyDown(Enum.KeyCode.RightShift) then
						self:CraftToInventory(recipe, canCraft)
						self:HideRecipeDetailPage()
					end
				end
			end)
		end
	else
		-- Mobile: Tap to toggle detail page
		card.MouseButton1Click:Connect(function()
			if self.activeTooltipCard == card then
				-- Tapped same card, hide detail page
				self:HideRecipeDetailPage()
			else
				-- Show detail page for this card
				self:ShowRecipeDetailPage(card, recipe, canCraft)
			end
		end)

		-- Craft button tap
		if buttonState.enabled then
			craftBtn.MouseButton1Click:Connect(function()
				-- Prevent event from bubbling to card
				self:CraftToInventory(recipe, canCraft)
				-- Keep detail page open for multiple crafts
			end)
		end
	end
end

--[[
	Show recipe detail page (full overlay)
	@param card: TextButton - Recipe card element
	@param group: table - Recipe group definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:ShowRecipeDetailPage(card, group, canCraft)
	-- Hide existing detail page
	self:HideRecipeDetailPage()

	-- Create detail page
	local detailPage = self:CreateRecipeDetailPage(group, canCraft)

	-- Store state
	self.activeTooltip = detailPage
	self.activeTooltipCard = card
	self.activeTooltipRecipe = nil -- Will be set when variant selected

	-- Make detail page visible (full overlay, no positioning needed)
	detailPage.Visible = true

	-- Fade in animation
	detailPage.BackgroundTransparency = 1
	TweenService:Create(detailPage, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0
	}):Play()
end

--[[
	Hide recipe detail page
]]
function CraftingPanel:HideRecipeDetailPage()
	if self.activeTooltip then
		self.activeTooltip:Destroy()
		self.activeTooltip = nil
	end

	if self.activeTooltipCard then
		-- Reset slot to default state (matching inventory - no active state)
		local canCraft = self.activeTooltipCard:GetAttribute("CanCraft")
		self.activeTooltipCard.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		self.activeTooltipCard.BackgroundTransparency = canCraft and CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY or CRAFTING_CONFIG.SLOT_DISABLED_TRANSPARENCY
		local hoverBorder = self.activeTooltipCard:FindFirstChild("HoverBorder")
		if hoverBorder then
			hoverBorder.Transparency = 1
		end
		self.activeTooltipCard = nil
	end

	-- Clear callback references
	self._detailPageRefreshCallback = nil
	self.activeTooltipRecipe = nil
end

--[[
	Show error notification to player
	@param message: string - Error message to display
]]
function CraftingPanel:ShowErrorNotification(message)
	-- Use EventManager to show notification (assumes notification system exists)
	EventManager:FireEvent("ShowNotification", {
		message = message,
		type = "error",
		duration = 3
	})
	print("CraftingPanel Error:", message)
end

--[[
	Craft single recipe to inventory
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:CraftToInventory(recipe, canCraft)
	if not canCraft then
		return
	end

	local output = recipe.outputs[1]

	-- Check if inventory has space
	if not self.inventoryManager:HasSpaceForItem(output.itemId, output.count) then
		self:ShowErrorNotification("Inventory is full!")
		return
	end

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
	Craft maximum possible to inventory
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether player can craft
	@param maxCraftable: number - Max number of times to craft
]]
function CraftingPanel:CraftMaxToInventory(recipe, canCraft, maxCraftable)
	if not canCraft or maxCraftable <= 0 then
		return
	end

	local output = recipe.outputs[1]
	local totalItems = maxCraftable * output.count

	-- Check if inventory has space
	if not self.inventoryManager:HasSpaceForItem(output.itemId, totalItems) then
		self:ShowErrorNotification("Inventory is full!")
		return
	end

	-- Request batch craft to server; server will update inventory and sync back
	EventManager:SendToServer("CraftRecipeBatch", {
		recipeId = recipe.id,
		count = maxCraftable,
		toCursor = false
	})

	-- UI will refresh after server sync; do a local refresh for immediate feedback
	self:RefreshRecipes()
end

--[[
	Compute maximum crafts allowed combining materials and inventory space
	@param recipe: table - Recipe definition
	@return: number, number, number - compositeMax, materialsMax, spaceMax
]]
function CraftingPanel:GetCompositeMaxCraft(recipe)
	local output = recipe.outputs[1]
	if not output then
		return 0, 0, 0
	end
	local perCraft = output.count or 0
	if perCraft <= 0 then
		return 0, 0, 0
	end

	local materialsMax = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)
	local spaceMax = self:GetMaxCraftBySpace(output.itemId, perCraft, materialsMax)
	return math.min(materialsMax, spaceMax), materialsMax, spaceMax
end

--[[
	Binary search for max crafts by space only, up to materialsUpperBound
]]
function CraftingPanel:GetMaxCraftBySpace(itemId, perCraft, materialsUpperBound)
	if (materialsUpperBound or 0) <= 0 then
		return 0
	end
	local lo, hi = 0, materialsUpperBound
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		local totalItems = mid * perCraft
		if self.inventoryManager:HasSpaceForItem(itemId, totalItems) then
			lo = mid
		else
			hi = mid - 1
		end
	end
	return lo
end

--[[
	Validate there is enough inventory space for all outputs for a quantity of crafts
]]
function CraftingPanel:HasSpaceForOutputs(recipe, quantity)
	for _, output in ipairs(recipe.outputs or {}) do
		local total = (output.count or 0) * quantity
		if total > 0 and not self.inventoryManager:HasSpaceForItem(output.itemId, total) then
			return false
		end
	end
	return true
end

--[[
	Craft an explicit quantity directly to inventory (optimistic updates)
]]
function CraftingPanel:CraftQuantityToInventory(recipe, quantity)
	if quantity <= 0 then
		return
	end

	-- Rate-limit rapid clicks
	self._lastCraftTs = self._lastCraftTs or 0
	if tick() - self._lastCraftTs < 0.1 then
		return
	end
	self._lastCraftTs = tick()

	-- Validate materials and space
	local compositeMax, _materialsMax, _ = self:GetCompositeMaxCraft(recipe)
	if quantity > compositeMax then
		return -- UI should have clamped already
	end

	-- OPTIMISTIC: consume inputs quantity times (small quantities expected)
	for _ = 1, quantity do
		CraftingSystem:ConsumeMaterials(recipe, self.inventoryManager)
	end

	-- OPTIMISTIC: add outputs in bulk
	for _, output in ipairs(recipe.outputs or {}) do
		local total = (output.count or 0) * quantity
		if total > 0 then
			self.inventoryManager:AddItem(output.itemId, total)
		end
	end

	-- Refresh displays
	self.voxelInventoryPanel:UpdateAllDisplays()

	-- Send batch craft request
	EventManager:SendToServer("CraftRecipeBatch", {
		recipeId = recipe.id,
		count = quantity,
		toCursor = false
	})

	-- Visual feedback and auto-refresh
	self:ShowCraftSuccess(quantity, recipe.outputs[1])
	task.delay(0.3, function()
		self:RefreshRecipes()
		-- If detail page still open, recalculate max
		if self.activeTooltip then
			self:RefreshDetailPageMaxCraft()
		end
	end)
end

--[[
	Show visual success feedback after crafting with animations
]]
function CraftingPanel:ShowCraftSuccess(quantity, output)
	if not self.activeTooltip then
		return
	end
	local statusLabel = self.activeTooltip:FindFirstChild("StatusLabel", true)
	if statusLabel then
		local totalItems = quantity * (output.count or 0)
		statusLabel.Text = string.format("✓ Crafted ×%d", totalItems)
		statusLabel.TextColor3 = Color3.fromRGB(150, 220, 150)

		-- Create success particle effect
		self:PlayCraftSuccessEffect(self.activeTooltip)

		-- Show item reveal popup
		self:ShowItemRevealPopup(output, quantity)

		task.wait(1.5)
		if statusLabel and statusLabel.Parent then
			-- Restore to normal state
			local compositeMax = self.activeTooltipRecipe and self:GetCompositeMaxCraft(self.activeTooltipRecipe) or 0
			if compositeMax > 0 then
				if compositeMax >= 99 then
					statusLabel.Text = string.format("✓ Can craft %d+", 99)
				else
					statusLabel.Text = string.format("✓ Can craft %d", compositeMax)
				end
			end
		end
	end
end

--[[
	Play craft success particle effect
]]
function CraftingPanel:PlayCraftSuccessEffect(parent)
	-- Create sparkle particles
	for i = 1, 8 do
		local particle = Instance.new("Frame")
		particle.Size = UDim2.fromOffset(6, 6)
		particle.Position = UDim2.fromScale(0.5, 0.5)
		particle.AnchorPoint = Vector2.new(0.5, 0.5)
		particle.BackgroundColor3 = CRAFTING_CONFIG.SLOT_CRAFTABLE_GLOW
		particle.BorderSizePixel = 0
		particle.ZIndex = 200
		particle.Parent = parent

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle

		-- Random angle
		local angle = (i / 8) * math.pi * 2
		local distance = 80
		local targetX = math.cos(angle) * distance
		local targetY = math.sin(angle) * distance

		-- Animate outward with fade
		local tween = TweenService:Create(particle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, targetX, 0.5, targetY),
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(2, 2)
		})
		tween:Play()

		-- Clean up
		task.delay(0.6, function()
			particle:Destroy()
		end)
	end
end

--[[
	Show item reveal popup with animation
]]
function CraftingPanel:ShowItemRevealPopup(output, quantity)
	-- Parent to the inventory panel for proper visibility above detail page
	local inventoryGui = playerGui:FindFirstChild("VoxelInventory")
	if not inventoryGui then
		return
	end

	local inventoryPanel = inventoryGui:FindFirstChild("InventoryPanel")
	if not inventoryPanel then
		return
	end

	-- Create popup container
	local popup = Instance.new("Frame")
	popup.Name = "ItemRevealPopup"
	popup.Size = UDim2.fromOffset(160, 80)
	popup.Position = UDim2.fromScale(0.5, 0.3)
	popup.AnchorPoint = Vector2.new(0.5, 0.5)
	popup.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	popup.BorderSizePixel = 0
	popup.ZIndex = 250
	popup.BackgroundTransparency = 1
	popup.Parent = inventoryPanel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = popup

	local stroke = Instance.new("UIStroke")
	stroke.Color = CRAFTING_CONFIG.SLOT_CRAFTABLE_GLOW
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = popup

	-- Icon (larger for dramatic effect in popup)
	local icon = Instance.new("Frame")
	icon.Size = UDim2.fromOffset(64, 64)
	icon.Position = UDim2.new(0.5, 0, 0, 8)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
	icon.BorderSizePixel = 0
	icon.ZIndex = 251
	icon.ClipsDescendants = false
	icon.Parent = popup

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 6)
	iconCorner.Parent = icon

	-- Create viewport and ensure it's visible
	local viewport = BlockViewportCreator.CreateBlockViewport(icon, output.itemId, UDim2.fromScale(1, 1))
	if viewport then
		viewport.ZIndex = 252
		-- Recursively set ZIndex on all children for proper visibility
		for _, child in ipairs(viewport:GetDescendants()) do
			if child:IsA("GuiObject") or child:IsA("ViewportFrame") then
				child.ZIndex = 252
			end
		end
	end

	-- Text
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, 20)
	label.Position = UDim2.new(0, 8, 1, -24)
	label.BackgroundTransparency = 1
	label.Font = BOLD_FONT
	label.TextSize = 14
	label.TextColor3 = CRAFTING_CONFIG.TEXT_SUCCESS
	label.Text = string.format("+ %d", quantity * (output.count or 1))
	label.ZIndex = 251
	label.Parent = popup

	-- Animate in: scale up + fade in
	popup.Size = UDim2.fromOffset(140, 80)
	local tweenIn = TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(180, 100),
		BackgroundTransparency = 0.1
	})
	TweenService:Create(stroke, TweenInfo.new(0.25), {Transparency = 0}):Play()
	tweenIn:Play()

	-- Hold, then animate out
	task.delay(1.2, function()
		if popup.Parent then
			local tweenOut = TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.fromScale(0.5, 0.2),
				BackgroundTransparency = 1
			})
			TweenService:Create(stroke, TweenInfo.new(0.3), {Transparency = 1}):Play()
			tweenOut:Play()
			task.delay(0.3, function()
				popup:Destroy()
			end)
		end
	end)
end

--[[
	Add button press animation for tactile feedback
	@param button: TextButton - Button to add animation to
]]
function CraftingPanel:AddButtonPressAnimation(button)
	local isPressed = false
	local originalSize = button.Size

	button.MouseButton1Down:Connect(function()
		if isPressed then
			return
		end
		isPressed = true

		-- Scale down
		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 2, originalSize.Y.Scale, originalSize.Y.Offset - 2)
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		if not isPressed then
			return
		end
		isPressed = false

		-- Scale back with bounce
		TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = originalSize
		}):Play()
	end)

	-- Handle case where mouse leaves while pressed
	button.MouseLeave:Connect(function()
		if isPressed then
			isPressed = false
			TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = originalSize
			}):Play()
		end
	end)
end

--[[
	Add pulse glow animation to craftable recipe cards
	@param card: Frame - Recipe card to animate
]]
function CraftingPanel:AddCraftableGlowPulse(card)
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not stroke then
		return
	end

	stroke.ApplyStrokeMode = stroke.ApplyStrokeMode or Enum.ApplyStrokeMode.Border

	-- Create breathing glow animation
	local pulseIn = TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Thickness = 3
	})
	local pulseOut = TweenService:Create(stroke, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
		Thickness = 2
	})

	-- Loop animation
	pulseIn.Completed:Connect(function()
		if stroke and stroke.Parent then
			pulseOut:Play()
		end
	end)

	pulseOut.Completed:Connect(function()
		if stroke and stroke.Parent then
			pulseIn:Play()
		end
	end)

	pulseIn:Play()
end

--[[
	Refresh max craft calculation in open detail page
]]
function CraftingPanel:RefreshDetailPageMaxCraft()
	if self._detailPageRefreshCallback then
		self._detailPageRefreshCallback()
	end
end

--[[
	Called when cursor item changes (from VoxelInventoryPanel)
	Note: Cursor items are still used for dragging between inventory slots,
	we just don't craft items to the cursor anymore.
]]
function CraftingPanel:OnCursorChanged()
	-- No action needed - crafting doesn't care about cursor state anymore
	-- This method exists so VoxelInventoryPanel doesn't error when calling it
end

--[[
	Create recipe detail page UI (full overlay)
	@param group: table - Recipe group definition
	@param canCraft: boolean - Whether player can craft
	@return: Frame - Detail page frame
]]
function CraftingPanel:CreateRecipeDetailPage(group, _canCraft)
	local output = group.output

	-- Find best craftable recipe
	local primaryRecipe = nil
	local maxCraftCount = 0
	for _, recipe in ipairs(group.recipes) do
		local recipeCanCraft = CraftingSystem:CanCraft(recipe, self.inventoryManager)
		if recipeCanCraft then
			local recipeMaxCount = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)
			if recipeMaxCount > maxCraftCount then
				maxCraftCount = recipeMaxCount
				primaryRecipe = recipe
			end
		end
	end

	-- Fallback to first recipe if none are craftable
	if not primaryRecipe then
		primaryRecipe = group.recipes[1]
	end

	-- Max craftable combined (materials + space)
	local maxCraftable, materialsMax, _spaceMax = self:GetCompositeMaxCraft(primaryRecipe)

	-- Detail page overlays the crafting panel exactly
	-- It's created as a child of the crafting container
	local detailPage = Instance.new("Frame")
	detailPage.Name = "RecipeDetailPage"
	detailPage.Size = UDim2.fromScale(1, 1)  -- Full size overlay
	detailPage.Position = UDim2.fromScale(0, 0)
	detailPage.BackgroundColor3 = Color3.fromRGB(58, 58, 58)  -- Match content section color
	detailPage.BorderSizePixel = 0
	detailPage.ZIndex = 100  -- Above everything else in crafting panel
	detailPage.Visible = false
	detailPage.Parent = self.container

	-- HEADER SECTION (contains "CRAFTING" label and back button)
	-- Header height matches back button (56px) for proper alignment
	local headerHeight = 56  -- Matching inventory slot size
	local headerSection = Instance.new("Frame")
	headerSection.Name = "HeaderSection"
	headerSection.Size = UDim2.new(1, 0, 0, headerHeight)
	headerSection.Position = UDim2.fromScale(0, 0)
	headerSection.BackgroundTransparency = 1
	headerSection.BorderSizePixel = 0
	headerSection.ZIndex = 101
	headerSection.Parent = detailPage

	-- Back button (left side) - matching inventory slot styling
	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.fromOffset(56, 56)  -- Matching inventory slot size exactly
	backButton.Position = UDim2.fromScale(0, 0.5)  -- Vertically centered
	backButton.AnchorPoint = Vector2.new(0, 0.5)
	backButton.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	backButton.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	backButton.BorderSizePixel = 0
	backButton.Font = BOLD_FONT
	backButton.TextSize = MIN_TEXT_SIZE
	backButton.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	backButton.Text = "←"
	backButton.ZIndex = 102
	backButton.Parent = headerSection

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	backCorner.Parent = backButton

	-- Background image matching inventory
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = backButton

	-- Border matching inventory
	local backBorder = Instance.new("UIStroke")
	backBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	backBorder.Thickness = 2
	backBorder.Transparency = 0
	backBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	backBorder.Parent = backButton

	self:AddButtonPressAnimation(backButton)

	backButton.MouseEnter:Connect(function()
		backButton.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
	end)

	backButton.MouseLeave:Connect(function()
		backButton.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		backButton.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	end)

	backButton.MouseButton1Click:Connect(function()
		self:HideRecipeDetailPage()
	end)

	-- "CRAFTING" label (matching overview page style, aligned with back button)
	local craftingLabel = Instance.new("TextLabel")
	craftingLabel.Name = "CraftingLabel"
	craftingLabel.Size = UDim2.new(1, -64, 0, LABEL_SIZE)  -- Full width minus back button + spacing
	craftingLabel.Position = UDim2.new(0, 64, 0.5, 0)  -- After back button, vertically centered
	craftingLabel.AnchorPoint = Vector2.new(0, 0.5)
	craftingLabel.BackgroundTransparency = 1
	craftingLabel.Font = Enum.Font.Code
	craftingLabel.TextSize = LABEL_SIZE
	craftingLabel.TextColor3 = Color3.fromRGB(140, 140, 140)  -- Matching inventory label color
	craftingLabel.TextXAlignment = Enum.TextXAlignment.Left
	craftingLabel.Text = "CRAFTING"
	craftingLabel.ZIndex = 102
	craftingLabel.Parent = headerSection
	FontBinder.apply(craftingLabel, CUSTOM_FONT_NAME)

	local controlsHeight = 56  -- Larger controls
	local statusHeight = LABEL_SIZE  -- Matching label height for consistency
	local bottomPadding = 8  -- Top and bottom padding
	local bottomLayoutSpacing = 8  -- Spacing between elements in layout
	local bottomSectionHeight = bottomPadding + statusHeight + bottomLayoutSpacing + controlsHeight + bottomLayoutSpacing + controlsHeight + bottomPadding  -- All elements + padding + spacing

	-- Scrolling frame for content (below header, above bottom controls)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -(headerHeight + bottomSectionHeight))  -- Full width, between header and bottom
	scrollFrame.Position = UDim2.fromOffset(0, headerHeight)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ClipsDescendants = true  -- Ensure content doesn't overflow into bottom section
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 180, 80)
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ZIndex = 101
	scrollFrame.Parent = detailPage

	-- Content container
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.ZIndex = 102
	content.Parent = scrollFrame

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)  -- Consistent spacing between sections
	contentLayout.Parent = content

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 8)  -- Consistent padding
	contentPadding.PaddingBottom = UDim.new(0, 8)
	contentPadding.PaddingLeft = UDim.new(0, 8)
	contentPadding.PaddingRight = UDim.new(0, 8)
	contentPadding.Parent = content

	-- INGREDIENTS SECTION: Compact variant selection
	local availableRecipes = {}
	for _, r in ipairs(group.recipes) do
		if CraftingSystem:CanCraft(r, self.inventoryManager) then
			table.insert(availableRecipes, r)
		end
	end
	if #availableRecipes == 0 then
		table.insert(availableRecipes, primaryRecipe)
	end

	local ingredientsLabel = Instance.new("TextLabel")
	ingredientsLabel.Name = "IngredientsLabel"
	ingredientsLabel.Size = UDim2.new(1, 0, 0, LABEL_SIZE)  -- Matching label height
	ingredientsLabel.BackgroundTransparency = 1
	ingredientsLabel.Font = Enum.Font.Code
	ingredientsLabel.TextSize = LABEL_SIZE  -- Matching label size
	ingredientsLabel.TextColor3 = Color3.fromRGB(140, 140, 140)  -- Matching inventory label color
	ingredientsLabel.Text = #availableRecipes > 1 and "RECIPE VARIANTS" or "REQUIRED MATERIALS"
	ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
	ingredientsLabel.ZIndex = 103
	ingredientsLabel.LayoutOrder = 2
	ingredientsLabel.Parent = content
	FontBinder.apply(ingredientsLabel, CUSTOM_FONT_NAME)

	-- Track selected recipe (default to primary/best one among available)
	local selectedRecipe = primaryRecipe
	local selectedRecipeIndex = 1
	for i, recipe in ipairs(availableRecipes) do
		if recipe == primaryRecipe then
			selectedRecipeIndex = i
			break
		end
	end

	-- Container for recipe variant options (horizontal)
	local variantsContainer = Instance.new("Frame")
	variantsContainer.Name = "VariantsContainer"
	variantsContainer.Size = UDim2.fromScale(1, 0)
	variantsContainer.AutomaticSize = Enum.AutomaticSize.Y
	variantsContainer.BackgroundTransparency = 1
	variantsContainer.ZIndex = 103
	variantsContainer.LayoutOrder = 3
	variantsContainer.Parent = content

	local variantsLayout = Instance.new("UIListLayout")
	variantsLayout.FillDirection = Enum.FillDirection.Horizontal
	variantsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	variantsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	variantsLayout.Padding = UDim.new(0, 8)  -- Consistent spacing between variants
	variantsLayout.Parent = variantsContainer

	-- Create clickable variant buttons (only for available variants)
	local variantButtons = {}
	for variantIndex, recipe in ipairs(availableRecipes) do
		local recipeCanCraft = true
		local isSelected = (variantIndex == selectedRecipeIndex)

		local variantButton = self:CreateVariantOption(recipe, recipeCanCraft, isSelected, variantIndex)
		variantButton.Parent = variantsContainer
		table.insert(variantButtons, variantButton)

		-- Click to select this variant
		variantButton.MouseButton1Click:Connect(function()
			-- Update selection
			selectedRecipe = recipe
			selectedRecipeIndex = variantIndex

			-- Update visual state of all buttons (no green borders, standard inventory styling)
			for i, btn in ipairs(variantButtons) do
				local btnBorder = btn:FindFirstChild("BorderStroke")
				if i == variantIndex then
					-- Selected: thicker border
					btnBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
					btnBorder.Thickness = 3
					btnBorder.Transparency = 0
				else
					-- Not selected: standard border
					btnBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
					btnBorder.Thickness = 2
					btnBorder.Transparency = 0
				end
			end
		end)
	end

	-- Bottom section (stuck to bottom): input controls above, craft button below
	local bottomSection = Instance.new("Frame")
	bottomSection.Name = "BottomSection"
	bottomSection.Size = UDim2.new(1, 0, 0, bottomSectionHeight)
	bottomSection.Position = UDim2.fromScale(0, 1)  -- Position at bottom (1, 0 means 100% from top, 0 offset)
	bottomSection.AnchorPoint = Vector2.new(0, 1)  -- Anchor to bottom-left
	bottomSection.BackgroundTransparency = 1
	bottomSection.ZIndex = 200  -- High ZIndex to ensure it's above scrollFrame
	bottomSection.Parent = detailPage

	local bottomPadding = Instance.new("UIPadding")
	bottomPadding.PaddingLeft = UDim.new(0, 8)
	bottomPadding.PaddingRight = UDim.new(0, 8)
	bottomPadding.PaddingTop = UDim.new(0, 8)  -- Consistent padding
	bottomPadding.PaddingBottom = UDim.new(0, 8)
	bottomPadding.Parent = bottomSection

	local bottomLayout = Instance.new("UIListLayout")
	bottomLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bottomLayout.Padding = UDim.new(0, 8)  -- Consistent spacing between elements
	bottomLayout.FillDirection = Enum.FillDirection.Vertical
	bottomLayout.Parent = bottomSection

	-- STATUS (above input controls)
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(1, 0, 0, statusHeight)
	statusBar.BackgroundTransparency = 1
	statusBar.BorderSizePixel = 0
	statusBar.ZIndex = 201  -- Above bottom section base
	statusBar.LayoutOrder = 1
	statusBar.Parent = bottomSection

	-- Status label (left-aligned)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.fromScale(1, 1)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = BOLD_FONT
	statusLabel.TextSize = MIN_TEXT_SIZE
	statusLabel.TextColor3 = (maxCraftable > 0) and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(220, 150, 150)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.ZIndex = 202
	statusLabel.Parent = statusBar

	-- INPUT CONTROLS (above craft button) - spans full width
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.Size = UDim2.new(1, 0, 0, controlsHeight)  -- Full width, larger controls
	controls.BackgroundTransparency = 1
	controls.ZIndex = 201  -- Above bottom section base
	controls.LayoutOrder = 2
	controls.Parent = bottomSection

	-- Input controls layout - left to right: -, amount, +, max
	local controlsLayout = Instance.new("UIListLayout")
	controlsLayout.FillDirection = Enum.FillDirection.Horizontal
	controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	controlsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	controlsLayout.Padding = UDim.new(0, 8)  -- Consistent spacing between controls
	controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	controlsLayout.Parent = controls

	-- 1. Minus button (leftmost) - matching inventory slot styling
	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "Minus"
	minusBtn.Size = UDim2.fromOffset(56, 56)  -- Matching inventory slot size
	minusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	minusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	minusBtn.BorderSizePixel = 0
	minusBtn.Font = BOLD_FONT
	minusBtn.TextSize = MIN_TEXT_SIZE
	minusBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	minusBtn.Text = "−"
	minusBtn.AutoButtonColor = false
	minusBtn.ZIndex = 202
	minusBtn.LayoutOrder = 1
	minusBtn.Parent = controls

	local minusCorner = Instance.new("UICorner")
	minusCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	minusCorner.Parent = minusBtn

	-- Background image matching inventory
	local minusBgImage = Instance.new("ImageLabel")
	minusBgImage.Name = "BackgroundImage"
	minusBgImage.Size = UDim2.fromScale(1, 1)
	minusBgImage.Position = UDim2.fromScale(0, 0)
	minusBgImage.BackgroundTransparency = 1
	minusBgImage.Image = "rbxassetid://82824299358542"
	minusBgImage.ImageTransparency = 0.6
	minusBgImage.ScaleType = Enum.ScaleType.Fit
	minusBgImage.ZIndex = 1
	minusBgImage.Parent = minusBtn

	-- Border matching inventory
	local minusBorder = Instance.new("UIStroke")
	minusBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	minusBorder.Thickness = 2
	minusBorder.Transparency = 0
	minusBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	minusBorder.Parent = minusBtn

	-- Add press animation
	self:AddButtonPressAnimation(minusBtn)

	-- 2. Amount textbox - matching inventory slot styling
	local qtyBox = Instance.new("TextBox")
	qtyBox.Name = "Quantity"
	qtyBox.Size = UDim2.fromOffset(80, 56)  -- Matching inventory slot height
	qtyBox.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	qtyBox.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	qtyBox.BorderSizePixel = 0
	qtyBox.Font = BOLD_FONT
	qtyBox.TextSize = MIN_TEXT_SIZE
	qtyBox.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	qtyBox.Text = "1"
	qtyBox.ClearTextOnFocus = false
	qtyBox.TextXAlignment = Enum.TextXAlignment.Center
	qtyBox.ZIndex = 202
	qtyBox.LayoutOrder = 2
	qtyBox.Parent = controls

	local qtyCorner = Instance.new("UICorner")
	qtyCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	qtyCorner.Parent = qtyBox

	-- Background image matching inventory
	local qtyBgImage = Instance.new("ImageLabel")
	qtyBgImage.Name = "BackgroundImage"
	qtyBgImage.Size = UDim2.fromScale(1, 1)
	qtyBgImage.Position = UDim2.fromScale(0, 0)
	qtyBgImage.BackgroundTransparency = 1
	qtyBgImage.Image = "rbxassetid://82824299358542"
	qtyBgImage.ImageTransparency = 0.6
	qtyBgImage.ScaleType = Enum.ScaleType.Fit
	qtyBgImage.ZIndex = 1
	qtyBgImage.Parent = qtyBox

	-- Border matching inventory
	local qtyBorder = Instance.new("UIStroke")
	qtyBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	qtyBorder.Thickness = 2
	qtyBorder.Transparency = 0
	qtyBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	qtyBorder.Parent = qtyBox

	-- 3. Plus button - matching inventory slot styling
	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "Plus"
	plusBtn.Size = UDim2.fromOffset(56, 56)  -- Matching inventory slot size
	plusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	plusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	plusBtn.BorderSizePixel = 0
	plusBtn.Font = BOLD_FONT
	plusBtn.TextSize = MIN_TEXT_SIZE
	plusBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	plusBtn.Text = "+"
	plusBtn.AutoButtonColor = false
	plusBtn.ZIndex = 202
	plusBtn.LayoutOrder = 3
	plusBtn.Parent = controls

	local plusCorner = Instance.new("UICorner")
	plusCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	plusCorner.Parent = plusBtn

	-- Background image matching inventory
	local plusBgImage = Instance.new("ImageLabel")
	plusBgImage.Name = "BackgroundImage"
	plusBgImage.Size = UDim2.fromScale(1, 1)
	plusBgImage.Position = UDim2.fromScale(0, 0)
	plusBgImage.BackgroundTransparency = 1
	plusBgImage.Image = "rbxassetid://82824299358542"
	plusBgImage.ImageTransparency = 0.6
	plusBgImage.ScaleType = Enum.ScaleType.Fit
	plusBgImage.ZIndex = 1
	plusBgImage.Parent = plusBtn

	-- Border matching inventory
	local plusBorder = Instance.new("UIStroke")
	plusBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	plusBorder.Thickness = 2
	plusBorder.Transparency = 0
	plusBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	plusBorder.Parent = plusBtn

	-- Add press animation
	self:AddButtonPressAnimation(plusBtn)

	-- 4. Max button (rightmost, takes remaining width) - matching inventory slot styling
	-- Calculate remaining width: minus(56) + spacing(8) + amount(80) + spacing(8) + plus(56) + spacing(8) = 216px
	local maxBtn = Instance.new("TextButton")
	maxBtn.Name = "Max"
	maxBtn.Size = UDim2.new(1, -216, 0, 56)  -- Full width minus other buttons and spacing
	maxBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	maxBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	maxBtn.BorderSizePixel = 0
	maxBtn.Font = BOLD_FONT
	maxBtn.TextSize = MIN_TEXT_SIZE
	maxBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	maxBtn.Text = "Max"
	maxBtn.AutoButtonColor = false
	maxBtn.ZIndex = 202
	maxBtn.LayoutOrder = 4
	maxBtn.Parent = controls

	local maxCorner = Instance.new("UICorner")
	maxCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	maxCorner.Parent = maxBtn

	-- Background image matching inventory
	local maxBgImage = Instance.new("ImageLabel")
	maxBgImage.Name = "BackgroundImage"
	maxBgImage.Size = UDim2.fromScale(1, 1)
	maxBgImage.Position = UDim2.fromScale(0, 0)
	maxBgImage.BackgroundTransparency = 1
	maxBgImage.Image = "rbxassetid://82824299358542"
	maxBgImage.ImageTransparency = 0.6
	maxBgImage.ScaleType = Enum.ScaleType.Fit
	maxBgImage.ZIndex = 1
	maxBgImage.Parent = maxBtn

	-- Border matching inventory
	local maxBorder = Instance.new("UIStroke")
	maxBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	maxBorder.Thickness = 2
	maxBorder.Transparency = 0
	maxBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	maxBorder.Parent = maxBtn

	-- Add press animation
	self:AddButtonPressAnimation(maxBtn)

	-- Craft button (below input controls) - matching inventory slot styling
	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "Craft"
	craftBtn.Size = UDim2.new(1, 0, 0, 56)  -- Full width, matching inventory slot height
	craftBtn.BackgroundColor3 = CRAFTING_CONFIG.CRAFT_BTN_COLOR
	craftBtn.BackgroundTransparency = 0
	craftBtn.BorderSizePixel = 0
	craftBtn.Font = BOLD_FONT  -- Matching other buttons
	craftBtn.TextSize = MIN_TEXT_SIZE  -- Matching inventory minimum text size
	craftBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	craftBtn.Text = "Craft"
	craftBtn.AutoButtonColor = false
	craftBtn.ZIndex = 202
	craftBtn.LayoutOrder = 3  -- Below input controls
	craftBtn.Parent = bottomSection

	local craftCorner = Instance.new("UICorner")
	craftCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	craftCorner.Parent = craftBtn

	-- Border matching inventory (no green border)
	local craftBorder = Instance.new("UIStroke")
	craftBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	craftBorder.Thickness = 2
	craftBorder.Transparency = 0
	craftBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	craftBorder.Parent = craftBtn

	-- Don't use custom font for craft button (regular font)
	-- FontBinder.apply(craftBtn, CUSTOM_FONT_NAME)

	-- Add press animation
	self:AddButtonPressAnimation(craftBtn)


	local function setStatus(text, ok)
		statusLabel.Text = text
		statusLabel.TextColor3 = ok and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(220, 150, 150)
	end

	local selectedQty = 1
	local function clampQty(q)
		q = math.floor(math.max(0, tonumber(q) or 0))
		if q == 0 then
			return 0
		end
		if maxCraftable and maxCraftable > 0 then
			return math.min(q, maxCraftable)
		end
		return q
	end

	local function refreshUI()
		-- Recalculate max (materials might have changed)
		maxCraftable, _materialsMax, _spaceMax = self:GetCompositeMaxCraft(selectedRecipe)
		selectedQty = clampQty(selectedQty)

		local canAny = maxCraftable > 0
		local _totalItems = selectedQty * (output.count or 0)
		craftBtn.Text = string.format("Craft ×%d", selectedQty)
		craftBtn.BackgroundColor3 = (canAny and selectedQty > 0) and CRAFTING_CONFIG.CRAFT_BTN_COLOR or CRAFTING_CONFIG.CRAFT_BTN_DISABLED_COLOR

		minusBtn.Active = selectedQty > 1
		if selectedQty > 1 then
			minusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
			minusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		else
			minusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_DISABLED_COLOR
			minusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_DISABLED_TRANSPARENCY
		end

		plusBtn.Active = selectedQty < maxCraftable
		if selectedQty < maxCraftable then
			plusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
			plusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		else
			plusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_DISABLED_COLOR
			plusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_DISABLED_TRANSPARENCY
		end

		maxBtn.Active = maxCraftable > 1 and selectedQty ~= maxCraftable
		if maxCraftable > 1 and selectedQty ~= maxCraftable then
			maxBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
			maxBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		else
			maxBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_DISABLED_COLOR
			maxBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_DISABLED_TRANSPARENCY
		end

		qtyBox.Text = tostring(selectedQty)

		-- Minimal status message
		if maxCraftable <= 0 then
			if materialsMax <= 0 then
				setStatus("⚠ Missing materials", false)
			else
				setStatus("⚠ Inventory full", false)
			end
		else
			-- Show simple available count
			if maxCraftable >= 99 then
				setStatus(string.format("✓ Can craft %d+", 99), true)
			else
				setStatus(string.format("✓ Can craft %d", maxCraftable), true)
			end
		end
	end

	-- Store refresh callback for external updates
	self._detailPageRefreshCallback = refreshUI
	self.activeTooltipRecipe = selectedRecipe

	-- Hover effects - matching inventory slot hover styling
	minusBtn.MouseEnter:Connect(function()
		if minusBtn.Active then
			minusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
		end
	end)
	minusBtn.MouseLeave:Connect(function()
		minusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		minusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		refreshUI()
	end)

	plusBtn.MouseEnter:Connect(function()
		if plusBtn.Active then
			plusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
		end
	end)
	plusBtn.MouseLeave:Connect(function()
		plusBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		plusBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		refreshUI()
	end)

	maxBtn.MouseEnter:Connect(function()
		if maxBtn.Active then
			maxBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
		end
	end)
	maxBtn.MouseLeave:Connect(function()
		maxBtn.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		maxBtn.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		refreshUI()
	end)

	craftBtn.MouseEnter:Connect(function()
		if maxCraftable > 0 and selectedQty > 0 then
			craftBtn.BackgroundColor3 = CRAFTING_CONFIG.CRAFT_BTN_HOVER
		end
	end)
	craftBtn.MouseLeave:Connect(function()
		refreshUI()
	end)

	minusBtn.MouseButton1Click:Connect(function()
		if selectedQty > 1 then
			selectedQty -= 1
			refreshUI()
		end
	end)

	plusBtn.MouseButton1Click:Connect(function()
		if selectedQty < maxCraftable then
			selectedQty += 1
			refreshUI()
		end
	end)

	maxBtn.MouseButton1Click:Connect(function()
		selectedQty = math.max(0, maxCraftable)
		refreshUI()
	end)

	qtyBox.FocusLost:Connect(function(enterPressed)
		selectedQty = clampQty(qtyBox.Text)
		refreshUI()
		if enterPressed and selectedQty > 0 then
			self:CraftQuantityToInventory(selectedRecipe, selectedQty)
		end
	end)

	craftBtn.MouseButton1Click:Connect(function()
		if selectedQty > 0 and maxCraftable > 0 then
			self:CraftQuantityToInventory(selectedRecipe, selectedQty)
		end
	end)



	-- Keyboard shortcuts
	detailPage.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			if selectedQty > 0 and maxCraftable > 0 then
				self:CraftQuantityToInventory(selectedRecipe, selectedQty)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			self:HideRecipeDetailPage()
		end
	end)

	-- Initialize
	refreshUI()

	return detailPage
end

--[[
	Create a compact variant option button (horizontal display)
	@param recipe: table - Recipe definition
	@param canCraft: boolean - Whether this variant can be crafted
	@param isSelected: boolean - Whether this is the selected variant
	@param variantIndex: number - Index of this variant
	@return: TextButton - Variant option button
]]

function CraftingPanel:CreateVariantOption(recipe, _canCraft, isSelected, variantIndex)
	-- Calculate height based on number of ingredients (56px per ingredient + spacing)
	local ingredientCount = #recipe.inputs
	local buttonHeight = (56 * ingredientCount) + (5 * (ingredientCount - 1)) + 16  -- 8px top + 8px bottom padding

	-- Button sized to fit standard 56×56 inventory slots
	local button = Instance.new("TextButton")
	button.Name = "Variant_" .. variantIndex
	button.Size = UDim2.fromOffset(72, buttonHeight)  -- 56px slots + 8px left + 8px right margin
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 104

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	btnCorner.Parent = button

	-- Border (no green border, standard inventory border)
	local btnBorder = Instance.new("UIStroke")
	btnBorder.Name = "BorderStroke"
	if isSelected then
		btnBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
		btnBorder.Thickness = 3
		btnBorder.Transparency = 0
	else
		btnBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
		btnBorder.Thickness = 2
		btnBorder.Transparency = 0
	end
	btnBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	btnBorder.Parent = button

	-- Container for ingredients (vertical stack)
	local ingredientsContainer = Instance.new("Frame")
	ingredientsContainer.Name = "Ingredients"
	ingredientsContainer.Size = UDim2.new(1, -16, 1, -16)  -- 8px padding on all sides
	ingredientsContainer.Position = UDim2.fromOffset(8, 8)
	ingredientsContainer.AnchorPoint = Vector2.new(0, 0)
	ingredientsContainer.BackgroundTransparency = 1
	ingredientsContainer.ZIndex = 105
	ingredientsContainer.Parent = button

	local ingredientsLayout = Instance.new("UIListLayout")
	ingredientsLayout.FillDirection = Enum.FillDirection.Vertical
	ingredientsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ingredientsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	ingredientsLayout.Padding = UDim.new(0, 5)  -- Matching inventory slot spacing
	ingredientsLayout.Parent = ingredientsContainer

	-- Show each ingredient as full 56×56 inventory slot (only if available)
	for i, input in ipairs(recipe.inputs) do
		-- Check if player has enough of this ingredient
		local playerCount = self.inventoryManager:CountItem(input.itemId)
		if playerCount < input.count then
			continue -- Skip ingredients that aren't available
		end

		-- Slot container (56×56 matching inventory exactly)
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. i
		slotFrame.Size = UDim2.fromOffset(56, 56)  -- Matching inventory slot size exactly
		slotFrame.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
		slotFrame.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
		slotFrame.BorderSizePixel = 0
		slotFrame.ClipsDescendants = false
		slotFrame.ZIndex = 105
		slotFrame.Parent = ingredientsContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
		slotCorner.Parent = slotFrame

		-- Background image matching inventory
		local bgImage = Instance.new("ImageLabel")
		bgImage.Name = "BackgroundImage"
		bgImage.Size = UDim2.fromScale(1, 1)
		bgImage.Position = UDim2.fromScale(0, 0)
		bgImage.BackgroundTransparency = 1
		bgImage.Image = "rbxassetid://82824299358542"
		bgImage.ImageTransparency = 0.6
		bgImage.ScaleType = Enum.ScaleType.Fit
		bgImage.ZIndex = 1
		bgImage.Parent = slotFrame

		-- Border matching inventory (no green border)
		local slotBorder = Instance.new("UIStroke")
		slotBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
		slotBorder.Thickness = 2
		slotBorder.Transparency = 0
		slotBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		slotBorder.Parent = slotFrame

		-- Icon container for viewport
		local iconContainer = Instance.new("Frame")
		iconContainer.Name = "IconContainer"
		iconContainer.Size = UDim2.fromScale(1, 1)
		iconContainer.Position = UDim2.fromScale(0, 0)
		iconContainer.BackgroundTransparency = 1
		iconContainer.ZIndex = 3  -- Above background image
		iconContainer.Parent = slotFrame

		-- Create full-size viewport
		BlockViewportCreator.CreateBlockViewport(
			iconContainer,
			input.itemId,
			UDim2.fromScale(1, 1)
		)

		-- Count badge (bottom-right like inventory, matching inventory style)
		if input.count > 1 then
			local countBadge = Instance.new("TextLabel")
			countBadge.Name = "CountBadge"
			countBadge.Size = UDim2.fromOffset(40, 20)  -- Matching inventory count label size
			countBadge.Position = UDim2.new(1, -4, 1, -4)
			countBadge.AnchorPoint = Vector2.new(1, 1)
			countBadge.BackgroundTransparency = 1
			countBadge.Font = BOLD_FONT
			countBadge.TextSize = MIN_TEXT_SIZE
			countBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
			countBadge.TextStrokeTransparency = 0.3
			countBadge.Text = tostring(input.count)
			countBadge.TextXAlignment = Enum.TextXAlignment.Right
			countBadge.ZIndex = 5  -- Above viewport
			countBadge.Parent = slotFrame
		end
	end

	-- Hover effect
	button.MouseEnter:Connect(function()
		if not isSelected then
			button.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
		end
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	end)

	-- Add press animation for tactile feedback
	self:AddButtonPressAnimation(button)

	return button
end

--[[
	Create ingredient row for tooltip
	@param input: table - Input requirement {itemId, count}
	@param canCraft: boolean - Whether player can craft
	@param layoutOrder: number - Layout order
	@return: Frame - Ingredient row
]]
function CraftingPanel:CreateIngredientRow(input, _canCraft, layoutOrder)
	local hasEnough = self.inventoryManager:CountItem(input.itemId) >= input.count

	local row = Instance.new("Frame")
	row.Name = "Ingredient_" .. input.itemId
	row.Size = UDim2.new(1, 0, 0, 56)  -- Matching inventory slot height
	row.BackgroundColor3 = CRAFTING_CONFIG.SLOT_BG_COLOR
	row.BackgroundTransparency = CRAFTING_CONFIG.SLOT_BG_TRANSPARENCY
	row.BorderSizePixel = 0
	row.ZIndex = 103
	row.LayoutOrder = layoutOrder

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)  -- Matching inventory corner radius
	rowCorner.Parent = row

	-- Background image matching inventory
	local bgImage = Instance.new("ImageLabel")
	bgImage.Name = "BackgroundImage"
	bgImage.Size = UDim2.fromScale(1, 1)
	bgImage.Position = UDim2.fromScale(0, 0)
	bgImage.BackgroundTransparency = 1
	bgImage.Image = "rbxassetid://82824299358542"
	bgImage.ImageTransparency = 0.6
	bgImage.ScaleType = Enum.ScaleType.Fit
	bgImage.ZIndex = 1
	bgImage.Parent = row

	-- Border matching inventory (no green border, always standard)
	local rowBorder = Instance.new("UIStroke")
	rowBorder.Name = "Border"
	rowBorder.Color = CRAFTING_CONFIG.BORDER_COLOR
	rowBorder.Thickness = 2
	rowBorder.Transparency = 0
	rowBorder.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rowBorder.Parent = row

	-- Icon (matching inventory slot size)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "Icon"
	iconContainer.Size = UDim2.fromOffset(56, 56)  -- Matching inventory slot size
	iconContainer.Position = UDim2.fromScale(0, 0.5)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ClipsDescendants = false
	iconContainer.ZIndex = 3  -- Above background image
	iconContainer.Parent = row

	-- Create viewport and ensure proper ZIndex
	local viewport = BlockViewportCreator.CreateBlockViewport(
		iconContainer,
		input.itemId,
		UDim2.fromScale(1, 1)
	)
	if viewport then
		viewport.ZIndex = 105
		for _, child in ipairs(viewport:GetDescendants()) do
			if child:IsA("GuiObject") or child:IsA("ViewportFrame") then
				child.ZIndex = 105
			end
		end
	end

	-- Item name
	local isTool = ToolConfig.IsTool(input.itemId)
	local itemName = ""
	if isTool then
		local toolInfo = ToolConfig.GetToolInfo(input.itemId)
		itemName = toolInfo and toolInfo.name or "Tool"
	else
		local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
		local blockDef = BlockRegistry.Blocks[input.itemId]
		itemName = blockDef and blockDef.name or "Item"
	end

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ItemName"
	-- Icon (56) + gap (8) = 64
	nameLabel.Size = UDim2.new(1, -140, 1, 0)  -- Reserve 64 left + 60 for right count + margins
	nameLabel.Position = UDim2.fromOffset(64, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Code
	nameLabel.TextSize = MIN_TEXT_SIZE  -- Matching inventory minimum text size
	nameLabel.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	nameLabel.Text = itemName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.ZIndex = 5  -- Above viewport
	nameLabel.Parent = row
	-- Don't use custom font for item name

	-- Count: available/required (show actual item counts, not stacks)
	local availableCount = self.inventoryManager:CountItem(input.itemId)
	local requiredCount = input.count
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0, 60, 1, 0)
	countLabel.Position = UDim2.new(1, -8, 0.5, 0)
	countLabel.AnchorPoint = Vector2.new(1, 0.5)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.Code
	countLabel.TextSize = MIN_TEXT_SIZE  -- Matching inventory minimum text size
	countLabel.TextColor3 = hasEnough and CRAFTING_CONFIG.TEXT_SUCCESS or CRAFTING_CONFIG.TEXT_ERROR
	countLabel.Text = string.format("%d/%d", availableCount, requiredCount)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.TextYAlignment = Enum.TextYAlignment.Center
	countLabel.ZIndex = 5  -- Above viewport
	countLabel.Parent = row
	FontBinder.apply(countLabel, CUSTOM_FONT_NAME)

	return row
end

-- PositionTooltip method removed - detail page is now a full overlay, no positioning needed

--[[
	Cleanup
]]
function CraftingPanel:Destroy()
	self:HideRecipeDetailPage()

	if self.hoverDebounce then
		task.cancel(self.hoverDebounce)
	end

	if self.container then
		self.container:Destroy()
	end
	self.recipeCards = {}
end

return CraftingPanel

