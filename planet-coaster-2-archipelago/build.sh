#!/usr/bin/env bash
# Package the Planet Coaster 2 Manual world into a .apworld.
#
# Assembles this repo's data/ and docs/ on top of the upstream Manual template,
# then packages it with Archipelago's own "Build APWorlds" component. Going
# through Archipelago is what writes the "version" and "compatible_version"
# fields into archipelago.json; an apworld without them is rejected from
# Archipelago 0.7.0 onward, so a plain zip is not good enough.
#
# Both checkouts are cached in .cache/ and reused. Point AP_ROOT at an existing
# Archipelago source tree to skip cloning it.
#
# Usage: ./build.sh [output-dir]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${1:-$HERE/dist}"
CACHE="$HERE/.cache"

# Apworld filenames must be all lower case -- an upper case name raises a bogus
# import exception under frozen Python 3.10+.
WORLD_DIR="manual_planetcoaster2_bondfired"

echo "==> Validating data"
python3 "$HERE/tools/build_data.py"
python3 "$HERE/tools/check_logic.py"

mkdir -p "$CACHE"

if [ -n "${AP_ROOT:-}" ]; then
    AP="$AP_ROOT"
    echo "==> Using Archipelago at $AP"
else
    AP="$CACHE/Archipelago"
    if [ -d "$AP" ]; then
        echo "==> Reusing cached Archipelago checkout"
    else
        echo "==> Cloning Archipelago (one time, into .cache/)"
        git clone --depth 1 --quiet https://github.com/ArchipelagoMW/Archipelago.git "$AP"
    fi
fi

MANUAL="$CACHE/Manual"
if [ -d "$MANUAL" ]; then
    echo "==> Reusing cached Manual template"
    git -C "$MANUAL" pull --quiet --ff-only || true
else
    echo "==> Cloning Manual template"
    git clone --depth 1 --quiet https://github.com/ManualForArchipelago/Manual.git "$MANUAL"
fi

echo "==> Assembling $WORLD_DIR"
TARGET="$AP/worlds/$WORLD_DIR"
rm -rf "$TARGET"
cp -r "$MANUAL/src" "$TARGET"
cp "$HERE"/data/*.json "$TARGET/data/"
# The template ships sample data for files we do not define; drop them so its
# example items and events cannot leak into our pool.
rm -f "$TARGET/data/events.json" "$TARGET/data/meta.json"
rm -f "$TARGET"/docs/*.md
cp "$HERE"/docs/*.md "$TARGET/docs/"
cp "$HERE/archipelago.json" "$TARGET/archipelago.json"

GAME="$(python3 -c "import json;print(json.load(open('$HERE/archipelago.json'))['game'])")"

echo "==> Packaging via Archipelago"
# ModuleUpdate is stubbed out because it otherwise blocks on stdin trying to
# install dependencies for unrelated core worlds we neither need nor load.
( cd "$AP" && python3 -c "
import sys, ModuleUpdate
ModuleUpdate.update = lambda *a, **k: None
ModuleUpdate.update_ran = True
sys.argv = ['Launcher.py', 'Build APWorlds', '--', '$GAME']
exec(open('Launcher.py').read().replace('ModuleUpdate.update()', 'pass'))
" ) >"$CACHE/build.log" 2>&1 || { echo "Packaging failed, see $CACHE/build.log"; exit 1; }

BUILT="$AP/build/apworlds/$WORLD_DIR.apworld"
[ -f "$BUILT" ] || { echo "Expected $BUILT, not found. See $CACHE/build.log"; exit 1; }

mkdir -p "$OUT_DIR"
cp "$BUILT" "$OUT_DIR/$WORLD_DIR.apworld"
rm -rf "$TARGET"

echo "==> Verifying manifest"
python3 - "$OUT_DIR/$WORLD_DIR.apworld" "$WORLD_DIR" <<'PY'
import json, sys, zipfile
path, world_dir = sys.argv[1], sys.argv[2]
manifest = json.loads(zipfile.ZipFile(path).read(f"{world_dir}/archipelago.json"))
missing = [k for k in ("game", "version", "compatible_version") if k not in manifest]
if missing:
    sys.exit(f"manifest missing {missing}")
print(f"    game={manifest['game']} world_version={manifest.get('world_version')} "
      f"container_version={manifest['version']}")
PY

echo "==> Built $OUT_DIR/$WORLD_DIR.apworld"
