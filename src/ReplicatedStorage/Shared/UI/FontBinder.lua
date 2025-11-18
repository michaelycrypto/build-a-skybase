--!nonstrict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)

local CUSTOM_FONT_MODULE_NAME = "RBX_CustomFont"
local CUSTOM_FONT_MODULE_TIMEOUT = 15

local FontBinder = {}

local fontModule
local fontModuleLoaded = false
local primedFonts = {}

local logger = Logger:CreateContext("FontBinder")

local function getFontModule()
	if fontModuleLoaded and fontModule then
		return fontModule
	end

	local moduleInstance = ReplicatedStorage:WaitForChild(CUSTOM_FONT_MODULE_NAME, CUSTOM_FONT_MODULE_TIMEOUT)
	assert(moduleInstance, ("FontBinder: %s module not found"):format(CUSTOM_FONT_MODULE_NAME))

	local ok, moduleOrError = pcall(require, moduleInstance)
	assert(ok and moduleOrError, ("FontBinder: Failed to require %s: %s"):format(CUSTOM_FONT_MODULE_NAME, tostring(moduleOrError)))

	fontModule = moduleOrError
	fontModuleLoaded = true
	return fontModule
end

local function gatherFontNames(input)
	local names = {}

	local function add(name)
		if typeof(name) == "string" and name ~= "" then
			names[name] = true
		end
	end

	if typeof(input) == "string" then
		add(input)
	elseif typeof(input) == "table" then
		for _, value in pairs(input) do
			if typeof(value) == "string" then
				add(value)
			end
		end
	end

	return names
end

function FontBinder.preload(fonts)
	local module = getFontModule()
	local names = gatherFontNames(fonts)

	for fontName in pairs(names) do
		if primedFonts[fontName] then
			continue
		end

		local ok, err = pcall(function()
			if typeof(module.Preload) == "function" then
				module.Preload(fontName)
			else
				local preview = module.Label(fontName)
				if preview and preview.Destroy then
					preview:Destroy()
				end
			end
		end)

		if not ok then
			logger:Warn("Failed to preload font", {
				font = fontName,
				error = tostring(err),
			})
		else
			primedFonts[fontName] = true
		end
	end
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
			logger:Warn("Failed to apply property to text instance", {
				property = tostring(prop),
				error = tostring(err),
				instance = instance:GetFullName(),
			})
		end
	end
end

function FontBinder.apply(instance, descriptor, props)
	assert(typeof(instance) == "Instance", "FontBinder.apply expects an Instance")

	local module = getFontModule()
	local resolvedDescriptor = descriptor or ""

	if props then
		applyProps(instance, props)
	end

	if typeof(module.Apply) == "function" then
		local ok, resultOrErr = pcall(function()
			return module.Apply(instance, resolvedDescriptor)
		end)

		if ok and resultOrErr then
			return resultOrErr
		end

		logger:Warn("CustomFont.Apply failed; falling back to Attach", {
			descriptor = resolvedDescriptor,
			error = tostring(resultOrErr),
			instance = instance:GetFullName(),
		})
	end

	local ok, err = pcall(function()
		module.Attach(instance, resolvedDescriptor)
	end)

	if not ok then
		logger:Error("Failed to attach custom font", {
			descriptor = resolvedDescriptor,
			error = tostring(err),
			instance = instance:GetFullName(),
		})
		return nil, err
	end

	return instance
end

return FontBinder


