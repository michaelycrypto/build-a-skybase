--[[
	BuildSelectorPanel.lua - UX-friendly build selection panel
	- Left-docked sidebar (configured in PanelManager)
	- Two-column grid inside a scrolling frame
	- Stays open after selection for easy switching
	- Visual highlight for the selected item
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Panel = {}

local Config = require(ReplicatedStorage.Shared.Config)
local ViewportPreview = require(script.Parent.Parent.Managers.ViewportPreview)
local UIComponents = require(script.Parent.Parent.Managers.UIComponents)

-- Internal state
local selectedId = nil

function Panel:CreateContent(contentFrame, data)
	local onChoose = data and data.onChoose
	selectedId = (data and data.selectedId) or selectedId

	-- Scrolling container (full content area)
	local scroll = UIComponents:CreateScrollFrame({
		parent = contentFrame,
		size = UDim2.fromScale(1, 1)
	})

	-- Grid container for preview cards (two columns)
	local grid = Instance.new("Frame")
	grid.Name = "OptionsGrid"
	grid.Size = UDim2.fromScale(1, 0)
	grid.BackgroundTransparency = 1
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.Parent = scroll.content

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.fromOffset(10, 10)
	gridLayout.CellSize = UDim2.new(0.5, -8, 0, 210) -- two columns, taller to allow square previews
	gridLayout.FillDirectionMaxCells = 2
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	-- Options list
	local options = {
		{name = "Box", model = "Box", id = "BOX", order = 1},
		{name = "Wedge", model = "Wedge", id = "WEDGE", order = 2}
	}

	-- Keep references to cards for selection highlighting
	local cardsById = {}

	local function updateSelectionHighlights()
		for id, elements in pairs(cardsById) do
			local stroke = elements.stroke
			local bg = elements.button
			if selectedId == id then
				stroke.Color = Config.UI_SETTINGS.colors.accent
				stroke.Thickness = 2
				stroke.Transparency = 0
				bg.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
				bg.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
			else
				stroke.Color = Config.UI_SETTINGS.colors.semantic.borders.default
				stroke.Thickness = Config.UI_SETTINGS.designSystem.borderWidth.thin
				stroke.Transparency = 0.3
				bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
				bg.BackgroundTransparency = 0
			end
		end
	end

	local function createCard(option)
		local button = Instance.new("TextButton")
		button.Name = option.name .. "Card"
		button.Size = UDim2.fromScale(0, 0) -- sized by UIGridLayout
		button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
		button.AutoButtonColor = true
		button.Text = ""
		button.ClipsDescendants = true
		button.LayoutOrder = option.order or 1
		button.Parent = grid

		local stroke = Instance.new("UIStroke")
		stroke.Color = Config.UI_SETTINGS.colors.semantic.borders.default
		stroke.Thickness = Config.UI_SETTINGS.designSystem.borderWidth.thin
		stroke.Transparency = 0.3
		stroke.Parent = button

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		-- Preview container with square area to keep preview square regardless of card width
		local previewContainer = Instance.new("Frame")
		previewContainer.Name = "PreviewContainer"
		previewContainer.Size = UDim2.new(1, -20, 1, -44)
		previewContainer.Position = UDim2.fromOffset(10, 10)
		previewContainer.BackgroundTransparency = 1
		previewContainer.Parent = button

		local squareArea = Instance.new("Frame")
		squareArea.Name = "SquareArea"
		squareArea.Size = UDim2.fromScale(1, 1)
		squareArea.BackgroundTransparency = 1
		squareArea.Parent = previewContainer

		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.DominantAxis = Enum.DominantAxis.Width
		aspect.Parent = squareArea

		-- Viewport preview inside square area
		local preview = ViewportPreview.new({
			parent = squareArea,
			size = UDim2.fromScale(1, 1),
			borderRadius = 6,
			backgroundColor = Color3.fromRGB(18, 18, 18),
			backgroundTransparency = 0,
			paddingScale = 1.35 -- pull camera back a bit
		})

		local blocksFolder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Blocks")
		local template = blocksFolder and blocksFolder:FindFirstChild(option.model)
		if template then
			local model = template:Clone()
			preview:SetModel(model)
		end
		preview:SetSpin(true)

		-- Label (bottom)
		local label = Instance.new("TextLabel")
		label.Name = option.name .. "Label"
		label.Size = UDim2.new(1, -20, 0, 24)
		label.Position = UDim2.new(0, 10, 1, -34)
		label.BackgroundTransparency = 1
		label.Text = option.name
		label.TextColor3 = Config.UI_SETTINGS.colors.text
		label.Font = Config.UI_SETTINGS.typography.fonts.bold
		label.TextSize = 18
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.Parent = button

		button.MouseButton1Click:Connect(function()
			selectedId = option.id
			updateSelectionHighlights()
			if onChoose then
				onChoose(option.id)
			end
		end)

		cardsById[option.id] = {
			button = button,
			stroke = stroke
		}
	end

	for _, option in ipairs(options) do
		createCard(option)
	end

	-- Default select first option if none specified
	if not selectedId and #options > 0 then
		selectedId = options[1].id
	end

	updateSelectionHighlights()
end

return Panel


