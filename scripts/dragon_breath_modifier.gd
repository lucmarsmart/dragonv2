extends SkeletonModifier3D

var breath: Node3D

func _process_modification() -> void:
	if not breath or not is_instance_valid(breath.dragon):
		return
	var sk := get_skeleton()
	var driven_head: bool = "has_head_pose_driver" in breath.dragon and breath.dragon.has_head_pose_driver
	if not driven_head and breath.mouth_bone >= 0 and breath.intensity > 0.001:
		# Raise and lead the neck toward the flight heading before exhaling.
		# On land this keeps the jet forward instead of aiming into the front paws.
		var head_pos := sk.to_global(sk.get_bone_global_pose(breath.dragon.bone_head_idx).origin)
		var snout_pos := sk.to_global(sk.get_bone_global_pose(breath.mouth_bone).origin)
		var current := (snout_pos - head_pos).normalized()
		var desired: Vector3 = -breath.dragon.global_basis.z.normalized()
		if breath.dragon.locomotion_state == breath.dragon.LocomotionState.GROUNDED:
			desired.y = -0.025
			desired = desired.normalized()
		var correction := Quaternion(current,desired)
		var weights := [0.25,0.35,0.40]
		for i in breath.dragon.bone_neck_indices.size():
			var bone: int = breath.dragon.bone_neck_indices[i]
			var parent := sk.get_bone_parent(bone)
			var parent_world := (sk.global_basis * sk.get_bone_global_pose(parent).basis).orthonormalized().get_rotation_quaternion()
			var turn := Quaternion.IDENTITY.slerp(correction, weights[i] * breath.intensity)
			var local_turn := parent_world.inverse() * turn * parent_world
			sk.set_bone_pose_rotation(bone, local_turn * sk.get_bone_pose_rotation(bone))
	# Mandibular chain, whose child bones articulate the tongue.
	var jaw := sk.find_bone("Bone015_012")
	if jaw >= 0:
		var parent := sk.get_bone_parent(jaw)
		var axis_world: Vector3 = breath.dragon.global_basis.x.normalized()
		var axis_skeleton := sk.global_basis.inverse() * axis_world
		var axis_parent := sk.get_bone_global_pose(parent).basis.inverse() * axis_skeleton
		var open_jaw := Quaternion(axis_parent.normalized(), -0.26 * breath.intensity)
		sk.set_bone_pose_rotation(jaw, open_jaw * sk.get_bone_pose_rotation(jaw))
		if breath.intensity>.001:
			breath.dragon.wing_contact.sample_jaw_final(breath.dragon,sk)
	# Read both original oral rim vertices after the jaw, while the final skin pose
	# is applied. The nasal tip below is retained only for the head direction.
	breath._update_mouth()
	breath.rendered_snout_tip = sk.to_global(sk.get_bone_global_pose(breath.mouth_bone).origin) if breath.mouth_bone >= 0 else breath.mouth_position
	for material in [breath.flame_material, breath.smoke_material]:
		material.set_shader_parameter("mouth_position", breath.mouth_position)
		material.set_shader_parameter("breath_direction", breath.breath_direction)
