--[[
	MobileControlTypes.lua
	Type definitions and enums for mobile controls
]]

local MobileControlTypes = {}

-- Device Types
MobileControlTypes.DeviceType = {
	SmallPhone = "SmallPhone",
	Phone = "Phone",
	Tablet = "Tablet",
	Unknown = "Unknown",
}

-- Control Schemes
MobileControlTypes.ControlScheme = {
	Classic = "Classic",
	Split = "Split",
	OneHandedLeft = "OneHandedLeft",
	OneHandedRight = "OneHandedRight",
}

-- Button Types
MobileControlTypes.ButtonType = {
	Jump = "Jump",
	Crouch = "Crouch",
	Sprint = "Sprint",
	Interact = "Interact",
	UseItem = "UseItem",
	PlaceBlock = "PlaceBlock",
	Attack = "Attack",
}

-- Gesture Types
MobileControlTypes.GestureType = {
	Tap = "Tap",
	LongPress = "LongPress",
	Drag = "Drag",
	Swipe = "Swipe",
	Pinch = "Pinch",
}

-- Feedback Types
MobileControlTypes.FeedbackType = {
	Light = "Light",
	Medium = "Medium",
	Strong = "Strong",
	Success = "Success",
	Error = "Error",
	Warning = "Warning",
}

-- Colorblind Modes
MobileControlTypes.ColorblindMode = {
	None = "None",
	Protanopia = "Protanopia",
	Deuteranopia = "Deuteranopia",
	Tritanopia = "Tritanopia",
}

return MobileControlTypes

