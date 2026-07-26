#!/usr/bin/env python3
"""Sanity check the Planet Coaster 2 Manual world before packaging it.

Verifies the things schema validation cannot:
  1. every item/category named in a requires string actually exists
  2. with the full item pool collected, every location and both goals are
     reachable through the region graph
  3. progression items are placeable, i.e. the pool fits in the location count
  4. the same holds for each combination of the yaml content toggles

Exits non-zero on any failure.
"""

import itertools
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, os.pardir, "data")

TOKEN = re.compile(r"\|(@?)([^|:]+?)(?::([^|]+))?\|")


def load(name):
    with open(os.path.join(DATA, name), encoding="utf-8") as handle:
        return json.load(handle)


def parse(requirement):
    """Return [(is_category, name, count)] for a requires string."""
    out = []
    for is_category, name, count in TOKEN.findall(requirement or ""):
        out.append((bool(is_category), name.strip(), int(count) if count else 1))
    return out


def main():
    game = load("game.json")
    items = load("items.json")["data"]
    locations = load("locations.json")["data"]
    # Both files carry a "$schema" string key alongside the real entries.
    regions = {k: v for k, v in load("regions.json").items() if isinstance(v, dict)}
    categories = load("categories.json")

    failures = []

    # Which categories are gated behind a yaml option, and on what.
    gated = {
        name: body["yaml_option"]
        for name, body in categories.items()
        if isinstance(body, dict) and "yaml_option" in body
    }
    toggles = sorted({opt.lstrip("!") for opts in gated.values() for opt in opts})

    def category_active(name, settings):
        for opt in gated.get(name, []):
            want = not opt.startswith("!")
            if settings.get(opt.lstrip("!"), False) != want:
                return False
        return True

    for settings in (
        dict(zip(toggles, combo))
        for combo in itertools.product([False, True], repeat=len(toggles))
    ):
        label = ", ".join(f"{k}={v}" for k, v in settings.items()) or "defaults"

        # ---- build the active pool -------------------------------------
        pool = {}
        item_categories = {}
        copies = 0
        for item in items:
            cats = item.get("category", [])
            if not all(category_active(c, settings) for c in cats):
                continue
            count = item.get("count", 1)
            pool[item["name"]] = count
            copies += count
            item_categories[item["name"]] = cats

        counts = dict(pool)
        for name, cats in item_categories.items():
            for cat in cats:
                counts[cat] = counts.get(cat, 0) + pool[name]

        active_locations = [
            loc
            for loc in locations
            if all(category_active(c, settings) for c in loc.get("category", []))
        ]

        def satisfied(requirement):
            for is_category, name, count in parse(requirement):
                if counts.get(name, 0) < count:
                    return False
            return True

        # ---- 1. every referenced name exists ---------------------------
        known = set(pool) | {c for cats in item_categories.values() for c in cats}
        for source, requirement in [
            (f"region {n}", b.get("requires")) for n, b in regions.items()
        ] + [(f"location {loc['name']}", loc.get("requires")) for loc in active_locations]:
            for _, name, _ in parse(requirement):
                if name not in known:
                    failures.append(f"[{label}] {source} references unknown '{name}'")

        # ---- 2. reachability with the full pool ------------------------
        reachable = set()
        frontier = [n for n, b in regions.items() if b.get("starting")]
        if not frontier:
            failures.append(f"[{label}] no starting region")
        while frontier:
            region = frontier.pop()
            if region in reachable:
                continue
            if not satisfied(regions[region].get("requires")):
                continue
            reachable.add(region)
            for nxt in regions[region].get("connects_to", []):
                if nxt not in reachable:
                    frontier.append(nxt)

        for region in regions:
            if region not in reachable:
                failures.append(f"[{label}] region '{region}' unreachable with full pool")

        goals_ok = 0
        for loc in active_locations:
            region = loc.get("region")
            if region and region not in reachable:
                failures.append(f"[{label}] location '{loc['name']}' in unreachable region")
                continue
            if not satisfied(loc.get("requires")):
                failures.append(f"[{label}] location '{loc['name']}' unsatisfiable: {loc['requires']}")
                continue
            if loc.get("victory"):
                goals_ok += 1

        if goals_ok == 0:
            failures.append(f"[{label}] no reachable victory location")

        # ---- 3. the pool has somewhere to go ---------------------------
        starting = sum(
            len(entry.get("items", [])) if "random" not in entry else entry["random"]
            for entry in game.get("starting_items", [])
        )
        placeable = copies - starting
        if placeable > len(active_locations):
            failures.append(
                f"[{label}] {placeable} items to place but only {len(active_locations)} locations"
            )

        print(
            f"{label:>55}: {len(active_locations):>3} locations, "
            f"{copies:>3} item copies, {len(reachable)}/{len(regions)} regions, "
            f"{goals_ok} goal(s), {len(active_locations) - placeable} filler slots"
        )

    print()
    if failures:
        print(f"FAILED ({len(failures)} problem(s)):")
        for failure in failures:
            print("  -", failure)
        return 1
    print("All checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
