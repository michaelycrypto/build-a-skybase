--[[
	UIScaler.lua - Responsive UI Scaling Manager
	Automatically scales UI based on viewport size using CollectionService tags

	Usage:
	1. Add UIScale object to your ScreenGui
	2. Set attribute: uiScale:SetAttribute("base_resolution", Vector2.new(1920, 1080))
	3. Tag it: CollectionService:AddTag(uiScale, "scale_component")
	4. UIScaler will automatically rescale on viewport changes (orientation, resolution)

	Mobile scaling:
	- On touch devices, all scale_component tagged UIScale objects are additionally
	  multiplied by MOBILE_SCALE_MULTIPLIER (default 0.72) for a smaller HUD.
	- Per-component override: set attribute "mobile_scale_multiplier" (number) on the
	  UIScale instance to use a custom multiplier instead of the global default.
	  e.g. uiScale:SetAttribute("mobile_scale_multiplier", 1.0) to keep full size on mobile.
]]

local UIScaler = {}

local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Configuration
local MIN_SCALE = 0.85 -- Minimum scale (85%) to prevent UI from being too small on tiny screens
local MAX_SCALE = 1.5  -- Maximum scale (150%) to prevent UI from being too large on very small resolutions
local MOBILE_SCALE_MULTIPLIER = 0.72 -- Scale down HUD on mobile for more gameplay visibility

-- State
local scale_component_to_base_resolution = {}
local layout_component_to_rescaling_connection = {}
local scale_listeners = {}
local next_scale_listener_id = 0
local camera = nil
local actual_viewport_size = nil
local has_initialized = false
local is_mobile = false

--[[
	Rescale a single UIScale component with min/max clamping
]]
local function rescale(scale_component, base_resolution)
	if not actual_viewport_size then
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

	-- Apply mobile scale multiplier for smaller HUD on touch devices
	if is_mobile then
		local mobileMultiplier = scale_component:GetAttribute("mobile_scale_multiplier")
		if typeof(mobileMultiplier) ~= "number" then
			mobileMultiplier = MOBILE_SCALE_MULTIPLIER
		end
		finalScale = finalScale * mobileMultiplier
	end

	scale_component.Scale = finalScale
end

--[[
	Rescale all registered components
]]
local function notify_scale_listeners()
	for _, listener in pairs(scale_listeners) do
		if listener then
			local ok, err = pcall(listener)
			if not ok then
				warn("UIScaler: Scale listener error:", err)
			end
		end
	end
end

local function rescale_all()
	-- Use full viewport size without subtracting insets
	-- UIs with IgnoreGuiInset=false already account for the top bar
	actual_viewport_size = camera.ViewportSize

	for scale_component, base_resolution in scale_component_to_base_resolution do
		rescale(scale_component, base_resolution)
	end

	notify_scale_listeners()
end

--[[
	Register a UIScale component
]]
local function register_scale(component)
	local base_resolution = component:GetAttribute("base_resolution")
	if typeof(base_resolution) ~= "Vector2" then
		return
	end
	scale_component_to_base_resolution[component] = base_resolution
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
		return
	end

	has_initialized = true

	-- Get camera reference
	camera = Workspace:FindFirstChild("Camera") or Workspace.CurrentCamera

	-- Detect mobile (touch-enabled device)
	is_mobile = UserInputService.TouchEnabled

	-- Listen for new scale components
	CollectionService:GetInstanceAddedSignal("scale_component"):Connect(function(object)
		if object:IsA("UIScale") then
			register_scale(object)
			if scale_component_to_base_resolution[object] then
				rescale(object, scale_component_to_base_resolution[object])
			end
		end
	end)

	CollectionService:GetInstanceRemovedSignal("scale_component"):Connect(function(object)
		if object:IsA("UIScale") then
			scale_component_to_base_resolution[object] = nil
		end
	end)

	-- Register existing scale components
	local existingComponents = CollectionService:GetTagged("scale_component")
	for _, object in existingComponents do
		if object:IsA("UIScale") then
			register_scale(object)
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
		rescale_all()
	end)

	-- Initial rescale
	rescale_all()

	-- Delayed rescales to catch any late-loading UI
	task.delay(2, rescale_all)
	task.delay(5, rescale_all)
end

--[[
	Cleanup (called automatically by GameClient on player leaving)
]]
function UIScaler:Cleanup()
	for _, connection in layout_component_to_rescaling_connection do
		if connection then
			connection:Disconnect()
		end
	end
	layout_component_to_rescaling_connection = {}
	scale_component_to_base_resolution = {}
	has_initialized = false
	is_mobile = false
	scale_listeners = {}
	next_scale_listener_id = 0
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

local function _notify_scale_listeners()
	for _, listener in pairs(scale_listeners) do
		if listener then
			local ok, err = pcall(listener)
			if not ok then
				warn("UIScaler: Scale listener error:", err)
			end
		end
	end
end

return UIScaler

