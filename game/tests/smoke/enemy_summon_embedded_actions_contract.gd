extends SceneTree
## Requires the published action manifest and imported animated GLBs.
## Run after parent import: --headless --path game --script tests/smoke/enemy_summon_embedded_actions_contract.gd

const EnemyScript = preload("res://scripts/enemy.gd")
const SummonScript = preload("res://scripts/combat/spirit_summon.gd")
const EmbeddedActions = preload("res://scripts/core/embedded_model_actions.gd")
const Chapter3Content = preload("res://scripts/data/chapter_3_content.gd")

class SummonOwner extends Node3D:
	var focus_regen_multiplier := 1.0
	var healed := 0.0
	var hits := 0

	func heal(amount: float) -> void:
		healed += amount

	func receive_hit(_damage: float, _stagger: float, _direction: Vector3, _source: Node) -> void:
		hits += 1

class ExecutorProbe extends RefCounted:
	var active_calls := 0
	var recovery_calls := 0

	func execute_active(_attacker: Node3D, _target: Node3D, _profile: Dictionary) -> void:
		active_calls += 1

	func execute_recovery(_attacker: Node3D, _target: Node3D, _profile: Dictionary) -> void:
		recovery_calls += 1

var _failures: Array[String] = []
var _stage: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_stage = Node3D.new()
	root.add_child(_stage)
	_test_enemy()
	_test_summon_actions()
	await _test_summon_death()
	_test_instant_cleanup()
	_stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("ASHEN_ENEMY_SUMMON_EMBEDDED_ACTIONS_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _make_enemy() -> Variant:
	var content: Dictionary = {}
	for entry: Dictionary in Chapter3Content.enemies():
		if String(entry.get("id", "")) == "maze_guardian":
			content = entry
	_expect(not content.is_empty(), "Maze Guardian fixture content missing")
	var enemy: Variant = EnemyScript.new()
	enemy.setup_from_content(null, null, null, Vector3.ZERO, content, false)
	_stage.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy


func _make_summon(kind: StringName, owner: Node3D) -> Variant:
	var summon: Variant = SummonScript.new()
	summon.setup(kind, owner, _stage)
	_stage.add_child(summon)
	summon.set_process(false)
	return summon


func _player_for(visual: Node) -> AnimationPlayer:
	if not EmbeddedActions.available(visual):
		_expect(false, "Embedded binding missing: publish manifest and import animated fixtures first")
		return null
	for node: Node in visual.find_children("*", "AnimationPlayer", true, false):
		var player: AnimationPlayer = node as AnimationPlayer
		if player.active and not player.assigned_animation.is_empty():
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.advance(0.0)
			return player
	_expect(false, "Bound visual has no active AnimationPlayer")
	return null


func _clip(player: AnimationPlayer) -> String:
	return String(player.assigned_animation).get_file()


func _expect_cursor(player: AnimationPlayer, before: float, message: String) -> void:
	_expect(is_equal_approx(player.current_animation_position, before), message)


func _test_enemy() -> void:
	var enemy: Variant = _make_enemy()
	var player: AnimationPlayer = _player_for(enemy.body_visual_root)
	if player == null:
		enemy.queue_free()
		return
	_expect(_clip(player) == "idle", "Enemy reset did not select idle")
	player.advance(0.12)
	var cursor: float = player.current_animation_position
	for _i in range(8):
		enemy._update_embedded_movement()
	_expect_cursor(player, cursor, "Repeated idle restarted/reset the clip")
	enemy._change_state(enemy.State.ACTIVE, 0.2)
	_expect(enemy.state == enemy.State.IDLE, "Rejected IDLE -> ACTIVE changed gameplay state")
	_expect_cursor(player, cursor, "Rejected transition changed the animation")

	enemy.velocity = Vector3(3.0, 0.0, 0.0)
	enemy._change_state(enemy.State.CHASE)
	player.advance(0.0)
	_expect(_clip(player) in ["walk", "run", "trot", "move"], "Moving chase did not choose locomotion")
	player.advance(0.1)
	cursor = player.current_animation_position
	for _i in range(8):
		enemy._update_embedded_movement()
	_expect_cursor(player, cursor, "Repeated chase restarted locomotion")
	enemy._change_state(enemy.State.RETURN)
	_expect(_clip(player) == "walk", "RETURN did not request walk")
	enemy.velocity = Vector3.ZERO
	enemy._update_embedded_movement()
	_expect(_clip(player) == "idle", "Stationary RETURN did not request idle")

	enemy.attack_active = 0.2
	enemy.attack_recovery = 0.3
	enemy._change_state(enemy.State.WINDUP, 0.5)
	player.advance(0.12)
	_expect(_clip(player) == "attack", "WINDUP did not start attack")
	_expect(is_equal_approx(player.speed_scale, player.get_animation(player.assigned_animation).length),
		"Attack duration did not span windup + active + recovery (1 second)")
	_expect(enemy._vfx_emitted, "Embedded attack suppressed WINDUP ember VFX")
	cursor = player.current_animation_position
	enemy._change_state(enemy.State.WINDUP, 0.5)
	_expect_cursor(player, cursor, "Same WINDUP restarted the attack")
	enemy._change_state(enemy.State.ACTIVE, 0.2)
	_expect_cursor(player, cursor, "ACTIVE restarted the WINDUP clip")
	enemy._change_state(enemy.State.RECOVERY, 0.3)
	_expect_cursor(player, cursor, "RECOVERY restarted the WINDUP clip")
	enemy._change_state(enemy.State.CHASE)
	_expect(_clip(player) == "attack", "Loop request interrupted an unfinished attack")
	player.advance(2.0)
	_expect(_clip(player) == "idle", "Queued stationary loop was not restored")

	var executor := ExecutorProbe.new()
	enemy.guardian = true
	enemy._boss_attack_executor = executor
	enemy._active_attack_profile = {"type": "radial_aoe", "damage": 17.0}
	enemy._change_state(enemy.State.WINDUP, 0.5)
	player.advance(0.1)
	_expect(_clip(player) == "stone_stomp", "Custom boss attack did not use manifest special")
	cursor = player.current_animation_position
	enemy._change_state(enemy.State.ACTIVE, 0.2)
	enemy._change_state(enemy.State.RECOVERY, 0.3)
	_expect_cursor(player, cursor, "Boss executor phases restarted special")
	_expect(executor.active_calls == 1 and executor.recovery_calls == 1, "Boss executor hooks changed")
	_expect(enemy._active_attack_profile == {"type": "radial_aoe", "damage": 17.0}, "Attack profile mutated")
	enemy.guardian = false

	for reaction in [enemy.State.STAGGER, enemy.State.PARRY_VULNERABLE,
			enemy.State.GUARD_BROKEN, enemy.State.WEAK_POINT_EXPOSED]:
		enemy._change_state(reaction, 0.6)
		player.advance(0.05)
		_expect(_clip(player) == "hit", "Accepted reaction did not play hit")
	var speed: float = player.speed_scale
	cursor = player.current_animation_position
	var state_time: float = enemy.state_time
	enemy.set_visual_frozen(true)
	enemy._physics_process(0.1)
	player.advance(0.25)
	_expect_cursor(player, cursor, "Frozen animation advanced")
	_expect(is_zero_approx(player.speed_scale) and enemy.state_time == state_time, "Frozen FSM or speed advanced")
	enemy.set_visual_frozen(false)
	_expect(is_equal_approx(player.speed_scale, speed), "Thaw lost duration scaling")
	player.advance(0.05)
	_expect(player.current_animation_position > cursor, "Thawed animation did not resume")

	var skeleton: Skeleton3D = enemy._get_enemy_skeleton()
	if skeleton != null and skeleton.find_bone("spine") >= 0:
		var spine: int = skeleton.find_bone("spine")
		var rotation: Quaternion = skeleton.get_bone_pose_rotation(spine)
		enemy._apply_rig_idle_sway(0.4)
		_expect(skeleton.get_bone_pose_rotation(spine).is_equal_approx(rotation), "Procedural sway overwrote embedded bones")
	else:
		_expect(false, "Fixture is missing its embedded spine")
	var model: Node3D = enemy.body_visual_root.get_node("ModelRoot") as Node3D
	var rest: Transform3D = model.transform
	enemy._real_model_idle_vfx(0.2)
	_expect(model.transform.is_equal_approx(rest), "ModelFx moved the embedded body wrapper")

	enemy._die()
	_expect(_clip(player) == "death" and enemy._embedded_death_playing, "Death was skipped by the DEAD early return")
	_expect(is_zero_approx(enemy.visual_root.rotation.z), "Embedded corpse received procedural tilt")
	player.advance(player.get_animation(player.assigned_animation).length + 0.1)
	cursor = player.current_animation_position
	enemy._change_state(enemy.State.CHASE)
	enemy._update_embedded_movement()
	EmbeddedActions.play_action(enemy.body_visual_root, "idle")
	player.advance(0.2)
	_expect(enemy.state == enemy.State.DEAD and _clip(player) == "death", "Death did not hold until reset")
	_expect_cursor(player, cursor, "Death final pose rewound")
	enemy.reset_enemy()
	enemy.set_physics_process(false)
	player = _player_for(enemy.body_visual_root)
	if player != null:
		_expect(enemy.state == enemy.State.IDLE and _clip(player) == "idle", "reset_enemy did not release death")
		_expect(not enemy._embedded_death_playing, "reset_enemy retained corpse flag")
	for child: Node in enemy.body_visual_root.get_children():
		child.free()
	enemy._die()
	_expect(is_equal_approx(enemy.visual_root.rotation.z, 1.35), "Missing clips lost procedural corpse fallback")
	enemy.queue_free()


func _test_summon_actions() -> void:
	var owner := SummonOwner.new()
	_stage.add_child(owner)
	var summon: Variant = _make_summon(&"dharma_child", owner)
	var player: AnimationPlayer = _player_for(summon._visual)
	if player != null:
		owner.position.x = 8.0
		summon._update_movement(0.1)
		summon._drive_model_motion(0.1)
		_expect(_clip(player) in ["walk", "fly", "move"], "Summon movement did not choose locomotion")
		player.advance(0.1)
		var cursor: float = player.current_animation_position
		summon._drive_model_motion(0.1)
		_expect_cursor(player, cursor, "Summon movement restarted each frame")
		summon._perform_attack(owner)
		player.advance(0.05)
		var attack_clip: String = _clip(player)
		_expect(owner.hits == 1, "Summon attack changed immediate hit count")
		_expect(not player.get_animation(player.assigned_animation).loop_mode, "Summon attack did not play a one-shot")
		summon._drive_model_motion(0.1)
		_expect(_clip(player) == attack_clip, "Summon loop interrupted attack")
		summon.receive_hit(1.0, 0.0, Vector3.ZERO, owner)
		_expect(_clip(player) == "hit" and summon.health == summon.max_health - 1.0, "Summon hit timing changed")
	summon._despawn()
	owner.position = Vector3.ZERO
	var lotus: Variant = _make_summon(&"rebirth_lotus", owner)
	player = _player_for(lotus._visual)
	if player != null:
		var model: Node3D = lotus._visual.get_node("ModelRoot") as Node3D
		var rest: Transform3D = model.transform
		var rotation: Vector3 = lotus._visual.rotation
		lotus._tick_behavior(1.0)
		player.advance(0.05)
		_expect(is_equal_approx(owner.healed, lotus.heal_rate), "Lotus heal was delayed or duplicated")
		_expect(player.get_animation(player.assigned_animation).loop_mode == Animation.LOOP_NONE, "Heal did not request cast/special")
		_expect(model.transform.is_equal_approx(rest) and lotus._visual.rotation == rotation, "Embedded lotus still spins/bobs procedurally")
		var cursor: float = player.current_animation_position
		lotus._drive_model_motion(0.1)
		_expect_cursor(player, cursor, "Lotus idle restarted its heal clip")
	lotus._despawn()
	owner.queue_free()


func _test_summon_death() -> void:
	var owner := SummonOwner.new()
	_stage.add_child(owner)
	var summon: Variant = _make_summon(&"white_crane", owner)
	var player: AnimationPlayer = _player_for(summon._visual)
	if player == null:
		summon._despawn()
		owner.queue_free()
		return
	var visual: Node3D = summon._visual
	var transform: Transform3D = visual.global_transform
	var events: Dictionary = {"despawned": 0, "refund": 0.0, "restored": false}
	summon.despawned.connect(func(_summon: Node) -> void:
		events["despawned"] += 1
		events["refund"] += 12.0
		events["restored"] = is_equal_approx(owner.focus_regen_multiplier, 1.0))
	_expect(owner.focus_regen_multiplier > 1.0, "White Crane boon fixture missing")
	summon.receive_hit(summon.max_health, 0.0, Vector3.ZERO, owner)
	_expect(not summon.is_targetable() and summon.is_queued_for_deletion(), "Death retained gameplay actor")
	_expect(events["despawned"] == 1 and events["refund"] == 12.0 and events["restored"], "Death deferred refund or boon restoration")
	_expect(visual.get_parent() == _stage and visual.global_transform.is_equal_approx(transform), "Death visual was not detached in place")
	_expect(_clip(player) == "death", "Detached summon visual did not play death")
	player.advance(0.2)
	_expect(player.current_animation_position > 0.0, "Detached death cannot advance")
	summon._die()
	summon._despawn()
	summon.receive_hit(999.0, 0.0, Vector3.ZERO, owner)
	_expect(events["despawned"] == 1 and events["refund"] == 12.0, "Cleanup callbacks duplicated")
	await process_frame
	_expect(not is_instance_valid(summon), "Gameplay actor survived its original deletion frame")
	await create_timer(SummonScript.DEATH_VISUAL_SECONDS + 0.1, false).timeout
	await process_frame
	_expect(not is_instance_valid(visual), "Death visual exceeded its bounded lifetime")
	_expect(events["despawned"] == 1, "Visual retirement emitted despawn again")
	owner.queue_free()


func _test_instant_cleanup() -> void:
	for reason: String in ["death", "dismiss", "expiry", "missing_owner"]:
		var owner := SummonOwner.new()
		_stage.add_child(owner)
		var summon: Variant = SummonScript.new()
		summon.player = owner
		summon.focus_regen_multiplier = 1.5
		owner.focus_regen_multiplier = 1.5
		summon._visual = MeshInstance3D.new()
		summon.add_child(summon._visual)
		_stage.add_child(summon)
		summon.set_process(false)
		var visual: Node3D = summon._visual
		var events: Dictionary = {"count": 0}
		summon.despawned.connect(func(_summon: Node) -> void: events["count"] += 1)
		match reason:
			"death": summon._die()
			"dismiss": summon._despawn()
			"expiry":
				summon._lifetime_left = 0.0
				summon._process(0.1)
			"missing_owner":
				summon.player = null
				summon._process(0.1)
		summon._die()
		summon._despawn()
		_expect(events["count"] == 1 and summon.is_queued_for_deletion(), reason + " cleanup duplicated/delayed")
		_expect(visual.get_parent() == summon, reason + " detached a visual without death support")
		if reason != "missing_owner":
			_expect(owner.focus_regen_multiplier == 1.0, reason + " did not restore boon immediately")
		owner.queue_free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
