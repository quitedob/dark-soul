class_name CampaignInteriorMirrorView
extends Node3D
## The single 03_02 wall mirror looks into the existing level's World3D.
## It is a fixed directional reflection, not a copied stair scene or a portal.
## API: docs.godotengine.org/en/stable/tutorials/rendering/viewports.html

const RESOLUTION := Vector2i(256, 256)
const UPDATE_INTERVAL := .125
const WAKE_DISTANCE := 18.0
const RELEASE_DISTANCE := 24.0
# Only this disk uses visual layer 20. Its own camera excludes that layer,
# preventing a ViewportTexture from recursively sampling its render target.
const MIRROR_VISUAL_LAYER := 1 << 19
const MIRROR_SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;
uniform sampler2D reflected_world : source_color, filter_linear, repeat_disable;
void fragment() {
	if (length(UV - vec2(0.5)) > 0.49) {
		discard;
	}
	// The live image is horizontally reversed by the silvered mirror face.
	ALBEDO = texture(reflected_world, vec2(1.0 - UV.x, UV.y)).rgb * vec3(0.91, 0.98, 0.96);
}
"""

var _scene_space: Node3D
var _target_local := Vector3.ZERO
var _source_viewport: Viewport
var _view: SubViewport
var _camera: Camera3D
var _surface: MeshInstance3D
var _material: ShaderMaterial
var _elapsed := UPDATE_INTERVAL


func configure(scene_space: Node3D, target_local: Vector3) -> void:
	_scene_space = scene_space
	_target_local = target_local


func _ready() -> void:
	if not is_instance_valid(_scene_space):
		push_error("The return mirror requires its actual level coordinate space")
		set_process(false)
		return
	_source_viewport = get_viewport()
	var shader := Shader.new()
	shader.code = MIRROR_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	var disk := QuadMesh.new()
	disk.size = Vector2(1.92, 1.92)
	_surface = MeshInstance3D.new()
	_surface.name = "LiveCircularMirrorFace"
	_surface.mesh = disk
	_surface.material_override = _material
	_surface.layers = MIRROR_VISUAL_LAYER
	_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_surface.visible = false
	add_child(_surface)
	# Both values are global only after the completed level enters the tree.
	set_meta("reflection_target_global", _scene_space.to_global(_target_local))
	set_meta("reflection_origin_global", to_global(Vector3(0, 0, .10)))
	set_meta("reflection_resolution", RESOLUTION)
	set_meta("reflection_update_hz", 1.0 / UPDATE_INTERVAL)
	set_meta("reflection_source", "shared_actual_world")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL:
		return
	_elapsed = 0.0
	if not is_instance_valid(_source_viewport) or not is_instance_valid(_scene_space):
		_release_view()
		return
	var observer := _source_viewport.get_camera_3d()
	if observer == null:
		_release_view()
		return
	var distance := observer.global_position.distance_to(global_position)
	if distance > RELEASE_DISTANCE:
		_release_view()
		return
	if not is_visible_in_tree() or not observer.is_position_in_frustum(global_position):
		if is_instance_valid(_view):
			_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if not is_instance_valid(_view):
		if distance > WAKE_DISTANCE:
			return
		_create_view(observer)
	# Use global coordinates across the SubViewport boundary. Re-evaluate them
	# when updating so a translated/rotated loaded level remains correctly aimed.
	_camera.global_position = to_global(Vector3(0, 0, .10))
	var target_global := _scene_space.to_global(_target_local + Vector3.UP * 1.8)
	_camera.look_at(target_global, _scene_space.global_basis.y.normalized())
	_camera.environment = observer.environment
	_camera.attributes = observer.attributes
	_camera.cull_mask = observer.cull_mask & ~MIRROR_VISUAL_LAYER
	set_meta("reflection_target_global", target_global)
	set_meta("reflection_origin_global", _camera.global_position)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _create_view(observer: Camera3D) -> void:
	_view = SubViewport.new()
	_view.name = "ActualStairReflection256"
	_view.size = RESOLUTION
	_view.own_world_3d = false
	_view.world_3d = get_world_3d()
	_view.gui_disable_input = true
	_view.audio_listener_enable_2d = false
	_view.audio_listener_enable_3d = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_view)
	_camera = Camera3D.new()
	_camera.name = "ActualReturnStairCamera"
	_camera.fov = 24.0
	_camera.near = .08
	_camera.far = 90.0
	_camera.cull_mask = observer.cull_mask & ~MIRROR_VISUAL_LAYER
	_view.add_child(_camera)
	_camera.make_current()
	_material.set_shader_parameter("reflected_world", _view.get_texture())
	_surface.visible = true
	set_meta("reflection_active", true)


func _release_view() -> void:
	if is_instance_valid(_surface):
		_surface.visible = false
	if _material != null:
		_material.set_shader_parameter("reflected_world", null)
	if is_instance_valid(_view):
		_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_view.queue_free()
	_view = null
	_camera = null
	set_meta("reflection_active", false)


func _exit_tree() -> void:
	_release_view()
