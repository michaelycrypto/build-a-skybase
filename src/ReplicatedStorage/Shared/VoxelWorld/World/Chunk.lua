--[[
	Chunk.lua
	Represents a chunk of blocks in the voxel world
]]

local Constants = require(script.Parent.Parent.Core.Constants)

local Chunk = {}
Chunk.__index = Chunk

-- Normalize a nested 3D blocks table so that numeric-like string keys become numbers
local function normalizeBlocksTable(src)
    if type(src) ~= "table" then return {} end

    -- Helper to compute numeric key range
    local function minMaxNumericKeys(t)
        local minK, maxK = math.huge, -math.huge
        for k, _ in pairs(t) do
            local n = tonumber(k)
            if n ~= nil then
                if n < minK then
                    minK = n
                end
                if n > maxK then
                    maxK = n
                end
            end
        end
        if minK == math.huge then return nil, nil end
        return minK, maxK
    end

    -- Detect 1-based X keys
    local minX, maxX = minMaxNumericKeys(src)
    local shiftX = (minX == 1 and maxX == Constants.CHUNK_SIZE_X) and -1 or 0

    local dst = {}
    for kx, vx in pairs(src) do
        local xi = tonumber(kx)
        if xi ~= nil then
            xi = xi + shiftX
        end
        if xi == nil then
            xi = kx
        end
        local inX = (type(xi) ~= "number") or (xi >= 0 and xi < Constants.CHUNK_SIZE_X)
        if inX then
            dst[xi] = dst[xi] or {}
            if type(vx) == "table" then
                -- Detect 1-based Y keys per X slice
                local minY, maxY = minMaxNumericKeys(vx)
                local shiftY = (minY == 1 and maxY == Constants.CHUNK_SIZE_Y) and -1 or 0
                for ky, vy in pairs(vx) do
                    local yi = tonumber(ky)
                    if yi ~= nil then
                        yi = yi + shiftY
                    end
                    if yi == nil then
                        yi = ky
                    end
                    local inY = (type(yi) ~= "number") or (yi >= 0 and yi < Constants.CHUNK_SIZE_Y)
                    if inY then
                        dst[xi][yi] = dst[xi][yi] or {}
                        if type(vy) == "table" then
                            -- Detect 1-based Z keys per (X,Y)
                            local minZ, maxZ = minMaxNumericKeys(vy)
                            local shiftZ = (minZ == 1 and maxZ == Constants.CHUNK_SIZE_Z) and -1 or 0
                            for kz, blockId in pairs(vy) do
                                local zi = tonumber(kz)
                                if zi ~= nil then
                                    zi = zi + shiftZ
                                end
                                if zi == nil then
                                    zi = kz
                                end
                                local inZ = (type(zi) ~= "number") or (zi >= 0 and zi < Constants.CHUNK_SIZE_Z)
                                if inZ then
                                    dst[xi][yi][zi] = blockId
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return dst
end

function Chunk.new(chunkX: number, chunkZ: number)
    local self = setmetatable({
        chunkX = chunkX,
        chunkZ = chunkZ,
        -- Aliases used by some modules (e.g., mesher/generator)
        x = chunkX,
        z = chunkZ,
        blocks = {}, -- 3D array of blocks: [x][y][z]
        metadata = {}, -- 3D array of block metadata: [x][y][z]
        heightMap = {}, -- 1D height map indexed by x + z * CHUNK_SIZE_X
        state = Constants.ChunkState.EMPTY,
        isDirty = false,
        isCompressed = false
    }, Chunk)

    -- Initialize empty blocks and metadata arrays
    for x = 0, Constants.CHUNK_SIZE_X - 1 do
        self.blocks[x] = {}
        self.metadata[x] = {}
        for y = 0, Constants.CHUNK_SIZE_Y - 1 do
            self.blocks[x][y] = {}
            self.metadata[x][y] = {}
            for z = 0, Constants.CHUNK_SIZE_Z - 1 do
                self.blocks[x][y][z] = Constants.BlockType.AIR
                self.metadata[x][y][z] = 0  -- Default: no metadata
            end
        end
    end

    -- Initialize heightMap to 0
    for lx = 0, Constants.CHUNK_SIZE_X - 1 do
        for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
            self.heightMap[lx + lz * Constants.CHUNK_SIZE_X] = 0
        end
    end

    return self
end

-- Get block at local coordinates
function Chunk:getBlock(x: number, y: number, z: number): number
    if x < 0 or x >= Constants.CHUNK_SIZE_X or y < 0 or y >= Constants.CHUNK_SIZE_Y or z < 0 or z >= Constants.CHUNK_SIZE_Z then
        return Constants.BlockType.AIR
    end
    if not self.blocks[x] or not self.blocks[x][y] then
        return Constants.BlockType.AIR
    end
    return self.blocks[x][y][z] or Constants.BlockType.AIR
end

-- PascalCase alias for consumers
function Chunk:GetBlock(x: number, y: number, z: number): number
    return self:getBlock(x, y, z)
end

-- Get block metadata at local coordinates
function Chunk:getMetadata(x: number, y: number, z: number): number
    if x < 0 or x >= Constants.CHUNK_SIZE_X or y < 0 or y >= Constants.CHUNK_SIZE_Y or z < 0 or z >= Constants.CHUNK_SIZE_Z then
        return 0
    end
    if not self.metadata[x] or not self.metadata[x][y] then
        return 0
    end
    return self.metadata[x][y][z] or 0
end

-- PascalCase alias for metadata
function Chunk:GetMetadata(x: number, y: number, z: number): number
    return self:getMetadata(x, y, z)
end

-- Set block metadata at local coordinates
function Chunk:setMetadata(x: number, y: number, z: number, meta: number)
    if x < 0 or x >= Constants.CHUNK_SIZE_X or y < 0 or y >= Constants.CHUNK_SIZE_Y or z < 0 or z >= Constants.CHUNK_SIZE_Z then
        return
    end
    if not self.metadata[x] then
        self.metadata[x] = {}
    end
    if not self.metadata[x][y] then
        self.metadata[x][y] = {}
    end
    self.metadata[x][y][z] = meta or 0
    self.isDirty = true
end

-- PascalCase alias for metadata
function Chunk:SetMetadata(x: number, y: number, z: number, meta: number)
    self:setMetadata(x, y, z, meta)
end

-- Fast check for emptiness (no non-air blocks)
function Chunk:IsEmpty(): boolean
    return (self.numNonAirBlocks or 0) == 0
end

-- Check if a block ID is water
local function isWaterBlock(blockId)
    return blockId == Constants.BlockType.WATER_SOURCE or blockId == Constants.BlockType.FLOWING_WATER
end

-- Set block at local coordinates
function Chunk:setBlock(x: number, y: number, z: number, blockId: number)
    if x < 0 or x >= Constants.CHUNK_SIZE_X or y < 0 or y >= Constants.CHUNK_SIZE_Y or z < 0 or z >= Constants.CHUNK_SIZE_Z then
        return
    end
    if not self.blocks[x] then
        self.blocks[x] = {}
    end
    if not self.blocks[x][y] then
        self.blocks[x][y] = {}
    end

    local oldBlockId = self.blocks[x][y][z]
    self.blocks[x][y][z] = blockId
    self.isDirty = true

    -- Maintain non-air count
    if oldBlockId == Constants.BlockType.AIR and blockId ~= Constants.BlockType.AIR then
        self.numNonAirBlocks = (self.numNonAirBlocks or 0) + 1
    elseif oldBlockId ~= Constants.BlockType.AIR and blockId == Constants.BlockType.AIR then
        self.numNonAirBlocks = math.max(0, (self.numNonAirBlocks or 0) - 1)
    end

    -- Track water Y bounds for efficient WaterMesher scanning
    -- This avoids scanning 256 Y levels when water only exists in a small range
    local wasWater = isWaterBlock(oldBlockId)
    local isWater = isWaterBlock(blockId)

    if isWater then
        -- Water placed - extend bounds
        if self.waterMinY == nil or y < self.waterMinY then
            self.waterMinY = y
        end
        if self.waterMaxY == nil or y > self.waterMaxY then
            self.waterMaxY = y
        end
    elseif wasWater then
        -- Water removed - mark bounds as dirty (will be recalculated on next mesh)
        -- Full recalculation is expensive, so we just invalidate and let WaterMesher handle it
        self.waterBoundsDirty = true
    end

    -- Maintain heightMap (highest non-air y for column)
    local idx = x + z * Constants.CHUNK_SIZE_X

    if blockId ~= Constants.BlockType.AIR then
        -- Placing a solid block - update if higher
        if (self.heightMap[idx] or 0) < y then
            self.heightMap[idx] = y
        end
    elseif oldBlockId ~= Constants.BlockType.AIR then
        -- Removing a solid block - need to recalculate if this was the highest
        if (self.heightMap[idx] or 0) == y then
            -- Scan downward to find new highest block
            local newHeight = 0
            for scanY = y - 1, 0, -1 do
                local scanBlock = (self.blocks[x] and self.blocks[x][scanY] and self.blocks[x][scanY][z]) or Constants.BlockType.AIR
                if scanBlock ~= Constants.BlockType.AIR then
                    newHeight = scanY
                    break
                end
            end
            self.heightMap[idx] = newHeight
        end
    end
end

-- PascalCase alias for consumers
function Chunk:SetBlock(x: number, y: number, z: number, blockId: number)
    self:setBlock(x, y, z, blockId)
end

-- Serialize chunk data for network transfer
function Chunk:serialize()
	return {
        x = self.chunkX,
        z = self.chunkZ,
		blocks = self.blocks,
		metadata = self.metadata,  -- NEW: Include metadata
        state = self.state
	}
end

-- Serialize chunk data to a robust flat array (1-based) to avoid 0-index issues over the network
function Chunk:serializeLinear()
    local sx, sy, sz = Constants.CHUNK_SIZE_X, Constants.CHUNK_SIZE_Y, Constants.CHUNK_SIZE_Z
    local total = sx * sy * sz
    local flat = table.create(total)
    local flatMeta = table.create(total)
    local i = 1 -- 1-based for network safety
    for y = 0, sy - 1 do
        for z = 0, sz - 1 do
            for x = 0, sx - 1 do
                local bid = (self.blocks[x] and self.blocks[x][y] and self.blocks[x][y][z]) or Constants.BlockType.AIR
                local meta = (self.metadata[x] and self.metadata[x][y] and self.metadata[x][y][z]) or 0
                flat[i] = bid
                flatMeta[i] = meta
                i += 1
            end
        end
    end
    return {
        x = self.chunkX,
        z = self.chunkZ,
        flat = flat,
        flatMeta = flatMeta,  -- NEW: Include metadata
        dims = { sx, sy, sz },
        state = self.state
    }
end

-- Deserialize chunk data from network
function Chunk:deserialize(data)
    self.chunkX = data.x
    self.chunkZ = data.z
    self.x = data.x
    self.z = data.z
    -- Convert any stringified numeric keys back to numbers to support 0-based indexing
    self.blocks = normalizeBlocksTable(data.blocks)
	self.metadata = normalizeBlocksTable(data.metadata or {})  -- NEW: Deserialize metadata
	self.state = data.state
	self.isDirty = true

    -- Rebuild heightMap and non-air count
    local count = 0
    for lx = 0, Constants.CHUNK_SIZE_X - 1 do
        for lz = 0, Constants.CHUNK_SIZE_Z - 1 do
            local highest = 0
            for ly = Constants.CHUNK_SIZE_Y - 1, 0, -1 do
                local bid = (self.blocks[lx] and self.blocks[lx][ly] and self.blocks[lx][ly][lz]) or Constants.BlockType.AIR
                if bid ~= Constants.BlockType.AIR then
                    highest = ly
                    break
                end
            end
            -- Count full column non-air by scanning upward (cheap, small columns)
            for ly2 = 0, highest do
                local b = (self.blocks[lx] and self.blocks[lx][ly2] and self.blocks[lx][ly2][lz]) or Constants.BlockType.AIR
                if b ~= Constants.BlockType.AIR then
                    count += 1
                end
            end
            self.heightMap[lx + lz * Constants.CHUNK_SIZE_X] = highest
        end
    end
    self.numNonAirBlocks = count
end

-- Deserialize from flat array (1-based) created by serializeLinear
function Chunk:deserializeLinear(data)
    local sx, sy, sz = Constants.CHUNK_SIZE_X, Constants.CHUNK_SIZE_Y, Constants.CHUNK_SIZE_Z
    self.chunkX = data.x
    self.chunkZ = data.z
    self.x = data.x
    self.z = data.z
    -- Ensure blocks and metadata tables exist
    self.blocks = {}
    self.metadata = {}
    for x = 0, sx - 1 do
        self.blocks[x] = {}
        self.metadata[x] = {}
        for y = 0, sy - 1 do
            self.blocks[x][y] = {}
            self.metadata[x][y] = {}
        end
    end

    local flat = data.flat or {}
    local flatMeta = data.flatMeta or {}  -- NEW: Deserialize metadata
    local i = 1
    local count = 0

    -- Track highest block per column during deserialization (optimize heightMap rebuild)
    local columnHeights = {}  -- [x + z*sx] = highest y
    for lx = 0, sx - 1 do
        for lz = 0, sz - 1 do
            columnHeights[lx + lz * sx] = 0
        end
    end

    for y = 0, sy - 1 do
        for z = 0, sz - 1 do
            for x = 0, sx - 1 do
                local bid = flat[i] or Constants.BlockType.AIR
                local meta = flatMeta[i] or 0
                self.blocks[x][y][z] = bid
                self.metadata[x][y][z] = meta
                if bid ~= Constants.BlockType.AIR then
                    count += 1
                    -- Update heightMap during deserialization (single pass)
                    local colIdx = x + z * sx
                    if y > columnHeights[colIdx] then
                        columnHeights[colIdx] = y
                    end
                end
                i += 1
            end
        end
    end

    -- Copy optimized heightMap
    for lx = 0, sx - 1 do
        for lz = 0, sz - 1 do
            self.heightMap[lx + lz * sx] = columnHeights[lx + lz * sx]
        end
    end

    self.state = data.state
    self.isDirty = true
    self.numNonAirBlocks = count
end

-- PascalCase aliases
function Chunk:SerializeLinear()
    return self:serializeLinear()
end

function Chunk:DeserializeLinear(data)
    return self:deserializeLinear(data)
end

-- PascalCase aliases for compatibility
function Chunk:Serialize()
    return self:serialize()
end

function Chunk:Deserialize(data)
    return self:deserialize(data)
end

-- Clear chunk data
function Chunk:clear()
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		self.blocks[x] = {}
		for y = 0, Constants.CHUNK_SIZE_Y - 1 do
			self.blocks[x][y] = {}
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				self.blocks[x][y][z] = Constants.BlockType.AIR
			end
		end
	end
	self.isDirty = true
	self.numNonAirBlocks = 0
end

return Chunk