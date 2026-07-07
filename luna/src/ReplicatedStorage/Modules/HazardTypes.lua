-- Hazard type definitions shared between server and client.
local GridConfig = require(script.Parent.GridConfig)

local HazardTypes = {}

local W = GridConfig.GRID_WIDTH
local H = GridConfig.GRID_HEIGHT

-- Returns a list of {row, col} tiles affected by a hazard landing at (originRow, originCol).
-- `metadata` holds type-specific extra data (laser direction, meteor arc direction, etc.)
function HazardTypes.getAffectedTiles(hazardType, originRow, originCol, metadata)
    local tiles = {}

    local function add(r, c)
        if r >= 0 and r < H and c >= 0 and c < W then
            table.insert(tiles, { row = r, col = c })
        end
    end

    if hazardType == "Standard" then
        -- 3×3 blast; center tile is counted twice (dealt with in danger accumulation)
        for dr = -1, 1 do
            for dc = -1, 1 do
                add(originRow + dr, originCol + dc)
            end
        end
        add(originRow, originCol) -- extra hit on center

    elseif hazardType == "Cluster" then
        -- Roughly diamond-shaped 5-tile radius
        for dr = -2, 2 do
            for dc = -2, 2 do
                if math.abs(dr) + math.abs(dc) <= 3 then
                    add(originRow + dr, originCol + dc)
                end
            end
        end

    elseif hazardType == "Laser" then
        -- Full row or full column
        if metadata and metadata.direction == "H" then
            for c = 0, W - 1 do add(originRow, c) end
        else
            for r = 0, H - 1 do add(r, originCol) end
        end

    elseif hazardType == "Meteor" then
        -- ~6-tile diagonal arc, one tile wide
        local d = (metadata and metadata.dir) or { 1, 1 }
        for i = 0, 5 do
            add(originRow + d[1] * i, originCol + d[2] * i)
            add(originRow + d[1] * i, originCol + d[2] * i + d[2])
        end
    end

    return tiles
end

-- Weighted random hazard type selection (Standard is most common)
local POOL = {
    "Standard", "Standard", "Standard",
    "Cluster",  "Cluster",
    "Laser",
    "Meteor",
}
function HazardTypes.random()
    return POOL[math.random(#POOL)]
end

-- Generates random metadata appropriate for the hazard type
function HazardTypes.randomMetadata(hazardType)
    if hazardType == "Laser" then
        return { direction = math.random(2) == 1 and "H" or "V" }
    elseif hazardType == "Meteor" then
        local dirs = { {1,1}, {1,-1}, {-1,1}, {-1,-1} }
        return { dir = dirs[math.random(#dirs)] }
    end
    return {}
end

-- Display info used by both server warning emits and client HUD
HazardTypes.DISPLAY = {
    Standard = { label = "BOMB",    color = Color3.fromRGB(255, 100,  50) },
    Cluster  = { label = "CLUSTER", color = Color3.fromRGB(255, 180,   0) },
    Laser    = { label = "LASER",   color = Color3.fromRGB( 80, 200, 255) },
    Meteor   = { label = "METEOR",  color = Color3.fromRGB(255, 140, 220) },
}

return HazardTypes
