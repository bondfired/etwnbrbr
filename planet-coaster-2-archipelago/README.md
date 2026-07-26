# Planet Coaster 2 — Archipelago (Manual) world

An [Archipelago](https://archipelago.gg) multiworld randomizer for **Planet Coaster 2**,
built on the [Manual](https://github.com/ManualForArchipelago/Manual) template.

No game mod. You restrict what you build to the items the multiworld sends you, and
tick off checks in the Manual client as you earn career medals.

## Build

```sh
./build.sh
```

Produces `dist/manual_planetcoaster2_bondfired.apworld`. The script regenerates the
data, runs the logic checks, assembles the world on top of the upstream Manual
template, and packages it with Archipelago's own "Build APWorlds" component.

Packaging has to go through Archipelago: that is what writes the `version` and
`compatible_version` fields into `archipelago.json`. A hand-rolled zip without them
loads today but is rejected from Archipelago 0.7.0 onward. The build verifies the
manifest before it finishes.

Both the Archipelago and Manual checkouts are cached in `.cache/` and reused. Set
`AP_ROOT` to an existing Archipelago source tree to skip cloning it.

Drop the `.apworld` into `custom_worlds/` in your Archipelago install. Manual worlds
cannot be generated on the official web host — generation has to run locally.

## Test

```sh
./test.sh
```

Builds the apworld and generates a real multiworld for all eight combinations of
`goal` × `franchise_milestones` × `include_traps`, reporting the location count each
produced. Needs the generation dependencies:

```sh
pip install pyyaml schema jellyfish orjson websockets platformdirs \
            colorama bsdiff4 cymem typing_extensions jinja2 certifi pathspec
```

To play-test by hand instead, put a yaml in `Players/` and run `ArchipelagoGenerate`:

```yaml
name: CoasterTycoon
game: Manual_PlanetCoaster2_bondfired
Manual_PlanetCoaster2_bondfired:
  goal: career_complete
  franchise_milestones: false
  include_traps: false
```

Then open **Manual Client** from the Archipelago Launcher and connect.

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

Verified:

- **Generation.** All eight option combinations generate successfully against an
  Archipelago source checkout, producing 74 locations by default and 94 with
  milestones on — matching what the static checker predicts.
- **Progression.** The spoiler playthrough confirms the intended shape: sphere 0 is
  the starting kit, sphere 1 is Prologue-only, and each `Progressive Chapter Pass`
  opens the next chapter region in turn before the goal resolves.
- **Loading.** The packaged apworld registers cleanly with no manifest or version
  warnings.
- **Static checks.** `tools/check_logic.py` asserts that every requires string
  resolves to a real item or category, that every region and location is reachable
  with the full pool, that a goal is always reachable, and that the item pool fits
  the location count. The data also validates against the upstream Manual schemas.

Not verified: the in-client play experience, and whether the difficulty curve is
any fun. Those need actual play.

The 18 scenario names were assembled from community wikis and guides rather than
from the game, and the medal arithmetic checks out (18 × 4 = 72 medals). Worth a
once-over against your own career screen before a serious run.
