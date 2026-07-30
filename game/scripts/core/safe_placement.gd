class_name SafePlacement
extends RefCounted
## 安全落点查询：重叠检测 + 向下找地面（重生 / Lost Echo）

const WORLD_MASK := 1
const DEFAULT_RADIUS := 0.42
const DEFAULT_HEIGHT := 1.85
const RING_RADIUS := 1.25
const RING_STEPS := 8
const MAX_DROP := 8.0


## 将候选点投影到可站立地面，失败则按同心环搜索备用点
static func resolve_standing_position(
	space: PhysicsDirectSpaceState3D,
	candidate: Vector3,
	exclude: Array[RID] = [],
	radius: float = DEFAULT_RADIUS,
	height: float = DEFAULT_HEIGHT
) -> Vector3:
	var primary: Variant = _try_candidate(space, candidate, exclude, radius, height)
	if primary is Vector3:
		return primary as Vector3
	for step in range(RING_STEPS):
		var angle := TAU * float(step) / float(RING_STEPS)
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * RING_RADIUS
		var alternate: Variant = _try_candidate(space, candidate + offset, exclude, radius, height)
		if alternate is Vector3:
			return alternate as Vector3
	# 兜底：仅向下 ray，保证可复现
	var floor_y := _ray_floor_y(space, candidate + Vector3.UP * 2.0, exclude)
	return Vector3(candidate.x, floor_y + height * 0.5, candidate.z)


static func _try_candidate(
	space: PhysicsDirectSpaceState3D,
	candidate: Vector3,
	exclude: Array[RID],
	radius: float,
	height: float
) -> Variant:
	var floor_y := _ray_floor_y(space, candidate + Vector3.UP * 2.5, exclude)
	if floor_y <= -9990.0:
		return null
	var standing := Vector3(candidate.x, floor_y + height * 0.5, candidate.z)
	if _capsule_overlaps(space, standing, exclude, radius, height):
		return null
	return standing


static func _ray_floor_y(space: PhysicsDirectSpaceState3D, from: Vector3, exclude: Array[RID]) -> float:
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * MAX_DROP)
	query.collision_mask = WORLD_MASK
	query.exclude = exclude
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return -9999.0
	var hit_pos: Vector3 = hit["position"]
	return hit_pos.y


static func _capsule_overlaps(
	space: PhysicsDirectSpaceState3D,
	center: Vector3,
	exclude: Array[RID],
	radius: float,
	height: float
) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, center)
	params.collision_mask = WORLD_MASK
	params.exclude = exclude
	params.collide_with_areas = false
	params.collide_with_bodies = true
	return not space.intersect_shape(params, 1).is_empty()
