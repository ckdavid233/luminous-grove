#!/usr/bin/env bash
set -euo pipefail

BLENDER_BIN="/home/cenkai/game_dev_tools/blender/4.5.12/blender"
SCRIPT_PATH="/home/cenkai/game_dev_plan/art_source/player/create_player.py"

exec "$BLENDER_BIN" --background --factory-startup --python "$SCRIPT_PATH"

