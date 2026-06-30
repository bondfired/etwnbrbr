-- Luna – server orchestrator (full game loop)
-- Phases: Lobby → Countdown → PreGame → Warmup → Active → Overtime → PostGame → Lobby

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules          = ReplicatedStorage:WaitForChild("Modules")
local GridConfig       = require(Modules:WaitForChild("GridConfig"))
local HazardTypes      = require(Modules:WaitForChild("HazardTypes"))
local ProgressionConfig = require(Modules:WaitForChild("ProgressionConfig"))
local AbilityConfig    = require(Modules:WaitForChild("AbilityConfig"))
local ShopConfig       = require(Modules:WaitForChild("ShopConfig"))

-- ─────────────────────────────────────────────
-- Remote events
-- ─────────────────────────────────────────────

local Remotes = Instance.new("Folder")
Remotes.Name  = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeEvent(name)
    local e = Instance.new("RemoteEvent")
    e.Name   = name
    e.Parent = Remotes
    return e
end

local RE_SyncGrid       = makeEvent("SyncGrid")
local RE_HazardWarning  = makeEvent("HazardWarning")
local RE_HazardLanded   = makeEvent("HazardLanded")
local RE_GameState      = makeEvent("GameState")
local RE_PlayerDied     = makeEvent("PlayerDied")
local RE_SonarRequest   = makeEvent("SonarRequest")
local RE_SonarResult    = makeEvent("SonarResult")
local RE_PlayerData     = makeEvent("PlayerData")      -- Server→Client: XP/level/credits/loadout
local RE_ActivateAbility = makeEvent("ActivateAbility") -- Client→Server: use ability
local RE_AbilityFeedback = makeEvent("AbilityFeedback") -- Server→Client: cooldown / VFX cue
local RE_PostGameStats  = makeEvent("PostGameStats")   -- Server→Client: end-of-match results
local RE_UpdateLoadout  = makeEvent("UpdateLoadout")   -- Client→Server: change loadout slot
local RE_ShopPurchase   = makeEvent("ShopPurchase")    -- Client→Server: buy skin
local RE_LobbyInfo      = makeEvent("LobbyInfo")       -- Server→Client: lobby player list, shop

-- ─────────────────────────────────────────────
-- DataStore + player data
-- ─────────────────────────────────────────────

local DataStore = DataStoreService:GetDataStore("LunaData_v2")
local playerData = {}  -- [userId] = data table

local function defaultData()
    return {
        xp               = 0,
        level            = 1,
        credits          = 100,
        loadout          = { Movement = "BlinkStep", Utility = "FuturePing", Defensive = "TemporalShield" },
        equippedSkin     = "Noob",
        unlockedAbilities = table.clone(AbilityConfig.STARTER_UNLOCKS),
        unlockedSkins    = { "Noob" },
        stats            = { matchesPlayed = 0, wins = 0, totalSurvive = 0 },
    }
end

local function loadData(player)
    local ok, data = pcall(function() return DataStore:GetAsync("p_"..player.UserId) end)
    if ok and type(data) == "table" then
        local def = defaultData()
        for k, v in pairs(def) do if data[k] == nil then data[k] = v end end
        playerData[player.UserId] = data
    else
        playerData[player.UserId] = defaultData()
    end
end

local function saveData(player)
    local d = playerData[player.UserId]
    if d then pcall(function() DataStore:SetAsync("p_"..player.UserId, d) end) end
end

local function sendPlayerData(player)
    local d = playerData[player.UserId]
    if d then RE_PlayerData:FireClient(player, d) end
end

-- ─────────────────────────────────────────────
-- Grid construction
-- ─────────────────────────────────────────────

local W, H   = GridConfig.GRID_WIDTH, GridConfig.GRID_HEIGHT
local TILE   = GridConfig.TILE_SIZE
local THICK  = GridConfig.TILE_THICK
local ORIGIN = GridConfig.ORIGIN

local grid = {}
local gridFolder = Instance.new("Folder")
gridFolder.Name   = "LunaGrid"
gridFolder.Parent = workspace

local function dangerColor(d)
    local c = GridConfig.DANGER_COLORS
    return c[math.min(d,8)] or c[8]
end

for row = 0, H-1 do
    grid[row] = {}
    for col = 0, W-1 do
        local part = Instance.new("Part")
        part.Name       = ("Tile_%d_%d"):format(row,col)
        part.Size       = Vector3.new(TILE, THICK, TILE)
        part.Anchored   = true
        part.Material   = Enum.Material.SmoothPlastic
        part.Color      = dangerColor(0)
        part.TopSurface = Enum.SurfaceType.Smooth
        part.Position   = ORIGIN + Vector3.new(col*TILE+TILE/2, THICK/2, row*TILE+TILE/2)
        part.Parent     = gridFolder

        local gui = Instance.new("SurfaceGui")
        gui.Face           = Enum.NormalId.Top
        gui.LightInfluence = 0
        gui.Parent         = part

        local lbl = Instance.new("TextLabel")
        lbl.Size                   = UDim2.new(0.8,0,0.8,0)
        lbl.Position               = UDim2.new(0.1,0,0.1,0)
        lbl.BackgroundTransparency = 1
        lbl.TextScaled             = true
        lbl.Font                   = Enum.Font.GothamBold
        lbl.Text                   = ""
        lbl.TextColor3             = Color3.fromRGB(255,255,255)
        lbl.TextStrokeTransparency = 0.5
        lbl.Parent                 = gui

        grid[row][col] = { danger=0, part=part, label=lbl, scorched=false }
    end
end

-- Border walls
local function makeBorder(cx,cy,cz,sx,sy,sz)
    local p = Instance.new("Part")
    p.Size=Vector3.new(sx,sy,sz); p.Position=Vector3.new(cx,cy,cz)
    p.Anchored=true; p.Material=Enum.Material.SmoothPlastic
    p.Color=Color3.fromRGB(20,20,30); p.Parent=gridFolder
end
local arCX = ORIGIN.X+(W*TILE)/2
local arCZ = ORIGIN.Z+(H*TILE)/2
makeBorder(arCX, 3, ORIGIN.Z-1,       W*TILE+2, 6, 2)
makeBorder(arCX, 3, ORIGIN.Z+H*TILE+1,W*TILE+2, 6, 2)
makeBorder(ORIGIN.X-1,      3, arCZ, 2, 6, H*TILE+4)
makeBorder(ORIGIN.X+W*TILE+1,3, arCZ, 2, 6, H*TILE+4)

-- ─────────────────────────────────────────────
-- Tile visuals
-- ─────────────────────────────────────────────

local function updateTile(row,col)
    local t = grid[row][col]
    if not t then return end
    if t.scorched then t.part.Color=Color3.fromRGB(20,12,12); t.label.Text=""; return end
    t.part.Color  = dangerColor(t.danger)
    t.label.Text  = t.danger > 0 and tostring(t.danger) or ""
end

local function refreshGrid()
    for r=0,H-1 do for c=0,W-1 do updateTile(r,c) end end
end

-- ─────────────────────────────────────────────
-- Hazard system
-- ─────────────────────────────────────────────

local hazardQueue   = {}
local hazardCounter = 0

local function scheduleHazard(hType, row, col, meta, delay)
    hazardCounter += 1
    local h = { id=hazardCounter, hazardType=hType, row=row, col=col, metadata=meta, landTime=tick()+delay }
    table.insert(hazardQueue, h)
    RE_HazardWarning:FireAllClients(h)
end

local function recalcDanger(window)
    local now, cutoff = tick(), tick()+window
    for r=0,H-1 do for c=0,W-1 do grid[r][c].danger=0 end end
    for _,h in ipairs(hazardQueue) do
        if h.landTime>now and h.landTime<=cutoff then
            for _,t in ipairs(HazardTypes.getAffectedTiles(h.hazardType,h.row,h.col,h.metadata)) do
                local cell = grid[t.row] and grid[t.row][t.col]
                if cell then cell.danger = math.min(cell.danger+1, 9) end
            end
        end
    end
    refreshGrid()
    local flat={}
    for r=0,H-1 do flat[r]={} for c=0,W-1 do flat[r][c]=grid[r][c].danger end end
    RE_SyncGrid:FireAllClients(flat)
end

-- ─────────────────────────────────────────────
-- Character appearance
-- ─────────────────────────────────────────────

local function applySkin(char, skinId)
    local skin = ShopConfig.SKIN_MAP[skinId or "Noob"] or ShopConfig.SKIN_MAP["Noob"]
    for partName, bc in pairs(skin.colors) do
        local part = char:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            part.BrickColor = bc
        end
    end
end

-- ─────────────────────────────────────────────
-- Per-player runtime state
-- ─────────────────────────────────────────────

local matchStats    = {}  -- [userId] = { spawnTime, nearMisses, abilitiesUsed={}, maxDanger }
local abilityState  = {}  -- [userId] = { cooldowns={}, shielded, dampened, phaseImmune, rewindPos={} }

local function initPlayerState(player)
    matchStats[player.UserId]   = { spawnTime=tick(), nearMisses=0, abilitiesUsed={}, maxDanger=0 }
    abilityState[player.UserId] = { cooldowns={}, shielded=false, dampened=false, phaseImmune=false, rewindPos={} }
end

local function cleanPlayerState(player)
    matchStats[player.UserId]  = nil
    abilityState[player.UserId] = nil
end

-- ─────────────────────────────────────────────
-- Kill detection
-- ─────────────────────────────────────────────

local function killPlayersOnTiles(affectedTiles)
    for _,player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health<=0 then continue end

        local as = abilityState[player.UserId]
        if as and (as.dampened or as.phaseImmune) then continue end

        local px, pz = hrp.Position.X, hrp.Position.Z
        for _,t in ipairs(affectedTiles) do
            local cell = grid[t.row] and grid[t.row][t.col]
            if cell then
                local tp = cell.part.Position
                if math.abs(px-tp.X)<=TILE/2 and math.abs(pz-tp.Z)<=TILE/2 then
                    if as and as.shielded then
                        as.shielded = false
                        RE_AbilityFeedback:FireClient(player, "ShieldConsumed")
                    else
                        local ms = matchStats[player.UserId]
                        if ms then ms.nearMisses += 1 end
                        hum.Health = 0
                    end
                    break
                end
            end
        end
    end
end

local function processLanded()
    local now, remaining = tick(), {}
    for _,h in ipairs(hazardQueue) do
        if h.landTime>now then table.insert(remaining,h); continue end
        local affected = HazardTypes.getAffectedTiles(h.hazardType,h.row,h.col,h.metadata)
        for _,t in ipairs(affected) do
            local cell = grid[t.row] and grid[t.row][t.col]
            if cell then
                cell.scorched = true; updateTile(t.row,t.col)
                local r,c = t.row,t.col
                task.delay(2.5, function()
                    local g=grid[r] and grid[r][c]
                    if g then g.scorched=false end
                end)
            end
        end
        killPlayersOnTiles(affected)
        RE_HazardLanded:FireAllClients(h, affected)
    end
    hazardQueue = remaining
end

-- ─────────────────────────────────────────────
-- Ability system
-- ─────────────────────────────────────────────

local function getTileFromPos(px, pz)
    local col = math.clamp(math.floor((px-ORIGIN.X)/TILE), 0, W-1)
    local row = math.clamp(math.floor((pz-ORIGIN.Z)/TILE), 0, H-1)
    return row, col
end

local function tileCenter(row, col)
    return ORIGIN + Vector3.new(col*TILE+TILE/2, THICK+3, row*TILE+TILE/2)
end

local function findSafeTile(nearRow, nearCol, radius)
    local best, bestDanger = nil, math.huge
    for dr=-radius,radius do
        for dc=-radius,radius do
            local r,c = nearRow+dr, nearCol+dc
            if r<0 or r>=H or c<0 or c>=W then continue end
            local cell = grid[r][c]
            if cell and not cell.scorched and cell.danger < bestDanger then
                bestDanger = cell.danger
                best = {row=r, col=c}
            end
        end
    end
    return best
end

local ABILITY_HANDLERS = {}

ABILITY_HANDLERS.BlinkStep = function(player)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pRow, pCol = getTileFromPos(hrp.Position.X, hrp.Position.Z)
    local target = findSafeTile(pRow, pCol, 5)
    if not target then return false end
    hrp.CFrame = CFrame.new(tileCenter(target.row, target.col))
    return true
end

ABILITY_HANDLERS.PhaseDash = function(player)
    local as = abilityState[player.UserId]
    if not as then return false end
    as.phaseImmune = true
    task.delay(0.8, function() if abilityState[player.UserId] then abilityState[player.UserId].phaseImmune=false end end)
    return true
end

ABILITY_HANDLERS.TileSwap = function(player)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pRow, pCol = getTileFromPos(hrp.Position.X, hrp.Position.Z)
    local candidates = {}
    for dr=-4,4 do for dc=-4,4 do
        local r,c=pRow+dr,pCol+dc
        if r>=0 and r<H and c>=0 and c<W then
            local cell=grid[r][c]
            if cell and not cell.scorched and cell.danger<=2 then
                table.insert(candidates,{row=r,col=c})
            end
        end
    end end
    if #candidates==0 then return false end
    local t = candidates[math.random(#candidates)]
    hrp.CFrame = CFrame.new(tileCenter(t.row, t.col))
    return true
end

ABILITY_HANDLERS.FuturePing = function(player)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local pRow, pCol = getTileFromPos(hrp.Position.X, hrp.Position.Z)
    local pingData = {}
    for dr=-1,1 do for dc=-1,1 do
        local r,c=pRow+dr,pCol+dc
        if r>=0 and r<H and c>=0 and c<W then
            table.insert(pingData,{row=r,col=c,danger=grid[r][c].danger})
        end
    end end
    RE_AbilityFeedback:FireClient(player, "FuturePing", pingData)
    return true
end

ABILITY_HANDLERS.SafeBeacon = function(player)
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local bRow, bCol = getTileFromPos(hrp.Position.X, hrp.Position.Z)
    -- Beacon: set danger to 0 in 2-tile radius for 6s
    local beaconTiles = {}
    for dr=-2,2 do for dc=-2,2 do
        local r,c=bRow+dr,bCol+dc
        if r>=0 and r<H and c>=0 and c<W then table.insert(beaconTiles,{r,c}) end
    end end
    for _,t in ipairs(beaconTiles) do grid[t[1]][t[2]].danger=0; updateTile(t[1],t[2]) end
    RE_AbilityFeedback:FireClient(player,"SafeBeacon",{row=bRow,col=bCol})
    task.delay(6, function() recalcDanger(GridConfig.FORECAST_WINDOW) end)
    return true
end

ABILITY_HANDLERS.ForecastSteal = function(player)
    local others = {}
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=player and p.Character then table.insert(others,p) end
    end
    if #others==0 then return false end
    local victim = others[math.random(#others)]
    local vChar  = victim.Character
    if not vChar then return false end
    local hrp = vChar:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local vRow, vCol = getTileFromPos(hrp.Position.X, hrp.Position.Z)
    local stealData = {}
    for dr=-3,3 do for dc=-3,3 do
        local r,c=vRow+dr,vCol+dc
        if r>=0 and r<H and c>=0 and c<W then
            table.insert(stealData,{row=r,col=c,danger=grid[r][c].danger})
        end
    end end
    RE_AbilityFeedback:FireClient(player,"ForecastSteal",stealData)
    return true
end

ABILITY_HANDLERS.TemporalShield = function(player)
    local as = abilityState[player.UserId]
    if not as then return false end
    as.shielded = true
    task.delay(10, function() if abilityState[player.UserId] then abilityState[player.UserId].shielded=false end end)
    RE_AbilityFeedback:FireClient(player,"ShieldActive")
    return true
end

ABILITY_HANDLERS.RewindStep = function(player)
    local as = abilityState[player.UserId]
    if not as or #as.rewindPos<1 then return false end
    local char = player.Character
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    local oldest = as.rewindPos[1]
    hrp.CFrame = CFrame.new(oldest + Vector3.new(0,3,0))
    as.rewindPos = {}
    return true
end

ABILITY_HANDLERS.DangerDampener = function(player)
    local as = abilityState[player.UserId]
    if not as then return false end
    as.dampened = true
    RE_AbilityFeedback:FireClient(player,"DampenerActive")
    task.delay(3, function() if abilityState[player.UserId] then abilityState[player.UserId].dampened=false; RE_AbilityFeedback:FireClient(player,"DampenerExpired") end end)
    return true
end

-- Record rewind positions every 0.5s for alive players
task.spawn(function()
    while true do task.wait(0.5)
        for _,player in ipairs(Players:GetPlayers()) do
            local as = abilityState[player.UserId]
            if not as then continue end
            local char = player.Character
            if not char then continue end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if not hrp then continue end
            table.insert(as.rewindPos, hrp.Position)
            if #as.rewindPos > 4 then table.remove(as.rewindPos,1) end
        end
    end
end)

RE_ActivateAbility.OnServerEvent:Connect(function(player, abilityName)
    local State = _G.LunaState
    if not State or (State.phase~="Active" and State.phase~="Warmup" and State.phase~="Overtime") then return end

    local data = playerData[player.UserId]
    if not data then return end
    local as = abilityState[player.UserId]
    if not as then return end

    local cfg = AbilityConfig.ABILITIES[abilityName]
    if not cfg then return end

    -- Check it's in player's loadout
    local inLoadout = false
    for _, v in pairs(data.loadout) do if v==abilityName then inLoadout=true; break end end
    if not inLoadout then return end

    -- Cooldown check
    local now = tick()
    local last = as.cooldowns[abilityName] or 0
    if now-last < cfg.cooldown then
        RE_AbilityFeedback:FireClient(player,"OnCooldown",abilityName, cfg.cooldown-(now-last))
        return
    end

    local handler = ABILITY_HANDLERS[abilityName]
    if handler and handler(player) then
        as.cooldowns[abilityName] = now
        local ms = matchStats[player.UserId]
        if ms then ms.abilitiesUsed[abilityName]=true end
        RE_AbilityFeedback:FireClient(player,"Used",abilityName,cfg.cooldown)
    end
end)

-- ─────────────────────────────────────────────
-- Sonar ability (legacy, kept for compatibility)
-- ─────────────────────────────────────────────

RE_SonarRequest.OnServerEvent:Connect(function(player)
    local as = abilityState[player.UserId]
    if not as then return end
    local now=tick(); local last=as.cooldowns["__sonar"] or 0
    if now-last < GridConfig.SONAR_COOLDOWN then return end
    as.cooldowns["__sonar"] = now
    local char=player.Character; if not char then return end
    local hrp=char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
    local rel=hrp.Position-ORIGIN
    local pCol=math.clamp(math.floor(rel.X/TILE),0,W-1)
    local pRow=math.clamp(math.floor(rel.Z/TILE),0,H-1)
    local radius=GridConfig.SONAR_RADIUS
    local cutoff=now+GridConfig.SONAR_WINDOW
    local sonarData={}
    for dr=-radius,radius do for dc=-radius,radius do
        if dr*dr+dc*dc<=radius*radius then
            local r,c=pRow+dr,pCol+dc
            if r>=0 and r<H and c>=0 and c<W then
                local val=0
                for _,h in ipairs(hazardQueue) do
                    if h.landTime>now and h.landTime<=cutoff then
                        for _,t in ipairs(HazardTypes.getAffectedTiles(h.hazardType,h.row,h.col,h.metadata)) do
                            if t.row==r and t.col==c then val+=1; break end
                        end
                    end
                end
                table.insert(sonarData,{row=r,col=c,danger=val})
            end
        end
    end end
    RE_SonarResult:FireClient(player, sonarData)
end)

-- ─────────────────────────────────────────────
-- Loadout & shop
-- ─────────────────────────────────────────────

RE_UpdateLoadout.OnServerEvent:Connect(function(player, slot, abilityName)
    local data = playerData[player.UserId]
    if not data then return end
    local cfg = AbilityConfig.ABILITIES[abilityName]
    if not cfg or cfg.slot ~= slot then return end
    -- Check unlocked
    local unlocked = false
    for _,a in ipairs(data.unlockedAbilities) do if a==abilityName then unlocked=true; break end end
    if not unlocked then return end
    data.loadout[slot] = abilityName
    sendPlayerData(player)
end)

RE_ShopPurchase.OnServerEvent:Connect(function(player, itemType, itemId)
    local data = playerData[player.UserId]
    if not data then return end
    if itemType == "skin" then
        local skin = ShopConfig.SKIN_MAP[itemId]
        if not skin then return end
        if skin.free or (skin.levelUnlock and data.level >= skin.levelUnlock) then
            local owned = false
            for _,s in ipairs(data.unlockedSkins) do if s==itemId then owned=true; break end end
            if not owned then table.insert(data.unlockedSkins, itemId) end
            data.equippedSkin = itemId
            local char = player.Character
            if char then applySkin(char, itemId) end
            sendPlayerData(player)
        end
    end
end)

-- ─────────────────────────────────────────────
-- Progression
-- ─────────────────────────────────────────────

local function getLevel(xp)
    local lvl = 1
    for i = ProgressionConfig.MAX_LEVEL, 1, -1 do
        if xp >= ProgressionConfig.XP_PER_LEVEL[i] then
            lvl = i; break
        end
    end
    return math.min(lvl, ProgressionConfig.MAX_LEVEL)
end

local function awardProgression(player, surviveSeconds, placement, ms)
    local data = playerData[player.UserId]
    if not data then return end

    local src = ProgressionConfig.XP_SOURCES
    local cSrc = ProgressionConfig.CREDIT_SOURCES
    local xpGain = math.floor(surviveSeconds * src.PER_SECOND_SURVIVED)
        + (placement == 1 and src.WIN or placement <= 3 and src.TOP3 or 0)
        + (ms and ms.nearMisses * src.NEAR_MISS or 0)
    local creditGain = math.floor(cSrc.BASE + surviveSeconds * cSrc.PER_SECOND
        + (placement == 1 and cSrc.WIN or placement <= 3 and cSrc.TOP3 or 0))

    local oldLevel = data.level
    data.xp       = data.xp + xpGain
    data.credits  = data.credits + creditGain
    data.level    = getLevel(data.xp)
    data.stats.matchesPlayed += 1
    if placement == 1 then data.stats.wins += 1 end
    data.stats.totalSurvive += surviveSeconds

    -- Level-up rewards
    local newUnlocks = {}
    for lvl = oldLevel+1, data.level do
        local reward = ProgressionConfig.LEVEL_REWARDS[lvl]
        if reward then
            if reward.credits then data.credits += reward.credits end
            if reward.unlock then
                local uType, uId = reward.unlock:match("(%w+):(%w+)")
                if uType == "ability" then
                    local found=false
                    for _,a in ipairs(data.unlockedAbilities) do if a==uId then found=true; break end end
                    if not found then table.insert(data.unlockedAbilities, uId) end
                    table.insert(newUnlocks, { type="ability", id=uId })
                elseif uType == "skin" then
                    local found=false
                    for _,s in ipairs(data.unlockedSkins) do if s==uId then found=true; break end end
                    if not found then table.insert(data.unlockedSkins, uId) end
                    table.insert(newUnlocks, { type="skin", id=uId })
                end
            end
        end
    end

    -- Medals
    local medals = {}
    for _,medal in ipairs(ProgressionConfig.MEDALS) do
        local earned = false
        if medal.id=="LastStanding" and placement==1 then earned=true
        elseif medal.id=="Survivor" and placement<=3 then earned=true
        elseif medal.id=="CloseCall" and ms and ms.nearMisses>=5 then earned=true
        elseif medal.id=="AbilityMaster" and ms then
            local used=0; for _ in pairs(ms.abilitiesUsed) do used+=1 end
            if used>=3 then earned=true end
        elseif medal.id=="FutureReader" and ms and ms.maxDanger<=3 then earned=true
        end
        if earned then
            data.xp += medal.xp
            table.insert(medals, medal)
        end
    end

    saveData(player)
    return { xpGain=xpGain, creditGain=creditGain, medals=medals, newUnlocks=newUnlocks,
             newLevel=data.level, oldLevel=oldLevel }
end

-- ─────────────────────────────────────────────
-- Game state machine
-- ─────────────────────────────────────────────

local State = {
    phase          = "Lobby",
    overtimeStage  = 0,
    timer          = 0,
    alivePlayers   = {},
    placements     = {},   -- { player, placement, surviveSeconds }
    placementIndex = 1,
}
_G.LunaState = State  -- expose for ability handlers

local function broadcastState(extra)
    local data = { phase=State.phase, timer=State.timer,
                   overtimeStage=State.overtimeStage, aliveCount=#State.alivePlayers }
    if extra then for k,v in pairs(extra) do data[k]=v end end
    RE_GameState:FireAllClients(data)
end

local function eliminatePlayer(player)
    for i,p in ipairs(State.alivePlayers) do
        if p==player then
            table.remove(State.alivePlayers,i)
            local ms = matchStats[player.UserId]
            local survive = ms and (tick()-ms.spawnTime) or 0
            table.insert(State.placements,{player=player, placement=State.placementIndex, surviveSeconds=survive, ms=ms})
            State.placementIndex += 1
            RE_PlayerDied:FireAllClients(player)
            break
        end
    end
end

local function checkWin()
    if State.phase~="Active" and State.phase~="Overtime" then return end
    if #State.alivePlayers==0 then
        State.phase="PostGame"
        broadcastState({ winner="Nobody" })
    elseif #State.alivePlayers==1 and State.phase=="Overtime" then
        local winner = State.alivePlayers[1]
        eliminatePlayer(winner)
        State.phase="PostGame"
        broadcastState({ winner=winner.Name })
    end
end

local function onCharAdded(player, char)
    local hum = char:WaitForChild("Humanoid")
    local data = playerData[player.UserId]
    applySkin(char, data and data.equippedSkin or "Noob")
    hum.Died:Connect(function()
        if State.phase=="Active" or State.phase=="Overtime" or State.phase=="Warmup" then
            eliminatePlayer(player); checkWin()
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    loadData(player)
    task.wait(1); sendPlayerData(player)
    player.CharacterAdded:Connect(function(char) onCharAdded(player,char) end)
    if player.Character then onCharAdded(player, player.Character) end
    -- Send lobby info
    RE_LobbyInfo:FireAllClients({ playerCount=#Players:GetPlayers() })
end)

Players.PlayerRemoving:Connect(function(player)
    saveData(player)
    cleanPlayerState(player)
    if State.phase=="Active" or State.phase=="Overtime" then
        eliminatePlayer(player); checkWin()
    end
    playerData[player.UserId] = nil
end)

-- Auto-save
task.spawn(function() while true do task.wait(60)
    for _,p in ipairs(Players:GetPlayers()) do saveData(p) end
end end)

-- ─────────────────────────────────────────────
-- Grid / hazard helpers
-- ─────────────────────────────────────────────

local function currentCfg()
    if State.phase=="Warmup" then
        return { window=GridConfig.FORECAST_WINDOW, spawnInterval=GridConfig.SPAWN_INTERVAL*3 }
    elseif State.phase=="Active" then
        return { window=GridConfig.FORECAST_WINDOW, spawnInterval=GridConfig.SPAWN_INTERVAL }
    elseif State.phase=="Overtime" then
        return GridConfig.OVERTIME[State.overtimeStage]
    end
    return nil
end

local function spawnHazard()
    local t=HazardTypes.random(); local meta=HazardTypes.randomMetadata(t)
    scheduleHazard(t, math.random(0,H-1), math.random(0,W-1), meta, 3+math.random()*5)
end

local function resetGrid()
    hazardQueue={}
    for r=0,H-1 do for c=0,W-1 do grid[r][c].danger=0; grid[r][c].scorched=false; updateTile(r,c) end end
end

-- ─────────────────────────────────────────────
-- Post-game results
-- ─────────────────────────────────────────────

local function runPostGame()
    State.phase="PostGame"
    task.wait(0.5)

    -- Award progression and send results to each player
    for i, entry in ipairs(State.placements) do
        local player = entry.player
        if not player or not player.Parent then continue end
        local result = awardProgression(player, entry.surviveSeconds, entry.placement, entry.ms)
        if result then
            RE_PostGameStats:FireClient(player, {
                placement    = entry.placement,
                totalPlayers = #State.placements,
                surviveTime  = math.floor(entry.surviveSeconds),
                nearMisses   = entry.ms and entry.ms.nearMisses or 0,
                medals       = result.medals,
                xpGain       = result.xpGain,
                creditGain   = result.creditGain,
                newLevel     = result.newLevel,
                oldLevel     = result.oldLevel,
                newUnlocks   = result.newUnlocks,
            })
            sendPlayerData(player)
        end
    end

    broadcastState()
    task.wait(10)

    -- Reset
    State.phase         = "Lobby"
    State.placements    = {}
    State.placementIndex = 1
    State.alivePlayers  = {}
    State.overtimeStage = 0
    cleanPlayerStates()
    broadcastState()
    RE_LobbyInfo:FireAllClients({ playerCount=#Players:GetPlayers() })
end

function cleanPlayerStates()
    for _,p in ipairs(Players:GetPlayers()) do cleanPlayerState(p) end
end

-- ─────────────────────────────────────────────
-- Game start
-- ─────────────────────────────────────────────

local function startMatch()
    resetGrid()
    State.alivePlayers   = {}
    State.placements     = {}
    State.placementIndex = 1
    State.overtimeStage  = 0

    for _,p in ipairs(Players:GetPlayers()) do
        table.insert(State.alivePlayers, p)
        p:LoadCharacter()
    end
    task.wait(1)

    -- PreGame: show map 8 seconds
    State.phase="PreGame"; State.timer=8; broadcastState()
    task.wait(8)

    -- Warmup: 10 seconds, low hazard rate
    State.phase="Warmup"; State.timer=10; broadcastState()
    for _=1,3 do spawnHazard() end
    task.wait(10)

    -- Active phase
    State.phase="Active"; State.timer=GridConfig.GAME_DURATION; broadcastState()
    for _=1,6 do spawnHazard() end

    for _,p in ipairs(State.alivePlayers) do initPlayerState(p) end
end

-- ─────────────────────────────────────────────
-- Main game loop
-- ─────────────────────────────────────────────

local gameStartTime     = 0
local overtimeStartTime = 0
local lastSpawn         = 0
local lastDangerRefresh = 0
local prevSecond        = 0

local function tryStart()
    if State.phase~="Lobby" then return end
    if #Players:GetPlayers()<1 then return end
    State.phase="Countdown"; State.timer=10; broadcastState()
    task.wait(10)
    if State.phase~="Countdown" then return end
    gameStartTime   = tick()
    lastSpawn       = tick()
    lastDangerRefresh = tick()
    startMatch()
end

Players.PlayerAdded:Connect(function()
    task.wait(2)
    if State.phase=="Lobby" and #Players:GetPlayers()>=1 then tryStart() end
end)

task.defer(function()
    task.wait(5)
    if State.phase=="Lobby" and #Players:GetPlayers()>=1 then tryStart() end
end)

-- Watch for post-game and auto-restart
task.spawn(function()
    while true do task.wait(1)
        if State.phase=="PostGame" then task.wait(12)
            if State.phase~="Lobby" then
                State.phase="Lobby"; broadcastState()
                task.wait(5); tryStart()
            end
        end
    end
end)

RunService.Heartbeat:Connect(function(dt)
    if State.phase~="Warmup" and State.phase~="Active" and State.phase~="Overtime" then return end

    local now = tick()
    local cfg = currentCfg()
    if not cfg then return end

    processLanded()
    if State.phase=="PostGame" or State.phase=="Lobby" then return end

    if now-lastSpawn >= cfg.spawnInterval then lastSpawn=now; spawnHazard() end
    if now-lastDangerRefresh >= GridConfig.DANGER_REFRESH then
        lastDangerRefresh=now; recalcDanger(cfg.window)
    end

    -- Update per-player max danger stat
    for _,player in ipairs(State.alivePlayers) do
        local ms = matchStats[player.UserId]
        if not ms then continue end
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then continue end
        local row,col = getTileFromPos(hrp.Position.X, hrp.Position.Z)
        local cell = grid[row] and grid[row][col]
        if cell then ms.maxDanger = math.max(ms.maxDanger, cell.danger) end
    end

    if State.phase=="Warmup" then
        local elapsed = now-gameStartTime
        State.timer = math.max(0, 10-elapsed)
        if State.timer<=0 then
            State.phase="Active"; State.timer=GridConfig.GAME_DURATION
            gameStartTime=now; broadcastState()
        end

    elseif State.phase=="Active" then
        local elapsed = now-gameStartTime
        State.timer = math.max(0, GridConfig.GAME_DURATION-elapsed)
        local sec = math.floor(elapsed)
        if sec~=prevSecond then prevSecond=sec; broadcastState() end
        if State.timer<=0 then
            State.phase="Overtime"; State.overtimeStage=1
            overtimeStartTime=now; broadcastState()
        end

    elseif State.phase=="Overtime" then
        local elapsed = now-overtimeStartTime
        local stage = GridConfig.OVERTIME[State.overtimeStage]
        local sec = math.floor(elapsed)
        if sec~=prevSecond then prevSecond=sec; broadcastState() end
        if stage and stage.duration>0 and elapsed>=stage.duration then
            State.overtimeStage=math.min(State.overtimeStage+1,#GridConfig.OVERTIME)
            overtimeStartTime=now; broadcastState()
        end
        if #State.alivePlayers==1 then
            task.spawn(runPostGame)
        elseif #State.alivePlayers==0 then
            task.spawn(runPostGame)
        end
    end

    if #State.alivePlayers==0 and (State.phase=="Active" or State.phase=="Warmup") then
        task.spawn(runPostGame)
    end
end)
