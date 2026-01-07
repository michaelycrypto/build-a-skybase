--[[
	SpawnEggConfig.lua
	Defines spawn egg items mapped to mob types and their two-tone colors.
	Generates numeric itemIds for eggs and provides helpers for UI/server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobRegistry = require(ReplicatedStorage.Configs.MobRegistry)

local SpawnEggConfig = {}

-- Asset ids provided by user
SpawnEggConfig.BaseImageId = "rbxassetid://75183565228794"
SpawnEggConfig.OverlayImageId = "rbxassetid://129253357973352"

-- Numeric id range reserved for spawn eggs
-- NOTE: 2001 is reserved for Arrows, so spawn eggs start at 4001
local EGG_ID_START = 4001

-- Deterministic color generation from mobType when not explicitly mapped
local function hashStringToHue(str)
	local hash = 0
	for i = 1, #str do
		hash = (hash * 31 + string.byte(str, i)) % 360
	end
	return hash / 360
end

local function defaultColorsForMob(mobType)
	local h1 = hashStringToHue(mobType)
	local h2 = (h1 + 0.15) % 1
	local s1, v1 = 0.55, 0.95
	local s2, v2 = 0.65, 0.80
	return Color3.fromHSV(h1, s1, v1), Color3.fromHSV(h2, s2, v2)
end

-- Optional explicit color overrides (primary, secondary)
local COLOR_OVERRIDES = {
	ZOMBIE = { Color3.fromRGB(58, 125, 68), Color3.fromRGB(46, 78, 31) },
	SKELETON = { Color3.fromRGB(198, 198, 198), Color3.fromRGB(122, 122, 122) },
	CHICKEN = { Color3.fromRGB(245, 245, 245), Color3.fromRGB(255, 190, 64) },
	SHEEP = { Color3.fromRGB(240, 240, 240), Color3.fromRGB(180, 180, 180) },
}

-- Generated items: id -> { mobType = "ZOMBIE", name = "Zombie Spawn Egg", colors = {primary, secondary} }
SpawnEggConfig.Items = {}
-- Reverse lookup: mobType -> id
SpawnEggConfig.MobToEggId = {}

do
	local nextId = EGG_ID_START
	for mobType, def in pairs(MobRegistry.Definitions) do
		-- Skip generating a spawn egg for stationary minions
		if mobType == "COBBLE_MINION" then
			continue
		end
		local display = def.displayName or tostring(mobType)
		local override = COLOR_OVERRIDES[mobType]
		local primary, secondary = override and override[1], override and override[2]
		if not primary or not secondary then
			primary, secondary = defaultColorsForMob(mobType)
		end
		SpawnEggConfig.Items[nextId] = {
			mobType = mobType,
			name = string.format("%s Spawn Egg", display),
			colors = {
				primary = primary,
				secondary = secondary,
			}
		}
		SpawnEggConfig.MobToEggId[mobType] = nextId
		nextId += 1
	end
end

function SpawnEggConfig.IsSpawnEgg(itemId)
	return SpawnEggConfig.Items[tonumber(itemId)] ~= nil
end

function SpawnEggConfig.GetEggInfo(itemId)
	return SpawnEggConfig.Items[tonumber(itemId)]
end

function SpawnEggConfig.GetEggIdForMob(mobType)
	return SpawnEggConfig.MobToEggId[mobType]
end

function SpawnEggConfig.GetAllEggItemIds()
	local ids = {}
	for id, _ in pairs(SpawnEggConfig.Items) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return SpawnEggConfig


