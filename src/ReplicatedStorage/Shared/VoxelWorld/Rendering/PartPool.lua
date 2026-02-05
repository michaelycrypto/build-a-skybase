--[[
	PartPool.lua
	Lightweight pooling for voxel Parts (visual faces and colliders)
	Optimized: texture pooling, batch operations
]]

local PartPool = {}

-- Debug config reference (loaded lazily to avoid circular dependency)
local _debugConfig = nil
local function getDebugConfig()
	if _debugConfig == nil then
		local success, Config = pcall(function()
			return require(script.Parent.Parent.Core.Config)
		end)
		_debugConfig = success and Config and Config.DEBUG or {}
	end
	return _debugConfig
end

-- Reusable pools
local facePool = {}
local colliderPool = {}
local texturePool = {}  -- Pool for Texture instances
local wedgePool = {}    -- Pool for WedgePart instances (water rendering)

-- Debug counters
local textureAcquireCount = 0
local textureReleaseCount = 0
local contaminatedTextureCount = 0

-- Pre-allocated default values
local DEFAULT_SIZE = Vector3.new(1, 1, 1)
local DEFAULT_CFRAME = CFrame.new()
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

-- Acquire a pooled texture (much faster than Instance.new)
-- IMPORTANT: Reset critical UV properties to prevent bleeding from previous usage
function PartPool.AcquireTexture()
	textureAcquireCount = textureAcquireCount + 1
	local debugConfig = getDebugConfig()
	
	local tex = table.remove(texturePool)
	if tex then
		-- Debug: Check for contaminated textures BEFORE reset
		local wasContaminated = tex.OffsetStudsU ~= 0 or tex.OffsetStudsV ~= 0 
			or tex.StudsPerTileU ~= 1 or tex.StudsPerTileV ~= 1
			or tex.Texture ~= ""
		
		if wasContaminated then
			contaminatedTextureCount = contaminatedTextureCount + 1
			if debugConfig.LOG_TEXTURE_POOL then
				warn(string.format("[PartPool] CONTAMINATED texture #%d: OffsetU=%.2f, OffsetV=%.2f, TileU=%.2f, TileV=%.2f, Tex=%s",
					textureAcquireCount,
					tex.OffsetStudsU, tex.OffsetStudsV,
					tex.StudsPerTileU, tex.StudsPerTileV,
					tostring(tex.Texture):sub(1, 50)))
			end
		end
		
		-- Safety reset for UV-affecting properties (prevents cross-shape UV glitches after re-mesh)
		tex.OffsetStudsU = 0
		tex.OffsetStudsV = 0
		tex.StudsPerTileU = 1
		tex.StudsPerTileV = 1
		tex.Transparency = 0
		tex.Texture = ""
		tex.Color3 = DEFAULT_COLOR
		
		if debugConfig.LOG_TEXTURE_POOL and textureAcquireCount % 100 == 0 then
			print(string.format("[PartPool] Texture stats: acquired=%d, released=%d, contaminated=%d, poolSize=%d",
				textureAcquireCount, textureReleaseCount, contaminatedTextureCount, #texturePool))
		end
		
		return tex
	end
	
	-- Create new texture
	local t = Instance.new("Texture")
	t.Transparency = 0
	
	if debugConfig.LOG_TEXTURE_POOL then
		print(string.format("[PartPool] Created NEW texture #%d (pool was empty, size=%d)", 
			textureAcquireCount, #texturePool))
	end
	
	return t
end

-- Release texture back to pool
function PartPool.ReleaseTexture(tex)
	if not tex then return end
	
	textureReleaseCount = textureReleaseCount + 1
	local debugConfig = getDebugConfig()
	
	-- Debug: Log state before release
	if debugConfig.LOG_TEXTURE_POOL and (tex.OffsetStudsU ~= 0 or tex.OffsetStudsV ~= 0) then
		warn(string.format("[PartPool] Releasing texture with non-zero offset: OffsetU=%.2f, OffsetV=%.2f, Tex=%s",
			tex.OffsetStudsU, tex.OffsetStudsV, tostring(tex.Texture):sub(1, 50)))
	end
	
	tex.Parent = nil
	-- Reset ALL commonly changed properties to prevent bleeding
	tex.Texture = ""
	tex.Color3 = DEFAULT_COLOR
	tex.Name = "Texture"
	tex.Face = Enum.NormalId.Front
	tex.OffsetStudsU = 0
	tex.OffsetStudsV = 0
	tex.StudsPerTileU = 1
	tex.StudsPerTileV = 1
	table.insert(texturePool, tex)
end

-- Optimized reset - pools textures instead of destroying
local function resetCommon(part)
	-- Reset minimal properties
	part.Size = DEFAULT_SIZE
	part.CFrame = DEFAULT_CFRAME
	part.Transparency = 0
	part.Color = DEFAULT_COLOR
	part.Material = Enum.Material.Plastic
	part.Reflectance = 0
	part.Name = ""

	-- Pool texture children instead of destroying (MUCH faster)
	local children = part:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if child:IsA("Texture") then
			PartPool.ReleaseTexture(child)
		elseif child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
end

function PartPool.AcquireFacePart()
	-- Keep trying until we get a valid Part (not MeshPart)
	-- This protects against any MeshParts that may have been incorrectly pooled
	while true do
		local part = table.remove(facePool)
		if not part then
			-- Pool is empty, create new Part
			break
		end
		
		-- Safeguard: If somehow a MeshPart got into the pool, destroy it and try again
		if part:IsA("MeshPart") then
			part:Destroy()
			continue
		end
		
		part.Parent = nil
		return part
	end
	
	local p = Instance.new("Part")
	p.Anchored = true
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

function PartPool.ReleaseFacePart(part)
	if not part then return end
	
	-- Safeguard: Never pool MeshParts - they should be destroyed
	if part:IsA("MeshPart") then
		part:Destroy()
		return
	end
	
	resetCommon(part)
	part.CanCollide = false
	part.Parent = nil
	table.insert(facePool, part)
end

function PartPool.AcquireColliderPart()
	local part = table.remove(colliderPool)
	if part then
		part.Parent = nil
		return part
	end
	local p = Instance.new("Part")
	p.Anchored = true
	p.Massless = true
	p.CanCollide = true
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.CastShadow = false
	p.Name = "Collider"
	return p
end

function PartPool.ReleaseColliderPart(part)
	if not part then return end
	resetCommon(part)
	part.CanCollide = true
	part.Transparency = 1
	part.Name = "Collider"
	part.Parent = nil
	table.insert(colliderPool, part)
end

-- WedgePart pooling for water flow rendering
function PartPool.AcquireWedgePart()
	local part = table.remove(wedgePool)
	if part then
		part.Parent = nil
		return part
	end
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

function PartPool.ReleaseWedgePart(part)
	if not part then return end
	-- Reset properties similar to resetCommon but for WedgePart
	part.Size = DEFAULT_SIZE
	part.CFrame = DEFAULT_CFRAME
	part.Transparency = 0
	part.Color = DEFAULT_COLOR
	part.Material = Enum.Material.Plastic
	part.Reflectance = 0
	part.Name = ""
	-- Pool texture children
	local children = part:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if child:IsA("Texture") then
			PartPool.ReleaseTexture(child)
		elseif child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	part.Parent = nil
	table.insert(wedgePool, part)
end

-- CornerWedgePart pooling for outer corner water rendering
local cornerWedgePool = {}

function PartPool.AcquireCornerWedgePart()
	local part = table.remove(cornerWedgePool)
	if part then
		part.Parent = nil
		return part
	end
	local p = Instance.new("CornerWedgePart")
	p.Anchored = true
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end

function PartPool.ReleaseCornerWedgePart(part)
	if not part then return end
	part.Size = DEFAULT_SIZE
	part.CFrame = DEFAULT_CFRAME
	part.Transparency = 0
	part.Color = DEFAULT_COLOR
	part.Material = Enum.Material.Plastic
	part.Reflectance = 0
	part.Name = ""
	-- Pool texture children
	local children = part:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if child:IsA("Texture") then
			PartPool.ReleaseTexture(child)
		elseif child:IsA("Decal") or child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	part.Parent = nil
	table.insert(cornerWedgePool, part)
end

function PartPool.ReleaseAllFromModel(model)
	if not model then return end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("CornerWedgePart") then
			PartPool.ReleaseCornerWedgePart(child)
		elseif child:IsA("WedgePart") then
			PartPool.ReleaseWedgePart(child)
		elseif child:IsA("MeshPart") then
			-- MeshParts are from BlockEntity models (Chest, Anvil, etc.)
			-- Do NOT pool them - they are cloned fresh from entity templates
			child:Destroy()
		elseif child:IsA("Model") then
			-- Models are from BlockEntity models (complex multi-part entities)
			-- Do NOT pool them - they are cloned fresh from entity templates
			child:Destroy()
		elseif child:IsA("BasePart") then
			-- Regular Part instances (face parts, colliders)
			if child.Name == "Collider" then
				PartPool.ReleaseColliderPart(child)
			else
				PartPool.ReleaseFacePart(child)
			end
		else
			child:Destroy()
		end
	end
end

return PartPool


