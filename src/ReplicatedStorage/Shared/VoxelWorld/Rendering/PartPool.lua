--[[
	PartPool.lua
	Lightweight pooling for voxel Parts (visual faces and colliders)
]]

local PartPool = {}

-- Reusable pools
local facePool = {}
local colliderPool = {}

local function resetCommon(part)
	-- Reset minimal properties that commonly change
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new()
	part.Transparency = 0
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Material = Enum.Material.Plastic
	part.Reflectance = 0
	part.Name = ""

	-- Clear all texture children to prevent texture bleeding when part is reused
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
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


