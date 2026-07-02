# Babble Blox — Roadmap

## Concept Summary

Babble Blox is a Roblox party game built around the sentence-builder /
word-guessing genre popularized by games like Jackbox. One player describes a
secret prompt using a curated bank of tappable words while everyone else
guesses in real time. It's designed mobile-first for Roblox's younger,
phone-and-tablet-heavy audience: big touch targets, no typing required to
play, and rounds fast enough to hold that attention span.

## Design Constraints That Differentiate From Jackbox

Babble Blox is not a Roblox reskin of Jackbox — the platform forces three
structural differences that shape every phase below, not just the UI:

- **Per-device play, no shared TV screen.** Every player — describer and
  guessers alike — plays entirely on their own device. There's no
  "shared-screen + phone-as-controller" split. Each client renders its own
  role-specific view (the describer sees the prompt and word bank; guessers
  see their podium and guess input), all driven by server-replicated state.
- **Mid-game joinability.** Roblox players hop in and out of servers
  constantly. Sessions must accept a joining player at any point — mid-round,
  mid-scoring, whenever — and slot them in without stalling the round or
  breaking describer rotation for everyone else.
- **Short, 90-second-max rounds.** Rounds are capped at 90 seconds, shorter
  than Jackbox's typical pacing, matched to the attention span of Roblox's
  audience.

## Competitive Moat

There is no strong word-guessing party game on Roblox today. Games like
*Guess the Emoji* post huge numbers with shallow, single-mechanic depth —
proof the audience and demand exist, but not that the niche is served. The
opportunity is to pair real gameplay depth (turn-based describer/guesser
roles, prompt variety, scoring) with Roblox-native production values
(avatars, a game-show stage, cosmetic progression) that shallow competitors
don't attempt.

## Phase 1: Core Build

- Build in Roblox Studio with Luau: lobby system, 3–8 player rounds,
  matchmaking into public servers plus private servers for friend groups.
- Recreate the sentence-builder as a tap-friendly UI (Roblox skews
  mobile/young, so big buttons and simple word lists).
- Text filtering is critical — all guesses run through Roblox's TextService
  filter, so lean on the word-bank system since free typing gets censored
  unpredictably.

**Architecture guidance:**

- **Session architecture — single place, no teleport hopping.** Use one
  place for the whole experience rather than a lobby place that teleports
  players into a separate game place. The place's own running servers *are*
  the lobby list — public matchmaking is standard Roblox server-join
  behavior, and friend groups use Roblox's native VIP/private server
  feature. This avoids `TeleportService` loading screens between lobby and
  round, which would otherwise undercut the "hop in and out" experience the
  audience expects.
- **Round state machine.** A per-server `GameManager` `ModuleScript`
  singleton drives explicit phases: `WaitingForPlayers → RoundIntro →
  Describing (90s) → Reveal → Scoring → NextRound / GameEnd`. State is
  server-authoritative; clients only render what the server tells them to.
- **Mid-game join handling.** `PlayerAdded` always succeeds — a joining
  player enters a queue that slots them into the next round rather than
  being rejected or redirected. `PlayerRemoving` immediately advances the
  describer-rotation queue so a disconnect never stalls the round for
  everyone else. On join, fire a `GameStateSync` `RemoteEvent` so the new
  client immediately renders the current phase, timer, and scoreboard
  instead of starting blank.
- **90-second timer.** The server holds the authoritative countdown (e.g.
  an `os.clock()`-based deadline) and replicates remaining time to clients
  each tick. Clients never own the clock — this avoids drift and prevents
  timer manipulation.
- **Word-bank UI as the primary input.** A tap-friendly grid of
  pre-approved words/phrases is the main way players play, with large touch
  targets for mobile. This is the primary defense against Roblox's
  unpredictable `TextService` filtering — not a fallback bolted on after the
  fact.
- **Text filtering for any free-text entry.** If free typing is offered at
  all, it must go through `TextService:FilterStringAsync`, scoped
  per-recipient as Roblox requires (filtering can differ by viewer's account
  settings), with a timeout fallback that degrades to word-bank-only if
  filtering doesn't resolve within the round's time budget.
- **Progression data sketch.** Decide the shape now to avoid rework in
  Phase 3: a per-`UserId` DataStore profile holding `xp`, `level`, `streak`,
  `lastPlayedDate`, `unlockedCosmetics`, `equippedCosmetics`, and
  `gamesPlayed`. Use a session-locking pattern (e.g. ProfileService-style) so
  profiles survive the frequent join/leave churn without data loss.

## Phase 2: Roblox-ify It

- Give players avatars in a game-show set instead of a flat UI — the
  describer stands on stage, guessers at podiums.
- Emotes and physical reactions when someone guesses right (confetti
  cannon, trapdoor for wrong answers).
- Kid-friendly prompt packs by default: Roblox games, memes, animals, food —
  the audience is younger than Jackbox's.

## Phase 3: Progression & Retention

- XP and levels, daily prompt packs, win streaks — Roblox players expect
  persistent progression, unlike Jackbox's pick-up-and-play model.
- Cosmetic unlocks: podium skins, victory animations, describer hats.
- Leaderboards (global and friends).

## Phase 4: Monetization

- Game passes: VIP (2x XP, exclusive cosmetics), private server perks.
- Robux shop for cosmetics and premium prompt packs — never pay-to-win,
  since guessing skill should stay pure.
- Free to play, always — that's non-negotiable on Roblox.

## Phase 5: Live Ops (Ongoing)

- Roblox games live or die on updates: weekly prompt drops, seasonal events
  (Horror pack, holiday set).
- Community prompt submissions with heavy moderation (Roblox's content
  rules are strict).
- Collabs with popular Roblox games for crossover prompt packs.
