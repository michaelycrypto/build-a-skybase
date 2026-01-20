--[[
	EmoteManager.lua - Emote System Manager
	Handles emote selection, display, and network communication
--]]

local EmoteManager = {}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Import dependencies (will be overridden by Initialize)
local Network = nil
local Config = require(ReplicatedStorage.Shared.Config)
local IconMapping = require(ReplicatedStorage.Shared.IconMapping)
local EventManager = require(ReplicatedStorage.Shared.EventManager)
local SoundManager = nil

-- Services
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get emote mapping from shared IconMapping
local EMOTE_MAPPING = IconMapping.Emotes

-- Constants
local EMOTE_DURATION = 3 -- seconds
local BILLBOARD_OFFSET = Vector3.new(0, 5, 0) -- Better positioning above player's head
local BILLBOARD_SIZE = UDim2.new(0, 64, 0, 64)

-- State
local activeBillboards = {} -- Track active billboards by player
local scalingConnections = {} -- Track scaling connections by billboard
local emotePanel = nil
local overlayDetector = nil
local isPanelOpen = false
local isInitialized = false

--[[
	Initialize the EmoteManager
	@param dependencies: table - Optional dependencies (Network, SoundManager)
--]]
function EmoteManager:Initialize(dependencies)
    if isInitialized then return end

    -- Set up dependencies
    if dependencies then
        Network = dependencies.Network or require(ReplicatedStorage.Shared.Network)
        SoundManager = dependencies.SoundManager
    else
        -- Fallback to direct require
        Network = require(ReplicatedStorage.Shared.Network)
        -- SoundManager stays nil if not provided
    end

    -- Validate required dependencies
    if not Network then
        warn("EmoteManager: Network dependency is required")
        return false
    end

    -- Register network events
    self:RegisterNetworkEvents()

    -- Create emote panel
    self:CreateEmotePanel()

    isInitialized = true
    return true
end

--[[
	Register network events for emote synchronization
--]]
function EmoteManager:RegisterNetworkEvents()
    -- Events are handled automatically by EventManager configuration
    -- No manual registration needed - EventManager will call the appropriate methods
end

--[[
	Create the emote panel UI
--]]
function EmoteManager:CreateEmotePanel()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "EmotePanel"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    	-- Wide rectangular quick actions panel
	local panelFrame = Instance.new("Frame")
	panelFrame.Name = "PanelFrame"
	panelFrame.Size = UDim2.new(0, 630, 0, 180)
	panelFrame.Position = UDim2.new(0.5, -315, 1, -290) -- Position above bottom HUD
	panelFrame.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundGlass
	panelFrame.BackgroundTransparency = 0.05
	panelFrame.BorderSizePixel = 0
	panelFrame.Visible = false
	panelFrame.Parent = screenGui

	-- Panel styling
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panelFrame

	local border = Instance.new("UIStroke")
	border.Color = Config.UI_SETTINGS.colors.primary
	border.Thickness = 1
	border.Transparency = 0.4
	border.Parent = panelFrame

	-- Full-size emote grid container (no header)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "EmoteGrid"
	scrollFrame.Size = UDim2.new(1, -16, 1, -16)
	scrollFrame.Position = UDim2.new(0, 8, 0, 8)
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 4
	scrollFrame.ScrollBarImageColor3 = Config.UI_SETTINGS.colors.primary
	scrollFrame.ScrollBarImageTransparency = 0.6
	scrollFrame.Parent = panelFrame

	-- Wide grid layout for more items per row
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 3, 0, 3)
	gridLayout.CellSize = UDim2.new(0, 40, 0, 40)
	gridLayout.SortOrder = Enum.SortOrder.Name
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.Parent = scrollFrame

    -- Populate emotes
    self:PopulateEmoteGrid(scrollFrame)

    	-- Update scroll canvas size
	local contentSize = gridLayout.AbsoluteContentSize
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10)
	end)

	-- Smart overlay behavior - only capture clicks outside the panel area
	local overlayFrame = Instance.new("TextButton")
	overlayFrame.Name = "OverlayDetector"
	overlayFrame.Size = UDim2.new(1, 0, 1, 0)
	overlayFrame.BackgroundTransparency = 1
	overlayFrame.Text = ""
	overlayFrame.Modal = false -- Don't block other UI interactions
	overlayFrame.Parent = screenGui
	overlayFrame.Visible = false
	overlayFrame.ZIndex = 1 -- Behind the panel

	-- Close when clicking the overlay background
	overlayFrame.MouseButton1Click:Connect(function()
		self:HideEmotePanel()
	end)

	-- Set panel to higher ZIndex to prevent overlay clicks
	panelFrame.ZIndex = 2

	emotePanel = panelFrame
	overlayDetector = overlayFrame
end

--[[
	Populate the emote grid with all available emotes
--]]
function EmoteManager:PopulateEmoteGrid(container)
    for emoteName, assetId in pairs(EMOTE_MAPPING) do
        local emoteButton = Instance.new("ImageButton")
        emoteButton.Name = emoteName
        emoteButton.Size = UDim2.new(0, 40, 0, 40)
        emoteButton.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
        emoteButton.BackgroundTransparency = 0.4
        emoteButton.BorderSizePixel = 0
        emoteButton.Image = "rbxassetid://" .. assetId
        emoteButton.Parent = container

        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 8)
        buttonCorner.Parent = emoteButton

        -- Compact hover effects - no size change for tight layout
        emoteButton.MouseEnter:Connect(function()
            TweenService:Create(emoteButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.1,
            }):Play()
        end)

        emoteButton.MouseLeave:Connect(function()
            TweenService:Create(emoteButton, TweenInfo.new(0.15), {
                BackgroundTransparency = 0.4,
            }):Play()
        end)

        -- Click handler
        emoteButton.MouseButton1Click:Connect(function()
            self:SelectEmote(emoteName)
        end)
    end
end

--[[
	Select and display an emote
--]]
function EmoteManager:SelectEmote(emoteName)
    if not isInitialized then
        warn("EmoteManager: Not initialized")
        return
    end

    if not EMOTE_MAPPING[emoteName] then
        warn("EmoteManager: Invalid emote name:", emoteName)
        return
    end

    if not Network then
        warn("EmoteManager: Network not available")
        return
    end

    -- Show emote locally
    self:ShowEmoteBillboard(player, emoteName)

    -- Send to server to show to other players
    local success, error = pcall(function()
        EventManager:SendToServer("PlayEmote", emoteName)
    end)

    if not success then
        warn("EmoteManager: Failed to send emote to server:", error)
    end

    -- Hide panel after selection
    self:HideEmotePanel()

    -- Play sound effect if available
    if SoundManager and SoundManager.PlaySFX then
        pcall(function()
            SoundManager:PlaySFX("buttonClick")
        end)
    end
end

--[[
	Show emote billboard above a player
--]]
function EmoteManager:ShowEmoteBillboard(targetPlayer, emoteName)
    if not targetPlayer or not targetPlayer.Character then return end

    local character = targetPlayer.Character
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoidRootPart then return end

    -- Remove existing billboard if any
    self:RemoveEmoteBillboard(targetPlayer)

    -- Create billboard GUI
    local billboardGui = Instance.new("BillboardGui")
    billboardGui.Name = "EmoteBillboard"
    billboardGui.Size = BILLBOARD_SIZE
    billboardGui.StudsOffset = BILLBOARD_OFFSET
    billboardGui.Adornee = humanoidRootPart
    billboardGui.Parent = workspace

    -- Create emote image with completely transparent design
    local emoteImage = Instance.new("ImageLabel")
    emoteImage.Name = "EmoteImage"
    emoteImage.Size = UDim2.new(1, 0, 1, 0)
    emoteImage.Position = UDim2.new(0.5, 0, 0.5, 0) -- Center position
    emoteImage.AnchorPoint = Vector2.new(0.5, 0.5) -- Center anchor for smooth scaling
    emoteImage.BackgroundTransparency = 1 -- Fully transparent background
    emoteImage.BorderSizePixel = 0
    emoteImage.Image = "rbxassetid://" .. EMOTE_MAPPING[emoteName]
    emoteImage.ImageColor3 = Color3.new(1, 1, 1)
    emoteImage.ScaleType = Enum.ScaleType.Fit
    emoteImage.Parent = billboardGui

    -- Store billboard reference
    activeBillboards[targetPlayer] = billboardGui

    -- Store original size for distance scaling
    billboardGui:SetAttribute("OriginalSize", BILLBOARD_SIZE)

    -- Setup distance-based scaling
    self:SetupDistanceScaling(billboardGui)

    -- Initial state for refined fade/grow animation
    emoteImage.Size = UDim2.new(0.3, 0, 0.3, 0) -- Start smaller
    emoteImage.ImageTransparency = 1
    emoteImage.Rotation = 0

    -- Start the refined entrance effect
    self:CreateRefinedEntranceEffect(billboardGui, emoteImage)

    -- Auto-remove after duration and clean up reference
    game:GetService("Debris"):AddItem(billboardGui, EMOTE_DURATION)

    -- Clean up reference when billboard is removed
    task.delay(EMOTE_DURATION, function()
        if activeBillboards[targetPlayer] == billboardGui then
            activeBillboards[targetPlayer] = nil
        end
    end)
end

--[[
	Create a refined fade/grow entrance effect with rotational shake
--]]
function EmoteManager:CreateRefinedEntranceEffect(billboardGui, emoteImage)
    if not billboardGui or not billboardGui.Parent or not emoteImage then return end

    -- Phase 1: Fade and grow in smoothly
    local fadeGrowTween = TweenService:Create(emoteImage,
        TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(1, 0, 1, 0),
        ImageTransparency = 0
    })

    fadeGrowTween:Play()

    -- Phase 2: Subtle rotational shake after fade/grow
    fadeGrowTween.Completed:Connect(function()
        if billboardGui.Parent and emoteImage.Parent then
            self:CreateRotationalShake(emoteImage)
        end
    end)
end

--[[
	Create a subtle rotational shake effect
--]]
function EmoteManager:CreateRotationalShake(emoteImage)
    if not emoteImage or not emoteImage.Parent then return end

    -- Rotational shake parameters
    local shakeCount = 0
    local maxShakes = 4
    local rotationIntensity = 8 -- degrees
    local shakeSpeed = 0.12

    local function performShake()
        if shakeCount >= maxShakes or not emoteImage.Parent then return end

        -- Random rotation direction and intensity
        local randomRotation = (math.random() - 0.5) * rotationIntensity

        -- Quick rotation shake
        local shakeTween = TweenService:Create(emoteImage,
            TweenInfo.new(shakeSpeed, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
            Rotation = randomRotation
        })

        shakeTween:Play()
        shakeCount = shakeCount + 1

        -- Return to center rotation
        shakeTween.Completed:Connect(function()
            if emoteImage.Parent then
                local returnTween = TweenService:Create(emoteImage,
                    TweenInfo.new(shakeSpeed * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                    Rotation = 0
                })

                returnTween:Play()

                -- Continue shaking or finish
                if shakeCount < maxShakes then
                    returnTween.Completed:Connect(function()
                        task.wait(shakeSpeed * 0.3)
                        performShake()
                    end)
                end
            end
        end)
    end

    -- Start the rotational shake sequence
    task.spawn(function()
        task.wait(0.1) -- Brief pause before shaking
        performShake()
    end)
end

--[[
	Setup distance-based scaling for billboard
--]]
function EmoteManager:SetupDistanceScaling(billboardGui)
    if not billboardGui or not billboardGui.Parent then return end

    local camera = workspace.CurrentCamera
    local originalSize = billboardGui:GetAttribute("OriginalSize") or BILLBOARD_SIZE

    -- Distance scaling parameters
    local minScale = 0.4 -- Minimum scale at far distance
    local maxScale = 1.2 -- Maximum scale at close distance
    local nearDistance = 15 -- Distance for max scale
    local farDistance = 80 -- Distance for min scale

        local connection
    connection = RunService.Heartbeat:Connect(function()
        if not billboardGui.Parent or not billboardGui.Adornee then
            connection:Disconnect()
            scalingConnections[billboardGui] = nil
            return
        end

        -- Calculate distance from camera to billboard
        local adorneePosition = billboardGui.Adornee.Position
        local cameraPosition = camera.CFrame.Position
        local distance = (adorneePosition - cameraPosition).Magnitude

        -- Calculate scale based on distance (inverse relationship)
        local scale = 1
        if distance <= nearDistance then
            scale = maxScale
        elseif distance >= farDistance then
            scale = minScale
        else
            -- Linear interpolation between near and far
            local t = (distance - nearDistance) / (farDistance - nearDistance)
            scale = maxScale - (maxScale - minScale) * t
        end

        -- Apply scaled size
        local newSize = UDim2.new(0, originalSize.X.Offset * scale, 0, originalSize.Y.Offset * scale)
        billboardGui.Size = newSize
    end)

    -- Store connection for cleanup
    scalingConnections[billboardGui] = connection
end

--[[
	Remove emote billboard from a player
--]]
function EmoteManager:RemoveEmoteBillboard(targetPlayer)
    local billboard = activeBillboards[targetPlayer]
    if billboard then
        -- Clean up scaling connection
        local connection = scalingConnections[billboard]
        if connection then
            connection:Disconnect()
            scalingConnections[billboard] = nil
        end

        billboard:Destroy()
        activeBillboards[targetPlayer] = nil
    end
end

--[[
	Show the emote panel
--]]
function EmoteManager:ShowEmotePanel()
    if not emotePanel then return end

    isPanelOpen = true
    emotePanel.Visible = true
    if overlayDetector then
        overlayDetector.Visible = true
    end

    -- Simple slide up animation from button area
    emotePanel.Position = UDim2.new(0.5, -315, 1, -110) -- Start near button
    emotePanel.BackgroundTransparency = 0.3

    -- Single smooth slide up
    TweenService:Create(emotePanel,
        TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -315, 1, -290), -- Final position
        BackgroundTransparency = 0.05
    }):Play()
end

--[[
	Hide the emote panel
--]]
function EmoteManager:HideEmotePanel()
    if not emotePanel then return end

    isPanelOpen = false
    if overlayDetector then
        overlayDetector.Visible = false
    end

    -- Simple slide down animation back to button area
    local tween = TweenService:Create(emotePanel,
        TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -315, 1, -110), -- Slide back toward button
        BackgroundTransparency = 1
    })

    tween:Play()
    tween.Completed:Connect(function()
        emotePanel.Visible = false
    end)
end

--[[
	Toggle the emote panel visibility
--]]
function EmoteManager:ToggleEmotePanel()
    if isPanelOpen then
        self:HideEmotePanel()
    else
        self:ShowEmotePanel()
    end
end

--[[
	Check if emote panel is open
--]]
function EmoteManager:IsEmotePanelOpen()
    return isPanelOpen
end

--[[
	Get all available emote names
--]]
function EmoteManager:GetAvailableEmotes()
    local emotes = {}
    for emoteName, _ in pairs(EMOTE_MAPPING) do
        table.insert(emotes, emoteName)
    end
    return emotes
end

--[[
	Get the complete emote mapping for preloading
--]]
function EmoteManager:GetEmoteMapping()
    return EMOTE_MAPPING
end

--[[
	Check if emote assets are likely preloaded
	Simple heuristic - checks if first few emotes load quickly
--]]
function EmoteManager:AreAssetsPreloaded()
    local testAssets = 0
    local maxTests = 3

    for emoteName, assetId in pairs(EMOTE_MAPPING) do
        if testAssets >= maxTests then break end

        local assetUrl = "rbxassetid://" .. tostring(assetId)
        local startTime = tick()

        -- Quick check if asset loads fast (likely cached)
        pcall(function()
            game:GetService("ContentProvider"):PreloadAsync({assetUrl})
        end)

        local loadTime = tick() - startTime
        if loadTime > 0.1 then -- If it takes longer than 100ms, probably not preloaded
            return false
        end

        testAssets = testAssets + 1
    end

    return true
end

--[[
	Show emote panel (can be called from UI)
--]]
function EmoteManager:ShowPanel()
    if not isInitialized then
        warn("EmoteManager: Not initialized")
        return false
    end

    self:ShowEmotePanel()
    return true
end

--[[
	Hide emote panel (can be called from UI)
--]]
function EmoteManager:HidePanel()
    if not isInitialized then
        return false
    end

    self:HideEmotePanel()
    return true
end

--[[
	Check if the manager is initialized
--]]
function EmoteManager:IsInitialized()
    return isInitialized
end

--[[
	Called when the panel is shown via PanelManager
--]]
function EmoteManager:OnPanelShown()
    if not isInitialized then
        warn("EmoteManager: Not initialized")
        return
    end

    -- Panel shown via PanelManager integration
    print("EmoteManager: Panel shown via PanelManager")
end

--[[
	Called when the panel is hidden via PanelManager
--]]
function EmoteManager:OnPanelHidden()
    if not isInitialized then
        return
    end

    -- Panel hidden via PanelManager integration
    print("EmoteManager: Panel hidden via PanelManager")
end

--[[
	Cleanup function for proper shutdown
--]]
function EmoteManager:Cleanup()
    -- Clean up all active billboards and their connections
    for player, billboard in pairs(activeBillboards) do
        if billboard then
            local connection = scalingConnections[billboard]
            if connection then
                connection:Disconnect()
                scalingConnections[billboard] = nil
            end
            billboard:Destroy()
        end
    end
    activeBillboards = {}
    scalingConnections = {}

    -- Hide and clean up emote panel
    if emotePanel then
        emotePanel.Parent:Destroy()
        emotePanel = nil
    end

    isPanelOpen = false
    isInitialized = false

    print("EmoteManager: Cleaned up successfully")
end

--[[
	Create panel content for PanelManager integration
	@param contentFrame: Frame - The content frame provided by PanelManager
	@param data: table - Optional data for the panel
--]]
function EmoteManager:CreatePanelContent(contentFrame, data)
	if not contentFrame then
		warn("EmoteManager: No content frame provided")
		return
	end

			-- Create emote grid container (compact design)
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "EmoteGrid"
	scrollFrame.Size = UDim2.new(1, -8, 1, -8)  -- Tighter padding
	scrollFrame.Position = UDim2.new(0, 4, 0, 4) -- Tighter padding
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.BorderSizePixel = 0
	scrollFrame.ScrollBarThickness = 3 -- Thinner scrollbar
	scrollFrame.ScrollBarImageColor3 = Config.UI_SETTINGS.colors.primary
	scrollFrame.ScrollBarImageTransparency = 0.6
	scrollFrame.Parent = contentFrame

	-- Wide grid layout for more items per row (original design)
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellPadding = UDim2.new(0, 3, 0, 3) -- Original tight spacing
	gridLayout.CellSize = UDim2.new(0, 40, 0, 40) -- Original smaller icons
	gridLayout.SortOrder = Enum.SortOrder.Name
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	gridLayout.Parent = scrollFrame

	-- Populate emotes in the panel format
	self:PopulateEmoteGridForPanel(scrollFrame)

	-- Update scroll canvas size
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 10)
	end)

	print("EmoteManager: Created panel content for PanelManager integration")
end

--[[
	Populate emote grid for PanelManager integration (original wide design)
--]]
function EmoteManager:PopulateEmoteGridForPanel(container)
	for emoteName, assetId in pairs(EMOTE_MAPPING) do
		local emoteButton = Instance.new("ImageButton")
		emoteButton.Name = emoteName
		emoteButton.Size = UDim2.new(0, 40, 0, 40) -- Original smaller size
		emoteButton.BackgroundColor3 = Config.UI_SETTINGS.colors.backgroundSecondary
		emoteButton.BackgroundTransparency = 0.4 -- Original transparency
		emoteButton.BorderSizePixel = 0
		emoteButton.Image = "rbxassetid://" .. assetId
		emoteButton.Parent = container

		local buttonCorner = Instance.new("UICorner")
		buttonCorner.CornerRadius = UDim.new(0, 8) -- Original smaller radius
		buttonCorner.Parent = emoteButton

		-- Original compact hover effects - no size change for tight layout
		emoteButton.MouseEnter:Connect(function()
			TweenService:Create(emoteButton, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.1,
				-- No size change to maintain tight grid layout
			}):Play()
		end)

		emoteButton.MouseLeave:Connect(function()
			TweenService:Create(emoteButton, TweenInfo.new(0.15), {
				BackgroundTransparency = 0.4,
			}):Play()
		end)

		-- Click handler - same functionality but integrated with PanelManager
		emoteButton.MouseButton1Click:Connect(function()
			self:SelectEmoteFromPanel(emoteName)
		end)
	end
end

--[[
	Select emote from PanelManager integration (closes panel automatically)
--]]
function EmoteManager:SelectEmoteFromPanel(emoteName)
	if not isInitialized then
		warn("EmoteManager: Not initialized")
		return
	end

	if not EMOTE_MAPPING[emoteName] then
		warn("EmoteManager: Invalid emote name:", emoteName)
		return
	end

	if not Network then
		warn("EmoteManager: Network not available")
		return
	end

	-- Show emote locally
	self:ShowEmoteBillboard(player, emoteName)

	-- Send to server to show to other players
	local success, error = pcall(function()
		EventManager:SendToServer("PlayEmote", emoteName)
	end)

	if not success then
		warn("EmoteManager: Failed to send emote to server:", error)
	end

	-- Close the panel through PanelManager
	local PanelManager = require(script.Parent.PanelManager)
	if PanelManager then
		PanelManager:ClosePanel("emotes")
	end

	-- Play sound effect if available
	if SoundManager and SoundManager.PlaySFX then
		pcall(function()
			SoundManager:PlaySFX("buttonClick")
		end)
	end
end

return EmoteManager