## Reads and validates the tuning pages: one plain-text page per subject in
## the tuning/ folder at the repo root, each read with Godot's ConfigFile
## (`[section]` headers, `key = value` lines, `;` comments). Every value lives
## on exactly one page (page_of); the pages are merged into one set of values
## by section, e.g. values["move.light_1"]["hitstop_frames"], whichever page
## holds it. Any bad value yields an error naming the page and the key, never
## a silent default. The plain-words meaning of each key is in the comment
## above it on its page.
##
## All loading goes through load_folder (or parse, for text already read), so
## hot reload (TuningWatcher, TuningSchedule) reads through here too.
class_name Tuning
extends RefCounted

## Every page, by file name without ".cfg" (a zone's page sits in
## tuning/zones/; a character's own kit has its own page: the mage's,
## Kit.MAGE_PAGE, and Kit.PAGES). All must exist; a page whose subject has no
## values yet holds only comments.
const PAGES: Array[String] = ["character", "mage", "boons", "enemies", "camera-and-arena", "feel", "zones/zones",
	"zones/volcano", "zones/lava_ball", "duelist", GlobalMultipliers.PAGE, GearTiers.PAGE]
## The page every zone shares (the tuning screen's "Zones: all"; P-O
## 2026-11-05): the spawn sections each zone reads (Ground.ZONE_SHARED and
## ZONES_SECTIONS). A zone's own page overrides single keys of them in its
## copy (Ground.with_zone_copies).
const ZONES_PAGE := "zones/zones"
## The zones page's sections beside Ground.ZONE_SHARED: the boss focus and
## the super spawner's schedule and look, which no zone copies yet.
const ZONES_SECTIONS: Array[String] = [BossFocus.SECTION, SuperSpawner.SECTION, "spawner_look"]
## The volcano zone's page: the ring arena (RingArena).
const VOLCANO_PAGE := "zones/volcano"
## The lava ball's page (BallGround.keys).
const LAVA_BALL_PAGE := "zones/lava_ball"
## The water zone's page (docs/design/content-switch.md, "Tuning"): not one
## of PAGES, since the Demo has no such page and must still start. It is read
## and checked only while water is on (WaterRegistry.on), and only when it is
## there: its keys are the water zone's (WaterRegistry.tuning_keys), never
## named here.
const WATER_PAGE := "zones/water"
## The pistol shrimp's page, behind the same switch and just as optional. Its
## name starts `water` too, so the Demo's tuning copy drops it.
const WATER_SHRIMP_PAGE := "zones/water-shrimp"

## The page each section's keys live on, unless PAGE_OF_KEY says otherwise.
## Every enemy type's section (Enemies.TYPES) is on the enemies page.
static var PAGE_OF_SECTION := _page_of_section()


static func _page_of_section() -> Dictionary:
	var pages := {
		"player": "character",
		"combo": Kit.MAGE_PAGE,
		"dodge": "character",
		"blink": "character",
		"drink": "character",
		"potion": "character",
		"ultimate": Kit.MAGE_PAGE,
		"downed": "character",
		"camera": "camera-and-arena",
		"arena": "camera-and-arena",
		"look": "camera-and-arena",
		"zone_look": VOLCANO_PAGE,
		"ash_forest_look": VOLCANO_PAGE,
		"blob_look": "enemies",
		"worm_look": "enemies",
		"caster_look": "enemies",
		"fire_tiger_look": "enemies",
		"core_mother_look": "enemies",
		"boon_look": "boons",
		Boons.RULES_SECTION: "boons",
		"sound": "feel",
		"music": "feel",
		"trail": "feel",
		"callout": "feel",
		"run_bar": "feel",
		"enemy_bar": "feel",
		"boss_bar": "feel",
		"action_buttons": "feel",
		"impact": "feel",
		"shake": "feel",
		"damage_numbers": "feel",
		"death_screen": "feel",
		"lobby": "feel",
		"netcode": "feel",
	}
	for type: String in Enemies.TYPES:
		pages[Enemies.section_of(type)] = "enemies"
	for section: String in Enemies.SPELL_SECTIONS:
		pages[section] = "enemies"
	for section: String in EnemyStatus.KEYS:
		pages[section] = "enemies"
	for section: String in AttackSlots.KEYS:
		pages[section] = "enemies"
	for section: String in Tactics.KEYS:
		pages[section] = "enemies"
	for section: String in Boons.sections():
		pages[section] = "boons"
	for section: String in BossBoons.sections():
		pages[section] = "boons"
	for section: String in RingArena.KEYS:
		pages[section] = VOLCANO_PAGE
	for section: String in VolcanoZone.KEYS:
		pages[section] = VOLCANO_PAGE
	for section: String in SpawnGrid.keys():
		pages[section] = VOLCANO_PAGE
	for section: String in BallGround.keys():
		pages[section] = LAVA_BALL_PAGE
	for section: String in SuperSpawner.keys():
		pages[section] = VOLCANO_PAGE
	pages["danger_look"] = VOLCANO_PAGE
	pages.merge(ProgressMeter.page_of_section(VOLCANO_PAGE))
	# The sections every zone shares, on their own page (ZONES_PAGE): after
	# SuperSpawner's and ProgressMeter's, whose [spawner] and [progress] move here.
	for section: String in Ground.ZONE_SHARED + ZONES_SECTIONS:
		pages[section] = ZONES_PAGE
	pages[GlobalMultipliers.SECTION] = GlobalMultipliers.PAGE
	for section: String in GearTiers.keys():
		pages[section] = GearTiers.PAGE
	for section: String in VolcanoGear.keys():
		pages[section] = GearTiers.PAGE
	return pages


## Keys that live on another page than the rest of their section: how a hit
## feels on impact (the freeze and the shove) is on the feel page.
static var PAGE_OF_KEY := _page_of_key()

## The player's keys on the feel page: how far a hit taken shoves the player.
const PLAYER_FEEL_KEYS: Array[String] = ["flinch_slide_m", "flinch_slide_frames", "stagger_slide_m",
	"stagger_slide_frames"]


static func _page_of_key() -> Dictionary:
	var pages := {}
	for path: String in MAGE_LOOK:
		pages[path] = Kit.MAGE_PAGE
	for key: String in PLAYER_FEEL_KEYS:
		pages["player.%s" % key] = "feel"
	for type: String in Enemies.TYPES:
		for key: String in Enemies.FEEL_KEYS:
			if not Enemies.keys_of(type).has(key):
				continue
			pages["%s.%s" % [Enemies.section_of(type), key]] = "feel"
	return pages


## The Light group's move name (GLOSSARY "Light group"): [<id>.move.light]
## holds every light-swing value; [<id>.move.light_<n>] holds a swing's
## chaining values and its overrides (_resolve_light_groups).
const LIGHT_GROUP := "light"
## A swing row's keys that are its edges in the move graph: its next move per
## button, the one that follows on its own and the combo window. Per swing,
## never in a Light group.
const CHAINING_KEYS: Array[String] = ["next_light", "next_heavy", "next_auto", "combo_window_start_frame",
	"combo_window_end_frame"]

## Keys of every swing row (`[move.<name>]`, see Moves) that live on the feel
## page; the row's other keys are on the mage's page (Kit.MAGE_PAGE).
const FEEL_ROW_KEYS: Array[String] = ["hitstop_frames", "knockback_m"]

## key path -> rule, for the fixed sections. A rule is one of
##   ["number", min, max], ["whole number", min, max]
##   ["choice", options]: a word in quotes that must be one of the options
##   ["text"]: any words in quotes, not empty (a boon's display name, or its
##             effect line with {key} slots, checked by BoonText.check)
##   ["colour"]: a colour code in quotes, "#rrggbb" (an area telegraph's
##               or a bat lane's colour)
##   ["move name", "or none"]: a move's name in quotes (a swing row's, or a
##                             fixed move's such as "blink"), or "" for none
##   ["move name", "required"]: a move's name in quotes
##   ["preset", recipe]: the name of a saved preset of that recipe in quotes
##                       (FxPresets; the game resolves it, FxPresets.resolve),
##                       or "" for none (the move keeps its own effect)
## The swing rows' keys come from Moves.KINDS (see rule_of), the enemy
## sections' keys from the enemy-type table (Enemies).
static var SCHEMA := _schema()


## The mage's move presets (VFX all-spells; FxMoves pairs each with its
## move and recipe): each names the saved preset a move of his plays ("" for
## the move's own effect). They live on his page headed [mage.look] and read
## into the common [look] section, as the Duelist's [duelist.look] adds his
## dash_fx to it (Kit.tuning_of).
const MAGE_LOOK := {
	"look.ground_shake_fx": ["preset", "ground_shake"],
	# His light slashes' sand (ticket 01): "" keeps the staff's sand trail.
	"look.sand_slash_fx": ["preset", "sand_slash"],
	"look.whirlwind_fx": ["preset", "whirlwind"],
	# His tornado (ticket 04): "" keeps the old tornado look (TornadoLook).
	"look.tornado_fx": ["preset", "tornado"],
	# His blink's streak and arrival burst (ticket 05).
	"look.blink_fx": ["preset", "blink"],
	# His ultimate's time slow (ticket 06): "" keeps the old hourglass
	# (HourglassLook).
	"look.ultimate_fx": ["preset", "time_slow"],
	# His character boons' looks (gear-boons tickets 13-20; MageBoonLooks).
	"look.decoy_fx": ["preset", "blink"],
	"look.decoy_opacity": ["number", 0.0, 1.0],
	"look.landing_push_fx": ["preset", "ground_shake"],
	"look.sand_blind_fx": ["preset", "blink"],
	"look.ult_charge_fx": ["preset", "blink"],
	"look.reflect_fx": ["preset", "blink"],
	"look.twin_tornado_fx": ["preset", "tornado"],
	"look.sandglass_fx": ["preset", "ground_shake"],
}


static func _schema() -> Dictionary:
	var schema := BASE_SCHEMA.duplicate()
	schema.merge(Boons.schema())
	schema.merge(BossBoons.schema())
	schema.merge(MAGE_LOOK)
	for section: String in RingArena.KEYS:
		for key: String in RingArena.KEYS[section]:
			schema["%s.%s" % [section, key]] = RingArena.KEYS[section][key]
	for section: String in VolcanoZone.KEYS:
		for key: String in VolcanoZone.KEYS[section]:
			schema["%s.%s" % [section, key]] = VolcanoZone.KEYS[section][key]
	var ball := BallGround.keys()
	for section: String in ball:
		for key: String in ball[section]:
			schema["%s.%s" % [section, key]] = ball[section][key]
	var grid := SpawnGrid.keys()
	grid.merge(DangerClock.keys())
	grid.merge(ArrivalBatch.keys())
	grid.merge(AreaFatigue.keys())
	grid.merge(BossFocus.keys())
	grid.merge(SuperSpawner.keys())
	grid.merge(ProgressMeter.keys())
	grid.merge(GlobalMultipliers.keys())
	grid.merge(GearTiers.keys())
	grid.merge(VolcanoGear.keys())
	for section: String in grid:
		for key: String in grid[section]:
			schema["%s.%s" % [section, key]] = grid[section][key]
	for move: String in Moves.FIXED:
		var keys: Dictionary = Moves.KINDS[Moves.FIXED[move]]["keys"]
		for key: String in keys:
			schema["%s.%s" % [move, key]] = keys[key]
	# Every effect's keys of the ultimate slot; a slot needs only its own
	# effect's (parse).
	for effect: String in Moves.EFFECTS:
		if effect in Moves.SWITCHED_EFFECTS:
			continue
		for key: String in Moves.EFFECTS[effect]:
			schema["%s.%s" % [Moves.ULTIMATE_MOVE, key]] = Moves.EFFECTS[effect][key]
	# Every charge's keys likewise (a slot needs only its own charge's).
	for charge: String in Moves.CHARGE_KEYS:
		for key: String in Moves.CHARGE_KEYS[charge]:
			schema["%s.%s" % [Moves.ULTIMATE_MOVE, key]] = Moves.CHARGE_KEYS[charge][key]
	for type: String in Enemies.TYPES:
		var section: String = Enemies.section_of(type)
		var type_keys: Dictionary = Enemies.keys_of(type)
		for key: String in type_keys:
			schema["%s.%s" % [section, key]] = type_keys[key]
	for section: String in Enemies.SPELL_SECTIONS:
		for key: String in Enemies.SPELL_SECTIONS[section]:
			schema["%s.%s" % [section, key]] = Enemies.SPELL_SECTIONS[section][key]
	for section: String in EnemyStatus.KEYS:
		for key: String in EnemyStatus.KEYS[section]:
			schema["%s.%s" % [section, key]] = EnemyStatus.KEYS[section][key]
	for section: String in AttackSlots.KEYS:
		for key: String in AttackSlots.KEYS[section]:
			schema["%s.%s" % [section, key]] = AttackSlots.KEYS[section][key]
	for section: String in Tactics.KEYS:
		for key: String in Tactics.KEYS[section]:
			schema["%s.%s" % [section, key]] = Tactics.KEYS[section][key]
	return schema


const BASE_SCHEMA := {
	"combo.start_light": ["move name", "required"],
	"combo.start_heavy": ["move name", "required"],
	"combo.buffer_frames": ["whole number", 0, 600],
	# How fast every swing and the blink play (Moves.at_tempo; CombatSim).
	"combo.tempo": ["number", 0.25, 4.0],
	"camera.distance_m": ["number", 0.5, 100.0],
	"camera.height_m": ["number", 0.0, 100.0],
	"camera.mouse_deg_per_pixel": ["number", 0.001, 10.0],
	# The extra look-down on a curved ground (SurfaceCamera; flat ignores it).
	"camera.curved_pitch_deg": ["number", 0.0, 60.0],
	# The pull-in at a wall (SurfaceCamera.clear_share; P-O's walkthrough, 2026-11-05).
	"camera.wall_pull": ["whole number", 0, 1],
	"camera.wall_margin_m": ["number", 0.0, 5.0],
	"camera.wall_release_s": ["number", 0.0, 5.0],
	"player.move_speed_m_per_s": ["number", 0.0, 50.0],
	"player.max_hp": ["whole number", 1, 100000],
	"player.spawn_spacing_m": ["number", 0.0, 50.0],
	"player.flinch_frames": ["whole number", 1, 600],
	"player.stagger_frames": ["whole number", 1, 600],
	"player.flinch_slide_m": ["number", 0.0, 20.0],
	"player.flinch_slide_frames": ["whole number", 0, 600],
	"player.stagger_slide_m": ["number", 0.0, 20.0],
	"player.stagger_slide_frames": ["whole number", 0, 600],
	"player.cancel_resource_max": ["number", 1.0, 100000.0],
	"player.dodge_cost": ["number", 0.0, 100000.0],
	"player.paid_cancel_cost": ["number", 0.0, 100000.0],
	"player.cancel_resource_refill_per_s": ["number", 0.0, 100000.0],
	"player.cancel_resource_per_hit": ["number", 0.0, 100000.0],
	"downed.solo_lives": ["whole number", 1, 99],
	"downed.get_up_s": ["number", 0.0, 60.0],
	"downed.get_up_hp_percent": ["whole number", 1, 100],
	"downed.get_up_invulnerable_s": ["number", 0.0, 60.0],
	"downed.revive_range_m": ["number", 0.0, 50.0],
	"downed.revive_s": ["number", 0.0, 60.0],
	"downed.revive_hp_percent": ["whole number", 1, 100],
	"potion.stack_max": ["whole number", 0, 100],
	"potion.pickup_radius_m": ["number", 0.1, 20.0],
	"potion.floor_max": ["whole number", 1, 50],
	"potion.drop_reduction_percent_per_min": ["number", 0.0, 100.0],
	# How the mage is drawn (MageLook). Presentation only: the simulation never
	# reads them; his hit shapes are the move rows'.
	"look.mage_height_m": ["number", 0.5, 10.0],
	"look.mage_outline": ["number", 0.0, 1.0],
	"look.mage_lift": ["number", 0.0, 2.0],
	# How the enemies' models are drawn (EnemyModel): one dark outline for
	# every type and the glow lift of their own colours, as the mage's.
	# A lava blob's hit wobble (BlobLook.spring), every size tier: how stiff
	# the spring is, how fast it calms, what each hit adds, and the most it
	# swings (a share of its height). Presentation only.
	"blob_look.spring_k": ["number", 1.0, 2000.0],
	"blob_look.damping": ["number", 0.0, 100.0],
	"blob_look.impulse": ["number", 0.0, 20.0],
	"blob_look.max_wobble": ["number", 0.0, 0.9],
	# How the lava worm idles (WormLook.idle_motion, follow_step; P-O
	# 2026-10-29): its slow side sway and its breath (shares of its height,
	# and their periods), and the loose turn toward the nearest player while
	# it holds up between moves (its speed, and its limit off the sim's
	# facing). Its adds the same at their size. Presentation only.
	"worm_look.sway_share": ["number", 0.0, 0.5],
	"worm_look.sway_period_s": ["number", 0.5, 60.0],
	"worm_look.breath_share": ["number", 0.0, 0.5],
	"worm_look.breath_period_s": ["number", 0.5, 60.0],
	"worm_look.follow_deg_per_s": ["number", 0.0, 720.0],
	"worm_look.follow_max_deg": ["number", 0.0, 180.0],
	# The fire casters' attacks (enemy-vfx ticket 01; FxMoves.ENEMY): the
	# fireball the elemental and the skeleton mage throw, the flame strike
	# of the elemental's ground circle. "" keeps today's look.
	"caster_look.fireball_fx": ["preset", "fireball"],
	"caster_look.flame_strike_fx": ["preset", "flame_strike"],
	# The fire tiger's look (FireTigerLooks): its rigged model's scale (1: as
	# rigged, 2.8 m nose to tail, 1.17 m at the shoulder). Presentation only.
	"fire_tiger_look.model_scale": ["number", 0.1, 5.0],
	# Its flame mane and tail flame (new-enemies ticket 04; FxTigerFlames).
	# "" draws it without.
	"fire_tiger_look.flames_fx": ["preset", "tiger_flames"],
	# How the core mother is drawn (core-mother ticket 02; CoreMotherHeadModel,
	# CoreMotherLegModel): her sizes (rulings 1-2), the glow, the leg's seam
	# floor and the red glow steps. Presentation only.
	"core_mother_look.head_width_m": ["number", 0.5, 30.0],
	"core_mother_look.head_sunk_share": ["number", 0.0, 0.9],
	"core_mother_look.leg_height_m": ["number", 0.5, 30.0],
	"core_mother_look.leg_sunk_m": ["number", 0.0, 10.0],
	"core_mother_look.head_glow": ["number", 0.0, 10.0],
	"core_mother_look.leg_glow": ["number", 0.0, 10.0],
	"core_mother_look.leg_seam_floor": ["number", 0.0, 0.9],
	"core_mother_look.red_step_share": ["number", 0.0, 1.0],
	# Her head's lift as it bites, and her boss volcanoes (ticket 04).
	"core_mother_look.head_bite_lift_m": ["number", 0.0, 5.0],
	"core_mother_look.volcano_height_m": ["number", 0.1, 10.0],
	"core_mother_look.volcano_glow": ["number", 0.0, 10.0],
	# Her spinning X's burning beams (ticket 05).
	"core_mother_look.x_beam_height_m": ["number", 0.0, 10.0],
	"core_mother_look.x_glow": ["number", 0.0, 10.0],
	# Her debris as a part bursts up, the lava dripping from her head
	# (ticket 06).
	"core_mother_look.debris_amount": ["number", 0.0, 64.0],
	"core_mother_look.drip_amount": ["number", 0.0, 64.0],
	# The polish pass (P-O 2026-10-29, step 12a; core_mother.gdshader): wide
	# hot flowing cracks, warm rock, her forehead core and eyes the hottest
	# points, a bigger brighter drip, a short warm hit flash.
	"core_mother_look.crack_spread": ["number", 0.0, 8.0],
	"core_mother_look.crack_flow": ["number", 0.0, 1.0],
	"core_mother_look.crack_flow_speed": ["number", 0.0, 2.0],
	"core_mother_look.crack_pulse": ["number", 0.0, 1.0],
	"core_mother_look.crack_pulse_s": ["number", 0.2, 10.0],
	"core_mother_look.rock_warmth": ["number", 0.0, 1.0],
	"core_mother_look.rock_edge_light": ["number", 0.0, 2.0],
	"core_mother_look.rock_scorch": ["number", 0.0, 1.0],
	"core_mother_look.core_glow": ["number", 0.0, 10.0],
	"core_mother_look.eye_glow": ["number", 0.0, 10.0],
	"core_mother_look.drip_size_m": ["number", 0.05, 2.0],
	"core_mother_look.drip_glow": ["number", 0.0, 10.0],
	"core_mother_look.flash_s": ["number", 0.02, 1.0],
	"core_mother_look.flash_glow": ["number", 0.0, 5.0],
	# Her spinning X's beams as flame jets (step 12b; FxFlameJet). "" keeps
	# the old glowing strip and wall of fire.
	"core_mother_look.x_fx": ["preset", "flame_jet"],
	# The boons' effect looks (playtest 2026-10-25 #3; FxMoves.BOON): the
	# Fire bomb's explosion. "" keeps today's look.
	"boon_look.fire_bomb_fx": ["preset", "fire_bomb"],
	# The Throwing knives boon's knife (the light vs heavy pass, 2026-10-28).
	# "" draws its recipe's default.
	"boon_look.throwing_knife_fx": ["preset", "throwing_knife"],
	"look.enemy_outline": ["number", 0.0, 1.0],
	"look.enemy_lift": ["number", 0.0, 2.0],
	# The outline's width on screen for everyone, and the ring marking each
	# player at its feet (PlayerAvatar), in its player colour.
	"look.outline_width_px": ["number", 0.0, 20.0],
	"look.marker_opacity": ["number", 0.0, 1.0],
	"look.marker_ring_width_m": ["number", 0.0, 0.5],
	# The standard player glow (PlayerGlow, ruling Q33): one faint outer-edge
	# glow on every player-owned glow, capped under the enemies' danger glow.
	"look.player_glow_strength": ["number", 0.0, 1.0],
	# How long the drawn mage takes to turn to his facing (MageLook.turn_toward;
	# 0 snaps). Presentation only: his facing and hit shapes turn at once.
	"look.turn_smoothing_s": ["number", 0.0, 1.0],
	# The tornado's sand (its preset, FxTornado, or TornadoLook): sized by
	# its radius_m, never taller than this. Presentation only.
	"look.tornado_height_m": ["number", 0.0, 10.0],
	# The ultimate's hourglass (HourglassLook): its height as a share of the
	# mage's, how long it takes to shatter as the slow begins, and the faint
	# marker over a caster for the rest of his slow (your own, the others').
	# Presentation only.
	"look.hourglass_size": ["number", 0.5, 4.0],
	"look.hourglass_shatter_s": ["number", 0.0, 3.0],
	"look.hourglass_marker_own": ["number", 0.0, 1.0],
	"look.hourglass_marker_other": ["number", 0.0, 1.0],
	# The stars circling a stunned enemy's head (StunStars), one neutral
	# colour for every source. Presentation only.
	"look.stun_star_color": ["colour"],
	"look.stun_star_size_m": ["number", 0.0, 1.0],
	# The portal icon on a curved surface (PortalIcon): the colour of its ring
	# and tip, its size and how high over the portal its marker floats; and
	# how far in from the screen's edge the edge arrows sit, the portal's and
	# the teammates' (TeammateArrows), on one edge; the teammate arrows' size,
	# the arrow-to-marker glide, the room between arrows on the edge and the
	# swap's two holds. Presentation only.
	"look.portal_icon_color": ["colour"],
	"look.portal_icon_size_px": ["number", 4.0, 64.0],
	"look.edge_arrow_inset_px": ["number", 0.0, 200.0],
	"look.portal_icon_raise_m": ["number", 0.0, 10.0],
	"look.teammate_arrow_size_px": ["number", 4.0, 64.0],
	"look.portal_icon_glide_s": ["number", 0.0, 2.0],
	"look.edge_arrow_gap_px": ["number", 0.0, 100.0],
	"look.portal_icon_hold_px": ["number", 0.0, 100.0],
	"look.portal_icon_hold_m": ["number", 0.0, 10.0],
	# Every shot's height over the ground (ShotPath; P-O 2026-10-29), the
	# players' and the enemies', out along the up wherever it flies (the
	# lava ball, the climb). Presentation only: the hits are the sim's.
	"look.shot_height_m": ["number", 0.0, 5.0],
	# The launch shader warm-up (WarmUpList.done, shader-loading ticket 01):
	# done after this many frames with no new pipeline compilation, or at the
	# cap. Presentation only.
	"look.warm_up_quiet_frames": ["number", 1.0, 120.0],
	"look.warm_up_cap_s": ["number", 1.0, 120.0],
	# The loading screen over it (LoadingScreen, ticket 02): shown only past this
	# long a wait. Presentation only.
	"look.warm_up_screen_after_s": ["number", 0.0, 15.0],
	"look.warm_up_bar_half_compilations": ["number", 1.0, 5000.0],
	# The longest a co-op run's start waits on the slowest player (RunStartGate,
	# ticket 04). Presentation only: it holds no tick of the simulation.
	"look.warm_up_coop_cap_s": ["number", 1.0, 600.0],
	# The enemies' ground telegraphs (Telegraphs, playtest ruling 5): the
	# border at the attack's exact hit edge and the pale fill growing as the
	# countdown runs. Presentation only: the radius and the countdown are the
	# enemies page's.
	"look.telegraph_border_width_m": ["number", 0.0, 1.0],
	"look.telegraph_border_opacity": ["number", 0.0, 1.0],
	"look.telegraph_fill_opacity": ["number", 0.0, 1.0],
	"look.telegraph_color": ["colour"],
	# How the volcano's ring arena is drawn (RingArenaView, ZoneLooks, RingFx;
	# zone SOP 6b-6d), on the volcano page. Presentation only: the simulation
	# never reads them.
	"zone_look.pit_brightness": ["number", 0.0, 10.0],
	"zone_look.outer_lava_brightness": ["number", 0.0, 10.0],
	"zone_look.lava_flow_m_per_s": ["number", 0.0, 10.0],
	"zone_look.lava_light_energy": ["number", 0.0, 10.0],
	"zone_look.floor_crack_glow": ["number", 0.0, 5.0],
	"zone_look.rock_outline": ["number", 0.0, 1.0],
	"zone_look.lavafall_opacity": ["number", 0.0, 1.0],
	"zone_look.lavafall_height_m": ["number", 0.0, 10.0],
	"zone_look.vent_eruption_size": ["number", 0.0, 5.0],
	"zone_look.spurt_every_s": ["number", 0.1, 60.0],
	"zone_look.embers": ["whole number", 0, 2000],
	"zone_look.heat_shimmer": ["number", 0.0, 0.05],
	# The volcano's slope dressing (VolcanoZoneView.outcrops, the slope's cracks;
	# playtest 2026-10-25 #2).
	"zone_look.slope_outcrops": ["whole number", 0, 400],
	"zone_look.slope_crack_glow": ["number", 0.0, 2.0],
	# How the ash forest is drawn (AshForestView): its haze and ash waves.
	# Looks only: no effect on aim, enemy sight or aggro.
	"ash_forest_look.haze": ["number", 0.0, 1.0],
	"ash_forest_look.wave_haze": ["number", 0.0, 1.0],
	"ash_forest_look.wave_every_s": ["number", 1.0, 3600.0],
	"ash_forest_look.wave_s": ["number", 0.5, 600.0],
	"ash_forest_look.ember_glow": ["number", 0.0, 10.0],
	"ash_forest_look.tree_height_m": ["number", 0.5, 30.0],
	# How the zone's super spawner is drawn (SuperSpawnerLooks; spawn-pressure
	# ticket 05): its swirl's preset (FxSpawnerSwirl), the colour re-skinning
	# it, and the rock material of its ring. Looks only.
	"spawner_look.swirl_fx": ["preset", "spawner_swirl"],
	"spawner_look.swirl_colour": ["colour"],
	"spawner_look.rock_material": ["choice", ["volcano rock"]],
	"spawner_look.column_height_m": ["number", 0.0, 200.0],
	"spawner_look.column_width_m": ["number", 0.0, 50.0],
	"spawner_look.column_low_share": ["number", 0.0, 1.0],
	"spawner_look.column_opacity": ["number", 0.0, 1.0],
	# How loud each kind of sound plays (decibels added to master_db; -80 is
	# silent) and how far each play's pitch wanders. Presentation only: the
	# simulation never reads them (SoundMix, ticket 19).
	"sound.master_db": ["number", -80.0, 12.0],
	"sound.swing_db": ["number", -80.0, 12.0],
	"sound.impact_db": ["number", -80.0, 12.0],
	"sound.hurt_db": ["number", -80.0, 12.0],
	"sound.movement_db": ["number", -80.0, 12.0],
	"sound.enemy_db": ["number", -80.0, 12.0],
	"sound.stinger_db": ["number", -80.0, 12.0],
	"sound.callout_db": ["number", -80.0, 12.0],
	"sound.ultimate_db": ["number", -80.0, 12.0],
	"sound.parry_db": ["number", -80.0, 12.0],
	"sound.teammate_db": ["number", -80.0, 12.0],
	"sound.pitch_variation_percent": ["number", 0.0, 50.0],
	# Impacts (sound spec "Impacts"): a level per weight on top of impact_db,
	# the extra targets' layers, boon damage's offset, and the variation.
	"sound.impact_light_db": ["number", -80.0, 12.0],
	"sound.impact_medium_db": ["number", -80.0, 12.0],
	"sound.impact_heavy_db": ["number", -80.0, 12.0],
	"sound.impact_extra_layer_db": ["number", -80.0, 0.0],
	"sound.boon_impact_db": ["number", -80.0, 12.0],
	"sound.impact_pitch_variation_percent": ["number", 0.0, 50.0],
	"sound.impact_volume_variation_db": ["number", 0.0, 12.0],
	# Hit timing (docs/audio/hit-timing.md): how much of a hit take's lead-in
	# before its hit point still plays (SoundMix.plan from_s).
	"sound.impact_lead_ms": ["number", 0.0, 100.0],
	# The hit's layers (docs/audio/hit-sound-guide.md): the thump under an
	# impact (its level, an ender's extra, how long it trails the crack: its
	# takes open on 50 ms of silence), the Kenney takes' gain, the whole hit's
	# random pitch, how many impacts at once (0: no cap), and getting hit's
	# muffle and thump.
	"sound.impact_thump_db": ["number", -80.0, 12.0],
	"sound.impact_thump_ender_db": ["number", -80.0, 12.0],
	"sound.impact_thump_delay_ms": ["number", 0.0, 45.0],
	"sound.impact_kenney_db": ["number", -80.0, 0.0],
	"sound.hit_pitch_semitones": ["number", 0.0, 12.0],
	"sound.impact_max_voices": ["whole number", 0, 32],
	"sound.hurt_lowpass_hz": ["number", 200.0, 20000.0],
	"sound.hurt_thump_db": ["number", -80.0, 12.0],
	"sound.hurt_thump_delay_ms": ["number", 0.0, 45.0],
	# P-O's reference hits (SoundCues.impact_cue): each switch 0 (off) or 1,
	# their level and how much of their lead-in plays on a light strike.
	"sound.mage_light_sand_slash": ["whole number", 0, 1],
	"sound.duelist_light_lightning": ["whole number", 0, 1],
	"sound.duelist_slam_lightning": ["whole number", 0, 1],
	"sound.reference_db": ["number", -80.0, 12.0],
	"sound.reference_lead_ms": ["number", 0.0, 300.0],
	# Swings (sound ticket 02): how far a whoosh's pitch and level wander.
	"sound.swing_pitch_variation_percent": ["number", 0.0, 50.0],
	"sound.swing_volume_variation_db": ["number", 0.0, 12.0],
	# Enemy sounds (sound ticket 08): how far they wander, and the bats'
	# own level and the cooldown every bat shares (SoundGate.allow_cue).
	"sound.enemy_pitch_variation_percent": ["number", 0.0, 50.0],
	"sound.enemy_volume_variation_db": ["number", 0.0, 12.0],
	"sound.bat_db": ["number", -80.0, 12.0],
	"sound.bat_cooldown_s": ["number", 0.0, 10.0],
	# The music tiers' tempos (MusicTempo, sound ticket 03): every track of a
	# tier plays at its tier's tempo, its pitch held. Presentation only.
	"music.green_bpm": ["number", 60.0, 200.0],
	"music.yellow_bpm": ["number", 60.0, 200.0],
	"music.red_bpm": ["number", 60.0, 200.0],
	"music.black_bpm": ["number", 60.0, 200.0],
	# The music director's crossfade on a tier change, in bars of the new
	# tier's tempo, and the menus' music level (MusicDirector, ticket 04).
	"music.crossfade_bars": ["number", 0.0, 8.0],
	"music.menu_db": ["number", -40.0, 0.0],
	# Tempo creep (MusicDirector, ticket 05): the cap as a fraction of the
	# tier's tempo at a full meter, and the ease back once a marker is crossed,
	# in bars. In-tier rotation: loops of a track before the next (0 never).
	"music.creep_cap": ["number", 0.0, 0.2],
	"music.creep_ease_bars": ["number", 0.0, 32.0],
	"music.rotate_loops": ["number", 0.0, 16.0],
	# The boss layer's level and each tier's pattern (BossLayer, BossPatterns:
	# its NAMES, kept the same here; ticket 06).
	"music.boss_db": ["number", -40.0, 12.0],
	# The music's offset under the combat sounds (MusicPlayer, sound ticket 07's
	# mix pass): every deck and the boss layer, on the Music bus.
	"music.music_db": ["number", -60.0, 12.0],
	"music.boss_pattern_green": ["choice", ["march", "drive", "gallop", "storm", "taiko_loops"]],
	"music.boss_pattern_yellow": ["choice", ["march", "drive", "gallop", "storm", "taiko_loops"]],
	"music.boss_pattern_red": ["choice", ["march", "drive", "gallop", "storm", "taiko_loops"]],
	"music.boss_pattern_black": ["choice", ["march", "drive", "gallop", "storm", "taiko_loops"]],
	# The sand trail behind the staff head during a swing (MageModel,
	# StaffTrail). Presentation only: the simulation never reads them.
	"trail.light_width_m": ["number", 0.0, 5.0],
	"trail.heavy_width_m": ["number", 0.0, 5.0],
	"trail.fade_s": ["number", 0.01, 2.0],
	"trail.heavy_fade_s": ["number", 0.01, 2.0],
	"trail.glow": ["number", 0.0, 4.0],
	"trail.lead_frames": ["whole number", 0, 60],
	"trail.opacity": ["number", 0.0, 1.0],
	"trail.grain_count": ["whole number", 0, 64],
	"trail.grain_size_m": ["number", 0.0, 0.5],
	"trail.grain_life_s": ["number", 0.05, 3.0],
	# How long the boon callouts stay up, and the boon bar's glyph size
	# (BoonCallouts). Presentation only: the simulation never reads them.
	"callout.slam_s": ["number", 0.0, 10.0],
	"callout.slam_fade_s": ["number", 0.0, 10.0],
	"callout.feed_s": ["number", 0.0, 30.0],
	"callout.own_flash_s": ["number", 0.0, 10.0],
	"callout.team_flash_s": ["number", 0.0, 10.0],
	"callout.heal_flash_s": ["number", 0.0, 10.0],
	"callout.pick_s": ["number", 0.0, 10.0],
	"callout.pick_fade_s": ["number", 0.0, 10.0],
	"callout.spawner_banner_s": ["number", 0.0, 30.0],
	"callout.spawner_banner_fade_s": ["number", 0.0, 10.0],
	"callout.bar_glyph_px": ["number", 8.0, 256.0],
	# The run bar at the top of the screen (RunBar, progression ticket 06):
	# how many points of the progress meter it shows, where the now line
	# sits, and its four danger colours. Presentation only.
	"run_bar.window_points": ["number", 10.0, 10000.0],
	"run_bar.now_at": ["number", 0.0, 1.0],
	"run_bar.green": ["colour"],
	"run_bar.yellow": ["colour"],
	"run_bar.red": ["colour"],
	"run_bar.black": ["colour"],
	# The small enemy health bars (EnemyBars, playtest-fixes ticket 07): how
	# long a bar holds after the last hit, its fade tail, its size and how
	# high over the enemy. Presentation only.
	"enemy_bar.hold_s": ["number", 0.0, 30.0],
	"enemy_bar.tail_s": ["number", 0.0, 5.0],
	"enemy_bar.width_m": ["number", 0.1, 5.0],
	"enemy_bar.height_m": ["number", 0.02, 1.0],
	"enemy_bar.above_m": ["number", 0.0, 5.0],
	# The boss bars on the right edge of the screen (BossBars, playtest-fixes
	# ticket 08): where they sit and their size in the HUD layout's pixels,
	# the gap between two side by side, and the name's font size.
	# Presentation only.
	"boss_bar.right_px": ["number", 0.0, 500.0],
	"boss_bar.top_px": ["number", 0.0, 600.0],
	"boss_bar.length_px": ["number", 40.0, 600.0],
	"boss_bar.thickness_px": ["number", 4.0, 60.0],
	"boss_bar.gap_px": ["number", 0.0, 60.0],
	"boss_bar.font_size": ["number", 8.0, 48.0],
	"action_buttons.size_px": ["number", 24.0, 128.0],
	"action_buttons.gap_px": ["number", 0.0, 60.0],
	"action_buttons.bottom_px": ["number", 0.0, 300.0],
	"action_buttons.key_font_size": ["number", 8.0, 32.0],
	"action_buttons.count_font_size": ["number", 8.0, 32.0],
	# The dire zone (DireLook, progression ticket 08): the zone's lighting
	# at black on the danger clock, blended from red. Presentation only.
	"danger_look.dim_at_black": ["number", 0.0, 1.0],
	"danger_look.tint_at_black": ["colour"],
	"danger_look.lava_glow_at_black": ["number", 1.0, 5.0],
	# The player's impact reactions (ImpactLooks, playtest ruling 5): hit
	# sparks per tier, the whirlwinds' and the ground-shake's dust and
	# shockwave, the ground-shake's cracks. Look sizes, deliberately not the
	# hit area (reach_m). Presentation only.
	"impact.chip_spark_scale": ["number", 0.0, 10.0],
	"impact.flinch_spark_scale": ["number", 0.0, 10.0],
	"impact.stagger_spark_scale": ["number", 0.0, 10.0],
	"impact.dust_radius_m": ["number", 0.0, 20.0],
	"impact.shockwave_radius_m": ["number", 0.0, 20.0],
	"impact.shockwave_s": ["number", 0.05, 5.0],
	"impact.crack_radius_m": ["number", 0.0, 20.0],
	"impact.crack_fade_s": ["number", 0.05, 10.0],
	# The camera shake on heavy moments (ScreenShake, front-end ticket 03).
	# Presentation only: the simulation never reads them.
	"shake.strength_m": ["number", 0.0, 1.0],
	"shake.length_s": ["number", 0.0, 2.0],
	"shake.near_m": ["number", 0.0, 100.0],
	# The damage numbers over enemies you hit (DamageNumbers, front-end ticket
	# 05). Presentation only: the simulation never reads them.
	"damage_numbers.window_s": ["number", 0.0, 2.0],
	"damage_numbers.size_m": ["number", 0.05, 3.0],
	"damage_numbers.rise_m": ["number", 0.0, 5.0],
	"damage_numbers.rise_s": ["number", 0.1, 5.0],
	"death_screen.freeze_s": ["number", 0.0, 5.0],
	"death_screen.drain_s": ["number", 0.0, 30.0],
	"death_screen.text_fade_s": ["number", 0.0, 10.0],
	"death_screen.input_guard_s": ["number", 0.0, 2.0],
	"death_screen.title_px": ["number", 24.0, 400.0],
	"death_screen.title_spacing_px": ["number", 0.0, 100.0],
	"death_screen.title_slam_s": ["number", 0.0, 2.0],
	"death_screen.title_slam_scale": ["number", 0.0, 8.0],
	"death_screen.title_jolt_px": ["number", 0.0, 100.0],
	"death_screen.title_jolt_s": ["number", 0.0, 3.0],
	"death_screen.title_creep": ["number", 0.0, 1.0],
	"death_screen.title_creep_s": ["number", 0.0, 600.0],
	"death_screen.vignette": ["number", 0.0, 1.0],
	"death_screen.music_fall_s": ["number", 0.0, 30.0],
	"death_screen.music_fall_pitch": ["number", 0.01, 1.0],
	"death_screen.hit_db": ["number", -80.0, 24.0],
	# The co-op lobby's countdown after the host's Start (front-end ticket 08).
	"lobby.countdown_s": ["number", 0.0, 60.0],
	"netcode.hit_grace_ticks": ["whole number", 0, 30],
}


class Result:
	extends RefCounted
	## Empty when every page is valid.
	var error: String = ""
	## Nested sections, e.g. values["player"]["move_speed_m_per_s"].
	var values: Dictionary = {}


## Keys a section may leave out, with their rule: the ultimate slot's
## `effect` (absent: Moves.EFFECT_SLOW, the mage's), [combo] `light_tempo`
## (absent: 1.0), [combo] `heavy_area_percent` (absent: 100), [boon_rules]
## `light_attack_speed_cap_percent` (absent: no cap). A row's `kind` is
## optional too (Moves.row_rule).
static var OPTIONAL := {"%s.%s" % [Moves.ULTIMATE_MOVE, Moves.EFFECT_KEY]: ["choice", Moves.EFFECTS.keys()],
	# The light swings' own speed-up on top of the tempo (Moves.at_tempo; absent 1.0).
	"combo.light_tempo": ["number", 0.25, 4.0],
	# A light or heavy held down chains as each combo window opens (CombatSim._chain;
	# absent 0: the shrimp's hold charges his shots instead; P-O's walkthrough 2026-11-05).
	"combo.hold_chains": ["whole number", 0, 1],
	# A light or heavy pressed this soon after a swing ends chains from it (CombatSim
	# _chain_memory; absent 0: none; P-O's walkthrough 2026-11-05).
	"combo.memory_s": ["number", 0.0, 2.0],
	# The heavy attacks' and enders' hit size, a percent of the page's
	# (Moves.at_heavy_area; absent 100; P-O's light vs heavy pass 2026-10-28).
	"combo.heavy_area_percent": ["number", 10.0, 300.0],
	# The cap on the light attack + ender's total attack speed bonus
	# (Boons.tuned; absent: no cap; P-O's light vs heavy pass 2026-10-28).
	"%s.%s" % [Boons.RULES_SECTION, Boons.LIGHT_SPEED_CAP]: ["number", 0.0, 1000.0],
	# Gear tier 1's kills (GearTiers.needs_of; absent: tier n needs n x the per-tier numbers).
	"gear_tiers.first_tier_kills": ["whole number", 0, 100000]}

## Keys only a character's own kit has (Kit), by their section without the
## prefix: a kit whose page holds any section must give them, the mage never
## does. [duelist.look] lightning_intensity: one brightness for all his
## lightning, always under the danger telegraphs (LightningLook).
## [duelist.look] dash_fx: his dash streak's preset (the VFX lab's, by
## name; "" for today's streak; DuelistModel.set_dash_fx).
## [duelist.look] light_fx: his light strikes' preset (VFX all-spells ticket
## 07: the light strike's, by name; "" for today's blade arcs;
## DuelistModel.set_light_fx).
## [duelist.look] heavy_spin_fx: his heavy spin's preset (VFX all-spells
## ticket 08: the heavy spin's, by name; "" for today's blade arcs;
## DuelistModel.set_heavy_spin_fx).
## [duelist.look] slam_fx: his jump-slam's preset (VFX all-spells ticket
## 09: the lightning ring's, by name; "" for today's thunderclap;
## DuelistModel.set_slam_fx).
## [duelist.look] throw_fx: his blade throw's preset (VFX all-spells ticket
## 10: the blade throw's, by name; "" for today's tethers;
## DuelistModel.set_throw_fx).
## [duelist.look] parry_fx: his parry's preset (VFX all-spells ticket 11:
## the parry's, by name; "" for today's flash and forks;
## DuelistModel.set_parry_fx).
## [duelist.look] roll_fx: his log roll's preset (VFX all-spells ticket 12:
## the roll's, by name; "" for today's wheel and floor bursts;
## DuelistModel.set_roll_fx).
## [duelist.look] fusion_fx: his fusion's preset (VFX all-spells ticket 13:
## the fusion's, by name; "" for today's bolt and flash;
## DuelistModel.set_fusion_fx).
## [duelist.parry] (ticket 09): his passive front parry (CombatSim's Parry):
## the chance by the hit's tier (chip, medium = flinch, heavy = stagger),
## the front cone either side of his facing, the attacker's shove.
## They are the Duelist's alone (kit_only_of).
const KIT_ONLY_CHARACTER := "duelist"
const KIT_ONLY := {
	"look.lightning_intensity": ["number", 0.0, 1.0],
	"look.dash_fx": ["preset", "lightning_line"],
	"look.light_fx": ["preset", "light_strike"],
	"look.heavy_spin_fx": ["preset", "heavy_spin"],
	"look.slam_fx": ["preset", "lightning_ring"],
	"look.throw_fx": ["preset", "blade_throw"],
	"look.parry_fx": ["preset", "parry"],
	"look.roll_fx": ["preset", "roll"],
	"look.fusion_fx": ["preset", "fusion"],
	"parry.chip_chance_percent": ["number", 0.0, 100.0],
	"parry.medium_chance_percent": ["number", 0.0, 100.0],
	"parry.heavy_chance_percent": ["number", 0.0, 100.0],
	"parry.front_half_angle_deg": ["number", 0.0, 180.0],
	"parry.attacker_shove_m": ["number", 0.0, 5.0],
}


## The page `section`'s `key` lives on. A character's own section
## ([duelist.move.light_1], Kit) lives on its page whatever the key, the
## feel keys included: one page per character. The mage's rows, [combo] and
## [ultimate] live on his page (Kit.MAGE_PAGE), his rows' feel keys on the
## feel page; his page's header for a section ([mage.combo]) is placed as
## the section.
static func page_of(section: String, key: String) -> String:
	if Kit.is_mage_header(section):
		return page_of(Kit.from_header(section), key)
	var character := Kit.character_of(section)
	if character != "":
		return Kit.PAGES[character]
	if Moves.is_row(section):
		return "feel" if key in FEEL_ROW_KEYS else Kit.MAGE_PAGE
	var home: String = PAGE_OF_KEY.get("%s.%s" % [section, key], PAGE_OF_SECTION.get(section, ""))
	if home == "" and WaterRegistry.tuning_keys().has(section):
		return WATER_PAGE
	# A pack's character boon: its row is on its character's page.
	var boon_of := CharacterPacks.of_boon_section(section) if home == "" else null
	return Kit.PAGES.get(boon_of.id(), home) if boon_of else home


## True when `section`'s `key` overrides a zones page key: a zone copy's
## (Ground.shared_of: `[spawning.water] ramp_cap`), optional on its page. A
## key only the zone has (`no_spawn_radius_m`) is none.
static func is_zone_override(section: String, key: String) -> bool:
	var shared := Ground.shared_of(section)
	return shared != "" and SCHEMA.has("%s.%s" % [shared, key])


## The rule (see SCHEMA) for `section`'s `key`, or [] if it is no tuning
## value. A character's own section has the rules of the same section
## without its prefix (Kit.strip).
static func rule_of(section: String, key: String) -> Array:
	var own_section := section
	section = Kit.strip(section)
	if Moves.is_row(section):
		# A swing row's or a channel row's (Moves.row_rule); parse checks each
		# row has only its own kind's keys.
		return Moves.row_rule(key)
	var path := "%s.%s" % [section, key]
	var character := Kit.character_of(own_section)
	if character != "" and kit_only_of(character).has(path):
		return kit_only_of(character)[path]
	if character != "" and CharacterPacks.optional_keys(character).has(path):
		return CharacterPacks.optional_keys(character)[path]
	if SCHEMA.has(path):
		return SCHEMA[path]
	if OPTIONAL.has(path):
		return OPTIONAL[path]
	if section == Moves.ULTIMATE_MOVE and _effect_of_key(key) in Moves.SWITCHED_EFFECTS:
		return Moves.EFFECTS[_effect_of_key(key)][key]
	if CharacterPacks.of_boon_section(section):
		var boon := section.trim_prefix("boon.")
		return Boons.keys_of(boon).get(key, Boons.COMMON_KEYS.get(key, []))
	return WaterRegistry.tuning_keys().get(section, {}).get(key, [])


## The keys `character`'s page holds beside every kit's: the Duelist's KIT_ONLY,
## another's from his pack (CharacterPacks.kit_keys).
static func kit_only_of(character: String) -> Dictionary:
	return KIT_ONLY if character == KIT_ONLY_CHARACTER else CharacterPacks.kit_keys(character)


## The folder the game reads its pages from: the live tuning folder
## (live_path) unless use_folder pointed it elsewhere. The test runner points
## it at the tests' frozen copy (FrozenTuning), so P-O's live tuning never
## reaches a test.
static func default_path() -> String:
	return _folder if _folder != "" else live_path()


## The live tuning folder, located relative to the Godot project:
## <repo>/tuning. P-O edits it from the tuning screen. An exported build
## reads the `tuning` folder beside its exe (tools/export_windows.ps1).
static func live_path() -> String:
	return live_folder(OS.has_feature("template"), OS.get_executable_path(), ProjectSettings.globalize_path("res://"))


## live_path's rule: beside `exe` when `exported`, else <project>/../tuning.
static func live_folder(exported: bool, exe: String, project: String) -> String:
	if exported:
		return exe.get_base_dir().path_join("tuning")
	return project.path_join("../tuning").simplify_path()


## Points default_path at `folder` for the rest of the run ("" for the live
## folder again).
static func use_folder(folder: String) -> void:
	_folder = folder


static var _folder := ""


## Reads every page from `folder` and validates them together.
static func load_folder(folder: String) -> Result:
	var result := parse(read_pages(folder))
	if result.error != "":
		result.error = "In the tuning folder %s:\n%s" % [folder, result.error]
	return result


## Every page this build reads: PAGES, then the water pages while water is
## on (WATER_PAGE, WATER_SHRIMP_PAGE).
static func page_names() -> Array[String]:
	var out := PAGES.duplicate()
	if WaterRegistry.on():
		out.append(WATER_PAGE)
		out.append(WATER_SHRIMP_PAGE)
	return out


## The text of every page found in `folder` (page name -> text, page_names);
## a missing page is left out, and parse names it (the water pages may be
## missing).
static func read_pages(folder: String) -> Dictionary:
	var pages := {}
	for page in page_names():
		var path := folder.path_join(page + ".cfg")
		if FileAccess.file_exists(path):
			pages[page] = FileAccess.get_file_as_string(path)
	return pages


## Validates `pages` (page name -> page text) and merges their values.
static func parse(pages: Dictionary) -> Result:
	var result := Result.new()
	var files := {}
	# The packs first: asked in the middle of the water entry's own load (the
	# scripts it pulls in read FxMoves' table as they start), they would stay empty
	# and his page would read as stray keys.
	CharacterPacks.packs()
	# The pages read: every one of PAGES, and each water page when it is given
	# while water is on (a demo ignores them).
	var read := PAGES.duplicate()
	if WaterRegistry.on():
		for page: String in [WATER_PAGE, WATER_SHRIMP_PAGE]:
			if pages.has(page):
				read.append(page)
	for page in read:
		if not pages.has(page):
			result.error = "%s.cfg is missing (every tuning page must exist, even one with only comments)" % page
			return result
		var syntax := _check_syntax(pages[page])
		if syntax != "":
			result.error = "%s.cfg: %s" % [page, syntax]
			return result
		var file := ConfigFile.new()
		if file.parse(pages[page]) != OK:
			result.error = "%s.cfg could not be read" % page
			return result
		if page == Kit.MAGE_PAGE:
			# His page's [mage.<section>] headers read as the sections his kit
			# plays (Kit.from_header).
			var own := ConfigFile.new()
			for header: String in file.get_sections():
				if not Kit.is_mage_header(header):
					result.error = "%s.cfg: [%s] must be headed [%s.%s]: every section on this page is the mage's" % [
						page, header, Kit.MAGE_PAGE, header]
					return result
				for key: String in file.get_section_keys(header):
					own.set_value(Kit.from_header(header), key, file.get_value(header, key))
			file = own
		files[page] = file
	# Each light swing is its Light group plus its own lines (_resolve_light_groups).
	var light := _resolve_light_groups(files)
	if light["error"] != "":
		result.error = light["error"]
		return result
	var named_as: Callable = func(page: String, section: String, key: String) -> String:
		return Kit.header_of(page, light["from"].get("%s|%s|%s" % [page, section, key], section))
	# Every row named on any page must be complete on its pages, as the kind
	# any page names in its `kind`, else a channel row when any page gives it
	# `channel_frames` (Moves.row_kind), else a swing row. A character's own
	# row ([duelist.move.<name>]) likewise (Kit.strip).
	var row_kinds := {}
	var named_kinds := {}
	for page in read:
		var file: ConfigFile = files[page]
		for section in file.get_sections():
			if not Moves.is_row(Kit.strip(section)):
				continue
			if file.has_section_key(section, Moves.KIND_KEY):
				var named: Variant = file.get_value(section, Moves.KIND_KEY)
				named_kinds[section] = named if named is String and named in Moves.ROW_KINDS else Moves.SWING
			elif not row_kinds.has(section) or row_kinds[section] == Moves.SWING:
				row_kinds[section] = Moves.CHANNEL if file.has_section_key(section, "channel_frames") else Moves.SWING
	row_kinds.merge(named_kinds, true)
	# The ultimate slots' effects (absent: the slow), so each needs only its
	# own effect's keys.
	var effects := {}
	for page in read:
		var file: ConfigFile = files[page]
		for section in file.get_sections():
			if Kit.strip(section) == Moves.ULTIMATE_MOVE and file.has_section_key(section, Moves.EFFECT_KEY):
				var effect: Variant = file.get_value(section, Moves.EFFECT_KEY)
				if not (effect is String and Moves.EFFECTS.has(effect)):
					var quoted := ", ".join(Moves.EFFECTS.keys().map(func(o: String) -> String: return "\"%s\"" % o))
					result.error = "%s.cfg: [%s] %s must be one of %s (in quotes), got %s" % [page, Kit.header_of(page, section),
						Moves.EFFECT_KEY, quoted, var_to_str(effect)]
					return result
				effects[section] = effect
	# Their charges likewise (one not given or not known: the time's keys
	# are asked, and reading `charge` itself names the fault).
	var charges := {}
	for page in read:
		var file: ConfigFile = files[page]
		for section in file.get_sections():
			if Kit.strip(section) == Moves.ULTIMATE_MOVE and file.has_section_key(section, Moves.CHARGE_KEY):
				var charge: Variant = file.get_value(section, Moves.CHARGE_KEY)
				if charge is String and Moves.CHARGE_KEYS.has(charge):
					charges[section] = charge
	var required := SCHEMA.duplicate()
	# The water page, when read, must hold every water key but its copies'
	# shared keys: those it overrides only when it gives them (Ground.ZONE_SHARED).
	if WATER_PAGE in read:
		var water := WaterRegistry.tuning_keys()
		for section: String in water:
			for key: String in water[section]:
				if not is_zone_override(section, key):
					required["%s.%s" % [section, key]] = water[section][key]
	# A character's kit is complete on its page once the page holds any of it:
	# its own [combo] and [ultimate] as the mage's (Kit.OWN_SECTIONS).
	for page in read:
		for section in (files[page] as ConfigFile).get_sections():
			var character := Kit.character_of(section)
			if character == "":
				continue
			for path: String in SCHEMA:
				if path.substr(0, path.rfind(".")) in Kit.OWN_SECTIONS:
					required["%s.%s" % [character, path]] = SCHEMA[path]
			var own_keys := kit_only_of(character)
			for path: String in own_keys:
				required["%s.%s" % [character, path]] = own_keys[path]
	# An effect out of SCHEMA is complete on the slot that names it.
	for section: String in effects:
		if effects[section] in Moves.SWITCHED_EFFECTS:
			var effect_keys: Dictionary = Moves.EFFECTS[effects[section]]
			for key: String in effect_keys:
				required["%s.%s" % [section, key]] = effect_keys[key]
	for path: String in required.keys():
		var section := path.substr(0, path.rfind("."))
		var key := path.substr(path.rfind(".") + 1)
		if Kit.strip(section) == Moves.ULTIMATE_MOVE and _effect_of_key(key) != "" \
				and _effect_of_key(key) != effects.get(section, Moves.EFFECT_SLOW):
			required.erase(path)
		if Kit.strip(section) == Moves.ULTIMATE_MOVE and _charge_of_key(key) != "" \
				and _charge_of_key(key) != charges.get(section, Moves.CHARGE_TIME):
			required.erase(path)
	for page in read:
		var file: ConfigFile = files[page]
		for section in file.get_sections():
			var own := Kit.strip(section)
			if Moves.is_row(own):
				var row_keys: Dictionary = Moves.KINDS[row_kinds[section]]["keys"]
				for key: String in row_keys:
					required["%s.%s" % [section, key]] = row_keys[key]
			for key in file.get_section_keys(section):
				var home := page_of(section, key)
				if Moves.is_row(own) and key != Moves.KIND_KEY and not Moves.KINDS[row_kinds[section]]["keys"].has(key):
					result.error = "%s.cfg: [%s] %s is not a tuning value of a %s row (check the spelling and the [section] above it)" % [
						page, named_as.call(page, section, key), key, row_kinds[section]]
					return result
				var effect: String = effects.get(section, Moves.EFFECT_SLOW)
				if own == Moves.ULTIMATE_MOVE and not _effect_of_key(key) in ["", effect]:
					result.error = "%s.cfg: [%s] %s is not a tuning value of a \"%s\" ultimate (its effect)" % [
						page, Kit.header_of(page, section), key, effect]
					return result
				var charge: String = charges.get(section, Moves.CHARGE_TIME)
				if own == Moves.ULTIMATE_MOVE and not _charge_of_key(key) in ["", charge]:
					result.error = "%s.cfg: [%s] %s is not a tuning value of an ultimate charged by \"%s\" (its charge)" % [
						page, Kit.header_of(page, section), key, charge]
					return result
				var rule := rule_of(section, key)
				if rule.is_empty():
					result.error = "%s.cfg: [%s] %s is not a tuning value (check the spelling and the [section] above it)" % [page, Kit.header_of(page, section), key]
					return result
				if home != page:
					result.error = "%s.cfg: [%s] %s belongs on %s.cfg, not here" % [page, Kit.header_of(page, section), key, home]
					return result
				# An optional key (a row's kind, the slot's effect) is read when given.
				required["%s.%s" % [section, key]] = rule
	var keys := required.keys()
	keys.sort()
	for page in read:
		var file: ConfigFile = files[page]
		for path: String in keys:
			var cut := path.rfind(".")
			var section: String = path.substr(0, cut)
			var name: String = path.substr(cut + 1)
			if page_of(section, name) != page:
				continue
			var error := _read(file, section, name, required[path], result.values)
			if error != "":
				result.error = "%s.cfg: [%s] %s %s" % [page, named_as.call(page, section, name), name, error]
				return result
	# Each zone copy of a shared section, whole: the shared keys it does not
	# give (Ground.with_zone_copies), before the checks and the multipliers.
	if WATER_PAGE in read:
		Ground.with_zone_copies(result.values, WaterRegistry.tuning_keys().keys())
	# Each kit's moves, in the tuning that kit plays (Kit.tuning_of).
	for character: String in Kit.characters(result.values):
		var kit := Kit.tuning_of(result.values, character)
		if result.error == "":
			result.error = _check_move_spans(kit, _shown(result.values, character))
		if result.error == "":
			result.error = _check_move_names(kit, _shown(result.values, character))
	if result.error == "":
		result.error = BoonText.check(result.values)
	if result.error == "":
		result.error = DangerClock.check(result.values, page_of)
	if result.error == "":
		result.error = ArrivalBatch.check(result.values, page_of)
	if result.error == "":
		result.error = AreaFatigue.check(result.values, page_of)
	if result.error == "":
		result.error = SuperSpawner.check(result.values, page_of)
	if result.error == "":
		result.error = Skittish.check(result.values, page_of)
	if result.error == "":
		result.error = Packs.check(result.values, page_of)
	if result.error == "":
		result.error = CoreMother.check(result.values, page_of)
	if result.error == "":
		result.error = BallGround.check(result.values)
	if result.error == "":
		result.error = ConeGround.check(result.values)
	if result.error == "":
		result.error = AshForest.check(result.values)
	if result.error == "":
		result.error = BeeSwarm.check(result.values)
	if result.error == "":
		result.error = CoreCrawler.check(result.values)
	# Last: the Global tab's multipliers scale their categories, so every
	# system reads plain scaled numbers (GlobalMultipliers).
	if result.error == "":
		GlobalMultipliers.apply(result.values, rule_of)
		# The paired checks again on the numbers the game plays: a key's range
		# can stop one of a pair and not the other (code review, 2026-10-18).
		var after := _paired_checks(result.values)
		if after != "":
			result.error = "%s, with the Global tab's %s" % [after, ", ".join(PackedStringArray(GlobalMultipliers.changed(result.values).map(
				func(key: String) -> String: return "%s %s%%" % [key, result.values[GlobalMultipliers.SECTION][key]])))]
	return result


## The checks that compare two keys (an order, a band) on `values`.
static func _paired_checks(values: Dictionary) -> String:
	for check: Callable in [DangerClock.check, ArrivalBatch.check, AreaFatigue.check, SuperSpawner.check,
			Skittish.check, Packs.check, CoreMother.check]:
		var error: String = check.call(values, page_of)
		if error != "":
			return error
	return ""


## Resolves the Light groups in `files` (page -> ConfigFile, the mage's
## headers already read as his sections), in place. A Light group
## ([<id>.move.light], the mage's [move.light] on his page and on the feel
## page) holds every light-swing value of one character; each of his light
## swings ([<id>.move.light_<n>], on any page) gets every group key its own
## section on that page lacks, and the group section is dropped, so what
## follows reads full rows. A swing's own line is its override. The chaining
## values (CHAINING_KEYS) are the combo graph: per swing, never in a group.
## Returns {error, from: "page|swing|key" -> the group's section, for each
## key a swing took from its group (errors name the line where it is
## written)}.
static func _resolve_light_groups(files: Dictionary) -> Dictionary:
	var swings := {}  # group section -> [swing sections], from every page
	for page: String in files:
		for section: String in (files[page] as ConfigFile).get_sections():
			var group := light_group_of(section)
			if group != "":
				if not swings.has(group):
					swings[group] = []
				if not section in swings[group]:
					swings[group].append(section)
	var from := {}
	for page: String in files:
		var file: ConfigFile = files[page]
		for group: String in file.get_sections():
			if not is_light_group(group):
				continue
			for key: String in file.get_section_keys(group):
				if key in CHAINING_KEYS:
					return {"error": "%s.cfg: [%s] %s is a chaining value: it goes on each light swing's own section ([%s_1]...), not in the Light group" % [
						page, Kit.header_of(page, group), key, Kit.header_of(page, group)], "from": {}}
			if not swings.has(group):
				return {"error": "%s.cfg: [%s] is a Light group but no light swing plays it (a [%s_1] section)" % [
					page, Kit.header_of(page, group), Kit.header_of(page, group)], "from": {}}
			for swing: String in swings[group]:
				for key: String in file.get_section_keys(group):
					if not file.has_section_key(swing, key):
						file.set_value(swing, key, file.get_value(group, key))
						from["%s|%s|%s" % [page, swing, key]] = group
			file.erase_section(group)
	return {"error": "", "from": from}


## True for a Light group's section: [move.light] (the mage's) or
## [<id>.move.light].
static func is_light_group(section: String) -> bool:
	return Kit.strip(section) == Moves.ROW_PREFIX + LIGHT_GROUP


## The Light group section a light swing's section plays ([duelist.move.light_2]
## -> [duelist.move.light], [mage.move.light_3] -> [mage.move.light]), or ""
## for any other section.
static func light_group_of(section: String) -> String:
	var own := Kit.strip(section)
	var swing := Moves.ROW_PREFIX + LIGHT_GROUP + "_"
	if not (own.begins_with(swing) and own.trim_prefix(swing).is_valid_int()):
		return ""
	return section.substr(0, section.length() - own.length()) + Moves.ROW_PREFIX + LIGHT_GROUP


## The charge (a Moves.CHARGE_KEYS key) whose key `key` is, or "" for a key
## of every ultimate slot.
static func _charge_of_key(key: String) -> String:
	for charge: String in Moves.CHARGE_KEYS:
		if Moves.CHARGE_KEYS[charge].has(key):
			return charge
	return ""


## The effect (a Moves.EFFECTS key) whose key `key` is, or "" for a key of
## every ultimate slot.
static func _effect_of_key(key: String) -> String:
	for effect: String in Moves.EFFECTS:
		if Moves.EFFECTS[effect].has(key):
			return effect
	return ""


## How a section of `character`'s kit tuning (Kit.tuning_of) is named on its
## page: with the character's prefix when `values` holds it so
## ([duelist.combo]), the mage's own on his page likewise ([mage.combo]),
## else as it is (the common sections every kit shares).
static func _shown(values: Dictionary, character: String) -> Callable:
	return func(section: String) -> String:
		if character == Kit.MAGE:
			return Kit.header_of(Kit.MAGE_PAGE, section) if Kit.is_mages_own(section) else section
		var own := "%s.%s" % [character, section]
		return own if values.has(own) else section


## Checks each line of a page is blank, a `;` comment, a `[section]` or a
## `key = value` with a readable value, so a typo is reported with its line
## (Godot's own reader only logs it).
static func _check_syntax(text: String) -> String:
	var in_section := false
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("#"):
			return "line %d starts with #; comments start with ; instead" % (i + 1)
		if line.begins_with("["):
			if not line.get_slice(";", 0).strip_edges().ends_with("]"):
				return "line %d: a [section] line must end with ]" % (i + 1)
			in_section = true
			continue
		if not line.contains("="):
			return "line %d: expected key = value, a [section] or a ; comment, got: %s" % [i + 1, line]
		if not in_section:
			return "line %d: %s comes before any [section]" % [i + 1, line]
		var value := line.substr(line.find("=") + 1).strip_edges()
		if str_to_var(value) == null:
			return ("line %d: cannot read the value in: %s (write a number like 6 or 6.5, or a word in quotes like \"%s\")"
				% [i + 1, line, value.get_slice(";", 0).strip_edges()])
	return ""


## Reads `section`'s `name` from `file` into `values`, or returns what is
## wrong with it.
static func _read(file: ConfigFile, section: String, name: String, rule: Array, values: Dictionary) -> String:
	if not file.has_section_key(section, name):
		return "is missing"
	var value: Variant = file.get_value(section, name)
	if rule[0] == "text":
		if not (value is String and value != ""):
			return "must be words in quotes, like \"Dagger\", got %s" % var_to_str(value)
		if not values.has(section):
			values[section] = {}
		values[section][name] = value
		return ""
	if rule[0] == "preset":
		if not value is String:
			return "must be a preset's name in quotes, like \"%s - default\", or \"\" for none, got %s" % [
				str(rule[1]).replace("_", " "), var_to_str(value)]
		if not values.has(section):
			values[section] = {}
		values[section][name] = value
		return ""
	if rule[0] == "colour":
		if not (value is String and _is_colour(value)):
			return "must be a colour code in quotes, like \"#ff4a1c\", got %s" % var_to_str(value)
		if not values.has(section):
			values[section] = {}
		values[section][name] = value
		return ""
	if rule[0] == "choice" or rule[0] == "move name":
		if rule[0] == "choice":
			var options: Array = rule[1]
			if not (value is String and value in options):
				var quoted := ", ".join(options.map(func(o: String) -> String: return "\"%s\"" % o))
				return "must be one of %s (in quotes), got %s" % [quoted, var_to_str(value)]
		elif not value is String:
			return "must be a move's name in quotes, like \"light_1\", got %s" % var_to_str(value)
		elif rule[1] == "required" and value == "":
			return "must name a move, got \"\""
		if not values.has(section):
			values[section] = {}
		values[section][name] = value
		return ""
	if not (value is float or value is int):
		return "must be a %s, got %s" % [rule[0], var_to_str(value)]
	if rule[0] == "whole number" and float(value) != floorf(float(value)):
		return "must be a whole number, got %s" % str(value)
	if float(value) < float(rule[1]) or float(value) > float(rule[2]):
		return "must be between %s and %s, got %s" % [str(rule[1]), str(rule[2]), str(value)]
	if not values.has(section):
		values[section] = {}
	values[section][name] = int(value) if rule[0] == "whole number" else float(value)
	return ""


## "#rrggbb": a # then six hex digits (either case).
static func _is_colour(text: String) -> bool:
	if text.length() != 7 or not text.begins_with("#"):
		return false
	for c: String in text.substr(1):
		if not "0123456789abcdefABCDEF".contains(c):
			return false
	return true


## Each move's frame spans (a swing's cancel and combo windows, the dodge's
## i-frames) must start no later than they end, and end no later than the
## move's last frame.
static func _check_move_spans(values: Dictionary, shown: Callable) -> String:
	for move: String in Moves.names(values):
		var section: String = shown.call(Moves.section_of(move))
		var data: Dictionary = values[Moves.section_of(move)]
		var kind := Moves.kind_of_section(Moves.section_of(move), data)
		if Moves.is_row(Moves.section_of(move)) and Moves.is_channel(data) and int(data["ticks"]) > int(data["channel_frames"]):
			return "%s.cfg: [%s] ticks (%d) must be at most channel_frames (%d): one pulse a frame at most" % [
				page_of(section, "ticks"), section, int(data["ticks"]), int(data["channel_frames"])]
		var length := Moves.length(kind, data)
		var length_keys: PackedStringArray = []
		for phase: Array in kind["phases"]:
			length_keys.append(str(phase[1]))
		for span_name: String in kind["spans"]:
			if not kind["spans"][span_name] is Array:
				continue  # a phase's own frames (Moves.span_frames): it fits
			var span: Array = kind["spans"][span_name]
			var frames := Moves.span_frames(kind, data, span_name)
			var first: int = frames[0]
			var last: int = frames[1]
			if not (span[0] is String and span[1] is String):
				continue  # a span fixed by the move's kind, not tuned
			var page := page_of(section, span[1])
			if last < first:
				return "%s.cfg: [%s] %s (%d) must not be before %s (%d)" % [page, section, span[1], last, span[0], first]
			if last > length:
				return "%s.cfg: [%s] %s must be at most the move's length, %d frames (%s), got %d" % [
					page, section, span[1], length, " + ".join(length_keys), last]
	return ""


## Every move name on the pages (the [combo] starts, each row's next moves)
## must name a move (a swing row, or a fixed move such as the blink), so a
## misspelt link stops the game instead of silently ending a combo.
static func _check_move_names(values: Dictionary, shown: Callable) -> String:
	var sections := values.keys()
	sections.sort()
	for section: String in sections:
		var keys: Array = values[section].keys()
		keys.sort()
		for key: String in keys:
			var rule := rule_of(section, key)
			if rule.is_empty() or rule[0] != "move name":
				continue
			var name: String = values[section][key]
			if name != "" and not values.has(Moves.section_of(name)):
				var named: String = shown.call(section)
				var rows: String = Kit.character_of(named) + "." if Kit.character_of(named) != "" else (
					Kit.MAGE_PAGE + "." if Kit.is_mage_header(named) else "")
				return "%s.cfg: [%s] %s names no move: \"%s\" (each move is a [%s%s<name>] section on %s.cfg, or [blink])" % [
					page_of(named, key), named, key, name, rows, Moves.ROW_PREFIX, page_of(named, "damage")]
	return ""
