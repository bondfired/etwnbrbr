# Babble Blox — Phase 1 Prototype

Rojo project for the Babble Blox Roblox game. See `../BABBLE_BLOX_ROADMAP.md`
for the full product roadmap; this folder is the first playable slice of
Phase 1 (Core Build).

## What's implemented

- Single-place lobby/round architecture — no teleporting between a lobby
  place and a game place, so players can join mid-round with no loading screen.
- Server-authoritative round state machine (`GameManager.server.lua`):
  `WaitingForPlayers → RoundIntro → Describing (90s) → Reveal → Scoring → next round`.
- Mid-game join handling: players who join mid-round queue up and are folded
  into the next round; a disconnecting describer ends the round early instead
  of stalling everyone else.
- Tap-friendly describer UI: a fixed pool of clue words, tapped in sequence
  to build a live clue sentence guessers see appear in real time.
- Multiple-choice guessing: guessers pick from four pre-approved options per
  prompt. Because every string a client can send is from a fixed word/answer
  list, there's nothing that needs to go through `TextService` filtering yet.
- A minimal `PlayerDataManager` DataStore module tracking xp/level/streak/
  cosmetics per player, with XP awarded to the describer and correct guessers
  at round end.

## Not yet built

- Free-text guessing with `TextService:FilterStringAsync` (mentioned in the
  roadmap as a possible fallback path — deliberately left out of this first
  pass since the multiple-choice path is filter-safe by construction).
- Everything in Phases 2–5: avatar game-show staging, cosmetics, monetization,
  live ops.
- Production-grade data persistence (swap `PlayerDataManager` for
  ProfileService/ProfileStore before shipping — see the comment at the top of
  that file).

## Setup (Rojo)

1. Install the **Rojo** Studio plugin: in Roblox Studio, open the Toolbox,
   search "Rojo", and install the official plugin by Rojo's authors.
2. Install the **Rojo CLI**. Easiest path is via
   [Aftman](https://github.com/LPGhatguy/aftman): `aftman install rojo-rbx/rojo`.
   (Any recent Rojo CLI release works — see https://github.com/rojo-rbx/rojo/releases
   if you'd rather grab a standalone binary.)
3. From this folder, run:
   ```
   rojo serve
   ```
4. In Roblox Studio, open (or create) a place, open the Rojo plugin panel,
   and click **Connect** (default port `34872`).
5. Rojo will sync `src/` and the `Remotes` folder into the place. Save the
   place file locally if you want a persistent `.rbxl` (git-ignored — don't
   commit built place files).

## Playtesting

`MIN_PLAYERS` is 3 (see `GameConfig.lua`), so Play Solo alone won't start a
round. Use Studio's **Test** tab → **Local Server** with 3+ players, or
publish to a private/unlisted place and playtest with friends in-experience.

## File map

```
default.project.json                                  Rojo project definition (also declares the Remotes folder)
src/ReplicatedStorage/GameConfig.lua                   Shared timing/scoring constants
src/ReplicatedStorage/WordBank.lua                     Clue-word pool + prompt packs
src/ServerScriptService/GameManager.server.lua         Round state machine, matchmaking, scoring
src/ServerScriptService/PlayerDataManager.lua          DataStore-backed player profiles
src/StarterPlayer/StarterPlayerScripts/ClientMain.client.lua   Per-device describer/guesser UI
```
