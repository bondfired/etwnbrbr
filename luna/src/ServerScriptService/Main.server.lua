-- Luna – server orchestrator
-- Owns: grid creation, hazard scheduling, danger forecasting, game state, player kills.

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules      = ReplicatedStorage:WaitForChild("Modules")
local GridConfig   = require(Modules:WaitForChild("GridConfig"))
local HazardTypes  = require(Modules:WaitForChild("HazardTypes"))

-- ─────────────────────────────────────────────
-- Remote events
-- ─────────────────────────────────────────────

local Remotes = Instance.new("Folder")
Remotes.Name = "Remotes"
Remotes.Parent = ReplicatedStorage

local function makeEvent(name)
    local e = Instance.new("RemoteEvent")
    e.Name = name
    e.Parent = Remotes
    return e
end

local RE_SyncGrid      = makeEvent("SyncGrid")       -- Server→Client: flat danger grid
local RE_HazardWarning = makeEvent("HazardWarning")  -- Server→Client: hazard incoming
local RE_HazardLanded  = makeEvent("HazardLanded")   -- Server→Client: explosion VFX
local RE_GameState     = makeEvent("GameState")      -- Server→Client: phase / timer
local RE_PlayerDied    = makeEvent("PlayerDied")     -- Server→Client: elimination notice
local RE_SonarRequest  = makeEvent("SonarRequest")   -- Client→Server: use sonar
local RE_SonarResult   = makeEvent("SonarResult")    -- Server→Client: extended forecast

-- ─────────────────────────────────────────────
-- Grid construction
-- ─────────────────────────────────────────────

local W      = GridConfig.GRID_WIDTH
local H      = GridConfig.GRID_HEIGHT
local TILE   = GridConfig.TILE_SIZE
local THICK  = GridConfig.TILE_THICK
local ORIGIN = GridConfig.ORIGIN

-- grid[row][col] = { danger, part, label, scorched }
local grid = {}

local gridFolder = Instance.new("Folder")
gridFolder.Name = "LunaGrid"
gridFolder.Parent = workspace

local function dangerColor(danger)
    local c = GridConfig.DANGER_COLORS
    return c[math.min(danger, 8)] or c[8]
end

for row = 0, H - 1 do
    grid[row] = {}
    for col = 0, W - 1 do
        local part = Instance.new("Part")
        part.Name      = string.format("Tile_%d_%d", row, col)
        part.Size      = Vector3.new(TILE, THICK, TILE)
        part.Anchored  = true
        part.Material  = Enum.Material.SmoothPlastic
        part.Color     = dangerColor(0)
        part.TopSurface = Enum.SurfaceType.Smooth
        part.Position  = ORIGIN + Vector3.new(
            col * TILE + TILE / 2,
            THICK / 2,
            row  * TILE + TILE / 2
        )
        part.Parent = gridFolder
        part:SetAttribute("Row", row)
        part:SetAttribute("Col", col)

        -- SurfaceGui shows the danger number on the top face
        local gui = Instance.new("SurfaceGui")
        gui.Face            = Enum.NormalId.Top
        gui.LightInfluence  = 0
        gui.Parent          = part

        local label = Instance.new("TextLabel")
        label.Size                  = UDim2.new(0.8, 0, 0.8, 0)
        label.Position              = UDim2.new(0.1, 0, 0.1, 0)
        label.BackgroundTransparency = 1
        label.TextScaled            = true
        label.Font                  = Enum.Font.GothamBold
        label.Text                  = ""
        label.TextColor3            = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0.5
        label.Parent                = gui

        grid[row][col] = { danger = 0, part = part, label = label, scorched = false }
    end
end

-- Add thin border walls so players can't walk off the grid
local function makeBorder(cx, cy, cz, sx, sy, sz)
    local p = Instance.new("Part")
    p.Size     = Vector3.new(sx, sy, sz)
    p.Position = Vector3.new(cx, cy, cz)
    p.Anchored = true
    p.Material = Enum.Material.SmoothPlastic
    p.Color    = Color3.fromRGB(20, 20, 30)
    p.Parent   = gridFolder
end
local arenaHalf = (W * TILE) / 2
local cx = ORIGIN.X + arenaHalf
local cz = ORIGIN.Z + arenaHalf
local wallH = 6
makeBorder(cx,           wallH/2, ORIGIN.Z - 1,       W*TILE+2, wallH, 2)
makeBorder(cx,           wallH/2, ORIGIN.Z+H*TILE+1,  W*TILE+2, wallH, 2)
makeBorder(ORIGIN.X - 1, wallH/2, cz,                 2, wallH, H*TILE+4)
makeBorder(ORIGIN.X+W*TILE+1, wallH/2, cz,            2, wallH, H*TILE+4)

-- ─────────────────────────────────────────────
-- Tile visual update
-- ─────────────────────────────────────────────

local function updateTileVisual(row, col)
    local t = grid[row][col]
    if not t then return end

    if t.scorched then
        t.part.Color = Color3.fromRGB(20, 12, 12)
        t.label.Text = ""
        return
    end

    t.part.Color = dangerColor(t.danger)
    t.label.Text = t.danger > 0 and tostring(t.danger) or ""
end

local function refreshAllTiles()
    for r = 0, H - 1 do
        for c = 0, W - 1 do
            updateTileVisual(r, c)
        end
    end
end

-- ─────────────────────────────────────────────
-- Hazard system
-- ─────────────────────────────────────────────

local hazardQueue   = {}   -- { id, hazardType, row, col, metadata, landTime }
local hazardCounter = 0

local function scheduleHazard(hazardType, row, col, metadata, delay)
    hazardCounter += 1
    local h = {
        id          = hazardCounter,
        hazardType  = hazardType,
        row         = row,
        col         = col,
        metadata    = metadata,
        landTime    = tick() + delay,
    }
    table.insert(hazardQueue, h)
    RE_HazardWarning:FireAllClients(h)
    return h
end

-- Recompute danger values for all tiles based on hazards landing within `window` seconds.
local function recalcDanger(window)
    local now    = tick()
    local cutoff = now + window

    for r = 0, H - 1 do
        for c = 0, W - 1 do
            grid[r][c].danger = 0
        end
    end

    for _, h in ipairs(hazardQueue) do
        if h.landTime > now and h.landTime <= cutoff then
            local affected = HazardTypes.getAffectedTiles(h.hazardType, h.row, h.col, h.metadata)
            for _, t in ipairs(affected) do
                local cell = grid[t.row] and grid[t.row][t.col]
                if cell then
                    cell.danger = math.min(cell.danger + 1, 9)
                end
            end
        end
    end

    refreshAllTiles()

    -- Send flat grid to clients for HUD-level queries
    local flat = {}
    for r = 0, H - 1 do
        flat[r] = {}
        for c = 0, W - 1 do
            flat[r][c] = grid[r][c].danger
        end
    end
    RE_SyncGrid:FireAllClients(flat)
end

-- Check which players are standing on a set of tiles and kill them.
local function killPlayersOnTiles(affectedTiles)
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if not char then continue end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then continue end

        local px, pz = hrp.Position.X, hrp.Position.Z
        for _, t in ipairs(affectedTiles) do
            local cell = grid[t.row] and grid[t.row][t.col]
            if cell then
                local tp = cell.part.Position
                if math.abs(px - tp.X) <= TILE / 2 and math.abs(pz - tp.Z) <= TILE / 2 then
                    hum.Health = 0
                    break
                end
            end
        end
    end
end

-- Process any hazards whose landTime has passed.
local function processLanded()
    local now       = tick()
    local remaining = {}

    for _, h in ipairs(hazardQueue) do
        if h.landTime > now then
            table.insert(remaining, h)
            continue
        end

        local affected = HazardTypes.getAffectedTiles(h.hazardType, h.row, h.col, h.metadata)

        -- Scorch tiles briefly
        for _, t in ipairs(affected) do
            local cell = grid[t.row] and grid[t.row][t.col]
            if cell then
                cell.scorched = true
                updateTileVisual(t.row, t.col)
                local r, c = t.row, t.col
                task.delay(2.5, function()
                    local g = grid[r] and grid[r][c]
                    if g then
                        g.scorched = false
                    end
                end)
            end
        end

        killPlayersOnTiles(affected)
        RE_HazardLanded:FireAllClients(h, affected)
    end

    hazardQueue = remaining
end

-- ─────────────────────────────────────────────
-- Game state
-- ─────────────────────────────────────────────

local State = {
    phase          = "Waiting",  -- Waiting | Countdown | Active | Overtime | Ended
    timer          = 0,
    overtimeStage  = 0,
    alivePlayers   = {},
    sonarCooldowns = {},         -- [player] = lastUsedTick
}

local function broadcastState(extra)
    local data = {
        phase         = State.phase,
        timer         = State.timer,
        overtimeStage = State.overtimeStage,
        aliveCount    = #State.alivePlayers,
    }
    if extra then
        for k, v in pairs(extra) do data[k] = v end
    end
    RE_GameState:FireAllClients(data)
end

local function eliminatePlayer(player)
    for i, p in ipairs(State.alivePlayers) do
        if p == player then
            table.remove(State.alivePlayers, i)
            RE_PlayerDied:FireAllClients(player)
            break
        end
    end
end

local function checkWinCondition()
    if State.phase ~= "Active" and State.phase ~= "Overtime" then return end
    if #State.alivePlayers == 0 then
        State.phase = "Ended"
        broadcastState({ winner = "Nobody" })
    elseif #State.alivePlayers == 1 and State.phase == "Overtime" then
        State.phase = "Ended"
        broadcastState({ winner = State.alivePlayers[1].Name })
    end
end

local function onCharacterAdded(player, char)
    local hum = char:WaitForChild("Humanoid")
    hum.Died:Connect(function()
        if State.phase == "Active" or State.phase == "Overtime" then
            eliminatePlayer(player)
            checkWinCondition()
        end
    end)
end

Players.PlayerAdded:Connect(function(player)
    State.sonarCooldowns[player] = 0
    player.CharacterAdded:Connect(function(char)
        onCharacterAdded(player, char)
    end)
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    State.sonarCooldowns[player] = nil
    if State.phase == "Active" or State.phase == "Overtime" then
        eliminatePlayer(player)
        checkWinCondition()
    end
end)

-- ─────────────────────────────────────────────
-- Sonar ability
-- ─────────────────────────────────────────────

RE_SonarRequest.OnServerEvent:Connect(function(player)
    if State.phase ~= "Active" and State.phase ~= "Overtime" then return end

    local now      = tick()
    local lastUsed = State.sonarCooldowns[player] or 0
    if now - lastUsed < GridConfig.SONAR_COOLDOWN then return end
    State.sonarCooldowns[player] = now

    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- Determine player's grid position
    local rel  = hrp.Position - ORIGIN
    local pCol = math.clamp(math.floor(rel.X / TILE), 0, W - 1)
    local pRow = math.clamp(math.floor(rel.Z / TILE), 0, H - 1)

    local radius = GridConfig.SONAR_RADIUS
    local window = GridConfig.SONAR_WINDOW
    local cutoff = now + window

    -- Build per-tile danger for the extended window
    local sonarData = {}
    for dr = -radius, radius do
        for dc = -radius, radius do
            if dr * dr + dc * dc <= radius * radius then
                local r = pRow + dr
                local c = pCol + dc
                if r >= 0 and r < H and c >= 0 and c < W then
                    local val = 0
                    for _, h in ipairs(hazardQueue) do
                        if h.landTime > now and h.landTime <= cutoff then
                            for _, t in ipairs(HazardTypes.getAffectedTiles(h.hazardType, h.row, h.col, h.metadata)) do
                                if t.row == r and t.col == c then
                                    val += 1
                                    break
                                end
                            end
                        end
                    end
                    table.insert(sonarData, { row = r, col = c, danger = val })
                end
            end
        end
    end

    RE_SonarResult:FireClient(player, sonarData)
end)

-- ─────────────────────────────────────────────
-- Game loop
-- ─────────────────────────────────────────────

local function currentCfg()
    if State.phase == "Active" then
        return { window = GridConfig.FORECAST_WINDOW, spawnInterval = GridConfig.SPAWN_INTERVAL }
    elseif State.phase == "Overtime" then
        return GridConfig.OVERTIME[State.overtimeStage]
    end
    return nil
end

local function spawnHazard()
    local t    = HazardTypes.random()
    local meta = HazardTypes.randomMetadata(t)
    local row  = math.random(0, H - 1)
    local col  = math.random(0, W - 1)
    -- Delay is within [3, 8] seconds so players have time to react
    local delay = 3 + math.random() * 5
    scheduleHazard(t, row, col, meta, delay)
end

local function resetGrid()
    hazardQueue = {}
    for r = 0, H - 1 do
        for c = 0, W - 1 do
            grid[r][c].danger  = 0
            grid[r][c].scorched = false
            updateTileVisual(r, c)
        end
    end
end

local function startGame()
    resetGrid()

    State.alivePlayers  = {}
    State.overtimeStage = 0
    for _, p in ipairs(Players:GetPlayers()) do
        table.insert(State.alivePlayers, p)
        p:LoadCharacter()
    end

    task.wait(1) -- brief pause after respawn

    State.phase     = "Active"
    State.timer     = GridConfig.GAME_DURATION
    gameStartTime   = tick()
    lastSpawn       = tick()
    lastDangerRefresh = tick()

    -- Pre-populate a few hazards so the board isn't empty at start
    for _ = 1, 6 do spawnHazard() end

    broadcastState()
end

-- These are module-level so the heartbeat closure can read/write them
gameStartTime     = 0
overtimeStartTime = 0
lastSpawn         = 0
lastDangerRefresh = 0

-- Auto-start: wait until at least 1 player joins, then countdown
Players.PlayerAdded:Connect(function()
    if State.phase ~= "Waiting" then return end
    task.wait(5) -- brief lobby wait
    if #Players:GetPlayers() >= 1 and State.phase == "Waiting" then
        State.phase = "Countdown"
        broadcastState()
        task.wait(3)
        startGame()
    end
end)

-- Handle the rare case where a player is already present when the script runs
task.defer(function()
    if #Players:GetPlayers() >= 1 and State.phase == "Waiting" then
        task.wait(5)
        if State.phase == "Waiting" then
            State.phase = "Countdown"
            broadcastState()
            task.wait(3)
            startGame()
        end
    end
end)

-- Auto-restart after a game ends
local function watchForRestart()
    while true do
        task.wait(1)
        if State.phase == "Ended" and #Players:GetPlayers() > 0 then
            task.wait(8) -- show winner screen
            State.phase = "Waiting"
            task.wait(5)
            if #Players:GetPlayers() > 0 and State.phase == "Waiting" then
                State.phase = "Countdown"
                broadcastState()
                task.wait(3)
                startGame()
            end
        end
    end
end
task.spawn(watchForRestart)

-- Main heartbeat: runs every frame
local prevSecond = 0

RunService.Heartbeat:Connect(function(dt)
    if State.phase ~= "Active" and State.phase ~= "Overtime" then return end

    local now = tick()
    local cfg = currentCfg()
    if not cfg then return end

    -- Land any due hazards
    processLanded()

    if State.phase == "Ended" then return end

    -- Schedule new hazard
    if now - lastSpawn >= cfg.spawnInterval then
        lastSpawn = now
        spawnHazard()
    end

    -- Recalculate danger values
    if now - lastDangerRefresh >= GridConfig.DANGER_REFRESH then
        lastDangerRefresh = now
        recalcDanger(cfg.window)
    end

    -- Timer logic
    if State.phase == "Active" then
        local elapsed = now - gameStartTime
        State.timer   = math.max(0, GridConfig.GAME_DURATION - elapsed)

        local sec = math.floor(elapsed)
        if sec ~= prevSecond then
            prevSecond = sec
            broadcastState()
        end

        if State.timer <= 0 then
            -- Enter first overtime stage
            State.phase         = "Overtime"
            State.overtimeStage = 1
            overtimeStartTime   = now
            broadcastState()
        end

    elseif State.phase == "Overtime" then
        local elapsed = now - overtimeStartTime
        local stage   = GridConfig.OVERTIME[State.overtimeStage]

        local sec = math.floor(elapsed)
        if sec ~= prevSecond then
            prevSecond = sec
            broadcastState()
        end

        -- Advance overtime stage when duration expires (stage 3 duration = 0 → never advances)
        if stage and stage.duration > 0 and elapsed >= stage.duration then
            State.overtimeStage = math.min(State.overtimeStage + 1, #GridConfig.OVERTIME)
            overtimeStartTime   = now
            broadcastState()
        end

        -- In overtime, single survivor immediately wins
        if #State.alivePlayers == 1 then
            State.phase = "Ended"
            broadcastState({ winner = State.alivePlayers[1].Name })
        end
    end
end)
