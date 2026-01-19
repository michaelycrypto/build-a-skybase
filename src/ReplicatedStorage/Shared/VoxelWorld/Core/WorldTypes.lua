--[[
	WorldTypes.lua
	Defines the available voxel world presets (player worlds, hub worlds, etc)
]]

local Constants = require(script.Parent.Constants)
local SkyblockGenerator = require(script.Parent.Parent.Generation.SkyblockGenerator)
local HubWorldGenerator = require(script.Parent.Parent.Generation.HubWorldGenerator)
local SchematicWorldGenerator = require(script.Parent.Parent.Generation.SchematicWorldGenerator)

local WorldTypes = {}

WorldTypes.registry = {
	player_world = {
		id = "player_world",
		name = "Player World",
		generatorModule = SkyblockGenerator,
		generatorOptions = nil, -- Uses SkyblockGenerator defaults
		renderDistance = 6,
		isHub = false,
		workspaceAttributes = {
			IsHubWorld = false,
			HubRenderDistance = nil,
		},
	},

	-- Hub world using imported Minecraft schematic (LittleIsland)
	hub_world = {
		id = "hub_world",
		name = "Lobby Hub",
		generatorModule = SchematicWorldGenerator,
		generatorOptions = {
			-- Path to schematic in ServerStorage/Schematics folder
			schematicPath = "Schematics.LittleIsland",

			-- Offset to position schematic in world
			-- Schematic is 202x136x166, centering around origin
			offsetX = -101,
			offsetY = 0,
			offsetZ = -83,

			-- Chunk bounds for streaming optimization
			-- Calculated from schematic size: 202/16 ≈ 13 chunks, 166/16 ≈ 11 chunks
			-- With offset, chunks span roughly -7 to 7 on X, -6 to 6 on Z
			chunkBounds = {
				minChunkX = -7,
				maxChunkX = 7,
				minChunkZ = -6,
				maxChunkZ = 6,
			},
		},
		renderDistance = 6, -- Larger render distance for hub schematic
		isHub = true,
		workspaceAttributes = {
			IsHubWorld = true,
			HubRenderDistance = 6,
		},
	},

	-- Legacy procedural hub (kept for reference/fallback)
	hub_world_procedural = {
		id = "hub_world_procedural",
		name = "Procedural Hub (Legacy)",
		generatorModule = HubWorldGenerator,
		generatorOptions = {
			chunkBounds = {
				minChunkX = 0,
				maxChunkX = 4,
				minChunkZ = 0,
				maxChunkZ = 4,
			},
			hubConfig = {
				CENTER_X = 40,
				CENTER_Z = 40,
				BASE_TOP_Y = 86,
				MAX_TOP_Y = 90,
				ISLAND_DEPTH = 22,
				EDGE_TAPER_PER_LEVEL = 0.42,
				NOISE = {
					surfacePrimaryScale = 0.03,
					surfacePrimaryAmp = 0.4,
					surfaceDetailScale = 0.08,
					surfaceDetailAmp = 0.2,
					edgeScale = 0.15,
					edgeAmplitude = 0.12,
				},
				PATH = { count = 0 },
				NPC_PAD = { radius = 0 },
				SATELLITES = {},
				SATELLITE_NOISE = { scale = 0, amplitude = 0 },
			},
			simpleIsland = {
				outerRadius = 30,
				stoneExposureThreshold = 5,
				forceStoneSupport = true,
				bottomTaperPerLevel = 0.28,
				domainWarp = {
					scale = 0.018,
					amplitude = 4.6,
				},
				domes = {
					{ radius = 24, height = 0.9, power = 1.7 },
					{ radius = 18, height = 0.5, offsetX = -3, offsetZ = 2, power = 1.9 },
					{ radius = 14, height = -0.2, offsetX = 4, offsetZ = -3, power = 1.8 },
				},
				maskEllipses = {
					{ radiusX = 25, radiusZ = 19, rotation = 0 },
					{ radiusX = 23, radiusZ = 30, rotation = math.rad(14), offsetX = -4, offsetZ = 1, strength = 0.82 },
					{ radiusX = 22, radiusZ = 25, rotation = math.rad(-18), offsetX = 5, offsetZ = -3, strength = 0.78 },
				},
				maskFalloff = {
					depth = 3.4,
					power = 2.15,
				},
				prongs = {
					count = 3,
					amplitude = 0.8,
					falloff = 2.4,
					innerRadiusFactor = 0.7,
					phaseOffset = 0.35,
					noiseScale = 0.045,
					noiseWeight = 0.3,
					blend = 0.75,
				},
				falloffBands = {
					{ startRadius = 18, endRadius = 26, depth = 0.9, power = 1.35, stretchX = 1.05, stretchZ = 1.1 },
					{ startRadius = 26, endRadius = 30, depth = 3.4, power = 2.4, stretchX = 1.12, stretchZ = 1.0 },
				},
				rimNoise = {
					amplitude = 1.5,
					scale = 0.16,
					startRadius = 26,
				},
				rimFracture = {
					amplitude = 1.8,
					scale = 0.1,
					startRadius = 25,
					bias = -0.15,
				},
				undersideWarp = {
					scale = 0.065,
					amplitude = 2.2,
					rimWidth = 7,
					power = 1.3,
				},
				strataStart = 5,
				cliffStrata = {
					{ blockId = Constants.BlockType.STONE, thickness = 3 },
					{ blockId = Constants.BlockType.COBBLESTONE, thickness = 2 },
					{ blockId = Constants.BlockType.STONE_BRICKS, thickness = 1 },
				},
				verticalLayers = {
					{ thickness = 1, blockId = Constants.BlockType.GRASS },
					{ thickness = 3, blockId = Constants.BlockType.DIRT },
					{ thickness = 3, blockId = Constants.BlockType.STONE },
				},
				cliffLayers = {
					{ depth = 0.5, topBlock = Constants.BlockType.GRASS, mantleBlock = Constants.BlockType.DIRT },
					{ depth = 2.4, topBlock = Constants.BlockType.DIRT, mantleBlock = Constants.BlockType.DIRT },
					{ depth = 4.6, topBlock = Constants.BlockType.DIRT, mantleBlock = Constants.BlockType.STONE },
					{ depth = 7.2, topBlock = Constants.BlockType.STONE, mantleBlock = Constants.BlockType.STONE },
				},
			},
			disablePaths = true,
			disableNpcPads = true,
		},
		renderDistance = 2,
		isHub = true,
		workspaceAttributes = {
			IsHubWorld = true,
			HubRenderDistance = 3,
		},
	},
}

local DEFAULT_TYPE = WorldTypes.registry.player_world

function WorldTypes:Get(id)
	if not id then
		return DEFAULT_TYPE
	end
	return self.registry[id] or DEFAULT_TYPE
end

function WorldTypes:GetAll()
	return self.registry
end

return WorldTypes

