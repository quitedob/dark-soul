extends SceneTree
# One-shot size scanner: recursively finds every GLB, instantiates, prints AABB.
const ROOT := "res://assets/models"
func _init() -> void:
	var files: Array[String] = []
	_collect(ROOT, files)
	files.sort()
	for f in files:
		if not ResourceLoader.exists(f):
			printerr("MISSING: %s" % f); continue
		var scene := load(f) as PackedScene
		if scene == null:
			printerr("LOAD FAIL: %s" % f); continue
		var inst := scene.instantiate()
		var aabb := _aabb(inst)
		var s := aabb.size
		print("%-70s h=%.2f w=%.2f d=%.2f oy=%.2f" % [f.replace("res://assets/models/", ""), s.y, s.x, s.z, aabb.position.y])
		inst.free()
	quit()

func _collect(dir: String, out: Array[String]) -> void:
	var da := DirAccess.open(dir)
	if da == null: return
	da.list_dir_begin()
	var name := da.get_next()
	while name != "":
		if name.begins_with("."): name = da.get_next(); continue
		var p := dir.path_join(name)
		if da.current_is_dir():
			_collect(p, out)
		elif name.ends_with(".glb"):
			out.append(p)
		name = da.get_next()

func _aabb(n: Node) -> AABB:
	var bb: AABB; var first := true
	for mi in _meshes(n):
		if mi.mesh == null: continue
		var xf := _xf(mi)
		if first: bb = xf * mi.mesh.get_aabb(); first = false
		else: bb = bb.merge(xf * mi.mesh.get_aabb())
	return bb
func _xf(mi: MeshInstance3D) -> Transform3D:
	var t := Transform3D(); var p: Node = mi
	while p is Node3D and p != root: t = (p as Node3D).transform * t; p = p.get_parent()
	return t
func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if n is MeshInstance3D: out.append(n)
	for c in n.get_children(): out.append_array(_meshes(c))
	return out
