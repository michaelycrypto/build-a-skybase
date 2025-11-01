--[[
	ChestUI.lua
	Minecraft-style chest interface with drag-and-drop
	Shows chest inventory (27 slots) + player inventory (27 slots)
	Note: Hotbar remains visible at bottom of screen (not included in chest UI)
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
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)
local TextureManager = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.TextureManager)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local GameConfig = require(ReplicatedStorage.Configs.GameConfig)

local ChestUI = {}
ChestUI.__index = ChestUI

-- Configuration
local CHEST_CONFIG = {
	COLUMNS = 9,
	CHEST_ROWS = 3, -- 27 chest slots
	INVENTORY_ROWS = 3, -- 27 inventory slots
	SLOT_SIZE = 52,
	SLOT_SPACING = 4,
	PADDING = 20,
	SECTION_SPACING = 20,

	-- Colors
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
}

function ChestUI.new(inventoryManager, inventoryPanel)
	local self = setmetatable({}, ChestUI)

	-- Use centralized inventory manager
	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar
	self.inventoryPanel = inventoryPanel

	self.isOpen = false
	self.gui = nil
	self.panel = nil
	self.chestPosition = nil -- {x, y, z} of current chest

	-- Chest slots (27 slots) - local to this UI
	self.chestSlots = {}
	self.chestSlotFrames = {}

	-- UI slot frames for inventory display
	self.inventorySlotFrames = {}

	-- Cursor/drag state
	self.cursorStack = ItemStack.new(0, 0)
	self.cursorFrame = nil

	self.connections = {}
	self.renderConnection = nil

	-- Initialize empty chest slots
	for i = 1, 27 do
		self.chestSlots[i] = ItemStack.new(0, 0)
	end

	return self
end

function ChestUI:Initialize()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "ChestUI"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 101 -- Above inventory panel
	self.gui.IgnoreGuiInset = true
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Add responsive scaling (100% = original size)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080)) -- 1920x1080 for 100% original size
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Create panels
	self:CreatePanel()
	self:CreateCursorItem()

	-- Bind input
	self:BindInput()

	-- Register network events
	self:RegisterEvents()

	return self
end

function ChestUI:CreatePanel()
	local slotWidth = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.COLUMNS +
	                  CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.COLUMNS - 1)
	local chestHeight = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.CHEST_ROWS +
	                    CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.CHEST_ROWS - 1)
	local invHeight = CHEST_CONFIG.SLOT_SIZE * CHEST_CONFIG.INVENTORY_ROWS +
	                  CHEST_CONFIG.SLOT_SPACING * (CHEST_CONFIG.INVENTORY_ROWS - 1)

	local totalHeight = chestHeight + invHeight +
	                    CHEST_CONFIG.SECTION_SPACING + -- Between chest and inventory
	                    CHEST_CONFIG.PADDING * 2 +
	                    50 + 25 + 25 -- Title + labels (no hotbar label)

	-- Background overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	overlay.BackgroundTransparency = 0.5
	overlay.BorderSizePixel = 0
	overlay.Parent = self.gui

	-- Main panel
	self.panel = Instance.new("Frame")
	self.panel.Name = "ChestPanel"
	self.panel.Size = UDim2.new(0, slotWidth + CHEST_CONFIG.PADDING * 2, 0, totalHeight)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.panel.AnchorPoint = Vector2.new(0.5, 0.5)
	self.panel.BackgroundColor3 = CHEST_CONFIG.BG_COLOR
	self.panel.BorderSizePixel = 0
	self.panel.Parent = self.gui

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = self.panel

	-- Border
	local stroke = Instance.new("UIStroke")
	stroke.Color = CHEST_CONFIG.BORDER_COLOR
	stroke.Thickness = 3
	stroke.Parent = self.panel

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "Chest"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = self.panel

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 30, 0, 30)
	closeBtn.Position = UDim2.new(1, -40, 0, 15)
	closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	closeBtn.BorderSizePixel = 0
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 18
	closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	closeBtn.Text = "×"
	closeBtn.Parent = self.panel

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 6)
	closeCorner.Parent = closeBtn

	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	local yOffset = 50

	-- === CHEST SECTION ===
	local chestLabel = Instance.new("TextLabel")
	chestLabel.Size = UDim2.new(1, -40, 0, 20)
	chestLabel.Position = UDim2.new(0, 20, 0, yOffset)
	chestLabel.BackgroundTransparency = 1
	chestLabel.Font = Enum.Font.Gotham
	chestLabel.TextSize = 14
	chestLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	chestLabel.Text = "Chest"
	chestLabel.TextXAlignment = Enum.TextXAlignment.Left
	chestLabel.Parent = self.panel

	yOffset = yOffset + 25

	-- Create chest slots (3 rows of 9)
	for row = 0, CHEST_CONFIG.CHEST_ROWS - 1 do
		for col = 0, CHEST_CONFIG.COLUMNS - 1 do
			local index = row * CHEST_CONFIG.COLUMNS + col + 1
			local x = CHEST_CONFIG.PADDING + col * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			self:CreateChestSlot(index, x, y)
		end
	end

	yOffset = yOffset + chestHeight + CHEST_CONFIG.SECTION_SPACING

	-- === INVENTORY SECTION ===
	local invLabel = Instance.new("TextLabel")
	invLabel.Size = UDim2.new(1, -40, 0, 20)
	invLabel.Position = UDim2.new(0, 20, 0, yOffset)
	invLabel.BackgroundTransparency = 1
	invLabel.Font = Enum.Font.Gotham
	invLabel.TextSize = 14
	invLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	invLabel.Text = "Inventory"
	invLabel.TextXAlignment = Enum.TextXAlignment.Left
	invLabel.Parent = self.panel

	yOffset = yOffset + 25

	-- Create inventory slots (3 rows of 9)
	for row = 0, CHEST_CONFIG.INVENTORY_ROWS - 1 do
		for col = 0, CHEST_CONFIG.COLUMNS - 1 do
			local index = row * CHEST_CONFIG.COLUMNS + col + 1
			local x = CHEST_CONFIG.PADDING + col * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (CHEST_CONFIG.SLOT_SIZE + CHEST_CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, x, y)
		end
	end

	-- Note: Hotbar remains visible at bottom of screen (not included in chest UI)
end

function ChestUI:CreateChestSlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "ChestSlot" .. index
	slot.Size = UDim2.new(0, CHEST_CONFIG.SLOT_SIZE, 0, CHEST_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = CHEST_CONFIG.SLOT_COLOR
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(255, 255, 255)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.Parent = slot

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

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
	countLabel.ZIndex = 4
	countLabel.Parent = slot

	self.chestSlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder
	}

	-- Hover effects
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = CHEST_CONFIG.HOVER_COLOR
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = CHEST_CONFIG.SLOT_COLOR
	end)

	-- Click handlers
	slot.MouseButton1Click:Connect(function()
		self:OnChestSlotLeftClick(index)
	end)

	slot.MouseButton2Click:Connect(function()
		self:OnChestSlotRightClick(index)
	end)

	self:UpdateChestSlotDisplay(index)
end

function ChestUI:CreateInventorySlot(index, x, y)
	local slot = Instance.new("TextButton")
	slot.Name = "InventorySlot" .. index
	slot.Size = UDim2.new(0, CHEST_CONFIG.SLOT_SIZE, 0, CHEST_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, x, 0, y)
	slot.BackgroundColor3 = CHEST_CONFIG.SLOT_COLOR
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	local hoverBorder = Instance.new("UIStroke")
	hoverBorder.Name = "HoverBorder"
	hoverBorder.Color = Color3.fromRGB(255, 255, 255)
	hoverBorder.Thickness = 2
	hoverBorder.Transparency = 1
	hoverBorder.Parent = slot

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

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
	countLabel.ZIndex = 4
	countLabel.Parent = slot

	self.inventorySlotFrames[index] = {
		frame = slot,
		iconContainer = iconContainer,
		countLabel = countLabel,
		hoverBorder = hoverBorder
	}

	-- Hover effects
	slot.MouseEnter:Connect(function()
		hoverBorder.Transparency = 0.5
		slot.BackgroundColor3 = CHEST_CONFIG.HOVER_COLOR
	end)

	slot.MouseLeave:Connect(function()
		hoverBorder.Transparency = 1
		slot.BackgroundColor3 = CHEST_CONFIG.SLOT_COLOR
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

function ChestUI:CreateCursorItem()
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.new(0, CHEST_CONFIG.SLOT_SIZE, 0, CHEST_CONFIG.SLOT_SIZE)
	self.cursorFrame.AnchorPoint = Vector2.new(0.5, 0.5)  -- Center on cursor
	self.cursorFrame.BackgroundTransparency = 1
	self.cursorFrame.Visible = false
	self.cursorFrame.ZIndex = 1000
	self.cursorFrame.Parent = self.gui

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = self.cursorFrame

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
	countLabel.ZIndex = 1001
	countLabel.Parent = self.cursorFrame
end

-- === UPDATE DISPLAYS ===

function ChestUI:UpdateChestSlotDisplay(index)
	local slotData = self.chestSlotFrames[index]
	if not slotData then return end

	local stack = self.chestSlots[index]
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	local currentItemId = iconContainer:GetAttribute("CurrentItemId")

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		-- Only update visuals if item type changed
		if currentItemId ~= itemId then
			if isTool then
				local info = ToolConfig.GetToolInfo(itemId)
				local image = iconContainer:FindFirstChild("ToolImage")
				if image and image:IsA("ImageLabel") then
					image.Image = info and info.image or ""
				else
					-- Fallback: rebuild
					for _, child in ipairs(iconContainer:GetChildren()) do
						if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
							child:Destroy()
						end
					end
					local newImage = Instance.new("ImageLabel")
					newImage.Name = "ToolImage"
					newImage.Size = UDim2.new(1, -6, 1, -6)
					newImage.Position = UDim2.new(0.5, 0, 0.5, 0)
					newImage.AnchorPoint = Vector2.new(0.5, 0.5)
					newImage.BackgroundTransparency = 1
					newImage.Image = info and info.image or ""
					newImage.ScaleType = Enum.ScaleType.Fit
					newImage.Parent = iconContainer
				end
			else
				-- Decide between flat image vs 3D block and rebuild on type mismatch
				local blockDef = BlockRegistry.Blocks[itemId]
				local shouldBeFlatImage = false
				if blockDef and blockDef.textures and blockDef.textures.all then
					shouldBeFlatImage = blockDef.craftingMaterial or blockDef.crossShape
				end

				if shouldBeFlatImage then
					-- Ensure ImageLabel exists; rebuild if needed
					for _, child in ipairs(iconContainer:GetChildren()) do
						if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
							child:Destroy()
						end
					end
					BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.new(1, 0, 1, 0))
				else
					-- Try to update existing viewport instead of rebuilding
					local container = iconContainer:FindFirstChild("ViewportContainer")
					local viewport = iconContainer:FindFirstChild("BlockViewport")
					local target = container or viewport
					if target then
						BlockViewportCreator.UpdateBlockViewport(target, itemId)
					else
						for _, child in ipairs(iconContainer:GetChildren()) do
							if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
								child:Destroy()
							end
						end
						BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.new(1, 0, 1, 0))
					end
				end
			end
			iconContainer:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count (cheap operation)
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		iconContainer:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

function ChestUI:UpdateInventorySlotDisplay(index)
	local slotData = self.inventorySlotFrames[index]
	if not slotData then return end

	local stack = self.inventoryManager:GetInventorySlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel
	local currentItemId = iconContainer:GetAttribute("CurrentItemId")

	if stack and not stack:IsEmpty() then
		local itemId = stack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

		-- Only update visuals if item type changed
		if currentItemId ~= itemId then
			if isTool then
				local info = ToolConfig.GetToolInfo(itemId)
				local image = iconContainer:FindFirstChild("ToolImage")
				if image and image:IsA("ImageLabel") then
					image.Image = info and info.image or ""
				else
					for _, child in ipairs(iconContainer:GetChildren()) do
						if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
							child:Destroy()
						end
					end
					local newImage = Instance.new("ImageLabel")
					newImage.Name = "ToolImage"
					newImage.Size = UDim2.new(1, -6, 1, -6)
					newImage.Position = UDim2.new(0.5, 0, 0.5, 0)
					newImage.AnchorPoint = Vector2.new(0.5, 0.5)
					newImage.BackgroundTransparency = 1
					newImage.Image = info and info.image or ""
					newImage.ScaleType = Enum.ScaleType.Fit
					newImage.Parent = iconContainer
				end
			else
				-- Decide between flat image vs 3D block and rebuild on type mismatch
				local blockDef = BlockRegistry.Blocks[itemId]
				local shouldBeFlatImage = false
				if blockDef and blockDef.textures and blockDef.textures.all then
					shouldBeFlatImage = blockDef.craftingMaterial or blockDef.crossShape
				end

				if shouldBeFlatImage then
					-- Ensure ImageLabel exists; rebuild if needed
					for _, child in ipairs(iconContainer:GetChildren()) do
						if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
							child:Destroy()
						end
					end
					BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.new(1, 0, 1, 0))
				else
					local container = iconContainer:FindFirstChild("ViewportContainer")
					local viewport = iconContainer:FindFirstChild("BlockViewport")
					local target = container or viewport
					if target then
						BlockViewportCreator.UpdateBlockViewport(target, itemId)
					else
						for _, child in ipairs(iconContainer:GetChildren()) do
							if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
								child:Destroy()
							end
						end
						BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.new(1, 0, 1, 0))
					end
				end
			end
			iconContainer:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count (cheap operation)
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Slot is empty - clear attribute IMMEDIATELY to prevent race conditions
		iconContainer:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""

		-- Then clear ALL visual children (ViewportContainer, ToolImage, ImageLabel, etc.)
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

-- Smart update - check what actually changed and only update those slots
-- Works for both local actions and remote player updates
function ChestUI:UpdateChangedSlots()
	-- Check chest slots (compare cached vs actual)
	for i = 1, 27 do
		local slotData = self.chestSlotFrames[i]
		if slotData then
			local stack = self.chestSlots[i]
			local cachedItemId = slotData.iconContainer:GetAttribute("CurrentItemId")
			local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

			-- Update if item ID changed OR if visuals/labels are out of sync
			if cachedItemId ~= actualItemId then
				-- Item changed (including nil -> item, item -> nil, or item A -> item B)
				self:UpdateChestSlotDisplay(i)
			elseif actualItemId and stack then
				-- Same item, just update count (cheap operation)
				slotData.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
			end
		end
	end

	-- Check inventory slots (compare cached vs actual)
	for i = 1, 27 do
		local slotData = self.inventorySlotFrames[i]
		if slotData then
			local stack = self.inventoryManager:GetInventorySlot(i)
			local cachedItemId = slotData.iconContainer:GetAttribute("CurrentItemId")
			local actualItemId = stack and not stack:IsEmpty() and stack:GetItemId() or nil

			-- Update if item ID changed OR if visuals/labels are out of sync
			if cachedItemId ~= actualItemId then
				-- Item changed (including nil -> item, item -> nil, or item A -> item B)
				self:UpdateInventorySlotDisplay(i)
			elseif actualItemId and stack then
				-- Same item, just update count (cheap operation)
				slotData.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
			end
		end
	end

	-- Always update cursor
	self:UpdateCursorDisplay()
end

-- Legacy function for full refresh (used on open)
function ChestUI:UpdateAllDisplays()
	-- Update chest slots
	for i = 1, 27 do
		self:UpdateChestSlotDisplay(i)
	end

	-- Update inventory slots
	for i = 1, 27 do
		self:UpdateInventorySlotDisplay(i)
	end

	-- Update cursor
	self:UpdateCursorDisplay()

	-- Note: Hotbar remains visible at bottom of screen (managed by VoxelHotbar)
end

function ChestUI:UpdateCursorDisplay()
	if not self.cursorFrame then return end

	local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
	local countLabel = self.cursorFrame:FindFirstChild("CountLabel")
	if not iconContainer or not countLabel then return end

	local currentItemId = self.cursorFrame:GetAttribute("CurrentItemId")

	if self.cursorStack and not self.cursorStack:IsEmpty() then
		local itemId = self.cursorStack:GetItemId()
		local isTool = ToolConfig.IsTool(itemId)

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
				BlockViewportCreator.CreateBlockViewport(iconContainer, itemId, UDim2.new(1, 0, 1, 0))
			end

			-- Set new item ID AFTER creating visuals
			self.cursorFrame:SetAttribute("CurrentItemId", itemId)
		end

		-- Always update count (cheap operation)
		countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		self.cursorFrame.Visible = true
	else
		-- Clear attribute IMMEDIATELY to prevent race conditions
		self.cursorFrame:SetAttribute("CurrentItemId", nil)
		countLabel.Text = ""
		self.cursorFrame.Visible = false

		-- Clear ALL visuals
		for _, child in ipairs(iconContainer:GetChildren()) do
			if not child:IsA("UILayout") and not child:IsA("UIPadding") and not child:IsA("UICorner") then
				child:Destroy()
			end
		end
	end
end

-- === CLICK HANDLERS ===

-- Local helper: simulate Minecraft-style click on a slot
function ChestUI:_simulateSlotClick(slotStack, cursorStack, clickType)
	-- Work on clones to avoid mutating originals before applying
	local slot = (slotStack and slotStack:Clone()) or ItemStack.new(0, 0)
	local cursor = (cursorStack and cursorStack:Clone()) or ItemStack.new(0, 0)

	if clickType == "left" then
		if cursor:IsEmpty() then
			-- Pick up entire stack
			if not slot:IsEmpty() then
				cursor = slot:Clone()
				slot = ItemStack.new(0, 0)
			end
		else
			-- Place entire stack / merge / swap
			if slot:IsEmpty() then
				slot = cursor:Clone()
				cursor = ItemStack.new(0, 0)
			elseif cursor:CanStack(slot) then
				-- Merge as much as possible
				slot:Merge(cursor)
				if cursor:IsEmpty() then
					cursor = ItemStack.new(0, 0)
				end
			else
				-- Swap stacks
				local temp = slot:Clone()
				slot = cursor:Clone()
				cursor = temp
			end
		end
	elseif clickType == "right" then
		if cursor:IsEmpty() then
			-- Pick up half (round up)
			if not slot:IsEmpty() then
				cursor = slot:SplitHalf()
			end
		else
			-- Place one / add one to stack
			if slot:IsEmpty() then
				local oneItem = cursor:TakeOne()
				slot = oneItem
			elseif cursor:CanStack(slot) and not slot:IsFull() then
				slot:AddCount(1)
				cursor:RemoveCount(1)
			end
		end
	end

	return slot, cursor
end

function ChestUI:OnChestSlotLeftClick(index)
	-- Predictive visual update for instant feedback
	local currentSlot = self.chestSlots[index]
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "left")

	-- Apply visuals immediately
	self.chestSlots[index] = newSlot
	self:UpdateChestSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "left"
	})
end

function ChestUI:OnChestSlotRightClick(index)
	-- Predictive visual update for instant feedback
	local currentSlot = self.chestSlots[index]
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "right")

	-- Apply visuals immediately
	self.chestSlots[index] = newSlot
	self:UpdateChestSlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "right"
	})
end

function ChestUI:OnInventorySlotLeftClick(index)
	-- Predictive visual update for instant feedback (player inventory slot)
	local currentSlot = self.inventoryManager:GetInventorySlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "left")

	-- Apply visuals immediately to player's inventory
	self.inventoryManager:SetInventorySlot(index, newSlot)
	self:UpdateInventorySlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = false,
		clickType = "left"
	})
end

function ChestUI:OnInventorySlotRightClick(index)
	-- Predictive visual update for instant feedback (player inventory slot)
	local currentSlot = self.inventoryManager:GetInventorySlot(index)
	local newSlot, newCursor = self:_simulateSlotClick(currentSlot, self.cursorStack, "right")

	-- Apply visuals immediately to player's inventory
	self.inventoryManager:SetInventorySlot(index, newSlot)
	self:UpdateInventorySlotDisplay(index)
	self.cursorStack = newCursor
	self:UpdateCursorDisplay()

	-- Send authoritative click to server
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = false,
		clickType = "right"
	})
end

-- === NETWORK SYNC ===

-- Send atomic transaction (chest + inventory + cursor together)
function ChestUI:SendTransaction()
	if not self.chestPosition then return end

	-- Serialize chest contents
	local chestContents = {}
	for i = 1, 27 do
		chestContents[i] = self.chestSlots[i]:Serialize()
	end

	-- Serialize player inventory
	local playerInventory = {}
	for i = 1, 27 do
		local stack = self.inventoryManager:GetInventorySlot(i)
		if stack and not stack:IsEmpty() then
			playerInventory[i] = stack:Serialize()
		end
	end

	-- Include cursor items in transaction (important for validation!)
	local cursorItem = nil
	if not self.cursorStack:IsEmpty() then
		cursorItem = self.cursorStack:Serialize()
	end

	-- Send SINGLE atomic transaction with all three states
	EventManager:SendToServer("ChestContentsUpdate", {
		x = self.chestPosition.x,
		y = self.chestPosition.y,
		z = self.chestPosition.z,
		contents = chestContents,
		playerInventory = playerInventory,
		cursorItem = cursorItem  -- Include cursor for proper validation
	})
end

-- Deprecated - kept for compatibility
function ChestUI:SendChestUpdate()
	self:SendTransaction()
end

function ChestUI:SendInventoryUpdate()
	self:SendTransaction()
end

-- === LIFECYCLE ===

function ChestUI:Open(chestPos, chestContents, playerInventory)
	if not self.gui then
		warn("ChestUI:Open - self.gui is nil! ChestUI not properly initialized!")
		return
	end

	if not self.panel then
		warn("ChestUI:Open - self.panel is nil! Panel not created!")
		return
	end

	self.isOpen = true
	self.chestPosition = chestPos

	-- Close inventory panel if open (mutual exclusion)
	if self.inventoryPanel and self.inventoryPanel.isOpen then
		self.inventoryPanel:Close()
	end

	-- First, initialize all slots as empty
	for i = 1, 27 do
		self.chestSlots[i] = ItemStack.new(0, 0)
	end

	-- Then apply chest contents from server (now a dense array of all 27 slots)
	if chestContents then
		for i = 1, 27 do
			if chestContents[i] then
				local deserialized = ItemStack.Deserialize(chestContents[i])
				self.chestSlots[i] = deserialized or ItemStack.new(0, 0)
			else
				self.chestSlots[i] = ItemStack.new(0, 0)
			end
		end
	end

	-- Update all displays
	self:UpdateAllDisplays()

	-- Show UI
	self.gui.Enabled = true
	GameState:Set("voxelWorld.inventoryOpen", true)

	-- Unlock mouse - force it!
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	-- Force mouse visible again on next frame (in case something overrides it)
	task.defer(function()
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end)

	-- Start render connection for cursor tracking and keep mouse unlocked
	self.renderConnection = RunService.RenderStepped:Connect(function()
		-- Keep forcing mouse to be visible and unlocked while chest is open
		if self.isOpen then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		end
		self:UpdateCursorPosition()
	end)
end

function ChestUI:Close()
	if not self.isOpen then return end

	self.isOpen = false

	-- Drop cursor item back to inventory/chest
	if not self.cursorStack:IsEmpty() then
		-- Try to return to first empty inventory slot
		local placed = false
		for i = 1, 27 do
			if self.inventoryManager:GetInventorySlot(i):IsEmpty() then
				self.inventoryManager:SetInventorySlot(i, self.cursorStack:Clone())
				placed = true
				break
			end
		end
		if not placed then
			-- Try chest
			for i = 1, 27 do
				if self.chestSlots[i]:IsEmpty() then
					self.chestSlots[i] = self.cursorStack:Clone()
					placed = true
					break
				end
			end
		end
		self.cursorStack = ItemStack.new(0, 0)
		self:UpdateCursorDisplay()

		-- Sync changes to server
		if placed then
			self.inventoryManager:SendUpdateToServer()
		end
	end

	-- Notify server of closure
	if self.chestPosition then
		EventManager:SendToServer("RequestCloseChest", {
			x = self.chestPosition.x,
			y = self.chestPosition.y,
			z = self.chestPosition.z
		})
		self.chestPosition = nil
	end

	-- Stop render connection first
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Hide UI
	self.gui.Enabled = false
	GameState:Set("voxelWorld.inventoryOpen", false)

	-- Note: CameraController now manages mouse lock dynamically based on camera mode
	-- (first person = locked, third person = free)
end

function ChestUI:UpdateCursorPosition()
	if not self.cursorFrame or not self.cursorFrame.Visible then return end

	local mousePos = UserInputService:GetMouseLocation()
	local guiInset = GuiService:GetGuiInset()

	-- Adjust for GUI insets (top bar, etc.)
	self.cursorFrame.Position = UDim2.new(0, mousePos.X, 0, mousePos.Y - guiInset.Y)
end

function ChestUI:BindInput()
	table.insert(self.connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E then
			if self.isOpen then
				self:Close()
			end
		end
	end))
end

function ChestUI:RegisterEvents()
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestOpened", function(data)
		if not data then
			warn("ChestUI: ChestOpened event data is nil!")
			return
		end
		self:Open(
			{x = data.x, y = data.y, z = data.z},
			data.contents or {},
			data.playerInventory or {}
		)
	end)

	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestClosed", function(data)
		if self.chestPosition and
		   self.chestPosition.x == data.x and
		   self.chestPosition.y == data.y and
		   self.chestPosition.z == data.z then
			self:Close()
		end
	end)

	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestUpdated", function(data)
		if not self.isOpen then return end
		if not self.chestPosition then return end
		if self.chestPosition.x ~= data.x or self.chestPosition.y ~= data.y or self.chestPosition.z ~= data.z then
			return
		end

		-- Targeted update: compute changes and only redraw changed indices
		if data.contents then
			for i = 1, 27 do
				local incoming = data.contents[i]
				local old = self.chestSlots[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				local oldId = old and not old:IsEmpty() and old:GetItemId() or 0
				local oldCount = old and old:GetCount() or 0
				local newId = not newStack:IsEmpty() and newStack:GetItemId() or 0
				local newCount = newStack:GetCount()
				if oldId ~= newId or oldCount ~= newCount then
					self.chestSlots[i] = newStack
					self:UpdateChestSlotDisplay(i)
				else
					self.chestSlots[i] = newStack
				end
			end
		end

		-- Player inventory is managed by inventoryManager (dense array from server)
		if data.playerInventory then
			self.inventoryManager._syncingFromServer = true
			for i = 1, 27 do
				local incoming = data.playerInventory[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				local old = self.inventoryManager:GetInventorySlot(i)
				local oldId = old and not old:IsEmpty() and old:GetItemId() or 0
				local oldCount = old and old:GetCount() or 0
				local newId = not newStack:IsEmpty() and newStack:GetItemId() or 0
				local newCount = newStack:GetCount()
				if oldId ~= newId or oldCount ~= newCount then
					self.inventoryManager:SetInventorySlot(i, newStack)
					self:UpdateInventorySlotDisplay(i)
				else
					self.inventoryManager:SetInventorySlot(i, newStack)
				end
			end
			self.inventoryManager._syncingFromServer = false
		end
	end)

	-- NEW SYSTEM: Handle server-authoritative click results (now delta-based)
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestActionResult", function(data)
		if not self.isOpen then return end
		if not self.chestPosition then return end
		if not data.chestPosition or
		   self.chestPosition.x ~= data.chestPosition.x or
		   self.chestPosition.y ~= data.chestPosition.y or
		   self.chestPosition.z ~= data.chestPosition.z then
			return
		end

		-- Apply authoritative chest deltas (preferred)
		if data.chestDelta then
			for k, stackData in pairs(data.chestDelta) do
				local i = tonumber(k) or k
				if type(i) == "number" and i >= 1 and i <= 27 then
					local newStack = stackData and ItemStack.Deserialize(stackData) or ItemStack.new(0, 0)
					self.chestSlots[i] = newStack
					self:UpdateChestSlotDisplay(i)
				end
			end
		elseif data.chestContents then
			-- Backward compatibility: dense array
			for i = 1, 27 do
				local incoming = data.chestContents[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				self.chestSlots[i] = newStack
				self:UpdateChestSlotDisplay(i)
			end
		end

		-- Apply authoritative player inventory deltas (preferred)
		if data.inventoryDelta then
			self.inventoryManager._syncingFromServer = true
			for k, stackData in pairs(data.inventoryDelta) do
				local i = tonumber(k) or k
				if type(i) == "number" and i >= 1 and i <= 27 then
					local newStack = stackData and ItemStack.Deserialize(stackData) or ItemStack.new(0, 0)
					self.inventoryManager:SetInventorySlot(i, newStack)
					self:UpdateInventorySlotDisplay(i)
				end
			end
			self.inventoryManager._syncingFromServer = false
		elseif data.playerInventory then
			-- Backward compatibility: dense array
			self.inventoryManager._syncingFromServer = true
			for i = 1, 27 do
				local incoming = data.playerInventory[i]
				local newStack = incoming and ItemStack.Deserialize(incoming) or ItemStack.new(0, 0)
				self.inventoryManager:SetInventorySlot(i, newStack)
				self:UpdateInventorySlotDisplay(i)
			end
			self.inventoryManager._syncingFromServer = false
		end

		-- Apply authoritative cursor from server
		if data.cursorItem then
			self.cursorStack = ItemStack.Deserialize(data.cursorItem)
		else
			self.cursorStack = ItemStack.new(0, 0)
		end
		self:UpdateCursorDisplay()
	end)
end

function ChestUI:Cleanup()
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

return ChestUI
