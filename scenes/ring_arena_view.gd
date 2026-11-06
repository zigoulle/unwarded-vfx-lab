## The volcano's ring arena (zone SOP 6b-6d), built procedurally in the
## style of P-O's chunky reference (faceted dark rock, outlined, lava the only
## light): the simulation's shape (RingArena, the volcano page) drawn as
## - the ring: irregular dark basalt slabs (RockMesh.add_ring_slabs) with
##   faint dim cracks and seams that warm only toward the lava edges;
## - the central pit and the outer lava: flowing lava (lava.gdshader), the
##   pit the brightest thing in the room;
## - the cave: leaning faceted rock columns rising out of the outer lava,
##   stalactites hanging from their tops and darkness above (an implied
##   ceiling, ruling Q2: no roof over the camera), ragged rocks along both
##   lava edges;
## - the two bridges: chunky rock slabs (the entrance four lanes wide) to
##   arched tunnel mouths in the wall; the exit's (entrance 2) tunnel opens
##   onto the forest's cavern (a second connector, VolcanoZoneView) while
##   the forest stands, ends at a face of lava while the ash forest's base
##   section is lava (VolcanoZone.base), dark inside otherwise;
## - the lavafall: lava pouring from over the entrance tunnel onto the
##   bridge's two outer lanes, molten lanes, and see-through falling lava a
##   character high over them (ruling Q1; the camera looks over it);
## - ambient: embers and heat shimmer over the lava (high quality only) and
##   lava spurts (RingFx), every repeated effect culled off screen.
## The lava lights the room (lights along both lava edges, ruling Q14) with a
## weak cool fill that lights the characters only (light_as_character). What
## changes during a fight (pillars, vents, swells) is ZoneLooks', driven by
## EnemyWorld; its pooled effects are this node's RingFx (fx()). Looks
## values: the volcano page's `[zone_look]`. Nothing here touches the game.
class_name RingArenaView
extends Node3D

const BASALT_SHADER := preload("res://scenes/basalt.gdshader")
const SEAM_SHADER := preload("res://scenes/seam.gdshader")
const LAVA_SHADER := preload("res://scenes/lava.gdshader")
const LAVA_FALL_SHADER := preload("res://scenes/lava_fall.gdshader")
const ROCK_SHADER := preload("res://scenes/ring_rock.gdshader")
const CURTAIN_SHADER := preload("res://scenes/lava_curtain.gdshader")
const SHIMMER_SHADER := preload("res://scenes/heat_shimmer.gdshader")
const EMBER_SHADER := preload("res://scenes/ember.gdshader")
const OUTLINE_SHADER := preload("res://scenes/outline.gdshader")

## The render layer the cool fill lights; characters are put on it too.
const CHARACTER_LAYER := 2
const LAVA_LIGHT := Color(1.0, 0.42, 0.13)
const FILL := Color(0.55, 0.65, 1.0)
const AMBIENT := Color(0.3, 0.22, 0.25)
const FOG := Color(0.035, 0.012, 0.012)
const OUTLINE_COLOR := Color(0.04, 0.025, 0.025, 1.0)
## The lava's surface, this far under the floor: the ring's edge stands this
## high over it.
const LAVA_Y := -0.7
const SEGMENTS := 96
## Floor slabs: about this wide, this far apart.
const SLAB_M := 3.2
const SLAB_GAP_M := 0.07
## The cave: column spacing along the wall (m), their height range, and the
## rock above this height sinking into darkness.
const WALL_STEP_M := 2.1
const DARK_ABOVE_M := 6.5
## The tunnel mouths: height of the opening.
const TUNNEL_M := 4.4
## How much deeper into a blocked tunnel its lava face stands than the
## darkness would (m), so the mouth frames a short tunnel ending in lava.
const LAVA_FACE_IN_M := 1.2
## Fixed seed: the scenery stands in the same places every run.
const SEED := 26
## How strongly the lava lights the rock faces turned toward it
## (ring_rock.gdshader `bounce`), at `lava_light_energy` 1.
const BOUNCE := 5.0
## The reduced lava lights' outer ones reach this much further than the full set's.
const REDUCED_OUTER_REACH := 1.45

## Set before the node enters the tree: the tuning values in effect, and how
## much to draw (ArenaLayout).
var tuning: Dictionary = {}
var quality := ArenaLayout.HIGH

static var _current: RingArenaView

var _rng := RandomNumberGenerator.new()
## The tunnel mouths ending a little way in (tunnel_ends).
var _tunnel_ends := 0
var _fx: RingFx
## room_parts.
var _room: Array = []
var _environment: Environment
## The lava lights: the full set and the reduced one (apply_graphics).
var _full_lights: Node3D
var _reduced_lights: Node3D
## The dire look (show_danger), over this room and the islands' view in it.
var _dire: DireLook


## The pooled effects of the ring arena showing now (none when another arena
## is up, or none is).
static func fx() -> RingFx:
	if _current != null and is_instance_valid(_current):
		return _current._fx
	return null


func _ready() -> void:
	_current = self
	_rng.seed = SEED
	var look := _look()
	_add_environment()
	_add_lights(look)
	_add_floor(look)
	_add_lava(look)
	_add_cave()
	_add_props(look)
	_add_lavafall(look)
	if quality == ArenaLayout.HIGH:
		_add_embers(int(look.get("embers", 240)))
		_add_shimmer(float(look.get("heat_shimmer", 0.006)))
	_collect_room()
	# Its effects' shaders compile in the game's warm-up (WarmUpList: the
	# volcano's ring_fx and zone_looks), before the run's nodes exist.
	_fx = RingFx.new(self, quality == ArenaLayout.LOW)


## The room's own drawn parts (its meshes, particles and lava lights; not
## the zone's view under it, its pooled effects, its environment or its
## characters' fill light): VolcanoZoneView hides them where nothing inside
## the volcano can be seen (perf pass 15, show_room).
func room_parts() -> Array:
	return _room


## The room drawn or not. A light keeps its set (apply_graphics shows one
## set or the other; this hides each light, not the set).
func show_room(on: bool) -> void:
	for part: Node3D in _room:
		part.visible = on


func _collect_room() -> void:
	_room.clear()
	for child in get_children():
		if child is MeshInstance3D or child is GPUParticles3D or child is CPUParticles3D or child is OmniLight3D:
			_room.append(child)
	for lights: Node3D in [_full_lights, _reduced_lights]:
		if lights:
			for light in lights.get_children():
				_room.append(light)


func _exit_tree() -> void:
	if _current == self:
		_current = null


func _process(delta: float) -> void:
	if _fx:
		_fx.step(delta, tuning)


func _look() -> Dictionary:
	return tuning.get("zone_look", {})


# --- Darkness and light -------------------------------------------------------

func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT
	env.ambient_light_energy = 7.0
	env.ambient_light_sky_contribution = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	for level in [2, 3, 4, 5]:
		env.set_glow_level(level, 1.0)
	# The far cave sinks into a dark red haze.
	env.fog_enabled = true
	env.fog_light_color = FOG
	env.fog_density = 0.01
	env.fog_sky_affect = 0.0
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	_environment = env


## The lava lights the room from both its edges; a weak cool fill from
## above lights only what is on CHARACTER_LAYER.
func _add_lights(look: Dictionary) -> void:
	var wall := RingArena.wall_radius(tuning)
	var energy := float(look.get("lava_light_energy", 1.0))
	var low := quality == ArenaLayout.LOW
	_full_lights = Node3D.new()
	_full_lights.name = "LavaLightsFull"
	add_child(_full_lights)
	_add_lava_light_ring(_full_lights, 3 if low else 6, 6 if low else 12, energy, 1.0, 1.0)
	# The reduced set (the graphics option, GraphicsSettings.LIGHTS_REDUCED):
	# half the pit's lights at twice the energy, a third of the outer ones
	# brighter and reaching further, so the room keeps about the light it had
	# (~3 ms less on Iris Xe at 1080p, perf loop pass 4).
	_reduced_lights = Node3D.new()
	_reduced_lights.name = "LavaLightsReduced"
	_reduced_lights.visible = false
	add_child(_reduced_lights)
	_add_lava_light_ring(_reduced_lights, 3, 4, energy, 2.0, REDUCED_OUTER_REACH)
	# The lavafall at the entrance tunnel.
	_add_lava_light(self, Vector3(0, 2.0, wall - 1.2), 3.0 * energy, 8.0)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-60, 30, 0)
	fill.light_color = FILL
	fill.light_energy = 0.35
	fill.light_cull_mask = 1 << (CHARACTER_LAYER - 1)
	add_child(fill)


## `inner` lights round the pit and `outer` along the outer lava, under
## `parent`, all at `gain` times the base energy, the outer ones reaching
## `outer_reach` times as far.
func _add_lava_light_ring(parent: Node3D, inner: int, outer: int, energy: float, gain: float,
		outer_reach: float) -> void:
	var pit := RingArena.pit_radius(tuning)
	var outer_r := RingArena.outer_radius(tuning)
	for i in inner:
		var a := TAU * (i + 0.5) / inner
		_add_lava_light(parent, Vector3(sin(a), 0, cos(a)) * pit * 0.55 + Vector3(0, 1.4, 0), 3.0 * energy * gain,
			pit + 6.0)
	for i in outer:
		var a := TAU * i / outer
		_add_lava_light(parent, Vector3(sin(a), 0, cos(a)) * (outer_r + 2.4) + Vector3(0, 0.5, 0), 1.8 * energy * gain,
			9.0 * outer_reach)


## The graphics options (GraphicsSettings, main.gd applies them): glow on or
## off, and which lava lights light the room (LIGHTS_FULL: every one;
## LIGHTS_REDUCED: the reduced set).
func apply_graphics(glow: bool, lava_lights: String) -> void:
	if _environment:
		_environment.glow_enabled = glow
	var reduced := lava_lights == GraphicsSettings.LIGHTS_REDUCED
	if _full_lights:
		_full_lights.visible = not reduced
	if _reduced_lights:
		_reduced_lights.visible = reduced


## Every lava light of the room (both sets and the lavafall's), lit or not.
func lava_lights() -> Array:
	return find_children("*", "OmniLight3D", true, false)


## The room's Environment (glow, fog, tone mapping).
func environment() -> Environment:
	return _environment


## The zone turned dire for the danger clock at `clock` (DireLook; the
## synced `danger_clock`, the host's tuning), the islands' view included.
## Within the graphics options apply_graphics set: no glow or light turned on.
func show_danger(world_tuning: Dictionary, clock: int) -> void:
	if _dire == null:
		_dire = DireLook.new(self, _environment)
	_dire.show(DireLook.at(world_tuning, clock))


func _add_lava_light(parent: Node3D, at: Vector3, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = LAVA_LIGHT
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.5
	parent.add_child(light)


# --- The ring and the lava ------------------------------------------------------

func _add_floor(look: Dictionary) -> void:
	var pit := RingArena.pit_radius(tuning)
	var outer := RingArena.outer_radius(tuning)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	RockMesh.add_ring_slabs(st, _rng, pit, outer, SLAB_M, SLAB_GAP_M, LAVA_Y - 0.5)
	var basalt := _material(BASALT_SHADER)
	basalt.set_shader_parameter("stone_dark", Color(0.11, 0.09, 0.11))
	basalt.set_shader_parameter("stone_light", Color(0.32, 0.26, 0.29))
	basalt.set_shader_parameter("ring_inner_m", pit)
	basalt.set_shader_parameter("ring_outer_m", outer)
	basalt.set_shader_parameter("hot_band_m", 2.5)
	basalt.set_shader_parameter("glow", float(look.get("floor_crack_glow", 0.2)))
	add_child(_mesh(st.commit(), basalt))
	# The dim glow between the slabs.
	var seam := _material(SEAM_SHADER)
	seam.set_shader_parameter("ring_inner_m", pit)
	seam.set_shader_parameter("ring_outer_m", outer)
	seam.set_shader_parameter("hot_band_m", 2.5)
	# Unlit: the seams' own colour is what shows, dim red near the lava and
	# near black in the middle.
	var crack_glow := float(look.get("floor_crack_glow", 0.2))
	seam.set_shader_parameter("brightness", 0.5 * crack_glow)
	seam.set_shader_parameter("hot", Color(0.9, 0.28, 0.06) * crack_glow)
	seam.set_shader_parameter("cool", Color(0.06, 0.015, 0.01))
	seam.set_shader_parameter("patches", 0.15)
	add_child(_mesh(_annulus(pit - 0.2, outer + 0.2, -0.12), seam))


func _add_lava(look: Dictionary) -> void:
	var pit := RingArena.pit_radius(tuning)
	var outer := RingArena.outer_radius(tuning)
	var wall := RingArena.wall_radius(tuning)
	var flow := float(look.get("lava_flow_m_per_s", 0.5))
	var centre := _material(LAVA_SHADER)
	centre.set_shader_parameter("brightness", float(look.get("pit_brightness", 1.7)))
	centre.set_shader_parameter("crust_amount", 0.12)
	centre.set_shader_parameter("scale_m", 2.6)
	# Hotter colours than the outer lava's, so the pit reads brightest rather
	# than pushing its red bands into deep red.
	centre.set_shader_parameter("deep", Color(0.9, 0.3, 0.06))
	centre.set_shader_parameter("hot", Color(1.0, 0.55, 0.12))
	centre.set_shader_parameter("white_hot", Color(1.0, 0.85, 0.42))
	# A steady drift across the pit, churning, not a whirl round its middle.
	centre.set_shader_parameter("still_core_m", 1000.0)
	centre.set_shader_parameter("flow_speed", flow)
	add_child(_mesh(_annulus(0.0, pit + 0.2, LAVA_Y), centre))
	var ring := _material(LAVA_SHADER)
	ring.set_shader_parameter("brightness", float(look.get("outer_lava_brightness", 1.1)))
	ring.set_shader_parameter("crust_amount", 0.2)
	ring.set_shader_parameter("scale_m", 3.2)
	ring.set_shader_parameter("white_hot", Color(1.0, 0.62, 0.22))
	ring.set_shader_parameter("flow_speed", flow)
	add_child(_mesh(_annulus(outer - 0.2, wall + 3.0, LAVA_Y), ring))
	# The outer ring is deep lava you wade (spec "Lava tiers"): a rock floor
	# `[lava] deep_sink_m` down under it, the ring's slabs the step down, so a
	# character wading it sinks in to its knees and more instead of standing
	# on the surface (VolcanoZoneView.sink_m).
	var sink := float(tuning.get("lava", {}).get("deep_sink_m", 1.5))
	add_child(_mesh(_annulus(outer - 0.2, wall + 3.0, -sink), _floor_rock()))


# --- The cave ---------------------------------------------------------------------

## Leaning faceted columns rising out of the outer lava all round (two rows,
## the back one taller), gaps for the two tunnels, stalactites hanging from
## the tops, and ragged rocks along both lava edges. One mesh, no outline
## (it stands against darkness).
func _add_cave() -> void:
	var pit := RingArena.pit_radius(tuning)
	var outer := RingArena.outer_radius(tuning)
	var wall := RingArena.wall_radius(tuning)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 2:
		var at := wall + (1.2 if row == 0 else 3.6)
		var count := roundi(TAU * at / (WALL_STEP_M * (1.0 if row == 0 else 1.3)))
		for i in count:
			var a := TAU * (i + _rng.randf_range(-0.3, 0.3)) / count
			var radius := _rng.randf_range(1.3, 2.3) * (1.0 if row == 0 else 1.3)
			var foot := Vector2(sin(a), cos(a)) * (at + radius * 0.4)
			if _by_a_tunnel(foot, radius + 0.4):
				continue
			var height := _rng.randf_range(5.5, 9.0) if row == 0 else _rng.randf_range(9.0, 14.0)
			var radial := Vector3(foot.x, 0, foot.y).normalized()
			var lean := Basis(Vector3.UP.cross(-radial).normalized(), _rng.randf_range(0.1, 0.24) * (1.0 + row * 0.4))
			RockMesh.add_prism_placed(st, _rng, Transform3D(lean, Vector3(foot.x, LAVA_Y - 1.0, foot.y)), radius,
				height, 0.0, _rng.randi_range(4, 6), _rng.randf_range(0.3, 0.6), 0.7)
	# Stalactites hanging from the walls' tops, over the outer lava.
	var count := roundi(TAU * wall / 1.5)
	for i in count:
		var a := TAU * (i + _rng.randf_range(-0.35, 0.35)) / count
		var spot := Vector2(sin(a), cos(a)) * (wall - _rng.randf_range(0.6, 2.2))
		if _by_a_tunnel(spot, 0.8):
			continue
		var top := _rng.randf_range(6.5, 8.5)
		RockMesh.add_stalactite(st, _rng, Vector3(spot.x, top, spot.y), _rng.randf_range(0.3, 0.75),
			minf(top - 3.6, _rng.randf_range(1.6, 3.8)), _rng.randf_range(0.3, 0.55))
	# Ragged rocks in the lava along both edges.
	for edge in 2:
		# Hugging the ring's cliff foot, clear of the swells further out.
		var r0 := outer + 0.45 if edge == 0 else pit - 0.45
		var n := roundi(TAU * r0 / 3.2)
		for i in n:
			if _rng.randf() < 0.45:
				continue
			var a := TAU * (i + _rng.randf_range(-0.3, 0.3)) / n
			var spot := Vector2(sin(a), cos(a)) * (r0 + _rng.randf_range(-0.1, 0.2) * (1.0 if edge == 0 else -1.0))
			if _by_a_tunnel(spot, 2.5) or RingArena.on_floor(tuning, spot):
				continue
			RockMesh.add_crag(st, _rng, Vector3(spot.x, LAVA_Y, spot.y), _rng.randf_range(0.3, 0.55),
				_rng.randf_range(0.4, 0.9), _rng.randf_range(0.3, 0.5), 0.8)
	var rock := _material(ROCK_SHADER)
	rock.set_shader_parameter("lava_y", LAVA_Y)
	rock.set_shader_parameter("glow_height_m", 1.4)
	rock.set_shader_parameter("near_fade_m", 3.0)
	rock.set_shader_parameter("dark_above_y", DARK_ABOVE_M)
	add_child(_mesh(st.commit(), rock))


## Lets the lava's light fall on rock drawn with ring_rock.gdshader: faces
## turned toward the nearer lava warm up (scaled by `lava_light_energy`).
func _lava_lit(material: ShaderMaterial, look: Dictionary) -> void:
	lava_lit(material, tuning, float(look.get("lava_light_energy", 1.0)))


static func lava_lit(material: ShaderMaterial, values: Dictionary, energy: float) -> void:
	material.set_shader_parameter("bounce", BOUNCE * energy)
	material.set_shader_parameter("ring_inner_m", RingArena.pit_radius(values))
	material.set_shader_parameter("ring_outer_m", RingArena.outer_radius(values))


## True when `spot` is within `margin` metres of a bridge's strip (or its
## line out through the wall): kept clear for the bridges and tunnels.
func _by_a_tunnel(spot: Vector2, margin: float) -> bool:
	for bridge: Dictionary in RingArena.bridges(tuning):
		var dir: Vector2 = bridge["dir"]
		var along := spot.dot(dir)
		var across := absf(spot.dot(Vector2(-dir.y, dir.x)))
		if along > float(bridge["from_m"]) - 1.0 and across < float(bridge["half_width_m"]) + margin:
			return true
	return false


# --- Bridges and tunnels ------------------------------------------------------------

## The two bridges as chunky slabs (one row of blocks per lane), arched
## tunnel mouths in the wall at their ends, dark inside. One outlined mesh.
func _add_props(look: Dictionary) -> void:
	var wall := RingArena.wall_radius(tuning)
	var lane := float(tuning["lavafall"]["lane_width_m"])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for bridge: Dictionary in RingArena.bridges(tuning):
		var d: Vector2 = bridge["dir"]
		var side := Vector2(-d.y, d.x)
		var half := float(bridge["half_width_m"])
		var from := float(bridge["from_m"])
		var to := float(bridge["to_m"]) + 1.6
		var yaw := atan2(d.x, d.y)
		var rows := roundi(2.0 * half / lane) if bridge["name"] == "entrance" else maxi(1, roundi(half))
		var row_w := 2.0 * half / rows
		for k in rows:
			var across := -half + (k + 0.5) * row_w
			var along := from
			while along < to - 0.3:
				var length := minf(_rng.randf_range(1.8, 2.8), to - along)
				var mid := d * (along + length / 2.0) + side * across
				RockMesh.add_block(st, _rng, Vector3(mid.x, -0.52, mid.y), Vector3(row_w - 0.06, 1.0, length - 0.06), yaw,
					_rng.randf_range(0.42, 0.58), 0.02)
				along += length
		# Piers under the bridge, in the lava.
		for f: float in [0.45, 0.8]:
			var at := d * lerpf(from, to, f)
			for s: float in [-1.0, 1.0]:
				var p := at + side * s * (half - 0.4)
				RockMesh.add_prism(st, _rng, p, 0.55, -0.9, LAVA_Y - 1.0, 5, 0.35, 0.8)
		# The tunnel mouth: two jambs and a lintel, the wall's columns round it.
		var mouth := d * (wall + 0.4)
		for s: float in [-1.0, 1.0]:
			var jamb := mouth + side * s * (half + 0.75)
			RockMesh.add_block(st, _rng, Vector3(jamb.x, (TUNNEL_M + LAVA_Y) / 2.0, jamb.y),
				Vector3(1.5, TUNNEL_M - LAVA_Y + 0.3, 1.8), yaw + _rng.randf_range(-0.06, 0.06), 0.45, 0.05)
			RockMesh.add_prism(st, _rng, mouth + side * s * (half + 2.3) + d * 0.6, 1.5, TUNNEL_M + 2.0, LAVA_Y - 1.0, 5,
				0.4, 0.6)
		RockMesh.add_block(st, _rng, Vector3(mouth.x, TUNNEL_M + 0.6, mouth.y), Vector3(2.0 * half + 3.2, 1.2, 2.0), yaw,
			0.5, 0.06)
		RockMesh.add_block(st, _rng, Vector3(mouth.x + d.x * 0.6, TUNNEL_M + 1.7, mouth.y + d.y * 0.6),
			Vector3(2.0 * half + 2.2, 1.1, 1.8), yaw + 0.04, 0.42, 0.08)
		# The entrance's tunnel is the connector cavern (VolcanoZoneView),
		# open. The exit's is entrance 2, toward the ash forest: while the
		# forest stands it is the forest's cavern, a second connector (open
		# too); while its base section is lava the tunnel ends a little way in
		# at a face of lava (the link is blocked); otherwise darkness.
		if bridge["name"] == "entrance" or _entrance_2_cavern():
			continue
		var dark := BoxMesh.new()
		dark.size = Vector3(2.0 * half + 0.6, TUNNEL_M + 0.4, 3.0)
		var inside := _mesh(dark, _lava_face(look) if _entrance_2_lava() else _black())
		var at := d * (wall + 1.9 + (LAVA_FACE_IN_M if _entrance_2_lava() else 0.0))
		inside.position = Vector3(at.x, TUNNEL_M / 2.0 - 0.2, at.y)
		inside.rotation.y = yaw
		add_child(inside)
		_tunnel_ends += 1
	var mesh := st.commit()
	var rock := _material(ROCK_SHADER)
	rock.set_shader_parameter("lava_y", LAVA_Y)
	rock.set_shader_parameter("near_fade_m", 2.0)
	rock.set_shader_parameter("dark_above_y", DARK_ABOVE_M)
	_lava_lit(rock, look)
	add_child(_mesh(mesh, rock))
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	outline.set_shader_parameter("outline_color", OUTLINE_COLOR)
	outline.set_shader_parameter("strength", float(look.get("rock_outline", 0.7)))
	outline.set_shader_parameter("width_px", float(tuning.get("look", {}).get("outline_width_px", 2.0)))
	add_child(_mesh(RockMesh.outline_hull(mesh), outline))


## How many of the ring's tunnel mouths end a little way in (darkness or a
## lava face) rather than open onto a cavern.
func tunnel_ends() -> int:
	return _tunnel_ends


## True when the ring's entrance 2 opens onto the forest's cavern
## (VolcanoZone.tunnels has the forest's tunnel; VolcanoZoneView draws it).
func _entrance_2_cavern() -> bool:
	if not (tuning.has("connector") and tuning.has("islands") and tuning.has("base")):
		return false
	for tunnel: Dictionary in VolcanoZone.tunnels(tuning):
		if tunnel["area"] == VolcanoZone.FOREST_TUNNEL:
			return true
	return false


## True when the ring's entrance 2 (its exit bridge's tunnel) is blocked by
## lava: the area graph's `entrance_2` link (VolcanoZone.link_way, from the
## base sections).
func _entrance_2_lava() -> bool:
	if not tuning.has("base"):
		return false
	for link: Dictionary in VolcanoZone.layout(tuning)["area_graph"]["links"]:
		if link["crossing"] == "entrance_2":
			return link["way"] == VolcanoZone.WAY_LAVA
	return false


## The lava face a blocked tunnel ends at: the lava sea beyond, upright.
func _lava_face(look: Dictionary) -> ShaderMaterial:
	var face := _material(LAVA_SHADER)
	face.set_shader_parameter("brightness", 0.9)
	face.set_shader_parameter("crust_amount", 0.35)
	face.set_shader_parameter("scale_m", 3.0)
	face.set_shader_parameter("flow_speed", float(look.get("lava_flow_m_per_s", 0.5)) * 0.4)
	return face


# --- The lavafall ----------------------------------------------------------------

## Lava pouring from the lintel over the entrance tunnel onto the bridge's
## two outer lanes, the lanes molten where they burn, and falling lava
## `lavafall_height_m` high over them, see-through (`lavafall_opacity`).
func _add_lavafall(look: Dictionary) -> void:
	var wall := RingArena.wall_radius(tuning)
	var height := float(look.get("lavafall_height_m", 2.2))
	var falls := SurfaceTool.new()
	falls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curtain := _material(CURTAIN_SHADER)
	curtain.set_shader_parameter("opacity", float(look.get("lavafall_opacity", 0.4)))
	curtain.set_shader_parameter("height_m", height)
	var molten := _material(LAVA_SHADER)
	molten.set_shader_parameter("brightness", 1.7)
	molten.set_shader_parameter("crust_amount", 0.12)
	molten.set_shader_parameter("scale_m", 2.0)
	molten.set_shader_parameter("flow_speed", 1.2)
	for lane: Dictionary in RingArena.lavafall_lanes(tuning):
		var size: Vector2 = lane["size"]
		var centre: Vector2 = lane["centre"]
		RockMesh.add_fall_sheet(falls, Vector3(centre.x, TUNNEL_M, wall - 0.4), Vector3(0, 0, -1), size.x * 1.15, 0.0)
		var strip := PlaneMesh.new()
		strip.size = Vector2(size.x * 0.92, size.y)
		add_child(_mesh(strip, molten, Vector3(centre.x, 0.03, centre.y)))
		if height > 0.0:
			var box := BoxMesh.new()
			box.size = Vector3(size.x * 0.95, height, size.y)
			add_child(_mesh(box, curtain, Vector3(centre.x, height / 2.0, centre.y)))
		if quality == ArenaLayout.HIGH:
			_add_lane_splash(Vector3(centre.x, 0.05, centre.y), size)
	var pour := _material(LAVA_FALL_SHADER)
	add_child(_mesh(falls.commit(), pour))


func _add_lane_splash(at: Vector3, size: Vector2) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 24
	particles.lifetime = 0.8
	particles.preprocess = 0.8
	particles.position = at
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size.x * 0.4, 0.05, size.y * 0.45)
	process.direction = Vector3.UP
	process.spread = 35.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 2.8
	process.gravity = Vector3(0, -9.8, 0)
	process.scale_min = 1.0
	process.scale_max = 2.2
	process.color_ramp = _ember_ramp()
	particles.process_material = process
	particles.draw_pass_1 = _ember_quad(0.1, 2.0)
	add_child(particles)


# --- Ambient (high quality only) ------------------------------------------------------

## Embers drifting up off the lava: `count` in all, a third over the pit,
## the rest over the outer lava. Each is one particle system, culled by its
## box when off screen.
func _add_embers(count: int) -> void:
	if count <= 0:
		return
	var pit := RingArena.pit_radius(tuning)
	var outer := RingArena.outer_radius(tuning)
	var wall := RingArena.wall_radius(tuning)
	_add_ember_ring(maxi(1, count / 3), 0.0, pit - 0.5)
	_add_ember_ring(maxi(1, count - count / 3), outer + 0.5, wall - 0.5)


func _add_ember_ring(amount: int, inner: float, outer: float) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = 5.0
	particles.preprocess = 5.0
	particles.position = Vector3(0, LAVA_Y + 0.2, 0)
	particles.visibility_aabb = AABB(Vector3(-outer, -1, -outer), Vector3(2 * outer, 14, 2 * outer))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_height = 0.2
	process.emission_ring_radius = outer
	process.emission_ring_inner_radius = inner
	process.direction = Vector3.UP
	process.spread = 20.0
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.8
	process.gravity = Vector3(0, 0.2, 0)
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.8
	process.turbulence_noise_scale = 5.0
	process.scale_min = 0.5
	process.scale_max = 1.4
	process.color_ramp = _ember_ramp()
	particles.process_material = process
	particles.draw_pass_1 = _ember_quad(0.09)
	add_child(particles)


## Heat shimmer: see-through bands standing at the pit's edge and the outer
## lava's inner edge that bend what is behind them.
func _add_shimmer(strength: float) -> void:
	if strength <= 0.0:
		return
	var material := _material(SHIMMER_SHADER)
	material.set_shader_parameter("strength", strength)
	add_child(_mesh(_band(RingArena.pit_radius(tuning) - 0.8, LAVA_Y, 1.8), material))
	add_child(_mesh(_band(RingArena.outer_radius(tuning) + 1.2, LAVA_Y, 1.8), material))


func _ember_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.75, 0.35, 1.0))
	gradient.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _ember_quad(size: float, brightness: float = 4.0) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := _material(EMBER_SHADER)
	material.set_shader_parameter("brightness", brightness)
	quad.material = material
	return quad


## Puts `node`'s every visual on CHARACTER_LAYER as well as its own, so the
## ring arena's cool fill lights it (a mage, an enemy model).
static func light_as_character(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers |= 1 << (CHARACTER_LAYER - 1)
	for child in node.get_children():
		light_as_character(child)


## True when a pillar (`radius` wide, `height` tall, standing at `pillar` on
## the ground) stands across the line from the camera at `camera` to
## `target` (a player's chest): it hides them (ruling Q8: it then fades).
## The flat case of SurfaceCamera.pillar_hides (any up).
static func hides(camera: Vector3, target: Vector3, pillar: Vector2, radius: float, height: float) -> bool:
	return SurfaceCamera.pillar_hides(camera, target, Vector3(pillar.x, 0.0, pillar.y), Vector3.UP, radius, height)


# --- Meshes ------------------------------------------------------------------------

static func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	return material


static func _mesh(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance


## Dark rock under deep lava (seen only through the lava's edge).
static func _floor_rock() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.07, 0.08)
	material.roughness = 0.95
	return material


static func _black() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0, 0, 0)
	return material


static func _ring_point(angle: float, r: float, y: float) -> Vector3:
	return Vector3(sin(angle) * r, y, cos(angle) * r)


## A flat ring (a disc when `inner` is 0) at height `y`, facing up.
static func _annulus(inner: float, outer: float, y: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		# Clockwise seen from above: Godot's front faces.
		for p: Vector3 in [_ring_point(a0, inner, y), _ring_point(a1, outer, y), _ring_point(a0, outer, y),
				_ring_point(a0, inner, y), _ring_point(a1, inner, y), _ring_point(a1, outer, y)]:
			st.add_vertex(p)
	return st.commit()


## A vertical band round the centre, `r` metres out, from `y0` up `height`,
## with UVs (x round it, y 0 at the top to 1 at the foot).
static func _band(r: float, y0: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * i / SEGMENTS
		var a1 := TAU * (i + 1) / SEGMENTS
		var u0 := float(i) / SEGMENTS
		var u1 := float(i + 1) / SEGMENTS
		var quad := [[_ring_point(a0, r, y0), Vector2(u0, 1)], [_ring_point(a0, r, y0 + height), Vector2(u0, 0)],
			[_ring_point(a1, r, y0), Vector2(u1, 1)], [_ring_point(a1, r, y0 + height), Vector2(u1, 0)]]
		for k: int in [0, 1, 2, 2, 1, 3]:
			st.set_normal(-Vector3(sin(a0), 0, cos(a0)))
			st.set_uv(quad[k][1])
			st.add_vertex(quad[k][0])
	return st.commit()
