#!/usr/bin/env bash
# Moved to a NEW kit folder (new zip)? Bring over the slow-to-build parts from
# the OLD folder so you don't re-download the model or regenerate the voices:
#     bash update_from.sh ~/agritect-kit-old
# Copies: the AI model, generated audio/plan cards, any photos you added, and
# the Python environment. Then just run the usual launcher.
set -euo pipefail
OLD="${1:?usage: bash update_from.sh /path/to/old/agritect-kit}"
NEW="$(cd "$(dirname "$0")" && pwd)"
for d in pi/server/model pi/server/static/media pi/server/.venv; do
  if [ -d "$OLD/$d" ]; then
    mkdir -p "$NEW/$d"; cp -R "$OLD/$d/." "$NEW/$d/"; echo "copied $d"
  else echo "skipped $d (not in old folder)"; fi
done
echo "Done. Now run:  bash run_demo_laptop.sh   (new voice clips are generated automatically)"
