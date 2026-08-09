#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="/home/cenkai/game_dev_tools/godot/4.7.1/Godot_v4.7.1-stable_linux.x86_64"
PROJECT_PATH="/home/cenkai/game_dev_plan/game"

TESTS=(
  environment_capability_test.gd
  environment_geometry_test.gd
  realistic_character_import_test.gd
  player_import_test.gd
  player_animation_test.gd
  movement_regression_test.gd
  save_service_test.gd
  smoke_test.gd
  world_streamer_test.gd
  jolt_physics_test.gd
  cinematic_director_test.gd
  interactive_water_test.gd
  presentation_test.gd
  quality_settings_test.gd
  input_regression_test.gd
  phase_shift_test.gd
  portal_preview_test.gd
  lantern_city_level_test.gd
  rain_eye_level_test.gd
  narrative_finale_test.gd
  gameplay_test.gd
)

for test_name in "${TESTS[@]}"; do
  echo "RUN $test_name"
  "$GODOT_BIN" \
    --headless \
    --path "$PROJECT_PATH" \
    --script "res://tests/$test_name"
done

echo "REGRESSION_OK tests=${#TESTS[@]}"
