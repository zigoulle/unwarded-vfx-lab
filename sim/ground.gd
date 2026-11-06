## The ground the effects lay their floor marks on (scorches, cracks, the
## ground layers of a burst): the lab's floor is level, so every answer is
## the level ground's. The game asks the same questions of a curved planet
## too; its effects bend what they draw by these answers (SurfaceMesh,
## SurfaceDraw), so a recipe written against Ground works on both.
##
## The 2D frame: a step is x right and y back (its -y is the heading); on
## the level ground every heading is the world's -Z.
## Node-free, pure functions.
class_name Ground
extends RefCounted

## The heading every point has on level ground.
const WORLD_HEADING := Vector3.FORWARD


## True when the ground curves anywhere (level: never).
func curved() -> bool:
	return false


## True when the ground curves at `point` (level: never).
func curved_at(_point: Vector3) -> bool:
	return false


## The ground's up at `point`.
func up_at(_point: Vector3) -> Vector3:
	return Vector3.UP


## The heading a thing at `point` faces when it faces "ahead".
func heading_at(_point: Vector3) -> Vector3:
	return WORLD_HEADING


## The spot `step` off `point` (x right, y back), on the ground.
func offset(point: Vector3, _heading: Vector3, step: Vector2) -> Vector3:
	return lift(xz(point) + step)


## The distance between two ground points, along the ground.
func distance(a: Vector3, b: Vector3) -> float:
	return xz(a).distance_to(xz(b))


## `point` kept on the floor (level: as it is, on the ground plane).
func clamp_to_floor(point: Vector3) -> Vector3:
	return lift(xz(point))


## The area `point` is in (the lab has one).
func area_of(_point: Vector3) -> String:
	return "ring"


## The map spot of ground point `point`: (x, z).
static func xz(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


## The ground point over map spot `spot`: (x, 0, z).
static func lift(spot: Vector2) -> Vector3:
	return Vector3(spot.x, 0.0, spot.y)
