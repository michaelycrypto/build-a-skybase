--!nonstrict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)

local FONT_FOLDER_NAME = "Fonts"
local DEFAULT_STYLE_NAME = "Normal"
local DEFAULT_PRELOAD_TIMEOUT = 10

local ATTR_FONT_FAMILY = "CustomFontFamily"
local ATTR_FONT_STYLE = "CustomFontStyle"
local ATTR_DESIRED_TRANSPARENCY = "CustomFontDesiredTextTransparency"

local function getXAlignmentMultiplier(alignment)
	if alignment == Enum.TextXAlignment.Left then
		return 0
	elseif alignment == Enum.TextXAlignment.Right then
		return 1
	end

	return 0.5
end

local function getYAlignmentMultiplier(alignment)
	if alignment == Enum.TextYAlignment.Top then
		return 0
	elseif alignment == Enum.TextYAlignment.Bottom then
		return 1
	end

	return 0.5
end

local SUPPORTED_CLASSES = {
	TextLabel = true,
	TextButton = true,
}

local CustomFont = {}
CustomFont.__index = CustomFont

local fontCache = {}
local stateRegistry = setmetatable({}, {__mode = "k"})
local fontsFolder

local logger = Logger:CreateContext("CustomFont")

local function trim(str)
	if typeof(str) ~= "string" then
		return ""
	end

	return str:match("^%s*(.-)%s*$")
end

local function parseFontDescriptor(descriptor)
	if typeof(descriptor) ~= "string" or descriptor == "" then
		return nil, DEFAULT_STYLE_NAME
	end

	local family, style = descriptor:match("^(.-)%s*/%s*(.+)$")
	if family and style then
		return trim(family), trim(style)
	end

	family, style = descriptor:match("^(.-)%s*:%s*(.+)$")
	if family and style then
		return trim(family), trim(style)
	end

	return trim(descriptor), DEFAULT_STYLE_NAME
end

local function getFontsFolder()
	if fontsFolder and fontsFolder.Parent then
		return fontsFolder
	end

	local folder = ReplicatedStorage:FindFirstChild(FONT_FOLDER_NAME)
	if not folder then
		folder = ReplicatedStorage:WaitForChild(FONT_FOLDER_NAME, DEFAULT_PRELOAD_TIMEOUT)
	end

	assert(folder, ("RBX_CustomFont: Missing '%s' folder in ReplicatedStorage"):format(FONT_FOLDER_NAME))
	fontsFolder = folder
	return folder
end

local function normalizeCharacterMap(characters)
	local normalized = {}

	if typeof(characters) ~= "table" then
		return normalized
	end

	for codepoint, glyph in pairs(characters) do
		local numeric = tonumber(codepoint)
		if numeric and typeof(glyph) == "table" then
			normalized[numeric] = {
				atlas = glyph.atlas or 0,
				width = glyph.width or 0,
				height = glyph.height or 0,
				xadvance = glyph.xadvance or 0,
				yoffset = glyph.yoffset or 0,
				x = glyph.x or 0,
				y = glyph.y or 0,
			}
		end
	end

	return normalized
end

local function normalizeKerning(source)
	local normalized = {}

	if typeof(source) ~= "table" then
		return normalized
	end

	local function normalizeOffset(offset)
		if typeof(offset) ~= "table" then
			return nil
		end

		local kernX = offset.kernX or offset.kernx or offset.x or 0
		local kernY = offset.kernY or offset.kerny or offset.y or 0

		if kernX == 0 and kernY == 0 then
			return nil
		end

		return {
			x = kernX,
			y = kernY,
		}
	end

	for left, targets in pairs(source) do
		local leftCode = tonumber(left)
		if leftCode and typeof(targets) == "table" then
			local lookup = {}
			for right, offset in pairs(targets) do
				local rightCode = tonumber(right)
				if rightCode then
					local normalizedOffset = normalizeOffset(offset)
					if normalizedOffset then
						lookup[rightCode] = normalizedOffset
					end
				end
			end

			if next(lookup) then
				normalized[leftCode] = lookup
			end
		end
	end

	return normalized
end

local function normalizeSizeEntry(entry)
	if typeof(entry) ~= "table" then
		return nil
	end

	return {
		characters = normalizeCharacterMap(entry.characters),
		kerning = normalizeKerning(entry.kerning),
		lineHeight = entry.lineHeight or 0,
		firstAdjust = entry.firstAdjust or 0,
	}
end

local function normalizeStyle(styleTable)
	local normalized = {}

	if typeof(styleTable) ~= "table" then
		return normalized
	end

	for sizeKey, sizeEntry in pairs(styleTable) do
		local numericSize = tonumber(sizeKey)
		if numericSize and typeof(sizeEntry) == "table" then
			normalized[numericSize] = normalizeSizeEntry(sizeEntry)
		end
	end

	return normalized
end

local function normalizeFont(fontName, raw)
	assert(typeof(raw) == "table", ("RBX_CustomFont: Font '%s' returned invalid data"):format(fontName))

	local info = raw.font or {}
	local styles = info.styles or {}

	local normalized = {
		name = (info.information and info.information.family) or fontName,
		atlases = {},
		styles = {},
	}

	for index, assetId in ipairs(raw.atlases or {}) do
		normalized.atlases[index] = tostring(assetId)
	end

	for styleName, styleTable in pairs(styles) do
		normalized.styles[styleName] = normalizeStyle(styleTable)
	end

	if not next(normalized.styles) and typeof(styles) == "table" then
		normalized.styles[DEFAULT_STYLE_NAME] = normalizeStyle(styles)
	end

	return normalized
end

local function getFontDefinition(fontName)
	assert(typeof(fontName) == "string" and fontName ~= "", "RBX_CustomFont: font name must be a non-empty string")

	local cached = fontCache[fontName]
	if cached then
		return cached
	end

	local fontModule = getFontsFolder():FindFirstChild(fontName)
	assert(fontModule and fontModule:IsA("ModuleScript"), ("RBX_CustomFont: Font '%s' not found in ReplicatedStorage.%s"):format(fontName, FONT_FOLDER_NAME))

	local ok, data = pcall(require, fontModule)
	assert(ok, ("RBX_CustomFont: Failed to require font '%s': %s"):format(fontName, tostring(data)))

	local normalized = normalizeFont(fontName, data)
	fontCache[fontName] = normalized
	return normalized
end

local function resolveStyle(fontDefinition, requestedStyle)
	if fontDefinition.styles[requestedStyle] then
		return requestedStyle, fontDefinition.styles[requestedStyle]
	end

	if fontDefinition.styles[DEFAULT_STYLE_NAME] then
		return DEFAULT_STYLE_NAME, fontDefinition.styles[DEFAULT_STYLE_NAME]
	end

	for styleName, styleMap in pairs(fontDefinition.styles) do
		return styleName, styleMap
	end

	error(("RBX_CustomFont: Font '%s' has no styles defined"):format(fontDefinition.name))
end

local function resolveSizeEntry(styleMap, targetSize)
	targetSize = math.max(targetSize or 0, 1)

	local closestEntry
	local closestSize
	local smallestDelta = math.huge

	for sizeValue, entry in pairs(styleMap) do
		if typeof(entry) == "table" then
			local delta = math.abs(sizeValue - targetSize)
			if delta < smallestDelta or (delta == smallestDelta and (closestSize == nil or sizeValue > closestSize)) then
				smallestDelta = delta
				closestSize = sizeValue
				closestEntry = entry
			end
		end
	end

	return closestEntry, closestSize
end

local function isTextObject(instance)
	return typeof(instance) == "Instance" and SUPPORTED_CLASSES[instance.ClassName] == true
end

local function createGlyphContainer(instance)
	local container = Instance.new("Frame")
	container.Name = "CustomFontGlyphs"
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = UDim2.fromScale(1, 1)
	container.Position = UDim2.fromScale(0, 0)
	container.ZIndex = instance.ZIndex
	container.Visible = instance.Visible
	container.ClipsDescendants = instance.ClipsDescendants
	container.Active = false
	container.Parent = instance
	return container
end

local function concealNativeText(state)
	local instance = state.instance
	if not instance then
		return
	end

	state.concealGuard = true

	if instance.TextTransparency ~= 1 then
		instance.TextTransparency = 1
	end

	if instance.TextStrokeTransparency ~= 1 then
		instance.TextStrokeTransparency = 1
	end

	state.concealGuard = false
end

local function clampTransparency(value)
	if typeof(value) ~= "number" then
		return 0
	end

	return math.clamp(value, 0, 1)
end

local function updateGlyphAppearance(state)
	local color = state.textColor3 or state.instance.TextColor3
	local transparency = state.textTransparency or 0

	for _, glyph in ipairs(state.activeGlyphs) do
		glyph.ImageColor3 = color
		glyph.ImageTransparency = transparency
	end
end

local function setDesiredTransparency(state, value)
	local instance = state.instance
	if not instance then
		return
	end

	local clamped = clampTransparency(value)
	if state.textTransparency == clamped then
		return
	end

	state.textTransparency = clamped
	instance:SetAttribute(ATTR_DESIRED_TRANSPARENCY, clamped)

	updateGlyphAppearance(state)
end

local function releaseGlyph(state, glyph)
	glyph.Visible = false
	glyph.Parent = nil
	table.insert(state.glyphPool, glyph)
end

local function clearGlyphs(state)
	for index, glyph in ipairs(state.activeGlyphs) do
		releaseGlyph(state, glyph)
		state.activeGlyphs[index] = nil
	end
end

local function acquireGlyph(state)
	local glyph = table.remove(state.glyphPool)
	if not glyph then
		glyph = Instance.new("ImageLabel")
		glyph.Name = "Glyph"
		glyph.BackgroundTransparency = 1
		glyph.BorderSizePixel = 0
		glyph.ScaleType = Enum.ScaleType.Stretch
	end

	glyph.Parent = state.glyphContainer
	return glyph
end

local function getKerningAdjustment(sizeEntry, previousCode, currentCode)
	if not previousCode or not currentCode then
		return 0, 0
	end

	local row = sizeEntry.kerning[previousCode]
	if not row then
		return 0, 0
	end

	local entry = row[currentCode]
	if not entry then
		return 0, 0
	end

	if typeof(entry) == "number" then
		return entry, 0
	end

	return entry.x or 0, entry.y or 0
end

local function planGlyphs(text, sizeEntry, scale, fontDefinition)
	local lines = {}
	local chars = sizeEntry.characters

	local function newLine(index)
		local startX = (sizeEntry.firstAdjust or 0) * scale
		return {
			index = index,
			glyphs = {},
			cursorX = startX,
			startX = startX,
			baseY = 0,
			minX = math.huge,
			maxX = -math.huge,
			minY = math.huge,
			maxY = -math.huge,
			prevCode = nil,
		}
	end

	table.insert(lines, newLine(1))
	local lineIndex = 1
	local totalGlyphs = 0
	local maxWidth = 0

	local iterator = utf8.codes
	local skipNextLineFeed = false

	for _, codepoint in iterator(text) do
		if skipNextLineFeed then
			skipNextLineFeed = false
			if codepoint == 10 then
				continue
			end
		end

		if codepoint == 10 or codepoint == 13 then
			if codepoint == 13 then
				skipNextLineFeed = true
			end

			lineIndex += 1
			table.insert(lines, newLine(lineIndex))
			continue
		end

		local currentLine = lines[#lines]
		local glyphData = chars[codepoint] or chars[32]
		if not glyphData then
			continue
		end

		local kernX, kernY = getKerningAdjustment(sizeEntry, currentLine.prevCode, codepoint)
		kernX *= scale
		kernY *= scale
		currentLine.cursorX += kernX

		local glyphWidth = glyphData.width * scale
		local glyphHeight = glyphData.height * scale
		local glyphX = currentLine.cursorX
		local glyphY = (glyphData.yoffset or 0) * scale + kernY

		currentLine.cursorX += glyphData.xadvance * scale
		currentLine.prevCode = codepoint

		if glyphWidth > 0 and glyphHeight > 0 then
			local atlasIndex = (glyphData.atlas or 0) + 1
			local atlasId = fontDefinition.atlases[atlasIndex]

			if atlasId then
				table.insert(currentLine.glyphs, {
					image = atlasId,
					rectOffset = Vector2.new(glyphData.x, glyphData.y),
					rectSize = Vector2.new(glyphData.width, glyphData.height),
					width = glyphWidth,
					height = glyphHeight,
					x = glyphX,
					y = glyphY,
				})

				currentLine.minX = math.min(currentLine.minX, glyphX)
				currentLine.maxX = math.max(currentLine.maxX, glyphX + glyphWidth)
				currentLine.minY = math.min(currentLine.minY, glyphY)
				currentLine.maxY = math.max(currentLine.maxY, glyphY + glyphHeight)
				totalGlyphs += 1
			end
		end
	end

	for _, line in ipairs(lines) do
		if line.minX == math.huge then
			line.minX = line.startX
			line.maxX = line.cursorX
		end

		if line.minY == math.huge then
			line.minY = 0
			line.maxY = 0
		end

		local glyphWidth = math.max(line.maxX - line.minX, line.cursorX - line.startX)
		line.width = glyphWidth
		maxWidth = math.max(maxWidth, glyphWidth)
	end

	local baseline = -((sizeEntry.firstAdjust or 0) * scale)
	local minY = math.huge
	local maxY = -math.huge

	for _, line in ipairs(lines) do
		line.baseY = baseline
		minY = math.min(minY, baseline + line.minY)
		maxY = math.max(maxY, baseline + line.maxY)

		local lineHeight = math.max(line.maxY - line.minY, 0)
		baseline += lineHeight
	end

	if minY == math.huge then
		minY = 0
	end

	if maxY == -math.huge then
		maxY = 0
	end

	return {
		lines = lines,
		minY = minY,
		maxY = maxY,
		maxWidth = maxWidth,
		totalGlyphs = totalGlyphs,
	}
end

local function applyGlyphPlan(state, plan)
	local label = state.instance
	local color = state.textColor3 or label.TextColor3
	local transparency = state.textTransparency or 0
	local labelWidth = math.abs(label.AbsoluteSize.X)
	local labelHeight = math.abs(label.AbsoluteSize.Y)
	local contentHeight = math.max(plan.maxY - plan.minY, 0)
	local yMultiplier = getYAlignmentMultiplier(label.TextYAlignment)
	local xMultiplier = getXAlignmentMultiplier(label.TextXAlignment)
	local verticalOffset = -plan.minY + (labelHeight - contentHeight) * yMultiplier

	local active = state.activeGlyphs
	local glyphCount = 0

	for _, line in ipairs(plan.lines) do
		local horizontalOffset = -line.minX + (labelWidth - line.width) * xMultiplier
		local lineBaseY = line.baseY

		for _, glyphInfo in ipairs(line.glyphs) do
			glyphCount += 1
			local glyph = active[glyphCount]

			if not glyph then
				glyph = acquireGlyph(state)
				active[glyphCount] = glyph
			end

			glyph.Image = glyphInfo.image
			glyph.ImageRectOffset = glyphInfo.rectOffset
			glyph.ImageRectSize = glyphInfo.rectSize
			glyph.Size = UDim2.fromOffset(math.floor(glyphInfo.width + 0.5), math.floor(glyphInfo.height + 0.5))
			glyph.Position = UDim2.fromOffset(
				math.floor(glyphInfo.x + horizontalOffset + 0.5),
				math.floor(glyphInfo.y + lineBaseY + verticalOffset + 0.5)
			)
			glyph.ZIndex = label.ZIndex
			glyph.Visible = label.Visible
			glyph.ImageColor3 = color
			glyph.ImageTransparency = transparency
		end
	end

	for index = glyphCount + 1, #active do
		local glyph = active[index]
		if glyph then
			releaseGlyph(state, glyph)
			active[index] = nil
		end
	end
end

local function renderState(state)
	local label = state.instance
	local text = label.Text or ""

	if text == "" then
		clearGlyphs(state)
		return
	end

	local styleName, styleMap = resolveStyle(state.fontDefinition, state.styleName)
	state.styleName = styleName

	local sizeEntry, sourceSize = resolveSizeEntry(styleMap, label.TextSize)
	if not sizeEntry then
		clearGlyphs(state)
		return
	end

	local scale = label.TextSize / sourceSize
	local plan = planGlyphs(text, sizeEntry, scale, state.fontDefinition)

	if plan.totalGlyphs == 0 then
		clearGlyphs(state)
		return
	end

	applyGlyphPlan(state, plan)
end

local function queueRender(state)
	if state.renderQueued then
		return
	end

	state.renderQueued = true
	task.defer(function()
		if not stateRegistry[state.instance] then
			return
		end

		state.renderQueued = false
		renderState(state)
	end)
end

local function disconnectState(state)
	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	table.clear(state.connections)
end

local function detachInstance(instance)
	local state = stateRegistry[instance]
	if not state then
		return
	end

	stateRegistry[instance] = nil
	disconnectState(state)
	clearGlyphs(state)

	if state.glyphContainer then
		state.glyphContainer:Destroy()
	end

	if instance then
		instance:SetAttribute(ATTR_FONT_FAMILY, nil)
		instance:SetAttribute(ATTR_FONT_STYLE, nil)
		instance:SetAttribute(ATTR_DESIRED_TRANSPARENCY, nil)
	end
end

CustomFont.Detach = detachInstance

local function attachConnections(state)
	local instance = state.instance

	local function bind(signal, callback)
		table.insert(state.connections, signal:Connect(callback))
	end

	bind(instance:GetPropertyChangedSignal("Text"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextSize"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextWrapped"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("Size"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("AbsoluteSize"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextXAlignment"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextYAlignment"), function()
		queueRender(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextColor3"), function()
		state.textColor3 = instance.TextColor3
		updateGlyphAppearance(state)
	end)

	bind(instance:GetPropertyChangedSignal("TextTransparency"), function()
		if state.concealGuard then
			return
		end

		setDesiredTransparency(state, instance.TextTransparency)
		concealNativeText(state)
	end)

	bind(instance:GetAttributeChangedSignal(ATTR_DESIRED_TRANSPARENCY), function()
		local attrValue = instance:GetAttribute(ATTR_DESIRED_TRANSPARENCY)
		if typeof(attrValue) ~= "number" then
			return
		end

		state.textTransparency = clampTransparency(attrValue)
		updateGlyphAppearance(state)
	end)

	bind(instance:GetPropertyChangedSignal("ZIndex"), function()
		if state.glyphContainer then
			state.glyphContainer.ZIndex = instance.ZIndex
		end

		for _, glyph in ipairs(state.activeGlyphs) do
			glyph.ZIndex = instance.ZIndex
		end
	end)

	bind(instance:GetPropertyChangedSignal("Visible"), function()
		if state.glyphContainer then
			state.glyphContainer.Visible = instance.Visible
		end
	end)

	bind(instance:GetPropertyChangedSignal("ClipsDescendants"), function()
		if state.glyphContainer then
			state.glyphContainer.ClipsDescendants = instance.ClipsDescendants
		end
	end)

	bind(instance.Destroying, function()
		CustomFont.Detach(instance)
	end)
end

local function configureInstance(instance)
	instance.AutoLocalize = false
	instance.BorderSizePixel = instance.BorderSizePixel or 0

	if instance:IsA("TextButton") then
		instance.AutoButtonColor = false
	end
end

function CustomFont.Attach(instance, fontDescriptor)
	assert(isTextObject(instance), "RBX_CustomFont.Attach expects a TextLabel or TextButton")

	local fontName, styleName = parseFontDescriptor(fontDescriptor or "")
	assert(fontName and fontName ~= "", "RBX_CustomFont.Attach requires a font name")

	CustomFont.Detach(instance)

	local fontDefinition = getFontDefinition(fontName)
	local resolvedStyleName = styleName
	if not fontDefinition.styles[resolvedStyleName] then
		local fallbackName = DEFAULT_STYLE_NAME
		if fontDefinition.styles[fallbackName] then
			resolvedStyleName = fallbackName
		else
			for candidate in pairs(fontDefinition.styles) do
				resolvedStyleName = candidate
				break
			end
		end
	end

	local state = {
		instance = instance,
		fontDefinition = fontDefinition,
		styleName = resolvedStyleName,
		glyphContainer = createGlyphContainer(instance),
		glyphPool = {},
		activeGlyphs = {},
		connections = {},
		renderQueued = false,
		textColor3 = instance.TextColor3,
		textTransparency = 0,
		concealGuard = false,
	}

	stateRegistry[instance] = state

	configureInstance(instance)
	local existingAttr = instance:GetAttribute(ATTR_DESIRED_TRANSPARENCY)
	local initialTransparency = clampTransparency(
		typeof(existingAttr) == "number" and existingAttr or instance.TextTransparency
	)
	state.textTransparency = initialTransparency

	instance:SetAttribute(ATTR_FONT_FAMILY, fontDefinition.name)
	instance:SetAttribute(ATTR_FONT_STYLE, resolvedStyleName)
	instance:SetAttribute(ATTR_DESIRED_TRANSPARENCY, initialTransparency)

	concealNativeText(state)

	attachConnections(state)
	queueRender(state)

	return instance
end

local function applyProps(instance, props)
	if typeof(props) ~= "table" then
		return
	end

	for prop, value in pairs(props) do
		local ok, err = pcall(function()
			instance[prop] = value
		end)

		if not ok then
			logger.Warn("RBX_CustomFont: Failed to apply property", {
				property = tostring(prop),
				error = tostring(err),
				instance = instance:GetFullName(),
			})
		end
	end
end

local function normalizeDescriptorInput(descriptorOrOptions, propsFallback)
	if descriptorOrOptions == nil then
		error("RBX_CustomFont: descriptor is required")
	end

	if typeof(descriptorOrOptions) == "table" then
		local fontName = descriptorOrOptions.font
			or descriptorOrOptions.family
			or descriptorOrOptions.descriptor
			or descriptorOrOptions.name
		local styleName = descriptorOrOptions.style or descriptorOrOptions.variant
		local resolvedProps = descriptorOrOptions.props or propsFallback

		assert(typeof(fontName) == "string" and fontName ~= "", "RBX_CustomFont: descriptor table must include a font name")

		if styleName and styleName ~= "" then
			return ("%s/%s"):format(fontName, styleName), resolvedProps
		end

		return fontName, resolvedProps
	end

	assert(typeof(descriptorOrOptions) == "string" and descriptorOrOptions ~= "", "RBX_CustomFont: font descriptor must be a non-empty string")
	return descriptorOrOptions, propsFallback
end

local function createTextInstance(className, fontDescriptor, props)
	local instance = Instance.new(className)
	instance.Name = props and props.Name or ("CustomFont" .. className)
	instance.BackgroundTransparency = 1
	instance.BorderSizePixel = 0
	instance.Size = UDim2.fromScale(1, 1)
	instance.TextColor3 = instance.TextColor3 or Color3.new(1, 1, 1)
	instance.TextSize = props and props.TextSize or 24
	instance.TextXAlignment = Enum.TextXAlignment.Center
	instance.TextYAlignment = Enum.TextYAlignment.Center
	instance.ClipsDescendants = true
	instance.RichText = false
	instance.TextWrapped = props and props.TextWrapped or false

	if props then
		applyProps(instance, props)
	end

	CustomFont.Attach(instance, fontDescriptor)
	return instance
end

function CustomFont.Label(fontDescriptor, props)
	return createTextInstance("TextLabel", fontDescriptor, props)
end

function CustomFont.TextLabel(fontDescriptor, props)
	return CustomFont.Label(fontDescriptor, props)
end

function CustomFont.TextButton(fontDescriptor, props)
	return createTextInstance("TextButton", fontDescriptor, props)
end

--[[
	Apply a custom font descriptor (string or options table) to an existing TextLabel/TextButton.
	@params:
		instance (TextLabel | TextButton)
		fontDescriptor (string | {font: string?, style: string?, descriptor: string?, props: table?})
		props table? - optional property overrides applied before attachment
	@return instance|nil, err?
--]]
function CustomFont.Apply(instance, fontDescriptor, props)
	assert(isTextObject(instance), "RBX_CustomFont.Apply expects a TextLabel or TextButton")

	local descriptorString, resolvedProps = normalizeDescriptorInput(fontDescriptor, props)

	if resolvedProps then
		applyProps(instance, resolvedProps)
	end

	local ok, err = pcall(function()
		CustomFont.Attach(instance, descriptorString)
	end)

	if not ok then
		logger.Error("RBX_CustomFont: Failed to attach custom font", {
			descriptor = descriptorString,
			error = tostring(err),
			instance = instance:GetFullName(),
		})
		return nil, err
	end

	return instance
end

--[[
	Bulk apply descriptors to descendants of a root Instance.
	Map keys can be Instances or string names searched recursively under the root.
	Values accept the same inputs as CustomFont.Apply.
	Returns an array of Instances that were successfully attached.
--]]
function CustomFont.ApplyMap(rootInstance, descriptorMap)
	assert(typeof(rootInstance) == "Instance", "RBX_CustomFont.ApplyMap expects an Instance root")
	assert(typeof(descriptorMap) == "table", "RBX_CustomFont.ApplyMap expects a table of descriptors")

	local attached = {}

	for identifier, descriptor in pairs(descriptorMap) do
		local target

		if typeof(identifier) == "Instance" then
			target = identifier
		elseif typeof(identifier) == "string" then
			target = rootInstance:FindFirstChild(identifier, true)
		end

		if target and isTextObject(target) then
			local appliedInstance, err = CustomFont.Apply(target, descriptor)
			if appliedInstance and not err then
				table.insert(attached, appliedInstance)
			else
				logger.Warn("RBX_CustomFont: Failed to apply descriptor to target", {
					target = target:GetFullName(),
					error = tostring(err),
				})
			end
		else
			logger.Warn("RBX_CustomFont: ApplyMap target missing or unsupported", {
				identifier = typeof(identifier) == "string" and identifier or tostring(identifier),
			})
		end
	end

	return attached
end

function CustomFont.Preload(fontDescriptor)
	local fontName = parseFontDescriptor(fontDescriptor or "")
	assert(fontName ~= "", "RBX_CustomFont.Preload requires a font name")

	local fontDefinition = getFontDefinition(fontName)
	local assets = {}

	for _, contentId in ipairs(fontDefinition.atlases) do
		if typeof(contentId) == "string" and contentId ~= "" then
			table.insert(assets, contentId)
		end
	end

	if #assets > 0 then
		local ok, err = pcall(function()
			ContentProvider:PreloadAsync(assets)
		end)

		if not ok then
			logger.Warn("RBX_CustomFont: Failed to preload font", {
				font = fontName,
				error = tostring(err),
			})
			return false
		end
	end

	return true
end

return CustomFont

