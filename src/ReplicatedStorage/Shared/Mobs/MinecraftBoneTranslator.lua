--[[
	MinecraftBoneTranslator.lua

	Translates Minecraft Bedrock bone geometry (pivot-based) to Roblox Motor6D system.
	Handles hierarchical bones, rotations, and cube origins correctly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.VoxelWorld.Core.Constants)

local MinecraftBoneTranslator = {}

local BLOCK_SIZE = Constants.BLOCK_SIZE

-- Convert Minecraft pixels to Roblox studs
local function px(pixels)
	return (pixels / 16) * BLOCK_SIZE
end

--[[
	Calculate the center position of a Minecraft cube

	@param origin Vector3 - Corner position from JSON (e.g. [-4, 13, -5])
	@param size Vector3 - Cube size from JSON (e.g. [8, 16, 6])
	@param pivot Vector3 - Bone pivot point (e.g. [0, 19, 2])
	@param rotation Vector3 - Bind pose rotation in degrees (e.g. [90, 0, 0])
	@return Vector3 - Center position in Roblox studs
	@return CFrame - Rotation to apply
]]
function MinecraftBoneTranslator.CalculateCubeTransform(origin, size, pivot, rotation, inflate)
	inflate = inflate or 0

	-- Apply inflate to size and adjust origin
	local inflatedSize = Vector3.new(
		size.X + inflate * 2,
		size.Y + inflate * 2,
		size.Z + inflate * 2
	)

	local inflatedOrigin = Vector3.new(
		origin.X - inflate,
		origin.Y - inflate,
		origin.Z - inflate
	)

	-- Calculate cube center in Minecraft space (before rotation)
	local cubeCenter = Vector3.new(
		inflatedOrigin.X + inflatedSize.X / 2,
		inflatedOrigin.Y + inflatedSize.Y / 2,
		inflatedOrigin.Z + inflatedSize.Z / 2
	)

	-- Convert rotation from degrees to radians
	local rotX = math.rad(rotation.X or 0)
	local rotY = math.rad(rotation.Y or 0)
	local rotZ = math.rad(rotation.Z or 0)

	-- Create rotation CFrame
	local rotationCFrame = CFrame.Angles(rotX, rotY, rotZ)

	-- If there's a rotation, we need to rotate around the pivot point
	if rotation.X ~= 0 or rotation.Y ~= 0 or rotation.Z ~= 0 then
		-- Offset from pivot to cube center
		local offsetFromPivot = cubeCenter - pivot

		-- Rotate the offset
		local rotatedOffset = rotationCFrame * offsetFromPivot

		-- New center = pivot + rotated offset
		cubeCenter = pivot + rotatedOffset

		-- Rotate the size as well for the final part size
		-- For 90° X rotation: Y→Z, Z→Y
		if rotation.X == 90 then
			inflatedSize = Vector3.new(inflatedSize.X, inflatedSize.Z, inflatedSize.Y)
		elseif rotation.X == -90 then
			inflatedSize = Vector3.new(inflatedSize.X, inflatedSize.Z, inflatedSize.Y)
		end
	end

	-- Convert to Roblox studs
	local centerStuds = Vector3.new(px(cubeCenter.X), px(cubeCenter.Y), px(cubeCenter.Z))
	local sizeStuds = Vector3.new(px(inflatedSize.X), px(inflatedSize.Y), px(inflatedSize.Z))

	return centerStuds, sizeStuds, rotationCFrame
end

--[[
	Create Motor6D offset CFrames for a bone

	In Minecraft: bones have a pivot point and child cubes
	In Roblox: Motor6D has C0 (from Part0 to joint) and C1 (from joint to Part1)

	@param pivot Vector3 - Bone pivot in Minecraft pixels
	@param cubeCenter Vector3 - Calculated cube center in studs
	@param parentBone table - Parent bone info (nil for root)
	@return CFrame - C0 offset
	@return CFrame - C1 offset
]]
function MinecraftBoneTranslator.CalculateMotorOffsets(pivot, cubeCenter, parentBone)
    local pivotStuds = Vector3.new(px(pivot.X), px(pivot.Y), px(pivot.Z))

    -- C0: joint frame relative to Part0 (root) – place joint at the bone pivot
    local c0 = CFrame.new(pivotStuds)

    -- C1: joint frame relative to Part1 (the limb/part)
    -- This must be the transform from the part's frame (at its center) to the joint at the pivot
    -- i.e., pivot - center, not center - pivot
    local offsetPartToJoint = pivotStuds - cubeCenter
    local c1 = CFrame.new(offsetPartToJoint)

    return c0, c1
end

--[[
	Build a sheep model from Minecraft geometry
	Returns a model spec compatible with MobModel.Build
]]
function MinecraftBoneTranslator.BuildSheepGeometry()
	-- Sheared sheep geometry (no wool on body/legs)
	local shearedGeometry = {
		body = {
			pivot = Vector3.new(0, 19, 2),
			rotation = Vector3.new(90, 0, 0),
			cubes = {
				{origin = Vector3.new(-4, 13, -5), size = Vector3.new(8, 16, 6), inflate = 0}
			}
		},
		head = {
			pivot = Vector3.new(0, 18, -8),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(-3, 16, -14), size = Vector3.new(6, 6, 8), inflate = 0}
			}
		},
		leg0 = {
			parent = "body",
			pivot = Vector3.new(-3, 12, 7),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(-5, 0, 5), size = Vector3.new(4, 12, 4), inflate = 0}
			}
		},
		leg1 = {
			parent = "body",
			pivot = Vector3.new(3, 12, 7),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(1, 0, 5), size = Vector3.new(4, 12, 4), inflate = 0}
			}
		},
		leg2 = {
			parent = "body",
			pivot = Vector3.new(-3, 12, -5),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(-5, 0, -7), size = Vector3.new(4, 12, 4), inflate = 0}
			}
		},
		leg3 = {
			parent = "body",
			pivot = Vector3.new(3, 12, -5),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(1, 0, -7), size = Vector3.new(4, 12, 4), inflate = 0}
			}
		}
	}

	-- Woolly sheep geometry (with wool inflate on body/legs)
	local woollyGeometry = {
		body = {
			pivot = Vector3.new(0, 19, 2),
			rotation = Vector3.new(90, 0, 0),
			cubes = {
				-- Skin layer
				{origin = Vector3.new(-4, 13, -5), size = Vector3.new(8, 16, 6), inflate = 0},
				-- Wool layer
				{origin = Vector3.new(-4, 13, -5), size = Vector3.new(8, 16, 6), inflate = 1.75, isWool = true}
			}
		},
		head = {
			pivot = Vector3.new(0, 18, -8),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				-- Skin layer
				{origin = Vector3.new(-3, 16, -14), size = Vector3.new(6, 6, 8), inflate = 0},
				-- Wool layer (different origin/size than sheared!)
				{origin = Vector3.new(-3, 16, -12), size = Vector3.new(6, 6, 6), inflate = 0.6, isWool = true}
			}
		},
		leg0 = {
			parent = "body",
			pivot = Vector3.new(-3, 12, 7),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				-- Skin layer (full leg)
				{origin = Vector3.new(-5, 0, 5), size = Vector3.new(4, 12, 4), inflate = 0},
				-- Wool layer (upper leg only!)
				{origin = Vector3.new(-5, 6, 5), size = Vector3.new(4, 6, 4), inflate = 0.5, isWool = true}
			}
		},
		leg1 = {
			parent = "body",
			pivot = Vector3.new(3, 12, 7),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(1, 0, 5), size = Vector3.new(4, 12, 4), inflate = 0},
				{origin = Vector3.new(1, 6, 5), size = Vector3.new(4, 6, 4), inflate = 0.5, isWool = true}
			}
		},
		leg2 = {
			parent = "body",
			pivot = Vector3.new(-3, 12, -5),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(-5, 0, -7), size = Vector3.new(4, 12, 4), inflate = 0},
				{origin = Vector3.new(-5, 6, -7), size = Vector3.new(4, 6, 4), inflate = 0.5, isWool = true}
			}
		},
		leg3 = {
			parent = "body",
			pivot = Vector3.new(3, 12, -5),
			rotation = Vector3.new(0, 0, 0),
			cubes = {
				{origin = Vector3.new(1, 0, -7), size = Vector3.new(4, 12, 4), inflate = 0},
				{origin = Vector3.new(1, 6, -7), size = Vector3.new(4, 6, 4), inflate = 0.5, isWool = true}
			}
		}
	}

	return woollyGeometry
end

--[[
	Process geometry and build part specs for Roblox
]]
function MinecraftBoneTranslator.ProcessGeometry(geometry)
	local parts = {}
	local partIndex = 0

	for boneName, boneData in pairs(geometry) do
		local pivot = boneData.pivot
		local rotation = boneData.rotation or Vector3.new(0, 0, 0)

		for cubeIndex, cube in ipairs(boneData.cubes) do
			local center, size, rotCFrame = MinecraftBoneTranslator.CalculateCubeTransform(
				cube.origin,
				cube.size,
				pivot,
				rotation,
				cube.inflate
			)

			partIndex = partIndex + 1
			local partName = boneName .. "_" .. cubeIndex .. (cube.isWool and "_wool" or "_skin")

			-- For Motor6D: we want C0 to position the joint, C1 to offset the part from joint
			-- Joint should be at the pivot point
			-- Part should be at the cube center
			local c0, c1 = MinecraftBoneTranslator.CalculateMotorOffsets(pivot, center, boneData.parent)

			parts[partName] = {
				size = size,
				cframe = CFrame.new(center),
				pivot = Vector3.new(px(pivot.X), px(pivot.Y), px(pivot.Z)),
				c0 = c0,
				c1 = c1,
				isWool = cube.isWool or false,
				boneName = boneName,
				parent = boneData.parent
			}
		end
	end

	return parts
end

--[[
	Build complete sheep model spec from Minecraft geometry
]]
function MinecraftBoneTranslator.BuildSheepModel(scale)
	local function px(p) return (p / 16) * BLOCK_SIZE end
    local s = (type(scale) == "number" and scale > 0) and scale or 1

	-- Use the woolly geometry definition
	local geometry = MinecraftBoneTranslator.BuildSheepGeometry()

	-- Build parts manually with proper positioning
	-- Root offset lifts entire model by 12px (6px leg offset + 6px ground clearance)
	local rootOffset = Vector3.new(0, px(12) * s, 0)

	return {
		rootOffset = rootOffset,
		minecraftGeometry = geometry,
		parts = {
			-- BODY SKIN: Empirically determined to sit flush on legs
			-- Body center at 3px makes bottom exactly touch leg tops
			BodySkin = {
				size = Vector3.new(px(8), px(6), px(16)) * s,
				cframe = CFrame.new(0, px(3) * s, px(2) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(205, 185, 150),
				tag = "BodySkin",
				motorName = "BodySkinMotor",
				transparency = 1
			},
			-- BODY WOOL: same center, inflated size covers legs
			BodyWool = {
				size = Vector3.new(px(11.5), px(9.5), px(19.5)) * s,
				cframe = CFrame.new(0, px(3) * s, px(2) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(245, 245, 245),
				tag = "BodyWool",
				motorName = "BodyWoolMotor"
			},
			-- HEAD: Body ends at Y=6px (3+3), head should sit on top
			-- Head height is 6px, so head spans 6-12px, center at 9px
			HeadSkin = {
				size = Vector3.new(px(6), px(6), px(8)) * s,
				cframe = CFrame.new(0, px(9) * s, px(-10) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(210, 193, 178),
				tag = "HeadSkin",
				motorName = "HeadSkinMotor"
			},
			-- HEAD WOOL: same center, inflated size
			HeadWool = {
				size = Vector3.new(px(7.2), px(7.2), px(7.2)) * s,
				cframe = CFrame.new(0, px(9) * s, px(-9) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(245, 245, 245),
				tag = "HeadWool",
				motorName = "HeadWoolMotor",
				parent = "HeadSkin",
				-- HeadWool center is 1px forward of HeadSkin center; attach to head so it inherits rotation
				c0 = CFrame.new(0, 0, px(1) * s),
				jointC1 = CFrame.new()
			},
			-- LEGS: Legs centered at Y=6px, but root is offset by +6px
			-- So relative to root, legs are at Y=0
			FrontLeftLeg = {
				size = Vector3.new(px(4), px(12), px(4)) * s,
				cframe = CFrame.new(px(-3) * s, px(0) * s, px(7) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(205, 185, 150),
				tag = "FrontLeftLeg",
				motorName = "FrontLeftLegMotor",
				jointC1 = CFrame.new(0, px(6) * s, 0),
				assetTemplate = "SheepLeg"
			},
			FrontRightLeg = {
				size = Vector3.new(px(4), px(12), px(4)) * s,
				cframe = CFrame.new(px(3) * s, px(0) * s, px(7) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(205, 185, 150),
				tag = "FrontRightLeg",
				motorName = "FrontRightLegMotor",
				jointC1 = CFrame.new(0, px(6) * s, 0),
				assetTemplate = "SheepLeg"
			},
			BackLeftLeg = {
				size = Vector3.new(px(4), px(12), px(4)) * s,
				cframe = CFrame.new(px(-3) * s, px(0) * s, px(-5) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(205, 185, 150),
				tag = "BackLeftLeg",
				motorName = "BackLeftLegMotor",
				jointC1 = CFrame.new(0, px(6) * s, 0),
				assetTemplate = "SheepLeg"
			},
			BackRightLeg = {
				size = Vector3.new(px(4), px(12), px(4)) * s,
				cframe = CFrame.new(px(3) * s, px(0) * s, px(-5) * s),
				material = Enum.Material.SmoothPlastic,
				color = Color3.fromRGB(205, 185, 150),
				tag = "BackRightLeg",
				motorName = "BackRightLegMotor",
				jointC1 = CFrame.new(0, px(6) * s, 0),
				assetTemplate = "SheepLeg"
			}
		}
	}
end

-- Build Zombie geometry from provided Bedrock model data
function MinecraftBoneTranslator.BuildZombieGeometry()
    -- Using the Bedrock JSON (geometry.zombie.v1.8)
    -- Omit neverRender bones like waist/hat/items
    local geometry = {
        body = {
            parent = "waist",
            pivot = Vector3.new(0.0, 24.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-4.0, 12.0, -2.0), size = Vector3.new(8, 12, 4) }
            }
        },
        head = {
            parent = "body",
            pivot = Vector3.new(0.0, 24.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-4.0, 24.0, -4.0), size = Vector3.new(8, 8, 8) }
            }
        },
        rightArm = {
            parent = "body",
            pivot = Vector3.new(-5.0, 22.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-8.0, 12.0, -2.0), size = Vector3.new(4, 12, 4) }
            }
        },
        leftArm = {
            parent = "body",
            pivot = Vector3.new(5.0, 22.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(4.0, 12.0, -2.0), size = Vector3.new(4, 12, 4) }
            }
        },
        rightLeg = {
            parent = "body",
            pivot = Vector3.new(-1.9, 12.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-3.9, 0.0, -2.0), size = Vector3.new(4, 12, 4) }
            }
        },
        leftLeg = {
            parent = "body",
            pivot = Vector3.new(1.9, 12.0, 0.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-0.1, 0.0, -2.0), size = Vector3.new(4, 12, 4) }
            }
        }
    }

    return geometry
end

-- Build complete Zombie model spec using ProcessGeometry for accurate pivots
function MinecraftBoneTranslator.BuildZombieModel(scale)
    local s = (type(scale) == "number" and scale > 0) and scale or 1
    local geometry = MinecraftBoneTranslator.BuildZombieGeometry()
    local processed = MinecraftBoneTranslator.ProcessGeometry(geometry)

    -- Part color/materials to match simple zombie look
    local headColor = Color3.fromRGB(111, 170, 79)
    local limbColor = Color3.fromRGB(111, 170, 79)
    local torsoColor = Color3.fromRGB(63, 102, 62)
    local legColor = Color3.fromRGB(63, 102, 62)

    local parts = {}

    local function scaleCFrame(cf)
        if not cf then return nil end
        local pos = cf.Position
        local rot = cf - cf.Position
        return CFrame.new(pos.X * s, pos.Y * s, pos.Z * s) * rot
    end

    local function addFrom(nameKey, tag, motorName, color)
        local d = processed[nameKey]
        if not d then return end
        parts[tag] = {
            size = d.size * s,
            cframe = scaleCFrame(d.cframe),
            c0 = scaleCFrame(d.c0),
            c1 = scaleCFrame(d.c1),
            material = Enum.Material.Plastic,
            color = color,
            tag = tag,
            motorName = motorName
        }
    end

    addFrom("body_1_skin", "Torso", "TorsoMotor", torsoColor)
    addFrom("head_1_skin", "Head", "HeadMotor", headColor)
    addFrom("leftArm_1_skin", "LeftArm", "LeftArmMotor", limbColor)
    addFrom("rightArm_1_skin", "RightArm", "RightArmMotor", limbColor)
    addFrom("leftLeg_1_skin", "LeftLeg", "LeftLegMotor", legColor)
    addFrom("rightLeg_1_skin", "RightLeg", "RightLegMotor", legColor)

    -- Simple pickaxe visual attached to RightArm
    parts.Pickaxe = {
        size = Vector3.new(0.2, 1.2, 0.2) * s,
        cframe = CFrame.new(0, 0, 0), -- will be positioned via c0 relative to arm
        material = Enum.Material.Metal,
        color = Color3.fromRGB(180, 180, 180),
        tag = "Pickaxe",
        motorName = "PickaxeMotor",
        parent = "RightArm",
        c0 = CFrame.new(0, -0.6 * s, -0.3 * s) * CFrame.Angles(math.rad(45), 0, 0),
        jointC1 = CFrame.new()
    }

    return {
        rootOffset = Vector3.new(0, 0, 0),
        parts = parts
    }
end

-- Build a Minion model (zombie-based proportions) with skin tone and blue outfit
function MinecraftBoneTranslator.BuildMinionModel(scale)
    local s = (type(scale) == "number" and scale > 0) and scale or 1
    local geometry = MinecraftBoneTranslator.BuildZombieGeometry()
    local processed = MinecraftBoneTranslator.ProcessGeometry(geometry)

    -- Colors for minion: skin + blue outfit
    local skinColor = Color3.fromRGB(245, 224, 200)
    local outfitBlue = Color3.fromRGB(60, 120, 220)

    local parts = {}

    local function scaleCFrame(cf)
        if not cf then return nil end
        local pos = cf.Position
        local rot = cf - cf.Position
        return CFrame.new(pos.X * s, pos.Y * s, pos.Z * s) * rot
    end

    local function addFrom(nameKey, tag, motorName, color)
        local d = processed[nameKey]
        if not d then return end
        parts[tag] = {
            size = d.size * s,
            cframe = scaleCFrame(d.cframe),
            c0 = scaleCFrame(d.c0),
            c1 = scaleCFrame(d.c1),
            material = Enum.Material.Plastic,
            color = color,
            tag = tag,
            motorName = motorName
        }
    end

    -- Head skin
    addFrom("head_1_skin", "Head", "HeadMotor", skinColor)
    -- Torso and limbs as blue outfit
    addFrom("body_1_skin", "Torso", "TorsoMotor", outfitBlue)
    addFrom("leftArm_1_skin", "LeftArm", "LeftArmMotor", outfitBlue)
    addFrom("rightArm_1_skin", "RightArm", "RightArmMotor", outfitBlue)
    addFrom("leftLeg_1_skin", "LeftLeg", "LeftLegMotor", outfitBlue)
    addFrom("rightLeg_1_skin", "RightLeg", "RightLegMotor", outfitBlue)

    -- Keep pickaxe prop for visual mining
    parts.Pickaxe = {
        size = Vector3.new(0.2, 1.2, 0.2) * s,
        cframe = CFrame.new(0, 0, 0),
        material = Enum.Material.Metal,
        color = Color3.fromRGB(180, 180, 180),
        tag = "Pickaxe",
        motorName = "PickaxeMotor",
        parent = "RightArm",
        c0 = CFrame.new(0, -0.6 * s, -0.3 * s) * CFrame.Angles(math.rad(45), 0, 0),
        jointC1 = CFrame.new()
    }

    return {
        rootOffset = Vector3.new(0, 0, 0),
        parts = parts
    }
end

-- Build Cow geometry from Minecraft Bedrock geometry.cow.v1.8
function MinecraftBoneTranslator.BuildCowGeometry()
    -- From the provided Minecraft Bedrock JSON
    local geometry = {
        body = {
            pivot = Vector3.new(0.0, 19.0, 2.0),
            rotation = Vector3.new(90, 0, 0),  -- bind_pose_rotation
            cubes = {
                -- Main body
                { origin = Vector3.new(-6.0, 11.0, -5.0), size = Vector3.new(12, 18, 10) },
                -- Udder
                { origin = Vector3.new(-2.0, 11.0, -6.0), size = Vector3.new(4, 6, 1), isUdder = true }
            }
        },
        head = {
            parent = "body",
            pivot = Vector3.new(0.0, 20.0, -8.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                -- Head
                { origin = Vector3.new(-4.0, 16.0, -14.0), size = Vector3.new(8, 8, 6) },
                -- Left horn
                { origin = Vector3.new(-5.0, 22.0, -12.0), size = Vector3.new(1, 3, 1), isHorn = true },
                -- Right horn
                { origin = Vector3.new(4.0, 22.0, -12.0), size = Vector3.new(1, 3, 1), isHorn = true }
            }
        },
        leg0 = {
            parent = "body",
            pivot = Vector3.new(-4.0, 12.0, 7.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-6.0, 0.0, 5.0), size = Vector3.new(4, 12, 4) }
            }
        },
        leg1 = {
            parent = "body",
            pivot = Vector3.new(4.0, 12.0, 7.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(2.0, 0.0, 5.0), size = Vector3.new(4, 12, 4) }
            }
        },
        leg2 = {
            parent = "body",
            pivot = Vector3.new(-4.0, 12.0, -6.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(-6.0, 0.0, -7.0), size = Vector3.new(4, 12, 4) }
            }
        },
        leg3 = {
            parent = "body",
            pivot = Vector3.new(4.0, 12.0, -6.0),
            rotation = Vector3.new(0, 0, 0),
            cubes = {
                { origin = Vector3.new(2.0, 0.0, -7.0), size = Vector3.new(4, 12, 4) }
            }
        }
    }

    return geometry
end

-- Build complete Cow model spec
function MinecraftBoneTranslator.BuildCowModel(scale)
    local s = (type(scale) == "number" and scale > 0) and scale or 1

    -- Cow colors - brown/white variants will be applied later
    local bodyColor = Color3.fromRGB(95, 72, 53)  -- Default brown
    local udderColor = Color3.fromRGB(255, 192, 203)  -- Pink udder
    local headColor = Color3.fromRGB(95, 72, 53)
    local hornColor = Color3.fromRGB(220, 220, 220)  -- Light gray horns
    local legColor = Color3.fromRGB(95, 72, 53)

    -- PROPER ROTATION CALCULATION:
    -- Body pivot: [0, 19, 2], rotation: [90, 0, 0]
    -- Body cube origin: [-6, 11, -5], size: [12, 18, 10]
    --
    -- Step 1: Cube center before rotation = origin + size/2 = [0, 20, 0]
    -- Step 2: Offset from pivot = [0, 20, 0] - [0, 19, 2] = [0, 1, -2]
    -- Step 3: Apply 90° X rotation (X stays, Y→Z, Z→-Y): [0, 1, -2] → [0, -(-2), 1] = [0, 2, 1]
    -- Step 4: Final center = pivot + rotated offset = [0, 19, 2] + [0, 2, 1] = [0, 21, 3]
    --
    -- Wait, that puts body at Y=21 which is too high. Let me reconsider...
    -- 90° positive rotation around X: (x,y,z) → (x, y*cos(90)-z*sin(90), y*sin(90)+z*cos(90))
    --                                        → (x, -z, y)
    -- Applied to offset [0, 1, -2]: → [0, -(-2), 1] = [0, 2, 1]
    --
    -- Hmm, but Minecraft might use negative rotation. Let me try -90°:
    -- -90° rotation around X: (x,y,z) → (x, y*cos(-90)-z*sin(-90), y*sin(-90)+z*cos(-90))
    --                                  → (x, z, -y)
    -- Applied to offset [0, 1, -2]: → [0, -2, -1]
    -- Final: [0, 19, 2] + [0, -2, -1] = [0, 17, 1]
    --
    -- With rootOffset 12: [0, 5, 1]
    -- Size after rotation [12, 18, 10] → (width stays, height↔depth) → [12, 10, 18]

    return {
        rootOffset = Vector3.new(0, px(12) * s, 0),  -- Lift model so legs touch ground
        parts = {
            -- BODY (horizontal body sitting on legs)
            Body = {
                size = Vector3.new(px(12), px(10), px(18)) * s,  -- Rotated: [width, depth, height]
                cframe = CFrame.new(0, px(5) * s, px(1) * s),  -- Center at Y=5, Z=1
                material = Enum.Material.SmoothPlastic,
                color = bodyColor,
                tag = "Body",
                motorName = "BodyMotor"
            },

            -- UDDER (using same rotation math)
            -- Origin: [-2, 11, -6], size: [4, 6, 1], pivot: [0, 19, 2]
            -- Center before rotation: [0, 14, -5.5]
            -- Offset from pivot: [0, 14-19, -5.5-2] = [0, -5, -7.5]
            -- After -90° X rotation (z, -y): [0, -7.5, 5]
            -- Final: [0, 19, 2] + [0, -7.5, 5] = [0, 11.5, 7]
            -- Relative to root: [0, -0.5, 7]
            -- Size after rotation [4, 6, 1] → [4, 1, 6]
            Udder = {
                size = Vector3.new(px(4), px(1), px(6)) * s,
                cframe = CFrame.new(0, px(-0.5) * s, px(7) * s),
                material = Enum.Material.SmoothPlastic,
                color = udderColor,
                tag = "Udder",
                motorName = "UdderMotor"
            },

            -- HEAD (Minecraft: center at [0, 20, -11], pivot at [0, 20, -8])
            -- With rootOffset 12: relative Y = 20 - 12 = 8
            Head = {
                size = Vector3.new(px(8), px(8), px(6)) * s,
                cframe = CFrame.new(0, px(8) * s, px(-11) * s),
                material = Enum.Material.SmoothPlastic,
                color = headColor,
                tag = "Head",
                motorName = "HeadMotor",
                jointC1 = CFrame.new(0, px(-4) * s, 0)  -- Pivot at top of head for neck rotation
            },

            -- LEFT HORN (Minecraft: origin [-5, 22, -12], size [1, 3, 1])
            -- Center: [-4.5, 23.5, -11.5], relative Y = 23.5 - 12 = 11.5
            HornLeft = {
                size = Vector3.new(px(1), px(3), px(1)) * s,
                cframe = CFrame.new(px(-4.5) * s, px(11.5) * s, px(-11.5) * s),
                material = Enum.Material.SmoothPlastic,
                color = hornColor,
                tag = "HornLeft",
				motorName = "HornLeftMotor",
				parent = "Head",
				-- Relative to head center (0, 8, -11): (-4.5, +3.5, -0.5)
				c0 = CFrame.new(px(-4.5) * s, px(3.5) * s, px(-0.5) * s),
				jointC1 = CFrame.new()
            },

            -- RIGHT HORN (Minecraft: origin [4, 22, -12], size [1, 3, 1])
            -- Center: [4.5, 23.5, -11.5], relative Y = 23.5 - 12 = 11.5
            HornRight = {
                size = Vector3.new(px(1), px(3), px(1)) * s,
                cframe = CFrame.new(px(4.5) * s, px(11.5) * s, px(-11.5) * s),
                material = Enum.Material.SmoothPlastic,
                color = hornColor,
                tag = "HornRight",
				motorName = "HornRightMotor",
				parent = "Head",
				-- Relative to head center (0, 8, -11): (+4.5, +3.5, -0.5)
				c0 = CFrame.new(px(4.5) * s, px(3.5) * s, px(-0.5) * s),
				jointC1 = CFrame.new()
            },

            -- BACK LEFT LEG (leg0: pivot [-4, 12, 7])
            BackLeftLeg = {
                size = Vector3.new(px(4), px(12), px(4)) * s,
                cframe = CFrame.new(px(-4) * s, px(0) * s, px(7) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "BackLeftLeg",
                motorName = "BackLeftLegMotor",
                jointC1 = CFrame.new(0, px(6) * s, 0)  -- Pivot at top of leg
            },

            -- BACK RIGHT LEG (leg1: pivot [4, 12, 7])
            BackRightLeg = {
                size = Vector3.new(px(4), px(12), px(4)) * s,
                cframe = CFrame.new(px(4) * s, px(0) * s, px(7) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "BackRightLeg",
                motorName = "BackRightLegMotor",
                jointC1 = CFrame.new(0, px(6) * s, 0)
            },

            -- FRONT LEFT LEG (leg2: pivot [-4, 12, -6])
            FrontLeftLeg = {
                size = Vector3.new(px(4), px(12), px(4)) * s,
                cframe = CFrame.new(px(-4) * s, px(0) * s, px(-6) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "FrontLeftLeg",
                motorName = "FrontLeftLegMotor",
                jointC1 = CFrame.new(0, px(6) * s, 0)
            },

            -- FRONT RIGHT LEG (leg3: pivot [4, 12, -6])
            FrontRightLeg = {
                size = Vector3.new(px(4), px(12), px(4)) * s,
                cframe = CFrame.new(px(4) * s, px(0) * s, px(-6) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "FrontRightLeg",
                motorName = "FrontRightLegMotor",
                jointC1 = CFrame.new(0, px(6) * s, 0)
            }
        }
    }
end

-- Build Chicken model from Minecraft Bedrock geometry.chicken.v1.12
function MinecraftBoneTranslator.BuildChickenModel(scale)
    local s = (type(scale) == "number" and scale > 0) and scale or 1

    -- Chicken colors
    local bodyColor = Color3.fromRGB(255, 255, 255)  -- White body
    local headColor = Color3.fromRGB(255, 255, 255)  -- White head
    local combColor = Color3.fromRGB(255, 0, 0)  -- Red comb
    local beakColor = Color3.fromRGB(255, 165, 0)  -- Orange beak
    local legColor = Color3.fromRGB(255, 215, 0)  -- Yellow legs
    local wingColor = Color3.fromRGB(255, 255, 255)  -- White wings

    -- COMPREHENSIVE FINAL CALCULATIONS FROM JSON:
    -- Body rotation [90, 0, 0] around pivot [0, 8, 0]
    -- rootOffset = 5 (leg pivot Y=5 touches ground)

    return {
        rootOffset = Vector3.new(0, px(5) * s, 0),
        parts = {
            -- BODY: pivot [0, 8, 0], origin [-3, 4, -3], size [6, 8, 6], rotation [90, 0, 0]
            -- Before rotation: cube center [0, 8, 0], spans Y: 4-12, Z: -3 to 3
            -- After 90° X rotation: Y and Z swap, size [6, 6, 8]
            -- Body is now horizontal, absolute center [0, 8, 0] → relative [0, 3, 0]
            Body = {
                size = Vector3.new(px(6), px(6), px(8)) * s,
                cframe = CFrame.new(0, px(3) * s, 0),
                material = Enum.Material.SmoothPlastic,
                color = bodyColor,
                tag = "Body",
                motorName = "BodyMotor"
            },

            -- HEAD: pivot [0, 9, -4], origin [-2, 9, -6], size [4, 6, 3], NO rotation
            -- JSON center: [0, 12, -4.5], but body ends at Z=-4
            -- To close gap: position head so back edge touches body front at Z=-4
            -- Head depth=3, so: back=-4, center=-5.5, front=-7
            -- Pivot [0, 9, -4] at neck, absolute [0, 9, -4] → relative [0, 4, -4]
            -- Adjusted center: [0, 12, -5.5] → relative [0, 7, -5.5]
            -- C1 offset: pivot - center = [0, -3, 1.5]
            Head = {
                size = Vector3.new(px(4), px(6), px(3)) * s,
                cframe = CFrame.new(0, px(7) * s, px(-5.5) * s),
                material = Enum.Material.SmoothPlastic,
                color = headColor,
                tag = "Head",
                motorName = "HeadMotor",
                c0 = CFrame.new(0, px(4) * s, px(-4) * s),
                jointC1 = CFrame.new(0, px(-3) * s, px(1.5) * s)
            },

            -- COMB (parent: head): origin [-1, 9, -7], size [2, 2, 2]
            -- JSON center: [0, 10, -6]
            -- Adjusted for new head position: center [0, 10, -7]
            -- Relative to HEAD center [0, 12, -5.5]: offset [0, -2, -1.5]
            Comb = {
                size = Vector3.new(px(2), px(2), px(2)) * s,
                cframe = CFrame.new(0, px(5) * s, px(-7) * s),
                material = Enum.Material.SmoothPlastic,
                color = combColor,
                tag = "Comb",
                motorName = "CombMotor",
                parent = "Head",
                c0 = CFrame.new(0, px(-2) * s, px(-1.5) * s),
                jointC1 = CFrame.new()
            },

            -- BEAK (parent: head): origin [-2, 11, -8], size [4, 2, 2]
            -- JSON center: [0, 12, -7]
            -- Adjusted for new head position: center [0, 12, -8]
            -- Relative to HEAD center [0, 12, -5.5]: offset [0, 0, -2.5]
            Beak = {
                size = Vector3.new(px(4), px(2), px(2)) * s,
                cframe = CFrame.new(0, px(7) * s, px(-8) * s),
                material = Enum.Material.SmoothPlastic,
                color = beakColor,
                tag = "Beak",
                motorName = "BeakMotor",
                parent = "Head",
                c0 = CFrame.new(0, 0, px(-2.5) * s),
                jointC1 = CFrame.new()
            },

            -- LEFT LEG (leg0) - MODIFIED: half width AND depth for thinner legs
            -- JSON: pivot [-2, 5, 1], origin [-3, 0, -2], size [3, 5, 3]
            -- Modified size: [1.5, 5, 1.5] for thinner legs (both X and Z halved)
            -- Part center: [-1.5, 2.5, -0.5] absolute = [-1.5, -2.5, -0.5] relative
            -- Pivot: [-2, 5, 1] absolute = [-2, 0, 1] relative
            -- C0 at pivot, C1 offset: pivot - center = [-0.5, 2.5, 1.5]
            LeftLeg = {
                size = Vector3.new(px(1.5), px(5), px(1.5)) * s,
                cframe = CFrame.new(px(-1.5) * s, px(-2.5) * s, px(-0.5) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "LeftLeg",
                motorName = "LeftLegMotor",
                c0 = CFrame.new(px(-2) * s, px(0) * s, px(1) * s),
                jointC1 = CFrame.new(px(-0.5) * s, px(2.5) * s, px(1.5) * s)
            },

            -- RIGHT LEG (leg1) - MODIFIED: half width AND depth for thinner legs
            -- JSON: pivot [1, 5, 1], origin [0, 0, -2], size [3, 5, 3]
            -- Modified size: [1.5, 5, 1.5] for thinner legs (both X and Z halved)
            -- Part center: [1.5, 2.5, -0.5] absolute = [1.5, -2.5, -0.5] relative
            -- Pivot: [1, 5, 1] absolute = [1, 0, 1] relative
            -- C0 at pivot, C1 offset: pivot - center = [-0.5, 2.5, 1.5]
            RightLeg = {
                size = Vector3.new(px(1.5), px(5), px(1.5)) * s,
                cframe = CFrame.new(px(1.5) * s, px(-2.5) * s, px(-0.5) * s),
                material = Enum.Material.SmoothPlastic,
                color = legColor,
                tag = "RightLeg",
                motorName = "RightLegMotor",
                c0 = CFrame.new(px(1) * s, px(0) * s, px(1) * s),
                jointC1 = CFrame.new(px(-0.5) * s, px(2.5) * s, px(1.5) * s)
            },

            -- LEFT WING (wing0)
            -- JSON: pivot [-3, 11, 0], origin [-4, 7, -3], size [1, 4, 6]
            -- Part center: [-3.5, 9, 0] absolute = [-3.5, 4, 0] relative
            -- Pivot: [-3, 11, 0] absolute = [-3, 6, 0] relative
            -- C0 at pivot, C1 offset: pivot - center = [0.5, 2, 0]
            LeftWing = {
                size = Vector3.new(px(1), px(4), px(6)) * s,
                cframe = CFrame.new(px(-3.5) * s, px(4) * s, 0),
                material = Enum.Material.SmoothPlastic,
                color = wingColor,
                tag = "LeftWing",
                motorName = "LeftWingMotor",
                c0 = CFrame.new(px(-3) * s, px(6) * s, 0),
                jointC1 = CFrame.new(px(0.5) * s, px(2) * s, 0)
            },

            -- RIGHT WING (wing1)
            -- JSON: pivot [3, 11, 0], origin [3, 7, -3], size [1, 4, 6]
            -- Part center: [3.5, 9, 0] absolute = [3.5, 4, 0] relative
            -- Pivot: [3, 11, 0] absolute = [3, 6, 0] relative
            -- C0 at pivot, C1 offset: pivot - center = [-0.5, 2, 0]
            RightWing = {
                size = Vector3.new(px(1), px(4), px(6)) * s,
                cframe = CFrame.new(px(3.5) * s, px(4) * s, 0),
                material = Enum.Material.SmoothPlastic,
                color = wingColor,
                tag = "RightWing",
                motorName = "RightWingMotor",
                c0 = CFrame.new(px(3) * s, px(6) * s, 0),
                jointC1 = CFrame.new(px(-0.5) * s, px(2) * s, 0)
            }
        }
    }
end

-- Build an NPC model with customizable outfit color and optional props
-- Used for hub world NPCs (Shop Keeper, Merchant, Warp Master)
function MinecraftBoneTranslator.BuildNPCModel(scale, outfitColor, npcType)
    local s = (type(scale) == "number" and scale > 0) and scale or 1
    local geometry = MinecraftBoneTranslator.BuildZombieGeometry()
    local processed = MinecraftBoneTranslator.ProcessGeometry(geometry)

    -- Default colors
    local skinColor = Color3.fromRGB(255, 213, 170)
    local outfit = outfitColor or Color3.fromRGB(60, 120, 220)

    local parts = {}

    local function scaleCFrame(cf)
        if not cf then return nil end
        local pos = cf.Position
        local rot = cf - cf.Position
        return CFrame.new(pos.X * s, pos.Y * s, pos.Z * s) * rot
    end

    local function addFrom(nameKey, tag, motorName, color)
        local d = processed[nameKey]
        if not d then return end
        parts[tag] = {
            size = d.size * s,
            cframe = scaleCFrame(d.cframe),
            c0 = scaleCFrame(d.c0),
            c1 = scaleCFrame(d.c1),
            material = Enum.Material.SmoothPlastic,
            color = color,
            tag = tag,
            motorName = motorName
        }
    end

    -- Head with skin color
    addFrom("head_1_skin", "Head", "HeadMotor", skinColor)
    -- Body and limbs with outfit color
    addFrom("body_1_skin", "Torso", "TorsoMotor", outfit)
    addFrom("leftArm_1_skin", "LeftArm", "LeftArmMotor", outfit)
    addFrom("rightArm_1_skin", "RightArm", "RightArmMotor", outfit)
    addFrom("leftLeg_1_skin", "LeftLeg", "LeftLegMotor", outfit)
    addFrom("rightLeg_1_skin", "RightLeg", "RightLegMotor", outfit)

    -- Add NPC-specific props based on type
    if npcType == "SHOP_KEEPER" then
        -- Add a chest/box prop
        parts.Prop = {
            size = Vector3.new(0.6, 0.5, 0.4) * s,
            cframe = CFrame.new(0, 0, 0),
            material = Enum.Material.Wood,
            color = Color3.fromRGB(139, 90, 43),
            tag = "Prop",
            motorName = "PropMotor",
            parent = "LeftArm",
            c0 = CFrame.new(0, -0.7 * s, -0.3 * s),
            jointC1 = CFrame.new()
        }
    elseif npcType == "MERCHANT" then
        -- Add a coin bag prop
        parts.Prop = {
            size = Vector3.new(0.4, 0.5, 0.3) * s,
            cframe = CFrame.new(0, 0, 0),
            material = Enum.Material.Fabric,
            color = Color3.fromRGB(139, 119, 42),
            tag = "Prop",
            motorName = "PropMotor",
            parent = "RightArm",
            c0 = CFrame.new(0, -0.7 * s, -0.3 * s),
            jointC1 = CFrame.new()
        }
    elseif npcType == "WARP_MASTER" then
        -- Add a staff/wand prop
        parts.Prop = {
            size = Vector3.new(0.15, 1.5, 0.15) * s,
            cframe = CFrame.new(0, 0, 0),
            material = Enum.Material.Neon,
            color = Color3.fromRGB(180, 120, 255),
            tag = "Prop",
            motorName = "PropMotor",
            parent = "RightArm",
            c0 = CFrame.new(0, -0.8 * s, -0.2 * s) * CFrame.Angles(math.rad(15), 0, 0),
            jointC1 = CFrame.new()
        }
    end

    return {
        rootOffset = Vector3.new(0, 0, 0),
        parts = parts
    }
end

-- NPC outfit colors for different types
MinecraftBoneTranslator.NPCColors = {
    SHOP_KEEPER = Color3.fromRGB(50, 180, 80),   -- Green
    MERCHANT = Color3.fromRGB(220, 170, 50),     -- Gold
    WARP_MASTER = Color3.fromRGB(140, 80, 220),  -- Purple
}

return MinecraftBoneTranslator

