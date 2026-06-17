#!/usr/bin/env python3
"""Phase 4 — Fix broken requires and config references."""

FILE = "SoundScape_RNG.rbxlx"

with open(FILE, "r", encoding="utf-8") as f:
    content = f.read()

fixes = [
    # Fix: Monet → Monetization in RNGController
    (
        "require(RS.Main.Configs.Monet)",
        "require(RS.Main.Configs.Monetization)",
    ),
    # Fix: Monet.Gamepasses → Monetization.Gamepasses
    (
        "(Monet.Gamepasses.AutoRoll  and Monet.Gamepasses.AutoRoll.id  or 0)",
        "(Monetization.Gamepasses.AutoRoll  and Monetization.Gamepasses.AutoRoll.id  or 0)",
    ),
    (
        "(Monet.Gamepasses.QuickRoll and Monet.Gamepasses.QuickRoll.id or 0)",
        "(Monetization.Gamepasses.QuickRoll and Monetization.Gamepasses.QuickRoll.id or 0)",
    ),
]

count = 0
for old, new in fixes:
    if old in content:
        content = content.replace(old, new)
        count += 1
        print(f"FIX: {old[:60]}...")
    else:
        print(f"SKIP (not found): {old[:60]}...")

with open(FILE, "w", encoding="utf-8") as f:
    f.write(content)

print(f"Phase 4 complete. {count} fixes applied.")
