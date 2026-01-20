# Plan: Load Only Textures Present in Schematic

## Problem
Currently, the loading screen loads **all** block textures from the BlockRegistry (333+ textures), even though the hub schematic only uses a small subset. This causes:
- 30+ second loading times
- Unnecessary network bandwidth usage
- Poor user experience with long loading screens

## Solution Overview
Extract unique block IDs from the schematic during loading, then only load textures for those specific blocks.

## Implementation Plan

### Phase 1: Extract Block IDs from Schematic (Server)

#### 1.1 Add Method to SchematicWorldGenerator
**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Generation/SchematicWorldGenerator.lua`

**New Method**: `GetUsedBlockIds()`
- Extract unique block IDs from `_processedPalette`
- Return array of block IDs that are actually used in the schematic
- Should be called after `_loadSchematic()` completes

```lua
function SchematicWorldGenerator:GetUsedBlockIds(): {number}
	local usedBlockIds = {}
	local seen = {}

	for _, blockInfo in pairs(self._processedPalette) do
		if blockInfo and blockInfo.blockId then
			local blockId = blockInfo.blockId
			if not seen[blockId] and blockId ~= BlockType.AIR then
				seen[blockId] = true
				table.insert(usedBlockIds, blockId)
			end
		end
	end

	return usedBlockIds
end
```

#### 1.2 Store Used Block IDs
- Add `_usedBlockIds` field to store the result
- Populate it after schematic loading completes
- Make it accessible via `GetUsedBlockIds()` method

### Phase 2: Add Texture Filtering to TextureManager (Shared)

#### 2.1 Add Method to Get Textures for Specific Block IDs
**File**: `src/ReplicatedStorage/Shared/VoxelWorld/Rendering/TextureManager.lua`

**New Method**: `GetTextureAssetIdsForBlocks(blockIds: {number}): {string}`
- Accept array of block IDs
- For each block ID, get its textures from BlockRegistry
- Collect all unique texture asset IDs
- Return array of unique asset IDs

```lua
function TextureManager:GetTextureAssetIdsForBlocks(blockIds: {number}): {string}
	local results = {}
	local seen = {}

	for _, blockId in ipairs(blockIds) do
		local block = BlockRegistry:GetBlock(blockId)
		if block and block.textures then
			for _, textureName in pairs(block.textures) do
				local assetId = self:GetTextureId(textureName)
				if assetId and not seen[assetId] then
					seen[assetId] = true
					table.insert(results, assetId)
				end
			end
		end
	end

	return results
end
```

### Phase 3: Communicate Block IDs to Client (Server → Client)

#### 3.1 Add Event/Property to World State
**Option A**: Add to existing WorldStateChanged event
- Include `usedBlockIds` in world state data
- Client receives it when world becomes ready

**Option B**: Create new event `SchematicBlockIds`
- Fire when schematic loading completes
- Send array of used block IDs

**Recommended**: Option A (simpler, uses existing infrastructure)

**File**: `src/ServerScriptService/Server/Services/VoxelWorldService.lua` or `Bootstrap.server.lua`
- When world is ready and uses SchematicWorldGenerator, get used block IDs
- Include in world state data sent to clients

### Phase 4: Modify LoadingScreen to Accept Block ID Filter (Client)

#### 4.1 Update LoadBlockTextures Method
**File**: `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua`

**Modify**: `LoadBlockTextures(onProgress, onComplete, blockIds: {number}?)`
- Add optional `blockIds` parameter
- If provided, only load textures for those blocks
- If not provided, fall back to loading all textures (backward compatible)

```lua
function LoadingScreen:LoadBlockTextures(onProgress, onComplete, blockIds)
	local assetsToLoad = {}
	local totalAssets = 0
	local seen = {}

	if blockIds and #blockIds > 0 then
		-- OPTIMIZED: Only load textures for blocks in schematic
		local registryAssets = TextureManager:GetTextureAssetIdsForBlocks(blockIds)
		for _, assetUrl in ipairs(registryAssets) do
			if assetUrl and not seen[assetUrl] then
				seen[assetUrl] = true
				table.insert(assetsToLoad, {name = assetUrl, url = assetUrl})
				totalAssets = totalAssets + 1
			end
		end
	else
		-- FALLBACK: Load all textures (original behavior)
		-- ... existing code ...
	end

	-- ... rest of loading logic ...
end
```

#### 4.2 Update LoadAllAssets Method
**File**: `src/StarterPlayerScripts/Client/UI/LoadingScreen.lua`

**Modify**: `LoadAllAssets(onProgress, onComplete, onBeforeFadeOut, blockIds: {number}?)`
- Add optional `blockIds` parameter
- Pass to `LoadBlockTextures` when calling it

### Phase 5: Connect Client to Use Block IDs (Client)

#### 5.1 Extract Block IDs from World State
**File**: `src/StarterPlayerScripts/Client/GameClient.client.lua`

**Modify**: `handleWorldStateChanged` function
- Check if `worldState.usedBlockIds` exists
- Store it for use during texture loading

#### 5.2 Pass Block IDs to LoadingScreen
**File**: `src/StarterPlayerScripts/Client/GameClient.client.lua`

**Modify**: Call to `LoadingScreen:LoadAllAssets`
- Pass `usedBlockIds` if available
- Otherwise pass `nil` (falls back to loading all)

### Phase 6: Testing & Validation

#### 6.1 Verify Block ID Extraction
- Log used block IDs from schematic
- Verify it matches expected blocks in hub

#### 6.2 Verify Texture Loading Reduction
- Compare texture count before/after
- Measure loading time improvement
- Ensure all required textures still load

#### 6.3 Test Edge Cases
- Empty schematic (should handle gracefully)
- Schematic with unmapped blocks
- Fallback when block IDs not provided

## Expected Results

### Before Optimization
- **Textures Loaded**: ~333+ (all blocks)
- **Loading Time**: 30+ seconds (timeout)
- **Network**: High bandwidth usage

### After Optimization
- **Textures Loaded**: ~50-100 (only blocks in hub schematic)
- **Loading Time**: <5 seconds (estimated)
- **Network**: ~70-80% reduction in texture loading

## Implementation Order

1. ✅ Phase 1: Extract block IDs from schematic (server-side)
2. ✅ Phase 2: Add texture filtering method to TextureManager
3. ✅ Phase 3: Send block IDs to client via world state
4. ✅ Phase 4: Modify LoadingScreen to accept block ID filter
5. ✅ Phase 5: Connect client to use block IDs
6. ✅ Phase 6: Testing and validation

## Backward Compatibility

- All changes use optional parameters
- Falls back to loading all textures if block IDs not provided
- Works with both schematic-based and procedural worlds
- No breaking changes to existing code

## Future Enhancements

1. **Caching**: Cache used block IDs per schematic path
2. **Lazy Loading**: Load additional textures on-demand when blocks are placed
3. **Progress Tracking**: Show which textures are being loaded
4. **Compression**: Further optimize texture asset loading
