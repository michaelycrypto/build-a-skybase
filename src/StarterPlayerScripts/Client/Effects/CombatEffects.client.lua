--[[
    CombatEffects.client.lua
    Visual feedback for PvP combat tagging.

    - Highlights enemy characters while they are in combat
    - Brief red flash on each successful hit (Minecraft-style)
    - Auto-cleans on character despawn
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local CombatConfig = require(ReplicatedStorage.Configs.CombatConfig)

local DEFAULT_FILL_COLOR = CombatConfig.HIGHLIGHT_DEFAULT_FILL_COLOR or Color3.fromRGB(255, 0, 0)
local DEFAULT_OUTLINE_COLOR = CombatConfig.HIGHLIGHT_DEFAULT_OUTLINE_COLOR or Color3.fromRGB(255, 0, 0)
local FLASH_WHITE = CombatConfig.HIGHLIGHT_FLASH_WHITE or Color3.fromRGB(255, 255, 255)
local FILL_T = CombatConfig.HIGHLIGHT_DEFAULT_FILL_TRANSPARENCY or 0.15
local OUTLINE_T = CombatConfig.HIGHLIGHT_DEFAULT_OUTLINE_TRANSPARENCY or 0
local FLASH_FILL_T = CombatConfig.HIGHLIGHT_FLASH_FILL_TRANSPARENCY or 0.05
local FLASH_DUR = CombatConfig.FLASH_DURATION_SEC or 0.12
local FLASH_BACK_DUR = CombatConfig.FLASH_FADE_BACK_SEC or 0.12

local characterState = {} -- [Model] = { highlight, conns = {}, flashTween }

local function isLocalCharacter(character)
    local owner = Players:GetPlayerFromCharacter(character)
    return owner == LocalPlayer
end

local function ensureHighlight(character)
    local state = characterState[character]
    if not state then
        state = { conns = {} }
        characterState[character] = state
    end

    if not state.highlight then
        local hl = Instance.new("Highlight")
        hl.DepthMode = Enum.HighlightDepthMode.Occluded
        hl.FillColor = DEFAULT_FILL_COLOR
        hl.OutlineColor = DEFAULT_OUTLINE_COLOR
        hl.FillTransparency = FILL_T
        hl.OutlineTransparency = OUTLINE_T
        hl.Adornee = character
        hl.Enabled = false
        hl.Parent = character
        state.highlight = hl
    end

    return state.highlight, state
end

local function removeHighlight(character)
    local state = characterState[character]
    if not state then return end
    if state.flashTween then
        pcall(function()
            state.flashTween:Cancel()
        end)
        state.flashTween = nil
    end
    if state.highlight then
        local hl = state.highlight
        state.highlight = nil
        pcall(function()
            hl:Destroy()
        end)
    end
end

local function cleanupCharacter(character)
    local state = characterState[character]
    if not state then return end
    if state.conns then
        for _, c in ipairs(state.conns) do
            pcall(function()
                c:Disconnect()
            end)
        end
        state.conns = nil
    end
    removeHighlight(character)
    characterState[character] = nil
end

local function setHighlightEnabled(character, enabled)
    local hl = ensureHighlight(character)
    if hl then
        hl.Enabled = enabled and true or false
        if not enabled then
            -- Reset to defaults when disabling
            hl.FillColor = DEFAULT_FILL_COLOR
            hl.OutlineColor = DEFAULT_OUTLINE_COLOR
        end
    end
end

local function flashHit(character)
    local state = characterState[character] or {}
    characterState[character] = state
    local hl = ensureHighlight(character)
    if not hl then return end

    -- Ensure visible during flash
    hl.Enabled = true

    -- Cancel any existing tween
    if state.flashTween then
        pcall(function()
            state.flashTween:Cancel()
        end)
        state.flashTween = nil
    end

    -- Tween to white fill (flash) with stronger opacity, outline remains red
    local toWhite = TweenService:Create(hl, TweenInfo.new(FLASH_DUR, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        FillColor = FLASH_WHITE,
        FillTransparency = FLASH_FILL_T
    })
    state.flashTween = toWhite
    toWhite:Play()
    toWhite.Completed:Once(function()
        -- Step 1: snap/tween quickly to red color (keep strong opacity)
        local toRed = TweenService:Create(hl, TweenInfo.new(math.max(FLASH_DUR, 0.05), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            FillColor = DEFAULT_FILL_COLOR
        })
        state.flashTween = toRed
        toRed:Play()
        toRed.Completed:Once(function()
            -- Step 2: fade fill opacity to default (more see-through red)
            local fadeOpacity = TweenService:Create(hl, TweenInfo.new(FLASH_BACK_DUR, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                FillTransparency = FILL_T
            })
            state.flashTween = fadeOpacity
            fadeOpacity:Play()
            fadeOpacity.Completed:Once(function()
                state.flashTween = nil
                -- If not in combat anymore, disable highlight
                local inCombat = character:GetAttribute("IsInCombat") == true
                if not inCombat then
                    setHighlightEnabled(character, false)
                end
            end)
        end)
    end)
end

local function trackCharacter(character)
    if not character or not character:IsA("Model") then return end
    if isLocalCharacter(character) then
        -- Do not highlight the local player's own character
        return
    end

    -- Attribute: IsInCombat
    table.insert(characterState[character] and characterState[character].conns or (function()
        characterState[character] = { conns = {} }
        return characterState[character].conns
    end)(), character:GetAttributeChangedSignal("IsInCombat"):Connect(function()
        local isInCombat = character:GetAttribute("IsInCombat") == true
        setHighlightEnabled(character, isInCombat)
    end))

    -- Attribute: LastHitAt (trigger red flash)
    table.insert(characterState[character].conns, character:GetAttributeChangedSignal("LastHitAt"):Connect(function()
        -- Only flash if currently considered in combat; otherwise a stale attribute change shouldn't show
        if character:GetAttribute("IsInCombat") == true then
            flashHit(character)
        else
            -- If not in combat, create a quick flash and then disable
            flashHit(character)
            task.delay((FLASH_DUR + FLASH_BACK_DUR) + 0.02, function()
                setHighlightEnabled(character, false)
            end)
        end
    end))

    -- Initialize current state if attributes already exist
    local isInCombatNow = character:GetAttribute("IsInCombat") == true
    if isInCombatNow then
        setHighlightEnabled(character, true)
    end

    -- Cleanup when character is removed
    table.insert(characterState[character].conns, character.AncestryChanged:Connect(function(_, parent)
        if not parent then
            cleanupCharacter(character)
        end
    end))
end

local function onPlayerAdded(player)
    -- Track existing character if present
    if player.Character then
        trackCharacter(player.Character)
    end
    -- Track future characters
    player.CharacterAdded:Connect(function(character)
        trackCharacter(character)
    end)
end

-- Initialize for current players
for _, plr in ipairs(Players:GetPlayers()) do
    onPlayerAdded(plr)
end
-- Track future players
Players.PlayerAdded:Connect(onPlayerAdded)
-- Cleanup on player removing
Players.PlayerRemoving:Connect(function(plr)
    local character = plr.Character
    if character then
        cleanupCharacter(character)
    end
end)

-- Track mob models in workspace.MobEntities for the same combat visuals
local function trackMobFolder(folder)
    if not folder or not folder:IsA("Folder") then return end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Model") then
            trackCharacter(child)
        end
    end
    folder.ChildAdded:Connect(function(inst)
        if inst:IsA("Model") then
            trackCharacter(inst)
        end
    end)
    folder.ChildRemoved:Connect(function(inst)
        if inst:IsA("Model") then
            cleanupCharacter(inst)
        end
    end)
end

local function ensureMobTracking()
    local folder = Workspace:FindFirstChild("MobEntities")
    if folder then
        trackMobFolder(folder)
    end
    Workspace.ChildAdded:Connect(function(inst)
        if inst:IsA("Folder") and inst.Name == "MobEntities" then
            trackMobFolder(inst)
        end
    end)
end

ensureMobTracking()
