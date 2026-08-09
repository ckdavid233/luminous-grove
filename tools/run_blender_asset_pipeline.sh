#!/usr/bin/env bash
set -euo pipefail

BLENDER_BIN="/home/cenkai/game_dev_tools/blender/4.5.12/blender"
SCRIPT_PATH="/home/cenkai/game_dev_plan/art_source/shrine/create_shrine.py"
PREVIEW_SCRIPT="/home/cenkai/game_dev_plan/art_source/shrine/render_preview.py"

"$BLENDER_BIN" --background --python "$SCRIPT_PATH"
exec "$BLENDER_BIN" --background --python "$PREVIEW_SCRIPT"
