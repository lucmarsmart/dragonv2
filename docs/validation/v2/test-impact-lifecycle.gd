extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var combat = scene.get_node("SiegeCombat")
	combat.spawn_impact(Vector3(300, 30, 120), Vector3.UP, true)
	var impact: CPUParticles3D
	for child in combat.get_children():
		if child is CPUParticles3D:
			impact = child
	check(is_instance_valid(impact), "Actual combat creates impact particles")
	for tick in 90:
		await process_frame
	check(not is_instance_valid(impact), "Completed one-shot impact frees itself")
	combat.spawn_impact(Vector3(300, 30, 120), Vector3.UP, false)
	scene.queue_free()
	for tick in 90:
		await process_frame
	check(not is_instance_valid(scene), "Scene can close while an impact is active")
	print("IMPACT_LIFECYCLE failures=", failures)
	quit(0 if failures == 0 else 1)
