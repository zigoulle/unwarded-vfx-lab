## Where the arena's scenery goes, and how much of it to draw. Pure static
## functions so they can be tested headless; looks only, nothing here touches
## the simulation.
class_name ArenaLayout
extends RefCounted

## Every effect: particles (embers, smoke), volumetric fog, shadows,
## anti-aliasing (MSAA 4x and SMAA).
const HIGH := "high"
## No particles, no volumetric fog, no shadows, no anti-aliasing: for headless, smoke and
## several-windows runs.
const LOW := "low"

## The tuning sections the arena's scenery is built from (the ring arena,
## the lavafall, the zone's look, the connector, the islands, the base's
## sections, the lava, the lava ball): a hot reload changing one rebuilds it
## (rebuilds).
const ARENA_SECTIONS: Array[String] = ["ring", "lavafall", "zone_look", "connector", "islands", "base", "lava", "ball",
	"ball_look"]


## Whether retuning from `before` to `after` rebuilds the arena's scenery:
## another zone (Ground.zone_of), or a change in any of ARENA_SECTIONS.
static func rebuilds(before: Dictionary, after: Dictionary) -> bool:
	if Ground.zone_of(before) != Ground.zone_of(after):
		return true
	for section: String in ARENA_SECTIONS:
		if before.get(section) != after.get(section):
			return true
	# The water zone's scenery and camera rig read the water page.
	if Ground.zone_of(after) == WaterRegistry.ZONE:
		for section: String in WaterRegistry.tuning_keys():
			if before.get(section) != after.get(section):
				return true
	return false


## The quality asked for on the command line (`++ --quality=low|high`, high
## by default). A headless run draws nothing, so it is low, unless
## `--perf-high-views` asks for high: the perf loop's headless measure of
## what the views cost the CPU at the window's quality (perf pass 18).
static func quality(user_args: PackedStringArray, headless: bool) -> String:
	if headless:
		return HIGH if "--perf-high-views" in user_args else LOW
	for arg in user_args:
		if arg == "--quality=" + LOW:
			return LOW
	return HIGH


## The 3D multisampling for a quality: 4x smooths the edges of models and
## rocks; low quality (several windows on one machine) skips its cost. In the
## game the player's graphics options decide (GraphicsSettings, main.gd).
static func msaa_3d(level: String) -> Viewport.MSAA:
	return Viewport.MSAA_DISABLED if level == LOW else Viewport.MSAA_4X


## Whether this window draws with an integrated GPU (Intel Iris Xe and the
## like), which shares the CPU's memory and has a fraction of a discrete
## card's fill rate.
static func on_integrated_gpu() -> bool:
	return RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU


## The screen-space anti-aliasing for a quality: SMAA on top of MSAA softens
## what multisampling misses, the shading speckles inside the models and the
## glowing rune and seam lines, without FXAA's blur; none at low quality.
static func screen_space_aa(level: String) -> Viewport.ScreenSpaceAA:
	return Viewport.SCREEN_SPACE_AA_DISABLED if level == LOW else Viewport.SCREEN_SPACE_AA_SMAA


## `count` ground spots (x, z) round a floor `size_m` wide, in a square band
## from `gap_m` past its edge to `gap_m + depth_m` past it, spread round all
## four sides with some jitter. Scenery placed here never stands on the
## floor. The same `seed` gives the same spots.
static func perimeter_spots(size_m: float, gap_m: float, depth_m: float, count: int, seed: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var spots: Array[Vector2] = []
	for i in count:
		var out := size_m / 2.0 + gap_m + rng.randf() * depth_m
		# Position round the square, 0..4 (one unit per side), jittered.
		var t := fposmod((float(i) + rng.randf_range(-0.4, 0.4)) / count * 4.0, 4.0)
		var side := int(t)
		var along := ((t - side) * 2.0 - 1.0) * out
		match side:
			0:
				spots.append(Vector2(along, -out))
			1:
				spots.append(Vector2(out, along))
			2:
				spots.append(Vector2(-along, out))
			_:
				spots.append(Vector2(-out, -along))
	return spots
