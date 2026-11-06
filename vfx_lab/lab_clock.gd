## The lab's time (spec Q9): the seconds since the cast began and the cast's
## seed, which is all an effect is drawn from, so pause, 0.1x, a frame step
## either way and a replay with the same seed all show the same shapes.
## Node-free; the lab advances it each drawn frame.
extends RefCounted

## The slow motion's rate, and one frame step (s: a 60 fps frame).
const SLOW := 0.1
const FRAME_S := 1.0 / 60.0

## Seconds since the cast began.
var time := 0.0
## The cast's seed: a replay keeps it.
var seed := 0
## How long a cast lasts (s): it holds its end there, or starts over on loop.
var length := 1.0
var paused := false
var slow := false
var looping := false


## A new cast with `cast_seed`, from time 0.
func cast(cast_seed: int) -> void:
	seed = cast_seed
	time = 0.0


## The same cast again from time 0 (the same seed).
func replay() -> void:
	time = 0.0


## P: pauses, or plays on.
func toggle_pause() -> void:
	paused = not paused


## S: 0.1x slow motion on or off.
func toggle_slow() -> void:
	slow = not slow


## L: the cast loops (back to 0 at its length) or stops at its end.
func toggle_loop() -> void:
	looping = not looping


## How fast the time runs (1, or SLOW).
func rate() -> float:
	return SLOW if slow else 1.0


## `frames` 60 fps frames on (back when negative), paused: never before the
## cast's start nor past its end.
func step(frames: int) -> void:
	paused = true
	time = clampf(time + frames * FRAME_S, 0.0, length)


## On by `delta` real seconds (none while paused), at the rate.
func advance(delta: float) -> void:
	if paused:
		return
	time += delta * rate()
	if time >= length:
		time = fposmod(time, length) if looping and length > 0.0 else length


## Whether the cast has played to its end and holds there.
func finished() -> bool:
	return not looping and time >= length
