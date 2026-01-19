# PRDs for Complex Blocks

This folder contains Product Requirements Documents (PRDs) for blocks that require special functionality beyond basic placement and breaking.

## Simple Blocks (No PRD Needed)

These blocks only need to be added to `BlockRegistry.lua` with textures:
- Decorative blocks (wool, concrete, terracotta, stained glass)
- Basic building blocks (planks, bricks, stone variants)
- Materials/ingots (just need crafting integration)

## Complex Blocks (PRD Required)

These blocks need special mechanics and should have PRDs here:

### Functional Blocks
- Furnaces, Chests, Crafting Tables
- Hoppers, Droppers, Dispensers
- Brewing Stands, Enchanting Tables

### Interactive Blocks
- Doors, Trapdoors
- Buttons, Levers, Pressure Plates
- Redstone components

### Special Mechanics
- Pistons, Sticky Pistons
- Observers, Redstone Repeaters
- Note Blocks, Jukeboxes

### Consumables
- Food items (grouped by type)
- Potions (grouped)

### Tools & Armor
- Tools (grouped by tool type)
- Armor (grouped by tier)

## PRD Naming Convention

- `PRD_[BLOCK_NAME].md` for individual blocks
- `PRD_[CATEGORY]_[SUBCATEGORY].md` for groups
- Examples:
  - `PRD_FURNACE.md`
  - `PRD_FOOD_CONSUMABLES.md`
  - `PRD_TOOLS_PICKAXES.md`
