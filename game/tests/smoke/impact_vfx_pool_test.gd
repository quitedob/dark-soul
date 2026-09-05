extends SceneTree
## Smoke contract for ImpactVfx (pooled one-shot impact bursts).
## Verifies:
##   1) pool of 8 impact emitters (+3 slam rings), all one_shot + explosiveness 1.0;
##   2) 12 consecutive spawns wrap the round-robin pool and each retriggers
##      (emitting stays true right after seed+restart);
##   3) color_for_kind returns pairwise-distinct colors (incl. unknown-kind default);
##   4) degenerate normals (exact UP, ZERO) do not crash and leave finite transforms;
##   5) spawn_slam_ring fires from its own pool.
## Prints ASHEN_IMPACT_VFX_OK on success.
## Run: godot --headless --path game --script res://tests/smoke/impact_vfx_pool_test.gd
const ImpactVfx = preload("res://scripts/fx/impact_vfx.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var vfx := ImpactVfx.new()
	vfx.name = "ImpactVfxUnderTest"
	get_root().add_child(vfx)
	await process_frame  # let the pool build + enter tree

	# 1) pool contract
	var pool: Array[GPUParticles3D] = vfx.impact_pool()
	if pool.size() != 8:
		failures.append("impact pool size %d != 8" % pool.size())
	for i in pool.size():
		if not pool[i].one_shot:
			failures.append("pool[%d] not one_shot" % i)
		if absf(pool[i].explosiveness - 1.0) > 0.001:
			failures.append("pool[%d] explosiveness %.3f != 1.0" % [i, pool[i].explosiveness])
	var rings: Array[GPUParticles3D] = vfx.ring_pool()
	if rings.size() != 3:
		failures.append("ring pool size %d != 3" % rings.size())

	# 2) 12 spawns wrap the 8-slot pool; the just-used slot must be emitting
	var kinds := ["stone_sparks", "ember", "steel", "dust"]
	for i in 12:
		var normal := Vector3.UP if i % 2 == 0 else Vector3(0.4, 0.6, 0.2).normalized()
		vfx.spawn_impact(Vector3(float(i) * 0.5, 0.5, -1.0), normal, kinds[i % kinds.size()])
		if not pool[i % pool.size()].emitting:
			failures.append("pool[%d] not emitting right after spawn %d" % [i % pool.size(), i])

	# 3) distinct kind colors (4 known + 1 default)
	var colors: Array[Color] = []
	for k in kinds:
		colors.append(ImpactVfx.color_for_kind(k))
	colors.append(ImpactVfx.color_for_kind("unknown_kind"))
	for a in colors.size():
		for b in range(a + 1, colors.size()):
			if colors[a].is_equal_approx(colors[b]):
				failures.append("color_for_kind not distinct: idx %d == idx %d" % [a, b])

	# 4) degenerate normals: exact UP (look_at up-axis fallback) and ZERO (guard)
	vfx.spawn_impact(Vector3(0.0, 1.0, 0.0), Vector3.UP, "steel")
	vfx.spawn_impact(Vector3(0.5, 1.0, 0.0), Vector3.ZERO, "dust")
	if not is_instance_valid(vfx):
		failures.append("vfx freed after degenerate normals")
	else:
		for i in pool.size():
			if not pool[i].global_position.is_finite():
				failures.append("pool[%d] position not finite after degenerate normals" % i)

	# 5) slam ring from its own pool
	vfx.spawn_slam_ring(Vector3(1.0, 0.05, 2.0), "ember")
	if not rings[0].emitting:
		failures.append("ring[0] not emitting after spawn_slam_ring")
	if not rings[0].global_position.is_finite():
		failures.append("ring[0] position not finite")

	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASHEN_IMPACT_VFX_OK")
	else:
		for f in failures:
			print("FAIL: " + f)
	print("ASHEN_DONE")
	quit(1 if not failures.is_empty() else 0)
