extends SkeletonModifier3D
class_name DragonSkeletonModifier

var dragon: Node = null

func _process_modification() -> void:
	if dragon and dragon.has_method("_apply_biomechanical_posture_to_skeleton"):
		dragon._apply_biomechanical_posture_to_skeleton(get_skeleton())
