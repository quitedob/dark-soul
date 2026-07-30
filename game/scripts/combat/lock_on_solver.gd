class_name LockOnSolver
extends RefCounted


static func score_candidate(
	camera_position: Vector3,
	camera_forward: Vector3,
	target_position: Vector3,
	max_distance: float,
	max_angle_radians: float
) -> Dictionary:
	var offset := target_position - camera_position
	var distance := offset.length()
	if distance < 0.01 or distance > max_distance:
		return {}
	var forward := camera_forward.normalized()
	var direction := offset / distance
	var dot_product := clampf(forward.dot(direction), -1.0, 1.0)
	var angle := acos(dot_product)
	if angle > max_angle_radians:
		return {}
	var angle_score := 1.0 - angle / max_angle_radians
	var distance_factor := 1.0 / (1.0 + distance * 0.1)
	return {
		"score": angle_score * distance_factor,
		"angle": angle,
		"distance": distance,
		"dot": dot_product,
	}


static func screen_angle(camera: Camera3D, target_position: Vector3) -> float:
	var screen_position := camera.unproject_position(target_position)
	var viewport_center := camera.get_viewport().get_visible_rect().size * 0.5
	var offset := screen_position - viewport_center
	return atan2(offset.y, offset.x)


static func sort_by_score_descending(left: Dictionary, right: Dictionary) -> bool:
	if is_equal_approx(float(left["score"]), float(right["score"])):
		return float(left["screen_angle"]) < float(right["screen_angle"])
	return float(left["score"]) > float(right["score"])


static func sort_by_screen_angle(left: Dictionary, right: Dictionary) -> bool:
	return float(left["screen_angle"]) < float(right["screen_angle"])
