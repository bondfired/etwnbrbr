-- Luna – lobby UI controller
-- Shows between matches: Play info, Shop (skins), Loadout (ability slots), Stats.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService  = game:GetService("UserInputService")

local player  = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")
local AbilityConfig    = require(Modules:WaitForChild("AbilityConfig"))
local ShopConfig       = require(Modules:WaitForChild("ShopConfig"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))

local Remotes         = ReplicatedStorage:WaitForChild("Remotes")
local RE_PlayerData   = Remotes:WaitForChild("PlayerData")
local RE_UpdateLoadout = Remotes:WaitForChild("UpdateLoadout")
local RE_ShopPurchase  = Remotes:WaitForChild("ShopPurchase")
local RE_GameState     = Remotes:WaitForChild("GameState")
local RE_LobbyInfo     = Remotes:WaitForChild("LobbyInfo")

-- ─────────────────────────────────────────────
-- State
-- ─────────────────────────────────────────────

local localData    = nil
local currentTab   = "Play"
local lobbyVisible = true
local lobbyGui     = nil

-- ─────────────────────────────────────────────
-- UI helpers
-- ─────────────────────────────────────────────

local function make(class, props, parent)
    local i = Instance.new(class)
    for k,v in pairs(props) do i[k]=v end
    if parent then i.Parent=parent end
    return i
end

local function frm(parent,size,pos,bg,alpha)
    local f=make("Frame",{Size=size,Position=pos,BackgroundColor3=bg or Color3.fromRGB(10,10,20),
        BackgroundTransparency=alpha or 0,BorderSizePixel=0},parent)
    local c=make("UICorner",{CornerRadius=UDim.new(0,10)},f)
    return f
end

local function lbl(parent,size,pos,text,fs,col,xa)
    return make("TextLabel",{Size=size,Position=pos,BackgroundTransparency=1,
        TextScaled=true,Font=fs or Enum.Font.GothamBold,Text=text or "",
        TextColor3=col or Color3.fromRGB(255,255,255),
        TextXAlignment=xa or Enum.TextXAlignment.Center},parent)
end

local function btn(parent,size,pos,text,bg,callback)
    local b=make("TextButton",{Size=size,Position=pos,BackgroundColor3=bg or Color3.fromRGB(60,60,90),
        BorderSizePixel=0,TextScaled=true,Font=Enum.Font.GothamBold,
        Text=text,TextColor3=Color3.fromRGB(255,255,255)},parent)
    make("UICorner",{CornerRadius=UDim.new(0,8)},b)
    if callback then b.MouseButton1Click:Connect(callback) end
    return b
end

-- ─────────────────────────────────────────────
-- Build lobby panel
-- ─────────────────────────────────────────────

local function buildLobby()
    if lobbyGui then lobbyGui:Destroy() end

    lobbyGui = make("ScreenGui",{Name="LunaLobby",ResetOnSpawn=false,
        ZIndexBehavior=Enum.ZIndexBehavior.Sibling},player.PlayerGui)

    -- Background overlay
    local bg = frm(lobbyGui,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(0,0,0),0.55)
    bg.ZIndex=1

    -- Main card
    local card = frm(lobbyGui,UDim2.new(0,680,0,480),UDim2.new(0.5,-340,0.5,-240),
        Color3.fromRGB(12,12,22),0.05)
    card.ZIndex=2

    -- Title
    lbl(card,UDim2.new(1,0,0,50),UDim2.new(0,0,0,10),"LUNA",Enum.Font.GothamBold,
        Color3.fromRGB(140,200,255))

    -- XP bar area
    local xpPanel = frm(card,UDim2.new(0.9,0,0,40),UDim2.new(0.05,0,0,62),Color3.fromRGB(20,20,35),0)
    local xpBar = frm(xpPanel,UDim2.new(0,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(80,160,255),0)
    local xpLabel = lbl(xpPanel,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),"Level 1 · 0 XP",
        Enum.Font.Gotham,Color3.fromRGB(180,220,255))
    local levelLabel = lbl(card,UDim2.new(0,80,0,30),UDim2.new(0.05,0,0,64),"",
        Enum.Font.GothamBold,Color3.fromRGB(255,220,80))
    local credLabel = lbl(card,UDim2.new(0,120,0,30),UDim2.new(0.72,0,0,64),"0 Credits",
        Enum.Font.Gotham,Color3.fromRGB(255,200,60))
    credLabel.TextXAlignment = Enum.TextXAlignment.Right

    -- Tab bar
    local tabs = {"Play","Shop","Loadout","Stats"}
    local tabFrames = {}
    local tabBtns   = {}
    for i, tabName in ipairs(tabs) do
        local tb = btn(card,
            UDim2.new(0.22,0,0,34),
            UDim2.new(0.02+(i-1)*0.245,0,0,110),
            tabName,
            Color3.fromRGB(30,30,50))
        tb.Font = Enum.Font.Gotham
        table.insert(tabBtns,{btn=tb,name=tabName})
    end

    -- Content area
    local content = frm(card,UDim2.new(0.96,0,0,290),UDim2.new(0.02,0,0,152),
        Color3.fromRGB(18,18,30),0)

    -- ── TAB: Play ───────────────────────────────────────────────────────
    tabFrames["Play"] = frm(content,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,30),1)
    lbl(tabFrames["Play"],UDim2.new(1,0,0,60),UDim2.new(0,0,0.1,0),
        "Survive the forecast.\nRead the danger. Outlast everyone.",
        Enum.Font.Gotham,Color3.fromRGB(180,180,200))
    local playerCountLabel = lbl(tabFrames["Play"],UDim2.new(1,0,0,30),UDim2.new(0,0,0.6,0),
        "Players in lobby: 0",Enum.Font.Gotham,Color3.fromRGB(140,200,140))
    btn(tabFrames["Play"],UDim2.new(0.4,0,0,50),UDim2.new(0.3,0,0.75,0),
        "PLAY",Color3.fromRGB(40,140,80),function()
            -- Playing is automatic; this just closes the UI
            lobbyGui.Enabled = false
        end)

    -- ── TAB: Shop ───────────────────────────────────────────────────────
    tabFrames["Shop"] = frm(content,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,30),1)
    tabFrames["Shop"].Visible = false
    local shopScroll = make("ScrollingFrame",{
        Size=UDim2.new(1,-10,1,-10),Position=UDim2.new(0,5,0,5),
        BackgroundTransparency=1,ScrollBarThickness=4,
        CanvasSize=UDim2.new(0,0,0,#ShopConfig.SKINS*90+10)},tabFrames["Shop"])
    local shopLayout = make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,8)},shopScroll)

    for idx, skin in ipairs(ShopConfig.SKINS) do
        local skinRow = frm(shopScroll,UDim2.new(1,-10,0,78),UDim2.new(0,5,0,0),Color3.fromRGB(25,25,40),0)
        skinRow.LayoutOrder = idx
        -- Color preview swatches
        local swatchNames = {"Head","Torso","LeftArm","LeftLeg"}
        for si, sn in ipairs(swatchNames) do
            local sw = frm(skinRow,UDim2.new(0,16,0,16),UDim2.new(0,6+(si-1)*22,0.1,0),
                skin.colors[sn] and skin.colors[sn].Color or Color3.fromRGB(80,80,80),0)
        end
        lbl(skinRow,UDim2.new(0.45,0,0,28),UDim2.new(0.02,0,0.38,0),skin.name,
            Enum.Font.GothamBold,Color3.fromRGB(220,220,255))
        lbl(skinRow,UDim2.new(0.45,0,0,22),UDim2.new(0.02,0,0.68,0),skin.desc,
            Enum.Font.Gotham,Color3.fromRGB(140,140,160))
        local reqText = skin.free and "Free" or ("Lv."..( skin.levelUnlock or "?"))
        lbl(skinRow,UDim2.new(0.2,0,0,28),UDim2.new(0.5,0,0.35,0),reqText,
            Enum.Font.Gotham,Color3.fromRGB(255,200,60))
        local equipBtn = btn(skinRow,UDim2.new(0.22,0,0,36),UDim2.new(0.76,0,0.3,0),
            "Equip",Color3.fromRGB(40,100,180),function()
                RE_ShopPurchase:FireServer("skin", skin.id)
            end)
    end

    -- ── TAB: Loadout ────────────────────────────────────────────────────
    tabFrames["Loadout"] = frm(content,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,30),1)
    tabFrames["Loadout"].Visible = false
    local slotPanels = {}
    for si, slot in ipairs(AbilityConfig.SLOTS) do
        local panel = frm(tabFrames["Loadout"],UDim2.new(0.3,0,0.9,0),
            UDim2.new(0.02+(si-1)*0.33,0,0.05,0),Color3.fromRGB(20,20,35),0)
        lbl(panel,UDim2.new(1,0,0,22),UDim2.new(0,0,0,2),slot,Enum.Font.GothamBold,
            Color3.fromRGB(180,180,220))
        local scrollH = frm(panel,UDim2.new(1,0,1,-28),UDim2.new(0,0,0,26),Color3.fromRGB(12,12,20),0)
        local sScroll = make("ScrollingFrame",{Size=UDim2.new(1,0,1,0),
            BackgroundTransparency=1,ScrollBarThickness=3},scrollH)
        local sLayout = make("UIListLayout",{SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)},sScroll)
        slotPanels[slot] = { scroll=sScroll }
    end

    local function refreshLoadout()
        if not localData then return end
        for _, slot in ipairs(AbilityConfig.SLOTS) do
            local sp = slotPanels[slot]
            if not sp then continue end
            for _,c in ipairs(sp.scroll:GetChildren()) do
                if c:IsA("Frame") then c:Destroy() end
            end
            local abilities = {}
            for name, cfg in pairs(AbilityConfig.ABILITIES) do
                if cfg.slot==slot then table.insert(abilities,{name=name,cfg=cfg}) end
            end
            local abilH = 0
            for _, ab in ipairs(abilities) do
                local unlocked = false
                for _,u in ipairs(localData.unlockedAbilities) do if u==ab.name then unlocked=true; break end end
                local equipped = localData.loadout[slot]==ab.name
                local row = frm(sp.scroll,UDim2.new(1,-6,0,58),UDim2.new(0,3,0,0),
                    equipped and Color3.fromRGB(20,50,30) or Color3.fromRGB(18,18,28),0)
                row.LayoutOrder = abilH; abilH+=1
                local dot = frm(row,UDim2.new(0,10,0,10),UDim2.new(0,4,0.5,-5),
                    ab.cfg.color,unlocked and 0 or 0.6)
                lbl(row,UDim2.new(0.75,0,0,22),UDim2.new(0.1,0,0.05,0),ab.cfg.name,
                    Enum.Font.GothamBold, unlocked and Color3.fromRGB(220,220,255) or Color3.fromRGB(80,80,100))
                lbl(row,UDim2.new(0.75,0,0,18),UDim2.new(0.1,0,0.48,0),ab.cfg.desc,
                    Enum.Font.Gotham,Color3.fromRGB(120,120,140))
                if unlocked and not equipped then
                    btn(row,UDim2.new(0.22,0,0,28),UDim2.new(0.76,0,0.3,0),"Equip",
                        Color3.fromRGB(30,80,160),function()
                            RE_UpdateLoadout:FireServer(slot,ab.name)
                        end)
                elseif equipped then
                    lbl(row,UDim2.new(0.22,0,0,28),UDim2.new(0.76,0,0.35,0),"[ON]",
                        Enum.Font.GothamBold,Color3.fromRGB(80,255,120))
                end
            end
            sp.scroll.CanvasSize = UDim2.new(0,0,0,abilH*64)
        end
    end

    -- ── TAB: Stats ──────────────────────────────────────────────────────
    tabFrames["Stats"] = frm(content,UDim2.new(1,0,1,0),UDim2.new(0,0,0,0),Color3.fromRGB(18,18,30),1)
    tabFrames["Stats"].Visible = false
    local statLines = {
        {"Matches Played","matchesPlayed"}, {"Wins","wins"}, {"Total Survive Time","totalSurvive"}
    }
    local statLabels = {}
    for i, sl in ipairs(statLines) do
        lbl(tabFrames["Stats"],UDim2.new(0.4,0,0,30),UDim2.new(0.05,0,0.05+(i-1)*0.2,0),
            sl[1]..":", Enum.Font.Gotham,Color3.fromRGB(160,160,180),Enum.TextXAlignment.Left)
        statLabels[sl[2]] = lbl(tabFrames["Stats"],UDim2.new(0.45,0,0,30),
            UDim2.new(0.5,0,0.05+(i-1)*0.2,0),"—",Enum.Font.GothamBold,Color3.fromRGB(255,255,255),
            Enum.TextXAlignment.Left)
    end

    -- ── Tab switching ────────────────────────────────────────────────────
    local function switchTab(name)
        currentTab = name
        for _, tf in pairs(tabFrames) do tf.Visible=false end
        if tabFrames[name] then tabFrames[name].Visible=true end
        for _, tb in ipairs(tabBtns) do
            tb.btn.BackgroundColor3 = tb.name==name
                and Color3.fromRGB(40,80,160)
                or  Color3.fromRGB(30,30,50)
        end
        if name=="Loadout" then refreshLoadout() end
    end
    for _, tb in ipairs(tabBtns) do
        tb.btn.MouseButton1Click:Connect(function() switchTab(tb.name) end)
    end
    switchTab("Play")

    -- ── Update UI from player data ────────────────────────────────────────
    local function refreshUI(data)
        localData = data
        local maxXP = ProgressionConfig.XP_PER_LEVEL[math.min(data.level+1,ProgressionConfig.MAX_LEVEL)] or 1
        local curXP = data.xp - (ProgressionConfig.XP_PER_LEVEL[data.level] or 0)
        local nextXP = maxXP - (ProgressionConfig.XP_PER_LEVEL[data.level] or 0)
        local ratio  = math.clamp(curXP/math.max(nextXP,1),0,1)
        xpBar.Size   = UDim2.new(ratio,0,1,0)
        xpLabel.Text = ("Lv.%d · %d / %d XP"):format(data.level, curXP, nextXP)
        levelLabel.Text = "Lv."..data.level
        credLabel.Text  = data.credits.." Credits"
        if statLabels.matchesPlayed then statLabels.matchesPlayed.Text = tostring(data.stats.matchesPlayed) end
        if statLabels.wins          then statLabels.wins.Text          = tostring(data.stats.wins)          end
        if statLabels.totalSurvive  then statLabels.totalSurvive.Text  = math.floor(data.stats.totalSurvive).."s" end
        if currentTab=="Loadout" then refreshLoadout() end
    end

    RE_PlayerData.OnClientEvent:Connect(function(data) refreshUI(data) end)
    RE_LobbyInfo.OnClientEvent:Connect(function(info)
        if playerCountLabel then
            playerCountLabel.Text = "Players in lobby: "..(info.playerCount or 0)
        end
    end)

    return lobbyGui, refreshUI
end

-- ─────────────────────────────────────────────
-- Show / hide based on game phase
-- ─────────────────────────────────────────────

local refreshFn = nil
local gui, rf = buildLobby()
refreshFn = rf

RE_GameState.OnClientEvent:Connect(function(data)
    if not lobbyGui then return end
    local phase = data.phase
    local showLobby = (phase=="Lobby" or phase=="Countdown" or phase=="PostGame")
    lobbyGui.Enabled = showLobby
end)

RE_PlayerData.OnClientEvent:Connect(function(data)
    localData = data
end)
