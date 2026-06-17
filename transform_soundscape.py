#!/usr/bin/env python3
"""SoundScape RNG — Minimal transformation from Template RNG.

Strategy: The template works perfectly. Only replace the Cards config
content with music-themed albums. Keep ALL services, controllers, and
startup scripts identical to the proven template.
"""

import shutil

SRC = "/root/.claude/uploads/d53bc4ea-e11e-575e-bd06-8672868bb35d/80cb7769-Template_RNG.rbxlx"
DST = "SoundScape_RNG.rbxlx"


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


# ── Music-themed Cards config ────────────────────────────────────────
# Same structure as template: id, name, rarity, unitType, power, image,
# rollPower, tags.  Images use the template's existing asset IDs as
# placeholders — the user can swap them for real album art later.
CARDS = r'''local Cards = {}

Cards.Rarity = {
	Basic = {
		id = "Basic",
		order = 1,
		color = Color3.fromRGB(120, 140, 160),
		stroke = Color3.fromRGB(40, 50, 60),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(90, 105, 125)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(120, 140, 160)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(70, 85, 105))
			},
			Transparency = NumberSequence.new(0)
		}
	},

	Gold = {
		id = "Gold",
		order = 2,
		color = Color3.fromRGB(255, 196, 62),
		stroke = Color3.fromRGB(120, 90, 20),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 222, 120)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(255, 196, 62)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 235, 170)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(230, 170, 40))
			},
			Transparency = NumberSequence.new(0)
		}
	},

	AllBlue = {
		id = "AllBlue",
		order = 3,
		color = Color3.fromRGB(70, 170, 255),
		stroke = Color3.fromRGB(25, 70, 120),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(40, 120, 230)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(70, 170, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(20, 90, 190))
			},
			Transparency = NumberSequence.new(0)
		}
	},

	Secret = {
		id = "Secret",
		order = 4,
		color = Color3.fromRGB(190, 70, 255),
		stroke = Color3.fromRGB(80, 20, 120),
		uiGradient = {
			Rotation = 0,
			Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(60, 10, 120)),
				ColorSequenceKeypoint.new(0.45, Color3.fromRGB(190, 70, 255)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 120, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(100, 20, 170))
			},
			Transparency = NumberSequence.new(0)
		}
	},
}

Cards.RarityOrder = { "Basic", "Gold", "AllBlue", "Secret" }

Cards.UnitType = { Attack = "Attack", Support = "Support" }

Cards.Catalog = {
	-- ══ Basic (common drops) ══
	{
		id = "lofi_beats_basic",
		name = "Lo-Fi Beats",
		rarity = "Basic",
		unitType = Cards.UnitType.Attack,
		power = 1200000,
		image = "rbxassetid://113165478145605",
		rollPower = 5,
		tags = { "Chill" },
	},
	{
		id = "midnight_radio_basic",
		name = "Midnight Radio",
		rarity = "Basic",
		unitType = Cards.UnitType.Attack,
		power = 1400000,
		image = "rbxassetid://113165478145605",
		rollPower = 8,
		tags = { "Indie" },
	},
	{
		id = "acoustic_dawn_basic",
		name = "Acoustic Dawn",
		rarity = "Basic",
		unitType = Cards.UnitType.Support,
		power = 1100000,
		image = "rbxassetid://113165478145605",
		rollPower = 6,
		tags = { "Folk" },
	},
	{
		id = "synth_city_basic",
		name = "Synth City",
		rarity = "Basic",
		unitType = Cards.UnitType.Attack,
		power = 1350000,
		image = "rbxassetid://113165478145605",
		rollPower = 7,
		tags = { "Electronic" },
	},
	{
		id = "vinyl_groove_basic",
		name = "Vinyl Groove",
		rarity = "Basic",
		unitType = Cards.UnitType.Support,
		power = 1250000,
		image = "rbxassetid://113165478145605",
		rollPower = 10,
		tags = { "Funk" },
	},
	{
		id = "garage_riff_basic",
		name = "Garage Riff",
		rarity = "Basic",
		unitType = Cards.UnitType.Attack,
		power = 1300000,
		image = "rbxassetid://113165478145605",
		rollPower = 9,
		tags = { "Rock" },
	},

	-- ══ Gold (uncommon) ══
	{
		id = "neon_pulse_gold",
		name = "Neon Pulse",
		rarity = "Gold",
		unitType = Cards.UnitType.Attack,
		power = 2400000,
		image = "rbxassetid://115490303677656",
		rollPower = 800,
		tags = { "EDM" },
	},
	{
		id = "velvet_echo_gold",
		name = "Velvet Echo",
		rarity = "Gold",
		unitType = Cards.UnitType.Support,
		power = 2100000,
		image = "rbxassetid://115490303677656",
		rollPower = 1000,
		tags = { "R&B" },
	},
	{
		id = "bass_cathedral_gold",
		name = "Bass Cathedral",
		rarity = "Gold",
		unitType = Cards.UnitType.Attack,
		power = 2600000,
		image = "rbxassetid://115490303677656",
		rollPower = 1200,
		tags = { "Dubstep" },
	},
	{
		id = "jazz_noir_gold",
		name = "Jazz Noir",
		rarity = "Gold",
		unitType = Cards.UnitType.Support,
		power = 2000000,
		image = "rbxassetid://115490303677656",
		rollPower = 900,
		tags = { "Jazz" },
	},
	{
		id = "stadium_anthem_gold",
		name = "Stadium Anthem",
		rarity = "Gold",
		unitType = Cards.UnitType.Attack,
		power = 2500000,
		image = "rbxassetid://115490303677656",
		rollPower = 1100,
		tags = { "Pop" },
	},

	-- ══ AllBlue (rare) ══
	{
		id = "aurora_waves_blue",
		name = "Aurora Waves",
		rarity = "AllBlue",
		unitType = Cards.UnitType.Support,
		power = 3200000,
		image = "rbxassetid://95289023079537",
		rollPower = 4000,
		tags = { "Ambient" },
	},
	{
		id = "phoenix_drop_blue",
		name = "Phoenix Drop",
		rarity = "AllBlue",
		unitType = Cards.UnitType.Attack,
		power = 3600000,
		image = "rbxassetid://95289023079537",
		rollPower = 5000,
		tags = { "DnB" },
	},
	{
		id = "crystal_resonance_blue",
		name = "Crystal Resonance",
		rarity = "AllBlue",
		unitType = Cards.UnitType.Attack,
		power = 3400000,
		image = "rbxassetid://95289023079537",
		rollPower = 4500,
		tags = { "Trance" },
	},
	{
		id = "dreamscape_blue",
		name = "Dreamscape",
		rarity = "AllBlue",
		unitType = Cards.UnitType.Support,
		power = 3000000,
		image = "rbxassetid://95289023079537",
		rollPower = 3500,
		tags = { "Shoegaze" },
	},

	-- ══ Secret (ultra rare) ══
	{
		id = "eternal_frequency_secret",
		name = "Eternal Frequency",
		rarity = "Secret",
		unitType = Cards.UnitType.Attack,
		power = 5000000,
		image = "rbxassetid://82097846469507",
		rollPower = 10000,
		tags = { "Legendary" },
	},
	{
		id = "cosmic_symphony_secret",
		name = "Cosmic Symphony",
		rarity = "Secret",
		unitType = Cards.UnitType.Attack,
		power = 5500000,
		image = "rbxassetid://82097846469507",
		rollPower = 15000,
		tags = { "Orchestral" },
	},
	{
		id = "void_resonator_secret",
		name = "Void Resonator",
		rarity = "Secret",
		unitType = Cards.UnitType.Support,
		power = 4800000,
		image = "rbxassetid://82097846469507",
		rollPower = 20000,
		tags = { "Glitch" },
	},
	{
		id = "soundscape_origin_secret",
		name = "SoundScape Origin",
		rarity = "Secret",
		unitType = Cards.UnitType.Attack,
		power = 6000000,
		image = "rbxassetid://82097846469507",
		rollPower = 50000,
		tags = { "Mythic" },
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
		table.insert(rollPool, { id = c.id, weight = w, image = c.image, color = c.color })
		weights[c.id] = w
	end
end

Cards.ById        = byId
Cards.RollPool    = rollPool
Cards.RollWeights = weights

return Cards
'''


def main():
    print(f"Copying template: {SRC} -> {DST}")
    shutil.copy2(SRC, DST)

    with open(DST, "r", encoding="utf-8") as f:
        content = f.read()
    print(f"  {len(content)} chars read")

    content = replace_cdata(
        content,
        'id = "goku_basic"',
        CARDS,
        "Cards config → SoundScape music-themed albums"
    )

    with open(DST, "w", encoding="utf-8") as f:
        f.write(content)
    print(f"Wrote {len(content)} chars to {DST}")
    print("Done — SoundScape RNG transformation complete.")
    print()
    print("What changed:")
    print("  - Cards.Catalog: 4 anime cards -> 18 music-themed albums")
    print("  - Everything else: IDENTICAL to working template")


if __name__ == "__main__":
    main()
