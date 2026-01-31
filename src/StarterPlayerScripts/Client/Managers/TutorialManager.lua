--[[
	TutorialManager.lua - Client-side Tutorial/Onboarding Manager

	Displays tutorial UI (tooltips, popups, highlights) and tracks local progress.
	Communicates with TutorialService for server-authoritative progress.

	NOTE: Tutorial only applies in player's own realm, not in the hub or other players' realms.
]]

local TutorialManager = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dependencies (injected during Initialize)
local EventManager = nil
local GameState = nil
local ToastManager = nil
local SoundManager = nil
local TutorialConfig = nil
local TutorialUI = nil
local InventoryManager = nil  -- For counting items across slots

-- State
local isInitialized = false
local tutorialData = nil
local currentStep = nil
local settings = nil
local localProgress = {} -- Track local progress for responsive UI
local isDisabled = false -- True when not in own realm (hub or friend's realm)
local isOwnRealm = false -- True when in player's own realm
local lastReportedCounts = {} -- Track last reported count per objective to avoid duplicate reports

-- Player reference
local player = Players.LocalPlayer

-- Tracking state for objectives
local moveStartPosition = nil
local totalMoveDistance = 0
local cameraStartRotation = nil
local totalCameraRotation = 0
local visitedCameraModes = {} -- Track which camera modes have been visited

--[[
	Initialize the TutorialManager
	@param deps: table - Dependencies {EventManager, GameState, ToastManager, SoundManager}
]]
function TutorialManager:Initialize(deps)
	if isInitialized then return end

	-- Store dependencies
	EventManager = deps.EventManager or require(ReplicatedStorage.Shared.EventManager)
	GameState = deps.GameState or require(script.Parent.GameState)
	ToastManager = deps.ToastManager
	SoundManager = deps.SoundManager
	InventoryManager = deps.InventoryManager

	-- Load config
	local success, result = pcall(function()
		TutorialConfig = require(ReplicatedStorage.Configs.TutorialConfig)
	end)
	if not success then
		warn("TutorialManager: Failed to load TutorialConfig:", result)
		return
	end
	settings = TutorialConfig.Settings

	-- Load TutorialUI
	local uiSuccess, uiResult = pcall(function()
		TutorialUI = require(script.Parent.Parent.UI.TutorialUI)
	end)
	if not uiSuccess then
		warn("TutorialManager: Failed to load TutorialUI:", uiResult)
	end

	-- Register event handlers
	self:_registerEventHandlers()

	-- Setup tracking hooks
	self:_setupTrackingHooks()

	-- Setup camera mode tracking
	self:_setupCameraModeTracking()

	isInitialized = true

	-- Request tutorial data from server
	task.delay(1, function()
		EventManager:SendToServer("RequestTutorialData")
	end)
end

--[[
	Register event handlers for server communication
]]
function TutorialManager:_registerEventHandlers()
	-- Tutorial data update (full sync)
	EventManager:RegisterEvent("TutorialDataUpdated", function(data)
		tutorialData = data.tutorial
		settings = data.config and data.config.settings or settings

		-- Check if tutorial is complete
		if tutorialData and tutorialData.completed then
			isDisabled = true
			currentStep = nil
			if TutorialUI then
				TutorialUI:HideAll()
			end
			return
		end

		-- Check if tutorial is disabled for current step on this server
		if tutorialData and tutorialData.disabled then
			isDisabled = true
			isOwnRealm = false
			currentStep = nil
			if TutorialUI then
				TutorialUI:HideAll()
			end
			return
		end

		-- Tutorial is active (either on own realm or hub with hub-specific step)
		isOwnRealm = data.isOwnRealm == true
		local isHub = data.isHub == true
		isDisabled = false -- Tutorial is active for current step

		if tutorialData and not tutorialData.completed then
			currentStep = data.config and data.config.currentStep
			self:_showCurrentStep()
		else
			if TutorialUI then
				TutorialUI:HideAll()
			end
		end
	end)

	-- Step completed
	EventManager:RegisterEvent("TutorialStepCompleted", function(data)
		self:_onStepCompleted(data)
	end)

	-- Step skipped
	EventManager:RegisterEvent("TutorialStepSkipped", function(data)
		self:_onStepSkipped(data)
	end)

	-- Tutorial skipped entirely
	EventManager:RegisterEvent("TutorialSkipped", function(data)
		tutorialData = data.tutorial
		currentStep = nil
		if TutorialUI then
			TutorialUI:HideAll()
		end
		if ToastManager then
			ToastManager:Info("Tutorial skipped. Good luck on your adventure!", 3)
		end
	end)

	-- Progress update
	EventManager:RegisterEvent("TutorialProgressUpdated", function(data)
		self:_onProgressUpdated(data)
	end)

	-- Error
	EventManager:RegisterEvent("TutorialError", function(data)
		if ToastManager then
			ToastManager:Error(data.message or "Tutorial error", 3)
		end
	end)
end

--[[
	Setup hooks to track player actions for objectives
]]
function TutorialManager:_setupTrackingHooks()
	-- Tab key to skip current step (if skippable)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Tab then
			if currentStep and currentStep.canSkip and not isDisabled then
				self:SkipCurrentStep()
			end
		end
	end)

	-- Track movement (non-blocking setup - character may not exist yet)
	local function setupMovementTracking(character)
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
		if humanoidRootPart then
			moveStartPosition = humanoidRootPart.Position
		end
	end
	
	-- Setup existing character if present
	if player.Character then
		setupMovementTracking(player.Character)
	end
	
	-- Handle respawn
	player.CharacterAdded:Connect(function(newCharacter)
		task.spawn(function()
			setupMovementTracking(newCharacter)
		end)
	end)
	
	-- Movement tracking heartbeat (safe if character doesn't exist yet)
	RunService.Heartbeat:Connect(function()
		-- Skip tracking if tutorial is disabled (not in own realm)
		if isDisabled or not currentStep or tutorialData and tutorialData.completed then
			return
		end

		local newChar = player.Character
		local newHRP = newChar and newChar:FindFirstChild("HumanoidRootPart")
		if newHRP then
			local currentPos = newHRP.Position
			local distance = (currentPos - (moveStartPosition or currentPos)).Magnitude
			if distance > 0.5 then -- Ignore tiny movements
				totalMoveDistance = totalMoveDistance + distance
				moveStartPosition = currentPos

				-- Check movement objective
				if currentStep and currentStep.objective and currentStep.objective.type == "move" then
					if totalMoveDistance >= (currentStep.objective.distance or 10) then
						self:_reportProgress("move", {distance = totalMoveDistance})
					end
				end
			end
		end
	end)

	-- Track camera rotation
	local camera = workspace.CurrentCamera
	if camera then
		cameraStartRotation = camera.CFrame.LookVector

		RunService.RenderStepped:Connect(function()
			-- Skip tracking if tutorial is disabled (not in own realm)
			if isDisabled or not currentStep or tutorialData and tutorialData.completed then
				return
			end

			local currentLook = camera.CFrame.LookVector
			if cameraStartRotation then
				local dot = currentLook:Dot(cameraStartRotation)
				dot = math.clamp(dot, -1, 1)
				local angleDiff = math.deg(math.acos(dot))

				if angleDiff > 5 then -- Ignore tiny rotations
					totalCameraRotation = totalCameraRotation + angleDiff
					cameraStartRotation = currentLook

					-- Check camera rotation objective
					if currentStep and currentStep.objective and currentStep.objective.type == "camera_rotate" then
						if totalCameraRotation >= (currentStep.objective.degrees or 180) then
							self:_reportProgress("camera_rotate", {degrees = totalCameraRotation})
						end
					end
				end
			end
		end)
	end

	-- Character respawn handling
	player.CharacterAdded:Connect(function(newCharacter)
		local newHRP = newCharacter:WaitForChild("HumanoidRootPart", 5)
		if newHRP then
			moveStartPosition = newHRP.Position
		end
	end)
end

--[[
	Setup camera mode tracking for camera_cycle objective
]]
function TutorialManager:_setupCameraModeTracking()
	-- Wait for CameraController to be available
	task.spawn(function()
		-- Give CameraController time to initialize
		task.wait(2)

		local success, CameraController = pcall(function()
			return require(script.Parent.Parent.Controllers.CameraController)
		end)

		if not success or not CameraController then
			warn("TutorialManager: Could not load CameraController for camera mode tracking")
			return
		end

		-- Listen to camera mode changes
		CameraController.StateChanged:Connect(function(newState, previousState)
			-- Skip if tutorial not active
			if isDisabled or not currentStep or (tutorialData and tutorialData.completed) then
				return
			end

			local objective = currentStep.objective
			if not objective or objective.type ~= "camera_cycle" then
				return
			end

			-- Track that this mode has been visited
			if not visitedCameraModes[newState] then
				visitedCameraModes[newState] = true

				-- Count how many unique modes have been visited
				local visitedCount = 0
				for _ in pairs(visitedCameraModes) do
					visitedCount = visitedCount + 1
				end

				-- Report progress
				self:_reportProgress("camera_cycle", {
					mode = newState,
					count = visitedCount,
				})
			end
		end)
	end)
end

--[[
	Report progress to server
	@param progressType: string - Type of progress
	@param progressData: table - Progress data
]]
function TutorialManager:_reportProgress(progressType, progressData)
	if isDisabled or not currentStep then
		return
	end

	EventManager:SendToServer("TutorialProgress", {
		stepId = currentStep.id,
		progressType = progressType,
		progressData = progressData,
	})
end

--[[
	Show the current tutorial step UI
]]
function TutorialManager:_showCurrentStep()
	if not currentStep then
		if TutorialUI then
			TutorialUI:HideAll()
		end
		return
	end

	-- Reset local progress trackers
	totalMoveDistance = 0
	totalCameraRotation = 0
	visitedCameraModes = {} -- Reset camera mode tracking
	-- Reset last reported counts when step changes
	lastReportedCounts = {}

	-- Track initial camera mode if this is a camera_cycle objective
	if currentStep.objective and currentStep.objective.type == "camera_cycle" then
		task.spawn(function()
			-- Wait a bit for CameraController to be ready
			task.wait(0.5)
			local success, CameraController = pcall(function()
				return require(script.Parent.Parent.Controllers.CameraController)
			end)

			if success and CameraController then
				local currentMode = CameraController:GetCurrentState()
				if currentMode then
					visitedCameraModes[currentMode] = true

					-- Count how many unique modes have been visited
					local visitedCount = 0
					for _ in pairs(visitedCameraModes) do
						visitedCount = visitedCount + 1
					end

					-- Report initial progress
					self:_reportProgress("camera_cycle", {
						mode = currentMode,
						count = visitedCount,
					})
				end
			end
		end)
	end

	-- Show appropriate UI based on step type
	if TutorialUI then
		if currentStep.uiType == "popup" then
			TutorialUI:ShowPopup(currentStep)
		elseif currentStep.uiType == "tooltip" then
			TutorialUI:ShowTooltip(currentStep)
		elseif currentStep.uiType == "objective" then
			TutorialUI:ShowObjective(currentStep)
		end

		-- Apply highlights if configured
		if currentStep.highlightBlockTypes then
			TutorialUI:HighlightBlockTypes(currentStep.highlightBlockTypes)
		end
		if currentStep.highlightKey then
			TutorialUI:HighlightKey(currentStep.highlightKey)
		end
		if currentStep.highlightUI then
			TutorialUI:HighlightUIElement(currentStep.highlightUI)
		end
	end

	-- Play notification sound
	if SoundManager and SoundManager.PlaySFX then
		SoundManager:PlaySFX("notification")
	end
end

--[[
	Handle step completed event
]]
function TutorialManager:_onStepCompleted(data)
	-- Hide current step UI
	if TutorialUI then
		TutorialUI:HideAll()
	end

	-- Show reward notification
	if data.reward then
		local rewardParts = {}
		if data.reward.coins then
			table.insert(rewardParts, "+" .. data.reward.coins .. " coins")
		end
		if data.reward.gems then
			table.insert(rewardParts, "+" .. data.reward.gems .. " gems")
		end
		if data.reward.experience then
			table.insert(rewardParts, "+" .. data.reward.experience .. " XP")
		end

		if ToastManager then
			local message = data.reward.message or "Step complete!"
			if #rewardParts > 0 then
				message = message .. " " .. table.concat(rewardParts, ", ")
			end
			ToastManager:Success(message, 3)
		end

		-- Play success sound
		if SoundManager and SoundManager.PlaySFX then
			SoundManager:PlaySFX("achievement")
		end
	end

	-- Show next step after delay
	if data.nextStep then
		currentStep = data.nextStep
		task.delay(settings and settings.tooltipDelay or 0.5, function()
			self:_showCurrentStep()
		end)
	elseif data.tutorialComplete then
		-- Tutorial complete!
		currentStep = nil
		if ToastManager then
			ToastManager:Achievement("Tutorial Complete!", "You've mastered the basics of Skyblox!")
		end
	end
end

--[[
	Handle step skipped event
]]
function TutorialManager:_onStepSkipped(data)
	if TutorialUI then
		TutorialUI:HideAll()
	end

	if ToastManager then
		ToastManager:Info("Step skipped", 2)
	end

	if data.nextStep then
		currentStep = data.nextStep
		task.delay(0.5, function()
			self:_showCurrentStep()
		end)
	elseif data.tutorialComplete then
		currentStep = nil
	end
end

--[[
	Handle progress update (for UI updates)
]]
function TutorialManager:_onProgressUpdated(data)
	if TutorialUI and currentStep then
		-- Extract progressData from the event data structure
		local progressData = data.progressData or data
		TutorialUI:UpdateProgress(currentStep, progressData)
	else
		if not TutorialUI then
			warn("[TutorialManager] _onProgressUpdated: TutorialUI not available")
		end
		if not currentStep then
			warn("[TutorialManager] _onProgressUpdated: currentStep is nil")
		end
	end
end

--[[
	Called when player collects an item
	@param itemId: number - The item ID collected
	@param count: number - Count in the changed slot
]]
function TutorialManager:OnItemCollected(itemId, count)
	-- Skip if tutorial not active
	if isDisabled or not currentStep or (tutorialData and tutorialData.completed) then
		return
	end

	local objective = currentStep.objective
	if not objective or objective.type ~= "collect_item" then
		return
	end

	-- Check if item matches objective
	local matches = false
	if objective.itemId and itemId == objective.itemId then
		matches = true
	elseif objective.anyOf then
		for _, targetId in ipairs(objective.anyOf) do
			if itemId == targetId then
				matches = true
				break
			end
		end
	end

	if not matches then
		return
	end

	-- Calculate total count of matching items across inventory
	local totalCount = count
	if objective.anyOf then
		totalCount = self:_getTotalMatchingItemCount(objective.anyOf)
	elseif objective.itemId then
		totalCount = self:_getTotalMatchingItemCount({objective.itemId})
	end

	-- Only report progress if the count has increased (avoid duplicate reports)
	local stepKey = currentStep.id
	local lastCount = lastReportedCounts[stepKey] or 0
	if totalCount <= lastCount then
		-- Count didn't increase, don't report
		return
	end

	-- Update last reported count
	lastReportedCounts[stepKey] = totalCount

	self:_reportProgress("collect_item", {
		itemId = itemId,
		count = totalCount,
	})
end

--[[
	Get total count of all matching items across inventory and hotbar
	@param itemIds: table - Array of item IDs to match
	@return number - Total count
]]
function TutorialManager:_getTotalMatchingItemCount(itemIds)
	local total = 0

	if not InventoryManager then
		return 0
	end

	-- Build a set for fast lookup
	local itemIdSet = {}
	for _, id in ipairs(itemIds) do
		itemIdSet[id] = true
	end

	-- Check inventory slots (27 slots)
	if InventoryManager.GetInventorySlot then
		for i = 1, 27 do
			local stack = InventoryManager:GetInventorySlot(i)
			if stack and not stack:IsEmpty() and itemIdSet[stack:GetItemId()] then
				total = total + stack:GetCount()
			end
		end
	end

	-- Check hotbar slots (9 slots)
	if InventoryManager.GetHotbarSlot then
		for i = 1, 9 do
			local stack = InventoryManager:GetHotbarSlot(i)
			if stack and not stack:IsEmpty() and itemIdSet[stack:GetItemId()] then
				total = total + stack:GetCount()
			end
		end
	end

	return total
end

--[[
	Called when player crafts an item
	@param itemId: number - The item ID crafted
	@param count: number - Total items crafted (default 1)
]]
function TutorialManager:OnItemCrafted(itemId, count)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("craft_item", {itemId = itemId, count = count or 1})
end

--[[
	Called when player places a block
	@param blockId: number - The block type placed
]]
function TutorialManager:OnBlockPlaced(blockId)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("place_block", {blockId = blockId})
end

--[[
	Called when player breaks a block
	@param blockType: number - The block type broken
]]
function TutorialManager:OnBlockBroken(blockType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("break_block", {blockType = blockType})
end

--[[
	Called when player opens a UI panel
	@param panelName: string - Name of the panel opened
]]
function TutorialManager:OnPanelOpened(panelName)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("ui_open", {panel = panelName})
end

--[[
	Called when player interacts with a block
	@param blockType: string - Type of block interacted with (e.g., "crafting_table")
]]
function TutorialManager:OnBlockInteracted(blockType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("interact_block", {blockType = blockType})
end

--[[
	Called when player equips an item
	@param itemId: number - The item ID equipped
]]
function TutorialManager:OnItemEquipped(itemId)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("equip_item", {itemId = itemId})
end

--[[
	Called when player interacts with an NPC
	@param npcType: string - The NPC type ("shop", "merchant", "warp", etc.)
]]
function TutorialManager:OnNPCInteracted(npcType)
	-- Skip if tutorial disabled (not in own realm)
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("npc_interact", {npcType = npcType})
end

--[[
	Called when player sells an item to merchant
	@param itemId: number - The item ID sold
	@param count: number - Amount sold
]]
function TutorialManager:OnItemSold(itemId, count)
	-- Skip if tutorial disabled
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("sell_item", {itemId = itemId, count = count or 1})
end

--[[
	Called when player buys an item from shop
	@param itemId: number - The item ID bought
	@param count: number - Amount bought
]]
function TutorialManager:OnItemBought(itemId, count)
	-- Skip if tutorial disabled
	if isDisabled or not currentStep or tutorialData and tutorialData.completed then
		return
	end

	self:_reportProgress("buy_item", {itemId = itemId, count = count or 1})
end

--[[
	Skip the current step (if allowed)
]]
function TutorialManager:SkipCurrentStep()
	-- Can't skip if disabled (not in own realm)
	if isDisabled or not currentStep then return end

	if currentStep.canSkip then
		EventManager:SendToServer("SkipTutorialStep")
	else
		if ToastManager then
			ToastManager:Warning("This step cannot be skipped", 2)
		end
	end
end

--[[
	Skip the entire tutorial
]]
function TutorialManager:SkipTutorial()
	-- Can't skip if disabled (not in own realm)
	if isDisabled then return end

	EventManager:SendToServer("SkipTutorial")
end

--[[
	Check if tutorial is completed
]]
function TutorialManager:IsCompleted()
	return tutorialData and tutorialData.completed
end

--[[
	Check if tutorial is active
]]
function TutorialManager:IsActive()
	return not isDisabled and tutorialData and not tutorialData.completed and currentStep ~= nil
end

--[[
	Check if tutorial is disabled (not in own realm)
]]
function TutorialManager:IsDisabled()
	return isDisabled
end

--[[
	Check if currently in own realm
]]
function TutorialManager:IsInOwnRealm()
	return isOwnRealm
end

--[[
	Get current step info
]]
function TutorialManager:GetCurrentStep()
	return currentStep
end

--[[
	Cleanup
]]
function TutorialManager:Cleanup()
	if TutorialUI then
		TutorialUI:HideAll()
	end
	isInitialized = false
	tutorialData = nil
	currentStep = nil
	isDisabled = false
	isOwnRealm = false
end

return TutorialManager

