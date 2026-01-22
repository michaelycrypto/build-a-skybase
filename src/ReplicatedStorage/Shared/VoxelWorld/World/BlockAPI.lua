--[[
	BlockAPI.lua
	Provides a clean interface for block operations
]]

local RunService = game:GetService("RunService")
local Constants = require(script.Parent.Parent.Core.Constants)
local EventManager = require(game.ReplicatedStorage.Shared.EventManager)
local BlockRegistry = require(script.Parent.BlockRegistry)

local BlockAPI = {}
BlockAPI.__index = BlockAPI

function BlockAPI.new(worldManager)
	local self = setmetatable({
		worldManager = worldManager,
		pendingChanges = {} -- For client-side prediction
	}, BlockAPI)

	return self
end

-- Set block at world coordinates
function BlockAPI:SetBlock(x: number, y: number, z: number, blockId: number): boolean
	if RunService:IsClient() then
		-- Client-side: Send to server and predict change
		EventManager:SendToServer("BlockChange", {
			x = x,
			y = y,
			z = z,
			blockId = blockId
		})

		-- Store pending change
		local key = string.format("%d,%d,%d", x, y, z)
		self.pendingChanges[key] = {
			x = x,
			y = y,
			z = z,
			blockId = blockId,
			time = tick()
		}

		-- Apply change locally for immediate feedback
		return self.worldManager:SetBlock(x, y, z, blockId)
	else
		-- Server-side: Apply directly
		return self.worldManager:SetBlock(x, y, z, blockId)
	end
end

-- Remove block at world coordinates
function BlockAPI:RemoveBlock(x: number, y: number, z: number): boolean
	return self:SetBlock(x, y, z, Constants.BlockType.AIR)
end

-- Get block at world coordinates
function BlockAPI:GetBlock(x: number, y: number, z: number): number
	return self.worldManager:GetBlock(x, y, z)
end

-- Handle block change rejection from server
function BlockAPI:HandleRejection(x: number, y: number, z: number)
	if not RunService:IsClient() then
		return
	end

	-- Remove pending change
	local key = string.format("%d,%d,%d", x, y, z)
	local change = self.pendingChanges[key]
	if change then
		self.pendingChanges[key] = nil

		-- Revert block to previous state
		local currentBlock = self:GetBlock(x, y, z)
		if currentBlock == change.blockId then
			-- Only revert if it hasn't been changed again
			self.worldManager:SetBlock(x, y, z, Constants.BlockType.AIR)
		end
	end
end

-- Clean up old pending changes
function BlockAPI:CleanupPendingChanges()
	if not RunService:IsClient() then
		return
	end

	local now = tick()
	for key, change in pairs(self.pendingChanges) do
		if now - change.time > 5 then -- Remove changes older than 5 seconds
			self.pendingChanges[key] = nil
		end
	end
end

-- Get block face that was hit by a ray
-- Returns: blockPos, faceNormal, hitPosition (precise world position where ray hit the block face)
function BlockAPI:GetTargetedBlockFace(origin: Vector3, direction: Vector3, maxDistance: number): (Vector3, Vector3, Vector3)
	local rayOrigin = origin
	local rayDirection = direction.Unit
	local maxDist = maxDistance or 50

	-- Convert to block coordinates
	local startX = math.floor(rayOrigin.X / Constants.BLOCK_SIZE)
	local startY = math.floor(rayOrigin.Y / Constants.BLOCK_SIZE)
	local startZ = math.floor(rayOrigin.Z / Constants.BLOCK_SIZE)

	-- Ray parameters for DDA algorithm
	local tMaxX = math.abs(rayDirection.X) > 0.001 and (((startX + (rayDirection.X > 0 and 1 or 0)) * Constants.BLOCK_SIZE - rayOrigin.X) / rayDirection.X) or math.huge
	local tMaxY = math.abs(rayDirection.Y) > 0.001 and (((startY + (rayDirection.Y > 0 and 1 or 0)) * Constants.BLOCK_SIZE - rayOrigin.Y) / rayDirection.Y) or math.huge
	local tMaxZ = math.abs(rayDirection.Z) > 0.001 and (((startZ + (rayDirection.Z > 0 and 1 or 0)) * Constants.BLOCK_SIZE - rayOrigin.Z) / rayDirection.Z) or math.huge

	local tDeltaX = math.abs(rayDirection.X) > 0.001 and (Constants.BLOCK_SIZE / math.abs(rayDirection.X)) or math.huge
	local tDeltaY = math.abs(rayDirection.Y) > 0.001 and (Constants.BLOCK_SIZE / math.abs(rayDirection.Y)) or math.huge
	local tDeltaZ = math.abs(rayDirection.Z) > 0.001 and (Constants.BLOCK_SIZE / math.abs(rayDirection.Z)) or math.huge

	local stepX = rayDirection.X > 0 and 1 or -1
	local stepY = rayDirection.Y > 0 and 1 or -1
	local stepZ = rayDirection.Z > 0 and 1 or -1

	local currentX, currentY, currentZ = startX, startY, startZ
	local lastX, lastY, lastZ = currentX, currentY, currentZ
	local hitT = 0

    -- Helper: compute entry/exit for one axis for ray vs slab/box
    -- Returns: (intersects:boolean, tEnter:number|nil, faceNormal:Vector3|nil)
    local function testSlabIntersection(blockX, blockY, blockZ, blockId, metadata)
        if not Constants.IsSlab(blockId) then
            return true, nil, nil -- Not a slab, treat as full block (no AABB details)
        end

        -- Get slab orientation
        local orientation = Constants.GetVerticalOrientation(metadata)
        local isTopSlab = (orientation == Constants.BlockMetadata.VERTICAL_TOP)

        -- Define slab bounds in world space
        local minX = blockX * Constants.BLOCK_SIZE
        local minZ = blockZ * Constants.BLOCK_SIZE
        local maxX = (blockX + 1) * Constants.BLOCK_SIZE
        local maxZ = (blockZ + 1) * Constants.BLOCK_SIZE

        local minY, maxY
        if isTopSlab then
            -- Top slab: Y from 0.5 to 1.0
            minY = blockY * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
            maxY = (blockY + 1) * Constants.BLOCK_SIZE
        else
            -- Bottom slab: Y from 0.0 to 0.5
            minY = blockY * Constants.BLOCK_SIZE
            maxY = blockY * Constants.BLOCK_SIZE + Constants.BLOCK_SIZE * 0.5
        end

        -- Ray-AABB intersection test (compute entry/exit per axis)
        local function axisEntryExit(minV, maxV, o, d)
            if math.abs(d) < 0.001 then
                if o < minV or o > maxV then
                    return math.huge, -math.huge -- no intersection on this axis
                else
                    return -math.huge, math.huge -- inside slab bounds along this axis
                end
            end
            local t1 = (minV - o) / d
            local t2 = (maxV - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            return t1, t2
        end

        local tx1, tx2 = axisEntryExit(minX, maxX, rayOrigin.X, rayDirection.X)
        local ty1, ty2 = axisEntryExit(minY, maxY, rayOrigin.Y, rayDirection.Y)
        local tz1, tz2 = axisEntryExit(minZ, maxZ, rayOrigin.Z, rayDirection.Z)

        local tEnter = math.max(tx1, math.max(ty1, tz1))
        local tExit  = math.min(tx2, math.min(ty2, tz2))

        if tEnter > tExit or tExit < 0 then
            return false, nil, nil -- no intersection in front
        end

        -- Determine which axis we entered through (largest entry time)
        local face
        if tEnter == tx1 then
            -- Entered via X plane
            face = Vector3.new(rayDirection.X > 0 and -1 or 1, 0, 0)
        elseif tEnter == ty1 then
            -- Entered via Y plane
            face = Vector3.new(0, rayDirection.Y > 0 and -1 or 1, 0)
        else
            -- Entered via Z plane
            face = Vector3.new(0, 0, rayDirection.Z > 0 and -1 or 1)
        end

        -- Clamp tEnter to be non-negative to avoid origins inside volume
        if tEnter < 0 then
            tEnter = 0
        end

        return true, tEnter, face
    end

    -- Helper function: test ray against stair composite AABBs derived from metadata
    -- Returns: (intersects:boolean, tEnter:number|nil, faceNormal:Vector3|nil)
    local function testStairIntersection(blockX, blockY, blockZ, blockId, metadata)
        local def = BlockRegistry:GetBlock(blockId)
        if not (def and def.stairShape) then
            return true, nil, nil -- not a stair; treat as full block by caller
        end

        local bs = Constants.BLOCK_SIZE
        local baseX = blockX * bs
        local baseY = blockY * bs
        local baseZ = blockZ * bs

        local rot = Constants.GetRotation(metadata)
        local vert = Constants.GetVerticalOrientation(metadata)
        local shape = Constants.GetStairShape(metadata)

        local isUpsideDown = (vert == Constants.BlockMetadata.VERTICAL_TOP)

        -- Local ranges in [0, bs]
        local xL0, xL1 = 0, bs * 0.5
        local xH0, xH1 = bs * 0.5, bs
        local zL0, zL1 = 0, bs * 0.5
        local zH0, zH1 = bs * 0.5, bs

        -- Y ranges
        local slabY0, slabY1
        local stepY0, stepY1
        if isUpsideDown then
            slabY0, slabY1 = baseY + bs * 0.5, baseY + bs
            stepY0, stepY1 = baseY, baseY + bs * 0.5
        else
            slabY0, slabY1 = baseY, baseY + bs * 0.5
            stepY0, stepY1 = baseY + bs * 0.5, baseY + bs
        end

        -- Helper: add AABB to list (world coordinates)
        local boxes = {}
        local function addBox(minX, maxX, minY, maxY, minZ, maxZ)
            boxes[#boxes + 1] = {minX = minX, maxX = maxX, minY = minY, maxY = maxY, minZ = minZ, maxZ = maxZ}
        end

        -- Base slab is always half-block covering full XZ
        addBox(baseX + 0, baseX + bs, slabY0, slabY1, baseZ + 0, baseZ + bs)

        -- Top step: build based on rotation and shape
        local ROT_N, ROT_E, ROT_S, ROT_W = Constants.BlockMetadata.ROTATION_NORTH, Constants.BlockMetadata.ROTATION_EAST, Constants.BlockMetadata.ROTATION_SOUTH, Constants.BlockMetadata.ROTATION_WEST
        local SH = Constants.BlockMetadata

        local function addStraightTop()
            if rot == ROT_N then
                addBox(baseX + 0, baseX + bs, stepY0, stepY1, baseZ + zH0, baseZ + zH1)
            elseif rot == ROT_S then
                addBox(baseX + 0, baseX + bs, stepY0, stepY1, baseZ + zL0, baseZ + zL1)
            elseif rot == ROT_E then
                addBox(baseX + xH0, baseX + xH1, stepY0, stepY1, baseZ + 0, baseZ + bs)
            else -- ROT_W
                addBox(baseX + xL0, baseX + xL1, stepY0, stepY1, baseZ + 0, baseZ + bs)
            end
        end

        local function addQuarterTop(isRight)
            -- Quarter at (front + side)
            if rot == ROT_N then
                if isRight then
                    addBox(baseX + xH0, baseX + xH1, stepY0, stepY1, baseZ + zH0, baseZ + zH1)
                else
                    addBox(baseX + xL0, baseX + xL1, stepY0, stepY1, baseZ + zH0, baseZ + zH1)
                end
            elseif rot == ROT_E then
                if isRight then
                    addBox(baseX + xH0, baseX + xH1, stepY0, stepY1, baseZ + zL0, baseZ + zL1)
                else
                    addBox(baseX + xH0, baseX + xH1, stepY0, stepY1, baseZ + zH0, baseZ + zH1)
                end
            elseif rot == ROT_S then
                if isRight then
                    addBox(baseX + xL0, baseX + xL1, stepY0, stepY1, baseZ + zL0, baseZ + zL1)
                else
                    addBox(baseX + xH0, baseX + xH1, stepY0, stepY1, baseZ + zL0, baseZ + zL1)
                end
            else -- ROT_W
                if isRight then
                    addBox(baseX + xL0, baseX + xL1, stepY0, stepY1, baseZ + zH0, baseZ + zH1)
                else
                    addBox(baseX + xL0, baseX + xL1, stepY0, stepY1, baseZ + zL0, baseZ + zL1)
                end
            end
        end

        if shape == SH.STAIR_SHAPE_STRAIGHT then
            addStraightTop()
        elseif shape == SH.STAIR_SHAPE_OUTER_LEFT then
            addQuarterTop(false)
        elseif shape == SH.STAIR_SHAPE_OUTER_RIGHT then
            addQuarterTop(true)
        elseif shape == SH.STAIR_SHAPE_INNER_LEFT then
            addStraightTop()
            addQuarterTop(false)
        elseif shape == SH.STAIR_SHAPE_INNER_RIGHT then
            addStraightTop()
            addQuarterTop(true)
        else
            -- Unknown shape → fallback to straight
            addStraightTop()
        end

        -- Ray-AABB intersection across all AABBs: choose nearest positive entry
        local function axisEntryExit(minV, maxV, o, d)
            if math.abs(d) < 0.001 then
                if o < minV or o > maxV then
                    return math.huge, -math.huge
                else
                    return -math.huge, math.huge
                end
            end
            local t1 = (minV - o) / d
            local t2 = (maxV - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            return t1, t2
        end

        local bestT = math.huge
        local bestFace = nil
        for i = 1, #boxes do
            local b = boxes[i]
            local tx1, tx2 = axisEntryExit(b.minX, b.maxX, rayOrigin.X, rayDirection.X)
            local ty1, ty2 = axisEntryExit(b.minY, b.maxY, rayOrigin.Y, rayDirection.Y)
            local tz1, tz2 = axisEntryExit(b.minZ, b.maxZ, rayOrigin.Z, rayDirection.Z)
            local tEnter = math.max(tx1, math.max(ty1, tz1))
            local tExit  = math.min(tx2, math.min(ty2, tz2))
            if tEnter <= tExit and tExit >= 0 then
                -- Determine face at entry
                local face
                if tEnter == tx1 then
                    face = Vector3.new(rayDirection.X > 0 and -1 or 1, 0, 0)
                elseif tEnter == ty1 then
                    face = Vector3.new(0, rayDirection.Y > 0 and -1 or 1, 0)
                else
                    face = Vector3.new(0, 0, rayDirection.Z > 0 and -1 or 1)
                end
                if tEnter < 0 then tEnter = 0 end
                if tEnter < bestT then
                    bestT = tEnter
                    bestFace = face
                end
            end
        end

        if bestFace then
            return true, bestT, bestFace
        end
        return false, nil, nil
    end

    -- Helper function: test ray against fence composite AABBs (post + rails based on neighbors)
    -- Returns: (intersects:boolean, tEnter:number|nil, faceNormal:Vector3|nil)
    local function testFenceIntersection(blockX, blockY, blockZ, blockId, metadata)
        local def = BlockRegistry:GetBlock(blockId)
        if not (def and def.fenceShape) then
            return true, nil, nil -- not a fence; treat as full block by caller
        end

        local bs = Constants.BLOCK_SIZE
        local baseX = blockX * bs
        local baseY = blockY * bs
        local baseZ = blockZ * bs

        -- Sample neighbors to determine which rails should exist
        local function sampleNeighbor(dx, dz)
            local nid = self:GetBlock(blockX + dx, blockY, blockZ + dz)
            if not nid or nid == Constants.BlockType.AIR then return "none" end
            local ndef = BlockRegistry:GetBlock(nid)
            if not ndef or ndef.name == "Unknown" then return "none" end
            if ndef.fenceShape then return "fence" end
            -- Connect to full solid blocks (excluding special shapes and interactables)
            if ndef.solid and not ndef.crossShape and not ndef.slabShape and not ndef.stairShape and not ndef.fenceShape then
                if nid == Constants.BlockType.CHEST or ndef.interactable == true then
                    return "none"
                end
                return "full"
            end
            return "none"
        end

        local kindN = sampleNeighbor(0, -1)
        local kindS = sampleNeighbor(0, 1)
        local kindW = sampleNeighbor(-1, 0)
        local kindE = sampleNeighbor(1, 0)

        -- Build AABBs for fence geometry
        local boxes = {}
        local function addBox(minX, maxX, minY, maxY, minZ, maxZ)
            boxes[#boxes + 1] = {minX = minX, maxX = maxX, minY = minY, maxY = maxY, minZ = minZ, maxZ = maxZ}
        end

        -- Center post (always present): 0.25 wide, full height, centered
        local postWidth = bs * 0.25
        local postHeight = bs * 1.0
        local postHalf = postWidth / 2
        addBox(
            baseX + bs/2 - postHalf, baseX + bs/2 + postHalf,
            baseY, baseY + postHeight,
            baseZ + bs/2 - postHalf, baseZ + bs/2 + postHalf
        )

        -- Rail dimensions
        local railThickness = bs * 0.20
        local railHalf = railThickness / 2
        -- Symmetric rail positions: 0.25 bottom, 0.5 middle gap, 0.25 top
        -- When stacked vertically, this creates perfect repeating pattern
        local railYOffset1 = bs * 0.25
        local railYOffset2 = bs * 0.75

        -- Helper to add rails in a direction
        local function addRails(dx, dz, kind)
            if kind == "none" then return end

            local length, railMinX, railMaxX, railMinZ, railMaxZ

            if dz ~= 0 then
                -- North/South rails (extend along Z)
                railMinX = baseX + bs/2 - railHalf
                railMaxX = baseX + bs/2 + railHalf
                if kind == "full" then
                    -- Half-rail to solid block
                    if dz < 0 then
                        -- North: extend from center to block edge
                        railMinZ = baseZ
                        railMaxZ = baseZ + bs/2
                    else
                        -- South: extend from center to block edge
                        railMinZ = baseZ + bs/2
                        railMaxZ = baseZ + bs
                    end
                else
                    -- Full rail to neighboring fence
                    if dz < 0 then
                        railMinZ = baseZ
                        railMaxZ = baseZ + bs/2
                    else
                        railMinZ = baseZ + bs/2
                        railMaxZ = baseZ + bs
                    end
                end
            else
                -- East/West rails (extend along X)
                railMinZ = baseZ + bs/2 - railHalf
                railMaxZ = baseZ + bs/2 + railHalf
                if kind == "full" then
                    -- Half-rail to solid block
                    if dx < 0 then
                        -- West: extend from center to block edge
                        railMinX = baseX
                        railMaxX = baseX + bs/2
                    else
                        -- East: extend from center to block edge
                        railMinX = baseX + bs/2
                        railMaxX = baseX + bs
                    end
                else
                    -- Full rail to neighboring fence
                    if dx < 0 then
                        railMinX = baseX
                        railMaxX = baseX + bs/2
                    else
                        railMinX = baseX + bs/2
                        railMaxX = baseX + bs
                    end
                end
            end

            -- Add two rails (upper and lower)
            addBox(railMinX, railMaxX, baseY + railYOffset1 - railHalf, baseY + railYOffset1 + railHalf, railMinZ, railMaxZ)
            addBox(railMinX, railMaxX, baseY + railYOffset2 - railHalf, baseY + railYOffset2 + railHalf, railMinZ, railMaxZ)
        end

        -- Add rails for each direction that connects
        addRails(0, -1, kindN) -- North
        addRails(0, 1, kindS)  -- South
        addRails(-1, 0, kindW) -- West
        addRails(1, 0, kindE)  -- East

        -- Ray-AABB intersection across all AABBs: choose nearest positive entry
        local function axisEntryExit(minV, maxV, o, d)
            if math.abs(d) < 0.001 then
                if o < minV or o > maxV then
                    return math.huge, -math.huge
                else
                    return -math.huge, math.huge
                end
            end
            local t1 = (minV - o) / d
            local t2 = (maxV - o) / d
            if t1 > t2 then t1, t2 = t2, t1 end
            return t1, t2
        end

        local bestT = math.huge
        local bestFace = nil
        for i = 1, #boxes do
            local b = boxes[i]
            local tx1, tx2 = axisEntryExit(b.minX, b.maxX, rayOrigin.X, rayDirection.X)
            local ty1, ty2 = axisEntryExit(b.minY, b.maxY, rayOrigin.Y, rayDirection.Y)
            local tz1, tz2 = axisEntryExit(b.minZ, b.maxZ, rayOrigin.Z, rayDirection.Z)
            local tEnter = math.max(tx1, math.max(ty1, tz1))
            local tExit  = math.min(tx2, math.min(ty2, tz2))
            if tEnter <= tExit and tExit >= 0 then
                -- Determine face at entry
                local face
                if tEnter == tx1 then
                    face = Vector3.new(rayDirection.X > 0 and -1 or 1, 0, 0)
                elseif tEnter == ty1 then
                    face = Vector3.new(0, rayDirection.Y > 0 and -1 or 1, 0)
                else
                    face = Vector3.new(0, 0, rayDirection.Z > 0 and -1 or 1)
                end
                if tEnter < 0 then tEnter = 0 end
                if tEnter < bestT then
                    bestT = tEnter
                    bestFace = face
                end
            end
        end

        if bestFace then
            return true, bestT, bestFace
        end
        return false, nil, nil
    end

	-- Step through blocks until we hit something
	while true do
		local block = self:GetBlock(currentX, currentY, currentZ)

		-- Skip air and flowing water (flowing water is non-targetable, allows placement through it)
        if block ~= Constants.BlockType.AIR and block ~= Constants.BlockType.FLOWING_WATER then
            -- Check if ray actually intersects shape (slab or stair); otherwise continue
            local metadata = self.worldManager:GetBlockMetadata(currentX, currentY, currentZ)
            local def = BlockRegistry:GetBlock(block)

            local intersects, tHit, hitFace = false, nil, nil
            if def and def.slabShape then
                intersects, tHit, hitFace = testSlabIntersection(currentX, currentY, currentZ, block, metadata)
            elseif def and def.stairShape then
                intersects, tHit, hitFace = testStairIntersection(currentX, currentY, currentZ, block, metadata)
            elseif def and def.fenceShape then
                intersects, tHit, hitFace = testFenceIntersection(currentX, currentY, currentZ, block, metadata)
            else
                intersects = true -- treat as full block
            end

            if intersects then
                local hitPos = Vector3.new(
                    currentX * Constants.BLOCK_SIZE,
                    currentY * Constants.BLOCK_SIZE,
                    currentZ * Constants.BLOCK_SIZE
                )
                local faceNormal
                local preciseHitPos

                if tHit ~= nil and hitFace ~= nil then
                    faceNormal = hitFace
                    preciseHitPos = rayOrigin + rayDirection * tHit
                else
                    -- Full block fallback: derive from DDA stepping
                    faceNormal = Vector3.new(
                        lastX - currentX,
                        lastY - currentY,
                        lastZ - currentZ
                    )
                    preciseHitPos = rayOrigin + rayDirection * hitT
                end
                return hitPos, faceNormal, preciseHitPos
            end
            -- If no intersection (ray passed through empty part), continue
        end

		-- Store last position
		lastX, lastY, lastZ = currentX, currentY, currentZ

		-- Step to next block and track the hit distance
		if tMaxX < tMaxY and tMaxX < tMaxZ then
			hitT = tMaxX
			tMaxX = tMaxX + tDeltaX
			currentX = currentX + stepX
		elseif tMaxY < tMaxZ then
			hitT = tMaxY
			tMaxY = tMaxY + tDeltaY
			currentY = currentY + stepY
		else
			hitT = tMaxZ
			tMaxZ = tMaxZ + tDeltaZ
			currentZ = currentZ + stepZ
		end

		-- Check if we've gone too far
		local distance = hitT
		if distance > maxDist then
			return nil, nil, nil
		end
	end
end

return BlockAPI
