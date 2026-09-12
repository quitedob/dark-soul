extends Node3D
## One encounter owns admission, combat permission, containment and retry lifecycle.
## The boundary never awards victory: only the boss's production defeat signal does.

signal encounter_started
signal encounter_reset
signal encounter_resolved
signal navigation_changed

enum EncounterState { WAITING, ACTIVE, RESOLVING, CLEARED }
const SEGMENTS := 40
const PROFILES := {
	"boss_giant_gate": ["keeper_rune", Color("d99845"), 5.0],
	"boss_xing_tian": ["military_soul_seal", Color("b84032"), 6.0],
	"boss_nine_tails": ["moon_veil", Color("85cbbb"), 5.0],
	"boss_xuan_xiao_wrath": ["wrath_fire", Color("e87b3d"), 5.5],
	"boss_xuan_xiao_obsession": ["frozen_mandala", Color("78afd5"), 5.5],
	"boss_xuan_xiao": ["ascension_seal", Color("ddc489"), 6.0],
	"boss_zhu_yin": ["furnace_chains", Color("a986cc"), 8.0],
	"boss_blind_bell": ["silent_resonance", Color("b7a371"), 7.0],
}

var state := EncounterState.WAITING
var boss: Node3D
var player: Node3D
var center := Vector3.ZERO
var radius := 20.0
var generation := 0
var admission_count := 0
var boundary_profile := ""
var admission_check: Callable
var admission_denied: Callable
var _denied_notice_time := 0.0
var _admission_locked := false
var _walls: Array[CollisionShape3D] = []
var _gates: Array[StaticBody3D] = []
var _curtain: MeshInstance3D
var _resetting := false
var _boss_ranges := Vector3.ZERO


func setup(encounter_boss: Node3D, encounter_player: Node3D, at: Vector3, arena_radius: float) -> void:
	boss = encounter_boss
	player = encounter_player
	center = at
	radius = maxf(arena_radius, 8.0)
	global_position = center
	var id := String(boss.get("content_id"))
	var profile: Array = PROFILES.get(id, PROFILES["boss_giant_gate"])
	boundary_profile = String(profile[0])
	_boss_ranges = Vector3(boss.aggro_range, boss.disengage_range, boss.leash_range)
	boss.encounter_boundary = self
	boss.reset_completed.connect(_on_boss_reset)
	boss.story_resolution_entered.connect(_on_story_resolution)
	boss.defeated.connect(_on_boss_defeated)
	_build_boundary(profile[1], float(profile[2]))
	_set_sealed(false)
	set_meta("boss_id", id)
	set_meta("boundary_profile", boundary_profile)
	add_to_group("boss_encounter_boundaries")
	process_physics_priority = -10


func combat_is_active() -> bool:
	return state == EncounterState.ACTIVE


func contains_actor(actor: Node3D, margin := 0.0) -> bool:
	if not is_instance_valid(actor):
		return false
	var offset := actor.global_position - center
	return Vector2(offset.x, offset.z).length() <= radius + margin and offset.y >= -3.0 and offset.y <= 18.0


func allows_damage(source: Variant = null) -> bool:
	if not combat_is_active() or not contains_actor(player, 1.5):
		return false
	# Environmental hits may have no source; actual outside actors cannot snipe in.
	if is_instance_valid(source) and source is Node3D:
		return contains_actor(source, 1.5)
	return true


func register_gate(gate: StaticBody3D) -> void:
	if is_instance_valid(gate) and gate not in _gates:
		_gates.append(gate)
		_set_gate(gate, state == EncounterState.ACTIVE)


func _physics_process(delta: float) -> void:
	_denied_notice_time = maxf(0.0, _denied_notice_time - delta)
	if not is_instance_valid(boss) or not is_instance_valid(player):
		if state == EncounterState.ACTIVE:
			_set_sealed(false)
		return
	if state == EncounterState.WAITING:
		var locked := admission_check.is_valid() and not bool(admission_check.call())
		if locked != _admission_locked:
			_admission_locked = locked
			_set_sealed(locked)
			navigation_changed.emit()
		if locked:
			if contains_actor(player, -1.0):
				var outward := player.global_position - center
				outward.y = 0.0
				outward = outward.normalized() if outward.length_squared() > .01 else Vector3.BACK
				player.global_position = center + outward * (radius + 2.) + Vector3.UP * .1
				player.velocity = Vector3.ZERO
			if contains_actor(player, 5.) and admission_denied.is_valid() and _denied_notice_time <= 0.:
				admission_denied.call()
				_denied_notice_time = 4.
			return
		if float(player.get("health")) > 0.0 and contains_actor(player, -2.0):
			_begin_encounter()
	elif state == EncounterState.ACTIVE:
		if float(player.get("health")) <= 0.0:
			reset_encounter()
			return
		# Physical walls handle ordinary motion. This catches high-speed impulses and
		# direct teleports beyond them without healing the boss or dropping aggro.
		_contain(player, 0.8)
		_contain(boss, maxf(1.2, float(boss.chapter_content.get("body_radius", 0.6)) + 0.4))


func _begin_encounter() -> void:
	if state != EncounterState.WAITING or not is_instance_valid(boss):
		return
	state = EncounterState.ACTIVE
	generation += 1
	admission_count += 1
	boss.aggro_range = radius * 3.0
	boss.disengage_range = radius * 3.0
	boss.leash_range = radius * 2.0
	boss.navigation_refresh = 0.0
	boss._set_engaged(true)
	_set_sealed(true)
	encounter_started.emit()
	navigation_changed.emit()


func reset_encounter() -> void:
	if _resetting or state == EncounterState.CLEARED:
		return
	_resetting = true
	if is_instance_valid(boss):
		boss.reset_enemy()
	else:
		_on_boss_reset(null)
	_resetting = false


func _on_boss_reset(_enemy: Node) -> void:
	state = EncounterState.WAITING
	_admission_locked = false
	generation += 1
	if is_instance_valid(boss):
		boss.aggro_range = _boss_ranges.x
		boss.disengage_range = _boss_ranges.y
		boss.leash_range = _boss_ranges.z
	_set_sealed(false)
	encounter_reset.emit()
	navigation_changed.emit()


func _on_story_resolution(_enemy: Node) -> void:
	if state == EncounterState.CLEARED:
		return
	state = EncounterState.RESOLVING
	_set_sealed(false)
	navigation_changed.emit()


func _on_boss_defeated(_enemy: Node, _reward: int, _guardian: bool) -> void:
	mark_cleared()


func mark_cleared() -> void:
	if state == EncounterState.CLEARED:
		return
	state = EncounterState.CLEARED
	generation += 1
	_set_sealed(false)
	encounter_resolved.emit()
	navigation_changed.emit()


func _contain(actor: Node3D, inset: float) -> void:
	var offset := actor.global_position - center
	var flat := Vector2(offset.x, offset.z)
	if flat.length() <= radius + 1.2:
		return
	flat = flat.normalized() * (radius - inset)
	actor.global_position = Vector3(center.x + flat.x, actor.global_position.y, center.z + flat.y)
	if actor is CharacterBody3D:
		actor.velocity.x = 0.0
		actor.velocity.z = 0.0


func _set_sealed(sealed: bool) -> void:
	for shape in _walls:
		if is_instance_valid(shape):
			shape.set_deferred("disabled", not sealed)
	if is_instance_valid(_curtain):
		_curtain.visible = sealed
	for gate in _gates:
		if is_instance_valid(gate):
			_set_gate(gate, sealed)


func _set_gate(gate: StaticBody3D, sealed: bool) -> void:
	gate.visible = sealed
	gate.set_meta("arena_sealed", sealed)
	for child in gate.find_children("*", "CollisionShape3D", true, false):
		child.set_deferred("disabled", not sealed)


func _build_boundary(tint: Color, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 2.0 * radius * tan(PI / SEGMENTS) + 0.12
	for index in SEGMENTS:
		var a := TAU * float(index) / SEGMENTS
		var b := TAU * float(index + 1) / SEGMENTS
		var p := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		var q := Vector3(cos(b) * radius, 0.0, sin(b) * radius)
		for vertex: Vector3 in [p, q, q + Vector3.UP * height, p, q + Vector3.UP * height, p + Vector3.UP * height]:
			surface.add_vertex(vertex)
		var wall := StaticBody3D.new()
		wall.name = "SealSegment%02d" % index
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.add_to_group("campaign_navigation_source")
		wall.position = (p + q) * 0.5 + Vector3.UP * (height * 0.5 - 0.5)
		wall.rotation.y = -(a + b) * 0.5
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.6, height + 1.0, width)
		shape.shape = box
		shape.disabled = true
		wall.add_child(shape)
		add_child(wall)
		_walls.append(shape)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(tint, 0.16)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.35
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_curtain = MeshInstance3D.new()
	_curtain.name = "EncounterVeil"
	_curtain.mesh = surface.commit()
	_curtain.material_override = material
	_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_curtain)
