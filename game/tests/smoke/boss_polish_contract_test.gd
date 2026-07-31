extends SceneTree
## Boss 打磨合约：抓投配对 / 专属镜头 / 命运旗标 / G-04 相变抛光

const GrabDirector = preload("res://scripts/combat/grab_paired_director.gd")
const GrabProfileScript = preload("res://scripts/combat/data/grab_profile.gd")
const ShotCatalog = preload("res://scripts/combat/data/camera_shot_profile.gd")
const CameraDirector = preload("res://scripts/combat/combat_camera_director.gd")
const FateCatalog = preload("res://scripts/combat/data/boss_fate_catalog.gd")
const RunStateScript = preload("res://scripts/core/run_state.gd")
const PhaseFocusProfile = preload("res://scripts/camera/phase_focus_profile.gd")
const ArenaPhaseVfxScript = preload("res://scripts/fx/arena_phase_vfx.gd")
const BossPhasePolisherScript = preload("res://scripts/boss/boss_phase_polisher.gd")
const Chapter1Content = preload("res://scripts/data/chapter_1_content.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_grab_director()
	_test_camera_shots()
	_test_fate_catalog_and_run_state()
	_test_phase_transition_polish()
	if _failures.is_empty():
		print("ASHEN_BOSS_POLISH_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_grab_director() -> void:
	var initiator := _StubBody.new()
	var victim := _StubVictim.new()
	root.add_child(initiator)
	root.add_child(victim)
	initiator.global_position = Vector3.ZERO
	victim.global_position = Vector3(0, 0, -1.2)
	victim.health = 100.0
	var profile = GrabProfileScript.make_boss_default()
	profile.hold_seconds = 0.5
	profile.damage_event_seconds = 0.1
	profile.grab_damage = 12.0
	var director = GrabDirector.new()
	_expect(director.begin(initiator, victim, profile), "Grab director should begin.")
	_expect(director.active, "Grab should be active.")
	_expect(victim.grabbed, "Victim must enter grabbed.")
	var hp_before := float(victim.health)
	director.update(0.12)
	_expect(director.damage_done, "Damage event must fire once.")
	_expect(float(victim.health) < hp_before, "Grab must deal damage.")
	director.update(0.12)
	_expect(director.damage_done, "Damage must stay single-fire.")
	director.update(0.5)
	_expect(not director.active, "Hold end should finish director.")
	director.begin(initiator, victim, profile)
	director.force_cancel(&"test")
	_expect(not director.active, "Cancel must clear active.")
	_expect(not victim.grabbed, "Cancel must release grabbed.")
	initiator.queue_free()
	victim.queue_free()


func _test_camera_shots() -> void:
	var catalog: Dictionary = ShotCatalog.catalog()
	for shot_id in [&"weak_point_expose", &"weak_point_exec", &"grab_hold", &"fate_halfbody", &"phase_rise", &"phase_overload"]:
		_expect(catalog.has(shot_id), "Missing shot %s" % shot_id)
		_expect(catalog[shot_id].validate().is_empty(), "Invalid shot %s" % shot_id)
	var player := _StubCameraPlayer.new()
	root.add_child(player)
	player.build()
	var director = CameraDirector.new()
	root.add_child(director)
	director.setup(player, null)
	director.set_reduced_motion(true)
	var subject := Node3D.new()
	root.add_child(subject)
	subject.global_position = Vector3(0, 0, -3)
	_expect(director.play_shot_id(&"weak_point_expose", subject), "Expose shot should play.")
	_expect(director.active, "Director active after play.")
	_expect(player.camera_override, "Override flag set.")
	director.release()
	_expect(not director.active, "Release must clear override.")
	_expect(not player.camera_override, "Override flag cleared.")
	player.queue_free()
	subject.queue_free()
	director.queue_free()


func _test_fate_catalog_and_run_state() -> void:
	var flags := [
		&"ch1_guardian_fate", &"ch2_xingtian_fate", &"ch3_nine_tails_fate",
		&"ch4_xuanxiao_fate", &"ending_state"
	]
	for flag in flags:
		var entry: Dictionary = FateCatalog.entry_for_flag(flag)
		_expect(not entry.is_empty(), "Missing fate entry %s" % flag)
		var options: Array = entry.get("options", [])
		_expect(options.size() >= 2, "Fate %s needs >=2 options." % flag)
		var first_id := String(options[0].get("id", ""))
		_expect(FateCatalog.is_valid_choice(flag, first_id), "Choice %s invalid for %s" % [first_id, flag])
	var state = RunStateScript.new()
	state.set_choice_flag(&"ch1_guardian_fate", "released")
	state.set_choice_flag(&"legacy_bool", true)
	_expect(String(state.get_choice_flag(&"ch1_guardian_fate")) == "released", "String fate flag round-trip.")
	_expect(bool(state.get_choice_flag(&"legacy_bool")) == true, "Bool legacy flag kept.")
	var encoded := state.to_dictionary()
	var decoded = RunStateScript.from_dictionary(encoded)
	_expect(decoded != null, "RunState must accept string choice_flags.")
	_expect(String(decoded.choice_flags.get("ch1_guardian_fate", "")) == "released", "Decoded string fate.")
	_expect(bool(decoded.choice_flags.get("legacy_bool", false)), "Decoded bool fate.")


func _test_phase_transition_polish() -> void:
	# G-04：相变镜头配置 / 场地 VFX / 抛光编排
	var phase_catalog: Dictionary = PhaseFocusProfile.catalog()
	_expect(phase_catalog.has(&"phase_rise"), "phase_rise profile missing.")
	_expect(phase_catalog.has(&"phase_overload"), "phase_overload profile missing.")
	var rise = PhaseFocusProfile.shot_for_phase(2)
	var overload = PhaseFocusProfile.shot_for_phase(3)
	_expect(rise != null and rise.validate().is_empty(), "phase 2 shot invalid.")
	_expect(overload != null and overload.validate().is_empty(), "phase 3 shot invalid.")
	_expect(PhaseFocusProfile.focus_offset_for_phase(2).y > 1.0, "phase 2 focus offset too low.")
	_expect(PhaseFocusProfile.focus_offset_for_phase(3).y > PhaseFocusProfile.focus_offset_for_phase(2).y, "phase 3 should raise focus.")

	var boss_content: Dictionary = Chapter1Content.boss()
	var phases: Dictionary = boss_content.get("phases", {})
	_expect(phases.has("2"), "Chapter1 boss needs phase 2 content.")
	_expect(String(phases["2"].get("vfx", "")) != "", "Phase 2 vfx key missing.")

	var player := _StubCameraPlayer.new()
	root.add_child(player)
	player.build()
	var cam = CameraDirector.new()
	root.add_child(cam)
	cam.setup(player, null)

	var polisher = BossPhasePolisherScript.new()
	root.add_child(polisher)
	polisher.setup(cam)

	var boss := _StubBoss.new()
	root.add_child(boss)
	boss.build()
	boss.global_position = Vector3(0, 0, -4)
	boss.chapter_content = boss_content
	boss.guardian = true

	polisher.play_transition(boss, 2)
	_expect(cam.active, "Phase polish must drive camera director.")
	_expect(player.camera_override, "Phase camera override required.")
	# 场地 VFX 根节点应挂到世界
	var vfx_nodes := 0
	for child in root.get_children():
		if String(child.name).begins_with("ArenaPhaseVfx"):
			vfx_nodes += 1
	_expect(vfx_nodes >= 1, "Arena phase VFX must spawn.")

	# 姿态混合：缩放应被 tween 拉开
	_expect(boss.visual_root != null, "Boss visual_root required for blend.")
	polisher.reset()
	_expect(not cam.active, "Polisher reset must release camera.")

	# 独立 VFX 单元：phase 3 过载柱
	var vfx = ArenaPhaseVfxScript.new()
	root.add_child(vfx)
	vfx.play_at(Vector3(1, 0, -2), 3, "orange_ember_trails", root)
	var found_overload := false
	for child in root.get_children():
		if String(child.name).begins_with("ArenaPhaseVfx_P3"):
			found_overload = child.find_child("OverloadColumn", true, false) != null
	_expect(found_overload, "Phase 3 overload column missing.")

	boss.queue_free()
	player.queue_free()
	cam.queue_free()
	polisher.queue_free()
	vfx.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class _StubBody extends CharacterBody3D:
	var health := 200.0


class _StubVictim extends CharacterBody3D:
	var health := 100.0
	var grabbed := false
	var pose_lock := false

	func is_targetable() -> bool:
		return health > 0.0

	func begin_grabbed(_grabber: Node, _duration: float = 1.4) -> void:
		grabbed = true

	func end_grabbed(_grabber: Node = null) -> void:
		grabbed = false
		pose_lock = false

	func set_grab_pose_lock(locked: bool) -> void:
		pose_lock = locked

	func receive_hit(damage, _stagger, _dir, _source) -> void:
		health = maxf(health - float(damage), 0.0)


class _StubCameraPlayer extends Node3D:
	var camera_rig: Node3D
	var camera_pitch: Node3D
	var spring_arm: SpringArm3D
	var camera: Camera3D
	var camera_override := false

	func build() -> void:
		camera_rig = Node3D.new()
		add_child(camera_rig)
		camera_pitch = Node3D.new()
		camera_rig.add_child(camera_pitch)
		spring_arm = SpringArm3D.new()
		spring_arm.spring_length = 5.2
		camera_pitch.add_child(spring_arm)
		camera = Camera3D.new()
		camera.fov = 75.0
		spring_arm.add_child(camera)

	func set_camera_director_override(active: bool) -> void:
		camera_override = active


class _StubBoss extends CharacterBody3D:
	var guardian := true
	var chapter_content: Dictionary = {}
	var visual_root: Node3D
	var weapon_pivot: Node3D
	var weapon_material: StandardMaterial3D
	var body_material: StandardMaterial3D

	func build() -> void:
		visual_root = Node3D.new()
		visual_root.name = "Visuals"
		visual_root.scale = Vector3.ONE * 1.22
		add_child(visual_root)
		weapon_pivot = Node3D.new()
		weapon_pivot.name = "WeaponPivot"
		visual_root.add_child(weapon_pivot)
		weapon_material = StandardMaterial3D.new()
		body_material = StandardMaterial3D.new()

	func get_target_point() -> Vector3:
		return global_position + Vector3.UP * 1.4
