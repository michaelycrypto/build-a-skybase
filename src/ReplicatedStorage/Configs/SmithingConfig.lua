--[[
	SmithingConfig.lua
	Configuration for the smithing mini-game (Anvil workstation)

	Temperature gauge settings, difficulty scaling per material tier,
	and efficiency calculations for the anvil system.
	
	Note: This is the advanced crafting system that was previously
	tied to the furnace. Now it operates on the Anvil block.
]]

local SmithingConfig = {}

-- Temperature gauge settings
SmithingConfig.Gauge = {
	MIN = 0,
	MAX = 100,
	START_POSITION = 40,   -- Start closer to center for easier initial positioning
	HEAT_RATE = 32,        -- Units per second when holding (slower for better control)
	COOL_RATE = 24,        -- Units per second when released (slower for smoother gameplay)
}

-- Zone drift boundaries
SmithingConfig.ZoneDrift = {
	MIN = 30,   -- Zone doesn't go too far to edges
	MAX = 70,
}

-- Difficulty settings per ore tier
-- [oreTier] = {zoneWidth, driftSpeed, smeltTime, baseCoal}
SmithingConfig.Difficulty = {
	[1] = { zoneWidth = 34, driftSpeed = 4,  smeltTime = 3,  baseCoal = 1 },  -- Copper (very easy, tutorial)
	[2] = { zoneWidth = 30, driftSpeed = 6,  smeltTime = 4,  baseCoal = 1 },  -- Iron (easy)
	[3] = { zoneWidth = 26, driftSpeed = 8,  smeltTime = 5,  baseCoal = 2 },  -- Steel (moderate)
	[4] = { zoneWidth = 22, driftSpeed = 11, smeltTime = 6,  baseCoal = 3 },  -- Bluesteel (challenging)
}

-- Efficiency tiers (sorted by threshold descending)
SmithingConfig.Efficiency = {
	{ threshold = 90, multiplier = 0.70, rating = "Perfect", color = Color3.fromRGB(100, 255, 100) },
	{ threshold = 75, multiplier = 0.85, rating = "Great",   color = Color3.fromRGB(180, 255, 100) },
	{ threshold = 60, multiplier = 1.00, rating = "Good",    color = Color3.fromRGB(255, 255, 100) },
	{ threshold = 40, multiplier = 1.15, rating = "Fair",    color = Color3.fromRGB(255, 180, 100) },
	{ threshold = 0,  multiplier = 1.30, rating = "Poor",    color = Color3.fromRGB(255, 100, 100) },
}

-- Progress rates
SmithingConfig.Progress = {
	IN_ZONE_RATE = 1.0,       -- Full speed in optimal zone
	OUT_OF_ZONE_MIN = 0.1,    -- Minimum progress rate outside zone
	OUT_OF_ZONE_FALLOFF = 0.5 -- Starting rate at zone edge
}

-- Countdown tuning
SmithingConfig.Countdown = {
	IDLE_MULTIPLIER = 1.7 -- No interaction takes 70% longer than active smelting
}

-- Recipe to tier mapping (must match recipe IDs in RecipeConfig)
-- Note: Copper and Iron are now handled by the simple Furnace
-- Anvil handles advanced alloys that require skill
SmithingConfig.RecipeTiers = {
	smith_steel = 1,      -- Steel from Iron Ingot (beginner smithing)
	smith_bluesteel = 2,  -- Bluesteel from Iron + Dust (advanced)
}

-- Maximum interaction distance (studs)
SmithingConfig.MAX_INTERACTION_DISTANCE = 18 -- 6 blocks * 3 studs

--[[
	Get difficulty settings for a recipe
	@param recipeId: string - Recipe identifier
	@return: table - {zoneWidth, driftSpeed, smeltTime, baseCoal} or nil
]]
function SmithingConfig:GetDifficulty(recipeId)
	local tier = self.RecipeTiers[recipeId]
	if not tier then
		return nil
	end
	return self.Difficulty[tier]
end

--[[
	Get tier for a recipe
	@param recipeId: string - Recipe identifier
	@return: number - Tier (1-6) or nil
]]
function SmithingConfig:GetTier(recipeId)
	return self.RecipeTiers[recipeId]
end

--[[
	Calculate progress rate based on indicator position relative to zone
	@param indicator: number - Current temperature indicator position
	@param zoneCenter: number - Center of optimal zone
	@param zoneWidth: number - Width of optimal zone
	@return: number - Progress rate multiplier (0.1 to 1.0)
]]
function SmithingConfig:GetProgressRate(indicator, zoneCenter, zoneWidth)
	local zoneMin = zoneCenter - (zoneWidth / 2)
	local zoneMax = zoneCenter + (zoneWidth / 2)

	if indicator >= zoneMin and indicator <= zoneMax then
		-- In optimal zone: full speed
		return self.Progress.IN_ZONE_RATE
	else
		-- Outside zone: reduced speed (not zero - prevents frustration)
		local distance = 0
		if indicator < zoneMin then
			distance = zoneMin - indicator
		else
			distance = indicator - zoneMax
		end
		-- Falloff: 50% speed at edge, down to 10% at extremes
		return math.max(self.Progress.OUT_OF_ZONE_MIN, self.Progress.OUT_OF_ZONE_FALLOFF - (distance / 100))
	end
end

--[[
	Calculate efficiency rating based on time spent in zone
	@param timeInZone: number - Total time indicator was in optimal zone
	@param totalTime: number - Total smelting time
	@return: table - {multiplier, rating, color}
]]
function SmithingConfig:CalculateEfficiency(timeInZone, totalTime)
	if totalTime <= 0 then
		return self.Efficiency[#self.Efficiency] -- Return "Poor" if no time
	end

	local zonePercentage = (timeInZone / totalTime) * 100

	for _, tier in ipairs(self.Efficiency) do
		if zonePercentage >= tier.threshold then
			return tier
		end
	end

	return self.Efficiency[#self.Efficiency] -- Fallback to "Poor"
end

--[[
	Calculate actual coal cost based on base coal and efficiency
	@param baseCoal: number - Base coal cost from recipe
	@param efficiencyMultiplier: number - Efficiency multiplier (0.7 to 1.3)
	@return: number - Actual coal to consume (minimum 1)
]]
function SmithingConfig:CalculateCoalCost(baseCoal, efficiencyMultiplier)
	local adjustedCost = baseCoal * efficiencyMultiplier
	return math.max(1, math.ceil(adjustedCost))
end

--[[
	Check if a recipe requires anvil (smithing)
	@param recipe: table - Recipe from RecipeConfig
	@return: boolean
]]
function SmithingConfig:RequiresAnvil(recipe)
	return recipe and recipe.requiresAnvil == true
end

return SmithingConfig

