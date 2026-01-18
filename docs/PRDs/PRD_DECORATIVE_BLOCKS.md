# Product Requirements Document: Decorative Blocks
## Skyblox - Visual Building Blocks

> **Status**: Ready for Implementation
> **Priority**: P1 (Important - Building & Aesthetics)
> **Estimated Effort**: Small (1-2 days)
> **Last Updated**: January 2026

---

## Executive Summary

Decorative blocks (stained glass, wool, concrete, terracotta) are visual building blocks with no special functionality beyond placement and breaking. This PRD confirms these blocks work correctly with the existing block system and require no additional mechanics.

### Why This Matters
- **Building**: Essential for creative building and aesthetics
- **Base Design**: Players use these for base decoration
- **Minecraft Parity**: Expected visual variety

---

## Current State & Gap Analysis

### What Exists ✅

| Component | Location | Status |
|-----------|----------|--------|
| Stained Glass Blocks | `Constants.lua` → 16 colors (123-138) | ✅ Defined |
| Wool Blocks | `Constants.lua` → 16 colors (156-171) | ✅ Defined |
| Concrete Blocks | `Constants.lua` → 16 colors (180-195) | ✅ Defined |
| Concrete Powder | `Constants.lua` → 16 colors (196-211) | ✅ Defined |
| Terracotta Blocks | `Constants.lua` → 17 colors (139-155) | ✅ Defined |
| Block Textures | `BlockRegistry.lua` | ✅ Available |
| Block Properties | `BlockProperties.lua` | ✅ Hardness, etc. defined |

### What's Missing ❌

| Component | Required For | Priority |
|-----------|--------------|----------|
| Concrete Powder Physics | Falls like sand/gravel | P1 |
| Block Placement | Should work with existing system | P0 |
| Block Breaking | Should work with existing system | P0 |

---

## Detailed Requirements

### FR-1: Block Functionality

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-1.1 | All decorative blocks can be placed | P0 |
| FR-1.2 | All decorative blocks can be broken | P0 |
| FR-1.3 | Blocks drop themselves when broken | P0 |
| FR-1.4 | Blocks have correct hardness values | P0 |
| FR-1.5 | Blocks render with correct textures | P0 |

### FR-2: Special Behaviors

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-2.1 | Concrete Powder falls like sand/gravel | P1 |
| FR-2.2 | Stained Glass is transparent | P0 |
| FR-2.3 | Wool/Concrete/Terracotta are solid | P0 |

---

## Implementation Notes

These blocks should work with the existing block system. No special services needed:

1. **Placement**: Use existing `VoxelWorldService:SetBlock()`
2. **Breaking**: Use existing block breaking system
3. **Rendering**: Use existing block rendering system
4. **Physics**: Concrete Powder needs gravity (like sand)

### Concrete Powder Physics

If sand/gravel already have falling physics, concrete powder should use the same system.

---

## Implementation Plan

### Phase 1: Verification (Day 1)

| Task | File | Description |
|------|------|-------------|
| 1.1 | Testing | Verify all blocks can be placed |
| 1.2 | Testing | Verify all blocks can be broken |
| 1.3 | Testing | Verify textures render correctly |

### Phase 2: Special Behaviors (Day 2)

| Task | File | Description |
|------|------|-------------|
| 2.1 | `BlockPhysicsService.lua` | Add concrete powder to falling blocks |
| 2.2 | Testing | Test concrete powder falling |

---

*Document Version: 1.0*
*Created: January 2026*
*Author: PRD Generation Agent*
