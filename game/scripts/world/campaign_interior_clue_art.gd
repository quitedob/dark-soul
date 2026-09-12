class_name CampaignInteriorClueArt
extends RefCounted
## Static, level-local scene evidence. The runtime owns choices and interactions.
## Imported resource meshes remain unchanged; posed figures use a private
## mesh without their plinth. Native inscriptions are batched by material.

const StoryArt = preload("res://scripts/world/campaign_story_prop_renderer.gd")
const EnvironmentArt = preload("res://scripts/world/campaign_environment_renderer.gd")
const MirrorView = preload("res://scripts/world/campaign_interior_mirror_view.gd")
const InterfaceFont = preload("res://assets/fonts/NotoSansSC-AshenHollow.ttf")


static func build(plan: Dictionary, theme: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "InteriorSceneEvidence"
	root.set_meta("scene_story_version", int(plan.get("scene_story_version", 0)))
	var batches: Dictionary = {}
	var materials := _materials()
	for stage: Dictionary in plan.get("stages", []):
		var cue: Dictionary = stage.get("visual_clue", {})
		if not cue.is_empty():
			_build_cue(root, batches, materials, cue, int(stage["index"]))
		for motif: Dictionary in stage.get("option_visuals", []):
			_build_control(root, batches, materials, motif, int(stage["index"]))
	for owner: Dictionary in plan.get("owners", []):
		_build_owner(root, batches, materials, owner)
	var landmark: Dictionary = plan.get("top_landmark", {})
	if not landmark.is_empty():
		_build_goal(root, batches, materials, landmark, theme)
	for readable: Dictionary in plan.get("scene_readables", []):
		_build_leaf(root, batches, materials, readable)
	for record: Dictionary in plan.get("revisit_interactions", []):
		if String(record.get("art_kind", "")) != "mounted_mirror":
			_build_leaf(root, batches, materials, record)
	for prop: Dictionary in plan.get("props", []):
		_build_owned_details(batches, materials, prop, theme)
	if plan.has("stele_east_marks"):
		_build_east_marks(root, batches, materials, plan["stele_east_marks"])
	if plan.has("stele_scout_reward"):
		_build_scout_copy(root, materials, plan["stele_scout_reward"], String(plan["id"]))
	if plan.has("mounted_return_mirror"):
		_build_mounted_mirror(root, batches, materials, plan["mounted_return_mirror"])
	if plan.has("empty_mirror_frame"):
		_build_empty_frame(root, batches, materials, plan["empty_mirror_frame"])
	var foreign: Dictionary = plan.get("foreign_store_art", {})
	if not foreign.is_empty():
		_build_foreign_store(root, batches, materials, foreign)
	var souls: Dictionary = plan.get("souls", {})
	var drop: Dictionary = souls.get("drop", {})
	if drop.has("landing_center"):
		_build_book_pile(root, batches, materials, drop["landing_center"])
	var ladder: Dictionary = souls.get("roof_ladder", {})
	if ladder.has("bottom") and ladder.has("top"):
		_build_ladder(root, batches, materials, ladder)
	_flush(root, batches)
	return root


static func set_up(parent: Node3D, plan: Dictionary, theme: StringName) -> Node3D:
	if parent == null:
		return null
	var root := build(plan, theme)
	parent.add_child(root)
	return root


static func _materials() -> Dictionary:
	return {"stone": _material(Color("515955"), .88, .08),
		"recess": _material(Color("202b2b"), .93, .08),
		"edge": _material(Color("7b8172"), .75, .20),
		"bronze": _material(Color("7d6850"), .55, .70),
		"mirror": _material(Color("aec8c3"), .19, .90),
		"beam": _material(Color("b6c5b2"), .5, .0, .50),
		"ring": _material(Color("57c6c8"), .4, .45, .50),
		"triangle": _material(Color("dd865c"), .4, .45, .50),
		"square": _material(Color("b5a0df"), .4, .45, .50),
		"gold": _material(Color("e9b755"), .29, .85, .10),
		"lamp_core": _material(Color("d9a05b"), .48, .15, .78),
		"paper": _material(Color("b8ad89"), .96, .0),
		"ink": _material(Color("302921"), .97, .0),
		"red_cloth": _material(Color("713c32"), .97, .0),
		"blue_cloth": _material(Color("354e59"), .97, .0),
		"green_cloth": _material(Color("506453"), .97, .0),
		"iron": _material(Color("343b3b"), .61, .76)}


static func _material(color: Color, roughness: float, metallic: float, glow := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	return material


static func _build_cue(root: Node3D, batches: Dictionary, mats: Dictionary, cue: Dictionary, index: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, float(cue["yaw"])), cue["position"])
	var marker := Node3D.new()
	marker.name = "CauseAndReflection_%d" % index
	marker.transform = frame
	marker.set_meta("visual_clue", cue.duplicate(true))
	root.add_child(marker)
	var source: Vector3 = cue["source"]
	var relay: Vector3 = cue["relay"]
	var receiver: Vector3 = cue["receiver"]
	var shape := String(cue["shape"])
	_box(batches, frame, Vector3(0, .14, 0), Vector3(3.25, .28, 1.1), mats["stone"])
	_box(batches, frame, Vector3(0, .30, 0), Vector3(3.0, .07, .9), mats["edge"])
	for at: Vector3 in [source, relay, receiver]:
		_box(batches, frame, Vector3(at.x, .65, at.z), Vector3(.25, .65, .3), mats["bronze"])
	# A shaped aperture physically sits in front of the first ray. Its cast
	# mark is repeated on the receiving stone and on exactly one control.
	_box(batches, frame, source, Vector3(.76, .95, .18), mats["recess"])
	for side in [-1, 1]:
		_glyph(batches, frame, source + Vector3(0, 0, side * .12), shape, .62, mats[shape])
	var incoming := (relay - source).normalized()
	var outgoing := (receiver - relay).normalized()
	var mirror_normal := (incoming - outgoing).normalized()
	# The facet bisects the incident/outgoing rays. The seal-specific roll
	# rotates its rim within that plane without falsifying the reflection.
	var mirror_basis := Basis(Quaternion(Vector3.BACK, mirror_normal)) * Basis(Vector3.BACK, float(cue["mirror_angle"]))
	_box(batches, frame, relay, Vector3(.72, .90, .11), mats["bronze"], mirror_basis)
	_box(batches, frame, relay + Vector3(0, 0, .07), Vector3(.61, .79, .04), mats["mirror"], mirror_basis)
	_box(batches, frame, receiver, Vector3(.9, 1.03, .18), mats["stone"])
	for side in [-1, 1]:
		_box(batches, frame, receiver + Vector3(0, 0, side * .1), Vector3(.78, .91, .025), mats["recess"])
		_glyph(batches, frame, receiver + Vector3(0, 0, side * .15), shape, .66, mats[shape])
	# Thick opaque light channels remain legible without bloom/transparency.
	_rod(batches, frame, source + Vector3(.16, 0, .20), relay + Vector3(-.08, 0, .20), .032, mats["beam"])
	_rod(batches, frame, relay + Vector3(.08, 0, .20), receiver + Vector3(-.16, 0, .20), .041, mats[shape])
	if String(cue["mode"]) == "split_ray":
		_rod(batches, frame, source + Vector3(.16, -.12, .20), relay + Vector3(-.08, -.08, .20), .022, mats[shape])
	elif String(cue["mode"]) == "mirror":
		_ring(batches, frame, relay + Vector3(0, 0, -.10), 1.12, mats["bronze"])
	else:
		_glyph(batches, frame, source + Vector3(0, 0, .16), shape, .82, mats["edge"])
	if cue.has("target_door"):
		var wax_at: Vector3 = cue["target_door"] + Vector3(2.05, 1.5, .33)
		_ring(batches, Transform3D.IDENTITY, wax_at, .24, mats[shape])
	var light := OmniLight3D.new()
	light.name = "InscriptionLamplight_%d" % index
	light.position = frame * Vector3(0, 2.25, .65)
	light.light_color = Color("c9c3a6")
	light.light_energy = .7
	light.omni_range = 4.5
	light.shadow_enabled = false
	root.add_child(light)


static func _build_control(root: Node3D, batches: Dictionary, mats: Dictionary, motif: Dictionary, stage: int) -> void:
	var frame := Transform3D(Basis(Vector3.UP, float(motif["yaw"])), motif["position"])
	var marker := Node3D.new()
	marker.name = "ResponseSeal_%d_%d" % [stage, int(motif["option_index"])]
	marker.transform = frame
	marker.set_meta("option_visual", motif.duplicate(true))
	root.add_child(marker)
	var shape := String(motif["shape"])
	_box(batches, frame, Vector3(0, .14, 0), Vector3(.94, .28, .82), mats["stone"])
	_box(batches, frame, Vector3(0, .61, 0), Vector3(.54, .74, .5), mats["stone"])
	_box(batches, frame, Vector3(0, 1.42, 0), Vector3(1.05, 1.10, .18), mats["bronze"])
	for side in [-1, 1]:
		_box(batches, frame, Vector3(0, 1.42, side * .105), Vector3(.90, .96, .04), mats["recess"])
		_glyph(batches, frame, Vector3(0, 1.42, side * .145), shape, .80, mats[shape])
	# The small physical mirror below the seal repeats its angle as another
	# distinction between choices; the shape carries the color-blind cue.
	_box(batches, frame, Vector3(0, .89, .15), Vector3(.40, .08, .35), mats["mirror"], Basis(Vector3.UP, float(motif["mirror_angle"])))


static func _build_owner(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var owner := Node3D.new()
	owner.name = String(record["id"]).validate_node_name()
	owner.position = record["position"]
	# The prone mesh needs more length than the former upright statue. Keep
	# that length beside the clue stand, without folding the head into it.
	if record.has("clue_position") and not bool(record.get("fixed_position", false)):
		var away: Vector3 = owner.position - (record["clue_position"] as Vector3)
		away.y = 0.0
		if away.length_squared() > .01:
			owner.position += away.normalized() * .95
	var target: Vector3 = record.get("hand_target", record["looks_toward"])
	var direction := target - owner.position
	owner.rotation.y = atan2(-direction.x, -direction.z)
	var ownership: Dictionary = record.duplicate(true)
	ownership["position"] = owner.position
	ownership["pose_pitch"] = -1.35
	owner.set_meta("ownership", ownership)
	root.add_child(owner)
	var body := StoryArt.instantiate_part("KneelingStatue")
	if body == null:
		push_error("Scene ownership requires the authored KneelingStatue")
		return
	# This library part includes a square ceremonial plinth. Retain only the
	# figure's existing triangles before posing it; no upright black slab remains.
	_remove_low_faces(body, .62)
	var scale_value: Vector3 = record.get("scale", Vector3.ONE * .53)
	body.basis = (Basis(Vector3.RIGHT, -1.35) * Basis(Vector3.FORWARD,
		float(record.get("pose_lean", .34)) * .80)).scaled_local(scale_value)
	# A rotated enclosing box would suspend the face above the floor. Read
	# existing mesh vertices for actual support; shared imported data stays intact.
	var lowest := _lowest_mesh_y(body, Transform3D.IDENTITY)
	if is_finite(lowest):
		body.position.y -= lowest
	body.name = "SlumpedOwner"
	owner.add_child(body)
	# The broken seal and opened sheet are at the lowered hand, not arranged
	# on a ceremonial pedestal. The scrape continues toward the next passage.
	var frame := owner.transform
	var hand := body.transform * Vector3(0, 1.50, -.65)
	if bool(record.get("holds_record", false)):
		var palm := body.transform * Vector3(0, 1.90, -.60)
		_box(batches, frame, palm + Vector3(.03, .025, -.03), Vector3(.48, .024, .35), mats["paper"], Basis(Vector3.UP, -.15))
		for line in 3:
			_box(batches, frame, palm + Vector3(.02, .042, -.12 + line * .07), Vector3(.30, .01, .016), mats["ink"])
	var dropped := Vector3(hand.x + .13, .06, hand.z - .23)
	_box(batches, frame, dropped + Vector3(-.07, 0, 0), Vector3(.17, .10, .33), mats["bronze"], Basis(Vector3.UP, -.24))
	_box(batches, frame, dropped + Vector3(.16, -.02, .08), Vector3(.16, .07, .31), mats["bronze"], Basis(Vector3.UP, .43))
	_box(batches, frame, dropped + Vector3(.30, -.035, -.24), Vector3(.64, .025, .42), mats["paper"], Basis(Vector3.UP, -.18))
	for line in 3:
		_box(batches, frame, dropped + Vector3(.29, -.014, -.35 + line * .10), Vector3(.38, .009, .018), mats["ink"], Basis(Vector3.UP, -.18))
	var point := dropped + Vector3(0, -.01, -.85)
	_rod(batches, frame, dropped + Vector3(0, 0, -.26), point, .027, mats["edge"])
	_rod(batches, frame, point, point + Vector3(-.18, 0, .22), .027, mats["edge"])
	_rod(batches, frame, point, point + Vector3(.18, 0, .22), .027, mats["edge"])


static func _remove_low_faces(root: Node3D, minimum_y: float) -> void:
	for child in root.get_children():
		if not child is MeshInstance3D or child.mesh == null:
			continue
		var source: Mesh = child.mesh
		var mesh := ArrayMesh.new()
		for surface in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for index in vertices.size():
					indices.append(index)
			var kept := PackedInt32Array()
			for triangle in range(0, indices.size(), 3):
				var highest := -INF
				for corner in 3:
					highest = maxf(highest, (child.transform * vertices[indices[triangle + corner]]).y)
				if highest > minimum_y:
					for corner in 3:
						kept.append(indices[triangle + corner])
			if kept.is_empty():
				continue
			arrays[Mesh.ARRAY_INDEX] = kept
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(mesh.get_surface_count() - 1, child.get_active_material(surface))
		if mesh.get_surface_count() == 0:
			child.free()
		else:
			child.mesh = mesh
			child.material_override = null


static func _lowest_mesh_y(node: Node3D, parent: Transform3D) -> float:
	var transform := parent * node.transform
	var lowest := INF
	if node is MeshInstance3D and node.mesh != null:
		for vertex: Vector3 in node.mesh.get_faces():
			lowest = minf(lowest, (transform * vertex).y)
	for child in node.get_children():
		if child is Node3D:
			lowest = minf(lowest, _lowest_mesh_y(child, transform))
	return lowest


static func _build_goal(root: Node3D, batches: Dictionary, mats: Dictionary, goal: Dictionary, theme: StringName) -> void:
	var frame := Transform3D(Basis(Vector3.UP, float(goal["yaw"])), goal["position"])
	var marker := Node3D.new()
	marker.name = "ActualUpperGateLandmark"
	marker.transform = frame
	marker.set_meta("goal_landmark", goal.duplicate(true))
	root.add_child(marker)
	var lintel := EnvironmentArt.instantiate_part(theme, "Wall")
	if lintel != null:
		lintel.name = "FreshStoneLintel"
		# The ground vista sees this door mainly along X. A deeper return gives
		# the refreshed stone a visible side face without filling the remote slit.
		lintel.scale = Vector3(.97, .072, .85)
		lintel.position = Vector3(0, float(goal["lintel_center_y"]) - .45, .03)
		_fresh_materials(lintel, Color("bcbbaa"))
		marker.add_child(lintel)
	# An octagonal hanging lantern has a real silhouette from the ground's
	# sideways view: glowing volume, cage ribs, a flared cap and a bottom finial.
	var center := Vector3(0, float(goal["pendant_center_y"]) - .14, 1.50)
	marker.set_meta("fixture_bounds", AABB(center - Vector3(.78, .68, .78), Vector3(1.56, 1.36, 1.56)))
	# A short real bracket projects from the thick stone return. It keeps the
	# rear half of the lantern outside the lintel rather than buried inside it.
	_rod(batches, frame, Vector3(0, 5.86, .55), Vector3(0, 5.86, 1.50), .065, mats["gold"])
	_rod(batches, frame, Vector3(0, 5.48, .55), Vector3(0, 5.86, 1.50), .040, mats["gold"])
	_rod(batches, frame, Vector3(0, 5.89, 1.50), center + Vector3(0, .53, 0), .048, mats["gold"])
	_rod(batches, frame, center + Vector3(0, -.32, 0), center + Vector3(0, .27, 0), .34, mats["lamp_core"])
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var next_angle := TAU * float(index + 1) / 8.0
		var radial := Vector3(cos(angle), 0, sin(angle))
		var next_radial := Vector3(cos(next_angle), 0, sin(next_angle))
		var lower := center + radial * .43 + Vector3(0, -.39, 0)
		var waist := center + radial * .60
		var upper := center + radial * .47 + Vector3(0, .34, 0)
		var eave := center + radial * .72 + Vector3(0, .33, 0)
		_rod(batches, frame, lower, waist, .042, mats["gold"])
		_rod(batches, frame, waist, upper, .042, mats["gold"])
		_rod(batches, frame, lower, center + next_radial * .43 + Vector3(0, -.39, 0), .039, mats["gold"])
		_rod(batches, frame, eave, center + next_radial * .72 + Vector3(0, .33, 0), .038, mats["gold"])
		_rod(batches, frame, eave, center + radial * .10 + Vector3(0, .55, 0), .046, mats["gold"])
		_rod(batches, frame, lower, center + Vector3(0, -.58, 0), .025, mats["gold"])
	_rod(batches, frame, center + Vector3(0, -.56, 0), center + Vector3(0, -.66, 0), .073, mats["gold"])
	var banner := StoryArt.instantiate_part("WarBanner")
	if banner != null:
		banner.name = "UpperGateTwoSidedBanner"
		_remove_low_faces(banner, .35)
		# The three approach views are east/south of the real gate. Hang the
		# cloth in front of its stone return, with the authored emblem facing +X.
		banner.position = Vector3(1.65, 3.95, 1.70)
		banner.rotation.y = -PI / 2.0
		banner.scale = Vector3(.50, .37, .50)
		_two_sided_materials(banner)
		banner.set_meta("belongs_to", goal.get("belongs_to", "旧屋守门人"))
		marker.add_child(banner)
		_rod(batches, frame, Vector3(1.65, 5.48, .55), Vector3(1.65, 5.48, 1.70), .055, mats["gold"])
		_rod(batches, frame, Vector3(1.65, 5.10, .55), Vector3(1.65, 5.48, 1.70), .036, mats["gold"])
		var banner_fill := OmniLight3D.new()
		banner_fill.name = "UpperGateBannerBounce"
		banner_fill.position = Vector3(2.40, 5.35, 2.00)
		banner_fill.light_color = Color("e6bc88")
		banner_fill.light_energy = .65
		banner_fill.omni_range = 3.4
		banner_fill.shadow_enabled = false
		marker.add_child(banner_fill)
	var light := OmniLight3D.new()
	light.name = "UpperGatePendantLight"
	light.position = frame * (center + Vector3(0, -.12, .12))
	light.light_color = Color("e5b66e")
	light.light_energy = 1.8
	light.omni_range = 7.0
	light.shadow_enabled = false
	root.add_child(light)


static func _two_sided_materials(root: Node3D) -> void:
	for child in root.get_children():
		if not child is MeshInstance3D or child.mesh == null:
			continue
		for surface in child.mesh.get_surface_count():
			var source := child.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var unique := source.duplicate() as BaseMaterial3D
			unique.cull_mode = BaseMaterial3D.CULL_DISABLED
			# These copies belong only to this goal fixture; neither chapter
			# banners nor the source GLB acquire the brighter red/gold treatment.
			var surface_name := String(child.name) + " " + source.resource_name
			if surface_name.contains("cloth"):
				unique.albedo_color = Color("b0472e")
				unique.roughness = .78
			elif surface_name.contains("trim"):
				unique.albedo_color = Color("d2a64d")
				unique.metallic = .72
				unique.roughness = .40
				unique.emission_enabled = true
				unique.emission = Color("d2a64d")
				unique.emission_energy_multiplier = .08
			child.set_surface_override_material(surface, unique)


static func _fresh_materials(node: Node3D, color: Color) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var copies: Array[Material] = []
		for surface in node.mesh.get_surface_count():
			var source := node.get_active_material(surface) as BaseMaterial3D
			if source == null:
				copies.append(_material(color, .78, .05))
				continue
			var unique := source.duplicate() as BaseMaterial3D
			unique.albedo_color = color
			unique.roughness = .78
			unique.metallic = .05
			unique.emission_enabled = false
			copies.append(unique)
		node.material_override = null
		for surface in copies.size():
			node.set_surface_override_material(surface, copies[surface])
	for child in node.get_children():
		if child is Node3D:
			_fresh_materials(child, color)


static func _build_leaf(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var frame := Transform3D(Basis.IDENTITY, record["position"])
	var table_top := .0 if bool(record.get("on_existing_table", false)) else .92
	if table_top > 0.0:
		_box(batches, frame, Vector3(0, .43, 0), Vector3(.65, .86, .60), mats["stone"])
		_box(batches, frame, Vector3(0, .90, 0), Vector3(1.64, .10, 1.15), mats["bronze"])
	# An upright reading slope carries real Chinese lines; loose sheets, wax
	# and a broken brush make the contradictory note an object in the room.
	var slope := Basis(Vector3.RIGHT, -PI / 6.0)
	_box(batches, frame, Vector3(0, table_top + .31, 0), Vector3(1.55, .72, .07), mats["paper"], slope)
	_box(batches, frame, Vector3(-.46, table_top + .025, .30), Vector3(.57, .025, .37), mats["paper"], Basis(Vector3.UP, -.20))
	_rod(batches, frame, Vector3(.40, table_top + .035, .3), Vector3(.76, table_top + .035, .05), .022, mats["ink"])
	_ring(batches, frame, Vector3(.57, table_top + .05, .24), .13, mats["red_cloth"], Basis(Vector3.RIGHT, PI / 2.0))
	var label := Label3D.new()
	label.name = String(record["id"]).validate_node_name() + "_LeafText"
	label.text = String(record.get("inscription", record["title"]))
	label.font = InterfaceFont
	label.font_size = 40
	label.pixel_size = .0017
	label.modulate = Color("28271e")
	label.outline_size = 0
	label.no_depth_test = false
	label.transform = frame * Transform3D(slope, Vector3(0, table_top + .32, .065))
	label.set_meta("scene_readable", record.duplicate(true))
	root.add_child(label)


static func _build_owned_details(batches: Dictionary, mats: Dictionary, prop: Dictionary, theme: StringName) -> void:
	var part := String(prop["part_id"])
	if part not in ["WarTable", "RitualDesk"]:
		return
	var basis := Basis(Vector3.UP, float(prop.get("rotation_y", 0.0))).scaled_local(prop.get("scale", Vector3.ONE))
	var frame := Transform3D(basis, prop["position"])
	var target: Vector3 = prop.get("mechanism_position", prop.get("looks_toward", prop["position"]))
	var direction := frame.basis.inverse() * (target - frame.origin)
	direction.y = 0
	direction = direction.normalized() if direction.length_squared() > .001 else Vector3.FORWARD
	var shape := String(prop.get("seal_shape", "triangle"))
	if part == "WarTable":
		# An actual little flag stands in the map, with a snapped rod pointing
		# to the relevant mechanism. The geometry is more than an ownership tag.
		_rod(batches, frame, Vector3(0, 1.33, 0), Vector3(0, 2.02, 0), .036, mats["bronze"])
		for strip in 4:
			_box(batches, frame, Vector3(.09 + strip * .08, 1.88 - strip * .012, sin(strip * .8) * .035), Vector3(.095, .29, .025), mats[shape])
		_rod(batches, frame, Vector3(.1, 1.35, 0), Vector3(.1, 1.35, 0) + direction * .98, .028, mats["bronze"])
		_glyph(batches, frame, Vector3(.20, 1.86, .065), shape, .18, mats["recess"])
	else:
		var page := Vector3(.22, 1.22, -.02)
		_box(batches, frame, page, Vector3(.75, .018, .58), mats["paper"])
		# Alternating protruding fibres form a torn edge, repeated by a matching
		# colored wax seal at the paper and its destination control.
		for tooth in 7:
			_box(batches, frame, page + Vector3(-.34 + tooth * .105, .008, -.29 - .014 * (tooth % 2)),
				Vector3(.065, .015, .09 + .03 * (tooth % 2)), mats["paper"])
		_ring(batches, frame, page + Vector3(.24, .036, .16), .19, mats[shape], Basis(Vector3.RIGHT, PI / 2.0))
		var pen := Vector3(-.55, 1.25, .30)
		_rod(batches, frame, pen - direction * .23, pen + direction * .35, .023, mats["ink"])
		_rod(batches, frame, pen + direction * .35, pen + direction * .45, .012, mats["bronze"])
		if String(theme) == "theme_ember_abyss":
			_box(batches, frame, pen + direction * .45 + Vector3(0, -.018, 0), Vector3(.06, .008, .045), mats["ink"])


static func _build_east_marks(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var frame := Transform3D(Basis(Vector3.UP, float(record["yaw"])), record["position"])
	var marker := Node3D.new()
	marker.name = "SteleEastWallMarks"
	marker.transform = frame
	marker.set_meta("object_lore", record.duplicate(true))
	root.add_child(marker)
	# The layout owns this wall's masonry and collider; only the two exposed
	# inscription faces are added here, avoiding a coplanar duplicate wall.
	var shape := String(record["shape"])
	for side in [-1, 1]:
		_glyph(batches, frame, Vector3(0, 1.40, side * .28), shape, 1.05, mats[shape])
		for cut in 4:
			_rod(batches, frame, Vector3(-1.1 + cut * .10, .7, side * .28), Vector3(-.96 + cut * .10, 1.05, side * .28), .025, mats["edge"])


static func _build_scout_copy(root: Node3D, mats: Dictionary, reward: Dictionary, interior_id: String) -> void:
	var copy := Node3D.new()
	copy.name = "SteleScoutCopy"
	copy.position = reward["position"]
	copy.visible = false
	copy.set_meta("interior_stele_scout_id", interior_id)
	copy.set_meta("object_lore", reward.duplicate(true))
	root.add_child(copy)
	var local_batches: Dictionary = {}
	_box(local_batches, Transform3D.IDENTITY, Vector3.ZERO, Vector3(.96, .80, .09), mats["stone"])
	_glyph(local_batches, Transform3D.IDENTITY, Vector3(0, 0, .07), String(reward["shape"]), .66, mats[String(reward["shape"])])
	_flush(copy, local_batches)
	var light := OmniLight3D.new()
	light.name = "WarmLight"
	light.position = Vector3(0, .18, .65)
	light.light_color = Color("e5bc7e")
	light.light_energy = .9
	light.omni_range = 3.8
	light.shadow_enabled = false
	copy.add_child(light)


static func _build_mounted_mirror(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var frame := Transform3D(Basis(Vector3.UP, float(record.get("rotation_y", PI / 2.0))), record["position"])
	var marker := Node3D.new()
	marker.name = "GroundReturnMemoryMirror"
	marker.transform = frame
	marker.set_meta("object_lore", record.duplicate(true))
	root.add_child(marker)
	var imported := StoryArt.instantiate_part("MemoryMirror")
	if imported != null:
		# Reuse the actual polished disk, leave its floor stand behind, and give
		# it visible wall fasteners. It is a hanging object, not a floating statue.
		for child in imported.get_children():
			if not String(child.name).ends_with("_mirror"):
				child.free()
			elif child is MeshInstance3D:
				var center: Vector3 = child.mesh.get_aabb().get_center()
				child.position = -center
		imported.scale = Vector3.ONE * .78
		imported.position = Vector3(0, 2.3, -.10)
		marker.add_child(imported)
	var center := Vector3(0, 2.3, -.13)
	_ring(batches, frame, center, 2.1, mats["bronze"])
	for side in [-1, 1]:
		_box(batches, frame, Vector3(side * .73, 3.2, .06), Vector3(.18, .16, .38), mats["bronze"])
		_rod(batches, frame, Vector3(side * .73, 3.2, -.13), center + Vector3(side * .65, .72, 0), .042, mats["bronze"])
	var target: Vector3 = record["looks_toward"]
	# This helper is instantiated only for the uniquely relocated 03_02 mirror.
	# Its camera shares this exact level, including the real stair and doors.
	var reflection := MirrorView.new()
	reflection.name = "ActualReturnStairReflection"
	reflection.position = center + Vector3(0, 0, -.075)
	reflection.rotation.y = PI
	reflection.configure(root, target)
	marker.add_child(reflection)
	var direction := (target - frame.origin).normalized()
	_rod(batches, Transform3D.IDENTITY, frame.origin + Vector3(0, .08, 0) + direction * .7,
		frame.origin + Vector3(0, .08, 0) + direction * 2.0, .028, mats["ring"])


static func _build_empty_frame(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var frame := Transform3D(Basis.IDENTITY, record["position"])
	var marker := Node3D.new()
	marker.name = "EmptyUpperMemoryFrame"
	marker.transform = frame
	marker.set_meta("object_lore", record.duplicate(true))
	root.add_child(marker)
	for side in [-1, 1]:
		_box(batches, frame, Vector3(side * .9, 1.1, 0), Vector3(.13, 2.2, .15), mats["bronze"])
	_ring(batches, frame, Vector3(0, 2.1, 0), 2.15, mats["bronze"])
	_rod(batches, frame, Vector3(0, .9, .1), Vector3(0, .3, .1), .040, mats["ring"])
	for side in [-1, 1]:
		_rod(batches, frame, Vector3(0, .3, .1), Vector3(side * .18, .5, .1), .040, mats["ring"])


static func _build_foreign_store(root: Node3D, batches: Dictionary, mats: Dictionary, record: Dictionary) -> void:
	var floor_piece := EnvironmentArt.instantiate_part(&"theme_blood_iron", "Floor")
	var center: Vector3 = record["position"]
	if floor_piece != null:
		floor_piece.name = "ForeignIronStoreFloor"
		floor_piece.position = center + Vector3(0, .04, 0)
		root.add_child(floor_piece)
	var frame := Transform3D(Basis.IDENTITY, center)
	for row in 3:
		var at := Vector3(-2.6 + float(row) * .12, .46 + float(row) * .64, 2.15)
		_box(batches, frame, at, Vector3(1.6, .58, .85), mats["recess"])
		for x_side in [-1, 1]:
			_box(batches, frame, at + Vector3(x_side * .48, 0, .44), Vector3(.10, .59, .045), mats["iron"])
		_box(batches, frame, at + Vector3(0, 0, .46), Vector3(.15, .46, .028), mats["red_cloth"])


static func _build_book_pile(root: Node3D, batches: Dictionary, mats: Dictionary, at: Vector3) -> void:
	var marker := Node3D.new()
	marker.name = "ArchiveDropBookPile"
	marker.position = at
	marker.set_meta("landing_center", at)
	marker.set_meta("maximum_height", .53)
	root.add_child(marker)
	for index in 19:
		var row := index / 5
		var col := index % 5
		var offset := Vector3((col - 2) * .62, .085 + float(row % 2) * .19, (float(row) - 1.5) * .48)
		var angle := float((index * 17) % 11 - 5) * .11
		var frame := Transform3D(Basis(Vector3.UP, angle), at + offset)
		var cloth: Material = mats[["red_cloth", "blue_cloth", "green_cloth"][index % 3]]
		_box(batches, frame, Vector3.ZERO, Vector3(.92, .13, .62), mats["paper"])
		for y_side in [-1, 1]:
			_box(batches, frame, Vector3(0, y_side * .079, 0), Vector3(.99, .028, .68), cloth)
		_box(batches, frame, Vector3(-.49, 0, 0), Vector3(.04, .18, .68), cloth)
		_box(batches, frame, Vector3(0, .097, 0), Vector3(.53, .01, .055), mats["ink"])


static func _build_ladder(root: Node3D, batches: Dictionary, mats: Dictionary, data: Dictionary) -> void:
	var lower: Vector3 = data["bottom"]
	var upper: Vector3 = data["top"]
	var direction := upper - lower
	if direction.length_squared() < .01:
		return
	var across := direction.cross(Vector3.UP).normalized()
	var frame := Transform3D.IDENTITY
	var marker := Node3D.new()
	marker.name = "RoofRouteLadder"
	marker.set_meta("ladder_route", data.duplicate(true))
	root.add_child(marker)
	for side in [-1, 1]:
		var offset: Vector3 = across * side * 2.1 + Vector3.UP * .12
		_rod(batches, frame, lower + offset, upper + offset, .09, mats["iron"])
	var count := maxi(2, ceili(direction.length() / .48))
	for index in count + 1:
		var center := lower.lerp(upper, float(index) / count) + Vector3.UP * .13
		_rod(batches, frame, center - across * 2.15, center + across * 2.15, .058, mats["bronze"])


static func _glyph(batches: Dictionary, frame: Transform3D, center: Vector3, shape: String, size: float, material: Material) -> void:
	if shape == "ring":
		_ring(batches, frame, center, size, material)
		return
	var points: Array[Vector3] = []
	if shape == "triangle":
		points.assign([Vector3(0, .48, 0), Vector3(-.43, -.33, 0), Vector3(.43, -.33, 0)])
	else:
		points.assign([Vector3(-.38, .38, 0), Vector3(.38, .38, 0), Vector3(.38, -.38, 0), Vector3(-.38, -.38, 0)])
	for index in points.size():
		_rod(batches, frame, center + points[index] * size, center + points[(index + 1) % points.size()] * size, .052 * size, material)


static func _ring(batches: Dictionary, frame: Transform3D, center: Vector3, size: float, material: Material, extra := Basis.IDENTITY) -> void:
	var transform := frame * Transform3D(extra * Basis(Vector3.RIGHT, PI / 2.0), center)
	transform.basis = transform.basis.scaled_local(Vector3.ONE * size)
	_queue(batches, "ring", material, transform)


static func _box(batches: Dictionary, frame: Transform3D, center: Vector3, size: Vector3, material: Material, rotation := Basis.IDENTITY) -> void:
	_queue(batches, "box", material, frame * Transform3D(rotation.scaled_local(size), center))


static func _rod(batches: Dictionary, frame: Transform3D, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var delta := to - from
	if delta.length_squared() < .000001:
		return
	var rotation := Basis(Quaternion(Vector3.UP, delta.normalized()))
	var transform := Transform3D(rotation.scaled_local(Vector3(radius * 2, delta.length(), radius * 2)), (from + to) * .5)
	_queue(batches, "rod", material, frame * transform)


static func _queue(batches: Dictionary, kind: String, material: Material, transform: Transform3D) -> void:
	var key := "%s_%d" % [kind, material.get_instance_id()]
	if not batches.has(key):
		var mesh: PrimitiveMesh
		match kind:
			"box":
				var box := BoxMesh.new()
				box.size = Vector3.ONE
				mesh = box
			"ring":
				var ring := TorusMesh.new()
				ring.inner_radius = .37
				ring.outer_radius = .5
				ring.rings = 20
				ring.ring_segments = 6
				mesh = ring
			_:
				var rod := CylinderMesh.new()
				rod.top_radius = .5
				rod.bottom_radius = .5
				rod.height = 1.0
				rod.radial_segments = 10
				mesh = rod
		batches[key] = {"mesh": mesh, "material": material, "transforms": []}
	batches[key]["transforms"].append(transform)


static func _flush(root: Node3D, batches: Dictionary) -> void:
	var count := 0
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var transforms: Array = batch["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch["mesh"]
		multi.instance_count = transforms.size()
		for index in transforms.size():
			multi.set_instance_transform(index, transforms[index])
		var instance := MultiMeshInstance3D.new()
		instance.name = "InscriptionBatch_%d" % count
		instance.multimesh = multi
		instance.material_override = batch["material"]
		instance.set_meta("placement_transforms", transforms.duplicate())
		root.add_child(instance)
		count += 1
	root.set_meta("native_art_batches", count)
