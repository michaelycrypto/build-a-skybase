--[[
	QuestsPanel.lua - Client UI for Quests

	Displays per-mob milestones, progress, and claim buttons.
--]]

local QuestsPanel = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Imports
local Config = require(ReplicatedStorage.Shared.Config)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local QuestsApi = require(ReplicatedStorage.Shared.Api.QuestsApi)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)
local IconManager = require(script.Parent.Parent.Managers.IconManager)
local QuestConfigFallback = require(ReplicatedStorage.Configs.QuestConfig)

-- State
local questConfig = nil
local playerQuests = nil -- {mobs = { [mobType] = {kills, claimed={milestone=true}} }}
local activeTab = "all" -- "all", "claimable", "claimed"

-- Ensure we only register network event listeners once per session
local eventsRegistered = false
-- Ensure the auto-switch from Completed -> All happens only once per empty state
local didAutoSwitchAfterEmpty = false
-- Controls one-time default tab switch after opening the panel
local pendingDefaultTabCheck = false

-- UI Refs
local refs = {
	contentFrame = nil,
	tabBar = nil,
	listContainer = nil,
}

local function clearChildren(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
end

-- Removed old createMobRow function - now using UIComponents:CreateQuestRow

local function getQuestCards()
	if not questConfig or not questConfig.Mobs then
		questConfig = QuestConfigFallback
	end

	local cards = {}
	for mobType, mobConfig in pairs(questConfig.Mobs) do
		local mobData = (playerQuests and playerQuests.mobs and playerQuests.mobs[mobType]) or {kills = 0, claimed = {}}

		-- Sort milestones by kills required (ascending)
		local sortedMilestones = {}
		for _, milestone in ipairs(mobConfig.milestones) do
			table.insert(sortedMilestones, milestone)
		end
		table.sort(sortedMilestones, function(a, b) return a < b end)

		-- Find the next unclaimed milestone (current active quest)
		local nextMilestone = nil
		print("QuestsPanel: Checking milestones for", mobType)
		print("QuestsPanel: Full mobData:", mobData)
		print("QuestsPanel: Claimed status:", mobData.claimed)
		for _, milestone in ipairs(sortedMilestones) do
			-- Server normalizes milestone keys to strings before transmission
			local isClaimed = mobData.claimed and mobData.claimed[tostring(milestone)]
			print("QuestsPanel: Milestone", milestone, "claimed:", isClaimed)
			if not isClaimed then
				nextMilestone = milestone
				print("QuestsPanel: Next milestone for", mobType, "is", nextMilestone, "kills")
				break
			end
		end
		if not nextMilestone then
			print("QuestsPanel: No more milestones available for", mobType)
		end

		-- Only create a card if there's a next milestone to work on
		if nextMilestone then
			local isClaimable = (mobData.kills or 0) >= nextMilestone
			local isClaimed = false -- Current active quest is never claimed

			table.insert(cards, {
				mobType = mobType,
				mobConfig = mobConfig,
				mobData = mobData,
				milestone = nextMilestone,
				isClaimable = isClaimable,
				isClaimed = isClaimed
			})
		end
	end

	return cards
end

local function filterCards(cards, filter)
	if filter == "all" then
		return cards
	end

	local filtered = {}
	for _, card in ipairs(cards) do
		if filter == "claimable" and card.isClaimable then
			table.insert(filtered, card)
		end
	end
	return filtered
end

local function updateTabBadges()
	if not refs.tabBar then return end

	local cards = getQuestCards()
	local claimableCount = 0

	for _, card in ipairs(cards) do
		if card.isClaimable then
			claimableCount += 1
		end
	end

	refs.tabBar:UpdateBadge("claimable", claimableCount)

	-- Reset one-time switch guard when claimables appear again
	if claimableCount > 0 then
		didAutoSwitchAfterEmpty = false
	end

	-- If user is on Completed tab and there are no claimables left, switch back to All ONCE
	local switched = false
	if activeTab == "claimable" and claimableCount == 0 and not didAutoSwitchAfterEmpty then
		didAutoSwitchAfterEmpty = true
		activeTab = "all"
		if refs.tabBar and refs.tabBar.SetActiveTab then
			refs.tabBar:SetActiveTab("all")
		end
		-- Re-render to reflect tab switch
		QuestsPanel:Render()
		switched = true
	end

	return switched
end

function QuestsPanel:Render()
	if not refs.listContainer then return end
	clearChildren(refs.listContainer)

	print("QuestsPanel: Rendering with playerQuests:", playerQuests)
	local cards = getQuestCards()
	print("QuestsPanel: Generated", #cards, "quest cards")
	local filteredCards = filterCards(cards, activeTab)

	-- Update badges and perform any necessary auto-switch before proceeding
	local switched = updateTabBadges()
	if switched then
		return
	end

	if #filteredCards == 0 then
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -12, 0, 40)
		label.Position = UDim2.new(0, 6, 0, 20)
		label.BackgroundTransparency = 1
		label.Text = activeTab == "all" and "No active quests" or
					 "No rewards ready to collect"
		label.TextColor3 = Color3.fromRGB(180, 180, 180)
		label.TextSize = 16
		label.Font = Enum.Font.SourceSans
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.TextYAlignment = Enum.TextYAlignment.Center
		label.Parent = refs.listContainer
		return
	end

	-- Sort cards: claimable first, then by milestone
	table.sort(filteredCards, function(a, b)
		if a.isClaimable ~= b.isClaimable then
			return a.isClaimable and not b.isClaimable
		end
		return a.milestone < b.milestone
	end)

	for _, card in ipairs(filteredCards) do
		UIComponents:CreateQuestCard({
			parent = refs.listContainer,
			questData = card.mobData,
			questConfig = card.mobConfig,
			milestone = card.milestone,
            onClaim = function()
                print("QuestsPanel: Claiming quest", card.mobType, "milestone", card.milestone)
                QuestsApi.ClaimReward(card.mobType, card.milestone)
            end
		})
	end

	-- Badges already updated earlier in this render
end

function QuestsPanel:CreateContent(contentFrame, data)
	refs.contentFrame = contentFrame
	clearChildren(contentFrame)

	-- Determine default tab based on current data:
	-- If there are claimable items, open with the "Completed" tab active
	local claimableCountForDefault = 0
	local cardsForDefault = getQuestCards()
	for _, card in ipairs(cardsForDefault) do
		if card.isClaimable then
			claimableCountForDefault += 1
		end
	end
	-- Enable a one-time default tab check after network data arrives
	pendingDefaultTabCheck = true
	if claimableCountForDefault > 0 then
		activeTab = "claimable"
		pendingDefaultTabCheck = false
	else
		activeTab = "all"
	end

	-- No header or refresh button needed

	-- Tab bar
	refs.tabBar = UIComponents:CreateTabBar({
		parent = contentFrame,
			tabs = {
				{text = "All", key = "all"},
				{text = "Completed", key = "claimable", badgeCount = 0}
			},
		activeTab = activeTab,
		onTabChanged = function(newTab)
			activeTab = newTab
			QuestsPanel:Render()
		end
	})
	refs.tabBar.frame.Position = UDim2.new(0, 0, 0, 8)

	-- Scrolling list
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "QuestScroll"
	scroll.Size = UDim2.new(1, 0, 1, -80)
	scroll.Position = UDim2.new(0, 0, 0, 54)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Color3.fromRGB(100, 149, 237)
	scroll.ScrollBarImageTransparency = 0.3
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = contentFrame

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 0, 0)
	list.BackgroundTransparency = 1
	list.AutomaticSize = Enum.AutomaticSize.Y
	list.Parent = scroll

	local vlayout = Instance.new("UIListLayout")
	vlayout.FillDirection = Enum.FillDirection.Vertical
	vlayout.SortOrder = Enum.SortOrder.LayoutOrder
	vlayout.Padding = UDim.new(0, 12)
	vlayout.Parent = list

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = list

	refs.listContainer = list

	-- Register quest event listeners
	if not eventsRegistered then
		print("QuestsPanel: Registering event listeners")
        QuestsApi.OnDataUpdated(function(payload)
			print("🔥 QuestDataUpdated RECEIVED! 🔥")
			print("QuestsPanel: Received QuestDataUpdated - server authoritative update")

			-- Server data is always authoritative
			playerQuests = payload.quests
			questConfig = payload.config

			-- Debug what we received
			if payload.quests and payload.quests.mobs then
				for mobType, mobData in pairs(payload.quests.mobs) do
					print("QuestsPanel: Server data -", mobType, "kills:", mobData.kills, "claimed:", mobData.claimed)
					if mobData.claimed then
						for milestone, isClaimed in pairs(mobData.claimed) do
							if isClaimed then
								print("QuestsPanel: Server confirms milestone", milestone, "is claimed for", mobType)
							end
						end
					end
				end
			end

			-- On the first update after opening, if there are claimables, switch to Completed
			if pendingDefaultTabCheck and refs.tabBar then
				local cards = getQuestCards()
				local hasClaimable = false
				for _, card in ipairs(cards) do
					if card.isClaimable then
						hasClaimable = true
						break
					end
				end
				if hasClaimable then
					activeTab = "claimable"
					if refs.tabBar and refs.tabBar.SetActiveTab then
						refs.tabBar:SetActiveTab("claimable")
					end
				end
				pendingDefaultTabCheck = false
			end

			QuestsPanel:Render()
        end)

        QuestsApi.OnProgressUpdated(function(update)
			print("QuestsPanel: Received QuestProgressUpdated", update.mobType, "kills:", update.kills)
			if not playerQuests then return end
			playerQuests.mobs = playerQuests.mobs or {}
			local mobType = update.mobType
			playerQuests.mobs[mobType] = playerQuests.mobs[mobType] or {kills = 0, claimed = {}}
			playerQuests.mobs[mobType].kills = update.kills or playerQuests.mobs[mobType].kills
			QuestsPanel:Render()
        end)

        QuestsApi.OnRewardClaimed(function(result)
			print("QuestsPanel: Quest reward claimed successfully!", result.mobType, "milestone:", result.milestone)
			-- Don't update local state - wait for server's authoritative QuestDataUpdated

			-- Show success toast with reward details
			local parts = {}
			if result.reward then
				if result.reward.coins then table.insert(parts, "💰" .. tostring(result.reward.coins)) end
				if result.reward.gems then table.insert(parts, "💎" .. tostring(result.reward.gems)) end
				if result.reward.experience then table.insert(parts, "⭐" .. tostring(result.reward.experience)) end
			end

			local msg = "Quest reward claimed!"
			local detail = (#parts > 0) and ("+" .. table.concat(parts, ", +")) or ""

			-- Try to show toast notification
			local success, ToastManager = pcall(require, script.Parent.Parent.Managers.ToastManager)
			if success and ToastManager and ToastManager.Success then
				ToastManager:Success(msg .. " " .. detail, 5)
			else
				-- Fallback: print to console
				print("Quest reward claimed:", msg, detail)
			end
        end)

        QuestsApi.OnError(function(err)
			print("QuestsPanel: Received QuestError", err and err.message or "Unknown error")

			-- Re-render to reset any "Claiming..." buttons back to normal
			QuestsPanel:Render()

			-- Show error toast
			local success, ToastManager = pcall(require, script.Parent.Parent.Managers.ToastManager)
			if success and ToastManager and ToastManager.Error then
				ToastManager:Error("Quest Error: " .. (err and err.message or "Unknown error"), 4)
			else
				print("Quest error:", err and err.message or "Unknown error")
			end
        end)

		eventsRegistered = true
	end

	-- Request initial data every time panel is created/shown
    QuestsApi.RequestData()
end

function QuestsPanel:Initialize() end

return QuestsPanel
