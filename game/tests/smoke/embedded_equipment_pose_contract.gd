extends SceneTree
## Run after publishing/importing model_actions.json and the animated class GLBs.
## Uses actual clips and deferred Skeleton3D updates; no IK/art-quality claim.

const PlayerScript = preload("res://scripts/player/player.gd")
const Visuals = preload("res://scripts/core/player_visuals.gd")
const Embedded = preload("res://scripts/core/embedded_model_actions.gd")
const Resolver = preload("res://scripts/core/real_model_resolver.gd")
const NpcScript = preload("res://scripts/world/shrine_npc_interact.gd")
const SUCCESS_MARKER := "ASHEN_EMBEDDED_EQUIPMENT_POSE_CONTRACTS_OK"
const CLASSES := ["barbarian", "marksman", "mystic", "invoker", "yin_yang", "war_shaman", "arcane_archer", "asura"]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := Node3D.new()
	stage.transform = Transform3D(Basis.from_euler(Vector3(.07, .61, -.04)).scaled(Vector3.ONE * 1.3), Vector3(4., 2., -3.))
	root.add_child(stage)
	var player = PlayerScript.new()
	stage.add_child(player)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.rotation.y = -.37
	if player._anim_bridge != null:
		player._anim_bridge.anim_tree.active = false
	await process_frame
	await process_frame
	var retained: Array[Node3D] = [player.weapon_pivot, player.offhand_weapon_pivot,
		player.shield_mesh, player.weapon_trail, player.combat_area, player.camera_rig]
	var weapon_children: Array[Node] = player.weapon_pivot.get_children()
	var weapon_transforms: Array[Transform3D] = []
	for child in weapon_children:
		weapon_transforms.append(child.transform)
	for class_id: String in CLASSES:
		player.state = player.State.LOCOMOTION
		player._rebuild_player_body(class_id)
		await process_frame
		await process_frame
		_expect(Embedded.available(player.body_mesh), class_id + ": missing embedded fixture")
		var skeleton := _hands(player.body_mesh)
		var animation := _animation(player.body_mesh)
		if skeleton == null or animation == null:
			_expect(false, class_id + ": missing hand skeleton/player")
			continue
		animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var body: Node = player.body_mesh
		player._rebuild_player_body(class_id)
		_expect(player.body_mesh == body, class_id + ": same-class rebuild replaced body")
		for index in retained.size():
			_expect(is_instance_valid(retained[index]) and retained[index].is_inside_tree(), class_id + ": lost retained node")
		for node: Node3D in retained.slice(0, 4):
			_expect(node.get_parent() == player.body_yaw, class_id + ": equipment ownership changed")
		var first_hand := Vector3.ZERO
		var max_motion := 0.0
		for action: String in ["idle", "walk", "attack_light", "cast", "dodge", "death"]:
			Embedded.reset(player.body_mesh)
			_expect(Embedded.play_action(player.body_mesh, action, true), class_id + ": cannot request " + action)
			var clip := animation.get_animation(animation.assigned_animation)
			if clip == null:
				_expect(false, class_id + ": action has no assigned clip")
				continue
			player.state = player.State.DEAD if action == "death" else player.State.ATTACK_ACTIVE
			player.state_duration = .8
			player.state_time = .3
			player._update_visual_pose()
			for fraction: float in [.0, .31, .67]:
				animation.seek(clip.length * fraction, true)
				# Do not manually sync the helper here: the final skin update signal
				# must move equipment even when the player's physics callback is off.
				await process_frame
				await process_frame
				var label := "%s/%s/%s" % [class_id, action, fraction]
				_assert_equipment(player, skeleton, label)
				var position: Vector3 = player.weapon_pivot.position
				if action == "idle" and fraction == 0.:
					first_hand = position
				max_motion = maxf(max_motion, position.distance_to(first_hand))
				var followed: Transform3D = player.weapon_pivot.transform
				player._update_visual_pose()
				_expect(player.weapon_pivot.transform.is_equal_approx(followed), label + ": procedural swing overwrote hand pose")
				if action != "death":
					player._trail_points.clear()
					player._update_weapon_trail()
					var tip: Vector3 = player.body_yaw.to_local(player.weapon_pivot.to_global(_authored_sword_tip(player)))
					_expect(player._trail_points.size() == 1 and player._trail_points[0].distance_to(tip) < .0001, label + ": trail tip ignores pivot transform")
				else:
					_expect(player._trail_points.is_empty() and not player.weapon_trail.visible, label + ": death retains attack trail")
		_expect(max_motion > .02, class_id + ": clips did not move the hand anchor")
		for index in weapon_children.size():
			_expect(weapon_children[index].get_parent() == player.weapon_pivot and weapon_children[index].transform.is_equal_approx(weapon_transforms[index]), class_id + ": weapon grip correction changed")

	# Returning to Manny must release old callbacks and follow his DEF-hand bones
	# through the real library's idle, walk, and sword animation poses.
	player.state = player.State.LOCOMOTION
	player._rebuild_player_body("")
	await process_frame
	await process_frame
	_expect(not Embedded.available(player.body_mesh), "Manny incorrectly bound embedded actions")
	player.guard_active = false
	var manny_skeleton := _hands(player.body_mesh, "DEF-hand.")
	var bridge = player._anim_bridge
	_expect(manny_skeleton != null and bridge != null and bridge.has_real_animations(), "Manny real hand/clip fixture unavailable")
	if manny_skeleton != null and bridge != null and bridge.has_real_animations():
		bridge.anim_tree.active = false
		bridge.anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var manny_motion := 0.0
		for action: StringName in [&"idle", &"walk", &"sword_light_1"]:
			var clip_name: StringName = bridge.real_clip_for(action)
			_expect(not clip_name.is_empty(), "Manny missing " + String(action))
			if clip_name.is_empty():
				continue
			bridge.anim_player.play("real/" + String(clip_name))
			var clip: Animation = bridge.anim_player.get_animation("real/" + String(clip_name))
			player.state = player.State.ATTACK_ACTIVE if action == &"sword_light_1" else player.State.LOCOMOTION
			player.state_duration = .8
			player.state_time = .3
			player._update_visual_pose()
			for fraction: float in [.0, .31, .67]:
				bridge.anim_player.seek(clip.length * fraction, true)
				await process_frame
				await process_frame
				var label := "Manny/%s/%s" % [action, fraction]
				_assert_equipment(player, manny_skeleton, label, "DEF-hand.")
				manny_motion = maxf(manny_motion, player.weapon_pivot.position.distance_to(Visuals.HAND_RIGHT_REST))
				var followed: Transform3D = player.weapon_pivot.transform
				player._update_visual_pose()
				_expect(player.weapon_pivot.transform.is_equal_approx(followed), label + ": procedural swing doubled real hand pose")
		_expect(manny_motion > .1, "Manny equipment stayed at T-pose anchors")
		bridge.anim_player.stop()
		# Production evaluates the AnimationTree rather than playing clips directly.
		bridge.anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		bridge.anim_tree.active = true
		player.state = player.State.LOCOMOTION
		bridge.travel_locomotion(false, false)
		bridge.anim_tree.advance(.3)
		await process_frame
		await process_frame
		_assert_equipment(player, manny_skeleton, "Manny/tree-idle", "DEF-hand.")
		player.state = player.State.ATTACK_ACTIVE
		player.attack_heavy = false
		bridge.travel_light_attack()
		bridge.anim_tree.advance(.3)
		await process_frame
		await process_frame
		_assert_equipment(player, manny_skeleton, "Manny/tree-light", "DEF-hand.")
		var tree_pose: Transform3D = player.weapon_pivot.transform
		player._update_visual_pose()
		_expect(player.weapon_pivot.transform.is_equal_approx(tree_pose), "Manny tree-driven sword received a second swing")
		bridge.anim_tree.active = false
		bridge.real_layer_active = false
		manny_skeleton.reset_bone_poses()
		await process_frame
		await process_frame
	# Without a real clip, legacy attack gestures still compose around the hand.
	player.state = player.State.ATTACK_ACTIVE
	player.state_time = .3
	player.state_duration = .8
	player._update_visual_pose()
	_expect(absf(player.weapon_pivot.rotation.z) > .1, "Manny procedural swing was suppressed")
	if manny_skeleton != null:
		var hand_world := manny_skeleton.global_transform * manny_skeleton.get_bone_global_pose(manny_skeleton.find_bone("DEF-hand.R"))
		var grip: Vector3 = hand_world.affine_inverse() * player.weapon_pivot.global_position
		_expect(grip.y > .05 and grip.y < .1 and absf(grip.x) < .02, "Manny fallback gesture detached from palm")
	# Independent synthetic orientation ensures this assertion cannot pass merely
	# because a selected native clip happens to keep its hand upright.
	player.weapon_pivot.transform = Transform3D(Basis(Vector3.FORWARD, PI * .5), Vector3(.2, 1., -.3))
	player._trail_points.clear()
	player._update_weapon_trail()
	var expected_tip: Vector3 = player.weapon_pivot.transform * _authored_sword_tip(player)
	_expect(player._trail_points.size() == 1 and player._trail_points[0].distance_to(expected_tip) < .0001, "Rotated trail tip is not transformed")
	player.weapon_pivot.position.x += .2
	player._update_weapon_trail()
	var trail_mesh := player.weapon_trail.mesh as ArrayMesh
	var trail_material := player.weapon_trail.material_override as StandardMaterial3D
	_expect(player.weapon_trail.visible and trail_mesh != null and trail_mesh.get_surface_count() == 1, "Moving weapon did not build a visible ribbon surface")
	_expect(trail_material != null and trail_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and trail_material.vertex_color_use_as_albedo, "Ribbon material must render its vertex colors without generated normals")
	if trail_mesh != null and trail_mesh.get_surface_count() == 1:
		var arrays := trail_mesh.surface_get_arrays(0)
		_expect(trail_mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLE_STRIP and arrays[Mesh.ARRAY_VERTEX].size() == 4 and arrays[Mesh.ARRAY_COLOR].size() == 4, "Ribbon geometry lost its two vertices/colors per sampled tip")
	await _test_npc(stage, player)
	stage.queue_free()
	await process_frame
	if _failures.is_empty():
		print("%s checks=%d" % [SUCCESS_MARKER, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _assert_equipment(player, skeleton: Skeleton3D, label: String, hand_prefix := "hand.") -> void:
	for side: String in ["R", "L"]:
		var bone := skeleton.find_bone(hand_prefix + side)
		var hand_world := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var rest_world := skeleton.global_transform * skeleton.get_bone_global_rest(bone)
		var pivot: Node3D = player.weapon_pivot if side == "R" else player.offhand_weapon_pivot
		if hand_prefix == "DEF-hand.":
			var grip := hand_world.affine_inverse() * pivot.global_position
			_expect(grip.y > .05 and grip.y < .1 and absf(grip.x) < .02 and absf(grip.z) < .01, label + ": " + side + " grip outside palm")
			# Blade length follows the transverse thumb axis, not the palm normal.
			_expect(pivot.global_basis.y.normalized().dot(hand_world.basis.orthonormalized().z) > .999, label + ": " + side + " blade points through palm instead of along grip")
			_expect(pivot.global_basis.x.normalized().dot(hand_world.basis.x.normalized()) > .999, label + ": " + side + " blade plane is rolled relative to grip")
			if side == "L":
				_expect(player.shield_mesh.global_position.distance_to(hand_world.origin) < .0001, label + ": shield not on left wrist")
			continue
		_expect(pivot.global_position.distance_to(hand_world.origin) < .0001, label + ": " + side + " hand/pivot separation")
		# The relative rotation maps every rest-basis axis onto its posed axis.
		var frame: Basis = player.body_yaw.global_basis.orthonormalized()
		var world_delta: Basis = frame * pivot.basis * frame.inverse()
		var rest_axes := rest_world.basis.orthonormalized()
		var pose_axes := hand_world.basis.orthonormalized()
		_expect((world_delta * rest_axes).is_equal_approx(pose_axes), label + ": " + side + " rest-to-pose basis mismatch")
		if side == "L":
			_expect(player.shield_mesh.global_position.distance_to(hand_world.origin) < .0001, label + ": shield not on left hand")
			_expect(player.shield_mesh.basis.is_equal_approx(pivot.basis * Basis(Vector3.RIGHT, PI * .5)), label + ": shield grip-axis correction lost")


func _authored_sword_tip(player) -> Vector3:
	var meshes: Array[Node] = player.weapon_pivot.find_children("Sword", "MeshInstance3D", true, false)
	if meshes.is_empty():
		_expect(false, "Default sword geometry unavailable for independent tip check")
		return Vector3.ZERO
	var sword := meshes[0] as MeshInstance3D
	var to_pivot: Transform3D = player.weapon_pivot.global_transform.affine_inverse() * sword.global_transform
	var tip := Vector3.ZERO
	var highest := -INF
	for surface in sword.mesh.get_surface_count():
		var arrays := sword.mesh.surface_get_arrays(surface)
		for point: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var at := to_pivot * point
			if at.y > highest:
				highest = at.y
				tip = at
	_expect(highest > .5 and highest < .6, "Default sword's real blade reach changed unexpectedly")
	return tip


func _test_npc(stage: Node3D, player: Node) -> void:
	var npc = NpcScript.new()
	stage.add_child(npc)
	npc.set_process(false)
	_expect(Resolver.try_instance("npc/npc_cloud_wanderer", npc), "NPC fixture failed to instance")
	await process_frame
	await process_frame
	var model := npc.get_node_or_null("ModelRoot") as Node3D
	var animation := _animation(model)
	if model == null or animation == null:
		_expect(false, "NPC fixture missing native player")
		return
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	model.rotation = Vector3(.07, .2, -.1)
	var wrapper := model.transform
	npc._process(.2)
	_expect(model.transform.is_equal_approx(wrapper), "NPC procedural movement overwrote native wrapper")
	_expect(npc.get_node_or_null("ModelAmbient") != null, "NPC lost ambient VFX")
	var events := {"callback": 0, "signal": 0, "actor_ok": true}
	npc.world_callback = func(who: Node, actor: Node) -> void:
		events["callback"] += 1
		events["actor_ok"] = events["actor_ok"] and who == npc and actor == player
	npc.talk_requested.connect(func(id: StringName, actor: Node) -> void:
		events["signal"] += 1
		events["actor_ok"] = events["actor_ok"] and id == npc.npc_id and actor == player)
	npc.interact(player)
	_expect(String(animation.assigned_animation).get_file() == "interact", "NPC interaction did not select native clip")
	_expect(events["callback"] == 1 and events["signal"] == 1 and events["actor_ok"], "NPC interaction callbacks changed")
	animation.advance(animation.get_animation(animation.assigned_animation).length + .1)
	_expect(String(animation.assigned_animation).get_file() == "idle", "NPC did not return to idle")
	# Legacy/no-model interaction retains both callbacks without a native driver.
	model.free()
	npc.interact(player)
	_expect(events["callback"] == 2 and events["signal"] == 2, "NPC fallback interaction lost callbacks")


func _hands(node: Node, hand_prefix := "hand.") -> Skeleton3D:
	for candidate in node.find_children("*", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton.find_bone(hand_prefix + "R") >= 0 and skeleton.find_bone(hand_prefix + "L") >= 0:
			return skeleton
	return null


func _animation(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	for candidate in node.find_children("*", "AnimationPlayer", true, false):
		var animation := candidate as AnimationPlayer
		if animation.active:
			return animation
	return null


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
