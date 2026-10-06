extends SceneTree

var scene: Node3D
var dragon: DragonController
var camera: Camera3D
var breath: DragonBreath
var frame_times: Array[float] = []

func _initialize() -> void:
	call_deferred("run")

func wait_ticks(count: int) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://docs/validation/" + label + ".png"
	root.get_texture().get_image().save_png(path)
	print("CAPTURE ",label," pos=",dragon.global_position," speed=",dragon.current_speed," state=",dragon.locomotion_state)

func run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	dragon = scene.get_node("Dragon")
	camera = scene.get_node("FlightCamera")
	breath = dragon.get_node("DragonBreath")
	await wait_ticks(90)
	dragon.manual_input_override = true
	dragon.has_taken_off = true
	await capture("01-flight")
	dragon.manual_climb = true
	for i in range(6):
		await wait_ticks(15)
		await capture("02-climb-%02d" % i)
	dragon.manual_climb = false
	dragon.manual_dive = true
	for i in range(6):
		await wait_ticks(15)
		await capture("03-dive-%02d" % i)
	dragon.manual_dive = false
	dragon.trigger_normal()
	breath.manual_override = true
	breath.manual_fire = true
	camera.set_view(camera.ViewPreset.RIGHT)
	await wait_ticks(75)
	await capture("04-fire-air")
	breath.manual_fire = false
	dragon.manual_turn_input = 0
	dragon.trigger_landing()
	for _i in range(1800):
		await wait_ticks(1)
		if dragon.locomotion_state == dragon.LocomotionState.GROUNDED:
			break
	await wait_ticks(60)
	await capture("05-landed")
	dragon.manual_move_input = 1.0
	for i in range(8):
		await wait_ticks(12)
		await capture("06-walk-%02d" % i)
	dragon.manual_move_input = 0
	await wait_ticks(50)
	breath.manual_fire = true
	await wait_ticks(40)
	await capture("07-fire-ground")
	breath.manual_fire = false
	dragon.trigger_takeoff()
	for i in range(6):
		await wait_ticks(15)
		await capture("08-takeoff-%02d" % i)
	camera.set_view(camera.ViewPreset.BACK)
	await wait_ticks(60)
	scene.get_node("HUD/ControlsPanel").visible = true
	await capture("09-help")
	print("CAPTURE COMPLETE")
	scene.queue_free()
	await wait_ticks(15)
	quit(0)
