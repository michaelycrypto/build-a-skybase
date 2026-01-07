--[[
	ViewportPreview.lua - Utility to render 3D models inside a ViewportFrame

	Features:
	- Creates a ViewportFrame with internal WorldModel and Camera
	- Centers and fits the provided Model within frame with padding
	- Optional auto-rotate animation
	- Simple API: SetModel(model), Clear(), SetSpin(enabled), Destroy()
--]]

local ViewportPreview = {}
ViewportPreview.__index = ViewportPreview

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

local function ensureModel(instance)
	if not instance then return nil end
	if instance:IsA("Model") then
		return instance
	end
	-- Wrap non-model instances into a model for consistent handling
	local model = Instance.new("Model")
	model.Name = "PreviewModel"
	instance.Parent = model
	if instance:IsA("BasePart") then
		model.PrimaryPart = instance
	end
	return model
end

local function calculateModelBounds(model)
	if not model then return nil end
	local primary = model.PrimaryPart
	if not primary then
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("BasePart") then
				model.PrimaryPart = child
				primary = child
				break
			end
		end
	end
	if not primary then return nil end
	local size = model:GetExtentsSize()
	local pivotPos = model:GetPivot().Position
	return size, pivotPos
end

local function createDefaultLighting(parent)
	local ambient = Instance.new("Folder")
	ambient.Name = "Lighting"
	ambient.Parent = parent

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 32
	light.Color = Color3.fromRGB(255, 255, 255)
	light.Parent = ambient

	return ambient, light
end

function ViewportPreview.new(config)
	local self = setmetatable({}, ViewportPreview)

	local parent = config and config.parent or nil
	local size = config and config.size or UDim2.new(0, 128, 0, 128)
	local position = config and config.position or UDim2.new(0, 0, 0, 0)
	local backgroundColor = config and config.backgroundColor or Color3.fromRGB(20, 20, 20)
	local backgroundTransparency = config and config.backgroundTransparency or 0
	local borderRadius = config and config.borderRadius
	local zIndex = config and config.zIndex

	-- High resolution support: render at 2x size, scale down for crisp visuals
	local highResolution = config and config.highResolution or false
	local actualSize = size
	local actualPosition = position
	local container = nil

	if highResolution then
		-- Create container for high-res rendering
		container = Instance.new("Frame")
		container.Name = (config and config.name) or "ViewportPreview" .. "Container"
		container.Size = size
		container.Position = position
		container.BackgroundTransparency = 1
		container.BorderSizePixel = 0
		container.Parent = parent
		parent = container

		-- ViewportFrame at 2x resolution
		actualSize = UDim2.new(size.X.Scale, size.X.Offset * 2, size.Y.Scale, size.Y.Offset * 2)
		actualPosition = UDim2.new(0.5, 0, 0.5, 0)

		-- Add UIScale to scale back down
		local uiScale = Instance.new("UIScale")
		uiScale.Scale = 0.5
		uiScale.Parent = container
	end

	-- ViewportFrame
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = (config and config.name) or "ViewportPreview"
	viewport.Size = actualSize
	viewport.Position = actualPosition
	if highResolution then
		viewport.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	viewport.BackgroundColor3 = backgroundColor
	viewport.BackgroundTransparency = backgroundTransparency
	viewport.BorderSizePixel = 0
	viewport.LightDirection = Vector3.new(0, -1, -0.5)
	viewport.Ambient = Color3.fromRGB(200, 200, 200)
	viewport.LightColor = Color3.fromRGB(255, 255, 255)
	viewport.CurrentCamera = nil
	if zIndex then viewport.ZIndex = zIndex end
	viewport.Parent = parent

	if borderRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, borderRadius)
		corner.Parent = viewport
	end

	-- Internal WorldModel
	local world = Instance.new("WorldModel")
	world.Name = "World"
	world.Parent = viewport

	-- Camera (parent to viewport for clarity)
	local camera = Instance.new("Camera")
	camera.Name = "Camera"
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	-- Lighting (for consistent look)
	local lightingFolder, pointLight = createDefaultLighting(world)

	-- State
	self._viewport = viewport
	self._world = world
	self._camera = camera
	self._lightingFolder = lightingFolder
	self._pointLight = pointLight
	self._container = container  -- Store container reference if high resolution
	self._model = nil
	self._spinConnection = nil
	self._mouseConnection = nil
	self._basePivot = nil  -- Store base pivot for mouse tracking
	self._rotationSpeed = (config and config.rotationSpeed) or 30 -- deg/sec
	self._paddingScale = (config and config.paddingScale) or 1.15 -- camera distance scale
	self._cameraPitch = (config and config.cameraPitch) or 0
	self._sizeConn = nil
	self._highResolution = config and config.highResolution or false

	-- Refit on viewport size changes
	self._sizeConn = viewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self._model then
			self:_refit()
		end
	end)

	return self
end

function ViewportPreview:SetModel(model)
	-- Clear existing
	self:Clear()
	if not model then return end

	-- Ensure world exists
	if not self._world then
		warn("ViewportPreview:SetModel - _world is nil, viewport not initialized")
		return
	end

	-- Clone to avoid mutating live instances
	local clone = model:Clone()
	if not clone then
		warn("ViewportPreview:SetModel - Failed to clone model")
		return
	end

	-- Ensure we work with a Model type
	clone = ensureModel(clone)
	if not clone then
		warn("ViewportPreview:SetModel - ensureModel returned nil")
		return
	end

	clone.Parent = self._world
	self._model = clone

	-- Ensure PrimaryPart
	if not clone.PrimaryPart then
		for _, child in ipairs(clone:GetDescendants()) do
			if child:IsA("BasePart") then
				clone.PrimaryPart = child
				break
			end
		end
	end

	-- Center and fit
	self:_refit()

	-- Store base pivot for mouse tracking
	self._basePivot = clone:GetPivot()
end

function ViewportPreview:Clear()
	if self._model then
		self._model:Destroy()
		self._model = nil
	end
	-- PointLight stays in lighting folder, no need to move it
end

function ViewportPreview:_refit()
	if not self._model or not self._camera then return end
	local size = select(1, calculateModelBounds(self._model))
	if not size then return end

	-- Place model centered at origin (y at half-height)
	self._model:PivotTo(CFrame.new(Vector3.new(0, size.Y * 0.5, 0)))

	-- Compute distance to fit both vertical and horizontal based on viewport aspect and FOV
	local viewportSize = self._viewport.AbsoluteSize
	local aspect = viewportSize.X > 0 and viewportSize.Y > 0 and (viewportSize.X / viewportSize.Y) or 1
	self._camera.FieldOfView = 50
	local vFov = math.rad(self._camera.FieldOfView)
	local halfHeight = size.Y * 0.5
	local halfWidth = math.max(size.X, size.Z) * 0.5
	local verticalDistance = halfHeight / math.tan(vFov / 2)
	local horizontalDistance = halfWidth / (math.tan(vFov / 2) * math.max(aspect, 0.0001))
	local distance = math.max(verticalDistance, horizontalDistance) * self._paddingScale

	local target = Vector3.new(0, size.Y * 0.5, 0)
	local pitch = self._cameraPitch
	local verticalOffset = math.sin(pitch) * distance
	local forwardOffset = math.cos(pitch) * distance
	local cameraPos = target + Vector3.new(0, verticalOffset, forwardOffset)
	self._camera.CFrame = CFrame.lookAt(cameraPos, target)
	self._camera.Focus = CFrame.new(target)

	-- Light follows model primary for consistent illumination
	if self._model.PrimaryPart and self._pointLight then
		pcall(function()
			self._pointLight.Parent = self._model.PrimaryPart
		end)
	end

	-- Update base pivot for mouse tracking
	if self._model then
		self._basePivot = self._model:GetPivot()
	end
end

function ViewportPreview:SetSpin(enabled)
	if enabled then
		if self._spinConnection then return end
		-- Disable mouse tracking when spinning
		self:SetMouseTracking(false)
		self._spinConnection = RunService.RenderStepped:Connect(function(dt)
			if self._model and self._model.PrimaryPart then
				self._model:PivotTo(self._model:GetPivot() * CFrame.Angles(0, math.rad(self._rotationSpeed * dt), 0))
			end
		end)
	else
		if self._spinConnection then
			self._spinConnection:Disconnect()
			self._spinConnection = nil
		end
	end
end

function ViewportPreview:SetMouseTracking(enabled)
	if enabled then
		if self._mouseConnection then return end
		-- Disable spin when mouse tracking
		self:SetSpin(false)

		-- Update base pivot if model exists
		if self._model then
			self._basePivot = self._model:GetPivot()
		end

		self._mouseConnection = RunService.Heartbeat:Connect(function()
			if not self._model or not self._model.PrimaryPart or not self._viewport or not self._basePivot then return end

			-- Get mouse position and screen width
			local mousePos = UserInputService:GetMouseLocation()
			local camera = Workspace.CurrentCamera
			if not camera then return end

			local screenWidth = camera.ViewportSize.X
			local screenHeight = camera.ViewportSize.Y

			-- Calculate mouse position relative to screen center (0 to screenWidth)
			-- Map mouse X from [0, screenWidth] to [-1, 1] where 0 is left edge, screenWidth is right edge
			local relativeX = (mousePos.X / screenWidth) * 2 - 1  -- Maps [0, screenWidth] to [-1, 1]
			local relativeY = (mousePos.Y / screenHeight) * 2 - 1  -- Maps [0, screenHeight] to [-1, 1]

			-- Clamp to screen bounds
			relativeX = math.clamp(relativeX, -1, 1)
			relativeY = math.clamp(relativeY, -1, 1)

			-- Convert to rotation angles:
			-- -45 degrees when mouse is at left edge (relativeX = -1)
			-- 0 degrees when mouse is at center (relativeX = 0)
			-- +45 degrees when mouse is at right edge (relativeX = 1)
			local horizontalAngle = relativeX * math.rad(45)  -- Max 45 degrees horizontal
			local verticalAngle = -relativeY * math.rad(15)   -- Max 15 degrees vertical (slight head tilt)

			-- Apply rotation to model relative to base pivot
			-- Rotate 180 degrees around Y axis so character faces forward correctly
			local baseRotation = CFrame.Angles(0, math.rad(180), 0)
			local mouseRotation = CFrame.Angles(verticalAngle, horizontalAngle, 0)
			local rotation = baseRotation * mouseRotation
			self._model:PivotTo(self._basePivot * rotation)
		end)
	else
		if self._mouseConnection then
			self._mouseConnection:Disconnect()
			self._mouseConnection = nil
		end
		-- Reset to base pivot with 180-degree rotation when mouse tracking is disabled
		if self._model and self._basePivot then
			local baseRotation = CFrame.Angles(0, math.rad(180), 0)
			self._model:PivotTo(self._basePivot * baseRotation)
		end
	end
end

function ViewportPreview:Destroy()
	self:SetSpin(false)
	self:SetMouseTracking(false)
	self:Clear()
	if self._world then self._world:Destroy() end
	if self._viewport then self._viewport:Destroy() end
	if self._container then self._container:Destroy() end
	self._world = nil
	self._viewport = nil
	self._camera = nil
	self._lightingFolder = nil
	self._pointLight = nil
	self._container = nil
	self._basePivot = nil
end

return ViewportPreview


