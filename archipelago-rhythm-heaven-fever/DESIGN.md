# Archipelago World Design: Rhythm Heaven Fever (Wii)

Status: **design draft, unimplemented**. This document specifies the proposed
`apworld` for Rhythm Heaven Fever (RHF) before any code is written, per
request. It should be reviewed and the open questions in §7 resolved (or
explicitly accepted as risk) before implementation starts.

## 1. Feasibility summary

An Archipelago integration has two independent halves:

1. **The apworld** — pure Python: item/location tables, region graph, access
   rules, options, goal. This is fully specified below and is safe to build
   regardless of what happens with part 2.
2. **The client** — the process that keeps the AP server in sync with the
   actual running game. For a Wii title with no PC version, this normally
   means a `dolphin-memory-engine`-based client that polls/pokes specific RAM
   addresses in a running Dolphin instance (the same approach used by
   existing GameCube/Wii apworlds such as Paper Mario, Metroid Prime, and
   Twilight Princess).

Part 2 requires a reverse-engineered map of RHF's live memory and/or save
file: where clear-rank-per-game, medal count, and unlock flags live. **I have
not found or verified that this map exists publicly.** There's an active
modding community (GBAtemp's "Rhythm Heaven Wii Hacking" thread, GameBanana's
RHF hub) that has reverse-engineered RHF's *asset* formats for cosmetic mods,
but I found no confirmation of documented save/RAM offsets for game-clear
state. That has to be produced (via Dolphin's memory viewer + Cheat Engine
diffing, comparing save states before/after each clear) before a real client
can exist. This is real reverse-engineering work, done against the actual
game, and isn't something I can produce from written sources alone.

Recommended path: build and merge the apworld (§2–§6) now — it's independently
useful, is how AP core review expects a submission to look, and can be
exercised with `Generate.py`/unit tests without any client. Treat the client
as Phase 2, gated on the memory-map research in §7.

## 2. Vanilla structure (source of truth for the region graph)

RHF presents 40 main rhythm games in 10 fixed stages of 4, each stage
followed by a Remix that chains together the preceding games in that stage
(a "review" of everything cleared so far, weighted toward the newest stage).
Perfecting all 40 games unlocks **Endless Remix**, which contains 3 games not
otherwise playable. Confirmed order for stages 1–7 (32 games) via community
wiki cross-reference:

```
Stage 1: Hole in One / Screwbot Factory / See-Saw / Double Date       -> Remix 1
Stage 2: Fork Lifter / Tambourine / Board Meeting / Monkey Watch       -> Remix 2
Stage 3: Working Dough / Built to Scale / Air Rally / Figure Fighter   -> Remix 3
Stage 4: Ringside / Packing Pests / Micro-Row / Samurai Slice          -> Remix 4
Stage 5: Catch of the Day / Flipper-Flop / Exhibition Match / Flock Step -> Remix 5
Stage 6: Launch Party / Donk-Donk / Bossa Nova / Love Rap              -> Remix 6
Stage 7: Tap Troupe / Shrimp Shuffle / Cheer Readers / Karate Man      -> Remix 7
Stage 8-10: (33-40) — NOT YET VERIFIED, see §7 open question 1
Remix 10: full-game finale, all 40 games + tutorial
```

Alongside the main line, medals earned from Superb ranks unlock the
**Medal Corner**: Rhythm Toys, 5 Endless Games, and 4 Extra Games (ports of
original Rhythm Tengoku games). Exact medal thresholds are also unverified
(§7, open question 2).

## 3. Design philosophy: decouple from vanilla linearity

Vanilla RHF is a straight line — game N+1 is inaccessible until game N is
cleared. Mirroring that 1:1 in Archipelago would produce a world with zero
interesting multiworld interleaving (every check is required, in a fixed
order, before the next one opens — the AP server couldn't affect pacing at
all). Instead, follow the pattern other linear-progression apworlds use:

- Turn **"which game is playable"** into an item, not a vanilla unlock. The
  client force-unlocks a game's menu slot when the corresponding
  `Unlock: <Game>` item is received, regardless of vanilla progress.
- Once unlocked, a game can be attempted in **any order** — the player picks
  from whatever's been received, same as picking which dungeon to enter in a
  Zelda apworld.
- Remixes stay logically gated on their 4 constituent games (a remix isn't
  meaningful, and may not be completable, without having played what it
  remixes), but are *also* separately itemized so they aren't forced
  immediately upon finishing a stage.

This turns a completely linear 5-hour campaign into a real multiworld-shaped
game with meaningful item placement, at the cost of needing the client to be
able to force-unlock arbitrary menu entries out of vanilla order (see §7,
open question 3 — this needs confirming against how the unlock flags are
actually stored, e.g. a bitfield vs. a "highest cleared index" counter).

## 4. Items

| Item | Qty | Classification | Effect |
|---|---|---|---|
| `Unlock: <Game>` (one per main game) | 40 | Progression | Client force-unlocks that game's menu entry |
| `Unlock: Remix <N>` | 10 | Progression | Client force-unlocks that remix; logically requires the 4 `Unlock: <Game>` items for that stage |
| `Medal Corner Access` | 1 | Progression | Client unlocks the Medal Corner menu itself |
| `Rhythm Toy: <Name>` | ~5 | Useful | Cosmetic/bonus toy unlock |
| `Extra Game: <Name>` | 4 | Useful | Unlocks a Rhythm Tengoku port game as a bonus location-bearing item |
| `Endless Game: <Name>` | 5 | Useful | Unlocks an endless-mode variant |
| `Medal` (filler) | fills remaining pool | Filler | No client effect; pure pool padding, OR drives a `medal_count` option that gates Medal Corner content (see §7 open question 2) |
| `Perfect Unlock: <Game>` | 40, optional via option | Progression (hard logic only) | Only included if "Perfect Campaign" goal is enabled; required to flag that game's Perfect-rank check as in-logic |

Total base pool (excluding filler): 40 + 10 + 1 + 5 + 4 + 5 = 65 items before
filler padding to match location count.

## 5. Locations

| Location | Qty | Check condition |
|---|---|---|
| `<Game> - Clear` | 40 | Reach at least OK rank |
| `<Game> - Superb` | 40 | Optional bonus location tier (option: `include_superb_checks`), reach Superb rank |
| `Remix <N> - Clear` | 10 | Clear the remix |
| `Extra Game <N> - Clear` | 4 | Clear the bonus game |
| `Endless Game <N> - High Score` | 5 | Reach a defined score/combo threshold (needs game-specific tuning) |
| `Perfect Campaign` (goal location, optional) | 1 | All 40 games at Perfect rank |
| `Endless Remix - Clear` (alt goal) | 1 | Clear Endless Remix |

Base location count: 40 + 10 + 4 + 5 = 59 (+40 optional Superb, +1-2 goal).

## 6. Regions, rules, options, goal

- **Regions**: essentially flat — `Menu` region containing all locations,
  since access is item-gated rather than region-gated (no overworld to
  traverse). Each location's access rule is simply "has `Unlock: <Game>`
  received"; each Remix location additionally requires the 4 stage items.
- **Options**:
  - `goal`: `remix_10` (default, clear the finale) | `perfect_campaign`
    (clear Endless Remix, much longer)
  - `include_superb_checks`: bool, adds the 40 harder bonus locations
  - `include_extra_endless_games`: bool, adds Medal Corner content to the
    pool (requires resolving medal-threshold logic, §7)
  - `remix_logic`: `vanilla_stage` (remix requires only its own 4 games) |
    `cumulative` (remix N requires all games up through stage N, matching how
    later remixes musically reference earlier games) — affects difficulty
    curve of generated seeds, not just fairness
- **Goal**: victory triggers when the selected goal location's event fires;
  standard AP `finished_game` semantics.

## 7. Open questions before implementation (need answers, not assumptions)

1. **Full game list for stages 8–10** (games 33–40) — the searches I ran
   returned inconsistent/garbled results for this stretch; needs a clean
   source (in-game menu, or a wiki page fetched directly rather than via
   search snippets) before the item/location tables are finalized.
2. **Medal thresholds** — how many medals unlock each Extra/Endless/Toy slot
   in vanilla, so `include_extra_endless_games` logic is correct.
3. **Unlock flag storage** — whether menu-unlock state is a per-game bitfield
   (any subset force-unlockable independently, which is what §3 assumes) or
   a "highest index cleared" counter (which would make out-of-order
   force-unlocking impossible without a bigger client-side patch, and would
   push the design back toward vanilla's linear order — undermining §3).
   **This is the single fact that most determines whether the "any order"
   design in §3 is achievable or whether the world has to be linear.**
4. **Client feasibility** — confirm whether `dolphin-memory-engine` can
   reliably read/write RHF's save-related RAM live during gameplay (vs. only
   being readable from the save file on disk between sessions), since that
   changes whether checks can be sent in real time or only at save points.

## 8. Suggested next steps

1. Resolve open question 3 first — it's the fork in the road for the whole
   design. Needs someone with Dolphin + Cheat Engine/memory-search access to
   RHF running live.
2. If bitfield-style unlocks are confirmed: implement the apworld exactly as
   specified above (items/locations/rules/options), verify it generates and
   passes `test/general` in the Archipelago core repo using a stub client.
3. If not: fall back to a linear "keys open the next stage" design (still a
   valid, if less interesting, apworld) and revise §3–§6 accordingly.
4. Only after the apworld is generating valid seeds, start the memory-map
   research needed for the real Dolphin client.
