## The move graph: every move a player has, and how each kind of move reads
## its tuning section. CombatSim plays moves from it and Tuning validates their
## sections from it.
##
## The graph is data on the character page. Each swing is a row, a
## `[move.<name>]` section; the row names the move that follows it per button
## (`next_light`, `next_heavy`) and the frame span in which that press is taken
## (its combo window), plus an automatic follow-up when it ends (`next_auto`).
## `[combo]` names the move each button starts from free. A new combo is a new
## row: no code names a particular swing. The dodge is a fixed move, in its
## own `[dodge]` section, and so is the blink, in `[blink]`: a swing's
## `next_auto` may name it. The ultimate's cast is a fixed move too, in
## `[ultimate]`, which also holds the character's ultimate slot (how it
## charges and what it does; see CAST), and so is the drink, in `[drink]`.
class_name Moves
extends RefCounted

## A swing hits enemies with its hit shape in its active phase; a cancelling
## move pressed inside its cancel window ends it early; a light or heavy press
## inside its combo window chains into its next move for that button.
const SWING := "swing"
## A dodge carries the player over its whole length, is invulnerable on its
## i-frames, and cancels a swing inside the swing's cancel window. A paid
## dodge (CombatSim's paid cancel) is invulnerable from its own start frame
## (`paid_iframe_start_frame`) to the same last i-frame.
const DODGE := "dodge"
## A blink carries the player its distance over its whole length, invulnerable
## from its first frame to its last. It hits nothing and nothing cancels it.
## It is never pressed: a swing flows into it (`next_auto`).
const BLINK := "blink"
## The drink (C, CombatSim): a committed stand-still of its length that
## spends a carried potion on its first frame and heals
## `heal_percent_of_max_hp` of max HP on its last. It hits nothing, has no
## cancel window (no dodge, free or paid, gets out of it) and nothing chains
## from it; a flinch or stagger breaks it and the potion is lost.
const DRINK := "drink"
## A cast (the ultimate's, on F) stands the player still for its length
## (CAST_FRAMES: the slow's `cast_frames`, the fusion's `fusion_time_s`),
## committed: nothing cancels it, not even a paid dodge, and it is not
## invulnerable. A flinch or stagger breaks the slow's cast like any move,
## and then the ultimate is not spent; the fusion's cast no hit breaks (its
## hits cost HP only, CombatSim). Its section is the character's ultimate
## slot: `charge` names how the ultimate charges (CHARGE_KEYS: "time", a
## cooldown of `cooldown_s` from the moment a cast completes; "hits", the
## Duelist's gauge, `charge_per_enemy_struck_percent` per enemy his moves
## strike) and `effect` what it does on completing (EFFECTS: the mage's
## slow, the Duelist's fusion).
const CAST := "cast"
## The fusion's end (the Duelist's split, SPLIT_MOVE): a stand-still of
## `split_time_s` (the slot's), committed and unbreakable as the fusion's
## cast. Never pressed and never on a page of its own: CombatSim gives it to
## a kit whose ultimate is the fusion, played at the fusion's first free
## moment once its time is up.
const SPLIT := "split"
## A channel (the tornado, heavy, heavy, heavy's third press) is a row too, a
## `[move.<name>]` section, told from a swing by its `channel_frames` key
## (is_channel). It roots the player for `channel_frames`, then
## `recovery_frames`. Over the channel it pulses `ticks` times, evenly: pulse
## k (1 to ticks) lands on channel frame round(k * channel_frames / ticks)
## and hits every living enemy within `radius_m` for `tick_damage` at
## `hit_tier`, with no hitstop. On every channel frame the enemy half pushes
## every living enemy inside `radius_m` out to `radius_m` + `push_m` from the
## player (projectiles pass). A brake press (Q) during the channel collapses
## it into its recovery at once; a paid dodge gets out of any frame of it (it
## has no free cancel window); a chip does not break it, a flinch or stagger
## does. A press in a swing's combo window starts it like any row (the
## mage's tornado, P-O's ruling 2026-10-27); as a swing's `next_auto` it
## starts right after that swing's last active frame (the swing's recovery
## is cut), unless the combo was braked. Either way it is an ender (PAYLOADS).
const CHANNEL := "channel"
## A dash (the Duelist's slashing dash) is a row too, `kind = "dash"`. It
## stands through `startup_frames`, then runs `distance_m` along its
## direction at `speed_m_per_s` (its travel: TRAVEL_FRAMES, the "active"
## phase), then `recovery_frames`. Each travel tick it hits every enemy the
## path it swept that tick meets (a capsule `half_width_m` either side),
## each once per dash, and stops before unsafe ground (CombatSim._dash). Not
## invulnerable; nothing cancels it; as a swing's `next_auto` it is armed
## and braked like the blink.
const DASH := "dash"
## A hop (the Duelist's log roll, his heavy) is a row too, `kind = "hop"`:
## a swing whose step, `hop_distance_m` over startup and active, stops
## short of harmful ground and an edge (Ground.safe_reach: the dash's rule),
## and whose hit shape is two lobes on the ground, one along his facing to
## `reach_front_m`, one opposite to `reach_back_m`, each `lobe_arc_deg`
## wide, nothing at his sides (CombatSim._in_shape). Its windows, chains,
## targets, tier and feel keys are a swing's. `hop_height_m` and
## `wheel_tilt_deg` are drawn only (DuelistClips): the simulation never
## reads them.
const HOP := "hop"
## A throw (the Duelist's blade throw, light, light, heavy's ender) is a row
## too, `kind = "throw"`. It stands through `startup_frames` to the release,
## then the throw lock (its "lock" phase: LOCK_FRAMES, `lock_s` in ticks,
## never scaled by the tempo; attack speed shortens it, P-O's ruling 5),
## then `recovery_frames` after the catch. On the release the blades leave
## his hands as a record in his state (`blades`, CombatSim._fly_blades): out
## along his facing to `range_m` over the first half of the lock, back to
## wherever he stands over the second, one hit body `blade_radius_m` round
## them in which each of `blade_count` blades hits an enemy at most once
## going out and once coming back, `damage` each. While they fly he is
## locked: no move, walk, dodge or parry; a flinch or stagger breaks his
## pose but not the flight, and he acts again once they are back. With
## `paid_dodge_escapes_lock` = 1, a paid dodge gets him out (the blades
## still fly home). It has no active phase of its own: the blades hit.
## As a swing's `next_auto` it starts after that swing's active frames.
const THROW := "throw"
## A jump-slam (the Duelist's heavy, heavy ender) is a row too, `kind =
## "slam"`: no travel; a crouch (`startup_frames`), then the jump's air time
## (`airborne_untouchable_s`, seconds, never scaled: no enemy hit lands on
## him), then one landing frame (its "active" phase: every enemy within
## `radius_m` all round takes `damage` and is stunned `stun_s` through
## CombatSim.stun_enemy, its shove pointing away from him), then
## `recovery_frames`. As a swing's `next_auto` it starts once that swing's
## active frames end (as the tornado), armed and braked like the blink: Q
## before it starts brakes it, nothing ends it once it has. No cancel or
## combo window, and nothing follows it; a paid dodge gets out of it as
## out of any swing. `storm_pulse_frames` is Tempest's storm rhythm on it.
const SLAM := "slam"
## A shot (a charged shooter's light or heavy) is a row too, `kind = "shot"`:
## a swing's frames, windows and chains, its "active" frames firing where he
## faces instead of a hit shape: each is handed to his pack
## (CharacterPack.advance_shot; CombatSim._advance_move). `range_m` is how far a
## shot flies and `shot_radius_m` its body; its base numbers are level 1 of its
## charge, `*_level_2` and `*_level_3` the steps above.
const SHOT := "shot"
## A volley (a shooter's stream) is a row too, `kind = "volley"`:
## fired by a press, never charged, an ender however it is reached (PAYLOADS);
## its active frames are handed over as a shot's. `shots` is its count,
## `shots_per_charge_step` what each charge step of the chain before it adds.
const VOLLEY := "volley"
## A blast (a shooter's front blast) is a volley with no count of its own,
## `kind = "blast"`: it fires what the shots of the chain before it fired, so it
## follows their rows.
const BLAST := "blast"
## A lob (a shooter's mortar) is a row too, `kind = "lob"`: an ender (PAYLOADS),
## handed over as a shot's. Fired on its active frames, it lands `land_distance_m`
## ahead `flight_frames` later, over any pillar, bursting `radius_m` round
## (`radius_per_charge_step_m` more per charge step of the chain before it),
## stunning `stun_s`. Its hit is that landing (FxMoves.hit_s).
const LOB := "lob"

## The section of a swing row is this prefix plus the move's name.
const ROW_PREFIX := "move."
## The dodge's move name and section.
const DODGE_MOVE := "dodge"
## The blink's move name and section.
const BLINK_MOVE := "blink"
## The drink's move name and section.
const DRINK_MOVE := "drink"
## The ultimate's cast's move name and section (the ultimate slot).
const ULTIMATE_MOVE := "ultimate"
## The fusion's split's move name (no section: it reads the ultimate slot's
## `split_time_s`; SPLIT).
const SPLIT_MOVE := "split"
## The fixed moves (each its own section, named as the move) and their kinds.
const FIXED := {DODGE_MOVE: DODGE, BLINK_MOVE: BLINK, ULTIMATE_MOVE: CAST, DRINK_MOVE: DRINK}
## The ways an ultimate can charge (the ultimate slot's `charge`) and the
## slot's keys each adds: the mage's time cooldown (`cooldown_s`), or the
## Duelist's gauge, filled by the enemies his moves strike
## (`charge_per_enemy_struck_percent` each; CombatSim's Charge). A slot
## holds only its own charge's keys (Tuning).
const CHARGE_KEY := "charge"
const CHARGE_TIME := "time"
const CHARGE_HITS := "hits"
const CHARGES: Array[String] = [CHARGE_TIME, CHARGE_HITS]
const CHARGE_KEYS := {
	CHARGE_TIME: {
		"cooldown_s": ["number", 0.0, 3600.0],
	},
	CHARGE_HITS: {
		"charge_per_enemy_struck_percent": ["number", 0.0, 100.0],
	},
}
## A hit-charged gauge (a player's `ultimate_charge`) counts in hundredths
## of a percent: this much is full.
const FULL_GAUGE := 10000
## What an ultimate does when its cast completes (the slot's optional
## `effect`; absent = EFFECT_SLOW, the mage's) and the slot's keys each
## effect adds: the slow (its cast's `cast_frames`, CombatSim's slow time),
## or the fusion (the Duelist's: the cast's `fusion_time_s`, then
## `duration_s` of his fused kit, fused; the split's `split_time_s`; the
## view's flash and thunder). A slot holds only its own effect's keys
## (Tuning).
const EFFECT_KEY := "effect"
const EFFECT_SLOW := "slow"
const EFFECT_FUSION := "fusion"
## The tidal wave (a shooter's ultimate): the cast's `wave_cast_s`, then waves
## turning round him and mines left behind, run by his pack (CharacterPack.step_kit).
const EFFECT_TIDAL := "tidal"
const EFFECTS := {
	EFFECT_SLOW: {
		"cast_frames": ["whole number", 1, 600],
		"slow_enemy_speed_percent": ["whole number", 1, 100],
		"slow_duration_s": ["number", 0.0, 600.0],
	},
	EFFECT_FUSION: {
		"fusion_time_s": ["number", 0.05, 10.0],
		"split_time_s": ["number", 0.05, 10.0],
		"duration_s": ["number", 0.5, 600.0],
		"damage_mult": ["number", 0.1, 10.0],
		"swing_speed_mult": ["number", 0.25, 4.0],
		"arc_mult": ["number", 0.1, 10.0],
		"reach_mult": ["number", 0.1, 10.0],
		"flash_strength": ["number", 0.0, 1.0],
		"thunder_volume": ["number", 0.0, 1.0],
	},
	EFFECT_TIDAL: {
		"wave_cast_s": ["number", 0.05, 10.0],
		"wave_turn_s": ["number", 0.5, 120.0],
		"wave_reach_m": ["number", 0.5, 50.0],
		"wave_width_m": ["number", 0.1, 20.0],
		"wave_push_m": ["number", 0.0, 20.0],
		"wave_count": ["whole number", 1, 12],
		"wave_length_m": ["number", 0.5, 50.0],
		"wave_offset_m": ["number", 0.0, 50.0],
		"wave_spread_deg": ["number", 0.0, 360.0],
		"mine_count": ["whole number", 0, 200],
		"mine_damage": ["whole number", 0, 100000],
		"mine_lifetime_s": ["number", 0.0, 600.0],
		"mine_cap": ["whole number", 0, 200],
	},
}
## The effects only a page behind the content switch may hold: their keys stay
## out of Tuning.SCHEMA, which every build's pages and the tuning screen answer
## for, and are read only off a slot that names them (Tuning.parse).
const SWITCHED_EFFECTS: Array[String] = [EFFECT_TIDAL]
## A row's optional key naming its kind (a ROW_KINDS entry); absent, the
## row is a channel when it has `channel_frames`, else a swing (is_channel).
const KIND_KEY := "kind"
## The kinds a row (`[move.<name>]`) may be.
const ROW_KINDS: Array[String] = [SWING, CHANNEL, HOP, DASH, SLAM, THROW, SHOT, VOLLEY, BLAST, LOB]
## The row kinds whose active frames fire shots, handed to the character's pack.
const SHOOTING: Array[String] = [SHOT, VOLLEY, BLAST, LOB]
## A phase's frames key that is no tuning key: a dash's travel, worked out
## from its distance and speed (phase_frames).
const TRAVEL_FRAMES := "travel_frames"
## A phase's frames key that is no tuning key: a throw's lock, `lock_s` in
## whole ticks (at least two: one out, one back; phase_frames).
const LOCK_FRAMES := "lock_frames"
## A phase's frames key that is no tuning key: the ultimate's cast, its
## slot's `cast_frames` (the slow) or `fusion_time_s` in whole ticks (the
## fusion; at least one).
const CAST_FRAMES := "cast_length"
## The same for the fusion's split: `split_time_s` in whole ticks (at least one).
const SPLIT_FRAMES := "split_length"

## The buttons that start or chain moves, in press priority order: when several
## are pressed on one tick, the first listed wins. They are CombatSim's
## per-player input keys.
const BUTTONS: Array[String] = ["dodge", "heavy", "light", "ultimate"]

## Per kind of move:
##   keys: its tuning section's keys, as a Tuning.SCHEMA rule
##   phases: [phase name, frames key] in order; together they make the move's
##           length (phase_frames: a key ending "_s" is seconds, a number a
##           fixed length). A move hits enemies only in a phase named "active".
##   travels_until: the last phase over which the move covers its
##                  `distance_m`, evenly
##   spans: name -> [first frame, last frame], each a key of the move's section
##          or a fixed frame number (1 = the start frame), or a phase's name
##          alone (a String: that phase's frames); each span must fit
##          inside the move. "cancel_window": a cancelling move pressed in it
##          ends this one. "combo_window": a press with a next move chains in
##          it (0 to 0 = no window). "invulnerable": enemy hits do nothing.
##          "paid_invulnerable": the same, when the move was paid for.
##   cancels: pressed inside another move's cancel window, it ends that move
##            and starts on the same tick
##   start_event: the event type its start frame emits
##   paid_escape (optional, default false): a paid dodge gets out of any frame
##                of it, with no free cancel window needed (see CombatSim's
##                paid cancel)
##   follows_after (optional): as a swing's `next_auto`, it starts once that
##                 swing's phase of this name has ended, not the whole swing
##   travel_key (optional): the key of the distance it covers over its
##              travel (default "distance_m")
##   reach_keys (optional): the keys a reach boon scales (Boons.tuned)
##   safe_travel (optional, default false): its travel stops short of
##               harmful ground and an edge (Ground.safe_reach)
const KINDS := {
	SWING: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"distance_m": ["number", 0.0, 20.0],
			"reach_m": ["number", 0.1, 20.0],
			"arc_deg": ["number", 1.0, 360.0],
			"targets": ["whole number", 0, 100],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"stuns": ["choice", ["yes", "no"]],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "active",
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["reach_m"],
	},
	HOP: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"hop_distance_m": ["number", 0.0, 20.0],
			"hop_height_m": ["number", 0.0, 5.0],
			"reach_front_m": ["number", 0.1, 20.0],
			"reach_back_m": ["number", 0.1, 20.0],
			"lobe_arc_deg": ["number", 1.0, 180.0],
			"wheel_tilt_deg": ["number", 0.0, 90.0],
			"targets": ["whole number", 0, 100],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"stuns": ["choice", ["yes", "no"]],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "active",
		"travel_key": "hop_distance_m",
		"safe_travel": true,
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["reach_front_m", "reach_back_m"],
	},
	SLAM: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"airborne_untouchable_s": ["number", 0.0, 10.0],
			"recovery_frames": ["whole number", 0, 600],
			"radius_m": ["number", 0.1, 20.0],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"stun_s": ["number", 0.0, 60.0],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
			"storm_pulse_frames": ["whole number", 1, 600],
		},
		"phases": [["startup", "startup_frames"], ["airborne", "airborne_untouchable_s"], ["active", 1],
			["recovery", "recovery_frames"]],
		"travels_until": "",
		"travel_key": "",
		"spans": {"invulnerable": "airborne"},
		"cancels": false,
		"start_event": "move_started",
		"follows_after": "active",
		"reach_keys": ["radius_m"],
	},
	DODGE: {
		"keys": {
			"distance_m": ["number", 0.0, 20.0],
			"duration_frames": ["whole number", 1, 600],
			"iframe_start_frame": ["whole number", 1, 600],
			"iframe_end_frame": ["whole number", 1, 600],
			"paid_iframe_start_frame": ["whole number", 1, 600],
		},
		"phases": [["dodge", "duration_frames"]],
		"travels_until": "dodge",
		"spans": {"invulnerable": ["iframe_start_frame", "iframe_end_frame"],
			"paid_invulnerable": ["paid_iframe_start_frame", "iframe_end_frame"]},
		"cancels": true,
		"start_event": "dodge_started",
	},
	BLINK: {
		"keys": {
			"distance_m": ["number", 0.0, 20.0],
			"duration_frames": ["whole number", 1, 600],
		},
		"phases": [["blink", "duration_frames"]],
		"travels_until": "blink",
		"spans": {"invulnerable": [1, "duration_frames"]},
		"cancels": false,
		"start_event": "blink_started",
	},
	DRINK: {
		"keys": {
			"duration_frames": ["whole number", 1, 600],
			"heal_percent_of_max_hp": ["number", 0.0, 100.0],
		},
		"phases": [["drink", "duration_frames"]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "drink_started",
	},
	CAST: {
		"keys": {
			CHARGE_KEY: ["choice", CHARGES],
		},
		"phases": [["cast", CAST_FRAMES]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "ultimate_cast_started",
	},
	SPLIT: {
		"keys": {},
		"phases": [["split", SPLIT_FRAMES]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "fusion_split",
	},
	CHANNEL: {
		"keys": {
			"channel_frames": ["whole number", 1, 1800],
			"ticks": ["whole number", 1, 600],
			"tick_damage": ["whole number", 0, 100000],
			"radius_m": ["number", 0.1, 20.0],
			"push_m": ["number", 0.0, 20.0],
			"recovery_frames": ["whole number", 0, 600],
			"hit_tier": ["choice", Enemies.TIERS],
			"walk_percent": ["number", 0.0, 100.0],
		},
		"phases": [["channel", "channel_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "move_started",
		"paid_escape": true,
		"follows_after": "active",
		"reach_keys": ["radius_m"],
	},
	DASH: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"distance_m": ["number", 0.0, 20.0],
			"speed_m_per_s": ["number", 1.0, 200.0],
			"half_width_m": ["number", 0.05, 20.0],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", TRAVEL_FRAMES], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["half_width_m"],
	},
	THROW: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"lock_s": ["number", 0.1, 10.0],
			"range_m": ["number", 0.5, 30.0],
			"blade_count": ["whole number", 1, 2],
			"blade_radius_m": ["number", 0.05, 10.0],
			"paid_dodge_escapes_lock": ["whole number", 0, 1],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["lock", LOCK_FRAMES], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"spans": {},
		"cancels": false,
		"start_event": "move_started",
		"follows_after": "active",
		"reach_keys": ["blade_radius_m"],
	},
	SHOT: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"range_m": ["number", 0.5, 30.0],
			"shot_radius_m": ["number", 0.05, 10.0],
			"shot_speed_m_per_s": ["number", 1.0, 200.0],
			"speed_level_2_m_per_s": ["number", 1.0, 200.0],
			"speed_level_3_m_per_s": ["number", 1.0, 200.0],
			"arc_deg": ["number", 1.0, 360.0],
			"arc_level_2_deg": ["number", 1.0, 360.0],
			"arc_level_3_deg": ["number", 1.0, 360.0],
			"shots": ["whole number", 1, 100],
			"shots_level_2": ["whole number", 1, 100],
			"shots_level_3": ["whole number", 1, 100],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"damage_level_2": ["whole number", 0, 100000],
			"damage_level_3": ["whole number", 0, 100000],
			"stagger_frames": ["whole number", 0, 600],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"travel_key": "",
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["shot_radius_m"],
	},
	VOLLEY: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"range_m": ["number", 0.5, 30.0],
			"shot_radius_m": ["number", 0.05, 10.0],
			"shot_speed_m_per_s": ["number", 1.0, 200.0],
			"arc_deg": ["number", 1.0, 360.0],
			"shots": ["whole number", 1, 100],
			"shots_per_charge_step": ["whole number", 0, 100],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"travel_key": "",
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["shot_radius_m"],
	},
	BLAST: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"range_m": ["number", 0.5, 30.0],
			"shot_radius_m": ["number", 0.05, 10.0],
			"shot_speed_m_per_s": ["number", 1.0, 200.0],
			"arc_deg": ["number", 1.0, 360.0],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"travel_key": "",
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["shot_radius_m"],
	},
	LOB: {
		"keys": {
			"startup_frames": ["whole number", 1, 600],
			"active_frames": ["whole number", 1, 600],
			"recovery_frames": ["whole number", 0, 600],
			"cancel_window_start_frame": ["whole number", 1, 1800],
			"cancel_window_end_frame": ["whole number", 1, 1800],
			"combo_window_start_frame": ["whole number", 0, 1800],
			"combo_window_end_frame": ["whole number", 0, 1800],
			"next_light": ["move name", "or none"],
			"next_heavy": ["move name", "or none"],
			"next_auto": ["move name", "or none"],
			"land_distance_m": ["number", 0.5, 50.0],
			"flight_frames": ["whole number", 1, 600],
			"radius_m": ["number", 0.1, 20.0],
			"radius_per_charge_step_m": ["number", 0.0, 20.0],
			"stun_s": ["number", 0.0, 60.0],
			"hit_tier": ["choice", Enemies.TIERS],
			"damage": ["whole number", 0, 100000],
			"hitstop_frames": ["whole number", 0, 120],
			"knockback_m": ["number", 0.0, 20.0],
		},
		"phases": [["startup", "startup_frames"], ["active", "active_frames"], ["recovery", "recovery_frames"]],
		"travels_until": "",
		"travel_key": "",
		"spans": {
			"cancel_window": ["cancel_window_start_frame", "cancel_window_end_frame"],
			"combo_window": ["combo_window_start_frame", "combo_window_end_frame"],
		},
		"cancels": false,
		"start_event": "move_started",
		"reach_keys": ["radius_m"],
	},
}

## Attack scopes (GLOSSARY "Attack scope", "Ender"): which of a character's
## attacks a move is. A boon asks whether a hit is in its scope, never which
## move it is. Moves that attack nothing (the dodge, the drink, the cast) have
## none ("").
const SCOPE_LIGHT_ATTACK := "light_attack"
const SCOPE_LIGHT_ENDER := "light_ender"
const SCOPE_HEAVY_ATTACK := "heavy_attack"
const SCOPE_HEAVY_ENDER := "heavy_ender"
const SCOPE_NONE := ""
## The row kinds that are a combo's payload, an ender however a press or a
## swing's `next_auto` reaches them (scopes): the channel (the tornado) and
## the jump-slam, a volley, a blast and a lob (fired by a press of the chain's own
## button, as light, light, light, press: still the ender).
const PAYLOADS: Array[String] = [CHANNEL, SLAM, VOLLEY, BLAST, LOB]


## Every move's attack scope in `values` (merged tuning, by section), as
## move name -> SCOPE_*, read off the move graph so a new character's rows
## tag themselves: walking from `[combo] start_light` (light) and
## `start_heavy` (heavy), a press of the same button as the chain so far is an
## attack of that side; a press of the other button is an ender of the
## pressed side outright (light-light-heavy's heavy press); a move a row flows
## into on its own (`next_auto`: the blink, the tornado) is an ender of that
## row's side; whatever follows an ender is an ender too. A channel or a
## jump-slam (PAYLOADS) is an ender however it is reached: the mage's
## tornado, heavy, heavy, heavy's third press (P-O's ruling 2026-10-27), is
## the heavy ender as it was when it followed whirlwind_2 on its own. Moves
## the graph never reaches have SCOPE_NONE (absent from the result).
static func scopes(values: Dictionary) -> Dictionary:
	var out := {}
	var combo: Dictionary = values.get("combo", {})
	# [move, side, is ender], walked breadth first; a move keeps its first tag.
	var queue: Array = [[str(combo.get("start_light", "")), "light", false],
		[str(combo.get("start_heavy", "")), "heavy", false]]
	while not queue.is_empty():
		var at: Array = queue.pop_front()
		var move: String = at[0]
		if move == "" or out.has(move) or not values.has(section_of(move)):
			continue
		var side: String = at[1]
		var data: Dictionary = values[section_of(move)]
		var ender: bool = at[2] or (is_row(section_of(move)) and row_kind(data) in PAYLOADS)
		out[move] = "%s_%s" % [side, "ender" if ender else "attack"]
		for button: String in ["light", "heavy"]:
			queue.append([str(data.get("next_" + button, "")), button, ender or button != side])
		queue.append([str(data.get("next_auto", "")), side, true])
	return out


## A pulsing channel's hit lands this far past its `radius_m` too, so an enemy
## the push left exactly on the edge is still hit (floating point).
const CHANNEL_EDGE_M := 0.001


## True for a swing row's section, `[move.<name>]`.
static func is_row(section: String) -> bool:
	return section.begins_with(ROW_PREFIX) and section.length() > ROW_PREFIX.length()


## The tuning section of move `name`.
static func section_of(name: String) -> String:
	return name if FIXED.has(name) else ROW_PREFIX + name


## True for a row's tuning section `data` that is a channel: its `kind`
## says so, or, with no `kind`, it has `channel_frames`.
static func is_channel(data: Dictionary) -> bool:
	return row_kind(data) == CHANNEL


## The kind (a ROW_KINDS entry) of a row whose tuning section is `data`:
## its `kind`, else a channel when it has `channel_frames`, else a swing.
static func row_kind(data: Dictionary) -> String:
	return str(data.get(KIND_KEY, CHANNEL if data.has("channel_frames") else SWING))


## The kind (a KINDS key) of the move in `section`, whose tuning section is
## `data` (a row by row_kind).
static func kind_name_of_section(section: String, data: Dictionary = {}) -> String:
	if is_row(section):
		return row_kind(data)
	return FIXED[section]


static func kind_of_section(section: String, data: Dictionary = {}) -> Dictionary:
	return KINDS[kind_name_of_section(section, data)]


## The rule (as in Tuning.SCHEMA) of a row's `key`, for any kind of row
## (ROW_KINDS in order: the keys they share have one rule), or [].
static func row_rule(key: String) -> Array:
	if key == KIND_KEY:
		return ["choice", ROW_KINDS]
	for kind: String in ROW_KINDS:
		var rule: Array = KINDS[kind]["keys"].get(key, [])
		if not rule.is_empty():
			return rule
	return []


## The distance (m) a move whose tuning section is `data`, of kind `kind`
## (a KINDS entry), covers over its travel: its kind's `travel_key`.
static func travel_m(kind: Dictionary, data: Dictionary) -> float:
	return float(data.get(kind.get("travel_key", "distance_m"), 0.0))


## True for a throw row's tuning section `data` (`kind = "throw"`).
static func is_throw(data: Dictionary) -> bool:
	return row_kind(data) == THROW


## True for a dash row's tuning section `data` (`kind = "dash"`).
static func is_dash(data: Dictionary) -> bool:
	return row_kind(data) == DASH


## True for a row that is a jump-slam (SLAM).
static func is_slam(data: Dictionary) -> bool:
	return row_kind(data) == SLAM


## True for a row whose active frames fire shots (SHOOTING).
static func fires_shots(data: Dictionary) -> bool:
	return row_kind(data) in SHOOTING


## True for a row that is a lob (LOB).
static func is_lob(data: Dictionary) -> bool:
	return row_kind(data) == LOB


## The frames of the phase whose frames key is `key` (a KINDS phase's
## second entry) in a move's tuning section `data`: a fixed number as it
## is; a dash's travel (TRAVEL_FRAMES): its distance at its speed, in whole
## ticks (at least one); a key ending "_s" is seconds, rounded to frames
## (CombatSim.TICK_HZ); a throw's lock (LOCK_FRAMES): `lock_s` in whole
## ticks (at least two: one out, one back); the ultimate's cast
## (CAST_FRAMES) and the fusion's split (SPLIT_FRAMES) as those say; any
## other key's value, frames.
static func phase_frames(data: Dictionary, key: Variant) -> int:
	if not key is String:
		return int(key)
	if key == CAST_FRAMES:
		if data.has("cast_frames"):
			return int(data["cast_frames"])
		return maxi(1, roundi(float(data["wave_cast_s" if data.has("wave_cast_s") else "fusion_time_s"]) * 60.0))
	if key == SPLIT_FRAMES:
		return maxi(1, roundi(float(data["split_time_s"]) * 60.0))
	if key == LOCK_FRAMES:
		return maxi(2, roundi(float(data["lock_s"]) * CombatSim.TICK_HZ))
	if key == TRAVEL_FRAMES:
		return maxi(1, ceili(float(data["distance_m"]) / float(data["speed_m_per_s"]) * CombatSim.TICK_HZ - 0.000001))
	if key.ends_with("_s"):
		return roundi(float(data[key]) * 60.0)
	return int(data[key])


## The damage one hit of a row deals: a swing's `damage`, a channel's
## `tick_damage` per pulse.
static func damage_of(data: Dictionary) -> int:
	return int(data["tick_damage"]) if is_channel(data) else int(data["damage"])


## The channel frames (1 = the move's first) a channel row `data` pulses on:
## round(k * channel_frames / ticks) for k = 1 to ticks, as a set (frame ->
## true). Two pulses rounding onto one frame land once.
static func pulse_frames(data: Dictionary) -> Dictionary:
	var frames := {}
	var channel := int(data["channel_frames"])
	var ticks := int(data["ticks"])
	for k in range(1, ticks + 1):
		frames[clampi(roundi(float(k * channel) / ticks), 1, channel)] = true
	return frames


## Every move in `values` (merged tuning, by section): the fixed moves (the
## dodge, the blink, the ultimate's cast, the drink), then the swing rows
## sorted by name, so every peer walks them in the same order.
static func names(values: Dictionary) -> Array[String]:
	var rows: Array[String] = []
	for section: String in values:
		if is_row(section):
			rows.append(section.trim_prefix(ROW_PREFIX))
	rows.sort()
	var out: Array[String] = [DODGE_MOVE, BLINK_MOVE, ULTIMATE_MOVE, DRINK_MOVE]
	out.append_array(rows)
	return out


## A move's length in frames: the sum of its phases, read from `data` (its
## tuning section).
static func length(kind: Dictionary, data: Dictionary) -> int:
	var frames := 0
	for phase: Array in kind["phases"]:
		frames += phase_frames(data, phase[1])
	return frames


## The first and last frame of `kind`'s span named `span_name`, read from
## `data` (its tuning section), or [] if the kind has no such span.
static func span_frames(kind: Dictionary, data: Dictionary, span_name: String) -> Array:
	if not kind["spans"].has(span_name):
		return []
	if kind["spans"][span_name] is String:
		# A phase's frames.
		var first := 1
		for phase: Array in kind["phases"]:
			var frames := phase_frames(data, phase[1])
			if phase[0] == kind["spans"][span_name]:
				return [first, first + frames - 1]
			first += frames
		return []
	var ends: Array = kind["spans"][span_name]
	return ends.map(func(end: Variant) -> int: return int(data[end]) if end is String else int(end))


## The tuning at its `[combo] tempo` (playtest ruling 7): every swing row and
## the blink play `tempo` times as fast. A swing's startup, active and
## recovery frames become round(frames / tempo), startup and active at least 1
## (a recovery of 0 stays 0), and its cancel and combo windows keep their
## place in the move (place_frame); the blink's duration_frames likewise. Hitstop
## and everything else are left as given (a channel row's `channel_frames`
## and `recovery_frames` scale like a swing's phases): the dodge, the drink and the
## ultimate's cast are defence and design-rule timings. The result's tempo is
## 1.0, so applying it again changes nothing (CombatSim applies it to every
## tuning it is given, Boons.tuned variants included: Dagger composes on
## top). `[combo] light_tempo` (optional, absent 1.0; playtest 2026-10-25
## point 10) multiplies the tempo for the light swings only (Boons.light_rows:
## light_1 to light_3), so the blink after the third light comes sooner while
## its own length, the heavies and the rest keep the tempo alone; it is 1.0 in
## the result too. A tempo and light tempo of 1.0 return `tuning` itself;
## otherwise a copy.
static func at_tempo(tuning: Dictionary) -> Dictionary:
	var combo: Dictionary = tuning.get("combo", {})
	var base_tempo := float(combo.get("tempo", 1.0))
	var light_tempo := float(combo.get("light_tempo", 1.0))
	if base_tempo == 1.0 and light_tempo == 1.0:
		return tuning
	var lights: Array[String] = Boons.light_rows(tuning) if light_tempo != 1.0 else ([] as Array[String])
	var out := tuning.duplicate()
	out["combo"] = combo.duplicate()
	out["combo"]["tempo"] = 1.0
	if combo.has("light_tempo"):
		out["combo"]["light_tempo"] = 1.0
	for section: String in tuning:
		var tempo := base_tempo * light_tempo if section in lights else base_tempo
		if tempo == 1.0:
			continue
		if is_row(section) and is_channel(tuning[section]):
			# A channel's two phases likewise (its pulses spread over the longer
			# channel, pulse_frames).
			var channel: Dictionary = tuning[section].duplicate()
			channel["channel_frames"] = maxi(1, roundi(int(channel["channel_frames"]) / tempo))
			channel["recovery_frames"] = roundi(int(channel["recovery_frames"]) / tempo)
			out[section] = channel
		elif is_row(section) and is_dash(tuning[section]):
			out[section] = quickened_dash(tuning[section], tempo)
		elif is_row(section) and is_throw(tuning[section]):
			# The wind-up and the recovery; never the lock (spec "Blade throw").
			out[section] = quickened_throw(tuning[section], tempo, false)
		elif is_row(section):
			out[section] = quickened(tuning[section], tempo)
	if tuning.has(BLINK_MOVE) and base_tempo != 1.0:
		out[BLINK_MOVE] = tuning[BLINK_MOVE].duplicate()
		out[BLINK_MOVE]["duration_frames"] = maxi(1, roundi(int(tuning[BLINK_MOVE]["duration_frames"]) / base_tempo))
	return out


## The tuning with its kit's heavy area (P-O's light vs heavy pass,
## 2026-10-28; docs/boon-system.md section 8): `[combo] heavy_area_percent`
## (optional, absent 100) sizes every heavy attack and heavy ender row
## (scopes: the move graph) to that share of the page's: the kind's
## reach_keys (a swing's reach, a hop's two lobes, a channel's or slam's
## radius, a dash's path width, the blades' body), never a travel or the
## throw's range. The result's percent is 100, so applying it again changes
## nothing (CombatSim applies it to every tuning it is given, Boons.tuned
## variants included: Greatsword composes on top). At 100 (or absent) it
## returns `tuning` itself; otherwise a copy.
static func at_heavy_area(tuning: Dictionary) -> Dictionary:
	var combo: Dictionary = tuning.get("combo", {})
	var share := float(combo.get("heavy_area_percent", 100.0)) / 100.0
	if share == 1.0:
		return tuning
	var out := tuning.duplicate()
	out["combo"] = combo.duplicate()
	out["combo"]["heavy_area_percent"] = 100.0
	var all := scopes(tuning)
	for move: String in all:
		if all[move] != SCOPE_HEAVY_ATTACK and all[move] != SCOPE_HEAVY_ENDER:
			continue
		var section := section_of(move)
		if not is_row(section):
			continue
		var row: Dictionary = tuning[section].duplicate()
		for key: String in KINDS[row_kind(row)].get("reach_keys", []):
			row[key] = float(row[key]) * share
		out[section] = row
	return out


## Row `row` (a swing, hop or slam) played `rate` times as fast: its
## startup, active and recovery frames divided by it (rounded; startup and
## active at least 1), its windows kept in place (rephased). A slam has no
## windows and one landing frame: its crouch and recovery likewise, its air
## time (seconds) as it is.
static func quickened(row: Dictionary, rate: float) -> Dictionary:
	if is_slam(row):
		var out := row.duplicate()
		out["startup_frames"] = maxi(1, roundi(int(row["startup_frames"]) / rate))
		out["recovery_frames"] = roundi(int(row["recovery_frames"]) / rate)
		return out
	return rephased(row, maxi(1, roundi(int(row["startup_frames"]) / rate)),
		maxi(1, roundi(int(row["active_frames"]) / rate)), roundi(int(row["recovery_frames"]) / rate))


## Dash row `row` played `rate` times as fast: its startup and recovery
## divided by it (rounded; at least one tick of startup), its speed times
## it: the same distance, sooner.
static func quickened_dash(row: Dictionary, rate: float) -> Dictionary:
	var out := row.duplicate()
	out["startup_frames"] = maxi(1, roundi(int(row["startup_frames"]) / rate))
	out["recovery_frames"] = roundi(int(row["recovery_frames"]) / rate)
	out["speed_m_per_s"] = float(row["speed_m_per_s"]) * rate
	return out


## Throw row `row` played `rate` times as fast: its startup and recovery
## divided by it (rounded; at least one tick of startup) and, with
## `lock` (attack speed: the blades fly faster, P-O's ruling 5), its
## `lock_s` too. The tempo leaves the lock alone.
static func quickened_throw(row: Dictionary, rate: float, lock: bool) -> Dictionary:
	var out := row.duplicate()
	out["startup_frames"] = maxi(1, roundi(int(row["startup_frames"]) / rate))
	out["recovery_frames"] = roundi(int(row["recovery_frames"]) / rate)
	if lock:
		out["lock_s"] = float(row["lock_s"]) / rate
	return out


## The swing windows a phase change moves (see rephased).
const WINDOW_KEYS: Array[String] = ["cancel_window_start_frame", "cancel_window_end_frame",
	"combo_window_start_frame", "combo_window_end_frame"]


## Swing row `row` with phases `startup`, `active` and `recovery` frames
## long, its cancel and combo windows moved with them (place_frame); a row with no
## combo window (0 to 0) keeps none.
static func rephased(row: Dictionary, startup: int, active: int, recovery: int) -> Dictionary:
	var out := row.duplicate()
	out["startup_frames"] = startup
	out["active_frames"] = active
	out["recovery_frames"] = recovery
	for key: String in WINDOW_KEYS:
		out[key] = place_frame(int(row[key]), [int(row["startup_frames"]), int(row["active_frames"]),
			int(row["recovery_frames"])], [startup, active, recovery])
	if int(row["combo_window_start_frame"]) == 0 and int(row["combo_window_end_frame"]) == 0:
		out["combo_window_start_frame"] = 0
		out["combo_window_end_frame"] = 0
	return out


## Where frame `frame` of a swing whose phases were `old` frames long
## ([startup, active, recovery]) falls once they are `new` long: the same
## fraction of the way into its phase (rounded), never before the phase's
## first frame; a phase's last frame stays its last. Frame 0 (no window)
## stays 0.
static func place_frame(frame: int, old: Array, new: Array) -> int:
	if frame <= 0:
		return 0
	var old_start := 0
	var new_start := 0
	for p in old.size():
		var o := int(old[p])
		var n := int(new[p])
		if frame <= old_start + o or p == old.size() - 1:
			var into := frame - old_start
			return new_start + clampi(roundi(float(into) * n / maxi(1, o)), mini(1, n), n)
		old_start += o
		new_start += n
	return frame


## The fused kit (the Duelist's fusion, spec "Fusion"; P-O's ruling 3;
## docs/characters/duelist.md Q4-Q6): `tuning` (a kit's, its ultimate a
## fusion) with every move row re-read for the fused greatsword, by its
## ultimate slot's numbers. Each row plays at `swing_speed_mult` (its
## frames divided by it as attack speed does, windows kept in place:
## quickened; a dash the same distance at that speed, quickened_dash; a
## throw its wind-up and recovery, never its lock); each hit deals
## `damage_mult / swing_speed_mult` times its damage (rounded), so the
## damage per second is `damage_mult` times; a swing's arc is `arc_mult`
## times (at most 360: the light's fan, 60 to 180 deg; the log roll's lobes
## keep their width); every hit size (the kind's reach_keys: a swing's
## reach, both lobes, the slam's radius, the dash's path width, the blades'
## body) and the throw's range are `reach_mult` times, never a travel (the
## dash's distance, the hop's step). The throw throws one greatsword:
## `blade_count` 1, its hit the pair's (`damage` times their count, then
## the fused rate). The tuning given is not changed.
static func fused(tuning: Dictionary) -> Dictionary:
	var slot: Dictionary = tuning[ULTIMATE_MOVE]
	var speed := float(slot["swing_speed_mult"])
	var dealt := float(slot["damage_mult"]) / speed
	var reach := float(slot["reach_mult"])
	var out := tuning.duplicate()
	for section: String in tuning:
		if not is_row(section):
			continue
		var row: Dictionary = tuning[section]
		var kind := row_kind(row)
		var damage_key := "damage"
		match kind:
			DASH:
				row = quickened_dash(row, speed)
			THROW:
				row = quickened_throw(row, speed, false)
				row["range_m"] = float(row["range_m"]) * reach
				row["damage"] = int(row["damage"]) * int(row["blade_count"])
				row["blade_count"] = 1
			CHANNEL:
				row = row.duplicate()
				row["channel_frames"] = maxi(1, roundi(int(row["channel_frames"]) / speed))
				row["recovery_frames"] = roundi(int(row["recovery_frames"]) / speed)
				damage_key = "tick_damage"
			_:
				row = quickened(row, speed)
		row[damage_key] = roundi(int(row[damage_key]) * dealt)
		for key: String in KINDS[kind].get("reach_keys", []):
			row[key] = float(row[key]) * reach
		if kind == SWING:
			row["arc_deg"] = minf(360.0, float(row["arc_deg"]) * float(slot["arc_mult"]))
		out[section] = row
	return out
