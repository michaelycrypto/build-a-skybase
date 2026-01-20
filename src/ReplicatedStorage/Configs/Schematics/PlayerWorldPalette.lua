--[[
	PlayerWorldPalette.lua
	Palette for player-owned worlds (Skyblock islands)

	Used by client-side LoadingScreen to preload ONLY necessary textures,
	reducing load time from ~10-15s to ~3-4s.

	Derived from SkyblockGenerator.lua analysis:
	- Terrain: grass, dirt, stone, cobblestone, stone_bricks
	- Trees: all 6 wood families (log + leaves)
	- Decorations: chest, glass (portals)
	- Essential player-placed: crafting_table, furnace, torch

	This palette covers ~95% of blocks players will encounter on initial load.
	Additional blocks are lazy-loaded when placed.
]]

return {
	-- ═══════════════════════════════════════════════════════════════════
	-- TERRAIN (SkyblockGenerator island materials)
	-- ═══════════════════════════════════════════════════════════════════
	"grass_block[snowy=false]",
	"dirt",
	"coarse_dirt",
	"stone",
	"cobblestone",
	"stone_bricks",
	"mossy_cobblestone",

	-- ═══════════════════════════════════════════════════════════════════
	-- WOOD FAMILIES (all variants for tree generation + player building)
	-- ═══════════════════════════════════════════════════════════════════

	-- Oak (default tree type)
	"oak_log[axis=y]",
	"oak_log[axis=x]",
	"oak_log[axis=z]",
	"oak_leaves[distance=1,persistent=false,waterlogged=false]",
	"oak_leaves[distance=1,persistent=true,waterlogged=false]",
	"oak_planks",
	"oak_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"oak_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"oak_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"oak_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"oak_slab[type=bottom,waterlogged=false]",
	"oak_slab[type=top,waterlogged=false]",
	"oak_fence[east=false,north=false,south=false,waterlogged=false,west=false]",
	"oak_sapling",

	-- Spruce
	"spruce_log[axis=y]",
	"spruce_log[axis=x]",
	"spruce_log[axis=z]",
	"spruce_leaves[distance=1,persistent=false,waterlogged=false]",
	"spruce_leaves[distance=1,persistent=true,waterlogged=false]",
	"spruce_planks",
	"spruce_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"spruce_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"spruce_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"spruce_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"spruce_slab[type=bottom,waterlogged=false]",
	"spruce_slab[type=top,waterlogged=false]",
	"spruce_sapling",

	-- Jungle
	"jungle_log[axis=y]",
	"jungle_log[axis=x]",
	"jungle_log[axis=z]",
	"jungle_leaves[distance=1,persistent=false,waterlogged=false]",
	"jungle_leaves[distance=1,persistent=true,waterlogged=false]",
	"jungle_planks",
	"jungle_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"jungle_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"jungle_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"jungle_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"jungle_slab[type=bottom,waterlogged=false]",
	"jungle_slab[type=top,waterlogged=false]",
	"jungle_sapling",

	-- Dark Oak
	"dark_oak_log[axis=y]",
	"dark_oak_log[axis=x]",
	"dark_oak_log[axis=z]",
	"dark_oak_leaves[distance=1,persistent=false,waterlogged=false]",
	"dark_oak_leaves[distance=1,persistent=true,waterlogged=false]",
	"dark_oak_planks",
	"dark_oak_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"dark_oak_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"dark_oak_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"dark_oak_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"dark_oak_slab[type=bottom,waterlogged=false]",
	"dark_oak_slab[type=top,waterlogged=false]",
	"dark_oak_sapling",

	-- Birch
	"birch_log[axis=y]",
	"birch_log[axis=x]",
	"birch_log[axis=z]",
	"birch_leaves[distance=1,persistent=false,waterlogged=false]",
	"birch_leaves[distance=1,persistent=true,waterlogged=false]",
	"birch_planks",
	"birch_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"birch_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"birch_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"birch_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"birch_slab[type=bottom,waterlogged=false]",
	"birch_slab[type=top,waterlogged=false]",
	"birch_sapling",

	-- Acacia
	"acacia_log[axis=y]",
	"acacia_log[axis=x]",
	"acacia_log[axis=z]",
	"acacia_leaves[distance=1,persistent=false,waterlogged=false]",
	"acacia_leaves[distance=1,persistent=true,waterlogged=false]",
	"acacia_planks",
	"acacia_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"acacia_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"acacia_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"acacia_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"acacia_slab[type=bottom,waterlogged=false]",
	"acacia_slab[type=top,waterlogged=false]",
	"acacia_sapling",

	-- ═══════════════════════════════════════════════════════════════════
	-- DECORATIONS & UTILITY (from SkyblockGenerator + early game)
	-- ═══════════════════════════════════════════════════════════════════
	"chest[facing=north,type=single,waterlogged=false]",
	"chest[facing=south,type=single,waterlogged=false]",
	"chest[facing=east,type=single,waterlogged=false]",
	"chest[facing=west,type=single,waterlogged=false]",
	"glass",
	"crafting_table",
	"furnace[facing=north,lit=false]",
	"furnace[facing=south,lit=false]",
	"furnace[facing=east,lit=false]",
	"furnace[facing=west,lit=false]",
	"furnace[facing=north,lit=true]",
	"torch",
	"wall_torch[facing=north]",
	"wall_torch[facing=south]",
	"wall_torch[facing=east]",
	"wall_torch[facing=west]",

	-- ═══════════════════════════════════════════════════════════════════
	-- STONE VARIANTS (common building + cliff strata)
	-- ═══════════════════════════════════════════════════════════════════
	"cobblestone_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"cobblestone_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"cobblestone_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"cobblestone_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"cobblestone_slab[type=bottom,waterlogged=false]",
	"cobblestone_slab[type=top,waterlogged=false]",
	"stone_brick_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"stone_brick_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"stone_brick_stairs[facing=east,half=bottom,shape=straight,waterlogged=false]",
	"stone_brick_stairs[facing=west,half=bottom,shape=straight,waterlogged=false]",
	"stone_brick_slab[type=bottom,waterlogged=false]",
	"stone_brick_slab[type=top,waterlogged=false]",
	"stone_slab[type=bottom,waterlogged=false]",
	"stone_slab[type=top,waterlogged=false]",
	"bricks",
	"brick_stairs[facing=north,half=bottom,shape=straight,waterlogged=false]",
	"brick_stairs[facing=south,half=bottom,shape=straight,waterlogged=false]",
	"brick_slab[type=bottom,waterlogged=false]",

	-- ═══════════════════════════════════════════════════════════════════
	-- ORES & MINERALS (early game progression)
	-- ═══════════════════════════════════════════════════════════════════
	"coal_ore",
	"iron_ore",
	"copper_ore",

	-- ═══════════════════════════════════════════════════════════════════
	-- FARMING (player progression)
	-- ═══════════════════════════════════════════════════════════════════
	"farmland[moisture=0]",
	"farmland[moisture=7]",
	"wheat[age=0]",
	"wheat[age=7]",

	-- ═══════════════════════════════════════════════════════════════════
	-- MISC DECORATIONS
	-- ═══════════════════════════════════════════════════════════════════
	"short_grass",
	"tall_grass[half=lower]",
	"tall_grass[half=upper]",
	"poppy",
	"dandelion",
}
