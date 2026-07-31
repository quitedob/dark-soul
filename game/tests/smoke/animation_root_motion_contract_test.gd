extends SceneTree
## Wave3 动画链合约：D-01~D-06 + D-07 Grab 回归

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")
const ExecDirector = preload("res://scripts/combat/execution_paired_director.gd")
const ExecProfile = preload("res://scripts/combat/data/execution_profile.gd")
const GrabDirector = preload("res://scripts/combat/grab_paired_director.gd")
const GrabProfileScript = preload("res://scripts/combat/data/grab_profile.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_d01_animation_tree()
	_test_d02_root_motion_api()
	_test_d03_strafe_blendspace()
	_test_d05_leap_root_track()
	_test_d08_callback_bridge()
	_test_d06_execution_director()
	_test_d07_grab_still_works()
	if _failures.is_empty():
		print("ASHEN_ANIMATION_ROOT_MOTION_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_d01_animation_tree() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "D-01: bridge must enable.")
	_expect(bridge.skeleton != null, "D-01: RootMotionSkeleton required.")
	_expect(bridge.anim_tree != null, "D-01: AnimationTree required.")
	_expect(bridge.anim_player != null, "D-01: AnimationPlayer required.")
	_expect(bridge.is_physics_callback(), "D-01/D-04: Physics callback required.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "D-01: light root track ~0.55m.")
	var track_path: NodePath = bridge.anim_tree.root_motion_track
	_expect(not track_path.is_empty(), "D-01: root_motion_track must be set.")
	body.queue_free()


func _test_d02_root_motion_api() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	bridge.travel_light_attack()
	# API 可调用（headless 首帧可能为零位移）
	var pos: Vector3 = bridge.consume_root_motion()
	var rot: Quaternion = bridge.consume_root_motion_rotation()
	_expect(pos is Vector3, "D-02: get_root_motion_position wired.")
	_expect(rot is Quaternion, "D-02: get_root_motion_rotation wired.")
	body.queue_free()


func _test_d03_strafe_blendspace() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.has_strafe_blendspace(), "D-03: Strafe BlendSpace2D node missing.")
	bridge.travel_locomotion(true, true, Vector2(0.7, 0.2))
	var blend = bridge.anim_tree.get("parameters/Strafe/blend_position")
	_expect(blend is Vector2, "D-03: blend_position must be Vector2.")
	_expect(Vector2(blend).distance_to(Vector2(0.7, 0.2)) < 0.01, "D-03: blend param not applied.")
	body.queue_free()


func _test_d05_leap_root_track() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.sample_leap_root_delta() >= 2.0, "D-05: colossal leap root forward >= 2m.")
	bridge.travel_leap(false)
	body.queue_free()


## D-08：method-track 回调钩子可触发信号；不改 state_time 权威
func _test_d08_callback_bridge() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.has_method("anim_event_hitbox_on"), "D-08: hitbox_on hook missing.")
	_expect(bridge.has_method("anim_event_combo_open"), "D-08: combo_open hook missing.")
	_expect(bridge.has_timing_method_tracks, "D-08: light attack should stamp method tracks.")
	var hit_on := [false]
	var combo_on := [false]
	var impulse := [0.0]
	bridge.hitbox_activated.connect(func(): hit_on[0] = true)
	bridge.combo_window_opened.connect(func(): combo_on[0] = true)
	bridge.forward_impulse_requested.connect(func(a): impulse[0] = a)
	bridge.anim_event_hitbox_on()
	bridge.anim_event_combo_open()
	bridge.anim_event_push_forward(0.35)
	_expect(hit_on[0], "D-08: hitbox_activated signal missing.")
	_expect(combo_on[0], "D-08: combo_window_opened signal missing.")
	_expect(is_equal_approx(float(impulse[0]), 0.35), "D-08: forward impulse arg missing.")
	bridge.set_speed_scale(0.45)
	_expect(is_equal_approx(bridge.anim_player.speed_scale, 0.45), "D-08: speed_scale not applied.")
	body.queue_free()


func _test_d06_execution_director() -> void:
	var initiator := _StubBody.new()
	var victim := _StubVictim.new()
	root.add_child(initiator)
	root.add_child(victim)
	initiator.global_position = Vector3(0, 0, 1.5)
	victim.global_position = Vector3.ZERO
	victim.health = 100.0
	var profile = ExecProfile.make_riposte()
	profile.damage_event_seconds = 0.05
	profile.windup_seconds = 0.1
	profile.active_seconds = 0.2
	profile.recovery_seconds = 0.2
	_expect(victim.try_claim_execution(initiator, 2.0), "D-06: first claim ok.")
	_expect(not victim.try_claim_execution(_StubBody.new(), 2.0), "D-06: exclusive claim.")
	var director = ExecDirector.new()
	_expect(director.begin(initiator, victim, profile, &"parry", null, true), "D-06: director begin.")
	_expect(director.active, "D-06: director active.")
	director.update_pose(0.1)
	var hp := float(victim.health)
	_expect(not director.try_damage_event(0.0), "D-06: damage before event.")
	_expect(director.try_damage_event(0.1, 15.0), "D-06: damage at event.")
	_expect(float(victim.health) < hp, "D-06: event damage applied.")
	_expect(not director.try_damage_event(0.2, 15.0), "D-06: single-fire damage.")
	director.force_cancel(&"test")
	_expect(not director.active, "D-06: cancel clears active.")
	_expect(victim.claimer == null, "D-06: cancel releases claim.")
	initiator.queue_free()
	victim.queue_free()


func _test_d07_grab_still_works() -> void:
	# D-07 DONE：仅验证 Grab 框架仍可用，不破坏
	var initiator := _StubBody.new()
	var victim := _StubGrabVictim.new()
	root.add_child(initiator)
	root.add_child(victim)
	initiator.global_position = Vector3.ZERO
	victim.global_position = Vector3(0, 0, -1.2)
	victim.health = 100.0
	var profile = GrabProfileScript.make_boss_default()
	profile.hold_seconds = 0.4
	profile.damage_event_seconds = 0.08
	profile.grab_damage = 10.0
	var director = GrabDirector.new()
	_expect(director.begin(initiator, victim, profile), "D-07: grab begin.")
	director.update(0.1)
	_expect(director.damage_done, "D-07: grab damage event.")
	director.force_cancel(&"verify")
	_expect(not director.active, "D-07: grab cancel.")
	_expect(not victim.grabbed, "D-07: grab release.")
	initiator.queue_free()
	victim.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


class _StubBody extends CharacterBody3D:
	var health := 100.0


class _StubVictim extends CharacterBody3D:
	var health := 100.0
	var claimer: Node = null
	var claim_time := 0.0

	func is_targetable() -> bool:
		return health > 0.0

	func try_claim_execution(c: Node, duration: float = 2.8) -> bool:
		if claimer != null and is_instance_valid(claimer) and claimer != c:
			return false
		claimer = c
		claim_time = duration
		return true

	func release_execution_claim(c: Node = null) -> void:
		if c != null and claimer != c:
			return
		claimer = null
		claim_time = 0.0

	func apply_execution_damage(amount: float, _allow_lethal: bool = true) -> void:
		health = maxf(health - amount, 0.0)

	func get_execution_anchor(_anchor: StringName) -> Vector3:
		return global_position + Vector3.UP * 1.1


class _StubGrabVictim extends CharacterBody3D:
	var health := 100.0
	var grabbed := false

	func is_targetable() -> bool:
		return health > 0.0

	func begin_grabbed(_grabber: Node, _duration: float = 1.4) -> void:
		grabbed = true

	func end_grabbed(_grabber: Node = null) -> void:
		grabbed = false

	func set_grab_pose_lock(_locked: bool) -> void:
		pass

	func receive_hit(amount, _stagger, _dir, _src) -> void:
		health = maxf(health - float(amount), 0.0)
