--[[
	StatusBarsHUD.lua
	Minecraft-style health, armor, and hunger bars

	Layout (Minecraft-accurate):
	- Left half: Health bar (armor above when equipped)
	- Right half: Hunger bar
	- Positioned directly above hotbar, symmetric around center

	Integration:
	- Registers with UIVisibilityManager for mode-based visibility
	- Uses same scaling system as VoxelHotbar
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)

local StatusBarsHUD = {}
StatusBarsHUD.__index = StatusBarsHUD

--------------------------------------------------------------------------------
-- CONFIGURATION (Hotbar values must match VoxelHotbar.lua)
--------------------------------------------------------------------------------

local HOTBAR = {
	SLOT_SIZE = 62,
	SLOT_SPACING = 5,
	SLOT_COUNT = 9,
	BOTTOM_OFFSET = 4,
	SCALE = 0.85,
	BORDER = 2,
	INTERNAL_OFFSET = 8,
}

-- Derived hotbar dimensions
local VISUAL_SLOT_SIZE = HOTBAR.SLOT_SIZE + (HOTBAR.BORDER * 2) -- 66px per slot
local HOTBAR_WIDTH = (VISUAL_SLOT_SIZE * HOTBAR.SLOT_COUNT) +
                     (HOTBAR.SLOT_SPACING * (HOTBAR.SLOT_COUNT - 1))

-- Status bar configuration
local CONFIG = {
	-- Icon sizing (larger for better visibility)
	ICON_SIZE = 22,
	ICON_SPACING = 2,
	BAR_SPACING = 5,
	GAP_ABOVE_HOTBAR = 1,  -- Minimal consistent gap

	-- Counts (Minecraft standard: 10 of each)
	MAX_HEARTS = 10,
	HP_PER_HEART = 10,
	MAX_ARMOR_ICONS = 10,
	ARMOR_PER_ICON = 2,
	MAX_HUNGER_ICONS = 10,
	HUNGER_PER_ICON = 2,

	-- Colors (Minecraft-accurate)
	HEART_FULL = Color3.fromRGB(211, 33, 45),
	HEART_EMPTY = Color3.fromRGB(85, 0, 0),
	HEART_OUTLINE = Color3.fromRGB(0, 0, 0),

	ARMOR_FULL = Color3.fromRGB(223, 223, 223),
	ARMOR_EMPTY = Color3.fromRGB(55, 55, 55),
	ARMOR_OUTLINE = Color3.fromRGB(35, 35, 35),

	HUNGER_FULL = Color3.fromRGB(179, 119, 49),
	HUNGER_EMPTY = Color3.fromRGB(65, 45, 20),
	HUNGER_OUTLINE = Color3.fromRGB(35, 25, 10),

	-- Animation
	SHAKE_DURATION = 0.15,
	SHAKE_INTENSITY = 3,
	PULSE_SPEED = 8,
	LOW_HEALTH_THRESHOLD = 4,
}

-- Calculate bar dimensions
local ICON_STEP = CONFIG.ICON_SIZE + CONFIG.ICON_SPACING
local BAR_WIDTH = CONFIG.MAX_HEARTS * ICON_STEP - CONFIG.ICON_SPACING -- 10 icons × 18px - 2px = 178px

local player = Players.LocalPlayer

--------------------------------------------------------------------------------
-- CONSTRUCTOR
--------------------------------------------------------------------------------

function StatusBarsHUD.new()
	local self = setmetatable({}, StatusBarsHUD)

	self.gui = nil
	self.container = nil
	self.leftContainer = nil  -- Health + Armor
	self.rightContainer = nil -- Hunger

	self.heartIcons = {}
	self.armorIcons = {}
	self.hungerIcons = {}
	self.armorBar = nil
	self.healthBar = nil
	self.hungerBar = nil

	self.currentHealth = 100
	self.maxHealth = 100
	self.currentArmor = 0
	self.currentHunger = 20

	self.connections = {}
	self.isShaking = false

	return self
end

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------

function StatusBarsHUD:Initialize()
	self:_createGui()
	self:_createContainers()
	self:_createBars()
	self:_connectEvents()
	self:_registerWithVisibilityManager()

	-- Initial sync
	task.spawn(function()
		self:_syncFromHumanoid()
		-- Initialize hunger bar with default value
		self:_updateHunger()
	end)

	-- Request armor and hunger sync from server (with retry logic)
	task.delay(1, function()
		EventManager:SendToServer("RequestArmorSync")
		EventManager:SendToServer("RequestHungerSync")
	end)

	-- Retry sync after a longer delay in case first attempt fails
	task.delay(3, function()
		EventManager:SendToServer("RequestHungerSync")
	end)

	-- Start pulse effect
	self:_startPulseLoop()
end

function StatusBarsHUD:_createGui()
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "StatusBarsHUD"
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 49
	self.gui.IgnoreGuiInset = true
	self.gui.Parent = player:WaitForChild("PlayerGui")

	-- Responsive scaling (matches VoxelHotbar)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = self.gui
	CollectionService:AddTag(uiScale, "scale_component")
end

function StatusBarsHUD:_createContainers()
	-- Calculate positioning to align exactly with hotbar (580px width)
	local hotbarScaledHeight = VISUAL_SLOT_SIZE * HOTBAR.SCALE
	local bottomOffset = HOTBAR.BOTTOM_OFFSET + hotbarScaledHeight + CONFIG.GAP_ABOVE_HOTBAR
	local containerHeight = CONFIG.ICON_SIZE * 2 + CONFIG.BAR_SPACING

	-- Main container (exact same width as hotbar: 580px)
	self.container = Instance.new("Frame")
	self.container.Name = "StatusContainer"
	self.container.BackgroundTransparency = 1
	self.container.AnchorPoint = Vector2.new(0.5, 1)
	self.container.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
	self.container.Size = UDim2.fromOffset(HOTBAR_WIDTH, containerHeight) -- 580px to match hotbar
	self.container.Active = false
	self.container.Parent = self.gui

	-- Local scale (matches VoxelHotbar: 0.85)
	local localScale = Instance.new("UIScale")
	localScale.Name = "LocalScale"
	localScale.Scale = HOTBAR.SCALE
	localScale.Parent = self.container

	-- Left container (health + armor) - aligns with slot 1 frame left edge
	-- Hotbar: slot 1 frame starts at x=8
	self.leftContainer = Instance.new("Frame")
	self.leftContainer.Name = "LeftContainer"
	self.leftContainer.BackgroundTransparency = 1
	self.leftContainer.Position = UDim2.fromOffset(HOTBAR.INTERNAL_OFFSET, 0) -- x=8 to match slot 1 frame
	self.leftContainer.Size = UDim2.new(0, BAR_WIDTH, 1, 0)
	self.leftContainer.Parent = self.container

	-- Right container (hunger) - aligns with slot 9 frame right edge
	-- Hotbar: slot 9 frame ends at x=528+56=584
	-- Container: 580px, so offset = 584-580 = +4px
	self.rightContainer = Instance.new("Frame")
	self.rightContainer.Name = "RightContainer"
	self.rightContainer.BackgroundTransparency = 1
	self.rightContainer.AnchorPoint = Vector2.new(1, 0)
	self.rightContainer.Position = UDim2.new(1, 4, 0, 0) -- +4px to match slot 9 frame right edge
	self.rightContainer.Size = UDim2.new(0, BAR_WIDTH, 1, 0)
	self.rightContainer.Parent = self.container
end

function StatusBarsHUD:_createBars()
	self:_createHealthBar()
	self:_createArmorBar()
	self:_createHungerBar()
end

function StatusBarsHUD:_registerWithVisibilityManager()
	UIVisibilityManager:RegisterComponent("statusBarsHUD", self, {
		showMethod = "Show",
		hideMethod = "Hide",
		priority = 5
	})
end

--------------------------------------------------------------------------------
-- BAR CREATION
--------------------------------------------------------------------------------

function StatusBarsHUD:_createIcon(iconType, parent)
	local size = CONFIG.ICON_SIZE
	local fullColor, emptyColor, outlineColor

	if iconType == "Heart" then
		fullColor = CONFIG.HEART_FULL
		emptyColor = CONFIG.HEART_EMPTY
		outlineColor = CONFIG.HEART_OUTLINE
	elseif iconType == "Armor" then
		fullColor = CONFIG.ARMOR_FULL
		emptyColor = CONFIG.ARMOR_EMPTY
		outlineColor = CONFIG.ARMOR_OUTLINE
	else
		fullColor = CONFIG.HUNGER_FULL
		emptyColor = CONFIG.HUNGER_EMPTY
		outlineColor = CONFIG.HUNGER_OUTLINE
	end

	local frame = Instance.new("Frame")
	frame.Name = iconType
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(size, size)
	frame.Parent = parent

	-- Outline (black border)
	local outline = Instance.new("Frame")
	outline.Name = "Outline"
	outline.BackgroundColor3 = outlineColor
	outline.BorderSizePixel = 0
	outline.Size = UDim2.fromScale(1, 1)
	outline.ZIndex = 1
	outline.Parent = frame

	-- Empty background (inset by outline)
	local empty = Instance.new("Frame")
	empty.Name = "Empty"
	empty.BackgroundColor3 = emptyColor
	empty.BorderSizePixel = 0
	empty.Position = UDim2.fromOffset(2, 2)
	empty.Size = UDim2.new(1, -4, 1, -4)
	empty.ZIndex = 2
	empty.Parent = frame

	-- Full fill (same position as empty)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = fullColor
	fill.BorderSizePixel = 0
	fill.Position = UDim2.fromOffset(2, 2)
	fill.Size = UDim2.new(1, -4, 1, -4)
	fill.ZIndex = 3
	fill.Parent = frame

	-- Highlight (top-left shine)
	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundColor3 = Color3.new(1, 1, 1)
	highlight.BackgroundTransparency = 0.55
	highlight.BorderSizePixel = 0
	highlight.Position = UDim2.fromOffset(1, 1)
	highlight.Size = UDim2.fromOffset(3, 3)
	highlight.ZIndex = 4
	highlight.Parent = fill

	-- Half fill (for partial values - left half only)
	local halfFill = Instance.new("Frame")
	halfFill.Name = "HalfFill"
	halfFill.BackgroundColor3 = fullColor
	halfFill.BorderSizePixel = 0
	halfFill.Position = UDim2.fromOffset(2, 2)
	halfFill.Size = UDim2.new(0.5, -2, 1, -4)
	halfFill.ZIndex = 3
	halfFill.Visible = false
	halfFill.Parent = frame

	return frame
end

function StatusBarsHUD:_createHealthBar()
	self.healthBar = Instance.new("Frame")
	self.healthBar.Name = "HealthBar"
	self.healthBar.BackgroundTransparency = 1
	self.healthBar.AnchorPoint = Vector2.new(0, 1)
	self.healthBar.Position = UDim2.fromScale(0, 1)
	self.healthBar.Size = UDim2.new(1, 0, 0, CONFIG.ICON_SIZE)
	self.healthBar.Parent = self.leftContainer

	-- Hearts: left-to-right (icon 1 at far left)
	for i = 1, CONFIG.MAX_HEARTS do
		local icon = self:_createIcon("Heart", self.healthBar)
		icon.Position = UDim2.fromOffset((i - 1) * ICON_STEP, 0)
		icon.Name = "Heart_" .. i
		self.heartIcons[i] = icon
	end
end

function StatusBarsHUD:_createArmorBar()
	self.armorBar = Instance.new("Frame")
	self.armorBar.Name = "ArmorBar"
	self.armorBar.BackgroundTransparency = 1
	self.armorBar.Position = UDim2.fromScale(0, 0)
	self.armorBar.Size = UDim2.new(1, 0, 0, CONFIG.ICON_SIZE)
	self.armorBar.Visible = false
	self.armorBar.Parent = self.leftContainer

	-- Armor: left-to-right (same direction as hearts)
	for i = 1, CONFIG.MAX_ARMOR_ICONS do
		local icon = self:_createIcon("Armor", self.armorBar)
		icon.Position = UDim2.fromOffset((i - 1) * ICON_STEP, 0)
		icon.Name = "Armor_" .. i
		self.armorIcons[i] = icon
	end
end

function StatusBarsHUD:_createHungerBar()
	self.hungerBar = Instance.new("Frame")
	self.hungerBar.Name = "HungerBar"
	self.hungerBar.BackgroundTransparency = 1
	self.hungerBar.AnchorPoint = Vector2.new(1, 1)
	self.hungerBar.Position = UDim2.fromScale(1, 1)
	self.hungerBar.Size = UDim2.new(1, 0, 0, CONFIG.ICON_SIZE)
	self.hungerBar.Parent = self.rightContainer

	-- Hunger: right-to-left (icon 1 at far right, mirrored like Minecraft)
	for i = 1, CONFIG.MAX_HUNGER_ICONS do
		local icon = self:_createIcon("Hunger", self.hungerBar)
		-- Position from right: rightmost icon (i=1) at far right
		icon.AnchorPoint = Vector2.new(1, 0)
		icon.Position = UDim2.new(1, -(i - 1) * ICON_STEP, 0, 0)
		icon.Name = "Hunger_" .. i
		self.hungerIcons[i] = icon
	end

	-- Initialize hunger bar with default value
	self:_updateHunger()
end

--------------------------------------------------------------------------------
-- STATE UPDATES
--------------------------------------------------------------------------------

function StatusBarsHUD:_setIconState(icon, state)
	local fill = icon:FindFirstChild("Fill")
	local halfFill = icon:FindFirstChild("HalfFill")
	if not fill or not halfFill then
		return
	end

	if state == "full" then
		fill.Visible = true
		halfFill.Visible = false
	elseif state == "half" then
		fill.Visible = false
		halfFill.Visible = true
	else
		fill.Visible = false
		halfFill.Visible = false
	end
end

function StatusBarsHUD:_updateHearts()
	local hearts = self.currentHealth / CONFIG.HP_PER_HEART

	for i = 1, CONFIG.MAX_HEARTS do
		if hearts >= i then
			self:_setIconState(self.heartIcons[i], "full")
		elseif hearts >= i - 0.5 then
			self:_setIconState(self.heartIcons[i], "half")
		else
			self:_setIconState(self.heartIcons[i], "empty")
		end
	end
end

function StatusBarsHUD:_updateArmor()
	local armorPoints = self.currentArmor / CONFIG.ARMOR_PER_ICON
	self.armorBar.Visible = self.currentArmor > 0

	for i = 1, CONFIG.MAX_ARMOR_ICONS do
		if armorPoints >= i then
			self:_setIconState(self.armorIcons[i], "full")
		elseif armorPoints >= i - 0.5 then
			self:_setIconState(self.armorIcons[i], "half")
		else
			self:_setIconState(self.armorIcons[i], "empty")
		end
	end
end

function StatusBarsHUD:_updateHunger()
	-- Ensure hunger icons exist
	if not self.hungerIcons or #self.hungerIcons == 0 then
		return
	end

	-- Clamp hunger to valid range (0-20) for safety
	local clampedHunger = math.clamp(self.currentHunger or 20, 0, 20)
	local hungerPoints = clampedHunger / CONFIG.HUNGER_PER_ICON

	-- Update each hunger icon (10 icons, each represents 2 hunger points)
	for i = 1, CONFIG.MAX_HUNGER_ICONS do
		if not self.hungerIcons[i] then
			continue
		end

		-- Each icon represents 2 hunger points
		-- Icon 1 = hunger 0-2, Icon 2 = hunger 2-4, etc.
		-- Full icon: hungerPoints >= i (e.g., icon 1 full when hunger >= 2)
		-- Half icon: hungerPoints >= i - 0.5 (e.g., icon 1 half when hunger >= 1)
		-- Empty icon: hungerPoints < i - 0.5
		if hungerPoints >= i then
			self:_setIconState(self.hungerIcons[i], "full")
		elseif hungerPoints >= i - 0.5 then
			self:_setIconState(self.hungerIcons[i], "half")
		else
			self:_setIconState(self.hungerIcons[i], "empty")
		end
	end
end

--------------------------------------------------------------------------------
-- ANIMATIONS
--------------------------------------------------------------------------------

function StatusBarsHUD:_shakeHearts()
	if self.isShaking then
		return
	end
	self.isShaking = true

	local shakeCount = 4
	local shakeTime = CONFIG.SHAKE_DURATION / shakeCount

	for _ = 1, shakeCount do
		for i, icon in ipairs(self.heartIcons) do
			local baseX = (i - 1) * ICON_STEP
			local offsetY = math.random(-CONFIG.SHAKE_INTENSITY, CONFIG.SHAKE_INTENSITY)
			icon.Position = UDim2.fromOffset(baseX, offsetY)
		end
		task.wait(shakeTime)
	end

	-- Reset positions
	for i, icon in ipairs(self.heartIcons) do
		icon.Position = UDim2.fromOffset((i - 1) * ICON_STEP, 0)
	end

	self.isShaking = false
end

function StatusBarsHUD:_startPulseLoop()
	local pulsePhase = 0

	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		pulsePhase = pulsePhase + dt * CONFIG.PULSE_SPEED
		local threshold = CONFIG.LOW_HEALTH_THRESHOLD * CONFIG.HP_PER_HEART

		if self.currentHealth <= threshold and self.currentHealth > 0 then
			local pulse = (math.sin(pulsePhase) + 1) / 2
			local color = CONFIG.HEART_FULL:Lerp(CONFIG.HEART_EMPTY, pulse * 0.4)

			for _, icon in ipairs(self.heartIcons) do
				local fill = icon:FindFirstChild("Fill")
				local halfFill = icon:FindFirstChild("HalfFill")
				if fill and fill.Visible then
					fill.BackgroundColor3 = color
				end
				if halfFill and halfFill.Visible then
					halfFill.BackgroundColor3 = color
				end
			end
		else
			for _, icon in ipairs(self.heartIcons) do
				local fill = icon:FindFirstChild("Fill")
				local halfFill = icon:FindFirstChild("HalfFill")
				if fill then
					fill.BackgroundColor3 = CONFIG.HEART_FULL
				end
				if halfFill then
					halfFill.BackgroundColor3 = CONFIG.HEART_FULL
				end
			end
		end
	end))
end

--------------------------------------------------------------------------------
-- EVENT CONNECTIONS
--------------------------------------------------------------------------------

function StatusBarsHUD:_connectEvents()
	local healthConn = EventManager:ConnectToServer("PlayerHealthChanged", function(data)
		if not data then
			return
		end
		local oldHealth = self.currentHealth
		self.currentHealth = data.health or self.currentHealth
		self.maxHealth = data.maxHealth or self.maxHealth

		if self.currentHealth < oldHealth then
			task.spawn(function() self:_shakeHearts() end)
		end
		self:_updateHearts()
	end)
	if healthConn then
		table.insert(self.connections, healthConn)
	end

	local armorConn = EventManager:ConnectToServer("PlayerArmorChanged", function(data)
		if not data then
			return
		end
		self.currentArmor = data.defense or 0
		self:_updateArmor()
	end)
	if armorConn then
		table.insert(self.connections, armorConn)
	end

	local hungerConn = EventManager:ConnectToServer("PlayerHungerChanged", function(data)
		if not data then
			warn("StatusBarsHUD: PlayerHungerChanged event received with no data")
			return
		end

		-- Clamp hunger to valid range (0-20) for safety
		local hunger = data.hunger
		local _saturation = data.saturation

		if hunger ~= nil then
			local oldHunger = self.currentHunger
			hunger = math.clamp(hunger, 0, 20)
			self.currentHunger = hunger

			-- Only update if hunger actually changed (avoid unnecessary redraws)
			if oldHunger ~= hunger then
				self:_updateHunger()
			end
		else
			warn("StatusBarsHUD: PlayerHungerChanged event received with nil hunger value")
		end

		-- Note: saturation is not displayed in the UI, but we receive it for potential future use
	end)
	if hungerConn then
		table.insert(self.connections, hungerConn)
	else
		warn("StatusBarsHUD: Failed to connect to PlayerHungerChanged event")
	end

	local damageConn = EventManager:ConnectToServer("PlayerDamageTaken", function(data)
		if data then
			task.spawn(function() self:_shakeHearts() end)
		end
	end)
	if damageConn then
		table.insert(self.connections, damageConn)
	end
end

function StatusBarsHUD:_syncFromHumanoid()
	local function connect(humanoid)
		if not humanoid then
			return
		end

		self.currentHealth = humanoid.Health
		self.maxHealth = humanoid.MaxHealth
		self:_updateHearts()

		table.insert(self.connections, humanoid.HealthChanged:Connect(function(newHealth)
			local oldHealth = self.currentHealth
			self.currentHealth = newHealth
			if newHealth < oldHealth then
				task.spawn(function() self:_shakeHearts() end)
			end
			self:_updateHearts()
		end))
	end

	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			connect(humanoid)
		else
			connect(character:WaitForChild("Humanoid", 5))
		end
	end

	table.insert(self.connections, player.CharacterAdded:Connect(function(char)
		task.spawn(function()
			connect(char:WaitForChild("Humanoid", 5))
		end)
	end))
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function StatusBarsHUD:Show()
	if self.gui then
		self.gui.Enabled = true
	end
end

function StatusBarsHUD:Hide()
	if self.gui then
		self.gui.Enabled = false
	end
end

function StatusBarsHUD:IsOpen()
	return self.gui and self.gui.Enabled
end

function StatusBarsHUD:Destroy()
	-- Unregister from visibility manager
	UIVisibilityManager:UnregisterComponent("statusBarsHUD")

	-- Disconnect all connections
	for _, conn in ipairs(self.connections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		end
	end
	self.connections = {}

	-- Destroy GUI
	if self.gui then
		self.gui:Destroy()
		self.gui = nil
	end
end

return StatusBarsHUD
