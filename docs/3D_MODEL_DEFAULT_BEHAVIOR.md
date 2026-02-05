# 3D Model Default Behavior

## Overview

The system now uses **3D models from `ReplicatedStorage.Assets.Tools` as the default** for all item rendering. This applies to:
- **DroppedItem** (items on the ground)
- **HeldItem** (items held in hand - 3rd person)
- **Viewmodel** (items held in hand - 1st person)

## Default Rendering Priority

For **all items**, the system follows this priority order:

1. **3D Model from Tools Folder** (highest priority)
   - Checks `ReplicatedStorage.Assets.Tools[itemName]` (primary)
   - Falls back to `ReplicatedStorage.Tools[itemName]` (legacy)
   - Also checks by item ID: `ReplicatedStorage.Assets.Tools[tostring(itemId)]`
   - If found, uses the 3D model

2. **Apply BlockRegistry Texture** (if model exists but has no texture)
   - If the 3D model doesn't have a TextureID, applies the texture from BlockRegistry
   - Ensures items always have proper textures

3. **Fallback to Texture-Based Rendering** (if no 3D model exists)
   - For cross-shaped items: Creates a flat sprite with texture
   - For regular blocks: Creates a 3D cube with textures on all faces
   - For tools: Uses tool image from ToolConfig

## Implementation Details

### Systems Using 3D Models by Default

1. **HeldItemRenderer** (`src/ReplicatedStorage/Shared/HeldItemRenderer.lua`)
   - `createBlockHandle()` - Checks for 3D models first before creating texture-based parts

2. **DroppedItemController** (`src/StarterPlayerScripts/Client/Controllers/DroppedItemController.lua`)
   - `CreateModel()` - Checks for 3D models for all non-block items before creating sprites

3. **ViewmodelController** (`src/StarterPlayerScripts/Client/Controllers/ViewmodelController.lua`)
   - `buildFlatBlockItem()` - Checks for 3D models first for flat items
   - `buildBlockModel()` - Checks for 3D models first for 3D block items

### Helper Module

**ItemModelLoader** (`src/ReplicatedStorage/Shared/ItemModelLoader.lua`)
- Provides unified API for loading 3D models
- `GetModelTemplate(itemName, itemId)` - Returns MeshPart template if found
- `HasModel(itemName, itemId)` - Checks if model exists
- `CloneModel(itemName, itemId)` - Clones model for use

## Model Naming Convention

Models in `ReplicatedStorage.Assets.Tools` should be named using:
- **Item name** (e.g., "Apple", "Bread", "Cooked Beef")
- **Item ID** (e.g., "37" for Apple, "348" for Bread)

The system checks both:
1. `ReplicatedStorage.Assets.Tools[itemName]`
2. `ReplicatedStorage.Assets.Tools[tostring(itemId)]`

## Texture Application Logic

When a 3D model is found:
1. Check if model has existing TextureID
2. If no texture, get texture from BlockRegistry:
   - `blockInfo.textures.all` (preferred)
   - `blockInfo.textures.side` (fallback)
   - `blockInfo.textures.top` (fallback)
3. Apply texture using `TextureManager:GetTextureId()`

## Example: Bread

```lua
-- BlockRegistry has:
[Constants.BlockType.BREAD] = {
    name = "Bread",
    textures = { all = "rbxassetid://131410059829657" },
    ...
}

-- System checks:
1. ReplicatedStorage.Assets.Tools["Bread"] → Found! Uses 3D model
2. Model has TextureID? → Yes, uses model's texture
3. If model had no texture → Would apply BlockRegistry texture
```

## Benefits

1. **Consistent Rendering**: All items use 3D models when available
2. **Automatic Texture Sync**: BlockRegistry textures are applied if model lacks texture
3. **Graceful Fallback**: System still works if no 3D model exists
4. **Easy to Extend**: Just add 3D model to Tools folder with item name

## Adding New 3D Models

To add a 3D model for an item:
1. Create MeshPart or Model in `ReplicatedStorage.Assets.Tools`
2. Name it using the item name (e.g., "Bread", "Apple")
3. Optionally set TextureID on the MeshPart
4. System will automatically use it!

If the model doesn't have a TextureID, the system will automatically apply the texture from BlockRegistry.
