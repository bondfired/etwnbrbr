-- Skin and shop item definitions.
-- Skins use body-part BrickColor names so they work with R6 characters.
local ShopConfig = {}

ShopConfig.SKINS = {
    {
        id          = "Noob",
        name        = "Classic Noob",
        desc        = "The original. Timeless.",
        price       = 0,
        free        = true,
        colors = {
            Head      = BrickColor.new("Yellow"),
            Torso     = BrickColor.new("Bright blue"),
            LeftArm   = BrickColor.new("Bright green"),
            RightArm  = BrickColor.new("Bright green"),
            LeftLeg   = BrickColor.new("Bright yellow"),
            RightLeg  = BrickColor.new("Bright yellow"),
        },
    },
    {
        id          = "FutureSeer",
        name        = "Future Seer",
        desc        = "They saw this coming.",
        price       = 0,
        levelUnlock = 5,
        colors = {
            Head      = BrickColor.new("Light blue"),
            Torso     = BrickColor.new("Navy blue"),
            LeftArm   = BrickColor.new("Navy blue"),
            RightArm  = BrickColor.new("Navy blue"),
            LeftLeg   = BrickColor.new("Dark blue"),
            RightLeg  = BrickColor.new("Dark blue"),
        },
    },
    {
        id          = "GlitchProphet",
        name        = "Glitch Prophet",
        desc        = "Reality has issues with them.",
        price       = 0,
        levelUnlock = 10,
        colors = {
            Head      = BrickColor.new("Magenta"),
            Torso     = BrickColor.new("Black"),
            LeftArm   = BrickColor.new("Dark purple"),
            RightArm  = BrickColor.new("Dark purple"),
            LeftLeg   = BrickColor.new("Black"),
            RightLeg  = BrickColor.new("Black"),
        },
    },
    {
        id          = "HazardDiver",
        name        = "Hazard Diver",
        desc        = "Professionally reckless.",
        price       = 0,
        levelUnlock = 15,
        colors = {
            Head      = BrickColor.new("Bright orange"),
            Torso     = BrickColor.new("Dark grey"),
            LeftArm   = BrickColor.new("Reddish brown"),
            RightArm  = BrickColor.new("Reddish brown"),
            LeftLeg   = BrickColor.new("Dark grey"),
            RightLeg  = BrickColor.new("Dark grey"),
        },
    },
    {
        id          = "CyberOracle",
        name        = "Cyber Oracle",
        desc        = "Max prestige.",
        price       = 0,
        levelUnlock = 20,
        colors = {
            Head      = BrickColor.new("Cyan"),
            Torso     = BrickColor.new("Dark blue"),
            LeftArm   = BrickColor.new("Teal"),
            RightArm  = BrickColor.new("Teal"),
            LeftLeg   = BrickColor.new("Dark blue"),
            RightLeg  = BrickColor.new("Dark blue"),
        },
    },
}

-- Map by id for quick lookup
ShopConfig.SKIN_MAP = {}
for _, skin in ipairs(ShopConfig.SKINS) do
    ShopConfig.SKIN_MAP[skin.id] = skin
end

return ShopConfig
