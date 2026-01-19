--[[
	ArmorVisualController.lua
	Armor visual system using body color changes + physical boots/helmet.

	- Chestplate: Changes body color (torso, arms)
	- Leggings: Changes body color (legs)
	- Boots: Physical armor parts
	- Helmet: Mesh attachment

	Uses ArmorRenderer shared module for actual rendering logic.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local ArmorRenderer = require(ReplicatedStorage.Shared.ArmorRenderer)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

-- ═══════════════════════════════════════════════════════════════════════════
-- STATE
-- ═══════════════════════════════════════════════════════════════════════════

local controller = {}
local player = Players.LocalPlayer
local connections = {}

local equippedArmor = {
	helmet = nil,
	chestplate = nil,
	leggings = nil,
	boots = nil
}

-- Physical armor parts (for cleanup)
local armorParts = {
	helmet = {},
	chestplate = {},
	leggings = {},
	boots = {}
}

-- Store original body colors to restore when armor is removed
local originalColors = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- SLOT MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════

local function destroySlotParts(slot)
	if not armorParts[slot] then return end
	for _, part in pairs(armorParts[slot]) do
		if part and part.Parent then
			part:Destroy()
		end
	end
	armorParts[slot] = {}
end

local function updateSlot(slot, itemId)
	local character = player.Character
	if not character then return end

	if slot == "helmet" then
		destroySlotParts("helmet")
		if itemId and itemId > 0 then
			armorParts.helmet = ArmorRenderer.CreateHelmet(character, itemId, false)
		end
	elseif slot == "chestplate" then
		destroySlotParts("chestplate")
		if itemId and itemId > 0 then
			ArmorRenderer.ApplyBodyColors(character, slot, itemId, originalColors)
			armorParts.chestplate = ArmorRenderer.CreateChestplateArmor(character, itemId, false)
		else
			ArmorRenderer.RemoveBodyColors(character, slot, originalColors)
		end
	elseif slot == "leggings" then
		destroySlotParts("leggings")
		if itemId and itemId > 0 then
			ArmorRenderer.ApplyBodyColors(character, slot, itemId, originalColors)
			armorParts.leggings = ArmorRenderer.CreateLeggingsArmor(character, itemId, false)
		else
			ArmorRenderer.RemoveBodyColors(character, slot, originalColors)
		end
	elseif slot == "boots" then
		destroySlotParts("boots")
		if itemId and itemId > 0 then
			armorParts.boots = ArmorRenderer.CreateBoots(character, itemId, false)
		end
	end

	equippedArmor[slot] = itemId
end

local function refreshAllArmor()
	local character = player.Character
	if not character then return end

	-- Clear all physical parts
	destroySlotParts("helmet")
	destroySlotParts("chestplate")
	destroySlotParts("leggings")
	destroySlotParts("boots")

	-- Reset original colors cache for new character
	originalColors = {}

	-- Re-apply all equipped armor
	for slot, itemId in pairs(equippedArmor) do
		if itemId and itemId > 0 then
			updateSlot(slot, itemId)
		end
	end
end

local function clearAllArmor()
	local character = player.Character

	destroySlotParts("helmet")
	destroySlotParts("chestplate")
	destroySlotParts("leggings")
	destroySlotParts("boots")

	if character then
		ArmorRenderer.RemoveBodyColors(character, "chestplate", originalColors)
		ArmorRenderer.RemoveBodyColors(character, "leggings", originalColors)
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENT HANDLERS
-- ═══════════════════════════════════════════════════════════════════════════

local function onArmorSync(data)
	if not data or not data.equippedArmor then return end

	equippedArmor = {
		helmet = data.equippedArmor.helmet,
		chestplate = data.equippedArmor.chestplate,
		leggings = data.equippedArmor.leggings,
		boots = data.equippedArmor.boots
	}

	refreshAllArmor()
end

local function onArmorEquipped(data)
	if not data or not data.slot then return end
	updateSlot(data.slot, data.itemId)
end

local function onArmorUnequipped(data)
	if not data or not data.slot then return end
	updateSlot(data.slot, nil)
end

local function onArmorSlotResult(data)
	if not data or not data.equippedArmor then return end

	local oldArmor = equippedArmor
	equippedArmor = {
		helmet = data.equippedArmor.helmet,
		chestplate = data.equippedArmor.chestplate,
		leggings = data.equippedArmor.leggings,
		boots = data.equippedArmor.boots
	}

	for slot, newItemId in pairs(equippedArmor) do
		if oldArmor[slot] ~= newItemId then
			updateSlot(slot, newItemId)
		end
	end
	for slot, oldItemId in pairs(oldArmor) do
		if equippedArmor[slot] == nil and oldItemId ~= nil then
			updateSlot(slot, nil)
		end
	end
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	local head = character:WaitForChild("Head", 5)
	local _ = character:WaitForChild("Torso", 2) or character:WaitForChild("UpperTorso", 2)

	if not humanoid or not head then
		warn("[ArmorVisualController] Character missing required parts, aborting setup")
		return
	end

	-- Remove accessories
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Accessory") then
			child:Destroy()
		end
	end

	-- Reset color cache and re-apply armor
	originalColors = {}
	task.defer(refreshAllArmor)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTROLLER LIFECYCLE
-- ═══════════════════════════════════════════════════════════════════════════

function controller.Init()
	local events = {
		{ "ArmorSync", onArmorSync },
		{ "ArmorEquipped", onArmorEquipped },
		{ "ArmorUnequipped", onArmorUnequipped },
		{ "ArmorSlotResult", onArmorSlotResult }
	}

	for _, event in ipairs(events) do
		local conn = EventManager:RegisterEvent(event[1], event[2])
		if conn then
			table.insert(connections, conn)
		end
	end

	table.insert(connections, player.CharacterAdded:Connect(onCharacterAdded))

	if player.Character then
		task.defer(function()
			onCharacterAdded(player.Character)
		end)
	end

	print("🛡️ ArmorVisualController initialized (body colors + boots)")
end

function controller.Destroy()
	for _, conn in ipairs(connections) do
		if typeof(conn) == "RBXScriptConnection" then
			conn:Disconnect()
		elseif typeof(conn) == "table" and conn.Disconnect then
			conn:Disconnect()
		end
	end
	connections = {}
	clearAllArmor()
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PUBLIC API
-- ═══════════════════════════════════════════════════════════════════════════

controller.RefreshAllArmor = refreshAllArmor
controller.UpdateSlot = updateSlot
controller.GetEquippedArmor = function() return equippedArmor end

return controller
