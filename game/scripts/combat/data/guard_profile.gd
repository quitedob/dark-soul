class_name GuardProfile
extends Resource

@export_range(1.0, 180.0, 1.0) var guard_angle_degrees := 120.0
@export_range(0.0, 1.0, 0.01) var physical_absorption := 0.80
@export_range(0.0, 0.95, 0.01) var stability := 0.65
@export_range(0.0, 500.0, 1.0) var max_guard_meter := 100.0
@export_range(0.0, 500.0, 1.0) var direct_break_threshold := 75.0
@export_range(0.0, 4.0, 0.05) var guard_meter_damage_multiplier := 1.0
@export_range(0.0, 4.0, 0.05) var stamina_damage_multiplier := 1.0
@export var can_parry := false
@export var parry_start_seconds := 0.10
@export var parry_active_seconds := 0.12
@export var parry_recovery_seconds := 0.42
@export var parry_miss_multiplier := 1.0
