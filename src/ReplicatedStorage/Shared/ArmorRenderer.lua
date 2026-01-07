--[[
	ArmorRenderer.lua
	Shared armor rendering logic for applying armor visuals to any character model.

	Used by:
	- ArmorVisualController (player's in-game character)
	- VoxelInventoryPanel (viewport preview character)

	Supports both R6 and R15 rigs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorConfig = require(ReplicatedStorage.Configs.ArmorConfig)

local ArmorRenderer = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local ARMOR_MESHES_FOLDER = ReplicatedStorage:FindFirstChild("Tools")

-- Physical armor dimensions (refined proportions)
ArmorRenderer.ARMOR = {
	-- Boots
	BOOT_PAD = 0.015,
	BOOT_TOE = 0.2,
	BOOT_CUFF_HEIGHT = 0.1,
	BOOT_CUFF_TOE = 0.4,
	-- Belt (waist wrap + buckle)
	BELT_HEIGHT = 1.001,
	BELT_PAD = 0.001,
	BUCKLE_WIDTH = 0.24,
	BUCKLE_HEIGHT = 1.001,
	BUCKLE_PAD = 0.02,
	BUCKLE_DEPTH = 0.02,
	-- Chest plate
	CHEST_PLATE_HEIGHT = 0.58,
	CHEST_PLATE_PAD = 0.04,
	-- Arm (2-part style: sleeve + shoulder plate)
	SLEEVE_HEIGHT = 0.5,
	SLEEVE_PAD = 0.001,
	SHOULDER_PLATE_HEIGHT = 0.36,
	SHOULDER_PLATE_PAD = 0.12,
	SHOULDER_TILT = 3,
}

-- Armor tier colors - read from ArmorConfig (which reads from ItemDefinitions)
ArmorRenderer.TIER_COLORS = ArmorConfig.TierColors

-- Shading multipliers for visual depth
ArmorRenderer.SHADE = {
	RAISED = 0.85,
	SHOULDER = 0.70,
	BOOTS = 0.70,
}

-- Body parts affected by each armor slot
ArmorRenderer.BODY_COLOR_PARTS = {
	chestplate = {
		R6 = { "Torso" },
		R15 = { "UpperTorso", "LowerTorso" }
	},
	leggings = {
		R6 = { "Left Leg", "Right Leg" },
		R15 = { "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }
	}
}

ArmorRenderer.BOOT_PARTS = {
	R6 = {},
	R15 = { "LeftFoot", "RightFoot" }
}

-- Helmet configuration
ArmorRenderer.HELMET_MESH = "ChainmailHelmet"
ArmorRenderer.HELMET_SCALE_VALUE = 0.84
ArmorRenderer.HELMET_Y_OFFSET_VALUE = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorRenderer.IsR15(character)
	return character:FindFirstChild("UpperTorso") ~= nil
end

function ArmorRenderer.GetArmorColor(itemId)
	local armorInfo = ArmorConfig.GetArmorInfo(itemId)
	if armorInfo then
		return ArmorRenderer.TIER_COLORS[armorInfo.tier] or Color3.fromRGB(150, 150, 150)
	end
	return Color3.fromRGB(150, 150, 150)
end

function ArmorRenderer.ShadeColor(color, factor)
	return Color3.new(
		math.clamp(color.R * factor, 0, 1),
		math.clamp(color.G * factor, 0, 1),
		math.clamp(color.B * factor, 0, 1)
	)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BODY COLOR SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorRenderer.ApplyBodyColors(character, slot, itemId, originalColorsCache)
	local partConfig = ArmorRenderer.BODY_COLOR_PARTS[slot]
	if not partConfig then return end

	local partNames = ArmorRenderer.IsR15(character) and partConfig.R15 or partConfig.R6
	local color = ArmorRenderer.GetArmorColor(itemId)

	for _, partName in ipairs(partNames) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") then
			-- Save original color if cache provided
			if originalColorsCache and not originalColorsCache[partName] then
				originalColorsCache[partName] = part.Color
			end
			part.Color = color
		end
	end
end

function ArmorRenderer.RemoveBodyColors(character, slot, originalColorsCache)
	local partConfig = ArmorRenderer.BODY_COLOR_PARTS[slot]
	if not partConfig then return end

	local partNames = ArmorRenderer.IsR15(character) and partConfig.R15 or partConfig.R6

	for _, partName in ipairs(partNames) do
		local part = character:FindFirstChild(partName)
		if part and part:IsA("BasePart") and originalColorsCache and originalColorsCache[partName] then
			part.Color = originalColorsCache[partName]
		end
	end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PART CREATION
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorRenderer.WeldPart(name, size, color, bodyPart, character, offset, anchored)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.Massless = true
	part.CastShadow = false
	part.Anchored = anchored or false
	part.Parent = character

	if anchored then
		-- For anchored models (viewports), position directly
		local bodyPartCFrame = bodyPart.CFrame
		part.CFrame = bodyPartCFrame * (offset or CFrame.new())
	else
		-- For physics models, use welds
		local weld = Instance.new("Weld")
		weld.Part0 = bodyPart
		weld.Part1 = part
		weld.C0 = offset or CFrame.new()
		weld.Parent = part
	end

	return part
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PHYSICAL ARMOR CREATORS
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorRenderer.CreateBoot(bodyPart, color, character, anchored)
	local parts = {}
	local s = bodyPart.Size
	local A = ArmorRenderer.ARMOR
	local pad = A.BOOT_PAD * 2
	local bootColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.BOOTS)

	-- Main boot with toe extension
	local bootToe = A.BOOT_TOE
	local bootSize = Vector3.new(s.X + pad, s.Y + pad, s.Z + pad + bootToe)
	local bootOffset = CFrame.new(0, 0, -bootToe / 2)
	table.insert(parts, ArmorRenderer.WeldPart("Boot", bootSize, bootColor, bodyPart, character, bootOffset, anchored))

	-- Ankle cuff
	local cuffToe = bootToe * A.BOOT_CUFF_TOE
	local cuffSize = Vector3.new(s.X + pad, A.BOOT_CUFF_HEIGHT, s.Z + pad + cuffToe)
	local cuffOffset = CFrame.new(0, s.Y / 2 + A.BOOT_CUFF_HEIGHT / 2, -cuffToe / 2)
	table.insert(parts, ArmorRenderer.WeldPart("Boot_Cuff", cuffSize, bootColor, bodyPart, character, cuffOffset, anchored))

	return parts
end

function ArmorRenderer.CreateBelt(bodyPart, color, character, anchored)
	local parts = {}
	local s = bodyPart.Size
	local A = ArmorRenderer.ARMOR

	local beltPad = A.BELT_PAD * 2
	local beltHeight = s.Y * A.BELT_HEIGHT
	local beltColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.RAISED)

	-- Belt wrap
	local beltSize = Vector3.new(s.X + beltPad, beltHeight, s.Z + beltPad)
	table.insert(parts, ArmorRenderer.WeldPart("Belt", beltSize, beltColor, bodyPart, character, CFrame.new(), anchored))

	-- Belt buckle
	local buckleWidth = s.X * A.BUCKLE_WIDTH
	local buckleHeight = s.Y * A.BUCKLE_HEIGHT + A.BUCKLE_PAD * 2
	local buckleColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.BOOTS)
	local buckleSize = Vector3.new(buckleWidth, buckleHeight, A.BUCKLE_DEPTH)
	local buckleOffset = CFrame.new(0, 0, -(s.Z / 2 + beltPad / 2 + A.BUCKLE_DEPTH / 2))
	table.insert(parts, ArmorRenderer.WeldPart("Belt_Buckle", buckleSize, buckleColor, bodyPart, character, buckleOffset, anchored))

	return parts
end

function ArmorRenderer.CreateChestPlate(bodyPart, color, character, anchored)
	local parts = {}
	local s = bodyPart.Size
	local A = ArmorRenderer.ARMOR

	local platePad = A.CHEST_PLATE_PAD * 2
	local plateHeight = s.Y * A.CHEST_PLATE_HEIGHT
	local plateSize = Vector3.new(s.X + platePad, plateHeight, s.Z + platePad)
	local plateOffset = CFrame.new(0, (s.Y - plateHeight) / 2 + platePad * 0.4, 0)
	local plateColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.RAISED)
	table.insert(parts, ArmorRenderer.WeldPart("ChestPlate", plateSize, plateColor, bodyPart, character, plateOffset, anchored))

	return parts
end

function ArmorRenderer.CreateSleeve(bodyPart, color, character, anchored)
	local parts = {}
	local s = bodyPart.Size
	local A = ArmorRenderer.ARMOR

	local sleevePad = A.SLEEVE_PAD * 2
	local sleeveHeight = s.Y * A.SLEEVE_HEIGHT
	local sleeveSize = Vector3.new(s.X + sleevePad, sleeveHeight, s.Z + sleevePad)
	local sleeveOffset = CFrame.new(0, (s.Y - sleeveHeight) / 2, 0)
	local sleeveColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.RAISED)
	table.insert(parts, ArmorRenderer.WeldPart("Sleeve", sleeveSize, sleeveColor, bodyPart, character, sleeveOffset, anchored))

	return parts
end

function ArmorRenderer.CreateShoulderPlate(bodyPart, color, character, isLeft, anchored)
	local parts = {}
	local s = bodyPart.Size
	local A = ArmorRenderer.ARMOR

	local platePad = A.SHOULDER_PLATE_PAD * 2
	local plateHeight = s.Y * A.SHOULDER_PLATE_HEIGHT
	local plateSize = Vector3.new(s.X + platePad, plateHeight, s.Z + platePad)
	local tiltAngle = math.rad(A.SHOULDER_TILT) * (isLeft and -1 or 1)
	local plateOffset = CFrame.new(0, (s.Y - plateHeight) / 2 + platePad, 0) * CFrame.Angles(0, 0, tiltAngle)
	local plateColor = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.SHOULDER)
	table.insert(parts, ArmorRenderer.WeldPart("ShoulderPlate", plateSize, plateColor, bodyPart, character, plateOffset, anchored))

	return parts
end

-- ═══════════════════════════════════════════════════════════════════════════
-- SLOT-SPECIFIC CREATORS
-- ═══════════════════════════════════════════════════════════════════════════

function ArmorRenderer.CreateBoots(character, itemId, anchored)
	local parts = {}
	local partNames = ArmorRenderer.IsR15(character) and ArmorRenderer.BOOT_PARTS.R15 or ArmorRenderer.BOOT_PARTS.R6
	local color = ArmorRenderer.GetArmorColor(itemId)

	for _, partName in ipairs(partNames) do
		local bodyPart = character:FindFirstChild(partName)
		if bodyPart then
			local bootParts = ArmorRenderer.CreateBoot(bodyPart, color, character, anchored)
			for _, part in ipairs(bootParts) do
				table.insert(parts, part)
			end
		end
	end

	return parts
end

function ArmorRenderer.CreateChestplateArmor(character, itemId, anchored)
	local parts = {}
	local color = ArmorRenderer.GetArmorColor(itemId)
	local r15 = ArmorRenderer.IsR15(character)

	-- Upper torso: chest plate
	local upperTorso = character:FindFirstChild(r15 and "UpperTorso" or "Torso")
	if upperTorso then
		local chestParts = ArmorRenderer.CreateChestPlate(upperTorso, color, character, anchored)
		for _, part in ipairs(chestParts) do
			table.insert(parts, part)
		end
	end

	-- Sleeves + shoulder plates on upper arms
	local armNames = r15 and { "LeftUpperArm", "RightUpperArm" } or { "Left Arm", "Right Arm" }
	for _, armName in ipairs(armNames) do
		local arm = character:FindFirstChild(armName)
		if arm then
			local isLeft = armName:find("Left") ~= nil
			-- Sleeve
			local sleeveParts = ArmorRenderer.CreateSleeve(arm, color, character, anchored)
			for _, part in ipairs(sleeveParts) do
				table.insert(parts, part)
			end
			-- Shoulder plate
			local plateParts = ArmorRenderer.CreateShoulderPlate(arm, color, character, isLeft, anchored)
			for _, part in ipairs(plateParts) do
				table.insert(parts, part)
			end
		end
	end

	return parts
end

function ArmorRenderer.CreateLeggingsArmor(character, itemId, anchored)
	local parts = {}
	local color = ArmorRenderer.GetArmorColor(itemId)
	local r15 = ArmorRenderer.IsR15(character)

	-- Belt on lower torso
	local lowerTorso = character:FindFirstChild(r15 and "LowerTorso" or "Torso")
	if lowerTorso then
		local beltParts = ArmorRenderer.CreateBelt(lowerTorso, color, character, anchored)
		for _, part in ipairs(beltParts) do
			table.insert(parts, part)
		end
	end

	return parts
end

function ArmorRenderer.CreateHelmet(character, itemId, anchored)
	local parts = {}
	local armorInfo = ArmorConfig.GetArmorInfo(itemId)
	if not armorInfo then return parts end

	if not ARMOR_MESHES_FOLDER then
		warn("[ArmorRenderer] Tools folder not found")
		return parts
	end

	local meshTemplate = ARMOR_MESHES_FOLDER:FindFirstChild(ArmorRenderer.HELMET_MESH)
	if not meshTemplate then
		warn("[ArmorRenderer] Helmet mesh not found:", ArmorRenderer.HELMET_MESH)
		return parts
	end

	local headPart = character:FindFirstChild("Head")
	if not headPart then return parts end

	local helmet = meshTemplate:Clone()
	helmet.Name = "Armor_Helmet"
	helmet.CanCollide = false
	helmet.Massless = true
	helmet.CastShadow = true
	helmet.Anchored = anchored or false

	-- Apply tier color
	local color = ArmorRenderer.GetArmorColor(itemId)
	helmet.Color = ArmorRenderer.ShadeColor(color, ArmorRenderer.SHADE.RAISED)

	-- Scale to fit head
	local headSize = headPart.Size
	local originalSize = helmet.Size
	local scaleFactor = math.max(
		headSize.X * ArmorRenderer.HELMET_SCALE_VALUE / originalSize.X,
		headSize.Y * ArmorRenderer.HELMET_SCALE_VALUE / originalSize.Y,
		headSize.Z * ArmorRenderer.HELMET_SCALE_VALUE / originalSize.Z
	)
	helmet.Size = originalSize * scaleFactor
	helmet.Parent = character

	local helmetOffset = CFrame.new(0, headSize.Y * 0.25 + ArmorRenderer.HELMET_Y_OFFSET_VALUE, 0) * CFrame.Angles(0, math.rad(180), 0)

	if anchored then
		-- For anchored models, position directly
		helmet.CFrame = headPart.CFrame * helmetOffset
	else
		-- For physics models, use welds
		local weld = Instance.new("Weld")
		weld.Part0 = headPart
		weld.Part1 = helmet
		weld.C0 = helmetOffset
		weld.Parent = helmet
	end

	table.insert(parts, helmet)
	return parts
end

-- ═══════════════════════════════════════════════════════════════════════════
-- HIGH-LEVEL API
-- ═══════════════════════════════════════════════════════════════════════════

-- Clear all armor parts from a character (by name pattern)
function ArmorRenderer.ClearArmorParts(character)
	if not character then return end

	local partsToDestroy = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") then
			local name = child.Name
			if name == "Boot" or name == "Boot_Cuff" or name == "Belt" or name == "Belt_Buckle"
				or name == "ChestPlate" or name == "Sleeve" or name == "ShoulderPlate"
				or name == "Armor_Helmet" then
				table.insert(partsToDestroy, child)
			end
		end
	end

	for _, part in ipairs(partsToDestroy) do
		part:Destroy()
	end
end

-- Apply all equipped armor visuals to a character
-- @param character: The character model to apply armor to
-- @param equippedArmor: Table with helmet, chestplate, leggings, boots item IDs
-- @param anchored: Whether to use anchored parts (for viewports) or welds (for physics)
-- @param originalColorsCache: Optional table to store original body colors for restoration
-- @returns: Table of all created armor part instances
function ArmorRenderer.ApplyAllArmor(character, equippedArmor, anchored, originalColorsCache)
	if not character or not equippedArmor then return {} end

	local allParts = {}

	-- Helmet
	if equippedArmor.helmet and equippedArmor.helmet > 0 then
		local parts = ArmorRenderer.CreateHelmet(character, equippedArmor.helmet, anchored)
		for _, part in ipairs(parts) do
			table.insert(allParts, part)
		end
	end

	-- Chestplate (body colors + physical armor)
	if equippedArmor.chestplate and equippedArmor.chestplate > 0 then
		ArmorRenderer.ApplyBodyColors(character, "chestplate", equippedArmor.chestplate, originalColorsCache)
		local parts = ArmorRenderer.CreateChestplateArmor(character, equippedArmor.chestplate, anchored)
		for _, part in ipairs(parts) do
			table.insert(allParts, part)
		end
	end

	-- Leggings (body colors + belt)
	if equippedArmor.leggings and equippedArmor.leggings > 0 then
		ArmorRenderer.ApplyBodyColors(character, "leggings", equippedArmor.leggings, originalColorsCache)
		local parts = ArmorRenderer.CreateLeggingsArmor(character, equippedArmor.leggings, anchored)
		for _, part in ipairs(parts) do
			table.insert(allParts, part)
		end
	end

	-- Boots
	if equippedArmor.boots and equippedArmor.boots > 0 then
		local parts = ArmorRenderer.CreateBoots(character, equippedArmor.boots, anchored)
		for _, part in ipairs(parts) do
			table.insert(allParts, part)
		end
	end

	return allParts
end

return ArmorRenderer

