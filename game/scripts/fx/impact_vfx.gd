extends Node3D
## 战斗打击 VFX（对象池）：命中火花 / 余烬 / 钢屑 / 尘土 的一次性迸溅。
## Pooled one-shot impact bursts — fully code-built, no scene deps.
## 兼容 gl_compatibility（GLES3）：不用 trail / sub_emitter / emit_particle。
## 用法：preload → .new() → add_child → spawn_impact(...)，无需 await。

const IMPACT_POOL_SIZE := 8
const RING_POOL_SIZE := 3

var _pool: Array[GPUParticles3D] = []
var _ring_pool: Array[GPUParticles3D] = []
var _cursor := 0
var _ring_cursor := 0


## 可选便捷挂载：尚未入树时把自己挂到 parent（也可直接 add_child 后靠 _ready 建池）。
func setup(parent: Node) -> void:
	if parent != null and not is_inside_tree():
		parent.add_child(self)
	_build_pools()


func _ready() -> void:
	_build_pools()


# -- public API ------------------------------------------------------------


@warning_ignore("shadowed_variable_base_class")
func spawn_impact(position: Vector3, normal := Vector3.UP, kind := "stone_sparks", scale := 1.0) -> void:
	## 在命中点炸出一簇沿法线方向的火花；池轮转复用，同帧多次调用安全。
	if not is_inside_tree():
		return
	_build_pools()
	var p := _pool[_cursor]
	_cursor = (_cursor + 1) % _pool.size()
	_apply_kind_ramp(p, color_for_kind(kind))
	# 退化法线回退，避免 look_at 目标与自身重合 / degenerate normal guard
	var n := normal if normal.length_squared() > 0.0001 else Vector3.UP
	n = n.normalized()
	p.global_position = position
	# 朝向：粒子沿 +Z 发射，look_at 让 -Z 指向 (position - normal) 即 +Z 对齐法线；
	# 法线近似平行 UP 时换 FORWARD 作上轴，否则 look_at 会报 up 共线。
	if absf(n.dot(Vector3.UP)) > 0.99:
		p.look_at(position - n, Vector3.FORWARD)
	else:
		p.look_at(position - n, Vector3.UP)
	var s := maxf(scale, 0.05)
	p.scale = Vector3(s, s, s)
	_retrigger(p)


@warning_ignore("shadowed_variable_base_class")
func spawn_slam_ring(position: Vector3, kind := "ember") -> void:
	## 重击落点：贴地向外扩散的扁平火花环（独立 3 槽小池）。
	if not is_inside_tree():
		return
	_build_pools()
	var p := _ring_pool[_ring_cursor]
	_ring_cursor = (_ring_cursor + 1) % _ring_pool.size()
	_apply_kind_ramp(p, color_for_kind(kind))
	p.rotation = Vector3.ZERO  # 环轴保持世界 Y，铺平 / keep the ring flat
	p.global_position = position
	_retrigger(p)


func impact_pool() -> Array[GPUParticles3D]:
	_build_pools()
	return _pool


func ring_pool() -> Array[GPUParticles3D]:
	_build_pools()
	return _ring_pool


static func color_for_kind(kind: String) -> Color:
	## 打击类型 → 火花基色（HUD / 拖尾等外部系统可复用）。
	match kind:
		"stone_sparks":
			return Color("ffd9a0")  # 暖橙白
		"ember":
			return Color("ff5522")  # 余烬橙红
		"steel":
			return Color("cfe4ff")  # 钢屑冷蓝
		"dust":
			return Color("8a8578")  # 尘土灰褐
		_:
			return Color(1.0, 0.92, 0.82)  # 默认暖白 / warm white


# -- internals -------------------------------------------------------------


func _build_pools() -> void:
	if not _pool.is_empty():
		return
	for i in IMPACT_POOL_SIZE:
		var p := _make_impact_emitter()
		p.name = "Impact%d" % i
		add_child(p)
		_pool.append(p)
	for i in RING_POOL_SIZE:
		var r := _make_ring_emitter()
		r.name = "SlamRing%d" % i
		add_child(r)
		_ring_pool.append(r)


func _retrigger(p: GPUParticles3D) -> void:
	# one_shot 重触发要诀（引擎实测）：只设 emitting 不可靠，先换 seed 再 restart()。
	# 注：4.7 的 seed 在 GPUParticles3D 节点上（不在 process material 上）。
	p.use_fixed_seed = true
	p.seed = randi()
	p.restart()


func _apply_kind_ramp(p: GPUParticles3D, kind_color: Color) -> void:
	# 渐变三停：白热 → 材质色 → 透明 / white-hot → kind color → fade out
	var mat := p.process_material as ParticleProcessMaterial
	if mat == null:
		return
	var tex := mat.color_ramp as GradientTexture1D
	if tex == null or tex.gradient == null:
		return
	var g := tex.gradient
	if g.offsets.size() != 3:
		return
	g.set_color(0, Color(1.0, 1.0, 0.95, 1.0))
	g.set_color(1, Color(kind_color.r, kind_color.g, kind_color.b, 1.0))
	g.set_color(2, Color(kind_color.r, kind_color.g, kind_color.b, 0.0))


func _make_impact_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.amount = 26
	p.visibility_aabb = AABB(Vector3(-3.0, -3.0, -3.0), Vector3(6.0, 6.0, 6.0))
	p.interpolate = true
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	p.draw_pass_1 = _make_draw_mesh(0.035, 0.07)
	p.process_material = _make_impact_material()
	return p


func _make_impact_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 0.0, 1.0)
	pm.spread = 42.0
	pm.initial_velocity_min = 3.5
	pm.initial_velocity_max = 8.0
	pm.gravity = Vector3(0.0, -12.0, 0.0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = 0.35
	pm.scale_max = 1.0
	pm.angle_min = 0.0  # 随机自旋（4.x 用角度区间表达随机，替代旧 angle_randomness）
	pm.angle_max = 360.0
	pm.color_ramp = _make_ramp(color_for_kind("stone_sparks"))
	return pm


func _make_ring_emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.amount = 30
	p.visibility_aabb = AABB(Vector3(-5.0, -0.6, -5.0), Vector3(10.0, 1.6, 10.0))
	p.interpolate = true
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	p.draw_pass_1 = _make_draw_mesh(0.05, 0.1)
	p.process_material = _make_ring_material()
	return p


func _make_ring_material() -> ParticleProcessMaterial:
	# 扁平外扩环：环形发射 + 极窄 spread + 零重力 + 阻尼收尾（压住残余 y 漂移）
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0.0, 1.0, 0.0)
	pm.emission_ring_radius = 0.3
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 3.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3.ZERO
	pm.damping_min = 0.5
	pm.damping_max = 1.2
	pm.scale_min = 0.5
	pm.scale_max = 1.1
	pm.angle_min = 0.0
	pm.angle_max = 360.0
	pm.color_ramp = _make_ramp(color_for_kind("ember"))
	return pm


func _make_ramp(kind_color: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([
		Color(1.0, 1.0, 0.95, 1.0),
		Color(kind_color.r, kind_color.g, kind_color.b, 1.0),
		Color(kind_color.r, kind_color.g, kind_color.b, 0.0),
	])
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


func _make_draw_mesh(radius: float, height: float) -> SphereMesh:
	# 微型无光照球贴片：颜色/淡出全由 process material 的 color_ramp 顶点色驱动
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 5
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	s.material = m
	return s
