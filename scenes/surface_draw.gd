## Where a thing on the ground is drawn: the frame of its ground point and
## heading (Ground: x right, up, the heading ahead), so on the lava ball a
## player, an enemy or a rack stands along the up where it is. On the level
## ground the frame is the world's moved to the point, the flat placement
## the views draw with; they keep their own flat code there (bit for bit
## what they drew before) and use this only on a curved ground
## (Ground.curved). `yaw` is the one turn every view gives a 2D facing.
## The ball's view (tickets 07, 08).
## Pure static, presentation only.
class_name SurfaceDraw
extends RefCounted


## The turn about the up (radians, as `rotation.y`) that points a model's
## front (-Z) along `facing`, a 2D facing (x right, y back).
static func yaw(facing: Vector2) -> float:
	return atan2(-facing.x, -facing.y)


## The frame at `point` heading `heading`: x right, y up, -z the heading
## (made a tangent there), at the point.
static func frame(ground: Ground, point: Vector3, heading: Vector3) -> Transform3D:
	var up := ground.up_at(point)
	var ahead := heading - up * heading.dot(up)
	if ahead.length_squared() < 0.000001:
		ahead = ground.heading_at(point)
	ahead = ahead.normalized()
	return Transform3D(Basis(ahead.cross(up), up, -ahead), point)


## A thing standing at `point` (heading `heading`), facing `facing` (its
## frame's 2D facing, x right, y back), its feet `height_m` out along the
## up: the frame turned by the facing (`yaw`, as `rotation.y` on the level
## ground) and lifted.
static func standing(ground: Ground, point: Vector3, heading: Vector3, facing: Vector2, height_m: float) -> Transform3D:
	var turn := yaw(facing) if facing.length_squared() > 0.0 else 0.0
	return frame(ground, point, heading) * Transform3D(Basis(Vector3.UP, turn), Vector3(0, height_m, 0))


## A thing drawn upright at `position` on the level ground, facing `facing`
## (`yaw`): the whole frame, so nothing is left of a tilt it was drawn with
## on a curved ground (ticket 12: the cone's tilt kept under a new yaw).
static func upright(position: Vector3, facing: Vector2) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw(facing)), position)


## `point` moved `height_m` out along the up there: where a thing over a
## body is drawn (a damage number, a spark, stun stars, a corpse's sink). On
## the level ground straight up (y + height_m), as the flat views draw.
static func lift(ground: Ground, point: Vector3, height_m: float) -> Vector3:
	return point + ground.up_at(point) * height_m
