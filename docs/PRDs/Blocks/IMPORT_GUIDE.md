# Block Import & PRD Generation Guide

## Overview
This guide explains how to import 333 exported Minecraft block textures and create PRDs for complex blocks.

## Step 1: Locate Exported Data

The exported blocks/items should be in one of these formats:
- JSON file(s) with block/item definitions
- Lua module(s) with block/item data
- CSV/TSV with block information
- Directory with individual block files

**Common locations to check:**
- `src/ReplicatedStorage/Assets/Blocks/`
- `src/ReplicatedStorage/Assets/Items/`
- `src/ServerStorage/ExportedBlocks/`
- Root directory: `blocks/` or `items/` folders
- Data file: `block_data.json` or `item_data.lua`

## Step 2: Data Format Expected

Each block should have:
```lua
{
    id = number,              -- Block ID (or will be assigned)
    name = string,            -- "Oak Planks", "Stone Bricks", etc.
    texture = string,         -- rbxassetid:// or texture name
    category = string,        -- "decorative", "functional", "interactive", etc.
    -- Optional:
    hardness = number,        -- Mining hardness
    toolType = string,        -- "pickaxe", "axe", "shovel", etc.
    minToolTier = number,    -- Minimum tool tier required
    transparent = boolean,    -- Is block transparent?
    solid = boolean,          -- Is block solid?
    -- Special properties:
    interactable = boolean,   -- Can right-click interact?
    storage = boolean,        -- Has inventory/storage?
    liquid = boolean,         -- Is it a liquid?
    crossShape = boolean,     -- Uses cross-shaped model?
    stairShape = boolean,     -- Is it a stair block?
    slabShape = boolean,      -- Is it a slab block?
}
```

## Step 3: Processing Workflow

### For Each Block:

1. **Categorize Complexity:**
   - **Simple**: Decorative, basic building blocks → Just add to registry
   - **Complex**: Functional, interactive, special mechanics → Create PRD

2. **Add to Registry:**
   - Add `BlockType` enum in `Constants.lua`
   - Add block definition in `BlockRegistry.lua`
   - Add properties in `BlockProperties.lua` (if needed)

3. **Create PRD (if complex):**
   - Use template from `PRD_GENERATION_PROMPT_CONCISE.md`
   - Save in `docs/PRDs/Blocks/`

## Step 4: Block Categories

### Simple Blocks (No PRD)
- Wool (16 colors)
- Concrete (16 colors)
- Concrete Powder (16 colors)
- Terracotta (17 colors)
- Stained Glass (16 colors)
- Basic planks, logs, stone variants
- Basic building materials

### Complex Blocks (PRD Required)

**Functional:**
- Furnace, Chest, Crafting Table
- Hopper, Dropper, Dispenser
- Brewing Stand, Enchanting Table
- Anvil, Grindstone

**Interactive:**
- Doors, Trapdoors
- Buttons, Levers
- Pressure Plates
- Fence Gates

**Redstone:**
- Redstone Dust, Redstone Torch
- Redstone Repeater, Comparator
- Piston, Sticky Piston
- Observer, Target Block

**Special:**
- Note Block, Jukebox
- Beacon, End Portal Frame
- Spawner, Command Block

## Step 5: Implementation Checklist

For each block:
- [ ] Added to `Constants.lua` (BlockType enum)
- [ ] Added to `BlockRegistry.lua` (with textures)
- [ ] Added to `BlockProperties.lua` (if has special mining properties)
- [ ] Added to `ItemDefinitions.lua` (if it's also an item)
- [ ] Added to `RecipeConfig.lua` (if craftable)
- [ ] PRD created (if complex block)
- [ ] Tested placement
- [ ] Tested breaking
- [ ] Tested special functionality (if applicable)

## Next Steps

Once you provide the exported data location/format, we can:
1. Parse the exported blocks/items
2. Automatically categorize them
3. Add simple blocks to registry
4. Generate PRDs for complex blocks
