#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64"
PACK_PATH="/home/cenkai/game_dev_plan/build/LuminousGrove.pck"

if [[ ! -f "$PACK_PATH" ]]; then
  echo "缺少 $PACK_PATH，请先运行 build_development_pack.sh。" >&2
  exit 1
fi

exec "$GODOT_BIN" --main-pack "$PACK_PATH"
