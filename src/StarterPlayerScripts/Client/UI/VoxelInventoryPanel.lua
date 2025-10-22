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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local VoxelInventoryPanel = {}
VoxelInventoryPanel.__index = VoxelInventoryPanel

-- Inventory configuration
local INVENTORY_CONFIG = {
	COLUMNS = 9,
	ROWS = 3, -- 3 rows of storage (27 slots) + 9 hotbar slots = 36 total
	SLOT_SIZE = 52,
	SLOT_SPACING = 4,
	PADDING = 20,
	SECTION_SPACING = 20, -- Space between inventory and hotbar sections

	-- Colors
	BG_COLOR = Color3.fromRGB(35, 35, 35),
	SLOT_COLOR = Color3.fromRGB(45, 45, 45),
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
	HOVER_COLOR = Color3.fromRGB(80, 80, 80),
}

function VoxelInventoryPanel.new(inventoryManager)
	local self = setmetatable({}, VoxelInventoryPanel)

	-- Use centralized inventory manager
	self.inventoryManager = inventoryManager
	self.hotbar = inventoryManager.hotbar

	self.isOpen = false
	self.gui = nil
	self.panel = nil

	-- UI slot frames
	self.inventorySlotFrames = {}

	-- Cursor/drag state (Minecraft-style)
	self.cursorStack = ItemStack.new(0, 0) -- Item attached to cursor
	self.cursorFrame = nil

	self.connections = {}
	self.renderConnection = nil

	return self
end

function VoxelInventoryPanel:Initialize()
	-- Create ScreenGui
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "VoxelInventory"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 100
	self.gui.IgnoreGuiInset = true
	self.gui.Enabled = false
	self.gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

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
	local totalHeight = storageHeight + INVENTORY_CONFIG.SECTION_SPACING + hotbarHeight +
	                    INVENTORY_CONFIG.PADDING * 2 + 50

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
	self.panel.Name = "InventoryPanel"
	self.panel.Size = UDim2.new(0, slotWidth + INVENTORY_CONFIG.PADDING * 2, 0, totalHeight)
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

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -40, 0, 40)
	title.Position = UDim2.new(0, 20, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "Inventory"
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

	-- Inventory section label
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
	for row = 0, INVENTORY_CONFIG.ROWS - 1 do
		for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
			local index = row * INVENTORY_CONFIG.COLUMNS + col + 1
			local x = INVENTORY_CONFIG.PADDING + col * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
			local y = yOffset + row * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
			self:CreateInventorySlot(index, x, y)
		end
	end

	yOffset = yOffset + storageHeight + INVENTORY_CONFIG.SECTION_SPACING

	-- Hotbar section label
	local hotbarLabel = Instance.new("TextLabel")
	hotbarLabel.Size = UDim2.new(1, -40, 0, 20)
	hotbarLabel.Position = UDim2.new(0, 20, 0, yOffset)
	hotbarLabel.BackgroundTransparency = 1
	hotbarLabel.Font = Enum.Font.Gotham
	hotbarLabel.TextSize = 14
	hotbarLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	hotbarLabel.Text = "Hotbar"
	hotbarLabel.TextXAlignment = Enum.TextXAlignment.Left
	hotbarLabel.Parent = self.panel

	yOffset = yOffset + 25

	-- Hotbar slots (reference only, actual data in hotbar)
	for col = 0, INVENTORY_CONFIG.COLUMNS - 1 do
		local x = INVENTORY_CONFIG.PADDING + col * (INVENTORY_CONFIG.SLOT_SIZE + INVENTORY_CONFIG.SLOT_SPACING)
		self:CreateHotbarSlot(col + 1, x, yOffset)
	end

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

function VoxelInventoryPanel:CreateCursorItem()
	-- Item that follows cursor when dragging
	self.cursorFrame = Instance.new("Frame")
	self.cursorFrame.Name = "CursorItem"
	self.cursorFrame.Size = UDim2.new(0, INVENTORY_CONFIG.SLOT_SIZE, 0, INVENTORY_CONFIG.SLOT_SIZE)
	self.cursorFrame.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	self.cursorFrame.BackgroundTransparency = 0.2
	self.cursorFrame.BorderSizePixel = 0
	self.cursorFrame.Visible = false
	self.cursorFrame.ZIndex = 1000
	self.cursorFrame.Parent = self.gui

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
	if stack and not stack:IsEmpty() then
		-- Get or create viewport container
		local viewportContainer = slotFrame.iconContainer:FindFirstChild("ViewportContainer")
		if viewportContainer then
			-- Update existing viewport
			BlockViewportCreator.UpdateBlockViewport(viewportContainer, stack:GetItemId())
		else
			-- Create new viewport
			BlockViewportCreator.CreateBlockViewport(
				slotFrame.iconContainer,
				stack:GetItemId(),
				UDim2.new(1, 0, 1, 0)
			)
		end
		slotFrame.countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Clear viewport container
		local viewportContainer = slotFrame.iconContainer:FindFirstChild("ViewportContainer")
		if viewportContainer then
			viewportContainer:Destroy()
		end
		slotFrame.countLabel.Text = ""
	end
end

function VoxelInventoryPanel:UpdateHotbarSlotDisplay(index, slot, iconContainer, countLabel, selectionBorder)
	if not self.hotbar then return end

	local stack = self.hotbar:GetSlot(index)
	if stack and not stack:IsEmpty() then
		-- Get or create viewport container
		local viewportContainer = iconContainer:FindFirstChild("ViewportContainer")
		if viewportContainer then
			-- Update existing viewport
			BlockViewportCreator.UpdateBlockViewport(viewportContainer, stack:GetItemId())
		else
			-- Create new viewport
			BlockViewportCreator.CreateBlockViewport(
				iconContainer,
				stack:GetItemId(),
				UDim2.new(1, 0, 1, 0)
			)
		end
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		-- Clear viewport container
		local viewportContainer = iconContainer:FindFirstChild("ViewportContainer")
		if viewportContainer then
			viewportContainer:Destroy()
		end
		countLabel.Text = ""
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

function VoxelInventoryPanel:UpdateCursorDisplay()
	if self.cursorStack:IsEmpty() then
		self.cursorFrame.Visible = false
	else
		self.cursorFrame.Visible = true
		local iconContainer = self.cursorFrame:FindFirstChild("IconContainer")
		local countLabel = self.cursorFrame:FindFirstChild("CountLabel")

		if iconContainer then
			-- Get or create viewport container
			local viewportContainer = iconContainer:FindFirstChild("ViewportContainer")
			if viewportContainer then
				-- Update existing viewport
				BlockViewportCreator.UpdateBlockViewport(viewportContainer, self.cursorStack:GetItemId())
			else
				-- Create new viewport
				BlockViewportCreator.CreateBlockViewport(
					iconContainer,
					self.cursorStack:GetItemId(),
					UDim2.new(1, 0, 1, 0)
				)
			end
		end
		if countLabel then
			countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		end
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
			local added = slotStack:Merge(self.cursorStack)
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

	self:UpdateAllDisplays()
	self.inventoryManager:SendUpdateToServer()
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

	self:UpdateAllDisplays()
	self.inventoryManager:SendUpdateToServer()
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
			local added = slotStack:Merge(self.cursorStack)
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

	self:UpdateAllDisplays()
	self.inventoryManager:SendUpdateToServer()
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

	self:UpdateAllDisplays()
	self.inventoryManager:SendUpdateToServer()
end

-- Send inventory update to server (deprecated - use inventoryManager)
function VoxelInventoryPanel:SendInventoryUpdateToServer()
	-- Delegate to inventory manager
	self.inventoryManager:SendUpdateToServer()
end

function VoxelInventoryPanel:UpdateCursorPosition()
	if not self.cursorFrame.Visible then return end

	local mouse = Players.LocalPlayer:GetMouse()
	self.cursorFrame.Position = UDim2.new(0, mouse.X - INVENTORY_CONFIG.SLOT_SIZE/2, 0, mouse.Y - INVENTORY_CONFIG.SLOT_SIZE/2)
end

function VoxelInventoryPanel:BindInput()
	-- E key to toggle
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end

		if input.KeyCode == Enum.KeyCode.E then
			self:Toggle()
		elseif input.KeyCode == Enum.KeyCode.Escape and self.isOpen then
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
			-- Drop/delete item (Minecraft drops it as entity, but we'll just delete for now)
			print("Dropped:", self.hotbar:GetBlockInfo(self.cursorStack:GetItemId()).name, "x" .. self.cursorStack:GetCount())
			self.cursorStack = ItemStack.new(0, 0)
			self:UpdateCursorDisplay()
		end
	end)
end

function VoxelInventoryPanel:Open()
	if self.isOpen then return end

	self.isOpen = true
	self.gui.Enabled = true

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
			print("Inventory full! Dropped:", self.hotbar:GetBlockInfo(self.cursorStack:GetItemId()).name)
		end

		self.cursorStack = ItemStack.new(0, 0)
		self:UpdateCursorDisplay()

		-- Sync to server
		self.inventoryManager:SendUpdateToServer()
	end

	self.isOpen = false

	-- Stop updating cursor
	if self.renderConnection then
		self.renderConnection:Disconnect()
		self.renderConnection = nil
	end

	-- Signal to character controller to resume mouse locking
	GameState:Set("voxelWorld.inventoryOpen", false)

	-- Re-lock mouse when closing UI
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	-- Animate out
	local tween = TweenService:Create(self.panel, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.5, 0, 0.5, 30)
	})
	tween:Play()
	tween.Completed:Connect(function()
		self.gui.Enabled = false
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
