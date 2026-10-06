extends "res://scripts/combat/play_siege_validation.gd"

# Evidence-only adapter: the native launcher explicitly enables MovieMaker.
# This engine build does not expose that mode through the parent's query.
# Set output classification before the first capture and performance recording.
func capture(label: String) -> void:
	movie_maker = true
	tag = "metal"
	await super.capture(label)
