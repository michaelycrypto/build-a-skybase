--[[
	MobileControlConfig.lua
	Configuration for mobile controls - Minecraft-inspired
]]

local MobileControlConfig = {
	-- Movement Controls
	Movement = {
		ThumbstickRadius = 60, -- Size of the thumbstick
		ThumbstickOpacity = 0.6, -- Transparency
		DeadZone = 0.15, -- Center dead zone (0-1)
		Position = UDim2.new(0, 100, 1, -150), -- Bottom-left position
		DynamicPosition = false, -- If true, thumbstick appears where user touches
		SnapToDirections = false, -- Snap to 8 cardinal directions
		EnableFloating = true, -- Thumbstick follows thumb within bounds
		MaxFloatDistance = 30, -- Max distance thumbstick can move from start
	},

	-- Camera Controls
	Camera = {
		SensitivityX = 0.5, -- Horizontal sensitivity (0-2)
		SensitivityY = 0.5, -- Vertical sensitivity (0-2)
		InvertY = false, -- Invert Y-axis
		Smoothing = 0.2, -- Camera smoothing factor (0-1)
		GyroscopeEnabled = false, -- Use device tilt
		GyroscopeSensitivity = 1.0,
		ControlScheme = "Classic", -- Classic, Split, Gyro
		MaxVerticalAngle = 80, -- Prevent looking too far up/down
	},

	-- Action Buttons
	Actions = {
		ButtonSize = 65, -- Size in pixels
		ButtonOpacity = 0.7,
		ButtonSpacing = 15, -- Space between buttons
		ToggleMode = false, -- false = hold, true = toggle
		ShowLabels = true, -- Show button text labels
		Positions = {
			-- Default positions (right side)
			Jump = UDim2.new(1, -90, 1, -150),
			Crouch = UDim2.new(1, -90, 1, -240),
			Sprint = UDim2.new(1, -180, 1, -150),
			Interact = UDim2.new(0.5, -35, 1, -100), -- Center-bottom for context actions
		},
	},

	-- Control Schemes
	Schemes = {
		Classic = {
			Name = "Classic",
			Description = "Full-screen camera, thumbstick on left",
			ThumbstickPosition = UDim2.new(0, 100, 1, -150),
			CameraZone = "FullScreen", -- or "RightHalf"
			ButtonLayout = "RightSide",
		},
		Split = {
			Name = "Split-Screen",
			Description = "Left side movement, right side camera (Minecraft-style)",
			ThumbstickPosition = UDim2.new(0, 100, 1, -150),
			CameraZone = "RightHalf",
			ButtonLayout = "RightSide",
			ShowCrosshair = true,
			SplitRatio = 0.4, -- 40% left for movement
		},
		OneHandedLeft = {
			Name = "One-Handed (Left)",
			Description = "All controls on left side",
			ThumbstickPosition = UDim2.new(0, 100, 1, -150),
			CameraZone = "FullScreen",
			ButtonLayout = "LeftSide",
			AutoAim = true,
		},
		OneHandedRight = {
			Name = "One-Handed (Right)",
			Description = "All controls on right side",
			ThumbstickPosition = UDim2.new(1, -150, 1, -150),
			CameraZone = "FullScreen",
			ButtonLayout = "RightSide",
			AutoAim = true,
		},
	},

	-- Accessibility
	Accessibility = {
		UIScale = 1.0, -- Overall UI scaling (0.75-1.5)
		ColorblindMode = "None", -- None, Protanopia, Deuteranopia, Tritanopia
		HighContrast = false,
		ReduceMotion = false,
		TouchAssistance = 0, -- 0=Off, 1=Low, 2=Medium, 3=High
		OneHandedMode = false,
		OneHandedSide = "Right", -- Right or Left
		HapticIntensity = 1.0, -- 0.0-2.0
		AudioCues = true,
		AutoJump = false, -- Auto jump when approaching obstacles
		AutoAim = false, -- Subtle aim assistance
		TapRadius = 0, -- Extra pixels around buttons (0-20)
		MinimumTouchSize = 48, -- Minimum button size in pixels (accessibility)
		StickyButtons = false, -- Buttons stay pressed without holding

		-- Color themes for colorblind support
		ColorThemes = {
			Default = {
				Primary = Color3.fromRGB(255, 255, 255),
				Secondary = Color3.fromRGB(200, 200, 200),
				Accent = Color3.fromRGB(100, 200, 255),
				Background = Color3.fromRGB(40, 40, 50),
			},
			HighContrast = {
				Primary = Color3.fromRGB(255, 255, 255),
				Secondary = Color3.fromRGB(255, 255, 0),
				Accent = Color3.fromRGB(0, 255, 255),
				Background = Color3.fromRGB(0, 0, 0),
			},
			Protanopia = { -- Red-blind
				Primary = Color3.fromRGB(255, 255, 255),
				Secondary = Color3.fromRGB(150, 150, 255),
				Accent = Color3.fromRGB(100, 200, 255),
				Background = Color3.fromRGB(40, 40, 50),
			},
			Deuteranopia = { -- Green-blind
				Primary = Color3.fromRGB(255, 255, 255),
				Secondary = Color3.fromRGB(255, 200, 100),
				Accent = Color3.fromRGB(100, 150, 255),
				Background = Color3.fromRGB(40, 40, 50),
			},
			Tritanopia = { -- Blue-blind
				Primary = Color3.fromRGB(255, 255, 255),
				Secondary = Color3.fromRGB(255, 100, 100),
				Accent = Color3.fromRGB(100, 255, 200),
				Background = Color3.fromRGB(40, 40, 50),
			},
		},
	},

	-- Visual Feedback
	Visual = {
		Theme = "Default",
		ShowTutorialHints = true,
		DebugOverlay = false, -- Show touch points for debugging
		ParticleEffects = true,
		AnimationSpeed = 1.0, -- 0.5-2.0
		ButtonPressScale = 0.9, -- Scale when pressed
		ButtonPressAlpha = 1.0, -- Opacity when pressed
		RippleEffect = true,
	},

	-- Haptic Feedback Patterns
	Haptics = {
		ButtonPress = {
			Duration = 0.05,
			Intensity = 0.3,
		},
		ActionSuccess = {
			Duration = 0.1,
			Intensity = 0.5,
		},
		ActionFail = {
			Duration = 0.15,
			Intensity = 0.7,
		},
		DirectionChange = {
			Duration = 0.03,
			Intensity = 0.2,
		},
	},

	-- Performance
	Performance = {
		TouchSamplingRate = 60, -- Hz
		ReduceEffects = false,
		InputLatencyCompensation = true,
		MaxSimultaneousTouches = 5,
	},

	-- Device Presets
	DevicePresets = {
		SmallPhone = {
			Condition = function(screenSize) return screenSize.X < 375 end,
			UIScale = 0.85,
			ButtonSize = 55,
			ThumbstickRadius = 50,
		},
		Phone = {
			Condition = function(screenSize) return screenSize.X >= 375 and screenSize.X < 768 end,
			UIScale = 1.0,
			ButtonSize = 65,
			ThumbstickRadius = 60,
		},
		Tablet = {
			Condition = function(screenSize) return screenSize.X >= 768 end,
			UIScale = 1.2,
			ButtonSize = 75,
			ThumbstickRadius = 70,
			SuggestScheme = "Split",
		},
	},
}

return MobileControlConfig

