extends SceneTree
# Busca el tramo realmente cíclico de un clip comparando TODAS las rotaciones locales de hueso.
# Uso: godot --headless --script res://scripts/find_cyclic_loop.gd

func _init():
	var raw = load("res://assets/models/dragon.glb").instantiate()
	root.add_child(raw)
	var ap: AnimationPlayer = null
	var q = [raw]
	while q.size() > 0:
		var c = q.pop_front()
		if c is AnimationPlayer: ap = c
		for ch in c.get_children(): q.append(ch)
	for clip in ["Qishilong_fly2", "Qishilong_down"]:
		_search(ap.get_animation(clip), clip)
	quit(0)

func _search(anim: Animation, clip: String) -> void:
	var tracks: Array[int] = []
	for t in range(anim.get_track_count()):
		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			tracks.append(t)
	var step := 0.1
	var n := int(anim.length / step)
	var samples: Array = []
	for i in range(n):
		var row: Array = []
		for t in tracks:
			row.append(anim.rotation_track_interpolate(t, i * step))
		samples.append(row)
	var res: Array = []
	for i in range(n):
		for j in range(i + 10, min(n, i + 31)):
			var sum := 0.0
			var mx := 0.0
			for k in range(tracks.size()):
				var a: float = rad_to_deg((samples[i][k] as Quaternion).angle_to(samples[j][k]))
				sum += a
				mx = max(mx, a)
			# Actividad: cuánto se aleja la pose del inicio dentro de la ventana (descarta poses estáticas)
			var act := 0.0
			for m in range(i + 1, j):
				var s2 := 0.0
				for k in range(tracks.size()):
					s2 += rad_to_deg((samples[i][k] as Quaternion).angle_to(samples[m][k]))
				act = max(act, s2 / tracks.size())
			if act < 8.0:
				continue
			res.append({"s": i * step, "e": j * step, "mean": sum / tracks.size(), "max": mx, "act": act})
	res.sort_custom(func(a, b): return a["mean"] + 0.1 * a["max"] < b["mean"] + 0.1 * b["max"])
	print("== ", clip, " (", anim.length, "s) top 10 ==")
	for i in range(min(10, res.size())):
		var m = res[i]
		print("start=%.2f end=%.2f len=%.2f mean=%.2f max=%.2f act=%.1f" % [m["s"], m["e"], m["e"] - m["s"], m["mean"], m["max"], m["act"]])

