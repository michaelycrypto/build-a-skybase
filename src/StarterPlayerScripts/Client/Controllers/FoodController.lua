--[[
	FoodController.lua
	Client-side controller for food consumption input handling.
	Manages eating state, coordinates with server, and handles cancellation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local _UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local FoodConfig = require(ReplicatedStorage.Shared.FoodConfig)

local player = Players.LocalPlayer
local FoodController = {}

-- Eating state
local EatingState = {
	IDLE = "idle",
	EATING = "eating",
	COOLDOWN = "cooldown"
}

local currentState = EatingState.IDLE
local eatingData = nil -- {foodId, startTime, duration}
local _cooldownEndTime = 0

-- Connections
local connections = {}

--[[
	Initialize the food controller
--]]
function FoodController:Init()
	-- Connect to server events
	EventManager:ConnectToServer("EatingStarted", function(data)
		self:_onEatingStarted(data)
	end)

	EventManager:ConnectToServer("EatingCompleted", function(data)
		self:_onEatingCompleted(data)
	end)

	EventManager:ConnectToServer("EatingCancelled", function(data)
		self:_onEatingCancelled(data)
	end)

	-- Track player movement for cancellation
	self:_setupMovementTracking()

	self._initialized = true
end

--[[
	Setup movement tracking to cancel eating on movement
--]]
function FoodController:_setupMovementTracking()
	local lastPosition = nil
	local lastUpdate = 0

	connections.movement = RunService.Heartbeat:Connect(function()
		if currentState ~= EatingState.EATING then
			return
		end

		local character = player.Character
		if not character then
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end

		local now = os.clock()
		if (now - lastUpdate) < 0.1 then
			return -- Rate limit
		end
		lastUpdate = now

		local currentPosition = rootPart.Position

		if lastPosition then
			local distance = (currentPosition - lastPosition).Magnitude
			if distance > 0.1 then -- Player moved
				self:CancelEating()
			end
		end

		lastPosition = currentPosition
	end)
end

--[[
	Start eating a food item
	@param foodId: number - Item ID of food
	@param slotIndex: number? - Optional hotbar slot index
--]]
function FoodController:StartEating(foodId, slotIndex)
	if not FoodConfig.IsFood(foodId) then
		warn("[FoodController] Not a food item:", foodId)
		return false
	end

	if currentState ~= EatingState.IDLE then
		return false -- Already eating or on cooldown
	end

	-- Request start from server
	EventManager:SendToServer("RequestStartEating", {
		foodId = foodId,
		slotIndex = slotIndex
	})

	return true
end

--[[
	Cancel eating
--]]
function FoodController:CancelEating()
	if currentState ~= EatingState.EATING then
		return
	end

	-- Request cancel from server
	EventManager:SendToServer("RequestCancelEating", {})

	-- Reset state immediately
	currentState = EatingState.IDLE
	eatingData = nil
end

--[[
	Handle eating started from server
--]]
function FoodController:_onEatingStarted(data)
	if data.error then
		warn("[FoodController] Eating failed:", data.error)
		return
	end

	if not data.foodId or not data.duration then
		warn("[FoodController] Invalid eating started data")
		return
	end

	currentState = EatingState.EATING
	eatingData = {
		foodId = data.foodId,
		startTime = os.clock(),
		duration = data.duration
	}

	-- Start eating animation (will be handled by EatingAnimation)
	-- For now, we'll just track the timer
	self:_startEatingTimer()
end

--[[
	Start eating timer - completes eating after duration
--]]
function FoodController:_startEatingTimer()
	if not eatingData then
		return
	end

	-- Wait for eating duration
	task.spawn(function()
		task.wait(eatingData.duration)

		-- Check if still eating (might have been cancelled)
		if currentState == EatingState.EATING and eatingData then
			-- Request completion from server
			EventManager:SendToServer("RequestCompleteEating", {
				foodId = eatingData.foodId
			})
		end
	end)
end

--[[
	Handle eating completed from server
--]]
function FoodController:_onEatingCompleted(data)
	if data.error then
		warn("[FoodController] Eating completion failed:", data.error)
		currentState = EatingState.IDLE
		eatingData = nil
		return
	end

	-- Set cooldown
	currentState = EatingState.COOLDOWN
	_cooldownEndTime = os.clock() + FoodConfig.Eating.cooldown
	eatingData = nil

	-- Clear cooldown after duration
	task.spawn(function()
		task.wait(FoodConfig.Eating.cooldown)
		if currentState == EatingState.COOLDOWN then
			currentState = EatingState.IDLE
		end
	end)
end

--[[
	Handle eating cancelled from server
--]]
function FoodController:_onEatingCancelled(_data)
	currentState = EatingState.IDLE
	eatingData = nil
end

--[[
	Check if player can eat (not eating, not on cooldown)
--]]
function FoodController:CanEat()
	return currentState == EatingState.IDLE
end

--[[
	Check if player is currently eating
--]]
function FoodController:IsEating()
	return currentState == EatingState.EATING
end

--[[
	Get current eating state
--]]
function FoodController:GetState()
	return currentState
end

--[[
	Get eating progress (0-1)
--]]
function FoodController:GetEatingProgress()
	if not eatingData then
		return 0
	end

	local elapsed = os.clock() - eatingData.startTime
	return math.clamp(elapsed / eatingData.duration, 0, 1)
end

--[[
	Cleanup
--]]
function FoodController:Destroy()
	for _, connection in pairs(connections) do
		if connection then
			connection:Disconnect()
		end
	end
	connections = {}
end

-- Auto-initialize
FoodController:Init()

return FoodController
