#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64"
PROJECT_PATH="/home/cenkai/game_dev_plan/game"
BUILD_PATH="/home/cenkai/game_dev_plan/build"
PACK_PATH="$BUILD_PATH/LuminousGrove.pck"

mkdir -p "$BUILD_PATH"
exec "$GODOT_BIN" \
  --headless \
  --path "$PROJECT_PATH" \
  --export-pack "Linux Development Pack" \
  "$PACK_PATH"
