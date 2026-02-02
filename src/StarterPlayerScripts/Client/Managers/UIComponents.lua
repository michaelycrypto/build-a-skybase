--[[
	UIComponents.lua - Reusable UI Component Library
	Provides standardized UI components for consistent design across the game
--]]

local UIComponents = {}

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import dependencies
local Config = require(ReplicatedStorage.Shared.Config)
local IconManager = require(script.Parent.IconManager)
local SoundManager = require(script.Parent.SoundManager)
local GameState = require(script.Parent.GameState)
local ViewportPreview = require(script.Parent.ViewportPreview)

-- Services
local Players = game:GetService("Players")
local InputService = require(script.Parent.Parent.Input.InputService)
local _GuiService = game:GetService("GuiService")

-- Services and instances
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Tooltip system state
local activeTooltip = nil
local activeTooltipTarget = nil -- Track which element the active tooltip belongs to
local tooltipContainer = nil
local _tooltipDebounce = {}
local hideTooltipDebounce = nil

-- Component configurations
local COMPONENT_CONFIGS = {
	panel = {
		sizes = {
			small = {width = 420, height = 320},     -- More spacious
			medium = {width = 560, height = 440},    -- More spacious
			large = {width = 680, height = 560},     -- More spacious
			wide = {width = 780, height = 440},      -- More spacious
			emote_wide = {width = 720, height = 220} -- More spacious emote panel
		},
		headerHeight = 32,  -- Taller header for better proportion
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.lg,
		backdropTransparency = Config.UI_SETTINGS.designSystem.transparency.backdrop
	},
	button = {
		sizes = {
			compact = {width = 100, height = 35},   -- Compact size for buy buttons
			small = {width = 80, height = 36},   -- More spacious buttons
			medium = {width = 100, height = 48},  -- More spacious buttons
			large = {width = 140, height = 56}    -- More spacious buttons
		},
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md,
		borderOffset = 2,
		useBackgroundFrame = true -- Enable background frames for all buttons
	},
	iconButton = {
		sizes = {
			small = {width = 32, height = 32, iconSize = 16},
			medium = {width = 40, height = 40, iconSize = 20},
			large = {width = 48, height = 48, iconSize = 24},
			xl = {width = 60, height = 60, iconSize = 40},     -- MainHUD sidebar buttons
			xxl = {width = 68, height = 68, iconSize = 44}     -- MainHUD border frames
		},
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.sm,
		borderOffset = 4,
		useBackgroundFrame = true -- Enable background frames for all icon buttons
	},
	card = {
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.lg,
		borderThickness = Config.UI_SETTINGS.designSystem.borderWidth.thin,
		borderTransparency = Config.UI_SETTINGS.designSystem.transparency.ghost
	},
	container = {
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md,
		padding = Config.UI_SETTINGS.designSystem.spacing.md
	},
	badge = {
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.xs,
		padding = Config.UI_SETTINGS.designSystem.spacing.xs,
		sizes = {
			small = {height = 16, textSize = Config.UI_SETTINGS.typography.sizes.ui.badge},
			medium = {height = 20, textSize = Config.UI_SETTINGS.typography.sizes.body.base},
			large = {height = 24, textSize = Config.UI_SETTINGS.typography.sizes.body.base}
		}
	}
}

-- Panel Layout Components for spacious, comfortable designs
local PANEL_LAYOUTS = {
	-- Standard spacings using design system (more generous)
	spacing = {
		section = Config.UI_SETTINGS.designSystem.spacing.lg,    -- Between major sections
		item = Config.UI_SETTINGS.designSystem.spacing.sm,      -- Between items in a section
		tight = Config.UI_SETTINGS.designSystem.spacing.sm,     -- For compact layouts
		content = Config.UI_SETTINGS.designSystem.spacing.lg    -- Content padding from edges
	},

	-- Section configurations
	section = {
		headerHeight = 32,  -- Taller section headers
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md,
		padding = Config.UI_SETTINGS.designSystem.spacing.lg  -- More generous padding
	},

	-- Form element configurations
	formRow = {
		height = 48,       -- More comfortable form rows
		labelWidth = 0.4,  -- 40% for labels, 60% for controls
		spacing = Config.UI_SETTINGS.designSystem.spacing.sm  -- More space between elements
	}
}

--[[
	Create a compact information topbar (reusable for currency, streak, etc.)
	@param config: table - Topbar configuration
	@return: table - Topbar components
--]]
function UIComponents:CreateInfoTopbar(config)
	local topbarConfig = config or {}
	local parent = topbarConfig.parent
	local items = topbarConfig.items or {} -- Array of {icon = {category, name, color}, text = "Text", value = "Value"}
	local layoutOrder = topbarConfig.layoutOrder or 1
	local backgroundColor = topbarConfig.backgroundColor or Config.UI_SETTINGS.colors.backgroundSecondary
	local transparency = topbarConfig.transparency or Config.UI_SETTINGS.designSystem.transparency.light
	local size = topbarConfig.size or UDim2.new(1, 0, 0, 39) -- Allow custom sizing

	-- Main topbar frame
	local topbarFrame = Instance.new("Frame")
	topbarFrame.Name = "InfoTopbar"
	topbarFrame.Size = size -- Use configurable size
	topbarFrame.BackgroundColor3 = backgroundColor
	topbarFrame.BackgroundTransparency = transparency
	topbarFrame.BorderSizePixel = 0
	topbarFrame.LayoutOrder = layoutOrder
	topbarFrame.Parent = parent

	-- Horizontal layout for items
	local topbarLayout = Instance.new("UIListLayout")
	topbarLayout.FillDirection = Enum.FillDirection.Horizontal
	topbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	topbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topbarLayout.Padding = UDim.new(0, 16) -- Space between items
	topbarLayout.Parent = topbarFrame

	local topbarPadding = Instance.new("UIPadding")
	topbarPadding.PaddingLeft = UDim.new(0, 12)
	topbarPadding.PaddingRight = UDim.new(0, 12)
	topbarPadding.PaddingTop = UDim.new(0, 6)
	topbarPadding.PaddingBottom = UDim.new(0, 6)
	topbarPadding.Parent = topbarFrame

	-- Create items
	local itemComponents = {}
	for i, item in ipairs(items) do
		local itemContainer = Instance.new("Frame")
		itemContainer.Name = "TopbarItem" .. i
		itemContainer.Size = UDim2.fromScale(0, 1) -- Auto-size based on content
		itemContainer.BackgroundTransparency = 1
		itemContainer.LayoutOrder = i
		itemContainer.Parent = topbarFrame

		local itemLayout = Instance.new("UIListLayout")
		itemLayout.FillDirection = Enum.FillDirection.Horizontal
		itemLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		itemLayout.SortOrder = Enum.SortOrder.LayoutOrder
		itemLayout.Padding = UDim.new(0, 6) -- Tight spacing between icon and text
		itemLayout.Parent = itemContainer

		-- Auto-size the container based on content
		local itemSizeConstraint = Instance.new("UIListLayout")
		itemSizeConstraint.FillDirection = Enum.FillDirection.Horizontal
		itemSizeConstraint.HorizontalAlignment = Enum.HorizontalAlignment.Left
		itemSizeConstraint.VerticalAlignment = Enum.VerticalAlignment.Center
		itemSizeConstraint.SortOrder = Enum.SortOrder.LayoutOrder
		itemSizeConstraint.Padding = UDim.new(0, 6)
		itemSizeConstraint.Parent = itemContainer

		-- Icon (if provided)
		local itemIcon = nil
		if item.icon and item.icon.category and item.icon.name then
			itemIcon = IconManager:CreateIcon(itemContainer, item.icon.category, item.icon.name, {
				size = UDim2.fromOffset(40, 40), -- Compact icon size
				layoutOrder = 1
			})
		end

		-- Text/Value container
		local textContainer = Instance.new("Frame")
		textContainer.Name = "TextContainer"
		textContainer.Size = UDim2.fromScale(0, 1) -- Will be auto-sized based on content
		textContainer.BackgroundTransparency = 1
		textContainer.LayoutOrder = 2
		textContainer.Parent = itemContainer

		local textLayout = Instance.new("UIListLayout")
		textLayout.FillDirection = Enum.FillDirection.Horizontal
		textLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
		textLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		textLayout.SortOrder = Enum.SortOrder.LayoutOrder
		textLayout.Padding = UDim.new(0, 4)
		textLayout.Parent = textContainer

		-- Text label (if provided)
		local textLabel = nil
		if item.text then
			textLabel = Instance.new("TextLabel")
			textLabel.Name = "TextLabel"
			textLabel.Size = UDim2.fromScale(0, 1) -- Auto-size
			textLabel.BackgroundTransparency = 1
			textLabel.Text = item.text
			textLabel.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
			textLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
			textLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
			textLabel.TextXAlignment = Enum.TextXAlignment.Left
			textLabel.TextYAlignment = Enum.TextYAlignment.Center
			textLabel.LayoutOrder = 1
			textLabel.Parent = textContainer

			-- Auto-size text
			textLabel.Size = UDim2.new(0, textLabel.TextBounds.X, 1, 0)
		end

		-- Value label (if provided)
		local valueLabel = nil
		if item.value then
			valueLabel = Instance.new("TextLabel")
			valueLabel.Name = "ValueLabel"
			valueLabel.Size = UDim2.fromScale(0, 1) -- Auto-size
			valueLabel.BackgroundTransparency = 1
			valueLabel.Text = tostring(item.value)
			valueLabel.TextColor3 = item.valueColor or Config.UI_SETTINGS.colors.text
			valueLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
			valueLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
			valueLabel.TextXAlignment = Enum.TextXAlignment.Left
			valueLabel.TextYAlignment = Enum.TextYAlignment.Center
			valueLabel.LayoutOrder = 2
			valueLabel.Parent = textContainer

			-- Auto-size value
			valueLabel.Size = UDim2.new(0, valueLabel.TextBounds.X, 1, 0)
		end

		-- Calculate and set textContainer width based on its children
		local textContainerWidth = 0
		if textLabel then
			textContainerWidth = textContainerWidth + textLabel.TextBounds.X
		end
		if valueLabel then
			textContainerWidth = textContainerWidth + (textLabel and 4 or 0) + valueLabel.TextBounds.X -- Add padding if both exist
		end
		-- Add 10px spacing to the right of the text
		textContainerWidth = textContainerWidth + 10
		textContainer.Size = UDim2.new(0, textContainerWidth, 1, 0)

		-- Store component references
		table.insert(itemComponents, {
			container = itemContainer,
			icon = itemIcon,
			textLabel = textLabel,
			valueLabel = valueLabel,
			textContainer = textContainer
		})

		-- Auto-size the item container
		itemContainer.Size = UDim2.new(0,
			(itemIcon and 26 or 0) +
			(textLabel and textLabel.TextBounds.X + 4 or 0) +
			(valueLabel and valueLabel.TextBounds.X or 0),
		1, 0)
	end

	return {
		topbar = topbarFrame,
		items = itemComponents,
		UpdateItem = function(_self, index, newData)
			if itemComponents[index] then
				local item = itemComponents[index]
				if newData.text and item.textLabel then
					item.textLabel.Text = newData.text
					item.textLabel.Size = UDim2.new(0, item.textLabel.TextBounds.X, 1, 0)
				end
				if newData.value and item.valueLabel then
					item.valueLabel.Text = tostring(newData.value)
					item.valueLabel.TextColor3 = newData.valueColor or Config.UI_SETTINGS.colors.text
					item.valueLabel.Size = UDim2.new(0, item.valueLabel.TextBounds.X, 1, 0)
				end

				-- Update textContainer width based on its children
				local textContainerWidth = 0
				if item.textLabel then
					textContainerWidth = textContainerWidth + item.textLabel.TextBounds.X
				end
				if item.valueLabel then
					textContainerWidth = textContainerWidth + (item.textLabel and 4 or 0) + item.valueLabel.TextBounds.X -- Add padding if both exist
				end
				-- Add 10px spacing to the right of the text
				textContainerWidth = textContainerWidth + 10
				item.textContainer.Size = UDim2.new(0, textContainerWidth, 1, 0)

				-- Update container size
				item.container.Size = UDim2.new(0,
					(item.icon and 26 or 0) +
					textContainerWidth,
				1, 0)
			end
		end
	}
end

--[[
	Create a standardized panel with header and content area
	@param config: table - Panel configuration
	@return: table - Panel components
--]]
function UIComponents:CreatePanel(config)
	local panelConfig = config or {}
	local size = panelConfig.size or "medium"
	local title = panelConfig.title or "Panel"
	local _icon = panelConfig.icon
	local parent = panelConfig.parent
	local closable = panelConfig.closable ~= false -- Default true
	local headerless = panelConfig.headerless == true -- Default false

	local sizeConfig = COMPONENT_CONFIGS.panel.sizes[size] or COMPONENT_CONFIGS.panel.sizes.medium
	local panelWidth = sizeConfig.width
	local panelHeight = sizeConfig.height

	-- Create main ScreenGui
	local panelGui = Instance.new("ScreenGui")
	panelGui.Name = (panelConfig.name or "Panel") .. "GUI"
	panelGui.ResetOnSpawn = false
	panelGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	panelGui.Enabled = false
	panelGui.Parent = parent or game.Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Main panel frame (no backdrop)
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "MainFrame"
	mainFrame.Size = UDim2.fromOffset(panelWidth, panelHeight)
	mainFrame.Position = UDim2.new(0.5, -panelWidth/2, 0.5, -panelHeight/2)
	mainFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundGlass -- Flat dark background
	mainFrame.BackgroundTransparency = 0 -- Completely opaque for flat design
	mainFrame.BorderSizePixel = 0
	mainFrame.Parent = panelGui

	-- Main panel border
	local mainBorder = Instance.new("UIStroke")
	mainBorder.Color = Config.UI_SETTINGS.colors.semantic.borders.default -- Consistent with other UI components
	mainBorder.Thickness = Config.UI_SETTINGS.designSystem.borderWidth.thin
	mainBorder.Transparency = 0.3 -- Semi-transparent black border
	mainBorder.Parent = mainFrame

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	mainCorner.Parent = mainFrame

	-- Header frame (only if not headerless)
	local headerFrame = nil
	local actualHeaderHeight = headerless and 0 or COMPONENT_CONFIGS.panel.headerHeight

	if not headerless then
		headerFrame = Instance.new("Frame")
		headerFrame.Name = "Header"
		headerFrame.Size = UDim2.new(1, 0, 0, 1)
		headerFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary -- Slightly lighter header
		headerFrame.BackgroundTransparency = 1 -- Transparent background
		headerFrame.BorderSizePixel = 0
		headerFrame.Parent = mainFrame

		local headerCorner = Instance.new("UICorner")
		headerCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
		headerCorner.Parent = headerFrame
	end

	-- Title container with icon (only if not headerless)
	local titleContainer = nil
	local titleIcon = nil
	local titleLabel = nil
	local closeButton = nil

	if not headerless then
		titleContainer = Instance.new("Frame")
		titleContainer.Name = "TitleContainer"
		titleContainer.Size = UDim2.new(1, closable and -(64 + Config.UI_SETTINGS.designSystem.spacing.lg) or 0, 1, 0) -- Reserve space for close button
		titleContainer.Position = UDim2.fromScale(0, -0.5) -- 50% offset above the panel
		titleContainer.BackgroundTransparency = 1
		titleContainer.Parent = headerFrame

		-- Title container padding using design system (more generous)
		local titlePadding = Instance.new("UIPadding")
		titlePadding.PaddingLeft = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
		titlePadding.PaddingRight = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
		titlePadding.Parent = titleContainer

		local titleLayout = Instance.new("UIListLayout")
		titleLayout.FillDirection = Enum.FillDirection.Horizontal
		titleLayout.SortOrder = Enum.SortOrder.LayoutOrder
		titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		titleLayout.Padding = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.lg)
		titleLayout.Parent = titleContainer
		-- Title text
		titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(0, 200, 1, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.RichText = true
		titleLabel.Text = "<b><i>" .. title .. "</i></b>"
		titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
		titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.display.hero
		titleLabel.Font = Config.UI_SETTINGS.typography.fonts.italicBold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.LayoutOrder = 2
		titleLabel.Parent = titleContainer

		-- Title stroke
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
		titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
		titleStroke.Parent = titleLabel

		-- Close button (if closable)
		if closable then
            closeButton = IconManager:CreateIcon(headerFrame, "UI", "X", {
                size = UDim2.fromOffset(40, 40),
                position = UDim2.fromScale(1, 0),
            })

			-- Make the icon clickable with dark red background
			if closeButton then
				closeButton.Name = "CloseButton"
				-- Convert to ImageButton for better interaction
				local imageButton = Instance.new("ImageButton")
				imageButton.Name = "CloseButton"
				imageButton.Size = closeButton.Size
				imageButton.Position = closeButton.Position
				imageButton.AnchorPoint = closeButton.AnchorPoint
				imageButton.BackgroundTransparency = 1
				imageButton.Image = closeButton.Image
				imageButton.ScaleType = closeButton.ScaleType
				imageButton.Parent = headerFrame

				-- Add rounded corners to close button
				local closeButtonCorner = Instance.new("UICorner")
				closeButtonCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.sm)
				closeButtonCorner.Parent = imageButton

				-- Add rotation animation on mouse enter/leave
				local TweenService = game:GetService("TweenService")
				local rotationTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

				-- Mouse enter: rotate 90 degrees
				imageButton.MouseEnter:Connect(function()
					local rotationTween = TweenService:Create(imageButton, rotationTweenInfo, {
						Rotation = 90
					})
					rotationTween:Play()
				end)

				-- Mouse leave: rotate back to 0 degrees
				imageButton.MouseLeave:Connect(function()
					local rotationTween = TweenService:Create(imageButton, rotationTweenInfo, {
						Rotation = 0
					})
					rotationTween:Play()
				end)

				-- Remove the original icon
				closeButton:Destroy()
				closeButton = imageButton
			end
		end
	end

	-- Content frame (compact padding using design system)
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "Content"
	contentFrame.Size = UDim2.new(1, 0, 1, -actualHeaderHeight) -- No side padding, tight fit
	contentFrame.Position = UDim2.fromOffset(0, actualHeaderHeight) -- No side margin
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = mainFrame



	-- Panel object with methods
	local panel = {
		gui = panelGui,
		mainFrame = mainFrame,
		headerFrame = headerFrame,
		titleContainer = titleContainer,
		titleIcon = titleIcon,
		titleLabel = titleLabel,
		closeButton = closeButton,
		contentFrame = contentFrame,

		-- Panel methods
		Show = function(self, animationDuration)
			local duration = animationDuration or Config.UI_SETTINGS.designSystem.animation.duration.normal
			self.gui.Enabled = true

			-- Store original position for animation
			local originalPosition = self.mainFrame.Position

			-- Start from below/hidden for slide-up effect
			self.mainFrame.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, 1, 50)

			-- Slide up animation
			TweenService:Create(self.mainFrame, TweenInfo.new(duration, Config.UI_SETTINGS.designSystem.animation.easing.smooth, Enum.EasingDirection.Out), {
				Position = originalPosition
			}):Play()

			if SoundManager then
				SoundManager:PlaySFX("buttonClick")
			end
		end,

		Hide = function(self, animationDuration)
			local duration = animationDuration or Config.UI_SETTINGS.designSystem.animation.duration.fast
			local originalPosition = self.mainFrame.Position

			-- Slide down animation
			local hideTween = TweenService:Create(self.mainFrame, TweenInfo.new(duration, Config.UI_SETTINGS.designSystem.animation.easing.smooth, Enum.EasingDirection.In), {
				Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, 1, 50)
			})

			hideTween:Play()
			hideTween.Completed:Connect(function()
				self.gui.Enabled = false
			end)
		end,

		SetTitle = function(self, newTitle)
			if self.titleLabel then
				self.titleLabel.Text = newTitle
			end
		end,

		Destroy = function(self)
			if self.gui then
				self.gui:Destroy()
			end
		end
	}

	return panel
end

--[[
	Create a standardized button with border frame and hover effects
	@param config: table - Button configuration
		- style: string - "action" (default, HUD style with border frames) or "panel" (full-width for panels)
	@return: table - Button components
--]]
function UIComponents:CreateButton(config)
	local buttonConfig = config or {}
	local size = buttonConfig.size or "medium"
	local text = buttonConfig.text or "Button"
	local parent = buttonConfig.parent
	local position = buttonConfig.position
	local callback = buttonConfig.callback
	local colorVariant = buttonConfig.color or "primary"
	local style = buttonConfig.style or "action" -- Default to action button style

	local sizeConfig = COMPONENT_CONFIGS.button.sizes[size] or COMPONENT_CONFIGS.button.sizes.medium
	local buttonWidth = sizeConfig.width
	local buttonHeight = sizeConfig.height

	-- Get color from semantic tokens or fallback to direct color
	local buttonColor = Config.UI_SETTINGS.colors.semantic.button[colorVariant] or buttonConfig.color or Config.UI_SETTINGS.colors.accent
	local borderColor = Config.UI_SETTINGS.colors.semantic.borders.default

	local borderFrame, button

	if style == "panel" then
		-- Panel button style - full width, no border frame
		button = Instance.new("TextButton")
		button.Name = buttonConfig.name or "Button"
		button.Size = UDim2.fromScale(1, 1) -- Fill parent container
		button.Position = UDim2.fromScale(0, 0)
		button.BackgroundColor3 = buttonColor
		button.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
		button.Text = text
		button.TextColor3 = buttonConfig.textColor or Config.UI_SETTINGS.colors.text
		button.TextSize = buttonConfig.textSize or Config.UI_SETTINGS.typography.sizes.headings.h3
		button.Font = buttonConfig.font or Config.UI_SETTINGS.typography.fonts.bold
		button.BorderSizePixel = 0
		button.Parent = parent

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.button.borderRadius)
		buttonCorner.Parent = button

		-- Flat background - no gradient overlay

		-- For panel buttons, the button itself is the border frame equivalent
		borderFrame = button
	else
		-- Action button style - fixed size with border frame (original behavior)
		borderFrame = Instance.new("Frame")
		borderFrame.Name = (buttonConfig.name or "Button") .. "Frame"
		borderFrame.Size = UDim2.fromOffset(buttonWidth + (COMPONENT_CONFIGS.button.borderOffset * 2), buttonHeight + (COMPONENT_CONFIGS.button.borderOffset * 2))
		borderFrame.Position = position or UDim2.fromScale(0, 0)
		borderFrame.BackgroundColor3 = borderColor
		borderFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy
		borderFrame.BorderSizePixel = 0
		borderFrame.Parent = parent

		local frameCorner = Instance.new("UICorner")
		frameCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.button.borderRadius + 2)
		frameCorner.Parent = borderFrame

		-- Main button
		button = Instance.new("TextButton")
		button.Name = buttonConfig.name or "Button"
		button.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
		button.Position = UDim2.fromOffset(COMPONENT_CONFIGS.button.borderOffset, COMPONENT_CONFIGS.button.borderOffset)
		button.BackgroundColor3 = buttonColor
		button.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
		button.Text = text
		button.TextColor3 = buttonConfig.textColor or Config.UI_SETTINGS.colors.text
		button.TextSize = buttonConfig.textSize or Config.UI_SETTINGS.typography.sizes.headings.h3
		button.Font = buttonConfig.font or Config.UI_SETTINGS.typography.fonts.bold
		button.BorderSizePixel = 0
		button.Parent = borderFrame

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.button.borderRadius)
		buttonCorner.Parent = button

		-- Flat background - no gradient overlay
	end

	-- Button object with methods
	local buttonObj = {
		borderFrame = borderFrame,
		button = button,

		-- Button methods
		SetText = function(self, newText)
			self.button.Text = newText
		end,

		SetEnabled = function(self, enabled)
			self.button.Active = enabled
			self.button.BackgroundTransparency = enabled and Config.UI_SETTINGS.designSystem.transparency.light or Config.UI_SETTINGS.designSystem.transparency.backdrop
		end,

		Destroy = function(self)
			if self.borderFrame then
				self.borderFrame:Destroy()
			end
		end
	}

	-- Hover effects (different for panel vs action buttons)
	if style == "panel" then
		-- Panel button hover effects
		button.MouseEnter:Connect(function()
			if SoundManager then
				SoundManager:PlaySFX("buttonHover")
			end
			TweenService:Create(button, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.subtle
			}):Play()
		end)

		button.MouseLeave:Connect(function()
			TweenService:Create(button, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
			}):Play()
		end)
	else
		-- Action button hover effects (original behavior)
		button.MouseEnter:Connect(function()
			if SoundManager then
				SoundManager:PlaySFX("buttonHover")
			end
			TweenService:Create(borderFrame, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
			}):Play()
		end)

		button.MouseLeave:Connect(function()
			TweenService:Create(borderFrame, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.heavy
			}):Play()
		end)
	end

	button.MouseButton1Click:Connect(function()
		if SoundManager then
			SoundManager:PlaySFX("buttonClick")
		end
		if callback then
			callback()
		end
	end)

	return buttonObj
end

--[[
	Create a specialized icon button (like MainHUD sidebar buttons)
	@param config: table - Icon button configuration
	@return: table - Icon button components
--]]
function UIComponents:CreateIconButton(config)
	local buttonConfig = config or {}
	local size = buttonConfig.size or "medium"
	local parent = buttonConfig.parent
	local position = buttonConfig.position
	local anchorPoint = buttonConfig.anchorPoint
	local callback = buttonConfig.callback
	local colorVariant = buttonConfig.color or "secondary"

	local sizeConfig = COMPONENT_CONFIGS.iconButton.sizes[size] or COMPONENT_CONFIGS.iconButton.sizes.medium
	local buttonWidth = sizeConfig.width
	local buttonHeight = sizeConfig.height
	local iconSize = sizeConfig.iconSize

	-- Get colors from semantic tokens
	local buttonColor = Config.UI_SETTINGS.colors.semantic.button[colorVariant] or Config.UI_SETTINGS.colors.accent
	local borderColor = Config.UI_SETTINGS.colors.semantic.borders.default

	-- Background frame (always create for consistency)
	local borderFrame = Instance.new("Frame")
	borderFrame.Name = (buttonConfig.name or "IconButton") .. "Frame"
	borderFrame.Size = UDim2.fromOffset(buttonWidth + (COMPONENT_CONFIGS.iconButton.borderOffset * 2), buttonHeight + (COMPONENT_CONFIGS.iconButton.borderOffset * 2))
	borderFrame.Position = position or UDim2.fromScale(0, 0)
	borderFrame.AnchorPoint = anchorPoint or Vector2.new(0, 0)
	borderFrame.BackgroundColor3 = borderColor
	borderFrame.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	borderFrame.BorderSizePixel = 0
	borderFrame.Parent = parent

	local frameCorner = Instance.new("UICorner")
	frameCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.iconButton.borderRadius + 2)
	frameCorner.Parent = borderFrame

	-- Main button
	local button = Instance.new("TextButton")
	button.Name = buttonConfig.name or "IconButton"
	button.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
	button.Position = UDim2.fromOffset(COMPONENT_CONFIGS.iconButton.borderOffset, COMPONENT_CONFIGS.iconButton.borderOffset)
	button.BackgroundColor3 = buttonColor
	button.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.medium
	button.Text = ""
	button.BorderSizePixel = 0
	button.Parent = borderFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.iconButton.borderRadius)
	buttonCorner.Parent = button

	-- Flat background - no gradient overlay

	-- Icon (adjust position if there's a text label)
	local iconElement = nil
	if buttonConfig.iconCategory and buttonConfig.iconName then
		local iconPosition = UDim2.fromScale(0.5, 0.5)
		local iconAnchor = Vector2.new(0.5, 0.5)
		local adjustedIconSize = iconSize

		-- If there's a text label, adjust icon position and size
		if buttonConfig.buttonText then
			iconPosition = UDim2.new(0.5, 0, 0, 6) -- Move icon to top
			iconAnchor = Vector2.new(0.5, 0)
			adjustedIconSize = math.floor(iconSize * 0.8) -- Make icon slightly smaller
		end

		iconElement = IconManager:CreateIcon(button, buttonConfig.iconCategory, buttonConfig.iconName, {
			size = UDim2.fromOffset(adjustedIconSize, adjustedIconSize),
			position = iconPosition,
			anchorPoint = iconAnchor,
		})
	end

	-- Create button text label if specified
	local buttonTextLabel = nil
	if buttonConfig.buttonText then
		buttonTextLabel = Instance.new("TextLabel")
		buttonTextLabel.Name = "ButtonText"
		buttonTextLabel.Size = UDim2.new(1, -4, 0, 18) -- Full width minus padding, 18px height for larger text
		buttonTextLabel.Position = UDim2.new(0, 2, 1, -14) -- Stuck lower to bottom of button
		buttonTextLabel.BackgroundTransparency = 1
		buttonTextLabel.Text = buttonConfig.buttonText
		buttonTextLabel.TextColor3 = buttonConfig.textColor or Config.UI_SETTINGS.colors.text
		buttonTextLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.large -- Bigger font (16px)
		buttonTextLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
		buttonTextLabel.TextXAlignment = Enum.TextXAlignment.Center
		buttonTextLabel.TextYAlignment = Enum.TextYAlignment.Center
		buttonTextLabel.TextScaled = false -- Disable scaling to use exact font size
		-- Add semi-transparent text stroke for better readability
		buttonTextLabel.TextStrokeTransparency = 0.5
		buttonTextLabel.TextStrokeColor3 = Config.UI_SETTINGS.colors.text
		buttonTextLabel.Parent = button
	end

	-- Button object with methods
	local buttonObj = {
		borderFrame = borderFrame,
		button = button,
		icon = iconElement,
		buttonTextLabel = buttonTextLabel,

		-- Button methods
		SetEnabled = function(self, enabled)
			self.button.Active = enabled
			-- Don't modify icon transparency here - let cooldown system handle it
		end,

		Destroy = function(self)
			if self.borderFrame then
				self.borderFrame:Destroy()
			end
		end
	}

	-- Hover effects
	button.MouseEnter:Connect(function()
		if SoundManager then
			SoundManager:PlaySFX("buttonHover")
		end
		-- Scale up the icon
		if iconElement then
			local currentSize = iconElement.Size.X.Offset
			TweenService:Create(iconElement, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(currentSize + 4, currentSize + 4)
			}):Play()
		end
		-- Border glow effect
		TweenService:Create(borderFrame, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
			BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.subtle
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		-- Scale down the icon
		if iconElement then
			local originalSize = buttonConfig.buttonText and math.floor(iconSize * 0.8) or iconSize
			TweenService:Create(iconElement, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
				Size = UDim2.fromOffset(originalSize, originalSize)
			}):Play()
		end
		-- Reset border
		TweenService:Create(borderFrame, TweenInfo.new(Config.UI_SETTINGS.designSystem.animation.duration.normal, Config.UI_SETTINGS.designSystem.animation.easing.ease, Enum.EasingDirection.Out), {
			BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
		}):Play()
	end)

	button.MouseButton1Click:Connect(function()
		if SoundManager then
			SoundManager:PlaySFX("buttonClick")
		end
		if callback then
			callback()
		end
	end)

	return buttonObj
end

--[[
	Create a standardized container frame
	@param config: table - Container configuration
	@return: Frame - Container frame
--]]
function UIComponents:CreateContainer(config)
	local containerConfig = config or {}
	local parent = containerConfig.parent
	local size = containerConfig.size or UDim2.fromScale(1, 1)
	local position = containerConfig.position

	local container = Instance.new("Frame")
	container.Name = containerConfig.name or "Container"
	container.Size = size
	container.Position = position or UDim2.fromScale(0, 0)
	container.BackgroundColor3 = containerConfig.backgroundColor or Config.UI_SETTINGS.colors.semantic.backgrounds.card
	container.BackgroundTransparency = containerConfig.backgroundTransparency or Config.UI_SETTINGS.designSystem.transparency.subtle
	container.BorderSizePixel = 0
	container.Parent = parent

	if containerConfig.rounded ~= false then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, containerConfig.borderRadius or COMPONENT_CONFIGS.container.borderRadius)
		corner.Parent = container
	end

	if containerConfig.padding then
		local padding = Instance.new("UIPadding")
		local paddingValue = containerConfig.padding or COMPONENT_CONFIGS.container.padding
		padding.PaddingTop = UDim.new(0, paddingValue)
		padding.PaddingBottom = UDim.new(0, paddingValue)
		padding.PaddingLeft = UDim.new(0, paddingValue)
		padding.PaddingRight = UDim.new(0, paddingValue)
		padding.Parent = container
	end

	return container
end

--[[
	Create a standardized badge/label
	@param config: table - Badge configuration
	@return: Frame - Badge frame
--]]
function UIComponents:CreateBadge(config)
	local badgeConfig = config or {}
	local size = badgeConfig.size or "medium"
	local text = badgeConfig.text or "Badge"
	local parent = badgeConfig.parent
	local position = badgeConfig.position
	local colorVariant = badgeConfig.color or "primary"

	local sizeConfig = COMPONENT_CONFIGS.badge.sizes[size] or COMPONENT_CONFIGS.badge.sizes.medium
	local badgeHeight = sizeConfig.height
	local textSize = sizeConfig.textSize

	-- Get color from semantic tokens
	local badgeColor = Config.UI_SETTINGS.colors.semantic.button[colorVariant] or Config.UI_SETTINGS.colors.accent

	local badge = Instance.new("Frame")
	badge.Name = badgeConfig.name or "Badge"
	badge.Size = UDim2.fromOffset(0, badgeHeight) -- Width auto-calculated by text
	badge.Position = position or UDim2.fromScale(0, 0)
	badge.BackgroundColor3 = badgeColor
	badge.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	badge.BorderSizePixel = 0
	badge.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.badge.borderRadius)
	corner.Parent = badge

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.TextColor3 = Config.UI_SETTINGS.colors.text
	textLabel.TextSize = textSize
	textLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	textLabel.TextXAlignment = Enum.TextXAlignment.Center
	textLabel.Parent = badge

	-- Auto-size the badge based on text
	local textBounds = textLabel.TextBounds
	badge.Size = UDim2.fromOffset(textBounds.X + (COMPONENT_CONFIGS.badge.padding * 2), badgeHeight)

	return badge
end

--[[
	Create a standardized card with border and content area
	@param config: table - Card configuration
	@return: Frame - Card frame
--]]
function UIComponents:CreateCard(config)
	local cardConfig = config or {}
	local parent = cardConfig.parent
	local size = cardConfig.size or UDim2.fromOffset(200, 150)
	local position = cardConfig.position

	-- Main card frame
	local cardFrame = Instance.new("Frame")
	cardFrame.Name = cardConfig.name or "Card"
	cardFrame.Size = size
	cardFrame.Position = position or UDim2.fromScale(0, 0)
	cardFrame.BackgroundColor3 = cardConfig.backgroundColor or Config.UI_SETTINGS.colors.semantic.backgrounds.card
	cardFrame.BackgroundTransparency = cardConfig.backgroundTransparency or Config.UI_SETTINGS.designSystem.transparency.subtle
	cardFrame.BorderSizePixel = 0
	cardFrame.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.card.borderRadius)
	cardCorner.Parent = cardFrame

	-- Add border if specified
	if cardConfig.border ~= false then
		local cardBorder = Instance.new("UIStroke")
		cardBorder.Color = cardConfig.borderColor or Config.UI_SETTINGS.colors.semantic.borders.default
		cardBorder.Thickness = COMPONENT_CONFIGS.card.borderThickness
		cardBorder.Transparency = cardConfig.borderTransparency or COMPONENT_CONFIGS.card.borderTransparency
		cardBorder.Parent = cardFrame
	end

	return cardFrame
end

-- Gradient overlay function removed - using flat backgrounds with borders

--[[
	Create a compact card component for flexbox layouts
	@param config: table - Card configuration
	@return: table - Card components
--]]
function UIComponents:CreateFlexibleCard(config)
	local cardConfig = config or {}
	local parent = cardConfig.parent
	local title = cardConfig.title
	local icon = cardConfig.icon
	local layoutOrder = cardConfig.layoutOrder or 1
	local size = cardConfig.size or "auto" -- "auto", "full", or UDim2
	local minHeight = cardConfig.minHeight or 100

	-- Main card container
	local card = Instance.new("Frame")
	card.Name = (title and title:gsub("[^%w]", "") or "Card") .. "Container"

	-- Size handling
	if size == "auto" then
		card.Size = UDim2.fromScale(1, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
	elseif size == "full" then
		card.Size = UDim2.fromScale(1, 1)
	elseif typeof(size) == "UDim2" then
		card.Size = size
	else
		card.Size = UDim2.new(1, 0, 0, minHeight)
	end

	card.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	card.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, PANEL_LAYOUTS.section.borderRadius)
	cardCorner.Parent = card

	-- Card padding
	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 12)
	cardPadding.PaddingBottom = UDim.new(0, 12)
	cardPadding.PaddingLeft = UDim.new(0, 12)
	cardPadding.PaddingRight = UDim.new(0, 12)
	cardPadding.Parent = card

	-- Card header (if title provided)
	local headerContainer = nil
	local contentStartY = 0

	if title then
		headerContainer = Instance.new("Frame")
		headerContainer.Name = "Header"
		headerContainer.Size = UDim2.new(1, 0, 0, 28) -- Compact header
		headerContainer.Position = UDim2.fromScale(0, 0)
		headerContainer.BackgroundTransparency = 1
		headerContainer.Parent = card

		local headerLayout = Instance.new("UIListLayout")
		headerLayout.FillDirection = Enum.FillDirection.Horizontal
		headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		headerLayout.Padding = UDim.new(0, 8)
		headerLayout.Parent = headerContainer

		-- Icon (if provided)
		if icon and icon.category and icon.name then
			local _headerIcon = IconManager:CreateIcon(headerContainer, icon.category, icon.name, {
				size = UDim2.fromOffset(22, 22), -- Larger icon for better proportion
				layoutOrder = 1
			})
		end

		-- Title text
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(0, 200, 1, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.RichText = true
		titleLabel.Text = "<b><i>" .. title .. "</i></b>"
		titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
		titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.headings.h3 -- Larger card title
		titleLabel.Font = Config.UI_SETTINGS.typography.fonts.italicBold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center
		titleLabel.LayoutOrder = 2
		titleLabel.Parent = headerContainer

		-- Title stroke
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
		titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
		titleStroke.Parent = titleLabel

		contentStartY = 36 -- Header height + spacing
	end

	-- Content container
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, 0, 1, -contentStartY)
	contentContainer.Position = UDim2.fromOffset(0, contentStartY)
	contentContainer.BackgroundTransparency = 1
	if size == "auto" then
		contentContainer.AutomaticSize = Enum.AutomaticSize.Y
		contentContainer.Size = UDim2.fromScale(1, 0)
	end
	contentContainer.Parent = card

	return {
		card = card,
		content = contentContainer,
		header = headerContainer
	}
end

--[[
	Create a compact panel section with optional header (legacy compatibility)
	@param config: table - Section configuration
	@return: Frame - Section container
--]]
function UIComponents:CreatePanelSection(config)
	local sectionConfig = config or {}
	local parent = sectionConfig.parent
	local title = sectionConfig.title
	local icon = sectionConfig.icon
	local layoutOrder = sectionConfig.layoutOrder or 1
	local fullWidth = sectionConfig.fullWidth ~= false -- Default true

	-- Main section container
	local section = Instance.new("Frame")
	section.Name = (title and title:gsub("[^%w]", "") or "Section") .. "Container"
	section.Size = fullWidth and UDim2.fromScale(1, 0) or UDim2.fromOffset(sectionConfig.width or 200, 0)
	section.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	section.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	section.BorderSizePixel = 0
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.LayoutOrder = layoutOrder
	section.Parent = parent

	local sectionCorner = Instance.new("UICorner")
	sectionCorner.CornerRadius = UDim.new(0, PANEL_LAYOUTS.section.borderRadius)
	sectionCorner.Parent = section

	local currentY = PANEL_LAYOUTS.section.padding

	-- Section header (if title provided)
	if title then
		local headerContainer = Instance.new("Frame")
		headerContainer.Name = "Header"
		headerContainer.Size = UDim2.new(1, -24, 0, PANEL_LAYOUTS.section.headerHeight)
		headerContainer.Position = UDim2.fromOffset(12, 8)
		headerContainer.BackgroundTransparency = 1
		headerContainer.Parent = section

		local headerLayout = Instance.new("UIListLayout")
		headerLayout.FillDirection = Enum.FillDirection.Horizontal
		headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
		headerLayout.Padding = UDim.new(0, 8)
		headerLayout.Parent = headerContainer

		-- Icon (if provided)
		if icon and icon.category and icon.name then
			local _headerIcon = IconManager:CreateIcon(headerContainer, icon.category, icon.name, {
				layoutOrder = 1
			})
		end

		-- Title text
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.new(0, 200, 1, 0) -- Wider for larger text
		titleLabel.BackgroundTransparency = 1
		titleLabel.RichText = true
		titleLabel.Text = "<b><i>" .. title .. "</i></b>"
		titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
		titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.headings.h2 -- Larger section title
		titleLabel.Font = Config.UI_SETTINGS.typography.fonts.italicBold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextYAlignment = Enum.TextYAlignment.Center
		titleLabel.LayoutOrder = 2
		titleLabel.Parent = headerContainer

		-- Title stroke
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
		titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
		titleStroke.Parent = titleLabel

		currentY = currentY + PANEL_LAYOUTS.section.headerHeight + PANEL_LAYOUTS.spacing.item
	end

	-- Content container
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -24, 0, 0)
	contentContainer.Position = UDim2.fromOffset(12, currentY)
	contentContainer.BackgroundTransparency = 1
	contentContainer.AutomaticSize = Enum.AutomaticSize.Y
	contentContainer.Parent = section

	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, PANEL_LAYOUTS.spacing.item)
	contentLayout.Parent = contentContainer

	-- Bottom padding
	local bottomPadding = Instance.new("UIPadding")
	bottomPadding.PaddingBottom = UDim.new(0, PANEL_LAYOUTS.section.padding)
	bottomPadding.Parent = contentContainer

	return {
		section = section,
		content = contentContainer,
		layout = contentLayout
	}
end

--[[
	Create a compact form row (label + control)
	@param config: table - Form row configuration
	@return: Frame - Form row container
--]]
function UIComponents:CreateFormRow(config)
	local rowConfig = config or {}
	local parent = rowConfig.parent
	local label = rowConfig.label
	local control = rowConfig.control -- Pre-created control element
	local layoutOrder = rowConfig.layoutOrder or 1
	local fullWidth = rowConfig.fullWidth ~= false

	-- Form row container
	local formRow = Instance.new("Frame")
	formRow.Name = (label and label:gsub("[^%w]", "") or "FormRow") .. "Container"
	formRow.Size = fullWidth and UDim2.new(1, 0, 0, PANEL_LAYOUTS.formRow.height) or
					UDim2.fromOffset(rowConfig.width or 300, PANEL_LAYOUTS.formRow.height)
	formRow.BackgroundTransparency = 1
	formRow.LayoutOrder = layoutOrder
	formRow.Parent = parent

	local labelFrame = nil
	-- Label
	if label then
		labelFrame = Instance.new("TextLabel")
		labelFrame.Name = "Label"
		labelFrame.Size = UDim2.new(PANEL_LAYOUTS.formRow.labelWidth, -PANEL_LAYOUTS.formRow.spacing, 1, 0)
		labelFrame.Position = UDim2.fromScale(0, 0)
		labelFrame.BackgroundTransparency = 1
		labelFrame.Text = label
		labelFrame.TextColor3 = Config.UI_SETTINGS.colors.text
		labelFrame.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		labelFrame.Font = Config.UI_SETTINGS.typography.fonts.regular
		labelFrame.TextXAlignment = Enum.TextXAlignment.Left
		labelFrame.TextYAlignment = Enum.TextYAlignment.Center
		labelFrame.Parent = formRow
	end

	-- Control container
	local controlContainer = Instance.new("Frame")
	controlContainer.Name = "ControlContainer"
	controlContainer.Size = UDim2.fromScale(1 - PANEL_LAYOUTS.formRow.labelWidth, 1)
	controlContainer.Position = UDim2.fromScale(PANEL_LAYOUTS.formRow.labelWidth, 0)
	controlContainer.BackgroundTransparency = 1
	controlContainer.Parent = formRow

	-- Add control if provided
	if control then
		control.Parent = controlContainer
		-- Adjust control size to fit container
		control.Size = UDim2.fromScale(1, 1)
		control.Position = UDim2.fromScale(0, 0)
	end

	return {
		row = formRow,
		controlContainer = controlContainer,
		labelFrame = labelFrame
	}
end

--[[
	Create a toggle switch component
	@param config: table - Toggle configuration
		- parent: Instance - Parent container
		- label: string - Toggle label text
		- enabled: boolean - Initial enabled state
		- callback: function - State change callback
		- layoutOrder: number - Layout order
		- size: string - "small", "medium", "large"
	@return: table - Toggle instance with setEnabled/getEnabled methods
--]]
function UIComponents:CreateToggleSwitch(config)
	local toggleConfig = config or {}
	local parent = toggleConfig.parent
	local label = toggleConfig.label or "Toggle"
	local enabled = toggleConfig.enabled or false
	local callback = toggleConfig.callback
	local layoutOrder = toggleConfig.layoutOrder or 1
	local size = toggleConfig.size or "medium"

	-- Size configurations
	local sizes = {
		small = {width = 40, height = 20, knobSize = 16},
		medium = {width = 50, height = 25, knobSize = 21},
		large = {width = 60, height = 30, knobSize = 26}
	}
	local sizeConfig = sizes[size] or sizes.medium

	local container = Instance.new("Frame")
	container.Name = label .. "Container"
	container.Size = UDim2.new(1, 0, 0, math.max(35, sizeConfig.height + 10))
	container.BackgroundTransparency = 1
	container.LayoutOrder = layoutOrder
	container.Parent = parent

	-- Label text
	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.fromScale(0.7, 1)
	labelText.BackgroundTransparency = 1
	labelText.Text = label
	labelText.TextColor3 = Config.UI_SETTINGS.colors.text
	labelText.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	labelText.Font = Config.UI_SETTINGS.typography.fonts.regular
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextYAlignment = Enum.TextYAlignment.Center
	labelText.Parent = container

	-- Toggle background
	local toggleBg = Instance.new("Frame")
	toggleBg.Size = UDim2.fromOffset(sizeConfig.width, sizeConfig.height)
	toggleBg.Position = UDim2.new(1, -sizeConfig.width - 10, 0.5, -sizeConfig.height/2)
	toggleBg.BackgroundColor3 = enabled and Config.UI_SETTINGS.colors.semantic.button.success or Config.UI_SETTINGS.colors.backgroundSecondary
	toggleBg.BorderSizePixel = 0
	toggleBg.Parent = container

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(0, sizeConfig.height/2)
	toggleCorner.Parent = toggleBg

	-- Toggle handle
	local toggleHandle = Instance.new("Frame")
	toggleHandle.Size = UDim2.fromOffset(sizeConfig.knobSize, sizeConfig.knobSize)
	toggleHandle.Position = enabled and
		UDim2.new(1, -sizeConfig.knobSize - 2, 0.5, -sizeConfig.knobSize/2) or
		UDim2.new(0, 2, 0.5, -sizeConfig.knobSize/2)
	toggleHandle.BackgroundColor3 = Config.UI_SETTINGS.colors.text
	toggleHandle.BorderSizePixel = 0
	toggleHandle.Parent = toggleBg

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, sizeConfig.knobSize/2)
	handleCorner.Parent = toggleHandle

	local currentEnabled = enabled

	local function updateToggle(newEnabled, silent)
		currentEnabled = newEnabled
		local bgColor = newEnabled and Config.UI_SETTINGS.colors.semantic.button.success or Config.UI_SETTINGS.colors.backgroundSecondary
		local handlePos = newEnabled and
			UDim2.new(1, -sizeConfig.knobSize - 2, 0.5, -sizeConfig.knobSize/2) or
			UDim2.new(0, 2, 0.5, -sizeConfig.knobSize/2)

		TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = bgColor}):Play()
		TweenService:Create(toggleHandle, TweenInfo.new(0.2), {Position = handlePos}):Play()

		-- Only trigger callback if not silent update
		if callback and not silent then
			callback(newEnabled)
		end
	end

	-- Click to toggle
	toggleBg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			updateToggle(not currentEnabled)
			if SoundManager then
				SoundManager:PlaySFX("buttonClick")
			end
		end
	end)

	return {
		container = container,
		setEnabled = function(enabled, silent) updateToggle(enabled, silent) end,
		getEnabled = function() return currentEnabled end
	}
end

--[[
	Create a working slider component
	@param config: table - Slider configuration
		- parent: Instance - Parent container
		- label: string - Slider label text
		- value: number - Initial value (0-1)
		- callback: function - Value change callback
		- layoutOrder: number - Layout order
	@return: table - Slider instance with setValue/getValue methods
--]]
function UIComponents:CreateSlider(config)
	local sliderConfig = config or {}
	local parent = sliderConfig.parent
	local label = sliderConfig.label or "Slider"
	local value = sliderConfig.value or 0.5
	local callback = sliderConfig.callback
	local layoutOrder = sliderConfig.layoutOrder or 1

	local container = Instance.new("Frame")
	container.Name = label .. "Container"
	container.Size = UDim2.new(1, 0, 0, 45)
	container.BackgroundTransparency = 1
	container.LayoutOrder = layoutOrder
	container.Parent = parent

	-- Label
	local labelText = Instance.new("TextLabel")
	labelText.Size = UDim2.fromScale(0.3, 1)
	labelText.BackgroundTransparency = 1
	labelText.Text = label
	labelText.TextColor3 = Config.UI_SETTINGS.colors.text
	labelText.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	labelText.Font = Config.UI_SETTINGS.typography.fonts.regular
	labelText.TextXAlignment = Enum.TextXAlignment.Left
	labelText.TextYAlignment = Enum.TextYAlignment.Center
	labelText.Parent = container

	-- Track
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.5, 0, 0, 8)
	track.Position = UDim2.new(0.35, 0, 0.5, -4)
	track.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	track.BorderSizePixel = 0
	track.Parent = container

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	-- Fill
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(value, 1)
	fill.BackgroundColor3 = Config.UI_SETTINGS.colors.accent
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	-- Handle
	local handle = Instance.new("Frame")
	handle.Size = UDim2.fromOffset(20, 20)
	handle.Position = UDim2.new(value, -10, 0.5, -10)
	handle.BackgroundColor3 = Config.UI_SETTINGS.colors.text
	handle.BorderSizePixel = 0
	handle.Parent = track

	local handleCorner = Instance.new("UICorner")
	handleCorner.CornerRadius = UDim.new(0, 10)
	handleCorner.Parent = handle

	-- Value label
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.fromScale(0.15, 1)
	valueLabel.Position = UDim2.fromScale(0.85, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = math.floor(value * 100) .. "%"
	valueLabel.TextColor3 = Config.UI_SETTINGS.colors.accent
	valueLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	valueLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Center
	valueLabel.TextYAlignment = Enum.TextYAlignment.Center
	valueLabel.Parent = container

	-- Interaction state
	local dragging = false
	local currentValue = value

	local function updateSlider(newValue, silent)
		newValue = math.clamp(newValue, 0, 1)
		currentValue = newValue

		fill.Size = UDim2.fromScale(newValue, 1)
		handle.Position = UDim2.new(newValue, -10, 0.5, -10)
		valueLabel.Text = math.floor(newValue * 100) .. "%"

		-- Only trigger callback if not silent update
		if callback and not silent then
			callback(newValue)
		end
	end

	-- Click to set value
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local relativeX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
			updateSlider(relativeX)
			dragging = true
		end
	end)

	-- Drag handle
	local connection
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			connection = InputService.InputChanged:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
					local relativeX = (input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X
					updateSlider(relativeX)
				end
			end)
		end
	end)

	InputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			if connection then
				connection:Disconnect()
			end
		end
	end)

	return {
		container = container,
		setValue = function(newValue, silent) updateSlider(newValue, silent) end,
		getValue = function() return currentValue end
	}
end

--[[
	Create a compact dropdown/selector
	@param config: table - Dropdown configuration
	@return: table - Dropdown components and methods
--]]
function UIComponents:CreateDropdown(config)
	local dropdownConfig = config or {}
	local options = dropdownConfig.options or {"Option 1", "Option 2"}
	local selectedIndex = dropdownConfig.selectedIndex or 1
	local callback = dropdownConfig.callback

	-- Dropdown button
	local dropdownButton = self:CreateButton({
		name = "DropdownButton",
		size = "medium",
		text = options[selectedIndex] or "Select",
		color = "secondary",
		callback = function()
			-- Cycle through options
			selectedIndex = (selectedIndex % #options) + 1
			dropdownButton:SetText(options[selectedIndex])
			if callback then
				callback(options[selectedIndex], selectedIndex)
			end
		end
	})

	return {
		dropdown = dropdownButton.button,
		button = dropdownButton,
		SetSelectedIndex = function(_self, index)
			selectedIndex = math.clamp(index, 1, #options)
			dropdownButton:SetText(options[selectedIndex])
		end,
		GetSelectedIndex = function(_self)
			return selectedIndex
		end,
		GetSelectedValue = function(_self)
			return options[selectedIndex]
		end
	}
end

--[[
	Create a flexbox container for cards
	@param config: table - Flexbox configuration
	@return: Frame - Flexbox container
--]]
function UIComponents:CreateFlexContainer(config)
	local flexConfig = config or {}
	local parent = flexConfig.parent
	local direction = flexConfig.direction or "vertical" -- "vertical", "horizontal", "grid"
	local gap = flexConfig.gap or PANEL_LAYOUTS.spacing.item
	local _wrap = flexConfig.wrap or false

	local container = Instance.new("Frame")
	container.Name = "FlexContainer"
	container.Size = UDim2.fromScale(1, 0)
	container.BackgroundTransparency = 1
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.Parent = parent

	if direction == "grid" then
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = flexConfig.cellSize or UDim2.fromOffset(160, 120)
		gridLayout.CellPadding = UDim2.fromOffset(gap, gap)
		gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = container
	else
		local listLayout = Instance.new("UIListLayout")
		listLayout.SortOrder = Enum.SortOrder.LayoutOrder
		listLayout.Padding = UDim.new(0, gap)
		listLayout.FillDirection = direction == "horizontal" and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
		listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		listLayout.Parent = container
	end

	return container
end

--[[
	Create a properly configured scrolling frame
	@param config: table - Scroll configuration
	@return: table - Scroll components
--]]
function UIComponents:CreateScrollFrame(config)
	local scrollConfig = config or {}
	local parent = scrollConfig.parent
	local size = scrollConfig.size or UDim2.fromScale(1, 1)
	local position = scrollConfig.position or UDim2.fromScale(0, 0)

	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ScrollFrame"
	scrollFrame.Size = size
	scrollFrame.Position = position
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4 -- Very thin scrollbar
	scrollFrame.ScrollBarImageColor3 = Config.UI_SETTINGS.colors.accent
	scrollFrame.ScrollBarImageTransparency = 0.3
	scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
	scrollFrame.CanvasSize = UDim2.fromScale(0, 0) -- Will be updated automatically
	scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scrollFrame.Parent = parent

	-- Content container inside scroll frame
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ScrollContent"
	contentContainer.Size = UDim2.fromScale(1, 0)
	contentContainer.BackgroundTransparency = 1
	contentContainer.AutomaticSize = Enum.AutomaticSize.Y
	contentContainer.Parent = scrollFrame

	-- Content padding
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 12)
	contentPadding.PaddingBottom = UDim.new(0, 12)
	contentPadding.PaddingLeft = UDim.new(0, 12)
	contentPadding.PaddingRight = UDim.new(0, 12)
	contentPadding.Parent = contentContainer

	return {
		scrollFrame = scrollFrame,
		content = contentContainer
	}
end

-- Create quest milestone pill (reusable)
function UIComponents:CreateQuestPill(config)
	local parent = config.parent
	local milestone = config.milestone
	local achieved = config.achieved
	local claimed = config.claimed
	local reward = config.reward or {}
	local onClaim = config.onClaim

	local pill = Instance.new("Frame")
	pill.Name = "QuestPill_" .. tostring(milestone)
	pill.Size = UDim2.fromOffset(180, 40)
	pill.BackgroundColor3 = achieved and (claimed and Color3.fromRGB(50, 90, 50) or Config.UI_SETTINGS.colors.semantic.button.success) or Config.UI_SETTINGS.colors.semantic.button.secondary
	pill.BackgroundTransparency = achieved and 0 or 0.2
	pill.BorderSizePixel = 0
	pill.Parent = parent

	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 10)
	pc.Parent = pill

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = pill

	local top = Instance.new("TextLabel")
	top.Size = UDim2.new(1, -10, 0, 18)
	top.Position = UDim2.fromOffset(5, 0)
	top.BackgroundTransparency = 1
	top.Text = tostring(milestone) .. (claimed and " ✔" or "")
	top.TextColor3 = Color3.fromRGB(255,255,255)
	top.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	top.Font = Config.UI_SETTINGS.typography.fonts.bold
	top.TextXAlignment = Enum.TextXAlignment.Left
	top.Parent = pill

	local parts = {}
	if reward.coins then
		table.insert(parts, "+" .. tostring(reward.coins) .. " coins")
	end
	if reward.gems then
		table.insert(parts, "+" .. tostring(reward.gems) .. " gems")
	end
	if reward.experience then
		table.insert(parts, "+" .. tostring(reward.experience) .. " XP")
	end
	if reward.xp then
		table.insert(parts, "+" .. tostring(reward.xp) .. " XP")
	end
	local rewardText = table.concat(parts, "  ")

	local bottom = Instance.new("TextLabel")
	bottom.Size = UDim2.new(1, -10, 0, 14)
	bottom.Position = UDim2.fromOffset(5, 0)
	bottom.BackgroundTransparency = 1
	bottom.Text = rewardText
	bottom.TextColor3 = Color3.fromRGB(230,230,230)
	bottom.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	bottom.Font = Config.UI_SETTINGS.typography.fonts.regular
	bottom.TextXAlignment = Enum.TextXAlignment.Left
	bottom.TextTruncate = Enum.TextTruncate.AtEnd
	bottom.Parent = pill

	if achieved and not claimed then
		local button = self:CreateButton({
			name = "ClaimButton",
			style = "panel",
			size = "small",
			text = "Claim",
			color = "primary",
			parent = pill,
			callback = function()
				if onClaim then
					onClaim()
				end
			end
		})
		button.button.Size = UDim2.fromOffset(64, 22)
	end

	return pill
end

-- Create quest row (reusable)
function UIComponents:CreateQuestRow(config)
	local parent = config.parent
	local displayName = config.displayName
	local mobType = config.mobType
	local kills = config.kills or 0
	local milestones = config.milestones or {}
	local rewards = config.rewards or {}
	local claimedMap = config.claimed or {}
	local onClaim = config.onClaim -- function(milestone)

	local row = Instance.new("Frame")
	row.Name = "QuestRow_" .. tostring(mobType)
	row.Size = UDim2.new(1, 0, 0, 88)
	row.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	row.BackgroundTransparency = Config.UI_SETTINGS.designSystem.transparency.light
	row.BorderSizePixel = 0
	row.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	corner.Parent = row

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = row

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 18)
	header.BackgroundTransparency = 1
	header.Text = displayName .. " • Kills: " .. tostring(kills)
	header.TextColor3 = Config.UI_SETTINGS.colors.text
	header.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	header.Font = Config.UI_SETTINGS.typography.fonts.bold
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Parent = row

	local milestonesContainer = Instance.new("Frame")
	milestonesContainer.Name = "Milestones"
	milestonesContainer.Size = UDim2.new(1, 0, 0, 40)
	milestonesContainer.BackgroundTransparency = 1
	milestonesContainer.Parent = row

	local mlayout = Instance.new("UIListLayout")
	mlayout.FillDirection = Enum.FillDirection.Horizontal
	mlayout.SortOrder = Enum.SortOrder.LayoutOrder
	mlayout.Padding = UDim.new(0, 8)
	mlayout.VerticalAlignment = Enum.VerticalAlignment.Center
	mlayout.Parent = milestonesContainer

	for _, milestone in ipairs(milestones) do
		self:CreateQuestPill({
			parent = milestonesContainer,
			milestone = milestone,
			achieved = kills >= milestone,
			claimed = claimedMap[milestone] == true,
			reward = rewards[milestone] or {},
			onClaim = function()
				if onClaim then
					onClaim()
				end
			end
		})
	end

	return row
end

--[[
	Create a tab bar for filtering content
	@param config: table - Tab bar configuration
	@return: table - Tab bar components and methods
--]]
function UIComponents:CreateTabBar(config)
	local parent = config.parent
	local tabs = config.tabs or {} -- {text, key, badgeCount?}
	local onTabChanged = config.onTabChanged
	local activeTab = config.activeTab or (tabs[1] and tabs[1].key)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 40)
	tabBar.BackgroundTransparency = 1
	tabBar.Parent = parent

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabLayout.Parent = tabBar

	local tabButtons = {}
	local tabBarObj = {
		frame = tabBar,
		buttons = tabButtons,
		activeTab = activeTab
	}

	local function updateTabStates()
		for key, button in pairs(tabButtons) do
		local isActive = key == tabBarObj.activeTab
		button.BackgroundColor3 = isActive and Config.UI_SETTINGS.colors.primary or Config.UI_SETTINGS.colors.backgroundSecondary
		button.TextColor3 = isActive and Config.UI_SETTINGS.colors.text or Config.UI_SETTINGS.colors.textSecondary
		end
	end

	for i, tab in ipairs(tabs) do
		local tabButton = Instance.new("TextButton")
		tabButton.Name = "Tab_" .. tab.key
		tabButton.Size = UDim2.fromOffset(100, 32)
		tabButton.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		tabButton.BorderSizePixel = 0
		tabButton.Text = tab.text .. (tab.badgeCount and " (" .. tab.badgeCount .. ")" or "")
		tabButton.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
		tabButton.TextSize = 14
		tabButton.Font = Enum.Font.SourceSansBold
		tabButton.LayoutOrder = i
		tabButton.Parent = tabBar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = tabButton

		tabButtons[tab.key] = tabButton

		tabButton.MouseButton1Click:Connect(function()
			tabBarObj.activeTab = tab.key
			updateTabStates()
			if onTabChanged then
				onTabChanged(tab.key)
			end
		end)
	end

	updateTabStates()

	function tabBarObj:SetActiveTab(key)
		self.activeTab = key
		updateTabStates()
	end

	function tabBarObj:UpdateBadge(tabKey, count)
		local button = tabButtons[tabKey]
		if button then
			local baseText = ""
			for _, tab in ipairs(tabs) do
				if tab.key == tabKey then
					baseText = tab.text
					tab.badgeCount = count
					break
				end
			end
			button.Text = baseText .. (count and count > 0 and " (" .. count .. ")" or "")
		end
	end

	return tabBarObj
end

--[[
	Create a quest card component
	@param config: table - Quest card configuration
	@return: Frame - Quest card
--]]
function UIComponents:CreateQuestCard(config)
	local parent = config.parent
	local questData = config.questData or {}
	local questConfig = config.questConfig or {}
	local milestone = config.milestone
	local onClaim = config.onClaim

	local kills = questData.kills or 0
	local claimed = questData.claimed or {}
	-- Server normalizes milestone keys to strings before transmission
	local isClaimable = kills >= milestone and not claimed[tostring(milestone)]
	local isClaimed = claimed[tostring(milestone)] == true

	local card = Instance.new("Frame")
	card.Name = "QuestCard_" .. (questConfig.displayName or "Quest")
	-- Slightly taller to comfortably fit a large left icon
	card.Size = UDim2.new(1, 0, 0, 100)
	card.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = parent

	local cardCorner = Instance.new("UICorner")
	cardCorner.CornerRadius = UDim.new(0, 8)
	cardCorner.Parent = card

	local cardPadding = Instance.new("UIPadding")
	cardPadding.PaddingTop = UDim.new(0, 16)
	cardPadding.PaddingBottom = UDim.new(0, 16)
	cardPadding.PaddingLeft = UDim.new(0, 20)
	cardPadding.PaddingRight = UDim.new(0, 20)
	cardPadding.Parent = card

	-- Layout constants
	local iconWidth = 72
	local gap = 16
	local rightScale = 0.38

	-- Left icon container
	local iconContainer = Instance.new("Frame")
	iconContainer.Name = "IconContainer"
	iconContainer.Size = UDim2.new(0, iconWidth, 1, 0)
	iconContainer.BackgroundTransparency = 1
	iconContainer.Parent = card

	-- Icon background for better visual weight
	local iconBg = Instance.new("Frame")
	iconBg.Name = "IconBg"
	iconBg.Size = UDim2.fromScale(1, 1)
	iconBg.BackgroundColor3 = Config.UI_SETTINGS.colors.background
	iconBg.BackgroundTransparency = 0
	iconBg.BorderSizePixel = 0
	iconBg.Parent = iconContainer

	local iconBgCorner = Instance.new("UICorner")
	iconBgCorner.CornerRadius = UDim.new(0, 8)
	iconBgCorner.Parent = iconBg

	-- Pick icon from config if available, else fallback
	local iconCategory = (questConfig.icon and questConfig.icon.category) or questConfig.iconCategory or "General"
	local iconName = (questConfig.icon and questConfig.icon.name) or questConfig.iconName or "Skull"
	local _iconColor = (questConfig.icon and questConfig.icon.color)

	IconManager:CreateIcon(iconBg, iconCategory, iconName, {
		size = "hero",
		position = UDim2.fromScale(0.5, 0.5),
		anchorPoint = Vector2.new(0.5, 0.5),
	})

	-- Middle section: Title and progress
	local leftSection = Instance.new("Frame")
	leftSection.Name = "LeftSection"
	leftSection.Position = UDim2.fromOffset(iconWidth + gap, 0)
	leftSection.Size = UDim2.new(1 - rightScale, - (iconWidth + gap), 1, 0)
	leftSection.BackgroundTransparency = 1
	leftSection.Parent = card

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 20)
	title.BackgroundTransparency = 1
	title.Text = (questConfig.displayName or "Quest") .. " - " .. milestone .. " kills"
	title.TextColor3 = Config.UI_SETTINGS.colors.text
	title.TextSize = Config.UI_SETTINGS.typography.sizes.headings.h4
	title.Font = Config.UI_SETTINGS.typography.fonts.bold
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = leftSection

	local progress = Instance.new("TextLabel")
	progress.Name = "Progress"
	progress.Size = UDim2.new(1, 0, 0, 16)
	progress.Position = UDim2.fromOffset(0, 24)
	progress.BackgroundTransparency = 1
	progress.Text = "Progress: " .. kills .. "/" .. milestone
	progress.TextColor3 = isClaimable and Config.UI_SETTINGS.colors.semantic.button.success or Config.UI_SETTINGS.colors.textMuted
	progress.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
	progress.Font = Config.UI_SETTINGS.typography.fonts.regular
	progress.TextXAlignment = Enum.TextXAlignment.Left
	progress.Parent = leftSection

	-- Progress bar
	local progressBarBg = Instance.new("Frame")
	progressBarBg.Name = "ProgressBarBg"
	progressBarBg.Size = UDim2.new(1, 0, 0, 4)
	progressBarBg.Position = UDim2.fromOffset(0, 44)
	progressBarBg.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.borders.subtle
	progressBarBg.BorderSizePixel = 0
	progressBarBg.Parent = leftSection

	local progressBarCorner = Instance.new("UICorner")
	progressBarCorner.CornerRadius = UDim.new(0, 2)
	progressBarCorner.Parent = progressBarBg

	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(math.min(kills / milestone, 1), 0, 1, 0)
	progressBar.BackgroundColor3 = isClaimable and Config.UI_SETTINGS.colors.semantic.button.success or Config.UI_SETTINGS.colors.primary
	progressBar.BorderSizePixel = 0
	progressBar.Parent = progressBarBg

	local progressBarFillCorner = Instance.new("UICorner")
	progressBarFillCorner.CornerRadius = UDim.new(0, 2)
	progressBarFillCorner.Parent = progressBar

	-- Right section: Rewards and claim button
	local rightSection = Instance.new("Frame")
	rightSection.Name = "RightSection"
	rightSection.Size = UDim2.fromScale(rightScale, 1)
	rightSection.Position = UDim2.fromScale(1 - rightScale, 0)
	rightSection.BackgroundTransparency = 1
	rightSection.Parent = card

	-- Rewards display with icons
	-- questConfig comes from server and should contain the full mob config including rewards
	-- Server sends milestone keys as strings, so convert milestone to string for lookup
	local rewards = questConfig.rewards and questConfig.rewards[tostring(milestone)] or {}

	-- Create reward container positioned above the claim button (aligned with button)
	local rewardContainer = Instance.new("Frame")
	rewardContainer.Name = "RewardContainer"
	rewardContainer.Size = UDim2.fromOffset(120, 18)
	rewardContainer.Position = UDim2.new(1, -120, 1, -65)
	rewardContainer.BackgroundTransparency = 1
	rewardContainer.Parent = rightSection

	local rewardLayout = Instance.new("UIListLayout")
	rewardLayout.FillDirection = Enum.FillDirection.Horizontal
	rewardLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rewardLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rewardLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardLayout.Padding = UDim.new(0, 6)
	rewardLayout.Parent = rewardContainer

	-- Add reward items
	local rewardOrder = 1
	if rewards.coins then
		-- Create coin icon
		local coinIcon = IconManager:CreateIcon(rewardContainer, "Currency", "Cash", {
			size = UDim2.fromOffset(14, 14)
		})
		if coinIcon then
			coinIcon.LayoutOrder = rewardOrder
		end
		rewardOrder = rewardOrder + 1

		-- Create coin amount label
		local coinLabel = Instance.new("TextLabel")
		coinLabel.Name = "CoinsAmount"
		coinLabel.Size = UDim2.fromOffset(0, 18)
		coinLabel.AutomaticSize = Enum.AutomaticSize.X
		coinLabel.BackgroundTransparency = 1
		coinLabel.Text = tostring(rewards.coins)
		coinLabel.TextColor3 = Config.UI_SETTINGS.colors.text
		coinLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		coinLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
		coinLabel.TextXAlignment = Enum.TextXAlignment.Left
		coinLabel.LayoutOrder = rewardOrder
		coinLabel.Parent = rewardContainer
		rewardOrder = rewardOrder + 1
	end

	if rewards.gems then
		-- Create gem icon
		local gemIcon = IconManager:CreateIcon(rewardContainer, "Currency", "Gem", {
			size = UDim2.fromOffset(14, 14)
		})
		if gemIcon then
			gemIcon.LayoutOrder = rewardOrder
		end
		rewardOrder = rewardOrder + 1

		-- Create gem amount label
		local gemLabel = Instance.new("TextLabel")
		gemLabel.Name = "GemsAmount"
		gemLabel.Size = UDim2.fromOffset(0, 18)
		gemLabel.AutomaticSize = Enum.AutomaticSize.X
		gemLabel.BackgroundTransparency = 1
		gemLabel.Text = tostring(rewards.gems)
		gemLabel.TextColor3 = Config.UI_SETTINGS.colors.text
		gemLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		gemLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
		gemLabel.TextXAlignment = Enum.TextXAlignment.Left
		gemLabel.LayoutOrder = rewardOrder
		gemLabel.Parent = rewardContainer
		rewardOrder = rewardOrder + 1
	end


	-- Claim button
	local claimButton = Instance.new("TextButton")
	claimButton.Name = "ClaimButton"
	claimButton.Size = UDim2.fromOffset(100, 36)
	claimButton.Position = UDim2.new(1, -100, 1, -40)
	claimButton.BorderSizePixel = 0
	claimButton.TextSize = Config.UI_SETTINGS.typography.sizes.ui.button
	claimButton.Font = Config.UI_SETTINGS.typography.fonts.bold
	claimButton.Parent = rightSection

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, 6)
	buttonCorner.Parent = claimButton

	-- Set button state
	if isClaimed then
		claimButton.Text = "Claimed"
		claimButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
		claimButton.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
		claimButton.Active = false
	elseif isClaimable then
		claimButton.Text = "Claim"
		claimButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.success
		claimButton.TextColor3 = Config.UI_SETTINGS.colors.text
		claimButton.Active = true
		claimButton.MouseButton1Click:Connect(function()
			-- Immediate visual feedback - disable button to prevent double-clicking
			claimButton.Text = "Collecting..."
			claimButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.secondary
			claimButton.TextColor3 = Config.UI_SETTINGS.colors.textMuted
			claimButton.Active = false

			if onClaim then
				onClaim()
			end
		end)
	else
		claimButton.Text = "Not Ready"
		claimButton.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.button.secondary
		claimButton.TextColor3 = Config.UI_SETTINGS.colors.textMuted
		claimButton.Active = false
	end

	return card
end

--[[
	Initialize the UIComponents system
--]]
function UIComponents:Initialize()
	-- Initialize tooltip container
	self:InitializeTooltips()
end

--[[
	Initialize tooltip system
--]]
function UIComponents:InitializeTooltips()
	-- Create tooltip container if it doesn't exist
	if not tooltipContainer then
		tooltipContainer = Instance.new("ScreenGui")
		tooltipContainer.Name = "TooltipContainer"
		tooltipContainer.DisplayOrder = 9999 -- Very high priority to appear above all UI
		tooltipContainer.IgnoreGuiInset = true
		tooltipContainer.Parent = playerGui
	end
end

--[[
	Create and show tooltip for an element
	@param config: table - Tooltip configuration
	@return: Frame - Created tooltip frame
--]]
function UIComponents:ShowTooltip(config)
	local tooltipConfig = config or {}
	local targetElement = tooltipConfig.target
	local content = tooltipConfig.content or {}
	local position = tooltipConfig.position -- Optional manual position

	if not targetElement then
		warn("UIComponents: ShowTooltip requires a target element")
		return
	end

	-- Cancel any pending hide operation
	if hideTooltipDebounce then
		task.cancel(hideTooltipDebounce)
		hideTooltipDebounce = nil
	end

	-- If tooltip is already showing for this element, don't recreate
	if activeTooltip and activeTooltipTarget == targetElement then
		return activeTooltip
	end

	-- Hide existing tooltip immediately (no animation to prevent flicker)
	if activeTooltip then
		activeTooltip:Destroy()
		activeTooltip = nil
		activeTooltipTarget = nil
	end

	-- Create tooltip frame (initially invisible)
	local tooltipFrame = Instance.new("Frame")
	tooltipFrame.Name = "Tooltip"
	tooltipFrame.Size = UDim2.fromOffset(280, 0) -- Width fixed, height auto-calculated
	tooltipFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.semantic.backgrounds.panel
	tooltipFrame.BackgroundTransparency = 0 -- Normal opacity
	tooltipFrame.BorderSizePixel = 0
	tooltipFrame.AutomaticSize = Enum.AutomaticSize.Y
	tooltipFrame.Visible = false -- Start invisible to prevent flicker
	tooltipFrame.ZIndex = 10000 -- Very high ZIndex to appear above everything
	tooltipFrame.Parent = tooltipContainer

	-- Rounded corners
	local tooltipCorner = Instance.new("UICorner")
	tooltipCorner.CornerRadius = UDim.new(0, Config.UI_SETTINGS.designSystem.borderRadius.md)
	tooltipCorner.Parent = tooltipFrame

	-- Border
	local tooltipBorder = Instance.new("UIStroke")
	tooltipBorder.Color = Config.UI_SETTINGS.colors.semantic.borders.default
	tooltipBorder.Thickness = 1
	tooltipBorder.Transparency = Config.UI_SETTINGS.designSystem.transparency.subtle
	tooltipBorder.Parent = tooltipFrame

	-- Content container
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.fromScale(1, 0)
	contentContainer.BackgroundTransparency = 1
	contentContainer.AutomaticSize = Enum.AutomaticSize.Y
	contentContainer.ZIndex = 10001 -- Higher than tooltip frame
	contentContainer.Parent = tooltipFrame

	-- Content padding
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 12)
	contentPadding.PaddingBottom = UDim.new(0, 12)
	contentPadding.PaddingLeft = UDim.new(0, 16)
	contentPadding.PaddingRight = UDim.new(0, 16)
	contentPadding.Parent = contentContainer

	-- Content layout
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, 8)
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	contentLayout.Parent = contentContainer

	-- Build tooltip content
	self:BuildTooltipContent(contentContainer, content)

	-- Position tooltip after content is built
	if position then
		tooltipFrame.Position = position
		-- Show entire tooltip at once
		tooltipFrame.Visible = true
	else
		-- Position automatically based on target element
		task.spawn(function()
			-- Wait one frame for size calculation
			task.wait()

			local targetPosition = targetElement.AbsolutePosition
			local targetSize = targetElement.AbsoluteSize
			local tooltipSize = tooltipFrame.AbsoluteSize
			local screenSize = workspace.CurrentCamera.ViewportSize

			-- Calculate preferred position (to the right of the target)
			local preferredX = targetPosition.X + targetSize.X + 10
			local preferredY = targetPosition.Y

			-- Adjust if tooltip would go off-screen
			if preferredX + tooltipSize.X > screenSize.X then
				-- Position to the left instead
				preferredX = targetPosition.X - tooltipSize.X - 10
			end

			if preferredY + tooltipSize.Y > screenSize.Y then
				-- Position above the target
				preferredY = targetPosition.Y - tooltipSize.Y - 10
			end

			-- Ensure tooltip stays on screen
			preferredX = math.max(10, math.min(preferredX, screenSize.X - tooltipSize.X - 10))
			preferredY = math.max(10, math.min(preferredY, screenSize.Y - tooltipSize.Y - 10))

			tooltipFrame.Position = UDim2.fromOffset(preferredX, preferredY)

			-- Show entire tooltip at once
			tooltipFrame.Visible = true
		end)
	end

	activeTooltip = tooltipFrame
	activeTooltipTarget = targetElement
	return tooltipFrame
end

--[[
	Hide active tooltip
	@param immediate: boolean - Whether to hide immediately without debouncing (default: false)
--]]
function UIComponents:HideTooltip(immediate)
	-- Cancel any existing hide debounce
	if hideTooltipDebounce then
		task.cancel(hideTooltipDebounce)
		hideTooltipDebounce = nil
	end

	if not activeTooltip then
		return
	end

	if immediate then
		-- Hide immediately without animation
		activeTooltip:Destroy()
		activeTooltip = nil
		activeTooltipTarget = nil
	else
		-- Add a small delay to prevent flickering when moving between nearby elements
		hideTooltipDebounce = task.spawn(function()
			task.wait(0.1) -- Small delay to prevent flicker
			if activeTooltip then
				-- Hide immediately - no animation needed
				activeTooltip:Destroy()
				activeTooltip = nil
				activeTooltipTarget = nil
			end
			hideTooltipDebounce = nil
		end)
	end
end

--[[
	Build tooltip content from configuration
	@param container: Frame - Content container
	@param content: table - Content configuration
--]]
function UIComponents:BuildTooltipContent(container, content)
	local layoutOrder = 1

	-- Title
	if content.title then
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Name = "Title"
		titleLabel.Size = UDim2.fromScale(1, 0)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Text = content.title
		titleLabel.TextColor3 = Config.UI_SETTINGS.titleLabel.textColor
		titleLabel.TextSize = Config.UI_SETTINGS.typography.sizes.headings.h3
		titleLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
		titleLabel.TextXAlignment = Enum.TextXAlignment.Left
		titleLabel.TextYAlignment = Enum.TextYAlignment.Top
		titleLabel.TextWrapped = true
		titleLabel.AutomaticSize = Enum.AutomaticSize.Y
		titleLabel.ZIndex = 10002 -- High ZIndex for text
		titleLabel.LayoutOrder = layoutOrder
		titleLabel.Parent = container

		-- Title stroke
		local titleStroke = Instance.new("UIStroke")
		titleStroke.Color = Config.UI_SETTINGS.titleLabel.stroke.color
		titleStroke.Thickness = Config.UI_SETTINGS.titleLabel.stroke.thickness
		titleStroke.Parent = titleLabel

		layoutOrder = layoutOrder + 1
	end

	-- Description
	if content.description then
		local descLabel = Instance.new("TextLabel")
		descLabel.Name = "Description"
		descLabel.Size = UDim2.fromScale(1, 0)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = content.description
		descLabel.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
		descLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		descLabel.Font = Config.UI_SETTINGS.typography.fonts.regular
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextYAlignment = Enum.TextYAlignment.Top
		descLabel.TextWrapped = true
		descLabel.AutomaticSize = Enum.AutomaticSize.Y
		descLabel.ZIndex = 10002 -- High ZIndex for text
		descLabel.LayoutOrder = layoutOrder
		descLabel.Parent = container
		layoutOrder = layoutOrder + 1
	end

	-- Status
	if content.status then
		local statusContainer = Instance.new("Frame")
		statusContainer.Name = "Status"
		statusContainer.Size = UDim2.new(1, 0, 0, 24)
		statusContainer.BackgroundTransparency = 1
		statusContainer.ZIndex = 10002 -- High ZIndex for status elements
		statusContainer.LayoutOrder = layoutOrder
		statusContainer.Parent = container

		local statusLayout = Instance.new("UIListLayout")
		statusLayout.FillDirection = Enum.FillDirection.Horizontal
		statusLayout.SortOrder = Enum.SortOrder.LayoutOrder
		statusLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		statusLayout.Padding = UDim.new(0, 8)
		statusLayout.Parent = statusContainer

		-- Status indicator
		local statusIndicator = Instance.new("Frame")
		statusIndicator.Name = "StatusIndicator"
		statusIndicator.Size = UDim2.fromOffset(8, 8)
		-- Better status color detection
		local statusColor = Config.UI_SETTINGS.colors.semantic.game.coins -- Default to green (available)
		if content.status and (content.status:lower():find("placed") or content.status:lower():find("dungeon")) then
			statusColor = Config.UI_SETTINGS.colors.semantic.game.experience -- Orange for placed
		end
		statusIndicator.BackgroundColor3 = statusColor
		statusIndicator.BorderSizePixel = 0
		statusIndicator.ZIndex = 10003 -- Higher ZIndex for indicator
		statusIndicator.LayoutOrder = 1
		statusIndicator.Parent = statusContainer

		local indicatorCorner = Instance.new("UICorner")
		indicatorCorner.CornerRadius = UDim.new(0.5, 0)
		indicatorCorner.Parent = statusIndicator

		-- Status text
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "StatusText"
		statusLabel.Size = UDim2.fromOffset(0, 24)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = content.status
		statusLabel.TextColor3 = Config.UI_SETTINGS.colors.text
		statusLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
		statusLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
		statusLabel.TextXAlignment = Enum.TextXAlignment.Left
		statusLabel.TextYAlignment = Enum.TextYAlignment.Center
		statusLabel.AutomaticSize = Enum.AutomaticSize.X
		statusLabel.ZIndex = 10003 -- Higher ZIndex for text
		statusLabel.LayoutOrder = 2
		statusLabel.Parent = statusContainer

		layoutOrder = layoutOrder + 1
	end

	-- Properties list
	if content.properties and #content.properties > 0 then
		for i, property in ipairs(content.properties) do
			local propertyContainer = Instance.new("Frame")
			propertyContainer.Name = "Property" .. i
			propertyContainer.Size = UDim2.new(1, 0, 0, 20)
			propertyContainer.BackgroundTransparency = 1
			propertyContainer.ZIndex = 10002 -- High ZIndex for property containers
			propertyContainer.LayoutOrder = layoutOrder
			propertyContainer.Parent = container

			-- Property name
			local propertyName = Instance.new("TextLabel")
			propertyName.Name = "PropertyName"
			propertyName.Size = UDim2.fromScale(0.6, 1)
			propertyName.BackgroundTransparency = 1
			propertyName.Text = property.name .. ":"
			propertyName.TextColor3 = Config.UI_SETTINGS.colors.textSecondary
			propertyName.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
			propertyName.Font = Config.UI_SETTINGS.typography.fonts.regular
			propertyName.TextXAlignment = Enum.TextXAlignment.Left
			propertyName.TextYAlignment = Enum.TextYAlignment.Center
			propertyName.ZIndex = 10003 -- Higher ZIndex for text
			propertyName.Parent = propertyContainer

			-- Property value
			local propertyValue = Instance.new("TextLabel")
			propertyValue.Name = "PropertyValue"
			propertyValue.Size = UDim2.fromScale(0.4, 1)
			propertyValue.Position = UDim2.fromScale(0.6, 0)
			propertyValue.BackgroundTransparency = 1
			propertyValue.Text = tostring(property.value)
			propertyValue.TextColor3 = property.color or Config.UI_SETTINGS.colors.text
			propertyValue.TextSize = Config.UI_SETTINGS.typography.sizes.body.base
			propertyValue.Font = Config.UI_SETTINGS.typography.fonts.bold
			propertyValue.TextXAlignment = Enum.TextXAlignment.Right
			propertyValue.TextYAlignment = Enum.TextYAlignment.Center
			propertyValue.ZIndex = 10003 -- Higher ZIndex for text
			propertyValue.Parent = propertyContainer

			layoutOrder = layoutOrder + 1
		end
	end
end



--[[
	Position tooltip relative to target element
	@param tooltipFrame: Frame - Tooltip frame
	@param targetElement: GuiObject - Target element
--]]
function UIComponents:PositionTooltip(tooltipFrame, targetElement)
	-- Wait for tooltip to calculate its size
	task.wait()

	local targetPosition = targetElement.AbsolutePosition
	local targetSize = targetElement.AbsoluteSize
	local tooltipSize = tooltipFrame.AbsoluteSize
	local screenSize = workspace.CurrentCamera.ViewportSize

	-- Calculate preferred position (to the right of the target)
	local preferredX = targetPosition.X + targetSize.X + 10
	local preferredY = targetPosition.Y

	-- Adjust if tooltip would go off-screen
	if preferredX + tooltipSize.X > screenSize.X then
		-- Position to the left instead
		preferredX = targetPosition.X - tooltipSize.X - 10
	end

	if preferredY + tooltipSize.Y > screenSize.Y then
		-- Position above the target
		preferredY = targetPosition.Y - tooltipSize.Y - 10
	end

	-- Ensure tooltip stays on screen
	preferredX = math.max(10, math.min(preferredX, screenSize.X - tooltipSize.X - 10))
	preferredY = math.max(10, math.min(preferredY, screenSize.Y - tooltipSize.Y - 10))

	tooltipFrame.Position = UDim2.fromOffset(preferredX, preferredY)
end

--[[
	Add tooltip to element
	@param element: GuiObject - Element to add tooltip to
	@param content: table - Tooltip content configuration
	@return: Connection - Connection objects for cleanup
--]]
function UIComponents:AddTooltip(element, content)
	if not element then
		warn("UIComponents: AddTooltip requires an element")
		return
	end

	local hoverConnection = nil
	local leaveConnection = nil
	local clickConnection = nil
	local elementDebounce = nil

	-- Detect device type for interaction handling
	local function isMobile()
		return InputService.TouchEnabled and not InputService.KeyboardEnabled
	end

	if isMobile() then
		-- Mobile: tap to show/hide tooltip
		clickConnection = element.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				if activeTooltip then
					self:HideTooltip(true) -- Immediate hide for mobile
				else
					self:ShowTooltip({
						target = element,
						content = content
					})
				end
			end
		end)
	else
		-- Desktop: hover to show/hide tooltip with debouncing
		hoverConnection = element.MouseEnter:Connect(function()
			-- Cancel any existing debounce for this element
			if elementDebounce then
				task.cancel(elementDebounce)
				elementDebounce = nil
			end

			-- Show tooltip with a very small delay to prevent rapid firing
			elementDebounce = task.spawn(function()
				task.wait(0.05) -- Small delay to debounce rapid hover events
				self:ShowTooltip({
					target = element,
					content = content
				})
				elementDebounce = nil
			end)
		end)

		leaveConnection = element.MouseLeave:Connect(function()
			-- Cancel any pending show operation
			if elementDebounce then
				task.cancel(elementDebounce)
				elementDebounce = nil
			end

			-- Hide with debouncing (allows smooth transition between nearby elements)
			self:HideTooltip(false) -- Use debounced hide
		end)
	end

	-- Return connections for cleanup
	return {
		hover = hoverConnection,
		leave = leaveConnection,
		click = clickConnection,
				cleanup = function()
			-- Clean up any pending debounce operations
			if elementDebounce then
				task.cancel(elementDebounce)
				elementDebounce = nil
			end

			if hoverConnection then
				hoverConnection:Disconnect()
			end
			if leaveConnection then
				leaveConnection:Disconnect()
			end
			if clickConnection then
				clickConnection:Disconnect()
			end
		end
	}
end



--[[
	Create a reusable currency display component with GameState integration
	@param config: table - Currency display configuration
		- parent: Instance - Parent container
		- currencies: table - Array of currency types to display (e.g., {"coins", "gems"})
		- layoutOrder: number - Layout order
		- style: string - "topbar" (horizontal) or "vertical" (stacked)
	@return: table - CurrencyDisplay instance with update methods
--]]
function UIComponents:CreateCurrencyDisplay(config)
	local currencyConfig = config or {}
	local parent = currencyConfig.parent
	local currencies = currencyConfig.currencies or {"coins", "gems"}
	local layoutOrder = currencyConfig.layoutOrder or 1
	local style = currencyConfig.style or "topbar"

	-- Currency icon mappings
	local CURRENCY_ICONS = {
		coins = {category = "Currency", name = "Cash", color = Config.UI_SETTINGS.colors.semantic.game.coins},
		gems = {category = "Currency", name = "Gem", color = Config.UI_SETTINGS.colors.semantic.game.gems},
		experience = {category = "General", name = "Star", color = Config.UI_SETTINGS.colors.semantic.game.experience}
	}

	-- Currency display names
	local _CURRENCY_NAMES = {
		coins = "Coins",
		gems = "Gems",
		experience = "XP"
	}

	local currencyDisplay = {
		topbar = nil,
		items = {},
		gameStateListener = nil
	}

	-- Build topbar items (original style - no text labels, just icon + value)
	local topbarItems = {}
	for i, currencyType in ipairs(currencies) do
		local iconData = CURRENCY_ICONS[currencyType] or CURRENCY_ICONS.coins

		table.insert(topbarItems, {
			icon = iconData,
			text = "", -- No text label for original style
			value = "0",
			valueColor = Config.UI_SETTINGS.colors.text
		})

		currencyDisplay.items[currencyType] = i
	end

	-- Create the display using existing topbar component with proper sizing
	if style == "topbar" then
		currencyDisplay.topbar = UIComponents:CreateInfoTopbar({
			parent = parent,
			layoutOrder = layoutOrder,
			items = topbarItems,
			-- Make it fit properly in parent container
			size = UDim2.fromScale(1, 1), -- Use full available space
			transparency = 1 -- Transparent background to inherit parent styling
		})
	end

	--[[
		Update currency values
	--]]
	function currencyDisplay:UpdateValues(playerData)
		if not playerData or not self.topbar then
			return
		end

		for currencyType, itemIndex in pairs(self.items) do
			local amount = playerData[currencyType] or 0
			self.topbar:UpdateItem(itemIndex, {
				value = tostring(amount)
			})
		end
	end

	--[[
		Set up automatic GameState integration
	--]]
	function currencyDisplay:EnableAutoUpdate()
		if self.gameStateListener then return end -- Already enabled

		self.gameStateListener = GameState:OnPropertyChanged("playerData", function(newValue, _oldValue, _path)
			if newValue then
				self:UpdateValues(newValue)
			end
		end)

		-- Initial update
		local playerData = GameState:Get("playerData")
		if playerData then
			self:UpdateValues(playerData)
		end
	end

	--[[
		Cleanup
	--]]
	function currencyDisplay:Destroy()
		if self.gameStateListener then
			self.gameStateListener:Disconnect()
			self.gameStateListener = nil
		end
	end

	-- Auto-enable GameState integration by default
	currencyDisplay:EnableAutoUpdate()

	return currencyDisplay
end

--[[
	Create a specialized buy button with currency icon and amount
	@param config: table - Button configuration
	@return: table - Button object with methods
--]]
function UIComponents:CreateBuyButton(config)
	local buttonConfig = config or {}
	local size = buttonConfig.size or "medium"
	local parent = buttonConfig.parent
	local position = buttonConfig.position
	local callback = buttonConfig.callback
	local colorVariant = buttonConfig.color or "primary"
	local currency = buttonConfig.currency or "coins"
	local amount = buttonConfig.amount or 0
	local enabled = buttonConfig.enabled ~= false -- Default true

	local sizeConfig = COMPONENT_CONFIGS.button.sizes[size] or COMPONENT_CONFIGS.button.sizes.medium
	local buttonWidth = sizeConfig.width
	local buttonHeight = sizeConfig.height

	-- Get color from semantic tokens
	local buttonColor = Config.UI_SETTINGS.colors.semantic.button[colorVariant] or buttonConfig.color or Config.UI_SETTINGS.colors.accent
	local _borderColor = Config.UI_SETTINGS.colors.semantic.borders.default

	-- Border frame (acts as the border)
	local borderFrame = Instance.new("Frame")
	borderFrame.Name = (buttonConfig.name or "BuyButton") .. "Border"
	borderFrame.Size = UDim2.fromOffset(buttonWidth + 4, buttonHeight + 4) -- 2px border on all sides
	borderFrame.Position = position and UDim2.new(position.X.Scale, position.X.Offset - 2, position.Y.Scale, position.Y.Offset - 2) or UDim2.fromOffset(-2, -2)
	borderFrame.BackgroundColor3 = Color3.fromRGB(0, 80, 0) -- Dark green border
	borderFrame.BorderSizePixel = 0
	borderFrame.Parent = parent

	local borderCorner = Instance.new("UICorner")
	borderCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.button.borderRadius + 3) -- +2 to border radius
	borderCorner.Parent = borderFrame

	-- Main button (inside the border frame)
	local button = Instance.new("TextButton")
	button.Name = buttonConfig.name or "BuyButton"
	button.Size = UDim2.fromOffset(buttonWidth, buttonHeight)
	button.Position = UDim2.fromOffset(2, 2) -- Offset by border thickness (2px)
	button.BackgroundColor3 = buttonColor
	button.BackgroundTransparency = enabled and Config.UI_SETTINGS.designSystem.transparency.light or Config.UI_SETTINGS.designSystem.transparency.backdrop
	button.Text = "" -- No text, we'll use icons and labels
	button.BorderSizePixel = 0
	button.Active = enabled
	button.AutoButtonColor = false -- Disable default hover effects
	button.Parent = borderFrame

	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(0, COMPONENT_CONFIGS.button.borderRadius + 2) -- +2 to border radius
	buttonCorner.Parent = button

	-- No gradient overlay for BuyButtons - we want clean borders

	-- Create content container for icon and amount
	local contentContainer = Instance.new("Frame")
	contentContainer.Name = "ContentContainer"
	contentContainer.Size = UDim2.fromScale(1, 1)
	contentContainer.BackgroundTransparency = 1
	contentContainer.Parent = button

	-- Horizontal layout for icon and amount
	local contentLayout = Instance.new("UIListLayout")
	contentLayout.FillDirection = Enum.FillDirection.Horizontal
	contentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
	contentLayout.Padding = UDim.new(0, Config.UI_SETTINGS.designSystem.spacing.xs) -- Use design system spacing
	contentLayout.Parent = contentContainer

	-- Create currency icon (reduced size)
	local currencyIcon = IconManager:CreateIcon(contentContainer, "Currency", currency == "coins" and "Cash" or "Gem", {
		size = UDim2.fromOffset(25, 20), -- Reduced from 32 to 24
		layoutOrder = 1
	})

	-- Create amount label with white text
	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "AmountLabel"
	amountLabel.Size = UDim2.fromOffset(0, 1)
	amountLabel.AutomaticSize = Enum.AutomaticSize.X
	amountLabel.BackgroundTransparency = 1
	amountLabel.Text = tostring(amount)
	amountLabel.TextColor3 = Color3.fromRGB(255, 255, 255) -- White text
	amountLabel.TextSize = Config.UI_SETTINGS.typography.sizes.body.large -- Use design system typography
	amountLabel.Font = Config.UI_SETTINGS.typography.fonts.bold
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.TextYAlignment = Enum.TextYAlignment.Center
	amountLabel.LayoutOrder = 2
	amountLabel.Parent = contentContainer

	-- Add text stroke (will be updated by SetTextStrokeColor)
	local textStroke = Instance.new("UIStroke")
	textStroke.Thickness = 2
	textStroke.Color = Color3.fromRGB(30, 120, 30) -- Default dark green stroke
	textStroke.Parent = amountLabel

	-- Store original values for animation reset
	local originalTransparency = enabled and Config.UI_SETTINGS.designSystem.transparency.light or Config.UI_SETTINGS.designSystem.transparency.backdrop
	local originalColor = buttonColor
	local currentFlashTween = nil
	local currentRestoreTween = nil

	-- Add click functionality (flash effect removed)
	if callback then
		-- Simple click handler without flash animation
		button.MouseButton1Down:Connect(function()
			-- selene: allow(empty_if)
			if enabled then
				-- No flash animation - just handle the click
			end
		end)

		-- Reset animation and execute callback on button up
		button.MouseButton1Up:Connect(function()
			if enabled then
				-- Cancel any ongoing animations and immediately reset to original state
				if currentFlashTween then
					currentFlashTween:Cancel()
					currentFlashTween = nil
				end
				if currentRestoreTween then
					currentRestoreTween:Cancel()
					currentRestoreTween = nil
				end

				-- Immediately reset to original state
				button.BackgroundTransparency = originalTransparency
				button.BackgroundColor3 = originalColor

				callback()
			end
		end)
	end

	-- Button object with methods
	local buttonObj = {
		button = button,
		borderFrame = borderFrame, -- Reference to the border frame
		contentContainer = contentContainer,
		currencyIcon = currencyIcon,
		amountLabel = amountLabel,
		textStroke = textStroke, -- Reference to the text stroke
		isAvailable = true, -- Track availability state for hover effects
		originalColor = buttonColor, -- Store original color for hover effects
		originalBorderColor = Color3.fromRGB(0, 80, 0), -- Store original border color for hover effects

		-- Button methods
		SetAmount = function(self, newAmount)
			self.amountLabel.Text = tostring(newAmount)
		end,

		SetCurrency = function(self, newCurrency)
			-- Update icon
			if self.currencyIcon then
				IconManager:ApplyIcon(self.currencyIcon, "Currency", newCurrency == "coins" and "Cash" or "Gem", {
					size = UDim2.fromOffset(25, 20)
				})
			end
		end,

		SetEnabled = function(self, newEnabled)
			enabled = newEnabled
			self.button.Active = enabled
			self.button.BackgroundTransparency = enabled and Config.UI_SETTINGS.designSystem.transparency.light or Config.UI_SETTINGS.designSystem.transparency.backdrop
		end,

		SetAvailable = function(self, available)
			self.isAvailable = available
		end,

		SetText = function(self, text)
			-- For compatibility with existing code, but we'll ignore this since we use amount
			-- Could be used to show "Out of Stock" or "Can't Afford" states
			if text == "Buy" then
				-- Reset to normal state
				self:SetAmount(amount)
			else
				-- Show status text instead of amount
				self.amountLabel.Text = text
			end
		end,

		SetColor = function(self, newColor)
			-- Update button background color and store as original for hover effects
			self.button.BackgroundColor3 = newColor
			self.originalColor = newColor
			-- Also update the local originalColor for animation reset
			originalColor = newColor
		end,

		SetBorderColor = function(self, newColor)
			-- Update button border color using border frame and store as original for hover effects
			self.borderFrame.BackgroundColor3 = newColor
			self.originalBorderColor = newColor
		end,

		SetTextStrokeColor = function(self, newColor)
			-- Update text stroke color
			self.textStroke.Color = newColor
		end,

		SetIconSize = function(self, newSize)
			-- Update icon size
			if self.currencyIcon then
				self.currencyIcon.Size = UDim2.fromOffset(newSize, newSize)
			end
		end,

		Destroy = function(self)
			if self.borderFrame then
				self.borderFrame:Destroy()
			end
		end
	}

	-- Store original colors for hover effects
	local _originalBackgroundColor = buttonColor
	local _originalBorderColor = Color3.fromRGB(0, 80, 0)

	-- Custom hover effects
	button.MouseEnter:Connect(function()
		if buttonObj.isAvailable then
		-- Get current button colors to determine if it's green or red
		local currentBgColor = button.BackgroundColor3
		local _currentBorderColor = borderFrame.BackgroundColor3

			-- Determine if this is a green (available) or red (unavailable) button
			local isGreenButton = currentBgColor.G > currentBgColor.R

			local hoverBackgroundColor, hoverBorderColor

			if isGreenButton then
				-- Dark green hover effect for available buttons
				hoverBackgroundColor = Color3.fromRGB(20, 150, 20) -- Dark green
				hoverBorderColor = Color3.fromRGB(0, 60, 0) -- Darker green border
			else
				-- Dark red hover effect for unavailable buttons (if somehow available)
				hoverBackgroundColor = Color3.fromRGB(150, 20, 20) -- Dark red
				hoverBorderColor = Color3.fromRGB(60, 0, 0) -- Darker red border
			end

			TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverBackgroundColor
			}):Play()

			TweenService:Create(borderFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = hoverBorderColor
			}):Play()
		end
		-- No hover effect for unavailable buttons
	end)

	button.MouseLeave:Connect(function()
		if buttonObj.isAvailable then
		-- Return to original colors stored in the button object
		TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = buttonObj.originalColor
		}):Play()

		TweenService:Create(borderFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = buttonObj.originalBorderColor
		}):Play()
		end
	end)

	return buttonObj
end

--[[
	Create a block viewport preview control for showing a 3D block in UI
	@param config: table
	  - parent: Instance (required)
	  - blockType: string (e.g., "grass", "stone")
	  - size: UDim2
	  - position: UDim2
	  - spin: boolean (default true)
	  - name: string
	@return: table with fields {frame, setBlockType, setSpin, destroy}

 	Usage:
 	local preview = UIComponents:CreateBlockPreview({
 		parent = someParent,
 		blockType = "grass",
 		size = UDim2.fromOffset(128, 128)
 	})
 	-- later
 	preview.setBlockType("stone")
--]]
function UIComponents:CreateBlockPreview(config)
	local previewConfig = config or {}
	local parent = previewConfig.parent
	local size = previewConfig.size or UDim2.fromOffset(120, 120)
	local position = previewConfig.position or UDim2.fromScale(0, 0)
	local spin = previewConfig.spin ~= false

	-- Container to allow borders, labels, etc., if needed later
	local container = Instance.new("Frame")
	container.Name = (previewConfig.name or "BlockPreview") .. "Container"
	container.Size = size
	container.Position = position
	container.BackgroundTransparency = 1
	container.Parent = parent

	-- Create viewport preview
	local preview = ViewportPreview.new({
		parent = container,
		size = UDim2.fromScale(1, 1),
		backgroundColor = Color3.fromRGB(18, 18, 18),
		backgroundTransparency = 0,
		borderRadius = Config.UI_SETTINGS.designSystem.borderRadius.md
	})

	-- Helper to construct a model representing a blockType
	local function buildBlockModel(blockType)
		local BlockVisualRenderer = require(game:GetService("ReplicatedStorage").Shared.BlockSystem.BlockVisualRenderer)
		-- Build a Part using existing renderer into a temporary Folder, then wrap in a Model
		local tmpFolder = Instance.new("Folder")
		local part = BlockVisualRenderer.CreateBlockModel(blockType, Vector3.new(0, 0, 0), tmpFolder)
		if not part then
			tmpFolder:Destroy()
			return nil
		end
		local model = Instance.new("Model")
		model.Name = "BlockModel_" .. blockType
		part.Parent = model
		model.PrimaryPart = part
		tmpFolder:Destroy()
		return model
	end

	local function setBlockType(blockType)
		if not blockType then
			return
		end
		local model = buildBlockModel(blockType)
		preview:SetModel(model)
	end

	-- Initial block type
	if previewConfig.blockType then
		setBlockType(previewConfig.blockType)
	end

	-- Spin control
	preview:SetSpin(spin)

	local api = {
		frame = container,
		setBlockType = setBlockType,
		setSpin = function(_, enabled)
			preview:SetSpin(enabled)
		end,
		destroy = function()
			preview:Destroy()
			if container then
				container:Destroy()
			end
		end
	}

	return api
end

return UIComponents