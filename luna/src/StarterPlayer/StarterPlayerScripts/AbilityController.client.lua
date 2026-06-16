-- Luna – in-match ability UI and input
-- Shows 3 ability slots at bottom-center (Z / X / C keys).

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService     = game:GetService("TweenService")

local player   = Players.LocalPlayer
local Modules  = ReplicatedStorage:WaitForChild("Modules")
local AbilityConfig = require(Modules:WaitForChild("AbilityConfig"))

local Remotes           = ReplicatedStorage:WaitForChild("Remotes")
local RE_ActivateAbility = Remotes:WaitForChild("ActivateAbility")
local RE_AbilityFeedback = Remotes:WaitForChild("AbilityFeedback")
local RE_PlayerData      = Remotes:WaitForChild("PlayerData")
local RE_GameState       = Remotes:WaitForChild("GameState")

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────

local loadout       = { Movement="BlinkStep", Utility="FuturePing", Defensive="TemporalShield" }
local cooldowns     = {}  -- [abilityName] = { startTime, duration }
local activePhase   = false

-- ─────────────────────────────────────────────
-- HUD
-- ─────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "AbilityHUD"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

-- Ability bar: 3 slots centered at bottom
local barFrame = Instance.new("Frame")
barFrame.Size             = UDim2.new(0,380,0,90)
barFrame.Position         = UDim2.new(0.5,-190,1,-105)
barFrame.BackgroundTransparency = 1
barFrame.Parent           = gui

local slotUIs = {}  -- [slotName] = { frame, icon, nameLabel, keyLabel, cdOverlay, cdLabel }

local SLOT_ORDER = { "Movement", "Utility", "Defensive" }
local KEY_LABELS = { Movement="Z", Utility="X", Defensive="C" }
local SLOT_COLORS = { Movement=Color3.fromRGB(100,180,255), Utility=Color3.fromRGB(255,220,60), Defensive=Color3.fromRGB(255,160,40) }

for i, slot in ipairs(SLOT_ORDER) do
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(0,110,0,86)
    f.Position         = UDim2.new(0,(i-1)*128,0,0)
    f.BackgroundColor3 = Color3.fromRGB(12,12,22)
    f.BackgroundTransparency = 0.2
    f.BorderSizePixel  = 0
    f.Parent           = barFrame
    local fc = Instance.new("UICorner"); fc.CornerRadius=UDim.new(0,8); fc.Parent=f

    -- Colored top bar
    local topBar = Instance.new("Frame")
    topBar.Size             = UDim2.new(1,0,0,4)
    topBar.BackgroundColor3 = SLOT_COLORS[slot]
    topBar.BorderSizePixel  = 0
    topBar.Parent           = f
    local tbc = Instance.new("UICorner"); tbc.CornerRadius=UDim.new(0,4); tbc.Parent=topBar

    -- Key hint
    local keyLbl = Instance.new("TextLabel")
    keyLbl.Size               = UDim2.new(0,22,0,22)
    keyLbl.Position           = UDim2.new(0,4,0,6)
    keyLbl.BackgroundColor3   = SLOT_COLORS[slot]
    keyLbl.BackgroundTransparency = 0.3
    keyLbl.BorderSizePixel    = 0
    keyLbl.TextScaled         = true
    keyLbl.Font               = Enum.Font.GothamBold
    keyLbl.Text               = KEY_LABELS[slot]
    keyLbl.TextColor3         = Color3.fromRGB(255,255,255)
    keyLbl.Parent             = f
    local klc = Instance.new("UICorner"); klc.CornerRadius=UDim.new(0,4); klc.Parent=keyLbl

    -- Ability name
    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size               = UDim2.new(1,-8,0,24)
    nameLbl.Position           = UDim2.new(0,4,0,30)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextScaled         = true
    nameLbl.Font               = Enum.Font.GothamBold
    nameLbl.Text               = "—"
    nameLbl.TextColor3         = Color3.fromRGB(220,220,255)
    nameLbl.TextXAlignment     = Enum.TextXAlignment.Left
    nameLbl.Parent             = f

    -- Cooldown overlay
    local cdOverlay = Instance.new("Frame")
    cdOverlay.Size             = UDim2.new(1,0,1,0)
    cdOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
    cdOverlay.BackgroundTransparency = 1
    cdOverlay.BorderSizePixel  = 0
    cdOverlay.ZIndex           = 5
    cdOverlay.Parent           = f
    local cdc = Instance.new("UICorner"); cdc.CornerRadius=UDim.new(0,8); cdc.Parent=cdOverlay

    -- Cooldown label
    local cdLbl = Instance.new("TextLabel")
    cdLbl.Size               = UDim2.new(1,0,1,0)
    cdLbl.BackgroundTransparency = 1
    cdLbl.TextScaled         = true
    cdLbl.Font               = Enum.Font.GothamBold
    cdLbl.Text               = ""
    cdLbl.TextColor3         = Color3.fromRGB(255,255,255)
    cdLbl.ZIndex             = 6
    cdLbl.Parent             = cdOverlay

    -- Status bar (fills as cooldown refills)
    local statusBar = Instance.new("Frame")
    statusBar.Size             = UDim2.new(1,0,0,3)
    statusBar.Position         = UDim2.new(0,0,1,-3)
    statusBar.BackgroundColor3 = SLOT_COLORS[slot]
    statusBar.BorderSizePixel  = 0
    statusBar.ZIndex           = 7
    statusBar.Parent           = f

    slotUIs[slot] = { frame=f, nameLbl=nameLbl, cdOverlay=cdOverlay, cdLbl=cdLbl, statusBar=statusBar }
end

-- Flash overlay for feedback
local flashLabel = Instance.new("TextLabel")
flashLabel.Size               = UDim2.new(0.5,0,0,50)
flashLabel.Position           = UDim2.new(0.25,0,0.75,0)
flashLabel.BackgroundTransparency = 1
flashLabel.TextScaled         = true
flashLabel.Font               = Enum.Font.GothamBold
flashLabel.Text               = ""
flashLabel.TextColor3         = Color3.fromRGB(255,255,255)
flashLabel.TextStrokeTransparency = 0
flashLabel.ZIndex             = 20
flashLabel.Parent             = gui

local function flash(text, color, dur)
    flashLabel.Text       = text
    flashLabel.TextColor3 = color or Color3.fromRGB(255,255,255)
    task.delay(dur or 2, function()
        if flashLabel.Text == text then flashLabel.Text="" end
    end)
end

-- ─────────────────────────────────────────────
-- Refresh slot UI from loadout
-- ─────────────────────────────────────────────

local function refreshSlotUI()
    for _, slot in ipairs(SLOT_ORDER) do
        local abilityName = loadout[slot]
        local cfg = abilityName and AbilityConfig.ABILITIES[abilityName]
        local ui = slotUIs[slot]
        if ui then
            ui.nameLbl.Text = cfg and cfg.name or "—"
        end
    end
end

-- ─────────────────────────────────────────────
-- Cooldown handling
-- ─────────────────────────────────────────────

local function startCooldown(abilityName, duration)
    cooldowns[abilityName] = { startTime=tick(), duration=duration }
end

-- ─────────────────────────────────────────────
-- Heartbeat: update cooldown overlays
-- ─────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
    local now = tick()
    for _, slot in ipairs(SLOT_ORDER) do
        local abilityName = loadout[slot]
        local ui = slotUIs[slot]
        if not ui or not abilityName then continue end

        local cd = cooldowns[abilityName]
        if cd then
            local elapsed = now - cd.startTime
            local ratio   = math.clamp(elapsed / cd.duration, 0, 1)
            if ratio >= 1 then
                cooldowns[abilityName] = nil
                ui.cdOverlay.BackgroundTransparency = 1
                ui.cdLbl.Text = ""
                ui.statusBar.Size = UDim2.new(1,0,0,3)
            else
                local left = cd.duration - elapsed
                ui.cdOverlay.BackgroundTransparency = 0.55
                ui.cdLbl.Text = string.format("%.1f", left)
                ui.statusBar.Size = UDim2.new(ratio,0,0,3)
            end
        else
            ui.cdOverlay.BackgroundTransparency = 1
            ui.cdLbl.Text = ""
            ui.statusBar.Size = UDim2.new(1,0,0,3)
        end
    end
end)

-- ─────────────────────────────────────────────
-- Input: Z / X / C
-- ─────────────────────────────────────────────

local KEY_TO_SLOT = { Z="Movement", X="Utility", C="Defensive" }

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if not activePhase then return end

    local slot = KEY_TO_SLOT[input.KeyCode.Name]
    if not slot then return end

    local abilityName = loadout[slot]
    if not abilityName then return end

    local cd = cooldowns[abilityName]
    if cd then
        local left = math.ceil(cd.duration - (tick()-cd.startTime))
        flash("Cooldown: "..left.."s", Color3.fromRGB(150,150,180), 1.5)
        return
    end

    RE_ActivateAbility:FireServer(abilityName)
end)

-- ─────────────────────────────────────────────
-- Server feedback
-- ─────────────────────────────────────────────

RE_AbilityFeedback.OnClientEvent:Connect(function(eventType, abilityName, data)
    if eventType == "Used" then
        local cfg = AbilityConfig.ABILITIES[abilityName]
        local dur = type(data)=="number" and data or (cfg and cfg.cooldown or 10)
        startCooldown(abilityName, dur)
        flash(cfg and cfg.name or abilityName, cfg and cfg.color or Color3.fromRGB(255,255,255), 1.5)

    elseif eventType == "OnCooldown" then
        local left = type(data)=="number" and math.ceil(data) or "?"
        flash("Cooldown: "..left.."s", Color3.fromRGB(150,150,180), 1.5)

    elseif eventType == "ShieldActive" then
        flash("SHIELD ACTIVE", Color3.fromRGB(255,160,40), 3)

    elseif eventType == "ShieldConsumed" then
        flash("SHIELD BLOCKED IT", Color3.fromRGB(255,200,80), 2)

    elseif eventType == "DampenerActive" then
        flash("DAMPENER ACTIVE", Color3.fromRGB(60,200,100), 3)

    elseif eventType == "DampenerExpired" then
        flash("Dampener expired", Color3.fromRGB(100,150,100), 1.5)

    elseif eventType == "FuturePing" and type(abilityName)=="table" then
        -- abilityName is actually pingData here
        flash("FUTURE PING", Color3.fromRGB(255,220,60), 2)
        local gridFolder = workspace:FindFirstChild("LunaGrid")
        if gridFolder then
            for _, t in ipairs(abilityName) do
                local part = gridFolder:FindFirstChild(("Tile_%d_%d"):format(t.row,t.col))
                if part then
                    local orig = part.Color
                    part.Color = Color3.fromRGB(255,220,60)
                    task.delay(0.4, function() end) -- server sync restores color
                end
            end
        end

    elseif eventType == "SafeBeacon" then
        flash("SAFE BEACON PLACED", Color3.fromRGB(60,255,120), 2)

    elseif eventType == "ForecastSteal" and type(abilityName)=="table" then
        flash("FORECAST STOLEN", Color3.fromRGB(255,100,200), 2)
    end
end)

-- ─────────────────────────────────────────────
-- Sync loadout + phase changes
-- ─────────────────────────────────────────────

RE_PlayerData.OnClientEvent:Connect(function(data)
    if data.loadout then
        loadout = data.loadout
        refreshSlotUI()
    end
end)

RE_GameState.OnClientEvent:Connect(function(data)
    local phase = data.phase
    activePhase = (phase=="Active" or phase=="Warmup" or phase=="Overtime")
    gui.Enabled = activePhase
end)

gui.Enabled = false
refreshSlotUI()
