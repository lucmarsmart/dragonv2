extends Node3D

var combat: Node
var velocity := Vector3.ZERO
var damage := 18.0
var remaining := 5.0
var owner_rid := RID()
var hit := false

func _ready() -> void:
	var model: PackedScene = load("res://assets/siege/weapons/bolt.glb")
	add_child(model.instantiate())

func _physics_process(delta: float) -> void:
	if hit or not is_instance_valid(combat) or not combat.is_running():
		queue_free()
		return
	remaining -= delta
	if remaining <= 0:
		queue_free()
		return
	var start := global_position
	velocity.y -= 3.5 * delta
	var end := start + velocity * delta
	# Swept ray, so a 65m/s bolt cannot skip a thin wall or the player's collider.
	var query := PhysicsRayQueryParameters3D.create(start, end, 3)
	if owner_rid.is_valid():
		query.exclude = [owner_rid]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if not result.is_empty():
		hit = true
		global_position = result.position
		if result.collider == combat.dragon:
			combat.damage_dragon(damage, "Virote de ballista")
		combat.projectile_impacts += 1
		combat.spawn_impact(result.position, result.normal, false)
		queue_free()
		return
	global_position = end
	if velocity.length_squared() > 0.1:
		look_at(end + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.95 else Vector3.RIGHT)
