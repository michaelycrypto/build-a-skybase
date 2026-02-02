--[[
	AdvancedPathfinding.lua

	Minecraft-inspired advanced pathfinding system with node-based navigation,
	multi-stage paths, door/gate interaction, and dynamic recalculation.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
local BlockRegistry = require(ReplicatedStorage.Shared.VoxelWorld.World.BlockRegistry)

local BLOCK_SIZE = Constants.BLOCK_SIZE

local AdvancedPathfinding = {}

-- ============================================================================
-- PATH NODE TYPES (Minecraft-inspired)
-- ============================================================================

AdvancedPathfinding.PathNodeType = {
	-- Basic terrain types
	BLOCKED = -1.0,
	OPEN = 0.0,
	WALKABLE = 0.0,

	-- Door and gate types
	WALKABLE_DOOR = 0.0,
	TRAPDOOR = 0.0,
	FENCE = -1.0,
	DOOR_OPEN = 0.0,
	DOOR_WOOD_CLOSED = -1.0,
	DOOR_IRON_CLOSED = -1.0,

	-- Hazardous terrain
	LAVA = -1.0,
	WATER = 8.0,
	WATER_BORDER = 8.0,
	DANGER_FIRE = 8.0,
	DANGER_CACTUS = 8.0,
	DANGER_OTHER = 8.0,

	-- Special navigation
	RAIL = 0.0,
	UNLOADED = -1.0,

	-- TDS-specific voxel types
	VOXEL_SOLID = -1.0,
	VOXEL_AIR = 0.0,
	VOXEL_WATER = 8.0,
	VOXEL_LAVA = -1.0,
	VOXEL_DANGER = 8.0,
	VOXEL_DOOR = 0.0,
	VOXEL_GATE = -1.0,
	VOXEL_FENCE = -1.0
}

-- ============================================================================
-- PATH NODE CLASS
-- ============================================================================

local PathNode = {}
PathNode.__index = PathNode

function PathNode.new(x, y, z, nodeType)
	return setmetatable({
		x = x,
		y = y,
		z = z,
		type = nodeType or AdvancedPathfinding.PathNodeType.OPEN,
		costMalus = 0,  -- Additional movement cost penalty
		distanceToTarget = 0,
		distanceToStart = 0,
		heapIdx = -1,
		visited = false,
		previous = nil,
		hash = nil,  -- Cached hash for performance
	}, PathNode)
end

function PathNode:getHash()
	if not self.hash then
		self.hash = string.format("%d,%d,%d", self.x, self.y, self.z)
	end
	return self.hash
end

function PathNode:getWorldPosition()
	return Vector3.new(
		self.x * BLOCK_SIZE + BLOCK_SIZE / 2,
		self.y * BLOCK_SIZE + BLOCK_SIZE / 2,
		self.z * BLOCK_SIZE + BLOCK_SIZE / 2
	)
end

function PathNode:distanceTo(other)
	local dx = self.x - other.x
	local dy = self.y - other.y
	local dz = self.z - other.z
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function PathNode:distanceToSq(other)
	local dx = self.x - other.x
	local dy = self.y - other.y
	local dz = self.z - other.z
	return dx * dx + dy * dy + dz * dz
end

-- ============================================================================
-- NODE CACHE SYSTEM
-- ============================================================================

local NodeCache = {}
NodeCache.__index = NodeCache

function NodeCache.new()
	return setmetatable({
		nodes = {},  -- hash -> node
		maxSize = 10000,
		hitCount = 0,
		missCount = 0
	}, NodeCache)
end

function NodeCache:get(x, y, z, nodeType)
	local hash = string.format("%d,%d,%d", x, y, z)
	local node = self.nodes[hash]

	if node then
		self.hitCount = self.hitCount + 1
		-- Update type if different
		if node.type ~= nodeType then
			node.type = nodeType
			node.costMalus = 0  -- Reset cost when type changes
		end
		return node
	else
		self.missCount = self.missCount + 1
		node = PathNode.new(x, y, z, nodeType)
		self.nodes[hash] = node

		-- Evict old nodes if cache is full
		if #self.nodes > self.maxSize then
			local toRemove = {}
			local count = 0
			for k, _ in pairs(self.nodes) do
				if count < 1000 then  -- Remove oldest 1000 nodes
					table.insert(toRemove, k)
					count = count + 1
				else
					break
				end
			end
			for _, k in ipairs(toRemove) do
				self.nodes[k] = nil
			end
		end

		return node
	end
end

function NodeCache:clear()
	self.nodes = {}
	self.hitCount = 0
	self.missCount = 0
end

function NodeCache:getStats()
	local total = self.hitCount + self.missCount
	local hitRate = total > 0 and (self.hitCount / total) or 0
	return {
		size = #self.nodes,
		maxSize = self.maxSize,
		hitRate = hitRate,
		hits = self.hitCount,
		misses = self.missCount
	}
end

-- ============================================================================
-- PATH NODE EVALUATOR BASE CLASS
-- ============================================================================

local PathNodeEvaluator = {}
PathNodeEvaluator.__index = PathNodeEvaluator

function PathNodeEvaluator.new(nodeCache)
	return setmetatable({
		nodeCache = nodeCache or NodeCache.new(),
		startNode = nil,
		targetNode = nil,
		maxDistance = 64,  -- Maximum pathfinding distance in blocks
		canOpenDoors = false,
		canBreakBlocks = false,
		maxFallDistance = 3,
		preferredTerrain = {},
        avoidedTerrain = {},
        typeMalus = {} -- nodeType -> extra cost like Minecraft's malus
	}, PathNodeEvaluator)
end

function PathNodeEvaluator:getStart()
	return self.startNode
end

function PathNodeEvaluator:getNodeType(_x, _y, _z)
	-- Override in subclasses
	return AdvancedPathfinding.PathNodeType.OPEN
end

function PathNodeEvaluator:getNeighbors(node, successors)
	-- Basic 4-directional movement (override in subclasses for diagonals)
	local neighbors = {
		{ x = 1, z = 0, cost = 1.0 },
		{ x = -1, z = 0, cost = 1.0 },
		{ x = 0, z = 1, cost = 1.0 },
		{ x = 0, z = -1, cost = 1.0 }
	}

	for _, dir in ipairs(neighbors) do
		local nx, ny, nz = node.x + dir.x, node.y, node.z + dir.z
		local nodeType = self:getNodeType(nx, ny, nz)

		if nodeType >= 0 then  -- Not blocked
			local neighborNode = self.nodeCache:get(nx, ny, nz, nodeType)
			local cost = dir.cost + self:getAdditionalCost(neighborNode)
			table.insert(successors, { node = neighborNode, cost = cost })
		end
	end
end

function PathNodeEvaluator:getAdditionalCost(node)
	-- Base implementation - override in subclasses
	local cost = 0

	-- Distance malus (prefer shorter paths)
	cost = cost + node.distanceToStart * 0.01

    -- Node type specific costs
    if node.type == AdvancedPathfinding.PathNodeType.WATER then
        cost = cost + 2.0  -- Water is slower to move through
    elseif node.type == AdvancedPathfinding.PathNodeType.DANGER_FIRE or
           node.type == AdvancedPathfinding.PathNodeType.DANGER_CACTUS or
           node.type == AdvancedPathfinding.PathNodeType.DANGER_OTHER then
        cost = cost + 8.0  -- Avoid dangerous areas
    end

    -- Add malus table (Minecraft-style per-type penalties/bonuses)
    local malus = self.typeMalus and self.typeMalus[node.type]
    if malus then
        cost = cost + malus
    end

	-- Terrain preferences
	for _, preferred in ipairs(self.preferredTerrain) do
		if node.type == preferred then
			cost = cost - 0.5  -- Bonus for preferred terrain
			break
		end
	end

	for _, avoided in ipairs(self.avoidedTerrain) do
		if node.type == avoided then
			cost = cost + 2.0  -- Penalty for avoided terrain
			break
		end
	end

	return cost
end

function PathNodeEvaluator:setTypeMalus(nodeType, malus)
    self.typeMalus[nodeType] = malus
end

function PathNodeEvaluator:getNode(x, y, z)
	local nodeType = self:getNodeType(x, y, z)
	return self.nodeCache:get(x, y, z, nodeType)
end

function PathNodeEvaluator:canReach(node)
	-- Basic implementation - can reach any non-blocked node
	return node.type >= 0
end

function PathNodeEvaluator:findNearestNode(x, y, z, range)
	range = range or 8
	local nearest = nil
	local nearestDist = math.huge

	for dx = -range, range do
		for dy = -range, range do
			for dz = -range, range do
				local nx, ny, nz = x + dx, y + dy, z + dz
				local node = self:getNode(nx, ny, nz)
				if self:canReach(node) then
					local dist = node:distanceToSq(self.startNode)
					if dist < nearestDist then
						nearest = node
						nearestDist = dist
					end
				end
			end
		end
	end

	return nearest
end

-- ============================================================================
-- GROUND EVALUATOR (Most Common)
-- ============================================================================

local GroundEvaluator = setmetatable({}, PathNodeEvaluator)
GroundEvaluator.__index = GroundEvaluator

function GroundEvaluator.new(nodeCache, voxelWorldService)
	local self = PathNodeEvaluator.new(nodeCache)
	setmetatable(self, GroundEvaluator)

	-- Ground-specific settings
    self.maxStepUp = 1
    self.maxStepDown = 8
	self.canOpenDoors = true
	self.canBreakBlocks = false

	-- Voxel world integration
	self.voxelWorldService = voxelWorldService

	return self
end

function GroundEvaluator:getNodeType(x, y, z)
	if not self.voxelWorldService or not self.voxelWorldService.worldManager then
		return AdvancedPathfinding.PathNodeType.BLOCKED
	end

	local wm = self.voxelWorldService.worldManager

	-- Use Minecraft-style footprint checking for pathfinding
	-- Convert block coordinates to world coordinates for footprint checking
	local _worldX = x * BLOCK_SIZE + BLOCK_SIZE / 2
	local _worldZ = z * BLOCK_SIZE + BLOCK_SIZE / 2
	local _worldY = y * BLOCK_SIZE + BLOCK_SIZE / 2

	-- Check if this position has a valid footprint (can stand here)
	-- This mirrors the MobEntityService probeFootprint logic but simplified for pathfinding
	local blockId = wm:GetBlock(x, y, z)
	local blockType = AdvancedPathfinding.voxelTypeToNodeType(blockId)

	-- Primary check: can we stand on this block?
	if blockType == AdvancedPathfinding.PathNodeType.WALKABLE then
		-- Check headroom (2 blocks above)
		local head1Id = wm:GetBlock(x, y + 1, z)
		local head2Id = wm:GetBlock(x, y + 2, z)
		local head1Type = AdvancedPathfinding.voxelTypeToNodeType(head1Id)
		local head2Type = AdvancedPathfinding.voxelTypeToNodeType(head2Id)

		if head1Type == AdvancedPathfinding.PathNodeType.OPEN and
		   head2Type == AdvancedPathfinding.PathNodeType.OPEN then
			-- Check for minimal edge support (Minecraft allows edge-standing)
			local hasEdgeSupport = false

			-- Check adjacent blocks for additional support
			local adjacentOffsets = {
				{1, 0}, {-1, 0}, {0, 1}, {0, -1}
			}

			for _, offset in ipairs(adjacentOffsets) do
				local adjX, adjZ = x + offset[1], z + offset[2]
				local adjBlockId = wm:GetBlock(adjX, y, adjZ)
				local adjType = AdvancedPathfinding.voxelTypeToNodeType(adjBlockId)

				if adjType == AdvancedPathfinding.PathNodeType.WALKABLE then
					hasEdgeSupport = true
					break
				end
			end

			-- Allow standing with just center support (for narrow platforms)
			-- or with at least one adjacent block support
			if hasEdgeSupport then
				return AdvancedPathfinding.PathNodeType.WALKABLE
			else
				-- Check if this is truly isolated or just a narrow platform
				-- For narrow platforms (1-block wide), center support is enough
				return AdvancedPathfinding.PathNodeType.WALKABLE
			end
		end
	elseif blockType == AdvancedPathfinding.PathNodeType.OPEN then
		-- Check if we can stand on the block below (for falling/jumping)
		local belowBlockId = wm:GetBlock(x, y - 1, z)
		local belowType = AdvancedPathfinding.voxelTypeToNodeType(belowBlockId)

		if belowType == AdvancedPathfinding.PathNodeType.WALKABLE then
			-- Check headroom at the current level
			local head1Id = wm:GetBlock(x, y, z)
			local head2Id = wm:GetBlock(x, y + 1, z)
			local head1Type = AdvancedPathfinding.voxelTypeToNodeType(head1Id)
			local head2Type = AdvancedPathfinding.voxelTypeToNodeType(head2Id)

			if head1Type == AdvancedPathfinding.PathNodeType.OPEN and
			   head2Type == AdvancedPathfinding.PathNodeType.OPEN then
				return AdvancedPathfinding.PathNodeType.WALKABLE
			end
		end
	end

	-- If we didn't early-return as WALKABLE or via OPEN-below-WALKABLE logic,
	-- treat solid blocks without headroom as BLOCKED. Preserve special types.
	if blockType == AdvancedPathfinding.PathNodeType.WALKABLE then
		return AdvancedPathfinding.PathNodeType.BLOCKED
	end

	-- Return the basic type for special cases (WATER, LAVA, FENCE, etc.)
	return blockType
end

function GroundEvaluator:getNeighbors(node, successors)
	-- Enhanced neighbor generation for complex paths (U-shapes, detours)
	local neighbors = {
		-- Cardinal directions (horizontal movement)
		{ x = 1, z = 0, y = 0, cost = 1.0 },
		{ x = -1, z = 0, y = 0, cost = 1.0 },
		{ x = 0, z = 1, y = 0, cost = 1.0 },
		{ x = 0, z = -1, y = 0, cost = 1.0 },
		-- Diagonals (√2 ≈ 1.414) - essential for smooth U-turns
		{ x = 1, z = 1, y = 0, cost = 1.414 },
		{ x = 1, z = -1, y = 0, cost = 1.414 },
		{ x = -1, z = 1, y = 0, cost = 1.414 },
		{ x = -1, z = -1, y = 0, cost = 1.414 },
		-- Extended range for U-shaped navigation (allows wider exploration)
		{ x = 2, z = 0, y = 0, cost = 2.0 },
		{ x = -2, z = 0, y = 0, cost = 2.0 },
		{ x = 0, z = 2, y = 0, cost = 2.0 },
		{ x = 0, z = -2, y = 0, cost = 2.0 },
		-- Vertical movement (for climbing/descending)
		{ x = 0, z = 0, y = 1, cost = 1.5 },  -- Up
		{ x = 0, z = 0, y = -1, cost = 1.2 }, -- Down
	}

	for _, dir in ipairs(neighbors) do
		local nx, ny, nz = node.x + dir.x, node.y + dir.y, node.z + dir.z

		-- Check if movement is valid (no corner cutting, obstacle avoidance)
		local canMove = true
		if dir.y == 0 then  -- Horizontal movement
			if dir.x ~= 0 and dir.z ~= 0 then
				-- Diagonal movement: check corner cutting
				local side1Clear = self:getNodeType(node.x + dir.x, node.y, node.z) >= 0
				local side2Clear = self:getNodeType(node.x, node.y, node.z + dir.z) >= 0
				if not (side1Clear and side2Clear) then
					canMove = false
				end
			elseif math.abs(dir.x) == 2 or math.abs(dir.z) == 2 then
				-- Extended range movement: check intermediate blocks
				local stepX = dir.x > 0 and 1 or (dir.x < 0 and -1 or 0)
				local stepZ = dir.z > 0 and 1 or (dir.z < 0 and -1 or 0)

				-- Check all blocks along the path
				for i = 1, math.max(math.abs(dir.x), math.abs(dir.z)) do
					local checkX = node.x + (stepX * i)
					local checkZ = node.z + (stepZ * i)
					local checkType = self:getNodeType(checkX, node.y, checkZ)
					if checkType < 0 then
						canMove = false
						break
					end
				end
			end
		end

		-- Special handling for vertical movement
		if dir.y ~= 0 then
			-- For vertical movement, check if there's a climbable surface
			local canClimb = self:canClimbAt(nx, ny, nz, dir.y > 0)
			if not canClimb then
				canMove = false
			end
		end

		if canMove then
			local nodeType = self:getNodeType(nx, ny, nz)

			if nodeType >= 0 then  -- Not blocked
				-- Check step height constraints for horizontal movement
				local heightDiff = ny - node.y
				local validHeight = true

				if dir.y == 0 then  -- Horizontal movement
					-- Use step constraints
					validHeight = heightDiff <= self.maxStepUp and heightDiff >= -self.maxStepDown
				else  -- Vertical movement
					-- Allow larger vertical movements (for stairs, ladders)
					validHeight = math.abs(heightDiff) <= 4  -- Allow up to 4 blocks vertical
				end

				if validHeight then
					local neighborNode = self.nodeCache:get(nx, ny, nz, nodeType)
					local cost = dir.cost + self:getAdditionalCost(neighborNode)

					-- Add movement cost penalties
					if dir.y > 0 then
						cost = cost + dir.y * 0.5  -- Penalty for climbing up
					elseif dir.y < 0 then
						cost = cost + math.abs(dir.y) * 0.3  -- Smaller penalty for climbing down
					elseif heightDiff > 0 then
						cost = cost + heightDiff * 0.2  -- Small penalty for stepping up
					elseif heightDiff < 0 then
						cost = cost + math.abs(heightDiff) * 0.3  -- Larger penalty for stepping down
					end

					table.insert(successors, { node = neighborNode, cost = cost })
				end
			end
		end
	end
end

function GroundEvaluator:canClimbAt(x, y, z, _climbingUp)
	-- Check if the mob can climb at this position
	-- For now, allow vertical movement if the target position is walkable
	local targetType = self:getNodeType(x, y, z)
	if targetType >= 0 then
		-- Check if there's a surface to climb on (adjacent blocks)
		local adjacentWalkable = false
		local directions = {
			{1, 0}, {-1, 0}, {0, 1}, {0, -1}
		}

		for _, dir in ipairs(directions) do
			local ax, az = x + dir[1], z + dir[2]
			local adjacentType = self:getNodeType(ax, y, az)
			if adjacentType == AdvancedPathfinding.PathNodeType.WALKABLE then
				adjacentWalkable = true
				break
			end
		end

		return adjacentWalkable
	end
	return false
end

-- Door interaction methods (to be expanded with door mechanics)
function GroundEvaluator:isDoor(_blockId)
	local _Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)
	-- TDS doesn't have doors yet, but this is where door logic would go
	return false
end

function GroundEvaluator:isDoorOpen(_x, _y, _z)
	-- TODO: Check door state when doors are implemented
	return true
end

function GroundEvaluator:canOpenDoorAt(x, y, z)
	if not self.canOpenDoors then return false end
	local blockId = self.voxelWorldService.worldManager:GetBlock(x, y, z)
	return self:isDoor(blockId)
end

-- ============================================================================
-- ADVANCED PATHFINDER (A* Implementation)
-- ============================================================================

local AdvancedPathfinder = {}
AdvancedPathfinder.__index = AdvancedPathfinder

function AdvancedPathfinder.new()
	return setmetatable({
		nodeCache = NodeCache.new(),
		maxIterations = 2000,  -- Increased for complex U-shaped paths
		timeout = 8.0,  -- Increased timeout for complex navigation
		debug = false,
		-- U-shaped path optimization parameters
		explorationBonus = 0.3,  -- Encourage exploration for detours
		maxDetourFactor = 2.0   -- Allow paths up to 2x the direct distance
	}, AdvancedPathfinder)
end

function AdvancedPathfinder:findPath(startX, startY, startZ, goalX, goalY, goalZ, evaluator)
	evaluator = evaluator or GroundEvaluator.new(self.nodeCache)

	-- Convert world coordinates to block coordinates
	local startBX = math.floor(startX / BLOCK_SIZE)
	local startBY = math.floor(startY / BLOCK_SIZE)
	local startBZ = math.floor(startZ / BLOCK_SIZE)

	local goalBX = math.floor(goalX / BLOCK_SIZE)
	local goalBY = math.floor(goalY / BLOCK_SIZE)
	local goalBZ = math.floor(goalZ / BLOCK_SIZE)

	return self:findPathBlocks(startBX, startBY, startBZ, goalBX, goalBY, goalBZ, evaluator)
end

function AdvancedPathfinder:findPathBlocks(startBX, startBY, startBZ, goalBX, goalBY, goalBZ, evaluator)
	local startTime = os.clock()

	-- Get start and goal nodes
	local startNode = evaluator:getNode(startBX, startBY, startBZ)
	local goalNode = evaluator:getNode(goalBX, goalBY, goalBZ)

	if not startNode or not goalNode then
		return nil
	end

	if not evaluator:canReach(startNode) or not evaluator:canReach(goalNode) then
		return nil
	end

	evaluator.startNode = startNode
	evaluator.targetNode = goalNode

	-- A* data structures
	local openSet = {}  -- Min-heap would be better, but using simple list for now
	local openSetLookup = {}
	local closedSet = {}

	local gScore = {}  -- distance from start
	local fScore = {}  -- estimated total distance

	local function getNodeKey(node)
		return node:getHash()
	end

	local function heuristic(a, b)
		-- Enhanced heuristic for U-shaped and complex paths
		local dx = math.abs(a.x - b.x)
		local dy = math.abs(a.y - b.y)
		local dz = math.abs(a.z - b.z)

		-- Base Manhattan distance
		local manhattan = dx + dy + dz

		-- For U-shaped navigation, add exploration bonus to encourage detours
		-- This helps find paths that go around obstacles
		local explorationBonus = self.explorationBonus or 0.3

		-- Penalize straight-line paths slightly to encourage exploration
		-- This helps with U-shapes where direct path might be blocked
		local detourBonus = manhattan * explorationBonus

		return manhattan + detourBonus
	end

	-- Initialize
	gScore[getNodeKey(startNode)] = 0
	fScore[getNodeKey(startNode)] = heuristic(startNode, goalNode)
	table.insert(openSet, startNode)
	openSetLookup[getNodeKey(startNode)] = true

	local iterations = 0

	while #openSet > 0 and iterations < self.maxIterations do
		iterations = iterations + 1

		-- Find node with lowest fScore
		local currentIdx = 1
		local current = openSet[1]
		local lowestF = fScore[getNodeKey(current)]

		for i = 2, #openSet do
			local node = openSet[i]
			local f = fScore[getNodeKey(node)]
			if f < lowestF then
				lowestF = f
				current = node
				currentIdx = i
			end
		end

		-- Remove from open set
		table.remove(openSet, currentIdx)
		openSetLookup[getNodeKey(current)] = nil

		-- Check if we reached the goal
		if current.x == goalBX and current.y == goalBY and current.z == goalBZ then
			local path = self:reconstructPath(current)
			if self.debug then
				print(string.format("Path found in %.3fs, %d iterations, %d nodes",
					os.clock() - startTime, iterations, #path))
			end
			return path
		end

		-- Mark as visited
		closedSet[getNodeKey(current)] = true

		-- Get neighbors
		local successors = {}
		evaluator:getNeighbors(current, successors)

		for _, successorData in ipairs(successors) do
			local neighbor = successorData.node
			local moveCost = successorData.cost

			local neighborKey = getNodeKey(neighbor)

			if closedSet[neighborKey] then
				continue
			end

			local tentativeG = gScore[getNodeKey(current)] + moveCost

			if not openSetLookup[neighborKey] then
				-- New node discovered
				table.insert(openSet, neighbor)
				openSetLookup[neighborKey] = true
			elseif tentativeG >= (gScore[neighborKey] or math.huge) then
				continue  -- Not a better path
			end

			-- This is the best path so far
			neighbor.previous = current
			gScore[neighborKey] = tentativeG
			fScore[neighborKey] = tentativeG + heuristic(neighbor, goalNode)
		end

		-- Timeout check
		if os.clock() - startTime > self.timeout then
			if self.debug then
				warn("Pathfinding timeout after", self.timeout, "seconds")
			end
			break
		end
	end

	if self.debug then
		print(string.format("Path not found (%.3fs, %d iterations)", os.clock() - startTime, iterations))
	end
	return nil
end

function AdvancedPathfinder:reconstructPath(goalNode)
	local path = {}
	local current = goalNode

	while current do
		table.insert(path, 1, current:getWorldPosition())
		current = current.previous
	end

	-- Post-process path for U-shaped navigation optimization
	path = self:optimizeUShapedPath(path)

	return path
end

function AdvancedPathfinder:optimizeUShapedPath(path)
	if #path < 3 then return path end

	local optimized = {path[1]}  -- Always include start
	local i = 2

	while i < #path do
		local current = path[i]
		local nextPoint = path[i + 1]

		if nextPoint then
			-- Check if we can skip intermediate points for smoother U-turns
			local canSkip = true

			-- Look ahead to see if there's a better connection
			for j = i + 2, math.min(i + 4, #path) do
				local futurePoint = path[j]
				if futurePoint then
					-- Check if direct path from current to future point is clear
					-- This helps with U-shapes by allowing wider turns
					local directClear = self:isDirectPathClear(current, futurePoint)
					if directClear then
						-- Skip to this future point
						table.insert(optimized, futurePoint)
						i = j
						canSkip = false
						break
					end
				end
			end

			if canSkip then
				-- Add current point if we can't skip ahead
				table.insert(optimized, current)
				i = i + 1
			end
		else
			-- Add current point if no next point
			table.insert(optimized, current)
			i = i + 1
		end
	end

	-- Always include goal
	if #path > 1 then
		table.insert(optimized, path[#path])
	end

	return optimized
end

function AdvancedPathfinder:isDirectPathClear(point1, point2)
    -- Only allow skipping if horizontal distance is small AND net vertical rise ≤ 1 block
    local delta = point2 - point1
    local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude
    local netRise = delta.Y
    if netRise > (BLOCK_SIZE + 1e-4) then
        return false
    end
    return horizontal < 8
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function AdvancedPathfinding.createGroundEvaluator(voxelWorldService, canOpenDoors, canBreakBlocks)
    local evaluator = GroundEvaluator.new(nil, voxelWorldService)
    evaluator.canOpenDoors = canOpenDoors or false
    evaluator.canBreakBlocks = canBreakBlocks or false
    return evaluator
end

function AdvancedPathfinding.findPath(startPos, goalPos, evaluator)
	local pathfinder = AdvancedPathfinder.new()
	return pathfinder:findPath(
		startPos.X, startPos.Y, startPos.Z,
		goalPos.X, goalPos.Y, goalPos.Z,
		evaluator
	)
end

function AdvancedPathfinding.getNodeCacheStats()
	local pathfinder = AdvancedPathfinder.new()
	return pathfinder.nodeCache:getStats()
end

function AdvancedPathfinding.clearNodeCache()
	local pathfinder = AdvancedPathfinder.new()
	pathfinder.nodeCache:clear()
end

-- ============================================================================
-- INTEGRATION HELPERS
-- ============================================================================

-- Convert TDS block IDs to pathfinding node types
function AdvancedPathfinding.voxelTypeToNodeType(blockId)
	-- Robust mapping using BlockRegistry: solid => WALKABLE; non-solid/cross-shape => OPEN
	if blockId == Constants.BlockType.AIR then
		return AdvancedPathfinding.PathNodeType.OPEN
	end

	-- Specific obstacles
	if blockId == Constants.BlockType.OAK_FENCE then
		return AdvancedPathfinding.PathNodeType.FENCE
	end

	local def = BlockRegistry and BlockRegistry.GetBlock and BlockRegistry:GetBlock(blockId)
	if not def then
		return AdvancedPathfinding.PathNodeType.BLOCKED
	end

	if def.solid == true then
		return AdvancedPathfinding.PathNodeType.WALKABLE
	end

	-- Non-solid (including cross-shaped) counts as open/passable space for headroom
	return AdvancedPathfinding.PathNodeType.OPEN
end

-- Get block type name from block ID (for debugging)
function AdvancedPathfinding.getBlockTypeName(blockId)
	local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

	for name, id in pairs(Constants.BlockType) do
		if id == blockId then
			return name
		end
	end
	return "UNKNOWN_" .. tostring(blockId)
end

return AdvancedPathfinding
