class_name SpiritSummon
extends Node3D
## L-06 召唤物：祝祷师灵符五灵，按 kind 差异化行为。
## 护法灵童=嘲讽坦克 / 金甲力士=高防肉盾 / 往生莲=治疗图腾 /
## 怨灵=玻璃大炮 DPS / 白鹤童子=专注支援（飞行、法术回复加速）
## 敌人通过 receive_hit 直接结算对召唤物的伤害；target_node 由敌 FSM 覆盖。

signal despawned(summon)

const LocalizationScript = preload("res://scripts/core/localization.gd")

var player: Node3D
var world_node: Node
var kind_id := &"dharma_child"
var display_name := "护法灵童"
var max_health := 60.0
var health := 60.0
var damage := 8.0
var stagger := 10.0
var attack_interval := 1.2
var leash_distance := 4.5
var taunt_radius := 0.0
var heal_rate := 0.0
var heal_radius := 0.0
var focus_regen_multiplier := 1.0

var _lifetime_left := 20.0
var _attack_timer := 0.0
var _heal_timer := 0.0
var _target: Node3D = null
var _dead := false
var _visual: MeshInstance3D = null
var _floating_base_y := 0.9

const KIND_DATA := {
	"dharma_child": {
		"display_name": "护法灵童", "max_health": 60.0, "damage": 8.0, "stagger": 12.0,
		"attack_interval": 1.0, "taunt_radius": 7.0, "color": Color("ffcc44"),
		"shape": "capsule", "scale": 0.7,
	},
	"golden_guardian": {
		"display_name": "金甲力士", "max_health": 120.0, "damage": 14.0, "stagger": 18.0,
		"attack_interval": 1.4, "taunt_radius": 5.0, "color": Color("ccaa55"),
		"shape": "box", "scale": 1.2,
	},
	"rebirth_lotus": {
		"display_name": "往生莲", "max_health": 40.0, "damage": 0.0, "stagger": 0.0,
		"attack_interval": 0.0, "heal_rate": 4.0, "heal_radius": 6.0,
		"color": Color("66ffcc"), "shape": "sphere", "scale": 0.9, "floating": 0.3,
	},
	"resentful_spirit": {
		"display_name": "怨灵", "max_health": 50.0, "damage": 26.0, "stagger": 22.0,
		"attack_interval": 0.9, "color": Color("cc66ff"), "shape": "capsule", "scale": 0.8,
	},
	"white_crane": {
		"display_name": "白鹤童子", "max_health": 45.0, "damage": 12.0, "stagger": 14.0,
		"attack_interval": 1.1, "focus_regen_multiplier": 1.5, "floating": 1.6,
		"color": Color("eeeeff"), "shape": "capsule", "scale": 0.7,
	},
}


func setup(kind: StringName, owner: Node3D, world: Node) -> void:
	kind_id = kind
	player = owner
	world_node = world
	var data: Dictionary = KIND_DATA.get(String(kind), KIND_DATA["dharma_child"])
	display_name = String(data.get("display_name", "灵"))
	max_health = float(data.get("max_health", 60.0))
	health = max_health
	damage = float(data.get("damage", 8.0))
	stagger = float(data.get("stagger", 10.0))
	attack_interval = float(data.get("attack_interval", 1.2))
	leash_distance = float(data.get("leash_distance", 4.5))
	taunt_radius = float(data.get("taunt_radius", 0.0))
	heal_rate = float(data.get("heal_rate", 0.0))
	heal_radius = float(data.get("heal_radius", 0.0))
	focus_regen_multiplier = float(data.get("focus_regen_multiplier", 1.0))
	_lifetime_left = float(data.get("lifetime", 20.0))
	_floating_base_y = float(data.get("floating", 0.9))
	_build_visual(data)
	# 白鹤童子：场时专注回复提升
	if focus_regen_multiplier > 1.0 and player != null and is_instance_valid(player):
		player.focus_regen_multiplier = focus_regen_multiplier
	set_process(true)


func _process(delta: float) -> void:
	if _dead:
		return
	if player == null or not is_instance_valid(player):
		_despawn()
		return
	_lifetime_left -= delta
	if _lifetime_left <= 0.0:
		_despawn()
		return
	_tick_behavior(delta)


func _tick_behavior(delta: float) -> void:
	if heal_rate > 0.0:
		# 往生莲：原地治疗图腾
		_heal_timer += delta
		if _heal_timer >= 1.0:
			_heal_timer = 0.0
			_heal_player()
		_visual.rotation.y += delta * 0.8
		return
	_update_movement(delta)
	_update_target()
	if taunt_radius > 0.0:
		_taunt_nearby()
	_attack_timer -= delta
	if _attack_timer <= 0.0 and _target != null and is_instance_valid(_target):
		_attack_timer = attack_interval
		_perform_attack(_target)
	_flicker_visual(delta)


func _update_movement(delta: float) -> void:
	if _target != null and is_instance_valid(_target):
		var to_target := _target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 1.8:
			global_position += to_target.normalized() * (2.6 * delta)
	elif player != null:
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length() > leash_distance:
			global_position += to_player.normalized() * (2.8 * delta)
	if player != null:
		global_position.y = lerpf(global_position.y, player.global_position.y + _floating_base_y, 0.2)


func _update_target() -> void:
	_target = null
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return
	var nearest: Node3D = null
	var nearest_dist := 12.0
	for candidate in world_node.get_target_candidates():
		var dist: float = global_position.distance_to(candidate.global_position)
		if dist < nearest_dist:
			nearest = candidate
			nearest_dist = dist
	_target = nearest


func _taunt_nearby() -> void:
	if world_node == null or not world_node.has_method("get_target_candidates"):
		return
	for candidate in world_node.get_target_candidates():
		if global_position.distance_to(candidate.global_position) <= taunt_radius and "target_node" in candidate:
			candidate.target_node = self


func _perform_attack(target: Node3D) -> void:
	if damage <= 0.0 or not target.has_method("receive_hit"):
		return
	var dir := (target.global_position - global_position).normalized()
	# 面向目标轻微抖动，方便观察
	if _visual != null:
		_visual.rotation.y += 0.15
	target.receive_hit(damage, stagger, dir, self)


func _heal_player() -> void:
	if heal_rate <= 0.0 or player == null or not is_instance_valid(player):
		return
	if global_position.distance_to(player.global_position) <= heal_radius and player.has_method("heal"):
		player.heal(heal_rate)


func _build_visual(data: Dictionary) -> void:
	_visual = MeshInstance3D.new()
	_visual.name = "SummonBody"
	var prim: PrimitiveMesh
	var scale_f := float(data.get("scale", 1.0))
	match String(data.get("shape", "capsule")):
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5 * scale_f
			sphere.height = 1.0 * scale_f
			prim = sphere
		"box":
			var box := BoxMesh.new()
			box.size = Vector3(1.1, 1.8, 0.9) * scale_f
			prim = box
		_:
			var cap := CapsuleMesh.new()
			cap.radius = 0.35 * scale_f
			cap.height = 1.4 * scale_f
			prim = cap
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.get("color", Color.WHITE)
	mat.emission_enabled = true
	mat.emission = data.get("color", Color.WHITE)
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.9
	prim.material = mat
	_visual.mesh = prim
	_visual.position = Vector3(0.0, 1.0 * scale_f, 0.0)
	add_child(_visual)


func _flicker_visual(delta: float) -> void:
	if _visual == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	_visual.position.y = 1.0 + sin(t * 3.0) * 0.12


## 敌人命中入口（敌 FSM target_node 指向本节点时调用）
func receive_hit(damage, stagger, hit_direction, source) -> void:
	if _dead:
		return
	health = maxf(health - float(damage), 0.0)
	if health <= 0.0:
		_die()


## 敌 FSM 目标合法性
func is_targetable() -> bool:
	return not _dead and is_instance_valid(self)


func get_target_point() -> Vector3:
	return global_position + Vector3.UP * 1.2


func _die() -> void:
	if _dead:
		return
	_dead = true
	_restore_boons()
	despawned.emit(self)
	queue_free()


func _despawn() -> void:
	if _dead:
		return
	_dead = true
	_restore_boons()
	despawned.emit(self)
	queue_free()


func _restore_boons() -> void:
	if focus_regen_multiplier > 1.0 and player != null and is_instance_valid(player):
		player.focus_regen_multiplier = 1.0
