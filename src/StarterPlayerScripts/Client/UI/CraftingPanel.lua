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
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local RecipeConfig = require(ReplicatedStorage.Configs.RecipeConfig)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local CraftingSystem = require(ReplicatedStorage.Shared.VoxelWorld.Crafting.CraftingSystem)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CraftingPanel = {}
CraftingPanel.__index = CraftingPanel

-- UI Configuration (optimized for compact layout)
local CRAFTING_CONFIG = {
	PANEL_WIDTH = 230,  -- Ultra-compact width (detail overlays full panel)

	-- Grid Layout (optimized for 230px width)
	GRID_CELL_SIZE = 42,  -- Slightly smaller for better fit
	GRID_SPACING = 2,     -- Tighter spacing
	GRID_COLUMNS = 5,     -- 5 columns: (42×5) + (2×4) + (6×2) = 210 + 8 + 12 = 230px
	PADDING = 4,          -- Minimal padding for compact layout

	-- Icons
	INGREDIENT_ICON_SIZE = 32,  -- Icons in detail page

	-- Recipe Detail Page Configuration (full overlay, ultra-compact)
	DETAIL_PAGE_PADDING = 0,      -- No padding for maximum content space
	DETAIL_BACK_BUTTON_SIZE = 26, -- Slightly smaller
	HOVER_DELAY = 0,  -- Instant detail page

	-- Animation (disabled for straightforward UX)
	HOVER_SCALE = 1.0,  -- No scaling
	ANIMATION_SPEED = 0,  -- Instant transitions

	-- Colors (match VoxelInventoryPanel)
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_BG_COLOR = Color3.fromRGB(45, 45, 45),
	SLOT_HOVER_COLOR = Color3.fromRGB(55, 55, 55),
	SLOT_DISABLED_COLOR = Color3.fromRGB(40, 40, 40),
	SLOT_SELECTED_COLOR = Color3.fromRGB(65, 65, 65),  -- Mobile tap state
	SLOT_CRAFTABLE_GLOW = Color3.fromRGB(80, 180, 80),
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
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = self.parentFrame

	-- MINIMAL HEADER (ultra-compact)
	local headerSection = Instance.new("Frame")
	headerSection.Name = "HeaderSection"
	headerSection.Size = UDim2.new(1, 0, 0, 32)  -- More compact header
	headerSection.Position = UDim2.new(0, 0, 0, 0)
	headerSection.BackgroundTransparency = 1  -- Minimal: no background
	headerSection.BorderSizePixel = 0
	headerSection.Parent = container

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 5)  -- Match grid padding
	headerPadding.PaddingRight = UDim.new(0, 5)
	headerPadding.PaddingTop = UDim.new(0, 2)
	headerPadding.PaddingBottom = UDim.new(0, 2)
	headerPadding.Parent = headerSection

	-- Scrolling frame for recipes (below header, full width)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "RecipeScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -2)  -- Full width, below 32px header
	scrollFrame.Position = UDim2.new(0, 0, 0, 2)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 180, 80)
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = container

	-- Recipe grid container
	local recipeGrid = Instance.new("Frame")
	recipeGrid.Name = "RecipeGrid"
	recipeGrid.Size = UDim2.new(1, 0, 0, 0)
	recipeGrid.BackgroundTransparency = 1
	recipeGrid.AutomaticSize = Enum.AutomaticSize.Y
	recipeGrid.Parent = scrollFrame

	-- Optimized Grid Layout (5×N grid)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.Name = "GridLayout"
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellSize = UDim2.new(0, CRAFTING_CONFIG.GRID_CELL_SIZE, 0, CRAFTING_CONFIG.GRID_CELL_SIZE)
	gridLayout.CellPadding = UDim2.new(0, CRAFTING_CONFIG.GRID_SPACING, 0, CRAFTING_CONFIG.GRID_SPACING)
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center  -- Center for balanced layout
	gridLayout.Parent = recipeGrid

	-- Calculated padding for perfect 5-column fit
	local gridPadding = Instance.new("UIPadding")
	gridPadding.PaddingTop = UDim.new(0, 2)  -- Minimal top padding
	gridPadding.PaddingBottom = UDim.new(0, 4)
	gridPadding.PaddingLeft = UDim.new(0, 5)  -- Calculated: (230 - 220) / 2
	gridPadding.PaddingRight = UDim.new(0, 5)
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
	for i, recipe in ipairs(self.allRecipes) do
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
	for outputKey, group in pairs(recipeGroups) do
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
function CraftingPanel:CreateRecipeGridItem(group, canCraft, maxCount, layoutOrder)
	local output = group.output

	-- Grid slot (like inventory slot)
	local slot = Instance.new("TextButton")
	slot.Name = "Recipe_" .. output.itemId
	slot.Size = UDim2.new(0, CRAFTING_CONFIG.GRID_CELL_SIZE, 0, CRAFTING_CONFIG.GRID_CELL_SIZE)
	slot.BackgroundColor3 = canCraft and CRAFTING_CONFIG.SLOT_BG_COLOR or CRAFTING_CONFIG.SLOT_DISABLED_COLOR
	slot.BorderSizePixel = 0
	slot.AutoButtonColor = false
	slot.Text = ""
	slot.LayoutOrder = layoutOrder

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slot

	-- Border with glow when craftable
	local slotBorder = Instance.new("UIStroke")
	if canCraft then
		slotBorder.Color = CRAFTING_CONFIG.SLOT_CRAFTABLE_GLOW
		slotBorder.Thickness = 2
		slotBorder.Transparency = 0.5
	else
		slotBorder.Color = Color3.fromRGB(50, 50, 50)
		slotBorder.Thickness = 1
		slotBorder.Transparency = 0.8
	end
	slotBorder.Parent = slot

	-- Output icon container (fills most of the slot)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "Icon"
	iconContainer.Size = UDim2.new(1, -8, 1, -8)
	iconContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0.5, 0.5)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = slot

	-- Create 3D viewmodel
	BlockViewportCreator.CreateBlockViewport(
		iconContainer,
		output.itemId,
		UDim2.new(1, 0, 1, 0)
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
	Detect if running on mobile device
	@return: boolean - True if mobile
]]
function CraftingPanel:IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

--[[
	Setup grid item interactions with hover/tap tooltips and animations
	@param slot: TextButton - Recipe grid slot
	@param group: table - Recipe group definition
	@param canCraft: boolean - Whether player can craft
]]
function CraftingPanel:SetupGridItemInteractions(slot, group, canCraft)
	local originalColor = slot.BackgroundColor3

	-- Hover highlight (visual feedback only)
	slot.MouseEnter:Connect(function()
		if self.activeTooltipCard ~= slot then
			slot.BackgroundColor3 = CRAFTING_CONFIG.SLOT_HOVER_COLOR
		end
	end)

	slot.MouseLeave:Connect(function()
		if self.activeTooltipCard ~= slot then
			slot.BackgroundColor3 = originalColor
		end
	end)

	-- Click to show detail page (both desktop and mobile)
	slot.MouseButton1Click:Connect(function()
		if self.activeTooltipCard == slot then
			-- Clicked same slot, close detail page
			self:HideRecipeDetailPage()
			slot.BackgroundColor3 = originalColor
		else
			-- Open detail page for this slot
			-- Reset previous slot color if any
			if self.activeTooltipCard then
				self.activeTooltipCard.BackgroundColor3 = canCraft and CRAFTING_CONFIG.SLOT_BG_COLOR or CRAFTING_CONFIG.SLOT_DISABLED_COLOR
			end

			self:ShowRecipeDetailPage(slot, group, canCraft)
			slot.BackgroundColor3 = CRAFTING_CONFIG.SLOT_SELECTED_COLOR
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
			if hoverTween then hoverTween:Cancel() end
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
			if hoverTween then hoverTween:Cancel() end
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
					if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or
					   UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
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
		-- Reset slot background
		local canCraft = self.activeTooltipCard:GetAttribute("CanCraft")
		self.activeTooltipCard.BackgroundColor3 = canCraft and CRAFTING_CONFIG.SLOT_BG_COLOR or CRAFTING_CONFIG.SLOT_DISABLED_COLOR
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
	if not canCraft then return end

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
	if not canCraft or maxCraftable <= 0 then return end

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
	if not output then return 0, 0, 0 end
	local perCraft = output.count or 0
	if perCraft <= 0 then return 0, 0, 0 end

	local materialsMax = CraftingSystem:GetMaxCraftCount(recipe, self.inventoryManager)
	local spaceMax = self:GetMaxCraftBySpace(output.itemId, perCraft, materialsMax)
	return math.min(materialsMax, spaceMax), materialsMax, spaceMax
end

--[[
	Binary search for max crafts by space only, up to materialsUpperBound
]]
function CraftingPanel:GetMaxCraftBySpace(itemId, perCraft, materialsUpperBound)
	if (materialsUpperBound or 0) <= 0 then return 0 end
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
	if quantity <= 0 then return end

	-- Rate-limit rapid clicks
	self._lastCraftTs = self._lastCraftTs or 0
	if tick() - self._lastCraftTs < 0.1 then return end
	self._lastCraftTs = tick()

	-- Validate materials and space
	local compositeMax, materialsMax, _ = self:GetCompositeMaxCraft(recipe)
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
	if not self.activeTooltip then return end
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
		particle.Size = UDim2.new(0, 6, 0, 6)
		particle.Position = UDim2.new(0.5, 0, 0.5, 0)
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
			Size = UDim2.new(0, 2, 0, 2)
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
	if not inventoryGui then return end

	local inventoryPanel = inventoryGui:FindFirstChild("InventoryPanel")
	if not inventoryPanel then return end

	-- Create popup container
	local popup = Instance.new("Frame")
	popup.Name = "ItemRevealPopup"
	popup.Size = UDim2.new(0, 160, 0, 80)
	popup.Position = UDim2.new(0.5, 0, 0.3, 0)
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
	stroke.Parent = popup

	-- Icon (larger for dramatic effect in popup)
	local icon = Instance.new("Frame")
	icon.Size = UDim2.new(0, 64, 0, 64)
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
	local viewport = BlockViewportCreator.CreateBlockViewport(icon, output.itemId, UDim2.new(1, 0, 1, 0))
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
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = CRAFTING_CONFIG.TEXT_SUCCESS
	label.Text = string.format("+ %d", quantity * (output.count or 1))
	label.ZIndex = 251
	label.Parent = popup

	-- Animate in: scale up + fade in
	popup.Size = UDim2.new(0, 140, 0, 80)
	local tweenIn = TweenService:Create(popup, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 180, 0, 100),
		BackgroundTransparency = 0.1
	})
	TweenService:Create(stroke, TweenInfo.new(0.25), {Transparency = 0}):Play()
	tweenIn:Play()

	-- Hold, then animate out
	task.delay(1.2, function()
		if popup.Parent then
			local tweenOut = TweenService:Create(popup, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Position = UDim2.new(0.5, 0, 0.2, 0),
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
		if isPressed then return end
		isPressed = true

		-- Scale down
		TweenService:Create(button, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(originalSize.X.Scale, originalSize.X.Offset - 2, originalSize.Y.Scale, originalSize.Y.Offset - 2)
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		if not isPressed then return end
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
	if not stroke then return end

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
function CraftingPanel:CreateRecipeDetailPage(group, canCraft)
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
	local maxCraftable, materialsMax, spaceMax = self:GetCompositeMaxCraft(primaryRecipe)

	-- Detail page overlays the crafting panel exactly
	-- It's created as a child of the crafting container
	local detailPage = Instance.new("Frame")
	detailPage.Name = "RecipeDetailPage"
	detailPage.Size = UDim2.new(1, 0, 1, 0)  -- Full size overlay
	detailPage.Position = UDim2.new(0, 0, 0, 0)
	detailPage.BackgroundColor3 = Color3.fromRGB(35, 35, 35)  -- Match main panel color
	detailPage.BorderSizePixel = 0
	detailPage.ZIndex = 100  -- Above everything else in crafting panel
	detailPage.Visible = false
	detailPage.Parent = self.container

	-- HEADER SECTION (contains back button, icon with badge, and item name)
	local headerSection = Instance.new("Frame")
	headerSection.Name = "HeaderSection"
	headerSection.Size = UDim2.new(1, 0, 0, 50)  -- Compact header
	headerSection.Position = UDim2.new(0, 0, 0, 0)
	headerSection.BackgroundTransparency = 1  -- Minimal: no background
	headerSection.BorderSizePixel = 0
	headerSection.ZIndex = 101
	headerSection.Parent = detailPage

	local headerPadding = Instance.new("UIPadding")
	headerPadding.PaddingLeft = UDim.new(0, 6)  -- Minimal internal padding
	headerPadding.PaddingRight = UDim.new(0, 6)
	headerPadding.PaddingTop = UDim.new(0, 6)
	headerPadding.PaddingBottom = UDim.new(0, 6)
	headerPadding.Parent = headerSection

	-- Back button (left side)
	local backButton = Instance.new("TextButton")
	backButton.Name = "BackButton"
	backButton.Size = UDim2.new(0, 34, 0, 34)  -- Larger for easier clicking
	backButton.Position = UDim2.new(0, 0, 0.5, 0)
	backButton.AnchorPoint = Vector2.new(0, 0.5)
	backButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	backButton.BorderSizePixel = 0
	backButton.Font = Enum.Font.GothamBold
	backButton.TextSize = 18
	backButton.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	backButton.Text = "←"
	backButton.ZIndex = 102
	backButton.Parent = headerSection

	local backCorner = Instance.new("UICorner")
	backCorner.CornerRadius = UDim.new(0, 8)
	backCorner.Parent = backButton

	self:AddButtonPressAnimation(backButton)

	backButton.MouseEnter:Connect(function()
		backButton.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	end)

	backButton.MouseLeave:Connect(function()
		backButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	end)

	backButton.MouseButton1Click:Connect(function()
		self:HideRecipeDetailPage()
	end)

	-- Item icon with badge (center-left)
	local itemIconContainer = Instance.new("Frame")
	itemIconContainer.Name = "ItemIconContainer"
	itemIconContainer.Size = UDim2.new(0, 38, 0, 38)  -- Slightly smaller icon
	itemIconContainer.Position = UDim2.new(0, 42, 0.5, 0)  -- Adjusted for larger back button
	itemIconContainer.AnchorPoint = Vector2.new(0, 0.5)
	itemIconContainer.BackgroundTransparency = 1
	itemIconContainer.ZIndex = 102
	itemIconContainer.Parent = headerSection

	local itemIcon = Instance.new("Frame")
	itemIcon.Name = "ItemIcon"
	itemIcon.Size = UDim2.new(1, 0, 1, 0)
	itemIcon.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	itemIcon.BorderSizePixel = 0
	itemIcon.ClipsDescendants = false
	itemIcon.ZIndex = 103
	itemIcon.Parent = itemIconContainer

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 8)
	iconCorner.Parent = itemIcon

	-- Create viewport
	local viewport = BlockViewportCreator.CreateBlockViewport(itemIcon, output.itemId, UDim2.new(1, 0, 1, 0))
	if viewport then
		viewport.ZIndex = 104
		for _, child in ipairs(viewport:GetDescendants()) do
			if child:IsA("GuiObject") or child:IsA("ViewportFrame") then
				child.ZIndex = 104
			end
		end
	end

	-- Output count badge (bottom-right of icon)
	local countBadge = Instance.new("TextLabel")
	countBadge.Name = "CountBadge"
	countBadge.Size = UDim2.new(0, 24, 0, 16)  -- Slightly smaller
	countBadge.Position = UDim2.new(1, -1, 1, -1)
	countBadge.AnchorPoint = Vector2.new(1, 1)
	countBadge.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	countBadge.BorderSizePixel = 0
	countBadge.Font = Enum.Font.GothamBold
	countBadge.TextSize = 10  -- Slightly smaller
	countBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
	countBadge.Text = "×" .. (output.count or 1)
	countBadge.ZIndex = 105
	countBadge.Parent = itemIconContainer

	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(0, 4)
	badgeCorner.Parent = countBadge

	-- Item name (right of icon)
	local itemName = Instance.new("TextLabel")
	itemName.Name = "ItemName"
	itemName.Size = UDim2.new(1, -88, 1, 0)  -- Adjusted for larger back button + icon spacing
	itemName.Position = UDim2.new(0, 88, 0, 0)
	itemName.BackgroundTransparency = 1
	itemName.Font = Enum.Font.GothamBold
	itemName.TextSize = 14  -- Slightly smaller text
	itemName.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	itemName.Text = group.displayName
	itemName.TextXAlignment = Enum.TextXAlignment.Left
	itemName.TextYAlignment = Enum.TextYAlignment.Center
	itemName.ZIndex = 102
	itemName.Parent = headerSection

	-- Scrolling frame for content (below header, full width)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ContentScroll"
	scrollFrame.Size = UDim2.new(1, 0, 1, -50)  -- Full width, below 50px header
	scrollFrame.Position = UDim2.new(0, 0, 0, 50)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 6
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 180, 80)
	scrollFrame.ScrollBarImageTransparency = 0.4
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.ZIndex = 101
	scrollFrame.Parent = detailPage

	-- Content container
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.new(1, 0, 0, 0)
	content.AutomaticSize = Enum.AutomaticSize.Y
	content.BackgroundTransparency = 1
	content.ZIndex = 102
	content.Parent = scrollFrame

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 6)  -- Reduced spacing between sections
	contentLayout.Parent = content

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 4)  -- Minimal padding
	contentPadding.PaddingBottom = UDim.new(0, 6)
	contentPadding.PaddingLeft = UDim.new(0, 8)  -- Slightly more for readability
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
	ingredientsLabel.Size = UDim2.new(1, 0, 0, 12)  -- Compact label
	ingredientsLabel.BackgroundTransparency = 1
	ingredientsLabel.Font = Enum.Font.GothamBold
	ingredientsLabel.TextSize = 9  -- Slightly smaller
	ingredientsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
	ingredientsLabel.Text = #availableRecipes > 1 and "RECIPE VARIANTS" or "REQUIRED MATERIALS"
	ingredientsLabel.TextXAlignment = Enum.TextXAlignment.Left
	ingredientsLabel.ZIndex = 103
	ingredientsLabel.LayoutOrder = 2
	ingredientsLabel.Parent = content

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
	variantsContainer.Size = UDim2.new(1, 0, 0, 0)
	variantsContainer.AutomaticSize = Enum.AutomaticSize.Y
	variantsContainer.BackgroundTransparency = 1
	variantsContainer.ZIndex = 103
	variantsContainer.LayoutOrder = 3
	variantsContainer.Parent = content

	local variantsLayout = Instance.new("UIListLayout")
	variantsLayout.FillDirection = Enum.FillDirection.Horizontal
	variantsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	variantsLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	variantsLayout.Padding = UDim.new(0, 6)  -- Tighter spacing between variants
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

			-- Update visual state of all buttons
			for i, btn in ipairs(variantButtons) do
				local btnBorder = btn:FindFirstChild("BorderStroke")
				local selBar = btn:FindFirstChild("SelectionBar")
				if i == variantIndex then
					-- Selected
					btnBorder.Color = Color3.fromRGB(80, 180, 80)
					btnBorder.Thickness = 3
					btnBorder.Transparency = 0
					if selBar then selBar.Visible = true end
				else
					-- Not selected
					btnBorder.Color = Color3.fromRGB(70, 70, 70)
					btnBorder.Thickness = 1
					btnBorder.Transparency = 0.6
					if selBar then selBar.Visible = false end
				end
			end
		end)
	end

	-- Divider line above controls
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	divider.BackgroundTransparency = 0.5
	divider.BorderSizePixel = 0
	divider.ZIndex = 103
	divider.LayoutOrder = 98  -- Right before controls
	divider.Parent = content

	-- MINIMAL STATUS (below controls, compact single line)
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(1, 0, 0, 12)  -- Even more compact
	statusBar.BackgroundTransparency = 1
	statusBar.BorderSizePixel = 0
	statusBar.ZIndex = 103
	statusBar.LayoutOrder = 101  -- Right after controls (LayoutOrder = 100)
	statusBar.Parent = content

	local statusPadding = Instance.new("UIPadding")
	statusPadding.PaddingTop = UDim.new(0, 1)  -- Minimal padding
	statusPadding.PaddingBottom = UDim.new(0, 1)
	statusPadding.Parent = statusBar

	-- Single minimal status line (left-aligned)
	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, 0, 1, 0)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 8  -- Even smaller for ultra-compact
	statusLabel.TextColor3 = (maxCraftable > 0) and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(220, 150, 150)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.ZIndex = 104
	statusLabel.Parent = statusBar

	-- COMPACT CONTROLS (tighter layout)
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.Size = UDim2.new(1, 0, 0, 28)  -- Reduced from 32 to 28
	controls.BackgroundTransparency = 1
	controls.ZIndex = 103
	controls.LayoutOrder = 100
	controls.Parent = content

	local minusBtn = Instance.new("TextButton")
	minusBtn.Name = "Minus"
	minusBtn.Size = UDim2.new(0, 28, 1, 0)
	minusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	minusBtn.BorderSizePixel = 0
	minusBtn.Font = Enum.Font.GothamBold
	minusBtn.TextSize = 14
	minusBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	minusBtn.Text = "−"
	minusBtn.AutoButtonColor = false
	minusBtn.ZIndex = 104
	minusBtn.Parent = controls

	local minusCorner = Instance.new("UICorner")
	minusCorner.CornerRadius = UDim.new(0, 4)
	minusCorner.Parent = minusBtn

	-- Add press animation
	self:AddButtonPressAnimation(minusBtn)

	local qtyBox = Instance.new("TextBox")
	qtyBox.Name = "Quantity"
	qtyBox.Size = UDim2.new(0, 54, 1, 0)
	qtyBox.Position = UDim2.new(0, 32, 0, 0)
	qtyBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	qtyBox.BorderSizePixel = 0
	qtyBox.Font = Enum.Font.GothamBold
	qtyBox.TextSize = 12
	qtyBox.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	qtyBox.Text = "1"
	qtyBox.ClearTextOnFocus = false
	qtyBox.TextXAlignment = Enum.TextXAlignment.Center
	qtyBox.ZIndex = 104
	qtyBox.Parent = controls

	local qtyCorner = Instance.new("UICorner")
	qtyCorner.CornerRadius = UDim.new(0, 4)
	qtyCorner.Parent = qtyBox

	local plusBtn = Instance.new("TextButton")
	plusBtn.Name = "Plus"
	plusBtn.Size = UDim2.new(0, 28, 1, 0)
	plusBtn.Position = UDim2.new(0, 88, 0, 0)
	plusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	plusBtn.BorderSizePixel = 0
	plusBtn.Font = Enum.Font.GothamBold
	plusBtn.TextSize = 14
	plusBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	plusBtn.Text = "+"
	plusBtn.AutoButtonColor = false
	plusBtn.ZIndex = 104
	plusBtn.Parent = controls

	local plusCorner = Instance.new("UICorner")
	plusCorner.CornerRadius = UDim.new(0, 4)
	plusCorner.Parent = plusBtn

	-- Add press animation
	self:AddButtonPressAnimation(plusBtn)

	local maxBtn = Instance.new("TextButton")
	maxBtn.Name = "Max"
	maxBtn.Size = UDim2.new(0, 44, 1, 0)
	maxBtn.Position = UDim2.new(0, 120, 0, 0)
	maxBtn.BackgroundColor3 = Color3.fromRGB(70, 140, 200)
	maxBtn.BorderSizePixel = 0
	maxBtn.Font = Enum.Font.GothamBold
	maxBtn.TextSize = 11
	maxBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	maxBtn.Text = "Max"
	maxBtn.AutoButtonColor = false
	maxBtn.ZIndex = 104
	maxBtn.Parent = controls

	local maxCorner = Instance.new("UICorner")
	maxCorner.CornerRadius = UDim.new(0, 4)
	maxCorner.Parent = maxBtn

	-- Add press animation
	self:AddButtonPressAnimation(maxBtn)

	local craftBtn = Instance.new("TextButton")
	craftBtn.Name = "Craft"
	craftBtn.Size = UDim2.new(1, -168, 1, 0)
	craftBtn.Position = UDim2.new(0, 168, 0, 0)
	craftBtn.BackgroundColor3 = CRAFTING_CONFIG.CRAFT_BTN_COLOR
	craftBtn.BorderSizePixel = 0
	craftBtn.Font = Enum.Font.GothamBold
	craftBtn.TextSize = 12
	craftBtn.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	craftBtn.Text = "Craft"
	craftBtn.AutoButtonColor = false
	craftBtn.ZIndex = 104
	craftBtn.Parent = controls

	local craftCorner = Instance.new("UICorner")
	craftCorner.CornerRadius = UDim.new(0, 4)
	craftCorner.Parent = craftBtn

	-- Add press animation
	self:AddButtonPressAnimation(craftBtn)


	local function setStatus(text, ok)
		statusLabel.Text = text
		statusLabel.TextColor3 = ok and Color3.fromRGB(150, 220, 150) or Color3.fromRGB(220, 150, 150)
	end

	local selectedQty = 1
	local function clampQty(q)
		q = math.floor(math.max(0, tonumber(q) or 0))
		if q == 0 then return 0 end
		if maxCraftable and maxCraftable > 0 then
			return math.min(q, maxCraftable)
		end
		return q
	end

	local function refreshUI()
		-- Recalculate max (materials might have changed)
		maxCraftable, materialsMax, spaceMax = self:GetCompositeMaxCraft(selectedRecipe)
		selectedQty = clampQty(selectedQty)

		local canAny = maxCraftable > 0
		local totalItems = selectedQty * (output.count or 0)
		craftBtn.Text = string.format("Craft ×%d", selectedQty)
		craftBtn.BackgroundColor3 = (canAny and selectedQty > 0) and CRAFTING_CONFIG.CRAFT_BTN_COLOR or CRAFTING_CONFIG.CRAFT_BTN_DISABLED_COLOR

		minusBtn.Active = selectedQty > 1
		minusBtn.BackgroundColor3 = (selectedQty > 1) and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(45, 45, 45)

		plusBtn.Active = selectedQty < maxCraftable
		plusBtn.BackgroundColor3 = (selectedQty < maxCraftable) and Color3.fromRGB(60, 60, 60) or Color3.fromRGB(45, 45, 45)

		maxBtn.Active = maxCraftable > 1 and selectedQty ~= maxCraftable
		maxBtn.BackgroundColor3 = (maxCraftable > 1 and selectedQty ~= maxCraftable) and Color3.fromRGB(70, 140, 200) or Color3.fromRGB(50, 50, 50)

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

	-- Hover effects
	minusBtn.MouseEnter:Connect(function()
		if minusBtn.Active then
			minusBtn.BackgroundColor3 = Color3.fromRGB(75, 75, 75)
		end
	end)
	minusBtn.MouseLeave:Connect(function()
		refreshUI()
	end)

	plusBtn.MouseEnter:Connect(function()
		if plusBtn.Active then
			plusBtn.BackgroundColor3 = Color3.fromRGB(75, 75, 75)
		end
	end)
	plusBtn.MouseLeave:Connect(function()
		refreshUI()
	end)

	maxBtn.MouseEnter:Connect(function()
		if maxBtn.Active then
			maxBtn.BackgroundColor3 = Color3.fromRGB(80, 150, 210)
		end
	end)
	maxBtn.MouseLeave:Connect(function()
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
		if gpe then return end
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

function CraftingPanel:CreateVariantOption(recipe, canCraft, isSelected, variantIndex)
	-- Calculate height based on number of ingredients (44px per ingredient + spacing)
	local ingredientCount = #recipe.inputs
	local buttonHeight = (44 * ingredientCount) + (4 * (ingredientCount - 1)) + 8  -- 8px padding

	-- Button sized to fit standard 44×44 inventory slots (ultra-compact)
	local button = Instance.new("TextButton")
	button.Name = "Variant_" .. variantIndex
	button.Size = UDim2.new(0, 48, 0, buttonHeight)  -- Ultra-compact: 44px slots + 4px margin
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.ZIndex = 104

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = button

	-- Border (different for selected/available/unavailable)
	local btnBorder = Instance.new("UIStroke")
	btnBorder.Name = "BorderStroke"
	if isSelected then
		btnBorder.Color = Color3.fromRGB(80, 180, 80)
		btnBorder.Thickness = 3
		btnBorder.Transparency = 0
	elseif canCraft then
		btnBorder.Color = Color3.fromRGB(70, 70, 70)
		btnBorder.Thickness = 1
		btnBorder.Transparency = 0.6
	else
		btnBorder.Color = Color3.fromRGB(180, 60, 60)
		btnBorder.Thickness = 1
		btnBorder.Transparency = 0.7
	end
	btnBorder.Parent = button

	-- Selection bar for extra clarity
	local selectionBar = Instance.new("Frame")
	selectionBar.Name = "SelectionBar"
	selectionBar.Size = UDim2.new(1, 0, 0, 3)
	selectionBar.Position = UDim2.new(0, 0, 0, 0)
	selectionBar.BackgroundColor3 = Color3.fromRGB(80, 180, 80)
	selectionBar.BorderSizePixel = 0
	selectionBar.Visible = isSelected
	selectionBar.ZIndex = 106
	selectionBar.Parent = button

	-- Container for ingredients (vertical stack, ultra-compact with no padding)
	local ingredientsContainer = Instance.new("Frame")
	ingredientsContainer.Name = "Ingredients"
	ingredientsContainer.Size = UDim2.new(1, 0, 1, -6)  -- No horizontal padding, minimal vertical padding
	ingredientsContainer.Position = UDim2.new(0, 0, 0, 3)  -- Absolute positioning for consistent 3px top padding
	ingredientsContainer.AnchorPoint = Vector2.new(0, 0)
	ingredientsContainer.BackgroundTransparency = 1
	ingredientsContainer.ZIndex = 105
	ingredientsContainer.Parent = button

	local ingredientsLayout = Instance.new("UIListLayout")
	ingredientsLayout.FillDirection = Enum.FillDirection.Vertical
	ingredientsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ingredientsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ingredientsLayout.Padding = UDim.new(0, 4)
	ingredientsLayout.Parent = ingredientsContainer

	-- Show each ingredient as full 44×44 inventory slot (only if available)
	for i, input in ipairs(recipe.inputs) do
		-- Check if player has enough of this ingredient
		local playerCount = self.inventoryManager:CountItem(input.itemId)
		if playerCount < input.count then
			continue -- Skip ingredients that aren't available
		end

		-- Slot container (44×44 standard size)
		local slotFrame = Instance.new("Frame")
		slotFrame.Name = "Slot_" .. i
		slotFrame.Size = UDim2.new(0, 44, 0, 44)
		slotFrame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		slotFrame.BorderSizePixel = 0
		slotFrame.ClipsDescendants = false
		slotFrame.ZIndex = 105
		slotFrame.Parent = ingredientsContainer

		local slotCorner = Instance.new("UICorner")
		slotCorner.CornerRadius = UDim.new(0, 6)
		slotCorner.Parent = slotFrame

		-- Create full-size viewport
		local createdVariant = BlockViewportCreator.CreateBlockViewport(
			slotFrame,
			input.itemId,
			UDim2.new(1, 0, 1, 0)
		)
		-- Raise child viewport/image above slot background
		if createdVariant then
			if createdVariant:IsA("ViewportFrame") or createdVariant:IsA("ImageLabel") then
				createdVariant.ZIndex = slotFrame.ZIndex + 1
			else
				local childVP = createdVariant:FindFirstChildWhichIsA("ViewportFrame") or createdVariant:FindFirstChildWhichIsA("ImageLabel")
				if childVP then
					childVP.ZIndex = slotFrame.ZIndex + 1
				end
			end
		end

		-- Count badge (bottom-right like inventory)
		if input.count > 1 then
			local countBadge = Instance.new("TextLabel")
			countBadge.Name = "CountBadge"
			countBadge.Size = UDim2.new(0, 24, 0, 16)
			countBadge.Position = UDim2.new(1, -2, 1, -2)
			countBadge.AnchorPoint = Vector2.new(1, 1)
			countBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			countBadge.BackgroundTransparency = 0.3
			countBadge.BorderSizePixel = 0
			countBadge.Font = Enum.Font.GothamBold
			countBadge.TextSize = 11
			countBadge.TextColor3 = canCraft and CRAFTING_CONFIG.TEXT_COLOR or Color3.fromRGB(180, 100, 100)
			countBadge.TextStrokeTransparency = 0.5
			countBadge.Text = "×" .. input.count
			countBadge.ZIndex = 107
			countBadge.Parent = slotFrame

			local badgeCorner = Instance.new("UICorner")
			badgeCorner.CornerRadius = UDim.new(0, 3)
			badgeCorner.Parent = countBadge
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
function CraftingPanel:CreateIngredientRow(input, canCraft, layoutOrder)
	local hasEnough = self.inventoryManager:CountItem(input.itemId) >= input.count

	local row = Instance.new("Frame")
	row.Name = "Ingredient_" .. input.itemId
	row.Size = UDim2.new(1, 0, 0, 38)  -- More compact
	row.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	row.BackgroundTransparency = 0
	row.BorderSizePixel = 0
	row.ZIndex = 103
	row.LayoutOrder = layoutOrder

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 4)
	rowCorner.Parent = row

	-- Left border indicator for status
	local statusBar = Instance.new("Frame")
	statusBar.Name = "StatusBar"
	statusBar.Size = UDim2.new(0, 3, 1, 0)
	statusBar.Position = UDim2.new(0, 0, 0, 0)
	statusBar.BackgroundColor3 = hasEnough and CRAFTING_CONFIG.SLOT_CRAFTABLE_GLOW or CRAFTING_CONFIG.TEXT_ERROR
	statusBar.BorderSizePixel = 0
	statusBar.ZIndex = 104
	statusBar.Parent = row

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 4)
	barCorner.Parent = statusBar

	-- Icon (compact size)
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "Icon"
	iconContainer.Size = UDim2.new(0, 38, 0, 38)  -- Compact
	iconContainer.Position = UDim2.new(0, 6, 0.5, 0)
	iconContainer.AnchorPoint = Vector2.new(0, 0.5)
	iconContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	iconContainer.BackgroundTransparency = 0
	iconContainer.BorderSizePixel = 0
	iconContainer.ClipsDescendants = false
	iconContainer.ZIndex = 104
	iconContainer.Parent = row

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(0, 5)
	iconCorner.Parent = iconContainer

	-- Create viewport and ensure proper ZIndex
	local viewport = BlockViewportCreator.CreateBlockViewport(
		iconContainer,
		input.itemId,
		UDim2.new(1, 0, 1, 0)
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
	-- Left padding (6) + icon (38) + gap (6) = 50
	nameLabel.Size = UDim2.new(1, -120, 1, 0)  -- Reserve ~50 left + 60 for right count + margins
	nameLabel.Position = UDim2.new(0, 50, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 10  -- Slightly smaller for compact layout
	nameLabel.TextColor3 = CRAFTING_CONFIG.TEXT_COLOR
	nameLabel.Text = itemName
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.ZIndex = 104
	nameLabel.Parent = row

	-- Count: available/required (show actual item counts, not stacks)
	local availableCount = self.inventoryManager:CountItem(input.itemId)
	local requiredCount = input.count
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "Count"
	countLabel.Size = UDim2.new(0, 56, 1, 0)  -- Slightly narrower
	countLabel.Position = UDim2.new(1, -6, 0, 0)
	countLabel.AnchorPoint = Vector2.new(1, 0)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 10  -- Slightly smaller
	countLabel.TextColor3 = hasEnough and CRAFTING_CONFIG.TEXT_SUCCESS or CRAFTING_CONFIG.TEXT_ERROR
	countLabel.Text = string.format("%d/%d", availableCount, requiredCount)
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 104
	countLabel.Parent = row

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

