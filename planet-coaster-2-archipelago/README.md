# Planet Coaster 2 — Archipelago (Manual) world

An [Archipelago](https://archipelago.gg) multiworld randomizer for **Planet Coaster 2**,
built on the [Manual](https://github.com/ManualForArchipelago/Manual) template.

No game mod. You restrict what you build to the items the multiworld sends you, and
tick off checks in the Manual client as you earn career medals.

## Build

```sh
./build.sh
```

Produces `dist/manual_PlanetCoaster2_bondfired.apworld`. The script regenerates the
data, runs the logic checks, fetches the upstream Manual template and zips the
result. Requires `python3`, `git` and `zip`.

Drop the `.apworld` into `custom_worlds/` in your Archipelago install. Manual worlds
cannot be generated on the official web host — generation has to run locally.

## Layout

| Path | What it is |
|---|---|
| `data/game.json` | World identity, starting kit, goal handling |
| `data/regions.json` | The five campaign chapters plus the optional franchise region |
| `data/categories.json` | Category flags — which are hidden, which are yaml-gated |
| `data/options.json` | The `goal`, `franchise_milestones` and `include_traps` options |
| `data/items.json` | **Generated** by `tools/build_data.py` |
| `data/locations.json` | **Generated** by `tools/build_data.py` |
| `tools/build_data.py` | Career tables and item pool — edit here, not in the JSON |
| `tools/check_logic.py` | Reachability and pool-size checks |
| `docs/` | Player-facing setup and world docs, bundled into the apworld |

## Design

**Locations (74 default, 94 with milestones).** The 72 career medals — bronze,
silver, gold and platinum across the 18 scenarios of the Prologue and Chapters 1–4 —
plus two goal locations. The `franchise_milestones` option adds 20 checks earnable
outside career mode.

**Items (68 copies default).** Coaster classes, water park slide types, flat rides,
scenery themes and park tools. Receiving one grants permission to build that thing.

**Progression.** Two axes:

- `Progressive Chapter Pass` ×4 gates the chapter regions in order, so the campaign
  cannot be rushed ahead of the multiworld.
- Medal tiers require escalating counts of `@Rides`, `@Park Operations` and — on the
  six water park scenarios — `@Water Park`. Chapter 4 platinums sit at the deep end
  of the pool, so late items stay meaningful.

**Goals.** `career_complete` (gold on Coaster Chasm) or `career_mastery` (platinum
everywhere). The unselected one remains as a normal check.

## Verification status

`tools/check_logic.py` runs on every build and covers all four combinations of the
content toggles, asserting that every requires string resolves to a real item or
category, that every region and location is reachable with the full pool, that a
goal is always reachable, and that the item pool fits the location count.

The data files also validate cleanly against the upstream Manual JSON schemas.

Not yet verified: a real generation run against an Archipelago install, and the
in-client experience. Both need an AP host, which this world has not been through
yet.

The 18 scenario names were assembled from community wikis and guides rather than
from the game, and the medal arithmetic checks out (18 × 4 = 72 medals). Worth a
once-over against your own career screen before a serious run.
