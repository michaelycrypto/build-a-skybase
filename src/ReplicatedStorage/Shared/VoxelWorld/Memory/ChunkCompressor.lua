--[[
	ChunkCompressor.lua
	Palette + RLE compression for linear chunk data (flat array)
]]

local ChunkCompressor = {}

-- Build palette and index map from a flat block-id array
local function buildPalette(flat)
	local palette = {}
	local toIndex = {}
	for i = 1, #flat do
		local bid = flat[i]
		if toIndex[bid] == nil then
			toIndex[bid] = #palette + 1
			palette[#palette + 1] = bid
		end
	end
	return palette, toIndex
end

-- Run-length encode an array of palette indices
local function rleEncode(indices)
	local runs = {}
	local last = nil
	local count = 0
	for i = 1, #indices do
		local v = indices[i]
		if v == last then
			count += 1
		else
			if last ~= nil then
				runs[#runs + 1] = { last, count }
			end
			last = v
			count = 1
		end
	end
	if last ~= nil then
		runs[#runs + 1] = { last, count }
	end
	return runs
end

local function rleDecode(runs)
	local out = {}
	local k = 1
	for i = 1, #runs do
		local pair = runs[i]
		local v = pair[1]
		local n = pair[2]
		for j = 1, n do
			out[k] = v
			k += 1
		end
	end
	return out
end

-- Convert linear chunk to compressed form
function ChunkCompressor.CompressForNetwork(linear)
	local flat = linear.flat or {}
	local flatMeta = linear.flatMeta or {}

	-- Blocks
	local palette, toIndex = buildPalette(flat)
	local indices = table.create(#flat)
	for i = 1, #flat do
		indices[i] = toIndex[flat[i]]
	end
	local runs = rleEncode(indices)

	-- Metadata
	local metaPalette, metaToIndex = buildPalette(flatMeta)
	local metaIndices = table.create(#flatMeta)
	for i = 1, #flatMeta do
		metaIndices[i] = metaToIndex[flatMeta[i]]
	end
	local metaRuns = rleEncode(metaIndices)

	return {
		version = 2,
		dims = linear.dims,
		palette = palette,
		runs = runs,
		metaPalette = metaPalette,
		metaRuns = metaRuns
	}
end

-- Decompress to a flat array of block ids
function ChunkCompressor.DecompressToLinear(compressed)
	local dims = compressed.dims
	-- Blocks
	local palette = compressed.palette or {}
	local runs = compressed.runs or {}
	local indices = rleDecode(runs)
	local flat = table.create(#indices)
	for i = 1, #indices do
		flat[i] = palette[indices[i]] or 0
	end

	-- Metadata (optional for backward compatibility)
	local flatMeta = {}
	if compressed.metaPalette and compressed.metaRuns then
		local metaPalette = compressed.metaPalette or {}
		local metaRuns = compressed.metaRuns or {}
		local metaIndices = rleDecode(metaRuns)
		flatMeta = table.create(#metaIndices)
		for i = 1, #metaIndices do
			flatMeta[i] = metaPalette[metaIndices[i]] or 0
		end
	else
		-- Fallback: no metadata provided → zeros
		local total = 0
		if dims and #dims == 3 then
			total = (dims[1] or 0) * (dims[2] or 0) * (dims[3] or 0)
		else
			total = #flat
		end
		flatMeta = table.create(total)
		for i = 1, total do flatMeta[i] = 0 end
	end

	return { flat = flat, flatMeta = flatMeta, dims = dims }
end

-- Back-compat API
function ChunkCompressor.DecompressToFlat(compressed)
	local lin = ChunkCompressor.DecompressToLinear(compressed)
	return lin.flat
end

return ChunkCompressor


