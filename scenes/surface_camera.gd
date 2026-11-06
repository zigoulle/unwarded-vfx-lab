## The surface-riding camera (the gravity spike, docs/zones/lava-ball-gravity-
## system.md): today's camera (distance_m behind, height_m above the player,
## looking at him, turned round him by the mouse's yaw), set in the frame of
## the ground under him (frame: his up, and the heading
## carried along his path) instead of the world's. On flat ground (up +Y,
## heading -Z) it is exactly today's camera. Node-free.
class_name SurfaceCamera
extends RefCounted


## The pivot's frame: the ground's frame at the player (`up`, heading
## `forward`) turned `yaw_deg` round his up (the mouse; yaw 0 looks along
## the heading, 90 along its left, as the game's simulation).
static func pivot_basis(up: Vector3, forward: Vector3, yaw_deg: float) -> Basis:
	return Basis(up, deg_to_rad(yaw_deg)) * frame(up, forward)


## The camera's world transform: `distance_m` behind and `height_m` above
## `pivot` in pivot_basis, looking at the pivot, its screen up the ground's.
## `shake` (ScreenShake's offset) moves it in the pivot's frame, as today's
## rig shook the camera inside its pivot. `pitch_deg` tilts it to look that
## much further down from the same spot (`[camera] curved_pitch_deg`, for a
## curved ground's near horizon; the caller passes 0 on flat ground).
static func place(pivot: Vector3, up: Vector3, forward: Vector3, yaw_deg: float, distance_m: float,
		height_m: float, shake := Vector3.ZERO, pitch_deg := 0.0) -> Transform3D:
	var rig := Transform3D(pivot_basis(up, forward, yaw_deg), pivot)
	var home := Transform3D(Basis(), Vector3(0, height_m, distance_m)).looking_at(Vector3.ZERO, Vector3.UP)
	home.origin += shake
	if pitch_deg != 0.0:
		home.basis = home.basis * Basis(Vector3.RIGHT, -deg_to_rad(pitch_deg))
	return rig * home


## True when a pillar standing at `foot` along `up` (`radius` wide, `height`
## tall) stands across the line from the camera at `camera` to `target` (a
## player's chest): it hides them (ruling Q8: it then fades). Measured in
## the pillar's own frame, so it holds on any up (the ball's underside too);
## on flat ground (foot on the floor, up +Y) it is the ring's old check.
static func pillar_hides(camera: Vector3, target: Vector3, foot: Vector3, up: Vector3, radius: float,
		height: float) -> bool:
	var cam_rel := camera - foot
	var target_rel := target - foot
	var cam_h := cam_rel.dot(up)
	var target_h := target_rel.dot(up)
	var a := cam_rel - up * cam_h
	var ab := (target_rel - up * target_h) - a
	if ab.length_squared() < 0.000001:
		return false
	var t := clampf(-a.dot(ab) / ab.length_squared(), 0.0, 1.0)
	if t <= 0.0 or t >= 1.0:
		return false
	if (a + ab * t).length() >= radius:
		return false
	return lerpf(cam_h, target_h, t) <= height


## How far along the line from `target` (where it looks, the player) to
## `camera` (its spot) the camera may stand, as a share (1: its spot): its
## spot inside a column of `columns` ({foot: Vector2 on the floor at
## `foot_y`, radius_m, height_m}: the cliff's and the caves' walls), widened
## by `margin`, slides it in to just short of that column's near side, and
## again for any column it then stands in; never under `min_share` (P-O's
## walkthrough, 2026-11-05: the camera saw into the walls). A column only
## between them, the camera clear of it, is the fade's (it dithers); one
## round the player himself gains nothing pulled in, so it is passed over.
static func clear_share(target: Vector3, camera: Vector3, columns: Array, foot_y: float, margin: float,
		min_share: float) -> float:
	var share := 1.0
	var from := Vector2(target.x, target.z)
	var way := Vector2(camera.x, camera.z) - from
	var along := way.length_squared()
	if along < 0.000001:
		return share
	for pass_k in 8:
		var spot := target.lerp(camera, share)
		var flat := Vector2(spot.x, spot.z)
		var nearest := share
		for column: Dictionary in columns:
			var foot: Vector2 = column["foot"]
			var reach := float(column["radius_m"]) + margin
			if flat.distance_squared_to(foot) >= reach * reach or spot.y - foot_y > float(column["height_m"]):
				continue
			# The line's entry into the column's circle, from his side.
			var rel := from - foot
			var b := rel.dot(way)
			var c := rel.length_squared() - reach * reach
			if c <= 0.0:
				continue
			var disc := b * b - along * c
			if disc < 0.0:
				continue
			nearest = minf(nearest, (-b - sqrt(disc)) / along - 0.0001)
		if nearest >= share:
			break
		share = maxf(min_share, nearest)
		if share <= min_share:
			break
	return share


## The camera's share this frame (clear_share's) from `current`, its last:
## in at once to a nearer `wanted` (never a frame inside rock), back out
## toward a farther one at the pace of `release_s` for the whole way.
static func eased_share(current: float, wanted: float, delta: float, release_s: float) -> float:
	if wanted <= current or release_s <= 0.0:
		return wanted
	return minf(wanted, current + delta / release_s)


## The surface frame at a point whose up is `up`, heading `forward`: x is
## right, y is up, z is back (-forward), like a Godot node facing -Z.
static func frame(up: Vector3, forward: Vector3) -> Basis:
	var ahead := (forward - up * forward.dot(up)).normalized()
	return Basis(ahead.cross(up), up, -ahead)
