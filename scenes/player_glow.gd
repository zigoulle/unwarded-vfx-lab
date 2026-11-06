## The standard player glow (gear-boons ticket 04, ruling Q33): every
## player-owned glow (a full gear set's, player effects) is this one really
## faint glow round the outer edge, marking it as the player's, always under
## the enemies' danger glow, visible on Low.
##
## One knob, [look] player_glow_strength (0 to 1): at 1.0 the glow's peak is
## CAP of the dimmest danger glow (the enemies' floor warnings, the telegraph
## border, and their wind-up tints, EnemyLooks), so no value of the knob
## reaches it. Brightness as LightningLook counts it: the colour's brightest
## channel times its opacity (or its added light).
##
## Drawn by player_glow.gdshader: unshaded and added over the model, so it
## needs neither lights nor the graphics glow (off on Low). One shared
## material per colour, built once (material).
##
## Use: CharacterModel.set_glow(color, look) on a player's model; an effect
## puts PlayerGlow.material(color, look) as a next pass or overlay on its
## meshes.
class_name PlayerGlow
extends RefCounted

const SHADER := preload("res://scenes/player_glow.gdshader")
## The glow at full strength, as a share of the dimmest danger glow.
const CAP := 0.6
## The game's enemy warnings on the floor (its wind-up, slam, dive and
## cast tints): the glow stays under the dimmest of them, so a player's ring
## never reads as a danger.
const DANGER_TINTS: Array[Color] = [Color(1.0, 0.6, 0.1, 0.35), Color(1.0, 0.1, 0.05, 0.5),
	Color(1.0, 0.08, 0.08, 0.5), Color(1.0, 0.95, 0.3, 0.45)]

## The shared materials, by colour (html code), built once.
static var _materials: Dictionary = {}


## The one shared glow material for `color` (its hue, the brightest channel
## at full) at the [look] strength in `look`: the same material for the
## same colour every call, its brightness set from `look` each call (cheap),
## so a retuned knob reaches every model and effect drawing with it.
static func material(color: Color, look: Dictionary) -> ShaderMaterial:
	var key := color.to_html(false)
	var out: ShaderMaterial = _materials.get(key)
	if out == null:
		out = ShaderMaterial.new()
		out.shader = SHADER
		out.render_priority = GroundDrawOrder.PLAYER_EFFECTS
		var top := maxf(color.r, maxf(color.g, color.b))
		var hue := Color(color.r / top, color.g / top, color.b / top) if top > 0.0 else Color.WHITE
		out.set_shader_parameter("glow_color", hue)
		_materials[key] = out
	out.set_shader_parameter("peak", brightness(float(look.get("player_glow_strength", 0.0)), look))
	return out


## The dimmest of the enemies' danger glows (brightest channel x opacity).
static func danger_brightness(look: Dictionary) -> float:
	var telegraph := Color.from_string(String(look.get("telegraph_color", "#ff4a1c")), Color(1.0, 0.29, 0.11))
	var out := maxf(telegraph.r, maxf(telegraph.g, telegraph.b)) * float(look.get("telegraph_border_opacity", 0.9))
	for tint: Color in DANGER_TINTS:
		out = minf(out, maxf(tint.r, maxf(tint.g, tint.b)) * tint.a)
	return out


## The glow's peak brightness at `strength` (clamped 0 to 1).
static func brightness(strength: float, look: Dictionary) -> float:
	return clampf(strength, 0.0, 1.0) * CAP * danger_brightness(look)
