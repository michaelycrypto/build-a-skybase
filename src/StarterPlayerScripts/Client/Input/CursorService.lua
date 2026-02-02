local CursorService = {}
CursorService.__index = CursorService

local function cloneOptions(options)
	if not options then
		return {}
	end

	return table.clone(options)
end

function CursorService.new(config)
	local self = setmetatable({}, CursorService)

	self._userInputService = config.userInputService
	self._determineCursorBehavior = config.determineCursorBehavior
	self._shouldShowCursor = config.shouldShowCursor
	self._defaultSensitivity = config.defaultSensitivity or 1
	self._validateCursorMode = config.validateCursorMode
	self._modeChangedCallback = config.modeChangedCallback or function() end
	self._gameplayCursor = config.gameplayCursor

	self._stack = {}
	self._stack[1] = self._gameplayCursor

	self._nextCursorToken = 0
	self._activeCursorToken = self._gameplayCursor.token
	self._activeEffectiveMode = self._gameplayCursor.mode
	self._activeEffectiveSource = self._gameplayCursor.source

	return self
end

function CursorService:SetDefaultSensitivity(value)
	self._defaultSensitivity = value or self._defaultSensitivity
end

function CursorService:Apply()
	self:_applyCursorState()
end

function CursorService:SetGameplayCursorMode(mode, options)
	local resolvedMode = self._validateCursorMode and self._validateCursorMode(mode, "SetGameplayCursorMode") or mode
	self._gameplayCursor.mode = resolvedMode
	if options then
		self._gameplayCursor.options = options
	end
	self:_applyCursorState()
end

function CursorService:PushCursorMode(source, mode, options)
	self._nextCursorToken += 1
	local token = ("%s_%d"):format(source or "anon", self._nextCursorToken)
	local resolvedMode = self._validateCursorMode and self._validateCursorMode(mode, "PushCursorMode") or mode

	table.insert(self._stack, {
		token = token,
		source = source or "unknown",
		mode = resolvedMode,
		options = options or {},
	})

	self:_applyCursorState()
	return token
end

function CursorService:PopCursorMode(token)
	if not token then
		return
	end

	for index = #self._stack, 2, -1 do
		if self._stack[index].token == token then
			table.remove(self._stack, index)
			break
		end
	end

	self:_applyCursorState()
end

function CursorService:GetCurrentMode()
	local active = self._stack[#self._stack]
	return (active and active.mode) or (self._gameplayCursor and self._gameplayCursor.mode)
end

function CursorService:GetCursorStack()
	local snapshot = {}
	for index, entry in ipairs(self._stack) do
		snapshot[index] = {
			token = entry.token,
			source = entry.source,
			mode = entry.mode,
			options = cloneOptions(entry.options),
		}
	end
	return snapshot
end

function CursorService:DescribeCursorState()
	local snapshot = self:GetCursorStack()
	local lines = {
		("Active Mode: %s (source: %s)"):format(
			self._activeEffectiveMode or "unknown",
			self._activeEffectiveSource or "unknown"
		),
		("Stack Depth: %d"):format(#snapshot),
	}

	for index = #snapshot, 1, -1 do
		local entry = snapshot[index]
		lines[#lines + 1] = ("  [%d] %s (%s)"):format(index, entry.mode, entry.source)
	end

	return table.concat(lines, "\n")
end

function CursorService:_applyCursorState()
	if #self._stack == 0 then
		warn("[CursorService] Cursor stack empty; restoring gameplay entry")
		self._stack[1] = self._gameplayCursor
	end

	local active = self._stack[#self._stack]

	local behavior = self._determineCursorBehavior(active.mode, active.options)
	if self._userInputService.MouseBehavior ~= behavior then
		self._userInputService.MouseBehavior = behavior
	end

	local showIcon = self._shouldShowCursor(active.mode, active.options)
	if self._userInputService.MouseIconEnabled ~= showIcon then
		self._userInputService.MouseIconEnabled = showIcon
	end

	local desiredSensitivity = (active.options and active.options.mouseDeltaSensitivity) or self._defaultSensitivity
	if self._userInputService.MouseDeltaSensitivity ~= desiredSensitivity then
		self._userInputService.MouseDeltaSensitivity = desiredSensitivity
	end

	if self._activeCursorToken ~= active.token
		or self._activeEffectiveMode ~= active.mode
		or self._activeEffectiveSource ~= active.source
	then
		self._activeCursorToken = active.token
		self._activeEffectiveMode = active.mode
		self._activeEffectiveSource = active.source
		if self._modeChangedCallback then
			self._modeChangedCallback(active.mode, active.source)
		end
	end
end

return CursorService

