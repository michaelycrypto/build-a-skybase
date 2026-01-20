# Player-Owned World Loading Optimization Plan

## Overview
Player-owned worlds use `SkyblockGenerator` which creates small sky islands with a limited set of blocks. Currently, the LoadingScreen loads ALL textures for player worlds, which is inefficient. This plan outlines optimizations to reduce load times and memory usage.

## Current State Analysis

### Blocks Used in Player Worlds (SkyblockGenerator)
Based on `SkyblockGenerator.lua` analysis, player worlds use a very limited palette:

**Terrain Blocks:**
- `GRASS` - Island surface
- `DIRT` - Island mantle layer
- `STONE` - Island body and exposed cliffs
- `COBBLESTONE` - Cliff strata (optional)
- `STONE_BRICKS` - Cliff strata and portal frames (optional)

**Decoration Blocks:**
- `WOOD` / `OAK_LOG` - Tree trunks (default, can be any log type)
- `OAK_LEAVES` - Tree canopy (matches log type)
- `CHEST` - Starter chest
- `GLASS` - Portal inner blocks (if portals exist)

**Total: ~8-10 unique block types** (vs. 100+ in full BlockRegistry)

### Current Loading Behavior
- **Hub Worlds**: Loads only schematic palette textures (optimized ✅)
- **Player Worlds**: Loads ALL textures from BlockRegistry (inefficient ❌)
- **Estimated Impact**: Loading 100+ textures when only 8-10 are needed

## Optimization Strategies

### Phase 1: Palette-Based Texture Loading (High Priority)
**Goal**: Load only textures for blocks actually used in player worlds

**Implementation:**
1. Create `PlayerWorldPalette.lua` in `ReplicatedStorage/Configs/Schematics/`
   - Extract block IDs from SkyblockGenerator's default configuration
   - Include all possible blocks: GRASS, DIRT, STONE, COBBLESTONE, STONE_BRICKS, WOOD, OAK_LEAVES, CHEST, GLASS
   - Also include all log/leaves variants (players may place different tree types)

2. Update `LoadingScreen.lua`:
   - Add player world detection (check `IsHubWorld == false`)
   - Load palette from `Configs.Schematics.PlayerWorldPalette`
   - Extract block IDs and load only those textures
   - Similar to hub world optimization

**Expected Impact:**
- Reduce texture loading from ~100+ to ~15-20 textures
- **Estimated load time reduction: 60-80%**
- Lower memory footprint

**Files to Modify:**
- `src/ReplicatedStorage/Configs/Schematics/PlayerWorldPalette.lua` (new)
- `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua`

---

### Phase 2: Lazy Texture Loading (Medium Priority)
**Goal**: Load textures on-demand as blocks are placed/encountered

**Implementation:**
1. Create `LazyTextureLoader` module:
   - Maintains a cache of loaded textures
   - Tracks which textures are currently loading
   - Provides async texture loading API

2. Update `TextureManager`:
   - Add lazy loading support
   - Check if texture is loaded before use
   - Queue texture loading if not available
   - Use placeholder texture while loading

3. Update chunk rendering:
   - Preload textures for blocks in visible chunks
   - Load textures for newly placed blocks immediately
   - Unload textures for blocks no longer in render distance

**Expected Impact:**
- Initial load time: **~90% reduction** (only critical textures)
- Progressive loading as player explores/builds
- Better memory management

**Files to Create:**
- `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/LazyTextureLoader.lua`

**Files to Modify:**
- `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/TextureManager.lua`
- `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/ChunkRenderer.lua` (if exists)

---

### Phase 3: Chunk-Based Progressive Loading (Medium Priority)
**Goal**: Load textures in priority order based on chunk distance from spawn

**Implementation:**
1. Texture loading priority system:
   - **Priority 1**: Spawn chunk textures (load immediately)
   - **Priority 2**: Adjacent chunks (load after spawn)
   - **Priority 3**: Render distance chunks (load in background)
   - **Priority 4**: Beyond render distance (lazy load)

2. Update `LoadingScreen`:
   - Load spawn chunk textures first
   - Allow world to start rendering with spawn textures
   - Continue loading other textures in background

3. Chunk texture analysis:
   - Scan chunks to determine which blocks are present
   - Build texture dependency list per chunk
   - Load textures in priority order

**Expected Impact:**
- **Time to first render: 70-80% reduction**
- Player can start playing while textures continue loading
- Better perceived performance

**Files to Modify:**
- `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua`
- `src/ReplicatedStorage/Shared/VoxelWorld/World/WorldManager.lua` (if needed)

---

### Phase 4: Texture Caching & Compression (Low Priority)
**Goal**: Reduce texture memory usage and improve load times

**Implementation:**
1. Texture compression:
   - Use compressed texture formats where possible
   - Implement texture atlasing for similar blocks
   - Reduce texture resolution for distant blocks (LOD)

2. Caching system:
   - Cache loaded textures in memory
   - Persist texture cache across world loads
   - Share texture cache between players in same world

3. Texture streaming:
   - Stream textures in batches
   - Prefetch textures for likely next blocks
   - Unload unused textures after timeout

**Expected Impact:**
- **Memory usage: 30-50% reduction**
- Faster subsequent world loads
- Better performance on low-end devices

**Files to Create:**
- `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/TextureCache.lua`
- `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/TextureAtlas.lua`

---

### Phase 5: Asset Loading Optimization (Low Priority)
**Goal**: Optimize loading of non-texture assets (icons, sounds, meshes)

**Implementation:**
1. Defer non-critical assets:
   - Load icons after world is visible
   - Load sounds in background
   - Load tool meshes on first use

2. Asset priority system:
   - Critical: World textures, UI icons
   - High: Tool meshes, common sounds
   - Medium: Decorative items, rare sounds
   - Low: Optional assets, background music

3. Progressive asset loading:
   - Load assets in waves
   - Allow gameplay to start after critical assets
   - Continue loading in background

**Expected Impact:**
- **Initial load time: Additional 20-30% reduction**
- Faster time to gameplay
- Better user experience

**Files to Modify:**
- `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua`

---

## Implementation Priority

### Immediate (Week 1)
1. ✅ **Phase 1: Palette-Based Texture Loading**
   - Quick win with high impact
   - Similar to hub world optimization (already done)
   - Low risk, high reward

### Short Term (Week 2-3)
2. **Phase 2: Lazy Texture Loading**
   - More complex but significant impact
   - Requires careful testing
   - Better long-term solution

### Medium Term (Month 2)
3. **Phase 3: Chunk-Based Progressive Loading**
   - Improves perceived performance
   - Requires chunk analysis system
   - Good user experience improvement

### Long Term (Month 3+)
4. **Phase 4: Texture Caching & Compression**
   - Advanced optimization
   - Requires texture pipeline changes
   - Best for scalability

5. **Phase 5: Asset Loading Optimization**
   - Polish and refinement
   - Improves overall experience
   - Lower priority

---

## Success Metrics

### Performance Targets
- **Initial Load Time**: Reduce from ~10-15s to ~2-4s (70-80% reduction)
- **Time to First Render**: Reduce to <1s (90% reduction)
- **Memory Usage**: Reduce texture memory by 60-80%
- **Texture Count**: Load 15-20 textures instead of 100+

### Quality Targets
- No visible texture pop-in for initial spawn area
- Smooth texture loading as player explores
- No performance degradation during texture loading
- Maintain visual quality

---

## Technical Considerations

### Block Placement Edge Cases
- Players can place any block type (not just palette)
- Need fallback for unloaded textures
- Lazy loading must handle unexpected blocks

### Multiplayer Considerations
- Texture loading should not block other players
- Shared texture cache between players
- Handle texture loading conflicts

### Backward Compatibility
- Existing worlds should continue to work
- Graceful degradation if palette missing
- Fallback to full texture loading if needed

---

## Testing Plan

### Unit Tests
- Palette extraction accuracy
- Texture loading logic
- Lazy loading cache behavior

### Integration Tests
- Full world load with palette
- Block placement with lazy loading
- Chunk loading with progressive textures

### Performance Tests
- Load time measurements
- Memory usage profiling
- Texture loading performance

### User Testing
- Load time perception
- Visual quality assessment
- Performance on low-end devices

---

## Rollout Strategy

1. **Phase 1**: Deploy to test environment
   - Verify palette accuracy
   - Test with various world configurations
   - Measure performance improvements

2. **Gradual Rollout**:
   - Enable for new worlds first
   - Monitor for issues
   - Roll out to existing worlds

3. **Monitoring**:
   - Track load times
   - Monitor error rates
   - Collect user feedback

---

## Future Enhancements

### Dynamic Palette Detection
- Analyze world chunks to determine actual blocks used
- Build palette dynamically
- Update palette as world changes

### Predictive Loading
- Predict likely next blocks based on player behavior
- Preload textures for predicted blocks
- Machine learning for prediction (advanced)

### Texture Variants
- Support multiple texture quality levels
- Auto-select based on device capabilities
- Allow user preference override

---

## Notes

- This optimization is complementary to the hub world optimization
- Can be implemented incrementally
- Each phase provides independent value
- Consider player feedback when prioritizing phases
