-- Luna – client HUD controller
-- Owns: danger HUD, timer, warning feed, sonar, camera shake, post-game results screen.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local Modules    = ReplicatedStorage:WaitForChild("Modules")
local GridConfig = require(Modules:WaitForChild("GridConfig"))

local Remotes          = ReplicatedStorage:WaitForChild("Remotes")
local RE_SyncGrid      = Remotes:WaitForChild("SyncGrid")
local RE_HazardWarning = Remotes:WaitForChild("HazardWarning")
local RE_HazardLanded  = Remotes:WaitForChild("HazardLanded")
local RE_GameState     = Remotes:WaitForChild("GameState")
local RE_PlayerDied    = Remotes:WaitForChild("PlayerDied")
local RE_SonarRequest  = Remotes:WaitForChild("SonarRequest")
local RE_SonarResult   = Remotes:WaitForChild("SonarResult")
local RE_PostGameStats = Remotes:WaitForChild("PostGameStats")

-- ─────────────────────────────────────────────
-- HUD
-- ─────────────────────────────────────────────

local gui = Instance.new("ScreenGui")
gui.Name           = "LunaHUD"
gui.ResetOnSpawn   = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent         = player.PlayerGui

local function frame(parent,size,pos,bg,alpha)
    local f=Instance.new("Frame")
    f.Size=size; f.Position=pos; f.BackgroundColor3=bg or Color3.fromRGB(10,10,20)
    f.BackgroundTransparency=alpha or 0.3; f.BorderSizePixel=0; f.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=f
    return f
end

local function label(parent,size,pos,text,font,color,xa)
    local l=Instance.new("TextLabel")
    l.Size=size; l.Position=pos; l.BackgroundTransparency=1; l.TextScaled=true
    l.Font=font or Enum.Font.GothamBold; l.Text=text or ""
    l.TextColor3=color or Color3.fromRGB(255,255,255)
    l.TextXAlignment=xa or Enum.TextXAlignment.Center; l.Parent=parent
    return l
end

-- Timer panel
local timerPanel = frame(gui,UDim2.new(0,180,0,55),UDim2.new(0.5,-90,0,16))
local timerLabel = label(timerPanel,UDim2.new(1,0,0.6,0),UDim2.new(0,0,0,0),"—")
local phaseLabel = label(timerPanel,UDim2.new(1,0,0.4,0),UDim2.new(0,0,0.6,0),
    "WAITING",Enum.Font.Gotham,Color3.fromRGB(255,220,80))

-- Alive counter
local aliveLabel = label(gui,UDim2.new(0,140,0,32),UDim2.new(1,-150,0,20),
    "Alive: 0",Enum.Font.Gotham,Color3.fromRGB(180,255,180))
aliveLabel.TextXAlignment=Enum.TextXAlignment.Right

-- Sonar panel
local sonarPanel = frame(gui,UDim2.new(0,145,0,38),UDim2.new(0,16,1,-54))
local sonarLabel = label(sonarPanel,UDim2.new(1,0,0.85,0),UDim2.new(0,0,0,0),
    "[Q] SONAR  READY",Enum.Font.GothamBold,Color3.fromRGB(80,200,255))
local sonarBar=Instance.new("Frame")
sonarBar.Size=UDim2.new(1,0,0.12,0); sonarBar.Position=UDim2.new(0,0,0.88,0)
sonarBar.BackgroundColor3=Color3.fromRGB(80,200,255); sonarBar.BorderSizePixel=0
sonarBar.Parent=sonarPanel

-- Warning feed
local warningPanel = frame(gui,UDim2.new(0,215,0,200),UDim2.new(1,-224,1,-210))
local warningLayout=Instance.new("UIListLayout")
warningLayout.SortOrder=Enum.SortOrder.LayoutOrder
warningLayout.Padding=UDim.new(0,2); warningLayout.Parent=warningPanel
label(warningPanel,UDim2.new(1,0,0,22),UDim2.new(0,0,0,0),
    "INCOMING",Enum.Font.GothamBold,Color3.fromRGB(255,80,80)).LayoutOrder=-1

-- Center announcement
local banner=label(gui,UDim2.new(0.6,0,0,70),UDim2.new(0.2,0,0.38,0),
    "",Enum.Font.GothamBold,Color3.fromRGB(255,255,255))
banner.TextStrokeTransparency=0; banner.ZIndex=10

-- Danger legend
local legendPanel=frame(gui,UDim2.new(0,112,0,132),UDim2.new(0,16,0,16),Color3.fromRGB(5,5,15),0.25)
label(legendPanel,UDim2.new(1,0,0,18),UDim2.new(0,0,0,0),"DANGER",Enum.Font.GothamBold,Color3.fromRGB(200,200,200))
local legendItems={
    {"0 – Safe",GridConfig.DANGER_COLORS[0]},{"1–2 – Low",GridConfig.DANGER_COLORS[1]},
    {"3–4 – Med",GridConfig.DANGER_COLORS[3]},{"5–6 – High",GridConfig.DANGER_COLORS[5]},
    {"7–8 – Doom",GridConfig.DANGER_COLORS[7]},
}
for i,item in ipairs(legendItems) do
    local row=Instance.new("Frame"); row.Size=UDim2.new(1,0,0,20)
    row.Position=UDim2.new(0,0,0,18+i*20); row.BackgroundTransparency=1; row.Parent=legendPanel
    local sw=Instance.new("Frame"); sw.Size=UDim2.new(0,14,0,14)
    sw.Position=UDim2.new(0,4,0.5,-7); sw.BackgroundColor3=item[2]; sw.BorderSizePixel=0; sw.Parent=row
    local l=Instance.new("TextLabel"); l.Size=UDim2.new(1,-22,1,0); l.Position=UDim2.new(0,22,0,0)
    l.BackgroundTransparency=1; l.TextScaled=true; l.Font=Enum.Font.Gotham; l.Text=item[1]
    l.TextColor3=Color3.fromRGB(210,210,210); l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=row
end

-- Phase banner (PreGame / Warmup)
local phaseBanner=label(gui,UDim2.new(0.5,0,0,50),UDim2.new(0.25,0,0.12,0),
    "",Enum.Font.GothamBold,Color3.fromRGB(255,220,80))
phaseBanner.TextStrokeTransparency=0; phaseBanner.ZIndex=9

-- ─────────────────────────────────────────────
-- Post-game results screen
-- ─────────────────────────────────────────────

local resultsGui = nil

local function showResults(data)
    if resultsGui then resultsGui:Destroy() end
    resultsGui = Instance.new("ScreenGui")
    resultsGui.Name="LunaResults"; resultsGui.ResetOnSpawn=false
    resultsGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    resultsGui.Parent=player.PlayerGui

    -- Dark background
    local bg=Instance.new("Frame")
    bg.Size=UDim2.new(1,0,1,0); bg.BackgroundColor3=Color3.fromRGB(0,0,0)
    bg.BackgroundTransparency=0.45; bg.BorderSizePixel=0; bg.Parent=resultsGui

    -- Card
    local card=Instance.new("Frame")
    card.Size=UDim2.new(0,560,0,520); card.Position=UDim2.new(0.5,-280,0.5,-260)
    card.BackgroundColor3=Color3.fromRGB(10,10,22); card.BackgroundTransparency=0.05
    card.BorderSizePixel=0; card.Parent=resultsGui
    local cc=Instance.new("UICorner"); cc.CornerRadius=UDim.new(0,14); cc.Parent=card

    -- Placement
    local placementText = data.placement==1 and "1st  WINNER!" or
        data.placement==2 and "2nd Place" or data.placement==3 and "3rd Place" or
        ("#"..data.placement.." Place")
    local placementColor = data.placement==1 and Color3.fromRGB(255,215,0)
        or data.placement<=3 and Color3.fromRGB(200,200,200)
        or Color3.fromRGB(160,120,120)

    label(card,UDim2.new(1,0,0,60),UDim2.new(0,0,0,10),placementText,
        Enum.Font.GothamBold,placementColor)
    label(card,UDim2.new(1,0,0,26),UDim2.new(0,0,0,68),"POST GAME REPORT",
        Enum.Font.Gotham,Color3.fromRGB(140,140,160))

    -- Stats
    local statData = {
        {"Survived",           (data.surviveTime or 0).."s"},
        {"Near Misses",        tostring(data.nearMisses or 0)},
        {"Players in match",   tostring(data.totalPlayers or 0)},
    }
    for i,s in ipairs(statData) do
        label(card,UDim2.new(0.45,0,0,28),UDim2.new(0.04,0,0,100+i*38),
            s[1],Enum.Font.Gotham,Color3.fromRGB(160,160,180),Enum.TextXAlignment.Left)
        label(card,UDim2.new(0.4,0,0,28),UDim2.new(0.54,0,0,100+i*38),
            s[2],Enum.Font.GothamBold,Color3.fromRGB(220,220,255),Enum.TextXAlignment.Left)
    end

    -- Medals
    local medY = 100 + #statData*38 + 14
    label(card,UDim2.new(1,0,0,24),UDim2.new(0,0,0,medY),"MEDALS",
        Enum.Font.GothamBold,Color3.fromRGB(255,200,60))
    medY += 26
    if data.medals and #data.medals>0 then
        for _,medal in ipairs(data.medals) do
            label(card,UDim2.new(0.9,0,0,24),UDim2.new(0.05,0,0,medY),
                medal.name.."  +"..medal.xp.." XP",
                Enum.Font.GothamBold,Color3.fromRGB(255,215,0),Enum.TextXAlignment.Left)
            medY += 26
        end
    else
        label(card,UDim2.new(0.9,0,0,24),UDim2.new(0.05,0,0,medY),
            "No medals this round.",Enum.Font.Gotham,Color3.fromRGB(110,110,130),Enum.TextXAlignment.Left)
        medY += 26
    end

    -- New unlocks
    if data.newUnlocks and #data.newUnlocks>0 then
        medY += 8
        label(card,UDim2.new(1,0,0,24),UDim2.new(0,0,0,medY),"UNLOCKED",
            Enum.Font.GothamBold,Color3.fromRGB(100,200,255))
        medY += 26
        for _,u in ipairs(data.newUnlocks) do
            label(card,UDim2.new(0.9,0,0,22),UDim2.new(0.05,0,0,medY),
                (u.type=="ability" and "Ability: " or "Skin: ")..u.id,
                Enum.Font.Gotham,Color3.fromRGB(80,200,255),Enum.TextXAlignment.Left)
            medY += 24
        end
    end

    -- XP / Credits gained
    medY += 8
    local xpLine = "+"..( data.xpGain or 0).." XP"
    if data.newLevel and data.oldLevel and data.newLevel>data.oldLevel then
        xpLine ..= "  →  Level "..data.newLevel.." !"
    end
    label(card,UDim2.new(0.9,0,0,28),UDim2.new(0.05,0,0,medY),xpLine,
        Enum.Font.GothamBold,Color3.fromRGB(100,180,255),Enum.TextXAlignment.Left)
    label(card,UDim2.new(0.9,0,0,26),UDim2.new(0.05,0,0,medY+30),
        "+"..( data.creditGain or 0).." Credits",
        Enum.Font.Gotham,Color3.fromRGB(255,200,60),Enum.TextXAlignment.Left)

    -- Auto-close after 10 seconds
    task.delay(10, function()
        if resultsGui and resultsGui.Parent then resultsGui:Destroy() end
    end)
end

RE_PostGameStats.OnClientEvent:Connect(showResults)

-- ─────────────────────────────────────────────
-- Helpers
-- ─────────────────────────────────────────────

local function announce(text,color,dur)
    banner.Text=text; banner.TextColor3=color or Color3.fromRGB(255,255,255)
    task.delay(dur or 3, function() if banner.Text==text then banner.Text="" end end)
end

-- ─────────────────────────────────────────────
-- Game state
-- ─────────────────────────────────────────────

RE_GameState.OnClientEvent:Connect(function(data)
    aliveLabel.Text="Alive: "..(data.aliveCount or 0)
    local phase=data.phase

    if phase=="Lobby" then
        phaseLabel.Text="LOBBY"; timerLabel.Text="—"
        phaseBanner.Text=""
        timerLabel.TextColor3=Color3.fromRGB(200,200,200)

    elseif phase=="Countdown" then
        phaseLabel.Text="GET READY"; timerLabel.Text="..."
        timerLabel.TextColor3=Color3.fromRGB(255,220,80)
        phaseBanner.Text="Match starting!"
        announce("MATCH STARTING!",Color3.fromRGB(255,220,80),5)

    elseif phase=="PreGame" then
        phaseLabel.Text="PRE-GAME"
        timerLabel.Text=math.ceil(data.timer or 8).."s"
        phaseBanner.Text="Study the grid"
        timerLabel.TextColor3=Color3.fromRGB(200,200,200)

    elseif phase=="Warmup" then
        phaseLabel.Text="WARMUP"
        timerLabel.Text=math.ceil(data.timer or 10).."s"
        phaseBanner.Text="Warmup – low hazards"
        timerLabel.TextColor3=Color3.fromRGB(200,255,200)

    elseif phase=="Active" then
        phaseBanner.Text=""
        phaseLabel.Text="SURVIVE"
        local t=math.ceil(data.timer or 60)
        timerLabel.Text=tostring(t)
        timerLabel.TextColor3=t<=10 and Color3.fromRGB(255,80,80) or Color3.fromRGB(255,255,255)

    elseif phase=="Overtime" then
        phaseBanner.Text=""
        phaseLabel.Text="OVERTIME"
        timerLabel.Text="OT "..(data.overtimeStage or 1)
        timerLabel.TextColor3=Color3.fromRGB(255,60,60)
        local msgs={"OVERTIME! Forecast shrinking!","STAGE 2 – 2s window!","FINAL STAGE – 1s window!"}
        if msgs[data.overtimeStage] then announce(msgs[data.overtimeStage],Color3.fromRGB(255,80,80),4) end

    elseif phase=="PostGame" then
        phaseBanner.Text=""
        phaseLabel.Text=""; timerLabel.Text="END"
        timerLabel.TextColor3=Color3.fromRGB(255,215,0)
        local msg=data.winner=="Nobody" and "No survivors!" or (data.winner.." wins!")
        announce(msg,Color3.fromRGB(255,215,0),8)
    end
end)

-- ─────────────────────────────────────────────
-- Hazard warnings
-- ─────────────────────────────────────────────

local activeWarnings={}
local DISPLAY={
    Standard={label="BOMB",   color=Color3.fromRGB(255,100,50)},
    Cluster ={label="CLUSTER",color=Color3.fromRGB(255,180, 0)},
    Laser   ={label="LASER",  color=Color3.fromRGB( 80,200,255)},
    Meteor  ={label="METEOR", color=Color3.fromRGB(255,140,220)},
}

RE_HazardWarning.OnClientEvent:Connect(function(hazard)
    local d=DISPLAY[hazard.hazardType] or {label="HAZARD",color=Color3.fromRGB(255,255,255)}
    local row=Instance.new("Frame")
    row.Size=UDim2.new(1,-6,0,30); row.BackgroundColor3=Color3.fromRGB(20,10,10)
    row.BackgroundTransparency=0.3; row.BorderSizePixel=0
    row.LayoutOrder=hazard.id; row.Parent=warningPanel
    local rc=Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,4); rc.Parent=row
    local lbl_=Instance.new("TextLabel"); lbl_.Size=UDim2.new(1,-8,1,0)
    lbl_.Position=UDim2.new(0,6,0,0); lbl_.BackgroundTransparency=1
    lbl_.TextScaled=true; lbl_.Font=Enum.Font.GothamBold
    lbl_.TextXAlignment=Enum.TextXAlignment.Left
    lbl_.Text=d.label; lbl_.TextColor3=d.color; lbl_.Parent=row
    activeWarnings[hazard.id]={row=row,lbl=lbl_,landTime=hazard.landTime,d=d}
    task.delay(math.max(0,hazard.landTime-tick())+0.3, function()
        if activeWarnings[hazard.id] then
            activeWarnings[hazard.id].row:Destroy(); activeWarnings[hazard.id]=nil
        end
    end)
end)

-- ─────────────────────────────────────────────
-- Hazard landing VFX
-- ─────────────────────────────────────────────

RE_HazardLanded.OnClientEvent:Connect(function(hazard, affectedTiles)
    local gf=workspace:FindFirstChild("LunaGrid")
    if gf then
        for _,t in ipairs(affectedTiles) do
            local part=gf:FindFirstChild(("Tile_%d_%d"):format(t.row,t.col))
            if part then
                part.Color=Color3.fromRGB(255,200,80)
                task.delay(0.15, function() if part and part.Parent then part.Color=Color3.fromRGB(20,12,12) end end)
            end
        end
    end
    local camera=workspace.CurrentCamera
    if camera then task.spawn(function()
        for i=1,6 do task.wait(0.03)
            local s=(7-i)*0.2
            camera.CFrame=camera.CFrame*CFrame.new((math.random()-0.5)*s,(math.random()-0.5)*s,0)
        end
    end) end
end)

-- ─────────────────────────────────────────────
-- Sonar
-- ─────────────────────────────────────────────

RE_SonarResult.OnClientEvent:Connect(function(sonarData)
    announce("SONAR  +3s forecast",Color3.fromRGB(80,200,255),2)
    local gf=workspace:FindFirstChild("LunaGrid"); if not gf then return end
    for _,t in ipairs(sonarData) do
        local part=gf:FindFirstChild(("Tile_%d_%d"):format(t.row,t.col))
        if part then part.Color=Color3.fromRGB(80,200,255) end
    end
end)

-- ─────────────────────────────────────────────
-- Player death
-- ─────────────────────────────────────────────

RE_PlayerDied.OnClientEvent:Connect(function(deadPlayer)
    if deadPlayer==player then announce("YOU WERE ELIMINATED",Color3.fromRGB(255,50,50),6)
    else announce(deadPlayer.Name.." eliminated",Color3.fromRGB(180,180,180),2) end
end)

-- ─────────────────────────────────────────────
-- Sonar input (Q key legacy)
-- ─────────────────────────────────────────────

local sonarLastUsed=-GridConfig.SONAR_COOLDOWN
UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode~=Enum.KeyCode.Q then return end
    local now=tick()
    if now-sonarLastUsed<GridConfig.SONAR_COOLDOWN then
        announce("Sonar: "..math.ceil(GridConfig.SONAR_COOLDOWN-(now-sonarLastUsed)).."s",Color3.fromRGB(120,120,160),1.5)
        return
    end
    sonarLastUsed=now; RE_SonarRequest:FireServer()
end)

-- ─────────────────────────────────────────────
-- Heartbeat: warnings + sonar bar
-- ─────────────────────────────────────────────

RunService.Heartbeat:Connect(function()
    local now=tick()
    for id,w in pairs(activeWarnings) do
        local left=w.landTime-now; if left<0 then continue end
        w.lbl.Text=string.format("%s  %.1fs",w.d.label,left)
        w.lbl.TextColor3=left<1.5 and Color3.fromRGB(255,50,50) or w.d.color
    end
    local elapsed=now-sonarLastUsed
    local ratio=math.clamp(elapsed/GridConfig.SONAR_COOLDOWN,0,1)
    sonarBar.Size=UDim2.new(ratio,0,0.12,0)
    if ratio>=1 then
        sonarLabel.Text="[Q] SONAR  READY"; sonarLabel.TextColor3=Color3.fromRGB(80,200,255)
        sonarBar.BackgroundColor3=Color3.fromRGB(80,200,255)
    else
        sonarLabel.Text=string.format("[Q] SONAR  %ds",math.ceil(GridConfig.SONAR_COOLDOWN-elapsed))
        sonarLabel.TextColor3=Color3.fromRGB(110,110,140)
        sonarBar.BackgroundColor3=Color3.fromRGB(60,100,120)
    end
end)
