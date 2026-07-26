#!/usr/bin/env bash
# Package the Planet Coaster 2 Manual world into a .apworld.
#
# Fetches the upstream Manual template, drops this repo's data/ and docs/ on top
# of its src/, and zips the result. Nothing from the template is vendored here,
# so the build always tracks upstream.
#
# Usage: ./build.sh [output-dir]

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$(cd "${1:-$HERE/dist}" 2>/dev/null || { mkdir -p "${1:-$HERE/dist}"; cd "${1:-$HERE/dist}"; }; pwd)"

GAME="$(python3 -c "import json;print(json.load(open('$HERE/data/game.json'))['game'])")"
CREATOR="$(python3 -c "import json;print(json.load(open('$HERE/data/game.json'))['creator'])")"
BASENAME="manual_${GAME}_${CREATOR}"

echo "==> Validating data"
python3 "$HERE/tools/build_data.py"
python3 "$HERE/tools/check_logic.py"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Fetching Manual template"
git clone --depth 1 --quiet https://github.com/ManualForArchipelago/Manual.git "$WORK/Manual"

echo "==> Assembling $BASENAME"
mv "$WORK/Manual/src" "$WORK/$BASENAME"
cp "$HERE"/data/*.json "$WORK/$BASENAME/data/"
# The template ships example data for files we do not define; drop them so its
# sample items and events cannot leak into our pool.
rm -f "$WORK/$BASENAME/data/events.json" "$WORK/$BASENAME/data/meta.json"
rm -f "$WORK/$BASENAME"/docs/*.md
cp "$HERE"/docs/*.md "$WORK/$BASENAME/docs/"

echo "==> Zipping"
mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$BASENAME.apworld"
( cd "$WORK" && zip -r -q "$BASENAME.zip" "$BASENAME" )
mv "$WORK/$BASENAME.zip" "$OUT_DIR/$BASENAME.apworld"

echo "==> Built $OUT_DIR/$BASENAME.apworld"
