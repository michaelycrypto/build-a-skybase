--[[
	GreedyMesher.lua
	Implements greedy meshing algorithm to merge block faces into larger surfaces
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Config)
local Constants = require(script.Parent.Parent.Core.Constants)
local Config = require(script.Parent.Parent.Core.Config)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local PartPool = require(script.Parent.PartPool)
local Blocks = BlockRegistry.Blocks
local BOLD_FONT = GlobalConfig.UI_SETTINGS.typography.fonts.bold

-- Texture system
local TextureApplicator = require(script.Parent.TextureApplicator)
local TextureManager = require(script.Parent.TextureManager)

local GreedyMesher = {}
GreedyMesher.__index = GreedyMesher

-- Face directions (right, left, top, bottom, front, back)
local FACES = {
    {x = 0, y = 1, z = 0},  -- Top (+Y) first to ensure ground colliders are generated early
    {x = 0, y = -1, z = 0}, -- Bottom (-Y)
    {x = 1, y = 0, z = 0},  -- Right (+X)
    {x = -1, y = 0, z = 0}, -- Left (-X)
    {x = 0, y = 0, z = 1},  -- Front (+Z)
    {x = 0, y = 0, z = -1}  -- Back (-Z)
}

-- Razor-thin face thickness (use Roblox minimum size to avoid gaps)
local FACE_THICKNESS = 0.01
local SEAM_EPS = 0 -- no seam offset on plane; faces fit within their cell
-- Keep faces exactly on cell planes to meet neighbors without gaps or overlaps
local INSET = 0

-- Snap to 1/1000th of a stud to avoid floating-point drift between chunks
local function snap(value)
    return math.floor(value * 10000 + 0.5) / 10000
end

local function getMaterialForBlock(blockId)
	return Enum.Material.Plastic
end

-- Helper: sample block ID, including neighbors across chunk borders
local function DefaultSampleBlock(worldManager, chunk, x, y, z)
	if x >= 0 and x < Constants.CHUNK_SIZE_X and z >= 0 and z < Constants.CHUNK_SIZE_Z then
		return chunk:GetBlock(x, y, z)
	end
	if not worldManager then
		return Constants.BlockType.AIR
	end
	local cx = chunk.x
	local cz = chunk.z
	local lx = x
	local lz = z
	if lx < 0 then
		cx -= 1
		lx += Constants.CHUNK_SIZE_X
	elseif lx >= Constants.CHUNK_SIZE_X then
		cx += 1
		lx -= Constants.CHUNK_SIZE_X
	end
	if lz < 0 then
		cz -= 1
		lz += Constants.CHUNK_SIZE_Z
	elseif lz >= Constants.CHUNK_SIZE_Z then
		cz += 1
		lz -= Constants.CHUNK_SIZE_Z
	end

	-- Important: do NOT generate missing chunks on the client; only peek existing
    local neighbor
    if worldManager and worldManager.chunks then
        local key = Constants.ToChunkKey(cx, cz)
        neighbor = worldManager.chunks[key]
    end
	if not neighbor then
		return Constants.BlockType.AIR
	end
	return neighbor:GetBlock(lx, y, lz)
end

function GreedyMesher.new()
	return setmetatable({}, GreedyMesher)
end

-- Check if two blocks can be merged (same type and face properties)
function GreedyMesher:CanMergeBlocks(chunk, x1: number, y1: number, z1: number, x2: number, y2: number, z2: number): boolean
	local block1 = chunk:GetBlock(x1, y1, z1)
	local block2 = chunk:GetBlock(x2, y2, z2)

	if block1 ~= block2 then
		return false
	end

	local blockData1 = Blocks[block1] or BlockRegistry:GetBlock(block1)
	local blockData2 = Blocks[block2] or BlockRegistry:GetBlock(block2)

	if not blockData1 or not blockData2 then return false end
	-- Do not merge cross-shaped or transparent blocks
	if blockData1.crossShape or blockData2.crossShape then return false end
	if blockData1.transparent or blockData2.transparent then return false end

	return (block1 == block2) and (blockData1.color == blockData2.color)
end

-- Check if a face should be rendered
function GreedyMesher:ShouldRenderFace(chunk, x: number, y: number, z: number, face, worldManager, sampleFn): boolean
	local blockId = chunk:GetBlock(x, y, z)
	if blockId == Constants.BlockType.AIR then
		return false
	end

	local block = Blocks[blockId] or BlockRegistry:GetBlock(blockId)
	-- Skip face-based rendering for cross-shaped blocks (rendered separately)
	if block and block.crossShape then
		return false
	end

	local nx = x + face.x
	local ny = y + face.y
	local nz = z + face.z

	local sampler = sampleFn or DefaultSampleBlock
	local neighborId = sampler(worldManager, chunk, nx, ny, nz)

	-- Render if neighbor is non-occluding
	if neighborId == Constants.BlockType.AIR then
		return true
	end

	local neighbor = Blocks[neighborId] or BlockRegistry:GetBlock(neighborId)
	if not neighbor then
		return true
	end
	-- Transparent, non-solid, or cross-shaped neighbors should not occlude
	if neighbor.transparent or (neighbor.solid == false) or neighbor.crossShape then
		return true
	end
	return false
end

-- Generate mesh for chunk using greedy meshing
function GreedyMesher:GenerateMesh(chunk, worldManager, options)
	options = options or {}
	local sampler = options.sampleBlock or DefaultSampleBlock
	local meshParts = {}
	local partsBudget = 0
	local MAX_PARTS = options.maxParts or 500
    local VISUALS_ENABLED = (options.visual ~= false)
    local SURFACE_SLABS = (options.surfaceSlabs == true)
    local FULL_THICKNESS = (options.fullThickness == true)
    local BOX_MERGE = (options.boxMerge == true)

	-- Limit meshing work to tallest column + safety layer
	local yLimit = Constants.CHUNK_SIZE_Y
	if chunk.heightMap then
		local maxH = 0
		local sx = Constants.CHUNK_SIZE_X
		local sz = Constants.CHUNK_SIZE_Z
		for z = 0, sz - 1 do
			for x = 0, sx - 1 do
				local idx = x + z * sx
				local h = chunk.heightMap[idx] or 0
				if h > maxH then maxH = h end
			end
		end
		-- Include the top cell and one extra layer for safe neighbor checks
		yLimit = math.clamp(maxH + 2, 1, Constants.CHUNK_SIZE_Y)
	end

	-- Debug AABB tracking for this chunk's generated mesh
	local trackAabb = false
	local aabbMinX, aabbMaxX = math.huge, -math.huge
	local aabbMinZ, aabbMaxZ = math.huge, -math.huge
	local trackTop = false
	local topMinX, topMaxX = math.huge, -math.huge
	local topMinZ, topMaxZ = math.huge, -math.huge
	local trackEdgeOccupancy = false
	local occNegX, occPosX, occNegZ, occPosZ = 0, 0, 0, 0

	-- Debug borders disabled (cleanup after fixing seams)
	local shouldDrawBorders = false
	if shouldDrawBorders then
		trackAabb = true
		trackTop = true
		trackEdgeOccupancy = true
		local bs = Constants.BLOCK_SIZE
		local baseX = chunk.x * Constants.CHUNK_SIZE_X * bs
		local baseZ = chunk.z * Constants.CHUNK_SIZE_Z * bs
		local sizeX = Constants.CHUNK_SIZE_X * bs
		local sizeZ = Constants.CHUNK_SIZE_Z * bs

		local function addBorderPart(cx, cz, sx, sz, color, labelText)
			local p = Instance.new("Part")
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Material = Enum.Material.Neon
			p.Color = color
			p.Transparency = 0.25
			-- Make borders vertical walls spanning full world height for visibility
			p.Size = Vector3.new(snap(sx), snap(Constants.WORLD_HEIGHT * bs), snap(sz))
			p.Position = Vector3.new(snap(cx), snap((Constants.WORLD_HEIGHT * bs) * 0.5), snap(cz))
			p.Name = "ChunkBorder"

			-- Optional label to indicate axis direction (+X/-X/+Z/-Z)
			if labelText then
				local gui = Instance.new("BillboardGui")
				gui.Name = "AxisLabel"
				gui.AlwaysOnTop = true
				gui.Size = UDim2.new(0, 80, 0, 28)
				gui.StudsOffsetWorldSpace = Vector3.new(0, math.min(6, p.Size.Y * 0.25), 0)
				gui.Adornee = p
				local tl = Instance.new("TextLabel")
				tl.BackgroundTransparency = 1
				tl.Text = labelText
				tl.Font = BOLD_FONT
				tl.TextScaled = true
				tl.TextColor3 = color
				tl.Size = UDim2.new(1, 0, 1, 0)
				tl.Parent = gui
				gui.Parent = p
			end
			return p
		end

		-- West edge (X = baseX) => -X
		table.insert(meshParts, addBorderPart(baseX, baseZ + sizeZ * 0.5, 0.05, sizeZ, Color3.fromRGB(255, 0, 0), "-X"))
		-- East edge (X = baseX + sizeX) => +X
		table.insert(meshParts, addBorderPart(baseX + sizeX, baseZ + sizeZ * 0.5, 0.05, sizeZ, Color3.fromRGB(255, 0, 0), "+X"))
		-- North edge (Z = baseZ) => -Z
		table.insert(meshParts, addBorderPart(baseX + sizeX * 0.5, baseZ, sizeX, 0.05, Color3.fromRGB(0, 0, 255), "-Z"))
		-- South edge (Z = baseZ + sizeZ) => +Z
		table.insert(meshParts, addBorderPart(baseX + sizeX * 0.5, baseZ + sizeZ, sizeX, 0.05, Color3.fromRGB(0, 0, 255), "+Z"))

		-- Edge occupancy scan (how many columns have any solid blocks on each border)
		if trackEdgeOccupancy then
			-- -X edge (x=0)
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				local has = false
				for y = 0, Constants.CHUNK_SIZE_Y - 1 do
					if chunk:GetBlock(0, y, z) ~= Constants.BlockType.AIR then has = true break end
				end
				if has then occNegX += 1 end
			end
			-- +X edge (x=15)
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				local has = false
				for y = 0, Constants.CHUNK_SIZE_Y - 1 do
					if chunk:GetBlock(Constants.CHUNK_SIZE_X - 1, y, z) ~= Constants.BlockType.AIR then has = true break end
				end
				if has then occPosX += 1 end
			end
			-- -Z edge (z=0)
			for x = 0, Constants.CHUNK_SIZE_X - 1 do
				local has = false
				for y = 0, Constants.CHUNK_SIZE_Y - 1 do
					if chunk:GetBlock(x, y, 0) ~= Constants.BlockType.AIR then has = true break end
				end
				if has then occNegZ += 1 end
			end
			-- +Z edge (z=15)
			for x = 0, Constants.CHUNK_SIZE_X - 1 do
				local has = false
				for y = 0, Constants.CHUNK_SIZE_Y - 1 do
					if chunk:GetBlock(x, y, Constants.CHUNK_SIZE_Z - 1) ~= Constants.BlockType.AIR then has = true break end
				end
				if has then occPosZ += 1 end
			end
		end

		-- Log exact world edge positions (once per chunk mesh)
		print(string.format("[VoxelDebug] Chunk %d,%d edges: X=[%.3f, %.3f], Z=[%.3f, %.3f]",
			chunk.x, chunk.z,
			baseX, baseX + sizeX,
			baseZ, baseZ + sizeZ
		))
	end

    -- Simplified: remove prime collider generation for clarity and performance

    -- Fast path: volume box merging (merge solid blocks into maximal AABBs)
    if BOX_MERGE then
        local sx, sy, sz = Constants.CHUNK_SIZE_X, yLimit, Constants.CHUNK_SIZE_Z
        local visited = {}
        local function k(x, y, z)
            return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
        end
        local function markVisited(x, y, z, v)
            visited[k(x, y, z)] = v
        end
        local function isVisited(x, y, z)
            return visited[k(x, y, z)] == true
        end
        local function isSolid(x, y, z)
            if y < 0 or y >= sy then return false end
            local id
            if x >= 0 and x < sx and z >= 0 and z < sz then
                id = chunk:GetBlock(x, y, z)
            else
                -- Sample across chunk borders using provided sampler
                id = sampler(worldManager, chunk, x, y, z)
            end
            if id == Constants.BlockType.AIR then return false end
            local def = Blocks[id] or BlockRegistry:GetBlock(id)
            return def and def.solid ~= false and not def.crossShape
        end
        -- Optional: only emit boxes that touch air somewhere (exposed), to avoid hidden volume
        local function touchesAir(x0, y0, z0, dx, dy, dz)
            for y = y0, y0 + dy - 1 do
                for z = z0, z0 + dz - 1 do
                    -- Expand faces around the box by 1 cell to test exposure
                    if not isSolid(x0 - 1, y, z) or not isSolid(x0 + dx, y, z) then return true end
                end
            end
            for x = x0, x0 + dx - 1 do
                for z = z0, z0 + dz - 1 do
                    if not isSolid(x, y0 - 1, z) or not isSolid(x, y0 + dy, z) then return true end
                end
            end
            for x = x0, x0 + dx - 1 do
                for y = y0, y0 + dy - 1 do
                    if not isSolid(x, y, z0 - 1) or not isSolid(x, y, z0 + dz) then return true end
                end
            end
            return false
        end

        for y = 0, sy - 1 do
            for z = 0, sz - 1 do
                for x = 0, sx - 1 do
                    if partsBudget >= MAX_PARTS then return meshParts end
                    if not isVisited(x, y, z) and isSolid(x, y, z) then
                        local seedId = chunk:GetBlock(x, y, z)
                        -- Grow x
                        local dx = 1
                        while x + dx < sx and not isVisited(x + dx, y, z) and isSolid(x + dx, y, z) and chunk:GetBlock(x + dx, y, z) == seedId do
                            dx += 1
                        end
                        -- Grow z for each x span uniformly
                        local dz = 1
                        local canGrowZ = true
                        while canGrowZ and (z + dz) < sz do
                            for ix = 0, dx - 1 do
                                if isVisited(x + ix, y, z + dz) or not isSolid(x + ix, y, z + dz) or chunk:GetBlock(x + ix, y, z + dz) ~= seedId then
                                    canGrowZ = false
                                    break
                                end
                            end
                            if canGrowZ then dz += 1 end
                        end
                        -- Grow y uniformly across xz area
                        local dy = 1
                        local canGrowY = true
                        while canGrowY and (y + dy) < sy do
                            for iz = 0, dz - 1 do
                                for ix = 0, dx - 1 do
                                    if isVisited(x + ix, y + dy, z + iz) or not isSolid(x + ix, y + dy, z + iz) or chunk:GetBlock(x + ix, y + dy, z + iz) ~= seedId then
                                        canGrowY = false
                                        break
                                    end
                                end
                                if not canGrowY then break end
                            end
                            if canGrowY then dy += 1 end
                        end
                        -- Mark visited
                        for iy = 0, dy - 1 do
                            for iz = 0, dz - 1 do
                                for ix = 0, dx - 1 do
                                    markVisited(x + ix, y + iy, z + iz, true)
                                end
                            end
                        end
                        -- Skip hidden boxes if requested
                        local exposed = touchesAir(x, y, z, dx, dy, dz)
                        if exposed then
                            local id = seedId
                            local def = Blocks[id] or BlockRegistry:GetBlock(id)
                            local bs = Constants.BLOCK_SIZE
                            local size = Vector3.new(snap(dx * bs), snap(dy * bs), snap(dz * bs))
                            local cxw = (chunk.x * sx + x) * bs + size.X * 0.5
                            local cyw = (y) * bs + size.Y * 0.5
                            local czw = (chunk.z * sz + z) * bs + size.Z * 0.5
                            local p = PartPool.AcquireColliderPart()
                            p.CanCollide = true
                            p.Material = getMaterialForBlock(id)
                            p.Color = def and def.color or Color3.fromRGB(255,255,255)
                            p.Transparency = (def and def.transparent) and 0.8 or 0
                            p.Size = size
                            p.Position = Vector3.new(snap(cxw), snap(cyw), snap(czw))

                            -- Apply textures to all 6 faces of the merged box
                            TextureApplicator:ApplyBoxTextures(p, id, dx, dy, dz)

                            table.insert(meshParts, p)
                            partsBudget += 1
                            if partsBudget >= MAX_PARTS then return meshParts end
                        end
                    end
                end
            end
        end
        return meshParts
    end

    -- For each face direction (optionally restrict for surface slabs)
    for faceIndex, face in ipairs(FACES) do
        local skipFace = (SURFACE_SLABS and face.y <= 0)
        if not skipFace then
		-- Determine primary axes based on face direction
		local u = face.y ~= 0 and "x" or (face.x ~= 0 and "z" or "x")
		local v = face.y ~= 0 and "z" or "y"
		local w = face.y ~= 0 and "y" or (face.x ~= 0 and "x" or "z")

		-- Get dimensions for this orientation (clamp any Y axis to yLimit)
		local WIDTH = u == "x" and Constants.CHUNK_SIZE_X or (u == "y" and yLimit or Constants.CHUNK_SIZE_Z)
		local HEIGHT = v == "x" and Constants.CHUNK_SIZE_X or (v == "y" and yLimit or Constants.CHUNK_SIZE_Z)
		local DEPTH = w == "x" and Constants.CHUNK_SIZE_X or (w == "y" and yLimit or Constants.CHUNK_SIZE_Z)

		-- Create mask for this slice
		local mask = table.create(WIDTH * HEIGHT, false)

		-- For each depth slice
		for d = 0, DEPTH - 1 do
			-- Compute mask for this slice
			local n = 1
			for h = 0, HEIGHT - 1 do
				for w = 0, WIDTH - 1 do
					-- Get block position
					local x, y, z = 0, 0, 0
					if u == "x" then x = w elseif u == "y" then y = w else z = w end
					if v == "x" then x = h elseif v == "y" then y = h else z = h end
					if face.x ~= 0 then x = d elseif face.y ~= 0 then y = d else z = d end

						-- Check if face should be rendered (voxel.js-style neighbor sampler)
						mask[n] = self:ShouldRenderFace(chunk, x, y, z, face, worldManager, sampler)
					n = n + 1
				end
			end

			-- Generate mesh for this mask
			n = 1
			for h = 0, HEIGHT - 1 do
				for w = 0, WIDTH - 1 do
                    if mask[n] then
						-- Get block position
						local x, y, z = 0, 0, 0
						if u == "x" then x = w elseif u == "y" then y = w else z = w end
						if v == "x" then x = h elseif v == "y" then y = h else z = h end
						if face.x ~= 0 then x = d elseif face.y ~= 0 then y = d else z = d end

						local blockId = chunk:GetBlock(x, y, z)

						-- Find width of face
						local width = 1
						while w + width < WIDTH and mask[n + width] and
							  self:CanMergeBlocks(chunk, x, y, z,
								  u == "x" and (x + width) or x,
								  u == "y" and (y + width) or y,
								  u == "z" and (z + width) or z) do
							mask[n + width] = false
							width = width + 1
						end

						-- Find height of face
						local height = 1
						local done = false
						while h + height < HEIGHT and not done do
							for i = 0, width - 1 do
								local testX = u == "x" and (x + i) or (v == "x" and (x + height) or x)
								local testY = u == "y" and (y + i) or (v == "y" and (y + height) or y)
								local testZ = u == "z" and (z + i) or (v == "z" and (z + height) or z)

								if not mask[n + i + height * WIDTH] or
								   not self:CanMergeBlocks(chunk, x, y, z, testX, testY, testZ) then
									done = true
									break
								end
							end

							if not done then
								-- Zero out mask for merged area
								for i = 0, width - 1 do
									mask[n + i + height * WIDTH] = false
								end
								height = height + 1
							end
						end

					-- Create face part
					local block = Blocks[blockId] or BlockRegistry:GetBlock(blockId)

						if partsBudget >= MAX_PARTS then
							return meshParts
						end

						local part
                        if VISUALS_ENABLED then
                            if FULL_THICKNESS or (SURFACE_SLABS and face.y > 0) then
								-- Full-thickness slab part with collision
								part = PartPool.AcquireColliderPart()
								part.Transparency = block.transparent and 0.8 or 0
								part.CanCollide = true
								part.Material = getMaterialForBlock(blockId)
								part.Color = block.color
							else
								part = PartPool.AcquireFacePart()
								part.Material = getMaterialForBlock(blockId)
								part.Color = block.color
								part.Transparency = block.transparent and 0.8 or 0
							end
						end

					local bs = Constants.BLOCK_SIZE
					local widthStuds = width * bs
					local heightStuds = height * bs

                    -- Dimensions: width/height on plane; slab uses full voxel thickness on normal axis
                    local normalThickness = (FULL_THICKNESS and Constants.BLOCK_SIZE)
                        or ((SURFACE_SLABS and face.y > 0) and Constants.BLOCK_SIZE or FACE_THICKNESS)
					local sizeX = ((u == "x") and widthStuds) or ((v == "x") and heightStuds) or normalThickness
					local sizeY = ((u == "y") and widthStuds) or ((v == "y") and heightStuds) or normalThickness
					local sizeZ = ((u == "z") and widthStuds) or ((v == "z") and heightStuds) or normalThickness

					-- No edge padding; rely on proper face culling and normal offset
                        if VISUALS_ENABLED then
                            part.Size = Vector3.new(snap(sizeX), snap(sizeY), snap(sizeZ))
                        end

						-- World bases
						local baseX = chunk.x * Constants.CHUNK_SIZE_X
						local baseZ = chunk.z * Constants.CHUNK_SIZE_Z

						-- Face plane coordinate in units along normal axis
						local planeUnits
						if face.x ~= 0 then planeUnits = d + (face.x > 0 and 1 or 0) end
						if face.y ~= 0 then planeUnits = d + (face.y > 0 and 1 or 0) end
						if face.z ~= 0 then planeUnits = d + (face.z > 0 and 1 or 0) end

					-- Center positions (studs) per axis with a small inward offset along the face normal.
					local cx, cy, cz
						if u == "x" then
						cx = (baseX + x + width/2) * bs
						elseif v == "x" then
						cx = (baseX + x + height/2) * bs
					else -- w == x (normal axis)
						local plane = (baseX + planeUnits) * bs
						cx = plane - (face.x * (FACE_THICKNESS * 0.5))
						end

					if u == "y" then
						cy = (y + width/2) * bs
					elseif v == "y" then
						cy = (y + height/2) * bs
					else -- w == y (normal axis)
                        local offset = ((FULL_THICKNESS or (SURFACE_SLABS and face.y > 0)) and (normalThickness * 0.5)) or (FACE_THICKNESS * 0.5)
						cy = (planeUnits) * bs - (face.y * offset)
					end

					if u == "z" then
						cz = (baseZ + z + width/2) * bs
					elseif v == "z" then
						cz = (baseZ + z + height/2) * bs
					else -- w == z (normal axis)
						local plane = (baseZ + planeUnits) * bs
                        local offset = ((FULL_THICKNESS or (SURFACE_SLABS and face.y > 0)) and (normalThickness * 0.5)) or (FACE_THICKNESS * 0.5)
						cz = plane - (face.z * offset)
					end


                        if VISUALS_ENABLED then
                            part.Position = Vector3.new(snap(cx), snap(cy), snap(cz))
                        end

					-- Update debug AABB
					if VISUALS_ENABLED and trackAabb then
						local minX = cx - (part.Size.X * 0.5)
						local maxX = cx + (part.Size.X * 0.5)
						local minZ = cz - (part.Size.Z * 0.5)
						local maxZ = cz + (part.Size.Z * 0.5)
						if minX < aabbMinX then aabbMinX = minX end
						if maxX > aabbMaxX then aabbMaxX = maxX end
						if minZ < aabbMinZ then aabbMinZ = minZ end
						if maxZ > aabbMaxZ then aabbMaxZ = maxZ end
					end

					-- Track top faces coverage extents
					if VISUALS_ENABLED and trackTop and face.y > 0 then
						local minX = cx - (part.Size.X * 0.5)
						local maxX = cx + (part.Size.X * 0.5)
						local minZ = cz - (part.Size.Z * 0.5)
						local maxZ = cz + (part.Size.Z * 0.5)
						if minX < topMinX then topMinX = minX end
						if maxX > topMaxX then topMaxX = maxX end
						if minZ < topMinZ then topMinZ = minZ end
						if maxZ > topMaxZ then topMaxZ = maxZ end
					end

                        if VISUALS_ENABLED then
                            table.insert(meshParts, part)
                            partsBudget = partsBudget + 1
                        end

                    -- Optional collision slab for top faces (minecraft-like terrain walkability)
                    if (not FULL_THICKNESS) and (not SURFACE_SLABS) and options.colliders and face.y > 0 then
                            local bs = Constants.BLOCK_SIZE
                            local col = PartPool.AcquireColliderPart()
                            local sizeX = width * bs
                            local sizeY = bs
                            local sizeZ = height * bs
                            col.Size = Vector3.new(snap(sizeX), snap(sizeY), snap(sizeZ))
                            local worldX = (chunk.x * Constants.CHUNK_SIZE_X + x) * bs
                            local worldZ = (chunk.z * Constants.CHUNK_SIZE_Z + z) * bs
                            local centerY = (y + 0.5) * bs
                            col.Position = Vector3.new(snap(worldX + sizeX/2), snap(centerY), snap(worldZ + sizeZ/2))
                            table.insert(meshParts, col)
                            partsBudget = partsBudget + 1
                        end
					end
					n = n + 1
				end
			end
		end
        end
	end

	-- At the end of meshing, if tracking AABB, print actual mesh extents for this chunk
	if trackAabb then
		print(string.format("[VoxelDebug] Chunk %d,%d mesh AABB: X=[%.3f, %.3f], Z=[%.3f, %.3f]",
			chunk.x, chunk.z, snap(aabbMinX), snap(aabbMaxX), snap(aabbMinZ), snap(aabbMaxZ)))
	end

	if trackTop then
		print(string.format("[VoxelDebug] Chunk %d,%d top faces: X=[%.3f, %.3f], Z=[%.3f, %.3f]",
			chunk.x, chunk.z, snap(topMinX), snap(topMaxX), snap(topMinZ), snap(topMaxZ)))
	end

	if trackEdgeOccupancy then
		print(string.format("[VoxelDebug] Chunk %d,%d edge occupancy: -X=%d, +X=%d, -Z=%d, +Z=%d",
			chunk.x, chunk.z, occNegX, occPosX, occNegZ, occPosZ))
	end

	-- Second pass: cross-shaped plants (e.g., tall grass/flowers)
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		for y = 0, yLimit - 1 do
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				local id = chunk:GetBlock(x, y, z)
				if id ~= Constants.BlockType.AIR then
				local def = Blocks[id] or BlockRegistry:GetBlock(id)
					if def and def.crossShape then
						if partsBudget >= MAX_PARTS then return meshParts end

						local center = Vector3.new(
							(chunk.x * Constants.CHUNK_SIZE_X + x + 0.5) * Constants.BLOCK_SIZE,
							(y + 0.5) * Constants.BLOCK_SIZE,
							(chunk.z * Constants.CHUNK_SIZE_Z + z + 0.5) * Constants.BLOCK_SIZE
						)

						local bladeSize = Vector3.new(snap(Constants.BLOCK_SIZE), snap(Constants.BLOCK_SIZE), snap(FACE_THICKNESS))
                        local p1 = PartPool.AcquireFacePart()
                        p1.Material = getMaterialForBlock(id)
                        p1.Color = def.color
                        p1.Transparency = 1 -- Fully transparent, only texture shows
                        p1.Size = bladeSize
						p1.CFrame = CFrame.new(Vector3.new(snap(center.X), snap(center.Y), snap(center.Z))) * CFrame.Angles(0, math.rad(45), 0)

                        local p2 = PartPool.AcquireFacePart()
                        p2.Material = getMaterialForBlock(id)
                        p2.Color = def.color
                        p2.Transparency = 1 -- Fully transparent, only texture shows
                        p2.Size = bladeSize
						p2.CFrame = CFrame.new(Vector3.new(snap(center.X), snap(center.Y), snap(center.Z))) * CFrame.Angles(0, math.rad(-45), 0)

						-- Apply textures to both planes if available
						if def.textures and def.textures.all then
							local textureId = TextureManager:GetTextureId(def.textures.all)
							if textureId then
								local bs = Constants.BLOCK_SIZE
								-- First plane - both sides
								local t1f = PartPool.AcquireTexture()
								t1f.Face = Enum.NormalId.Front
								t1f.Texture = textureId
								t1f.StudsPerTileU = bs
								t1f.StudsPerTileV = bs
								t1f.Parent = p1

								local t1b = PartPool.AcquireTexture()
								t1b.Face = Enum.NormalId.Back
								t1b.Texture = textureId
								t1b.StudsPerTileU = bs
								t1b.StudsPerTileV = bs
								t1b.Parent = p1

								-- Second plane - both sides
								local t2f = PartPool.AcquireTexture()
								t2f.Face = Enum.NormalId.Front
								t2f.Texture = textureId
								t2f.StudsPerTileU = bs
								t2f.StudsPerTileV = bs
								t2f.Parent = p2

								local t2b = PartPool.AcquireTexture()
								t2b.Face = Enum.NormalId.Back
								t2b.Texture = textureId
								t2b.StudsPerTileU = bs
								t2b.StudsPerTileV = bs
								t2b.Parent = p2
							end
						end

						table.insert(meshParts, p1)
						table.insert(meshParts, p2)
						partsBudget = partsBudget + 2
					end
				end
			end
		end
	end

	return meshParts
end

return GreedyMesher