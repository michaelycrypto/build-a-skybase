--[[
	NoiseGenerator.lua
	Implements proper Perlin noise generation
]]

local NoiseGenerator = {}
NoiseGenerator.__index = NoiseGenerator

-- Permutation table
local function createPermutation(seed: number)
	local perm = {}
	local rng = Random.new(seed)

	-- Fill array with ordered values
	for i = 0, 255 do
		perm[i] = i
	end

	-- Shuffle array
	for i = 255, 1, -1 do
		local j = rng:NextInteger(0, i)
		perm[i], perm[j] = perm[j], perm[i]
	end

	-- Duplicate array to avoid overflow
	for i = 0, 255 do
		perm[i + 256] = perm[i]
	end

	return perm
end

-- Gradient vectors for 2D noise
local GRAD2 = {
	{1, 1}, {-1, 1}, {1, -1}, {-1, -1},
	{1, 0}, {-1, 0}, {0, 1}, {0, -1}
}

-- Fade function (6t^5 - 15t^4 + 10t^3)
local function fade(t: number): number
	return t * t * t * (t * (t * 6 - 15) + 10)
end

-- Linear interpolation
local function lerp(a: number, b: number, t: number): number
	return a + t * (b - a)
end

-- Gradient function for 2D noise
local function grad2(hash: number, x: number, y: number): number
	local g = GRAD2[hash % 8 + 1]
	return g[1] * x + g[2] * y
end

function NoiseGenerator.new(seed: number)
	local self = setmetatable({
		perm = createPermutation(seed)
	}, NoiseGenerator)

	return self
end

-- Generate 2D Perlin noise
function NoiseGenerator:Noise2D(x: number, y: number): number
	-- Grid cell coordinates
	local xi = math.floor(x) % 256
	local yi = math.floor(y) % 256

	-- Relative coordinates within cell
	local xf = x - math.floor(x)
	local yf = y - math.floor(y)

	-- Fade factors
	local u = fade(xf)
	local v = fade(yf)

	-- Hash coordinates of the 4 corners
	local aa = self.perm[self.perm[xi] + yi]
	local ab = self.perm[self.perm[xi] + yi + 1]
	local ba = self.perm[self.perm[xi + 1] + yi]
	local bb = self.perm[self.perm[xi + 1] + yi + 1]

	-- Blend gradients
	local x1 = lerp(
		grad2(aa, xf, yf),
		grad2(ba, xf - 1, yf),
		u
	)
	local x2 = lerp(
		grad2(ab, xf, yf - 1),
		grad2(bb, xf - 1, yf - 1),
		u
	)

	-- Return value in range [-1, 1]
	return lerp(x1, x2, v)
end

-- Generate octaved noise (multiple frequencies)
function NoiseGenerator:OctaveNoise2D(x: number, y: number, octaves: number, persistence: number): number
	local total = 0
    local frequency = 1
    local amplitude = 1
    local maxValue = 0

	for _ = 1, octaves do
		total = total + self:Noise2D(x * frequency, y * frequency) * amplitude
		maxValue = maxValue + amplitude
		amplitude = amplitude * persistence
		frequency = frequency * 2
	end

	-- Normalize to [-1, 1]
	return total / maxValue
end

return NoiseGenerator