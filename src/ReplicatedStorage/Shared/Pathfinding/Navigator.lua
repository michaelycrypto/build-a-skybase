local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AdvancedPathfinding = require(ReplicatedStorage.Shared.Pathfinding.AdvancedPathfinding)

local Navigator = {}
Navigator.__index = Navigator

function Navigator.new(voxelWorldService, moveFn, lineClearFn, opts)
    local self = setmetatable({}, Navigator)
    self.voxelWorldService = voxelWorldService
    self.moveFn = moveFn -- function(selfSvc, mob, dirOrDisplacement, speed, dt) -> bool
    self.lineClearFn = lineClearFn -- function(selfSvc, from, to, startY) -> bool
    self.opts = opts or {}
    self.blockSize = (self.opts and self.opts.blockSize) or 4

    -- Path/navigation state
    self.path = nil
    self.pathIndex = 1
    self.pathTarget = nil
    self.repathAt = 0

    -- Timing / stuck detection (Minecraft-like behavior)
    self.lastProgressPos = nil
    self.lastProgressTime = 0
    self.stuckSeconds = self.opts.stuckSeconds or 1.25
    self.repathCooldown = self.opts.repathCooldown or 1.0

    -- Movement
    self.speed = 0

    -- Per-type malus map (Minecraft BlockPathTypes equivalent)
    self.typeMalus = {}

    return self
end

function Navigator:setTypeMalus(nodeType, malus)
    self.typeMalus[nodeType] = malus
end

function Navigator:_makeEvaluator()
    local evaluator = AdvancedPathfinding.createGroundEvaluator(self.voxelWorldService, true, false)
    -- Apply malus table
    for nodeType, malus in pairs(self.typeMalus) do
        evaluator:setTypeMalus(nodeType, malus)
    end
    return evaluator
end

function Navigator:clearPath(mob)
    self.path = nil
    self.pathIndex = 1
    self.pathTarget = nil
    self.repathAt = 0
    self.lastProgressPos = nil
    self.lastProgressTime = 0

    local brain = mob.brain
    if brain then
        brain.path = nil
        brain.pathIndex = nil
        brain.pathTarget = nil
        brain.repathAt = 0
    end
end

function Navigator:hasPath()
    return self.path ~= nil and self.pathIndex ~= nil and self.path[self.pathIndex] ~= nil
end

function Navigator:moveToPosition(mob, goal, speed, maxRangeBlocks)
    self.speed = speed or self.speed or (mob.definition and mob.definition.walkSpeed) or 4
    self.pathTarget = goal

    local evaluator = self:_makeEvaluator()
    local path = AdvancedPathfinding.findPath(mob.position, goal, evaluator)
    if path and #path > 0 then
        self.path = path
        self.pathIndex = 1
        self.repathAt = os.clock() + (self.repathCooldown or 1.0)
        self.lastProgressPos = mob.position
        self.lastProgressTime = os.clock()

        local brain = mob.brain
        if brain then
            brain.path = path
            brain.pathIndex = 1
            brain.pathTarget = goal
            brain.repathAt = self.repathAt
        end
        return true
    end
    return false
end

function Navigator:tick(selfSvc, mob, dt)
    if not self:hasPath() then return false end

    local idx = self.pathIndex
    local waypoint = self.path[idx]
    local toWP = waypoint - mob.position
    local dist = Vector3.new(toWP.X, 0, toWP.Z).Magnitude

    -- String-pulling: look ahead and skip waypoints if clear
    local bestIdx = idx
    local bestWP = waypoint
    local lookaheadMax = math.min(#self.path, idx + 5)
    for j = idx + 1, lookaheadMax do
        local candidate = self.path[j]
        local toCand = candidate - mob.position
        local d = Vector3.new(toCand.X, 0, toCand.Z).Magnitude
        if d <= (self.blockSize) * 3 then
            -- Do not skip across a net vertical rise > 1 block
            local netRise = (candidate.Y - mob.position.Y) / self.blockSize
            if netRise > 1.0 + 1e-4 then
                break
            end
            if self.lineClearFn(selfSvc, mob.position, candidate, mob.position.Y) then
                bestIdx = j
                bestWP = candidate
            else
                break
            end
        else
            break
        end
    end
    if bestIdx ~= idx then
        idx = bestIdx
        waypoint = bestWP
        toWP = waypoint - mob.position
        dist = Vector3.new(toWP.X, 0, toWP.Z).Magnitude
    end

    if dist < 0.6 then
        self.pathIndex = idx + 1
        if not self.path[idx + 1] then
            self:clearPath(mob)
            return true
        end
        waypoint = self.path[idx + 1]
        toWP = waypoint - mob.position
    end

    -- Attempt movement toward waypoint
    local moved = self.moveFn(selfSvc, mob, toWP, self.speed, dt)
    if moved then
        self.lastProgressPos = mob.position
        self.lastProgressTime = os.clock()
        if mob.brain then
            mob.brain.pathIndex = self.pathIndex
        end
        return true
    end

    -- Stuck detection: if no progress for a while, request replan
    local now = os.clock()
    if (now - (self.lastProgressTime or now)) >= (self.stuckSeconds or 1.25) then
        -- Mark for immediate replan
        self.repathAt = now
        if mob.brain then
            mob.brain.repathAt = now
        end
        return false
    end

    return false
end

return Navigator


