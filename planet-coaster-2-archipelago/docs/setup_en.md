# Planet Coaster 2 (Manual) Setup Guide

There is no mod and nothing to patch. The Manual Client is a tracker: it tells you
what you may build and records the medals you earn. The restrictions are yours to
keep.

## Setup Instructions

1. Install Planet Coaster 2. Any platform works, since nothing is modified.
2. Install [Archipelago](https://github.com/ArchipelagoMW/Archipelago/releases).
3. Install the apworld by double-clicking on it.
4. Open the Archipelago Launcher and click "Generate Template Options", then find
   `Manual_PlanetCoaster2_bondfired.yaml` in the templates folder.
5. Open the yaml, set `name` to your player name, and pick your `goal`,
   `franchise_milestones` and `include_traps` options.
6. Copy the yaml into the `Players` folder of your Archipelago install.
7. Run `ArchipelagoGenerate` to roll the seed. Manual worlds cannot be generated on
   the Archipelago website, so this has to happen locally on a machine that has the
   apworld installed.
8. Host the resulting file in `output/`, either on the website or with
   `ArchipelagoServer`.

## Connect Instructions

1. Start the Manual Client, which should now be found in the Archipelago launcher.
2. Connect the client to the server and enter your slot name.
3. Run Planet Coaster 2 and start Career mode on a new save.
4. Build only with what the client has sent you.
5. Tick each medal in the client as you earn it.

## Playing

You start with path tools, a Janitor and a Mechanic, one random coaster class and
one random water park piece. Everything else — coaster types, slides, flat rides,
scenery themes, further staff, shops — arrives as items from the multiworld.

The two starting staff exist so a park is always operable: without a Janitor litter
compounds and without a Mechanic broken rides stay broken. Vendors and Lifeguards
are still locked behind the two remaining `Progressive Staff Hire` items.

Career chapters are gated by `Progressive Chapter Pass`. Even once Planet Coaster 2
unlocks the next chapter, you may not start it until the matching pass arrives.

Anything a scenario hands you pre-built is yours to keep and operate. The
restriction is on what *you* place.

## Troubleshooting

**A scenario objective needs a ride I do not have.** Expected. That check stays
locked until the item arrives. Work on another scenario in an unlocked chapter.

**I cannot reach the next chapter.** You need the next `Progressive Chapter Pass`.
Use `!hint Progressive Chapter Pass` in the client to find out who is holding it.

**I have nothing to do.** This is the most common complaint, and it is why
`franchise_milestones` exists — it adds 20 checks earnable in Franchise, Challenge
or Sandbox parks, so there is always something available when the campaign is shut.
Turn it on if you are playing in a room with more than two people.

**The client cannot see my game.** Correct, and it never will. Nothing is detected
or enforced automatically.
