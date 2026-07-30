class_name InputConfigurator
extends RefCounted
## Static input-map configuration for keyboard, mouse, and gamepad.
## Extracted from game_world.gd so input binding lives in a dedicated class.


static func configure_inputs() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("dodge", KEY_SPACE)
	_add_key_action("jump", KEY_V)
	_add_key_action("lock_on", KEY_Q)
	_add_key_action("interact", KEY_E)
	_add_key_action("right_primary", KEY_J)
	_add_key_action("right_secondary", KEY_K)
	_add_key_action("left_primary", KEY_C)
	_add_key_action("left_secondary", KEY_R)
	_add_key_action("light_attack_alt", KEY_J)
	_add_key_action("heavy_attack_alt", KEY_K)
	_add_key_action("help", KEY_F1)
	_add_key_action("debug_hitbox", KEY_F3)
	_add_key_action("pause", KEY_ESCAPE)
	_add_key_action("guard", KEY_C)
	_add_key_action("parry", KEY_R)
	_add_key_action("special_attack", KEY_F)
	_add_key_action("cast_spell", KEY_G)
	_add_key_action("cycle_style", KEY_TAB)
	_add_key_action("toggle_grip", KEY_T)
	_add_key_action("style_1", KEY_1)
	_add_key_action("style_2", KEY_2)
	_add_key_action("style_3", KEY_3)
	_add_key_action("style_4", KEY_4)
	_add_key_action("style_5", KEY_5)
	_add_mouse_action("right_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("right_secondary", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("light_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("heavy_attack", MOUSE_BUTTON_RIGHT)
	_add_mouse_action("lock_on", MOUSE_BUTTON_MIDDLE)
	_add_joy_axis_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis_action("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis_action("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis_action("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis_action("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_axis_action("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_axis_action("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_axis_action("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_add_joy_button_action("dodge", JOY_BUTTON_A)
	_add_joy_button_action("jump", JOY_BUTTON_DPAD_UP)
	_add_joy_button_action("interact", JOY_BUTTON_Y)
	_add_joy_button_action("right_primary", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_axis_action("right_secondary", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button_action("left_primary", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_axis_action("left_secondary", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button_action("light_attack", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_axis_action("heavy_attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_button_action("lock_on", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button_action("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button_action("pause", JOY_BUTTON_START)
	_add_joy_button_action("help", JOY_BUTTON_BACK)
	_add_joy_button_action("special_attack", JOY_BUTTON_B)
	_add_joy_button_action("parry", JOY_BUTTON_X)
	_add_joy_button_action("cycle_style", JOY_BUTTON_DPAD_RIGHT)


static func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	_add_input_event_once(action, event)


static func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	_add_input_event_once(action, event)


static func _add_joy_button_action(action: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	_add_input_event_once(action, event)


static func _add_joy_axis_action(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.22)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	_add_input_event_once(action, event)


static func _add_input_event_once(action: StringName, event: InputEvent) -> void:
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)
