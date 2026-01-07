--[[
	BowConfig.lua
	Centralized configuration for bow and arrow mechanics.
]]

local BowConfig = {
	-- Item IDs
	BOW_ITEM_ID = 1051,
	ARROW_ITEM_ID = 2001,

	-- Draw timing (seconds)
	MAX_DRAW_TIME = 1.0,
	MIN_CHARGE_TIME = 0.08,
	DRAW_STAGE_TIMES = {0, 0.2, 0.6},

	-- Projectile tuning
	MIN_SPEED = 120,
	MAX_SPEED = 240,
	MAX_LIFETIME = 10,
	FIRE_COOLDOWN = 0.2,
	INACCURACY_AT_MIN = 2.0,
	INACCURACY_AT_MAX = 0.25,
	IGNORE_SHOOTER_TIME = 0.2,

	-- Damage tuning (Minecraft-style scaling)
	-- Minecraft: 1 dmg (no charge) → 6 dmg (medium) → 9 dmg (full) → 10 dmg (crit)
	MIN_DAMAGE = 1,        -- Damage at no/minimal charge
	MAX_DAMAGE = 9,        -- Damage at full charge
	CRIT_DAMAGE = 10,      -- Damage on critical hit (full charge + sparkle)
	KNOCKBACK_STRENGTH = 18,
	CRIT_THRESHOLD = 1.0,  -- Must be fully charged for crit chance
	CRIT_CHANCE = 0.25,    -- 25% chance for crit at full charge (Minecraft-like)

	-- Stuck arrow cleanup
	STUCK_LIFETIME = 6,

	-- FOV zoom when fully charged (subtle Minecraft-style)
	-- Base: 80 FOV → 70 FOV (subtle 12% reduction)
	ZOOM_FOV = 70,
	ZOOM_IN_SPEED = 18, -- Fast zoom in
	ZOOM_OUT_SPEED = 14, -- Fast snap back when released

	-- Arrow hit sounds
	HIT_SOUNDS = {
		"rbxassetid://115515859621136",
		"rbxassetid://90784820853741",
		"rbxassetid://123130446112968",
		"rbxassetid://100144120804053",
	},
	HIT_SOUND_VOLUME = 0.8,

	-- Bow shoot sounds (plays when arrow is released)
	SHOOT_SOUNDS = {
		"rbxassetid://99176007341961",
		"rbxassetid://87079854445341",
		"rbxassetid://80644673929793",
	},
	SHOOT_SOUND_VOLUME = 0.7,
}

-- Convert charge time to power (0-1), using Minecraft-like curve
function BowConfig.ChargeToPower(chargeSeconds)
	local t = math.clamp(chargeSeconds / BowConfig.MAX_DRAW_TIME, 0, 1)
	-- Minecraft-style curve: slow start, faster middle, levels off at end
	return math.clamp((t * t * 0.8) + (t * 0.2), 0, 1)
end

function BowConfig.GetSpeed(chargeSeconds)
	local power = BowConfig.ChargeToPower(chargeSeconds)
	return BowConfig.MIN_SPEED + (BowConfig.MAX_SPEED - BowConfig.MIN_SPEED) * power, power
end

-- Minecraft-style damage scaling based on charge power
-- power 0.0 = 1 damage (tap release)
-- power 0.5 = ~5 damage (medium charge)
-- power 1.0 = 9 damage (full charge)
-- power 1.0 + crit = 10 damage
function BowConfig.GetDamage(power, isCrit)
	-- Linear interpolation from MIN to MAX damage based on power
	local dmg = BowConfig.MIN_DAMAGE + (BowConfig.MAX_DAMAGE - BowConfig.MIN_DAMAGE) * power

	-- Critical hit at full charge
	if isCrit and power >= BowConfig.CRIT_THRESHOLD then
		dmg = BowConfig.CRIT_DAMAGE
	end

	return math.floor(dmg + 0.5) -- Round to nearest integer like Minecraft
end

-- Determine if shot is a critical hit (full charge + random chance)
function BowConfig.RollCrit(power)
	if power >= BowConfig.CRIT_THRESHOLD then
		return math.random() < (BowConfig.CRIT_CHANCE or 0.25)
	end
	return false
end

return BowConfig
