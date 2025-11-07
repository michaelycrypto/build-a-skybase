# Minecraft Advanced Pathfinding System

## Overview
This document outlines the requirements and implementation plan for Minecraft's advanced pathfinding system, based on the Java Edition source code analysis.

## Current System Analysis

### Existing Implementation
- **Algorithm**: Basic A* with Manhattan heuristic
- **Features**:
  - Line-of-sight optimization (string pulling)
  - Diagonal movement with corner-cutting prevention
  - Step height constraints (±1 block)
  - Ground finding and walkability checks
  - Basic entity avoidance (collision detection)

### Limitations
- Single node type (GROUND only)
- No door/gate interaction
- No block breaking capabilities
- No advanced terrain evaluation
- No multi-stage pathfinding
- No dynamic path recalculation
- Limited entity avoidance

## Minecraft Pathfinding Architecture

### Core Components

#### 1. PathNode System
Minecraft uses a sophisticated node-based navigation system with different node types:

```java
enum PathNodeType {
    BLOCKED(-1.0F),
    OPEN(0.0F),
    WALKABLE(0.0F),
    WALKABLE_DOOR(0.0F),
    TRAPDOOR(0.0F),
    FENCE(-1.0F),
    LAVA(-1.0F),
    WATER(8.0F),
    WATER_BORDER(8.0F),
    RAIL(0.0F),
    UNLOADED(-1.0F),
    DANGER_FIRE(8.0F),
    DANGER_CACTUS(8.0F),
    DANGER_OTHER(8.0F),
    DOOR_OPEN(0.0F),
    DOOR_WOOD_CLOSED(-1.0F),
    DOOR_IRON_CLOSED(-1.0F)
}
```

#### 2. PathNodeEvaluator
Evaluates nodes for pathfinding with different strategies per mob type:

**GroundEvaluator** (most common):
- Evaluates ground-based movement
- Handles doors, gates, fences
- Considers fall damage and preferred paths
- Can break certain blocks

**FlyEvaluator**:
- For flying mobs (ghasts, phantoms)
- Ignores ground constraints
- Considers air blocks as walkable

**AmphibiousEvaluator**:
- For aquatic/terrestrial mobs (axolotls, frogs)
- Handles both water and ground navigation

**SwimEvaluator**:
- For water-only mobs (fish, guardians)
- Only considers water blocks

#### 3. PathFinder
Main A* implementation with advanced features:
- **Node caching**: Reuses nodes between pathfinding calls
- **Multi-threading**: Can run pathfinding on separate threads
- **Timeout protection**: Prevents infinite loops
- **Dynamic recalculation**: Can adapt paths based on world changes

#### 4. Path
Represents the found path with advanced features:
- **Target tracking**: Can follow moving targets
- **Partial paths**: Can reach partial goals if full path blocked
- **Path post-processing**: Optimizes waypoints
- **Reevaluation**: Can recalculate if path becomes invalid

## Implementation Requirements

### Phase 1: Node System Foundation

#### Node Types Implementation
```lua
PathNodeType = {
    BLOCKED = -1.0,
    OPEN = 0.0,
    WALKABLE = 0.0,
    WALKABLE_DOOR = 0.0,
    TRAPDOOR = 0.0,
    FENCE = -1.0,
    LAVA = -1.0,
    WATER = 8.0,
    WATER_BORDER = 8.0,
    RAIL = 0.0,
    UNLOADED = -1.0,
    DANGER_FIRE = 8.0,
    DANGER_CACTUS = 8.0,
    DANGER_OTHER = 8.0,
    DOOR_OPEN = 0.0,
    DOOR_WOOD_CLOSED = -1.0,
    DOOR_IRON_CLOSED = -1.0,
    -- TDS specific additions
    VOXEL_SOLID = -1.0,
    VOXEL_AIR = 0.0,
    VOXEL_WATER = 8.0,
    VOXEL_LAVA = -1.0,
    VOXEL_DANGER = 8.0
}
```

#### Node Structure
```lua
PathNode = {
    x = number,      -- Block X coordinate
    y = number,      -- Block Y coordinate
    z = number,      -- Block Z coordinate
    type = PathNodeType,
    costMalus = number,  -- Additional movement cost
    visited = boolean,
    distanceToTarget = number,
    distanceToStart = number,
    previous = PathNode,
    heapIdx = number
}
```

### Phase 2: Evaluator System

#### Base Evaluator Interface
```lua
PathNodeEvaluator = {
    -- Core evaluation methods
    getStart = function() return PathNode end,
    getNodeType = function(x, y, z) return PathNodeType end,
    getNeighbors = function(node, successors) end,
    getNode = function(x, y, z) return PathNode end,

    -- Advanced features
    canReach = function(node) return boolean end,
    isBlockWalkable = function(blockType) return boolean end,
    getBlockPathCost = function(blockType) return number end,
    findNearestNode = function(x, y, z, range) return PathNode end
}
```

#### GroundEvaluator Implementation
- Evaluates ground-based movement with step constraints
- Handles door interaction (can open wooden doors)
- Considers fall damage (avoids drops > 3 blocks)
- Prefers paths along roads/grass over rough terrain
- Can break certain blocks (doors, gates)

#### Advanced Node Evaluation
```lua
-- Cost calculation with multiple factors
local function calculateNodeCost(self, node, blockType, worldX, worldY, worldZ)
    local baseCost = self:getBlockPathCost(blockType)

    -- Distance malus (prefer shorter paths)
    local distanceMalus = node.distanceToStart * 0.01

    -- Terrain preference (prefer grass/sand over rough blocks)
    local terrainMalus = self:getTerrainMalus(blockType)

    -- Danger malus (avoid lava, cactus, etc.)
    local dangerMalus = self:getDangerMalus(worldX, worldY, worldZ)

    -- Entity avoidance malus
    local entityMalus = self:getEntityAvoidanceMalus(worldX, worldY, worldZ)

    return baseCost + distanceMalus + terrainMalus + dangerMalus + entityMalus
end
```

### Phase 3: Door and Gate Handling

#### Door Interaction System
```lua
DoorHandler = {
    canOpenDoor = function(blockType, blockData) return boolean end,
    openDoor = function(worldX, worldY, worldZ) end,
    isDoorOpen = function(blockType, blockData) return boolean end,
    getDoorCost = function(blockType, blockData) return number end
}
```

#### Block Breaking System
```lua
BlockBreaker = {
    canBreakBlock = function(blockType) return boolean end,
    getBreakCost = function(blockType) return number end,
    breakBlock = function(worldX, worldY, worldZ) end,
    shouldBreakForPath = function(blockType, pathCost) return boolean end
}
```

### Phase 4: Multi-Stage Pathfinding

#### Path Stages
Minecraft breaks complex navigation into stages:
1. **Initial Approach**: Get close to target area
2. **Local Navigation**: Navigate within target area
3. **Final Approach**: Reach exact target position

```lua
MultiStagePath = {
    stages = {},
    currentStage = 1,

    addStage = function(targetArea, evaluator, maxDistance) end,
    advanceStage = function(currentPos) return boolean end,
    getCurrentTarget = function() return Vector3 end,
    isComplete = function() return boolean end
}
```

### Phase 5: Dynamic Path Recalculation

#### Path Validation and Recalculation
```lua
PathValidator = {
    validatePath = function(path, currentPos, worldState) return boolean end,
    findInvalidSegment = function(path, worldState) return number end,
    recalculateFrom = function(path, invalidIndex, evaluator) return Path end,
    canReusePath = function(path, currentPos) return boolean end
}
```

#### World Change Monitoring
```lua
WorldChangeMonitor = {
    blockChanges = {},  -- Queue of recent block changes
    entityMovements = {}, -- Track entity positions

    registerBlockChange = function(x, y, z, oldBlock, newBlock) end,
    registerEntityMovement = function(entityId, oldPos, newPos) end,
    getAffectedPaths = function(change) return Path[] end,
    invalidatePaths = function(paths) end
}
```

## Implementation Plan

### Phase 1: Core Node System (Week 1-2)
1. Implement PathNode and PathNodeType system
2. Create basic PathNodeEvaluator base class
3. Implement GroundEvaluator with enhanced node evaluation
4. Add node caching and reuse system

### Phase 2: Advanced Evaluation (Week 3-4)
1. Implement terrain preference system
2. Add danger evaluation (lava, cactus, etc.)
3. Implement entity avoidance
4. Add block type specific costs

### Phase 3: Interaction Systems (Week 5-6)
1. Implement door opening mechanics
2. Add gate/fence handling
3. Implement selective block breaking
4. Add interaction cost calculations

### Phase 4: Multi-Stage Paths (Week 7-8)
1. Implement MultiStagePath system
2. Add stage transition logic
3. Integrate with existing AI behaviors
4. Add path optimization between stages

### Phase 5: Dynamic Systems (Week 9-10)
1. Implement path validation system
2. Add world change monitoring
3. Implement dynamic recalculation
4. Add path reuse optimization

### Phase 6: Performance & Polish (Week 11-12)
1. Optimize node evaluation performance
2. Add path caching system
3. Implement background pathfinding
4. Add debug visualization tools

## Performance Considerations

### Memory Optimization
- **Node Pooling**: Reuse PathNode objects to reduce GC pressure
- **Region-Based Evaluation**: Only evaluate nodes in relevant world regions
- **Path Caching**: Cache successful paths for similar goals

### CPU Optimization
- **Asynchronous Pathfinding**: Run complex paths on background threads
- **Early Termination**: Stop pathfinding when target becomes unreachable
- **Hierarchical Search**: Use coarse grid for long-distance planning

### Network Optimization
- **Partial Path Updates**: Send only changed path segments
- **Compressed Node Data**: Use efficient node serialization
- **Client-Side Prediction**: Predict path following on client

## Integration with Existing System

### Backward Compatibility
- Keep existing `findPath` function as fallback
- Add new `advancedFindPath` function with full feature set
- Allow mobs to opt into advanced pathfinding via MobRegistry

### Gradual Migration
1. Start with sheep using advanced pathfinding
2. Gradually migrate other mobs
3. Add performance monitoring to ensure stability

### Configuration
```lua
-- MobRegistry pathfinding settings
MobRegistry.Definitions.SHEEP = {
    -- ... existing config ...
    pathfinding = {
        evaluator = "GroundEvaluator",
        canBreakBlocks = false,
        canOpenDoors = true,
        maxFallDistance = 3,
        preferredTerrain = {"GRASS", "DIRT"},
        avoidedTerrain = {"LAVA", "CACTUS"}
    }
}
```

## Testing and Validation

### Unit Tests
- Node evaluation correctness
- Pathfinding algorithm accuracy
- Door/gate interaction
- Multi-stage path completion

### Integration Tests
- Mob behavior with new pathfinding
- Performance impact measurement
- Memory usage monitoring
- Network traffic analysis

### Playtesting
- Natural mob movement
- Complex navigation scenarios
- Performance in crowded areas
- Edge case handling

## Success Metrics

1. **Navigation Quality**: Mobs navigate complex terrain naturally
2. **Performance**: Pathfinding adds <5ms average latency
3. **Memory**: Node pooling keeps GC pressure low
4. **Reliability**: <1% pathfinding failures in normal scenarios
5. **Scalability**: Supports 100+ concurrent pathfinding operations

This advanced pathfinding system will bring TDS mob AI to Minecraft-level sophistication, enabling complex behaviors like navigating mazes, opening doors, avoiding hazards, and adapting to changing world conditions.
