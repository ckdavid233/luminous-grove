#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64"
PROJECT_PATH="/home/cenkai/game_dev_plan/game"

exec "$GODOT_BIN" --path "$PROJECT_PATH"
