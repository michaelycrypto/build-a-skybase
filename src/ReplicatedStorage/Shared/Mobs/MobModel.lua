--[[
	MobModel.lua

	Factory for constructing Roblox Model instances representing mobs on the client.
	Meshes are approximated with blocky Parts sized and positioned to match Minecraft proportions.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobRegistry = require(ReplicatedStorage.Configs.MobRegistry)

local MobModel = {}

local ROOT_SIZE = Vector3.new(0.5, 0.5, 0.5)

local function createRoot()
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = ROOT_SIZE
	root.Anchored = true
	root.CanCollide = false
	root.Transparency = 1
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Massless = true
	return root
end

local function createMotor(part0, part1, name, c0, c1)
	local motor = Instance.new("Motor6D")
	motor.Name = name or (part1.Name .. "Motor")
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0 or CFrame.new()
	motor.C1 = c1 or CFrame.new()
	motor.Parent = part0
	return motor
end

local function resolveVariant(definition, variant)
	if not variant or not definition or not definition.variants then
		return variant
	end
	if variant.id then
		for _, entry in ipairs(definition.variants) do
			if entry.id == variant.id then
				return entry
			end
		end
	end
	return variant
end

local function applyVariant(definition, variant, part)
	if not variant then
		return
	end
	if definition.id == "SHEEP" then
		if part.Name == "BodyWool" or part.Name == "HeadWool" then
			if variant.woolColor then
				part.Color = variant.woolColor
			end
		end
	elseif definition.id == "ZOMBIE" then
		if part.Name == "Head" and variant.skinColor then
			part.Color = variant.skinColor
		end
	elseif definition.id == "COW" then
		-- Apply body color to body, head, and legs
		if (part.Name == "Body" or part.Name == "Head" or
		    part.Name:match("Leg")) and variant.bodyColor then
			part.Color = variant.bodyColor
		end
		-- Optionally apply spot pattern (for black/white spotted cows)
		-- Note: Simple version just uses solid color, spots would need texture or multiple parts
	elseif definition.id == "CHICKEN" then
		-- Apply body color to body, head, and wings
		if (part.Name == "Body" or part.Name == "Head" or
		    part.Name:match("Wing")) and variant.bodyColor then
			part.Color = variant.bodyColor
		end
		-- Comb stays red, beak stays orange, legs stay yellow
	end
end

function MobModel.Build(mobType, variant)
	local definition = MobRegistry:GetDefinition(mobType)
	if not definition then
		warn("MobModel: Unknown mob type", mobType)
		return nil
	end

local resolvedVariant = resolveVariant(definition, variant)
	local model = Instance.new("Model")
	model.Name = definition.displayName or mobType

	local root = createRoot()
	root.Parent = model
	model.PrimaryPart = root

	local parts = {}
	local motors = {}
	local baseCFrame = CFrame.new()
	root.CFrame = baseCFrame

	if definition.model and definition.model.parts then
		-- First pass: create all parts
		for name, partDef in pairs(definition.model.parts) do
			local part
			-- Prefer cloning from ReplicatedStorage/Assets when provided
			if partDef.assetTemplate then
				local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
				local template = assetsFolder and assetsFolder:FindFirstChild(partDef.assetTemplate)
				if template and template:IsA("BasePart") then
					part = template:Clone()
				else
					warn("MobModel: asset template not found or invalid:", tostring(partDef.assetTemplate))
				end
			end
			if (not part) and partDef.meshId then
				local createdMeshPart = Instance.new("MeshPart")
				local ok, err = pcall(function()
					createdMeshPart.MeshId = partDef.meshId
					if partDef.textureId then
						createdMeshPart.TextureID = partDef.textureId
					end
				end)
				if ok then
					part = createdMeshPart
				else
					warn("MobModel: Failed to set MeshId/TextureID for", tostring(name), "-", tostring(err))
					createdMeshPart:Destroy()
					part = Instance.new("Part")
				end
			end
			if not part then
				part = Instance.new("Part")
			end
			part.Name = partDef.tag or name
			-- Size: scale templates/meshparts to target size (guarded)
			pcall(function()
				if partDef.size then
					part.Size = partDef.size
				end
			end)
			-- Avoid tinting textured MeshParts; otherwise apply color
			local applyColor = true
			if part:IsA("MeshPart") then
				local ok, tex = pcall(function() return part.TextureID end)
				if ok and tex and tostring(tex) ~= "" then
					applyColor = false
				end
			end
			if applyColor then
				part.Color = partDef.color or Color3.new(1, 1, 1)
			end
			part.Material = partDef.material or Enum.Material.Plastic
			part.Transparency = partDef.transparency or 0
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth

			local offset = partDef.cframe or CFrame.new()
			part.CFrame = baseCFrame * offset
			part.Parent = model

			applyVariant(definition, resolvedVariant, part)
			parts[part.Name] = part
		end

		-- Second pass: create motors (so parent parts exist)
		for name, partDef in pairs(definition.model.parts) do
			local part = parts[partDef.tag or name]
			if not part then continue end

			local motorName = partDef.motorName or (part.Name .. "Motor")
			local jointC0 = partDef.c0 or (partDef.cframe or CFrame.new())
			local jointC1 = partDef.c1 or partDef.jointC1

			-- Determine parent part (default to root)
			local parentPart = root
			if partDef.parent and parts[partDef.parent] then
				parentPart = parts[partDef.parent]
			end

			local motor = createMotor(parentPart, part, motorName, jointC0, jointC1)
			motors[motorName] = motor
		end
	end

	-- Optional collider: adds a blocking hitbox matching Minecraft specs
	local colliderDef = definition.collider or (definition.model and definition.model.collider)
	if colliderDef and colliderDef.size then
		local collider = Instance.new("Part")
		collider.Name = colliderDef.name or "Collider"
		collider.Size = colliderDef.size
		collider.Color = Color3.fromRGB(0, 0, 0)
		collider.Transparency = colliderDef.transparency or 1
		collider.Material = Enum.Material.Plastic
		collider.CanCollide = true
		collider.CanQuery = true
		collider.CanTouch = false
		collider.Massless = true
		collider.Anchored = false
		collider.CastShadow = false
		collider.Parent = model

		local offset = colliderDef.cframe or CFrame.new(0, colliderDef.size.Y / 2, 0)
		collider.CFrame = baseCFrame * offset
		local motor = createMotor(root, collider, colliderDef.motorName or "ColliderMotor", offset, colliderDef.c1)
		motors[collider.Name .. "Motor"] = motor
		parts[collider.Name] = collider
	end

	-- Add sounds for sheep
	local sounds = {}
	if definition.id == "SHEEP" then
		local grazeSound = Instance.new("Sound")
		grazeSound.Name = "GrazeSound"
		grazeSound.SoundId = "rbxassetid://6324790483" -- Placeholder sound, can be replaced with proper graze sound
		grazeSound.Volume = 0.2
		grazeSound.Looped = false
		grazeSound.Parent = model
		sounds.GrazeSound = grazeSound
	end

	return {
		model = model,
		root = root,
		parts = parts,
		motors = motors,
		sounds = sounds,
		definition = definition,
		variant = resolvedVariant
	}
end

return MobModel


