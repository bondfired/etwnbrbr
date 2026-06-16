-- All 9 abilities: 3 per slot (Movement / Utility / Defensive).
-- Keybinds: Z = Movement, X = Utility, C = Defensive.
local AbilityConfig = {}

AbilityConfig.SLOTS = { "Movement", "Utility", "Defensive" }

AbilityConfig.KEYBINDS = {
    Movement  = "Z",
    Utility   = "X",
    Defensive = "C",
}

AbilityConfig.ABILITIES = {
    -- ── MOVEMENT ──────────────────────────────────────────────────────────
    BlinkStep = {
        slot        = "Movement",
        name        = "Blink Step",
        desc        = "Teleport to a safe tile within 5 tiles.",
        cooldown    = 8,
        color       = Color3.fromRGB(100, 180, 255),
        startUnlocked = true,
    },
    PhaseDash = {
        slot        = "Movement",
        name        = "Phase Dash",
        desc        = "Dash forward ignoring hazard damage for 0.8s.",
        cooldown    = 10,
        color       = Color3.fromRGB(150, 100, 255),
        startUnlocked = false,
    },
    TileSwap = {
        slot        = "Movement",
        name        = "Tile Swap",
        desc        = "Swap with a random safe tile nearby.",
        cooldown    = 12,
        color       = Color3.fromRGB(80, 255, 180),
        startUnlocked = false,
    },

    -- ── UTILITY ───────────────────────────────────────────────────────────
    FuturePing = {
        slot        = "Utility",
        name        = "Future Ping",
        desc        = "Reveal a 3×3 area's danger for 5 seconds.",
        cooldown    = 12,
        color       = Color3.fromRGB(255, 220, 60),
        startUnlocked = true,
    },
    SafeBeacon = {
        slot        = "Utility",
        name        = "Safe Beacon",
        desc        = "Drop a beacon that zeroes nearby danger for 6s.",
        cooldown    = 18,
        color       = Color3.fromRGB(60, 255, 120),
        startUnlocked = false,
    },
    ForecastSteal = {
        slot        = "Utility",
        name        = "Forecast Steal",
        desc        = "Copy a random player's local danger map for 3s.",
        cooldown    = 20,
        color       = Color3.fromRGB(255, 100, 200),
        startUnlocked = false,
    },

    -- ── DEFENSIVE ─────────────────────────────────────────────────────────
    TemporalShield = {
        slot        = "Defensive",
        name        = "Temporal Shield",
        desc        = "Negate the next hazard that would hit you.",
        cooldown    = 15,
        color       = Color3.fromRGB(255, 160, 40),
        startUnlocked = true,
    },
    RewindStep = {
        slot        = "Defensive",
        name        = "Rewind Step",
        desc        = "Return to your position from 2 seconds ago.",
        cooldown    = 14,
        color       = Color3.fromRGB(200, 60, 255),
        startUnlocked = false,
    },
    DangerDampener = {
        slot        = "Defensive",
        name        = "Danger Dampener",
        desc        = "Your tile deals no damage for 3s.",
        cooldown    = 20,
        color       = Color3.fromRGB(60, 200, 100),
        startUnlocked = false,
    },
}

AbilityConfig.DEFAULT_LOADOUT = {
    Movement  = "BlinkStep",
    Utility   = "FuturePing",
    Defensive = "TemporalShield",
}

-- Abilities unlocked by default (before any level rewards)
AbilityConfig.STARTER_UNLOCKS = { "BlinkStep", "FuturePing", "TemporalShield" }

return AbilityConfig
