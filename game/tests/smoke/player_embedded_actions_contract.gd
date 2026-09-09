extends SceneTree
## Run after the embedded-action manifest and class GLBs have been imported.
## Exercises real player helpers with manually advanced clips, not physics updates.

const PlayerScript = preload("res://scripts/player/player.gd")
const Embedded = preload("res://scripts/core/embedded_model_actions.gd")
const SUCCESS_MARKER := "ASHEN_PLAYER_EMBEDDED_ACTIONS_CONTRACTS_OK"

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player = PlayerScript.new()
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	var bridge = player._anim_bridge
	_expect(bridge != null and bridge.enabled, "legacy bridge must remain available")
	if bridge == null:
		player.queue_free()
		_finish()
		return
	# Keep the existing tree/resources intact, but make this fixture deterministic.
	bridge.anim_tree.active = false
	var root_track: NodePath = bridge.anim_tree.root_motion_track
	var combat_library: AnimationLibrary = bridge.anim_player.get_animation_library("combat")
	_expect(not Embedded.available(player.body_mesh), "Manny must not bind embedded class actions")
	player._change_state(player.State.DODGE, .8)
	player.state_time = .4
	player._update_visual_pose()
	_expect(absf(player.visual_root.rotation.x) > .1, "legacy procedural dodge must remain")
	player._change_state(player.State.LOCOMOTION)
	_expect(player.try_switch_class(player.CombatStyle.TWIN_COLOSSI), "base class switch must succeed")
	await process_frame
	await process_frame
	_expect(Embedded.available(player.body_mesh), "barbarian requires newly imported embedded actions")
	var animation := _animation_player(player.body_mesh)
	if animation == null or not Embedded.available(player.body_mesh):
		_expect(false, "class BodyRoot must contain its bound AnimationPlayer")
		player.queue_free()
		_finish()
		return
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var weapon_animation := _weapon_probe(player.weapon_pivot)
	_test_locomotion(player, animation)
	_test_state_entries(player, animation)
	_test_speed_and_visuals(player, animation)
	_test_death_and_respawn(player, animation)
	_test_body_rebuild(player)
	_expect(bridge.anim_tree.root_motion_track == root_track, "root-motion track must not change")
	_expect(bridge.anim_player.get_animation_library("combat") == combat_library,
		"embedded actions must not replace the legacy library")
	_expect(is_equal_approx(weapon_animation.speed_scale, .75), "body speed must not reach weapons")
	_expect(_is_clip(weapon_animation, "weapon_probe"), "body reset must not reset weapons")
	_expect(is_equal_approx(weapon_animation.current_animation_position, .23),
		"body playback must not advance the weapon probe")
	player.queue_free()
	await process_frame
	_finish()


func _test_locomotion(player, animation: AnimationPlayer) -> void:
	Embedded.reset(player.body_mesh)
	player._change_state(player.State.LOCOMOTION)
	player._update_embedded_locomotion(Vector3.ZERO, false)
	_expect(_is_clip(animation, "idle"), "stationary player must idle")
	player._update_embedded_locomotion(Vector3.FORWARD, false)
	_expect(_is_clip(animation, "walk"), "moving player must walk")
	animation.advance(.13)
	var position := animation.current_animation_position
	player._update_embedded_locomotion(Vector3.FORWARD, false)
	_expect(is_equal_approx(animation.current_animation_position, position), "walk must be idempotent")
	player._update_embedded_locomotion(Vector3.FORWARD, true)
	_expect(_is_clip(animation, "run"), "sprinting player must run")
	var target := Node3D.new()
	player.add_child(target)
	player.lock_target = target
	player._update_embedded_locomotion(player.global_basis.x, false)
	_expect(_is_clip(animation, "strafe_right"), "locked right movement must strafe right")
	player._update_embedded_locomotion(-player.global_basis.x, false)
	_expect(_is_clip(animation, "strafe_left"), "locked left movement must strafe left")
	player._update_embedded_locomotion(Vector3.ZERO, false)
	_expect(_is_clip(animation, "idle"), "lock-on without movement must idle")
	player.lock_target = null
	target.free()


func _test_state_entries(player, animation: AnimationPlayer) -> void:
	var attack := AttackData.new()
	attack.windup_seconds = .30
	attack.active_seconds = .20
	attack.recovery_seconds = .40
	player._current_attack = attack
	for heavy in [false, true]:
		Embedded.reset(player.body_mesh)
		player._change_state(player.State.LOCOMOTION)
		player.attack_heavy = heavy
		player._change_state(player.State.ATTACK_WINDUP, attack.windup_seconds)
		_expect(_is_clip(animation, "attack_heavy" if heavy else "attack_light"),
			"windup must start the selected attack")
		_expect(not player.combat_area.active, "windup must not open the hitbox")
		_expect(is_equal_approx(player.state_time, attack.windup_seconds), "clip must not change state timing")
		animation.advance(.08)
		var clip := animation.current_animation
		var position := animation.current_animation_position
		Embedded.play_action(player.body_mesh, "walk")
		_expect(animation.current_animation == clip, "loop request must not interrupt a one-shot")
		player._change_state(player.State.ATTACK_ACTIVE, attack.active_seconds)
		_expect(animation.current_animation == clip, "active must retain the windup clip")
		_expect(is_equal_approx(animation.current_animation_position, position), "active must not restart")
		_expect(player.combat_area.active and not player._hitbox_anim_deferred, "active remains state-timed")
		player._change_state(player.State.ATTACK_RECOVERY, attack.recovery_seconds)
		_expect(is_equal_approx(animation.current_animation_position, position), "recovery must not restart")
		_expect(not player.combat_area.active, "recovery must close the hitbox")
		player._change_state(player.State.ATTACK_WINDUP, attack.windup_seconds)
		_expect(animation.current_animation_position < position, "a newly accepted attack must restart")
	var cases := {
		player.State.CAST: "cast", player.State.DODGE: "dodge",
		player.State.LEAP_WINDUP: "twin_axe_cleave",
		player.State.GUARD_THRUST: "twin_axe_cleave",
		player.State.STAGGER: "hit", player.State.GUARD_BROKEN: "hit",
		player.State.GRABBED: "hit",
	}
	for next_state in cases:
		player._change_state(next_state, .6)
		_expect(_is_clip(animation, cases[next_state]), "state %s must play %s" % [next_state, cases[next_state]])
		player._update_embedded_locomotion(Vector3.ZERO, false)
		_expect(_is_clip(animation, cases[next_state]), "locomotion helper must respect player state")
	player._change_state(player.State.LEAP_WINDUP, .3)
	animation.advance(.08)
	var leap_position := animation.current_animation_position
	player._change_state(player.State.LEAP_ACTIVE, .2)
	_expect(is_equal_approx(animation.current_animation_position, leap_position), "leap active must not restart")
	_expect(player.combat_area.active and not player._hitbox_anim_deferred, "leap hitbox remains state-timed")
	player._change_state(player.State.ATTACK_RECOVERY, .4)
	_expect(is_equal_approx(animation.current_animation_position, leap_position), "leap recovery must not restart")
	Embedded.reset(player.body_mesh)
	player._change_state(player.State.LOCOMOTION)


func _test_speed_and_visuals(player, animation: AnimationPlayer) -> void:
	player._change_state(player.State.CAST, .7)
	var full_speed := animation.get_playing_speed()
	_expect(full_speed > 0., "cast must have a positive playback rate")
	player.set_meta("g06_time_dilation", .5)
	player.set_meta("g06_time_dilation_ttl", .2)
	player._tick_g06_time_dilation(0.)
	_expect(is_equal_approx(animation.get_playing_speed(), full_speed * .5), "local dilation applies once")
	player.set_visual_frozen(true)
	_expect(is_zero_approx(animation.get_playing_speed()), "hit-stop must freeze embedded animation")
	player._tick_g06_time_dilation(0.)
	_expect(is_zero_approx(animation.get_playing_speed()), "dilation tick must not thaw hit-stop")
	player.set_visual_frozen(false)
	_expect(is_equal_approx(animation.get_playing_speed(), full_speed * .5), "thaw restores local dilation")
	player._tick_g06_time_dilation(.3)
	_expect(is_equal_approx(animation.get_playing_speed(), full_speed), "expired dilation restores speed")
	player.visual_root.rotation = Vector3(.2, .1, .3)
	player.state_time = .35
	player._update_visual_pose()
	_expect(player.visual_root.rotation.is_zero_approx(), "procedural body tilt must not fight native clips")
	Embedded.reset(player.body_mesh)
	player._change_state(player.State.LOCOMOTION)
	var body_transform: Transform3D = player.body_mesh.transform
	player._update_real_body_motion(.1)
	_expect(player.body_mesh.transform.is_equal_approx(body_transform), "procedural bob must not move native BodyRoot")
	_expect(player.body_yaw.get_node_or_null("ModelAmbient") != null, "class ambient VFX must remain")


func _test_death_and_respawn(player, animation: AnimationPlayer) -> void:
	player._die()
	_expect(player.state == player.State.DEAD and _is_clip(animation, "death"), "death must start the native clip")
	_expect(player.visual_root.rotation.is_zero_approx(), "death must not apply legacy body tilt")
	animation.advance(.1)
	var position := animation.current_animation_position
	player._change_state(player.State.DEAD)
	_expect(is_equal_approx(animation.current_animation_position, position), "repeated death must not restart")
	player._change_state(player.State.LOCOMOTION)
	player._update_embedded_locomotion(Vector3.FORWARD, false)
	_expect(_is_clip(animation, "death"), "death must stay locked until reset")
	player.respawn_at(Vector3.ZERO)
	_expect(player.state == player.State.LOCOMOTION and _is_clip(animation, "idle"), "respawn must reset death lock")


func _test_body_rebuild(player) -> void:
	var old_body: Node = player.body_mesh
	var old_animation := _animation_player(old_body)
	old_animation.advance(.12)
	var position := old_animation.current_animation_position
	player._rebuild_player_body("barbarian")
	_expect(player.body_mesh == old_body, "same-class rebuild must be a no-op")
	_expect(is_equal_approx(old_animation.current_animation_position, position), "same-class rebuild must not reset playback")
	var retained: Array[Node3D] = [player.weapon_pivot, player.offhand_weapon_pivot,
		player.shield_mesh, player.weapon_trail, player.combat_area, player.camera_rig]
	var transforms: Array[Transform3D] = []
	for node in retained:
		transforms.append(node.transform)
	var timer: float = player.state_time
	var state: int = player.state
	player.set_visual_frozen(true)
	player._rebuild_player_body("mystic")
	_expect(player.body_mesh != old_body and old_body.is_queued_for_deletion(), "class change must replace only the old body")
	_expect(player.state == state and player.state_time == timer, "body rebuild must preserve gameplay state")
	_expect(Embedded.available(player.body_mesh), "replacement class must bind embedded actions")
	var new_animation := _animation_player(player.body_mesh)
	_expect(new_animation != null, "replacement class must contain an AnimationPlayer")
	if new_animation != null:
		new_animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_expect(_is_clip(new_animation, "idle"), "replacement class must start cleanly")
		_expect(is_zero_approx(new_animation.get_playing_speed()), "replacement class must inherit hit-stop")
	for index in retained.size():
		var node := retained[index]
		_expect(is_instance_valid(node) and node.is_inside_tree(), "body rebuild must preserve equipment/camera/hitbox nodes")
		_expect(node.transform.is_equal_approx(transforms[index]), "body rebuild must preserve retained transforms")
	_expect(player.weapon_pivot.get_parent() == player.body_yaw, "weapon pivot must remain outside replaceable BodyRoot")
	_expect(player.weapon_trail.get_parent() == player.body_yaw, "trail hierarchy must remain unchanged")
	player.set_visual_frozen(false)
	player._change_state(player.State.GUARD_THRUST, .4)
	if new_animation != null:
		_expect(_is_clip(new_animation, "gate_seal_ritual"), "special alias must use the replacement model")


func _weapon_probe(parent: Node) -> AnimationPlayer:
	var animation := AnimationPlayer.new()
	animation.name = "EmbeddedScopeProbe"
	parent.add_child(animation)
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var library := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 1.
	clip.loop_mode = Animation.LOOP_LINEAR
	library.add_animation("weapon_probe", clip)
	animation.add_animation_library("", library)
	animation.speed_scale = .75
	animation.play("weapon_probe")
	animation.seek(.23, true)
	return animation


func _animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer and node.active:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _animation_player(child)
		if found != null:
			return found
	return null


func _is_clip(animation: AnimationPlayer, clip: String) -> bool:
	var current := String(animation.current_animation)
	return current == clip or current.ends_with("/" + clip)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(SUCCESS_MARKER)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
