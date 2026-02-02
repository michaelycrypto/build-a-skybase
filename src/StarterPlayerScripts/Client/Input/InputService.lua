--[[
	InputService.lua
	Centralized orchestration layer for desktop, gamepad, and mobile inputs.
	- Owns all UserInputService interactions
	- Provides uniform signals for gameplay actions (primary/secondary/sprint/etc.)
	- Manages cursor locking via a stack (gameplay vs UI focus)
	- Bridges mobile thumbsticks/action buttons into the same event surface
]]

local _Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Signal)
local GameState = require(script.Parent.Parent.Managers.GameState)
local MobileControlController = require(script.Parent.Parent.Controllers.MobileControlController)
local CursorService = require(script.Parent.CursorService)
local GameplayLockController = require(script.Parent.GameplayLockController)

local InputService = {}

-- Signals mirrored from UserInputService plus high-level gameplay events
InputService.InputBegan = Signal.new()
InputService.InputChanged = Signal.new()
InputService.InputEnded = Signal.new()
InputService.LastInputTypeChanged = Signal.new()

InputService.PrimaryDown = Signal.new()
InputService.PrimaryUp = Signal.new()
InputService.SecondaryDown = Signal.new()
InputService.SecondaryUp = Signal.new()
InputService.InteractRequested = Signal.new()

InputService.InputModeChanged = Signal.new()
InputService.CursorModeChanged = Signal.new()
InputService.GameplayLockChanged = Signal.new()

-- Internal constants
local PRIMARY_MOUSE_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
}

local SECONDARY_MOUSE_TYPES = {
	[Enum.UserInputType.MouseButton2] = true,
}

local PRIMARY_GAMEPAD_KEYS = {
	[Enum.KeyCode.ButtonR2] = true,
	[Enum.KeyCode.ButtonX] = true,
}

local SECONDARY_GAMEPAD_KEYS = {
	[Enum.KeyCode.ButtonL2] = true,
	[Enum.KeyCode.ButtonB] = true,
}

local MOBILE_BUTTON_ACTIONS = {
	Attack = "primary",
	UseItem = "secondary",
	PlaceBlock = "secondary",
	Interact = "interact",
	Sprint = "sprint",
	Camera = "camera",
}

-- State
InputService._connections = {}
InputService.CursorMode = {
	GAMEPLAY_LOCK = "gameplay-lock",
	GAMEPLAY_FREE = "gameplay-free",
	UI = "ui",
	CINEMATIC = "cinematic",
}

local OVERLAY_CURSOR_MODES = {
	[InputService.CursorMode.UI] = true,
	[InputService.CursorMode.CINEMATIC] = true,
}

local GAMEPLAY_CURSOR_MODES = {
	[InputService.CursorMode.GAMEPLAY_LOCK] = true,
	[InputService.CursorMode.GAMEPLAY_FREE] = true,
}

local function validateCursorMode(mode, context)
	if not mode then
		warn(("[InputService] %s provided nil cursor mode; defaulting to gameplay-lock"):format(context or "Unknown caller"))
		return InputService.CursorMode.GAMEPLAY_LOCK
	end

	if not (OVERLAY_CURSOR_MODES[mode] or GAMEPLAY_CURSOR_MODES[mode]) then
		warn(("[InputService] %s provided unknown cursor mode '%s'"):format(context or "Unknown caller", tostring(mode)))
	end
	return mode
end

InputService._inputMode = "mouseKeyboard"
InputService._gameplayCursor = {
	token = "__gameplay__",
	source = "gameplay",
	mode = InputService.CursorMode.GAMEPLAY_LOCK,
	options = {
		showIcon = false,
		mouseDeltaSensitivity = UserInputService.MouseDeltaSensitivity or 1,
	},
}
InputService._defaultSensitivity = UserInputService.MouseDeltaSensitivity or 1
InputService._mobileController = false
InputService._initialized = false
InputService._movementActionName = "InputServiceDisableMovement"
InputService._suppressedInputs = {
	Enum.KeyCode.W,
	Enum.KeyCode.A,
	Enum.KeyCode.S,
	Enum.KeyCode.D,
	Enum.KeyCode.Space,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift,
}
InputService._gameplayLocked = false

-- Metatable fallback so existing utility methods can proxy to UserInputService
setmetatable(InputService, {
	__index = function(_, key)
		local rawValue = UserInputService[key]
		if typeof(rawValue) == "function" then
			return function(_, ...)
				return rawValue(UserInputService, ...)
			end
		end
		return rawValue
	end,
})

local function isGamepadInput(userInputType)
	if not userInputType then
		return false
	end
	return userInputType.Name:find("Gamepad") ~= nil
end

local function determineCursorBehavior(mode, options)
	if options and options.mouseBehavior then
		return options.mouseBehavior
	end

	if mode == InputService.CursorMode.GAMEPLAY_LOCK then
		return Enum.MouseBehavior.LockCenter
	end

	return Enum.MouseBehavior.Default
end

local function shouldShowCursor(mode, options)
	if options and options.showIcon ~= nil then
		return options.showIcon
	end
	return mode ~= InputService.CursorMode.GAMEPLAY_LOCK
end

InputService._cursorController = CursorService.new({
	userInputService = UserInputService,
	determineCursorBehavior = determineCursorBehavior,
	shouldShowCursor = shouldShowCursor,
	defaultSensitivity = InputService._defaultSensitivity,
	validateCursorMode = validateCursorMode,
	gameplayCursor = InputService._gameplayCursor,
	modeChangedCallback = function(mode, source)
		InputService.CursorModeChanged:Fire(mode, source)
	end,
})

InputService._gameplayLockController = GameplayLockController.new({
	contextActionService = ContextActionService,
	movementActionName = InputService._movementActionName,
	suppressedInputs = InputService._suppressedInputs,
	getMobileController = function()
		return InputService._mobileController
	end,
	onStateChanged = function(isLocked)
		InputService._gameplayLocked = isLocked
		InputService.GameplayLockChanged:Fire(isLocked)
	end,
})

function InputService:_connectUserInput()
	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
		self:_updateInputMode(input and input.UserInputType)
		self.InputBegan:Fire(input, gameProcessed)
		if not gameProcessed then
			self:_handleActionBegin(input)
		end
	end))

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input, gameProcessed)
		self.InputChanged:Fire(input, gameProcessed)
	end))

	table.insert(self._connections, UserInputService.InputEnded:Connect(function(input, gameProcessed)
		self.InputEnded:Fire(input, gameProcessed)
		self:_handleActionEnded(input)
	end))

	table.insert(self._connections, UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		self.LastInputTypeChanged:Fire(lastInputType)
		self:_updateInputMode(lastInputType)
	end))
end

function InputService:_handleActionBegin(input)
	if self:_isGameplayLocked() then
		return
	end
	if not input then
		return
	end

	if PRIMARY_MOUSE_TYPES[input.UserInputType] or input.UserInputType == Enum.UserInputType.Touch or PRIMARY_GAMEPAD_KEYS[input.KeyCode] then
		self.PrimaryDown:Fire(input)
	elseif SECONDARY_MOUSE_TYPES[input.UserInputType] or SECONDARY_GAMEPAD_KEYS[input.KeyCode] then
		self.SecondaryDown:Fire(input)
	end
end

function InputService:_handleActionEnded(input)
	if self:_isGameplayLocked() then
		return
	end
	if not input then
		return
	end

	if PRIMARY_MOUSE_TYPES[input.UserInputType] or input.UserInputType == Enum.UserInputType.Touch or PRIMARY_GAMEPAD_KEYS[input.KeyCode] then
		self.PrimaryUp:Fire(input)
	elseif SECONDARY_MOUSE_TYPES[input.UserInputType] or SECONDARY_GAMEPAD_KEYS[input.KeyCode] then
		self.SecondaryUp:Fire(input)
	end
end

function InputService:_isGameplayLocked()
	return self._gameplayLockController:IsLocked()
end

--[[
	Apply cursor state based on the cursor stack.

	The stack is evaluated top-to-bottom:
	- UI components push "ui" mode entries when they open
	- CameraController sets the base gameplay mode via SetGameplayCursorMode
	- The topmost non-gameplay entry wins, otherwise gameplay mode applies

	This is the SOLE writer to UserInputService cursor properties.
]]


function InputService:_updateInputMode(lastInputType)
	local newMode
	if self:_shouldUseMobileController() or lastInputType == Enum.UserInputType.Touch then
		newMode = "touch"
	elseif isGamepadInput(lastInputType) or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled) then
		newMode = "gamepad"
	else
		newMode = "mouseKeyboard"
	end

	if newMode == self._inputMode then
		return
	end

	self._inputMode = newMode
	GameState:Set("input.mode", newMode)
	self.InputModeChanged:Fire(newMode)

	if newMode == "touch" and not self._mobileController then
		self:_initializeMobileController()
	end
end

function InputService:_shouldUseMobileController()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function InputService:_initializeMobileController()
	if self._mobileController then
		return
	end

	local controller = MobileControlController.new(self)
	controller:Initialize({
		onButton = function(buttonType, isPressed)
			self:_handleMobileButton(buttonType, isPressed)
		end,
	})

	self._mobileController = controller
	self:_applyHighContrast(GameState:Get("settings.highContrast"))
end

function InputService:_handleMobileButton(buttonType, isPressed)
	if self:_isGameplayLocked() then
		return
	end
	if not buttonType then
		return
	end

	local mapped = MOBILE_BUTTON_ACTIONS[buttonType]
	if not mapped then
		return
	end

	if mapped == "primary" then
		if isPressed then
			self.PrimaryDown:Fire(nil)
		else
			self.PrimaryUp:Fire(nil)
		end
	elseif mapped == "secondary" then
		if isPressed then
			self.SecondaryDown:Fire(nil)
		else
			self.SecondaryUp:Fire(nil)
		end
	elseif mapped == "interact" then
		if isPressed then
			self.InteractRequested:Fire()
		end
	end
end

function InputService:_applyHighContrast(enabled)
	self._highContrast = enabled and true or false
	if self._mobileController and self._mobileController.SetHighContrast then
		self._mobileController:SetHighContrast(self._highContrast)
	end
end

-- Public API
function InputService:Initialize(config)
	if self._initialized then
		return
	end

	self._config = config or {}
	self._gameplayCursor.options.mouseDeltaSensitivity = UserInputService.MouseDeltaSensitivity or 1
	self._defaultSensitivity = self._gameplayCursor.options.mouseDeltaSensitivity
	self._cursorController:SetDefaultSensitivity(self._defaultSensitivity)

	self:_connectUserInput()
	self:_updateInputMode()
	self._cursorController:Apply()

	GameState:OnPropertyChanged("settings.highContrast", function(newValue)
		self:_applyHighContrast(newValue == true)
	end)

	-- NOTE: We intentionally do NOT listen to UI GameState flags (inventoryOpen, panelManagerOpen, etc.)
	-- for cursor control. UI components push/pop cursor modes directly via PushCursorMode/PopCursorMode.
	-- This eliminates race conditions between multiple systems fighting over cursor state.
	-- CameraController handles freezing camera state when UI is open.

	self._initialized = true

	if self:_shouldUseMobileController() then
		self:_initializeMobileController()
	end
end

function InputService:SetGameplayCursorMode(mode, options)
	self._cursorController:SetGameplayCursorMode(mode or InputService.CursorMode.GAMEPLAY_LOCK, options)
end

function InputService:PushCursorMode(source, mode, options)
	return self._cursorController:PushCursorMode(source, mode or InputService.CursorMode.UI, options)
end

function InputService:PopCursorMode(token)
	self._cursorController:PopCursorMode(token)
end

function InputService:SetHighContrast(enabled)
	GameState:Set("settings.highContrast", enabled)
	self:_applyHighContrast(enabled)
end

function InputService:IsOverlayMode(mode)
	return OVERLAY_CURSOR_MODES[mode] == true
end

function InputService:GetCursorStack()
	return self._cursorController:GetCursorStack()
end

function InputService:DescribeCursorState()
	return self._cursorController:DescribeCursorState()
end

function InputService:PrintCursorDebug()
	print("[InputService] Cursor Diagnostics")
	print(self:DescribeCursorState())
end

function InputService:VerifyCursorStackIntegrity()
	local snapshot = self:GetCursorStack()
	local baseEntry = snapshot[1]
	if not baseEntry or baseEntry.token ~= self._gameplayCursor.token then
		warn("[InputService] Cursor stack missing gameplay base entry")
		return false
	end
	return true
end

function InputService:BeginOverlay(source, cursorOptions)
	source = source or "Overlay"
	local releaseCalled = false
	local cursorToken = self:PushCursorMode(source, InputService.CursorMode.UI, cursorOptions or {
		showIcon = true,
	})
	local lockToken = self:PushGameplayLock(source)

	local function release()
		if releaseCalled then
			return
		end
		releaseCalled = true
		if lockToken then
			self:PopGameplayLock(lockToken)
			lockToken = nil
		end
		if cursorToken then
			self:PopCursorMode(cursorToken)
			cursorToken = nil
		end
	end

	return release
end

function InputService:PushGameplayLock(source)
	return self._gameplayLockController:PushLock(source)
end

function InputService:PopGameplayLock(token)
	self._gameplayLockController:PopLock(token)
end

--[[
	Check if gameplay interactions should be blocked.
	Returns true when UI overlays are open (inventory, chest, worlds, minion, etc.)

	This is THE single source of truth for checking if mouse/keyboard gameplay
	interactions should be disabled. Use this instead of checking multiple
	GameState flags or UIVisibilityManager mode.

	Usage:
		if InputService:IsGameplayBlocked() then return end
]]
function InputService:IsGameplayBlocked()
	return self._gameplayLockController:IsLocked()
end

--[[
	Inverse of IsGameplayBlocked for more readable code.
	Returns true when gameplay interactions should be allowed.

	Usage:
		if not InputService:IsGameplayActive() then return end
]]
function InputService:IsGameplayActive()
	return not self._gameplayLockController:IsLocked()
end

return InputService
