--[[
	SpawnEggIcon.lua
	Creates a two-layer ImageLabel stack for spawn egg icons (base + overlay tint).
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpawnEggConfig = require(ReplicatedStorage.Configs.SpawnEggConfig)

-- Preload images once
local preloaded = false
local function ensurePreloaded()
	if preloaded then return end
	preloaded = true
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ SpawnEggConfig.BaseImageId, SpawnEggConfig.OverlayImageId })
		end)
	end)
end

local SpawnEggIcon = {}

function SpawnEggIcon.Create(itemId, size)
	ensurePreloaded()

	local info = SpawnEggConfig.GetEggInfo(itemId)
	local primary = info and info.colors and info.colors.primary or Color3.new(1, 1, 1)
	local secondary = info and info.colors and info.colors.secondary or Color3.new(0.5, 0.5, 0.5)

	local holder = Instance.new("Frame")
	holder.Name = "SpawnEggIcon"
	holder.BackgroundTransparency = 1
	holder.Size = size or UDim2.fromScale(1, 1)

	local base = Instance.new("ImageLabel")
	base.Name = "Base"
	base.BackgroundTransparency = 1
	base.Size = UDim2.fromScale(1, 1)
	base.Image = SpawnEggConfig.BaseImageId
	base.ImageColor3 = primary
	base.ScaleType = Enum.ScaleType.Fit
	base.Parent = holder

	local overlay = Instance.new("ImageLabel")
	overlay.Name = "Overlay"
	overlay.BackgroundTransparency = 1
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Image = SpawnEggConfig.OverlayImageId
	overlay.ImageColor3 = secondary
	overlay.ScaleType = Enum.ScaleType.Fit
	overlay.Parent = holder

	return holder
end

return SpawnEggIcon


