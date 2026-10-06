extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

# Baseline copied from terrain SHA a17cc68d… before the silhouette change.
func _previous_height(terrain: Node3D, x: float, z: float) -> float:
	var distance_to_river: float = absf(x - terrain.river_center(z))
	var width: float = terrain.river_width(z)
	var detail: float = terrain._noise.get_noise_2d(x, z)
	var h: float = maxf(terrain._original_height(x, z), 9.0) + detail * 9.0
	var bank: float = smoothstep(width - 8.0, width + 64.0, distance_to_river)
	h = lerpf(-3.0 + detail * 0.35, h, bank)
	var court_distance: float = maxf(absf(x - 300.0) / 96.0, absf(z - 120.0) / 90.0)
	h = lerpf(24.0, h, smoothstep(1.0, 1.55, court_distance))
	if z > 180.0 and z < 390.0:
		var access: float = (1.0 - smoothstep(18.0, 42.0, absf(x - 300.0))) * (1.0 - smoothstep(325.0, 390.0, z))
		h = lerpf(h, 24.0, access)
	return h

func _sample(terrain: Node3D, x: float, z: float) -> Dictionary:
	var hit: Dictionary = terrain.ground_surface(Vector3(x,0,z))
	if hit.is_empty():
		failures.append("Missing ray %s,%s" % [x,z])
		return {}
	var n: Vector3 = hit.normal
	var ix := floori((x+1000.0)/6.25)
	var iz := floori((z+1000.0)/6.25)
	var fx := (x+1000.0)/6.25-ix
	var fz := (z+1000.0)/6.25-iz
	var baseline := PackedFloat32Array([_previous_height(terrain,-1000.0+ix*6.25,-1000.0+iz*6.25),_previous_height(terrain,-1000.0+ix*6.25,-1000.0+(iz+1)*6.25),_previous_height(terrain,-1000.0+(ix+1)*6.25,-1000.0+iz*6.25),_previous_height(terrain,-1000.0+(ix+1)*6.25,-1000.0+(iz+1)*6.25)])
	var before: float = baseline[0]+(baseline[2]-baseline[0])*fx+(baseline[1]-baseline[0])*fz if fx+fz<=1.0 else baseline[3]+(baseline[1]-baseline[3])*(1.0-fx)+(baseline[2]-baseline[3])*(1.0-fz)
	return {"x":x,"z":z,"height_m":hit.position.y,"previous_height_m":before,"normal":[n.x,n.y,n.z],"slope_degrees":rad_to_deg(acos(clampf(n.y,-1.0,1.0))),"ray_error_m":absf(hit.position.y-terrain.ground_height(x,z))}

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain: Node3D = load("res://assets/models/terrain.glb").instantiate()
	terrain.set_script(load("res://scripts/terrain.gd"))
	world.add_child(terrain)
	await physics_frame
	await physics_frame
	var counts := {"court":0,"river":0,"access":0,"changed_outside":0}
	var maximum_protected_error := 0.0
	var maximum_change := 0.0
	var baseline_grid := PackedFloat32Array([0.0])
	for iz in 321:
		for ix in 321:
			var x: float = -1000.0 + ix * 6.25
			var z: float = -1000.0 + iz * 6.25
			baseline_grid[0]=_previous_height(terrain,x,z)
			var before: float = baseline_grid[0]
			var after: float = terrain._heights[iz*321+ix]
			var error: float = absf(after-before)
			var protected := false
			if maxf(absf(x-300.0)/96.0,absf(z-120.0)/90.0)<=1.55:
				counts.court+=1
				protected=true
			if absf(x-terrain.river_center(z))<=terrain.river_width(z)+64.0:
				counts.river+=1
				protected=true
			if absf(x-300.0)<=48.0 and z>=150.0 and z<=430.0:
				counts.access+=1
				protected=true
			if protected:
				maximum_protected_error=maxf(maximum_protected_error,error)
			elif error>0.001:
				counts.changed_outside+=1
				maximum_change=maxf(maximum_change,error)
	if maximum_protected_error!=0.0:failures.append("Protected grid changed")
	if terrain._tree_transforms.size()>2771:failures.append("Tree budget increased")
	var samples: Array[Dictionary] = []
	for p in [Vector2(450,220),Vector2(650,-300),Vector2(300,275),Vector2(300,82),Vector2(300,400)]:
		samples.append(_sample(terrain,p.x,p.y))
	var second_walk_sample: Dictionary = {}
	for z in range(-450,-100,25):
		for x in range(550,900,25):
			var sample := _sample(terrain,float(x),float(z))
			if not sample.is_empty() and sample.slope_degrees>=12.0 and sample.slope_degrees<=19.0 and absf(sample.height_m-sample.previous_height_m)>3.0:
				second_walk_sample=sample
				break
		if not second_walk_sample.is_empty():break
	var report := {"terrain_sha256":FileAccess.get_sha256("res://scripts/terrain.gd"),"shader_sha256":FileAccess.get_sha256("res://shaders/terrain.gdshader"),"baseline_terrain_sha256":"a17cc68d679c7f4e9586552eb65780d419338f8e83fec576465cf756aa9d33b3","grid_resolution":320,"trees":terrain._tree_transforms.size(),"protected_counts":counts,"maximum_protected_grid_error_m":maximum_protected_error,"maximum_changed_height_m":maximum_change,"surface_samples":samples,"new_walk_sample":second_walk_sample,"failures":failures}
	FileAccess.open("res://docs/validation/v2/environment-warp-physics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("WARP_VERIFY ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
