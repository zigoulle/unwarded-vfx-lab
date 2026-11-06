## The move's real hit area as a thin outline on the lab's floor (VFX
## all-spells ticket 15; spec: "read from the same page the game uses"):
## the shape the simulation hits with, from the move's data (MoveKit
## move_data) round the caster facing -Z (the lab's caster):
##   - a swing: a pie slice reach_m deep and arc_deg wide (a full circle at 360);
##   - a channel or a slam: a circle of radius_m;
##   - the dash: his path, half_width_m either side, distance_m ahead;
##   - the throw: where the blades fly, blade_radius_m round them all along
##     from his feet out to range_m and back (a band rounded at both ends);
##   - the parry: his front cone, front_half_angle_deg either side of his
##     facing, drawn CONE_M deep (it has no reach: any blow from the front);
##   - a hop (the log roll): its two lobes, a pie slice ahead reach_front_m
##     deep and one behind reach_back_m deep, each lobe_arc_deg wide round
##     his facing and its opposite (nothing at his sides);
##   - a tidal wave (loops_of): each wave's band, wave_width_m wide, from
##     wave_offset_m out to its tip, turned as it stands now (TURNED_KEY, radians
##     clockwise from above), and the circle of wave_reach_m: the gap round him empty;
##   - a bubble ring (loops_of): the band the bubbles' bodies sweep, ring_radius_m
##     give or take bubble_radius_m.
## A move with no hit area (the blink, the time slow) draws none; the fusion the greatsword's slice (FxMoves.data_of). The effect's
## drawn edge is held against it by the fairness check (FxReach.check).
## Developer only, never exported (the lab's folder).
extends Node3D

## How far over the floor it floats, so it draws over it (m).
const LIFT_M := 0.03
## Its colour: the lab's light outline, distinct from the dummies' rings.
const COLOUR := Color(1.0, 1.0, 1.0, 0.85)
## The points round a full circle.
const SEGMENTS := 64
## How deep the parry's cone is drawn (m): as far as its forks leap.
const CONE_M := 2.5
## A tidal wave's turn so far, as the lab adds it to the move's data.
const TURNED_KEY := "wave_turned_rad"

var _mesh := ImmediateMesh.new()
var _drawn := MeshInstance3D.new()
var _points := PackedVector3Array()
var _key: Array = []


func _init() -> void:
	name = "HitOutline"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLOUR
	material.no_depth_test = true
	_drawn.name = "Lines"
	_drawn.mesh = _mesh
	_drawn.material_override = material
	_drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_drawn)
	visible = false


## The outline's loop (world) for a move's `data` with its caster's feet at
## `at`, facing -Z; empty for a move with no hit area.
static func loop_of(data: Dictionary, at: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var lift := Vector3.UP * LIFT_M
	if data.has(FxReach.FRONT_KEY):
		var arc := deg_to_rad(clampf(float(data.get(FxReach.LOBE_ARC_KEY, 90.0)), 0.0, 180.0))
		var steps := maxi(4, ceili(SEGMENTS * arc / TAU))
		# From his feet round the front lobe, back to his feet, round the back one.
		for lobe: int in [0, 1]:
			var reach := float(data[FxReach.FRONT_KEY] if lobe == 0 else data.get(FxReach.BACK_KEY, 0.0))
			out.append(at + lift)
			for i in steps + 1:
				var angle := -arc / 2.0 + arc * float(i) / steps + (0.0 if lobe == 0 else PI)
				out.append(at + lift + Vector3(-sin(angle), 0.0, -cos(angle)) * reach)
		out.append(at + lift)
	elif data.has("reach_m") or data.has("radius_m"):
		var reach := float(data.get("reach_m", data.get("radius_m", 0.0)))
		var arc := deg_to_rad(minf(float(data.get("arc_deg", 360.0)), 360.0))
		var whole := arc >= TAU - 0.0001
		var steps := maxi(4, ceili(SEGMENTS * arc / TAU))
		if not whole:
			out.append(at + lift)
		for i in steps + 1:
			var angle := -arc / 2.0 + arc * float(i) / steps
			# 0 straight ahead (-Z), positive to his left.
			out.append(at + lift + Vector3(-sin(angle), 0.0, -cos(angle)) * reach)
		if not whole:
			out.append(at + lift)
	elif data.has(FxReach.CONE_KEY):
		var half := deg_to_rad(clampf(float(data[FxReach.CONE_KEY]), 0.0, 180.0))
		var steps := maxi(4, ceili(SEGMENTS * half / PI))
		out.append(at + lift)
		for i in steps + 1:
			var angle := -half + 2.0 * half * float(i) / steps
			out.append(at + lift + Vector3(-sin(angle), 0.0, -cos(angle)) * CONE_M)
		out.append(at + lift)
	elif data.has("range_m") and data.has("blade_radius_m"):
		var radius := float(data["blade_radius_m"])
		var far := Vector3(0.0, 0.0, -float(data["range_m"]))
		var half := maxi(4, SEGMENTS / 2)
		# Round the far end (his right, ahead, his left), then round his feet.
		for i in half + 1:
			var angle := PI * float(i) / half
			out.append(at + lift + far + Vector3(cos(angle), 0.0, -sin(angle)) * radius)
		for i in half + 1:
			var angle := PI + PI * float(i) / half
			out.append(at + lift + Vector3(cos(angle), 0.0, -sin(angle)) * radius)
		out.append(out[0])
	elif data.has("half_width_m"):
		var half := float(data["half_width_m"])
		var ahead := float(data.get("distance_m", 0.0))
		for corner: Vector2 in [Vector2(-half, 0.0), Vector2(half, 0.0), Vector2(half, -ahead),
				Vector2(-half, -ahead), Vector2(-half, 0.0)]:
			out.append(at + lift + Vector3(corner.x, 0.0, corner.y))
	return out


## The outline's separate loops (world): a shape of pieces, each drawn apart, or the
## one loop of loop_of.
static func loops_of(data: Dictionary, at: Vector3) -> Array[PackedVector3Array]:
	if data.has(FxReach.WAVE_LENGTH_KEY):
		return _wave_loops(data, at)
	if data.has("ring_radius_m"):
		var ring := float(data["ring_radius_m"])
		var body := float(data.get("bubble_radius_m", 0.0))
		return [_circle(at, ring - body), _circle(at, ring + body)]
	return [loop_of(data, at)]


## Each wave's band and the circle it turns in.
static func _wave_loops(data: Dictionary, at: Vector3) -> Array[PackedVector3Array]:
	var out: Array[PackedVector3Array] = [_circle(at, float(data.get("wave_reach_m", 0.0)))]
	var inner := float(data.get(FxReach.WAVE_OFFSET_KEY, 0.0))
	var tip := inner + float(data[FxReach.WAVE_LENGTH_KEY])
	var half := float(data.get("wave_width_m", 0.0)) / 2.0
	var lift := Vector3.UP * LIFT_M
	for i in int(data.get("wave_count", 1)):
		var bearing := float(data.get(TURNED_KEY, 0.0)) + deg_to_rad(float(data.get("wave_spread_deg", 0.0))) * i
		var along := Vector3(sin(bearing), 0.0, -cos(bearing))
		var side := Vector3(cos(bearing), 0.0, sin(bearing))
		var band := PackedVector3Array()
		for corner: Vector2 in [Vector2(inner, -half), Vector2(tip, -half), Vector2(tip, half), Vector2(inner, half),
				Vector2(inner, -half)]:
			band.append(at + lift + along * corner.x + side * corner.y)
		out.append(band)
	return out


static func _circle(at: Vector3, radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in SEGMENTS + 1:
		var angle := TAU * float(i) / SEGMENTS
		out.append(at + Vector3.UP * LIFT_M + Vector3(sin(angle), 0.0, -cos(angle)) * radius)
	return out


## Shows the hit area of a move's `data` (none: {} or a move with no hit
## area) round its caster's feet at `at`. Built again only when it changed.
func show_for(data: Dictionary, at: Vector3) -> void:
	var key := [data, at]
	if key == _key:
		return
	_key = key
	_points = PackedVector3Array()
	_mesh.clear_surfaces()
	for loop: PackedVector3Array in loops_of(data, at):
		_points.append_array(loop)
		if loop.size() < 2:
			continue
		_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for p: Vector3 in loop:
			_mesh.surface_add_vertex(p)
		_mesh.surface_end()
	visible = _points.size() > 1


## The loop drawn now (world).
func points() -> PackedVector3Array:
	return _points
