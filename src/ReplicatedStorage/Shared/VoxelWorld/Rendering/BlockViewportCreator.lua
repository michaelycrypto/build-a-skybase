--[[
	BlockViewportCreator.lua
	Creates 3D ViewportFrame models of blocks for inventory/hotbar display
	Similar to Minecraft's 3D item rendering
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(script.Parent.Parent.Core.Constants)
local BlockRegistry = require(script.Parent.Parent.World.BlockRegistry)
local TextureApplicator = require(script.Parent.TextureApplicator)
local TextureManager = require(script.Parent.TextureManager)

local BlockViewportCreator = {}

-- Cache for viewport models to avoid recreating them
local viewportModelCache = {}

--[[
	Creates a 3D block part with textures
	@param blockId: number - Block type ID
	@return Part - The block model
]]
local function createBlockPart(blockId)
	local def = BlockRegistry.Blocks[blockId]
	if not def then
		return nil
	end

	-- Handle cross-shaped plants differently
	if def.crossShape then
		-- Create two perpendicular planes
		local model = Instance.new("Model")
		model.Name = "CrossBlock"

		local FACE_THICKNESS = 0.03
		local size = 1 -- 1 stud size for viewport

		-- First plane
		local p1 = Instance.new("Part")
		p1.Name = "Plane1"
		p1.Size = Vector3.new(size, size, FACE_THICKNESS)
		p1.Anchored = true
		p1.CanCollide = false
		p1.Material = Enum.Material.SmoothPlastic
		p1.Color = def.color
		p1.Transparency = 1 -- Fully transparent, only texture shows
		p1.TopSurface = Enum.SurfaceType.Smooth
		p1.BottomSurface = Enum.SurfaceType.Smooth
		p1.CFrame = CFrame.Angles(0, math.rad(45), 0)
		p1.Parent = model

		-- Second plane
		local p2 = Instance.new("Part")
		p2.Name = "Plane2"
		p2.Size = Vector3.new(size, size, FACE_THICKNESS)
		p2.Anchored = true
		p2.CanCollide = false
		p2.Material = Enum.Material.SmoothPlastic
		p2.Color = def.color
		p2.Transparency = 1 -- Fully transparent, only texture shows
		p2.TopSurface = Enum.SurfaceType.Smooth
		p2.BottomSurface = Enum.SurfaceType.Smooth
		p2.CFrame = CFrame.Angles(0, math.rad(-45), 0)
		p2.Parent = model

		-- Apply textures to both planes if available
		if def.textures and def.textures.all then
			local textureId = TextureManager:GetTextureId(def.textures.all)
			if textureId then
				-- Apply to both sides of first plane
				local t1Front = Instance.new("Texture")
				t1Front.Name = "CrossTexture"
				t1Front.Face = Enum.NormalId.Front
				t1Front.Texture = textureId
				t1Front.StudsPerTileU = size
				t1Front.StudsPerTileV = size
				t1Front.Parent = p1

				local t1Back = Instance.new("Texture")
				t1Back.Name = "CrossTexture"
				t1Back.Face = Enum.NormalId.Back
				t1Back.Texture = textureId
				t1Back.StudsPerTileU = size
				t1Back.StudsPerTileV = size
				t1Back.Parent = p1

				-- Apply to both sides of second plane
				local t2Front = Instance.new("Texture")
				t2Front.Name = "CrossTexture"
				t2Front.Face = Enum.NormalId.Front
				t2Front.Texture = textureId
				t2Front.StudsPerTileU = size
				t2Front.StudsPerTileV = size
				t2Front.Parent = p2

				local t2Back = Instance.new("Texture")
				t2Back.Name = "CrossTexture"
				t2Back.Face = Enum.NormalId.Back
				t2Back.Texture = textureId
				t2Back.StudsPerTileU = size
				t2Back.StudsPerTileV = size
				t2Back.Parent = p2
			end
		end

		-- Set the first part as PrimaryPart
		model.PrimaryPart = p1

		return model
	end

	-- Handle staircase blocks
	if def.stairShape then
		local model = Instance.new("Model")
		model.Name = "StairBlock"

		local size = 1 -- 1 stud size for viewport

		-- Bottom slab (full size, half height)
		local bottomPart = Instance.new("Part")
		bottomPart.Name = "BottomSlab"
		bottomPart.Size = Vector3.new(size, size / 2, size)
		bottomPart.Anchored = true
		bottomPart.CanCollide = false
		bottomPart.Material = Enum.Material.SmoothPlastic
		bottomPart.Color = def.color
		bottomPart.TopSurface = Enum.SurfaceType.Smooth
		bottomPart.BottomSurface = Enum.SurfaceType.Smooth
		bottomPart.CFrame = CFrame.new(0, -size / 4, 0) -- Position at bottom
		bottomPart.Parent = model

		-- Top step (half depth, half height) - facing SOUTH for UI display
		local topPart = Instance.new("Part")
		topPart.Name = "TopStep"
		topPart.Size = Vector3.new(size, size / 2, size / 2)
		topPart.Anchored = true
		topPart.CanCollide = false
		topPart.Material = Enum.Material.SmoothPlastic
		topPart.Color = def.color
		topPart.TopSurface = Enum.SurfaceType.Smooth
		topPart.BottomSurface = Enum.SurfaceType.Smooth
		topPart.CFrame = CFrame.new(0, size / 4, -size / 4) -- Position at top-back
		topPart.Parent = model

		-- Apply textures if available
		if def.textures and def.textures.all then
			local textureId = TextureManager:GetTextureId(def.textures.all)
			if textureId then
				-- Apply textures to bottom slab
				for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
					local texture = Instance.new("Texture")
					texture.Face = face
					texture.Texture = textureId
					texture.StudsPerTileU = size
					texture.StudsPerTileV = (face == Enum.NormalId.Top or face == Enum.NormalId.Bottom) and size or (size / 2)
					texture.Parent = bottomPart
				end

				-- Apply textures to top step
				for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
					local texture = Instance.new("Texture")
					texture.Face = face
					texture.Texture = textureId
					texture.StudsPerTileU = size
					texture.StudsPerTileV = (face == Enum.NormalId.Top or face == Enum.NormalId.Bottom) and (size / 2) or (size / 2)
					texture.Parent = topPart
				end
			end
		end

		-- Set the bottom part as PrimaryPart
		model.PrimaryPart = bottomPart

		return model
	end

	-- Handle fence blocks
	if def.fenceShape then
		local model = Instance.new("Model")
		model.Name = "FenceBlock"

		local size = 1 -- 1 stud size for viewport
		local postWidth = 0.25 * size
		local postHeight = 1.0 * size
		local railThickness = 0.18 * size
		local sep = 0.35 * size -- left/right post offset from center

		local function makePost(x)
			local post = Instance.new("Part")
			post.Name = "Post"
			post.Size = Vector3.new(postWidth, postHeight, postWidth)
			post.Anchored = true
			post.CanCollide = false
			post.Material = Enum.Material.SmoothPlastic
			post.Color = def.color
			post.TopSurface = Enum.SurfaceType.Smooth
			post.BottomSurface = Enum.SurfaceType.Smooth
			post.CFrame = CFrame.new(x, (postHeight - size) * 0.5, 0)
			post.Parent = model
			-- Apply wood planks texture to post
			if def.textures and def.textures.all then
				local textureId = TextureManager:GetTextureId(def.textures.all)
				if textureId then
					for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
						local texture = Instance.new("Texture")
						texture.Face = face
						texture.Texture = textureId
						texture.StudsPerTileU = size
						texture.StudsPerTileV = size
						texture.Parent = post
					end
				end
			end
			return post
		end

		local postL = makePost(-sep)
		local postR = makePost(sep)

		-- two horizontal rails connecting posts
		local span = (sep * 2) - postWidth
		local function makeRail(y)
			local rail = Instance.new("Part")
			rail.Name = "Rail"
			rail.Size = Vector3.new(span, railThickness, railThickness)
			rail.Anchored = true
			rail.CanCollide = false
			rail.Material = Enum.Material.SmoothPlastic
			rail.Color = def.color
			rail.TopSurface = Enum.SurfaceType.Smooth
			rail.BottomSurface = Enum.SurfaceType.Smooth
			rail.CFrame = CFrame.new(0, -0.5 * size + y, 0)
			rail.Parent = model
			-- Apply wood planks texture to rail
			if def.textures and def.textures.all then
				local textureId = TextureManager:GetTextureId(def.textures.all)
				if textureId then
					for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
						local texture = Instance.new("Texture")
						texture.Face = face
						texture.Texture = textureId
						texture.StudsPerTileU = size
						texture.StudsPerTileV = size
						texture.Parent = rail
					end
				end
			end
			return rail
		end

		makeRail(0.35 * size)
		makeRail(0.80 * size)

		model.PrimaryPart = postL
		return model
	end

	-- Handle slab blocks
	if def.slabShape then
		local size = 1 -- 1 stud size for viewport

		-- Create slab part (half-height block)
		local slabPart = Instance.new("Part")
		slabPart.Name = "SlabBlock"
		slabPart.Size = Vector3.new(size, size / 2, size)
		slabPart.CFrame = CFrame.new(0, -size / 4, 0)  -- Position at bottom half
		slabPart.Anchored = true
		slabPart.CanCollide = false
		slabPart.Material = Enum.Material.SmoothPlastic
		slabPart.Color = def.color or Color3.fromRGB(255, 255, 255)
		slabPart.TopSurface = Enum.SurfaceType.Smooth
		slabPart.BottomSurface = Enum.SurfaceType.Smooth

		-- Apply textures if available
		if def.textures and def.textures.all then
			local textureId = TextureManager:GetTextureId(def.textures.all)
			if textureId then
				for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
					local texture = Instance.new("Texture")
					texture.Face = face
					texture.Texture = textureId
					-- Use full block size for tiling so texture cuts off at half height
					texture.StudsPerTileU = size
					texture.StudsPerTileV = (face == Enum.NormalId.Top or face == Enum.NormalId.Bottom) and size or size
					texture.Parent = slabPart
				end
			end
		end

		return slabPart
	end

	-- Regular solid block
	local part = Instance.new("Part")
	part.Name = "Block"
	part.Size = Vector3.new(1, 1, 1) -- 1 stud size for viewport
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = def.color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- Apply textures if available
	if def.textures then
		TextureApplicator.ApplyTexturesToPart(part, def.textures, Vector3.new(1, 1, 1))
	end

	return part
end

--[[
	Creates a ViewportFrame with a 3D block model inside
	@param parent: GuiObject - Parent GUI element
	@param blockId: number - Block type ID
	@param size: UDim2 - Size of the ViewportFrame (optional, defaults to full parent size)
	@param position: UDim2 - Position of the ViewportFrame (optional)
	@param anchorPoint: Vector2 - Anchor point (optional)
	@return ViewportFrame - The created viewport
]]
function BlockViewportCreator.CreateBlockViewport(parent, blockId, size, position, anchorPoint)
	-- Check cache first
	local cacheKey = "viewport_" .. tostring(blockId)

	-- Create container for high-resolution rendering
	-- We'll render at 2x resolution for crisp visuals
	local container = Instance.new("Frame")
	container.Name = "ViewportContainer"
	container.Size = size or UDim2.new(1, 0, 1, 0)
	container.Position = position or UDim2.new(0, 0, 0, 0)
	container.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.ClipsDescendants = false
	container.Parent = parent

	-- Create ViewportFrame at higher resolution (2x)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "BlockViewport"
	viewport.Size = UDim2.new(2, 0, 2, 0) -- Render at 2x size
	viewport.Position = UDim2.new(0.5, 0, 0.5, 0)
	viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.LightDirection = Vector3.new(-0.3, -1, -0.5) -- Angled lighting for depth
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.Ambient = Color3.fromRGB(140, 140, 140) -- Slightly brighter ambient
	viewport.ImageTransparency = 0
	viewport.Parent = container

	-- Scale down to actual size for anti-aliasing effect
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.5 -- Scale back to 1x (from 2x)
	uiScale.Parent = viewport

	-- Create camera for viewport
	local camera = Instance.new("Camera")
	camera.Name = "ViewportCamera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Create or clone block model
	local blockModel
	if viewportModelCache[blockId] then
		blockModel = viewportModelCache[blockId]:Clone()
	else
		blockModel = createBlockPart(blockId)
		if blockModel then
			-- Cache the original
			local cacheModel = blockModel:Clone()
			viewportModelCache[blockId] = cacheModel
		end
	end

	if not blockModel then
		-- Fallback: create a simple gray cube
		blockModel = Instance.new("Part")
		blockModel.Size = Vector3.new(1, 1, 1)
		blockModel.Color = Color3.fromRGB(150, 150, 150)
		blockModel.Anchored = true
	end

	-- Position block at origin
	if blockModel:IsA("Model") then
		blockModel:PivotTo(CFrame.new(0, 0, 0))
	else
		blockModel.CFrame = CFrame.new(0, 0, 0)
	end

	blockModel.Parent = viewport

	-- Position camera for nice isometric view (Minecraft-style)
	-- View from top-right-front angle
	-- Zoomed out 50% total (25% twice) for better full-block visibility
	local distance = 3.44 -- Increased from 2.2 → 2.75 → 3.44 (50% zoom out total)
	local cameraPos = Vector3.new(distance * 0.7, distance * 0.5, distance * 0.7)
	camera.CFrame = CFrame.lookAt(cameraPos, Vector3.new(0, 0, 0))
	camera.FieldOfView = 28 -- Narrow FOV for less distortion, sharper look

	return container
end

--[[
	Updates an existing viewport with a new block
	@param container: Frame - The viewport container to update (can also be ViewportFrame for backwards compat)
	@param blockId: number - New block type ID
]]
function BlockViewportCreator.UpdateBlockViewport(container, blockId)
	if not container then
		return
	end

	-- Handle both container Frame and direct ViewportFrame for backwards compatibility
	local viewport = container
	if container:IsA("Frame") then
		viewport = container:FindFirstChild("BlockViewport")
		if not viewport then return end
	end

	if not viewport:IsA("ViewportFrame") then
		return
	end

	-- Clear existing block
	for _, child in ipairs(viewport:GetChildren()) do
		if child.Name ~= "ViewportCamera" and child.Name ~= "UIScale" then
			child:Destroy()
		end
	end

	-- Add new block
	local blockModel
	if viewportModelCache[blockId] then
		blockModel = viewportModelCache[blockId]:Clone()
	else
		blockModel = createBlockPart(blockId)
		if blockModel then
			local cacheModel = blockModel:Clone()
			viewportModelCache[blockId] = cacheModel
		end
	end

	if not blockModel then
		return
	end

	-- Position block at origin
	if blockModel:IsA("Model") then
		blockModel:PivotTo(CFrame.new(0, 0, 0))
	else
		blockModel.CFrame = CFrame.new(0, 0, 0)
	end

	blockModel.Parent = viewport
end

--[[
	Clears the viewport cache (useful for memory management)
]]
function BlockViewportCreator.ClearCache()
	for _, model in pairs(viewportModelCache) do
		model:Destroy()
	end
	viewportModelCache = {}
end

return BlockViewportCreator

