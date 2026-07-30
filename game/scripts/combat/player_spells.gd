class_name PlayerSpells
extends RefCounted
## Spell casting, projectile spawning, and weapon-skill execution for the player.
## Composition helper — takes a player node reference and delegates spell logic.

const SpellProjectileScene = preload("res://scenes/components/spell_projectile.tscn")
const LocalizationScript = preload("res://scripts/core/localization.gd")
const CombatData = preload("res://scripts/data/player_combat_data.gd")

var _player: Node3D
var _world_node: Node


func setup(player_node: Node3D, world_node: Node) -> void:
	_player = player_node
	_world_node = world_node


# -- public API ------------------------------------------------------------


func try_cast_for_style(combat_style: int) -> String:
	## Returns the cast_id if a spell was begun, or "" if a style skill should be used.
	match combat_style:
		3: # VEILCRAFT
			begin_cast(&"veil_bolt", CombatData.SPELL_CONFIG["veil_bolt"]["focus_cost"], CombatData.SPELL_CONFIG["veil_bolt"]["cast_time"])
			return "veil_bolt"
		4: # EMBER_RITE
			begin_cast(&"ember_rite", CombatData.SPELL_CONFIG["ember_rite"]["focus_cost"], CombatData.SPELL_CONFIG["ember_rite"]["cast_time"])
			return "ember_rite"
		_:
			return ""


func begin_cast(cast_id: StringName, focus_cost: float, duration: float) -> bool:
	if _player.focus < focus_cost:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - focus_cost, 0.0)
	_player._emit_focus()
	if cast_id == &"ember_rite":
		_player.healing_started.emit()
	_player._pending_cast = cast_id
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, duration)
	return true


func resolve_cast(pending_cast: StringName) -> void:
	var config: Dictionary = CombatData.SPELL_CONFIG.get(String(pending_cast), {})
	match pending_cast:
		&"veil_bolt", &"bow_quick_shot", &"bow_power_shot", &"seal_burst":
			spawn_spell_projectile(config, String(pending_cast))
			_player._play_audio("recover", -6.0, 1.3)
		&"arcane_barrage":
			for i in range(5):
				var spread_angle := deg_to_rad(-16.0 + float(i) * 8.0)
				var base_dir: Vector3 = -_player.camera.global_transform.basis.z
				var spread_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_angle).normalized()
				var barrage_config := config.duplicate()
				barrage_config["proj_lifetime"] = config["proj_lifetime"] + randf_range(-0.15, 0.15)
				spawn_spell_projectile(barrage_config, "arcane_barrage", spread_dir)
			_player._show_message("ARCANE BARRAGE", 0.7)
			_player._play_audio("recover", -5.0, 1.1)
		&"divine_smite":
			spawn_spell_projectile(config, "divine_smite")
			_player._show_message("DIVINE SMITE", 0.7)
			_player._play_audio("heavy", -5.0, 0.9)
		&"ember_rite":
			var heal_amount: float = config.get("heal", 28.0)
			var aoe_damage: float = config.get("aoe_damage", 22.0)
			var aoe_stagger: float = config.get("aoe_stagger", 20.0)
			var aoe_range: float = config.get("aoe_range", 6.0)
			_player.health = minf(_player.health + heal_amount, _player.max_health)
			_player._emit_stats()
			if _world_node != null and _world_node.has_method("get_target_candidates"):
				for candidate in _world_node.get_target_candidates():
					if candidate is Node3D and _player.global_position.distance_to(candidate.global_position) <= aoe_range:
						var direction: Vector3 = (
							candidate.global_position - _player.global_position
						).normalized()
						candidate.receive_hit(aoe_damage, aoe_stagger, direction, _player)
			_player._show_message(LocalizationScript.text("EMBER RITE CAST"), 0.75)
			_player._play_audio("rest", -4.0, 0.82)


func spawn_spell_projectile(config: Dictionary, action_id: String, override_direction: Vector3 = Vector3.ZERO) -> void:
	var projectile = SpellProjectileScene.instantiate()
	var cast_direction: Vector3 = override_direction if override_direction.length_squared() > 0.001 else -_player.camera.global_transform.basis.z
	var lock_target: Node3D = _player.lock_target
	if lock_target != null and is_instance_valid(lock_target) and override_direction.length_squared() < 0.001:
		var target_point: Vector3 = (
			lock_target.get_target_point()
			if lock_target.has_method("get_target_point")
			else lock_target.global_position
		)
		cast_direction = (
			target_point
			- (_player.global_position + Vector3.UP * 1.25)
		).normalized()

	var item_id: String = _player.right_hand_item
	var proj_damage: float = config.get("damage", 28.0)
	var proj_stagger: float = config.get("stagger", 18.0)

	var homing: Node3D = null
	if bool(config.get("homing", false)) and lock_target != null and is_instance_valid(lock_target):
		homing = lock_target

	var is_spell := action_id in ["veil_bolt", "seal_burst", "arcane_barrage", "divine_smite"]

	projectile.setup(_player, cast_direction, proj_damage, proj_stagger, {
		"hand": "right",
		"item_id": item_id,
		"action_id": action_id,
		"tags": ["projectile", "spell" if is_spell else "physical"],
		"blockable": true,
		"parryable": false,
		"spell_type": String(config.get("spell_type", "default")),
		"proj_speed": float(config.get("proj_speed", 15.0)),
		"proj_lifetime": float(config.get("proj_lifetime", 2.2)),
		"homing_target": homing,
		"homing_strength": float(config.get("homing_strength", 0.0)),
	})

	var projectile_parent: Node = (
		_world_node
		if _world_node != null and _world_node.is_inside_tree()
		else _player.get_tree().current_scene
	)
	projectile_parent.add_child(projectile)
	projectile.global_position = _player.global_position + Vector3.UP * 1.25 + cast_direction * 0.8

	var message_key := "VEIL BOLT"
	if action_id == "bow_quick_shot" or action_id == "bow_power_shot":
		message_key = "QUICK SHOT" if action_id == "bow_quick_shot" else "POWER SHOT"
	elif action_id == "seal_burst":
		message_key = "SEAL BURST"
	elif action_id == "arcane_barrage":
		message_key = "ARCANE BARRAGE"
	elif action_id == "divine_smite":
		message_key = "DIVINE SMITE"
	_player._show_message(message_key, 0.6)


func try_arcane_barrage() -> bool:
	var cfg: Dictionary = CombatData.SPELL_CONFIG["arcane_barrage"]
	if _player.focus < cfg["focus_cost"]:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - cfg["focus_cost"], 0.0)
	_player._emit_focus()
	_player._pending_cast = &"arcane_barrage"
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, 0.55)
	return true


func try_divine_smite() -> bool:
	var cfg: Dictionary = CombatData.SPELL_CONFIG["divine_smite"]
	if _player.focus < cfg["focus_cost"]:
		_player._show_message(LocalizationScript.text("NOT ENOUGH FOCUS"), 0.8)
		return false
	_player.focus = maxf(_player.focus - cfg["focus_cost"], 0.0)
	_player._emit_focus()
	_player._pending_cast = &"divine_smite"
	_player._cast_resolved = false
	_player._change_state(_player.State.CAST, 0.68)
	return true
