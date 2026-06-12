-- Luna – client controller
-- Owns: HUD construction, remote event listeners, sonar input, warning feed, VFX triggers.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player  = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local GridConfig = require(Modules:WaitForChild("GridConfig"))

local Remotes       = ReplicatedStorage:WaitForChild("Remotes")
local RE_SyncGrid      = Remotes:WaitForChild("SyncGrid")
local RE_HazardWarning = Remotes:WaitForChild("HazardWarning")
local RE_HazardLanded  = Remotes:WaitForChild("HazardLanded")
local RE_GameState     = Remotes:WaitForChild("GameState")
local RE_PlayerDied    = Remotes:WaitForChild("PlayerDied")
local RE_SonarRequest  = Remotes:WaitForChild("SonarRequest")
local RE_SonarResult   = Remotes:WaitForChild("SonarResult")

-- ─────────────────────────────────────────────
-- HUD construction
-- ─────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name          = "LunaHUD"
gui.ResetOnSpawn  = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent        = player.PlayerGui

local function frame(parent, size, pos, bg, alpha)
    local f = Instance.new("Frame")
    f.Size = size
    f.Position = pos
    f.BackgroundColor3 = bg or Color3.fromRGB(10,10,20)
    f.BackgroundTransparency = alpha or 0.3
    f.BorderSizePixel = 0
    f.Parent = parent
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0,8)
    c.Parent = f
    return f
end

local function label(parent, size, pos, text, font, color)
    local l = Instance.new("TextLabel")
    l.Size = size
    l.Position = pos
    l.BackgroundTransparency = 1
    l.TextScaled = true
    l.Font = font or Enum.Font.GothamBold
    l.Text = text or ""
    l.TextColor3 = color or Color3.fromRGB(255,255,255)
    l.Parent = parent
    return l
end

-- Timer panel (top-center)
local timerPanel = frame(gui,
    UDim2.new(0,180,0,55),
    UDim2.new(0.5,-90,0,16))
local timerLabel = label(timerPanel, UDim2.new(1,0,0.6,0), UDim2.new(0,0,0,0), "60")
local phaseLabel = label(timerPanel, UDim2.new(1,0,0.4,0), UDim2.new(0,0,0.6,0),
    "SURVIVE", Enum.Font.Gotham, Color3.fromRGB(255,220,80))
phaseLabel.TextScaled = true

-- Alive counter (top-right)
local aliveLabel = label(gui,
    UDim2.new(0,140,0,32),
    UDim2.new(1,-150,0,20),
    "Alive: 0", Enum.Font.Gotham, Color3.fromRGB(180,255,180))
aliveLabel.TextXAlignment = Enum.TextXAlignment.Right

-- Sonar button indicator (bottom-left)
local sonarPanel = frame(gui, UDim2.new(0,140,0,38), UDim2.new(0,16,1,-54))
local sonarLabel = label(sonarPanel, UDim2.new(1,0,1,0), UDim2.new(0,0,0,0),
    "[Q] SONAR", Enum.Font.GothamBold, Color3.fromRGB(80,200,255))

-- Sonar cooldown bar
local sonarBar = Instance.new("Frame")
sonarBar.Size = UDim2.new(1,0,0.15,0)
sonarBar.Position = UDim2.new(0,0,0.85,0)
sonarBar.BackgroundColor3 = Color3.fromRGB(80,200,255)
sonarBar.BorderSizePixel = 0
sonarBar.Parent = sonarPanel

-- Hazard warning list (bottom-right)
local warningScroll = frame(gui, UDim2.new(0,210,0,200), UDim2.new(1,-220,1,-210))
local warningLayout = Instance.new("UIListLayout")
warningLayout.SortOrder = Enum.SortOrder.LayoutOrder
warningLayout.Padding   = UDim.new(0,2)
warningLayout.Parent    = warningScroll

local warningTitle = label(warningScroll, UDim2.new(1,0,0,22), UDim2.new(0,0,0,0),
    "INCOMING", Enum.Font.GothamBold, Color3.fromRGB(255,80,80))
warningTitle.LayoutOrder = -1

-- Center announcement banner
local banner = label(gui,
    UDim2.new(0.55,0,0,70),
    UDim2.new(0.225,0,0.38,0),
    "", Enum.Font.GothamBold, Color3.fromRGB(255,255,255))
banner.TextStrokeTransparency = 0
banner.ZIndex = 10

-- Legend (top-left)
local legendPanel = frame(gui, UDim2.new(0,110,0,130), UDim2.new(0,16,0,16), Color3.fromRGB(5,5,15), 0.25)
label(legendPanel, UDim2.new(1,0,0,18), UDim2.new(0,0,0,0),
    "DANGER KEY", Enum.Font.GothamBold, Color3.fromRGB(200,200,200))

local legendItems = {
    { "0 – Safe",    GridConfig.DANGER_COLORS[0] },
    { "1–2 – Low",   GridConfig.DANGER_COLORS[1] },
    { "3–4 – Med",   GridConfig.DANGER_COLORS[3] },
    { "5–6 – High",  GridConfig.DANGER_COLORS[5] },
    { "7–8 – Doom",  GridConfig.DANGER_COLORS[7] },
}
for i, item in ipairs(legendItems) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,0,0,20)
    row.Position = UDim2.new(0,0,0,18+i*20)
    row.BackgroundTransparency = 1
    row.Parent = legendPanel

    local swatch = Instance.new("Frame")
    swatch.Size = UDim2.new(0,14,0,14)
    swatch.Position = UDim2.new(0,4,0.5,-7)
    swatch.BackgroundColor3 = item[2]
    swatch.BorderSizePixel  = 0
    swatch.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-22,1,0)
    lbl.Position = UDim2.new(0,22,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.Gotham
    lbl.Text = item[1]
    lbl.TextColor3 = Color3.fromRGB(210,210,210)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row
end

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function announce(text, color, duration)
    banner.Text       = text
    banner.TextColor3 = color or Color3.fromRGB(255,255,255)
    task.delay(duration or 3, function()
        if banner.Text == text then banner.Text = "" end
    end)
end

-- ─────────────────────────────────────────────
-- Game state handler
-- ─────────────────────────────────────────────

RE_GameState.OnClientEvent:Connect(function(data)
    local phase = data.phase

    aliveLabel.Text = "Alive: " .. (data.aliveCount or 0)

    if phase == "Countdown" then
        phaseLabel.Text  = "GET READY"
        timerLabel.Text  = "..."
        timerLabel.TextColor3 = Color3.fromRGB(255,220,80)
        announce("GAME STARTING!", Color3.fromRGB(255,220,80), 4)

    elseif phase == "Active" then
        phaseLabel.Text  = "SURVIVE"
        local t = math.ceil(data.timer or 60)
        timerLabel.Text  = tostring(t)
        timerLabel.TextColor3 = t <= 10
            and Color3.fromRGB(255,80,80)
            or  Color3.fromRGB(255,255,255)

    elseif phase == "Overtime" then
        phaseLabel.Text  = "OVERTIME"
        timerLabel.Text  = "OT " .. (data.overtimeStage or 1)
        timerLabel.TextColor3 = Color3.fromRGB(255,60,60)
        if data.overtimeStage == 1 then
            announce("OVERTIME! Forecast shrinking!", Color3.fromRGB(255,80,80), 4)
        elseif data.overtimeStage == 2 then
            announce("STAGE 2 – 2s window!", Color3.fromRGB(255,50,50), 3)
        elseif data.overtimeStage == 3 then
            announce("FINAL STAGE – 1s window!", Color3.fromRGB(220,20,20), 3)
        end

    elseif phase == "Ended" then
        phaseLabel.Text  = ""
        timerLabel.Text  = "END"
        timerLabel.TextColor3 = Color3.fromRGB(255,215,0)
        local winMsg = (data.winner == "Nobody")
            and "No survivors!"
            or  (data.winner .. " wins!")
        announce(winMsg, Color3.fromRGB(255,215,0), 8)
    end
end)

-- ─────────────────────────────────────────────
-- Hazard warning feed
-- ─────────────────────────────────────────────

local activeWarnings = {}  -- [hazard.id] = { row, label, landTime }

local DISPLAY = {
    Standard = { label = "BOMB",    color = Color3.fromRGB(255,100, 50) },
    Cluster  = { label = "CLUSTER", color = Color3.fromRGB(255,180,  0) },
    Laser    = { label = "LASER",   color = Color3.fromRGB( 80,200,255) },
    Meteor   = { label = "METEOR",  color = Color3.fromRGB(255,140,220) },
}

RE_HazardWarning.OnClientEvent:Connect(function(hazard)
    local d = DISPLAY[hazard.hazardType] or { label = "HAZARD", color = Color3.fromRGB(255,255,255) }

    local row = Instance.new("Frame")
    row.Size                = UDim2.new(1,-6,0,30)
    row.BackgroundColor3    = Color3.fromRGB(20,10,10)
    row.BackgroundTransparency = 0.3
    row.BorderSizePixel     = 0
    row.LayoutOrder         = hazard.id
    row.Parent              = warningScroll

    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0,4)
    rc.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1,-8,1,0)
    lbl.Position = UDim2.new(0,6,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Text = d.label
    lbl.TextColor3 = d.color
    lbl.Parent = row

    activeWarnings[hazard.id] = { row = row, lbl = lbl, landTime = hazard.landTime, d = d }

    -- Auto-remove when hazard has landed
    local delay = math.max(0, hazard.landTime - tick()) + 0.3
    task.delay(delay, function()
        if activeWarnings[hazard.id] then
            activeWarnings[hazard.id].row:Destroy()
            activeWarnings[hazard.id] = nil
        end
    end)
end)

-- ─────────────────────────────────────────────
-- Bomb landing VFX
-- ─────────────────────────────────────────────

RE_HazardLanded.OnClientEvent:Connect(function(hazard, affectedTiles)
    -- Flash affected tile parts from the client-visible folder
    local gridFolder = workspace:FindFirstChild("LunaGrid")
    if gridFolder then
        for _, t in ipairs(affectedTiles) do
            local part = gridFolder:FindFirstChild(string.format("Tile_%d_%d", t.row, t.col))
            if part then
                local orig = part.Color
                part.Color = Color3.fromRGB(255, 200, 80)
                task.delay(0.15, function()
                    if part and part.Parent then
                        part.Color = Color3.fromRGB(20,12,12)
                    end
                end)
            end
        end
    end

    -- Simple camera shake
    local camera = workspace.CurrentCamera
    if camera then
        task.spawn(function()
            for i = 1, 6 do
                task.wait(0.03)
                local shake = (7 - i) * 0.2
                camera.CFrame = camera.CFrame
                    * CFrame.new(
                        (math.random() - 0.5) * shake,
                        (math.random() - 0.5) * shake,
                        0
                    )
            end
        end)
    end
end)

-- ─────────────────────────────────────────────
-- Sonar result
-- ─────────────────────────────────────────────

RE_SonarResult.OnClientEvent:Connect(function(sonarData)
    announce("SONAR ACTIVE  (+3s forecast)", Color3.fromRGB(80,200,255), 2)

    local gridFolder = workspace:FindFirstChild("LunaGrid")
    if not gridFolder then return end

    for _, t in ipairs(sonarData) do
        local part = gridFolder:FindFirstChild(string.format("Tile_%d_%d", t.row, t.col))
        if part then
            -- Briefly highlight sonar-revealed tiles cyan
            local orig = part.Color
            part.Color = Color3.fromRGB(80, 200, 255)
            task.delay(0.5, function()
                if part and part.Parent then
                    -- color is restored by next SyncGrid; do nothing
                end
            end)
        end
    end
end)

-- ─────────────────────────────────────────────
-- Player death notification
-- ─────────────────────────────────────────────

RE_PlayerDied.OnClientEvent:Connect(function(deadPlayer)
    if deadPlayer == player then
        announce("YOU WERE ELIMINATED", Color3.fromRGB(255,50,50), 6)
    else
        announce(deadPlayer.Name .. " eliminated", Color3.fromRGB(180,180,180), 2)
    end
end)

-- ─────────────────────────────────────────────
-- Input: Sonar (Q)
-- ─────────────────────────────────────────────

local sonarLastUsed = -GridConfig.SONAR_COOLDOWN  -- allow immediate use on spawn

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode ~= Enum.KeyCode.Q then return end

    local now = tick()
    if now - sonarLastUsed < GridConfig.SONAR_COOLDOWN then
        local left = math.ceil(GridConfig.SONAR_COOLDOWN - (now - sonarLastUsed))
        announce("Sonar on cooldown: " .. left .. "s", Color3.fromRGB(120,120,160), 1.5)
        return
    end

    sonarLastUsed = now
    RE_SonarRequest:FireServer()
end)

-- ─────────────────────────────────────────────
-- Heartbeat: update warning countdowns + sonar bar
-- ─────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
    local now = tick()

    -- Warning countdown labels
    for id, w in pairs(activeWarnings) do
        local left = w.landTime - now
        if left < 0 then continue end
        w.lbl.Text = string.format("%s  %.1fs", w.d.label, left)
        w.lbl.TextColor3 = left < 1.5
            and Color3.fromRGB(255, 50, 50)
            or  w.d.color
    end

    -- Sonar cooldown bar + label
    local elapsed = now - sonarLastUsed
    local ratio   = math.clamp(elapsed / GridConfig.SONAR_COOLDOWN, 0, 1)
    sonarBar.Size = UDim2.new(ratio, 0, 0.12, 0)

    if ratio >= 1 then
        sonarLabel.Text       = "[Q] SONAR  READY"
        sonarLabel.TextColor3 = Color3.fromRGB(80, 200, 255)
        sonarBar.BackgroundColor3 = Color3.fromRGB(80, 200, 255)
    else
        local cdLeft = math.ceil(GridConfig.SONAR_COOLDOWN - elapsed)
        sonarLabel.Text       = string.format("[Q] SONAR  %ds", cdLeft)
        sonarLabel.TextColor3 = Color3.fromRGB(110, 110, 140)
        sonarBar.BackgroundColor3 = Color3.fromRGB(60, 100, 120)
    end
end)
