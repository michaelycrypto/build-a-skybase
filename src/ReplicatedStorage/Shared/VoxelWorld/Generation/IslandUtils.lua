--[[
	IslandUtils.lua
	Shared helper functions for island-shaped world generators.
]]

local IslandUtils = {}

function IslandUtils.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end

	local copy = {}
	for k, v in pairs(value) do
		copy[k] = IslandUtils.deepCopy(v)
	end
	return copy
end

function IslandUtils.mergeTables(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then
		return source
	end

	for k, v in pairs(source) do
		if type(v) == "table" then
			local existing = target[k]
			target[k] = IslandUtils.mergeTables(existing and IslandUtils.deepCopy(existing) or {}, v)
		else
			target[k] = v
		end
	end
	return target
end

function IslandUtils.computeRadiusAtDepth(topRadius: number, depthFromTop: number, taperPerLevel: number?)
	local taper = taperPerLevel or 0.3
	return math.max(1.5, topRadius - taper * depthFromTop)
end

function IslandUtils.applyEdgeNoise(cleanRadius: number, wx: number, wz: number, noiseParams)
	if not noiseParams then
		return cleanRadius
	end

	local scale = noiseParams.scale or 0.15
	local amplitude = noiseParams.amplitude or 0.2
	local seedZ = noiseParams.seed or 0
	local n = math.noise(wx * scale, wz * scale, seedZ)
	n = math.clamp(n, -1, 1)
	local factor = math.clamp(1.0 + amplitude * n, 1.0 - amplitude * 0.75, 1.0 + amplitude)
	return cleanRadius * factor
end

return IslandUtils

