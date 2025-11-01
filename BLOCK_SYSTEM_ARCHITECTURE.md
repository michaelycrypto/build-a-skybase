# Block System Architecture

**Visual guide to block type integration points**

---

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     NEW BLOCK TYPE ADDED                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    1. CONSTANTS.LUA                             │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ • Block ID: YOUR_BLOCK = 30                              │  │
│  │ • Metadata: Bit masks, helpers (if needed)               │  │
│  │ • Mappings: Slab/stair conversions (if needed)           │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                  2. BLOCKREGISTRY.LUA                           │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ • Definition: name, colors, textures                     │  │
│  │ • Flags: solid, transparent, crossShape, etc.            │  │
│  │ • Behavior: replaceable, interactable, etc.              │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────┬────────────────────────────────┬─────────────────┬─────┘
         │                                │                 │
         ▼                                ▼                 ▼
┌──────────────────┐          ┌─────────────────┐  ┌──────────────┐
│ 3. INVENTORY     │          │ 4. PLACEMENT    │  │ 5. RENDERING │
│    VALIDATOR     │          │    RULES        │  │              │
│ ┌──────────────┐ │          │ ┌─────────────┐ │  │ ┌──────────┐ │
│ │ VALID_ITEM_  │ │          │ │ Support     │ │  │ │ BoxMesher│ │
│ │ IDS += ID    │ │          │ │ Rules       │ │  │ │ Passes   │ │
│ └──────────────┘ │          │ └─────────────┘ │  │ └──────────┘ │
│  **CRITICAL**    │          │  (if special)   │  │  (if special)│
└──────────────────┘          └─────────────────┘  └──────────────┘
         │                                │                 │
         │                                ▼                 │
         │                    ┌─────────────────────┐       │
         │                    │ 6. SPECIAL SYSTEMS  │       │
         │                    │ ┌─────────────────┐ │       │
         │                    │ │ • Simulators    │ │       │
         │                    │ │ • Network Events│ │       │
         │                    │ │ • UI Panels     │ │       │
         │                    │ └─────────────────┘ │       │
         │                    │   (if needed)       │       │
         │                    └─────────────────────┘       │
         │                                │                 │
         └────────────────────────────────┴─────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                        GAME RUNTIME                             │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │ Chest System │→ │  Inventory   │→ │ Placement/Breaking │   │
│  │  (storage)   │  │ (validated)  │  │   (validated)      │   │
│  └──────────────┘  └──────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow: Block Transfer

```
CHEST → INVENTORY → PLACEMENT
  │         │           │
  │         │           └─→ BlockPlacementRules.CanPlace()
  │         │                 • Distance check
  │         │                 • Collision check
  │         │                 • Support check
  │         │
  │         └──────────────→ InventoryValidator.ValidateItemStack()
  │                            • Check VALID_ITEM_IDS ← **CRITICAL**
  │                            • Check stack size
  │                            • Anti-duplication
  │
  └────────────────────────→ ChestStorageService
                               • Load from chest slots
                               • Uses ItemStack with block ID
```

---

## Critical Integration Points

### ⚠️ **Point 1: Inventory Validation**
```
Location: InventoryValidator.lua
Impact: HIGH - Silent failures if missing
Check: VALID_ITEM_IDS table

Problem Signature:
- Block visible in chest ✓
- Block doesn't transfer to inventory ✗
- No error message shown ✗

Fix:
[Constants.BlockType.YOUR_BLOCK] = true,
```

### ⚠️ **Point 2: Block Registry**
```
Location: BlockRegistry.lua
Impact: HIGH - Breaks rendering and behavior
Check: Blocks table definition

Problem Signature:
- Block transfers but won't place ✗
- Block renders incorrectly ✗
- Missing texture ✗

Fix: Add complete block definition
```

### ⚠️ **Point 3: Constants Definition**
```
Location: Constants.lua
Impact: CRITICAL - Nothing works without this
Check: BlockType table

Problem Signature:
- Block ID undefined error ✗
- Lua errors in console ✗

Fix: Add unique block ID
```

---

## Block Type Categories

### **Category A: Simple Solid Block**
```
Examples: Stone, Cobblestone, Bricks
Required Files: 3
- Constants.lua (ID)
- BlockRegistry.lua (Definition)
- InventoryValidator.lua (Validation)

Complexity: LOW ●○○○○
```

### **Category B: Special Shape Block**
```
Examples: Stairs, Slabs, Fences
Required Files: 4
- Constants.lua (ID + Metadata)
- BlockRegistry.lua (Definition + shape flag)
- InventoryValidator.lua (Validation)
- BoxMesher.lua (Custom rendering)

Complexity: MEDIUM ●●●○○
```

### **Category C: Interactive Block**
```
Examples: Chests, Crafting Tables
Required Files: 6+
- Constants.lua (ID)
- BlockRegistry.lua (Definition + interactable flag)
- InventoryValidator.lua (Validation)
- Custom Service (Storage/logic)
- EventManager.lua (Network events)
- UI Panel (Client interface)

Complexity: HIGH ●●●●○
```

### **Category D: Dynamic/Liquid Block**
```
Examples: Water, Lava
Required Files: 8+
- Constants.lua (ID + Metadata for level)
- BlockRegistry.lua (Definition + liquid/replaceable flags)
- InventoryValidator.lua (Validation)
- BlockPlacementRules.lua (Replaceable logic)
- BoxMesher.lua (Custom rendering)
- Custom Simulator (Flow logic)
- VoxelWorldService.lua (Integration)
- EventManager.lua (Network events)
- BlockInteraction.lua (Bucket mechanics)

Complexity: VERY HIGH ●●●●●
```

---

## Validation Chain

```
Server Receives Block Placement Request
         │
         ▼
    ┌─────────────────────────┐
    │ 1. Check Block ID Exists│
    │    (Constants.BlockType)│
    └───────────┬─────────────┘
                │ PASS
                ▼
    ┌─────────────────────────┐
    │ 2. Validate Inventory   │
    │    (VALID_ITEM_IDS)     │ ← **Most common failure point**
    └───────────┬─────────────┘
                │ PASS
                ▼
    ┌─────────────────────────┐
    │ 3. Check Placement Rules│
    │    (Distance, Support)  │
    └───────────┬─────────────┘
                │ PASS
                ▼
    ┌─────────────────────────┐
    │ 4. Apply Block Change   │
    │    (SetBlock + Metadata)│
    └───────────┬─────────────┘
                │
                ▼
    ┌─────────────────────────┐
    │ 5. Network Broadcast    │
    │    (To All Clients)     │
    └─────────────────────────┘
                │
                ▼
    ┌─────────────────────────┐
    │ 6. Client Remesh Chunk  │
    │    (BoxMesher rendering)│
    └─────────────────────────┘
```

---

## Debugging Decision Tree

```
Block not working?
    │
    ├─→ Not in inventory?
    │   └─→ Check InventoryValidator.VALID_ITEM_IDS
    │
    ├─→ Won't place?
    │   ├─→ Check BlockPlacementRules
    │   └─→ Check BlockRegistry.replaceable flag
    │
    ├─→ Wrong texture/missing?
    │   └─→ Check BlockRegistry.textures definition
    │
    ├─→ Wrong collision?
    │   └─→ Check BlockRegistry.solid flag
    │
    ├─→ Special behavior not working?
    │   ├─→ Check metadata helpers exist
    │   ├─→ Check special system integrated
    │   └─→ Check network events registered
    │
    └─→ Lua error?
        └─→ Check Constants.BlockType has ID defined
```

---

## File Dependency Map

```
Constants.lua ─────────────┐
    ├─→ BlockRegistry.lua  │
    │      ├─→ InventoryValidator.lua  ← **CRITICAL PATH**
    │      ├─→ BlockPlacementRules.lua
    │      └─→ BoxMesher.lua
    │
    ├─→ VoxelWorldService.lua
    │      ├─→ EventManager.lua
    │      └─→ Custom Services (WaterSimulator, etc.)
    │
    └─→ Client Scripts
           ├─→ BlockInteraction.lua
           └─→ UI Panels
```

---

## Performance Considerations

### Block Type Impact on Performance

| Category | Render Cost | CPU Cost | Memory Cost |
|----------|-------------|----------|-------------|
| Simple Solid | LOW | LOW | LOW |
| Stairs/Slabs | MEDIUM | LOW | MEDIUM |
| Liquids | HIGH | HIGH | MEDIUM |
| Interactable | MEDIUM | MEDIUM | HIGH |

**Optimization Tips**:
- Solid blocks merge automatically (best performance)
- Special shapes render individually (higher cost)
- Liquids update every tick (highest CPU cost)
- Minimize metadata size (use bits efficiently)

---

## Security Considerations

### Validation Points (Anti-Cheat)

1. **Inventory Validation** (InventoryValidator.lua)
   - Prevents item duplication
   - Validates stack sizes
   - Checks item IDs against whitelist

2. **Placement Validation** (BlockPlacementRules.lua)
   - Prevents placing at invalid positions
   - Checks reach distance
   - Prevents player suffocation

3. **Network Validation** (EventManager.lua)
   - Rate limiting
   - Action validation
   - State consistency checks

---

**Last Updated**: 2025-10-24
**See Also**: `DOCS_ADDING_NEW_BLOCKS.md`, `CHECKLIST_NEW_BLOCK.md`



