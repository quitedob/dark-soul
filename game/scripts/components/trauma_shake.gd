class_name TraumaShake
extends Node

## 武器重量档位创伤注入量（C-03）
const TRAUMA_LIGHT := 0.3
const TRAUMA_HEAVY := 0.8
const TRAUMA_EXPLOSION := 1.0

## light / heavy / explosion → 注入量查表
const TRAUMA_BY_WEIGHT := {
	&"light": TRAUMA_LIGHT,
	&"heavy": TRAUMA_HEAVY,
	&"explosion": TRAUMA_EXPLOSION,
}

## 判定为爆炸档的标签（跳劈 / AoE / 地砸等）
const EXPLOSION_TAGS := [&"leap", &"explosion", &"aoe", &"ground_slam", "leap", "explosion", "aoe", "ground_slam"]

var trauma := 0.0
var intensity := 1.0
var enabled := true
var trauma_power := 2.0
var max_offset := Vector2(0.18, 0.12)
var max_roll := 0.035
var decay_rate := 1.8
var noise_speed := 24.0

var _camera: Camera3D
var _noise := FastNoiseLite.new()
var _sample_position := 0.0
var _applied_transform := Transform3D.IDENTITY
var _has_applied_offset := false


func setup(camera: Camera3D) -> void:
	_camera = camera
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.frequency = 0.45
	_applied_transform = Transform3D.IDENTITY


## 查表取得档位对应创伤量，缺省回退 light
static func trauma_for_weight(weight: StringName) -> float:
	return float(TRAUMA_BY_WEIGHT.get(weight, TRAUMA_LIGHT))


## 从 is_heavy / 标签 / action_id 解析重量档位
static func resolve_weight(is_heavy: bool, tags: Array = [], action_id: String = "") -> StringName:
	var action_lower := action_id.to_lower()
	# 爆炸档：标签或招式名含 leap / explosion / aoe / slam
	if _has_explosion_marker(tags, action_lower):
		return &"explosion"
	if is_heavy:
		return &"heavy"
	return &"light"


## 检测爆炸档标记（标签集合或 action 子串）
static func _has_explosion_marker(tags: Array, action_lower: String) -> bool:
	for marker in EXPLOSION_TAGS:
		if marker in tags:
			return true
	if action_lower.contains("leap") \
			or action_lower.contains("explosion") \
			or action_lower.contains("aoe") \
			or action_lower.contains("slam"):
		return true
	return false


## 按重量档位注入创伤（light 0.3 / heavy 0.8 / explosion 1.0）
func inject_weight(weight: StringName) -> void:
	inject(trauma_for_weight(weight))


func inject(amount: float) -> void:
	if not enabled:
		return
	trauma = clampf(trauma + amount * intensity, 0.0, 1.0)


func set_settings(shake_enabled: bool, shake_intensity: float) -> void:
	enabled = shake_enabled
	intensity = clampf(shake_intensity, 0.0, 2.0)
	if not enabled:
		reset_camera()


func reset_camera() -> void:
	trauma = 0.0
	if _camera != null and is_instance_valid(_camera) and _has_applied_offset:
		_camera.transform = _camera.transform * _applied_transform.affine_inverse()
	_applied_transform = Transform3D.IDENTITY
	_has_applied_offset = false


func _process(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var base_transform := _camera.transform
	if _has_applied_offset:
		base_transform = base_transform * _applied_transform.affine_inverse()
	if not enabled or trauma <= 0.001:
		_camera.transform = base_transform
		trauma = 0.0
		_applied_transform = Transform3D.IDENTITY
		_has_applied_offset = false
		return
	trauma = maxf(trauma - decay_rate * delta, 0.0)
	_sample_position += noise_speed * delta
	var shake := pow(trauma, trauma_power)
	var offset_x := _noise.get_noise_2d(0.0, _sample_position) * shake * max_offset.x
	var offset_y := _noise.get_noise_2d(1000.0, _sample_position) * shake * max_offset.y
	var roll := _noise.get_noise_2d(2000.0, _sample_position) * shake * max_roll
	_applied_transform = Transform3D(Basis(Vector3.FORWARD, roll), Vector3(offset_x, offset_y, 0.0))
	_camera.transform = base_transform * _applied_transform
	_has_applied_offset = true
