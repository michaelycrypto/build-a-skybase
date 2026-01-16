local GameplayLockController = {}
GameplayLockController.__index = GameplayLockController

function GameplayLockController.new(config)
	local self = setmetatable({}, GameplayLockController)

	self._contextActionService = config.contextActionService
	self._movementActionName = config.movementActionName
	self._suppressedInputs = config.suppressedInputs or {}
	self._getMobileController = config.getMobileController
	self._stateChangedCallback = config.onStateChanged or function() end

	self._locks = {}
	self._lockCounter = 0
	self._movementSuppressed = false
	self._isLocked = false

	return self
end

function GameplayLockController:IsLocked()
	return #self._locks > 0
end

function GameplayLockController:_apply()
	local shouldLock = self:IsLocked()

	if shouldLock and not self._movementSuppressed then
		self._contextActionService:BindActionAtPriority(
			self._movementActionName,
			function()
				return Enum.ContextActionResult.Sink
			end,
			false,
			Enum.ContextActionPriority.High.Value,
			table.unpack(self._suppressedInputs)
		)
		self._movementSuppressed = true
		local controller = self._getMobileController and self._getMobileController()
		if controller and controller.SetEnabled then
			controller:SetEnabled(false)
		end
	elseif not shouldLock and self._movementSuppressed then
		self._contextActionService:UnbindAction(self._movementActionName)
		self._movementSuppressed = false
		local controller = self._getMobileController and self._getMobileController()
		if controller and controller.SetEnabled then
			controller:SetEnabled(true)
		end
	end

	if shouldLock ~= self._isLocked then
		self._isLocked = shouldLock
		self._stateChangedCallback(shouldLock)
	end
end

function GameplayLockController:PushLock(source)
	self._lockCounter += 1
	local token = ("%s_lock_%d"):format(source or "lock", self._lockCounter)
	table.insert(self._locks, {
		token = token,
		source = source or "unknown",
	})
	self:_apply()
	return token
end

function GameplayLockController:PopLock(token)
	if not token then
		return
	end

	for index = #self._locks, 1, -1 do
		if self._locks[index].token == token then
			table.remove(self._locks, index)
			break
		end
	end

	self:_apply()
end

return GameplayLockController



