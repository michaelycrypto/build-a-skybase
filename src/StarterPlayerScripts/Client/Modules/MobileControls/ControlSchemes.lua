--[[
	ControlSchemes.lua
	Manages different control schemes (Classic, Split, One-Handed)

	Features:
	- Switch between control schemes
	- Apply scheme-specific settings
	- Layout adjustments
]]

local ControlSchemes = {}
ControlSchemes.__index = ControlSchemes

-- Available schemes
local SchemeType = {
	Classic = "Classic",
	Split = "Split",
	OneHandedLeft = "OneHandedLeft",
	OneHandedRight = "OneHandedRight",
}

function ControlSchemes.new()
	local self = setmetatable({}, ControlSchemes)

	-- Current scheme
	self.currentScheme = SchemeType.Classic

	-- Scheme definitions
	self.schemes = {
		[SchemeType.Classic] = {
			name = "Classic",
			description = "Full-screen camera, thumbstick on left",
			thumbstickPosition = UDim2.new(0, 100, 1, -150),
			cameraZone = "FullScreen",
			buttonLayout = "RightSide",
			splitRatio = 0,
			showCrosshair = false,
			buttons = {
				Jump = UDim2.new(1, -90, 1, -150),
				Crouch = UDim2.new(1, -90, 1, -240),
				Sprint = UDim2.new(1, -180, 1, -150),
			},
		},

		[SchemeType.Split] = {
			name = "Split-Screen",
			description = "Left side movement, right side camera (Minecraft-style)",
			thumbstickPosition = UDim2.new(0, 100, 1, -150),
			cameraZone = "RightHalf",
			buttonLayout = "RightSide",
			splitRatio = 0.4,
			showCrosshair = true,
			buttons = {
				Jump = UDim2.new(1, -90, 1, -150),
				Crouch = UDim2.new(0, 120, 1, -240),
				Sprint = UDim2.new(0, 210, 1, -240),
			},
		},

		[SchemeType.OneHandedLeft] = {
			name = "One-Handed (Left)",
			description = "All controls on left side",
			thumbstickPosition = UDim2.new(0, 100, 1, -150),
			cameraZone = "FullScreen",
			buttonLayout = "LeftSide",
			splitRatio = 0,
			showCrosshair = false,
			autoAim = true,
			buttons = {
				Jump = UDim2.new(0, 100, 1, -80),
				Crouch = UDim2.new(0, 190, 1, -150),
				Sprint = UDim2.new(0, 190, 1, -240),
			},
		},

		[SchemeType.OneHandedRight] = {
			name = "One-Handed (Right)",
			description = "All controls on right side",
			thumbstickPosition = UDim2.new(1, -150, 1, -150),
			cameraZone = "FullScreen",
			buttonLayout = "RightSide",
			splitRatio = 0,
			showCrosshair = false,
			autoAim = true,
			buttons = {
				Jump = UDim2.new(1, -150, 1, -80),
				Crouch = UDim2.new(1, -240, 1, -150),
				Sprint = UDim2.new(1, -240, 1, -240),
			},
		},
	}

	return self
end

--[[
	Get available schemes
]]
function ControlSchemes:GetAvailableSchemes()
	local schemes = {}
	for schemeType, schemeData in pairs(self.schemes) do
		table.insert(schemes, {
			type = schemeType,
			name = schemeData.name,
			description = schemeData.description,
		})
	end
	return schemes
end

--[[
	Get current scheme
]]
function ControlSchemes:GetCurrentScheme()
	return self.currentScheme
end

--[[
	Get scheme data
]]
function ControlSchemes:GetSchemeData(schemeType)
	return self.schemes[schemeType]
end

--[[
	Set current scheme
]]
function ControlSchemes:SetScheme(schemeType)
	if not self.schemes[schemeType] then
		warn("Invalid scheme type:", schemeType)
		return false
	end

	self.currentScheme = schemeType
	print("📱 Control Scheme:", self.schemes[schemeType].name)

	return true
end

--[[
	Apply scheme to controllers
]]
function ControlSchemes:ApplyScheme(schemeType, controllers)
	local schemeData = self.schemes[schemeType]
	if not schemeData then
		warn("Invalid scheme type:", schemeType)
		return false
	end

	-- Apply to thumbstick
	if controllers.thumbstick then
		controllers.thumbstick:SetPosition(schemeData.thumbstickPosition)
	end

	-- Apply to camera controller
	if controllers.camera then
		controllers.camera:SetControlScheme(schemeData.cameraZone == "RightHalf" and "Split" or "Classic")
		if schemeData.splitRatio then
			controllers.camera:SetSplitRatio(schemeData.splitRatio)
		end
	end

	-- Apply to action buttons
	if controllers.actionButtons then
		for buttonType, position in pairs(schemeData.buttons) do
			controllers.actionButtons:SetButtonPosition(buttonType, position)
		end
	end

	-- Apply crosshair visibility (if exists)
	if controllers.crosshair and schemeData.showCrosshair ~= nil then
		controllers.crosshair:SetVisible(schemeData.showCrosshair)
	end

	self.currentScheme = schemeType
	return true
end

--[[
	Get scheme button positions
]]
function ControlSchemes:GetButtonPositions(schemeType)
	local schemeData = self.schemes[schemeType or self.currentScheme]
	if not schemeData then return {} end

	return schemeData.buttons
end

--[[
	Check if scheme uses split screen
]]
function ControlSchemes:IsSplitScreen(schemeType)
	local schemeData = self.schemes[schemeType or self.currentScheme]
	if not schemeData then return false end

	return schemeData.cameraZone == "RightHalf"
end

--[[
	Check if scheme is one-handed
]]
function ControlSchemes:IsOneHanded(schemeType)
	schemeType = schemeType or self.currentScheme
	return schemeType == SchemeType.OneHandedLeft or schemeType == SchemeType.OneHandedRight
end

--[[
	Get scheme types (for external use)
]]
function ControlSchemes:GetSchemeTypes()
	return SchemeType
end

return ControlSchemes

