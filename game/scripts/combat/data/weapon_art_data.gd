class_name WeaponArtData
extends Resource

@export var art_id: StringName
@export var stance_animation: StringName
@export var entry_attack: AttackData
@export var light_branch: AttackData
@export var heavy_branch: AttackData
@export var guard_success_branch: AttackData
@export var requires_guard_success := false
@export var cooldown_seconds := 0.0
@export var uses_per_rest := 0
