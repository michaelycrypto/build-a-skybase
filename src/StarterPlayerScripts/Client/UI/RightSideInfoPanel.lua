--[[
	RightSideInfoPanel.lua
	Two-region HUD info panel:
	  1. World ownership — top-right
	  2. Tutorial objectives — center-right panel
	PRD: docs/PRDs/PRD_RIGHT_SIDE_INFO_PANEL.md
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EventManager = require(ReplicatedStorage.Shared.EventManager)
local Config = require(ReplicatedStorage.Shared.Config)
local TutorialConfig = require(ReplicatedStorage.Configs.TutorialConfig)
local GameState = require(script.Parent.Parent.Managers.GameState)
local UIVisibilityManager = require(script.Parent.Parent.Managers.UIVisibilityManager)
local IconManager = require(script.Parent.Parent.Managers.IconManager)

local RightSideInfoPanel = {}
local BOLD_FONT = Config.UI_SETTINGS.typography.fonts.bold

-- Design tokens
local DESIGN = Config.UI_SETTINGS.designSystem

-- ═══════════════════════════════════════════════════════════════════
-- Layout constants
-- ═══════════════════════════════════════════════════════════════════

-- World ownership label (top-right, styled like panel rows)
local WORLD_STYLE = {
	RIGHT_OFFSET = 8,
	TOP = 8,
	WIDTH = 270,          -- Same width as tutorial panel
	HEIGHT = 44,          -- Same height as panel rows
	TEXT_SIZE = 20,       -- Match panel text size
	ICON_SIZE = 28,       -- Match panel icon size
}

-- Right-side tutorial panel (unchanged)
local PANEL_STYLE = {
	WIDTH = 270,
	ROW_GAP = 5,
	ROW_HEIGHT = 44,
	ROW_CORNER = DESIGN.borderRadius.sm,
	ROW_PADDING_H = 16,
	ROW_PADDING_V = 8,
	OFFSET_TOP = 8,
	OFFSET_RIGHT = 8,
	TEXT_SIZE = 20,
	ICON_SIZE = 28,
	ROW_COLOR = Color3.fromRGB(28, 32, 42),
	ROW_COLOR_ACCENT = Color3.fromRGB(38, 42, 58),
	ROW_EDGE_COLOR = Color3.fromRGB(22, 28, 48),
	OBJ_ROW_HEIGHT = 38,
	OBJ_TEXT_COLOR = Color3.fromRGB(255, 255, 255),
	OBJ_DONE_COLOR = Color3.fromRGB(80, 200, 120),
	TEXT_STROKE_COLOR = Color3.fromRGB(0, 0, 0),
	TEXT_STROKE_THICKNESS = 1.2,
	TEXT_STROKE_TRANSPARENCY = 0.2,
}

local TUTORIAL_TITLE = "Your Starter Island"

-- ═══════════════════════════════════════════════════════════════════
-- State
-- ═══════════════════════════════════════════════════════════════════

-- ScreenGuis
local worldGui
local tutorialGui

-- UI references
local worldLabel
local tutorialPanelFrame
local tutorialContainer
local tutorialTitleRow
local tutorialTitleLabel
local objectiveRows = {}
local dynamicRows = {}
local tutorialManager
local activeStepId = nil
local liveProgressCount = 0
local worldData = nil

local initialized = false

-- ═══════════════════════════════════════════════════════════════════
-- Helpers
-- ═══════════════════════════════════════════════════════════════════

local function addTextStroke(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = PANEL_STYLE.TEXT_STROKE_COLOR
	stroke.Thickness = thickness or PANEL_STYLE.TEXT_STROKE_THICKNESS
	stroke.Transparency = PANEL_STYLE.TEXT_STROKE_TRANSPARENCY
	stroke.Parent = label
	return stroke
end

-- ═══════════════════════════════════════════════════════════════════
-- Region 1: World ownership label (top-right)
-- ═══════════════════════════════════════════════════════════════════

function RightSideInfoPanel:CreateWorldUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	worldGui = Instance.new("ScreenGui")
	worldGui.Name = "WorldOwnerLabel"
	worldGui.ResetOnSpawn = false
	worldGui.DisplayOrder = 99
	worldGui.IgnoreGuiInset = true
	worldGui.Parent = playerGui

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = worldGui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Styled row (same as tutorial panel rows) anchored top-right
	local row = Instance.new("Frame")
	row.Name = "WorldRow"
	row.AnchorPoint = Vector2.new(1, 0)
	row.Position = UDim2.new(1, -WORLD_STYLE.RIGHT_OFFSET, 0, WORLD_STYLE.TOP)
	row.Size = UDim2.fromOffset(WORLD_STYLE.WIDTH, WORLD_STYLE.HEIGHT)
	row.BackgroundColor3 = PANEL_STYLE.ROW_COLOR
	row.BackgroundTransparency = 0
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Parent = worldGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, PANEL_STYLE.ROW_CORNER)
	corner.Parent = row

	-- Radial gradient (same as panel rows)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, PANEL_STYLE.ROW_EDGE_COLOR),
		ColorSequenceKeypoint.new(0.3, PANEL_STYLE.ROW_COLOR),
		ColorSequenceKeypoint.new(0.7, PANEL_STYLE.ROW_COLOR),
		ColorSequenceKeypoint.new(1, PANEL_STYLE.ROW_EDGE_COLOR),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(0.35, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.02),
		NumberSequenceKeypoint.new(0.65, 0.08),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	gradient.Rotation = 0
	gradient.Parent = row

	local rowPadding = Instance.new("UIPadding")
	rowPadding.PaddingLeft = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	rowPadding.PaddingRight = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	rowPadding.PaddingTop = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	rowPadding.PaddingBottom = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	rowPadding.Parent = row

	-- Content: icon + label, horizontal
	local content = Instance.new("Frame")
	content.Name = "WorldContent"
	content.Size = UDim2.new(1, 0, 1, 0)
	content.BackgroundTransparency = 1
	content.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = content

	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "WorldIcon"
	iconContainer.Size = UDim2.fromOffset(WORLD_STYLE.ICON_SIZE, WORLD_STYLE.ICON_SIZE)
	iconContainer.BackgroundTransparency = 1
	iconContainer.LayoutOrder = 1
	iconContainer.Parent = content
	IconManager:CreateIcon(iconContainer, "General", "Home", {
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})

	worldLabel = Instance.new("TextLabel")
	worldLabel.Name = "WorldLabel"
	worldLabel.Size = UDim2.new(1, -WORLD_STYLE.ICON_SIZE - 6, 1, 0)
	worldLabel.BackgroundTransparency = 1
	worldLabel.Text = "\u{2014}"
	worldLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	worldLabel.TextSize = WORLD_STYLE.TEXT_SIZE
	worldLabel.Font = BOLD_FONT
	worldLabel.TextXAlignment = Enum.TextXAlignment.Left
	worldLabel.TextYAlignment = Enum.TextYAlignment.Center
	worldLabel.TextTruncate = Enum.TextTruncate.AtEnd
	worldLabel.LayoutOrder = 2
	worldLabel.Parent = content
	addTextStroke(worldLabel)
end

-- ═══════════════════════════════════════════════════════════════════
-- Region 2: Tutorial panel (center-right)
-- ═══════════════════════════════════════════════════════════════════

local function createListRow(name, layoutOrder, accentColor)
	local row = Instance.new("Frame")
	row.Name = name
	row.Size = UDim2.new(1, 0, 0, PANEL_STYLE.ROW_HEIGHT)
	row.BackgroundColor3 = accentColor or PANEL_STYLE.ROW_COLOR
	row.BackgroundTransparency = 0
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder
	row.ClipsDescendants = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, PANEL_STYLE.ROW_CORNER)
	corner.Parent = row

	local coreColor = accentColor or PANEL_STYLE.ROW_COLOR
	local edgeColor = PANEL_STYLE.ROW_EDGE_COLOR
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, edgeColor),
		ColorSequenceKeypoint.new(0.3, coreColor),
		ColorSequenceKeypoint.new(0.7, coreColor),
		ColorSequenceKeypoint.new(1, edgeColor),
	})
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(0.35, 0.08),
		NumberSequenceKeypoint.new(0.5, 0.02),
		NumberSequenceKeypoint.new(0.65, 0.08),
		NumberSequenceKeypoint.new(0.85, 0.2),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	gradient.Rotation = 0
	gradient.Parent = row

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	padding.PaddingRight = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	padding.PaddingTop = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	padding.PaddingBottom = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	padding.Parent = row

	return row
end

local function createObjectiveRow(parent, layoutOrder)
	local row = Instance.new("Frame")
	row.Name = "ObjRow_" .. layoutOrder
	row.Size = UDim2.new(1, 0, 0, PANEL_STYLE.OBJ_ROW_HEIGHT)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.LayoutOrder = layoutOrder

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	padding.PaddingRight = UDim.new(0, PANEL_STYLE.ROW_PADDING_H)
	padding.PaddingTop = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	padding.PaddingBottom = UDim.new(0, PANEL_STYLE.ROW_PADDING_V)
	padding.Parent = row

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "ObjName"
	nameLabel.Size = UDim2.new(1, -44, 1, 0)
	nameLabel.Position = UDim2.fromScale(0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = ""
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextSize = PANEL_STYLE.TEXT_SIZE
	nameLabel.Font = BOLD_FONT
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextYAlignment = Enum.TextYAlignment.Center
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = row
	addTextStroke(nameLabel)

	local progressLabel = Instance.new("TextLabel")
	progressLabel.Name = "ObjProgress"
	progressLabel.Size = UDim2.new(0, 40, 1, 0)
	progressLabel.Position = UDim2.new(1, -40, 0, 0)
	progressLabel.BackgroundTransparency = 1
	progressLabel.Text = ""
	progressLabel.TextColor3 = PANEL_STYLE.OBJ_TEXT_COLOR
	progressLabel.TextSize = PANEL_STYLE.TEXT_SIZE
	progressLabel.Font = BOLD_FONT
	progressLabel.TextXAlignment = Enum.TextXAlignment.Right
	progressLabel.TextYAlignment = Enum.TextYAlignment.Center
	progressLabel.Parent = row
	addTextStroke(progressLabel)

	local checkSize = PANEL_STYLE.ICON_SIZE - 4
	local checkContainer = Instance.new("Frame")
	checkContainer.Name = "CheckContainer"
	checkContainer.Size = UDim2.new(0, checkSize, 0, checkSize)
	checkContainer.Position = UDim2.new(1, -checkSize, 0.5, -checkSize / 2)
	checkContainer.BackgroundTransparency = 1
	checkContainer.Visible = false
	checkContainer.Parent = row
	IconManager:CreateIcon(checkContainer, "UI", "CheckMark", {
		size = UDim2.fromScale(1, 1),
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
		color = PANEL_STYLE.OBJ_DONE_COLOR,
	})

	row.Parent = parent

	return {
		frame = row,
		nameLabel = nameLabel,
		progressLabel = progressLabel,
		checkContainer = checkContainer,
	}
end

local function clearDynamicRows()
	for _, obj in ipairs(dynamicRows) do
		if obj.frame then obj.frame:Destroy() end
	end
	dynamicRows = {}
	objectiveRows = {}
end

local function buildObjectiveRows(step)
	clearDynamicRows()
	if not step or not step.objective or not tutorialContainer then return end

	local objective = step.objective
	local stepLabel = step.title or step.id or "Step"

	if objective.type == "multi_objective" and objective.objectives then
		local titleRow = createObjectiveRow(tutorialContainer, 99)
		titleRow.nameLabel.Text = stepLabel
		titleRow.progressLabel.Text = ""
		table.insert(dynamicRows, titleRow)

		for i, subObj in ipairs(objective.objectives) do
			local row = createObjectiveRow(tutorialContainer, 100 + i)
			row.nameLabel.Text = subObj.name or ("Objective " .. i)
			local target = subObj.count or 1
			row.progressLabel.Text = "0/" .. target
			table.insert(dynamicRows, row)
			table.insert(objectiveRows, row)
		end
	else
		local row = createObjectiveRow(tutorialContainer, 101)
		row.nameLabel.Text = stepLabel
		local target = objective.count or 1
		row.progressLabel.Text = "0/" .. target
		table.insert(dynamicRows, row)
		table.insert(objectiveRows, row)
	end
end

local function updateObjectiveProgress(step)
	if not step or not step.objective or #objectiveRows == 0 then return end

	local tData = tutorialManager and tutorialManager.GetTutorialData and tutorialManager:GetTutorialData()
	local objective = step.objective

	local function applyRowProgress(row, current, target)
		local done = current >= target
		if done then
			row.progressLabel.Visible = false
			if row.checkContainer then row.checkContainer.Visible = true end
			row.nameLabel.TextColor3 = PANEL_STYLE.OBJ_DONE_COLOR
		else
			row.progressLabel.Visible = true
			row.progressLabel.Text = current .. "/" .. target
			row.progressLabel.TextColor3 = PANEL_STYLE.OBJ_TEXT_COLOR
			if row.checkContainer then row.checkContainer.Visible = false end
			row.nameLabel.TextColor3 = PANEL_STYLE.OBJ_TEXT_COLOR
		end
	end

	if objective.type == "multi_objective" and objective.objectives then
		local multiProgress = tutorialManager and tutorialManager.GetMultiObjectiveProgress
			and tutorialManager:GetMultiObjectiveProgress() or {}
		if not next(multiProgress) and tData and tData.multiObjectiveProgress then
			multiProgress = tData.multiObjectiveProgress
		end
		for i, subObj in ipairs(objective.objectives) do
			local row = objectiveRows[i]
			if row then
				local current = multiProgress["obj_" .. i] or 0
				local target = subObj.count or 1
				applyRowProgress(row, current, target)
			end
		end
	else
		local row = objectiveRows[1]
		if row then
			local target = objective.count or 1
			local current = liveProgressCount
			if current == 0 and tData then
				if objective.type == "collect_item" then
					current = tData.collectProgressCount or 0
				elseif objective.type == "craft_item" then
					current = tData.craftProgressCount or 0
				elseif objective.type == "place_block" then
					current = tData.placeProgressCount or 0
				elseif objective.type == "break_block" then
					current = tData.breakProgressCount or 0
				else
					current = tData.progressCount or 0
				end
			end
			current = math.min(current, target)
			applyRowProgress(row, current, target)
		end
	end
end

local function resolveStep(stepId)
	if not stepId then return nil end
	return TutorialConfig.GetStep(stepId)
end

local function showTutorialStep(stepId)
	if not tutorialContainer or not tutorialTitleRow or not tutorialTitleLabel then return end

	activeStepId = stepId
	local step = resolveStep(stepId)

	if not step then
		tutorialContainer.Visible = false
		clearDynamicRows()
		return
	end

	tutorialContainer.Visible = true
	liveProgressCount = 0
	tutorialTitleLabel.Text = TUTORIAL_TITLE
	buildObjectiveRows(step)
	updateObjectiveProgress(step)
end

local function updateTutorialProgress()
	local step = resolveStep(activeStepId)
	if step then
		updateObjectiveProgress(step)
	end
end

function RightSideInfoPanel:CreateTutorialUI()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	tutorialGui = Instance.new("ScreenGui")
	tutorialGui.Name = "RightSideInfoPanel"
	tutorialGui.ResetOnSpawn = false
	tutorialGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	tutorialGui.IgnoreGuiInset = true
	tutorialGui.Parent = playerGui

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "ResponsiveScale"
	uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	uiScale.Parent = tutorialGui
	CollectionService:AddTag(uiScale, "scale_component")

	-- Center-right container (tutorial only)
	tutorialPanelFrame = Instance.new("Frame")
	tutorialPanelFrame.Name = "Panel"
	tutorialPanelFrame.AnchorPoint = Vector2.new(1, 0.5)
	tutorialPanelFrame.Position = UDim2.new(1, -PANEL_STYLE.OFFSET_RIGHT, 0.5, 0)
	tutorialPanelFrame.Size = UDim2.fromOffset(PANEL_STYLE.WIDTH, 0)
	tutorialPanelFrame.AutomaticSize = Enum.AutomaticSize.Y
	tutorialPanelFrame.BackgroundTransparency = 1
	tutorialPanelFrame.BorderSizePixel = 0
	tutorialPanelFrame.Parent = tutorialGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, PANEL_STYLE.ROW_GAP)
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.Parent = tutorialPanelFrame

	-- Tutorial section
	tutorialContainer = Instance.new("Frame")
	tutorialContainer.Name = "TutorialSection"
	tutorialContainer.Size = UDim2.new(1, 0, 0, 0)
	tutorialContainer.AutomaticSize = Enum.AutomaticSize.Y
	tutorialContainer.BackgroundTransparency = 1
	tutorialContainer.BorderSizePixel = 0
	tutorialContainer.LayoutOrder = 1
	tutorialContainer.Visible = false
	tutorialContainer.Parent = tutorialPanelFrame

	local tutorialListLayout = Instance.new("UIListLayout")
	tutorialListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tutorialListLayout.Padding = UDim.new(0, 2)
	tutorialListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	tutorialListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	tutorialListLayout.Parent = tutorialContainer

	tutorialTitleRow = createListRow("TutorialTitleRow", 1, PANEL_STYLE.ROW_COLOR_ACCENT)
	tutorialTitleRow.Parent = tutorialContainer
	local titleContent = Instance.new("Frame")
	titleContent.Size = UDim2.new(1, 0, 1, 0)
	titleContent.BackgroundTransparency = 1
	titleContent.Parent = tutorialTitleRow
	local titleLayout = Instance.new("UIListLayout")
	titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
	titleLayout.Padding = UDim.new(0, 6)
	titleLayout.FillDirection = Enum.FillDirection.Horizontal
	titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	titleLayout.Parent = titleContent
	IconManager:CreateIcon(titleContent, "Items", "Scroll", { size = UDim2.fromOffset(PANEL_STYLE.ICON_SIZE, PANEL_STYLE.ICON_SIZE) })
	tutorialTitleLabel = Instance.new("TextLabel")
	tutorialTitleLabel.Name = "TutorialTitleLabel"
	tutorialTitleLabel.Size = UDim2.new(1, -PANEL_STYLE.ICON_SIZE - 6, 1, 0)
	tutorialTitleLabel.BackgroundTransparency = 1
	tutorialTitleLabel.Text = ""
	tutorialTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	tutorialTitleLabel.TextSize = PANEL_STYLE.TEXT_SIZE
	tutorialTitleLabel.Font = BOLD_FONT
	tutorialTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	tutorialTitleLabel.TextYAlignment = Enum.TextYAlignment.Center
	tutorialTitleLabel.TextTruncate = Enum.TextTruncate.AtEnd
	tutorialTitleLabel.LayoutOrder = 2
	tutorialTitleLabel.Parent = titleContent
	addTextStroke(tutorialTitleLabel)
end

-- ═══════════════════════════════════════════════════════════════════
-- World display logic
-- ═══════════════════════════════════════════════════════════════════

function RightSideInfoPanel:UpdateWorldDisplay()
	if not worldLabel then return end

	local Workspace = game:GetService("Workspace")
	local isHub = Workspace:GetAttribute("IsHubWorld") == true
	if isHub then
		worldLabel.Text = "Skyblox Hub"
		worldLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
		return
	end

	if not worldData then
		worldLabel.Text = "\u{2014}"
		worldLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		return
	end
	local ownerName = worldData.ownerName or "Unknown"
	local worldName = worldData.worldName or "Realm"
	local displayText = worldName .. " [" .. ownerName .. "]"
	local localPlayer = Players.LocalPlayer
	if localPlayer.UserId == worldData.ownerId then
		worldLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
		worldLabel.Text = "Your Island"
	else
		worldLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		worldLabel.Text = displayText
	end
end

-- ═══════════════════════════════════════════════════════════════════
-- Initialize
-- ═══════════════════════════════════════════════════════════════════

function RightSideInfoPanel:Initialize(managers)
	tutorialManager = managers and managers.TutorialManager

	-- Create both regions
	self:CreateWorldUI()
	self:CreateTutorialUI()

	-- Seed world display
	if not worldData then
		local worldState = GameState:Get("game.worldState")
		if worldState and worldState.ownerUserId then
			worldData = {
				ownerId = worldState.ownerUserId,
				ownerName = worldState.ownerName or "Unknown",
				worldName = (worldState.ownerName or "Unknown") .. "'s World",
			}
		end
	end
	self:UpdateWorldDisplay()

	-- Initial tutorial state
	local currentStep = tutorialManager and tutorialManager.GetCurrentStep and tutorialManager:GetCurrentStep()
	if currentStep and currentStep.id then
		local isActive = tutorialManager.IsActive and tutorialManager:IsActive()
		if isActive then
			showTutorialStep(currentStep.id)
		end
	end

	initialized = true

	-- World ownership
	EventManager:RegisterEvent("WorldOwnershipInfo", function(data)
		worldData = data
		self:UpdateWorldDisplay()
	end)
	EventManager:RegisterEvent("WorldStateChanged", function(data)
		if not data then return end
		if not worldData and data.ownerUserId then
			worldData = {
				ownerId = data.ownerUserId,
				ownerName = data.ownerName or "Unknown",
				worldName = (data.ownerName or "Unknown") .. "'s World",
			}
			self:UpdateWorldDisplay()
		end
	end)
	local Workspace = game:GetService("Workspace")
	Workspace:GetAttributeChangedSignal("IsHubWorld"):Connect(function()
		self:UpdateWorldDisplay()
	end)

	-- Tutorial events
	EventManager:RegisterEvent("TutorialStepCompleted", function(data)
		if data and data.nextStep and data.nextStep.id then
			showTutorialStep(data.nextStep.id)
		elseif data and data.tutorialComplete then
			showTutorialStep(nil)
		else
			local step = tutorialManager and tutorialManager:GetCurrentStep()
			showTutorialStep(step and step.id or nil)
		end
	end)
	EventManager:RegisterEvent("TutorialStepSkipped", function(data)
		if data and data.nextStep and data.nextStep.id then
			showTutorialStep(data.nextStep.id)
		elseif data and data.tutorialComplete then
			showTutorialStep(nil)
		else
			local step = tutorialManager and tutorialManager:GetCurrentStep()
			showTutorialStep(step and step.id or nil)
		end
	end)
	EventManager:RegisterEvent("TutorialSkipped", function()
		showTutorialStep(nil)
	end)
	EventManager:RegisterEvent("TutorialProgressUpdated", function(data)
		local progressData = data and (data.progressData or data)
		if progressData and progressData.count then
			liveProgressCount = progressData.count
		end
		updateTutorialProgress()
	end)
	EventManager:RegisterEvent("TutorialDataUpdated", function()
		liveProgressCount = 0
		local isActive = tutorialManager and tutorialManager.IsActive and tutorialManager:IsActive()
		if isActive then
			local step = tutorialManager:GetCurrentStep()
			showTutorialStep(step and step.id or nil)
		else
			showTutorialStep(nil)
		end
	end)

	UIVisibilityManager:RegisterComponent("rightSideInfoPanel", self, {
		showMethod = "Show",
		hideMethod = "Hide",
	})
end

-- ═══════════════════════════════════════════════════════════════════
-- Visibility
-- ═══════════════════════════════════════════════════════════════════

function RightSideInfoPanel:Show()
	if worldGui then worldGui.Enabled = true end
	if tutorialGui then tutorialGui.Enabled = true end
end

function RightSideInfoPanel:Hide()
	if worldGui then worldGui.Enabled = false end
	if tutorialGui then tutorialGui.Enabled = false end
end

function RightSideInfoPanel:IsOpen()
	return tutorialGui ~= nil and tutorialGui.Enabled
end

-- ═══════════════════════════════════════════════════════════════════
-- Cleanup
-- ═══════════════════════════════════════════════════════════════════

function RightSideInfoPanel:Cleanup()
	clearDynamicRows()
	if worldGui then worldGui:Destroy(); worldGui = nil end
	if tutorialGui then tutorialGui:Destroy(); tutorialGui = nil end
	tutorialPanelFrame = nil
	worldLabel = nil
	tutorialContainer = nil
	tutorialTitleRow = nil
	tutorialTitleLabel = nil
	activeStepId = nil
	liveProgressCount = 0
	initialized = false
end

return RightSideInfoPanel
