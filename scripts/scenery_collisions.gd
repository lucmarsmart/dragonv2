extends Node3D

## A bounded pool gives nearby trunks and boulders physical presence without 7000 bodies.
const ACTIVE_RADIUS := 90.0
const TREE_BUDGET := 192
const ROCK_BUDGET := 64
var landscape: Node3D
var dragon: CharacterBody3D
var trees: Array = []
var rock_transforms: Array[Transform3D] = []
var rock_vertices: PackedVector3Array
var active: Dictionary = {}
var timer: float = 0.0

func _ready() -> void:
	landscape = get_tree().get_first_node_in_group("landscape")
	dragon = get_parent().get_node("Dragon")
	if not landscape:
		return
	trees = landscape.get("_tree_transforms")
	var rocks := landscape.get_node_or_null("ScatteredBoulders") as MultiMeshInstance3D
	if not rocks:
		return
	rock_vertices = rocks.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for i in rocks.multimesh.instance_count:
		rock_transforms.append(rocks.multimesh.get_instance_transform(i))
	_refresh()

func _physics_process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		timer = 0.5
		_refresh()

func _refresh() -> void:
	if not landscape or not dragon:
		return
	var selected: Dictionary = {}
	var local_player := landscape.to_local(dragon.global_position)
	for data in [[trees, TREE_BUDGET, "tree"], [rock_transforms, ROCK_BUDGET, "rock"]]:
		var candidates: Array[Array] = []
		for i in data[0].size():
			var t: Transform3D = data[0][i]
			var distance := Vector2(t.origin.x - local_player.x, t.origin.z - local_player.z).length_squared()
			if distance <= ACTIVE_RADIUS * ACTIVE_RADIUS:
				candidates.append([distance, i, t])
		candidates.sort_custom(func(a: Array,b: Array): return a[0] < b[0])
		for i in mini(candidates.size(), data[1]):
			var item: Array = candidates[i]
			var key: String = "%s_%d" % [data[2],item[1]]
			selected[key] = true
			if not active.has(key):
				active[key] = _make_body(item[2],data[2],key)
	for key in active.keys():
		if not selected.has(key):
			active[key].queue_free()
			active.erase(key)

func _make_body(t: Transform3D, kind: String, label: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = 2
	body.collision_mask = 0
	body.add_to_group("scenery_obstacle")
	var col := CollisionShape3D.new()
	var size := t.basis.get_scale()
	if kind == "tree":
		var shape := CylinderShape3D.new()
		shape.radius = 0.45 * maxf(size.x,size.z)
		shape.height = 18.96 * size.y
		col.shape = shape
		col.position.y = shape.height / 2.0
	else:
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array()
		var stride := maxi(1, rock_vertices.size() / 512)
		for i in range(0, rock_vertices.size(), stride):
			points.append(rock_vertices[i] * size)
		shape.points = points
		col.shape = shape
	body.add_child(col)
	add_child(body)
	body.global_transform = landscape.global_transform * Transform3D(t.basis.orthonormalized(), t.origin)
	return body
