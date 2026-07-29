class_name AshenGameHostBridge
extends Node

signal settings_received(settings: Dictionary)
signal initialize_received(settings: Dictionary, save_data: Dictionary)
signal new_run_requested
signal continue_run_requested(save_data: Dictionary)
signal lifecycle_changed(active: bool)
signal save_requested
signal exit_requested
signal protocol_error(message: String)

const PROTOCOL_VERSION := 1

var _js_bridge: Object
var _window: Object
var _host: Object
var _receive_callback: Object
var _sample_elapsed := 0.0
var _request_sequence := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_web_host()


func _process(delta: float) -> void:
	if _host == null:
		return
	_sample_elapsed += delta
	if _sample_elapsed < 2.0:
		return
	_sample_elapsed = 0.0
	send_event("performance.sample", {
		"fps": Engine.get_frames_per_second(),
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
	})


func is_connected_to_host() -> bool:
	return _host != null


func send_ready(has_save: bool) -> void:
	send_event("game.ready", {"hasSave": has_save})


func send_save(save_data: Dictionary, reason: String) -> void:
	send_event("save.changed", {
		"reason": reason,
		"save": save_data,
	})


func send_fatal_error(message: String) -> void:
	send_event("game.error", {"message": message})


func send_event(event_type: String, payload: Dictionary = {}) -> void:
	if _host == null:
		return
	_request_sequence += 1
	var envelope := {
		"protocolVersion": PROTOCOL_VERSION,
		"type": event_type,
		"requestId": "godot-%d" % _request_sequence,
		"payload": payload,
	}
	_host.call("postMessage", JSON.stringify(envelope))


func handle_message(raw_message: String) -> bool:
	var decoded = JSON.parse_string(raw_message)
	if not decoded is Dictionary:
		protocol_error.emit("Host message is not valid JSON.")
		return false
	if int(decoded.get("protocolVersion", -1)) != PROTOCOL_VERSION:
		protocol_error.emit("Unsupported host protocol version.")
		return false
	if String(decoded.get("requestId", "")).is_empty():
		protocol_error.emit("Host message does not include a request ID.")
		return false

	var message_type := String(decoded.get("type", ""))
	var payload = decoded.get("payload", {})
	if not payload is Dictionary:
		payload = {}
	match message_type:
		"settings.apply":
			var settings_data = payload.get("settings", payload)
			if not settings_data is Dictionary:
				protocol_error.emit("Settings payload does not contain a settings object.")
				return false
			settings_received.emit(settings_data)
		"host.initialize":
			var initial_settings = payload.get("settings", {})
			var initial_save = payload.get("save", {})
			if not initial_settings is Dictionary or not initial_save is Dictionary:
				protocol_error.emit("Initialize payload is malformed.")
				return false
			initialize_received.emit(initial_settings, initial_save)
		"run.new":
			new_run_requested.emit()
		"run.continue":
			var save_data = payload.get("save", payload)
			if not save_data is Dictionary:
				protocol_error.emit("Continue payload does not contain a save object.")
				return false
			continue_run_requested.emit(save_data)
		"lifecycle":
			lifecycle_changed.emit(bool(payload.get("active", false)))
		"save.request":
			save_requested.emit()
		"exit.request":
			exit_requested.emit()
		_:
			protocol_error.emit("Unknown host message type: %s" % message_type)
			return false
	return true


func _connect_web_host() -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	_js_bridge = Engine.get_singleton("JavaScriptBridge")
	_window = _js_bridge.call("get_interface", "window")
	if _window == null:
		return
	_host = _js_bridge.call("get_interface", "AshenHollowHost")
	_receive_callback = _js_bridge.call("create_callback", _on_js_message)
	_js_bridge.call(
		"eval",
		"window.AshenHollowBridge = window.AshenHollowBridge || {};",
		true
	)
	var receiver = _js_bridge.call("get_interface", "AshenHollowBridge")
	if receiver != null:
		receiver.set("receive", _receive_callback)


func _on_js_message(arguments: Array) -> void:
	if arguments.is_empty():
		protocol_error.emit("Host callback did not include a message.")
		return
	handle_message(String(arguments[0]))
