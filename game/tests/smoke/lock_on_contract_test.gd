extends SceneTree

const LockOnSolverScript = preload("res://scripts/combat/lock_on_solver.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_center_priority()
	_test_fov_and_distance_rejection()
	_test_deterministic_ordering()
	if _failures.is_empty():
		print("ASHEN_LOCK_ON_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_center_priority() -> void:
	var center := LockOnSolverScript.score_candidate(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -10.0), 18.0, deg_to_rad(40.0))
	var side := LockOnSolverScript.score_candidate(Vector3.ZERO, Vector3.FORWARD, Vector3(5.0, 0.0, -10.0), 18.0, deg_to_rad(40.0))
	_expect(not center.is_empty() and not side.is_empty(), "Visible lock-on candidates were rejected.")
	_expect(float(center.get("score", 0.0)) > float(side.get("score", 0.0)), "Screen-center target did not receive the higher score.")


func _test_fov_and_distance_rejection() -> void:
	var offscreen := LockOnSolverScript.score_candidate(Vector3.ZERO, Vector3.FORWARD, Vector3(12.0, 0.0, -1.0), 18.0, deg_to_rad(40.0))
	var distant := LockOnSolverScript.score_candidate(Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -20.0), 18.0, deg_to_rad(40.0))
	_expect(offscreen.is_empty(), "Off-FOV target was accepted.")
	_expect(distant.is_empty(), "Out-of-range target was accepted.")


func _test_deterministic_ordering() -> void:
	var entries := [
		{"score": 0.5, "screen_angle": 1.0},
		{"score": 0.5, "screen_angle": -1.0},
		{"score": 0.8, "screen_angle": 0.0},
	]
	entries.sort_custom(LockOnSolverScript.sort_by_score_descending)
	_expect(float(entries[0]["score"]) == 0.8, "Highest score was not selected first.")
	_expect(float(entries[1]["screen_angle"]) == -1.0, "Score tie was not resolved by screen angle.")
	entries.sort_custom(LockOnSolverScript.sort_by_screen_angle)
	_expect(float(entries[0]["screen_angle"]) == -1.0 and float(entries[2]["screen_angle"]) == 1.0, "Screen-angle cycling order is unstable.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
