extends Node
## Two real landings and a physics-driven platform. Discovery unlocks the lower
## call switch; riding preserves the production CharacterBody platform motion.
const Interact = preload("res://scripts/world/campaign_exit_interact.gd")
var platform: AnimatableBody3D
var upper_y := -0.175
var lower_y := -6.175
var destination_y := -0.175
var unlocked := false
var moving := false
var _unlock: Callable
var _prerequisite: Callable
var _last_ready := false
var _lift: Node3D
var _controls: Array[Area3D] = []

func setup(lift: Node3D, already_unlocked: bool, on_unlock: Callable, prerequisite: Callable = Callable()) -> void:
	_lift = lift
	_unlock = on_unlock
	_prerequisite = prerequisite
	unlocked = already_unlocked
	platform = lift.get_node("LiftPlatform") as AnimatableBody3D
	platform.sync_to_physics = false
	lower_y = (lift.get_node("ShrineDock") as Marker3D).position.y - .175
	destination_y = upper_y
	platform.position = Vector3(0, upper_y, 0)
	lift.set_meta("is_active", unlocked)
	_add_control("UpperLiftCall", Vector3(0, 1.0, -4.2), true)
	_add_control("LowerLiftCall", Vector3(0, lower_y + 1.175, -4.2), false)
	var onboard := Interact.new()
	onboard.name = "LiftRideInteract"
	onboard.position = Vector3(0, 1.1, 0)
	_configure_area(onboard)
	onboard.world_callback = func(_a: Node, player: Node) -> void:
		if not _nearby(onboard, player) or moving or not _ready_to_unlock(): return
		_discover()
		_start(lower_y if absf(platform.position.y - upper_y) < .1 else upper_y)
	platform.add_child(onboard)
	_controls.append(onboard)
	_refresh_prompts()

func _physics_process(delta: float) -> void:
	var ready := _ready_to_unlock()
	if ready != _last_ready:
		_last_ready = ready
		_refresh_prompts()
	if not moving or not is_instance_valid(platform): return
	platform.position.y = move_toward(platform.position.y, destination_y, delta * float(_lift.get_meta("lift_speed", 2.6)))
	if is_equal_approx(platform.position.y, destination_y):
		moving = false
		_refresh_prompts()

func _add_control(label: String, at: Vector3, upper: bool) -> void:
	var area := Interact.new()
	area.name = label
	area.set_meta("upper_landing", upper)
	area.position = at
	_configure_area(area)
	area.world_callback = func(_a: Node, player: Node) -> void:
		if not _nearby(area, player) or moving or not _ready_to_unlock(): return
		if upper: _discover()
		if not unlocked: return
		var landing_y := upper_y if upper else lower_y
		# A switch calls an absent platform; when boarded it rides to the other
		# landing. Standing on the fixed landing never relocates the character.
		if absf(platform.position.y - landing_y) > .1:
			_start(landing_y)
		elif player is Node3D:
			var local: Vector3 = platform.to_local(player.global_position)
			if absf(local.x) < 2.75 and absf(local.z) < 2.75:
				_start(lower_y if upper else upper_y)
	_lift.add_child(area)
	_controls.append(area)

func _configure_area(area: Area3D) -> void:
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.add_to_group("interactable")
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.2
	collision.shape = shape
	area.add_child(collision)

func _nearby(area: Area3D, player: Node) -> bool:
	return player is Node3D and is_instance_valid(player) \
		and (not "health" in player or float(player.get("health")) > 0.0) \
		and area.global_position.distance_to(player.global_position + Vector3.UP) < 3.2

func _ready_to_unlock() -> bool:
	return not _prerequisite.is_valid() or bool(_prerequisite.call())

func _discover() -> void:
	if unlocked: return
	unlocked = true
	_lift.set_meta("is_active", true)
	if _unlock.is_valid(): _unlock.call()

func _start(target: float) -> void:
	destination_y = target
	moving = not is_equal_approx(platform.position.y, target)
	_refresh_prompts()

func _refresh_prompts() -> void:
	for area in _controls:
		area.prompt_text = "升降台运行中 / Lift moving" if moving else "呼叫升降台 / Call lift"
		if not moving and String(area.name) == "LiftRideInteract":
			area.prompt_text = "乘坐升降台 / Ride lift"
		elif not moving:
			var landing := upper_y if bool(area.get_meta("upper_landing", false)) else lower_y
			if absf(platform.position.y - landing) < .1:
				area.prompt_text = "升降台已停靠 · 走上平台 / Step onto the lift"
		if String(area.name) == "LowerLiftCall" and not unlocked:
			area.prompt_text = "需要从上层解锁 / Unlock from above"
		if not _ready_to_unlock():
			area.prompt_text = String(_lift.get_meta("locked_prompt", "完成楼内三层记录后解锁 / Complete the three storeys"))
