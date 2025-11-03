--[[
	VoxelHotbar.lua
	Minecraft-style hotbar for block/item selection
	9-slot toolbar at bottom of screen with number key selection
	Supports stacking (64 max) and drag-and-drop
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameState = require(script.Parent.Parent.Managers.GameState)
local ItemStack = require(ReplicatedStorage.Shared.VoxelWorld.Inventory.ItemStack)
local BlockViewportCreator = require(ReplicatedStorage.Shared.VoxelWorld.Rendering.BlockViewportCreator)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local ToolConfig = require(ReplicatedStorage.Configs.ToolConfig)

local VoxelHotbar = {}
VoxelHotbar.__index = VoxelHotbar

-- Hotbar configuration
local HOTBAR_CONFIG = {
	SLOT_COUNT = 9,
	SLOT_SIZE = 58,
	SLOT_SPACING = 4,
		BOTTOM_OFFSET = 20,
	BORDER_WIDTH = 3,
		SCALE = 1.1,

	-- Colors (Minecraft-inspired)
	BG_COLOR = Color3.fromRGB(40, 40, 40),
	BG_TRANSPARENCY = 0.3,
	BORDER_COLOR = Color3.fromRGB(60, 60, 60),
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
}

function VoxelHotbar.new()
	local self = setmetatable({}, VoxelHotbar)

	self.selectedSlot = 1
	self.slots = {} -- Array of ItemStack objects
	self.slotFrames = {} -- UI frames for each slot
	self.gui = nil
	self.container = nil
	self.connections = {}

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
	print("📐 VoxelHotbar: Added UIScale with base resolution 1920x1080 (100% original size)")

	-- Create main hotbar container
	self:CreateHotbar()

	-- Bind input
	self:BindInput()

	-- Set initial selection and populate with starter blocks
	self:SetupStarterBlocks()
	self:SelectSlot(1)

	return self
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
end

function VoxelHotbar:CreateHotbar()
	local totalWidth = (HOTBAR_CONFIG.SLOT_SIZE * HOTBAR_CONFIG.SLOT_COUNT) +
	                   (HOTBAR_CONFIG.SLOT_SPACING * (HOTBAR_CONFIG.SLOT_COUNT - 1))

	-- Container frame
	self.container = Instance.new("Frame")
	self.container.Name = "HotbarContainer"
	self.container.Size = UDim2.new(0, totalWidth + 16, 0, HOTBAR_CONFIG.SLOT_SIZE + 16)
	self.container.Position = UDim2.new(0.5, 0, 1, -math.floor(HOTBAR_CONFIG.BOTTOM_OFFSET / (HOTBAR_CONFIG.SCALE or 1) + 0.5))
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.BackgroundColor3 = HOTBAR_CONFIG.BG_COLOR
	self.container.BackgroundTransparency = HOTBAR_CONFIG.BG_TRANSPARENCY
	self.container.BorderSizePixel = 0
	self.container.Parent = self.gui

	-- Local scale only for hotbar (multiplies on top of global UIScaler)
	local localScale = Instance.new("UIScale")
	localScale.Name = "LocalScale"
	localScale.Scale = HOTBAR_CONFIG.SCALE
	localScale.Parent = self.container

	-- Rounded corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = self.container

	-- Border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = HOTBAR_CONFIG.BORDER_COLOR
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = self.container

	-- Create slots
	for i = 1, HOTBAR_CONFIG.SLOT_COUNT do
		self:CreateSlotUI(i)
	end
end

function VoxelHotbar:CreateSlotUI(index)
	local xPos = 8 + ((index - 1) * (HOTBAR_CONFIG.SLOT_SIZE + HOTBAR_CONFIG.SLOT_SPACING))

	-- Slot frame
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.Size = UDim2.new(0, HOTBAR_CONFIG.SLOT_SIZE, 0, HOTBAR_CONFIG.SLOT_SIZE)
	slot.Position = UDim2.new(0, xPos, 0, 8)
	slot.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	slot.BackgroundTransparency = 0.2
	slot.BorderSizePixel = 0
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.Parent = self.container

	-- Slot corner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = slot

	-- Selection border (bright and prominent like Minecraft)
	local border = Instance.new("UIStroke")
	border.Name = "SelectionBorder"
	border.Color = Color3.fromRGB(255, 255, 255) -- Pure white
	border.Thickness = 4 -- Thicker for better visibility
	border.Transparency = 1
	border.Parent = slot

	-- Inner glow effect when selected
	local innerGlow = Instance.new("UIStroke")
	innerGlow.Name = "InnerGlow"
	innerGlow.Color = Color3.fromRGB(255, 255, 255)
	innerGlow.Thickness = 1
	innerGlow.Transparency = 1
	innerGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	innerGlow.Parent = slot

	-- Create container for viewport - fills entire slot
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(1, 0, 1, 0)
	iconContainer.Position = UDim2.new(0, 0, 0, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.ZIndex = 2
	iconContainer.Parent = slot

	-- Stack count label overlays in bottom right
	local countLabel = Instance.new("TextLabel")
	countLabel.Name = "CountLabel"
	countLabel.Size = UDim2.new(0, 40, 0, 20)
	countLabel.Position = UDim2.new(1, -4, 1, -4)
	countLabel.AnchorPoint = Vector2.new(1, 1)
	countLabel.BackgroundTransparency = 1
	countLabel.Font = Enum.Font.GothamBold
	countLabel.TextSize = 14
	countLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	countLabel.TextStrokeTransparency = 0.3
	countLabel.Text = ""
	countLabel.TextXAlignment = Enum.TextXAlignment.Right
	countLabel.ZIndex = 4 -- Above viewport
	countLabel.Parent = slot

	-- Number indicator overlays in top left
	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.Size = UDim2.new(0, 20, 0, 20)
	number.Position = UDim2.new(0, 4, 0, 4)
	number.BackgroundTransparency = 1
	number.Font = Enum.Font.GothamBold
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
		border = border,
		innerGlow = innerGlow,
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
				-- Render tool image
				local info = ToolConfig.GetToolInfo(itemId)
				local image = Instance.new("ImageLabel")
				image.Name = "ToolImage"
				image.Size = UDim2.new(1, -8, 1, -8)
				image.Position = UDim2.new(0.5, 0, 0.5, 0)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundTransparency = 1
				image.Image = info and info.image or ""
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

	-- Deselect previous slot
	if self.slotFrames[self.selectedSlot] then
		local prevSlot = self.slotFrames[self.selectedSlot]
		prevSlot.border.Transparency = 1
		prevSlot.innerGlow.Transparency = 1
		-- Reset background to default
		prevSlot.frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		prevSlot.frame.BackgroundTransparency = 0.2
		-- Animate back to normal size
		TweenService:Create(prevSlot.frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, HOTBAR_CONFIG.SLOT_SIZE, 0, HOTBAR_CONFIG.SLOT_SIZE)
		}):Play()
	end

	-- Select new slot with prominent Minecraft-style highlighting
	self.selectedSlot = index
	if self.slotFrames[index] then
		local slot = self.slotFrames[index]
		-- Bright white border
		slot.border.Transparency = 0
		slot.border.Color = Color3.fromRGB(255, 255, 255)
		-- Inner glow for extra emphasis
		slot.innerGlow.Transparency = 0.6
		-- Slightly lighter background
		slot.frame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
		slot.frame.BackgroundTransparency = 0.1
		-- Animate to slightly larger size (Minecraft effect)
		TweenService:Create(slot.frame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, HOTBAR_CONFIG.SLOT_SIZE + 4, 0, HOTBAR_CONFIG.SLOT_SIZE + 4)
		}):Play()
	end

	self:OnSlotSelected()
end

function VoxelHotbar:OnSlotSelected()
	local stack = self.slots[self.selectedSlot]

	-- Store selected slot index for server requests
	GameState:Set("voxelWorld.selectedSlot", self.selectedSlot)

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
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
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
	end)

	-- Mouse wheel scrolling
	self.connections[#self.connections + 1] = UserInputService.InputChanged:Connect(function(input, gpe)
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
