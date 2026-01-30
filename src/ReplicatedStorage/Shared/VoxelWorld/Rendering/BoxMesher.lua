--[[
	BoxMesher.lua
	Generates voxel meshes by merging adjacent blocks into solid cuboid Parts (BOX_MERGE)

	Features:
	- Merges adjacent identical blocks into maximal cuboids for performance
	- Texture-aware merging: only merges blocks with matching texture configurations
	- Applies textures to all 6 faces with correct UV tiling (4 studs per texture tile)
	- Handles both uniform blocks (dirt, stone) and multi-face blocks (grass, logs)

	Texture Merging Behavior:
	- Grass blocks merge with grass blocks âœ“ (same textures: top/side/bottom)
	- Dirt blocks merge with dirt blocks âœ“ (uniform texture)
	- Grass blocks DON'T merge with dirt blocks âœ“ (different block types)
	- Future: Rotatable blocks (logs facing up/down/sideways) will need rotation metadata
]]

local Constants = require(script.Parent.Parent.Core.Constants)
local Config = require(script.Parent.Parent.Core.Config)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local WaterUtils = require(script.Parent.Parent.World.WaterUtils)
local PartPool = require(script.Parent.PartPool)
local Blocks = BlockRegistry.Blocks
-- Texture system
local TextureApplicator = require(script.Parent.TextureApplicator)
local TextureManager = require(script.Parent.TextureManager)
-- Water rendering with Part + WedgePart system
local WaterMesher = require(script.Parent.WaterMesher)

local BoxMesher = {}
BoxMesher.__index = BoxMesher

-- Snap to 1/1000th of a stud to avoid floating-point drift
local function snap(value)
	return math.floor(value * 10000 + 0.5) / 10000
end

-- Get Roblox material for block type
local function getMaterialForBlock(blockId)
	return Enum.Material.Plastic
end

-- Helper: sample block ID including neighbors across chunk borders
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

	-- Only peek existing chunks (don't generate)
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

-- Helper: sample block metadata including neighbors across chunk borders
local function DefaultSampleMetadata(worldManager, chunk, x, y, z)
    if x >= 0 and x < Constants.CHUNK_SIZE_X and z >= 0 and z < Constants.CHUNK_SIZE_Z then
        return chunk:GetMetadata(x, y, z)
    end
    if not worldManager then
        return 0
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

    local neighbor
    if worldManager and worldManager.chunks then
        local key = Constants.ToChunkKey(cx, cz)
        neighbor = worldManager.chunks[key]
    end
    if not neighbor then
        return 0
    end
    return neighbor:GetMetadata(lx, y, lz)
end

function BoxMesher.new()
	return setmetatable({}, BoxMesher)
end

--[[
	Generate mesh for chunk by merging adjacent blocks into maximal solid cuboids

	@param chunk: Chunk to generate mesh for
	@param worldManager: World manager for neighbor sampling
	@param options: Table with optional parameters:
		- maxParts: Maximum number of parts to generate (default 500)
		- sampleBlock: Custom block sampling function
	@return: Array of Parts with textures applied
]]
function BoxMesher:GenerateMesh(chunk, worldManager, options)
	options = options or {}
	local sampler = options.sampleBlock or DefaultSampleBlock
	local meshParts = table.create(256)  -- Pre-allocate for typical chunk
	local partsBudget = 0
	local MAX_PARTS = options.maxParts or 500
	local metaSampler = options.sampleMetadata or DefaultSampleMetadata

	-- Cache constants locally for faster access
	local CHUNK_SX = Constants.CHUNK_SIZE_X
	local CHUNK_SZ = Constants.CHUNK_SIZE_Z
	local CHUNK_SY = Constants.CHUNK_SIZE_Y
	local BLOCK_SIZE = Constants.BLOCK_SIZE
	local AIR = Constants.BlockType.AIR

	-- Limit meshing to tallest column + safety layer
	local yLimit = CHUNK_SY
	if chunk.heightMap then
		local maxH = 0
		for z = 0, CHUNK_SZ - 1 do
			for x = 0, CHUNK_SX - 1 do
				local h = chunk.heightMap[x + z * CHUNK_SX] or 0
				if h > maxH then maxH = h end
			end
		end
		yLimit = math.clamp(maxH + 2, 1, CHUNK_SY)
	end

	local sx, sy, sz = CHUNK_SX, yLimit, CHUNK_SZ

	-- Use flat array with numeric index for visited tracking (MUCH faster than string keys)
	-- Index = x + y*sx + z*sx*sy gives unique int for each position
	local visited = {}
	local sxsy = sx * sy  -- Pre-compute for speed

	-- Block definition cache (avoid repeated BlockRegistry lookups)
	local blockDefCache = {}
	local function getBlockDef(blockId)
		local def = blockDefCache[blockId]
		if def == nil then
			def = Blocks[blockId] or BlockRegistry:GetBlock(blockId) or false
			blockDefCache[blockId] = def
		end
		return def
	end

	-- Helper functions for visited tracking using numeric indices
	local function visitedIndex(x, y, z)
		return x + y * sx + z * sxsy
	end

	local function markVisited(x, y, z)
		visited[visitedIndex(x, y, z)] = true
	end

	local function isVisited(x, y, z)
		return visited[visitedIndex(x, y, z)] == true
	end

	-- Check if block is solid at position (for box merging)
	-- Excludes crossShape and stairShape blocks - they're rendered in separate passes
	local function isSolid(x, y, z)
		if y < 0 or y >= sy then return false end
		local id
		if x >= 0 and x < sx and z >= 0 and z < sz then
			id = chunk:GetBlock(x, y, z)
		else
			id = sampler(worldManager, chunk, x, y, z)
		end
		if id == AIR then return false end
		local def = getBlockDef(id)
		return def and def.solid ~= false and not def.crossShape and not def.stairShape and not def.slabShape and not def.fenceShape
	end

	-- Check if a neighbor FULLY occludes visibility (opaque full cube)
	local function isOccluding(x, y, z)
		if y < 0 or y >= sy then return false end
		local id
		if x >= 0 and x < sx and z >= 0 and z < sz then
			id = chunk:GetBlock(x, y, z)
		else
			id = sampler(worldManager, chunk, x, y, z)
		end
		if id == AIR then return false end
		local def = getBlockDef(id)
		-- Occluding only when it is a full, opaque cube (not slabs/stairs/fences/cross-shapes)
		return def and def.solid ~= false and def.transparent ~= true
			and not def.crossShape and not def.stairShape and not def.slabShape and not def.fenceShape
	end

	-- Check if box touches exposure (not fully occluded by opaque full cubes)
	local function touchesAir(x0, y0, z0, dx, dy, dz)
		for y = y0, y0 + dy - 1 do
			for z = z0, z0 + dz - 1 do
				if not isOccluding(x0 - 1, y, z) or not isOccluding(x0 + dx, y, z) then
					return true
				end
			end
		end
		for x = x0, x0 + dx - 1 do
			for z = z0, z0 + dz - 1 do
				if not isOccluding(x, y0 - 1, z) or not isOccluding(x, y0 + dy, z) then
					return true
				end
			end
		end
		for x = x0, x0 + dx - 1 do
			for y = y0, y0 + dy - 1 do
				if not isOccluding(x, y, z0 - 1) or not isOccluding(x, y, z0 + dz) then
					return true
				end
			end
		end
		return false
	end

	-- Check if two blocks can be merged together (same ID + same texture config)
	-- This ensures blocks with different texture faces (like rotated logs) don't merge incorrectly
	local function canMerge(blockId1, blockId2, x1, y1, z1, x2, y2, z2)
		if blockId1 ~= blockId2 then
			return false
		end

		-- Get block definitions
		local def1 = Blocks[blockId1] or BlockRegistry:GetBlock(blockId1)
		local def2 = Blocks[blockId2] or BlockRegistry:GetBlock(blockId2)

		if not def1 or not def2 then
			return false
		end

		-- Staircase blocks: Only merge if they have the same rotation
		if def1.stairShape or def2.stairShape then
			-- If one is a staircase and the other isn't, don't merge
			if def1.stairShape ~= def2.stairShape then
				return false
			end

			-- Both are staircases - check rotation metadata
			local meta1 = chunk:GetMetadata(x1, y1, z1)
			local meta2 = chunk:GetMetadata(x2, y2, z2)
			local rot1 = Constants.GetRotation(meta1)
			local rot2 = Constants.GetRotation(meta2)

			return rot1 == rot2
		end

		-- Regular blocks: merge if same type
		-- Future enhancement: support other rotatable blocks (logs facing different directions)
		return true
	end

	-- Main box merging algorithm - merge adjacent blocks into maximal cuboids
	for y = 0, sy - 1 do
		for z = 0, sz - 1 do
			for x = 0, sx - 1 do
				if partsBudget >= MAX_PARTS then return meshParts end

				if not isVisited(x, y, z) and isSolid(x, y, z) then
					local seedId = chunk:GetBlock(x, y, z)

					-- Grow along X axis (only merge blocks with matching textures/rotation)
					local dx = 1
					while x + dx < sx and not isVisited(x + dx, y, z) and
						  isSolid(x + dx, y, z) and
						  canMerge(chunk:GetBlock(x + dx, y, z), seedId, x + dx, y, z, x, y, z) do
						dx += 1
					end

					-- Grow along Z axis uniformly (only merge blocks with matching textures/rotation)
					local dz = 1
					local canGrowZ = true
					while canGrowZ and (z + dz) < sz do
						for ix = 0, dx - 1 do
							if isVisited(x + ix, y, z + dz) or
							   not isSolid(x + ix, y, z + dz) or
							   not canMerge(chunk:GetBlock(x + ix, y, z + dz), seedId, x + ix, y, z + dz, x, y, z) then
								canGrowZ = false
								break
							end
						end
						if canGrowZ then dz += 1 end
					end

					-- Grow along Y axis uniformly across XZ area (only merge blocks with matching textures/rotation)
					local dy = 1
					local canGrowY = true
					while canGrowY and (y + dy) < sy do
						for iz = 0, dz - 1 do
							for ix = 0, dx - 1 do
								if isVisited(x + ix, y + dy, z + iz) or
								   not isSolid(x + ix, y + dy, z + iz) or
								   not canMerge(chunk:GetBlock(x + ix, y + dy, z + iz), seedId, x + ix, y + dy, z + iz, x, y, z) then
									canGrowY = false
									break
								end
							end
							if not canGrowY then break end
						end
						if canGrowY then dy += 1 end
					end

					-- Mark all merged blocks as visited
					for iy = 0, dy - 1 do
						for iz = 0, dz - 1 do
							for ix = 0, dx - 1 do
								markVisited(x + ix, y + iy, z + iz, true)
							end
						end
					end

					-- Only create Part if box is exposed to air
					local exposed = touchesAir(x, y, z, dx, dy, dz)
					if exposed then
						local id = seedId
						local def = getBlockDef(id)

						-- Calculate Part size and position using cached BLOCK_SIZE
						local size = Vector3.new(snap(dx * BLOCK_SIZE), snap(dy * BLOCK_SIZE), snap(dz * BLOCK_SIZE))
						local cxw = (chunk.x * sx + x) * BLOCK_SIZE + size.X * 0.5
						local cyw = y * BLOCK_SIZE + size.Y * 0.5
						local czw = (chunk.z * sz + z) * BLOCK_SIZE + size.Z * 0.5

						-- Create merged box Part
						local p = PartPool.AcquireColliderPart()
					p.CanCollide = true
					p.Material = getMaterialForBlock(id)
					p.Color = def and def.color or Color3.fromRGB(255, 255, 255)
					p.Transparency = (def and def.transparent) and 0.8 or 0
					p.Size = size
					p.Position = Vector3.new(snap(cxw), snap(cyw), snap(czw))

						-- Get metadata for rotation (if applicable)
						local metadata = chunk:GetMetadata(x, y, z)

				-- Per-face visibility: check ALL positions along each face
				-- A face is visible if ANY neighbor position is not occluded
				-- This properly handles merged boxes where middle positions may have air holes
				local visibleFaces = {
					[Enum.NormalId.Left] = false,
					[Enum.NormalId.Right] = false,
					[Enum.NormalId.Bottom] = false,
					[Enum.NormalId.Top] = false,
					[Enum.NormalId.Front] = false,
					[Enum.NormalId.Back] = false,
				}

				-- Left face (at x-1): spans Y and Z
				for iy = 0, dy - 1 do
					for iz = 0, dz - 1 do
						if not isOccluding(x - 1, y + iy, z + iz) then
							visibleFaces[Enum.NormalId.Left] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Left] then break end
				end

				-- Right face (at x+dx): spans Y and Z
				for iy = 0, dy - 1 do
					for iz = 0, dz - 1 do
						if not isOccluding(x + dx, y + iy, z + iz) then
							visibleFaces[Enum.NormalId.Right] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Right] then break end
				end

				-- Bottom face (at y-1): spans X and Z
				for ix = 0, dx - 1 do
					for iz = 0, dz - 1 do
						if not isOccluding(x + ix, y - 1, z + iz) then
							visibleFaces[Enum.NormalId.Bottom] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Bottom] then break end
				end

				-- Top face (at y+dy): spans X and Z
				for ix = 0, dx - 1 do
					for iz = 0, dz - 1 do
						if not isOccluding(x + ix, y + dy, z + iz) then
							visibleFaces[Enum.NormalId.Top] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Top] then break end
				end

				-- Front face (at z-1): spans X and Y
				for ix = 0, dx - 1 do
					for iy = 0, dy - 1 do
						if not isOccluding(x + ix, y + iy, z - 1) then
							visibleFaces[Enum.NormalId.Front] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Front] then break end
				end

				-- Back face (at z+dz): spans X and Y
				for ix = 0, dx - 1 do
					for iy = 0, dy - 1 do
						if not isOccluding(x + ix, y + iy, z + dz) then
							visibleFaces[Enum.NormalId.Back] = true
							break
						end
					end
					if visibleFaces[Enum.NormalId.Back] then break end
				end

					-- Apply textures only to faces marked visible
					TextureApplicator:ApplyBoxTextures(p, id, dx, dy, dz, metadata, visibleFaces)

						table.insert(meshParts, p)
						partsBudget += 1
					end
				end
			end
		end
	end

	-- Second pass: staircase blocks with merging
	local stairVisited = {}
	local function isStairVisited(x, y, z)
		return stairVisited[visitedIndex(x, y, z)] == true
	end
	local function markStairVisited(x, y, z)
		stairVisited[visitedIndex(x, y, z)] = true
	end

	for y = 0, yLimit - 1 do
		for z = 0, sz - 1 do
			for x = 0, sx - 1 do
				if partsBudget >= MAX_PARTS then return meshParts end

				local id = chunk:GetBlock(x, y, z)
				if id ~= Constants.BlockType.AIR and not isStairVisited(x, y, z) then
					local def = BlockRegistry:GetBlock(id)
					if def and def.stairShape then
						local metadata = chunk:GetMetadata(x, y, z)
						local rotation = Constants.GetRotation(metadata)
						local verticalOrientation = Constants.GetVerticalOrientation(metadata)
						local isUpsideDown = (verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP)

						-- Determine merge direction based on rotation
						-- NOTE: Corner stairs are rendered per-block. Disable merging for stairs to support corners.
						local canMergeX = false
						local canMergeZ = false

						-- Merge stairs along the allowed axis
						local stretchX = 1
						local stretchZ = 1

						if canMergeX then
							-- Grow along X axis
							while x + stretchX < sx do
								local nextId = chunk:GetBlock(x + stretchX, y, z)
								local nextDef = BlockRegistry:GetBlock(nextId)
								if nextDef and nextDef.stairShape and not isStairVisited(x + stretchX, y, z) then
									local nextMeta = chunk:GetMetadata(x + stretchX, y, z)
									local nextRot = Constants.GetRotation(nextMeta)
									local nextVert = Constants.GetVerticalOrientation(nextMeta)
									-- Only merge stairs with same rotation AND vertical orientation
									if nextRot == rotation and nextVert == verticalOrientation then
										stretchX = stretchX + 1
									else
										break
									end
								else
									break
								end
							end
						elseif canMergeZ then
							-- Grow along Z axis
							while z + stretchZ < sz do
								local nextId = chunk:GetBlock(x, y, z + stretchZ)
								local nextDef = BlockRegistry:GetBlock(nextId)
								if nextDef and nextDef.stairShape and not isStairVisited(x, y, z + stretchZ) then
									local nextMeta = chunk:GetMetadata(x, y, z + stretchZ)
									local nextRot = Constants.GetRotation(nextMeta)
									local nextVert = Constants.GetVerticalOrientation(nextMeta)
									-- Only merge stairs with same rotation AND vertical orientation
									if nextRot == rotation and nextVert == verticalOrientation then
										stretchZ = stretchZ + 1
									else
										break
									end
								else
									break
								end
							end
						end

						-- Mark all merged stairs as visited
						if canMergeX then
							for ix = 0, stretchX - 1 do
								markStairVisited(x + ix, y, z)
							end
						elseif canMergeZ then
							for iz = 0, stretchZ - 1 do
								markStairVisited(x, y, z + iz)
							end
						else
							markStairVisited(x, y, z)
						end

						-- Calculate world position and stretched size
						local wx = (chunk.chunkX * Constants.CHUNK_SIZE_X + x) * Constants.BLOCK_SIZE
						local wy = y * Constants.BLOCK_SIZE
						local wz = (chunk.chunkZ * Constants.CHUNK_SIZE_Z + z) * Constants.BLOCK_SIZE

						local bottomSizeX = stretchX * Constants.BLOCK_SIZE
						local bottomSizeZ = stretchZ * Constants.BLOCK_SIZE

						-- Create two parts for stairs: bottom slab + top step
						-- Vertical orientation determines if stairs are upside-down
						local bottomYOffset, topYOffset
						if isUpsideDown then
							-- Upside-down: base slab at top, step at bottom
							bottomYOffset = Constants.BLOCK_SIZE * 0.75  -- Top position
							topYOffset = Constants.BLOCK_SIZE * 0.25     -- Bottom position
						else
							-- Normal: base slab at bottom, step at top
							bottomYOffset = Constants.BLOCK_SIZE * 0.25  -- Bottom position
							topYOffset = Constants.BLOCK_SIZE * 0.75     -- Top position
						end

						-- Bottom slab (stretched along merge axis, full on other axis, half height)
						local bottomPart = Instance.new("Part")
						bottomPart.Name = "StairBottom"
						bottomPart.Anchored = true
						bottomPart.CanCollide = true
						bottomPart.CastShadow = true
						bottomPart.Material = Enum.Material.Plastic
						bottomPart.Color = def.color or Color3.fromRGB(255, 255, 255)
						bottomPart.TopSurface = Enum.SurfaceType.Smooth
						bottomPart.BottomSurface = Enum.SurfaceType.Smooth
						bottomPart.Size = Vector3.new(bottomSizeX, Constants.BLOCK_SIZE / 2, bottomSizeZ)
						bottomPart.Position = Vector3.new(
							wx + bottomSizeX / 2,
							wy + bottomYOffset,
							wz + bottomSizeZ / 2
						)
						-- Apply texture to bottom slab BEFORE adding to meshParts
						if def.textures and def.textures.all then
							local textureId = TextureManager:GetTextureId(def.textures.all)
							if textureId then
								for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
									local texture = PartPool.AcquireTexture()
									texture.Face = face
									texture.Texture = textureId
									-- Tile per block (not stretched across merged stairs)
									-- Vertical faces use full block height so texture cuts off naturally at half
									if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
										-- Horizontal faces tile per block
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE
									elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
										-- Vertical faces: tile per block width, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									else -- Left or Right
										-- Vertical faces: tile per block depth, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									end
									texture.Parent = bottomPart
								end
							end
						end

						table.insert(meshParts, bottomPart)

						-- Top step (half width/depth based on rotation, half height)
						local topPart = Instance.new("Part")
						topPart.Name = "StairTop"
						topPart.Anchored = true
						topPart.CanCollide = true
						topPart.CastShadow = true
						topPart.Material = Enum.Material.Plastic
						topPart.Color = def.color or Color3.fromRGB(255, 255, 255)
						topPart.TopSurface = Enum.SurfaceType.Smooth
						topPart.BottomSurface = Enum.SurfaceType.Smooth

						-- Determine stair shape (straight, outer, inner) using stored metadata if available
						-- Helper: rotation math
						local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
						local function rotLeft(r)
							return (r + 3) % 4
						end
						local function rotRight(r)
							return (r + 1) % 4
						end
						-- Helper: get grid dir from rotation (Minecraft coordinate system)
						-- North = -Z, South = +Z, East = +X, West = -X
						local function dirFromRot(r)
							if r == ROT_N then return 0, 0, -1 end  -- North faces -Z
							if r == ROT_E then return 1, 0, 0 end   -- East faces +X
							if r == ROT_S then return 0, 0, 1 end   -- South faces +Z
							return -1, 0, 0 -- West faces -X
						end
                        local fx, _, fz = dirFromRot(rotation)
                        local bx, bz = -fx, -fz -- opposite of facing (behind)
                        local rx, _, rz = dirFromRot(rotRight(rotation))
                        local lx, _, lz = dirFromRot(rotLeft(rotation))
                        local function rotOpp(r)
                            return (r + 2) % 4
                        end
                        -- Neighbor metadata helpers
                        local function getStairNeighbor(nx, ny, nz)
                            local nid
                            if nx >= 0 and nx < sx and nz >= 0 and nz < sz then
                                nid = chunk:GetBlock(nx, ny, nz)
                            else
                                nid = sampler(worldManager, chunk, nx, ny, nz)
                            end
							local ndef = BlockRegistry:GetBlock(nid)
							if not (ndef and ndef.stairShape) then return nil end
                            local nmeta = DefaultSampleMetadata(worldManager, chunk, nx, ny, nz)
                            local nrot = Constants.GetRotation(nmeta)
							local nvert = Constants.GetVerticalOrientation(nmeta)
                            if nvert ~= verticalOrientation then return nil end
                            local nshape = Constants.GetStairShape(nmeta)
                            -- Allow linking across different stair types (Minecraft parity)
                            return {rot = nrot, shape = nshape}
						end

                        -- Mojang parity: use front neighbor for OUTER, back neighbor for INNER
                        local frontNeighbor = getStairNeighbor(x + fx, y, z + fz)
                        local backNeighbor = getStairNeighbor(x + bx, y, z + bz)

                        -- Guard from Mojang: do not form a corner if the block in the check direction
                        -- is a same-orientation stair. This mirrors StairsBlock.isDifferentOrientation.
                        local function isDifferentOrientation(checkRot)
                            local dx, _, dz = dirFromRot(checkRot)
                            local n = getStairNeighbor(x + dx, y, z + dz)
                            if not n then return true end -- not a stair or different HALF
                            if n.rot ~= rotation then return true end -- different facing
                            -- Same facing: only allow if neighbor shape is STRAIGHT (vanilla guard)
                            return n.shape == Constants.BlockMetadata.STAIR_SHAPE_STRAIGHT
                        end

						-- Prefer stored shape from metadata for exact parity
						local shapeFromMeta = Constants.GetStairShape(metadata)
						local shape = "straight"
						if shapeFromMeta == Constants.BlockMetadata.STAIR_SHAPE_OUTER_LEFT then shape = "outer_left" end
						if shapeFromMeta == Constants.BlockMetadata.STAIR_SHAPE_OUTER_RIGHT then shape = "outer_right" end
						if shapeFromMeta == Constants.BlockMetadata.STAIR_SHAPE_INNER_LEFT then shape = "inner_left" end
						if shapeFromMeta == Constants.BlockMetadata.STAIR_SHAPE_INNER_RIGHT then shape = "inner_right" end

						-- If no stored shape, derive at render as fallback
						if shape == "straight" then
							-- OUTER: front neighbor perpendicular to our facing
							if frontNeighbor then
                            local frot = frontNeighbor.rot
                            if frot == rotLeft(rotation) and isDifferentOrientation(rotOpp(frot)) then
                                shape = "outer_left"
                            elseif frot == rotRight(rotation) and isDifferentOrientation(rotOpp(frot)) then
                                shape = "outer_right"
                            end
							end

                        -- INNER: back neighbor perpendicular to our facing (no additional guard)
                        if shape == "straight" and backNeighbor then
                            local brot = backNeighbor.rot
                            if brot == rotLeft(rotation) then
                                shape = "inner_left"
                            elseif brot == rotRight(rotation) then
                                shape = "inner_right"
                            end
                        end
						end

						-- Compute top step geometry
						-- Straight: half block along facing direction
						-- Outer: single quarter at (front+side)
						-- Inner: straight half + additional quarter to form L
						-- Minecraft coordinate system: North=-Z, South=+Z, East=+X, West=-X
						local topSizeX, topSizeZ, stepOffset
						if shape == "straight" then
							if rotation == ROT_N then
								-- North faces -Z, step at -Z side
								topSizeX = bottomSizeX
								topSizeZ = Constants.BLOCK_SIZE / 2
								stepOffset = Vector3.new(0, 0, -Constants.BLOCK_SIZE / 4)
							elseif rotation == ROT_E then
								-- East faces +X, step at +X side
								topSizeX = Constants.BLOCK_SIZE / 2
								topSizeZ = bottomSizeZ
								stepOffset = Vector3.new(Constants.BLOCK_SIZE / 4, 0, 0)
							elseif rotation == ROT_S then
								-- South faces +Z, step at +Z side
								topSizeX = bottomSizeX
								topSizeZ = Constants.BLOCK_SIZE / 2
								stepOffset = Vector3.new(0, 0, Constants.BLOCK_SIZE / 4)
							else
								-- West faces -X, step at -X side
								topSizeX = Constants.BLOCK_SIZE / 2
								topSizeZ = bottomSizeZ
								stepOffset = Vector3.new(-Constants.BLOCK_SIZE / 4, 0, 0)
							end
						elseif shape == "outer_left" or shape == "outer_right" then
							-- Outer: quarter step at forward+side quadrant
							-- Uses dirFromRot which now returns correct Minecraft directions
							topSizeX = Constants.BLOCK_SIZE / 2
							topSizeZ = Constants.BLOCK_SIZE / 2
							local qx = (shape == "outer_right") and rx or lx
							local qz = (shape == "outer_right") and rz or lz
							local offX = (qx + fx) * (Constants.BLOCK_SIZE / 4)
							local offZ = (qz + fz) * (Constants.BLOCK_SIZE / 4)
							stepOffset = Vector3.new(offX, 0, offZ)
						else
							-- Inner: straight half-block geometry (L will be formed by adding a quarter below)
							if rotation == ROT_N then
								-- North faces -Z, step at -Z side
								topSizeX = bottomSizeX
								topSizeZ = Constants.BLOCK_SIZE / 2
								stepOffset = Vector3.new(0, 0, -Constants.BLOCK_SIZE / 4)
							elseif rotation == ROT_E then
								-- East faces +X, step at +X side
								topSizeX = Constants.BLOCK_SIZE / 2
								topSizeZ = bottomSizeZ
								stepOffset = Vector3.new(Constants.BLOCK_SIZE / 4, 0, 0)
							elseif rotation == ROT_S then
								-- South faces +Z, step at +Z side
								topSizeX = bottomSizeX
								topSizeZ = Constants.BLOCK_SIZE / 2
								stepOffset = Vector3.new(0, 0, Constants.BLOCK_SIZE / 4)
							else
								-- West faces -X, step at -X side
								topSizeX = Constants.BLOCK_SIZE / 2
								topSizeZ = bottomSizeZ
								stepOffset = Vector3.new(-Constants.BLOCK_SIZE / 4, 0, 0)
							end
						end

						topPart.Size = Vector3.new(topSizeX, Constants.BLOCK_SIZE / 2, topSizeZ)
						topPart.Position = Vector3.new(
							wx + bottomSizeX / 2,
							wy + topYOffset,
							wz + bottomSizeZ / 2
						) + stepOffset

						-- Apply texture to top step BEFORE adding to meshParts
						if def.textures and def.textures.all then
							local textureId = TextureManager:GetTextureId(def.textures.all)
							if textureId then
								for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
									local texture = PartPool.AcquireTexture()
									texture.Face = face
									texture.Texture = textureId

									-- Tile per block (not stretched across merged stairs)
									-- Vertical faces use full block height so texture cuts off naturally at half
									if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
										-- Horizontal faces tile per block
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE
									elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
										-- Vertical faces: tile per block width, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									else -- Left or Right
										-- Vertical faces: tile per block depth, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									end

									texture.Parent = topPart
								end
							end
						end

						table.insert(meshParts, topPart)

                        -- No double-outer: Minecraft does not render a single stair as two outer quarters

						-- Inner corner: add second top half across the perpendicular axis (L-shape = 0.5 + 0.5 - 0.25 = 0.75)
						if shape == "inner_left" or shape == "inner_right" then
							local topPart2 = Instance.new("Part")
							topPart2.Name = "StairTopCorner"
							topPart2.Anchored = true
							topPart2.CanCollide = true
							topPart2.CastShadow = true
						topPart2.Material = Enum.Material.Plastic
							topPart2.Color = def.color or Color3.fromRGB(255, 255, 255)
							topPart2.TopSurface = Enum.SurfaceType.Smooth
							topPart2.BottomSurface = Enum.SurfaceType.Smooth

							-- Determine size and offset: perpendicular half across full length
							local size2X, size2Z
							local extraOffset
							if rotation == ROT_N or rotation == ROT_S then
								-- Straight top covers Z half; second top covers X half across full Z
								size2X = Constants.BLOCK_SIZE / 2
								size2Z = bottomSizeZ
							else
								-- Straight top covers X half; second top covers Z half across full X
								size2X = bottomSizeX
								size2Z = Constants.BLOCK_SIZE / 2
							end
							local q = Constants.BLOCK_SIZE / 4
							local offX, offZ
							if shape == "inner_right" then
								offX, _, offZ = rx * q, 0, rz * q
							else
								offX, _, offZ = lx * q, 0, lz * q
							end
							extraOffset = Vector3.new(offX, 0, offZ)

							topPart2.Size = Vector3.new(size2X, Constants.BLOCK_SIZE / 2, size2Z)
							topPart2.Position = Vector3.new(
								wx + bottomSizeX / 2,
								wy + topYOffset,
								wz + bottomSizeZ / 2
							) + extraOffset

							-- Apply texture to second top quarter BEFORE adding to meshParts
							if def.textures and def.textures.all then
								local textureId = TextureManager:GetTextureId(def.textures.all)
								if textureId then
									for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
										local texture = PartPool.AcquireTexture()
										texture.Face = face
										texture.Texture = textureId
										if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
											texture.StudsPerTileU = Constants.BLOCK_SIZE
											texture.StudsPerTileV = Constants.BLOCK_SIZE
										else
											texture.StudsPerTileU = Constants.BLOCK_SIZE
											texture.StudsPerTileV = Constants.BLOCK_SIZE
										end
										texture.Parent = topPart2
									end
								end
							end

							table.insert(meshParts, topPart2)
						end

						-- Update parts budget
						if shape == "inner_left" or shape == "inner_right" then
							partsBudget += 3 -- bottom + two top quarters
						else
							partsBudget += 2 -- bottom + one top
						end
					end
				end
			end
		end
	end

	-- Third pass: slab blocks with merging
	local slabVisited = {}
	local function isSlabVisited(x, y, z)
		return slabVisited[visitedIndex(x, y, z)] == true
	end
	local function markSlabVisited(x, y, z)
		slabVisited[visitedIndex(x, y, z)] = true
	end

	for y = 0, yLimit - 1 do
		for z = 0, sz - 1 do
			for x = 0, sx - 1 do
				if partsBudget >= MAX_PARTS then return meshParts end

				local id = chunk:GetBlock(x, y, z)
				if id ~= Constants.BlockType.AIR and not isSlabVisited(x, y, z) then
					local def = BlockRegistry:GetBlock(id)
					if def and def.slabShape then
						-- Get vertical orientation metadata
						local metadata = chunk:GetMetadata(x, y, z)
						local verticalOrientation = Constants.GetVerticalOrientation(metadata)
						local isTopSlab = (verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP)

						-- Merge slabs horizontally (X and Z) with same vertical orientation
						local stretchX = 1
						local stretchZ = 1

						-- Try merging along X axis
						while x + stretchX < sx do
							local nextId = chunk:GetBlock(x + stretchX, y, z)
							if nextId == id and not isSlabVisited(x + stretchX, y, z) then
								local nextMeta = chunk:GetMetadata(x + stretchX, y, z)
								local nextVert = Constants.GetVerticalOrientation(nextMeta)
								-- Only merge slabs with same vertical orientation
								if nextVert == verticalOrientation then
									stretchX = stretchX + 1
								else
									break
								end
							else
								break
							end
						end

						-- Try merging along Z axis (only if we didn't merge along X)
						if stretchX == 1 then
							while z + stretchZ < sz do
								local nextId = chunk:GetBlock(x, y, z + stretchZ)
								if nextId == id and not isSlabVisited(x, y, z + stretchZ) then
									local nextMeta = chunk:GetMetadata(x, y, z + stretchZ)
									local nextVert = Constants.GetVerticalOrientation(nextMeta)
									-- Only merge slabs with same vertical orientation
									if nextVert == verticalOrientation then
										stretchZ = stretchZ + 1
									else
										break
									end
								else
									break
								end
							end
						end

						-- Mark all merged slabs as visited
						for ix = 0, stretchX - 1 do
							for iz = 0, stretchZ - 1 do
								markSlabVisited(x + ix, y, z + iz)
							end
						end

						-- Calculate world position and size
						local wx = (chunk.chunkX * Constants.CHUNK_SIZE_X + x) * Constants.BLOCK_SIZE
						local wy = y * Constants.BLOCK_SIZE
						local wz = (chunk.chunkZ * Constants.CHUNK_SIZE_Z + z) * Constants.BLOCK_SIZE

						local slabSizeX = stretchX * Constants.BLOCK_SIZE
						local slabSizeZ = stretchZ * Constants.BLOCK_SIZE

						-- Create slab part (half-height block)
						-- Vertical orientation determines if slab is at top or bottom
						local slabYOffset = isTopSlab and (Constants.BLOCK_SIZE * 0.75) or (Constants.BLOCK_SIZE * 0.25)

						local slabPart = Instance.new("Part")
						slabPart.Name = "Slab"
						slabPart.Anchored = true
						slabPart.CanCollide = true
						slabPart.CastShadow = true
						slabPart.Material = Enum.Material.Plastic
						slabPart.Color = def.color or Color3.fromRGB(255, 255, 255)
						slabPart.TopSurface = Enum.SurfaceType.Smooth
						slabPart.BottomSurface = Enum.SurfaceType.Smooth
						slabPart.Size = Vector3.new(slabSizeX, Constants.BLOCK_SIZE / 2, slabSizeZ)
						slabPart.Position = Vector3.new(
							wx + slabSizeX / 2,
							wy + slabYOffset,
							wz + slabSizeZ / 2
						)

						-- Apply texture to slab BEFORE adding to meshParts
						if def.textures and def.textures.all then
							local textureId = TextureManager:GetTextureId(def.textures.all)
							if textureId then
								for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
									local texture = PartPool.AcquireTexture()
									texture.Face = face
									texture.Texture = textureId
									-- Tile per block (not stretched across merged slabs)
									-- Vertical faces use full block height so texture cuts off naturally at half
									if face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
										-- Horizontal faces tile per block
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE
									elseif face == Enum.NormalId.Front or face == Enum.NormalId.Back then
										-- Vertical faces: tile per block width, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									else -- Left or Right
										-- Vertical faces: tile per block depth, use full block height
										texture.StudsPerTileU = Constants.BLOCK_SIZE
										texture.StudsPerTileV = Constants.BLOCK_SIZE  -- Full block height (cuts off at half)
									end
									texture.Parent = slabPart
								end
							end
						end

						table.insert(meshParts, slabPart)

						-- Update parts budget
						partsBudget += 1
					end
				end
			end
		end
	end

	-- Fourth pass: cross-shaped plants (tall grass, flowers)
	local FACE_THICKNESS = 0.01
	-- Fence pass: optimized (merge rails and avoid duplicate textures)
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		for y = 0, yLimit - 1 do
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				if partsBudget >= MAX_PARTS then return meshParts end

				local id = chunk:GetBlock(x, y, z)
				if id ~= Constants.BlockType.AIR then
					local def = Blocks[id] or BlockRegistry:GetBlock(id)
					if def and def.fenceShape then
						local bs = Constants.BLOCK_SIZE
						local cx = (chunk.x * Constants.CHUNK_SIZE_X + x + 0.5) * bs
						local cz = (chunk.z * Constants.CHUNK_SIZE_Z + z + 0.5) * bs

						-- Neighbor sampling (chunk-border aware)
						local function sample(nx, ny, nz)
							if nx >= 0 and nx < Constants.CHUNK_SIZE_X and nz >= 0 and nz < Constants.CHUNK_SIZE_Z then
								return chunk:GetBlock(nx, ny, nz)
							end
							return DefaultSampleBlock(worldManager, chunk, nx, ny, nz)
						end

						local function neighborKind(dx, dz)
							local nid = sample(x + dx, y, z + dz)
							-- Guard against nil or AIR
							if not nid or nid == Constants.BlockType.AIR then return "none" end
							local ndef = BlockRegistry:GetBlock(nid)
							-- Unknown or missing definitions should never connect
							if not ndef or ndef.name == "Unknown" then return "none" end
							if ndef.fenceShape then return "fence" end
							-- Treat only true full cubes as connectable; exclude chests and other interactables
							if ndef.solid and not ndef.crossShape and not ndef.slabShape and not ndef.stairShape and not ndef.fenceShape then
								-- Do not connect to chests (or any explicitly interactable blocks)
								if nid == Constants.BlockType.CHEST or ndef.interactable == true then
									return "none"
								end
								return "full"
							end
							return "none"
						end

						local kindN = neighborKind(0, -1)
						local kindS = neighborKind(0, 1)
						local kindW = neighborKind(-1, 0)
						local kindE = neighborKind(1, 0)

						-- Dimensions
						local postWidth = bs * 0.25
						local postHeight = bs * 1.0
						local railThickness = bs * 0.20
						-- Symmetric rail positions: 0.25 bottom, 0.5 middle gap, 0.25 top
						-- When stacked vertically, this creates perfect repeating pattern
						local railYOffset1 = bs * 0.25
						local railYOffset2 = bs * 0.75

						-- Invisible collider (1.25 blocks high)
						-- Extends 0.25 blocks above visual post, spans rail width
						local colliderHeight = bs * 1.25
						local hasNorth = (kindN ~= "none")
						local hasSouth = (kindS ~= "none")
						local hasWest = (kindW ~= "none")
						local hasEast = (kindE ~= "none")

						-- Calculate collider bounds based on connections
						local minX, maxX, minZ, maxZ
						if hasWest and hasEast then
							-- Rails extend both X directions: full block width
							minX, maxX = cx - bs/2, cx + bs/2
						elseif hasWest then
							-- Rail extends west: from center to left edge
							minX, maxX = cx - bs/2, cx + postWidth/2
						elseif hasEast then
							-- Rail extends east: from center to right edge
							minX, maxX = cx - postWidth/2, cx + bs/2
						else
							-- No X rails: just post width
							minX, maxX = cx - postWidth/2, cx + postWidth/2
						end

						if hasNorth and hasSouth then
							-- Rails extend both Z directions: full block depth
							minZ, maxZ = cz - bs/2, cz + bs/2
						elseif hasNorth then
							-- Rail extends north: from center to front edge
							minZ, maxZ = cz - bs/2, cz + postWidth/2
						elseif hasSouth then
							-- Rail extends south: from center to back edge
							minZ, maxZ = cz - postWidth/2, cz + bs/2
						else
							-- No Z rails: just post depth
							minZ, maxZ = cz - postWidth/2, cz + postWidth/2
						end

						local colliderSizeX = maxX - minX
						local colliderSizeZ = maxZ - minZ
						local colliderCenterX = (minX + maxX) / 2
						local colliderCenterZ = (minZ + maxZ) / 2

						local collider = PartPool.AcquireColliderPart()
						collider.CanCollide = true
						collider.Transparency = 1
						collider.Size = Vector3.new(snap(colliderSizeX), snap(colliderHeight), snap(colliderSizeZ))
						collider.Position = Vector3.new(snap(colliderCenterX), snap((y * bs) + (colliderHeight * 0.5)), snap(colliderCenterZ))
						table.insert(meshParts, collider)
						partsBudget += 1

						-- Center post (visual only, non-collidable)
						local post = PartPool.AcquireFacePart()
						post.CanCollide = false
						post.Material = getMaterialForBlock(id)
						post.Color = def.color
						post.Transparency = 0
						post.Size = Vector3.new(postWidth, postHeight, postWidth)
						post.Position = Vector3.new(snap(cx), snap((y * bs) + (postHeight * 0.5)), snap(cz))
						-- Apply wood planks texture (e.g., oak planks) to fence post
						if def and def.textures and def.textures.all then
							local textureId = TextureManager:GetTextureId(def.textures.all)
							if textureId then
								for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
										local tex = PartPool.AcquireTexture()
										tex.Face = face
										tex.Texture = textureId
										tex.StudsPerTileU = bs
										tex.StudsPerTileV = bs
										tex.Parent = post
								end
							end
						end
						table.insert(meshParts, post)
						partsBudget += 1

						-- Helper to emit one rail part (visual only, non-collidable)
						local function emitRail(centerX, centerZ, sizeX, sizeZ, yoff)
							if partsBudget >= MAX_PARTS then return end
							local rail = PartPool.AcquireFacePart()
							rail.CanCollide = false
							rail.Material = getMaterialForBlock(id)
							rail.Color = def.color
							rail.Transparency = 0
							rail.Size = Vector3.new(sizeX, railThickness, sizeZ)
							rail.Position = Vector3.new(snap(centerX), snap((y * bs) + yoff), snap(centerZ))
							-- Apply wood planks texture to rail
							if def and def.textures and def.textures.all then
								local textureId = TextureManager:GetTextureId(def.textures.all)
								if textureId then
								for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
										local tex = PartPool.AcquireTexture()
										tex.Face = face
										tex.Texture = textureId
										tex.StudsPerTileU = bs
										tex.StudsPerTileV = bs
										tex.Parent = rail
								end
								end
							end
							table.insert(meshParts, rail)
							partsBudget += 1
						end

						-- Merge rails along East (positive X) through contiguous fences
						if kindE == "fence" and kindW ~= "fence" then
							local run = 1
							while true do
								local nid = sample(x + run, y, z)
								local ndef = BlockRegistry:GetBlock(nid)
								if not (ndef and ndef.fenceShape) then break end
								run += 1
							end
							local gaps = run - 1
							if gaps > 0 then
								local length = gaps * bs
								local centerX = cx + (length * 0.5)
								for _, yoff in ipairs({railYOffset1, railYOffset2}) do
									emitRail(centerX, cz, length, railThickness, yoff)
								end
							end
						end

						-- Merge rails along South (positive Z) through contiguous fences
						if kindS == "fence" and kindN ~= "fence" then
							local run = 1
							while true do
								local nid = sample(x, y, z + run)
								local ndef = BlockRegistry:GetBlock(nid)
								if not (ndef and ndef.fenceShape) then break end
								run += 1
							end
							local gaps = run - 1
							if gaps > 0 then
								local length = gaps * bs
								local centerZ = cz + (length * 0.5)
								for _, yoff in ipairs({railYOffset1, railYOffset2}) do
									emitRail(cx, centerZ, railThickness, length, yoff)
								end
							end
						end

						-- Half-rails to connect full cubes (neighbor won't emit)
						local halfLen = bs * 0.5
						local function emitHalf(dx, dz)
							local sizeX = (dx ~= 0) and halfLen or railThickness
							local sizeZ = (dz ~= 0) and halfLen or railThickness
							local offX = (dx ~= 0) and (dx * halfLen * 0.5) or 0
							local offZ = (dz ~= 0) and (dz * halfLen * 0.5) or 0
							for _, yoff in ipairs({railYOffset1, railYOffset2}) do
								emitRail(cx + offX, cz + offZ, sizeX, sizeZ, yoff)
							end
						end

						if kindN == "full" then emitHalf(0, -1) end
						if kindS == "full" then emitHalf(0, 1) end
						if kindW == "full" then emitHalf(-1, 0) end
						if kindE == "full" then emitHalf(1, 0) end
					end
				end
			end
		end
	end
	for x = 0, Constants.CHUNK_SIZE_X - 1 do
		for y = 0, yLimit - 1 do
			for z = 0, Constants.CHUNK_SIZE_Z - 1 do
				if partsBudget >= MAX_PARTS then return meshParts end

				local id = chunk:GetBlock(x, y, z)
				if id ~= Constants.BlockType.AIR then
					local def = Blocks[id] or BlockRegistry:GetBlock(id)
					if def and def.crossShape then
						local bs = Constants.BLOCK_SIZE
						local center = Vector3.new(
							(chunk.x * Constants.CHUNK_SIZE_X + x + 0.5) * bs,
							(y + 0.5) * bs,
							(chunk.z * Constants.CHUNK_SIZE_Z + z + 0.5) * bs
						)

						local bladeSize = Vector3.new(snap(bs), snap(bs), snap(FACE_THICKNESS))

						-- Create two perpendicular planes at 45Â° angles
						local p1 = PartPool.AcquireFacePart()
						p1.Material = getMaterialForBlock(id)
						p1.Color = def.color
						p1.Transparency = 1 -- Fully transparent, only texture shows
						p1.Size = bladeSize
						p1.CFrame = CFrame.new(Vector3.new(snap(center.X), snap(center.Y), snap(center.Z))) *
									CFrame.Angles(0, math.rad(45), 0)

						local p2 = PartPool.AcquireFacePart()
						p2.Material = getMaterialForBlock(id)
						p2.Color = def.color
						p2.Transparency = 1 -- Fully transparent, only texture shows
						p2.Size = bladeSize
						p2.CFrame = CFrame.new(Vector3.new(snap(center.X), snap(center.Y), snap(center.Z))) *
									CFrame.Angles(0, math.rad(-45), 0)

						-- Apply textures to both planes if available
						-- Handle two-block tall plants (tall grass, flowers) with half=lower/upper variants
						local textureName = nil
						if def.textures then
							-- Support metadata-based texture selection for any cross-shaped block with supportsVariants
							if def.supportsVariants then
								-- Check metadata for half property (upper vs lower)
								local metadata = chunk:GetMetadata(x, y, z)
								local verticalOrientation = Constants.GetVerticalOrientation(metadata)
								local isUpperHalf = (verticalOrientation == Constants.BlockMetadata.VERTICAL_TOP)

								-- Minecraft convention: lower block = "lower" texture, upper block = "upper" texture
								if isUpperHalf then
									textureName = def.textures.upper or def.textures.all
								else
									textureName = def.textures.lower or def.textures.all
								end

								-- Debug logging (enable in Config.DEBUG.LOG_CROSSSHAPE_TEXTURES)
								if Config.DEBUG.LOG_CROSSSHAPE_TEXTURES then
									print(string.format("[CrossShape] id=%d, name=%s, meta=%d, isUpper=%s -> tex=%s",
										id, def.name or "?", metadata, tostring(isUpperHalf), tostring(textureName)))
								end
							else
								textureName = def.textures.all
							end
						end

						if textureName then
							local textureId = TextureManager:GetTextureId(textureName)

							-- Extended debug logging with texture ID
							if Config.DEBUG.LOG_CROSSSHAPE_TEXTURES and textureId then
								print(string.format("[CrossShape] Applying textureId=%s for textureName=%s", tostring(textureId), tostring(textureName)))
							end

							if textureId then
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
						partsBudget += 2
					end
				end
			end
		end
	end

	-- Water meshing: use dedicated WaterMesher for Part + WedgePart rendering
	local waterMesher = WaterMesher.new()
	local waterOptions = {
		sampleBlock = sampler,
		sampleMetadata = metaSampler,
		maxWaterParts = math.max(0, MAX_PARTS - partsBudget)
	}
	local waterParts = waterMesher:GenerateMesh(chunk, worldManager, waterOptions)
	for _, part in ipairs(waterParts) do
		table.insert(meshParts, part)
		partsBudget = partsBudget + 1
		if partsBudget >= MAX_PARTS then
			break
		end
	end

	return meshParts
end

return BoxMesher

