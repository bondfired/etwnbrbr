-- XP, leveling, credits, and medal definitions.
local P = {}

P.MAX_LEVEL = 20

-- Cumulative XP required to REACH each level (index = level number)
P.XP_PER_LEVEL = {
    0, 100, 250, 450, 700, 1000,
    1350, 1750, 2200, 2700, 3300,
    4000, 4800, 5700, 6700, 7800,
    9000, 10300, 11700, 13200,
}

P.XP_SOURCES = {
    PER_SECOND_SURVIVED = 2,
    WIN                 = 150,
    TOP3                = 75,
    ABILITY_USE         = 5,
    NEAR_MISS           = 3,
}

P.CREDIT_SOURCES = {
    BASE       = 20,
    PER_SECOND = 0.5,
    WIN        = 50,
    TOP3       = 25,
}

-- What players receive when they hit a new level
P.LEVEL_REWARDS = {
    [2]  = { credits = 100, unlock = "ability:PhaseDash"    },
    [4]  = { credits = 150, unlock = "ability:ForecastSteal" },
    [5]  = { credits = 200, unlock = "skin:FutureSeer"      },
    [8]  = { credits = 250, unlock = "ability:SafeBeacon"   },
    [10] = { credits = 500, unlock = "skin:GlitchProphet"   },
    [12] = { credits = 300, unlock = "ability:RewindStep"   },
    [14] = { credits = 350, unlock = "ability:DangerDampener"},
    [15] = { credits = 500, unlock = "skin:HazardDiver"     },
    [17] = { credits = 400, unlock = "ability:TileSwap"     },
    [20] = { credits = 1000, unlock = "skin:CyberOracle"    },
}

-- Post-game medals (awarded per match)
P.MEDALS = {
    { id = "LastStanding",  name = "Last Standing",  desc = "Won the match",           xp = 100 },
    { id = "Survivor",      name = "Survivor",        desc = "Reached overtime",        xp = 35  },
    { id = "CloseCall",     name = "Close Call",      desc = "5+ near-misses survived", xp = 40  },
    { id = "AbilityMaster", name = "Ability Master",  desc = "Used all 3 ability slots",xp = 25  },
    { id = "FutureReader",  name = "Future Reader",   desc = "Never on danger > 3",     xp = 50  },
}

return P
