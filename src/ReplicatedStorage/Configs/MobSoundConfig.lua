--[[
	MobSoundConfig.lua

	Defines per-mob sound mappings (death, hurt, ambient "say") that reference the
	global SOUND_LIBRARY names declared in GameConfig.
]]

local DEFAULT_AMBIENT_INTERVAL = {min = 8, max = 14}

local MobSoundConfig = {
	Definitions = {
		ZOMBIE = {
			death = {"zombieDeath"},
			hurt = {"zombieHurt1", "zombieHurt2"},
			say = {"zombieSay1", "zombieSay2", "zombieSay3"},
			ambientInterval = {min = 6, max = 11}
		}
	}
}

local function getDefinition(mobType)
	return MobSoundConfig.Definitions[mobType]
end

function MobSoundConfig.GetSoundNames(mobType, category)
	local def = getDefinition(mobType)
	if not def then
		return nil
	end
	return def[category]
end

function MobSoundConfig.GetRandomSoundName(mobType, category, rng)
	local sounds = MobSoundConfig.GetSoundNames(mobType, category)
	if not sounds or #sounds == 0 then
		return nil
	end
	local randomGen = rng or Random.new()
	local index = randomGen:NextInteger(1, #sounds)
	return sounds[index]
end

function MobSoundConfig.GetAmbientInterval(mobType)
	local def = getDefinition(mobType)
	local interval = (def and def.ambientInterval) or DEFAULT_AMBIENT_INTERVAL
	return interval.min or DEFAULT_AMBIENT_INTERVAL.min, interval.max or DEFAULT_AMBIENT_INTERVAL.max
end

function MobSoundConfig.HasCategory(mobType, category)
	local sounds = MobSoundConfig.GetSoundNames(mobType, category)
	return sounds ~= nil and #sounds > 0
end

return MobSoundConfig

