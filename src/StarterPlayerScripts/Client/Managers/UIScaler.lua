--[[
	UIScaler.lua - Responsive UI Scaling Manager
	Automatically scales UI based on viewport size using CollectionService tags

	Usage:
	1. Add UIScale object to your ScreenGui
	2. Set attribute: uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	3. Tag it: CollectionService:AddTag(uiScale, "scale_component")
	4. UIScaler will automatically rescale on viewport changes (orientation, resolution)
]]

local UIScaler = {}

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")

-- Configuration
local MIN_SCALE = 0.85 -- Minimum scale (85%) to prevent UI from being too small on tiny screens
local MAX_SCALE = 1.5  -- Maximum scale (150%) to prevent UI from being too large on very small resolutions

-- State
local scale_component_to_base_resolution = {}
local layout_component_to_rescaling_connection = {}
local scale_listeners = {}
local next_scale_listener_id = 0
local camera = nil
local actual_viewport_size = nil
local has_initialized = false

--[[
	Rescale a single UIScale component with min/max clamping
]]
local function rescale(scale_component, base_resolution)
	if not actual_viewport_size then
		warn("❌ UIScaler: actual_viewport_size is nil!")
		return
	end

	local scaleX = base_resolution.X / actual_viewport_size.X
	local scaleY = base_resolution.Y / actual_viewport_size.Y
	local maxScale = math.max(scaleX, scaleY)
	local rawScale = 1 / maxScale

	-- Allow components to override clamp range
	local minScaleAttr = scale_component:GetAttribute("min_scale")
	local maxScaleAttr = scale_component:GetAttribute("max_scale")
	local minScale = (typeof(minScaleAttr) == "number") and minScaleAttr or MIN_SCALE
	local maxScale = (typeof(maxScaleAttr) == "number") and maxScaleAttr or MAX_SCALE
	if minScale > maxScale then
		minScale, maxScale = maxScale, minScale
	end

	-- Clamp scale to prevent UI from being too small or too large
	local finalScale = math.clamp(rawScale, minScale, maxScale)

	scale_component.Scale = finalScale

	local clamped = (rawScale ~= finalScale) and " [CLAMPED]" or ""
	print(string.format("📐 UIScaler: Rescaled %s → Scale=%.3f%s (raw=%.3f, base=%dx%d, viewport=%dx%d)",
		scale_component:GetFullName(),
		finalScale,
		clamped,
		rawScale,
		base_resolution.X, base_resolution.Y,
		actual_viewport_size.X, actual_viewport_size.Y
	))
end

--[[
	Rescale all registered components
]]
local function notify_scale_listeners()
	for listener_id, listener in pairs(scale_listeners) do
		if listener then
			local ok, err = pcall(listener)
			if not ok then
				warn("UIScaler: Scale listener error:", err)
			end
		end
	end
end

local function rescale_all()
	local top_inset, bottom_inset = GuiService:GetGuiInset()
	actual_viewport_size = camera.ViewportSize - top_inset - bottom_inset

	local count = 0
	for scale_component, base_resolution in scale_component_to_base_resolution do
		rescale(scale_component, base_resolution)
		count = count + 1
	end

	print(string.format("📐 UIScaler: Rescaled %d components for viewport %dx%d",
		count, math.floor(actual_viewport_size.X), math.floor(actual_viewport_size.Y)))

	notify_scale_listeners()
end

--[[
	Register a UIScale component
]]
local function register_scale(component)
	local base_resolution = component:GetAttribute("base_resolution")
	if typeof(base_resolution) ~= "Vector2" then
		warn(string.format("❌ UIScaler: Component %s has invalid base_resolution: %s (type: %s)",
			component:GetFullName(),
			tostring(base_resolution),
			typeof(base_resolution)
		))
		return
	end
	scale_component_to_base_resolution[component] = base_resolution
	print(string.format("✅ UIScaler: Registered %s (parent: %s, base: %dx%d)",
		component:GetFullName(),
		component.Parent and component.Parent.Name or "nil",
		base_resolution.X, base_resolution.Y))
end

--[[
	Register a scrolling frame layout component
	Fixes AutomaticCanvasSize working with UIListLayout and UIScale
]]
local function register_scrolling_frame_layout_component(layout_component)
	local scale_component_referral = layout_component:FindFirstChild("scale_component_referral")
	if not (scale_component_referral and scale_component_referral:IsA("ObjectValue")) then
		warn("UIScaler: Layout must have scale_component_referral ObjectValue")
		return
	end
	if not (scale_component_referral.Value and scale_component_referral.Value:IsA("UIScale")) then
		warn("UIScaler: scale_component_referral must point to UIScale")
		return
	end

	local scale_component = scale_component_referral.Value
	local scrolling_frame = layout_component.Parent
	if not (scrolling_frame and scrolling_frame:IsA("ScrollingFrame")) then
		warn("UIScaler: Layout parent must be ScrollingFrame")
		return
	end

	-- Fix AutomaticCanvasSize working with UIListLayout and UIScale
	-- https://devforum.roblox.com/t/automaticcanvassize-working-with-uilistlayout-and-uiscale-causes-wrong-automatic-size/1334861
	layout_component_to_rescaling_connection[layout_component] = layout_component:GetPropertyChangedSignal(
		"AbsoluteContentSize"
	):Connect(function()
		scrolling_frame.CanvasSize = UDim2.fromOffset(
			layout_component.AbsoluteContentSize.X / scale_component.Scale,
			layout_component.AbsoluteContentSize.Y / scale_component.Scale
		)
	end)

	-- Set initial canvas size
	scrolling_frame.CanvasSize = UDim2.fromOffset(
		layout_component.AbsoluteContentSize.X / scale_component.Scale,
		layout_component.AbsoluteContentSize.Y / scale_component.Scale
	)
end

--[[
	Initialize UIScaler system
]]
function UIScaler:Initialize()
	if has_initialized then
		warn("UIScaler: Already initialized")
		return
	end

	print("🚀 UIScaler: Starting initialization...")
	has_initialized = true

	-- Get camera reference
	camera = Workspace:FindFirstChild("Camera") or Workspace.CurrentCamera

	-- Listen for new scale components
	CollectionService:GetInstanceAddedSignal("scale_component"):Connect(function(object)
		print(string.format("🔔 UIScaler: New scale_component detected: %s (type: %s)",
			object:GetFullName(),
			object.ClassName))
		if object:IsA("UIScale") then
			register_scale(object)
			if scale_component_to_base_resolution[object] then
				rescale(object, scale_component_to_base_resolution[object])
			end
		else
			warn(string.format("⚠️ UIScaler: Tagged object is not UIScale: %s (type: %s)",
				object:GetFullName(),
				object.ClassName))
		end
	end)

	CollectionService:GetInstanceRemovedSignal("scale_component"):Connect(function(object)
		if object:IsA("UIScale") then
			scale_component_to_base_resolution[object] = nil
		end
	end)

	-- Register existing scale components
	local existingComponents = CollectionService:GetTagged("scale_component")
	print(string.format("🔍 UIScaler: Found %d existing scale_component tagged objects", #existingComponents))
	for _, object in existingComponents do
		print(string.format("   → %s (type: %s)", object:GetFullName(), object.ClassName))
		if object:IsA("UIScale") then
			register_scale(object)
		else
			warn(string.format("⚠️ UIScaler: Tagged object is not UIScale: %s (type: %s)",
				object:GetFullName(),
				object.ClassName))
		end
	end

	-- Listen for new scrolling frame layout components
	CollectionService:GetInstanceAddedSignal("scrolling_frame_layout_component"):Connect(function(object)
		if object:IsA("UIGridStyleLayout") or object:IsA("UIListLayout") then
			register_scrolling_frame_layout_component(object)
		end
	end)

	-- Register existing scrolling frame layout components
	for _, object in CollectionService:GetTagged("scrolling_frame_layout_component") do
		if object:IsA("UIGridStyleLayout") or object:IsA("UIListLayout") then
			register_scrolling_frame_layout_component(object)
		end
	end

	CollectionService:GetInstanceRemovedSignal("scrolling_frame_layout_component"):Connect(function(object)
		if object:IsA("UIGridStyleLayout") or object:IsA("UIListLayout") then
			local rescaling_connection = layout_component_to_rescaling_connection[object]
			if rescaling_connection then
				rescaling_connection:Disconnect()
				layout_component_to_rescaling_connection[object] = nil
			end
		end
	end)

	-- Watch for viewport changes (handles orientation changes landscape/portrait)
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		print(string.format("🔄 UIScaler: Viewport size changed to %dx%d - Rescaling all components...",
			camera.ViewportSize.X,
			camera.ViewportSize.Y))
		rescale_all()
	end)

	print(string.format("📐 UIScaler: Current viewport size: %dx%d",
		camera.ViewportSize.X,
		camera.ViewportSize.Y))

	-- Initial rescale
	print("📐 UIScaler: Performing initial rescale...")
	rescale_all()

	-- Delayed rescales to catch any late-loading UI
	task.delay(2, function()
		print("📐 UIScaler: Delayed rescale check (2s)...")
		rescale_all()
	end)

	task.delay(5, function()
		print("📐 UIScaler: Delayed rescale check (5s)...")
		rescale_all()
	end)

	print("✅ UIScaler: Initialization complete")
end

--[[
	Cleanup (called automatically by GameClient on player leaving)
]]
function UIScaler:Cleanup()
	for layout_component, connection in layout_component_to_rescaling_connection do
		if connection then
			connection:Disconnect()
		end
	end
	layout_component_to_rescaling_connection = {}
	scale_component_to_base_resolution = {}
	has_initialized = false
	scale_listeners = {}
	next_scale_listener_id = 0
	print("UIScaler: Cleanup complete")
end

function UIScaler:RegisterScaleListener(callback)
	if typeof(callback) ~= "function" then
		warn("UIScaler:RegisterScaleListener requires a function callback")
		return nil
	end

	next_scale_listener_id = next_scale_listener_id + 1
	local listener_id = next_scale_listener_id
	scale_listeners[listener_id] = callback

	return function()
		scale_listeners[listener_id] = nil
	end
end

local function notify_scale_listeners()
	for listener_id, listener in pairs(scale_listeners) do
		if listener then
			local ok, err = pcall(listener)
			if not ok then
				warn("UIScaler: Scale listener error:", err)
			end
		end
	end
end

return UIScaler

