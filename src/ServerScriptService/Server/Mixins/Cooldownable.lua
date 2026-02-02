--[[
	Cooldownable Trait

	Simple composable trait for managing cooldowns on abilities, rewards, and actions.
	Essential for daily rewards, abilities, commands, and rate-limited features.

	Usage:
	- Include in your service: local Cooldownable = require(ServerScriptService.Server.Mixins.Cooldownable)
	- Apply to service: Cooldownable.Apply(self)
	- Use cooldown methods: self:StartCooldown("daily_reward", player, 86400)

	Features:
	- Multi-key cooldown tracking
	- Flexible cooldown duration configuration
	- Cooldown reduction and modifiers
	- Per-player and global cooldowns
	- Cooldown status queries
--]]

local Cooldownable = {}

--[[
	Apply cooldown functionality to a service
	@param service table - Service to apply cooldown functionality to
--]]
function Cooldownable.Apply(service)
	-- Initialize cooldown data
	service._cooldowns = {}
	service._cooldownDefinitions = {}
	service._cooldownModifiers = {}

	-- Add cooldown methods
	for methodName, method in pairs(Cooldownable.Methods) do
		service[methodName] = method
	end
end

--[[
	Cooldown methods that get added to services
--]]
Cooldownable.Methods = {}

--[[
	Define a cooldown type with default duration
	@param cooldownId string - Unique cooldown identifier
	@param defaultDuration number - Default cooldown duration in seconds
	@param config table - Optional configuration {playerSpecific, resetOnLeave, etc.}
--]]
function Cooldownable.Methods:DefineCooldown(cooldownId, defaultDuration, config)
	assert(type(cooldownId) == "string", "CooldownId must be a string")
	assert(type(defaultDuration) == "number", "Default duration must be a number")

	config = config or {}

	self._cooldownDefinitions[cooldownId] = {
		defaultDuration = defaultDuration,
		playerSpecific = config.playerSpecific ~= false, -- Default true
		resetOnLeave = config.resetOnLeave == true,
		modifiable = config.modifiable ~= false, -- Default true
		data = config.data or {}
	}
end

--[[
	Start a cooldown for a player or globally
	@param cooldownId string - Cooldown to start
	@param player Player - Optional player (if player-specific)
	@param duration number - Optional custom duration (overrides default)
	@return number - Actual cooldown duration used
--]]
function Cooldownable.Methods:StartCooldown(cooldownId, player, duration)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	local definition = self._cooldownDefinitions[cooldownId]
	if not definition then
		error("Cooldown not defined: " .. cooldownId)
	end

	-- Calculate final duration
	local finalDuration = duration or definition.defaultDuration
	if definition.modifiable then
		finalDuration = self:_applyDurationModifiers(cooldownId, finalDuration, player)
	end

	local cooldownKey = self:_getCooldownKey(cooldownId, player, definition.playerSpecific)
	local endTime = os.time() + finalDuration

	self._cooldowns[cooldownKey] = {
		cooldownId = cooldownId,
		startTime = os.time(),
		endTime = endTime,
		duration = finalDuration,
		player = player and tostring(player.UserId) or nil
	}

	return finalDuration
end

--[[
	Check if a cooldown is active
	@param cooldownId string - Cooldown to check
	@param player Player - Optional player (if player-specific)
	@return boolean - True if on cooldown
--]]
function Cooldownable.Methods:IsOnCooldown(cooldownId, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	local definition = self._cooldownDefinitions[cooldownId]
	if not definition then
		return false
	end

	local cooldownKey = self:_getCooldownKey(cooldownId, player, definition.playerSpecific)
	local cooldownData = self._cooldowns[cooldownKey]

	if not cooldownData then
		return false
	end

	-- Check if cooldown has expired
	if os.time() >= cooldownData.endTime then
		self._cooldowns[cooldownKey] = nil
		return false
	end

	return true
end

--[[
	Get remaining cooldown time
	@param cooldownId string - Cooldown to check
	@param player Player - Optional player (if player-specific)
	@return number - Remaining seconds (0 if not on cooldown)
--]]
function Cooldownable.Methods:GetRemainingCooldown(cooldownId, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	if not self:IsOnCooldown(cooldownId, player) then
		return 0
	end

	local definition = self._cooldownDefinitions[cooldownId]
	local cooldownKey = self:_getCooldownKey(cooldownId, player, definition.playerSpecific)
	local cooldownData = self._cooldowns[cooldownKey]

	return math.max(0, cooldownData.endTime - os.time())
end

--[[
	Get cooldown progress (0-1, where 1 is complete)
	@param cooldownId string - Cooldown to check
	@param player Player - Optional player (if player-specific)
	@return number - Progress from 0 to 1
--]]
function Cooldownable.Methods:GetCooldownProgress(cooldownId, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	if not self:IsOnCooldown(cooldownId, player) then
		return 1.0
	end

	local definition = self._cooldownDefinitions[cooldownId]
	local cooldownKey = self:_getCooldownKey(cooldownId, player, definition.playerSpecific)
	local cooldownData = self._cooldowns[cooldownKey]

	local elapsed = os.time() - cooldownData.startTime
	return math.min(1.0, elapsed / cooldownData.duration)
end

--[[
	Clear a specific cooldown
	@param cooldownId string - Cooldown to clear
	@param player Player - Optional player (if player-specific)
	@return boolean - True if cooldown was cleared
--]]
function Cooldownable.Methods:ClearCooldown(cooldownId, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	local definition = self._cooldownDefinitions[cooldownId]
	if not definition then
		return false
	end

	local cooldownKey = self:_getCooldownKey(cooldownId, player, definition.playerSpecific)
	local wasOnCooldown = self._cooldowns[cooldownKey] ~= nil

	self._cooldowns[cooldownKey] = nil

	return wasOnCooldown
end

--[[
	Add a duration modifier for a cooldown
	@param cooldownId string - Cooldown to modify
	@param modifier number - Multiplier for duration (0.5 = 50% duration, 2.0 = 200% duration)
	@param player Player - Optional player (if player-specific)
--]]
function Cooldownable.Methods:AddCooldownModifier(cooldownId, modifier, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")
	assert(type(modifier) == "number", "Modifier must be a number")

	local key = player and tostring(player.UserId) or "global"
	if not self._cooldownModifiers[key] then
		self._cooldownModifiers[key] = {}
	end

	self._cooldownModifiers[key][cooldownId] = modifier
end

--[[
	Remove a duration modifier for a cooldown
	@param cooldownId string - Cooldown to modify
	@param player Player - Optional player (if player-specific)
--]]
function Cooldownable.Methods:RemoveCooldownModifier(cooldownId, player)
	assert(type(cooldownId) == "string", "CooldownId must be a string")

	local key = player and tostring(player.UserId) or "global"
	if self._cooldownModifiers[key] then
		self._cooldownModifiers[key][cooldownId] = nil
	end
end

--[[
	Get all active cooldowns for a player
	@param player Player - Optional player (if nil, returns global cooldowns)
	@return table - Array of cooldown data
--]]
function Cooldownable.Methods:GetActiveCooldowns(player)
	local activeCooldowns = {}
	local playerKey = player and tostring(player.UserId) or "global"

	for _, cooldownData in pairs(self._cooldowns) do
		local matchesPlayer = (player and cooldownData.player == playerKey) or (not player and not cooldownData.player)

		if matchesPlayer and os.time() < cooldownData.endTime then
			table.insert(activeCooldowns, {
				cooldownId = cooldownData.cooldownId,
				remaining = cooldownData.endTime - os.time(),
				progress = self:GetCooldownProgress(cooldownData.cooldownId, player)
			})
		end
	end

	return activeCooldowns
end

--[[
	Private: Generate cooldown key
--]]
function Cooldownable.Methods:_getCooldownKey(cooldownId, player, playerSpecific)
	if playerSpecific and player then
		return tostring(player.UserId) .. ":" .. cooldownId
	else
		return "global:" .. cooldownId
	end
end

--[[
	Private: Apply duration modifiers
--]]
function Cooldownable.Methods:_applyDurationModifiers(cooldownId, baseDuration, player)
	local key = player and tostring(player.UserId) or "global"
	local modifiers = self._cooldownModifiers[key]

	if not modifiers or not modifiers[cooldownId] then
		return baseDuration
	end

	return baseDuration * modifiers[cooldownId]
end

return Cooldownable