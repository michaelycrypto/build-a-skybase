--[[
	ArmorEquipService.lua
	Server-side armor equip management
	Handles equipping/unequipping armor, validates operations, syncs to clients
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local ArmorEquipService = setmetatable({}, BaseService)
ArmorEquipService.__index = ArmorEquipService

-- Armor slot to ArmorConfig slot mapping
local SLOT_MAPPING = {
	["helmet"] = ArmorConfig.ArmorSlot.HELMET,
	["chestplate"] = ArmorConfig.ArmorSlot.CHESTPLATE,
	["leggings"] = ArmorConfig.ArmorSlot.LEGGINGS,
	["boots"] = ArmorConfig.ArmorSlot.BOOTS,
	-- UI uses "Head", "Chest", etc.
	["Head"] = ArmorConfig.ArmorSlot.HELMET,
	["Chest"] = ArmorConfig.ArmorSlot.CHESTPLATE,
	["Leggings"] = ArmorConfig.ArmorSlot.LEGGINGS,
	["Boots"] = ArmorConfig.ArmorSlot.BOOTS
}

function ArmorEquipService.new()
	local self = setmetatable(BaseService.new(), ArmorEquipService)

	self._logger = Logger:CreateContext("ArmorEquipService")
	self.equippedArmor = {} -- {[player] = {helmet = itemId, chestplate = itemId, ...}}

	return self
end

function ArmorEquipService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Info("ArmorEquipService initialized")
end

function ArmorEquipService:Start()
	if self._started then
		return
	end

	BaseService.Start(self)

	-- Note: RequestArmorSync is handled in EventManager:CreateServerEventConfig()
	-- which calls SyncArmorToClient. We also need to sync armor stats there.

	self._logger.Debug("ArmorEquipService started")
end

function ArmorEquipService:OnPlayerAdded(player: Player)
	-- Initialize empty armor slots (will be populated by LoadArmor if data exists)
	self.equippedArmor[player] = {
		helmet = nil,
		chestplate = nil,
		leggings = nil,
		boots = nil
	}

	-- Note: Actual armor data loading happens in PlayerService after data is loaded
	-- Initial sync will be triggered by PlayerService after LoadArmor is called
end

function ArmorEquipService:OnPlayerRemoving(player: Player)
	-- Note: Armor is saved by PlayerService before this is called
	-- Just clean up player data
	self.equippedArmor[player] = nil
end

-- Load armor data from saved state (called by PlayerService after data is loaded)
function ArmorEquipService:LoadArmor(player: Player, armorData: {helmet: number?, chestplate: number?, leggings: number?, boots: number?})
	if not armorData then
		self._logger.Debug("No armor data to load", {player = player.Name})
		return
	end

	-- Check if armorData has any actual values (not just an empty table)
	local hasAnyArmor = armorData.helmet or armorData.chestplate or armorData.leggings or armorData.boots
	if not hasAnyArmor then
		self._logger.Debug("Armor data exists but is empty", {player = player.Name})
		-- Still initialize the structure even if empty
	end

	-- Initialize if needed
	if not self.equippedArmor[player] then
		self.equippedArmor[player] = {}
	end

	-- Load saved armor into slots (only set if value exists and is a valid number)
	self.equippedArmor[player].helmet = type(armorData.helmet) == "number" and armorData.helmet or nil
	self.equippedArmor[player].chestplate = type(armorData.chestplate) == "number" and armorData.chestplate or nil
	self.equippedArmor[player].leggings = type(armorData.leggings) == "number" and armorData.leggings or nil
	self.equippedArmor[player].boots = type(armorData.boots) == "number" and armorData.boots or nil

	self._logger.Info("Loaded armor data", {
		player = player.Name,
		helmet = self.equippedArmor[player].helmet,
		chestplate = self.equippedArmor[player].chestplate,
		leggings = self.equippedArmor[player].leggings,
		boots = self.equippedArmor[player].boots
	})

	-- Sync to client with delay to ensure client UI is ready
	-- Client initializes many systems on join; a short delay ensures VoxelInventoryPanel
	-- has registered its event listeners before we send the sync
	task.delay(1.5, function()
		if player and player:IsDescendantOf(game.Players) then
			self:SyncArmorToClient(player)
			-- Also sync armor stats for StatusBarsHUD
			self:_syncArmorStats(player)
		end
	end)
end

-- Serialize armor data for saving (called by PlayerService before save)
function ArmorEquipService:SerializeArmor(player: Player)
	local equipped = self.equippedArmor[player]
	if not equipped then
		return nil
	end

	return {
		helmet = equipped.helmet,
		chestplate = equipped.chestplate,
		leggings = equipped.leggings,
		boots = equipped.boots
	}
end

-- Get the canonical slot name
function ArmorEquipService:_normalizeSlot(slot: string): string?
	local armorSlot = SLOT_MAPPING[slot]
	if armorSlot then
		return armorSlot
	end
	-- Already normalized
	if slot == "helmet" or slot == "chestplate" or slot == "leggings" or slot == "boots" then
		return slot
	end
	return nil
end

-- Check if an item can be equipped in a slot
function ArmorEquipService:_canEquipInSlot(itemId: number, slot: string): boolean
	if not itemId or itemId == 0 then
		return false
	end

	local armorInfo = ArmorConfig.GetArmorInfo(itemId)
	if not armorInfo then
		return false
	end

	local normalizedSlot = self:_normalizeSlot(slot)
	return armorInfo.slot == normalizedSlot
end

-- Get equipped armor for a player
function ArmorEquipService:GetEquippedArmor(player: Player)
	return self.equippedArmor[player] or {}
end

-- Equip armor to a slot (takes item from inventory)
function ArmorEquipService:EquipArmor(player: Player, slot: string, itemId: number): boolean
	local normalizedSlot = self:_normalizeSlot(slot)
	if not normalizedSlot then
		self._logger.Warn("Invalid armor slot", {player = player.Name, slot = slot})
		return false
	end

	if not self:_canEquipInSlot(itemId, normalizedSlot) then
		self._logger.Warn("Item cannot be equipped in slot", {player = player.Name, slot = normalizedSlot, itemId = itemId})
		return false
	end

	-- Initialize if needed
	if not self.equippedArmor[player] then
		self.equippedArmor[player] = {}
	end

	-- Store the equipped item
	self.equippedArmor[player][normalizedSlot] = itemId

	self._logger.Debug("Armor equipped", {player = player.Name, slot = normalizedSlot, itemId = itemId})

	-- Notify client
	EventManager:FireEvent("ArmorEquipped", player, {
		slot = normalizedSlot,
		itemId = itemId
	})

	-- Sync armor stats to DamageService for UI update
	self:_syncArmorStats(player)

	return true
end

-- Unequip armor from a slot (returns item to inventory)
function ArmorEquipService:UnequipArmor(player: Player, slot: string): number?
	local normalizedSlot = self:_normalizeSlot(slot)
	if not normalizedSlot then
		self._logger.Warn("Invalid armor slot", {player = player.Name, slot = slot})
		return nil
	end

	if not self.equippedArmor[player] then
		return nil
	end

	local itemId = self.equippedArmor[player][normalizedSlot]
	self.equippedArmor[player][normalizedSlot] = nil

	if itemId then
		self._logger.Debug("Armor unequipped", {player = player.Name, slot = normalizedSlot, itemId = itemId})

		-- Notify client
		EventManager:FireEvent("ArmorUnequipped", player, {
			slot = normalizedSlot
		})

		-- Sync armor stats to DamageService for UI update
		self:_syncArmorStats(player)
	end

	return itemId
end

-- Handle armor slot click (swap with cursor item)
function ArmorEquipService:HandleArmorSlotClick(player: Player, data)
	local slot = data.slot
	local cursorItemId = data.cursorItemId
	local cursorCount = data.cursorCount or 1

	local normalizedSlot = self:_normalizeSlot(slot)
	if not normalizedSlot then
		self._logger.Warn("Invalid armor slot in click", {player = player.Name, slot = slot})
		return
	end

	if not self.equippedArmor[player] then
		self.equippedArmor[player] = {}
	end

	local currentEquipped = self.equippedArmor[player][normalizedSlot]
	local newCursorItem = nil
	local newEquipped = nil

	-- Logic:
	-- 1. If cursor has compatible armor and slot is empty -> equip, cursor becomes empty
	-- 2. If cursor has compatible armor and slot has armor -> swap
	-- 3. If cursor is empty and slot has armor -> unequip to cursor
	-- 4. If cursor has incompatible item -> do nothing

	if cursorItemId and cursorItemId > 0 then
		-- Cursor has an item
		if self:_canEquipInSlot(cursorItemId, normalizedSlot) then
			-- Compatible armor - equip it
			newEquipped = cursorItemId
			newCursorItem = currentEquipped -- Could be nil (empty) or previous armor
			self.equippedArmor[player][normalizedSlot] = newEquipped

			self._logger.Debug("Armor slot click: equipped", {
				player = player.Name,
				slot = normalizedSlot,
				equipped = newEquipped,
				toCursor = newCursorItem
			})
		else
			-- Incompatible item - do nothing
			self._logger.Debug("Armor slot click: incompatible item", {
				player = player.Name,
				slot = normalizedSlot,
				cursorItemId = cursorItemId
			})
			return
		end
	else
		-- Cursor is empty
		if currentEquipped then
			-- Unequip to cursor
			newCursorItem = currentEquipped
			newEquipped = nil
			self.equippedArmor[player][normalizedSlot] = nil

			self._logger.Debug("Armor slot click: unequipped to cursor", {
				player = player.Name,
				slot = normalizedSlot,
				toCursor = newCursorItem
			})
		else
			-- Both empty - do nothing
			return
		end
	end

	-- If an armor item was unequipped to cursor, grant craft credit so it can be placed in inventory
	if newCursorItem and newCursorItem > 0 then
		local PlayerInventoryService = self.Deps and self.Deps.PlayerInventoryService
		if PlayerInventoryService then
			PlayerInventoryService:AddCraftCredit(player, newCursorItem, 1)
			self._logger.Debug("Granted craft credit for unequipped armor", {
				player = player.Name,
				itemId = newCursorItem
			})
		end
	end

	-- Send result to client
	EventManager:FireEvent("ArmorSlotResult", player, {
		slot = normalizedSlot,
		equippedArmor = self.equippedArmor[player],
		newCursorItemId = newCursorItem,
		newCursorCount = newCursorItem and 1 or 0
	})

	-- Sync armor stats to DamageService for UI update
	self:_syncArmorStats(player)
end

-- Internal: Sync armor stats to client via DamageService
function ArmorEquipService:_syncArmorStats(player: Player)
	-- Calculate defense and toughness
	local defense, toughness = self:GetPlayerDefense(player)

	-- Fire armor changed event directly for immediate UI update
	EventManager:FireEvent("PlayerArmorChanged", player, {
		defense = defense,
		toughness = toughness,
	})
end

-- Sync full armor state to client
function ArmorEquipService:SyncArmorToClient(player: Player)
	local armorState = self.equippedArmor[player] or {}
	EventManager:FireEvent("ArmorSync", player, {
		equippedArmor = armorState
	})
end

-- Get armor defense for a player
function ArmorEquipService:GetPlayerDefense(player: Player): (number, number)
	local equipped = self.equippedArmor[player] or {}
	return ArmorConfig.CalculateTotalDefense(equipped)
end

return ArmorEquipService

