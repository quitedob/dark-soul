extends Node3D
## Physical evidence belongs to its authored room and persists through the run.
const Dressing = preload("res://scripts/data/campaign_scene_dressing.gd")
const Clue = preload("res://scripts/world/furnace_memory_crystal.gd")
const Copy = preload("res://scripts/ui/hud_theme.gd")
const CLUES := {
	"level_01_04": ["keeper_rune"],
	"level_02_03": ["cage_key_1", "cage_key_2", "cage_key_3"],
	"level_03_02": ["true_memory_1", "true_memory_2", "true_memory_3"],
	"level_03_05": ["true_mirror"],
	"level_04_03": ["xuanxiao_record"],
}
const LABELS := {
	"keeper_rune": ["取出守炉符文", "Take the Keeper Rune"],
	"cage_key_1": ["取回第一把笼钥", "Recover the First Cage Key"],
	"cage_key_2": ["取回第二把笼钥", "Recover the Second Cage Key"],
	"cage_key_3": ["取回第三把笼钥", "Recover the Third Cage Key"],
	"true_memory_1": ["辨认铸炉者的记忆", "Identify the Forger's Memory"],
	"true_memory_2": ["辨认流亡者的记忆", "Identify the Exile's Memory"],
	"true_memory_3": ["辨认守望者的记忆", "Identify the Watcher's Memory"],
	"true_mirror": ["取下真实之镜", "Claim the Mirror of Truth"],
	"xuanxiao_record": ["读取未改写的天界实录", "Read the Unaltered Celestial Record"],
}
var world: Node
var level_id := ""
var forge_seal: StaticBody3D
var seal_interaction: Area3D

func setup(owner_world: Node, id: String) -> void:
	world = owner_world
	level_id = id
	var anchors := Dressing.story_anchors(id)
	if id == "level_02_03" and not bool(world.run_state.get_choice_flag("iron_forge_seal_broken", false)):
		_build_forge_seal(anchors["iron_heart_cage"])
	for key: String in CLUES.get(id, []):
		if world.has_story_item(key):
			continue
		var clue = Clue.new()
		clue.name = "StoryEvidence_" + key
		clue.memory_key = key
		var labels: Array = LABELS[key]
		clue.prompt_text = Copy.copy(String(labels[0]), String(labels[1]))
		clue.world_callback = Callable(self, "_claim")
		clue.collision_layer = 8
		clue.collision_mask = 0
		clue.monitoring = false
		clue.add_to_group("interactable")
		clue.add_to_group("campaign_story_evidence")
		clue.set_meta("story_source", Dressing.story_source(id))
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 1.1
		shape.shape = sphere
		shape.position.y = .75
		clue.add_child(shape)
		add_child(clue)
		clue.position = anchors[key]
		_add_evidence_visual(clue, key)

func _claim(clue: Node3D, actor: Node) -> void:
	if not is_instance_valid(world) or actor != world.player or clue.get_parent() != self:
		return
	if actor.global_position.distance_to(clue.global_position) > 3.6 or float(actor.health) <= 0.0:
		return
	var key := String(clue.memory_key)
	if key not in CLUES.get(level_id, []) or world.has_story_item(key):
		return
	world.run_state.inventory[key] = 1
	if key not in world.run_state.collected_loot:
		world.run_state.collected_loot.append(key)
	world.run_state.set_choice_flag("evidence_" + key, true)
	world._save_run("story_evidence_" + key)
	var labels: Array = LABELS[key]
	world.hud.show_message(Copy.copy(String(labels[0]), String(labels[1])), 2.8)
	world.audio.play_cue("rest", -5.0, 1.1)
	clue.queue_free()


func _build_forge_seal(cage_position: Vector3) -> void:
	forge_seal = StaticBody3D.new()
	forge_seal.name = "ForcedForgeSeal"
	forge_seal.position = cage_position + Vector3(0, 0, 1.86)
	forge_seal.collision_layer = 1
	forge_seal.collision_mask = 0
	forge_seal.add_to_group("campaign_navigation_source")
	add_child(forge_seal)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.95, 2.9, .2)
	collision.shape = box
	collision.position.y = 1.45
	forge_seal.add_child(collision)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("51382f")
	iron.metallic = .7
	for index in 5:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.12, 2.9, .18)
		bar.mesh = mesh
		bar.material_override = iron
		bar.position = Vector3((index - 2) * .42, 1.45, 0)
		forge_seal.add_child(bar)
	seal_interaction = Clue.new()
	seal_interaction.name = "ReleaseForgeSeal"
	seal_interaction.prompt_text = Copy.copy("用三把笼钥解除强制锻造印", "Use three cage keys to break the forced-forge seal")
	seal_interaction.world_callback = _release_forge_seal
	seal_interaction.collision_layer = 8
	seal_interaction.collision_mask = 0
	seal_interaction.add_to_group("interactable")
	forge_seal.add_child(seal_interaction)
	var trigger := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	trigger.shape = sphere
	trigger.position = Vector3(0, 1.1, .5)
	seal_interaction.add_child(trigger)
	# Three visible locks correspond to three actual items, not a dialogue flag.
	for index in 3:
		var lock_root := Node3D.new()
		lock_root.position = Vector3((index - 1) * .52, .4, .18)
		lock_root.scale = Vector3.ONE * .45
		forge_seal.add_child(lock_root)
		_add_evidence_visual(lock_root, "cage_key_" + str(index + 1))


func _release_forge_seal(area: Node, actor: Node) -> void:
	if area != seal_interaction or actor != world.player or not is_instance_valid(forge_seal):
		return
	if actor.global_position.distance_to(forge_seal.global_position) > 3.6 or float(actor.health) <= 0.:
		return
	if bool(world.run_state.get_choice_flag("iron_forge_seal_broken", false)):
		return
	for index in range(1, 4):
		if not world.has_story_item("cage_key_" + str(index)):
			world.hud.show_message(Copy.copy("军印未解：营地中还有笼钥。", "The military seal holds. Another cage key remains in the camp."), 2.5)
			return
	world.run_state.set_choice_flag("iron_forge_seal_broken", true)
	world._save_run("forced_forge_released")
	seal_interaction.remove_from_group("interactable")
	seal_interaction.set_deferred("collision_layer", 0)
	for shape: CollisionShape3D in forge_seal.find_children("*", "CollisionShape3D", true, false):
		shape.set_deferred("disabled", true)
	create_tween().tween_property(forge_seal, "position:y", forge_seal.position.y + 3.2, 1.2)
	world.call_deferred("_generate_navigation")
	world.hud.show_message(Copy.copy("军印断开了。铁心终于可以停下锻锤。", "The seal breaks. Iron Heart can finally lay down his hammer."), 3.0)

func _add_evidence_visual(clue: Node3D, key: String) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("344147")
	stone.roughness = .85
	var pedestal := MeshInstance3D.new()
	var base := CylinderMesh.new()
	base.top_radius = .42
	base.bottom_radius = .56
	base.height = .55
	base.radial_segments = 8
	pedestal.mesh = base
	pedestal.material_override = stone
	pedestal.position.y = .275
	clue.add_child(pedestal)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("cda657") if key.begins_with("cage_key") else Color("78beba")
	brass.metallic = .65
	brass.roughness = .25
	brass.emission_enabled = true
	brass.emission = brass.albedo_color
	brass.emission_energy_multiplier = .5
	var seal := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = .12 if key.begins_with("cage_key") else .27
	ring.outer_radius = .20 if key.begins_with("cage_key") else .38
	ring.rings = 20
	ring.ring_segments = 10
	seal.mesh = ring
	seal.material_override = brass
	seal.position.y = .98
	seal.rotation.x = PI * .5
	clue.add_child(seal)
	if key == "true_mirror":
		var mirror := MeshInstance3D.new()
		var face := CylinderMesh.new()
		face.top_radius = .29
		face.bottom_radius = .29
		face.height = .04
		mirror.mesh = face
		mirror.material_override = brass
		mirror.position.y = .98
		mirror.rotation.x = PI * .5
		clue.add_child(mirror)
	elif key.begins_with("cage_key"):
		var stem := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.08, .32, .08)
		stem.mesh = mesh
		stem.material_override = brass
		stem.position.y = .72
		clue.add_child(stem)
