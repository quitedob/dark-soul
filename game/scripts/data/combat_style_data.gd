class_name CombatStyleData
extends Resource

@export var style_id: StringName
@export var display_name: String
@export_group("Light Attack")
@export var windup_light := 0.3
@export var active_light := 0.15
@export var recovery_light := 0.32
@export var lunge_light := 2.0
@export var damage_light := 20.0
@export var stagger_light := 16.0
@export var stamina_light := 20.0
@export_group("Heavy Attack")
@export var windup_heavy := 0.6
@export var active_heavy := 0.22
@export var recovery_heavy := 0.65
@export var lunge_heavy := 2.8
@export var damage_heavy := 38.0
@export var stagger_heavy := 34.0
@export var stamina_heavy := 38.0
@export_group("Movement")
@export var stamina_dodge := 24.0
@export var move_speed := 5.2
@export var sprint_speed := 7.4
@export_group("Leap Attack")
@export var leap_windup := 0.0
@export var leap_active := 0.0
@export var leap_recovery := 0.0
@export var leap_damage := 0.0
@export var leap_stagger := 0.0
@export var leap_stamina := 0.0
@export var leap_lunge := 0.0
@export var leap_velocity_y := 0.0
@export_group("Defense")
@export var has_hyper_armor := false
@export var wam_light := 0.0
@export var wam_heavy := 0.0
@export var wam_leap := 0.0
@export var wam_guard := 0.0
@export_group("Presentation")
@export var weapon_material_color := Color.WHITE
@export var trail_color := Color.WHITE
@export var hit_vfx_scale := 1.0


func value(key: StringName, heavy := false) -> Variant:
	var property_name := String(key)
	if key in [&"windup", &"active", &"recovery", &"lunge", &"damage", &"stagger", &"stamina"]:
		property_name += "_heavy" if heavy else "_light"
	return get(property_name)
