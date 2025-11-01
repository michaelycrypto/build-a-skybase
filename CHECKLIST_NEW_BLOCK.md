# New Block Type - Quick Checklist

**Block Name**: _________________
**Block ID**: _________________
**Date**: _________________
**Developer**: _________________

---

## Phase 1: Core Constants ✓

- [ ] **Added block ID** to `Constants.lua` → `BlockType`
  - [ ] Used next available ID (not 0)
  - [ ] ID is unique and sequential

- [ ] **Added metadata constants** (if needed)
  - [ ] Defined bit masks
  - [ ] Created helper functions (Get/Set)

- [ ] **Added special mappings** (if slab/stair)
  - [ ] Updated SlabToFullBlock (if slab)
  - [ ] Updated FullBlockToSlab (if slab)

---

## Phase 2: Block Registry ✓

- [ ] **Added block definition** to `BlockRegistry.lua`
  - [ ] Set `name`
  - [ ] Set `solid` (true/false)
  - [ ] Set `transparent` (true/false)
  - [ ] Set `color` (fallback)
  - [ ] Set `textures` (all/top/side/bottom)
  - [ ] Set shape flags (crossShape/stairShape/slabShape/fenceShape/liquid)
  - [ ] Set behavior flags (replaceable/interactable/hasRotation)

---

## Phase 3: Inventory Validation ✓ (CRITICAL!)

- [ ] **Added to VALID_ITEM_IDS** in `InventoryValidator.lua`
  - [ ] `[Constants.BlockType.YOUR_BLOCK] = true,`

**⚠️ Forgetting this causes silent inventory failures!**

---

## Phase 4: Block Placement Rules ✓

- [ ] **Added support rules** (if needed)
  - [ ] Updated `NeedsGroundSupport()` function
  - [ ] Updated `CanSupport()` function

- [ ] **Added special placement logic** (if needed)
  - [ ] Custom validation in `CanPlace()`

---

## Phase 5: Rendering ✓

- [ ] **Rendering configured**
  - [ ] Standard solid block → No changes needed
  - [ ] Cross-shape → `crossShape = true` set
  - [ ] Stairs/Slabs/Fences → Already handled
  - [ ] Special rendering → Added custom pass to `BoxMesher.lua`

- [ ] **Textures loaded**
  - [ ] Texture files exist
  - [ ] Texture names match definition

---

## Phase 6: Optional Features ✓

- [ ] **Added to starter chest** (if needed)
  - [ ] Updated `ChestStorageService.lua` → `InitializeStarterChest()`

- [ ] **Special systems** (if needed)
  - [ ] Created simulator service (liquids)
  - [ ] Added network events (interactable)
  - [ ] Added UI panel (interactable)
  - [ ] Added client interaction (special behavior)

---

## Testing Checklist ✓

- [ ] **Inventory Test**
  - [ ] Transfers from chest to inventory
  - [ ] Transfers between inventory slots
  - [ ] Stacks correctly
  - [ ] Shows correct icon/name

- [ ] **Placement Test**
  - [ ] Places in valid positions
  - [ ] Rejects invalid positions
  - [ ] Consumes from inventory correctly
  - [ ] Rotation works (if rotatable)

- [ ] **Breaking Test**
  - [ ] Breaks and drops item
  - [ ] Break speed correct
  - [ ] Doesn't break if protected

- [ ] **Rendering Test**
  - [ ] Textures visible on all faces
  - [ ] Merging works (if solid)
  - [ ] Transparency correct (if transparent)
  - [ ] Shape correct (if special shape)

- [ ] **Behavior Test** (if applicable)
  - [ ] Special mechanic works
  - [ ] Interaction works
  - [ ] Network sync works
  - [ ] State saves/loads

---

## Files Modified

Track which files you edited:

- [ ] `Constants.lua`
- [ ] `BlockRegistry.lua`
- [ ] `InventoryValidator.lua`
- [ ] `BlockPlacementRules.lua`
- [ ] `BoxMesher.lua`
- [ ] `ChestStorageService.lua`
- [ ] `VoxelWorldService.lua`
- [ ] `EventManager.lua`
- [ ] `BlockInteraction.lua`
- [ ] Other: ___________________

---

## Common Mistakes (Check if issue occurs)

- [ ] Block doesn't transfer from chest → Check `InventoryValidator.lua`
- [ ] Can't place block in water → Check `replaceable` flag
- [ ] Pink/missing texture → Check texture name matches
- [ ] Wrong collision → Check `solid` flag
- [ ] Metadata conflicts → Check bit masks don't overlap
- [ ] Block ID conflict → Check ID is unique

---

## Sign-off

- [ ] All tests pass
- [ ] Code reviewed
- [ ] Documentation updated
- [ ] Ready for commit

**Approved by**: _________________
**Date**: _________________

---

**See**: `DOCS_ADDING_NEW_BLOCKS.md` for detailed instructions



