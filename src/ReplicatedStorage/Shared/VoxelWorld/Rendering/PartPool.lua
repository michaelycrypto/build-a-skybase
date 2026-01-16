--[[
	PartPool.lua
	Lightweight pooling for voxel Parts (visual faces and colliders)
	Optimized: texture pooling, batch operations
]]

local PartPool = {}

-- Reusable pools
local facePool = {}
local colliderPool = {}
local texturePool = {}  -- Pool for Texture instances

-- Pre-allocated default values
local DEFAULT_SIZE = Vector3.new(1, 1, 1)
local DEFAULT_CFRAME = CFrame.new()
local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)

-- Acquire a pooled texture (much faster than Instance.new)
function PartPool.AcquireTexture()
	local tex = table.remove(texturePool)
	if tex then
		return tex
	end
	local t = Instance.new("Texture")
	t.Transparency = 0
	return t
end

-- Release texture back to pool
function PartPool.ReleaseTexture(tex)
	if not tex then return end
	tex.Parent = nil
	-- Reset commonly changed properties
	tex.Texture = ""
	tex.Color3 = DEFAULT_COLOR
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
	local part = table.remove(facePool)
	if part then
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

function PartPool.ReleaseAllFromModel(model)
	if not model then return end
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
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


