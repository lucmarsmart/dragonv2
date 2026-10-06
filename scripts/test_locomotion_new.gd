extends SceneTree
var failures: Array[String]=[]
func check(value: bool, message: String):
	if not value:
		failures.append(message)
		push_error(message)
func ticks(count: int):
	for i in range(count): await physics_frame
func _init():
	var scene=load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await ticks(80)
	var d=scene.get_node("Dragon")
	d.has_taken_off=true
	d.manual_input_override=true
	d.global_position=Vector3(0,400,0)
	d.rotation=Vector3.ZERO
	d.target_pitch=0.0
	d.target_roll=0.0
	d.target_yaw=0.0
	d.velocity=Vector3(0,0,-26)
	var y0=d.position.y
	d.manual_climb=true
	var max_tick_delta=0.0
	for i in range(120):
		var before=d.velocity
		await physics_frame
		max_tick_delta=max(max_tick_delta,before.distance_to(d.velocity))
	check(d.position.y>y0+14,"CLIMB must gain height")
	check(d.rotation.x>0.4,"CLIMB pitch positive")
	d.manual_climb=false
	d.manual_dive=true
	y0=d.position.y
	for i in range(150):
		var before=d.velocity
		await physics_frame
		max_tick_delta=max(max_tick_delta,before.distance_to(d.velocity))
	print("Dive deltaheight ",d.position.y-y0)
	check(d.position.y<y0-25,"DIVE must lower height")
	check(d.current_speed>32,"DIVE must gain speed")
	check(max_tick_delta<3.0,"Velocity continuity <3m/s per tick: %s"%max_tick_delta)
	d.manual_dive=false
	d.manual_brake=true
	await ticks(180)
	check(d.current_speed>=d.min_stall_speed,"Brake cannot reverse scalar speed")
	check(d.velocity.dot(-d.global_basis.z)>0,"Brake cannot reverse forward movement")
	d.manual_brake=false
	var plane=StaticBody3D.new()
	plane.position=Vector3(180,250,120)
	var col=CollisionShape3D.new()
	var box=BoxShape3D.new()
	box.size=Vector3(200,1,200)
	col.shape=box
	plane.add_child(col)
	scene.add_child(plane)
	d.global_position=Vector3(180,260,120)
	d.rotation=Vector3.ZERO
	d.target_pitch=0.0
	d.target_roll=0.0
	d.target_yaw=0.0
	d.velocity=Vector3(0,-3,0)
	d.current_speed=0
	d.locomotion_state=d.LocomotionState.LANDING
	await ticks(250)
	check(d.locomotion_state==d.LocomotionState.GROUNDED,"Must land on plane")
	var pos=d.position
	d.manual_move_input=1
	await ticks(90)
	check(d.position.z<pos.z-5,"Ground forward must advance")
	print("Walk feet errors: ",d.ground_pose.debug_errors)
	d.manual_move_input=-0.6
	await ticks(90)
	check(d.current_speed<0,"Ground reverse allowed")
	d.manual_move_input=0
	await ticks(40)
	check(abs(d.current_speed)<0.05,"Ground stop")
	d.trigger_takeoff()
	await ticks(100)
	check(d.locomotion_state==d.LocomotionState.FLYING,"Takeoff finishes in flight")
	check(d.position.y>pos.y+10,"Takeoff gains height")
	var wall=StaticBody3D.new()
	wall.position=Vector3(300,280,-10)
	var wc=CollisionShape3D.new()
	var ws=BoxShape3D.new()
	ws.size=Vector3(30,100,1)
	wc.shape=ws
	wall.add_child(wc)
	scene.add_child(wall)
	d.global_position=Vector3(300,280,0)
	d.rotation=Vector3.ZERO
	d.target_yaw=0
	d.target_pitch=0
	d.target_roll=0
	d.velocity=Vector3(0,-2,-15)
	d.current_speed=15
	d.locomotion_state=d.LocomotionState.LANDING
	await ticks(50)
	check(d.locomotion_state!=d.LocomotionState.GROUNDED,"Wall contact cannot ground")
	plane.queue_free()
	wall.queue_free()
	await ticks(2)
	d.global_position=Vector3(180,140,120)
	d.rotation=Vector3.ZERO
	d.target_yaw=0
	d.target_pitch=0
	d.target_roll=0
	d.velocity=Vector3(0,0,-26)
	d.current_speed=26
	d.manual_move_input=0
	d.manual_turn_input=0
	d.locomotion_state=d.LocomotionState.FLYING
	d.trigger_landing()
	for i in range(1500):
		await ticks(1)
		if d.locomotion_state==d.LocomotionState.GROUNDED: break
	await ticks(50)
	var previous: Dictionary={}
	var max_slip=0.0
	var max_contact_error=0.0
	d.manual_move_input=1.0
	for i in range(240):
		if i==150:
			d.manual_move_input=0.0
			d.manual_turn_input=1.0
		await physics_frame
		await process_frame
		for j in range(d.ground_pose.limbs.size()):
			var limb=d.ground_pose.limbs[j]
			var foot: Vector3 = limb.actual
			var item={"point":foot,"target":limb.planted,"swing":limb.swinging}
			if previous.has(j) and not item.swing and not previous[j].swing and item.target.distance_to(previous[j].target)<0.02:
				max_slip=maxf(max_slip,foot.distance_to(previous[j].point))
			previous[j]=item
		for j in range(d.ground_pose.debug_errors.size()):
			var error=d.ground_pose.debug_errors[j]
			if error>max_contact_error:
				max_contact_error=error
				if error>0.45: print("ERRORFRAME ",i," limb ",j," error ",error," swing ",d.ground_pose.limbs[j].swinging," pos ",d.position)
	print("REAL TERRAIN WALK+PIVOT max stance displacement per tick: ",max_slip," max contact error: ",max_contact_error)
	check(max_slip<0.05,"Stance feet must remain stable on real slope during walking and pivot")
	check(max_contact_error<0.45,"All foot targets remain reachable on real slope walking and pivot")
	print("LOCOMOTION NEW: ",failures.size()," failures; max tick delta ",max_tick_delta)
	scene.free()
	for _i in 15:
		await process_frame
	quit(0 if failures.is_empty() else 1)
