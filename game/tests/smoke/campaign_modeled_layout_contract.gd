extends SceneTree
## Independent topology contracts; no production save files or test-only repairs.

const Layout = preload("res://scripts/world/campaign_modeled_layout.gd")
const Content = preload("res://scripts/data/campaign_content.gd")
const Builder = preload("res://scripts/world/procedural_campaign_level_builder.gd")

var _failures: Array[String] = []

func _initialize() -> void:
	var signatures: Dictionary = {}
	var checked := 0
	var cell_count := 0
	for level: Dictionary in Content.levels():
		var id := String(level["id"])
		if id == "level_01_01":
			continue
		var layout := Layout.create(level)
		_expect(not layout.is_empty(), id + ": missing deterministic layout")
		if layout.is_empty():
			continue
		var cells: Dictionary = layout["cell_set"]
		var reachable := _reachable(layout)
		_expect(reachable.size() == cells.size(), id + ": disconnected walkable cells " + str(cells.size() - reachable.size()))
		var signature := Builder._cell_signature(layout["cells"])
		_expect(not signatures.has(signature), id + ": duplicates another level's geometry")
		signatures[signature] = id
		for cell: Vector3i in layout["route"]:
			_expect(reachable.has(cell), id + ": primary route contains missing/unreachable landing " + str(cell))
		for cell: Vector3i in layout["cells"]:
			_expect(not cells.has(cell + Vector3i.UP), id + ": upper floor leaves less than actor headroom at " + str(cell))
		for point: Vector3 in layout["encounter_positions"]:
			_expect(is_finite(Builder._tile_floor_at(layout["cells"], point)), id + ": unsupported encounter anchor " + str(point))
		var start: Vector3 = layout["spawn"]
		_expect(is_finite(Builder._tile_floor_at(layout["cells"], start + Vector3.BACK * 6.0)), id + ": no supported rear camera clearance")
		for ramp: Dictionary in layout["ramps"]:
			var lower: Vector3i = ramp["lower"]
			var upper: Vector3i = ramp["upper"]
			var midpoint := Vector3i((lower.x + upper.x) / 2, lower.y, (lower.z + upper.z) / 2)
			_expect(not cells.has(midpoint) and not cells.has(midpoint + Vector3i.UP), id + ": incline gap filled by colliding floor")
		if layout.has("boss_arena_center"):
			var center: Vector3 = layout["boss_arena_center"]
			var radius := float(layout["boss_arena_radius"])
			for index in 48:
				var angle := index * TAU / 48.0
				var point := center + Vector3(cos(angle), 0, sin(angle)) * radius
				_expect(is_finite(Builder._tile_floor_at(layout["cells"], point)), id + ": boss active radius lacks floor")
			for feature: Dictionary in layout["features"]:
				var point: Vector3 = feature["position"]
				_expect(Vector2(point.x - center.x, point.z - center.z).length() >= radius + 3.0,
					id + ": permanent modeled obstacle intrudes into boss fighting radius")
		checked += 1
		cell_count += cells.size()
		print("CAMPAIGN_LAYOUT_TOPOLOGY %s cells=%d reachable=%d ramps=%d" % [id, cells.size(), reachable.size(), layout["ramps"].size()])
	_expect(checked == 28 and signatures.size() == 28, "All 28 kit levels must have distinct tested layouts")
	print("CAMPAIGN_LAYOUT_COUNTS levels=%d cells=%d" % [checked, cell_count])
	if _failures.is_empty():
		print("ASHEN_CAMPAIGN_MODELED_LAYOUT_CONTRACT_OK")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)


func _reachable(layout: Dictionary) -> Dictionary:
	var cells: Dictionary = layout["cell_set"]
	var links: Dictionary = {}
	for ramp: Dictionary in layout["ramps"]:
		for endpoint: String in ["lower", "upper"]:
			var from: Vector3i = ramp[endpoint]
			var to: Vector3i = ramp["upper" if endpoint == "lower" else "lower"]
			if not links.has(from):
				links[from] = []
			links[from].append(to)
	var visited := {Vector3i.ZERO: true}
	var pending: Array[Vector3i] = [Vector3i.ZERO]
	var cursor := 0
	while cursor < pending.size():
		var cell := pending[cursor]
		cursor += 1
		var neighbors: Array[Vector3i] = []
		for direction: Vector3i in [Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK]:
			if cells.has(cell + direction):
				neighbors.append(cell + direction)
		for other: Vector3i in links.get(cell, []):
			neighbors.append(other)
		for neighbor: Vector3i in neighbors:
			if not visited.has(neighbor):
				visited[neighbor] = true
				pending.append(neighbor)
	return visited


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
