#!/usr/bin/env python3
"""Phase 1: Replace all config module source code for SoundScape RNG."""

def replace_cdata(content, unique_str, new_source, label=""):
    pos = content.find(unique_str)
    if pos == -1:
        print(f"WARN: not found [{label}]: {unique_str[:60]}")
        return content
    marker = '<![CDATA['
    cs = content.rfind(marker, 0, pos)
    ce = content.find(']]>', pos)
    if cs == -1 or ce == -1:
        print(f"WARN: CDATA bounds not found [{label}]")
        return content
    result = content[:cs + len(marker)] + new_source + '\n' + content[ce:]
    print(f"OK: {label}")
    return result

def main():
    fp = "/home/user/etwnbrbr/SoundScape_RNG.rbxlx"
    with open(fp, 'r', encoding='utf-8') as f:
        c = f.read()

    # 1. Cards Config (Collectibles)
    c = replace_cdata(c, 'Cards.RollWeights = weights', CARDS, "Cards")
    # 2. RNG Config
    c = replace_cdata(c, 'BANNER_ID = "default"', RNG_CFG, "RNG")
    # 3. Items Config
    c = replace_cdata(c, 'Description = "Instantly open Cards."', ITEMS, "Items")
    # 4. Upgrades Config
    c = replace_cdata(c, 'PointsPerRolls = 1000', UPGRADES, "Upgrades")
    # 5. Quests Config
    c = replace_cdata(c, 'Quests.RefreshSeconds', QUESTS, "Quests")
    # 6. DataSchema
    c = replace_cdata(c, 'Schema.VERSION = 1', SCHEMA, "DataSchema")
    # 7. Codes
    c = replace_cdata(c, '["WELCOME"] = {', CODES, "Codes")
    # 8. Monetization
    c = replace_cdata(c, 'AutoRoll  = { id = 0000000 }', MONET, "Monetization")
    # 9. Leveling
    c = replace_cdata(c, 'RollsPerLevel = { base = 1000', LEVELING, "Leveling")
    # 10. AdminCommands
    c = replace_cdata(c, 'function AdminCommands.Run(plr, text: string)', ADMINCMDS, "AdminCommands")

    with open(fp, 'w', encoding='utf-8') as f:
        f.write(c)
    print("Phase 1 complete.")

# =====================================================================
# LUA SOURCE STRINGS
# =====================================================================

CARDS = r"""local Cards = {}

Cards.FragmentTypes = { "Beat", "Melody", "Bass", "Vocal" }

Cards.FragmentRarity = {
	{ id = "Common",   chance = 0.60, order = 1, color = Color3.fromRGB(150, 160, 170) },
	{ id = "Uncommon", chance = 0.25, order = 2, color = Color3.fromRGB(80, 200, 120)  },
	{ id = "Rare",     chance = 0.10, order = 3, color = Color3.fromRGB(70, 150, 255)  },
	{ id = "Epic",     chance = 0.04, order = 4, color = Color3.fromRGB(180, 70, 255)  },
	{ id = "Mythic",   chance = 0.01, order = 5, color = Color3.fromRGB(255, 200, 50)  },
}
Cards.FragmentRarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic" }

Cards.Rarity = {
	Common = {
		id = "Common", order = 1,
		color = Color3.fromRGB(150, 160, 170),
		stroke = Color3.fromRGB(60, 65, 70),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(130, 140, 150)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(150, 160, 170)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(110, 120, 130)),
			},
			Transparency = NumberSequence.new(0),
		},
	},
	Uncommon = {
		id = "Uncommon", order = 2,
		color = Color3.fromRGB(80, 200, 120),
		stroke = Color3.fromRGB(30, 80, 45),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(60, 180, 100)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(80, 200, 120)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(40, 160, 80)),
			},
			Transparency = NumberSequence.new(0),
		},
	},
	Rare = {
		id = "Rare", order = 3,
		color = Color3.fromRGB(70, 150, 255),
		stroke = Color3.fromRGB(25, 60, 120),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(40, 120, 230)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(70, 150, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(20, 100, 200)),
			},
			Transparency = NumberSequence.new(0),
		},
	},
	Epic = {
		id = "Epic", order = 4,
		color = Color3.fromRGB(180, 70, 255),
		stroke = Color3.fromRGB(70, 20, 110),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(140, 40, 220)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(180, 70, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(100, 20, 180)),
			},
			Transparency = NumberSequence.new(0),
		},
	},
	Mythic = {
		id = "Mythic", order = 5,
		color = Color3.fromRGB(255, 200, 50),
		stroke = Color3.fromRGB(120, 90, 15),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 230, 120)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 240, 160)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 180, 30)),
			},
			Transparency = NumberSequence.new(0),
		},
	},
}

Cards.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Mythic" }

Cards.UnitType = { Artist = "Artist", LP = "LP", EP = "EP", Single = "Single" }

Cards.Zones = {
	City      = { id = "City",      name = "City",       order = 1 },
	NeonAlley = { id = "NeonAlley", name = "Neon Alley", order = 2 },
	Desert    = { id = "Desert",    name = "Desert",     order = 3 },
	Arcade    = { id = "Arcade",    name = "Arcade",     order = 4 },
}

Cards.Catalog = {
	-- ===== ARTISTS (Common, 2-3 fragments, high drop rate) =====
	{
		id = "tyler_artist", name = "Tyler, The Creator",
		artist = "Tyler, The Creator", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Beat", "Melody"},
		image = "rbxassetid://0", color = Color3.fromRGB(255, 183, 197),
		rollPower = 2, zone = "City", power = 100,
		tags = {"HipHop"},
	},
	{
		id = "kendrick_artist", name = "Kendrick Lamar",
		artist = "Kendrick Lamar", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Beat", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(50, 50, 50),
		rollPower = 2, zone = "City", power = 100,
		tags = {"HipHop"},
	},
	{
		id = "frank_artist", name = "Frank Ocean",
		artist = "Frank Ocean", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(230, 230, 230),
		rollPower = 3, zone = "NeonAlley", power = 100,
		tags = {"RnB"},
	},
	{
		id = "kanye_artist", name = "Kanye West",
		artist = "Kanye West", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Beat", "Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(60, 60, 60),
		rollPower = 3, zone = "City", power = 120,
		tags = {"HipHop"},
	},
	{
		id = "travis_artist", name = "Travis Scott",
		artist = "Travis Scott", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Beat", "Bass"},
		image = "rbxassetid://0", color = Color3.fromRGB(120, 80, 40),
		rollPower = 4, zone = "Desert", power = 100,
		tags = {"HipHop"},
	},
	{
		id = "sza_artist", name = "SZA",
		artist = "SZA", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(200, 150, 100),
		rollPower = 4, zone = "NeonAlley", power = 100,
		tags = {"RnB"},
	},
	{
		id = "weeknd_artist", name = "The Weeknd",
		artist = "The Weeknd", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Beat", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(200, 30, 30),
		rollPower = 3, zone = "NeonAlley", power = 100,
		tags = {"RnB"},
	},
	{
		id = "drake_artist", name = "Drake",
		artist = "Drake", collectibleType = "Artist",
		rarity = "Common", unitType = "Artist",
		fragments = {"Melody", "Bass"},
		image = "rbxassetid://0", color = Color3.fromRGB(20, 20, 20),
		rollPower = 3, zone = "City", power = 100,
		tags = {"HipHop"},
	},

	-- ===== LPs (Rare, 4 fragments, medium drop rate) =====
	{
		id = "igor_lp", name = "IGOR",
		artist = "Tyler, The Creator", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(255, 183, 197),
		rollPower = 50, zone = "City", power = 500,
		tags = {"Album"},
	},
	{
		id = "gkmc_lp", name = "good kid, m.A.A.d city",
		artist = "Kendrick Lamar", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(180, 120, 60),
		rollPower = 60, zone = "City", power = 550,
		tags = {"Album"},
	},
	{
		id = "blonde_lp", name = "Blonde",
		artist = "Frank Ocean", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(229, 229, 229),
		rollPower = 80, zone = "NeonAlley", power = 600,
		tags = {"Album"},
	},
	{
		id = "mbdtf_lp", name = "My Beautiful Dark Twisted Fantasy",
		artist = "Kanye West", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(180, 30, 30),
		rollPower = 70, zone = "Desert", power = 650,
		tags = {"Album"},
	},
	{
		id = "astroworld_lp", name = "ASTROWORLD",
		artist = "Travis Scott", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(255, 200, 0),
		rollPower = 60, zone = "Desert", power = 500,
		tags = {"Album"},
	},
	{
		id = "sos_lp", name = "SOS",
		artist = "SZA", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(70, 130, 180),
		rollPower = 50, zone = "NeonAlley", power = 520,
		tags = {"Album"},
	},
	{
		id = "afterhours_lp", name = "After Hours",
		artist = "The Weeknd", collectibleType = "LP",
		rarity = "Rare", unitType = "LP",
		fragments = {"Beat", "Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(200, 30, 30),
		rollPower = 65, zone = "NeonAlley", power = 540,
		tags = {"Album"},
	},

	-- ===== EPs (Epic, 3 fragments, low drop rate) =====
	{
		id = "flowerboy_ep", name = "Flower Boy Demos",
		artist = "Tyler, The Creator", collectibleType = "EP",
		rarity = "Epic", unitType = "EP",
		fragments = {"Beat", "Melody", "Bass"},
		image = "rbxassetid://0", color = Color3.fromRGB(247, 209, 74),
		rollPower = 500, zone = "Arcade", power = 1500,
		tags = {"EP"},
	},
	{
		id = "untitled_ep", name = "untitled unmastered",
		artist = "Kendrick Lamar", collectibleType = "EP",
		rarity = "Epic", unitType = "EP",
		fragments = {"Beat", "Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(40, 40, 40),
		rollPower = 600, zone = "Desert", power = 1600,
		tags = {"EP"},
	},
	{
		id = "endless_ep", name = "Endless",
		artist = "Frank Ocean", collectibleType = "EP",
		rarity = "Epic", unitType = "EP",
		fragments = {"Melody", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(180, 180, 180),
		rollPower = 700, zone = "NeonAlley", power = 1800,
		tags = {"EP"},
	},
	{
		id = "cruel_ep", name = "Cruel Summer",
		artist = "Kanye West", collectibleType = "EP",
		rarity = "Epic", unitType = "EP",
		fragments = {"Beat", "Bass", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(220, 180, 80),
		rollPower = 550, zone = "Desert", power = 1400,
		tags = {"EP"},
	},

	-- ===== SINGLES (Mythic, 1-2 fragments, very low drop rate) =====
	{
		id = "earfquake_single", name = "EARFQUAKE",
		artist = "Tyler, The Creator", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(255, 183, 197),
		rollPower = 2000, zone = "Arcade", power = 5000,
		tags = {"Single"},
	},
	{
		id = "humble_single", name = "HUMBLE.",
		artist = "Kendrick Lamar", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Beat", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(139, 0, 0),
		rollPower = 2500, zone = "City", power = 5500,
		tags = {"Single"},
	},
	{
		id = "nights_single", name = "Nights",
		artist = "Frank Ocean", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Melody"},
		image = "rbxassetid://0", color = Color3.fromRGB(20, 20, 80),
		rollPower = 3000, zone = "NeonAlley", power = 6000,
		tags = {"Single"},
	},
	{
		id = "runaway_single", name = "Runaway",
		artist = "Kanye West", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(180, 30, 30),
		rollPower = 4000, zone = "Desert", power = 8000,
		tags = {"Single"},
	},
	{
		id = "sickomode_single", name = "SICKO MODE",
		artist = "Travis Scott", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Beat", "Bass"},
		image = "rbxassetid://0", color = Color3.fromRGB(50, 10, 80),
		rollPower = 3500, zone = "Desert", power = 7000,
		tags = {"Single"},
	},
	{
		id = "killbill_single", name = "Kill Bill",
		artist = "SZA", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(200, 60, 60),
		rollPower = 2800, zone = "Arcade", power = 5800,
		tags = {"Single"},
	},
	{
		id = "blindinglights_single", name = "Blinding Lights",
		artist = "The Weeknd", collectibleType = "Single",
		rarity = "Mythic", unitType = "Single",
		fragments = {"Melody", "Vocal"},
		image = "rbxassetid://0", color = Color3.fromRGB(255, 40, 40),
		rollPower = 3200, zone = "NeonAlley", power = 6500,
		tags = {"Single"},
	},
}

local rollPool = {}
local byId     = {}
local weights  = {}

for _, c in ipairs(Cards.Catalog) do
	byId[c.id] = c
	local denom = tonumber(c.rollPower)
	if c.id and denom and denom > 0 then
		local w = 1 / denom
		table.insert(rollPool, { id = c.id, weight = w })
		weights[c.id] = w
	end
end

Cards.ById        = byId
Cards.RollPool    = rollPool
Cards.RollWeights = weights

function Cards.RollFragmentRarity(luckMult: number?): string
	local mult = luckMult or 1
	local r = math.random()
	local cumulative = 0
	for i = #Cards.FragmentRarity, 1, -1 do
		local entry = Cards.FragmentRarity[i]
		local adjusted = entry.chance
		if i >= 3 then adjusted = adjusted * mult end
		cumulative += adjusted
		if r <= cumulative then return entry.id end
	end
	return "Common"
end

function Cards.PickRandomFragment(collectibleId: string): string?
	local def = byId[collectibleId]
	if not def or not def.fragments or #def.fragments == 0 then return nil end
	return def.fragments[math.random(1, #def.fragments)]
end

function Cards.GetCollectiblesForZone(zoneId: string): {any}
	local result = {}
	for _, c in ipairs(Cards.Catalog) do
		if c.zone == zoneId then table.insert(result, c) end
	end
	return result
end

function Cards.IsTrackComplete(fragments: any, collectibleId: string): boolean
	local def = byId[collectibleId]
	if not def or not def.fragments then return false end
	if type(fragments) ~= "table" then return false end
	local coll = fragments[collectibleId]
	if type(coll) ~= "table" then return false end
	for _, frag in ipairs(def.fragments) do
		if not coll[frag] or (coll[frag].count or 0) < 1 then return false end
	end
	return true
end

function Cards.GetLowestFragmentRarity(fragments: any, collectibleId: string): string
	local def = byId[collectibleId]
	if not def then return "Common" end
	local coll = type(fragments) == "table" and fragments[collectibleId] or {}
	local worst = 99
	for _, frag in ipairs(def.fragments or {}) do
		local fData = coll[frag]
		if fData then
			local rIdx = 1
			for i, r in ipairs(Cards.FragmentRarity) do
				if r.id == (fData.bestRarity or "Common") then rIdx = i; break end
			end
			worst = math.min(worst, rIdx)
		else
			worst = 1
		end
	end
	local entry = Cards.FragmentRarity[worst] or Cards.FragmentRarity[1]
	return entry.id
end

return Cards
"""

RNG_CFG = r"""return {
	ScanInterval = 0.45,
	AutoScanInterval = 0.6,
	QuickScanInterval = 0.25,

	Pity = { enabled = true, target = "Rare", scansForBoost = 30, boostPerStep = 0.005, maxBoost = 0.06 },
	MultiScanSizes = { x1 = 1, x5 = 5, x10 = 10 },
	AnimationMs = 400,

	Soundstorm = {
		intervalMin = 300,
		intervalMax = 600,
		duration = 60,
		dropMultiplier = 3.0,
		rarityBoost = 1.5,
	},

	Zones = {
		City      = { dropMult = 1.0,  rarityBoost = 1.0 },
		NeonAlley = { dropMult = 1.1,  rarityBoost = 1.05 },
		Desert    = { dropMult = 0.9,  rarityBoost = 1.15 },
		Arcade    = { dropMult = 0.8,  rarityBoost = 1.25 },
	},
}
"""

ITEMS = r"""local Items = {
	FragmentScanner = {
		id = "FragmentScanner",
		name = "Fragment Scanner",
		icon = "rbxassetid://132292029713675",
		Description = "Instantly scan for fragments in your zone.",
	},

	RarityBooster = {
		id = "RarityBooster",
		name = "Rarity Booster (60s)",
		icon = "rbxassetid://124515443468836",
		Description = "Boost fragment rarity for 60 seconds.",
		use = { payload = { mult = 1.5, duration = 60 } },
	},

	FragmentMagnet = {
		id = "FragmentMagnet",
		name = "Fragment Magnet (120s)",
		icon = "rbxassetid://132292029713675",
		Description = "Auto-collect nearby fragments for 120 seconds.",
		use = { payload = { duration = 120 } },
	},
}
return Items
"""

UPGRADES = r"""return {
	PointsPerRolls = 500,
	Upgrades = {
		Luck = {
			name = "Drop Rate",
			maxLevel = 100,
			perLevel = 0.30,
			desc = function(lv, per)
				return ("+%.2f%% Drop Rate\n(+%.2f%% per level)"):format(lv * per, per)
			end,
			color = Color3.fromRGB(80, 200, 120),
		},
		RollSpeed = {
			maxLevel = 50,
			perLevel = 3,
			name = function() return "Scan Speed" end,
			desc = function(lvl, per) return ("+%d%% Scan Speed (+%d%% per level)"):format(lvl*per, per) end,
		},
		PotionDuration = {
			maxLevel = 60,
			perLevel = 1,
			name = function() return "Booster Duration" end,
			desc = function(lvl, per) return ("+%d%% Booster Duration (+%d%% per level)"):format(lvl*per, per) end,
		},
	},
}
"""

QUESTS = r"""local Quests = {}

Quests.RefreshSeconds = 24 * 60 * 60
Quests.DailyCount = 5

Quests.Filters = {
	Daily = { id = "Daily", name = "Daily Quests" },
}

Quests.Icons = {
	Scan   = "rbxassetid://132292029713675",
	Boost  = "rbxassetid://124515443468836",
}

Quests.Pool = {
	Daily = {
		{
			id = "scan_15",
			group = "Scanning",
			name = "Scan 15 times",
			statKey = "Rolls",
			target  = 15,
			icon    = "rbxassetid://132292029713675",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 3} },
				Boost = { {id = "RarityBooster", amount = 1} },
			},
		},
		{
			id = "scan_50",
			group = "Scanning",
			name = "Scan 50 times",
			statKey = "Rolls",
			target  = 50,
			icon    = "rbxassetid://132292029713675",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 5} },
				Boost = { {id = "RarityBooster", amount = 2} },
			},
		},
		{
			id = "use_booster_1",
			name = "Use 1 Rarity Booster",
			statKey = "PotionsUsed",
			target  = 1,
			icon    = "rbxassetid://124515443468836",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 5} },
				Boost = { {id = "RarityBooster", amount = 1} },
			},
		},
		{
			id = "collect_rare_1",
			group = "Collecting",
			name = "Find a Rare+ fragment",
			statKey = "RareFinds",
			target  = 1,
			icon    = "rbxassetid://132292029713675",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 8} },
				Boost = { {id = "RarityBooster", amount = 2} },
			},
		},
		{
			id = "playtime_5",
			group = "Playtime",
			name = "Play for 5 minutes",
			statKey = "OnlineSeconds",
			target  = 300,
			icon    = "rbxassetid://14334363335",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 3} },
				Boost = { {id = "RarityBooster", amount = 1} },
			},
		},
		{
			id = "fuse_1",
			group = "Fusion",
			name = "Complete 1 Track",
			statKey = "TracksFused",
			target  = 1,
			icon    = "rbxassetid://132292029713675",
			rewards = {
				Scan = { {id = "FragmentScanner", amount = 10} },
				Boost = { {id = "RarityBooster", amount = 3} },
			},
		},
	}
}

Quests.RarityGradients = {
	Default = ColorSequence.new{
		ColorSequenceKeypoint.new(0.00, Color3.fromRGB(140, 140, 255)),
		ColorSequenceKeypoint.new(0.50, Color3.fromRGB(80, 220, 255)),
		ColorSequenceKeypoint.new(1.00, Color3.fromRGB(140, 140, 255)),
	},
}

return Quests
"""

SCHEMA = r"""local Schema = {}

Schema.VERSION = 2

Schema.DEFAULT = {
	__v = Schema.VERSION,
	Rolls = 0,
	Level = 1,
	Xp = 0,
	Pity = { misses = 0, boost = 0 },
	Fragments = {},
	CompletedTracks = {},
	Equipped = {},
	Items = {},
	Upgrades = { Levels = {}, Points = 0, PointsSpent = 0, RollsDone = 0 },
	Codes = {},
	Zone = "City",
	Quests = {},
	Cards = {},
}

function Schema.migrate(data: table): table
	data = table.clone(data or {})
	local v = tonumber(data.__v or 0) or 0

	if v < 1 then
		data.Pity = data.Pity or { misses = 0, boost = 0 }
		data.Upgrades = data.Upgrades or { Levels = {}, Points = 0, PointsSpent = 0, RollsDone = 0 }
		v = 1
	end

	if v < 2 then
		data.Fragments = data.Fragments or {}
		data.CompletedTracks = data.CompletedTracks or {}
		data.Equipped = data.Equipped or {}
		data.Items = data.Items or {}
		data.Codes = data.Codes or {}
		data.Zone = data.Zone or "City"
		data.Cards = data.Cards or {}
		v = 2
	end

	data.__v = v
	return data
end

return Schema
"""

CODES = r"""return {
	["SOUNDSCAPE"] = {
		reward = {
			RarityBooster   = 3,
			FragmentScanner = 5,
		},
		expiration    = "never",
		globalMaxUses = 0,
	},

	["BEATDROP"] = {
		reward = {
			RarityBooster = 5,
		},
		expiration    = "7D",
		globalMaxUses = 0,
	},

	["FIRSTTRACK"] = {
		reward = {
			FragmentScanner = 10,
			RarityBooster   = 3,
		},
		expiration    = "1M",
		globalMaxUses = 500,
	},

	["MYTHICHUNT"] = {
		reward = {
			RarityBooster   = 10,
			FragmentMagnet  = 2,
		},
		expiration    = "14D",
		globalMaxUses = 200,
	},
}
"""

MONET = r"""return {
	Gamepasses = {
		AutoRoll  = { id = 0000000 },
		QuickRoll = { id = 0000000 },
	},
}
"""

LEVELING = r"""return {
	MaxLevel = 200,
	RollsPerLevel = { base = 500, pow = 1.15 },
}
"""

ADMINCMDS = r"""local RS        = game:GetService("ReplicatedStorage")
local Cards     = require(RS.Main.Configs.Cards)
local ItemsCfg  = require(RS.Main.Configs.Items)
local GameCore  = require(RS.Main.GameCore)

local AdminCommands = {}

local function trim(s: string?): string
	return (s and s:match("^%s*(.-)%s*$") or "")
end
local function norm(s: string?): string
	return string.lower(trim(s or ""))
end

local _cmds: {[string]: {name: string, desc: string, run: (any, {string}) -> string}} = {}
local function register(name: string, desc: string, fn)
	_cmds[norm(name)] = { name = name, desc = desc, run = fn }
end
local function alias(src: string, other: string)
	_cmds[norm(other)] = _cmds[norm(src)]
end

local function findCollectible(arg: string)
	arg = norm(arg)
	if arg == "" then return nil end
	for id, c in pairs(Cards.ById) do
		if norm(id) == arg then return c end
	end
	for _, c in pairs(Cards.ById) do
		if norm(c.name) == arg then return c end
	end
	return nil
end

local function rarityExists(arg: string)
	arg = norm(arg)
	for r, _ in pairs(Cards.Rarity) do
		if norm(r) == arg then return r end
	end
	return nil
end

local function resolvePlayerArg(meName: string, raw: string?): string
	local v = trim(raw or "")
	if v == "" or norm(v) == "me" then return meName end
	return v
end

local function parseInt(s: string?, def: number?): number?
	local n = tonumber(s or "")
	if n then return math.floor(n) end
	return def
end

register("scan", "Force next scan to a rarity or collectible", function(plr, args)
	local arg = norm(args[1] or "")
	if arg == "" then return "Usage: scan <rarity|id|name>" end
	local rar = rarityExists(arg)
	if rar then
		plr:SetAttribute("ForceNextRarity", rar)
		plr:SetAttribute("ForceNextCard", nil)
		return ("Next scan forced to %s"):format(rar)
	end
	local coll = findCollectible(arg)
	if coll then
		plr:SetAttribute("ForceNextCard", coll.id)
		plr:SetAttribute("ForceNextRarity", nil)
		return ("Next scan forced to %s"):format(coll.name)
	end
	return "Unknown rarity or collectible: " .. arg
end)

register("clearforce", "Clear forced scan", function(plr)
	plr:SetAttribute("ForceNextCard", nil)
	plr:SetAttribute("ForceNextRarity", nil)
	return "Force cleared"
end)

register("givefragment", "Give a fragment to a player", function(plr, args)
	local targetName = resolvePlayerArg(plr.Name, args[1])
	local idOrName   = trim(args[2] or "")
	local fragType   = trim(args[3] or "Beat")
	local rarity     = trim(args[4] or "Common")
	if idOrName == "" then
		return "Usage: givefragment <player|me> <collectibleId> [fragType] [rarity]"
	end
	local coll = findCollectible(idOrName)
	if not coll then return "Invalid collectible" end

	GameCore.Fire("CardService", "AdminGiveFragment", {
		target = targetName,
		collectibleId = coll.id,
		fragmentType = fragType,
		rarity = rarity,
	})
	return ("Giving %s %s fragment (%s) to %s"):format(coll.name, fragType, rarity, targetName)
end)

register("addrolls", "Add scans to a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	local amt    = parseInt(a[2], nil)
	if not amt then return "Usage: addrolls <player|me> <amount>" end
	GameCore.Fire("EconomyService", "AddRolls", { target = target, amount = amt })
	return ("Adding %d scans to %s"):format(amt, target)
end)

register("setrolls", "Set scans for a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	local amt    = parseInt(a[2], nil)
	if not amt then return "Usage: setrolls <player|me> <amount>" end
	GameCore.Fire("EconomyService", "SetRolls", { target = target, amount = amt })
	return ("Setting %s scans = %d"):format(target, amt)
end)

register("giveitem", "Give item(s) to a player", function(plr, a)
	local target   = resolvePlayerArg(plr.Name, a[1])
	local idOrName = trim(a[2] or "")
	local amount   = parseInt(a[3], 1) or 1
	if idOrName == "" then
		return "Usage: giveitem <player|me> <itemId|name> [amount]"
	end

	local itemId = nil
	if ItemsCfg[idOrName] then
		itemId = idOrName
	else
		for k, def in pairs(ItemsCfg) do
			if norm(def.name) == norm(idOrName) then itemId = k; break end
		end
	end
	if not itemId then return "Invalid item" end

	GameCore.Fire("BackpackService", "AdminGiveItem", { target = target, itemId = itemId, amount = amount })
	return ("Giving %dx %s to %s"):format(amount, itemId, target)
end)

register("setlevel", "Set level for a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	local lvl    = parseInt(a[2], nil)
	if not lvl then return "Usage: setlevel <player|me> <level>" end
	GameCore.Fire("EconomyService", "SetLevel", { target = target, level = lvl })
	return ("Setting %s level = %d"):format(target, lvl)
end)

register("setpoints", "Set upgrade points for a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	local pts    = tonumber((a[2] or ""):match("^%s*(.-)%s*$") or "")
	if not pts or pts < 0 then
		return "Usage: setpoints <player|me> <points>=0"
	end
	GameCore.Fire("UpgradeService", "AdminSetPoints", { target = target, points = pts })
	return ("Setting %s upgrade points = %d"):format(target, pts)
end)
alias("setpoints", "setpts")

register("completetrack", "Force-complete a track for a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	local id     = trim(a[2] or "")
	local rarity = trim(a[3] or "Common")
	if id == "" then return "Usage: completetrack <player|me> <collectibleId> [rarity]" end
	GameCore.Fire("CardService", "AdminCompleteTrack", { target = target, id = id, rarity = rarity })
	return ("Completing %s for %s at %s rarity"):format(id, target, rarity)
end)

register("wipeinv", "Wipe inventory for a player", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	if target == "" then return "Usage: wipeinv <player|me>" end
	GameCore.Fire("CardService", "WipeInventory", { target = target })
	return ("Wiping inventory for %s"):format(target)
end)

register("saveprofile", "Force save a player's profile", function(plr, a)
	local target = resolvePlayerArg(plr.Name, a[1])
	GameCore.Fire("DataService", "ForceSave", { target = target })
	return ("Saving profile for %s"):format(target)
end)

register("announce", "Broadcast a message", function(_, a)
	local msg = trim(table.concat(a, " "))
	if msg == "" then return "Usage: announce <message>" end
	GameCore.Fire("AnnounceService", "Broadcast", { message = msg })
	return ("Announce: %s"):format(msg)
end)

register("toggleautoroll", "Toggle Auto Scan (self)", function(plr)
	plr:SetAttribute("ForceToggleAuto", not plr:GetAttribute("ForceToggleAuto"))
	GameCore.Fire("RNGService", "NotifyAutoToggle", { player = plr.Name })
	return ("AutoScan toggled: %s"):format(tostring(plr:GetAttribute("ForceToggleAuto")))
end)

function AdminCommands.Find(prefix: string)
	prefix = norm(prefix)
	local out = {}
	for _, cmd in pairs(_cmds) do
		if string.find(norm(cmd.name), prefix, 1, true) == 1 then
			table.insert(out, cmd)
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

function AdminCommands.Run(plr, text: string)
	local parts = string.split(trim(text or ""), " ")
	local cmd = norm(table.remove(parts, 1))
	if cmd == "" then return "No command" end
	local entry = _cmds[cmd]
	if not entry then return "Unknown command: " .. cmd end
	return entry.run(plr, parts)
end

function AdminCommands.All()
	local out = {}
	for _, cmd in pairs(_cmds) do table.insert(out, cmd) end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

return AdminCommands
"""

if __name__ == "__main__":
    main()
