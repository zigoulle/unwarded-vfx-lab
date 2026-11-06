## What PlayerAvatar draws a player with (Duelist ticket 04): one model per
## character, named by its roster `look` (MageLook.build_model,
## DuelistLook.build_model). The avatar only speaks this interface; each
## character's model (MageModel, DuelistModel) fills it, and its clip choice
## (MageClips, DuelistClips) makes the poses show_pose takes. Looks only.
class_name CharacterModel
extends Node3D

## Per move: the clip it plays and its markers in seconds (the clips' pose).
var markers: Dictionary = {}
## The run clip's stride speed at this model's drawn height (m/s).
var stride_m_per_s := 1.0
## How tall it is drawn (m; set_look).
var height_m := MageLook.BASE_HEIGHT_M


## Drawn once for the warm-up (WarmUpList), under the stage: what only shows in
## a fight (its hit overlay, its glow, its ribbon) showing now. In the tree by
## then. Nothing by default.
func warm_up(_look: Dictionary) -> void:
	pass


## A small ribbon on `draw` wearing `material`, at this model's place: the
## format a weapon trail is drawn in, `uv2` if its trail has it.
func _warm_ribbon(draw: ImmediateMesh, material: Material, uv2: bool) -> void:
	draw.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, material)
	for i in 4:
		draw.surface_set_color(Color.WHITE)
		draw.surface_set_uv(Vector2(i / 3.0, float(i % 2)))
		if uv2:
			draw.surface_set_uv2(Vector2.ONE)
		draw.surface_add_vertex(global_position + Vector3(i * 0.1, float(i % 2) * 0.1, 0.0))
	draw.surface_end()


## The pose (show_pose's) the game draws for `state` (a player's move, frame,
## hitstop and tick factor) on `kit`, the clip retimed on the move's frame data:
## a character's own clip choice. The mage's by default; the mage and the Duelist
## are drawn by theirs directly (PlayerAvatar), a pack's character through here.
func clip_pose(kit: MoveKit, state: Dictionary) -> Dictionary:
	return MageClips.pose(kit, state, markers)


## Shows `pose` `delta` seconds after the last call.
func show_pose(_pose: Dictionary, _delta: float) -> void:
	pass


## How it is drawn from the [look] values: `height` metres tall, the outline
## in `color` (the player's) at `outline` strength and `width_px`, its own
## colours glowing at `lift`.
func set_look(_height: float, _color: Color, _outline: float, _lift: float, _width_px: float = 2.0) -> void:
	pass


## The weapon trail's [trail] values (feel page) and the quality.
func set_trail_look(_values: Dictionary, _low_quality: bool) -> void:
	pass


## The up of the ground it stands on (PlayerAvatar, each frame; world up on
## the level ground): what falls from it falls along its negative. Nothing by
## default (MageModel's sand grains use it).
func set_ground_up(_up: Vector3) -> void:
	pass


## A character's lightning at `intensity` against the common [look]
## values (LightningLook); none by default.
func set_lightning(_intensity: float, _look: Dictionary) -> void:
	pass


## A lightning hit of this character's landed at `at` (world; ImpactLooks,
## on the hit spark every peer shows). Nothing by default (the Duelist's
## hit bolt).
func strike_hit(_at: Vector3) -> void:
	pass


## The kit `kit` (the player's own MoveKit: his character, boons, rage
## and fusion, MoveKit.for_player) and the common [look] values `look`:
## every input the model's move effects read. The one path that feeds them,
## in a run, in the capture scene and in the character select alike
## (PlayerAvatar calls it each frame). Nothing by default.
func read_kit(_kit: MoveKit, _look: Dictionary) -> void:
	pass


## The screen-shake kicks its moves' lab presets gave since the last take
## (VFX all-spells ticket 03; each {strength_m, length_s}, FxShakeKicks):
## the local player's camera takes them (ScreenShake.take_from). None by
## default.
func take_shake_kicks() -> Array:
	return []


## A pack's character's effects from its kit's state (MoveKit.KIT_STATE), each drawn
## frame. `view`: {move, move_frame, move_tick, position (his ground point), heading, facing,
## ground, to_world (ground points to the world), now_tick, tick_factor, actor, low, down,
## kit_ints (MoveKit.KIT_INTS as this peer sees them)}. Nothing by default.
func show_kit_state(_kit: MoveKit, _state: Dictionary, _view: Dictionary) -> void:
	pass


## True when its own drink clip shows the potion: the avatar's flask stays hidden.
func holds_own_potion() -> bool:
	return false


## Whether `move` plays its lab preset (FxMoves; its character's page names
## a saved one): its old effects (ImpactLooks' dust, shockwave and cracks)
## stay off. None by default.
func plays_move_fx(_move: String) -> bool:
	return false


## Checks: the effects this model's moves draw, for the shared run-world
## check (test_character_effects.gd): {name: {"presses": [press...],
## "effects": [effect id...]}}, each a string of presses played from a
## standing start (light, heavy, ultimate; "parry": the world's parried
## column moves on; "fuse": the gauge filled, then F) and the effects
## (effect_nodes ids) it must draw. None by default.
func move_effects() -> Dictionary:
	return {}


## Checks: each effect's drawn nodes, {effect id: [Node3D]}: a ribbon
## (a MeshInstance3D drawing an ImmediateMesh) or a pack effect.
func effect_nodes() -> Dictionary:
	return {}


## A see-through colour over the whole model, or none (Color(0, 0, 0, 0)).
func set_tint(_color: Color) -> void:
	pass


## The standard player glow (PlayerGlow, ruling Q33) round the model's edge
## in `color` at the [look] strength in `look` (a full gear set's), or none
## (a clear colour, Color(0, 0, 0, 0)). Nothing by default.
func set_glow(_color: Color, _look: Dictionary) -> void:
	pass


## How long `clip` lasts (s).
func clip_length(_clip: String) -> float:
	return 0.0
