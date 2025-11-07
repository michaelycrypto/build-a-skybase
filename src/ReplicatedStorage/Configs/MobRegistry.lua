--[[
	MobRegistry.lua

	Central definition table for all mob types supported by the new mob entity system.
	Provides stats, spawn rules, drop tables, model specs and helper accessors.
--]]

local MobRegistry = {}

MobRegistry.Categories = {
	PASSIVE = "PASSIVE",
	HOSTILE = "HOSTILE",
	NEUTRAL = "NEUTRAL"
}

MobRegistry.SpawnCaps = {
	PASSIVE = 12,
	HOSTILE = 55,
	AMBIENT = 15,
	WATER = 6
}

local ConstantsModule = game.ReplicatedStorage.Shared.VoxelWorld.Core.Constants
local Constants = require(ConstantsModule)
local BLOCK_SIZE = Constants.BLOCK_SIZE
local MinecraftBoneTranslator = require(game.ReplicatedStorage.Shared.Mobs.MinecraftBoneTranslator)

local function studs(pixels)
	-- Minecraft mobs are authored at 16 pixels per block. Convert pixels to Roblox studs using block size.
	return (pixels / 16) * BLOCK_SIZE
end

local function pixels(px)
	return studs(px)
end

local function blocks(blocksValue)
	return blocksValue * BLOCK_SIZE
end


MobRegistry.Definitions = {
	SHEEP = {
		id = "SHEEP",
		displayName = "Sheep",
		category = MobRegistry.Categories.PASSIVE,
		maxHealth = 8,
		baseDamage = 0,
		walkSpeed = 4,
		runSpeed = 7,
		turnRateDegPerSec = 220,  -- Sheep rotate faster for more agile feel
		useAdvancedPathfinding = true,  -- Enable Minecraft-style advanced pathfinding
		attackCooldown = 0,
		attackRange = 0,
		aggroRange = 0,
		wanderRadius = blocks(8),
		wanderInterval = { min = 5, max = 12 },  -- Idle duration in seconds between wander points
		fleeDistance = 0,  -- Sheep do not flee players in Minecraft; they only panic when hurt
		panicDuration = 5,  -- Seconds to panic after taking damage
		-- Tempt items: use Birch Sapling for testing (block item id)
		temptItems = { Constants.BlockType.BIRCH_SAPLING },
		temptDistance = blocks(10),  -- Distance to detect tempting items
		tamed = false,
		spawnRules = {
			biomes = { "PLAINS", "FOREST", "SKYBLOCK" },
			lightLevel = { min = 8, max = 15 },
			groundBlocks = { "GRASS", "DIRT" },
			packSize = { min = 1, max = 3 },
			chance = 0.35
		},
		drops = {
			{ itemId = "WOOL_WHITE", min = 1, max = 1, chance = 1.0 },
			{ itemId = "RAW_MUTTON", min = 1, max = 2, chance = 0.75 }
		},
		variants = {
			{ id = "white", weight = 10, woolColor = Color3.fromRGB(241, 241, 241) },
			{ id = "light_gray", weight = 3, woolColor = Color3.fromRGB(167, 167, 167) },
			{ id = "gray", weight = 2, woolColor = Color3.fromRGB(105, 105, 105) },
			{ id = "black", weight = 1, woolColor = Color3.fromRGB(25, 25, 25) },
			{ id = "brown", weight = 1, woolColor = Color3.fromRGB(154, 110, 77) },
			{ id = "pink", weight = 0.1, woolColor = Color3.fromRGB(249, 128, 122) }
		},
		model = MinecraftBoneTranslator.BuildSheepModel(0.9)
	},
	ZOMBIE = {
		id = "ZOMBIE",
		displayName = "Zombie",
		category = MobRegistry.Categories.HOSTILE,
		maxHealth = 20,
		baseDamage = 3,
		walkSpeed = 4,
		runSpeed = 6.5,
		attackCooldown = 1.5,
		attackRange = blocks(2),
		aggroRange = blocks(20),
		useAdvancedPathfinding = true,
		wanderRadius = blocks(6),
		wanderInterval = { min = 6, max = 11 },
		fleeDistance = 0,
		spawnRules = {
			biomes = { "ANY" },
			lightLevel = { min = 0, max = 7 },
			groundBlocks = { "ANY" },
			packSize = { min = 1, max = 2 },
			chance = 0.4
		},
		drops = {
			{ itemId = "ROTTEN_FLESH", min = 0, max = 2, chance = 1.0 },
			{ itemId = "IRON_INGOT", min = 1, max = 1, chance = 0.05 }
		},
		variants = {
			{ id = "default", weight = 1, skinColor = Color3.fromRGB(111, 170, 79) }
		},
		model = MinecraftBoneTranslator.BuildZombieModel(1),
		-- Minecraft hitbox: 0.6w x 1.95h x 0.6d blocks
		collider = {
			size = Vector3.new(studs(0.6), studs(1.95), studs(0.6)),
			cframe = CFrame.new(0, studs(1.95) / 2, 0)
		}
	},
	COW = {
		id = "COW",
		displayName = "Cow",
		category = MobRegistry.Categories.PASSIVE,
		maxHealth = 10,
		baseDamage = 0,
		walkSpeed = 4,
		runSpeed = 6,
		turnRateDegPerSec = 180,
		useAdvancedPathfinding = true,
		attackCooldown = 0,
		attackRange = 0,
		aggroRange = 0,
		wanderRadius = blocks(8),
		wanderInterval = { min = 5, max = 12 },
		fleeDistance = 0,
		panicDuration = 5,
		-- Tempt with wheat (block sapling for now as placeholder)
		temptItems = { Constants.BlockType.OAK_SAPLING },
		temptDistance = blocks(10),
		tamed = false,
		spawnRules = {
			biomes = { "PLAINS", "FOREST", "SKYBLOCK" },
			lightLevel = { min = 8, max = 15 },
			groundBlocks = { "GRASS", "DIRT" },
			packSize = { min = 2, max = 4 },
			chance = 0.3
		},
		drops = {
			{ itemId = "RAW_BEEF", min = 1, max = 3, chance = 1.0 },
			{ itemId = "LEATHER", min = 0, max = 2, chance = 1.0 }
		},
		variants = {
			-- Classic black and white spotted cow
			{ id = "black_white", weight = 10, bodyColor = Color3.fromRGB(255, 255, 255), spotColor = Color3.fromRGB(25, 25, 25) },
			-- Brown cow
			{ id = "brown", weight = 5, bodyColor = Color3.fromRGB(95, 72, 53), spotColor = nil },
			-- Red cow (Mooshroom-style, but without mushrooms)
			{ id = "red", weight = 1, bodyColor = Color3.fromRGB(166, 29, 29), spotColor = nil }
		},
		model = MinecraftBoneTranslator.BuildCowModel(0.95),
		-- Minecraft hitbox: 0.9w x 1.4h x 0.9d blocks
		collider = {
			size = Vector3.new(studs(0.9), studs(1.4), studs(0.9)),
			cframe = CFrame.new(0, studs(1.4) / 2, 0)
		}
	},
	CHICKEN = {
		id = "CHICKEN",
		displayName = "Chicken",
		category = MobRegistry.Categories.PASSIVE,
		maxHealth = 4,
		baseDamage = 0,
		walkSpeed = 4,
		runSpeed = 6,
		turnRateDegPerSec = 240,  -- Chickens are agile
		useAdvancedPathfinding = false,  -- Chickens use simple wandering
		attackCooldown = 0,
		attackRange = 0,
		aggroRange = 0,
		wanderRadius = blocks(6),
		wanderInterval = { min = 3, max = 8 },
		fleeDistance = 0,
		panicDuration = 4,
		-- Tempt with seeds (use sapling as placeholder)
		temptItems = { Constants.BlockType.OAK_SAPLING },
		temptDistance = blocks(8),
		tamed = false,
		spawnRules = {
			biomes = { "PLAINS", "FOREST", "SKYBLOCK" },
			lightLevel = { min = 8, max = 15 },
			groundBlocks = { "GRASS", "DIRT" },
			packSize = { min = 2, max = 4 },
			chance = 0.35
		},
		drops = {
			{ itemId = "RAW_CHICKEN", min = 1, max = 1, chance = 1.0 },
			{ itemId = "FEATHER", min = 0, max = 2, chance = 1.0 }
		},
		variants = {
			-- White chicken (most common)
			{ id = "white", weight = 10, bodyColor = Color3.fromRGB(255, 255, 255) },
			-- Brown chicken
			{ id = "brown", weight = 5, bodyColor = Color3.fromRGB(139, 90, 43) },
			-- Black chicken
			{ id = "black", weight = 2, bodyColor = Color3.fromRGB(45, 45, 45) }
		},
		model = MinecraftBoneTranslator.BuildChickenModel(0.95),
		-- Minecraft hitbox: 0.4w x 0.7h x 0.4d blocks
		collider = {
			size = Vector3.new(studs(0.4), studs(0.7), studs(0.4)),
			cframe = CFrame.new(0, studs(0.7) / 2, 0)
		}
	}
}

local totalVariantWeights = {}

for mobType, def in pairs(MobRegistry.Definitions) do
	local total = 0
	if def.variants then
		for _, variant in ipairs(def.variants) do
			total += variant.weight or 1
		end
	end
	totalVariantWeights[mobType] = total
end

function MobRegistry:GetDefinition(mobType)
	return self.Definitions[mobType]
end

function MobRegistry:GetSpawnCap(category)
	return self.SpawnCaps[category] or 0
end

function MobRegistry:GetRandomVariant(mobType, randomGenerator)
	local def = self.Definitions[mobType]
	if not def or not def.variants or #def.variants == 0 then
		return nil
	end
	local total = totalVariantWeights[mobType] or 1
	local rng = randomGenerator or Random.new()
	local roll = rng:NextNumber(0, total)
	local cumulative = 0
	for _, variant in ipairs(def.variants) do
		cumulative += variant.weight or 1
		if roll <= cumulative then
			return variant
		end
	end
	return def.variants[#def.variants]
end

function MobRegistry:SerializeMob(mob)
	return {
		entityId = mob.entityId,
		mobType = mob.mobType,
		position = { mob.position.X, mob.position.Y, mob.position.Z },
		velocity = { mob.velocity.X, mob.velocity.Y, mob.velocity.Z },
		health = mob.health,
		chunkX = mob.chunkX,
		chunkZ = mob.chunkZ,
		variant = mob.variant and mob.variant.id or nil,
		state = mob.state,
		metadata = mob.metadata or {}
	}
end

return MobRegistry


