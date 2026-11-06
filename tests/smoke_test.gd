## A headless smoke test of the lab: opens it, casts every effect on each of
## its moves, steps the clock through each cast, moves the reach slider, and
## saves, duplicates and renames a preset in a scratch folder. Prints PASS or
## the first thing that broke, and exits 0 or 1.
##
## Run it from the repo root (a scene, so the lab's GameClock autoload is up):
##   godot --headless --path . res://tests/smoke_test.tscn
extends Node

var _failed := ""


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var lab: Node3D = (load("res://vfx_lab/vfx_lab.tscn") as PackedScene).instantiate()
	add_child(lab)
	await get_tree().process_frame
	_check(lab.caster() != null, "the lab built no caster (a tuning page error?): " + lab.readout())
	if _failed == "":
		for id: String in lab.effects_of("mage"):
			lab.use_recipe(id)
			var moves: Array = FxMoves.moves_of(id)
			if moves.is_empty():
				moves = [lab.move]
			for m: String in moves:
				lab.move = m
				lab.handle_key(KEY_SPACE)
				_check(lab._cast, "%s on %s did not cast" % [id, m])
				# Stepped at 15 frames a second: every phase of the cast drawn, quickly.
				var steps := 0
				while lab.clock.time < lab.clock.length - 0.01 and steps < 120:
					lab.advance(1.0 / 15.0)
					steps += 1
				_check(lab.effect() != null, "%s on %s lost its effect" % [id, m])
			print("[smoke] %s: cast on %s (%d ms)" % [id, ", ".join(moves), Time.get_ticks_msec()])
	if _failed == "":
		lab.use_recipe("ground_shake")
		lab.advance(0.0)
		var spot: Dictionary = lab.reach()
		_check(not spot.is_empty(), "the ground shake shows no reach slider")
		if not spot.is_empty():
			# The hit is the page's reach times the kit's heavy area ([combo]
			# heavy_area_percent, on heavy moves): it follows the page in proportion.
			var was: float = float(spot["value"])
			var hit_was: float = float(lab.hit()["reach_m"])
			_check(lab.set_reach(was + 0.5) == "", "the reach slider did not take a new value")
			var hit_now: float = float(lab.hit()["reach_m"])
			_check(absf(hit_now / hit_was - (was + 0.5) / was) < 0.01, "the hit did not follow the reach slider")
			print("[smoke] reach slider: %s %.2f -> %.2f on the page, hit %.2f -> %.2f m" % [spot["key"], was,
				was + 0.5, hit_was, hit_now])
	if _failed == "":
		var scratch := "user://smoke_presets"
		FxPresets.use_folder(scratch)
		lab.use_recipe("tornado")
		var panel = lab.presets()
		_check(panel.save_preset("smoke - a") == "", "Save failed: " + panel.status())
		_check(panel.duplicate_preset("smoke - b") == "", "Duplicate failed: " + panel.status())
		_check(panel.rename_preset("smoke - c") == "", "Rename failed: " + panel.status())
		_check(panel.preset_text().contains("FxPreset") or panel.preset_text().contains("fx_preset"),
			"Copy wrote no preset text")
		_check(FxPresets.names("tornado") == ["smoke - a", "smoke - c"], "presets now: %s" % [FxPresets.names("tornado")])
		for n: String in FxPresets.names("tornado"):
			DirAccess.remove_absolute(FxPresets.path_of("tornado", n))
		FxPresets.use_folder("")
		print("[smoke] presets: save, duplicate, rename, copy")
	lab.queue_free()
	await get_tree().process_frame
	print("PASS" if _failed == "" else "FAIL: " + _failed)
	get_tree().quit(0 if _failed == "" else 1)


func _check(ok: bool, what: String) -> void:
	if not ok and _failed == "":
		_failed = what
