--[[
	Camera.lua
	Camera frustum calculation for culling

	Extracts camera planes from Roblox camera for frustum culling.
]]

local Camera = {}
Camera.__index = Camera

--[[
	Create a new camera frustum calculator
]]
function Camera.new()
	return setmetatable({
		frustum = {
			planes = {},
		},
		position = Vector3.new(0, 0, 0),
		lookVector = Vector3.new(0, 0, -1),
		rightVector = Vector3.new(1, 0, 0),
		upVector = Vector3.new(0, 1, 0),
		fov = 70,
		aspectRatio = 16/9,
		nearPlane = 0.1,
		farPlane = 1000,
	}, Camera)
end

--[[
	Calculate a plane from point and normal
	Plane format: { normal = Vector3, distance = number }
]]
local function CalculatePlane(point: Vector3, normal: Vector3): {normal: Vector3, distance: number}
	local normalized = normal.Unit
	return {
		normal = normalized,
		distance = normalized:Dot(point),
	}
end

--[[
	Update frustum from Roblox camera
]]
function Camera:UpdateFromCamera(robloxCamera)
	self.position = robloxCamera.CFrame.Position
	self.lookVector = robloxCamera.CFrame.LookVector
	self.rightVector = robloxCamera.CFrame.RightVector
	self.upVector = robloxCamera.CFrame.UpVector
	self.fov = math.rad(robloxCamera.FieldOfView)

	-- Calculate viewport aspect ratio
	local viewport = robloxCamera.ViewportSize
	self.aspectRatio = viewport.X / viewport.Y

	-- Calculate frustum planes
	self:CalculateFrustum()
end

--[[
	Calculate the six frustum planes
]]
function Camera:CalculateFrustum()
	local pos = self.position
	local look = self.lookVector
	local right = self.rightVector
	local up = self.upVector

	-- Near and far planes
	local nearPlane = CalculatePlane(pos + look * self.nearPlane, look)
	local farPlane = CalculatePlane(pos + look * self.farPlane, -look)

	-- Calculate half angles
	local halfVFov = self.fov / 2
	local halfHFov = math.atan(math.tan(halfVFov) * self.aspectRatio)

	-- Left and right planes
	local leftNormal = (look * math.cos(halfHFov) - right * math.sin(halfHFov)).Unit
	local rightNormal = (look * math.cos(halfHFov) + right * math.sin(halfHFov)).Unit

	local leftPlane = CalculatePlane(pos, leftNormal)
	local rightPlane = CalculatePlane(pos, rightNormal)

	-- Top and bottom planes
	local topNormal = (look * math.cos(halfVFov) + up * math.sin(halfVFov)).Unit
	local bottomNormal = (look * math.cos(halfVFov) - up * math.sin(halfVFov)).Unit

	local topPlane = CalculatePlane(pos, topNormal)
	local bottomPlane = CalculatePlane(pos, bottomNormal)

	-- Store planes as indexed array for fast iteration
	self.frustum.planes = {
		nearPlane,
		farPlane,
		leftPlane,
		rightPlane,
		topPlane,
		bottomPlane,
	}
end

--[[
	Test if a point is inside the frustum
]]
function Camera:IsPointVisible(point: Vector3): boolean
	for _, plane in pairs(self.frustum.planes) do
		local distance = plane.normal:Dot(point) - plane.distance
		if distance < 0 then
			return false
		end
	end
	return true
end

--[[
	Test if an AABB (Axis-Aligned Bounding Box) is visible
	@param min Vector3 - minimum corner of box
	@param max Vector3 - maximum corner of box
	@return boolean - true if at least partially visible
]]
function Camera:IsAABBVisible(min: Vector3, max: Vector3): boolean
	for _, plane in pairs(self.frustum.planes) do
		-- Get positive/negative vertices relative to plane normal
		local pVertex = Vector3.new(
			plane.normal.X > 0 and max.X or min.X,
			plane.normal.Y > 0 and max.Y or min.Y,
			plane.normal.Z > 0 and max.Z or min.Z
		)

		-- Test if positive vertex is behind plane
		local distance = plane.normal:Dot(pVertex) - plane.distance
		if distance < 0 then
			-- Box is completely outside this plane
			return false
		end
	end

	-- Box is at least partially inside frustum
	return true
end

--[[
	Get distance from camera to point (for sorting)
]]
function Camera:GetDistance(point: Vector3): number
	return (point - self.position).Magnitude
end

return Camera

