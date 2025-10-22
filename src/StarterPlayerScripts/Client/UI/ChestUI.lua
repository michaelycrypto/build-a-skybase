--[[
	ChestUI.lua
	Minecraft-style chest interface with drag-and-drop
	Shows chest inventory (27 slots) + player inventory (27 slots)
	Note: Hotbar remains visible at bottom of screen (not included in chest UI)
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

	-- Clear old viewport
	for _, child in ipairs(iconContainer:GetChildren()) do
		child:Destroy()
	end

	if stack and not stack:IsEmpty() then
		BlockViewportCreator.CreateBlockViewport(iconContainer, stack:GetItemId(), UDim2.new(1, 0, 1, 0))
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		countLabel.Text = ""
	end
end

function ChestUI:UpdateInventorySlotDisplay(index)
	local slotData = self.inventorySlotFrames[index]
	if not slotData then return end

	local stack = self.inventoryManager:GetInventorySlot(index)
	local iconContainer = slotData.iconContainer
	local countLabel = slotData.countLabel

	-- Clear old viewport
	for _, child in ipairs(iconContainer:GetChildren()) do
		child:Destroy()
	end

	if stack and not stack:IsEmpty() then
		BlockViewportCreator.CreateBlockViewport(iconContainer, stack:GetItemId(), UDim2.new(1, 0, 1, 0))
		countLabel.Text = stack:GetCount() > 1 and tostring(stack:GetCount()) or ""
	else
		countLabel.Text = ""
	end
end

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

	-- Clear old viewport
	for _, child in ipairs(iconContainer:GetChildren()) do
		child:Destroy()
	end

	if self.cursorStack and not self.cursorStack:IsEmpty() then
		BlockViewportCreator.CreateBlockViewport(iconContainer, self.cursorStack:GetItemId(), UDim2.new(1, 0, 1, 0))
		countLabel.Text = self.cursorStack:GetCount() > 1 and tostring(self.cursorStack:GetCount()) or ""
		self.cursorFrame.Visible = true
	else
		self.cursorFrame.Visible = false
		countLabel.Text = ""
	end
end

-- === CLICK HANDLERS ===

function ChestUI:OnChestSlotLeftClick(index)
	-- NEW SYSTEM: Send click event to server, don't update local state
	-- Server will validate and send back authoritative state
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "left"
	})
end

function ChestUI:OnChestSlotRightClick(index)
	-- NEW SYSTEM: Send click event to server, don't update local state
	-- Server will validate and send back authoritative state
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = true,
		clickType = "right"
	})
end

function ChestUI:OnInventorySlotLeftClick(index)
	-- NEW SYSTEM: Send click event to server, don't update local state
	-- Server will validate and send back authoritative state
	EventManager:SendToServer("ChestSlotClick", {
		chestPosition = self.chestPosition,
		slotIndex = index,
		isChestSlot = false,
		clickType = "left"
	})
end

function ChestUI:OnInventorySlotRightClick(index)
	-- NEW SYSTEM: Send click event to server, don't update local state
	-- Server will validate and send back authoritative state
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
	print("📦 ChestUI:Open called!")
	print("  - chestPos:", chestPos)
	print("  - self.gui exists:", self.gui ~= nil)
	print("  - self.panel exists:", self.panel ~= nil)

	if not self.gui then
		warn("ChestUI:Open - self.gui is nil! ChestUI not properly initialized!")
		return
	end

	if not self.panel then
		warn("ChestUI:Open - self.panel is nil! Panel not created!")
		return
	end

	print("  - Setting isOpen to true...")
	self.isOpen = true
	self.chestPosition = chestPos

	-- Close inventory panel if open (mutual exclusion)
	if self.inventoryPanel and self.inventoryPanel.isOpen then
		print("  - Closing inventory panel...")
		self.inventoryPanel:Close()
	end

	-- Load chest contents
	print(string.format("  - chestContents type: %s", type(chestContents)))

	-- First, initialize all slots as empty
	for i = 1, 27 do
		self.chestSlots[i] = ItemStack.new(0, 0)
	end

	-- Then apply chest contents from server (now a dense array of all 27 slots)
	if chestContents then
		local chestItemCount = 0
		for i = 1, 27 do
			if chestContents[i] then
				local deserialized = ItemStack.Deserialize(chestContents[i])
				if deserialized and not deserialized:IsEmpty() then
					chestItemCount = chestItemCount + 1
					print(string.format("  - Loading chest slot %d: itemId=%d, count=%d",
						i, deserialized:GetItemId(), deserialized:GetCount()))
				end
				self.chestSlots[i] = deserialized or ItemStack.new(0, 0)
			else
				self.chestSlots[i] = ItemStack.new(0, 0)
			end
		end
		print(string.format("  - Loaded %d chest items from server", chestItemCount))
	else
		print("  - No chest contents provided by server (chestContents is nil)")
	end

	-- Load player inventory from manager (already synced from server)
	print("  - Using inventory from ClientInventoryManager...")
	local count = 0
	for i = 1, 27 do
		local stack = self.inventoryManager:GetInventorySlot(i)
		if stack:GetItemId() > 0 then
			count = count + 1
			print(string.format("    Slot %d: Item %d x%d", i, stack:GetItemId(), stack:GetCount()))
		end
	end
	print(string.format("  - Found %d inventory items", count))

	-- Update all displays
	print("  - Updating all displays...")
	self:UpdateAllDisplays()

	-- Show UI
	print("  - Enabling GUI (self.gui.Enabled = true)...")
	self.gui.Enabled = true
	print("  - GUI enabled! Visible:", self.gui.Enabled)
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

	print(string.format("✅ ChestUI: Successfully opened chest at (%d, %d, %d)", chestPos.x, chestPos.y, chestPos.z))
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

	-- Re-lock mouse when closing UI
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false

	print("ChestUI: Closed")
end

function ChestUI:UpdateCursorPosition()
	if not self.cursorFrame or not self.cursorFrame.Visible then return end

	local mousePos = UserInputService:GetMouseLocation()
	self.cursorFrame.Position = UDim2.new(0, mousePos.X - CHEST_CONFIG.SLOT_SIZE/2, 0, mousePos.Y - CHEST_CONFIG.SLOT_SIZE/2)
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
	print("ChestUI: Registering events...")
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestOpened", function(data)
		print("🎉 ChestUI: Received ChestOpened event!", data)
		if not data then
			warn("ChestUI: ChestOpened event data is nil!")
			return
		end
		print(string.format("ChestUI: Opening chest at (%d, %d, %d)", data.x, data.y, data.z))
		self:Open(
			{x = data.x, y = data.y, z = data.z},
			data.contents or {},
			data.playerInventory or {}
		)
	end)
	print("ChestUI: ChestOpened event registered")

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

		-- Update chest contents (now dense array from server)
		if data.contents then
			for i = 1, 27 do
				if data.contents[i] then
					local deserialized = ItemStack.Deserialize(data.contents[i])
					self.chestSlots[i] = deserialized or ItemStack.new(0, 0)
				else
					self.chestSlots[i] = ItemStack.new(0, 0)
				end
				self:UpdateChestSlotDisplay(i)
			end
		end

		-- Player inventory is managed by inventoryManager (now dense array from server)
		if data.playerInventory then
			self.inventoryManager._syncingFromServer = true

			for i = 1, 27 do
				if data.playerInventory[i] then
					local deserialized = ItemStack.Deserialize(data.playerInventory[i])
					self.inventoryManager:SetInventorySlot(i, deserialized or ItemStack.new(0, 0))
				else
					self.inventoryManager:SetInventorySlot(i, ItemStack.new(0, 0))
				end
				self:UpdateInventorySlotDisplay(i)
			end

			self.inventoryManager._syncingFromServer = false
		end
	end)

	-- NEW SYSTEM: Handle server-authoritative click results
	self.connections[#self.connections + 1] = EventManager:RegisterEvent("ChestActionResult", function(data)
		if not self.isOpen then return end
		if not self.chestPosition then return end
		if not data.chestPosition or
		   self.chestPosition.x ~= data.chestPosition.x or
		   self.chestPosition.y ~= data.chestPosition.y or
		   self.chestPosition.z ~= data.chestPosition.z then
			return
		end

		print("[ChestUI] Received ChestActionResult")
		print(string.format("[ChestUI] Cursor item: %s", data.cursorItem and "has item" or "empty"))
		print(string.format("[ChestUI] chestContents type: %s", type(data.chestContents)))

		if data.chestContents then
			-- Debug: print what slots have data
			for k, v in pairs(data.chestContents) do
				print(string.format("[ChestUI] chestContents[%s] = %s (itemId=%s, count=%s)",
					tostring(k), tostring(v), tostring(v.itemId), tostring(v.count)))
			end
		end

		-- Apply authoritative chest contents from server
		-- Server now sends dense array (all 27 slots)
		if data.chestContents then
			local itemCount = 0

			-- Apply all 27 slots from server (now a dense array)
			for i = 1, 27 do
				if data.chestContents[i] then
					local deserialized = ItemStack.Deserialize(data.chestContents[i])
					self.chestSlots[i] = deserialized or ItemStack.new(0, 0)
					if not deserialized:IsEmpty() then
						itemCount = itemCount + 1
						print(string.format("[ChestUI] Chest slot %d: Item %d x%d",
							i, deserialized:GetItemId(), deserialized:GetCount()))
					end
				else
					self.chestSlots[i] = ItemStack.new(0, 0)
				end
				self:UpdateChestSlotDisplay(i)
			end

			print(string.format("[ChestUI] Applied %d chest items", itemCount))
		end

		-- Apply authoritative inventory from server
		-- Server now sends dense array (all 27 slots)
		if data.playerInventory then
			self.inventoryManager._syncingFromServer = true

			-- Apply all 27 slots from server (now a dense array)
			for i = 1, 27 do
				if data.playerInventory[i] then
					local deserialized = ItemStack.Deserialize(data.playerInventory[i])
					self.inventoryManager:SetInventorySlot(i, deserialized or ItemStack.new(0, 0))
				else
					self.inventoryManager:SetInventorySlot(i, ItemStack.new(0, 0))
				end
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

	print("ChestUI: Cleaned up")
end

return ChestUI
