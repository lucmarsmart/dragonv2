extends "res://scripts/test_dragon_anatomy.gd"

# Camera and rendered evidence only; parent locomotion assertions and controls run unchanged.
var captured_bank_states := {}
func record() -> void:
	super.record()
	if not is_instance_valid(camera) or not is_instance_valid(dragon): return
	var heading := Basis(Vector3.UP, dragon.rotation.y)
	camera.global_position = dragon.global_position + heading * Vector3(0, 8, -50)
	camera.look_at(dragon.global_position + Vector3(0, 1, 0), Vector3.UP)
	if contract_bank_phase.is_empty() or captured_bank_states.has(contract_bank_phase): return
	var angle := absf(rad_to_deg(dragon.rotation.z))
	var ready := angle >= 25.0 if contract_bank_phase.ends_with("turn") else angle <= 0.5
	if ready:
		captured_bank_states[contract_bank_phase] = true
		capture_presented_bank.call_deferred(contract_bank_phase)
func capture_presented_bank(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/validation/v2/anatomy-bank-" + label + ".png")
	print("BANK_RENDER_CAPTURE ", label, " body_deg=", rad_to_deg(dragon.rotation.z), " original_skin_axis=", contract_axis_samples)
