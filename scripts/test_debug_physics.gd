extends SceneTree

func ticks(count: int):
	for i in range(count):
		await physics_frame
		await process_frame

func _init():
	run.call_deferred()

func run():
	print("--- INSPECCIÓN DE PROCESAMIENTO FÍSICO ---")
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await ticks(60)
	var d = scene.get_node("Dragon")
	print("Dragon physics processing: ", d.is_physics_processing())
	print("Dragon position before: ", d.global_position)
	print("Dragon velocity before: ", d.velocity)
	print("Dragon has_taken_off: ", d.has_taken_off)
	print("Dragon calibrating: ", d.calibrating)
	
	d.has_taken_off = true
	d.velocity = Vector3(0, -10, 0)
	for i in range(10):
		await physics_frame
		await process_frame
		print("Tick %d: pos=%s vel=%s floor=%s" % [i, d.global_position, d.velocity, d.is_on_floor()])
		
	quit(0)
