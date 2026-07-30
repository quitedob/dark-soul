extends SceneTree

const HitStopManagerScript = preload("res://scripts/combat/hit_stop_manager.gd")
const TraumaShakeScript = preload("res://scripts/components/trauma_shake.gd")

class FreezeProbe extends Node:
	var frozen := false
	func set_visual_frozen(value: bool) -> void:
		frozen = value

var _failures: Array[String] = []


func _init() -> void:
	_test_hit_stop()
	_test_trauma()
	if _failures.is_empty():
		print("ASHEN_FEEDBACK_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_hit_stop() -> void:
	var manager = HitStopManagerScript.new()
	var source := FreezeProbe.new()
	var target := FreezeProbe.new()
	root.add_child(manager)
	root.add_child(source)
	root.add_child(target)
	var original_scale := Engine.time_scale
	manager.trigger(source, target, 0.08, 60.0)
	_expect(source.frozen and target.frozen, "Hit-stop did not freeze both visual probes.")
	_expect(is_equal_approx(Engine.time_scale, original_scale), "Hit-stop changed global time scale.")
	for frame in range(5):
		manager._physics_process(1.0 / 60.0)
	_expect(not source.frozen and not target.frozen, "Hit-stop did not restore visual probes after five frames.")
	manager.free()
	source.free()
	target.free()


func _test_trauma() -> void:
	var camera := Camera3D.new()
	var shake = TraumaShakeScript.new()
	root.add_child(camera)
	root.add_child(shake)
	shake.setup(camera)
	var base := camera.transform
	shake.inject(0.8)
	shake._process(0.016)
	_expect(shake.trauma > 0.0 and shake.trauma < 0.8, "Trauma did not decay smoothly.")
	_expect(camera.transform != base, "Trauma did not affect the camera transform.")
	shake.set_settings(false, 1.0)
	_expect(is_zero_approx(shake.trauma), "Disabling shake did not clear trauma.")
	_expect(camera.transform.is_equal_approx(base), "Disabling shake did not restore the camera.")
	shake.inject(1.0)
	_expect(is_zero_approx(shake.trauma), "Disabled shake accepted trauma.")
	shake.free()
	camera.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
