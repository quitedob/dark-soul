extends SceneTree
## D-01 真蒙皮动画管线合约：
## 1) 无真库时 bridge 走纯程序化（回归：enabled + root delta + BS2D 均在）。
## 2) 有真库且身体骨架匹配时，bridge 能加载真库（animation list 非空）、
##    真层激活、Idle 状态切到 "real/<clip>"，且现有 root-motion 合约不破坏。
## 3) 真库 clip 只含整身根运动骨（如 mannyquin 的 "root" 轨）→ 剔除后 0 可用轨，
##    真层保持关闭，纯程序化回退（负例）。

const AnimBridge = preload("res://scripts/combat/player_animation_bridge.gd")
const PlayerScene = preload("res://scenes/actors/player.tscn")
const InputConfig = preload("res://scripts/core/input_config.gd")

const TMP_HEAD_PATH := "res://tests/smoke/_player_anim_real_lib_head.tmp.tres"
const TMP_ROOT_PATH := "res://tests/smoke/_player_anim_real_lib_root.tmp.tres"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_no_library_procedural_fallback()
	_test_real_library_loads_and_drives()
	_test_root_only_clip_stays_fallback()
	_test_mannyquin_bind_pose_guarded()
	_cleanup_tmp_files()
	await process_frame
	await _test_real_sword_combat_timeline()
	if _failures.is_empty():
		print("PLAYER_ANIMATION_REAL_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


## Actual scene, Physics AnimationTree, combat FSM, and buffered combo. The source
## wrist must finish its raised windup before damage, then cross during the hitbox.
func _test_real_sword_combat_timeline() -> void:
	InputConfig.configure_inputs()
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 0.5, 60.0)
	floor_shape.shape = box
	floor_shape.position.y = -0.25
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)
	var player = PlayerScene.instantiate()
	stage.add_child(player)
	player.set_process_unhandled_input(false)
	player.max_stamina = 1000.0
	player.stamina = 1000.0
	for frame in 20:
		await physics_frame
		await process_frame
	var bridge = player._anim_bridge
	_expect(player.is_on_floor(), "timeline: real player must settle on physical floor")
	_expect(bridge.has_real_animations() and bridge.real_clip_for(&"sword_light_1") != &"",
		"timeline: actual Manny sword clip must be loaded")
	if not bridge.has_real_animations():
		stage.free()
		return
	var skeleton: Skeleton3D = bridge._real_skeleton
	var hand := skeleton.find_bone("DEF-hand.R")
	_expect(hand >= 0, "timeline: real Manny right wrist required")
	var original: Animation = bridge.anim_player.get_animation("real/sword_light_1")
	var original_length := original.length
	var base: AttackData = player._current_moveset().neutral_light
	var authored_durations := Vector3(base.windup_seconds, base.active_seconds, base.recovery_seconds)
	player._try_attack(false, "right", "sword_light")
	_expect(player.state == player.State.ATTACK_WINDUP, "timeline: player must accept light attack")
	var queued := false
	var second_started := false
	var finished := false
	var active_points: Dictionary = {0: [], 1: []}
	var checked_frames := 0
	var checked_attacks: Dictionary = {}
	var grip_phases: Dictionary = {}
	var seen_recovery := false
	var step := 1.0 / float(Engine.physics_ticks_per_second)
	for frame in 240:
		await physics_frame
		await process_frame
		var state: int = player.state
		var index: int = player._combo_chain_index
		if state == player.State.LOCOMOTION:
			finished = true
			break
		if state not in [player.State.ATTACK_WINDUP, player.State.ATTACK_ACTIVE, player.State.ATTACK_RECOVERY]:
			_expect(false, "timeline: unexpected interrupt state %s" % state)
			break
		var attack: AttackData = player._current_attack
		var position: float = bridge._playback.get_current_play_position()
		var elapsed: float = player.state_duration - player.state_time
		if state == player.State.ATTACK_ACTIVE:
			elapsed += attack.windup_seconds
		elif state == player.State.ATTACK_RECOVERY:
			elapsed += attack.windup_seconds + attack.active_seconds
			seen_recovery = true
		_expect(bridge._playback.get_current_node() == &"LightAttack", "timeline: attack FSM must drive real tree LightAttack")
		_expect(absf(position - elapsed) <= step * 2.1,
			"timeline: animation/FSM clocks differ: clip=%.4f phase=%.4f" % [position, elapsed])
		_expect(player.combat_area.active == (state == player.State.ATTACK_ACTIVE),
			"timeline: real CombatArea must be enabled only during active phase")
		_check_manny_grip(player, skeleton, "timeline: swing %d phase %d" % [index, state])
		grip_phases[state] = true
		var clip: Animation = bridge.anim_player.get_animation(bridge._light_node.animation)
		_expect(bridge.clip_drives_real_body(bridge._light_node.animation), "timeline: retimed real clip must retain skeletal pose provenance")
		_expect(is_equal_approx(clip.length, attack.windup_seconds + attack.active_seconds + attack.recovery_seconds),
			"timeline: each real clip must finish with its AttackData recovery")
		if not checked_attacks.has(index):
			checked_attacks[index] = true
			_check_light_boundary_poses(original, clip, attack)
		if index == 1 and not second_started:
			second_started = true
			_expect(state == player.State.ATTACK_WINDUP and position <= step * 1.1,
				"timeline: queued second swing must restart at windup, not continue first clip")
			_expect(attack.windup_seconds < base.windup_seconds,
				"timeline: use real derived combo cadence, not a duplicate first attack")
		if state == player.State.ATTACK_ACTIVE and hand >= 0:
			var wrist: Vector3 = player.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand).origin))
			if active_points.has(index):
				active_points[index].append(wrist)
			if index == 0 and not queued and player.state_time < attack.active_seconds * 0.5:
				player.enqueue_action(&"right_primary", 500)
				queued = true
		checked_frames += 1
	_expect(queued and second_started, "timeline: buffered input must reach a second real swing")
	_expect(finished and seen_recovery, "timeline: combo must finish recovery and return to locomotion")
	_expect(grip_phases.size() == 3, "timeline: anatomical grip must be sampled throughout all three combat phases")
	for index in [0, 1]:
		var points: Array = active_points[index]
		_expect(points.size() >= 3, "timeline: swing %d needs actual active wrist samples" % index)
		if points.size() >= 3:
			var first: Vector3 = points.front()
			var last: Vector3 = points.back()
			_expect(first.y > 1.5 and last.y < 1.35 and first.distance_to(last) > 0.85,
				"timeline: swing %d damage window missed raised-to-cross-body wrist sweep: %s -> %s" % [index, first, last])
			print("REAL_SWORD_ACTIVE_SWEEP index=%d samples=%d first=%s last=%s span=%.4f" %
				[index, points.size(), first, last, first.distance_to(last)])
	for frame in 6:
		await physics_frame
		await process_frame
	_expect(bridge._playback.get_current_node() == &"Idle" and not player.combat_area.active,
		"timeline: completed combo must restore idle tree and close damage")
	_check_manny_grip(player, skeleton, "timeline: returned idle")
	_expect(not player.action_queued(&"right_primary"), "timeline: chain must consume queued attack once")
	_expect(is_equal_approx(original.length, original_length) and original == bridge.anim_player.get_animation("real/sword_light_1"),
		"timeline: source clip must remain unchanged")
	_expect(authored_durations.is_equal_approx(Vector3(base.windup_seconds, base.active_seconds, base.recovery_seconds)),
		"timeline: animation alignment must preserve authored combat balance")
	print("REAL_SWORD_TIMELINE frames=%d chained=%s idle=%s source_length=%.6f" %
		[checked_frames, second_started, finished, original_length])
	await _check_real_heavy_attacks(player, skeleton, original)
	await _check_real_weapon_arts(player, skeleton)
	stage.free()


func _check_real_heavy_attacks(player, skeleton: Skeleton3D, original: Animation) -> void:
	for charged in [false, true]:
		if charged:
			# Exercise the actual K-release route with its authored charge tier.
			player._start_heavy_charge("right", "sword_heavy")
			player._charge_time = player._current_moveset().charged_heavy.tier_two_seconds
			player._release_heavy_charge()
		else:
			player._try_attack(true, "right", "sword_heavy")
		_expect(player.state == player.State.ATTACK_WINDUP and player.attack_heavy,
			"heavy: actual heavy commit must enter windup")
		var bridge = player._anim_bridge
		var attack: AttackData = player._current_attack
		var durations := Vector3(attack.windup_seconds, attack.active_seconds, attack.recovery_seconds)
		var phases: Dictionary = {}
		var wrists: Array[Vector3] = []
		var frames := 0
		for frame in 240:
			await physics_frame
			await process_frame
			if player.state == player.State.LOCOMOTION:
				break
			phases[player.state] = true
			_check_manny_grip(player, skeleton, "heavy charged=%s phase=%d" % [charged, player.state])
			_expect(bridge._playback.get_current_node() == &"LightAttack"
				and bridge.clip_drives_real_body(bridge._light_node.animation),
				"heavy: real ground melee clip must drive the body")
			_expect(player.combat_area.active == (player.state == player.State.ATTACK_ACTIVE),
				"heavy: physical hitbox must agree with actual heavy FSM")
			if frames == 0:
				var clip: Animation = bridge.anim_player.get_animation(bridge._light_node.animation)
				_expect(is_equal_approx(clip.length, durations.x + durations.y + durations.z), "heavy: authored cadence must fit full clip")
				_check_light_boundary_poses(original, clip, attack)
			if player.state == player.State.ATTACK_ACTIVE:
				var hand := skeleton.find_bone("DEF-hand.R")
				wrists.append(player.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hand).origin)))
			frames += 1
		_expect(player.state == player.State.LOCOMOTION and phases.size() == 3, "heavy: all three attack phases must complete")
		_expect(wrists.size() > 3 and wrists.front().distance_to(wrists.back()) > 0.85,
			"heavy: damage window must contain the full real wrist sweep")
		_expect(durations.is_equal_approx(Vector3(attack.windup_seconds, attack.active_seconds, attack.recovery_seconds)),
			"heavy: animation must preserve attack balance")
		for frame in 6:
			await physics_frame
			await process_frame
		_expect(bridge._playback.get_current_node() == &"Idle" and not player.combat_area.active, "heavy: return to idle after recovery")
		print("REAL_HEAVY_TIMELINE charged=%s frames=%d phases=%d cadence=%s" % [charged, frames, phases.size(), durations])


func _check_real_weapon_arts(player, skeleton: Skeleton3D) -> void:
	var cases := [
		["guard_thrust", player.CombatStyle.RELIQUARY_GUARD, "sword_art", &"Skill", 2],
		["curved_leap", player.CombatStyle.CRESCENT_PAIR, "curved_art", &"Skill", 3],
		["colossal_leap", player.CombatStyle.TWIN_COLOSSI, "axe_art", &"ColossalLeap", 3],
	]
	for fixture in cases:
		# Select the actual moveset while keeping the Manny rig under test. Normal
		# class switching would replace it with a separate native character driver.
		player.combat_style = fixture[1]
		player._refresh_moveset_cache()
		# F dispatch uses the weapon's own default art, including legacy resources
		# with no authored stance. Passing the catalog art here misses that route.
		player._try_style_skill()
		var phases: Dictionary = {}
		var frames := 0
		var first_wrist := Vector3.ZERO
		var wrist_motion := 0.0
		for frame in 240:
			await physics_frame
			await process_frame
			if player.state == player.State.LOCOMOTION:
				break
			phases[player.state] = true
			var bridge = player._anim_bridge
			_expect(bridge._playback.get_current_node() == fixture[3], String(fixture[0]) + ": actual art must use expected tree node")
			_check_manny_grip(player, skeleton, "%s phase=%d" % [fixture[0], player.state])
			var right := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R")).origin
			var left := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.L")).origin
			var right_shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-upper_arm.R")).origin
			var left_shoulder := skeleton.get_bone_global_pose(skeleton.find_bone("DEF-upper_arm.L")).origin
			var right_arm := right - right_shoulder
			var left_arm := left - left_shoulder
			if frames > 3:
				var arms_out := absf(right_arm.x) > 0.45 and absf(left_arm.x) > 0.45 \
					and absf(right_arm.y) < 0.2 and absf(left_arm.y) < 0.2 \
					and absf(right_arm.z) < 0.25 and absf(left_arm.z) < 0.25
				_expect(not arms_out, String(fixture[0]) + ": default art must not reset both arms to T-pose")
			if frames == 4:
				first_wrist = right
			if frames > 4:
				wrist_motion = maxf(wrist_motion, right.distance_to(first_wrist))
			_expect(player.combat_area.active == (player.state in [player.State.GUARD_THRUST, player.State.LEAP_ACTIVE]),
				String(fixture[0]) + ": hitbox must close during recovery")
			frames += 1
		_expect(player.state == player.State.LOCOMOTION and phases.size() == fixture[4], String(fixture[0]) + ": real art must finish every phase")
		_expect(wrist_motion > 0.15, String(fixture[0]) + ": real default art needs meaningful skeletal arm motion, not only weapon rotation")
		# Finish landing as well as returning the animation to Idle before next art.
		for frame in 90:
			await physics_frame
			await process_frame
			if player.is_on_floor() and frame >= 6:
				break
		print("REAL_ART_GRIP art=%s frames=%d phases=%d stance=%s wrist_motion=%.4f" % [fixture[0], frames, phases.size(), player._current_art_stance, wrist_motion])
	# A real idle library alone must not suppress the missing-stance fallback.
	player.combat_style = player.CombatStyle.RELIQUARY_GUARD
	player._refresh_moveset_cache()
	var fallback: WeaponArtData = load("res://resources/weapon_arts/sword_art.tres").duplicate()
	fallback.stance_animation = &"missing_art_pose_fixture"
	player._execute_weapon_art(fallback)
	await physics_frame
	await process_frame
	_expect(player._anim_bridge._skill_node.animation == &"combat/skill_pose"
		and not player._visuals._legacy_equipment_clip_active(), "art fallback: procedural pose must remain classified as fallback")
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R"))
	_expect(player.weapon_pivot.global_basis.y.normalized().dot(hand.basis.orthonormalized().z) < 0.95,
		"art fallback: missing real pose must retain procedural weapon gesture")


func _check_manny_grip(player, skeleton: Skeleton3D, label: String) -> void:
	for side in ["R", "L"]:
		var bone := skeleton.find_bone("DEF-hand." + side)
		var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var pivot: Node3D = player.weapon_pivot if side == "R" else player.offhand_weapon_pivot
		var palm_position := hand_world.affine_inverse() * pivot.global_position
		_expect(palm_position.y > 0.05 and palm_position.y < 0.1 and absf(palm_position.x) < 0.02 and absf(palm_position.z) < 0.01,
			label + ": " + side + " grip must remain inside the animated palm")
		_expect(pivot.global_basis.y.normalized().dot(hand_world.basis.orthonormalized().z) > 0.999,
			label + ": " + side + " blade axis must follow anatomical hand grip without procedural rotation")
		_expect(pivot.global_basis.x.normalized().dot(hand_world.basis.x.normalized()) > 0.999,
			label + ": " + side + " blade plane must follow hand through phase and combo transitions")


func _check_light_boundary_poses(source: Animation, timed: Animation, attack: AttackData) -> void:
	# Measured source sweep landmarks, independently sampled from the original
	# real library. Check every bone at damage-on/off, including rotation curves.
	var target_times := [attack.windup_seconds, attack.windup_seconds + attack.active_seconds]
	var source_times := [0.525, 0.700]
	for track in source.get_track_count():
		var kind := source.track_get_type(track)
		if kind not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			continue
		var target := timed.find_track(source.track_get_path(track), kind)
		_expect(target >= 0, "timeline: timed clip lost a source bone track")
		if target < 0:
			continue
		for index in 2:
			var source_time: float = source_times[index]
			var target_time: float = target_times[index]
			var error := 0.0
			match kind:
				Animation.TYPE_POSITION_3D:
					error = source.position_track_interpolate(track, source_time).distance_to(timed.position_track_interpolate(target, target_time))
				Animation.TYPE_ROTATION_3D:
					error = 1.0 - absf(source.rotation_track_interpolate(track, source_time).dot(timed.rotation_track_interpolate(target, target_time)))
				Animation.TYPE_SCALE_3D:
					error = source.scale_track_interpolate(track, source_time).distance_to(timed.scale_track_interpolate(target, target_time))
			_expect(error < 0.0001, "timeline: contact boundary pose changed on " + String(source.track_get_path(track)))
	var method := timed.find_track(NodePath("."), Animation.TYPE_METHOD)
	_expect(method >= 0, "timeline: timed real clip must retain callback events")
	if method >= 0:
		var hit_events := 0
		for key in timed.track_get_key_count(method):
			var event: Dictionary = timed.track_get_key_value(method, key)
			var at := timed.track_get_key_time(method, key)
			if event["method"] == "anim_event_hitbox_on":
				_expect(is_equal_approx(at, attack.windup_seconds), "timeline: hit-on callback differs from real FSM windup")
				hit_events += 1
			elif event["method"] == "anim_event_hitbox_off":
				_expect(is_equal_approx(at, attack.windup_seconds + attack.active_seconds), "timeline: hit-off callback differs from real FSM active end")
				hit_events += 1
		_expect(hit_events == 2, "timeline: expected exactly one pair of hit callbacks")


## 1) 无真库：setup 全程序化，真层关闭。
func _test_no_library_procedural_fallback() -> void:
	var bridge = AnimBridge.new()
	var body := CharacterBody3D.new()
	root.add_child(body)
	bridge.setup(body)
	_expect(bridge.enabled, "no-lib: bridge must enable (procedural).")
	_expect(not bridge.real_layer_active, "no-lib: real layer must stay off.")
	_expect(not bridge.has_real_animations(), "no-lib: has_real_animations must be false.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "no-lib: light root delta must still be procedural.")
	_expect(bridge.has_strafe_blendspace(), "no-lib: Strafe BlendSpace2D must still exist.")
	_expect(bridge.skeleton != null and bridge.anim_tree != null and bridge.anim_player != null,
		"no-lib: full procedural pipeline required.")
	body.queue_free()


## 2) 有真库 + 骨架匹配：加载、注入、重建状态机指向真 clip；root 合约不破。
func _test_real_library_loads_and_drives() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	# 模拟真模型身体：Visuals/BodyRoot/Skeleton3D（root 探针骨 + 肢体骨）
	var visuals := Node3D.new()
	visuals.name = "Visuals"
	body.add_child(visuals)
	var body_root := Node3D.new()
	body_root.name = "BodyRoot"
	visuals.add_child(body_root)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-head")
	skel.set_bone_rest(1, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, 0)))
	body_root.add_child(skel)

	var lib := _make_head_library()
	var save_err := ResourceSaver.save(lib, TMP_HEAD_PATH)
	_expect(save_err == OK, "real-lib: temp library save failed (err %d)." % save_err)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	# 默认真库现已含真实 strafe_back（DEF-head 轨可在本骨架存活）→ 层在 configure 前即激活。
	_expect(bridge.real_layer_active, "real-lib: default lib now drives real strafe_back -> layer active before configure.")
	var ok := bridge.configure_real_animations(TMP_HEAD_PATH, skel)
	_expect(ok, "real-lib: configure_real_animations must succeed with matching skeleton.")
	_expect(bridge.real_layer_active, "real-lib: real layer must activate after configure.")
	_expect(bridge.has_real_animations(), "real-lib: has_real_animations must be true.")
	var list: Array[String] = bridge.get_real_animation_list()
	_expect(not list.is_empty(), "real-lib: animation list must be non-empty.")
	_expect(list.has("idle"), "real-lib: animation list must contain 'idle'.")
	_expect(not bridge.real_clip_for(&"idle").is_empty(), "real-lib: idle resolves to a real clip.")
	# Idle 状态节点指向真 clip
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	_expect(idle_node != null, "real-lib: Idle node present in state machine.")
	if idle_node != null:
		_expect(idle_node.animation == "real/idle", "real-lib: Idle node must use 'real/idle', got '%s'." % idle_node.animation)
	# Walk 无真 clip → 程序化回退
	var walk_node := sm.get_node("Walk") as AnimationNodeAnimation
	if walk_node != null:
		_expect(walk_node.animation == "combat/walk", "real-lib: Walk must fall back to 'combat/walk'.")
	# root-motion 合约仍由程序化 Root 轨提供
	_expect(bridge.sample_light_root_delta() >= 0.5, "real-lib: light root delta preserved.")
	_expect(bridge.has_strafe_blendspace(), "real-lib: Strafe BlendSpace2D preserved.")
	# 状态切换不崩
	bridge.travel_locomotion(true, true, Vector2(0.5, 0.2))
	bridge.travel_locomotion(false, false)
	bridge.travel_light_attack(AttackData.new())
	_expect(not bridge.clip_drives_real_body(bridge._light_node.animation),
		"real-lib: having real idle must not classify a retimed procedural light fallback as real body pose")
	_expect(not bridge.travel_melee_attack(AttackData.new(), true),
		"real-lib: heavy without a real sword source must retain its procedural fallback")
	body.queue_free()


## 3) 真库只含整身根运动骨轨 → 剔除后 0 可用轨 → 真层关闭（程序化回退负例）。
func _test_root_only_clip_stays_fallback() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var skel := Skeleton3D.new()
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	body.add_child(skel)

	var lib := _make_root_only_library()
	var save_err := ResourceSaver.save(lib, TMP_ROOT_PATH)
	_expect(save_err == OK, "root-only: temp library save failed (err %d)." % save_err)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations(TMP_ROOT_PATH, skel)
	_expect(not ok, "root-only: configure must fail when only root-motion bone tracks exist.")
	_expect(not bridge.real_layer_active, "root-only: real layer must stay off.")
	# Idle 仍是程序化
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	if idle_node != null:
		_expect(idle_node.animation == "combat/idle", "root-only: Idle must stay 'combat/idle'.")
	_expect(bridge.sample_light_root_delta() >= 0.5, "root-only: procedural root delta preserved.")
	body.queue_free()


## 4) 真实 mannyquin 绑位姿：REAL_IDLE_FALLBACK 名字已对齐（下划线导入名），
##    且内容太薄（3 轨 0.04s）→ 被守卫 → 不会驱动 idle。
##    Step 2 起默认真库已含真实 idle（OAL 重定向 batch）→ idle 解析到真 clip（非绑位姿回退）；
##    绑位姿守卫仍在（无真实 idle 时绝不回退到薄 clip），此处验证该层不被薄 clip 顶替。
func _test_mannyquin_bind_pose_guarded() -> void:
	var body := CharacterBody3D.new()
	root.add_child(body)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	skel.add_bone("root")
	skel.set_bone_rest(0, Transform3D.IDENTITY)
	skel.add_bone("DEF-thumb.01.R")
	skel.set_bone_rest(1, Transform3D.IDENTITY)
	body.add_child(skel)

	var bridge = AnimBridge.new()
	bridge.setup(body)
	var ok := bridge.configure_real_animations("res://resources/animations/mannyquin_lib.tres", skel)
	_expect(ok, "bind-pose: configure must succeed (lib loads + skeleton matches).")
	_expect(bridge.real_layer_active, "bind-pose: real layer injected (library present).")
	_expect(bool(bridge._real_library.has_animation(String(bridge.REAL_IDLE_FALLBACK))),
		"bind-pose: REAL_IDLE_FALLBACK must match imported lib key (underscore).")
	# Step 2：默认库现含真实 idle（OAL batch）→ idle 精确解析到真 clip，而非绑位姿薄 clip。
	_expect(not bridge.real_clip_for(&"idle").is_empty(),
		"bind-pose: idle must resolve to a real clip (Step-2 batch), got empty.")
	# has_real_animations 为真（真实 idle/strafe_back 匹配状态键）。
	_expect(bridge.has_real_animations(),
		"bind-pose: real state-key clips present -> has_real_animations true.")
	var sm := bridge.anim_tree.tree_root as AnimationNodeStateMachine
	var idle_node := sm.get_node("Idle") as AnimationNodeAnimation
	if idle_node != null:
		_expect(idle_node.animation == "real/idle",
			"bind-pose: Idle must use 'real/idle' (Step-2 batch), got '%s'." % idle_node.animation)
	body.queue_free()


func _make_head_library() -> AnimationLibrary:
	var clip := Animation.new()
	clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var t := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(t, NodePath("Skeleton3D:DEF-head"))
	clip.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
	clip.rotation_track_insert_key(t, 0.5, Quaternion(Vector3(0, 1, 0), 0.2))
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", clip)
	return lib


func _make_root_only_library() -> AnimationLibrary:
	var clip := Animation.new()
	clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var t := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(t, NodePath("Skeleton3D:root"))
	clip.position_track_insert_key(t, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(t, 0.5, Vector3(0, 0, -0.5))
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", clip)
	return lib


func _cleanup_tmp_files() -> void:
	DirAccess.remove_absolute(TMP_HEAD_PATH)
	DirAccess.remove_absolute(TMP_ROOT_PATH)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
