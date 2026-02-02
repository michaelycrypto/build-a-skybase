--[[
	DamageService.lua
	Centralized damage calculation with Minecraft-style armor reduction
	Handles all damage types: melee, ranged, fall, fire, etc.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local BaseService = require(script.Parent.BaseService)
local Logger = require(ReplicatedStorage.Shared.Logger)
local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)
local EventManager = require(ReplicatedStorage.Shared.EventManager)

local DamageService = setmetatable({}, BaseService)
DamageService.__index = DamageService

-- Damage types (affects armor reduction)
DamageService.DamageType = {
	MELEE = "melee",       -- Reduced by armor
	PROJECTILE = "projectile", -- Reduced by armor
	FALL = "fall",         -- NOT reduced by armor (Minecraft behavior)
	FIRE = "fire",         -- Reduced by armor
	VOID = "void",         -- NOT reduced by armor
	MAGIC = "magic",       -- NOT reduced by armor (bypasses)
	STARVATION = "starvation", -- NOT reduced by armor
}

-- Damage types that bypass armor
local ARMOR_BYPASS_TYPES = {
	[DamageService.DamageType.FALL] = true,
	[DamageService.DamageType.VOID] = true,
	[DamageService.DamageType.MAGIC] = true,
	[DamageService.DamageType.STARVATION] = true,
}

function DamageService.new()
	local self = setmetatable(BaseService.new(), DamageService)

	self._logger = Logger:CreateContext("DamageService")
	self._lastHealthBroadcast = {} -- {[player] = {health, time}}

	return self
end

function DamageService:Init()
	if self._initialized then
		return
	end

	BaseService.Init(self)
	self._logger.Debug("DamageService initialized")
end

function DamageService:Start()
	if self._started then
		return
	end

	-- Listen for character spawns to track health
	Players.PlayerAdded:Connect(function(player)
		self:_setupPlayerHealth(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		self:_setupPlayerHealth(player)
	end

	BaseService.Start(self)
	self._logger.Debug("DamageService started")
end

-- Setup health tracking for a player
function DamageService:_setupPlayerHealth(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			-- Sync initial health
			task.defer(function()
				self:_broadcastHealthUpdate(player)
				self:_broadcastArmorUpdate(player)
			end)

			-- Track health changes
			humanoid.HealthChanged:Connect(function(_newHealth)
				self:_broadcastHealthUpdate(player)
			end)

			-- Handle death
			humanoid.Died:Connect(function()
				self:_onPlayerDeath(player)
			end)
		end
	end)
end

-- Broadcast health update to client
function DamageService:_broadcastHealthUpdate(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Rate limit broadcasts (max once per 0.1s)
	local now = os.clock()
	local last = self._lastHealthBroadcast[player]
	if last and (now - last.time) < 0.1 and last.health == humanoid.Health then
		return
	end

	self._lastHealthBroadcast[player] = {health = humanoid.Health, time = now}

	EventManager:FireEvent("PlayerHealthChanged", player, {
		health = humanoid.Health,
		maxHealth = humanoid.MaxHealth,
	})
end

-- Broadcast armor update to client
function DamageService:_broadcastArmorUpdate(player)
	local ArmorEquipService = self.Deps and self.Deps.ArmorEquipService
	if not ArmorEquipService then return end

	local defense, toughness = ArmorEquipService:GetPlayerDefense(player)

	EventManager:FireEvent("PlayerArmorChanged", player, {
		defense = defense,
		toughness = toughness,
	})
end

-- Handle player death
function DamageService:_onPlayerDeath(player)
	self._logger.Debug("Player died", {player = player.Name})

	-- Fire death event
	EventManager:FireEvent("PlayerDied", player, {
		playerId = player.UserId,
	})

	-- Drop items on death (Minecraft behavior)
	self:_dropPlayerItems(player)
end

-- Drop player's inventory on death
function DamageService:_dropPlayerItems(player)
	local PlayerInventoryService = self.Deps and self.Deps.PlayerInventoryService
	local DroppedItemService = self.Deps and self.Deps.DroppedItemService

	if not PlayerInventoryService or not DroppedItemService then
		return
	end

	local character = player.Character
	local position = character and character:FindFirstChild("HumanoidRootPart")
	if not position then return end

	local dropPos = position.Position + Vector3.new(0, 2, 0)

	-- Get all items from hotbar and inventory
	local hotbar = PlayerInventoryService:GetHotbarContents(player)
	local inventory = PlayerInventoryService:GetInventoryContents(player)

	-- Drop hotbar items
	for slot, stack in pairs(hotbar or {}) do
		if stack and not stack:IsEmpty() then
			local itemId = stack:GetItemId()
			local count = stack:GetCount()

			-- Random spread
			local offset = Vector3.new(
				(math.random() - 0.5) * 2,
				0,
				(math.random() - 0.5) * 2
			)

			DroppedItemService:SpawnItem(itemId, count, dropPos + offset, Vector3.new(0, 5, 0), false)
			PlayerInventoryService:ClearHotbarSlot(player, slot)
		end
	end

	-- Drop inventory items
	for slot, stack in pairs(inventory or {}) do
		if stack and not stack:IsEmpty() then
			local itemId = stack:GetItemId()
			local count = stack:GetCount()

			local offset = Vector3.new(
				(math.random() - 0.5) * 2,
				0,
				(math.random() - 0.5) * 2
			)

			DroppedItemService:SpawnItem(itemId, count, dropPos + offset, Vector3.new(0, 5, 0), false)
			PlayerInventoryService:ClearInventorySlot(player, slot)
		end
	end

	-- Clear equipped armor (but don't drop - too punishing)
	-- Could optionally drop armor here too

	self._logger.Info("Dropped items on death", {player = player.Name})
end

--[[
	Apply damage to a player with armor reduction
	@param victim: Player - The player receiving damage
	@param rawDamage: number - Base damage before reduction
	@param damageType: string - Type of damage (affects armor calculation)
	@param attacker: Player? - Optional attacker for events
	@return number - Actual damage dealt after reduction
]]
function DamageService:DamagePlayer(victim: Player, rawDamage: number, damageType: string?, attacker: Player?): number
	damageType = damageType or self.DamageType.MELEE

	local character = victim.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return 0
	end

	-- Calculate armor reduction
	local finalDamage = rawDamage
	local defense, toughness = 0, 0

	if not ARMOR_BYPASS_TYPES[damageType] then
		-- Get player's armor defense
		local ArmorEquipService = self.Deps and self.Deps.ArmorEquipService
		if ArmorEquipService then
			defense, toughness = ArmorEquipService:GetPlayerDefense(victim)
		end

		-- Apply Minecraft armor formula
		if defense > 0 then
			finalDamage = ArmorConfig.CalculateDamageReduction(rawDamage, defense, toughness)
		end
	end

	-- Apply damage
	humanoid:TakeDamage(finalDamage)

	-- Log damage
	self._logger.Debug("Damage applied", {
		victim = victim.Name,
		rawDamage = rawDamage,
		finalDamage = finalDamage,
		defense = defense,
		toughness = toughness,
		damageType = damageType,
		attacker = attacker and attacker.Name or "none"
	})

	-- Fire damage event for UI feedback
	EventManager:FireEvent("PlayerDamageTaken", victim, {
		rawDamage = rawDamage,
		finalDamage = finalDamage,
		reduced = rawDamage - finalDamage,
		damageType = damageType,
		attackerId = attacker and attacker.UserId or nil,
	})

	-- Also fire to attacker if exists (for hit confirmation)
	if attacker and attacker ~= victim then
		EventManager:FireEvent("PlayerDealtDamage", attacker, {
			victimId = victim.UserId,
			damage = finalDamage,
			damageType = damageType,
		})
	end

	return finalDamage
end

--[[
	Apply damage to a mob (mobs don't have armor in current implementation)
	@param mob: table - The mob data
	@param rawDamage: number - Damage to apply
	@param attacker: Player? - Optional attacker
	@return number - Damage dealt
]]
function DamageService:DamageMob(_mob, rawDamage: number, _attacker: Player?): number
	-- Mobs don't have armor currently, just return raw damage
	-- Could extend this later for armored mobs
	return rawDamage
end

--[[
	Heal a player
	@param player: Player - The player to heal
	@param amount: number - Amount to heal
]]
function DamageService:HealPlayer(player: Player, amount: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	humanoid.Health = math.min(humanoid.Health + amount, humanoid.MaxHealth)

	-- Broadcast update
	self:_broadcastHealthUpdate(player)
end

--[[
	Force sync armor to client (call when armor changes)
]]
function DamageService:SyncArmor(player: Player)
	self:_broadcastArmorUpdate(player)
end

-- Cleanup on player leave
function DamageService:OnPlayerRemoving(player: Player)
	self._lastHealthBroadcast[player] = nil
end

return DamageService

