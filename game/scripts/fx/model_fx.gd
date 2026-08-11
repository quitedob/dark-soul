class_name ModelFx
extends RefCounted
## 真实 GLB 模型特效层 —— 每个模型按 ModelMotionProfiles 档案获得专属运动与视觉特效。
##   · apply_movement():bob/float/sway/rock 等专属运动(悬浮呼吸/摆荡/漂浮);
##   · ensure_ambient():持续环境粒子(余烬/萤光/尘埃),按档案类型;
##   · spawn_ember_burst():蓄力余烬喷发(一次性),颜色按档案。
## 仅对真模型(ModelRoot)生效;程序化占位体由旧材质变色体系负责。

const FLOATING_BODY_TYPES := {
	"ethereal_flicker": true, "floating_small": true, "floating_orb": true,
	"lantern_float": true, "floating_dress": true, "tower_ranged": true,
	"void_wraith": true, "flying_small": true, "quantum_shimmer": true,
	"celestial_guard": true, "flying_large": true, "floating_book": true,
	"reflection_clone": true, "ghost": true,
}


static func is_floating(body_type: String) -> bool:
	return FLOATING_BODY_TYPES.has(body_type)


## 按档案施加专属运动。非运动体型先复位,避免积累漂移。
static func apply_movement(node: Node3D, base_y: float, movement: Dictionary, _delta: float) -> void:
	var type := String(movement.get("type", "none"))
	var amp := float(movement.get("amplitude", 0.05))
	var speed := float(movement.get("speed", 2.0))
	var t := Time.get_ticks_msec() * 0.001
	var phase := float(node.get_instance_id()) * 0.013
	node.position.y = base_y
	node.rotation = Vector3.ZERO
	match type:
		"bob":
			node.position.y = base_y + sin(t * speed + phase) * amp
		"float":
			node.position.y = base_y + sin(t * speed + phase) * amp
			node.rotation.z = sin(t * speed * 0.5 + phase) * amp * 0.4
		"sway":
			node.rotation.y = sin(t * speed + phase) * amp
		"rock":
			node.rotation.z = sin(t * speed + phase) * amp
		"none", _:
			pass


## 持续环境粒子:每个模型只建一次(按名字查),循环低开销。
static func ensure_ambient(parent: Node3D, ambient: Dictionary) -> void:
	if ambient.is_empty() or parent.get_node_or_null("ModelAmbient") != null:
		return
	var type := String(ambient.get("type", "none"))
	if type == "none":
		return
	var color: Color = ambient.get("color", Color(1.0, 0.8, 0.4))
	var count := int(ambient.get("count", 12))
	var p := CPUParticles3D.new()
	p.name = "ModelAmbient"
	p.amount = count
	p.lifetime = 2.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.7
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0, 0.4, 0) if type != "dust" else Vector3.ZERO
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.13
	p.color = color
	p.position.y = 1.0
	parent.add_child(p)


## 环境光环:档案 vfx.aura 提供的软性点光源(幽灵/火焰模型的光晕)。
static func ensure_aura(parent: Node3D, aura_color) -> void:
	if parent.get_node_or_null("ModelAura") != null:
		return
	var l := OmniLight3D.new()
	l.name = "ModelAura"
	l.light_color = aura_color
	l.light_energy = 0.5
	l.omni_range = 2.2
	l.shadow_enabled = false
	l.position.y = 1.2
	parent.add_child(l)


## 蓄力余烬喷发:一次性粒子,播完自动销毁。颜色由档案 windup_ember 决定。
static func spawn_ember_burst(parent: Node3D, color := Color(1.0, 0.45, 0.1)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = "EmberBurst"
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 20
	p.lifetime = 0.8
	p.spread = 50.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.8
	p.gravity = Vector3(0, -1.0, 0)
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.18
	p.color = color
	p.position.y = 1.0
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	return p
