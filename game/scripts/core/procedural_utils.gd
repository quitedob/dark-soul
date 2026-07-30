class_name AshenProceduralUtils
extends RefCounted


static func is_mobile_runtime() -> bool:
	if OS.has_feature("mobile"):
		return true
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var bridge = Engine.get_singleton("JavaScriptBridge")
		var coarse_pointer = bridge.call(
			"eval",
			"window.matchMedia('(pointer: coarse)').matches",
			true
		)
		var mobile_browser = bridge.call(
			"eval",
			"/Android|iPhone|iPad|Mobile/i.test(navigator.userAgent)",
			true
		)
		return bool(coarse_pointer) or bool(mobile_browser)
	return OS.has_feature("web") and DisplayServer.is_touchscreen_available()


static func make_material(
	color: Color,
	roughness: float,
	metallic: float,
	emission := Color.BLACK,
	emission_energy := 0.0,
	transparent := false,
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func has_collision_shape(node: Node) -> bool:
	for child in node.get_children():
		if child is CollisionShape3D:
			return true
	return false
