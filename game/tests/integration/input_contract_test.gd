extends SceneTree
## L-23 合约：输入系统（input_config.gd）。
## 1) configure_inputs 注册核心动作（移动 / 交互 / 战斗 / 风格 / 系统）。
## 2) 每个动作至少带一个绑定事件。
## 3) 关键动作绑定具体键位 / 鼠标 / 手柄（移动、互动、施法、切换风格、锁敌、攻击）。
## 4) 幂等：重复 configure_inputs 不重复追加事件。

const InputConfigurator = preload("res://scripts/core/input_config.gd")

const REQUIRED_ACTIONS := [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"sprint",
	&"dodge", &"jump", &"lock_on", &"cycle_lock_left", &"cycle_lock_right",
	&"interact", &"right_primary", &"right_secondary", &"left_primary",
	&"left_secondary", &"guard", &"parry", &"special_attack", &"cast_spell",
	&"cycle_style", &"cycle_weapon", &"equipment", &"toggle_grip", &"light_attack", &"heavy_attack",
	&"pause", &"help", &"style_1", &"style_2", &"style_3", &"style_4", &"style_5",
]

var _failures: Array[String] = []


func _init() -> void:
	InputConfigurator.configure_inputs()
	_test_required_actions_registered()
	_test_action_bindings_present()
	_test_key_mouse_bindings()
	_test_configuration_is_idempotent()
	if _failures.is_empty():
		print("ASHEN_INPUT_CONTRACTS_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_required_actions_registered() -> void:
	for action in REQUIRED_ACTIONS:
		_expect(InputMap.has_action(action), "Required input action %s is missing." % action)


func _test_action_bindings_present() -> void:
	for action in REQUIRED_ACTIONS:
		_expect(InputMap.action_get_events(action).size() > 0, "Action %s has no bindings." % action)


func _test_key_mouse_bindings() -> void:
	_expect(_has_mouse_binding(&"right_primary", MOUSE_BUTTON_LEFT), "right_primary must bind mouse left.")
	_expect(_has_mouse_binding(&"right_secondary", MOUSE_BUTTON_RIGHT), "right_secondary must bind mouse right.")
	_expect(_has_mouse_binding(&"lock_on", MOUSE_BUTTON_MIDDLE), "lock_on must bind mouse middle.")
	_expect(_has_key_binding(&"dodge", KEY_SPACE), "dodge must bind Space.")
	_expect(_has_key_binding(&"jump", KEY_V), "jump must bind V.")
	_expect(_has_key_binding(&"interact", KEY_E), "interact must bind E.")
	_expect(_has_key_binding(&"cast_spell", KEY_G), "cast_spell must bind G.")
	_expect(_has_key_binding(&"cycle_style", KEY_TAB), "cycle_style must bind Tab.")
	_expect(_has_key_binding(&"cycle_weapon", KEY_X), "cycle_weapon must bind X.")
	_expect(_has_key_binding(&"equipment", KEY_I), "equipment must bind I.")


func _test_configuration_is_idempotent() -> void:
	var counts: Dictionary = {}
	for action in REQUIRED_ACTIONS:
		counts[action] = InputMap.action_get_events(action).size()
	InputConfigurator.configure_inputs()
	for action in REQUIRED_ACTIONS:
		_expect(
			InputMap.action_get_events(action).size() == counts[action],
			"Reconfigure duplicated events for %s." % action
		)


func _has_key_binding(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == keycode:
			return true
	return false


func _has_mouse_binding(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == button:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
