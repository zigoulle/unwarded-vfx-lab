## The effect intensity knob (GLOSSARY: Effect intensity; P-O 2026-10-18:
## "ONE knob that turns all effects up or down"): global.cfg's
## [global] effect_intensity_percent, 0 (today's look) to 100 (the look
## stills' look, docs/characters/*/<move>/look.png). The one shared place
## every character's, enemy's and boon's effect takes its strength from.
## Presentation only: the simulation never reads it.
##
## Each effect family in EFFECTS has a full set: for each kind of look
## value it scales (KINDS), the factor that turns today's value into the
## stills' one. At level t a value is today's times lerp(1, full, t): exactly
## today's at 0, the full set at 1, rising in between. Effects reach it two
## ways, both through here:
## - Built nodes, `track(node, family)`: after an effect's nodes are built
##   with today's values, the shared walk (_apply) scales their particle
##   counts, particle sizes and glowing brightness (an added particle's
##   colour, a shader's `emission`, a decal's or a material's emission
##   energy) from today's values kept on them, and again on every level
##   change (set_level), so a hot reload retunes what is on screen.
## - Values the code draws with each frame: the mage's [trail] (trail_look),
##   the hits' [impact] (impact_look), the Duelist's lightning brightness,
##   width and roughness (LightningLook, LightningArc, his blade trail), read
##   through `scaled` / `factor`.
## Never a light and never the environment's glow: a preset's extras stay
## what the preset says (Low keeps them off at any level).
class_name EffectIntensity
extends RefCounted

## The knob's place on the pages.
const SECTION := GlobalMultipliers.SECTION
const KEY := GlobalMultipliers.EFFECT_INTENSITY

## The kinds of look value an effect family scales.
## brightness: emission, glow and the colour of added (glowing) pieces;
## size: particle sprites, the ground effects' reach, the lightning's roughness;
## width: ribbons (the sand trail, the lightning); count: particles;
## trail: how long a trail or a mark lingers.
const KINDS: Array[String] = ["brightness", "size", "width", "count", "trail"]

## The full set: family -> kind -> factor at 100 (a kind left out stays
## today's). Chosen against the look stills and reference images
## (docs/dev-notes/effect-intensity.md has the reading of each).
const EFFECTS := {
	# The mage's light sand trail and grains ([trail] on the feel page): the
	# light still's ribbon is about the staff's length wide and sweeps half a
	# turn, packed with grains, warm gold off the dark floor (capture
	# 2026-10-18: 1.6x trail swept only a quarter turn at the game camera).
	"mage.sand_trail": {"width": 2.2, "brightness": 1.6, "trail": 2.2, "count": 3.0},
	# His heavy ring (whirlwinds, ground shake): the heavy still's ring is a
	# band round a hollow middle, lingering the whole circle. Today's 0.75 m
	# band already reads so at the game camera, so its width stays (the light
	# trail's 2.2x, and 1.3x, filled it into a disc: captures 2026-10-18).
	"mage.sand_ring": {"trail": 1.6},
	# The mage's tornado (hh still): denser, bigger sand.
	"mage.tornado": {"count": 2.0, "size": 1.3},
	# The mage's ultimate hourglass sparkles.
	"mage.hourglass": {"count": 2.0, "size": 1.3, "brightness": 1.5},
	# The Duelist's code-drawn lightning (blade arcs, streak, tethers, wheel,
	# clap, bolts, forks, the blade trail) and his pack flashes' brightness
	# (LightningLook): the stills' white-hot, thick, branching bolts, past
	# the danger telegraphs (P-O accepted the clarity cost).
	# His blades' trail lingers to the stills' long sweep.
	# Capture 2026-10-18: at 3x the bolts and flashes clipped to flat white
	# (the stills keep a blue halo) and the flash quads' edges showed; the
	# stills' bolts are more jagged than 1.5x.
	# Second pass (2026-10-18): the strip is wider at 0 (40 cm, a 5 cm core),
	# so 2x reaches 80 cm at 100, past the first pass's 62 cm; "size" also
	# carries the blade arcs further past the tip (DuelistModel).
	# Round 2: at 2x the halos of twins and forks summed into a white mush on
	# the light swing; 1.7x keeps the strands apart.
	"duelist.lightning": {"brightness": 2.2, "width": 1.7, "size": 1.4, "trail": 2.0},
	# His pack effects (slash flash, parry burst, roll bursts, his hit
	# sparks): bigger. Never more: a flash is one additive quad, and two
	# stacked doubled it into a flat white square (capture 2026-10-18; the
	# square shows now and then at 0 too, far more often doubled).
	"duelist.packs": {"size": 1.4},
	# Their brightness (LightningLook.emission sets it on the packs each
	# frame; read there only, never tracked): a little brighter. Capture
	# 2026-10-18: at the lightning's 1.6x and up they clipped to flat white.
	"duelist.flashes": {"brightness": 1.15},
	# The hits' reach ([impact] on the feel page): spark scales, the dust,
	# the shockwave and the cracks bigger, the cracks lingering longer.
	"impact.hits": {"size": 1.4, "trail": 1.5},
	# The sand hit sparks: the stills' big gold starbursts, crisp (capture
	# 2026-10-18: 1.8x bloomed them into white balls bigger than the mage),
	# one each (their size is impact.hits'): doubling the flash quad made a
	# flat white square far more often.
	"impact.sparks": {"brightness": 1.3},
	# The ground reactions: dust, the deflect's sparks, the cracks' glow.
	"impact.ground": {"count": 2.0, "size": 1.3, "brightness": 1.6},
	# Every boon effect (BoonEventVfx, BoonStateVfx). Their explosions are
	# big Binbun packs that bloom past their emission: at 1.6x brightness
	# and 2x count Fire bomb's blew out into a white mass filling the view
	# (capture 2026-10-18), so they lift less.
	"boon.effects": {"count": 1.5, "size": 1.2, "brightness": 1.2},
	# The enemies' own effects: the bees' trails, sparks and embers, the
	# worm's flame, the crawler's dirt, the blob's splashes, the skeleton
	# mage's flames, the fire tornadoes and the bee tornado.
	"enemy.effects": {"count": 1.8, "size": 1.25, "brightness": 1.4},
	# The lava's one-shots (RingFx): vent eruptions, splashes, rock dust.
	"zone.lava": {"count": 1.6, "size": 1.2, "brightness": 1.3},
	# The VFX lab's presets (FxPreset.drawn_intensity; ticket 08, grill Q12):
	# their glow (the ribbon's, its glow pass, the burst, the bloom) and
	# their flash. A preset is tuned in the lab at the knob's level in effect.
	"fx.presets": {"brightness": 1.5},
}

## The level the drawn effects use now, 0 to 1 (set_from: the tuning in
## effect, on loading and on every hot reload).
static var level := 0.0
## family -> kind -> true for every factor read (checks: no family in the
## table goes unused).
static var reads := {}
## Weak references to the tracked roots (pruned as they are freed).
static var _tracked: Array[WeakRef] = []

const _FAMILY_META := &"effect_family"
const _TODAY_META := &"effect_today"
const _OWN_PROCESS_META := &"effect_own_process"


## The knob's level on the resolved tuning `values`, 0 to 1 (0 when the
## page has none).
static func level_of(values: Dictionary) -> float:
	return clampf(float(values.get(SECTION, {}).get(KEY, 0)) / 100.0, 0.0, 1.0)


## Every drawn effect at `at` (0 to 1): the tracked ones redrawn now, the
## others on their next frame.
static func set_level(at: float) -> void:
	var was := level
	level = clampf(at, 0.0, 1.0)
	if level != was:
		for root: Node in tracked_roots():
			_apply(root)


## Every drawn effect at the level the resolved tuning `values` holds.
static func set_from(values: Dictionary) -> void:
	set_level(level_of(values))


## The factor `family`'s `kind` draws with at `at` (0 to 1; below 0: the
## level now): 1 at 0, its full set at 1, linear between.
static func factor(family: String, kind: String, at: float = -1.0) -> float:
	var row: Dictionary = EFFECTS[family]
	if not reads.has(family):
		reads[family] = {}
	reads[family][kind] = true
	var t := level if at < 0.0 else clampf(at, 0.0, 1.0)
	return lerpf(1.0, float(row.get(kind, 1.0)), t)


## Today's `value` of `family`'s `kind` as drawn at `at` (the level now
## when below 0).
static func scaled(family: String, kind: String, value: float, at: float = -1.0) -> float:
	return value * factor(family, kind, at)


## Today's particle count `today` as drawn at `at`: rounded, never 0 for an
## effect that has any.
static func counted(family: String, today: int, at: float = -1.0) -> int:
	if today <= 0:
		return today
	return maxi(1, roundi(today * factor(family, "count", at)))


## The mage's [trail] values (feel page) as drawn at `at`: the ribbon's
## light width, its fades (how long it lingers), its glow and its grains.
## The heavy ring's fade follows mage.sand_ring, its width stays today's,
## the rest follow mage.sand_trail.
static func trail_look(values: Dictionary, at: float = -1.0) -> Dictionary:
	var out := values.duplicate()
	if out.has("light_width_m"):
		out["light_width_m"] = scaled("mage.sand_trail", "width", float(out["light_width_m"]), at)
	if out.has("fade_s"):
		out["fade_s"] = scaled("mage.sand_trail", "trail", float(out["fade_s"]), at)
	if out.has("heavy_fade_s"):
		out["heavy_fade_s"] = scaled("mage.sand_ring", "trail", float(out["heavy_fade_s"]), at)
	if out.has("glow"):
		out["glow"] = scaled("mage.sand_trail", "brightness", float(out["glow"]), at)
	if out.has("grain_count"):
		out["grain_count"] = counted("mage.sand_trail", int(out["grain_count"]), at)
	return out


## The hits' [impact] values (feel page) as drawn at `at`: the spark
## scales and the dust, shockwave and crack reach bigger, the cracks
## lingering longer (the shockwave's time stays: it is the hit's beat).
static func impact_look(values: Dictionary, at: float = -1.0) -> Dictionary:
	var out := values.duplicate()
	for key: String in out:
		if key.ends_with("_spark_scale") or key.ends_with("_radius_m"):
			out[key] = scaled("impact.hits", "size", float(out[key]), at)
	if out.has("crack_fade_s"):
		out["crack_fade_s"] = scaled("impact.hits", "trail", float(out["crack_fade_s"]), at)
	return out


# --- Tracked nodes ----------------------------------------------------------

## Puts `node` (an effect just built with today's values) under `family`'s
## full set: its particle counts, sizes and glowing brightness are drawn at
## the level now, and follow every level change. Returns `node`.
static func track(node: Node, family: String) -> Node:
	assert(EFFECTS.has(family), "an effect family of EffectIntensity.EFFECTS")
	node.set_meta(_FAMILY_META, family)
	_apply(node)
	_tracked.append(weakref(node))
	if _tracked.size() > 256:
		_prune()
	return node


## Draws a tracked `node` again at the level now, its pieces added since
## included (an effect that builds more of itself later); nothing for an
## untracked node.
static func refresh(node: Node) -> void:
	_apply(node)


## Sets today's `property` of a tracked `node` (one the walk scales: its
## colour, amount...) and draws it at the level now: for code that changes
## such a value after building (a reflected shot's trail turning silver).
static func set_today(node: Node, property: String, value: Variant) -> void:
	var holder: Object = node
	if property.begins_with("shader:") or property.begins_with("material:"):
		holder = (node as GeometryInstance3D).material_override
	var kept: Dictionary = holder.get_meta(_TODAY_META, {})
	kept[property] = value
	holder.set_meta(_TODAY_META, kept)
	var family := _family_above(node)
	var kind := _kind_of(property)
	_write(node, property, _drawn(family, kind, value) if family != "" and EFFECTS[family].has(kind) else value)


## The family of `node` or of the nearest tracked node above it, or "".
static func _family_above(node: Node) -> String:
	var at := node
	while at != null:
		if at.has_meta(_FAMILY_META):
			return family_of(at)
		at = at.get_parent()
	return ""


## The family `node` is tracked under, or "".
static func family_of(node: Node) -> String:
	return str(node.get_meta(_FAMILY_META, ""))


## The tracked roots still alive.
static func tracked_roots() -> Array[Node]:
	_prune()
	var out: Array[Node] = []
	for ref: WeakRef in _tracked:
		var node: Variant = ref.get_ref()
		if node != null:
			out.append(node)
	return out


static func _prune() -> void:
	_tracked = _tracked.filter(func(ref: WeakRef) -> bool:
		var node: Variant = ref.get_ref()
		return node != null and not (node as Node).is_queued_for_deletion())


## What a tracked `root` draws with now, for checks: "<path>:<property>" ->
## [value, kind], over every piece the shared walk scales.
static func drawn(root: Node) -> Dictionary:
	var out := {}
	for node: Node in _pieces(root):
		var path := str(root.get_path_to(node))
		for property: String in _properties(node):
			out["%s:%s" % [path, property]] = [_read(node, property), _kind_of(property)]
	return out


## `root` and every node under it that is not tracked on its own (that one
## follows its own family).
static func _pieces(root: Node) -> Array[Node]:
	var out: Array[Node] = [root]
	var i := 0
	while i < out.size():
		for child: Node in out[i].get_children():
			if not child.has_meta(_FAMILY_META):
				out.append(child)
		i += 1
	return out


## The properties of `node` the walk scales (in _read / _write terms).
static func _properties(node: Node) -> Array[String]:
	var out: Array[String] = []
	if node is CPUParticles3D:
		out.append_array(["amount", "scale_amount_min", "scale_amount_max"])
		if _added(node as CPUParticles3D):
			out.append("color")
	elif node is GPUParticles3D:
		out.append("amount")
		if (node as GPUParticles3D).process_material is ParticleProcessMaterial:
			out.append_array(["process:scale_min", "process:scale_max"])
	elif node is Decal:
		out.append("emission_energy")
	if node is GeometryInstance3D:
		var material := (node as GeometryInstance3D).material_override
		if material is ShaderMaterial and (material as ShaderMaterial).get_shader_parameter("emission") != null:
			out.append("shader:emission")
		elif material is StandardMaterial3D and (material as StandardMaterial3D).emission_enabled:
			out.append("material:emission_energy_multiplier")
	return out


## True when the particles of `emitter` are drawn added (glowing): their
## colour is their brightness. Mixed ones (smoke, dust, dirt) keep theirs.
static func _added(emitter: CPUParticles3D) -> bool:
	var material: Material = emitter.material_override
	if material == null and emitter.mesh is PrimitiveMesh:
		material = (emitter.mesh as PrimitiveMesh).material
	return material is BaseMaterial3D and (material as BaseMaterial3D).blend_mode == BaseMaterial3D.BLEND_MODE_ADD


static func _kind_of(property: String) -> String:
	if property == "amount":
		return "count"
	if property.contains("scale"):
		return "size"
	return "brightness"


static func _read(node: Node, property: String) -> Variant:
	if property.begins_with("process:"):
		return (node as GPUParticles3D).process_material.get(property.trim_prefix("process:"))
	if property == "shader:emission":
		return ((node as GeometryInstance3D).material_override as ShaderMaterial).get_shader_parameter("emission")
	if property.begins_with("material:"):
		return (node as GeometryInstance3D).material_override.get(property.trim_prefix("material:"))
	return node.get(property)


static func _write(node: Node, property: String, value: Variant) -> void:
	if property.begins_with("process:"):
		(node as GPUParticles3D).process_material.set(property.trim_prefix("process:"), value)
	elif property == "shader:emission":
		((node as GeometryInstance3D).material_override as ShaderMaterial).set_shader_parameter("emission", value)
	elif property.begins_with("material:"):
		(node as GeometryInstance3D).material_override.set(property.trim_prefix("material:"), value)
	elif node.get(property) != value:
		node.set(property, value)


## Today's values of `root`'s pieces (taken the first time the walk meets
## them), each drawn at the level now through its family's full set.
static func _apply(root: Node) -> void:
	var family := family_of(root)
	if family == "":
		return
	for node: Node in _pieces(root):
		for property: String in _properties(node):
			var kind := _kind_of(property)
			if not EFFECTS[family].has(kind):
				continue
			_write(node, property, _drawn(family, kind, _today(node, property)))


## Today's value of `node`'s `property`, kept the first time it is read.
## A material's value is kept on the material: a pack scene's materials are
## shared by its instances, so the second instance would read the first's
## drawn value. A process material is made the node's own first (other
## families may draw the same scene at other sizes).
static func _today(node: Node, property: String) -> Variant:
	if property.begins_with("process:") and not node.has_meta(_OWN_PROCESS_META):
		var particles := node as GPUParticles3D
		particles.process_material = particles.process_material.duplicate()
		node.set_meta(_OWN_PROCESS_META, true)
	var holder: Object = node
	if property.begins_with("shader:") or property.begins_with("material:"):
		holder = (node as GeometryInstance3D).material_override
	var kept: Dictionary = holder.get_meta(_TODAY_META, {})
	if not kept.has(property):
		kept[property] = _read(node, property)
		holder.set_meta(_TODAY_META, kept)
	return kept[property]


## Today's `value` of a `kind` drawn through `family`'s full set now.
static func _drawn(family: String, kind: String, value: Variant) -> Variant:
	if kind == "count":
		return counted(family, int(value))
	var f := factor(family, kind)
	if value is Color:
		var c: Color = value
		return Color(c.r * f, c.g * f, c.b * f, c.a)
	return float(value) * f
