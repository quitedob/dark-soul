class_name WeaponArtData
extends Resource

@export var art_id: StringName
@export var art_kind: StringName = &""  # pierce_thrust / leap / crescent_leap / arcane_barrage / divine_smite
@export var stance_animation: StringName
@export var entry_attack: AttackData
@export var light_branch: AttackData
@export var heavy_branch: AttackData
@export var guard_success_branch: AttackData
@export var requires_guard_success := false
@export var cooldown_seconds := 0.0
@export var uses_per_rest := 0


static func make(kind: StringName, art_id: StringName = &"") -> Resource:
	var art = load("res://scripts/combat/data/weapon_art_data.gd").new()
	art.art_kind = kind
	art.art_id = art_id if not art_id.is_empty() else kind
	return art
