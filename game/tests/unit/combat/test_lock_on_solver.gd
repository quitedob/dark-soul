# game/tests/unit/combat/test_lock_on_solver.gd
extends "res://addons/gut/test.gd"
## I-15：LockOnSolver 评分 / 循环排序 / 断锁距离

const LockOnSolver = preload("res://scripts/combat/lock_on_solver.gd")

const MAX_DIST := 18.0
const MAX_ANGLE := deg_to_rad(40.0)


## 更贴近画面中心的目标得分更高
func test_closest_to_camera_wins() -> void:
	var center := LockOnSolver.score_candidate(
		Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -10.0), MAX_DIST, MAX_ANGLE
	)
	var side := LockOnSolver.score_candidate(
		Vector3.ZERO, Vector3.FORWARD, Vector3(5.0, 0.0, -10.0), MAX_DIST, MAX_ANGLE
	)
	assert_false(center.is_empty())
	assert_false(side.is_empty())
	assert_gt(float(center["score"]), float(side["score"]), "中心目标应得分更高")


## 屏幕角排序：逆时针/递增角用于左循环
func test_cycle_left_selects_next_counterclockwise() -> void:
	var entries := [
		{"score": 0.5, "screen_angle": 1.0, "id": "right"},
		{"score": 0.5, "screen_angle": -1.0, "id": "left"},
		{"score": 0.5, "screen_angle": 0.0, "id": "center"},
	]
	entries.sort_custom(LockOnSolver.sort_by_screen_angle)
	assert_eq(entries[0]["id"], "left")
	assert_eq(entries[1]["id"], "center")
	assert_eq(entries[2]["id"], "right")
	# 从 center 向左（角度减小方向）→ left
	var current_idx := 1
	var next_idx := (current_idx - 1 + entries.size()) % entries.size()
	assert_eq(entries[next_idx]["id"], "left", "向左循环应落到更小 screen_angle")


## 超距 → 空字典（断锁）
func test_break_distance_releases_lock() -> void:
	var distant := LockOnSolver.score_candidate(
		Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, -20.0), MAX_DIST, MAX_ANGLE
	)
	assert_true(distant.is_empty(), "超距目标应被拒绝")


## FOV 外 / 无效近距不进评分（死亡排除在 world 层，此处测几何排除）
func test_out_of_fov_not_scored() -> void:
	var offscreen := LockOnSolver.score_candidate(
		Vector3.ZERO, Vector3.FORWARD, Vector3(12.0, 0.0, -1.0), MAX_DIST, MAX_ANGLE
	)
	assert_true(offscreen.is_empty(), "FOV 外目标不应得分")
	var too_close := LockOnSolver.score_candidate(
		Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, MAX_DIST, MAX_ANGLE
	)
	assert_true(too_close.is_empty(), "零距无效目标不应得分")


## 同分按 screen_angle 打破平局
func test_score_tie_breaks_by_screen_angle() -> void:
	var entries := [
		{"score": 0.5, "screen_angle": 1.0},
		{"score": 0.5, "screen_angle": -1.0},
		{"score": 0.8, "screen_angle": 0.0},
	]
	entries.sort_custom(LockOnSolver.sort_by_score_descending)
	assert_almost_eq(float(entries[0]["score"]), 0.8, 0.001)
	assert_almost_eq(float(entries[1]["screen_angle"]), -1.0, 0.001)
