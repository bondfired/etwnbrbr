-- Shared constants. Loaded by both server and client.
local GridConfig = {}

GridConfig.GRID_WIDTH    = 20    -- columns
GridConfig.GRID_HEIGHT   = 20    -- rows
GridConfig.TILE_SIZE     = 8     -- studs per tile
GridConfig.TILE_THICK    = 1.5   -- tile part height
GridConfig.ORIGIN        = Vector3.new(-80, 0, -80)  -- world position of tile (0,0) corner

GridConfig.FORECAST_WINDOW  = 5    -- seconds to look ahead for normal display
GridConfig.DANGER_REFRESH   = 0.5  -- seconds between danger recalculations

GridConfig.GAME_DURATION    = 60   -- seconds of regular play
GridConfig.SPAWN_INTERVAL   = 1.5  -- seconds between new hazard spawns at start

-- Overtime stages: forecast window shrinks, hazards accelerate
GridConfig.OVERTIME = {
    { window = 3, spawnInterval = 1.0, duration = 20 },
    { window = 2, spawnInterval = 0.6, duration = 20 },
    { window = 1, spawnInterval = 0.3, duration = 0  }, -- until last survivor
}

-- Sonar ability
GridConfig.SONAR_COOLDOWN = 15   -- seconds
GridConfig.SONAR_RADIUS   = 5    -- tile radius
GridConfig.SONAR_WINDOW   = 8    -- extended forecast seconds for sonar

-- Tile color by danger value (0 = safe, 8+ = extreme)
GridConfig.DANGER_COLORS = {
    [0] = Color3.fromRGB( 35,  35,  45),
    [1] = Color3.fromRGB( 20,  90, 200),
    [2] = Color3.fromRGB( 15, 160,  75),
    [3] = Color3.fromRGB(210, 185,  15),
    [4] = Color3.fromRGB(230, 120,  10),
    [5] = Color3.fromRGB(215,  45,  10),
    [6] = Color3.fromRGB(165,   5,   5),
    [7] = Color3.fromRGB(125,   5, 145),
    [8] = Color3.fromRGB( 60,   0,  80),
}

return GridConfig
