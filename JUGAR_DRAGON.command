#!/bin/sh
set -eu
dragon_project=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
exec "$dragon_project/tools/godot.sh" --path "$dragon_project" "$@"
