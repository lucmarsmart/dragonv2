#!/bin/sh
set -eu
dragon_project=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
dragon_log=$(mktemp -t dragon-validation)
trap 'rm -f "$dragon_log"' EXIT HUP INT TERM
run_checked() {
    dragon_status=0
    "$dragon_project/tools/godot.sh" "$@" > "$dragon_log" 2>&1 || dragon_status=$?
    cat "$dragon_log"
    if [ "$dragon_status" -ne 0 ] || grep -Eq 'SCRIPT ERROR|SHADER ERROR|^ERROR:' "$dragon_log"; then
        return 1
    fi
}
run_checked --headless --path "$dragon_project" --editor --import
run_checked --headless --path "$dragon_project" --script res://scripts/test_dragon_biomechanics.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_acceptance.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd -- --stationary-pose
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd -- --body-contact
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd -- --foot-yaw
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd -- --locomotion-contract
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/anatomy_descent_compact_repro.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/anatomy_mouth_repro.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_camera_surfaces.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/test_dragon_anatomy.gd -- --real-terrain --body-terrain --verify-body-partition
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/anatomy_escape_repro.gd -- --acceptance
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/verify_siege_environment.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_siege.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_active_ai_los.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_simultaneous_controls.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_ground_escape.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_terrain_player_escape.gd -- --x=500 --z=450
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_terrain_player_escape.gd -- --x=850 --z=130
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_terrain_player_escape.gd -- --x=-450 --z=220
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_air_contact_escape.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/test_player_aim_feedback.gd
run_checked --headless --path "$dragon_project" --fixed-fps 60 --script res://scripts/combat/play_siege_validation.gd
