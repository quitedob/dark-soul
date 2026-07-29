extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HudScript = preload("res://scripts/hud.gd")
const CheckpointScript = preload("res://scripts/checkpoint.gd")
const ShortcutScript = preload("res://scripts/shortcut.gd")
const LostEchoScript = preload("res://scripts/lost_echo.gd")
const AudioScript = preload("res://scripts/procedural_audio.gd")

var player
var hud
var audio
var checkpoint
var enemies: Array = []
var respawn_position := Vector3(0.0, 1.1, 9.0)
var lost_echo
var guardian
var victory := false
var materials: Dictionary = {}
var world_environment: WorldEnvironment


func _ready() -> void:
	_configure_inputs()
	_create_materials()
	_create_environment()
	_create_level()
	_create_systems()
	if "--smoke-test" in OS.get_cmdline_user_args():
		get_tree().create_timer(2.0).timeout.connect(_run_smoke_test)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var nearest: Node = null
	var nearest_distance := 3.0
	for interactable in get_tree().get_nodes_in_group("interactable"):
		if interactable is Node3D and is_instance_valid(interactable):
			var distance: float = player.global_position.distance_to(interactable.global_position)
			if distance < nearest_distance:
				nearest = interactable
				nearest_distance = distance
	player.set_interaction(nearest)
	if hud != null:
		hud.set_prompt(nearest.get_prompt() if nearest != null and nearest.has_method("get_prompt") else "")


func _create_systems() -> void:
	audio = AudioScript.new()
	audio.name = "ProceduralAudio"
	add_child(audio)

	hud = HudScript.new()
	hud.name = "HUD"
	add_child(hud)

	player = PlayerScript.new()
	player.name = "Warden"
	player.position = respawn_position
	add_child(player)
	player.setup(self, audio, hud)
	hud.setup(player)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(hud.update_stats)
	player.embers_changed.connect(hud.update_embers)
	player.lock_target_changed.connect(hud.set_lock_target)

	checkpoint = CheckpointScript.new()
	checkpoint.name = "EmberShrine"
	checkpoint.position = Vector3(0.0, 0.0, 6.0)
	add_child(checkpoint)
	checkpoint.setup(self, "Ember Shrine")

	var gate := _create_gate(Vector3(0.0, 1.5, -5.6))
	var lever = ShortcutScript.new()
	lever.name = "AncientLever"
	lever.position = Vector3(-8.0, 0.0, -5.0)
	add_child(lever)
	lever.setup(gate, self)

	_spawn_enemy(Vector3(-4.0, 0.95, 0.0), false)
	_spawn_enemy(Vector3(4.0, 0.95, -8.0), false)
	_spawn_enemy(Vector3(-7.0, 0.95, -12.0), false)
	guardian = _spawn_enemy(Vector3(0.0, 1.15, -24.0), true)
	_show_intro.call_deferred()


func _show_intro() -> void:
	hud.show_message("ASHEN HOLLOW\nReach the sealed guardian beyond the ruins.", 4.0)


func _spawn_enemy(spawn_position: Vector3, is_guardian: bool):
	var enemy = EnemyScript.new()
	enemy.name = "HollowSentinel" if not is_guardian else "CinderGuardian"
	enemy.position = spawn_position
	add_child(enemy)
	enemy.setup(self, player, audio, spawn_position, is_guardian)
	enemy.defeated.connect(_on_enemy_defeated)
	enemy.engagement_changed.connect(_on_enemy_engagement_changed)
	enemy.health_changed.connect(_on_guardian_health_changed.bind(enemy))
	enemies.append(enemy)
	return enemy


func rest_at_checkpoint(shrine: Node3D, _interacting_player: Node = null) -> void:
	respawn_position = shrine.global_position + Vector3(0.0, 1.1, 2.0)
	player.heal_full()
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.reset_enemy()
	audio.play_cue("rest", -4.0)
	hud.show_message("EMBER RESTORED\nEnemies return to the hollow.", 2.5)


func open_shortcut(gate: Node3D) -> void:
	hud.show_message("SHORTCUT OPENED", 2.0)
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(gate, "position:y", gate.position.y + 4.5, 1.8)


func shortcut_opened(_shortcut: Node, _gate: Node3D, _interacting_player: Node) -> void:
	audio.play_cue("rest", -7.0, 0.75)
	hud.show_message("SHORTCUT OPENED", 2.0)


func recover_lost_echo(amount: int, _recovering_player: Node = null) -> void:
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
	lost_echo = null
	player.recover_embers(amount)
	audio.play_cue("recover", -3.0)
	hud.show_message("LOST EMBERS RECOVERED  +%d" % amount, 2.0)


func _on_player_died(death_position: Vector3) -> void:
	var lost_amount: int = int(player.lose_embers())
	if lost_echo != null and is_instance_valid(lost_echo):
		lost_echo.queue_free()
	if lost_amount > 0:
		lost_echo = LostEchoScript.new()
		lost_echo.name = "LostEcho"
		lost_echo.position = death_position + Vector3.UP * 0.35
		add_child(lost_echo)
		lost_echo.setup(lost_amount, self)
	hud.show_death()
	await get_tree().create_timer(2.2).timeout
	player.respawn_at(respawn_position)
	hud.clear_death()
	hud.show_message("RISE AGAIN", 1.5)


func _on_enemy_defeated(enemy, reward: int, is_guardian: bool) -> void:
	player.add_embers(reward)
	if is_guardian and not victory:
		victory = true
		hud.hide_boss()
		hud.show_victory()
		audio.play_cue("victory", -2.0)
	else:
		hud.show_message("EMBER CLAIMED  +%d" % reward, 1.2)


func _on_enemy_engagement_changed(enemy, is_guardian: bool, engaged: bool) -> void:
	if not is_guardian:
		return
	if engaged and enemy.is_targetable():
		hud.show_boss("CINDER GUARDIAN", enemy.health, enemy.max_health)
	else:
		hud.hide_boss()


func _on_guardian_health_changed(current: float, maximum: float, enemy) -> void:
	if enemy == guardian and is_instance_valid(enemy) and enemy.engaged:
		hud.show_boss("CINDER GUARDIAN", current, maximum)


func get_target_candidates() -> Array[Node]:
	var candidates: Array[Node] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.is_targetable():
			candidates.append(enemy)
	return candidates


func _create_environment() -> void:
	world_environment = WorldEnvironment.new()
	world_environment.name = "NightEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("07101a")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("52708a")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.fog_enabled = true
	environment.fog_light_color = Color("28405a")
	environment.fog_light_energy = 0.35
	environment.fog_density = 0.012
	world_environment.environment = environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	moon.light_color = Color("9db9d2")
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	add_child(moon)

	var warm_light := OmniLight3D.new()
	warm_light.name = "ShrineGlow"
	warm_light.position = Vector3(0.0, 2.4, 6.0)
	warm_light.light_color = Color("ff7738")
	warm_light.light_energy = 5.0
	warm_light.omni_range = 9.0
	warm_light.shadow_enabled = true
	add_child(warm_light)


func _create_materials() -> void:
	materials["stone"] = _material(Color("27303a"), 0.92, 0.05)
	materials["stone_dark"] = _material(Color("121922"), 0.98, 0.02)
	materials["metal"] = _material(Color("303a43"), 0.46, 0.72)
	materials["ember"] = _material(Color("ff5a24"), 0.35, 0.0, Color("ff3a12"), 3.2)
	materials["moss"] = _material(Color("203a31"), 0.95, 0.0)
	materials["void"] = _material(Color("05070c"), 1.0, 0.0)


func _create_level() -> void:
	_create_block(Vector3(0.0, -0.5, -8.0), Vector3(24.0, 1.0, 38.0), "stone_dark")
	_create_block(Vector3(0.0, -0.2, -27.0), Vector3(18.0, 0.6, 14.0), "stone")
	_create_block(Vector3(-9.0, 2.0, -8.0), Vector3(1.0, 5.0, 38.0), "stone")
	_create_block(Vector3(9.0, 2.0, -8.0), Vector3(1.0, 5.0, 38.0), "stone")
	_create_block(Vector3(0.0, 2.0, 11.0), Vector3(19.0, 5.0, 1.0), "stone")
	_create_block(Vector3(-5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(5.5, 1.1, 2.0), Vector3(5.0, 2.7, 1.0), "stone")
	_create_block(Vector3(-3.6, 1.2, -5.5), Vector3(6.0, 3.0, 1.0), "stone")
	_create_block(Vector3(5.0, 1.2, -5.5), Vector3(5.0, 3.0, 1.0), "stone")
	_create_block(Vector3(0.0, 1.6, -18.5), Vector3(10.0, 3.8, 1.0), "stone")
	_create_block(Vector3(-6.5, 1.6, -18.5), Vector3(2.0, 3.8, 1.0), "stone")
	_create_block(Vector3(6.5, 1.6, -18.5), Vector3(2.0, 3.8, 1.0), "stone")
	for z_position in [-2.0, -10.0, -17.0, -28.0]:
		_create_pillar(Vector3(-7.4, 1.7, z_position))
		_create_pillar(Vector3(7.4, 1.7, z_position))
	_create_block(Vector3(-7.0, 0.2, -7.8), Vector3(3.0, 0.5, 2.5), "moss")
	_create_block(Vector3(6.5, 0.2, -14.0), Vector3(2.6, 0.5, 3.5), "moss")
	_create_landmark()
	_create_boundary_fog()


func _create_landmark() -> void:
	var spire := MeshInstance3D.new()
	spire.name = "BrokenSpire"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 1.4
	mesh.height = 13.0
	mesh.radial_segments = 7
	mesh.material = materials["stone"]
	spire.mesh = mesh
	spire.position = Vector3(0.0, 6.0, -37.0)
	spire.rotation_degrees.z = -7.0
	add_child(spire)
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0.0, 9.5, -37.0)
	beacon.light_color = Color("f14b28")
	beacon.light_energy = 7.0
	beacon.omni_range = 18.0
	add_child(beacon)


func _create_boundary_fog() -> void:
	for side in [-1.0, 1.0]:
		var veil := MeshInstance3D.new()
		var plane := QuadMesh.new()
		plane.size = Vector2(14.0, 5.0)
		plane.material = _material(Color(0.08, 0.14, 0.2, 0.55), 1.0, 0.0, Color("1d3852"), 0.6, true)
		veil.mesh = plane
		veil.position = Vector3(side * 10.0, 2.0, -26.0)
		veil.rotation_degrees.y = 90.0
		add_child(veil)


func _create_pillar(at: Vector3) -> void:
	_create_block(at, Vector3(1.1, 3.4, 1.1), "stone")
	_create_block(at + Vector3(0.0, 1.9, 0.0), Vector3(1.6, 0.35, 1.6), "stone")


func _create_gate(at: Vector3) -> Node3D:
	var gate := Node3D.new()
	gate.name = "ShortcutGate"
	gate.position = at
	add_child(gate)
	for offset in [-1.6, -0.8, 0.0, 0.8, 1.6]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 3.0, 0.3)
		mesh.material = materials["metal"]
		bar.mesh = mesh
		bar.position = Vector3(offset, 0.0, 0.0)
		gate.add_child(bar)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.0, 3.0, 0.5)
	shape.shape = box
	body.add_child(shape)
	gate.add_child(body)
	return gate


func _create_block(at: Vector3, size: Vector3, material_name: String) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = 1
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = materials[material_name]
	visual.mesh = mesh
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	return body


func _material(color: Color, roughness: float, metallic: float, emission := Color.BLACK, emission_energy := 0.0, transparent := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _configure_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("dodge", KEY_SPACE)
	_add_key_action("lock_on", KEY_Q)
	_add_key_action("interact", KEY_E)
	_add_key_action("light_attack_alt", KEY_J)
	_add_key_action("heavy_attack_alt", KEY_K)
	_add_key_action("help", KEY_F1)
	_add_mouse_action("light_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("heavy_attack", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("lock_on", MOUSE_BUTTON_MIDDLE)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)


func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)


func _run_smoke_test() -> void:
	if player == null or hud == null or enemies.is_empty():
		push_error("Smoke test failed: systems missing")
		get_tree().quit(1)
		return
	player.add_embers(3)
	player.receive_hit(5.0, 0.0, Vector3.FORWARD, null)
	player.heal_full()
	enemies[0].receive_hit(5.0, 0.0, Vector3.BACK, player)
	hud.set_prompt("Smoke interaction")
	if not hud.is_prompt_visible():
		push_error("Smoke test failed: interaction prompt did not appear")
		get_tree().quit(1)
		return
	hud.set_prompt("")
	hud.show_boss("Smoke Guardian", 50.0, 100.0)
	if not hud.is_boss_visible():
		push_error("Smoke test failed: boss HUD did not appear")
		get_tree().quit(1)
		return
	hud.hide_boss()
	hud.show_death()
	if not hud.is_death_visible():
		push_error("Smoke test failed: death overlay did not appear")
		get_tree().quit(1)
		return
	hud.clear_death()
	if hud.is_death_visible():
		push_error("Smoke test failed: death overlay did not clear")
		get_tree().quit(1)
		return
	hud.show_message("HUD SMOKE", 0.35)
	print("ASHEN_HOLLOW_SMOKE_OK")
	await get_tree().create_timer(1.2).timeout
	get_tree().quit(0)
