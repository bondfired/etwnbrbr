#!/usr/bin/env bash
# End-to-end test: build the apworld, then generate a real multiworld with
# Archipelago for every combination of the yaml options.
#
# Reuses the Archipelago checkout that build.sh caches in .cache/, or the one
# at AP_ROOT. Requires the generation dependencies:
#
#   pip install pyyaml schema jellyfish orjson websockets platformdirs \
#               colorama bsdiff4 cymem typing_extensions jinja2 certifi pathspec
#
# Usage: ./test.sh

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE="$HERE/.cache"
WORLD_DIR="manual_planetcoaster2_bondfired"
GAME="Manual_PlanetCoaster2_bondfired"

"$HERE/build.sh" >/dev/null
echo "built $WORLD_DIR.apworld"

AP="${AP_ROOT:-$CACHE/Archipelago}"
[ -d "$AP" ] || { echo "No Archipelago checkout; run ./build.sh first"; exit 1; }

mkdir -p "$AP/custom_worlds"
rm -f "$AP/custom_worlds/$WORLD_DIR.apworld"
cp "$HERE/dist/$WORLD_DIR.apworld" "$AP/custom_worlds/"

# Generate.py calls ModuleUpdate.update(), which blocks on stdin trying to
# install dependencies for unrelated core worlds. Stub it out.
cat > "$AP/_run_gen.py" <<'PY'
import sys, ModuleUpdate
ModuleUpdate.update = lambda *a, **k: None
ModuleUpdate.update_ran = True
sys.argv = ["Generate.py", "--seed", sys.argv[1], "--player_files_path", "Players",
            "--outputpath", "output", "--spoiler", "3"]
exec(open("Generate.py").read().replace("ModuleUpdate.update()", "pass"))
PY

count_locations() {
    python3 - <<'PY'
import glob, zipfile
zf = zipfile.ZipFile(glob.glob('output/*.zip')[0])
name = [n for n in zf.namelist() if n.endswith('Spoiler.txt')][0]
text = zf.read(name).decode('utf-8', 'replace')
block = text.split('Locations:\n\n')[1].split('\n\n')[0] if 'Locations:\n\n' in text else ''
print(len([line for line in block.splitlines() if line.strip()]))
PY
}

failures=0
cd "$AP"
for goal in career_complete career_mastery; do
  for milestones in false true; do
    for traps in false true; do
      rm -rf Players output && mkdir -p Players output
      cat > Players/pc2.yaml <<YML
name: Tester
game: $GAME
$GAME:
  goal: $goal
  franchise_milestones: $milestones
  include_traps: $traps
YML
      label="goal=$goal milestones=$milestones traps=$traps"
      if python3 _run_gen.py 777 >gen.log 2>&1; then
          echo "PASS  $label -> $(count_locations) locations"
      else
          echo "FAIL  $label"
          tail -15 gen.log | sed 's/^/      /'
          failures=$((failures + 1))
      fi
    done
  done
done

rm -f "$AP/_run_gen.py"
echo
if [ "$failures" -ne 0 ]; then
    echo "$failures combination(s) failed."
    exit 1
fi
echo "All 8 combinations generated successfully."
