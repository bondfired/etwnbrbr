#!/usr/bin/env python3
"""Generate items.json and locations.json for the Planet Coaster 2 Manual world.

The career tables below are the source of truth. Run this after editing them:

    python3 tools/build_data.py

Output is written to data/items.json and data/locations.json.
"""

import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, os.pardir, "data")

SCHEMA = "https://github.com/ManualForArchipelago/Manual/raw/main/schemas/Manual"

# --------------------------------------------------------------------------
# Career structure: (region, chapter display name, [scenario names])
#
# Each scenario awards four medals (bronze, silver, gold, platinum), giving
# 18 scenarios x 4 = 72 career locations.
# --------------------------------------------------------------------------

CAREER = [
    ("First Drop", ["Keys to the Coaster", "In the Swim of Things"]),
    (
        "Rolling With It",
        ["Parks and Restoration", "A Shore Thing", "Just the Thicket", "Summit Awesome"],
    ),
    (
        "Wheel-y Good Times",
        ["Building the Bifrost", "Farmland Fiasco", "The Brothers Swimm"],
    ),
    (
        "Twisting Tracks",
        [
            "Sky's The Limit",
            "Paradise Lost",
            "Double Trouble",
            "The Garden of Edith",
            "Fabled Fjord",
        ],
    ),
    (
        "Final Plunge",
        ["Lazy River Styx", "Labyrinth Secrets", "Thrills'n'Spills", "Coaster Chasm"],
    ),
]

# Scenarios built around the water park systems. Their silver/gold/platinum
# medals additionally require water park items, so the aquatic half of the
# item pool stays logically relevant.
AQUATIC_SCENARIOS = {
    "In the Swim of Things",
    "A Shore Thing",
    "The Brothers Swimm",
    "Paradise Lost",
    "Lazy River Styx",
    "Thrills'n'Spills",
}

MEDALS = ["Bronze", "Silver", "Gold", "Platinum"]

# Per chapter index, the number of items each medal tier demands. Difficulty
# ramps across the campaign so later chapters consume the deeper item pool.
#                    bronze  silver  gold  platinum
RIDE_CURVE = [
    (0, 1, 2, 3),  # First Drop
    (1, 2, 3, 5),  # Rolling With It
    (2, 4, 6, 8),  # Wheel-y Good Times
    (3, 6, 9, 12),  # Twisting Tracks
    (5, 8, 12, 16),  # Final Plunge
]
OPS_CURVE = [
    (0, 0, 1, 1),
    (0, 1, 1, 2),
    (1, 1, 2, 3),
    (1, 2, 3, 5),
    (2, 3, 5, 7),
]
WATER_CURVE = [
    (0, 1, 1, 2),
    (0, 1, 2, 3),
    (1, 2, 3, 4),
    (1, 3, 4, 6),
    (2, 4, 6, 8),
]

# --------------------------------------------------------------------------
# Item pool
# --------------------------------------------------------------------------

COASTERS = [
    "Chainlift Coaster",
    "Wooden Coaster",
    "Hybrid Coaster",
    "Steel Looping Coaster",
    "Launched Coaster",
    "Inverted Coaster",
    "Suspended Coaster",
    "Wing Coaster",
    "Dive Coaster",
    "Spinning Coaster",
    "Mine Train Coaster",
    "Bobsled Coaster",
    "Water Coaster",
    "Tilt Coaster",
    "Multi-Dimension Coaster",
    "SuperSplash Coaster",
]

WATER_PARK = [
    "Body Slide",
    "Inner Tube Slide",
    "Raft Slide",
    "Mat Slide",
    "Capsule Slide",
    "Plughole Slide",
    "Sphere Slide",
    "Boomerang Slide",
    "Lazy River",
    "Wave Pool",
    "Pool Builder",
    "Flume Builder",
]

FLAT_RIDES = [
    "Carousel",
    "Ferris Wheel",
    "Drop Tower",
    "Pendulum Ride",
    "Teacups",
    "Swing Ride",
    "Bumper Cars",
    "Top Spin",
    "Enterprise",
    "Gyro Tower",
    "Log Flume",
    "River Rapids",
    "Transport Ride",
]

PARK_OPS = [
    "Advanced Path Tools",
    "Terrain Sculpting",
    "Queue Customisation",
    "Shops and Food Stalls",
    "Marketing Campaigns",
    "Lighting and Special Effects",
    "Ride Blueprint Library",
    "Scenery Theme - Viking",
    "Scenery Theme - Mythology",
    "Scenery Theme - Aquatic",
    "Scenery Theme - Resort",
    "Scenery Theme - Classic",
    "Scenery Theme - Adventure",
]

TRAPS = [
    "Ride Breakdown",
    "Guest Sickness Wave",
    "Sudden Downpour",
    "Litter Explosion",
    "Power Outage",
]

# Optional non-career checks, enabled with the franchise_milestones yaml option.
MILESTONES = [
    ("Reach a 3 Star Park Rating", 3, 1, 0),
    ("Reach a 4 Star Park Rating", 6, 2, 1),
    ("Reach a 5 Star Park Rating", 10, 4, 2),
    ("Host 500 Guests at Once", 2, 1, 0),
    ("Host 1000 Guests at Once", 5, 2, 1),
    ("Host 2500 Guests at Once", 9, 3, 2),
    ("Host 5000 Guests at Once", 14, 5, 4),
    ("Open 5 Rides in One Park", 5, 0, 0),
    ("Open 15 Rides in One Park", 12, 1, 2),
    ("Open 25 Rides in One Park", 18, 3, 4),
    ("Build a Coaster Rated 6 Excitement", 3, 0, 0),
    ("Build a Coaster Rated 8 Excitement", 8, 2, 0),
    ("Build a Coaster Rated 10 Excitement", 14, 4, 0),
    ("Reach 100,000 Park Value", 4, 1, 0),
    ("Reach 500,000 Park Value", 9, 3, 2),
    ("Reach 1,000,000 Park Value", 15, 5, 4),
    ("Complete a Franchise Season", 7, 2, 2),
    ("Win a Franchise Community Challenge", 11, 3, 3),
    ("Publish a Blueprint to the Frontier Workshop", 6, 2, 1),
    ("Run a Park with Zero Litter for a Full Year", 8, 4, 2),
]


def requires(rides: int, ops: int, water: int) -> str:
    """Build a Manual requires string from category counts."""
    parts = []
    if rides:
        parts.append(f"|@Rides:{rides}|")
    if ops:
        parts.append(f"|@Park Operations:{ops}|")
    if water:
        parts.append(f"|@Water Park:{water}|")
    return " and ".join(parts)


def build_items() -> list:
    items = [
        {
            "name": "Progressive Chapter Pass",
            "category": ["Chapter Passes"],
            "count": 4,
            "progression": True,
            "_comment": "Gates each successive career chapter region.",
        }
    ]

    for name in COASTERS:
        items.append(
            {"name": name, "category": ["Coasters", "Rides"], "progression": True}
        )
    for name in WATER_PARK:
        items.append(
            {
                "name": name,
                "category": ["Water Park", "Rides"],
                "progression": True,
            }
        )
    for name in FLAT_RIDES:
        items.append({"name": name, "category": ["Flat Rides", "Rides"], "useful": True})
    for name in PARK_OPS:
        items.append(
            {"name": name, "category": ["Park Operations"], "progression": True}
        )

    items.append(
        {
            "name": "Progressive Staff Hire",
            "category": ["Park Operations"],
            "count": 4,
            "progression": True,
            "_comment": "Janitor, Mechanic, Vendor, then Lifeguard.",
        }
    )

    items.append(
        {
            "name": "Guest Satisfaction Boost",
            "category": ["Bonuses"],
            "count": 6,
            "useful": True,
        }
    )

    # One copy each. A career-only world has just 74 locations, so the trap
    # pool has to stay small enough to fit alongside the progression items.
    for name in TRAPS:
        items.append(
            {"name": name, "category": ["Traps"], "count": 1, "trap": True}
        )

    return items


def build_locations() -> list:
    locations = []

    for chapter_index, (region, scenarios) in enumerate(CAREER):
        for scenario in scenarios:
            aquatic = scenario in AQUATIC_SCENARIOS
            for medal_index, medal in enumerate(MEDALS):
                rides = RIDE_CURVE[chapter_index][medal_index]
                ops = OPS_CURVE[chapter_index][medal_index]
                water = WATER_CURVE[chapter_index][medal_index] if aquatic else 0

                location = {
                    "name": f"{scenario} - {medal} Medal",
                    "category": ["Career Medals", f"Chapter - {region}", medal],
                    "region": region,
                }
                requirement = requires(rides, ops, water)
                if requirement:
                    location["requires"] = requirement
                locations.append(location)

    # Goal locations. Whichever goal is not selected in the yaml becomes an
    # ordinary check, courtesy of unused_goals_are_locations in game.json.
    locations.append(
        {
            "name": "Career Complete - Gold at Coaster Chasm",
            "category": ["Goals"],
            "region": "Final Plunge",
            "requires": requires(12, 5, 0),
            "victory": True,
        }
    )
    locations.append(
        {
            "name": "Career Mastery - Platinum Every Scenario",
            "category": ["Goals"],
            "region": "Final Plunge",
            "requires": "|@Rides:20| and |@Park Operations:8| and |@Water Park:8|",
            "victory": True,
        }
    )

    for name, rides, ops, water in MILESTONES:
        location = {
            "name": name,
            "category": ["Franchise Milestones"],
            "region": "Franchise and Challenge",
        }
        requirement = requires(rides, ops, water)
        if requirement:
            location["requires"] = requirement
        locations.append(location)

    return locations


def write(filename: str, schema_name: str, payload: list) -> None:
    path = os.path.join(DATA, filename)
    document = {"$schema": f"{SCHEMA}.{schema_name}.schema.json", "data": payload}
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(document, handle, indent=4, ensure_ascii=False)
        handle.write("\n")
    print(f"wrote {filename}: {len(payload)} entries")


if __name__ == "__main__":
    items = build_items()
    locations = build_locations()
    write("items.json", "items", items)
    write("locations.json", "locations", locations)

    total_copies = sum(item.get("count", 1) for item in items)
    print(f"item pool: {total_copies} copies across {len(items)} definitions")
    print(f"locations: {len(locations)}")
