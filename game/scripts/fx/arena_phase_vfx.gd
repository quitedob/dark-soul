extends Node
## G-04：Boss 相变场地 VFX（径向冲击环 + 余烬粒子，3D 程序化）

const DEFAULT_LIFETIME := 3.2


## 在 Boss 脚下播放相变场地特效；vfx_key 来自章节 phases.vfx
func play_at(origin: Vector3, phase: int, vfx_key: String = "", parent: Node = null) -> void:
	var host: Node = parent if parent != null else self
	if host == null or not is_instance_valid(host):
		return
	var root := Node3D.new()
	root.name = "ArenaPhaseVfx_P%d" % phase
	root.position = origin
	host.add_child(root)
	_spawn_shock_ring(root, phase)
	_spawn_ember_burst(root, phase, vfx_key)
	if phase >= 3:
		_spawn_overload_column(root)
	# 超时清理，避免粒子节点堆积
	var tree := host.get_tree()
	if tree != null:
		tree.create_timer(DEFAULT_LIFETIME).timeout.connect(func():
			if is_instance_valid(root):
				root.queue_free()
		)


func _spawn_shock_ring(root: Node3D, phase: int) -> void:
	var ring := MeshInstance3D.new()
	ring.name = "ShockRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.55 if phase < 3 else 0.72
	torus.rings = 12
	torus.ring_segments = 24
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.45, 0.12, 0.85) if phase < 3 else Color(1.0, 0.78, 0.35, 0.9)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.8 if phase < 3 else 4.2
	torus.material = mat
	ring.mesh = torus
	ring.position.y = 0.08
	ring.scale = Vector3(0.2, 0.2, 0.2)
	root.add_child(ring)
	var target_scale := 3.6 if phase < 3 else 5.2
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(target_scale, 0.35, target_scale), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55).set_delay(0.12)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.55).set_delay(0.12)


func _spawn_ember_burst(root: Node3D, phase: int, vfx_key: String) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "EmberBurst"
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.amount = 42 if phase < 3 else 64
	particles.lifetime = 1.4 if phase < 3 else 1.8
	particles.visibility_aabb = AABB(Vector3(-8, -1, -8), Vector3(16, 10, 16))
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 4
	sphere.rings = 2
	var draw_mat := StandardMaterial3D.new()
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.albedo_color = _color_for_key(vfx_key, phase)
	draw_mat.emission_enabled = true
	draw_mat.emission = draw_mat.albedo_color
	draw_mat.emission_energy_multiplier = 3.0
	sphere.material = draw_mat
	particles.draw_pass_1 = sphere
	var proc := ParticleProcessMaterial.new()
	proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	proc.emission_sphere_radius = 0.4
	proc.direction = Vector3(0, 1, 0)
	proc.spread = 180.0
	proc.initial_velocity_min = 2.2 if phase < 3 else 3.4
	proc.initial_velocity_max = 5.5 if phase < 3 else 7.8
	proc.gravity = Vector3(0, -1.2, 0)
	proc.damping_min = 0.8
	proc.damping_max = 1.6
	proc.scale_min = 0.4
	proc.scale_max = 1.4
	proc.color = Color(draw_mat.albedo_color.r, draw_mat.albedo_color.g, draw_mat.albedo_color.b, 0.85)
	particles.process_material = proc
	root.add_child(particles)


func _spawn_overload_column(root: Node3D) -> void:
	# 三阶段：短暂光柱强调炉心过载
	var column := MeshInstance3D.new()
	column.name = "OverloadColumn"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.55
	cyl.height = 4.5
	cyl.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.65, 0.2, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.5, 0.1)
	mat.emission_energy_multiplier = 5.0
	cyl.material = mat
	column.mesh = cyl
	column.position.y = 2.2
	column.scale = Vector3(0.15, 0.2, 0.15)
	root.add_child(column)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(column, "scale", Vector3(1.15, 1.0, 1.15), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_property(mat, "emission_energy_multiplier", 0.0, 0.7).set_delay(0.25)


func _color_for_key(vfx_key: String, phase: int) -> Color:
	match vfx_key:
		"mechanical_steam_puffs":
			return Color(0.75, 0.82, 0.9)
		"orange_ember_trails":
			return Color(1.0, 0.4, 0.08)
		"broken_chain_particles", "blood_mist_aura", "spectral_blood_geysers":
			return Color(0.72, 0.12, 0.14)
		"ethereal_foxfire_cyan", "jade_mist_swirl", "desperate_flickering_form":
			return Color(0.35, 0.85, 0.78)
		"red_flame_aura", "exploding_fire_pools":
			return Color(1.0, 0.28, 0.05)
		"ice_crystal_formation", "time_frozen_particles":
			return Color(0.55, 0.78, 1.0)
		"golden_divine_glow", "celestial_wing_particles", "corrupted_divine_light":
			return Color(0.95, 0.82, 0.35)
		_:
			return Color(1.0, 0.35, 0.06) if phase < 3 else Color(1.0, 0.72, 0.28)
