--[[
	SkyblockGenerator.lua

	Player-owned sky islands: a starter grass island with a tree + chest and a
	secondary rocky portal island. The generator supports a data-driven template
	system so new island types can be added without touching the core logic.
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BaseWorldGenerator = require(script.Parent.BaseWorldGenerator)
local IslandUtils = require(script.Parent.IslandUtils)

local SkyblockGenerator = BaseWorldGenerator.extend({})

local BlockType = Constants.BlockType

local LOG_TO_LEAF = {
	[BlockType.WOOD] = BlockType.OAK_LEAVES,
	[BlockType.SPRUCE_LOG] = BlockType.SPRUCE_LEAVES,
	[BlockType.JUNGLE_LOG] = BlockType.JUNGLE_LEAVES,
	[BlockType.DARK_OAK_LOG] = BlockType.DARK_OAK_LEAVES,
	[BlockType.BIRCH_LOG] = BlockType.BIRCH_LEAVES,
	[BlockType.ACACIA_LOG] = BlockType.ACACIA_LEAVES,
}

local function getLeavesForLog(logId)
	return LOG_TO_LEAF[logId] or BlockType.OAK_LEAVES
end

local DEFAULT_PROFILES = {
	micro_starter = {
		domes = {
			{ radius = 4.2, height = 0.9, power = 1.8 },
			{ radius = 3.2, height = -0.2, offsetX = 0.6, offsetZ = -0.4, power = 1.6 },
		},
		maskEllipses = {
			{ radiusX = 4.6, radiusZ = 4.4, strength = 1.0, power = 2.1 },
			{ radiusX = 4.2, radiusZ = 4.8, offsetX = -0.2, offsetZ = 0.3, strength = 0.9, power = 2.0 },
		},
		maskFalloff = { depth = 1.4, power = 2.4 },
		rimNoise = { amplitude = 0.35, scale = 0.32, startRadius = 3.6 },
		rimFracture = { amplitude = 0.25, scale = 0.27, startRadius = 3.4, bias = -0.15 },
		stoneExposureThreshold = 4,
		mantleStoneDepth = 2,
		verticalLayers = {
			{ thickness = 1, blockId = BlockType.GRASS },
			{ thickness = 2, blockId = BlockType.DIRT },
			{ thickness = 2, blockId = BlockType.STONE },
		},
		cliffLayers = {
			{ depth = 0.2, topBlock = BlockType.GRASS, mantleBlock = BlockType.DIRT },
			{ depth = 1.4, topBlock = BlockType.DIRT, mantleBlock = BlockType.DIRT },
			{ depth = 2.8, topBlock = BlockType.DIRT, mantleBlock = BlockType.STONE },
		},
	},
	starter = {
		domes = {
			{ radius = 12, height = 1.2, power = 1.6 },
			{ radius = 7, height = 0.6, offsetX = -2, offsetZ = 1, power = 1.5 },
			{ radius = 5, height = -0.3, offsetX = 3, offsetZ = -2, power = 1.3 },
		},
		maskEllipses = {
			{ radiusX = 15, radiusZ = 12, strength = 1.0, power = 1.4 },
			{ radiusX = 13, radiusZ = 15, offsetX = 2, offsetZ = -1, strength = 0.85, power = 1.3 },
		},
		maskFalloff = { depth = 3.2, power = 2.0 },
		prongs = {
			count = 3,
			amplitude = 0.6,
			innerRadiusFactor = 0.55,
			falloff = 2.0,
			phaseOffset = 0.35,
			noiseScale = 0.05,
			noiseWeight = 0.35,
			blend = 0.75,
		},
		rimNoise = { amplitude = 1.2, scale = 0.18, startRadius = 13 },
		rimFracture = { amplitude = 1.4, scale = 0.11, startRadius = 12, bias = -0.1 },
		undersideWarp = { amplitude = 1.8, scale = 0.08, rimWidth = 5, power = 1.2 },
		stoneExposureThreshold = 3,
		mantleStoneDepth = 1.5,
		verticalLayers = {
			{ thickness = 1, blockId = BlockType.GRASS },
			{ thickness = 2, blockId = BlockType.DIRT },
			{ thickness = 4, blockId = BlockType.STONE },
		},
		cliffLayers = {
			{ depth = 0.3, topBlock = BlockType.GRASS, mantleBlock = BlockType.DIRT },
			{ depth = 2.0, topBlock = BlockType.DIRT, mantleBlock = BlockType.DIRT },
			{ depth = 4.0, topBlock = BlockType.STONE, mantleBlock = BlockType.STONE },
		},
		cliffStrata = {
			{ blockId = BlockType.STONE, thickness = 3 },
			{ blockId = BlockType.COBBLESTONE, thickness = 2 },
		},
		strataStart = 6,
	},
	portal = {
		domes = {
			{ radius = 7, height = 0.4, power = 1.8 },
			{ radius = 5, height = -0.3, offsetX = 1, offsetZ = -0.5, power = 1.4 },
		},
		maskEllipses = {
			{ radiusX = 10, radiusZ = 8, strength = 1.0, power = 1.6 },
		},
		maskFalloff = { depth = 2.4, power = 1.7 },
		rimNoise = { amplitude = 0.9, scale = 0.22, startRadius = 7 },
		rimFracture = { amplitude = 0.7, scale = 0.13, startRadius = 7, bias = 0.05 },
		undersideWarp = { amplitude = 1.6, scale = 0.09, rimWidth = 4, power = 1.4 },
		stoneExposureThreshold = 1,
		forceStoneSupport = true,
		verticalLayers = {
			{ thickness = 1, blockId = BlockType.COBBLESTONE },
			{ thickness = 3, blockId = BlockType.STONE },
		},
		cliffStrata = {
			{ blockId = BlockType.COBBLESTONE, thickness = 2 },
			{ blockId = BlockType.STONE_BRICKS, thickness = 1 },
		},
		strataStart = 3,
	},
}

local DEFAULT_TEMPLATES = {
	{
		id = "starter_island",
		profile = "micro_starter",
		offsetX = 0,
		offsetZ = 0,
		topRadius = 5.5,
		topY = 65,
		baseTopY = 62,
		depth = 6,
		taper = 0.32,
		decorations = {
			{
				kind = "tree",
				offsetX = 2,
				offsetZ = -2,
				trunkHeight = 4,
				canopyRadius = 1,
				baseOffset = 1,
				logBlockId = BlockType.WOOD,
			},
			{
				kind = "chest",
				offsetX = 2,
				offsetZ = 2,
				raise = 1,
			},
			{
				-- Minecraft-style Nether portal to hub
				kind = "portal",
				offsetX = -3,
				offsetZ = 0,
				baseOffset = 1,
				orientation = "z",
				innerHalfWidth = 1,
				innerHeight = 3,
				frameBlockId = BlockType.OBSIDIAN,
				innerBlockId = BlockType.PURPLE_STAINED_GLASS,
			},
			{
				-- Pre-built 3x3 farmland with water center
				kind = "farmland",
				offsetX = 0,
				offsetZ = 2,
				raise = 0,
				size = 3, -- 3x3 grid
				waterCenter = true,
			},
		},
	},
}

local DEFAULT_CONFIG = {
	originX = 48,
	originZ = 48,
	spawnOffsetY = 2,
	defaults = {
		topRadius = 14,
		topY = 66,
		baseTopY = 63,
		depth = 18,
		taper = 0.32,
	},
}

function SkyblockGenerator.new(seed: number, overrides)
	overrides = overrides or {}

	local self = setmetatable({}, SkyblockGenerator)
	BaseWorldGenerator._init(self, "SkyblockGenerator", seed, overrides)

	self._profiles = IslandUtils.mergeTables(IslandUtils.deepCopy(DEFAULT_PROFILES), overrides.profiles or {})
	self._config = IslandUtils.mergeTables(IslandUtils.deepCopy(DEFAULT_CONFIG), overrides.config or {})

	local templates = {}
	for _, template in ipairs(DEFAULT_TEMPLATES) do
		table.insert(templates, IslandUtils.deepCopy(template))
	end
	if overrides.templates then
		for _, template in ipairs(overrides.templates) do
			table.insert(templates, IslandUtils.deepCopy(template))
		end
	end

	self._templates = templates
	self._islands = self:_materializeIslands(templates)
	self._decorPlans = self:_planDecorations()
	self._spawnPosition = self:_computeSpawnPosition()

	return self
end

function SkyblockGenerator:_materializeIslands(templates)
	local islands = {}
	self._islandIndexById = {}

	for index, template in ipairs(templates) do
		local descriptor = IslandUtils.deepCopy(template)
		descriptor.id = descriptor.id or ("island_" .. index)
		descriptor.profileId = descriptor.profile or "starter"
		descriptor.centerX = descriptor.centerX or (self._config.originX + (descriptor.offsetX or 0))
		descriptor.centerZ = descriptor.centerZ or (self._config.originZ + (descriptor.offsetZ or 0))
		descriptor.topRadius = descriptor.topRadius or self._config.defaults.topRadius
		descriptor.topY = descriptor.topY or self._config.defaults.topY
		descriptor.baseTopY = descriptor.baseTopY or (descriptor.topY - 2)
		descriptor.depth = descriptor.depth or self._config.defaults.depth
		descriptor.taper = descriptor.taper or self._config.defaults.taper
		descriptor.noise = descriptor.noise or {
			scale = 0.18,
			amplitude = 0.2,
			seed = (self.seed or 0) + index * 97,
		}
		islands[index] = descriptor
		self._islandIndexById[descriptor.id] = descriptor
	end

	return islands
end

function SkyblockGenerator:_getIslandById(id)
	return self._islandIndexById and self._islandIndexById[id] or nil
end

function SkyblockGenerator:_planDecorations()
	local plans = {
		trees = {},
		chests = {},
		portals = {},
		farmlands = {},
	}

	for _, template in ipairs(self._templates) do
		local island = self:_getIslandById(template.id)
		if island and template.decorations then
			for _, decoration in ipairs(template.decorations) do
				local wx = island.centerX + (decoration.offsetX or 0)
				local wz = island.centerZ + (decoration.offsetZ or 0)
				local surface = self:_getSurfaceInfo(wx, wz, island)
				if surface then
					if decoration.kind == "tree" then
						table.insert(plans.trees, {
							wx = wx,
							wz = wz,
							baseY = surface.surfaceY + (decoration.baseOffset or 0),
							logBlockId = decoration.logBlockId or BlockType.WOOD,
							trunkHeight = math.max(decoration.trunkHeight or 5, 3),
							canopyRadius = math.max(decoration.canopyRadius or 2, 2),
						})
					elseif decoration.kind == "chest" then
						table.insert(plans.chests, {
							wx = wx,
							wz = wz,
							y = surface.surfaceY + (decoration.raise or 1),
							blockId = decoration.blockId or BlockType.CHEST,
						})
					elseif decoration.kind == "portal" then
						table.insert(plans.portals, {
							centerX = wx,
							centerZ = wz,
							baseY = surface.surfaceY + (decoration.baseOffset or 1),
							orientation = decoration.orientation or "z",
							innerHalfWidth = math.max(decoration.innerHalfWidth or 1, 1),
							innerHeight = math.max(decoration.innerHeight or 3, 2),
							frameBlockId = decoration.frameBlockId or BlockType.STONE_BRICKS,
							innerBlockId = decoration.innerBlockId or BlockType.GLASS,
						})
					elseif decoration.kind == "farmland" then
						table.insert(plans.farmlands, {
							centerX = wx,
							centerZ = wz,
							y = surface.surfaceY + (decoration.raise or 0),
							size = decoration.size or 3,
							waterCenter = decoration.waterCenter or false,
						})
					end
				end
			end
		end
	end

	return plans
end

function SkyblockGenerator:_getProfile(island)
	return self._profiles[island.profileId] or self._profiles.starter
end

function SkyblockGenerator:_computeSpawnPosition()
	local mainIsland = self._islands and self._islands[1]
	if not mainIsland then
		return Vector3.new(0, (self._config.defaults.topY + self._config.spawnOffsetY) * Constants.BLOCK_SIZE, 0)
	end

	local surface = self:_getSurfaceInfo(mainIsland.centerX, mainIsland.centerZ, mainIsland)
	local topY = surface and surface.surfaceY or mainIsland.topY
	local spawnY = topY + (self._config.spawnOffsetY or 2)

	return Vector3.new(
		mainIsland.centerX * Constants.BLOCK_SIZE,
		spawnY * Constants.BLOCK_SIZE,
		mainIsland.centerZ * Constants.BLOCK_SIZE
	)
end

function SkyblockGenerator:_getSurfaceInfo(wx: number, wz: number, island)
	local profile = self:_getProfile(island)
	return self:_computeSimpleIslandSurface(wx, wz, island, profile)
end

function SkyblockGenerator:GetBlockAt(wx: number, wy: number, wz: number): number
	for _, island in ipairs(self._islands) do
		local topY = island.topY
		local bottomY = topY - island.depth
		if wy >= bottomY and wy <= topY then
			local info = self:_getSurfaceInfo(wx, wz, island)
			if info then
				local depthFromTop = info.surfaceY - wy
				if depthFromTop >= 0 then
					local blockId
					if info.layerProfile then
						blockId = self:_getLayeredBlock(info, depthFromTop)
					elseif depthFromTop == 0 then
						blockId = info.topBlock
					elseif depthFromTop <= 2 then
						blockId = info.mantleBlock or info.topBlock
					else
						blockId = info.bodyBlock or BlockType.STONE
					end

					return self:_applyCliffStrataBlock(info.strataConfig, depthFromTop, blockId)
				end
			end
		end
	end

	return BlockType.AIR
end

function SkyblockGenerator:PostProcessChunk(chunk, chunkWorldX, chunkWorldZ)
	self:_placeTrees(chunk, chunkWorldX, chunkWorldZ)
	self:_placeChests(chunk, chunkWorldX, chunkWorldZ)
	self:_placePortals(chunk, chunkWorldX, chunkWorldZ)
	self:_placeFarmlands(chunk, chunkWorldX, chunkWorldZ)
end

function SkyblockGenerator:_placeTrees(chunk, chunkWorldX, chunkWorldZ)
	for _, tree in ipairs(self._decorPlans.trees or {}) do
		local radius = tree.canopyRadius + 1
		if tree.wx + radius >= chunkWorldX and tree.wx - radius <= (chunkWorldX + Constants.CHUNK_SIZE_X - 1) and
			tree.wz + radius >= chunkWorldZ and tree.wz - radius <= (chunkWorldZ + Constants.CHUNK_SIZE_Z - 1) then

			for dy = 0, tree.trunkHeight - 1 do
				self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, tree.wx, tree.baseY + dy, tree.wz, tree.logBlockId)
			end

			local function placeLeaf(dx, dy, dz, skipTrunk)
				if skipTrunk and dx == 0 and dz == 0 then
					return
				end
				self:_setChunkBlockAndHeight(
					chunk,
					chunkWorldX,
					chunkWorldZ,
					tree.wx + dx,
					tree.baseY + dy,
					tree.wz + dz,
					getLeavesForLog(tree.logBlockId)
				)
			end

			for dx = -2, 2 do
				for dz = -2, 2 do
					if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
						placeLeaf(dx, 3, dz, true)
					end
				end
			end

			for dx = -2, 2 do
				for dz = -2, 2 do
					if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
						placeLeaf(dx, 4, dz, true)
					end
				end
			end

			for dx = -1, 1 do
				for dz = -1, 1 do
					placeLeaf(dx, 5, dz, false)
				end
			end
		end
	end
end

function SkyblockGenerator:_placeChests(chunk, chunkWorldX, chunkWorldZ)
	for _, chest in ipairs(self._decorPlans.chests or {}) do
		local lx = chest.wx - chunkWorldX
		local lz = chest.wz - chunkWorldZ
		if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
			self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, chest.wx, chest.y, chest.wz, chest.blockId)
		end
	end
end

function SkyblockGenerator:_placePortals(chunk, chunkWorldX, chunkWorldZ)
	for _, portal in ipairs(self._decorPlans.portals or {}) do
		local halfOuter = portal.innerHalfWidth + 1
		local outerHeight = portal.innerHeight + 2
		for offset = -halfOuter, halfOuter do
			for dy = 0, outerHeight - 1 do
				local wx = portal.centerX
				local wz = portal.centerZ
				if portal.orientation == "x" then
					wz = portal.centerZ + offset
				else
					wx = portal.centerX + offset
				end
				local wy = portal.baseY + dy
				local isSide = (offset == -halfOuter) or (offset == halfOuter)
				local isTopOrBottom = (dy == 0) or (dy == outerHeight - 1)
				if isSide or isTopOrBottom then
					self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, wy, wz, portal.frameBlockId)
				elseif math.abs(offset) <= portal.innerHalfWidth and dy >= 1 and dy <= portal.innerHeight then
					self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, wy, wz, portal.innerBlockId)
				end
			end
		end
	end
end

function SkyblockGenerator:_placeFarmlands(chunk, chunkWorldX, chunkWorldZ)
	for _, farm in ipairs(self._decorPlans.farmlands or {}) do
		local halfSize = math.floor(farm.size / 2)
		for dx = -halfSize, halfSize do
			for dz = -halfSize, halfSize do
				local wx = farm.centerX + dx
				local wz = farm.centerZ + dz
				local lx = wx - chunkWorldX
				local lz = wz - chunkWorldZ
				if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
					-- Water in center if enabled
					if farm.waterCenter and dx == 0 and dz == 0 then
						self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, farm.y, wz, BlockType.WATER_SOURCE)
					else
						self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, farm.y, wz, BlockType.FARMLAND)
					end
				end
			end
		end
	end
end

function SkyblockGenerator:_computeSimpleIslandSurface(wx: number, wz: number, island, config)
	config = config or {}
	local warpX, warpZ = self:_applyDomainWarp(wx, wz, config)
	local dx = warpX - island.centerX
	local dz = warpZ - island.centerZ
	local dist = math.sqrt(dx * dx + dz * dz)
	local outerRadius = config.outerRadius or island.topRadius or 16
	if dist > outerRadius + 4 then
		return nil
	end

	local maskValue, rimFactor = self:_sampleMask(config, warpX, warpZ, island, dist, outerRadius)
	if maskValue <= 0 and dist > outerRadius then
		return nil
	end

	local surfaceY = island.topY
	surfaceY += self:_sampleIslandDomes(config, warpX, warpZ, island)
	surfaceY += self:_sampleProngs(config, dx, dz, dist, outerRadius, maskValue)

	local falloffConfig = config.maskFalloff or {}
	local falloffDepth = falloffConfig.depth or 5
	local falloffPower = falloffConfig.power or 1.7
	local slope = math.max(0, 1 - maskValue)
	surfaceY -= math.pow(slope, falloffPower) * falloffDepth

	local rimDist = math.max(0, rimFactor) * outerRadius
	surfaceY -= self:_sampleRimNoise(config, wx, wz, rimDist, outerRadius)
	surfaceY -= self:_sampleRimFracture(config, wx, wz, rimDist, outerRadius)
	surfaceY -= self:_sampleUndersideWarp(config, wx, wz, rimDist, outerRadius)

	surfaceY = math.clamp(surfaceY, island.baseTopY - island.depth, island.topY)
	surfaceY = math.floor(surfaceY + 0.5)

	local depthBelowTop = (island.topY or surfaceY) - surfaceY
	local stoneThreshold = config.stoneExposureThreshold or 3
	local topBlock = config.topBlock or BlockType.GRASS
	local mantleBlock = config.mantleBlock or BlockType.DIRT
	local bodyBlock = config.bodyBlock or BlockType.STONE
	local stoneMantleDepth = config.mantleStoneDepth or (stoneThreshold * 0.6)
	local customLayers = config.cliffLayers

	if customLayers and #customLayers > 0 then
		table.sort(customLayers, function(a, b)
			return (a.depth or 0) < (b.depth or 0)
		end)
		local layerApplied = false
		for _, layer in ipairs(customLayers) do
			if depthBelowTop >= (layer.depth or 0) then
				topBlock = layer.topBlock or topBlock
				mantleBlock = layer.mantleBlock or mantleBlock
				layerApplied = true
			else
				break
			end
		end
		if not layerApplied and customLayers[1] then
			topBlock = customLayers[1].topBlock or topBlock
			mantleBlock = customLayers[1].mantleBlock or mantleBlock
		end
	else
		if depthBelowTop >= stoneThreshold then
			topBlock = BlockType.STONE
			mantleBlock = BlockType.STONE
		elseif depthBelowTop >= stoneMantleDepth then
			mantleBlock = BlockType.STONE
		end
	end

	if config.forceStoneSupport then
		mantleBlock = BlockType.STONE
	end

	return {
		island = island,
		surfaceY = surfaceY,
		region = "island",
		topBlock = topBlock,
		mantleBlock = mantleBlock,
		bodyBlock = bodyBlock,
		layerProfile = config.verticalLayers,
		strataConfig = config,
	}
end

function SkyblockGenerator:_sampleMask(config, wx, wz, island, dist, outerRadius)
	local ellipses = config.maskEllipses
	local fallback = math.clamp(1 - (dist / math.max(outerRadius, 0.001)), 0, 1)
	local best = fallback

	if ellipses then
		for _, ellipse in ipairs(ellipses) do
			best = math.max(best, self:_evaluateEllipseMask(ellipse, wx, wz, island, outerRadius))
		end
	end

	best = math.clamp(best, 0, 1)
	return best, 1 - best
end

function SkyblockGenerator:_evaluateEllipseMask(ellipse, wx, wz, island, outerRadius)
	local dx = wx - (island.centerX + (ellipse.offsetX or 0))
	local dz = wz - (island.centerZ + (ellipse.offsetZ or 0))
	local rotation = ellipse.rotation or 0
	local cosR = math.cos(rotation)
	local sinR = math.sin(rotation)
	local ox = dx * cosR - dz * sinR
	local oz = dx * sinR + dz * cosR
	local rx = math.max(ellipse.radiusX or ellipse.radius or outerRadius, 0.001)
	local rz = math.max(ellipse.radiusZ or ellipse.radius or outerRadius, 0.001)

	local normalized = math.sqrt((ox / rx) ^ 2 + (oz / rz) ^ 2)
	local value = 1 - normalized
	if value <= 0 then
		return 0
	end

	value = math.pow(value, ellipse.power or 1.2)
	return value * (ellipse.strength or 1)
end

function SkyblockGenerator:_getLayeredBlock(info, depthFromLocalTop)
	local profile = info.layerProfile
	if not profile then
		return nil
	end

	if depthFromLocalTop < 0 then
		return BlockType.AIR
	end

	local remaining = depthFromLocalTop
	for _, layer in ipairs(profile) do
		local thickness = math.max(layer.thickness or 1, 1)
		if remaining < thickness then
			local blockId = layer.blockId or info.mantleBlock or info.topBlock
			return self:_applyCliffStrataBlock(info.strataConfig, depthFromLocalTop, blockId)
		end
		remaining -= thickness
	end

	local blockId = info.bodyBlock or BlockType.STONE
	return self:_applyCliffStrataBlock(info.strataConfig, depthFromLocalTop, blockId)
end

function SkyblockGenerator:_applyDomainWarp(wx: number, wz: number, config)
	local warp = config.domainWarp
	if not warp then
		return wx, wz
	end

	local scale = warp.scale or 0.02
	local amplitude = warp.amplitude or 5
	local seed = self.seed or 0

	local offsetX = math.noise(wx * scale, wz * scale, seed + 101) * amplitude
	local offsetZ = math.noise(wx * scale, wz * scale, seed + 205) * amplitude

	return wx + offsetX, wz + offsetZ
end

function SkyblockGenerator:_sampleIslandDomes(config, warpX, warpZ, island)
	local domes = config.domes
	if not domes then
		return 0
	end

	local result = 0
	for _, dome in ipairs(domes) do
		local radius = math.max(dome.radius or 8, 0.001)
		local height = dome.height or 0.5
		local power = dome.power or 2
		local offsetX = dome.offsetX or 0
		local offsetZ = dome.offsetZ or 0

		local dx = warpX - (island.centerX + offsetX)
		local dz = warpZ - (island.centerZ + offsetZ)
		local d = math.sqrt(dx * dx + dz * dz)
		if d <= radius then
			local t = d / radius
			local falloff = math.pow(1 - (t * t), power)
			result += falloff * height
		end
	end

	return result
end

function SkyblockGenerator:_sampleRimNoise(config, wx, wz, dist, outerRadius)
	local rim = config.rimNoise
	if not rim then
		return 0
	end

	local startRadius = rim.startRadius or (outerRadius - 6)
	if dist < startRadius then
		return 0
	end

	local span = math.max(outerRadius - startRadius, 0.001)
	local t = math.clamp((dist - startRadius) / span, 0, 1)
	local scale = rim.scale or 0.2
	local amplitude = rim.amplitude or 2
	local noise = math.noise(wx * scale, wz * scale, (self.seed or 0) + 555)
	return noise * amplitude * t
end

function SkyblockGenerator:_sampleRimFracture(config, wx, wz, dist, outerRadius)
	local fracture = config.rimFracture
	if not fracture then
		return 0
	end

	local startRadius = fracture.startRadius or (outerRadius - 6)
	if dist < startRadius then
		return 0
	end

	local scale = fracture.scale or 0.15
	local amplitude = fracture.amplitude or 2
	local bias = fracture.bias or 0
	local seed = (self.seed or 0) + 9090
	local noise = math.noise(wx * scale, wz * scale, seed) + bias
	if noise <= 0 then
		return 0
	end

	local span = math.max(outerRadius - startRadius, 0.001)
	local t = math.clamp((dist - startRadius) / span, 0, 1)
	return noise * amplitude * t
end

function SkyblockGenerator:_sampleUndersideWarp(config, wx, wz, dist, outerRadius)
	local underside = config.undersideWarp
	if not underside then
		return 0
	end

	local rimWidth = math.max(underside.rimWidth or 5, 0.001)
	local start = math.max(outerRadius - rimWidth, 0)
	if dist < start then
		return 0
	end

	local t = math.clamp((dist - start) / rimWidth, 0, 1) ^ (underside.power or 1.2)
	local scale = underside.scale or 0.08
	local amplitude = underside.amplitude or 2.5
	local noise = math.abs(math.noise(wx * scale, wz * scale, (self.seed or 0) + 7777))
	return noise * amplitude * t
end

function SkyblockGenerator:_sampleProngs(config, dx, dz, dist, outerRadius, maskValue)
	local prongs = config.prongs
	if not prongs or not prongs.count or prongs.count <= 0 then
		return 0
	end

	local amplitude = prongs.amplitude or 2
	if amplitude == 0 then
		return 0
	end

	local angle = math.atan2(dz, dx)
	local seed = self.seed or 0
	local noiseComponent = 0
	if prongs.noiseScale and prongs.noiseScale > 0 then
		noiseComponent = math.noise(dx * prongs.noiseScale, dz * prongs.noiseScale, seed + 888) * (prongs.noiseWeight or 1)
	end

	local wave = math.sin(angle * prongs.count + (prongs.phaseOffset or 0) + noiseComponent)
	local innerRadiusFactor = math.clamp(prongs.innerRadiusFactor or 0.4, 0, 0.95)
	local innerRadius = innerRadiusFactor * outerRadius
	if dist <= innerRadius then
		return amplitude * wave * math.pow(dist / innerRadius, 2)
	end

	local radialSpan = math.max(outerRadius - innerRadius, 0.001)
	local radialInfluence = math.clamp((dist - innerRadius) / radialSpan, 0, 1)
	radialInfluence = 1 - math.pow(radialInfluence, prongs.falloff or 1.1)
	local prongBlend = prongs.blend or 0.5
	local maskMultiplier = math.pow(math.clamp(maskValue or 1, 0, 1), prongBlend)
	return wave * amplitude * radialInfluence * maskMultiplier
end

function SkyblockGenerator:_applyCliffStrataBlock(config, depthFromLocalTop, blockId)
	if not config or not config.cliffStrata or blockId == BlockType.GRASS then
		return blockId
	end

	local startDepth = config.strataStart or config.stoneExposureThreshold or 4
	if depthFromLocalTop < startDepth then
		return blockId
	end

	local strata = config.cliffStrata
	if not strata or #strata == 0 then
		return blockId
	end

	local totalThickness = 0
	for _, entry in ipairs(strata) do
		totalThickness += math.max(entry.thickness or 1, 1)
	end
	if totalThickness <= 0 then
		return blockId
	end

	local offset = depthFromLocalTop - startDepth
	if offset < 0 then
		return blockId
	end

	local cycle = offset % totalThickness
	for _, entry in ipairs(strata) do
		local thickness = math.max(entry.thickness or 1, 1)
		if cycle < thickness then
			return entry.blockId or blockId
		end
		cycle -= thickness
	end

	return blockId
end

function SkyblockGenerator:GetSpawnPosition(): Vector3
	return self._spawnPosition
end

return SkyblockGenerator


