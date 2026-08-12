extends SceneTree
## L-23 合约：相机系统（combat_camera_director.gd / camera_shot_profile.gd /
## phase_focus_profile.gd）。
## 1) 镜头库 schema：6 个 shot 全部可构造、validate 无错、数值区间合法。
## 2) CombatCameraDirector 信号触发：play_shot_id 命中 → shot_started / active /
##    camera override；release → shot_finished / override 复位。
## 3) 未知 shot id / 无 player 均拒绝且不崩溃。
## 4) reduced_motion 打开时释放进行中的镜头并触发 shot_finished。
## 5) 相变镜头映射（phase_focus_profile）与 trauma 递进。

const DirectorScript = preload("res://scripts/combat/combat_camera_director.gd")
const ShotCatalogScript = preload("res://scripts/combat/data/camera_shot_profile.gd")
const PhaseFocusScript = preload("res://scripts/camera/phase_focus_profile.gd")

var _failures: Array[String] = []


class MockPlayer:
	extends Node3D
	var spring_arm: SpringArm3D
	var camera_pitch: Node3D
	var camera: Camera3D
	var camera_rig: Node3D
	var director_override := false

	func set_camera_director_override(enabled: bool) -> void:
		director_override = enabled


func _init() -> void:
	_test_shot_catalog_schema()
	_test_director_signal_emission()
	_test_director_unknown_shot_rejected()
	_test_director_without_player_rejected()
	_test_reduced_motion_release()
	_test_phase_focus_profiles()
	if _failures.is_empty():
		print("ASHEN_CAMERA_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_shot_catalog_schema() -> void:
	var catalog: Dictionary = ShotCatalogScript.catalog()
	_expect(catalog.size() == 6, "Camera shot catalog must have 6 shots, got %d." % catalog.size())
	for shot_id: StringName in catalog:
		var profile = catalog[shot_id]
		_expect(profile is CameraShotProfile, "Catalog entry %s must be a CameraShotProfile." % shot_id)
		if not (profile is CameraShotProfile):
			continue
		_expect(profile.shot_id == shot_id, "Profile shot_id must match its catalog key.")
		_expect(profile.duration > 0.0, "Shot %s must have positive duration." % shot_id)
		_expect(profile.spring_length > 0.0, "Shot %s must have positive spring length." % shot_id)
		_expect(profile.blend_in > 0.0, "Shot %s must have positive blend-in." % shot_id)
		_expect(profile.validate().is_empty(), "Shot %s must validate clean." % shot_id)


func _test_director_signal_emission() -> void:
	var mock := MockPlayer.new()
	root.add_child(mock)
	var spring := SpringArm3D.new()
	spring.spring_length = 5.2
	mock.add_child(spring)
	mock.spring_arm = spring
	var pitch := Node3D.new()
	mock.add_child(pitch)
	mock.camera_pitch = pitch
	var cam := Camera3D.new()
	cam.fov = 75.0
	mock.add_child(cam)
	mock.camera = cam
	var rig := Node3D.new()
	mock.add_child(rig)
	mock.camera_rig = rig

	var director = DirectorScript.new()
	root.add_child(director)
	director.setup(mock, null)
	var started: Array[StringName] = []
	var finished: Array[StringName] = []
	director.shot_started.connect(func(shot_id: StringName): started.append(shot_id))
	director.shot_finished.connect(func(shot_id: StringName): finished.append(shot_id))

	_expect(director.play_shot_id(&"weak_point_expose", null), "Known camera shot must be accepted.")
	_expect(director.active, "Director must become active after a shot.")
	_expect(
		started.size() == 1 and started[0] == &"weak_point_expose",
		"shot_started must emit the shot id once."
	)
	_expect(mock.director_override, "Director must set camera override while a shot is active.")

	director.release()
	_expect(not director.active, "release must deactivate the director.")
	_expect(
		finished.size() == 1 and finished[0] == &"weak_point_expose",
		"shot_finished must emit the shot id once."
	)
	_expect(not mock.director_override, "Director must clear camera override after release.")
	director.free()
	mock.free()


func _test_director_unknown_shot_rejected() -> void:
	var director = DirectorScript.new()
	root.add_child(director)
	_expect(not director.play_shot_id(&"no_such_shot", null), "Unknown shot id must be rejected.")
	_expect(not director.active, "Rejected shot must not activate the director.")
	director.free()


func _test_director_without_player_rejected() -> void:
	var director = DirectorScript.new()
	root.add_child(director)
	var profile = ShotCatalogScript.catalog()[&"grab_hold"]
	_expect(not director.play_shot(profile, null), "Shot without a player must be rejected.")
	director.free()


func _test_reduced_motion_release() -> void:
	var mock := MockPlayer.new()
	root.add_child(mock)
	var director = DirectorScript.new()
	root.add_child(director)
	director.setup(mock, null)
	var finished: Array[StringName] = []
	director.shot_finished.connect(func(shot_id: StringName): finished.append(shot_id))
	_expect(director.play_shot_id(&"fate_halfbody", null), "Fate shot must be accepted.")
	_expect(director.active, "Director must be active before reduced motion.")
	director.set_reduced_motion(true)
	_expect(not director.active, "Reduced motion must release an active shot.")
	_expect(finished.has(&"fate_halfbody"), "Reduced-motion release must emit shot_finished.")
	director.free()
	mock.free()


func _test_phase_focus_profiles() -> void:
	var rise = PhaseFocusScript.shot_for_phase(2)
	var overload = PhaseFocusScript.shot_for_phase(3)
	var default_shot = PhaseFocusScript.shot_for_phase(1)
	_expect(rise.shot_id == &"phase_rise", "Phase 2 must map to phase_rise.")
	_expect(overload.shot_id == &"phase_overload", "Phase 3 must map to phase_overload.")
	_expect(default_shot.shot_id == &"phase_rise", "Phase 1 must default to phase_rise.")
	_expect(
		float(overload.trauma) > float(rise.trauma),
		"Phase 3 shot must escalate trauma over phase 2."
	)
	_expect(
		PhaseFocusScript.focus_offset_for_phase(3) == Vector3(0.0, 2.35, 0.0),
		"Phase 3 focus offset changed."
	)
	_expect(
		PhaseFocusScript.focus_offset_for_phase(1) == Vector3(0.0, 1.95, 0.0),
		"Phase 1 focus offset changed."
	)
	var catalog: Dictionary = PhaseFocusScript.catalog()
	_expect(
		catalog.has(&"phase_rise") and catalog.has(&"phase_overload"),
		"Phase catalog must expose both phase shots."
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
