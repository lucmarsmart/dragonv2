#!/bin/sh
set -eu
if [ -n "${DRAGON_GODOT_BIN:-}" ] && [ -x "$DRAGON_GODOT_BIN" ]; then
  exec "$DRAGON_GODOT_BIN" "$@"
fi
for dragon_runtime in "/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Applications/Godot.app/Contents/MacOS/Godot" "$HOME/Library/Application Support/Dragonv2/Godot.app/Contents/MacOS/Godot"; do
  if [ -x "$dragon_runtime" ]; then exec "$dragon_runtime" "$@"; fi
done
if command -v godot >/dev/null 2>&1; then exec godot "$@"; fi
printf '%s\n' 'No se encontró Godot 4.7. Instálalo desde https://godotengine.org/download o define DRAGON_GODOT_BIN.' >&2
exit 1
