--[[
	HubWorldGenerator.lua

	Hub lobby generator that carves a circular floating plaza with radial
	avenues, inset NPC pads, and satellite islands for portals or seasonal
	features. The layout is loosely inspired by sky-island hubs seen in
	Minecraft lobby builds.
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local BaseWorldGenerator = require(script.Parent.BaseWorldGenerator)
local IslandUtils = require(script.Parent.IslandUtils)

local HubWorldGenerator = BaseWorldGenerator.extend({})

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

local function pickSpecies(speciesList, rng)
	if not speciesList or #speciesList == 0 then
		return nil
	end
	local total = 0
	for _, entry in ipairs(speciesList) do
		total += math.max(entry.weight or 0, 0)
	end
	if total <= 0 then
		return speciesList[1]
	end
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(speciesList) do
		local weight = math.max(entry.weight or 0, 0)
		if weight > 0 then
			if roll <= weight then
				return entry
			end
			roll -= weight
		end
	end
	return speciesList[#speciesList]
end

local DEFAULT_RING_LAYERS = {
	{
		name = "core",
		radius = 12,
		heightOffset = 4,
		topBlock = BlockType.STONE_BRICKS,
		mantleBlock = BlockType.STONE,
	},
	{
		name = "plaza",
		radius = 22,
		heightOffset = 3,
		topBlock = BlockType.STONE_BRICKS,
		mantleBlock = BlockType.STONE,
	},
	{
		name = "market",
		radius = 32,
		heightOffset = 2,
		topBlock = BlockType.OAK_PLANKS,
		mantleBlock = BlockType.OAK_PLANKS,
	},
	{
		name = "feature",
		radius = 44,
		heightOffset = 1,
		topBlock = BlockType.GRASS,
		mantleBlock = BlockType.DIRT,
	},
	{
		name = "cliff",
		radius = 56,
		heightOffset = -1,
		topBlock = BlockType.GRASS,
		mantleBlock = BlockType.DIRT,
	},
	{
		name = "fringe",
		radius = 64,
		heightOffset = -3,
		topBlock = BlockType.GRASS,
		mantleBlock = BlockType.DIRT,
	},
}

local DEFAULT_HUB_CONFIG = {
	CENTER_X = 96,
	CENTER_Z = 96,
	BASE_TOP_Y = 86,
	MAX_TOP_Y = 91,
	ISLAND_DEPTH = 22,
	EDGE_TAPER_PER_LEVEL = 0.35,
	NOISE = {
		surfacePrimaryScale = 0.05,
		surfacePrimaryAmp = 1.1,
		surfaceDetailScale = 0.17,
		surfaceDetailAmp = 0.45,
		edgeScale = 0.18,
		edgeAmplitude = 0.22,
	},
	PATH = {
		count = 6,
		width = 6,
		reach = 52,
		raise = 1.4,
	},
	NPC_PAD = {
		radius = 34,
		width = 8,
		depth = 6,
		platformRaise = 1.2,
		material = BlockType.BRICKS,
	},
	SATELLITES = {
		{ angle = 0, distance = 82, radius = 11, depth = 14, topYOffset = -2 },
		{ angle = math.rad(120), distance = 82, radius = 11, depth = 14, topYOffset = -2 },
		{ angle = math.rad(240), distance = 82, radius = 11, depth = 14, topYOffset = -2 },
	},
	SATELLITE_NOISE = {
		scale = 0.26,
		amplitude = 0.35,
	},
	TREES = {
		enabled = true,
		minSpacing = 7,
		defaultTrunkHeight = 5,
		defaultCanopyRadius = 2,
		layout = {
			{ relativeRadius = 0.55, count = 8, radiusJitter = 1.6, angleJitter = 0.3 },
			{ relativeRadius = 0.75, count = 10, radiusJitter = 2.4, angleJitter = 0.35 },
		},
		species = {
			{ log = BlockType.WOOD, weight = 4 },
			{ log = BlockType.BIRCH_LOG, weight = 2.3 },
			{ log = BlockType.SPRUCE_LOG, weight = 2 },
			{ log = BlockType.ACACIA_LOG, weight = 1.6 },
			{ log = BlockType.DARK_OAK_LOG, weight = 1.4, trunkHeight = 6 },
		},
	},
}

local function evaluateRingLayer(ringLayers, dist: number)
	for i, layer in ipairs(ringLayers) do
		if dist <= layer.radius then
			if i == 1 then
				return layer, layer.heightOffset
			end

			local prev = ringLayers[i - 1]
			local span = math.max(0.0001, layer.radius - prev.radius)
			local t = math.clamp((dist - prev.radius) / span, 0, 1)
			local offset = prev.heightOffset + t * (layer.heightOffset - prev.heightOffset)
			return layer, offset
		end
	end

	return nil, nil
end

function HubWorldGenerator.new(seed: number, overrides)
	overrides = overrides or {}
	local ringLayers = overrides.ringLayers and IslandUtils.deepCopy(overrides.ringLayers) or IslandUtils.deepCopy(DEFAULT_RING_LAYERS)
	local hubConfig = IslandUtils.deepCopy(DEFAULT_HUB_CONFIG)
	if overrides.hubConfig then
		hubConfig = IslandUtils.mergeTables(hubConfig, overrides.hubConfig)
	end

	local self = setmetatable({}, HubWorldGenerator)
	BaseWorldGenerator._init(self, "HubWorldGenerator", seed, overrides)

	self._ringLayers = ringLayers
	self._hubConfig = hubConfig
	self._options = overrides or {}
	self._simpleIsland = overrides.simpleIsland and IslandUtils.deepCopy(overrides.simpleIsland) or nil
	self._hubCenter = {
		x = hubConfig.CENTER_X,
		z = hubConfig.CENTER_Z,
	}
	self._islands = self:_buildIslands()
	self._paths = self:_buildPaths()
	self._npcPads = self:_buildNpcPads()
	self._hubTrees = self:_planHubTrees()

	return self
end

function HubWorldGenerator:_buildIslands()
	local islands = {}
	local ringLayers = self._ringLayers
	local hubConfig = self._hubConfig
	local simpleIsland = self._simpleIsland
	local hubTopRadius = ringLayers[#ringLayers].radius
	if simpleIsland and simpleIsland.outerRadius then
		hubTopRadius = simpleIsland.outerRadius
	end

	table.insert(islands, {
		id = "hub_main",
		kind = "hub_main",
		centerX = self._hubCenter.x,
		centerZ = self._hubCenter.z,
		topRadius = hubTopRadius,
		topY = hubConfig.MAX_TOP_Y,
		baseTopY = hubConfig.BASE_TOP_Y,
		depth = hubConfig.ISLAND_DEPTH,
		taper = (simpleIsland and simpleIsland.bottomTaperPerLevel) or hubConfig.EDGE_TAPER_PER_LEVEL,
		noise = {
			scale = hubConfig.NOISE.edgeScale,
			amplitude = hubConfig.NOISE.edgeAmplitude,
			seed = (self.seed or 0) + 11,
		},
	})

	for idx, sat in ipairs(hubConfig.SATELLITES or {}) do
		local dirX = math.cos(sat.angle)
		local dirZ = math.sin(sat.angle)
		local centerX = math.floor(self._hubCenter.x + dirX * sat.distance + 0.5)
		local centerZ = math.floor(self._hubCenter.z + dirZ * sat.distance + 0.5)

		table.insert(islands, {
			id = "satellite_" .. idx,
			kind = "satellite",
			centerX = centerX,
			centerZ = centerZ,
			topRadius = sat.radius,
			topY = hubConfig.BASE_TOP_Y + sat.topYOffset,
			baseTopY = hubConfig.BASE_TOP_Y + sat.topYOffset,
			depth = sat.depth,
			taper = sat.taper or 0.25,
			noise = {
				scale = hubConfig.SATELLITE_NOISE.scale,
				amplitude = hubConfig.SATELLITE_NOISE.amplitude,
				seed = (self.seed or 0) + 53 + idx * 31,
			},
		})
	end

	return islands
end

function HubWorldGenerator:_buildPaths()
	local descriptors = {}
	if self._simpleIsland then
		return descriptors
	end
	local hubConfig = self._hubConfig
	if self._options.disablePaths then
		return descriptors
	end
	local count = hubConfig.PATH.count
	if not count or count <= 0 then
		return descriptors
	end
	for i = 0, count - 1 do
		local angle = (2 * math.pi / count) * i
		local dirX = math.cos(angle)
		local dirZ = math.sin(angle)
		local perpX = -dirZ
		local perpZ = dirX

		table.insert(descriptors, {
			angle = angle,
			dirX = dirX,
			dirZ = dirZ,
			perpX = perpX,
			perpZ = perpZ,
			halfWidth = hubConfig.PATH.width * 0.5,
			reach = hubConfig.PATH.reach,
			targetY = math.floor(hubConfig.BASE_TOP_Y + hubConfig.PATH.raise + 0.5),
		})
	end

	return descriptors
end

function HubWorldGenerator:_buildNpcPads()
	local pads = {}
	if self._simpleIsland then
		return pads
	end
	if self._options.disableNpcPads then
		return pads
	end
	local hubConfig = self._hubConfig
	for _, path in ipairs(self._paths) do
		local centerX = math.floor(self._hubCenter.x + path.dirX * hubConfig.NPC_PAD.radius + 0.5)
		local centerZ = math.floor(self._hubCenter.z + path.dirZ * hubConfig.NPC_PAD.radius + 0.5)
		local surfaceY = self:_calculateHubBaseSurface(centerX, centerZ, false)
		if surfaceY then
			local targetY = math.floor(surfaceY + hubConfig.NPC_PAD.platformRaise + 0.5)
			table.insert(pads, {
				centerX = centerX,
				centerZ = centerZ,
				forwardX = path.dirX,
				forwardZ = path.dirZ,
				rightX = path.perpX,
				rightZ = path.perpZ,
				halfWidth = hubConfig.NPC_PAD.width * 0.5,
				halfDepth = hubConfig.NPC_PAD.depth * 0.5,
				targetY = targetY,
				material = hubConfig.NPC_PAD.material,
			})
		end
	end

	return pads
end

function HubWorldGenerator:_planHubTrees()
	if self._options and self._options.disableHubTrees then
		return {}
	end

	local treeConfig = self._hubConfig and self._hubConfig.TREES
	if not treeConfig or treeConfig.enabled == false then
		return {}
	end

	local layout = treeConfig.layout
	if not layout or #layout == 0 then
		return {}
	end

	local mainIsland = self._islands and self._islands[1]
	if not mainIsland then
		return {}
	end

	local rng = self.rng or Random.new(self.seed or 0)
	local descriptors = {}
	local centerX = self._hubCenter.x
	local centerZ = self._hubCenter.z
	local islandTopRadius = mainIsland.topRadius or 32
	local globalMinSpacing = math.max(treeConfig.minSpacing or 6, 0)
	local globalMinSpacingSq = globalMinSpacing * globalMinSpacing
	local defaultTrunkHeight = math.max(treeConfig.defaultTrunkHeight or 5, 3)
	local defaultCanopyRadius = math.max(treeConfig.defaultCanopyRadius or 2, 2)

	local function isFarEnough(wx, wz, spacingSq)
		local thresholdSq = spacingSq or globalMinSpacingSq
		if thresholdSq <= 0 then
			return true
		end
		for _, tree in ipairs(descriptors) do
			local dx = wx - tree.wx
			local dz = wz - tree.wz
			if (dx * dx + dz * dz) < thresholdSq then
				return false
			end
		end
		return true
	end

	for _, band in ipairs(layout) do
		local count = math.max(band.count or 0, 0)
		if count > 0 then
			local baseRadius = band.radius
			if not baseRadius and band.relativeRadius then
				baseRadius = islandTopRadius * band.relativeRadius
			end
			baseRadius = baseRadius or (islandTopRadius * 0.7)
			baseRadius = math.clamp(baseRadius, 4, islandTopRadius)
			local radius = baseRadius
			local radiusJitter = band.radiusJitter or 0
			local angleJitter = band.angleJitter or 0
			local attemptsPerTree = math.max(band.extraAttempts or 3, 1)
			local spacing = math.max(band.minSpacing or globalMinSpacing, 0)
			local spacingSq = spacing * spacing
			local minRadius = math.max(band.minRadius or 4, 0)
			local maxRadius = band.maxRadius or (islandTopRadius - 1)
			if maxRadius < minRadius then
				maxRadius = minRadius
			end

			for i = 1, count do
				local baseAngle = (2 * math.pi * (i - 1)) / count
				local placed = false
				local attempt = 0

				while not placed and attempt <= attemptsPerTree do
					attempt += 1
					local angle = baseAngle + (rng:NextNumber() - 0.5) * angleJitter
					local dist = radius + (rng:NextNumber() - 0.5) * radiusJitter
					dist = math.clamp(dist, minRadius, maxRadius)
					local wx = math.floor(centerX + math.cos(angle) * dist + 0.5)
					local wz = math.floor(centerZ + math.sin(angle) * dist + 0.5)
					local info = self:_getSurfaceInfo(wx, wz, mainIsland)
					if info and info.surfaceY and info.surfaceY >= 0 then
						local topBlock = info.topBlock
						if (topBlock == BlockType.GRASS or topBlock == BlockType.DIRT) and info.region ~= "path" and info.region ~= "npc_pad" then
							if isFarEnough(wx, wz, spacingSq) then
								local species = pickSpecies(band.species or treeConfig.species, rng)
								if species then
									table.insert(descriptors, {
										wx = wx,
										wz = wz,
										baseY = info.surfaceY,
										logBlockId = species.log or BlockType.WOOD,
										trunkHeight = math.max(species.trunkHeight or defaultTrunkHeight, 3),
										horizontalRadius = math.max(species.canopyRadius or defaultCanopyRadius, 2),
									})
									placed = true
								end
							end
						end
					end
				end
			end
		end
	end

	if self._logger and self._logger.Debug then
		self._logger:Debug(string.format("Planned %d hub trees (layout mode)", #descriptors))
	end

	return descriptors
end

function HubWorldGenerator:_getRadialMetrics(wx: number, wz: number)
	local dx = wx - self._hubCenter.x
	local dz = wz - self._hubCenter.z
	local dist = math.sqrt(dx * dx + dz * dz)

	return {
		dx = dx,
		dz = dz,
		dist = dist,
	}
end

function HubWorldGenerator:_calculateHubBaseSurface(wx: number, wz: number, useNoise: boolean)
	local metrics = self:_getRadialMetrics(wx, wz)
	local layer, offset = evaluateRingLayer(self._ringLayers, metrics.dist)
	if not layer then
		return nil, nil, metrics
	end

	local hubConfig = self._hubConfig
	local baseY = hubConfig.BASE_TOP_Y + offset
	if not useNoise then
		return math.floor(baseY + 0.5), layer, metrics
	end

	local n1 = math.noise(
		wx * hubConfig.NOISE.surfacePrimaryScale,
		wz * hubConfig.NOISE.surfacePrimaryScale,
		(self.seed or 0) + 155
	)
	local n2 = math.noise(
		wx * hubConfig.NOISE.surfaceDetailScale,
		wz * hubConfig.NOISE.surfaceDetailScale,
		(self.seed or 0) + 255
	)

	local noiseFactor = math.clamp(metrics.dist / self._ringLayers[#self._ringLayers].radius, 0.25, 1)
	local noise = (n1 * hubConfig.NOISE.surfacePrimaryAmp + n2 * hubConfig.NOISE.surfaceDetailAmp) * noiseFactor
	local surfaced = math.clamp(baseY + noise, hubConfig.BASE_TOP_Y - 4, hubConfig.MAX_TOP_Y)
	return math.floor(surfaced + 0.5), layer, metrics
end

function HubWorldGenerator:_applyPathOverrides(info, wx: number, wz: number, metrics)
	local hubConfig = self._hubConfig
	if not metrics or metrics.dist > hubConfig.PATH.reach + 4 then
		return
	end

	for _, path in ipairs(self._paths) do
		local along = metrics.dx * path.dirX + metrics.dz * path.dirZ
		if along >= -2 and along <= path.reach then
			local cross = metrics.dx * path.perpX + metrics.dz * path.perpZ
			local jitter = math.noise(wx * 0.07, wz * 0.07, (self.seed or 0) + 77) * 0.5
			if math.abs(cross) <= (path.halfWidth + jitter) then
				local raisedY = math.max(info.surfaceY, path.targetY)
				info.surfaceY = raisedY
				info.topBlock = BlockType.STONE_BRICKS
				info.mantleBlock = BlockType.STONE_BRICKS
				info.bodyBlock = BlockType.STONE
				info.region = "path"
				return
			end
		end
	end
end

function HubWorldGenerator:_applyNpcPadOverrides(info, wx: number, wz: number)
	for _, pad in ipairs(self._npcPads) do
		local dx = wx - pad.centerX
		local dz = wz - pad.centerZ
		local forward = dx * pad.forwardX + dz * pad.forwardZ
		local right = dx * pad.rightX + dz * pad.rightZ
		if math.abs(forward) <= pad.halfDepth and math.abs(right) <= pad.halfWidth then
			info.surfaceY = math.max(info.surfaceY, pad.targetY)
			info.topBlock = pad.material
			info.mantleBlock = pad.material
			info.bodyBlock = BlockType.STONE
			info.region = "npc_pad"
			return
		end
	end
end

function HubWorldGenerator:_applyRockOutcrops(info, wx: number, wz: number, island, _metrics)
	local rockConfig = self._options and self._options.rockOutcrops
	if not rockConfig then
		return
	end

	local scale = rockConfig.scale or 0.08
	local threshold = rockConfig.threshold or 0.25
	local noise = math.noise(wx * scale, wz * scale, (self.seed or 0) + 512)
	if noise < threshold then
		return
	end

	local raise = rockConfig.heightRaise or 2
	info.surfaceY = math.min(info.surfaceY + raise, island.topY)
	local rockBlock = rockConfig.blockId or BlockType.STONE
	info.topBlock = rockBlock
	info.mantleBlock = rockBlock
	info.bodyBlock = BlockType.STONE
	info.region = "rock_outcrop"
end

function HubWorldGenerator:_computeSimpleIslandSurface(wx: number, wz: number, island)
	local config = self._simpleIsland or {}
	local warpX, warpZ = self:_applyDomainWarp(wx, wz, config)
	local dx = warpX - island.centerX
	local dz = warpZ - island.centerZ
	local dist = math.sqrt(dx * dx + dz * dz)
	local outerRadius = config.outerRadius or island.topRadius or 32
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
	surfaceY -= self:_sampleRimNoise(wx, wz, rimDist, outerRadius)
	surfaceY -= self:_sampleRimFracture(wx, wz, rimDist, outerRadius)
	surfaceY -= self:_sampleUndersideWarp(wx, wz, rimDist, outerRadius)

	surfaceY = math.clamp(surfaceY, island.baseTopY - self._hubConfig.ISLAND_DEPTH, island.topY)
	surfaceY = math.floor(surfaceY + 0.5)

	local depthBelowTop = (island.topY or surfaceY) - surfaceY
	local stoneThreshold = config.stoneExposureThreshold or 3
	local topBlock = BlockType.GRASS
	local mantleBlock = BlockType.DIRT
	local stoneMantleDepth = config.mantleStoneDepth or stoneThreshold * 0.6
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
		bodyBlock = BlockType.STONE,
		layerProfile = config.verticalLayers,
		strataConfig = config,
	}
end

function HubWorldGenerator:_sampleMask(config, wx, wz, island, dist, outerRadius)
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

function HubWorldGenerator:_evaluateEllipseMask(ellipse, wx, wz, island, outerRadius)
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

function HubWorldGenerator:_getLayeredBlock(info, depthFromLocalTop)
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

function HubWorldGenerator:_applyDomainWarp(wx: number, wz: number, config)
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

function HubWorldGenerator:_sampleIslandDomes(config, warpX, warpZ, island)
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

function HubWorldGenerator:_sampleFalloffBands(config, dist, outerRadius, dx, dz)
	local bands = config.falloffBands
	if not bands or #bands == 0 then
		bands = {
			{ startRadius = outerRadius * 0.55, endRadius = outerRadius - 4, depth = 1.5, power = 1.4 },
			{ startRadius = outerRadius - 4, endRadius = outerRadius, depth = 4.5, power = 2.1 },
		}
	end

	local total = 0
	for _, band in ipairs(bands) do
		local startR = math.clamp(band.startRadius or 0, 0, outerRadius)
		if startR < outerRadius - 0.001 then
			local desiredEnd = band.endRadius or outerRadius
			local minEnd = startR + 0.001
			local maxEnd = outerRadius
			local endR = math.clamp(desiredEnd, minEnd, maxEnd)
			if endR <= startR then
				endR = startR + 0.001
			end

			local localDist = dist
			if band.stretchX or band.stretchZ then
				local sx = math.max(band.stretchX or 1, 0.05)
				local sz = math.max(band.stretchZ or 1, 0.05)
				localDist = math.sqrt((dx / sx) * (dx / sx) + (dz / sz) * (dz / sz))
			end

			if localDist > startR then
				local span = math.max(endR - startR, 0.001)
				local t = math.clamp((localDist - startR) / span, 0, 1)
				t = t ^ (band.power or 1.2)
				total += t * (band.depth or 1)
			end
		end
	end
	return total
end

function HubWorldGenerator:_sampleRimNoise(wx, wz, dist, outerRadius)
	local rim = self._simpleIsland and self._simpleIsland.rimNoise
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

function HubWorldGenerator:_sampleRimFracture(wx, wz, dist, outerRadius)
	local fracture = self._simpleIsland and self._simpleIsland.rimFracture
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

function HubWorldGenerator:_sampleUndersideWarp(wx, wz, dist, outerRadius)
	local underside = self._simpleIsland and self._simpleIsland.undersideWarp
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

function HubWorldGenerator:_sampleProngs(config, dx, dz, dist, outerRadius, maskValue)
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

function HubWorldGenerator:_getHubSurfaceInfo(wx: number, wz: number, island)
	if self._simpleIsland then
		local info = self:_computeSimpleIslandSurface(wx, wz, island)
		if not info then
			return nil
		end
		return info
	end

	local surfaceY, ringLayer, metrics = self:_calculateHubBaseSurface(wx, wz, true)
	if not surfaceY then
		return nil
	end

	local info = {
		island = island,
		surfaceY = surfaceY,
		region = ringLayer.name,
		topBlock = ringLayer.topBlock,
		mantleBlock = ringLayer.mantleBlock or ringLayer.topBlock,
		bodyBlock = BlockType.STONE,
	}

	self:_applyPathOverrides(info, wx, wz, metrics)
	self:_applyNpcPadOverrides(info, wx, wz)
	self:_applyRockOutcrops(info, wx, wz, island, metrics)

	info.surfaceY = math.clamp(info.surfaceY, island.baseTopY - self._hubConfig.ISLAND_DEPTH, island.topY)
	return info
end

function HubWorldGenerator:_getSatelliteSurfaceInfo(wx: number, wz: number, island)
	local baseTop = island.topY
	local satelliteNoise = self._hubConfig.SATELLITE_NOISE
	local noise = math.noise(
		(wx + island.centerX * 0.15) * satelliteNoise.scale,
		(wz - island.centerZ * 0.12) * satelliteNoise.scale,
		island.noise.seed
	)
	local offset = math.floor(noise * 2 + 0.5)
	local surfaceY = math.clamp(baseTop + offset, baseTop - 2, baseTop + 1)

	return {
		island = island,
		surfaceY = surfaceY,
		region = island.id,
		topBlock = BlockType.GRASS,
		mantleBlock = BlockType.DIRT,
		bodyBlock = BlockType.STONE,
	}
end

function HubWorldGenerator:_getSurfaceInfo(wx: number, wz: number, island)
	if island.kind == "hub_main" then
		return self:_getHubSurfaceInfo(wx, wz, island)
	else
		return self:_getSatelliteSurfaceInfo(wx, wz, island)
	end
end

function HubWorldGenerator:IsChunkEmpty(chunkX: number, chunkZ: number): boolean
	local cs = Constants.CHUNK_SIZE_X
	local minX = chunkX * cs
	local maxX = minX + cs - 1
	local minZ = chunkZ * cs
	local maxZ = minZ + cs - 1

	local function distSqToRect(px, pz)
		local dx = 0
		if px < minX then
			dx = minX - px elseif px > maxX then dx = px - maxX
		end
		local dz = 0
		if pz < minZ then
			dz = minZ - pz elseif pz > maxZ then dz = pz - maxZ
		end
		return dx * dx + dz * dz
	end

	for _, island in ipairs(self._islands) do
		local buffer = island.topRadius + island.depth + 4
		if distSqToRect(island.centerX, island.centerZ) <= (buffer * buffer) then
			return false
		end
	end

	return true
end

function HubWorldGenerator:IsInsideIsland(wx: number, wy: number, wz: number): boolean
	local inside, _island = self:_isInsideAnyIsland(wx, wy, wz)
	return inside
end

function HubWorldGenerator:_isInsideAnyIsland(wx: number, wy: number, wz: number)
	for _, island in ipairs(self._islands) do
		local topY = island.topY
		local bottomY = topY - island.depth + 1
		if wy >= bottomY and wy <= topY then
			local dx = wx - island.centerX
			local dz = wz - island.centerZ
			local dist = math.sqrt(dx * dx + dz * dz)
			local depthFromTop = topY - wy
			local cleanRadius = IslandUtils.computeRadiusAtDepth(island.topRadius, depthFromTop, island.taper)
			local noisyRadius = IslandUtils.applyEdgeNoise(cleanRadius, wx, wz, island.noise)
			if dist <= noisyRadius then
				return true, island
			end
		end
	end

	return false, nil
end

function HubWorldGenerator:_getLocalTopY(wx: number, wz: number, island)
	local info = self:_getSurfaceInfo(wx, wz, island)
	return info and info.surfaceY or island.topY
end

function HubWorldGenerator:GetBlockAt(wx: number, wy: number, wz: number): number
	local inside, island = self:_isInsideAnyIsland(wx, wy, wz)
	if not inside then
		return BlockType.AIR
	end

	local info = self:_getSurfaceInfo(wx, wz, island)
	if not info then
		return BlockType.AIR
	end

	local depthFromLocalTop = info.surfaceY - wy
	if depthFromLocalTop < 0 then
		return BlockType.AIR
	end

	if info.layerProfile then
		return self:_getLayeredBlock(info, depthFromLocalTop)
	end

	local blockId
	if depthFromLocalTop == 0 then
		blockId = info.topBlock
	elseif depthFromLocalTop <= 2 then
		blockId = info.mantleBlock or info.topBlock
	else
		blockId = info.bodyBlock or BlockType.STONE
	end

	return self:_applyCliffStrataBlock(info.strataConfig, depthFromLocalTop, blockId)
end

function HubWorldGenerator:_applyCliffStrataBlock(config, depthFromLocalTop, blockId)
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

function HubWorldGenerator:GenerateChunk(chunk)
	local chunkWorldX = chunk.x * Constants.CHUNK_SIZE_X
	local chunkWorldZ = chunk.z * Constants.CHUNK_SIZE_Z

	for lx = 0, Constants.CHUNK_SIZE_X - 1 do
		for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
			local wx = chunkWorldX + lx
			local wz = chunkWorldZ + lz
			local highestY = 0

			for ly = 0, Constants.WORLD_HEIGHT - 1 do
				local wy = ly
				local blockType = self:GetBlockAt(wx, wy, wz)
				if blockType ~= BlockType.AIR then
					chunk:SetBlock(lx, ly, lz, blockType)
					highestY = ly
				end
			end

			local idx = lx + lz * Constants.CHUNK_SIZE_X
			chunk.heightMap[idx] = highestY
		end
	end

	self:_populateHubTrees(chunk, chunkWorldX, chunkWorldZ)
	self:_placeSpawnPad(chunk, chunkWorldX, chunkWorldZ)
	self:_placeNpcMarkers(chunk, chunkWorldX, chunkWorldZ)
	self:_placeSatellitePortalFrames(chunk, chunkWorldX, chunkWorldZ)

	chunk.state = Constants.ChunkState.READY
end

function HubWorldGenerator:_populateHubTrees(chunk, chunkWorldX: number, chunkWorldZ: number)
	local trees = self._hubTrees
	if not trees or #trees == 0 then
		return
	end

	local chunkMinX = chunkWorldX
	local chunkMaxX = chunkWorldX + Constants.CHUNK_SIZE_X - 1
	local chunkMinZ = chunkWorldZ
	local chunkMaxZ = chunkWorldZ + Constants.CHUNK_SIZE_Z - 1

	for _, tree in ipairs(trees) do
		local radius = tree.horizontalRadius or 2
		if tree.wx + radius >= chunkMinX and tree.wx - radius <= chunkMaxX and tree.wz + radius >= chunkMinZ and tree.wz - radius <= chunkMaxZ then
			self:_writeTreeToChunk(chunk, chunkWorldX, chunkWorldZ, tree)
		end
	end
end

function HubWorldGenerator:_writeTreeToChunk(chunk, chunkWorldX, chunkWorldZ, tree)
	if not tree.baseY then
		return
	end

	local baseX = tree.wx
	local baseZ = tree.wz
	local baseY = tree.baseY
	local trunkHeight = tree.trunkHeight or 5
	local logBlockId = tree.logBlockId or BlockType.WOOD
	local leafBlockId = getLeavesForLog(logBlockId)

	for dy = 0, trunkHeight - 1 do
		self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, baseX, baseY + dy, baseZ, logBlockId)
	end

	local function placeLeaf(dx, dy, dz, skipTrunk)
		if skipTrunk and dx == 0 and dz == 0 then
			return
		end
		self:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, baseX + dx, baseY + dy, baseZ + dz, leafBlockId)
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

function HubWorldGenerator:_setChunkBlockAndHeight(chunk, chunkWorldX, chunkWorldZ, wx, wy, wz, blockId)
	if not blockId then
		return
	end

	if wy < 0 or wy >= Constants.WORLD_HEIGHT then
		return
	end

	local lx = wx - chunkWorldX
	local lz = wz - chunkWorldZ
	if lx < 0 or lx >= Constants.CHUNK_SIZE_X or lz < 0 or lz >= Constants.CHUNK_SIZE_Z then
		return
	end

	chunk:SetBlock(lx, wy, lz, blockId)
	if chunk.heightMap then
		local idx = lx + lz * Constants.CHUNK_SIZE_X
		local current = chunk.heightMap[idx]
		if not current or wy > current then
			chunk.heightMap[idx] = wy
		end
	end
end

function HubWorldGenerator:_placeSpawnPad(chunk, chunkWorldX: number, chunkWorldZ: number)
	local mainIsland = self._islands and self._islands[1]
	if not mainIsland then
		return
	end

	local info = self:_getHubSurfaceInfo(self._hubCenter.x, self._hubCenter.z, mainIsland)
	if not info then
		return
	end

	if not self._spawnPadCells then
		self._spawnPadCells = {}
		local radius = 7.45 -- tuned so cardinal peaks are 5 blocks wide
		local loopRadius = math.ceil(radius)
		local radiusSq = radius * radius
		local innerRadius = math.max(radius - 1, 1)
		local innerRadiusSq = innerRadius * innerRadius
		self._spawnPadRadius = radius

		local centerX = self._hubCenter.x
		local centerZ = self._hubCenter.z

		for dx = -loopRadius, loopRadius do
			for dz = -loopRadius, loopRadius do
				local distSq = dx * dx + dz * dz
				if distSq <= radiusSq then
					local wxCell = centerX + dx
					local wzCell = centerZ + dz
					local blockId
					if distSq > innerRadiusSq then
						blockId = BlockType.COBBLESTONE
					else
						blockId = self:_sampleSpawnPadFillBlock(wxCell, wzCell, dx, dz, radius)
					end

					table.insert(self._spawnPadCells, {
						dx = dx,
						dz = dz,
						blockId = blockId,
					})
				end
			end
		end
	end

	local spawnY = info.surfaceY
	local centerX = self._hubCenter.x
	local centerZ = self._hubCenter.z

	for _, cell in ipairs(self._spawnPadCells) do
		local wx = centerX + cell.dx
		local wz = centerZ + cell.dz
		local lx = wx - chunkWorldX
		local lz = wz - chunkWorldZ

		if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z and spawnY >= 0 and spawnY < Constants.WORLD_HEIGHT then
			chunk:SetBlock(lx, spawnY, lz, cell.blockId)
		end
	end
end

function HubWorldGenerator:_sampleSpawnPadFillBlock(wx: number, wz: number, dx: number, dz: number, radius: number)
	local seed = self.seed or 0
	local dist = math.sqrt(dx * dx + dz * dz)
	local normalized = radius > 0 and (dist / radius) or 0
	local ringIndex = math.clamp(math.floor(normalized * 5), 0, 4)
	local angle = math.atan2(dz, dx)
	local spokeIndex = math.floor(((angle + math.pi) / (math.pi / 4))) % 4

	local hash = wx * 73856093 + wz * 19349663 + seed * 83492791
	hash = (hash % 2147483647 + 2147483647) % 2147483647 -- ensure positive
	local variant = hash % 3

	local blockId = BlockType.STONE
	if ringIndex <= 1 then
		blockId = (variant == 0) and BlockType.STONE_BRICKS or BlockType.STONE
	elseif ringIndex == 2 then
		blockId = (spokeIndex % 2 == 0) and BlockType.STONE_BRICKS or BlockType.STONE
	elseif ringIndex == 3 then
		blockId = (variant == 2) and BlockType.STONE_BRICKS or BlockType.COBBLESTONE
	else
		blockId = (spokeIndex % 2 == 0) and BlockType.COBBLESTONE or BlockType.STONE
	end

	if math.abs(dx) == math.abs(dz) or (math.abs(dx) <= 1 and math.abs(dz) <= 1) then
		blockId = BlockType.STONE_BRICKS
	end

	return blockId
end

function HubWorldGenerator:_placeNpcMarkers(chunk, chunkWorldX: number, chunkWorldZ: number)
	for _, pad in ipairs(self._npcPads) do
		local lx = pad.centerX - chunkWorldX
		local lz = pad.centerZ - chunkWorldZ
		if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
			local y = pad.targetY + 1
			if y < Constants.WORLD_HEIGHT then
				chunk:SetBlock(lx, y, lz, BlockType.CHEST)
			end
		end
	end
end

function HubWorldGenerator:_placeSatellitePortalFrames(chunk, chunkWorldX: number, chunkWorldZ: number)
	for _, island in ipairs(self._islands) do
		if island.kind == "satellite" then
			self:_placePortalFrameAt(chunk, chunkWorldX, chunkWorldZ, island)
		end
	end
end

function HubWorldGenerator:_placePortalFrameAt(chunk, chunkWorldX: number, chunkWorldZ: number, island)
	local info = self:_getSatelliteSurfaceInfo(island.centerX, island.centerZ, island)
	if not info then
		return
	end

	local baseY = info.surfaceY + 1
	local halfOuterW = 2
	local innerHalfW = 1
	local innerHeight = 3
	local outerHeight = innerHeight + 2

	for dx = -halfOuterW, halfOuterW do
		for dy = 0, outerHeight - 1 do
			local wx = island.centerX + dx
			local wy = baseY + dy
			local wz = island.centerZ

			local lx = wx - chunkWorldX
			local lz = wz - chunkWorldZ
			if lx >= 0 and lx < Constants.CHUNK_SIZE_X and lz >= 0 and lz < Constants.CHUNK_SIZE_Z then
				local isTopOrBottom = (dy == 0) or (dy == outerHeight - 1)
				local isSide = (dx == -halfOuterW) or (dx == halfOuterW)
				if isTopOrBottom or isSide then
					chunk:SetBlock(lx, wy, lz, BlockType.STONE_BRICKS)
				elseif math.abs(dx) <= innerHalfW and dy >= 1 and dy <= innerHeight then
					chunk:SetBlock(lx, wy, lz, BlockType.GLASS)
				end
			end
		end
	end
end

function HubWorldGenerator:PlaceTree(chunk, lx: number, ly: number, lz: number, logBlockId: number?)
	if lx < 0 or lx >= Constants.CHUNK_SIZE_X or lz < 0 or lz >= Constants.CHUNK_SIZE_Z then
		return
	end

	local trunkId = logBlockId or BlockType.WOOD
	for y = 0, 4 do
		if ly + y < Constants.WORLD_HEIGHT then
			chunk:SetBlock(lx, ly + y, lz, trunkId)
		end
	end

	local function placeLeaf(dx, dy, dz)
		local leafX = lx + dx
		local leafY = ly + dy
		local leafZ = lz + dz

		if leafX >= 0 and leafX < Constants.CHUNK_SIZE_X and
			leafZ >= 0 and leafZ < Constants.CHUNK_SIZE_Z and
			leafY < Constants.WORLD_HEIGHT then
			local leafId = getLeavesForLog(logBlockId)
			chunk:SetBlock(leafX, leafY, leafZ, leafId)
		end
	end

	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				if not (dx == 0 and dz == 0) then
					placeLeaf(dx, 3, dz)
				end
			end
		end
	end

	for dx = -2, 2 do
		for dz = -2, 2 do
			if not (math.abs(dx) == 2 and math.abs(dz) == 2) then
				if not (dx == 0 and dz == 0) then
					placeLeaf(dx, 4, dz)
				end
			end
		end
	end

	for dx = -1, 1 do
		for dz = -1, 1 do
			placeLeaf(dx, 5, dz)
		end
	end
end

function HubWorldGenerator:GetSpawnPosition(): Vector3
	local bs = Constants.BLOCK_SIZE
	local mainIsland = self._islands and self._islands[1]
	local topY = self._hubConfig.BASE_TOP_Y
	if mainIsland then
		local info = self:_getHubSurfaceInfo(self._hubCenter.x, self._hubCenter.z, mainIsland)
		if info then
			topY = info.surfaceY
		end
	end

	return Vector3.new(
		self._hubCenter.x * bs,
		(topY + 2) * bs,
		self._hubCenter.z * bs
	)
end

function HubWorldGenerator:GetChunkBounds()
	return self._chunkBounds
end

return HubWorldGenerator
